# Guild Sync & Group Detection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add guild-wide status sync, LFG dungeon matching, progress leaderboard, coordinated planning view, and auto-detection of addon users in party groups.

**Architecture:** New `Sync.lua` handles all addon messaging (GUILD/PARTY channels) with a 5-minute heartbeat + event-driven broadcasts. Guild roster persisted in SavedVariables, party roster in memory. New "Guild" tab (4th tab) in the main window. Three settings checkboxes in Setup tab.

**Tech Stack:** WoW TBC Classic Lua API — `SendAddonMessage`, `C_ChatInfo.RegisterAddonMessagePrefix`, `CHAT_MSG_ADDON` event, `GROUP_ROSTER_UPDATE` event.

**Design doc:** `docs/plans/2026-02-05-guild-sync-design.md`

---

### Task 1: Sync.lua — Message Protocol & Prefix Registration

**Context:** This is the foundation. Sync.lua lives under the `BoneyardTBC_DO` namespace alongside Tracker, Optimizer, etc. It handles serialization, deserialization, prefix registration, and the CHAT_MSG_ADDON dispatcher.

**Files:**
- Create: `BoneyardTBC_DungeonOptimizer/Sync.lua`

**Step 1: Create Sync.lua with protocol constants and serialization**

```lua
--------------------------------------------------------------------------------
-- Sync.lua
-- Guild & party status sync via addon messages.
-- Handles message protocol, heartbeat, roster management, and alerts.
--------------------------------------------------------------------------------

BoneyardTBC_DO.Sync = {}

local Sync = BoneyardTBC_DO.Sync

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
local ADDON_PREFIX = "BoneyardTBC"
local HEARTBEAT_INTERVAL = 300 -- 5 minutes in seconds
local STALE_THRESHOLD = 86400  -- 24 hours in seconds
local PRUNE_THRESHOLD = 604800 -- 7 days in seconds

-- Message types
local MSG_STATUS = "STATUS"
local MSG_HELLO  = "HELLO"
local MSG_PING   = "PING"
local MSG_PONG   = "PONG"

-- Rep keys in fixed order for serialization
local REP_KEYS = { "HONOR_HOLD", "CENARION_EXP", "CONSORTIUM", "KEEPERS_TIME", "LOWER_CITY", "SHATAR" }

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
Sync.guildRoster = {}   -- persisted via DB reference
Sync.partyRoster = {}   -- in-memory only
Sync.heartbeatFrame = nil
Sync.heartbeatElapsed = 0
Sync.initialized = false

--------------------------------------------------------------------------------
-- SerializeStatus: Build a compact status string from current player state
-- Format: STATUS:lvl,step,dungeon,runsDone,runsTotal,mode,HH:CE:CO:KT:LC:SH
--------------------------------------------------------------------------------
function Sync.SerializeStatus()
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    local playerState = BoneyardTBC_DO.Tracker and BoneyardTBC_DO.Tracker.playerState
    if not db or not playerState then return nil end

    local level = playerState.level or 0
    local step = db.currentStep or 1
    local mode = db.optimizationMode or "balanced"

    -- Find current dungeon info from route
    local dungeon = ""
    local runsDone = 0
    local runsTotal = 0
    local route = BoneyardTBC_DO.Optimizer and BoneyardTBC_DO.Optimizer.lastResult and BoneyardTBC_DO.Optimizer.lastResult.route
    if route then
        for _, routeStep in ipairs(route) do
            if routeStep.step == step and routeStep.type == "dungeon" then
                dungeon = routeStep.dungeon or ""
                runsTotal = routeStep.calculatedRuns or routeStep.runs or 0
                runsDone = (db.dungeonRunCounts and db.dungeonRunCounts[dungeon]) or 0
                break
            end
        end
    end

    -- Rep values in fixed order
    local repParts = {}
    for _, key in ipairs(REP_KEYS) do
        repParts[#repParts + 1] = tostring((playerState.reps and playerState.reps[key]) or 0)
    end
    local repStr = table.concat(repParts, ":")

    return string.format("%s:%d,%d,%s,%d,%d,%s,%s",
        MSG_STATUS, level, step, dungeon, runsDone, runsTotal, mode, repStr)
end

--------------------------------------------------------------------------------
-- DeserializeStatus: Parse a STATUS message payload into a table
--------------------------------------------------------------------------------
function Sync.DeserializeStatus(payload)
    -- payload format: lvl,step,dungeon,runsDone,runsTotal,mode,HH:CE:CO:KT:LC:SH
    local parts = {}
    for part in payload:gmatch("[^,]+") do
        parts[#parts + 1] = part
    end

    if #parts < 7 then return nil end

    local result = {
        level = tonumber(parts[1]) or 0,
        currentStep = tonumber(parts[2]) or 1,
        dungeon = parts[3] ~= "" and parts[3] or nil,
        runsDone = tonumber(parts[4]) or 0,
        runsTotal = tonumber(parts[5]) or 0,
        mode = parts[6] or "balanced",
        reps = {},
        lastSeen = time(),
        isOnline = true,
    }

    -- Parse rep values (colon-separated in the 7th field)
    local repStr = parts[7] or ""
    local repValues = {}
    for val in repStr:gmatch("[^:]+") do
        repValues[#repValues + 1] = tonumber(val) or 0
    end
    for i, key in ipairs(REP_KEYS) do
        result.reps[key] = repValues[i] or 0
    end

    return result
end

--------------------------------------------------------------------------------
-- RegisterComms: Register addon prefix and set up CHAT_MSG_ADDON handler
--------------------------------------------------------------------------------
function Sync.RegisterComms()
    -- Register the addon message prefix
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(ADDON_PREFIX)
    end

    -- Create event frame for addon messages and group changes
    Sync.commFrame = CreateFrame("Frame")
    Sync.commFrame:RegisterEvent("CHAT_MSG_ADDON")
    Sync.commFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

    Sync.commFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            Sync.OnAddonMessage(...)
        elseif event == "GROUP_ROSTER_UPDATE" then
            Sync.OnGroupChanged()
        end
    end)
end

--------------------------------------------------------------------------------
-- OnAddonMessage: Route incoming addon messages by type
--------------------------------------------------------------------------------
function Sync.OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_PREFIX then return end

    -- Don't process our own messages
    local playerName = UnitName("player")
    if sender == playerName then return end

    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return end

    -- Parse message type
    local msgType, payload = message:match("^(%u+):(.+)$")
    if not msgType then return end

    if msgType == MSG_STATUS then
        local data = Sync.DeserializeStatus(payload)
        if not data then return end

        if channel == "GUILD" and db.enableGuildSync ~= false then
            Sync.guildRoster[sender] = data
            -- Check for LFG match alert
            Sync.CheckDungeonMatchAlert(sender, data)
        elseif channel == "PARTY" and db.enablePartySync ~= false then
            Sync.partyRoster[sender] = data
        end

        -- Refresh guild tab if visible
        Sync.RefreshGuildTab()

    elseif msgType == MSG_HELLO then
        if channel == "GUILD" and db.enableGuildSync ~= false then
            -- Respond with our status
            Sync.BroadcastStatus("GUILD")
        end

    elseif msgType == MSG_PING then
        if channel == "PARTY" and db.enablePartySync ~= false then
            -- Respond with PONG then STATUS
            Sync.SendMessage(MSG_PONG .. ":1", "PARTY")
            Sync.BroadcastStatus("PARTY")
        end

    elseif msgType == MSG_PONG then
        if channel == "PARTY" and db.enablePartySync ~= false then
            -- Addon user confirmed in party — we'll get their STATUS next
        end
    end
end

--------------------------------------------------------------------------------
-- SendMessage: Send an addon message on the specified channel
--------------------------------------------------------------------------------
function Sync.SendMessage(message, channel)
    if not message or not channel then return end

    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, channel)
    elseif SendAddonMessage then
        SendAddonMessage(ADDON_PREFIX, message, channel)
    end
end

--------------------------------------------------------------------------------
-- BroadcastStatus: Serialize and send current status on the given channel
--------------------------------------------------------------------------------
function Sync.BroadcastStatus(channel)
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return end

    if channel == "GUILD" and db.enableGuildSync == false then return end
    if channel == "PARTY" and db.enablePartySync == false then return end

    -- Only send on GUILD if we're in a guild
    if channel == "GUILD" and not IsInGuild() then return end

    -- Only send on PARTY if we're in a group
    if channel == "PARTY" and not IsInGroup() then return end

    local message = Sync.SerializeStatus()
    if message then
        Sync.SendMessage(message, channel)
    end
end

--------------------------------------------------------------------------------
-- BroadcastAll: Send status on all enabled channels
--------------------------------------------------------------------------------
function Sync.BroadcastAll()
    Sync.BroadcastStatus("GUILD")
    Sync.BroadcastStatus("PARTY")
end
```

