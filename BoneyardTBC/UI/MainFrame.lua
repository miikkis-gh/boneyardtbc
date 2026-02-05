----------------------------------------------------------------------
-- BoneyardTBC MainFrame
-- Main window with dynamic tab system + minimap button
----------------------------------------------------------------------

BoneyardTBC.MainFrame = {}

local MainFrame = BoneyardTBC.MainFrame

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------

local FRAME_WIDTH = 700
local FRAME_HEIGHT = 500
local TITLE_HEIGHT = 30
local TAB_BAR_HEIGHT = 32
local TAB_BAR_Y_OFFSET = -(TITLE_HEIGHT + 4)
local CONTENT_TOP_OFFSET = -(TITLE_HEIGHT + TAB_BAR_HEIGHT + 8)

local MAIN_BACKDROP = {
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
}

----------------------------------------------------------------------
-- 1. Main Window Frame
----------------------------------------------------------------------

local frame = CreateFrame("Frame", "BoneyardTBCFrame", UIParent, "BackdropTemplate")
frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetBackdrop(MAIN_BACKDROP)
frame:SetBackdropColor(0.08, 0.08, 0.08, 0.92)
frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()

-- Allow Escape to close the window
tinsert(UISpecialFrames, "BoneyardTBCFrame")

-- Drag scripts
frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Save position
    local point, _, _, x, y = self:GetPoint()
    if BoneyardTBCDB and BoneyardTBCDB.core then
        BoneyardTBCDB.core.windowPosition = {
            point = point,
            x = x,
            y = y,
        }
    end
end)

-- Save position on hide
frame:SetScript("OnHide", function(self)
    local point, _, _, x, y = self:GetPoint()
    if BoneyardTBCDB and BoneyardTBCDB.core then
        BoneyardTBCDB.core.windowPosition = {
            point = point,
            x = x,
            y = y,
        }
    end
end)

-- Restore position on show
frame:SetScript("OnShow", function(self)
    if BoneyardTBCDB and BoneyardTBCDB.core and BoneyardTBCDB.core.windowPosition then
        local pos = BoneyardTBCDB.core.windowPosition
        self:ClearAllPoints()
        self:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    end
end)

----------------------------------------------------------------------
-- Title bar
----------------------------------------------------------------------

local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("TOP", frame, "TOP", 0, -12)
titleText:SetText("Boneyard TBC Special")
titleText:SetTextColor(1, 0.82, 0, 1)

----------------------------------------------------------------------
-- Close button
----------------------------------------------------------------------

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

----------------------------------------------------------------------
-- Tab system
----------------------------------------------------------------------

-- Storage for tabs
MainFrame.tabs = {}       -- { button = <tabBtn>, panel = <frame or nil>, create = <fn>, name = <string> }
MainFrame.selectedTab = 0
MainFrame.frame = frame

-- Tab bar container (anchors tab buttons)
local tabBar = CreateFrame("Frame", nil, frame)
tabBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, TAB_BAR_Y_OFFSET)
tabBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, TAB_BAR_Y_OFFSET)
tabBar:SetHeight(TAB_BAR_HEIGHT)
MainFrame.tabBar = tabBar

-- Content area container (tab panels go here)
local contentArea = CreateFrame("Frame", nil, frame)
contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, CONTENT_TOP_OFFSET)
contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
MainFrame.contentArea = contentArea

----------------------------------------------------------------------
-- AddModuleTabs(module)
--
-- Accepts a module table that has a GetTabPanels() method returning:
--   { { name = "Tab Name", create = function(parent) return frame end }, ... }
-- Creates tab buttons and wires them into the tab system.
----------------------------------------------------------------------

function MainFrame:AddModuleTabs(module)
    if not module or not module.GetTabPanels then
        return
    end

    local panels = module:GetTabPanels()
    if not panels then
        return
    end

    for _, panelDef in ipairs(panels) do
        local index = #self.tabs + 1

        -- Create the tab button using the Widgets factory
        local tabBtn = BoneyardTBC.Widgets.CreateTabButton(
            self.tabBar,
            panelDef.name,
            function()
                self:SelectTab(index)
            end
        )

        -- Position the tab button in the tab bar
        if index == 1 then
            tabBtn:SetPoint("BOTTOMLEFT", self.tabBar, "BOTTOMLEFT", 0, 0)
        else
            tabBtn:SetPoint("BOTTOMLEFT", self.tabs[index - 1].button, "BOTTOMRIGHT", 2, 0)
        end

        self.tabs[index] = {
            button = tabBtn,
            panel  = nil,      -- lazily created on first select
            create = panelDef.create,
            name   = panelDef.name,
        }
    end

    -- If no tab is selected yet, select the first one
    if self.selectedTab == 0 and #self.tabs > 0 then
        self:SelectTab(1)
    end
