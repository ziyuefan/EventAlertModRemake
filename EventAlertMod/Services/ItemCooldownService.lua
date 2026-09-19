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
    state.slotID = nil
    state.itemType = nil
    state.name = nil
    state.icon = nil
    state.factsSafe = false
    state.active = false
    state.shown = false
    state.completed = false
    state.usableGlow = false
    state.isPlaceholder = false
    state.isDesaturated = false
    state.cooldownRemoveAura = nil
    state.showSCDOutsideCombat = nil
    state.glowSCDWhenUsable = nil
    state.cooldownPreRender = nil
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

local COOLDOWN_BEHAVIOR_DEFAULTS = {
    cooldownRemoveAura = false,
    showSCDOutsideCombat = true,
    glowSCDWhenUsable = true,
    cooldownPreRender = false,
}

local function isInCombat()
    local inCombatLockdown = api.InCombatLockdown or _G.InCombatLockdown
    return type(inCombatLockdown) == "function" and inCombatLockdown() == true
end

local function resolveBehavior(alert, key)
    if key == "cooldownPreRender" then
        if type(alert) == "table" then
            if type(alert.cooldownPreRender) == "boolean" then
                return alert.cooldownPreRender
            end
            if alert.cooldownRemoveAura == true then
                return false
            end
        end
        local config = EAM.db and EAM.db.config
        local globalValue = type(config) == "table" and config[key] or nil
        if type(globalValue) == "boolean" then
            return globalValue
        end
        return false
    end
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

local function getCooldownData(alert)
    local isSlot = alert.slotID and Util.isSafePositiveNumber(alert.slotID)
    if isSlot then
        local slotID = alert.slotID
        local getInvID = api.GetInventoryItemID or _G.GetInventoryItemID
        local getInvCD = api.GetInventoryItemCooldown or _G.GetInventoryItemCooldown
        local getInvTex = api.GetInventoryItemTexture or _G.GetInventoryItemTexture
        local getInvLink = api.GetInventoryItemLink or _G.GetInventoryItemLink

        local icon = getInvTex and getInvTex("player", slotID)
        local itemLink = getInvLink and getInvLink("player", slotID)
        local equippedItemID = getInvID and getInvID("player", slotID) or nil

        -- 深入解析 equippedItemID：若直接查詢為 nil，嘗試由 itemLink 或 ItemLocation 解析
        if (not equippedItemID or equippedItemID == 0) and itemLink and api.C_Item and api.C_Item.GetItemInfoInstant then
            local instantID = api.C_Item.GetItemInfoInstant(itemLink)
            if instantID and instantID > 0 then
                equippedItemID = instantID
            end
        end
        if (not equippedItemID or equippedItemID == 0) and _G.ItemLocation and _G.ItemLocation.CreateFromEquipmentSlot and api.C_Item and api.C_Item.GetItemID then
            local itemLoc = _G.ItemLocation:CreateFromEquipmentSlot(slotID)
            if itemLoc and api.C_Item.DoesItemExist and api.C_Item.DoesItemExist(itemLoc) then
                equippedItemID = api.C_Item.GetItemID(itemLoc)
            end
        end

        local hasItem = (icon ~= nil) or (equippedItemID and equippedItemID > 0) or (itemLink ~= nil)
        if not hasItem then
            return false, 0, 0, false, nil, nil, nil
        end

        local startTime, duration, isEnabled = 0, 0, true
        -- 軌道 1：官方原生標準 API GetInventoryItemCooldown("player", slotID)
        if getInvCD then
            local ok, s, d, e = pcall(getInvCD, "player", slotID)
            if ok and s then
                startTime, duration, isEnabled = s, d, e
            end
        end

        -- 正規化 isEnabled (GetInventoryItemCooldown 回傳 number 1 或 0)
        if type(isEnabled) == "number" then
            isEnabled = (isEnabled == 1)
        elseif isEnabled == nil then
            isEnabled = true
        end

        -- 軌道 2：ItemLocation 現代化 API 備援 (適用於 Retail 11.x / 12.x)
        if (not startTime or startTime == 0 or not duration or duration == 0) and _G.ItemLocation and _G.ItemLocation.CreateFromEquipmentSlot and api.C_Item and api.C_Item.GetItemCooldown then
            local itemLoc = _G.ItemLocation:CreateFromEquipmentSlot(slotID)
            if itemLoc and api.C_Item.DoesItemExist and api.C_Item.DoesItemExist(itemLoc) then
                local ok, cStart, cDur, cEnable = pcall(api.C_Item.GetItemCooldown, itemLoc)
                if ok and cStart and cDur and cDur > 0 then
                    startTime = cStart
                    duration = cDur
                    isEnabled = (cEnable == true or cEnable == 1 or cEnable == nil)
                end
            end
        end

        -- 軌道 3：具體物品 ID 同軌備援 (以解析之 equippedItemID 查詢 C_Item.GetItemCooldown)
        if (not startTime or startTime == 0 or not duration or duration == 0) and equippedItemID and api.C_Item and api.C_Item.GetItemCooldown then
            local ok, cStart, cDur, cEnable = pcall(api.C_Item.GetItemCooldown, equippedItemID)
            if ok and cStart and cDur and cDur > 0 then
                startTime = cStart
                duration = cDur
                isEnabled = (cEnable == true or cEnable == 1 or cEnable == nil)
            end
        end

        local name = nil
        if equippedItemID and api.C_Item then
            if api.C_Item.GetItemNameByID then
                name = api.C_Item.GetItemNameByID(equippedItemID)
            end
            if not name and api.C_Item.GetItemInfo then
                name = api.C_Item.GetItemInfo(equippedItemID)
            end
        end
        if not icon and equippedItemID and api.C_Item and api.C_Item.GetItemIconByID then
            icon = api.C_Item.GetItemIconByID(equippedItemID)
        end

        return true, startTime or 0, duration or 0, isEnabled, icon, name, equippedItemID
    else
        local itemID = alert.itemID
        if not Util.isSafePositiveNumber(itemID) then
            return false, 0, 0, false, nil, nil, nil
        end
        local cItem = api.C_Item
        local startTime, duration, isEnabled = 0, 0, true
        local icon, name = nil, nil
        if cItem and cItem.GetItemCooldown then
            startTime, duration, isEnabled = cItem.GetItemCooldown(itemID)
        end
        if type(isEnabled) == "number" then
            isEnabled = (isEnabled == 1)
        elseif isEnabled == nil then
            isEnabled = true
        end
        if cItem and cItem.GetItemIconByID then
            icon = cItem.GetItemIconByID(itemID)
        end
        if cItem and cItem.GetItemInfo then
            name = cItem.GetItemInfo(itemID)
        end
        return true, startTime or 0, duration or 0, isEnabled, icon, name, itemID
    end