**Step 2: Lint the file**

Run: `luacheck BoneyardTBC_DungeonOptimizer/Sync.lua --no-color --globals BoneyardTBC_DO BoneyardTBC CreateFrame UnitName C_ChatInfo RegisterAddonMessagePrefix SendAddonMessage IsInGuild IsInGroup time`
Expected: 0 errors (warnings for WoW globals are fine)

**Step 3: Commit**

```bash
git add BoneyardTBC_DungeonOptimizer/Sync.lua
git commit -m "feat: Sync.lua with message protocol, serialization, and addon message handling"
```

---

### Task 2: Heartbeat Timer & Event-Driven Broadcasts

**Context:** Add the 5-minute heartbeat that broadcasts STATUS on GUILD channel, plus the HELLO handshake on login. Wire Tracker events to trigger broadcasts.

**Files:**
- Modify: `BoneyardTBC_DungeonOptimizer/Sync.lua` (append new functions)
- Modify: `BoneyardTBC_DungeonOptimizer/Tracker.lua:416-421` (add BroadcastAll after step advance)
- Modify: `BoneyardTBC_DungeonOptimizer/Tracker.lua:445` (add BroadcastAll after dungeon run)

**Step 1: Add heartbeat and initialization functions to Sync.lua**

Append to end of `Sync.lua`:

