----------------------------------------------------------------------
-- BoneyardTBC DungeonOptimizer UI — Route Tab
-- Scrollable step list with status indicators and dungeon sub-info.
----------------------------------------------------------------------

local DO = BoneyardTBC_DO.module

----------------------------------------------------------------------
-- Route-specific constants
----------------------------------------------------------------------

-- Step type icon textures
local STEP_ICONS = {
    travel     = "Interface\\Icons\\Ability_Rogue_Sprint",
    dungeon    = "Interface\\Icons\\INV_Sword_04",
    quest      = "Interface\\Icons\\INV_Misc_Note_01",
    checkpoint = "Interface\\Icons\\INV_Misc_Rune_01",
}

-- Row height constants
local ROW_HEIGHT = 32
local ROW_HEIGHT_EXPANDED = 48 -- dungeon rows with sub-info (run counter + rep bar)

-- Highlight backdrop for the current step
local ROW_HIGHLIGHT_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

----------------------------------------------------------------------
-- Tab 2: Route — DO:CreateRouteTab(parent)
----------------------------------------------------------------------

function DO:CreateRouteTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)

    self.routeTab = tab
    self.routeRows = {}

    ----------------------------------------------------------------
    -- ScrollFrame
    ----------------------------------------------------------------

    local scrollFrame = CreateFrame("ScrollFrame", "BoneyardTBC_DORouteScroll", tab, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", tab, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -26, 4)
    self.routeScrollFrame = scrollFrame

    -- Scroll child: content frame that grows vertically
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 640)
    scrollChild:SetHeight(1) -- will be resized in BuildRouteRows
    scrollFrame:SetScrollChild(scrollChild)
    self.routeScrollChild = scrollChild

    -- Update scroll child width when scroll frame resizes
    scrollFrame:SetScript("OnSizeChanged", function(sf, width, height)
        scrollChild:SetWidth(width)
    end)

    ----------------------------------------------------------------
    -- Empty-state message
    ----------------------------------------------------------------

    local emptyMsg = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyMsg:SetPoint("CENTER", tab, "CENTER", 0, 0)
    emptyMsg:SetText("Configure options in the Setup tab and click 'View Optimized Route'")
    emptyMsg:SetTextColor(0.5, 0.5, 0.5, 1)
    emptyMsg:SetWidth(400)
    emptyMsg:SetJustifyH("CENTER")
    self.routeEmptyMsg = emptyMsg

    ----------------------------------------------------------------
    -- Build initial rows (if route already calculated)
    ----------------------------------------------------------------

    -- Defer row building until the tab is first shown so sizes are resolved
    tab:SetScript("OnShow", function()
        -- Re-measure scroll child width now that the frame is visible
        scrollChild:SetWidth(scrollFrame:GetWidth())
        self:BuildRouteRows()

        -- Auto-scroll to current step
        local db = self.db
        if db.currentStep and db.currentStep > 1 and self.routeRowPositions then
            local scrollPos = self.routeRowPositions[db.currentStep] or 0
            -- Center the current step in the visible area
            local visibleHeight = scrollFrame:GetHeight() or 400
            scrollPos = math.max(0, scrollPos - (visibleHeight / 2) + (ROW_HEIGHT / 2))
            scrollFrame:SetVerticalScroll(scrollPos)
        end
    end)

    return tab
end

----------------------------------------------------------------------
-- DO:BuildRouteRows() — Build/rebuild all step rows from optimizer result
----------------------------------------------------------------------

