--------------------------------------------------------------------------------
-- Sync.lua
-- Guild & party status sync via addon messages.
-- Handles message protocol, heartbeat, roster management, and alerts.
--
-- Uses WoW's invisible addon message system (SendAddonMessage / CHAT_MSG_ADDON)
-- to share player progress with guildmates and party members.
--------------------------------------------------------------------------------

BoneyardTBC_DO.Sync = {}

local Sync = BoneyardTBC_DO.Sync

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
local ADDON_PREFIX = "BoneyardTBC"
local HEARTBEAT_INTERVAL = 300  -- 5 minutes in seconds
local STALE_THRESHOLD = 86400   -- 24 hours in seconds (greyed out in UI)
local PRUNE_THRESHOLD = 604800  -- 7 days in seconds (removed on login)

-- Message types
local MSG_STATUS = "STATUS"
local MSG_HELLO  = "HELLO"
local MSG_PING   = "PING"
local MSG_PONG   = "PONG"

-- Rep keys in fixed order for serialization
-- Order: Honor Hold, Cenarion Expedition, Consortium, Keepers of Time, Lower City, Sha'tar
local REP_KEYS = { "HONOR_HOLD", "CENARION_EXP", "CONSORTIUM", "KEEPERS_TIME", "LOWER_CITY", "SHATAR" }

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
Sync.guildRoster = {}       -- persisted via DB reference
Sync.partyRoster = {}       -- in-memory only, cleared on group leave
Sync.heartbeatFrame = nil   -- OnUpdate timer frame
Sync.heartbeatElapsed = 0   -- accumulated elapsed time for heartbeat
Sync.initialized = false    -- guard against double init

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
    local route = BoneyardTBC_DO.Optimizer
        and BoneyardTBC_DO.Optimizer.lastResult
        and BoneyardTBC_DO.Optimizer.lastResult.route
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

    -- Rep values in fixed order, colon-separated
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
-- Input: the portion after "STATUS:" e.g. "63,12,SLAVE_PENS,8,32,balanced,6000:4500:0:0:1050:0"
-- Returns: table with level, currentStep, dungeon, runsDone, runsTotal, mode, reps, lastSeen, isOnline
--------------------------------------------------------------------------------
function Sync.DeserializeStatus(payload)
    -- payload format: lvl,step,dungeon,runsDone,runsTotal,mode,HH:CE:CO:KT:LC:SH
    local parts = {}
    for part in payload:gmatch("[^,]+") do
        parts[#parts + 1] = part
    end

    if #parts < 7 then return nil end

    local result = {
        level       = tonumber(parts[1]) or 0,
        currentStep = tonumber(parts[2]) or 1,
        dungeon     = parts[3] ~= "" and parts[3] or nil,
        runsDone    = tonumber(parts[4]) or 0,
        runsTotal   = tonumber(parts[5]) or 0,
        mode        = parts[6] or "balanced",
        reps        = {},
        lastSeen    = time(),
        isOnline    = true,
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
-- RegisterComms: Register addon prefix and set up event handlers
-- Listens for CHAT_MSG_ADDON (incoming messages) and GROUP_ROSTER_UPDATE
--------------------------------------------------------------------------------
function Sync.RegisterComms()
    -- Register the addon message prefix (TBC compat)
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
-- CHAT_MSG_ADDON fires with: prefix, message, channel, sender
--------------------------------------------------------------------------------
function Sync.OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_PREFIX then return end

    -- Don't process our own messages
    -- Sender may arrive as "Name-Server" in TBC Classic; UnitName returns just "Name"
    local playerName = UnitName("player")
    local senderName = sender:match("^([^%-]+)") or sender
    if senderName == playerName then return end

    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return end

    -- Check enable flags for the channel before processing anything
    if channel == "GUILD" and db.enableGuildSync == false then return end
    if channel == "PARTY" and db.enablePartySync == false then return end

    -- Parse message type and payload: "MSGTYPE:payload"
    local msgType, payload = message:match("^(%u+):(.+)$")
    if not msgType then
        -- Messages without payload (shouldn't happen with our protocol, but guard)
        msgType = message:match("^(%u+)$")
        if not msgType then return end
        payload = ""
    end

    if msgType == MSG_STATUS then
        local data = Sync.DeserializeStatus(payload)
        if not data then return end

        if channel == "GUILD" then
            Sync.guildRoster[senderName] = data
            Sync.CheckDungeonMatchAlert(senderName, data)
        elseif channel == "PARTY" then
            Sync.partyRoster[senderName] = data
        end

        -- Refresh guild tab if visible
        Sync.RefreshGuildTab()

    elseif msgType == MSG_HELLO then
        if channel == "GUILD" then
            -- Respond with our status so the new login gets our data
            Sync.BroadcastStatus("GUILD")
        end

    elseif msgType == MSG_PING then
        if channel == "PARTY" then
            -- Respond with PONG to confirm addon presence, then send STATUS
            Sync.SendMessage(MSG_PONG .. ":1", "PARTY")
            Sync.BroadcastStatus("PARTY")
        end

    elseif msgType == MSG_PONG then
        -- Addon user confirmed in party; their STATUS will follow
        -- (no action needed, STATUS message follows automatically)
        return
    end
end

--------------------------------------------------------------------------------
-- SendMessage: Wrapper around SendAddonMessage with TBC compat
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
-- Respects enable flags and channel prerequisites (guild membership / group)
--------------------------------------------------------------------------------
function Sync.BroadcastStatus(channel)
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return end

    -- Respect per-channel enable flags
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
-- BroadcastAll: Send status on both GUILD and PARTY channels
--------------------------------------------------------------------------------
function Sync.BroadcastAll()
    Sync.BroadcastStatus("GUILD")
    Sync.BroadcastStatus("PARTY")
end

--------------------------------------------------------------------------------
-- StartHeartbeat: Begin the periodic broadcast timer (OnUpdate every 5 min)
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
    Sync.heartbeatElapsed = 0
end

--------------------------------------------------------------------------------
-- OnGroupChanged: Called on GROUP_ROSTER_UPDATE
-- If in a group: PING for addon users + broadcast our STATUS
-- If left group: wipe the party roster
--------------------------------------------------------------------------------
function Sync.OnGroupChanged()
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db or db.enablePartySync == false then return end

    if IsInGroup() then
        -- Ping to discover addon users in the group
        Sync.SendMessage(MSG_PING .. ":1", "PARTY")
        -- Broadcast our status to the party
        Sync.BroadcastStatus("PARTY")
    else
        -- Left group: clear party roster
        wipe(Sync.partyRoster)
        Sync.RefreshGuildTab()
    end
end

--------------------------------------------------------------------------------
-- PruneStaleEntries: Remove entries older than 7 days from guildRoster
-- Returns: number of entries pruned
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

    -- Load persisted guild roster from DB (or create fresh)
    if db.guildRoster then
        Sync.guildRoster = db.guildRoster
    else
        db.guildRoster = {}
        Sync.guildRoster = db.guildRoster
    end

    -- Mark all entries as offline initially
    -- HELLO responses from online guildies will set isOnline = true
    for _, data in pairs(Sync.guildRoster) do
        data.isOnline = false
    end

    -- Prune entries older than 7 days
    Sync.PruneStaleEntries()

    -- Register communications (prefix + event frame)
    Sync.RegisterComms()

    -- Send HELLO to guild after a short delay (let other addons load)
    if db.enableGuildSync ~= false and IsInGuild() then
        C_Timer.After(3, function()
            Sync.SendMessage(MSG_HELLO .. ":1", "GUILD")
            Sync.BroadcastStatus("GUILD")
        end)
    end

    -- Check if already in a group (e.g. reload during dungeon)
    if db.enablePartySync ~= false and IsInGroup() then
        C_Timer.After(3, function()
            Sync.SendMessage(MSG_PING .. ":1", "PARTY")
            Sync.BroadcastStatus("PARTY")
        end)
    end

    -- Start the 5-minute heartbeat timer
    Sync.StartHeartbeat()

    Sync.initialized = true
end

--------------------------------------------------------------------------------
-- CheckDungeonMatchAlert: Alert if a guildie is on the same dungeon as us
-- Only fires if enableSyncAlerts is on and we're currently on a dungeon step
--------------------------------------------------------------------------------
function Sync.CheckDungeonMatchAlert(senderName, senderData)
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db or db.enableSyncAlerts == false then return end

    -- Find our current dungeon from the route
    local myDungeon = nil
    local route = BoneyardTBC_DO.Optimizer
        and BoneyardTBC_DO.Optimizer.lastResult
        and BoneyardTBC_DO.Optimizer.lastResult.route
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
        if BoneyardTBC_DO.Overlay then
            BoneyardTBC_DO.Overlay.FireAlert("GUILD_MATCH", senderName .. " is also running " .. dungeonName .. "!")
        else
            print("|cff00ccffBoneyard:|r " .. senderName .. " is also running " .. dungeonName .. "!")
        end
    end
end

--------------------------------------------------------------------------------
-- RefreshGuildTab: Notify the UI to refresh the Guild tab if it exists
--------------------------------------------------------------------------------
function Sync.RefreshGuildTab()
    local DO = BoneyardTBC_DO.module
    if DO and DO.RefreshGuildTab then
        DO:RefreshGuildTab()
    end
end

--------------------------------------------------------------------------------
-- GetDungeonMatches: Find guildies on the same dungeon as the player
-- Returns: array of { name = "PlayerName", data = { ... } }
--------------------------------------------------------------------------------
function Sync.GetDungeonMatches()
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return {} end

    -- Find our current dungeon from the route
    local myDungeon = nil
    local route = BoneyardTBC_DO.Optimizer
        and BoneyardTBC_DO.Optimizer.lastResult
        and BoneyardTBC_DO.Optimizer.lastResult.route
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
-- GetDungeonGroups: Aggregate guildies by dungeon for the planning view
-- Returns: sorted array of { dungeon = "KEY", dungeonName = "Name", players = { {name, data}, ... } }
-- Sorted by number of players descending
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
            local players = groupMap[data.dungeon].players
            players[#players + 1] = { name = name, data = data }
        end
    end

    -- Add readable dungeon names
    for _, group in ipairs(groups) do
        local dungeon = BoneyardTBC_DO.DUNGEONS[group.dungeon]
        group.dungeonName = (dungeon and dungeon.name) or group.dungeon
    end

    -- Sort by number of players (descending), then dungeon name (ascending) for ties
    table.sort(groups, function(a, b)
        if #a.players ~= #b.players then
            return #a.players > #b.players
        end
        return (a.dungeonName or "") < (b.dungeonName or "")
    end)

    return groups
end

--------------------------------------------------------------------------------
-- GetSortedRoster: Return the guild roster sorted by level desc, then step desc
-- Returns: array of { name = "PlayerName", data = { ... } }
--------------------------------------------------------------------------------
function Sync.GetSortedRoster()
    local sorted = {}

    for name, data in pairs(Sync.guildRoster) do
        sorted[#sorted + 1] = { name = name, data = data }
    end

    table.sort(sorted, function(a, b)
        -- Sort by level descending
        if a.data.level ~= b.data.level then
            return a.data.level > b.data.level
        end
        -- Then by step descending
        if a.data.currentStep ~= b.data.currentStep then
            return a.data.currentStep > b.data.currentStep
        end
        -- Fallback: alphabetical by name
        return a.name < b.name
    end)

    return sorted
end
