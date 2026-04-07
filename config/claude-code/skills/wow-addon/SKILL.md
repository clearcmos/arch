---
name: wow-addon
description: "WoW Classic Anniversary addon development - TBC API reference, Lua patterns, testing workflow"
user-invocable: true
disable-model-invocation: true
---

# WoW TBC Classic Anniversary Addon Development

Reference for developing World of Warcraft addons targeting **TBC Classic Anniversary Edition**. This is a specific client that differs from both original TBC Classic and Retail - many APIs behave differently.

## Version Information

- **Game Version**: 2.5.5
- **Build**: 65340
- **Interface**: 20505
- **Game Type**: Classic Anniversary (TBC content, level 70 cap)
- **WOW_PROJECT_ID**: 5 (unique to Anniversary edition)

**Important**: This is NOT the same as TBC Classic (WOW_PROJECT_ID = 2) or Retail. API behaviors, texture paths, and spell data can differ significantly. Always test in the actual Anniversary client.

To verify the current interface version in-game: `/run print(select(4, GetBuildInfo()))` — use this value for `## Interface:` in TOC files.

## Development Workflow

### Testing Changes

After making any code changes, **validate then copy** files to the live addon folder immediately — do not ask, just do it.

**Step 1: Local variable limit check** — Before copying, count file-scope locals (the Lua 200 limit — see Gotcha #21):
```bash
grep -c '^local ' ~/git/mine/<AddonName>/<AddonName>.lua
```
This counts unindented `local` declarations (file-scope). Thresholds:
- **< 180**: Safe, proceed with copy
- **180-195**: Warn the user ("approaching 200 local limit: N/200") but proceed
- **> 195**: **STOP**. Do NOT copy. Tell the user the file will error in-game. Consolidate locals into tables before proceeding (see Gotcha #21 for mitigations).

**Step 2: Copy to live folder**:
```bash
cp ~/git/mine/<AddonName>/<AddonName>.lua "/mnt/data/games/World of Warcraft/_anniversary_/Interface/AddOns/<AddonName>/"
```
Then tell the user to `/reload` in-game to apply changes.

Debug commands: `/fstack` (frame stack), `/eventtrace` (event trace)

### New Addon Setup

When you create a new addon (i.e., you just created its folder under the AddOns directory for the first time), **always** scaffold a git repository for it at `~/git/mine/<AddonName>/` with the full standard project structure. Use `~/git/mine/ScrollingLoot/` as the reference template for file contents and style.

**Steps:**
1. Create `~/git/mine/<AddonName>/` with subdirectories: `.github/workflows/`, `.claude/`, `assets/`
2. Copy the addon source files (`.lua`, `.xml`, `.toc`) into it
3. Create all standard project files (see table below), adapting content for the new addon
4. Run `git init`, stage all files with `git add -A`
5. Do NOT commit — leave staged for the user to review

**Key files to adapt from ScrollingLoot:**
- `.pkgmeta` — update `package-as` to the addon name
- `.github/workflows/release.yml` — copy as-is
- `.claude/settings.local.json` — copy as-is
- `.gitignore` — copy as-is (`temp/`)
- `LICENSE.md` — MIT license, author "clearcmos", current year
- `CI.md` — copy as-is, update addon name references
- `CLAUDE.md` — write fresh for the new addon (overview, architecture, features, dev workflow)
- `README.md` — write fresh for the new addon (see README Template below)
- `CHANGELOG.md` — start with `v1.0.0` containing only "Initial release." — never list out features for a first release

### Development Workflow (Before Committing)

1. **Copy live and tell user to test** - Files are automatically copied after changes (see Testing Changes above). Wait for the user to confirm they're done testing before proceeding.
2. **Update version numbers** - Before committing:
   - Add a new version section to `CHANGELOG.md` with the changes
   - Increment the version in the `.toc` file (`## Version: x.x.x`)
3. **Focused doc update** - Once the user confirms testing is done, run the `update-diff` directive:
   - Run `git diff HEAD` (or `git diff` if unstaged) to identify what changed
   - Update only the sections of `CLAUDE.md` and `README.md` that relate to those changes
   - Do NOT perform a full audit; that is reserved for the `update-full` directive
4. **Commit and push** - Only after testing and updating versions
5. **Deploy to CurseForge** - Create a tag and push to trigger CI/CD (see below)

### `update-diff` Directive

When the user says **"update-diff"**, perform a fast, diff-based documentation update scoped to recent changes. No sub-agents needed — the diff is small enough for the main context.

**Step 1**: Run `git diff HEAD` (or `git diff` if all changes are unstaged). If the working tree is clean, fall back to `git diff HEAD~1` to capture the last commit.

**Step 2**: Read the diff output and identify which documentation sections are affected:
- New features or changed behavior → update Features sections in `CLAUDE.md` and `README.md`
- New SavedVariables keys → update SavedVariables section in `CLAUDE.md`
- New entry types or UI components → update Architecture / Key Components in `CLAUDE.md`
- Changed event handling → update Events Handled in `CLAUDE.md`
- New config options → update Config GUI section in `CLAUDE.md` and Configuration Options in `README.md`
- Line number shifts → do NOT chase these; they drift naturally and are only corrected during `update-full`

**Step 3**: Make targeted edits to only the affected sections of `CLAUDE.md` and `README.md`. Do NOT touch unrelated sections. Do NOT bump version numbers or create changelog entries unless the user explicitly asks.

### `update-full` Directive

When the user says **"update-full"**, perform a full documentation audit using **parallel sub-agents** to avoid flooding the main context with thousands of lines of source code. Use this for periodic deep audits when docs may have drifted over many sessions.

**Step 1: Source inventory agent** — Spawn a Task agent (subagent_type: `general-purpose`) to read the addon's `.lua` source and produce a structured inventory:
- All `DEFAULT_SETTINGS` keys and their defaults
- Code sections with line ranges and descriptions (match the Code Sections table format in CLAUDE.md)
- All user-facing features (what the addon does, not implementation details)
- All WoW API functions used (e.g., `NotifyInspect`, `C_ChatInfo.SendAddonMessage`)
- All slash commands registered
- All Options GUI toggles/controls
- Preview/test mode mock data coverage

The agent should return this as a structured text summary — NOT the raw source.

**Step 2: Parallel doc audit agents** — Once the inventory is ready, spawn **two agents in parallel** (subagent_type: `general-purpose`):

- **CLAUDE.md audit agent**: Read the current `CLAUDE.md` and the source inventory. Return a list of specific discrepancies:
  - Features section: missing features, deprecated features still listed
  - Architecture / Key Systems: sections that don't match actual code
  - Code Sections table: wrong line ranges, missing/renamed sections
  - Key APIs: missing or removed APIs
  - Development Workflow: any inaccuracies

- **README.md audit agent**: Read the current `README.md` and the source inventory. Return a list of specific discrepancies:
  - Features section: missing user-facing features, deprecated features still listed
  - Usage / Slash Commands: inaccurate or missing commands
  - Configuration Options: missing or removed settings

**Step 3: Apply fixes** — Using the discrepancy lists from both agents, make targeted edits to `CLAUDE.md` and `README.md` in the main context. Also check `CHANGELOG.md` — verify the latest version entry includes all recent undocumented changes.

Do NOT bump version numbers or create new changelog entries unless the user explicitly asks. The goal is accuracy — ensure nothing is missing or deprecated across all three files.

### Pre-Edit Orientation

Before making non-trivial changes to an addon with 1000+ lines of source, **spawn an Explore agent** (subagent_type: `Explore`, thoroughness: `medium`) to map the relevant code before editing. The agent should identify:
- The specific code sections and line ranges that need modification
- Forward declarations, state variables, and constants the change depends on
- Other functions that call into or are called by the code being changed
- Related mock/preview data that will need updating

This returns a compact map (~20-50 lines) instead of loading the full source into the main context. Skip this for small, well-scoped changes where the CLAUDE.md Code Sections table already tells you exactly where to look.

### Feature Add/Remove Checklist

When **adding** a new trackable feature (buff, cooldown, status indicator, display option, etc.):

1. **Options GUI toggle** — if the feature is something the user might want to enable/disable, add a `showFeatureName` (or similar) entry to `DEFAULT_SETTINGS` and a corresponding checkbox in the Options GUI registration function. Gate the display/behavior behind the setting.
2. **Preview system coverage** — if the addon has a preview/test mode, add mock data so the new feature is visible in preview. If the feature has a timer or animation, hook it into the preview's OnUpdate loop.
3. **Documentation** — add the feature to the Features section in both `CLAUDE.md` and `README.md`.

When **removing** a feature:

1. **Options GUI cleanup** — remove the setting from `DEFAULT_SETTINGS` and delete the corresponding checkbox from the Options GUI.
2. **Preview system cleanup** — remove related mock data and preview loop logic.
3. **Documentation** — remove the feature from `CLAUDE.md` and `README.md`.

Use judgement on whether a feature warrants an Options toggle — not everything needs one. Simple internal improvements or bug fixes don't. User-facing behaviors that someone might want to turn off do.

**Post-change verification** — After completing a feature add or remove, spawn a Task agent (subagent_type: `general-purpose`) to verify all touchpoints were hit. The agent should read the addon's `.lua` source and check:
- `DEFAULT_SETTINGS` has/lacks the relevant key
- Options GUI registration has/lacks the corresponding checkbox
- Preview system has/lacks related mock data
- `CLAUDE.md` Features section includes/excludes the feature
- `README.md` Features section includes/excludes the feature

The agent returns a pass/fail checklist. Fix any misses before proceeding.

### Manual Zip

For manual CurseForge uploads, zip from the parent directory so the addon folder is included:

```bash
cd ~/git/mine && \
rm -f ~/<AddonName>-*.zip && \
zip -r ~/<AddonName>-$(grep "## Version:" <AddonName>/<AddonName>.toc | cut -d' ' -f3 | tr -d '\r').zip \
    <AddonName>/<AddonName>.toc <AddonName>/<AddonName>.lua <AddonName>/LICENSE.md
```

### Deployment to CurseForge

Tag and push to trigger the GitHub Actions pipeline:
```bash
git tag v1.0.3
git push origin main --tags
```

Each addon repo needs two GitHub secrets: `CF_API_KEY` (reusable across all addons) and `CURSEFORGE_PROJECT_ID` (unique per addon). See `ci-reference.md` for complete setup, workflow YAML, `.pkgmeta` format, and troubleshooting.

### Standard Project Structure

Each addon repository should include:

| File | Purpose |
|------|---------|
| `.github/workflows/release.yml` | GitHub Actions for CurseForge deployment |
| `.claude/settings.local.json` | Claude Code permissions for web research |
| `.pkgmeta` | BigWigsMods packager configuration |
| `CI.md` | Deployment instructions and setup guide |
| `CHANGELOG.md` | Version history (used by packager) |
| `LICENSE.md` | MIT license |
| `README.md` | CurseForge description |
| `CLAUDE.md` | Development instructions for Claude Code |
| `assets/` | Logo and screenshots for CurseForge |
| `.gitignore` | Git ignore patterns |

### README Template (for CurseForge)

Follow this section structure consistently:

```markdown
# AddonName

**AddonName** one-sentence description of what it does.

Built specifically for **TBC Classic Anniversary**.

---

## Features

- **Feature name** - Description
- ...

---

## Usage

Type `/cmd` to open the options panel.

### Slash Commands

- `/cmd` - Description
- ...

---

## Configuration Options

- Option 1
- Option 2
- ...

---

## License

MIT License - Open source and free to use.

---

## Feedback & Issues

Found a bug or have a suggestion? Reach me on Discord: `_cmos` or open an issue on GitHub: https://github.com/clearcmos/AddonName
```

Add additional sections between Configuration Options and License as needed (e.g., "Supported Instances" for RepSync). Keep the tone factual — no marketing fluff. Prefer Discord handle over CurseForge comments for feedback — most addon users and authors prefer Discord, and CurseForge comments are rarely checked.

## TOC File Structure

```
## Interface: 20505
## Title: My Addon
## Notes: Description
## Author: Your Name
## Version: 1.0.0

## Dependencies: Blizzard_UIParent
## OptionalDeps: Pawn, AtlasLootClassic

## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB

## DefaultState: enabled
## LoadOnDemand: 0
## AllowLoadGameType: tbc

MyAddon.lua
MyAddon.xml
```

## Critical TBC Classic Anniversary API Gotchas

### 1. Icon Textures: Use Numeric FileDataIDs, NOT String Paths

`GetSpellInfo()` returns numeric FileDataIDs (e.g., `132135`) for icons. These WORK in TBC Classic Anniversary. String paths like `"Interface\\Icons\\Ability_Druid_Mangle2"` do NOT work reliably.

```lua
-- WRONG - string paths often fail in TBC Classic Anniversary
icon:SetTexture("Interface\\Icons\\Ability_Druid_Mangle2")

-- CORRECT - use what GetSpellInfo returns
local _, _, textureID = GetSpellInfo(spellID)
icon:SetTexture(textureID)  -- e.g., 132135
```

### 2. IsUsableSpell() is Unreliable with Ranked Spells

`IsUsableSpell(spellID)` can return `false` even when the spell is usable, especially if checking a lower rank than what the player has learned. Use `IsSpellKnown()` instead for availability checks.

```lua
-- UNRELIABLE - may return false for rank 1 if player has rank 2
local isUsable = IsUsableSpell(33876)  -- Mangle rank 1

-- MORE RELIABLE - check if player knows any rank
local knowsSpell = IsSpellKnown(33876)
```

### 3. Talent Detection via GetTalentInfo() is Fragile

Talent indices vary and are hard to get right. For talent-granted abilities, check if the spell is known instead:

```lua
-- FRAGILE - talent index might be wrong
local _, _, _, _, rank = GetTalentInfo(2, 21)  -- Mangle talent?
local hasMangle = rank > 0

-- MORE RELIABLE - check if player knows the spell
local hasMangle = IsSpellKnown(33876) or PlayerKnowsSpell("Mangle (Cat)")
```

### 4. Spell Names May Include Suffixes

Some spells have form-specific names in the spellbook:
- `"Mangle (Cat)"` / `"Mangle (Bear)"`
- `"Faerie Fire (Feral)"`

Use the exact spellbook name when checking:
```lua
IsUsableSpell("Mangle (Cat)")  -- Not just "Mangle"
```

### 5. GetTalentTabInfo() Returns 5+ Values

```lua
-- WRONG - gets description, not points!
local _, _, pointsSpent = GetTalentTabInfo(i)

-- CORRECT - TBC returns: id, name, description, icon, pointsSpent
local _, _, _, _, pointsSpent = GetTalentTabInfo(i)
```

### 6. UTF-8 Characters Don't Render in WoW's Default Font

WoW's built-in fonts (FRIZQT__.TTF) do **not** support extended Unicode. Characters like `★`, `▸`, `▾`, `●`, `✓` all render as broken squares. Use inline texture escapes or ASCII/color-coded text instead:

```lua
-- BROKEN - shows as square in WoW
local star = "★"
local arrow = "▸"
local check = "✓"

-- CORRECT - inline textures via escape sequences
local star = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1:14|t"  -- raid star
local check = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"            -- green checkmark

-- CORRECT - ASCII/text alternatives
local expandIndicator = "(+5)"   -- instead of ▸ 5
local collapseIndicator = "(-5)" -- instead of ▾ 5
```

The `|T` escape format is `|TTexturePath:height:width|t`. Use `height` alone (e.g., `:14`) to auto-scale width proportionally.

### 7. Not All Retail Textures Exist in Classic TBC

Many texture paths that work on Retail are **missing or empty** in Classic Anniversary. Always verify textures in the actual client:

```lua
-- BROKEN in Classic TBC - texture exists on Retail but not Anniversary
icon:SetTexture("Interface\\COMMON\\Indicator-Gold")  -- empty/invisible

-- WORKS in Classic TBC
icon:SetTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1")  -- raid star
icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")             -- green checkmark
icon:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")              -- checkbox checkmark
```

Also note: `UI-DialogBox-Background` is **semi-transparent**. For a solid-color background, use `ChatFrameBackground` as `bgFile` with `SetBackdropColor(0, 0, 0, 1)` for solid black.

### 8. Combo Points Events Do NOT Exist

`UNIT_COMBO_POINTS` and `PLAYER_COMBO_POINTS` are **not valid events** in the Anniversary client. Registering them causes a Lua error. Combo points fire via `UNIT_POWER_UPDATE` with powerToken `"COMBO_POINTS"`:

```lua
-- WRONG - these events don't exist, causes error
frame:RegisterEvent("UNIT_COMBO_POINTS")
frame:RegisterEvent("PLAYER_COMBO_POINTS")

-- CORRECT - combo points come through UNIT_POWER_UPDATE
frame:RegisterEvent("UNIT_POWER_UPDATE")

function OnEvent(self, event, unit, powerToken)
    if event == "UNIT_POWER_UPDATE" and unit == "player" and powerToken == "COMBO_POINTS" then
        local points = GetComboPoints("player", "target")
        -- update UI
    end
end
```

Verified in `wow-ui-source` (classic_anniversary branch) `Blizzard_CombatText.lua` line 206.

### 9. Blizzard SpellActivationOverlay Glow on Custom Frames

`ActionButton_ShowOverlayGlow()` / `ActionButton_HideOverlayGlow()` don't exist in Anniversary. Build the glow manually using `Interface\SpellActivationOverlay\IconAlert` (spark, inner/outer glow) and `IconAlertAnts` (marching ants via `AnimateTexCoords`). The glow frame should be ~1.4x parent size with Scale/Alpha animation groups. See TellMeWhen's `LibCustomGlow-1.0` or MyDruid's `CreateButtonGlow()` for complete implementations.

### 10. Backdrop XML Deprecated

Must use `BackdropTemplate` and set backdrop in Lua:

```xml
<Frame name="MyFrame" inherits="BackdropTemplate">
```

```lua
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
```

### 11. Mixin Load Order

Lua files defining mixins must load BEFORE XML files that reference them. In TOC:
```
Core/MyMixin.lua
UI/MyFrame.xml   <!-- References MyMixin -->
```

### 12. FontString Placement in XML

Must be in `<Layers><Layer>`, NOT in `<Frames>`:

```xml
<Frame>
    <Layers>
        <Layer level="OVERLAY">
            <FontString parentKey="Text" inherits="GameFontNormal"/>
        </Layer>
    </Layers>
</Frame>
```

### 13. Item Data is Async

`GetItemInfo()` returns nil for uncached items:

```lua
-- WRONG - may return nil
local name = GetItemInfo(itemID)

-- CORRECT - use callback
local item = Item:CreateFromItemID(itemID)
item:ContinueOnItemLoad(function()
    local name = GetItemInfo(itemID)
    -- Now safe to use
end)
```

### 14. FauxScrollFrame Pattern

Classic uses FauxScrollFrame, not modern scroll APIs. See examples in addon code.

### 15. Profession Filtering

Use skill IDs, not localized names:
- 164 = Blacksmithing
- 165 = Leatherworking
- 171 = Alchemy
- 182 = Herbalism
- 186 = Mining
- 197 = Tailoring
- 202 = Engineering
- 333 = Enchanting
- 755 = Jewelcrafting

```lua
local prof1, prof2 = GetProfessions()
local _, _, skillLevel, _, _, _, skillID = GetProfessionInfo(prof1)
```

### 16. C_SpecializationInfo.GetSpecializationInfo() `role` Field is Nil in Classic

The `role` field is nil in Classic Anniversary — Classic talent trees don't have role metadata. Code checking `role == "HEALER"` always fails. Use talent tab mapping (class + primary tree index) as a fallback. `GetTalentTabInfo()` is a deprecated wrapper that **drops the `role` field** — always use `C_SpecializationInfo.GetSpecializationInfo()` with `activeGroup` for dual-spec support.

See `roles-reference.md` for the complete healer detection pattern including inspect queue and talent tab mapping.

### 17. OnUpdate Does NOT Fire on Hidden Frames

`OnUpdate` scripts only fire on **shown** frames. Putting periodic logic on a frame that starts hidden causes a deadlock if showing it depends on that logic completing.

```lua
-- BROKEN - frame starts hidden, OnUpdate never fires
local displayFrame = CreateFrame("Frame", nil, UIParent)
displayFrame:Hide()
displayFrame:SetScript("OnUpdate", function(self, elapsed)
    ProcessInspectQueue()  -- NEVER RUNS!
end)

-- CORRECT - background tasks on a separate always-shown frame
local bgFrame = CreateFrame("Frame")  -- shown by default, no visual
bgFrame:SetScript("OnUpdate", function(self, elapsed)
    ProcessInspectQueue()  -- always runs
end)
```

**Rule of thumb**: `CreateFrame("Frame")` is shown by default. Any frame that might be hidden should NOT host periodic background logic.

### 18. GetInstanceInfo() Instance Names Are Unreliable

The first return of `GetInstanceInfo()` is a localized name that can vary between clients (e.g., "Hellfire Ramparts" vs "Hellfire Citadel: Ramparts"). Use the 8th return value (`instanceID` / map ID) for reliable instance identification:

```lua
-- UNRELIABLE - name varies by locale/client version
local instanceName = GetInstanceInfo()
local entry = INSTANCE_MAP[instanceName]  -- may not match

-- CORRECT - instanceID is stable
local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
local entry = INSTANCE_MAP[instanceID]  -- e.g., [543] = "Hellfire Ramparts"
```

### 19. GetFactionInfo() Only Scans Visible (Expanded) Factions

`GetFactionInfo()` only iterates factions under expanded headers. Factions under collapsed headers are invisible to the scan. To reliably find a faction by ID, expand all collapsed headers first, do your lookup, then re-collapse:

```lua
-- BROKEN - misses factions under collapsed headers
for i = 1, GetNumFactions() do
    local name, _, _, _, _, _, _, _, _, _, _, _, _, factionID = GetFactionInfo(i)
    if factionID == targetID then return i end  -- may never match
end

-- CORRECT - expand all headers, scan, then re-collapse
-- 1. Loop: find collapsed headers, expand them (repeat until none left)
-- 2. Scan all factions for your target
-- 3. Loop: re-collapse headers you expanded
-- See RepSync's FindAndWatchFactionByID() for a complete implementation
```

### 20. Native Blizzard Frame Integration (Tabs, Panels, Hooks)

Adding custom tabs and panels to Blizzard frames requires handling several non-obvious behaviors: `CharacterFrameTabButtonTemplate` active textures bleed 4px upward (don't use `PanelTemplates_SelectTab` for toggle tabs), tab widths return template defaults (10px) before layout, Blizzard's OnShow hacks permanently shift tab positions, and load-on-demand frames require `ADDON_LOADED` + `C_Timer.After(0)` to access safely. Native frame backgrounds use multi-piece textures with sublevel ordering, not backdrops.

See `native-ui-reference.md` for complete patterns: custom tab creation and positioning, PanelTemplates system, native background reproduction, side panel attachment, hooking Blizzard methods, ScrollBox data mutation with filtering, three-state button visuals, and real-time delist cleanup.

### 21. Lua 200 Local Variable Limit Per Chunk

The Lua VM enforces a hard limit of **200 local variables per function scope** (including file scope). Large single-file addons can hit this. The error is: `main function has more than 200 local variables`.

```lua
-- This counts toward the 200 limit:
local foo = 1
local bar = 2
local function Baz() end  -- also counts

-- These do NOT count (they're table fields, not locals):
local SPELLS = {}
SPELLS[123] = { name = "Heal" }  -- table mutation, not a new local
```

**Mitigations when near the limit:**
- Group related constants into tables instead of individual locals (e.g., `local ICONS = { drinking = 132794, innervate = 136048 }` instead of separate locals)
- Use forward declarations sparingly — each `local Foo;` consumes a slot even before assignment
- Don't localize functions that aren't in hot paths (e.g., `C_SpecializationInfo.GetSpecializationInfo` called once every 2.5s doesn't need localizing)

### 22. WoW's sin()/cos() Take Degrees, NOT Radians

WoW's global `sin()` and `cos()` functions take **degrees**, unlike Lua's `math.sin()`/`math.cos()` which take radians. This is a common source of confusion when writing animations.

```lua
-- WoW globals: DEGREES
local alpha = sin(GetTime() * 270)  -- 270°/sec = 360/270 = 1.33s cycle

-- Lua standard library: RADIANS
local alpha = math.sin(GetTime() * 4.71)  -- same 1.33s cycle

-- Common mistake: using radian values with WoW's sin()
local alpha = sin(GetTime() * 4.71)  -- WRONG: 4.71°/sec = 76 second cycle (extremely slow)
```

**Period formula for WoW's sin():** `period = 360 / degrees_per_second`
- 360°/s = 1.0s cycle
- 270°/s = 1.33s cycle
- 180°/s = 2.0s cycle

## Common Patterns

For reusable code patterns (mixins, object pooling, event registration, animations, loot events, item link parsing, screen positioning, drag-to-resize, ScrollBox scroll preservation, slash commands, keybind-via-macrotext, SavedVariables, native Settings API, pre-creating secure buttons for configurable counts, combat log parsing, array compaction, load-on-demand initialization), see `patterns-reference.md`.

For native Blizzard frame integration patterns (custom tabs, panel attachment, background reproduction, ScrollBox filtering, three-state buttons), see `native-ui-reference.md`.

## Debugging

```lua
-- Print
print("Debug:", variable)

-- Dump table
DevTools_Dump(myTable)

-- Stack trace
print(debugstack())

-- In-game commands
/fstack      -- Frame stack under cursor
/eventtrace  -- Event trace
/reload      -- Reload UI
```

### Taint Log

When debugging errors, UI issues, or unexpected behavior, **proactively check the taint log** — don't wait for the user to ask. Taint errors are a common source of silent failures in WoW addons.

```bash
tail -50 "/mnt/data/games/World of Warcraft/_anniversary_/Logs/Taint.log"
```

Filter for specific addon references:
```bash
grep -i "<AddonName>" "/mnt/data/games/World of Warcraft/_anniversary_/Logs/Taint.log" | tail -30
```

The taint log is written during the session and cleared on each client launch. Check it after `/reload` if something looks wrong even without a visible Lua error.

## UI Source Reference

For additional API details, consult the Blizzard UI source:
```
~/git/reference/wow-ui-source/
```
Ensure repo is on the `classic_anniversary` branch.

Reference files in this skill directory:
- `api-reference.md` — Frame functions, Texture/FontString APIs, secure handlers, utility functions
- `roles-reference.md` — Group role detection (tank/healer/dps), role assignment APIs, events
- `native-ui-reference.md` — Custom tabs, panel attachment, native backgrounds, ScrollBox filtering, three-state buttons
- `patterns-reference.md` — Mixins, object pooling, event registration, animations, loot, item links, resize, scroll, slash commands, keybind-via-macrotext, SavedVariables, Settings API, secure button pre-creation
- `ci-reference.md` — GitHub Actions setup, secrets, .pkgmeta, CurseForge deployment, troubleshooting

**Self-maintenance**: When adding new patterns to a reference file or creating a new reference file, update BOTH the list above AND the "Common Patterns" summary earlier in this file so the new content is discoverable. The descriptions here should be concise keyword lists matching section headings in the reference files.

## Data References

| Resource | Location |
|----------|----------|
| WoW UI Source | `~/git/reference/wow-ui-source/` (classic_anniversary branch) |
| wow-classic-items | `~/git/reference/wow-classic-items/data/json/data.json` |
| AzerothCore SQL | `~/git/reference/azerothcore-wotlk/data/sql/base/db_world/` |
| Item generation scripts | `~/git/mine/wowtools/anniversary/` |


## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.
