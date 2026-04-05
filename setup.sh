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

# --- Locale ---

info "Ensuring en_CA.UTF-8 locale is generated..."
if locale -a 2>/dev/null | grep -q 'en_CA.utf8'; then
    info "  en_CA.UTF-8 already generated."
else
    sudo sed -i 's/^#en_CA.UTF-8 UTF-8/en_CA.UTF-8 UTF-8/' /etc/locale.gen
    sudo locale-gen
    info "  generated en_CA.UTF-8 locale."
fi

# --- Enable multilib repo ---

info "Ensuring multilib repo is enabled..."
if grep -q '^\[multilib\]' /etc/pacman.conf; then
    info "  multilib already enabled."
else
    # Uncomment the [multilib] section (header + Include line)
    sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    info "  enabled multilib repo."
fi

# --- Pre-upgrade Safety Check ---

if command -v claude &>/dev/null && claude auth status &>/dev/null 2>&1; then
    info "Running pre-upgrade safety check..."
    if ! "$SCRIPT_DIR/tools/check-updates.sh" --auto; then
        error "Pre-upgrade check flagged issues. Review above."
        read -r -p "Continue anyway? [y/N] " force_upgrade
        if [[ ! "$force_upgrade" =~ ^[Yy]$ ]]; then
            error "Upgrade aborted."
            exit 1
        fi
    fi
else
    info "Claude not available - skipping pre-upgrade analysis."
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
    | xargs paru -S --needed

# Save installed PKGBUILDs for post-auth audit
info "Saving AUR PKGBUILDs for audit..."
PKGBUILD_DIR="$SCRIPT_DIR/pkgbuilds"
mkdir -p "$PKGBUILD_DIR"
while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    cache_dir="$HOME/.cache/paru/clone/$pkg"
    if [[ -f "$cache_dir/PKGBUILD" ]]; then
        mkdir -p "$PKGBUILD_DIR/$pkg"
        cp "$cache_dir/PKGBUILD" "$PKGBUILD_DIR/$pkg/"
        # Copy .install files if present
        for f in "$cache_dir"/*.install; do
            [[ -f "$f" ]] && cp "$f" "$PKGBUILD_DIR/$pkg/"
        done
    fi
done < <(read_packages "$SCRIPT_DIR/packages/aur.txt")
info "  saved PKGBUILDs to pkgbuilds/"

# --- Lite XL (custom fork with fractional scaling) ---

if pacman -Q lite-xl-custom &>/dev/null; then
    info "lite-xl-custom already installed, skipping."
else
    info "Building lite-xl-custom from fork..."
    _tmp=$(mktemp -d)
    git clone https://github.com/clearcmos/lite-xl.git "$_tmp/lite-xl-custom"
    (cd "$_tmp/lite-xl-custom" && makepkg -si --noconfirm)
    rm -rf "$_tmp"
fi

# --- foot (custom fork with tabs) ---

if pacman -Q foot-custom &>/dev/null; then
    info "foot-custom already installed, skipping."
else
    info "Building foot-custom from fork..."
    _tmp=$(mktemp -d)
    git clone https://github.com/clearcmos/foot.git "$_tmp/foot-custom"
    (cd "$_tmp/foot-custom" && makepkg -si --noconfirm)
    rm -rf "$_tmp"
fi

# --- Nix (Determinate Systems installer) ---

if [[ -f /nix/receipt.json ]]; then
    info "Nix already installed, skipping."
else
    info "Installing Nix..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
        | sh -s -- install --no-confirm
fi

# Nix store signing key (required for nixos-rebuild --target-host to misc/jimmich)
NIX_SIGNING_KEY="/etc/nix/signing-key.sec"
NIX_SIGNING_BACKUP="/mnt/syno/backups/cmos/nix-signing-key.age"
if [[ -f "$NIX_SIGNING_KEY" ]]; then
    info "Nix signing key already exists, skipping."
else
    if [[ -f "$NIX_SIGNING_BACKUP" ]]; then
        info "  decrypting Nix signing key from NAS (enter passphrase)..."
        age -d -o "$NIX_SIGNING_KEY" "$NIX_SIGNING_BACKUP"
        chmod 600 "$NIX_SIGNING_KEY"
        info "  Nix signing key restored."
    else
        warn "  no Nix signing key backup found at $NIX_SIGNING_BACKUP, skipping."
        warn "  generate one: nix key generate-secret --key-name cmos-arch > $NIX_SIGNING_KEY"
    fi
fi
if ! grep -q 'secret-key-files' /etc/nix/nix.custom.conf 2>/dev/null; then
    echo "secret-key-files = $NIX_SIGNING_KEY" | tee -a /etc/nix/nix.custom.conf
    info "  added secret-key-files to nix.custom.conf."
fi

# Nix packages
for nix_pkg in nixpkgs#nixos-rebuild github:ryantm/agenix; do
    pkg_name="${nix_pkg##*#}"
    pkg_name="${pkg_name##*/}"
    if nix profile list 2>/dev/null | grep -q "$pkg_name"; then
        info "  nix: $pkg_name already installed."
    else
        nix profile install "$nix_pkg"
        info "  nix: installed $pkg_name."
    fi
