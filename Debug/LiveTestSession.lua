--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/LiveTestSession
檔案: Debug\LiveTestSession.lua

理念:
- 玩家操作遊戲、EAM 只記錄人工觀察，形成 PTR／XPTR／正式服可回灌 JSON。

責任:
- 管理 29 個實機案例、匿名能力快照、/reload checkpoint、摘要與 JSON 匯出。

邊界:
- 不施法、不使用物品、不執行巨集、不切換目標、不合成輸入、不呼叫 ReloadUI。
- 不讀帳號、角色、伺服器、AuraData、倒數文字或 applications 原值。
- 戰鬥中不寫入案例、備註、checkpoint 或完成狀態。
]]
local _, EAM = ...

local api = EAM.API or {}
local util = EAM.Util or {}
local freeze = util.tableFreeze or function(value)
    return value
end

local MATRIX_VERSION = "2026-08-08.1"
local PRIVACY_REDACTED_NOTE = "[privacy-redacted]"
local BOOT_TOKEN = {}
local CASES = freeze({
    freeze({ id = "live.environment.identity", category = "environment", labelKey = "EAM_LIVE_CASE_ENVIRONMENT" }),
    freeze({ id = "live.tooltip.spellbook", category = "tooltip", labelKey = "EAM_LIVE_CASE_SPELLBOOK" }),
    freeze({ id = "live.tooltip.actionbar_macro", category = "tooltip", labelKey = "EAM_LIVE_CASE_ACTIONBAR_MACRO" }),
    freeze({ id = "live.tooltip.bag_item", category = "tooltip", labelKey = "EAM_LIVE_CASE_BAG_ITEM" }),
    freeze({ id = "live.tooltip.player_aura", category = "tooltip", labelKey = "EAM_LIVE_CASE_PLAYER_AURA" }),
    freeze({ id = "live.tooltip.target_aura", category = "tooltip", labelKey = "EAM_LIVE_CASE_TARGET_AURA" }),
    freeze({ id = "live.tooltip.out_of_combat", category = "combat", labelKey = "EAM_LIVE_CASE_OUT_OF_COMBAT" }),
    freeze({ id = "live.tooltip.in_combat_rejected", category = "combat", labelKey = "EAM_LIVE_CASE_IN_COMBAT" }),
    freeze({ id = "live.popup.escape_cancel", category = "popup", labelKey = "EAM_LIVE_CASE_ESCAPE_CANCEL" }),
    freeze({ id = "live.popup.commit_added_unchanged", category = "popup", labelKey = "EAM_LIVE_CASE_COMMIT" }),
    freeze({ id = "live.tooltip.reload_resume", category = "reload", labelKey = "EAM_LIVE_CASE_RELOAD" }),
    freeze({ id = "live.blizzard_input_unchanged", category = "input", labelKey = "EAM_LIVE_CASE_INPUT" }),
    freeze({ id = "live.popup.combat_transition", category = "combat", labelKey = "EAM_LIVE_CASE_COMBAT_TRANSITION" }),
    freeze({ id = "live.tooltip.generation_switch", category = "tooltip", labelKey = "EAM_LIVE_CASE_GENERATION" }),
    freeze({ id = "live.api.load_order", category = "lifecycle", labelKey = "EAM_LIVE_CASE_LOAD_ORDER" }),
    freeze({ id = "live.errors.none_observed", category = "safety", labelKey = "EAM_LIVE_CASE_ERRORS" }),
    freeze({ id = "live.layout.timer_anchor_size", category = "layout", labelKey = "EAM_LIVE_CASE_TIMER_LAYOUT" }),
    freeze({ id = "live.layout.applications_anchor_size", category = "layout", labelKey = "EAM_LIVE_CASE_APPLICATIONS_LAYOUT" }),
    freeze({ id = "live.aura.single_countdown", category = "aura", labelKey = "EAM_LIVE_CASE_AURA_SINGLE_COUNTDOWN" }),
    freeze({ id = "live.aura.dual_countdown_diagnostic", category = "aura", labelKey = "EAM_LIVE_CASE_AURA_DUAL_COUNTDOWN" }),
    freeze({ id = "live.cooldown.spell_countdown", category = "cooldown", labelKey = "EAM_LIVE_CASE_SPELL_COOLDOWN" }),
    freeze({ id = "live.cooldown.item_trigger", category = "cooldown", labelKey = "EAM_LIVE_CASE_ITEM_COOLDOWN" }),
    freeze({ id = "live.ground.duration_auto", category = "ground", labelKey = "EAM_LIVE_CASE_GROUND_AUTO" }),
    freeze({ id = "live.ground.duration_manual_fallback", category = "ground", labelKey = "EAM_LIVE_CASE_GROUND_FALLBACK" }),
    freeze({ id = "live.visual.swipe_alpha", category = "visual", labelKey = "EAM_LIVE_CASE_SWIPE_ALPHA" }),
    freeze({ id = "live.aura.target_transition", category = "aura", labelKey = "EAM_LIVE_CASE_TARGET_AURA_TRANSITION" }),
    freeze({ id = "live.aura.native_border_capability", category = "aura", labelKey = "EAM_LIVE_CASE_NATIVE_BORDER" }),
    freeze({ id = "live.aura.native_pandemic_region", category = "aura", labelKey = "EAM_LIVE_CASE_NATIVE_PANDEMIC" }),
    freeze({ id = "live.aura.native_dispel_options", category = "aura", labelKey = "EAM_LIVE_CASE_NATIVE_DISPEL_OPTIONS" }),
    freeze({ id = "live.aura.container_disable_clear", category = "aura", labelKey = "EAM_LIVE_CASE_CONTAINER_DISABLE_CLEAR" }),
    freeze({ id = "live.unitpower.secondary_numeric", category = "unitpower", labelKey = "EAM_LIVE_CASE_UNITPOWER_SECONDARY" }),
    freeze({ id = "live.unitpower.primary_native_sink", category = "unitpower", labelKey = "EAM_LIVE_CASE_UNITPOWER_PRIMARY" }),
    freeze({ id = "live.unitpower.combat_deferred", category = "unitpower", labelKey = "EAM_LIVE_CASE_UNITPOWER_COMBAT" }),
    freeze({ id = "live.aura.duration_zero_regression", category = "aura", labelKey = "EAM_LIVE_CASE_DURATION_ZERO" }),
})

