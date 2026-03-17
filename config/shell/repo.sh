#!/bin/bash
set -euo pipefail

# repo - GitHub repository visibility manager

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

check_auth() {
    if ! gh api user &>/dev/null; then
        echo -e "${RED}Not authenticated with GitHub. Run 'gh auth login'.${NC}"
        exit 1
    fi
}

cmd_visibility() {
    check_auth

    while true; do
        echo -e "${CYAN}Fetching repositories...${NC}"

        repos=$(gh repo list --limit 100 --json name,visibility,stargazerCount \
            --jq 'sort_by(.name | ascii_downcase) | .[] | "\(.name)|\(.visibility)|\(.stargazerCount)"')

        if [[ -z "$repos" ]]; then
            echo -e "${YELLOW}No repositories found.${NC}"
            exit 0
        fi

        # Build numbered list
        clear
        echo -e "${CYAN}GitHub Repository Visibility Manager${NC}"
        echo -e "${CYAN}=====================================${NC}"
        echo -e "${YELLOW}Select a repository to toggle visibility (Ctrl+C to exit)${NC}"
        echo ""

        local i=1
        declare -a repo_names=()
        declare -a repo_visibilities=()
        while IFS='|' read -r name visibility stars; do
            if [[ "$visibility" == "PUBLIC" ]]; then
                vis_display="${GREEN}PUBLIC ${NC}"
            else
                vis_display="${RED}PRIVATE${NC}"
            fi

            star_display=""
            if [[ "$stars" -gt 0 ]]; then
                star_display=" ($stars stars)"
            fi

            printf "  %3d) %b %s%s\n" "$i" "$vis_display" "$name" "$star_display"
            repo_names+=("$name")
            repo_visibilities+=("$visibility")
            i=$((i + 1))
        done <<< "$repos"

        echo ""
        read -rp "Enter number (or q to quit): " choice
        if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
            exit 0
        fi

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#repo_names[@]} ]]; then
            echo "Invalid selection"
            sleep 1
            continue
        fi

        local idx=$((choice - 1))
        local repo_name="${repo_names[$idx]}"
        local current_vis="${repo_visibilities[$idx]}"

        if [[ "$current_vis" == "PUBLIC" ]]; then
            new_vis="private"
            new_vis_display="PRIVATE"

            star_count=$(echo "$repos" | grep "^$repo_name|" | cut -d'|' -f3)
            if [[ "$star_count" -gt 0 ]]; then
                echo ""
                echo -e "${RED}WARNING: This repo has $star_count star(s)!${NC}"
                echo -e "${RED}Making it private will PERMANENTLY remove all stars.${NC}"
                echo ""
            fi
        else
            new_vis="public"
            new_vis_display="PUBLIC"
        fi

        echo ""
        echo -e "Change ${BLUE}$repo_name${NC} from ${YELLOW}$current_vis${NC} to ${YELLOW}$new_vis_display${NC}?"
        read -rp "Proceed? (y/n): " confirm

        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}Updating...${NC}"
            if gh repo edit "clearcmos/$repo_name" --visibility "$new_vis" --accept-visibility-change-consequences 2>&1; then
                echo -e "${GREEN}$repo_name is now $new_vis_display${NC}"
            else
                echo -e "${RED}Failed to update $repo_name${NC}"
            fi
            sleep 1
        fi
    done
}

cmd_help() {
    echo "repo - GitHub repository management"
    echo ""
    echo "Usage: repo <command>"
    echo ""
    echo "Commands:"
    echo "  visibility    Manage repository visibility (public/private)"
    echo "  help          Show this help message"
}

case "${1:-help}" in
    visibility|vis|v)
        cmd_visibility
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        echo "Unknown command: $1"
        cmd_help
        exit 1
        ;;
esac
