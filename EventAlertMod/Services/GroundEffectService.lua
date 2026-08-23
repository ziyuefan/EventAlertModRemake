--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/GroundEffectService
檔案: Services\GroundEffectService.lua

責任:
- 將 canonical SavedVariables 與安全 Base／Override 法術族群編譯成 event spellID 索引，監聽玩家成功施法並建立地面效果計時。
- 非戰鬥、低頻解析法術說明；解析失敗時明確降級到使用者設定秒數。
- 將安全普通數字轉為 DurationObject，並以單一 Scheduler 處理到期。

邊界:
- UNIT_SPELLCAST_SUCCEEDED 熱路徑只讀預先編譯的安全快取，不查 Tooltip、不建立設定。
- 說明文字只接受可安全存取的普通字串；解析結果不覆寫 SavedVariables。
- spellID 必須先通過 Secret 與 table-key 檢查，才可索引自訂表。
]]
local _, EAM = ...

local api = EAM.API
local Util = EAM.Util
local DurationAdapter = EAM.Modules.DurationAdapter
local ModuleController = EAM.Modules and EAM.Modules.ModuleController
local Scheduler = nil

local GroundEffectService = {
    activeAlerts = {},
    activeStates = {},
    alertsBySpellID = {},
    configuredSpellIDByEventID = {},
    ambiguousEventSpellIDs = {},
    durationCache = {},
    compiledAlertCount = 0,
    compiledEventSpellCount = 0,
    familyCollisionCount = 0,
    restrictedActivationCount = 0,
    resolvedCount = 0,
    fallbackCount = 0,
    pendingCompile = false,
    pendingResolve = false,
    lastDbRevision = -1,
    lastResolutionSource = nil,
    lastActivationSpellID = nil,
    lastCanonicalSpellID = nil,
    lastTriggerResult = "uninitialized",
    defaults = {
        [19306] = { enabled = true, durationMode = "AUTO", manualDuration = 8, name = "暴風雪" },
        [84714] = { enabled = true, durationMode = "AUTO", manualDuration = 15, name = "寒冰寶珠" },
        [343292] = { enabled = true, durationMode = "AUTO", manualDuration = 6, name = "火焰之環" },
    },
}

EAM.Services.GroundEffectService = GroundEffectService

local function moduleEnabled()
    return not ModuleController
        or ModuleController.isEnabled(EAM.Constants.MODULE_KEYS.groundEffect)
end

local GroundEffectStatePool = {
    recycleBin = {},
    binSize = 0,
}

GroundEffectService.GroundEffectStatePool = GroundEffectStatePool

local function inCombat()
    return api.InCombatLockdown and api.InCombatLockdown() == true
end

local function safeSpellID(value)
    return Util.isSafePositiveNumber(value)
        and value % 1 == 0
        and Util.isSafeTableKey(value)
end

local function normalizeManualDuration(value)
    if not Util.isSafePositiveNumber(value) then
        return 8
    end
    if value < 0.1 then
        return 0.1
    elseif value > 3600 then
        return 3600
    end
    return value
end

function GroundEffectStatePool.initialize()
    for index = 1, 10 do
        local state = Util.tableCreate(0, 18)
        state.timer = Util.tableCreate(0, 6)
        state.source = Util.tableCreate(0, 4)
        state.boundaryWarnings = Util.tableCreate(2, 0)
        GroundEffectStatePool.recycleBin[index] = state
    end
    GroundEffectStatePool.binSize = 10
end

function GroundEffectStatePool.acquire()
    local state
    if GroundEffectStatePool.binSize > 0 then
        state = GroundEffectStatePool.recycleBin[GroundEffectStatePool.binSize]
        GroundEffectStatePool.recycleBin[GroundEffectStatePool.binSize] = nil
        GroundEffectStatePool.binSize = GroundEffectStatePool.binSize - 1
    else
        state = Util.tableCreate(0, 18)
        state.timer = Util.tableCreate(0, 6)
        state.source = Util.tableCreate(0, 4)
        state.boundaryWarnings = Util.tableCreate(2, 0)
    end
    state.releaseFunc = GroundEffectStatePool.release
    return state
end

