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

    # --- Check multilib repo ---
    echo ""
    info "Checking multilib repo..."
    if grep -q '^\[multilib\]' /etc/pacman.conf; then
        ok "multilib enabled in pacman.conf"
    else
        warn "multilib not enabled - will be enabled on real run"
    fi

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
        "config/claude-code/settings.json"
        "config/ghostty/config.ghostty"
        "config/claude-code/CLAUDE.md"
        "config/shell/aliases.sh"
        "config/brave/brave-flags.conf"
        "config/fontconfig/fonts.conf"
        "config/environment.d/10-amd-gpu.conf"
        "config/environment.d/10-wayland.conf"
        "config/environment.d/20-gaming.conf"
        "config/kde/plasma-org.kde.plasma.desktop-appletsrc"
        "config/kde/plasmashellrc"
        "config/kde/powerdevilrc"
        "config/ssh/sshd_config"
        "config/ssh/authorized_keys"
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

    # --- Check mount points ---
    echo ""
    info "Checking mount points..."
    DATA_UUID="60d4fb47-d8fd-4445-adb0-2fd303da775b"
    if grep -q "$DATA_UUID" /etc/fstab 2>/dev/null; then
        ok "/mnt/data in fstab"
    else
        warn "/mnt/data not in fstab - will be added on real run"
    fi
    if grep -q "//192.168.1.4/syno" /etc/fstab 2>/dev/null; then
        ok "/mnt/syno in fstab"
    else
        warn "/mnt/syno not in fstab - will be added on real run"
    fi

    # --- Check GPU kernel config ---
    echo ""
    info "Checking AMD GPU kernel configuration..."
    if grep -q "amdgpu.gpu_recovery" /etc/default/grub 2>/dev/null; then
        ok "GRUB amdgpu params set"
    else
        warn "GRUB amdgpu params not set - will be added on real run"
    fi

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

    # --- Check SSH config ---
    echo ""
    info "Checking SSH configuration..."
    if diff -q "$SCRIPT_DIR/config/ssh/sshd_config" /etc/ssh/sshd_config &>/dev/null; then
        ok "sshd_config matches"
    else
        warn "sshd_config differs or missing - will be deployed on real run"
    fi
    if [[ -e "$HOME/.ssh/authorized_keys" ]]; then
        if diff -q "$SCRIPT_DIR/config/ssh/authorized_keys" "$HOME/.ssh/authorized_keys" &>/dev/null; then
            ok "authorized_keys matches"
        else
            warn "authorized_keys differs - will be updated on real run"
        fi
    else
        warn "authorized_keys not found - will be deployed on real run"
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

# --- Enable multilib repo ---

info "Ensuring multilib repo is enabled..."
if grep -q '^\[multilib\]' /etc/pacman.conf; then
    info "  multilib already enabled."
else
    # Uncomment the [multilib] section (header + Include line)
    sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    info "  enabled multilib repo."
fi

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

# --- AMD GPU Kernel Params ---

info "Configuring AMD GPU kernel parameters..."

# Add amdgpu kernel params to GRUB (idempotent)
GRUB_DEFAULT="/etc/default/grub"
AMDGPU_PARAMS="amdgpu.gpu_recovery=1"
if grep -q "amdgpu.gpu_recovery" "$GRUB_DEFAULT" 2>/dev/null; then
    info "  GRUB amdgpu params already set."
else
    sudo sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $AMDGPU_PARAMS\"/" "$GRUB_DEFAULT"
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    info "  added amdgpu params to GRUB and regenerated config."
fi

# --- KDE Font Rendering ---

info "Configuring KDE font rendering..."
if command -v kwriteconfig6 &>/dev/null; then
    kwriteconfig6 --group General --key XftSubPixel rgb
    kwriteconfig6 --group General --key XftHintStyle hintmedium
    kwriteconfig6 --group General --key XftAntialias 1
    info "  set KDE fonts: sub-pixel RGB, medium hinting, anti-aliasing on."
else
    warn "  kwriteconfig6 not found, skipping KDE font config (set manually in System Settings)."
fi

# --- KDE Monitor Layout (PLP: Portrait-Landscape-Portrait) ---

info "Applying KDE monitor layout..."
if command -v kscreen-doctor &>/dev/null; then
    # Check what monitors are connected
    KSCREEN_OUT=$(kscreen-doctor -o 2>&1) || true

    HDMI_CONNECTED=$(echo "$KSCREEN_OUT" | grep -c "HDMI-A-1" || true)
    DP2_CONNECTED=$(echo "$KSCREEN_OUT" | grep -c "DP-2" || true)
    DP1_CONNECTED=$(echo "$KSCREEN_OUT" | grep -c "DP-1" || true)

    if [[ "$HDMI_CONNECTED" -gt 0 && "$DP2_CONNECTED" -gt 0 && "$DP1_CONNECTED" -gt 0 ]]; then
        # Triple monitor PLP layout
        # Side monitors at 1.5 scale rotated = 960x1707 each
        # Middle monitor at 1.5 scale = 1707x960
        # Positions: left at 0,0, middle at 960,246, right at 2667,0
        kscreen-doctor \
            output.HDMI-A-1.mode.2560x1440@60 \
            output.HDMI-A-1.scale.1.5 \
            output.HDMI-A-1.rotation.left \
            output.HDMI-A-1.position.0,0 \
            output.HDMI-A-1.enable \
            output.DP-2.mode.2560x1440@60 \
            output.DP-2.scale.1.5 \
            output.DP-2.position.960,246 \
            output.DP-2.enable \
            output.DP-2.priority.1 \
            output.DP-1.mode.2560x1440@60 \
            output.DP-1.scale.1.5 \
            output.DP-1.rotation.left \
            output.DP-1.position.2667,0 \
            output.DP-1.enable
        info "  applied triple monitor PLP layout (DP-2 primary)."
    elif [[ "$DP2_CONNECTED" -gt 0 ]]; then
        # Single/partial - at least set DP-2 as primary
        kscreen-doctor \
            output.DP-2.mode.2560x1440@60 \
            output.DP-2.scale.1.5 \
            output.DP-2.enable \
            output.DP-2.priority.1
        info "  set DP-2 as primary."
    else
        warn "  expected monitors not detected, skipping layout."
    fi
