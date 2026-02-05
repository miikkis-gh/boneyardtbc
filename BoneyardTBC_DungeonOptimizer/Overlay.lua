--------------------------------------------------------------------------------
-- Overlay.lua
-- Combined floating overlay: instance lockout timer + session stats + alerts.
--------------------------------------------------------------------------------

BoneyardTBC_DO.Overlay = {}

local Overlay = BoneyardTBC_DO.Overlay

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
local LOCKOUT_MAX = 5
local LOCKOUT_WINDOW = 3600 -- 1 hour in seconds
local UPDATE_INTERVAL = 1   -- refresh every 1 second

-- WoW Sound IDs (TBC Classic compatible)
local SOUNDS = {
    QUEST_COMPLETE = 5275,  -- SOUNDKIT.UI_QUEST_COMPLETE (fanfare)
    REPUTATION_UP  = 8960,  -- character rep level up
    RAID_WARNING   = 8959,  -- SOUNDKIT.RAID_WARNING
    FRIEND_JOIN    = 3332,  -- igPlayerInvite (subtle notification chime)
}

-- Alert type to sound mapping
local ALERT_SOUNDS = {
    RUN_COMPLETE    = "FRIEND_JOIN",
    STEP_ADVANCED   = "QUEST_COMPLETE",
    REP_MILESTONE   = "REPUTATION_UP",
    LOCKOUT_WARNING = "RAID_WARNING",
    LOCKOUT_HIT     = "RAID_WARNING",
    GUILD_MATCH     = "FRIEND_JOIN",
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
Overlay.sessionStartTime = nil
Overlay.sessionXPStart = 0
Overlay.sessionLevelStart = 1
Overlay.sessionRuns = 0
Overlay.sessionRunTimes = {}  -- array of run durations in seconds
Overlay.sessionRepStarts = {} -- faction -> starting rep value
Overlay.currentRunStart = nil -- GetTime() when entered instance
Overlay.previousStandings = {} -- faction -> standing name (for milestone detection)
Overlay.frame = nil
Overlay.elapsed = 0

--------------------------------------------------------------------------------
-- CreateOverlayFrame: Build the compact floating panel
--------------------------------------------------------------------------------
function Overlay.CreateOverlayFrame()
    if Overlay.frame then return end

    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return end

    local f = CreateFrame("Frame", "BoneyardTBC_DOOverlay", UIParent, "BackdropTemplate")
    f:SetSize(180, 100)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)

    -- Restore position
    local pos = db.overlayPosition
    if pos then
        f:SetPoint(pos.point or "TOPRIGHT", UIParent, pos.point or "TOPRIGHT", pos.x or -20, pos.y or -200)
    else
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -200)
    end

    -- Drag scripts
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        if db then
            db.overlayPosition = { point = point, x = x, y = y }
        end
    end)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -4)
    title:SetText("Boneyard Stats")
    title:SetTextColor(1, 0.82, 0, 1)

    -- Lockout line
    local lockoutText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lockoutText:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -18)
    lockoutText:SetText("Lockout:  0/5 | Ready")
    lockoutText:SetTextColor(0.9, 0.9, 0.9, 1)
    Overlay.lockoutText = lockoutText

    -- Runs line
    local runsText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    runsText:SetPoint("TOPLEFT", lockoutText, "BOTTOMLEFT", 0, -2)
    runsText:SetText("Runs:     0 this session")
    runsText:SetTextColor(0.9, 0.9, 0.9, 1)
    Overlay.runsText = runsText

    -- XP/hr line
    local xphrText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    xphrText:SetPoint("TOPLEFT", runsText, "BOTTOMLEFT", 0, -2)
    xphrText:SetText("XP/hr:    \226\128\148")
    xphrText:SetTextColor(0.9, 0.9, 0.9, 1)
    Overlay.xphrText = xphrText

    -- Rep/hr line
    local rephrText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rephrText:SetPoint("TOPLEFT", xphrText, "BOTTOMLEFT", 0, -2)
    rephrText:SetText("Rep/hr:   \226\128\148")
    rephrText:SetTextColor(0.9, 0.9, 0.9, 1)
    Overlay.rephrText = rephrText

    -- Avg run line
    local avgRunText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    avgRunText:SetPoint("TOPLEFT", rephrText, "BOTTOMLEFT", 0, -2)
    avgRunText:SetText("Avg Run:  \226\128\148")
    avgRunText:SetTextColor(0.9, 0.9, 0.9, 1)
    Overlay.avgRunText = avgRunText

    -- OnUpdate timer
    f:SetScript("OnUpdate", function(_, dt)
        Overlay.elapsed = Overlay.elapsed + dt
        if Overlay.elapsed >= UPDATE_INTERVAL then
            Overlay.elapsed = 0
            Overlay.Refresh()
        end
    end)

    Overlay.frame = f

    -- Apply initial visibility
    if db.showOverlay == false then
        f:Hide()
    else
        f:Show()
    end
