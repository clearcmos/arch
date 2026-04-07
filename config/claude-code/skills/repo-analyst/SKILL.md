---
name: repo-analyst
description: "Navigate and analyze repositories under ~/git to gather information for current tasks"
user-invocable: true
disable-model-invocation: true
---

# Repo Analyst

Search and analyze repositories under `~/git` to gather information needed for the current task.

## Repository Structure

```
~/git/
├── mine/       # Personal projects (owned by nicholas)
├── reference/  # Reference repos for research and learning
└── forked/     # Forked repositories
```

## How to Use This Skill

When invoked, search for the relevant repository and extract the information needed.

### Step 1: Find the Repository

Search for repos by partial name match across all three directories:

```bash
# Find repo by partial name (case-insensitive)
find ~/git -maxdepth 2 -type d -iname "*<partial-name>*" 2>/dev/null
```

Or list all repos in a category:

```bash
ls ~/git/mine/
ls ~/git/reference/
ls ~/git/forked/
```

### Step 2: Understand the Repository

Once located, gather context:

1. **Check for CLAUDE.md** - Project-specific instructions
2. **Check README.md** - Overview and usage
3. **Check package.json / Cargo.toml / pyproject.toml** - Dependencies and structure
4. **Browse src/ or main code directories** - Architecture understanding

### Step 3: Extract Relevant Information

Based on the user's goal, search for:
- Specific functions or implementations
- Patterns and conventions used
- Configuration approaches
- API designs

## Common Tasks

| Task | Approach |
|------|----------|
| Find implementation pattern | Grep for function/class names across the repo |
| Understand architecture | Read CLAUDE.md, README, main entry points |
| Compare approaches | Look at similar features across multiple repos |
| Get code examples | Find relevant files and extract snippets |

## Notes

- Always search across all three directories (mine, reference, forked) unless the user specifies which
- Use partial string matching since exact repo names may not be known
- Check for CLAUDE.md first - it often contains the most relevant project context
- Reference repos are particularly useful for seeing how established projects solve problems


## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.
