#!/usr/bin/env bash
# nuke-secret - Remove secrets from current files and entire git history
# Usage: nuke-secret "secret-string-to-remove"

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Print usage
usage() {
    cat <<EOF
🔥 nuke-secret - Remove secrets from files and git history

Usage:
    nuke-secret "secret-string" ["replacement"]

Arguments:
    secret-string  - The secret to find and remove (required)
    replacement    - What to replace it with (optional, default: "***REMOVED***")

Examples:
    nuke-secret "olduser@example.com"
    nuke-secret "olduser@example.com" "user@example.com"
    nuke-secret "sk-1234567890abcdef"
    nuke-secret "my-api-key-here" "REDACTED"

What it does:
    1. Validates you're in a git repository
    2. Commits any pending changes
    3. Creates backup branch (backup-nuke-YYYYMMDD-HHMMSS)
    4. Replaces secret with replacement in ALL git history
    5. Verifies removal was successful
    6. Shows instructions for force-pushing

⚠️  WARNING: This rewrites ALL git history!
    - All commit SHAs will change
    - Requires force push to remote
    - Anyone with clones must re-clone or git pull --force

EOF
    exit 1
}

# Check if in git repo
check_git_repo() {
    if ! git rev-parse --git-dir &>/dev/null; then
        print_msg "$RED" "❌ Error: Not in a git repository"
        print_msg "$YELLOW" "   Run this command from inside a git repository"
        exit 1
    fi
}

# Check if git-filter-repo is available
check_git_filter_repo() {
    if ! command -v git-filter-repo &>/dev/null; then
        print_msg "$RED" "❌ Error: git-filter-repo not found"
        print_msg "$YELLOW" "   Run: nix-shell -p git-filter-repo"
        exit 1
    fi
}

