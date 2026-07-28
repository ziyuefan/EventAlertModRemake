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

local frame = api.CreateFrame and api.CreateFrame("Frame", nil, nil)
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
