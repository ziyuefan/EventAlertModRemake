--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/UnitPowerCapabilityProbe
檔案: Debug\UnitPowerCapabilityProbe.lua

責任:
- 由玩家啟停 UnitPower 能力測試，持續把 UnitPowerPercent 直接送入原生顯示 sink。
- 產生不含 power/max/percent 原值的結構化 JSON 報告。

邊界:
- 不自動施法、不切換專精、不進出戰鬥、不修改 restriction CVar。
- Secret percent 不比較、不字串化、不存入 table、不讀回 widget。
- widget 幾何與材質在接收 Secret 前完成，測試中不重新配置。
]]
local _, EAM = ...

local api = EAM.API
local Theme = EAM.Theme
local Locale = EAM.Locale
local Util = EAM.Util

local UnitPowerCapabilityProbe = {
    schemaVersion = 1,
    initialized = false,
    active = false,
    frame = nil,
    sinks = {},
    cases = {},
    observations = {},
    startedAt = nil,
    stoppedAt = nil,
    lastReport = nil,
    lastReportJSON = nil,
}

EAM.Debug.UnitPowerCapabilityProbe = UnitPowerCapabilityProbe

local function sessionTime()
    return api.GetTime and api.GetTime() or 0
end

local function text(key, fallback)
    return EAM.L and EAM.L[key] or fallback
end

local function localized(key, fallback)
    return { key = key, fallback = fallback }
end

local function setWidgetText(target, value)
    if type(value) == "table" and type(value.key) == "string" then
        Locale.bindText(target, value.key, value.fallback)
    else
        target:SetText(value)
    end
end

local function createButton(parent, label, width, x, y, callback)
    local button = api.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(button) end
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    setWidgetText(button, label)
    button:SetScript("OnClick", callback)
    return button
end

local function createSink(parent, labelText, y)
    local sink = {}
    sink.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sink.label:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    setWidgetText(sink.label, labelText)

    sink.statusBar = api.CreateFrame("StatusBar", nil, parent)
    sink.statusBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y - 20)
    sink.statusBar:SetSize(220, 18)
    sink.statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    sink.statusBar:SetMinMaxValues(0, 1)
    sink.statusBar:SetValue(0)

    local background = sink.statusBar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(sink.statusBar)
    background:SetColorTexture(0.08, 0.08, 0.08, 0.9)

    sink.radial = parent:CreateTexture(nil, "ARTWORK")
    sink.radial:SetPoint("LEFT", sink.statusBar, "RIGHT", 16, 0)
    sink.radial:SetSize(38, 38)
    sink.radial:SetColorTexture(0.2, 0.8, 1, 0.75)
    sink.hasRadial = type(sink.radial.SetRadialProgressBarPercent) == "function"
    if sink.hasRadial then
        if type(sink.radial.SetRadialProgressBarStartOffset) == "function" then
            sink.radial:SetRadialProgressBarStartOffset(0)
        end
        if type(sink.radial.SetRadialProgressBarEndOffset) == "function" then
            sink.radial:SetRadialProgressBarEndOffset(1)
        end
        if type(sink.radial.SetRadialProgressBarFeather) == "function" then
            sink.radial:SetRadialProgressBarFeather(0.08)
        end
    end

    sink.resultText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sink.resultText:SetPoint("LEFT", sink.radial, "RIGHT", 10, 0)
    sink.resultText:SetText("pending")
    return sink
end

