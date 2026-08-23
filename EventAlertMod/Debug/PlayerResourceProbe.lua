--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/PlayerResourceProbe
檔案: Debug\PlayerResourceProbe.lua

責任:
- 在玩家手動啟動 UnitPower 能力測試期間，觀察各候選資源相關事件與安全能力 metadata。
- 產生不含 UnitPower、UnitPowerMax、percent 或其他 Secret 原始值的獨立 JSON 報告。

邊界:
- 不輪詢、不建立 OnUpdate、不呼叫 UnitPower/UnitPowerMax/UnitPowerPercent。
- 只讀取 PlayerResourceService 已正規化的安全 metadata，停止時解除所有事件。
- eventObserved 只代表事件已被玩家實機流程觸發，不代表視覺或數值正確。
]]
local _, EAM = ...

local api = EAM.API
local Util = EAM.Util
local Capability = EAM.Services.PlayerResourceCapability

local PlayerResourceProbe = {
    schemaVersion = 2,
    active = false,
    eventsRegistered = false,
    observedByKey = {},
    observedByEvent = {},
    observedByToken = {},
    observedEventCount = 0,
    startedAt = nil,
    stoppedAt = nil,
    lastReport = nil,
    lastReportJSON = nil,
    missingCheckDelay = 0.75,
    missingCheckGeneration = 0,
    missingCheckScheduled = false,
    missingCheckExecutedCount = 0,
}

EAM.Debug.PlayerResourceProbe = PlayerResourceProbe

local function sessionTime()
    return api.GetTime and api.GetTime() or 0
end

local function serviceStatus()
    local service = EAM.Services and EAM.Services.PlayerResourceService
    if service and type(service.getStatus) == "function" then
        return service.getStatus()
    end
    return nil
end

local function markResource(resourceKey,eventName,powerToken)
    if not Util.isSafeString(resourceKey) then
        return false
    end
    if Util.canAccessTable and not Util.canAccessTable(PlayerResourceProbe.observedByKey) then
        return false
    end
    local observation = PlayerResourceProbe.observedByKey[resourceKey]
    if type(observation) ~= 'table' then
        observation = { count = 0, events = {}, tokens = {} }
        PlayerResourceProbe.observedByKey[resourceKey] = observation
    end
    observation.count = observation.count + 1
    local eventSafe = Util.isSafeString(eventName) and eventName or nil
    local tokenSafe = Util.isSafeString(powerToken) and powerToken or nil
    if eventSafe then
        observation.events[eventSafe] = (observation.events[eventSafe] or 0) + 1
        PlayerResourceProbe.observedByEvent[eventSafe] = (PlayerResourceProbe.observedByEvent[eventSafe] or 0) + 1
    end
    if tokenSafe then
        observation.tokens[tokenSafe] = (observation.tokens[tokenSafe] or 0) + 1
        PlayerResourceProbe.observedByToken[tokenSafe] = (PlayerResourceProbe.observedByToken[tokenSafe] or 0) + 1
    end
    local service = EAM.Services and EAM.Services.PlayerResourceService
    if service and type(service.setBackgroundSamplingRequired) == 'function' then
        service.setBackgroundSamplingRequired(resourceKey, false)
    end
    return true
end

local function markForegroundTracked(status,eventName)
    local resources = status and status.resources
    if type(resources) ~= "table" or not Util.canAccessTable(resources) then
        return false
    end
    local marked = false
    for index = 1, #resources do
        local resource = resources[index]
        if type(resource) == "table" and resource.tracked == true
            and resource.foreground == true
            and markResource(resource.key,eventName)
        then
            marked = true
        end
    end
    return marked
end

local function markToken(status, powerToken,eventName)
    if not Util.isSafeString(powerToken) then
        return false
    end
    local resources = status and status.resources
    if type(resources) ~= "table" or not Util.canAccessTable(resources) then
        return false
    end
    for index = 1, #resources do
        local resource = resources[index]
        if type(resource) == "table" and Util.isSafeString(resource.token)
            and resource.token == powerToken
        then
            return markResource(resource.key,eventName,powerToken)
        end
    end
    return false
