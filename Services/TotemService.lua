--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/TotemService
檔案: Services\TotemService.lua

理念:
- 作為圖騰（主要是薩滿的 4 大圖騰插槽）的事實監控層。
- 使用 12.x 全域 GetTotemInfo 與 GetTotemDuration API 取得圖騰事實與原生時間物件。
- 當圖騰插槽更新時，即時渲染至獨立的 totem 告警框架中，並遵循選定的成長方向。

責任:
- 監聽 PLAYER_TOTEM_UPDATE 與 PLAYER_ENTERING_WORLD 事件。
- 逐一掃描 4 個圖騰插槽，獲取圖騰圖示、持續時間與開始時間。
- 分發 state 到 Renderer 的 totem 告警框架中，並支持 12.x 原生 DurationObject 倒數。

資料所有權:
- 擁有圖騰插槽的快取與更新狀態。

可變狀態:
- 無全域配置，只反映當前實時插槽事實。

效能注意:
- 事件觸發時，只執行 1 到 4 的簡單數字迴圈，完全無 garbage 產生。

]]
local _, EAM = ...

local api = EAM.API
local Util = EAM.Util
local DurationAdapter = EAM.Modules.DurationAdapter
local TotemStatePool = nil

local TotemService = {
    activeStates = {}, -- [slot] = state
}

EAM.Services.TotemService = TotemService

-- 低 GC 的 TotemState 物件快取池
TotemStatePool = {
    recycleBin = {},
    binSize = 0,
}

TotemService.TotemStatePool = TotemStatePool

function TotemStatePool.initialize()
    -- 預先建立 4 個 TotemState 對象備用
    for i = 1, 4 do
        local state = Util.tableCreate(0, 16)
        state.boundaryWarnings = Util.tableCreate(2, 0)
        state.timer = Util.tableCreate(0, 4)
        TotemStatePool.recycleBin[i] = state
    end
    TotemStatePool.binSize = 4
end

function TotemStatePool.acquire()
    local state
    if TotemStatePool.binSize > 0 then
        state = TotemStatePool.recycleBin[TotemStatePool.binSize]
        TotemStatePool.recycleBin[TotemStatePool.binSize] = nil
        TotemStatePool.binSize = TotemStatePool.binSize - 1
    else
        state = Util.tableCreate(0, 16)
        state.boundaryWarnings = Util.tableCreate(2, 0)
        state.timer = Util.tableCreate(0, 4)
    end
    state.releaseFunc = TotemStatePool.release
    return state
end

function TotemStatePool.release(state)
    if not state then return end
    
    state.id = nil
    state.kind = nil
    state.spellID = nil
    state.name = nil
    state.icon = nil
    state.stacks = nil
    state.active = false
    state.shown = false
    state.factsSafe = false
    state.boundaryLimited = false
    state.releaseFunc = nil
    wipe(state.boundaryWarnings)
    wipe(state.timer)
    
    TotemStatePool.binSize = TotemStatePool.binSize + 1
    TotemStatePool.recycleBin[TotemStatePool.binSize] = state
end

local function triggerState(state)
    local router = EAM.Modules.EventRouter
    if router then
        router.trigger("EAM_TOTEM_STATE_CHANGED", state, EAM.Constants.ALERT_FRAME_TYPES.totem)
    end
end

local function applyNativeDuration(slot, state)
    if type(api.GetTotemDuration) ~= "function" then
        return false
    end
    local ok, durationObject = pcall(api.GetTotemDuration, slot)
    if not ok then
        return false
    end
    state.timer.durationObject = durationObject
    return true
end

local function preserveBoundaryState(slot, code)
    local state = TotemService.activeStates[slot]
    if not state then
        return
    end
    state.factsSafe = false
    wipe(state.boundaryWarnings)
    Util.clearTimer(state.timer, EAM.Constants.TIMER_PROTECTED)
    if applyNativeDuration(slot, state) then
        state.timer.mode = EAM.Constants.TIMER_DISPLAY_ONLY
    end
    Util.markBoundary(state, "totem", code)
    triggerState(state)
end

-- 刷新單個圖騰插槽狀態
function TotemService.refreshSlot(slot)
    if type(api.GetTotemInfo) ~= "function" then
        return
    end

    local ok, haveTotem, name, startTime, duration, icon = pcall(api.GetTotemInfo, slot)
    if not ok or not Util.isSafeBoolean(haveTotem) then
        preserveBoundaryState(slot, "slotSecret")
        return
    end

    if haveTotem == true then
        if not Util.isSafeString(name) or name == "" then
            preserveBoundaryState(slot, "identitySecret")
            return
        end

        local timingFieldsSafe = Util.isSafeNumber(startTime) and Util.isSafeNumber(duration)
        local hasDuration = timingFieldsSafe and Util.isSafePositiveNumber(duration)
        local state = TotemService.activeStates[slot]
        
        if state then
            -- 覆蓋現有屬性
            state.name = name
            if Util.isSafePositiveNumber(icon) then
                state.icon = icon
            end
        else
            state = TotemStatePool.acquire()
            state.id = "totem_" .. slot
            state.kind = "totem"
            state.spellID = slot -- 使用 slot 作為區分 ID
            state.name = name
            state.icon = Util.isSafePositiveNumber(icon) and icon or 136243
            state.stacks = 0
            state.active = true
            state.shown = true
            
            TotemService.activeStates[slot] = state
        end

        state.factsSafe = timingFieldsSafe
        state.boundaryLimited = false
        wipe(state.boundaryWarnings)
        if hasDuration then
            Util.clearTimer(state.timer, EAM.Constants.TIMER_NUMERIC)
            state.timer.startTime = startTime
            state.timer.duration = duration
            state.timer.expirationTime = startTime + duration
            if not applyNativeDuration(slot, state) and DurationAdapter then
                state.timer.durationObject = DurationAdapter.createFromStart(startTime, duration)
            end
        elseif timingFieldsSafe then
            Util.clearTimer(state.timer, EAM.Constants.TIMER_NONE)
        else
            Util.clearTimer(state.timer, EAM.Constants.TIMER_PROTECTED)
            if applyNativeDuration(slot, state) then
                state.timer.mode = EAM.Constants.TIMER_DISPLAY_ONLY
            end
            Util.markBoundary(state, "totem", "timingProtected")
        end
        triggerState(state)
    else
        -- 釋放此插槽圖示
        local state = TotemService.activeStates[slot]
        if state then
            state.shown = false
            
            triggerState(state)
            
            TotemService.activeStates[slot] = nil
        end
    end
end

-- 掃描所有圖騰插槽
function TotemService.scanAll()
    for slot = 1, 4 do
        TotemService.refreshSlot(slot)
    end
end

-- 事件接收器
function TotemService.onEvent(event, slot)
    if event == "PLAYER_TOTEM_UPDATE" and slot then
        TotemService.refreshSlot(slot)
    else
        TotemService.scanAll()
    end
end

function TotemService.initialize()
    TotemStatePool.initialize()

    local router = EAM.Modules.EventRouter
    if router then
        router.register("PLAYER_TOTEM_UPDATE", TotemService.onEvent)
        router.register("PLAYER_ENTERING_WORLD", TotemService.onEvent)
    end
end