done

# nix-scan is a local flake -- clone if missing, then install
if [[ ! -f "$HOME/git/nix-scan/flake.nix" ]]; then
    mkdir -p "$HOME/git"
    git clone git@github.com:clearcmos/nix-scan.git "$HOME/git/nix-scan"
    info "  cloned nix-scan to ~/git/nix-scan."
fi
if nix profile list 2>/dev/null | grep -q "nix-scan"; then
    info "  nix: nix-scan already installed."
else
    nix profile install "git+file://$HOME/git/nix-scan"
    info "  nix: installed nix-scan."
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

# --- Bun ---

if command -v bun &>/dev/null; then
    info "Bun already installed, skipping."
else
    info "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
fi

# Install global Bun packages
if command -v tsc &>/dev/null; then
    info "TypeScript already installed, skipping."
else
    info "Installing TypeScript via Bun..."
    bun add -g typescript
fi

# --- depot_tools (Chromium build tools) ---

if grep -q 'depot_tools' "$HOME/.bashrc" 2>/dev/null; then
    info "depot_tools already in PATH, skipping."
else
    echo 'export PATH="$HOME/git/depot_tools:$PATH"' >> "$HOME/.bashrc"
    info "  added ~/git/depot_tools to PATH in ~/.bashrc"
fi
export PATH="$HOME/git/depot_tools:$PATH"

# --- uv tools ---

if uv tool list 2>/dev/null | grep -q '^instawow '; then
    info "instawow already installed, skipping."
else
    info "Installing instawow (fork with ignore list)..."
    uv tool install git+https://github.com/clearcmos/instawow.git
fi

# --- Enable Services (config-free) ---
# Services that need config deployed first are enabled inline in their own sections:
#   nftables   (before sshd, firewall must be up first)
#   fail2ban   (before sshd, brute force protection must be up first)
#   sshd       (after nftables + fail2ban + config/ssh/sshd_config)
#   bluetooth  (after config/bluetooth/main.conf)
#   docker     (after config/docker/daemon.json)
#   libvirtd   (after group memberships)
#   cockpit    (after config/cockpit/cockpit.conf)
#   ollama     (after systemd override for model path)
#   xremap     (after udev rules and service file)
#   ydotool    (after service file)

info "Enabling services..."
for svc in NetworkManager greetd pcscd tailscaled systemd-oomd; do
    if systemctl is-enabled "$svc" &>/dev/null; then
        info "  $svc already enabled."
    else
        sudo systemctl enable --now "$svc"
        info "  enabled and started $svc."
    fi
done

# Ensure pcscd is running (socket-activated but needed before YubiKey steps)
if ! systemctl is-active pcscd &>/dev/null; then
    sudo systemctl start pcscd
    info "  started pcscd (needed for YubiKey)."
fi

# --- Boot Entry Management (kernel-install / systemd-boot) ---

info "Configuring kernel-install and systemd-boot..."

# Set entry token to "arch" so boot entries are named arch-<version>.conf
# (required for "default arch-*" in loader.conf to match correctly)
if [[ "$(cat /etc/kernel/entry-token 2>/dev/null)" != "arch" ]]; then
    echo "arch" | sudo tee /etc/kernel/entry-token >/dev/null
    info "  set kernel-install entry token to 'arch'."
