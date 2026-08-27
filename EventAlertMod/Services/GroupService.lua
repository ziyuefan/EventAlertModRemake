--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/GroupService
檔案: Services\GroupService.lua

理念:
- 管理系統內建戰術群組與玩家自訂群組，提供 N:N 多對多法術標籤管理。
- 提供複合啟用狀態計算（Compound Active State），支援群組主開關與情境過濾。

責任:
- 維護群組定義清單（內建 + 自訂）。
- 提供群組 CRUD API 與 SavedVariables 雙向同步。
- 判斷法術在群組規則下的最終可視性（Compound Visibility）。
- 監聽群組狀態變更事件並通知 AlertManager。

資料所有權:
- 依賴 EAM.Modules.SavedVariables 保存群組設定與法術標籤。
- 依賴 EAM.Data.SpellHeuristics 取得內建預設群組定義。

邊界:
- 不直接渲染 Frame，不處理每幀 OnUpdate。
- 戰鬥中不執行結構變更，僅提供 O(1) 唯讀查詢。
--]]
local _, EAM = ...

EAM.Services = EAM.Services or {}

local GroupService = {
    _cachedGroups = nil,
    _spellGroupIndex = nil,
}
EAM.Services.GroupService = GroupService

local function getSavedVariables()
    return EAM.Modules and EAM.Modules.SavedVariables
end

local function getSpellHeuristics()
    return EAM.Data and EAM.Data.SpellHeuristics
end

-- 取得系統內建預設群組
function GroupService.getDefaultGroups()
    local sh = getSpellHeuristics()
    if sh and sh.TACTICAL_GROUPS then
        return sh.TACTICAL_GROUPS
    end
    return {
        { id = "burst", nameKey = "GROUP_BURST", icon = 132349, color = "FFFFD100" },
        { id = "defensive", nameKey = "GROUP_DEFENSIVE", icon = 132294, color = "FF00BFFF" },
        { id = "cc", nameKey = "GROUP_CC", icon = 132307, color = "FFFF6347" },
        { id = "ground_effect", nameKey = "GROUP_GROUND", icon = 136035, color = "FF32CD32" },
    }
end

-- 初始化並快取群組清單
function GroupService.refreshCache()
    local sv = getSavedVariables()
    local dbGroups = sv and sv.getGroups and sv.getGroups() or {}
    local defaultGroups = GroupService.getDefaultGroups()

    local merged = {}
    local seen = {}

    -- 1. 加入內建群組 (套用玩家儲存的覆寫)
    for _, def in ipairs(defaultGroups) do
        local gId = def.id
        local userOverride = dbGroups[gId] or {}
        local nameStr = def.nameKey and EAM.L and EAM.L[def.nameKey] or def.name or gId
        merged[#merged + 1] = {
            id = gId,
            name = userOverride.name or nameStr,
            nameKey = def.nameKey,
            icon = userOverride.icon or def.icon,
            color = userOverride.color or def.color,
            enabled = userOverride.enabled ~= false, -- 預設 true
            inCombatOnly = userOverride.inCombatOnly or false,
            instanceFilter = userOverride.instanceFilter or "ALL",
            anchorOverride = userOverride.anchorOverride or false,
            isSystem = true,
        }
        seen[gId] = true
    end

    -- 2. 加入玩家自訂群組
    for gId, custom in pairs(dbGroups) do
        if not seen[gId] then
            merged[#merged + 1] = {
                id = gId,
                name = custom.name or gId,
                icon = custom.icon or 134400,
                color = custom.color or "FFFFFFFF",
                enabled = custom.enabled ~= false,
                inCombatOnly = custom.inCombatOnly or false,
                instanceFilter = custom.instanceFilter or "ALL",
                anchorOverride = custom.anchorOverride or false,
                isSystem = false,
            }
            seen[gId] = true
        end
    end

    GroupService._cachedGroups = merged
    return merged
end

-- 取得所有群組
function GroupService.getGroups()
    if not GroupService._cachedGroups then
        GroupService.refreshCache()
    end
    return GroupService._cachedGroups
end

-- 取得單一群組
function GroupService.getGroup(groupId)
    local groups = GroupService.getGroups()
    for _, g in ipairs(groups) do
        if g.id == groupId then
            return g
        end
    end
    return nil
end

-- 檢查單一群組是否處於啟用狀態
function GroupService.isGroupEnabled(groupId)
    local g = GroupService.getGroup(groupId)
    return g and g.enabled ~= false
end

-- 設定群組啟用狀態
function GroupService.setGroupEnabled(groupId, enabled)
    local sv = getSavedVariables()
    if sv and sv.setGroupProperty then
        sv.setGroupProperty(groupId, "enabled", enabled)
    end
    GroupService.refreshCache()

    -- 廣播群組變更
    if EAM.EventRouter and EAM.EventRouter.broadcast then
        EAM.EventRouter.broadcast("EAM_GROUP_CONFIG_CHANGED", groupId)
    end
end

-- 新增自訂群組
function GroupService.createCustomGroup(name, color, icon)
    if not name or name:trim() == "" then
        return nil
    end
    local id = "custom_" .. time() .. "_" .. math.random(100, 999)
    local sv = getSavedVariables()
    if sv and sv.saveGroup then
        sv.saveGroup(id, {
            name = name,
            color = color or "FFFFFFFF",
            icon = icon or 134400,
            enabled = true,
            isSystem = false,
        })
    end
    GroupService.refreshCache()
    return id
end

-- 刪除自訂群組
function GroupService.deleteCustomGroup(groupId)
    local sv = getSavedVariables()
    if sv and sv.removeGroup then
        sv.removeGroup(groupId)
    end
    GroupService.refreshCache()
end

-- 核心判斷：計算單一法術在群組規則下的複合啟用狀態
function GroupService.isSpellActiveUnderGroups(alert)
    if not alert then
        return false
    end
    -- 1. 法術本身的 master switch
    if alert.enable == false or alert.enabled == false then
        return false
    end

    -- 2. 若未指派任何群組，預設直接依賴自身開關
    local groups = alert.groups
    if not groups or #groups == 0 then
        return true
    end

    -- 3. 若有指派群組，只要所屬群組中至少有一個為「已啟用」，即判定為啟用
    for _, gId in ipairs(groups) do
        if GroupService.isGroupEnabled(gId) then
            return true
        end
    end

    -- 所有指派的群組皆被停用
    return false
end

-- 取得某群組所包含的所有法術 ID 清單
function GroupService.getSpellsInGroup(groupId, alertList)
    local results = {}
    if not alertList then
        return results
    end

    for spellId, alert in pairs(alertList) do
        if alert.groups then
            for _, gId in ipairs(alert.groups) do
                if gId == groupId then
                    results[#results + 1] = spellId
                    break
                end
            end
        end
    end
    return results
end

-- 切換法術在特定群組中的歸屬
function GroupService.toggleSpellGroup(alert, groupId)
    if not alert or not groupId then
        return
    end
    alert.groups = alert.groups or {}
    local foundIndex = nil
    for index, gId in ipairs(alert.groups) do
        if gId == groupId then
            foundIndex = index
            break
        end
    end

    if foundIndex then
        table.remove(alert.groups, foundIndex)
    else
        table.insert(alert.groups, groupId)
    end
end
