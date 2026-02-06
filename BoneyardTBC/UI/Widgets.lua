----------------------------------------------------------------------
-- BoneyardTBC Widgets
-- Reusable UI widget factory functions
----------------------------------------------------------------------

BoneyardTBC.Widgets = {}

local Widgets = BoneyardTBC.Widgets

----------------------------------------------------------------------
-- Shared backdrop tables (reused across widgets)
----------------------------------------------------------------------

local BACKDROP_DARK = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

local BACKDROP_DROPDOWN_ITEM = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = nil,
    edgeSize = 0,
    insets   = { left = 0, right = 0, top = 0, bottom = 0 },
}

----------------------------------------------------------------------
-- 1. CreateProgressBar(parent, width, height, color)
--
-- Returns a frame with a dark backdrop background, a colored fill
-- texture, and a text overlay. Call :SetValue(pct) with 0-1 range.
----------------------------------------------------------------------

function Widgets.CreateProgressBar(parent, width, height, color)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetSize(width, height)
    bar:SetBackdrop(BACKDROP_DARK)
    bar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    bar:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Fill texture
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetTexture("Interface\\Buttons\\WHITE8x8")
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 1)
    fill:SetWidth(0.001) -- avoid zero-width issues
    fill:SetVertexColor(color.r or color[1] or 0, color.g or color[2] or 1, color.b or color[3] or 0, 1)
    bar.fill = fill

    -- Text overlay
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetTextColor(1, 1, 1, 1)
    text:SetText("")
    bar.text = text

    -- Internal state
    bar.currentValue = 0
    bar.barWidth = width

    function bar:SetValue(pct)
        if pct < 0 then pct = 0 end
        if pct > 1 then pct = 1 end
        self.currentValue = pct

        local innerWidth = self.barWidth - 2 -- account for 1px insets
        local fillWidth = math.max(innerWidth * pct, 0.001)
        self.fill:SetWidth(fillWidth)
        self.text:SetText(math.floor(pct * 100) .. "%")
    end

    function bar:SetBarColor(r, g, b)
        self.fill:SetVertexColor(r, g, b, 1)
    end

    function bar:SetBarText(str)
        self.text:SetText(str)
    end

    bar:SetValue(0)

    return bar
end

----------------------------------------------------------------------
-- 2. CreateCheckbox(parent, label, default, onChange)
--
-- CheckButton with a FontString label to the right. Fires
-- onChange(checked) on click. default is boolean for initial state.
----------------------------------------------------------------------

function Widgets.CreateCheckbox(parent, label, default, onChange)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(20, 20)

    -- Background texture (unchecked state)
    local bg = cb:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.15, 0.15, 0.15, 0.9)
    bg:SetAllPoints()
    cb.bg = bg

    -- Border
    local border = cb:CreateTexture(nil, "ARTWORK")
    border:SetTexture("Interface\\Buttons\\WHITE8x8")
    border:SetVertexColor(0.4, 0.4, 0.4, 1)
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    cb.border = border

    -- Bring bg above border so border acts as outline
    bg:SetDrawLayer("ARTWORK", 1)

    -- Check mark texture
    local check = cb:CreateTexture(nil, "OVERLAY")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetPoint("CENTER", 0, 0)
    check:SetSize(24, 24)
    cb:SetCheckedTexture(check)

    -- Highlight
    local highlight = cb:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
    highlight:SetVertexColor(1, 1, 1, 0.1)
    highlight:SetAllPoints()
    cb:SetHighlightTexture(highlight)

    -- Label text
    local labelText = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    labelText:SetText(label or "")
    labelText:SetTextColor(0.9, 0.9, 0.9, 1)
    cb.label = labelText

    -- Set initial state
    cb:SetChecked(default and true or false)

    -- OnClick handler
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        if onChange then
            onChange(checked)
        end
    end)

    return cb
end

