--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/ClassPowerService
檔案: Services\ClassPowerService.lua

責任:
- 選擇玩家目前可用的職業資源，次要資源優先、主要資源後備。
- 只把確認安全的普通數字送入一般 Renderer，並提供穩定 capability 狀態。

邊界:
- 呼叫 UnitPowerMax/UnitPower 前先查 C_Secrets predicate；回傳值仍須通過 safe-number 檢查。
- Secret power 不比較、不字串化、不寫入 state、SavedVariables、debug log 或 JSON。
- Secret 百分比顯示只交由獨立 UnitPowerCapabilityProbe 實測，不混入一般 IconPool。
]]
local _, EAM = ...

local api = EAM.API
local Util = EAM.Util
local Renderer = nil
local ModuleController = EAM.Modules and EAM.Modules.ModuleController
local PowerType = Enum and Enum.PowerType or {}

local ClassPowerService = {
    activePowerType = nil,
    activePowerToken = nil,
    activeConfigKey = nil,
    activeIcon = 136243,
    activeName = EAM.L.EAM_POWER_CLASS_POWER or "職業能量",
    overflowThreshold = nil,
    selectedFrom = "none",
    predicateAvailable = false,
    safeUpdateCount = 0,
    secretUpdateCount = 0,
    unavailableUpdateCount = 0,
    lastResultClass = "unavailable",
    combatDeferredCount = 0,
}

EAM.Services.ClassPowerService = ClassPowerService

local POWER_TYPE_CONFIGS = {}

local function powerID(name, fallback)
    local value = PowerType[name]
    if Util.isSafeNonNegativeNumber(value) then
        return value
    end
    return fallback
end

local function definePower(name, fallback, configKey, icon, displayName, token, thresholdRatio)
    local id = powerID(name, fallback)
    POWER_TYPE_CONFIGS[id] = {
        powerType = id,
        configKey = configKey,
        icon = icon,
        name = displayName,
        token = token,
        thresholdRatio = thresholdRatio or 1,
    }
    return id
end

local POWER_MANA = definePower("Mana", 0, "powerMana", 136096, "法力", "MANA", 0.9)
local POWER_RAGE = definePower("Rage", 1, "powerRage", 132344, EAM.L.EAM_POWER_RAGE or "怒氣", "RAGE", 0.85)
local POWER_FOCUS = definePower("Focus", 2, "powerFocus", 132242, "集中值", "FOCUS", 0.9)
local POWER_ENERGY = definePower("Energy", 3, "powerEnergy", 136110, "能量", "ENERGY", 0.9)
local POWER_COMBO = definePower("ComboPoints", 4, "powerCombo", 132292, EAM.L.EAM_POWER_COMBO_POINTS or "連擊點", "COMBO_POINTS", 1)
local POWER_RUNES = definePower("Runes", 5, "powerRunes", 134417, "符文", "RUNES", 1)
local POWER_RUNIC = definePower("RunicPower", 6, "powerRunic", 135767, EAM.L.EAM_POWER_RUNIC_POWER or "符文能量", "RUNIC_POWER", 0.85)
local POWER_SHARDS = definePower("SoulShards", 7, "powerShard", 136184, EAM.L.EAM_POWER_SOUL_SHARDS or "靈魂碎片", "SOUL_SHARDS", 1)
local POWER_LUNAR = definePower("LunarPower", 8, "powerAstral", 236168, "星能", "LUNAR_POWER", 0.9)
local POWER_HOLY = definePower("HolyPower", 9, "powerHoly", 524203, EAM.L.EAM_POWER_HOLY_POWER or "聖能", "HOLY_POWER", 1)
local POWER_MAELSTROM = definePower("Maelstrom", 11, "powerMaelstrom", 136099, "漩渦值", "MAELSTROM", 0.9)
local POWER_CHI = definePower("Chi", 12, "powerChi", 627485, EAM.L.EAM_POWER_CHI or "真氣", "CHI", 1)
local POWER_INSANITY = definePower("Insanity", 13, "powerInsanity", 237569, "瘋狂", "INSANITY", 0.9)
local POWER_ARCANE = definePower("ArcaneCharges", 16, "powerArcane", 135732, EAM.L.EAM_POWER_ARCANE_CHARGES or "秘法充能", "ARCANE_CHARGES", 1)
local POWER_FURY = definePower("Fury", 17, "powerFury", 1275380, EAM.L.EAM_POWER_FURY_PAIN or "魔怒", "FURY", 0.9)
local POWER_PAIN = definePower("Pain", 18, "powerFury", 1247264, "痛苦", "PAIN", 0.9)
local POWER_ESSENCE = definePower("Essence", 19, "powerVigor", 4630437, "精華", "ESSENCE", 1)