else
    info "  kernel-install entry token already set."
fi

# Mask mkinitcpio pacman hooks -- kernel-install's 50-mkinitcpio.install
# plugin handles initrd generation. Without masking, mkinitcpio runs twice
# per kernel upgrade (once from pacman hook, once from kernel-install plugin).
for hook in 60-mkinitcpio-remove.hook 90-mkinitcpio-install.hook; do
    if [[ ! -L "/etc/pacman.d/hooks/$hook" ]]; then
        sudo mkdir -p /etc/pacman.d/hooks
        sudo ln -sf /dev/null "/etc/pacman.d/hooks/$hook"
        info "  masked $hook (kernel-install handles this)."
    fi
done

# --- AMD GPU Kernel Params ---

info "Configuring AMD GPU kernel parameters..."

# Build kernel cmdline for /etc/kernel/cmdline (used by kernel-install).
# Do NOT include initrd= here -- kernel-install's 90-loaderentry.install
# sets the initrd via the BLS entry's "initrd" field.
KERNEL_PARAMS=(
    "amdgpu.gpu_recovery=1"
    "nmi_watchdog=0"
)
CMDLINE_CHANGED=false

# Initialize cmdline from existing file or /proc/cmdline
if [[ -f /etc/kernel/cmdline ]]; then
    CMDLINE=$(cat /etc/kernel/cmdline)
else
    CMDLINE=$(cat /proc/cmdline)
fi

# Strip initrd= from cmdline (kernel-install handles initrd via BLS entry)
CMDLINE_CLEAN=$(echo "$CMDLINE" | sed 's/initrd=[^ ]* *//')
if [[ "$CMDLINE_CLEAN" != "$CMDLINE" ]]; then
    CMDLINE="$CMDLINE_CLEAN"
    CMDLINE_CHANGED=true
fi

# Add missing kernel params
for param in "${KERNEL_PARAMS[@]}"; do
    key="${param%%=*}"
    if ! echo "$CMDLINE" | grep -q "$key"; then
        CMDLINE="$CMDLINE $param"
        CMDLINE_CHANGED=true
    fi
done

if $CMDLINE_CHANGED; then
    echo "$CMDLINE" | sudo tee /etc/kernel/cmdline >/dev/null
    info "  updated kernel cmdline."
else
    info "  kernel cmdline already up to date."
fi

# Ensure systemd-boot always boots the latest Arch kernel by default
if ! grep -q '^default arch-\*' /boot/loader/loader.conf 2>/dev/null; then
    sudo sed -i '/^default /d' /boot/loader/loader.conf
    echo "default arch-*" | sudo tee -a /boot/loader/loader.conf >/dev/null
    info "  set systemd-boot default to latest arch kernel."
else
    info "  systemd-boot default already set."
fi

# Remove stale archinstall boot entries (they reference /vmlinuz-linux which
# is not updated by kernel-install and will boot old kernels after updates)
for entry in /boot/loader/entries/*_linux.conf; do
    [[ -e "$entry" ]] || continue
    if grep -q "Created by: archinstall" "$entry"; then
        sudo rm "$entry"
        info "  removed stale archinstall boot entry: $(basename "$entry")"
    fi
done

# Migrate from machine-id to arch entry token if old entries exist
MACHINE_ID=$(cat /etc/machine-id)
if [[ -d "/boot/$MACHINE_ID" ]]; then
    sudo kernel-install add-all
    sudo rm -rf "/boot/$MACHINE_ID"
    # Remove old machine-id based entry files
    for entry in /boot/loader/entries/"$MACHINE_ID"-*.conf; do
        [[ -e "$entry" ]] || continue
        sudo rm "$entry"
    done
    info "  migrated boot entries from machine-id to arch token."
elif ! ls /boot/arch/*/linux &>/dev/null; then
    # No boot entries exist yet (fresh install), create them
    sudo kernel-install add-all
    info "  created initial boot entries."
