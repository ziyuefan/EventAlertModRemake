--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/AuraCapabilityService
檔案: Services\AuraCapabilityService.lua

理念:
- 將 12.1 AuraContainer 能力探測與後端選擇集中管理。
- Interface 只作初篩；真正啟用 Native 前仍需以實體 AuraContainer 驗證公開方法。

責任:
- 記錄客戶端 build、AuraContainer、AuraSlot、AuraGroup 與 AuraSound 能力。
- 12.1 探測失敗時選擇 Unsupported，禁止偷偷回退到 Secret AuraData 舊路徑。

資料所有權:
- 只擁有冷路徑 capability snapshot；不擁有 AuraContainer 或 SavedVariables。

邊界:
- 不讀 AuraData、不註冊 UNIT_AURA、不推導 Aura 狀態。
- 實體 frame 建立由 AuraContainerService 負責。
]]
local _, EAM = ...

local api = EAM.API
local Constants = EAM.Constants

local AuraCapabilityService = {
    initialized = false,
    clientInterface = 0,
    clientVersion = nil,
    clientBuild = nil,
    hasAuraContainer = false,
    hasAuraGroup = false,
    hasAuraSlot = false,
    hasAuraGroupLayout = false,
    hasAuraSound = false,
    hasAuraSoundEnum = false,
    hasDurationObject = false,
    clientIsPublicTest = false,
    clientIsTestBuild = false,
    clientIsBetaBuild = false,
    testBuildKnown = false,
    nativeRuntimeAllowed = false,
    canUseSpellIDCandidateFilter = false,
    spellIDCandidateFilterRestricted = true,
    selectedBackend = Constants.AURA_BACKEND_UNSUPPORTED,
    limitationReason = "notInitialized",
}

EAM.Services.AuraCapabilityService = AuraCapabilityService

local function hasMethod(owner, methodName)
    return owner ~= nil and type(owner[methodName]) == "function"
end

local function callBoolean(callback)
    if type(callback) ~= "function" then
        return false
    end
    local ok, value = pcall(callback)
    return ok and value == true
end

function AuraCapabilityService.initialize()
    if AuraCapabilityService.initialized then
        return
    end
    local version, build, _, interfaceVersion
    if api.GetBuildInfo then
        version, build, _, interfaceVersion = api.GetBuildInfo()
    end

    AuraCapabilityService.clientVersion = version
    AuraCapabilityService.clientBuild = build
    AuraCapabilityService.clientInterface = tonumber(interfaceVersion) or 0
    AuraCapabilityService.clientIsPublicTest = callBoolean(api.IsPublicTestClient)
    AuraCapabilityService.clientIsTestBuild = callBoolean(api.IsTestBuild)
    AuraCapabilityService.clientIsBetaBuild = callBoolean(api.IsBetaBuild)
    AuraCapabilityService.testBuildKnown = type(api.IsPublicTestClient) == "function"
        and type(api.IsTestBuild) == "function"
        and type(api.IsBetaBuild) == "function"
    -- 12.1 正式服與 PTR 共用 Native Aura；test flags 只辨識通道，不是能力授權。
    AuraCapabilityService.nativeRuntimeAllowed = AuraCapabilityService.clientInterface >= Constants.INTERFACE

    local unitAuras = api.C_UnitAuras
    AuraCapabilityService.hasAuraSound = type(unitAuras) == "table"
        and type(unitAuras.AddAuraSound) == "function"
        and type(unitAuras.RemoveAuraSound) == "function"

    local enumTable = Enum and Enum.UnitAuraSoundTrigger
    AuraCapabilityService.hasAuraSoundEnum = type(enumTable) == "table"
        and enumTable.Added ~= nil
        and enumTable.ApplicationsIncreased ~= nil
        and enumTable.Removed ~= nil
    AuraCapabilityService.soundTriggerAdded = enumTable and enumTable.Added or nil
    AuraCapabilityService.soundTriggerApplicationsIncreased = enumTable and enumTable.ApplicationsIncreased or nil
    AuraCapabilityService.soundTriggerRemoved = enumTable and enumTable.Removed or nil
    AuraCapabilityService.hasDurationObject = type(api.C_DurationUtil) == "table"
        and type(api.C_DurationUtil.CreateDuration) == "function"

    if AuraCapabilityService.clientInterface >= Constants.INTERFACE then
        AuraCapabilityService.selectedBackend = Constants.AURA_BACKEND_UNSUPPORTED
        AuraCapabilityService.limitationReason = "containerProbePending"
    else
        AuraCapabilityService.selectedBackend = Constants.AURA_BACKEND_LEGACY
        AuraCapabilityService.limitationReason = nil
    end
    AuraCapabilityService.initialized = true
end

