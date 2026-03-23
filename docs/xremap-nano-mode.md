# xremap Nano Mode (Ctrl+W Passthrough)

## Problem

Konsole's default close-session shortcut is Ctrl+Shift+W. The xremap config remaps Ctrl+W to Ctrl+Shift+W in Konsole so that Ctrl+W closes tabs (matching browser behavior). But this means Ctrl+W can never reach terminal apps like nano, where it triggers search.

## Why Not Just Match Window Title?

xremap's `window:` field matches the KWin window caption, which does update when nano sets the terminal title. However, xremap only captures the caption on window focus change (the KWin script fires on `workspace.windowActivated`), not when the title updates within the same window. So opening nano in an already-focused Konsole tab doesn't update xremap's view of the title.

## Solution

Use xremap's `mode` feature to toggle between `default` and `nano` modes, driven by a shell wrapper that injects synthetic keystrokes via ydotool.

### Components

1. **xremap config** (`config/xremap/config.yml`): F20 sets mode to `nano`, F19 sets mode to `default`. The nano-mode Konsole rule omits the Ctrl+W remap. The default-mode rule remaps it to Ctrl+Shift+W. Both rules are scoped to their respective mode so the default rule can't fire in nano mode.

2. **nano wrapper** (`config/shell/functions.sh`): Shell function that shadows `/usr/bin/nano`. Sends F20 (keycode 190) via ydotool before launching nano, and F19 (keycode 189) after nano exits.

3. **ydotool** (`packages/official.txt`): Injects synthetic key events on Wayland. Runs as a user service (`ydotool.service`). User must be in the `input` group.

### How It Works

```
nano /tmp/test
  -> wrapper sends F20 (ydotool key 190:1 190:0)
  -> xremap receives F20, sets mode to "nano"
  -> nano-mode rule applies: Ctrl+W passes through to nano as search
  -> user exits nano
  -> wrapper sends F19 (ydotool key 189:1 189:0)
  -> xremap receives F19, sets mode to "default"
  -> default-mode rule applies: Ctrl+W closes tab again
```

### Debugging

Check current mode and key events:
```
journalctl --user -u xremap.service -f
```

Test mode switching manually:
```
ydotool key 190:1 190:0   # switch to nano mode
ydotool key 189:1 189:0   # switch to default mode
```

### Scope

The mode switch is global but the Ctrl+W remap only targets Konsole (`application: only: org.kde.konsole`). Other terminals (foot, etc.) are unaffected regardless of which mode is active.

Functions that call `nano` (like `fnano`, `fgrep`) automatically use the wrapper since the shell function shadows the binary.
