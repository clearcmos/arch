# Work profile aliases

alias ls='ls -lh --color=auto --group-directories-first'
compress() { local target="${1:-.}"; local name=$(basename "$(realpath "$target")"); tar --zstd -cf "${name}.tar.zst" -C "$target" .; }
alias cpath='pwd | tr -d '\''\n'\'' | wl-copy && echo "Copied: $(pwd)"'
function du { command du -h --max-depth=1 "$@" | sort -h; }
alias gen='openssl rand -base64 45'
alias mine='sudo chown -R $(whoami):$(whoami)'
rcs() { rclone sync "$1" "$2" --transfers=32 --checkers=32 --stats-one-line -P -L --exclude-from <(find "$1" -xtype l -printf '%P\n'); }
