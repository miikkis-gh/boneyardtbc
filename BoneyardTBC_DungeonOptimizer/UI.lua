----------------------------------------------------------------------
-- BoneyardTBC DungeonOptimizer UI
-- Tab creation functions for the DungeonOptimizer module.
-- Tab 1: Setup (character info, options, rep goals, summary)
-- Tab 2: Route (scrollable step list with status indicators)
-- Tab 3: Tracker (live progress dashboard)
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

    local modeHeader = CreateSectionHeader(leftCol, "Mode", 0, -76)

    local balancedBtn = BoneyardTBC.Widgets.CreateTabButton(leftCol, "Balanced", function()
        db.optimizationMode = "balanced"
        W.balancedBtn:SetSelected(true)
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
        W.levelingBtn:SetSelected(true)
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

    local questHeader = CreateSectionHeader(leftCol, "Optional Quests", 0, -130)

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

    local showOverlayCB = BoneyardTBC.Widgets.CreateCheckbox(leftCol, "Show Overlay", db.showOverlay ~= false, function(checked)
        db.showOverlay = checked
        if BoneyardTBC_DO.Overlay then
            BoneyardTBC_DO.Overlay.SetVisible(checked)
        end
    end)
    showOverlayCB:SetPoint("TOPLEFT", alertsCB, "BOTTOMLEFT", 0, -2)
    W.showOverlayCB = showOverlayCB

    local soundAlertsCB = BoneyardTBC.Widgets.CreateCheckbox(leftCol, "Enable Sound Alerts", db.enableSoundAlerts ~= false, function(checked)
        db.enableSoundAlerts = checked
    end)
    soundAlertsCB:SetPoint("TOPLEFT", showOverlayCB, "BOTTOMLEFT", 0, -2)
    W.soundAlertsCB = soundAlertsCB

    ----------------------------------------------------------------
    -- 4. REPUTATION GOALS
    ----------------------------------------------------------------

    local repHeader = CreateSectionHeader(leftCol, "Reputation Goals", 0, -355)

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
            cb:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -2)
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
-- Tab 3: Tracker — Live Progress Dashboard
----------------------------------------------------------------------

-- Heroic key factions (all require Revered in TBC)
local HEROIC_KEY_FACTIONS = {
    { key = "HONOR_HOLD",   name = "Honor Hold" },
    { key = "CENARION_EXP", name = "Cenarion Expedition" },
    { key = "CONSORTIUM",   name = "The Consortium" },
    { key = "LOWER_CITY",   name = "Lower City" },
    { key = "KEEPERS_TIME", name = "Keepers of Time" },
}

-- Karazhan attunement checklist items
-- Each item's step field is the ORIGINAL route step number (the `step` field)
local KARA_CHECKLIST = {
    { label = "Shadow Labyrinth Key",           step = 17 },
    { label = "First Fragment (Shadow Lab)",     step = 58 },
    { label = "Second Fragment (Steamvault)",    step = 63 },
    { label = "Third Fragment (Arcatraz)",       step = 117 },
    { label = "The Master's Touch",             step = 124 },
    { label = "Karazhan Attuned!",              step = 130 },
}

-- Standing color map for reputation bars
local STANDING_COLORS = {
    Neutral  = { 0.5, 0.5, 0.5 },
    Friendly = { 0.2, 0.7, 0.2 },
    Honored  = { 0.2, 0.4, 0.8 },
    Revered  = { 0.6, 0.2, 0.8 },
    Exalted  = { 0.9, 0.8, 0.2 },
}