else
    warn "  kscreen-doctor not found, skipping monitor layout."
fi

# --- Mount Points (fstab) ---

info "Configuring mount points..."

# Data disk (nvme0n1p1)
DATA_UUID="60d4fb47-d8fd-4445-adb0-2fd303da775b"
DATA_FSTAB="UUID=$DATA_UUID /mnt/data ext4 defaults 0 2"
if grep -q "$DATA_UUID" /etc/fstab 2>/dev/null; then
    info "  /mnt/data already in fstab."
else
    sudo mkdir -p /mnt/data
    echo "$DATA_FSTAB" | sudo tee -a /etc/fstab >/dev/null
    info "  added /mnt/data to fstab."
fi
sudo mkdir -p /mnt/data
mountpoint -q /mnt/data || sudo mount /mnt/data
info "  /mnt/data mounted."

# NAS (Synology)
SYNO_SHARE="//192.168.1.4/syno"
SYNO_FSTAB="$SYNO_SHARE /mnt/syno cifs credentials=/etc/cifs/credentials,uid=1000,gid=100,vers=3.0,file_mode=0770,dir_mode=0770,soft,nounix,serverino,mapposix,noauto,x-systemd.automount,x-systemd.idle-timeout=60 0 0"
if grep -q "$SYNO_SHARE" /etc/fstab 2>/dev/null; then
    info "  /mnt/syno already in fstab."
else
    sudo mkdir -p /mnt/syno
    echo "$SYNO_FSTAB" | sudo tee -a /etc/fstab >/dev/null
    info "  added /mnt/syno to fstab."
fi
sudo mkdir -p /mnt/syno
sudo systemctl daemon-reload
info "  /mnt/syno configured (automount on access)."

# --- SSH Configuration ---

info "Configuring SSH..."

# Deploy hardened sshd_config (key auth only, no root login)
if diff -q "$SCRIPT_DIR/config/ssh/sshd_config" /etc/ssh/sshd_config &>/dev/null; then
    info "  sshd_config already up to date."
else
    sudo cp "$SCRIPT_DIR/config/ssh/sshd_config" /etc/ssh/sshd_config
    sudo chmod 644 /etc/ssh/sshd_config
    info "  deployed sshd_config."
    if systemctl is-active sshd &>/dev/null; then
        sudo systemctl reload sshd
        info "  reloaded sshd."
    fi
fi

# Deploy authorized_keys for user nicholas
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if diff -q "$SCRIPT_DIR/config/ssh/authorized_keys" "$HOME/.ssh/authorized_keys" &>/dev/null; then
    info "  authorized_keys already up to date."
else
    cp "$SCRIPT_DIR/config/ssh/authorized_keys" "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
    info "  deployed authorized_keys."
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

# KDE panel layout (centered taskbar with spacers, non-floating)
link_config "$SCRIPT_DIR/config/kde/plasma-org.kde.plasma.desktop-appletsrc" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
link_config "$SCRIPT_DIR/config/kde/plasmashellrc" "$HOME/.config/plasmashellrc"
link_config "$SCRIPT_DIR/config/kde/powerdevilrc" "$HOME/.config/powerdevilrc"
link_config "$SCRIPT_DIR/config/kde/ksmserverrc" "$HOME/.config/ksmserverrc"

# Fontconfig (crisp font rendering: medium hinting, subpixel RGB, LCD filter)
link_config "$SCRIPT_DIR/config/fontconfig/fonts.conf" "$HOME/.config/fontconfig/fonts.conf"

# Environment variables (AMD GPU, Wayland)
link_config "$SCRIPT_DIR/config/environment.d/10-amd-gpu.conf" "$HOME/.config/environment.d/10-amd-gpu.conf"
link_config "$SCRIPT_DIR/config/environment.d/10-wayland.conf" "$HOME/.config/environment.d/10-wayland.conf"
link_config "$SCRIPT_DIR/config/environment.d/20-gaming.conf" "$HOME/.config/environment.d/20-gaming.conf"

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

# SDDM (system config, needs root)
sudo mkdir -p /etc/sddm.conf.d
sudo cp "$SCRIPT_DIR/config/sddm/sddm.conf" /etc/sddm.conf.d/kde.conf
info "  copied SDDM config to /etc/sddm.conf.d/kde.conf"

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
info "Reboot to apply changes."
