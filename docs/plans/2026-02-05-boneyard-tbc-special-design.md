# Boneyard TBC Special — Design Document

**Date**: 2026-02-05
**Client**: WoW TBC Classic Anniversary Edition (2.5.5.65534, Interface 20505)
**Faction**: Alliance only

---

## Overview

Boneyard TBC Special is a modular WoW addon suite for TBC Classic. The first module, DungeonOptimizer, helps players plan and track an optimal dungeon-grinding route from level 58-70, maximizing both XP and faction reputation to unlock heroic dungeon keys and complete the Karazhan attunement.

Inspired by [tbc.rtw.dev/dungeon-optimizer](https://tbc.rtw.dev/dungeon-optimizer) and Myro's leveling spreadsheet (based on BiosparksTV's guide).

---

## Architecture: Modular Suite

### Folder Structure

```
BoneyardTBC/                          -- Core addon
├── BoneyardTBC.toc
├── Core.lua                          -- Addon init, module registry, saved variables
├── UI/
│   ├── MainFrame.lua                 -- Shared window shell, tab system
│   └── Widgets.lua                   -- Reusable UI components
└── Libs/                             -- Shared libraries (optional)

BoneyardTBC_DungeonOptimizer/         -- First module
├── BoneyardTBC_DungeonOptimizer.toc  -- Dependencies: BoneyardTBC
├── DungeonOptimizer.lua              -- Module registration + init
├── Data.lua                          -- Static dungeon/rep/route tables
├── Optimizer.lua                     -- Route calculation engine
├── Tracker.lua                       -- Live progress tracking
└── UI.lua                            -- Module-specific UI panels (3 tabs)
```

### Core Framework (`BoneyardTBC/Core.lua`)

- Module registry: `BoneyardTBC:RegisterModule(name, module)` / `BoneyardTBC:GetModule(name)`
- Shared saved variables: `BoneyardTBCDB` with per-module namespaces (`BoneyardTBCDB.core`, `BoneyardTBCDB.DungeonOptimizer`)
- Slash commands: `/btbc` toggles main window, `/btbc <module> <cmd>` routes to modules
- Minimap button: shared, toggles main window
- Main window: single shared frame with module selector; shows DungeonOptimizer directly when it's the only module

### Module Contract

Modules call `BoneyardTBC:RegisterModule(name, moduleTable)` during load. The module table must provide:
- `module:OnInitialize(db)` — called after ADDON_LOADED, receives its saved variables namespace
- `module:GetTabPanels()` — returns tab definitions for the main window
- `module:OnSlashCommand(args)` — handles module-specific slash subcommands

---

## DungeonOptimizer Module

### Data (`Data.lua`)

All static data from the CLAUDE.md spec:
- `FACTIONS` — Alliance faction IDs and names (Honor Hold, Cenarion Expedition, Consortium, Keepers of Time, Lower City, Sha'tar)
- `REP_LEVELS` / `REP_THRESHOLDS` — Standard Blizzard rep thresholds from Neutral 0
- `DUNGEONS` — 15 TBC dungeons with faction, rep/clear, level range, normal rep cap
- `DUNGEON_XP` — Base XP per clear with effective level ranges
- `XP_TO_LEVEL` — XP required per level (58-69)
- `ROUTES.ALLIANCE_BALANCED` — 132-step curated route (Myro's optimized path)

### Optimizer (`Optimizer.lua`)

Two modes:

**Balanced (default)**: Walks the curated route, dynamically adjusts run counts based on current level and rep. Algorithm:
1. Deep copy the route template
2. Iterate steps, simulating XP/rep gains
3. For dungeon steps with `runs = -1` (stay until goal), calculate actual runs needed
4. For fixed-run steps, adjust if rep already partially met
5. Apply Human racial 10% rep bonus if applicable
6. Respect normal rep caps (trash stops giving rep at cap standing)

**Leveling**: Greedy XP maximizer. At each level, pick the dungeon with best XP yield in your level range. Ignores rep targets.

Key behavior: Recalculates from current state every time, not just at setup. If a player runs extra dungeons, the optimizer reads actual rep/level and adjusts remaining route.

### Tracker (`Tracker.lua`)

Event-driven auto-advancement:

| Event | Action |
|-------|--------|
| `PLAYER_ENTERING_WORLD` | Initial state read |
| `PLAYER_XP_UPDATE` / `PLAYER_LEVEL_UP` | Update level/XP, check level goals |
| `UPDATE_FACTION` | Check rep goals |
| `QUEST_TURNED_IN` | Match quest name, advance quest steps |
| `ZONE_CHANGED_NEW_AREA` | Detect travel completion, dungeon entry/exit |

Step advancement conditions:
- **dungeon**: Rep target reached OR level goal reached
- **quest**: Matching QUEST_TURNED_IN or IsQuestFlaggedCompleted()
- **travel**: Player zone matches target zone (also manually skippable)
- **checkpoint**: Manual acknowledgment only

Dungeon run counting: Increment on dungeon exit detection. Rep-based advancement is the authoritative signal.

### UI (`UI.lua`)

Three tabs within the module panel:

**Tab 1 — Setup**:
- Character info (auto-detected: faction, level, race, Human bonus indicator)
- Optimization mode toggle (Balanced / Leveling)
- Optional quest chain checkboxes (Karazhan, Arcatraz Key, Shattered Halls Key)
- Rep goals table: per-faction enable/disable, target dropdown, auto-calculated "needed"
- Summary panel: total runs, projected final level, XP gained, faction progress, attunement status
- "View Optimized Route" button

**Tab 2 — Route**:
- Scrollable step list with icons (travel/dungeon/quest/checkpoint), description, status
- Dungeon rows show run progress ("3/12") and inline rep bar
- Current step highlighted with glow

**Tab 3 — Tracker**:
- Large current step display
- XP bar, rep bars per faction, dungeon run counter, attunement checklist

### Saved Variables

```lua
BoneyardTBCDB = {
    core = {
        minimapButtonAngle = 220,
        windowPosition = { point = "CENTER", x = 0, y = 0 },
        windowSize = { width = 700, height = 500 },
    },
    DungeonOptimizer = {
        optimizationMode = "balanced",
        includeKarazhan = true,
        includeArcatrazKey = true,
        includeShatteredHallsKey = false,
        repGoals = {
            HONOR_HOLD = "Revered",
            CENARION_EXP = "Revered",
            CONSORTIUM = "Honored",
            KEEPERS_TIME = "Revered",
            LOWER_CITY = "Revered",
            SHATAR = nil,
        },
        currentStep = 1,
        completedSteps = {},
        dungeonRunCounts = {},
    },
}
```

---

## Implementation Notes

- **No Ace libraries** — pure WoW Lua, self-contained
- **No XML templates** — all UI built with CreateFrame() calls
- **BackdropTemplate required** for SetBackdrop() in 2.5.x
- **No Mixin()/CreateFromMixins()** — use simple metatables if needed
- **Alliance only** — no Horde route, no faction resolution logic
- **TBC Classic API only** — no retail-only APIs
- **Human racial**: 10% rep bonus applied via ApplyRacialBonus()
- **Instance lockout**: 5/hour limit shown as warning, not enforced

## Edge Cases

- Player above 58: skip completed phases, enter route at appropriate point
- Existing rep: read live values, reduce run counts
- Normal rep caps: stop counting normal gains once cap standing reached
