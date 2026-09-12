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

local activeBindings = setmetatable({}, { __mode = "k" })
local bindingCustomCurves = setmetatable({}, { __mode = "k" })
local cachedColorCurve = nil
local colorCurveDirty = true

local function createColorWrapper(colorTable, defaultR, defaultG, defaultB, defaultA)
    local r = (colorTable and tonumber(colorTable[1])) or defaultR or 1
    local g = (colorTable and tonumber(colorTable[2])) or defaultG or 1
    local b = (colorTable and tonumber(colorTable[3])) or defaultB or 1
    local a = (colorTable and tonumber(colorTable[4])) or defaultA or 1
    if _G.CreateColor then
        return _G.CreateColor(r, g, b, a)
    end
    return { r = r, g = g, b = b, a = a, GetRGBA = function() return r, g, b, a end }
end

function DurationAdapter.buildColorCurve(config)
    local cCurveUtil = api.C_CurveUtil or _G.C_CurveUtil
    if not cCurveUtil or type(cCurveUtil.CreateColorCurve) ~= "function" then
        return nil
    end

    local ok, curve = pcall(cCurveUtil.CreateColorCurve)
    if not ok or not curve or type(curve.AddPoint) ~= "function" then
        return nil
    end

    local curveType = api.LuaCurveType or (_G.Enum and _G.Enum.LuaCurveType)
    if curveType and curveType.Step and type(curve.SetType) == "function" then
        pcall(curve.SetType, curve, curveType.Step)
    end

    local tcc = config and config.timerColorCurve
    if not tcc or tcc.enabled == false then
        return nil
    end

    local stages = tcc.stages or {
        { threshold = 3, color = { 1.0, 0.15, 0.15, 1.0 } },
        { threshold = 5, color = { 1.0, 0.82, 0.0, 1.0 } },
    }
    local normalColor = createColorWrapper(tcc.normalColor, 1.0, 1.0, 1.0, 1.0)

    -- 依照 threshold 排序
    local sortedStages = {}
    for i = 1, #stages do
        local s = stages[i]
        if s and s.threshold then
            table.insert(sortedStages, {
                threshold = tonumber(s.threshold) or 0,
                color = createColorWrapper(s.color, 1.0, 0.2, 0.2, 1.0),
            })
        end
    end
    table.sort(sortedStages, function(a, b) return a.threshold < b.threshold end)

    -- 加入關鍵點（雙點防衛邊界）
    local lastX = 0
    for i = 1, #sortedStages do
        local st = sortedStages[i]
        local th = math.max(st.threshold, 0.1)
        pcall(curve.AddPoint, curve, lastX, st.color)
        pcall(curve.AddPoint, curve, th, st.color)
        lastX = th + 0.001
    end

    -- 正常階段（超過所有階段閾值）
    pcall(curve.AddPoint, curve, lastX, normalColor)
    pcall(curve.AddPoint, curve, 99999, normalColor)

    return curve
end

function DurationAdapter.buildSpellColorCurve(redLimit, redColor, normalColor)
    local cCurveUtil = api.C_CurveUtil or _G.C_CurveUtil
    if not cCurveUtil or type(cCurveUtil.CreateColorCurve) ~= "function" then
        return nil
    end

    local ok, curve = pcall(cCurveUtil.CreateColorCurve)
    if not ok or not curve or type(curve.AddPoint) ~= "function" then
        return nil
    end

    local curveType = api.LuaCurveType or (_G.Enum and _G.Enum.LuaCurveType)
    if curveType and curveType.Step and type(curve.SetType) == "function" then
        pcall(curve.SetType, curve, curveType.Step)
    end

    local alertColor = createColorWrapper(redColor, 1.0, 0.15, 0.15, 1.0)
    local normColor = createColorWrapper(normalColor, 1.0, 1.0, 1.0, 1.0)
    local th = math.max(tonumber(redLimit) or 0, 0.1)

    pcall(curve.AddPoint, curve, 0, alertColor)
    pcall(curve.AddPoint, curve, th, alertColor)
    pcall(curve.AddPoint, curve, th + 0.001, normColor)
    pcall(curve.AddPoint, curve, 99999, normColor)

    return curve
end

function DurationAdapter.buildResourceDynamicColorCurve(baseColor, isReverse)
    local cCurveUtil = api.C_CurveUtil or _G.C_CurveUtil
    if not cCurveUtil or type(cCurveUtil.CreateColorCurve) ~= "function" then
        return nil
    end

    local ok, curve = pcall(cCurveUtil.CreateColorCurve)
    if not ok or not curve or type(curve.AddPoint) ~= "function" then
        return nil
    end

    local curveType = api.LuaCurveType or (_G.Enum and _G.Enum.LuaCurveType)
    if curveType and curveType.Linear and type(curve.SetType) == "function" then
        pcall(curve.SetType, curve, curveType.Linear)
    end

    local normColor = createColorWrapper(baseColor, 0.2, 0.8, 0.2, 1.0)
    local warnColor = createColorWrapper({ 1.0, 0.82, 0.15, 1.0 }, 1.0, 0.82, 0.15, 1.0)
    local alertColor = createColorWrapper({ 1.0, 0.2, 0.2, 1.0 }, 1.0, 0.2, 0.2, 1.0)
    local dimColor = createColorWrapper({ 0.35, 0.35, 0.35, 0.8 }, 0.35, 0.35, 0.35, 0.8)

    if isReverse then
        pcall(curve.AddPoint, curve, 0.0, dimColor)
        pcall(curve.AddPoint, curve, 0.5, warnColor)
        pcall(curve.AddPoint, curve, 1.0, normColor)
    else
        pcall(curve.AddPoint, curve, 0.0, alertColor)
        pcall(curve.AddPoint, curve, 0.3, alertColor)
        pcall(curve.AddPoint, curve, 0.6, warnColor)
        pcall(curve.AddPoint, curve, 1.0, normColor)
    end

    return curve