end
local function sinkAvailable(capability)
    local renderer = EAM.UI and EAM.UI.PowerRenderer
    if type(renderer) ~= "table" then
        return false
    end
    if capability == Capability.SECRET_DISPLAY then
        return type(renderer.applySecretPercent) == "function"
    end
    if capability == Capability.NUMERIC then
        return type(renderer.applyNumeric) == "function"
    end
    return false
end

local function buildCountEntries(counts,fieldName)
    local entries = {}
    if type(counts) ~= 'table' then
        return entries
    end
    for key,count in pairs(counts) do
        if Util.isSafeString(key) and Util.isSafePositiveNumber(count) then
            local entry = { count = count }
            entry[fieldName] = key
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries,function(left,right)
        return left[fieldName] < right[fieldName]
    end)
    return entries
end

local function buildResources(status)
    local result = {}
    local resources = status and status.resources
    if type(resources) ~= "table" or not Util.canAccessTable(resources) then
        return result
    end
    for index = 1, #resources do
        local source = resources[index]
        if type(source) == "table" and Util.isSafeString(source.key)
            and Util.isSafeNonNegativeNumber(source.powerType)
            and Util.isSafeString(source.capability)
        then
            local observation = PlayerResourceProbe.observedByKey[source.key]
            local eventObservationCount = type(observation) == "table"
                and observation.count or 0
            result[#result + 1] = {
                key = source.key,
                powerType = source.powerType,
                tracked = source.tracked == true,
                available = source.available == true,
                foreground = source.foreground == true,
                background = source.background == true,
                capability = source.capability,
                sinkAvailable = sinkAvailable(source.capability),
                eventObserved = eventObservationCount > 0,
                eventObservationCount = eventObservationCount,
                observedEvents = buildCountEntries(observation and observation.events, "event"),
                observedPowerTokens = buildCountEntries(observation and observation.tokens, "token"),
                backgroundSamplingRequired = source.backgroundSamplingRequired == true,
            }
        end
    end
    return result
end