function GroundEffectStatePool.release(state)
    if not state then
        return
    end
    state.id = nil
    state.kind = nil
    state.spellID = nil
    state.name = nil
    state.icon = nil
    state.stacks = nil
    state.active = false
    state.shown = false
    state.releaseFunc = nil
    wipe(state.timer)
    wipe(state.source)
    wipe(state.boundaryWarnings)
    GroundEffectStatePool.binSize = GroundEffectStatePool.binSize + 1
    GroundEffectStatePool.recycleBin[GroundEffectStatePool.binSize] = state
end

local function parseDurationText(value)
    if not Util.isSafeString(value) or value == "" then
        return nil
    end
    local locale = api.GetLocale and api.GetLocale() or "enUS"
    if locale == "enGB" then
        locale = "enUS"
    end
    local patterns = Util.MULTI_LOCALE_PATTERNS[locale] or Util.MULTI_LOCALE_PATTERNS.enUS
    local lowerValue = locale == "enUS" and string.lower(value) or value
    for index = 1, #patterns do
        local matched = string.match(lowerValue, patterns[index])
        local seconds = matched and tonumber(matched) or nil
        if Util.isSafePositiveNumber(seconds) and seconds <= 3600 then
            return seconds
        end
    end
    return nil
end

local function parseSpellDescription(spellID)
    local cSpell = api.C_Spell
    if not cSpell or type(cSpell.GetSpellDescription) ~= "function" then
        return nil
    end
    local ok, description = pcall(cSpell.GetSpellDescription, spellID)
    if not ok then
        return nil
    end
    return parseDurationText(description)
end

local function parseTooltipDescription(spellID)
    local cTooltipInfo = api.C_TooltipInfo
    local lineTypes = api.TooltipDataLineType
    local descriptionType = lineTypes and lineTypes.SpellDescription
    if descriptionType == nil
        or not cTooltipInfo
        or type(cTooltipInfo.GetSpellByID) ~= "function"
    then
        return nil
    end

    local ok, data = pcall(cTooltipInfo.GetSpellByID, spellID)
    if not ok or not Util.isReadableTable(data) then
        return nil
    end
    local lines, linesSafe = Util.readSafeField(data, "lines")
    if not linesSafe or not Util.isReadableTable(lines) then
        return nil
    end
    for index = 1, #lines do
        local line = lines[index]
        if Util.isReadableTable(line) then
            local lineType, typeSafe = Util.readSafeField(line, "type")
            if typeSafe and lineType == descriptionType then
                local text, textSafe = Util.readSafeField(line, "leftText")
                local duration = textSafe and parseDurationText(text) or nil
                if duration then
                    return duration
                end
            end
        end
    end
    return nil
end

local function resolveSpellIdentifier(callback, spellID)
    if type(callback) ~= "function" or not safeSpellID(spellID) then
        return nil
    end
    local ok, resolvedSpellID = pcall(callback, spellID)
    if not ok or not safeSpellID(resolvedSpellID) then
        return nil
    end
    return resolvedSpellID
end

local function indexEventSpellID(eventSpellID, canonicalSpellID)
    if not safeSpellID(eventSpellID) or not safeSpellID(canonicalSpellID) then
        return false
    end
    if eventSpellID ~= canonicalSpellID
        and GroundEffectService.alertsBySpellID[eventSpellID]
    then
        return false
    end
    if GroundEffectService.ambiguousEventSpellIDs[eventSpellID] then
        return false
    end

    local existing = GroundEffectService.configuredSpellIDByEventID[eventSpellID]
    if existing == nil then
        GroundEffectService.configuredSpellIDByEventID[eventSpellID] = canonicalSpellID
        GroundEffectService.compiledEventSpellCount = GroundEffectService.compiledEventSpellCount + 1
        return true
    end
    if existing ~= canonicalSpellID then
        GroundEffectService.configuredSpellIDByEventID[eventSpellID] = nil
        GroundEffectService.ambiguousEventSpellIDs[eventSpellID] = true
        GroundEffectService.compiledEventSpellCount = math.max(
            0,
            GroundEffectService.compiledEventSpellCount - 1
        )
        GroundEffectService.familyCollisionCount = GroundEffectService.familyCollisionCount + 1
    end
    return false
