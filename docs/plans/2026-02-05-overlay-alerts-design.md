# Overlay, Session Stats & Smart Alerts Design

**Goal:** Add a combined floating overlay showing instance lockout timer + session stats, and smart alerts with chat messages + sound effects on key events.

**Architecture:** Single new `Overlay.lua` file handles the floating frame, session tracking, and alert system. Tracker feeds events into Overlay for both display and alerts.

---

## 1. Combined Overlay

Small draggable frame (~180x90px), anchored TOPRIGHT by default:

```
 Boneyard Stats
 ───────────────────
 Lockout:  3/5 | 12m
 Runs:     7 this session
 XP/hr:    42,350
 Rep/hr:   1,250 (CE)
 Avg Run:  8m 32s
```

### Lockout Line
- Shows `X/5` instance entries in the last hour
- Timer counts down to when the oldest entry expires (freeing a slot)
- Text goes red at 4/5 and 5/5
- Shows "0/5 | Ready" when no entries

### Session Stats
- Session starts on login or `/reload`, resets each time
- **Runs**: Total dungeon runs this session
- **XP/hr**: Total XP gained / session duration
- **Rep/hr**: Rep gained for current dungeon step's faction / session duration
- **Avg Run**: Mean time between instance enter and exit

### Persistence
- Position saved in SavedVariables (`db.overlayPosition`)
- Session data is NOT persisted (resets on login)
- Visibility toggled via "Show Overlay" checkbox in Setup tab

## 2. Smart Alerts

Chat messages + WoW sound effects on key events:

| Event | Chat Message | Sound |
|-------|-------------|-------|
| Dungeon run counted | `Boneyard: <Dungeon> run X complete` | `INTERFACE\iFriendJoin` |
| Step auto-advanced | `Boneyard: Step X complete! Next: <desc>` | `SOUNDKIT.UI_QUEST_COMPLETE` |
| Rep milestone (new standing) | `Boneyard: <Standing> with <Faction>!` | `SOUNDKIT.UI_REPUTATION_UP` |
| Lockout warning (4/5) | `Boneyard WARNING: 4/5 instances. Slow down!` | `SOUNDKIT.RAID_WARNING` |
| Lockout hit (5/5) | `Boneyard WARNING: Lockout reached! Wait Xm.` | `SOUNDKIT.RAID_WARNING` |
| Guildie dungeon match | `Boneyard: <Player> is also running <Dungeon>!` | `INTERFACE\iFriendJoin` |

### Rep Milestone Detection
Compare standing before and after `UPDATE_FACTION`. If standing name changes (e.g., Friendly -> Honored), fire alert.

### Sound API
- `PlaySound(soundKitID)` for SOUNDKIT entries
- `PlaySoundFile("path")` for file-based sounds
- Both work in TBC Classic 2.5.x

### Setting
- Existing "Enable Sync Alerts" controls guild-related alerts
- New "Enable Sound Alerts" checkbox controls all sounds globally

## 3. File Changes

| File | Change |
|------|--------|
| `Overlay.lua` (new) | Floating overlay frame, session tracker, alert system |
| `Tracker.lua` | Fire alerts on key events, feed session data to Overlay |
| `DungeonOptimizer.lua` | Add overlay defaults, init on PLAYER_LOGIN |
| `UI.lua` | Add "Show Overlay" and "Enable Sound Alerts" checkboxes |
| `BoneyardTBC_DungeonOptimizer.toc` | Add `Overlay.lua` between `Sync.lua` and `UI.lua` |

### Overlay.lua Functions

- `CreateOverlayFrame()` — build the compact floating panel
- `UpdateLockout()` — recalculate X/5 and countdown from `Tracker.instanceEntries`
- `UpdateSessionStats()` — compute XP/hr, rep/hr, avg run time
- `StartSession()` / `ResetSession()` — session lifecycle
- `PlayAlert(alertType)` — play sound for event type
- `FireAlert(alertType, message)` — print chat + play sound
- `OnUpdate(elapsed)` — tick lockout countdown every 1 second

### Data Flow

```
Tracker events → Overlay.FireAlert() → chat + sound
Tracker.instanceEntries → Overlay.UpdateLockout() → lockout display
Overlay.OnUpdate (1s tick) → refresh lockout countdown
Session: sessionStartTime, sessionXP, sessionRuns, sessionRunTimes[]
```

### SavedVariables (new keys)

```lua
db.showOverlay = true
db.enableSoundAlerts = true
db.overlayPosition = { point = "TOPRIGHT", x = -20, y = -200 }
```
