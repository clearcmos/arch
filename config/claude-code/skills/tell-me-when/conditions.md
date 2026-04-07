# TellMeWhen Conditions Reference

Conditions control when icons and groups are shown/hidden. They are evaluated as boolean expressions with AND/OR logic and parentheses grouping.

## Condition Structure

```lua
["Conditions"] = {
    {
        ["Type"] = "CONDITION_TYPE",    -- Condition type (see categories below)
        ["Unit"] = "target",            -- Unit to check (if applicable)
        ["Name"] = "SpellName",         -- Spell/buff/item name (if applicable)
        ["Name2"] = "",                 -- Secondary name (for comparison conditions)
        ["Operator"] = ">=",            -- Comparison operator
        ["Level"] = 0,                  -- Value to compare against
        ["Checked"] = false,            -- "Only mine" modifier for aura conditions
        ["AndOr"] = "AND",              -- Logic with PREVIOUS condition ("AND" | "OR")
        ["PrtsBefore"] = 0,             -- Opening parentheses count before this condition
        ["PrtsAfter"] = 0,              -- Closing parentheses count after this condition
    },
    ["n"] = 1,                          -- Total number of conditions
}
```

## Operators

| Operator | Meaning |
|----------|---------|
| `==` | Equal to |
| `~=` | Not equal to |
| `>=` | Greater than or equal |
| `<=` | Less than or equal |
| `>` | Greater than |
| `<` | Less than |

## Boolean Conditions

For boolean conditions (EXISTS, ALIVE, COMBAT, MOUNTED, etc.):
- `["Level"] = 1` → condition should be TRUE (e.g., "is in combat")
- `["Level"] = 0` or absent → condition should be FALSE (e.g., "is NOT in combat")

## AND/OR Logic and Parentheses

Conditions are evaluated left-to-right. The first condition has no `AndOr` (or defaults to AND). Subsequent conditions specify `AndOr` to join with the previous result.

### Simple AND (all must be true)
```lua
{
    { ["Type"] = "COMBAT", ["Level"] = 1 },
    { ["Type"] = "EXISTS", ["Unit"] = "target", ["Level"] = 1 },
    ["n"] = 2,
}
-- Reads: In combat AND target exists
```

### Simple OR (any can be true)
```lua
{
    { ["Type"] = "STANCE", ["Level"] = 1 },
    { ["Type"] = "STANCE", ["Level"] = 3, ["AndOr"] = "OR" },
    ["n"] = 2,
}
-- Reads: In stance 1 OR in stance 3
```

### Complex: (A AND B) OR (C AND D)
```lua
{
    { ["Type"] = "A", ["PrtsBefore"] = 1 },
    { ["Type"] = "B", ["PrtsAfter"] = 1 },
    { ["Type"] = "C", ["AndOr"] = "OR", ["PrtsBefore"] = 1 },
    { ["Type"] = "D", ["PrtsAfter"] = 1 },
    ["n"] = 4,
}
```

### Complex: A AND (B OR C)
```lua
{
    { ["Type"] = "A" },
    { ["Type"] = "B", ["PrtsBefore"] = 1 },
    { ["Type"] = "C", ["AndOr"] = "OR", ["PrtsAfter"] = 1 },
    ["n"] = 3,
}
```

---

## Condition Categories

### Buffs & Debuffs

| Type | Description | Key Fields |
|------|-------------|------------|
| `BUFFDUR` | Buff duration remaining (sec) | Name, Unit, Operator, Level, Checked |
| `BUFFPERC` | Buff duration as % of max | Name, Unit, Operator, Level |
| `BUFFDURCOMP` | Compare durations of two buffs | Name, Name2, Unit |
| `BUFFSTACKS` | Buff stack count | Name, Unit, Operator, Level |
| `BUFFTOOLTIP` | Number from buff tooltip | Name, Unit, Operator, Level |
| `BUFFNUMBER` | Number of buffs matching name | Name, Unit, Operator, Level |
| `DEBUFFDUR` | Debuff duration remaining (sec) | Name, Unit, Operator, Level, Checked |
| `DEBUFFPERC` | Debuff duration as % of max | Name, Unit, Operator, Level |
| `DEBUFFDURCOMP` | Compare durations of two debuffs | Name, Name2, Unit |
| `DEBUFFSTACKS` | Debuff stack count | Name, Unit, Operator, Level |
| `DEBUFFTOOLTIP` | Number from debuff tooltip | Name, Unit, Operator, Level |
| `DEBUFFNUMBER` | Number of debuffs matching name | Name, Unit, Operator, Level |
| `MAINHAND` | Main hand enchant active | (boolean, use Level) |
| `OFFHAND` | Off hand enchant active | (boolean, use Level) |

