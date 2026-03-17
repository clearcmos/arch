#!/bin/bash
# Watches for screen wake (user activity) and restores notifications

CONFIG="$HOME/.config/plasmanotifyrc"
STATE_FILE="$HOME/.cache/screen-off-active"
WATCHER_PID_FILE="$HOME/.cache/screen-off-watcher.pid"

export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

echo $$ > "$WATCHER_PID_FILE"

sleep 5

SESSION_ID=$(loginctl show-user "$(id -un)" -P Sessions 2>/dev/null | tr ' ' '\n' | head -1)

WAITED=0
MAX_WAIT=60

# Phase 1: Wait for idle (screen off) or timeout
while [[ "$WAITED" -lt "$MAX_WAIT" ]]; do
    if [[ ! -f "$STATE_FILE" ]]; then
        rm -f "$WATCHER_PID_FILE"
        exit 0
    fi

    IDLE_HINT=$(loginctl show-session "$SESSION_ID" -P IdleHint 2>/dev/null)
    if [[ "$IDLE_HINT" == "yes" ]]; then
        break
    fi

    sleep 1
    WAITED=$((WAITED + 1))
done

# Timeout - clean up
if [[ "$WAITED" -ge "$MAX_WAIT" ]]; then
    if [[ -f "$STATE_FILE" ]]; then
        if grep -q "^\[DoNotDisturb\]" "$CONFIG" 2>/dev/null; then
            sed -i '/^\[DoNotDisturb\]/,/^$/d' "$CONFIG"
        fi
        rm -f "$STATE_FILE"
        notify-send -i preferences-desktop-notification "Notifications" "Restored (timeout)"
    fi
    rm -f "$WATCHER_PID_FILE"
    exit 0
fi

# Phase 2: User is idle, wait for them to become active
while true; do
    if [[ ! -f "$STATE_FILE" ]]; then
        rm -f "$WATCHER_PID_FILE"
        exit 0
    fi

    IDLE_HINT=$(loginctl show-session "$SESSION_ID" -P IdleHint 2>/dev/null)
    if [[ "$IDLE_HINT" == "no" ]]; then
        if [[ -f "$STATE_FILE" ]]; then
            if grep -q "^\[DoNotDisturb\]" "$CONFIG" 2>/dev/null; then
                sed -i '/^\[DoNotDisturb\]/,/^$/d' "$CONFIG"
            fi
            rm -f "$STATE_FILE"
            notify-send -i preferences-desktop-notification "Notifications" "Restored (screen woke)"
        fi
        rm -f "$WATCHER_PID_FILE"
        exit 0
    fi

    sleep 1
done
