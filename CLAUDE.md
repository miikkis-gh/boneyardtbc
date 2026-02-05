# TBC Dungeon & Reputation Optimizer — WoW Addon

## Claude Code Instructions

Build a World of Warcraft addon for **Burning Crusade Classic Anniversary Edition** (client version 2.5.x) called **"DungeonOptimizer"**. This addon helps players plan and track an optimal dungeon-grinding route from level 58–70, maximizing both XP and faction reputation to unlock heroic dungeon keys and complete the Karazhan attunement.

The addon is inspired by https://tbc.rtw.dev/dungeon-optimizer (a web tool) and Myro's leveling spreadsheet (based on BiosparksTV's guide). All data tables and route logic are provided below.

---

## 1. PROJECT STRUCTURE

```
DungeonOptimizer/
├── DungeonOptimizer.toc
├── Core.lua                 -- Addon initialization, saved variables, slash commands
├── Data.lua                 -- All static data tables (dungeons, factions, quests, routes)
├── Optimizer.lua            -- Route calculation / optimization engine
├── Tracker.lua              -- Live tracking of player level, rep, attunement progress
├── UI.lua                   -- Main frame, panels, and all UI elements
├── Widgets.lua              -- Reusable UI components (dropdowns, progress bars, checkboxes)
└── Libs/                    -- (optional) Embed AceAddon/AceDB if desired, otherwise pure Lua
```

### 1.1 TOC File — `DungeonOptimizer.toc`

```toc
## Interface: 20504
## Title: Dungeon Optimizer
## Notes: TBC dungeon leveling & reputation route optimizer
## Author: miikkis
## Version: 1.0.0
## SavedVariables: DungeonOptimizerDB

Data.lua
Core.lua
Optimizer.lua
Tracker.lua
Widgets.lua
UI.lua
```

> **Important**: TBC Classic Anniversary uses interface version `20504` (2.5.4). Verify against the live client and adjust if needed. You can check in-game with `/run print((select(4, GetBuildInfo())))`.

---

## 2. STATIC DATA TABLES — `Data.lua`

