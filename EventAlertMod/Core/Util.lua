--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Core/Util
檔案: Core\Util.lua

理念:
- 集中所有低階 Lua 相容 helper，避免各模組重複建立 table API fallback。
- 提供低 GC pool helper，讓 hot path 使用可重複物件。

責任:
- 提供 table.create/table.freeze/table.isfrozen fallback。
- 提供 acquireTable/releaseTable，並在 fallback 完成後 freeze EAM.API。
- 提供 secret/protected value 的集中安全讀取 adapter。
- 提供 EditBox 手動複製前的聚焦／全選能力檢測，不宣稱可寫入系統剪貼簿。

資料所有權:
- 擁有工具函式與 helper-local 行為。
- 不擁有任何業務 runtime state。

可變狀態:
- 只會 wipe/recycle 呼叫者傳入 pool 的 table。
- 不可 freeze SavedVariables 或 service runtime state。

邊界:
- 不讀 WoW aura/cooldown API。
- 不建立 frame 或註冊事件。

效能注意:
- pool helper 必須避免額外 closure 與 transient table。
- release 時使用 wipe 保留配置容量。
- 引入 warningStringCache 靜態字串快取，完全消除邊界限制警告路徑的高頻字串拼接 GC churn。

Retail API 注意:
- table.freeze/table.isfrozen 在 Retail 12.x 可用時使用；fallback 只維持語法安全。

]]
local _, EAM = ...

local api = EAM.API
local Util = {}
EAM.Util = Util

local tableCreate = table.create
if not tableCreate then
    tableCreate = function()
        return {}
    end
end

local tableFreeze = table.freeze
if not tableFreeze then
    tableFreeze = function(target)
        return target
    end
end

local tableIsFrozen = table.isfrozen
if not tableIsFrozen then
    tableIsFrozen = function()
        return false
    end
end

Util.tableCreate = tableCreate
Util.tableFreeze = tableFreeze
Util.tableIsFrozen = tableIsFrozen

-- 多國語系動態 Tooltip 正則匹配表 (Numerically Indexed Arrays，以 table.freeze 凍結避免 runtime mutation 與節省 HASH 負擔)
Util.MULTI_LOCALE_PATTERNS = tableFreeze({
    zhTW = tableFreeze({ "持續%s*(%d+%.?%d*)%s*秒", "(%d+%.?%d*)%s*秒內" }),
    zhCN = tableFreeze({ "持续%s*(%d+%.?%d*)%s*秒", "(%d+%.?%d*)%s*秒内" }),
    enUS = tableFreeze({ "lasts%s*(%d+%.?%d*)%s*sec", "for%s*(%d+%.?%d*)%s*sec", "over%s*(%d+%.?%d*)%s*sec", "lasts%s*(%d+%.?%d*)%s*second" }),
    koKR = tableFreeze({ "(%d+%.?%d*)초%s*동안", "(%d+%.?%d*)초%s*내에" }),
    ruRU = tableFreeze({ "в%s*течение%s*(%d+%.?%d*)%s*сек", "на%s*(%d+%.?%d*)%s*сек", "в%s*течение%s*(%d+%.?%d*)%s*с%.", "в%s*течение%s*(%d+%.?%d*)%s*секунд", "на%s*(%d+%.?%d*)%s*секунд" }),
})

local canAccessTable = canaccesstable or function(t) return type(t) == "table" end
local canAccessValue = canaccessvalue or function() return true end
local isSecretValue = issecretvalue or function() return false end
local isSecretTable = issecrettable or function() return false end
local hasAnySecretValues = hasanysecretvalues or function() return false end
local mathHuge = math.huge

function Util.canAccessTable(value)
    if canAccessTable then
        return canAccessTable(value)
    end
    return type(value) == "table"
end

function Util.canAccessValue(value)
    if canAccessValue then
        return canAccessValue(value)
    end
    return true
end

function Util.isSecretValue(value)
    if isSecretValue then
        return isSecretValue(value)
    end
    return false
