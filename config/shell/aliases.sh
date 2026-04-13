# Arch repo aliases
alias arch='cd ~/arch'
alias a='cd ~/arch && claude'

# Claude Code
alias c='claude'

# Update checker
alias check-updates='~/arch/tools/check-updates.sh'

# GitHub repo management
alias gvis='ghrepo visibility'
alias gvisibility='ghrepo visibility'

# Claude Code inline push (reuses /push skill)
cpush() {
  claude -p \
    --verbose \
    --output-format stream-json \
    --dangerously-skip-permissions \
    --tools "Bash,Read,Edit" \
    --append-system-prompt-file ~/arch/config/claude-code/commands/push.md \
    "Run /push.${1:+ Use this commit message: $1}" \
    2>&1 | jq -rj '
      if .type == "assistant" then
        [.message.content[]? |
          if .type == "tool_use" then
            "\(.input.command // .input.file_path // .name)\n"
          elif .type == "text" then
            "\n\(.text)\n"
          else empty end
        ] | join("")
      elif .type == "user" and .tool_use_result then
        (if (.tool_use_result | type) == "string" then .tool_use_result
         else (.tool_use_result.stdout // "") end) |
        if . != "" then
          split("\n") | if length > 6 then .[:3] + ["  ...(\(length - 3) more lines)"] else . end |
          map("  \(.)") | join("\n") + "\n"
        else empty end
      elif .type == "result" then empty
      else empty end
    ' | mdriver
}

# Standard
alias ls='ls -lh --color=auto --group-directories-first'
compress() { local target="${1:-.}"; local name=$(basename "$(realpath "$target")"); tar --zstd -cf "${name}.tar.zst" -C "$target" .; }
function du { command du -h --max-depth=1 "$@" | sort -h; }
alias gen='openssl rand -base64 45'
alias mine='sudo chown -R $(whoami):$(whoami)'
alias r='sudo -i'
alias cpath='pwd | tr -d '\''\n'\'' | wl-copy && echo "Copied: $(pwd)"'
alias addons='cd "/mnt/data/games/World of Warcraft/_anniversary_/Interface/AddOns"'

# Google Tasks CLI
alias task='uv run ~/git/tasks/task.py'
