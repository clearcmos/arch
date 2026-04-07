# TellMeWhen Events & Notifications Reference

Events are actions triggered when icon state changes (shown, hidden, duration changes, etc.). Each event can fire one of six handler types: Sound, Animations, Announcements, Counter, Timer, or Lua.

## Events Structure

```lua
["Events"] = {
    {
        -- Common fields (all handlers)
        ["Event"] = "OnShow",           -- Trigger event (see Trigger Events below)
        ["Type"] = "Sound",             -- Handler type
        ["OnlyShown"] = false,          -- Only fire when icon is visible
        ["PassThrough"] = true,         -- Continue to check lower-priority events
        ["PassingCndt"] = false,        -- Enable condition checking
        ["Operator"] = "<",             -- Condition operator (if PassingCndt)
        ["Value"] = 0,                  -- Condition value (if PassingCndt)
        ["CndtJustPassed"] = false,     -- Fire only on transition to passing
        ["Frequency"] = 1,             -- Min seconds between fires

        -- Handler-specific fields (see below)
        ["Sound"] = "TMW - Pling 1",   -- For Sound handler
        ["Animation"] = "ACTVTNGLOW",  -- For Animations handler
        -- etc.
    },
    ["n"] = 1,
}
```

## Trigger Events

| Event | Fires When |
|-------|------------|
| `OnShow` | Icon becomes visible (alpha changes from 0 to non-0) |
| `OnHide` | Icon becomes hidden (alpha changes to 0) |
| `OnAlphaInc` | Icon alpha increases |
| `OnAlphaDec` | Icon alpha decreases |
| `OnDurationChanged` | Timer/duration value changes |
| `OnStart` | A new timer/duration begins |
| `OnFinish` | A timer/duration reaches zero |
| `OnStack` | Stack count changes |
| `OnCharge` | Charge count changes |
| `OnEventsRestored` | After event suppression period ends |
| `OnCondition` | Custom condition met (via IconEventConditionHandler) |

### Most Common Combinations

| Use Case | Event | Handler |
|----------|-------|---------|
| Alert when proc appears | `OnShow` | Sound or Animations |
| Alert when buff expires | `OnHide` | Sound |
| Glow while active | `OnShow` | Animations (Infinite) |
| Announce in chat | `OnShow` | Announcements |
| Count occurrences | `OnShow` | Counter |

---

## Handler Type: Sound

Plays a sound effect when triggered.

```lua
{
    ["Event"] = "OnShow",
    ["Type"] = "Sound",
    ["Sound"] = "TMW - Pling 1",    -- Sound identifier
}
```

### Sound field values:
- **LSM name**: `"TMW - Pling 1"` through `"TMW - Pling 6"`, `"TMW - Ding 1"` through `"TMW - Ding 9"`
- **File path**: `"Interface\\AddOns\\MyAddon\\sound.ogg"`
- **SoundKit ID**: Numeric game sound ID
- **"None"**: No sound (disabled)

### Bundled TMW Sounds:
| Sound | Style |
|-------|-------|
| `TMW - Pling 1` through `TMW - Pling 6` | Soft chime/ping variants |
| `TMW - Ding 1` through `TMW - Ding 9` | Bell/ding variants |

### Game Sounds (via LibSharedMedia):
| Sound | Description |
|-------|-------------|
| `Rubber Ducky` | Squeak sound |
| `Cartoon FX` | Boing/cartoon |
| `Explosion` | Explosion effect |
| `Short Circuit` | Electric zap |
| `Humm` | Low hum |
| `Raid Warning` | Raid warning sound |
| `PvP Flag Taken` | Flag capture |
| `Ready Check` | Ready check sound |

### Sound Channel
Controlled by profile setting `TMW.db.profile.SoundChannel`:
- `"SFX"` — Sound Effects channel (default)
- `"Music"` — Music channel
- `"Ambience"` — Ambience channel
- `"Master"` — Master channel

---

## Handler Type: Animations

Plays visual animations on the icon.

