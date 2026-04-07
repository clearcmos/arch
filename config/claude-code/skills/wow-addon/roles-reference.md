# Group Role Detection - WoW Classic Anniversary

Role detection APIs for TBC Classic Anniversary (2.5.5, build 65340, WOW_PROJECT_ID 5).

## Quick Reference

| Use Case | API | Returns |
|----------|-----|---------|
| Get assigned role (string) | `UnitGroupRolesAssigned(unit)` | `"TANK"`, `"HEALER"`, `"DAMAGER"`, `"NONE"` |
| Get assigned role (enum) | `UnitGroupRolesAssignedEnum(unit)` | `0`=Tank, `1`=Healer, `2`=Damage |
| Get available roles for class | `UnitGetAvailableRoles(unit)` | Three booleans: `tank, healer, dps` |
| Check main tank/assist | `GetPartyAssignment("MAINTANK", unit)` | Boolean |
| Get LFG role selections | `GetLFGRoles()` | Four booleans: `leader, tank, healer, dps` |
| Set role (string) | `UnitSetRole(unit, roleStr)` | Boolean success |
| Set role (enum) | `UnitSetRoleEnum(unit, role)` | Boolean success |
| Get group role counts | `GetGroupMemberCounts()` | Table with `TANK`, `HEALER`, `DAMAGER`, `NOROLE` counts |

## Primary APIs

### UnitGroupRolesAssigned(unit)

The main function for checking a unit's assigned group role.

```lua
local role = UnitGroupRolesAssigned("player")
-- Returns: "TANK", "HEALER", "DAMAGER", or "NONE"

-- Works with any unit token
local partyRole = UnitGroupRolesAssigned("party1")
local raidRole = UnitGroupRolesAssigned("raid5")
```

**Source**: `Blizzard_CompactRaidFrames/Blizzard_CompactRaidFrameContainer.lua`, `Blizzard_FrameXML/SecureGroupHeaders.lua`

### UnitGroupRolesAssignedEnum(unit)

Enum version of the above. Returns numeric constants.

```lua
local roleEnum = UnitGroupRolesAssignedEnum("player")
-- Enum.LFGRole.Tank   = 0
-- Enum.LFGRole.Healer = 1
-- Enum.LFGRole.Damage = 2

if roleEnum == Enum.LFGRole.Tank then
    -- Player is tanking
end
```

**Source**: `Blizzard_APIDocumentationGenerated/UnitDocumentation.lua` (line 354), `Blizzard_FrameXML/Classic/RolePoll.lua` (line 34)

### UnitGetAvailableRoles(unit)

Returns what roles a player CAN fill based on their class/spec. Useful for role poll UI.

```lua
local canTank, canHeal, canDPS = UnitGetAvailableRoles("player")
-- A feral druid: canTank=true, canHeal=false, canDPS=true
-- A holy paladin: canTank=false, canHeal=true, canDPS=false
```

**Source**: `Blizzard_APIDocumentationGenerated/UnitRoleDocumentation.lua` (lines 37-52)

### GetPartyAssignment(assignment, unit, [byName])

Checks raid leader party assignments (main tank / main assist markers).

```lua
-- Check by unit token
if GetPartyAssignment("MAINTANK", "player") then
    -- Player is assigned main tank
end

-- Check by name
if GetPartyAssignment("MAINASSIST", "Playername", true) then
    -- Player is assigned main assist
end

-- Valid assignments: "MAINTANK", "MAINASSIST"
```

**Source**: `Blizzard_FrameXML/SecureGroupHeaders.lua` (lines 305-309)

**Note**: This is separate from the role system. A raid leader can mark someone as main tank via the raid UI regardless of their assigned role. In Classic raids, this is often more commonly used than the role system.

### GetLFGRoles()

Returns the player's currently selected LFG/LFD queue roles.

```lua
local isLeader, isTank, isHealer, isDPS = GetLFGRoles()
```

**Source**: `Blizzard_GroupFinder/Classic/LFGList.lua`, `Blizzard_GroupFinder/Shared/LFGFrame.lua`

### GetGroupMemberCounts()

Returns a table counting group members by role.

