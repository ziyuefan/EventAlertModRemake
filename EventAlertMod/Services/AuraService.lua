--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/AuraService
檔案: Services\AuraService.lua

理念:
- 作為 player/target aura facts 的唯一 adapter，隔離 Retail aura API 與 UI 層。
- 採取極致健壯且低 GC 的直讀策略，避免過度包裝導致普通屬性被誤判定為 restricted。
- 服務只產生 AlertState/AuraState，不直接渲染 UI。

責任:
- 接收 UNIT_AURA/target change 後更新 aura runtime cache。
- 在 timer 中寫入完整的 startTime、duration、expirationTime，對齊 Renderer 要求。
- 內置 EAM.addDebugLog 日誌探針，支援實時事件生命軌跡追蹤。

資料所有權:
- 擁有 aura states/cache 與 aura alert dirty markers。

可變狀態:
- 可 mutate AuraService.states；不可寫 SavedVariables 或 UI frames。

邊界:
- 僅在 duration 與 expirationTime 確實為非保護安全數字時進行計算。

效能注意:
- UNIT_AURA 是 hot path；使用 numeric loop，完全消滅 pairs。

]]
local _, EAM = ...

local issecretvalue = issecretvalue or function() return false end
local canaccessvalue = canaccessvalue or function() return true end
local canaccesstable = canaccesstable or function() return true end
local api = EAM.API
local Util = EAM.Util
local AuraStatePool
local SpellInfoService = EAM.Services and EAM.Services.SpellInfoService
local ModuleController = EAM.Modules and EAM.Modules.ModuleController

local AuraService = {
    states = {},
    unitCaches = {
        player = { byInstance = {}, spellCounts = {} },
        target = { byInstance = {}, spellCounts = {} },
    },
    alertIndex = {
        player = {},
        target = {},
    },
    indexedRevision = nil,
    scanLimit = 80,
}

EAM.Services.AuraService = AuraService

-- 低 GC 的 AuraState 物件快取池
AuraStatePool = {
    recycleBin = {},
    binSize = 0,
}

AuraService.AuraStatePool = AuraStatePool

function AuraStatePool.initialize()
    -- 預先建立 80 個 AuraState 對象備用
    for i = 1, 80 do
        local state = Util.tableCreate(0, 16)
        state.timer = Util.tableCreate(0, 4)
        state.source = Util.tableCreate(0, 3)
        state.boundaryWarnings = Util.tableCreate(0, 4)
        
        AuraStatePool.recycleBin[i] = state
    end
    AuraStatePool.binSize = 80
end

function AuraStatePool.acquire()
    local state
    if AuraStatePool.binSize > 0 then
        state = AuraStatePool.recycleBin[AuraStatePool.binSize]
        AuraStatePool.recycleBin[AuraStatePool.binSize] = nil
        AuraStatePool.binSize = AuraStatePool.binSize - 1
    else
        -- 溢出時配置新對象
        state = Util.tableCreate(0, 16)
        state.timer = Util.tableCreate(0, 4)
        state.source = Util.tableCreate(0, 3)
        state.boundaryWarnings = Util.tableCreate(0, 4)
    end
    state.releaseFunc = AuraStatePool.release
    return state
end

function AuraStatePool.release(state)
    if not state then return end
    
    -- 清洗狀態，防止殘留資料污染
    state.id = nil
    state.kind = nil
    state.spellID = nil
    state.unit = nil
    state.auraFilter = nil
    state.name = nil
    state.icon = nil
    state.stacks = nil
    state.fromPlayer = nil
    state.auraInstanceID = nil
    state.factsSafe = nil
    state.active = false
    state.shown = false
    state.boundaryLimited = nil
    state.pandemicReady = nil
    state.releaseFunc = nil
    wipe(state.timer)
    wipe(state.source)
    wipe(state.boundaryWarnings)
    
    AuraStatePool.binSize = AuraStatePool.binSize + 1
    AuraStatePool.recycleBin[AuraStatePool.binSize] = state
end

local playerFilters = { "HELPFUL", "HARMFUL" }
local targetFilters = { "HARMFUL", "HELPFUL" }

