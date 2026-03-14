#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Parse flags ---

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# --- Helpers ---

info()  { printf '\033[0;32m[INFO]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$1"; }
ok()    { printf '\033[0;32m  OK\033[0m %s\n' "$1"; }
fail()  { printf '\033[0;31m  FAIL\033[0m %s\n' "$1"; }

# Read a package list file, stripping comments and blanks
read_packages() {
    grep -v '^\s*#' "$1" | grep -v '^\s*$'
}

if $DRY_RUN; then
    info "=== DRY RUN - validating setup, nothing will be changed ==="
    echo ""
    errors=0

    # --- Validate package list files exist ---
    info "Checking package list files..."
    for f in "$SCRIPT_DIR/packages/official.txt" "$SCRIPT_DIR/packages/aur.txt" "$SCRIPT_DIR/services.txt"; do
        if [[ -f "$f" ]]; then
            ok "$f"
        else
            fail "$f not found"
            errors=$((errors + 1))
        fi
    done

    # --- Validate official packages ---
    echo ""
    info "Validating official packages (pacman --print)..."
    if read_packages "$SCRIPT_DIR/packages/official.txt" \
        | xargs pacman -S --needed --print &>/dev/null; then
        ok "all official packages resolved successfully"
    else
        fail "some official packages failed to resolve:"
        # Show which ones fail individually
        while IFS= read -r pkg; do
            if ! pacman -S --needed --print "$pkg" &>/dev/null; then
                fail "  $pkg"
                errors=$((errors + 1))
            fi
        done < <(read_packages "$SCRIPT_DIR/packages/official.txt")
    fi

    # --- Validate AUR helper ---
    echo ""
    info "Checking AUR helper (paru)..."
    if command -v paru &>/dev/null; then
        ok "paru is installed"

        # Validate AUR packages (paru --print doesn't work for AUR, use -Si to check existence)
        info "Validating AUR packages..."
        aur_ok=true
        while IFS= read -r pkg; do
            if paru -Si "$pkg" &>/dev/null; then
                ok "$pkg"
            else
                fail "$pkg (not found in repos or AUR)"
                errors=$((errors + 1))
                aur_ok=false
            fi
        done < <(read_packages "$SCRIPT_DIR/packages/aur.txt")
    else
        warn "paru not installed - AUR packages cannot be validated (will be installed on real run)"
    fi

    # --- Check standalone tools ---
    echo ""
    info "Checking standalone tools..."
    if command -v rustup &>/dev/null; then
        ok "rustup already installed"
    else
        warn "rustup not found - will be installed"
    fi

    if command -v nix &>/dev/null; then
        ok "nix already installed"
    else
        warn "nix not found - will be installed"
    fi

    if command -v npm &>/dev/null; then
        ok "npm available (needed for claude code)"
    else
        warn "npm not found - will be available after pacman installs it"
    fi

    if command -v claude &>/dev/null; then
        ok "claude code already installed"
    else
        warn "claude code not found - will be installed"
    fi

    # --- Check config source files ---
    echo ""
    info "Checking config source files..."
    config_files=(
        "config/hyprland/hyprland.conf"
        "config/waybar/config.jsonc"
        "config/waybar/style.css"
        "config/rofi/config.rasi"
        "config/greetd/config.toml"
        "config/claude-code/settings.json"
        "config/ghostty/config.ghostty"
        "config/claude-code/CLAUDE.md"
        "config/shell/aliases.sh"
        "config/hyprland/scripts/fake-maximize.sh"
        "config/brave/brave-flags.conf"
        "config/hyprfloat/commands/snap.lua"
        "config/hyprfloat/lib/hyprland.lua"
    )
    for f in "${config_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$f" ]]; then
            ok "$f"
        else
            fail "$f not found"
            errors=$((errors + 1))
        fi
    done

    # --- Check services ---
    echo ""
    info "Checking services..."
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue

        if [[ "$line" == user:* ]]; then
            svc="${line#user:}"
            if systemctl --user is-enabled "$svc" &>/dev/null; then
                ok "user:$svc (already enabled)"
            elif systemctl --user cat "$svc" &>/dev/null; then
                ok "user:$svc (unit exists, will enable)"
            else
                warn "user:$svc (unit not found - may appear after packages install)"
            fi
        else
            if systemctl is-enabled "$line" &>/dev/null; then
                ok "$line (already enabled)"
            elif systemctl cat "$line" &>/dev/null; then
                ok "$line (unit exists, will enable)"
            else
                warn "$line (unit not found - may appear after packages install)"
            fi
        fi
    done < "$SCRIPT_DIR/services.txt"

    # --- Check Bluetooth devices ---
    echo ""
    info "Checking Bluetooth devices..."
    Q30_MAC="E8:EE:CC:46:F1:AC"
    if bluetoothctl info "$Q30_MAC" 2>/dev/null | grep -q "Paired: yes"; then
        ok "Soundcore Life Q30 ($Q30_MAC) paired"
    else
        warn "Soundcore Life Q30 ($Q30_MAC) not paired - manual pairing required"
    fi
    if bluetoothctl info "$Q30_MAC" 2>/dev/null | grep -q "Trusted: yes"; then
        ok "Soundcore Life Q30 ($Q30_MAC) trusted"
    else
        warn "Soundcore Life Q30 ($Q30_MAC) not trusted - will trust on real run"
    fi

    # --- Summary ---
    echo ""
    if [[ $errors -eq 0 ]]; then
        info "=== DRY RUN PASSED - no errors found ==="
    else
        error "=== DRY RUN FOUND $errors ERROR(S) ==="
        exit 1
    fi
    exit 0
