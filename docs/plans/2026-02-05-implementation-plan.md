# Boneyard TBC Special — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a modular WoW TBC Classic addon suite with DungeonOptimizer as the first module — an in-game dungeon-grinding route planner and tracker for levels 58-70.

**Architecture:** Core addon (`BoneyardTBC/`) provides module registry, shared UI shell, saved variables, slash commands. Module addon (`BoneyardTBC_DungeonOptimizer/`) registers with core and provides all dungeon/rep/route logic and UI. Pure Lua, no external libraries, no XML templates.

**Tech Stack:** Lua 5.1 (WoW embedded), WoW Classic TBC API (Interface 20505), CreateFrame UI system with BackdropTemplate.

---

## Task 1: Core Addon Scaffold

**Files:**
- Create: `BoneyardTBC/BoneyardTBC.toc`
- Create: `BoneyardTBC/Core.lua`

**Step 1: Create TOC file**

```toc
## Interface: 20505
## Title: Boneyard TBC Special
## Notes: Modular addon suite for TBC Classic
## Author: miikkis
## Version: 1.0.0
## SavedVariables: BoneyardTBCDB

Core.lua
UI\Widgets.lua
UI\MainFrame.lua
```

**Step 2: Create Core.lua with module registry, saved variables, slash commands**

Core.lua implements:
- `BoneyardTBC` global namespace
- `RegisterModule(name, module)` / `GetModule(name)`
- `ADDON_LOADED` event handler that initializes `BoneyardTBCDB` with defaults and calls each module's `OnInitialize(db)`
- `/btbc` slash command handler that toggles the main window or routes `<module> <args>` to modules
- Saved variable defaults merging (fill missing keys without overwriting existing)

**Step 3: Commit**

```bash
git add BoneyardTBC/
git commit -m "feat: core addon scaffold with module registry and slash commands"
```

---

## Task 2: Core UI — Widgets

**Files:**
- Create: `BoneyardTBC/UI/Widgets.lua`

**Step 1: Create reusable widget factory functions**

All functions are namespaced under `BoneyardTBC.Widgets = {}`. Each returns a standard WoW frame.

Implement these factories:
- `CreateProgressBar(parent, width, height, color)` — Frame with background texture + foreground fill texture, `:SetValue(percent)` method, optional text overlay
- `CreateCheckbox(parent, label, default, onChange)` — CheckButton with FontString label, fires onChange(checked) on click
- `CreateDropdown(parent, items, default, onSelect)` — Button that opens a dropdown menu using `UIDropDownMenu_Initialize` / `UIDropDownMenu_CreateInfo` / `ToggleDropDownMenu`, displays selected value
- `CreateTabButton(parent, label, onClick)` — Button styled as a tab with selected/unselected visual states, `:SetSelected(bool)` method
- `CreateIconButton(parent, icon, size, onClick)` — Small clickable button with texture icon (for minimap button, step icons)

Use `CreateFrame("Frame", nil, parent, "BackdropTemplate")` for all backdrop-needing frames. Use standard `GameFontNormal`, `GameFontHighlight`, `GameFontNormalSmall` font objects.

**Step 2: Commit**

```bash
git add BoneyardTBC/UI/Widgets.lua
git commit -m "feat: reusable UI widget factories (progress bar, checkbox, dropdown, tabs)"
```

---

## Task 3: Core UI — Main Frame + Minimap Button

**Files:**
- Create: `BoneyardTBC/UI/MainFrame.lua`

**Step 1: Create the main window frame**

Implement `BoneyardTBC.MainFrame`:
- `CreateFrame("Frame", "BoneyardTBCFrame", UIParent, "BackdropTemplate")` — 700x500, dark semi-transparent backdrop (`{bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16, insets = {left=4, right=4, top=4, bottom=4}}`)
- Draggable via `RegisterForDrag("LeftButton")` + `SetMovable(true)` + `OnDragStart`/`OnDragStop` scripts
- Title bar with addon name "Boneyard TBC Special"
- Close button (standard `CreateFrame("Button", nil, frame, "UIPanelCloseButton")`)
- Tab bar at the top — dynamically populated from registered modules via `module:GetTabPanels()`
- Content area below tabs — shows/hides tab content frames
- Save/restore position from `BoneyardTBCDB.core.windowPosition` on show/hide
- `BoneyardTBC.MainFrame:Toggle()` method used by slash command and minimap button

**Step 2: Create minimap button**

