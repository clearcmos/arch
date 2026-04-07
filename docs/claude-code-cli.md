# Claude Code CLI Inline Usage

Run Claude Code non-interactively from the command line.

## One-Shot Mode (`-p`)

The `-p` (or `--print`) flag runs a single prompt and exits:

```bash
claude -p "explain this function"
cat logs.txt | claude -p "analyze these errors"
```

## System Prompt

| Flag | Description |
|------|-------------|
| `--system-prompt "..."` | Replace the entire default system prompt |
| `--system-prompt-file ./file.txt` | Replace from a file |
| `--append-system-prompt "..."` | Append to the default prompt |
| `--append-system-prompt-file ./file.txt` | Append from a file |

Prefer the append variants -- replacing the system prompt strips Claude Code's built-in tool instructions.

## Other Flags

```bash
claude -p --tools "Bash,Read,Edit" "prompt"           # restrict available tools
claude -p --model opus "prompt"                        # pick a model
claude -p --output-format json "prompt"                # structured JSON output
claude -p --max-turns 3 "prompt"                       # limit execution turns
claude -p --dangerously-skip-permissions "prompt"      # auto-approve all tools
claude -p --bare "prompt"                              # skip hooks, skills, CLAUDE.md
claude -c -p "follow-up"                               # continue last conversation
claude -n "session-name" "prompt"                       # named session
```

## Examples

Pipe a file and ask a question:

```bash
cat src/main.rs | claude -p "find any bugs"
```

One-shot with a custom system prompt appended:

```bash
claude -p --append-system-prompt "Always respond in bullet points" "summarize this repo"
```

Scripted usage with JSON output:

```bash
result=$(claude -p --output-format json "list all TODO comments in this project")
```
