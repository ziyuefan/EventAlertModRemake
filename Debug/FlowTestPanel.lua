--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/FlowTestPanel
檔案: Debug\FlowTestPanel.lua

理念:
- 提供明確、按需的 Retail/PTR 流程驗證按鈕與可複製報告。
- 讓玩家在遊戲內產生結構化證據，再回灌到開發環境。

責任:
- 建立測試面板、觸發 FlowTestRunner suite、顯示摘要與 JSON。
- 戰鬥中延後首次開啟，避免結構性 UI 建立造成 taint 風險。

資料所有權:
- 擁有測試面板 widgets 與 pendingOpen。
- 不擁有測試案例、服務狀態或 SavedVariables schema。

邊界:
- 不讀 Aura/Cooldown facts，不修改 Blizzard protected frames。
- 不自動執行測試，不在戰鬥中建立或重建面板。

效能注意:
- UI lazy-initialize；測試與報告只在使用者觸發時產生。

Retail API 注意:
- 面板只做非 protected 顯示與複製；實機結果仍需記錄 build 與場景。
]]
local _, EAM = ...

local api = EAM.API or {}

local FlowTestPanel = {
    frame = nil,
    editBox = nil,
    statusText = nil,
    pendingOpen = false,
}

EAM.Debug.FlowTestPanel = FlowTestPanel

local function text(key, fallback)
    return EAM.L and EAM.L[key] or fallback
end

local function setStatus(message, isError)
    if FlowTestPanel.statusText then
        if isError then
            FlowTestPanel.statusText:SetTextColor(1.0, 0.25, 0.25, 1.0)
        else
            FlowTestPanel.statusText:SetTextColor(0.2, 1.0, 0.2, 1.0)
        end
        FlowTestPanel.statusText:SetText(message or "")
    end
end

local function showReport(reportJSON)
    if FlowTestPanel.editBox then
        FlowTestPanel.editBox:SetText(reportJSON or "{}")
        FlowTestPanel.editBox:SetCursorPosition(0)
    end
end

local function buildSummary(report)
    local summary = report and report.summary
    if not summary then
        return text("EAM_FLOW_STATUS_NO_REPORT", "尚無流程測試報告。")
    end

    return string.format(
        text("EAM_FLOW_STATUS_SUMMARY", "完成：通過 %d、失敗 %d、略過 %d。"),
        summary.passed or 0,
        summary.failed or 0,
        summary.skipped or 0
    )
end

local function createButton(parent, label, width, point, relativeTo, relativePoint, x, y, onClick)
    local button = api.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 26)
    button:SetPoint(point, relativeTo, relativePoint, x, y)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

