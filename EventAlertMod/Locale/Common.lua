--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Locale/Common
檔案: Locale\Common.lua

理念:
- 建立 locale registry 與 fallback 機制，讓字串不再污染全域。
- 語系載入採 enUS fallback 加目前或使用者指定語系覆蓋；可選語系包含俄文。

責任:
- 建立 EAM.Locale、穩定 identity 的 EAM.L、語系 catalog、Auto Detect/手動選擇、文字綁定與 class/power static helper。

資料所有權:
- 擁有 EAM.L 字串表、requested/effective 選擇狀態、長生命週期 EAM widget 綁定與低頻 refresh callbacks。

可變狀態:
- EAM.L 以原地清除／覆蓋切換 fallback 與有效語系；綁定 registry 與 refresh callbacks 是 runtime 狀態，不得 freeze。
- Locale.LanguageOptions、class/power helper 等不可變靜態資料可 freeze。

邊界:
- 語系模組不建立、重建或控制 frame，只對明確註冊的 EAM 自有 widget 呼叫 SetText；釋放型 widget 必須 unbind。
- 不直接寫 SavedVariables；設定寫入由 SavedVariables 模組負責，再以 EAM_LANGUAGE_CHANGED 同步套用。

效能注意:
- 語系切換與 registry refresh 是使用者觸發的低頻工作，不得放入 hot path；static helper 應保持穩定。

Retail API 注意:
- GetLocale/GetClassInfo/Enum.PowerType 需 Retail 12.x 可用；class/power 變更需更新文件。

]]
local _, EAM = ...

local api = EAM.API or {}
local freeze = EAM.Util and EAM.Util.tableFreeze or function(value)
    return value
end

local Locale = {
    current = GetLocale and GetLocale() or "enUS",
    fallback = "enUS",
    requested = "auto",
    selected = "auto",
    effective = nil,
    catalog = {},
}

EAM.Locale = Locale
EAM.L = EAM.L or {}
local languageOptions = {
    { value = "auto", label = "Auto Detect" },
    { value = "enUS", label = "English" },
    { value = "zhTW", label = "繁體中文" },
    { value = "zhCN", label = "简体中文" },
    { value = "koKR", label = "한국어" },
    { value = "ruRU", label = "Русский" },
}

Locale.LanguageOptions = freeze(languageOptions)

local supportedSelections = {
    auto = true,
    enUS = true,
    zhTW = true,
    zhCN = true,
    koKR = true,
    ruRU = true,
}

function Locale.normalizeSelection(value)
    if supportedSelections[value] then
        return value
    end
    return "auto"
end

local savedVariables = rawget(_G, "EAM_DB")
local savedConfig = type(savedVariables) == "table" and savedVariables.config or nil
Locale.requested = Locale.normalizeSelection(type(savedConfig) == "table" and savedConfig.language or nil)

local function clearValues(target)
    for key in pairs(target) do
        target[key] = nil
    end
end

local function copyValues(target, source)
    for key, value in pairs(source) do
        target[key] = value
    end
end

local function shouldApply(locale)
    if Locale.requested == "auto" then
        return locale == Locale.current or (locale == Locale.fallback and not Locale.catalog[Locale.current])
    end
    return locale == Locale.requested or (locale == Locale.fallback and not Locale.catalog[Locale.requested])
end

local textBindings = table.create and table.create(64, 0) or {}
local textBindingByTarget = {}
local refreshCallbacks = table.create and table.create(8, 0) or {}
textBindings.count = 0
refreshCallbacks.count = 0
Locale.textBindings = textBindings

local function resolveText(key, fallback)
    local value = EAM.L
    local segmentStart = 1
    while type(value) == "table" do
        local separator = string.find(key, ".", segmentStart, true)
        local segment = separator and string.sub(key, segmentStart, separator - 1)
            or string.sub(key, segmentStart)
        value = value[segment]
        if not separator then
            break
        end
        segmentStart = separator + 1
    end
    if type(value) == "string" then
        return value
    end
    if type(fallback) == "string" then
        return fallback
    end
    return key
end

function Locale.bindText(target, key, fallback)
    if target == nil or type(key) ~= "string" or type(target.SetText) ~= "function" then
        return false, "invalidBinding"
    end

    local binding = textBindingByTarget[target]
    if binding then
        binding.key = key
        binding.fallback = fallback
    else
        binding = {
            target = target,
            key = key,
            fallback = fallback,
        }
        local count = textBindings.count + 1
        textBindings[count] = binding
        textBindings.count = count
        textBindingByTarget[target] = binding
    end

    target:SetText(resolveText(key, fallback))
    return true
end

function Locale.unbindText(target)
    local binding = target and textBindingByTarget[target] or nil
    if not binding then
        return false
    end

    local count = textBindings.count
    for index = 1, count do
        if textBindings[index] == binding then
            local last = textBindings[count]
            textBindings[index] = last
            textBindings[count] = nil
            textBindings.count = count - 1
            break
        end
    end
    textBindingByTarget[target] = nil
    return true
end

