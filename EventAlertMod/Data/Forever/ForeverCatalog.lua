--[[ EAM_FILE_COMMENTARY
EventAlertMod Forever Support
Module: Data/Forever/ForeverCatalog
檔案: Data\Forever\ForeverCatalog.lua

責任:
- 註冊 EAM.Data.ForeverCatalog，定義《World of Warcraft: Forever》(1.60.1, Interface 16001) 專屬之靜態資料。
- 定義經典 60 級職業資源拓樸 (Topology)，排除現代專精複合資源 (如聖能/秘法充能/靈魂碎片非痛苦)。
- 提供 Forever 經典法術監控預設清單 (ForeverDefaultAlerts / ForeverSpellHeuristics)，涵蓋 60 級核心觸發、飾品、附魔、露營 Buff 與天靈 (Skyborne) 種族主動技能。
- 定義 Forever 專屬人物屬性 (Spirit Mana Regen 五秒回魔、Spirit Health Regen、Defense Skill 防禦技能、Glancing Blow 偏斜率、Pet Happiness 寵物快樂度/忠誠度、Ammo Status 彈藥狀態)。

邊界:
- 保留 Data/PlayerResourceCatalog.lua 原 17 個定義與 40 個 spec 結構不變，本檔僅在 EAM.isForever 為 true 時作為優先擴充與覆寫層。
- 靜態資料一律經過 tableFreeze 凍結，維護資料純粹性。
]]

local _, EAM = ...

EAM.Data = EAM.Data or {}

local freeze = (EAM.Util and EAM.Util.tableFreeze) or function(value)
    return value
end

local ForeverCatalog = {}

-------------------------------------------------------------------------------
-- 1. Forever 經典 60 級全職業資源拓樸 (Resource Topology)
-------------------------------------------------------------------------------
-- 經典 60 級無專精資源分化，各職業依原始能量規則運行
local FOREVER_RESOURCE_TOPOLOGY = {
    WARRIOR = { "RAGE" },
    PALADIN = { "MANA" },
    HUNTER  = { "MANA", "FOCUS" }, -- 獵人本體法力 + 寵物集中值 (Pet Focus)
    ROGUE   = { "ENERGY", "COMBO_POINTS" },
    PRIEST  = { "MANA" },
    SHAMAN  = { "MANA" },
    MAGE    = { "MANA" },
    WARLOCK = { "MANA", "SOUL_SHARDS" },
    DRUID   = { "MANA", "RAGE", "ENERGY", "COMBO_POINTS" }, -- 德魯伊人/熊/豹形態切換全拓樸
}

function ForeverCatalog.GetCandidateResourceKeys(classToken)
    if not classToken then return nil end
    return FOREVER_RESOURCE_TOPOLOGY[classToken]
end

