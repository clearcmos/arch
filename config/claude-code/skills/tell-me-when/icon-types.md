# TellMeWhen Icon Types Reference

All icon types, their settings, states, and typical use cases.

## Core Types

### `cooldown` — Spell/Item Cooldown
Tracks when a spell or item comes off cooldown.

**Settings:**
```lua
{
    ["Type"] = "cooldown",
    ["Name"] = "Shield Slam",         -- Spell name or ID
    ["RangeCheck"] = false,           -- Enable out-of-range state
    ["ManaCheck"] = false,            -- Enable out-of-power state
    ["GCDAsUnusable"] = false,        -- Treat GCD as on cooldown
    ["IgnoreRunes"] = false,          -- Ignore DK rune cooldowns
}
```

**States:**
| State | Meaning |
|-------|---------|
| 1 (Show) | Spell is usable (off cooldown) |
| 2 (Hide) | Spell is on cooldown |
| 3 (NoRange) | Target out of range (if RangeCheck enabled) |
| 4 (NoMana) | Not enough power (if ManaCheck enabled) |

**Use cases:**
- Track rotation abilities
- Monitor defensive cooldowns
- Show when interrupts are ready

---

### `buff` — Buff/Debuff Tracking
Tracks presence/absence of auras on units.

**Settings:**
```lua
{
    ["Type"] = "buff",
    ["Name"] = "Rejuvenation; Lifebloom",  -- One or more aura names
    ["Unit"] = "player",              -- Unit to check (player, target, focus, etc.)
    ["BuffOrDebuff"] = "HELPFUL",     -- "HELPFUL" | "HARMFUL" | "EITHER"
    ["OnlyMine"] = false,             -- Only show auras cast by player
    ["Sort"] = 1,                     -- Sort order when tracking multiple
    ["StackSort"] = false,            -- Sort by stack count
    ["Stealable"] = false,            -- Only show stealable auras
    ["ShowTTText"] = false,           -- Show tooltip text
    ["HideIfNoUnits"] = false,        -- Hide when unit doesn't exist
}
```

**States:**
| State | Meaning |
|-------|---------|
| 1 (Show) | Aura is present on unit |
| 2 (Hide) | Aura is absent from unit |

**Use cases:**
- Track HoTs on yourself or party
- Monitor debuffs on target (DoT tracking)
- Track raid buffs (Battle Shout, Mark of the Wild)
- Track enemy buffs to purge/steal

---

### `buffcheck` — Missing Buff Check
Checks whether specific buffs are missing from units.

**Settings:**
```lua
{
    ["Type"] = "buffcheck",
    ["Name"] = "Mark of the Wild; Thorns",
    ["Unit"] = "player",
    ["BuffOrDebuff"] = "HELPFUL",
    ["OnlyMine"] = false,
}
```

**Use cases:**
- Reminder to rebuff
- Track missing raid buffs
- Pre-pull checklist

---

### `reactive` — Reactive/Proc Abilities
Tracks spells that become usable via procs (e.g., Overpower, Revenge, Nightfall).

**Settings:**
```lua
{
    ["Type"] = "reactive",
    ["Name"] = "Overpower",
    ["UseActvtnOverlay"] = true,      -- Check activation overlay glow
    ["OnlyActvtnOverlay"] = false,    -- ONLY show during overlay glow
    ["CooldownCheck"] = true,         -- Check cooldown too
    ["IgnoreNomana"] = false,         -- Ignore mana check
    ["IgnoreRunes"] = false,          -- Ignore DK runes
    ["RangeCheck"] = false,
    ["ManaCheck"] = false,
}
```

**States:**
| State | Meaning |
|-------|---------|
| 1 (Show) | Ability is usable/procced |
| 2 (Hide) | Ability is not usable |
| 3 (NoRange) | Out of range |
| 4 (NoMana) | Not enough power |

