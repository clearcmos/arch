# Native Blizzard Frame Integration

Patterns for integrating addon UI into Blizzard's native frames — adding tabs, attaching panels, hooking methods, and reproducing the native look. Based on LFGFilter's integration with the LFG Browse frame.

## Adding Custom Tabs to Blizzard Panel Frames

### CharacterFrameTabButtonTemplate

```lua
local tab = CreateFrame("Button", "LFGParentFrameTab3", LFGParentFrame, "CharacterFrameTabButtonTemplate")
tab:SetID(3)
tab:SetText("Filters")
PanelTemplates_DeselectTab(tab)
```

### Naming Convention

`PanelTemplates_GetTabByIndex()` resolves tabs via `_G[frame:GetName().."Tab"..index]`. Name your tab to match (e.g., `LFGParentFrameTab3`). Keep `numTabs` at its original value — `PanelTemplates_UpdateTabs` only iterates `1..numTabs`, so your extra tab won't be auto-selected/deselected.

### Active Texture Bleed (+4px)

The template has two texture sets:
- **Inactive** (`UI-Character-InActiveTab`): anchored at TOPLEFT y=0
- **Active** (`$parentLeftDisabled`/`Middle`/`Right`): anchored at TOPLEFT **y=+4**

`PanelTemplates_SelectTab()` shows active textures extending 4px above the tab (designed to merge with the parent frame). It also calls `tab:Disable()`.

**For toggle tabs** (must remain clickable): never call `PanelTemplates_SelectTab`. Keep permanently deselected and use font objects for visual state:

```lua
PanelTemplates_DeselectTab(tab)

local function SetTabHighlight(active)
    if active then
        tab:SetNormalFontObject(GameFontHighlightSmall)
    else
        tab:SetNormalFontObject(GameFontNormalSmall)
    end
end
```

### Tab Sizing

Tabs start at **10x32 pixels**. `PanelTemplates_TabResize` sets the real width:

```lua
PanelTemplates_TabResize(tab, padding, absoluteSize, minWidth, maxWidth, absoluteTextSize)
-- padding=0: auto-size to text | absoluteSize=N: force exact width
-- Default maxWidth from template OnEvent is 88px
```

**Gotcha**: `GetWidth()` returns 10 before resize runs. To match another tab's width, defer:
```lua
C_Timer.After(0, function()
    PanelTemplates_TabResize(myTab, nil, otherTab:GetWidth())
end)
```

### Preventing Template Event Interference

`CharacterFrameTabButtonTemplate` registers `DISPLAY_SIZE_CHANGED` which can reposition your tab:
```lua
tab:UnregisterAllEvents()
```

## Tab Positioning Gotchas

### Blizzard's Browse OnShow y=-2 Hack

`LFGBrowseMixin:OnShow()` (Blizzard_LFGVanilla_Browse.lua line 122-124) permanently shifts Tab2 down 2px:
```lua
-- "Baby hack... the selected tab texture doesn't blend well with the LFG texture"
LFGParentFrameTab1:SetPoint("BOTTOMLEFT", 16, 45)
LFGParentFrameTab2:SetPoint("LEFT", LFGParentFrameTab1, "RIGHT", -14, -2)
```

This never resets. Any tab anchored relative to Tab2 inherits the shift.

### Dynamic Tab Text Changes

Tab1 changes between "Create Listing" and "Edit Listing" (`C_LFGList.HasActiveEntryInfo()`), triggering `PanelTemplates_TabResize` which changes Tab1's width and shifts everything after it.

### Solution: Absolute Positioning + Re-anchor on Events

Don't anchor relative to Tab2. Compute absolute BOTTOMLEFT position from actual tab widths, and reposition on every relevant event:

```lua
local function RepositionTab()
    local tab1W = LFGParentFrame.Tab1:GetWidth()
    local tab2W = LFGParentFrame.Tab2:GetWidth()
    if tab1W <= 10 or tab2W <= 10 then return end  -- not laid out yet
    PanelTemplates_TabResize(myTab, nil, tab2W)
    myTab:ClearAllPoints()
    -- X = base offset + tab1 width - overlap + tab2 width - overlap
    myTab:SetPoint("BOTTOMLEFT", LFGParentFrame, "BOTTOMLEFT",
        16 + tab1W - 14 + tab2W - 14, 45)
end

-- Initial positioning (deferred until tabs have final widths)
C_Timer.After(0, RepositionTab)

-- Re-anchor on every tab switch (Blizzard shifts Tab2 in Browse OnShow)
hooksecurefunc(LFGBrowseFrame, "OnShow", RepositionTab)
LFGListingFrame:HookScript("OnShow", RepositionTab)

-- Recompute when Tab1 text changes (Create Listing <-> Edit Listing)
hooksecurefunc(LFGParentFrame.Tab1, "SetText", function()
    C_Timer.After(0, RepositionTab)
end)
```

