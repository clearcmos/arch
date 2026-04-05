# Arch repo aliases
alias arch='cd ~/arch'
alias a='cd ~/arch && claude'

# Claude Code
alias c='claude'

# Update checker
alias check-updates='~/arch/tools/check-updates.sh'

# Standard
alias ls='ls -lh --color=auto --group-directories-first'
alias compress='dir=$(basename "$(pwd)"); tar -czf "${dir}.tar.gz" ./*'
alias gen='openssl rand -base64 45'
alias mine='sudo chown -R $(whoami):$(whoami)'
alias r='sudo -i'
alias cpath='pwd | tr -d '\''\n'\'' | wl-copy && echo "Copied: $(pwd)"'
alias addons='cd "/mnt/data/games/World of Warcraft/_anniversary_/Interface/AddOns"'

# Google Tasks CLI
alias task='uv run ~/git/tasks/task.py'
