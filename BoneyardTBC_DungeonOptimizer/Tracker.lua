--------------------------------------------------------------------------------
-- Tracker.lua
-- Event-driven tracker with auto-advancement logic for the DungeonOptimizer.
-- Listens to WoW game events, reads player state, and auto-advances route
-- steps when completion conditions are met.
--------------------------------------------------------------------------------

BoneyardTBC_DO.Tracker = {}

local Tracker = BoneyardTBC_DO.Tracker

-- Standing bases from Neutral 0 (standingId -> cumulative rep at start of bracket)
local STANDING_BASES = {
    [4] = 0,      -- Neutral
    [5] = 3000,   -- Friendly
    [6] = 9000,   -- Honored
    [7] = 21000,  -- Revered
    [8] = 42000,  -- Exalted
}

-- Quest name cache: questID -> quest title (populated on QUEST_ACCEPTED)
Tracker.questCache = {}

-- Callback that UI.lua can set for step advancement notifications
Tracker.onStepAdvanced = nil

--------------------------------------------------------------------------------
-- Initialize: Create hidden event frame and register events
--------------------------------------------------------------------------------
function Tracker.Initialize()
    local self = Tracker

    self.eventFrame = CreateFrame("Frame")

    local events = {
        "PLAYER_ENTERING_WORLD",
        "PLAYER_LEVEL_UP",
        "PLAYER_XP_UPDATE",
        "UPDATE_FACTION",
        "QUEST_TURNED_IN",
        "QUEST_ACCEPTED",
        "ZONE_CHANGED_NEW_AREA",
    }

    for _, event in ipairs(events) do
        self.eventFrame:RegisterEvent(event)
    end

    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        Tracker.OnEvent(event, ...)
    end)

    -- Instance tracking state
    self.inInstance = false
    self.currentInstance = nil
    self.instanceEntries = {}
    self.lastExitedInstance = nil
    self.lastExitTime = 0
    self.pendingRunDungeonKey = nil
end

--------------------------------------------------------------------------------
-- ReadPlayerState: Read current player info from WoW API
--------------------------------------------------------------------------------
function Tracker.ReadPlayerState()
    local self = Tracker

    local raceLocal, raceEN = UnitRace("player")

    local reps = {}
    for factionKey, factionData in pairs(BoneyardTBC_DO.FACTIONS) do
        reps[factionKey] = Tracker.GetTotalRep(factionData.id)
    end

    self.playerState = {
        level    = UnitLevel("player"),
        xp       = UnitXP("player"),
        xpMax    = UnitXPMax("player"),
        race     = raceLocal,
        raceEN   = raceEN,
        faction  = UnitFactionGroup("player"),
        reps     = reps,
        isHuman  = (raceEN == "Human"),
    }

    return self.playerState
end

--------------------------------------------------------------------------------
-- GetTotalRep: Convert WoW standing data to absolute rep from Neutral 0
--
-- GetFactionInfoByID returns:
--   name, description, standingId, barMin, barMax, barValue, ...
-- standingId: 4=Neutral, 5=Friendly, 6=Honored, 7=Revered, 8=Exalted
-- barValue is the raw total rep within the current standing bracket.
-- barValue - barMin = progress within the current standing.
-- totalRep = standingBase + (barValue - barMin)
--------------------------------------------------------------------------------
function Tracker.GetTotalRep(factionID)
    local name, _, standingId, barMin, _, barValue = GetFactionInfoByID(factionID)
    if not name then
        return 0
    end

    local base = STANDING_BASES[standingId]
    if not base then
        -- Below Neutral (Hated/Hostile/Unfriendly) -- not expected for these factions
        return 0
    end

    return base + (barValue - barMin)
end

