--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Core/Scheduler
檔案: Core\Scheduler.lua

理念:
- 提供唯一 OnUpdate scheduler，取代 timer-per-icon/timer-per-spell。
- 所有 fallback tick 都集中排程，方便節流與除錯。

責任:
- 擁有 scheduler frame、due job queue 與 OnUpdate dispatch。

資料所有權:
- 擁有 Scheduler.tasks 與 task records。

可變狀態:
- 可 mutate due queue；不可直接 mutate aura/cooldown facts 或 UI frame。

邊界:
- 不使用 C_Timer.After(function() ...) 作為熱路徑模式。
- 不自行讀取資料來源 API。

效能注意:
- 使用 numeric loop 與 swap-remove；空 queue 時移除 OnUpdate。
- 使用 task pool，避免每次 Scheduler.after 建立新 table。

Retail API 注意:
- 戰鬥/低 FPS 節流需與 Core/Performance 整合。

]]
local _, EAM = ...

local api = EAM.API
local Util = EAM.Util
local Scheduler = {
    tasks = Util.tableCreate(16, 0),
    taskPool = { count = 0 },
    count = 0,
}

EAM.Modules.Scheduler = Scheduler

local frame = (Util and Util.createFrame and Util.createFrame("Frame", nil, nil)) or (api.CreateFrame and api.CreateFrame("Frame", nil, nil))
Scheduler.frame = frame

local function acquireTask()
    local pool = Scheduler.taskPool
    local count = pool.count or 0
    if count > 0 then
        local task = pool[count]
        pool[count] = nil
        pool.count = count - 1
        return task
    end

    return {}
end

local function releaseTask(task)
    if not task then
        return
    end

    task.dueAt = nil
    task.callback = nil
    task.owner = nil
    local pool = Scheduler.taskPool
    local count = (pool.count or 0) + 1
    pool[count] = task
    pool.count = count
end

local function onUpdate()
    if EAM.recordHotPath then
        EAM.recordHotPath("Scheduler.onUpdate")
    end
    local now = api.GetTime and api.GetTime() or 0
    local index = 1

    while index <= Scheduler.count do
        local task = Scheduler.tasks[index]
        if task and task.dueAt <= now then
            local callback = task.callback
            local owner = task.owner
            Scheduler.tasks[index] = Scheduler.tasks[Scheduler.count]
            Scheduler.tasks[Scheduler.count] = nil
            Scheduler.count = Scheduler.count - 1
            releaseTask(task)
            
            local ok, err = pcall(callback, owner)
            if not ok then
                print("|cffff0000EAM Scheduler Error|r: " .. tostring(err))
            end
        else
            index = index + 1
        end
    end

    if Scheduler.count == 0 and frame then
        frame:SetScript("OnUpdate", nil)
    end
end

function Scheduler.after(delay, callback, owner)
    if EAM.recordHotPath then
        EAM.recordHotPath("Scheduler.after")
    end
    if not callback then
        return false, "callbackUnavailable"
    end

    if delay == nil then
        delay = 0
    elseif not Util.isSafeNonNegativeNumber(delay) then
        return false, "unsafeDelay"
    end

    local count = Scheduler.count + 1
    local task = acquireTask()
    task.dueAt = (api.GetTime and api.GetTime() or 0) + delay
    task.callback = callback
    task.owner = owner
    Scheduler.tasks[count] = task
    Scheduler.count = count

    if frame then
        frame:SetScript("OnUpdate", onUpdate)
    end
    return true
end

-- ============================================================================
-- 12.1.5 TimedSignalMap: Zero-allocation key-based timer rescheduling
-- ============================================================================

Scheduler.nativeSignalMapCount = 0

local function createFallbackSignalMap(callback)
    local signals = {}
    local activeToken = 0
    local currentDueAt = nil

    local map = {}

    local function onSignalCheck(token)
        if token ~= activeToken then
            return
        end
        if EAM.recordHotPath then
            EAM.recordHotPath("Scheduler.signalMapCheck")
        end
        currentDueAt = nil
        local now = api.GetTime and api.GetTime() or 0
        local expiredList = nil

        for key, dueAt in pairs(signals) do
            if dueAt <= now then
                expiredList = expiredList or {}
                expiredList[#expiredList + 1] = key
            end
        end

        if expiredList then
            for i = 1, #expiredList do
                local k = expiredList[i]
                signals[k] = nil
                local ok, err = pcall(callback, k)
                if not ok then
                    print("|cffff0000EAM SignalMap Error|r: " .. tostring(err))
                end
            end
        end

        -- If a callback rescheduled or cleared signals, activeToken will have changed
        if token ~= activeToken then
            return
        end

        local nextMin = nil
        for _, dueAt in pairs(signals) do
            if not nextMin or dueAt < nextMin then
                nextMin = dueAt
            end
        end

        if nextMin then
            activeToken = activeToken + 1
            currentDueAt = nextMin
            local delay = math.max(0.001, nextMin - (api.GetTime and api.GetTime() or 0))
            Scheduler.after(delay, onSignalCheck, activeToken)
        end
    end

    function map:SignalAt(key, targetTime)
        if key == nil or not Util.isSafeNumber(targetTime) then
            return false, "invalidSignalAt"
        end
        signals[key] = targetTime
        local now = api.GetTime and api.GetTime() or 0
        if not currentDueAt or targetTime < currentDueAt then
            activeToken = activeToken + 1
            currentDueAt = targetTime
            local delay = math.max(0, targetTime - now)
            Scheduler.after(delay, onSignalCheck, activeToken)
        end
        return true
    end

    function map:SignalAfter(key, delay)
        if key == nil or not Util.isSafeNonNegativeNumber(delay) then
            return false, "invalidSignalAfter"
        end
        local now = api.GetTime and api.GetTime() or 0
        return self:SignalAt(key, now + delay)
    end

    function map:Cancel(key)
        if key ~= nil then
            signals[key] = nil
        end
        return true
    end

    function map:Clear()
        for k in pairs(signals) do
            signals[k] = nil
        end
        activeToken = activeToken + 1
        currentDueAt = nil
        return true
    end

    function map:IsNative()
        return false
    end

    return map
end

Scheduler.createFallbackSignalMap = createFallbackSignalMap

function Scheduler.hasNativeSignalMap()
    local cTimer = api.C_Timer or _G.C_Timer
    return (cTimer and type(cTimer.NewTimedSignalMap) == "function")
        or type(_G.TimedSignalMap) == "function"
end

function Scheduler.createSignalMap(callback)
    if type(callback) ~= "function" then
        return nil, "callbackRequired"
    end

    local cTimer = api.C_Timer or _G.C_Timer
    local newSignalMap = (cTimer and cTimer.NewTimedSignalMap) or _G.TimedSignalMap
    if type(newSignalMap) == "function" then
        local ok, nativeMap = pcall(newSignalMap, callback)
        if ok and nativeMap then
            Scheduler.nativeSignalMapCount = Scheduler.nativeSignalMapCount + 1
            if not nativeMap.SignalAfter then
                nativeMap.SignalAfter = function(self, key, delay)
                    local now = api.GetTime and api.GetTime() or 0
                    return self:SignalAt(key, now + (delay or 0))
                end
            end
            if not nativeMap.IsNative then
                nativeMap.IsNative = function() return true end
            end
            return nativeMap
        end
    end

    return createFallbackSignalMap(callback)
end
