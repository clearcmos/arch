#!/bin/bash
set -euo pipefail

# create-repo - Interactive GitHub repository creation wizard

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== GitHub Repository Creation Wizard ===${NC}\n"

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${YELLOW}This directory is not a git repository.${NC}"
    read -rp "Would you like to initialize it? (y/n): " init_choice
    if [[ "$init_choice" =~ ^[Yy]$ ]]; then
        git init --initial-branch=main
        echo -e "${GREEN}Initialized git repository${NC}\n"
    else
        echo -e "${RED}Cannot proceed without a git repository.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Already in a git repository${NC}\n"
fi

echo "Checking GitHub authentication..."
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed.${NC}"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}Not authenticated with GitHub.${NC}"
    echo "Authenticating now..."
    gh auth login
fi

echo -e "${GREEN}GitHub authentication verified${NC}\n"

read -rp "Enter the repository name: " repo_name
if [ -z "$repo_name" ]; then
    echo -e "${RED}Repository name cannot be empty.${NC}"
    exit 1
fi

echo ""
read -rp "Make repository public or private? (public/private) [public]: " visibility
visibility=${visibility:-public}

if [[ ! "$visibility" =~ ^(public|private)$ ]]; then
    echo -e "${RED}Invalid choice. Must be 'public' or 'private'.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Creating repository '$repo_name' as $visibility...${NC}"
gh repo create "$repo_name" --"$visibility" --source=. --remote=origin

current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [ "$current_branch" != "main" ]; then
    echo -e "\n${YELLOW}Renaming branch to 'main'...${NC}"
    if [ -z "$current_branch" ]; then
        git checkout -b main
    else
        git branch -M main
    fi
fi

echo -e "${GREEN}Branch set to 'main'${NC}"

remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [ -n "$remote_url" ]; then
    echo -e "${GREEN}Remote 'origin' configured: $remote_url${NC}"
fi

echo -e "\n${GREEN}=== Setup Complete! ===${NC}"
echo -e "You can now:"
echo -e "  ${YELLOW}git add .${NC}"
echo -e "  ${YELLOW}git commit -m \"Initial commit\"${NC}"
echo -e "  ${YELLOW}git push -u origin main${NC}"
