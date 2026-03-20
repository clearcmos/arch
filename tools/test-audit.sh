#!/bin/bash
# Test script for audit-pkgbuild with glow rendering.
# Run 1: clears cache, fresh analysis. Run 2: cached result.

set -euo pipefail

PKG="xremap-kde-bin"
CACHE="$HOME/.cache/audit-pkgbuild/$PKG.json"

echo "=== Run 1: Fresh analysis ==="
rm -f "$CACHE" 2>/dev/null
cd "$HOME/.cache/paru/clone/$PKG"
time audit-pkgbuild .

echo ""
echo "=== Run 2: Cached ==="
time audit-pkgbuild .
