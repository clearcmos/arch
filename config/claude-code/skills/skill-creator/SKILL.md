---
name: skill-creator
description: Interactive guide for creating new Claude skills. Walks the user through use case definition, frontmatter generation, instruction writing, and validation. Use when user says "create a skill", "build a skill", "make a new skill", "help me write a skill", or "skill-creator".
user-invocable: true
disable-model-invocation: false
---

# Skill Creator

Interactive workflow for building well-structured Claude skills. This skill guides users through every step — from defining use cases to producing a validated, ready-to-use skill folder.

## Instructions

### Step 1: Gather Requirements

Ask the user these questions (skip any they've already answered):

1. **What should the skill do?** Get a clear description of the skill's purpose.
2. **What are 2-3 concrete use cases?** Specific scenarios a user would trigger this skill for.
3. **What trigger phrases would a user say?** The natural language that should activate it.
4. **Does it need MCP servers, scripts, or external tools?** Or is it standalone using Claude's built-in capabilities?
5. **What category does it fall into?**
   - Document/Asset Creation (consistent output generation)
   - Workflow Automation (multi-step processes)
   - MCP Enhancement (workflow guidance for MCP tool access)
6. **Where should the skill be installed?** Default: `~/.claude/skills/`
7. **Should it be user-invocable?** (Can users trigger it with a slash command, or should it only activate automatically based on description matching?)

### Step 2: Generate the Skill Name

Derive a kebab-case name from the description.

Rules:
- kebab-case only: `my-skill-name`
- No spaces, underscores, or capitals
- No "claude" or "anthropic" in the name (reserved)
- Should match the folder name exactly

Present the name to the user for confirmation.

### Step 3: Write the YAML Frontmatter

Generate the frontmatter following this format:

```yaml
---
name: skill-name-here
description: [What it does]. Use when user [trigger conditions]. [Key capabilities].
user-invocable: true
disable-model-invocation: false
---
```

CRITICAL rules for the `description` field:
- MUST include BOTH what the skill does AND when to use it (trigger conditions)
- Under 1024 characters
- No XML angle brackets
- Include specific trigger phrases users might say
- Mention relevant file types if applicable
- Structure: `[What it does] + [When to use it] + [Key capabilities]`

Bad descriptions to avoid:
- Too vague: "Helps with projects."
- Missing triggers: "Creates sophisticated multi-page documentation systems."
- Too technical: "Implements the Project entity model with hierarchical relationships."

Present the frontmatter to the user for review before proceeding.

### Step 4: Write the Skill Body (SKILL.md)

After the frontmatter, write the main instructions in Markdown. Follow the recommended structure:

```
# Skill Name

[Brief overview of what this skill does]

## Instructions

### Step 1: [First Major Step]
Clear explanation of what happens.
[Include specific commands, tool calls, or actions]
Expected output: [describe what success looks like]

### Step 2: [Next Step]
...

## Examples

### Example 1: [Common scenario]
User says: "[trigger phrase]"
Actions:
1. [action]
2. [action]
Result: [expected outcome]

## Troubleshooting

### Error: [Common error message]
Cause: [Why it happens]
Solution: [How to fix]
```

Best practices for instructions:
- Be specific and actionable (not "validate the data" but "Run `python scripts/validate.py --input {filename}` to check data format")
- Include error handling for common failures
- Use progressive disclosure: keep SKILL.md focused, move detailed docs to `references/`
- Put critical instructions at the top with `## Important` or `## Critical` headers
- Use bullet points and numbered lists for clarity
- Keep SKILL.md under 5,000 words

**Privacy and sensitive data rules:**
- NEVER hardcode API keys, tokens, passwords, or secrets in skill files
- NEVER embed real names, email addresses, phone numbers, physical addresses, or other PII
- Use placeholders in templates and examples (e.g., `your-name-here`, `your-api-key`, `email@example.com`)
- If a skill references external services, use environment variables or config files for credentials — never inline secrets
- Check the **Whitelisted Identifiers** section at the bottom of this file for approved exceptions
- If something looks like it might need to contain PII or sensitive data (e.g., author attribution, service account names, project-specific IDs), **ask the user first** before including it — do not assume it's okay

### Step 5: Plan Supporting Files

Determine if the skill needs:
- **scripts/**: Executable code (Python, Bash, etc.) for validation, data processing, etc.
- **references/**: Documentation files Claude can load as needed (API guides, examples, patterns)
- **assets/**: Templates, fonts, icons used in output

For each file, explain its purpose and generate the content.

### Step 6: Create the Skill Folder

Create the complete skill folder structure:

```
skill-name/
├── SKILL.md          # Required - main skill file
├── scripts/          # Optional - executable code
├── references/       # Optional - documentation
└── assets/           # Optional - templates, etc.
```

CRITICAL rules:
- File MUST be named exactly `SKILL.md` (case-sensitive)
- Folder MUST be kebab-case
- Do NOT include a README.md inside the skill folder
- Write all files to the target directory

### Step 7: Validate the Skill

Run through this checklist with the user:

**Structure:**
- [ ] Folder named in kebab-case
- [ ] SKILL.md file exists (exact spelling)
- [ ] YAML frontmatter has `---` delimiters
- [ ] `name` field: kebab-case, no spaces, no capitals
- [ ] `description` includes WHAT and WHEN
- [ ] No XML tags anywhere in frontmatter
- [ ] Instructions are clear and actionable
- [ ] Error handling included
- [ ] Examples provided

**Privacy:**
- [ ] No API keys, tokens, passwords, or secrets hardcoded anywhere
- [ ] No PII (real names, emails, phone numbers, addresses) unless whitelisted
- [ ] Templates use placeholders instead of real values
- [ ] Any borderline cases were confirmed with the user before inclusion

**Triggering (suggest the user test these):**
- [ ] Should trigger on obvious related tasks
- [ ] Should trigger on paraphrased requests
- [ ] Should NOT trigger on unrelated topics

Ask Claude: "When would you use the [skill-name] skill?" to verify the description works.

### Step 8: Add `update-skill` Directive

Every generated SKILL.md must include a lightweight `update-skill` directive near the end (before Troubleshooting if present). This is a self-learning mechanism — it lets the agent improve the skill based on real session experience.

**Important: keep the directive to 2 lines in SKILL.md.** The full instructions live in a separate file to avoid context bloat (SKILL.md body loads into every conversation).

1. Create `references/update-skill.md` in the skill folder with the full directive content (copy from this skill's own `references/update-skill.md`)
2. Add this 2-line section to the generated SKILL.md:

```markdown
## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.
```

### Step 9: Iterate and Improve

After the skill is created, offer to help with:
- **Undertriggering**: Skill doesn't load when it should — add more trigger phrases and keywords to description
- **Overtriggering**: Skill loads for irrelevant queries — add negative triggers, be more specific
- **Execution issues**: Inconsistent results — improve instructions, add error handling
- **Large context issues**: Skill too big — move detailed docs to `references/`, keep SKILL.md under 5,000 words

## Patterns Reference

When designing the skill body, consider which pattern fits best:

1. **Sequential Workflow** — Multi-step processes in a specific order with dependencies and validation gates
2. **Multi-MCP Coordination** — Workflows spanning multiple services with clear phase separation
3. **Iterative Refinement** — Output that improves with iteration cycles and quality checks
4. **Context-Aware Selection** — Same outcome achieved via different tools depending on context
5. **Domain-Specific Intelligence** — Specialized knowledge embedded beyond basic tool access

Consult `references/guide-summary.md` for the full pattern details and examples.

## Troubleshooting

### Error: "Could not find SKILL.md in uploaded folder"
Cause: File not named exactly SKILL.md
Solution: Rename to SKILL.md (case-sensitive). Verify with `ls -la`.

### Error: "Invalid frontmatter"
Cause: YAML formatting issue — missing `---` delimiters or unclosed quotes
Solution: Ensure frontmatter starts and ends with `---` on their own lines. Check for unclosed quotes.

### Error: "Invalid skill name"
Cause: Name has spaces or capitals
Solution: Use kebab-case only: `my-cool-skill` not `My Cool Skill`

### Skill doesn't trigger
Cause: Description too vague or missing trigger phrases
Solution: Add specific trigger phrases users would say. Include relevant keywords and file types.

### Skill triggers too often
Cause: Description too broad
Solution: Add negative triggers ("Do NOT use for..."), be more specific about scope.

## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.

## Whitelisted Identifiers

The following identifiers are approved for use in skills without asking. Everything else that looks like PII or sensitive data must be confirmed with the user first.

- `clearcmos` — GitHub username, okay for author fields, LICENSE, README templates
- `_cmos` — Discord handle, okay for contact/community sections
- `nicholas` — Local username, okay for `author:` metadata fields

<!-- Add new whitelisted entries here as needed -->