function PlayerResourceProbe.buildReport()
    local validationEnvironment = EAM.Debug and EAM.Debug.ValidationEnvironment
    local environment, environmentWarnings
    if validationEnvironment and type(validationEnvironment.snapshot) == "function" then
        environment, environmentWarnings = validationEnvironment.snapshot()
    else
        environment = { executionSource = "client", channelValidation = "unknown" }
        environmentWarnings = { "validationEnvironmentUnavailable" }
    end

    local status = serviceStatus()
    local warnings = {}
    for index = 1, #(environmentWarnings or {}) do
        warnings[#warnings + 1] = environmentWarnings[index]
    end
    if not status then
        warnings[#warnings + 1] = "playerResourceServiceUnavailable"
    end

    local report = {
        schema = PlayerResourceProbe.schemaVersion,
        type = "EAM_PLAYER_RESOURCE_PROBE_REPORT",
        purpose = "resource-event-capability-probe",
        status = PlayerResourceProbe.active and "active" or "incomplete",
        rawValuesCollected = false,
        session = {
            active = PlayerResourceProbe.active,
            startedAtSessionMs = PlayerResourceProbe.startedAt,
            stoppedAtSessionMs = PlayerResourceProbe.stoppedAt,
        },
        environment = environment,
        events = {
            registered = PlayerResourceProbe.eventsRegistered,
            observedCount = PlayerResourceProbe.observedEventCount,
            observedEventNames = buildCountEntries(PlayerResourceProbe.observedByEvent, "event"),
            observedPowerTokens = buildCountEntries(PlayerResourceProbe.observedByToken, "token"),
            missingEventCheckScheduled = PlayerResourceProbe.missingCheckScheduled,
            missingEventCheckExecutedCount = PlayerResourceProbe.missingCheckExecutedCount,
        },
        resources = buildResources(status),
        boundaryWarnings = warnings,
    }

    local encoder = EAM.Debug.FlowTestRunner and EAM.Debug.FlowTestRunner.encodeJSON
    local reportJSON = encoder and encoder(report) or nil
    PlayerResourceProbe.lastReport = report
    PlayerResourceProbe.lastReportJSON = reportJSON
    _G.EAM_PLAYER_RESOURCE_PROBE_REPORT_JSON = reportJSON
    return report, reportJSON
end

local function invalidateMissingEventCheck()
    PlayerResourceProbe.missingCheckGeneration =
        PlayerResourceProbe.missingCheckGeneration + 1
    PlayerResourceProbe.missingCheckScheduled = false
end

local function runMissingEventCheck(owner)
    local generation = type(owner) == "table" and owner.generation or nil
    if generation ~= PlayerResourceProbe.missingCheckGeneration
        or not PlayerResourceProbe.active
    then
        return
    end
    PlayerResourceProbe.missingCheckScheduled = false
    PlayerResourceProbe.missingCheckExecutedCount =
        PlayerResourceProbe.missingCheckExecutedCount + 1

    local status = serviceStatus()
    local resources = status and status.resources
    if type(resources) == "table" and Util.canAccessTable(resources) then
        for index = 1, #resources do
            local resource = resources[index]
            if type(resource) == "table"
                and resource.tracked == true
                and resource.available == true
                and resource.background == true
                and Util.isSafeString(resource.key)
            then
                PlayerResourceProbe.markBackgroundEventMissing(resource.key)
            end
        end
    end
    PlayerResourceProbe.buildReport()
end

local function scheduleMissingEventCheck()
    local scheduler = EAM.Modules and EAM.Modules.Scheduler
    if not scheduler or type(scheduler.after) ~= "function" then
        return false, "schedulerUnavailable"
    end
    local generation = PlayerResourceProbe.missingCheckGeneration
    local owner = { generation = generation }
    local scheduled = scheduler.after(
        PlayerResourceProbe.missingCheckDelay,
        runMissingEventCheck,
        owner
    )
    if scheduled then
        PlayerResourceProbe.missingCheckScheduled = true
        return true, "scheduled"
    end
    return false, "scheduleRejected"
end
function PlayerResourceProbe.markBackgroundEventMissing(resourceKey)
    if not PlayerResourceProbe.active then
        return false, "probeInactive"
    end
    if not Util.isSafeString(resourceKey)
        or (type(PlayerResourceProbe.observedByKey[resourceKey]) == "table" and PlayerResourceProbe.observedByKey[resourceKey].count > 0)
    then
        return false, "eventAlreadyObservedOrUnsafeKey"
    end
    local status = serviceStatus()
    local resources = status and status.resources
    if type(resources) ~= "table" or not Util.canAccessTable(resources) then
        return false, "resourceStatusUnavailable"
    end
    for index = 1, #resources do
        local resource = resources[index]
        if type(resource) == "table" and resource.key == resourceKey then
            if resource.tracked ~= true or resource.available ~= true or resource.background ~= true then
                return false, "resourceNotEligibleForBackgroundSampling"
            end
            local service = EAM.Services and EAM.Services.PlayerResourceService
            if not service or type(service.setBackgroundSamplingRequired) ~= "function" then
                return false, "backgroundSamplerUnavailable"
            end
            return service.setBackgroundSamplingRequired(resourceKey, true)
        end
    end
    return false, "resourceNotTracked"
end
function PlayerResourceProbe.onEvent(eventName, unit, powerToken)
    if not PlayerResourceProbe.active or not Util.isSafeString(eventName) then
        return false, "inactiveOrUnsafeEvent"
    end

    local status = serviceStatus()
    local observed = false
    if eventName == "UNIT_POWER_UPDATE" or eventName == "UNIT_POWER_FREQUENT"
        or eventName == "UNIT_MAXPOWER"
    then
        if unit == "player" then
            observed = markToken(status, powerToken,eventName)
        end
    elseif eventName == "RUNE_POWER_UPDATE" then
        observed = markResource("RUNES",eventName)
    elseif eventName == "UNIT_DISPLAYPOWER" then
        if unit == nil or unit == "player" then
            observed = markForegroundTracked(status,eventName)
        end
    elseif eventName == "UPDATE_SHAPESHIFT_FORM" then
        observed = markForegroundTracked(status,eventName)
    end

    if observed then
        PlayerResourceProbe.observedEventCount = PlayerResourceProbe.observedEventCount + 1
        PlayerResourceProbe.buildReport()
        return true, "eventObserved"
    end
    return false, "eventIgnored"
end

local function registerEvents()
    if PlayerResourceProbe.eventsRegistered then
        return true
    end
    local router = EAM.Modules and EAM.Modules.EventRouter
    if not router or type(router.register) ~= "function" then
        return false, "eventRouterUnavailable"
    end
    router.register("UNIT_POWER_UPDATE", PlayerResourceProbe.onEvent)
    router.register("UNIT_POWER_FREQUENT", PlayerResourceProbe.onEvent)
    router.register("UNIT_MAXPOWER", PlayerResourceProbe.onEvent)
    router.register("RUNE_POWER_UPDATE", PlayerResourceProbe.onEvent)
    router.register("UNIT_DISPLAYPOWER", PlayerResourceProbe.onEvent)
    router.register("UPDATE_SHAPESHIFT_FORM", PlayerResourceProbe.onEvent)
    PlayerResourceProbe.eventsRegistered = true
    return true
end

local function unregisterEvents()
    if not PlayerResourceProbe.eventsRegistered then
        return true
    end
    local router = EAM.Modules and EAM.Modules.EventRouter
    if not router or type(router.unregister) ~= "function" then
        return false, "eventRouterUnavailable"
    end
    router.unregister("UNIT_POWER_UPDATE", PlayerResourceProbe.onEvent)
    router.unregister("UNIT_POWER_FREQUENT", PlayerResourceProbe.onEvent)
    router.unregister("UNIT_MAXPOWER", PlayerResourceProbe.onEvent)
    router.unregister("RUNE_POWER_UPDATE", PlayerResourceProbe.onEvent)
    router.unregister("UNIT_DISPLAYPOWER", PlayerResourceProbe.onEvent)
    router.unregister("UPDATE_SHAPESHIFT_FORM", PlayerResourceProbe.onEvent)
    PlayerResourceProbe.eventsRegistered = false
    return true
end

function PlayerResourceProbe.start()
    if PlayerResourceProbe.active then
        return true, PlayerResourceProbe.buildReport()
    end
    local registered, reason = registerEvents()
    if not registered then
        return false, reason
    end
    invalidateMissingEventCheck()
    wipe(PlayerResourceProbe.observedByKey)
    wipe(PlayerResourceProbe.observedByEvent)
    wipe(PlayerResourceProbe.observedByToken)
    PlayerResourceProbe.observedEventCount = 0
    PlayerResourceProbe.missingCheckExecutedCount = 0
    PlayerResourceProbe.active = true
    PlayerResourceProbe.startedAt = sessionTime()
    PlayerResourceProbe.stoppedAt = nil
    local report, reportJSON = PlayerResourceProbe.buildReport()
    scheduleMissingEventCheck()
    return true, report, reportJSON
end

function PlayerResourceProbe.stop()
    if not PlayerResourceProbe.active then
        return false, "inactive"
    end
    PlayerResourceProbe.active = false
    invalidateMissingEventCheck()
    PlayerResourceProbe.stoppedAt = sessionTime()
    local unregistered, reason = unregisterEvents()
    local report, reportJSON = PlayerResourceProbe.buildReport()
    if not unregistered then
        return false, reason, report, reportJSON
    end
    return true, report, reportJSON
end

function PlayerResourceProbe.isActive()
    return PlayerResourceProbe.active
end

function PlayerResourceProbe.getLastReportJSON()
    return PlayerResourceProbe.lastReportJSON
end