**Example — Target has 3+ stacks of Sunder Armor:**
```lua
{
    ["Type"] = "DEBUFFSTACKS",
    ["Name"] = "Sunder Armor",
    ["Unit"] = "target",
    ["Operator"] = ">=",
    ["Level"] = 3,
    ["Checked"] = true,  -- Only mine
}
```

---

### Unit Attributes

| Type | Description | Key Fields |
|------|-------------|------------|
| `EXISTS` | Unit exists | Unit, Level (bool) |
| `ALIVE` | Unit is alive | Unit, Level (bool) |
| `COMBAT` | Unit in combat | Unit, Level (bool) |
| `VEHICLE` | Unit in vehicle | Unit, Level (bool) |
| `PVPFLAG` | Unit PvP flagged | Unit, Level (bool) |
| `REACT` | Unit reaction | Unit, Level (1=hostile, 2=friendly) |
| `ISPLAYER` | Unit is a player | Unit, Level (bool) |
| `SPEED` | Unit movement speed | Unit, Operator, Level |
| `RUNSPEED` | Unit run speed % | Unit, Operator, Level |
| `LIBRANGECHECK` | Distance to unit (yards) | Unit, Operator, Level |
| `UNITISUNIT` | Compare two units | Unit, Unit2 (Name field) |
| `NAME` | Unit name matches | Unit, Name |
| `NPCID` | Unit NPC ID | Unit, Level |
| `LEVEL` | Unit level | Unit, Operator, Level |
| `CREATURETYPE` | Unit creature type | Unit, Name (e.g. "Beast", "Humanoid") |
| `UNITRACE` | Unit race | Unit, Name |
| `THREATSCALED` | Threat % (scaled) | Unit, Operator, Level |
| `THREATRAW` | Threat % (raw) | Unit, Operator, Level |

**Example — Target exists and is hostile:**
```lua
{
    { ["Type"] = "EXISTS", ["Unit"] = "target", ["Level"] = 1 },
    { ["Type"] = "REACT", ["Unit"] = "target", ["Level"] = 1 },
    ["n"] = 2,
}
```

**Example — Target within 8-30 yards (range window):**
```lua
{
    { ["Type"] = "LIBRANGECHECK", ["Unit"] = "target", ["Operator"] = ">=", ["Level"] = 8 },
    { ["Type"] = "LIBRANGECHECK", ["Unit"] = "target", ["Operator"] = "<=", ["Level"] = 30 },
    ["n"] = 2,
}
```

---

### Spells

| Type | Description | Key Fields |
|------|-------------|------------|
| `SPELLCD` | Spell cooldown remaining (sec) | Name, Operator, Level |
| `SPELLCDCOMP` | Compare two spell cooldowns | Name, Name2 |
| `SPELLCHARGES` | Spell charges available | Name, Operator, Level |
| `SPELLCHARGETIME` | Time until next charge (sec) | Name, Operator, Level |
| `LASTCAST` | Last spell cast matches | Name |
| `SPELL_LEARNED` | Spell is learned | Name, Level (bool) |
| `SPELL_OVERRIDE` | Spell is overridden | Name, Level (bool) |
| `REACTIVE` | Spell is reactive/usable | Name, Level (bool) |
| `CURRENTSPELL` | Currently casting spell | Name, Level (bool) |
| `AUTOSPELL` | Pet autocast enabled | Name, Level (bool) |
| `OVERLAYED` | Spell has overlay glow | Name, Level (bool) |
| `MANAUSABLE` | Spell usable (has mana) | Name, Level (bool) |
| `SPELLCOST` | Spell resource cost | Name, Operator, Level |
| `SPELLRANGE` | Spell in range of unit | Name, Unit, Level (bool) |
| `GCD` | GCD remaining (sec) | Operator, Level |
| `ITEMCD` | Item cooldown remaining (sec) | Name, Operator, Level |
| `ITEMCDCOMP` | Compare two item cooldowns | Name, Name2 |
| `ITEMRANGE` | Item in range of unit | Name, Unit, Level (bool) |
| `ITEMINBAGS` | Item count in bags | Name, Operator, Level |
| `ITEMEQUIPPED` | Item is equipped | Name, Level (bool) |
| `ITEMSPELL` | Item spell usable | Name, Level (bool) |
| `MHSWING` | Main hand swing timer (sec) | Operator, Level |
| `OHSWING` | Off hand swing timer (sec) | Operator, Level |
| `TOTEM_ANY` | Any totem active | Level (bool) |
| `TOTEM1` | Fire totem slot timer (sec) | Operator, Level |
| `TOTEM2` | Earth totem slot timer (sec) | Operator, Level |
| `TOTEM3` | Water totem slot timer (sec) | Operator, Level |
| `TOTEM4` | Air totem slot timer (sec) | Operator, Level |
| `CASTING` | Unit is casting a spell | Unit, Name, Level (bool) |
| `CASTPERCENT` | Cast progress % | Unit, Operator, Level |
| `CASTCOUNT` | Times spell has been cast | Name, Operator, Level |

