--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/CooldownService
檔案: Services\CooldownService.lua

理念:
- 集中 spell cooldown facts，避免 UI 或 slash command 直接查 C_Spell。
- 以 event-driven 為主，scheduler fallback 為輔。

責任:
- 管理 spell cooldown cache、normalized CooldownState、dirty alert markers。

資料所有權:
- 擁有 spell cooldown states。

可變狀態:
- 可 mutate CooldownService.states；不可寫 SavedVariables 或 UI frames。

邊界:
- 不得假造 start/duration/timeLeft。
- 不使用舊 Classic unpack API 作為核心路徑。

效能注意:
- SPELL_UPDATE_COOLDOWN 可能頻繁；避免每 frame 查全表。
- 透過 SavedVariables revision 響應式維護 alertList 陣列，熱路徑完全零 pairs/ipairs 迭代，零 GC table 分配。
- 使用 table.create 預分配狀態表與警告陣列容量，防止 rehashing。
- Service-Layer Write Gating: 僅當冷卻時間數值改變時才更新/獲取新 DurationObject，防範高頻 Event 導致重複解綁與綁定。

Retail API 注意:
- 優先 C_Spell structured/DurationObject API；charges 與 cooldown 欄位皆實做完整 secrecy 與 boundary 檢查。

]]
local _, EAM = ...

local api = EAM.API
local Util = EAM.Util
local CooldownStatePool
local SpellInfoService = EAM.Services and EAM.Services.SpellInfoService
local ModuleController = EAM.Modules and EAM.Modules.ModuleController
local DurationAdapter = EAM.Modules and EAM.Modules.DurationAdapter
local MIN_REAL_COOLDOWN_SECONDS = 1.5

local CooldownService = {
    states = {},
    -- 只有玩家 UNIT_SPELLCAST_SUCCEEDED 精確命中已啟用警示時才開啟。
    activatedAlerts = {},
    -- 保存本輪實際施放 ID，避免 base/override 家族在後續充能事件查錯成員。
    activationSpellIDs = {},
    -- 保存激活事件名稱（如 UNIT_SPELLCAST_CHANNEL_START 或 UNIT_SPELLCAST_SUCCEEDED），防範背景刷新覆寫。
    activationEvents = {},
    -- 完成移除前，必須先安全觀察到本輪至少消耗一層充能。
    chargeSpentObserved = {},
    -- 英雄天賦與法術覆蓋雙向對齊映射表
    baseToOverrideMap = {},
    overrideToBaseMap = {},
    -- 前次覆蓋技能記錄（補償法術在覆蓋移除前即進入冷卻之邊界狀態）
    previousOverrideMap = {},
    previousOverrideToBaseMap = {},
}

EAM.Services.CooldownService = CooldownService

local function moduleEnabled()
    return not ModuleController
        or ModuleController.isEnabled(EAM.Constants.MODULE_KEYS.spellCooldown)
end

local function getDurationObject(callback, spellID, ignoreGCD)
    if type(callback) ~= "function" then
        return nil
    end
    local ok, durationObject = pcall(callback, spellID, ignoreGCD)
    if ok then
        return durationObject
    end
    return nil
end

-- SpellChargeInfo 在 12.1 可同時包含安全與 Secret 欄位；此 reader 只放行可索引表，
-- 再逐欄套用 scalar 檢查，不使用 hasanysecretvalues 否決整張 structured table。
local function readChargeField(source, key, warnings, warningCode)
    if type(source) ~= "table"
        or Util.isSecretValue(source)
        or Util.isSecretTable(source)
        or not Util.canAccessTable(source)
    then
        Util.appendBoundaryWarning(warnings, warningCode or "chargeTableRestricted", "table")
        return nil, false
    end
    if not Util.isSafeTableKey(key) then
        Util.appendBoundaryWarning(warnings, warningCode or "chargeFieldRestricted", "key")
        return nil, false
    end
    return Util.readSafeScalar(source[key], warnings, warningCode or "chargeFieldProtected", key)
end

local function resolveSpellIdentifier(callback, spellID)
    if type(callback) ~= "function" or not Util.isSafePositiveNumber(spellID) then
        return nil
    end
    local resolvedSpellID = callback(spellID)
    if Util.isSafePositiveNumber(resolvedSpellID) then
        return resolvedSpellID
    end
    return nil
end

local function resolveSpellFamily(spellID)
    if not Util.isSafePositiveNumber(spellID) then
        return nil, nil, nil
    end

    local cSpell = api.C_Spell
    local baseSpellID = cSpell
        and resolveSpellIdentifier(cSpell.GetBaseSpell, spellID)
        or nil
    if not Util.isSafePositiveNumber(baseSpellID) then
        baseSpellID = CooldownService.overrideToBaseMap[spellID]
            or CooldownService.previousOverrideToBaseMap[spellID]
            or spellID
    end

    if not cSpell then
        local cachedOverride = CooldownService.baseToOverrideMap[spellID] or CooldownService.baseToOverrideMap[baseSpellID]
        local cachedPrev = CooldownService.previousOverrideMap[baseSpellID] or CooldownService.previousOverrideMap[spellID]
        return baseSpellID, cachedOverride or baseSpellID, cachedPrev
    end

    local overrideSpellID = resolveSpellIdentifier(cSpell.GetOverrideSpell, baseSpellID)
    if not overrideSpellID and baseSpellID ~= spellID then
        overrideSpellID = resolveSpellIdentifier(cSpell.GetOverrideSpell, spellID)
    end
    overrideSpellID = overrideSpellID or baseSpellID

    -- 動態同步覆蓋狀態；當覆蓋已解除或過期（overrideSpellID == baseSpellID）時即時清除快取
    if baseSpellID then
        local existingOverride = CooldownService.baseToOverrideMap[baseSpellID]
        if Util.isSafePositiveNumber(overrideSpellID) and overrideSpellID ~= baseSpellID then
            if existingOverride and existingOverride ~= overrideSpellID then
                CooldownService.previousOverrideMap[baseSpellID] = existingOverride
                CooldownService.previousOverrideToBaseMap[existingOverride] = baseSpellID
                CooldownService.overrideToBaseMap[existingOverride] = nil
            end
            CooldownService.baseToOverrideMap[baseSpellID] = overrideSpellID
            CooldownService.overrideToBaseMap[overrideSpellID] = baseSpellID
        else
            -- 覆蓋已解除或重置，將舊覆蓋捕獲至 previousOverrideMap 以補償殘存事件，並清除活躍覆蓋快取
            if existingOverride and existingOverride ~= baseSpellID then
                CooldownService.previousOverrideMap[baseSpellID] = existingOverride
                CooldownService.previousOverrideToBaseMap[existingOverride] = baseSpellID
                CooldownService.overrideToBaseMap[existingOverride] = nil
                CooldownService.baseToOverrideMap[baseSpellID] = nil
            end
        end
    end

    local finalPrev = CooldownService.previousOverrideMap[baseSpellID]
    return baseSpellID, overrideSpellID, finalPrev
end

local function readChargeCandidate(cSpell, spellID)
    if not Util.isSafePositiveNumber(spellID) then
        return nil, nil
    end
    local ok, chargesInfo = pcall(cSpell.GetSpellCharges, spellID)
    if not ok or type(chargesInfo) ~= "table" then
        return nil, nil
    end
    local maximumCharges, maximumSafe = readChargeField(
        chargesInfo,
        "maxCharges",
        nil,
        "chargeCandidateMax"
    )
    if maximumSafe and Util.isSafePositiveNumber(maximumCharges) and maximumCharges > 1 then
        return chargesInfo, spellID
    end
    return nil, nil
end

local function getSpellChargesInfo(cSpell, spellID, preferredSpellID)
    if not cSpell or type(cSpell.GetSpellCharges) ~= "function"
        or not Util.isSafePositiveNumber(spellID)
    then
        return nil, nil
    end

    local chargesInfo, selectedSpellID = readChargeCandidate(cSpell, preferredSpellID)
    if chargesInfo then
        return chargesInfo, selectedSpellID
    end

    local baseSpellID, overrideSpellID, previousOverrideSpellID = resolveSpellFamily(spellID)
    if overrideSpellID ~= preferredSpellID then
        chargesInfo, selectedSpellID = readChargeCandidate(cSpell, overrideSpellID)
        if chargesInfo then
            return chargesInfo, selectedSpellID
        end
    end
    if Util.isSafePositiveNumber(previousOverrideSpellID)
        and previousOverrideSpellID ~= preferredSpellID
        and previousOverrideSpellID ~= overrideSpellID
    then
        chargesInfo, selectedSpellID = readChargeCandidate(cSpell, previousOverrideSpellID)
        if chargesInfo then
            return chargesInfo, selectedSpellID
        end
    end
    if baseSpellID ~= preferredSpellID and baseSpellID ~= overrideSpellID and baseSpellID ~= previousOverrideSpellID then
        chargesInfo, selectedSpellID = readChargeCandidate(cSpell, baseSpellID)
        if chargesInfo then
            return chargesInfo, selectedSpellID
        end
    end
    if spellID ~= preferredSpellID and spellID ~= overrideSpellID and spellID ~= previousOverrideSpellID and spellID ~= baseSpellID then
        chargesInfo, selectedSpellID = readChargeCandidate(cSpell, spellID)
        if chargesInfo then
            return chargesInfo, selectedSpellID
        end
    end
    return nil, nil
end

local function readCooldownCandidate(cSpell, spellID)
    if not Util.isSafePositiveNumber(spellID) or type(cSpell.GetSpellCooldown) ~= "function" then
        return nil, nil
    end
    local ok, cooldownInfo = pcall(cSpell.GetSpellCooldown, spellID)
    if not ok or type(cooldownInfo) ~= "table" then
        return nil, nil
    end
    return cooldownInfo, spellID
end