else
    info "  boot entries already using arch token."
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
DATA_FSTAB="UUID=$DATA_UUID /mnt/data ext4 defaults,nosuid,nodev 0 2"
if grep -q "$DATA_UUID" /etc/fstab 2>/dev/null; then
    # Ensure nosuid,nodev flags are present on existing entry
    if ! grep "$DATA_UUID" /etc/fstab | grep -q 'nosuid'; then
        sudo sed -i "/$DATA_UUID/ s/ext4.*defaults/ext4 defaults,nosuid,nodev/" /etc/fstab
        info "  added nosuid,nodev to /mnt/data in fstab."
    else
        info "  /mnt/data already in fstab."
    fi
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
SYNO_FSTAB="$SYNO_SHARE /mnt/syno cifs credentials=/etc/cifs/credentials,uid=1000,gid=100,vers=3.0,file_mode=0770,dir_mode=0770,soft,nounix,serverino,mapposix,cache=loose,noauto,x-systemd.automount 0 0"

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

# --- SSH Key (restore from NAS, passphrase-encrypted) ---

info "Restoring SSH key..."
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_BACKUP_DIR="/mnt/syno/backups/cmos"

if [[ -f "$SSH_KEY" ]]; then
    info "  SSH key already exists, skipping."
else
    if [[ -f "$SSH_BACKUP_DIR/id_ed25519.age" ]]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        echo ""
        info "  decrypting SSH key from NAS (enter passphrase)..."
        age -d -o "$SSH_KEY" "$SSH_BACKUP_DIR/id_ed25519.age"
        chmod 600 "$SSH_KEY"
        cp "$SSH_BACKUP_DIR/id_ed25519.pub" "$HOME/.ssh/id_ed25519.pub"
        chmod 644 "$HOME/.ssh/id_ed25519.pub"
        info "  SSH key restored."
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
        echo "  This will open a browser — sign in to GitHub to authorize the CLI."
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

# --- Firewall (nftables + fail2ban, before sshd starts) ---

info "Configuring firewall..."
if ! diff -q "$SCRIPT_DIR/config/nftables/nftables.conf" /etc/nftables.conf &>/dev/null; then
    sudo cp "$SCRIPT_DIR/config/nftables/nftables.conf" /etc/nftables.conf
    info "  deployed nftables.conf."
else
    info "  nftables.conf already up to date."
fi
if systemctl is-enabled nftables &>/dev/null; then
    info "  nftables already enabled."
else
    sudo systemctl enable --now nftables
    info "  enabled nftables firewall."
fi

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
if systemctl is-enabled sshd &>/dev/null; then
    info "  sshd already enabled."
else
    sudo systemctl enable --now sshd
    info "  enabled and started sshd."
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
copy_config "$SCRIPT_DIR/config/kde/kcminputrc" "$HOME/.config/kcminputrc"
copy_config "$SCRIPT_DIR/config/kde/kxkbrc" "$HOME/.config/kxkbrc"

# Bluetooth main config (system-level, requires root)
BT_CONFIG_CHANGED=false
if ! diff -q "$SCRIPT_DIR/config/bluetooth/main.conf" /etc/bluetooth/main.conf &>/dev/null; then
    sudo cp "$SCRIPT_DIR/config/bluetooth/main.conf" /etc/bluetooth/main.conf
    BT_CONFIG_CHANGED=true
    info "  copied /etc/bluetooth/main.conf"
else
    info "  /etc/bluetooth/main.conf already up to date."
fi
if systemctl is-enabled bluetooth &>/dev/null; then
    info "  bluetooth already enabled."
else
    sudo systemctl enable --now bluetooth
    info "  enabled and started bluetooth."
fi

# WirePlumber Bluetooth audio (codecs, roles, hardware volume)
link_config "$SCRIPT_DIR/config/wireplumber/51-bluez-config.conf" "$HOME/.config/wireplumber/wireplumber.conf.d/51-bluez-config.conf"

# Bluetooth auto-connect on login
link_config "$SCRIPT_DIR/config/autostart/bluetooth.desktop" "$HOME/.config/autostart/bluetooth.desktop"
link_config "$SCRIPT_DIR/config/autostart/monitors.desktop" "$HOME/.config/autostart/monitors.desktop"

