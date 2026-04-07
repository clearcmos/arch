---
name: audit-addon
description: "WoW addon code quality auditor - checks for unnecessary globals, performance issues, deprecated APIs, and optimization opportunities using vscode-wow-api reference"
user-invocable: true
disable-model-invocation: true
---

# WoW Addon Code Quality Auditor

Audit WoW addon Lua code for unnecessary globals, performance issues, deprecated APIs, and optimization opportunities. Produces a structured report with severity ratings and concrete fixes.

## Reference

- **vscode-wow-api annotations**: `~/git/reference/vscode-wow-api/`
- **WoW UI source**: `~/git/reference/wow-ui-source/` (classic_anniversary branch)
- **Target client**: TBC Classic Anniversary (Interface 20505)

## Instructions

**Do NOT start auditing automatically when this skill is loaded.** Present a brief summary of what this skill does and wait for the user to explicitly ask you to run the audit.

### Step 1: Identify the Addon

Determine which addon to audit. If the user doesn't specify, use the current working directory. Read all `.lua` files and the `.toc` file.

### Step 2: Run the Audit via Parallel Sub-Agents

The audit has 4 independent categories. To avoid flooding the main context with thousands of lines of Lua source, **spawn two parallel Task agents** (subagent_type: `general-purpose`) that each handle two categories:

**Agent A — Globals + Performance** (Categories 1 & 2): Read all `.lua` files and the `.toc` file. Check for unnecessary globals and performance issues. Return findings in the standard format (see below). Include the full content of `references/performance-checklist.md` in the agent prompt so it has the reference material.

**Agent B — Deprecated APIs + Code Quality** (Categories 3 & 4): Read all `.lua` files. Check for deprecated/problematic APIs and code quality issues. Return findings in the standard format. Include the full content of `references/deprecated-apis.md` in the agent prompt.

Each agent must return findings in this format for each issue:
- **Severity**: Critical / Warning / Info
- **Location**: file:line
- **Issue**: What's wrong
- **Fix**: Concrete code to replace it with

Once both agents return, merge their findings into a single report in the main context (Step 3).

#### Category 1: Unnecessary Globals (Critical)

Any variable or function not declared with `local` that isn't intentionally global (addon namespace, SlashCmd handlers, or XML-referenced globals).

**Check for:**
- Functions defined without `local` (except slash command handlers like `SlashCmdList["MYADDON"]`)
- Variables assigned without `local` at file scope
- Loop variables leaking to global scope
- Accidental global writes inside functions (missing `local` on first assignment)

**How to detect:** Search for function/variable definitions at the top indentation level that lack `local`. Cross-reference with the TOC file and XML references to identify intentional globals.

**Exceptions (not issues):**
- `SlashCmdList["NAME"]` and `SLASH_NAME1` — required globals for slash commands
- Frame names passed to `CreateFrame()` — intentional named globals
- Mixin tables explicitly designed for global access
- The addon's main namespace variable from `local addonName, ns = ...`

#### Category 2: Performance Issues (Warning/Critical)

Consult `references/performance-checklist.md` for the full list. Key items:

**Localization of hot-path functions:**
- Any `C_*` namespaced function called inside a loop or frequently-called function should be localized at file scope: `local GetSpellInfo = C_LFGList.GetSearchResultInfo`
- WoW already provides pre-localized globals for common Lua functions (`wipe`, `tinsert`, `tremove`, `sort`, `format`, `floor`, `ceil`, `max`, `min`, `abs`, `pairs`, `ipairs`, `next`, etc.) — do NOT flag these as needing localization

**Table operations:**
- `table.remove()` inside loops — O(n) shift per removal, O(n^2) total. Use in-place compaction or `tUnorderedRemove` when order doesn't matter
- Creating new tables (`t = {}`) where `wipe(t)` could reuse an existing allocation
- Repeated table creation in hot paths (functions called per-frame or per-event)

**Frame/texture creation:**
- `CreateFrame()`, `CreateTexture()`, `CreateFontString()` inside OnUpdate, event handlers, or any function called repeatedly. These should be created once at init time
- Constant lookup tables defined inside functions that run more than once — move to file scope

**Event handling:**
- Registering for broad events when narrow alternatives exist (e.g., `RegisterEvent("UNIT_AURA")` when `RegisterUnitEvent("UNIT_AURA", "player")` would suffice)
- OnUpdate handlers on frames that may be hidden (OnUpdate doesn't fire on hidden frames)
- Missing event unregistration when no longer needed

**Redundant API calls:**
- Same API function called multiple times with the same arguments in a single code path without caching the result
- Fetching data in multiple passes when a single pass would suffice

#### Category 3: Deprecated / Problematic APIs (Warning)

Consult `references/deprecated-apis.md` for the full list. Key items:

- String texture paths (`"Interface\\Icons\\..."`) when the API returns numeric FileDataIDs — use the numeric IDs
- `getglobal()` / `setglobal()` — use `_G[name]` directly
- Old backdrop API without `BackdropTemplate` inheritance
- `this` instead of `self` in scripts (Lua 5.0 pattern)
- `arg` instead of `...` varargs (Lua 5.0 pattern)
- `math.mod` — use `%` operator or `mod()` (WoW global alias)
- Direct `UIParent` parenting without considering frame strata implications

#### Category 4: Code Quality (Info)

- Mixed indentation (tabs vs spaces)
- Inconsistent naming conventions
- Dead code (unreachable branches, unused variables)
- Missing nil checks on API returns that can be nil (e.g., `GetItemInfo()` for uncached items, `GetSpellInfo()` for invalid spell IDs)

### Step 3: Generate the Report

Merge the findings from both agents and present grouped by severity, then by category:

```
## Audit Report: [AddonName]

### Critical Issues (N)
[Must fix before release]

### Warnings (N)
[Should fix for quality]

### Info (N)
[Optional improvements]

### Summary
- Total issues: N
- Globals found: N
- Performance issues: N
- Deprecated APIs: N
- Files audited: N
```

### Step 4: Offer Fixes

After presenting the report, offer to apply fixes. Group fixes by risk:
1. **Safe fixes** — Localizing globals, moving constants to file scope (no behavior change)
2. **Low-risk fixes** — Replacing deprecated patterns, adding `local` declarations
3. **Structural fixes** — Refactoring loops, caching API calls, reordering logic (behavior-preserving but needs testing)

Always recommend testing in-game with `/reload` after applying fixes.


## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.