-------------------------------------------------------------------------------
-- 2. Forever 專屬經典人物屬性定義 (Forever Person Stats)
-------------------------------------------------------------------------------
local FOREVER_STAT_DEFINITIONS = {
    SPIRIT_MANA_REGEN = freeze({
        key = "SPIRIT_MANA_REGEN",
        nameKey = "STAT_SPIRIT_MANA_REGEN",
        fallbackName = "精神回魔 (FSR)",
        icon = 135981, -- Spell_Holy_MagicalSentry
        defaultOrder = 1,
        requiresForever = true,
        category = "MANA_REGEN",
        tooltipKey = "STAT_SPIRIT_MANA_REGEN_DESC",
        fallbackTooltip = "基於精神屬性之每 5 秒法力回復量 (含五秒規則內/外回復估算)。",
    }),
    SPIRIT_HEALTH_REGEN = freeze({
        key = "SPIRIT_HEALTH_REGEN",
        nameKey = "STAT_SPIRIT_HEALTH_REGEN",
        fallbackName = "精神回血",
        icon = 135941, -- Spell_Holy_GreaterHeal
        defaultOrder = 2,
        requiresForever = true,
        category = "HEALTH_REGEN",
        tooltipKey = "STAT_SPIRIT_HEALTH_REGEN_DESC",
        fallbackTooltip = "基於精神屬性之每 2 秒非戰鬥/戰鬥中生命值自然回復量。",
    }),
    DEFENSE_SKILL = freeze({
        key = "DEFENSE_SKILL",
        nameKey = "STAT_DEFENSE_SKILL",
        fallbackName = "防禦技能",
        icon = 132341, -- Inv_Shield_06
        defaultOrder = 3,
        requiresForever = true,
        category = "DEFENSE",
        tooltipKey = "STAT_DEFENSE_SKILL_DESC",
        fallbackTooltip = "經典圓桌防禦技能等級 (基礎值 + 裝備/天賦加成)。",
    }),
    GLANCING_BLOW = freeze({
        key = "GLANCING_BLOW",
        nameKey = "STAT_GLANCING_BLOW",
        fallbackName = "偏斜懲罰",
        icon = 132338, -- Inv_Shield_03
        defaultOrder = 4,
        requiresForever = true,
        category = "DEFENSE",
        tooltipKey = "STAT_GLANCING_BLOW_DESC",
        fallbackTooltip = "對目標普攻遭受偏斜打擊之機率與傷害減免懲罰率。",
    }),
    PET_HAPPINESS = freeze({
        key = "PET_HAPPINESS",
        nameKey = "STAT_PET_HAPPINESS",
        fallbackName = "寵物快樂度",
        icon = 132242, -- Ability_Hunter_BeastTraining
        defaultOrder = 5,
        requiresForever = true,
        classLimit = "HUNTER",
        category = "PET",
        tooltipKey = "STAT_PET_HAPPINESS_DESC",
        fallbackTooltip = "獵人當前活躍寵物之快樂度等級 (不快/高興/快樂) 與忠誠度階段。",
    }),
    AMMO_STATUS = freeze({
        key = "AMMO_STATUS",
        nameKey = "STAT_AMMO_STATUS",
        fallbackName = "遠程彈藥剩餘",
        icon = 132381, -- Inv_Ammo_Arrow_02
        defaultOrder = 6,
        requiresForever = true,
        classLimit = "HUNTER",
        category = "AMMO",
        tooltipKey = "STAT_AMMO_STATUS_DESC",
        fallbackTooltip = "當前裝備之箭矢或子彈存量與遠程射擊裝填需求狀態。",
    }),
    ARMOR_PENETRATION = freeze({
        key = "ARMOR_PENETRATION",
        nameKey = "STAT_ARMOR_PENETRATION",
        fallbackName = "護甲穿透",
        icon = 135848, -- Spell_Nature_Earthquake
        defaultOrder = 7,
        requiresForever = true,
        category = "OFFENSE",
        tooltipKey = "STAT_ARMOR_PENETRATION_DESC",
        fallbackTooltip = "物理攻擊忽視目標護甲之數值比率。",
    }),
    RESIST_ARCANE = freeze({
        key = "resistArcane",
        nameKey = "EAM_STAT_RESIST_ARCANE",
        fallbackName = "秘法抗性",
        icon = 136096,
        defaultOrder = 8,
        requiresForever = true,
        damageClass = 6,
        category = "RESISTANCE",
        tooltipKey = "STAT_RESIST_ARCANE_DESC",
        fallbackTooltip = "秘法魔法傷害減免與抗性等級。",
    }),
    RESIST_FIRE = freeze({
        key = "resistFire",
        nameKey = "EAM_STAT_RESIST_FIRE",
        fallbackName = "火焰抗性",
        icon = 135824,
        defaultOrder = 9,
        requiresForever = true,
        damageClass = 2,
        category = "RESISTANCE",
        tooltipKey = "STAT_RESIST_FIRE_DESC",
        fallbackTooltip = "火焰魔法傷害減免與抗性等級。",
    }),
    RESIST_FROST = freeze({
        key = "resistFrost",
        nameKey = "EAM_STAT_RESIST_FROST",
        fallbackName = "冰霜抗性",
        icon = 135848,
        defaultOrder = 10,
        requiresForever = true,
        damageClass = 4,
        category = "RESISTANCE",
        tooltipKey = "STAT_RESIST_FROST_DESC",
        fallbackTooltip = "冰霜魔法傷害減免與抗性等級。",
    }),
    RESIST_NATURE = freeze({
        key = "resistNature",
        nameKey = "EAM_STAT_RESIST_NATURE",
        fallbackName = "自然抗性",
        icon = 136074,
        defaultOrder = 11,
        requiresForever = true,
        damageClass = 3,
        category = "RESISTANCE",
        tooltipKey = "STAT_RESIST_NATURE_DESC",
        fallbackTooltip = "自然魔法傷害減免與抗性等級。",
    }),
    RESIST_SHADOW = freeze({
        key = "resistShadow",
        nameKey = "EAM_STAT_RESIST_SHADOW",
        fallbackName = "暗影抗性",
        icon = 136192,
        defaultOrder = 12,
        requiresForever = true,
        damageClass = 5,
        category = "RESISTANCE",
        tooltipKey = "STAT_RESIST_SHADOW_DESC",
        fallbackTooltip = "暗影魔法傷害減免與抗性等級。",
    }),
    SPIRIT = freeze({
        key = "spirit",
        nameKey = "EAM_STAT_SPIRIT",
        fallbackName = "精神",
        icon = 135981,
        defaultOrder = 13,
        requiresForever = true,
        category = "PRIMARY",
        tooltipKey = "STAT_SPIRIT_DESC",
        fallbackTooltip = "精神主屬性，提供生命力與法力恢復。",
    }),

}

