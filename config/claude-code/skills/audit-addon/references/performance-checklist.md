# Performance Checklist

Detailed performance audit items derived from vscode-wow-api annotations and WoW Lua best practices for TBC Classic Anniversary.

## 1. Localize Hot-Path API Functions

Any `C_*` namespaced function called in a loop, event handler, or frequently-triggered hook should be localized at file scope.

```lua
-- BAD: Global lookup on every call
for _, id in ipairs(results) do
    local info = C_LFGList.GetSearchResultInfo(id)
end

-- GOOD: Localized at file scope
local GetSearchResultInfo = C_LFGList.GetSearchResultInfo
-- ...
for _, id in ipairs(results) do
    local info = GetSearchResultInfo(id)
end
```

**Common candidates:**
- `C_LFGList.*` — search result functions
- `C_Timer.After` / `C_Timer.NewTicker`
- `C_Spell.GetSpellInfo` or `GetSpellInfo`
- `C_Item.GetItemInfo` or `GetItemInfo`
- `C_Container.*` — bag functions
- `C_ChatInfo.*` — chat functions
- Any `C_*` function called more than once in the same code path

**Already localized by WoW** (do NOT flag):
- `wipe`, `tinsert`, `tremove`, `sort` (table aliases)
- `format`, `strbyte`, `strchar`, `strfind`, `gmatch`, `gsub`, `strlen`, `strlower`, `strmatch`, `strrep`, `strrev`, `strsub`, `strupper`, `strtrim`, `strsplit`, `strjoin` (string aliases)
- `abs`, `ceil`, `cos`, `floor`, `max`, `min`, `mod`, `random`, `sin`, `sqrt`, `tan`, `PI` (math aliases)
- `pairs`, `ipairs`, `next`, `type`, `tostring`, `tonumber`, `select`, `unpack`, `error`, `pcall`, `xpcall` (Lua builtins — already fast as globals)

## 2. Table Operations

### table.remove in loops — O(n^2)

```lua
-- BAD: O(n^2) — each remove shifts all subsequent elements
for i = #t, 1, -1 do
    if shouldRemove(t[i]) then
        table.remove(t, i)
    end
end

-- GOOD: O(n) — in-place compaction with write pointer
local j = 1
for i = 1, #t do
    if not shouldRemove(t[i]) then
        t[j] = t[i]
        j = j + 1
    end
end
for i = j, #t do t[i] = nil end

-- GOOD: O(1) per removal when order doesn't matter
-- tUnorderedRemove swaps with last element
for i = #t, 1, -1 do
    if shouldRemove(t[i]) then
        tUnorderedRemove(t, i)
    end
end
```

### Table reuse with wipe()

```lua
-- BAD: Creates new table, old one becomes garbage
myData = {}

-- GOOD: Reuses existing allocation, no GC pressure
wipe(myData)
```

### Constant tables inside functions

```lua
-- BAD: Allocates identical table on every call
local function GetRoleAtlas(role)
    local ATLAS = {
        TANK = "groupfinder-icon-role-large-tank",
        HEALER = "groupfinder-icon-role-large-heal",
        DPS = "groupfinder-icon-role-large-dps",
    }
    return ATLAS[role]
end

-- GOOD: Allocated once at file scope
local ROLE_ATLAS = {
    TANK = "groupfinder-icon-role-large-tank",
    HEALER = "groupfinder-icon-role-large-heal",
    DPS = "groupfinder-icon-role-large-dps",
}
local function GetRoleAtlas(role)
    return ROLE_ATLAS[role]
end
```

## 3. Frame and Texture Creation

**Never create frames/textures in hot paths.** These allocate C++ objects that are expensive and never garbage-collected.

```lua
-- BAD: Creates new texture every update
frame:SetScript("OnUpdate", function(self)
    local icon = self:CreateTexture()  -- LEAKED!
    icon:SetTexture(textureID)
end)

-- GOOD: Create once, reuse
local icon = frame:CreateTexture(nil, "ARTWORK")
frame:SetScript("OnUpdate", function(self)
    icon:SetTexture(textureID)
end)
```

**SetAtlas vs SetTexture:**
- `SetAtlas` uses texture atlases (fewer draw calls, better batching)
- `SetTexture` with numeric FileDataID is faster than string path
- String paths like `"Interface\\Icons\\..."` require filesystem lookup

## 4. Event Handling

### Use RegisterUnitEvent for unit-specific events

```lua
-- BAD: Fires for ALL units
frame:RegisterEvent("UNIT_AURA")

-- GOOD: Fires only for specified units
frame:RegisterUnitEvent("UNIT_AURA", "player", "target")
```

### OnUpdate on hidden frames does nothing

`OnUpdate` only fires on shown frames. Background tasks must use a separate always-visible frame.

```lua
-- BAD: OnUpdate never fires if frame starts hidden
local display = CreateFrame("Frame", nil, UIParent)
display:Hide()
display:SetScript("OnUpdate", ProcessQueue)  -- NEVER RUNS

-- GOOD: Separate background frame
local bg = CreateFrame("Frame")  -- shown by default
bg:SetScript("OnUpdate", ProcessQueue)
```

### Unregister events when not needed

```lua
-- If you only need PLAYER_ENTERING_WORLD once:
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        Initialize()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)
```

## 5. Redundant API Calls

### Cache results within a code path

```lua
-- BAD: Calls GetSearchResultInfo 3 times for the same ID
local info1 = C_LFGList.GetSearchResultInfo(id)
local numMembers = info1.numMembers
-- ... later in same function ...
local info2 = C_LFGList.GetSearchResultInfo(id)  -- redundant!
local comment = info2.comment

-- GOOD: Call once, reuse
local info = GetSearchResultInfo(id)
local numMembers = info.numMembers
local comment = info.comment
```

### Single-pass processing

```lua
-- BAD: Two passes over the same data
for _, id in ipairs(results) do
    if ShouldShow(id) then  -- calls GetSearchResultInfo internally
        filtered[#filtered + 1] = id
    end
end
for _, id in ipairs(filtered) do
    local info = GetSearchResultInfo(id)  -- called again!
    cache[id] = info.numMembers
end

-- GOOD: Single pass
for _, id in ipairs(results) do
    local info = GetSearchResultInfo(id)
    if ShouldShow(id, info) then  -- pass cached info
        filtered[#filtered + 1] = id
        cache[id] = info.numMembers
    end
end
```

## 6. Profiling Tools Available

Use these to measure actual impact:

```lua
-- Simple timing
debugprofilestart()
MyExpensiveFunction()
local elapsed = debugprofilestop()
print(format("Took %.3f ms", elapsed))

-- Detailed measurement (memory + time)
local result = C_AddOnProfiler.MeasureCall(MyExpensiveFunction, arg1, arg2)
print(format("Time: %.3f ms, Alloc: %d bytes", result.elapsedMilliseconds, result.allocatedBytes))

-- Check addon impact
local metric = C_AddOnProfiler.GetAddOnMetric("MyAddon", Enum.AddOnProfilerMetric.RecentAverageTime)
```
