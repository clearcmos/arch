#!/usr/bin/env bash
# Workaround for KDE Bug 516855: org.kde.plasma.icontasks metadata references
# a nonexistent X-Plasma-RootPath, causing plasmashell to spin at 100% CPU.
# https://bugs.kde.org/show_bug.cgi?id=516855
#
# Removes the stale X-Plasma-RootPath key from the icontasks metadata.json.
# Idempotent: safe to re-run. Will be overwritten by the next plasma-desktop
# package update (which should include the upstream fix once it lands).
#
# Requires root (the file is owned by plasma-desktop package).

set -euo pipefail

METADATA="/usr/share/plasma/plasmoids/org.kde.plasma.icontasks/metadata.json"

if [[ ! -f "$METADATA" ]]; then
    echo "icontasks metadata not found at $METADATA - nothing to fix"
    exit 0
fi

if ! grep -q 'X-Plasma-RootPath' "$METADATA"; then
    echo "X-Plasma-RootPath already absent - nothing to do"
    exit 0
fi

if [[ $EUID -ne 0 ]]; then
    echo "error: must run as root (file is owned by plasma-desktop package)"
    exit 1
fi

python3 -c "
import json, sys
f = '$METADATA'
with open(f) as fh:
    d = json.load(fh)
d.pop('X-Plasma-RootPath', None)
with open(f, 'w') as fh:
    json.dump(d, fh, indent=4)
    fh.write('\n')
"

echo "removed X-Plasma-RootPath from $METADATA"
