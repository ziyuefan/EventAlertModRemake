--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/ValidationEnvironment
檔案: Debug\ValidationEnvironment.lua

理念:
- 將系統觀測的 build/interface 與玩家宣告的安裝目錄分欄，避免 PTR、XPTR、正式服互相誤標。

責任:
- 讀取 GetBuildInfo 與 test-build flags，保存玩家宣告的 client directory，產生去識別環境證據。

資料邊界:
- 不讀帳號、角色、伺服器、WTF 路徑或遊戲狀態原值。
- client directory 無法由 AddOn sandbox 可靠取得，只能標記為 user-asserted。
]]
local _, EAM = ...

local api = EAM.API or {}
local util = EAM.Util or {}
local freeze = util.tableFreeze or function(value)
    return value
end

local PROFILES = freeze({
    ["_ptr_"] = freeze({
        channel = "PTR",
        source = "ptr-live-manual",
        expectedPatch = "12.1.0",
        expectedInterface = 120100,
        expectedTestBuild = true,
    }),
    ["_xptr_"] = freeze({
        channel = "XPTR",
        source = "xptr-live-manual",
        expectedPatch = "12.0.7",
        expectedInterface = 120007,
        expectedTestBuild = true,
    }),
    ["_retail_"] = freeze({
        channel = "RETAIL",
        source = "retail-live-manual",
        expectedPatch = "12.0.7",
        expectedInterface = 120007,
        expectedTestBuild = false,
    }),
})

local ValidationEnvironment = {
    schemaVersion = 1,
    profiles = PROFILES,
}

EAM.Debug.ValidationEnvironment = ValidationEnvironment

local function safeScalar(value)
    if value == nil then
        return nil
    end
    if util.isSecretValue and util.isSecretValue(value) then
        return nil
    end
    if util.canAccessValue and not util.canAccessValue(value) then
        return nil
    end
    local valueType = type(value)
    if valueType == "string" or valueType == "number" or valueType == "boolean" then
        return value
    end
    return nil
end

local function callBoolean(callback)
    if type(callback) ~= "function" then
        return nil
    end
    local ok, value = pcall(callback)
    if not ok or type(value) ~= "boolean" then
        return nil
    end
    return value
end

local function detectTestBuild()
    local publicTest = callBoolean(api.IsPublicTestClient)
    local testBuild = callBoolean(api.IsTestBuild)
    local betaBuild = callBoolean(api.IsBetaBuild)
    local known = publicTest ~= nil or testBuild ~= nil or betaBuild ~= nil
    local value = publicTest == true or testBuild == true or betaBuild == true
    return known, value, {
        isPublicTestClient = publicTest == nil and "unknown" or publicTest,
        isTestBuild = testBuild == nil and "unknown" or testBuild,
        isBetaBuild = betaBuild == nil and "unknown" or betaBuild,
    }
end

local function getObservedBuild()
    local patch = "unknown"
    local build = "unknown"
    local buildDate = "unknown"
    local interface = 0
    if type(api.GetBuildInfo) == "function" then
        local ok, observedPatch, observedBuild, observedDate, observedInterface = pcall(api.GetBuildInfo)
        if ok then
            patch = safeScalar(observedPatch) or patch
            build = safeScalar(observedBuild) or build
            buildDate = safeScalar(observedDate) or buildDate
            interface = safeScalar(observedInterface) or interface
        end
    end
    return patch, build, buildDate, interface
end

local function currentProfile()
    local profile = _G.EAM_VALIDATION_PROFILE
    if type(profile) ~= "table" or profile.schema ~= ValidationEnvironment.schemaVersion then
        return nil
    end
    if profile.confirmed ~= true or not PROFILES[profile.declaredInstallation] then
        return nil
    end
    return profile
end

function ValidationEnvironment.setDeclaredInstallation(declaredInstallation)
    if not PROFILES[declaredInstallation] then
        return false, "invalidInstallation"
    end
    _G.EAM_VALIDATION_PROFILE = {
        schema = ValidationEnvironment.schemaVersion,
        declaredInstallation = declaredInstallation,
        confirmed = true,
    }
    return true, declaredInstallation
end

function ValidationEnvironment.getDeclaredInstallation()
    local profile = currentProfile()
    return profile and profile.declaredInstallation or nil
end

function ValidationEnvironment.snapshot()
    local patch, build, buildDate, interface = getObservedBuild()
    local testBuildKnown, isTestBuild, buildFlags = detectTestBuild()
    local locale = type(api.GetLocale) == "function" and safeScalar(api.GetLocale()) or nil
    local projectID = safeScalar(api.WOW_PROJECT_ID)

    if EAM.FlowTestEnvironment == "offline-mock" then
        return {
            product = "wow_retail",
            executionSource = "offline-mock",
            clientChannel = "OFFLINE",
            declaredInstallation = "offline",
            declaredInstallationEvidence = "harness",
            patch = patch,
            build = build,
            buildDate = buildDate,
            interface = interface,
            targetInterface = EAM.Constants.INTERFACE,
            projectID = projectID,
            isTestBuild = isTestBuild,
            isTestBuildKnown = testBuildKnown,
            buildFlags = buildFlags,
            locale = locale or "unknown",
            source = "offline-mock",
            channelValidation = "pass",
        }, {}
    end

    local profile = currentProfile()
    local declaredInstallation = profile and profile.declaredInstallation or "unconfirmed"
    local expected = profile and PROFILES[declaredInstallation] or nil
    local warnings = {}
    local validation = "pass"
    if not expected then
        validation = "unconfirmed"
        warnings[#warnings + 1] = "clientInstallationUnconfirmed"
    else
        if patch ~= expected.expectedPatch then
            validation = "mismatch"
            warnings[#warnings + 1] = "clientPatchMismatch"
        end
        if interface ~= expected.expectedInterface then
            validation = "mismatch"
            warnings[#warnings + 1] = "clientInterfaceMismatch"
        end
        if testBuildKnown and isTestBuild ~= expected.expectedTestBuild then
            validation = "mismatch"
            warnings[#warnings + 1] = "clientTestBuildMismatch"
        elseif not testBuildKnown then
            warnings[#warnings + 1] = "testBuildFlagUnavailable"
        end
    end

    return {
        product = "wow_retail",
        executionSource = "client",
        clientChannel = expected and expected.channel or "UNCONFIRMED",
        declaredInstallation = declaredInstallation,
        declaredInstallationEvidence = expected and "user-asserted" or "none",
        patch = patch,
        build = build,
        buildDate = buildDate,
        interface = interface,
        targetInterface = EAM.Constants.INTERFACE,
        projectID = projectID,
        isTestBuild = isTestBuild,
        isTestBuildKnown = testBuildKnown,
        buildFlags = buildFlags,
        locale = locale or "unknown",
        source = expected and expected.source or "client-unconfirmed",
        channelValidation = validation,
    }, warnings
end
