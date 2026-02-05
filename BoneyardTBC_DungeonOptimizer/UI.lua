----------------------------------------------------------------------
-- BoneyardTBC DungeonOptimizer UI
-- Tab creation functions for the DungeonOptimizer module.
-- Tab 1: Setup (character info, options, rep goals, summary)
-- Tab 2: Route (scrollable step list with status indicators)
-- Tab 3: Tracker (stub — Task 9)
----------------------------------------------------------------------

local DO = BoneyardTBC_DO.module

----------------------------------------------------------------------
-- Ordered faction keys for consistent display order
----------------------------------------------------------------------

local FACTION_ORDER = {
    "HONOR_HOLD",
    "CENARION_EXP",
    "CONSORTIUM",
    "KEEPERS_TIME",
    "LOWER_CITY",
    "SHATAR",
}

----------------------------------------------------------------------
-- Backdrop for dark panels (summary, etc.)
----------------------------------------------------------------------

local PANEL_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

----------------------------------------------------------------------
-- Helper: FormatNumber(n) — adds comma separators
-- e.g. 1234567 -> "1,234,567"
----------------------------------------------------------------------

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

----------------------------------------------------------------------
-- Helper: GetStandingName(totalRep) — returns standing name and
-- progress string, e.g., "Friendly 1200/3000"
----------------------------------------------------------------------

local function GetStandingName(totalRep)
    if not totalRep or type(totalRep) ~= "number" then
        return "Unknown 0/0"
    end

    local levels = BoneyardTBC_DO.REP_LEVELS
    for i = #levels, 1, -1 do
        local level = levels[i]
        if totalRep >= level.min then
            local progress = totalRep - level.min
            local rangeSize = level.max - level.min + 1
            return level.name .. " " .. progress .. "/" .. rangeSize
        end
    end

    return "Neutral 0/3000"
end

----------------------------------------------------------------------
-- Helper: GetStandingNameOnly(totalRep) — returns just the standing
-- name without progress numbers
----------------------------------------------------------------------

local function GetStandingNameOnly(totalRep)
    if not totalRep or type(totalRep) ~= "number" then
        return "Unknown"
    end

    local levels = BoneyardTBC_DO.REP_LEVELS
    for i = #levels, 1, -1 do
        if totalRep >= levels[i].min then
            return levels[i].name
        end
    end

    return "Neutral"
end

----------------------------------------------------------------------
-- Helper: CreateSectionHeader(parent, text, xOffset, yOffset)
-- Creates a GameFontNormalLarge header text anchored TOPLEFT
----------------------------------------------------------------------