local function getUnitCache(unit)
    local cache = AuraService.unitCaches[unit]
    if not cache then
        cache = { byInstance = {}, spellCounts = {} }
        AuraService.unitCaches[unit] = cache
    end
    return cache
end

local function clearUnitCache(unit)
    local cache = getUnitCache(unit)
    wipe(cache.byInstance)
    wipe(cache.spellCounts)
end

local function moduleEnabled(unit)
    return not ModuleController or ModuleController.isAuraUnitEnabled(unit)
end

function AuraService.clearUnit(unit, eventName)
    clearUnitCache(unit)
    local router = EAM.Modules.EventRouter
    for alertID, state in pairs(AuraService.states) do
        if state.unit == unit then
            state.shown = false
            AuraService.states[alertID] = nil
            if router then
                local frameName = unit == "target"
                    and EAM.Constants.ALERT_FRAME_TYPES.targetAura
                    or EAM.Constants.ALERT_FRAME_TYPES.selfAura
                router.fire("EAM_AURA_STATE_CHANGED", state, frameName)
            end
        end
    end
end

local function indexAlert(list, unit)
    if type(list) ~= "table" then
        return
    end

    local index = AuraService.alertIndex[unit]
    for _, alert in pairs(list) do
        if alert.enabled ~= false and alert.spellID then
            local spellAlerts = index[alert.spellID]
            if not spellAlerts then
                spellAlerts = {}
                index[alert.spellID] = spellAlerts
            end
            spellAlerts[alert.id] = alert
        end
    end
end

local function ensureAlertIndex()
    local revision = EAM.db and EAM.db.revision or 0
    if AuraService.indexedRevision == revision then
        return
    end

    wipe(AuraService.alertIndex.player)
    wipe(AuraService.alertIndex.target)
    local savedVariables = EAM.Modules and EAM.Modules.SavedVariables
    local alerts = savedVariables and savedVariables.getActiveAlerts and savedVariables.getActiveAlerts() or nil
    if alerts then
        if moduleEnabled("player") then
            indexAlert(alerts.playerAuras, "player")
        end
        if moduleEnabled("target") then
            indexAlert(alerts.targetAuras, "target")
        end
    end
    AuraService.indexedRevision = revision
end

local function getAlertsForSpell(unit, spellID)
    if not spellID or issecretvalue(spellID) or not canaccessvalue(spellID) then
        return nil
    end
    ensureAlertIndex()
    local unitIndex = AuraService.alertIndex[unit]
    return unitIndex and unitIndex[spellID] or nil
end

local function resetState(state, alert)
    state.id = alert.id
    state.kind = alert.kind
    state.spellID = alert.spellID
    state.unit = alert.unit
    local auraFilter = Util.isSafeString(alert.auraFilter) and alert.auraFilter or nil
    if auraFilter ~= "HELPFUL" and auraFilter ~= "HARMFUL" then
        auraFilter = alert.unit == "target" and "HARMFUL" or "HELPFUL"
    end
    state.auraFilter = auraFilter
    state.name = nil
    state.icon = nil
    state.customIcon = alert.customIcon
    state.stacks = nil
    state.fromPlayer = nil
    state.auraInstanceID = nil
    state.factsSafe = true
    state.active = false
    state.shown = false
    state.boundaryLimited = false
    state.boundaryWarnings = state.boundaryWarnings or {}
    wipe(state.boundaryWarnings)
    state.timer = state.timer or {}
    Util.clearTimer(state.timer, EAM.Constants.TIMER_NONE)
    state.source = state.source or {}
    state.source.event = nil
    state.source.api = nil
    state.source.updatedAt = nil
end

