--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Data/PlayerResourceCatalog
檔案: Data\PlayerResourceCatalog.lua

責任:
- 定義 Retail 12.1 玩家 UnitPower 資源的不可變 metadata。
- 定義職業/專精對應的候選資源拓樸；實際可用性仍由 runtime capability 驗證。

邊界:
- 本檔不呼叫 UnitPower API、不建立 frame、不保存即時值。
- 候選拓樸不是實機簽收；每個資源仍須通過 UnitHasPowerType 與能力分類。
]]
local _, EAM = ...

local freeze = EAM.Util and EAM.Util.tableFreeze or function(value)
    return value
end

local Catalog = {}
local definitions = {}
local byKey = {}
local byPowerType = {}
local byToken = {}

local function define(key, powerType, token, legacyConfigKey, icon, nameKey, fallbackName, rendererKind, maxPoints, color)
    local definition = freeze({
        key = key,
        powerType = powerType,
        token = token,
        legacyConfigKey = legacyConfigKey,
        legacyKey = legacyConfigKey,
        defaultOrder = #definitions + 1,
        icon = icon,
        nameKey = nameKey,
        fallbackName = fallbackName,
        rendererKind = rendererKind,
        maxPoints = maxPoints,
        color = freeze(color),
    })
    definitions[#definitions + 1] = definition
    byKey[key] = definition
    byPowerType[powerType] = definition
    byToken[token] = definition
    return key
end

local MANA = define("MANA", 0, "MANA", "powerMana", 136096, "EAM_RESOURCE_MANA", "法力", "BAR", nil, { 0.10, 0.45, 1.00, 1.00 })
local RAGE = define("RAGE", 1, "RAGE", "powerRage", 132344, "EAM_POWER_RAGE", "怒氣", "BAR", nil, { 0.90, 0.10, 0.10, 1.00 })
local FOCUS = define("FOCUS", 2, "FOCUS", "powerFocus", 132242, "EAM_RESOURCE_FOCUS", "集中值", "BAR", nil, { 1.00, 0.55, 0.20, 1.00 })
local ENERGY = define("ENERGY", 3, "ENERGY", "powerEnergy", 136110, "EAM_RESOURCE_ENERGY", "能量", "BAR", nil, { 1.00, 0.85, 0.10, 1.00 })
local COMBO = define("COMBO_POINTS", 4, "COMBO_POINTS", "powerCombo", 132292, "EAM_POWER_COMBO_POINTS", "連擊點", "POINTS", 7, { 1.00, 0.75, 0.15, 1.00 })
local RUNES = define("RUNES", 5, "RUNES", "powerRunes", 134417, "EAM_RESOURCE_RUNES", "符文", "POINTS", 6, { 0.20, 0.80, 1.00, 1.00 })
local RUNIC = define("RUNIC_POWER", 6, "RUNIC_POWER", "powerRunic", 135767, "EAM_POWER_RUNIC_POWER", "符文能量", "BAR", nil, { 0.05, 0.80, 1.00, 1.00 })
local SHARDS = define("SOUL_SHARDS", 7, "SOUL_SHARDS", "powerShard", 136184, "EAM_POWER_SOUL_SHARDS", "靈魂碎片", "POINTS", 5, { 0.65, 0.25, 1.00, 1.00 })
local LUNAR = define("LUNAR_POWER", 8, "LUNAR_POWER", "powerAstral", 236168, "EAM_RESOURCE_LUNAR_POWER", "星能", "BAR", nil, { 0.30, 0.45, 1.00, 1.00 })
local HOLY = define("HOLY_POWER", 9, "HOLY_POWER", "powerHoly", 524203, "EAM_POWER_HOLY_POWER", "聖能", "POINTS", 5, { 1.00, 0.90, 0.25, 1.00 })
local MAELSTROM = define("MAELSTROM", 11, "MAELSTROM", "powerMaelstrom", 136099, "EAM_RESOURCE_MAELSTROM", "漩渦值", "BAR", nil, { 0.15, 0.55, 1.00, 1.00 })
local CHI = define("CHI", 12, "CHI", "powerChi", 627485, "EAM_POWER_CHI", "真氣", "POINTS", 6, { 0.20, 0.90, 0.80, 1.00 })
local INSANITY = define("INSANITY", 13, "INSANITY", "powerInsanity", 237569, "EAM_RESOURCE_INSANITY", "瘋狂值", "BAR", nil, { 0.55, 0.15, 0.85, 1.00 })
local ARCANE = define("ARCANE_CHARGES", 16, "ARCANE_CHARGES", "powerArcane", 135732, "EAM_POWER_ARCANE_CHARGES", "秘法充能", "POINTS", 4, { 0.35, 0.55, 1.00, 1.00 })
local FURY = define("FURY", 17, "FURY", "powerFury", 1275380, "EAM_RESOURCE_FURY", "魔怒", "BAR", nil, { 0.75, 0.10, 0.95, 1.00 })
local PAIN = define("PAIN", 18, "PAIN", "powerPain", 1247264, "EAM_RESOURCE_PAIN", "痛苦", "BAR", nil, { 0.85, 0.20, 0.25, 1.00 })
local ESSENCE = define("ESSENCE", 19, "ESSENCE", "powerVigor", 4630437, "EAM_RESOURCE_ESSENCE", "精華", "POINTS", 6, { 0.25, 0.85, 1.00, 1.00 })

local function keys(...)
    return freeze({ ... })
end

local classFallback = freeze({
    WARRIOR = keys(RAGE),
    PALADIN = keys(MANA, HOLY),
    HUNTER = keys(FOCUS),
    ROGUE = keys(ENERGY, COMBO),
    PRIEST = keys(MANA, INSANITY),
    DEATHKNIGHT = keys(RUNES, RUNIC),
    SHAMAN = keys(MANA, MAELSTROM),
    MAGE = keys(MANA, ARCANE),
    WARLOCK = keys(MANA, SHARDS),
    MONK = keys(MANA, ENERGY, CHI),
    DRUID = keys(MANA, RAGE, ENERGY, COMBO, LUNAR),
    DEMONHUNTER = keys(FURY, PAIN),
    EVOKER = keys(MANA, ESSENCE),
})

local specResources = freeze({
    WARRIOR = freeze({ [71] = keys(RAGE), [72] = keys(RAGE), [73] = keys(RAGE) }),
    PALADIN = freeze({ [65] = keys(MANA, HOLY), [66] = keys(MANA, HOLY), [70] = keys(MANA, HOLY) }),
    HUNTER = freeze({ [253] = keys(FOCUS), [254] = keys(FOCUS), [255] = keys(FOCUS) }),
    ROGUE = freeze({ [259] = keys(ENERGY, COMBO), [260] = keys(ENERGY, COMBO), [261] = keys(ENERGY, COMBO) }),
    PRIEST = freeze({ [256] = keys(MANA), [257] = keys(MANA), [258] = keys(MANA, INSANITY) }),
    DEATHKNIGHT = freeze({ [250] = keys(RUNES, RUNIC), [251] = keys(RUNES, RUNIC), [252] = keys(RUNES, RUNIC) }),
    SHAMAN = freeze({ [262] = keys(MANA, MAELSTROM), [263] = keys(MANA, MAELSTROM), [264] = keys(MANA) }),
    MAGE = freeze({ [62] = keys(MANA, ARCANE), [63] = keys(MANA), [64] = keys(MANA) }),
    WARLOCK = freeze({ [265] = keys(MANA, SHARDS), [266] = keys(MANA, SHARDS), [267] = keys(MANA, SHARDS) }),
    MONK = freeze({ [268] = keys(ENERGY), [269] = keys(ENERGY, CHI), [270] = keys(MANA) }),
    DRUID = freeze({
        [102] = keys(MANA, RAGE, ENERGY, COMBO, LUNAR),
        [103] = keys(MANA, RAGE, ENERGY, COMBO, LUNAR),
        [104] = keys(MANA, RAGE, ENERGY, COMBO, LUNAR),
        [105] = keys(MANA, RAGE, ENERGY, COMBO, LUNAR),
    }),
    DEMONHUNTER = freeze({ [577] = keys(FURY), [581] = keys(FURY, PAIN), [1480] = keys(FURY, PAIN) }),
    EVOKER = freeze({ [1467] = keys(MANA, ESSENCE), [1468] = keys(MANA, ESSENCE), [1473] = keys(MANA, ESSENCE) }),
})

Catalog.Definitions = freeze(definitions)
Catalog.ByKey = freeze(byKey)
Catalog.ByPowerType = freeze(byPowerType)
Catalog.ByToken = freeze(byToken)
Catalog.ClassFallback = classFallback
Catalog.SpecResources = specResources
Catalog.ClassResourceKeys = freeze({
    COMBO_POINTS = true,
    RUNES = true,
    SOUL_SHARDS = true,
    HOLY_POWER = true,
    CHI = true,
    ARCANE_CHARGES = true,
    ESSENCE = true,
})
Catalog.ResourceCount = #definitions

function Catalog.getSpecResourceKeys(classToken, specializationID)
    local classSpecs = specResources[classToken]
    if classSpecs and specializationID and classSpecs[specializationID] then
        return classSpecs[specializationID]
    end
    return classFallback[classToken]
end

function Catalog.getDefinition(key)
    return byKey[key]
end

EAM.Data.PlayerResourceCatalog = freeze(Catalog)