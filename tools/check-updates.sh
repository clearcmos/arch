#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CACHE_DIR="$HOME/.cache/check-updates"
AUTO_MODE=false
NO_AI=false

# --- Parse args ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto) AUTO_MODE=true; shift ;;
        --no-ai) NO_AI=true; shift ;;
        *) shift ;;
    esac
done

# --- Helpers ---

info()  { printf '\033[0;32m[INFO]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$1"; }

# Read a package list file, stripping comments and blanks
read_packages() {
    grep -v '^\s*#' "$1" | grep -v '^\s*$' || true
}

# --- Dependency checks ---

if ! command -v paru &>/dev/null; then
    error "paru is required but not installed"
    exit 1
fi

HAVE_CLAUDE=0
if ! $NO_AI; then
    if command -v claude &>/dev/null && claude auth status &>/dev/null 2>&1; then
        HAVE_CLAUDE=1
    else
        if $AUTO_MODE; then
            exit 0
        fi
        warn "Claude CLI not available - will show raw updates only (no AUR audit)"
    fi
fi

# --- Gather official repo updates ---

info "Checking official repo updates..."

CHECKUP_DB=$(mktemp -d)
trap "rm -rf '$CHECKUP_DB'" EXIT

ln -s /var/lib/pacman/local "$CHECKUP_DB/local"
mkdir -p "$CHECKUP_DB/sync"

fakeroot pacman -Sy --dbpath "$CHECKUP_DB" --logfile /dev/null --disable-sandbox --noprogressbar &>/dev/null

OFFICIAL_UPDATES=$(pacman -Qu --dbpath "$CHECKUP_DB" 2>/dev/null || true)
OFFICIAL_COUNT=0
if [[ -n "$OFFICIAL_UPDATES" ]]; then
    OFFICIAL_COUNT=$(echo "$OFFICIAL_UPDATES" | wc -l)
fi

# --- Gather AUR updates ---

info "Checking AUR updates..."

AUR_UPDATES=$(paru -Qua 2>/dev/null || true)
AUR_COUNT=0
if [[ -n "$AUR_UPDATES" ]]; then
    AUR_COUNT=$(echo "$AUR_UPDATES" | wc -l)
fi

# --- Gather new installs (packages in lists but not installed) ---

info "Checking for new package installs..."

NEW_OFFICIAL=""
NEW_OFFICIAL_COUNT=0
if [[ -f "$REPO_DIR/packages/official.txt" ]]; then
    while IFS= read -r pkg; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            NEW_OFFICIAL+="$pkg (new install)"$'\n'
            NEW_OFFICIAL_COUNT=$((NEW_OFFICIAL_COUNT + 1))
        fi
    done < <(read_packages "$REPO_DIR/packages/official.txt")
    NEW_OFFICIAL="${NEW_OFFICIAL%$'\n'}"
fi

NEW_AUR=""
NEW_AUR_COUNT=0
if [[ -f "$REPO_DIR/packages/aur.txt" ]]; then
    while IFS= read -r pkg; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            NEW_AUR+="$pkg (new install)"$'\n'
            NEW_AUR_COUNT=$((NEW_AUR_COUNT + 1))
        fi
    done < <(read_packages "$REPO_DIR/packages/aur.txt")
    NEW_AUR="${NEW_AUR%$'\n'}"
fi

# --- Gather rustup status ---

RUSTUP_STATUS=""
if command -v rustup &>/dev/null; then
    info "Checking rustup status..."
    RUSTUP_STATUS=$(rustup check 2>/dev/null || true)
fi

# --- Gather Nix status ---

NIX_STATUS=""
if command -v nix &>/dev/null; then
    info "Checking Nix status..."
    NIX_PACKAGES=$(nix profile list 2>/dev/null || true)
    if [[ -n "$NIX_PACKAGES" ]]; then
        NIX_STATUS="Installed packages:
$NIX_PACKAGES

Upgrade dry-run:
$(nix profile upgrade --all --dry-run 2>&1 || true)"
    else
        NIX_STATUS="No Nix packages installed."
    fi
fi

# --- Fetch Arch Linux news ---

info "Fetching recent Arch Linux news..."

ARCH_NEWS=""
if NEWS_XML=$(curl -sf https://archlinux.org/feeds/news/); then
    ARCH_NEWS=$(python3 -c "
import xml.etree.ElementTree as ET
import sys
from datetime import datetime, timedelta, timezone

root = ET.fromstring(sys.stdin.read())
cutoff = datetime.now(timezone.utc) - timedelta(days=90)
count = 0

for item in root.findall('.//item'):
    if count >= 15:
        break
    title = item.findtext('title', '')
    link = item.findtext('link', '')
    pub_date = item.findtext('pubDate', '')
    try:
        dt = datetime.strptime(pub_date, '%a, %d %b %Y %H:%M:%S %z')
        if dt < cutoff:
            continue
    except (ValueError, TypeError):
        pass
    date_short = pub_date.split('+')[0].strip() if pub_date else 'unknown'
    print(f'- [{date_short}] {title}')
    print(f'  {link}')
    count += 1

if count == 0:
    print('No recent news items found.')
" <<< "$NEWS_XML" 2>/dev/null || echo "Failed to parse news feed.")
else
    ARCH_NEWS="Failed to fetch news feed."
fi

# --- Display summary ---

if ! $AUTO_MODE; then
    echo ""
    echo "==========================================="
    echo "  Arch Linux Update Summary"
    echo "==========================================="
    echo ""

    if [[ -n "$OFFICIAL_UPDATES" ]]; then
        echo "Official repo updates ($OFFICIAL_COUNT):"
        echo "$OFFICIAL_UPDATES" | sed 's/^/  /'
    else
        echo "Official repo: up to date"
    fi
    echo ""

    if [[ -n "$NEW_OFFICIAL" ]]; then
        echo "New official packages ($NEW_OFFICIAL_COUNT):"
        echo "$NEW_OFFICIAL" | sed 's/^/  /'
        echo ""
    fi

    if [[ -n "$AUR_UPDATES" ]]; then
        echo "AUR updates ($AUR_COUNT):"
        echo "$AUR_UPDATES" | sed 's/^/  /'
    else
        echo "AUR: up to date"
    fi
    echo ""

    if [[ -n "$NEW_AUR" ]]; then
        echo "New AUR packages ($NEW_AUR_COUNT):"
        echo "$NEW_AUR" | sed 's/^/  /'
        echo ""
    fi

    if [[ -n "$RUSTUP_STATUS" ]]; then
        echo "Rustup:"
        echo "$RUSTUP_STATUS" | sed 's/^/  /'
        echo ""
    fi

    if [[ -n "$NIX_STATUS" ]]; then
        echo "Nix:"
        echo "$NIX_STATUS" | sed 's/^/  /'
        echo ""
    fi

    echo "Recent Arch Linux news:"
    echo "$ARCH_NEWS"
    echo ""
fi

if $NO_AI; then
    exit 0
fi

# --- AUR audit (only if there are AUR changes) ---

AUR_TOTAL=$((AUR_COUNT + NEW_AUR_COUNT))

if [[ $AUR_TOTAL -eq 0 ]]; then
    info "No AUR packages to audit."
    exit 0
fi

# --- Fetch AUR PKGBUILDs ---

AUR_PKGBUILDS=""
TMPDIR_AUR=$(mktemp -d)
trap "rm -rf '$CHECKUP_DB' '$TMPDIR_AUR'" EXIT

AUR_AUDIT_PKGS=()
if [[ -n "$AUR_UPDATES" ]]; then
    while IFS= read -r line; do
        pkg=$(echo "$line" | awk '{print $1}')
        AUR_AUDIT_PKGS+=("$pkg")
    done <<< "$AUR_UPDATES"
fi
if [[ -n "$NEW_AUR" ]]; then
    while IFS= read -r line; do
        pkg=$(echo "$line" | awk '{print $1}')
        AUR_AUDIT_PKGS+=("$pkg")
    done <<< "$NEW_AUR"
fi

info "Fetching AUR PKGBUILDs for audit..."
for pkg in "${AUR_AUDIT_PKGS[@]}"; do
    if (cd "$TMPDIR_AUR" && paru -G "$pkg" 2>/dev/null); then
        PKGBUILD_FILE="$TMPDIR_AUR/$pkg/PKGBUILD"
        if [[ -f "$PKGBUILD_FILE" ]]; then
            AUR_PKGBUILDS+="
=== PKGBUILD: $pkg ===
$(cat "$PKGBUILD_FILE")"
            for f in "$TMPDIR_AUR/$pkg"/*.install; do
                [[ -f "$f" ]] || continue
                AUR_PKGBUILDS+="
--- $(basename "$f") ---
$(cat "$f")"
            done
        fi
    else
        warn "  failed to fetch PKGBUILD for $pkg"
    fi
done

if [[ -z "$AUR_PKGBUILDS" ]]; then
    warn "Could not fetch any PKGBUILDs - manual review required."
    exit 0
fi

# --- Claude AUR audit ---

if [[ $HAVE_CLAUDE -eq 0 ]]; then
    warn "Review the AUR PKGBUILDs manually before upgrading."
    exit 0
fi

# Cache check
mkdir -p "$CACHE_DIR"
CACHE_KEY=$(echo "$AUR_PKGBUILDS" | sha256sum | cut -d' ' -f1)
CACHE_FILE="$CACHE_DIR/$CACHE_KEY.json"

# Format and display verdict
render_verdict() {
    local json="$1"
    local cached="${2:-false}"
    local overall summary

    overall=$(echo "$json" | jq -r '.overall_verdict // empty' 2>/dev/null)
    summary=$(echo "$json" | jq -r '.overall_summary // empty' 2>/dev/null)

    [[ -z "$overall" ]] && return 1

    local VCOLOR
    case "$overall" in
        SAFE)    VCOLOR="\033[0;32m" ;;
        CAUTION) VCOLOR="\033[1;33m" ;;
        RISK)    VCOLOR="\033[0;31m" ;;
        *)       VCOLOR="\033[0m" ;;
    esac

    local header="AUR Audit"
    [[ "$cached" == "true" ]] && header="AUR Audit (cached)"

    echo ""
    echo "==========================================="
    echo "  $header"
    echo "==========================================="
    echo ""
    echo -e "Overall: ${VCOLOR}${overall}\033[0m - $summary"
    echo ""

    echo "$json" | jq -r '.packages[] |
        if .verdict == "SAFE" then "  \u001b[0;32m[SAFE]\u001b[0m \(.name) \(.from_version) -> \(.to_version): \(.reason)"
        elif .verdict == "CAUTION" then "  \u001b[1;33m[CAUTION]\u001b[0m \(.name) \(.from_version) -> \(.to_version): \(.reason)"
        else "  \u001b[0;31m[RISK]\u001b[0m \(.name) \(.from_version) -> \(.to_version): \(.reason)"
        end' 2>/dev/null || true

    local actions
    actions=$(echo "$json" | jq -r '.recommended_actions[]?' 2>/dev/null)
    if [[ -n "$actions" ]]; then
        echo ""
        echo "Recommended actions:"
        echo "$actions" | sed 's/^/  - /'
    fi
    echo ""
}

# Handle interactive prompt for CAUTION/RISK
handle_verdict() {
    local json="$1"
    local overall
    overall=$(echo "$json" | jq -r '.overall_verdict // empty' 2>/dev/null)

    if [[ "$overall" == "CAUTION" || "$overall" == "RISK" ]]; then
        local VCOLOR
        case "$overall" in
            CAUTION) VCOLOR="\033[1;33m" ;;
            *)       VCOLOR="\033[0;31m" ;;
        esac

        if $AUTO_MODE; then
            exit 1
        fi

        echo -e "${VCOLOR}[$overall]\033[0m This upgrade requires confirmation."
        echo ""
        echo "Options:"
        echo "  [A] Abort upgrade entirely"
        echo "  [S] Skip flagged packages, continue with rest"
        echo "  [C] Continue anyway (install all)"
        echo ""
        read -r -p "Choice [A/S/C]: " choice
        case "$choice" in
            [Cc]) info "Continuing with all packages." ;;
            [Ss])
                echo "$json" | jq -r '.packages[] | select(.verdict != "SAFE") | .name' 2>/dev/null \
                    > "$CACHE_DIR/skip-packages.txt"
                info "Skipped packages written to $CACHE_DIR/skip-packages.txt"
                ;;
            *) error "Upgrade aborted."; exit 1 ;;
        esac
    else
        info "All clear - safe to proceed with AUR upgrades."
    fi
}

if [[ -f "$CACHE_FILE" ]]; then
    info "Using cached AUR audit (PKGBUILDs unchanged)"
    VERDICT_JSON=$(cat "$CACHE_FILE")
    render_verdict "$VERDICT_JSON" true
    handle_verdict "$VERDICT_JSON"
    exit 0
fi

info "Running AUR audit with Claude..."
echo ""

AUDIT_PROMPT="You are an AUR PKGBUILD security and stability auditor for Arch Linux.

TARGET SYSTEM: AMD RX 6800 XT (mesa/RADV, RDNA2), Intel i7-13700K, KDE Plasma 6 on Wayland, KWin, PipeWire/WirePlumber, greetd/tuigreet, Wine-staging/Lutris/Gamemode, Docker, libvirt/KVM/QEMU, Bluetooth (bluez + PipeWire), nftables firewall, Tailscale, Nix package manager, NetworkManager.

PENDING AUR UPDATES ($AUR_COUNT):
${AUR_UPDATES:-None}

NEW AUR PACKAGES ($NEW_AUR_COUNT):
${NEW_AUR:-None}

AUR PKGBUILD CONTENTS:
$AUR_PKGBUILDS

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

INSTRUCTIONS:
1. For each AUR package, use WebFetch on https://aur.archlinux.org/packages/<package> to check comments for reported issues
2. Verify source URLs point to legitimate upstream locations
3. Check PKGBUILDs for security concerns
4. Be thorough but concise"

INVESTIGATION=$(echo "$AUDIT_PROMPT" | claude --print \
    --model opus \
    --allowedTools "WebSearch,WebFetch" \
    --max-budget-usd 0.50 2>/dev/null) || {
    error "Claude audit failed"
    if $AUTO_MODE; then
        exit 0
    fi
    warn "Review the AUR PKGBUILDs manually before upgrading."
    exit 0
}

if ! $AUTO_MODE; then
    echo "$INVESTIGATION"
    echo ""
fi

# --- Extract structured verdict ---

VERDICT_SCHEMA='{
  "type": "object",
  "properties": {
    "overall_verdict": {
      "type": "string",
      "enum": ["SAFE", "CAUTION", "RISK"],
      "description": "SAFE=all clear, CAUTION=proceed with care, RISK=significant danger"
    },
    "overall_summary": {
      "type": "string",
      "description": "One-line summary of the overall assessment"
    },
    "packages": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "from_version": {"type": "string", "description": "Current version or new install"},
          "to_version": {"type": "string"},
          "verdict": {"type": "string", "enum": ["SAFE", "CAUTION", "RISK"]},
          "reason": {"type": "string", "description": "Brief reason for the verdict"}
        },
        "required": ["name", "from_version", "to_version", "verdict", "reason"],
        "additionalProperties": false
      }
    },
    "manual_intervention_required": {
      "type": "boolean",
      "description": "Whether any manual steps are needed before upgrading"
    },
    "recommended_actions": {
      "type": "array",
      "items": {"type": "string"},
      "description": "List of recommended actions before or during upgrade"
    }
  },
  "required": ["overall_verdict", "overall_summary", "packages", "manual_intervention_required", "recommended_actions"],
  "additionalProperties": false
}'

EXTRACTION_PROMPT="Extract a structured per-package verdict from the following AUR audit. Map the analyst's ratings: SAFE/PROCEED=SAFE, CAUTION/PROCEED WITH CAUTION=CAUTION, DANGER/DELAY/RISK=RISK.

ANALYSIS:
$INVESTIGATION"

info "Extracting structured verdict..."

RAW_VERDICT=$(echo "$EXTRACTION_PROMPT" | claude --print \
    --model haiku \
    --json-schema "$VERDICT_SCHEMA" \
    --output-format json 2>/dev/null) || {
    error "Verdict extraction failed"
    if $AUTO_MODE; then
        exit 0
    fi
    exit 0
}

VERDICT_JSON=$(echo "$RAW_VERDICT" | jq '.structured_output // .' 2>/dev/null)

OVERALL=$(echo "$VERDICT_JSON" | jq -r '.overall_verdict // empty' 2>/dev/null)
if [[ -z "$OVERALL" ]]; then
    error "Could not parse structured verdict"
    if $AUTO_MODE; then
        exit 0
    fi
    exit 0
fi

# Cache the result
echo "$VERDICT_JSON" > "$CACHE_FILE"

render_verdict "$VERDICT_JSON"
handle_verdict "$VERDICT_JSON"
