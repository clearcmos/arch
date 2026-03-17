#!/bin/bash
# Bluetooth toggle for KDE (Meta+F11)
# If BT on -> turn off
# If BT off -> turn on and connect Q30 headphones

Q30_MAC="E8:EE:CC:46:F1:AC"

BT_POWERED=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk '{print $2}')

if [[ "$BT_POWERED" == "yes" ]]; then
    bluetoothctl power off
    rfkill block bluetooth
    notify-send -i bluetooth-disabled "Bluetooth" "Disabled"
else
    rfkill unblock bluetooth
    sleep 0.5
    bluetoothctl power on
    sleep 2

    if bluetoothctl connect "$Q30_MAC" 2>/dev/null; then
        notify-send -i audio-headphones "Bluetooth" "Connected to Soundcore Life Q30"
    else
        notify-send -i bluetooth "Bluetooth" "Enabled (Q30 not available)"
    fi
fi
