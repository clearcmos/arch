# Search Strategy Reference

Detailed patterns for finding conversations efficiently.

---

## Directory Structure Cheat Sheet

```
~/.claude/projects/
├── -home-user-git/                           # Sessions started from ~/git
│   ├── abc123.jsonl                          # Main conversation transcript
│   ├── abc123/subagents/agent-xyz.jsonl      # Subagent transcripts
│   └── def456.jsonl                          # Another session
├── -home-user-git-my-repo/                   # Sessions started from ~/git/my-repo
│   └── ...
└── -home-user-Downloads/                     # Sessions started from ~/Downloads
    └── ...
```

**Decoding directory names:**
- Strip the leading `-`
- Replace `-` with `/` to reconstruct the path
- Ambiguity: `my-repo` vs `my/repo` both encode as `my-repo`. Check what exists on disk.

---

## Search Patterns by Scenario

### User remembers specific terms

Best case. Use direct grep:

```bash
grep -rl "exact phrase or term" ~/.claude/projects/*/
```

Use `-l` to get file paths only (much faster than printing all matches).

### User remembers the topic but not exact words

Generate synonym sets. For example, if the user says "the one about deleting Gmail stuff":
- Search terms: `delete.*label`, `gmail.*message`, `remove.*label`, `batch.*delete`, `label.*delet`
- Also try domain-specific terms: `archive`, `GAM`, `gmail_v1`

### User remembers approximately when

Use `find` with date filters:

```bash
# Modified in the last 7 days
find ~/.claude/projects/ -name "*.jsonl" -mtime -7 -size +10k

# Modified between two dates
find ~/.claude/projects/ -name "*.jsonl" -newermt "2026-02-20" ! -newermt "2026-02-26"
```

Combine with grep:

```bash
find ~/.claude/projects/ -name "*.jsonl" -mtime -7 -size +10k -exec grep -l "keyword" {} +
```

### User remembers the project/directory

Map directly to the encoded folder and search only there:

```bash
grep -l "keyword" ~/.claude/projects/-home-user-git-my-repo/*.jsonl
```

---

## Scoring Heuristics

When multiple files match, rank candidates:

| Signal | Weight | How to check |
|--------|--------|-------------|
| All user keywords present | High | `grep -c` for each keyword |
| File size > 100KB | Medium | `ls -la` -- larger sessions are more substantive |
| Date matches user's hint | High | `stat -c '%y'` on the file |
| Project dir matches hint | High | Directory name |
| Keywords in user messages (not just tool output) | Medium | Grep for `"type":"user"` near the keyword |

### Quick scoring script

```bash
# Count how many of the search terms appear in each candidate
for f in <candidates>; do
  score=0
  for term in "term1" "term2" "term3"; do
    grep -ql "$term" "$f" && score=$((score + 1))
  done
  echo "$score - $(stat -c '%y' "$f") - $f"
done | sort -rn
```

---

## Extracting User Messages from JSONL

After narrowing to a few candidates with keyword grep, **immediately extract the first real user messages** to identify conversations. This is far more efficient than repeatedly grepping for more keywords.

The JSONL format stores user messages with `"type": "user"` at the top level. Content is nested at `obj['message']['content']` and can be a plain string or a list of content blocks (each with `"type": "text"` and a `"text"` field). Other top-level `type` values include `"permission-mode"`, `"file-history-snapshot"`, `"assistant"`, etc. -- only `"user"` contains user messages. Skip boilerplate lines (skill invocations, command output, etc.):

```bash
python3 -c "
import json, sys
with open('CANDIDATE_FILE') as fh:
    found = 0
    for line in fh:
        if found >= 5: break
        try:
            obj = json.loads(line)
            if obj.get('type') != 'user': continue
            content = obj.get('message', {}).get('content', '')
            if isinstance(content, list):
                text = ' '.join(c.get('text','') for c in content if isinstance(c, dict) and c.get('type')=='text')
            elif isinstance(content, str):
                text = content
            else: continue
            # Skip boilerplate
            if any(s in text for s in ['<command-message>', 'Base directory', '<local-command']):
                continue
            if len(text.strip()) < 5: continue
            found += 1
            print(f'MSG {found}: {text[:300]}')
        except: pass
"
```

**Best practice:** Run this across all candidates in a single loop early in the search. Wrap it in a `for f in CANDIDATE_FILES` shell loop, printing the session ID and date alongside messages. This usually identifies the right conversation in one step.

---

## Performance Tips

- **Always use `-l` flag** with grep when scanning many files -- stops reading after first match per file.
- **Filter by size first**: `find ... -size +10k` skips tiny/empty sessions.
- **Search main files before subagents**: Subagent files are in subdirectories, so `*.jsonl` at the directory level only hits main transcripts.
- **Avoid `grep -r` on the entire projects directory** -- there can be hundreds of files. Narrow to specific project folders first.
- **Use `head` on grep output** to avoid flooding the terminal with matches from large files.