## Reproducing Native Frame Backgrounds

Blizzard's frames use multi-piece textures with specific tex coords and sublevel ordering, not backdrops.

### LFG Frame 3-Piece System

```lua
-- Top piece (ornate header with portrait ring)
local bgTop = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
bgTop:SetSize(512, 121)
bgTop:SetPoint("TOPLEFT", -1, 0)  -- note -1px X offset
bgTop:SetTexture("Interface\\LFGFrame\\UI-LFR-FRAME-MAIN")
bgTop:SetTexCoord(0, 1.0, 0, 0.236328125)

-- Middle piece
local bgMid = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
bgMid:SetSize(512, 135)
bgMid:SetPoint("TOPLEFT", 0, -121)
bgMid:SetTexture("Interface\\LFGFrame\\UI-LFG-FRAME")
bgMid:SetTexCoord(0, 1.0, 0.236328125, 0.5)

-- Bottom piece (sublevel 1 to overlap middle seam)
local bgBot = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
bgBot:SetSize(512, 256)
bgBot:SetPoint("TOPLEFT", 0, -256)
bgBot:SetTexture("Interface\\LFGFrame\\UI-LFG-FRAME")
bgBot:SetTexCoord(0, 1.0, 0.5, 1.0)

-- Content area background (atlas, sublevel 2 — above bgBot so it replaces
-- the frame texture's content area with the dark silhouette artwork)
local bgArt = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
bgArt:SetSize(324, 282)
bgArt:SetPoint("TOPLEFT", 22, -128)
bgArt:SetAtlas("groupfinder-background-classic")
```

Key details:
- Textures are 512px wide but frame is 384px — ornate borders extend beyond frame boundary
- Top/Middle at sublevel -1, Bottom at sublevel 1 (overlaps middle seam)
- Content atlas at sublevel **2** (above bgBot at 1) so it draws over the frame texture
- **Baked-in separator bars**: The `UI-LFG-FRAME` texture has ornate horizontal separator bars at y=-128 (between role icons and content) and y=-410 (below content). Position bgArt at exactly y=-128 with height=282 to reveal both bars. Starting bgArt too high (e.g., y=-119) covers the top bar; extending it too far (past y=-410) covers the bottom bar
- The role icons zone (y=-60 to y=-128) sits on the bare frame background (blue-ish tint) — do NOT cover it with bgArt

### Portrait, Title, and Close Button

For a custom portrait icon (replacing the baked-in LFG eye), inherit `PortraitFrameTemplate` to get a circle-masked `PortraitContainer`. Hide all template chrome and use manual `UI-LFG-FRAME` textures instead:

```lua
-- Inherit PortraitFrameTemplate for circle-masked portrait only
local frame = CreateFrame("Frame", "MyPanel", parent, "PortraitFrameTemplate")
frame:SetSize(384, 512)

-- Hide ALL template chrome (we only keep PortraitContainer)
frame.Bg:Hide(); frame.TitleBg:Hide(); frame.TopBorder:Hide()
frame.TopRightCorner:Hide(); frame.BotLeftCorner:Hide()
frame.BotRightCorner:Hide(); frame.BottomBorder:Hide()
frame.LeftBorder:Hide(); frame.RightBorder:Hide()
frame.TopTileStreaks:Hide(); frame.PortraitFrame:Hide()
frame.TitleText:Hide(); frame.CloseButton:Hide()
if frame.NineSlice then frame.NineSlice:Hide() end
if frame.portrait then frame.portrait:Hide() end  -- unmasked duplicate

-- Reposition PortraitContainer to center within the LFG ring
-- Ring center = TOPLEFT(12,-5) + half of 64x64 = (44,-37)
-- Portrait is 62x62 at (-5,7) within container, so container at (18,-13)
frame.PortraitContainer:ClearAllPoints()
frame.PortraitContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -13)
SetPortraitToTexture(frame.PortraitContainer.portrait,
    "Interface\\FriendsFrame\\FriendsFrameScrollIcon")

-- Gold portrait ring over the circle-masked portrait
local ring = frame:CreateTexture(nil, "OVERLAY")
ring:SetSize(64, 64)
ring:SetPoint("TOPLEFT", 12, -5)
ring:SetTexture("Interface\\LFGFrame\\UI-LFG-PORTRAIT")

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -18)
title:SetText("My Panel")

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -26, -8)
```