local function getSpellCooldownInfo(cSpell, spellID, preferredSpellID)
    if not cSpell or type(cSpell.GetSpellCooldown) ~= "function"
        or not Util.isSafePositiveNumber(spellID)
    then
        return nil, nil
    end

    local candidates = {}
    if Util.isSafePositiveNumber(preferredSpellID) then
        candidates[#candidates + 1] = preferredSpellID
    end
    local baseSpellID, overrideSpellID, previousOverrideSpellID = resolveSpellFamily(spellID)
    if Util.isSafePositiveNumber(overrideSpellID) and overrideSpellID ~= preferredSpellID then
        candidates[#candidates + 1] = overrideSpellID
    end
    if Util.isSafePositiveNumber(previousOverrideSpellID)
        and previousOverrideSpellID ~= preferredSpellID
        and previousOverrideSpellID ~= overrideSpellID
    then
        candidates[#candidates + 1] = previousOverrideSpellID
    end
    if Util.isSafePositiveNumber(baseSpellID)
        and baseSpellID ~= preferredSpellID
        and baseSpellID ~= overrideSpellID
        and baseSpellID ~= previousOverrideSpellID
    then
        candidates[#candidates + 1] = baseSpellID
    end
    if spellID ~= preferredSpellID
        and spellID ~= overrideSpellID
        and spellID ~= previousOverrideSpellID
        and spellID ~= baseSpellID
    then
        candidates[#candidates + 1] = spellID
    end

    -- First pass: find candidate with an active non-GCD cooldown
    for i = 1, #candidates do
        local candID = candidates[i]
        local info, resolvedID = readCooldownCandidate(cSpell, candID)
        if info and Util.canAccessTable(info) then
            local dur, durSafe = Util.readSafeField(info, "duration", nil, "cooldown")
            local gcd, gcdSafe = Util.readSafeField(info, "isOnGCD", nil, "cooldown")
            if durSafe and type(dur) == "number" and dur > 0 and (not gcdSafe or gcd ~= true) then
                return info, resolvedID
            end
        end
    end

    -- Second pass: fallback to first valid candidate (preferred, override, previousOverride, base, or original)
    for i = 1, #candidates do
        local candID = candidates[i]
        local info, resolvedID = readCooldownCandidate(cSpell, candID)
        if info then
            return info, resolvedID
        end
    end

    return nil, nil
end

local function getObjectMethod(object, name)
    if not object then
        return nil
    end
    local ok, method = pcall(function()
        return object[name]
    end)
    if ok and type(method) == "function" then
        return method
    end
    return nil
end

-- currentCharges 在 12.1 可為 Secret；此函式只把原值送進 Blizzard C 層 StatusBar，
-- 不回傳、不保存、不比較該值。IconPool 必須先完成所有錨點與樣式設定。
function CooldownService.applyChargeStatusBar(spellID, statusBar, preferredSpellID)
    if not Util.isSafePositiveNumber(spellID) or not statusBar then
        return false, "invalidArguments"
    end

    local chargesInfo = getSpellChargesInfo(api.C_Spell, spellID, preferredSpellID)
    if type(chargesInfo) ~= "table"
        or Util.isSecretValue(chargesInfo)
        or Util.isSecretTable(chargesInfo)
        or not Util.canAccessTable(chargesInfo)
    then
        return false, "chargeTableRestricted"
    end

    local maximumCharges, maximumSafe = readChargeField(
        chargesInfo,
        "maxCharges",
        nil,
        "chargeSinkMax"
    )
    if not maximumSafe or not Util.isSafePositiveNumber(maximumCharges) then
        return false, "maximumUnavailable"
    end

    local currentOK, currentCharges = pcall(function()
        return chargesInfo.currentCharges
    end)
    if not currentOK then
        return false, "currentUnavailable"
    end
    local currentSecret = Util.isSecretValue(currentCharges)
    local currentSafe = not currentSecret
        and Util.canAccessValue(currentCharges)
        and Util.isSafeNonNegativeNumber(currentCharges)
    if not currentSecret and not currentSafe then
        return false, "currentUnavailable"
    end

    local setMinMaxValues = getObjectMethod(statusBar, "SetMinMaxValues")
    local setValue = getObjectMethod(statusBar, "SetValue")
    if not setMinMaxValues or not setValue then
        return false, "statusBarSinkUnavailable"
    end
    if not pcall(setMinMaxValues, statusBar, 0, maximumCharges) then
        return false, "rangeRejected"
    end

    -- 必須是最後一個 statusBar 呼叫：Secret BarValue 可能使後續讀取或錨點帶密。
    local accepted = pcall(setValue, statusBar, currentCharges)
    if not accepted then
        return false, "valueRejected"
    end
    return true, currentSecret and "secretCount" or "safeCount", maximumCharges
end

local function sameSpellID(left, right)
    return Util.isSafePositiveNumber(left)
        and Util.isSafePositiveNumber(right)
        and left == right
end

local COOLDOWN_BEHAVIOR_DEFAULTS = {
    cooldownRemoveAura = false,
    showSCDOutsideCombat = true,
    glowSCDWhenUsable = true,
    cooldownPreRender = true,
}

local function isInCombat()
    return type(api.InCombatLockdown) == "function"
        and api.InCombatLockdown() == true
end

local function resolveBehavior(alert, key)
    if key == "cooldownPreRender" then
        if type(alert) == "table" and type(alert.cooldownPreRender) == "boolean" then
            return alert.cooldownPreRender
        end
        if resolveBehavior(alert, "cooldownRemoveAura") == true then
            return false
        end
        local config = EAM.db and EAM.db.config
        local globalValue = nil
        if type(config) == "table" then
            globalValue = config[key]
        end
        if type(globalValue) == "boolean" then
            return globalValue
        end
        local defaultValue = COOLDOWN_BEHAVIOR_DEFAULTS[key]
        if type(defaultValue) == "boolean" then
            return defaultValue
        end
        return true
    end
    local override
    if type(alert) == "table" then
        override = alert[key]
    end
    if type(override) == "boolean" then
        return override
    end
    local config = EAM.db and EAM.db.config
    local globalValue = nil
    if type(config) == "table" then
        globalValue = config[key]
    end
    if type(globalValue) == "boolean" then
        return globalValue
    end
    return COOLDOWN_BEHAVIOR_DEFAULTS[key]
end

local function fireStateChanged(state)
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router and state then
        local frameName = (state.unit == "pet" or (state.rawAlert and (state.rawAlert.unit == "pet" or state.rawAlert.isPet)))
            and EAM.Constants.ALERT_FRAME_TYPES.petAlert
            or EAM.Constants.ALERT_FRAME_TYPES.spellCooldown
        router.fire(
            "EAM_COOLDOWN_STATE_CHANGED",
            state,
            frameName
        )
    end
end

local function setStateHidden(alertID, state, clearActivation)
    if clearActivation then
        CooldownService.activatedAlerts[alertID] = nil
        CooldownService.activationSpellIDs[alertID] = nil
        CooldownService.activationEvents[alertID] = nil
        CooldownService.chargeSpentObserved[alertID] = nil
    end
    if not state then
        return nil
    end
    state.shown = false
    CooldownService.states[alertID] = nil
    return state
end

local function setProtectedTimer(state, durationObject, warningField)
    state.factsSafe = false
    if not state.timer then
        state.timer = Util.tableCreate(0, 8)
    end
    Util.clearTimer(state.timer, EAM.Constants.TIMER_PROTECTED)
    state.timer.durationObject = durationObject
    Util.markBoundary(state, "cooldown", warningField)
end

-- 低 GC 的 CooldownState 物件快取池
CooldownStatePool = {
    recycleBin = {},
    binSize = 0,
}

CooldownService.CooldownStatePool = CooldownStatePool

function CooldownStatePool.initialize()
    for i = 1, 40 do
        local state = Util.tableCreate(0, 16)
        state.boundaryWarnings = Util.tableCreate(4, 0)
        state.timer = Util.tableCreate(0, 8)
        state.source = Util.tableCreate(0, 4)
        CooldownStatePool.recycleBin[i] = state
    end
    CooldownStatePool.binSize = 40
end

function CooldownStatePool.acquire()
    if CooldownStatePool.binSize > 0 then
        local state = CooldownStatePool.recycleBin[CooldownStatePool.binSize]
        CooldownStatePool.recycleBin[CooldownStatePool.binSize] = nil
        CooldownStatePool.binSize = CooldownStatePool.binSize - 1
        state.releaseFunc = CooldownStatePool.release
        return state
    else
        local state = Util.tableCreate(0, 16)
        state.boundaryWarnings = Util.tableCreate(4, 0)
        state.timer = Util.tableCreate(0, 8)
        state.source = Util.tableCreate(0, 4)
        state.releaseFunc = CooldownStatePool.release
        return state
    end
end

function CooldownStatePool.release(state)
    if not state then return end
    
    state.id = nil
    state.kind = nil
    state.spellID = nil
    state.name = nil
    state.icon = nil
    state.charges = nil
    state.maxCharges = nil
    state.chargeSpellID = nil
    state.isChargeBased = nil
    state.chargesSafe = false
    state.chargeActive = nil
    state.chargeActiveSafe = false
    state.chargeFull = nil
    state.chargeFullSafe = false
    state.chargeSpentObserved = false
    state.chargeCompletionDeferred = false
    state.displayValue = nil
    state.displayMaxValue = nil
    state.factsSafe = false
    state.active = false
    state.shown = false
    state.completed = nil
    state.usableGlow = nil
    state.isPlaceholder = nil
    state.isDesaturated = nil
    state.unit = nil
    state.rawAlert = nil
    state.order = nil
    state.cooldownRemoveAura = nil
    state.showSCDOutsideCombat = nil
    state.glowSCDWhenUsable = nil
    state.cooldownPreRender = nil
    state.overlayGlow = nil
    state.boundaryLimited = false
    state.isHeuristic = nil
    state.releaseFunc = nil
    wipe(state.boundaryWarnings)
    if state.timer then
        wipe(state.timer)
    else
        state.timer = Util.tableCreate(0, 8)
    end
    wipe(state.source)
    
    CooldownStatePool.binSize = CooldownStatePool.binSize + 1
    CooldownStatePool.recycleBin[CooldownStatePool.binSize] = state
end

-- Performance Optimizations: Array pre-allocation and revision tracking
local alertList = Util.tableCreate(32, 0)
local alertBaseSpellIDs = Util.tableCreate(32, 0)
local alertOverrideSpellIDs = Util.tableCreate(32, 0)
local alertPreviousOverrideSpellIDs = Util.tableCreate(32, 0)
local alertCount = 0
local lastDbRevision = -1

function CooldownService.updateAlertList()
    local previousCount = alertCount
    alertCount = 0
    local savedVariables = EAM.Modules and EAM.Modules.SavedVariables
    local alerts = savedVariables and savedVariables.getActiveAlerts and savedVariables.getActiveAlerts() or nil
    if alerts and alerts.spellCooldowns then
        for _, alert in pairs(alerts.spellCooldowns) do
            alertCount = alertCount + 1
            alertList[alertCount] = alert
            local baseSpellID, overrideSpellID, previousOverrideSpellID = resolveSpellFamily(alert and alert.spellID)
            alertBaseSpellIDs[alertCount] = baseSpellID
            alertOverrideSpellIDs[alertCount] = overrideSpellID
            alertPreviousOverrideSpellIDs[alertCount] = previousOverrideSpellID
        end
    end
    -- Clean up subsequent slots if the list shrank.
    for index = alertCount + 1, previousCount do
        alertList[index] = nil
        alertBaseSpellIDs[index] = nil
        alertOverrideSpellIDs[index] = nil
        alertPreviousOverrideSpellIDs[index] = nil
    end

    if EAM.UI and EAM.UI.Renderer and EAM.UI.Renderer.prewarmAlertFrames then
        pcall(EAM.UI.Renderer.prewarmAlertFrames)
    end
end

local function alertMatchesSpellFamily(index, spellID, baseSpellID, overrideSpellID)
    local alert = alertList[index]
    local alertSpellID = alert and alert.spellID or nil
    local alertBaseSpellID = alertBaseSpellIDs[index]
    local alertOverrideSpellID = alertOverrideSpellIDs[index]
    local alertPrevOverrideSpellID = alertPreviousOverrideSpellIDs[index]
    local prevOverrideSpellID = (Util.isSafePositiveNumber(baseSpellID) and CooldownService.previousOverrideMap[baseSpellID])
        or (Util.isSafePositiveNumber(spellID) and CooldownService.previousOverrideMap[spellID])
        or nil
    return sameSpellID(alertSpellID, spellID)
        or sameSpellID(alertSpellID, baseSpellID)
        or sameSpellID(alertSpellID, overrideSpellID)
        or sameSpellID(alertSpellID, prevOverrideSpellID)
        or sameSpellID(alertSpellID, alertPrevOverrideSpellID)
        or sameSpellID(alertBaseSpellID, spellID)
        or sameSpellID(alertBaseSpellID, baseSpellID)
        or sameSpellID(alertBaseSpellID, overrideSpellID)
        or sameSpellID(alertBaseSpellID, prevOverrideSpellID)
        or sameSpellID(alertBaseSpellID, alertPrevOverrideSpellID)
        or sameSpellID(alertOverrideSpellID, spellID)
        or sameSpellID(alertOverrideSpellID, baseSpellID)
        or sameSpellID(alertOverrideSpellID, overrideSpellID)
        or sameSpellID(alertOverrideSpellID, prevOverrideSpellID)
        or sameSpellID(alertOverrideSpellID, alertPrevOverrideSpellID)
        or sameSpellID(alertPrevOverrideSpellID, spellID)
        or sameSpellID(alertPrevOverrideSpellID, baseSpellID)
        or sameSpellID(alertPrevOverrideSpellID, overrideSpellID)
        or sameSpellID(alertPrevOverrideSpellID, prevOverrideSpellID)
end

local function verifyAlertList()
    local db = EAM.db
    if not db then return end
    local currentRev = db.revision or 0
    if currentRev ~= lastDbRevision then
        CooldownService.updateAlertList()
        lastDbRevision = currentRev
    end
end

-- 僅以安全（非 Secret）值判定「確實處於非 GCD 冷卻」；任何欄位不可讀即回傳 false（fail-closed，不自動開啟）。
function CooldownService.probeActiveCooldown(alert)
    local cSpell = api.C_Spell
    local spellID = type(alert) == "table" and alert.spellID or nil
    if not cSpell or not Util.isSafePositiveNumber(spellID) then
        return false
    end

    if type(cSpell.GetSpellCharges) == "function" then
        local chargesInfo = getSpellChargesInfo(cSpell, spellID, nil)
        if type(chargesInfo) == "table"
            and not Util.isSecretTable(chargesInfo)
            and Util.canAccessTable(chargesInfo)
        then
            local cur, curSafe = readChargeField(chargesInfo, "currentCharges", nil, "chargeProbe")
            local mx, mxSafe = readChargeField(chargesInfo, "maxCharges", nil, "chargeProbe")
            if curSafe and mxSafe
                and Util.isSafeNonNegativeNumber(cur)
                and Util.isSafePositiveNumber(mx)
            then
                return cur < mx
            end
            return false
        end
    end

    if type(cSpell.GetSpellCooldown) ~= "function" then
        return false
    end
    local okInfo, info = pcall(cSpell.GetSpellCooldown, spellID)
    if not okInfo or type(info) ~= "table" or not Util.canAccessTable(info) then
        return false
    end
    local st, stSafe = Util.readSafeField(info, "startTime", nil, "cooldownProbe")
    local dur, durSafe = Util.readSafeField(info, "duration", nil, "cooldownProbe")
    local en, enSafe = Util.readSafeField(info, "isEnabled", nil, "cooldownProbe")
    local gcd, gcdSafe = Util.readSafeField(info, "isOnGCD", nil, "cooldownProbe")
    if not (stSafe and durSafe) then
        return false
    end
    if gcdSafe and gcd == true then
        return false
    end
    if type(st) ~= "number" or type(dur) ~= "number" then
        return false
    end
    if dur <= MIN_REAL_COOLDOWN_SECONDS or st <= 0 then
        return false
    end
    if enSafe and en == false then
        return false
    end
    return true
end

local function refreshAlert(alert, eventName)
    local alertID = type(alert) == "table" and alert.id or nil
    local oldState = alertID and CooldownService.states[alertID] or nil
    if not Util.isSafeTableKey(alertID) then
        return nil, false
    end

    local oldShown = oldState and oldState.shown
    local oldActive = oldState and oldState.active
    local oldCompleted = oldState and oldState.completed
    local oldCharges = oldState and oldState.charges
    local oldChargeActive = oldState and oldState.chargeActive
    local oldPlaceholder = oldState and oldState.isPlaceholder
    local oldDesaturated = oldState and oldState.isDesaturated
    local oldGlow = oldState and oldState.usableGlow
    local oldIcon = oldState and oldState.icon
    local oldTimer = oldState and oldState.timer
    local oldStartTime = oldTimer and oldTimer.startTime
    local oldDuration = oldTimer and oldTimer.duration
    local oldExpirationTime = oldTimer and oldTimer.expirationTime

    if alert.enabled == false or not Util.isSafePositiveNumber(alert.spellID) then
        local hidden = setStateHidden(alertID, oldState, true)
        if hidden then
            hidden.rawAlert = alert
        end
        local isDirty = (hidden ~= nil and oldShown ~= false)
        return hidden, isDirty
    end

    local behaviorRemove = resolveBehavior(alert, "cooldownRemoveAura")
    local behaviorOutside = resolveBehavior(alert, "showSCDOutsideCombat")
    local behaviorGlow = resolveBehavior(alert, "glowSCDWhenUsable")
    local isPreRender = resolveBehavior(alert, "cooldownPreRender")
    local visibleNow = behaviorOutside or isInCombat()

    -- refreshAll、設定變更與一般 cooldown event 只更新已開啟的警示 (若開啟預渲染則依 visibleNow 決定顯示或 Alpha=0 隱藏佔位)
    if CooldownService.activatedAlerts[alertID] ~= true then
        if not isPreRender then
            if oldState then
                local hidden = setStateHidden(alertID, oldState, true)
                if hidden then
                    hidden.rawAlert = alert
                end
                local isDirty = (hidden ~= nil and oldShown ~= false)
                return hidden, isDirty
            end
            return nil, false
        else
            -- 預渲染待命佔位（尚未施放過）
            if not visibleNow then
                -- 戰鬥外且隨戰鬥關閉：圖示隱藏 (透過 Renderer SetAlpha(0) 保持槽位)
                if oldState then
                    local hidden = setStateHidden(alertID, oldState, false)
                    if hidden then
                        hidden.rawAlert = alert
                        hidden.isPlaceholder = true
                        hidden.isDesaturated = true
                        hidden.cooldownPreRender = isPreRender
                    end
                    local isDirty = (hidden ~= nil and oldShown ~= false)
                    return hidden, isDirty
                end
                return nil, false
            else
                -- 戰鬥中或非戰鬥允許顯示：以灰階暗色遮罩佔位顯示
                local state = oldState
                if not state then
                    state = CooldownStatePool.acquire()
                    CooldownService.states[alertID] = state
                end
                if not state.timer then
                    state.timer = Util.tableCreate(0, 8)
                end
                if not state.boundaryWarnings then
                    state.boundaryWarnings = Util.tableCreate(4, 0)
                end
                if not state.source then
                    state.source = Util.tableCreate(0, 4)
                end
                state.id = alertID
                state.kind = EAM.Constants.ALERT_KIND_SPELL_COOLDOWN
                state.spellID = alert.spellID
                state.order = alert.order
                state.rawAlert = alert
                state.isPlaceholder = true
                state.isDesaturated = true
                state.active = true
                state.shown = true
                state.completed = false
                state.usableGlow = false
                state.factsSafe = true
                state.cooldownRemoveAura = behaviorRemove
                state.showSCDOutsideCombat = behaviorOutside
                state.glowSCDWhenUsable = behaviorGlow
                state.cooldownPreRender = isPreRender
                state.boundaryLimited = false
                wipe(state.boundaryWarnings)
                wipe(state.source)
                local cSpell = api.C_Spell
                if SpellInfoService then
                    local spellInfo = SpellInfoService.getSpellInfo(alert.spellID)
                    if spellInfo then
                        state.name = spellInfo.name or tostring(alert.spellID)
                        state.icon = spellInfo.icon
                    else
                        state.name = tostring(alert.spellID)
                    end
                else
                    state.name = tostring(alert.spellID)
                end
                if alert.customName and alert.customName ~= "" then
                    state.name = alert.customName
                end
                if not state.icon and cSpell and cSpell.GetSpellTexture then
                    state.icon = cSpell.GetSpellTexture(alert.spellID)
                end
                if not state.icon and C_Spell and C_Spell.GetSpellTexture then
                    state.icon = C_Spell.GetSpellTexture(alert.spellID)
                end
                if alert.customIcon and alert.customIcon ~= "" then
                    state.icon = tonumber(alert.customIcon) or alert.customIcon
                end
                if not state.timer then
                    state.timer = Util.tableCreate(0, 8)
                end
                Util.clearTimer(state.timer, EAM.Constants.TIMER_UNKNOWN)
                local isDirty = (oldState == nil)
                    or (oldShown ~= state.shown)
                    or (oldActive ~= state.active)
                    or (oldPlaceholder ~= state.isPlaceholder)
                    or (oldDesaturated ~= state.isDesaturated)
                    or (oldGlow ~= state.usableGlow)
                    or (oldStartTime ~= state.timer.startTime)
                    or (oldDuration ~= state.timer.duration)
                return state, isDirty
            end
        end
    end

    local cSpell = api.C_Spell
    if not cSpell then
        local hidden = setStateHidden(alertID, oldState, false)
        local isDirty = (hidden ~= nil and oldShown ~= false)
        return hidden, isDirty
    end

    -- 1. Check Charges first. A non-nil SpellChargeInfo establishes charge capability;
    -- safe NeverSecret fields remain usable even when currentCharges is Secret.
    local isChargeBased = false
    local currentCharges, maxCharges
    local chargeActive
    local chargesInfo = nil
    local chargeSpellID = nil
    local chargesSafe = false
    local chargeActiveSafe = false

    if cSpell.GetSpellCharges then
        chargesInfo, chargeSpellID = getSpellChargesInfo(
            cSpell,
            alert.spellID,
            CooldownService.activationSpellIDs[alertID]
        )
        if type(chargesInfo) == "table" then
            isChargeBased = true
            if not Util.isSecretTable(chargesInfo) and Util.canAccessTable(chargesInfo) then
                local cur, curSafe = readChargeField(
                    chargesInfo,
                    "currentCharges",
                    nil,
                    "charges"
                )
                local mx, mxSafe = readChargeField(
                    chargesInfo,
                    "maxCharges",
                    nil,
                    "charges"
                )
                local active, activeSafe = readChargeField(
                    chargesInfo,
                    "isActive",
                    nil,
                    "charges"
                )

                if mxSafe and Util.isSafePositiveNumber(mx) then
                    maxCharges = mx
                end
                if curSafe and Util.isSafeNonNegativeNumber(cur) then
                    currentCharges = cur
                end
                chargesSafe = currentCharges ~= nil and maxCharges ~= nil
                if activeSafe and type(active) == "boolean" then
                    chargeActive = active
                    chargeActiveSafe = true
                end
            end
        end
    end

    -- 2. Process Cooldown Facts
    local cooldownInfo, cooldownSpellID = getSpellCooldownInfo(
        cSpell,
        alert.spellID,
        CooldownService.activationSpellIDs[alertID]
    )
    local infoSafe = false
    local startTime, duration, isEnabled, isOnGCD

    if cooldownInfo and Util.canAccessTable(cooldownInfo) then
        local st, stSafe = Util.readSafeField(cooldownInfo, "startTime", nil, "cooldown")
        local dur, durSafe = Util.readSafeField(cooldownInfo, "duration", nil, "cooldown")
        local en, enSafe = Util.readSafeField(cooldownInfo, "isEnabled", nil, "cooldown")
        local gcd, gcdSafe = Util.readSafeField(cooldownInfo, "isOnGCD", nil, "cooldown")

        if stSafe and durSafe and enSafe and gcdSafe then
            startTime = st
            duration = dur
            isEnabled = en
            isOnGCD = gcd
            infoSafe = true
        end
    end

    -- 3. 先判斷是否有未完成冷卻，再套用外部戰鬥顯示條件。
    local hasActiveCooldown = false
    local chargeFull = false
    local chargeFullSafe = false
    local chargeSpentObserved = CooldownService.chargeSpentObserved[alertID] == true
    local chargeCompletionDeferred = false
    if isChargeBased then
        -- currentCharges 只有在安全時才比較；isActive=true 是 NeverSecret 的未滿證據。
        local chargeSpentNow = chargesSafe and currentCharges < maxCharges
            or chargeActiveSafe and chargeActive == true
        if chargeSpentNow then
            chargeSpentObserved = true
            CooldownService.chargeSpentObserved[alertID] = true
        end

        -- 過渡快照若欄位互相矛盾，任何未滿證據都優先於「已滿」。
        if chargesSafe and currentCharges < maxCharges then
            chargeFull = false
            chargeFullSafe = true
        elseif chargeActiveSafe and chargeActive == true then
            chargeFull = false
            chargeFullSafe = true
        elseif chargesSafe then
            chargeFull = currentCharges == maxCharges
            chargeFullSafe = true
        elseif chargeActiveSafe then
            chargeFull = chargeActive ~= true
            chargeFullSafe = true
        end

        if chargeSpentObserved and chargeFullSafe then
            hasActiveCooldown = not chargeFull
        else
            -- UNIT_SPELLCAST_SUCCEEDED 可能早於 SPELL_UPDATE_CHARGES；未先證明已消耗時一律保留。
            hasActiveCooldown = true
            chargeCompletionDeferred = chargeFullSafe and chargeFull
        end
    elseif cooldownInfo then
        CooldownService.chargeSpentObserved[alertID] = nil
        if infoSafe then
            hasActiveCooldown = type(startTime) == "number"
                and type(duration) == "number"
                and duration > 0
                and isEnabled ~= false
                and isOnGCD ~= true
        else
            -- 無法讀取安全數字時保留 display-only／DurationObject 路徑。
            hasActiveCooldown = true
        end
    end

    -- 🛡️ 覆蓋與過渡狀態保護：若前一狀態仍有未過期的實質倒數，但當前候選因法術覆蓋（如彗星風暴取代冰霜射線）
    -- 或過渡延遲回傳 duration = 0，切勿直接截斷或抹除正在進行中的冷卻！
    local now = (api.GetTime and api.GetTime()) or 0
    local isTimerExpired = (eventName == "COOLDOWN_TIMER_EXPIRED")
    local oldTimer = oldState and oldState.timer
    local oldHasRunningCooldown = not isTimerExpired
        and oldState and oldState.active and not oldState.completed
        and oldTimer and type(oldTimer.expirationTime) == "number"
        and oldTimer.expirationTime > (now + 0.3)
    local isCastEvent = (eventName == "UNIT_SPELLCAST_SUCCEEDED" or eventName == "UNIT_SPELLCAST_CHANNEL_START" or eventName == "SPELLCAST_TRAILING_RETRY")

    -- 🛡️ 施法即刻啟動與先驗冷卻初始化 (Heuristic Cooldown Initialization)：
    -- 當玩家剛施法 (isCastEvent)，若 API 尚未回傳實質數值冷卻 (例如引導型技能冰霜射線回傳 0、GCD 或受保護秘密值)，
    -- 絕不能將其掛在空的 protectedTimer 導致 remaining=0；必須立即以先驗啟發式字典初始化冷卻倒數！
    local isHeuristic = false
    local heuristicData = EAM.Data and EAM.Data.SpellHeuristics and (EAM.Data.SpellHeuristics.SPELL_META or EAM.Data.SpellHeuristics.SPELL_DATA)
    local hasHeuristicMeta = heuristicData and (heuristicData[alert.spellID] or (cooldownSpellID and heuristicData[cooldownSpellID])) ~= nil

    if isCastEvent and not isChargeBased then
        local hasRealNumericCooldown = hasActiveCooldown and infoSafe and isOnGCD ~= true and type(duration) == "number" and duration > MIN_REAL_COOLDOWN_SECONDS
        if not hasRealNumericCooldown then
            local spellMeta = heuristicData and (heuristicData[alert.spellID] or (cooldownSpellID and heuristicData[cooldownSpellID]))
            local fallbackCD = spellMeta and (spellMeta.cooldown or spellMeta.baseCooldown)
            if fallbackCD and fallbackCD > MIN_REAL_COOLDOWN_SECONDS then
                hasActiveCooldown = true
                startTime = now
                duration = fallbackCD
                infoSafe = true
                isOnGCD = false
                isHeuristic = true
                local cdTrace = EAM.Debug and EAM.Debug.CooldownTrace
                if cdTrace and cdTrace.record then
                    cdTrace.record("HEURISTIC_INIT", alert.spellID, oldState and oldState.name, {
                        reason = "Initialized heuristic cooldown upon cast",
                        cooldown = fallbackCD,
                    })
                end
            end
        end
    elseif not hasActiveCooldown and not isChargeBased then
        local baseID, curOverride = resolveSpellFamily(alert.spellID)
        local isOverridden = (curOverride ~= nil and curOverride ~= alert.spellID)
            or (CooldownService.baseToOverrideMap[alert.spellID] ~= nil)
            or (CooldownService.previousOverrideMap[alert.spellID] ~= nil)
        local elapsedSinceStart = (oldTimer and type(oldTimer.startTime) == "number") and (now - oldTimer.startTime) or 999
        local inInitialGraceWindow = (hasHeuristicMeta or (oldState and oldState.isHeuristic == true))
            and elapsedSinceStart >= 0 and elapsedSinceStart <= 4.5

        if oldHasRunningCooldown and (isOverridden or inInitialGraceWindow) then
            hasActiveCooldown = true
            startTime = oldTimer.startTime
            duration = oldTimer.duration
            infoSafe = true
            isHeuristic = true
            local cdTrace = EAM.Debug and EAM.Debug.CooldownTrace
            if cdTrace and cdTrace.record then
                cdTrace.record("OVERRIDE_PRESERVED", alert.spellID, oldState.name, {
                    reason = isOverridden and "Preserved running cooldown against zero-CD override proc" or "Preserved running cooldown in initial cast grace window",
                    remaining = oldTimer.expirationTime - now,
                    overrideSpellID = curOverride,
                })
            end
        end
    end

    local shouldShow = hasActiveCooldown
    if not visibleNow then
        shouldShow = false
    elseif not hasActiveCooldown and (not behaviorRemove or isPreRender) then
        -- 第一次施放後，完成狀態仍可依設定保留圖示 (若開啟預渲染佔位則保留為灰階遮罩)
        shouldShow = true
    end

    if not shouldShow then
        local hidden = setStateHidden(alertID, oldState, false)
        local isDirty = (hidden ~= nil and oldShown ~= false)
        return hidden, isDirty
    end

    -- 4. Allocate state only after the spell has been activated by the player.
    local state = oldState
    if not state then
        state = CooldownStatePool.acquire()
        CooldownService.states[alertID] = state
    end
    if not state.timer then
        state.timer = Util.tableCreate(0, 8)
    end
    if not state.boundaryWarnings then
        state.boundaryWarnings = Util.tableCreate(4, 0)
    end
    if not state.source then
        state.source = Util.tableCreate(0, 4)
    end

    state.id = alertID
    state.kind = EAM.Constants.ALERT_KIND_SPELL_COOLDOWN
    state.spellID = alert.spellID
    state.order = alert.order
    state.rawAlert = alert
    state.unit = alert.unit or (alert.isPet and "pet") or "player"
    state.name = nil
    state.icon = nil
    state.charges = isChargeBased and currentCharges or nil
    state.maxCharges = isChargeBased and maxCharges or nil
    state.chargeSpellID = isChargeBased and chargeSpellID or nil
    state.isChargeBased = isChargeBased
    state.isHeuristic = isHeuristic or (oldState and oldState.isHeuristic == true and oldHasRunningCooldown and true or false)
    state.chargesSafe = chargesSafe
    state.chargeActive = nil
    if chargeActiveSafe then
        state.chargeActive = chargeActive
    end
    state.chargeActiveSafe = chargeActiveSafe
    state.chargeFull = nil
    if chargeFullSafe then
        state.chargeFull = chargeFull
    end
    state.chargeFullSafe = chargeFullSafe
    state.chargeSpentObserved = chargeSpentObserved
    state.chargeCompletionDeferred = chargeCompletionDeferred
    state.displayValue = isChargeBased and chargesSafe and currentCharges or nil
    state.displayMaxValue = isChargeBased and maxCharges or nil
    state.factsSafe = true
    state.active = true
    state.shown = true
    state.completed = not hasActiveCooldown
    local isPlaceholder = isPreRender and not hasActiveCooldown
    state.isPlaceholder = isPlaceholder
    state.isDesaturated = isPlaceholder
    state.usableGlow = state.completed and behaviorGlow or false
    if isPlaceholder then
        state.usableGlow = false
    end
    state.cooldownRemoveAura = behaviorRemove
    state.showSCDOutsideCombat = behaviorOutside
    state.glowSCDWhenUsable = behaviorGlow
    state.cooldownPreRender = isPreRender
    state.boundaryLimited = false
    wipe(state.boundaryWarnings)
    wipe(state.source)

    -- Spell Info lookup (name, icon)
    if SpellInfoService then
        local spellInfo = SpellInfoService.getSpellInfo(alert.spellID)
        if spellInfo then
            state.name = spellInfo.name or tostring(alert.spellID)
            state.icon = spellInfo.icon
        else
            state.name = tostring(alert.spellID)
        end
    else
        state.name = tostring(alert.spellID)
    end

    if alert.customName and alert.customName ~= "" then
        state.name = alert.customName
    end

    if alert.customIcon and alert.customIcon ~= "" then
        state.icon = tonumber(alert.customIcon) or alert.customIcon
    end

    -- 5. Populate TimerState. Completed states deliberately clear old timing.
    if not state.timer then
        state.timer = Util.tableCreate(0, 8)
    end
    if not hasActiveCooldown then
        Util.clearTimer(state.timer, EAM.Constants.TIMER_UNKNOWN)
    elseif isChargeBased then
        if chargesSafe then
            if chargesInfo then
                local start, startSafe = readChargeField(
                    chargesInfo,
                    "cooldownStartTime",
                    state.boundaryWarnings,
                    "charges"
                )
                local dur, durSafe = readChargeField(
                    chargesInfo,
                    "cooldownDuration",
                    state.boundaryWarnings,
                    "charges"
                )

                if startSafe and durSafe
                    and Util.isSafeNumber(start)
                    and Util.isSafePositiveNumber(dur)
                then
                    state.factsSafe = true
                    state.timer.mode = EAM.Constants.TIMER_NUMERIC
                    state.timer.startTime = start
                    state.timer.duration = dur
                    state.timer.expirationTime = start + dur
                    state.timer.durationObject = (cSpell.GetSpellChargeDuration and cSpell.GetSpellChargeDuration(chargeSpellID or alert.spellID))
                        or (DurationAdapter and DurationAdapter.createFromStart and DurationAdapter.createFromStart(start, dur))
                        or nil
                else
                    setProtectedTimer(
                        state,
                        getDurationObject(cSpell.GetSpellChargeDuration, chargeSpellID or alert.spellID),
                        "chargeTimingProtected"
                    )
                end
            else
                setProtectedTimer(
                    state,
                    getDurationObject(cSpell.GetSpellChargeDuration, chargeSpellID or alert.spellID),
                    "chargeTimingUnavailable"
                )
            end
        else
            setProtectedTimer(
                state,
                getDurationObject(cSpell.GetSpellChargeDuration, chargeSpellID or alert.spellID),
                "chargeFactsProtected"
            )
        end
    elseif infoSafe
        and type(startTime) == "number"
        and type(duration) == "number"
        and duration > 0
        and isEnabled ~= false
        and isOnGCD ~= true
    then
        state.timer.mode = EAM.Constants.TIMER_NUMERIC
        state.timer.startTime = startTime
        state.timer.duration = duration
        state.timer.expirationTime = startTime + duration
        local durationSpellID = cooldownSpellID or alert.spellID
        state.timer.durationObject = (not isHeuristic and not oldHasRunningCooldown and cSpell.GetSpellCooldownDuration and cSpell.GetSpellCooldownDuration(durationSpellID, true))
            or nil
    elseif oldHasRunningCooldown and state.isHeuristic then
        state.timer.mode = EAM.Constants.TIMER_NUMERIC
        state.timer.startTime = oldTimer.startTime
        state.timer.duration = oldTimer.duration
        state.timer.expirationTime = oldTimer.expirationTime
        state.timer.durationObject = nil
    else
        local durationSpellID = cooldownSpellID or alert.spellID
        setProtectedTimer(
            state,
            getDurationObject(cSpell.GetSpellCooldownDuration, durationSpellID, true),
            "timingProtected"
        )
    end

    state.source.event = eventName
    state.source.api = isChargeBased and "C_Spell.GetSpellCharges" or "C_Spell.GetSpellCooldown"
    local actEvent = CooldownService.activationEvents[alertID] or (eventName == "UNIT_SPELLCAST_CHANNEL_START" and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_SUCCEEDED")
    state.source.activation = tostring(actEvent) .. ":" .. tostring(state.unit or "player")
    state.source.activationSpellID = CooldownService.activationSpellIDs[alertID]
    state.source.chargeSpellID = chargeSpellID
    local newTimer = state.timer
    local newStartTime = newTimer and newTimer.startTime
    local newDuration = newTimer and newTimer.duration
    local newExpirationTime = newTimer and newTimer.expirationTime

    local isCastEvent = (eventName == "UNIT_SPELLCAST_SUCCEEDED" or eventName == "UNIT_SPELLCAST_CHANNEL_START" or eventName == "SPELLCAST_TRAILING_RETRY")
    local isDirty = (oldState == nil)
        or (oldShown ~= state.shown)
        or (oldActive ~= state.active)
        or (oldCompleted ~= state.completed)
        or (oldCharges ~= state.charges)
        or (oldChargeActive ~= state.chargeActive)
        or (oldPlaceholder ~= state.isPlaceholder)
        or (oldDesaturated ~= state.isDesaturated)
        or (oldGlow ~= state.usableGlow)
        or (oldIcon ~= state.icon)
        or (oldStartTime ~= newStartTime)
        or (oldDuration ~= newDuration)
        or (math.abs((oldExpirationTime or 0) - (newExpirationTime or 0)) > 0.01)
        or (isCastEvent and hasActiveCooldown)

    return state, isDirty
end
local presentAlerts = {}
local function cleanupDeletedAlerts()
    wipe(presentAlerts)
    for index = 1, alertCount do
        local alert = alertList[index]
        if alert and Util.isSafeTableKey(alert.id) then
            presentAlerts[alert.id] = true
        end
    end

    for alertID in pairs(CooldownService.activatedAlerts) do
        if not presentAlerts[alertID] then
            CooldownService.activatedAlerts[alertID] = nil
            CooldownService.activationSpellIDs[alertID] = nil
            CooldownService.activationEvents[alertID] = nil
            CooldownService.chargeSpentObserved[alertID] = nil
        end
    end
    for alertID, state in pairs(CooldownService.states) do
        if not presentAlerts[alertID] then
            local hidden = setStateHidden(alertID, state, true)
            fireStateChanged(hidden)
        end
    end
end

-- 前置宣告 refreshAll
local refreshAll

-- 冷卻事件合併排程器（在同一幀/Tick 內多次收到全域事件時合併掃描，防範重複 full-list scan）
local hasRefreshedThisTick = false
local needsTrailingRefresh = false

local function resetCoalesce()
    hasRefreshedThisTick = false
    if needsTrailingRefresh then
        needsTrailingRefresh = false
        refreshAll("COALESCED")
    end
end

local function queueCoalescedRefresh(eventName)
    if EAM.FlowTestEnvironment == "offline-mock" and not CooldownService._testCoalesceEnabled then
        return refreshAll(eventName)
    end

    local scheduler = EAM.Modules and EAM.Modules.Scheduler
    if not scheduler or not scheduler.after then
        return refreshAll(eventName)
    end

    if not hasRefreshedThisTick then
        hasRefreshedThisTick = true
        needsTrailingRefresh = false
        scheduler.after(0, resetCoalesce)
        return refreshAll(eventName)
    else
        needsTrailingRefresh = true
        return true, "coalesced"
    end
end

function refreshAll(eventName)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    verifyAlertList()
    cleanupDeletedAlerts()
    if alertCount == 0 then
        return true, "empty"
    end

    local hasAnyActive = false
    for index = 1, alertCount do
        local alert = alertList[index]
        local state, isDirty = refreshAlert(alert, eventName)
        if state then
            if state.active and not state.completed and not state.isPlaceholder then
                hasAnyActive = true
            end
            if isDirty then
                fireStateChanged(state)
            end
        end
    end
    if hasAnyActive then
        CooldownService.ensureActiveCDRSampler()
    end
    return true, "updated"
end
function CooldownService.initialize()
    CooldownStatePool.initialize()
    DurationAdapter = DurationAdapter or (EAM.Modules and EAM.Modules.DurationAdapter)
    local router = EAM.Modules.EventRouter
    if router then
        router.register("SPELL_UPDATE_COOLDOWN", CooldownService.onCooldownEvent)
        router.register("SPELL_UPDATE_CHARGES", CooldownService.onCooldownEvent)
        router.register("PET_BAR_UPDATE", CooldownService.onCooldownEvent)
        router.register("UNIT_SPELLCAST_SUCCEEDED", CooldownService.onSpellcastSucceeded)
        router.register("UNIT_SPELLCAST_CHANNEL_START", CooldownService.onSpellcastSucceeded)
        router.register("UNIT_SPELLCAST_CHANNEL_STOP", CooldownService.onSpellcastChannelStop)
        router.register("PLAYER_REGEN_ENABLED", CooldownService.onCombatEvent)
        router.register("PLAYER_REGEN_DISABLED", CooldownService.onCombatEvent)
        router.register("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", function(eventName, baseSpellID, overrideSpellID)
            local cdTrace = EAM.Debug and EAM.Debug.CooldownTrace
            if cdTrace and cdTrace.record then
                cdTrace.record("OVERRIDE_UPDATED", baseSpellID, nil, { overrideSpellID = overrideSpellID })
            end
            if Util.isSafePositiveNumber(baseSpellID) then
                local prevOverride = CooldownService.baseToOverrideMap[baseSpellID]
                if Util.isSafePositiveNumber(overrideSpellID) and overrideSpellID ~= baseSpellID then
                    if prevOverride and prevOverride ~= overrideSpellID then
                        CooldownService.previousOverrideMap[baseSpellID] = prevOverride
                        CooldownService.previousOverrideToBaseMap[prevOverride] = baseSpellID
                        CooldownService.overrideToBaseMap[prevOverride] = nil
                    end
                    CooldownService.baseToOverrideMap[baseSpellID] = overrideSpellID
                    CooldownService.overrideToBaseMap[overrideSpellID] = baseSpellID
                else
                    -- 覆蓋已移除或重置為基礎技能，捕獲前次覆蓋以補償冷卻事件
                    if prevOverride then
                        CooldownService.previousOverrideMap[baseSpellID] = prevOverride
                        CooldownService.previousOverrideToBaseMap[prevOverride] = baseSpellID
                        CooldownService.overrideToBaseMap[prevOverride] = nil
                    end
                    CooldownService.baseToOverrideMap[baseSpellID] = nil
                end
            end

            CooldownService.updateAlertList()
            if EAM.db then
                lastDbRevision = EAM.db.revision or 0
            end

            -- 若當前有活躍警報正處於舊的 baseSpellID、前次覆蓋或新覆蓋，動態遷移活躍狀態
            local prevOverride = Util.isSafePositiveNumber(baseSpellID) and CooldownService.previousOverrideMap[baseSpellID] or nil
            if Util.isSafePositiveNumber(baseSpellID) or Util.isSafePositiveNumber(overrideSpellID) or Util.isSafePositiveNumber(prevOverride) then
                local targetSpellID = Util.isSafePositiveNumber(overrideSpellID) and overrideSpellID or baseSpellID
                CooldownService.refreshSpell(targetSpellID, eventName, baseSpellID)
                if Util.isSafePositiveNumber(baseSpellID) and baseSpellID ~= targetSpellID then
                    CooldownService.refreshSpell(baseSpellID, eventName, baseSpellID)
                end
                if Util.isSafePositiveNumber(prevOverride) and prevOverride ~= targetSpellID and prevOverride ~= baseSpellID then
                    CooldownService.refreshSpell(prevOverride, eventName, baseSpellID)
                end
            end

            if router and router.fire then
                router.fire("EAM_SPELL_OVERRIDE_UPDATED", baseSpellID, overrideSpellID)
            end
        end)
    end
end

local function resolveEventSpellFamily(spellID, suppliedBaseSpellID)
    local baseSpellID, overrideSpellID, previousOverrideSpellID = resolveSpellFamily(spellID)
    if Util.isSafePositiveNumber(suppliedBaseSpellID) then
        baseSpellID = suppliedBaseSpellID
        local _, suppliedOverrideSpellID, suppliedPrevOverride = resolveSpellFamily(suppliedBaseSpellID)
        if Util.isSafePositiveNumber(suppliedOverrideSpellID) then
            overrideSpellID = suppliedOverrideSpellID
        end
        if Util.isSafePositiveNumber(suppliedPrevOverride) then
            previousOverrideSpellID = suppliedPrevOverride
        end
    end
    return baseSpellID, overrideSpellID, previousOverrideSpellID
end

function CooldownService.refreshSpell(spellID, eventName, suppliedBaseSpellID)
    if EAM.recordHotPath then
        EAM.recordHotPath("CooldownService.refreshSpell")
    end
    if not moduleEnabled() then
        return nil, "moduleDisabled"
    end
    if not Util.isSafePositiveNumber(spellID) then
        return nil, "invalidSpellID"
    end
    verifyAlertList()
    if alertCount == 0 then
        return nil
    end

    local baseSpellID, overrideSpellID = resolveEventSpellFamily(spellID, suppliedBaseSpellID)
    local result
    for index = 1, alertCount do
        local alert = alertList[index]
        if alert
            and Util.isSafeTableKey(alert.id)
            and alertMatchesSpellFamily(index, spellID, baseSpellID, overrideSpellID)
            and (
                CooldownService.activatedAlerts[alert.id] == true
                or CooldownService.states[alert.id] ~= nil
            )
        then
            local state, isDirty = refreshAlert(alert, eventName or "manual")
            if state then
                if isDirty then
                    fireStateChanged(state)
                end
                result = state
            end
        end
    end
    return result
end

function CooldownService.activateSpell(spellID, eventName)
    if not moduleEnabled() then
        return nil, "moduleDisabled"
    end
    if not Util.isSafePositiveNumber(spellID) then
        return nil, "invalidSpellID"
    end
    verifyAlertList()
    local result
    local hasAnyActiveCooldown = false
    local matchedCount = 0
    local now = (api.GetTime and api.GetTime()) or 0

    for index = 1, alertCount do
        local alert = alertList[index]
        if alert
            and Util.isSafeTableKey(alert.id)
            and alert.enabled ~= false
        then
            local isExactMatch = sameSpellID(alert.spellID, spellID)
            local isOverrideMatch = false
            local oldState = CooldownService.states[alert.id]
            local oldTimer = oldState and oldState.timer
            local oldActiveRunning = oldState and oldState.active and not oldState.completed
                and oldTimer and type(oldTimer.expirationTime) == "number"
                and oldTimer.expirationTime > (now + 0.3)

            -- 🛡️ 施法觸發精確防禦（杜絕 GetBaseSpell 反向劫持）：
            -- 1. 精確匹配：本次施放的正是該警報所監控之法術 (spellID == alert.spellID)。
            -- 2. 天賦覆蓋匹配：此警報的基礎法術被天賦永久替換（alertOverrideSpellIDs[index] == spellID），
            --    但前提是：主技能當前「沒有」正在倒數中的有效冷卻（避免像冰霜射線引導後觸發的彗星風暴反向破壞主冷卻）！
            --    且觸發冷卻時絕不拿施法技能的 GetBaseSpell 去反向抓取無關的基礎技能！
            if not isExactMatch and not oldActiveRunning then
                local alertOverrideID = alertOverrideSpellIDs[index]
                if alertOverrideID and sameSpellID(alertOverrideID, spellID) then
                    isOverrideMatch = true
                end
            end

            if isExactMatch or isOverrideMatch then
                matchedCount = matchedCount + 1
                CooldownService.activatedAlerts[alert.id] = true
                CooldownService.activationSpellIDs[alert.id] = spellID
                CooldownService.chargeSpentObserved[alert.id] = nil
                CooldownService.activationEvents[alert.id] = eventName or "UNIT_SPELLCAST_SUCCEEDED"

                local state, isDirty = refreshAlert(alert, eventName or "UNIT_SPELLCAST_SUCCEEDED")
                if state then
                    local hasActive = (state.completed ~= true and state.isPlaceholder ~= true)
                    if hasActive then
                        hasAnyActiveCooldown = true
                    end
                    if isDirty or hasActive then
                        fireStateChanged(state)
                    end
                    result = state
                end

                local cdTrace = EAM.Debug and EAM.Debug.CooldownTrace
                if cdTrace and cdTrace.record then
                    local expTime = state and state.timer and state.timer.expirationTime
                    local rem = (type(expTime) == "number" and expTime > now) and (expTime - now) or 0
                    cdTrace.record("ACTIVATE_MATCH", alert.spellID, state and state.name, {
                        castSpellID = spellID,
                        isOverrideMatch = isOverrideMatch,
                        hasActive = (state and state.completed ~= true and state.isPlaceholder ~= true),
                        remaining = rem,
                    })
                end
            end
        end
    end

    if hasAnyActiveCooldown then
        CooldownService.ensureActiveCDRSampler()
    end

    -- 若匹配到警示，但當下 Blizzard 引擎尚未回傳實質冷卻（例如僅回傳 0 或 GCD），
    -- 排程微延遲重試 (50ms 與 150ms)，確保客戶端在收到冷卻封包後即刻刷新激活
    if matchedCount > 0 and not hasAnyActiveCooldown then
        local scheduler = EAM.Modules and EAM.Modules.Scheduler
        if scheduler and scheduler.after then
            scheduler.after(0.05, function()
                CooldownService.refreshSpell(spellID, "SPELLCAST_TRAILING_RETRY", baseSpellID)
            end)
            scheduler.after(0.15, function()
                CooldownService.refreshSpell(spellID, "SPELLCAST_TRAILING_RETRY", baseSpellID)
            end)
        end
    end

    return result
end

function CooldownService.refreshActiveCooldowns(excludeSpellID)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    verifyAlertList()
    local refreshedCount = 0
    local baseExclude, overrideExclude = nil, nil
    if Util.isSafePositiveNumber(excludeSpellID) then
        baseExclude, overrideExclude = resolveEventSpellFamily(excludeSpellID)
    end

    for index = 1, alertCount do
        local alert = alertList[index]
        if alert and Util.isSafeTableKey(alert.id) and alert.enabled ~= false then
            if CooldownService.activatedAlerts[alert.id] == true then
                local state = CooldownService.states[alert.id]
                if state and state.active and not state.completed and not state.isPlaceholder then
                    local isExcluded = false
                    if Util.isSafePositiveNumber(excludeSpellID) then
                        if alert.spellID == excludeSpellID
                            or (baseExclude and alert.spellID == baseExclude)
                            or (overrideExclude and alert.spellID == overrideExclude)
                        then
                            isExcluded = true
                        end
                    end
                    if not isExcluded then
                        local refreshedState, isDirty = refreshAlert(alert, "ACTIVE_COOLDOWN_SYNC")
                        if refreshedState then
                            refreshedCount = refreshedCount + 1
                            if isDirty then
                                fireStateChanged(refreshedState)
                            end
                        end
                    end
                end
            end
        end
    end
    return refreshedCount
end

local burstSamplerActive = false
local burstEndTime = 0
local burstInterval = 0.08 -- 80ms 高頻取樣

local function burstCDRSamplerTick()
    if not burstSamplerActive or not moduleEnabled() then
        burstSamplerActive = false
        return
    end

    local now = (api.GetTime and api.GetTime()) or 0
    if now > burstEndTime then
        burstSamplerActive = false
        return
    end

    local activeCount = 0
    verifyAlertList()

    for index = 1, alertCount do
        local alert = alertList[index]
        if alert and Util.isSafeTableKey(alert.id) and alert.enabled ~= false then
            if CooldownService.activatedAlerts[alert.id] == true then
                local oldState = CooldownService.states[alert.id]
                if oldState and oldState.active and not oldState.completed and not oldState.isPlaceholder then
                    activeCount = activeCount + 1
                    local oldTimer = oldState.timer
                    local oldExp = oldTimer and oldTimer.expirationTime

                    local refreshedState, isDirty = refreshAlert(alert, "BURST_CDR_TICK")
                    if refreshedState then
                        local newTimer = refreshedState.timer
                        local newExp = newTimer and newTimer.expirationTime

                        -- 檢測到實質冷卻縮短（CDR 發生）
                        if type(oldExp) == "number" and type(newExp) == "number" and (oldExp - newExp) > 0.02 then
                            local delta = newExp - oldExp
                            local cdTrace = EAM.Debug and EAM.Debug.CooldownTrace
                            if cdTrace and cdTrace.record then
                                cdTrace.record("CDR_DETECTED", alert.spellID, refreshedState.name, {
                                    delta = string.format("%.2fs", delta),
                                    remaining = string.format("%.2fs", math.max(0, newExp - now)),
                                    oldExp = string.format("%.2f", oldExp),
                                    newExp = string.format("%.2f", newExp),
                                })
                            end
                            fireStateChanged(refreshedState)
                        elseif isDirty then
                            fireStateChanged(refreshedState)
                        end
                    end
                end
            end
        end
    end

    if activeCount > 0 and now < burstEndTime then
        local scheduler = EAM.Modules and EAM.Modules.Scheduler
        if scheduler and scheduler.after then
            scheduler.after(burstInterval, burstCDRSamplerTick)
        else
            burstSamplerActive = false
        end
    else
        burstSamplerActive = false
    end
end

function CooldownService.startBurstCDRSampler(duration)
    local dur = duration or 1.25 -- 預設突發取樣 1.25 秒，完整覆蓋 0~40 碼彈道
    local now = (api.GetTime and api.GetTime()) or 0
    burstEndTime = math.max(burstEndTime, now + dur)
    if burstSamplerActive then
        return
    end
    burstSamplerActive = true
    local scheduler = EAM.Modules and EAM.Modules.Scheduler
    if scheduler and scheduler.after then
        scheduler.after(0.06, burstCDRSamplerTick)
    else
        burstSamplerActive = false
    end
end

function CooldownService.scheduleActiveCDRRetries()
    local scheduler = EAM.Modules and EAM.Modules.Scheduler
    if scheduler and scheduler.after then
        local retryToken = (CooldownService._activeCDRToken or 0) + 1
        CooldownService._activeCDRToken = retryToken
        CooldownService._activeCDRRetryPending = true
        -- 多段彈道飛行時間支援（近戰 120ms、中距離 350ms、極限 40 碼 700ms）
        scheduler.after(0.12, function()
            if moduleEnabled() then
                CooldownService.refreshActiveCooldowns(nil)
            end
        end)
        scheduler.after(0.35, function()
            if moduleEnabled() then
                CooldownService.refreshActiveCooldowns(nil)
            end
        end)
        scheduler.after(0.70, function()
            if CooldownService._activeCDRToken == retryToken then
                CooldownService._activeCDRRetryPending = false
            end
            if moduleEnabled() then
                CooldownService.refreshActiveCooldowns(nil)
            end
        end)
    end
    CooldownService.startBurstCDRSampler(1.25)
end

local activeCDRSamplerActive = false

local function activeCDRSamplerTick()
    if not activeCDRSamplerActive or not moduleEnabled() then
        activeCDRSamplerActive = false
        return
    end

    local activeCount = 0
    verifyAlertList()

    for index = 1, alertCount do
        local alert = alertList[index]
        if alert and Util.isSafeTableKey(alert.id) and alert.enabled ~= false then
            if CooldownService.activatedAlerts[alert.id] == true then
                local oldState = CooldownService.states[alert.id]
                if oldState and oldState.active and not oldState.completed and not oldState.isPlaceholder then
                    activeCount = activeCount + 1
                    local oldTimer = oldState.timer
                    local oldExp = oldTimer and oldTimer.expirationTime

                    local refreshedState, isDirty = refreshAlert(alert, "ACTIVE_CDR_TICK")
                    if refreshedState then
                        local newTimer = refreshedState.timer
                        local newExp = newTimer and newTimer.expirationTime

                        if type(oldExp) == "number" and type(newExp) == "number" and (oldExp - newExp) > 0.02 then
                            local delta = newExp - oldExp
                            local cdTrace = EAM.Debug and EAM.Debug.CooldownTrace
                            if cdTrace and cdTrace.record then
                                cdTrace.record("CDR_DETECTED", alert.spellID, refreshedState.name, {
                                    delta = string.format("%.2fs", delta),
                                    remaining = string.format("%.2fs", math.max(0, newExp - (api.GetTime and api.GetTime() or 0))),
                                })
                            end
                            fireStateChanged(refreshedState)
                        elseif isDirty then
                            fireStateChanged(refreshedState)
                        end
                    end
                end
            end
        end
    end

    if activeCount > 0 then
        local scheduler = EAM.Modules and EAM.Modules.Scheduler
        if scheduler and scheduler.after then
            scheduler.after(0.25, activeCDRSamplerTick)
        else
            activeCDRSamplerActive = false
        end
    else
        activeCDRSamplerActive = false
    end
end

function CooldownService.ensureActiveCDRSampler()
    if activeCDRSamplerActive then
        return
    end
    activeCDRSamplerActive = true
    local scheduler = EAM.Modules and EAM.Modules.Scheduler
    if scheduler and scheduler.after then
        scheduler.after(0.25, activeCDRSamplerTick)
    else
        activeCDRSamplerActive = false
    end
end

-- 🛡️ 戰鬥中受保護冷卻之先驗減 CD 推算器 (In-Combat Heuristic CDR Deduction)：
-- 在 Retail 12.1+ 戰鬥中 (InCombatLockdown)，C_Spell.GetSpellCooldown 的 startTime 與 duration 會轉為 Secret Value，
-- 導致針對先驗初始化 (isHeuristic) 的冷卻無法透過 API 讀出減 CD 後的新數值。
-- 此函式在玩家施放減 CD 觸發技能時，即時對正在倒數中的先驗冷卻進行安全數值扣減，並於脫戰或 API 解鎖時自動無縫對齊官方時間！
function CooldownService.applyCombatHeuristicCDR(triggerSpellID)
    if not Util.isSafePositiveNumber(triggerSpellID) then
        return 0
    end
    local now = (api.GetTime and api.GetTime()) or 0
    local isKnown = function(sID)
        if api.IsPlayerSpell and api.IsPlayerSpell(sID) then return true end
        local cSpell = api.C_Spell
        if cSpell and cSpell.IsSpellKnownOrOverridesKnown and cSpell.IsSpellKnownOrOverridesKnown(sID) then return true end
        return false
    end

    local cdrTargets = nil
    if triggerSpellID == 30455 then
        -- 冰霜長矛 (Ice Lance 30455):
        -- 1. 白化 (Whiteout 1281638) + 碎冰消融: 縮短冰霜之球 (84714) 冷卻時間
        -- 2. 結冰 (Freezing 1247798) / 冰之心 (Heart of Ice 1247799): 消耗碎冰縮短冰霜射線 (205021) 冷卻時間
        local orbDelta = isKnown(1281638) and 1.5 or 0.5
        local rayDelta = (isKnown(1247798) or isKnown(1247799)) and 2.0 or 1.0
        cdrTargets = {
            [84714] = orbDelta,
            [205021] = rayDelta,
        }
    elseif triggerSpellID == 44614 or triggerSpellID == 228354 then
        -- 冰風暴 (Flurry): 縮短冰霜之球與冰霜射線冷卻
        cdrTargets = {
            [84714] = 0.5,
            [205021] = 1.0,
        }
    elseif triggerSpellID == 190356 or triggerSpellID == 1248829 then
        -- 暴風雪 (Blizzard): 縮短冰霜之球冷卻
        cdrTargets = {
            [84714] = 0.5,
        }
    end

    if not cdrTargets then
        return 0
    end

    local adjustedCount = 0
    local cSpell = api.C_Spell
    local cdTrace = EAM.Debug and EAM.Debug.CooldownTrace

    for alertID, state in pairs(CooldownService.states) do
        if state and state.active and not state.completed and not state.isPlaceholder and state.timer then
            local targetSpellID = state.spellID
            local delta = targetSpellID and cdrTargets[targetSpellID]
            if delta and delta > 0 and type(state.timer.expirationTime) == "number" and state.timer.expirationTime > now then
                -- 先檢查當前 API 是否已提供非 Secret 的安全數值（如非戰鬥或模擬測試環境）；若有安全數值則交由 refreshActiveCooldowns 精確同步
                local apiHasSafeNumeric = false
                if cSpell and type(cSpell.GetSpellCooldown) == "function" then
                    local okInfo, info = pcall(cSpell.GetSpellCooldown, targetSpellID)
                    if okInfo and type(info) == "table" and Util.canAccessTable(info) then
                        local _, stSafe = Util.readSafeField(info, "startTime", nil, "cdrCheck")
                        local dur, durSafe = Util.readSafeField(info, "duration", nil, "cdrCheck")
                        local gcd, gcdSafe = Util.readSafeField(info, "isOnGCD", nil, "cdrCheck")
                        if stSafe and durSafe and type(dur) == "number" and dur > MIN_REAL_COOLDOWN_SECONDS and (not gcdSafe or gcd ~= true) then
                            apiHasSafeNumeric = true
                        end
                    end
                end

                if not apiHasSafeNumeric then
                    local oldExp = state.timer.expirationTime
                    local newExp = math.max(now + 0.1, oldExp - delta)
                    local actualDelta = oldExp - newExp
                    if actualDelta > 0.01 then
                        state.timer.startTime = (state.timer.startTime or now) - actualDelta
                        state.timer.expirationTime = newExp
                        state.isHeuristic = true
                        adjustedCount = adjustedCount + 1
                        if cdTrace and cdTrace.record then
                            cdTrace.record("CDR_DETECTED", targetSpellID, state.name, {
                                delta = string.format("-%.2fs (Heuristic)", actualDelta),
                                remaining = string.format("%.2fs", math.max(0, newExp - now)),
                                triggerSpellID = triggerSpellID,
                            })
                        end
                        fireStateChanged(state)
                    end
                end
            end
        end
    end

    return adjustedCount
end

function CooldownService.onSpellcastSucceeded(eventName, unit, castGUID, spellID)
    if EAM.recordHotPath then
        EAM.recordHotPath("CooldownService.onSpellcastSucceeded")
    end
    if eventName == "UNIT_SPELLCAST_CHANNEL_START" then
        if unit ~= "player" and unit ~= "pet" then
            return false, "notPlayerCast"
        end
    elseif eventName ~= "UNIT_SPELLCAST_SUCCEEDED" or unit ~= "player" then
        if unit ~= "pet" then
            return false, "notPlayerCast"
        end
    end
    if not Util.isSafePositiveNumber(spellID) then
        return false, "invalidSpellID"
    end
    local cdTrace = EAM.Debug and EAM.Debug.CooldownTrace
    if cdTrace and cdTrace.record then
        cdTrace.record(eventName, spellID, nil, { unit = unit })
    end
    local result = CooldownService.activateSpell(spellID, eventName)
    if unit == "player" then
        if spellID == 30455 then
            -- 冰霜長矛施放：觸發地面效果（白化延長）與突發採樣器，零 Taint 風險
            local router = EAM.Modules and EAM.Modules.EventRouter
            if router and router.fire then
                router.fire("EAM_SHATTER_CONSUMED", 30455, 1)
            end
            if cdTrace and cdTrace.record then
                local activeCDs = cdTrace.snapshotActiveCooldowns and cdTrace.snapshotActiveCooldowns()
                cdTrace.record("CDR_TRIGGER_CAST", 30455, "冰霜長矛", {
                    activeCDs = activeCDs,
                })
            end
        end
        CooldownService.applyCombatHeuristicCDR(spellID)
        local refreshedCount = CooldownService.refreshActiveCooldowns(spellID)
        local hasActiveAlerts = (refreshedCount and refreshedCount > 0)
            or (result ~= nil and result.active and not result.completed and not result.isPlaceholder)
            or (next(CooldownService.activatedAlerts) ~= nil)
        if hasActiveAlerts then
            CooldownService.scheduleActiveCDRRetries()
            CooldownService.ensureActiveCDRSampler()
        end
    end
    return result
end

CooldownService.onSpellcastChannelStart = CooldownService.onSpellcastSucceeded

function CooldownService.onSpellcastChannelStop(eventName, unit, castGUID, spellID)
    if EAM.recordHotPath then
        EAM.recordHotPath("CooldownService.onSpellcastChannelStop")
    end
    if unit ~= "player" and unit ~= "pet" then
        return false, "notPlayerCast"
    end
    if not Util.isSafePositiveNumber(spellID) then
        return false, "invalidSpellID"
    end
    local cdTrace = EAM.Debug and EAM.Debug.CooldownTrace
    if cdTrace and cdTrace.record then
        cdTrace.record(eventName, spellID, nil, { unit = unit })
    end
    local refreshed = CooldownService.refreshSpell(spellID, eventName)
    if not refreshed and unit == "player" then
        refreshed = CooldownService.activateSpell(spellID, eventName)
    end
    if unit == "player" then
        local refreshedCount = CooldownService.refreshActiveCooldowns(spellID)
        local hasActiveAlerts = (refreshedCount and refreshedCount > 0)
            or (next(CooldownService.activatedAlerts) ~= nil)
        if hasActiveAlerts then
            CooldownService.scheduleActiveCDRRetries()
            CooldownService.ensureActiveCDRSampler()
        end
    end
    return refreshed ~= nil
end

function CooldownService.onCombatEvent(eventName)
    if eventName ~= "PLAYER_REGEN_ENABLED"
        and eventName ~= "PLAYER_REGEN_DISABLED"
    then
        return false, "ignoredEvent"
    end
    return refreshAll(eventName)
end

function CooldownService.onVisualTimerExpired(alertID)
    if not Util.isSafeTableKey(alertID) then
        return false, "invalidAlertID"
    end
    verifyAlertList()
    local state = CooldownService.states[alertID]
    local targetSpellID = state and state.spellID
    if not targetSpellID then
        for i = 1, alertCount do
            local a = alertList[i]
            if a and a.id == alertID then
                targetSpellID = a.spellID
                break
            end
        end
    end
    if not targetSpellID then
        return false, "notActive"
    end
    local refreshedState = CooldownService.refreshSpell(targetSpellID, "COOLDOWN_TIMER_EXPIRED")
    return (refreshedState ~= nil or state ~= nil), "refreshed"
end
function CooldownService.refreshAll(eventName)
    return refreshAll(eventName or "manual")
end
function CooldownService.onCooldownEvent(eventName, spellID, baseSpellID)
    if EAM.recordHotPath then
        EAM.recordHotPath("CooldownService.onCooldownEvent")
    end
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    if eventName == "SPELL_UPDATE_COOLDOWN" then
        local targetSpellID
        if Util.isSafePositiveNumber(spellID) then
            targetSpellID = spellID
        elseif Util.isSafePositiveNumber(baseSpellID) then
            targetSpellID = baseSpellID
        end
        if targetSpellID then
            local matched = CooldownService.refreshSpell(targetSpellID, eventName, baseSpellID)
            if matched ~= nil then
                CooldownService.refreshActiveCooldowns(targetSpellID)
                return true, "targeted"
            end
            -- 共用類別冷卻、覆蓋 ID 或尚未顯示過的警示不會被 targeted 路徑命中；改走合併全掃描。
        end
    end
    return queueCoalescedRefresh(eventName)
end
function CooldownService.onModuleToggle(enabled, reason)
    lastDbRevision = -1
    hasRefreshedThisTick = false
    needsTrailingRefresh = false
    if enabled == false then
        for alertID, state in pairs(CooldownService.states) do
            state.shown = false
            CooldownService.states[alertID] = nil
            fireStateChanged(state)
        end
        wipe(CooldownService.activatedAlerts)
        wipe(CooldownService.activationSpellIDs)
        wipe(CooldownService.activationEvents)
        wipe(CooldownService.chargeSpentObserved)
        wipe(CooldownService.baseToOverrideMap)
        wipe(CooldownService.overrideToBaseMap)
        wipe(CooldownService.previousOverrideMap)
        wipe(CooldownService.previousOverrideToBaseMap)
        CooldownService._activeCDRRetryPending = nil
        CooldownService._activeCDRToken = nil
        return true, "disabled"
    end
    -- 重新啟用不會把設定清單視為已施放；只刷新先前仍被保留的 activation。
    return refreshAll("MODULE_ENABLED_" .. tostring(reason or "manual"))
end