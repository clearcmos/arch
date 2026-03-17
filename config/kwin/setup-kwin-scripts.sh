#!/bin/bash
# Deploy KWin scripts for custom keyboard shortcuts
# Called by setup.sh - sets up Meta+F10 (screen off) and Meta+F11 (BT toggle)

KWINRC="$HOME/.config/kwinrc"
SHORTCUTS="$HOME/.config/kglobalshortcutsrc"

# --- Screen Off Toggle (Meta+F10) ---

SCRIPT_DIR="$HOME/.local/share/kwin/scripts/screenofftoggle"
CODE_DIR="$SCRIPT_DIR/contents/code"
mkdir -p "$CODE_DIR"

cat > "$CODE_DIR/main.js" << 'KWINSCRIPT'
registerShortcut(
    "Screen Off Toggle",
    "Turn off screen and mute notifications",
    "Meta+F10",
    function() {
        callDBus("org.freedesktop.systemd1", "/org/freedesktop/systemd1",
                 "org.freedesktop.systemd1.Manager", "StartUnit",
                 "screen-off-toggle.service", "replace");
    }
);
KWINSCRIPT

cat > "$SCRIPT_DIR/metadata.json" << 'METADATA'
{
    "KPackageStructure": "KWin/Script",
    "KPlugin": {
        "Id": "screenofftoggle",
        "Name": "Screen Off Toggle",
        "Description": "Toggle screen off and mute notifications with Meta+F10",
        "Icon": "preferences-desktop-display",
        "Authors": [{ "Name": "Nicholas" }],
        "License": "GPL",
        "Version": "1.1"
    },
    "X-Plasma-API": "javascript"
}
METADATA

# Remove KDE default binding for Turn Off Screen if it conflicts
if grep -q "Turn Off Screen=Meta+F10" "$SHORTCUTS" 2>/dev/null; then
    sed -i 's/Turn Off Screen=Meta+F10/Turn Off Screen=none/' "$SHORTCUTS"
fi

# Enable in kwinrc
if ! grep -q "screenofftoggleEnabled" "$KWINRC" 2>/dev/null; then
    if grep -q "^\[Plugins\]" "$KWINRC" 2>/dev/null; then
        sed -i '/^\[Plugins\]/a screenofftoggleEnabled=true' "$KWINRC"
    else
        echo "" >> "$KWINRC"
        echo "[Plugins]" >> "$KWINRC"
        echo "screenofftoggleEnabled=true" >> "$KWINRC"
    fi
fi

# --- Bluetooth Toggle (Meta+F11) ---

SCRIPT_DIR="$HOME/.local/share/kwin/scripts/bttoggle"
CODE_DIR="$SCRIPT_DIR/contents/code"
mkdir -p "$CODE_DIR"

cat > "$CODE_DIR/main.js" << 'KWINSCRIPT'
registerShortcut(
    "Toggle Bluetooth",
    "Toggle Bluetooth and connect Q30",
    "Meta+F11",
    function() {
        callDBus("org.freedesktop.systemd1", "/org/freedesktop/systemd1",
                 "org.freedesktop.systemd1.Manager", "StartUnit",
                 "bt-toggle.service", "replace");
    }
);
KWINSCRIPT

cat > "$SCRIPT_DIR/metadata.json" << 'METADATA'
{
    "KPackageStructure": "KWin/Script",
    "KPlugin": {
        "Id": "bttoggle",
        "Name": "Bluetooth Toggle",
        "Description": "Toggle Bluetooth with Meta+F11",
        "Icon": "bluetooth",
        "Authors": [{ "Name": "Nicholas" }],
        "License": "GPL",
        "Version": "1.0"
    },
    "X-Plasma-API": "javascript"
}
METADATA

# Enable in kwinrc
if ! grep -q "bttoggleEnabled" "$KWINRC" 2>/dev/null; then
    if grep -q "^\[Plugins\]" "$KWINRC" 2>/dev/null; then
        sed -i '/^\[Plugins\]/a bttoggleEnabled=true' "$KWINRC"
    else
        echo "" >> "$KWINRC"
        echo "[Plugins]" >> "$KWINRC"
        echo "bttoggleEnabled=true" >> "$KWINRC"
    fi
fi
