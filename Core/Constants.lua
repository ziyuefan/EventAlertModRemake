--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Core/Constants
檔案: Core\Constants.lua

理念:
- 將 schema、狀態與 enum 集中，避免魔法字串散落。
- 靜態常數可 freeze，提供穩定讀取與防止誤改。

責任:
- 定義 schema version、addon flavor、Interface number、alert kind、timer mode 與 boundary code。

資料所有權:
- 擁有不可變靜態常數表。

可變狀態:
- 載入後不應 mutate；透過 table.freeze 固定。

邊界:
- 不得放入 runtime state、SavedVariables 或會隨角色/戰鬥改變的資料。

效能注意:
- 常數表是高頻判斷依據，應以直接 key 存取為主。

Retail API 注意:
- Interface 錨定 120007；更新 Retail 版本時需同步 TOC、打包工具、CurseForge version ID 與文件。

]]
local _, EAM = ...

local freeze = EAM.Util and EAM.Util.tableFreeze or function(value)
    return value
end

EAM.Constants = freeze({
    SCHEMA_VERSION = 2,
    ADDON_FLAVOR = "Retail",
    INTERFACE = 120100,
    LEGACY_INTERFACE = 120007,
    ALERT_KIND_AURA = "aura",
    ALERT_KIND_SPELL_COOLDOWN = "spellCooldown",
    ALERT_KIND_ITEM_COOLDOWN = "itemCooldown",
    TIMER_NONE = "none",
    TIMER_NUMERIC = "numeric",
    TIMER_DISPLAY_ONLY = "displayOnly",
    TIMER_PROTECTED = "protected",
    TIMER_UNKNOWN = "unknown",
    BOUNDARY_API_UNAVAILABLE = "apiUnavailable",
    BOUNDARY_SECRET_VALUE = "secretValue",
    BOUNDARY_TABLE_RESTRICTED = "tableRestricted",
    BOUNDARY_COMBAT_DEFERRED = "combatDeferred",
    BOUNDARY_NATIVE_AURA_UNAVAILABLE = "nativeAuraUnavailable",
    BOUNDARY_NATIVE_AURA_LIMITED = "nativeAuraLimited",
    AURA_BACKEND_NATIVE = "NATIVE",
    AURA_BACKEND_LEGACY = "LEGACY",
    AURA_BACKEND_UNSUPPORTED = "UNSUPPORTED",
    AURA_RULE_NATIVE_SLOT = "NATIVE_SLOT",
    AURA_RULE_NATIVE_GROUP = "NATIVE_GROUP",
    AURA_RULE_READABLE_LEGACY = "READABLE_LEGACY",
    AURA_RULE_DISPLAY_UNSUPPORTED = "DISPLAY_UNSUPPORTED",

    -- 7 大獨立告警框架名稱
    ALERT_FRAME_TYPES = freeze({
        selfAura = "selfAura",
        targetAura = "targetAura",
        spellCooldown = "spellCooldown",
        itemCooldown = "itemCooldown",
        classPower = "classPower",
        groundEffect = "groundEffect",
        totem = "totem",
    }),

    -- 1 = RIGHT, 2 = LEFT, 3 = UP, 4 = DOWN
    -- 凍結為連續數字索引陣列 (Array Part)，以空間換時間，消除雜湊衝突與查詢消耗
    LAYOUT_OFFSETS = freeze({
        freeze({ 1, 0 }),  -- 1 = RIGHT (向右成長)
        freeze({ -1, 0 }), -- 2 = LEFT (向左成長)
        freeze({ 0, 1 }),  -- 3 = UP (向上成長)
        freeze({ 0, -1 })  -- 4 = DOWN (向下成長)
    })
})

