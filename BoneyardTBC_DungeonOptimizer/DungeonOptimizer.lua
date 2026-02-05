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
    end
end

function DO:GetTabPanels()
    return {
        { name = "Setup", create = function(parent) return self:CreateSetupTab(parent) end },
        { name = "Route", create = function(parent) return self:CreateRouteTab(parent) end },
        { name = "Tracker", create = function(parent) return self:CreateTrackerTab(parent) end },
    }
end

function DO:OnSlashCommand(args)
    -- Stub: will be wired in Task 10
end

BoneyardTBC:RegisterModule("DungeonOptimizer", DO)

BoneyardTBC_DO.module = DO
