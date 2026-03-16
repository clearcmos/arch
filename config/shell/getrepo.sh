#!/bin/bash
# Search GitHub repos with fzf, copy SSH URL to clipboard
set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: getrepo <search-term>"
    exit 1
fi

query="$1"
results=$(gh search repos "$query" --json fullName --limit 100 --sort stars 2>/dev/null)

if [ -z "$results" ] || [ "$results" = "[]" ]; then
    echo "No repos found matching '$query'"
    exit 1
fi

selected=$(echo "$results" | jq -r '.[].fullName' | fzf --query="$query" --prompt="repo> " --height=~40% --reverse)

if [ -z "$selected" ]; then
    exit 0
fi

url="git@github.com:$selected.git"
echo "$url" | tr -d '\n' | wl-copy
echo "Copied: $url"
