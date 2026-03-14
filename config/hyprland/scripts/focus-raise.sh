#!/bin/bash
# Daemon: when a maximized window gets focus, minimize floating windows
# on the same workspace that would visually block it.
# When a non-maximized window gets focus, restore any auto-minimized windows.

AUTO_MINIMIZED="/tmp/hypr-auto-minimized"
mkdir -p "$AUTO_MINIMIZED"

restore_windows() {
    for f in "$AUTO_MINIMIZED"/*; do
        [[ -f "$f" ]] || continue
        local addr
        addr=$(basename "$f")
        hyprctl dispatch movetoworkspacesilent "$(cat "$f"),address:0x$addr" 2>/dev/null
        rm "$f"
    done
}

socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while IFS= read -r event; do
    case "$event" in
        activewindowv2\>\>*)
            addr="${event#activewindowv2>>}"
            [[ -z "$addr" ]] && continue

            win=$(hyprctl clients -j | jq ".[] | select(.address == \"0x$addr\")")
            [[ -z "$win" ]] && continue

            is_max=$(echo "$win" | jq -r '.fullscreenClient')
            ws_id=$(echo "$win" | jq -r '.workspace.id')
            mon=$(echo "$win" | jq -r '.monitor')

            if [[ "$is_max" == "1" || "$is_max" == "3" ]]; then
                # Focused window is maximized - minimize floating non-maximized windows on same workspace
                hyprctl clients -j | jq -r ".[] | select(.workspace.id == $ws_id and .monitor == $mon and .address != \"0x$addr\" and .floating == true and .fullscreenClient == 0) | .address" | while read -r other; do
                    other_short="${other#0x}"
                    echo "$ws_id" > "$AUTO_MINIMIZED/$other_short"
                    hyprctl dispatch movetoworkspacesilent "special:autohide,address:$other" 2>/dev/null
                done
                # Re-focus the maximized window (focus may have shifted during minimize)
                hyprctl dispatch focuswindow "address:0x$addr" 2>/dev/null
            else
                # Focused window is not maximized - restore auto-minimized windows
                restore_windows
            fi
            ;;
    esac
done
