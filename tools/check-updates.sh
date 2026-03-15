#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# --- Helpers ---

info()  { printf '\033[0;32m[INFO]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$1"; }

# --- Dependency checks ---

if ! command -v paru &>/dev/null; then
    error "paru is required but not installed"
    exit 1
fi

HAVE_CLAUDE=0
if command -v claude &>/dev/null; then
    HAVE_CLAUDE=1
else
    warn "claude CLI not found - will show raw updates only (no risk assessment)"
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
    # Parse date for filtering
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

# --- Display raw summary ---

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

if [[ -n "$AUR_UPDATES" ]]; then
    echo "AUR updates ($AUR_COUNT):"
    echo "$AUR_UPDATES" | sed 's/^/  /'
else
    echo "AUR: up to date"
fi
echo ""

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

# --- Claude risk assessment ---

TOTAL_UPDATES=$((OFFICIAL_COUNT + AUR_COUNT))

if [[ $TOTAL_UPDATES -eq 0 ]]; then
    info "No pending updates. System is up to date."
    exit 0
fi

if [[ $HAVE_CLAUDE -eq 0 ]]; then
    warn "Review the updates above manually before upgrading."
    exit 0
fi

info "Running risk assessment with Claude..."
echo ""

PROMPT="You are an Arch Linux upgrade risk analyst. Assess the following pending updates for safety.

SYSTEM CONTEXT:
- KDE Plasma 6 on Wayland
- AMD RX 6800 XT GPU (mesa/RADV drivers)
- Intel i7-13700K CPU
- PipeWire audio
- greetd/tuigreet display manager
- Wine/Lutris for gaming
- Bluetooth (headphones)

PENDING OFFICIAL REPO UPDATES ($OFFICIAL_COUNT):
${OFFICIAL_UPDATES:-None}

PENDING AUR UPDATES ($AUR_COUNT):
${AUR_UPDATES:-None}

RUSTUP STATUS:
${RUSTUP_STATUS:-Not installed}

NIX STATUS:
${NIX_STATUS:-Not installed}

RECENT ARCH LINUX NEWS:
$ARCH_NEWS

INSTRUCTIONS:
1. For each package with a major or minor version bump, WebSearch for known issues:
   - Official packages: search \"arch linux <package> <new version> issue\" or \"<package> <new version> regression\"
   - AUR packages: search \"<package> <new version> issue\" or \"<package> <new version> bug\", and use WebFetch on https://aur.archlinux.org/packages/<package> to check pinned comments and recent activity
   - Pay special attention to: mesa, linux kernel, KDE/Plasma, PipeWire, systemd, glibc, Wine, greetd, Qt, Wayland, RADV, vulkan, electron-based apps
2. Check if any Arch news items require manual intervention before upgrading
3. For AUR packages, note if the version jump is large (may indicate upstream breaking changes) or if the package has been flagged out-of-date
4. Rate each package or logical group with one of: SAFE / CAUTION / DANGER
5. If update order matters, recommend the correct sequence
6. End with a final verdict: PROCEED / PROCEED WITH CAUTION / DELAY
7. Keep the output concise and scannable"

echo "$PROMPT" | claude --print \
    --model opus \
    --allowedTools "WebSearch,WebFetch" \
    --max-budget-usd 1.00
