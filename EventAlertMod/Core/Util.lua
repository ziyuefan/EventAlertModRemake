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
    if value == nil then
        return true
    end
    if Util.isSecretValue(value) or not Util.canAccessValue(value) then
        return false
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
    if value == nil or Util.isSecretValue(value) or Util.isSecretTable(value) then
        return false
    end
    if not Util.canAccessTable(value) or Util.hasAnySecretValues(value) then
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

if EAM.API and tableFreeze and not tableIsFrozen(EAM.API) then
    tableFreeze(EAM.API)
end
