--[[ EAM_FILE_COMMENTARY
Module: Services/AuraSoundService

責任:
- 依編譯後的普通設定值註冊與解除 12.1 C_UnitAuras Aura Sound。
- 精確管理 Added、ApplicationsIncreased、Removed 的註冊 ID 生命週期。

邊界:
- 不讀 AuraData、不推導 Aura 狀態；API 缺失或參數不完整時只回報 limitation。
]]

local _, EAM = ...
local Util = EAM.Util

local AuraSoundService = {
    active = {},
    activeCount = 0,
    lastFingerprint = nil,
    limitations = {},
}

EAM.Services.AuraSoundService = AuraSoundService

local SOUND_KEYS = {
    { key = "added", capabilityKey = "soundTriggerAdded" },
    { key = "applicationsIncreased", capabilityKey = "soundTriggerApplicationsIncreased" },
    { key = "removed", capabilityKey = "soundTriggerRemoved" },
}

local function appendLimitation(code)
    AuraSoundService.limitations[#AuraSoundService.limitations + 1] = code
end

local function unregisterEntry(entry)
    local cUnitAuras = EAM.API.C_UnitAuras
    if not entry or not cUnitAuras or type(cUnitAuras.RemoveAuraSound) ~= "function" then
        return false
    end
    local ok = pcall(cUnitAuras.RemoveAuraSound, entry.registrationID)
    return ok
end

local function buildSoundInfo(rule, soundConfig)
    if type(soundConfig) ~= "table" then
        return nil
    end
    local soundFileID = soundConfig.soundFileID
    local soundFileName = soundConfig.soundFileName
    if not Util.isSafePositiveNumber(soundFileID) and not Util.isSafeString(soundFileName) then
        return nil
    end

    local info = {
        unitToken = rule.unit,
        spellID = rule.spellID,
    }
    if Util.isSafePositiveNumber(soundFileID) then
        info.soundFileID = soundFileID
    else
        info.soundFileName = soundFileName
    end
    if Util.isSafeString(soundConfig.outputChannel) then
        info.outputChannel = soundConfig.outputChannel
    end
    return info
end

local function registerEntry(key, rule, trigger, soundConfig)
    local cUnitAuras = EAM.API.C_UnitAuras
    local info = buildSoundInfo(rule, soundConfig)
    if not info then
        appendLimitation("soundConfigIncomplete:" .. key)
        return
    end
    local ok, registrationID = pcall(cUnitAuras.AddAuraSound, trigger, info)
    if not ok or not Util.isSafePositiveNumber(registrationID) then
        appendLimitation("soundRegistrationFailed:" .. key)
        return
    end
    AuraSoundService.active[key] = {
        registrationID = registrationID,
        alertID = rule.alertID,
    }
    AuraSoundService.activeCount = AuraSoundService.activeCount + 1
end

function AuraSoundService.sync(plan, capability)
    if not plan or not capability or not capability.hasAuraSound then
        AuraSoundService.removeAll()
        appendLimitation("auraSoundUnavailable")
        return false, "auraSoundUnavailable"
    end
    if AuraSoundService.lastFingerprint == plan.fingerprint then
        return true, "unchanged"
    end

    AuraSoundService.removeAll()
    AuraSoundService.limitations = {}
    local cUnitAuras = EAM.API.C_UnitAuras
    if not cUnitAuras or type(cUnitAuras.AddAuraSound) ~= "function" then
        appendLimitation("auraSoundUnavailable")
        return false, "auraSoundUnavailable"
    end

    for ruleIndex = 1, #plan.soundRules do
        local rule = plan.soundRules[ruleIndex]
        local sound = rule.sound
        for keyIndex = 1, #SOUND_KEYS do
            local descriptor = SOUND_KEYS[keyIndex]
            local config = type(sound) == "table" and sound[descriptor.key] or nil
            local trigger = capability[descriptor.capabilityKey]
            if config and trigger ~= nil then
                local key = rule.alertID .. ":" .. descriptor.key
                registerEntry(key, rule, trigger, config)
            end
        end
    end

    AuraSoundService.lastFingerprint = plan.fingerprint
    return true, "registered"
end

function AuraSoundService.removeAll()
    for key, entry in pairs(AuraSoundService.active) do
        unregisterEntry(entry)
        AuraSoundService.active[key] = nil
    end
    AuraSoundService.activeCount = 0
    AuraSoundService.lastFingerprint = nil
end

function AuraSoundService.getStatus()
    return {
        activeCount = AuraSoundService.activeCount,
        limitations = AuraSoundService.limitations,
        lastFingerprint = AuraSoundService.lastFingerprint,
    }
end