# Main function
main() {
    # Check arguments
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        usage
    fi

    local SECRET="$1"
    local REPLACEMENT="${2:-***REMOVED***}"

    if [ -z "$SECRET" ]; then
        print_msg "$RED" "❌ Error: Secret string cannot be empty"
        usage
    fi

    # Validate environment
    check_git_repo
    check_git_filter_repo

    # Get repository info
    local REPO_ROOT
    REPO_ROOT=$(git rev-parse --show-toplevel)
    cd "$REPO_ROOT"

    local CURRENT_BRANCH
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    # First, search for the secret before doing anything
    print_msg "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_msg "$BLUE" "🔍 SEARCHING FOR SECRET"
    print_msg "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    print_msg "$YELLOW" "Repository: $REPO_ROOT"
    print_msg "$YELLOW" "Branch:     $CURRENT_BRANCH"
    print_msg "$YELLOW" "Secret:     ${SECRET:0:20}... (showing first 20 chars)"
    echo

    # Search current files
    print_msg "$BLUE" "Searching current files..."
    local FILES_FOUND=0
    local FILE_MATCHES=""
    set +e  # Temporarily disable exit on error for grep
    FILE_MATCHES=$(grep -r -n "$SECRET" . 2>/dev/null | grep -v "\.git/" | head -10)
    local GREP_EXIT=$?
    set -e  # Re-enable exit on error

    if [ -n "$FILE_MATCHES" ]; then
        FILES_FOUND=1
        print_msg "$YELLOW" "$FILE_MATCHES"
    else
        print_msg "$GREEN" "✓ Not found in current files"
    fi
    echo

    # Search git history
    print_msg "$BLUE" "Searching git history (all commits)..."
    local HISTORY_FOUND=0
    local HISTORY_COUNT=0
    set +e  # Temporarily disable exit on error
    HISTORY_COUNT=$(git log --all -S "$SECRET" --oneline 2>/dev/null | wc -l)
    set -e  # Re-enable exit on error

    if [ "$HISTORY_COUNT" -gt 0 ]; then
        HISTORY_FOUND=1
        print_msg "$YELLOW" "Found in $HISTORY_COUNT commits:"
        set +e  # Temporarily disable exit on error
        git log --all -S "$SECRET" --oneline | head -10
        set -e  # Re-enable exit on error
        if [ "$HISTORY_COUNT" -gt 10 ]; then
            print_msg "$YELLOW" "... and $((HISTORY_COUNT - 10)) more commits"
        fi
    else
        print_msg "$GREEN" "✓ Not found in git history"
    fi
    echo

    # Exit if nothing found
    if [ "$FILES_FOUND" -eq 0 ] && [ "$HISTORY_FOUND" -eq 0 ]; then
        print_msg "$GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_msg "$GREEN" "✅ SECRET NOT FOUND"
        print_msg "$GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_msg "$GREEN" "The secret was not found in current files or git history."
        print_msg "$GREEN" "Nothing to remove!"
        exit 0
    fi

    # Show summary and ask for confirmation
    print_msg "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_msg "$BLUE" "🔥 READY TO REMOVE SECRET"
    print_msg "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    print_msg "$YELLOW" "What will be replaced:"
    if [ "$FILES_FOUND" -eq 1 ]; then
        print_msg "$YELLOW" "  • Found in current files (shown above)"
    fi
    if [ "$HISTORY_FOUND" -eq 1 ]; then
        print_msg "$YELLOW" "  • Found in $HISTORY_COUNT commits (shown above)"
    fi
    print_msg "$YELLOW" "  • Will replace with: $REPLACEMENT"
    echo
    print_msg "$RED" "⚠️  WARNING: This will rewrite ALL git history!"
    print_msg "$RED" "   - All commit SHAs will change"
    print_msg "$RED" "   - Requires force push to remote"
    print_msg "$RED" "   - Creates backup branch automatically"
    echo

    # Confirmation
    read -p "Proceed with removal? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_msg "$YELLOW" "❌ Cancelled by user"
        exit 0
    fi

    # Step 1: Check for uncommitted changes
    print_msg "$BLUE" "[1/7] Checking for uncommitted changes..."
    if ! git diff-index --quiet HEAD --; then
        print_msg "$YELLOW" "   Found uncommitted changes, committing..."
        git add .
        git commit -m "chore: save work before secret removal" || true
    else
        print_msg "$GREEN" "   ✓ No uncommitted changes"
    fi
    echo

    # Step 2: Create backup branch
    print_msg "$BLUE" "[2/7] Creating backup branch..."
    local BACKUP_BRANCH="backup-nuke-$(date +%Y%m%d-%H%M%S)"
    git branch "$BACKUP_BRANCH"
    print_msg "$GREEN" "   ✓ Created: $BACKUP_BRANCH"
    echo

    # Step 3: Create replacement file
    print_msg "$BLUE" "[3/7] Creating replacement mapping..."
    local REPLACE_FILE
    REPLACE_FILE=$(mktemp)
    echo "${SECRET}==>${REPLACEMENT}" > "$REPLACE_FILE"
    print_msg "$GREEN" "   ✓ Replacement: $SECRET => $REPLACEMENT"
    echo

    # Step 4: Get remote info before filter-repo removes it
    print_msg "$BLUE" "[4/7] Saving remote information..."
    local REMOTE_URL=""
    if git remote get-url origin &>/dev/null; then
        REMOTE_URL=$(git remote get-url origin)
        print_msg "$GREEN" "   ✓ Saved remote: $REMOTE_URL"
    else
        print_msg "$YELLOW" "   No origin remote found"
    fi
    echo

    # Step 5: Run git-filter-repo
    print_msg "$BLUE" "[5/7] Running git-filter-repo (this rewrites ALL commits)..."
    rm -rf .git/filter-repo 2>/dev/null || true

    if git filter-repo --replace-text "$REPLACE_FILE" --force; then
        print_msg "$GREEN" "   ✓ History rewritten successfully"
    else
        print_msg "$RED" "   ❌ git-filter-repo failed"
        rm -f "$REPLACE_FILE"
        exit 1
    fi
    echo

    # Step 6: Verify removal
    print_msg "$BLUE" "[6/7] Verifying secret removal..."

    # Check if secret still exists in history
    if git log --all -S "$SECRET" --oneline | head -1 | grep -q .; then
        print_msg "$RED" "   ❌ WARNING: Secret still found in git history!"
        print_msg "$YELLOW" "   This might indicate the secret has variations (quotes, encoding, etc.)"
    else
        print_msg "$GREEN" "   ✓ Secret not found in git history"
    fi

    # Check if secret exists in current files
    if grep -r "$SECRET" . 2>/dev/null | grep -v "\.git/" | head -1 | grep -q .; then
        print_msg "$YELLOW" "   ⚠  Secret still found in current files (not in git)"
    else
        print_msg "$GREEN" "   ✓ Secret not found in current files"
    fi
    echo

    # Step 7: Re-add remote if it existed
    if [ -n "$REMOTE_URL" ]; then
        print_msg "$BLUE" "[7/7] Re-adding remote origin..."
        git remote add origin "$REMOTE_URL" 2>/dev/null || true
        print_msg "$GREEN" "   ✓ Remote origin re-added"
    else
        print_msg "$BLUE" "[7/7] Skipping remote (none configured)"
    fi
    echo

    # Cleanup
    rm -f "$REPLACE_FILE"

    # Success message and instructions
    print_msg "$GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_msg "$GREEN" "✅ SECRET REMOVAL COMPLETE"
    print_msg "$GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    print_msg "$YELLOW" "📋 What happened:"
    print_msg "$YELLOW" "   • Created backup branch: $BACKUP_BRANCH"
    print_msg "$YELLOW" "   • Replaced secret in ALL commits with: $REPLACEMENT"
    print_msg "$YELLOW" "   • All commit SHAs have changed"
    echo
    print_msg "$YELLOW" "🔍 Verify removal:"
    print_msg "$YELLOW" "   git log --all -S \"SECRET\" --oneline"
    print_msg "$YELLOW" "   grep -r \"SECRET\" ."
    echo
    print_msg "$RED" "🚀 NEXT STEPS (REQUIRED):"
    echo
    if [ -n "$REMOTE_URL" ]; then
        print_msg "$RED" "   1. Verify the secret is gone (commands above)"
        print_msg "$RED" "   2. Force push to remote:"
        print_msg "$RED" "      git push --force origin $CURRENT_BRANCH"
        echo
        print_msg "$RED" "   3. Tell anyone with clones to re-clone or:"
        print_msg "$RED" "      git fetch origin"
        print_msg "$RED" "      git reset --hard origin/$CURRENT_BRANCH"
    else
        print_msg "$RED" "   1. Verify the secret is gone (commands above)"
        print_msg "$RED" "   2. Add remote and force push:"
        print_msg "$RED" "      git remote add origin <REMOTE_URL>"
        print_msg "$RED" "      git push --force origin $CURRENT_BRANCH"
    fi
    echo
    print_msg "$YELLOW" "💾 Backup branch: $BACKUP_BRANCH"
    print_msg "$YELLOW" "   Delete when satisfied: git branch -D $BACKUP_BRANCH"
    echo
}

# Run main
main "$@"