local function createFrame()
    if UnitPowerCapabilityProbe.frame then
        return UnitPowerCapabilityProbe.frame
    end
    if not api.CreateFrame or not UIParent then
        return nil
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return nil
    end

    local frame = api.CreateFrame("Frame", "EAM_UnitPowerCapabilityFrame", UIParent, "BackdropTemplate")
    frame:SetSize(640, 190)
    frame:SetPoint("CENTER", UIParent, "CENTER", 280, 20)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    frame:SetBackdropColor(0.04, 0.04, 0.06, 0.96)
    if Theme and Theme.registerFrame then Theme.registerFrame(frame, "window") end
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    Locale.bindText(title, "EAM_UNIT_POWER_PROBE_TITLE", "UnitPower 原生顯示能力測試")
    if Theme and Theme.registerText then Theme.registerText(title, "title") end

    UnitPowerCapabilityProbe.sinks.primary =
        createSink(frame, localized("EAM_UNIT_POWER_PROBE_PRIMARY", "目前主要資源"), -38)
    UnitPowerCapabilityProbe.sinks.selected =
        createSink(frame, localized("EAM_UNIT_POWER_PROBE_SELECTED", "EAM 選定資源"), -92)

    local function createObservationButtons(caseID, y)
        createButton(frame, localized("EAM_UNIT_POWER_PROBE_PASS", "顯示正常"), 74, 350, y, function()
            UnitPowerCapabilityProbe.markVisual(caseID, "pass")
        end)
        createButton(frame, localized("EAM_UNIT_POWER_PROBE_FAIL", "顯示異常"), 74, 432, y, function()
            UnitPowerCapabilityProbe.markVisual(caseID, "fail")
        end)
        createButton(frame, localized("EAM_UNIT_POWER_PROBE_BLOCKED", "無法測試"), 100, 514, y, function()
            UnitPowerCapabilityProbe.markVisual(caseID, "blocked")
        end)
    end
    createObservationButtons("unitpower.primary.native_percent", -58)
    createObservationButtons("unitpower.selected.safe_or_native", -112)

    UnitPowerCapabilityProbe.frame = frame
    return frame
end

local function classifyResult(ok, value)
    if not ok then
        return "error"
    end
    if Util.isSecretValue(value) or not Util.canAccessValue(value) then
        return "secret"
    end
    if Util.isSafeNumber(value) then
        return "safe-number"
    end
    if value == nil then
        return "nil"
    end
    return "inaccessible"
end

local function updateCase(caseID, role, powerType, sink)
    local case = UnitPowerCapabilityProbe.cases[caseID]
    if not case then
        case = {
            id = caseID,
            role = role,
        }
        UnitPowerCapabilityProbe.cases[caseID] = case
    end
    case.powerTypeAvailable = Util.isSafeNonNegativeNumber(powerType)
    case.statusBarSink = "not-run"
    case.radialSink = sink.hasRadial and "not-run" or "unavailable"
    if not case.powerTypeAvailable or type(api.UnitPowerPercent) ~= "function" then
        case.resultClass = "unavailable"
        sink.resultText:SetText(case.resultClass)
        return
    end

    local ok, percent = pcall(api.UnitPowerPercent, "player", powerType, false)
    case.resultClass = classifyResult(ok, percent)
    -- Secret percent 只能直送原生 sink；不可測試真偽、比較或讀回。
    if ok then
        local statusOK = pcall(sink.statusBar.SetValue, sink.statusBar, percent)
        case.statusBarSink = statusOK and "accepted" or "rejected"
        if sink.hasRadial then
            local radialOK = pcall(sink.radial.SetRadialProgressBarPercent, sink.radial, percent)
            case.radialSink = radialOK and "accepted" or "rejected"
        end
    else
        case.statusBarSink = "rejected"
        if sink.hasRadial then
            case.radialSink = "rejected"
        end
    end
    percent = nil
    sink.resultText:SetText(case.resultClass)
end

local function currentPrimaryPowerType()
    if type(api.UnitPowerType) ~= "function" then
        return nil
    end
    local ok, powerType = pcall(api.UnitPowerType, "player")
    if ok and Util.isSafeNonNegativeNumber(powerType) then
        return powerType
    end
    return nil
end

local function selectedPowerType()
    local service = EAM.Services.ClassPowerService
    if service and service.getActivePowerType then
        return service.getActivePowerType()
    end
    return nil
end

function UnitPowerCapabilityProbe.update()
    if not UnitPowerCapabilityProbe.active then
        return false, "inactive"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    updateCase(
        "unitpower.primary.native_percent",
        "primary",
        currentPrimaryPowerType(),
        UnitPowerCapabilityProbe.sinks.primary
    )
    updateCase(
        "unitpower.selected.safe_or_native",
        "selected",
        selectedPowerType(),
        UnitPowerCapabilityProbe.sinks.selected
    )
    return true
end

local function buildCaseList()
    local list = {}
    local ids = {
        "unitpower.primary.native_percent",
        "unitpower.selected.safe_or_native",
    }
    for index = 1, #ids do
        local source = UnitPowerCapabilityProbe.cases[ids[index]] or {}
        list[index] = {
            id = ids[index],
            role = source.role or (index == 1 and "primary" or "selected"),
            powerTypeAvailable = source.powerTypeAvailable == true,
            resultClass = source.resultClass or "pending",
            statusBarSink = source.statusBarSink or "not-run",
            radialSink = source.radialSink or "not-run",
            visualObservation = UnitPowerCapabilityProbe.observations[ids[index]] or "pending",
        }
    end
    return list