# Environment variables (AMD GPU, Wayland)
link_config "$SCRIPT_DIR/config/environment.d/10-amd-gpu.conf" "$HOME/.config/environment.d/10-amd-gpu.conf"
link_config "$SCRIPT_DIR/config/environment.d/10-wayland.conf" "$HOME/.config/environment.d/10-wayland.conf"
link_config "$SCRIPT_DIR/config/environment.d/20-gaming.conf" "$HOME/.config/environment.d/20-gaming.conf"
link_config "$SCRIPT_DIR/config/environment.d/30-ai.conf" "$HOME/.config/environment.d/30-ai.conf"

# Foot terminal
link_config "$SCRIPT_DIR/config/foot/foot.ini" "$HOME/.config/foot/foot.ini"

# GameMode (AMD GPU performance)
link_config "$SCRIPT_DIR/config/gamemode.ini" "$HOME/.config/gamemode.ini"

# Brave
link_config "$SCRIPT_DIR/config/brave/brave-flags.conf" "$HOME/.config/brave-flags.conf"
if ! diff -q "$SCRIPT_DIR/config/brave/policies/policies.json" /etc/brave/policies/managed/policies.json &>/dev/null; then
    sudo mkdir -p /etc/brave/policies/managed
    sudo cp "$SCRIPT_DIR/config/brave/policies/policies.json" /etc/brave/policies/managed/policies.json
    info "  copied Brave policies to /etc/brave/policies/managed/"
else
    info "  Brave policies already up to date."
fi

# Web apps (Brave PWAs)
link_config "$SCRIPT_DIR/config/applications/brave-okhfeehhillipaleckndoboggdkcebmo-Default.desktop" "$HOME/.local/share/applications/brave-okhfeehhillipaleckndoboggdkcebmo-Default.desktop"
link_config "$SCRIPT_DIR/config/applications/brave-kippjfofjhjlffjecoapiogbkgbpmgej-Default.desktop" "$HOME/.local/share/applications/brave-kippjfofjhjlffjecoapiogbkgbpmgej-Default.desktop"
for size in 32x32 48x48 128x128 256x256; do
    link_config "$SCRIPT_DIR/config/icons/hicolor/$size/apps/brave-okhfeehhillipaleckndoboggdkcebmo-Default.png" "$HOME/.local/share/icons/hicolor/$size/apps/brave-okhfeehhillipaleckndoboggdkcebmo-Default.png"
    link_config "$SCRIPT_DIR/config/icons/hicolor/$size/apps/brave-kippjfofjhjlffjecoapiogbkgbpmgej-Default.png" "$HOME/.local/share/icons/hicolor/$size/apps/brave-kippjfofjhjlffjecoapiogbkgbpmgej-Default.png"
done
link_config "$SCRIPT_DIR/config/icons/hicolor/512x512/apps/brave-kippjfofjhjlffjecoapiogbkgbpmgej-Default.png" "$HOME/.local/share/icons/hicolor/512x512/apps/brave-kippjfofjhjlffjecoapiogbkgbpmgej-Default.png"

# paru (AUR helper)
link_config "$SCRIPT_DIR/config/paru/paru.conf" "$HOME/.config/paru/paru.conf"

# xremap (per-app key remapping - arrow keys for Konsole tab switching)
if ! diff -q "$SCRIPT_DIR/config/udev/99-xremap.rules" /etc/udev/rules.d/99-xremap.rules &>/dev/null; then
    sudo cp "$SCRIPT_DIR/config/udev/99-xremap.rules" /etc/udev/rules.d/99-xremap.rules
    sudo udevadm control --reload-rules
    info "  copied xremap udev rules."
else
    info "  xremap udev rules already up to date."
fi
link_config "$SCRIPT_DIR/config/xremap/config.yml" "$HOME/.config/xremap/config.yml"
copy_config "$SCRIPT_DIR/config/xremap/xremap.service" "$HOME/.config/systemd/user/xremap.service"
if ! systemctl --user is-enabled xremap.service &>/dev/null; then
    systemctl --user daemon-reload
    systemctl --user enable --now xremap.service
    info "  enabled and started xremap service."
else
    systemctl --user daemon-reload
    systemctl --user restart xremap.service
    info "  restarted xremap service."
fi

# ydotool (synthetic key injection for xremap mode switching)
if ! systemctl --user is-enabled ydotool.service &>/dev/null; then
    systemctl --user enable --now ydotool.service
    info "  enabled and started ydotool service."