local function createFrame()
    if FlowTestPanel.frame then
        return FlowTestPanel.frame
    end
    if not api.CreateFrame or not UIParent then
        return nil
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return nil
    end

    local frame = api.CreateFrame("Frame", "EAM_FlowTestFrame", UIParent, "BackdropTemplate")
    frame:SetSize(680, 520)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0.08, 0.06, 0.04, 0.98)
    frame:SetBackdropBorderColor(0.8, 0.6, 0.3, 1.0)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText(text("EAM_FLOW_PANEL_TITLE", "EAM 流程驗證與開發回灌"))

    local description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -44)
    description:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -44)
    description:SetJustifyH("LEFT")
    description:SetText(text(
        "EAM_FLOW_PANEL_DESC",
        "離線 Mock 與實機共用案例。Mock 通過不代表 Retail/PTR 實機通過。"
    ))

    local quickButton = createButton(
        frame,
        text("EAM_FLOW_BUTTON_QUICK", "快速流程"),
        110,
        "TOPLEFT",
        frame,
        "TOPLEFT",
        20,
        -74,
        function()
            FlowTestPanel.runSuite("quick")
        end
    )

    local coreButton = createButton(
        frame,
        text("EAM_FLOW_BUTTON_CORE", "核心流程"),
        110,
        "LEFT",
        quickButton,
        "RIGHT",
        8,
        0,
        function()
            FlowTestPanel.runSuite("core")
        end
    )

    local boundaryButton = createButton(
        frame,
        text("EAM_FLOW_BUTTON_BOUNDARY", "邊界流程"),
        110,
        "LEFT",
        coreButton,
        "RIGHT",
        8,
        0,
        function()
            FlowTestPanel.runSuite("boundary")
        end
    )

    local aura121Button = createButton(
        frame,
        text("EAM_FLOW_BUTTON_AURA121", "12.1 Aura"),
        110,
        "LEFT",
        boundaryButton,
        "RIGHT",
        8,
        0,
        function()
            FlowTestPanel.runSuite("aura121")
        end
    )

    createButton(
        frame,
        text("EAM_FLOW_BUTTON_ALL", "執行全部"),
        110,
        "LEFT",
        aura121Button,
        "RIGHT",
        8,
        0,
        function()
            FlowTestPanel.runSuite("all")
        end
    )

    local outputBackground = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    outputBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -112)
    outputBackground:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 78)
    outputBackground:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    outputBackground:SetBackdropColor(0.03, 0.03, 0.03, 0.95)

    local scrollFrame = api.CreateFrame("ScrollFrame", nil, outputBackground, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", outputBackground, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", outputBackground, "BOTTOMRIGHT", -28, 8)

    local scrollChild = api.CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(600, 320)
    scrollFrame:SetScrollChild(scrollChild)

    local editBox = api.CreateFrame("EditBox", nil, scrollChild)
    editBox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -4)
    editBox:SetSize(590, 310)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(999999)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)
    editBox:SetText("{}")
    FlowTestPanel.editBox = editBox

    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 54)
    statusText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 54)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("")
    FlowTestPanel.statusText = statusText

    local copyButton = createButton(
        frame,
        text("EAM_FLOW_BUTTON_COPY", "複製開發報告"),
        160,
        "BOTTOMLEFT",
        frame,
        "BOTTOMLEFT",
        20,
        18,
        function()
            editBox:SetFocus()
            editBox:HighlightText()
            editBox:Copy()
            setStatus(text("EAM_FLOW_STATUS_COPIED", "報告已複製，可回灌至開發環境。"), false)
        end
    )

    createButton(
        frame,
        text("EAM_FLOW_BUTTON_CLOSE", "關閉"),
        100,
        "LEFT",
        copyButton,
        "RIGHT",
        10,
        0,
        function()
            frame:Hide()
        end
    )

    _G.EAM_FlowTestFrame = frame
    if UISpecialFrames then
        UISpecialFrames[#UISpecialFrames + 1] = "EAM_FlowTestFrame"
    end

    FlowTestPanel.frame = frame
    return frame
end

function FlowTestPanel.runSuite(suite)
    if api.InCombatLockdown and api.InCombatLockdown() then
        setStatus(text("EAM_FLOW_STATUS_COMBAT", "戰鬥中不執行流程測試。"), true)
        return false
    end

    local runner = EAM.Debug and EAM.Debug.FlowTestRunner
    if not runner then
        setStatus(text("EAM_FLOW_STATUS_UNAVAILABLE", "流程測試模組尚未載入。"), true)
        return false
    end

    setStatus(text("EAM_FLOW_STATUS_RUNNING", "流程測試執行中……"), false)
    local ok, reason = runner.runSuite(suite, function(report, reportJSON)
        showReport(reportJSON)
        setStatus(buildSummary(report), report and report.summary and report.summary.failed > 0)
    end)

    if not ok then
        setStatus(
            string.format(text("EAM_FLOW_STATUS_START_FAILED", "無法啟動流程測試：%s"), tostring(reason)),
            true
        )
        return false
    end

    if reason ~= "pending" then
        showReport(runner.getLastReportJSON())
    end
    return true
end

function FlowTestPanel.open(forceShow)
    if api.InCombatLockdown and api.InCombatLockdown() then
        FlowTestPanel.pendingOpen = true
        print("|cff00ff96EAM|r " .. text("EAM_FLOW_STATUS_DEFERRED", "流程測試面板將於脫離戰鬥後開啟。"))
        return
    end

    local frame = createFrame()
    if not frame then
        print("|cff00ff96EAM|r " .. text("EAM_FLOW_STATUS_UNAVAILABLE", "流程測試模組尚未載入。"))
        return
    end

    if frame:IsShown() and not forceShow then
        frame:Hide()
        return
    end

    frame:Show()
    local runner = EAM.Debug and EAM.Debug.FlowTestRunner
    if runner then
        showReport(runner.getLastReportJSON())
        setStatus(buildSummary(runner.getLastReport()), false)
    end
end

local function onRegenEnabled()
    if not FlowTestPanel.pendingOpen then
        return
    end
    FlowTestPanel.pendingOpen = false
    FlowTestPanel.open()
end

if EAM.Modules and EAM.Modules.EventRouter then
    EAM.Modules.EventRouter.register("PLAYER_REGEN_ENABLED", onRegenEnabled)
end
