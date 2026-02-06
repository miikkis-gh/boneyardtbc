----------------------------------------------------------------------
-- BoneyardTBC DungeonOptimizer UI — Tracker Tab
-- Live progress dashboard: current step, XP, rep bars, attunement.
----------------------------------------------------------------------

local DO = BoneyardTBC_DO.module
local UI = BoneyardTBC_DO.UI

local FACTION_ORDER       = UI.FACTION_ORDER
local PANEL_BACKDROP      = UI.PANEL_BACKDROP
local FormatNumber        = UI.FormatNumber
local GetStandingNameOnly = UI.GetStandingNameOnly
local CreateSectionHeader = UI.CreateSectionHeader

----------------------------------------------------------------------
-- Tracker-specific constants
----------------------------------------------------------------------

-- Step type icon textures (duplicated from Route for independent loading)
local STEP_ICONS = {
    travel     = "Interface\\Icons\\Ability_Rogue_Sprint",
    dungeon    = "Interface\\Icons\\INV_Sword_04",
    quest      = "Interface\\Icons\\INV_Misc_Note_01",
    checkpoint = "Interface\\Icons\\INV_Misc_Rune_01",
}

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

----------------------------------------------------------------------
-- Tab 3: Tracker — DO:CreateTrackerTab(parent)
----------------------------------------------------------------------

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

        -- Run counter for dungeon steps (derived from rep progress when possible)
        if currentStep.type == "dungeon" then
            local currentRuns, totalRuns = BoneyardTBC_DO.Tracker.GetDungeonRunsDone(currentStep)
            TW.runText:SetText("Run " .. currentRuns .. " of " .. totalRuns)
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
