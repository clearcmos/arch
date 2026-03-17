#!/bin/bash
# Turn BT off when USB hub disconnects (runs as root, relays to nicholas)
sleep 1
runuser -u nicholas -- \
    env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
        XDG_RUNTIME_DIR=/run/user/1000 \
    bash -c '
        BT_POWERED=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk "{print \$2}")
        if [[ "$BT_POWERED" == "yes" ]]; then
            bluetoothctl power off
            rfkill block bluetooth
            notify-send -i bluetooth-disabled "Bluetooth" "Disabled (USB hub disconnected)"
        fi
    '
