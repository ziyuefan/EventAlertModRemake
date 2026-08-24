--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/ItemCooldownService
檔案: Services\ItemCooldownService.lua

理念:
- 直接 itemID 監控歸此模組，不讓 item cooldown 邏輯散入 renderer。
- 採取極致健壯且低 GC 的直讀策略，避免過度安全檢查導致普通冷卻數據被誤攔截。

責任:
- 管理 item cooldown cache、ItemCooldownState 與 opt-in cache build 狀態。
- 接收 BAG_UPDATE_COOLDOWN 事件並刷新物品冷卻狀態。
- 導入 Service-Layer Write Gating，防止高頻事件重複解綁與綁定。
- 對齊 12.x 原生時間 DurationObject 與雙軌 Renderer 管線。

資料所有權:
- 擁有 item cooldown states 與 runtime cache。

可變狀態:
- 可 mutate item runtime cache；不可寫 SavedVariables hot path。

效能注意:
- 使用 table.create 預分配狀態表與警告陣列容量，防止 rehashing。
- 避免 runtime 產生臨時 tables，且熱路徑無 pairs 迭代。

]]
local _, EAM = ...

local api = EAM.API
local Util = EAM.Util
local DurationAdapter = EAM.Modules.DurationAdapter
local ItemCooldownStatePool
local ModuleController = EAM.Modules and EAM.Modules.ModuleController

local ItemCooldownService = {
    states = {},
}

EAM.Services.ItemCooldownService = ItemCooldownService

local function moduleEnabled()
    return not ModuleController
        or ModuleController.isEnabled(EAM.Constants.MODULE_KEYS.itemCooldown)
end

-- 低 GC 的 ItemCooldownState 物件快取池
ItemCooldownStatePool = {
    recycleBin = {},
    binSize = 0,
}

ItemCooldownService.ItemCooldownStatePool = ItemCooldownStatePool

function ItemCooldownStatePool.initialize()
    for i = 1, 20 do
        local state = Util.tableCreate(0, 16)
        state.boundaryWarnings = Util.tableCreate(4, 0)
        state.timer = Util.tableCreate(0, 8)
        state.source = Util.tableCreate(0, 4)
        ItemCooldownStatePool.recycleBin[i] = state
    end
    ItemCooldownStatePool.binSize = 20
end

function ItemCooldownStatePool.acquire()
    if ItemCooldownStatePool.binSize > 0 then
        local state = ItemCooldownStatePool.recycleBin[ItemCooldownStatePool.binSize]
        ItemCooldownStatePool.recycleBin[ItemCooldownStatePool.binSize] = nil
        ItemCooldownStatePool.binSize = ItemCooldownStatePool.binSize - 1
        state.releaseFunc = ItemCooldownStatePool.release
        return state
    else
        local state = Util.tableCreate(0, 16)
        state.boundaryWarnings = Util.tableCreate(4, 0)
        state.timer = Util.tableCreate(0, 8)
        state.source = Util.tableCreate(0, 4)
        state.releaseFunc = ItemCooldownStatePool.release
        return state
    end
end

function ItemCooldownStatePool.release(state)
    if not state then return end
    
    state.id = nil
    state.kind = nil
    state.itemID = nil
    state.name = nil
    state.icon = nil
    state.factsSafe = false
    state.active = false
    state.shown = false
    state.boundaryLimited = false
    state.releaseFunc = nil
    wipe(state.boundaryWarnings)
    wipe(state.timer)
    wipe(state.source)
    
    ItemCooldownStatePool.binSize = ItemCooldownStatePool.binSize + 1
    ItemCooldownStatePool.recycleBin[ItemCooldownStatePool.binSize] = state
end

-- Performance Optimizations: Array pre-allocation and revision tracking
local alertList = Util.tableCreate(32, 0)
local alertCount = 0
local lastDbRevision = -1

function ItemCooldownService.updateAlertList()
    alertCount = 0
    local savedVariables = EAM.Modules and EAM.Modules.SavedVariables
    local alerts = savedVariables and savedVariables.getActiveAlerts and savedVariables.getActiveAlerts() or nil
    if alerts and alerts.itemCooldowns then
        for _, alert in pairs(alerts.itemCooldowns) do
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
        ItemCooldownService.updateAlertList()
        lastDbRevision = currentRev
    end
end

