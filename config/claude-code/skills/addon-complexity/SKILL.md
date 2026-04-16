---
name: addon-complexity
description: Analyzes a WoW addon codebase and delivers a calibrated, honest complexity assessment with a realistic time estimate for a seasoned developer. Use when user says "addon-complexity", "how complex is this addon", "how long would this take to build", or "complexity audit". Reads Lua source, TOC, and CLAUDE.md to evaluate system count, API surface, novel vs boilerplate work, and overall scope. Produces a structured verdict with tier rating, key complexity drivers, per-phase time breakdown, and honest calibration against known reference points.
user-invocable: true
disable-model-invocation: false
---

# Addon Complexity Auditor

Reads a WoW addon's source and delivers a calibrated, honest complexity assessment — not a flattering one. The goal is an accurate picture of scope, what's genuinely hard vs. boilerplate, and a realistic time estimate for a seasoned WoW addon developer who already knows the APIs.

## Critical: Calibration Principles

Before assessing, internalize these calibration rules:

**Do not oversell.** A seasoned WoW addon developer (someone who has shipped multiple addons, knows Classic APIs cold) moves fast on familiar patterns. Boilerplate is boilerplate — it doesn't add complexity just because there's a lot of it.

**Distinguish novel work from pattern work:**
- *Boilerplate*: CLEU parsing, SavedVariables, movable/resizable frames, options GUI via Settings API, slash commands, basic buff scanning, UNIT_POWER_UPDATE, row rendering loops
- *Novel / hard*: Multi-peer protocols (broadcaster election, heartbeat, stale pruning), async inspection queues with combat pausing and retry logic, cross-zone sync, subgroup-aware priority logic with stateful menus, fighting Classic Anniversary API quirks (nil role fields, hidden-frame OnUpdate deadlocks, etc.)

**Reference scale (calibrate your output against these):**
| Tier | Description | LOC (rough) | Seasoned dev time |
|------|-------------|-------------|-------------------|
| Trivial | Single tracker, one frame, no async | < 300 | Hours |
| Simple | Basic display, SavedVariables, options | 300–800 | 1–3 days |
| Mid-tier | Inspect queue, cooldown tracking, resize frames | 800–2000 | 1–2 weeks |
| Complex | Multi-peer protocol OR async queuing + rich UI | 2000–5000 | 2–4 weeks |
| Serious | Plugin architecture, multi-file, years of iteration | 5000+ | Months–years |

Grid2, HealBot, VuhDo, WeakAuras = Serious tier. Don't compare personal addons to those.

---

## Instructions

**Do NOT start analyzing automatically when this skill loads.** Greet the user briefly and wait for them to confirm they want the audit run.

### Step 1: Identify the Addon

Use the current working directory. Read:
- All `.lua` files (glob `**/*.lua`)
- The `.toc` file
- `CLAUDE.md` if present (architecture summary)
- `CHANGELOG.md` if present (feature history gives scope context)

If the working directory doesn't look like an addon, ask the user to specify the path.

### Step 2: Measure Raw Size

Count:
- Total lines of Lua (across all files)
- Number of Lua files
- Number of distinct code sections or modules (from CLAUDE.md section table if available, otherwise estimate from structure)

### Step 3: Score Each Complexity Dimension

Rate each dimension **Low / Medium / High**:

| Dimension | What to look for |
|-----------|-----------------|
| **Async / event complexity** | Inspect queues, throttled callbacks, combat gating, retry logic, deferred init |
| **Peer / network features** | Addon messages, election protocols, heartbeat/stale, cross-zone sync |
| **State management** | Volume and entanglement of mutable state, cross-system interactions |
| **API surface** | Number of distinct WoW APIs used; how many are obscure or Classic-specific |
| **UI complexity** | Frame count, resize/drag handles, custom animations, pulse overlays, context menus |
| **Classic API gotchas** | nil role fields, hidden-frame OnUpdate deadlock, numeric texture IDs, ranked spells, etc. |
| **Options/configurability** | Number of settings, proxy callbacks, per-feature toggles |
| **Preview / test systems** | Mock data, animated preview loops, simulated state |

### Step 4: Identify the True Complexity Drivers

From the dimensions above, call out the 2–4 things that actually make this hard. Everything else is boilerplate. Be specific — name the system, not just the category.

### Step 5: Assign a Tier and Time Estimate

Pick a tier from the reference scale. Then break down time:

```
Phase                          | Estimate
-------------------------------|----------
Core [main feature]            | X days
[Hard system 1]                | X days
[Hard system 2]                | X days
UI / frames / options          | X days
Bug fixing / edge cases        | X days
────────────────────────────── | ─────────
Total (seasoned dev)           | X–X weeks
```

Adjust downward if the seasoned dev has done this type of thing before (they likely have). Adjust upward only for genuinely novel problems they'd need to figure out.

### Step 6: Write the Verdict

Structure the output as:

---

## Addon Complexity Report: [AddonName]

**Tier**: [Trivial / Simple / Mid-tier / Complex / Serious]

**Size**: [N lines across N files] | [N code sections]

### Complexity Dimensions

| Dimension | Rating | Notes |
|-----------|--------|-------|
| ... | ... | ... |

### What's Actually Hard

[2–4 bullet points naming the specific systems that require real problem-solving — not just boilerplate volume]

### What's Boilerplate

[Brief list of systems that look impressive but are pattern work for a seasoned dev]

### Time Estimate (Seasoned Developer)

[Table from Step 5]

### Honest Verdict

[2–3 sentences. Be direct. Where does this sit relative to the reference scale? What would surprise even an experienced dev? What would they knock out in an afternoon?]

---

## Examples

### Example: Simple tracker
User says: `/addon-complexity` in a 400-line cooldown timer addon
Actions:
1. Reads single Lua file + TOC
2. Finds: CLEU parsing, one movable frame, SavedVariables, slash commands
3. Scores: all dimensions Low except UI (Medium for drag handle)
4. Verdict: Simple tier, 2–3 days

### Example: Complex multi-system addon
User says: `/addon-complexity` in a 4400-line healer tracking addon
Actions:
1. Reads Lua, TOC, CLAUDE.md
2. Finds: async inspect queue, broadcaster election protocol, cross-zone sync, subgroup-aware menus
3. Scores: Async = High, Peer/network = High, State = High, UI = Medium
4. Tier: Complex — 2–3 weeks for a seasoned dev
5. Calls out: broadcaster election and inspect queue as the genuine hard parts; display rendering and CLEU as boilerplate

## Troubleshooting

### No .lua files found
Ask the user to specify the addon directory path explicitly.

### CLAUDE.md missing
Proceed from source only. Note in the report that architecture docs were absent.

### Addon is minified or obfuscated
Note this and give a best-effort assessment based on file size and TOC metadata only.


## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.
