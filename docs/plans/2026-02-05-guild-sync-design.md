# Guild Sync & Group Detection Design

**Goal:** Add guild-wide status sharing, LFG dungeon matching, progress leaderboard, coordinated planning, and auto-detection of addon users in party.

**Architecture:** Event-driven addon messaging over WoW's built-in invisible addon channels (GUILD/PARTY), with periodic heartbeat and local-only progress verification.

---

## 1. Communication Protocol

### Channels & Prefix

- **Prefix**: `"BoneyardTBC"` registered via `C_ChatInfo.RegisterAddonMessagePrefix` (or `RegisterAddonMessagePrefix` in TBC Classic)
- **Channels**: `"GUILD"` for guild-wide sync, `"PARTY"` for group status
- Addon messages are invisible — they never appear in chat

### Message Types

| Type | Channel | Trigger | Payload |
|------|---------|---------|---------|
| `STATUS` | GUILD | Heartbeat (5 min) + events | level, step, dungeon, runs, mode, reps |
| `HELLO` | GUILD | Login / addon load | Version + triggers others to respond with STATUS |
| `STATUS` | PARTY | Group join + events | Same as guild STATUS |
| `PING` | PARTY | Group join | Discover addon users in party |
| `PONG` | PARTY | Response to PING | Confirm addon presence |

### Heartbeat

Hidden frame `OnUpdate` with elapsed accumulator, fires every 5 minutes. Event-driven broadcasts fire on: level up, step advance, dungeon run complete, rep milestone (new standing).

## 2. Settings

Three checkboxes in the Setup tab under a "Sync" section:

- **Enable Guild Sync** — broadcast/receive to guildies (default: on)
- **Enable Party Sync** — broadcast/receive to party (default: on)
- **Enable Sync Alerts** — chat notifications for LFG matches and milestones (default: on)

SavedVariables:
```lua
BoneyardTBCDB.DungeonOptimizer.enableGuildSync = true
BoneyardTBCDB.DungeonOptimizer.enablePartySync = true
BoneyardTBCDB.DungeonOptimizer.enableSyncAlerts = true
```

When a channel is disabled, no messages are sent or processed on that channel.

## 3. Data Model

### Broadcast Payload (255-byte limit)

```
STATUS:lvl,step,dungeon,runsDone,runsTotal,mode,HH:CE:CO:KT:LC:SH
```

Example: `STATUS:63,12,SLAVE_PENS,8,32,balanced,6000:4500:0:0:1050:0`

Fields: level, current step, dungeon key, runs done, runs total, optimization mode, then 6 rep values (Honor Hold, Cenarion Exp, Consortium, Keepers of Time, Lower City, Sha'tar).

### Guild Roster (persisted in SavedVariables)

```lua
guildRoster = {
    ["Playername"] = {
        level = 63,
        currentStep = 12,
        dungeon = "SLAVE_PENS",
        runsDone = 8,
        runsTotal = 32,
        mode = "balanced",
        reps = { HONOR_HOLD = 6000, ... },
        lastSeen = <server time>,
        isOnline = true,
    },
}
```

- Entries older than 24 hours: greyed out in UI
- Entries older than 7 days: pruned on login
- `HELLO` on login triggers all online guildies to respond with fresh STATUS

### Party Roster (in-memory only)

Same structure, not persisted. Cleared when leaving a group.

## 4. Guild Tab UI

New 4th tab "Guild" in the main window with three sections in a scroll frame:

### LFG Matches (top)

Highlighted panel showing guildies on the same dungeon as you:
```
Dungeon Match: Blood Furnace
  Tankplayer (Lvl 60, Run 4/12)
  Healername (Lvl 59, Run 7/12)
```
Shows "No guildies on your current dungeon" when empty.

### Leaderboard (middle)

Scrollable table sorted by level (desc), then step number:

| Name | Level | Current Phase | Dungeon | Progress | Last Seen |

- Online players in white, offline in grey
- Progress shows step X/132 as a mini completion bar

### Planning View (bottom)

"Who Needs What" — aggregates by dungeon:
```
Blood Furnace: 3 guildies (Tanker, Healer, DPS)
Slave Pens: 2 guildies (Player1, Player2)
```

Only shows dungeons with at least one active guildie.

## 5. Group Detection & Run Tracking

### Party Discovery

On group join, send `PING` on PARTY channel. Addon users respond with `PONG`, then exchange `STATUS`. `GROUP_ROSTER_UPDATE` event re-pings to discover new members.

### Auto-Tracking

Each client tracks its own runs independently via existing Tracker events (PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA). No modification of your own progress from party data. Party sync broadcasts your updated STATUS after:
- Dungeon run complete
- Step advance
- Level up

### Alerts (when enabled)

- Party join: `"Tankplayer is also using Boneyard TBC! (Blood Furnace 4/12)"`
- Guild LFG match: `"Healername just started Blood Furnace — same as you!"`

## 6. File Changes

| File | Change |
|------|--------|
| `BoneyardTBC_DungeonOptimizer.toc` | Add `Sync.lua` before `UI.lua` |
| `Sync.lua` (new) | Message protocol, heartbeat, roster management, alerts |
| `UI.lua` | Sync checkboxes in Setup tab, new Guild tab |
| `DungeonOptimizer.lua` | Sync defaults in OnInitialize, Guild tab in GetTabPanels |
| `Tracker.lua` | Call `Sync.BroadcastStatus()` on key events |

### Sync.lua Responsibilities

- `RegisterComms()` — register prefix + CHAT_MSG_ADDON handler
- `BroadcastStatus(channel)` — serialize player state, send on GUILD/PARTY
- `OnAddonMessage(prefix, msg, channel, sender)` — parse and route
- `StartHeartbeat()` / `StopHeartbeat()` — 5-min OnUpdate timer
- `GetGuildRoster()` / `GetPartyRoster()` — accessors for UI
- `GetDungeonMatches()` — find guildies on same dungeon
- `PruneStaleEntries()` — clean up old data on login

### Initialization Flow

1. `OnInitialize` — merge sync defaults into DB
2. `PLAYER_LOGIN` — register prefix, send HELLO on guild, start heartbeat
3. HELLO responses populate guild roster
4. `GROUP_ROSTER_UPDATE` — ping party for addon users