end

function Util.isSecretTable(value)
    if isSecretTable then
        return isSecretTable(value)
    end
    return false
end

function Util.hasAnySecretValues(value)
    if hasAnySecretValues then
        return hasAnySecretValues(value)
    end
    return false
end

function Util.isSafeValue(value)
    if isSecretValue(value) then
        return false
    end
    if not canAccessValue(value) then
        return false
    end
    if value == nil then
        return true
    end
    return true
end

function Util.isSafeNumber(value)
    if not Util.isSafeValue(value) or type(value) ~= "number" then
        return false
    end
    return value == value and value ~= mathHuge and value ~= -mathHuge
end

function Util.isSafePositiveNumber(value)
    return Util.isSafeNumber(value) and value > 0
end

function Util.isSafeNonNegativeNumber(value)
    return Util.isSafeNumber(value) and value >= 0
end

function Util.isSafeString(value)
    return Util.isSafeValue(value) and type(value) == "string"
end

function Util.isSafeBoolean(value)
    return Util.isSafeValue(value) and type(value) == "boolean"
end

function Util.prepareEditBoxManualCopy(editBox)
    if editBox == nil
        or type(editBox.SetFocus) ~= "function"
        or type(editBox.HighlightText) ~= "function"
    then
        return false, "selectionAPIUnavailable"
    end
    local focusOK = pcall(editBox.SetFocus, editBox)
    if not focusOK then
        return false, "focusFailed"
    end
    local highlightOK = pcall(editBox.HighlightText, editBox)
    if not highlightOK then
        return false, "highlightFailed"
    end
    return true, "manualCopyRequired"
end

function Util.isSafeTableKey(value)
    if not Util.isSafeValue(value) then
        return false
    end
    local valueType = type(value)
    return valueType == "string" or valueType == "number" or valueType == "boolean"
end

function Util.isReadableTable(value)
    if isSecretValue(value) or isSecretTable(value) then
        return false
    end
    if not canAccessTable(value) or hasAnySecretValues(value) then
        return false
    end
    return type(value) == "table"
end

-- Warning string cache to eliminate runtime string concatenation GC churn
local warningStringCache = {}

