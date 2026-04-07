# Troubleshooting

Top failure modes and recovery steps for the find-conversation skill.

---

## 1. No matches found for user's keywords

**Symptom:** grep returns no results across all project directories.

**Possible causes:**
- Keywords too specific or misspelled
- Conversation was in a subagent, not the main session file
- Session was very short and may have been cleaned up
- Keywords appear in a compressed/truncated form

**Recovery:**
1. Broaden the search -- try partial keywords, regex patterns, or synonyms
2. Search subagent files: `find ~/.claude/projects/ -path "*/subagents/*.jsonl" -exec grep -l "keyword" {} +`
3. Ask the user for alternative terms or more context
4. Try date-based filtering if the user remembers when

---

## 2. Too many matches

**Symptom:** grep returns dozens of files for common terms.

**Recovery:**
1. Add more keywords and require all to be present (AND logic)
2. Filter by date range
3. Filter by project directory if the user can identify the repo
4. Use file size as a proxy -- short sessions are less likely to be the target
5. Sample a few candidates with context snippets and ask the user to identify

---

## 3. Wrong directory decoded from project folder name

**Symptom:** The `--resume` command fails because the working directory doesn't match.

**Cause:** The `-` to `/` conversion is ambiguous. A folder named `-home-user-git-my-repo` could be `~/git/my-repo` or `~/git-my/repo`.

**Recovery:**
1. Check which actual directories exist on disk: `ls ~/git/my-repo` vs `ls ~/git-my/repo`
2. Look at the first line of the JSONL file for the `cwd` field -- it contains the original working directory
3. Use the `cwd` from the JSONL to construct the correct `cd` command

**Pro tip:** The JSONL `cwd` field is authoritative. When in doubt, extract it:
```bash
head -5 <file>.jsonl | grep -o '"cwd":"[^"]*"' | head -1
```

---

## 4. Session UUID exists but `--resume` fails

**Symptom:** The file exists but `claude --resume <uuid>` reports "session not found".

**Possible causes:**
- Running from the wrong directory (must match the original `cwd`)
- The JSONL file is corrupted or incomplete
- Claude Code version mismatch (very old sessions may be incompatible)

**Recovery:**
1. Extract the `cwd` from the JSONL and `cd` there first
2. Verify the file is valid: `wc -l <file>.jsonl` (should have many lines)
3. If the session truly can't be resumed, offer to extract key content from the JSONL so the user can reference it in a new session

---

## 5. Subagent file matches but parent session unclear

**Symptom:** Keywords only appear in a subagent transcript (`subagents/agent-*.jsonl`).

**Recovery:**
The parent session UUID is the directory containing the `subagents/` folder:

```
~/.claude/projects/-home-user-git/abc123/subagents/agent-xyz.jsonl
                                  ^^^^^^
                                  parent session = abc123
```

Provide `abc123` as the resume UUID. The subagent context will be part of the parent session.
