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
local SESSION_TIMEOUT = 21600 -- 6 hours: sessions older than this reset on login

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

    local PADDING = 8
    local LINE_HEIGHT = 13
    local LINE_GAP = 3
    local FRAME_W = 160
    local LABEL_COLOR = { 0.6, 0.6, 0.6 }
    local VALUE_COLOR = { 1, 1, 1 }

    local f = CreateFrame("Frame", "BoneyardTBC_DOOverlay", UIParent, "BackdropTemplate")
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
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.88)
    f:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.9)

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

    -- Helper: create a label + value pair on the same row
    local function CreateRow(anchorTo, offsetY, labelText)
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", 0, offsetY)
        label:SetText(labelText)
        label:SetTextColor(LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3], 1)

        local value = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        value:SetPoint("TOPRIGHT", anchorTo, "TOPRIGHT", 0, offsetY)
        value:SetJustifyH("RIGHT")
        value:SetTextColor(VALUE_COLOR[1], VALUE_COLOR[2], VALUE_COLOR[3], 1)

        return label, value
    end

    -- Content anchor (inset from frame edges)
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -PADDING)
    content:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PADDING, -PADDING)
    content:SetHeight(1)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", content)
    title:SetText("Boneyard")
    title:SetTextColor(0, 0.8, 1, 1)

    -- Separator line
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(LINE_HEIGHT + 2))
    sep:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(LINE_HEIGHT + 2))
    sep:SetColorTexture(0.3, 0.3, 0.35, 0.6)

    -- Row positions (below separator)
    local rowTop = -(LINE_HEIGHT + 2 + 4) -- after title + sep + gap
    local rowStep = -(LINE_HEIGHT + LINE_GAP)

    -- Lockout row
    local _, lockoutVal = CreateRow(content, rowTop, "Lockout")
    lockoutVal:SetText("0/5 | Ready")
    Overlay.lockoutVal = lockoutVal

    -- Runs row
    local _, runsVal = CreateRow(content, rowTop + rowStep, "Runs")
    runsVal:SetText("0")
    Overlay.runsVal = runsVal

    -- XP/hr row
    local _, xphrVal = CreateRow(content, rowTop + rowStep * 2, "XP/hr")
    xphrVal:SetText("\226\128\148")
    Overlay.xphrVal = xphrVal

    -- Rep/hr row
    local _, rephrVal = CreateRow(content, rowTop + rowStep * 3, "Rep/hr")
    rephrVal:SetText("\226\128\148")
    Overlay.rephrVal = rephrVal

    -- Avg Run row
    local _, avgRunVal = CreateRow(content, rowTop + rowStep * 4, "Avg Run")
    avgRunVal:SetText("\226\128\148")
    Overlay.avgRunVal = avgRunVal

    -- Calculate frame height from content
    local totalHeight = PADDING + LINE_HEIGHT + 2 + 4 + (LINE_HEIGHT + LINE_GAP) * 5 + PADDING
    f:SetSize(FRAME_W, totalHeight)

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
    if not Overlay.lockoutVal then return end

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

    Overlay.lockoutVal:SetText(string.format("%d/%d | %s", count, LOCKOUT_MAX, timerStr))

    -- Color based on count
    if count >= 5 then
        Overlay.lockoutVal:SetTextColor(1, 0.2, 0.2, 1)
    elseif count >= 4 then
        Overlay.lockoutVal:SetTextColor(1, 0.6, 0.2, 1)
    else
        Overlay.lockoutVal:SetTextColor(1, 1, 1, 1)
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
    if not Overlay.runsVal then return end

    -- Runs
    Overlay.runsVal:SetText(tostring(Overlay.sessionRuns))

    -- Session duration (time() persists across /reload)
    local sessionDuration = 0
    if Overlay.sessionStartTime then
        sessionDuration = time() - Overlay.sessionStartTime
    end

    local dash = "\226\128\148"

    -- XP/hr
    if sessionDuration > 60 then
        local playerState = BoneyardTBC_DO.Tracker and BoneyardTBC_DO.Tracker.playerState
        local currentTotalXP = 0
        if playerState then
            local startLevel = Overlay.sessionLevelStart or (playerState.level or 1)
            for lvl = startLevel, (playerState.level or 1) - 1 do
                currentTotalXP = currentTotalXP + (BoneyardTBC_DO.XP_TO_LEVEL[lvl] or 0)
            end
            currentTotalXP = currentTotalXP + (playerState.xp or 0) - Overlay.sessionXPStart
        end

        local hours = sessionDuration / 3600
        if hours > 0 and currentTotalXP > 0 then
            Overlay.xphrVal:SetText(FormatNumber(math.floor(currentTotalXP / hours)))
        else
            Overlay.xphrVal:SetText(dash)
        end

        -- Rep/hr
        local repGained = Overlay.GetSessionRepGained()
        if hours > 0 and repGained > 0 then
            local factionAbbrev = Overlay.GetCurrentFactionAbbrev()
            Overlay.rephrVal:SetText(FormatNumber(math.floor(repGained / hours)) .. " " .. factionAbbrev)
        else
            Overlay.rephrVal:SetText(dash)
        end
    else
        Overlay.xphrVal:SetText(dash)
        Overlay.rephrVal:SetText(dash)
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
        Overlay.avgRunVal:SetText(string.format("%dm %02ds", mins, secs))
    else
        Overlay.avgRunVal:SetText(dash)
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
-- StartSession: Initialize fresh session tracking
--------------------------------------------------------------------------------
function Overlay.StartSession()
    Overlay.sessionStartTime = time()
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
    Overlay.SaveSession()
