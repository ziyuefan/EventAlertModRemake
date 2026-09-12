--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/PreviewPanel
檔案: UI\PreviewPanel.lua

理念:
- 提供獨立、可自由拖曳的即時效果預覽小視窗 (Live Preview Window)。
- 支援「告警圖示 (Alert)」、「職業資源 (Resource)」與「角色屬性 (Stat)」三大分頁。
- 當使用者在主設定面板、屬性面板或資源面板調整任何滑桿、字型、主題、顏色曲線時，即時連動熱刷新預覽。
]]
local _, EAM = ...

EAM.UI = EAM.UI or {}

local api = EAM.API or {}
local Theme = EAM.Theme
local Util = EAM.Util or {}
local Constants = EAM.Constants

local PreviewPanel = {
    frame = nil,
    currentTab = 1,
    simulatedTime = 2.8,
    simulatedProc = true,
    simulatedPandemic = false,
    simulatedPower = 0.65,
}
EAM.UI.PreviewPanel = PreviewPanel

local function localized(key, fallback)
    return (EAM.L and EAM.L[key]) or fallback
end

local function createFrame()
    if PreviewPanel.frame then return PreviewPanel.frame end

    local parent = _G.UIParent
    if not parent then return nil end

    local frame = api.CreateFrame("Frame", "EAM_PreviewOptionsFrame", parent, "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(330, 420)
    frame:SetPoint("CENTER", parent, "CENTER", 280, 50)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 24, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 }
    })
    frame:SetBackdropColor(0.06, 0.06, 0.09, 0.96)
    frame:SetBackdropBorderColor(0.85, 0.70, 0.35, 1)
    if Theme and Theme.registerFrame then Theme.registerFrame(frame, "window") end

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetClampedToScreen(true)

    -- 標題列
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -14)
    title:SetText(localized("EAM_PREVIEW_TITLE", "★ 即時效果預覽 (Preview)"))
    title:SetTextColor(1.0, 0.85, 0.2, 1)
    if Theme and Theme.registerText then Theme.registerText(title, "title") end

    -- 右上關閉按鈕
    local closeBtn = api.CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(26, 26)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() PreviewPanel.hide() end)

    -- 分頁按鈕容器
    local tabContainer = api.CreateFrame("Frame", nil, frame)
    tabContainer:SetSize(306, 26)
    tabContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -38)

    local tabButtons = {}
    local tabPages = {}
    local tabNames = {
        { id = 1, key = "EAM_PREVIEW_TAB_ALERT", fallback = "告警圖示" },
        { id = 2, key = "EAM_PREVIEW_TAB_RESOURCE", fallback = "職業資源" },
        { id = 3, key = "EAM_PREVIEW_TAB_STAT", fallback = "角色屬性" },
    }

    local function selectTab(tabIdx)
        PreviewPanel.currentTab = tabIdx
        for idx, page in ipairs(tabPages) do
            if idx == tabIdx then
                page:Show()
                if tabButtons[idx] then
                    tabButtons[idx]:LockHighlight()
                end
            else
                page:Hide()
                if tabButtons[idx] then
                    tabButtons[idx]:UnlockHighlight()
                end
            end
        end
        PreviewPanel.refresh()
    end
    PreviewPanel.selectTab = selectTab

    for idx, tInfo in ipairs(tabNames) do
        local btn = api.CreateFrame("Button", nil, tabContainer, "UIPanelButtonTemplate")
        btn:SetSize(98, 22)
        btn:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", (idx - 1) * 102, 0)
        btn:SetText(localized(tInfo.key, tInfo.fallback))
        if Theme and Theme.registerButton then Theme.registerButton(btn) end
        btn:SetScript("OnClick", function() selectTab(idx) end)
        tabButtons[idx] = btn

        local page = api.CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
        page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
        page:Hide()
        tabPages[idx] = page
    end

    -- =========================================================================
    -- 【Tab 1: 告警圖示預覽 (Alert Icon Preview)】
    -- =========================================================================
    local pageAlert = tabPages[1]

    local alertCanvas = api.CreateFrame("Frame", nil, pageAlert, "BackdropTemplate")
    alertCanvas:SetSize(290, 180)
    alertCanvas:SetPoint("TOP", pageAlert, "TOP", 0, -4)
    alertCanvas:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    alertCanvas:SetBackdropColor(0.02, 0.02, 0.03, 0.9)
    alertCanvas:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.8)

    -- 預覽圖示框
    local alertIcon = api.CreateFrame("Frame", nil, alertCanvas)
    alertIcon:SetSize(56, 56)
    alertIcon:SetPoint("CENTER", alertCanvas, "CENTER", 0, -8)

    local iconTex = alertIcon:CreateTexture(nil, "BACKGROUND")
    iconTex:SetAllPoints(alertIcon)
    iconTex:SetTexture(136075) -- Spell_Fire_FlameShock
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    alertIcon.texture = iconTex

    -- 外框邊框 (Border)
    local borderTex = alertIcon:CreateTexture(nil, "OVERLAY")
    borderTex:SetTexture("Interface\\AddOns\\EventAlertMod\\Images\\UI-Achievement-WoodBorder")
    borderTex:SetPoint("TOPLEFT", alertIcon, "TOPLEFT", -3, 3)
    borderTex:SetPoint("BOTTOMRIGHT", alertIcon, "BOTTOMRIGHT", 3, -3)
    borderTex:SetVertexColor(1, 0.82, 0, 1)
    alertIcon.border = borderTex

    -- 發光外框 (Proc Glow)
    local glowTex = alertIcon:CreateTexture(nil, "OVERLAY")
    glowTex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glowTex:SetBlendMode("ADD")
    glowTex:SetPoint("TOPLEFT", alertIcon, "TOPLEFT", -8, 8)
    glowTex:SetPoint("BOTTOMRIGHT", alertIcon, "BOTTOMRIGHT", 8, -8)
    glowTex:SetVertexColor(1, 0.85, 0.2, 1)
    alertIcon.glow = glowTex

    -- 傳染紅綠亮框 (Pandemic Border)
    local pandemicBox = alertIcon:CreateTexture(nil, "OVERLAY")
    pandemicBox:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    pandemicBox:SetBlendMode("ADD")
    pandemicBox:SetPoint("TOPLEFT", alertIcon, "TOPLEFT", -5, 5)
    pandemicBox:SetPoint("BOTTOMRIGHT", alertIcon, "BOTTOMRIGHT", 5, -5)
    pandemicBox:SetVertexColor(0.2, 1.0, 0.3, 1)
    pandemicBox:Hide()
    alertIcon.pandemic = pandemicBox

    -- 法術名稱文字
    local nameText = alertIcon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("BOTTOM", alertIcon, "TOP", 0, 4)
    nameText:SetText(localized("EAM_PREVIEW_SAMPLE_SPELL", "烈焰震擊 (Flame Shock)"))
    alertIcon.nameText = nameText

    -- 倒數秒數文字
    local timerText = alertIcon:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    timerText:SetPoint("CENTER", alertIcon, "CENTER", 0, 0)
    timerText:SetText("2.8")
    alertIcon.timerText = timerText

    -- 堆疊層數文字
    local stackText = alertIcon:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stackText:SetPoint("BOTTOMRIGHT", alertIcon, "BOTTOMRIGHT", -2, 2)
    stackText:SetText("5")
    stackText:SetTextColor(0.4, 0.9, 1.0, 1)
    alertIcon.stackText = stackText

    PreviewPanel.alertIcon = alertIcon

    -- 下方模擬滑桿與勾選框
    local timeSlider = api.CreateFrame("Slider", nil, pageAlert, "OptionsSliderTemplate")
    timeSlider:SetPoint("TOPLEFT", pageAlert, "TOPLEFT", 12, -205)
    timeSlider:SetMinMaxValues(0, 15)
    timeSlider:SetValueStep(0.1)
    timeSlider:SetObeyStepOnDrag(true)
    timeSlider:SetSize(280, 14)
    timeSlider:SetValue(PreviewPanel.simulatedTime)
    local timeLabel = timeSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeLabel:SetPoint("BOTTOMLEFT", timeSlider, "TOPLEFT", 0, 3)
    timeLabel:SetText(localized("EAM_PREVIEW_SIM_TIME", "模擬剩餘秒數 (測試文字變色):"))
    local timeVal = timeSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeVal:SetPoint("BOTTOMRIGHT", timeSlider, "TOPRIGHT", 0, 3)
    timeVal:SetText(string.format("%.1fs", PreviewPanel.simulatedTime))

    timeSlider:SetScript("OnValueChanged", function(self, val)
        PreviewPanel.simulatedTime = val
        timeVal:SetText(string.format("%.1fs", val))
        PreviewPanel.refreshAlertPreview()
    end)

    local procCb = api.CreateFrame("CheckButton", nil, pageAlert, "UICheckButtonTemplate")
    procCb:SetPoint("TOPLEFT", pageAlert, "TOPLEFT", 8, -245)
    procCb.text = procCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    procCb.text:SetPoint("LEFT", procCb, "RIGHT", 4, 1)
    procCb.text:SetText(localized("EAM_PREVIEW_SIM_PROC", "模擬金色觸發發光 (Proc Glow)"))
    procCb:SetChecked(PreviewPanel.simulatedProc)
    procCb:SetScript("OnClick", function(self)
        PreviewPanel.simulatedProc = self:GetChecked() and true or false
        PreviewPanel.refreshAlertPreview()
    end)

    local panCb = api.CreateFrame("CheckButton", nil, pageAlert, "UICheckButtonTemplate")
    panCb:SetPoint("TOPLEFT", pageAlert, "TOPLEFT", 8, -275)
    panCb.text = panCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panCb.text:SetPoint("LEFT", panCb, "RIGHT", 4, 1)
    panCb.text:SetText(localized("EAM_PREVIEW_SIM_PANDEMIC", "模擬 DoT 傳染期 (Pandemic)"))
    panCb:SetChecked(PreviewPanel.simulatedPandemic)
    panCb:SetScript("OnClick", function(self)
        PreviewPanel.simulatedPandemic = self:GetChecked() and true or false
        PreviewPanel.refreshAlertPreview()
    end)

    local hintLabel = pageAlert:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hintLabel:SetPoint("BOTTOMLEFT", pageAlert, "BOTTOMLEFT", 6, 6)
    hintLabel:SetWidth(290)
    hintLabel:SetJustifyH("LEFT")
    hintLabel:SetText(localized("EAM_PREVIEW_HINT", "拖曳滑桿可測試低於門檻時的自動紅字/黃字變色曲線效果。"))

    -- =========================================================================
    -- 【Tab 2: 職業資源預覽 (Player Resource Preview)】
    -- =========================================================================
    local pageResource = tabPages[2]

    local resCanvas = api.CreateFrame("Frame", nil, pageResource, "BackdropTemplate")
    resCanvas:SetSize(290, 200)
    resCanvas:SetPoint("TOP", pageResource, "TOP", 0, -4)
    resCanvas:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    resCanvas:SetBackdropColor(0.02, 0.02, 0.03, 0.9)
    resCanvas:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.8)

    local resContainer = api.CreateFrame("Frame", nil, resCanvas)
    resContainer:SetSize(200, 34)
    resContainer:SetPoint("CENTER", resCanvas, "CENTER", 0, 0)

    local resIcon = resContainer:CreateTexture(nil, "ARTWORK")
    resIcon:SetSize(30, 30)
    resIcon:SetPoint("LEFT", resContainer, "LEFT", 0, 0)
    resIcon:SetTexture(136080) -- Rogue combo / energy icon
    resIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    resContainer.icon = resIcon

    local resBar = api.CreateFrame("StatusBar", nil, resContainer)
    resBar:SetSize(140, 16)
    resBar:SetPoint("LEFT", resIcon, "RIGHT", 6, 0)
    resBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    resBar:SetStatusBarColor(1, 0.85, 0.1, 1)
    resBar:SetMinMaxValues(0, 1)
    resBar:SetValue(0.65)
    resContainer.statusBar = resBar

    local resBg = resBar:CreateTexture(nil, "BACKGROUND")
    resBg:SetAllPoints(resBar)
    resBg:SetColorTexture(0.02, 0.02, 0.02, 0.6)
    resContainer.bg = resBg

    local resLabel = resContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resLabel:SetPoint("BOTTOMLEFT", resBar, "TOPLEFT", 0, 2)
    resLabel:SetText(localized("EAM_PREVIEW_SAMPLE_POWER", "能量 (Energy)"))
    resContainer.label = resLabel

    local resVal = resContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resVal:SetPoint("CENTER", resBar, "CENTER", 0, 0)
    resVal:SetText("65 / 100 (65%)")
    resContainer.valText = resVal

    PreviewPanel.resContainer = resContainer

    local powerSlider = api.CreateFrame("Slider", nil, pageResource, "OptionsSliderTemplate")
    powerSlider:SetPoint("TOPLEFT", pageResource, "TOPLEFT", 12, -225)
    powerSlider:SetMinMaxValues(0, 1)
    powerSlider:SetValueStep(0.01)
    powerSlider:SetObeyStepOnDrag(true)
    powerSlider:SetSize(280, 14)
    powerSlider:SetValue(PreviewPanel.simulatedPower)
    local pLabel = powerSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pLabel:SetPoint("BOTTOMLEFT", powerSlider, "TOPLEFT", 0, 3)
    pLabel:SetText(localized("EAM_PREVIEW_SIM_POWER", "模擬資源充能百分比:"))
    local pVal = powerSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pVal:SetPoint("BOTTOMRIGHT", powerSlider, "TOPRIGHT", 0, 3)
    pVal:SetText(string.format("%d%%", math.floor(PreviewPanel.simulatedPower * 100)))

    powerSlider:SetScript("OnValueChanged", function(self, val)
        PreviewPanel.simulatedPower = val
        pVal:SetText(string.format("%d%%", math.floor(val * 100)))
        PreviewPanel.refreshResourcePreview()
    end)

    -- =========================================================================
    -- 【Tab 3: 角色屬性預覽 (Player Stat Preview)】
    -- =========================================================================
    local pageStat = tabPages[3]

    local statCanvas = api.CreateFrame("Frame", nil, pageStat, "BackdropTemplate")
    statCanvas:SetSize(290, 200)
    statCanvas:SetPoint("TOP", pageStat, "TOP", 0, -4)
    statCanvas:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    statCanvas:SetBackdropColor(0.02, 0.02, 0.03, 0.9)
    statCanvas:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.8)

    local statBox = api.CreateFrame("Frame", nil, statCanvas)
    statBox:SetSize(120, 60)
    statBox:SetPoint("CENTER", statCanvas, "CENTER", 0, 0)

    local sIcon = statBox:CreateTexture(nil, "ARTWORK")
    sIcon:SetSize(36, 36)
    sIcon:SetPoint("LEFT", statBox, "LEFT", 0, 0)
    sIcon:SetTexture(132223) -- Crit icon
    sIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    statBox.icon = sIcon

    local sBorder = statBox:CreateTexture(nil, "OVERLAY")
    sBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    sBorder:SetBlendMode("ADD")
    sBorder:SetPoint("TOPLEFT", sIcon, "TOPLEFT", -4, 4)
    sBorder:SetPoint("BOTTOMRIGHT", sIcon, "BOTTOMRIGHT", 4, -4)
    sBorder:SetVertexColor(1, 0.15, 0.15, 1)
    sBorder:Hide()
    statBox.border = sBorder

    local sLabel = statBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sLabel:SetPoint("LEFT", sIcon, "RIGHT", 8, 8)
    sLabel:SetText(localized("EAM_PREVIEW_SAMPLE_STAT", "致命"))
    statBox.label = sLabel

    local sVal = statBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sVal:SetPoint("LEFT", sIcon, "RIGHT", 8, -8)
    sVal:SetText("20.4%")
    sVal:SetTextColor(1.0, 0.82, 0.0, 1)
    statBox.val = sVal

    PreviewPanel.statBox = statBox

    local statHint = pageStat:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statHint:SetPoint("TOPLEFT", pageStat, "TOPLEFT", 12, -225)
    statHint:SetWidth(280)
    statHint:SetJustifyH("LEFT")
    statHint:SetText(localized("EAM_PREVIEW_STAT_HINT", "此處即時連動屬性面板中當前選中屬性之圖示、字型大小、小數位數與警戒邊框。"))

    selectTab(1)
    PreviewPanel.frame = frame
    return frame
