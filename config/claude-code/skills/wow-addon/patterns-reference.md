# Common WoW Addon Patterns

Reusable code patterns for WoW Classic Anniversary addon development.

## Mixin Definition

```lua
MyFrameMixin = CreateFromMixins(CallbackRegistryMixin)

MyFrameMixin:GenerateCallbackEvents({
    "OnDataUpdated",
    "OnSelectionChanged",
})

function MyFrameMixin:OnLoad()
    CallbackRegistryMixin.OnLoad(self)
    self:RegisterEvent("PLAYER_LOGIN")
end

function MyFrameMixin:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        self:Initialize()
    end
end
```

## Object Pooling

```lua
local pool = CreateObjectPool(
    function(pool)  -- Creator
        return CreateFrame("Frame", nil, parent, "MyTemplate")
    end,
    function(pool, frame)  -- Resetter
        frame:Hide()
        frame:ClearAllPoints()
    end
)

local frame, isNew = pool:Acquire()
pool:Release(frame)
pool:ReleaseAll()
```

## Event Registration

```lua
function MyMixin:OnLoad()
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("PLAYER_LOGOUT")
end

-- Bulk registration
FrameUtil.RegisterFrameForEvents(frame, {
    "PLAYER_LOGIN",
    "PLAYER_LOGOUT",
})

-- Unit-specific events
FrameUtil.RegisterFrameForUnitEvents(frame, {"UNIT_HEALTH"}, "player")
```

## OnUpdate Animation (No XML AnimationGroups)

```lua
local activeFrames = {}

local function OnUpdate(self, elapsed)
    for i = #activeFrames, 1, -1 do
        local frame = activeFrames[i]
        frame.elapsed = frame.elapsed + elapsed

        if frame.elapsed >= frame.duration then
            frame:Hide()
            table.remove(activeFrames, i)
        else
            local progress = frame.elapsed / frame.duration
            frame:SetAlpha(1 - progress)
            -- Update position, etc.
        end
    end
end

parentFrame:SetScript("OnUpdate", OnUpdate)
```

## Loot Events

```lua
-- Chat-based (fires when loot message appears)
"CHAT_MSG_LOOT"     -- args: message, playerName, ...

-- Loot frame events
"LOOT_OPENED"       -- Loot window opens (arg: autoLoot bool)
"LOOT_READY"        -- Loot ready for looting
"LOOT_SLOT_CLEARED" -- Item looted (arg: slot index)
"LOOT_CLOSED"       -- Loot window closed

-- Get slot info
local texture, item, quantity, currencyID, quality, locked = GetLootSlotInfo(slot)
```

## Item Link Parsing

```lua
-- Extract link from chat message
local itemLink = strmatch(message, "(|c%x+|Hitem:[^|]+|h%[[^%]]+%]|h|r)")
local quantity = tonumber(strmatch(message, "|rx(%d+)")) or 1

-- Get info from link
local name, _, quality, ilvl, reqLevel, class, subclass, maxStack,
      equipSlot, texture, vendorPrice = GetItemInfo(itemLink)

-- Quality color
local r, g, b = GetItemQualityColor(quality)
```

## Screen-Relative Positioning

```lua
local function GetScaledScreenCenter()
    local scale = UIParent:GetEffectiveScale()
    return (GetScreenWidth() * scale) / 2, (GetScreenHeight() * scale) / 2
end

frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX + offsetX, centerY + offsetY)
```

## Drag-to-Resize via SetScale (Uniform Scaling)

Use `SetScale()` for uniform scaling of an entire frame and all its children. A corner grip button drives an OnUpdate that calculates a scale ratio from cursor movement in screen-pixel space. This avoids recalculating individual element sizes — text, icons, and spacing all scale proportionally.

