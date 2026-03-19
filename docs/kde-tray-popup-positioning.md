# KDE System Tray Popup Positioning Bug

## Problem

System tray popups (Bluetooth, volume, network, etc.) appear floating in the middle of the screen instead of anchored to the tray icon. Happens on multi-monitor Wayland setups, especially after monitors power cycle via DPMS (sleep/wake/screen blanking).

## Root Cause

On Wayland, KWin treats DPMS screen-off as a monitor disconnect. When monitors come back, kscreen re-detects outputs but popup anchoring data is stale, so popups attach to wrong coordinates. The 3-monitor setup with two portrait-rotated displays makes this especially prone to triggering.

## Status

Fixed upstream in Plasma 6.6.3 (bug #517093 - "Make popup placement on Wayland more robust" in the systemtray applet). Arch is on 6.6.2 as of 2026-03-18. Once 6.6.3 lands, this should be resolved.

Check current version: `plasmashell --version`

## Workaround

Disable DPMS screen blanking so monitors never "disconnect":

System Settings > Power Management > Energy Saving - set screen to never turn off.

## Bug Reports

- https://bugs.kde.org/show_bug.cgi?id=464428 - System tray popups centered on multi-monitor
- https://bugs.kde.org/show_bug.cgi?id=481736 - Popups mispositioned after DPMS wake
- https://bugs.kde.org/show_bug.cgi?id=517093 - Fix in Plasma 6.6.3