```lua
--------------------------------------------------------------------------------
-- StartHeartbeat: Begin the periodic broadcast timer
--------------------------------------------------------------------------------
function Sync.StartHeartbeat()
    if Sync.heartbeatFrame then return end -- already running

    Sync.heartbeatFrame = CreateFrame("Frame")
    Sync.heartbeatElapsed = 0

    Sync.heartbeatFrame:SetScript("OnUpdate", function(_, elapsed)
        Sync.heartbeatElapsed = Sync.heartbeatElapsed + elapsed
        if Sync.heartbeatElapsed >= HEARTBEAT_INTERVAL then
            Sync.heartbeatElapsed = 0
            Sync.BroadcastStatus("GUILD")
        end
    end)
end

--------------------------------------------------------------------------------
-- StopHeartbeat: Stop the periodic broadcast timer
--------------------------------------------------------------------------------
function Sync.StopHeartbeat()
    if Sync.heartbeatFrame then
        Sync.heartbeatFrame:SetScript("OnUpdate", nil)
        Sync.heartbeatFrame = nil
    end
end

--------------------------------------------------------------------------------
-- OnGroupChanged: Called when party composition changes
--------------------------------------------------------------------------------
function Sync.OnGroupChanged()
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db or db.enablePartySync == false then return end

    if IsInGroup() then
        -- Ping to discover addon users
        Sync.SendMessage(MSG_PING .. ":1", "PARTY")
        -- Also broadcast our status
        Sync.BroadcastStatus("PARTY")
    else
        -- Left group: clear party roster
        wipe(Sync.partyRoster)
        Sync.RefreshGuildTab()
    end
end

--------------------------------------------------------------------------------
-- PruneStaleEntries: Remove old entries from guild roster
--------------------------------------------------------------------------------
function Sync.PruneStaleEntries()
    local now = time()
    local pruned = 0

    for name, data in pairs(Sync.guildRoster) do
        if data.lastSeen and (now - data.lastSeen) > PRUNE_THRESHOLD then
            Sync.guildRoster[name] = nil
            pruned = pruned + 1
        end
    end

    return pruned
end

--------------------------------------------------------------------------------
-- Initialize: Set up comms, load roster from DB, send HELLO, start heartbeat
-- Called from DungeonOptimizer.lua during PLAYER_LOGIN
--------------------------------------------------------------------------------
function Sync.Initialize()
    if Sync.initialized then return end

    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return end

    -- Load persisted guild roster from DB
    if db.guildRoster then
        Sync.guildRoster = db.guildRoster
    else
        db.guildRoster = {}
        Sync.guildRoster = db.guildRoster
    end

    -- Mark all entries as offline initially (HELLO responses will update)
    for _, data in pairs(Sync.guildRoster) do
        data.isOnline = false
    end

    -- Prune old entries
    Sync.PruneStaleEntries()

    -- Register communications
    Sync.RegisterComms()

    -- Send HELLO to guild
    if db.enableGuildSync ~= false and IsInGuild() then
        -- Delay slightly so other addons have time to register
        C_Timer.After(3, function()
            Sync.SendMessage(MSG_HELLO .. ":1", "GUILD")
            -- Also broadcast our own status
            Sync.BroadcastStatus("GUILD")
        end)
    end

    -- Check if already in a group
    if db.enablePartySync ~= false and IsInGroup() then
        C_Timer.After(3, function()
            Sync.SendMessage(MSG_PING .. ":1", "PARTY")
            Sync.BroadcastStatus("PARTY")
        end)
    end

    -- Start heartbeat
    Sync.StartHeartbeat()

    Sync.initialized = true
end

--------------------------------------------------------------------------------
-- CheckDungeonMatchAlert: Alert if a guildie is on the same dungeon as us
--------------------------------------------------------------------------------
function Sync.CheckDungeonMatchAlert(senderName, senderData)
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db or db.enableSyncAlerts == false then return end

    -- Find our current dungeon
    local myDungeon = nil
    local route = BoneyardTBC_DO.Optimizer and BoneyardTBC_DO.Optimizer.lastResult and BoneyardTBC_DO.Optimizer.lastResult.route
    local myStep = db.currentStep or 1
    if route then
        for _, routeStep in ipairs(route) do
            if routeStep.step == myStep and routeStep.type == "dungeon" then
                myDungeon = routeStep.dungeon
                break
            end
        end
    end

    if not myDungeon or not senderData.dungeon then return end

    if myDungeon == senderData.dungeon then
        local dungeon = BoneyardTBC_DO.DUNGEONS[myDungeon]
        local dungeonName = (dungeon and dungeon.name) or myDungeon
        print("|cff00ccffBoneyard:|r " .. senderName .. " is also running " .. dungeonName .. "!")
    end
end

--------------------------------------------------------------------------------
-- RefreshGuildTab: Notify the UI to refresh the Guild tab
--------------------------------------------------------------------------------
function Sync.RefreshGuildTab()
    local DO = BoneyardTBC_DO.module
    if DO and DO.RefreshGuildTab then
        DO:RefreshGuildTab()
    end
end

--------------------------------------------------------------------------------
-- GetDungeonMatches: Find guildies on the same dungeon as the player
-- Returns: { { name = "Player", data = {...} }, ... }
--------------------------------------------------------------------------------
function Sync.GetDungeonMatches()
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return {} end

    -- Find our current dungeon
    local myDungeon = nil
    local route = BoneyardTBC_DO.Optimizer and BoneyardTBC_DO.Optimizer.lastResult and BoneyardTBC_DO.Optimizer.lastResult.route
    local myStep = db.currentStep or 1
    if route then
        for _, routeStep in ipairs(route) do
            if routeStep.step == myStep and routeStep.type == "dungeon" then
                myDungeon = routeStep.dungeon
                break
            end
        end
    end

    if not myDungeon then return {} end

    local matches = {}
    for name, data in pairs(Sync.guildRoster) do
        if data.dungeon == myDungeon and data.isOnline then
            matches[#matches + 1] = { name = name, data = data }
        end
    end

    return matches
end

--------------------------------------------------------------------------------
-- GetDungeonGroups: Aggregate guildies by dungeon for planning view
-- Returns: { { dungeon = "KEY", dungeonName = "Name", players = { {name, data}, ... } }, ... }
--------------------------------------------------------------------------------
function Sync.GetDungeonGroups()
    local groups = {}
    local groupMap = {}

    for name, data in pairs(Sync.guildRoster) do
        if data.dungeon and data.dungeon ~= "" and data.isOnline then
            if not groupMap[data.dungeon] then
                groupMap[data.dungeon] = { dungeon = data.dungeon, players = {} }
                groups[#groups + 1] = groupMap[data.dungeon]
            end
            groupMap[data.dungeon].players[#groupMap[data.dungeon].players + 1] = { name = name, data = data }
        end
    end

    -- Add dungeon names
    for _, group in ipairs(groups) do
        local dungeon = BoneyardTBC_DO.DUNGEONS[group.dungeon]
        group.dungeonName = (dungeon and dungeon.name) or group.dungeon
    end

    -- Sort by number of players (descending)
    table.sort(groups, function(a, b) return #a.players > #b.players end)

    return groups
end

--------------------------------------------------------------------------------
-- GetSortedRoster: Return guild roster sorted by level desc, then step desc
-- Returns: { { name = "Player", data = {...} }, ... }
--------------------------------------------------------------------------------
function Sync.GetSortedRoster()
    local sorted = {}
    for name, data in pairs(Sync.guildRoster) do
        sorted[#sorted + 1] = { name = name, data = data }
    end

    table.sort(sorted, function(a, b)
        if a.data.level ~= b.data.level then
            return a.data.level > b.data.level
        end
        return (a.data.currentStep or 0) > (b.data.currentStep or 0)
    end)

    return sorted
end
```