```lua
local counts = GetGroupMemberCounts()
-- counts.TANK     = number of tanks
-- counts.HEALER   = number of healers
-- counts.DAMAGER  = number of DPS
-- counts.NOROLE   = number without a role set

-- Wrapper that counts NOROLE as DAMAGER:
local display = GetGroupMemberCountsForDisplay()
```

**Source**: `Blizzard_FrameXMLUtil/PartyUtil.lua` (lines 108-113)

### UnitSetRole / UnitSetRoleEnum

Set a unit's group role. Typically only used during role poll responses.

```lua
UnitSetRole("player", "TANK")        -- string version
UnitSetRoleEnum("player", Enum.LFGRole.Tank)  -- enum version
```

**Source**: `Blizzard_APIDocumentationGenerated/UnitRoleDocumentation.lua`

## Events

### PLAYER_ROLES_ASSIGNED

Fires when group member roles are assigned or changed. No payload - re-query roles after this fires.

```lua
frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")

function frame:OnEvent(event)
    if event == "PLAYER_ROLES_ASSIGNED" then
        local role = UnitGroupRolesAssigned("player")
        -- Update state
    end
end
```

**Source**: `Blizzard_UnitFrame/Shared/CompactUnitFrame.lua` (line 32)

### ROLE_CHANGED_INFORM

Fires when someone's role changes. Provides details about what changed.

```lua
frame:RegisterEvent("ROLE_CHANGED_INFORM")

function frame:OnEvent(event, changedName, fromName, oldRole, newRole)
    -- changedName: player whose role changed
    -- fromName:    who changed it (may be same as changedName)
    -- oldRole:     previous role string
    -- newRole:     new role string
end
```

**Source**: `Blizzard_FrameXML/Classic/RolePoll.lua` (lines 84-107)

### ROLE_POLL_BEGIN

Fires when the group leader initiates a role poll.

```lua
frame:RegisterEvent("ROLE_POLL_BEGIN")

function frame:OnEvent(event, fromName)
    -- fromName: who initiated the poll
end
```

### Other LFG Role Events

- `LFG_ROLE_UPDATE` - LFG role selection changed
- `LFG_ROLE_CHECK_SHOW` / `LFG_ROLE_CHECK_HIDE` - Role check UI display
- `LFG_ROLE_CHECK_ROLE_CHOSEN` - Player selected role in a role check
- `LFG_LIST_ROLE_UPDATE` - LFG listing role update

## Constants

```lua
-- Enum values (for UnitGroupRolesAssignedEnum / UnitSetRoleEnum)
Enum.LFGRole.Tank   = 0
Enum.LFGRole.Healer = 1
Enum.LFGRole.Damage = 2

-- Internal constants
Constants.LFG_ROLEConstants.LFG_ROLE_NO_ROLE = -1
Constants.LFG_ROLEConstants.LFG_ROLE_ANY     = 3  -- num values
```

**Source**: `Blizzard_APIDocumentationGenerated/LFGConstantsDocumentation.lua`

## Important Caveats

### 1. Roles are NOT automatic

Roles are only set when:
- A **role poll** is initiated by the group/raid leader
- Players **manually set** their role via the group UI
- The player queued via **LFG/LFD** (roles assigned from queue selection)

In manually-formed groups (invite via `/invite`, trade chat pugs, guild runs without a role poll), **everyone returns `"NONE"`**. This is the most common scenario in Classic Anniversary.

### 2. "NONE" is the default

Most Classic players never set a role. Do NOT assume `"NONE"` means DPS. It means "unset". Always handle `"NONE"` as a valid state:

```lua
local role = UnitGroupRolesAssigned("player")
if role == "NONE" then
    -- Role not assigned - cannot determine tank/healer/dps
    -- Fall back to class/spec detection or other heuristics
end
```

### 3. GetPartyAssignment is more reliable for tanks in raids

In Classic raids, raid leaders commonly use the **main tank / main assist** system rather than role polls. Check `GetPartyAssignment("MAINTANK", unit)` as a supplementary tank detection method:

```lua
local function IsPlayerTank()
    local role = UnitGroupRolesAssigned("player")
    if role == "TANK" then return true end
    if GetPartyAssignment("MAINTANK", "player") then return true end
    return false
end
```

