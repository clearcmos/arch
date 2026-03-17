#!/bin/bash
# Screen off with DND for KDE Plasma 6 (Meta+F10)
# - Enables DND via plasmanotifyrc
# - Turns off screen
# - Starts watcher to auto-disable DND on wake

CONFIG="$HOME/.config/plasmanotifyrc"
STATE_FILE="$HOME/.cache/screen-off-active"
WATCHER_PID_FILE="$HOME/.cache/screen-off-watcher.pid"

export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

# Kill any existing watcher
if [[ -f "$WATCHER_PID_FILE" ]]; then
    OLD_PID=$(cat "$WATCHER_PID_FILE")
    kill "$OLD_PID" 2>/dev/null
    rm -f "$WATCHER_PID_FILE"
fi

if [[ -f "$STATE_FILE" ]]; then
    # Screen-off mode is active - disable DND
    if grep -q "^\[DoNotDisturb\]" "$CONFIG" 2>/dev/null; then
        sed -i '/^\[DoNotDisturb\]/,/^$/d' "$CONFIG"
    fi
    rm -f "$STATE_FILE"
    notify-send -i preferences-desktop-notification "Notifications" "Restored"
else
    # Enable DND and turn off screen
    if grep -q "^\[DoNotDisturb\]" "$CONFIG" 2>/dev/null; then
        sed -i 's/Until=.*/Until=2099-12-31T23:59:59/' "$CONFIG"
    else
        echo -e "\n[DoNotDisturb]\nUntil=2099-12-31T23:59:59" >> "$CONFIG"
    fi

    touch "$STATE_FILE"

    notify-send -i preferences-desktop-notification-bell "Notifications" "Muted - turning off screen"

    sleep 0.5

    qdbus org.kde.kglobalaccel /component/org_kde_powerdevil invokeShortcut "Turn Off Screen" 2>/dev/null

    # Start watcher to auto-restore on wake
    systemctl --user start screen-off-watcher.service
fi