end

local function indexSpellFamily(canonicalSpellID)
    indexEventSpellID(canonicalSpellID, canonicalSpellID)
    local cSpell = api.C_Spell
    if not cSpell then
        return
    end

    local baseSpellID = resolveSpellIdentifier(cSpell.GetBaseSpell, canonicalSpellID)
    local overrideSpellID = resolveSpellIdentifier(cSpell.GetOverrideSpell, canonicalSpellID)
    indexEventSpellID(baseSpellID, canonicalSpellID)
    indexEventSpellID(overrideSpellID, canonicalSpellID)
    if baseSpellID then
        indexEventSpellID(
            resolveSpellIdentifier(cSpell.GetOverrideSpell, baseSpellID),
            canonicalSpellID
        )
    end
    if overrideSpellID then
        indexEventSpellID(
            resolveSpellIdentifier(cSpell.GetBaseSpell, overrideSpellID),
            canonicalSpellID
        )
    end

    if type(cSpell.GetSpellInfo) == "function" then
        local ok, spellInfo = pcall(cSpell.GetSpellInfo, canonicalSpellID)
        if ok and Util.isReadableTable(spellInfo) then
            local resolvedSpellID, fieldSafe = Util.readSafeField(spellInfo, "spellID")
            if fieldSafe then
                indexEventSpellID(resolvedSpellID, canonicalSpellID)
            end
        end
    end
end

local function compileAlerts()
    wipe(GroundEffectService.alertsBySpellID)
    wipe(GroundEffectService.configuredSpellIDByEventID)
    wipe(GroundEffectService.ambiguousEventSpellIDs)
    GroundEffectService.compiledAlertCount = 0
    GroundEffectService.compiledEventSpellCount = 0
    GroundEffectService.familyCollisionCount = 0
    local savedVariables = EAM.Modules and EAM.Modules.SavedVariables
    local alerts = savedVariables and savedVariables.getActiveAlerts
        and savedVariables.getActiveAlerts() or nil
    local list = alerts and alerts.groundEffects
    if type(list) == "table" and Util.canAccessTable(list) then
        for _, alert in pairs(list) do
            local spellID = type(alert) == "table" and alert.spellID or nil
            if alert.enabled ~= false and safeSpellID(spellID) then
                GroundEffectService.alertsBySpellID[spellID] = alert
                GroundEffectService.compiledAlertCount = GroundEffectService.compiledAlertCount + 1
            end
        end
    end
    for canonicalSpellID in pairs(GroundEffectService.alertsBySpellID) do
        indexSpellFamily(canonicalSpellID)
    end
    GroundEffectService.lastDbRevision = EAM.db and EAM.db.revision or 0
    GroundEffectService.pendingCompile = false
end

local function verifyCompiledAlerts()
    local revision = EAM.db and EAM.db.revision or 0
    if revision ~= GroundEffectService.lastDbRevision then
        if inCombat() then
            GroundEffectService.pendingCompile = true
            GroundEffectService.pendingResolve = true
            return false, "combatCompileDeferred"
        end
        compileAlerts()
    end
    return true, "compiled"
end

local function resolveAlertDuration(spellID, alert)
    local manualDuration = normalizeManualDuration(alert and alert.manualDuration)
    if alert and alert.durationMode == EAM.Constants.GROUND_DURATION_MANUAL then
        return manualDuration, "manual"
    end

    local duration = parseSpellDescription(spellID)
    if duration then
        return duration, "spellDescription"
    end
    duration = parseTooltipDescription(spellID)
    if duration then
        return duration, "tooltipDescription"
    end
    return manualDuration, "manualFallback"
end

function GroundEffectService.refreshDurationCache()
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    if inCombat() then
        GroundEffectService.pendingResolve = true
        return false, "combatDeferred"
    end
    local compiled, compileReason = verifyCompiledAlerts()
    if not compiled then
        return false, compileReason
    end
    wipe(GroundEffectService.durationCache)
    GroundEffectService.resolvedCount = 0
    GroundEffectService.fallbackCount = 0
    for spellID, alert in pairs(GroundEffectService.alertsBySpellID) do
        local duration, source = resolveAlertDuration(spellID, alert)
        GroundEffectService.durationCache[spellID] = {
            duration = duration,
            source = source,
        }
        GroundEffectService.resolvedCount = GroundEffectService.resolvedCount + 1
        if source == "manualFallback" then
            GroundEffectService.fallbackCount = GroundEffectService.fallbackCount + 1
        end
        GroundEffectService.lastResolutionSource = source
    end
    GroundEffectService.pendingResolve = false
    return true, GroundEffectService.resolvedCount