local function cacheAura(unit, auraData)
    if not auraData or type(auraData) ~= "table" or not canaccesstable(auraData) then
        return nil, nil, false
    end

    local spellID = auraData.spellId
    local auraInstanceID = auraData.auraInstanceID
    if not spellID or not auraInstanceID or issecretvalue(spellID) or not canaccessvalue(spellID) then
        return spellID, auraInstanceID, false
    end

    local cache = getUnitCache(unit)
    local previous = cache.byInstance[auraInstanceID]
    if previous and previous.spellID and not issecretvalue(previous.spellID) and canaccessvalue(previous.spellID) then
        local previousCount = cache.spellCounts[previous.spellID]
        if previousCount and previousCount > 1 then
            cache.spellCounts[previous.spellID] = previousCount - 1
        else
            cache.spellCounts[previous.spellID] = nil
        end
    end

    local record = previous or {}
    record.spellID = spellID
    record.auraInstanceID = auraInstanceID
    cache.byInstance[auraInstanceID] = record
    
    if not issecretvalue(spellID) and canaccessvalue(spellID) then
        cache.spellCounts[spellID] = (cache.spellCounts[spellID] or 0) + 1
    end
    return spellID, auraInstanceID, true
end

local function removeCachedAura(unit, auraInstanceID)
    local cache = getUnitCache(unit)
    local record = cache.byInstance[auraInstanceID]
    if not record then
        return nil, nil
    end

    cache.byInstance[auraInstanceID] = nil
    local spellID = record.spellID
    if spellID and not issecretvalue(spellID) and canaccessvalue(spellID) then
        local count = cache.spellCounts[spellID]
        if count and count > 1 then
            count = count - 1
            cache.spellCounts[spellID] = count
        else
            cache.spellCounts[spellID] = nil
        end
    end

    return spellID, count
end

local function readAuraIntoState(unit, state, auraData, eventName, apiName)
    if not auraData or type(auraData) ~= "table" or not canaccesstable(auraData) then
        return false
    end

    local spellID = auraData.spellId
    if not spellID or issecretvalue(spellID) or not canaccessvalue(spellID) or spellID ~= state.spellID then
        return false
    end

    local name = auraData.name
    local icon = auraData.icon
    local stacks = auraData.applications
    local duration = auraData.duration
    local expirationTime = auraData.expirationTime
    local fromPlayer = auraData.isFromPlayerOrPlayerPet
    local auraInstanceID = auraData.auraInstanceID
    local isDebuff = auraData.isHarmful or (state.kind == EAM.Constants.ALERT_FRAME_TYPES.targetAura)

    if (not name or not icon) and SpellInfoService then
        local info = SpellInfoService.getSpellInfo(state.spellID)
        if info then
            name = name or info.name
            icon = icon or info.icon
        end
    end

    if state.customIcon and state.customIcon ~= "" then
        icon = tonumber(state.customIcon) or state.customIcon
    end

    state.name = name or tostring(state.spellID)
    state.icon = icon
    state.stacks = stacks
    state.auraInstanceID = auraInstanceID
    state.active = true
    state.shown = true
    state.fromPlayer = (fromPlayer == true) or nil
    state.factsSafe = true

    -- 🌡️ 完美的 DoT Pandemic (傳染累加) 原生預測
    -- 僅在是有害技能(isDebuff) 且有原生預測 API 時執行
    if isDebuff and Util.isSafePositiveNumber(auraInstanceID)
        and api.C_UnitAuras and api.C_UnitAuras.GetRefreshExtendedDuration and api.C_UnitAuras.GetAuraBaseDuration then
        local extendedDur = api.C_UnitAuras.GetRefreshExtendedDuration(unit, auraInstanceID)
        local baseDur = api.C_UnitAuras.GetAuraBaseDuration(unit, auraInstanceID)
        
        if Util.isSafePositiveNumber(extendedDur) and Util.isSafePositiveNumber(baseDur) then
            -- 若當前重鑄預測時間小於基礎時間的 130% 限制，代表正處於最佳的 Pandemic 傳染窗口！
            if extendedDur < (baseDur * 1.305) then
                state.pandemicReady = true
            end
        end
    end

    local isSecret = issecretvalue(duration) or not canaccessvalue(duration) or issecretvalue(expirationTime) or not canaccessvalue(expirationTime)
    
    local hasValidTimer = false

    -- 12.0 優選：DurationObject 只作 display-only，不回讀受限時間 scalar。
    if not hasValidTimer and Util.isSafePositiveNumber(auraInstanceID)
        and api.C_UnitAuras and api.C_UnitAuras.GetAuraDuration then
        local durationObj = api.C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
        if durationObj then
            state.timer.mode = EAM.Constants.TIMER_DISPLAY_ONLY
            state.timer.durationObject = durationObj
            state.timer.startTime = nil
            state.timer.duration = nil
            state.timer.expirationTime = nil
            hasValidTimer = true
        end
    end

    -- 普通非 Secret 時間通道
    if not hasValidTimer and not isSecret
        and Util.isSafePositiveNumber(duration) and Util.isSafeNumber(expirationTime) then
        state.timer.mode = EAM.Constants.TIMER_NUMERIC
        state.timer.startTime = expirationTime - duration
        state.timer.duration = duration
        state.timer.expirationTime = expirationTime
        hasValidTimer = true
    end

    -- 無安全數字或 DurationObject 時，只標示 protected/none，不偽造 expirationTime。
    if not hasValidTimer then
        if isSecret then
            state.factsSafe = false
            state.timer.mode = EAM.Constants.TIMER_PROTECTED
        else
            state.timer.mode = EAM.Constants.TIMER_NONE
        end
    end

    state.source.event = eventName
    state.source.api = apiName or "C_UnitAuras.GetAuraDataByIndex"
    state.source.updatedAt = api.GetTime and api.GetTime() or 0

    return true