--------------------------------------------------------------------------------
-- OnEvent: Main event dispatcher
--------------------------------------------------------------------------------
function Tracker.OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        Tracker.ReadPlayerState()
        if BoneyardTBC_DO.Optimizer and BoneyardTBC_DO.Optimizer.Recalculate then
            BoneyardTBC_DO.Optimizer.Recalculate()
        end
        Tracker.RefreshUI()

    elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
        if Tracker.playerState then
            Tracker.playerState.level = UnitLevel("player")
            Tracker.playerState.xp = UnitXP("player")
            Tracker.playerState.xpMax = UnitXPMax("player")
        else
            Tracker.ReadPlayerState()
        end
        Tracker.CheckStepAdvancement()
        Tracker.RefreshUI()

    elseif event == "UPDATE_FACTION" then
        if Tracker.playerState then
            for factionKey, factionData in pairs(BoneyardTBC_DO.FACTIONS) do
                Tracker.playerState.reps[factionKey] = Tracker.GetTotalRep(factionData.id)
            end
        else
            Tracker.ReadPlayerState()
        end
        -- Check for rep milestones (standing changes)
        if BoneyardTBC_DO.Overlay then
            BoneyardTBC_DO.Overlay.CheckRepMilestones()
        end
        Tracker.CheckStepAdvancement()
        Tracker.RefreshUI()

    elseif event == "QUEST_ACCEPTED" then
        -- Cache quest name for later lookup on QUEST_TURNED_IN
        -- TBC Classic fires QUEST_ACCEPTED with (questLogIndex, questID)
        local _, questID = ...
        if questID then
            local questTitle = C_QuestLog and C_QuestLog.GetQuestInfo and C_QuestLog.GetQuestInfo(questID)
            if not questTitle then
                -- Fallback: scan quest log for this quest ID
                questTitle = Tracker.GetQuestTitleFromLog(questID)
            end
            if questTitle then
                Tracker.questCache[questID] = questTitle
                Tracker.CheckQuestStep(questTitle, "Accept")
            end
        end

    elseif event == "QUEST_TURNED_IN" then
        local questID = ...
        local questTitle = Tracker.questCache[questID]
        if not questTitle and questID then
            -- Try to resolve the quest name if not cached
            if C_QuestLog and C_QuestLog.GetQuestInfo then
                questTitle = C_QuestLog.GetQuestInfo(questID)
            end
            if not questTitle then
                questTitle = Tracker.GetQuestTitleFromLog(questID)
            end
        end
        if questTitle then
            Tracker.CheckQuestStep(questTitle, "Turn In")
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        local zone = GetRealZoneText()

        -- Dungeon entry/exit detection
        local inInstance, instanceType = IsInInstance()
        if inInstance and (instanceType == "party" or instanceType == "raid") then
            if not Tracker.inInstance then
                -- Just entered an instance
                Tracker.inInstance = true
                Tracker.currentInstance = GetInstanceInfo()

                -- Check if this is a re-entry to the same instance (e.g. graveyard run)
                local isReentry = (Tracker.currentInstance == Tracker.lastExitedInstance)
                    and (time() - Tracker.lastExitTime) < 300

                if isReentry then
                    -- Same instance re-entry: cancel the pending run completion
                    Tracker.pendingRunDungeonKey = nil
                else
                    -- Genuinely new instance entry

                    -- Commit any pending run from a previous instance
                    if Tracker.pendingRunDungeonKey then
                        Tracker.IncrementDungeonRun(Tracker.pendingRunDungeonKey)
                        Tracker.pendingRunDungeonKey = nil
                    end

                    -- Track instance entry for lockout warning
                    table.insert(Tracker.instanceEntries, time())
                    -- Clean up entries older than 1 hour
                    local cutoff = time() - 3600
                    local i = 1
                    while i <= #Tracker.instanceEntries do
                        if Tracker.instanceEntries[i] < cutoff then
                            table.remove(Tracker.instanceEntries, i)
                        else
                            i = i + 1
                        end
                    end
                    -- Lockout warnings via Overlay
                    local Overlay = BoneyardTBC_DO.Overlay
                    if Overlay then
                        if #Tracker.instanceEntries >= 5 then
                            local oldest = Tracker.instanceEntries[1]
                            local waitMins = math.ceil((3600 - (time() - oldest)) / 60)
                            Overlay.FireAlert("LOCKOUT_HIT", "Lockout reached! Wait " .. waitMins .. "m.")
                        elseif #Tracker.instanceEntries >= 4 then
                            Overlay.FireAlert("LOCKOUT_WARNING", "4/5 instances. Slow down!")
                        end
                        Overlay.OnInstanceEnter()
                    end
                end

                Tracker.lastExitedInstance = nil
                Tracker.lastExitTime = 0
            end
        else
            if Tracker.inInstance then
                -- Just exited an instance -- defer run count in case of graveyard re-entry
                local exitedInstance = Tracker.currentInstance
                Tracker.inInstance = false
                Tracker.currentInstance = nil
                Tracker.lastExitedInstance = exitedInstance
                Tracker.lastExitTime = time()

                -- Notify overlay of instance exit
                if BoneyardTBC_DO.Overlay then
                    BoneyardTBC_DO.Overlay.OnInstanceExit()
                end

                -- Defer run increment — will be committed on next new instance entry or timeout
                if exitedInstance then
                    local dungeonKey = Tracker.FindDungeonKeyByName(exitedInstance)
                    if dungeonKey then
                        Tracker.pendingRunDungeonKey = dungeonKey
                        -- Commit after 5 minutes if no re-entry occurs
                        C_Timer.After(300, function()
                            if Tracker.pendingRunDungeonKey == dungeonKey then
                                Tracker.IncrementDungeonRun(dungeonKey)
                                Tracker.pendingRunDungeonKey = nil
                            end
                        end)
                    end
                end
            end
        end

        -- Check travel step advancement
        if zone and zone ~= "" then
            Tracker.CheckTravelStep(zone)
        end
    end
