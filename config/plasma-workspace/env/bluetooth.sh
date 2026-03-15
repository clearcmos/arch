#!/bin/bash
# Auto-connect paired Bluetooth devices after login
sleep 3
bluetoothctl connect E8:EE:CC:46:F1:AC &>/dev/null &