end

local function renderInactiveAlert(alert, eventName)
    local state = AuraService.states[alert.id]
    if not state then
        return -- 若未顯示過，直接返回，省去多餘的渲染和回收開銷
    end

    state.shown = false
    AuraService.states[alert.id] = nil

    local router = EAM.Modules.EventRouter
    if router then
        local frameName = alert.unit == "target" and EAM.Constants.ALERT_FRAME_TYPES.targetAura or EAM.Constants.ALERT_FRAME_TYPES.selfAura
        router.fire("EAM_AURA_STATE_CHANGED", state, frameName)
    end
end

local function renderAuraForAlerts(unit, spellID, auraData, eventName, apiName)
    local alerts = getAlertsForSpell(unit, spellID)
    if EAM.addDebugLog then
        EAM.addDebugLog("AuraService", "renderAuraForAlerts", "spellID=" .. tostring(spellID) .. ", matchedAlerts=" .. tostring(alerts ~= nil and "yes" or "no"))
    end
    if type(alerts) ~= "table" then
        return false
    end

    local fired = false
    for _, alert in pairs(alerts) do
        local state = AuraService.states[alert.id]
        if not state then
            state = AuraStatePool.acquire()
            AuraService.states[alert.id] = state
        end

        resetState(state, alert)
        if readAuraIntoState(unit, state, auraData, eventName, apiName) then
            local router = EAM.Modules.EventRouter
            if router then
                local frameName = alert.unit == "target" and EAM.Constants.ALERT_FRAME_TYPES.targetAura or EAM.Constants.ALERT_FRAME_TYPES.selfAura
                router.fire("EAM_AURA_STATE_CHANGED", state, frameName)
                fired = true
            end
        end
    end

    return fired
end

local function renderInactiveUnit(unit, eventName)
    ensureAlertIndex()
    local unitIndex = AuraService.alertIndex[unit]
    if type(unitIndex) ~= "table" then
        return
    end

    for _, alerts in pairs(unitIndex) do
        for _, alert in pairs(alerts) do
            renderInactiveAlert(alert, eventName)
        end
    end
end

local function renderBoundaryUnit(unit, eventName, code)
    ensureAlertIndex()
    local unitIndex = AuraService.alertIndex[unit]
    if type(unitIndex) ~= "table" then
        return
    end

    for _, alerts in pairs(unitIndex) do
        for _, alert in pairs(alerts) do
            local state = AuraService.states[alert.id]
            if not state then
                state = AuraStatePool.acquire()
                AuraService.states[alert.id] = state
            end

            resetState(state, alert)
            Util.markBoundary(state, "aura", code)
            state.timer.mode = EAM.Constants.TIMER_PROTECTED
            state.source.event = eventName
            state.source.api = code
            state.source.updatedAt = api.GetTime and api.GetTime() or 0
            
            local router = EAM.Modules.EventRouter
            if router then
                local frameName = alert.unit == "target" and EAM.Constants.ALERT_FRAME_TYPES.targetAura or EAM.Constants.ALERT_FRAME_TYPES.selfAura
                router.fire("EAM_AURA_STATE_CHANGED", state, frameName)
            end
        end
    end
