--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Core/EventRouter
檔案: Core\EventRouter.lua

理念:
- 所有 Blizzard events 由單一孤兒 frame 接收，避免事件 frame 分散。
- 模組只註冊 handler，不自行管理 RegisterEvent churn。

責任:
- 擁有事件 frame、event->handler list、OnEvent dispatch。

資料所有權:
- 擁有 EventRouter.handlers 與事件 frame。

可變狀態:
- 可 mutate handler list；不可 mutate service state 或 SavedVariables。

邊界:
- 不讀 aura/cooldown API。
- 不建立 UI icon。
- 不使用 RegisterAllEvents。

效能注意:
- dispatch 使用 numeric loop；註冊表穩定後避免熱路徑配置。
- OnEvent 內不做字串組合或大型 table 建立。

Retail API 注意:
- 事件 frame 使用 CreateFrame("Frame", nil, nil) 作為 orphan frame，降低 UIParent 戰鬥保護風險。

]]
local _, EAM = ...

local api = EAM.API
local EventRouter = {
    handlers = {},
}

EAM.Modules.EventRouter = EventRouter

local frame = api.CreateFrame and api.CreateFrame("Frame", nil, nil)
EventRouter.frame = frame

local function onEvent(_, event, ...)
    if EAM.addDebugLog and event ~= "UNIT_POWER_FREQUENT" and event ~= "UNIT_POWER_UPDATE" then
        EAM.addDebugLog("EventRouter", "onEvent", "WoW event fired: " .. tostring(event))
    end
    local handlers = EventRouter.handlers[event]
    if not handlers then
        return
    end

    local count = handlers.count or 0
    for index = 1, count do
        local ok, err = pcall(handlers[index], event, ...)
        if not ok then
            print("|cffff0000EAM Event Error|r on [" .. tostring(event) .. "]: " .. tostring(err))
        end
    end
end

function EventRouter.register(event, handler)
    if not event or not handler then
        return
    end

    local handlers = EventRouter.handlers[event]
    if not handlers then
        handlers = { count = 0 }
        EventRouter.handlers[event] = handlers
        if frame then
            local isCustom = string.sub(event, 1, 4) == "EAM_"
            if not isCustom then
                frame:RegisterEvent(event)
            end
            if EAM.addDebugLog then
                EAM.addDebugLog("EventRouter", "register", "Registered " .. (isCustom and "custom" or "frame") .. " event: " .. tostring(event))
            end
        end
    end

    local count = handlers.count + 1
    handlers[count] = handler
    handlers.count = count
end

function EventRouter.unregister(event, handler)
    if not event or not handler then
        return false
    end

    local handlers = EventRouter.handlers[event]
    local count = handlers and handlers.count or 0
    for index = 1, count do
        if handlers[index] == handler then
            handlers[index] = handlers[count]
            handlers[count] = nil
            handlers.count = count - 1

            if handlers.count == 0 then
                EventRouter.handlers[event] = nil
                local isCustom = string.sub(event, 1, 4) == "EAM_"
                if frame and not isCustom then
                    frame:UnregisterEvent(event)
                end
            end
            return true
        end
    end

    return false
end

-- 派發自訂事件
function EventRouter.fire(event, ...)
    if not event then
        return
    end

    local handlers = EventRouter.handlers[event]
    if not handlers then
        return
    end

    local count = handlers.count or 0
    for index = 1, count do
        local ok, err = pcall(handlers[index], event, ...)
        if not ok then
            print("|cffff0000EAM Custom Event Error|r on [" .. tostring(event) .. "]: " .. tostring(err))
        end
    end
end

-- trigger 別名對齊，無縫相容 trigger/fire 雙軌調用
EventRouter.trigger = EventRouter.fire

if frame then
    frame:SetScript("OnEvent", onEvent)
end


