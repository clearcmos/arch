#!/bin/bash
# Interactive package removal with fzf search.
# Lists all installed packages (official + AUR), lets you pick one, then removes it.
set -euo pipefail

PKG=$(expac --timefmt='%s' '%l\t%n' | sort -rn | cut -f2 | fzf --no-sort --prompt="Remove package: " --preview="pacman -Qi {}" --preview-window=right:60%:wrap) || exit 0

[[ -z "$PKG" ]] && exit 0

paru -R "$PKG"