local function refreshAlert(alert, eventName)
    local oldState = ItemCooldownService.states[alert.id]
    
    if alert.enabled == false or not alert.itemID then
        if oldState then
            oldState.shown = false
            ItemCooldownService.states[alert.id] = nil
            return oldState
        end
        return nil
    end

    local cItem = api.C_Item
    if not cItem or not cItem.GetItemCooldown then
        if oldState then
            oldState.shown = false
            ItemCooldownService.states[alert.id] = nil
            return oldState
        end
        return nil
    end

    local startTime, duration, isEnabled = cItem.GetItemCooldown(alert.itemID)
    local hasSafeTiming = Util.isSafeNumber(startTime) and Util.isSafeNumber(duration)
    local hasSafeEnabled = isEnabled == nil or Util.isSafeBoolean(isEnabled)

    -- Determine shown state prior to allocation (O(1) filtering)
    local shouldShow = false
    if hasSafeTiming and hasSafeEnabled and duration > 0 then
        if isEnabled ~= false then
            shouldShow = true
        end
    end

    if not shouldShow then
        if oldState then
            oldState.shown = false
            ItemCooldownService.states[alert.id] = nil
            return oldState
        end
        return nil
    end

    local state = oldState
    if not state then
        state = ItemCooldownStatePool.acquire()
        ItemCooldownService.states[alert.id] = state
    end

    state.id = alert.id
    state.kind = EAM.Constants.ALERT_KIND_ITEM_COOLDOWN
    state.itemID = alert.itemID
    local itemIcon = cItem.GetItemIconByID(alert.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
    if alert.customIcon and alert.customIcon ~= "" then
        itemIcon = tonumber(alert.customIcon) or alert.customIcon
    end
    state.icon = itemIcon
    state.factsSafe = true
    state.active = true
    state.shown = true
    state.boundaryLimited = false
    wipe(state.boundaryWarnings)

    if state.timer.startTime ~= startTime or state.timer.duration ~= duration or state.timer.mode ~= EAM.Constants.TIMER_NUMERIC then
        state.timer.mode = EAM.Constants.TIMER_NUMERIC
        state.timer.startTime = startTime
        state.timer.duration = duration
        state.timer.expirationTime = startTime + duration
        
        state.timer.durationObject = DurationAdapter
            and DurationAdapter.createFromStart(startTime, duration) or nil
    end

    state.source.event = eventName
    state.source.api = "C_Item.GetItemCooldown"
    state.source.updatedAt = api.GetTime and api.GetTime() or 0

    return state
end

local function refreshAll(eventName)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
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
                router.fire("EAM_ITEM_COOLDOWN_STATE_CHANGED", state, EAM.Constants.ALERT_FRAME_TYPES.itemCooldown)
            end
        end
    end
end

function ItemCooldownService.initialize()
    ItemCooldownStatePool.initialize()
    if EAM.addDebugLog then
        EAM.addDebugLog("ItemCooldownService", "initialize", "ItemCooldownService initialized with ItemCooldownStatePool.")
    end
    local router = EAM.Modules.EventRouter
    if router then
        router.register("BAG_UPDATE_COOLDOWN", ItemCooldownService.onCooldownEvent)
        router.register("SPELL_UPDATE_COOLDOWN", ItemCooldownService.onCooldownEvent)
    end
end

function ItemCooldownService.refreshItem(itemID, eventName)
    if not moduleEnabled() then
        return nil, "moduleDisabled"
    end
    verifyAlertList()
    if alertCount == 0 then
        return nil
    end

    for i = 1, alertCount do
        local alert = alertList[i]
        if alert.itemID == itemID then
            local state = refreshAlert(alert, eventName or "manual")
            if state then
                local router = EAM.Modules.EventRouter
                if router then
                    router.fire("EAM_ITEM_COOLDOWN_STATE_CHANGED", state, EAM.Constants.ALERT_FRAME_TYPES.itemCooldown)
                end
                return state
            end
        end
    end
    return nil
end

function ItemCooldownService.refreshAll(eventName)
    refreshAll(eventName or "manual")
end

function ItemCooldownService.onCooldownEvent(eventName, spellID, baseSpellID, category, startRecoveryCategory, itemID)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    if EAM.addDebugLog then
        EAM.addDebugLog("ItemCooldownService", "onCooldownEvent", "Event: " .. tostring(eventName))
    end
    if eventName == "SPELL_UPDATE_COOLDOWN" then
        if Util.isSafePositiveNumber(itemID) then
            ItemCooldownService.refreshItem(itemID, eventName)
        else
            refreshAll(eventName)
        end
        return
    end
    refreshAll(eventName)
end

function ItemCooldownService.onModuleToggle(enabled, reason)
    lastDbRevision = -1
    if enabled == false then
        local router = EAM.Modules.EventRouter
        for alertID, state in pairs(ItemCooldownService.states) do
            state.shown = false
            ItemCooldownService.states[alertID] = nil
            if router then
                router.fire(
                    "EAM_ITEM_COOLDOWN_STATE_CHANGED",
                    state,
                    EAM.Constants.ALERT_FRAME_TYPES.itemCooldown
                )
            end
        end
        return true, "disabled"
    end
    refreshAll("MODULE_ENABLED_" .. tostring(reason or "manual"))
    return true, "enabled"
end