end

--------------------------------------------------------------------------------
-- GetQuestTitleFromLog: Scan quest log for a quest by ID (TBC fallback)
--------------------------------------------------------------------------------
function Tracker.GetQuestTitleFromLog(questID)
    local numEntries = GetNumQuestLogEntries and GetNumQuestLogEntries() or 0
    for i = 1, numEntries do
        local title, _, _, isHeader, _, _, _, id = GetQuestLogTitle(i)
        if not isHeader and id == questID then
            return title
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- FindDungeonKeyByName: Map instance name -> dungeon key
--------------------------------------------------------------------------------
function Tracker.FindDungeonKeyByName(instanceName)
    if not instanceName then return nil end
    local lowerName = instanceName:lower()
    for key, dungeon in pairs(BoneyardTBC_DO.DUNGEONS) do
        if dungeon.name:lower() == lowerName then
            return key
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- GetCurrentStep: Get the current step data from the last calculated route
--------------------------------------------------------------------------------
function Tracker.GetCurrentStep()
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return nil, nil end

    local currentStepIndex = db.currentStep or 1
    local lastResult = BoneyardTBC_DO.Optimizer and BoneyardTBC_DO.Optimizer.lastResult
    if not lastResult or not lastResult.route then return nil, nil end

    -- Find the step in the route that matches the current step index
    for _, step in ipairs(lastResult.route) do
        if step.step == currentStepIndex then
            return step, currentStepIndex
        end
    end

    return nil, currentStepIndex
end

--------------------------------------------------------------------------------
-- CheckStepAdvancement: Check if current step's conditions are met
--------------------------------------------------------------------------------
function Tracker.CheckStepAdvancement()
    local step = Tracker.GetCurrentStep()
    if not step then return end
    if not Tracker.playerState then return end

    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return end

    if step.type == "dungeon" then
        local advanced = false

        -- Check rep goal
        if step.repGoal and step.faction then
            local targetRep = BoneyardTBC_DO.REP_THRESHOLDS[step.repGoal]
            local currentRep = Tracker.playerState.reps[step.faction] or 0
            if targetRep and currentRep >= targetRep then
                -- Rep goal met -- also check level goal if present
                if step.levelGoal then
                    if Tracker.playerState.level >= step.levelGoal then
                        advanced = true
                    end
                else
                    advanced = true
                end
            end
        end

        -- Check level goal (without rep goal)
        if not advanced and step.levelGoal and not step.repGoal then
            if Tracker.playerState.level >= step.levelGoal then
                advanced = true
            end
        end

        -- Check calculated runs (for steps with neither repGoal nor levelGoal,
        -- or as a fallback completion check)
        if not advanced and not step.repGoal and not step.levelGoal then
            if step.calculatedRuns then
                local dungeonKey = step.dungeon
                local runCount = (db.dungeonRunCounts and db.dungeonRunCounts[dungeonKey]) or 0
                if runCount >= step.calculatedRuns then
                    advanced = true
                end
            end
        end

        if advanced then
            Tracker.AdvanceStep()
        end

    -- Quest and travel steps are handled by their own check functions
    -- Checkpoint steps never auto-advance
    end
