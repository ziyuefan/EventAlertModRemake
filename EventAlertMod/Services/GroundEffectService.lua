--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/GroundEffectService
檔案: Services\GroundEffectService.lua

責任:
- 將 canonical SavedVariables 編譯成 spellID 索引，監聽玩家成功施法並建立地面效果計時。
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
    durationCache = {},
    compiledAlertCount = 0,
    resolvedCount = 0,
    fallbackCount = 0,
    pendingResolve = false,
    lastDbRevision = -1,
    lastResolutionSource = nil,
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

local function compileAlerts()
    wipe(GroundEffectService.alertsBySpellID)
    GroundEffectService.compiledAlertCount = 0
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
    GroundEffectService.lastDbRevision = EAM.db and EAM.db.revision or 0
end

local function verifyCompiledAlerts()
    local revision = EAM.db and EAM.db.revision or 0
    if revision ~= GroundEffectService.lastDbRevision then
        compileAlerts()
    end
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
    verifyCompiledAlerts()
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

local function triggerGroundEffect(spellID)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    if not safeSpellID(spellID) then
        return false, "invalidSpellID"
    end
    verifyCompiledAlerts()
    local alert = GroundEffectService.alertsBySpellID[spellID]
    if not alert or alert.enabled == false then
        return false, "notMonitored"
    end
    if not Scheduler then
        Scheduler = EAM.Modules.Scheduler
    end

    local resolution = GroundEffectService.durationCache[spellID]
    local duration = resolution and resolution.duration or normalizeManualDuration(alert.manualDuration)
    local source = resolution and resolution.source or "manualFallback"
    if not Util.isSafePositiveNumber(duration) then
        return false, "durationUnavailable"
    end

    local now = api.GetTime and api.GetTime() or 0
    GroundEffectService.activeAlerts[spellID] = now + duration
    local state = GroundEffectService.activeStates[spellID]
    if not state then
        local name, icon = readSpellPresentation(spellID, alert)
        state = GroundEffectStatePool.acquire()
        state.id = "groundEffect_" .. spellID
        state.kind = EAM.Constants.ALERT_KIND_GROUND_EFFECT
        state.spellID = spellID
        state.name = name
        state.icon = icon
        state.stacks = 0
        state.active = true
        GroundEffectService.activeStates[spellID] = state
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
    state.source.updatedAt = now
    wipe(state.boundaryWarnings)
    if source == "manualFallback" then
        state.boundaryWarnings[1] = "groundDurationManualFallback"
    end

    local router = EAM.Modules.EventRouter
    if router then
        router.fire("EAM_GROUND_EFFECT_STATE_CHANGED", state, EAM.Constants.ALERT_FRAME_TYPES.groundEffect)
    end
    if Scheduler and Scheduler.after then
        Scheduler.after(duration, onAlertExpired, spellID)
    end
    return true, source
end

GroundEffectService.triggerGroundEffect = triggerGroundEffect

function GroundEffectService.onSpellcastSucceeded(eventName, unit, castGUID, spellID)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    if eventName ~= "UNIT_SPELLCAST_SUCCEEDED" or unit ~= "player" or not safeSpellID(spellID) then
        return
    end
    triggerGroundEffect(spellID)
end

function GroundEffectService.onConfigChanged()
    compileAlerts()
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    return GroundEffectService.refreshDurationCache()
end

function GroundEffectService.onCombatEnd()
    if not moduleEnabled() then
        return false, "moduleDisabled"
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
        router.register("PLAYER_REGEN_ENABLED", GroundEffectService.onCombatEnd)
        router.register("EAM_GROUND_EFFECT_CONFIG_CHANGED", GroundEffectService.onConfigChanged)
    end
end

function GroundEffectService.onModuleToggle(enabled, reason)
    compileAlerts()
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
        GroundEffectService.pendingResolve = false
        return true, "disabled"
    end
    return GroundEffectService.refreshDurationCache()
end

function GroundEffectService.getStatus()
    return {
        compiledAlertCount = GroundEffectService.compiledAlertCount,
        resolvedCount = GroundEffectService.resolvedCount,
        fallbackCount = GroundEffectService.fallbackCount,
        pendingResolve = GroundEffectService.pendingResolve,
        lastResolutionSource = GroundEffectService.lastResolutionSource,
    }
end
