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

local function readField(object, name)
    if not object then return nil end
    local ok, value = pcall(function() return object[name] end)
    if ok then return value end
    return nil
end

local function safeCall(object, name, ...)
    local method = readField(object, name)
    if type(method) == "function" then
        return pcall(method, object, ...)
    end
    return false
end

local function createFrame()
    if PreviewPanel.frame then return PreviewPanel.frame end

    local parent = _G.UIParent
    if not parent then return nil end

    local frame = api.CreateFrame("Frame", "EAM_PreviewOptionsFrame", parent, "BackdropTemplate")
    safeCall(frame, "SetFrameStrata", "DIALOG")
    safeCall(frame, "SetSize", 330, 420)
    safeCall(frame, "SetPoint", "CENTER", parent, "CENTER", 280, 50)
    safeCall(frame, "SetBackdrop", {
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 24, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 }
    })
    safeCall(frame, "SetBackdropColor", 0.06, 0.06, 0.09, 0.96)
    safeCall(frame, "SetBackdropBorderColor", 0.85, 0.70, 0.35, 1)
    if Theme and Theme.registerFrame then Theme.registerFrame(frame, "window") end

    safeCall(frame, "SetMovable", true)
    safeCall(frame, "EnableMouse", true)
    safeCall(frame, "RegisterForDrag", "LeftButton")
    safeCall(frame, "SetScript", "OnDragStart", function(self) safeCall(self, "StartMoving") end)
    safeCall(frame, "SetScript", "OnDragStop", function(self) safeCall(self, "StopMovingOrSizing") end)
    safeCall(frame, "SetClampedToScreen", true)

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

    -- 診斷報告按鈕
    local diagBtn = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    diagBtn:SetSize(62, 22)
    diagBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    diagBtn:SetText(localized("EAM_DIAG_BTN_SHORT", "診斷報告"))
    if Theme and Theme.registerButton then Theme.registerButton(diagBtn) end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(diagBtn, localized("EAM_DIAG_BTN_TOOLTIP", "採集並開啟外掛目前運行狀態之診斷報告，方便一鍵複製回報"), localized("EAM_DIAG_TITLE", "系統診斷報告"))
    end
    diagBtn:SetScript("OnClick", function()
        PreviewPanel.showDiagnosticDialog()
    end)

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

    -- 倒數扇形轉圈 Cooldown 框架 (即時預覽扇形倒數轉圈)
    local cooldown = api.CreateFrame("Cooldown", nil, alertIcon, "CooldownFrameTemplate")
    cooldown:SetAllPoints(alertIcon)
    cooldown:SetReverse(true)
    cooldown:SetDrawEdge(true)
    cooldown:SetDrawSwipe(true)
    alertIcon.cooldown = cooldown

    -- 高層級裝飾與文字容器 (確保文字與外框置於扇形陰影之上)
    local overlay = api.CreateFrame("Frame", nil, alertIcon)
    overlay:SetAllPoints(alertIcon)
    alertIcon.overlay = overlay

    -- 外框邊框 (Border)
    local borderTex = overlay:CreateTexture(nil, "OVERLAY")
    borderTex:SetTexture("Interface\\AddOns\\EventAlertMod\\Images\\UI-Achievement-WoodBorder")
    borderTex:SetPoint("TOPLEFT", overlay, "TOPLEFT", -3, 3)
    borderTex:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 3, -3)
    borderTex:SetVertexColor(1, 0.82, 0, 1)
    alertIcon.border = borderTex

    -- 發光外框 (Proc Glow)
    local glowTex = overlay:CreateTexture(nil, "OVERLAY")
    glowTex:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glowTex:SetBlendMode("ADD")
    glowTex:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    glowTex:SetSize(40 * (64 / 36), 40 * (64 / 36))
    glowTex:SetVertexColor(1, 0.85, 0.2, 1)
    alertIcon.glow = glowTex

    -- 傳染紅綠亮框 (Pandemic Border)
    local pandemicBox = overlay:CreateTexture(nil, "OVERLAY")
    pandemicBox:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    pandemicBox:SetBlendMode("ADD")
    pandemicBox:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    pandemicBox:SetSize(40 * (64 / 36), 40 * (64 / 36))
    pandemicBox:SetVertexColor(0.2, 1.0, 0.3, 1)
    pandemicBox:Hide()
    alertIcon.pandemic = pandemicBox

    -- 法術名稱文字
    local nameText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("BOTTOM", overlay, "TOP", 0, 4)
    nameText:SetText(localized("EAM_PREVIEW_SAMPLE_SPELL", "烈焰震擊 (Flame Shock)"))
    alertIcon.nameText = nameText

    -- 倒數秒數文字
    local timerText = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    timerText:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    timerText:SetText("2.8")
    alertIcon.timerText = timerText

    -- 堆疊層數文字
    local stackText = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    stackText:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -2, 2)
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
    local timeVal = timeSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeVal:SetPoint("BOTTOMRIGHT", timeSlider, "TOPRIGHT", 0, 3)
    timeVal:SetJustifyH("RIGHT")
    timeVal:SetText(string.format("%.1fs", PreviewPanel.simulatedTime))
    local timeLabel = timeSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeLabel:SetPoint("BOTTOMLEFT", timeSlider, "TOPLEFT", 0, 3)
    timeLabel:SetPoint("RIGHT", timeVal, "LEFT", -4, 0)
    timeLabel:SetJustifyH("LEFT")
    timeLabel:SetWordWrap(false)
    timeLabel:SetText(localized("EAM_PREVIEW_SIM_TIME", "模擬剩餘秒數 (測試文字變色):"))

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
    local pVal = powerSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pVal:SetPoint("BOTTOMRIGHT", powerSlider, "TOPRIGHT", 0, 3)
    pVal:SetJustifyH("RIGHT")
    pVal:SetText(string.format("%d%%", math.floor(PreviewPanel.simulatedPower * 100)))
    local pLabel = powerSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pLabel:SetPoint("BOTTOMLEFT", powerSlider, "TOPLEFT", 0, 3)
    pLabel:SetPoint("RIGHT", pVal, "LEFT", -4, 0)
    pLabel:SetJustifyH("LEFT")
    pLabel:SetWordWrap(false)
    pLabel:SetText(localized("EAM_PREVIEW_SIM_POWER", "模擬資源充能百分比:"))

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
    local host = ai.overlay or ai

    local iconSize = (db and db.iconSize) or 56
    ai:SetSize(iconSize, iconSize)
    ai:SetAlpha((db and db.iconAlpha) or 1.0)

    -- 字型大小與路徑套用 (修正歷史欄位名 fontSizeTimer -> fontSizeTimeVal, fontSizeName -> fontSizeSpellName)
    local TextPlacement = EAM.UI.TextPlacement
    local fontSizeTimer = (db and db.fontSizeTimeVal)
        or (TextPlacement and TextPlacement.getFontSize and TextPlacement.getFontSize(db, "timer"))
        or 22
    local fontSizeName = (TextPlacement and TextPlacement.getFontSize and TextPlacement.getFontSize(db, "spellName"))
        or (db and db.fontSizeSpellName)
        or 12
    local fontSizeStack = (db and db.fontSizeStack)
        or (TextPlacement and TextPlacement.getFontSize and TextPlacement.getFontSize(db, "applications"))
        or 14
    local fontFamily = db and db.fontFamily

    if TextPlacement and TextPlacement.applyFont then
        TextPlacement.applyFont(ai.timerText, fontSizeTimer, fontFamily)
        TextPlacement.applyFont(ai.nameText, fontSizeName, fontFamily)
        TextPlacement.applyFont(ai.stackText, fontSizeStack, fontFamily)
    end

    if TextPlacement and TextPlacement.applyColor and TextPlacement.getColor then
        local appColor = TextPlacement.getColor(db, "applications")
        local spellNameColor = TextPlacement.getColor(db, "spellName")
        TextPlacement.applyColor(ai.stackText, appColor)
        TextPlacement.applyColor(ai.nameText, spellNameColor)
    end

    -- 文字位置排版 (套用 21 種錨點契約)
    if TextPlacement and TextPlacement.apply and TextPlacement.getPlacement then
        local timerPlacement = TextPlacement.getPlacement(db, "timer")
        TextPlacement.apply(ai.timerText, host, timerPlacement)
        local appPlacement = TextPlacement.getPlacement(db, "applications")
        TextPlacement.apply(ai.stackText, host, appPlacement)
        local spellNamePlacement = TextPlacement.getPlacement(db, "spellName") or "OUTSIDE_BOTTOM"
        TextPlacement.apply(ai.nameText, host, spellNamePlacement)
    else
        -- 法術名稱位置預設在圖示下方 (Fallback)
        if ai.nameText then
            safeCall(ai.nameText, "ClearAllPoints")
            if db and db.nameInside then
                safeCall(ai.nameText, "SetPoint", "BOTTOM", host, "BOTTOM", 0, 2)
            else
                safeCall(ai.nameText, "SetPoint", "TOP", host, "BOTTOM", 0, -2)
            end
        end
    end

    -- 顯隱控制即時連動
    if ai.nameText then
        if db and db.showSpellName == false then
            safeCall(ai.nameText, "Hide")
        else
            safeCall(ai.nameText, "Show")
        end
    end

    if ai.timerText then
        if db and db.showTimeVal == false then
            safeCall(ai.timerText, "Hide")
        else
            safeCall(ai.timerText, "Show")
        end
    end

    -- 扇形倒數轉圈 (Cooldown) 與陰影透明度 / 顏色
    if ai.cooldown then
        local shadowEnabled = (db and db.cooldownShadow ~= false)
        if shadowEnabled then
            local swipeAlpha = (db and db.cooldownSwipeAlpha)
            if swipeAlpha == nil then swipeAlpha = 0.8 end
            local swipeColor = (db and db.cooldownSwipeColor) or { r = 0, g = 0, b = 0 }
            safeCall(ai.cooldown, "SetSwipeColor", swipeColor.r or 0, swipeColor.g or 0, swipeColor.b or 0, swipeAlpha)
            local totalDur = 10
            local now = (api.GetTime and api.GetTime()) or 0
            local start = now - (totalDur - PreviewPanel.simulatedTime)
            safeCall(ai.cooldown, "SetCooldown", start, totalDur)
            safeCall(ai.cooldown, "Show")
        else
            safeCall(ai.cooldown, "Hide")
        end
    end

    -- 顏色曲線與剩餘時間連動
    local timeLeft = PreviewPanel.simulatedTime or 0
    if ai.timerText then
        if timeLeft < 3.05 then
            safeCall(ai.timerText, "SetText", string.format("%.1f", timeLeft))
        else
            safeCall(ai.timerText, "SetText", string.format("%d", math.ceil(timeLeft)))
        end

        local colorToApply = (TextPlacement and TextPlacement.getColor and TextPlacement.getColor(db, "timer")) or { 1, 1, 1, 1 }
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
        safeCall(ai.timerText, "SetTextColor", colorToApply[1] or 1, colorToApply[2] or 1, colorToApply[3] or 1, colorToApply[4] or 1)
    end

    -- 發光與 Pandemic
    if ai.glow then
        if PreviewPanel.simulatedProc then
            safeCall(ai.glow, "Show")
        else
            safeCall(ai.glow, "Hide")
        end
    end

    if ai.pandemic then
        if PreviewPanel.simulatedPandemic then
            safeCall(ai.pandemic, "Show")
        else
            safeCall(ai.pandemic, "Hide")
        end
    end