----------------------------------------------------------------------
-- 3. CreateDropdown(parent, items, default, onSelect)
--
-- Button showing the selected value. On click, opens a frame-based
-- dropdown menu with selectable items. items is a list of strings.
-- default is the initially selected string.
----------------------------------------------------------------------

-- Track the currently open dropdown menu globally so we can close it
-- when another opens or when the user clicks elsewhere.
local activeDropdownMenu = nil

local DROPDOWN_WIDTH  = 150
local DROPDOWN_HEIGHT = 24
local DROPDOWN_ITEM_HEIGHT = 20

-- Create or reuse a single item button inside a dropdown menu
local function CreateOrReuseItemButton(menu, index)
    local existing = menu.buttons[index]
    if existing then return existing end

    local itemBtn = CreateFrame("Button", nil, menu, "BackdropTemplate")
    itemBtn:SetSize(DROPDOWN_WIDTH - 2, DROPDOWN_ITEM_HEIGHT)
    itemBtn:SetBackdrop(BACKDROP_DROPDOWN_ITEM)

    local itemText = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemText:SetPoint("LEFT", itemBtn, "LEFT", 8, 0)
    itemText:SetPoint("RIGHT", itemBtn, "RIGHT", -8, 0)
    itemText:SetJustifyH("LEFT")
    itemBtn.itemText = itemText

    itemBtn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    itemBtn:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)

    menu.buttons[index] = itemBtn
    return itemBtn
end

function Widgets.CreateDropdown(parent, items, default, onSelect)
    -- Main button
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(DROPDOWN_WIDTH, DROPDOWN_HEIGHT)
    btn:SetBackdrop(BACKDROP_DARK)
    btn:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Selected text
    local selectedText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    selectedText:SetPoint("LEFT", btn, "LEFT", 8, 0)
    selectedText:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
    selectedText:SetJustifyH("LEFT")
    selectedText:SetTextColor(1, 1, 1, 1)
    selectedText:SetText(default or (items and items[1]) or "")
    btn.selectedText = selectedText

    -- Arrow indicator
    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0.7, 0.7, 0.7, 1)

    -- Highlight
    btn:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    local hl = btn:GetHighlightTexture()
    hl:SetVertexColor(1, 1, 1, 0.08)

    -- Internal state
    btn.selectedValue = default or (items and items[1]) or ""
    btn.items = items or {}

    -- Dropdown menu frame (created lazily, reused)
    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menu:SetBackdrop(BACKDROP_DARK)
    menu:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
    menu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:Hide()
    btn.menu = menu

    -- Build menu items (reuses existing button frames to avoid frame leaks)
    menu.buttons = {}

    local function BuildMenuItems()
        local itemCount = #btn.items
        local menuHeight = (itemCount * DROPDOWN_ITEM_HEIGHT) + 4 -- 2px padding top/bottom
        menu:SetSize(DROPDOWN_WIDTH, menuHeight)
        menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)

        -- Hide any excess buttons from previous builds
        for i = itemCount + 1, #menu.buttons do
            menu.buttons[i]:Hide()
        end

        for i, itemLabel in ipairs(btn.items) do
            local itemBtn = CreateOrReuseItemButton(menu, i)

            itemBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -((i - 1) * DROPDOWN_ITEM_HEIGHT) - 2)
            itemBtn:SetBackdropColor(0, 0, 0, 0)
            itemBtn.itemText:SetText(itemLabel)

            -- Highlight the currently selected item
            if itemLabel == btn.selectedValue then
                itemBtn.itemText:SetTextColor(0.3, 0.8, 1, 1)
            else
                itemBtn.itemText:SetTextColor(0.9, 0.9, 0.9, 1)
            end

            itemBtn:SetScript("OnClick", function()
                btn.selectedValue = itemLabel
                selectedText:SetText(itemLabel)
                menu:Hide()
                activeDropdownMenu = nil
                if onSelect then
                    onSelect(itemLabel)
                end
            end)

            itemBtn:Show()
        end
    end

    BuildMenuItems()

    -- Toggle menu on click
    btn:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
            activeDropdownMenu = nil
        else
            -- Close any other open dropdown
            if activeDropdownMenu and activeDropdownMenu ~= menu then
                activeDropdownMenu:Hide()
            end
            -- Rebuild to reflect current selection highlight
            BuildMenuItems()
            menu:Show()
            activeDropdownMenu = menu
        end
    end)

    -- Close menu when clicking outside
    menu:SetScript("OnShow", function()
        menu:SetScript("OnUpdate", function()
            if not MouseIsOver(menu) and not MouseIsOver(btn) and IsMouseButtonDown("LeftButton") then
                menu:Hide()
                activeDropdownMenu = nil
            end
        end)
    end)

    menu:SetScript("OnHide", function()
        menu:SetScript("OnUpdate", nil)
    end)

    -- Public API
    function btn:SetSelectedValue(value)
        self.selectedValue = value
        self.selectedText:SetText(value)
    end

    function btn:GetSelectedValue()
        return self.selectedValue
    end

    function btn:SetItems(newItems)
        self.items = newItems
        BuildMenuItems()
    end

    return btn
