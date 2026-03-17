#!/bin/bash
set -euo pipefail

# gscan - Scan repositories for secrets using trufflehog

if ! command -v trufflehog >/dev/null 2>&1; then
    echo "trufflehog not found. Install it first."
    exit 1
fi

echo "Scanning repositories for secrets..."
repos_found=0
repos_with_secrets=0

scan_repo() {
    local repo_path="$1"
    local repo_name
    repo_name=$(basename "$repo_path")

    if [[ ! -d "$repo_path/.git" ]]; then
        return
    fi

    repos_found=$((repos_found + 1))
    echo "Scanning $repo_name..."

    cd "$repo_path"
    trufflehog_output=$(trufflehog git file://. 2>/dev/null || true)
    total_secrets=$(echo "$trufflehog_output" | grep -c "Raw result:" || true)

    false_positives=0
    ignore_file="$HOME/.truffleignore"
    if [[ ! -f "$ignore_file" ]]; then
        ignore_file="/etc/truffleignore"
    fi

    if [[ -f "$ignore_file" ]]; then
        while IFS= read -r ignore_pattern; do
            if [[ -z "$ignore_pattern" || "$ignore_pattern" == \#* ]]; then
                continue
            fi
            pattern_matches=$(echo "$trufflehog_output" | grep -c "Raw result: $ignore_pattern" || true)
            false_positives=$((false_positives + pattern_matches))
        done < "$ignore_file"
    fi

    if [ "$total_secrets" -gt 0 ] && [ "$total_secrets" -ne "$false_positives" ]; then
        echo "  SECRETS FOUND in: $repo_name"
        echo "  Run 'cd $repo_path && trufflehog git file://.' for details"
        repos_with_secrets=$((repos_with_secrets + 1))
    else
        echo "  Clean: $repo_name"
    fi
}

# Scan ~/arch
if [[ -d "$HOME/arch/.git" ]]; then
    scan_repo "$HOME/arch"
fi

# Scan repos in ~/git/mine and ~/git/forked
for subdir in mine forked; do
    if [[ -d "/home/nicholas/git/$subdir" ]]; then
        for repo in /home/nicholas/git/$subdir/*/; do
            if [[ -d "$repo/.git" ]]; then
                cd "$repo"
                if git remote -v 2>/dev/null | grep -q "clearcmos"; then
                    scan_repo "$repo"
                fi
            fi
        done
    fi
done

echo ""
echo "Scan Summary:"
echo "   Repositories scanned: $repos_found"
echo "   Repositories with secrets: $repos_with_secrets"

if [[ $repos_with_secrets -gt 0 ]]; then
    echo "Please review and remove any sensitive data before committing!"
    exit 1
else
    echo "All repositories are clean!"
fi