else
    info "  ydotool service already enabled."
fi

# Zsh
link_config "$SCRIPT_DIR/config/zsh/.zshrc" "$HOME/.zshrc"

# Claude Code
link_config "$SCRIPT_DIR/config/claude-code/settings.json" "$HOME/.claude/settings.json"
link_config "$SCRIPT_DIR/config/claude-code/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# Instawow
link_config "$SCRIPT_DIR/config/instawow/profiles/__default__/config.json" "$HOME/.config/instawow/profiles/__default__/config.json"
link_config "$SCRIPT_DIR/config/instawow/profiles/__default__/ignore.txt" "$HOME/.config/instawow/profiles/__default__/ignore.txt"

# Shell aliases
link_config "$SCRIPT_DIR/config/shell/aliases.sh" "$HOME/.config/shell/aliases.sh"

# Shell functions
link_config "$SCRIPT_DIR/config/shell/functions.sh" "$HOME/.config/shell/functions.sh"

# Lite XL
mkdir -p "$HOME/.config/lite-xl/plugins"
link_config "$SCRIPT_DIR/config/lite-xl/init.lua" "$HOME/.config/lite-xl/init.lua"
link_config "$SCRIPT_DIR/config/lite-xl/plugins/language_yaml.lua" "$HOME/.config/lite-xl/plugins/language_yaml.lua"

# 1Password secret references
link_config "$SCRIPT_DIR/config/op/secrets.env" "$HOME/.config/op/secrets.env"

# Shell scripts -> ~/.local/bin/
mkdir -p "$HOME/.local/bin"
for script in getrepo gpush gscan create-repo repo ghelp bt-toggle screen-off-toggle screen-off-watcher usb-hub-bt-off usb-hub-bt-on flushdns check-cert nuke-secret video myspace claude-clean mergepdf audit-pkgbuild audit-aur check-upgrades-hook brave-reload-ext remove-pkg install-pkg article2md article2pdf t; do
    chmod +x "$SCRIPT_DIR/config/shell/${script}.sh"
    ln -sf "$SCRIPT_DIR/config/shell/${script}.sh" "$HOME/.local/bin/$script"
done
info "  linked shell scripts to ~/.local/bin/"

