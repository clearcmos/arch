# Global Rules

These apply to all projects.

- Never run sudo commands. The user will handle anything requiring root privileges themselves.
- Never run package install commands (pacman, paru, etc.) directly. Ask the user to run them instead.
- Do not add co-authorship lines (e.g. `Co-Authored-By`) to git commits.
- Do not use emojis anywhere - not in code, commits, comments, or documentation.
- Do not use em dashes. Use regular hyphens instead.
- Never commit PHI, PII, secrets, credentials, API keys, tokens, or any sensitive data. Always review staged changes for sensitive content before committing.

# Claude Agent SDK

The Agent SDK (`claude-agent-sdk` Python package) spawns the Claude Code CLI as a subprocess. It does not call the Anthropic API directly. This means:

- It inherits CLI authentication (OAuth from `~/.claude/.credentials.json`)
- No `ANTHROPIC_API_KEY` needed when the CLI is logged in via a Max/Pro plan
- The Anthropic docs warning about API keys applies to third-party developers distributing products, not personal tooling on your own machine
- Reference project with working tests: `~/claude-agent-sdk/`