**Step 2: Wire Tracker to broadcast on key events**

In `Tracker.lua`, add `Sync.BroadcastAll()` call after step advance (line 421) and dungeon run (line 448).

In `Tracker.lua:AdvanceStep()`, after the `onStepAdvanced` callback (line 421), add:
```lua
    -- Broadcast updated status to guild/party
    if BoneyardTBC_DO.Sync and BoneyardTBC_DO.Sync.BroadcastAll then
        BoneyardTBC_DO.Sync.BroadcastAll()
    end
```

In `Tracker.lua:IncrementDungeonRun()`, after `Tracker.CheckStepAdvancement()` (line 448), add:
```lua
    -- Broadcast updated status to guild/party
    if BoneyardTBC_DO.Sync and BoneyardTBC_DO.Sync.BroadcastAll then
        BoneyardTBC_DO.Sync.BroadcastAll()
    end
```

**Step 3: Lint and commit**

```bash
luacheck BoneyardTBC_DungeonOptimizer/Sync.lua --no-color --globals BoneyardTBC_DO BoneyardTBC CreateFrame UnitName C_ChatInfo RegisterAddonMessagePrefix SendAddonMessage IsInGuild IsInGroup C_Timer time wipe
git add BoneyardTBC_DungeonOptimizer/Sync.lua BoneyardTBC_DungeonOptimizer/Tracker.lua
git commit -m "feat: heartbeat timer, event-driven broadcasts, guild/party roster management"
```

---

### Task 3: DungeonOptimizer Integration — Defaults, Init, TOC

**Context:** Wire Sync into the module lifecycle: add sync defaults to OnInitialize, call Sync.Initialize() during PLAYER_LOGIN, add Sync.lua to the TOC.

**Files:**
- Modify: `BoneyardTBC_DungeonOptimizer/BoneyardTBC_DungeonOptimizer.toc` (add Sync.lua)
- Modify: `BoneyardTBC_DungeonOptimizer/DungeonOptimizer.lua:7-23` (add sync defaults)
- Modify: `BoneyardTBC_DungeonOptimizer/DungeonOptimizer.lua:28-36` (add Sync.Initialize to PLAYER_LOGIN)
- Modify: `BoneyardTBC_DungeonOptimizer/DungeonOptimizer.lua:39-45` (add Guild tab to GetTabPanels)

**Step 1: Update TOC**

Add `Sync.lua` between `Tracker.lua` and `UI.lua`:
```
Data.lua
DungeonOptimizer.lua
Optimizer.lua
Tracker.lua
Sync.lua
UI.lua
```

**Step 2: Add sync defaults to OnInitialize**

In `DungeonOptimizer.lua`, inside the `if not db.optimizationMode then` block (after line 22, before `end`), add:
```lua
        db.enableGuildSync = true
        db.enablePartySync = true
        db.enableSyncAlerts = true
        db.guildRoster = {}
```

Also add a migration block AFTER the defaults block (after line 23) to ensure existing installs get the new defaults:
```lua
    -- Migrate: add sync defaults for existing installs
    if db.enableGuildSync == nil then
        db.enableGuildSync = true
        db.enablePartySync = true
        db.enableSyncAlerts = true
    end
    if not db.guildRoster then
        db.guildRoster = {}
    end
```

**Step 3: Add Sync.Initialize to PLAYER_LOGIN handler**

In `DungeonOptimizer.lua`, inside the PLAYER_LOGIN handler (after line 31 `BoneyardTBC_DO.Tracker.Initialize()`), add:
```lua
        -- Initialize sync system
        BoneyardTBC_DO.Sync.Initialize()
```

**Step 4: Add Guild tab to GetTabPanels**

In `DungeonOptimizer.lua`, update `GetTabPanels()` to include the Guild tab:
```lua
function DO:GetTabPanels()
    return {
        { name = "Setup", create = function(parent) return self:CreateSetupTab(parent) end },
        { name = "Route", create = function(parent) return self:CreateRouteTab(parent) end },
        { name = "Tracker", create = function(parent) return self:CreateTrackerTab(parent) end },
        { name = "Guild", create = function(parent) return self:CreateGuildTab(parent) end },
    }
end
```