end

function GroundEffectService.scrapeDuration(spellID)
    if not moduleEnabled() then
        return nil, nil, "moduleDisabled"
    end
    if not safeSpellID(spellID) then
        return nil, nil, "invalidSpellID"
    end
    if inCombat() then
        GroundEffectService.pendingResolve = true
        return nil, nil, "combatDeferred"
    end
    local compiled, compileReason = verifyCompiledAlerts()
    if not compiled then
        return nil, nil, compileReason
    end
    local alert = GroundEffectService.alertsBySpellID[spellID]
    local duration, source = resolveAlertDuration(spellID, alert)
    GroundEffectService.durationCache[spellID] = {
        duration = duration,
        source = source,
    }
    GroundEffectService.lastResolutionSource = source
    return duration, source
end

local function onAlertExpired(spellID)
    if not safeSpellID(spellID) then
        return
    end
    local now = api.GetTime and api.GetTime() or 0
    local expireAt = GroundEffectService.activeAlerts[spellID]
    if not expireAt or now < expireAt - 0.05 then
        return
    end
    local state = GroundEffectService.activeStates[spellID]
    GroundEffectService.activeAlerts[spellID] = nil
    GroundEffectService.activeStates[spellID] = nil
    if not state then
        return
    end
    state.shown = false
    local router = EAM.Modules.EventRouter
    if router then
        router.fire("EAM_GROUND_EFFECT_STATE_CHANGED", state, EAM.Constants.ALERT_FRAME_TYPES.groundEffect)
    end
end

local function readSpellPresentation(spellID, alert)
    local name = alert and alert.name or EAM.L.EAM_GROUND_SKILL_DEFAULT or "地面技能"
    local icon = 136243
    local cSpell = api.C_Spell
    if cSpell and type(cSpell.GetSpellInfo) == "function" then
        local ok, spellInfo = pcall(cSpell.GetSpellInfo, spellID)
        if ok and Util.isReadableTable(spellInfo) then
            local spellName, nameSafe = Util.readSafeField(spellInfo, "name")
            local iconID, iconSafe = Util.readSafeField(spellInfo, "iconID")
            if nameSafe and Util.isSafeString(spellName) then
                name = spellName
            end
            if iconSafe and Util.isSafePositiveNumber(iconID) then
                icon = iconID
            end
        end
    end
    return name, icon
end

