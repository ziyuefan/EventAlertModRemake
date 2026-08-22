--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Core/DurationAdapter
檔案: Core\DurationAdapter.lua

責任:
- 依 12.x 契約建立已設定時間範圍的 DurationObject。
- 建立、設定與停用 DurationTextBinding，避免服務與 Renderer 重複實作生命週期。

邊界:
- 只接受已確認安全的普通數字作為自訂時間，不讀 Aura、Cooldown 或 Item facts。
- Secret DurationObject 只原樣交給 Blizzard binding/widget，不讀取、不比較、不序列化。
]]

local _, EAM = ...

local api = EAM.API
local Util = EAM.Util

local DurationAdapter = {
    createAttempts = 0,
    createSuccesses = 0,
    bindingAttempts = 0,
    bindingSuccesses = 0,
    bindingFailures = 0,
    lastFailure = nil,
}

EAM.Modules.DurationAdapter = DurationAdapter

local secondsFormatter = nil
local formatterUnavailable = false

local function recordFailure(reason)
    DurationAdapter.lastFailure = reason
    return nil, reason
end

local function getSecondsFormatter()
    if secondsFormatter then
        return secondsFormatter
    end
    if formatterUnavailable then
        return nil
    end

    local cStringUtil = api.C_StringUtil
    if not cStringUtil or type(cStringUtil.CreateSecondsFormatter) ~= "function" then
        formatterUnavailable = true
        return nil
    end

    local ok, formatter = pcall(cStringUtil.CreateSecondsFormatter)
    if not ok or not formatter then
        formatterUnavailable = true
        return nil
    end

    local abbreviation = api.SecondsFormatterAbbreviation
    if type(formatter.SetDefaultAbbreviation) == "function"
        and abbreviation
        and abbreviation.OneLetter ~= nil
    then
        pcall(formatter.SetDefaultAbbreviation, formatter, abbreviation.OneLetter)
    end

    local whitespace = api.SecondsFormatterIntervalWhitespace
    if type(formatter.SetStripIntervalWhitespace) == "function"
        and whitespace
        and whitespace.Strip ~= nil
    then
        pcall(formatter.SetStripIntervalWhitespace, formatter, whitespace.Strip)
    end

    if type(formatter.SetMillisecondsThreshold) == "function" then
        pcall(formatter.SetMillisecondsThreshold, formatter, 3)
    end

    secondsFormatter = formatter
    return formatter
end

function DurationAdapter.createFromStart(startTime, duration)
    DurationAdapter.createAttempts = DurationAdapter.createAttempts + 1
    if not Util.isSafeNumber(startTime) or not Util.isSafePositiveNumber(duration) then
        return recordFailure("invalidNumericDuration")
    end

    local durationUtil = api.C_DurationUtil
    if not durationUtil or type(durationUtil.CreateDuration) ~= "function" then
        return recordFailure("durationFactoryUnavailable")
    end

    local ok, durationObject = pcall(durationUtil.CreateDuration)
    if not ok or not durationObject then
        return recordFailure("durationFactoryFailed")
    end
    if type(durationObject.SetTimeFromStart) ~= "function" then
        return recordFailure("setTimeFromStartUnavailable")
    end

    local configured = pcall(durationObject.SetTimeFromStart, durationObject, startTime, duration)
    if not configured then
        return recordFailure("setTimeFromStartFailed")
    end

    DurationAdapter.createSuccesses = DurationAdapter.createSuccesses + 1
    DurationAdapter.lastFailure = nil
    return durationObject
end

function DurationAdapter.createTextBinding(durationObject, fontString)
    DurationAdapter.bindingAttempts = DurationAdapter.bindingAttempts + 1
    local durationUtil = api.C_DurationUtil
    if not durationObject or not fontString
        or not durationUtil
        or type(durationUtil.CreateDurationTextBinding) ~= "function"
    then
        DurationAdapter.bindingFailures = DurationAdapter.bindingFailures + 1
        return recordFailure("durationTextBindingUnavailable")
    end

    local formatter = getSecondsFormatter()
    if not formatter then
        DurationAdapter.bindingFailures = DurationAdapter.bindingFailures + 1
        return recordFailure("secondsFormatterUnavailable")
    end

    local ok, binding = pcall(durationUtil.CreateDurationTextBinding)
    if not ok or not binding
        or type(binding.SetFontString) ~= "function"
        or type(binding.SetDuration) ~= "function"
        or type(binding.SetFormatter) ~= "function"
    then
        DurationAdapter.bindingFailures = DurationAdapter.bindingFailures + 1
        return recordFailure("durationTextBindingIncomplete")
    end

    local configured = pcall(binding.SetFontString, binding, fontString)
        and pcall(binding.SetDuration, binding, durationObject)
        and pcall(binding.SetFormatter, binding, formatter)
    if not configured then
        DurationAdapter.bindingFailures = DurationAdapter.bindingFailures + 1
        DurationAdapter.releaseTextBinding(binding)
        return recordFailure("durationTextBindingConfigureFailed")
    end

    if type(binding.SetZeroDurationText) == "function" then
        pcall(binding.SetZeroDurationText, binding, "")
    end
    if type(binding.SetExpiredText) == "function" then
        pcall(binding.SetExpiredText, binding, "")
    end

    local enabled = false
    if type(binding.SetEnabled) == "function" then
        enabled = pcall(binding.SetEnabled, binding, true)
    elseif type(binding.Enable) == "function" then
        enabled = pcall(binding.Enable, binding)
    end
    if not enabled then
        DurationAdapter.bindingFailures = DurationAdapter.bindingFailures + 1
        DurationAdapter.releaseTextBinding(binding)
        return recordFailure("durationTextBindingEnableFailed")
    end

    DurationAdapter.bindingSuccesses = DurationAdapter.bindingSuccesses + 1
    DurationAdapter.lastFailure = nil
    return binding
end

function DurationAdapter.releaseTextBinding(binding)
    if not binding then
        return false
    end
    if type(binding.Disable) == "function" then
        pcall(binding.Disable, binding)
    elseif type(binding.SetEnabled) == "function" then
        pcall(binding.SetEnabled, binding, false)
    end
    if type(binding.SetToDefaults) == "function" then
        pcall(binding.SetToDefaults, binding)
    end
    return true
end

function DurationAdapter.getStatus()
    return {
        createAttempts = DurationAdapter.createAttempts,
        createSuccesses = DurationAdapter.createSuccesses,
        bindingAttempts = DurationAdapter.bindingAttempts,
        bindingSuccesses = DurationAdapter.bindingSuccesses,
        bindingFailures = DurationAdapter.bindingFailures,
        formatterAvailable = getSecondsFormatter() ~= nil,
        lastFailure = DurationAdapter.lastFailure,
    }
end