end

function PreviewPanel.refreshResourcePreview()
    if not PreviewPanel.resContainer then return end
    local rc = PreviewPanel.resContainer
    local resPanel = EAM.UI.PlayerResourcePanel
    local selectedKey = (resPanel and resPanel.selectedKey) or "energy"
    local draft = resPanel and resPanel.draft
    local dbRes = draft
    if not dbRes then
        local saved = EAM.Modules and EAM.Modules.SavedVariables
        if saved and saved.getPlayerResourceConfig then
            local cfg = saved.getPlayerResourceConfig(selectedKey)
            if type(cfg) == "table" then
                dbRes = cfg
            end
        end
    end
    if not dbRes then
        local pr = EAM.db and EAM.db.playerResources
        dbRes = (pr and (pr[selectedKey] or pr[string.lower(selectedKey)] or pr.energy)) or {}
    end

    -- 動態資源圖示與名稱
    local pService = EAM.Services and EAM.Services.PlayerResourceService
    local resInfo = pService and pService.getResourceDefinition and pService.getResourceDefinition(selectedKey)
    local iconTex = (resInfo and resInfo.icon) or 136080
    rc.icon:SetTexture(iconTex)
    local resLabel = (EAM.L and EAM.L["EAM_RESOURCE_" .. string.upper(selectedKey)]) or (resInfo and resInfo.name) or selectedKey
    rc.label:SetText(resLabel)

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

    -- 字型大小與字型族系
    local fontSize = Util.isSafePositiveNumber(dbRes.fontSize) and dbRes.fontSize or 11
    local valueFontSize = Util.isSafePositiveNumber(dbRes.valueFontSize) and dbRes.valueFontSize or 12
    local fontFamily = dbRes.fontFamily or (EAM.db and EAM.db.config and EAM.db.config.fontFamily)
    local TextPlacement = EAM.UI.TextPlacement
    if TextPlacement and TextPlacement.applyFont then
        TextPlacement.applyFont(rc.label, fontSize, fontFamily)
        TextPlacement.applyFont(rc.valText, valueFontSize, fontFamily)
    end

    -- 縮放與透明度
    local scale = Util.isSafePositiveNumber(dbRes.scale) and dbRes.scale or 1.0
    rc:SetScale(scale)
    local overallAlpha = Util.isSafePositiveNumber(dbRes.alpha) and dbRes.alpha or 1.0
    rc:SetAlpha(overallAlpha)
    local fgAlpha = Util.isSafePositiveNumber(dbRes.foregroundAlpha) and dbRes.foregroundAlpha or 1.0
    rc.statusBar:SetAlpha(fgAlpha)
    local bgAlpha = Util.isSafePositiveNumber(dbRes.backgroundAlpha) and dbRes.backgroundAlpha or 0.6
    rc.bg:SetAlpha(bgAlpha)

    if dbRes.showBackground == false then
        rc.bg:Hide()
    else
        rc.bg:Show()
    end

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
    rc.valText:ClearAllPoints()

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

    local valOffsetX = tonumber(dbRes.valueOffsetX) or 0
    local valOffsetY = tonumber(dbRes.valueOffsetY) or 0
    rc.valText:SetPoint("CENTER", rc.statusBar, "CENTER", valOffsetX, valOffsetY)

    local showValue = dbRes.showValue ~= false
    local showPercent = dbRes.showPercent ~= false
    local pct = math.floor(PreviewPanel.simulatedPower * 100)
    if showValue and showPercent then
        rc.valText:SetText(string.format("%d / 100 (%d%%)", pct, pct))
        rc.valText:Show()
    elseif showValue then
        rc.valText:SetText(string.format("%d / 100", pct))
        rc.valText:Show()
    elseif showPercent then
        rc.valText:SetText(string.format("%d%%", pct))
        rc.valText:Show()
    else
        rc.valText:Hide()
    end
