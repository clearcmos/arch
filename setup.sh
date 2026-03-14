#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Helpers ---

info()  { printf '\033[0;32m[INFO]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$1"; }

# Read a package list file, stripping comments and blanks
read_packages() {
    grep -v '^\s*#' "$1" | grep -v '^\s*$'
}

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
    git clone https://aur.archlinux.org/paru-bin.git "$_tmp/paru-bin"
    (cd "$_tmp/paru-bin" && makepkg -si --noconfirm)
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

# Waybar
link_config "$SCRIPT_DIR/config/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
link_config "$SCRIPT_DIR/config/waybar/style.css" "$HOME/.config/waybar/style.css"

# Rofi
link_config "$SCRIPT_DIR/config/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"

# greetd (system config, needs root)
sudo mkdir -p /etc/greetd
sudo cp "$SCRIPT_DIR/config/greetd/config.toml" /etc/greetd/config.toml
info "  copied greetd config to /etc/greetd/config.toml"

# --- Done ---

echo ""
info "Setup complete!"
info "Reboot to start with greetd + Hyprland."
info ""
info "Quick reference:"
info "  SUPER+Return  -> Ghostty"
info "  SUPER+Space   -> Rofi (app launcher)"
info "  SUPER+E       -> Dolphin"
info "  SUPER+Q       -> Close window"
info "  SUPER+F       -> Fullscreen"
info "  ALT+Tab       -> Cycle windows"
info "  Print         -> Screenshot (select area)"
info "  SHIFT+Print   -> Screenshot (full screen)"