Simple circular button positioned on the minimap ring:
- `CreateFrame("Button", "BoneyardTBCMinimapButton", Minimap)` with size 32x32
- Icon texture (use `"Interface\\Icons\\INV_Misc_Map_01"` as placeholder)
- Position calculated from angle: `x = cos(angle) * 80`, `y = sin(angle) * 80` (80 = minimap radius)
- Left-click toggles main window
- Draggable around minimap ring (update angle on drag, save to `BoneyardTBCDB.core.minimapButtonAngle`)

**Step 3: Commit**

```bash
git add BoneyardTBC/UI/MainFrame.lua
git commit -m "feat: main window frame with tabs, minimap button"
```

---

## Task 4: DungeonOptimizer Module — Scaffold + Data

**Files:**
- Create: `BoneyardTBC_DungeonOptimizer/BoneyardTBC_DungeonOptimizer.toc`
- Create: `BoneyardTBC_DungeonOptimizer/Data.lua`
- Create: `BoneyardTBC_DungeonOptimizer/DungeonOptimizer.lua`

**Step 1: Create module TOC**

```toc
## Interface: 20505
## Title: Boneyard TBC Special - Dungeon Optimizer
## Notes: Dungeon leveling & reputation route optimizer (58-70)
## Author: miikkis
## Version: 1.0.0
## Dependencies: BoneyardTBC

Data.lua
DungeonOptimizer.lua
Optimizer.lua
Tracker.lua
UI.lua
```

**Step 2: Create Data.lua with all static tables**

