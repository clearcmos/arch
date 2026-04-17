# Global Rules

These apply to all projects.

- Never run sudo commands locally. The user will handle anything requiring local root privileges themselves. Exception: SSH as root to NixOS servers on the LAN (e.g., `ssh root@misc.home.arpa`) is normal operational access and does not require confirmation.
- Never run package install commands (pacman, paru, etc.) directly. Ask the user to run them instead.
- Do not add co-authorship lines (e.g. `Co-Authored-By`) to git commits.
- Do not use emojis anywhere - not in code, commits, comments, or documentation.
- Never set the `icon` field on Outline documents or collections when calling the Outline MCP (create/update). No emojis, no icon names. Always omit the parameter entirely even though it is optional.
- Do not use em dashes or double dashes (--). Use regular hyphens instead. Exception: em dashes/double dashes are allowed if the user explicitly asks to override this rule for a specific project or file.
- Never commit PHI, PII, secrets, credentials, API keys, tokens, or any sensitive data. Always review staged changes for sensitive content before committing.
- When writing README.md files for dev project repos, do not overstate or oversell. Avoid editorial language (e.g. "powerful", "elegant", "blazing fast", "robust", "seamless"). Describe what the project does factually and concisely.
- When creating new repos, always use `main` as the default branch name, never `master`.

# System Configuration Repo

`~/arch` is the single source of truth for this machine's configuration (packages, services, dotfiles, firewall, etc.). When making system-level or user-level changes in any project, consult `~/arch/CLAUDE.md` for conventions, security model, and deployment rules. All config files must live in that repo and be deployed via its `setup.sh`.

# KDE/KWin Window Debugging (Wayland)

Standard X11 tools (wmctrl, xdotool, kdotool) do not work on Wayland. To inspect or manipulate windows on KDE Plasma Wayland:

1. **Write a KWin script** (JavaScript) to `/tmp/` that iterates `workspace.windowList()` and logs properties via `console.log()`. Useful properties: `resourceClass`, `caption`, `fullScreen`, `noBorder`, `moveable`, `resizeable`, `frameGeometry`, `layer`, `keepAbove`, `skipTaskbar`.
2. **Load the script** via D-Bus: `dbus-send --session --dest=org.kde.KWin --print-reply /Scripting org.kde.kwin.Scripting.loadScript string:/tmp/script.js string:"script_name"` - returns an int32 script ID (e.g. 1).
3. **Run the script** via D-Bus: `dbus-send --session --dest=org.kde.KWin --print-reply /Scripting/Script<ID> org.kde.kwin.Script.run`
4. **Read output** from the journal: `journalctl -t kwin_wayland -n 20 --no-pager`

To modify window state, set properties in the script (e.g. `c.fullScreen = false`). The `queryWindowInfo` D-Bus method on `/KWin` only returns info for the currently active window, so the scripting approach is needed to find a specific window by class or caption.

# Forked Repositories

When working in a forked repo owned by the user (i.e. their own fork, not upstream):

- **CLAUDE.md must exist.** If one is missing, create it. It should document the project structure, build/dev instructions, code style conventions, and a "Fork Changes" section listing all modifications made relative to upstream with enough detail to understand what was changed and where.
- **README must acknowledge the fork.** Update the existing README (usually `.md` or `.rst`) to note that it is a personal fork near the top, and summarize fork-specific changes so they are visible to anyone browsing the repo. Do not remove upstream content -- add a fork notice above it.
- Keep both files up to date when making further fork changes.

# Claude Agent SDK

The Agent SDK (`claude-agent-sdk` Python package) spawns the Claude Code CLI as a subprocess. It does not call the Anthropic API directly. This means:

- It inherits CLI authentication (OAuth from `~/.claude/.credentials.json`)
- No `ANTHROPIC_API_KEY` needed when the CLI is logged in via a Max/Pro plan
- The Anthropic docs warning about API keys applies to third-party developers distributing products, not personal tooling on your own machine
- Reference project with working tests: `~/claude-agent-sdk/`

# API Documentation

`~/git/api-docs` contains API documentation for various services. Reference this when working with APIs that may have docs there.