end

function PreviewPanel.refreshStatPreview()
    if not PreviewPanel.statBox then return end
    local sb = PreviewPanel.statBox
    local statPanel = EAM.UI.PlayerStatPanel
    local selectedKey = (statPanel and statPanel.selectedKey) or "crit"

    local pService = EAM.Services and EAM.Services.PlayerStatService
    local statsTable = nil
    if pService and pService.getPlayerStatsConfig then
        statsTable = pService.getPlayerStatsConfig()
    elseif EAM.Services and EAM.Services.PlayerStatService and EAM.Services.PlayerStatService.getPlayerStatsConfig then
        statsTable = EAM.Services.PlayerStatService.getPlayerStatsConfig()
    end
    if not statsTable then
        statsTable = (EAM.db and EAM.db.playerStats) or {}
    end
    local cfg = statsTable[selectedKey] or {}

    local iconSize = cfg.iconSize or 36
    sb.icon:SetSize(iconSize, iconSize)

    local customIcon = cfg.customIcon
    if customIcon and customIcon ~= "" then
        local num = tonumber(customIcon)
        sb.icon:SetTexture(num or customIcon)
    else
        local defIcon = pService and pService.getStatIcon and pService.getStatIcon(selectedKey) or 132223
        sb.icon:SetTexture(defIcon)
    end

    local customLabel = (cfg.customLabel and cfg.customLabel ~= "") and cfg.customLabel
    local defName = (EAM.L and EAM.L["EAM_STAT_" .. string.upper(selectedKey)]) or selectedKey
    sb.label:SetText(customLabel or defName)

    -- 字型大小與字型族系
    local fontLabelSize = cfg.fontSizeLabel or 12
    local fontValSize = cfg.fontSizeValue or 16
    local fontFamily = cfg.fontFamily or (EAM.db and EAM.db.config and EAM.db.config.fontFamily)
    local TextPlacement = EAM.UI.TextPlacement
    if TextPlacement and TextPlacement.applyFont then
        TextPlacement.applyFont(sb.label, fontLabelSize, fontFamily)
        TextPlacement.applyFont(sb.val, fontValSize, fontFamily)
    end

    local decimals = cfg.decimals or 1
    local valFormat = "%." .. decimals .. "f%%"
    local sampleVal = 20.4
    sb.val:SetText(string.format(valFormat, sampleVal))

    -- 數值位置排版 (valuePlacement: "RIGHT", "BELOW", "INSIDE", "TOP")
    local valPlacement = cfg.valuePlacement or "RIGHT"
    sb.icon:ClearAllPoints()
    sb.label:ClearAllPoints()
    sb.val:ClearAllPoints()

    if cfg.showIcon == false then
        sb.icon:Hide()
        sb.label:SetPoint("TOP", sb, "TOP", 0, -4)
        sb.val:SetPoint("TOP", sb.label, "BOTTOM", 0, -4)
    else
        sb.icon:Show()
        sb.icon:SetPoint("LEFT", sb, "LEFT", 0, 0)
        if valPlacement == "BELOW" then
            sb.label:SetPoint("LEFT", sb.icon, "RIGHT", 8, 8)
            sb.val:SetPoint("TOPLEFT", sb.label, "BOTTOMLEFT", 0, -4)
        elseif valPlacement == "INSIDE" then
            sb.label:SetPoint("TOP", sb.icon, "BOTTOM", 0, -2)
            sb.val:SetPoint("CENTER", sb.icon, "CENTER", 0, 0)
        elseif valPlacement == "TOP" then
            sb.label:SetPoint("BOTTOM", sb.icon, "TOP", 0, 2)
            sb.val:SetPoint("LEFT", sb.icon, "RIGHT", 8, 0)
        else -- "RIGHT"
            sb.label:SetPoint("LEFT", sb.icon, "RIGHT", 8, 8)
            sb.val:SetPoint("LEFT", sb.icon, "RIGHT", 8, -8)
        end
    end

    -- 警戒門檻紅框連動 (相容 thresholdMin / minThreshold, thresholdMax / maxThreshold)
    local minThresh = tonumber(cfg.thresholdMin or cfg.minThreshold)
    local maxThresh = tonumber(cfg.thresholdMax or cfg.maxThreshold)
    local isAlert = false
    if minThresh and sampleVal < minThresh then
        isAlert = true
    elseif maxThresh and sampleVal > maxThresh then
        isAlert = true
    end
    if isAlert and sb.border then
        sb.border:Show()
    elseif sb.border then
        sb.border:Hide()
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

