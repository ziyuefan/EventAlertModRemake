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

local CooldownService = {
    states = {},
}

EAM.Services.CooldownService = CooldownService

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
    if EAM.db and EAM.db.alerts and EAM.db.alerts.spellCooldowns then
        for _, alert in pairs(EAM.db.alerts.spellCooldowns) do
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
    local oldState = CooldownService.states[alert.id]
    
    if alert.enabled == false or not alert.spellID then
        if oldState then
            oldState.shown = false
            CooldownService.states[alert.id] = nil
            return oldState
        end
        return nil
    end

    local cSpell = api.C_Spell
    if not cSpell then
        if oldState then
            oldState.shown = false
            CooldownService.states[alert.id] = nil
            return oldState
        end
        return nil
    end

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

    -- 3. Determine show status prior to allocating table (O(1) filtering)
    local shouldShow = false
    if isChargeBased then
        if chargesSafe then
            if currentCharges ~= maxCharges then
                shouldShow = true
            end
        else
            -- 存在 Charges 資訊但無法安全讀取（可能是 Secret）
            shouldShow = true
        end
    else
        if cooldownInfo then
            if infoSafe then
                if type(startTime) == "number" and type(duration) == "number" and duration > 0 and isEnabled ~= false and isOnGCD ~= true then
                    shouldShow = true
                end
            else
                -- 存在 cooldown 資訊但無法安全讀取（可能是 Secret）
                shouldShow = true
            end
        end
    end

    if not shouldShow then
        if oldState then
            oldState.shown = false
            CooldownService.states[alert.id] = nil
            return oldState
        end
        return nil
    end

    -- 4. Allocate state from pool if shown is true and no old state exists
    local state = oldState
    if not state then
        state = CooldownStatePool.acquire()
        CooldownService.states[alert.id] = state
    end

    state.id = alert.id
    state.kind = EAM.Constants.ALERT_KIND_SPELL_COOLDOWN
    state.spellID = alert.spellID
    state.name = nil
    state.icon = nil
    state.charges = isChargeBased and currentCharges or nil
    state.maxCharges = isChargeBased and maxCharges or nil
    state.factsSafe = true
    state.active = true
    state.shown = true
    state.boundaryLimited = false
    wipe(state.boundaryWarnings)

    -- Spell Info lookup (name, icon)
    if SpellInfoService then
        local spellInfo = SpellInfoService.getSpellInfo(alert.spellID)
        if spellInfo then
            state.name = spellInfo.name or (tostring(alert.spellID))
            state.icon = spellInfo.icon
        else
            state.name = tostring(alert.spellID)
        end
    else
        state.name = tostring(alert.spellID)
    end

    -- 5. Determine active state and populate TimerState with Service-Layer Write Gating
    if isChargeBased then
        if chargesSafe then
            if chargesInfo then
                local start, startSafe = Util.readSafeField(chargesInfo, "cooldownStartTime", state.boundaryWarnings, "charges")
                local dur, durSafe = Util.readSafeField(chargesInfo, "cooldownDuration", state.boundaryWarnings, "charges")

                if startSafe and durSafe and Util.isSafeNumber(start) and Util.isSafePositiveNumber(dur) then
                    state.factsSafe = true
                    
                    if state.timer.startTime ~= start or state.timer.duration ~= dur or state.timer.mode ~= EAM.Constants.TIMER_NUMERIC then
                        state.timer.mode = EAM.Constants.TIMER_NUMERIC
                        state.timer.startTime = start
                        state.timer.duration = dur
                        state.timer.expirationTime = start + dur
                        state.timer.durationObject = cSpell.GetSpellChargeDuration and cSpell.GetSpellChargeDuration(alert.spellID) or nil
                    end
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
    else
        if infoSafe and type(startTime) == "number" and type(duration) == "number" then
            if state.timer.startTime ~= startTime or state.timer.duration ~= duration or state.timer.mode ~= EAM.Constants.TIMER_NUMERIC then
                state.timer.mode = EAM.Constants.TIMER_NUMERIC
                state.timer.startTime = startTime
                state.timer.duration = duration
                state.timer.expirationTime = startTime + duration
                state.timer.durationObject = cSpell.GetSpellCooldownDuration and cSpell.GetSpellCooldownDuration(alert.spellID, true) or nil
            end
        else
            setProtectedTimer(
                state,
                getDurationObject(cSpell.GetSpellCooldownDuration, alert.spellID, true),
                "timingProtected"
            )
        end
    end

    state.source.event = eventName
    state.source.api = "C_Spell.GetSpellCooldown"
    state.source.updatedAt = api.GetTime and api.GetTime() or 0

    return state
end

local function refreshAll(eventName)
    verifyAlertList()
    if alertCount == 0 then
        return
    end

    for i = 1, alertCount do
        local alert = alertList[i]
        local state = refreshAlert(alert, eventName)
        if state then
            local router = EAM.Modules.EventRouter
            if router then
                router.fire("EAM_COOLDOWN_STATE_CHANGED", state, EAM.Constants.ALERT_FRAME_TYPES.spellCooldown)
            end
        end
    end
end

function CooldownService.initialize()
    CooldownStatePool.initialize()
    local router = EAM.Modules.EventRouter
    if router then
        router.register("SPELL_UPDATE_COOLDOWN", CooldownService.onCooldownEvent)
        router.register("SPELL_UPDATE_CHARGES", CooldownService.onCooldownEvent)
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
    verifyAlertList()
    if alertCount == 0 then
        return nil
    end

    for i = 1, alertCount do
        local alert = alertList[i]
        if alert.spellID == spellID then
            local state = refreshAlert(alert, eventName or "manual")
            if state then
                local router = EAM.Modules.EventRouter
                if router then
                    router.fire("EAM_COOLDOWN_STATE_CHANGED", state, EAM.Constants.ALERT_FRAME_TYPES.spellCooldown)
                end
                return state
            end
        end
    end
    return nil
end

function CooldownService.refreshAll(eventName)
    refreshAll(eventName or "manual")
end

function CooldownService.onCooldownEvent(eventName, spellID, baseSpellID)
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
            return
        end
    end
    refreshAll(eventName)
end