end

----------------------------------------------------------------------
-- SelectTab(index)
--
-- Shows the content for the tab at `index`, hides all others,
-- and updates tab button selection states.
----------------------------------------------------------------------

function MainFrame:SelectTab(index)
    if index < 1 or index > #self.tabs then
        return
    end

    -- Deselect all tabs, hide all panels
    for i, tabEntry in ipairs(self.tabs) do
        tabEntry.button:SetSelected(false)
        if tabEntry.panel then
            tabEntry.panel:Hide()
        end
    end

    local tabEntry = self.tabs[index]

    -- Lazy creation: build the panel on first select
    if not tabEntry.panel and tabEntry.create then
        local panel = tabEntry.create(self.contentArea)
        if panel then
            panel:SetAllPoints(self.contentArea)
            tabEntry.panel = panel
        end
    end

    -- Show the selected tab
    tabEntry.button:SetSelected(true)
    if tabEntry.panel then
        tabEntry.panel:Show()
    end

    self.selectedTab = index
end

----------------------------------------------------------------------
-- Toggle()
----------------------------------------------------------------------

function MainFrame:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
    end
end

----------------------------------------------------------------------
-- 2. Minimap Button
----------------------------------------------------------------------

local minimapBtn = CreateFrame("Button", "BoneyardTBCMinimapButton", Minimap)
minimapBtn:SetSize(32, 32)
minimapBtn:SetFrameStrata("MEDIUM")
minimapBtn:SetFrameLevel(8)
minimapBtn:SetMovable(true)
minimapBtn:EnableMouse(true)
minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapBtn:RegisterForDrag("LeftButton")

-- Icon texture
local minimapIcon = minimapBtn:CreateTexture(nil, "ARTWORK")
minimapIcon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
minimapIcon:SetSize(20, 20)
minimapIcon:SetPoint("CENTER", minimapBtn, "CENTER", 0, 0)

-- Round border overlay
local minimapBorder = minimapBtn:CreateTexture(nil, "OVERLAY")
minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapBorder:SetSize(54, 54)
minimapBorder:SetPoint("TOPLEFT", minimapBtn, "TOPLEFT", -2, 2)

-- Background (dark circle behind the icon)
local minimapBg = minimapBtn:CreateTexture(nil, "BACKGROUND")
minimapBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
minimapBg:SetSize(24, 24)
minimapBg:SetPoint("CENTER", minimapBtn, "CENTER", 0, 0)

-- Highlight texture
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Position the button on the minimap ring based on saved angle
local function UpdateMinimapButtonPosition(angle)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Apply initial position once saved variables are available
-- (deferred to ADDON_LOADED via OnShow or direct call)
local function RestoreMinimapPosition()
    local angle = 220 * (math.pi / 180) -- default in radians
    if BoneyardTBCDB and BoneyardTBCDB.core and BoneyardTBCDB.core.minimapButtonAngle then
        angle = BoneyardTBCDB.core.minimapButtonAngle * (math.pi / 180)
    end
    minimapBtn:ClearAllPoints()
    UpdateMinimapButtonPosition(angle)
end

-- Set initial position (may use defaults if DB not loaded yet)
RestoreMinimapPosition()

-- Re-apply position after ADDON_LOADED ensures saved variables are ready
local minimapInitFrame = CreateFrame("Frame")
minimapInitFrame:RegisterEvent("ADDON_LOADED")
minimapInitFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "BoneyardTBC" then
        RestoreMinimapPosition()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Left-click: toggle main window
minimapBtn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        BoneyardTBC.MainFrame:Toggle()
    end
end)

-- Tooltip
minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Boneyard TBC Special")
    GameTooltip:AddLine("Left-click to toggle window", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Drag to reposition", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Drag around the minimap ring
minimapBtn:SetScript("OnDragStart", function(self)
    self.isDragging = true
    self:SetScript("OnUpdate", function(self)
        local mx, my = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        mx = mx / scale
        my = my / scale

        local cx, cy = Minimap:GetCenter()
        local dx = mx - cx
        local dy = my - cy
        local angle = math.atan2(dy, dx)

        self:ClearAllPoints()
        UpdateMinimapButtonPosition(angle)

        -- Save angle in degrees
        if BoneyardTBCDB and BoneyardTBCDB.core then
            BoneyardTBCDB.core.minimapButtonAngle = angle * (180 / math.pi)
        end
    end)
end)

minimapBtn:SetScript("OnDragStop", function(self)
    self.isDragging = false
    self:SetScript("OnUpdate", nil)
end)
