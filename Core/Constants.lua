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
    SCHEMA_VERSION = 5,
    TEXT_LAYOUT_SCHEMA_VERSION = 1,
    TEXT_PLACEMENT_TIMER_DEFAULT = "OUTSIDE_TOP",
    TEXT_PLACEMENT_APPLICATIONS_DEFAULT = "INSIDE_BOTTOM_RIGHT",
    TEXT_FONT_SIZE_MIN = 8,
    TEXT_FONT_SIZE_MAX = 32,
    ADDON_FLAVOR = "Retail",
    INTERFACE = 120100,
    LEGACY_INTERFACE = 120007,
    ALERT_KIND_AURA = "aura",
    ALERT_KIND_SPELL_COOLDOWN = "spellCooldown",
    ALERT_KIND_ITEM_COOLDOWN = "itemCooldown",
    ALERT_KIND_GROUND_EFFECT = "groundEffect",
    API_BASELINE_LABEL = "12.1.0 PTR 8",
    API_BASELINE_BUILD = "69189",
    RETAIL_COMPATIBILITY_LABEL = "12.0.7",
    PROJECT_AUTHOR = "ziyuefan死鬥",
    PROJECT_REPOSITORY_URL = "https://github.com/ziyuefan/EventAlertModRemake",
    PROJECT_PAGES_URL = "https://ziyuefan.github.io/EventAlertModRemake/",
    GROUND_DURATION_AUTO = "AUTO",
    GROUND_DURATION_MANUAL = "MANUAL",
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

    MODULE_KEYS = freeze({
        playerAura = "playerAura",
        targetAura = "targetAura",
        spellCooldown = "spellCooldown",
        itemCooldown = "itemCooldown",
        groundEffect = "groundEffect",
        classPower = "classPower",
        totem = "totem",
        tooltipMonitor = "tooltipMonitor",
    }),

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

    ALERT_BORDER_STYLE_KEYS = freeze({
        selfHelpful = "selfHelpful",
        selfHarmful = "selfHarmful",
        targetHelpful = "targetHelpful",
        targetHarmful = "targetHarmful",
        spellCooldown = "spellCooldown",
        itemCooldown = "itemCooldown",
        groundEffect = "groundEffect",
    }),

    FONT_FAMILY_DEFAULT = "STANDARD",
    FONT_FAMILY_OPTIONS = freeze({
        freeze({ value = "STANDARD", labelKey = "EAM_OPT_FONT_STANDARD", path = "STANDARD" }),
        freeze({ value = "ARIALN", labelKey = "EAM_OPT_FONT_ARIALN", path = "Fonts\\ARIALN.TTF" }),
        freeze({ value = "MORPHEUS", labelKey = "EAM_OPT_FONT_MORPHEUS", path = "Fonts\\MORPHEUS.TTF" }),
        freeze({ value = "SKURRI", labelKey = "EAM_OPT_FONT_SKURRI", path = "Fonts\\SKURRI.TTF" }),
    }),
    ALERT_BORDER_COLORS = freeze({
        selfHelpful = freeze({ 0.10, 0.82, 1.00, 1.00 }),
        selfHarmful = freeze({ 1.00, 0.18, 0.18, 1.00 }),
        targetHelpful = freeze({ 0.25, 0.42, 1.00, 1.00 }),
        targetHarmful = freeze({ 1.00, 0.36, 0.08, 1.00 }),
        spellCooldown = freeze({ 1.00, 0.85, 0.05, 1.00 }),
        itemCooldown = freeze({ 0.15, 0.95, 0.25, 1.00 }),
        groundEffect = freeze({ 0.72, 0.25, 1.00, 1.00 }),
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

