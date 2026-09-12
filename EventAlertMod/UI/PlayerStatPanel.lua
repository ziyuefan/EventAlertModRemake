--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/PlayerStatPanel
檔案: UI\PlayerStatPanel.lua

理念:
- 角色屬性與吸收量監控之獨立二級設定面板。
- 支援 18 種核心屬性每單項開關、替代圖示、字型大小、替代名稱、小數位數與數值高亮閾值自訂。
- 採用 4-Tab Frame 模組化介面，徹底消除控制項與文字標籤重疊。

責任:
- 管理屬性清單與細部設定表單之建立與狀態更新。
- 支援即時熱預覽與 SavedVariables 雙向保存。
]]
local _, EAM = ...

EAM.UI = EAM.UI or {}

local api = EAM.API or {}
local Theme = EAM.Theme
local Util = EAM.Util or {}
local PlayerStatService = EAM.Services and EAM.Services.PlayerStatService

local Panel = {
    frame = nil,
    selectedKey = "crit",
    rows = {},
    controls = {},
    currentTab = 1,
}
EAM.UI.PlayerStatPanel = Panel

local function inCombat()
    return api.InCombatLockdown and api.InCombatLockdown()
end

local function localized(key, fallback)
    return (EAM.L and EAM.L[key]) or fallback
end

local function getStatConfig(statKey)
    local statsTable = nil
    if PlayerStatService and PlayerStatService.getPlayerStatsConfig then
        statsTable = PlayerStatService.getPlayerStatsConfig()
    elseif EAM.Services and EAM.Services.PlayerStatService and EAM.Services.PlayerStatService.getPlayerStatsConfig then
        statsTable = EAM.Services.PlayerStatService.getPlayerStatsConfig()
    end
    if not statsTable then
        local db = EAM.db
        if not db then return {} end
        db.playerStats = db.playerStats or {}
        statsTable = db.playerStats
    end
    if not statsTable[statKey] then
        statsTable[statKey] = {
            enabled = false,
            showIcon = true,
            showStatusBar = false,
            customIcon = "",
            iconSize = 36,
            fontSizeValue = 14,
            fontSizeLabel = 11,
            customLabel = "",
            decimals = 1,
            shortNumber = true,
            useCustomPos = false,
            point = "CENTER",
            offsetX = 0,
            offsetY = 0,
        }
    end
    return statsTable[statKey]
end

