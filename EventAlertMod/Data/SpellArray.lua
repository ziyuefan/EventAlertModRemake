--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Data/SpellArray
檔案: Data\SpellArray.lua

實戰校對版本: 12.0.7 (Midnight-era)
優化內容:
- 精確校對 DoT/HoT 的 30% Pandemic 時間（例如狂狂 2.4s, 黑箭 5.4s, 曙光 2.4s）。
- 新增資源防溢出高亮屬性 (maxStacksAlert / minStacksAlert)。
- 新增移動狀態引導屬性 (grayOnMove = true) 與移動防護 Buff (moveBuffs)。
- 新增爆發期降噪屏蔽屬性 (burstFilterActive) 與高亮對齊。
]]

local _, EAM = ...

EAM.Data.SpellArray = {
    MAGE = {
        specs = {
            [1] = "秘法 (Arcane)",
            [2] = "火焰 (Fire)",
            [3] = "冰霜 (Frost)"
        },
        [1] = { -- Arcane
            { id = 12051, type = "spellCooldown", grayOnMove = true, moveBuffs = { 108839 } }, -- 喚醒 (移動且無浮冰時置灰)
            { id = 195740, type = "aura", unit = "player", glowOnApply = true }, -- 大法師之觸 (核心爆發觸發)
            { id = 382445, type = "aura", unit = "player", maxStacksAlert = 2 }, -- 虛空精準 (最大2層，防溢出)
            { id = 444619, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 日怒：能量重擔
            { id = 5143, type = "spellCooldown", grayOnMove = true, moveBuffs = { 108839 } } -- 秘法衝擊 (常規讀條)
        },
        [2] = { -- Fire
            { id = 190319, type = "spellCooldown" }, -- 燃燒 (核心爆發)
            { id = 48108, type = "aura", unit = "player", glowOnApply = true }, -- 臨界熾熱
            { id = 48107, type = "aura", unit = "player", glowOnApply = true }, -- 炎爆術! (大晴天)
            -- 活動炸彈：在燃燒(190319)期間屏蔽 Pandemic Glow 提示，降噪優化
            { id = 117828, type = "aura", unit = "target", pandemicTime = 3.6, burstFilterActive = 190319 }, 
            { id = 444619, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 日怒：能量重擔
            { id = 444625, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 霜火：霜火賦能 (瞬發插隊)
            { id = 133, type = "spellCooldown", grayOnMove = true, moveBuffs = { 108839 } }, -- 火球術
            { id = 2120, type = "spellCooldown", grayOnMove = true, moveBuffs = { 108839 } } -- 烈焰風暴
        },
        [3] = { -- Frost
            { id = 12472, type = "spellCooldown" }, -- 冰冷血脈
            { id = 44544, type = "aura", unit = "player", maxStacksAlert = 2 }, -- 寒冰指 (2層高亮)
            { id = 195457, type = "aura", unit = "player", glowOnApply = true }, -- 腦凍結
            { id = 444621, type = "aura", unit = "player", maxStacksAlert = 8 }, -- [Hero] 裂空者：法術碎屑 (8層大爆炸)
            { id = 444625, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 霜火：霜火賦能
            { id = 116, type = "spellCooldown", grayOnMove = true, moveBuffs = { 108839 } }, -- 寒冰箭
            { id = 228597, type = "spellCooldown", grayOnMove = true, moveBuffs = { 108839 } } -- 冰川長槍
        },
        general = {
            { id = 80353, type = "aura", unit = "player" }, -- 時間扭曲
            { id = 45438, type = "spellCooldown" }, -- 寒冰屏障
            { id = 235450, type = "aura", unit = "player" } -- 稜光護盾
        }
    },
    WARRIOR = {
        specs = {
            [1] = "武器 (Arms)",
            [2] = "狂怒 (Fury)",
            [3] = "防護 (Protection)"
        },
        [1] = { -- Arms
            { id = 26070, type = "aura", unit = "player", pandemicTime = 3.6 }, -- 橫掃攻擊
            { id = 262161, type = "spellCooldown" }, -- 戰術大師
            { id = 1719, type = "spellCooldown" }, -- 魯莽
            { id = 435345, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 屠宰者：屠手打擊
            { id = 434947, type = "aura", unit = "player", maxStacksAlert = 10, minStacksAlert = 3 } -- [Hero] 巨像：巨像之力 (10層發光)
        },
        [2] = { -- Fury
            { id = 184362, type = "aura", unit = "player", pandemicTime = 1.2 }, -- 激怒 (Pandemic 1.2s 刷新)
            { id = 184364, type = "aura", unit = "player" }, -- 狂暴怒火
            { id = 435345, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 屠宰者：屠手打擊
            { id = 433784, type = "aura", unit = "player" } -- [Hero] 山脈之王：閃電打擊
        },
        [3] = { -- Protection
            { id = 871, type = "spellCooldown" }, -- 盾牆
            { id = 12975, type = "spellCooldown" }, -- 破釜沉舟
            { id = 132404, type = "aura", unit = "player", pandemicTime = 1.8 }, -- 盾牌格擋 (Pandemic 1.8s)
            { id = 190456, type = "aura", unit = "player", showValue = true }, -- 無視苦痛 (顯示數值)
            { id = 434947, type = "aura", unit = "player", maxStacksAlert = 10, minStacksAlert = 3 }, -- [Hero] 巨像：巨像之力
            { id = 433784, type = "aura", unit = "player" } -- [Hero] 山脈之王：閃電打擊
        },
        general = {
            { id = 107574, type = "spellCooldown" }, -- 天神下凡
            { id = 97462, type = "spellCooldown" } -- 團隊集結吶喊
        }
    },
    PALADIN = {
        specs = {
            [1] = "神聖 (Holy)",
            [2] = "防護 (Protection)",
            [3] = "懲戒 (Retribution)"
        },
        [1] = { -- Holy
            { id = 31821, type = "spellCooldown" }, -- 光環精通
            { id = 200025, type = "aura", unit = "player", pandemicTime = 2.4 }, -- 美德道標 (Pandemic 2.4s)
            { id = 498, type = "spellCooldown" }, -- 聖佑術
            { id = 432459, type = "aura", unit = "player" }, -- [Hero] 光鑄者：神聖壁壘
            { id = 427447, type = "aura", unit = "target", pandemicTime = 2.4 }, -- [Hero] 烈日先驅：曙光 (Pandemic 2.4s)
            { id = 823, type = "spellCooldown", grayOnMove = true }, -- 聖光術 (移動讀條置灰)
            { id = 19750, type = "spellCooldown", grayOnMove = true } -- 聖光閃現
        },
        [2] = { -- Protection
            { id = 132403, type = "aura", unit = "player", pandemicTime = 1.35 }, -- 正義盾擊 (Pandemic 1.35s)
            { id = 31850, type = "spellCooldown" }, -- 熾熱防禦者
            { id = 86659, type = "spellCooldown" }, -- 古代列王守護者
            { id = 223817, type = "aura", unit = "player", glowOnApply = true }, -- 神聖意志
            { id = 432470, type = "aura", unit = "player" }, -- [Hero] 光鑄者：神聖武器
            { id = 431398, type = "aura", unit = "player", glowOnApply = true } -- [Hero] 聖殿騎士：聖天之錘
        },
        [3] = { -- Retribution
            { id = 31884, type = "spellCooldown" }, -- 復仇之怒 (翅膀)
            { id = 223819, type = "aura", unit = "player", pandemicTime = 4.5 }, -- 狂熱
            { id = 343721, type = "spellCooldown" }, -- 最終審判
            { id = 431398, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 聖殿騎士：聖天之錘
            { id = 427447, type = "aura", unit = "target", pandemicTime = 2.4 } -- [Hero] 烈日先驅：曙光
        },
        general = {
            { id = 642, type = "spellCooldown" }, -- 聖盾術
            { id = 1022, type = "spellCooldown" } -- 保護祝福
        }
    },
    HUNTER = {
        specs = {
            [1] = "野獸控制 (Beast Mastery)",
            [2] = "射擊 (Marksmanship)",
            [3] = "生存 (Survival)"
        },
        [1] = { -- Beast Mastery
            { id = 193530, type = "spellCooldown" }, -- 野性守護
            { id = 268877, type = "aura", unit = "pet", pandemicTime = 2.4, maxStacksAlert = 3 }, -- 寵物狂亂 (Pandemic 2.4s, 3層發光)
            { id = 118455, type = "aura", unit = "pet", pandemicTime = 1.8 }, -- 野獸順劈斬 (Pandemic 1.8s)
            { id = 430703, type = "aura", unit = "target", maxStacksAlert = 10 }, -- [Hero] 哨兵：哨兵印記
            { id = 431057, type = "aura", unit = "player", glowOnApply = true } -- [Hero] 荒野領袖：惡性狩獵
        },
        [2] = { -- Marksmanship
            { id = 288613, type = "spellCooldown" }, -- 百發百中
            { id = 257622, type = "aura", unit = "player", pandemicTime = 1.8 }, -- 技巧射擊
            { id = 430703, type = "aura", unit = "target", maxStacksAlert = 10 }, -- [Hero] 哨兵：哨兵印記
            { id = 430703, type = "aura", unit = "player", pandemicTime = 5.4 }, -- [Hero] 黑暗遊俠：黑箭 (DoT Pandemic 5.4s)
            { id = 19434, type = "spellCooldown", grayOnMove = true } -- 瞄準射擊 (移動置灰，除非瞬發)
        },
        [3] = { -- Survival
            { id = 266779, type = "spellCooldown" }, -- 協同進攻
            { id = 269747, type = "aura", unit = "target", pandemicTime = 2.4 }, -- 狂野炸彈撕裂
            { id = 431057, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 荒野領袖：惡性狩獵
            { id = 430703, type = "aura", unit = "player", pandemicTime = 5.4 } -- [Hero] 黑暗遊俠：黑箭
        },
        general = {
            { id = 186265, type = "spellCooldown" }, -- 龜殼守護
            { id = 5384, type = "spellCooldown" } -- 假死
        }
    },
    ROGUE = {
        specs = {
            [1] = "刺殺 (Assassination)",
            [2] = "暴徒 (Outlaw)",
            [3] = "敏銳 (Subtlety)"
        },
        [1] = { -- Assassination
            { id = 79140, type = "spellCooldown" }, -- 仇殺/死亡印記
            { id = 1943, type = "aura", unit = "target", pandemicTime = 7.2 }, -- 割裂 (Pandemic 7.2s)
            { id = 703, type = "aura", unit = "target", pandemicTime = 5.4 }, -- 絞喉 (Pandemic 5.4s)
            { id = 425313, type = "aura", unit = "target", glowOnApply = true }, -- [Hero] 死亡獵手：死亡標記
            { id = 428059, type = "aura", unit = "player" } -- [Hero] 天命之縛：命運硬幣
        },
        [2] = { -- Outlaw
            { id = 13750, type = "spellCooldown" }, -- 能量刺激
            { id = 193356, type = "aura", unit = "player", pandemicTime = 9.0 }, -- 命運骨牌
            { id = 428059, type = "aura", unit = "player" }, -- [Hero] 天命之縛：命運硬幣
            { id = 429311, type = "aura", unit = "player", pandemicTime = 3.6 } -- [Hero] 欺詐者：完美無瑕
        },
        [3] = { -- Subtlety
            { id = 185313, type = "spellCooldown" }, -- 陰影之舞
            { id = 315496, type = "aura", unit = "player", pandemicTime = 10.8 }, -- 切割
            { id = 425313, type = "aura", unit = "target", glowOnApply = true }, -- [Hero] 死亡獵手：死亡標記
            { id = 429311, type = "aura", unit = "player", pandemicTime = 3.6 } -- [Hero] 欺詐者：完美無瑕
        },
        general = {
            { id = 5277, type = "spellCooldown" }, -- 閃避
            { id = 31224, type = "spellCooldown" } -- 闇影披風
        }
    },
    PRIEST = {
        specs = {
            [1] = "戒律 (Discipline)",
            [2] = "神聖 (Holy)",
            [3] = "暗影 (Shadow)"
        },
        [1] = { -- Discipline
            { id = 33206, type = "spellCooldown" }, -- 痛苦壓制
            { id = 62618, type = "spellCooldown" }, -- 真言術: 障
            { id = 81782, type = "aura", unit = "player", pandemicTime = 4.5 }, -- 救贖 (Atonement)
            { id = 426817, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 神諭者：預知
            { id = 426871, type = "aura", unit = "player" }, -- [Hero] 虛空編織者：虛空裂隙
            { id = 47540, type = "spellCooldown", grayOnMove = true }, -- 懲擊/苦修 (移動讀條置灰)
            { id = 194118, type = "spellCooldown", grayOnMove = true } -- 真言術: 耀
        },
        [2] = { -- Holy
            { id = 47788, type = "spellCooldown" }, -- 守護之魂
            { id = 139, type = "aura", unit = "player", pandemicTime = 4.5 }, -- 恢復
            { id = 64843, type = "spellCooldown" }, -- 神聖讚美詩
            { id = 426817, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 神諭者：預知
            { id = 120517, type = "spellCooldown", glowOnApply = true }, -- [Hero] 執政官：神聖光暈
            { id = 2060, type = "spellCooldown", grayOnMove = true }, -- 治療術
            { id = 596, type = "spellCooldown", grayOnMove = true } -- 治療禱言
        },
        [3] = { -- Shadow
            { id = 228260, type = "aura", unit = "player" }, -- 虛空形態
            { id = 34914, type = "aura", unit = "target", pandemicTime = 6.3 }, -- 吸血鬼之觸
            { id = 589, type = "aura", unit = "target", pandemicTime = 5.4 }, -- 暗影之言：痛
            { id = 426871, type = "aura", unit = "player" }, -- [Hero] 虛空編織者：虛空裂隙
            { id = 120517, type = "spellCooldown", glowOnApply = true }, -- [Hero] 執政官：神聖光暈
            { id = 8092, type = "spellCooldown", grayOnMove = true }, -- 心靈震爆
            { id = 15407, type = "spellCooldown", grayOnMove = true } -- 精神鞭笞
        },
        general = {
            { id = 17, type = "aura", unit = "player" }, -- 真言術: 盾
            { id = 15286, type = "spellCooldown" } -- 吸血鬼的擁抱
        }
    },
    DEATHKNIGHT = {
        specs = {
            [1] = "鮮血 (Blood)",
            [2] = "冰霜 (Frost)",
            [3] = "邪惡 (Unholy)"
        },
        [1] = { -- Blood
            { id = 55233, type = "spellCooldown" }, -- 吸血鬼之血
            { id = 49028, type = "spellCooldown" }, -- 符文分流
            { id = 195181, type = "aura", unit = "player", pandemicTime = 9.0, minStacksAlert = 3 }, -- 骸骨之盾 (低於3層警告)
            { id = 439843, type = "aura", unit = "target", glowOnApply = true }, -- [Hero] 死亡使者：死神印記
            { id = 435349, type = "aura", unit = "player", pandemicTime = 3.6 } -- [Hero] 薩萊茵：薩萊茵之賜
        },
        [2] = { -- Frost
            { id = 47568, type = "spellCooldown" }, -- 符文武器增效
            { id = 196770, type = "aura", unit = "player", pandemicTime = 2.4 }, -- 冷酷嚴冬
            { id = 51271, type = "spellCooldown" }, -- 冰霜之柱
            { id = 439843, type = "aura", unit = "target", glowOnApply = true }, -- [Hero] 死亡使者：死神印記
            { id = 428815, type = "aura", unit = "player" } -- [Hero] 天啟騎士：天啟之護 (召喚增益)
        },
        [3] = { -- Unholy
            { id = 63560, type = "aura", unit = "player", pandemicTime = 4.5 }, -- 黑暗突變
            { id = 191587, type = "aura", unit = "target", pandemicTime = 8.1 }, -- 惡性瘟疫
            { id = 435349, type = "aura", unit = "player", pandemicTime = 3.6 }, -- [Hero] 薩萊茵：薩萊茵之賜
            { id = 428815, type = "aura", unit = "player" } -- [Hero] 天啟騎士：天啟之護
        },
        general = {
            { id = 48792, type = "spellCooldown" }, -- 冰封之韌
            { id = 48707, type = "spellCooldown" } -- 反魔法護罩
        }
    },
    SHAMAN = {
        specs = {
            [1] = "元素 (Elemental)",
            [2] = "增強 (Enhancement)",
            [3] = "恢復 (Restoration)"
        },
        [1] = { -- Elemental
            { id = 191634, type = "spellCooldown" }, -- 風暴守護者
            { id = 188389, type = "aura", unit = "target", pandemicTime = 5.4 }, -- 烈焰震擊
            { id = 114050, type = "spellCooldown" }, -- 卓越術
            { id = 452201, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 風暴使者：狂風暴雨
            { id = 426815, type = "aura", unit = "player" }, -- [Hero] 先知：先祖召喚
            { id = 188196, type = "spellCooldown", grayOnMove = true, moveBuffs = { 79206 } }, -- 閃電箭 (移動且無靈行者置灰)
            { id = 51505, type = "spellCooldown", grayOnMove = true, moveBuffs = { 79206 } } -- 熔岩爆裂 (移動置灰)
        },
        [2] = { -- Enhancement
            { id = 114051, type = "spellCooldown" }, -- 卓越術 (近戰)
            { id = 344179, type = "aura", unit = "player", maxStacksAlert = 10 }, -- 漩渦武器 (10層警告防溢出)
            { id = 201898, type = "aura", unit = "player" }, -- 野性之魂
            { id = 452201, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 風暴使者：狂風暴雨
            { id = 426851, type = "aura", unit = "player" } -- [Hero] 圖騰大師：澎湃圖騰
        },
        [3] = { -- Restoration
            { id = 98008, type = "spellCooldown" }, -- 靈魂連結圖騰
            { id = 974, type = "aura", unit = "player", minStacksAlert = 2 }, -- 大地之盾 (小於2層警告)
            { id = 61295, type = "aura", unit = "player", pandemicTime = 5.4 }, -- 激流
            { id = 426815, type = "aura", unit = "player" }, -- [Hero] 先知：先祖召喚
            { id = 426851, type = "aura", unit = "player" } -- [Hero] 圖騰大師：澎湃圖騰
        },
        general = {
            { id = 108271, type = "spellCooldown" }, -- 星界轉移
            { id = 79206, type = "spellCooldown" } -- 靈行者之賜
        }
    },
    MONK = {
        specs = {
            [1] = "釀酒 (Brewmaster)",
            [2] = "織霧 (Mistweaver)",
            [3] = "御風 (Windwalker)"
        },
        [1] = { -- Brewmaster
            { id = 124275, type = "stagger", colorGrading = true }, -- 醉拳 (三色判定)
            { id = 322507, type = "aura", unit = "player", showValue = true }, -- 天神酒 (吸收量化)
            { id = 325093, type = "aura", unit = "player", maxStacksAlert = 10 }, -- 淬鍊靈藥 (10層高亮)
            { id = 428815, type = "aura", unit = "player", maxStacksAlert = 10 }, -- [Hero] 影蹤派：疾風亂舞 (滿能高亮)
            { id = 428821, type = "aura", unit = "player" } -- [Hero] 和諧大師：真氣融合
        },
        [2] = { -- Mistweaver
            { id = 116849, type = "spellCooldown" }, -- 作繭自縛
            { id = 119611, type = "aura", unit = "player", pandemicTime = 6.0 }, -- 復甦之霧
            { id = 115310, type = "spellCooldown" }, -- 五氣朝元
            { id = 428821, type = "aura", unit = "player" }, -- [Hero] 和諧大師：真氣融合
            { id = 428831, type = "aura", unit = "player", glowOnApply = true } -- [Hero] 天神指引者：天神引導
        },
        [3] = { -- Windwalker
            { id = 123904, type = "spellCooldown" }, -- 白虎下凡
            { id = 325201, type = "aura", unit = "player", glowOnApply = true }, -- 赤精之舞
            { id = 137639, type = "spellCooldown" }, -- 風狂砂 (分身)
            { id = 428815, type = "aura", unit = "player", maxStacksAlert = 10 }, -- [Hero] 影蹤派：疾風亂舞
            { id = 428831, type = "aura", unit = "player", glowOnApply = true } -- [Hero] 天神指引者：天神引導
        },
        general = {
            { id = 122278, type = "spellCooldown" }, -- 害人害己
            { id = 122783, type = "spellCooldown" } -- 卸勁訣
        }
    },
    DRUID = {
        specs = {
            [1] = "平衡 (Balance)",
            [2] = "野性戰鬥 (Feral)",
            [3] = "守護者 (Guardian)",
            [4] = "恢復 (Restoration)"
        },
        [1] = { -- Balance
            { id = 102560, type = "spellCooldown" }, -- 化身: 艾露恩之眷
            { id = 8921, type = "aura", unit = "target", pandemicTime = 6.6 }, -- 月火術 (Pandemic 6.6s)
            { id = 93402, type = "aura", unit = "target", pandemicTime = 5.4 }, -- 陽火術 (Pandemic 5.4s)
            { id = 202246, type = "spellCooldown", glowOnApply = true }, -- [Hero] 艾露恩之選：艾之怒
            { id = 426817, type = "aura", unit = "player" }, -- [Hero] 叢林守護者：夢境
            { id = 5176, type = "spellCooldown", grayOnMove = true }, -- 憤怒 (移動讀條置灰)
            { id = 2912, type = "spellCooldown", grayOnMove = true } -- 星火術
        },
        [2] = { -- Feral
            { id = 106951, type = "spellCooldown" }, -- 狂暴
            { id = 1079, type = "aura", unit = "target", pandemicTime = 7.2 }, -- 割裂 (Pandemic 7.2s)
            { id = 1822, type = "aura", unit = "target", pandemicTime = 4.5 }, -- 斜掠 (Pandemic 4.5s)
            { id = 5217, type = "spellCooldown" }, -- 猛虎之怒
            { id = 426821, type = "aura", unit = "target", pandemicTime = 3.6 } -- [Hero] 荒野追獵者：荒野荊棘 (Pandemic 3.6s)
        },
        [3] = { -- Guardian
            { id = 102558, type = "spellCooldown" }, -- 化身: 烏索克之守護
            { id = 192081, type = "aura", unit = "player", pandemicTime = 1.8 }, -- 鐵鬃 (Pandemic 1.8s)
            { id = 22812, type = "spellCooldown" }, -- 樹皮術
            { id = 426831, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 利爪德魯伊：猛掠
            { id = 202246, type = "spellCooldown", glowOnApply = true } -- [Hero] 艾露恩之選：艾之怒
        },
        [4] = { -- Restoration
            { id = 33891, type = "spellCooldown" }, -- 生命之樹
            { id = 774, type = "aura", unit = "player", pandemicTime = 4.5 }, -- 回春術 (Pandemic 4.5s)
            { id = 33763, type = "aura", unit = "player", pandemicTime = 4.5 }, -- 生命綻放 (Pandemic 4.5s)
            { id = 740, type = "spellCooldown" }, -- 寧靜
            { id = 426817, type = "aura", unit = "player" }, -- [Hero] 叢林守護者：夢境
            { id = 426821, type = "aura", unit = "target", pandemicTime = 3.6 } -- [Hero] 荒野追獵者：荒野荊棘
        },
        general = {
            { id = 102401, type = "spellCooldown" }, -- 野性衝鋒
            { id = 29166, type = "spellCooldown" } -- 啟動
        }
    },
    WARLOCK = {
        specs = {
            [1] = "痛苦 (Affliction)",
            [2] = "惡魔學識 (Demonology)",
            [3] = "毀滅 (Destruction)"
        },
        [1] = { -- Affliction
            { id = 205180, type = "spellCooldown" }, -- 召喚黑眼
            { id = 980, type = "aura", unit = "target", pandemicTime = 5.4 }, -- 痛楚 (Pandemic 5.4s)
            { id = 172, type = "aura", unit = "target", pandemicTime = 4.2 }, -- 腐蝕術 (Pandemic 4.2s)
            { id = 316099, type = "aura", unit = "target", pandemicTime = 6.3 }, -- 痛苦無常 (Pandemic 6.3s)
            { id = 198590, type = "aura", unit = "player" }, -- 靈魂腐爛
            { id = 427815, type = "aura", unit = "player" }, -- [Hero] 靈魂收割者：共同命運
            { id = 427821, type = "aura", unit = "target", pandemicTime = 4.2 }, -- [Hero] 地獄召喚者：枯萎術 (Pandemic 4.2s)
            { id = 319697, type = "spellCooldown", grayOnMove = true } -- 災難狂歡 (移動讀條置灰)
        },
        [2] = { -- Demonology
            { id = 265187, type = "spellCooldown" }, -- 召喚惡魔暴君
            { id = 264173, type = "aura", unit = "player", maxStacksAlert = 4 }, -- 惡魔核心 (4層高亮)
            { id = 427815, type = "aura", unit = "player" }, -- [Hero] 靈魂收割者：共同命運
            { id = 427831, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 喚魔者：惡魔儀式
            { id = 686, type = "spellCooldown", grayOnMove = true }, -- 暗影箭 (移動讀條置灰)
            { id = 105174, type = "spellCooldown", grayOnMove = true } -- 古爾丹之手
        },
        [3] = { -- Destruction
            { id = 1122, type = "spellCooldown" }, -- 召喚地獄火
            { id = 117828, type = "aura", unit = "player", pandemicTime = 1.5 }, -- 爆燃
            { id = 427821, type = "aura", unit = "target", pandemicTime = 4.2 }, -- [Hero] 地獄召喚者：枯萎術 (Pandemic 4.2s)
            { id = 427831, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 喚魔者：惡魔儀式
            { id = 29722, type = "spellCooldown", grayOnMove = true }, -- 燒盡 (移動讀條置灰)
            { id = 116858, type = "spellCooldown", grayOnMove = true } -- 混難之箭
        },
        general = {
            { id = 104773, type = "spellCooldown" }, -- 不滅決心
            { id = 20707, type = "spellCooldown" } -- 靈魂石
        }
    },
    DEMONHUNTER = {
        specs = {
            [1] = "災虐 (Havoc)",
            [2] = "復仇 (Vengeance)"
        },
        [1] = { -- Havoc
            { id = 191427, type = "spellCooldown" }, -- 惡魔變形
            { id = 206476, type = "aura", unit = "player", pandemicTime = 1.5 }, -- 勢不可擋 (Pandemic 1.5s)
            { id = 425815, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 奧達奇掠奪者：戰技
            { id = 425821, type = "aura", unit = "player" } -- [Hero] 魔痕化身：魔痕
        },
        [2] = { -- Vengeance
            { id = 187827, type = "spellCooldown" }, -- 惡魔變形 (坦克)
            { id = 203720, type = "aura", unit = "player", pandemicTime = 1.8 }, -- 惡魔尖刺 (Pandemic 1.8s)
            { id = 247456, type = "aura", unit = "target", minStacksAlert = 5 }, -- 脆弱 (高於5層發光)
            { id = 425815, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 奧達奇掠奪者：戰技
            { id = 425821, type = "aura", unit = "player" } -- [Hero] 魔痕化身：魔痕
        },
        general = {
            { id = 198589, type = "spellCooldown" }, -- 疾影
            { id = 196718, type = "spellCooldown" } -- 黑暗
        }
    },
    EVOKER = {
        specs = {
            [1] = "破滅 (Devastation)",
            [2] = "恩補 (Preservation)",
            [3] = "增補 (Augmentation)"
        },
        [1] = { -- Devastation
            { id = 375087, type = "spellCooldown" }, -- 龍怒
            { id = 357208, type = "aura", unit = "target", pandemicTime = 4.8 }, -- 火焰之息
            { id = 426815, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 鱗長：群體裂解
            { id = 426821, type = "aura", unit = "player" }, -- [Hero] 時空守衛：時空加速
            { id = 356995, type = "spellCooldown", grayOnMove = true, moveBuffs = { 358267 } }, -- 裂解 (移動且無懸空時置灰)
            { id = 361461, type = "spellCooldown", grayOnMove = true, moveBuffs = { 358267 } } -- 活化烈焰
        },
        [2] = { -- Preservation
            { id = 370960, type = "spellCooldown" }, -- 翡翠交融
            { id = 366155, type = "aura", unit = "player", pandemicTime = 3.6 }, -- 黃金沙漏 (Reversion)
            { id = 363534, type = "spellCooldown" }, -- 回響
            { id = 426821, type = "aura", unit = "player" }, -- [Hero] 時空守衛：時空加速
            { id = 426831, type = "aura", unit = "player", glowOnApply = true } -- [Hero] 烈焰塑形者：吞噬
        },
        [3] = { -- Augmentation
            { id = 395152, type = "aura", unit = "player", pandemicTime = 1.5 }, -- 黑曜力量 (Pandemic 1.5s 刷新)
            { id = 403631, type = "spellCooldown" }, -- 烈焰吐息護體
            { id = 426815, type = "aura", unit = "player", glowOnApply = true }, -- [Hero] 鱗長：群體裂解
            { id = 426831, type = "aura", unit = "player", glowOnApply = true } -- [Hero] 烈焰塑形者：吞噬
        },
        general = {
            { id = 363916, type = "spellCooldown" }, -- 黑曜鱗片
            { id = 357170, type = "spellCooldown" } -- 營救
        }
    }
}