local CLASS_PRIORITIES = {
    PALADIN = { POWER_HOLY },
    WARLOCK = { POWER_SHARDS },
    ROGUE = { POWER_COMBO },
    MONK = { POWER_CHI },
    MAGE = { POWER_ARCANE },
    EVOKER = { POWER_ESSENCE },
    DEATHKNIGHT = { POWER_RUNES, POWER_RUNIC },
    DRUID = { POWER_ENERGY, POWER_COMBO, POWER_LUNAR },
    SHAMAN = { POWER_MAELSTROM },
    PRIEST = { POWER_INSANITY },
    WARRIOR = { POWER_RAGE },
    HUNTER = { POWER_FOCUS },
    DEMONHUNTER = { POWER_FURY, POWER_PAIN },
}

local numericState = {
    timer = { mode = EAM.Constants.TIMER_NONE },
    source = {},
}
local hiddenState = {
    shown = false,
}
local lastRenderedID = nil

local function configEnabled(config)
    return not EAM.db
        or not EAM.db.config
        or EAM.db.config[config.configKey] ~= false
end

local function moduleEnabled()
    return not ModuleController
        or ModuleController.isEnabled(EAM.Constants.MODULE_KEYS.classPower)
end

local function inCombat()
    return api.InCombatLockdown and api.InCombatLockdown() == true
end

local function callSecretPredicate(functionName, powerType)
    local cSecrets = api.C_Secrets
    local predicate = cSecrets and cSecrets[functionName]
    if type(predicate) ~= "function" then
        return nil, "unavailable"
    end
    local ok, result = pcall(predicate, "player", powerType)
    if not ok or not Util.isSafeBoolean(result) then
        return nil, "error"
    end
    return result, "available"
end

local function querySafeMax(powerType)
    local shouldBeSecret, predicateStatus = callSecretPredicate("ShouldUnitPowerMaxBeSecret", powerType)
    if predicateStatus ~= "available" or shouldBeSecret ~= false or type(api.UnitPowerMax) ~= "function" then
        return nil
    end
    local ok, value = pcall(api.UnitPowerMax, "player", powerType, false)
    if not ok or not Util.isSafePositiveNumber(value) then
        return nil
    end
    return value
end

local function hideRenderedState()
    if not Renderer then
        Renderer = EAM.UI.Renderer
    end
    if not Renderer or not Renderer.render or not lastRenderedID then
        return
    end
    hiddenState.id = lastRenderedID
    Renderer.render(hiddenState, EAM.Constants.ALERT_FRAME_TYPES.classPower)
    lastRenderedID = nil
end

local function selectPower(powerType, source)
    local config = POWER_TYPE_CONFIGS[powerType]
    if not config or not configEnabled(config) then
        return false
    end
    local maxPower = querySafeMax(powerType)
    if not maxPower then
        return false
    end

    local shouldBeSecret, predicateStatus = callSecretPredicate("ShouldUnitPowerBeSecret", powerType)
    if predicateStatus ~= "available" then
        return false
    end
    if shouldBeSecret ~= false and ClassPowerService.activePowerType ~= powerType then
        return false
    end

    local oldType = ClassPowerService.activePowerType
    if oldType and oldType ~= powerType then
        hideRenderedState()
    end
    ClassPowerService.activePowerType = powerType
    ClassPowerService.activePowerToken = config.token
    ClassPowerService.activeConfigKey = config.configKey
    ClassPowerService.activeIcon = config.icon
    ClassPowerService.activeName = config.name
    ClassPowerService.overflowThreshold = maxPower * config.thresholdRatio
    ClassPowerService.selectedFrom = source
    return true