### 4. Role detection fallback strategies

Since roles are often unset, addons typically fall back to heuristic detection:

```lua
-- Example: detect if player is likely tanking
local function IsLikelyTanking()
    -- Check assigned role first
    local role = UnitGroupRolesAssigned("player")
    if role == "TANK" then return true end
    if role == "HEALER" or role == "DAMAGER" then return false end

    -- Check main tank assignment
    if GetPartyAssignment("MAINTANK", "player") then return true end

    -- Heuristic: check stance/form/aura
    -- Warriors: Defensive Stance (spell ID 71)
    -- Druids: Bear Form (spell ID 5487) or Dire Bear Form (9634)
    -- Paladins: Righteous Fury buff (25780)
    local _, class = UnitClass("player")
    if class == "WARRIOR" then
        local stance = GetShapeshiftForm()
        return stance == 2  -- Defensive Stance
    elseif class == "DRUID" then
        local stance = GetShapeshiftForm()
        return stance == 1  -- Bear Form
    elseif class == "PALADIN" then
        -- Check for Righteous Fury buff
        for i = 1, 40 do
            local name = UnitBuff("player", i)
            if not name then break end
            if name == "Righteous Fury" then return true end
        end
    end

    return false
end
```

### 5. UnitGetAvailableRoles is class-based, not spec-based

`UnitGetAvailableRoles` returns what the class CAN do, not what the current spec/gear is built for. A feral druid returns `canTank=true, canDPS=true` regardless of whether they're in cat or bear gear. Don't use this for current-role detection.

### 6. Enum.LFGRole may not exist

In some Classic Anniversary client versions, `Enum.LFGRole` may not be populated. Always nil-check or use the string API (`UnitGroupRolesAssigned`) as the safer option:

```lua
-- Safe enum usage
local ROLE_TANK = Enum and Enum.LFGRole and Enum.LFGRole.Tank or 0
```

## Talent-Based Healer Detection (Inspect Pattern)

