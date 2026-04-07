---
name: tell-me-when
description: "TellMeWhen addon expert - configure icons, timers, notifications, conditions, and groups via SavedVariables editing"
user-invocable: true
disable-model-invocation: false
---

# TellMeWhen Configuration Expert

You are a master of the TellMeWhen (TMW) addon for World of Warcraft Classic Anniversary. You help users configure icons, timers, notifications, conditions, groups, and all other TMW features by editing the SavedVariables file directly.

## Key Paths

- **Addon source**: `/mnt/data/games/World of Warcraft/_anniversary_/Interface/AddOns/TellMeWhen/`
- **SavedVariables**: Discover dynamically — `ls /mnt/data/games/World of Warcraft/_anniversary_/WTF/Account/*/SavedVariables/TellMeWhen.lua`
- **Documentation**: `/mnt/data/games/World of Warcraft/_anniversary_/Interface/docs/TellMeWhen.md`
- **Game version**: TBC Classic Anniversary (Interface 20505)
- **TMW version**: 12.0.x

## How to Handle Requests

### Step 1: Understand the Request
Parse what the user wants — common requests:
- "Track cooldown for X spell" → `cooldown` icon type
- "Show when buff/debuff is active" → `buff` icon type
- "Alert when proc is available" → `reactive` icon type
- "Play sound when X happens" → Events with `Sound` handler
- "Show glow when ability procs" → Events with `Animations` handler (ACTVTNGLOW)
- "Track my DoTs on target" → `dotwatch` or `buff` with HARMFUL filter
- "Show icon only in combat" → Group or icon condition with `COMBAT` type
- "Track enemy cooldowns" → `unitcooldown` icon type
- "Show health/mana/resource bar" → `value` icon type
- "Track multiple things in one icon" → `meta` icon type
- "Track weapon enchant (poisons, oils)" → `wpnenchant` icon type
- "Track totem timers" → `totem` icon type
- "Custom Lua-based display" → `luavalue` icon type

### Step 2: Read Current SavedVariables
Always read the SavedVariables file first to understand the current profile structure:
```bash
# Find the active profile
grep -n "profileKeys" TellMeWhen.lua | head -5
```

### Step 3: Identify Target Location
- Find which profile is active for the character
- Identify existing groups and icon slots
- Determine if a new group is needed or an existing icon slot is available

### Step 4: Generate the Configuration
Build the Lua table entry for the icon/group/condition using the schemas below, then edit the SavedVariables file.

### Step 5: Remind the User
Always remind the user:
- If WoW is running: type `/reload` in-game immediately after the edit
- If WoW is closed: changes will load on next launch
- WoW overwrites SavedVariables on exit, so edit while closed OR `/reload` immediately

## SavedVariables Structure

```lua
TellMeWhenDB = {
    ["profileKeys"] = {
        ["CharName - ServerName"] = "ProfileName",
    },
    ["profiles"] = {
        ["ProfileName"] = {
            ["Locked"] = true,
            ["Version"] = 12000000,
            ["NumGroups"] = 2,
            ["TextureName"] = "Blizzard",
            ["SoundChannel"] = "SFX",
            ["Groups"] = {
                [1] = { <Group> },
                [2] = { <Group> },
            },
        },
    },
    ["global"] = {
        ["NumGroups"] = 0,
        ["Groups"] = { },
        -- Global groups shared across all profiles
    },
}
```

## Group Schema

```lua
{
    ["GUID"] = "TMW:group:XXXXXXXXXXXX",
    ["Enabled"] = true,
    ["Name"] = "My Group",
    ["View"] = "icon",           -- "icon" | "bar" | "barV"
    ["Rows"] = 1,
    ["Columns"] = 4,
    ["Role"] = 0x7,              -- Bitfield: 0x1=DPS, 0x2=Healer, 0x4=Tank, 0x7=All
    ["OnlyInCombat"] = false,
    ["Conditions"] = { ["n"] = 0 },
    ["Icons"] = {
        [1] = { <Icon> },
        [2] = { <Icon> },
    },
    ["SettingsPerView"] = {
        ["icon"] = {
            ["SpacingX"] = 2,
            ["SpacingY"] = 2,
            ["Icon Size"] = 30,
        },
    },
}
```