local CASE_BY_ID = {}
for index = 1, #CASES do
    CASE_BY_ID[CASES[index].id] = CASES[index]
end
CASE_BY_ID = freeze(CASE_BY_ID)

local LiveTestSession = {
    schemaVersion = 1,
    matrixVersion = MATRIX_VERSION,
    cases = CASES,
    caseByID = CASE_BY_ID,
}

EAM.Debug.LiveTestSession = LiveTestSession

local function isUNCComponentByte(byteValue)
    return byteValue ~= nil
        and byteValue ~= 9
        and byteValue ~= 10
        and byteValue ~= 13
        and byteValue ~= 32
        and byteValue ~= 47
        and byteValue ~= 92
end

local function containsUNCPath(value)
    local valueLength = #value
    for index = 1, valueLength - 3 do
        if string.byte(value, index) == 92 and string.byte(value, index + 1) == 92 then
            local serverStart = index + 2
            local cursor = serverStart
            while cursor <= valueLength and isUNCComponentByte(string.byte(value, cursor)) do
                cursor = cursor + 1
            end
            if cursor > serverStart and string.byte(value, cursor) == 92 then
                local shareStart = cursor + 1
                cursor = shareStart
                while cursor <= valueLength and isUNCComponentByte(string.byte(value, cursor)) do
                    cursor = cursor + 1
                end
                if cursor > shareStart then
                    return true
                end
            end
        end
    end
    return false
end

local function nowValue()
    if type(api.GetServerTime) == "function" then
        local ok, value = pcall(api.GetServerTime)
        if ok and type(value) == "number" and not (util.isSecretValue and util.isSecretValue(value)) then
            return value
        end
    end
    if type(api.GetTime) == "function" then
        local value = api.GetTime()
        if type(value) == "number" and not (util.isSecretValue and util.isSecretValue(value)) then
            return math.floor(value)
        end
    end
    return 0
end