# Standalone bin scripts -> ~/.local/bin/
for script in "$SCRIPT_DIR"/bin/*; do
    [[ -f "$script" ]] || continue
    chmod +x "$script"
    ln -sf "$script" "$HOME/.local/bin/$(basename "$script")"
done
info "  linked bin/ scripts to ~/.local/bin/"

# Set zsh as default shell
if [[ "$(getent passwd nicholas | cut -d: -f7)" != "/usr/bin/zsh" ]]; then
    info "Setting zsh as default shell..."
    chsh -s /usr/bin/zsh
    info "  default shell changed to zsh (takes effect on next login)."
else
    info "  zsh already set as default shell."
fi

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

# Pacman hooks
sudo mkdir -p /etc/pacman.d/hooks
if ! diff -q "$SCRIPT_DIR/config/pacman/check-upgrades.hook" /etc/pacman.d/hooks/check-upgrades.hook &>/dev/null; then
    sudo cp "$SCRIPT_DIR/config/pacman/check-upgrades.hook" /etc/pacman.d/hooks/check-upgrades.hook
    info "  deployed pacman pre-upgrade hook."
else
    info "  pacman pre-upgrade hook already up to date."
fi
for hook in kernel-install.hook kernel-install-remove.hook; do
    if ! diff -q "$SCRIPT_DIR/config/pacman/$hook" "/etc/pacman.d/hooks/$hook" &>/dev/null; then
        sudo cp "$SCRIPT_DIR/config/pacman/$hook" "/etc/pacman.d/hooks/$hook"
        info "  deployed $hook."
    else
        info "  $hook already up to date."
    fi
done

# Quiet console (suppress noisy kernel messages on greetd TTY)
sudo cp "$SCRIPT_DIR/config/sysctl/99-quiet-console.conf" /etc/sysctl.d/99-quiet-console.conf
sudo sysctl --load /etc/sysctl.d/99-quiet-console.conf &>/dev/null
info "  deployed sysctl quiet console config."

# Kernel hardening (kptr_restrict, rp_filter)
sudo cp "$SCRIPT_DIR/config/sysctl/99-hardening.conf" /etc/sysctl.d/99-hardening.conf
sudo sysctl --load /etc/sysctl.d/99-hardening.conf &>/dev/null
info "  deployed sysctl hardening config."

# Desktop memory tuning (zram + swappiness)
sudo cp "$SCRIPT_DIR/config/sysctl/99-desktop.conf" /etc/sysctl.d/99-desktop.conf
sudo sysctl --load /etc/sysctl.d/99-desktop.conf &>/dev/null
info "  deployed sysctl desktop memory config."

# zram (compressed swap in RAM)
sudo mkdir -p /etc/systemd
sudo cp "$SCRIPT_DIR/config/zram-generator/zram-generator.conf" /etc/systemd/zram-generator.conf
info "  deployed zram-generator config."

# Account lockout (explicit faillock settings)
sudo cp "$SCRIPT_DIR/config/security/faillock.conf" /etc/security/faillock.conf
info "  deployed faillock.conf."

# Remove nullok from PAM (disallow passwordless account login)
if grep -q 'nullok' /etc/pam.d/system-auth 2>/dev/null; then
    sudo sed -i 's/ nullok//g' /etc/pam.d/system-auth
    info "  removed nullok from system-auth."
else
    info "  system-auth already hardened (no nullok)."
fi

# Harden /boot mount options (add nosuid,nodev if not present)
if grep -q '/boot.*vfat' /etc/fstab && ! grep '/boot' /etc/fstab | grep -q 'nosuid'; then
    sudo sed -i '/\/boot.*vfat/ s/rw,relatime/rw,nosuid,nodev,relatime/' /etc/fstab
    info "  added nosuid,nodev to /boot in fstab."
else
    info "  /boot fstab already hardened."
fi


# Kernel modules
if [[ ! -f /etc/modules-load.d/i2c-dev.conf ]]; then
    sudo cp "$SCRIPT_DIR/config/modules-load/i2c-dev.conf" /etc/modules-load.d/i2c-dev.conf
    sudo modprobe i2c-dev
    info "  enabled i2c-dev module (for ddcutil)."
else
    info "  i2c-dev module already configured."
fi

# Bluetooth USB autosuspend (prevents BT adapter dropping out)
if ! diff -q "$SCRIPT_DIR/config/modprobe.d/btusb.conf" /etc/modprobe.d/btusb.conf &>/dev/null; then
    sudo cp "$SCRIPT_DIR/config/modprobe.d/btusb.conf" /etc/modprobe.d/btusb.conf
    info "  copied /etc/modprobe.d/btusb.conf"
else
    info "  /etc/modprobe.d/btusb.conf already up to date."
fi


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

# --- Discord (skip built-in update nag, let pacman manage it) ---

info "Configuring Discord..."
DISCORD_SETTINGS="$HOME/.config/discord/settings.json"
mkdir -p "$(dirname "$DISCORD_SETTINGS")"
if [[ -f "$DISCORD_SETTINGS" ]]; then
    if jq -e '.SKIP_HOST_UPDATE == true' "$DISCORD_SETTINGS" &>/dev/null; then
        info "  SKIP_HOST_UPDATE already set."
    else
        jq '. + {"SKIP_HOST_UPDATE": true}' "$DISCORD_SETTINGS" > "$DISCORD_SETTINGS.tmp" \
            && mv "$DISCORD_SETTINGS.tmp" "$DISCORD_SETTINGS"
        info "  set SKIP_HOST_UPDATE in Discord settings."
    fi
else
    echo '{"SKIP_HOST_UPDATE": true}' > "$DISCORD_SETTINGS"
    info "  created Discord settings with SKIP_HOST_UPDATE."
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

# --- CUPS (LAN printing) ---

info "Configuring CUPS..."
if ! groups nicholas | grep -q scanner; then
    sudo usermod -aG scanner nicholas
    info "  added nicholas to scanner group."
else
    info "  nicholas already in scanner group."
fi
if ! diff -q "$SCRIPT_DIR/config/cups/cupsd.conf" /etc/cups/cupsd.conf &>/dev/null; then
    sudo cp "$SCRIPT_DIR/config/cups/cupsd.conf" /etc/cups/cupsd.conf
    sudo systemctl restart cups
    info "  deployed cupsd.conf and restarted CUPS."
else
    info "  cupsd.conf already up to date."
fi

# --- Ollama ---

info "Configuring Ollama..."
sudo mkdir -p /etc/systemd/system/ollama.service.d
if ! diff -q "$SCRIPT_DIR/config/systemd/ollama.service.d/override.conf" /etc/systemd/system/ollama.service.d/override.conf &>/dev/null; then
    sudo cp "$SCRIPT_DIR/config/systemd/ollama.service.d/override.conf" /etc/systemd/system/ollama.service.d/override.conf
    sudo systemctl daemon-reload
    info "  deployed ollama override (OLLAMA_MODELS=/mnt/data/ollama/)."
fi
if systemctl is-enabled ollama &>/dev/null; then
    info "  ollama already enabled."
else
    sudo systemctl enable --now ollama
    info "  enabled and started ollama."
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

# --- System Dashboard ---

info "Configuring System Dashboard..."
DASHBOARD_DIR="$HOME/git/system-dashboard"
if [[ -d "$DASHBOARD_DIR" ]]; then
    # Set up Python venv if missing
    if [[ ! -d "$DASHBOARD_DIR/.venv" ]]; then
        python3 -m venv "$DASHBOARD_DIR/.venv"
        "$DASHBOARD_DIR/.venv/bin/pip" install -q -r "$DASHBOARD_DIR/backend/requirements.txt"
        info "  created venv and installed dependencies."
    else
        info "  venv already exists."
    fi

    # Deploy systemd service
    if ! diff -q "$SCRIPT_DIR/config/systemd/system-dashboard.service" /etc/systemd/system/system-dashboard.service &>/dev/null; then
        sudo cp "$SCRIPT_DIR/config/systemd/system-dashboard.service" /etc/systemd/system/system-dashboard.service
        sudo systemctl daemon-reload
        info "  deployed system-dashboard.service."
    else
        info "  system-dashboard.service already up to date."
    fi

    if systemctl is-enabled system-dashboard &>/dev/null; then
        info "  system-dashboard already enabled."
        sudo systemctl restart system-dashboard
        info "  restarted system-dashboard."
    else
        sudo systemctl enable --now system-dashboard
        info "  enabled and started system-dashboard."
    fi
else
    warn "  ~/git/system-dashboard not found, skipping."
fi

# --- Timer CLI ---

info "Configuring Timer CLI..."
TIMER_DIR="$HOME/git/timer-cli"
if [[ -d "$TIMER_DIR" ]]; then
    # Set up Python venv if missing
    if [[ ! -d "$TIMER_DIR/.venv" ]]; then
        python3 -m venv "$TIMER_DIR/.venv"
        "$TIMER_DIR/.venv/bin/pip" install -q requests pyjwt cryptography rich firebase-admin dbus-python
        info "  created venv and installed dependencies."
    else
        info "  venv already exists."
    fi

    # Create secrets directory
    mkdir -p "$HOME/.config/timer-cli/secrets"

    # Deploy KDE timer notifications user service
    cp "$SCRIPT_DIR/config/systemd/user/kde-timer-notifications.service" "$HOME/.config/systemd/user/"
    systemctl --user daemon-reload
    if [[ -f "$HOME/.config/timer-cli/secrets/firebase-service-account.json" ]]; then
        if systemctl --user is-enabled kde-timer-notifications &>/dev/null; then
            systemctl --user restart kde-timer-notifications
            info "  restarted kde-timer-notifications."
        else
            systemctl --user enable --now kde-timer-notifications
            info "  enabled and started kde-timer-notifications."
        fi
    else
        info "  secrets not yet placed, skipping kde-timer-notifications start."
        info "  decrypt secrets to ~/.config/timer-cli/secrets/ then enable manually."
    fi
else
    warn "  ~/git/timer-cli not found, skipping."
fi

# --- Done ---

echo ""
info "Setup complete!"
info "Some changes may require a reboot to take effect."