end

function PreviewPanel.refreshAlertPreview()
    if not PreviewPanel.alertIcon then return end
    local ai = PreviewPanel.alertIcon
    local db = EAM.db and EAM.db.config

    local iconSize = (db and db.iconSize) or 56
    ai:SetSize(iconSize, iconSize)

    -- 字型大小與路徑套用
    local fontSizeTimer = (db and db.fontSizeTimer) or 22
    local fontSizeName = (db and db.fontSizeName) or 12
    local fontSizeStack = (db and db.fontSizeStack) or 14
    local fontFamily = db and db.fontFamily

    if EAM.UI.TextPlacement and EAM.UI.TextPlacement.applyFont then
        EAM.UI.TextPlacement.applyFont(ai.timerText, fontSizeTimer, fontFamily)
        EAM.UI.TextPlacement.applyFont(ai.nameText, fontSizeName, fontFamily)
        EAM.UI.TextPlacement.applyFont(ai.stackText, fontSizeStack, fontFamily)
    end

    -- 法術名稱位置
    ai.nameText:ClearAllPoints()
    if db and db.nameInside then
        ai.nameText:SetPoint("TOP", ai, "TOP", 0, -2)
    else
        ai.nameText:SetPoint("BOTTOM", ai, "TOP", 0, 4)
    end

    -- 顏色曲線與剩餘時間連動
    local timeLeft = PreviewPanel.simulatedTime
    if timeLeft < 3.05 then
        ai.timerText:SetText(string.format("%.1f", timeLeft))
    else
        ai.timerText:SetText(string.format("%d", math.ceil(timeLeft)))
    end

    local colorToApply = { 1, 1, 1, 1 }
    local tcc = db and db.timerColorCurve
    if tcc and tcc.normalColor then
        colorToApply = tcc.normalColor
    end
    if tcc and tcc.enabled and type(tcc.stages) == "table" then
        for i = 1, #tcc.stages do
            local stage = tcc.stages[i]
            if stage and stage.threshold and timeLeft <= stage.threshold then
                colorToApply = stage.color or colorToApply
                break
            end
        end
    end
    ai.timerText:SetTextColor(colorToApply[1] or 1, colorToApply[2] or 1, colorToApply[3] or 1, colorToApply[4] or 1)

    -- 發光與 Pandemic
    if PreviewPanel.simulatedProc then
        ai.glow:Show()
    else
        ai.glow:Hide()
    end

    if PreviewPanel.simulatedPandemic then
        ai.pandemic:Show()
    else
        ai.pandemic:Hide()
    end