local function safeNote(value)
    if type(value) ~= "string" then
        return ""
    end
    if util.isSecretValue and util.isSecretValue(value) then
        return ""
    end
    if util.canAccessValue and not util.canAccessValue(value) then
        return ""
    end
    value = string.gsub(value, "[%z\1-\8\11\12\14-\31]", " ")
    local lowered = string.lower(value)
    local containsSavedVariablesPath = string.find(lowered, "savedvariables", 1, true) ~= nil
    local containsPrivatePath = string.match(value, "%a:[/\\]") ~= nil
        or string.find(lowered, "\\wtf\\", 1, true) ~= nil
        or string.find(lowered, "/wtf/", 1, true) ~= nil
        or string.find(lowered, "\\account\\", 1, true) ~= nil
        or string.find(lowered, "/account/", 1, true) ~= nil
    if containsPrivatePath or containsUNCPath(value) or containsSavedVariablesPath then
        return PRIVACY_REDACTED_NOTE
    end
    local characters = 0
    for index = 1, #value do
        local byte = string.byte(value, index)
        if byte < 128 or byte >= 192 then
            characters = characters + 1
            if characters > 500 then
                return string.sub(value, 1, index - 1)
            end
        end
    end
    return value
end

local function hasReloadEvidence(state)
    return state
        and state.resumedAfterReload == true
        and type(state.reloadSequence) == "number"
        and state.reloadSequence >= 1
end

local function validState(state)
    return type(state) == "table"
        and state.schema == LiveTestSession.schemaVersion
        and state.matrixVersion == MATRIX_VERSION
        and type(state.cases) == "table"
end

local function getState()
    local state = _G.EAM_LIVE_TEST_SESSION
    return validState(state) and state or nil
end

local function createCaseState()
    local caseState = {}
    for index = 1, #CASES do
        caseState[CASES[index].id] = {
            status = "pending",
            note = "",
        }
    end
    return caseState
end

local function buildSessionID(declaredInstallation, sequence)
    local normalized = string.gsub(declaredInstallation, "[^%w]", "")
    return string.format("EAM-RQA-%s-%d-%d", normalized, nowValue(), sequence)
end

local function collectCapabilities()
    local auraCapability = EAM.Services and EAM.Services.AuraCapabilityService
    local tooltipMonitor = EAM.Services and EAM.Services.TooltipMonitorService
    local auraSnapshot = auraCapability and auraCapability.getSnapshot and auraCapability.getSnapshot() or {}
    local tooltipStatus = tooltipMonitor and tooltipMonitor.getStatus and tooltipMonitor.getStatus() or {}
    local nativeRenderer = EAM.UI and EAM.UI.NativeAuraRenderer
    local nativeStatus = nativeRenderer and nativeRenderer.getStatus and nativeRenderer.getStatus() or {}
    local groundEffect = EAM.Services and EAM.Services.GroundEffectService
    local groundStatus = groundEffect and groundEffect.getStatus and groundEffect.getStatus() or {}
    local cSecrets = api.C_Secrets
    return {
        hasGetBuildInfo = type(api.GetBuildInfo) == "function",
        hasTooltipDataProcessor = type(_G.TooltipDataProcessor) == "table"
            and type(_G.TooltipDataProcessor.AddTooltipPostCall) == "function",
        hasTooltipMonitor = tooltipMonitor and tooltipMonitor.initialized == true or false,
        auraBackend = type(auraSnapshot.selectedBackend) == "string" and auraSnapshot.selectedBackend or "unknown",
        hasAuraContainer = auraSnapshot.hasAuraContainer == true,
        hasAuraSlot = auraSnapshot.hasAuraSlot == true,
        hasAuraGroup = auraSnapshot.hasAuraGroup == true,
        auraSpellIDDisplayEnabled = tooltipStatus.auraIDDisplayEnabled == true,
        hasTextPlacementContract = EAM.UI and EAM.UI.TextPlacement ~= nil or false,
        hasDurationAdapter = EAM.Modules and EAM.Modules.DurationAdapter ~= nil or false,
        nativeAuraSingleCountdownDefault = nativeStatus.dualCountdownProbeEnabled ~= true,
        nativeAuraDispelBorderAvailable = nativeStatus.nativeDispelBorderAvailable == true,
        nativeAuraPandemicRegionAvailable = nativeStatus.hasPandemicRegionAPI == true,
        nativeAuraPandemicRegionBoundCount = nativeStatus.pandemicRegionBoundCount or 0,
        nativeAuraDispelTextureBoundCount = nativeStatus.nativeDispelTextureBoundCount or 0,
        hasUnitPower = type(api.UnitPower) == "function",
        hasUnitPowerMax = type(api.UnitPowerMax) == "function",
        hasUnitPowerPercent = type(api.UnitPowerPercent) == "function",
        hasUnitPowerSecretPredicate = cSecrets
            and type(cSecrets.ShouldUnitPowerBeSecret) == "function" or false,
        hasUnitPowerMaxSecretPredicate = cSecrets
            and type(cSecrets.ShouldUnitPowerMaxBeSecret) == "function" or false,
        hasUnitPowerCapabilityProbe = EAM.Debug and EAM.Debug.UnitPowerCapabilityProbe ~= nil or false,
        groundEffectStatus = groundStatus,
    }
