---
name: find-conversation
description: Find a previous Claude Code conversation by keywords, topics, or context. Use when searching for a lost conversation, finding a past session, or when user says "find that conversation about..." or "where was the chat about...".
argument-hint: "[keywords or topic description]"
user-invocable: true
---

# Find Conversation

You search through Claude Code conversation history to locate past sessions based on keywords, topics, or contextual descriptions the user provides.

**Core principle: Search smart, not exhaustive.** The conversation store can be large. Use the user's keywords to narrow candidates quickly, then confirm matches before presenting results.

---

## Quick Reference - Supporting Files

- **[SEARCH-STRATEGY.md](SEARCH-STRATEGY.md)** - Detailed search patterns, directory structure, scoring heuristics
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Top failure modes and recovery steps

---

## How Conversations Are Stored

Claude Code stores conversation transcripts as JSONL files at:

```
~/.claude/projects/<encoded-cwd>/<session-uuid>.jsonl
```

Where `<encoded-cwd>` is the working directory path with `/` replaced by `-` and the leading `/` stripped. For example:

| Working directory | Project folder name |
|---|---|
| `/home/user/git` | `-home-user-git` |
| `/home/user/git/my-repo` | `-home-user-git-my-repo` |

Each project folder may also contain:
- `<session-uuid>/subagents/agent-*.jsonl` -- subagent transcripts for that session

The JSONL files contain one JSON object per line with message content, tool calls, and tool results interleaved.

---

## Step 1: Gather Search Terms

Extract search terms from the user's request. The user will describe the conversation by:
- **Keywords**: specific terms, file names, tool names, error messages
- **Topic**: general description of what was discussed
- **Time**: approximate date or relative time ("last week", "a few days ago")
- **Project**: which repo or directory they were working in

If the user's description is too vague (e.g., "that conversation"), ask:
- "Can you remember any specific terms, file names, or error messages from that session?"
- "Do you recall roughly when it was or which project/directory you were in?"

Aim for at least 2-3 distinct search terms before proceeding.

---

## Step 2: Identify Candidate Project Directories

List the project directories to narrow the search space:

```bash
ls ~/.claude/projects/
```

**IF the user mentioned a specific project or directory**, map it to the encoded folder name and search only that folder.

**IF the user gave a time hint**, use file modification dates to filter:

```bash
# Find JSONL files modified in a date range
find ~/.claude/projects/ -name "*.jsonl" -newermt "2026-02-20" ! -newermt "2026-02-26" -size +10k
```

**IF no project hint**, search across all project directories.

---

## Step 2.5: Exclude the Current Session

The current conversation (the one running this skill) will always match the user's search keywords because it contains them in the transcript. **Always exclude it from results.**

After finding candidates, filter out any file that contains BOTH `find-conversation` AND the user's search keywords -- that's this session. Use this pattern:

```bash
# After building candidate list, remove the current session
candidates=()
for f in $raw_candidates; do
  if grep -ql "find-conversation" "$f" && grep -ql "<user-keyword>" "$f"; then
    continue  # This is the current session -- skip
  fi
  candidates+=("$f")
done
```

Alternatively, identify the current session by finding the most recently modified JSONL in the current project directory that contains `find-conversation`. Exclude that file from results.

---

## Step 3: Search Conversation Files

Use `grep` to find JSONL files containing the user's keywords. Search the main conversation files (not subagent files) first.

### Primary search -- multiple keywords at once

```bash
grep -l "keyword1\|keyword2\|keyword3" ~/.claude/projects/<target-dir>/*.jsonl
```

### Narrowing with multiple required keywords

If the primary search returns too many results, require all keywords to appear:

```bash
# All keywords must be present in the same file
for f in ~/.claude/projects/<target-dir>/*.jsonl; do
  if grep -ql "keyword1" "$f" && grep -ql "keyword2" "$f"; then
    echo "$f"
  fi
done
```

### Scoring candidates

When multiple files match, rank them by:
1. **Keyword density**: more distinct keyword matches = better candidate
2. **File size**: larger files had longer conversations (more likely to be substantive sessions)
3. **Modification date**: closer to the user's time hint = better
4. **Project directory**: matches the user's project hint = strong signal

See [SEARCH-STRATEGY.md](SEARCH-STRATEGY.md) for detailed scoring heuristics.

---

## Step 4: Confirm the Match

Once you have a few candidates, **extract the first real user messages** from each to quickly identify the right conversation. This is much faster than iterating with more keyword greps. See the "Extracting User Messages from JSONL" section in [SEARCH-STRATEGY.md](SEARCH-STRATEGY.md) for the reusable script.

Run the extraction across all candidates in a single loop. This usually identifies the correct conversation in one step.

Present the candidates to the user with:
- **Session ID** (the UUID from the filename)
- **Date** (file modification date)
- **Working directory** (decoded from the project folder name)
- **Context snippet** (a short excerpt showing the keyword in context)

If multiple candidates look viable, ask the user to pick.

---

## Step 5: Provide the Resume Command

Once the user confirms which conversation they want, provide the resume command as a single line:

```
cd <working-directory> && claude --resume <session-uuid>
```

Where:
- `<working-directory>` is decoded from the project folder name (replace leading `-` with `/`, then replace remaining `-` with `/` only at path boundaries -- use the original folder name as the guide)
- `<session-uuid>` is the filename without `.jsonl`

**Important:** The `claude --resume` command must be run from the same working directory the original session was started in, otherwise Claude Code may not find the session.

---

## Edge Cases

- **Subagent conversations**: If the keywords only appear in a subagent file (`subagents/agent-*.jsonl`), the parent session UUID is the enclosing directory name. Provide the parent UUID for `--resume`.
- **Very old conversations**: Conversations may have been compressed or cleaned up. If no results are found, inform the user that the session may have been purged.
- **Encoded directory ambiguity**: The `-` replacement is lossy (a directory named `my-repo` and `my/repo` would encode the same). Use `ls` to check which directories actually exist on disk.
- **Large result sets**: If grep returns dozens of matches, add more keywords or use date filtering to narrow down.

---

## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.