**Step 5: Commit**

```bash
git add BoneyardTBC_DungeonOptimizer/BoneyardTBC_DungeonOptimizer.toc BoneyardTBC_DungeonOptimizer/DungeonOptimizer.lua
git commit -m "feat: wire Sync into module lifecycle, add Guild tab, sync defaults"
```

---

### Task 4: Settings UI — Sync Checkboxes in Setup Tab

**Context:** Add a "Sync" section to the Setup tab with three checkboxes: Enable Guild Sync, Enable Party Sync, Enable Sync Alerts. This goes between "Optional Quests" and "Reputation Goals" sections. Must adjust the Y offset for Reputation Goals to make room.

**Files:**
- Modify: `BoneyardTBC_DungeonOptimizer/UI.lua:234-286` (add sync section, adjust rep goals offset)

**Step 1: Add sync section to Setup tab**

In `UI.lua`, after the "Optional Quests" section (after the `shatteredCB` variable around line 280), add a new "Sync" section. Then adjust the Reputation Goals header Y offset from `-224` to `-310` to make room.

Insert after the shatteredCB block (around line 280):
```lua
    ----------------------------------------------------------------
    -- 3b. SYNC SETTINGS
    ----------------------------------------------------------------

    local syncHeader = CreateSectionHeader(leftCol, "Sync", 0, -220)

    local guildSyncCB = BoneyardTBC.Widgets.CreateCheckbox(leftCol, "Enable Guild Sync", db.enableGuildSync ~= false, function(checked)
        db.enableGuildSync = checked
        if checked then
            BoneyardTBC_DO.Sync.StartHeartbeat()
            BoneyardTBC_DO.Sync.BroadcastStatus("GUILD")
        else
            BoneyardTBC_DO.Sync.StopHeartbeat()
        end
    end)
    guildSyncCB:SetPoint("TOPLEFT", syncHeader, "BOTTOMLEFT", 0, -6)
    W.guildSyncCB = guildSyncCB

    local partySyncCB = BoneyardTBC.Widgets.CreateCheckbox(leftCol, "Enable Party Sync", db.enablePartySync ~= false, function(checked)
        db.enablePartySync = checked
    end)
    partySyncCB:SetPoint("TOPLEFT", guildSyncCB, "BOTTOMLEFT", 0, -2)
    W.partySyncCB = partySyncCB

    local alertsCB = BoneyardTBC.Widgets.CreateCheckbox(leftCol, "Enable Sync Alerts", db.enableSyncAlerts ~= false, function(checked)
        db.enableSyncAlerts = checked
    end)
    alertsCB:SetPoint("TOPLEFT", partySyncCB, "BOTTOMLEFT", 0, -2)
    W.alertsCB = alertsCB
```

Change the Reputation Goals header offset from `-224` to `-310`:
```lua
    local repHeader = CreateSectionHeader(leftCol, "Reputation Goals", 0, -310)
```

**Important:** The content area is only 422px tall. With the new Sync section, the rep goals table will overflow. To fix this, increase the main window height from 500 to 580.

In `BoneyardTBC/UI/MainFrame.lua`, change `FRAME_HEIGHT`:
```lua
local FRAME_HEIGHT = 580
```

Also update the default window size in `BoneyardTBC/Core.lua` DEFAULTS:
```lua
windowSize = { width = 700, height = 580 },
```

**Step 2: Commit**

```bash
git add BoneyardTBC_DungeonOptimizer/UI.lua BoneyardTBC/UI/MainFrame.lua BoneyardTBC/Core.lua
git commit -m "feat: sync settings checkboxes in Setup tab, increase window height"
```

---

### Task 5: Guild Tab — LFG Matches Section

**Context:** Create the Guild tab's first section: LFG Matches. Shows guildies currently on the same dungeon as you in a highlighted panel.

**Files:**
- Modify: `BoneyardTBC_DungeonOptimizer/UI.lua` (add CreateGuildTab and LFG section)

**Step 1: Add CreateGuildTab with LFG matches section**

Add to `UI.lua` (before the `onStepAdvanced` callback at the end of the file):

