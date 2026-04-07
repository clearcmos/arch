# WoW Classic Anniversary API Reference

Detailed API documentation for World of Warcraft Classic Anniversary Edition (2.5.5, build 65340).

## Directory Structure

```
Interface/AddOns/
├── Blizzard_SharedXMLBase/     # Core framework utilities (Mixin, Pools, Tables)
├── Blizzard_SharedXML/         # Shared UI templates and widgets
├── Blizzard_SharedXMLGame/     # Game-specific shared components
├── Blizzard_FrameXMLBase/      # Frame XML base definitions
├── Blizzard_FrameXML/          # Core frame implementations
├── Blizzard_UIParent/          # Main UI root frame
├── Blizzard_UIPanelTemplates/  # Standard panel templates
└── [180+ other Blizzard_* addons]
```

## Core Framework

### Mixin System

**Location**: `Blizzard_SharedXMLBase/Mixin.lua`

```lua
-- Define a mixin
MyMixin = {}

function MyMixin:OnLoad()
    self:Initialize()
end

function MyMixin:GetValue()
    return self.value
end

-- Create object from mixin(s)
local obj = CreateFromMixins(MyMixin)
local obj = CreateFromMixins(MixinA, MixinB, MixinC)

-- Apply mixin to existing object
Mixin(existingObject, MyMixin)

-- Create and initialize in one call
local obj = CreateAndInitFromMixin(MyMixin, arg1, arg2)
```

**Secure Variants** (combat-safe):
```lua
if issecure() then
    local obj = CreateFromSecureMixins(SecureMixin)
    SecureMixin(frame, SecureMixinA)
end
```

### Callback Registry

**Location**: `Blizzard_SharedXMLBase/CallbackRegistry.lua`

```lua
MyFrameMixin = CreateFromMixins(CallbackRegistryMixin)

MyFrameMixin:GenerateCallbackEvents({
    "OnValueChanged",
    "OnStateUpdated",
})

function MyFrameMixin:OnLoad()
    CallbackRegistryMixin.OnLoad(self)
end

-- Register callback
frame:RegisterCallback("OnValueChanged", function(frame, newValue)
    print("Value changed to:", newValue)
end, owner)

-- With handle for easy unregistration
local handle = frame:RegisterCallbackWithHandle("OnValueChanged", callback, owner)
handle:Unregister()

-- Trigger event
frame:TriggerEvent("OnValueChanged", self.value)

-- Unregister
frame:UnregisterCallback("OnValueChanged", owner)
```

### Object Pooling

**Location**: `Blizzard_SharedXMLBase/Pools.lua`

```lua
local pool = CreateObjectPool(
    function(pool)  -- Creator
        return CreateFrame("Frame", nil, parent, "MyTemplate")
    end,
    function(pool, frame)  -- Resetter
        frame:Hide()
        frame:ClearAllPoints()
        frame:SetParent(nil)
    end
)

local frame, isNew = pool:Acquire()
if isNew then
    -- First-time initialization
end

pool:Release(frame)
pool:ReleaseAll()
local count = pool:GetNumActive()
```

### Frame Factory

**Location**: `Blizzard_SharedXMLBase/FrameFactory.lua`

```lua
local factory = CreateFrameFactory()
local frame, isNew = factory:Create(parent, "MyTemplate")
factory:Release(frame)
factory:ReleaseAll()
```

## XML Template Patterns

### Basic Frame Declaration

```xml
<Ui xmlns="http://www.blizzard.com/wow/ui/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.blizzard.com/wow/ui/ ..\..\UI.xsd">

    <Frame name="MyFrameTemplate" mixin="MyFrameMixin" virtual="true">
        <Size x="200" y="150"/>

        <KeyValues>
            <KeyValue key="title" value="My Frame" type="string"/>
            <KeyValue key="maxValue" value="100" type="number"/>
            <KeyValue key="enabled" value="true" type="boolean"/>
            <KeyValue key="callback" value="MyGlobalFunction" type="global"/>
        </KeyValues>

        <Anchors>
            <Anchor point="CENTER"/>
        </Anchors>

        <Scripts>
            <OnLoad method="OnLoad"/>
            <OnShow method="OnShow"/>
            <OnHide method="OnHide"/>
            <OnEvent method="OnEvent"/>
        </Scripts>
    </Frame>
</Ui>
```