end

function ClassPowerService.detectClassPower()
    if not moduleEnabled() then
        ClassPowerService.lastResultClass = "moduleDisabled"
        return false, "moduleDisabled"
    end
    if inCombat() then
        ClassPowerService.combatDeferredCount = ClassPowerService.combatDeferredCount + 1
        ClassPowerService.lastResultClass = "combatDeferred"
        return false
    end

    local cSecrets = api.C_Secrets
    ClassPowerService.predicateAvailable = cSecrets
        and type(cSecrets.ShouldUnitPowerBeSecret) == "function"
        and type(cSecrets.ShouldUnitPowerMaxBeSecret) == "function" or false

    local classToken = nil
    if api.UnitClass then
        local ok, localizedClass, token = pcall(api.UnitClass, "player")
        if ok and Util.isSafeString(token) then
            classToken = token
        end
    end

    local priorities = classToken and CLASS_PRIORITIES[classToken] or nil
    if priorities then
        for index = 1, #priorities do
            if selectPower(priorities[index], "classSecondary") then
                return true
            end
        end
    end

    if type(api.UnitPowerType) == "function" then
        local ok, currentPowerType = pcall(api.UnitPowerType, "player")
        if ok and Util.isSafeNonNegativeNumber(currentPowerType)
            and selectPower(currentPowerType, "currentPrimary")
        then
            return true
        end
    end

    hideRenderedState()
    ClassPowerService.activePowerType = nil
    ClassPowerService.activePowerToken = nil
    ClassPowerService.activeConfigKey = nil
    ClassPowerService.overflowThreshold = nil
    ClassPowerService.selectedFrom = "none"
    return false
end

local function classifyPowerValue(powerType)
    local shouldBeSecret, predicateStatus = callSecretPredicate("ShouldUnitPowerBeSecret", powerType)
    if predicateStatus ~= "available" or shouldBeSecret ~= false then
        return "secret", nil
    end
    if type(api.UnitPower) ~= "function" then
        return "unavailable", nil
    end
    local ok, value = pcall(api.UnitPower, "player", powerType, false)
    if not ok then
        return "error", nil
    end
    if Util.isSecretValue(value) or not Util.canAccessValue(value) then
        return "secret", nil
    end
    if not Util.isSafeNonNegativeNumber(value) then
        return value == nil and "nil" or "inaccessible", nil
    end
    return "safe-number", value
end

function ClassPowerService.updatePower()
    if not moduleEnabled() then
        ClassPowerService.lastResultClass = "moduleDisabled"
        hideRenderedState()
        return false, "moduleDisabled"
    end
    if inCombat() then
        ClassPowerService.combatDeferredCount = ClassPowerService.combatDeferredCount + 1
        ClassPowerService.lastResultClass = "combatDeferred"
        return false, "combatDeferred"
    end

    if not Renderer then
        Renderer = EAM.UI.Renderer
    end
    local powerType = ClassPowerService.activePowerType
    local config = powerType and POWER_TYPE_CONFIGS[powerType] or nil
    if not powerType or not config or not configEnabled(config) then
        hideRenderedState()
        return false, "unavailable"
    end

    local resultClass, current = classifyPowerValue(powerType)
    ClassPowerService.lastResultClass = resultClass
    if resultClass ~= "safe-number" then
        if resultClass == "secret" then
            ClassPowerService.secretUpdateCount = ClassPowerService.secretUpdateCount + 1
        else
            ClassPowerService.unavailableUpdateCount = ClassPowerService.unavailableUpdateCount + 1
        end
        hideRenderedState()
        return false, resultClass
    end

    ClassPowerService.safeUpdateCount = ClassPowerService.safeUpdateCount + 1
    if current <= 0 then
        hideRenderedState()
        return true, "zero"
    end

    local id = "classPower_" .. powerType
    numericState.id = id
    numericState.kind = "classPower"
    numericState.spellID = powerType
    numericState.name = ClassPowerService.activeName
    numericState.icon = ClassPowerService.activeIcon
    numericState.stacks = nil
    numericState.displayValue = current
    numericState.active = true
    numericState.shown = true
    numericState.pandemicReady = ClassPowerService.overflowThreshold ~= nil
        and current >= ClassPowerService.overflowThreshold or false
    numericState.source.classification = "safe-number"
    numericState.source.selectedFrom = ClassPowerService.selectedFrom
    if Renderer and Renderer.render then
        Renderer.render(numericState, EAM.Constants.ALERT_FRAME_TYPES.classPower)
        lastRenderedID = id
    end
    return true, "rendered"
