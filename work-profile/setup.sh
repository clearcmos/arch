#!/bin/bash
# Work profile environment setup
# Clone this repo and run this script as the work user. No sudo needed.
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

# KDE Wallet config (shared with primary user)
deploy "$SCRIPT_DIR/../config/kde/kwalletrc" "$HOME/.config/kwalletrc"

info "Work profile setup complete."
info "Run 'source ~/.zshrc' or start a new shell to apply changes."
