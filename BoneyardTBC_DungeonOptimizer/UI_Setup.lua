----------------------------------------------------------------------
-- BoneyardTBC DungeonOptimizer UI — Setup Tab
-- Character info, optimization mode, quest chains, sync settings,
-- reputation goals, and summary panel.
----------------------------------------------------------------------

local DO = BoneyardTBC_DO.module
local UI = BoneyardTBC_DO.UI

local FACTION_ORDER      = UI.FACTION_ORDER
local PANEL_BACKDROP     = UI.PANEL_BACKDROP
local FormatNumber       = UI.FormatNumber
local GetStandingName    = UI.GetStandingName
local GetStandingNameOnly = UI.GetStandingNameOnly
local CreateSectionHeader = UI.CreateSectionHeader
local CreateLabel        = UI.CreateLabel
local CreateValueText    = UI.CreateValueText

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