Copy all data tables from CLAUDE.md spec into `BoneyardTBC_DungeonOptimizer` namespace:
- `FACTIONS` — 6 Alliance factions with IDs and names (Honor Hold, Cenarion Expedition, Consortium, Keepers of Time, Lower City, Sha'tar)
- `REP_LEVELS` — Neutral through Exalted with min/max values
- `REP_THRESHOLDS` — Shorthand thresholds (Neutral=0, Friendly=3000, Honored=6000, Revered=12000, Exalted=21000)
- `DUNGEONS` — 15 dungeons with all fields (name, faction, zone, repPerClear, repPerClearHeroic, minLevel, maxLevel, normalRepCap)
- `DUNGEON_XP` — Base XP and level ranges for each dungeon
- `XP_TO_LEVEL` — XP required for levels 58-69
- `ROUTES.ALLIANCE_BALANCED` — Full 132-step route from CLAUDE.md

**Step 3: Create DungeonOptimizer.lua module entry point**

```lua
local DO = {}
DO.name = "DungeonOptimizer"

function DO:OnInitialize(db)
    self.db = db
    -- Apply defaults if fresh install
    if not db.optimizationMode then
        db.optimizationMode = "balanced"
        db.includeKarazhan = true
        db.includeArcatrazKey = true
        db.includeShatteredHallsKey = false
        db.repGoals = {
            HONOR_HOLD = "Revered",
            CENARION_EXP = "Revered",
            CONSORTIUM = "Honored",
            KEEPERS_TIME = "Revered",
            LOWER_CITY = "Revered",
            SHATAR = nil,
        }
        db.currentStep = 1
        db.completedSteps = {}
        db.dungeonRunCounts = {}
    end
end

function DO:GetTabPanels()
    return {
        { name = "Setup", create = function(parent) return self:CreateSetupTab(parent) end },
        { name = "Route", create = function(parent) return self:CreateRouteTab(parent) end },
        { name = "Tracker", create = function(parent) return self:CreateTrackerTab(parent) end },
    }
end

function DO:OnSlashCommand(args)
    -- handle "route", "status", "reset"
end

BoneyardTBC:RegisterModule("DungeonOptimizer", DO)
```

**Step 4: Commit**

```bash
git add BoneyardTBC_DungeonOptimizer/
git commit -m "feat: DungeonOptimizer module scaffold with complete data tables"
```

---

## Task 5: Optimizer Engine — Balanced Mode

**Files:**
- Create: `BoneyardTBC_DungeonOptimizer/Optimizer.lua`

**Step 1: Implement the optimizer**

Namespace: `BoneyardTBC_DungeonOptimizer.Optimizer = {}`

Implement these functions:

**`DeepCopy(orig)`** — recursive table copy for route templates.

**`ApplyRacialBonus(rep, race)`** — returns `math.floor(rep * 1.10)` for Human, unchanged otherwise.

**`CanGainNormalRep(dungeonKey, currentRep)`** — checks if normal mode still gives rep by comparing current rep against `DUNGEONS[key].normalRepCap` threshold. Returns true if no cap or below cap.

**`CalculateDungeonXP(dungeonKey, playerLevel)`** — returns XP for a single clear. Uses `DUNGEON_XP[key].base` scaled down if player is above the dungeon's `levelRange[2]` (10% reduction per level above max, minimum 20% of base). Returns 0 if below `levelRange[1]`.

**`CalculateBalancedRoute(startLevel, startXP, currentReps, race, options)`**:
1. Deep copy `ROUTES.ALLIANCE_BALANCED`
2. Filter steps based on `options` (remove Karazhan steps if `includeKarazhan=false`, etc.)
3. Walk each step:
   - For `dungeon` steps with `runs == -1`: loop adding rep+XP per run until `levelGoal` and/or `repGoal` met. Set `step.calculatedRuns`.
   - For `dungeon` steps with fixed `runs`: calculate needed runs from rep deficit, take `max(needed, step.runs)`. Skip if rep already met. Set `step.calculatedRuns`.
   - Track `currentLevel`, `currentXP`, `currentReps` throughout.
   - Apply racial bonus to all rep gains.
   - Respect normal rep caps.
4. Return: `{ route = route, totalRuns = N, finalLevel = N, totalXP = N, finalReps = {} }`

**`CalculateLevelingRoute(startLevel, startXP)`**:
1. Build route from scratch — no curated template.
2. At each level, find dungeon with highest `CalculateDungeonXP()` in the valid level range.
3. Run that dungeon until player would level into a better option or hits 70.
4. Return same structure as balanced mode.

**`Recalculate()`** — convenience function that reads current player state (or saved state) and calls the appropriate mode's calculator.

**Step 2: Commit**

```bash
git add BoneyardTBC_DungeonOptimizer/Optimizer.lua
git commit -m "feat: optimizer engine with balanced and leveling route calculation"
```

---

## Task 6: Tracker — Event Handling + Auto-Advancement

**Files:**
- Create: `BoneyardTBC_DungeonOptimizer/Tracker.lua`

**Step 1: Implement the tracker**

Namespace: `BoneyardTBC_DungeonOptimizer.Tracker = {}`

**`Initialize()`** — Create a hidden event frame, register all events:
`PLAYER_ENTERING_WORLD`, `PLAYER_LEVEL_UP`, `PLAYER_XP_UPDATE`, `UPDATE_FACTION`, `QUEST_TURNED_IN`, `QUEST_ACCEPTED`, `ZONE_CHANGED_NEW_AREA`

**`ReadPlayerState()`** — Returns table with:
- `level` = `UnitLevel("player")`
- `xp` = `UnitXP("player")`
- `xpMax` = `UnitXPMax("player")`
- `race` = `UnitRace("player")`
- `faction` = `UnitFactionGroup("player")`
- `reps` = table of faction key → total rep from Neutral 0, read via `GetFactionInfoByID()` for each faction in `FACTIONS`
- `isHuman` = `(select(2, UnitRace("player")) == "Human")`

**`GetTotalRep(factionID)`** — Convert WoW's `GetFactionInfoByID` standing-relative values to absolute rep from Neutral 0. Map `standingId` (4=Neutral, 5=Friendly, 6=Honored, 7=Revered, 8=Exalted) to base values, add `barValue - barMin`.

**`OnEvent(event, ...)`** — Event dispatcher:
- `PLAYER_ENTERING_WORLD`: Call `ReadPlayerState()`, store in `self.playerState`. Trigger `Recalculate()` on optimizer.
- `PLAYER_XP_UPDATE` / `PLAYER_LEVEL_UP`: Update level/XP in state, call `CheckStepAdvancement()`.
- `UPDATE_FACTION`: Update rep values, call `CheckStepAdvancement()`.
- `QUEST_TURNED_IN`: Get quest name from args, call `CheckQuestStep(questName)`.
- `ZONE_CHANGED_NEW_AREA`: Get zone via `GetRealZoneText()`, call `CheckTravelStep(zone)`.

**`CheckStepAdvancement()`** — Look at current step from `db.currentStep`, check completion conditions:
- `dungeon` type: Check if `repGoal` met (compare current rep to threshold) AND/OR `levelGoal` met.
- `quest` type: Already handled by `CheckQuestStep`.
- `travel` type: Already handled by `CheckTravelStep`.
- `checkpoint` type: Never auto-advances.
- If met: increment `db.currentStep`, mark step in `db.completedSteps`, fire UI update callback.

**`CheckQuestStep(questName)`** — If current step is a quest step and `questName` matches `step.quest`, advance.

**`CheckTravelStep(zone)`** — If current step is a travel step and `zone` matches `step.zone`, advance.

**`IncrementDungeonRun(dungeonKey)`** — Called when `ZONE_CHANGED_NEW_AREA` detects leaving a dungeon instance. Increments `db.dungeonRunCounts[key]`.

**`SkipStep()`** — Manual skip for travel/checkpoint steps. Advances `db.currentStep`.

**`ResetProgress()`** — Resets `db.currentStep = 1`, clears `completedSteps` and `dungeonRunCounts`.

**Step 2: Commit**

```bash
git add BoneyardTBC_DungeonOptimizer/Tracker.lua
git commit -m "feat: event-driven tracker with auto-advancement logic"
```

---

## Task 7: DungeonOptimizer UI — Setup Tab

**Files:**
- Create: `BoneyardTBC_DungeonOptimizer/UI.lua`

**Step 1: Implement Setup tab (Tab 1)**

Add `DO:CreateSetupTab(parent)` to the module. Returns a frame containing:

**Character Section** (top-left, 300px wide):
- "Character" header (GameFontNormalLarge)
- Faction: text showing "Alliance" with faction icon
- Level: text showing current level (auto-detected)
- Race: text showing race name, "+10% Rep" badge if Human

**Optimization Mode** (below character):
- "Mode" header
- Two buttons: "Balanced (XP + Rep)" and "Leveling (Max XP)" — toggle style, mutually exclusive. Saves to `db.optimizationMode`. Triggers recalculation.

**Optional Quest Chains** (below mode):
- "Optional Quests" header
- 3 checkboxes using `Widgets.CreateCheckbox`:
  - "Include Karazhan Attunement (+63,100 XP)" → `db.includeKarazhan`
  - "  Include Arcatraz Key Chain (+113,450 XP, +2,860 Consortium)" → `db.includeArcatrazKey` (indented, disabled if Karazhan unchecked)
  - "Include Shattered Halls Key (+45,100 XP)" → `db.includeShatteredHallsKey`
- Each checkbox triggers recalculation on change.

**Rep Goals Table** (bottom, full width):
- "Reputation Goals" header
- Column headers: Enable | Faction | Current | Target | Needed
- One row per faction in `FACTIONS`:
  - Checkbox to enable/disable
  - Faction name text
  - Current rep read from tracker (e.g., "Friendly 1200/3000")
  - Target dropdown (Friendly/Honored/Revered/Exalted) → `db.repGoals[key]`
  - Calculated "needed" value (target threshold minus current)
- Triggers recalculation on any change.

**Summary Panel** (right side, 350px wide):
- "Summary" header
- Labels: Total Runs, Final Level, Total XP, each faction's projected standing, Karazhan status
- All values populated from optimizer's `Recalculate()` result
- Large button at bottom: "View Optimized Route" — switches to Tab 2

**Step 2: Commit**

```bash
git add BoneyardTBC_DungeonOptimizer/UI.lua
git commit -m "feat: DungeonOptimizer Setup tab with character info, options, rep goals"
```

---

## Task 8: DungeonOptimizer UI — Route Tab

**Files:**
- Modify: `BoneyardTBC_DungeonOptimizer/UI.lua`

**Step 1: Implement Route tab (Tab 2)**

Add `DO:CreateRouteTab(parent)`. Returns a frame containing:

**Scrollable step list**:
- `CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")` with a child content frame
- Each step is a row frame (full width, ~30px height) containing:
  - Step number (small text, 30px wide)
  - Type icon (20x20 texture): travel=footprints, dungeon=swords, quest=question mark, checkpoint=flag. Use standard WoW icon textures from `"Interface\\Icons\\"`.
  - Description text (GameFontNormal, wraps if needed):
    - `travel`: step.text
    - `dungeon`: "Run {dungeon.name} x{calculatedRuns} ({repGoal} {faction})"
    - `quest`: "{action}: {quest}" (+ npc/zone if present)
    - `checkpoint`: step.text
  - Status indicator (right-aligned):
    - Completed: green checkmark texture
    - Current: yellow glow border on the row
    - Pending: grey dash

- Dungeon rows get an extra sub-line: small rep progress bar (using `Widgets.CreateProgressBar`) showing current/target rep, and run counter "X/Y runs".

**Step 2: Auto-scroll to current step**

When the tab is shown or progress updates, scroll to the current step row using `scrollFrame:SetVerticalScroll()` calculated from step index * row height.

**Step 3: Commit**

```bash
git add BoneyardTBC_DungeonOptimizer/UI.lua
git commit -m "feat: DungeonOptimizer Route tab with scrollable step list"
```

---

## Task 9: DungeonOptimizer UI — Tracker Tab

**Files:**
- Modify: `BoneyardTBC_DungeonOptimizer/UI.lua`

**Step 1: Implement Tracker tab (Tab 3)**

Add `DO:CreateTrackerTab(parent)`. Returns a frame containing:

**Current Step** (top, large display):
- Type icon (32x32) + step description in GameFontNormalLarge
- "Skip" button (for travel/checkpoint steps only, hidden otherwise)
- If dungeon step: "Run X of Y" counter text

**Level Progress** (below current step):
- "Level {N}" header + XP bar (full width, using `Widgets.CreateProgressBar`)
- Text overlay: "123,456 / 456,000 XP"

**Reputation Bars** (middle section):
- One row per enabled faction in `db.repGoals`:
  - Faction name (left)
  - Progress bar colored by standing (Neutral=grey, Friendly=green, Honored=blue, Revered=purple, Exalted=gold)
  - Standing text + "X / Y" current/target
  - Only show factions with active goals

**Attunement Checklist** (bottom):
- "Attunement Progress" header
- Heroic Keys section: checkmark per faction where rep >= Revered (5 items)
- Karazhan section (if enabled): checkmarks for each key fragment and quest milestone
  - First Fragment (Shadow Labyrinth)
  - Second Fragment (Steamvault)
  - Third Fragment (Arcatraz)
  - Master's Touch (Black Morass)
  - The Violet Eye (final turn-in)

**Step 2: Wire up refresh**

Create `DO:RefreshTrackerUI()` that updates all elements from current player state + optimizer results. Called by tracker's event handler after state changes, and when tab is shown.

**Step 3: Commit**

```bash
git add BoneyardTBC_DungeonOptimizer/UI.lua
git commit -m "feat: DungeonOptimizer Tracker tab with live progress dashboard"
```

---

## Task 10: Integration + Polish

**Files:**
- Modify: `BoneyardTBC_DungeonOptimizer/DungeonOptimizer.lua`
- Modify: `BoneyardTBC/Core.lua`

**Step 1: Wire module slash commands**

In `DO:OnSlashCommand(args)`:
- `"route"` → print current step to chat via `print()`
- `"status"` → print rep summary (each faction's current standing + progress toward goal)
- `"reset"` → call `Tracker:ResetProgress()`, print confirmation

**Step 2: Wire tracker → UI refresh**

In the tracker's `CheckStepAdvancement()`, after advancing a step:
- Call `DO:RefreshRouteUI()` and `DO:RefreshTrackerUI()` if the UI frames exist
- Print step advancement to chat: "Boneyard: Step N complete! Next: {description}"

**Step 3: Wire optimizer → UI refresh**

After any recalculation (triggered by setup tab changes):
- Update Setup tab summary panel
- Rebuild Route tab step list
- Refresh Tracker tab values

**Step 4: Add instance lockout warning**

In tracker's dungeon detection: if 5 dungeon entries detected within the last hour, show a warning text on the Tracker tab: "Instance lockout: 5/5 per hour reached"

**Step 5: Commit**

```bash
git add BoneyardTBC/ BoneyardTBC_DungeonOptimizer/
git commit -m "feat: integration wiring, slash commands, instance lockout warning"
```

---

## Task 11: Final Review + Packaging

**Step 1: Verify file load order**

Check both TOC files list files in correct dependency order:
- Core: `Core.lua` → `UI\Widgets.lua` → `UI\MainFrame.lua`
- Module: `Data.lua` → `DungeonOptimizer.lua` → `Optimizer.lua` → `Tracker.lua` → `UI.lua`

**Step 2: Verify all WoW API usage is TBC Classic compatible**

Scan all files for API calls. Confirm none are retail-only:
- `CreateFrame` with `"BackdropTemplate"` ✓
- `GetFactionInfoByID()` ✓
- `UnitLevel/UnitXP/UnitXPMax/UnitRace/UnitFactionGroup` ✓
- `GetRealZoneText/GetSubZoneText` ✓
- `IsQuestFlaggedCompleted` ✓ (available in 2.5.x)
- No `C_QuestLog` advanced methods, no `Mixin()`, no `CreateFromMixins()`

**Step 3: Verify saved variables**

- `BoneyardTBCDB` declared in core TOC's `SavedVariables`
- Module TOC does NOT declare its own SavedVariables (core owns the table)
- Default merging handles fresh install without overwriting existing data

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: final review and packaging verification"
```