**Use cases:**
- Warrior: Overpower, Revenge, Execute procs
- Warlock: Nightfall (Shadow Trance) proc
- Any proc-based ability

---

### `meta` — Meta Icon
Combines multiple other icons — shows the first one that is active.

**Settings:**
```lua
{
    ["Type"] = "meta",
    ["Icons"] = {
        "TMW:icon:guid1",    -- First priority icon GUID
        "TMW:icon:guid2",    -- Second priority
        "TMW:icon:guid3",    -- etc.
    },
    ["Sort"] = false,         -- Sort by duration instead of priority
    ["CheckNext"] = false,    -- Expand sub-metas
}
```

**Use cases:**
- Priority-based rotation helpers
- Show highest-priority action from a set
- Combine multiple trackers into one icon slot

---

### `conditionicon` — Condition-Only Icon
Shows/hides based purely on conditions (no spell tracking).

**Settings:**
```lua
{
    ["Type"] = "conditionicon",
    ["Conditions"] = { ... },  -- Required: conditions determine show/hide
}
```

**Use cases:**
- Custom alerts based on game state
- Show icons based on zone, spec, combat state, etc.
- Complex multi-condition triggers

---

### `unitcondition` — Unit Condition Icon
Like conditionicon but designed for unit-based condition checking.

**Settings:**
```lua
{
    ["Type"] = "unitcondition",
    ["Unit"] = "target",
    ["UnitConditions"] = { ... },
}
```

---

## Combat Types

### `cast` — Spell Cast Tracking
Tracks when a unit is casting a specific spell.

**Settings:**
```lua
{
    ["Type"] = "cast",
    ["Name"] = "Hearthstone; Polymorph",
    ["Unit"] = "target",
    ["Interruptible"] = false,    -- Only show interruptible casts
}
```

**Use cases:**
- Interrupt alerts
- Enemy cast tracking
- Healer cast monitoring

---

### `icd` — Internal Cooldown Tracking
Tracks internal cooldowns on proc effects.

**Settings:**
```lua
{
    ["Type"] = "icd",
    ["Name"] = "Blade Flurry",
    ["ICDDuration"] = 10,          -- ICD duration in seconds
    ["ICDType"] = "aura",          -- "aura" | "spellcast" | "caststart"
}
```

**Use cases:**
- Trinket proc ICDs
- Item proc tracking
- Set bonus ICDs

---

### `dr` — Diminishing Returns
Tracks DR categories on units.

**Settings:**
```lua
{
    ["Type"] = "dr",
    ["Name"] = "stun",             -- DR category name
    ["Unit"] = "target",
}
```

**Use cases:**
- PvP CC tracking
- Arena DR management

---

### `swingtimer` — Swing Timer
Tracks auto-attack swing timer.

**Settings:**
```lua
{
    ["Type"] = "swingtimer",
    ["SwingType"] = "mainhand",    -- "mainhand" | "offhand"
}
```

**Use cases:**
- Rogue: optimize timing between swings
- Warrior: Heroic Strike queuing
- Hunter: auto-shot timing

---

### `dotwatch` — DoT/HoT Watcher
Tracks DoT/HoT durations across multiple targets.

**Settings:**
```lua
{
    ["Type"] = "dotwatch",
    ["Name"] = "Corruption; Curse of Agony",
    ["Unit"] = "target",
    ["BuffOrDebuff"] = "HARMFUL",
    ["OnlyMine"] = true,
}
```

**Use cases:**
- Multi-DoT tracking for warlocks
- HoT tracking for healers

---

### `cleu` — Combat Log Event
Tracks combat log events (CLEU).

**Settings:**
```lua
{
    ["Type"] = "cleu",
    ["CLEUEvents"] = {
        ["SPELL_AURA_APPLIED"] = true,
        ["SPELL_AURA_REMOVED"] = true,
    },
    ["CLEUDuration"] = 5,         -- How long to show after event
    ["Name"] = "Spell Name",
    ["Unit"] = "player",
    ["CLEUUnit"] = "source",      -- "source" | "dest"
}
```