```lua
local grip = CreateFrame("Button", nil, myFrame)
grip:SetSize(16, 16)
grip:SetPoint("BOTTOMRIGHT", -2, 2)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

grip:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    self.startX, self.startY = GetCursorPosition()
    self.startScale = myFrame:GetScale()
    -- Frame dimensions in screen pixels (standardized coordinates)
    self.stdWidth = myFrame:GetWidth() * myFrame:GetEffectiveScale()
    self.stdHeight = myFrame:GetHeight() * myFrame:GetEffectiveScale()
    self:SetScript("OnUpdate", function(self)
        local curX, curY = GetCursorPosition()
        local ratioX = (self.stdWidth + (curX - self.startX)) / self.stdWidth
        local ratioY = (self.stdHeight + (self.startY - curY)) / self.stdHeight
        local ratio = math.max(ratioX, ratioY)  -- uniform scale using larger axis
        local newScale = math.max(0.5, math.min(2.0, self.startScale * ratio))
        myFrame:SetScale(newScale)
    end)
end)
grip:SetScript("OnMouseUp", function(self)
    self:SetScript("OnUpdate", nil)
end)
```

Key details:
- `GetCursorPosition()` returns raw screen pixels; multiply frame dimensions by `GetEffectiveScale()` to get comparable "standardized" coordinates
- Use `math.max(ratioX, ratioY)` for intuitive drag in any direction
- Frames anchored via TOPLEFT scale downward/rightward naturally
- Clamp scale to reasonable bounds (0.5x-2.0x)
- For TellMeWhen's more advanced implementation (per-axis mode, right-click for rows/columns), see `TellMeWhen/Components/Core/Resizer_Generic/`

## ScrollBox Scroll Position Preservation

The LFG Browse frame (and other modern Classic Anniversary frames) uses ScrollBox, not FauxScrollFrame. When modifying the data provider (filtering results, removing entries), save and restore scroll percentage to prevent the scroll jumping:

```lua
local function SaveScroll()
    local sb = myScrollBox  -- e.g., LFGBrowseFrame.ScrollBox
    if sb and sb.GetScrollPercentage then
        return sb:GetScrollPercentage()
    end
    return nil
end

local function RestoreScroll(pct)
    if pct then
        local sb = myScrollBox
        if sb and sb.SetScrollPercentage then
            sb:SetScrollPercentage(pct)
        end
    end
end

-- Usage around data modifications:
local pct = SaveScroll()
ModifyDataProvider()      -- filter, remove, etc.
frame:UpdateResults()     -- re-renders the ScrollBox
RestoreScroll(pct)
```

Note: Blizzard's `UpdateResults()` already passes `ScrollBoxConstants.RetainScrollPosition` to `SetDataProvider`, but when hooks cause double `UpdateResults()` calls or significant list length changes, explicit save/restore is more reliable.

## Slash Command Registration

Register slash commands using the global `SLASH_*` variables and `SlashCmdList` table. The uppercase token (e.g., `"MYADDON"`) must match between them.

```lua
SLASH_MYADDON1 = "/myaddon"
SLASH_MYADDON2 = "/ma"  -- optional alias

SlashCmdList["MYADDON"] = function(msg)
    msg = msg and msg:lower():trim() or ""

    if msg == "test" then
        TogglePreview()
    elseif msg == "lock" then
        db.locked = not db.locked
        print("Locked:", db.locked)
    elseif msg == "" then
        OpenSettings()
    else
        print("Usage: /myaddon [test|lock]")
    end
end
```

Key details:
- `SLASH_TOKEN1`, `SLASH_TOKEN2`, etc. define aliases (numbering starts at 1)
- The function receives everything after the command as `msg` (e.g., `/ma test` passes `"test"`)
- These are global assignments — define them at file scope, not inside a function
- Trim and lowercase `msg` before comparing to handle whitespace and case

**Keybind-via-macrotext gotcha**: If you bind a key to a SecureActionButton with `type="macro"` and `macrotext="/myaddon"`, the keybind fires whatever the bare slash command does. If you later change the default (e.g., from toggling UI to opening config), the keybind silently breaks. Always use a dedicated subcommand for macrotext:

```lua
-- Toggle button bound to a key
toggleButton:SetAttribute("type", "macro")
toggleButton:SetAttribute("macrotext", "/myaddon run")  -- dedicated subcommand

-- Slash handler keeps default and keybind behavior separate
SlashCmdList["MYADDON"] = function(msg)
    msg = msg and msg:lower():trim() or ""
    if msg == "config" or msg == "options" then
        OpenSettings()
    elseif msg == "help" then
        PrintHelp()
    else  -- "" (bare /myaddon) and "run" (keybind) both toggle
        ToggleUI()
    end
end
```

