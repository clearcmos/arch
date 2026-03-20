#!/bin/bash
# Restart Brave to reload extensions from disk.
#
# Usage:
#   brave-reload-ext

set -euo pipefail

if ! pgrep -x brave >/dev/null 2>&1; then
    echo "Brave is not running."
    exit 1
fi

echo "Restarting Brave..."
pkill -x brave
while pgrep -x brave >/dev/null 2>&1; do
    sleep 0.2
done
nohup brave >/dev/null 2>&1 &
disown
echo "Brave restarted. Extensions reloaded."