end

local function buildReport()
    local state = getState()
    if not state then
        return nil, nil, "sessionUnavailable"
    end
    local validationEnvironment = EAM.Debug.ValidationEnvironment
    local environment, environmentWarnings = validationEnvironment.snapshot()
    local reportCases = {}
    local summary = {
        total = #CASES,
        required = #CASES,
        passed = 0,
        failed = 0,
        blocked = 0,
        pending = 0,
    }
    local privacyNoteRedacted = false
    for index = 1, #CASES do
        local definition = CASES[index]
        local savedCase = state.cases[definition.id] or {}
        local status = savedCase.status
        if status ~= "pass" and status ~= "fail" and status ~= "blocked" then
            status = "pending"
        end
        if status == "pass" then
            summary.passed = summary.passed + 1
        elseif status == "fail" then
            summary.failed = summary.failed + 1
        elseif status == "blocked" then
            summary.blocked = summary.blocked + 1
        else
            summary.pending = summary.pending + 1
        end
        local note = safeNote(savedCase.note)
        if note == PRIVACY_REDACTED_NOTE then
            privacyNoteRedacted = true
        end
        reportCases[index] = {
            id = definition.id,
            category = definition.category,
            required = true,
            status = status,
            note = note,
        }
    end

    local warnings = {}
    for index = 1, #environmentWarnings do
        warnings[#warnings + 1] = environmentWarnings[index]
    end
    if privacyNoteRedacted then
        warnings[#warnings + 1] = "privacyNoteRedacted"
    end
    if not hasReloadEvidence(state) then
        warnings[#warnings + 1] = "reloadCheckpointNotCompleted"
    end
    if environment.executionSource ~= "client" then
        warnings[#warnings + 1] = "offlineCannotSignoff"
    end

    local status = "pass"
    if summary.failed > 0 then
        status = "fail"
    elseif summary.blocked > 0
        or summary.pending > 0
        or state.phase ~= "complete"
        or environment.channelValidation ~= "pass"
        or environment.executionSource ~= "client"
        or #warnings > 0
    then
        status = "incomplete"
    end

    local report = {
        schema = LiveTestSession.schemaVersion,
        type = "EAM_LIVE_VALIDATION_REPORT",
        purpose = "rqa-signoff",
        matrixVersion = MATRIX_VERSION,
        status = status,
        session = {
            id = state.id,
            phase = state.phase,
            reloadSequence = state.reloadSequence or 0,
            resumedAfterReload = state.resumedAfterReload == true,
            humanObserved = true,
        },
        environment = environment,
        automation = {
            gameInputAutomated = false,
            reloadUIAutomated = false,
            playerOperated = true,
        },
        capabilities = collectCapabilities(),
        summary = summary,
        cases = reportCases,
        boundaryWarnings = warnings,
    }
    local encoder = EAM.Debug.FlowTestRunner and EAM.Debug.FlowTestRunner.encodeJSON
    if not encoder then
        return report, nil, "jsonEncoderUnavailable"
    end
    local reportJSON = encoder(report)
    _G.EAM_LIVE_TEST_REPORT_JSON = reportJSON
    return report, reportJSON, nil
end

local function reportReadyForCompletion(report)
    return report
        and report.summary.total == #CASES
        and report.summary.passed == #CASES
        and report.summary.failed == 0
        and report.summary.blocked == 0
        and report.summary.pending == 0
        and report.environment.executionSource == "client"
        and report.environment.channelValidation == "pass"
        and report.environment.isTestBuildKnown == true
        and #report.boundaryWarnings == 0
end

function LiveTestSession.getState()
    return getState()
end

function LiveTestSession.start(declaredInstallation)
    local existing = getState()
    if existing and existing.phase == "active" then
        return false, "sessionAlreadyActive"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    local validationEnvironment = EAM.Debug.ValidationEnvironment
    local ok, reason = validationEnvironment.setDeclaredInstallation(declaredInstallation)
    if not ok then
        return false, reason
    end
    local sequence = existing and (existing.sequence or 0) + 1 or 1
    _G.EAM_LIVE_TEST_SESSION = {
        schema = LiveTestSession.schemaVersion,
        matrixVersion = MATRIX_VERSION,
        id = buildSessionID(declaredInstallation, sequence),
        sequence = sequence,
        phase = "active",
        declaredInstallation = declaredInstallation,
        startedAt = nowValue(),
        reloadSequence = 0,
        resumedAfterReload = false,
        reloadCheckpoint = nil,
        cases = createCaseState(),
    }
    buildReport()
    return true, _G.EAM_LIVE_TEST_SESSION.id
end

function LiveTestSession.setCaseStatus(caseID, status, note)
    local state = getState()
    if not state or state.phase ~= "active" then
        return false, "sessionUnavailable"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    if not CASE_BY_ID[caseID] then
        return false, "unknownCase"
    end
    if status ~= "pending" and status ~= "pass" and status ~= "fail" and status ~= "blocked" then
        return false, "invalidStatus"
    end
    local savedCase = state.cases[caseID]
    savedCase.status = status
    if note ~= nil then
        savedCase.note = safeNote(note)
    end
    savedCase.observedAt = nowValue()
    buildReport()
    return true, status
end

function LiveTestSession.setCaseNote(caseID, note)
    local state = getState()
    if not state or not state.cases[caseID] then
        return false, "sessionUnavailable"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    state.cases[caseID].note = safeNote(note)
    buildReport()
    return true
end

function LiveTestSession.prepareReload()
    local state = getState()
    if not state or state.phase ~= "active" then
        return false, "sessionUnavailable"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    state.reloadCheckpoint = {
        pending = true,
        requestedAt = nowValue(),
        expectedSequence = (state.reloadSequence or 0) + 1,
        bootToken = BOOT_TOKEN,
    }
    buildReport()
    return true, "checkpointSaved"
end

function LiveTestSession.resumePendingReload()
    local state = getState()
    local checkpoint = state and state.reloadCheckpoint
    if not checkpoint or checkpoint.pending ~= true then
        return false, "checkpointUnavailable"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    if checkpoint.bootToken == BOOT_TOKEN then
        return false, "sameLoadRejected"
    end
    checkpoint.pending = false
    checkpoint.bootToken = nil
    checkpoint.resumed = true
    checkpoint.resumedAt = nowValue()
    state.reloadSequence = checkpoint.expectedSequence or ((state.reloadSequence or 0) + 1)
    state.resumedAfterReload = true
    buildReport()
    return true, "checkpointResumed"
end

function LiveTestSession.buildReport()
    return buildReport()
end

function LiveTestSession.complete()
    local state = getState()
    if not state then
        return false, "sessionUnavailable"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    if not hasReloadEvidence(state) then
        local report = buildReport()
        return false, "reloadRequired", report
    end
    local report = buildReport()
    if not reportReadyForCompletion(report) then
        return false, "sessionIncomplete", report
    end
    state.phase = "complete"
    report = buildReport()
    return true, "complete", report
end

function LiveTestSession.cancel()
    local state = getState()
    if not state or state.phase ~= "active" then
        return false, "sessionUnavailable"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    _G.EAM_LIVE_TEST_SESSION = nil
    _G.EAM_LIVE_TEST_REPORT_JSON = nil
    return true, "cancelled"
end

LiveTestSession.resumePendingReload()
