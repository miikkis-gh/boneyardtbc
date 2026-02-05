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
        db.enableGuildSync = true
        db.enablePartySync = true
        db.enableSyncAlerts = true
        db.guildRoster = {}
    end

    -- Migrate: add sync defaults for existing installs
    if db.enableGuildSync == nil then
        db.enableGuildSync = true
        db.enablePartySync = true
        db.enableSyncAlerts = true
    end
    if not db.guildRoster then
        db.guildRoster = {}
    end

    -- Schedule initialization that needs other systems ready
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function(frame)
        frame:UnregisterEvent("PLAYER_LOGIN")
        -- Initialize tracker
        BoneyardTBC_DO.Tracker.Initialize()
        -- Initialize sync system
        BoneyardTBC_DO.Sync.Initialize()
        -- Register tabs with main frame
        if BoneyardTBC.MainFrame and BoneyardTBC.MainFrame.AddModuleTabs then
            BoneyardTBC.MainFrame:AddModuleTabs(DO)
        end
    end)
end

function DO:GetTabPanels()
    return {
        { name = "Setup", create = function(parent) return self:CreateSetupTab(parent) end },
        { name = "Route", create = function(parent) return self:CreateRouteTab(parent) end },
        { name = "Tracker", create = function(parent) return self:CreateTrackerTab(parent) end },
        { name = "Guild", create = function(parent) return self:CreateGuildTab(parent) end },
    }
end

function DO:OnSlashCommand(args)
    if args == "route" then
        -- Print current step to chat
        local step = BoneyardTBC_DO.Tracker.GetCurrentStep and BoneyardTBC_DO.Tracker.GetCurrentStep()
        if step then
            local desc = step.text or step.quest or step.dungeon or "Unknown"
            print("|cff00ccffBoneyard:|r Current step: " .. desc)
        else
            print("|cff00ccffBoneyard:|r No route calculated yet.")
        end
    elseif args == "status" then
        -- Print rep summary to chat
        local state = BoneyardTBC_DO.Tracker.playerState
        if state and state.reps then
            print("|cff00ccffBoneyard:|r Reputation Status:")
            for key, faction in pairs(BoneyardTBC_DO.FACTIONS) do
                local rep = state.reps[key] or 0
                local goal = self.db.repGoals[key]
                if goal then
                    local needed = BoneyardTBC_DO.REP_THRESHOLDS[goal] - rep
                    local status = needed <= 0 and "|cff00ff00Done|r" or (needed .. " needed")
                    print("  " .. faction.name .. ": " .. rep .. " (" .. goal .. " - " .. status .. ")")
                end
            end
        else
            print("|cff00ccffBoneyard:|r Player state not loaded yet.")
        end
    elseif args == "reset" then
        BoneyardTBC_DO.Tracker.ResetProgress()
        print("|cff00ccffBoneyard:|r Progress reset.")
    else
        print("|cff00ccffBoneyard:|r Commands: route, status, reset")
    end
end

BoneyardTBC:RegisterModule("DungeonOptimizer", DO)

BoneyardTBC_DO.module = DO
