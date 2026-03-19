#!/bin/bash
# PKGBUILD security auditor - paru PreBuildCommand integration
#
# Called by paru with a directory path containing the PKGBUILD to review.
# Displays the PKGBUILD with syntax highlighting, then runs Claude analysis
# if the CLI is installed and authenticated. Falls back to display-only.
# Also saves the PKGBUILD to ~/arch/pkgbuilds/ for post-auth audit.

set -euo pipefail

MODEL="opus"

PKG_DIR="${1:-.}"
PKGBUILD="$PKG_DIR/PKGBUILD"

if [[ ! -f "$PKGBUILD" ]]; then
    echo "No PKGBUILD found in $PKG_DIR"
    exit 1
fi

# --- Save PKGBUILD for audit ---

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/../.."
SAVE_DIR="$REPO_DIR/pkgbuilds/${PKGBASE:-$(basename "$PKG_DIR")}"
mkdir -p "$SAVE_DIR"
cp "$PKGBUILD" "$SAVE_DIR/"
for f in "$PKG_DIR"/*.install; do
    [[ -f "$f" ]] && cp "$f" "$SAVE_DIR/"
done

# --- Display PKGBUILD ---

echo ""
if command -v bat &>/dev/null; then
    bat --style=numbers,header --language=bash "$PKGBUILD"
else
    cat -n "$PKGBUILD"
fi

# Show any .install files
for f in "$PKG_DIR"/*.install; do
    [[ -f "$f" ]] || continue
    echo ""
    echo "--- $(basename "$f") ---"
    if command -v bat &>/dev/null; then
        bat --style=numbers --language=bash "$f"
    else
        cat -n "$f"
    fi
done

# --- Claude analysis ---

if ! command -v claude &>/dev/null; then
    echo -e "\n\033[1;33m[AUDIT]\033[0m Claude CLI not installed - manual review only"
    exit 0
fi

if ! claude auth status &>/dev/null 2>&1; then
    echo -e "\n\033[1;33m[AUDIT]\033[0m Claude CLI not authenticated - manual review only"
    exit 0
fi

# --- Cache check ---

CACHE_DIR="$HOME/.cache/audit-pkgbuild"
mkdir -p "$CACHE_DIR"

# Hash all auditable files in the package directory
HASH_INPUT=$(cat "$PKGBUILD" && for f in "$PKG_DIR"/*.install; do [[ -f "$f" ]] && cat "$f"; done)
PKG_HASH=$(echo "$HASH_INPUT" | sha256sum | cut -d' ' -f1)
PKG_NAME="${PKGBASE:-$(basename "$PKG_DIR")}"
CACHE_FILE="$CACHE_DIR/$PKG_NAME.json"

if [[ -f "$CACHE_FILE" ]]; then
    CACHED_HASH=$(jq -r '.hash // empty' "$CACHE_FILE" 2>/dev/null)
    if [[ "$CACHED_HASH" == "$PKG_HASH" ]]; then
        CACHED_VERDICT=$(jq -r '.verdict // empty' "$CACHE_FILE" 2>/dev/null)
        CACHED_SUMMARY=$(jq -r '.summary // empty' "$CACHE_FILE" 2>/dev/null)
        case "$CACHED_VERDICT" in
            PASS) VCOLOR="\033[0;32m" ;;
            WARN) VCOLOR="\033[1;33m" ;;
            FAIL) VCOLOR="\033[0;31m" ;;
            *)    VCOLOR="\033[0m" ;;
        esac
        echo ""
        echo -e "\033[0;36m[AUDIT]\033[0m Cached result (PKGBUILD unchanged)"
        echo -e "  Verdict:          ${VCOLOR}${CACHED_VERDICT}\033[0m"
        echo -e "  Summary:          $CACHED_SUMMARY"
        echo ""
        if [[ "$CACHED_VERDICT" == "FAIL" ]]; then
            echo -e "\033[0;31m[AUDIT] Build aborted - PKGBUILD failed security audit.\033[0m"
            exit 1
        fi
        exit 0
    fi
fi

# Build content to analyze
content="--- PKGBUILD ---"$'\n'"$(cat "$PKGBUILD")"
for f in "$PKG_DIR"/*.install; do
    [[ -f "$f" ]] || continue
    content+=$'\n\n--- '"$(basename "$f")"$' ---\n'"$(cat "$f")"
done

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

echo ""
echo -e "\033[0;36m[AUDIT]\033[0m Analyzing PKGBUILD with Claude..."
echo ""

RAW_OUTPUT=$(echo "$content" | claude -p \
    --model "$MODEL" \
    --system-prompt "$SYSTEM_PROMPT" \
    --json-schema "$JSON_SCHEMA" \
    --output-format json 2>/dev/null) || {
    echo -e "\033[1;33m[AUDIT]\033[0m Claude analysis failed - manual review only"
    exit 0
}

# Structured output is in .structured_output (--json-schema uses an internal tool)
AUDIT_JSON=$(echo "$RAW_OUTPUT" | jq '.structured_output // empty' 2>/dev/null)

# Parse verdict
VERDICT=$(echo "$AUDIT_JSON" | jq -r '.verdict // empty' 2>/dev/null)
SUMMARY=$(echo "$AUDIT_JSON" | jq -r '.summary // empty' 2>/dev/null)
SOURCES=$(echo "$AUDIT_JSON" | jq -r '.sources_verified // empty' 2>/dev/null)

if [[ -z "$VERDICT" ]]; then
    echo -e "\033[1;33m[AUDIT]\033[0m Could not parse Claude response - manual review only"
    exit 0
fi

# Color the verdict
case "$VERDICT" in
    PASS) VCOLOR="\033[0;32m" ;;
    WARN) VCOLOR="\033[1;33m" ;;
    FAIL) VCOLOR="\033[0;31m" ;;
    *)    VCOLOR="\033[0m" ;;
esac

echo -e "  Verdict:          ${VCOLOR}${VERDICT}\033[0m"
echo -e "  Summary:          $SUMMARY"
echo -e "  Sources verified: $SOURCES"

# Show findings
FINDING_COUNT=$(echo "$AUDIT_JSON" | jq '.findings | length' 2>/dev/null)
if [[ "$FINDING_COUNT" -gt 0 ]]; then
    echo ""
    echo "$AUDIT_JSON" | jq -r '.findings[] |
        if .severity == "critical" then "  \u001b[0;31m[critical]\u001b[0m \(.description)"
        elif .severity == "warning" then "  \u001b[1;33m[warning]\u001b[0m \(.description)"
        else "  \u001b[0;36m[info]\u001b[0m \(.description)"
        end' 2>/dev/null
fi

echo ""

# Cache the result
jq -n --arg hash "$PKG_HASH" --arg verdict "$VERDICT" --arg summary "$SUMMARY" \
    --argjson sources "${SOURCES:-false}" --argjson findings "$AUDIT_JSON" \
    '{hash: $hash, verdict: $verdict, summary: $summary, sources_verified: $sources, findings: $findings.findings}' \
    > "$CACHE_FILE" 2>/dev/null

# Abort on FAIL - blocks paru from building the package
if [[ "$VERDICT" == "FAIL" ]]; then
    echo -e "\033[0;31m[AUDIT] Build aborted - PKGBUILD failed security audit.\033[0m"
    exit 1
fi
