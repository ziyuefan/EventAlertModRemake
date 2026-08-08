--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/FlowTestRunner
檔案: Debug\FlowTestRunner.lua

理念:
- 使用同一組案例支援離線 Mock 與 Retail/PTR 實機流程驗證。
- 將限制檢查、語法檢查以外的事件、排程、初始化、設定與報告流程轉成可重播證據。

責任:
- 註冊流程案例、執行 suite、處理同步與非同步結果。
- 產生不含 Secret 原值的 JSON 報告，保存最近一次使用者觸發結果。

資料所有權:
- 擁有瞬時 test session、lastReport 與 lastSummary。
- 只寫獨立 SavedVariables 字串 EAM_FLOW_TEST_REPORT_JSON，不寫 EAM_DB runtime facts。

邊界:
- 不讀 Aura/Cooldown 原始資料，不模擬成功實機結果。
- 不在背景自動執行，不在戰鬥中開始流程測試。
- 不建立 UI；按鈕由 Debug/FlowTestPanel 管理。

效能注意:
- 僅使用者或離線 harness 主動執行；允許有限 transient table 與字串。
- 非同步案例只使用既有中央 Scheduler，不建立額外 OnUpdate。

Retail API 注意:
- 報告環境欄位需先通過 Secret/access 檢查。
- Mock 通過與 Retail/PTR 實機通過必須以 source 欄位分離。
]]
local _, EAM = ...

local util = EAM.Util or {}
local api = EAM.API or {}

local FlowTestRunner = {
    schemaVersion = 2,
    cases = {},
    caseCount = 0,
    running = false,
    lastReport = nil,
    lastReportJSON = nil,
    lastSummary = nil,
}

EAM.Debug.FlowTestRunner = FlowTestRunner

local STATUS_PASS = "pass"
local STATUS_FAIL = "fail"
local STATUS_SKIP = "skip"
local STATUS_PENDING = "pending"

local function nowMilliseconds()
    if api.debugprofilestop then
        local value = api.debugprofilestop()
        if type(value) == "number" and not (util.isSecretValue and util.isSecretValue(value)) then
            return value
        end
    end

    if api.GetTime then
        local value = api.GetTime()
        if type(value) == "number" and not (util.isSecretValue and util.isSecretValue(value)) then
            return value * 1000
        end
    end

    return 0
end

local function safeScalar(value)
    if value == nil then
        return nil
    end

    if util.isSecretValue and util.isSecretValue(value) then
        return nil
    end
    if util.canAccessValue and not util.canAccessValue(value) then
        return nil
    end

    local valueType = type(value)
    if valueType == "string" or valueType == "number" or valueType == "boolean" then
        return value
    end
    return nil
end

local function safeMessage(value, fallback)
    local safe = safeScalar(value)
    if type(safe) == "string" then
        return safe
    end
    return fallback or "unavailable"
end

local function escapeJSON(value)
    return string.gsub(value, '[%z\1-\31\\"]', function(character)
        if character == '"' then
            return '\\"'
        elseif character == "\\" then
            return "\\\\"
        elseif character == "\b" then
            return "\\b"
        elseif character == "\f" then
            return "\\f"
        elseif character == "\n" then
            return "\\n"
        elseif character == "\r" then
            return "\\r"
        elseif character == "\t" then
            return "\\t"
        end
        return string.format("\\u%04x", string.byte(character))
    end)
end

local function classifyArray(value)
    local count = 0
    local maximum = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false, 0
        end
        count = count + 1
        if key > maximum then
            maximum = key
        end
    end
    return maximum == count, maximum
end

local function encodeJSON(value, stack)
    local valueType = type(value)
    if valueType == "nil" then
        return "null"
    elseif valueType == "boolean" then
        return value and "true" or "false"
    elseif valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return "null"
        end
        return tostring(value)
    elseif valueType == "string" then
        return '"' .. escapeJSON(value) .. '"'
    elseif valueType ~= "table" then
        return "null"
    end

    stack = stack or {}
    if stack[value] then
        return "null"
    end
    stack[value] = true

    local isArray, length = classifyArray(value)
    local buffer = {}
    if isArray then
        for index = 1, length do
            buffer[index] = encodeJSON(value[index], stack)
        end
        stack[value] = nil
        return "[" .. table.concat(buffer, ",") .. "]"
    end

    local keys = {}
    local keyCount = 0
    for key in pairs(value) do
        if type(key) == "string" then
            keyCount = keyCount + 1
            keys[keyCount] = key
        end
    end
    table.sort(keys)

    for index = 1, keyCount do
        local key = keys[index]
        buffer[index] = '"' .. escapeJSON(key) .. '":' .. encodeJSON(value[key], stack)
    end

    stack[value] = nil
    return "{" .. table.concat(buffer, ",") .. "}"
end

FlowTestRunner.encodeJSON = encodeJSON

function FlowTestRunner.registerCase(definition)
    if type(definition) ~= "table"
        or type(definition.id) ~= "string"
        or type(definition.run) ~= "function"
        or FlowTestRunner.cases[definition.id]
    then
        return false
    end

    local count = FlowTestRunner.caseCount + 1
    definition.order = count
    FlowTestRunner.cases[definition.id] = definition
    FlowTestRunner[count] = definition
    FlowTestRunner.caseCount = count
    return true
end

local function matchesSuite(definition, suite)
    if suite == "all" then
        return true
    end
    return definition.suites and definition.suites[suite] == true
end

local function buildEnvironment()
    local validationEnvironment = EAM.Debug and EAM.Debug.ValidationEnvironment
    local environment, warnings
    if validationEnvironment and validationEnvironment.snapshot then
        environment, warnings = validationEnvironment.snapshot()
    else
        environment = {
            product = "wow_retail",
            executionSource = "unknown",
            clientChannel = "UNCONFIRMED",
            declaredInstallation = "unconfirmed",
            interface = 0,
            source = "environment-module-unavailable",
            channelValidation = "unconfirmed",
        }
        warnings = { "validationEnvironmentUnavailable" }
    end

    environment.addon = "EventAlertMod"
    environment.addonVersion = safeScalar(EAM.version) or "unknown"
    environment.flavor = EAM.Constants and EAM.Constants.ADDON_FLAVOR or "Retail"
    environment.initialized = EAM.Modules and EAM.Modules.Main and EAM.Modules.Main.initialized == true or false
    environment.inCombat = api.InCombatLockdown and api.InCombatLockdown() == true or false
    return environment, warnings
end

