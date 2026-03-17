#!/bin/bash
# Turn BT on when USB hub reconnects (runs as root, relays to nicholas)
sleep 1
runuser -u nicholas -- \
    env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
        XDG_RUNTIME_DIR=/run/user/1000 \
    bash -c '
        Q30_MAC="E8:EE:CC:46:F1:AC"
        BT_POWERED=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk "{print \$2}")
        if [[ "$BT_POWERED" != "yes" ]]; then
            rfkill unblock bluetooth
            sleep 0.5
            bluetoothctl power on
            sleep 2
            if bluetoothctl connect "$Q30_MAC" 2>/dev/null; then
                notify-send -i audio-headphones "Bluetooth" "Connected to Soundcore Life Q30 (USB hub reconnected)"
            else
                notify-send -i bluetooth "Bluetooth" "Enabled (Q30 not available)"
            fi
        fi
    '
