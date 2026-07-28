--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/ClassPowerService
檔案: Services\ClassPowerService.lua

理念:
- 作為職業特殊核心能量（如聖能、連擊點、碎片、真氣、秘法充能、怒氣、狂怒等）的事實監控層。
- 採用「Icon + 中央大數字」的極簡低 GC 設計，免除計量條的複雜重繪開銷。
- 只有當能量值大於 0 時才會顯現於 classPower 告警框架，為 0 時即時回收。

責任:
- 監聽 UNIT_POWER_UPDATE 與 UNIT_MAXPOWER 事件（限 player）。
- 根據玩家當前 UnitPowerType 動態決定所監控的核心能量類別，支援德魯伊貓/熊形態變更。
- 導入 overflowThreshold 資源溢出警示，將其對接至 Renderer 的 glowBorder 亮框管線。

資料所有權:
- 擁有各職業能量類別的靜態圖示與對應設定 Key。

可變狀態:
- 無運行期 persistent 狀態，純事件數據派發。

效能注意:
- 僅在能量發生數值變動或上限變動時觸發 Renderer.render，不使用 OnUpdate。

]]
local _, EAM = ...

local api = EAM.API
local Renderer = nil

local ClassPowerService = {
    activePowerType = nil,
    activeConfigKey = nil,
    activeIcon = 136243,
    activeName = EAM.L.EAM_POWER_CLASS_POWER or "職業能量",
    overflowThreshold = nil,
}

EAM.Services.ClassPowerService = ClassPowerService

-- 能量類型的配置與高亮數據映射表
local POWER_TYPE_CONFIGS = {
    [Enum.PowerType.HolyPower or 9] = {
        configKey = "powerHoly",
        icon = 524203, -- 聖殿騎士裁決 Icon
        name = EAM.L.EAM_POWER_HOLY_POWER or "聖能",
        getThreshold = function() return 5 end
    },
    [Enum.PowerType.SoulShards or 7] = {
        configKey = "powerShard",
        icon = 136184, -- 混沌箭 Icon
        name = EAM.L.EAM_POWER_SOUL_SHARDS or "靈魂碎片",
        getThreshold = function() return 5 end
    },
    [Enum.PowerType.ComboPoints or 4] = {
        configKey = "powerCombo",
        icon = 132292, -- 剔骨 Icon
        name = EAM.L.EAM_POWER_COMBO_POINTS or "連擊點",
        getThreshold = function()
            if api.UnitPowerMax then
                return api.UnitPowerMax("player", Enum.PowerType.ComboPoints)
            end
            return 5
        end
    },
    [Enum.PowerType.Chi or 12] = {
        configKey = "powerChi",
        icon = 627485, -- 幻滅踢 Icon
        name = EAM.L.EAM_POWER_CHI or "真氣",
        getThreshold = function()
            if api.UnitPowerMax then
                return api.UnitPowerMax("player", Enum.PowerType.Chi)
            end
            return 5
        end
    },
    [Enum.PowerType.ArcaneCharges or 16] = {
        configKey = "powerArcane",
        icon = 135732, -- 秘法衝擊 Icon
        name = EAM.L.EAM_POWER_ARCANE_CHARGES or "秘法充能",
        getThreshold = function() return 4 end
    },
    [Enum.PowerType.RunicPower or 6] = {
        configKey = "powerRunic",
        icon = 135767, -- 冰打 Icon
        name = EAM.L.EAM_POWER_RUNIC_POWER or "符文能量",
        getThreshold = function() return 110 end
    },
    [Enum.PowerType.Rage or 1] = {
        configKey = "powerRage",
        icon = 132344, -- 盾牌猛擊 Icon
        name = EAM.L.EAM_POWER_RAGE or "怒氣",
        getThreshold = function() return 85 end
    },
    [Enum.PowerType.Fury or 17] = {
        configKey = "powerFury",
        icon = 1275380, -- 裂魂 Icon
        name = EAM.L.EAM_POWER_FURY_PAIN or "狂怒/痛苦",
        getThreshold = function() return 90 end
    }
}

