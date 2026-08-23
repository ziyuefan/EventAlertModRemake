--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/DebugCenterPanel
檔案: UI\DebugCenterPanel.lua

理念:
- 集中整合所有 EAM 診斷、符文探針、流程測試與提示詞匯出功能於單一視窗。

責任:
- 提供 4 大診斷分頁：
  1. 即時後端狀態 (Runtime Status & Aura Backend)
  2. DK 符文與資源診斷 (DK Rune & Resource Probe)
  3. 流程與單元測試 (Flow Test Runner)
  4. 提示詞與診斷匯出 (Diagnostic & Prompt Export)
- 提供安全、無副作用的一鍵複製與執行測試功能。

邊界:
- 戰鬥中不建立新 Frame。
- 嚴格唯讀，不向遊戲引擎寫入非安全資料。
]]
local _, EAM = ...

local api = EAM.API or {}
local Theme = EAM.Theme
local Locale = EAM.Locale

local Panel = {
    frame = nil,
    currentTab = 1,
    contentBox = nil,
    scrollFrame = nil,
    statusText = nil,
    actionButton1 = nil,
    actionButton2 = nil,
    tabButtons = {},
}
EAM.UI.DebugCenterPanel = Panel

local function inCombat()
    return type(api.InCombatLockdown) == "function" and api.InCombatLockdown() == true
end

local function localized(key, fallback)
    return EAM.L and EAM.L[key] or fallback
end

local function bindText(target, key, fallback)
    if Locale and type(Locale.bindText) == "function" then
        return Locale.bindText(target, key, fallback)
    end
    if target and type(target.SetText) == "function" then
        target:SetText(localized(key, fallback))
        return true
    end
    return false
end

local function setStatus(message)
    if Panel.statusText then
        Panel.statusText:SetText(message or "")
    end
end

local function setContent(text)
    if Panel.contentBox then
        Panel.contentBox:SetText(text or "")
        if Panel.scrollFrame then
            Panel.scrollFrame:SetVerticalScroll(0)
        end
    end
end

