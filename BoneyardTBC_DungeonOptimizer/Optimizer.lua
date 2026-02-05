BoneyardTBC_DO.Optimizer = {}

--------------------------------------------------------------------------------
-- Helper: Deep Copy
--------------------------------------------------------------------------------
function BoneyardTBC_DO.Optimizer.DeepCopy(orig)
    if type(orig) ~= "table" then
        return orig
    end
    local copy = {}
    for k, v in pairs(orig) do
        if type(v) == "table" then
            copy[k] = BoneyardTBC_DO.Optimizer.DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

--------------------------------------------------------------------------------
-- Helper: Apply Human Racial Bonus (10% more reputation)
--------------------------------------------------------------------------------
function BoneyardTBC_DO.Optimizer.ApplyRacialBonus(rep, race)
    if race == "Human" then
        return math.floor(rep * 1.10)
    end
    return rep
end

--------------------------------------------------------------------------------
-- Helper: Check if normal mode still gives rep for this dungeon
-- currentRep is the player's total rep from Neutral 0 for the dungeon's faction.
--------------------------------------------------------------------------------
function BoneyardTBC_DO.Optimizer.CanGainNormalRep(dungeonKey, currentRep)
    local dungeon = BoneyardTBC_DO.DUNGEONS[dungeonKey]
    if not dungeon then return false end
    local cap = dungeon.normalRepCap
    if not cap then
        return true -- no cap means rep all the way to Exalted
    end
    local threshold = BoneyardTBC_DO.REP_THRESHOLDS[cap]
    if not threshold then return true end
    return currentRep < threshold
end

--------------------------------------------------------------------------------
-- Helper: Calculate XP for one dungeon clear at the given player level
--------------------------------------------------------------------------------
function BoneyardTBC_DO.Optimizer.CalculateDungeonXP(dungeonKey, playerLevel)
    local xpData = BoneyardTBC_DO.DUNGEON_XP[dungeonKey]
    if not xpData then return 0 end

    local base = xpData.base
    local minLevel = xpData.levelRange[1]
    local maxLevel = xpData.levelRange[2]

    -- Player is below the dungeon's minimum level
    if playerLevel < minLevel then
        return 0
    end

    -- Player is within the dungeon's effective level range
    if playerLevel <= maxLevel then
        return base
    end

    -- Player is above the dungeon's max level: reduce by 10% per level over
    local reduction = 1 - 0.10 * (playerLevel - maxLevel)
    return math.floor(math.max(base * 0.20, base * reduction))
end