end

local function refreshAlert(alert, eventName)
    local alertID = alert and alert.id
    local oldState = alertID and ItemCooldownService.states[alertID]
    
    if not alert or alert.enabled == false or (not alert.itemID and not alert.slotID) then
        if oldState then
            oldState.shown = false
            ItemCooldownService.states[alertID] = nil
            return oldState
        end
        return nil
    end

    local behaviorRemove = resolveBehavior(alert, "cooldownRemoveAura")
    local behaviorOutside = resolveBehavior(alert, "showSCDOutsideCombat")
    local behaviorGlow = resolveBehavior(alert, "glowSCDWhenUsable")
    local isPreRender = resolveBehavior(alert, "cooldownPreRender")
    local visibleNow = behaviorOutside or isInCombat()

    local hasItem, startTime, duration, isEnabled, itemIcon, itemName, resolvedItemID = getCooldownData(alert)

    if not hasItem then
        -- 裝備欄位未穿戴或物品不存在
        if isPreRender and visibleNow then
            local state = oldState
            if not state then
                state = ItemCooldownStatePool.acquire()
                ItemCooldownService.states[alertID] = state
            end
            state.id = alertID
            state.kind = EAM.Constants.ALERT_KIND_ITEM_COOLDOWN
            state.slotID = alert.slotID
            state.itemType = "SLOT"
            state.itemID = nil
            state.name = itemName or (alert.slotID and ("Slot " .. alert.slotID))
            state.icon = alert.customIcon and (tonumber(alert.customIcon) or alert.customIcon) or "Interface\\Icons\\INV_Misc_QuestionMark"
            state.factsSafe = true
            state.active = true
            state.shown = true
            state.completed = false
            state.usableGlow = false
            state.isPlaceholder = true
            state.isDesaturated = true
            state.cooldownRemoveAura = behaviorRemove
            state.showSCDOutsideCombat = behaviorOutside
            state.glowSCDWhenUsable = behaviorGlow
            state.cooldownPreRender = isPreRender
            state.boundaryLimited = false
            wipe(state.boundaryWarnings)
            wipe(state.source)
            Util.clearTimer(state.timer, EAM.Constants.TIMER_UNKNOWN)
            state.source.event = eventName
            state.source.api = "InventoryEmptyPlaceholder"
            state.source.updatedAt = api.GetTime and api.GetTime() or 0
            return state
        else
            if oldState then
                oldState.shown = false
                ItemCooldownService.states[alertID] = nil
                return oldState
            end
            return nil
        end
    end

    local hasSafeTiming = Util.isSafeNumber(startTime) and Util.isSafeNumber(duration)
    local hasSafeEnabled = (isEnabled == true or isEnabled == 1 or isEnabled == nil or Util.isSafeBoolean(isEnabled))
    local hasActiveCooldown = hasSafeTiming and hasSafeEnabled and duration > 0 and isEnabled ~= false and isEnabled ~= 0

    local shouldShow = false
    if not visibleNow then
        shouldShow = false
    elseif hasActiveCooldown then
        shouldShow = true
    elseif isPreRender or not behaviorRemove then
        shouldShow = true
    end

    if not shouldShow then
        if oldState then
            oldState.shown = false
            ItemCooldownService.states[alertID] = nil
            return oldState
        end
        return nil
    end

    local state = oldState
    if not state then
        state = ItemCooldownStatePool.acquire()
        ItemCooldownService.states[alertID] = state
    end

    state.id = alertID
    state.kind = EAM.Constants.ALERT_KIND_ITEM_COOLDOWN
    state.itemID = resolvedItemID or alert.itemID
    state.slotID = alert.slotID
    state.itemType = alert.slotID and "SLOT" or "ITEM"
    state.name = itemName
    
    local icon = itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
    if alert.customIcon and alert.customIcon ~= "" then
        icon = tonumber(alert.customIcon) or alert.customIcon
    end
    state.icon = icon
    state.factsSafe = true
    state.active = true
    state.shown = true
    state.completed = not hasActiveCooldown
    state.usableGlow = (not hasActiveCooldown) and (behaviorGlow == true)
    state.isPlaceholder = isPreRender and not hasActiveCooldown
    state.isDesaturated = isPreRender and not hasActiveCooldown and not behaviorGlow
    state.cooldownRemoveAura = behaviorRemove
    state.showSCDOutsideCombat = behaviorOutside
    state.glowSCDWhenUsable = behaviorGlow
    state.cooldownPreRender = isPreRender
    state.boundaryLimited = false
    wipe(state.boundaryWarnings)

    if hasActiveCooldown then
        if state.timer.startTime ~= startTime or state.timer.duration ~= duration or state.timer.mode ~= EAM.Constants.TIMER_NUMERIC then
            state.timer.mode = EAM.Constants.TIMER_NUMERIC
            state.timer.startTime = startTime
            state.timer.duration = duration
            state.timer.expirationTime = startTime + duration
            state.timer.durationObject = DurationAdapter
                and DurationAdapter.createFromStart(startTime, duration) or nil
        end
    else
        Util.clearTimer(state.timer, EAM.Constants.TIMER_UNKNOWN)
    end

    state.source.event = eventName
    state.source.api = alert.slotID and "GetInventoryItemCooldown" or "C_Item.GetItemCooldown"
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
        router.register("ACTIONBAR_UPDATE_COOLDOWN", ItemCooldownService.onCooldownEvent)
        router.register("PLAYER_EQUIPMENT_CHANGED", ItemCooldownService.onEquipmentChanged)
        router.register("UNIT_INVENTORY_CHANGED", ItemCooldownService.onUnitInventoryChanged)
        router.register("PLAYER_REGEN_DISABLED", ItemCooldownService.onCombatEvent)
        router.register("PLAYER_REGEN_ENABLED", ItemCooldownService.onCombatEvent)
        router.register("EAM_ITEM_COOLDOWN_CONFIG_CHANGED", ItemCooldownService.onConfigChanged)
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

    local lastState = nil
    for i = 1, alertCount do
        local alert = alertList[i]
        local isMatch = false
        if alert.itemID == itemID then
            isMatch = true
        elseif alert.slotID then
            local getInvID = api.GetInventoryItemID or _G.GetInventoryItemID
            local eqID = getInvID and getInvID("player", alert.slotID)
            if not eqID and api.GetInventoryItemLink then
                local link = api.GetInventoryItemLink("player", alert.slotID)
                if link and api.C_Item and api.C_Item.GetItemInfoInstant then
                    local id = api.C_Item.GetItemInfoInstant(link)
                    if id then eqID = id end
                end
            end
            if eqID == itemID then
                isMatch = true
            end
        end

        if isMatch then
            local state = refreshAlert(alert, eventName or "manual")
            if state then
                local router = EAM.Modules.EventRouter
                if router then
                    router.fire("EAM_ITEM_COOLDOWN_STATE_CHANGED", state, EAM.Constants.ALERT_FRAME_TYPES.itemCooldown)
                end
                lastState = state
            end
        end
    end
    return lastState