local function triggerGroundEffect(canonicalSpellID, activationSpellID)
    if not moduleEnabled() then
        GroundEffectService.lastTriggerResult = "moduleDisabled"
        return false, "moduleDisabled"
    end
    if not safeSpellID(canonicalSpellID) then
        GroundEffectService.lastTriggerResult = "invalidSpellID"
        return false, "invalidSpellID"
    end
    if not safeSpellID(activationSpellID) then
        activationSpellID = canonicalSpellID
    end
    local compiled, compileReason = verifyCompiledAlerts()
    if not compiled then
        GroundEffectService.lastTriggerResult = compileReason
        return false, compileReason
    end
    local alert = GroundEffectService.alertsBySpellID[canonicalSpellID]
    if not alert or alert.enabled == false then
        GroundEffectService.lastTriggerResult = "notMonitored"
        return false, "notMonitored"
    end
    if not Scheduler then
        Scheduler = EAM.Modules.Scheduler
    end

    local resolution = GroundEffectService.durationCache[canonicalSpellID]
    local duration = resolution and resolution.duration or normalizeManualDuration(alert.manualDuration)
    local source = resolution and resolution.source or "manualFallback"
    if not Util.isSafePositiveNumber(duration) then
        GroundEffectService.lastTriggerResult = "durationUnavailable"
        return false, "durationUnavailable"
    end

    local now = api.GetTime and api.GetTime() or 0
    GroundEffectService.activeAlerts[canonicalSpellID] = now + duration
    local state = GroundEffectService.activeStates[canonicalSpellID]
    if not state then
        local name, icon = readSpellPresentation(canonicalSpellID, alert)
        state = GroundEffectStatePool.acquire()
        state.id = "groundEffect_" .. canonicalSpellID
        state.kind = EAM.Constants.ALERT_KIND_GROUND_EFFECT
        state.spellID = canonicalSpellID
        state.name = name
        state.icon = icon
        state.stacks = 0
        state.active = true
        GroundEffectService.activeStates[canonicalSpellID] = state
    end

    state.shown = true
    state.timer.mode = EAM.Constants.TIMER_NUMERIC
    state.timer.startTime = now
    state.timer.duration = duration
    state.timer.expirationTime = now + duration
    state.timer.durationObject = DurationAdapter
        and DurationAdapter.createFromStart(now, duration) or nil
    state.source.event = "UNIT_SPELLCAST_SUCCEEDED"
    state.source.api = source
    state.source.activationSpellID = activationSpellID
    state.source.updatedAt = now
    wipe(state.boundaryWarnings)
    if source == "manualFallback" then
        state.boundaryWarnings[1] = "groundDurationManualFallback"
    end

    GroundEffectService.lastActivationSpellID = activationSpellID
    GroundEffectService.lastCanonicalSpellID = canonicalSpellID
    GroundEffectService.lastTriggerResult = source
    local router = EAM.Modules.EventRouter
    if router then
        router.fire("EAM_GROUND_EFFECT_STATE_CHANGED", state, EAM.Constants.ALERT_FRAME_TYPES.groundEffect)
    end
    if Scheduler and Scheduler.after then
        Scheduler.after(duration, onAlertExpired, canonicalSpellID)
    end
    return true, source
end

GroundEffectService.triggerGroundEffect = triggerGroundEffect

function GroundEffectService.onSpellcastSucceeded(eventName, unit, castGUID, spellID)
    if not moduleEnabled() then
        GroundEffectService.lastTriggerResult = "moduleDisabled"
        return false, "moduleDisabled"
    end
    if eventName ~= "UNIT_SPELLCAST_SUCCEEDED" or unit ~= "player" then
        GroundEffectService.lastTriggerResult = "eventIgnored"
        return false, "eventIgnored"
    end
    if not safeSpellID(spellID) then
        GroundEffectService.restrictedActivationCount = GroundEffectService.restrictedActivationCount + 1
        GroundEffectService.lastActivationSpellID = nil
        GroundEffectService.lastCanonicalSpellID = nil
        GroundEffectService.lastTriggerResult = "activationSpellRestricted"
        return false, "activationSpellRestricted"
    end

    local compiled, compileReason = verifyCompiledAlerts()
    if not compiled then
        GroundEffectService.lastTriggerResult = compileReason
        return false, compileReason
    end
    GroundEffectService.lastActivationSpellID = spellID
    GroundEffectService.lastCanonicalSpellID = nil
    if GroundEffectService.ambiguousEventSpellIDs[spellID] then
        GroundEffectService.lastTriggerResult = "ambiguousSpellFamily"
        return false, "ambiguousSpellFamily"
    end

    local canonicalSpellID
    if GroundEffectService.alertsBySpellID[spellID] then
        canonicalSpellID = spellID
    else
        canonicalSpellID = GroundEffectService.configuredSpellIDByEventID[spellID]
    end
    if not safeSpellID(canonicalSpellID) then
        GroundEffectService.lastTriggerResult = "notMonitored"
        return false, "notMonitored"
    end
    GroundEffectService.lastCanonicalSpellID = canonicalSpellID
    return triggerGroundEffect(canonicalSpellID, spellID)
end

function GroundEffectService.onConfigChanged()
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    if inCombat() then
        GroundEffectService.pendingCompile = true
        GroundEffectService.pendingResolve = true
        return false, "combatCompileDeferred"
    end
    compileAlerts()
    return GroundEffectService.refreshDurationCache()
end

