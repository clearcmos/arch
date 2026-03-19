#!/bin/bash
# Post-authentication AUR package audit
#
# Fetches PKGBUILDs for all AUR packages in aur.txt and runs Claude
# security analysis against each one. Designed to run after Claude Code
# is installed and authenticated, covering the gap where AUR packages
# were installed on a fresh system before auth was available.
#
# Usage:
#   audit-aur                     # audit all packages in aur.txt
#   audit-aur brave-bin spotify   # audit specific packages

set -euo pipefail

MODEL="opus"

# When symlinked to ~/.local/bin, resolve to repo location
REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/../.. && pwd)"
AUR_LIST="$REPO_DIR/packages/aur.txt"
PKGBUILD_DIR="$REPO_DIR/pkgbuilds"

# --- Preflight checks ---

if ! command -v claude &>/dev/null; then
    echo "Claude CLI not installed. Install Claude Code first."
    exit 1
fi

if ! claude auth status &>/dev/null 2>&1; then
    echo "Claude CLI not authenticated. Run: claude auth login"
    exit 1
fi

if ! command -v paru &>/dev/null; then
    echo "paru not installed."
    exit 1
fi

# --- Build package list ---

packages=()
if [[ $# -gt 0 ]]; then
    packages=("$@")
elif [[ -f "$AUR_LIST" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        packages+=("$line")
    done < "$AUR_LIST"
else
    echo "No packages specified and aur.txt not found at $AUR_LIST"
    exit 1
fi

TOTAL=${#packages[@]}
echo "Auditing $TOTAL AUR package(s)..."
echo ""

# --- System prompt and schema (same as audit-pkgbuild) ---

SYSTEM_PROMPT='You are a security auditor for Arch Linux AUR PKGBUILDs. Analyze the PKGBUILD (and any .install files) for malicious or suspicious content.

Check for:
1. Source URLs - do they point to official/expected upstream locations?
2. Integrity checks - are sha256sums/b2sums present and not SKIP?
3. Fetch-and-execute patterns (curl|bash, wget|sh)
4. Obfuscated code (base64, hex escapes, eval of encoded strings)
5. Access to sensitive files (~/.ssh, ~/.gnupg, credentials, tokens)
6. Network calls in build()/package() beyond declared sources
7. SUID/SGID bits on unexpected binaries
8. Suspicious .install scripts (post_install/post_upgrade hooks)
9. Unusual or unnecessary dependencies
10. Commands that modify files outside the package directory

IMPORTANT: For ANY finding that is warning or critical severity, you MUST verify it before issuing your verdict. Use web search to:
- Check the upstream project documentation for whether the behavior is expected
- Search the AUR package page and comments for known issues or user reports
- Search for any recent security advisories or incidents involving this package
- Verify that source URLs match the official project distribution channels
- Check if SUID/SGID bits, eval usage, or network calls are documented upstream behavior

Only issue WARN if you have verified the behavior is documented/expected upstream.
Only issue FAIL if the behavior is unexplained, undocumented, or clearly malicious.
A finding you cannot verify against upstream documentation should be treated as more suspicious.

Be concise. Focus on actionable findings only.'

JSON_SCHEMA='{
  "type": "object",
  "properties": {
    "verdict": {
      "type": "string",
      "enum": ["PASS", "WARN", "FAIL"],
      "description": "PASS=clean, WARN=potentially risky but possibly legitimate, FAIL=clearly malicious or highly suspicious"
    },
    "summary": {
      "type": "string",
      "description": "One-line assessment"
    },
    "findings": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "severity": {"type": "string", "enum": ["info", "warning", "critical"]},
          "description": {"type": "string"}
        },
        "required": ["severity", "description"],
        "additionalProperties": false
      }
    },
    "sources_verified": {
      "type": "boolean",
      "description": "Whether source URLs point to expected upstream locations"
    }
  },
  "required": ["verdict", "summary", "findings", "sources_verified"],
  "additionalProperties": false
}'

# --- Audit each package ---

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Check if saved PKGBUILDs exist (from setup.sh or PreBuildCommand)
USE_SAVED=false
if [[ -d "$PKGBUILD_DIR" ]]; then
    USE_SAVED=true
    echo "Using saved PKGBUILDs from $PKGBUILD_DIR"
    echo ""
fi

pass=0
warn=0
fail=0
errors=0
warn_packages=()
fail_packages=()

for pkg in "${packages[@]}"; do
    echo -e "\033[1m[$((pass + warn + fail + errors + 1))/$TOTAL]\033[0m $pkg"

    # Use saved PKGBUILD if available, otherwise fetch from AUR
    if $USE_SAVED && [[ -f "$PKGBUILD_DIR/$pkg/PKGBUILD" ]]; then
        PKG_DIR="$PKGBUILD_DIR/$pkg"
    else
        if ! (cd "$TMPDIR" && paru -G "$pkg" 2>/dev/null); then
            echo -e "  \033[1;33m[SKIP]\033[0m Failed to fetch PKGBUILD"
            errors=$((errors + 1))
            continue
        fi
        PKG_DIR="$TMPDIR/$pkg"
    fi

    PKGBUILD="$PKG_DIR/PKGBUILD"

    if [[ ! -f "$PKGBUILD" ]]; then
        echo -e "  \033[1;33m[SKIP]\033[0m No PKGBUILD found"
        errors=$((errors + 1))
        continue
    fi

    # Check cache
    CACHE_DIR="$HOME/.cache/audit-pkgbuild"
    mkdir -p "$CACHE_DIR"
    HASH_INPUT=$(cat "$PKGBUILD" && for f in "$PKG_DIR"/*.install; do [[ -f "$f" ]] && cat "$f"; done)
    PKG_HASH=$(echo "$HASH_INPUT" | sha256sum | cut -d' ' -f1)
    CACHE_FILE="$CACHE_DIR/$pkg.json"

    if [[ -f "$CACHE_FILE" ]]; then
        CACHED_HASH=$(jq -r '.hash // empty' "$CACHE_FILE" 2>/dev/null)
        if [[ "$CACHED_HASH" == "$PKG_HASH" ]]; then
            VERDICT=$(jq -r '.verdict // empty' "$CACHE_FILE" 2>/dev/null)
            SUMMARY=$(jq -r '.summary // empty' "$CACHE_FILE" 2>/dev/null)
            case "$VERDICT" in
                PASS) echo -e "  \033[0;32m[PASS]\033[0m (cached) $SUMMARY"; pass=$((pass + 1)) ;;
                WARN) echo -e "  \033[1;33m[WARN]\033[0m (cached) $SUMMARY"; warn_packages+=("$pkg"); warn=$((warn + 1)) ;;
                FAIL) echo -e "  \033[0;31m[FAIL]\033[0m (cached) $SUMMARY"; fail_packages+=("$pkg"); fail=$((fail + 1)) ;;
            esac
            rm -rf "$TMPDIR/$pkg" 2>/dev/null
            continue
        fi
    fi

    # Build content
    content="--- PKGBUILD ---"$'\n'"$(cat "$PKGBUILD")"
    for f in "$PKG_DIR"/*.install; do
        [[ -f "$f" ]] || continue
        content+=$'\n\n--- '"$(basename "$f")"$' ---\n'"$(cat "$f")"
    done

    # Run Claude analysis
    RAW_OUTPUT=$(echo "$content" | claude -p \
        --model "$MODEL" \
        --system-prompt "$SYSTEM_PROMPT" \
        --json-schema "$JSON_SCHEMA" \
        --output-format json 2>/dev/null) || {
        echo -e "  \033[1;33m[SKIP]\033[0m Claude analysis failed"
        errors=$((errors + 1))
        continue
    }

    AUDIT_JSON=$(echo "$RAW_OUTPUT" | jq '.structured_output // empty' 2>/dev/null)
    VERDICT=$(echo "$AUDIT_JSON" | jq -r '.verdict // empty' 2>/dev/null)
    SUMMARY=$(echo "$AUDIT_JSON" | jq -r '.summary // empty' 2>/dev/null)

    # Cache the result
    if [[ -n "$VERDICT" ]]; then
        jq -n --arg hash "$PKG_HASH" --arg verdict "$VERDICT" --arg summary "$SUMMARY" \
            '{hash: $hash, verdict: $verdict, summary: $summary}' \
            > "$CACHE_FILE" 2>/dev/null
    fi

    if [[ -z "$VERDICT" ]]; then
        echo -e "  \033[1;33m[SKIP]\033[0m Could not parse response"
        errors=$((errors + 1))
        continue
    fi

    case "$VERDICT" in
        PASS)
            echo -e "  \033[0;32m[PASS]\033[0m $SUMMARY"
            pass=$((pass + 1))
            ;;
        WARN)
            echo -e "  \033[1;33m[WARN]\033[0m $SUMMARY"
            warn_packages+=("$pkg")
            warn=$((warn + 1))
            # Show findings for warnings
            echo "$AUDIT_JSON" | jq -r '.findings[] | "         \(.severity): \(.description)"' 2>/dev/null
            ;;
        FAIL)
            echo -e "  \033[0;31m[FAIL]\033[0m $SUMMARY"
            fail_packages+=("$pkg")
            fail=$((fail + 1))
            # Show findings for failures
            echo "$AUDIT_JSON" | jq -r '.findings[] | "         \(.severity): \(.description)"' 2>/dev/null
            ;;
    esac

    # Clean up for next package
    rm -rf "$PKG_DIR"
done

# --- Summary ---

echo ""
echo "=============================="
echo "  AUR Audit Summary"
echo "=============================="
echo -e "  \033[0;32mPASS:\033[0m  $pass"
echo -e "  \033[1;33mWARN:\033[0m  $warn"
echo -e "  \033[0;31mFAIL:\033[0m  $fail"
echo -e "  SKIP:  $errors"
echo "  Total: $TOTAL"

if [[ ${#warn_packages[@]} -gt 0 ]]; then
    echo ""
    echo -e "  \033[1;33mPackages with warnings:\033[0m"
    for p in "${warn_packages[@]}"; do
        echo "    - $p"
    done
fi

if [[ ${#fail_packages[@]} -gt 0 ]]; then
    echo ""
    echo -e "  \033[0;31mPackages that FAILED:\033[0m"
    for p in "${fail_packages[@]}"; do
        echo "    - $p"
    done
    echo ""
    echo "  Review failed packages immediately. Consider removing them:"
    for p in "${fail_packages[@]}"; do
        echo "    paru -R $p"
    done
fi

echo ""

# Clean up saved PKGBUILDs on successful audit
if [[ $fail -eq 0 && -d "$PKGBUILD_DIR" ]]; then
    rm -rf "$PKGBUILD_DIR"
    echo "Cleaned up saved PKGBUILDs."
fi

# Exit with failure if any packages failed
[[ $fail -eq 0 ]]