end

function PreviewPanel.refreshResourcePreview()
    if not PreviewPanel.resContainer then return end
    local rc = PreviewPanel.resContainer
    local draft = EAM.UI.PlayerResourcePanel and EAM.UI.PlayerResourcePanel.draft
    local dbRes = draft or (EAM.db and EAM.db.playerResources and EAM.db.playerResources.energy) or {}

    local isVertical = dbRes.orientation == "VERTICAL"
    local barWidth = Util.isSafePositiveNumber(dbRes.barWidth) and dbRes.barWidth or 126
    local barHeight = Util.isSafePositiveNumber(dbRes.barHeight) and dbRes.barHeight or 16
    local iconSize = Util.isSafePositiveNumber(dbRes.iconSize) and dbRes.iconSize or 30
    local spacing = Util.isSafeNonNegativeNumber(dbRes.spacing) and dbRes.spacing or 6

    local actualWidth = isVertical and barHeight or barWidth
    local actualHeight = isVertical and barWidth or barHeight

    rc.icon:SetSize(iconSize, iconSize)
    rc.statusBar:SetSize(actualWidth, actualHeight)
    rc.statusBar:SetValue(PreviewPanel.simulatedPower)

    pcall(function()
        if rc.statusBar.SetOrientation then
            rc.statusBar:SetOrientation(isVertical and "VERTICAL" or "HORIZONTAL")
        end
        if rc.statusBar.SetRotatesTexture then
            rc.statusBar:SetRotatesTexture(isVertical)
        end
    end)

    rc.icon:ClearAllPoints()
    rc.statusBar:ClearAllPoints()
    rc.label:ClearAllPoints()

    if isVertical then
        rc:SetSize(math.max(iconSize, actualWidth + 24), iconSize + spacing + actualHeight + 16)
        rc.icon:SetPoint("BOTTOM", rc, "BOTTOM", 0, 0)
        rc.statusBar:SetPoint("BOTTOM", rc.icon, "TOP", 0, spacing)
        rc.label:SetPoint("BOTTOM", rc.statusBar, "TOP", 0, 2)
    else
        rc:SetSize(iconSize + spacing + actualWidth, math.max(iconSize, actualHeight + 16))
        rc.icon:SetPoint("LEFT", rc, "LEFT", 0, 0)
        rc.statusBar:SetPoint("LEFT", rc.icon, "RIGHT", spacing, 0)
        rc.label:SetPoint("BOTTOMLEFT", rc.statusBar, "TOPLEFT", 0, 2)
    end

    local pct = math.floor(PreviewPanel.simulatedPower * 100)
    rc.valText:SetText(string.format("%d / 100 (%d%%)", pct, pct))