local function createFrame()
    if Panel.frame then return Panel.frame end

    local parent = _G.UIParent
    if not parent then return nil end

    local frame = api.CreateFrame("Frame", "EAM_PlayerStatOptionsFrame", parent, "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(720, 540)
    local mainFrame = _G.EAM_MainOptionsFrame
    if mainFrame and mainFrame:IsShown() then
        frame:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 2, 0)
    else
        frame:SetPoint("CENTER", parent, "CENTER", 0, 10)
    end
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    frame:SetBackdropBorderColor(0.78, 0.61, 0.35, 1)
    if Theme and Theme.registerFrame then Theme.registerFrame(frame, "window") end

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        local main = _G.EAM_MainOptionsFrame
        if main and main:IsShown() then
            main:StartMoving()
        else
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        local main = _G.EAM_MainOptionsFrame
        if main and main:IsShown() then
            main:StopMovingOrSizing()
        else
            frame:StopMovingOrSizing()
        end
    end)

    -- 標題列
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
    title:SetText(localized("EAM_STAT_PANEL_TITLE", "★ 角色屬性與吸收量監控"))
    title:SetTextColor(1.0, 0.82, 0.0, 1)
    if Theme and Theme.registerText then Theme.registerText(title, "title") end
    Panel.title = title

    -- 效果預覽按鈕
    local previewBtn = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    previewBtn:SetSize(88, 22)
    previewBtn:SetPoint("LEFT", title, "RIGHT", 14, 0)
    previewBtn:SetText(localized("EAM_PREVIEW_BTN", "效果預覽"))
    if Theme and Theme.registerButton then Theme.registerButton(previewBtn) end
    if EAM.UI.setTooltip then EAM.UI.setTooltip(previewBtn, "開啟或關閉獨立的即時效果預覽小視窗", "效果預覽") end
    previewBtn:SetScript("OnClick", function()
        if EAM.UI.PreviewPanel and EAM.UI.PreviewPanel.toggle then
            EAM.UI.PreviewPanel.toggle()
        end
    end)

    -- 整體圖示排列方向下拉選單
    local growDirLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    growDirLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -150, -17)
    growDirLabel:SetText(localized("EAM_STAT_GROW_DIR", "整體排列方向:"))

    local growDirOptions = {
        { value = 1, labelKey = "EAM_STAT_DIR_RIGHT", fallback = "向右 (Right)" },
        { value = 2, labelKey = "EAM_STAT_DIR_LEFT", fallback = "向左 (Left)" },
        { value = 3, labelKey = "EAM_STAT_DIR_UP", fallback = "向上 (Up)" },
        { value = 4, labelKey = "EAM_STAT_DIR_DOWN", fallback = "向下 (Down)" },
    }

    local growDirDropdown = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(growDirDropdown) end
    growDirDropdown:SetSize(105, 20)
    growDirDropdown:SetPoint("LEFT", growDirLabel, "RIGHT", 6, 0)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(growDirDropdown, "調整群組屬性圖示在畫面上的排列擴展方向", "整體排列方向") end

    local growDirMenu = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    growDirMenu:SetSize(105, (#growDirOptions * 22) + 8)
    growDirMenu:SetPoint("TOPLEFT", growDirDropdown, "BOTTOMLEFT", 0, -2)
    growDirMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    growDirMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    growDirMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
    growDirMenu:SetBackdropBorderColor(0.6, 0.4, 0.2, 1)
    if Theme and Theme.registerFrame then Theme.registerFrame(growDirMenu, "menu") end
    growDirMenu:Hide()

    local function refreshGrowDirDropdown(val)
        local db = EAM.db
        local currentDir = val or (db and db.layout and db.layout.frames and db.layout.frames.playerStat and db.layout.frames.playerStat.growDirection) or 1
        local text = "向右 (Right)"
        for _, opt in ipairs(growDirOptions) do
            if opt.value == currentDir then
                text = (EAM.L and EAM.L[opt.labelKey]) or opt.fallback
                break
            end
        end
        growDirDropdown:SetText(text)
    end

    for index = 1, #growDirOptions do
        local option = growDirOptions[index]
        local menuBtn = api.CreateFrame("Button", nil, growDirMenu)
        menuBtn:SetSize(99, 20)
        menuBtn:SetPoint("TOPLEFT", growDirMenu, "TOPLEFT", 3, -3 - (index - 1) * 22)
        local btnText = menuBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnText:SetPoint("LEFT", menuBtn, "LEFT", 6, 0)
        btnText:SetText((EAM.L and EAM.L[option.labelKey]) or option.fallback)
        if Theme and Theme.registerButton then Theme.registerButton(menuBtn) end
        menuBtn:SetScript("OnClick", function()
            local db = EAM.db
            if db and db.layout and db.layout.frames and db.layout.frames.playerStat then
                db.layout.frames.playerStat.growDirection = option.value
            end
            refreshGrowDirDropdown(option.value)
            growDirMenu:Hide()
            if PlayerStatService and PlayerStatService.update then
                PlayerStatService.update()
            end
        end)
    end

    growDirDropdown:SetScript("OnClick", function()
        if growDirMenu:IsShown() then
            growDirMenu:Hide()
        else
            growDirMenu:Show()
        end
    end)
    refreshGrowDirDropdown()

    -- 右上關閉按鈕 [X]
    local closeBtn = api.CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() Panel.hide() end)

    -- ===================================================
    -- 【左側】：屬性列表 (寬度 235px, 高度 475px)
    -- ===================================================
    local listContainer = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listContainer:SetSize(235, 475)
    listContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -48)
    listContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    listContainer:SetBackdropColor(0.04, 0.04, 0.05, 0.85)
    listContainer:SetBackdropBorderColor(0.45, 0.35, 0.25, 0.85)
    if Theme and Theme.registerFrame then Theme.registerFrame(listContainer, "panel") end

    local scrollFrame = api.CreateFrame("ScrollFrame", "EAM_PlayerStatScrollFrame", listContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -24, 34)

    local scrollChild = api.CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(205, 620)
    scrollFrame:SetScrollChild(scrollChild)

    -- 左側底部批次控制按鈕 [全選監控] / [全部停用]
    local enableAllBtn = api.CreateFrame("Button", nil, listContainer, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(enableAllBtn) end
    enableAllBtn:SetSize(100, 22)
    enableAllBtn:SetPoint("BOTTOMLEFT", listContainer, "BOTTOMLEFT", 6, 6)
    enableAllBtn:SetText(localized("EAM_STAT_ENABLE_ALL", "全選監控"))
    if EAM.UI.setTooltip then EAM.UI.setTooltip(enableAllBtn, "一次性啟用清單中所有 18 項角色屬性與吸收量監控", "全選監控") end
    enableAllBtn:SetScript("OnClick", function()
        local keys = PlayerStatService and PlayerStatService.ORDERED_KEYS or {}
        for _, k in ipairs(keys) do
            local cfg = getStatConfig(k)
            cfg.enabled = true
        end
        if PlayerStatService and PlayerStatService.update then
            PlayerStatService.update()
        end
        Panel.refreshList()
    end)

    local disableAllBtn = api.CreateFrame("Button", nil, listContainer, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(disableAllBtn) end
    disableAllBtn:SetSize(100, 22)
    disableAllBtn:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -6, 6)
    disableAllBtn:SetText(localized("EAM_STAT_DISABLE_ALL", "全部停用"))
    if EAM.UI.setTooltip then EAM.UI.setTooltip(disableAllBtn, "一次性停用清單中所有角色屬性與吸收量監控", "全部停用") end
    disableAllBtn:SetScript("OnClick", function()
        local keys = PlayerStatService and PlayerStatService.ORDERED_KEYS or {}
        for _, k in ipairs(keys) do
            local cfg = getStatConfig(k)
            cfg.enabled = false
        end
        if PlayerStatService and PlayerStatService.update then
            PlayerStatService.update()
        end
        Panel.refreshList()
    end)

    -- ===================================================
    -- 【右側】：細部設定表單 (寬度 445px, 高度 475px)
    -- ===================================================
    local detailContainer = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    detailContainer:SetSize(445, 475)
    detailContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -48)
    detailContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    detailContainer:SetBackdropColor(0.04, 0.04, 0.05, 0.85)
    detailContainer:SetBackdropBorderColor(0.45, 0.35, 0.25, 0.85)
    if Theme and Theme.registerFrame then Theme.registerFrame(detailContainer, "panel") end

    -- 大圖示與名稱展示
    local detailIcon = detailContainer:CreateTexture(nil, "ARTWORK")
    detailIcon:SetSize(36, 36)
    detailIcon:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 16, -10)
    detailIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local detailTitle = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    detailTitle:SetPoint("LEFT", detailIcon, "RIGHT", 10, 8)
    detailTitle:SetTextColor(1.0, 0.88, 0.2, 1)

    local detailValPreview = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detailValPreview:SetPoint("LEFT", detailIcon, "RIGHT", 10, -10)
    detailValPreview:SetTextColor(0.4, 0.9, 1.0, 1)

    -- 4-Tab 按鈕容器
    local tabContainer = api.CreateFrame("Frame", nil, detailContainer)
    tabContainer:SetSize(416, 24)
    tabContainer:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 14, -54)

    local tabButtons = {}
    local tabPages = {}
    local tabDefs = {
        { id = 1, key = "EAM_STAT_TAB_DISPLAY", fallback = "顯示與圖示" },
        { id = 2, key = "EAM_STAT_TAB_FONTS", fallback = "字型與格式" },
        { id = 3, key = "EAM_STAT_TAB_THRESHOLDS", fallback = "警戒門檻" },
        { id = 4, key = "EAM_STAT_TAB_POSITION", fallback = "位置與錨點" },
    }

    local function selectTab(tabIdx)
        Panel.currentTab = tabIdx
        for idx, page in ipairs(tabPages) do
            if idx == tabIdx then
                page:Show()
                if tabButtons[idx] then tabButtons[idx]:LockHighlight() end
            else
                page:Hide()
                if tabButtons[idx] then tabButtons[idx]:UnlockHighlight() end
            end
        end
    end

    for idx, tDef in ipairs(tabDefs) do
        local btn = api.CreateFrame("Button", nil, tabContainer, "UIPanelButtonTemplate")
        btn:SetSize(100, 22)
        btn:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", (idx - 1) * 104, 0)
        btn:SetText(localized(tDef.key, tDef.fallback))
        if Theme and Theme.registerButton then Theme.registerButton(btn) end
        btn:SetScript("OnClick", function() selectTab(idx) end)
        tabButtons[idx] = btn

        local page = api.CreateFrame("Frame", nil, detailContainer)
        page:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 14, -84)
        page:SetPoint("BOTTOMRIGHT", detailContainer, "BOTTOMRIGHT", -14, 46)
        page:Hide()
        tabPages[idx] = page
    end

    -- =========================================================================
    -- 【Tab 1: 顯示與圖示 (Display & Icon)】
    -- =========================================================================
    local pageDisplay = tabPages[1]

    local enableCb = api.CreateFrame("CheckButton", nil, pageDisplay, "UICheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", pageDisplay, "TOPLEFT", 8, -10)
    enableCb.text = enableCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    enableCb.text:SetPoint("LEFT", enableCb, "RIGHT", 4, 1)
    enableCb.text:SetText(localized("EAM_STAT_ENABLE", "啟用監控"))
    if EAM.UI.setTooltip then EAM.UI.setTooltip(enableCb, "啟用/停用此項屬性在畫面上的即時數值顯示", "啟用監控") end

    local showIconCb = api.CreateFrame("CheckButton", nil, pageDisplay, "UICheckButtonTemplate")
    showIconCb:SetPoint("TOPLEFT", pageDisplay, "TOPLEFT", 110, -10)
    showIconCb.text = showIconCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    showIconCb.text:SetPoint("LEFT", showIconCb, "RIGHT", 4, 1)
    showIconCb.text:SetText(localized("EAM_STAT_SHOW_ICON", "顯示圖示"))
    if EAM.UI.setTooltip then EAM.UI.setTooltip(showIconCb, "是否在此屬性旁邊顯示技能/屬性圖示", "顯示圖示") end

    local showStatusBarCb = api.CreateFrame("CheckButton", nil, pageDisplay, "UICheckButtonTemplate")
    showStatusBarCb:SetPoint("TOPLEFT", pageDisplay, "TOPLEFT", 215, -10)
    showStatusBarCb.text = showStatusBarCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    showStatusBarCb.text:SetPoint("LEFT", showStatusBarCb, "RIGHT", 4, 1)
    showStatusBarCb.text:SetText(localized("EAM_STAT_SHOW_STATUSBAR", "顯示進度條"))
    if EAM.UI.setTooltip then EAM.UI.setTooltip(showStatusBarCb, "是否在此屬性下方顯示進度條/狀態條", "顯示進度條") end

    local glideOnlyIconCb = api.CreateFrame("CheckButton", nil, pageDisplay, "UICheckButtonTemplate")
    glideOnlyIconCb:SetPoint("TOPLEFT", pageDisplay, "TOPLEFT", 320, -10)
    glideOnlyIconCb.text = glideOnlyIconCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    glideOnlyIconCb.text:SetPoint("LEFT", glideOnlyIconCb, "RIGHT", 4, 1)
    glideOnlyIconCb.text:SetText(localized("EAM_STAT_GLIDE_ONLY_ICON", "僅滑翔顯示"))
    if EAM.UI.setTooltip then EAM.UI.setTooltip(glideOnlyIconCb, localized("EAM_STAT_GLIDE_ONLY_ICON_TIP", "僅在御空術/飛龍滑翔狀態 (isGliding == true) 時才在畫面上顯示此圖示監控，未滑翔時自動隱藏"), "僅滑翔顯示") end
    glideOnlyIconCb:Hide()

    -- 無圖示時數值位置下拉選單
    local valuePlacementLabel = pageDisplay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valuePlacementLabel:SetPoint("TOPLEFT", pageDisplay, "TOPLEFT", 12, -48)
    valuePlacementLabel:SetText(localized("EAM_STAT_VALUE_PLACEMENT", "無圖示時數值位置:"))

    local valuePlacementOptions = {
        { value = "TOP", labelKey = "EAM_STAT_VAL_TOP", fallback = "上方 (Top)" },
        { value = "BOTTOM", labelKey = "EAM_STAT_VAL_BOTTOM", fallback = "下方 (Bottom)" },
        { value = "LEFT", labelKey = "EAM_STAT_VAL_LEFT", fallback = "左側 (Left)" },
        { value = "RIGHT", labelKey = "EAM_STAT_VAL_RIGHT", fallback = "右側 (Right)" },
    }

    local valuePlacementDropdown = api.CreateFrame("Button", nil, pageDisplay, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(valuePlacementDropdown) end
    valuePlacementDropdown:SetSize(140, 20)
    valuePlacementDropdown:SetPoint("LEFT", valuePlacementLabel, "RIGHT", 8, 0)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(valuePlacementDropdown, "設定停用圖示時，數值文字相對於屬性名稱標籤的排列方向", "數值相對位置") end

    local valuePlacementMenu = api.CreateFrame("Frame", nil, pageDisplay, "BackdropTemplate")
    valuePlacementMenu:SetSize(140, (#valuePlacementOptions * 22) + 8)
    valuePlacementMenu:SetPoint("TOPLEFT", valuePlacementDropdown, "BOTTOMLEFT", 0, -2)
    valuePlacementMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    valuePlacementMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    valuePlacementMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
    valuePlacementMenu:SetBackdropBorderColor(0.6, 0.4, 0.2, 1)
    valuePlacementMenu:Hide()

    local function refreshValuePlacementDropdown(val)
        val = val or (getStatConfig(Panel.selectedKey).valuePlacement or "TOP")
        local text = val
        for _, opt in ipairs(valuePlacementOptions) do
            if opt.value == val then
                text = (EAM.L and EAM.L[opt.labelKey]) or opt.fallback
                break
            end
        end
        valuePlacementDropdown:SetText(text)
    end

    -- 圖示大小滑桿 (縱深留白拉開防重疊)
    local sizeSlider = api.CreateFrame("Slider", nil, pageDisplay, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", pageDisplay, "TOPLEFT", 12, -95)
    sizeSlider:SetMinMaxValues(16, 80)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetSize(260, 14)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(sizeSlider, "調整此屬性圖示的像素大小 (16~80px)", "圖示大小") end
    local sizeLabel = sizeSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLabel:SetPoint("BOTTOMLEFT", sizeSlider, "TOPLEFT", 0, 4)
    sizeLabel:SetText(localized("EAM_STAT_ICON_SIZE", "圖示大小 (Icon Size)"))
    local sizeVal = sizeSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sizeVal:SetPoint("BOTTOMRIGHT", sizeSlider, "TOPRIGHT", 0, 4)

    -- 自訂替代圖示
    local iconLabel = pageDisplay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconLabel:SetPoint("TOPLEFT", pageDisplay, "TOPLEFT", 12, -150)
    iconLabel:SetText(localized("EAM_OPT_CUSTOM_ICON_LABEL", "自訂替代圖示 (代碼或材質路徑):"))

    local iconEditBox = api.CreateFrame("EditBox", nil, pageDisplay, "InputBoxTemplate")
    iconEditBox:SetSize(280, 20)
    iconEditBox:SetPoint("TOPLEFT", pageDisplay, "TOPLEFT", 16, -170)
    iconEditBox:SetAutoFocus(false)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(iconEditBox, "輸入替代圖示的 FileDataID 數字代碼或材質路徑（留空使用預設圖示）", "自訂替代圖示") end

    local iconPreviewBox = pageDisplay:CreateTexture(nil, "OVERLAY")
    iconPreviewBox:SetSize(24, 24)
    iconPreviewBox:SetPoint("LEFT", iconEditBox, "RIGHT", 10, 0)
    iconPreviewBox:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local urlHint = pageDisplay:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    urlHint:SetPoint("TOPLEFT", pageDisplay, "TOPLEFT", 12, -205)
    urlHint:SetText("可在 WoW.tools / Wago Tools 查詢圖示代碼與路徑:")

    local urlBox = api.CreateFrame("EditBox", nil, pageDisplay, "InputBoxTemplate")
    urlBox:SetSize(380, 20)
    urlBox:SetPoint("TOPLEFT", pageDisplay, "TOPLEFT", 16, -225)
    urlBox:SetAutoFocus(false)
    urlBox:SetText("https://wago.tools/icons")
    if EAM.UI.setTooltip then EAM.UI.setTooltip(urlBox, "點擊反白複製網址前往 Wago Tools 查詢圖示代碼", "圖示查詢網站") end
    urlBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    -- =========================================================================
    -- 【Tab 2: 字型與格式 (Fonts & Format)】
    -- =========================================================================
    local pageFonts = tabPages[2]

    local fontValSlider = api.CreateFrame("Slider", nil, pageFonts, "OptionsSliderTemplate")
    fontValSlider:SetPoint("TOPLEFT", pageFonts, "TOPLEFT", 12, -25)
    fontValSlider:SetMinMaxValues(8, 32)
    fontValSlider:SetValueStep(1)
    fontValSlider:SetObeyStepOnDrag(true)
    fontValSlider:SetSize(280, 14)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(fontValSlider, "調整屬性數值數字的文字大小 (8~32px)", "數值字型大小") end
    local fontValLabel = fontValSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontValLabel:SetPoint("BOTTOMLEFT", fontValSlider, "TOPLEFT", 0, 4)
    fontValLabel:SetText(localized("EAM_STAT_FONT_VALUE", "數值字型大小 (Value Font Size)"))
    local fontValVal = fontValSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontValVal:SetPoint("BOTTOMRIGHT", fontValSlider, "TOPRIGHT", 0, 4)

    local fontLabelSlider = api.CreateFrame("Slider", nil, pageFonts, "OptionsSliderTemplate")
    fontLabelSlider:SetPoint("TOPLEFT", pageFonts, "TOPLEFT", 12, -85)
    fontLabelSlider:SetMinMaxValues(8, 24)
    fontLabelSlider:SetValueStep(1)
    fontLabelSlider:SetObeyStepOnDrag(true)
    fontLabelSlider:SetSize(280, 14)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(fontLabelSlider, "調整屬性名稱標籤的文字大小 (8~24px)", "名稱字型大小") end
    local fontLabelLabel = fontLabelSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontLabelLabel:SetPoint("BOTTOMLEFT", fontLabelSlider, "TOPLEFT", 0, 4)
    fontLabelLabel:SetText(localized("EAM_STAT_FONT_LABEL", "名稱字型大小 (Label Font Size)"))
    local fontLabelVal = fontLabelSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontLabelVal:SetPoint("BOTTOMRIGHT", fontLabelSlider, "TOPRIGHT", 0, 4)

    local customLabelLabel = pageFonts:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    customLabelLabel:SetPoint("TOPLEFT", pageFonts, "TOPLEFT", 12, -145)
    customLabelLabel:SetText(localized("EAM_STAT_CUSTOM_LABEL", "名稱替代文字 (自訂簡稱):"))

    local customLabelEditBox = api.CreateFrame("EditBox", nil, pageFonts, "InputBoxTemplate")
    customLabelEditBox:SetSize(280, 20)
    customLabelEditBox:SetPoint("TOPLEFT", pageFonts, "TOPLEFT", 16, -165)
    customLabelEditBox:SetAutoFocus(false)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(customLabelEditBox, "自訂顯示在畫面上的屬性簡稱（留空使用預設名稱）", "名稱替代文字") end

    local decimalsLabel = pageFonts:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    decimalsLabel:SetPoint("TOPLEFT", pageFonts, "TOPLEFT", 12, -205)
    decimalsLabel:SetText(localized("EAM_STAT_DECIMALS", "小數位數 (0~2 位):"))

    local decimalsEditBox = api.CreateFrame("EditBox", nil, pageFonts, "InputBoxTemplate")
    decimalsEditBox:SetSize(60, 20)
    decimalsEditBox:SetPoint("LEFT", decimalsLabel, "RIGHT", 8, 0)
    decimalsEditBox:SetAutoFocus(false)
    decimalsEditBox:SetNumeric(true)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(decimalsEditBox, "數值顯示的小數位數（0 ~ 2 位）", "小數位數") end

    local shortNumberCb = api.CreateFrame("CheckButton", nil, pageFonts, "UICheckButtonTemplate")
    shortNumberCb:SetPoint("TOPLEFT", pageFonts, "TOPLEFT", 8, -240)
    shortNumberCb.text = shortNumberCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    shortNumberCb.text:SetPoint("LEFT", shortNumberCb, "RIGHT", 4, 1)
    shortNumberCb.text:SetText(localized("EAM_STAT_SHORT_NUMBER", "大數值簡寫 (k/M 單位簡化)"))
    if EAM.UI.setTooltip then EAM.UI.setTooltip(shortNumberCb, "數值過大時自動以 k / M 單位簡化顯示（例如 150.2k）", "大數值簡寫") end

    -- =========================================================================
    -- 【Tab 3: 警戒門檻 (Thresholds & Alerts)】
    -- =========================================================================
    local pageThresh = tabPages[3]

    local threshDesc = pageThresh:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    threshDesc:SetPoint("TOPLEFT", pageThresh, "TOPLEFT", 12, -15)
    threshDesc:SetWidth(380)
    threshDesc:SetJustifyH("LEFT")
    threshDesc:SetText(localized("EAM_STAT_THRESH_DESC", "當屬性數值超出以下門檻時，圖示外框將呈現深紅高亮閃爍警戒："))

    local minThreshLabel = pageThresh:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minThreshLabel:SetPoint("TOPLEFT", pageThresh, "TOPLEFT", 12, -55)
    minThreshLabel:SetText(localized("EAM_STAT_MIN_THRESH", "低於此數值紅框警戒 (Min Threshold):"))

    local minThreshEditBox = api.CreateFrame("EditBox", nil, pageThresh, "InputBoxTemplate")
    minThreshEditBox:SetSize(200, 20)
    minThreshEditBox:SetPoint("TOPLEFT", pageThresh, "TOPLEFT", 16, -75)
    minThreshEditBox:SetAutoFocus(false)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(minThreshEditBox, "當屬性數值低於此閾值時，邊框變紅高亮警戒（留空不啟用）", "低於警戒值") end

    local maxThreshLabel = pageThresh:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    maxThreshLabel:SetPoint("TOPLEFT", pageThresh, "TOPLEFT", 12, -120)
    maxThreshLabel:SetText(localized("EAM_STAT_MAX_THRESH", "高於此數值紅框警戒 (Max Threshold):"))

    local maxThreshEditBox = api.CreateFrame("EditBox", nil, pageThresh, "InputBoxTemplate")
    maxThreshEditBox:SetSize(200, 20)
    maxThreshEditBox:SetPoint("TOPLEFT", pageThresh, "TOPLEFT", 16, -140)
    maxThreshEditBox:SetAutoFocus(false)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(maxThreshEditBox, "當屬性數值高於此閾值時，邊框變紅高亮警戒（留空不啟用）", "高於警戒值") end

    local threshHint = pageThresh:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    threshHint:SetPoint("TOPLEFT", pageThresh, "TOPLEFT", 12, -185)
    threshHint:SetWidth(380)
    threshHint:SetJustifyH("LEFT")
    threshHint:SetText("提示：留空或填 0 表示不啟用該項警戒。支援整數或小數格式（例如 25 或 35.5）。")

    -- =========================================================================
    -- 【Tab 4: 位置與錨點 (Position & Anchors)】
    -- =========================================================================
    local pagePos = tabPages[4]

    local useCustomPosCb = api.CreateFrame("CheckButton", nil, pagePos, "UICheckButtonTemplate")
    useCustomPosCb:SetPoint("TOPLEFT", pagePos, "TOPLEFT", 8, -12)
    useCustomPosCb.text = useCustomPosCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    useCustomPosCb.text:SetPoint("LEFT", useCustomPosCb, "RIGHT", 4, 1)
    useCustomPosCb.text:SetText(localized("EAM_STAT_USE_CUSTOM_POS", "啟用此項獨立位置 (可自由拖曳)"))
    if EAM.UI.setTooltip then EAM.UI.setTooltip(useCustomPosCb, "開啟後此屬性不再隨整組排列，可獨立隨意放置於螢幕任意位置", "獨立位置") end

    local offsetXSlider = api.CreateFrame("Slider", nil, pagePos, "OptionsSliderTemplate")
    offsetXSlider:SetPoint("TOPLEFT", pagePos, "TOPLEFT", 12, -60)
    offsetXSlider:SetMinMaxValues(-1200, 1200)
    offsetXSlider:SetValueStep(1)
    offsetXSlider:SetObeyStepOnDrag(true)
    offsetXSlider:SetSize(320, 14)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(offsetXSlider, "調整此屬性的螢幕水平 X 軸像素位置", "水平位置") end
    local offsetXLabel = offsetXSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    offsetXLabel:SetPoint("BOTTOMLEFT", offsetXSlider, "TOPLEFT", 0, 4)
    offsetXLabel:SetText(localized("EAM_STAT_OFFSET_X", "水平位置 (X 偏移)"))
    local offsetXVal = offsetXSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    offsetXVal:SetPoint("BOTTOMRIGHT", offsetXSlider, "TOPRIGHT", 0, 4)

    local offsetYSlider = api.CreateFrame("Slider", nil, pagePos, "OptionsSliderTemplate")
    offsetYSlider:SetPoint("TOPLEFT", pagePos, "TOPLEFT", 12, -120)
    offsetYSlider:SetMinMaxValues(-900, 900)
    offsetYSlider:SetValueStep(1)
    offsetYSlider:SetObeyStepOnDrag(true)
    offsetYSlider:SetSize(320, 14)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(offsetYSlider, "調整此屬性的螢幕垂直 Y 軸像素位置", "垂直位置") end
    local offsetYLabel = offsetYSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    offsetYLabel:SetPoint("BOTTOMLEFT", offsetYSlider, "TOPLEFT", 0, 4)
    offsetYLabel:SetText(localized("EAM_STAT_OFFSET_Y", "垂直位置 (Y 偏移)"))
    local offsetYVal = offsetYSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    offsetYVal:SetPoint("BOTTOMRIGHT", offsetYSlider, "TOPRIGHT", 0, 4)

    local moveSingleBtn = api.CreateFrame("Button", nil, pagePos, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(moveSingleBtn) end
    moveSingleBtn:SetSize(140, 24)
    moveSingleBtn:SetPoint("TOPLEFT", pagePos, "TOPLEFT", 16, -170)
    moveSingleBtn:SetText(localized("EAM_STAT_MOVE_SINGLE_BTN", "移動此單項"))
    if EAM.UI.setTooltip then EAM.UI.setTooltip(moveSingleBtn, "僅在畫面上亮起當前選中屬性的移動錨點以供滑鼠單獨拖曳", "移動此單項") end
    moveSingleBtn:SetScript("OnClick", function()
        if PlayerStatService and PlayerStatService.setActiveAnchors then
            PlayerStatService.setActiveAnchors(not PlayerStatService.isMoving, Panel.selectedKey)
        end
    end)

    local moveAllBtn = api.CreateFrame("Button", nil, pagePos, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(moveAllBtn) end
    moveAllBtn:SetSize(140, 24)
    moveAllBtn:SetPoint("LEFT", moveSingleBtn, "RIGHT", 12, 0)
    moveAllBtn:SetText(localized("EAM_STAT_MOVE_ALL_BTN", "移動所有屬性"))
    if EAM.UI.setTooltip then EAM.UI.setTooltip(moveAllBtn, "在畫面上亮起群組與所有獨立屬性框架的錨點以供拖曳調整", "移動所有屬性") end
    moveAllBtn:SetScript("OnClick", function()
        if EAM.UI.Renderer and EAM.UI.Renderer.setActiveAnchors then
            EAM.UI.Renderer.setActiveAnchors("playerStat")
        end
    end)

    local moveHint = pagePos:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    moveHint:SetPoint("TOPLEFT", pagePos, "TOPLEFT", 12, -210)
    moveHint:SetWidth(380)
    moveHint:SetJustifyH("LEFT")
    moveHint:SetText("提示：點擊移動按鈕後，畫面中央將顯示移動錨點，按住滑鼠左鍵可拖曳，右鍵點擊完成定位。")

    Panel.controls.offsetXSlider = offsetXSlider
    Panel.controls.offsetXVal = offsetXVal
    Panel.controls.offsetYSlider = offsetYSlider
    Panel.controls.offsetYVal = offsetYVal

    -- =========================================================================
    -- 即時熱更新與雙向自動儲存機制
    -- =========================================================================
    local isUpdatingUI = false
    local function applyLiveChange()
        if isUpdatingUI then return end
        local cfg = getStatConfig(Panel.selectedKey)
        cfg.enabled = enableCb:GetChecked() and true or false
        cfg.showIcon = showIconCb:GetChecked() and true or false
        cfg.showStatusBar = showStatusBarCb:GetChecked() and true or false
        if Panel.selectedKey == "skyridingSpeed" then
            cfg.glideOnlyIcon = glideOnlyIconCb:GetChecked() and true or false
        end
        cfg.customIcon = iconEditBox:GetText() or ""
        cfg.iconSize = sizeSlider:GetValue()
        cfg.fontSizeValue = fontValSlider:GetValue()
        cfg.fontSizeLabel = fontLabelSlider:GetValue()
        cfg.customLabel = customLabelEditBox:GetText() or ""
        cfg.decimals = tonumber(decimalsEditBox:GetText()) or 1
        cfg.shortNumber = shortNumberCb:GetChecked() and true or false
        cfg.thresholdMin = tonumber(minThreshEditBox:GetText())
        cfg.thresholdMax = tonumber(maxThreshEditBox:GetText())
        cfg.useCustomPos = useCustomPosCb:GetChecked() and true or false
        cfg.offsetX = offsetXSlider:GetValue()
        cfg.offsetY = offsetYSlider:GetValue()

        -- 即時同步更新左側列表中選中項目的勾選框
        for _, r in ipairs(Panel.rows) do
            if r.statKey == Panel.selectedKey and r.cb then
                r.cb:SetChecked(cfg.enabled)
                break
            end
        end

        if PlayerStatService and PlayerStatService.update then
            PlayerStatService.update()
        end

        if EAM.UI.PreviewPanel and EAM.UI.PreviewPanel.refresh then
            EAM.UI.PreviewPanel.refresh()
        end
    end
    Panel.applyLiveChange = applyLiveChange

    -- 綁定即時觸發事件
    enableCb:SetScript("OnClick", applyLiveChange)
    showIconCb:SetScript("OnClick", applyLiveChange)
    showStatusBarCb:SetScript("OnClick", applyLiveChange)
    glideOnlyIconCb:SetScript("OnClick", applyLiveChange)
    useCustomPosCb:SetScript("OnClick", applyLiveChange)

    iconEditBox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText()
        if txt and txt ~= "" then
            local iconTex = tonumber(txt) or txt
            iconPreviewBox:SetTexture(iconTex)
            iconPreviewBox:Show()
        else
            local iconTex = PlayerStatService and PlayerStatService.getStatIcon and PlayerStatService.getStatIcon(Panel.selectedKey) or 134400
            iconPreviewBox:SetTexture(iconTex)
        end
        applyLiveChange()
    end)

    sizeSlider:SetScript("OnValueChanged", function(self, val)
        sizeVal:SetText(math.floor(val))
        applyLiveChange()
    end)

    fontValSlider:SetScript("OnValueChanged", function(self, val)
        fontValVal:SetText(math.floor(val))
        applyLiveChange()
    end)

    fontLabelSlider:SetScript("OnValueChanged", function(self, val)
        fontLabelVal:SetText(math.floor(val))
        applyLiveChange()
    end)

    offsetXSlider:SetScript("OnValueChanged", function(self, val)
        offsetXVal:SetText(math.floor(val))
        applyLiveChange()
    end)

    offsetYSlider:SetScript("OnValueChanged", function(self, val)
        offsetYVal:SetText(math.floor(val))
        applyLiveChange()
    end)

    customLabelEditBox:SetScript("OnTextChanged", applyLiveChange)
    decimalsEditBox:SetScript("OnTextChanged", applyLiveChange)
    shortNumberCb:SetScript("OnClick", applyLiveChange)
    minThreshEditBox:SetScript("OnTextChanged", applyLiveChange)
    maxThreshEditBox:SetScript("OnTextChanged", applyLiveChange)

    for index = 1, #valuePlacementOptions do
        local option = valuePlacementOptions[index]
        local menuButton = api.CreateFrame("Button", nil, valuePlacementMenu)
        menuButton:SetSize(134, 20)
        menuButton:SetPoint("TOPLEFT", valuePlacementMenu, "TOPLEFT", 3, -3 - (index - 1) * 22)
        local menuButtonText = menuButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        menuButtonText:SetPoint("LEFT", menuButton, "LEFT", 6, 0)
        menuButtonText:SetText((EAM.L and EAM.L[option.labelKey]) or option.fallback)
        if Theme and Theme.registerButton then Theme.registerButton(menuButton) end
        menuButton:SetScript("OnClick", function()
            local cfg = getStatConfig(Panel.selectedKey)
            cfg.valuePlacement = option.value
            refreshValuePlacementDropdown(option.value)
            valuePlacementMenu:Hide()
            applyLiveChange()
        end)
    end

    valuePlacementDropdown:SetScript("OnClick", function()
        if valuePlacementMenu:IsShown() then
            valuePlacementMenu:Hide()
        else
            valuePlacementMenu:Show()
        end
    end)

    -- 底部儲存按鈕
    local function saveSelectedStat()
        applyLiveChange()
        print("|cff00ff96EAM|r " .. string.format(localized("EAM_STAT_SAVED", "已儲存 [%s] 屬性監控設定。"), detailTitle:GetText()))
    end

    local saveBtn = api.CreateFrame("Button", nil, detailContainer, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(saveBtn) end
    saveBtn:SetSize(130, 24)
    saveBtn:SetPoint("BOTTOMLEFT", detailContainer, "BOTTOMLEFT", 14, 12)
    saveBtn:SetText(localized("EAM_OPT_COND_SAVE_BTN", "儲存設定 (Save)"))
    if EAM.UI.setTooltip then EAM.UI.setTooltip(saveBtn, "儲存並套用當前屬性的所有顯示與警戒設定", "儲存設定") end
    saveBtn:SetScript("OnClick", saveSelectedStat)

    -- 載入選定屬性到右側表單
    local function loadStatToDetail(statKey)
        Panel.selectedKey = statKey
        local def = PlayerStatService and PlayerStatService.DEFINITIONS and PlayerStatService.DEFINITIONS[statKey]
        if not def then return end

        local cfg = getStatConfig(statKey)
        local val = PlayerStatService and PlayerStatService.getStatValue and PlayerStatService.getStatValue(statKey) or 0

        isUpdatingUI = true

        detailTitle:SetText((EAM.L and def.labelKey and EAM.L[def.labelKey]) or def.defaultLabel)
        detailValPreview:SetText("當前數值: " .. PlayerStatService.formatStatNumber(val, def.format, cfg.decimals, cfg.shortNumber, def.suffix))

        local iconTex = PlayerStatService and PlayerStatService.getStatIcon and PlayerStatService.getStatIcon(statKey, cfg.customIcon) or def.defaultIcon
        detailIcon:SetTexture(iconTex)
        iconPreviewBox:SetTexture(iconTex)

        enableCb:SetChecked(cfg.enabled == true)
        showIconCb:SetChecked(cfg.showIcon ~= false)
        showStatusBarCb:SetChecked(cfg.showStatusBar ~= false)
        if statKey == "skyridingSpeed" then
            glideOnlyIconCb:Show()
            glideOnlyIconCb:SetChecked(cfg.glideOnlyIcon == true)
        else
            glideOnlyIconCb:Hide()
        end
        iconEditBox:SetText(cfg.customIcon or "")

        refreshValuePlacementDropdown(cfg.valuePlacement or "TOP")

        sizeSlider:SetValue(cfg.iconSize or 36)
        sizeVal:SetText(math.floor(cfg.iconSize or 36))
        fontValSlider:SetValue(cfg.fontSizeValue or 14)
        fontValVal:SetText(math.floor(cfg.fontSizeValue or 14))
        fontLabelSlider:SetValue(cfg.fontSizeLabel or 11)
        fontLabelVal:SetText(math.floor(cfg.fontSizeLabel or 11))
        customLabelEditBox:SetText(cfg.customLabel or "")
        decimalsEditBox:SetText(tostring(cfg.decimals or 1))
        shortNumberCb:SetChecked(cfg.shortNumber ~= false)
        minThreshEditBox:SetText(cfg.thresholdMin and tostring(cfg.thresholdMin) or "")
        maxThreshEditBox:SetText(cfg.thresholdMax and tostring(cfg.thresholdMax) or "")

        useCustomPosCb:SetChecked(cfg.useCustomPos == true)
        offsetXSlider:SetValue(cfg.offsetX or 0)
        offsetXVal:SetText(math.floor(cfg.offsetX or 0))
        offsetYSlider:SetValue(cfg.offsetY or 0)
        offsetYVal:SetText(math.floor(cfg.offsetY or 0))

        isUpdatingUI = false

        -- 高亮左側選中的屬性條目
        for _, r in ipairs(Panel.rows) do
            if r.statKey == statKey then
                r:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                r:SetBackdropColor(0.20, 0.16, 0.06, 0.95)
                if r.text then r.text:SetTextColor(1.0, 0.9, 0.3, 1) end
            else
                r:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.8)
                r:SetBackdropColor(0.08, 0.08, 0.10, 0.8)
                if r.text then r.text:SetTextColor(0.85, 0.85, 0.85, 1) end
            end
            if r.cb then
                local rCfg = getStatConfig(r.statKey)
                r.cb:SetChecked(rCfg.enabled == true)
            end
        end

        if EAM.UI.PreviewPanel and EAM.UI.PreviewPanel.refresh then
            EAM.UI.PreviewPanel.refresh()
        end
    end
    Panel.loadStatToDetail = loadStatToDetail

    -- 建立左側列表項目
    local function buildList()
        local keys = PlayerStatService and PlayerStatService.ORDERED_KEYS or {}
        scrollChild:SetSize(210, math.max(440, #keys * 32 + 20))
        for idx, key in ipairs(keys) do
            local def = PlayerStatService.DEFINITIONS[key]
            local row = Panel.rows[idx]
            if not row then
                row = api.CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                row:SetSize(200, 28)
                row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -4 - (idx - 1) * 32)
                row:SetBackdrop({
                    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = false, tileSize = 0, edgeSize = 8,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 }
                })
                row:SetBackdropColor(0.08, 0.08, 0.10, 0.8)
                row:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.8)

                local cb = api.CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                cb:SetSize(20, 20)
                cb:SetPoint("LEFT", row, "LEFT", 4, 0)
                row.cb = cb

                local rowIcon = row:CreateTexture(nil, "ARTWORK")
                rowIcon:SetSize(20, 20)
                rowIcon:SetPoint("LEFT", cb, "RIGHT", 2, 0)
                rowIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.icon = rowIcon

                local rowText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                rowText:SetPoint("LEFT", rowIcon, "RIGHT", 6, 0)
                row.text = rowText

                local rowVal = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                rowVal:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                row.valText = rowVal

                row:SetScript("OnClick", function()
                    loadStatToDetail(row.statKey)
                end)

                cb:SetScript("OnClick", function(self)
                    local statCfg = getStatConfig(row.statKey)
                    statCfg.enabled = self:GetChecked() and true or false
                    if PlayerStatService and PlayerStatService.update then
                        PlayerStatService.update()
                    end
                    loadStatToDetail(row.statKey)
                end)

                Panel.rows[idx] = row
            end

            row.statKey = key
            local cfg = getStatConfig(key)
            local val = PlayerStatService.getStatValue(key)
            local labelStr = (EAM.L and def.labelKey and EAM.L[def.labelKey]) or def.defaultLabel
            row.text:SetText(labelStr)
            row.valText:SetText(PlayerStatService.formatStatNumber(val, def.format, cfg.decimals, cfg.shortNumber, def.suffix))
            row.cb:SetChecked(cfg.enabled == true)

            local iconTex = PlayerStatService and PlayerStatService.getStatIcon and PlayerStatService.getStatIcon(key, cfg.customIcon) or def.defaultIcon
            row.icon:SetTexture(iconTex)
            row:Show()
        end
    end
    Panel.buildList = buildList

    Panel.refreshList = function()
        local keys = PlayerStatService and PlayerStatService.ORDERED_KEYS or {}
        for idx, key in ipairs(keys) do
            local row = Panel.rows[idx]
            local def = PlayerStatService.DEFINITIONS[key]
            if row and def then
                local cfg = getStatConfig(key)
                local val = PlayerStatService.getStatValue(key)
                row.valText:SetText(PlayerStatService.formatStatNumber(val, def.format, cfg.decimals, cfg.shortNumber, def.suffix))
                row.cb:SetChecked(cfg.enabled == true)
                local iconTex = PlayerStatService and PlayerStatService.getStatIcon and PlayerStatService.getStatIcon(key, cfg.customIcon) or def.defaultIcon
                row.icon:SetTexture(iconTex)

                if row.statKey == Panel.selectedKey then
                    row:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
                    row:SetBackdropColor(0.20, 0.16, 0.06, 0.95)
                    if row.text then row.text:SetTextColor(1.0, 0.9, 0.3, 1) end
                else
                    row:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.8)
                    row:SetBackdropColor(0.08, 0.08, 0.10, 0.8)
                    if row.text then row.text:SetTextColor(0.85, 0.85, 0.85, 1) end
                end
            end
        end
        if Panel.selectedKey then
            local def = PlayerStatService.DEFINITIONS[Panel.selectedKey]
            local cfg = getStatConfig(Panel.selectedKey)
            if def and cfg then
                local val = PlayerStatService.getStatValue(Panel.selectedKey)
                detailValPreview:SetText("當前數值: " .. PlayerStatService.formatStatNumber(val, def.format, cfg.decimals, cfg.shortNumber, def.suffix))
                enableCb:SetChecked(cfg.enabled == true)
            end
        end

        local _, classToken = nil, "GLOBAL"
        if PlayerStatService and PlayerStatService.getPlayerStatsConfig then
            _, classToken = PlayerStatService.getPlayerStatsConfig()
        end
        local classDisplayName = classToken
        if classToken and _G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[classToken] then
            classDisplayName = _G.LOCALIZED_CLASS_NAMES_MALE[classToken]
        end
        if Panel.title and classDisplayName and classDisplayName ~= "GLOBAL" then
            local baseTitle = localized("EAM_STAT_PANEL_TITLE", "★ 角色屬性與吸收量監控")
            Panel.title:SetText(baseTitle .. " [" .. tostring(classDisplayName) .. "]")
        end
    end

    Panel.syncSliders = function(statKey, x, y)
        if Panel.selectedKey == statKey and Panel.controls then
            if Panel.controls.offsetXSlider and Panel.controls.offsetXVal then
                Panel.controls.offsetXSlider:SetValue(x or 0)
                Panel.controls.offsetXVal:SetText(math.floor(x or 0))
            end
            if Panel.controls.offsetYSlider and Panel.controls.offsetYVal then
                Panel.controls.offsetYSlider:SetValue(y or 0)
                Panel.controls.offsetYVal:SetText(math.floor(y or 0))
            end
        end
    end

    -- 面板開啟時即時刷新當前屬性數值
    local panelElapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        panelElapsed = panelElapsed + delta
        if panelElapsed >= 0.15 then
            panelElapsed = 0
            if Panel.refreshList then
                Panel.refreshList()
            end
        end
    end)

    buildList()
    selectTab(1)
    loadStatToDetail("crit")

    frame:Hide()
    Panel.frame = frame
    return frame
end

function Panel.open()
    if inCombat() then
        print("|cff00ff96EAM|r " .. (localized("EAM_STAT_COMBAT_BLOCKED", "戰鬥中不開啟屬性監控設定面板。")))
        return false, "combatBlocked"
    end
    if EAM.UI and type(EAM.UI.closeAllSidePanels) == "function" then
        EAM.UI.closeAllSidePanels("stat")
    end
    local frame = createFrame()
    if not frame then return false end

    local mainFrame = _G.EAM_MainOptionsFrame
    if mainFrame and mainFrame:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 2, 0)
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    end
    frame:Show()
    frame:Raise()
    Panel.refreshList()
    return true
end

function Panel.hide()
    if Panel.frame then
        if Panel.applyLiveChange then
            Panel.applyLiveChange()
        end
        Panel.frame:Hide()
    end
    if EAM.UI and EAM.UI.Renderer and EAM.UI.Renderer.setActiveAnchors then
        EAM.UI.Renderer.setActiveAnchors(nil)
    end
end

Panel.close = Panel.hide