end

--------------------------------------------------------------------------------
-- RestoreSession: Load session state from saved data
--------------------------------------------------------------------------------
function Overlay.RestoreSession(session)
    Overlay.sessionStartTime = session.startTime
    Overlay.sessionXPStart = session.xpStart or 0
    Overlay.sessionLevelStart = session.levelStart or 1
    Overlay.sessionRuns = session.runs or 0
    Overlay.sessionRunTimes = session.runTimes or {}
    Overlay.sessionRepStarts = session.repStarts or {}
    Overlay.currentRunStart = nil

    Overlay.SnapshotStandings()
end

--------------------------------------------------------------------------------
-- SaveSession: Persist session state to SavedVariables
--------------------------------------------------------------------------------
function Overlay.SaveSession()
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return end

    db.session = {
        startTime  = Overlay.sessionStartTime,
        xpStart    = Overlay.sessionXPStart,
        levelStart = Overlay.sessionLevelStart,
        runs       = Overlay.sessionRuns,
        runTimes   = Overlay.sessionRunTimes,
        repStarts  = Overlay.sessionRepStarts,
    }
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
    Overlay.SaveSession()
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
-- Initialize: Create frame and restore or start session
-- Restores previous session if it exists and is recent (within SESSION_TIMEOUT).
-- Otherwise starts a fresh session. This preserves stats across /reload.
--------------------------------------------------------------------------------
function Overlay.Initialize()
    Overlay.CreateOverlayFrame()

    -- Ensure player state is read before snapshotting session baselines.
    -- Initialize runs on PLAYER_LOGIN, but Tracker reads state on
    -- PLAYER_ENTERING_WORLD which fires later. Force an early read so
    -- StartSession gets real values instead of defaults (level 1, XP 0).
    if BoneyardTBC_DO.Tracker and not BoneyardTBC_DO.Tracker.playerState then
        BoneyardTBC_DO.Tracker.ReadPlayerState()
    end

    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if db and db.session and db.session.startTime
        and (time() - db.session.startTime) < SESSION_TIMEOUT
        and (db.session.levelStart or 0) >= 58 then
        Overlay.RestoreSession(db.session)
    else
        Overlay.StartSession()
    end
end