function PreviewPanel.show(targetTab)
    local f = createFrame()
    if f then
        f:Show()
        if targetTab then
            PreviewPanel.selectTab(targetTab)
        else
            PreviewPanel.refresh()
        end
    end
end

function PreviewPanel.hide()
    if PreviewPanel.frame then
        PreviewPanel.frame:Hide()
    end
end

function PreviewPanel.toggle(targetTab)
    local f = createFrame()
    if not f then return end
    if f:IsShown() then
        if targetTab and PreviewPanel.currentTab ~= targetTab then
            PreviewPanel.selectTab(targetTab)
            return
        end
        PreviewPanel.hide()
    else
        PreviewPanel.show(targetTab)
    end
end

-- =========================================================================
-- 【系統診斷報告 (EAM Diagnostic Report System)】
-- =========================================================================
function PreviewPanel.generateDiagnosticReport()
    local lines = {}
    local function add(text)
        table.insert(lines, text or "")
    end

    local curTime = (api.date and api.date("%Y-%m-%d %H:%M:%S")) or "N/A"
    local buildVersion, buildNumber, buildDate, tocVersion = "N/A", "N/A", "N/A", "N/A"
    if api.GetBuildInfo then
        buildVersion, buildNumber, buildDate, tocVersion = api.GetBuildInfo()
    end
    local addonVersion = "Alpha 8.6"
    if api.GetAddOnMetadata then
        addonVersion = api.GetAddOnMetadata("EventAlertMod", "Version") or addonVersion
    end
    local locale = (api.GetLocale and api.GetLocale()) or "unknown"
    local inCombat = (api.InCombatLockdown and api.InCombatLockdown()) and "YES (戰鬥中)" or "NO (非戰鬥)"

    local className, classToken, classId = "N/A", "N/A", "N/A"
    if api.UnitClass then
        className, classToken, classId = api.UnitClass("player")
    end
    local specIndex = (api.GetSpecialization and api.GetSpecialization()) or 0
    local specId, specName = "N/A", "None"
    if specIndex > 0 and api.GetSpecializationInfo then
        specId, specName = api.GetSpecializationInfo(specIndex)
    end

    add("======================================================================")
    add("EventAlertMod (EAM) 系統即時診斷報告")
    add("產出時間: " .. curTime)
    add("======================================================================")
    add("")
    add("[1. 遊戲客戶端與外掛環境]")
    add("  - EAM 版本: " .. tostring(addonVersion))
    add("  - WoW 客戶端: " .. tostring(buildVersion) .. " (Build " .. tostring(buildNumber) .. ", TOC " .. tostring(tocVersion) .. ")")
    add("  - 遊戲語系: " .. tostring(locale))
    add("  - 戰鬥狀態: " .. inCombat)
    add("  - 當前角色: " .. tostring(className) .. " (" .. tostring(classToken) .. "), 專精: " .. tostring(specName) .. " [ID: " .. tostring(specId) .. "]")
    add("")

    -- 2. 預覽系統狀態
    local isShown = (PreviewPanel.frame and PreviewPanel.frame:IsShown()) and "已開啟 (Shown)" or "隱藏中 (Hidden)"
    local tabTitle = "Tab 1: 告警圖示"
    if PreviewPanel.currentTab == 2 then
        tabTitle = "Tab 2: 職業資源"
    elseif PreviewPanel.currentTab == 3 then
        tabTitle = "Tab 3: 角色屬性"
    end
    add("[2. 預覽系統狀態 (Preview System)]")
    add("  - 預覽視窗狀態: " .. isShown)
    add("  - 當前分頁: " .. tabTitle)
    add("  - 模擬秒數: " .. string.format("%.1fs", PreviewPanel.simulatedTime or 0))
    add("  - 模擬觸發(Proc): " .. tostring(PreviewPanel.simulatedProc))
    add("  - 模擬能量(Power): " .. string.format("%d%%", math.floor((PreviewPanel.simulatedPower or 0) * 100)))

    -- 資源面板狀態
    local resPanel = EAM.UI.PlayerResourcePanel
    if resPanel then
        local selKey = resPanel.selectedKey or "none"
        local scope = resPanel.scope or "class"
        add("  - 資源面板選中項: " .. tostring(selKey) .. " (範圍: " .. tostring(scope) .. ")")
        if resPanel.draft then
            local d = resPanel.draft
            add(string.format("  - 資源即時 Draft: [啟用:%s, 模式:%s, 方向:%s, 錨點:%s, 定位:%s, 尺寸:%dx%d, 縮放:%.2f, 透明:%.2f]",
                tostring(d.enabled), tostring(d.displayMode), tostring(d.orientation),
                tostring(d.anchor), tostring(d.position),
                tonumber(d.barWidth) or 0, tonumber(d.barHeight) or 0,
                tonumber(d.scale) or 1, tonumber(d.alpha) or 1))
        else
            add("  - 資源即時 Draft: 無 (未編輯或未載入)")
        end
    end

    -- 屬性面板狀態
    local statPanel = EAM.UI.PlayerStatPanel
    if statPanel then
        add("  - 屬性面板選中項: " .. tostring(statPanel.selectedKey or "none") .. " (分頁: " .. tostring(statPanel.currentTab or 1) .. ")")
    end
    add("")

    -- 3. 核心模組與服務運行檢測
    add("[3. 核心模組與服務狀態]")
    local alertMgr = EAM.AlertManager or (EAM.Services and EAM.Services.AlertManager)
    local alertCount = 0
    if alertMgr and alertMgr.getActiveAlertCount then
        alertCount = alertMgr.getActiveAlertCount()
    end
    add("  - AlertManager: " .. (alertMgr and "正常載入" or "未載入") .. " (當前活躍告警數: " .. tostring(alertCount) .. ")")

    local resService = EAM.Services and EAM.Services.PlayerResourceService
    local resActiveCount = 0
    if resService and resService.getActiveResourceCount then
        resActiveCount = resService.getActiveResourceCount()
    end
    add("  - PlayerResourceService: " .. (resService and "正常載入" or "未載入") .. " (活躍資源條: " .. tostring(resActiveCount) .. ")")

    local statService = EAM.Services and EAM.Services.PlayerStatService
    local statActiveCount = 0
    if statService and statService.getActiveStatCount then
        statActiveCount = statService.getActiveStatCount()
    end
    add("  - PlayerStatService: " .. (statService and "正常載入" or "未載入") .. " (活躍屬性條目: " .. tostring(statActiveCount) .. ")")

    local cdmHost = EAM.Services and EAM.Services.CDMShadowHost
    add("  - CooldownViewer (CDM 影子載體): " .. (cdmHost and (cdmHost.isHooked and cdmHost.isHooked() and "已成功 Hook 攔截" or "已載入") or "未啟用"))

    local lsm = EAM.Services and EAM.Services.MediaService
    local fontCount = 0
    if lsm and lsm.getMediaList then
        local fl = lsm.getMediaList("font")
        fontCount = fl and #fl or 0
    end
    add("  - SharedMedia (LSM): " .. (fontCount > 0 and ("已啟用 (可用字型: " .. fontCount .. " 種)") or "未啟用或使用內建預設"))
    add("")

    -- 4. 記憶體與效能指標
    add("[4. 記憶體與效能監控]")
    local memKb = (collectgarbage and collectgarbage("count")) or 0
    add(string.format("  - Lua 記憶體使用量: %.2f MB (%.1f KB)", memKb / 1024, memKb))
    if api.GetFramerate then
        add(string.format("  - 即時遊戲 FPS: %.1f", api.GetFramerate()))
    end
    if api.GetNetStats then
        local down, up, lagHome, lagWorld = api.GetNetStats()
        add(string.format("  - 網路延遲: 本地 %d ms / 世界 %d ms (頻寬: 下行 %.1f KB/s, 上行 %.1f KB/s)", lagHome or 0, lagWorld or 0, down or 0, up or 0))
    end
    add("")

    -- 5. 資料庫一致性檢驗
    add("[5. 資料庫設定狀態 (Database Check)]")
    local db = EAM.db
    if db then
        add("  - EAM.db: 正常載入")
        add("  - 設定檔版本: " .. tostring(db.version or "N/A"))
        local alertDb = db.alerts and (type(db.alerts) == "table" and "存在" or "無效") or "未初始化"
        add("  - 告警法術庫 (alerts): " .. alertDb)
        local resDb = db.playerResources and (type(db.playerResources) == "table" and "存在" or "無效") or "未初始化"
        add("  - 資源設定庫 (playerResources): " .. resDb)
        local statDb = db.playerStats and (type(db.playerStats) == "table" and "存在" or "無效") or "未初始化"
        add("  - 屬性設定庫 (playerStats): " .. statDb)
    else
        add("  - EAM.db: 【警告】尚未載入或為 nil！")
    end
    add("======================================================================")
    add("診斷報告採集完畢。您可以直接按下 Ctrl+C 複製整段報告提供給開發團隊。")
    add("======================================================================")

    return table.concat(lines, "\n")
