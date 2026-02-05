# Boneyard TBC Special

A World of Warcraft addon for **TBC Classic Anniversary Edition** (2.5.x) that plans and tracks an optimal dungeon-grinding route from level 58 to 70, maximizing both XP and faction reputation to unlock heroic dungeon keys and complete the Karazhan attunement.

Inspired by Myro's leveling spreadsheet and BiosparksTV's guide.

## Features

### Route Optimizer
- **Balanced mode** — follows Myro's optimized route, adjusting dungeon run counts dynamically based on your current level and rep standings
- **Leveling mode** — greedy XP/hour maximizer that picks the best dungeon at your level, ignoring rep targets
- Auto-detects faction, race, level, and current rep on load — zero configuration needed
- Human racial 10% rep bonus automatically factored into calculations
- Optional quest chains: Karazhan attunement, Arcatraz key, Shattered Halls key

### Live Tracker
- **Auto-advancement** — detects dungeon completions, quest turn-ins, zone changes, level-ups, and rep gains to automatically advance your route step
- **XP bar** with current/max progress
- **Rep bars** per faction with color-coded standings and progress toward goals
- **Dungeon counter** — "Run X of Y" for current phase
- **Attunement checklist** — heroic keys and Karazhan milestones

### Floating Overlay
- Compact draggable panel showing:
  - **Instance lockout** — X/5 with countdown timer, color-coded warnings
  - **Session runs** — dungeon completions this session
  - **XP/hr** and **Rep/hr** — calculated from session data
  - **Avg run time** — mean dungeon duration
- Toggle via right-click on minimap button or checkbox in settings

### Smart Alerts
Chat messages with sound effects on key events:

| Event | Sound |
|-------|-------|
| Dungeon run completed | Notification chime |
| Route step advanced | Quest complete fanfare |
| Rep milestone (new standing) | Reputation up |
| Instance lockout warning (4/5) | Raid warning |
| Instance lockout hit (5/5) | Raid warning |
| Guildie running same dungeon | Notification chime |

### Guild Sync
- Shares progress with guildmates and party members via invisible addon messages
- **Guild tab** with three sections:
  - **LFG Matches** — guildies currently on the same dungeon as you
  - **Leaderboard** — guild members ranked by route progress
  - **Planning View** — who needs what dungeon, grouped for easy coordination
- 5-minute heartbeat, stale detection, automatic roster pruning

## Installation

1. Download or clone this repo
2. Copy both folders into your WoW AddOns directory:
   ```
   World of Warcraft/_anniversary_/Interface/AddOns/BoneyardTBC/
   World of Warcraft/_anniversary_/Interface/AddOns/BoneyardTBC_DungeonOptimizer/
   ```
3. Restart WoW or `/reload`

## Usage

- **`/btbc`** — toggle the main window
- **`/btbc do route`** — print current step to chat
- **`/btbc do status`** — print rep summary to chat
- **`/btbc do reset`** — reset all progress
- **Minimap button** — left-click toggles window, right-click toggles overlay

## Project Structure

```
BoneyardTBC/                          # Core addon (module system, UI framework)
  Core.lua                            # Module registry, saved variables, slash commands
  UI/Widgets.lua                      # Reusable UI components
  UI/MainFrame.lua                    # Main window, tabs, minimap button

BoneyardTBC_DungeonOptimizer/         # Dungeon Optimizer module
  Data.lua                            # Static data (dungeons, factions, routes, XP tables)
  DungeonOptimizer.lua                # Module entry point, defaults, lifecycle
  Optimizer.lua                       # Route calculation engine (balanced + leveling)
  Tracker.lua                         # Event-driven auto-advancement
  Sync.lua                            # Guild/party message protocol
  Overlay.lua                         # Floating stats panel + alert system
  UI.lua                              # All tab UIs (Setup, Route, Tracker, Guild)
```

## Supported Factions

| Faction | Dungeons | Heroic Key At |
|---------|----------|---------------|
| Honor Hold | Ramparts, Blood Furnace, Shattered Halls | Revered |
| Cenarion Expedition | Slave Pens, Underbog, Steamvault | Revered |
| The Consortium | Mana-Tombs | Honored |
| Keepers of Time | Old Hillsbrad, Black Morass | Revered |
| Lower City | Auchenai Crypts, Sethekk Halls, Shadow Labyrinth | Revered |
| The Sha'tar | Mechanar, Botanica, Arcatraz | Revered |

## Requirements

- WoW TBC Classic Anniversary Edition (Interface 20505)
- Alliance character (Horde route not yet implemented)

## License

MIT
