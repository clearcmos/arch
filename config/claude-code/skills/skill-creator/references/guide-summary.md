# Claude Skills Guide - Quick Reference

## What is a Skill?

A skill is a folder containing:
- **SKILL.md** (required): Instructions in Markdown with YAML frontmatter
- **scripts/** (optional): Executable code (Python, Bash, etc.)
- **references/** (optional): Documentation loaded as needed
- **assets/** (optional): Templates, fonts, icons used in output

## Progressive Disclosure (Three Levels)

1. **YAML frontmatter**: Always loaded in system prompt. Tells Claude WHEN to use the skill.
2. **SKILL.md body**: Loaded when Claude thinks it's relevant. Full instructions.
3. **Linked files**: Additional files Claude discovers as needed.

## YAML Frontmatter Reference

### Required Fields

```yaml
---
name: skill-name-in-kebab-case
description: What it does and when to use it. Include specific trigger phrases.
---
```

### Optional Fields

```yaml
license: MIT
user-invocable: true
disable-model-invocation: false
compatibility: "Requires Python 3.10+, network access"
allowed-tools: "Bash(python:*) Bash(npm:*) WebFetch"
metadata:
  author: Company Name
  version: 1.0.0
  mcp-server: server-name
  category: productivity
  tags: [project-management, automation]
```

### Security Restrictions
- No XML angle brackets in frontmatter
- No "claude" or "anthropic" in skill name (reserved)

## Description Field Best Practices

Structure: `[What it does] + [When to use it] + [Key capabilities]`

### Good Examples

```yaml
# Specific and actionable
description: Analyzes Figma design files and generates developer handoff documentation. Use when user uploads .fig files, asks for "design specs", "component documentation", or "design-to-code handoff".

# Includes trigger phrases
description: Manages Linear project workflows including sprint planning, task creation, and status tracking. Use when user mentions "sprint", "Linear tasks", "project planning", or asks to "create tickets".

# Clear value proposition
description: End-to-end customer onboarding workflow for PayFlow. Handles account creation, payment setup, and subscription management. Use when user says "onboard new customer", "set up subscription", or "create PayFlow account".
```

### Bad Examples

```yaml
# Too vague
description: Helps with projects.

# Missing triggers
description: Creates sophisticated multi-page documentation systems.

# Too technical, no user triggers
description: Implements the Project entity model with hierarchical relationships.
```

## Skill Categories

### Category 1: Document & Asset Creation
- Creating consistent, high-quality output (documents, presentations, apps, designs, code)
- Key techniques: embedded style guides, template structures, quality checklists
- No external tools required — uses Claude's built-in capabilities

### Category 2: Workflow Automation
- Multi-step processes that benefit from consistent methodology
- Key techniques: step-by-step workflow with validation gates, templates, iterative refinement loops

### Category 3: MCP Enhancement
- Workflow guidance to enhance MCP server tool access
- Key techniques: coordinates multiple MCP calls, embeds domain expertise, error handling

## Workflow Patterns

### Pattern 1: Sequential Workflow Orchestration
Use when: Multi-step processes in a specific order.
- Explicit step ordering
- Dependencies between steps
- Validation at each stage
- Rollback instructions for failures

### Pattern 2: Multi-MCP Coordination
Use when: Workflows span multiple services.
- Clear phase separation
- Data passing between MCPs
- Validation before moving to next phase
- Centralized error handling

### Pattern 3: Iterative Refinement
Use when: Output quality improves with iteration.
- Explicit quality criteria
- Iterative improvement loops
- Validation scripts
- Know when to stop iterating

### Pattern 4: Context-Aware Tool Selection
Use when: Same outcome, different tools depending on context.
- Clear decision criteria
- Fallback options
- Transparency about choices

### Pattern 5: Domain-Specific Intelligence
Use when: Skill adds specialized knowledge beyond tool access.
- Domain expertise embedded in logic
- Compliance/validation before action
- Comprehensive documentation
- Clear governance

## File Structure Rules

```
your-skill-name/
├── SKILL.md              # Required - exactly this name
├── scripts/              # Optional
├── references/           # Optional
└── assets/               # Optional
```

- SKILL.md must be exactly `SKILL.md` (case-sensitive)
- Folder name must be kebab-case
- No README.md inside skill folder
- No spaces, underscores, or capitals in folder name

## Validation Checklist

### Before Upload
- [ ] Folder named in kebab-case
- [ ] SKILL.md exists (exact spelling)
- [ ] YAML frontmatter has `---` delimiters
- [ ] `name`: kebab-case, no spaces, no capitals
- [ ] `description` includes WHAT and WHEN
- [ ] No XML tags anywhere
- [ ] Instructions are clear and actionable
- [ ] Error handling included
- [ ] Examples provided

### After Upload
- [ ] Test triggering on obvious tasks
- [ ] Test triggering on paraphrased requests
- [ ] Verify doesn't trigger on unrelated topics
- [ ] Monitor for under/over-triggering
- [ ] Iterate on description and instructions

## Troubleshooting Quick Reference

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Skill won't upload | SKILL.md not found or bad YAML | Check filename, check `---` delimiters |
| Never triggers | Description too vague | Add trigger phrases, be specific |
| Triggers too often | Description too broad | Add negative triggers, narrow scope |
| MCP calls fail | Connection/auth issue | Verify MCP server, check API keys |
| Instructions ignored | Too verbose or buried | Put critical info first, use lists |
| Slow/degraded | Too much context | Move docs to references/, reduce size |

## Best Practices for Instructions

- Be specific and actionable
- Include error handling for common failures
- Use progressive disclosure (SKILL.md focused, details in references/)
- Put critical instructions at the top
- Use bullet points and numbered lists
- Keep SKILL.md under 5,000 words
- Add explicit quality encouragement for important steps