end

function UnitPowerCapabilityProbe.buildReport()
    local validationEnvironment = EAM.Debug.ValidationEnvironment
    local environment, environmentWarnings
    if validationEnvironment and validationEnvironment.snapshot then
        environment, environmentWarnings = validationEnvironment.snapshot()
    else
        environment = { executionSource = "client", channelValidation = "unknown" }
        environmentWarnings = { "validationEnvironmentUnavailable" }
    end

    local cases = buildCaseList()
    local warnings = {}
    for index = 1, #(environmentWarnings or {}) do
        warnings[#warnings + 1] = environmentWarnings[index]
    end
    local radialRequired = Util.isSafeNumber(environment.interface)
        and environment.interface >= EAM.Constants.INTERFACE
    local aggregateObservation = "pass"
    for index = 1, #cases do
        local case = cases[index]
        if case.visualObservation == "fail" then
            aggregateObservation = "fail"
        elseif case.visualObservation == "blocked" and aggregateObservation ~= "fail" then
            aggregateObservation = "blocked"
        elseif case.visualObservation == "pending" and aggregateObservation == "pass" then
            aggregateObservation = "pending"
        end
        if case.visualObservation == "pending" then
            warnings[#warnings + 1] = "humanVisualConfirmationRequired:" .. case.id
        end
        if not case.powerTypeAvailable then
            warnings[#warnings + 1] = "unitPowerTypeUnavailable:" .. case.id
        elseif case.statusBarSink ~= "accepted" then
            warnings[#warnings + 1] = "unitPowerStatusBarRejected:" .. case.id
        end
        if radialRequired and case.radialSink ~= "accepted" then
            warnings[#warnings + 1] = "unitPowerRadialRejected:" .. case.id
        end
    end

    local status = UnitPowerCapabilityProbe.active and "active" or "incomplete"
    if aggregateObservation == "fail" then
        status = "fail"
    elseif aggregateObservation == "blocked" then
        status = "blocked"
    elseif aggregateObservation == "pass"
        and UnitPowerCapabilityProbe.active == false
        and UnitPowerCapabilityProbe.stoppedAt ~= nil
        and #warnings == 0
        and environment.executionSource == "client"
        and environment.channelValidation == "pass"
    then
        status = "pass"
    end

    local cSecrets = api.C_Secrets
    local report = {
        schema = UnitPowerCapabilityProbe.schemaVersion,
        type = "EAM_UNIT_POWER_CAPABILITY_REPORT",
        purpose = "capability-probe",
        status = status,
        rawValuesCollected = false,
        session = {
            active = UnitPowerCapabilityProbe.active,
            startedAtSessionMs = UnitPowerCapabilityProbe.startedAt,
            stoppedAtSessionMs = UnitPowerCapabilityProbe.stoppedAt,
            visualObservation = aggregateObservation,
        },
        environment = environment,
        automation = {
            playerOperated = true,
            gameInputAutomated = false,
            restrictionCVarModified = false,
        },
        capabilities = {
            unitPower = type(api.UnitPower) == "function",
            unitPowerMax = type(api.UnitPowerMax) == "function",
            unitPowerPercent = type(api.UnitPowerPercent) == "function",
            shouldUnitPowerBeSecret = cSecrets
                and type(cSecrets.ShouldUnitPowerBeSecret) == "function" or false,
            shouldUnitPowerMaxBeSecret = cSecrets
                and type(cSecrets.ShouldUnitPowerMaxBeSecret) == "function" or false,
            getPowerTypeSecrecy = cSecrets
                and type(cSecrets.GetPowerTypeSecrecy) == "function" or false,
            statusBarSecretSink = UnitPowerCapabilityProbe.initialized,
            statusBarSecretSinkAvailable = UnitPowerCapabilityProbe.initialized
                and UnitPowerCapabilityProbe.sinks.primary
                and type(UnitPowerCapabilityProbe.sinks.primary.statusBar.SetValue) == "function" or false,
            radialProgressSecretSink = UnitPowerCapabilityProbe.sinks.primary
                and UnitPowerCapabilityProbe.sinks.primary.hasRadial == true or false,
            radialSinkRequired = radialRequired,
        },
        cases = cases,
        boundaryWarnings = warnings,
    }
    local encoder = EAM.Debug.FlowTestRunner and EAM.Debug.FlowTestRunner.encodeJSON
    local reportJSON = encoder and encoder(report) or nil
    UnitPowerCapabilityProbe.lastReport = report
    UnitPowerCapabilityProbe.lastReportJSON = reportJSON
    _G.EAM_UNIT_POWER_CAPABILITY_REPORT_JSON = reportJSON
    return report, reportJSON
end

function UnitPowerCapabilityProbe.markVisual(caseID, status)
    if not UnitPowerCapabilityProbe.active
        or (caseID ~= "unitpower.primary.native_percent"
            and caseID ~= "unitpower.selected.safe_or_native")
    then
        return false, "inactiveOrUnknownCase"
    end
    if status ~= "pass" and status ~= "fail" and status ~= "blocked" then
        return false, "invalidStatus"
    end
    UnitPowerCapabilityProbe.observations[caseID] = status
    local sink = caseID == "unitpower.primary.native_percent"
        and UnitPowerCapabilityProbe.sinks.primary or UnitPowerCapabilityProbe.sinks.selected
    local case = UnitPowerCapabilityProbe.cases[caseID]
    if sink and sink.resultText then
        sink.resultText:SetText((case and case.resultClass or "pending") .. " / " .. status)
    end
    UnitPowerCapabilityProbe.buildReport()
    return true, status
end

function UnitPowerCapabilityProbe.onEvent(eventName, unit)
    if UnitPowerCapabilityProbe.active and unit == "player" then
        return UnitPowerCapabilityProbe.update()
    end
    return false, "ignored"
end

function UnitPowerCapabilityProbe.initialize()
    if UnitPowerCapabilityProbe.initialized then
        return true
    end
    local frame = createFrame()
    if not frame then
        return false, "combatDeferred"
    end
    local router = EAM.Modules.EventRouter
    if router then
        router.register("UNIT_POWER_FREQUENT", UnitPowerCapabilityProbe.onEvent)
        router.register("UNIT_MAXPOWER", UnitPowerCapabilityProbe.onEvent)
    end
    UnitPowerCapabilityProbe.initialized = true
    return true
end

function UnitPowerCapabilityProbe.start()
    if EAM.FlowTestEnvironment ~= "offline-mock" then
        local validationEnvironment = EAM.Debug.ValidationEnvironment
        local declaredInstallation = validationEnvironment
            and validationEnvironment.getDeclaredInstallation
            and validationEnvironment.getDeclaredInstallation()
        if not declaredInstallation then
            return false, "clientInstallationUnconfirmed"
        end
        local environment = validationEnvironment.snapshot()
        if environment.channelValidation ~= "pass" then
            return false, "clientEnvironmentMismatch"
        end
    end
    local initialized, reason = UnitPowerCapabilityProbe.initialize()
    if not initialized then
        return false, reason
    end
    UnitPowerCapabilityProbe.active = true
    UnitPowerCapabilityProbe.startedAt = sessionTime()
    UnitPowerCapabilityProbe.stoppedAt = nil
    wipe(UnitPowerCapabilityProbe.cases)
    wipe(UnitPowerCapabilityProbe.observations)
    UnitPowerCapabilityProbe.observations["unitpower.primary.native_percent"] = "pending"
    UnitPowerCapabilityProbe.observations["unitpower.selected.safe_or_native"] = "pending"
    UnitPowerCapabilityProbe.frame:Show()
    UnitPowerCapabilityProbe.update()
    local report, reportJSON = UnitPowerCapabilityProbe.buildReport()
    return true, report, reportJSON
end

function UnitPowerCapabilityProbe.stop()
    if not UnitPowerCapabilityProbe.active then
        return false, "inactive"
    end
    UnitPowerCapabilityProbe.update()
    UnitPowerCapabilityProbe.active = false
    UnitPowerCapabilityProbe.stoppedAt = sessionTime()
    UnitPowerCapabilityProbe.frame:Hide()
    local report, reportJSON = UnitPowerCapabilityProbe.buildReport()
    return true, report, reportJSON
end

function UnitPowerCapabilityProbe.isActive()
    return UnitPowerCapabilityProbe.active
end

function UnitPowerCapabilityProbe.getLastReportJSON()
    return UnitPowerCapabilityProbe.lastReportJSON
end
