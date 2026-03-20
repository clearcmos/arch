#!/bin/bash
# Thin wrapper for pacman PreTransaction hook.
# Runs check-updates.sh --auto as the user (pacman hooks run as root).
# Exits 0 (allow) or 1 (block transaction).
# Gracefully exits 0 if Claude is not available.

set -euo pipefail

TARGET_USER="nicholas"
CHECK_SCRIPT="/home/$TARGET_USER/arch/tools/check-updates.sh"

if [[ ! -x "$CHECK_SCRIPT" ]]; then
    # Script not found, don't block
    exit 0
fi

# If running as root (pacman hook), run as the target user
if [[ "$(id -u)" -eq 0 ]]; then
    su - "$TARGET_USER" -c "$CHECK_SCRIPT --auto" || exit $?
else
    "$CHECK_SCRIPT" --auto || exit $?
fi