This is the most critical file. All numbers below come from verified community sources (Myro's spreadsheet, BiosparksTV guide, Wowhead TBC).

### 2.1 Faction IDs & Rep Thresholds

```lua
DungeonOptimizer.FACTIONS = {
    HONOR_HOLD    = { id = 946, name = "Honor Hold",          side = "Alliance" },
    THRALLMAR     = { id = 947, name = "Thrallmar",            side = "Horde" },
    CENARION_EXP  = { id = 942, name = "Cenarion Expedition",  side = "Both" },
    CONSORTIUM    = { id = 933, name = "The Consortium",        side = "Both" },
    KEEPERS_TIME  = { id = 989, name = "Keepers of Time",      side = "Both" },
    LOWER_CITY    = { id = 1011, name = "Lower City",           side = "Both" },
    SHATAR        = { id = 935, name = "The Sha'tar",           side = "Both" },
}

-- Standard Blizzard rep thresholds (cumulative from Neutral 0)
DungeonOptimizer.REP_LEVELS = {
    { name = "Neutral",   min = 0,     max = 2999 },
    { name = "Friendly",  min = 3000,  max = 5999 },
    { name = "Honored",   min = 6000,  max = 11999 },
    { name = "Revered",   min = 12000, max = 20999 },
    { name = "Exalted",   min = 21000, max = 42999 },
}

-- Shorthand thresholds from Neutral 0
DungeonOptimizer.REP_THRESHOLDS = {
    Neutral  = 0,
    Friendly = 3000,
    Honored  = 6000,
    Revered  = 12000,
    Exalted  = 21000,
}
```

### 2.2 Dungeon Data

Each dungeon entry contains: faction key, zone, rep per normal clear, rep per heroic clear, minimum recommended level, maximum effective level, and the rep cap for normal mode (the standing at which normal trash/bosses stop giving rep — note: bosses often give rep beyond this cap but trash does not).

```lua
DungeonOptimizer.DUNGEONS = {
    BLOOD_FURNACE = {
        name = "The Blood Furnace",
        faction = "HONOR_HOLD", -- or THRALLMAR for Horde
        zone = "Hellfire Peninsula",
        repPerClear = 750,
        repPerClearHeroic = 1700,
        minLevel = 58,
        maxLevel = 63,
        normalRepCap = "Honored", -- normal trash stops giving rep at Honored
    },
    HELLFIRE_RAMPARTS = {
        name = "Hellfire Ramparts",
        faction = "HONOR_HOLD",
        zone = "Hellfire Peninsula",
        repPerClear = 600,
        repPerClearHeroic = 1700,
        minLevel = 58,
        maxLevel = 62,
        normalRepCap = "Honored",
    },
    SHATTERED_HALLS = {
        name = "The Shattered Halls",
        faction = "HONOR_HOLD",
        zone = "Hellfire Peninsula",
        repPerClear = 1604,
        repPerClearHeroic = 2400,
        minLevel = 67,
        maxLevel = 70,
        normalRepCap = nil, -- gives rep all the way to Exalted
    },
    SLAVE_PENS = {
        name = "The Slave Pens",
        faction = "CENARION_EXP",
        zone = "Zangarmarsh",
        repPerClear = 915,
        repPerClearHeroic = 1700,
        minLevel = 60,
        maxLevel = 65,
        normalRepCap = "Honored",
    },
    UNDERBOG = {
        name = "The Underbog",
        faction = "CENARION_EXP",
        zone = "Zangarmarsh",
        repPerClear = 900,
        repPerClearHeroic = 1700,
        minLevel = 61,
        maxLevel = 66,
        normalRepCap = "Honored",
    },
    STEAMVAULT = {
        name = "The Steamvault",
        faction = "CENARION_EXP",
        zone = "Zangarmarsh",
        repPerClear = 1796,
        repPerClearHeroic = 2400,
        minLevel = 67,
        maxLevel = 70,
        normalRepCap = nil,
    },
    MANA_TOMBS = {
        name = "Mana-Tombs",
        faction = "CONSORTIUM",
        zone = "Terokkar Forest",
        repPerClear = 990,
        repPerClearHeroic = 1700,
        minLevel = 64,
        maxLevel = 68,
        normalRepCap = "Honored",
    },
    AUCHENAI_CRYPTS = {
        name = "Auchenai Crypts",
        faction = "LOWER_CITY",
        zone = "Terokkar Forest",
        repPerClear = 1050,
        repPerClearHeroic = 1700,
        minLevel = 63,
        maxLevel = 67,
        normalRepCap = "Honored",
    },
    SETHEKK_HALLS = {
        name = "Sethekk Halls",
        faction = "LOWER_CITY",
        zone = "Terokkar Forest",
        repPerClear = 1139,
        repPerClearHeroic = 1700,
        minLevel = 65,
        maxLevel = 70,
        normalRepCap = nil,
    },
    SHADOW_LABYRINTH = {
        name = "Shadow Labyrinth",
        faction = "LOWER_CITY",
        zone = "Terokkar Forest",
        repPerClear = 2012,
        repPerClearHeroic = 2400,
        minLevel = 67,
        maxLevel = 70,
        normalRepCap = nil,
    },
    OLD_HILLSBRAD = {
        name = "Old Hillsbrad Foothills",
        faction = "KEEPERS_TIME",
        zone = "Caverns of Time",
        repPerClear = 900,
        repPerClearHeroic = 1700,
        minLevel = 66,
        maxLevel = 70,
        normalRepCap = "Honored",
    },
    BLACK_MORASS = {
        name = "The Black Morass",
        faction = "KEEPERS_TIME",
        zone = "Caverns of Time",
        repPerClear = 1110,
        repPerClearHeroic = 1700,
        minLevel = 68,
        maxLevel = 70,
        normalRepCap = nil,
    },
    BOTANICA = {
        name = "The Botanica",
        faction = "SHATAR",
        zone = "Netherstorm",
        repPerClear = 1270,
        repPerClearHeroic = 1900,
        minLevel = 68,
        maxLevel = 70,
        normalRepCap = nil,
    },
    MECHANAR = {
        name = "The Mechanar",
        faction = "SHATAR",
        zone = "Netherstorm",
        repPerClear = 1200,
        repPerClearHeroic = 1900,
        minLevel = 67,
        maxLevel = 70,
        normalRepCap = nil,
    },
    ARCATRAZ = {
        name = "The Arcatraz",
        faction = "SHATAR",
        zone = "Netherstorm",
        repPerClear = 1600,
        repPerClearHeroic = 2400,
        minLevel = 68,
        maxLevel = 70,
        normalRepCap = nil,
    },
}
```

### 2.3 XP Per Dungeon Clear (Approximate)

These are average XP values per full clear at the recommended level range. They decrease as you outlevel the dungeon.

```lua
DungeonOptimizer.DUNGEON_XP = {
    BLOOD_FURNACE    = { base = 45000, levelRange = {58, 63} },
    HELLFIRE_RAMPARTS = { base = 38000, levelRange = {58, 62} },
    SLAVE_PENS       = { base = 52000, levelRange = {60, 65} },
    UNDERBOG         = { base = 52000, levelRange = {61, 66} },
    MANA_TOMBS       = { base = 55000, levelRange = {64, 68} },
    SETHEKK_HALLS    = { base = 58000, levelRange = {65, 70} },
    SHADOW_LABYRINTH = { base = 62000, levelRange = {67, 70} },
    OLD_HILLSBRAD    = { base = 55000, levelRange = {66, 70} },
    BLACK_MORASS     = { base = 52000, levelRange = {68, 70} },
    STEAMVAULT       = { base = 60000, levelRange = {67, 70} },
    SHATTERED_HALLS  = { base = 62000, levelRange = {67, 70} },
    BOTANICA         = { base = 60000, levelRange = {68, 70} },
    MECHANAR         = { base = 55000, levelRange = {67, 70} },
    ARCATRAZ         = { base = 65000, levelRange = {68, 70} },
    AUCHENAI_CRYPTS  = { base = 53000, levelRange = {63, 67} },
}
```

### 2.4 XP Required Per Level

```lua
DungeonOptimizer.XP_TO_LEVEL = {
    [58] = 209800,
    [59] = 221200,
    [60] = 290000,  -- TBC leveling curve kicks in
    [61] = 317000,
    [62] = 349000,
    [63] = 386000,
    [64] = 428000,
    [65] = 475000,
    [66] = 527000,
    [67] = 586000,
    [68] = 650000,
    [69] = 720000,
}
-- Total XP 60-70: ~4,928,000
```

### 2.5 Myro's Optimized Route (Alliance)

This is the default "Balanced" route. Store as an ordered list of steps. Each step is one of: `dungeon`, `quest`, `travel`, `checkpoint`.

```lua
DungeonOptimizer.ROUTES = {}

DungeonOptimizer.ROUTES.ALLIANCE_BALANCED = {
    -- PHASE 1: Blood Furnace (lvl 60-61)
    { type = "travel",  step = 1,  text = "Enter Dark Portal, set Hearth to Honor Hold", zone = "Hellfire Peninsula" },
    { type = "dungeon", step = 2,  dungeon = "BLOOD_FURNACE", runs = 12, repGoal = "Honored",
      faction = "HONOR_HOLD", note = "750 rep/clear, 12 runs to Honored" },

    -- PHASE 2: Slave Pens (lvl 61-65)
    { type = "travel",  step = 3,  text = "Run to Zangarmarsh, grab flight path" },
    { type = "travel",  step = 4,  text = "Run to Shattrath City, set Hearth", note = "Only trainers in Outland" },
    { type = "quest",   step = 5,  action = "Accept",  quest = "A'dal",                      npc = "Haggard War Veteran", zone = "Shattrath City" },
    { type = "quest",   step = 6,  action = "Turn In", quest = "A'dal",                      npc = "A'dal" },
    { type = "quest",   step = 7,  action = "Accept",  quest = "City of Light",              npc = "Khadgar" },
    { type = "quest",   step = 8,  action = "Turn In", quest = "City of Light",              npc = "Khadgar" },
    { type = "quest",   step = 9,  action = "Accept",  quest = "Allegiance to the Aldor",    npc = "Khadgar", note = "Choose Aldor OR Scryers" },
    { type = "quest",   step = 10, action = "Turn In", quest = "Allegiance to the Aldor/Scryers", npc = "Khadgar" },
    { type = "travel",  step = 11, text = "Fly to Telredor (Zangarmarsh)" },
    { type = "dungeon", step = 12, dungeon = "SLAVE_PENS", runs = -1, repGoal = "Honored",
      faction = "CENARION_EXP", levelGoal = 65, note = "915 rep/clear, stay until level 65" },

    -- PHASE 3: Mana-Tombs (lvl 65-66)
    { type = "travel",  step = 13, text = "Hearth to Shattrath" },
    { type = "travel",  step = 14, text = "Run to Allerian Stronghold, grab flight path" },
    { type = "dungeon", step = 15, dungeon = "MANA_TOMBS", runs = -1, repGoal = "Honored",
      faction = "CONSORTIUM", levelGoal = 66, note = "990 rep/clear, stay until level 66" },

    -- PHASE 4: Sethekk Halls (lvl 66-68)
    { type = "dungeon", step = 16, dungeon = "SETHEKK_HALLS", runs = 8, repGoal = "Honored",
      faction = "LOWER_CITY", note = "1139 rep/clear, 8 runs to Honored" },
    { type = "quest",   step = 17, action = "Collect", quest = "Shadow Labyrinth Key",
      note = "Loot from chest behind last boss of Sethekk Halls" },

    -- PHASE 5: Karazhan Attunement Start (lvl 68)
    { type = "travel",  step = 18, text = "Portal to Stormwind City" },
    { type = "travel",  step = 19, text = "Fly to Darkshire" },
    { type = "travel",  step = 20, text = "Run to Karazhan" },
    { type = "quest",   step = 21, action = "Accept",   quest = "Arcane Disturbances",       npc = "Archmage Alturus", zone = "Deadwind Pass" },
    { type = "quest",   step = 22, action = "Accept",   quest = "Restless Activity",         npc = "Archmage Alturus" },
    { type = "quest",   step = 23, action = "Complete", quest = "Arcane Disturbances" },
    { type = "quest",   step = 24, action = "Complete", quest = "Restless Activity" },
    { type = "quest",   step = 25, action = "Turn In",  quest = "Arcane Disturbances",       npc = "Archmage Alturus" },
    { type = "quest",   step = 26, action = "Turn In",  quest = "Restless Activity",         npc = "Archmage Alturus" },
    { type = "quest",   step = 27, action = "Accept",   quest = "Contact from Dalaran",      npc = "Archmage Alturus" },
    { type = "travel",  step = 28, text = "Fly to Southshore" },
    { type = "quest",   step = 29, action = "Turn In",  quest = "Contact from Dalaran",      npc = "Archmage Cedric", zone = "Alterac Mountains" },
    { type = "quest",   step = 30, action = "Accept",   quest = "Khadgar",                   npc = "Archmage Cedric" },
    { type = "travel",  step = 31, text = "Hearth to Shattrath" },
    { type = "quest",   step = 32, action = "Turn In",  quest = "Khadgar",                   npc = "Khadgar", zone = "Shattrath City" },
    { type = "quest",   step = 33, action = "Accept",   quest = "Entry Into Karazhan",       npc = "Khadgar" },
    { type = "travel",  step = 34, text = "Portal to Theramore, fly to Gadgetzan" },
    { type = "travel",  step = 35, text = "Run to Caverns of Time" },

    -- PHASE 6: Caverns of Time dungeons (lvl 68-69)
    { type = "quest",   step = 36, action = "Accept",   quest = "The Caverns of Time",       npc = "Andormu", zone = "Tanaris" },
    { type = "quest",   step = 37, action = "Complete", quest = "The Caverns of Time" },
    { type = "quest",   step = 38, action = "Turn In",  quest = "The Caverns of Time",       npc = "Andormu" },
    { type = "quest",   step = 39, action = "Accept",   quest = "Old Hillsbrad",             npc = "Andormu" },
    { type = "dungeon", step = 40, dungeon = "OLD_HILLSBRAD", runs = 1,
      faction = "KEEPERS_TIME", note = "1 clear, complete quests inside" },
    -- Old Hillsbrad internal quest chain (Taretha's Diversion → Escape from Durnholde → Return to Andormu)
    { type = "quest",   step = 41, action = "Accept",   quest = "Taretha's Diversion",       npc = "Erozion" },
    { type = "quest",   step = 42, action = "Complete", quest = "Taretha's Diversion" },
    { type = "quest",   step = 43, action = "Turn In",  quest = "Taretha's Diversion",       npc = "Thrall" },
    { type = "quest",   step = 44, action = "Accept",   quest = "Escape from Durnholde",     npc = "Thrall" },
    { type = "quest",   step = 45, action = "Complete", quest = "Escape from Durnholde" },
    { type = "quest",   step = 46, action = "Turn In",  quest = "Escape from Durnholde",     npc = "Erozion" },
    { type = "quest",   step = 47, action = "Accept",   quest = "Return to Andormu",         npc = "Erozion" },
    { type = "quest",   step = 48, action = "Turn In",  quest = "Return to Andormu",         npc = "Andormu" },
    { type = "quest",   step = 49, action = "Accept",   quest = "The Black Morass",          npc = "Andormu" },
    { type = "dungeon", step = 50, dungeon = "BLACK_MORASS", runs = 7, repGoal = "Revered",
      faction = "KEEPERS_TIME", note = "1110 rep/clear, 6-7 runs to Revered" },
    -- Black Morass internal quests
    { type = "quest",   step = 51, action = "Complete", quest = "The Black Morass" },
    { type = "quest",   step = 52, action = "Accept",   quest = "The Opening of the Dark Portal", npc = "Sa'at" },
    { type = "quest",   step = 53, action = "Complete", quest = "The Opening of the Dark Portal" },
    { type = "quest",   step = 54, action = "Turn In",  quest = "The Opening of the Dark Portal", npc = "Sa'at" },
    { type = "quest",   step = 55, action = "Accept",   quest = "Hero of the Brood",         npc = "Sa'at" },
    { type = "quest",   step = 56, action = "Turn In",  quest = "Hero of the Brood",         npc = "Andormu" },

    -- PHASE 7: Shadow Labyrinth (lvl 69)
    { type = "travel",  step = 57, text = "Hearth to Shattrath, fly to Allerian Stronghold" },
    { type = "dungeon", step = 58, dungeon = "SHADOW_LABYRINTH", runs = 6, repGoal = "Revered",
      faction = "LOWER_CITY", note = "2012 rep/clear, 6 runs to Revered" },

    -- PHASE 8: Steamvault + Kara attunement cont. (lvl 69-70)
    { type = "travel",  step = 59, text = "Hearth to Shattrath" },
    { type = "quest",   step = 60, action = "Turn In",  quest = "Entry Into Karazhan",       npc = "Khadgar" },
    { type = "quest",   step = 61, action = "Accept",   quest = "The Second and Third Fragments", npc = "Khadgar" },
    { type = "travel",  step = 62, text = "Fly to Telredor (Zangarmarsh)" },
    { type = "dungeon", step = 63, dungeon = "STEAMVAULT", runs = 7, repGoal = "Revered",
      faction = "CENARION_EXP", note = "1796 rep/clear, 7 runs to Revered" },

    -- PHASE 9: Shattered Halls Key + Dungeon
    { type = "travel",  step = 64, text = "Run to the Black Temple (Shadowmoon Valley)" },
    { type = "quest",   step = 65, action = "Kill",     quest = "Kill Smith Gorlunk for quest item", zone = "Shadowmoon Valley" },
    { type = "quest",   step = 66, action = "Accept",   quest = "Entry Into the Citadel" },
    { type = "travel",  step = 67, text = "Fly to Honor Hold" },
    { type = "quest",   step = 68, action = "Turn In",  quest = "Entry Into the Citadel",    npc = "Force Commander Danath Trollbane" },
    { type = "quest",   step = 69, action = "Accept",   quest = "Grand Master Dumphry",      npc = "Force Commander Danath Trollbane" },
    { type = "quest",   step = 70, action = "Turn In",  quest = "Grand Master Dumphry",      npc = "Dumphry" },
    { type = "quest",   step = 71, action = "Accept",   quest = "Dumphry's Request",         npc = "Dumphry" },
    { type = "quest",   step = 72, action = "Turn In",  quest = "Dumphry's Request",         npc = "Dumphry" },
    { type = "quest",   step = 73, action = "Accept",   quest = "Hotter than Hell",          npc = "Dumphry" },
    { type = "quest",   step = 74, action = "Complete", quest = "Hotter than Hell" },
    { type = "quest",   step = 75, action = "Turn In",  quest = "Hotter than Hell",          npc = "Dumphry" },
    { type = "dungeon", step = 76, dungeon = "SHATTERED_HALLS", runs = 8, repGoal = "Revered",
      faction = "HONOR_HOLD", note = "1604 rep/clear, run until Revered" },

    { type = "checkpoint", step = 77, text = "Level 70, 4/5 Heroic Keys, 2/3 Kara Fragments" },

    -- PHASE 10: Flying + Arcatraz Key Chain
    { type = "travel",  step = 78, text = "Fly to Wildhammer Stronghold, buy flying training" },
    { type = "travel",  step = 79, text = "Fly to Area 52 (Netherstorm)" },
    { type = "quest",   step = 80, action = "Accept",   quest = "Assisting the Consortium",       npc = "Anchorite Karja", zone = "Netherstorm" },
    { type = "quest",   step = 81, action = "Turn In",  quest = "Assisting the Consortium",       npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 82, action = "Accept",   quest = "Consortium Crystal Collection",  npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 83, action = "Complete", quest = "Consortium Crystal Collection",  note = "Kill named boss at Arklon Ruins" },
    { type = "quest",   step = 84, action = "Turn In",  quest = "Consortium Crystal Collection",  npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 85, action = "Accept",   quest = "A Heap of Ethereals",            npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 86, action = "Complete", quest = "A Heap of Ethereals" },
    { type = "quest",   step = 87, action = "Turn In",  quest = "A Heap of Ethereals",            npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 88, action = "Accept",   quest = "Warp-Rider Nesaad",              npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 89, action = "Complete", quest = "Warp-Rider Nesaad" },
    { type = "quest",   step = 90, action = "Turn In",  quest = "Warp-Rider Nesaad",              npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 91, action = "Accept",   quest = "Request for Assistance",         npc = "Nether-Stalker Khay'ji" },
    { type = "quest",   step = 92, action = "Turn In",  quest = "Request for Assistance",         npc = "Gahruj", zone = "Eco-Dome Midrealm" },
    { type = "quest",   step = 93, action = "Accept",   quest = "Rightful Repossession",          npc = "Gahruj" },
    { type = "quest",   step = 94, action = "Complete", quest = "Rightful Repossession",          note = "Boxes at Manaforge Duro" },
    { type = "quest",   step = 95, action = "Turn In",  quest = "Rightful Repossession",          npc = "Gahruj" },
    { type = "quest",   step = 96, action = "Accept",   quest = "An Audience with the Prince",    npc = "Gahruj" },
    { type = "quest",   step = 97, action = "Turn In",  quest = "An Audience with the Prince",    npc = "Image of Nexus-Prince Haramad" },
    { type = "quest",   step = 98, action = "Accept",   quest = "Triangulation Point One" },
    { type = "quest",   step = 99, action = "Complete", quest = "Triangulation Point One",        note = "NE of Manaforge Ultris" },
    { type = "quest",   step = 100, action = "Turn In", quest = "Triangulation Point One",        npc = "Dealer Hazzin" },
    { type = "quest",   step = 101, action = "Accept",  quest = "Triangulation Point Two" },
    { type = "quest",   step = 102, action = "Complete",quest = "Triangulation Point Two",        note = "Near Manaforge Ara" },
    { type = "quest",   step = 103, action = "Turn In", quest = "Triangulation Point Two",        npc = "Wind Trader Tuluman" },
    { type = "quest",   step = 104, action = "Accept",  quest = "Full Triangle" },
    { type = "quest",   step = 105, action = "Complete",quest = "Full Triangle",                  note = "Kill named boss, loot crystal" },
    { type = "quest",   step = 106, action = "Turn In", quest = "Full Triangle",                  npc = "Image of Nexus-Prince Haramad" },
    { type = "quest",   step = 107, action = "Accept",  quest = "Special Delivery to Shattrath City" },
    { type = "travel",  step = 108, text = "Hearth to Shattrath" },
    { type = "quest",   step = 109, action = "Turn In", quest = "Special Delivery to Shattrath City", npc = "A'dal" },
    { type = "quest",   step = 110, action = "Accept",  quest = "How to Break into Arcatraz",     npc = "A'dal" },
    { type = "travel",  step = 111, text = "Fly to Area 52" },
    { type = "dungeon", step = 112, dungeon = "BOTANICA", runs = 1, note = "1 clear for attunement" },
    { type = "dungeon", step = 113, dungeon = "MECHANAR", runs = 1, note = "1 clear for attunement" },
    { type = "travel",  step = 114, text = "Hearth to Shattrath" },
    { type = "quest",   step = 115, action = "Turn In", quest = "How to Break into Arcatraz",     npc = "A'dal" },
    { type = "travel",  step = 116, text = "Fly to Area 52" },
    { type = "dungeon", step = 117, dungeon = "ARCATRAZ", runs = 1,
      note = "1 clear for Kara key fragment (don't need to finish)" },

    -- PHASE 11: Finish Karazhan Attunement
    { type = "travel",  step = 118, text = "Hearth to Shattrath" },
    { type = "quest",   step = 119, action = "Turn In", quest = "The Second and Third Fragments", npc = "Khadgar" },
    { type = "quest",   step = 120, action = "Accept",  quest = "The Master's Touch",             npc = "Khadgar" },
    { type = "travel",  step = 121, text = "Portal to Theramore, fly to Gadgetzan, run to Caverns of Time" },
    { type = "dungeon", step = 122, dungeon = "BLACK_MORASS", runs = 1, note = "1 clear for Master's Touch" },
    { type = "quest",   step = 123, action = "Complete",quest = "The Master's Touch",             npc = "Medivh" },
    { type = "quest",   step = 124, action = "Turn In", quest = "The Master's Touch",             npc = "Medivh" },
    { type = "quest",   step = 125, action = "Accept",  quest = "Return to Khadgar",              npc = "Medivh" },
    { type = "travel",  step = 126, text = "Hearth to Shattrath" },
    { type = "quest",   step = 127, action = "Turn In", quest = "Return to Khadgar",              npc = "Khadgar" },
    { type = "quest",   step = 128, action = "Accept",  quest = "The Violet Eye",                 npc = "Khadgar" },
    { type = "travel",  step = 129, text = "Portal to Stormwind, fly to Darkshire, run to Karazhan" },
    { type = "quest",   step = 130, action = "Turn In", quest = "The Violet Eye",                 npc = "Archmage Alturus" },

    { type = "checkpoint", step = 131, text = "Level 70, 12/15 Heroics, Flying, Karazhan Attuned!" },

    -- BONUS
    { type = "dungeon", step = 132, dungeon = "BOTANICA", runs = -1, repGoal = "Revered",
      faction = "SHATAR", note = "Farm Botanica until Revered with Sha'tar (bonus)" },
}
```

> **Horde Route**: Create `ROUTES.HORDE_BALANCED` by swapping: Honor Hold → Thrallmar, Alliance cities → Horde cities (Orgrimmar, Thrallmar, Zabra'jin, Swamprat Post, Stonebreaker Hold, Shadowmoon Village), Dumphry quest chain → Rohok quest chain, Darkshire → Stonard, Theramore → use Orgrimmar portal. The dungeon order and rep targets remain identical.

---

## 3. OPTIMIZATION ENGINE — `Optimizer.lua`

### 3.1 Two Modes

1. **Balanced** (default): Follows Myro's route — optimizes XP + Rep together. Uses the fixed route from `ROUTES` but adjusts run counts dynamically based on starting level and current rep.

2. **Leveling**: Maximizes XP/hour only. Picks whichever dungeon gives the most XP at the player's current level, ignoring rep targets. Simple greedy algorithm.

### 3.2 Core Algorithm (Balanced Mode)

```
function CalculateRoute(startLevel, faction, race, repGoals, options):
    humanBonus = (race == "Human") and 1.10 or 1.0
    route = deepcopy(ROUTES[faction .. "_BALANCED"])
    currentLevel = startLevel
    currentXP = 0
    currentRep = { read from player or from user input }
    totalRuns = 0

    for each step in route:
        if step.type == "dungeon":
            dungeon = DUNGEONS[step.dungeon]
            repPerRun = dungeon.repPerClear * humanBonus
            targetRep = REP_THRESHOLDS[step.repGoal] or nil

            if step.runs == -1:  -- "stay until level/rep goal"
                runs = 0
                while (currentLevel < step.levelGoal OR currentRep[faction] < targetRep):
                    runs = runs + 1
                    currentRep[faction] += repPerRun (capped at normalRepCap if applicable)
                    currentXP += calculateDungeonXP(dungeon, currentLevel)
                    if currentXP >= XP_TO_LEVEL[currentLevel]:
                        currentXP -= XP_TO_LEVEL[currentLevel]
                        currentLevel += 1
                step.calculatedRuns = runs
            else:
                -- Fixed run count, but can skip if rep already met
                neededRep = max(0, targetRep - currentRep[faction])
                runs = ceil(neededRep / repPerRun)
                runs = max(runs, step.runs)  -- don't go below guide minimum
                ... update rep/xp/level
                step.calculatedRuns = runs

            totalRuns += step.calculatedRuns

    return route, totalRuns, currentLevel, currentRep
```

### 3.3 Rep Calculation Helpers

```lua
-- Apply Human racial bonus
function ApplyRacialBonus(rep, race)
    if race == "Human" then return math.floor(rep * 1.10) end
    return rep
end

-- Check if normal mode still gives rep
function CanGainNormalRep(dungeonKey, currentStanding)
    local cap = DUNGEONS[dungeonKey].normalRepCap
    if not cap then return true end
    return currentStanding < REP_THRESHOLDS[cap]
end
```

---

## 4. LIVE TRACKER — `Tracker.lua`

### 4.1 WoW API Calls to Use

Read all character info automatically — no manual input needed when in-game:

```lua
-- Player info
UnitLevel("player")                          -- Current level
UnitRace("player")                           -- Race name
UnitFactionGroup("player")                   -- "Alliance" or "Horde"
UnitXP("player")                             -- Current XP
UnitXPMax("player")                          -- XP needed for next level

-- Faction reputation
-- Use GetFactionInfoByID(factionID) which returns:
--   name, description, standingId, barMin, barMax, barValue, ...
-- standingId: 1=Hated, 2=Hostile, 3=Unfriendly, 4=Neutral, 5=Friendly, 6=Honored, 7=Revered, 8=Exalted
-- The actual rep value relative to Neutral 0 is:
--   barValue - barMin + cumulativeForStanding

-- Helper to get total rep from Neutral 0:
function GetTotalRep(factionID)
    local name, _, standingId, barMin, barMax, barValue = GetFactionInfoByID(factionID)
    if not name then return 0 end
    -- barValue is the current value within the standing bracket
    -- We need absolute rep from Neutral 0
    local standingBottoms = { [-2] = -42000, [-1] = -6000, [0] = -3000, [1] = 0, [2] = 3000, [3] = 6000, [4] = 12000, [5] = 21000 }
    -- standingId 4 = Neutral, 5 = Friendly, etc.
    -- Offset: standingId - 4 maps to our table index
    return barValue
end
```

### 4.2 Events to Register

```lua
local events = {
    "PLAYER_LEVEL_UP",           -- Level changed
    "PLAYER_XP_UPDATE",          -- XP gained
    "UPDATE_FACTION",            -- Rep changed
    "QUEST_TURNED_IN",           -- Quest completed (for attunement tracking)
    "QUEST_ACCEPTED",            -- Quest accepted
    "PLAYER_ENTERING_WORLD",     -- Initial load / zone change
    "ZONE_CHANGED_NEW_AREA",     -- Entered a new zone (detect dungeon entry)
}
```

### 4.3 Step Auto-Advancement

When the tracker detects a relevant event, check if the current step's conditions are met:

- **Dungeon step**: Compare current rep to target. If met → advance.
- **Quest step**: Use `C_QuestLog.IsQuestFlaggedCompleted(questID)` if quest IDs are known, or track `QUEST_TURNED_IN` events by name.
- **Travel step**: Detect zone via `GetRealZoneText()` or `GetSubZoneText()`.
- **Level goal**: Compare `UnitLevel("player")` to `step.levelGoal`.

---

## 5. USER INTERFACE — `UI.lua`

### 5.1 Main Window

Create a draggable, resizable frame (approximately 700x500 pixels) with a dark semi-transparent background. Use `CreateFrame("Frame", "DungeonOptimizerFrame", UIParent, "BackdropTemplate")`.

The window has **3 tabs** across the top:

#### Tab 1: "Setup" (Configuration)

Layout inspired by the rtw.dev tool screenshot:

- **CHARACTER section** (top-left):
  - Faction: Auto-detected, shown as text with icon
  - Starting Level: Auto-detected from `UnitLevel("player")`, but overridable (row of clickable buttons 58–70)
  - Race: Auto-detected, show Human bonus indicator if applicable

- **OPTIMIZATION MODE** (below character):
  - Two toggle buttons: "Balanced (XP + Rep)" and "Leveling (Max XP)"

- **OPTIONAL QUEST CHAINS** (checkboxes):
  - ☑ Include Karazhan Attunement (adds ~63,100 XP)
    - ☑ Include Arcatraz Key Quest Chain (adds ~113,450 XP, +2,860 Consortium rep)
  - ☐ Include Shattered Halls Key Quest Chain (adds ~45,100 XP, +875 Honor Hold rep)

- **REPUTATION GOALS table** (bottom):
  - Columns: Faction | Current Rep (auto-read) | Target | Needed
  - Per faction row: checkbox to enable/disable, dropdown for target (Friendly/Honored/Revered/Exalted), auto-calculated "needed" value
  - Default targets: Revered for all except Consortium (Honored) and Sha'tar (disabled)

- **SUMMARY panel** (right side, always visible):
  - Total Runs: calculated number
  - Final Level: projected
  - Total XP Gained: sum
  - Faction Progress: list each faction with projected final standing
  - Karazhan Attunement: Complete/Incomplete
  - Big button: **"View Optimized Route"** → switches to Tab 2

#### Tab 2: "Route" (Step-by-Step Guide)

A scrollable list showing every step of the calculated route:

- Each row shows: step number, icon (🏃 travel / ⚔️ dungeon / ❓ quest / 🏁 checkpoint), description, and status (✅ complete / ⬜ pending / ➡️ current)
- Dungeon rows show: dungeon name, run count (e.g., "3/12"), rep progress bar
- Current step is highlighted with a glow/border
- Clicking a step shows details in a tooltip or side panel

#### Tab 3: "Tracker" (Live Progress)

Real-time dashboard:

- **Current Step**: large display of what to do next
- **Level Progress**: XP bar with current/max
- **Reputation Bars**: one per active faction, showing current standing and progress toward goal
- **Dungeon Counter**: "Run X of Y" for current dungeon phase
- **Attunement Checklist**: checkmarks for each key fragment and quest chain milestone

### 5.2 Minimap Button

Add a minimap icon button using standard `CreateFrame("Button")` positioned on the minimap ring. Clicking toggles the main window. Use `LibDBIcon` if embedding libs, or manually place with angle calculation.

### 5.3 Slash Commands

```
/do or /dungeonopt  -- Toggle main window
/do reset           -- Reset all progress
/do route           -- Print current step to chat
/do status          -- Print rep summary to chat
```

---

## 6. SAVED VARIABLES — `Core.lua`

```lua
DungeonOptimizerDB = {
    -- Settings
    optimizationMode = "balanced",  -- or "leveling"
    includeKarazhan = true,
    includeArcatrazKey = true,
    includeShatteredHallsKey = false,

    -- Rep goal overrides (if user changed defaults)
    repGoals = {
        HONOR_HOLD   = "Revered",
        CENARION_EXP = "Revered",
        CONSORTIUM   = "Honored",
        KEEPERS_TIME = "Revered",
        LOWER_CITY   = "Revered",
        SHATAR       = nil,  -- disabled
    },

    -- Progress tracking
    currentStep = 1,
    completedSteps = {},
    dungeonRunCounts = {},  -- e.g., { BLOOD_FURNACE = 8, SLAVE_PENS = 15, ... }

    -- UI state
    windowPosition = { point = "CENTER", x = 0, y = 0 },
    windowSize = { width = 700, height = 500 },
    minimapButtonAngle = 220,
}
```

---

## 7. KEY IMPLEMENTATION NOTES

### 7.1 TBC Classic API Compatibility

- Do **NOT** use retail-only APIs. TBC Classic 2.5.x has a subset of the API.
- `C_QuestLog` exists but is limited. Prefer `GetQuestLogTitle()` loop or `IsQuestFlaggedCompleted()`.
- `GetFactionInfoByID()` works in TBC Classic. Test with the faction IDs listed above.
- Use `CreateFrame("Frame", name, parent, "BackdropTemplate")` — the BackdropTemplate is required in 2.5.x for `SetBackdrop()`.
- No `Mixin()` or `CreateFromMixins()` — use simple OOP with metatables if needed.

### 7.2 Horde Support

The data and route tables above are Alliance-focused. For full Horde support:
- Swap `HONOR_HOLD` → `THRALLMAR` (faction ID 947)
- Swap all Alliance city references in travel steps
- Shattered Halls key quest: Dumphry → Rohok
- Starting zones: Darkshire route → Stonard route

Create `ROUTES.HORDE_BALANCED` as a parallel table. The optimizer should pick the correct route based on `UnitFactionGroup("player")`.

### 7.3 Edge Cases

- Player is **already** past the starting level (e.g., starting at 65): Skip completed phases, recalculate from current position.
- Player has **existing rep**: Read live values and subtract from targets.
- **Human racial**: 10% bonus to all rep gains. This significantly reduces required dungeon runs.
- **Dungeon lockout**: 5 instances per hour limit. The addon should not enforce this but can show a warning.
- **Rep caps on normal**: Blood Furnace, Slave Pens, Underbog, Mana-Tombs, Auchenai Crypts, Old Hillsbrad stop giving trash rep at Honored. Bosses may give rep slightly beyond this. The optimizer should account for this.

### 7.4 Testing

- Test with a fresh level 58 character (both factions)
- Test with a level 65 character with some existing rep
- Test Human vs non-Human to verify 10% bonus math
- Verify all faction IDs return correct data from `GetFactionInfoByID()`
- Test UI at different resolutions (1080p, 1440p, 4K)

---

## 8. FILE DELIVERY

Deliver the complete addon as a folder named `DungeonOptimizer/` that can be dropped directly into `World of Warcraft/_classic_/Interface/AddOns/`. All files should be self-contained with no external dependencies (unless you choose to embed a library like AceAddon, in which case include it in `Libs/`).

The addon should be fully functional on first load with zero configuration — it auto-detects faction, race, level, and current rep standings.
