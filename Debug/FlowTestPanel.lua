--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/FlowTestPanel
檔案: Debug\FlowTestPanel.lua

理念:
- 提供明確、按需的 Retail/PTR 流程驗證按鈕與可手動複製報告。
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
- 面板只做非 protected 顯示、聚焦與全選；EditBox 沒有自動寫入系統剪貼簿的 API。
]]
local _, EAM = ...

local api = EAM.API or {}

local FlowTestPanel = {
    frame = nil,
    editBox = nil,
    statusText = nil,
    svgButton = nil,
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

function FlowTestPanel.showExternalReport(reportJSON, message, isError)
    showReport(reportJSON)
    setStatus(message, isError)
    if FlowTestPanel.frame then
        FlowTestPanel.frame:Show()
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
    frame:SetSize(830, 520)
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
        92,
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
        92,
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
        92,
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
        92,
        "LEFT",
        boundaryButton,
        "RIGHT",
        8,
        0,
        function()
            FlowTestPanel.runSuite("aura121")
        end
    )

    local allButton = createButton(
        frame,
        text("EAM_FLOW_BUTTON_ALL", "執行全部"),
        92,
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
    scrollChild:SetSize(750, 320)
    scrollFrame:SetScrollChild(scrollChild)

    local editBox = api.CreateFrame("EditBox", nil, scrollChild)
    editBox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -4)
    editBox:SetSize(740, 310)
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
        text("EAM_FLOW_BUTTON_COPY", "全選開發報告"),
        160,
        "BOTTOMLEFT",
        frame,
        "BOTTOMLEFT",
        20,
        18,
        function()
            local prepared = EAM.Util.prepareEditBoxManualCopy(editBox)
            if prepared then
                setStatus(text("EAM_FLOW_STATUS_COPIED", "報告已全選；請按 Ctrl+C 複製後回灌。"), false)
            else
                setStatus(text("EAM_COPY_SELECTION_FAILED", "無法全選報告文字，請手動點入文字框後按 Ctrl+A、Ctrl+C。"), true)
            end
        end
    )

    local closeButton = createButton(
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

    local dualCountdownButton
    local dualCountdownEnabled = EAM.db and EAM.db.config
        and EAM.db.config.nativeAuraDualCountdownProbe == true or false
    dualCountdownButton = createButton(
        frame,
        dualCountdownEnabled
            and text("EAM_FLOW_BUTTON_DUAL_COUNTDOWN_OFF", "關閉雙倒數")
            or text("EAM_FLOW_BUTTON_DUAL_COUNTDOWN", "雙倒數診斷"),
        92,
        "LEFT",
        allButton,
        "RIGHT",
        8,
        0,
        function()
            if api.InCombatLockdown and api.InCombatLockdown() then
                setStatus(text("EAM_FLOW_STATUS_COMBAT", "戰鬥中不執行流程測試。"), true)
                return
            end
            local savedVariables = EAM.Modules and EAM.Modules.SavedVariables
            local containerService = EAM.Services and EAM.Services.AuraContainerService
            local config = EAM.db and EAM.db.config
            if not savedVariables or not savedVariables.updateConfigBoolean or not config then
                setStatus(text("EAM_FLOW_DUAL_COUNTDOWN_UNAVAILABLE", "雙倒數診斷設定目前不可用。"), true)
                return
            end
            local enabled = config.nativeAuraDualCountdownProbe ~= true
            local updated, updateState = savedVariables.updateConfigBoolean(
                "nativeAuraDualCountdownProbe",
                enabled
            )
            if not updated or updateState ~= "updated" then
                setStatus(text("EAM_FLOW_DUAL_COUNTDOWN_UNAVAILABLE", "雙倒數診斷設定目前不可用。"), true)
                return
            end
            local rebuilt, rebuildReason = true, "unavailable"
            if containerService and containerService.requestRebuild then
                rebuilt, rebuildReason = containerService.requestRebuild("FLOW_TEST_DUAL_COUNTDOWN_TOGGLE")
            end
            dualCountdownButton:SetText(
                enabled
                    and text("EAM_FLOW_BUTTON_DUAL_COUNTDOWN_OFF", "關閉雙倒數")
                    or text("EAM_FLOW_BUTTON_DUAL_COUNTDOWN", "雙倒數診斷")
            )
            if rebuilt == false and rebuildReason == "nativeReloadRequired" then
                setStatus(text("EAM_FLOW_DUAL_COUNTDOWN_RELOAD", "診斷設定已保存；Native 容器已達本次載入上限，請由玩家自行 /reload。"), true)
            elseif enabled then
                setStatus(text("EAM_FLOW_DUAL_COUNTDOWN_ENABLED", "雙倒數診斷已啟用；只供人工觀察同步性，完成後請關閉。"), false)
            else
                setStatus(text("EAM_FLOW_DUAL_COUNTDOWN_DISABLED", "雙倒數診斷已關閉；正常模式只顯示一套倒數。"), false)
            end
        end
    )

    local liveButton = createButton(
        frame,
        text("EAM_FLOW_BUTTON_LIVE", "真人實機回報"),
        140,
        "LEFT",
        closeButton,
        "RIGHT",
        10,
        0,
        function()
            if EAM.Debug.LiveTestPanel then
                EAM.Debug.LiveTestPanel.open(true)
            end
        end
    )

    local unitPowerButton
    unitPowerButton = createButton(
        frame,
        text("EAM_FLOW_BUTTON_UNIT_POWER", "UnitPower 能力"),
        150,
        "LEFT",
        liveButton,
        "RIGHT",
        10,
        0,
        function()
            local probe = EAM.Debug.UnitPowerCapabilityProbe
            if not probe then
                setStatus(text("EAM_UNIT_POWER_PROBE_UNAVAILABLE", "UnitPower 能力探針尚未載入。"), true)
                return
            end
            local ok, report, reportJSON
            if probe.isActive() then
                ok, report, reportJSON = probe.stop()
                unitPowerButton:SetText(text("EAM_FLOW_BUTTON_UNIT_POWER", "UnitPower 能力"))
            else
                local validationEnvironment = EAM.Debug.ValidationEnvironment
                if not validationEnvironment
                    or not validationEnvironment.getDeclaredInstallation
                    or not validationEnvironment.getDeclaredInstallation()
                then
                    if EAM.Debug.LiveTestPanel then
                        EAM.Debug.LiveTestPanel.open(true)
                    end
                    setStatus(
                        text(
                            "EAM_UNIT_POWER_CLIENT_REQUIRED",
                            "請先在真人實機回報面板選擇目前實際開啟的 PTR、XPTR 或正式服，再啟動 UnitPower 測試。"
                        ),
                        true
                    )
                    return
                end
                ok, report, reportJSON = probe.start()
                if ok then
                    unitPowerButton:SetText(text("EAM_FLOW_BUTTON_UNIT_POWER_STOP", "停止並產生報告"))
                end
            end
            if not ok then
                setStatus(
                    text("EAM_UNIT_POWER_PROBE_START_FAILED", "UnitPower 測試無法啟動；請先離開戰鬥再開啟面板。"),
                    true
                )
                return
            end
            showReport(reportJSON)
            if probe.isActive() then
                setStatus(
                    text("EAM_UNIT_POWER_PROBE_RUNNING", "測試中：請由玩家產生／消耗資源，觀察兩條原生顯示後標記結果。"),
                    false
                )
            else
                setStatus(
                    text("EAM_UNIT_POWER_PROBE_STOPPED", "UnitPower 能力報告已完成；請複製回灌。"),
                    not report or report.status ~= "pass"
                )
            end
        end
    )

    local svgButton
    svgButton = createButton(
        frame,
        text("EAM_FLOW_BUTTON_SVG", "SVG 能力"),
        140,
        "LEFT",
        unitPowerButton,
        "RIGHT",
        10,
        0,
        function()
            local probe = EAM.Debug.SVGCapabilityProbe
            if not probe then
                setStatus(text("EAM_SVG_PROBE_UNAVAILABLE", "SVG 能力探針尚未載入。"), true)
                return
            end
            local ok, report, reportJSON
            if probe.isActive() then
                ok, report, reportJSON = probe.stop()
                svgButton:SetText(text("EAM_FLOW_BUTTON_SVG", "SVG 能力"))
            else
                local validationEnvironment = EAM.Debug.ValidationEnvironment
                if not validationEnvironment
                    or not validationEnvironment.getDeclaredInstallation
                    or not validationEnvironment.getDeclaredInstallation()
                then
                    if EAM.Debug.LiveTestPanel then
                        EAM.Debug.LiveTestPanel.open(true)
                    end
                    setStatus(
                        text(
                            "EAM_SVG_CLIENT_REQUIRED",
                            "請先在真人實機回報面板選擇目前客戶端，再啟動 SVG 測試。"
                        ),
                        true
                    )
                    return
                end
                ok, report, reportJSON = probe.start()
                if ok then
                    svgButton:SetText(text("EAM_FLOW_BUTTON_SVG_STOP", "停止 SVG 測試"))
                end
            end
            if not ok then
                setStatus(
                    text("EAM_SVG_PROBE_START_FAILED", "SVG 測試無法啟動；請先離開戰鬥。"),
                    true
                )
                return
            end
            showReport(reportJSON)
            if probe.isActive() then
                setStatus(
                    text("EAM_SVG_PROBE_RUNNING", "請確認兩格 SVG 圖案並分別標記目視結果。"),
                    false
                )
                frame:Hide()
            else
                setStatus(
                    text("EAM_SVG_PROBE_STOPPED", "SVG 能力報告已完成；請全選後按 Ctrl+C 回灌。"),
                    not report or report.status ~= "pass"
                )
            end
        end
    )
    FlowTestPanel.svgButton = svgButton

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
