#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/setup.log"
exec > >(tee "$LOG_FILE") 2>&1
trap 'sleep 0.1' EXIT  # allow tee to flush
echo "=== setup.sh started at $(date) ==="

# --- Sudo keep-alive (ask once, refresh in background) ---

sudo -v
while true; do sudo -n true; sleep 55; kill -0 "$$" || exit; done 2>/dev/null &

# --- Helpers ---

info()  { printf '\033[0;32m[INFO]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$1"; }

# Read a package list file, stripping comments and blanks
read_packages() {
    grep -v '^\s*#' "$1" | grep -v '^\s*$'
}

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
    | xargs sudo pacman -S --needed --noconfirm --ask 4

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

# --- Rust (via rustup) ---

# Remove distro rust if present (conflicts with rustup, pulled in by paru build)
if pacman -Qi rust &>/dev/null && ! command -v rustup &>/dev/null; then
    info "Removing distro rust package (replaced by rustup)..."
    sudo pacman -Rdd --noconfirm rust
fi

if ! command -v rustup &>/dev/null; then
    info "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    info "Rust already installed, skipping."
fi

# --- AUR Packages ---

info "Installing AUR packages..."
read_packages "$SCRIPT_DIR/packages/aur.txt" \
    | xargs paru -S --needed --noconfirm

# --- Nix (Determinate Systems installer) ---

if [[ -f /nix/receipt.json ]]; then
    info "Nix already installed, skipping."
else
    info "Installing Nix..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
        | sh -s -- install --no-confirm
fi

# --- Claude Code ---

if [[ -e "$HOME/.local/bin/claude" ]]; then
    info "Claude Code already installed, skipping."
else
    info "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
    # Ensure ~/.local/bin is in PATH
    if ! grep -q '\.local/bin' "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        info "  added ~/.local/bin to PATH in ~/.bashrc"
    fi
    export PATH="$HOME/.local/bin:$PATH"
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
            sudo systemctl enable --now "$line"
            info "  enabled and started service '$line'."
        fi
    fi
done < "$SCRIPT_DIR/services.txt"

# Ensure pcscd is running (socket-activated but needed before YubiKey steps)
if ! systemctl is-active pcscd &>/dev/null; then
    sudo systemctl start pcscd
    info "  started pcscd (needed for YubiKey)."
fi

# --- AMD GPU Kernel Params ---

info "Configuring AMD GPU kernel parameters..."

# Add amdgpu kernel params to /etc/kernel/cmdline (systemd-boot)
KERNEL_PARAMS=(
    "amdgpu.gpu_recovery=1"
    "nmi_watchdog=0"
)
ALL_SET=true
for param in "${KERNEL_PARAMS[@]}"; do
    key="${param%%=*}"
    if ! grep -q "$key" /etc/kernel/cmdline 2>/dev/null; then
        ALL_SET=false
        break
    fi
done
if $ALL_SET; then
    info "  kernel cmdline params already set."
else
    if [[ -f /etc/kernel/cmdline ]]; then
        CMDLINE=$(cat /etc/kernel/cmdline)
    else
        CMDLINE=$(cat /proc/cmdline)
    fi
    for param in "${KERNEL_PARAMS[@]}"; do
        key="${param%%=*}"
        if ! echo "$CMDLINE" | grep -q "$key"; then
            CMDLINE="$CMDLINE $param"
        fi
    done
    echo "$CMDLINE" | sudo tee /etc/kernel/cmdline >/dev/null
    sudo kernel-install add "$(uname -r)" /usr/lib/modules/"$(uname -r)"/vmlinuz
    info "  added kernel params and regenerated boot entry."
fi

# --- Font Rendering (system-level fontconfig) ---

info "Configuring system font rendering..."
FONT_CONF_AVAIL="/usr/share/fontconfig/conf.avail"
FONT_CONF_D="/etc/fonts/conf.d"
font_presets=(
    "10-sub-pixel-rgb.conf"
    "10-hinting-slight.conf"
    "10-yes-antialias.conf"
    "11-lcdfilter-default.conf"
)
for preset in "${font_presets[@]}"; do
    if [ ! -e "$FONT_CONF_D/$preset" ]; then
        sudo ln -s "$FONT_CONF_AVAIL/$preset" "$FONT_CONF_D/$preset"
        info "  enabled $preset"
    fi
done

# Deploy local.conf (overrides KDE's user-level fonts.conf, loaded via 51-local.conf)
if diff -q "$SCRIPT_DIR/config/fontconfig/local.conf" /etc/fonts/local.conf &>/dev/null; then
    info "  /etc/fonts/local.conf already up to date."
else
    sudo cp "$SCRIPT_DIR/config/fontconfig/local.conf" /etc/fonts/local.conf
    info "  deployed /etc/fonts/local.conf"
fi

# --- Disable WiFi (desktop uses Ethernet only) ---

info "Disabling WiFi..."
nmcli radio wifi off
info "  WiFi disabled."

# --- KDE Lock Screen (disabled) ---

info "Disabling KDE lock screen..."
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock false || true
kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockOnResume false || true
info "  lock screen disabled."

# --- KDE Hot Corners (disabled) ---

info "Disabling KDE hot corners..."
kwriteconfig6 --file kwinrc --group Effect-overview --key BorderActivate 9 || true
kwriteconfig6 --file kwinrc --group ElectricBorders --key TopLeft None || true
kwriteconfig6 --file kwinrc --group ElectricBorders --key TopRight None || true
kwriteconfig6 --file kwinrc --group ElectricBorders --key BottomLeft None || true
kwriteconfig6 --file kwinrc --group ElectricBorders --key BottomRight None || true
info "  hot corners disabled."
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key Overview "none,Meta+W,Toggle Overview" || true
info "  Overview shortcut disabled (takes effect after re-login)."

# --- KDE Dark Theme ---

info "Applying KDE dark theme..."
kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark || true
kwriteconfig6 --file kdeglobals --group General --key ColorSchemeHash "" || true
info "  set BreezeDark color scheme (applies on first KDE login)."

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

# Create CIFS credentials file if missing
if [[ ! -f /etc/cifs/credentials ]]; then
    echo ""
    info "CIFS credentials file not found at /etc/cifs/credentials."
    read -r -p "Create it now for NAS mount? [y/N] " create_creds
    if [[ "$create_creds" =~ ^[Yy]$ ]]; then
        read -r -p "NAS username: " nas_user
        read -r -s -p "NAS password: " nas_pass
        echo ""
        sudo mkdir -p /etc/cifs
        printf 'username=%s\npassword=%s\n' "$nas_user" "$nas_pass" | sudo tee /etc/cifs/credentials >/dev/null
        sudo chmod 600 /etc/cifs/credentials
        info "  created /etc/cifs/credentials."
    else
        warn "  skipping CIFS credentials - NAS mount will fail without it."
    fi
else
    info "  CIFS credentials file already exists."
fi

if grep -q "$SYNO_SHARE" /etc/fstab 2>/dev/null; then
    info "  /mnt/syno already in fstab."
else
    sudo mkdir -p /mnt/syno
    echo "$SYNO_FSTAB" | sudo tee -a /etc/fstab >/dev/null
    info "  added /mnt/syno to fstab."
fi
sudo mkdir -p /mnt/syno
sudo systemctl daemon-reload

# Ensure NAS is mounted (automount may not trigger mid-script)
if ! mountpoint -q /mnt/syno; then
    sudo mount /mnt/syno || sudo mount -t cifs "$SYNO_SHARE" /mnt/syno \
        -o credentials=/etc/cifs/credentials,uid=1000,gid=100,vers=3.0 || true
fi

if mountpoint -q /mnt/syno; then
    info "  /mnt/syno mounted."
else
    warn "  /mnt/syno failed to mount — NAS steps will be skipped."
fi

# --- SSH Key (restore from NAS, encrypted with YubiKey) ---

info "Restoring SSH key..."
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_BACKUP_DIR="/mnt/syno/backups/ssh/cmos-arch"

if [[ -f "$SSH_KEY" ]]; then
    info "  SSH key already exists, skipping."
else
    if [[ -f "$SSH_BACKUP_DIR/id_ed25519.age" ]]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        echo ""
        echo "  SSH key restore requires YubiKey."
        read -r -p "  Is your YubiKey plugged in? [Y/n] " yk_ready
        if [[ "$yk_ready" =~ ^[Nn]$ ]]; then
            warn "  skipping SSH key restore. Re-run setup.sh with YubiKey plugged in."
        else
        info "  decrypting SSH key from NAS (touch YubiKey when it blinks)..."
        age -d -i "$SCRIPT_DIR/config/age/yubikey-identity.txt" \
            -o "$SSH_KEY" "$SSH_BACKUP_DIR/id_ed25519.age"
        chmod 600 "$SSH_KEY"
        cp "$SSH_BACKUP_DIR/id_ed25519.pub" "$HOME/.ssh/id_ed25519.pub"
        chmod 644 "$HOME/.ssh/id_ed25519.pub"
        info "  SSH key restored."
        fi
    else
        warn "  no SSH backup found at $SSH_BACKUP_DIR, skipping."
        warn "  generate a key manually: ssh-keygen -t ed25519"
    fi
fi

# --- Git & GitHub ---

info "Configuring Git and GitHub..."
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
sort -u -o "$HOME/.ssh/known_hosts" "$HOME/.ssh/known_hosts"
info "  added github.com to known_hosts."

git config --global user.name "clearcmos"
git config --global user.email "noreply"
git config --global core.sshCommand "ssh"
git config --global url."git@github.com:".insteadOf "https://github.com/"
info "  set git identity (clearcmos <noreply>), SSH for all GitHub repos."

if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null 2>&1; then
        info "  gh already authenticated."
    else
        echo ""
        echo "  GitHub CLI is not authenticated."
        echo "  This will open a browser — sign in with your YubiKey passkey."
        read -r -p "  Set up GitHub CLI now? [Y/n] " gh_auth
        if [[ ! "$gh_auth" =~ ^[Nn]$ ]]; then
            gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key || true
            if gh auth status &>/dev/null 2>&1; then
                info "  gh authenticated successfully."
            else
                warn "  gh auth failed. Run manually later:"
                warn "    gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key"
            fi
        else
            warn "  skipping gh auth. Run later:"
            warn "    gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key"
        fi
    fi
else
    warn "  gh not found, skipping GitHub CLI auth."
fi

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

# Helper: copy a config file (for KDE files that break symlinks via atomic writes)
copy_config() {
    local src="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    info "  copied $dest"
}

# KDE panel layout (centered taskbar with spacers, non-floating)
# NOTE: KDE configs use cp, not symlinks — KConfig's QSaveFile atomic writes break symlinks
copy_config "$SCRIPT_DIR/config/kde/plasma-org.kde.plasma.desktop-appletsrc" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
copy_config "$SCRIPT_DIR/config/kde/plasmashellrc" "$HOME/.config/plasmashellrc"
copy_config "$SCRIPT_DIR/config/kde/powerdevilrc" "$HOME/.config/powerdevilrc"
copy_config "$SCRIPT_DIR/config/kde/ksmserverrc" "$HOME/.config/ksmserverrc"
copy_config "$SCRIPT_DIR/config/kde/kwinoutputconfig.json" "$HOME/.config/kwinoutputconfig.json"

# Bluetooth main config (system-level, requires root)
BT_CONFIG_CHANGED=false
if ! diff -q "$SCRIPT_DIR/config/bluetooth/main.conf" /etc/bluetooth/main.conf &>/dev/null; then
    sudo cp "$SCRIPT_DIR/config/bluetooth/main.conf" /etc/bluetooth/main.conf
    BT_CONFIG_CHANGED=true
    info "  copied /etc/bluetooth/main.conf"
else
    info "  /etc/bluetooth/main.conf already up to date."
fi

# WirePlumber Bluetooth audio (codecs, roles, hardware volume)
link_config "$SCRIPT_DIR/config/wireplumber/51-bluez-config.conf" "$HOME/.config/wireplumber/wireplumber.conf.d/51-bluez-config.conf"

# Bluetooth auto-connect on login
link_config "$SCRIPT_DIR/config/autostart/bluetooth.desktop" "$HOME/.config/autostart/bluetooth.desktop"

# Environment variables (AMD GPU, Wayland)
link_config "$SCRIPT_DIR/config/environment.d/10-amd-gpu.conf" "$HOME/.config/environment.d/10-amd-gpu.conf"
link_config "$SCRIPT_DIR/config/environment.d/10-wayland.conf" "$HOME/.config/environment.d/10-wayland.conf"
link_config "$SCRIPT_DIR/config/environment.d/20-gaming.conf" "$HOME/.config/environment.d/20-gaming.conf"
link_config "$SCRIPT_DIR/config/environment.d/30-ai.conf" "$HOME/.config/environment.d/30-ai.conf"

# Brave
link_config "$SCRIPT_DIR/config/brave/brave-flags.conf" "$HOME/.config/brave-flags.conf"

# Claude Code
link_config "$SCRIPT_DIR/config/claude-code/settings.json" "$HOME/.claude/settings.json"
link_config "$SCRIPT_DIR/config/claude-code/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# Shell aliases
link_config "$SCRIPT_DIR/config/shell/aliases.sh" "$HOME/.config/shell/aliases.sh"

# Shell functions
link_config "$SCRIPT_DIR/config/shell/functions.sh" "$HOME/.config/shell/functions.sh"

# Shell scripts -> ~/.local/bin/
mkdir -p "$HOME/.local/bin"
for script in getrepo gpush gscan create-repo repo ghelp bt-toggle screen-off-toggle screen-off-watcher usb-hub-bt-off usb-hub-bt-on; do
    chmod +x "$SCRIPT_DIR/config/shell/${script}.sh"
    ln -sf "$SCRIPT_DIR/config/shell/${script}.sh" "$HOME/.local/bin/$script"
done
info "  linked shell scripts to ~/.local/bin/"

# Source aliases and functions from bashrc if not already present
if ! grep -q 'shell/aliases.sh' "$HOME/.bashrc" 2>/dev/null; then
    echo '' >> "$HOME/.bashrc"
    echo '# Custom aliases' >> "$HOME/.bashrc"
    echo '[ -f "$HOME/.config/shell/aliases.sh" ] && source "$HOME/.config/shell/aliases.sh"' >> "$HOME/.bashrc"
    info "  added aliases source line to ~/.bashrc"
fi

if ! grep -q 'shell/functions.sh' "$HOME/.bashrc" 2>/dev/null; then
    echo '[ -f "$HOME/.config/shell/functions.sh" ] && source "$HOME/.config/shell/functions.sh"' >> "$HOME/.bashrc"
    info "  added functions source line to ~/.bashrc"
fi

# greetd (login manager, system config, needs root)
sudo cp "$SCRIPT_DIR/config/greetd/config.toml" /etc/greetd/config.toml
sudo cp "$SCRIPT_DIR/config/greetd/pam-greetd" /etc/pam.d/greetd
info "  deployed greetd config and PAM (KWallet auto-unlock)."

# Quiet console (suppress noisy kernel messages on greetd TTY)
sudo cp "$SCRIPT_DIR/config/sysctl/99-quiet-console.conf" /etc/sysctl.d/99-quiet-console.conf
sudo sysctl --load /etc/sysctl.d/99-quiet-console.conf &>/dev/null
info "  deployed sysctl quiet console config."

# Kernel modules
if [[ ! -f /etc/modules-load.d/i2c-dev.conf ]]; then
    sudo cp "$SCRIPT_DIR/config/modules-load/i2c-dev.conf" /etc/modules-load.d/i2c-dev.conf
    sudo modprobe i2c-dev
    info "  enabled i2c-dev module (for ddcutil)."
else
    info "  i2c-dev module already configured."
fi

# Brave policies (system-wide, needs root)
sudo mkdir -p /etc/brave/policies/managed
sudo cp "$SCRIPT_DIR/config/brave/policies.json" /etc/brave/policies/managed/policies.json
info "  copied Brave policies to /etc/brave/policies/managed/"

# --- Lutris (Battle.net config) ---

info "Configuring Lutris..."
LUTRIS_GAMES_DIR="$HOME/.local/share/lutris/games"
LUTRIS_DB="$HOME/.local/share/lutris/pga.db"
BNET_CONFIG="battlenet-standard-1773703119.yml"

mkdir -p "$LUTRIS_GAMES_DIR"
cp "$SCRIPT_DIR/config/lutris/$BNET_CONFIG" "$LUTRIS_GAMES_DIR/$BNET_CONFIG"
info "  deployed Battle.net game config."

# Seed the Lutris DB entry if missing
if [[ -f "$LUTRIS_DB" ]] && command -v sqlite3 &>/dev/null; then
    if ! sqlite3 "$LUTRIS_DB" "SELECT id FROM games WHERE slug='battlenet';" | grep -q .; then
        sqlite3 "$LUTRIS_DB" "INSERT INTO games (name, slug, installer_slug, platform, runner, directory, installed, installed_at, year, configpath) VALUES ('Battle.net', 'battlenet', 'battlenet-standard', 'Windows', 'wine', '/mnt/data/games/battlenet', 1, $(date +%s), 1996, 'battlenet-standard-1773703119');"
        info "  added Battle.net to Lutris database."
    else
        info "  Battle.net already in Lutris database."
    fi
fi

# --- CurseForge (seed WoW Retail game instance) ---

CF_INSTANCE_DIR="$HOME/.config/CurseForge/agent/GameInstances"
CF_INSTANCE_FILE="$CF_INSTANCE_DIR/AddonGameInstance.json"
if [[ -f "$CF_INSTANCE_FILE" ]]; then
    info "CurseForge game instance already exists, skipping."
else
    mkdir -p "$CF_INSTANCE_DIR"
    cp "$SCRIPT_DIR/config/CurseForge/AddonGameInstance.json" "$CF_INSTANCE_FILE"
    info "Seeded CurseForge WoW Retail game instance."
fi

# --- IPv4 Preference ---

info "Configuring IPv4 preference..."
if grep -q '^precedence ::ffff:0:0/96  100' /etc/gai.conf 2>/dev/null; then
    info "  IPv4 preference already set."
else
    sudo sed -i 's/^#precedence ::ffff:0:0\/96  100/precedence ::ffff:0:0\/96  100/' /etc/gai.conf
    info "  enabled IPv4 preference in /etc/gai.conf."
fi

# --- Local DNS Entries ---

info "Configuring local DNS entries..."
declare -A DNS_ENTRIES=(
    ["money.home.arpa"]="127.0.0.1"
    ["dashboard.home.arpa"]="127.0.0.1"
    ["meds.home.arpa"]="127.0.0.1"
)
for host in "${!DNS_ENTRIES[@]}"; do
    if grep -q "$host" /etc/hosts 2>/dev/null; then
        info "  $host already in /etc/hosts."
    else
        echo "${DNS_ENTRIES[$host]} $host" | sudo tee -a /etc/hosts >/dev/null
        info "  added $host to /etc/hosts."
    fi
done

# --- Bluetooth Devices ---

# Only restart bluetooth if main.conf was changed (avoids disconnecting devices)
if $BT_CONFIG_CHANGED; then
    sudo systemctl restart bluetooth
    sleep 1
    info "  restarted bluetooth (config changed)."
fi

info "Configuring Bluetooth devices..."

Q30_MAC="E8:EE:CC:46:F1:AC"

if bluetoothctl info "$Q30_MAC" 2>/dev/null | grep -q "Paired: yes"; then
    info "  Soundcore Life Q30 ($Q30_MAC) already paired."
else
    info "  Soundcore Life Q30 ($Q30_MAC) not paired."
    read -r -p "Pair now? Put headphones in pairing mode first. [y/N] " pair_bt
    if [[ "$pair_bt" =~ ^[Yy]$ ]]; then
        bluetoothctl power on &>/dev/null
        info "  scanning for device (up to 30s)..."
        bluetoothctl --timeout 30 scan on &>/dev/null &
        SCAN_PID=$!
        BT_FOUND=false
        for i in $(seq 1 30); do
            if bluetoothctl devices 2>/dev/null | grep -q "$Q30_MAC"; then
                BT_FOUND=true
                break
            fi
            sleep 1
        done
        kill "$SCAN_PID" 2>/dev/null; wait "$SCAN_PID" 2>/dev/null || true
        if $BT_FOUND; then
            bluetoothctl pair "$Q30_MAC" && info "  paired Soundcore Life Q30."
            bluetoothctl trust "$Q30_MAC" && info "  trusted Soundcore Life Q30."
            bluetoothctl connect "$Q30_MAC" && info "  connected Soundcore Life Q30."
        else
            warn "  device not found after 30s, skipping."
        fi
    else
        warn "  skipping Bluetooth pairing."
    fi
fi

# Ensure device is trusted (idempotent)
if bluetoothctl info "$Q30_MAC" 2>/dev/null | grep -q "Trusted: yes"; then
    info "  Soundcore Life Q30 already trusted."
else
    bluetoothctl trust "$Q30_MAC" 2>/dev/null && info "  trusted Soundcore Life Q30." || true
fi

# --- Fail2ban (SSH protection) ---

info "Configuring fail2ban..."
if diff -q "$SCRIPT_DIR/config/fail2ban/jail.local" /etc/fail2ban/jail.local &>/dev/null; then
    info "  fail2ban jail.local already up to date."
else
    sudo cp "$SCRIPT_DIR/config/fail2ban/jail.local" /etc/fail2ban/jail.local
    info "  deployed fail2ban jail.local."
fi
if systemctl is-enabled fail2ban &>/dev/null; then
    info "  fail2ban already enabled."
    sudo systemctl reload fail2ban || sudo systemctl restart fail2ban
    info "  reloaded fail2ban."
else
    sudo systemctl enable --now fail2ban
    info "  enabled and started fail2ban."
fi

# --- Docker ---

info "Configuring Docker..."
if ! groups nicholas | grep -q docker; then
    sudo usermod -aG docker nicholas
    info "  added nicholas to docker group."
else
    info "  nicholas already in docker group."
fi
sudo mkdir -p /etc/docker
if ! diff -q "$SCRIPT_DIR/config/docker/daemon.json" /etc/docker/daemon.json &>/dev/null; then
    sudo cp "$SCRIPT_DIR/config/docker/daemon.json" /etc/docker/daemon.json
    info "  deployed docker daemon.json."
else
    info "  docker daemon.json already up to date."
fi
if systemctl is-enabled docker &>/dev/null; then
    info "  docker already enabled."
else
    sudo systemctl enable --now docker
    info "  enabled and started docker."
fi
sudo mkdir -p /opt/docker-compose
sudo chown nicholas:docker /opt/docker-compose

# --- Libvirt/KVM ---

info "Configuring Libvirt/KVM..."
for grp in libvirt kvm render; do
    if ! groups nicholas | grep -q "$grp"; then
        sudo usermod -aG "$grp" nicholas
        info "  added nicholas to $grp group."
    fi
done
if systemctl is-enabled libvirtd &>/dev/null; then
    info "  libvirtd already enabled."
else
    sudo systemctl enable --now libvirtd
    info "  enabled and started libvirtd."
fi

# --- Cockpit ---

info "Configuring Cockpit..."
sudo mkdir -p /etc/cockpit
if ! diff -q "$SCRIPT_DIR/config/cockpit/cockpit.conf" /etc/cockpit/cockpit.conf &>/dev/null; then
    sudo cp "$SCRIPT_DIR/config/cockpit/cockpit.conf" /etc/cockpit/cockpit.conf
    info "  deployed cockpit.conf."
else
    info "  cockpit.conf already up to date."
fi
if systemctl is-enabled cockpit.socket &>/dev/null; then
    info "  cockpit already enabled."
else
    sudo systemctl enable --now cockpit.socket
    info "  enabled cockpit."
fi

# --- USB Hub Bluetooth Toggle ---

info "Configuring USB hub Bluetooth toggle..."
if ! diff -q "$SCRIPT_DIR/config/udev/99-usb-hub-bt-toggle.rules" /etc/udev/rules.d/99-usb-hub-bt-toggle.rules &>/dev/null; then
    sudo cp "$SCRIPT_DIR/config/udev/99-usb-hub-bt-toggle.rules" /etc/udev/rules.d/99-usb-hub-bt-toggle.rules
    sudo udevadm control --reload-rules
    info "  deployed udev rules and reloaded."
else
    info "  udev rules already up to date."
fi
sudo cp "$SCRIPT_DIR/config/systemd/usb-hub-bt-off.service" /etc/systemd/system/usb-hub-bt-off.service
sudo cp "$SCRIPT_DIR/config/systemd/usb-hub-bt-on.service" /etc/systemd/system/usb-hub-bt-on.service
sudo systemctl daemon-reload
info "  deployed USB hub BT toggle services."

# --- KWin Scripts (Meta+F10 Screen Off, Meta+F11 BT Toggle) ---

info "Configuring KWin scripts..."
# Deploy user systemd services
mkdir -p "$HOME/.config/systemd/user"
cp "$SCRIPT_DIR/config/systemd/user/screen-off-toggle.service" "$HOME/.config/systemd/user/"
cp "$SCRIPT_DIR/config/systemd/user/screen-off-watcher.service" "$HOME/.config/systemd/user/"
cp "$SCRIPT_DIR/config/systemd/user/bt-toggle.service" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
info "  deployed user systemd services."

# Deploy KWin scripts
chmod +x "$SCRIPT_DIR/config/kwin/setup-kwin-scripts.sh"
bash "$SCRIPT_DIR/config/kwin/setup-kwin-scripts.sh"
info "  deployed KWin scripts (Meta+F10, Meta+F11)."

# --- Done ---

echo ""
info "Setup complete!"
info "Some changes may require a reboot to take effect."
