----------------------------------------------------------------------
-- BoneyardTBC DungeonOptimizer UI — Guild Tab
-- Guild sync dashboard: LFG matches, leaderboard, planning view.
----------------------------------------------------------------------

local DO = BoneyardTBC_DO.module
local UI = BoneyardTBC_DO.UI

local CreateSectionHeader = UI.CreateSectionHeader
local CreateLabel         = UI.CreateLabel

----------------------------------------------------------------------
-- Guild-specific constants
----------------------------------------------------------------------

local GUILD_PANEL_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

----------------------------------------------------------------------
-- Tab 4: Guild — DO:CreateGuildTab(parent)
----------------------------------------------------------------------

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

            -- Progress (step X/total)
            local stepNum = data.currentStep or 0
            local lastResult = BoneyardTBC_DO.Optimizer and BoneyardTBC_DO.Optimizer.lastResult
            local totalSteps = lastResult and lastResult.route and #lastResult.route or 0
            local pctText = string.format("Step %d/%d", stepNum, totalSteps)
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
