#!/bin/bash

# ghelp - Git and GitHub command reference

echo "Git & GitHub Management Commands:"
echo "================================="
echo
echo "Git Workflow:"
echo "  gpush --all                - Fetch, pull, commit, push across all repos"
echo "  gpush --here               - Fetch, pull, commit, push current repo only"
echo "  gscan                      - Scan all repos for secrets using trufflehog"
echo "  create-repo                - Create new GitHub repository interactively"
echo
echo "Repository Management:"
echo "  repo visibility            - Toggle repo visibility (public/private)"
echo "  repo help                  - Show repo command help"
echo
echo "Utilities:"
echo "  getrepo                    - Search GitHub repos with fzf, copy SSH URL"
echo "  ghere                      - Interactive grep across codebase (shell function)"
echo
echo "Examples:"
echo "  gpush --all                - Handle all your git repos"
echo "  gpush --here               - Handle current git repo only"
echo "  create-repo                - Create new repository on GitHub"
echo "  gscan                      - Check all repos for leaked secrets"
