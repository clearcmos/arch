# Arch repo aliases
alias arch='cd ~/arch'
alias a='cd ~/arch && claude'

# Claude Code
alias c='claude'

# Update checker
alias check-updates='~/arch/tools/check-updates.sh'
alias check-updates-quick='~/arch/tools/check-updates.sh --no-ai'

# GitHub repo management
alias gvis='ghrepo visibility'
alias gvisibility='ghrepo visibility'

# Quick commit and push with Ollama-generated messages
alias cpush='~/arch/bin/cpush'

# Standard
# ls is a function in functions.sh (adds git ownership tags in ~/git)
compress() { local target="${1:-.}"; local name=$(basename "$(realpath "$target")"); tar --zstd -cf "${name}.tar.zst" -C "$target" .; }
function du { command du -h --max-depth=1 "$@" | sort -h; }
alias gen='openssl rand -base64 45'
rcs() { rclone sync "$1" "$2" --metadata --transfers=32 --checkers=32 --stats-one-line -P -L --exclude-from <(find "$1" -xtype l -printf '%P\n'); }
alias mine='sudo chown -R $(whoami):$(whoami)'
alias r='sudo -i'
alias cpath='pwd | tr -d '\''\n'\'' | wl-copy && echo "Copied: $(pwd)"'
alias addons='cd "/mnt/data/games/World of Warcraft/_anniversary_/Interface/AddOns"'

# Google Tasks CLI
alias task='uv run ~/git/tasks/task.py'