function Locale.registerRefresh(callback)
    if type(callback) ~= "function" then
        return false
    end
    local count = refreshCallbacks.count
    for index = 1, count do
        if refreshCallbacks[index] == callback then
            return true, "unchanged"
        end
    end
    count = count + 1
    refreshCallbacks[count] = callback
    refreshCallbacks.count = count
    return true, "registered"
end

function Locale.refreshBindings()
    local bindingCount = textBindings.count
    for index = 1, bindingCount do
        local binding = textBindings[index]
        local target = binding and binding.target or nil
        if target and type(target.SetText) == "function" then
            target:SetText(resolveText(binding.key, binding.fallback))
        end
    end

    local callbackCount = refreshCallbacks.count
    for index = 1, callbackCount do
        local ok, errorMessage = pcall(refreshCallbacks[index])
        if not ok and EAM.addDebugLog then
            EAM.addDebugLog("Locale", "refresh", tostring(errorMessage))
        end
    end
end

function Locale.apply(selection)
    local normalized = Locale.normalizeSelection(selection)
    local effective = normalized == "auto" and Locale.current or normalized
    if not Locale.catalog[effective] then
        effective = Locale.fallback
    end

    local fallbackValues = Locale.catalog[Locale.fallback]
    local selectedValues = Locale.catalog[effective]
    if not fallbackValues or not selectedValues then
        return false, "catalogUnavailable"
    end

    clearValues(EAM.L)
    copyValues(EAM.L, fallbackValues)
    if effective ~= Locale.fallback then
        copyValues(EAM.L, selectedValues)
    end

    Locale.requested = normalized
    Locale.selected = normalized
    Locale.effective = effective
    Locale.refreshBindings()
    return true, effective
end

function Locale.setSelection(selection)
    local normalized = Locale.normalizeSelection(selection)
    return Locale.apply(normalized)
end

function Locale.getSelection()
    local db = EAM.db or rawget(_G, "EAM_DB")
    local config = type(db) == "table" and db.config or nil
    return Locale.normalizeSelection(type(config) == "table" and config.language or Locale.requested)
end

function Locale.getOptionLabel(selection)
    local normalized = Locale.normalizeSelection(selection)
    for index = 1, #languageOptions do
        local option = languageOptions[index]
        if option.value == normalized then
            return option.label
        end
    end
    return "Auto Detect"
end

local classNames = {}
if GetNumClasses and GetClassInfo then
    for index = 1, GetNumClasses() do
        local classLocaleName, classFile = GetClassInfo(index)
        if classFile then
            classNames[classFile] = classLocaleName
        end
    end
end
classNames.OTHER = "OTHER"

Locale.ClassFile = freeze({
    DEATHKNIGHT = "DEATHKNIGHT",
    DEMONHUNTER = "DEMONHUNTER",
    DRUID = "DRUID",
    EVOKER = "EVOKER",
    HUNTER = "HUNTER",
    MAGE = "MAGE",
    MONK = "MONK",
    PALADIN = "PALADIN",
    PRIEST = "PRIEST",
    ROGUE = "ROGUE",
    SHAMAN = "SHAMAN",
    WARLOCK = "WARLOCK",
    WARRIOR = "WARRIOR",
    FUNKY = "FUNKY",
    OTHER = "OTHER",
})

Locale.ClassName = freeze(classNames)

local powerType = Enum and Enum.PowerType or {}
Locale.PowerType = freeze({
    MANA = powerType.Mana,
    RAGE = powerType.Rage,
    FOCUS = powerType.Focus,
    ENERGY = powerType.Energy,
    COMBO_POINTS = powerType.ComboPoints,
    RUNES = powerType.Runes,
    RUNIC_POWER = powerType.RunicPower,
    SOUL_SHARDS = powerType.SoulShards,
    LUNAR_POWER = powerType.LunarPower,
    HOLY_POWER = powerType.HolyPower,
    MAELSTROM = powerType.Maelstrom,
    CHI = powerType.Chi,
    INSANITY = powerType.Insanity,
    ARCANE_CHARGES = powerType.ArcaneCharges,
    FURY = powerType.Fury,
    PAIN = powerType.Pain,
    HAPPINESS = powerType.Happiness,
    ESSENCE = powerType.Essence,
})

Locale.CompareOptions = freeze({
    { text = "<", value = 1 },
    { text = "<=", value = 2 },
    { text = "=", value = 3 },
    { text = ">=", value = 4 },
    { text = ">", value = 5 },
    { text = "<>", value = 6 },
    { text = "*", value = 7 },
})

function Locale.register(locale, loader)
    if type(locale) ~= "string" or type(loader) ~= "function" then
        return
    end

    local values = {}
    loader(values)
    Locale.catalog[locale] = values

    if shouldApply(locale) then
        Locale.apply(Locale.requested)
    end
end

function Locale.get(key)
    return EAM.L[key] or key
end

local function onLanguageChanged(_, selection)
    Locale.setSelection(selection)
end

if EAM.Modules and EAM.Modules.EventRouter then
    EAM.Modules.EventRouter.register("EAM_LANGUAGE_CHANGED", onLanguageChanged)
end

