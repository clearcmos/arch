#!/bin/bash
# Self-service config deployment for work profile users.
# Reads from /usr/local/share/arch-work-profile/ and deploys to $HOME.
# Run as the work profile user (no sudo needed).
set -euo pipefail

SHARE_DIR="/usr/local/share/arch-work-profile"

info()  { printf '\033[0;32m[INFO]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }

if [[ ! -d "$SHARE_DIR" ]]; then
    warn "Shared config directory '$SHARE_DIR' not found."
    warn "Ask the primary user to run: ./setup.sh --work-profile"
    exit 1
fi

# Zsh config
if ! diff -q "$SHARE_DIR/zshrc" "$HOME/.zshrc" &>/dev/null; then
    cp "$SHARE_DIR/zshrc" "$HOME/.zshrc"
    info "deployed .zshrc"
else
    info ".zshrc already up to date."
fi

# Shell aliases and functions
mkdir -p "$HOME/.config/shell"

if ! diff -q "$SHARE_DIR/aliases-work.sh" "$HOME/.config/shell/aliases-work.sh" &>/dev/null; then
    cp "$SHARE_DIR/aliases-work.sh" "$HOME/.config/shell/aliases-work.sh"
    info "deployed aliases-work.sh"
else
    info "aliases-work.sh already up to date."
fi

if ! diff -q "$SHARE_DIR/functions-work.sh" "$HOME/.config/shell/functions-work.sh" &>/dev/null; then
    cp "$SHARE_DIR/functions-work.sh" "$HOME/.config/shell/functions-work.sh"
    info "deployed functions-work.sh"
else
    info "functions-work.sh already up to date."
fi

# KDE Wallet config
mkdir -p "$HOME/.config"

if ! diff -q "$SHARE_DIR/kwalletrc" "$HOME/.config/kwalletrc" &>/dev/null; then
    cp "$SHARE_DIR/kwalletrc" "$HOME/.config/kwalletrc"
    info "deployed kwalletrc"
else
    info "kwalletrc already up to date."
fi

info "Work profile config deployment complete."
info "Run 'source ~/.zshrc' or start a new shell to apply changes."