**Use cases:**
- Track specific combat events
- Custom proc detection
- Debuff application alerts

---

## Resource Types

### `totem` — Totem Tracking
Tracks active totems by slot.

**Settings:**
```lua
{
    ["Type"] = "totem",
    ["TotemSlots"] = 0xF,          -- Bitfield: 0x1=Fire, 0x2=Earth, 0x4=Water, 0x8=Air
}
```

**Totem slot bits:**
| Bit | Slot |
|-----|------|
| 0x1 | Fire |
| 0x2 | Earth |
| 0x4 | Water |
| 0x8 | Air |
| 0xF | All slots |

**Use cases:**
- Shaman totem management
- Track specific totem slot timers

---

### `guardian` — Guardian/Pet Tracking
Tracks guardian or pet entities.

**Settings:**
```lua
{
    ["Type"] = "guardian",
    ["Name"] = "Treant",           -- Guardian name
}
```

---

### `runes` — Death Knight Runes
Tracks DK rune availability (Wrath+).

**Settings:**
```lua
{
    ["Type"] = "runes",
    ["Runes"] = { true, true, true, true, true, true },  -- Which rune slots
}
```

---

## Item Types

### `item` — Item Cooldown/Usability
Tracks item cooldowns (trinkets, on-use items).

**Settings:**
```lua
{
    ["Type"] = "item",
    ["Name"] = "Healthstone; 13503",   -- Item name or ID
    ["RangeCheck"] = false,
    ["ManaCheck"] = false,
    ["EnableStacks"] = false,          -- Show stack/count
}
```

**Use cases:**
- Trinket cooldowns
- Potion/Healthstone availability
- Engineering gadget cooldowns

---

### `wpnenchant` — Weapon Enchant
Tracks temporary weapon enchants (poisons, oils, sharpening stones).

**Settings:**
```lua
{
    ["Type"] = "wpnenchant",
    ["WpnEnchantType"] = "mainhand",   -- "mainhand" | "offhand"
}
```

**States:**
| State | Meaning |
|-------|---------|
| 1 (Show) | Enchant is active |
| 2 (Hide) | No enchant present |

**Use cases:**
- Rogue poison tracking
- Shaman weapon buff tracking
- Oils/sharpening stone reminders

---

## Utility Types

### `unitcooldown` — Track Unit Cooldowns
Tracks cooldowns used by other units (PvP).

**Settings:**
```lua
{
    ["Type"] = "unitcooldown",
    ["Name"] = "Ice Block; Divine Shield",
    ["Unit"] = "arena1",
}
```

**Use cases:**
- Arena: track enemy defensives
- PvP: track enemy trinket CD

---

### `value` — Numeric Value Display
Displays a numeric resource value.

**Settings:**
```lua
{
    ["Type"] = "value",
    ["ValueType"] = "health",      -- Resource type to display
    ["Unit"] = "player",
}
```

**Use cases:**
- Health/mana bar replacement
- Combo point display
- Resource monitoring

---

### `luavalue` — Custom Lua Value
Displays a value computed by custom Lua code.

**Settings:**
```lua
{
    ["Type"] = "luavalue",
    ["LuaCode"] = "return GetMoney()",   -- Lua code returning a number
}
```

---

### `uierror` — UI Error Tracking
Tracks specific UI error messages (red text).

**Settings:**
```lua
{
    ["Type"] = "uierror",
    ["Name"] = "Not enough mana",
}
```

---

## Version-Specific Types

### `losecontrol` — Loss of Control (Retail/Cata+)
Tracks when player loses control (stunned, feared, etc.). Not available in Classic Anniversary.

### `lightwell` — Lightwell (Cata/MoP)
Tracks Priest Lightwell charges. Not available in Classic Anniversary.