function GroundEffectService.onSpellTopologyChanged(eventName, unit)
    if eventName == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
        return false, "unitIgnored"
    end
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    if inCombat() then
        GroundEffectService.pendingCompile = true
        GroundEffectService.pendingResolve = true
        return false, "combatCompileDeferred"
    end
    compileAlerts()
    return GroundEffectService.refreshDurationCache()
end

function GroundEffectService.onCombatEnd()
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    if GroundEffectService.pendingCompile then
        compileAlerts()
        GroundEffectService.pendingResolve = true
    end
    if GroundEffectService.pendingResolve then
        return GroundEffectService.refreshDurationCache()
    end
    return true, "unchanged"
end

function GroundEffectService.initialize()
    Scheduler = EAM.Modules.Scheduler
    GroundEffectStatePool.initialize()
    local savedVariables = EAM.Modules.SavedVariables
    local alerts = savedVariables and savedVariables.getActiveAlerts
        and savedVariables.getActiveAlerts() or nil
    local list = alerts and alerts.groundEffects
    if savedVariables and list then
        for spellID, definition in pairs(GroundEffectService.defaults) do
            local id = savedVariables.buildAlertID(EAM.Constants.ALERT_KIND_GROUND_EFFECT, "player", spellID)
            if not list[id] then
                savedVariables.addGroundEffectAlert(spellID, definition)
            end
        end
    end
    compileAlerts()
    if moduleEnabled() then
        GroundEffectService.refreshDurationCache()
    end

    local router = EAM.Modules.EventRouter
    if router then
        router.register("UNIT_SPELLCAST_SUCCEEDED", GroundEffectService.onSpellcastSucceeded)
        router.register("SPELLS_CHANGED", GroundEffectService.onSpellTopologyChanged)
        router.register("PLAYER_TALENT_UPDATE", GroundEffectService.onSpellTopologyChanged)
        router.register("PLAYER_SPECIALIZATION_CHANGED", GroundEffectService.onSpellTopologyChanged)
        router.register("ACTIVE_TALENT_GROUP_CHANGED", GroundEffectService.onSpellTopologyChanged)
        router.register("TRAIT_CONFIG_UPDATED", GroundEffectService.onSpellTopologyChanged)
        router.register("PLAYER_REGEN_ENABLED", GroundEffectService.onCombatEnd)
        router.register("EAM_GROUND_EFFECT_CONFIG_CHANGED", GroundEffectService.onConfigChanged)
    end
end

function GroundEffectService.onModuleToggle(enabled, reason)
    if enabled == false then
        local router = EAM.Modules.EventRouter
        for spellID, state in pairs(GroundEffectService.activeStates) do
            state.shown = false
            GroundEffectService.activeStates[spellID] = nil
            GroundEffectService.activeAlerts[spellID] = nil
            if router then
                router.fire(
                    "EAM_GROUND_EFFECT_STATE_CHANGED",
                    state,
                    EAM.Constants.ALERT_FRAME_TYPES.groundEffect
                )
            end
        end
        wipe(GroundEffectService.activeAlerts)
        wipe(GroundEffectService.durationCache)
        GroundEffectService.pendingCompile = false
        GroundEffectService.pendingResolve = false
        return true, "disabled"
    end
    return GroundEffectService.onSpellTopologyChanged("moduleEnabled")
end

function GroundEffectService.getStatus()
    return {
        compiledAlertCount = GroundEffectService.compiledAlertCount,
        compiledEventSpellCount = GroundEffectService.compiledEventSpellCount,
        familyCollisionCount = GroundEffectService.familyCollisionCount,
        restrictedActivationCount = GroundEffectService.restrictedActivationCount,
        resolvedCount = GroundEffectService.resolvedCount,
        fallbackCount = GroundEffectService.fallbackCount,
        pendingCompile = GroundEffectService.pendingCompile,
        pendingResolve = GroundEffectService.pendingResolve,
        lastResolutionSource = GroundEffectService.lastResolutionSource,
        lastActivationSpellID = GroundEffectService.lastActivationSpellID,
        lastCanonicalSpellID = GroundEffectService.lastCanonicalSpellID,
        lastTriggerResult = GroundEffectService.lastTriggerResult,
    }
end