--------------------------------------------------------------------------------
-- Balanced Mode: Calculate route based on Myro's guide with dynamic run counts
--------------------------------------------------------------------------------
function BoneyardTBC_DO.Optimizer.CalculateBalancedRoute(startLevel, startXP, currentReps, race, options)
    options = options or {}
    local route = BoneyardTBC_DO.Optimizer.DeepCopy(BoneyardTBC_DO.ROUTES.ALLIANCE_BALANCED)

    -- Build a set of step numbers to remove based on option toggles
    local removeSteps = {}

    if not options.includeKarazhan then
        -- Remove Karazhan attunement quest chain steps: 18-35, 59-61, 118-131
        for s = 18, 35 do removeSteps[s] = true end
        for s = 59, 61 do removeSteps[s] = true end
        for s = 118, 131 do removeSteps[s] = true end
    end

    if not options.includeArcatrazKey then
        -- Remove Arcatraz key chain + Netherstorm dungeons: steps 80-117
        for s = 80, 117 do removeSteps[s] = true end
    end

    if not options.includeShatteredHallsKey then
        -- Remove Shattered Halls key quest chain: steps 64-75 (keep step 76, the dungeon)
        for s = 64, 75 do removeSteps[s] = true end
    end

    -- Filter the route: remove steps whose step number is in the remove set
    local filteredRoute = {}
    for _, routeStep in ipairs(route) do
        if not removeSteps[routeStep.step] then
            filteredRoute[#filteredRoute + 1] = routeStep
        end
    end
    route = filteredRoute

    -- Simulation state
    local currentLevel = startLevel
    local currentXP = startXP
    local reps = BoneyardTBC_DO.Optimizer.DeepCopy(currentReps)
    local totalRuns = 0
    local totalXPGained = 0

    -- Walk each step
    for _, step in ipairs(route) do
        if step.type == "dungeon" then
            local dungeonKey = step.dungeon
            local dungeon = BoneyardTBC_DO.DUNGEONS[dungeonKey]

            if dungeon then
                local faction = step.faction or dungeon.faction

                if step.runs == -1 then
                    -----------------------------------------------------------------
                    -- Variable runs: stay until BOTH levelGoal AND repGoal are met
                    -----------------------------------------------------------------
                    local targetRep = nil
                    if step.repGoal then
                        targetRep = BoneyardTBC_DO.REP_THRESHOLDS[step.repGoal]
                    end
                    local targetLevel = step.levelGoal

                    local runs = 0
                    local MAX_RUNS = 200 -- safety cap

                    while runs < MAX_RUNS do
                        -- Check if both goals are met
                        local levelMet = (not targetLevel) or (currentLevel >= targetLevel)
                        local repMet = (not targetRep) or ((reps[faction] or 0) >= targetRep)

                        if levelMet and repMet then
                            break
                        end

                        -- Don't continue past level 70
                        if currentLevel >= 70 then break end

                        runs = runs + 1

                        -- Rep gain (only if normal mode still gives rep)
                        if BoneyardTBC_DO.Optimizer.CanGainNormalRep(dungeonKey, reps[faction] or 0) then
                            local repGain = BoneyardTBC_DO.Optimizer.ApplyRacialBonus(dungeon.repPerClear, race)
                            reps[faction] = (reps[faction] or 0) + repGain
                        end

                        -- XP gain
                        local xpGain = BoneyardTBC_DO.Optimizer.CalculateDungeonXP(dungeonKey, currentLevel)
                        currentXP = currentXP + xpGain
                        totalXPGained = totalXPGained + xpGain

                        -- Level-up checks
                        while currentLevel < 70 and BoneyardTBC_DO.XP_TO_LEVEL[currentLevel] and currentXP >= BoneyardTBC_DO.XP_TO_LEVEL[currentLevel] do
                            currentXP = currentXP - BoneyardTBC_DO.XP_TO_LEVEL[currentLevel]
                            currentLevel = currentLevel + 1
                        end
                    end

                    step.calculatedRuns = runs
                    totalRuns = totalRuns + runs

                else
                    -----------------------------------------------------------------
                    -- Fixed run count, with possible adjustments based on rep goal
                    -----------------------------------------------------------------
                    local actualRuns = step.runs

                    if step.repGoal and faction then
                        -- Has a rep goal: calculate needed runs from rep deficit
                        local targetRep = BoneyardTBC_DO.REP_THRESHOLDS[step.repGoal] or 0
                        local currentFactionRep = reps[faction] or 0
                        local neededRep = targetRep - currentFactionRep

                        if neededRep <= 0 then
                            -- Rep already met: skip dungeon runs for this step
                            actualRuns = 0
                        else
                            local repPerRun = BoneyardTBC_DO.Optimizer.ApplyRacialBonus(dungeon.repPerClear, race)
                            -- Account for rep cap: if can't gain rep, no point in running for rep
                            if not BoneyardTBC_DO.Optimizer.CanGainNormalRep(dungeonKey, currentFactionRep) then
                                -- Can't gain rep from normal mode anymore
                                -- Still run the guide minimum if it's a fixed step
                                actualRuns = step.runs
                            else
                                local neededRuns = math.ceil(neededRep / repPerRun)
                                actualRuns = math.max(neededRuns, step.runs)
                            end
                        end
                    end
                    -- Steps WITHOUT repGoal (e.g., attunement clears): always use fixed count

                    -- Simulate the runs
                    local runsThisStep = 0
                    for _ = 1, actualRuns do
                        -- Rep gain
                        if BoneyardTBC_DO.Optimizer.CanGainNormalRep(dungeonKey, reps[faction] or 0) then
                            local repGain = BoneyardTBC_DO.Optimizer.ApplyRacialBonus(dungeon.repPerClear, race)
                            reps[faction] = (reps[faction] or 0) + repGain
                        end

                        -- XP gain (only if below 70)
                        if currentLevel < 70 then
                            local xpGain = BoneyardTBC_DO.Optimizer.CalculateDungeonXP(dungeonKey, currentLevel)
                            currentXP = currentXP + xpGain
                            totalXPGained = totalXPGained + xpGain

                            -- Level-up checks
                            while currentLevel < 70 and BoneyardTBC_DO.XP_TO_LEVEL[currentLevel] and currentXP >= BoneyardTBC_DO.XP_TO_LEVEL[currentLevel] do
                                currentXP = currentXP - BoneyardTBC_DO.XP_TO_LEVEL[currentLevel]
                                currentLevel = currentLevel + 1
                            end
                        end

                        runsThisStep = runsThisStep + 1
                    end

                    step.calculatedRuns = runsThisStep
                    totalRuns = totalRuns + runsThisStep
                end
            else
                step.calculatedRuns = 0
            end
        end
        -- Quest, travel, and checkpoint steps pass through unchanged
        -- (XP from quests is minor and not tracked in the simulation)
    end

    return {
        route = route,
        totalRuns = totalRuns,
        finalLevel = currentLevel,
        totalXP = totalXPGained,
        finalReps = reps,
    }
end

--------------------------------------------------------------------------------
-- Leveling Mode: Greedy dungeon selection for max XP per run
--------------------------------------------------------------------------------
function BoneyardTBC_DO.Optimizer.CalculateLevelingRoute(startLevel, startXP, race)
    local currentLevel = startLevel
    local currentXP = startXP
    local totalRuns = 0
    local totalXPGained = 0
    local route = {}

    while currentLevel < 70 do
        -- Find the dungeon with the highest XP at the current level
        local bestDungeon = nil
        local bestXP = 0

        for key, xpData in pairs(BoneyardTBC_DO.DUNGEON_XP) do
            local dungeon = BoneyardTBC_DO.DUNGEONS[key]
            if dungeon and currentLevel >= dungeon.minLevel then
                local xp = BoneyardTBC_DO.Optimizer.CalculateDungeonXP(key, currentLevel)
                if xp > bestXP then
                    bestXP = xp
                    bestDungeon = key
                end
            end
        end

        -- No qualifying dungeon found (shouldn't happen for 58+, but safety check)
        if not bestDungeon or bestXP <= 0 then
            break
        end

        -- Run this dungeon repeatedly until a better one exists or player hits 70
        local phaseRuns = 0

        while currentLevel < 70 do
            -- Check if a better dungeon now exists at the current level
            local currentBestXP = 0
            local currentBestDungeon = nil
            for key, xpData in pairs(BoneyardTBC_DO.DUNGEON_XP) do
                local dungeon = BoneyardTBC_DO.DUNGEONS[key]
                if dungeon and currentLevel >= dungeon.minLevel then
                    local xp = BoneyardTBC_DO.Optimizer.CalculateDungeonXP(key, currentLevel)
                    if xp > currentBestXP then
                        currentBestXP = xp
                        currentBestDungeon = key
                    end
                end
            end

            -- If a better dungeon is now available, break out to pick it up
            if currentBestDungeon ~= bestDungeon then
                break
            end

            -- Run the dungeon
            phaseRuns = phaseRuns + 1

            local xpGain = BoneyardTBC_DO.Optimizer.CalculateDungeonXP(bestDungeon, currentLevel)
            currentXP = currentXP + xpGain
            totalXPGained = totalXPGained + xpGain

            -- Level-up checks
            while currentLevel < 70 and BoneyardTBC_DO.XP_TO_LEVEL[currentLevel] and currentXP >= BoneyardTBC_DO.XP_TO_LEVEL[currentLevel] do
                currentXP = currentXP - BoneyardTBC_DO.XP_TO_LEVEL[currentLevel]
                currentLevel = currentLevel + 1
            end
        end

        -- Record this phase
        if phaseRuns > 0 then
            local dungeon = BoneyardTBC_DO.DUNGEONS[bestDungeon]
            route[#route + 1] = {
                type = "dungeon",
                step = #route + 1,
                dungeon = bestDungeon,
                runs = phaseRuns,
                calculatedRuns = phaseRuns,
                note = dungeon and dungeon.name or bestDungeon,
                faction = dungeon and dungeon.faction or nil,
            }
            totalRuns = totalRuns + phaseRuns
        end
    end

    return {
        route = route,
        totalRuns = totalRuns,
        finalLevel = currentLevel,
        totalXP = totalXPGained,
        finalReps = {},
    }
end

--------------------------------------------------------------------------------
-- Convenience: Recalculate using current saved settings and player state
--------------------------------------------------------------------------------
function BoneyardTBC_DO.Optimizer.Recalculate()
    local db = BoneyardTBC_DO.module and BoneyardTBC_DO.module.db or {}

    -- Read player state from live tracker if available, otherwise use defaults
    local playerState = BoneyardTBC_DO.Tracker and BoneyardTBC_DO.Tracker.playerState
    local startLevel, startXP, race, currentReps

    if playerState then
        startLevel = playerState.level or 58
        startXP = playerState.xp or 0
        race = playerState.race or "Unknown"
        currentReps = playerState.reps or {}
    else
        startLevel = 58
        startXP = 0
        race = "Unknown"
        currentReps = {}
    end

    -- Ensure all factions have a rep entry
    for factionKey, _ in pairs(BoneyardTBC_DO.FACTIONS) do
        if not currentReps[factionKey] then
            currentReps[factionKey] = 0
        end
    end

    local result

    if db.optimizationMode == "leveling" then
        result = BoneyardTBC_DO.Optimizer.CalculateLevelingRoute(startLevel, startXP, race)
    else
        -- Default to balanced mode
        local options = {
            includeKarazhan = db.includeKarazhan ~= false,
            includeArcatrazKey = db.includeArcatrazKey ~= false,
            includeShatteredHallsKey = db.includeShatteredHallsKey == true,
            repGoals = db.repGoals or {},
        }
        result = BoneyardTBC_DO.Optimizer.CalculateBalancedRoute(startLevel, startXP, currentReps, race, options)
    end

    BoneyardTBC_DO.Optimizer.lastResult = result
    return result
end
