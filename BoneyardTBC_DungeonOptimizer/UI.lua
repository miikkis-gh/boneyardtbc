----------------------------------------------------------------------
-- BoneyardTBC DungeonOptimizer UI — Shared Helpers
-- Common constants, backdrops, and factory functions used by all tabs.
-- Tab-specific files: UI_Setup.lua, UI_Route.lua, UI_Tracker.lua, UI_Guild.lua
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Shared namespace for tab files to access helpers
----------------------------------------------------------------------

BoneyardTBC_DO.UI = {}
local UI = BoneyardTBC_DO.UI

----------------------------------------------------------------------
-- Ordered faction keys for consistent display order
----------------------------------------------------------------------

UI.FACTION_ORDER = {
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

UI.PANEL_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

----------------------------------------------------------------------
-- Helper: FormatNumber(n) — adds comma separators
-- e.g. 1234567 -> "1,234,567"
----------------------------------------------------------------------

function UI.FormatNumber(n)
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

function UI.GetStandingName(totalRep)
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

function UI.GetStandingNameOnly(totalRep)
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

function UI.CreateSectionHeader(parent, text, xOffset, yOffset)
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

function UI.CreateLabel(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetText(text or "")
    label:SetTextColor(0.9, 0.9, 0.9, 1)
    return label
end

----------------------------------------------------------------------
-- Helper: CreateValueText(parent, text, font)
-- Creates a value display text (not anchored)
----------------------------------------------------------------------

function UI.CreateValueText(parent, text, font)
    local val = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    val:SetText(text or "")
    val:SetTextColor(1, 1, 1, 1)
    return val
end