function ForeverCatalog.GetStatDefinitions()
    return FOREVER_STAT_DEFINITIONS
end

-------------------------------------------------------------------------------
-- 3. Forever 經典法術監控預設清單 (Forever Default Alerts)
-------------------------------------------------------------------------------
local FOREVER_DEFAULT_ALERTS = {
    MAGE = {
        { id = 12536, type = "aura", unit = "player", name = "節能施法", glowOnApply = true }, -- Clearcasting
        { id = 12042, type = "aura", unit = "player", name = "秘法強化", glowOnApply = true }, -- Arcane Power
        { id = 12043, type = "aura", unit = "player", name = "氣定神閒", glowOnApply = true }, -- Presence of Mind
        { id = 11129, type = "aura", unit = "player", name = "燃燒", glowOnApply = true },     -- Combustion
        { id = 11426, type = "aura", unit = "player", name = "寒冰護體" },                    -- Ice Barrier
        { id = 22959, type = "aura", unit = "target", name = "火焰易傷" },                    -- Improved Scorch
    },
    WARRIOR = {
        { id = 11585, type = "spellCooldown", name = "壓制", glowOnUsable = true },             -- Overpower
        { id = 20662, type = "spellCooldown", name = "斬殺", glowOnUsable = true },             -- Execute
        { id = 14202, type = "aura", unit = "player", name = "狂怒", glowOnApply = true },     -- Enrage
        { id = 16282, type = "aura", unit = "player", name = "亂擊", glowOnApply = true },     -- Flurry
        { id = 12292, type = "aura", unit = "player", name = "死亡之願" },                    -- Death Wish
        { id = 2565,  type = "aura", unit = "player", name = "盾牌格擋" },                    -- Shield Block
        { id = 18499, type = "aura", unit = "player", name = "狂暴之怒" },                    -- Berserker Rage
    },
    ROGUE = {
        { id = 14251, type = "spellCooldown", name = "還擊", glowOnUsable = true },             -- Riposte
        { id = 14149, type = "aura", unit = "player", name = "無情打擊", glowOnApply = true }, -- Remorseless Attacks
        { id = 13750, type = "aura", unit = "player", name = "衝動", glowOnApply = true },     -- Adrenaline Rush
        { id = 13877, type = "aura", unit = "player", name = "劍刃亂舞" },                    -- Blade Flurry
        { id = 6774,  type = "aura", unit = "player", name = "切割" },                        -- Slice and Dice
        { id = 5277,  type = "aura", unit = "player", name = "閃避" },                        -- Evasion
    },
    PRIEST = {
        { id = 17941, type = "aura", unit = "player", name = "暗影冥思 (夜幕)", glowOnApply = true }, -- Shadow Trance (Nightfall)
        { id = 15338, type = "aura", unit = "player", name = "精神分流", glowOnApply = true }, -- Spirit Tap
        { id = 10060, type = "aura", unit = "player", name = "能量灌注" },                    -- Power Infusion
        { id = 1006,  type = "aura", unit = "player", name = "心靈之火" },                    -- Inner Fire
        { id = 6788,  type = "aura", unit = "target", name = "虛弱靈魂" },                    -- Weakened Soul
    },
    WARLOCK = {
        { id = 17941, type = "aura", unit = "player", name = "夜幕 (暗影冥思)", glowOnApply = true }, -- Nightfall
        { id = 17800, type = "aura", unit = "target", name = "暗影易傷" },                    -- Shadow Vulnerability
        { id = 18708, type = "aura", unit = "player", name = "惡魔支配" },                    -- Fel Domination
    },
    HUNTER = {
        { id = 19556, type = "aura", unit = "player", name = "強化雄鷹守護", glowOnApply = true }, -- Improved Aspect of the Hawk
        { id = 19625, type = "aura", unit = "player", name = "狂亂 (寵物)", glowOnApply = true },  -- Frenzy
        { id = 3045,  type = "aura", unit = "player", name = "急速射擊" },                    -- Rapid Fire
        { id = 19263, type = "aura", unit = "player", name = "威懾" },                        -- Deterrence
        { id = 20906, type = "aura", unit = "player", name = "強擊光環" },                    -- Trueshot Aura
    },
    SHAMAN = {
        { id = 16246, type = "aura", unit = "player", name = "元素集中 (節能)", glowOnApply = true }, -- Clearcasting
        { id = 16280, type = "aura", unit = "player", name = "亂擊", glowOnApply = true },     -- Flurry
        { id = 17116, type = "aura", unit = "player", name = "自然迅捷" },                    -- Nature's Swiftness
        { id = 10432, type = "aura", unit = "player", name = "閃電之盾" },                    -- Lightning Shield
    },
    PALADIN = {
        { id = 20137, type = "aura", unit = "player", name = "壁壘", glowOnApply = true },     -- Redoubt
        { id = 20182, type = "aura", unit = "player", name = "清算", glowOnApply = true },     -- Reckoning
        { id = 20059, type = "aura", unit = "player", name = "復仇", glowOnApply = true },     -- Vengeance
        { id = 20216, type = "aura", unit = "player", name = "神恩術" },                      -- Divine Favor
        { id = 642,   type = "aura", unit = "player", name = "聖盾術" },                      -- Divine Shield
        { id = 25771, type = "aura", unit = "player", name = "自律" },                        -- Forbearance
    },
    DRUID = {
        { id = 16870, type = "aura", unit = "player", name = "清晰預兆", glowOnApply = true }, -- Omen of Clarity
        { id = 17116, type = "aura", unit = "player", name = "自然迅捷" },                    -- Nature's Swiftness
        { id = 5229,  type = "aura", unit = "player", name = "激怒" },                        -- Enrage
        { id = 9846,  type = "aura", unit = "player", name = "猛虎之怒" },                    -- Tiger's Fury
        { id = 22812, type = "aura", unit = "player", name = "樹皮術" },                      -- Barkskin
        { id = 29166, type = "aura", unit = "player", name = "啟動" },                        -- Innervate
    },
    -- 經典 60 級核心飾品 / 武器附魔 / 露營 / 天靈種族特徵
    GENERAL = {
        { id = 20007, type = "aura", unit = "player", name = "附魔：十字軍 (神聖之力)", glowOnApply = true }, -- Holy Strength (Crusader)
        { id = 20004, type = "aura", unit = "player", name = "附魔：生命偷取" },                             -- Lifestealing
        { id = 24427, type = "aura", unit = "player", name = "飾品：鑽石水瓶" },                             -- Diamond Flask
        { id = 16954, type = "aura", unit = "player", name = "飾品：荊棘之木" },                             -- Briarwood Reed
        { id = 15600, type = "aura", unit = "player", name = "飾品：正義之手" },                             -- Hand of Justice
        { id = 23723, type = "aura", unit = "player", name = "飾品：思緒加速寶石" },                         -- Mind Quickening Gem
        { id = 24658, type = "aura", unit = "player", name = "飾品：贊達拉英雄護符" },                         -- Zandalarian Hero Charm
        { id = 25891, type = "aura", unit = "player", name = "飾品：大地之擊" },                             -- Earthstrike
        { id = 28866, type = "aura", unit = "player", name = "飾品：蜘蛛之吻" },                             -- Kiss of the Spider
        -- 露營與 Plus 專屬特性
        { id = 402120, type = "aura", unit = "player", name = "安逸睡袋 (雙倍精力增益)" },                    -- Cozy Sleeping Bag
    },
}

