#!/bin/bash
# audit-aur is now part of check-updates.sh
# This wrapper redirects to the unified tool.

echo "audit-aur has been merged into check-updates."
echo "Running check-updates instead..."
echo ""
exec ~/arch/tools/check-updates.sh "$@"