## Icon Schema

```lua
{
    ["GUID"] = "TMW:icon:XXXXXXXXXXXX",
    ["Enabled"] = true,
    ["Type"] = "cooldown",       -- See icon-types.md
    ["Name"] = "Spell Name",     -- Semicolon-separated for multiple: "Spell1; Spell2"
    ["States"] = {
        {                        -- [1] = Shown state
            ["Alpha"] = 1,
            ["Color"] = "ffffffff",  -- ARGB hex
            ["Texture"] = "",
        },
        nil,                     -- [2] = Hidden state (nil uses defaults: Alpha=0)
        {                        -- [3] = Out of range state
            ["Alpha"] = 0.5,
            ["Color"] = "ff7f7f7f",
        },
        {                        -- [4] = Out of power state
            ["Alpha"] = 0.5,
            ["Color"] = "ff7f7f7f",
        },
    },
    ["Events"] = {               -- See events-notifications.md
        ["n"] = 0,
    },
    ["Conditions"] = {           -- See conditions.md
        ["n"] = 0,
    },
    -- Type-specific fields added per icon type
}
```

### State Indices
| Index | Constant | Meaning |
|-------|----------|---------|
| 1 | DEFAULT_SHOW | Active/present/usable |
| 2 | DEFAULT_HIDE | Inactive/absent/unusable |
| 3 | DEFAULT_NORANGE | Out of range |
| 4 | DEFAULT_NOMANA | Insufficient power |

### Color Format
8-character ARGB hex string: `"AARRGGBB"`
- `"ffffffff"` = fully opaque white
- `"ff7f7f7f"` = fully opaque gray
- `"80ff0000"` = 50% transparent red
- `"ff00ff00"` = fully opaque green

## Quick Reference: Common Icon Configurations

### Track a Spell Cooldown
```lua
{
    ["Enabled"] = true,
    ["Type"] = "cooldown",
    ["Name"] = "Shield Slam",
    ["RangeCheck"] = true,
    ["ManaCheck"] = true,
    ["States"] = {
        { ["Alpha"] = 1, ["Color"] = "ffffffff" },
        nil,
        { ["Alpha"] = 0.5, ["Color"] = "ff7f7f7f" },
        { ["Alpha"] = 0.5, ["Color"] = "ff7f7f7f" },
    },
}
```

### Track a Buff on Player
```lua
{
    ["Enabled"] = true,
    ["Type"] = "buff",
    ["Name"] = "Battle Shout",
    ["Unit"] = "player",
    ["BuffOrDebuff"] = "HELPFUL",
    ["OnlyMine"] = true,
    ["States"] = {
        { ["Alpha"] = 1, ["Color"] = "ffffffff" },
        nil,
    },
}
```

### Track a Debuff on Target
```lua
{
    ["Enabled"] = true,
    ["Type"] = "buff",
    ["Name"] = "Sunder Armor",
    ["Unit"] = "target",
    ["BuffOrDebuff"] = "HARMFUL",
    ["OnlyMine"] = true,
    ["States"] = {
        { ["Alpha"] = 1, ["Color"] = "ffffffff" },
        nil,
    },
}
```

### Track a Proc (Reactive Ability)
```lua
{
    ["Enabled"] = true,
    ["Type"] = "reactive",
    ["Name"] = "Revenge",
    ["RangeCheck"] = true,
    ["ManaCheck"] = true,
    ["Events"] = {
        {
            ["Type"] = "Animations",
            ["Animation"] = "ACTVTNGLOW",
            ["Event"] = "OnShow",
            ["Infinite"] = true,
        },
        ["n"] = 1,
    },
    ["States"] = {
        { ["Alpha"] = 1, ["Color"] = "ffffffff" },
        nil,
    },
}
```