end

--------------------------------------------------------------------------------
-- CheckQuestStep: Check if current step is a quest step matching the given name
-- eventAction: the action that just occurred ("Accept" or "Turn In")
-- Only advances if the step's action matches the event action.
--------------------------------------------------------------------------------
function Tracker.CheckQuestStep(questName, eventAction)
    local step = Tracker.GetCurrentStep()
    if not step then return end
    if step.type ~= "quest" then return end

    -- Only advance if the step action matches what just happened
    if eventAction and step.action and step.action ~= eventAction then return end

    if step.quest and questName then
        if step.quest:lower() == questName:lower() then
            Tracker.AdvanceStep()
        end
    end
end

--------------------------------------------------------------------------------
-- CheckTravelStep: Check if current step is a travel step matching the zone
--------------------------------------------------------------------------------
function Tracker.CheckTravelStep(zone)
    local step = Tracker.GetCurrentStep()
    if not step then return end
    if step.type ~= "travel" then return end

    if step.zone and zone then
        if step.zone:lower() == zone:lower() then
            Tracker.AdvanceStep()
        end
    end
end

--------------------------------------------------------------------------------
-- AdvanceStep: Mark current step complete and move to the next
--------------------------------------------------------------------------------
function Tracker.AdvanceStep()
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return end

    local currentStepIndex = db.currentStep or 1

    -- Mark current step as completed
    if not db.completedSteps then
        db.completedSteps = {}
    end
    db.completedSteps[currentStepIndex] = true

    -- Find the next step in the filtered route after the current one
    local nextStep = nil
    local route = BoneyardTBC_DO.Optimizer and BoneyardTBC_DO.Optimizer.lastResult and BoneyardTBC_DO.Optimizer.lastResult.route
    if route then
        local foundCurrent = false
        for _, routeStep in ipairs(route) do
            if foundCurrent then
                db.currentStep = routeStep.step
                nextStep = routeStep
                break
            end
            if routeStep.step == currentStepIndex then
                foundCurrent = true
            end
        end
        -- If we didn't find a next step (last step in route), just increment
        if not foundCurrent or db.currentStep == currentStepIndex then
            db.currentStep = currentStepIndex + 1
        end
    else
        -- No route available, fall back to simple increment
        db.currentStep = currentStepIndex + 1
    end

    local nextDesc = "End of route"
    if nextStep then
        if nextStep.type == "dungeon" then
            local dungeon = BoneyardTBC_DO.DUNGEONS[nextStep.dungeon]
            nextDesc = (dungeon and dungeon.name) or nextStep.dungeon
        elseif nextStep.type == "quest" then
            nextDesc = (nextStep.action or "") .. " " .. (nextStep.quest or "")
        elseif nextStep.type == "travel" then
            nextDesc = nextStep.text or "Travel"
        elseif nextStep.type == "checkpoint" then
            nextDesc = nextStep.text or "Checkpoint"
        end
    end

    if BoneyardTBC_DO.Overlay then
        BoneyardTBC_DO.Overlay.FireAlert("STEP_ADVANCED", "Step " .. currentStepIndex .. " complete! Next: " .. nextDesc)
    else
        print("|cff00ccffBoneyard:|r Step " .. currentStepIndex .. " complete! Next: " .. nextDesc)
    end

    -- Notify UI callback if set
    if Tracker.onStepAdvanced then
        Tracker.onStepAdvanced(db.currentStep)
    end

    -- Broadcast updated status to guild/party
    if BoneyardTBC_DO.Sync and BoneyardTBC_DO.Sync.BroadcastAll then
        BoneyardTBC_DO.Sync.BroadcastAll()
    end
end