```lua
{
    ["Event"] = "OnShow",
    ["Type"] = "Animations",
    ["Animation"] = "ACTVTNGLOW",    -- Animation type
    ["Infinite"] = true,             -- Loop until state changes
    ["Duration"] = 0.8,              -- Duration in seconds (if not infinite)
    ["Magnitude"] = 10,              -- Movement magnitude (for shake/bounce)
    ["ScaleMagnitude"] = 2,          -- Scale factor (for pulse)
    ["Period"] = 0.4,                -- Animation cycle period
    ["Fade"] = true,                 -- Fade out at end
    ["AnimColor"] = "7fff0000",      -- Color overlay (ARGB hex)
    ["Alpha"] = 0.5,                 -- Animation alpha
}
```

### Animation Types

| Animation | Description | Key Settings |
|-----------|-------------|-------------|
| `ACTVTNGLOW` | Activation glow (default proc border glow) | Infinite, AnimColor |
| `ICONFLASH` | Icon flashes/blinks | Duration, Period, Fade |
| `ICONFADE` | Icon fades in/out | Duration, Fade |
| `ICONSHAKE` | Icon shakes/vibrates | Duration, Magnitude, Period |
| `ICONBOUNCE` | Icon bounces up and down | Duration, Magnitude, Period |

### Common Animation Patterns

**Proc glow (stays until proc is used):**
```lua
{
    ["Event"] = "OnShow",
    ["Type"] = "Animations",
    ["Animation"] = "ACTVTNGLOW",
    ["Infinite"] = true,
}
```

**Flash 3 times then stop:**
```lua
{
    ["Event"] = "OnShow",
    ["Type"] = "Animations",
    ["Animation"] = "ICONFLASH",
    ["Duration"] = 1.2,
    ["Period"] = 0.4,
    ["Fade"] = false,
}
```

**Shake on appearance:**
```lua
{
    ["Event"] = "OnShow",
    ["Type"] = "Animations",
    ["Animation"] = "ICONSHAKE",
    ["Duration"] = 0.5,
    ["Magnitude"] = 8,
    ["Period"] = 0.05,
}
```

---

## Handler Type: Announcements

Sends messages to chat channels or floating combat text systems.

```lua
{
    ["Event"] = "OnShow",
    ["Type"] = "Announcements",
    ["Text"] = "Proc is up!",        -- Message text (supports DogTags)
    ["Channel"] = "SAY",             -- Output channel
    ["Location"] = "",               -- Sub-channel info (whisper target, channel #)
    ["Sticky"] = false,              -- Sticky text (for SCT systems)
    ["ShowIconTex"] = true,          -- Show icon texture in message
    ["TextDuration"] = 13,           -- Display duration (for frame outputs)
    ["TextColor"] = "ffffffff",      -- Text color (ARGB hex)
    ["Size"] = 0,                    -- Font size override (0 = default)
}
```

### Channels

