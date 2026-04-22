---
description: Stage all changes, commit with a generated message, push to a feature branch on origin, and open a draft PR if one does not already exist. For work repos where main is protected and changes land via PR.
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git checkout:*), Bash(git switch:*), Bash(git remote:*), Bash(gh pr:*), Bash(gh repo:*), Read, Edit
---

## Context
- Current git status: !`git status`
- Recent commits for style reference: !`git log --oneline -5`
- Current diff: !`git diff --stat`
- Current branch: !`git rev-parse --abbrev-ref HEAD`
- Remotes: !`git remote -v`

## Instructions

If "$ARGUMENTS" is provided, use it as the commit message instead of generating one.

### Phase 1 -- plan (no side effects)

1. Review the current changes (staged and unstaged) and all untracked files.
2. Check for secrets, credentials, API keys, tokens, .env files, or any sensitive data. If found, warn and stop -- do not stage or commit.
3. Identify files to exclude: build artifacts, compiled output, cache files, logs, and other generated data. If unsure whether a file belongs in the repo, ask.
4. Generate a concise conventional commit message based on the actual diff. Keep the subject under 72 characters. Use conventional commit format (feat:, fix:, chore:, docs:, refactor:, etc.). If there are no changes to commit, say so and stop.
5. Determine the target branch:
   - If current branch is `main` or `master`: derive a feature branch name from the commit subject (kebab-case, strip the conventional-commit prefix, max ~50 chars). Check `git log --pretty='%an %s' -20` for an initials/prefix convention (`nb/...`, etc.) and match it if present.
   - Otherwise: use the current branch.
6. Determine PR plan:
   - If `gh` is not available, or the origin remote is not GitHub, skip PR creation.
   - Otherwise, check for an existing open PR for the target branch with `gh pr list --head <branch> --json number,url`. If one exists, skip creation and plan to print its URL at the end.
   - If no PR exists, plan to open a **draft** PR. Title = commit subject. Body = markdown bullets derived from the diff, one bullet per substantive change, tied to specific file paths. No `## Summary` / `## Test plan` section headers, no emoji, no "Generated with Claude Code" line, no `Co-Authored-By` trailer. Look at recent PR bodies in the target repo (`gh pr view <N> --json body`) to match the local style.

### Phase 2 -- confirm

Show the user a single checkpoint with:

```
Plan:
  Branch:   <target-branch>   (new | existing)
  Remote:   origin
  Files:    <list of files to stage>
  Excluded: <list of files being excluded, with reason, or "none">
  Gitignore: <additions planned, or "none">
  Message:  <commit subject>
            <body if any>
  PR:       <create new draft PR | skip (existing PR #N) | skip (no gh / not GitHub)>
```

Ask: "Proceed? (y to continue, or edit anything above)". Wait for the reply. If the user changes the message, branch name, or file list, incorporate and re-display until they approve.

### Phase 3 -- execute (after approval, no further prompts)

7. If any files were excluded in the plan, add them to `.gitignore` under an appropriate section. Read the existing `.gitignore` first.
8. If the target branch is different from the current branch, create and switch to it with `git switch -c <branch>`.
9. Stage only the approved files by name -- do NOT use `git add -A` or `git add .`. Include `.gitignore` if modified.
10. Commit with the approved message. Do NOT add a Co-Authored-By trailer.
11. Push with `git push -u origin HEAD`. Do NOT push to any other remote. Do NOT force-push.
12. Print the final branch name and commit SHA.
13. If PR creation was planned, run `gh pr create --draft --title "<subject>" --body "<body>"` passing the body via HEREDOC. Print the resulting PR URL. If a PR already existed, print its URL instead.