### Frame Hierarchy with parentKey

```xml
<Frame name="MyDialogTemplate" mixin="MyDialogMixin" virtual="true">
    <Size x="400" y="300"/>

    <Frames>
        <!-- Access via self.CloseButton -->
        <Button name="$parentCloseButton" parentKey="CloseButton"
                inherits="UIPanelCloseButton">
            <Anchors>
                <Anchor point="TOPRIGHT" x="-5" y="-5"/>
            </Anchors>
        </Button>

        <!-- Access via self.ContentFrame -->
        <Frame name="$parentContent" parentKey="ContentFrame">
            <Size x="380" y="250"/>
        </Frame>

        <!-- Access via self.TitleText -->
        <FontString parentKey="TitleText" inherits="GameFontNormalLarge">
            <Anchors>
                <Anchor point="TOP" y="-15"/>
            </Anchors>
        </FontString>
    </Frames>
</Frame>
```

### Intrinsic Script Handlers

```xml
<Frame name="EventFrame" mixin="EventFrameMixin" intrinsic="true">
    <Scripts>
        <OnLoad method="OnLoad_Intrinsic"/>
        <OnShow method="OnShow_Intrinsic" intrinsicOrder="postcall"/>
        <OnHide method="OnHide_Intrinsic" intrinsicOrder="postcall"/>
    </Scripts>
</Frame>
```

## Secure Frame System

### Secure Execution

**Location**: `Blizzard_FrameXML/SecureHandlers.lua`

```lua
if issecure() then
    -- Can perform protected operations
end

securecallfunction(myFunction, arg1, arg2)

secureexecuterange(table, 1, #table, function(index, value)
    -- Process each element securely
end)
```

### State Drivers

**Location**: `Blizzard_FrameXML/SecureStateDriver.lua`

```lua
-- Visibility driver (macro conditions)
RegisterStateDriver(frame, "visibility", "[combat] hide; show")

-- Attribute driver
RegisterAttributeDriver(frame, "state-inCombat", "[combat] 1; 0")

-- Unit watch
RegisterUnitWatch(frame)  -- Shows when unit exists
RegisterUnitWatch(frame, true)  -- Sets state-unitexists attribute

-- Unregister
UnregisterStateDriver(frame, "visibility")
UnregisterUnitWatch(frame)
```

## Utility Functions

### FrameUtil

**Location**: `Blizzard_SharedXMLBase/FrameUtil.lua`

```lua
-- Apply mixins and auto-wire script handlers
FrameUtil.SpecializeFrameWithMixins(frame, MixinA, MixinB)

-- Register events
FrameUtil.RegisterFrameForEvents(frame, {"EVENT_A", "EVENT_B"})
FrameUtil.UnregisterFrameForEvents(frame, {"EVENT_A"})

-- Unit events
FrameUtil.RegisterFrameForUnitEvents(frame, {"UNIT_HEALTH"}, "player", "target")

-- Periodic callback
FrameUtil.RegisterUpdateFunction(frame, 0.1, function(frame, elapsed)
    -- Called every 0.1 seconds
end)
FrameUtil.UnregisterUpdateFunction(frame)

-- Get root parent
local root = FrameUtil.GetRootParent(frame)

-- Fit child to parent
FitToParent(parent, child)
```

### TableUtil

**Location**: `Blizzard_SharedXMLBase/TableUtil.lua`

```lua
tContains(table, value)           -- Check if value exists
tInvert(table)                    -- Swap keys and values
tDeleteItem(table, value)         -- Remove by value
CountTable(table)                 -- Count elements

local found = FindInTableIf(table, function(element)
    return element.id == targetId
end)

local exists = ContainsIf(table, function(element)
    return element.active
end)

for index, value in ipairs_reverse(table) do
    -- Iterate backwards
end
```

### FunctionUtil

**Location**: `Blizzard_SharedXMLBase/FunctionUtil.lua`

