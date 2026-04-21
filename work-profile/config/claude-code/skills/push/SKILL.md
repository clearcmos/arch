---
description: Stage all changes, commit with a generated message, and push to remote
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git log:*), Bash(git remote:*), Read, Edit
---

## Context
- Current git status: !`git status`
- Recent commits for style reference: !`git log --oneline -5`
- Current diff: !`git diff --stat`
- Remotes: !`git remote -v`

## Instructions

If "$ARGUMENTS" is provided, use it as the commit message instead of generating one.

1. Review the current changes (staged and unstaged) and all untracked files
2. Check for secrets, credentials, API keys, tokens, .env files, or any sensitive data. If found, warn and stop -- do not stage or commit.
3. Exclude build artifacts, compiled output, cache files, logs, and other generated data that should not be committed. If unsure whether a file belongs in the repo, ask.
4. If you excluded any files in step 3, add them to `.gitignore` so they don't reappear as untracked in future runs. Read the existing `.gitignore` first, then use Edit to add entries under an appropriate section.
5. Stage only the relevant files by name -- do NOT use `git add -A` or `git add .`. Include the `.gitignore` if you modified it.
6. Generate a concise conventional commit message based on the actual diff
7. Commit with that message
8. Push to the remote on the current branch (usually main). If multiple remotes exist, push to the one owned by `clearcmos`.

Keep the commit message under 72 characters. Use conventional commit format (feat:, fix:, chore:, docs:, refactor:, etc.). If there are no changes to commit, just say so and stop.

Do NOT add a Co-Authored-By trailer.

You MUST do all steps in a single response. Do not ask for confirmation.
