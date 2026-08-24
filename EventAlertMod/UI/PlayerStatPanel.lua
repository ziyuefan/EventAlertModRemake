--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/PlayerStatPanel
檔案: UI\PlayerStatPanel.lua

理念:
- 角色屬性與吸收量監控之獨立二級設定面板。
- 支援 16 種核心屬性每單項開關、替代圖示、字型大小、替代名稱、小數位數與數值高亮閾值自訂。

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
}
EAM.UI.PlayerStatPanel = Panel

local function inCombat()
    return api.InCombatLockdown and api.InCombatLockdown()
end

local function getStatConfig(statKey)
    local db = EAM.db
    if not db then return {} end
    db.playerStats = db.playerStats or {}
    if not db.playerStats[statKey] then
        db.playerStats[statKey] = {
            enabled = false,
            showIcon = true,
            customIcon = "",
            iconSize = 36,
            fontSizeValue = 14,
            fontSizeLabel = 11,
            customLabel = "",
            decimals = 1,
            shortNumber = true,
        }
    end
    return db.playerStats[statKey]
end

local function createFrame()
    if Panel.frame then return Panel.frame end

    local parent = _G.UIParent
    if not parent then return nil end

    local frame = api.CreateFrame("Frame", "EAM_PlayerStatOptionsFrame", parent, "BackdropTemplate")
    frame:SetSize(620, 540)
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
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -16)
    title:SetText(EAM.L.EAM_STAT_PANEL_TITLE or "★ 角色屬性與吸收量監控 (Player Stats & Absorbs)")
    title:SetTextColor(1.0, 0.82, 0.0, 1)
    if Theme and Theme.registerText then Theme.registerText(title, "title") end

    -- 右上關閉按鈕 [X]
    local closeBtn = api.CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(28, 28)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() Panel.hide() end)

    -- ===================================================
    -- 【左側】：屬性列表 (寬度 240px)
    -- ===================================================
    local listContainer = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listContainer:SetSize(240, 440)
    listContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -50)
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
    scrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -24, 4)

    local scrollChild = api.CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(210, 520)
    scrollFrame:SetScrollChild(scrollChild)

    -- ===================================================
    -- 【右側】：細部設定表單 (寬度 340px)
    -- ===================================================
    local detailContainer = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    detailContainer:SetSize(340, 440)
    detailContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -50)
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
    detailIcon:SetSize(40, 40)
    detailIcon:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 16, -14)
    detailIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local detailTitle = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    detailTitle:SetPoint("LEFT", detailIcon, "RIGHT", 10, 8)
    detailTitle:SetTextColor(1.0, 0.88, 0.2, 1)

    local detailValPreview = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detailValPreview:SetPoint("LEFT", detailIcon, "RIGHT", 10, -10)
    detailValPreview:SetTextColor(0.4, 0.9, 1.0, 1)

    -- 1. 啟用開關
    local enableCb = api.CreateFrame("CheckButton", nil, detailContainer, "UICheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 14, -62)
    enableCb.text = enableCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    enableCb.text:SetPoint("LEFT", enableCb, "RIGHT", 4, 1)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(enableCb, "啟用/停用此項屬性在畫面上的即時數值顯示", "啟用監控") end

    -- 2. 顯示圖示 & 顯示進度條 (StatusBar)
    local showIconCb = api.CreateFrame("CheckButton", nil, detailContainer, "UICheckButtonTemplate")
    showIconCb:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 140, -62)
    showIconCb.text = showIconCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    showIconCb.text:SetPoint("LEFT", showIconCb, "RIGHT", 4, 1)
    showIconCb.text:SetText(EAM.L.EAM_STAT_SHOW_ICON or "顯示圖示")
    if EAM.UI.setTooltip then EAM.UI.setTooltip(showIconCb, "是否在此屬性旁邊顯示技能/屬性圖示", "顯示圖示") end

    local showStatusBarCb = api.CreateFrame("CheckButton", nil, detailContainer, "UICheckButtonTemplate")
    showStatusBarCb:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 225, -62)
    showStatusBarCb.text = showStatusBarCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    showStatusBarCb.text:SetPoint("LEFT", showStatusBarCb, "RIGHT", 4, 1)
    showStatusBarCb.text:SetText(EAM.L.EAM_STAT_SHOW_STATUSBAR or "進度條")
    if EAM.UI.setTooltip then EAM.UI.setTooltip(showStatusBarCb, "是否在此屬性下方顯示進度條/狀態條", "顯示進度條") end

    -- 3. 替代圖示輸入框與預覽方塊
    local iconLabel = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconLabel:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 16, -96)
    iconLabel:SetText(EAM.L.EAM_OPT_CUSTOM_ICON_LABEL or "自訂替代圖示 (代碼或材質路徑):")

    local iconEditBox = api.CreateFrame("EditBox", nil, detailContainer, "InputBoxTemplate")
    iconEditBox:SetSize(240, 20)
    iconEditBox:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 20, -114)
    iconEditBox:SetAutoFocus(false)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(iconEditBox, "輸入替代圖示的 FileDataID 數字代碼或材質路徑（留空使用預設圖示）", "自訂替代圖示") end

    local iconPreviewBox = detailContainer:CreateTexture(nil, "OVERLAY")
    iconPreviewBox:SetSize(22, 22)
    iconPreviewBox:SetPoint("LEFT", iconEditBox, "RIGHT", 8, 0)
    iconPreviewBox:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    iconEditBox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText()
        if txt and txt ~= "" then
            local iconTex = tonumber(txt) or txt
            iconPreviewBox:SetTexture(iconTex)
            iconPreviewBox:Show()
        else
            local def = PlayerStatService and PlayerStatService.DEFINITIONS and PlayerStatService.DEFINITIONS[Panel.selectedKey]
            iconPreviewBox:SetTexture(def and def.defaultIcon or 134400)
        end
    end)

    -- WoW Tools URL 提示
    local urlHint = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    urlHint:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 16, -140)
    urlHint:SetText("可在 WoW.tools / Wago Tools 查詢圖示代碼與路徑:")

    local urlBox = api.CreateFrame("EditBox", nil, detailContainer, "InputBoxTemplate")
    urlBox:SetSize(295, 18)
    urlBox:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 20, -156)
    urlBox:SetAutoFocus(false)
    urlBox:SetText("https://wago.tools/icons")
    if EAM.UI.setTooltip then EAM.UI.setTooltip(urlBox, "點擊反白複製網址前往 Wago Tools 查詢圖示代碼", "圖示查詢網站") end
    urlBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    -- 4. 圖示大小滑桿
    local sizeSlider = api.CreateFrame("Slider", nil, detailContainer, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 16, -196)
    sizeSlider:SetMinMaxValues(16, 80)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetSize(140, 16)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(sizeSlider, "調整此屬性圖示的像素大小 (16~80px)", "圖示大小") end
    local sizeLabel = sizeSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sizeLabel:SetPoint("BOTTOMLEFT", sizeSlider, "TOPLEFT", 0, 4)
    sizeLabel:SetText(EAM.L.EAM_STAT_ICON_SIZE or "圖示大小 (Icon Size)")
    local sizeVal = sizeSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sizeVal:SetPoint("BOTTOMRIGHT", sizeSlider, "TOPRIGHT", 0, 4)
    sizeSlider:SetScript("OnValueChanged", function(self, val)
        sizeVal:SetText(math.floor(val))
    end)

    -- 5. 數值字型大小滑桿
    local fontValSlider = api.CreateFrame("Slider", nil, detailContainer, "OptionsSliderTemplate")
    fontValSlider:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 180, -196)
    fontValSlider:SetMinMaxValues(8, 32)
    fontValSlider:SetValueStep(1)
    fontValSlider:SetObeyStepOnDrag(true)
    fontValSlider:SetSize(140, 16)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(fontValSlider, "調整屬性數值數字的文字大小 (8~32px)", "數值字型大小") end
    local fontValLabel = fontValSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontValLabel:SetPoint("BOTTOMLEFT", fontValSlider, "TOPLEFT", 0, 4)
    fontValLabel:SetText(EAM.L.EAM_STAT_FONT_VALUE or "數值字型大小")
    local fontValVal = fontValSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontValVal:SetPoint("BOTTOMRIGHT", fontValSlider, "TOPRIGHT", 0, 4)
    fontValSlider:SetScript("OnValueChanged", function(self, val)
        fontValVal:SetText(math.floor(val))
    end)

    -- 6. 代表名稱字型大小滑桿
    local fontLabelSlider = api.CreateFrame("Slider", nil, detailContainer, "OptionsSliderTemplate")
    fontLabelSlider:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 16, -240)
    fontLabelSlider:SetMinMaxValues(8, 24)
    fontLabelSlider:SetValueStep(1)
    fontLabelSlider:SetObeyStepOnDrag(true)
    fontLabelSlider:SetSize(140, 16)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(fontLabelSlider, "調整屬性名稱標籤的文字大小 (8~24px)", "名稱字型大小") end
    local fontLabelLabel = fontLabelSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontLabelLabel:SetPoint("BOTTOMLEFT", fontLabelSlider, "TOPLEFT", 0, 4)
    fontLabelLabel:SetText(EAM.L.EAM_STAT_FONT_LABEL or "名稱字型大小")
    local fontLabelVal = fontLabelSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontLabelVal:SetPoint("BOTTOMRIGHT", fontLabelSlider, "TOPRIGHT", 0, 4)
    fontLabelSlider:SetScript("OnValueChanged", function(self, val)
        fontLabelVal:SetText(math.floor(val))
    end)

    -- 7. 代表名稱替代文字
    local customLabelLabel = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    customLabelLabel:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 180, -225)
    customLabelLabel:SetText(EAM.L.EAM_STAT_CUSTOM_LABEL or "名稱替代文字 (自訂):")

    local customLabelEditBox = api.CreateFrame("EditBox", nil, detailContainer, "InputBoxTemplate")
    customLabelEditBox:SetSize(140, 20)
    customLabelEditBox:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 184, -240)
    customLabelEditBox:SetAutoFocus(false)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(customLabelEditBox, "自訂顯示在畫面上的屬性簡稱（留空使用預設名稱）", "名稱替代文字") end

    -- 8. 小數位數與大數值簡寫
    local decimalsLabel = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    decimalsLabel:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 16, -275)
    decimalsLabel:SetText(EAM.L.EAM_STAT_DECIMALS or "小數位數 (0 ~ 2):")

    local decimalsEditBox = api.CreateFrame("EditBox", nil, detailContainer, "InputBoxTemplate")
    decimalsEditBox:SetSize(60, 20)
    decimalsEditBox:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 20, -292)
    decimalsEditBox:SetAutoFocus(false)
    decimalsEditBox:SetNumeric(true)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(decimalsEditBox, "數值顯示的小數位數（0 ~ 2 位）", "小數位數") end

    local shortNumberCb = api.CreateFrame("CheckButton", nil, detailContainer, "UICheckButtonTemplate")
    shortNumberCb:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 110, -288)
    shortNumberCb.text = shortNumberCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    shortNumberCb.text:SetPoint("LEFT", shortNumberCb, "RIGHT", 4, 1)
    shortNumberCb.text:SetText(EAM.L.EAM_STAT_SHORT_NUMBER or "大數值簡寫 (k/M)")
    if EAM.UI.setTooltip then EAM.UI.setTooltip(shortNumberCb, "數值過大時自動以 k / M 單位簡化顯示（例如 150.2k）", "大數值簡寫") end

    -- 9. 警戒值上限 / 下限
    local minThreshLabel = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minThreshLabel:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 16, -325)
    minThreshLabel:SetText(EAM.L.EAM_STAT_MIN_THRESH or "低於此值紅框警戒:")

    local minThreshEditBox = api.CreateFrame("EditBox", nil, detailContainer, "InputBoxTemplate")
    minThreshEditBox:SetSize(120, 20)
    minThreshEditBox:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 20, -342)
    minThreshEditBox:SetAutoFocus(false)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(minThreshEditBox, "當屬性數值低於此閾值時，邊框變紅高亮警戒（留空不啟用）", "低於警戒值") end

    local maxThreshLabel = detailContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    maxThreshLabel:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 180, -325)
    maxThreshLabel:SetText(EAM.L.EAM_STAT_MAX_THRESH or "高於此值紅框警戒:")

    local maxThreshEditBox = api.CreateFrame("EditBox", nil, detailContainer, "InputBoxTemplate")
    maxThreshEditBox:SetSize(120, 20)
    maxThreshEditBox:SetPoint("TOPLEFT", detailContainer, "TOPLEFT", 184, -342)
    maxThreshEditBox:SetAutoFocus(false)
    if EAM.UI.setTooltip then EAM.UI.setTooltip(maxThreshEditBox, "當屬性數值高於此閾值時，邊框變紅高亮警戒（留空不啟用）", "高於警戒值") end

    -- 10. 底部儲存與移動按鈕
    local function saveSelectedStat()
        local cfg = getStatConfig(Panel.selectedKey)
        cfg.enabled = enableCb:GetChecked() and true or false
        cfg.showIcon = showIconCb:GetChecked() and true or false
        cfg.showStatusBar = showStatusBarCb:GetChecked() and true or false
        cfg.customIcon = iconEditBox:GetText() or ""
        cfg.iconSize = sizeSlider:GetValue()
        cfg.fontSizeValue = fontValSlider:GetValue()
        cfg.fontSizeLabel = fontLabelSlider:GetValue()
        cfg.customLabel = customLabelEditBox:GetText() or ""
        cfg.decimals = tonumber(decimalsEditBox:GetText()) or 1
        cfg.shortNumber = shortNumberCb:GetChecked() and true or false
        cfg.thresholdMin = tonumber(minThreshEditBox:GetText())
        cfg.thresholdMax = tonumber(maxThreshEditBox:GetText())

        if PlayerStatService and PlayerStatService.update then
            PlayerStatService.update()
        end
        Panel.refreshList()
        print("|cff00ff96EAM|r " .. string.format(EAM.L.EAM_STAT_SAVED or "已儲存 [%s] 屬性監控設定。", detailTitle:GetText()))
    end

    local saveBtn = api.CreateFrame("Button", nil, detailContainer, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(saveBtn) end
    saveBtn:SetSize(140, 26)
    saveBtn:SetPoint("BOTTOMLEFT", detailContainer, "BOTTOMLEFT", 16, 16)
    saveBtn:SetText(EAM.L.EAM_OPT_COND_SAVE_BTN or "儲存設定 (Save)")
    if EAM.UI.setTooltip then EAM.UI.setTooltip(saveBtn, "儲存並套用當前屬性的所有顯示與警戒設定", "儲存設定") end
    saveBtn:SetScript("OnClick", saveSelectedStat)

    local moveBtn = api.CreateFrame("Button", nil, detailContainer, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(moveBtn) end
    moveBtn:SetSize(150, 26)
    moveBtn:SetPoint("BOTTOMRIGHT", detailContainer, "BOTTOMRIGHT", -16, 16)
    moveBtn:SetText(EAM.L.EAM_STAT_MOVE_BTN or "移動屬性框架")
    if EAM.UI.setTooltip then EAM.UI.setTooltip(moveBtn, "在畫面上亮起屬性框架的錨點以方便滑鼠拖曳移動位置", "移動屬性框架") end
    moveBtn:SetScript("OnClick", function()
        if EAM.UI.Renderer and EAM.UI.Renderer.setActiveAnchors then
            EAM.UI.Renderer.setActiveAnchors("playerStat")
        end
    end)

    -- 載入選定屬性到右側表單
    local function loadStatToDetail(statKey)
        Panel.selectedKey = statKey
        local def = PlayerStatService and PlayerStatService.DEFINITIONS and PlayerStatService.DEFINITIONS[statKey]
        if not def then return end

        local cfg = getStatConfig(statKey)
        local val = PlayerStatService and PlayerStatService.getStatValue and PlayerStatService.getStatValue(statKey) or 0

        detailTitle:SetText((EAM.L and def.labelKey and EAM.L[def.labelKey]) or def.defaultLabel)
        detailValPreview:SetText("當前數值: " .. PlayerStatService.formatStatNumber(val, def.format, cfg.decimals, cfg.shortNumber, def.suffix))

        local iconTex = (cfg.customIcon and cfg.customIcon ~= "") and (tonumber(cfg.customIcon) or cfg.customIcon) or def.defaultIcon
        detailIcon:SetTexture(iconTex)
        iconPreviewBox:SetTexture(iconTex)

        enableCb:SetChecked(cfg.enabled == true)
        showIconCb:SetChecked(cfg.showIcon ~= false)
        showStatusBarCb:SetChecked(cfg.showStatusBar ~= false)
        iconEditBox:SetText(cfg.customIcon or "")

        sizeSlider:SetValue(cfg.iconSize or 36)
        fontValSlider:SetValue(cfg.fontSizeValue or 14)
        fontLabelSlider:SetValue(cfg.fontSizeLabel or 11)
        customLabelEditBox:SetText(cfg.customLabel or "")
        decimalsEditBox:SetText(tostring(cfg.decimals or 1))
        shortNumberCb:SetChecked(cfg.shortNumber ~= false)
        minThreshEditBox:SetText(cfg.thresholdMin and tostring(cfg.thresholdMin) or "")
        maxThreshEditBox:SetText(cfg.thresholdMax and tostring(cfg.thresholdMax) or "")
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
                    if Panel.selectedKey == row.statKey then
                        enableCb:SetChecked(statCfg.enabled)
                    end
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

            local iconTex = (cfg.customIcon and cfg.customIcon ~= "") and (tonumber(cfg.customIcon) or cfg.customIcon) or def.defaultIcon
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
            end
        end
        if Panel.selectedKey then
            local def = PlayerStatService.DEFINITIONS[Panel.selectedKey]
            local cfg = getStatConfig(Panel.selectedKey)
            if def and cfg then
                local val = PlayerStatService.getStatValue(Panel.selectedKey)
                detailValPreview:SetText("當前數值: " .. PlayerStatService.formatStatNumber(val, def.format, cfg.decimals, cfg.shortNumber, def.suffix))
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
    loadStatToDetail("crit")

    frame:Hide()
    Panel.frame = frame
    return frame
end

function Panel.open()
    if inCombat() then
        print("|cff00ff96EAM|r " .. (EAM.L.EAM_STAT_COMBAT_BLOCKED or "戰鬥中不開啟屬性監控設定面板。"))
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
        Panel.frame:Hide()
    end
    if EAM.UI and EAM.UI.Renderer and EAM.UI.Renderer.setActiveAnchors then
        EAM.UI.Renderer.setActiveAnchors(nil)
    end
end

Panel.close = Panel.hide