```lua
-- Closure with pre-bound arguments
local closure = GenerateClosure(myFunction, arg1, arg2)
closure(arg3)  -- Calls myFunction(arg1, arg2, arg3)

-- Execute next frame
RunNextFrame(function()
    -- Runs on next frame update
end)

-- Safe method call
FunctionUtil.SafeInvokeMethod(object, "MethodName", arg1, arg2)

-- Execute frame script
ExecuteFrameScript(frame, "OnClick", "LeftButton", false)

-- Call method on ancestor
CallMethodOnNearestAncestor(frame, "UpdateLayout")
```

### EnumUtil

**Location**: `Blizzard_SharedXMLBase/EnumUtil.lua`

```lua
local MyEnum = EnumUtil.MakeEnum("NONE", "ACTIVE", "PAUSED", "COMPLETE")
-- Result: { NONE = 1, ACTIVE = 2, PAUSED = 3, COMPLETE = 4 }

if EnumUtil.IsValid(MyEnum, value) then
    -- Valid enum value
end

local getName = EnumUtil.GenerateNameTranslation(MyEnum)
print(getName(2))  -- "ACTIVE"
```

### Color Utilities

**Location**: `Blizzard_SharedXMLBase/Color.lua`

```lua
local color = CreateColor(1.0, 0.5, 0.0, 1.0)  -- RGBA

color:SetRGBA(r, g, b, a)
local r, g, b, a = color:GetRGBA()
local hex = color:GenerateHexColor()  -- "FF8000"

-- Predefined colors
HIGHLIGHT_FONT_COLOR
NORMAL_FONT_COLOR
RED_FONT_COLOR
GREEN_FONT_COLOR
GRAY_FONT_COLOR
WHITE_FONT_COLOR
YELLOW_FONT_COLOR
ORANGE_FONT_COLOR
```

## UI Animation

### Frame Fading

```lua
UIFrameFadeOut(frame, 0.5, 1.0, 0.0)
UIFrameFadeIn(frame, 0.5, 0.0, 1.0)

UIFrameFade(frame, {
    mode = "IN",  -- or "OUT"
    timeToFade = 0.5,
    startAlpha = 0.0,
    endAlpha = 1.0,
    finishedFunc = function()
        print("Fade complete")
    end,
    finishedArg1 = customArg,
})

if UIFrameIsFading(frame) then
    UIFrameFadeRemoveFrame(frame)  -- Cancel fade
end
```

## Common API Functions

### Unit Functions

```lua
UnitName(unit)
UnitClass(unit)
UnitLevel(unit)
UnitRace(unit)

UnitHealth(unit)
UnitHealthMax(unit)
UnitPower(unit, powerType)
UnitPowerMax(unit, powerType)

UnitIsPlayer(unit)
UnitIsEnemy(unit, otherUnit)
UnitIsFriend(unit, otherUnit)
UnitIsDead(unit)
UnitIsGhost(unit)
UnitIsAFK(unit)

UnitAffectingCombat(unit)
UnitCanAttack(unit, target)
UnitThreatSituation(unit, target)
```

### Frame Functions

```lua
-- Creation
CreateFrame(frameType, name, parent, template)

-- Positioning
frame:SetPoint(point, relativeTo, relativePoint, x, y)
frame:ClearAllPoints()
frame:SetAllPoints(relativeTo)

-- Size
frame:SetSize(width, height)
frame:SetWidth(width)
frame:SetHeight(height)
frame:GetSize()

-- Visibility
frame:Show()
frame:Hide()
frame:SetShown(shown)
frame:IsShown()
frame:IsVisible()

-- Hierarchy
frame:SetParent(parent)
frame:GetParent()
frame:GetChildren()

-- Alpha
frame:SetAlpha(alpha)
frame:GetAlpha()
frame:GetEffectiveAlpha()

-- Level
frame:SetFrameLevel(level)
frame:GetFrameLevel()
frame:SetFrameStrata(strata)

-- Mouse
frame:EnableMouse(enable)
frame:EnableMouseWheel(enable)
frame:SetMovable(movable)
frame:SetResizable(resizable)
```

### Texture Functions

```lua
local tex = frame:CreateTexture(name, layer)

tex:SetTexture(path)
tex:SetAtlas(atlasName)
tex:SetColorTexture(r, g, b, a)

tex:SetTexCoord(left, right, top, bottom)
tex:SetVertexColor(r, g, b, a)
tex:SetBlendMode(mode)  -- "BLEND", "ADD", "ALPHAKEY"
```