**Example — Spell CD less than 3 seconds remaining:**
```lua
{
    ["Type"] = "SPELLCD",
    ["Name"] = "Shield Wall",
    ["Operator"] = "<=",
    ["Level"] = 3,
}
```

**Example — Have 5+ of an item in bags:**
```lua
{
    ["Type"] = "ITEMINBAGS",
    ["Name"] = "Healthstone",
    ["Operator"] = ">=",
    ["Level"] = 5,
}
```

---

### Resources

| Type | Description | Key Fields |
|------|-------------|------------|
| `HEALTH` | Unit health % | Unit, Operator, Level |
| `HEALTH_ABS` | Unit health (absolute) | Unit, Operator, Level |
| `HEALTH_MAX` | Unit max health | Unit, Operator, Level |
| `DEFAULT` | Default power % (auto-detect) | Unit, Operator, Level |
| `DEFAULT_ABS` | Default power absolute | Unit, Operator, Level |
| `DEFAULT_MAX` | Default max power | Unit, Operator, Level |
| `MANA` | Mana % | Unit, Operator, Level |
| `MANA_ABS` | Mana absolute | Unit, Operator, Level |
| `ENERGY` | Energy % | Unit, Operator, Level |
| `RAGE` | Rage % | Unit, Operator, Level |
| `FOCUS` | Focus % | Unit, Operator, Level |
| `RUNIC_POWER` | Runic Power % | Unit, Operator, Level |
| `COMBO` | Combo points | Operator, Level |
| `SOUL_SHARDS` | Soul Shards | Operator, Level |
| `HOLY_POWER` | Holy Power | Operator, Level |
| `CHI` | Chi | Operator, Level |
| `RUNES` | Available runes | Operator, Level |
| `RUNESRECH` | Runes recharging | Operator, Level |

**Example — Health below 30%:**
```lua
{
    ["Type"] = "HEALTH",
    ["Unit"] = "player",
    ["Operator"] = "<=",
    ["Level"] = 30,
}
```

**Example — Have 5 combo points:**
```lua
{
    ["Type"] = "COMBO",
    ["Operator"] = ">=",
    ["Level"] = 5,
}
```

---

### Player Attributes

| Type | Description | Key Fields |
|------|-------------|------------|
| `MOUNTED` | Player is mounted | Level (bool) |
| `SWIMMING` | Player is swimming | Level (bool) |
| `RESTING` | Player is resting | Level (bool) |
| `STANCE` | Current stance/form number | Level (stance number) |
| `AUTOCAST` | Pet autocast enabled | Name, Level (bool) |
| `TRACKING` | Tracking type active | Name, Level (bool) |
| `BLIZZEQUIPSET` | Equipment set equipped | Name, Level (bool) |
| `ARMORREPAIR` | Armor durability % | Operator, Level |

**Stance/Form numbers (varies by class):**
- Warrior: 1=Battle, 2=Defensive, 3=Berserker
- Druid: 1=Bear, 2=Aquatic, 3=Cat, 4=Travel, 5=Moonkin/Tree
- Paladin: 1-3 (Devotion, Retribution, Concentration auras, etc.)
- Rogue: 1=Stealth

**Example — Player is in Defensive Stance:**
```lua
{
    ["Type"] = "STANCE",
    ["Level"] = 2,
}
```

---

### Player Combat Stats

| Type | Description |
|------|-------------|
| `STRENGTH` | Strength stat |
| `AGILITY` | Agility stat |
| `STAMINA` | Stamina stat |
| `INTELLECT` | Intellect stat |
| `SPIRIT` | Spirit stat |
| `MELEECRIT` | Melee crit % |
| `MELEEHASTE` | Melee haste % |
| `MELEEAP` | Melee attack power |
| `RANGEAP` | Ranged attack power |
| `SPELLDMG` | Spell damage |
| `MANAREGEN` | Mana regen (OOC) |
| `MANAREGENCOMBAT` | Mana regen (in combat) |
| `EXPERTISE` | Expertise rating |