end

local diagFrame = nil
function PreviewPanel.showDiagnosticDialog()
    if not diagFrame then
        local parent = _G.UIParent or PreviewPanel.frame
        diagFrame = api.CreateFrame("Frame", "EAM_DiagnosticReportDialog", parent, "BackdropTemplate")
        diagFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        diagFrame:SetSize(680, 520)
        diagFrame:SetPoint("CENTER", parent, "CENTER", 0, 0)
        diagFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 24, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 }
        })
        diagFrame:SetBackdropColor(0.04, 0.04, 0.06, 0.98)
        diagFrame:SetBackdropBorderColor(0.85, 0.70, 0.35, 1)
        if Theme and Theme.registerFrame then Theme.registerFrame(diagFrame, "window") end

        diagFrame:SetMovable(true)
        diagFrame:EnableMouse(true)
        diagFrame:RegisterForDrag("LeftButton")
        diagFrame:SetScript("OnDragStart", function(self) safeCall(self, "StartMoving") end)
        diagFrame:SetScript("OnDragStop", function(self) safeCall(self, "StopMovingOrSizing") end)
        diagFrame:SetClampedToScreen(true)

        -- 標題
        local title = diagFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", diagFrame, "TOPLEFT", 16, -14)
        title:SetText(localized("EAM_DIAG_TITLE", "★ EventAlertMod 系統診斷報告 (Diagnostic Report)"))
        title:SetTextColor(1.0, 0.85, 0.2, 1)
        if Theme and Theme.registerText then Theme.registerText(title, "title") end

        -- 右上關閉按鈕
        local closeBtn = api.CreateFrame("Button", nil, diagFrame, "UIPanelCloseButton")
        closeBtn:SetSize(26, 26)
        closeBtn:SetPoint("TOPRIGHT", diagFrame, "TOPRIGHT", -6, -6)
        closeBtn:SetScript("OnClick", function() diagFrame:Hide() end)

        -- 提示標籤
        local desc = diagFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
        desc:SetText(localized("EAM_DIAG_DESC", "以下是外掛與環境即時狀態。點擊下方【一鍵全選複製】後按 Ctrl+C，即可貼給開發團隊進行排查。"))

        -- 滾動框容器
        local scrollContainer = api.CreateFrame("Frame", nil, diagFrame, "BackdropTemplate")
        scrollContainer:SetPoint("TOPLEFT", diagFrame, "TOPLEFT", 14, -64)
        scrollContainer:SetPoint("BOTTOMRIGHT", diagFrame, "BOTTOMRIGHT", -14, 52)
        scrollContainer:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 12, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        scrollContainer:SetBackdropColor(0.01, 0.01, 0.02, 0.95)
        scrollContainer:SetBackdropBorderColor(0.35, 0.35, 0.4, 0.8)

        local scrollFrame = api.CreateFrame("ScrollFrame", "EAM_DiagReportScrollFrame", scrollContainer, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 6, -6)
        scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -26, 6)

        local editBox = api.CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetMaxLetters(99999)
        editBox:EnableMouse(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("GameFontHighlightSmall")
        editBox:SetWidth(610)
        editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus() end)
        scrollFrame:SetScrollChild(editBox)
        diagFrame.editBox = editBox

        -- 底部功能按鈕
        local copyBtn = api.CreateFrame("Button", nil, diagFrame, "UIPanelButtonTemplate")
        copyBtn:SetSize(130, 24)
        copyBtn:SetPoint("BOTTOMLEFT", diagFrame, "BOTTOMLEFT", 14, 14)
        copyBtn:SetText(localized("EAM_DIAG_COPY_ALL", "一鍵全選複製"))
        if Theme and Theme.registerButton then Theme.registerButton(copyBtn) end
        copyBtn:SetScript("OnClick", function()
            editBox:SetFocus()
            editBox:HighlightText()
            print("|cff00ff96EAM|r 診斷報告文字已全選，請按 |cffffff00Ctrl+C|r 進行複製！")
        end)

        local refreshBtn = api.CreateFrame("Button", nil, diagFrame, "UIPanelButtonTemplate")
        refreshBtn:SetSize(110, 24)
        refreshBtn:SetPoint("LEFT", copyBtn, "RIGHT", 10, 0)
        refreshBtn:SetText(localized("EAM_DIAG_REFRESH", "重新採集"))
        if Theme and Theme.registerButton then Theme.registerButton(refreshBtn) end
        refreshBtn:SetScript("OnClick", function()
            local text = PreviewPanel.generateDiagnosticReport()
            editBox:SetText(text)
            editBox:SetCursorPosition(0)
            print("|cff00ff96EAM|r 診斷報告已即時重新整理。")
        end)

        local closeBottomBtn = api.CreateFrame("Button", nil, diagFrame, "UIPanelButtonTemplate")
        closeBottomBtn:SetSize(80, 24)
        closeBottomBtn:SetPoint("BOTTOMRIGHT", diagFrame, "BOTTOMRIGHT", -14, 14)
        closeBottomBtn:SetText(localized("EAM_CLOSE", "關閉"))
        if Theme and Theme.registerButton then Theme.registerButton(closeBottomBtn) end
        closeBottomBtn:SetScript("OnClick", function() diagFrame:Hide() end)
    end

    local text = PreviewPanel.generateDiagnosticReport()
    diagFrame.editBox:SetText(text)
    diagFrame.editBox:SetCursorPosition(0)
    diagFrame:Show()
end

EAM.Diagnostics = EAM.Diagnostics or {}
EAM.Diagnostics.generateReport = PreviewPanel.generateDiagnosticReport
EAM.Diagnostics.showReportDialog = PreviewPanel.showDiagnosticDialog

-- 監聽全域字型、顏色曲線與文字版面事件，達成零延遲熱更新
if EAM.Modules and EAM.Modules.EventRouter and EAM.Modules.EventRouter.register then
    EAM.Modules.EventRouter.register("EAM_FONT_FAMILY_CHANGED", function()
        PreviewPanel.refresh()
    end)
    EAM.Modules.EventRouter.register("EAM_TIMER_COLOR_CHANGED", function()
        PreviewPanel.refresh()
    end)
    EAM.Modules.EventRouter.register("EAM_TEXT_LAYOUT_CHANGED", function()
        PreviewPanel.refresh()
    end)
end