-- 動態偵測玩家當前形態下的主要核心能量
local function detectClassPower()
    if not api.UnitPowerType then
        return
    end

    local ok, powerType, powerToken = pcall(api.UnitPowerType, "player")
    if not ok or not EAM.Util.isSafeNumber(powerType) then
        if EAM.addDebugLog then
            EAM.addDebugLog("ClassPowerService", "detectClassPower", "UnitPowerType query failed or was restricted.")
        end
        return
    end

    local config = POWER_TYPE_CONFIGS[powerType]
    
    if config then
        ClassPowerService.activePowerType = powerType
        ClassPowerService.activeConfigKey = config.configKey
        ClassPowerService.activeIcon = config.icon
        ClassPowerService.activeName = config.name
        
        local thOk, thVal = pcall(config.getThreshold)
        ClassPowerService.overflowThreshold = thOk and EAM.Util.isSafeNumber(thVal) and thVal or nil
    else
        ClassPowerService.activePowerType = nil
        ClassPowerService.activeConfigKey = nil
        ClassPowerService.activeIcon = 136243
        ClassPowerService.activeName = EAM.L.EAM_POWER_CLASS_POWER or "職業能量"
        ClassPowerService.overflowThreshold = nil
    end

    if EAM.addDebugLog then
        EAM.addDebugLog("ClassPowerService", "detectClassPower", "Detected powerType=" .. tostring(ClassPowerService.activePowerType) .. ", threshold=" .. tostring(ClassPowerService.overflowThreshold))
    end
end

-- 更新目前能量到 UI
function ClassPowerService.updatePower()
    if not Renderer then
        Renderer = EAM.UI.Renderer
    end

    local powerType = ClassPowerService.activePowerType
    local configKey = ClassPowerService.activeConfigKey
    
    if not powerType or not configKey then
        return
    end

    -- 檢查設定是否啟用該能量監控
    local enabled = true
    if EAM.db and EAM.db.config then
        enabled = EAM.db.config[configKey] ~= false
    end

    local current = 0
    if enabled and api.UnitPower then
        local ok, val = pcall(api.UnitPower, "player", powerType)
        if ok and EAM.Util.isSafeNumber(val) then
            current = val
        else
            current = nil
        end
    end

    -- 🛡️ 核心安全防禦：高頻戰鬥中若能量數據突然變為 Secret，絕不與 0 進行大小比較
    local isSecret = not EAM.Util.isSafeNumber(current)
    local id = "classPower_" .. powerType

    if EAM.addDebugLog then
        EAM.addDebugLog("ClassPowerService", "updatePower", "powerType=" .. tostring(powerType) .. ", current=" .. (isSecret and "Secret" or tostring(current)) .. ", isEnabled=" .. tostring(enabled))
    end

    if isSecret then
        -- 數據受限：安全降級，隱藏圖示，絕不拋錯
        if Renderer and Renderer.render then
            Renderer.render({
                id = id,
                shown = false,
            }, EAM.Constants.ALERT_FRAME_TYPES.classPower)
        end
        return
    end

    if current > 0 then
        -- 判斷是否達到溢出警告閾值
        local isOverflow = false
        if ClassPowerService.overflowThreshold and current >= ClassPowerService.overflowThreshold then
            isOverflow = true
        end

        local state = {
            id = id,
            kind = "classPower",
            spellID = powerType,
            name = ClassPowerService.activeName,
            icon = ClassPowerService.activeIcon,
            stacks = current, -- 將能量數值直接作為圖示的 Stacks 疊加層數
            active = true,
            shown = true,
            pandemicReady = isOverflow, -- 複用 UI 的 pandemicReady Glow 發光邊框管線！
            timer = { mode = EAM.Constants.TIMER_NONE }
        }
        
        if Renderer and Renderer.render then
            Renderer.render(state, EAM.Constants.ALERT_FRAME_TYPES.classPower)
        end
    else
        -- 歸 0 時隱藏釋放
        if Renderer and Renderer.render then
            Renderer.render({
                id = id,
                shown = false,
            }, EAM.Constants.ALERT_FRAME_TYPES.classPower)
        end
    end
end

-- 事件接收
function ClassPowerService.onEvent(_, event, unit, powerTypeToken)
    if event == "UNIT_POWER_UPDATE" then
        if unit == "player" and ClassPowerService.activePowerType then
            ClassPowerService.updatePower()
        end
    elseif event == "UNIT_MAXPOWER" then
        if unit == "player" then
            -- 最大能量上限變更時，動態重新計算閾值
            detectClassPower()
            ClassPowerService.updatePower()
        end
    else
        detectClassPower()
        ClassPowerService.updatePower()
    end
end

function ClassPowerService.initialize()
    Renderer = EAM.UI.Renderer
    detectClassPower()

    local router = EAM.Modules.EventRouter
    if router then
        router.register("UNIT_POWER_UPDATE", ClassPowerService.onEvent)
        router.register("UNIT_POWER_FREQUENT", ClassPowerService.onEvent)
        router.register("UNIT_MAXPOWER", ClassPowerService.onEvent)
        router.register("PLAYER_ENTERING_WORLD", ClassPowerService.onEvent)
        router.register("UPDATE_SHAPESHIFT_FORM", ClassPowerService.onEvent) -- 監聽德魯伊形態切換
        router.register("PLAYER_TALENT_UPDATE", function()
            detectClassPower()
            ClassPowerService.updatePower()
        end)
    end
end