local function CreateSectionHeader(parent, text, xOffset, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    header:SetText(text)
    header:SetTextColor(1, 0.82, 0, 1)
    return header
end

----------------------------------------------------------------------
-- Helper: CreateLabel(parent, text, font)
-- Creates a simple text label (not anchored)
----------------------------------------------------------------------

local function CreateLabel(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetText(text or "")
    label:SetTextColor(0.9, 0.9, 0.9, 1)
    return label
end

----------------------------------------------------------------------
-- Helper: CreateValueText(parent, text, font)
-- Creates a value display text (not anchored)
----------------------------------------------------------------------

local function CreateValueText(parent, text, font)
    local val = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    val:SetText(text or "")
    val:SetTextColor(1, 1, 1, 1)
    return val
end

----------------------------------------------------------------------
-- Tab 1: Setup — DO:CreateSetupTab(parent)
----------------------------------------------------------------------

function DO:CreateSetupTab(parent)
    local db = self.db
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)

    -- Store references for RefreshSetupTab
    self.setupTab = tab
    self.setupWidgets = {}

    local W = self.setupWidgets -- shorthand

    ----------------------------------------------------------------
    -- LEFT COLUMN (340px wide)
    ----------------------------------------------------------------

    local leftCol = CreateFrame("Frame", nil, tab)
    leftCol:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    leftCol:SetSize(340, 440)

    ----------------------------------------------------------------
    -- 1. CHARACTER section
    ----------------------------------------------------------------

    local charHeader = CreateSectionHeader(leftCol, "Character", 0, 0)

    -- Faction row
    local factionLabel = CreateLabel(leftCol, "Faction:")
    factionLabel:SetPoint("TOPLEFT", charHeader, "BOTTOMLEFT", 0, -8)

    local factionIcon = leftCol:CreateTexture(nil, "ARTWORK")
    factionIcon:SetTexture("Interface\\Icons\\INV_BannerPVP_02")
    factionIcon:SetSize(14, 14)
    factionIcon:SetPoint("LEFT", factionLabel, "RIGHT", 6, 0)

    local factionValue = CreateValueText(leftCol, "Alliance")
    factionValue:SetPoint("LEFT", factionIcon, "RIGHT", 4, 0)
    W.factionValue = factionValue
    W.factionIcon = factionIcon

    -- Level row
    local levelLabel = CreateLabel(leftCol, "Level:")
    levelLabel:SetPoint("TOPLEFT", factionLabel, "BOTTOMLEFT", 0, -4)

    local levelValue = CreateValueText(leftCol, "?")
    levelValue:SetPoint("LEFT", levelLabel, "RIGHT", 6, 0)
    W.levelValue = levelValue

    -- Race row
    local raceLabel = CreateLabel(leftCol, "Race:")
    raceLabel:SetPoint("TOPLEFT", levelLabel, "BOTTOMLEFT", 0, -4)

    local raceValue = CreateValueText(leftCol, "?")
    raceValue:SetPoint("LEFT", raceLabel, "RIGHT", 6, 0)
    W.raceValue = raceValue

    local raceBonusText = CreateLabel(leftCol, "(+10% Rep)", "GameFontNormalSmall")
    raceBonusText:SetPoint("LEFT", raceValue, "RIGHT", 6, 0)
    raceBonusText:SetTextColor(1, 0.82, 0, 1)
    raceBonusText:Hide()
    W.raceBonusText = raceBonusText

    ----------------------------------------------------------------
    -- 2. OPTIMIZATION MODE
    ----------------------------------------------------------------

    local modeHeader = CreateSectionHeader(leftCol, "Mode", 0, -100)

    local balancedBtn = BoneyardTBC.Widgets.CreateTabButton(leftCol, "Balanced", function()
        db.optimizationMode = "balanced"
        balancedBtn:SetSelected(true)
        W.levelingBtn:SetSelected(false)
        BoneyardTBC_DO.Optimizer.Recalculate()
        DO:RefreshSummary()
    end)
    balancedBtn:SetSize(160, 28)
    balancedBtn:SetPoint("TOPLEFT", modeHeader, "BOTTOMLEFT", 0, -6)
    W.balancedBtn = balancedBtn

    local levelingBtn = BoneyardTBC.Widgets.CreateTabButton(leftCol, "Leveling", function()
        db.optimizationMode = "leveling"
        W.balancedBtn:SetSelected(false)
        levelingBtn:SetSelected(true)
        BoneyardTBC_DO.Optimizer.Recalculate()
        DO:RefreshSummary()
    end)
    levelingBtn:SetSize(160, 28)
    levelingBtn:SetPoint("LEFT", balancedBtn, "RIGHT", 4, 0)
    W.levelingBtn = levelingBtn

    -- Set initial selection
    if db.optimizationMode == "leveling" then
        balancedBtn:SetSelected(false)
        levelingBtn:SetSelected(true)
    else
        balancedBtn:SetSelected(true)
        levelingBtn:SetSelected(false)
    end

    ----------------------------------------------------------------
    -- 3. OPTIONAL QUEST CHAINS
    ----------------------------------------------------------------

    local questHeader = CreateSectionHeader(leftCol, "Optional Quests", 0, -162)

    -- Karazhan checkbox
    local karazhanCB = BoneyardTBC.Widgets.CreateCheckbox(leftCol, "Karazhan Attunement (+63,100 XP)", db.includeKarazhan, function(checked)
        db.includeKarazhan = checked
        -- If Karazhan unchecked, also disable Arcatraz
        if not checked then
            db.includeArcatrazKey = false
            W.arcatrazCB:SetChecked(false)
            W.arcatrazCB:Disable()
            W.arcatrazCB.label:SetTextColor(0.5, 0.5, 0.5, 1)
        else
            W.arcatrazCB:Enable()
            W.arcatrazCB.label:SetTextColor(0.9, 0.9, 0.9, 1)
        end
        BoneyardTBC_DO.Optimizer.Recalculate()
        DO:RefreshSummary()
    end)
    karazhanCB:SetPoint("TOPLEFT", questHeader, "BOTTOMLEFT", 0, -8)
    W.karazhanCB = karazhanCB

    -- Arcatraz Key Chain checkbox (indented 20px)
    local arcatrazCB = BoneyardTBC.Widgets.CreateCheckbox(leftCol, "Arcatraz Key Chain (+113,450 XP)", db.includeArcatrazKey, function(checked)
        db.includeArcatrazKey = checked
        BoneyardTBC_DO.Optimizer.Recalculate()
        DO:RefreshSummary()
    end)
    arcatrazCB:SetPoint("TOPLEFT", karazhanCB, "BOTTOMLEFT", 20, -4)
    W.arcatrazCB = arcatrazCB

    -- Disable Arcatraz if Karazhan is unchecked
    if not db.includeKarazhan then
        arcatrazCB:Disable()
        arcatrazCB.label:SetTextColor(0.5, 0.5, 0.5, 1)
    end

    -- Shattered Halls Key checkbox
    local shatteredCB = BoneyardTBC.Widgets.CreateCheckbox(leftCol, "Shattered Halls Key (+45,100 XP)", db.includeShatteredHallsKey, function(checked)
        db.includeShatteredHallsKey = checked
        BoneyardTBC_DO.Optimizer.Recalculate()
        DO:RefreshSummary()
    end)
    shatteredCB:SetPoint("TOPLEFT", arcatrazCB, "BOTTOMLEFT", -20, -4)
    W.shatteredCB = shatteredCB

    ----------------------------------------------------------------
    -- 4. REPUTATION GOALS
    ----------------------------------------------------------------

    local repHeader = CreateSectionHeader(leftCol, "Reputation Goals", 0, -280)

    -- Column headers
    local colFaction = CreateLabel(leftCol, "Faction", "GameFontNormalSmall")
    colFaction:SetPoint("TOPLEFT", repHeader, "BOTTOMLEFT", 0, -6)
    colFaction:SetWidth(140)
    colFaction:SetTextColor(0.7, 0.7, 0.7, 1)

    local colCurrent = CreateLabel(leftCol, "Current", "GameFontNormalSmall")
    colCurrent:SetPoint("LEFT", colFaction, "LEFT", 140, 0)
    colCurrent:SetTextColor(0.7, 0.7, 0.7, 1)

    local colTarget = CreateLabel(leftCol, "Target", "GameFontNormalSmall")
    colTarget:SetPoint("LEFT", colFaction, "LEFT", 220, 0)
    colTarget:SetTextColor(0.7, 0.7, 0.7, 1)

    local colNeeded = CreateLabel(leftCol, "Needed", "GameFontNormalSmall")
    colNeeded:SetPoint("LEFT", colFaction, "LEFT", 300, 0)
    colNeeded:SetTextColor(0.7, 0.7, 0.7, 1)

    -- Faction rows
    W.repRows = {}

    local prevAnchor = colFaction
    for _, factionKey in ipairs(FACTION_ORDER) do
        local factionData = BoneyardTBC_DO.FACTIONS[factionKey]
        if factionData then
            local row = {}
            row.key = factionKey

            -- Determine initial enabled state and target
            local goalTarget = db.repGoals and db.repGoals[factionKey]
            local isEnabled = (goalTarget ~= nil)

            -- Checkbox + faction name
            local cb = BoneyardTBC.Widgets.CreateCheckbox(leftCol, factionData.name, isEnabled, function(checked)
                if checked then
                    -- Enable with a default target
                    if not db.repGoals then db.repGoals = {} end
                    db.repGoals[factionKey] = row.dropdown:GetSelectedValue()
                    row.dropdown:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
                    row.currentText:SetTextColor(0.9, 0.9, 0.9, 1)
                    row.neededText:SetTextColor(1, 1, 1, 1)
                else
                    -- Disable
                    if db.repGoals then db.repGoals[factionKey] = nil end
                    row.currentText:SetTextColor(0.5, 0.5, 0.5, 1)
                    row.neededText:SetTextColor(0.5, 0.5, 0.5, 1)
                end
                BoneyardTBC_DO.Optimizer.Recalculate()
                DO:RefreshSummary()
                DO:RefreshRepNeeded()
            end)
            cb:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -4)
            cb.label:SetWidth(110)
            row.checkbox = cb

            -- Current rep text
            local currentText = CreateLabel(leftCol, "—", "GameFontNormalSmall")
            currentText:SetPoint("LEFT", cb, "LEFT", 140, 0)
            currentText:SetWidth(80)
            currentText:SetJustifyH("LEFT")
            row.currentText = currentText

            -- Target dropdown
            local targetOptions = {"Friendly", "Honored", "Revered", "Exalted"}
            local defaultTarget = goalTarget or "Revered"
            local dropdown = BoneyardTBC.Widgets.CreateDropdown(leftCol, targetOptions, defaultTarget, function(value)
                if db.repGoals and db.repGoals[factionKey] ~= nil then
                    db.repGoals[factionKey] = value
                    BoneyardTBC_DO.Optimizer.Recalculate()
                    DO:RefreshSummary()
                    DO:RefreshRepNeeded()
                end
            end)
            dropdown:SetSize(80, 20)
            dropdown:SetPoint("LEFT", cb, "LEFT", 220, 0)
            row.dropdown = dropdown

            -- Needed text
            local neededText = CreateValueText(leftCol, "—", "GameFontNormalSmall")
            neededText:SetPoint("LEFT", cb, "LEFT", 300, 0)
            neededText:SetWidth(40)
            row.neededText = neededText

            -- Grey out if disabled
            if not isEnabled then
                currentText:SetTextColor(0.5, 0.5, 0.5, 1)
                neededText:SetTextColor(0.5, 0.5, 0.5, 1)
            end

            W.repRows[#W.repRows + 1] = row

            prevAnchor = cb
        end
    end

    ----------------------------------------------------------------
    -- RIGHT COLUMN (340px wide)
    ----------------------------------------------------------------

    local rightCol = CreateFrame("Frame", nil, tab)
    rightCol:SetPoint("TOPLEFT", tab, "TOPLEFT", 350, 0)
    rightCol:SetSize(340, 440)

    ----------------------------------------------------------------
    -- 5. SUMMARY panel
    ----------------------------------------------------------------

    local summaryHeader = CreateSectionHeader(rightCol, "Summary", 0, 0)

    -- Dark background panel
    local summaryPanel = CreateFrame("Frame", nil, rightCol, "BackdropTemplate")
    summaryPanel:SetPoint("TOPLEFT", summaryHeader, "BOTTOMLEFT", 0, -6)
    summaryPanel:SetPoint("TOPRIGHT", rightCol, "TOPRIGHT", 0, -26)
    summaryPanel:SetHeight(340)
    summaryPanel:SetBackdrop(PANEL_BACKDROP)
    summaryPanel:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    summaryPanel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    W.summaryPanel = summaryPanel

    -- Summary stat labels and values
    local yPos = -10
    local LABEL_X = 10
    local VALUE_X = -10

    local function AddSummaryStat(labelText, valueDefault)
        local lbl = CreateLabel(summaryPanel, labelText, "GameFontNormal")
        lbl:SetPoint("TOPLEFT", summaryPanel, "TOPLEFT", LABEL_X, yPos)
        lbl:SetTextColor(0.8, 0.8, 0.8, 1)

        local val = CreateValueText(summaryPanel, valueDefault or "—", "GameFontNormal")
        val:SetPoint("TOPRIGHT", summaryPanel, "TOPRIGHT", VALUE_X, yPos)

        yPos = yPos - 18
        return lbl, val
    end

    local function AddSummarySubheader(text)
        local lbl = CreateLabel(summaryPanel, text, "GameFontNormal")
        lbl:SetPoint("TOPLEFT", summaryPanel, "TOPLEFT", LABEL_X, yPos)
        lbl:SetTextColor(1, 0.82, 0, 1)
        yPos = yPos - 18
        return lbl
    end

    local function AddSummaryLine(text, color)
        local lbl = CreateLabel(summaryPanel, text, "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", summaryPanel, "TOPLEFT", LABEL_X + 10, yPos)
        if color then
            lbl:SetTextColor(color.r, color.g, color.b, 1)
        else
            lbl:SetTextColor(0.9, 0.9, 0.9, 1)
        end
        yPos = yPos - 16
        return lbl
    end

    local _, totalRunsVal = AddSummaryStat("Total Dungeon Runs:", "—")
    W.totalRunsVal = totalRunsVal

    local _, finalLevelVal = AddSummaryStat("Projected Final Level:", "—")
    W.finalLevelVal = finalLevelVal

    local _, totalXPVal = AddSummaryStat("Total XP Gained:", "—")
    W.totalXPVal = totalXPVal

    -- Blank line
    yPos = yPos - 8

    -- Faction Progress sub-header
    AddSummarySubheader("Faction Progress:")

    -- Per-faction projected standing lines
    W.factionProgressLines = {}
    for _, factionKey in ipairs(FACTION_ORDER) do
        local factionData = BoneyardTBC_DO.FACTIONS[factionKey]
        if factionData then
            local line = AddSummaryLine("  " .. factionData.name .. ": —")
            W.factionProgressLines[factionKey] = line
        end
    end

    -- Blank line
    yPos = yPos - 4

    -- Karazhan Attuned line
    local karaLabel = CreateLabel(summaryPanel, "Karazhan Attuned:", "GameFontNormal")
    karaLabel:SetPoint("TOPLEFT", summaryPanel, "TOPLEFT", LABEL_X, yPos)
    karaLabel:SetTextColor(0.8, 0.8, 0.8, 1)

    local karaVal = CreateValueText(summaryPanel, "—", "GameFontNormal")
    karaVal:SetPoint("TOPRIGHT", summaryPanel, "TOPRIGHT", VALUE_X, yPos)
    W.karaVal = karaVal

    -- "View Optimized Route" button at bottom of summary
    local routeBtn = CreateFrame("Button", nil, summaryPanel, "BackdropTemplate")
    routeBtn:SetSize(200, 30)
    routeBtn:SetPoint("BOTTOM", summaryPanel, "BOTTOM", 0, 10)
    routeBtn:SetBackdrop(PANEL_BACKDROP)
    routeBtn:SetBackdropColor(0.2, 0.4, 0.7, 1)
    routeBtn:SetBackdropBorderColor(0.3, 0.5, 0.8, 1)

    local routeBtnText = routeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    routeBtnText:SetPoint("CENTER", routeBtn, "CENTER", 0, 0)
    routeBtnText:SetText("View Optimized Route")
    routeBtnText:SetTextColor(1, 1, 1, 1)

    routeBtn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    local routeHl = routeBtn:GetHighlightTexture()
    routeHl:SetVertexColor(1, 1, 1, 0.1)

    routeBtn:SetScript("OnClick", function()
        BoneyardTBC.MainFrame:SelectTab(2)
    end)

    ----------------------------------------------------------------
    -- Initial data population
    ----------------------------------------------------------------
    self:RefreshSetupTab()

    return tab
end

----------------------------------------------------------------------
-- DO:RefreshSetupTab() — Update all dynamic values in the Setup tab
----------------------------------------------------------------------

function DO:RefreshSetupTab()
    if not self.setupWidgets then return end
    local W = self.setupWidgets
    local playerState = BoneyardTBC_DO.Tracker and BoneyardTBC_DO.Tracker.playerState

    -- Character info
    if playerState then
        -- Faction
        local factionName = playerState.faction or "Alliance"
        W.factionValue:SetText(factionName)
        if factionName == "Alliance" then
            W.factionIcon:SetTexture("Interface\\Icons\\INV_BannerPVP_02")
        else
            W.factionIcon:SetTexture("Interface\\Icons\\INV_BannerPVP_01")
        end

        -- Level
        W.levelValue:SetText(tostring(playerState.level or "?"))

        -- Race
        local raceName = playerState.race or "?"
        W.raceValue:SetText(raceName)
        if playerState.isHuman then
            W.raceBonusText:Show()
        else
            W.raceBonusText:Hide()
        end
    else
        W.factionValue:SetText("Alliance")
        W.levelValue:SetText("?")
        W.raceValue:SetText("?")
        W.raceBonusText:Hide()
    end

    -- Update current rep values in goals table
    self:RefreshRepNeeded()

    -- Update summary
    self:RefreshSummary()
end

----------------------------------------------------------------------
-- DO:RefreshRepNeeded() — Update current rep and "needed" in goals
----------------------------------------------------------------------

function DO:RefreshRepNeeded()
    if not self.setupWidgets or not self.setupWidgets.repRows then return end

    local db = self.db
    local playerState = BoneyardTBC_DO.Tracker and BoneyardTBC_DO.Tracker.playerState

    for _, row in ipairs(self.setupWidgets.repRows) do
        local factionKey = row.key
        local currentRep = 0

        if playerState and playerState.reps and playerState.reps[factionKey] then
            currentRep = playerState.reps[factionKey]
        end

        -- Update current rep display
        row.currentText:SetText(GetStandingName(currentRep))

        -- Calculate needed
        local goalTarget = db.repGoals and db.repGoals[factionKey]
        if goalTarget then
            local targetRep = BoneyardTBC_DO.REP_THRESHOLDS[goalTarget] or 0
            local needed = targetRep - currentRep
            if needed <= 0 then
                row.neededText:SetText("Done")
                row.neededText:SetTextColor(0.3, 0.9, 0.3, 1)
            else
                row.neededText:SetText(FormatNumber(needed))
                row.neededText:SetTextColor(1, 1, 1, 1)
            end
        else
            row.neededText:SetText("—")
            row.neededText:SetTextColor(0.5, 0.5, 0.5, 1)
        end
    end
end

----------------------------------------------------------------------
-- DO:RefreshSummary() — Update summary panel from optimizer result
----------------------------------------------------------------------

function DO:RefreshSummary()
    if not self.setupWidgets then return end
    local W = self.setupWidgets
    local db = self.db
    local result = BoneyardTBC_DO.Optimizer and BoneyardTBC_DO.Optimizer.lastResult

    if result then
        -- Total runs
        W.totalRunsVal:SetText(tostring(result.totalRuns or 0))

        -- Projected final level
        W.finalLevelVal:SetText(tostring(result.finalLevel or "—"))

        -- Total XP gained
        W.totalXPVal:SetText(FormatNumber(result.totalXP or 0))

        -- Faction progress
        if result.finalReps then
            for factionKey, line in pairs(W.factionProgressLines) do
                local factionData = BoneyardTBC_DO.FACTIONS[factionKey]
                local rep = result.finalReps[factionKey]
                if factionData and rep then
                    local standing = GetStandingNameOnly(rep)
                    line:SetText("  " .. factionData.name .. ": " .. standing)
                else
                    line:SetText("  " .. (factionData and factionData.name or factionKey) .. ": —")
                end
            end
        end

        -- Karazhan attuned
        if db.includeKarazhan then
            W.karaVal:SetText("Yes")
            W.karaVal:SetTextColor(0.3, 0.9, 0.3, 1)
        else
            W.karaVal:SetText("No")
            W.karaVal:SetTextColor(0.9, 0.3, 0.3, 1)
        end
    else
        -- No result yet
        W.totalRunsVal:SetText("—")
        W.finalLevelVal:SetText("—")
        W.totalXPVal:SetText("—")

        for factionKey, line in pairs(W.factionProgressLines) do
            local factionData = BoneyardTBC_DO.FACTIONS[factionKey]
            line:SetText("  " .. (factionData and factionData.name or factionKey) .. ": —")
        end

        if db.includeKarazhan then
            W.karaVal:SetText("Yes")
            W.karaVal:SetTextColor(0.3, 0.9, 0.3, 1)
        elseif db.includeKarazhan == false then
            W.karaVal:SetText("No")
            W.karaVal:SetTextColor(0.9, 0.3, 0.3, 1)
        else
            W.karaVal:SetText("N/A")
            W.karaVal:SetTextColor(0.5, 0.5, 0.5, 1)
        end
    end
end

----------------------------------------------------------------------
-- Tab 2: Route — Scrollable step list
----------------------------------------------------------------------

-- Step type icon textures
local STEP_ICONS = {
    travel     = "Interface\\Icons\\Ability_Rogue_Sprint",
    dungeon    = "Interface\\Icons\\INV_Sword_04",
    quest      = "Interface\\Icons\\INV_Misc_Note_01",
    checkpoint = "Interface\\Icons\\INV_Misc_Rune_01",
}

-- Row height constant
local ROW_HEIGHT = 32

-- Highlight backdrop for the current step
local ROW_HIGHLIGHT_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

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
        if db.currentStep and db.currentStep > 1 then
            local scrollPos = (db.currentStep - 1) * ROW_HEIGHT
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
    for i, step in ipairs(route) do
        local row = self.routeRows[i]

        if not row then
            -- Create a new row frame
            row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
            row:SetHeight(ROW_HEIGHT)

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
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
        row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

        -- Determine effective row height (dungeon with sub-info needs more)
        local hasDungeonSubInfo = (step.type == "dungeon" and step.calculatedRuns and step.calculatedRuns > 0)

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

            -- Run counter
            local dungeonKey = step.dungeon
            local currentRuns = dungeonRunCounts[dungeonKey] or 0
            local totalRuns = step.calculatedRuns or step.runs or 0
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
    scrollChild:SetHeight(#route * ROW_HEIGHT)
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
    if scrollFrame and db.currentStep and db.currentStep > 1 then
        local scrollPos = (db.currentStep - 1) * ROW_HEIGHT
        local visibleHeight = scrollFrame:GetHeight() or 400
        scrollPos = math.max(0, scrollPos - (visibleHeight / 2) + (ROW_HEIGHT / 2))
        scrollFrame:SetVerticalScroll(scrollPos)
    end
end

----------------------------------------------------------------------
-- Tab 3: Tracker — Stub (Task 9)
----------------------------------------------------------------------

function DO:CreateTrackerTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)

    local placeholder = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    placeholder:SetPoint("CENTER", tab, "CENTER", 0, 0)
    placeholder:SetText("Tracker tab — coming soon")
    placeholder:SetTextColor(0.5, 0.5, 0.5, 1)

    return tab
end
