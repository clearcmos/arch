#!/bin/bash
# One-shot first-login script. Runs setup.sh then removes itself from autostart.

AUTOSTART_FILE="$HOME/.config/autostart/first-login.desktop"

cd "$HOME/arch" || { echo "ERROR: ~/arch not found"; read -r; exit 1; }

echo "Running setup.sh..."
echo

rm -f "$AUTOSTART_FILE"

if ./setup.sh; then
    echo
    read -r -p "Setup complete! Reboot now? [Y/n] " answer
    if [[ ! "$answer" =~ ^[Nn]$ ]]; then
        sudo reboot now
    fi
else
    echo
    echo "Setup failed with errors."
    read -r -p "Open setup.log in nano? [Y/n] " answer
    if [[ ! "$answer" =~ ^[Nn]$ ]]; then
        nano "$HOME/arch/setup.log"
    fi
fi