function Util.appendBoundaryWarning(warnings, code, field)
    if not warnings or not Util.isSafeString(code) then
        return
    end

    if field ~= nil then
        if not Util.isSafeString(field) then
            return
        end
        local key = code .. ":" .. field
        local cached = warningStringCache[key]
        if not cached then
            cached = key
            warningStringCache[key] = cached
        end
        warnings[#warnings + 1] = cached
    else
        warnings[#warnings + 1] = code
    end
end

function Util.markBoundary(state, code, field)
    if not state then
        return
    end

    state.boundaryLimited = true
    state.boundaryWarnings = state.boundaryWarnings or {}
    Util.appendBoundaryWarning(state.boundaryWarnings, code, field)
end

function Util.clearTimer(timer, mode)
    if not timer then
        return
    end

    wipe(timer)
    timer.mode = mode or EAM.Constants.TIMER_UNKNOWN
end

function Util.readSafeScalar(value, warnings, warningCode, field)
    if value == nil then
        return nil, true
    end

    if not Util.isSafeValue(value) then
        Util.appendBoundaryWarning(warnings, warningCode, field)
        return nil, false
    end

    return value, true
end

function Util.readSafeField(source, key, warnings, warningCode)
    if source == nil or not Util.isReadableTable(source) then
        Util.appendBoundaryWarning(warnings, warningCode or EAM.Constants.BOUNDARY_TABLE_RESTRICTED, "table")
        return nil, false
    end

    if not Util.isSafeTableKey(key) then
        Util.appendBoundaryWarning(warnings, warningCode or EAM.Constants.BOUNDARY_SECRET_VALUE, "key")
        return nil, false
    end

    local value = source[key]
    return Util.readSafeScalar(value, warnings, warningCode, key)
end

function Util.acquireTable(pool)
    local count = pool.count or 0
    if count > 0 then
        local value = pool[count]
        pool[count] = nil
        pool.count = count - 1
        return value
    end
    return tableCreate(0, 8)
end

function Util.releaseTable(pool, value)
    if not value then
        return
    end
    wipe(value)
    local count = (pool.count or 0) + 1
    pool[count] = value
    pool.count = count
end

function Util.createStepGateCurve(thresholdPercent)
    local cCurveUtil = api.C_CurveUtil or _G.C_CurveUtil
    if not cCurveUtil or type(cCurveUtil.CreateCurve) ~= "function" then
        return nil
    end
    local ok, curve = pcall(cCurveUtil.CreateCurve)
    if not ok or not curve or type(curve.AddPoint) ~= "function" then
        return nil
    end
    local curveType = api.LuaCurveType or (_G.Enum and _G.Enum.LuaCurveType)
    if curveType and curveType.Step and type(curve.SetType) == "function" then
        pcall(curve.SetType, curve, curveType.Step)
    end
    local th = math.max(0.01, math.min(0.99, tonumber(thresholdPercent) or 0.2))
    pcall(curve.AddPoint, curve, 0.0, 1.0)
    pcall(curve.AddPoint, curve, th, 1.0)
    pcall(curve.AddPoint, curve, math.min(1.0, th + 0.0001), 0.0)
    pcall(curve.AddPoint, curve, 1.0, 0.0)
    return curve
end

function Util.createColorStepGateCurve(thresholdPercent, activeColor, inactiveColor)
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
    local act = activeColor or (_G.CreateColor and _G.CreateColor(1, 0, 0, 1)) or { 1, 0, 0, 1 }
    local inact = inactiveColor or (_G.CreateColor and _G.CreateColor(0, 0, 0, 0)) or { 0, 0, 0, 0 }
    local th = math.max(0.01, math.min(0.99, tonumber(thresholdPercent) or 0.2))
    pcall(curve.AddPoint, curve, 0.0, act)
    pcall(curve.AddPoint, curve, th, act)
    pcall(curve.AddPoint, curve, 1.0, inact)
    return curve
end

function Util.createBandPassCurve(minThreshold, maxThreshold)
    local cCurveUtil = api.C_CurveUtil or _G.C_CurveUtil
    if not cCurveUtil or type(cCurveUtil.CreateCurve) ~= "function" then
        return nil
    end
    local ok, curve = pcall(cCurveUtil.CreateCurve)
    if not ok or not curve or type(curve.AddPoint) ~= "function" then
        return nil
    end
    local curveType = api.LuaCurveType or (_G.Enum and _G.Enum.LuaCurveType)
    if curveType and curveType.Step and type(curve.SetType) == "function" then
        pcall(curve.SetType, curve, curveType.Step)
    end
    local minTh = math.max(0.0, math.min(0.99, tonumber(minThreshold) or 0.2))
    local maxTh = math.max(minTh + 0.01, math.min(1.0, tonumber(maxThreshold) or 0.35))
    if minTh > 0.0001 then
        pcall(curve.AddPoint, curve, 0.0, 0.0)
        pcall(curve.AddPoint, curve, math.max(0.0, minTh - 0.0001), 0.0)
    end
    pcall(curve.AddPoint, curve, minTh, 1.0)
    pcall(curve.AddPoint, curve, maxTh, 1.0)
    if maxTh < 0.9999 then
        pcall(curve.AddPoint, curve, math.min(1.0, maxTh + 0.0001), 0.0)
        pcall(curve.AddPoint, curve, 1.0, 0.0)
    end
    return curve
end

-- ============================================================================
-- 12.1.5 Native Utility Acceleration & Frame Creation Helpers
-- ============================================================================

local nativeMathClamp = math.clamp
local nativeMathSaturate = math.saturate
local nativeMathRound = math.round
local nativeMathLerp = math.lerp
local nativeMathNormalize = math.normalize
local nativeMathSign = math.sign
local nativeMathRemap = math.remap
local nativeMathWrap = math.wrap
local nativeMathIsFinite = math.isfinite
local nativeMathIsNaN = math.isnan
local nativeMathIsInf = math.isinf

function Util.clamp(value, minVal, maxVal)
    if nativeMathClamp then
        return nativeMathClamp(value, minVal, maxVal)
    end
    if value < minVal then return minVal end
    if value > maxVal then return maxVal end
    return value
end

function Util.saturate(value)
    if nativeMathSaturate then
        return nativeMathSaturate(value)
    end
    return Util.clamp(value, 0, 1)
end

function Util.round(value)
    if nativeMathRound then
        return nativeMathRound(value)
    end
    if not value then return 0 end
    return math.floor(value + 0.5)
end

function Util.lerp(a, b, t)
    if nativeMathLerp then
        return nativeMathLerp(a, b, t)
    end
    return a + (b - a) * t
end

function Util.normalize(value, minVal, maxVal)
    if nativeMathNormalize then
        return nativeMathNormalize(value, minVal, maxVal)
    end
    if maxVal == minVal then return 0 end
    return (value - minVal) / (maxVal - minVal)
end

function Util.sign(value)
    if nativeMathSign then
        return nativeMathSign(value)
    end
    if not value or value == 0 then return 0 end
    return value > 0 and 1 or -1
end

function Util.remap(value, inMin, inMax, outMin, outMax)
    if nativeMathRemap then
        return nativeMathRemap(value, inMin, inMax, outMin, outMax)
    end
    if inMax == inMin then return outMin end
    return outMin + (value - inMin) / (inMax - inMin) * (outMax - outMin)
end

function Util.wrap(value, minVal, maxVal)
    if nativeMathWrap then
        return nativeMathWrap(value, minVal, maxVal)
    end
    local range = maxVal - minVal
    if range == 0 then return minVal end
    return minVal + ((value - minVal) % range)
end

function Util.isfinite(value)
    if nativeMathIsFinite then
        return nativeMathIsFinite(value)
    end
    return type(value) == "number" and value == value and value ~= mathHuge and value ~= -mathHuge
end

function Util.isnan(value)
    if nativeMathIsNaN then
        return nativeMathIsNaN(value)
    end
    return type(value) == "number" and value ~= value
end

function Util.isinf(value)
    if nativeMathIsInf then
        return nativeMathIsInf(value)
    end
    return value == mathHuge or value == -mathHuge
end

-- String Utilities
local nativeStringContains = string.contains
local nativeStringLtrim = string.ltrim
local nativeStringRtrim = string.rtrim
local nativeStringStartsWith = string.startswith
local nativeStringEndsWith = string.endswith

function Util.stringContains(str, substr)
    if not str or not substr then return false end
    if nativeStringContains then
        return nativeStringContains(str, substr)
    end
    return string.find(str, substr, 1, true) ~= nil
end

function Util.stringLtrim(str)
    if not str then return "" end
    if nativeStringLtrim then
        return nativeStringLtrim(str)
    end
    return (string.gsub(str, "^%s+", ""))
end

function Util.stringRtrim(str)
    if not str then return "" end
    if nativeStringRtrim then
        return nativeStringRtrim(str)
    end
    return (string.gsub(str, "%s+$", ""))
end

function Util.stringStartsWith(str, prefix)
    if not str or not prefix then return false end
    if nativeStringStartsWith then
        return nativeStringStartsWith(str, prefix)
    end
    return string.find(str, prefix, 1, true) == 1
end

function Util.stringEndsWith(str, suffix)
    if not str or not suffix then return false end
    if nativeStringEndsWith then
        return nativeStringEndsWith(str, suffix)
    end
    if suffix == "" then return true end
    local strLen = string.len(str)
    local suffixLen = string.len(suffix)
    if suffixLen > strLen then return false end
    return string.sub(str, strLen - suffixLen + 1) == suffix
end

Util.contains = Util.stringContains
Util.ltrim = Util.stringLtrim
Util.rtrim = Util.stringRtrim
Util.startswith = Util.stringStartsWith
Util.endswith = Util.stringEndsWith

-- Table Utilities
local nativeTableIsEmpty = table.isempty
local nativeTableContains = table.contains
local nativeTableIndexOf = table.indexof
local nativeTableRemoveUnordered = table.removeunordered
local nativeTableRemoveValue = table.removevalue
local nativeTableKeys = table.keys
local nativeTableValues = table.values

function Util.tableIsEmpty(tbl)
    if not tbl or type(tbl) ~= "table" then return true end
    if nativeTableIsEmpty then
        return nativeTableIsEmpty(tbl)
    end
    return next(tbl) == nil
end

function Util.tableContains(tbl, val)
    if not tbl or type(tbl) ~= "table" then return false end
    if nativeTableContains then
        return nativeTableContains(tbl, val)
    end
    for _, v in pairs(tbl) do
        if v == val then return true end
    end
    return false
end

function Util.tableIndexOf(tbl, val)
    if not tbl or type(tbl) ~= "table" then return nil end
    if nativeTableIndexOf then
        return nativeTableIndexOf(tbl, val)
    end
    for i, v in ipairs(tbl) do
        if v == val then return i end
    end
    return nil
end

function Util.tableRemoveUnordered(tbl, index)
    if not tbl or type(tbl) ~= "table" or not index then return nil end
    if nativeTableRemoveUnordered then
        return nativeTableRemoveUnordered(tbl, index)
    end
    local len = #tbl
    if index < 1 or index > len then return nil end
    local val = tbl[index]
    tbl[index] = tbl[len]
    tbl[len] = nil
    return val
end

function Util.tableRemoveValue(tbl, val)
    if not tbl or type(tbl) ~= "table" then return false end
    if nativeTableRemoveValue then
        return nativeTableRemoveValue(tbl, val)
    end
    for i = 1, #tbl do
        if tbl[i] == val then
            table.remove(tbl, i)
            return true
        end
    end
    return false
end

function Util.tableKeys(tbl)
    if not tbl or type(tbl) ~= "table" then return {} end
    if nativeTableKeys then
        return nativeTableKeys(tbl)
    end
    local keys = {}
    for k in pairs(tbl) do
        keys[#keys + 1] = k
    end
    return keys
end

function Util.tableValues(tbl)
    if not tbl or type(tbl) ~= "table" then return {} end
    if nativeTableValues then
        return nativeTableValues(tbl)
    end
    local values = {}
    for _, v in pairs(tbl) do
        values[#values + 1] = v
    end
    return values
end

Util.isempty = Util.tableIsEmpty

-- Frame creation helper (uses 12.1.5 CreateFrameWithOptions when available)
function Util.createFrame(frameType, frameName, parent, template, id)
    local eamAPI = EAM.API or api
    local cfo = (eamAPI and eamAPI.CreateFrameWithOptions) or _G.CreateFrameWithOptions
    if cfo and type(cfo) == "function" then
        local options = {
            frameType = frameType or "Frame",
            name = frameName,
            parent = parent,
            inherits = template,
            id = id,
        }
        local ok, f = pcall(cfo, options)
        if ok and f then
            return f
        end
    end
    local cf = (eamAPI and eamAPI.CreateFrame) or _G.CreateFrame
    if cf and type(cf) == "function" then
        return cf(frameType or "Frame", frameName, parent, template, id)
    end
    return nil
end

-- Native pixel rounding helper (uses 12.1.5 SetRoundLayoutToNearestPixel)
function Util.snapToPixels(region)
    if not region then return false end
    local ok, func = pcall(function() return region.SetRoundLayoutToNearestPixel end)
    if ok and type(func) == "function" then
        pcall(func, region, true)
        return true
    end
    return false
end

if EAM.API and tableFreeze and not tableIsFrozen(EAM.API) then
    tableFreeze(EAM.API)
end