end

function ItemCooldownService.refreshSlot(slotID, eventName)
    if not moduleEnabled() then
        return nil, "moduleDisabled"
    end
    verifyAlertList()
    if alertCount == 0 then
        return nil
    end

    for i = 1, alertCount do
        local alert = alertList[i]
        if alert.slotID == slotID then
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

function ItemCooldownService.onEquipmentChanged(eventName, slotID, hasItem)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    if EAM.addDebugLog then
        EAM.addDebugLog("ItemCooldownService", "onEquipmentChanged", "Slot: " .. tostring(slotID))
    end
    if Util.isSafePositiveNumber(slotID) then
        ItemCooldownService.refreshSlot(slotID, eventName)
    else
        refreshAll(eventName)
    end
end

function ItemCooldownService.onUnitInventoryChanged(eventName, unitTarget)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    if unitTarget and unitTarget ~= "player" then
        return false
    end
    if EAM.addDebugLog then
        EAM.addDebugLog("ItemCooldownService", "onUnitInventoryChanged", "Unit: " .. tostring(unitTarget))
    end
    refreshAll(eventName)
end

function ItemCooldownService.onCombatEvent(eventName)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    refreshAll(eventName)
end

function ItemCooldownService.onConfigChanged(eventName, alertID, field, value)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    refreshAll("CONFIG_CHANGED")
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