When the user says **"update-skill"** (or similar like "update the skill", "improve the skill"), perform a retrospective on the current session and update the skill files to capture lessons learned:

### What to do:
1. **Identify pain points**: Review the session for errors, wrong assumptions, wasted steps, failed API calls, or incorrect conclusions
2. **Fix documentation bugs**: Correct any instructions in SKILL.md or supporting files that led to mistakes
3. **Add new knowledge**: If the session uncovered a new workflow, workaround, or edge case not already documented -- add it to the relevant supporting file
4. **Remove stale info**: If anything documented is now wrong or outdated, fix or remove it
5. **Present changes**: Summarize what was changed and why, in a table format

### Keep SKILL.md concise (~500 lines target)
SKILL.md is loaded into context on every skill invocation. Keep it lean:
- Detailed reference content belongs in supporting files
- SKILL.md should contain workflow steps, decision logic, and brief instructions -- then point to reference files for details
- If an update would push SKILL.md significantly past ~500 lines, move the detailed content to a reference file and add a short pointer instead

### Where to save changes:
- Update the skill files in `~/.claude/skills/find-conversation/`

### What NOT to do:
- Don't make changes that aren't grounded in actual session experience
- Don't restructure or reformat files for cosmetic reasons
- Don't add speculative documentation about things that weren't encountered
