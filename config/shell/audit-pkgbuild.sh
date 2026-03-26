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
HASH_INPUT=$(cat "$PKGBUILD"; for f in "$PKG_DIR"/*.install; do [[ -f "$f" ]] && cat "$f" || true; done)
PKG_HASH=$(echo "$HASH_INPUT" | sha256sum | cut -d' ' -f1)
PKG_NAME="${PKGBASE:-$(basename "$PKG_DIR")}"
CACHE_FILE="$CACHE_DIR/$PKG_NAME.json"

# Format and display verdict JSON as markdown (via glow if available)
render_verdict() {
    local json="$1"
    local cached="${2:-false}"
    local verdict summary sources
    verdict=$(echo "$json" | jq -r '.verdict // empty' 2>/dev/null)
    summary=$(echo "$json" | jq -r '.summary // empty' 2>/dev/null)
    sources=$(echo "$json" | jq -r '.sources_verified // empty' 2>/dev/null)

    [[ -z "$verdict" ]] && return 1

    local md=""
    local header="PKGBUILD Audit"
    [[ "$cached" == "true" ]] && header="PKGBUILD Audit (cached)"

    md="# $header"$'\n\n'
    md+="| | |"$'\n'
    md+="|---|---|"$'\n'
    md+="| **Verdict** | **${verdict}** |"$'\n'
    md+="| **Summary** | ${summary} |"$'\n'
    md+="| **Sources verified** | ${sources} |"$'\n'

    local finding_count
    finding_count=$(echo "$json" | jq '.findings | length' 2>/dev/null)
    if [[ "$finding_count" -gt 0 ]]; then
        md+=$'\n'"## Findings"$'\n\n'
        while IFS= read -r line; do
            md+="$line"$'\n'
        done < <(echo "$json" | jq -r '.findings[] |
            if .severity == "critical" then "- **CRITICAL:** \(.description)"
            elif .severity == "warning" then "- **WARNING:** \(.description)"
            else "- \(.description)"
            end' 2>/dev/null)
    fi

    if command -v glow &>/dev/null; then
        echo "$md" | glow -
    else
        echo "$md"
    fi
}

if [[ -f "$CACHE_FILE" ]]; then
    CACHED_HASH=$(jq -r '.hash // empty' "$CACHE_FILE" 2>/dev/null)
    if [[ "$CACHED_HASH" == "$PKG_HASH" ]]; then
        CACHED_VERDICT=$(jq -r '.verdict // empty' "$CACHE_FILE" 2>/dev/null)
        echo ""
        render_verdict "$(cat "$CACHE_FILE")" true
        if [[ "$CACHED_VERDICT" == "FAIL" ]]; then
            echo -e "\033[0;31m[AUDIT] Build aborted - package failed audit.\033[0m"
            exit 1
        fi
        read -r -p "Press Enter to continue..." < /dev/tty
        exit 0
    fi
fi

# Build content to analyze
content="--- PKGBUILD ---"$'\n'"$(cat "$PKGBUILD")"
for f in "$PKG_DIR"/*.install; do
    [[ -f "$f" ]] || continue
    content+=$'\n\n--- '"$(basename "$f")"$' ---\n'"$(cat "$f")"
done

SYSTEM_PROMPT='You are a security and stability auditor for Arch Linux AUR PKGBUILDs. Analyze the PKGBUILD (and any .install files) for both malicious content AND potential system stability impact.

TARGET SYSTEM: AMD RX 6800 XT (mesa/RADV, RDNA2), Intel i7-13700K, KDE Plasma 6 on Wayland, KWin, PipeWire/WirePlumber, greetd/tuigreet, Wine-staging/Lutris/Gamemode, Docker, libvirt/KVM/QEMU, Bluetooth (bluez + PipeWire), nftables firewall, Tailscale, Nix package manager, NetworkManager.

SECURITY - check for:
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

STABILITY - check for:
1. Conflicts with or replacement of core system packages (mesa, KDE, PipeWire, systemd, kernel)
2. Kernel modules, systemd services, or udev rules that could affect boot or hardware
3. System-wide config changes (Xorg, Wayland, audio, network)
4. Known incompatibilities with the target hardware or software stack
5. Input/device grabbing that could interfere with gaming or desktop

Issue PASS if both security and stability are fine.
Issue WARN for non-critical concerns (document what and why).
Issue FAIL for clearly malicious code or high likelihood of breaking the system.

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

render_verdict "$AUDIT_JSON"

read -r -p "Press Enter to continue..." < /dev/tty

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