end

local function processAuraData(unit, auraData, eventName, apiName)
    if not auraData or not canaccesstable(auraData) then
        return false
    end
    local spellID = auraData.spellId
    if not spellID or issecretvalue(spellID) or not canaccessvalue(spellID) then
        return false
    end

    -- 🛡️ 混合型動態過濾：如果在安全狀態下發現不是我們監控的法術
    local alerts = getAlertsForSpell(unit, spellID)
    if type(alerts) ~= "table" then
        -- 垃圾光環！直接調用原生 Block 機制在 C++ 底層過濾它
        local auraInstanceID = auraData.auraInstanceID
        if auraInstanceID and not issecretvalue(auraInstanceID) and api.C_UnitAuras and api.C_UnitAuras.AddBlockedAura then
            api.C_UnitAuras.AddBlockedAura(unit, auraInstanceID)
        end
        return false -- 阻斷後續 Cache 與渲染，0-Lua-CPU 開銷！
    end

    local returnedSpellID = cacheAura(unit, auraData)
    if not returnedSpellID then
        return false
    end

    return renderAuraForAlerts(unit, returnedSpellID, auraData, eventName, apiName)
end

local fullScanMatched = {}

local function fullScanUnit(unit, eventName)
    if EAM.addDebugLog then
        EAM.addDebugLog("AuraService", "fullScanUnit", "unit=" .. tostring(unit) .. ", reason=" .. tostring(eventName))
    end
    ensureAlertIndex()
    wipe(fullScanMatched)
    clearUnitCache(unit)

    if api.UnitExists and not api.UnitExists(unit) then
        renderInactiveUnit(unit, eventName)
        return
    end

    local cUnitAuras = api.C_UnitAuras
    if not cUnitAuras or not cUnitAuras.GetAuraDataByIndex then
        renderBoundaryUnit(unit, eventName, "apiUnavailable")
        return
    end

    -- 直接掃描不設 filter，避免 HELPFUL/HARMFUL 漏抓，效能與精準度最高！
    for index = 1, AuraService.scanLimit do
        local auraData = cUnitAuras.GetAuraDataByIndex(unit, index)
        if not auraData or not canaccesstable(auraData) then
            break
        end

        local spellID = auraData.spellId
        if spellID and not issecretvalue(spellID) and canaccessvalue(spellID) then
            local returnedSpellID = cacheAura(unit, auraData)
            if returnedSpellID and renderAuraForAlerts(unit, returnedSpellID, auraData, eventName, "C_UnitAuras.GetAuraDataByIndex") then
                fullScanMatched[returnedSpellID] = true
            end
        end
    end

    local unitIndex = AuraService.alertIndex[unit]
    if type(unitIndex) ~= "table" then
        return
    end

    for spellID, alerts in pairs(unitIndex) do
        if not fullScanMatched[spellID] then
            for _, alert in pairs(alerts) do
                renderInactiveAlert(alert, eventName)
            end
        end
    end
end

function AuraService.onRegenEnabled()
    if EAM.addDebugLog then
        EAM.addDebugLog("AuraService", "onRegenEnabled", "Player out of combat, clearing native blocked lists and caches.")
    end

    local clearBlocked = api.C_UnitAuras and api.C_UnitAuras.ClearBlockedAuras
    if moduleEnabled("player") then
        if clearBlocked then
            clearBlocked("player")
        end
        clearUnitCache("player")
        AuraService.refreshUnit("player", "PLAYER_REGEN_ENABLED")
    end
    if moduleEnabled("target") then
        if clearBlocked then
            clearBlocked("target")
        end
        clearUnitCache("target")
        AuraService.refreshUnit("target", "PLAYER_REGEN_ENABLED")
    end