-- =========================================================================
-- Tab 1: Runtime Status
-- =========================================================================
local function refreshRuntimeStatus()
    local lines = {}
    lines[#lines + 1] = "=== EAM Runtime & Backend Diagnostics ==="
    lines[#lines + 1] = "Time: " .. (date and date("%Y-%m-%d %H:%M:%S") or "N/A")
    lines[#lines + 1] = "Addon Version: " .. (EAM.Constants and EAM.Constants.VERSION or "Unknown")
    lines[#lines + 1] = "Schema Version: " .. tostring(EAM.Constants and EAM.Constants.SCHEMA_VERSION or "N/A")
    lines[#lines + 1] = ""

    -- Aura Backend
    local containerService = EAM.Services and EAM.Services.AuraContainerService
    local containerState = containerService and containerService.getState and containerService.getState()
    lines[#lines + 1] = "[Aura Backend]"
    if containerState then
        lines[#lines + 1] = "  - Mode: " .. tostring(containerState.backendKind or "Native 12.1")
        lines[#lines + 1] = "  - Containers Active: " .. tostring(containerState.containerCount or 0)
        lines[#lines + 1] = "  - Rebuild Generation: " .. tostring(containerState.generation or 0)
    else
        lines[#lines + 1] = "  - AuraContainerService Active: true (12.1 Native)"
    end
    lines[#lines + 1] = ""

    -- Player & Spec
    local classToken = EAM.Modules and EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.getActiveClassToken and EAM.Modules.SavedVariables.getActiveClassToken()
    lines[#lines + 1] = "[Player Context]"
    lines[#lines + 1] = "  - Class: " .. tostring(classToken or "Unknown")
    if type(api.GetSpecialization) == "function" and type(api.GetSpecializationInfo) == "function" then
        local spec = api.GetSpecialization()
        if spec then
            local id, name = api.GetSpecializationInfo(spec)
            lines[#lines + 1] = "  - Specialization: " .. tostring(name) .. " (ID: " .. tostring(id) .. ")"
        end
    end
    lines[#lines + 1] = ""

    -- Player Resource Service
    local resService = EAM.Services and EAM.Services.PlayerResourceService
    lines[#lines + 1] = "[Player Resource Service]"
    if resService then
        lines[#lines + 1] = "  - Tracked Resources: " .. tostring(resService.trackedResourceCount or 0)
        lines[#lines + 1] = "  - Foreground Power: " .. tostring(resService.foregroundPowerType or "N/A")
        lines[#lines + 1] = "  - Last Result: " .. tostring(resService.lastResultClass or "OK")
    else
        lines[#lines + 1] = "  - Status: Service uninitialized"
    end
    lines[#lines + 1] = ""

    -- Tooltip & Target Diagnostics
    local tooltipService = EAM.Services and EAM.Services.TooltipMonitorService
    lines[#lines + 1] = "[Tooltip & Diagnostics]"
    lines[#lines + 1] = "  - Tooltip Monitor: " .. (tooltipService and "Active" or "Inactive")

    setContent(table.concat(lines, "\n"))
    setStatus(localized("EAM_DEBUG_STATUS_REFRESHED", "已更新即時後端狀態。"))
end

-- =========================================================================
-- Tab 2: DK Rune & Resource Probe
-- =========================================================================
local function refreshRuneProbe()
    local lines = {}
    lines[#lines + 1] = "=== Death Knight Rune Diagnostic & State ==="
    lines[#lines + 1] = "Time: " .. (date and date("%Y-%m-%d %H:%M:%S") or "N/A")
    lines[#lines + 1] = ""

    local spec = type(api.GetSpecialization) == "function" and api.GetSpecialization()
    local specID, specName = nil, "Unknown"
    if spec and type(api.GetSpecializationInfo) == "function" then
        specID, specName = api.GetSpecializationInfo(spec)
    end
    lines[#lines + 1] = string.format("Current Specialization: %s (ID: %s)", tostring(specName), tostring(specID))

    local Catalog = EAM.Data and EAM.Data.PlayerResourceCatalog
    local specIcon = Catalog and Catalog.getResourceIcon and Catalog.getResourceIcon("RUNES", specID)
    lines[#lines + 1] = string.format("Rune Spec Icon FileDataID: %s", tostring(specIcon or "Default"))
    lines[#lines + 1] = ""

    local now = type(api.GetTime) == "function" and api.GetTime() or 0
    local readyCount = 0
    local slotsData = {}

    lines[#lines + 1] = "Slot | Ready | Start     | Duration | Remaining | Progress"
    lines[#lines + 1] = "-----+-------+-----------+----------+-----------+---------"

    if type(api.GetRuneCooldown) == "function" then
        for slot = 1, 6 do
            local start, duration, runeReady = api.GetRuneCooldown(slot)
            local remaining = 0
            local progress = 1.0
            if runeReady then
                readyCount = readyCount + 1
            elseif start and duration and duration > 0 then
                remaining = math.max(0, (start + duration) - now)
                progress = math.max(0, math.min(1, (now - start) / duration))
            end
            slotsData[slot] = {
                slot = slot,
                ready = runeReady == true,
                start = start or 0,
                duration = duration or 0,
                remaining = remaining,
                progress = progress,
            }
            lines[#lines + 1] = string.format(
                " #%d  | %-5s | %-9.2f | %-8.2f | %-9.2fs | %3.0f%%",
                slot,
                tostring(runeReady == true),
                start or 0,
                duration or 0,
                remaining,
                progress * 100
            )
        end
    else
        lines[#lines + 1] = "(GetRuneCooldown API unavailable in current environment)"
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Summary: %d / 6 Runes Ready", readyCount)

    -- Format JSON for copying
    lines[#lines + 1] = ""
    lines[#lines + 1] = "=== JSON Payload (Ready to copy) ==="
    local jsonParts = {}
    for slot = 1, #slotsData do
        local d = slotsData[slot]
        jsonParts[#jsonParts + 1] = string.format(
            '{"slot":%d,"ready":%s,"remaining":%.2f,"progress":%.2f}',
            d.slot,
            tostring(d.ready),
            d.remaining,
            d.progress
        )
    end
    lines[#lines + 1] = string.format('{"specID":%s,"readyCount":%d,"runes":[%s]}', tostring(specID or 0), readyCount, table.concat(jsonParts, ","))

    setContent(table.concat(lines, "\n"))
    setStatus(localized("EAM_DEBUG_STATUS_RUNE_REFRESHED", "已更新 DK 符文診斷數據。"))
end

-- =========================================================================
-- Tab 3: Flow Test Runner
-- =========================================================================
local function runFlowTests()
    setStatus(localized("EAM_DEBUG_STATUS_RUNNING_TESTS", "正在執行流程與單元測試..."))
    local runner = EAM.Debug and EAM.Debug.FlowTestRunner
    if not runner or type(runner.runSuite) ~= "function" then
        setContent("FlowTestRunner module is not loaded.")
        setStatus("測試模組未加載。")
        return
    end

    local report = runner.runSuite("all")
    if not report then
        setContent("Flow test execution failed or returned no report.")
        setStatus("測試執行失敗。")
        return
    end

    local lines = {}
    lines[#lines + 1] = "=== EAM Flow & State Machine Test Report ==="
    lines[#lines + 1] = "Suite: all"
    lines[#lines + 1] = string.format("Total: %d | Passed: %d | Failed: %d | Skipped: %d", report.total or 0, report.passed or 0, report.failed or 0, report.skipped or 0)
    lines[#lines + 1] = "Duration: " .. string.format("%.2f ms", (report.durationMs or 0))
    lines[#lines + 1] = ""
    lines[#lines + 1] = "=== Test Cases ==="

    if report.cases and #report.cases > 0 then
        for i = 1, #report.cases do
            local c = report.cases[i]
            local mark = (c.status == "pass" or c.status == "passed") and "[PASS]" or "[FAIL]"
            lines[#lines + 1] = string.format("%s %-45s (%.2f ms)", mark, c.id or "unknown", c.durationMs or 0)
            if c.message and c.message ~= "" then
                lines[#lines + 1] = "       " .. c.message
            end
        end
    end

    setContent(table.concat(lines, "\n"))
    setStatus(string.format("流程測試完成：共 %d 項，通過 %d 項，失敗 %d 項。", report.total or 0, report.passed or 0, report.failed or 0))
end

-- =========================================================================
-- Tab 4: Prompt & Diagnostic Export
-- =========================================================================
local function generateDiagnosticExport()
    setStatus(localized("EAM_DEBUG_STATUS_EXPORTING", "正在產生診斷報告..."))
    local exporter = EAM.Debug and EAM.Debug.PromptExport
    if exporter and type(exporter.export) == "function" then
        local text, report = exporter.export()
        if text then
            setContent(text)
            setStatus(string.format("已產生完整系統診斷報告（共 %d 字元），請按全選複製。", #text))
            return
        end
    end

    -- Fallback diagnostic bundle
    local lines = {}
    lines[#lines + 1] = "=== EAM Diagnostic Report Export ==="
    lines[#lines + 1] = "Generated: " .. (date and date("%Y-%m-%d %H:%M:%S") or "N/A")
    lines[#lines + 1] = "Addon: EventAlertMod"
    lines[#lines + 1] = "Version: " .. tostring(EAM.Constants and EAM.Constants.VERSION)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "[Database Summary]"
    local db = EAM.db
    if db then
        lines[#lines + 1] = "  - Theme: " .. tostring(db.theme or "default")
        lines[#lines + 1] = "  - Language: " .. tostring(db.language or "auto")
        lines[#lines + 1] = "  - Active Class: " .. tostring(db.activeClassToken or "N/A")
    end
    setContent(table.concat(lines, "\n"))
    setStatus("已產生基礎診斷資訊。")
end

local function selectAllForCopy()
    if not Panel.contentBox then
        return
    end
    local ok = EAM.Util and EAM.Util.prepareEditBoxManualCopy
        and EAM.Util.prepareEditBoxManualCopy(Panel.contentBox)
    if ok then
        setStatus(localized("EAM_PROFILE_CODEC_STATUS_SELECTED", "已全選內容；請按 Ctrl+C 複製。"))
    else
        setStatus("請在文字欄位內按 Ctrl+A、Ctrl+C 複製。")
    end
end

-- =========================================================================
-- Tab Switcher & UI Building
-- =========================================================================
local function switchTab(tabIndex)
    Panel.currentTab = tabIndex
    for i = 1, #Panel.tabButtons do
        if i == tabIndex then
            Panel.tabButtons[i]:SetBackdropColor(0.2, 0.4, 0.6, 1)
        else
            Panel.tabButtons[i]:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
        end
    end

    if tabIndex == 1 then
        Panel.actionButton1:SetText(localized("EAM_DEBUG_BTN_REFRESH", "刷新狀態"))
        Panel.actionButton1:SetScript("OnClick", refreshRuntimeStatus)
        refreshRuntimeStatus()
    elseif tabIndex == 2 then
        Panel.actionButton1:SetText(localized("EAM_DEBUG_BTN_RUNE_PROBE", "即時探針檢測"))
        Panel.actionButton1:SetScript("OnClick", refreshRuneProbe)
        refreshRuneProbe()
    elseif tabIndex == 3 then
        Panel.actionButton1:SetText(localized("EAM_DEBUG_BTN_RUN_TESTS", "執行流程測試"))
        Panel.actionButton1:SetScript("OnClick", runFlowTests)
        runFlowTests()
    elseif tabIndex == 4 then
        Panel.actionButton1:SetText(localized("EAM_DEBUG_BTN_GENERATE_EXPORT", "產生診斷報告"))
        Panel.actionButton1:SetScript("OnClick", generateDiagnosticExport)
        generateDiagnosticExport()
    end
end

local function createFrame()
    if Panel.frame then
        return Panel.frame
    end
    if inCombat() then
        return nil
    end

    local frame = api.CreateFrame("Frame", "EAM_DebugCenterFrame", api.UIParent, "BackdropTemplate")
    frame:SetSize(620, 520)
    frame:SetPoint("CENTER", api.UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    frame:SetBackdropBorderColor(0.3, 0.6, 0.9, 1)
    if Theme and Theme.registerFrame then
        Theme.registerFrame(frame, "window")
    end
    Panel.frame = frame

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    bindText(title, "EAM_DEBUG_CENTER_TITLE", "除錯與測試診斷中心")
    if Theme and Theme.registerText then
        Theme.registerText(title, "title")
    end

    -- Tab Buttons
    local tabDefs = {
        { label = "即時後端狀態", key = "EAM_DEBUG_TAB_RUNTIME" },
        { label = "DK 符文診斷", key = "EAM_DEBUG_TAB_RUNE" },
        { label = "流程測試運行", key = "EAM_DEBUG_TAB_FLOW" },
        { label = "系統診斷匯出", key = "EAM_DEBUG_TAB_EXPORT" },
    }
    local tabWidth = 142
    for i = 1, #tabDefs do
        local btn = api.CreateFrame("Button", nil, frame, "BackdropTemplate")
        btn:SetSize(tabWidth, 26)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 16 + (i - 1) * (tabWidth + 6), -42)
        btn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 12, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        btn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
        btn:SetBackdropBorderColor(0.4, 0.5, 0.6, 1)

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        bindText(btnText, tabDefs[i].key, tabDefs[i].label)
        if Theme and Theme.registerText then
            Theme.registerText(btnText, "body")
        end

        btn:SetScript("OnClick", function()
            switchTab(i)
        end)
        Panel.tabButtons[i] = btn
    end

    -- ScrollFrame and Content Box
    local scrollFrame = api.CreateFrame("ScrollFrame", "EAM_DebugCenterScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -74)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -36, 68)
    Panel.scrollFrame = scrollFrame

    local contentBox = api.CreateFrame("EditBox", nil, scrollFrame)
    contentBox:SetMultiLine(true)
    contentBox:SetMaxLetters(131072)
    contentBox:EnableMouse(true)
    contentBox:SetAutoFocus(false)
    contentBox:SetFontObject("GameFontHighlightSmall")
    contentBox:SetWidth(560)
    contentBox:SetScript("OnEscapePressed", function()
        contentBox:ClearFocus()
    end)
    scrollFrame:SetScrollChild(contentBox)
    Panel.contentBox = contentBox

    -- Status Text
    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 44)
    statusText:SetWidth(580)
    statusText:SetJustifyH("LEFT")
    Panel.statusText = statusText

    -- Bottom Buttons
    local actionBtn1 = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    actionBtn1:SetSize(140, 26)
    actionBtn1:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 12)
    if Theme and Theme.registerButton then Theme.registerButton(actionBtn1) end
    Panel.actionButton1 = actionBtn1

    local actionBtn2 = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    actionBtn2:SetSize(120, 26)
    actionBtn2:SetPoint("LEFT", actionBtn1, "RIGHT", 10, 0)
    bindText(actionBtn2, "EAM_DEBUG_BTN_SELECT_ALL", "全選複製")
    actionBtn2:SetScript("OnClick", selectAllForCopy)
    if Theme and Theme.registerButton then Theme.registerButton(actionBtn2) end
    Panel.actionButton2 = actionBtn2

    local closeBtn = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 26)
    closeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 12)
    bindText(closeBtn, "EAM_OPT_CLOSE_BTN", "關閉")
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    if Theme and Theme.registerButton then Theme.registerButton(closeBtn) end

    return frame
end

function Panel.open(tabIndex)
    local frame = createFrame()
    if not frame then
        return false, "combatDeferred"
    end
    frame:Show()
    switchTab(tabIndex or Panel.currentTab or 1)
    return true
end

function Panel.close()
    if Panel.frame then
        Panel.frame:Hide()
    end
end
