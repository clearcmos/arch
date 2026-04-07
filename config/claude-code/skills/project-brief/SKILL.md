---
name: project-brief
description: Generates a polished, self-contained HTML technical brief for a project. Use when user says "project brief", "brief me on this", "build a brief", "create a brief for", "summarize this project", or provides a repo/idea/material and wants a structured visual summary. Produces a single HTML file with architecture diagrams, key decisions, engineering patterns, talking points, and quick reference — all sanitized with no proprietary details.
user-invocable: true
disable-model-invocation: false
metadata:
  author: nicholas
  version: 1.0.0
  category: document-creation
---

# Project Brief Generator

Generates a self-contained HTML technical brief from any source material — a repo, an idea, notes, or a conversation. The output is a polished, printable single-file HTML document with no external dependencies.

## Important

- **NEVER** include the word "interview" anywhere in the output file
- **NEVER** hardcode company names, API keys, internal system names, or proprietary code
- **Sanitize everything** — describe architecture, patterns, and decisions, not source code
- All details should be abstract enough to share publicly but specific enough to be impressive
- The HTML must be fully self-contained (inline CSS, no external fonts/scripts/images)
- **NEVER** use em dashes (`&mdash;`, `—`) anywhere in the output - use normal dashes (`-`) instead
- **NEVER** use emojis anywhere in the output

## Instructions

### Step 1: Gather Source Material

Ask the user what they want to brief. Accept any of:
- A **repo path** — you will explore it using Explore subagents
- An **idea or description** — you will structure it from the narrative
- **Existing docs/notes** — you will read and synthesize them
- A **combination** of the above

If given a repo, ask:
- "Which parts should I focus on? Any folders to skip?"
- "What's the one-line pitch for what this does?"

If the user has already provided this context in the conversation, skip asking and proceed.

### Step 2: Deep Research

For repos, launch Explore subagents to understand:
1. **Purpose** — what it is, why it exists, what problem it solves
2. **Architecture** — layers, modules, how components connect
3. **Tech stack** — languages, frameworks, APIs, cloud services, tools
4. **Scale** — file counts, line counts, system integrations, users
5. **Key engineering decisions** — the non-obvious choices and why they were made
6. **Patterns** — recurring design patterns, conventions, quality controls
7. **What it ISN'T** — common misconceptions to preempt

For ideas/notes, extract the same dimensions from the material provided.

### Step 3: Plan the Sections

Every brief follows this structure (skip sections that don't apply):

1. **Title + Subtitle** — project name + "Technical Brief"
2. **Sanitization Notice** — red banner: no proprietary details
3. **One-Line Pitch** — blue callout box, 2-3 sentences max. Focus on the business problem and what you built.
4. **Architecture** — layered diagram using nested indented boxes (CSS, not images). Only if the project has meaningful layers.
5. **Key Technical Decisions** — cards with PROBLEM / CHOICE / RESULT labels. These are the meat — what was hard, what you chose, what happened.
6. **Spotlight: Key Components** — 2-4 cards with workflow steps or bullet points. Only the most important parts.
7. **How I Drive AI** — (only for AI-related projects) What AI engineering problems you solved. Not "I used AI" but how you programmed, constrained, and made it reliable.
8. **Talking Points** — conversational Q&A format: "Tell me about this project", "What was the hardest part?", "What did you learn?" Keep answers natural, like you'd actually say them. No corporate-speak.
9. **Footer** — "not for distribution" notice

## What NOT to include

- **No "By the Numbers" stat grids.** No line counts, no vanity metrics. Numbers only appear naturally where they convey real meaning.
- **No "What This Isn't" sections.** Defensive. If the brief is strong, you don't need to apologize.
- **No "Quick Reference" tables.** Tech stack is obvious from context. Padding.
- **No "Engineering Patterns" grids.** If a pattern matters, it belongs in Key Decisions or Talking Points, not a separate showcase section.
- **No "Systems Integrated" tag clouds.** Showing off. Systems come up naturally in the architecture and decisions.
- **No tool/line-count inventories.** Nobody cares about a numbered list of tools with line counts.
- **No marketing language.** Write like a person talking to another person, not a brochure.

Present the planned sections to the user for approval before generating HTML.

### Step 4: Generate the HTML

Read the reference template at `references/html-template.md` for the exact CSS classes and HTML patterns to use.

Rules:
- Single self-contained HTML file — all CSS inline in `<style>`, no external dependencies
- Must look good in browser AND print cleanly to PDF (include `@media print` rules)
- Use the exact CSS variable system from the template (--accent, --muted, --green, etc.)
- Use the exact HTML component patterns (`.card`, `.stat`, `.pitch`, `.decision`, `.wf-step`, `.sys-tag`, `.talk-point`, `.pattern-box`)
- Responsive — works on mobile via `@media (max-width: 600px)` rules
- No JavaScript
- No emoji

### Step 5: Write the File

Ask the user where to save the file. Default: current working directory as `project-brief-{project-name}.html`.

Write the file using the Write tool.

### Step 6: Offer Iteration

After writing, tell the user the file path and offer to:
- Adjust any section's content or tone
- Add/remove sections
- Change the accent color scheme
- Generate a brief for a companion project or related repo

## Sanitization Rules

Replace real details with abstract descriptions:
- Company names → "the organization", "the team"
- Internal tool names → generic descriptions ("identity provider", "ticketing system")
- API endpoints → describe the integration, not the URL
- Specific field IDs → "custom fields", "configured values"
- Employee names → never include
- BUT keep: technology names (Terraform, Python, Okta, etc.), architectural patterns, scale numbers, design decisions


## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.
