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
        pet = { byInstance = {}, spellCounts = {} },
    },
    alertIndex = {
        player = {},
        target = {},
        pet = {},
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
    state.isImportant = nil
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

local function resolveAuraFrameName(unit)
    if unit == "target" then
        return EAM.Constants.ALERT_FRAME_TYPES.targetAura
    elseif unit == "pet" then
        return EAM.Constants.ALERT_FRAME_TYPES.petAlert
    else
        return EAM.Constants.ALERT_FRAME_TYPES.selfAura
    end
end

local function moduleEnabled(unit)
    if unit == "pet" then
        return not ModuleController or ModuleController.isEnabled(EAM.Constants.MODULE_KEYS.petAlert)
    end
    return not ModuleController or ModuleController.isAuraUnitEnabled(unit)
end

local function indexAlert(list, unit)
    if type(list) ~= "table" then
        return
    end

    local index = AuraService.alertIndex[unit]
    if not index then
        index = {}
        AuraService.alertIndex[unit] = index
    end
    for key, alert in pairs(list) do
        if type(alert) == "table" and alert.enabled ~= false and alert.spellID then
            local spellID = tonumber(alert.spellID) or alert.spellID
            local alertID = alert.id or (type(key) == "string" and key) or ("aura:" .. unit .. ":" .. tostring(spellID))
            alert.id = alertID
            alert.unit = alert.unit or unit
            local spellAlerts = index[spellID]
            if not spellAlerts then
                spellAlerts = {}
                index[spellID] = spellAlerts
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
    if not AuraService.alertIndex.pet then
        AuraService.alertIndex.pet = {}
    else
        wipe(AuraService.alertIndex.pet)
    end
    local savedVariables = EAM.Modules and EAM.Modules.SavedVariables
    local alerts = savedVariables and savedVariables.getActiveAlerts and savedVariables.getActiveAlerts() or nil
    if alerts then
        if moduleEnabled("player") then
            indexAlert(alerts.playerAuras, "player")
        end
        if moduleEnabled("pet") then
            indexAlert(alerts.playerAuras, "pet")
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
    state.customName = alert.customName
    state.rawAlert = alert
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
    record.fromPlayer = auraData.isFromPlayerOrPlayerPet == true
    record.isHarmful = auraData.isHarmful == true
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
        return nil, nil, nil, nil
    end

    cache.byInstance[auraInstanceID] = nil
    local spellID = record.spellID
    local fromPlayer = record.fromPlayer
    local isHarmful = record.isHarmful
    local count = nil
    if spellID and not issecretvalue(spellID) and canaccessvalue(spellID) then
        count = cache.spellCounts[spellID]
        if count and count > 1 then
            count = count - 1
            cache.spellCounts[spellID] = count
        else
            cache.spellCounts[spellID] = nil
            count = 0
        end
    end

    return spellID, count, fromPlayer, isHarmful
end

local function hasPlayerAuraInstance(unit, spellID, isHarmful)
    local cache = getUnitCache(unit)
    for _, record in pairs(cache.byInstance) do
        if record.spellID == spellID and record.fromPlayer then
            if isHarmful == nil or record.isHarmful == isHarmful then
                return true
            end
        end
    end
    return false
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
    local isDebuff = (auraData.isHarmful == true) or (auraData.isHarmful == nil and state.auraFilter == "HARMFUL")

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

    state.name = (state.customName and state.customName ~= "" and state.customName) or name or tostring(state.spellID)
    state.icon = icon
    state.stacks = stacks
    state.auraInstanceID = auraInstanceID
    state.active = true
    state.shown = true
    state.fromPlayer = (fromPlayer == true) or nil
    state.factsSafe = true
    state.pandemicReady = nil
    state.isImportant = nil
    state.absorbAmount = nil

    -- 🛡️ 護盾與傷害吸收量提取 (Aura Absorb / Shield Point Extraction)
    local absorbAmount = nil
    if type(auraData.points) == "table" and canaccesstable(auraData.points) then
        for i = 1, #auraData.points do
            local pt = auraData.points[i]
            if pt and canaccessvalue(pt) then
                if not issecretvalue(pt) and type(pt) == "number" and pt > 0 then
                    absorbAmount = pt
                    break
                elseif issecretvalue(pt) then
                    absorbAmount = pt
                    break
                end
            end
        end
    end
    state.absorbAmount = absorbAmount

    -- 🌟 重要光環與首領機制高亮 (Important / Boss / Priority / Stealable)
    if auraData.isBossAura or auraData.isPriorityAura or auraData.isStealable then
        state.isImportant = true
    elseif api.C_Spell and api.C_Spell.IsSpellImportant and Util.isSafePositiveNumber(state.spellID) then
        local ok, isImp = pcall(api.C_Spell.IsSpellImportant, state.spellID)
        if ok and isImp == true then
            state.isImportant = true
        end
    end

    -- 🌡️ 完美的 DoT Pandemic (傳染累加) 原生預測
    -- 支援 12.1.5 GetRefreshCarryOverDuration 精確結餘窗口與 12.1 GetRefreshExtendedDuration
    if Util.isSafePositiveNumber(auraInstanceID) and api.C_UnitAuras then
        local baseDur = api.C_UnitAuras.GetAuraBaseDuration and api.C_UnitAuras.GetAuraBaseDuration(unit, auraInstanceID)
        local carryOverDur = api.C_UnitAuras.GetRefreshCarryOverDuration and api.C_UnitAuras.GetRefreshCarryOverDuration(unit, auraInstanceID)
        local extendedDur = api.C_UnitAuras.GetRefreshExtendedDuration and api.C_UnitAuras.GetRefreshExtendedDuration(unit, auraInstanceID)

        if Util.isSafeNonNegativeNumber(carryOverDur) and Util.isSafePositiveNumber(baseDur) then
            -- 12.1.5 精確結餘：結餘時長小於等於法術最大結餘上限（標準為基礎時間的 30%），處於無浪費的完美傳染窗口
            if carryOverDur <= (baseDur * 0.305) then
                state.pandemicReady = true
            end
        elseif Util.isSafePositiveNumber(extendedDur) and Util.isSafePositiveNumber(baseDur) then
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

    state.timer = state.timer or {}
    state.source = state.source or {}
    state.source.event = eventName
    state.source.api = apiName or "C_UnitAuras.GetAuraDataByIndex"
    state.source.updatedAt = api.GetTime and api.GetTime() or 0

    return true
end

local function renderInactiveAlert(alert, eventName)
    local state = AuraService.states[alert.id]
    local frameName = resolveAuraFrameName(alert.unit or "target")
    if not state then
        local router = EAM.Modules.EventRouter
        if router then
            router.fire("EAM_AURA_STATE_CHANGED", { id = alert.id, unit = alert.unit or "target", active = false, shown = false }, frameName)
        end
        return
    end

    state.active = false
    state.shown = false
    AuraService.states[alert.id] = nil

    local router = EAM.Modules.EventRouter
    if router then
        router.fire("EAM_AURA_STATE_CHANGED", state, frameName)
    end
end

function AuraService.clearUnit(unit, eventName)
    clearUnitCache(unit)
    if unit == "target" then
        local Renderer = EAM.UI and EAM.UI.Renderer
        if Renderer and Renderer.clearFrame then
            Renderer.clearFrame(EAM.Constants.ALERT_FRAME_TYPES.targetAura)
        end
        local AlertManager = EAM.Managers and EAM.Managers.AlertManager
        if AlertManager and AlertManager.clearPending then
            AlertManager.clearPending(EAM.Constants.ALERT_FRAME_TYPES.targetAura)
        end
    end
    ensureAlertIndex()
    local unitIndex = AuraService.alertIndex[unit]
    if type(unitIndex) == "table" then
        for _, alerts in pairs(unitIndex) do
            for _, alert in pairs(alerts) do
                renderInactiveAlert(alert, eventName)
            end
        end
    end
    local router = EAM.Modules.EventRouter
    for alertID, state in pairs(AuraService.states) do
        if state.unit == unit or (unit == "pet" and state.unit == "pet") or string.find(tostring(alertID), "^aura:" .. unit .. ":") then
            state.active = false
            state.shown = false
            AuraService.states[alertID] = nil
            if router then
                local frameName = resolveAuraFrameName(unit)
                router.fire("EAM_AURA_STATE_CHANGED", state, frameName)
            end
        end
    end
end

local function alertMatchesAura(alert, auraData)
    local expectedFilter = alert.auraFilter
    if expectedFilter ~= "HELPFUL" and expectedFilter ~= "HARMFUL" then
        expectedFilter = (alert.unit == "target") and "HARMFUL" or "HELPFUL"
    end
    if expectedFilter == "HARMFUL" then
        if auraData.isHarmful ~= true then
            return false
        end
    elseif expectedFilter == "HELPFUL" then
        if auraData.isHarmful == true or (auraData.isHelpful ~= nil and auraData.isHelpful ~= true) then
            return false
        end
    end

    if alert.fromPlayer == true or alert.self == true then
        if auraData.isFromPlayerOrPlayerPet ~= true then
            return false
        end
    end

    return true
end

local function renderAuraForAlerts(unit, spellID, auraData, eventName, apiName, matchedAlerts)
    local alerts = getAlertsForSpell(unit, spellID)
    if EAM.addDebugLog then
        EAM.addDebugLog("AuraService", "renderAuraForAlerts", "spellID=" .. tostring(spellID) .. ", matchedAlerts=" .. tostring(alerts ~= nil and "yes" or "no"))
    end
    if type(alerts) ~= "table" then
        return false
    end

    local fired = false
    for _, alert in pairs(alerts) do
        if alertMatchesAura(alert, auraData) then
            local state = AuraService.states[alert.id]
            if not state then
                state = AuraStatePool.acquire()
                AuraService.states[alert.id] = state
            end

            resetState(state, alert)
            if readAuraIntoState(unit, state, auraData, eventName, apiName) then
                local router = EAM.Modules.EventRouter
                if router then
                    local frameName = resolveAuraFrameName(alert.unit)
                    router.fire("EAM_AURA_STATE_CHANGED", state, frameName)
                    fired = true
                end
                if matchedAlerts then
                    matchedAlerts[alert.id] = true
                end
            end
        end
    end

    return fired
end

local function renderInactiveUnit(unit, eventName)
    if unit == "target" then
        local Renderer = EAM.UI and EAM.UI.Renderer
        if Renderer and Renderer.clearFrame then
            Renderer.clearFrame(EAM.Constants.ALERT_FRAME_TYPES.targetAura)
        end
        local AlertManager = EAM.Managers and EAM.Managers.AlertManager
        if AlertManager and AlertManager.clearPending then
            AlertManager.clearPending(EAM.Constants.ALERT_FRAME_TYPES.targetAura)
        end
    end
    ensureAlertIndex()
    local unitIndex = AuraService.alertIndex[unit]
    if type(unitIndex) == "table" then
        for _, alerts in pairs(unitIndex) do
            for _, alert in pairs(alerts) do
                renderInactiveAlert(alert, eventName)
            end
        end
    end

    local router = EAM.Modules.EventRouter
    for alertID, state in pairs(AuraService.states) do
        if state.unit == unit or (unit == "pet" and state.unit == "pet") or string.find(tostring(alertID), "^aura:" .. unit .. ":") then
            state.active = false
            state.shown = false
            AuraService.states[alertID] = nil
            if router then
                local frameName = resolveAuraFrameName(unit)
                router.fire("EAM_AURA_STATE_CHANGED", state, frameName)
            end
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

    local filters = (unit == "target") and targetFilters or playerFilters
    for fIndex = 1, #filters do
        local filter = filters[fIndex]
        for index = 1, AuraService.scanLimit do
            local auraData = cUnitAuras.GetAuraDataByIndex(unit, index, filter)
            if not auraData or not canaccesstable(auraData) then
                break
            end

            local spellID = auraData.spellId
            if spellID and not issecretvalue(spellID) and canaccessvalue(spellID) then
                local alerts = getAlertsForSpell(unit, spellID)
                if alerts then
                    local returnedSpellID = cacheAura(unit, auraData)
                    if returnedSpellID then
                        renderAuraForAlerts(unit, returnedSpellID, auraData, eventName, "C_UnitAuras.GetAuraDataByIndex", fullScanMatched)
                    end
                end
            end
        end
    end

    local unitIndex = AuraService.alertIndex[unit]
    if type(unitIndex) == "table" then
        for _, alerts in pairs(unitIndex) do
            for _, alert in pairs(alerts) do
                if not fullScanMatched[alert.id] then
                    renderInactiveAlert(alert, eventName)
                end
            end
        end
    end

    local router = EAM.Modules.EventRouter
    for alertID, state in pairs(AuraService.states) do
        if (state.unit == unit or (unit == "pet" and state.unit == "pet") or string.find(tostring(alertID), "^aura:" .. unit .. ":")) and not fullScanMatched[alertID] then
            state.active = false
            state.shown = false
            AuraService.states[alertID] = nil
            if router then
                local frameName = resolveAuraFrameName(unit)
                router.fire("EAM_AURA_STATE_CHANGED", state, frameName)
            end
        end
    end
end

function AuraService.onRegenEnabled()
    local capability = EAM.Services.AuraCapabilityService
    if AuraService.backendDisabled or (capability and not capability.isLegacy()) then
        return
    end

    if EAM.addDebugLog then
        EAM.addDebugLog("AuraService", "onRegenEnabled", "Player out of combat, clearing native blocked lists and caches.")
    end

    local clearBlocked = api.C_UnitAuras and api.C_UnitAuras.ClearBlockedAuras
    if moduleEnabled("player") then
        if clearBlocked then
            clearBlocked("player")
            clearBlocked("pet")
        end
        clearUnitCache("player")
        clearUnitCache("pet")
        AuraService.refreshUnit("player", "PLAYER_REGEN_ENABLED")
        AuraService.refreshUnit("pet", "PLAYER_REGEN_ENABLED")
    end
    if moduleEnabled("target") then
        if clearBlocked then
            clearBlocked("target")
        end
        clearUnitCache("target")
        AuraService.refreshUnit("target", "PLAYER_REGEN_ENABLED")
    end
end

function AuraService.onUnitPet(eventName, unit)
    if unit == "player" then
        clearUnitCache("pet")
        AuraService.refreshUnit("pet", "UNIT_PET")
    end
end

local legacyEventsRegistered = false

local function registerLegacyEvents()
    if legacyEventsRegistered then
        return
    end
    local router = EAM.Modules.EventRouter
    if not router then
        return
    end
    router.register("UNIT_AURA", AuraService.onUnitAura)
    router.register("PLAYER_TARGET_CHANGED", AuraService.onTargetChanged)
    router.register("PLAYER_REGEN_ENABLED", AuraService.onRegenEnabled)
    router.register("UNIT_PET", AuraService.onUnitPet)
    legacyEventsRegistered = true
end

local function unregisterLegacyEvents()
    if not legacyEventsRegistered then
        return
    end
    local router = EAM.Modules.EventRouter
    if not router then
        return
    end
    router.unregister("UNIT_AURA", AuraService.onUnitAura)
    router.unregister("PLAYER_TARGET_CHANGED", AuraService.onTargetChanged)
    router.unregister("PLAYER_REGEN_ENABLED", AuraService.onRegenEnabled)
    router.unregister("UNIT_PET", AuraService.onUnitPet)
    legacyEventsRegistered = false
end

function AuraService.onBackendSwitched(backend)
    local isLegacy = backend == EAM.Constants.AURA_BACKEND_LEGACY
    if not isLegacy then
        AuraService.backendDisabled = true
        unregisterLegacyEvents()
        AuraService.clearUnit("player", "BACKEND_SWITCH")
        AuraService.clearUnit("target", "BACKEND_SWITCH")
        AuraService.clearUnit("pet", "BACKEND_SWITCH")
    else
        AuraService.backendDisabled = false
        registerLegacyEvents()
        if moduleEnabled("player") then
            AuraService.refreshUnit("player", "BACKEND_SWITCH")
        end
        if moduleEnabled("target") then
            AuraService.refreshUnit("target", "BACKEND_SWITCH")
        end
    end
end

function AuraService.initialize()
    local capability = EAM.Services.AuraCapabilityService
    if capability and not capability.initialized then
        capability.initialize()
    end

    local router = EAM.Modules.EventRouter
    if router then
        router.register("EAM_AURA_BACKEND_SWITCHED", function(_, backend)
            AuraService.onBackendSwitched(backend)
        end)
    end

    AuraStatePool.initialize()

    if capability and not capability.isLegacy() then
        AuraService.backendDisabled = true
        unregisterLegacyEvents()
        return false, "nativeOrUnsupportedBackend"
    end

    AuraService.backendDisabled = false
    registerLegacyEvents()

    if EAM.addDebugLog then
        EAM.addDebugLog("AuraService", "initialize", "AuraService initialized with AuraStatePool.")
    end
end

local unitRefreshKeyCache = {
    player = "AuraService.refreshUnit:player",
    target = "AuraService.refreshUnit:target",
    pet = "AuraService.refreshUnit:pet",
}

function AuraService.refreshUnit(unit, eventName)
    if EAM.recordHotPath then
        EAM.recordHotPath(unitRefreshKeyCache[unit] or "AuraService.refreshUnit:other")
    end
    if not moduleEnabled(unit) then
        return false, "moduleDisabled"
    end
    local capability = EAM.Services.AuraCapabilityService
    if AuraService.backendDisabled or (capability and not capability.isLegacy()) then
        return false, "legacyBackendDisabled"
    end
    local savedVariables = EAM.Modules and EAM.Modules.SavedVariables
    if not EAM.db or not savedVariables or not savedVariables.getActiveAlerts() then
        return
    end
    fullScanUnit(unit, eventName or "manual")
end

function AuraService.refreshAll(eventName)
    if moduleEnabled("player") then
        AuraService.refreshUnit("player", eventName or "refreshAll")
    end
    if moduleEnabled("target") then
        AuraService.refreshUnit("target", eventName or "refreshAll")
    end
    if moduleEnabled("pet") then
        AuraService.refreshUnit("pet", eventName or "refreshAll")
    end
end

local unitAuraKeyCache = {
    player = "AuraService.onUnitAura:player",
    target = "AuraService.onUnitAura:target",
    pet = "AuraService.onUnitAura:pet",
}

function AuraService.onUnitAura(_, unit, updateInfo)
    if EAM.recordHotPath then
        EAM.recordHotPath(unitAuraKeyCache[unit] or "AuraService.onUnitAura:other")
    end
    local capability = EAM.Services.AuraCapabilityService
    if capability and not capability.isLegacy() then
        return
    end
    if EAM.addDebugLog then
        EAM.addDebugLog("AuraService", "onUnitAura", "unit=" .. tostring(unit) .. ", hasUpdateInfo=" .. tostring(updateInfo ~= nil))
    end
    if unit ~= "player" and unit ~= "target" and unit ~= "pet" then
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
            local spellID, remaining, wasFromPlayer, wasHarmful = removeCachedAura(unit, removed[index])
            if spellID then
                local alerts = getAlertsForSpell(unit, spellID)
                if type(alerts) == "table" then
                    for _, alert in pairs(alerts) do
                        local alertExpectedHarmful = (alert.auraFilter == "HARMFUL") or (alert.auraFilter ~= "HELPFUL" and alert.unit == "target")
                        local filterMatches = (wasHarmful == nil) or (alertExpectedHarmful == wasHarmful)
                        if filterMatches then
                            if remaining == 0 then
                                renderInactiveAlert(alert, "UNIT_AURA_REMOVED")
                            elseif alert.fromPlayer == true or alert.self == true then
                                if wasFromPlayer and not hasPlayerAuraInstance(unit, spellID, wasHarmful) then
                                    renderInactiveAlert(alert, "UNIT_AURA_REMOVED")
                                end
                            end
                        end
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
    if EAM.recordHotPath then
        EAM.recordHotPath("AuraService.onTargetChanged")
    end
    local capability = EAM.Services.AuraCapabilityService
    if AuraService.backendDisabled or (capability and not capability.isLegacy()) then
        return
    end

    -- 🛡️ 立即同步徹底清理當前畫面上的所有目標光環圖示與倒數綁定 (杜絕切換目標後的舊圖示與倒數鬼影殘留)
    local Renderer = EAM.UI and EAM.UI.Renderer
    if Renderer and Renderer.clearFrame then
        Renderer.clearFrame(EAM.Constants.ALERT_FRAME_TYPES.targetAura)
    end
    local AlertManager = EAM.Managers and EAM.Managers.AlertManager
    if AlertManager and AlertManager.clearPending then
        AlertManager.clearPending(EAM.Constants.ALERT_FRAME_TYPES.targetAura)
    end

    if not moduleEnabled("target") then
        AuraService.clearUnit("target", "MODULE_DISABLED")
        return false, "moduleDisabled"
    end
    AuraService.clearUnit("target", "PLAYER_TARGET_CHANGED")
    if api.UnitExists and api.UnitExists("target") then
        AuraService.refreshUnit("target", "PLAYER_TARGET_CHANGED")
    end
end

function AuraService.onModuleToggle(enabled, unit, reason)
    AuraService.indexedRevision = nil
    local capability = EAM.Services.AuraCapabilityService
    if AuraService.backendDisabled or (capability and not capability.isLegacy()) then
        return false, "legacyBackendDisabled"
    end
    if enabled == false then
        AuraService.clearUnit(unit, "MODULE_DISABLED")
        return true, "disabled"
    end
    return AuraService.refreshUnit(unit, "MODULE_ENABLED_" .. tostring(reason or unit))
end

AuraService.readAuraIntoState = readAuraIntoState

function AuraService.updateStateFromAuraData(state, auraData, unit, eventName, apiName)
    return readAuraIntoState(unit or "target", state, auraData, eventName or "UPDATE", apiName or "updateStateFromAuraData")
end