end

--------------------------------------------------------------------------------
-- Refresh: Update all overlay lines (called every 1 second by OnUpdate)
--------------------------------------------------------------------------------
function Overlay.Refresh()
    Overlay.UpdateLockout()
    Overlay.UpdateSessionStats()
end

--------------------------------------------------------------------------------
-- UpdateLockout: Recalculate X/5 and countdown from Tracker.instanceEntries
--------------------------------------------------------------------------------
function Overlay.UpdateLockout()
    if not Overlay.lockoutText then return end

    local entries = BoneyardTBC_DO.Tracker and BoneyardTBC_DO.Tracker.instanceEntries or {}
    local now = time()
    local cutoff = now - LOCKOUT_WINDOW

    -- Count valid entries (within last hour)
    local count = 0
    local oldestValid = nil
    for _, t in ipairs(entries) do
        if t > cutoff then
            count = count + 1
            if not oldestValid or t < oldestValid then
                oldestValid = t
            end
        end
    end

    -- Format countdown
    local timerStr = "Ready"
    if oldestValid then
        local remaining = LOCKOUT_WINDOW - (now - oldestValid)
        if remaining > 0 then
            local mins = math.ceil(remaining / 60)
            timerStr = mins .. "m"
        else
            timerStr = "Ready"
        end
    end

    local text = string.format("Lockout:  %d/%d | %s", count, LOCKOUT_MAX, timerStr)
    Overlay.lockoutText:SetText(text)

    -- Color based on count
    if count >= 5 then
        Overlay.lockoutText:SetTextColor(1, 0.2, 0.2, 1)
    elseif count >= 4 then
        Overlay.lockoutText:SetTextColor(1, 0.6, 0.2, 1)
    else
        Overlay.lockoutText:SetTextColor(0.9, 0.9, 0.9, 1)
    end
end

--------------------------------------------------------------------------------
-- FormatNumber: Add comma separators (local helper)
--------------------------------------------------------------------------------
local function FormatNumber(n)
    if not n or type(n) ~= "number" then return "0" end
    local formatted = tostring(math.floor(n))
    while true do
        local k
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

