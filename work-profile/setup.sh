#!/bin/bash
# Work profile environment setup
# Clone this repo and run this script as the work user. Sudo needed for NAS mount.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { printf '\033[0;32m[INFO]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$1"; }

# Idempotent copy - only copies if source and destination differ
deploy() {
    local src="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    if ! diff -q "$src" "$dest" &>/dev/null; then
        cp "$src" "$dest"
        info "deployed $dest"
    else
        info "$dest already up to date."
    fi
}

info "Setting up work profile environment..."

# Zsh config
deploy "$SCRIPT_DIR/.zshrc-work" "$HOME/.zshrc"

# Shell aliases and functions
deploy "$SCRIPT_DIR/aliases-work.sh" "$HOME/.config/shell/aliases-work.sh"
deploy "$SCRIPT_DIR/functions-work.sh" "$HOME/.config/shell/functions-work.sh"

# Idempotent symlink
link() {
    local src="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
    info "linked $dest"
}

# Claude Code global config
link "$SCRIPT_DIR/../config/claude-code/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# KDE Wallet config (shared with primary user)
deploy "$SCRIPT_DIR/../config/kde/kwalletrc" "$HOME/.config/kwalletrc"

# --- NAS Mount (Synology) ---

info "Configuring NAS mount..."

SYNO_SHARE="//192.168.1.4/syno"
SYNO_MNT="/mnt/syno-work"
SYNO_FSTAB="$SYNO_SHARE $SYNO_MNT cifs credentials=/etc/cifs/credentials,uid=$(id -u),gid=$(id -g),vers=3.0,file_mode=0770,dir_mode=0770,soft,nounix,serverino,mapposix,cache=loose,noauto,x-systemd.automount 0 0"

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

if grep -q "$SYNO_MNT" /etc/fstab 2>/dev/null; then
    info "  $SYNO_MNT already in fstab."
else
    sudo mkdir -p "$SYNO_MNT"
    echo "$SYNO_FSTAB" | sudo tee -a /etc/fstab >/dev/null
    sudo systemctl daemon-reload
    info "  added $SYNO_MNT to fstab."
fi

# Ensure NAS is mounted (automount may not trigger mid-script)
if mountpoint -q "$SYNO_MNT"; then
    info "  $SYNO_MNT mounted."
else
    sudo mount "$SYNO_MNT" || sudo mount -t cifs "$SYNO_SHARE" "$SYNO_MNT" \
        -o "credentials=/etc/cifs/credentials,uid=$(id -u),gid=$(id -g),vers=3.0" || true
    if mountpoint -q "$SYNO_MNT"; then
        info "  $SYNO_MNT mounted."
    else
        warn "  $SYNO_MNT failed to mount — NAS may be unreachable."
    fi
fi

# --- SSH Keys ---

info "Configuring SSH keys..."
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

for key in id_ed25519_work id_ed25519_personal; do
    if [[ -f "$HOME/.ssh/$key" ]]; then
        info "  SSH key $key already exists."
    else
        label="${key#id_ed25519_}"
        read -rp "  No SSH key for $label. Generate one? [y/N]: " yn < /dev/tty
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            ssh-keygen -t ed25519 -f "$HOME/.ssh/$key" -C "$key"
            info "  Add this public key to GitHub ($label):"
            cat "$HOME/.ssh/$key.pub"
            echo ""
        fi
    fi
done

# Add github.com host key to known_hosts
if ! grep -q 'github.com' "$HOME/.ssh/known_hosts" 2>/dev/null; then
    ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
    info "  added github.com to known_hosts."
else
    info "  github.com already in known_hosts."
fi

# --- Git Config ---

info "Configuring Git..."

if [[ -f "$HOME/.gitconfig" ]]; then
    info "  Git config already exists, skipping."
else
    read -rp "  Git name (for commits): " git_name < /dev/tty
    read -rp "  Git email (personal, default): " git_email_personal < /dev/tty
    read -rp "  Git email (work, for Optable repos): " git_email_work < /dev/tty

    cat > "$HOME/.gitconfig" <<EOF
[user]
    name = $git_name
    email = $git_email_personal
    useConfigOnly = true

[init]
    defaultBranch = main

[pull]
    rebase = true

[push]
    autoSetupRemote = true

[core]
    sshCommand = ssh -i ~/.ssh/id_ed25519_personal

[url "git@github.com:"]
    insteadOf = https://github.com/

[includeIf "hasconfig:remote.*.url:git@github.com:Optable/**"]
    path = ~/.gitconfig-work
EOF
    info "  wrote ~/.gitconfig"

    cat > "$HOME/.gitconfig-work" <<EOF
[user]
    name = $git_name
    email = $git_email_work

[core]
    sshCommand = ssh -i ~/.ssh/id_ed25519_work
EOF
    info "  wrote ~/.gitconfig-work"
fi

# --- GitHub CLI Auth ---

info "Configuring GitHub CLI..."

if ! command -v gh &>/dev/null; then
    warn "  gh not found, skipping GitHub CLI auth."
else
    if gh auth status &>/dev/null 2>&1; then
        info "  gh already authenticated."
    else
        echo ""
        echo "  GitHub CLI is not authenticated."
        echo "  This will open a browser to sign in."
        read -r -p "  Set up GitHub CLI now? [Y/n] " gh_auth < /dev/tty
        if [[ ! "$gh_auth" =~ ^[Nn]$ ]]; then
            gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key || true
            if gh auth status &>/dev/null 2>&1; then
                info "  gh authenticated successfully."
            else
                warn "  gh auth failed. Run manually later:"
                warn "    gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key"
            fi
        else
            warn "  Skipping gh auth. Run later:"
            warn "    gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key"
        fi
    fi
fi

info "Work profile setup complete."
info "Run 'source ~/.zshrc' or start a new shell to apply changes."
