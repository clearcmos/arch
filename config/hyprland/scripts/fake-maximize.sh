#!/bin/bash
# Fake maximize: resize floating window to fill monitor workarea.
# Keeps window in the floating layer so z-ordering works naturally.
# Toggles: run once to maximize, again to restore.

ACTIVE=$(hyprctl activewindow -j)
ADDR=$(echo "$ACTIVE" | jq -r '.address')
FLOATING=$(echo "$ACTIVE" | jq -r '.floating')

if [[ "$FLOATING" != "true" || -z "$ADDR" || "$ADDR" == "null" ]]; then
    exit 0
fi

STATE_DIR="/tmp/hypr-fake-maximize"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/$ADDR"

if [[ -f "$STATE_FILE" ]]; then
    read -r OX OY OW OH < "$STATE_FILE"
    hyprctl --batch "dispatch movewindowpixel exact $OX $OY,address:$ADDR ; dispatch resizewindowpixel exact $OW $OH,address:$ADDR"
    rm "$STATE_FILE"
else
    # Save current geometry
    X=$(echo "$ACTIVE" | jq -r '.at[0]')
    Y=$(echo "$ACTIVE" | jq -r '.at[1]')
    W=$(echo "$ACTIVE" | jq -r '.size[0]')
    H=$(echo "$ACTIVE" | jq -r '.size[1]')
    echo "$X $Y $W $H" > "$STATE_FILE"

    # Get monitor info and calculate workarea
    MON_ID=$(echo "$ACTIVE" | jq -r '.monitor')
    read -r NX NY NW NH < <(hyprctl monitors -j | python3 -c "
import sys, json
monitors = json.load(sys.stdin)
m = [x for x in monitors if x['id'] == $MON_ID][0]

scale = m['scale']
transform = m['transform']
mx, my = m['x'], m['y']

ew = int(m['width'] / scale)
eh = int(m['height'] / scale)
if transform in (1, 3):
    ew, eh = eh, ew

# reserved = [left, right, top, bottom]
r_left, r_right, r_top, r_bottom = m['reserved']

gaps = 8

nx = mx + r_left + gaps
ny = my + r_top + gaps
nw = ew - r_left - r_right - gaps * 2
nh = eh - r_top - r_bottom - gaps * 2

print(f'{nx} {ny} {nw} {nh}')
")

    hyprctl --batch "dispatch movewindowpixel exact $NX $NY,address:$ADDR ; dispatch resizewindowpixel exact $NW $NH,address:$ADDR"
fi