**Why PortraitFrameTemplate**: The `UI-LFG-FRAME` texture has a baked-in eye icon in the portrait area at the BACKGROUND layer. `PortraitContainer` renders at frame level 400 in the OVERLAY layer with a circle mask, drawing above the baked-in eye. Without it, you cannot replace the eye — no BACKGROUND sublevel ordering can cover a texture within the same layer at the same position.

## Side Panel Attachment

```lua
local panel = CreateFrame("Frame", "MyAddonPanel", BlizzardParentFrame)
panel:SetSize(384, 512)
panel:SetPoint("TOPLEFT", BlizzardParentFrame, "TOPRIGHT", -1, 0)  -- -1 overlaps border seam
panel:SetFrameStrata("DIALOG")

-- Hide when parent hides
BlizzardParentFrame:HookScript("OnHide", function()
    if panel:IsShown() then panel:Hide() end
end)
```

## Hooking Load-On-Demand Addon Frames

Many Blizzard UI frames (LFG, Collections, etc.) load on demand. Hook `ADDON_LOADED` and defer one frame:

```lua
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == "Blizzard_GroupFinder_VanillaStyle" then
        C_Timer.After(0, Initialize)  -- defer for Blizzard init to complete
    end
end)

-- Handle case where addon loaded before ours
if LFGBrowseFrame then
    C_Timer.After(0, Initialize)
end
```

### HookScript vs hooksecurefunc

- `frame:HookScript("OnShow", fn)` — hooks frame scripts (OnShow, OnHide, OnEvent)
- `hooksecurefunc(obj, "Method", fn)` — hooks a Lua method on a table (mixin methods)
- `hooksecurefunc("GlobalFunc", fn)` — hooks a global function

Use `hooksecurefunc` for Blizzard mixin methods (like `UpdateResultList`). Use `HookScript` for traditional frame scripts. Both run your function **after** the original.

## ScrollBox Data Provider Mutation with Filtering

When filtering a ScrollBox-backed list, mutate the underlying data array and call the frame's update method. Save/restore scroll position to prevent jumping:

```lua
hooksecurefunc(browseFrame, "UpdateResultList", function(self)
    if not HasActiveFilters() then return end
    local pct = self.ScrollBox:GetScrollPercentage()

    -- Remove non-matching entries from the results array
    local results = self.results
    for i = #results, 1, -1 do
        if not ShouldShow(results[i]) then
            table.remove(results, i)
        end
    end

    self:UpdateResults()  -- re-renders ScrollBox with filtered data
    self.ScrollBox:SetScrollPercentage(pct)
end)
```

**Note**: Blizzard's `UpdateResults()` passes `ScrollBoxConstants.RetainScrollPosition` to `SetDataProvider`, but when hooks cause double calls or significant list length changes, explicit save/restore is more reliable.

## Real-time Event-Driven List Cleanup

Listen for update events to remove delisted entries without a full re-search:

```lua
local cleanupFrame = CreateFrame("Frame")
cleanupFrame:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
cleanupFrame:SetScript("OnEvent", function(_, event, resultID)
    if not browseFrame:IsShown() then return end
    local info = C_LFGList.GetSearchResultInfo(resultID)
    if not info or not info.isDelisted then return end

    local results = browseFrame.results
    for i = #results, 1, -1 do
        if results[i] == resultID then
            table.remove(results, i)
            local pct = browseFrame.ScrollBox:GetScrollPercentage()
            browseFrame:UpdateResults()
            browseFrame.ScrollBox:SetScrollPercentage(pct)
            return
        end
    end
end)
```

## Native Role Icon Buttons

The LFG frame uses big circular role icons with colored background rings. These textures and helper functions are available in Classic Anniversary:

```lua
-- Role icon textures (48x48 icons with 80x80 background rings)
local ROLE_ICON_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
local ROLE_BG_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICONS-ROLEBACKGROUNDS"

-- Global functions for tex coords (work in Classic Anniversary)
GetTexCoordsForRole(role)              -- "TANK", "HEALER", "DAMAGER"
GetBackgroundTexCoordsForRole(role)    -- colored ring behind icon

-- Creating a role button
local btn = CreateFrame("Button", nil, parent)
btn:SetSize(48, 48)

local bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetSize(80, 80)
bg:SetPoint("CENTER")
bg:SetTexture(ROLE_BG_TEXTURE)
bg:SetTexCoord(GetBackgroundTexCoordsForRole(role))

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
icon:SetTexture(ROLE_ICON_TEXTURE)
icon:SetTexCoord(GetTexCoordsForRole(role))

-- Circular highlight
local hl = btn:CreateTexture(nil, "HIGHLIGHT")
hl:SetSize(80, 80)
hl:SetPoint("CENTER")
hl:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
hl:SetBlendMode("ADD")
hl:SetAlpha(0.3)
```

## Three-State Toggle Buttons (Off / Require / Exclude)

### Visual States (Role Icons)

```lua
local function UpdateRoleButtonVisual(btn, state)
    if state == "require" then
        btn.icon:SetDesaturated(false)
        btn.icon:SetVertexColor(1, 1, 1)
        btn.icon:SetAlpha(1.0)
        if btn.bg then btn.bg:SetAlpha(0.6); btn.bg:SetVertexColor(1, 1, 1) end
        if btn.includeCheck then btn.includeCheck:Show() end
        if btn.excludeX then btn.excludeX:Hide() end
    elseif state == "exclude" then
        btn.icon:SetDesaturated(false)
        btn.icon:SetVertexColor(1, 0.3, 0.3)
        btn.icon:SetAlpha(1.0)
        if btn.bg then btn.bg:SetAlpha(0.4); btn.bg:SetVertexColor(1, 0.3, 0.3) end
        if btn.includeCheck then btn.includeCheck:Hide() end
        if btn.excludeX then btn.excludeX:Show() end
    else  -- "off"
        btn.icon:SetDesaturated(true)
        btn.icon:SetVertexColor(1, 1, 1)
        btn.icon:SetAlpha(0.4)
        if btn.bg then btn.bg:SetAlpha(0.15); btn.bg:SetVertexColor(1, 1, 1) end
        if btn.includeCheck then btn.includeCheck:Hide() end
        if btn.excludeX then btn.excludeX:Hide() end
    end
end
```

### Click Handlers

**Click-cycling** (single button, cycles through states):
```lua
-- off → include → exclude → off
btn:SetScript("OnClick", function(self)
    local key = self.filterKey
    if includeTable[key] then
        includeTable[key] = nil
        excludeTable[key] = true
    elseif excludeTable[key] then
        excludeTable[key] = nil
    else
        includeTable[key] = true
    end
    RefreshVisuals()
    TriggerRefilter()
end)
```

**Left/right-click** (separate buttons for include/exclude):
```lua
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:SetScript("OnClick", function(self, mouseButton)
    if mouseButton == "RightButton" and excludeTable then
        includeTable[self.key] = nil
        excludeTable[self.key] = not excludeTable[self.key] or nil
    else
        if excludeTable then excludeTable[self.key] = nil end
        includeTable[self.key] = not includeTable[self.key] or nil
    end
    RefreshVisuals()
    TriggerRefilter()
end)
```

### Key Textures

```lua
-- Green checkmark overlay (include state)
includeCheck:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")

-- Red X overlay (exclude state)
excludeX:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")

-- Highlight on hover (circular, for role icons)
hl:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
hl:SetBlendMode("ADD")
hl:SetAlpha(0.3)

-- Row highlight (for list items)
hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
```

## Lua Scope Gotcha

Local functions must be defined before closures that reference them:

```lua
-- BROKEN: SetFoo doesn't exist when the closure is created
local function CreateBar()
    btn:SetScript("OnClick", function() SetFoo() end)  -- captures nil
end
local function SetFoo() ... end

-- CORRECT: define before reference
local function SetFoo() ... end
local function CreateBar()
    btn:SetScript("OnClick", function() SetFoo() end)  -- works
end
```

Lua resolves upvalue references at closure creation time. If the local doesn't exist yet, it captures nil — even though the closure runs later.