local function finalizeSession(session)
    if session.finished then
        return
    end
    session.finished = true
    FlowTestRunner.running = false

    local summary = {
        total = #session.results,
        passed = 0,
        failed = 0,
        skipped = 0,
        pending = 0,
    }

    for index = 1, #session.results do
        local status = session.results[index].status
        if status == STATUS_PASS then
            summary.passed = summary.passed + 1
        elseif status == STATUS_FAIL then
            summary.failed = summary.failed + 1
        elseif status == STATUS_SKIP then
            summary.skipped = summary.skipped + 1
        elseif status == STATUS_PENDING then
            summary.pending = summary.pending + 1
        end
    end

    local environment, environmentWarnings = buildEnvironment()
    for index = 1, #environmentWarnings do
        session.boundaryWarnings[#session.boundaryWarnings + 1] = environmentWarnings[index]
    end

    local reportStatus = STATUS_PASS
    if summary.failed > 0 then
        reportStatus = STATUS_FAIL
    elseif summary.skipped > 0
        or summary.pending > 0
        or environment.channelValidation ~= "pass"
        or #session.boundaryWarnings > 0
    then
        reportStatus = "incomplete"
    end

    local report = {
        schema = FlowTestRunner.schemaVersion,
        type = "EAM_FLOW_VALIDATION_REPORT",
        purpose = environment.executionSource == "offline-mock" and "offline-contract" or "capability-probe",
        matrixVersion = "2026-08-08.1",
        suite = session.suite,
        status = reportStatus,
        generatedAtSessionMs = nowMilliseconds(),
        session = {
            phase = "complete",
            humanObserved = false,
            gameInputAutomated = false,
        },
        environment = environment,
        summary = summary,
        cases = session.results,
        boundaryWarnings = session.boundaryWarnings,
    }

    local reportJSON = encodeJSON(report)
    FlowTestRunner.lastReport = report
    FlowTestRunner.lastReportJSON = reportJSON
    FlowTestRunner.lastSummary = summary
    _G.EAM_FLOW_TEST_REPORT_JSON = reportJSON

    if session.onComplete then
        local ok, err = pcall(session.onComplete, report, reportJSON)
        if not ok and EAM.addDebugLog then
            EAM.addDebugLog("FlowTestRunner", "onComplete", safeMessage(err, "callback failed"))
        end
    end
end

local function completeCase(session, result, passed, message, status)
    if result.completed then
        return
    end
    result.completed = true
    result.status = status or (passed and STATUS_PASS or STATUS_FAIL)
    result.message = safeMessage(message, passed and "completed" or "failed")
    result.durationMs = math.max(0, nowMilliseconds() - result.startedAt)
    result.startedAt = nil
    session.remaining = session.remaining - 1

    if session.started and session.remaining == 0 then
        finalizeSession(session)
    end
end

local function executeCase(session, definition)
    local result = {
        id = definition.id,
        suite = definition.primarySuite or "core",
        status = STATUS_PENDING,
        message = "pending",
        durationMs = 0,
        startedAt = nowMilliseconds(),
        completed = false,
    }

    session.results[#session.results + 1] = result
    session.remaining = session.remaining + 1

    local context = {
        complete = function(passed, message, status)
            completeCase(session, result, passed == true, message, status)
        end,
    }

    local ok, state, message = pcall(definition.run, context)
    if not ok then
        completeCase(session, result, false, safeMessage(state, "case error"))
    elseif state == STATUS_PENDING then
        return
    elseif state == STATUS_SKIP then
        completeCase(session, result, true, message or "skipped", STATUS_SKIP)
    else
        completeCase(session, result, state == true, message)
    end
end

function FlowTestRunner.runSuite(suite, onComplete)
    suite = string.lower(suite or "quick")
    if suite ~= "quick" and suite ~= "core" and suite ~= "boundary" and suite ~= "aura121" and suite ~= "all" then
        return false, "unknownSuite"
    end
    if FlowTestRunner.running then
        return false, "alreadyRunning"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end

    local session = {
        suite = suite,
        results = {},
        boundaryWarnings = {},
        remaining = 0,
        started = false,
        finished = false,
        onComplete = onComplete,
    }

    FlowTestRunner.running = true
    for index = 1, FlowTestRunner.caseCount do
        local definition = FlowTestRunner[index]
        if matchesSuite(definition, suite) then
            executeCase(session, definition)
        end
    end

    session.started = true
    if session.remaining == 0 then
        finalizeSession(session)
    end
    return true, session.remaining > 0 and STATUS_PENDING or STATUS_PASS
end

function FlowTestRunner.getLastReport()
    return FlowTestRunner.lastReport
end

function FlowTestRunner.getLastReportJSON()
    return FlowTestRunner.lastReportJSON or _G.EAM_FLOW_TEST_REPORT_JSON or "{}"
end

function FlowTestRunner.getLastSummary()
    return FlowTestRunner.lastSummary
end

FlowTestRunner.registerCase({
    id = "boot.initialized",
    primarySuite = "core",
    suites = { quick = true, core = true },
    run = function()
        local main = EAM.Modules and EAM.Modules.Main
        local valid = main and main.initialized == true
        return valid, valid and "Main initialized" or "Main not initialized"
    end,
})

local function buildAura121TestDB(revision)
    return {
        schemaVersion = EAM.Constants.SCHEMA_VERSION,
        revision = revision or 121,
        alerts = {
            playerAuras = {
                ["aura:player:1001"] = { id = "aura:player:1001", kind = "aura", unit = "player", spellID = 1001, enabled = true, auraFilter = "HELPFUL" },
                ["aura:player:1002"] = { id = "aura:player:1002", kind = "aura", unit = "player", spellID = 1002, enabled = true, auraFilter = "HELPFUL" },
                ["aura:player:1003"] = { id = "aura:player:1003", kind = "aura", unit = "player", spellID = 1003, enabled = true, auraFilter = "HELPFUL" },
            },
            targetAuras = {
                ["aura:target:2001"] = { id = "aura:target:2001", kind = "aura", unit = "target", spellID = 2001, enabled = true, auraFilter = "HARMFUL", fromPlayer = true },
            },
            spellCooldowns = {},
            itemCooldowns = {},
            groundEffects = {},
        },
        config = {
            iconSize = 40,
            iconSpacing = 6,
        },
    }
end

FlowTestRunner.registerCase({
    id = "aura121.capability.native_complete",
    primarySuite = "aura121",
    suites = { aura121 = true },
    run = function()
        local service = EAM.Services and EAM.Services.AuraCapabilityService
        if not service then
            return false, "AuraCapabilityService unavailable"
        end
        local snapshot = service.getSnapshot()
        if (snapshot.clientInterface or 0) < EAM.Constants.INTERFACE then
            return STATUS_SKIP, "client is below 12.1"
        end
        local valid = snapshot.selectedBackend == EAM.Constants.AURA_BACKEND_NATIVE
            and snapshot.hasAuraContainer
            and snapshot.hasAuraSlot
            and snapshot.hasAuraGroup
            and snapshot.hasAuraGroupLayout
        return valid, valid and "12.1 native capability selected" or "12.1 native capability incomplete"
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.native.zero_legacy_pipeline",
    primarySuite = "aura121",
    suites = { aura121 = true },
    run = function()
        local capability = EAM.Services and EAM.Services.AuraCapabilityService
        if not capability or not capability.isNative() then
            return STATUS_SKIP, "native backend not active"
        end
        local router = EAM.Modules and EAM.Modules.EventRouter
        local auraService = EAM.Services and EAM.Services.AuraService
        local handlers = router and router.handlers and router.handlers.UNIT_AURA
        local valid = auraService and auraService.backendDisabled == true and handlers == nil
        local mock = EAM.FlowTestMock
        if valid and mock then
            mock.resetTrace()
            router.fire("UNIT_AURA", "player", mock.createSecretUnitAuraPayload())
            valid = mock.trace.unitAuraPayloadReads == 0 and mock.trace.auraGetterCalls == 0
        end
        return valid, valid and "native backend bypasses UNIT_AURA and AuraState" or "legacy Aura pipeline remains active"
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.compiler.slot_group",
    primarySuite = "aura121",
    suites = { aura121 = true },
    run = function()
        local compiler = EAM.Managers and EAM.Managers.AuraRuleCompiler
        if not compiler then
            return false, "AuraRuleCompiler unavailable"
        end
        local plan = compiler.compile(buildAura121TestDB(122), {
            backend = EAM.Constants.AURA_BACKEND_NATIVE,
        })
        local valid = plan.nativeSlotCount == 2
            and plan.nativeGroupCount == 1
            and #plan.rules == 3
            and plan.rules[1].slotKey ~= nil
            and plan.rules[3].groupKey ~= nil
        return valid, valid and "stable player/target slots and merged group compiled" or "slot/group compilation mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.container.rebuild_contract",
    primarySuite = "aura121",
    suites = { aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        if not mock then
            return STATUS_SKIP, "strict container mock is offline only"
        end
        local service = EAM.Services.AuraContainerService
        local originalDB = EAM.db
        EAM.db = buildAura121TestDB(123)
        service.lastPlan = nil
        mock.resetTrace()
        local ok = service.requestRebuild("flowTest")
        local valid = ok == true
            and mock.trace.containerCreates == 2
            and mock.trace.slotAdds == 2
            and mock.trace.groupAdds == 1
            and mock.trace.groupLayouts == 1
            and mock.trace.auraGetterCalls == 0
        EAM.db = originalDB
        service.lastPlan = nil
        service.requestRebuild("flowTestRestore")
        local message = valid and "player/target containers rebuilt without legacy getters" or string.format(
            "container rebuild mismatch creates=%d slots=%d groups=%d layouts=%d getters=%d",
            mock.trace.containerCreates,
            mock.trace.slotAdds,
            mock.trace.groupAdds,
            mock.trace.groupLayouts,
            mock.trace.auraGetterCalls
        )
        return valid, message
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.rebuild.combat_pending_once",
    primarySuite = "aura121",
    suites = { aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        if not mock then
            return STATUS_SKIP, "combat mutation mock is offline only"
        end
        local service = EAM.Services.AuraContainerService
        local originalDB = EAM.db
        EAM.db = buildAura121TestDB(124)
        service.lastPlan = nil
        mock.resetTrace()
        local before = service.rebuildCount
        mock.setCombat(true)
        local deferred, reason = service.requestRebuild("flowCombat")
        service.requestRebuild("flowCombatAgain")
        local noMutation = mock.trace.containerMutations == 0 and service.pending == true
        mock.setCombat(false)
        service.onCombatEnd()
        local rebuiltOnce = service.rebuildCount == before + 1 and service.pending == false
        EAM.db = originalDB
        service.lastPlan = nil
        service.requestRebuild("flowTestRestore")
        local valid = deferred == false and reason == "combatDeferred" and noMutation and rebuiltOnce
        local message = valid and "combat changes deferred and rebuilt once" or string.format(
            "combat pending mismatch deferred=%s reason=%s noMutation=%s rebuildBefore=%d rebuildAfter=%d pending=%s",
            tostring(deferred),
            tostring(reason),
            tostring(noMutation),
            before,
            service.rebuildCount,
            tostring(service.pending)
        )
        return valid, message
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.container.creation_bounded",
    primarySuite = "aura121",
    suites = { aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        if not mock then
            return STATUS_SKIP, "container lifecycle bound mock is offline only"
        end

        local service = EAM.Services.AuraContainerService
        local originalDB = EAM.db
        local fieldNames = {
            "pending",
            "pendingRevision",
            "current",
            "createdContainerCount",
            "maxCreatedContainerCount",
            "retiredContainerCount",
            "reloadRequired",
            "rebuildCount",
            "failedRebuildCount",
            "lastPlan",
            "lastReason",
        }
        local snapshot = {}
        for index = 1, #fieldNames do
            local field = fieldNames[index]
            snapshot[field] = service[field]
        end

        local ok, result, message = pcall(function()
            EAM.db = buildAura121TestDB(129)
            service.pending = false
            service.pendingRevision = nil
            service.current = nil
            service.createdContainerCount = 0
            service.maxCreatedContainerCount = 18
            service.retiredContainerCount = 0
            service.reloadRequired = false
            service.rebuildCount = 0
            service.failedRebuildCount = 0
            service.lastPlan = nil
            service.lastReason = nil
            mock.resetTrace()

            local firstBuilt = service.requestRebuild("boundedInitial")
            local successfulRebuilds = firstBuilt and 1 or 0
            local deniedReason
            for index = 1, 9 do
                local spellID = 5000 + index
                local alertID = "aura:player:" .. tostring(spellID)
                EAM.db.alerts.playerAuras[alertID] = {
                    id = alertID,
                    kind = "aura",
                    unit = "player",
                    spellID = spellID,
                    enabled = true,
                    auraFilter = "HELPFUL",
                }
                local rebuilt, reason = service.requestRebuild("boundedStructuralChange")
                if rebuilt then
                    successfulRebuilds = successfulRebuilds + 1
                else
                    deniedReason = reason
                    break
                end
            end

            local status = service.getStatus()
            local valid = firstBuilt == true
                and successfulRebuilds == 9
                and deniedReason == "nativeReloadRequired"
                and status.createdContainerCount == 18
                and status.maxCreatedContainerCount == 18
                and status.retiredContainerCount == 16
                and status.rebuildCount == 9
                and status.failedRebuildCount == 0
                and status.reloadRequired == true
                and status.lastReason == "nativeReloadRequired"
                and mock.trace.containerCreates == 18
            local detail = valid and "native containers are capped at 18 per load and then require /reload"
                or string.format(
                    "container bound mismatch successes=%d reason=%s created=%d retired=%d rebuilds=%d reload=%s",
                    successfulRebuilds,
                    tostring(deniedReason),
                    status.createdContainerCount,
                    status.retiredContainerCount,
                    status.rebuildCount,
                    tostring(status.reloadRequired)
                )
            return valid, detail
        end)

        EAM.db = originalDB
        for index = 1, #fieldNames do
            local field = fieldNames[index]
            service[field] = snapshot[field]
        end
        mock.setCombat(false)
        if not ok then
            return false, tostring(result)
        end
        return result, message
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.sound.lifecycle",
    primarySuite = "aura121",
    suites = { aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        if not mock then
            return STATUS_SKIP, "sound registry mock is offline only"
        end
        local service = EAM.Services.AuraSoundService
        service.removeAll()
        mock.resetTrace()
        local plan = {
            fingerprint = "flow-sound-121",
            soundRules = {
                {
                    alertID = "aura:player:3001",
                    unit = "player",
                    spellID = 3001,
                    sound = {
                        added = { soundFileID = 1 },
                        applicationsIncreased = { soundFileID = 2 },
                        removed = { soundFileID = 3 },
                    },
                },
            },
        }
        local capability = EAM.Services.AuraCapabilityService.getSnapshot()
        local ok = service.sync(plan, capability)
        service.sync(plan, capability)
        local registeredOnce = mock.trace.addAuraSoundCalls == 3 and service.activeCount == 3
        service.removeAll()
        local valid = ok == true and registeredOnce and mock.trace.removeAuraSoundCalls == 3
        return valid, valid and "three Aura Sound triggers registered and removed exactly once" or "Aura Sound lifecycle mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.saved_variables.noop_revision",
    primarySuite = "aura121",
    suites = { aura121 = true },
    run = function()
        local saved = EAM.Modules.SavedVariables
        local originalDB = EAM.db
        EAM.db = buildAura121TestDB(125)
        local ok, _, state = saved.addAuraAlert("player", 1001, { auraFilter = "HELPFUL" })
        local revision = EAM.db.revision
        local okAgain, _, stateAgain = saved.addAuraAlert("player", 1001, { auraFilter = "HELPFUL" })
        local valid = ok and okAgain and state == "unchanged" and stateAgain == "unchanged" and EAM.db.revision == revision
        EAM.db = originalDB
        return valid, valid and "unchanged Aura setting preserves revision" or "unchanged Aura setting changed revision"
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.compat.120007_no_native_calls",
    primarySuite = "aura121",
    suites = { aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        if not mock then
            return STATUS_SKIP, "interface switching mock is offline only"
        end
        local capability = EAM.Services.AuraCapabilityService
        local container = EAM.Services.AuraContainerService
        mock.interface = EAM.Constants.LEGACY_INTERFACE
        capability.initialized = false
        capability.initialize()
        mock.resetTrace()
        local rebuilt, reason = container.requestRebuild("legacyCompatibility")
        local valid = capability.isLegacy()
            and rebuilt == false
            and reason == "legacyBackend"
            and mock.trace.containerCreates == 0

        mock.interface = EAM.Constants.INTERFACE
        capability.initialized = false
        capability.initialize()
        if container.current and container.current.player then
            capability.acceptContainer(container.current.player)
        end
        return valid, valid and "12.0.7 selects Legacy without 12.1 container calls" or "12.0.7 compatibility contract mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.saved_variables.migration_v1_v4",
    primarySuite = "aura121",
    suites = { aura121 = true },
    run = function()
        if EAM.FlowTestEnvironment ~= "offline-mock" then
            return STATUS_SKIP, "migration fixture is offline only"
        end
        local saved = EAM.Modules.SavedVariables
        local originalGlobalDB = EAM_DB
        local originalDB = EAM.db
        EAM_DB = {
            schemaVersion = 1,
            revision = 9,
            customField = "preserve-me",
            alerts = {
                playerAuras = {
                    ["aura:player:4001"] = {
                        id = "aura:player:4001",
                        kind = "aura",
                        unit = "player",
                        spellID = 4001,
                        enabled = true,
                        unknownField = "keep",
                    },
                },
                targetAuras = {},
                spellCooldowns = {},
                itemCooldowns = {},
                groundEffects = {},
            },
            config = {
                timerInside = false,
                timerPosition = "TOPLEFT",
                stackInside = true,
                stackPosition = "RIGHT",
                fontSizeTimeVal = 21,
                fontSizeStack = 22,
            },
        }
        saved.initialize()
        local alert = EAM_DB.alerts.playerAuras["aura:player:4001"]
        local backup = EAM_DB.migrationBackups and EAM_DB.migrationBackups.auraSchemaV1
        local textLayout = EAM_DB.config and EAM_DB.config.textLayout
        local textLayoutBackup = EAM_DB.migrationBackups and EAM_DB.migrationBackups.textLayoutV2
        local valid = EAM_DB.schemaVersion == 4
            and EAM_DB.revision == 9
            and EAM_DB.customField == "preserve-me"
            and alert and alert.unknownField == "keep"
            and alert.nativeBackend == "AUTO"
            and backup ~= nil
            and backup.playerAuras ~= nil
            and backup.playerAuras["aura:player:4001"] ~= nil
            and textLayout ~= nil
            and textLayout.timer.placement == "OUTSIDE_TOP_AT_LEFT"
            and textLayout.timer.fontSize == 21
            and textLayout.applications.placement == "INSIDE_RIGHT"
            and textLayout.applications.fontSize == 22
            and textLayoutBackup ~= nil
            and textLayoutBackup.timerInside == false
            and textLayoutBackup.timerPosition == "TOPLEFT"
            and textLayoutBackup.stackInside == true
            and textLayoutBackup.stackPosition == "RIGHT"
            and textLayoutBackup.fontSizeTimeVal == 21
            and textLayoutBackup.fontSizeStack == 22
        EAM_DB = originalGlobalDB
        EAM.db = originalDB
        return valid, valid and "schema v1 migrated through v4 with backups and unknown fields preserved" or "schema v1-v4 migration contract mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.saved_variables.future_schema_preserved",
    primarySuite = "aura121",
    suites = { aura121 = true },
    run = function()
        if EAM.FlowTestEnvironment ~= "offline-mock" then
            return STATUS_SKIP, "future schema fixture is offline only"
        end
        local saved = EAM.Modules.SavedVariables
        local originalGlobalDB = EAM_DB
        local originalDB = EAM.db
        local report = saved.migrationReport
        local originalPreserved = report.futureSchemaPreserved
        local originalVersion = report.futureSchemaVersion
        local futureDB = {
            schemaVersion = EAM.Constants.SCHEMA_VERSION + 50,
            revision = 77,
            sentinel = {
                nested = "keep",
            },
            config = {
                textLayout = {
                    schema = 99,
                    timer = {
                        placement = "FUTURE_ONLY",
                        fontSize = 77,
                    },
                },
            },
        }
        EAM_DB = futureDB
        local runtimeDB = saved.initialize()
        local valid = rawequal(EAM_DB, futureDB)
            and not rawequal(runtimeDB, futureDB)
            and futureDB.schemaVersion == EAM.Constants.SCHEMA_VERSION + 50
            and futureDB.revision == 77
            and futureDB.sentinel.nested == "keep"
            and futureDB.config.textLayout.schema == 99
            and futureDB.config.textLayout.timer.placement == "FUTURE_ONLY"
            and futureDB.config.textLayout.timer.fontSize == 77
            and runtimeDB.schemaVersion == EAM.Constants.SCHEMA_VERSION
            and runtimeDB.futureSchemaSourceVersion == EAM.Constants.SCHEMA_VERSION + 50
            and runtimeDB.migrationWarnings[1] == "futureSchemaPreserved"
            and rawequal(EAM.db, runtimeDB)
            and report.futureSchemaPreserved == true
            and report.futureSchemaVersion == EAM.Constants.SCHEMA_VERSION + 50
        EAM_DB = originalGlobalDB
        EAM.db = originalDB
        report.futureSchemaPreserved = originalPreserved
        report.futureSchemaVersion = originalVersion
        return valid, valid and "future schema source remains field-compatible while runtime uses safe defaults"
            or "future schema preservation contract mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "ui.text_layout.contract_all_placements",
    primarySuite = "boundary",
    suites = { boundary = true, aura121 = true },
    run = function()
        local textPlacement = EAM.UI and EAM.UI.TextPlacement
        if not textPlacement then
            return false, "TextPlacement unavailable"
        end
        local seen = {}
        local valid = #textPlacement.orderedPlacements == 21
        for index = 1, #textPlacement.orderedPlacements do
            local placement = textPlacement.orderedPlacements[index]
            local definition = textPlacement.placements[placement]
            if seen[placement]
                or type(definition) ~= "table"
                or type(definition[1]) ~= "string"
                or type(definition[2]) ~= "string"
                or type(definition[3]) ~= "number"
                or type(definition[4]) ~= "number"
            then
                valid = false
                break
            end
            seen[placement] = true
        end
        return valid, valid and "21 canonical text placements are unique and complete" or "text placement contract mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.native.initialize_only_binding",
    primarySuite = "aura121",
    suites = { aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local nativeRenderer = EAM.UI and EAM.UI.NativeAuraRenderer
        if not mock or not nativeRenderer then
            return STATUS_SKIP, "native text layout mock is offline only"
        end
        local originalDB = EAM.db
        local originalApplyCount = nativeRenderer.textLayoutApplyCount
        local originalInitializedCount = nativeRenderer.initializedButtonCount
        local ok, result, message = pcall(function()
            EAM.db = buildAura121TestDB(126)
            EAM.db.config.textLayout = {
                schema = 1,
                timer = { placement = "OUTSIDE_RIGHT_AT_TOP", fontSize = 18 },
                applications = { placement = "OUTSIDE_BOTTOM_AT_LEFT", fontSize = 20 },
            }
            EAM.db.config.fontSizeSpellName = 12
            EAM.db.config.cooldownSwipeAlpha = 0.35
            EAM.db.config.nativeAuraDualCountdownProbe = false
            mock.resetTrace()
            local button = mock.createAuraButtonForTest()
            local initializer = nativeRenderer.createInitializer({
                style = {
                    showCountdown = true,
                    showStacks = true,
                    showName = true,
                },
                layout = {
                    elementWidth = 40,
                    elementSpacing = 6,
                },
            }, nil, nil)
            initializer(button)
            local timerPoint = button.durationText and button.durationText.lastPoint
            local applicationsPoint = button.applicationCount and button.applicationCount.lastPoint
            local initialValid = button.eamNativeInitialized == true
                and button.durationText ~= nil
                and button.applicationCount ~= nil
                and button.spellName ~= nil
                and timerPoint and timerPoint.point == "TOPLEFT"
                and timerPoint.relativePoint == "TOPRIGHT"
                and timerPoint.x == 4 and timerPoint.y == 0
                and applicationsPoint and applicationsPoint.point == "TOPLEFT"
                and applicationsPoint.relativePoint == "BOTTOMLEFT"
                and applicationsPoint.x == 0 and applicationsPoint.y == -2
                and button.durationText.fontSize == 18
                and button.applicationCount.fontSize == 20
                and button.spellName.fontSize == 12
                and button.cooldown.hideCountdownNumbers == true
                and button.cooldown.swipeAlpha == 0.35

            mock.lockAuraButtonForTest(button)
            local pointsBefore = mock.trace.regionSetPoints
            local fontsBefore = mock.trace.regionSetFonts
            local reapplied, reapplyReason = nativeRenderer.applyTextLayout()
            local mutationAllowed = pcall(function()
                button:SetSize(50, 50)
            end)
            local valid = initialValid
                and reapplied == false
                and reapplyReason == "nativeRebuildRequired"
                and mutationAllowed == false
                and mock.trace.postInitializationMutations == 1
                and mock.trace.regionSetPoints == pointsBefore
                and mock.trace.regionSetFonts == fontsBefore
                and mock.trace.auraGetterCalls == 0
            return valid, valid and "native bindings stay inside initializeFrame and post-init mutation is rejected"
                or "native initialize-only binding contract mismatch"
        end)
        EAM.db = originalDB
        nativeRenderer.textLayoutApplyCount = originalApplyCount
        nativeRenderer.initializedButtonCount = originalInitializedCount
        if not ok then
            return false, tostring(result)
        end
        return result, message
    end,
})

FlowTestRunner.registerCase({
    id = "ui.text_layout.general_reapply_combat_deferred",
    primarySuite = "boundary",
    suites = { boundary = true, aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local renderer = EAM.UI and EAM.UI.Renderer
        if not mock or not renderer then
            return STATUS_SKIP, "general renderer text layout mock is offline only"
        end

        local originalDB = EAM.db
        local originalFrames = renderer.frames
        local originalPending = renderer.textLayoutPending
        local originalCombat = mock.inCombat
        local ok, result, message = pcall(function()
            EAM.db = buildAura121TestDB(128)
            EAM.db.config.textLayout = {
                schema = 1,
                timer = { placement = "OUTSIDE_RIGHT_AT_TOP", fontSize = 18 },
                applications = { placement = "OUTSIDE_BOTTOM_AT_LEFT", fontSize = 20 },
            }
            local icon = mock.createAuraButtonForTest()
            icon.overlay = icon
            icon.timerText = icon:CreateFontString()
            icon.stackText = icon:CreateFontString()
            icon.nameText = icon:CreateFontString()
            icon.rendered = {}
            renderer.frames = {
                fixture = {
                    parent = nil,
                    icons = { fixture = icon },
                    order = {},
                    orderCount = 0,
                    layoutDirty = false,
                    layoutBlocked = false,
                },
            }

            mock.setCombat(false)
            local applied, appliedCount = renderer.applyTextLayout()
            local firstTimerPoint = icon.timerText.lastPoint
            local firstApplicationsPoint = icon.stackText.lastPoint
            local initialValid = applied == true
                and appliedCount == 1
                and firstTimerPoint and firstTimerPoint.point == "TOPLEFT"
                and firstTimerPoint.relativePoint == "TOPRIGHT"
                and firstTimerPoint.x == 4 and firstTimerPoint.y == 0
                and firstApplicationsPoint and firstApplicationsPoint.point == "TOPLEFT"
                and firstApplicationsPoint.relativePoint == "BOTTOMLEFT"
                and firstApplicationsPoint.x == 0 and firstApplicationsPoint.y == -2
                and icon.timerText.fontSize == 18
                and icon.stackText.fontSize == 20

            EAM.db.config.textLayout.timer.placement = "INSIDE_TOP_LEFT"
            EAM.db.config.textLayout.timer.fontSize = 22
            EAM.db.config.textLayout.applications.placement = "OUTSIDE_LEFT_AT_BOTTOM"
            EAM.db.config.textLayout.applications.fontSize = 24
            mock.setCombat(true)
            local pointsBeforeLayout = mock.trace.regionSetPoints
            local layoutDeferred, layoutDeferredReason = renderer.requestLayout("fixture")
            local layoutRemainedUnchanged = layoutDeferred == false
                and layoutDeferredReason == "combatDeferred"
                and renderer.frames.fixture.layoutDirty == true
                and renderer.frames.fixture.layoutBlocked == true
                and mock.trace.regionSetPoints == pointsBeforeLayout
            local deferred, deferredReason = renderer.applyTextLayout()
            local remainedUnchanged = icon.timerText.lastPoint == firstTimerPoint
                and icon.stackText.lastPoint == firstApplicationsPoint
                and icon.timerText.fontSize == 18
                and icon.stackText.fontSize == 20
                and renderer.textLayoutPending == true

            mock.setCombat(false)
            renderer.onCombatEnd()
            local finalTimerPoint = icon.timerText.lastPoint
            local finalApplicationsPoint = icon.stackText.lastPoint
            local valid = initialValid
                and layoutRemainedUnchanged
                and deferred == false
                and deferredReason == "combatDeferred"
                and remainedUnchanged
                and renderer.textLayoutPending == false
                and renderer.frames.fixture.layoutDirty == false
                and renderer.frames.fixture.layoutBlocked == false
                and finalTimerPoint and finalTimerPoint.point == "TOPLEFT"
                and finalTimerPoint.relativePoint == "TOPLEFT"
                and finalTimerPoint.x == 2 and finalTimerPoint.y == -2
                and finalApplicationsPoint and finalApplicationsPoint.point == "BOTTOMRIGHT"
                and finalApplicationsPoint.relativePoint == "BOTTOMLEFT"
                and finalApplicationsPoint.x == -4 and finalApplicationsPoint.y == 0
                and icon.timerText.fontSize == 22
                and icon.stackText.fontSize == 24
            return valid, valid and "existing general icons reapply text layout immediately and once after combat"
                or "general renderer text layout reapply mismatch"
        end)
        EAM.db = originalDB
        renderer.frames = originalFrames
        renderer.textLayoutPending = originalPending
        mock.setCombat(originalCombat)
        if not ok then
            return false, tostring(result)
        end
        return result, message
    end,
})

FlowTestRunner.registerCase({
    id = "ui.renderer.combat_first_activation_deferred",
    primarySuite = "boundary",
    suites = { boundary = true, core = true, aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local renderer = EAM.UI and EAM.UI.Renderer
        local iconPool = EAM.UI and EAM.UI.IconPool
        if not mock or not renderer or not iconPool then
            return STATUS_SKIP, "renderer first-activation mock is offline only"
        end

        local originalFrames = renderer.frames
        local originalDeferred = renderer.deferred
        local originalDeferredCount = renderer.deferredCount
        local originalTextLayoutPending = renderer.textLayoutPending
        local originalPrewarmPending = renderer.prewarmPending
        local originalAnchorTogglePending = renderer.anchorTogglePending
        local originalAcquire = iconPool.acquire
        local originalRender = renderer.render
        local originalCombat = mock.inCombat
        local acquireCalls = 0
        local replayCalls = 0
        local ok, result, message = pcall(function()
            renderer.frames = {}
            renderer.deferred = {}
            renderer.deferredCount = 0
            renderer.textLayoutPending = false
            renderer.prewarmPending = false
            renderer.anchorTogglePending = false
            renderer.frames.fixture = {
                parent = api.CreateFrame("Frame"),
                icons = {},
                order = {},
                orderCount = 0,
                layoutDirty = false,
                layoutBlocked = false,
            }
            iconPool.acquire = function()
                acquireCalls = acquireCalls + 1
                error("IconPool.acquire reached during combat")
            end

            mock.resetTrace()
            mock.setCombat(true)
            local rendered, reason = renderer.render({
                id = "combat-first-activation",
                shown = true,
                name = "Deferred",
            }, "fixture")
            local fixture = renderer.frames.fixture
            local deferredWithoutStructure = rendered == false
                and reason == "combatDeferred"
                and acquireCalls == 0
                and renderer.deferredCount == 1
                and fixture.layoutDirty == true
                and fixture.layoutBlocked == true
                and mock.trace.regionSetPoints == 0
                and mock.trace.regionSetFonts == 0

            renderer.render = function()
                replayCalls = replayCalls + 1
                return true, "replayed"
            end
            mock.setCombat(false)
            renderer.onCombatEnd()
            renderer.onCombatEnd()
            local valid = deferredWithoutStructure
                and replayCalls == 1
                and renderer.deferredCount == 0
                and next(renderer.deferred) == nil
            return valid, valid and "combat first activation performs no pool or region structure and replays once"
                or "combat first-activation deferral mismatch"
        end)
        renderer.frames = originalFrames
        renderer.deferred = originalDeferred
        renderer.deferredCount = originalDeferredCount
        renderer.textLayoutPending = originalTextLayoutPending
        renderer.prewarmPending = originalPrewarmPending
        renderer.anchorTogglePending = originalAnchorTogglePending
        iconPool.acquire = originalAcquire
        renderer.render = originalRender
        mock.setCombat(originalCombat)
        if not ok then
            return false, tostring(result)
        end
        return result, message
    end,
})

FlowTestRunner.registerCase({
    id = "ui.renderer.combat_existing_icon_display_only",
    primarySuite = "boundary",
    suites = { boundary = true, core = true, aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local renderer = EAM.UI and EAM.UI.Renderer
        if not mock or not renderer then
            return STATUS_SKIP, "renderer existing-icon mock is offline only"
        end

        local originalFrames = renderer.frames
        local originalDeferred = renderer.deferred
        local originalDeferredCount = renderer.deferredCount
        local originalTextLayoutPending = renderer.textLayoutPending
        local originalPrewarmPending = renderer.prewarmPending
        local originalAnchorTogglePending = renderer.anchorTogglePending
        local originalCombat = mock.inCombat
        local displayCalls = 0
        local nameClearAllPointsCalls = 0
        local nameSetPointCalls = 0
        local nameSetFontObjectCalls = 0
        local function displayCall()
            displayCalls = displayCalls + 1
        end
        local function createTextRegion()
            return {
                ClearAllPoints = function()
                end,
                SetPoint = function()
                end,
                SetSize = function()
                end,
                SetFont = function()
                end,
                SetFontObject = function()
                end,
                SetText = displayCall,
                ClearText = displayCall,
            }
        end

        local ok, result, message = pcall(function()
            local nameText = createTextRegion()
            nameText.ClearAllPoints = function()
                nameClearAllPointsCalls = nameClearAllPointsCalls + 1
            end
            nameText.SetPoint = function()
                nameSetPointCalls = nameSetPointCalls + 1
            end
            nameText.SetFontObject = function()
                nameSetFontObjectCalls = nameSetFontObjectCalls + 1
            end
            local icon = {
                isParasite = false,
                rendered = {
                    nameInside = true,
                },
                timerText = createTextRegion(),
                stackText = createTextRegion(),
                nameText = nameText,
                cooldown = {
                    SetCooldown = displayCall,
                },
                glowBorder = {
                    Show = displayCall,
                    Hide = displayCall,
                },
                SetParent = function()
                end,
                ClearAllPoints = function()
                end,
                SetPoint = function()
                end,
                SetSize = function()
                end,
                SetFont = function()
                end,
                Show = displayCall,
            }
            renderer.frames = {
                fixture = {
                    parent = api.CreateFrame("Frame"),
                    icons = {
                        ["combat-existing"] = icon,
                    },
                    order = { "combat-existing" },
                    orderCount = 1,
                    layoutDirty = false,
                    layoutBlocked = false,
                },
            }
            renderer.deferred = {}
            renderer.deferredCount = 0
            renderer.textLayoutPending = false
            renderer.prewarmPending = false
            renderer.anchorTogglePending = false
            mock.setCombat(true)
            renderer.render({
                id = "combat-existing",
                shown = true,
                name = "Updated in combat",
                stacks = 2,
            }, "fixture")
            local fixture = renderer.frames.fixture
            local combatSafe = nameClearAllPointsCalls == 0
                and nameSetPointCalls == 0
                and nameSetFontObjectCalls == 0
                and displayCalls > 0
                and renderer.textLayoutPending == true
                and icon.rendered.name == "Updated in combat"
                and icon.rendered.stacks == "2"
                and icon.rendered.nameInside == true
                and icon.rendered.nameLayoutPending == true
                and icon.rendered.pendingNameInside == false
                and fixture.layoutDirty == true
                and fixture.layoutBlocked == true

            mock.setCombat(false)
            renderer.onCombatEnd()
            renderer.onCombatEnd()
            local valid = combatSafe
                and nameClearAllPointsCalls == 1
                and nameSetPointCalls == 1
                and nameSetFontObjectCalls == 1
                and icon.rendered.nameInside == false
                and icon.rendered.nameLayoutPending == nil
                and icon.rendered.pendingNameInside == nil
                and fixture.layoutDirty == false
                and fixture.layoutBlocked == false
            return valid, valid and "existing icon keeps display-only combat updates and applies name layout once after combat"
                or "existing icon combat name-layout deferral mismatch"
        end)
        renderer.frames = originalFrames
        renderer.deferred = originalDeferred
        renderer.deferredCount = originalDeferredCount
        renderer.textLayoutPending = originalTextLayoutPending
        renderer.prewarmPending = originalPrewarmPending
        renderer.anchorTogglePending = originalAnchorTogglePending
        mock.setCombat(originalCombat)
        if not ok then
            return false, tostring(result)
        end
        return result, message
    end,
})

FlowTestRunner.registerCase({
    id = "ui.renderer.combat_parasite_release_deferred",
    primarySuite = "boundary",
    suites = { boundary = true, core = true, aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local renderer = EAM.UI and EAM.UI.Renderer
        local iconPool = EAM.UI and EAM.UI.IconPool
        if not mock or not renderer or not iconPool then
            return STATUS_SKIP, "renderer parasite-release mock is offline only"
        end

        local originalFrames = renderer.frames
        local originalDeferred = renderer.deferred
        local originalDeferredCount = renderer.deferredCount
        local originalTextLayoutPending = renderer.textLayoutPending
        local originalPrewarmPending = renderer.prewarmPending
        local originalAnchorTogglePending = renderer.anchorTogglePending
        local originalRelease = iconPool.release
        local originalCombat = mock.inCombat
        local setParentCalls = 0
        local releaseCalls = 0
        local ok, result, message = pcall(function()
            local token = { active = true }
            local icon = {
                isParasite = true,
                rendered = {
                    activeToken = token,
                },
                SetParent = function()
                    setParentCalls = setParentCalls + 1
                end,
            }
            renderer.frames = {
                fixture = {
                    parent = api.CreateFrame("Frame"),
                    icons = {
                        ["combat-parasite-hide"] = icon,
                    },
                    order = { "combat-parasite-hide" },
                    orderCount = 1,
                    layoutDirty = false,
                    layoutBlocked = false,
                },
            }
            renderer.deferred = {}
            renderer.deferredCount = 0
            renderer.textLayoutPending = false
            renderer.prewarmPending = false
            renderer.anchorTogglePending = false
            iconPool.release = function(releasedIcon)
                if releasedIcon == icon then
                    releaseCalls = releaseCalls + 1
                end
            end

            mock.setCombat(true)
            local hidden, reason = renderer.render({
                id = "combat-parasite-hide",
                shown = false,
            }, "fixture")
            local fixture = renderer.frames.fixture
            local combatSafe = hidden == false
                and reason == "combatDeferred"
                and setParentCalls == 0
                and releaseCalls == 0
                and icon.releasePending == true
                and icon.isParasite == true
                and icon.rendered.activeToken == nil
                and token.active == false
                and fixture.icons["combat-parasite-hide"] == icon
                and fixture.orderCount == 1
                and fixture.layoutDirty == true
                and fixture.layoutBlocked == true
                and renderer.deferredCount == 1

            mock.setCombat(false)
            renderer.onCombatEnd()
            renderer.onCombatEnd()
            local valid = combatSafe
                and setParentCalls == 1
                and releaseCalls == 1
                and icon.releasePending == nil
                and icon.isParasite == nil
                and fixture.icons["combat-parasite-hide"] == nil
                and fixture.orderCount == 0
                and renderer.deferredCount == 0
                and next(renderer.deferred) == nil
            return valid, valid and "combat parasite release defers reparenting and releases once after combat"
                or "combat parasite release deferral mismatch"
        end)
        renderer.frames = originalFrames
        renderer.deferred = originalDeferred
        renderer.deferredCount = originalDeferredCount
        renderer.textLayoutPending = originalTextLayoutPending
        renderer.prewarmPending = originalPrewarmPending
        renderer.anchorTogglePending = originalAnchorTogglePending
        iconPool.release = originalRelease
        mock.setCombat(originalCombat)
        if not ok then
            return false, tostring(result)
        end
        return result, message
    end,
})

FlowTestRunner.registerCase({
    id = "ui.renderer.combat_initialize_prewarm_deferred",
    primarySuite = "boundary",
    suites = { boundary = true, core = true, aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local renderer = EAM.UI and EAM.UI.Renderer
        local iconPool = EAM.UI and EAM.UI.IconPool
        local router = EAM.Modules and EAM.Modules.EventRouter
        if not mock or not renderer or not iconPool or not router then
            return STATUS_SKIP, "renderer prewarm mock is offline only"
        end

        local originalFrames = renderer.frames
        local originalDeferred = renderer.deferred
        local originalDeferredCount = renderer.deferredCount
        local originalTextLayoutPending = renderer.textLayoutPending
        local originalPrewarmPending = renderer.prewarmPending
        local originalAnchorTogglePending = renderer.anchorTogglePending
        local originalPrewarm = iconPool.prewarm
        local originalCreateFrame = api.CreateFrame
        local originalRegister = router.register
        local originalCombat = mock.inCombat
        local prewarmCalls = 0
        local createFrameCalls = 0
        local ok, result, message = pcall(function()
            renderer.frames = {}
            renderer.deferred = {}
            renderer.deferredCount = 0
            renderer.textLayoutPending = false
            renderer.prewarmPending = false
            renderer.anchorTogglePending = false
            iconPool.prewarm = function()
                prewarmCalls = prewarmCalls + 1
            end
            api.CreateFrame = function(...)
                createFrameCalls = createFrameCalls + 1
                return originalCreateFrame(...)
            end
            router.register = function()
            end

            mock.setCombat(true)
            renderer.initialize()
            local combatCreateFrameCalls = createFrameCalls
            local deferredSafely = prewarmCalls == 0
                and combatCreateFrameCalls == 0
                and renderer.prewarmPending == true
            mock.setCombat(false)
            renderer.onCombatEnd()
            renderer.onCombatEnd()
            local valid = deferredSafely
                and prewarmCalls == 1
                and renderer.prewarmPending == false
            return valid, valid and "combat initialize defers all frame creation and prewarms once after combat"
                or "combat initialize prewarm deferral mismatch"
        end)
        renderer.frames = originalFrames
        renderer.deferred = originalDeferred
        renderer.deferredCount = originalDeferredCount
        renderer.textLayoutPending = originalTextLayoutPending
        renderer.prewarmPending = originalPrewarmPending
        renderer.anchorTogglePending = originalAnchorTogglePending
        iconPool.prewarm = originalPrewarm
        api.CreateFrame = originalCreateFrame
        router.register = originalRegister
        mock.setCombat(originalCombat)
        if not ok then
            return false, tostring(result)
        end
        return result, message
    end,
})

FlowTestRunner.registerCase({
    id = "ui.icon_pool.direct_prewarm_combat_guard",
    primarySuite = "boundary",
    suites = { boundary = true, core = true, aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local iconPool = EAM.UI and EAM.UI.IconPool
        if not mock or not iconPool then
            return STATUS_SKIP, "icon-pool prewarm guard mock is offline only"
        end

        local originalCreateFrame = api.CreateFrame
        local originalCombat = mock.inCombat
        local originalCreated = iconPool.created
        local originalInactiveCount = iconPool.inactiveCount
        local createFrameCalls = 0
        local ok, result, message = pcall(function()
            api.CreateFrame = function(...)
                createFrameCalls = createFrameCalls + 1
                return originalCreateFrame(...)
            end
            mock.setCombat(true)
            local prewarmed, reason = iconPool.prewarm(originalCreated + 1)
            local valid = prewarmed == false
                and reason == "combatDeferred"
                and createFrameCalls == 0
                and iconPool.created == originalCreated
                and iconPool.inactiveCount == originalInactiveCount
            return valid, valid and "direct prewarm rejects combat without creating frames"
                or "direct prewarm combat guard mismatch"
        end)
        api.CreateFrame = originalCreateFrame
        for index = iconPool.inactiveCount, originalInactiveCount + 1, -1 do
            iconPool.inactive[index] = nil
        end
        iconPool.inactiveCount = originalInactiveCount
        iconPool.created = originalCreated
        mock.setCombat(originalCombat)
        if not ok then
            return false, tostring(result)
        end
        return result, message
    end,
})

FlowTestRunner.registerCase({
    id = "ui.renderer.anchor_toggle_combat_replay",
    primarySuite = "boundary",
    suites = { boundary = true, core = true, aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local renderer = EAM.UI and EAM.UI.Renderer
        if not mock or not renderer then
            return STATUS_SKIP, "renderer anchor-toggle mock is offline only"
        end

        local originalFrames = renderer.frames
        local originalDeferred = renderer.deferred
        local originalDeferredCount = renderer.deferredCount
        local originalTextLayoutPending = renderer.textLayoutPending
        local originalPrewarmPending = renderer.prewarmPending
        local originalAnchorTogglePending = renderer.anchorTogglePending
        local originalIsMoving = renderer.isMoving
        local originalToggleAnchors = renderer.toggleAnchors
        local originalCombat = mock.inCombat
        local replayCalls = 0
        local ok, result, message = pcall(function()
            renderer.frames = {}
            renderer.deferred = {}
            renderer.deferredCount = 0
            renderer.textLayoutPending = false
            renderer.prewarmPending = false
            renderer.anchorTogglePending = false
            renderer.isMoving = originalIsMoving
            mock.setCombat(true)
            local toggled, reason = renderer.toggleAnchors()
            local queued = toggled == false
                and reason == "combatDeferred"
                and renderer.anchorTogglePending == true
                and renderer.isMoving == originalIsMoving

            renderer.toggleAnchors = function()
                replayCalls = replayCalls + 1
                renderer.isMoving = not renderer.isMoving
                return true, renderer.isMoving
            end
            mock.setCombat(false)
            renderer.onCombatEnd()
            renderer.onCombatEnd()
            local valid = queued
                and replayCalls == 1
                and renderer.anchorTogglePending == false
                and renderer.isMoving ~= originalIsMoving
            return valid, valid and "anchor toggle queues in combat and replays once after combat"
                or "anchor toggle combat replay mismatch"
        end)
        renderer.frames = originalFrames
        renderer.deferred = originalDeferred
        renderer.deferredCount = originalDeferredCount
        renderer.textLayoutPending = originalTextLayoutPending
        renderer.prewarmPending = originalPrewarmPending
        renderer.anchorTogglePending = originalAnchorTogglePending
        renderer.isMoving = originalIsMoving
        renderer.toggleAnchors = originalToggleAnchors
        mock.setCombat(originalCombat)
        if not ok then
            return false, tostring(result)
        end
        return result, message
    end,
})

FlowTestRunner.registerCase({
    id = "ui.text_layout.font_bounds",
    primarySuite = "boundary",
    suites = { boundary = true, aura121 = true },
    run = function()
        local textPlacement = EAM.UI and EAM.UI.TextPlacement
        if not textPlacement then
            return false, "TextPlacement unavailable"
        end
        local below = textPlacement.getFontSize({ textLayout = { timer = { fontSize = 2 } } }, "timer")
        local above = textPlacement.getFontSize({ textLayout = { applications = { fontSize = 90 } } }, "applications")
        local valid = below == EAM.Constants.TEXT_FONT_SIZE_MIN
            and above == EAM.Constants.TEXT_FONT_SIZE_MAX
        return valid, valid and "text font sizes clamp to 8-32" or "text font size bounds mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "ui.text_layout.revision_once",
    primarySuite = "boundary",
    suites = { boundary = true, aura121 = true },
    run = function()
        local saved = EAM.Modules and EAM.Modules.SavedVariables
        if not saved or not saved.updateTextLayout then
            return false, "SavedVariables text layout updater unavailable"
        end
        local originalDB = EAM.db
        EAM.db = buildAura121TestDB(127)
        EAM.db.config.textLayout = {
            schema = 1,
            timer = { placement = "OUTSIDE_TOP", fontSize = 14 },
            applications = { placement = "INSIDE_BOTTOM_RIGHT", fontSize = 12 },
        }
        EAM.db.config.fontSizeTimeVal = 14
        EAM.db.config.fontSizeStack = 12
        local originalRevision = EAM.db.revision
        local unchanged, unchangedState = saved.updateTextLayout("timer", "OUTSIDE_TOP", 14)
        local updated, updatedState, updatedRevision = saved.updateTextLayout("timer", "OUTSIDE_LEFT", 19)
        local duplicate, duplicateState = saved.updateTextLayout("timer", "OUTSIDE_LEFT", 19)
        local valid = unchanged == true
            and unchangedState == "unchanged"
            and updated == true
            and updatedState == "updated"
            and updatedRevision == originalRevision + 1
            and duplicate == true
            and duplicateState == "unchanged"
            and EAM.db.revision == originalRevision + 1
            and EAM.db.config.fontSizeTimeVal == 19
        EAM.db = originalDB
        return valid, valid and "text layout revision changes exactly once" or "text layout revision contract mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "ui.text_layout.options_native_reapply_only",
    primarySuite = "boundary",
    suites = { boundary = true, aura121 = true },
    run = function()
        local options = EAM.UI and EAM.UI.Options
        local renderer = EAM.UI and EAM.UI.Renderer
        local nativeRenderer = EAM.UI and EAM.UI.NativeAuraRenderer
        local containerService = EAM.Services and EAM.Services.AuraContainerService
        if not options or not renderer or not nativeRenderer or not containerService then
            return false, "text layout notification dependencies unavailable"
        end

        local originalGeneralApply = renderer.applyTextLayout
        local originalNativeApply = nativeRenderer.applyTextLayout
        local originalRequestRebuild = containerService.requestRebuild
        local originalMarkSettingsDirty = containerService.markSettingsDirty
        local generalApplyCount = 0
        local nativeApplyCount = 0
        local rebuildCount = 0
        local dirtyCount = 0
        local ok, result = pcall(function()
            renderer.applyTextLayout = function()
                generalApplyCount = generalApplyCount + 1
                return true
            end
            nativeRenderer.applyTextLayout = function()
                nativeApplyCount = nativeApplyCount + 1
                return true
            end
            containerService.requestRebuild = function()
                rebuildCount = rebuildCount + 1
                return true
            end
            containerService.markSettingsDirty = function()
                dirtyCount = dirtyCount + 1
                return true
            end

            options.notifyTextLayoutChanged(false)
            options.notifyTextLayoutChanged(true)
            options.notifyConfigChanged(false)
            local textRouteValid = generalApplyCount == 2
                and nativeApplyCount == 0
                and rebuildCount == 0
                and dirtyCount == 1
            options.notifyConfigChanged(false)
            options.notifyConfigChanged(true)
            return textRouteValid and dirtyCount == 2 and rebuildCount == 0
        end)
        renderer.applyTextLayout = originalGeneralApply
        nativeRenderer.applyTextLayout = originalNativeApply
        containerService.requestRebuild = originalRequestRebuild
        containerService.markSettingsDirty = originalMarkSettingsDirty
        local valid = ok and result == true
        return valid, valid and "Native text/config changes mark settings dirty until manual rebuild"
            or "text layout notification routing mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.shadow_host.disabled",
    primarySuite = "aura121",
    suites = { aura121 = true },
    run = function()
        local valid = EAM.Services.ShadowHostService == nil
        return valid, valid and "ShadowHost is not loaded" or "ShadowHost unexpectedly loaded"
    end,
})

FlowTestRunner.registerCase({
    id = "event.custom_roundtrip",
    primarySuite = "core",
    suites = { quick = true, core = true },
    run = function()
        local router = EAM.Modules and EAM.Modules.EventRouter
        if not router or not router.register or not router.fire or not router.unregister then
            return false, "EventRouter contract incomplete"
        end

        local received = 0
        local token = "flow-roundtrip"
        local function handler(_, value)
            if value == token then
                received = received + 1
            end
        end

        router.register("EAM_FLOW_TEST_EVENT", handler)
        router.fire("EAM_FLOW_TEST_EVENT", token)
        local removed = router.unregister("EAM_FLOW_TEST_EVENT", handler)
        local valid = received == 1 and removed == true
        return valid, valid and "custom event round-trip completed" or "custom event round-trip failed"
    end,
})

FlowTestRunner.registerCase({
    id = "scheduler.next_frame",
    primarySuite = "core",
    suites = { core = true },
    run = function(context)
        local scheduler = EAM.Modules and EAM.Modules.Scheduler
        if not scheduler or not scheduler.after then
            return false, "Scheduler unavailable"
        end

        local before = scheduler.count or 0
        scheduler.after(0, function()
            local valid = (scheduler.count or 0) == before
            context.complete(valid, valid and "scheduled callback completed" or "scheduler queue did not settle")
        end)

        if (scheduler.count or 0) ~= before + 1 then
            return false, "scheduler did not enqueue"
        end
        return STATUS_PENDING
    end,
})

FlowTestRunner.registerCase({
    id = "saved_variables.contract",
    primarySuite = "core",
    suites = { quick = true, core = true },
    run = function()
        local saved = EAM.Modules and EAM.Modules.SavedVariables
        local db = EAM.db
        local valid = saved
            and type(saved.getAlertList) == "function"
            and type(saved.addAlert) == "function"
            and type(saved.removeAlert) == "function"
            and type(db) == "table"
            and db.schemaVersion == EAM.Constants.SCHEMA_VERSION
            and type(db.alerts) == "table"

        return valid == true, valid and "SavedVariables contract available" or "SavedVariables contract invalid"
    end,
})

FlowTestRunner.registerCase({
    id = "boundary.safe_scalar",
    primarySuite = "boundary",
    suites = { boundary = true },
    run = function()
        if not util.readSafeScalar or not util.isSecretValue or not util.canAccessValue then
            return false, "Secret boundary helpers unavailable"
        end

        local warnings = {}
        local value, accessible = util.readSafeScalar(42, warnings, "flowTest", "value")
        local valid = value == 42 and accessible == true and #warnings == 0
        return valid, valid and "safe scalar boundary completed" or "safe scalar boundary failed"
    end,
})

local function openTooltipCandidateFromMock(mock)
    mock.setModifiers(true, true, false, false)
    EAM.Modules.EventRouter.fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
    mock.setModifiers(false, false, false, false)
    local menu = EAM.UI and EAM.UI.TooltipMonitorMenu
    if not menu or type(menu._getStateForTest) ~= "function" then
        return nil
    end
    local state = menu._getStateForTest()
    if not state or state.shown ~= true then
        return nil
    end
    return state
end

local function buildTooltipTestDB()
    local db = buildAura121TestDB(0)
    db.alerts.playerAuras = {}
    db.alerts.targetAuras = {}
    return db
end

local function installTooltipRefreshSpies(mock)
    local services = EAM.Services
    local ui = EAM.UI
    local auraContainerService = services.AuraContainerService
    local auraService = services.AuraService
    local originalAuraContainerRefresh = auraContainerService.requestRebuild
    local originalAuraSettingsDirty = auraContainerService.markSettingsDirty
    local originalAuraRefresh = auraService.refreshAll
    local originalCooldownService = services.CooldownService
    local originalItemService = services.ItemCooldownService
    local originalRenderer = ui.Renderer
    local cooldownService = originalCooldownService or {}
    local itemService = originalItemService or {}
    local renderer = originalRenderer or {}
    local originalCooldownRefresh = cooldownService.refreshAll
    local originalItemRefresh = itemService.refreshAll
    local originalLayoutRefresh = renderer.requestLayout

    services.CooldownService = cooldownService
    services.ItemCooldownService = itemService
    ui.Renderer = renderer
    auraContainerService.requestRebuild = function()
        mock.recordConfigRefresh("auraContainer")
    end
    auraContainerService.markSettingsDirty = function()
        mock.recordConfigRefresh("auraContainer")
    end
    auraService.refreshAll = function()
        mock.recordConfigRefresh("aura")
    end
    cooldownService.refreshAll = function()
        mock.recordConfigRefresh("cooldown")
    end
    itemService.refreshAll = function()
        mock.recordConfigRefresh("item")
    end
    renderer.requestLayout = function()
        mock.recordConfigRefresh("layout")
    end

    return function()
        auraContainerService.requestRebuild = originalAuraContainerRefresh
        auraContainerService.markSettingsDirty = originalAuraSettingsDirty
        auraService.refreshAll = originalAuraRefresh
        if originalCooldownService then
            originalCooldownService.refreshAll = originalCooldownRefresh
        else
            services.CooldownService = nil
        end
        if originalItemService then
            originalItemService.refreshAll = originalItemRefresh
        else
            services.ItemCooldownService = nil
        end
        if originalRenderer then
            originalRenderer.requestLayout = originalLayoutRefresh
        else
            ui.Renderer = nil
        end
    end
end

local function hasConfigRefreshCount(mock, expected)
    local trace = mock.trace
    return trace.configNotifications == expected
        and trace.auraContainerRefreshes == expected
        and trace.auraRefreshes == expected
        and trace.cooldownRefreshes == expected
        and trace.itemRefreshes == expected
        and trace.layoutRefreshes == expected
end

local function withTooltipTestDB(callback)
    local originalDB = EAM.db
    local originalGlobalDB = _G.EAM_DB
    local testDB = buildTooltipTestDB()
    EAM.db = testDB
    _G.EAM_DB = testDB
    local restoreRefreshSpies = installTooltipRefreshSpies(EAM.FlowTestMock)
    local ok, first, second, third, fourth = pcall(callback, testDB)
    restoreRefreshSpies()
    EAM.db = originalDB
    _G.EAM_DB = originalGlobalDB
    if not ok then
        error(first)
    end
    return first, second, third, fourth
end

local function resetTooltipTestState(mock, resetTrace)
    local menu = EAM.UI and EAM.UI.TooltipMonitorMenu
    if menu and type(menu.hide) == "function" then
        menu.hide()
    end
    mock.resetTooltipScenario()
    if resetTrace then
        mock.resetTrace()
    end
    local service = EAM.Services and EAM.Services.TooltipMonitorService
    if service and type(service._clearCandidateForTest) == "function" then
        service._clearCandidateForTest("testReset")
    end
end

FlowTestRunner.registerCase({
    id = "tooltip_monitor.capability",
    primarySuite = "boundary",
    suites = { boundary = true },
    run = function()
        local service = EAM.Services and EAM.Services.TooltipMonitorService
        if not service or type(service.getStatus) ~= "function" then
            return false, "TooltipMonitorService unavailable"
        end
        local status = service.getStatus()
        local menu = EAM.UI and EAM.UI.TooltipMonitorMenu
        local menuReady = menu
            and menu.initialized == true
            and menu.frame ~= nil
        if EAM.FlowTestEnvironment == "offline-mock" then
            menuReady = menuReady
                and type(menu._getStateForTest) == "function"
                and type(menu._clickActionForTest) == "function"
                and type(menu.actionButtons) == "table"
                and menu.actionButtons[1] ~= nil
                and type(menu.actionButtons[1]:GetScript("OnClick")) == "function"
        end
        local callbacksValid = true
        local mock = EAM.FlowTestMock
        if mock and api.TooltipDataType then
            local callbackTypes = {
                api.TooltipDataType.Spell,
                api.TooltipDataType.Item,
                api.TooltipDataType.UnitAura,
                api.TooltipDataType.Macro,
            }
            for index = 1, #callbackTypes do
                local callbacks = mock.tooltipPostCalls[callbackTypes[index]]
                if type(callbacks) ~= "table" or #callbacks ~= 1 then
                    callbacksValid = false
                    break
                end
            end
        end
        service.initialize()
        local statusAfterSecondInitialize = service.getStatus()
        local interfaceVersion
        if api.GetBuildInfo then
            local _, _, _, clientInterface = api.GetBuildInfo()
            interfaceVersion = clientInterface
        end
        local requiresAuraCVar = type(interfaceVersion) == "number" and interfaceVersion >= 120100
        local valid = status.initialized == true
            and type(status.postCallCount) == "number"
            and status.postCallCount == 4
            and statusAfterSecondInitialize.postCallCount == 4
            and callbacksValid == true
            and menuReady == true
            and (not requiresAuraCVar or status.auraIDDisplayEnabled == true)
            and status.spellID == nil
            and status.itemID == nil
            and status.macroID == nil
        local message = valid and "tooltip callbacks and anonymous status available" or string.format(
            "tooltip capability mismatch callbacks=%s stableCallbacks=%s auraCVar=%s reason=%s",
            tostring(status.postCallCount),
            tostring(callbacksValid),
            tostring(status.auraIDDisplayEnabled),
            tostring(status.lastReason)
        )
        return valid, message
    end,
})

FlowTestRunner.registerCase({
    id = "tooltip_monitor.offline_spell_item_routes",
    primarySuite = "boundary",
    suites = { boundary = true },
    run = function()
        local mock = EAM.FlowTestMock
        if not mock then
            return STATUS_SKIP, "tooltip route mock is offline only"
        end
        return withTooltipTestDB(function(db)
            local service = EAM.Services.TooltipMonitorService
            local saved = EAM.Modules.SavedVariables
            local menu = EAM.UI.TooltipMonitorMenu
            resetTooltipTestState(mock, true)

            mock.emitTooltip("Spell", { id = 910001 })
            local spellLines = mock.getTooltipLines()
            local spellCandidate = openTooltipCandidateFromMock(mock)
            local spellOK = spellCandidate
                and spellCandidate.kind == "spell"
                and spellCandidate.spellID == 910001
                and spellCandidate.actionOne == service.ACTION_SPELL_COOLDOWN
                and spellCandidate.actionTwo == nil
                and #spellLines == 2
                and spellLines[1].kind == "double"
                and spellLines[1].rightText == "910001"
            local spellCommitted, spellAlertID, spellChange = menu._clickActionForTest(1)

            mock.emitTooltip("Spell", { id = 910001 })
            local unchangedCandidate = openTooltipCandidateFromMock(mock)
            local unchangedCommitted, unchangedAlertID, unchangedChange = menu._clickActionForTest(1)

            mock.emitTooltip("Item", { id = 910002 })
            local itemLines = mock.getTooltipLines()
            local itemCandidate = openTooltipCandidateFromMock(mock)
            local itemOK = itemCandidate
                and itemCandidate.kind == "item"
                and itemCandidate.itemID == 910002
                and itemCandidate.actionOne == service.ACTION_ITEM_COOLDOWN
                and itemCandidate.actionTwo == nil
                and #itemLines == 2
                and itemLines[1].kind == "double"
                and itemLines[1].rightText == "910002"
            local itemCommitted, itemAlertID, itemChange = menu._clickActionForTest(1)

            local expectedSpellID = saved.buildAlertID(
                EAM.Constants.ALERT_KIND_SPELL_COOLDOWN,
                "player",
                910001,
                nil
            )
            local expectedItemID = saved.buildAlertID(
                EAM.Constants.ALERT_KIND_ITEM_COOLDOWN,
                nil,
                nil,
                910002
            )
            local valid = spellOK == true
                and itemOK == true
                and spellCommitted == true
                and spellAlertID == expectedSpellID
                and spellChange == "added"
                and unchangedCandidate ~= nil
                and unchangedCommitted == true
                and unchangedAlertID == expectedSpellID
                and unchangedChange == "unchanged"
                and itemCommitted == true
                and itemAlertID == expectedItemID
                and itemChange == "added"
                and db.revision == 2
                and hasConfigRefreshCount(mock, 2)
                and db.alerts.spellCooldowns[expectedSpellID].spellID == 910001
                and db.alerts.itemCooldowns[expectedItemID].itemID == 910002
            return valid, valid and "real popup committed spell/item and skipped unchanged refresh" or string.format(
                "spell/item popup mismatch spell=%s/%s unchanged=%s/%s item=%s/%s revision=%s notifications=%s refreshes=%s/%s/%s/%s/%s",
                tostring(spellCommitted),
                tostring(spellChange),
                tostring(unchangedCommitted),
                tostring(unchangedChange),
                tostring(itemCommitted),
                tostring(itemChange),
                tostring(db.revision),
                tostring(mock.trace.configNotifications),
                tostring(mock.trace.auraContainerRefreshes),
                tostring(mock.trace.auraRefreshes),
                tostring(mock.trace.cooldownRefreshes),
                tostring(mock.trace.itemRefreshes),
                tostring(mock.trace.layoutRefreshes)
            )
        end)
    end,
})

FlowTestRunner.registerCase({
    id = "tooltip_monitor.offline_macro_resolution",
    primarySuite = "boundary",
    suites = { boundary = true },
    run = function()
        local mock = EAM.FlowTestMock
        if not mock then
            return STATUS_SKIP, "macro tooltip mock is offline only"
        end
        return withTooltipTestDB(function(db)
            local service = EAM.Services.TooltipMonitorService
            local saved = EAM.Modules.SavedVariables
            local menu = EAM.UI.TooltipMonitorMenu
            resetTooltipTestState(mock, true)
            mock.setMacroAction(17, 77, 920001, 920002)
            mock.emitTooltip("Macro", { id = 999999 }, {
                getterName = "GetAction",
                getterArgs = { 17, n = 1 },
            })
            local source = openTooltipCandidateFromMock(mock)
            local resolvedValid = source
                and source.kind == "macro"
                and source.macroID == 77
                and source.spellID == 920001
                and source.itemID == 920002
                and source.inputShown == false
                and source.actionOne == service.ACTION_SPELL_COOLDOWN
                and source.actionTwo == service.ACTION_ITEM_COOLDOWN
            local spellCommitted, spellAlertID, spellChange = menu._clickActionForTest(1)
            mock.emitTooltip("Macro", { id = 999999 }, {
                getterName = "GetAction",
                getterArgs = { 17, n = 1 },
            })
            local reopenedSource = openTooltipCandidateFromMock(mock)
            local itemCommitted, itemAlertID, itemChange = menu._clickActionForTest(2)

            mock.emitTooltip("Macro", { id = 888888 }, {
                getterName = "GetMacro",
                getterArgs = { 77, n = 1 },
            })
            local manualSource = openTooltipCandidateFromMock(mock)
            local manualValid = manualSource
                and manualSource.kind == "macro"
                and manualSource.macroID == nil
                and manualSource.spellID == nil
                and manualSource.itemID == nil
                and manualSource.inputShown == true
                and manualSource.actionOne == service.ACTION_SPELL_COOLDOWN
                and manualSource.actionTwo == service.ACTION_ITEM_COOLDOWN
            local manualSpellCommitted, manualSpellAlertID, manualSpellChange = menu._clickActionForTest(1, 920003)

            mock.emitTooltip("Macro", { id = 888888 }, {
                getterName = "GetMacro",
                getterArgs = { 77, n = 1 },
            })
            local secondManualSource = openTooltipCandidateFromMock(mock)
            local manualItemCommitted, manualItemAlertID, manualItemChange = menu._clickActionForTest(2, 920004)

            local expectedSpellID = saved.buildAlertID(EAM.Constants.ALERT_KIND_SPELL_COOLDOWN, "player", 920001, nil)
            local expectedItemID = saved.buildAlertID(EAM.Constants.ALERT_KIND_ITEM_COOLDOWN, nil, nil, 920002)
            local expectedManualSpellID = saved.buildAlertID(EAM.Constants.ALERT_KIND_SPELL_COOLDOWN, "player", 920003, nil)
            local expectedManualItemID = saved.buildAlertID(EAM.Constants.ALERT_KIND_ITEM_COOLDOWN, nil, nil, 920004)
            local valid = resolvedValid == true
                and reopenedSource ~= nil
                and manualValid == true
                and secondManualSource ~= nil
                and spellCommitted == true
                and spellAlertID == expectedSpellID
                and spellChange == "added"
                and itemCommitted == true
                and itemAlertID == expectedItemID
                and itemChange == "added"
                and manualSpellCommitted == true
                and manualSpellAlertID == expectedManualSpellID
                and manualSpellChange == "added"
                and manualItemCommitted == true
                and manualItemAlertID == expectedManualItemID
                and manualItemChange == "added"
                and db.revision == 4
                and hasConfigRefreshCount(mock, 4)
                and db.alerts.spellCooldowns[expectedSpellID] ~= nil
                and db.alerts.itemCooldowns[expectedItemID] ~= nil
                and db.alerts.spellCooldowns[expectedManualSpellID] ~= nil
                and db.alerts.itemCooldowns[expectedManualItemID] ~= nil
            return valid, valid and "macro popup committed resolved and manual spell/item routes" or string.format(
                "macro popup mismatch resolved=%s manual=%s revision=%s notifications=%s",
                tostring(resolvedValid),
                tostring(manualValid),
                tostring(db.revision),
                tostring(mock.trace.configNotifications)
            )
        end)
    end,
})

FlowTestRunner.registerCase({
    id = "tooltip_monitor.offline_aura_manual_route",
    primarySuite = "boundary",
    suites = { boundary = true },
    run = function()
        local mock = EAM.FlowTestMock
        if not mock then
            return STATUS_SKIP, "aura tooltip mock is offline only"
        end
        return withTooltipTestDB(function(db)
            local service = EAM.Services.TooltipMonitorService
            local saved = EAM.Modules.SavedVariables
            local menu = EAM.UI.TooltipMonitorMenu
            resetTooltipTestState(mock, true)
            local secretData = mock.createSecretTooltipData()
            local readsBefore = mock.trace.secretTooltipReads

            mock.emitTooltip("UnitAura", secretData)
            local auraLines = mock.getTooltipLines()
            local playerSource = openTooltipCandidateFromMock(mock)
            local playerRouteValid = playerSource
                and playerSource.kind == "aura"
                and playerSource.spellID == nil
                and playerSource.inputShown == true
                and playerSource.actionOne == service.ACTION_AURA_PLAYER
                and playerSource.actionTwo == service.ACTION_AURA_TARGET
                and #auraLines == 1
            local playerCommitted, playerAlertID, playerChange = menu._clickActionForTest(1, 930001)

            mock.emitTooltip("UnitAura", secretData)
            local targetSource = openTooltipCandidateFromMock(mock)
            local targetCommitted, targetAlertID, targetChange = menu._clickActionForTest(2, 930002)

            local originalAuraIDDisplayEnabled = service.auraIDDisplayEnabled
            local fallbackOK, fallbackValid = pcall(function()
                service.auraIDDisplayEnabled = false
                mock.emitTooltip("UnitAura", secretData)
                local fallbackLines = mock.getTooltipLines()
                local fallbackSource = openTooltipCandidateFromMock(mock)
                local validFallback = fallbackSource
                    and #fallbackLines == 1
                    and fallbackLines[1].leftText == EAM.L.EAM_TOOLTIP_AURA_MANUAL_HINT
                    and fallbackSource.description == EAM.L.EAM_POPUP_DESC_AURA_MANUAL
                menu.hide()
                return validFallback == true
            end)
            service.auraIDDisplayEnabled = originalAuraIDDisplayEnabled
            if not fallbackOK then
                error(fallbackValid)
            end

            local expectedPlayerID = saved.buildAlertID(EAM.Constants.ALERT_KIND_AURA, "player", 930001, nil)
            local expectedTargetID = saved.buildAlertID(EAM.Constants.ALERT_KIND_AURA, "target", 930002, nil)
            local valid = playerRouteValid == true
                and targetSource ~= nil
                and playerCommitted == true
                and playerAlertID == expectedPlayerID
                and playerChange == "added"
                and targetCommitted == true
                and targetAlertID == expectedTargetID
                and targetChange == "added"
                and fallbackValid == true
                and mock.trace.secretTooltipReads == readsBefore
                and db.revision == 2
                and hasConfigRefreshCount(mock, 2)
                and db.alerts.playerAuras[expectedPlayerID].unit == "player"
                and db.alerts.targetAuras[expectedTargetID].unit == "target"
            return valid, valid and "aura popup committed player/target manual IDs without payload reads" or string.format(
                "aura popup mismatch player=%s target=%s secretReads=%d revision=%s",
                tostring(playerCommitted),
                tostring(targetCommitted),
                mock.trace.secretTooltipReads - readsBefore,
                tostring(db.revision)
            )
        end)
    end,
})

FlowTestRunner.registerCase({
    id = "tooltip_monitor.offline_fail_closed",
    primarySuite = "boundary",
    suites = { boundary = true },
    run = function()
        local mock = EAM.FlowTestMock
        if not mock then
            return STATUS_SKIP, "tooltip fail-closed mock is offline only"
        end
        local menu = EAM.UI.TooltipMonitorMenu
        resetTooltipTestState(mock, true)

        local function opensWithModifiers(spellID, controlDown, altDown, shiftDown, metaDown, key)
            resetTooltipTestState(mock, false)
            mock.emitTooltip("Spell", { id = spellID })
            mock.setModifiers(controlDown, altDown, shiftDown, metaDown)
            EAM.Modules.EventRouter.fire("MODIFIER_STATE_CHANGED", key, 1)
            mock.setModifiers(false, false, false, false)
            return menu.isShown()
        end

        mock.setModifiers(true, true, false, false)
        mock.emitTooltip("Spell", { id = 940001 })
        local callbackOpened = menu.isShown()
        mock.setModifiers(false, false, false, false)

        resetTooltipTestState(mock, false)
        mock.emitTooltip("Spell", { id = 940002 })
        mock.setKeyboardFocus({})
        local keyboardCandidate = openTooltipCandidateFromMock(mock)

        resetTooltipTestState(mock, false)
        mock.emitTooltip("Spell", { id = 940003 })
        mock.setCombat(true)
        local combatCandidate = openTooltipCandidateFromMock(mock)

        resetTooltipTestState(mock, false)
        mock.setCombat(true)
        mock.emitTooltip("Spell", { id = 940010 })
        mock.setCombat(false)
        local combatReplayCandidate = openTooltipCandidateFromMock(mock)

        resetTooltipTestState(mock, false)
        mock.emitTooltip("Spell", { id = 940004 })
        mock.setTooltipType("Item")
        local typeChangedCandidate = openTooltipCandidateFromMock(mock)

        resetTooltipTestState(mock, false)
        mock.emitTooltip("Spell", { id = 940005 })
        mock.setTooltipShown(false)
        local hiddenCandidate = openTooltipCandidateFromMock(mock)

        resetTooltipTestState(mock, false)
        mock.emitTooltip("Spell", { id = 940006 })
        EAM.FlowTestAdvanceTime(6)
        local expiredCandidate = openTooltipCandidateFromMock(mock)

        local shiftedOpened = opensWithModifiers(940007, true, true, true, false, "LSHIFT")
        local metaOpened = opensWithModifiers(940011, true, true, false, true, "LMETA")
        local missingControlOpened = opensWithModifiers(940012, false, true, false, false, "LALT")
        local missingAltOpened = opensWithModifiers(940013, true, false, false, false, "LCTRL")

        resetTooltipTestState(mock, false)
        mock.emitTooltip("Spell", { id = 940008 })
        mock.emitTooltip("Spell", { id = 940009 })
        local latestCandidate = openTooltipCandidateFromMock(mock)

        local valid = callbackOpened == false
            and keyboardCandidate == nil
            and combatCandidate == nil
            and combatReplayCandidate == nil
            and typeChangedCandidate == nil
            and hiddenCandidate == nil
            and expiredCandidate == nil
            and shiftedOpened == false
            and metaOpened == false
            and missingControlOpened == false
            and missingAltOpened == false
            and latestCandidate ~= nil
            and latestCandidate.spellID == 940009
        resetTooltipTestState(mock, false)
        return valid, valid and "callback, focus, combat replay, type, visibility, TTL, exact chord, and latest gates passed" or string.format(
            "tooltip fail-closed mismatch callback=%s focus=%s combat=%s replay=%s type=%s hidden=%s expired=%s chord=%s/%s/%s/%s latest=%s",
            tostring(callbackOpened),
            tostring(keyboardCandidate ~= nil),
            tostring(combatCandidate ~= nil),
            tostring(combatReplayCandidate ~= nil),
            tostring(typeChangedCandidate ~= nil),
            tostring(hiddenCandidate ~= nil),
            tostring(expiredCandidate ~= nil),
            tostring(shiftedOpened),
            tostring(metaOpened),
            tostring(missingControlOpened),
            tostring(missingAltOpened),
            tostring(latestCandidate and latestCandidate.spellID)
        )
    end,
})

FlowTestRunner.registerCase({
    id = "tooltip_monitor.offline_secret_scalars",
    primarySuite = "boundary",
    suites = { boundary = true },
    run = function()
        local mock = EAM.FlowTestMock
        if not mock then
            return STATUS_SKIP, "tooltip secret scalar mock is offline only"
        end
        return withTooltipTestDB(function(db)
            local service = EAM.Services.TooltipMonitorService
            resetTooltipTestState(mock, true)
            local guardedSpellCooldowns = mock.createSecretKeyGuardedTable()
            db.alerts.spellCooldowns = guardedSpellCooldowns
            local spellSecret = mock.createSecretScalar()
            local operationsBefore = mock.trace.secretScalarOperations
            local keyOperationsBefore = mock.trace.secretKeyTableOperations
            mock.emitTooltip("Spell", { id = spellSecret })
            local secretSpellSource = openTooltipCandidateFromMock(mock)

            resetTooltipTestState(mock, false)
            local macroSecret = mock.createSecretScalar()
            mock.setSecretMacroAction(23, macroSecret)
            mock.emitTooltip("Macro", {}, {
                getterName = "GetAction",
                getterArgs = { 23, n = 1 },
            })
            local secretMacroSource = openTooltipCandidateFromMock(mock)
            local macroFallbackValid = secretMacroSource
                and secretMacroSource.kind == "macro"
                and secretMacroSource.macroID == nil
                and secretMacroSource.spellID == nil
                and secretMacroSource.itemID == nil
                and secretMacroSource.inputShown == true

            local manualSecret = mock.createSecretScalar()
            local committed, reason = service.commitCandidate(
                { kind = "macro" },
                service.ACTION_SPELL_COOLDOWN,
                manualSecret
            )
            local actionSecret = mock.createSecretScalar()
            local actionCommitted, actionReason = service.commitCandidate(
                { kind = "spell", spellID = 960001 },
                actionSecret,
                nil
            )
            local keyOperationsAfterService = mock.trace.secretKeyTableOperations
            local guardProbeOK = pcall(function()
                return guardedSpellCooldowns[manualSecret]
            end)
            local guardDetected = guardProbeOK == false
                and mock.trace.secretKeyTableOperations == keyOperationsAfterService + 1
            local valid = secretSpellSource == nil
                and macroFallbackValid == true
                and committed == false
                and reason == "invalidCommitRoute"
                and actionCommitted == false
                and actionReason == "invalidAction"
                and mock.trace.secretScalarOperations == operationsBefore
                and keyOperationsAfterService == keyOperationsBefore
                and guardDetected == true
                and db.revision == 0
                and hasConfigRefreshCount(mock, 0)
            resetTooltipTestState(mock, false)
            return valid, valid and "secret spell, macro, manual, action, and table-key paths caused zero service operations" or string.format(
                "secret scalar mismatch spell=%s macroFallback=%s commit=%s/%s action=%s/%s scalarOps=%d keyOps=%d guard=%s revision=%s",
                tostring(secretSpellSource ~= nil),
                tostring(macroFallbackValid),
                tostring(committed),
                tostring(reason),
                tostring(actionCommitted),
                tostring(actionReason),
                mock.trace.secretScalarOperations - operationsBefore,
                keyOperationsAfterService - keyOperationsBefore,
                tostring(guardDetected),
                tostring(db.revision)
            )
        end)
    end,
})

FlowTestRunner.registerCase({
    id = "tooltip_monitor.offline_db_isolation",
    primarySuite = "boundary",
    suites = { boundary = true },
    run = function()
        local mock = EAM.FlowTestMock
        if not mock then
            return STATUS_SKIP, "tooltip DB isolation mock is offline only"
        end
        local originalDB = EAM.db
        local originalGlobalDB = _G.EAM_DB
        local callbackDB
        local successValue = withTooltipTestDB(function(testDB)
            callbackDB = testDB
            return true
        end)
        local successRestored = successValue == true
            and callbackDB ~= originalDB
            and rawequal(EAM.db, originalDB)
            and rawequal(_G.EAM_DB, originalGlobalDB)
        local errorOK = pcall(function()
            withTooltipTestDB(function()
                error("tooltipDBIsolationSentinel")
            end)
        end)
        local errorRestored = errorOK == false
            and rawequal(EAM.db, originalDB)
            and rawequal(_G.EAM_DB, originalGlobalDB)
        local valid = successRestored and errorRestored
        return valid, valid and "temporary DB and refresh spies restored after success and error" or string.format(
            "tooltip DB isolation mismatch success=%s error=%s",
            tostring(successRestored),
            tostring(errorRestored)
        )
    end,
})

FlowTestRunner.registerCase({
    id = "runtime_probe.schema",
    primarySuite = "boundary",
    suites = { boundary = true },
    run = function()
        local probe = EAM.Debug and EAM.Debug.RuntimeProbe
        if not probe or not probe.snapshot then
            return false, "RuntimeProbe unavailable"
        end

        local mock = EAM.FlowTestMock
        if mock then
            resetTooltipTestState(mock, true)
            mock.emitTooltip("Spell", { id = 950001 })
        end
        local snapshot = probe.snapshot({ runFrameProbe = false })
        local encoded = encodeJSON(snapshot)
        local humanLines = probe.buildLines and probe.buildLines(snapshot) or {}
        local humanOutput = table.concat(humanLines, "\n")
        local tooltipStatus = snapshot.tooltipMonitor or {}
        local valid = type(snapshot) == "table"
            and type(snapshot.environment) == "table"
            and type(snapshot.capabilities) == "table"
            and type(snapshot.summary) == "table"
            and tooltipStatus.spellID == nil
            and tooltipStatus.itemID == nil
            and tooltipStatus.macroID == nil
            and string.find(encoded, "950001", 1, true) == nil
            and string.find(humanOutput, "950001", 1, true) == nil
        if mock then
            resetTooltipTestState(mock, false)
        end
        return valid, valid and "RuntimeProbe schema available without tooltip candidate IDs" or "RuntimeProbe schema or redaction invalid"
    end,
})

FlowTestRunner.registerCase({
    id = "report.json_roundtrip",
    primarySuite = "boundary",
    suites = { quick = true, boundary = true },
    run = function()
        local encoded = encodeJSON({
            schema = 1,
            status = "pass",
            cases = {
                { id = "probe", status = "pass" },
            },
        })
        local valid = string.find(encoded, '"schema":1', 1, true) ~= nil
            and string.find(encoded, '"cases":[', 1, true) ~= nil
        return valid, valid and "JSON serializer contract available" or "JSON serializer contract invalid"
    end,
})

FlowTestRunner.registerCase({
    id = "live_test.offline_cannot_signoff",
    primarySuite = "boundary",
    suites = { boundary = true },
    run = function()
        local live = EAM.Debug and EAM.Debug.LiveTestSession
        if not live then
            return false, "LiveTestSession unavailable"
        end
        local originalSession = _G.EAM_LIVE_TEST_SESSION
        local originalReport = _G.EAM_LIVE_TEST_REPORT_JSON
        local originalProfile = _G.EAM_VALIDATION_PROFILE
        _G.EAM_LIVE_TEST_SESSION = nil
        _G.EAM_LIVE_TEST_REPORT_JSON = nil
        _G.EAM_VALIDATION_PROFILE = nil

        local ok, result = pcall(function()
            local mock = EAM.FlowTestMock
            mock.setCombat(true)
            local combatStart, combatStartReason = live.start("_ptr_")
            mock.setCombat(false)
            local started = live.start("_ptr_")
            local initial = live.buildReport()

            mock.setCombat(true)
            local combatNote, combatNoteReason = live.setCaseNote(live.cases[1].id, "blocked in combat")
            local combatReload, combatReloadReason = live.prepareReload()
            local combatComplete, combatCompleteReason = live.complete()
            mock.setCombat(false)

            local slash = string.char(92)
            local privatePath = "D:" .. slash .. "World of Warcraft"
                .. slash .. "_ptr_" .. slash .. "WTF"
                .. slash .. "Account" .. slash .. "PRIVATE"
            local privacySaved = live.setCaseNote(live.cases[1].id, privatePath)
            local privacyReport, privacyJSON = live.buildReport()
            local privacyRedacted = privacySaved == true
                and privacyReport.cases[1].note == "[privacy-redacted]"
                and string.find(privacyJSON, "privacyNoteRedacted", 1, true) ~= nil
                and string.find(privacyJSON, "World of Warcraft", 1, true) == nil
            local uncNote = slash .. slash .. "server"
                .. slash .. "share"
                .. slash .. "SavedVariables"
                .. slash .. "EventAlertMod.lua"
            local uncSaved = live.setCaseNote(live.cases[1].id, uncNote)
            local uncReport, uncJSON = live.buildReport()
            local uncRedacted = uncSaved == true
                and uncReport.cases[1].note == "[privacy-redacted]"
                and string.find(uncJSON, "server", 1, true) == nil
            live.setCaseNote(live.cases[1].id, "offline fixture")

            for index = 1, #live.cases do
                live.setCaseStatus(live.cases[index].id, "pass", "offline fixture")
            end
            local noReloadComplete, noReloadReason, noReloadReport = live.complete()
            local _, noReloadJSON = live.buildReport()
            local checkpoint = live.prepareReload()
            local sameLoadResumed, sameLoadReason = live.resumePendingReload()
            live.getState().reloadCheckpoint.bootToken = {}
            local resumed = live.resumePendingReload()
            local finalReport, finalJSON = live.buildReport()
            local hasGroundEvidence = type(finalReport.capabilities.groundEffectStatus) == "table"
                and type(finalReport.capabilities.groundEffectStatus.compiledAlertCount) == "number"
            local cancelled = live.cancel()
            local cancelCleared = live.getState() == nil and _G.EAM_LIVE_TEST_REPORT_JSON == nil
            local restarted = live.start("_xptr_")
            local restartProfile = live.getState()
            local restartedAsXPTR = restartProfile
                and restartProfile.declaredInstallation == "_xptr_"
            local cancelledRestart = live.cancel()
            return combatStart == false
                and combatStartReason == "combatDeferred"
                and started == true
                and initial.status == "incomplete"
                and initial.summary.pending == #live.cases
                and combatNote == false
                and combatNoteReason == "combatDeferred"
                and combatReload == false
                and combatReloadReason == "combatDeferred"
                and combatComplete == false
                and combatCompleteReason == "combatDeferred"
                and privacyRedacted
                and uncRedacted
                and noReloadComplete == false
                and noReloadReason == "reloadRequired"
                and noReloadReport.status == "incomplete"
                and string.find(noReloadJSON, "reloadCheckpointNotCompleted", 1, true) ~= nil
                and checkpoint == true
                and sameLoadResumed == false
                and sameLoadReason == "sameLoadRejected"
                and resumed == true
                and finalReport.session.resumedAfterReload == true
                and finalReport.session.reloadSequence == 1
                and finalReport.summary.passed == #live.cases
                and finalReport.status == "incomplete"
                and string.find(finalJSON, "offlineCannotSignoff", 1, true) ~= nil
                and hasGroundEvidence
                and cancelled == true
                and cancelCleared
                and restarted == true
                and restartedAsXPTR
                and cancelledRestart == true
                and (EAM.FlowTestMock and EAM.FlowTestMock.trace.gameplayAutomationCalls or 0) == 0
        end)

        _G.EAM_LIVE_TEST_SESSION = originalSession
        _G.EAM_LIVE_TEST_REPORT_JSON = originalReport
        _G.EAM_VALIDATION_PROFILE = originalProfile
        if EAM.FlowTestMock then
            EAM.FlowTestMock.setCombat(false)
        end
        local valid = ok and result == true
        return valid, valid and "offline session, privacy, combat, reload, and live signoff fail-closed passed"
            or "live session fail-closed mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "live_test.privacy_unc_anywhere",
    primarySuite = "boundary",
    suites = { boundary = true },
    run = function()
        local live = EAM.Debug and EAM.Debug.LiveTestSession
        local mock = EAM.FlowTestMock
        if not live or not mock then
            return STATUS_SKIP, "live privacy producer mock is offline only"
        end

        local originalSession = _G.EAM_LIVE_TEST_SESSION
        local originalReport = _G.EAM_LIVE_TEST_REPORT_JSON
        local originalProfile = _G.EAM_VALIDATION_PROFILE
        local originalCombat = mock.inCombat
        _G.EAM_LIVE_TEST_SESSION = nil
        _G.EAM_LIVE_TEST_REPORT_JSON = nil
        _G.EAM_VALIDATION_PROFILE = nil

        local ok, result = pcall(function()
            mock.setCombat(false)
            local started = live.start("_ptr_")
            local caseID = live.cases[1].id
            local slash = string.char(92)
            local redactedNote = "[privacy-redacted]"
            local pureUNC = slash .. slash .. "privacy-host-pure" .. slash .. "share-pure"
            local leadingUNC = "  \t" .. slash .. slash .. "privacy-host-leading" .. slash .. "share-leading"
            local embeddedUNC = "manual observation at "
                .. slash .. slash .. "privacy-host-embedded" .. slash .. "share-embedded"
                .. " during probe"
            local safeNote = "safe path"
                .. slash .. "segment and isolated pair " .. slash .. slash .. " without share separator"

            local function redactsEntireValue(note, marker)
                local saved = live.setCaseNote(caseID, note)
                local report, reportJSON = live.buildReport()
                return saved == true
                    and report.cases[1].note == redactedNote
                    and string.find(reportJSON, marker, 1, true) == nil
                    and string.find(reportJSON, "privacyNoteRedacted", 1, true) ~= nil
            end

            local pureRedacted = redactsEntireValue(pureUNC, "privacy-host-pure")
            local leadingRedacted = redactsEntireValue(leadingUNC, "privacy-host-leading")
            local embeddedRedacted = redactsEntireValue(embeddedUNC, "privacy-host-embedded")
            local safeSaved = live.setCaseNote(caseID, safeNote)
            local safeReport, safeJSON = live.buildReport()
            local safePreserved = safeSaved == true
                and safeReport.cases[1].note == safeNote
                and string.find(safeJSON, "privacyNoteRedacted", 1, true) == nil
            return started == true
                and pureRedacted
                and leadingRedacted
                and embeddedRedacted
                and safePreserved
        end)

        _G.EAM_LIVE_TEST_SESSION = originalSession
        _G.EAM_LIVE_TEST_REPORT_JSON = originalReport
        _G.EAM_VALIDATION_PROFILE = originalProfile
        mock.setCombat(originalCombat)
        local valid = ok and result == true
        return valid, valid and "UNC privacy values redact at start, after whitespace, and inline while safe slashes remain"
            or "UNC privacy producer sanitization mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "live_test.client_completion_gate",
    primarySuite = "boundary",
    suites = { boundary = true },
    run = function()
        local live = EAM.Debug and EAM.Debug.LiveTestSession
        local mock = EAM.FlowTestMock
        if not live or not mock then
            return STATUS_SKIP, "client completion gate mock is offline only"
        end

        local originalSession = _G.EAM_LIVE_TEST_SESSION
        local originalReport = _G.EAM_LIVE_TEST_REPORT_JSON
        local originalProfile = _G.EAM_VALIDATION_PROFILE
        local originalEnvironment = EAM.FlowTestEnvironment
        local originalInterface = mock.interface
        local originalCombat = mock.inCombat
        _G.EAM_LIVE_TEST_SESSION = nil
        _G.EAM_LIVE_TEST_REPORT_JSON = nil
        _G.EAM_VALIDATION_PROFILE = nil

        local ok, result = pcall(function()
            EAM.FlowTestEnvironment = nil
            mock.interface = EAM.Constants.INTERFACE
            mock.setCombat(false)
            local started = live.start("_ptr_")
            for index = 1, #live.cases do
                live.setCaseStatus(live.cases[index].id, "pass", "client-shaped offline fixture")
            end
            local checkpoint = live.prepareReload()
            local sameLoadResumed, sameLoadReason = live.resumePendingReload()
            live.getState().reloadCheckpoint.bootToken = {}
            local resumed = live.resumePendingReload()
            local activeReport = live.buildReport()
            local completed, completeReason, completeReport = live.complete()
            return started == true
                and checkpoint == true
                and sameLoadResumed == false
                and sameLoadReason == "sameLoadRejected"
                and resumed == true
                and activeReport.status == "incomplete"
                and activeReport.session.phase == "active"
                and activeReport.summary.passed == #live.cases
                and #activeReport.boundaryWarnings == 0
                and completed == true
                and completeReason == "complete"
                and completeReport.status == "pass"
                and completeReport.session.phase == "complete"
                and completeReport.session.reloadSequence == 1
                and completeReport.environment.executionSource == "client"
                and completeReport.environment.channelValidation == "pass"
                and completeReport.environment.isTestBuildKnown == true
                and completeReport.environment.isTestBuild == true
                and completeReport.environment.buildFlags.isPublicTestClient == true
                and #completeReport.boundaryWarnings == 0
        end)

        _G.EAM_LIVE_TEST_SESSION = originalSession
        _G.EAM_LIVE_TEST_REPORT_JSON = originalReport
        _G.EAM_VALIDATION_PROFILE = originalProfile
        EAM.FlowTestEnvironment = originalEnvironment
        mock.interface = originalInterface
        mock.setCombat(originalCombat)
        local valid = ok and result == true
        return valid, valid and "active phase cannot pass; complete phase requires reload and every client-shaped case"
            or "client completion gate mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "environment.client_profile_crosscheck",
    primarySuite = "boundary",
    suites = { boundary = true, aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local validation = EAM.Debug and EAM.Debug.ValidationEnvironment
        if not mock or not validation then
            return STATUS_SKIP, "client profile switching mock is offline only"
        end
        local originalEnvironment = EAM.FlowTestEnvironment
        local originalInterface = mock.interface
        local originalProfile = _G.EAM_VALIDATION_PROFILE
        EAM.FlowTestEnvironment = nil
        mock.interface = EAM.Constants.LEGACY_INTERFACE
        validation.setDeclaredInstallation("_xptr_")
        local xptr = validation.snapshot()
        validation.setDeclaredInstallation("_ptr_")
        local mismatch = validation.snapshot()
        EAM.FlowTestEnvironment = originalEnvironment
        mock.interface = originalInterface
        _G.EAM_VALIDATION_PROFILE = originalProfile

        local valid = xptr.clientChannel == "XPTR"
            and xptr.declaredInstallation == "_xptr_"
            and xptr.patch == "12.0.7"
            and xptr.interface == EAM.Constants.LEGACY_INTERFACE
            and xptr.source == "xptr-live-manual"
            and xptr.channelValidation == "pass"
            and mismatch.clientChannel == "PTR"
            and mismatch.channelValidation == "mismatch"
        return valid, valid and "XPTR 12.0.7 identity and PTR mismatch cross-check passed" or "client profile cross-check mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "duration.adapter.contract",
    primarySuite = "core",
    suites = { core = true, boundary = true, aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local adapter = EAM.Modules and EAM.Modules.DurationAdapter
        if not mock or not adapter then
            return STATUS_SKIP, "DurationAdapter strict mock is offline only"
        end
        mock.resetTrace()
        local fontString = mock.createAuraButtonForTest():CreateFontString()
        local durationObject = adapter.createFromStart(12, 30)
        local binding = adapter.createTextBinding(durationObject, fontString)
        local released = adapter.releaseTextBinding(binding)
        local valid = durationObject ~= nil
            and durationObject.startTime == 12
            and durationObject.duration == 30
            and binding ~= nil
            and binding.fontString == fontString
            and binding.durationObject == durationObject
            and binding.formatter ~= nil
            and binding.enabled == false
            and binding.reset == true
            and released == true
            and mock.trace.durationCreates == 1
            and mock.trace.durationSetTimeCalls == 1
            and mock.trace.durationBindingCreates == 1
            and mock.trace.durationBindingEnables == 1
        return valid, valid and "DurationObject and text binding use the 12.x no-argument factory lifecycle"
            or "DurationAdapter lifecycle mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "cooldown.spell.duration_contract",
    primarySuite = "core",
    suites = { core = true, boundary = true },
    run = function()
        local mock = EAM.FlowTestMock
        local service = EAM.Services and EAM.Services.CooldownService
        local cSpell = api.C_Spell
        if not mock or not service or not cSpell then
            return false, "CooldownService dependencies unavailable"
        end
        local originalDB = EAM.db
        local originalStates = service.states
        local originalCharges = cSpell.GetSpellCharges
        local originalCooldown = cSpell.GetSpellCooldown
        local originalDuration = cSpell.GetSpellCooldownDuration
        local marker = { source = "official-spell-duration" }
        local ok, result = pcall(function()
            EAM.db = {
                revision = 820001,
                alerts = {
                    spellCooldowns = {
                        ["spellCooldown:player:50101"] = {
                            id = "spellCooldown:player:50101",
                            enabled = true,
                            spellID = 50101,
                        },
                    },
                },
            }
            service.states = {}
            cSpell.GetSpellCharges = function()
                return nil
            end
            cSpell.GetSpellCooldown = function(spellID)
                if spellID == 50101 then
                    return { startTime = 20, duration = 15, isEnabled = true, isOnGCD = false }
                end
                return nil
            end
            cSpell.GetSpellCooldownDuration = function(spellID)
                return spellID == 50101 and marker or nil
            end
            service.updateAlertList()
            local state = service.refreshSpell(50101, "offlineFixture")
            local numericValid = state ~= nil
                and state.shown == true
                and state.timer.mode == EAM.Constants.TIMER_NUMERIC
                and state.timer.startTime == 20
                and state.timer.duration == 15
                and state.timer.expirationTime == 35
                and state.timer.durationObject == marker
            local secretTime = mock.createSecretScalar()
            cSpell.GetSpellCooldown = function(spellID)
                if spellID == 50101 then
                    return {
                        startTime = secretTime,
                        duration = secretTime,
                        isEnabled = true,
                        isOnGCD = false,
                    }
                end
                return nil
            end
            mock.resetTrace()
            local protectedState = service.refreshSpell(50101, "offlineSecretFixture")
            local protectedValid = protectedState == state
                and state.factsSafe == false
                and state.boundaryLimited == true
                and state.boundaryWarnings[1] == "cooldown:timingProtected"
                and state.timer.mode == EAM.Constants.TIMER_PROTECTED
                and state.timer.startTime == nil
                and state.timer.duration == nil
                and state.timer.expirationTime == nil
                and state.timer.durationObject == marker
                and mock.trace.secretScalarOperations == 0
            return numericValid and protectedValid
        end)
        EAM.db = originalDB
        service.states = originalStates
        cSpell.GetSpellCharges = originalCharges
        cSpell.GetSpellCooldown = originalCooldown
        cSpell.GetSpellCooldownDuration = originalDuration
        local valid = ok and result == true
        return valid, valid and "spell cooldown clears stale numerics and keeps only official DurationObject at the Secret boundary"
            or "spell cooldown duration contract mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "totem.duration_secret_boundary",
    primarySuite = "boundary",
    suites = { core = true, boundary = true, aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local service = EAM.Services and EAM.Services.TotemService
        if not mock or not service or type(api.GetTotemInfo) ~= "function" then
            return STATUS_SKIP, "Totem strict mock is offline only"
        end
        local originalStates = service.activeStates
        local originalTotems = mock.totems
        local ok, result = pcall(function()
            service.activeStates = {}
            mock.totems = {
                [1] = {
                    name = "Mock Totem",
                    startTime = 50,
                    duration = 30,
                    icon = 136102,
                    spellID = 90001,
                },
            }
            service.TotemStatePool.initialize()
            service.refreshSlot(1)
            local state = service.activeStates[1]
            local numericValid = state ~= nil
                and state.timer.mode == EAM.Constants.TIMER_NUMERIC
                and state.timer.startTime == 50
                and state.timer.duration == 30
                and state.timer.expirationTime == 80
                and state.timer.durationObject ~= nil

            local secretTime = mock.createSecretScalar()
            mock.totems[1].startTime = secretTime
            mock.totems[1].duration = secretTime
            mock.resetTrace()
            service.refreshSlot(1)
            local protectedValid = state.factsSafe == false
                and state.boundaryLimited == true
                and state.boundaryWarnings[1] == "totem:timingProtected"
                and state.timer.mode == EAM.Constants.TIMER_DISPLAY_ONLY
                and state.timer.startTime == nil
                and state.timer.duration == nil
                and state.timer.expirationTime == nil
                and state.timer.durationObject ~= nil
                and mock.trace.secretScalarOperations == 0
            return numericValid and protectedValid
        end)
        service.activeStates = originalStates
        mock.totems = originalTotems
        local valid = ok and result == true
        return valid, valid and "Totem uses global APIs and clears unsafe numeric timing while preserving native duration"
            or "Totem duration boundary contract mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "cooldown.item.targeted_121",
    primarySuite = "core",
    suites = { core = true, boundary = true, aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local service = EAM.Services and EAM.Services.ItemCooldownService
        local cItem = api.C_Item
        if not mock or not service or not cItem then
            return STATUS_SKIP, "item cooldown strict mock is offline only"
        end
        local originalDB = EAM.db
        local originalStates = service.states
        local originalGetItemCooldown = cItem.GetItemCooldown
        local originalGetItemNameByID = cItem.GetItemNameByID
        local originalGetItemIconByID = cItem.GetItemIconByID
        local reads = 0
        local ok, result = pcall(function()
            EAM.db = {
                revision = 820002,
                alerts = {
                    itemCooldowns = {
                        ["itemCooldown:player:55123"] = {
                            id = "itemCooldown:player:55123",
                            enabled = true,
                            itemID = 55123,
                        },
                    },
                },
            }
            service.states = {}
            cItem.GetItemCooldown = function(itemID)
                reads = reads + 1
                if itemID == 55123 then
                    return 40, 25, true
                end
                return 0, 0, true
            end
            cItem.GetItemNameByID = function(itemID)
                return "Mock Item " .. itemID
            end
            cItem.GetItemIconByID = function()
                return 134400
            end
            service.updateAlertList()
            mock.resetTrace()
            service.onCooldownEvent("SPELL_UPDATE_COOLDOWN", nil, nil, nil, nil, 99999)
            local readsAfterWrongItem = reads
            service.onCooldownEvent("SPELL_UPDATE_COOLDOWN")
            local readsAfterMergedRefresh = reads
            service.onCooldownEvent("SPELL_UPDATE_COOLDOWN", nil, nil, nil, nil, 55123)
            local state = service.states["itemCooldown:player:55123"]
            return readsAfterWrongItem == 0
                and readsAfterMergedRefresh == 1
                and reads == 2
                and state ~= nil
                and state.shown == true
                and state.source.event == "SPELL_UPDATE_COOLDOWN"
                and state.timer.mode == EAM.Constants.TIMER_NUMERIC
                and state.timer.startTime == 40
                and state.timer.duration == 25
                and state.timer.durationObject ~= nil
                and state.timer.durationObject.startTime == 40
                and state.timer.durationObject.duration == 25
                and mock.trace.durationCreates == 1
                and mock.trace.durationSetTimeCalls == 1
        end)
        EAM.db = originalDB
        service.states = originalStates
        cItem.GetItemCooldown = originalGetItemCooldown
        cItem.GetItemNameByID = originalGetItemNameByID
        cItem.GetItemIconByID = originalGetItemIconByID
        local valid = ok and result == true
        return valid, valid and "12.1 itemID targets one item and missing itemID safely falls back to merged refresh"
            or "12.1 targeted item cooldown refresh mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "ground.duration_resolution_chain",
    primarySuite = "boundary",
    suites = { boundary = true, core = true, aura121 = true },
    run = function()
        local service = EAM.Services and EAM.Services.GroundEffectService
        local cSpell = api.C_Spell
        local cTooltipInfo = api.C_TooltipInfo
        if not service or not cSpell or not cTooltipInfo then
            return false, "GroundEffectService dependencies unavailable"
        end
        local originalDB = EAM.db
        local originalDescription = cSpell.GetSpellDescription
        local originalSpellInfo = cSpell.GetSpellInfo
        local originalTooltip = cTooltipInfo.GetSpellByID
        local originalLocale = api.GetLocale
        local scheduler = EAM.Modules.Scheduler
        local originalAfter = scheduler and scheduler.after
        local ok, result = pcall(function()
            EAM.db = {
                revision = 820003,
                alerts = {
                    groundEffects = {
                        ["groundEffect:player:61001"] = { id = "groundEffect:player:61001", enabled = true, spellID = 61001, durationMode = "AUTO", manualDuration = 8 },
                        ["groundEffect:player:61002"] = { id = "groundEffect:player:61002", enabled = true, spellID = 61002, durationMode = "AUTO", manualDuration = 8 },
                        ["groundEffect:player:61003"] = { id = "groundEffect:player:61003", enabled = true, spellID = 61003, durationMode = "AUTO", manualDuration = 9 },
                        ["groundEffect:player:61004"] = { id = "groundEffect:player:61004", enabled = true, spellID = 61004, durationMode = "MANUAL", manualDuration = 11 },
                    },
                },
            }
            api.GetLocale = function()
                return "enUS"
            end
            cSpell.GetSpellDescription = function(spellID)
                if spellID == 61001 then
                    return "Lasts 12 sec."
                elseif spellID == 61004 then
                    return "Lasts 99 sec."
                end
                return nil
            end
            cSpell.GetSpellInfo = function(spellID)
                return { name = "Ground " .. spellID, iconID = 136243 }
            end
            cTooltipInfo.GetSpellByID = function(spellID)
                if spellID == 61002 then
                    return {
                        lines = {
                            { type = api.TooltipDataLineType.SpellDescription, leftText = "For 7 sec." },
                        },
                    }
                end
                return { lines = {} }
            end
            if scheduler then
                scheduler.after = function()
                    return true
                end
            end
            local refreshed, count = service.onConfigChanged()
            local d1, s1 = service.scrapeDuration(61001)
            local d2, s2 = service.scrapeDuration(61002)
            local d3, s3 = service.scrapeDuration(61003)
            local d4, s4 = service.scrapeDuration(61004)
            local triggered, triggerSource = service.triggerGroundEffect(61003)
            local state = service.activeStates[61003]
            return refreshed == true
                and count == 4
                and d1 == 12 and s1 == "spellDescription"
                and d2 == 7 and s2 == "tooltipDescription"
                and d3 == 9 and s3 == "manualFallback"
                and d4 == 11 and s4 == "manual"
                and triggered == true and triggerSource == "manualFallback"
                and state ~= nil
                and state.timer.duration == 9
                and state.source.api == "manualFallback"
                and state.boundaryWarnings[1] == "groundDurationManualFallback"
        end)
        EAM.db = originalDB
        api.GetLocale = originalLocale
        cSpell.GetSpellDescription = originalDescription
        cSpell.GetSpellInfo = originalSpellInfo
        cTooltipInfo.GetSpellByID = originalTooltip
        if scheduler then
            scheduler.after = originalAfter
        end
        wipe(service.activeAlerts)
        wipe(service.activeStates)
        local valid = ok and result == true
        return valid, valid and "ground duration resolves spell text, tooltip text, manual fallback, and manual override"
            or "ground duration resolution chain mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "ui.cooldown_swipe_alpha",
    primarySuite = "boundary",
    suites = { boundary = true, core = true, aura121 = true },
    run = function()
        local iconPool = EAM.UI and EAM.UI.IconPool
        if not iconPool then
            return false, "IconPool unavailable"
        end
        local cooldown = api.CreateFrame("Cooldown", nil, nil, "CooldownFrameTemplate")
        local icon = { cooldown = cooldown }
        local applied = iconPool.applyCooldownStyle(icon, { cooldownSwipeAlpha = 0.4 })
        local middle = cooldown.swipeAlpha
        iconPool.applyCooldownStyle(icon, { cooldownSwipeAlpha = -1 })
        local minimum = cooldown.swipeAlpha
        iconPool.applyCooldownStyle(icon, { cooldownSwipeAlpha = 2 })
        local maximum = cooldown.swipeAlpha
        local valid = applied == true and middle == 0.4 and minimum == 0 and maximum == 1
        return valid, valid and "cooldown swipe alpha applies and clamps to 0..1"
            or "cooldown swipe alpha contract mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.native.ptr8_region_options",
    primarySuite = "aura121",
    suites = { aura121 = true, boundary = true },
    run = function()
        local mock = EAM.FlowTestMock
        local nativeRenderer = EAM.UI and EAM.UI.NativeAuraRenderer
        if not mock or not nativeRenderer then
            return STATUS_SKIP, "PTR8 AuraButton mock is offline only"
        end
        local originalDB = EAM.db
        local originalPandemicCapability = nativeRenderer.nativePandemicRegionCapabilityCount
        local originalPandemicBound = nativeRenderer.pandemicRegionBoundCount
        local originalBorderCapability = nativeRenderer.nativeBorderCapabilityCount
        local originalDispelBound = nativeRenderer.nativeDispelTextureBoundCount
        local ok, result = pcall(function()
            EAM.db = buildAura121TestDB(820006)
            mock.resetTrace()
            local button = mock.createAuraButtonForTest()
            local initializer = nativeRenderer.createInitializer({
                style = {
                    showPandemic = true,
                    dispelMode = "STEALABLE",
                    dispelStyle = "BORDER_WITH_ICON",
                },
            }, nil, nil)
            initializer(button)
            local dispel = button.dispelTypeTextures[1]
            local options = dispel and dispel.options or nil
            local filterEnum = Enum.CustomAuraButtonDispelTypeStealableFilter
            local styleEnum = Enum.CustomAuraButtonDispelTypeTextureStyle
            return mock.trace.pandemicRegionAdds == 1
                and mock.trace.dispelTextureAdds == 1
                and #button.pandemicRegions == 1
                and options ~= nil
                and options.showAlways == false
                and options.showWhenHelpful == true
                and options.showWhenHarmful == false
                and options.stealableFilter == filterEnum.Stealable
                and options.style == styleEnum.BorderWithIcon
                and nativeRenderer.nativePandemicRegionCapabilityCount == originalPandemicCapability + 1
                and nativeRenderer.pandemicRegionBoundCount == originalPandemicBound + 1
                and nativeRenderer.nativeBorderCapabilityCount == originalBorderCapability + 1
                and nativeRenderer.nativeDispelTextureBoundCount == originalDispelBound + 1
                and mock.trace.auraGetterCalls == 0
                and mock.trace.postInitializationMutations == 0
        end)
        EAM.db = originalDB
        nativeRenderer.nativePandemicRegionCapabilityCount = originalPandemicCapability
        nativeRenderer.pandemicRegionBoundCount = originalPandemicBound
        nativeRenderer.nativeBorderCapabilityCount = originalBorderCapability
        nativeRenderer.nativeDispelTextureBoundCount = originalDispelBound
        local valid = ok and result == true
        return valid, valid and "PTR8 Pandemic Region and stealable Dispel options bind during initializeFrame"
            or "PTR8 AuraButton region/options binding mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.container.disable_clears_assignments",
    primarySuite = "aura121",
    suites = { aura121 = true, boundary = true },
    run = function()
        local mock = EAM.FlowTestMock
        if not mock then
            return STATUS_SKIP, "AuraContainer strict mock is offline only"
        end
        local ok, result = pcall(function()
            mock.resetTrace()
            local container = CreateFrame("AuraContainer")
            local button = container:AddAuraSlot("EAM_PTR8_CLEAR", "HELPFUL", {
                initializeFrame = function(frame)
                    frame:SetIcon({})
                    frame:SetDurationCooldown({})
                    frame:SetDurationText({})
                    frame:SetApplicationCount({})
                    frame:SetSpellName({})
                end,
            })
            container:SetEnabled(false)
            return #container.buttons == 1
                and container.buttons[1] == button
                and rawget(button, "icon") == nil
                and rawget(button, "cooldown") == nil
                and rawget(button, "durationText") == nil
                and rawget(button, "applicationCount") == nil
                and rawget(button, "spellName") == nil
                and mock.trace.auraAssignmentsCleared == 1
                and mock.trace.containerMutations == 2
        end)
        local valid = ok and result == true
        return valid, valid and "disabled AuraContainer clears AuraButton assignments while retaining the frame"
            or "disabled AuraContainer clear contract mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "unitpower.combat_deferred_no_reads",
    primarySuite = "boundary",
    suites = { boundary = true, aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local service = EAM.Services and EAM.Services.ClassPowerService
        if not mock or not service then
            return STATUS_SKIP, "UnitPower strict mock is offline only"
        end
        local originalCombat = mock.inCombat
        mock.setCombat(true)
        mock.resetTrace()
        local detected, updated, updateReason = service.detectClassPower(), nil, nil
        updated, updateReason = service.updatePower()
        service.onEvent("UNIT_POWER_FREQUENT", "player", "HOLY_POWER")
        local valid = detected == false
            and updated == false
            and updateReason == "combatDeferred"
            and service.getStatus().lastResultClass == "combatDeferred"
            and mock.trace.unitPowerReads == 0
            and mock.trace.unitPowerMaxReads == 0
        mock.setCombat(originalCombat)
        return valid, valid and "combat UnitPower reads are deferred without polling secret values"
            or "combat UnitPower read guard mismatch"
    end,
})
FlowTestRunner.registerCase({
    id = "aura121.native.dual_countdown_diagnostic",
    primarySuite = "aura121",
    suites = { aura121 = true, boundary = true },
    run = function()
        local mock = EAM.FlowTestMock
        local nativeRenderer = EAM.UI and EAM.UI.NativeAuraRenderer
        if not mock or not nativeRenderer then
            return STATUS_SKIP, "Native Aura diagnostic mock is offline only"
        end
        local originalDB = EAM.db
        local originalDualCount = nativeRenderer.dualCountdownButtonCount
        local originalBorderCount = nativeRenderer.nativeBorderCapabilityCount
        local ok, result = pcall(function()
            EAM.db = buildAura121TestDB(820004)
            EAM.db.config.nativeAuraDualCountdownProbe = true
            local button = mock.createAuraButtonForTest()
            local initializer = nativeRenderer.createInitializer({
                style = { showCountdown = false, showStacks = false, showName = false },
            }, nil, nil)
            initializer(button)
            return button.cooldown ~= nil
                and button.cooldown.hideCountdownNumbers == false
                and button.durationText ~= nil
                and rawget(button, "applicationCount") == nil
                and rawget(button, "spellName") == nil
                and nativeRenderer.dualCountdownButtonCount == originalDualCount + 1
                and nativeRenderer.nativeBorderCapabilityCount == originalBorderCount + 1
        end)
        EAM.db = originalDB
        nativeRenderer.dualCountdownButtonCount = originalDualCount
        nativeRenderer.nativeBorderCapabilityCount = originalBorderCount
        local valid = ok and result == true
        return valid, valid and "dual countdown remains an explicit diagnostic mode sharing Native aura duration"
            or "dual countdown diagnostic contract mismatch"
    end,
})

FlowTestRunner.registerCase({
    id = "aura121.compiler.style_fingerprint",
    primarySuite = "aura121",
    suites = { aura121 = true, boundary = true },
    run = function()
        local compiler = EAM.Managers and EAM.Managers.AuraRuleCompiler
        if not compiler then
            return false, "AuraRuleCompiler unavailable"
        end
        local firstDB = buildAura121TestDB(820005)
        firstDB.config.textLayout = firstDB.config.textLayout or {
            schema = 1,
            timer = { placement = "OUTSIDE_RIGHT_AT_TOP", fontSize = 18 },
            applications = { placement = "OUTSIDE_BOTTOM_AT_LEFT", fontSize = 20 },
        }
        local firstPlan = compiler.compile(firstDB, { backend = EAM.Constants.AURA_BACKEND_NATIVE })
        local rule = firstDB.alerts.playerAuras["aura:player:1001"]
        if not rule then
            for _, candidate in pairs(firstDB.alerts.playerAuras) do
                rule = candidate
                break
            end
        end
        if not rule then
            return false, "Aura fixture unavailable"
        end
        rule.showCountdown = false
        firstDB.config.textLayout.timer.placement = "INSIDE_TOP_LEFT"
        firstDB.revision = firstDB.revision + 1
        local secondPlan = compiler.compile(firstDB, { backend = EAM.Constants.AURA_BACKEND_NATIVE })
        local valid = firstPlan.fingerprint ~= secondPlan.fingerprint
        return valid, valid and "Native style and text placement participate in the compiler fingerprint"
            or "Native style fingerprint did not change"
    end,
})

FlowTestRunner.registerCase({
    id = "unitpower.secondary_and_secret_sink",
    primarySuite = "boundary",
    suites = { boundary = true, core = true, aura121 = true },
    run = function()
        local mock = EAM.FlowTestMock
        local service = EAM.Services and EAM.Services.ClassPowerService
        local probe = EAM.Debug and EAM.Debug.UnitPowerCapabilityProbe
        local renderer = EAM.UI and EAM.UI.Renderer
        if not mock or not service or not probe or not renderer then
            return STATUS_SKIP, "UnitPower strict mock is offline only"
        end
        local originalDB = EAM.db
        local originalRender = renderer.render
        local originalPowerType = mock.unitPowerType
        local originalPowerToken = mock.unitPowerToken
        local captured = nil
        local ok, result = pcall(function()
            EAM.db = { config = { powerHoly = true, powerRage = true } }
            renderer.render = function(state, frameType)
                captured = {
                    id = state.id,
                    shown = state.shown,
                    displayValue = state.displayValue,
                    stacks = state.stacks,
                    frameType = frameType,
                }
                return true
            end
            mock.unitPowerType = api.PowerType and api.PowerType.Mana or 0
            mock.unitPowerToken = "MANA"
            mock.setUnitPowerScenario(
                "PALADIN",
                { [9] = 1, [0] = 100 },
                { [9] = 5, [0] = 100 },
                {},
                {}
            )
            mock.resetTrace()
            local detected = service.detectClassPower()
            local updated, updateReason = service.updatePower()
            local readsBeforeMismatch = mock.trace.unitPowerReads
            service.onEvent("UNIT_POWER_FREQUENT", "player", "MANA")
            local mismatchIgnored = mock.trace.unitPowerReads == readsBeforeMismatch
            service.onEvent("UNIT_POWER_FREQUENT", "player", "HOLY_POWER")
            local matchingRead = mock.trace.unitPowerReads == readsBeforeMismatch + 1
            local safeValid = detected == true
                and updated == true
                and updateReason == "rendered"
                and service.getActivePowerType() == 9
                and service.getStatus().selectedFrom == "classSecondary"
                and captured ~= nil
                and captured.displayValue == 1
                and captured.stacks == nil
                and mismatchIgnored
                and matchingRead

            mock.setUnitPowerScenario("PALADIN", {}, { [9] = 5 }, { [9] = true }, {})
            service.detectClassPower()
            local secretUpdated, secretReason = service.updatePower()
            local secretValid = secretUpdated == false
                and secretReason == "secret"
                and service.getStatus().lastResultClass == "secret"
                and mock.trace.secretScalarOperations == 0

            mock.unitPowerType = 1
            mock.unitPowerToken = "RAGE"
            mock.setUnitPowerScenario(
                "PALADIN",
                { [9] = 1 },
                { [9] = 5, [1] = 100 },
                { [1] = true },
                {}
            )
            service.detectClassPower()
            mock.resetTrace()
            local started, report, reportJSON = probe.start()
            local primary = report and report.cases and report.cases[1]
            local selected = report and report.cases and report.cases[2]
            local markedPrimary = probe.markVisual("unitpower.primary.native_percent", "pass")
            local markedSelected = probe.markVisual("unitpower.selected.safe_or_native", "pass")
            local activeReport = probe.buildReport()
            local stopped, stoppedReport = probe.stop()
            local reportValid = started == true
                and report.type == "EAM_UNIT_POWER_CAPABILITY_REPORT"
                and report.rawValuesCollected == false
                and report.environment.executionSource == "offline-mock"
                and report.status ~= "pass"
                and primary.resultClass == "secret"
                and primary.statusBarSink == "accepted"
                and primary.radialSink == "accepted"
                and selected.resultClass == "safe-number"
                and markedPrimary == true
                and markedSelected == true
                and activeReport.status == "active"
                and activeReport.session.active == true
                and activeReport.cases[1].visualObservation == "pass"
                and activeReport.cases[2].visualObservation == "pass"
                and stopped == true
                and stoppedReport.status == "incomplete"
                and stoppedReport.session.active == false
                and stoppedReport.session.stoppedAtSessionMs ~= nil
                and reportJSON ~= nil
                and string.find(reportJSON, "currentPower", 1, true) == nil
                and string.find(reportJSON, "maxPower", 1, true) == nil
                and string.find(reportJSON, "percentValue", 1, true) == nil
                and mock.trace.secretScalarOperations == 0
            return safeValid and secretValid and reportValid
        end)
        renderer.render = originalRender
        EAM.db = originalDB
        mock.unitPowerType = originalPowerType
        mock.unitPowerToken = originalPowerToken
        mock.setUnitPowerScenario("PALADIN", {}, {}, {}, {})
        local valid = ok and result == true
        return valid, valid and "secondary UnitPower shows 1, filters events, and Secret percent only reaches native sinks"
            or "UnitPower safe/secret capability contract mismatch"
    end,
})