### FontString Functions

```lua
local fs = frame:CreateFontString(name, layer, template)

fs:SetText(text)
fs:GetText()
fs:SetFormattedText(format, ...)

fs:SetFontObject(fontObject)
fs:SetFont(font, size, flags)

fs:SetTextColor(r, g, b, a)
fs:SetJustifyH(justify)  -- "LEFT", "CENTER", "RIGHT"
fs:SetJustifyV(justify)  -- "TOP", "MIDDLE", "BOTTOM"
```

## Lua Coding Conventions

### Naming Patterns

```lua
-- Mixins: PascalCase + "Mixin" suffix
MyFrameMixin = {}
ButtonControllerMixin = {}

-- Mixin methods: PascalCase
function MyFrameMixin:OnLoad()
function MyFrameMixin:GetValue()

-- Global functions: PascalCase
function CreateMyWidget(parent, name)

-- Global constants: SCREAMING_SNAKE_CASE
MY_ADDON_VERSION = "1.0.0"
MAX_ITEM_COUNT = 100

-- Local variables: camelCase
local frameFactory = CreateFrameFactory()
```

### Standard Script Handler Names

Auto-wired by `FrameUtil.SpecializeFrameWithMixins`:

```lua
StandardScriptHandlerSet = {
    OnLoad = true,
    OnShow = true,
    OnHide = true,
    OnEvent = true,
    OnEnter = true,
    OnLeave = true,
    OnClick = true,
    OnDragStart = true,
    OnReceiveDrag = true,
}
```

### Local References for Performance

```lua
local pairs = pairs
local ipairs = ipairs
local select = select
local type = type
local wipe = table.wipe
local tinsert = table.insert
local tremove = table.remove

local CreateFrame = CreateFrame
local GetTime = GetTime
local UnitHealth = UnitHealth
```

## Important Files Reference

| File | Purpose |
|------|---------|
| `Blizzard_SharedXMLBase/Mixin.lua` | Mixin system |
| `Blizzard_SharedXMLBase/CallbackRegistry.lua` | Custom events |
| `Blizzard_SharedXMLBase/Pools.lua` | Object pooling |
| `Blizzard_SharedXMLBase/FrameFactory.lua` | Frame factory |
| `Blizzard_SharedXMLBase/TableUtil.lua` | Table utilities |
| `Blizzard_SharedXMLBase/FrameUtil.lua` | Frame utilities |
| `Blizzard_SharedXMLBase/FunctionUtil.lua` | Function utilities |
| `Blizzard_SharedXMLBase/Color.lua` | Color utilities |
| `Blizzard_SharedXMLBase/EnumUtil.lua` | Enum utilities |
| `Blizzard_FrameXML/SecureHandlers.lua` | Secure handlers |
| `Blizzard_FrameXML/SecureStateDriver.lua` | State drivers |
| `Blizzard_FrameXMLBase/Classic/FrameLocks.lua` | Frame locks |

## Best Practices

### Avoid Taint

```lua
local CreateFrame = CreateFrame
local securecallfunction = securecallfunction

securecallfunction(callback, arg1, arg2)
```

### Efficient Event Handling

```lua
function MyMixin:OnLoad()
    self:RegisterEvent("SPECIFIC_EVENT_NEEDED")
end

function MyMixin:OnHide()
    self:UnregisterAllEvents()
end

function MyMixin:OnShow()
    self:RegisterEvent("SPECIFIC_EVENT_NEEDED")
end
```

### Memory Management

```lua
local buttonPool = CreateObjectPool(
    function() return CreateFrame("Button", nil, parent, "MyButtonTemplate") end,
    function(pool, button)
        button:Hide()
        button:ClearAllPoints()
    end
)

-- Reuse tables
local reuseTable = {}
function ProcessData(data)
    wipe(reuseTable)
    -- Use reuseTable
end
```

### Error Handling

```lua
local success, result = pcall(function()
    -- Potentially dangerous code
end)

if not success then
    print("Error:", result)
end

xpcall(
    function()
        -- Code that might error
    end,
    function(err)
        print("Error:", err)
        print(debugstack())
    end
)
```