end

function PreviewPanel.refreshStatPreview()
    if not PreviewPanel.statBox then return end
    local sb = PreviewPanel.statBox
    local statPanel = EAM.UI.PlayerStatPanel
    local selectedKey = (statPanel and statPanel.selectedKey) or "crit"

    local statsTable = (EAM.db and EAM.db.playerStats) or {}
    local cfg = statsTable[selectedKey] or {}

    local iconSize = cfg.iconSize or 36
    sb.icon:SetSize(iconSize, iconSize)

    local customIcon = cfg.customIcon
    if customIcon and customIcon ~= "" then
        local num = tonumber(customIcon)
        sb.icon:SetTexture(num or customIcon)
    else
        local pService = EAM.Services and EAM.Services.PlayerStatService
        local defIcon = pService and pService.getStatIcon and pService.getStatIcon(selectedKey) or 132223
        sb.icon:SetTexture(defIcon)
    end

    local customLabel = (cfg.customLabel and cfg.customLabel ~= "") and cfg.customLabel
    local defName = (EAM.L and EAM.L["EAM_STAT_" .. string.upper(selectedKey)]) or selectedKey
    sb.label:SetText(customLabel or defName)

    local decimals = cfg.decimals or 1
    local valFormat = "%." .. decimals .. "f%%"
    sb.val:SetText(string.format(valFormat, 20.4))

    if cfg.showIcon == false then
        sb.icon:Hide()
        sb.label:ClearAllPoints()
        sb.label:SetPoint("CENTER", sb, "CENTER", 0, 8)
        sb.val:ClearAllPoints()
        sb.val:SetPoint("TOP", sb.label, "BOTTOM", 0, -4)
    else
        sb.icon:Show()
        sb.label:ClearAllPoints()
        sb.label:SetPoint("LEFT", sb.icon, "RIGHT", 8, 8)
        sb.val:ClearAllPoints()
        sb.val:SetPoint("LEFT", sb.icon, "RIGHT", 8, -8)
    end
end

function PreviewPanel.refresh()
    if not PreviewPanel.frame or not PreviewPanel.frame:IsShown() then return end
    if PreviewPanel.currentTab == 1 then
        PreviewPanel.refreshAlertPreview()
    elseif PreviewPanel.currentTab == 2 then
        PreviewPanel.refreshResourcePreview()
    elseif PreviewPanel.currentTab == 3 then
        PreviewPanel.refreshStatPreview()
    end
end

function PreviewPanel.show()
    local f = createFrame()
    if f then
        f:Show()
        PreviewPanel.refresh()
    end
end

function PreviewPanel.hide()
    if PreviewPanel.frame then
        PreviewPanel.frame:Hide()
    end
end

function PreviewPanel.toggle()
    if PreviewPanel.frame and PreviewPanel.frame:IsShown() then
        PreviewPanel.hide()
    else
        PreviewPanel.show()
    end
end
