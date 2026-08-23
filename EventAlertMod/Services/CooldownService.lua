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

local CooldownService = {
    states = {},
    -- 只有玩家 UNIT_SPELLCAST_SUCCEEDED 精確命中已啟用警示時才開啟。
    activatedAlerts = {},
    -- 保存本輪實際施放 ID，避免 base/override 家族在後續充能事件查錯成員。
    activationSpellIDs = {},
    -- 完成移除前，必須先安全觀察到本輪至少消耗一層充能。
    chargeSpentObserved = {},
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
        return nil, nil
    end
    local cSpell = api.C_Spell
    local baseSpellID = cSpell
        and resolveSpellIdentifier(cSpell.GetBaseSpell, spellID)
        or nil
    baseSpellID = baseSpellID or spellID

    local overrideSpellID = cSpell
        and resolveSpellIdentifier(cSpell.GetOverrideSpell, baseSpellID)
        or nil
    if not overrideSpellID and baseSpellID ~= spellID and cSpell then
        overrideSpellID = resolveSpellIdentifier(cSpell.GetOverrideSpell, spellID)
    end
    return baseSpellID, overrideSpellID or baseSpellID
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

    local baseSpellID, overrideSpellID = resolveSpellFamily(spellID)
    if overrideSpellID ~= preferredSpellID then
        chargesInfo, selectedSpellID = readChargeCandidate(cSpell, overrideSpellID)
        if chargesInfo then
            return chargesInfo, selectedSpellID
        end
    end
    if baseSpellID ~= preferredSpellID and baseSpellID ~= overrideSpellID then
        chargesInfo, selectedSpellID = readChargeCandidate(cSpell, baseSpellID)
        if chargesInfo then
            return chargesInfo, selectedSpellID
        end
    end
    if spellID ~= preferredSpellID and spellID ~= overrideSpellID and spellID ~= baseSpellID then
        chargesInfo, selectedSpellID = readChargeCandidate(cSpell, spellID)
        if chargesInfo then
            return chargesInfo, selectedSpellID
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
}

local function isInCombat()
    return type(api.InCombatLockdown) == "function"
        and api.InCombatLockdown() == true
end

local function resolveBehavior(alert, key)
    local override
    if type(alert) == "table" then
        override = alert[key]
    end
    if type(override) == "boolean" then
        return override
    end
    local config = EAM.db and EAM.db.config
    local globalValue = type(config) == "table" and config[key] or nil
    if type(globalValue) == "boolean" then
        return globalValue
    end
    return COOLDOWN_BEHAVIOR_DEFAULTS[key]
end

local function fireStateChanged(state)
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router and state then
        router.fire(
            "EAM_COOLDOWN_STATE_CHANGED",
            state,
            EAM.Constants.ALERT_FRAME_TYPES.spellCooldown
        )
    end
end

local function setStateHidden(alertID, state, clearActivation)
    if clearActivation then
        CooldownService.activatedAlerts[alertID] = nil
        CooldownService.activationSpellIDs[alertID] = nil
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
    state.cooldownRemoveAura = nil
    state.showSCDOutsideCombat = nil
    state.glowSCDWhenUsable = nil
    state.boundaryLimited = false
    state.releaseFunc = nil
    wipe(state.boundaryWarnings)
    wipe(state.timer)
    wipe(state.source)
    
    CooldownStatePool.binSize = CooldownStatePool.binSize + 1
    CooldownStatePool.recycleBin[CooldownStatePool.binSize] = state
end

-- Performance Optimizations: Array pre-allocation and revision tracking
local alertList = Util.tableCreate(32, 0)
local alertBaseSpellIDs = Util.tableCreate(32, 0)
local alertOverrideSpellIDs = Util.tableCreate(32, 0)
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
            local baseSpellID, overrideSpellID = resolveSpellFamily(alert and alert.spellID)
            alertBaseSpellIDs[alertCount] = baseSpellID
            alertOverrideSpellIDs[alertCount] = overrideSpellID
        end
    end
    -- Clean up subsequent slots if the list shrank.
    for index = alertCount + 1, previousCount do
        alertList[index] = nil
        alertBaseSpellIDs[index] = nil
        alertOverrideSpellIDs[index] = nil
    end
end

