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
    schemaVersion = 1,
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
    local inCombat = false
    if api.InCombatLockdown then
        local value = api.InCombatLockdown()
        if type(value) == "boolean" then
            inCombat = value
        end
    end

    local locale = nil
    if api.GetLocale then
        locale = safeScalar(api.GetLocale())
    end

    return {
        addon = "EventAlertMod",
        addonVersion = safeScalar(EAM.version) or "unknown",
        interface = EAM.Constants and EAM.Constants.INTERFACE or 0,
        flavor = EAM.Constants and EAM.Constants.ADDON_FLAVOR or "Retail",
        initialized = EAM.Modules and EAM.Modules.Main and EAM.Modules.Main.initialized == true or false,
        inCombat = inCombat,
        locale = locale or "unknown",
        source = safeScalar(EAM.FlowTestEnvironment) or "retail-client",
    }
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

    local report = {
        schema = FlowTestRunner.schemaVersion,
        type = "EAM_FLOW_VALIDATION_REPORT",
        suite = session.suite,
        status = summary.failed == 0 and summary.pending == 0 and STATUS_PASS or STATUS_FAIL,
        generatedAtSessionMs = nowMilliseconds(),
        environment = buildEnvironment(),
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
    id = "aura121.saved_variables.migration_v1_v2",
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
            config = {},
        }
        saved.initialize()
        local alert = EAM_DB.alerts.playerAuras["aura:player:4001"]
        local backup = EAM_DB.migrationBackups and EAM_DB.migrationBackups.auraSchemaV1
        local valid = EAM_DB.schemaVersion == 2
            and EAM_DB.customField == "preserve-me"
            and alert and alert.unknownField == "keep"
            and alert.nativeBackend == "AUTO"
            and backup ~= nil
            and backup.playerAuras ~= nil
            and backup.playerAuras["aura:player:4001"] ~= nil
        EAM_DB = originalGlobalDB
        EAM.db = originalDB
        return valid, valid and "schema v1 migrated with backup and unknown fields preserved" or "schema v1 migration contract mismatch"
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