This way the default `/myaddon` behavior can evolve independently without breaking the keybind.

## SavedVariables Initialization and Migration

Declare saved variables in the TOC file, then initialize with defaults on `ADDON_LOADED`. The WoW client creates the global variable from `## SavedVariables:` before firing the event.

```lua
-- TOC file:
-- ## SavedVariables: MyAddonDB

local DEFAULT_SETTINGS = {
    enabled = true,
    fontSize = 12,
    scale = 1.0,
    showFeatureX = true,
}

local db  -- local reference for performance

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= addonName then return end

        -- Create table if first run
        if not MyAddonDB then
            MyAddonDB = {}
        end

        -- Copy defaults for any missing keys (new settings auto-populate)
        for key, value in pairs(DEFAULT_SETTINGS) do
            if MyAddonDB[key] == nil then
                MyAddonDB[key] = value
            end
        end

        db = MyAddonDB

        -- Clean up removed settings (nil them out)
        db.oldRemovedSetting = nil
        db.anotherOldSetting = nil

        -- Migrate renamed/restructured settings
        if db.oldBoolFlag ~= nil then
            if db.oldBoolFlag then
                db.newEnumSetting = "enabled"
            else
                db.newEnumSetting = "disabled"
            end
            db.oldBoolFlag = nil  -- remove old key
        end

        self:UnregisterEvent("ADDON_LOADED")
    end
end
```

Key details:
- Use `== nil` (not `not`) when copying defaults — preserves `false` values
- Always nil out removed settings so they don't persist in saved variables forever
- Migration should be idempotent — check if the old key exists before migrating, then delete it
- Assign to a local `db` reference for performance (avoids global lookup on every access)
- For per-character storage, use `## SavedVariablesPerCharacter:` in the TOC

## Native Settings API (Options Panel)

Use the built-in Settings API to create an options panel in the AddOns tab (ESC > Options > AddOns). This avoids InterfaceOptions (deprecated) and AceConfig dependencies.

```lua
local function RegisterSettings()
    local category, layout = Settings.RegisterVerticalLayoutCategory("My Addon")

    -- Helper: boolean checkbox
    local function AddCheckbox(key, name, tooltip, onChange)
        local setting = Settings.RegisterProxySetting(category,
            "MYADDON_" .. key:upper(),   -- unique variable ID
            Settings.VarType.Boolean,     -- type
            name,                         -- display name
            DEFAULT_SETTINGS[key],        -- default value
            function() return db[key] end,          -- getter
            function(value)                         -- setter
                db[key] = value
                if onChange then onChange(value) end
            end)
        return Settings.CreateCheckbox(category, setting, tooltip)
    end

    -- Helper: numeric slider
    local function AddSlider(key, name, tooltip, minVal, maxVal, step, onChange)
        local setting = Settings.RegisterProxySetting(category,
            "MYADDON_" .. key:upper(),
            Settings.VarType.Number, name,
            DEFAULT_SETTINGS[key],
            function() return db[key] end,
            function(value)
                db[key] = value
                if onChange then onChange(value) end
            end)
        local options = Settings.CreateSliderOptions(minVal, maxVal, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        return Settings.CreateSlider(category, setting, options, tooltip)
    end

    -- Checkboxes
    AddCheckbox("enabled", "Enable Addon", "Toggle the addon on/off.")
    AddCheckbox("showFeatureX", "Show Feature X", "Display feature X.", RefreshDisplay)

    -- Slider
    AddSlider("fontSize", "Font Size", "Adjust the display font size.", 8, 24, 1, RefreshDisplay)

    -- Dropdown
    local sortSetting = Settings.RegisterProxySetting(category,
        "MYADDON_SORT_BY", Settings.VarType.Number, "Sort By",
        1,  -- default
        function() return SORT_REVERSE[db.sortBy] or 1 end,
        function(value) db.sortBy = SORT_MAP[value] or "name" end)
    local function GetSortOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(1, "Name (A-Z)")
        container:Add(2, "Value (Low-High)")
        return container:GetData()
    end
    Settings.CreateDropdown(category, sortSetting, GetSortOptions, "How to sort entries.")

    -- Register the category (makes it visible in Options)
    Settings.RegisterAddOnCategory(category)

    -- Save category ID for opening programmatically
    myCategoryID = category:GetID()
end

-- Open to this addon's settings page
Settings.OpenToCategory(myCategoryID)
```