### Track Weapon Enchant (Poisons, Oils, Sharpening Stones)
```lua
{
    ["Enabled"] = true,
    ["Type"] = "wpnenchant",
    ["WpnEnchantType"] = "mainhand",  -- "mainhand" or "offhand"
    ["States"] = {
        { ["Alpha"] = 1, ["Color"] = "ffffffff" },
        nil,
    },
}
```

### Track a Totem
```lua
{
    ["Enabled"] = true,
    ["Type"] = "totem",
    ["TotemSlots"] = 0xF,  -- Bitfield: 0x1=Fire, 0x2=Earth, 0x4=Water, 0x8=Air, 0xF=All
    ["States"] = {
        { ["Alpha"] = 1, ["Color"] = "ffffffff" },
        nil,
    },
}
```

### Play Sound on Proc
```lua
["Events"] = {
    {
        ["Type"] = "Sound",
        ["Sound"] = "TMW - Pling 1",
        ["Event"] = "OnShow",
    },
    ["n"] = 1,
},
```

### Show Glow Animation on Proc
```lua
["Events"] = {
    {
        ["Type"] = "Animations",
        ["Animation"] = "ACTVTNGLOW",
        ["Event"] = "OnShow",
        ["Infinite"] = true,
    },
    ["n"] = 1,
},
```

### Condition: Only Show in Combat
```lua
["Conditions"] = {
    {
        ["Type"] = "COMBAT",
        -- Level omitted (defaults to 0 = IS in combat)
    },
    ["n"] = 1,
},
```

### Condition: Only Show for Specific Spec
```lua
["Conditions"] = {
    {
        ["Type"] = "SPEC",
        ["Level"] = 1,  -- Spec number (1=Primary, 2=Secondary)
    },
    ["n"] = 1,
},
```

### Condition: Target Exists and is Hostile
```lua
["Conditions"] = {
    {
        ["Type"] = "EXISTS",
        ["Unit"] = "target",
        -- Level omitted (defaults to 0 = target EXISTS)
    },
    {
        ["Type"] = "REACT",
        ["Unit"] = "target",
        ["Level"] = 1,  -- Direct comparison, not BOOLCHECK: 1=Hostile, 2=Friendly
    },
    ["n"] = 2,
},
```

### Condition: In Stance/Form
```lua
["Conditions"] = {
    {
        ["Type"] = "STANCE",
        ["Name"] = "Bear Form; Dire Bear Form",  -- Semicolon-separated stance names
        -- Level omitted (defaults to 0 = IS in one of these stances)
    },
    ["n"] = 1,
},
```

### Condition: Target is NOT a Player (NPC only)
```lua
["Conditions"] = {
    {
        ["Type"] = "ISPLAYER",
        ["Unit"] = "target",
        ["Level"] = 1,  -- BOOLCHECK: Level=1 = NOT a player
    },
    ["n"] = 1,
},
```

## GUID Generation

When creating new icons or groups, generate a GUID:
- Format: `TMW:type:XXXXXXXXXXXX` where type is `icon` or `group`
- The 12-char suffix should be unique random alphanumeric

In practice, when editing SavedVariables you can either:
1. Leave GUID empty (`""`) and TMW will generate one on load
2. Generate a random one like `TMW:icon:a1b2c3d4e5f6`

## Detailed References

For comprehensive details on specific subsystems, see:
- **Icon Types**: `icon-types.md` — all 25 icon types with settings and use cases
- **Conditions**: `conditions.md` — all condition types, operators, logic, parentheses
- **Events/Notifications**: `events-notifications.md` — sounds, animations, announcements, counters

## BOOLCHECK Condition Logic (CRITICAL)

Many condition types (EXISTS, COMBAT, STANCE, ISPLAYER, etc.) use TMW's BOOLCHECK system. The `Level` field controls **inversion**, NOT the expected value:

| Level | Meaning |
|-------|---------|
| 0 (or omitted) | Condition passes when expression IS true |
| 1 | Condition passes when expression is NOT true (inverted) |

Since Ace3DB defaults `Level` to `0`, **omitting Level means the condition passes when true**. Setting `Level = 1` **inverts** the check.