All use: `Operator, Level`

---

### Talents

| Type | Description | Key Fields |
|------|-------------|------------|
| `UNITSPEC` | Unit's specialization | Unit, Level |
| `SPEC` | Player's active spec | Level (1=Primary, 2=Secondary) |
| `TREE` | Primary talent tree | Level (tree index) |
| `TALENTLEARNED` | Talent is learned | Name, Level (bool) |
| `PTSINTAL` | Points in talent | Name, Operator, Level |
| `GLYPH` | Glyph equipped (Wrath) | Name, Level (bool) |

**Example — Has 5 points in a specific talent:**
```lua
{
    ["Type"] = "PTSINTAL",
    ["Name"] = "Improved Shield Block",
    ["Operator"] = ">=",
    ["Level"] = 5,
}
```

---

### Location

| Type | Description | Key Fields |
|------|-------------|------------|
| `GROUPSIZE` | Group/raid size | Operator, Level |
| `ZONEPVP` | Zone PvP type | Level |
| `LOC_CONTINENT` | Current continent | Name |
| `LOC_ZONE` | Current zone name | Name |
| `LOC_SUBZONE` | Current subzone name | Name |

**Example — In a 5-man group:**
```lua
{
    ["Type"] = "GROUPSIZE",
    ["Operator"] = "<=",
    ["Level"] = 5,
}
```

---

### Boss Mods

| Type | Description | Key Fields |
|------|-------------|------------|
| `BIGWIGS_TIMER` | BigWigs timer active | Name, Operator, Level |
| `BIGWIGS_ENGAGED` | BigWigs boss engaged | Name, Level (bool) |
| `DBM_TIMER` | DBM timer active | Name, Operator, Level |
| `DBM_ENGAGED` | DBM boss engaged | Name, Level (bool) |

---

### Miscellaneous

| Type | Description | Key Fields |
|------|-------------|------------|
| `ICON` | Another TMW icon's state | Icon (GUID), Level |
| `ICONSHOWNTME` | Icon shown duration (sec) | Icon (GUID), Operator, Level |
| `ICONHIDDENTME` | Icon hidden duration (sec) | Icon (GUID), Operator, Level |
| `MOUSEOVER` | Frame has mouseover | Level (bool) |
| `WEEKDAY` | Day of the week | Level (1=Sun, 7=Sat) |
| `TIMEOFDAY` | Time of day (hours) | Operator, Level |
| `QUESTCOMPLETE` | Quest completed | Level (quest ID) |
| `MACRO` | Macro condition string | Name (macro text) |
| `LUA` | Custom Lua expression | Name (Lua code returning bool) |

**Example — Custom Lua condition:**
```lua
{
    ["Type"] = "LUA",
    ["Name"] = "return UnitAffectingCombat('player') and UnitHealthMax('target') > 10000",
}
```

**Example — Macro condition (WoW macro syntax):**
```lua
{
    ["Type"] = "MACRO",
    ["Name"] = "[swimming][flying]",
}
```

---

## Common Condition Patterns

### In Combat + Target Exists + Target is Hostile
```lua
["Conditions"] = {
    { ["Type"] = "COMBAT", ["Level"] = 1 },
    { ["Type"] = "EXISTS", ["Unit"] = "target", ["Level"] = 1 },
    { ["Type"] = "REACT", ["Unit"] = "target", ["Level"] = 1 },
    ["n"] = 3,
}
```

### Only When Specific Buff is NOT Active
```lua
["Conditions"] = {
    { ["Type"] = "BUFFDUR", ["Name"] = "Shield Block", ["Unit"] = "player", ["Operator"] = "==", ["Level"] = 0 },
    ["n"] = 1,
}
```

### Health Below Threshold (Emergency Alert)
```lua
["Conditions"] = {
    { ["Type"] = "HEALTH", ["Unit"] = "player", ["Operator"] = "<=", ["Level"] = 20 },
    { ["Type"] = "COMBAT", ["Level"] = 1 },
    ["n"] = 2,
}
```

### In a Raid AND Not Mounted
```lua
["Conditions"] = {
    { ["Type"] = "GROUPSIZE", ["Operator"] = ">", ["Level"] = 5 },
    { ["Type"] = "MOUNTED", ["Level"] = 0 },  -- Level 0 = NOT mounted
    ["n"] = 2,
}
```

### Target is a Boss (high-level mob)
```lua
["Conditions"] = {
    { ["Type"] = "LEVEL", ["Unit"] = "target", ["Operator"] = "==", ["Level"] = -1 },  -- -1 = boss level
    ["n"] = 1,
}
```