| Channel | Description |
|---------|-------------|
| `SAY` | /say chat |
| `YELL` | /yell chat |
| `WHISPER` | Whisper (set target in Location) |
| `PARTY` | Party chat |
| `RAID` | Raid chat |
| `RAID_WARNING` | Raid warning (requires assist) |
| `BATTLEGROUND` | Battleground chat |
| `INSTANCE_CHAT` | Instance chat |
| `SMART` | Auto-detect (raid > party > say) |
| `GUILD` | Guild chat |
| `OFFICER` | Officer chat |
| `EMOTE` | /emote |
| `CHANNEL` | Custom channel (set # in Location) |
| `FRAME` | Print to chat frame |
| `RAID_WARNING_FAKE` | RaidWarningFrame overlay (no rank required) |
| `ERRORS_FRAME` | Red error text area |
| `SCT` | Scrolling Combat Text (if addon present) |
| `MSBT` | MikScrollingBattleText (if addon present) |
| `Parrot` | Parrot (if addon present) |
| `FCT` | Floating Combat Text (Blizzard) |

### DogTag Text Substitutions
The Text field supports LibDogTag-3.0 tags:
- `[Spell]` — Spell name
- `[Duration]` — Remaining duration
- `[Stacks]` — Stack count
- `[Unit]` — Unit name
- `[Icon]` — Icon texture
- `[Counter("name")]` — Counter value

**Example — Raid warning when proc happens:**
```lua
{
    ["Event"] = "OnShow",
    ["Type"] = "Announcements",
    ["Text"] = "Proc is up! Use it!",
    ["Channel"] = "RAID_WARNING_FAKE",
    ["TextColor"] = "ffff0000",
    ["TextDuration"] = 3,
}
```

---

## Handler Type: Counter

Modifies a named counter value.

```lua
{
    ["Event"] = "OnShow",
    ["Type"] = "Counter",
    ["Counter"] = "myCounter",           -- Counter name
    ["CounterOperation"] = "+",          -- Operation
    ["CounterAmt"] = 1,                  -- Amount
}
```

### Operations
| Op | Effect |
|----|--------|
| `+` | Add to counter |
| `-` | Subtract from counter |
| `*` | Multiply counter |
| `/` | Divide counter |
| `=` | Set counter to value |

Counters are accessible via:
- Condition type `COUNTER`
- DogTag `[Counter("name")]`
- Lua: `TMW.COUNTERS["name"]`

---

## Handler Type: Timer

Timer event handler for delayed/periodic actions.

```lua
{
    ["Event"] = "OnShow",
    ["Type"] = "Timer",
    -- Timer-specific settings
}
```

---

## Handler Type: Lua

Executes custom Lua code when triggered.

```lua
{
    ["Event"] = "OnShow",
    ["Type"] = "Lua",
    ["LuaCode"] = "print('Proc happened!')",
}
```

The Lua environment has access to:
- `icon` — the icon object
- `eventSettings` — this event's settings table
- Standard WoW API

---

## Combining Multiple Events

You can have multiple events per icon. They are processed in order.

**Example — Sound + Glow on proc:**
```lua
["Events"] = {
    {
        ["Event"] = "OnShow",
        ["Type"] = "Sound",
        ["Sound"] = "TMW - Pling 1",
    },
    {
        ["Event"] = "OnShow",
        ["Type"] = "Animations",
        ["Animation"] = "ACTVTNGLOW",
        ["Infinite"] = true,
    },
    ["n"] = 2,
}
```

**Example — Sound on show + different sound on hide:**
```lua
["Events"] = {
    {
        ["Event"] = "OnShow",
        ["Type"] = "Sound",
        ["Sound"] = "TMW - Pling 1",
    },
    {
        ["Event"] = "OnHide",
        ["Type"] = "Sound",
        ["Sound"] = "TMW - Ding 3",
    },
    ["n"] = 2,
}
```

**Example — Announcement + Sound when buff drops off:**
```lua
["Events"] = {
    {
        ["Event"] = "OnHide",
        ["Type"] = "Sound",
        ["Sound"] = "Raid Warning",
    },
    {
        ["Event"] = "OnHide",
        ["Type"] = "Announcements",
        ["Text"] = "Shield Block EXPIRED!",
        ["Channel"] = "RAID_WARNING_FAKE",
        ["TextColor"] = "ffff4444",
        ["TextDuration"] = 3,
    },
    ["n"] = 2,
}
```

---

## Complete Example: Full Icon with Events and Conditions

```lua
{
    ["Enabled"] = true,
    ["Type"] = "reactive",
    ["Name"] = "Revenge",
    ["RangeCheck"] = true,
    ["ManaCheck"] = true,
    ["States"] = {
        { ["Alpha"] = 1, ["Color"] = "ffffffff" },
        nil,
        { ["Alpha"] = 0.5, ["Color"] = "ff7f7f7f" },
        { ["Alpha"] = 0.5, ["Color"] = "ff7f7f7f" },
    },
    ["Events"] = {
        {
            ["Event"] = "OnShow",
            ["Type"] = "Sound",
            ["Sound"] = "TMW - Pling 1",
        },
        {
            ["Event"] = "OnShow",
            ["Type"] = "Animations",
            ["Animation"] = "ACTVTNGLOW",
            ["Infinite"] = true,
        },
        ["n"] = 2,
    },
    ["Conditions"] = {
        {
            ["Type"] = "COMBAT",
            ["Level"] = 1,
        },
        {
            ["Type"] = "EXISTS",
            ["Unit"] = "target",
            ["Level"] = 1,
        },
        {
            ["Type"] = "REACT",
            ["Unit"] = "target",
            ["Level"] = 1,
        },
        ["n"] = 3,
    },
}
```

This creates a Revenge icon that:
- Only shows in combat with a hostile target
- Plays a pling sound when Revenge procs
- Glows with activation border while usable
- Dims when out of range or out of rage
