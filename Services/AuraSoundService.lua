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
    retired = {},
    retiredCount = 0,
    retiredSequence = 0,
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

local function retainRetiredEntry(key, entry)
    AuraSoundService.retiredSequence = AuraSoundService.retiredSequence + 1
    local retiredKey = key .. "#" .. AuraSoundService.retiredSequence
    AuraSoundService.retired[retiredKey] = entry
    AuraSoundService.retiredCount = AuraSoundService.retiredCount + 1
end

local function clearRegistry(registry, retainFailures)
    local remaining = 0
    for key, entry in pairs(registry) do
        if unregisterEntry(entry) then
            registry[key] = nil
        elseif retainFailures then
            registry[key] = nil
            retainRetiredEntry(key, entry)
            appendLimitation("soundRemovalFailed:" .. key)
        else
            remaining = remaining + 1
            appendLimitation("soundRemovalFailed:" .. key)
        end
    end
    return remaining
end

local function retryRetired()
    AuraSoundService.retiredCount = clearRegistry(AuraSoundService.retired, false)
    return AuraSoundService.retiredCount == 0
end

local function buildSoundInfo(rule, soundConfig)
    if type(soundConfig) ~= "table" then
        return nil
    end
    local soundFileID = soundConfig.soundFileID
    local soundFileName = soundConfig.soundFileName
    local hasFileID = Util.isSafePositiveNumber(soundFileID)
    local hasFileName = Util.isSafeString(soundFileName) and soundFileName:find("%S") ~= nil
    if not hasFileID and not hasFileName then
        return nil
    end

    if (rule.unit ~= "player" and rule.unit ~= "target")
        or not Util.isSafePositiveNumber(rule.spellID)
        or rule.spellID % 1 ~= 0
    then
        return nil
    end

    local info = {
        unitToken = rule.unit,
        spellID = rule.spellID,
    }
    if hasFileID then
        info.soundFileID = soundFileID
    else
        info.soundFileName = soundFileName
    end
    if Util.isSafeString(soundConfig.outputChannel)
        and soundConfig.outputChannel:find("%S")
    then
        info.outputChannel = soundConfig.outputChannel
    end
    return info
end

local function registerEntry(key, rule, trigger, soundConfig)
    local cUnitAuras = EAM.API.C_UnitAuras
    local info = buildSoundInfo(rule, soundConfig)
    if not info then
        appendLimitation("soundConfigIncomplete:" .. key)
        return nil
    end
    local ok, registrationID = pcall(cUnitAuras.AddAuraSound, trigger, info)
    if not ok or not Util.isSafePositiveNumber(registrationID) then
        appendLimitation("soundRegistrationFailed:" .. key)
        return nil
    end
    return {
        registrationID = registrationID,
        alertID = rule.alertID,
    }
end

function AuraSoundService.sync(plan, capability)
    AuraSoundService.limitations = {}
    if not plan then
        appendLimitation("auraSoundPlanUnavailable")
        return false, "auraSoundPlanUnavailable"
    end
    if not capability or not capability.hasAuraSound or not capability.hasAuraSoundEnum then
        local removed = AuraSoundService.removeAll()
        appendLimitation("auraSoundUnavailable")
        if not removed then
            appendLimitation("auraSoundRemovalPending")
        end
        -- AuraSound 是選配能力；缺少它不可阻斷已通過 capability 的 Native Aura 視覺。
        return true, removed and "auraSoundUnavailable" or "auraSoundRemovalPending"
    end

    local fingerprint = plan.soundFingerprint or plan.fingerprint
    local retiredCleared = retryRetired()
    if AuraSoundService.lastFingerprint == fingerprint then
        if retiredCleared then
            return true, "unchanged"
        end
        return false, "soundRemovalPending"
    end

    local cUnitAuras = EAM.API.C_UnitAuras
    if not cUnitAuras or type(cUnitAuras.AddAuraSound) ~= "function" then
        appendLimitation("auraSoundUnavailable")
        return false, "auraSoundUnavailable"
    end

    local candidate = {}
    local candidateCount = 0
    local registrationFailed = false
    for ruleIndex = 1, #plan.soundRules do
        local rule = plan.soundRules[ruleIndex]
        local sound = rule.sound
        for keyIndex = 1, #SOUND_KEYS do
            local descriptor = SOUND_KEYS[keyIndex]
            local config = type(sound) == "table" and sound[descriptor.key] or nil
            local trigger = capability[descriptor.capabilityKey]
            if config and trigger ~= nil then
                local key = rule.alertID .. ":" .. descriptor.key
                local entry = registerEntry(key, rule, trigger, config)
                if entry then
                    candidate[key] = entry
                    candidateCount = candidateCount + 1
                else
                    registrationFailed = true
                end
            elseif config then
                appendLimitation("soundTriggerUnavailable:" .. rule.alertID .. ":" .. descriptor.key)
                registrationFailed = true
            end
        end
    end

    if registrationFailed then
        clearRegistry(candidate, true)
        return false, "soundRegistrationFailed"
    end

    clearRegistry(AuraSoundService.active, true)
    AuraSoundService.active = candidate
    AuraSoundService.activeCount = candidateCount
    AuraSoundService.lastFingerprint = fingerprint
    if AuraSoundService.retiredCount > 0 then
        return false, "soundRemovalPending"
    end
    return true, "registered"
end

function AuraSoundService.removeAll()
    retryRetired()
    clearRegistry(AuraSoundService.active, true)
    AuraSoundService.active = {}
    AuraSoundService.activeCount = 0
    AuraSoundService.lastFingerprint = nil
    return AuraSoundService.retiredCount == 0
end

function AuraSoundService.getStatus()
    return {
        activeCount = AuraSoundService.activeCount,
        retiredCount = AuraSoundService.retiredCount,
        limitations = AuraSoundService.limitations,
        lastFingerprint = AuraSoundService.lastFingerprint,
    }
end