fi

# =============================================================
# REAL RUN
# =============================================================

# --- System Update ---

info "Updating system..."
sudo pacman -Syu --noconfirm

# --- Official Packages ---

info "Installing official packages..."
read_packages "$SCRIPT_DIR/packages/official.txt" \
    | xargs sudo pacman -S --needed --noconfirm

# --- AUR Helper (paru) ---

if ! command -v paru &>/dev/null; then
    info "Installing paru (AUR helper)..."
    _tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/paru.git "$_tmp/paru"
    (cd "$_tmp/paru" && makepkg -si --noconfirm)
    rm -rf "$_tmp"
else
    info "paru already installed, skipping."
fi

# --- AUR Packages ---

info "Installing AUR packages..."
read_packages "$SCRIPT_DIR/packages/aur.txt" \
    | xargs paru -S --needed --noconfirm

# --- Rust (via rustup) ---

if ! command -v rustup &>/dev/null; then
    info "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    info "Rust already installed, skipping."
fi

# --- Nix (Determinate Systems installer) ---

if ! command -v nix &>/dev/null; then
    info "Installing Nix..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
        | sh -s -- install --no-confirm
else
    info "Nix already installed, skipping."
fi

# --- Claude Code ---

if ! command -v claude &>/dev/null; then
    info "Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
else
    info "Claude Code already installed, skipping."
fi

# --- Enable Services ---