end

----------------------------------------------------------------------
-- 4. CreateTabButton(parent, label, onClick)
--
-- Button styled as a tab with selected/unselected visual states.
-- Has :SetSelected(bool) to toggle appearance.
----------------------------------------------------------------------

local TAB_WIDTH  = 100
local TAB_HEIGHT = 28

function Widgets.CreateTabButton(parent, label, onClick)
    local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
    tab:SetSize(TAB_WIDTH, TAB_HEIGHT)
    tab:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 0 },
    })

    -- Label
    local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", tab, "CENTER", 0, 0)
    text:SetText(label or "")
    tab.label = text

    -- Highlight
    tab:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    local hl = tab:GetHighlightTexture()
    hl:SetVertexColor(1, 1, 1, 0.05)

    -- State
    tab.isSelected = false

    function tab:SetSelected(selected)
        self.isSelected = selected
        if selected then
            self:SetBackdropColor(0.15, 0.15, 0.15, 1)
            self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            self.label:SetTextColor(1, 1, 1, 1)
        else
            self:SetBackdropColor(0.08, 0.08, 0.08, 0.7)
            self:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.7)
            self.label:SetTextColor(0.5, 0.5, 0.5, 1)
        end
    end

    tab:SetScript("OnClick", function(self)
        if onClick then
            onClick(self)
        end
    end)

    -- Start unselected
    tab:SetSelected(false)

    return tab
end

----------------------------------------------------------------------
-- 5. CreateIconButton(parent, icon, size, onClick)
--
-- Small clickable button with a texture icon. icon is a texture path
-- string, size is pixel dimension (square).
----------------------------------------------------------------------

function Widgets.CreateIconButton(parent, icon, size, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)

    -- Icon texture
    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(icon)
    tex:SetAllPoints()
    btn.icon = tex

    -- Highlight overlay
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
    highlight:SetVertexColor(1, 1, 1, 0.15)
    highlight:SetAllPoints()
    btn:SetHighlightTexture(highlight)

    -- Pushed state: slight scale-down effect via inset
    local pushed = btn:CreateTexture(nil, "ARTWORK")
    pushed:SetTexture(icon)
    pushed:SetPoint("TOPLEFT", 1, -1)
    pushed:SetPoint("BOTTOMRIGHT", -1, 1)
    btn:SetPushedTexture(pushed)

    btn:SetScript("OnClick", function(self)
        if onClick then
            onClick(self)
        end
    end)

    -- Public API to change icon
    function btn:SetIcon(newIcon)
        self.icon:SetTexture(newIcon)
        self:GetPushedTexture():SetTexture(newIcon)
    end

    return btn
end