Since roles are almost never assigned in Classic (see caveat #1), the reliable way to detect healers is by **inspecting talent trees** via `C_SpecializationInfo`. This requires an async inspect workflow.

### Healing Talent Tabs by Class (TBC)

```lua
-- Tab index → healing spec mapping
local HEALING_TALENT_TABS = {
    ["PRIEST"]  = { [1] = true, [2] = true },  -- Discipline (1), Holy (2)
    ["DRUID"]   = { [3] = true },               -- Restoration (3)
    ["PALADIN"] = { [1] = true },               -- Holy (1)
    ["SHAMAN"]  = { [3] = true },               -- Restoration (3)
}

-- Only these classes can heal
local HEALER_CAPABLE_CLASSES = {
    ["PRIEST"] = true, ["DRUID"] = true,
    ["PALADIN"] = true, ["SHAMAN"] = true,
}
```

### Layered Detection Approach

Best practice is a three-layer approach, from fastest to slowest:

1. **`UnitGroupRolesAssigned(unit)`** — if role is explicitly assigned, trust it immediately
2. **Class filter** — non-healer classes (warrior, rogue, etc.) can be ruled out instantly
3. **Talent inspection** — for healer-capable classes with unknown role, inspect their talent trees

### Complete Healer Detection Pattern

```lua
-- State
local healerData = {}          -- [guid] = { unit, name, classFile, isHealer, ... }
local inspectQueue = {}        -- { { unit, guid }, ... }
local inspectPending = nil     -- guid of player currently being inspected
local lastInspectTime = 0
local INSPECT_COOLDOWN = 2.5   -- seconds between inspect requests

-- Determine healer status from talent inspection
-- isInspect: true for other players (after INSPECT_READY), false for self
local function DetermineHealerFromTalents(classFile, isInspect)
    local activeGroup = 1
    if C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
        local ok, result = pcall(C_SpecializationInfo.GetActiveSpecGroup, isInspect, false)
        if ok and result then activeGroup = result end
    end

    local maxPoints, primaryTab, primaryRole = 0, nil, nil
    for i = 1, 3 do
        local ok, _, _, _, _, role, _, pointsSpent =
            pcall(C_SpecializationInfo.GetSpecializationInfo, i, isInspect, false, nil, nil, activeGroup)
        if ok and pointsSpent and pointsSpent > maxPoints then
            maxPoints = pointsSpent
            primaryTab = i
            primaryRole = role
        end
    end

    if maxPoints > 0 and primaryTab then
        if primaryRole == "HEALER" then return true end
        if primaryRole then return false end
        -- role is nil in Classic; fall back to talent tab mapping
        local healTabs = HEALING_TALENT_TABS[classFile]
        return (healTabs and healTabs[primaryTab]) or false
    end
    return nil  -- couldn't determine (API failure)
end

-- Self-check (no inspection needed)
local function CheckSelfSpec()
    local guid = UnitGUID("player")
    local data = healerData[guid]
    if not data then return end

    local isCapable, classFile = IsHealerCapableClass("player")
    if not isCapable then data.isHealer = false; return end

    local result = DetermineHealerFromTalents(classFile, false)
    data.isHealer = (result ~= nil) and result or (GetNumGroupMembers() <= 5)
end

-- Process INSPECT_READY for other players
local function ProcessInspectResult(inspecteeGUID)
    if inspectPending ~= inspecteeGUID then return end
    local data = healerData[inspecteeGUID]
    if not data or not data.unit then
        ClearInspectPlayer(); inspectPending = nil; return
    end

    local _, classFile = UnitClass(data.unit)
    if classFile then
        local result = DetermineHealerFromTalents(classFile, true)
        if result ~= nil then
            data.isHealer = result
        elseif GetNumGroupMembers() <= 5 then
            data.isHealer = true  -- assume healer in 5-man
        end
        -- In raids with API failure, leave nil to retry
    end

    ClearInspectPlayer()
    inspectPending = nil
end

-- Queue and process inspections
local function ProcessInspectQueue()
    if inspectPending or #inspectQueue == 0 then return end
    if GetTime() - lastInspectTime < INSPECT_COOLDOWN then return end

    while #inspectQueue > 0 do
        local entry = table.remove(inspectQueue, 1)
        if UnitExists(entry.unit) and UnitGUID(entry.unit) == entry.guid then
            local ok, canDo = pcall(CanInspect, entry.unit)
            if ok and canDo then
                NotifyInspect(entry.unit)
                inspectPending = entry.guid
                lastInspectTime = GetTime()
                return
            end
        end
    end
end
```

### Key Implementation Notes

1. **`activeGroup` parameter is required** — always call `GetActiveSpecGroup(isInspect, false)` and pass the result to `GetSpecializationInfo()`. Without it, you may get data for the wrong dual-spec group or no data at all.

2. **`role` field is nil in Classic Anniversary** — `C_SpecializationInfo.GetSpecializationInfo()` returns valid `pointsSpent` but the `role` field ("HEALER"/"TANK"/"DAMAGER") is nil. You MUST fall back to the `HEALING_TALENT_TABS` mapping. Check `role` first in case future client updates populate it.

3. **`GetTalentTabInfo()` is a deprecated wrapper** — it calls `GetSpecializationInfo()` internally but drops the `role` and `primaryStat` return values. Use `C_SpecializationInfo.GetSpecializationInfo()` directly.

4. **Pause inspections during combat** — `NotifyInspect()` can fail or cause issues in combat. Set a flag on `PLAYER_REGEN_DISABLED` and clear on `PLAYER_REGEN_ENABLED`.

5. **Re-queue unresolved members** — if inspection fails (out of range, API error), the member stays `isHealer == nil`. Periodically re-queue nil members for retry.

6. **5-man fallback** — if talent detection completely fails in a 5-man group, it's safe to assume healer-capable classes are healers (there's usually exactly one). In raids, leave as nil and retry to avoid showing all priests/druids/paladins/shamans.

7. **OnUpdate must be on a visible frame** — inspection queue processing and periodic checks must NOT be on a display frame that starts hidden. Use a separate `CreateFrame("Frame")` (shown by default) for background timers. See SKILL.md gotcha #17.