local function alertMatchesSpellFamily(index, spellID, baseSpellID, overrideSpellID)
    local alert = alertList[index]
    local alertSpellID = alert and alert.spellID or nil
    local alertBaseSpellID = alertBaseSpellIDs[index]
    local alertOverrideSpellID = alertOverrideSpellIDs[index]
    return sameSpellID(alertSpellID, spellID)
        or sameSpellID(alertSpellID, baseSpellID)
        or sameSpellID(alertSpellID, overrideSpellID)
        or sameSpellID(alertBaseSpellID, spellID)
        or sameSpellID(alertBaseSpellID, baseSpellID)
        or sameSpellID(alertBaseSpellID, overrideSpellID)
        or sameSpellID(alertOverrideSpellID, spellID)
        or sameSpellID(alertOverrideSpellID, baseSpellID)
        or sameSpellID(alertOverrideSpellID, overrideSpellID)
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

local function refreshAlert(alert, eventName)
    local alertID = type(alert) == "table" and alert.id or nil
    local oldState = alertID and CooldownService.states[alertID] or nil
    if not Util.isSafeTableKey(alertID) then
        return nil
    end

    if alert.enabled == false or not Util.isSafePositiveNumber(alert.spellID) then
        return setStateHidden(alertID, oldState, true)
    end

    -- refreshAll、設定變更與一般 cooldown event 只更新已開啟的警示。
    if CooldownService.activatedAlerts[alertID] ~= true then
        if oldState then
            return setStateHidden(alertID, oldState, true)
        end
        return nil
    end

    local cSpell = api.C_Spell
    if not cSpell then
        return setStateHidden(alertID, oldState, false)
    end

    local behaviorRemove = resolveBehavior(alert, "cooldownRemoveAura")
    local behaviorOutside = resolveBehavior(alert, "showSCDOutsideCombat")
    local behaviorGlow = resolveBehavior(alert, "glowSCDWhenUsable")
    local visibleNow = behaviorOutside or isInCombat()

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
    local cooldownInfo = cSpell.GetSpellCooldown and cSpell.GetSpellCooldown(alert.spellID) or nil
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

    local shouldShow = hasActiveCooldown
    if not visibleNow then
        shouldShow = false
    elseif not hasActiveCooldown and not behaviorRemove then
        -- 第一次施放後，完成狀態仍可依設定保留圖示。
        shouldShow = true
    end

    if not shouldShow then
        return setStateHidden(alertID, oldState, false)
    end

    -- 4. Allocate state only after the spell has been activated by the player.
    local state = oldState
    if not state then
        state = CooldownStatePool.acquire()
        CooldownService.states[alertID] = state
    end

    state.id = alertID
    state.kind = EAM.Constants.ALERT_KIND_SPELL_COOLDOWN
    state.spellID = alert.spellID
    state.name = nil
    state.icon = nil
    state.charges = isChargeBased and currentCharges or nil
    state.maxCharges = isChargeBased and maxCharges or nil
    state.chargeSpellID = isChargeBased and chargeSpellID or nil
    state.isChargeBased = isChargeBased
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
    state.usableGlow = state.completed and behaviorGlow or false
    state.cooldownRemoveAura = behaviorRemove
    state.showSCDOutsideCombat = behaviorOutside
    state.glowSCDWhenUsable = behaviorGlow
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

    -- 5. Populate TimerState. Completed states deliberately clear old timing.
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
                    state.timer.durationObject = cSpell.GetSpellChargeDuration
                        and cSpell.GetSpellChargeDuration(chargeSpellID or alert.spellID)
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
        state.timer.durationObject = cSpell.GetSpellCooldownDuration
            and cSpell.GetSpellCooldownDuration(alert.spellID, true)
            or nil
    else
        setProtectedTimer(
            state,
            getDurationObject(cSpell.GetSpellCooldownDuration, alert.spellID, true),
            "timingProtected"
        )
    end

    state.source.event = eventName
    state.source.api = isChargeBased and "C_Spell.GetSpellCharges" or "C_Spell.GetSpellCooldown"
    state.source.activation = "UNIT_SPELLCAST_SUCCEEDED:player"
    state.source.activationSpellID = CooldownService.activationSpellIDs[alertID]
    state.source.chargeSpellID = chargeSpellID
    state.source.updatedAt = api.GetTime and api.GetTime() or 0

    return state
end
local function cleanupDeletedAlerts()
    local present = {}
    for index = 1, alertCount do
        local alert = alertList[index]
        if alert and Util.isSafeTableKey(alert.id) then
            present[alert.id] = true
        end
    end

    for alertID in pairs(CooldownService.activatedAlerts) do
        if not present[alertID] then
            CooldownService.activatedAlerts[alertID] = nil
            CooldownService.activationSpellIDs[alertID] = nil
            CooldownService.chargeSpentObserved[alertID] = nil
        end
    end
    for alertID, state in pairs(CooldownService.states) do
        if not present[alertID] then
            local hidden = setStateHidden(alertID, state, true)
            fireStateChanged(hidden)
        end
    end
end