```lua
----------------------------------------------------------------------
-- Tab 4: Guild — Guild Sync Dashboard
----------------------------------------------------------------------

local GUILD_PANEL_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

function DO:CreateGuildTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)

    self.guildTab = tab
    self.guildWidgets = {}
    local GW = self.guildWidgets

    -- Scroll frame for entire guild tab content
    local scrollFrame = CreateFrame("ScrollFrame", "BoneyardTBC_DOGuildScroll", tab, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -26, 0)
    GW.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth() or 640)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    GW.content = content

    scrollFrame:SetScript("OnSizeChanged", function(sf, width, height)
        content:SetWidth(width)
    end)

    local yOffset = 0

    ----------------------------------------------------------------
    -- 1. LFG MATCHES (top section)
    ----------------------------------------------------------------

    local lfgHeader = CreateSectionHeader(content, "Dungeon Matches", 0, yOffset)
    yOffset = yOffset - 22

    -- LFG match panel (dark background)
    local lfgPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    lfgPanel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    lfgPanel:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    lfgPanel:SetHeight(60)
    lfgPanel:SetBackdrop(GUILD_PANEL_BACKDROP)
    lfgPanel:SetBackdropColor(0.15, 0.25, 0.15, 0.9)
    lfgPanel:SetBackdropBorderColor(0.3, 0.5, 0.3, 1)
    GW.lfgPanel = lfgPanel

    -- Dungeon match title
    local lfgTitle = lfgPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lfgTitle:SetPoint("TOPLEFT", lfgPanel, "TOPLEFT", 10, -8)
    lfgTitle:SetText("No guildies on your current dungeon.")
    lfgTitle:SetTextColor(0.7, 0.7, 0.7, 1)
    GW.lfgTitle = lfgTitle

    -- Match player list (below title)
    local lfgPlayers = lfgPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lfgPlayers:SetPoint("TOPLEFT", lfgTitle, "BOTTOMLEFT", 0, -4)
    lfgPlayers:SetPoint("RIGHT", lfgPanel, "RIGHT", -10, 0)
    lfgPlayers:SetJustifyH("LEFT")
    lfgPlayers:SetWordWrap(true)
    lfgPlayers:SetText("")
    GW.lfgPlayers = lfgPlayers

    yOffset = yOffset - 70

    -- Store yOffset for leaderboard section start
    GW.leaderboardStartY = yOffset

    ----------------------------------------------------------------
    -- Sections 2 & 3 (Leaderboard + Planning) added in Tasks 6 & 7
    ----------------------------------------------------------------

    -- Refresh on show
    tab:SetScript("OnShow", function()
        content:SetWidth(scrollFrame:GetWidth())
        DO:RefreshGuildTab()
    end)

    return tab
end

----------------------------------------------------------------------
-- DO:RefreshGuildTab() — Update all guild tab sections
----------------------------------------------------------------------
function DO:RefreshGuildTab()
    if not self.guildWidgets then return end
    local GW = self.guildWidgets

    ----------------------------------------------------------------
    -- 1. LFG Matches
    ----------------------------------------------------------------
    local matches = BoneyardTBC_DO.Sync.GetDungeonMatches()

    if #matches > 0 then
        -- Find our dungeon name
        local db = self.db
        local myDungeon = nil
        local route = BoneyardTBC_DO.Optimizer and BoneyardTBC_DO.Optimizer.lastResult and BoneyardTBC_DO.Optimizer.lastResult.route
        local myStep = db.currentStep or 1
        if route then
            for _, routeStep in ipairs(route) do
                if routeStep.step == myStep and routeStep.type == "dungeon" then
                    myDungeon = routeStep.dungeon
                    break
                end
            end
        end

        local dungeonData = myDungeon and BoneyardTBC_DO.DUNGEONS[myDungeon]
        local dungeonName = (dungeonData and dungeonData.name) or (myDungeon or "Unknown")

        GW.lfgTitle:SetText("Dungeon Match: " .. dungeonName)
        GW.lfgTitle:SetTextColor(0.3, 0.9, 0.3, 1)

        local playerLines = {}
        for _, match in ipairs(matches) do
            playerLines[#playerLines + 1] = string.format("  %s (Lvl %d, Run %d/%d)",
                match.name, match.data.level, match.data.runsDone, match.data.runsTotal)
        end
        GW.lfgPlayers:SetText(table.concat(playerLines, "\n"))

        -- Resize panel to fit
        local lineCount = #playerLines
        GW.lfgPanel:SetHeight(30 + (lineCount * 14))
        GW.lfgPanel:SetBackdropColor(0.15, 0.25, 0.15, 0.9)
        GW.lfgPanel:SetBackdropBorderColor(0.3, 0.5, 0.3, 1)
    else
        GW.lfgTitle:SetText("No guildies on your current dungeon.")
        GW.lfgTitle:SetTextColor(0.7, 0.7, 0.7, 1)
        GW.lfgPlayers:SetText("")
        GW.lfgPanel:SetHeight(60)
        GW.lfgPanel:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
        GW.lfgPanel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
end
```

**Step 2: Commit**

```bash
git add BoneyardTBC_DungeonOptimizer/UI.lua
git commit -m "feat: Guild tab with LFG dungeon matches section"
```

---

### Task 6: Guild Tab — Leaderboard Section

**Context:** Add the scrollable leaderboard table to the Guild tab. Shows all guild roster entries sorted by level desc, with columns: Name, Level, Dungeon, Progress, Last Seen.

**Files:**
- Modify: `BoneyardTBC_DungeonOptimizer/UI.lua` (expand CreateGuildTab and RefreshGuildTab)

**Step 1: Add leaderboard section to CreateGuildTab**

In `CreateGuildTab`, replace the `-- Sections 2 & 3` placeholder comment with the leaderboard section. Insert after `GW.leaderboardStartY = yOffset`:

```lua
    ----------------------------------------------------------------
    -- 2. LEADERBOARD
    ----------------------------------------------------------------

    local lbHeader = CreateSectionHeader(content, "Guild Leaderboard", 0, yOffset)
    yOffset = yOffset - 22

    -- Column headers
    local LB_COL_NAME = 0
    local LB_COL_LEVEL = 150
    local LB_COL_DUNGEON = 200
    local LB_COL_PROGRESS = 380
    local LB_COL_SEEN = 500

    local colName = CreateLabel(content, "Name", "GameFontNormalSmall")
    colName:SetPoint("TOPLEFT", content, "TOPLEFT", LB_COL_NAME, yOffset)
    colName:SetTextColor(0.7, 0.7, 0.7, 1)

    local colLevel = CreateLabel(content, "Level", "GameFontNormalSmall")
    colLevel:SetPoint("TOPLEFT", content, "TOPLEFT", LB_COL_LEVEL, yOffset)
    colLevel:SetTextColor(0.7, 0.7, 0.7, 1)

    local colDungeon = CreateLabel(content, "Current Dungeon", "GameFontNormalSmall")
    colDungeon:SetPoint("TOPLEFT", content, "TOPLEFT", LB_COL_DUNGEON, yOffset)
    colDungeon:SetTextColor(0.7, 0.7, 0.7, 1)

    local colProgress = CreateLabel(content, "Progress", "GameFontNormalSmall")
    colProgress:SetPoint("TOPLEFT", content, "TOPLEFT", LB_COL_PROGRESS, yOffset)
    colProgress:SetTextColor(0.7, 0.7, 0.7, 1)

    local colSeen = CreateLabel(content, "Last Seen", "GameFontNormalSmall")
    colSeen:SetPoint("TOPLEFT", content, "TOPLEFT", LB_COL_SEEN, yOffset)
    colSeen:SetTextColor(0.7, 0.7, 0.7, 1)

    yOffset = yOffset - 16

    GW.leaderboardRowsStartY = yOffset
    GW.leaderboardRows = {}
    GW.LB_COLS = { NAME = LB_COL_NAME, LEVEL = LB_COL_LEVEL, DUNGEON = LB_COL_DUNGEON, PROGRESS = LB_COL_PROGRESS, SEEN = LB_COL_SEEN }

    -- Empty state
    local lbEmpty = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbEmpty:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    lbEmpty:SetText("No guild members synced yet.")
    lbEmpty:SetTextColor(0.5, 0.5, 0.5, 1)
    GW.lbEmpty = lbEmpty

    -- Store planning view start offset (will be computed dynamically in refresh)
    GW.planningStartY = yOffset - 20
```

**Step 2: Add leaderboard refresh logic to RefreshGuildTab**

In `RefreshGuildTab`, after the LFG section, add:

```lua
    ----------------------------------------------------------------
    -- 2. Leaderboard
    ----------------------------------------------------------------
    local sorted = BoneyardTBC_DO.Sync.GetSortedRoster()
    local content = GW.content
    local LB = GW.LB_COLS
    local ROW_H = 18

    -- Hide existing rows
    for _, row in ipairs(GW.leaderboardRows) do
        row.nameText:Hide()
        row.levelText:Hide()
        row.dungeonText:Hide()
        row.progressText:Hide()
        row.seenText:Hide()
    end

    if #sorted == 0 then
        GW.lbEmpty:Show()
        GW.planningStartY = GW.leaderboardRowsStartY - 20
    else
        GW.lbEmpty:Hide()
        local rowY = GW.leaderboardRowsStartY

        for i, entry in ipairs(sorted) do
            local row = GW.leaderboardRows[i]
            if not row then
                row = {}
                row.nameText = CreateLabel(content, "", "GameFontNormalSmall")
                row.levelText = CreateLabel(content, "", "GameFontNormalSmall")
                row.dungeonText = CreateLabel(content, "", "GameFontNormalSmall")
                row.progressText = CreateLabel(content, "", "GameFontNormalSmall")
                row.seenText = CreateLabel(content, "", "GameFontNormalSmall")
                GW.leaderboardRows[i] = row
            end

            local data = entry.data
            local isStale = data.lastSeen and (time() - data.lastSeen) > 86400
            local textColor = data.isOnline and { 0.9, 0.9, 0.9 } or { 0.5, 0.5, 0.5 }
            if isStale then textColor = { 0.4, 0.4, 0.4 } end

            -- Name
            row.nameText:ClearAllPoints()
            row.nameText:SetPoint("TOPLEFT", content, "TOPLEFT", LB.NAME, rowY)
            row.nameText:SetText(entry.name)
            row.nameText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
            row.nameText:Show()

            -- Level
            row.levelText:ClearAllPoints()
            row.levelText:SetPoint("TOPLEFT", content, "TOPLEFT", LB.LEVEL, rowY)
            row.levelText:SetText(tostring(data.level))
            row.levelText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
            row.levelText:Show()

            -- Dungeon
            local dungeonName = "—"
            if data.dungeon and data.dungeon ~= "" then
                local dungeon = BoneyardTBC_DO.DUNGEONS[data.dungeon]
                dungeonName = (dungeon and dungeon.name) or data.dungeon
                if data.runsDone and data.runsTotal and data.runsTotal > 0 then
                    dungeonName = dungeonName .. " (" .. data.runsDone .. "/" .. data.runsTotal .. ")"
                end
            end
            row.dungeonText:ClearAllPoints()
            row.dungeonText:SetPoint("TOPLEFT", content, "TOPLEFT", LB.DUNGEON, rowY)
            row.dungeonText:SetText(dungeonName)
            row.dungeonText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
            row.dungeonText:Show()

            -- Progress (step X/132)
            local stepNum = data.currentStep or 0
            local pctText = string.format("Step %d/132", stepNum)
            row.progressText:ClearAllPoints()
            row.progressText:SetPoint("TOPLEFT", content, "TOPLEFT", LB.PROGRESS, rowY)
            row.progressText:SetText(pctText)
            row.progressText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
            row.progressText:Show()

            -- Last Seen
            local seenText = "Now"
            if not data.isOnline and data.lastSeen then
                local ago = time() - data.lastSeen
                if ago < 3600 then
                    seenText = math.floor(ago / 60) .. "m ago"
                elseif ago < 86400 then
                    seenText = math.floor(ago / 3600) .. "h ago"
                else
                    seenText = math.floor(ago / 86400) .. "d ago"
                end
            end
            row.seenText:ClearAllPoints()
            row.seenText:SetPoint("TOPLEFT", content, "TOPLEFT", LB.SEEN, rowY)
            row.seenText:SetText(seenText)
            row.seenText:SetTextColor(textColor[1], textColor[2], textColor[3], 1)
            row.seenText:Show()

            rowY = rowY - ROW_H
        end

        GW.planningStartY = GW.leaderboardRowsStartY - (#sorted * ROW_H) - 16
    end
```