function ForeverCatalog.GetDefaultAlerts(classToken)
    local classAlerts = (classToken and FOREVER_DEFAULT_ALERTS[classToken]) or {}
    local generalAlerts = FOREVER_DEFAULT_ALERTS.GENERAL or {}
    local combined = {}
    for i = 1, #classAlerts do
        combined[#combined + 1] = classAlerts[i]
    end
    for i = 1, #generalAlerts do
        combined[#combined + 1] = generalAlerts[i]
    end
    return combined
end

-------------------------------------------------------------------------------
-- 4. Forever 專屬啟發規則 (Forever Spell Heuristics)
-------------------------------------------------------------------------------
local FOREVER_SPELL_HEURISTICS = {
    -- 經典 5 秒規則法力監控
    [12536] = { isClearcasting = true, refundCost = true },
    [16246] = { isClearcasting = true, refundCost = true },
    [16870] = { isClearcasting = true, refundCost = true },
    -- 經典觸發型冷卻技
    [11585] = { requiresDodge = true, stanceLimit = 1 }, -- 壓制 (戰鬥姿態)
    [14251] = { requiresParry = true },                  -- 還擊
    [20662] = { targetHealthThreshold = 0.20 },          -- 斬殺 (20% 血量)
}

function ForeverCatalog.GetSpellHeuristics(spellID)
    if spellID then
        return FOREVER_SPELL_HEURISTICS[spellID]
    end
    return FOREVER_SPELL_HEURISTICS
end


-------------------------------------------------------------------------------
-- 5. Forever 經典法術等級家族定義 (Forever Spell Rank Families)
-------------------------------------------------------------------------------
local FOREVER_SPELL_RANK_FAMILIES = {
    -- 戰士
    WARRIOR_BATTLE_SHOUT = { 6673, 5242, 6192, 11549, 11550, 11551, 25289 },
    WARRIOR_SUNDER_ARMOR = { 7386, 7405, 8380, 11596, 11597 },
    WARRIOR_REND = { 772, 6546, 6547, 6548, 11572, 11573, 11574 },
    WARRIOR_THUNDER_CLAP = { 6343, 8198, 8204, 8205, 11580, 11581 },
    WARRIOR_DEMORALIZING_SHOUT = { 1160, 6190, 11554, 11555, 11556 },
    WARRIOR_OVERPOWER = { 7384, 7887, 11584, 11585 },
    WARRIOR_EXECUTE = { 5308, 20658, 20660, 20661, 20662 },
    WARRIOR_MORTAL_STRIKE = { 12294, 21551, 21552, 21553 },
    -- 法師
    MAGE_FROST_NOVA = { 122, 865, 6131, 10230 },
    MAGE_CONE_OF_COLD = { 120, 8492, 10159, 10160, 10161 },
    MAGE_BLIZZARD = { 10, 6141, 8427, 10185, 10186, 10187 },
    MAGE_FLAMESTRIKE = { 2120, 2121, 8422, 8423, 10215, 10216 },
    MAGE_ICE_BARRIER = { 11426, 13031, 13032, 13033 },
    MAGE_MANA_SHIELD = { 1463, 8494, 8495, 10191, 10192, 10193 },
    MAGE_FIRE_WARD = { 543, 8457, 8458, 10223, 10225 },
    MAGE_FROST_WARD = { 6143, 8461, 8462, 10177, 28609 },
    MAGE_ARCANE_INTELLECT = { 1459, 1460, 1461, 10156, 10157 },
    MAGE_POLYMORPH = { 118, 12824, 12825, 12826 },
    MAGE_FROSTBOLT = { 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304 },
    MAGE_FIREBALL = { 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306 },
    -- 牧師
    PRIEST_POWER_WORD_SHIELD = { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 },
    PRIEST_RENEW = { 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315 },
    PRIEST_SHADOW_WORD_PAIN = { 589, 594, 970, 992, 2767, 10892, 10893, 10894 },
    PRIEST_POWER_WORD_FORTITUDE = { 1243, 1244, 1245, 2791, 10937, 10938 },
    PRIEST_PSYCHIC_SCREAM = { 8122, 8124, 10888, 10890 },
    PRIEST_MIND_BLAST = { 8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947 },
    -- 術士
    WARLOCK_CORRUPTION = { 172, 6222, 6223, 7648, 11671, 11672, 25311 },
    WARLOCK_CURSE_OF_AGONY = { 980, 1014, 6217, 11711, 11712, 11713 },
    WARLOCK_IMMOLATE = { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 },
    WARLOCK_CURSE_OF_ELEMENTS = { 1490, 11721, 11722 },
    WARLOCK_CURSE_OF_SHADOW = { 17862, 17937 },
    WARLOCK_CURSE_OF_RECKLESSNESS = { 702, 1108, 6205, 7646, 11717 },
    WARLOCK_FEAR = { 5782, 6213, 6215 },
    WARLOCK_RAIN_OF_FIRE = { 5740, 6219, 11677, 11678 },
    WARLOCK_HELLFIRE = { 1949, 11683, 11684 },
    -- 德魯伊
    DRUID_MARK_OF_THE_WILD = { 1126, 5232, 6756, 5234, 8907, 9884, 9885 },
    DRUID_REJUVENATION = { 774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299 },
    DRUID_REGROWTH = { 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858 },
    DRUID_MOONFIRE = { 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835 },
    DRUID_INSECT_SWARM = { 5570, 24968, 24969, 24970, 24971 },
    DRUID_FAERIE_FIRE = { 770, 778, 9749, 9907 },
    DRUID_FAERIE_FIRE_FERAL = { 16857, 17390, 17391, 17392 },
    DRUID_ENTANGLING_ROOTS = { 339, 1062, 5195, 5196, 9852, 9853 },
    DRUID_HURRICANE = { 16914, 17401, 17402 },
    -- 聖騎士
    PALADIN_CONSECRATION = { 26573, 20116, 20922, 20923, 20924 },
    PALADIN_BLESSING_OF_MIGHT = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 },
    PALADIN_BLESSING_OF_WISDOM = { 19742, 19850, 19852, 19853, 19854, 25290 },
    PALADIN_BLESSING_OF_PROTECTION = { 1022, 5599, 10278 },
    PALADIN_HAMMER_OF_JUSTICE = { 853, 5588, 5589, 10308 },
    PALADIN_HOLY_SHOCK = { 20473, 20929, 20930 },
    -- 獵人
    HUNTER_MARK = { 1130, 14323, 14324, 14325 },
    HUNTER_SERPENT_STING = { 1978, 13549, 13550, 13551, 13552, 13553, 13554, 13555, 25295 },
    HUNTER_EXPLOSIVE_TRAP = { 13813, 14316, 14317 },
    HUNTER_IMMOLATION_TRAP = { 13795, 14302, 14303, 14304, 14305 },
    HUNTER_FREEZING_TRAP = { 1499, 14310, 14311 },
    HUNTER_VOLLEY = { 1510, 14294, 14295 },
    HUNTER_MULTI_SHOT = { 2643, 14288, 14289, 14290, 25294 },
    HUNTER_AIMED_SHOT = { 19434, 20900, 20901, 20902, 20903, 20904 },
    -- 盜賊
    ROGUE_SLICE_AND_DICE = { 5171, 6774 },
    ROGUE_RUPTURE = { 1943, 8639, 8640, 11273, 11274, 11275 },
    ROGUE_GARROTE = { 703, 8631, 8632, 8633, 11289, 11290 },
    ROGUE_KIDNEY_SHOT = { 408, 8643 },
    ROGUE_SAP = { 6770, 2070, 11297 },
    ROGUE_GOUGE = { 1776, 1777, 8629, 11267, 11268 },
    ROGUE_VANISH = { 1856, 1857 },
    ROGUE_SPRINT = { 2983, 8696, 11305 },
    ROGUE_EVASION = { 5277, 26669 },
    -- 薩滿
    SHAMAN_FLAME_SHOCK = { 8050, 8052, 8053, 10447, 10448, 29228 },
    SHAMAN_EARTH_SHOCK = { 8042, 8044, 8045, 8046, 10412, 10413, 10414 },
    SHAMAN_FROST_SHOCK = { 8056, 8058, 10472, 10473 },
    SHAMAN_LIGHTNING_SHIELD = { 324, 325, 905, 945, 8134, 10431, 10432 },
    SHAMAN_MAGMA_TOTEM = { 8190, 10585, 10586, 10587 },
    SHAMAN_SEARING_TOTEM = { 3599, 6363, 6364, 6365, 10437, 10438 },
    SHAMAN_STONECLAW_TOTEM = { 5730, 6390, 6391, 6392, 10427, 10428 },
    SHAMAN_FIRE_NOVA_TOTEM = { 1535, 8498, 8499, 11314, 11315 },
}

local rankFamilyLookup = {}
for _, family in pairs(FOREVER_SPELL_RANK_FAMILIES) do
    for i = 1, #family do
        rankFamilyLookup[family[i]] = family
    end
end

function ForeverCatalog.GetRankFamilyBySpellID(spellID)
    if not spellID then return nil end
    return rankFamilyLookup[spellID]
end

function ForeverCatalog.GetRankFamilies()
    return FOREVER_SPELL_RANK_FAMILIES
end

EAM.Data.ForeverCatalog = freeze(ForeverCatalog)