--------------------------------------------------------------------------------
-- UpdateSessionStats: Compute XP/hr, rep/hr, avg run time
--------------------------------------------------------------------------------
function Overlay.UpdateSessionStats()
    if not Overlay.runsText then return end

    -- Runs
    Overlay.runsText:SetText("Runs:     " .. Overlay.sessionRuns .. " this session")

    -- Session duration
    local sessionDuration = 0
    if Overlay.sessionStartTime then
        sessionDuration = GetTime() - Overlay.sessionStartTime
    end

    -- XP/hr
    if sessionDuration > 60 then -- need at least 1 minute of data
        local playerState = BoneyardTBC_DO.Tracker and BoneyardTBC_DO.Tracker.playerState
        local currentTotalXP = 0
        if playerState then
            -- Approximate total XP: sum XP_TO_LEVEL for levels gained + current XP
            local startLevel = Overlay.sessionLevelStart or (playerState.level or 1)
            for lvl = startLevel, (playerState.level or 1) - 1 do
                currentTotalXP = currentTotalXP + (BoneyardTBC_DO.XP_TO_LEVEL[lvl] or 0)
            end
            currentTotalXP = currentTotalXP + (playerState.xp or 0) - Overlay.sessionXPStart
        end

        local hours = sessionDuration / 3600
        if hours > 0 and currentTotalXP > 0 then
            Overlay.xphrText:SetText("XP/hr:    " .. FormatNumber(math.floor(currentTotalXP / hours)))
        else
            Overlay.xphrText:SetText("XP/hr:    \226\128\148")
        end

        -- Rep/hr (for current dungeon's faction)
        local repGained = Overlay.GetSessionRepGained()
        if hours > 0 and repGained > 0 then
            local factionAbbrev = Overlay.GetCurrentFactionAbbrev()
            Overlay.rephrText:SetText("Rep/hr:   " .. FormatNumber(math.floor(repGained / hours)) .. " (" .. factionAbbrev .. ")")
        else
            Overlay.rephrText:SetText("Rep/hr:   \226\128\148")
        end
    else
        Overlay.xphrText:SetText("XP/hr:    \226\128\148")
        Overlay.rephrText:SetText("Rep/hr:   \226\128\148")
    end

    -- Avg run time
    if #Overlay.sessionRunTimes > 0 then
        local total = 0
        for _, t in ipairs(Overlay.sessionRunTimes) do
            total = total + t
        end
        local avg = total / #Overlay.sessionRunTimes
        local mins = math.floor(avg / 60)
        local secs = math.floor(avg % 60)
        Overlay.avgRunText:SetText(string.format("Avg Run:  %dm %02ds", mins, secs))
    else
        Overlay.avgRunText:SetText("Avg Run:  \226\128\148")
    end
end

--------------------------------------------------------------------------------
-- GetSessionRepGained: Get rep gained this session for current dungeon's faction
--------------------------------------------------------------------------------
function Overlay.GetSessionRepGained()
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    local playerState = BoneyardTBC_DO.Tracker and BoneyardTBC_DO.Tracker.playerState
    if not db or not playerState or not playerState.reps then return 0 end

    -- Find current dungeon's faction
    local route = BoneyardTBC_DO.Optimizer and BoneyardTBC_DO.Optimizer.lastResult and BoneyardTBC_DO.Optimizer.lastResult.route
    local myStep = db.currentStep or 1
    local factionKey = nil
    if route then
        for _, routeStep in ipairs(route) do
            if routeStep.step == myStep and routeStep.type == "dungeon" then
                factionKey = routeStep.faction or (BoneyardTBC_DO.DUNGEONS[routeStep.dungeon] and BoneyardTBC_DO.DUNGEONS[routeStep.dungeon].faction)
                break
            end
        end
    end

    if not factionKey then return 0 end

    local currentRep = playerState.reps[factionKey] or 0
    local startRep = Overlay.sessionRepStarts and Overlay.sessionRepStarts[factionKey] or currentRep
    return math.max(0, currentRep - startRep)
end

--------------------------------------------------------------------------------
-- GetCurrentFactionAbbrev: Short name for current dungeon's faction
--------------------------------------------------------------------------------
local FACTION_ABBREVS = {
    HONOR_HOLD = "HH", CENARION_EXP = "CE", CONSORTIUM = "CO",
    KEEPERS_TIME = "KT", LOWER_CITY = "LC", SHATAR = "SH",
}

function Overlay.GetCurrentFactionAbbrev()
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return "\226\128\148" end

    local route = BoneyardTBC_DO.Optimizer and BoneyardTBC_DO.Optimizer.lastResult and BoneyardTBC_DO.Optimizer.lastResult.route
    local myStep = db.currentStep or 1
    if route then
        for _, routeStep in ipairs(route) do
            if routeStep.step == myStep and routeStep.type == "dungeon" then
                local fk = routeStep.faction or (BoneyardTBC_DO.DUNGEONS[routeStep.dungeon] and BoneyardTBC_DO.DUNGEONS[routeStep.dungeon].faction)
                return FACTION_ABBREVS[fk] or "\226\128\148"
            end
        end
    end
    return "\226\128\148"
end

--------------------------------------------------------------------------------
-- StartSession: Initialize session tracking (called on PLAYER_LOGIN)
--------------------------------------------------------------------------------
function Overlay.StartSession()
    Overlay.sessionStartTime = GetTime()
    Overlay.sessionRuns = 0
    Overlay.sessionRunTimes = {}
    Overlay.currentRunStart = nil

    -- Snapshot starting XP
    local playerState = BoneyardTBC_DO.Tracker and BoneyardTBC_DO.Tracker.playerState
    if playerState then
        Overlay.sessionXPStart = playerState.xp or 0
        Overlay.sessionLevelStart = playerState.level or 1
    else
        Overlay.sessionXPStart = 0
        Overlay.sessionLevelStart = 1
    end

    -- Snapshot starting rep for all factions
    Overlay.sessionRepStarts = {}
    if playerState and playerState.reps then
        for k, v in pairs(playerState.reps) do
            Overlay.sessionRepStarts[k] = v
        end
    end

    -- Snapshot current standings for milestone detection
    Overlay.SnapshotStandings()
end

--------------------------------------------------------------------------------
-- SnapshotStandings: Record current rep standings for milestone detection
--------------------------------------------------------------------------------
function Overlay.SnapshotStandings()
    local playerState = BoneyardTBC_DO.Tracker and BoneyardTBC_DO.Tracker.playerState
    if not playerState or not playerState.reps then return end

    Overlay.previousStandings = {}
    local levels = BoneyardTBC_DO.REP_LEVELS
    for factionKey, rep in pairs(playerState.reps) do
        for i = #levels, 1, -1 do
            if rep >= levels[i].min then
                Overlay.previousStandings[factionKey] = levels[i].name
                break
            end
        end
    end
end

--------------------------------------------------------------------------------
-- CheckRepMilestones: Compare current standings to previous, fire alerts
--------------------------------------------------------------------------------
function Overlay.CheckRepMilestones()
    local playerState = BoneyardTBC_DO.Tracker and BoneyardTBC_DO.Tracker.playerState
    if not playerState or not playerState.reps then return end

    local levels = BoneyardTBC_DO.REP_LEVELS
    for factionKey, rep in pairs(playerState.reps) do
        local currentStanding = nil
        for i = #levels, 1, -1 do
            if rep >= levels[i].min then
                currentStanding = levels[i].name
                break
            end
        end

        local prevStanding = Overlay.previousStandings[factionKey]
        if currentStanding and prevStanding and currentStanding ~= prevStanding then
            local factionData = BoneyardTBC_DO.FACTIONS[factionKey]
            local factionName = factionData and factionData.name or factionKey
            Overlay.FireAlert("REP_MILESTONE", currentStanding .. " with " .. factionName .. "!")
        end
    end

    -- Update snapshots
    Overlay.SnapshotStandings()
end

--------------------------------------------------------------------------------
-- OnInstanceEnter: Called when player enters a dungeon instance
--------------------------------------------------------------------------------
function Overlay.OnInstanceEnter()
    Overlay.currentRunStart = GetTime()
end

--------------------------------------------------------------------------------
-- OnInstanceExit: Called when player exits a dungeon instance
--------------------------------------------------------------------------------
function Overlay.OnInstanceExit()
    if Overlay.currentRunStart then
        local runDuration = GetTime() - Overlay.currentRunStart
        if runDuration > 30 then -- ignore very short entries (zoning errors)
            Overlay.sessionRunTimes[#Overlay.sessionRunTimes + 1] = runDuration
        end
        Overlay.currentRunStart = nil
    end
    Overlay.sessionRuns = Overlay.sessionRuns + 1
end

--------------------------------------------------------------------------------
-- FireAlert: Print chat message + play sound
--------------------------------------------------------------------------------
function Overlay.FireAlert(alertType, message)
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db

    -- Always print chat message
    if message then
        print("|cff00ccffBoneyard:|r " .. message)
    end

    -- Play sound if enabled
    if db and db.enableSoundAlerts ~= false then
        local soundKey = ALERT_SOUNDS[alertType]
        if soundKey then
            local sound = SOUNDS[soundKey]
            if type(sound) == "number" then
                PlaySound(sound)
            elseif type(sound) == "string" then
                PlaySoundFile(sound)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- SetVisible: Show or hide the overlay
--------------------------------------------------------------------------------
function Overlay.SetVisible(visible)
    if Overlay.frame then
        if visible then
            Overlay.frame:Show()
        else
            Overlay.frame:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- Initialize: Create frame and start session (called from DungeonOptimizer.lua)
--------------------------------------------------------------------------------
function Overlay.Initialize()
    Overlay.CreateOverlayFrame()
    Overlay.StartSession()
end