**Step 3: Commit**

```bash
git add BoneyardTBC_DungeonOptimizer/UI.lua
git commit -m "feat: Guild tab leaderboard with sorted roster display"
```

---

### Task 7: Guild Tab — Planning View Section

**Context:** Add the "Who Needs What" planning view as the bottom section of the Guild tab. Shows dungeons with active guildies aggregated.

**Files:**
- Modify: `BoneyardTBC_DungeonOptimizer/UI.lua` (expand CreateGuildTab and RefreshGuildTab)

**Step 1: Add planning section to CreateGuildTab**

In `CreateGuildTab`, after the leaderboard section (before the `tab:SetScript("OnShow"` block), add:

```lua
    ----------------------------------------------------------------
    -- 3. PLANNING VIEW — Who Needs What
    ----------------------------------------------------------------

    local planHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    planHeader:SetText("Who Needs What")
    planHeader:SetTextColor(1, 0.82, 0, 1)
    GW.planHeader = planHeader

    GW.planRows = {}

    local planEmpty = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    planEmpty:SetText("No active dungeon groups found.")
    planEmpty:SetTextColor(0.5, 0.5, 0.5, 1)
    GW.planEmpty = planEmpty
```

**Step 2: Add planning refresh logic to RefreshGuildTab**

At the end of `RefreshGuildTab`, add:

```lua
    ----------------------------------------------------------------
    -- 3. Planning View
    ----------------------------------------------------------------
    local groups = BoneyardTBC_DO.Sync.GetDungeonGroups()
    local planY = GW.planningStartY

    GW.planHeader:ClearAllPoints()
    GW.planHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, planY)
    planY = planY - 22

    -- Hide existing rows
    for _, row in ipairs(GW.planRows) do
        row.text:Hide()
    end

    if #groups == 0 then
        GW.planEmpty:ClearAllPoints()
        GW.planEmpty:SetPoint("TOPLEFT", content, "TOPLEFT", 10, planY)
        GW.planEmpty:Show()
        planY = planY - 20
    else
        GW.planEmpty:Hide()
        for i, group in ipairs(groups) do
            local row = GW.planRows[i]
            if not row then
                row = {}
                row.text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.text:SetJustifyH("LEFT")
                row.text:SetWordWrap(true)
                GW.planRows[i] = row
            end

            local playerNames = {}
            for _, p in ipairs(group.players) do
                playerNames[#playerNames + 1] = p.name
            end

            local line = string.format("%s: %d guildie%s (%s)",
                group.dungeonName,
                #group.players,
                #group.players > 1 and "s" or "",
                table.concat(playerNames, ", "))

            row.text:ClearAllPoints()
            row.text:SetPoint("TOPLEFT", content, "TOPLEFT", 10, planY)
            row.text:SetPoint("RIGHT", content, "RIGHT", -10, 0)
            row.text:SetText(line)
            row.text:SetTextColor(0.9, 0.9, 0.9, 1)
            row.text:Show()

            planY = planY - 20
        end
    end

    -- Update content height
    local totalHeight = math.abs(planY) + 20
    content:SetHeight(totalHeight)
```

**Step 3: Commit**

```bash
git add BoneyardTBC_DungeonOptimizer/UI.lua
git commit -m "feat: Guild tab planning view with who-needs-what aggregation"
```

---

### Task 8: Deploy & In-Game Testing

**Context:** Copy all changed files to the WoW AddOns directory, reload in-game, and verify the new features work.

**Files:**
- Copy entire `BoneyardTBC/` to WoW AddOns
- Copy entire `BoneyardTBC_DungeonOptimizer/` to WoW AddOns

**Step 1: Copy files to WoW**

```bash
# Core addon (window height change)
cp -R BoneyardTBC/* "/Applications/World of Warcraft/_anniversary_/Interface/AddOns/BoneyardTBC/"

# DungeonOptimizer (all changes)
cp -R BoneyardTBC_DungeonOptimizer/* "/Applications/World of Warcraft/_anniversary_/Interface/AddOns/BoneyardTBC_DungeonOptimizer/"
```

**Step 2: In-game verification checklist**

After `/reload`:
1. `/btbc` opens — verify 4 tabs visible (Setup, Route, Tracker, Guild)
2. Setup tab — verify Sync section with 3 checkboxes between Optional Quests and Rep Goals
3. Guild tab — verify LFG matches section shows "No guildies on your current dungeon."
4. Guild tab — verify leaderboard shows "No guild members synced yet."
5. Guild tab — verify planning view shows "No active dungeon groups found."
6. Verify SavedVariables contain `enableGuildSync`, `enablePartySync`, `enableSyncAlerts`, `guildRoster` keys
7. Run: `/run print(BoneyardTBC_DO.Sync.initialized)` — should print `true`
8. Run: `/run local s = BoneyardTBC_DO.Sync.SerializeStatus(); print(s)` — should print a STATUS message

**Step 3: Push to remote**

```bash
git push origin main
```