end

function ClassPowerService.onEvent(eventName, unit, powerTypeToken)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    if inCombat() then
        ClassPowerService.combatDeferredCount = ClassPowerService.combatDeferredCount + 1
        ClassPowerService.lastResultClass = "combatDeferred"
        return false, "combatDeferred"
    end

    if eventName == "UNIT_POWER_FREQUENT" then
        if unit ~= "player" then
            return
        end
        if Util.isSafeString(powerTypeToken)
            and ClassPowerService.activePowerToken
            and powerTypeToken ~= ClassPowerService.activePowerToken
        then
            return
        end
        ClassPowerService.updatePower()
        return
    end
    if eventName == "UNIT_MAXPOWER" then
        if unit ~= "player" then
            return
        end
        ClassPowerService.detectClassPower()
        ClassPowerService.updatePower()
        return
    end
    ClassPowerService.detectClassPower()
    ClassPowerService.updatePower()
end

function ClassPowerService.getActivePowerType()
    return ClassPowerService.activePowerType
end

function ClassPowerService.getStatus()
    return {
        active = ClassPowerService.activePowerType ~= nil,
        activePowerType = ClassPowerService.activePowerType,
        activePowerToken = ClassPowerService.activePowerToken,
        selectedFrom = ClassPowerService.selectedFrom,
        predicateAvailable = ClassPowerService.predicateAvailable,
        lastResultClass = ClassPowerService.lastResultClass,
        safeUpdateCount = ClassPowerService.safeUpdateCount,
        secretUpdateCount = ClassPowerService.secretUpdateCount,
        unavailableUpdateCount = ClassPowerService.unavailableUpdateCount,
        combatDeferredCount = ClassPowerService.combatDeferredCount,
        rawValuesExposed = false,
    }
end

function ClassPowerService.onModuleToggle(enabled, reason)
    if enabled == false then
        hideRenderedState()
        ClassPowerService.activePowerType = nil
        ClassPowerService.activePowerToken = nil
        ClassPowerService.activeConfigKey = nil
        ClassPowerService.overflowThreshold = nil
        ClassPowerService.selectedFrom = "moduleDisabled"
        ClassPowerService.lastResultClass = "moduleDisabled"
        return true, "disabled"
    end
    if inCombat() then
        ClassPowerService.lastResultClass = "combatDeferred"
        return false, "combatDeferred"
    end
    ClassPowerService.detectClassPower()
    return ClassPowerService.updatePower()
end

function ClassPowerService.initialize()
    Renderer = EAM.UI.Renderer
    ClassPowerService.detectClassPower()
    local router = EAM.Modules.EventRouter
    if router then
        router.register("UNIT_POWER_FREQUENT", ClassPowerService.onEvent)
        router.register("UNIT_MAXPOWER", ClassPowerService.onEvent)
        router.register("PLAYER_ENTERING_WORLD", ClassPowerService.onEvent)
        router.register("UPDATE_SHAPESHIFT_FORM", ClassPowerService.onEvent)
        router.register("PLAYER_TALENT_UPDATE", ClassPowerService.onEvent)
        router.register("PLAYER_SPECIALIZATION_CHANGED", ClassPowerService.onEvent)
        router.register("PLAYER_REGEN_ENABLED", ClassPowerService.onEvent)
    end
end