--------------------------------------------------------------------------------
-- GetDungeonRunsDone: Derive completed runs from rep progress for a route step
-- Returns: done, total (both dynamically computed from rep when possible)
-- Falls back to db.dungeonRunCounts when rep derivation isn't possible.
--------------------------------------------------------------------------------
function Tracker.GetDungeonRunsDone(step)
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    local dungeonKey = step.dungeon
    local fallbackTotal = step.calculatedRuns or step.runs or 0

    -- Derive from rep when startRep and repGoal are available
    if step.startRep and step.repGoal and step.faction then
        local dungeon = BoneyardTBC_DO.DUNGEONS[dungeonKey]
        if dungeon and dungeon.repPerClear and dungeon.repPerClear > 0 then
            local playerState = Tracker.playerState
            local race = playerState and playerState.race or "Unknown"
            local repPerRun = BoneyardTBC_DO.Optimizer.ApplyRacialBonus(dungeon.repPerClear, race)
            local targetRep = BoneyardTBC_DO.REP_THRESHOLDS[step.repGoal] or 0
            local currentRep = playerState and playerState.reps and playerState.reps[step.faction] or 0

            -- Total runs needed from startRep to target
            local neededFromStart = math.max(0, targetRep - step.startRep)
            local total = math.max(1, math.ceil(neededFromStart / repPerRun))

            -- Runs done since startRep
            local gainedRep = math.max(0, currentRep - step.startRep)
            local done = math.min(total, math.floor(gainedRep / repPerRun))

            return done, total
        end
    end

    -- Fallback: event-based counter
    local done = (db and db.dungeonRunCounts and db.dungeonRunCounts[dungeonKey]) or 0
    return done, fallbackTotal
end

--------------------------------------------------------------------------------
-- IncrementDungeonRun: Record a completed dungeon run
--------------------------------------------------------------------------------
function Tracker.IncrementDungeonRun(dungeonKey)
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return end

    if not db.dungeonRunCounts then
        db.dungeonRunCounts = {}
    end

    if not db.dungeonRunCounts[dungeonKey] then
        db.dungeonRunCounts[dungeonKey] = 0
    end

    db.dungeonRunCounts[dungeonKey] = db.dungeonRunCounts[dungeonKey] + 1

    local dungeon = BoneyardTBC_DO.DUNGEONS[dungeonKey]
    local dungeonName = (dungeon and dungeon.name) or dungeonKey
    local count = db.dungeonRunCounts[dungeonKey]

    if BoneyardTBC_DO.Overlay then
        BoneyardTBC_DO.Overlay.FireAlert("RUN_COMPLETE", dungeonName .. " run " .. count .. " complete")
    else
        print("|cff00ccffBoneyard:|r " .. dungeonName .. " run " .. count .. " complete")
    end

    -- Check if this run triggers step advancement
    Tracker.CheckStepAdvancement()

    -- Broadcast updated status to guild/party
    if BoneyardTBC_DO.Sync and BoneyardTBC_DO.Sync.BroadcastAll then
        BoneyardTBC_DO.Sync.BroadcastAll()
    end
end

--------------------------------------------------------------------------------
-- SkipStep: Manual skip for travel/checkpoint steps only
--------------------------------------------------------------------------------
function Tracker.SkipStep()
    local step = Tracker.GetCurrentStep()
    if not step then
        print("|cff00ccffBoneyard:|r No current step to skip.")
        return
    end

    if step.type == "travel" or step.type == "checkpoint" then
        Tracker.AdvanceStep()
    else
        print("|cff00ccffBoneyard:|r Can only skip travel or checkpoint steps.")
    end
end

--------------------------------------------------------------------------------
-- RefreshUI: Notify the module UI to refresh all tabs
--------------------------------------------------------------------------------
function Tracker.RefreshUI()
    local DO = BoneyardTBC_DO.module
    if not DO then return end
    if DO.RefreshSetupTab then DO:RefreshSetupTab() end
    if DO.RefreshRouteTab then DO:RefreshRouteTab() end
    if DO.RefreshTrackerTab then DO:RefreshTrackerTab() end
    if DO.RefreshGuildTab then DO:RefreshGuildTab() end
end

--------------------------------------------------------------------------------
-- ResetProgress: Reset all tracking state
--------------------------------------------------------------------------------
function Tracker.ResetProgress()
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db
    if not db then return end

    db.currentStep = 1
    db.completedSteps = {}
    db.dungeonRunCounts = {}

    print("|cff00ccffBoneyard:|r Progress reset. Starting from step 1.")

    -- Notify UI callback
    if Tracker.onStepAdvanced then
        Tracker.onStepAdvanced(1)
    end
end
