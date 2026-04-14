#!/bin/bash
# Work profile setup
# Sourced by setup.sh when --work-profile is passed. Not run standalone.
# Expects: SCRIPT_DIR, info(), warn(), error() from setup.sh
#
# Publishes work profile configs to /usr/local/share/arch-work-profile/ and
# installs a 'work-setup' command that the work user runs to deploy them.

SHARE_DIR="/usr/local/share/arch-work-profile"

read -r -p "Enter work profile username: " WORK_USER

if [[ -z "$WORK_USER" ]]; then
    error "No username provided, skipping work profile setup."
    return 0
fi

if ! id "$WORK_USER" &>/dev/null; then
    warn "User '$WORK_USER' does not exist, skipping work profile setup."
    return 0
fi

if [[ ! -d "/home/$WORK_USER" ]]; then
    warn "Home directory '/home/$WORK_USER' does not exist, skipping work profile setup."
    return 0
fi

info "Setting up work profile ($WORK_USER)..."

# Publish configs to shared location (root-owned, world-readable)
sudo mkdir -p "$SHARE_DIR"

sudo cp "$SCRIPT_DIR/config/zsh/.zshrc-work" "$SHARE_DIR/zshrc"
sudo cp "$SCRIPT_DIR/config/shell/aliases-work.sh" "$SHARE_DIR/aliases-work.sh"
sudo cp "$SCRIPT_DIR/config/shell/functions-work.sh" "$SHARE_DIR/functions-work.sh"
sudo cp "$SCRIPT_DIR/config/kde/kwalletrc" "$SHARE_DIR/kwalletrc"
sudo cp "$SCRIPT_DIR/config/work-profile/deploy.sh" "$SHARE_DIR/deploy.sh"
sudo chmod 755 "$SHARE_DIR/deploy.sh"
sudo chmod -R a+rX "$SHARE_DIR"
info "  published work profile configs to $SHARE_DIR"

# Install work-setup command
sudo ln -sf "$SHARE_DIR/deploy.sh" /usr/local/bin/work-setup
info "  installed 'work-setup' command"

# Set zsh as default shell for work user
if [[ "$(getent passwd "$WORK_USER" | cut -d: -f7)" != "/usr/bin/zsh" ]]; then
    sudo chsh -s /usr/bin/zsh "$WORK_USER"
    info "  default shell changed to zsh for $WORK_USER."
else
    info "  zsh already set as default shell for $WORK_USER."
fi

info "Work profile setup complete."
info "  The work user can now run 'work-setup' to deploy configs."