function DO:BuildRouteRows()
    local scrollChild = self.routeScrollChild
    local scrollFrame = self.routeScrollFrame
    if not scrollChild or not scrollFrame then return end

    local db = self.db
    local result = BoneyardTBC_DO.Optimizer and BoneyardTBC_DO.Optimizer.lastResult
    local route = result and result.route

    ----------------------------------------------------------------
    -- Hide all existing rows
    ----------------------------------------------------------------
    for _, row in ipairs(self.routeRows) do
        row:Hide()
    end

    ----------------------------------------------------------------
    -- No route: show empty message
    ----------------------------------------------------------------
    if not route or #route == 0 then
        if self.routeEmptyMsg then
            self.routeEmptyMsg:Show()
        end
        scrollChild:SetHeight(1)
        return
    end

    -- Hide empty message
    if self.routeEmptyMsg then
        self.routeEmptyMsg:Hide()
    end

    local currentStep = db.currentStep or 1
    local completedSteps = db.completedSteps or {}
    local dungeonRunCounts = db.dungeonRunCounts or {}
    local playerReps = BoneyardTBC_DO.Tracker and BoneyardTBC_DO.Tracker.playerState and BoneyardTBC_DO.Tracker.playerState.reps or {}
    local contentWidth = scrollChild:GetWidth()

    ----------------------------------------------------------------
    -- Create or reuse rows for each step
    ----------------------------------------------------------------
    local yOffset = 0
    self.routeRowPositions = {} -- store y positions for scroll-to-step

    for i, step in ipairs(route) do
        local row = self.routeRows[i]

        -- Determine effective row height before positioning
        local hasDungeonSubInfo = (step.type == "dungeon" and step.calculatedRuns and step.calculatedRuns > 0)
        local rowHeight = hasDungeonSubInfo and ROW_HEIGHT_EXPANDED or ROW_HEIGHT

        if not row then
            -- Create a new row frame
            row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")

            -- Step number text (30px wide, left)
            local stepNum = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            stepNum:SetPoint("LEFT", row, "LEFT", 4, 0)
            stepNum:SetWidth(30)
            stepNum:SetJustifyH("RIGHT")
            stepNum:SetTextColor(0.6, 0.6, 0.6, 1)
            row.stepNum = stepNum

            -- Type icon (24x24, next to number)
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(24, 24)
            icon:SetPoint("LEFT", row, "LEFT", 38, 0)
            row.icon = icon

            -- Description text (flexible width)
            local desc = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            desc:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            desc:SetPoint("RIGHT", row, "RIGHT", -36, 0)
            desc:SetJustifyH("LEFT")
            desc:SetWordWrap(false)
            row.desc = desc

            -- Status indicator (30px, right side)
            local statusIcon = row:CreateTexture(nil, "OVERLAY")
            statusIcon:SetSize(16, 16)
            statusIcon:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.statusIcon = statusIcon

            local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            statusText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            statusText:SetTextColor(0.5, 0.5, 0.5, 1)
            row.statusText = statusText

            -- Sub-info line for dungeon rows (run counter + optional rep bar)
            local subInfo = CreateFrame("Frame", nil, row)
            subInfo:SetHeight(14)
            subInfo:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -1)
            subInfo:SetPoint("RIGHT", row, "RIGHT", -36, 0)
            subInfo:Hide()
            row.subInfo = subInfo

            local runCounter = subInfo:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            runCounter:SetPoint("LEFT", subInfo, "LEFT", 0, 0)
            runCounter:SetTextColor(0.7, 0.7, 0.7, 1)
            row.runCounter = runCounter

            -- Rep progress bar placeholder (created lazily)
            row.repBar = nil

            self.routeRows[i] = row
        end

        ----------------------------------------------------------------
        -- Populate row data
        ----------------------------------------------------------------
        row:Show()
        row:SetHeight(rowHeight)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

        -- Store position for scroll-to-step
        self.routeRowPositions[step.step or i] = yOffset

        -- Step number
        row.stepNum:SetText(tostring(step.step or i))

        -- Type icon
        local iconPath = STEP_ICONS[step.type] or STEP_ICONS.travel
        row.icon:SetTexture(iconPath)

        -- Description text
        local descText = ""
        if step.type == "travel" then
            descText = step.text or ""
        elseif step.type == "dungeon" then
            local dungeon = BoneyardTBC_DO.DUNGEONS[step.dungeon]
            local dungeonName = dungeon and dungeon.name or (step.dungeon or "Unknown")
            local runs = step.calculatedRuns or step.runs or 0
            descText = dungeonName .. " x" .. runs
            if step.repGoal and step.faction then
                local factionData = BoneyardTBC_DO.FACTIONS[step.faction]
                local factionName = factionData and factionData.name or step.faction
                descText = descText .. " (" .. step.repGoal .. " " .. factionName .. ")"
            end
        elseif step.type == "quest" then
            local action = step.action or "Quest"
            local quest = step.quest or ""
            descText = action .. ": " .. quest
            if step.npc then
                descText = descText .. " (" .. step.npc .. ")"
            end
        elseif step.type == "checkpoint" then
            descText = step.text or ""
        else
            descText = step.text or step.note or ""
        end
        row.desc:SetText(descText)

        ----------------------------------------------------------------
        -- Status indicator
        ----------------------------------------------------------------
        local stepNumber = step.step or i
        local isCompleted = completedSteps[stepNumber]
        local isCurrent = (stepNumber == currentStep)

        -- Reset status elements
        row.statusIcon:Hide()
        row.statusText:Hide()

        if isCompleted then
            row.statusIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
            row.statusIcon:Show()
            row.desc:SetTextColor(0.5, 0.7, 0.5, 1)
            row.stepNum:SetTextColor(0.5, 0.7, 0.5, 1)
        elseif isCurrent then
            row.statusIcon:SetTexture("Interface\\BUTTONS\\UI-MicroStream-Yellow")
            row.statusIcon:Show()
            row.desc:SetTextColor(1, 1, 1, 1)
            row.stepNum:SetTextColor(1, 0.82, 0, 1)
        else
            row.statusText:SetText("\226\128\148") -- em dash
            row.statusText:Show()
            row.desc:SetTextColor(0.9, 0.9, 0.9, 1)
            row.stepNum:SetTextColor(0.6, 0.6, 0.6, 1)
        end

        ----------------------------------------------------------------
        -- Current step highlight
        ----------------------------------------------------------------
        if isCurrent then
            row:SetBackdrop(ROW_HIGHLIGHT_BACKDROP)
            row:SetBackdropColor(0.3, 0.25, 0.05, 0.3)
            row:SetBackdropBorderColor(0.8, 0.65, 0.1, 0.6)
        else
            row:SetBackdrop(nil)
        end

        ----------------------------------------------------------------
        -- Dungeon sub-info (run counter + optional rep bar)
        ----------------------------------------------------------------
        if hasDungeonSubInfo then
            row.subInfo:Show()

            -- Run counter (derived from rep progress when possible)
            local currentRuns, totalRuns = BoneyardTBC_DO.Tracker.GetDungeonRunsDone(step)
            row.runCounter:SetText("Run " .. currentRuns .. "/" .. totalRuns)

            -- Rep progress bar (if step has a repGoal)
            if step.repGoal and step.faction then
                if not row.repBar then
                    row.repBar = BoneyardTBC.Widgets.CreateProgressBar(row.subInfo, 150, 10, { r = 0.2, g = 0.6, b = 0.2 })
                    row.repBar:SetPoint("LEFT", row.runCounter, "RIGHT", 8, 0)
                end
                row.repBar:Show()

                -- Calculate rep progress toward the goal
                local targetRep = BoneyardTBC_DO.REP_THRESHOLDS[step.repGoal] or 0
                local currentRep = playerReps[step.faction] or 0
                if targetRep > 0 then
                    local pct = math.min(currentRep / targetRep, 1)
                    row.repBar:SetValue(pct)
                    row.repBar:SetBarText(currentRep .. "/" .. targetRep)
                else
                    row.repBar:SetValue(0)
                end
            else
                if row.repBar then
                    row.repBar:Hide()
                end
            end

            -- Adjust row description to not overlap with sub-info
            row.desc:SetPoint("RIGHT", row, "RIGHT", -36, 6)
        else
            row.subInfo:Hide()
            if row.repBar then
                row.repBar:Hide()
            end
            -- Reset description vertical position
            row.desc:ClearAllPoints()
            row.desc:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.desc:SetPoint("RIGHT", row, "RIGHT", -36, 0)
        end

        yOffset = yOffset + rowHeight
    end

    ----------------------------------------------------------------
    -- Hide any excess rows from a previous build with more steps
    ----------------------------------------------------------------
    for i = #route + 1, #self.routeRows do
        self.routeRows[i]:Hide()
    end

    ----------------------------------------------------------------
    -- Set scroll child height to fit all rows
    ----------------------------------------------------------------
    scrollChild:SetHeight(yOffset)
end

----------------------------------------------------------------------
-- DO:RefreshRouteTab() — Rebuild route rows from the latest result
----------------------------------------------------------------------

function DO:RefreshRouteTab()
    if not self.routeTab then return end

    -- Rebuild all rows
    self:BuildRouteRows()

    -- Auto-scroll to current step
    local db = self.db
    local scrollFrame = self.routeScrollFrame
    if scrollFrame and db.currentStep and db.currentStep > 1 and self.routeRowPositions then
        local scrollPos = self.routeRowPositions[db.currentStep] or 0
        local visibleHeight = scrollFrame:GetHeight() or 400
        scrollPos = math.max(0, scrollPos - (visibleHeight / 2) + (ROW_HEIGHT / 2))
        scrollFrame:SetVerticalScroll(scrollPos)
    end
end
