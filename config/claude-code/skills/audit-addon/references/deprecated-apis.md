# Deprecated and Problematic APIs

APIs and patterns that are deprecated, removed, or problematic in TBC Classic Anniversary (Interface 20505). Derived from vscode-wow-api annotations and WoW UI source.

## Deprecated Global Functions

| Deprecated | Replacement | Notes |
|-----------|-------------|-------|
| `getglobal("name")` | `_G["name"]` | Removed wrapper, direct table access is faster |
| `setglobal("name", val)` | `_G["name"] = val` | Same — direct assignment |
| `this` | `self` | Lua 5.0 implicit local; use explicit `self` parameter |
| `arg` (implicit) | `...` (varargs) | Lua 5.0 pattern; use `select()` or `...` |
| `math.mod(a, b)` | `a % b` or `mod(a, b)` | `mod()` is a WoW global alias for `%` |
| `string.gfind` | `string.gmatch` | Renamed in Lua 5.1 |
| `table.getn(t)` | `#t` | Length operator replaces this |
| `table.foreach` | `for k, v in pairs(t)` | Removed in later Lua; use iterators |
| `table.foreachi` | `for i, v in ipairs(t)` | Same |

## Backdrop API

The old `SetBackdrop` method requires `BackdropTemplate` inheritance in TBC Classic Anniversary:

```lua
-- DEPRECATED: SetBackdrop without template
local frame = CreateFrame("Frame")
frame:SetBackdrop({...})  -- may fail or behave unexpectedly

-- CORRECT: Inherit BackdropTemplate
local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
```

## Texture Paths vs FileDataIDs

String texture paths require filesystem lookups. Numeric FileDataIDs are direct references.

```lua
-- SLOWER: String path lookup
icon:SetTexture("Interface\\Icons\\Ability_Druid_Mangle2")

-- FASTER: Numeric FileDataID (from GetSpellInfo, GetItemInfo, etc.)
local _, _, textureID = GetSpellInfo(spellID)
icon:SetTexture(textureID)  -- e.g., 132135
```

**Important for TBC Classic Anniversary:** `GetSpellInfo()` returns numeric FileDataIDs. String icon paths are unreliable in this client and may not resolve correctly.

## Events That Don't Exist

These events do NOT exist in TBC Classic Anniversary and will cause Lua errors if registered:

| Non-existent Event | Correct Alternative |
|-------------------|-------------------|
| `UNIT_COMBO_POINTS` | `UNIT_POWER_UPDATE` with `powerToken == "COMBO_POINTS"` |
| `PLAYER_COMBO_POINTS` | Same as above |

## Problematic Patterns

### Using OnUpdate for One-Shot Delays

```lua
-- BAD: Manual OnUpdate timer
local elapsed = 0
frame:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed > 1 then
        DoThing()
        self:SetScript("OnUpdate", nil)
    end
end)

-- GOOD: C_Timer handles this cleanly
C_Timer.After(1, DoThing)
```

### Polling Instead of Event-Driven

```lua
-- BAD: Checking every frame
frame:SetScript("OnUpdate", function()
    if UnitHealth("player") < threshold then
        ShowWarning()
    end
end)

-- GOOD: React to health changes
frame:RegisterUnitEvent("UNIT_HEALTH", "player")
frame:SetScript("OnEvent", function(self, event, unit)
    if UnitHealth("player") < threshold then
        ShowWarning()
    end
end)
```

### String Concatenation in Loops

```lua
-- BAD: Creates intermediate strings (O(n^2) memory)
local result = ""
for i = 1, #items do
    result = result .. items[i] .. ", "
end

-- GOOD: Use table.concat
local parts = {}
for i = 1, #items do
    parts[i] = items[i]
end
local result = table.concat(parts, ", ")
```

### Unthrottled Event Handlers

Events like `UNIT_AURA`, `COMBAT_LOG_EVENT_UNFILTERED`, and `BAG_UPDATE` can fire many times per second. Throttle expensive work:

```lua
-- BAD: Full recalculation on every aura change
frame:RegisterUnitEvent("UNIT_AURA", "player")
frame:SetScript("OnEvent", function()
    ExpensiveFullRecalc()  -- fires 10+ times per second in combat
end)

-- GOOD: Defer with C_Timer (coalesce rapid fires)
local pending = false
frame:RegisterUnitEvent("UNIT_AURA", "player")
frame:SetScript("OnEvent", function()
    if not pending then
        pending = true
        C_Timer.After(0, function()
            pending = false
            ExpensiveFullRecalc()
        end)
    end
end)
```

## Font and Text Rendering

### UTF-8 Characters Don't Render

WoW's built-in fonts (FRIZQT__.TTF) do not support extended Unicode. Characters like `★`, `▸`, `▾`, `●`, `✓` render as broken squares.

```lua
-- BROKEN
local check = "✓"

-- CORRECT: Use inline texture escapes
local check = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
```
