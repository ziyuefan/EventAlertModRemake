--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Core/ModuleController
檔案: CoreModuleController.lua

理念:
- 各服務只註冊事件一次，功能開關以事件入口 gate 與明確清理控制生命週期。
- 避免反覆 RegisterEvent、Tooltip post-call 或匿名 callback 造成重複處理。

責任:
- 讀取全域 moduleToggles，將設定變更分派給對應服務。
- 提供 frameName 到 module key 的顯示 gate，阻止停用後的舊 queue 復活圖示。

資料所有權:
- 不擁有 SavedVariables；只持有初始化旗標與不可變模組 catalog。

邊界:
- 不讀取光環、冷卻、物品或 UnitPower 數值。
- Native Aura 結構變更交由 AuraContainerService 在非戰鬥重建。
]]
local _, EAM = ...

local freeze = EAM.Util and EAM.Util.tableFreeze or function(value)
    return value
end
local Keys = EAM.Constants.MODULE_KEYS

local ModuleController = {
    initialized = false,
}

EAM.Modules.ModuleController = ModuleController

local validKeys = freeze({
    playerAura = true,
    targetAura = true,
    spellCooldown = true,
    itemCooldown = true,
    groundEffect = true,
    classPower = true,
    totem = true,
    tooltipMonitor = true,
})

local moduleOptions = {
    freeze({ key = Keys.playerAura, labelKey = "EAM_MODULE_PLAYER_AURA" }),
    freeze({ key = Keys.targetAura, labelKey = "EAM_MODULE_TARGET_AURA" }),
    freeze({ key = Keys.spellCooldown, labelKey = "EAM_MODULE_SPELL_COOLDOWN" }),
    freeze({ key = Keys.itemCooldown, labelKey = "EAM_MODULE_ITEM_COOLDOWN" }),
    freeze({ key = Keys.groundEffect, labelKey = "EAM_MODULE_GROUND_EFFECT" }),
    freeze({ key = Keys.classPower, labelKey = "EAM_MODULE_CLASS_POWER" }),
    freeze({ key = Keys.totem, labelKey = "EAM_MODULE_TOTEM" }),
    freeze({ key = Keys.tooltipMonitor, labelKey = "EAM_MODULE_TOOLTIP_MONITOR" }),
}
ModuleController.ModuleOptions = freeze(moduleOptions)

local frameModules = freeze({
    selfAura = Keys.playerAura,
    targetAura = Keys.targetAura,
    spellCooldown = Keys.spellCooldown,
    itemCooldown = Keys.itemCooldown,
    classPower = Keys.classPower,
    groundEffect = Keys.groundEffect,
    totem = Keys.totem,
})

local serviceNames = freeze({
    spellCooldown = "CooldownService",
    itemCooldown = "ItemCooldownService",
    groundEffect = "GroundEffectService",
    classPower = "ClassPowerService",
    totem = "TotemService",
    tooltipMonitor = "TooltipMonitorService",
})

function ModuleController.isValidKey(key)
    return type(key) == "string" and validKeys[key] == true
end

function ModuleController.isEnabled(key)
    if not ModuleController.isValidKey(key) then
        return false
    end
    local config = EAM.db and EAM.db.config
    local toggles = type(config) == "table" and config.moduleToggles or nil
    if type(toggles) ~= "table" then
        return true
    end
    return toggles[key] ~= false
end

function ModuleController.isAuraUnitEnabled(unit)
    if unit == "target" then
        return ModuleController.isEnabled(Keys.targetAura)
    end
    if unit == "player" then
        return ModuleController.isEnabled(Keys.playerAura)
    end
    return false
end

function ModuleController.isFrameEnabled(frameName)
    local key = frameModules[frameName]
    return key == nil or ModuleController.isEnabled(key)
end

local function clearFrameForKey(key)
    local renderer = EAM.UI and EAM.UI.Renderer
    if not renderer or type(renderer.clearFrame) ~= "function" then
        return
    end
    for frameName, moduleKey in pairs(frameModules) do
        if moduleKey == key then
            renderer.clearFrame(frameName)
        end
    end
end

function ModuleController.applyToggle(key, enabled, reason)
    if not ModuleController.isValidKey(key) then
        return false, "invalidModuleKey"
    end
    if type(enabled) ~= "boolean" then
        return false, "invalidModuleValue"
    end

    if key == Keys.playerAura or key == Keys.targetAura then
        local unit = key == Keys.targetAura and "target" or "player"
        local auraService = EAM.Services and EAM.Services.AuraService
        if auraService and type(auraService.onModuleToggle) == "function" then
            auraService.onModuleToggle(enabled, unit, reason)
        end
        local containerService = EAM.Services and EAM.Services.AuraContainerService
        if containerService and type(containerService.onModuleToggle) == "function" then
            containerService.onModuleToggle(enabled, unit, reason)
        end
    else
        local serviceName = serviceNames[key]
        local service = serviceName and EAM.Services and EAM.Services[serviceName] or nil
        if service and type(service.onModuleToggle) == "function" then
            service.onModuleToggle(enabled, reason)
        end
    end

    if enabled == false then
        clearFrameForKey(key)
    end
    return true, enabled and "enabled" or "disabled"
end

local function onToggleChanged(_, key, enabled)
    ModuleController.applyToggle(key, enabled, "savedVariables")
end

function ModuleController.initialize()
    if ModuleController.initialized then
        return true, "unchanged"
    end
    ModuleController.initialized = true
    local router = EAM.Modules.EventRouter
    if router then
        router.register("EAM_MODULE_TOGGLE_CHANGED", onToggleChanged)
    end
    return true, "initialized"
end