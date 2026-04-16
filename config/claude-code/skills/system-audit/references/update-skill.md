# update-skill Directive

When the user says **"update-skill"** (or similar like "update the skill", "improve the skill"), perform a retrospective on the current session and update the skill files to capture lessons learned.

## What to do:
1. **Identify pain points**: Review the session for errors, wrong assumptions, wasted steps, or incorrect output
2. **Fix documentation bugs**: Correct any instructions in SKILL.md or supporting files that led to mistakes
3. **Add new knowledge**: If the session uncovered a new pattern, edge case, or improvement - add it to the relevant file (SKILL.md for workflow changes, references/ for domain knowledge)
4. **Remove stale info**: If anything documented is now wrong or outdated, fix or remove it
5. **Present changes**: Summarize what was changed and why

## Keep SKILL.md lean
Target ~500 lines. If an update would push it past that, move detailed content to a supporting file in `references/`.

## What NOT to do:
- Don't make changes that aren't grounded in actual session experience
- Don't restructure or reformat files for cosmetic reasons
- Don't add speculative documentation about things that weren't encountered