Key details:
- Call `RegisterSettings()` inside your `ADDON_LOADED` handler (after `db` is set)
- `RegisterProxySetting` makes the Settings system use your `db` table as the backing store — it never touches `SavedVariables` directly
- The variable ID string (e.g., `"MYADDON_FONT_SIZE"`) must be globally unique across all addons
- Dropdowns map numeric values (1, 2, 3) to your internal strings via lookup tables
- `Settings.OpenToCategory(categoryID)` opens directly to your panel — use this in slash commands
- Section headers can be added with `layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Section Name"))`

## Pre-Creating Secure Buttons for Configurable Counts

SecureActionButtons cannot be created during combat lockdown, so if you want a user-configurable number of result slots (e.g., a "max results" slider), pre-create the maximum number of buttons at init time. Use the config value only for limiting search results and controlling visibility — display loops should iterate all pre-created buttons to properly hide unused ones.

```lua
local MAX_BUTTONS = 12  -- hard ceiling, pre-created once
local resultButtons = {}

-- Create all buttons at init (outside combat)
for i = 1, MAX_BUTTONS do
    local btn = CreateFrame("Button", "MyResult" .. i, parent, "SecureActionButtonTemplate")
    resultButtons[i] = btn
end

-- Search limits results to user's configured max
local function Search(query)
    local maxResults = db.maxResults or 8  -- user setting (4-12)
    local results = {}
    for _, entry in ipairs(candidates) do
        if #results < maxResults then
            table.insert(results, entry)
        end
    end
    return results
end

-- Display loop iterates ALL pre-created buttons
function UpdateResults()
    for i = 1, MAX_BUTTONS do
        local btn = resultButtons[i]
        local entry = currentResults[i]
        if entry then
            -- configure and show button
            btn:Show()
        else
            -- clear attributes and hide
            btn:Hide()
        end
    end
end
```

Key details:
- Navigation (Up/Down) should clamp to `#currentResults`, not `MAX_BUTTONS` — this naturally respects the user's configured limit since `Search()` already limits the result count
- The slider range (e.g., 4-12) should never exceed `MAX_BUTTONS`
- Merchant/vendor search overlays need the same pattern if they use secure buttons

## Combat Log Event Parsing

Register `COMBAT_LOG_EVENT_UNFILTERED` and call `CombatLogGetCurrentEventInfo()` to parse combat events. This is a varargs function — the return values depend on the subevent type.

```lua
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

local band = bit.band

local function ProcessCombatLog()
    local _, subevent, _, sourceGUID, sourceName, sourceFlags, _,
          destGUID, destName, destFlags, _, spellId, spellName =
        CombatLogGetCurrentEventInfo()

    -- Filter to player/pet sources (ignore environment, NPCs)
    -- sourceFlags bits 0-2 (0x07) indicate affiliation:
    --   0x01 = mine, 0x02 = party, 0x04 = raid
    if not sourceFlags or band(sourceFlags, 0x07) == 0 then return end

    if subevent == "SPELL_CAST_SUCCESS" then
        -- Spell was successfully cast
        -- spellId = numeric spell ID, spellName = localized name
        -- sourceGUID/sourceName = caster, destGUID/destName = target
    elseif subevent == "SPELL_AURA_APPLIED" then
        -- Buff/debuff applied to destGUID
    elseif subevent == "SPELL_AURA_REMOVED" then
        -- Buff/debuff removed from destGUID
    elseif subevent == "UNIT_DIED" then
        -- destGUID died (sourceGUID is nil for natural death)
    end
end

-- In your event handler:
if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    ProcessCombatLog()
end
```

