#!/bin/bash
# Interactive package install with fzf search.
# Searches all pacman + AUR packages, lets you pick one, then installs it.
set -euo pipefail

PKG=$(paru -Slq | sort -u | fzf --prompt="Install package: " --preview="paru -Si {} 2>/dev/null" --preview-window=right:60%:wrap) || exit 0

[[ -z "$PKG" ]] && exit 0

paru -S "$PKG"