local function refreshAll(eventName)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    verifyAlertList()
    cleanupDeletedAlerts()
    if alertCount == 0 then
        return true, "empty"
    end

    for index = 1, alertCount do
        local alert = alertList[index]
        local state = refreshAlert(alert, eventName)
        if state then
            fireStateChanged(state)
        end
    end
    return true, "updated"
end
function CooldownService.initialize()
    CooldownStatePool.initialize()
    local router = EAM.Modules.EventRouter
    if router then
        router.register("SPELL_UPDATE_COOLDOWN", CooldownService.onCooldownEvent)
        router.register("SPELL_UPDATE_CHARGES", CooldownService.onCooldownEvent)
        router.register("UNIT_SPELLCAST_SUCCEEDED", CooldownService.onSpellcastSucceeded)
        router.register("PLAYER_REGEN_ENABLED", CooldownService.onCombatEvent)
        router.register("PLAYER_REGEN_DISABLED", CooldownService.onCombatEvent)
        router.register("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", function(eventName, overriddenSpellID, originalSpellID)
            CooldownService.updateAlertList()
            if EAM.db then
                lastDbRevision = EAM.db.revision or 0
            end
            local targetSpellID
            if Util.isSafePositiveNumber(overriddenSpellID) then
                targetSpellID = overriddenSpellID
            elseif Util.isSafePositiveNumber(originalSpellID) then
                targetSpellID = originalSpellID
            end
            if targetSpellID then
                CooldownService.refreshSpell(targetSpellID, eventName, originalSpellID)
            end
        end)
    end
end

local function resolveEventSpellFamily(spellID, suppliedBaseSpellID)
    local baseSpellID, overrideSpellID = resolveSpellFamily(spellID)
    if Util.isSafePositiveNumber(suppliedBaseSpellID) then
        baseSpellID = suppliedBaseSpellID
        local _, suppliedOverrideSpellID = resolveSpellFamily(suppliedBaseSpellID)
        if Util.isSafePositiveNumber(suppliedOverrideSpellID) then
            overrideSpellID = suppliedOverrideSpellID
        end
    end
    return baseSpellID, overrideSpellID
end

function CooldownService.refreshSpell(spellID, eventName, suppliedBaseSpellID)
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
            local state = refreshAlert(alert, eventName or "manual")
            if state then
                fireStateChanged(state)
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
    local baseSpellID, overrideSpellID = resolveEventSpellFamily(spellID)
    local result
    for index = 1, alertCount do
        local alert = alertList[index]
        if alert
            and Util.isSafeTableKey(alert.id)
            and alert.enabled ~= false
            and alertMatchesSpellFamily(index, spellID, baseSpellID, overrideSpellID)
        then
            CooldownService.activatedAlerts[alert.id] = true
            CooldownService.activationSpellIDs[alert.id] = spellID
            CooldownService.chargeSpentObserved[alert.id] = nil
            local state = refreshAlert(alert, eventName or "UNIT_SPELLCAST_SUCCEEDED")
            if state then
                fireStateChanged(state)
                result = state
            end
        end
    end
    return result
end

function CooldownService.onSpellcastSucceeded(eventName, unit, castGUID, spellID)
    if eventName ~= "UNIT_SPELLCAST_SUCCEEDED" or unit ~= "player" then
        return false, "notPlayerCast"
    end
    if not Util.isSafePositiveNumber(spellID) then
        return false, "invalidSpellID"
    end
    return CooldownService.activateSpell(spellID, eventName)
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
    if not state then
        return false, "notActive"
    end
    return CooldownService.refreshSpell(state.spellID, "COOLDOWN_TIMER_EXPIRED") ~= nil,
        "refreshed"
end
function CooldownService.refreshAll(eventName)
    return refreshAll(eventName or "manual")
end
function CooldownService.onCooldownEvent(eventName, spellID, baseSpellID)
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
            CooldownService.refreshSpell(targetSpellID, eventName, baseSpellID)
            return true, "targeted"
        end
    end
    return refreshAll(eventName)
end
function CooldownService.onModuleToggle(enabled, reason)
    lastDbRevision = -1
    if enabled == false then
        local router = EAM.Modules.EventRouter
        for alertID, state in pairs(CooldownService.states) do
            state.shown = false
            CooldownService.states[alertID] = nil
            fireStateChanged(state)
        end
        wipe(CooldownService.activatedAlerts)
        wipe(CooldownService.activationSpellIDs)
        wipe(CooldownService.chargeSpentObserved)
        return true, "disabled"
    end
    -- 重新啟用不會把設定清單視為已施放；只刷新先前仍被保留的 activation。
    return refreshAll("MODULE_ENABLED_" .. tostring(reason or "manual"))
end