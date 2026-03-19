#!/bin/bash
set -euo pipefail

# gpush - Smart git workflow: fetch, pull, commit, push across repos

if [[ $# -eq 0 ]]; then
    echo "Missing required flag"
    echo "Usage: gpush --all | gpush --here"
    echo "  --all   Process all repositories in ~/git/mine and ~/git/forked"
    echo "  --here  Process current directory only"
    exit 1
fi

mode="$1"

if [[ "$mode" != "--all" && "$mode" != "--here" ]]; then
    echo "Invalid flag: $mode"
    echo "Usage: gpush --all | gpush --here"
    exit 1
fi

echo "Scanning git repositories..."

repos=()

if [[ "$mode" == "--all" ]]; then
    if [[ -d "/home/nicholas/git" ]]; then
        for dir in /home/nicholas/git/*/; do
            if [[ -d "$dir.git" ]]; then
                repos+=("$(realpath "$dir")")
            fi
        done
    fi
else
    if [[ ! -d ".git" ]]; then
        echo "Current directory is not a git repository"
        exit 1
    fi
    repos+=("$(pwd)")
fi

if [[ ${#repos[@]} -eq 0 ]]; then
    echo "No git repositories found"
    exit 1
fi

echo "Found ${#repos[@]} repositories:"
printf "   %s\n" "${repos[@]}"
echo

# Phase 1: Fetch all repos
echo "Phase 1: Fetching from remotes..."
for repo in "${repos[@]}"; do
    cd "$repo"

    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ "$current_branch" != "main" ]]; then
        echo "  Skipping $repo (not on main branch: $current_branch)"
        continue
    fi

    if ! git remote get-url origin >/dev/null 2>&1; then
        echo "  Skipping $repo (no origin remote configured)"
        continue
    fi

    echo "  Fetching $repo..."
    if ! git fetch origin >/dev/null 2>&1; then
        echo "  Failed to fetch $repo"
        exit 1
    fi
done

echo
echo "Phase 2: Analyzing repository states..."

clean_behind=()
clean_uptodate=()
dirty_current=()
conflicts=()

for repo in "${repos[@]}"; do
    cd "$repo"

    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ "$current_branch" != "main" ]] || ! git remote get-url origin >/dev/null 2>&1; then
        continue
    fi

    git update-index --refresh >/dev/null 2>&1
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        remote_ahead=$(git rev-list --count origin/main ^HEAD 2>/dev/null || echo "0")

        if [[ "$remote_ahead" -gt 0 ]]; then
            conflicts+=("$repo")
        else
            dirty_current+=("$repo")
        fi
    else
        remote_ahead=$(git rev-list --count origin/main ^HEAD 2>/dev/null || echo "0")

        if [[ "$remote_ahead" -gt 0 ]]; then
            clean_behind+=("$repo")
        else
            clean_uptodate+=("$repo")
        fi
    fi
done

if [[ ${#conflicts[@]} -gt 0 ]]; then
    echo "CONFLICTS DETECTED - Aborting!"
    echo "The following repositories have both local changes AND remote changes:"
    for repo in "${conflicts[@]}"; do
        echo "   $repo"
    done
    echo
    echo "Please resolve these conflicts manually before running gpush again."
    exit 1
fi

# Phase 3: Pull clean repos that are behind
if [[ ${#clean_behind[@]} -gt 0 ]]; then
    echo
    echo "Phase 3: Pulling clean repositories that are behind..."
    for repo in "${clean_behind[@]}"; do
        echo "  Pulling $repo..."
        cd "$repo"
        if ! git pull origin main >/dev/null 2>&1; then
            echo "  Failed to pull $repo"
            exit 1
        fi
        echo "  Updated $repo"
    done
fi

# Phase 4: Commit and push dirty repos
if [[ ${#dirty_current[@]} -gt 0 ]]; then
    echo
    echo "Phase 4: Committing and pushing repositories with local changes..."
    for repo in "${dirty_current[@]}"; do
        echo "  Processing $repo..."
        cd "$repo"
        git add -A
        git commit -m "Updates"
        git push origin main
        echo "  Pushed $repo"
    done
fi

# Summary
echo
echo "gpush completed successfully!"
echo "Summary:"
echo "   Up to date: ${#clean_uptodate[@]}"
echo "   Pulled: ${#clean_behind[@]}"
echo "   Committed: ${#dirty_current[@]}"

if [[ ${#clean_uptodate[@]} -gt 0 ]]; then
    echo "   Up to date repos:"
    printf "      %s\n" "${clean_uptodate[@]}"
fi