function AuraCapabilityService.acceptContainer(container)
    AuraCapabilityService.hasAuraContainer = container ~= nil
        and hasMethod(container, "SetUnit")
        and hasMethod(container, "SetEnabled")
    AuraCapabilityService.hasAuraGroup = hasMethod(container, "AddAuraGroup")
    AuraCapabilityService.hasAuraSlot = hasMethod(container, "AddAuraSlot")
    AuraCapabilityService.hasAuraGroupLayout = hasMethod(container, "SetAuraGroupLayout")

    if AuraCapabilityService.clientInterface >= Constants.INTERFACE
        and AuraCapabilityService.nativeRuntimeAllowed
        and AuraCapabilityService.hasAuraContainer
        and AuraCapabilityService.hasAuraGroup
        and AuraCapabilityService.hasAuraSlot
        and AuraCapabilityService.hasAuraGroupLayout then
        AuraCapabilityService.selectedBackend = Constants.AURA_BACKEND_NATIVE
        AuraCapabilityService.canUseSpellIDCandidateFilter = true
        AuraCapabilityService.limitationReason = nil
        return true
    end

    AuraCapabilityService.selectedBackend = AuraCapabilityService.clientInterface < Constants.INTERFACE
        and Constants.AURA_BACKEND_LEGACY
        or Constants.AURA_BACKEND_UNSUPPORTED
    AuraCapabilityService.limitationReason = "nativeContainerContractMissing"

    AuraCapabilityService.canUseSpellIDCandidateFilter = false
    return false
end

function AuraCapabilityService.rejectContainer(reason)
    AuraCapabilityService.hasAuraContainer = false
    AuraCapabilityService.hasAuraGroup = false
    AuraCapabilityService.hasAuraSlot = false
    AuraCapabilityService.hasAuraGroupLayout = false
    AuraCapabilityService.selectedBackend = AuraCapabilityService.clientInterface < Constants.INTERFACE
        and Constants.AURA_BACKEND_LEGACY
        or Constants.AURA_BACKEND_UNSUPPORTED
    AuraCapabilityService.limitationReason = reason or "nativeContainerCreationFailed"
    AuraCapabilityService.canUseSpellIDCandidateFilter = false
end

function AuraCapabilityService.isNative()
    return AuraCapabilityService.selectedBackend == Constants.AURA_BACKEND_NATIVE
end

function AuraCapabilityService.isLegacy()
    return AuraCapabilityService.selectedBackend == Constants.AURA_BACKEND_LEGACY
end

function AuraCapabilityService.getAuraFilters()
    return Constants.AURA_FILTERS or {}
end

function AuraCapabilityService.isValidFilterString(filterString)
    if type(filterString) ~= "string" or filterString == "" then
        return false, "empty"
    end
    if type(AuraUtil) == "table" and type(AuraUtil.IsValidFilterString) == "function" then
        local ok, valid, err = pcall(AuraUtil.IsValidFilterString, filterString)
        if ok then
            return valid, err
        end
    end
    local filters = Constants.AURA_FILTERS
    if not filters then
        return true
    end
    for component in string.gmatch(filterString, "[^|%s]+") do
        local token = component
        if string.sub(token, 1, 1) == "!" then
            token = string.sub(token, 2)
            if token == "" then
                return false, "emptyNegation"
            end
        end
        if token ~= "" and not filters[token] then
            -- Also check if token matches any filter value
            local matched = false
            for _, val in pairs(filters) do
                if val == token or val == ("!" .. token) then
                    matched = true
                    break
                end
            end
            if not matched then
                return false, "invalidToken:" .. token
            end
        end
    end
    return true
end

function AuraCapabilityService.getSnapshot()
    return {
        clientInterface = AuraCapabilityService.clientInterface,
        clientVersion = AuraCapabilityService.clientVersion,
        clientBuild = AuraCapabilityService.clientBuild,
        hasAuraContainer = AuraCapabilityService.hasAuraContainer,
        hasAuraGroup = AuraCapabilityService.hasAuraGroup,
        hasAuraSlot = AuraCapabilityService.hasAuraSlot,
        hasAuraGroupLayout = AuraCapabilityService.hasAuraGroupLayout,
        hasAuraSound = AuraCapabilityService.hasAuraSound,
        hasAuraSoundEnum = AuraCapabilityService.hasAuraSoundEnum,
        hasDurationObject = AuraCapabilityService.hasDurationObject,
        clientIsPublicTest = AuraCapabilityService.clientIsPublicTest,
        clientIsTestBuild = AuraCapabilityService.clientIsTestBuild,
        clientIsBetaBuild = AuraCapabilityService.clientIsBetaBuild,
        testBuildKnown = AuraCapabilityService.testBuildKnown,
        nativeRuntimeAllowed = AuraCapabilityService.nativeRuntimeAllowed,
        canUseSpellIDCandidateFilter = AuraCapabilityService.canUseSpellIDCandidateFilter,
        spellIDCandidateFilterRestricted = AuraCapabilityService.spellIDCandidateFilterRestricted,
        soundTriggerAdded = AuraCapabilityService.soundTriggerAdded,
        soundTriggerApplicationsIncreased = AuraCapabilityService.soundTriggerApplicationsIncreased,
        soundTriggerRemoved = AuraCapabilityService.soundTriggerRemoved,
        backend = AuraCapabilityService.selectedBackend,
        reason = AuraCapabilityService.limitationReason,
        selectedBackend = AuraCapabilityService.selectedBackend,
        limitationReason = AuraCapabilityService.limitationReason,
    }
end