end

function DurationAdapter.getActiveColorCurve()
    if not colorCurveDirty and cachedColorCurve ~= nil then
        return cachedColorCurve
    end
    local cfg = EAM.db and EAM.db.config
    cachedColorCurve = DurationAdapter.buildColorCurve(cfg)
    colorCurveDirty = false
    return cachedColorCurve
end

function DurationAdapter.markColorCurveDirty()
    colorCurveDirty = true
    cachedColorCurve = nil
end

function DurationAdapter.refreshActiveBindingsColorCurve()
    DurationAdapter.markColorCurveDirty()
    local globalCurve = DurationAdapter.getActiveColorCurve()
    local bindingPropEnum = api.DurationTextBindingProperty or (_G.Enum and _G.Enum.DurationTextBindingProperty)
    local prop = (bindingPropEnum and bindingPropEnum.RemainingDuration) or 0

    for binding in pairs(activeBindings) do
        if binding then
            local curve = bindingCustomCurves[binding] or globalCurve
            if curve then
                pcall(binding.SetTextColorCurve, binding, curve, prop)
            elseif type(binding.ClearTextColorCurve) == "function" then
                pcall(binding.ClearTextColorCurve, binding)
            end
            if type(binding.UpdateFontString) == "function" then
                pcall(binding.UpdateFontString, binding)
            end
        end
    end
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

    local cCurveUtil = api.C_CurveUtil or _G.C_CurveUtil
    if cCurveUtil and type(cCurveUtil.CreateCurve) == "function" and type(formatter.SetDesiredUnitCountCurve) == "function" then
        local unitCurve = cCurveUtil.CreateCurve()
        local curveType = api.LuaCurveType or (_G.Enum and _G.Enum.LuaCurveType)
        if curveType and curveType.Step and type(unitCurve.SetType) == "function" then
            pcall(unitCurve.SetType, unitCurve, curveType.Step)
        end
        pcall(unitCurve.AddPoint, unitCurve, 0.0, 2.0)
        pcall(unitCurve.AddPoint, unitCurve, 5.0, 2.0)
        pcall(unitCurve.AddPoint, unitCurve, 5.001, 1.0)
        pcall(unitCurve.AddPoint, unitCurve, 99999, 1.0)
        pcall(formatter.SetDesiredUnitCountCurve, formatter, unitCurve)
    end

    secondsFormatter = formatter
    return formatter
end

function DurationAdapter.buildNonLinearProgressCurve(mode)
    local cCurveUtil = api.C_CurveUtil or _G.C_CurveUtil
    if not cCurveUtil or type(cCurveUtil.CreateCurve) ~= "function" then
        return nil
    end
    local ok, curve = pcall(cCurveUtil.CreateCurve)
    if not ok or not curve or type(curve.AddPoint) ~= "function" then
        return nil
    end
    local curveType = api.LuaCurveType or (_G.Enum and _G.Enum.LuaCurveType)
    local targetType = (curveType and curveType.Linear) or 0
    if mode == "CUBIC" and curveType and curveType.Cubic then
        targetType = curveType.Cubic
    elseif mode == "COSINE" and curveType and curveType.Cosine then
        targetType = curveType.Cosine
    end
    if type(curve.SetType) == "function" then
        pcall(curve.SetType, curve, targetType)
    end
    pcall(curve.AddPoint, curve, 0.0, 0.0)
    pcall(curve.AddPoint, curve, 1.0, 1.0)
    return curve
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

function DurationAdapter.createTextBinding(durationObject, fontString, customCurve)
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

    activeBindings[binding] = true
    if customCurve then
        bindingCustomCurves[binding] = customCurve
    end

    local curve = customCurve or DurationAdapter.getActiveColorCurve()
    if curve and type(binding.SetTextColorCurve) == "function" then
        local bindingPropEnum = api.DurationTextBindingProperty or (_G.Enum and _G.Enum.DurationTextBindingProperty)
        local prop = (bindingPropEnum and bindingPropEnum.RemainingDuration) or 0
        pcall(binding.SetTextColorCurve, binding, curve, prop)
    end

    DurationAdapter.bindingSuccesses = DurationAdapter.bindingSuccesses + 1
    DurationAdapter.lastFailure = nil
    return binding
end

function DurationAdapter.releaseTextBinding(binding)
    if not binding then
        return false
    end
    activeBindings[binding] = nil
    bindingCustomCurves[binding] = nil
    if type(binding.Disable) == "function" then
        pcall(binding.Disable, binding)
    elseif type(binding.SetEnabled) == "function" then
        pcall(binding.SetEnabled, binding, false)
    end
    if type(binding.ClearTextColorCurve) == "function" then
        pcall(binding.ClearTextColorCurve, binding)
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
        colorCurveAvailable = cachedColorCurve ~= nil,
    }
end

if EAM.Modules.EventRouter and type(EAM.Modules.EventRouter.register) == "function" then
    EAM.Modules.EventRouter.register("EAM_TIMER_COLOR_CHANGED", function()
        DurationAdapter.refreshActiveBindingsColorCurve()
    end)
end