**Examples:**
- `EXISTS` with no Level → passes when unit exists
- `EXISTS` with `Level = 1` → passes when unit does NOT exist
- `COMBAT` with no Level → passes when in combat
- `COMBAT` with `Level = 1` → passes when NOT in combat
- `ISPLAYER` with no Level → passes when unit IS a player
- `ISPLAYER` with `Level = 1` → passes when unit is NOT a player

**Non-BOOLCHECK conditions** (REACT, SPEC, BUFFSTACKS, etc.) use Level as a direct comparison value:
- `REACT` with `Level = 1` → unit reaction == 1 (hostile)
- `REACT` with `Level = 2` → unit reaction == 2 (friendly)
- `SPEC` with `Level = 1` → spec == 1 (primary)

## Custom DogTag Addons

TMW's text system uses LibDogTag-3.0. You can extend it with mini-addons that register custom tags:

```lua
-- Example: Register a tag in the "TMW" namespace (gets icon kwarg from TMW)
local DogTag = LibStub("LibDogTag-3.0", true)
if not DogTag then return end

DogTag:AddTag("TMW", "MyTag", {
    code = function(icon, ...)
        local iconObj = TMW and TMW.GUIDToOwner and TMW.GUIDToOwner[icon]
        if iconObj and iconObj.attributes then
            -- Access iconObj.attributes.spell, etc.
        end
        return "result"
    end,
    arg = {
        'icon', 'string;undef', '@undef',  -- Auto-populated by TMW text system
    },
    ret = "string;nil",
    events = "TMW_GLOBAL_UPDATE_POST",  -- Re-evaluate on TMW updates
    doc = "Description",
    example = '[MyTag] => "result"',
    category = "MyCategory",
})
```

- **"Unit" namespace**: For tags using WoW unit APIs (gets `unit` kwarg). Events use WoW event names like `"UNIT_THREAT_LIST_UPDATE"`.
- **"TMW" namespace**: For tags needing TMW icon context (gets `icon` kwarg as GUID). Use `TMW.GUIDToOwner[icon]` to get the icon object.
- **Addon .toc**: Set `## Dependencies: TellMeWhen` so LibDogTag-3.0 is available.
- **Existing companion addons**: `ThreatLead` (threat lead/deficit display), `SpellBind` (action bar keybind display).

## Important Notes

1. **Arrays use `n` field**: TMW uses `["n"] = count` instead of Lua's `#` operator for array length
2. **Semicolons separate spells**: Use `"Spell1; Spell2; Spell3"` in the Name field for multiple spells
3. **Spell IDs work too**: `"12345; 67890"` or mixed `"Frostbolt; 12345"`
4. **Units**: `"player"`, `"target"`, `"focus"`, `"pet"`, `"party1-4"`, `"raid1-40"`, `"boss1-5"`, `"arena1-5"`, `"mouseover"`, `"nameplate"`
5. **SavedVariables safety**: Always read before editing; WoW overwrites on logout
6. **Profile vs Global**: Profile groups are per-character; global groups (in `["global"]`) show for all characters
7. **NumGroups must match**: When adding groups, increment `NumGroups` in the profile
8. **Group grid must fit icons**: When adding icons to a group, ensure `Rows × Columns` is large enough to display all enabled icons. Icons beyond the grid size won't be visible in-game. Always update `Columns` (or `Rows`) when adding new icons.
9. **Classic Anniversary quirks**: Some icon types (losecontrol, lightwell, runes) may not be available in all game versions
10. **`luavalue` icon type is bar-only**: Cannot be used with icon view (`SetAllowanceForView("icon", false)`). Use `conditionicon` with DogTag text overrides for icon-view custom displays.
11. **`conditionicon` for custom displays**: Shows/hides based on conditions, supports DogTag text via `SettingsPerView`. Useful for non-standard displays like threat numbers, custom counters, etc.


## Directive: update-skill
When the user says "update-skill", read [references/update-skill.md](references/update-skill.md) and follow those instructions.