end

function AuraService.initialize()
    local capability = EAM.Services.AuraCapabilityService
    if capability and not capability.initialized then
        capability.initialize()
    end
    if capability and not capability.isLegacy() then
        AuraService.backendDisabled = true
        return false, "nativeOrUnsupportedBackend"
    end

    AuraStatePool.initialize()
    if EAM.addDebugLog then
        EAM.addDebugLog("AuraService", "initialize", "AuraService initialized with AuraStatePool.")
    end
    local router = EAM.Modules.EventRouter
    if router then
        router.register("UNIT_AURA", AuraService.onUnitAura)
        router.register("PLAYER_TARGET_CHANGED", AuraService.onTargetChanged)
        router.register("PLAYER_REGEN_ENABLED", AuraService.onRegenEnabled)
    end
end

function AuraService.refreshUnit(unit, eventName)
    if not moduleEnabled(unit) then
        return false, "moduleDisabled"
    end
    local capability = EAM.Services.AuraCapabilityService
    if capability and not capability.isLegacy() then
        return false, "legacyBackendDisabled"
    end
    local savedVariables = EAM.Modules and EAM.Modules.SavedVariables
    if not EAM.db or not savedVariables or not savedVariables.getActiveAlerts() then
        return
    end
    fullScanUnit(unit, eventName or "manual")
end

function AuraService.onUnitAura(_, unit, updateInfo)
    local capability = EAM.Services.AuraCapabilityService
    if capability and not capability.isLegacy() then
        return
    end
    if EAM.addDebugLog then
        EAM.addDebugLog("AuraService", "onUnitAura", "unit=" .. tostring(unit) .. ", hasUpdateInfo=" .. tostring(updateInfo ~= nil))
    end
    if unit ~= "player" and unit ~= "target" then
        return
    end
    if not moduleEnabled(unit) then
        return false, "moduleDisabled"
    end

    local cUnitAuras = api.C_UnitAuras
    if not updateInfo or updateInfo.isFullUpdate or not cUnitAuras then
        clearUnitCache(unit)
        AuraService.refreshUnit(unit, "UNIT_AURA_FULL")
        return
    end

    local removed = updateInfo.removedAuraInstanceIDs
    if type(removed) == "table" then
        for index = 1, #removed do
            local spellID, remaining = removeCachedAura(unit, removed[index])
            if spellID and remaining == 0 then
                local alerts = getAlertsForSpell(unit, spellID)
                if type(alerts) == "table" then
                    for _, alert in pairs(alerts) do
                        renderInactiveAlert(alert, "UNIT_AURA_REMOVED")
                    end
                end
            end
        end
    end

    local added = updateInfo.addedAuras
    if type(added) == "table" then
        for index = 1, #added do
            processAuraData(unit, added[index], "UNIT_AURA_ADDED", "UNIT_AURA.addedAuras")
        end
    end

    local updated = updateInfo.updatedAuraInstanceIDs
    if type(updated) == "table" and cUnitAuras.GetAuraDataByAuraInstanceID then
        for index = 1, #updated do
            local auraData = cUnitAuras.GetAuraDataByAuraInstanceID(unit, updated[index])
            if auraData then
                processAuraData(unit, auraData, "UNIT_AURA_UPDATED", "C_UnitAuras.GetAuraDataByAuraInstanceID")
            end
        end
    end
end

function AuraService.onTargetChanged()
    if not moduleEnabled("target") then
        AuraService.clearUnit("target", "MODULE_DISABLED")
        return false, "moduleDisabled"
    end
    clearUnitCache("target")
    AuraService.refreshUnit("target", "PLAYER_TARGET_CHANGED")
end

function AuraService.onModuleToggle(enabled, unit, reason)
    AuraService.indexedRevision = nil
    if enabled == false then
        AuraService.clearUnit(unit, "MODULE_DISABLED")
        return true, "disabled"
    end
    return AuraService.refreshUnit(unit, "MODULE_ENABLED_" .. tostring(reason or unit))
end
