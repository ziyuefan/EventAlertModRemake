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
local alertCount = 0
local lastDbRevision = -1

function CooldownService.updateAlertList()
    alertCount = 0
    local savedVariables = EAM.Modules and EAM.Modules.SavedVariables
    local alerts = savedVariables and savedVariables.getActiveAlerts and savedVariables.getActiveAlerts() or nil
    if alerts and alerts.spellCooldowns then
        for _, alert in pairs(alerts.spellCooldowns) do
            alertCount = alertCount + 1
            alertList[alertCount] = alert
        end
    end
    -- Clean up subsequent slots if the list shrank
    for i = alertCount + 1, #alertList do
        alertList[i] = nil
    end
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

    -- 1. Check Charges first
    local isChargeBased = false
    local currentCharges, maxCharges
    local chargesInfo = nil
    local chargesSafe = false

    if cSpell.GetSpellCharges then
        chargesInfo = cSpell.GetSpellCharges(alert.spellID)
        if type(chargesInfo) == "table" and Util.canAccessTable(chargesInfo) then
            local cur, curSafe = Util.readSafeField(chargesInfo, "currentCharges", nil, "charges")
            local mx, mxSafe = Util.readSafeField(chargesInfo, "maxCharges", nil, "charges")

            if curSafe and mxSafe then
                currentCharges = cur
                maxCharges = mx
                isChargeBased = true
                chargesSafe = true
            else
                isChargeBased = true
                chargesSafe = false
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
    if isChargeBased then
        if chargesSafe then
            hasActiveCooldown = currentCharges ~= maxCharges
        else
            hasActiveCooldown = true
        end
    elseif cooldownInfo then
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
                local start, startSafe = Util.readSafeField(
                    chargesInfo,
                    "cooldownStartTime",
                    state.boundaryWarnings,
                    "charges"
                )
                local dur, durSafe = Util.readSafeField(
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
                        and cSpell.GetSpellChargeDuration(alert.spellID)
                        or nil
                else
                    setProtectedTimer(
                        state,
                        getDurationObject(cSpell.GetSpellChargeDuration, alert.spellID),
                        "chargeTimingProtected"
                    )
                end
            else
                setProtectedTimer(
                    state,
                    getDurationObject(cSpell.GetSpellChargeDuration, alert.spellID),
                    "chargeTimingUnavailable"
                )
            end
        else
            setProtectedTimer(
                state,
                getDurationObject(cSpell.GetSpellChargeDuration, alert.spellID),
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
    state.source.api = "C_Spell.GetSpellCooldown"
    state.source.activation = "UNIT_SPELLCAST_SUCCEEDED:player"
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
        router.register("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", function(_, overriddenSpellID, originalSpellID)
            if overriddenSpellID and not Util.isSecretValue(overriddenSpellID) then
                CooldownService.refreshSpell(overriddenSpellID, "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED")
            end
            if originalSpellID and not Util.isSecretValue(originalSpellID) then
                CooldownService.refreshSpell(originalSpellID, "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED")
            end
        end)
    end
end
function CooldownService.refreshSpell(spellID, eventName)
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

    local result
    for index = 1, alertCount do
        local alert = alertList[index]
        if alert
            and Util.isSafeTableKey(alert.id)
            and alert.spellID == spellID
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
    local result
    for index = 1, alertCount do
        local alert = alertList[index]
        if alert
            and Util.isSafeTableKey(alert.id)
            and alert.enabled ~= false
            and alert.spellID == spellID
        then
            CooldownService.activatedAlerts[alert.id] = true
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
        local hasTarget = false
        if Util.isSafePositiveNumber(spellID) then
            CooldownService.refreshSpell(spellID, eventName)
            hasTarget = true
        end
        if Util.isSafePositiveNumber(baseSpellID)
            and (not Util.isSafePositiveNumber(spellID) or baseSpellID ~= spellID)
        then
            CooldownService.refreshSpell(baseSpellID, eventName)
            hasTarget = true
        end
        if hasTarget then
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
        return true, "disabled"
    end
    -- 重新啟用不會把設定清單視為已施放；只刷新先前仍被保留的 activation。
    return refreshAll("MODULE_ENABLED_" .. tostring(reason or "manual"))
end