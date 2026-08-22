--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/PlayerResourceCapability
檔案: Services\PlayerResourceCapability.lua

責任:
- 在冷路徑判斷指定 UnitPower 資源為 NUMERIC、SECRET_DISPLAY 或 UNAVAILABLE。
- 只回傳安全 metadata，不回傳任何即時資源值。

邊界:
- UnitHasPowerType 只作可用性判斷。
- 能力不明時 fail closed 到 SECRET_DISPLAY，避免先讀 raw value 再試錯。
]]
local _, EAM = ...

local api = EAM.API
local Util = EAM.Util

local Capability = {
    NUMERIC = "NUMERIC",
    SECRET_DISPLAY = "SECRET_DISPLAY",
    UNAVAILABLE = "UNAVAILABLE",
    RETAIL_121_SECRET = "RETAIL_121_SECRET",
    RETAIL_120_NUMERIC = "RETAIL_120_NUMERIC",
    UNSUPPORTED_CLIENT = "UNSUPPORTED_CLIENT",
}

EAM.Services.PlayerResourceCapability = Capability

local function resolveClientAdapter()
    if type(api.GetBuildInfo) ~= "function" then
        return Capability.RETAIL_121_SECRET, nil, "interfaceUnknownFailClosed"
    end

    local ok, _, _, _, interfaceVersion = pcall(api.GetBuildInfo)
    if not ok or not Util.isSafeNonNegativeNumber(interfaceVersion) then
        return Capability.RETAIL_121_SECRET, nil, "interfaceUnknownFailClosed"
    end

    if interfaceVersion >= 120000 and interfaceVersion < 120100 then
        return Capability.RETAIL_120_NUMERIC, interfaceVersion, "legacyRetail120"
    end
    if interfaceVersion >= 120100 then
        return Capability.RETAIL_121_SECRET, interfaceVersion, "retail121SecretAware"
    end
    return Capability.UNSUPPORTED_CLIENT, interfaceVersion, "unsupportedClient"
end

function Capability.getClientAdapter()
    return resolveClientAdapter()
end
local function safePredicate(name, powerType)
    local secrets = api.C_Secrets
    local predicate = secrets and secrets[name]
    if type(predicate) ~= "function" then
        return nil
    end
    local ok, result = pcall(predicate, "player", powerType)
    if ok and Util.isSafeBoolean(result) then
        return result
    end
    return nil
end

local function classifySecrecyLevel(powerType)
    local secrets = api.C_Secrets
    local getter = secrets and secrets.GetPowerTypeSecrecy
    local levels = api.SecrecyLevel
    if type(getter) ~= "function" or type(levels) ~= "table" then
        return nil
    end

    local ok, secrecy = pcall(getter, powerType)
    if not ok or not Util.isSafeValue(secrecy) then
        return nil
    end
    if secrecy == levels.NeverSecret then
        return Capability.NUMERIC
    end
    if secrecy == levels.AlwaysSecret or secrecy == levels.ContextuallySecret then
        return Capability.SECRET_DISPLAY
    end
    return nil
end

function Capability.classify(definition)
    if type(definition) ~= "table" or not Util.isSafeNonNegativeNumber(definition.powerType) then
        return Capability.UNAVAILABLE, "invalidDefinition"
    end
    if type(api.UnitHasPowerType) ~= "function" then
        return Capability.UNAVAILABLE, "unitHasPowerTypeUnavailable"
    end

    local ok, available = pcall(api.UnitHasPowerType, "player", definition.powerType)
    if not ok or not Util.isSafeBoolean(available) or available ~= true then
        return Capability.UNAVAILABLE, "powerTypeUnavailable"
    end

    local adapter = resolveClientAdapter()
    if adapter == Capability.UNSUPPORTED_CLIENT then
        return Capability.UNAVAILABLE, "unsupportedClient"
    end
    if adapter == Capability.RETAIL_120_NUMERIC then
        if type(api.UnitPower) == "function" and type(api.UnitPowerMax) == "function" then
            return Capability.NUMERIC, "legacyRetail120Numeric"
        end
        return Capability.UNAVAILABLE, "legacyNumericSourceUnavailable"
    end

    local curveConstants = api.CurveConstants    if type(api.UnitPowerPercent) ~= "function"
        or type(curveConstants) ~= "table"
        or curveConstants.ZeroToOne == nil
    then
        return Capability.UNAVAILABLE, "percentSinkSourceUnavailable"
    end

    local levelClass = classifySecrecyLevel(definition.powerType)
    if levelClass then
        return levelClass, "powerTypeSecrecy"
    end

    local powerSecret = safePredicate("ShouldUnitPowerBeSecret", definition.powerType)
    local maxSecret = safePredicate("ShouldUnitPowerMaxBeSecret", definition.powerType)
    if powerSecret == false and maxSecret == false then
        return Capability.NUMERIC, "predicatesSafe"
    end
    local reason = "secrecyUnknownFailClosed"
    if powerSecret == true or maxSecret == true then
        reason = "predicatesSecret"
    end
    return Capability.SECRET_DISPLAY, reason
end