function DO:CreateTrackerTab(parent)
    local db = self.db
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)

    self.trackerTab = tab
    self.trackerWidgets = {}

    local TW = self.trackerWidgets

    -- We use a scroll frame for the entire tracker content so it can
    -- handle many reputation rows + attunement checklist
    local scrollFrame = CreateFrame("ScrollFrame", "BoneyardTBC_DOTrackerScroll", tab, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -26, 0)
    TW.scrollFrame = scrollFrame

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth() or 640)
    content:SetHeight(1) -- resized at the end
    scrollFrame:SetScrollChild(content)
    TW.content = content

    scrollFrame:SetScript("OnSizeChanged", function(sf, width, height)
        content:SetWidth(width)
    end)

    local yOffset = 0

    ----------------------------------------------------------------
    -- 1. CURRENT STEP (top, ~80px)
    ----------------------------------------------------------------

    local stepPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    stepPanel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    stepPanel:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    stepPanel:SetHeight(80)
    stepPanel:SetBackdrop(PANEL_BACKDROP)
    stepPanel:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    stepPanel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    TW.stepPanel = stepPanel

    -- Type icon (32x32)
    local stepIcon = stepPanel:CreateTexture(nil, "ARTWORK")
    stepIcon:SetSize(32, 32)
    stepIcon:SetPoint("LEFT", stepPanel, "LEFT", 10, 4)
    stepIcon:SetTexture(STEP_ICONS.travel)
    TW.stepIcon = stepIcon

    -- Step description (large text)
    local stepDesc = stepPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stepDesc:SetPoint("TOPLEFT", stepIcon, "TOPRIGHT", 10, 2)
    stepDesc:SetPoint("RIGHT", stepPanel, "RIGHT", -100, 0)
    stepDesc:SetJustifyH("LEFT")
    stepDesc:SetWordWrap(true)
    stepDesc:SetText("No route calculated")
    stepDesc:SetTextColor(1, 1, 1, 1)
    TW.stepDesc = stepDesc

    -- "Run X of Y" sub-text for dungeon steps
    local runText = stepPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    runText:SetPoint("TOPLEFT", stepDesc, "BOTTOMLEFT", 0, -2)
    runText:SetText("")
    runText:Hide()
    TW.runText = runText

    -- "Skip" button (right side, only for travel/checkpoint)
    local skipBtn = CreateFrame("Button", nil, stepPanel, "BackdropTemplate")
    skipBtn:SetSize(80, 24)
    skipBtn:SetPoint("RIGHT", stepPanel, "RIGHT", -10, 0)
    skipBtn:SetBackdrop(PANEL_BACKDROP)
    skipBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    skipBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local skipBtnText = skipBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    skipBtnText:SetPoint("CENTER", skipBtn, "CENTER", 0, 0)
    skipBtnText:SetText("Skip")
    skipBtnText:SetTextColor(1, 1, 1, 1)

    skipBtn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    local skipHl = skipBtn:GetHighlightTexture()
    skipHl:SetVertexColor(1, 1, 1, 0.1)

    skipBtn:SetScript("OnClick", function()
        BoneyardTBC_DO.Tracker.SkipStep()
    end)
    skipBtn:Hide()
    TW.skipBtn = skipBtn

    yOffset = yOffset - 88

    ----------------------------------------------------------------
    -- 2. LEVEL PROGRESS (~50px)
    ----------------------------------------------------------------

    local levelHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    levelHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    levelHeader:SetText("Level ?")
    levelHeader:SetTextColor(1, 0.82, 0, 1)
    TW.levelHeader = levelHeader

    yOffset = yOffset - 22

    local xpBar = BoneyardTBC.Widgets.CreateProgressBar(content, 640, 18, { 0.2, 0.4, 0.8 })
    xpBar:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
    xpBar:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    xpBar:SetValue(0)
    xpBar:SetBarText("0 / 0 XP")
    TW.xpBar = xpBar

    yOffset = yOffset - 30

    ----------------------------------------------------------------
    -- 3. REPUTATION BARS (variable height)
    ----------------------------------------------------------------

    local repHeader = CreateSectionHeader(content, "Reputation Progress", 0, yOffset)
    TW.repHeader = repHeader

    yOffset = yOffset - 22

    -- We create rep bar rows dynamically in RefreshTrackerTab, but
    -- store a container starting Y for layout.
    TW.repBarsStartY = yOffset
    TW.repBarRows = {}

    -- Pre-create rows for all factions (show/hide based on enabled goals)
    for _, factionKey in ipairs(FACTION_ORDER) do
        local factionData = BoneyardTBC_DO.FACTIONS[factionKey]
        if factionData then
            local row = {}
            row.key = factionKey

            -- Faction name label (140px, left)
            local nameLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameLabel:SetText(factionData.name)
            nameLabel:SetWidth(140)
            nameLabel:SetJustifyH("LEFT")
            nameLabel:SetTextColor(0.9, 0.9, 0.9, 1)
            row.nameLabel = nameLabel

            -- Progress bar (300px wide, 14px tall)
            local bar = BoneyardTBC.Widgets.CreateProgressBar(content, 300, 14, { 0.5, 0.5, 0.5 })
            row.bar = bar

            -- Standing text right of bar
            local standingLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            standingLabel:SetText("Neutral 0/3000")
            standingLabel:SetTextColor(0.9, 0.9, 0.9, 1)
            standingLabel:SetJustifyH("LEFT")
            row.standingLabel = standingLabel

            -- Hide initially (shown by RefreshTrackerTab)
            nameLabel:Hide()
            bar:Hide()
            standingLabel:Hide()

            TW.repBarRows[#TW.repBarRows + 1] = row
        end
    end

    ----------------------------------------------------------------
    -- 4. ATTUNEMENT CHECKLIST (bottom section)
    ----------------------------------------------------------------

    -- These will be positioned by RefreshTrackerTab after the rep bars

    -- "Attunement Progress" header
    local attHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    attHeader:SetText("Attunement Progress")
    attHeader:SetTextColor(1, 0.82, 0, 1)
    TW.attHeader = attHeader

    -- Heroic Keys sub-header
    local heroicLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heroicLabel:SetText("Heroic Keys:")
    heroicLabel:SetTextColor(1, 0.82, 0, 1)
    TW.heroicLabel = heroicLabel

    -- Heroic key checklist rows
    TW.heroicRows = {}
    for _, hkData in ipairs(HEROIC_KEY_FACTIONS) do
        local row = {}
        row.key = hkData.key

        local icon = content:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
        row.icon = icon

        local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetText(hkData.name)
        label:SetTextColor(0.9, 0.3, 0.3, 1)
        label:SetJustifyH("LEFT")
        row.label = label

        TW.heroicRows[#TW.heroicRows + 1] = row
    end

    -- Karazhan Attunement sub-header
    local karaLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    karaLabel:SetText("Karazhan Attunement:")
    karaLabel:SetTextColor(1, 0.82, 0, 1)
    TW.karaLabel = karaLabel

    -- Karazhan checklist rows
    TW.karaRows = {}
    for _, checkItem in ipairs(KARA_CHECKLIST) do
        local row = {}
        row.step = checkItem.step
        row.labelText = checkItem.label

        local icon = content:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
        row.icon = icon

        local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetText(checkItem.label)
        label:SetTextColor(0.9, 0.3, 0.3, 1)
        label:SetJustifyH("LEFT")
        row.label = label

        TW.karaRows[#TW.karaRows + 1] = row
    end

    -- Initial population deferred to OnShow to ensure widths are resolved
    tab:SetScript("OnShow", function()
        content:SetWidth(scrollFrame:GetWidth())
        -- Update xpBar width to match available content width
        TW.xpBar.barWidth = content:GetWidth()
        DO:RefreshTrackerTab()
    end)

    return tab
end

----------------------------------------------------------------------
-- DO:RefreshTrackerTab() — Update all tracker elements
----------------------------------------------------------------------

function DO:RefreshTrackerTab()
    if not self.trackerWidgets then return end
    local TW = self.trackerWidgets
    local db = self.db
    local playerState = BoneyardTBC_DO.Tracker and BoneyardTBC_DO.Tracker.playerState
    local lastResult = BoneyardTBC_DO.Optimizer and BoneyardTBC_DO.Optimizer.lastResult
    local route = lastResult and lastResult.route
    local content = TW.content
    if not content then return end

    ----------------------------------------------------------------
    -- 1. Current Step display
    ----------------------------------------------------------------
    local currentStepNum = db.currentStep or 1
    local currentStep = nil
    if route then
        for _, step in ipairs(route) do
            if step.step == currentStepNum then
                currentStep = step
                break
            end
        end
    end

    if currentStep then
        -- Set icon
        local iconPath = STEP_ICONS[currentStep.type] or STEP_ICONS.travel
        TW.stepIcon:SetTexture(iconPath)

        -- Set description
        local descText = ""
        if currentStep.type == "travel" then
            descText = currentStep.text or "Travel"
        elseif currentStep.type == "dungeon" then
            local dungeon = BoneyardTBC_DO.DUNGEONS[currentStep.dungeon]
            descText = (dungeon and dungeon.name) or (currentStep.dungeon or "Unknown Dungeon")
        elseif currentStep.type == "quest" then
            local action = currentStep.action or "Quest"
            local quest = currentStep.quest or ""
            descText = action .. ": " .. quest
            if currentStep.npc then
                descText = descText .. " (" .. currentStep.npc .. ")"
            end
        elseif currentStep.type == "checkpoint" then
            descText = currentStep.text or "Checkpoint"
        else
            descText = currentStep.text or currentStep.note or ""
        end
        TW.stepDesc:SetText(descText)

        -- Run counter for dungeon steps
        if currentStep.type == "dungeon" then
            local dungeonKey = currentStep.dungeon
            local currentRuns = (db.dungeonRunCounts and db.dungeonRunCounts[dungeonKey]) or 0
            local totalRuns = currentStep.calculatedRuns or currentStep.runs or 0
            if totalRuns == -1 then totalRuns = "?" end
            TW.runText:SetText("Run " .. currentRuns .. " of " .. tostring(totalRuns))
            TW.runText:Show()
        else
            TW.runText:Hide()
        end

        -- Skip button visibility
        if currentStep.type == "travel" or currentStep.type == "checkpoint" then
            TW.skipBtn:Show()
        else
            TW.skipBtn:Hide()
        end
    else
        -- No current step found
        TW.stepIcon:SetTexture(STEP_ICONS.checkpoint)
        if route and #route > 0 then
            TW.stepDesc:SetText("Route complete!")
        else
            TW.stepDesc:SetText("No route calculated")
        end
        TW.runText:Hide()
        TW.skipBtn:Hide()
    end

    ----------------------------------------------------------------
    -- 2. Level + XP bar
    ----------------------------------------------------------------
    if playerState then
        local level = playerState.level or 1
        local xp = playerState.xp or 0
        local xpMax = playerState.xpMax or 1

        TW.levelHeader:SetText("Level " .. level)

        if level >= 70 then
            TW.xpBar:SetValue(1)
            TW.xpBar:SetBarText("Max Level")
        else
            local pct = (xpMax > 0) and (xp / xpMax) or 0
            TW.xpBar:SetValue(pct)
            TW.xpBar:SetBarText(FormatNumber(xp) .. " / " .. FormatNumber(xpMax) .. " XP")
        end
    else
        TW.levelHeader:SetText("Level ?")
        TW.xpBar:SetValue(0)
        TW.xpBar:SetBarText("0 / 0 XP")
    end

    ----------------------------------------------------------------
    -- 3. Reputation bars
    ----------------------------------------------------------------
    local repY = TW.repBarsStartY
    local visibleRepCount = 0

    for _, row in ipairs(TW.repBarRows) do
        local factionKey = row.key
        local goalTarget = db.repGoals and db.repGoals[factionKey]

        if goalTarget then
            -- This faction is enabled -- show it
            row.nameLabel:ClearAllPoints()
            row.nameLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, repY)
            row.nameLabel:Show()

            row.bar:ClearAllPoints()
            row.bar:SetPoint("TOPLEFT", content, "TOPLEFT", 145, repY - 1)
            row.bar:Show()

            row.standingLabel:ClearAllPoints()
            row.standingLabel:SetPoint("LEFT", row.bar, "RIGHT", 8, 0)
            row.standingLabel:Show()

            -- Get current rep
            local currentRep = 0
            if playerState and playerState.reps and playerState.reps[factionKey] then
                currentRep = playerState.reps[factionKey]
            end

            -- Determine standing and color
            local standingName = GetStandingNameOnly(currentRep)
            local standingColor = STANDING_COLORS[standingName] or STANDING_COLORS.Neutral
            row.bar:SetBarColor(standingColor[1], standingColor[2], standingColor[3])

            -- Calculate progress toward goal
            local targetRep = BoneyardTBC_DO.REP_THRESHOLDS[goalTarget] or 0

            -- Find the start of the current standing bracket for progress display
            local standingStart = 0
            local standingEnd = 3000 -- default to Neutral range
            local levels = BoneyardTBC_DO.REP_LEVELS
            for i = #levels, 1, -1 do
                if currentRep >= levels[i].min then
                    standingStart = levels[i].min
                    standingEnd = levels[i].max + 1
                    break
                end
            end

            -- Progress bar value = how far toward the target goal
            local pct = 0
            if targetRep > 0 then
                pct = math.min(currentRep / targetRep, 1)
            end
            row.bar:SetValue(pct)

            -- Standing text: "Honored 2,450 / 12,000"
            local progressInBracket = currentRep - standingStart
            local bracketSize = standingEnd - standingStart
            row.standingLabel:SetText(standingName .. " " .. FormatNumber(progressInBracket) .. " / " .. FormatNumber(bracketSize))
            row.bar:SetBarText("")

            repY = repY - 22
            visibleRepCount = visibleRepCount + 1
        else
            -- This faction is disabled -- hide it
            row.nameLabel:Hide()
            row.bar:Hide()
            row.standingLabel:Hide()
        end
    end

    -- If no rep goals enabled, show a note
    if visibleRepCount == 0 then
        repY = repY - 20
    end

    ----------------------------------------------------------------
    -- 4. Attunement Checklist
    ----------------------------------------------------------------
    local attY = repY - 16

    TW.attHeader:ClearAllPoints()
    TW.attHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, attY)
    attY = attY - 22

    -- Heroic Keys
    TW.heroicLabel:ClearAllPoints()
    TW.heroicLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 4, attY)
    attY = attY - 20

    local playerReps = (playerState and playerState.reps) or {}

    for _, row in ipairs(TW.heroicRows) do
        local factionKey = row.key
        local currentRep = playerReps[factionKey] or 0
        local reveredThreshold = BoneyardTBC_DO.REP_THRESHOLDS.Revered or 12000
        local isComplete = (currentRep >= reveredThreshold)

        row.icon:ClearAllPoints()
        row.icon:SetPoint("TOPLEFT", content, "TOPLEFT", 10, attY)
        if isComplete then
            row.icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
            row.label:SetTextColor(0.3, 0.9, 0.3, 1)
        else
            row.icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
            row.label:SetTextColor(0.9, 0.3, 0.3, 1)
        end

        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)

        attY = attY - 20
    end

    -- Karazhan Attunement (only if enabled)
    if db.includeKarazhan then
        attY = attY - 8

        TW.karaLabel:ClearAllPoints()
        TW.karaLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 4, attY)
        TW.karaLabel:Show()
        attY = attY - 20

        local completedSteps = db.completedSteps or {}

        for _, row in ipairs(TW.karaRows) do
            local isComplete = completedSteps[row.step] == true

            row.icon:ClearAllPoints()
            row.icon:SetPoint("TOPLEFT", content, "TOPLEFT", 10, attY)
            if isComplete then
                row.icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
                row.label:SetTextColor(0.3, 0.9, 0.3, 1)
            else
                row.icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
                row.label:SetTextColor(0.9, 0.3, 0.3, 1)
            end

            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.icon:Show()
            row.label:Show()

            attY = attY - 20
        end
    else
        -- Hide Karazhan checklist
        TW.karaLabel:Hide()
        for _, row in ipairs(TW.karaRows) do
            row.icon:Hide()
            row.label:Hide()
        end
    end

    ----------------------------------------------------------------
    -- Set content height to fit everything
    ----------------------------------------------------------------
    local totalHeight = math.abs(attY) + 20
    content:SetHeight(totalHeight)
end

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
    lfgPanel:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    lfgPanel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
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

    -- Store planning view start offset (computed dynamically in refresh)
    GW.planningStartY = yOffset - 20

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
    local content = GW.content
    if not content then return end

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

    ----------------------------------------------------------------
    -- 2. Leaderboard
    ----------------------------------------------------------------
    local sorted = BoneyardTBC_DO.Sync.GetSortedRoster()
    local LB = GW.LB_COLS
    local LB_ROW_H = 18

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
            local dungeonName = "\226\128\148" -- em dash
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

            rowY = rowY - LB_ROW_H
        end

        GW.planningStartY = GW.leaderboardRowsStartY - (#sorted * LB_ROW_H) - 16
    end

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
end

----------------------------------------------------------------------
-- Wire onStepAdvanced callback (after all tab functions are defined)
----------------------------------------------------------------------

BoneyardTBC_DO.Tracker.onStepAdvanced = function()
    if DO.RefreshTrackerTab then DO:RefreshTrackerTab() end
    if DO.RefreshRouteTab then DO:RefreshRouteTab() end
end