### Multi-Rank Spell Canonicalization

Many TBC spells have multiple ranks with different spell IDs. To track cooldowns consistently, map all ranks to a single canonical ID:

```lua
-- All Rebirth ranks → rank 1 ID (20484)
local CANONICAL_SPELL_ID = {
    [20484] = 20484, [20739] = 20484, [20742] = 20484,
    [20747] = 20484, [20748] = 20484, [26994] = 20484,
    -- All Lay on Hands ranks → rank 1 ID (633)
    [633] = 633, [2800] = 633, [10310] = 633, [27154] = 633,
}

-- In combat log handler:
local canonical = CANONICAL_SPELL_ID[spellId] or spellId
local key = sourceGUID .. "-" .. canonical  -- unique per caster per spell
```

Key details:
- `COMBAT_LOG_EVENT_UNFILTERED` fires with no args — you MUST call `CombatLogGetCurrentEventInfo()` to get the data
- Cache `CombatLogGetCurrentEventInfo` as a local for performance (it fires very frequently in raids)
- Common subevents: `SPELL_CAST_SUCCESS`, `SPELL_AURA_APPLIED`, `SPELL_AURA_REMOVED`, `SPELL_HEAL`, `SPELL_DAMAGE`, `UNIT_DIED`, `SPELL_CAST_START`
- `sourceFlags` bitmask: `0x01` = mine, `0x02` = party member, `0x04` = raid member. Use `band(flags, 0x07) ~= 0` to check if the source is in your group
- `GetPlayerInfoByGUID(guid)` returns `localizedClass, englishClass, ...` for class-coloring the caster name
- Use canonical IDs as storage keys so rank 1 and rank 6 of the same spell share one cooldown entry

## In-Place Array Compaction (O(n) Filtering)

When filtering a large array in-place, avoid `table.remove()` which shifts elements and is O(n^2). Use a two-pointer compaction pattern instead:

```lua
local function FilterResults(results)
    local j = 1
    for i = 1, #results do
        local id = results[i]
        if ShouldKeep(id) then
            results[j] = id
            j = j + 1
        end
    end
    -- Nil out the tail
    for i = j, #results do
        results[i] = nil
    end
end
```

Key details:
- `j` tracks the write position; only increments when an element is kept
- The tail-nil loop cleans up leftover entries after the compacted portion
- No table allocations — modifies the array in-place
- For 100+ element arrays (LFG listings, loot tables, roster scans), this is measurably faster than repeated `table.remove()`
- Can combine with caching: store API results (e.g., `GetSearchResultInfo`) during the filter pass to avoid re-fetching in later processing phases

## Addon Initialization with Load-on-Demand Dependency

When your addon extends a Blizzard frame that loads on demand (e.g., `Blizzard_GroupFinder_VanillaStyle`, `Blizzard_AchievementUI`), you must wait for it to load before hooking. Use `ADDON_LOADED` with a `C_Timer.After(0)` to defer until after the frame is fully initialized:

```lua
local function Initialize()
    -- Safe to hook Blizzard frames here
    hooksecurefunc(LFGBrowseFrame, "UpdateResultList", MyFilterHook)
    -- ... create UI, register events, etc.
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == "Blizzard_GroupFinder_VanillaStyle" then
        self:UnregisterEvent("ADDON_LOADED")
        C_Timer.After(0, Initialize)  -- defer one frame for full init
    end
end)

-- Fallback: if the Blizzard addon loaded before ours
if LFGBrowseFrame then
    C_Timer.After(0, Initialize)
end
```

Key details:
- `C_Timer.After(0, fn)` defers to the next frame — ensures all `OnLoad` scripts and XML templates are fully processed
- The fallback check (`if LFGBrowseFrame then`) handles the case where your addon loads after the dependency (common on `/reload`)
- Without the defer, frames may exist but lack child elements, scroll boxes, or methods added by `OnLoad`
- Always `UnregisterEvent` after initialization to avoid double-init
- This pattern applies to any load-on-demand Blizzard addon, not just LFG