info "Enabling services..."
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and blanks
    [[ -z "$line" || "$line" == \#* ]] && continue

    if [[ "$line" == user:* ]]; then
        svc="${line#user:}"
        if systemctl --user is-enabled "$svc" &>/dev/null; then
            info "  user service '$svc' already enabled."
        else
            systemctl --user enable --now "$svc"
            info "  enabled user service '$svc'."
        fi
    else
        if systemctl is-enabled "$line" &>/dev/null; then
            info "  service '$line' already enabled."
        else
            sudo systemctl enable "$line"
            info "  enabled service '$line'."
        fi
    fi
done < "$SCRIPT_DIR/services.txt"

# --- Hyprland Plugins (via hyprpm) ---

info "Setting up Hyprland plugins..."
hyprpm update || true
if ! hyprpm list | grep -q "hyprbars.*enabled"; then
    hyprpm add https://github.com/hyprwm/hyprland-plugins || true
    hyprpm enable hyprbars
else
    info "  hyprbars already enabled, skipping."
fi

# --- Hyprfloat (window snapping) ---

if ! command -v hyprfloat &>/dev/null; then
    info "Installing hyprfloat..."
    curl -fsSL https://raw.githubusercontent.com/yz778/hyprfloat/main/install.sh | sh
else
    info "hyprfloat already installed, skipping."
fi

# --- Deploy Configs ---

info "Deploying config files..."

# Helper: symlink a config file, creating parent dirs as needed
link_config() {
    local src="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
    info "  linked $dest"
}

# Hyprland
link_config "$SCRIPT_DIR/config/hyprland/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"
link_config "$SCRIPT_DIR/config/hyprland/scripts/focus-raise.sh" "$HOME/.config/hypr/scripts/focus-raise.sh"

# labwc
link_config "$SCRIPT_DIR/config/labwc/rc.xml" "$HOME/.config/labwc/rc.xml"
link_config "$SCRIPT_DIR/config/labwc/autostart" "$HOME/.config/labwc/autostart"
link_config "$SCRIPT_DIR/config/labwc/environment" "$HOME/.config/labwc/environment"
link_config "$SCRIPT_DIR/config/labwc/themerc-override" "$HOME/.config/labwc/themerc-override"

# Waybar
link_config "$SCRIPT_DIR/config/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
link_config "$SCRIPT_DIR/config/waybar/style.css" "$HOME/.config/waybar/style.css"

# Rofi
link_config "$SCRIPT_DIR/config/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"

# Hyprfloat patches (custom snap with scale/transform/cross-monitor support)
link_config "$SCRIPT_DIR/config/hyprfloat/commands/snap.lua" "$HOME/.local/share/hyprfloat/commands/snap.lua"
link_config "$SCRIPT_DIR/config/hyprfloat/lib/hyprland.lua" "$HOME/.local/share/hyprfloat/lib/hyprland.lua"

# Brave
link_config "$SCRIPT_DIR/config/brave/brave-flags.conf" "$HOME/.config/brave-flags.conf"

# Ghostty
link_config "$SCRIPT_DIR/config/ghostty/config.ghostty" "$HOME/.config/ghostty/config.ghostty"

# Claude Code
link_config "$SCRIPT_DIR/config/claude-code/settings.json" "$HOME/.claude/settings.json"
link_config "$SCRIPT_DIR/config/claude-code/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# Shell aliases
link_config "$SCRIPT_DIR/config/shell/aliases.sh" "$HOME/.config/shell/aliases.sh"

# Source aliases from bashrc if not already present
if ! grep -q 'shell/aliases.sh' "$HOME/.bashrc" 2>/dev/null; then
    echo '' >> "$HOME/.bashrc"
    echo '# Custom aliases' >> "$HOME/.bashrc"
    echo '[ -f "$HOME/.config/shell/aliases.sh" ] && source "$HOME/.config/shell/aliases.sh"' >> "$HOME/.bashrc"
    info "  added aliases source line to ~/.bashrc"
fi

# greetd (system config, needs root)
sudo mkdir -p /etc/greetd
sudo cp "$SCRIPT_DIR/config/greetd/config.toml" /etc/greetd/config.toml
info "  copied greetd config to /etc/greetd/config.toml"

# Brave policies (system-wide, needs root)
sudo mkdir -p /etc/brave/policies/managed
sudo cp "$SCRIPT_DIR/config/brave/policies.json" /etc/brave/policies/managed/policies.json
info "  copied Brave policies to /etc/brave/policies/managed/"

# --- Bluetooth Devices ---

info "Configuring Bluetooth devices..."

Q30_MAC="E8:EE:CC:46:F1:AC"

if bluetoothctl info "$Q30_MAC" 2>/dev/null | grep -q "Paired: yes"; then
    info "  Soundcore Life Q30 ($Q30_MAC) already paired."
else
    info "  Soundcore Life Q30 ($Q30_MAC) not paired."
    info "  Put headphones in pairing mode (off -> hold power 5s), then run:"
    info "    bluetoothctl scan on  (wait for Q30)  ->  scan off  ->  pair $Q30_MAC"
    info "    bluetoothctl trust $Q30_MAC"
fi

# Ensure device is trusted (idempotent)
if bluetoothctl info "$Q30_MAC" 2>/dev/null | grep -q "Trusted: yes"; then
    info "  Soundcore Life Q30 already trusted."
else
    bluetoothctl trust "$Q30_MAC" 2>/dev/null && info "  trusted Soundcore Life Q30." || true
fi

# --- Done ---

echo ""
info "Setup complete!"
info "Reboot to start with greetd + Hyprland."
info ""
info "Quick reference:"
info "  SUPER+Return  -> Ghostty"
info "  SUPER+Space   -> Rofi (app launcher)"
info "  SUPER+E       -> Thunar"
info "  SUPER+Q       -> Close window"
info "  SUPER+F       -> Fullscreen"
info "  SUPER+Up      -> Maximize"
info "  SUPER+Left    -> Snap left (repeat to cross monitors)"
info "  SUPER+Right   -> Snap right (repeat to cross monitors)"
info "  ALT+Tab       -> Window switcher (hyprswitch)"
info "  Print         -> Screenshot (select area)"
info "  SHIFT+Print   -> Screenshot (full screen)"
