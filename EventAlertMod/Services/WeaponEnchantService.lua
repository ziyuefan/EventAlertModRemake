--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/WeaponEnchantService
檔案: Services\WeaponEnchantService.lua

理念:
- 將武器暫時性附魔 (磨刀石/巫術之油/薩滿火舌風怒/影之哀傷等) 作為標準 AuraState 提供給渲染器。
- 與自身增益光環流式並列，消除傳統獨立輪詢視窗。

責任:
- 監聽裝備變更與定時器，解析 GetWeaponEnchantInfo。
- 生成標準化 AuraState 並派發至 selfAura 告警框架。

資料所有權:
- 擁有 weapon enchant states。
]]

local _, EAM = ...

local api = EAM.API
local Util = EAM.Util
local Constants = EAM.Constants
local ModuleController = EAM.Modules and EAM.Modules.ModuleController

local WeaponEnchantService = {
    states = {},
    timerHandle = nil,
    enabled = true,
}

EAM.Services = EAM.Services or {}
EAM.Services.WeaponEnchantService = WeaponEnchantService

local function isServiceEnabled()
    if not WeaponEnchantService.enabled then
        return false
    end
    if ModuleController and not ModuleController.isAuraUnitEnabled("player") then
        return false
    end
    local config = EAM.db and EAM.db.config
    if config and config.enableWeaponEnchant == false then
        return false
    end
    return true
end

local function fireState(state)
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router and state then
        router.fire("EAM_AURA_STATE_CHANGED", state, Constants.ALERT_FRAME_TYPES.selfAura)
    end
end

local function getOrCreateState(id)
    local state = WeaponEnchantService.states[id]
    if not state then
        state = {
            id = id,
            kind = Constants.ALERT_KIND_AURA,
            unit = "player",
            auraFilter = "HELPFUL",
            factsSafe = true,
            boundaryLimited = false,
            boundaryWarnings = {},
            timer = { kind = Constants.TIMER_NUMERIC },
            source = { event = "WEAPON_ENCHANT" },
        }
        WeaponEnchantService.states[id] = state
    end
    return state
end

local function scheduleNextTick()
    if WeaponEnchantService.timerHandle then
        return
    end
    local Scheduler = EAM.Modules and EAM.Modules.Scheduler
    if Scheduler and Scheduler.after then
        WeaponEnchantService.timerHandle = Scheduler.after(1.0, function()
            WeaponEnchantService.timerHandle = nil
            WeaponEnchantService.refresh("TIMER")
        end)
    end
end

function WeaponEnchantService.refresh(eventName)
    if not isServiceEnabled() then
        for id, state in pairs(WeaponEnchantService.states) do
            if state.shown then
                state.shown = false
                fireState(state)
            end
        end
        return
    end

    local getEnchantInfo = api.GetWeaponEnchantInfo or GetWeaponEnchantInfo
    if type(getEnchantInfo) ~= "function" then
        return
    end

    local hasMH, mhExp, mhCharges, mhID, hasOH, ohExp, ohCharges, ohID = getEnchantInfo()
    local now = (api.GetTime and api.GetTime()) or GetTime()
    local anyActive = false

    -- 主手 (Slot 16)
    local mhState = getOrCreateState("WEAPON_ENCHANT_16")
    if hasMH and mhExp and mhExp > 0 then
        anyActive = true
        local durationSec = mhExp / 1000
        local getTexture = api.GetInventoryItemTexture or GetInventoryItemTexture
        local tex = (type(getTexture) == "function" and getTexture("player", 16)) or 136518
        mhState.name = EAM.Locale and EAM.Locale.EAM_WEAPON_ENCHANT_MH or "主手附魔"
        mhState.icon = tex
        mhState.stacks = (mhCharges and mhCharges > 0) and mhCharges or nil
        mhState.active = true
        mhState.shown = true
        mhState.fromPlayer = true
        mhState.timer.kind = Constants.TIMER_NUMERIC
        mhState.timer.duration = durationSec
        mhState.timer.expirationTime = now + durationSec
        fireState(mhState)
    else
        if mhState.shown then
            mhState.shown = false
            fireState(mhState)
        end
    end

    -- 副手 (Slot 17)
    local ohState = getOrCreateState("WEAPON_ENCHANT_17")
    if hasOH and ohExp and ohExp > 0 then
        anyActive = true
        local durationSec = ohExp / 1000
        local getTexture = api.GetInventoryItemTexture or GetInventoryItemTexture
        local tex = (type(getTexture) == "function" and getTexture("player", 17)) or 136518
        ohState.name = EAM.Locale and EAM.Locale.EAM_WEAPON_ENCHANT_OH or "副手附魔"
        ohState.icon = tex
        ohState.stacks = (ohCharges and ohCharges > 0) and ohCharges or nil
        ohState.active = true
        ohState.shown = true
        ohState.fromPlayer = true
        ohState.timer.kind = Constants.TIMER_NUMERIC
        ohState.timer.duration = durationSec
        ohState.timer.expirationTime = now + durationSec
        fireState(ohState)
    else
        if ohState.shown then
            ohState.shown = false
            fireState(ohState)
        end
    end

    if anyActive then
        scheduleNextTick()
    end
end

function WeaponEnchantService.initialize()
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router then
        router.register("UNIT_INVENTORY_CHANGED", function(eventName, unit)
            if unit == "player" then
                WeaponEnchantService.refresh(eventName)
            end
        end)
        router.register("PLAYER_EQUIPMENT_CHANGED", function(eventName)
            WeaponEnchantService.refresh(eventName)
        end)
        router.register("PLAYER_ENTERING_WORLD", function(eventName)
            WeaponEnchantService.refresh(eventName)
        end)
    end
end
