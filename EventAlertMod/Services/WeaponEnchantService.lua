--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/WeaponEnchantService
檔案: Services\WeaponEnchantService.lua

理念:
- 將武器暫時性附魔 (磨刀石/巫術之油/薩滿火舌風怒/盜賊毒藥/DK符文熔鑄/影之哀傷等) 作為獨立告警模組提供全面監控。
- 為什麼不是常規光環？底層是裝備槽位（Slot 16 主手、17 副手、18 遠程）之物品臨時附魔 (Item Temporary Enchantment)，
  無 AuraInstanceID，在 C_UnitAuras 查不到。
- 雙軌原生 API：優先查詢 C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)（Retail 12.1.x & Forever 1.60.1 原生契約），
  搭配 Forever 專屬 C_Item.GetWeaponEnchantInfo(slot - 16) 補充附魔圖示與類型，並保留舊式 GetWeaponEnchantInfo() 降級相容層。
- 專用事件：WEAPON_ENCHANT_CHANGED, WEAPON_SLOT_CHANGED, PLAYER_EQUIPMENT_CHANGED, UNIT_INVENTORY_CHANGED, PLAYER_ENTERING_WORLD。

責任:
- 主手 (16)、副手 (17) 與遠程 (18) 臨時附魔之狀態取樣（剩餘時間、到期旗標、剩餘次數、裝備與附魔圖示）。
- 【缺少武器附魔提醒 (Missing Enchant Warning)】：裝備武器但未施加臨時附魔時發出告警（可獨立切換顯示與高亮）。
- 【作用中／即將到期提醒 (Active / Expiring Highlight)】：支援作用中高亮開關、剩餘時間低於閾值或次數耗盡提醒。
- 【角落附魔小圖示 (Corner Enchant Sub-Icon Badge)】：主圖示顯示武器裝備圖示，角落疊加臨時附魔本身小圖示（支援四角位置與縮放比例）。
- 獨立設定面板 (`EAM.UI.WeaponEnchantPanel`)、高精度倒數分離排程 (`tickCountdown`) 與自由拖曳定位 (`/eam enchant`)。
]]

local _, EAM = ...

EAM.Services = EAM.Services or {}
EAM.UI = EAM.UI or {}

local api = EAM.API or {}
local Util = EAM.Util or {}
local Constants = EAM.Constants or {}

local function getTheme()
    return EAM.Theme
end

local function getLocale()
    return EAM.Locale
end

local mathFloor = math.floor
local mathMax = math.max

local DEFAULT_WEAPON_ICON = 136518
local DEFAULT_ENCHANT_BADGE_ICON = 136244 -- Interface\Icons\Trade_Engraving
local ENCHANT_SLOTS = { 16, 17, 18 }

local WeaponEnchantService = {
    states = {},
    frames = {},
    parentFrame = nil,
    tickerFrame = nil,
    isMoving = false,
    initialized = false,
    lastSoundAlertTime = { [16] = 0, [17] = 0, [18] = 0 },
    enabled = true,
    lastSampleTime = 0,
    sampleThrottle = 0.2,
}

EAM.Services.WeaponEnchantService = WeaponEnchantService

-- 常見臨時武器附魔 EnchantID -> FileDataID 靜態對照表（涵蓋經典/Forever 與正式服常見項目）
local ENCHANT_ID_ICON_MAP = {
    -- 風怒武器 / 風怒圖騰 (Windfury): 136018
    [283] = 136018, [284] = 136018, [525] = 136018, [1669] = 136018, [2636] = 136018,
    [3780] = 136018, [5401] = 136018,
    [563] = 136018, [564] = 136018, [1783] = 136018, [2638] = 136018, [2639] = 136018, [3014] = 136018,
    -- 火舌武器 / 火舌圖騰 (Flametongue): 135814
    [3] = 135814, [4] = 135814, [5] = 135814, [523] = 135814, [1665] = 135814,
    [1666] = 135814, [2634] = 135814, [3779] = 135814, [5400] = 135814,
    [124] = 135814, [285] = 135814, [543] = 135814, [1683] = 135814, [2637] = 135814,
    -- 冰封武器 (Frostbrand): 135847
    [2] = 135847, [12] = 135847, [524] = 135847, [1667] = 135847, [1668] = 135847,
    [2635] = 135847, [3782] = 135847, [5402] = 135847,
    -- 石化武器 (Rockbiter): 136086
    [1] = 136086, [6] = 136086, [29] = 136086, [503] = 136086, [504] = 136086,
    [683] = 136086, [1663] = 136086, [1664] = 136086, [2632] = 136086, [2633] = 136086,
    -- 大地生命武器 (Earthliving): 136027
    [3345] = 136027, [3346] = 136027, [3347] = 136027, [3348] = 136027, [3349] = 136027,
    [3350] = 136027, [6498] = 136027,
    -- 速效毒藥 (Instant Poison): 132273
    [42] = 132273, [323] = 132273, [324] = 132273, [325] = 132273, [623] = 132273,
    [624] = 132273, [625] = 132273, [2641] = 132273, [3768] = 132273, [3769] = 132273,
    [8679] = 132273, [315584] = 132273,
    -- 致命毒藥 (Deadly Poison): 132290
    [7] = 132290, [8] = 132290, [626] = 132290, [627] = 132290, [2630] = 132290,
    [2642] = 132290, [2643] = 132290, [3770] = 132290, [3771] = 132290, [2823] = 132290,
    -- 致傷毒藥 (Wound Poison): 134197
    [703] = 134197, [704] = 134197, [705] = 134197, [706] = 134197, [2644] = 134197,
    [3772] = 134197, [3773] = 134197, [8680] = 134197,
    -- 致殘毒藥 (Crippling Poison): 132274
    [22] = 132274, [603] = 132274, [3409] = 132274,
    -- 麻痺毒藥 (Mind-numbing / Numbing Poison): 136066
    [23] = 136066, [35] = 136066, [643] = 136066, [5761] = 136066,
    -- 其他毒藥 (Misc / Atrophic / Amplifying): 136093
    [9] = 136093, [10] = 136093, [11] = 136093, [1003] = 136093, [2640] = 136093,
    [3102] = 136093, [381637] = 136093, [381664] = 136093,
    -- 磨刀石 (Sharpening Stones & Whetstones): 135252
    [13] = 135252, [14] = 135252, [39] = 135252, [40] = 135252, [483] = 135252,
    [1643] = 135252, [2506] = 135252, [2684] = 135252, [2712] = 135252, [2713] = 135252,
    [6188] = 135252, [6190] = 135252, [6379] = 135252, [6380] = 135252, [6696] = 135252,
    [6697] = 135252, [6698] = 135252, [7543] = 135252, [7544] = 135252, [7545] = 135252,
    -- 平衡石與配重 (Weightstones & Counterweights): 135259
    [19] = 135259, [20] = 135259, [21] = 135259, [34] = 135259, [484] = 135259,
    [1703] = 135259, [2954] = 135259, [2955] = 135259, [6191] = 135259, [6192] = 135259,
    [6381] = 135259, [6382] = 135259, [6699] = 135259, [6700] = 135259, [6701] = 135259,
    [7546] = 135259, [7547] = 135259, [7548] = 135259,
    -- 巫術之油與正式服武器之油 (Wizard Oils & Retail Oils): 134723
    [2623] = 134723, [2626] = 134723, [2627] = 134723, [2628] = 134723, [2678] = 134723,
    [7529] = 134723, [7530] = 134723, [7531] = 134723, [7532] = 134723, [7533] = 134723,
    [7534] = 134723, [7549] = 134723, [7550] = 134723, [7551] = 134723,
    -- 法力之油 (Mana Oils): 134719
    [2624] = 134719, [2625] = 134719, [2629] = 134719, [2676] = 134719, [2677] = 134719,
    -- 暗影之油 (Shadow Oil): 134803 / 冰霜之油 (Frost Oil): 134799
    [25] = 134803,
    [26] = 134799,
    -- 火焰石 (Firestones): 134085
    [1803] = 134085, [1823] = 134085, [1824] = 134085, [1825] = 134085, [2645] = 134085,
    -- 魚餌 (Fishing Lures): 134327
    [263] = 134327, [264] = 134327, [265] = 134327, [266] = 134327,
}
for id = 3018, 3044 do
    ENCHANT_ID_ICON_MAP[id] = 136086
end

WeaponEnchantService.ENCHANT_ID_ICON_MAP = ENCHANT_ID_ICON_MAP

-- 常見臨時附魔 EnchantID -> 法術 ID 對照表（供副 Tooltip 顯示完整法術/附魔說明）
local ENCHANT_ID_SPELL_MAP = {
    -- 風怒武器 / 風怒圖騰
    [283] = 8232, [284] = 8235, [525] = 10486, [1669] = 16362, [2636] = 25505,
    [3780] = 58804, [5401] = 33757,
    [563] = 8512, [564] = 10613, [1783] = 10614, [2638] = 25587, [2639] = 25585, [3014] = 8512,
    -- 火舌武器 / 火舌圖騰
    [5] = 8024, [4] = 8027, [3] = 8030, [523] = 16339, [1665] = 16341,
    [1666] = 16342, [2634] = 25489, [3779] = 58790, [5400] = 318038,
    [124] = 8227, [285] = 8249, [543] = 10526, [1683] = 16387, [2637] = 25557,
    -- 冰封武器
    [2] = 8033, [12] = 8038, [524] = 10456, [1667] = 16355, [1668] = 16356,
    [2635] = 25500, [3782] = 58796, [5402] = 196834,
    -- 石化武器
    [29] = 8017, [6] = 8018, [1] = 8019, [503] = 10399, [1663] = 16314,
    [683] = 16315, [1664] = 16316, [504] = 10399, [2632] = 25485, [2633] = 25485,
    -- 大地生命武器
    [3345] = 51730, [3346] = 51990, [3347] = 51997, [3348] = 51998, [3349] = 51999,
    [3350] = 52000, [6498] = 382021,
    -- 盜賊毒藥
    [42] = 8679, [323] = 8686, [324] = 8688, [325] = 11338, [623] = 11339,
    [624] = 11340, [625] = 26891, [2641] = 315584, [3768] = 57968, [3769] = 315584,
    [8679] = 8679, [315584] = 315584,
    [7] = 2823, [8] = 2824, [626] = 11355, [627] = 11356, [2630] = 25351,
    [2642] = 27186, [2643] = 2823, [3770] = 57973, [3771] = 2823, [2823] = 2823,
    [703] = 13219, [704] = 13225, [705] = 13226, [706] = 13227, [2644] = 27188,
    [3772] = 57978, [3773] = 8680, [8680] = 8680,
    [22] = 3408, [603] = 11202, [3409] = 3408,
    [23] = 5761, [35] = 8693, [643] = 11399, [5761] = 5761,
    [381637] = 381637, [381664] = 381664,
    -- DK 符文熔鑄
    [3368] = 53344, [3370] = 53343, [3847] = 62158, [6241] = 326805,
    [6242] = 326855, [6244] = 326977, [6245] = 327082, [3369] = 53331,
}
for id = 3018, 3044 do
    ENCHANT_ID_SPELL_MAP[id] = 8017
end

local ENCHANT_ICON_FALLBACK_SPELL = {
    [136018] = { 33757, 8232 }, -- 風怒
    [135814] = { 318038, 8024 }, -- 火舌
    [135847] = { 196834, 8033 }, -- 冰封
    [136086] = { 8017 }, -- 石化
    [136027] = { 382021, 51730 }, -- 大地生命
    [132273] = { 315584, 8679 }, -- 速效毒藥
    [132290] = { 2823 }, -- 致命毒藥
    [134197] = { 8680, 13219 }, -- 致傷毒藥
    [132274] = { 3408 }, -- 致殘毒藥
    [136066] = { 5761 }, -- 麻痺毒藥
}

WeaponEnchantService.ENCHANT_ID_SPELL_MAP = ENCHANT_ID_SPELL_MAP

-- 預分配表格避免熱路徑產生 GC 垃圾
local slotsToShowBuffer = {}
local activeSlotsBuffer = {}

local function inCombat()
    return api.InCombatLockdown and api.InCombatLockdown()
end

local function isSafeNumber(val)
    if val == nil then return false end
    if Util and Util.isSecretValue and Util.isSecretValue(val) then return false end
    if issecretvalue and issecretvalue(val) then return false end
    if Util and Util.isSafeNumber then return Util.isSafeNumber(val) end
    if type(val) ~= "number" then return false end
    return val == val and val ~= math.huge and val ~= -math.huge
end

local function localized(key, fallback)
    return (EAM.L and EAM.L[key]) or fallback or key
end

local function getCurrentTime()
    return (api.GetTime and api.GetTime()) or (_G.GetTime and _G.GetTime()) or 0
end

function WeaponEnchantService.resolveEnchantSpellID(enchantID, iconHint)
    if isSafeNumber(enchantID) and ENCHANT_ID_SPELL_MAP[enchantID] then
        return ENCHANT_ID_SPELL_MAP[enchantID]
    end
    local iconKey = isSafeNumber(iconHint) and iconHint
        or (isSafeNumber(enchantID) and ENCHANT_ID_ICON_MAP[enchantID])
        or nil
    local candidates = iconKey and ENCHANT_ICON_FALLBACK_SPELL[iconKey] or nil
    if candidates then
        local cSpell = api.C_Spell or _G.C_Spell
        for _, spellID in ipairs(candidates) do
            if not cSpell or type(cSpell.DoesSpellExist) ~= "function" then
                return spellID
            end
            local ok, exists = pcall(cSpell.DoesSpellExist, spellID)
            if ok and exists then
                return spellID
            end
        end
        return candidates[1]
    end
    return nil
end

function WeaponEnchantService.resolveEnchantIcon(slot, enchantID, nativeIconID)
    if isSafeNumber(nativeIconID) and nativeIconID > 0 then
        return nativeIconID
    end
    if type(nativeIconID) == "string" and nativeIconID ~= "" then
        return nativeIconID
    end
    if isSafeNumber(enchantID) and ENCHANT_ID_ICON_MAP[enchantID] then
        return ENCHANT_ID_ICON_MAP[enchantID]
    end
    if isSafeNumber(enchantID) and enchantID > 0 then
        local cSpell = api.C_Spell or _G.C_Spell
        if cSpell and type(cSpell.GetSpellTexture) == "function" then
            local ok, tex = pcall(cSpell.GetSpellTexture, enchantID)
            if ok and tex and ((isSafeNumber(tex) and tex > 0) or (type(tex) == "string" and tex ~= "")) then
                return tex
            end
        end
    end
    return DEFAULT_ENCHANT_BADGE_ICON
end

function WeaponEnchantService.getConfig()
    local db = EAM.db
    if not db then return {} end
    if not db.weaponEnchant or type(db.weaponEnchant) ~= "table" then
        db.weaponEnchant = {}
    end
    local cfg = db.weaponEnchant
    local layoutFrame = db.layout and db.layout.frames and db.layout.frames.weaponEnchant

    if cfg.enabled == nil then cfg.enabled = true end
    if cfg.showMainHand == nil then cfg.showMainHand = true end
    if cfg.showOffHand == nil then cfg.showOffHand = true end
    if cfg.showRanged == nil then cfg.showRanged = false end
    if cfg.showActive == nil then cfg.showActive = true end
    if cfg.glowActive == nil then cfg.glowActive = false end
    if cfg.warnMissing == nil then cfg.warnMissing = true end
    if cfg.warnExpiring == nil then cfg.warnExpiring = true end
    if not isSafeNumber(cfg.expireThreshold) or cfg.expireThreshold <= 0 then cfg.expireThreshold = 300 end
    if cfg.glowMissing == nil then cfg.glowMissing = true end
    if cfg.glowExpiring == nil then cfg.glowExpiring = true end
    if cfg.showEnchantBadge == nil then cfg.showEnchantBadge = true end
    if cfg.badgeOutside == nil then cfg.badgeOutside = true end
    if cfg.badgePosition ~= "TOPLEFT" and cfg.badgePosition ~= "TOPRIGHT" and cfg.badgePosition ~= "BOTTOMLEFT" and cfg.badgePosition ~= "BOTTOMRIGHT" then
        cfg.badgePosition = "TOPLEFT"
    end
    if not isSafeNumber(cfg.badgeScale) or cfg.badgeScale <= 0 then cfg.badgeScale = 0.45 end
    if cfg.playSound == nil then cfg.playSound = false end
    if type(cfg.soundName) ~= "string" or cfg.soundName == "" then cfg.soundName = "ShayBell" end
    if not isSafeNumber(cfg.iconSize) or cfg.iconSize <= 0 then cfg.iconSize = 40 end
    if not isSafeNumber(cfg.growDirection) or cfg.growDirection < 1 or cfg.growDirection > 4 then
        cfg.growDirection = (layoutFrame and layoutFrame.growDirection) or 1
    end
    if not isSafeNumber(cfg.spacing) or cfg.spacing < 0 then
        cfg.spacing = (db.layout and isSafeNumber(db.layout.spacing) and db.layout.spacing) or 6
    end
    if not isSafeNumber(cfg.x) then
        cfg.x = (layoutFrame and isSafeNumber(layoutFrame.x) and layoutFrame.x) or 120
    end
    if not isSafeNumber(cfg.y) then
        cfg.y = (layoutFrame and isSafeNumber(layoutFrame.y) and layoutFrame.y) or -120
    end
    if type(cfg.point) ~= "string" or cfg.point == "" then
        cfg.point = (layoutFrame and layoutFrame.point) or "CENTER"
    end
    return cfg
end

local function syncPositionToLayout(cfg)
    local db = EAM.db
    if db and db.layout and db.layout.frames and cfg then
        db.layout.frames.weaponEnchant = db.layout.frames.weaponEnchant or {}
        local lf = db.layout.frames.weaponEnchant
        lf.point = cfg.point or lf.point or "CENTER"
        lf.attachPoint = lf.attachPoint or lf.point or "CENTER"
        lf.x = isSafeNumber(cfg.x) and cfg.x or 120
        lf.y = isSafeNumber(cfg.y) and cfg.y or -120
        lf.growDirection = cfg.growDirection or 1
    end
end

local function isServiceEnabled()
    if not WeaponEnchantService.enabled then
        return false
    end
    local mc = EAM.Modules and EAM.Modules.ModuleController
    if mc and type(mc.isEnabled) == "function" then
        if not mc.isEnabled("weaponEnchant") then
            return false
        end
    end
    local cfg = WeaponEnchantService.getConfig()
    if cfg and cfg.enabled == false then
        return false
    end
    local config = EAM.db and EAM.db.config
    if config and config.enableWeaponEnchant == false then
        return false
    end
    return true
end

local function getSlotDisplayName(slot)
    if slot == 16 then
        return localized("EAM_WEAPON_ENCHANT_MH", "主手武器附魔")
    elseif slot == 17 then
        return localized("EAM_WEAPON_ENCHANT_OH", "副手武器附魔")
    end
    return localized("EAM_WEAPON_ENCHANT_RANGED", "遠程武器附魔")
end

local function getSlotShortLabel(slot)
    if slot == 16 then
        return localized("EAM_WEAPON_ENCHANT_MH", "主手")
    elseif slot == 17 then
        return localized("EAM_WEAPON_ENCHANT_OH", "副手")
    end
    return localized("EAM_WEAPON_ENCHANT_RANGED", "遠程")
end

-- 取得指定槽位狀態物件
local function getOrCreateSlotState(slot)
    local state = WeaponEnchantService.states[slot]
    if not state then
        state = {
            slot = slot,
            hasItem = false,
            hasEnchant = false,
            hasExpiration = false,
            expiration = 0,
            charges = nil,
            enchantID = nil,
            enchantIcon = nil,
            durationSec = 0,
            icon = nil,
            name = nil,
            isMissing = false,
            isExpiring = false,
            active = false,
            shown = false,
            kind = Constants.ALERT_KIND_WEAPON_ENCHANT or "weaponEnchant",
        }
        WeaponEnchantService.states[slot] = state
    end
    return state
end

-- 格式化剩餘時間 (高精度四捨五入至整秒，進行中 <0.5s 顯示 1s 不誤顯 0s)
function WeaponEnchantService.formatDuration(seconds)
    if not isSafeNumber(seconds) or seconds <= 0 then
        return ""
    end
    local secInt = mathMax(1, mathFloor(seconds + 0.5))
    if secInt >= 3600 then
        local hours = mathFloor(secInt / 3600)
        local mins = mathFloor((secInt % 3600) / 60)
        return string.format("%dh%dm", hours, mins)
    elseif secInt >= 60 then
        local mins = mathFloor(secInt / 60)
        local secs = secInt % 60
        return string.format("%d:%02d", mins, secs)
    else
        return string.format("%ds", secInt)
    end
end

-- 從裝備 API 偵測是否已裝備武器
local function checkSlotHasItem(slot, getItemID, getItemTex)
    if type(getItemID) == "function" then
        local okID, itemID = pcall(getItemID, "player", slot)
        if okID and itemID then
            return true
        end
    end
    if type(getItemTex) == "function" then
        local okTex, tex = pcall(getItemTex, "player", slot)
        if okTex and tex then
            return true
        end
    end
    return false
end

local function resolveSlotTexture(slot, getItemTex)
    if type(getItemTex) == "function" then
        local okTex, tex = pcall(getItemTex, "player", slot)
        if okTex and tex then
            return tex
        end
    end
    return DEFAULT_WEAPON_ICON
end

-- 查詢單一槽位附魔資料：回傳 ok, enchantTableOrNil
local function querySlotEnchantData(slot, cPaperDoll, cItem, legacyTuple)
    local hasTempAPI = cPaperDoll and type(cPaperDoll.GetTemporaryEnchantmentInfo) == "function"
    local hasItemAPI = cItem and type(cItem.GetWeaponEnchantInfo) == "function"

    local tempOk, tempInfo = false, nil
    if hasTempAPI then
        tempOk, tempInfo = pcall(cPaperDoll.GetTemporaryEnchantmentInfo, slot)
        if not tempOk then
            return false, nil
        end
    end

    local nativeIconID = nil
    local itemBest = nil
    if hasItemAPI then
        local weaponSlot = slot - 16
        local itemOk, enchants = pcall(cItem.GetWeaponEnchantInfo, weaponSlot)
        if itemOk and type(enchants) == "table" then
            for _, entry in ipairs(enchants) do
                if type(entry) == "table" and entry.hasEnchant == true then
                    -- ItemEnchantType: 0=None, 1=Permanent, 2=Temporary, 3=Imbue
                    local eType = entry.enchantType
                    if eType ~= 1 then
                        if not itemBest or eType == 3 then
                            itemBest = entry
                        end
                    end
                end
            end
            if itemBest and itemBest.enchantIconID then
                nativeIconID = itemBest.enchantIconID
            end
        elseif not itemOk and not hasTempAPI then
            return false, nil
        end
    end

    if hasTempAPI then
        if type(tempInfo) == "table" then
            return true, {
                enchantID = tempInfo.enchantID or (itemBest and itemBest.enchantID),
                remainingTimeMs = tempInfo.remainingTimeMs,
                chargesRemaining = tempInfo.chargesRemaining,
                hasExpirationTime = tempInfo.hasExpirationTime,
                nativeIconID = nativeIconID,
            }
        end
        if itemBest then
            local remMs = isSafeNumber(itemBest.timeLeft) and (itemBest.timeLeft * 1000) or 0
            return true, {
                enchantID = itemBest.enchantID,
                remainingTimeMs = remMs,
                chargesRemaining = itemBest.charges,
                hasExpirationTime = remMs > 0,
                nativeIconID = nativeIconID,
            }
        end
        return true, nil
    end

    if hasItemAPI then
        if itemBest then
            local remMs = isSafeNumber(itemBest.timeLeft) and (itemBest.timeLeft * 1000) or 0
            return true, {
                enchantID = itemBest.enchantID,
                remainingTimeMs = remMs,
                chargesRemaining = itemBest.charges,
                hasExpirationTime = remMs > 0,
                nativeIconID = nativeIconID,
            }
        end
        return true, nil
    end

    if legacyTuple then
        local baseIdx = (slot == 16 and 1) or (slot == 17 and 5) or 9
        local hasFlag = legacyTuple[baseIdx]
        local expMs = legacyTuple[baseIdx + 1]
        local charges = legacyTuple[baseIdx + 2]
        local enchantID = legacyTuple[baseIdx + 3]
        if hasFlag == true or (hasFlag and isSafeNumber(expMs) and expMs > 0) then
            local hasExp = isSafeNumber(expMs) and expMs > 0
            return true, {
                enchantID = enchantID,
                remainingTimeMs = expMs,
                chargesRemaining = charges,
                hasExpirationTime = hasExp,
                nativeIconID = nil,
            }
        end
        return true, nil
    end

    return false, nil
end

-- 採樣與狀態推導 (核心業務狀態機)
function WeaponEnchantService.sampleWeaponEnchants()
    local cPaperDoll = api.C_PaperDollInfo or _G.C_PaperDollInfo
    local cItem = api.C_Item or _G.C_Item
    local hasTempAPI = cPaperDoll and type(cPaperDoll.GetTemporaryEnchantmentInfo) == "function"
    local hasItemAPI = cItem and type(cItem.GetWeaponEnchantInfo) == "function"
    local legacyGetEnchant = api.GetWeaponEnchantInfo or _G.GetWeaponEnchantInfo
    local hasLegacyAPI = type(legacyGetEnchant) == "function"

    if not hasTempAPI and not hasItemAPI and not hasLegacyAPI then
        return WeaponEnchantService.states
    end

    local legacyTuple = nil
    if not hasTempAPI and not hasItemAPI and hasLegacyAPI then
        local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 = pcall(legacyGetEnchant)
        if not ok then
            return WeaponEnchantService.states
        end
        legacyTuple = { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12 }
    end

    local cfg = WeaponEnchantService.getConfig()
    local expireThreshold = (cfg and isSafeNumber(cfg.expireThreshold) and cfg.expireThreshold > 0) and cfg.expireThreshold or 300
    local warnMissing = (cfg and cfg.warnMissing ~= false)
    local warnExpiring = (cfg and cfg.warnExpiring ~= false)
    local now = getCurrentTime()
    WeaponEnchantService.lastSampleTime = now

    local getItemTex = api.GetInventoryItemTexture or _G.GetInventoryItemTexture
    local getItemID = api.GetInventoryItemID or _G.GetInventoryItemID

    local queryFailed = false
    for _, slot in ipairs(ENCHANT_SLOTS) do
        local queryOk, info = querySlotEnchantData(slot, cPaperDoll, cItem, legacyTuple)
        if not queryOk then
            queryFailed = true
        else
            local state = getOrCreateSlotState(slot)
            local hasItem = checkSlotHasItem(slot, getItemID, getItemTex)
            state.hasItem = hasItem
            state.icon = resolveSlotTexture(slot, getItemTex)
            state.name = getSlotDisplayName(slot)

            if info ~= nil then
                local rawHasExp = info.hasExpirationTime
                local remMs = info.remainingTimeMs
                local hasExp
                if rawHasExp ~= nil then
                    hasExp = (rawHasExp == true)
                else
                    hasExp = isSafeNumber(remMs) and remMs > 0
                end

                state.hasEnchant = true
                state.hasExpiration = hasExp
                state.charges = isSafeNumber(info.chargesRemaining) and info.chargesRemaining or nil
                state.enchantID = isSafeNumber(info.enchantID) and info.enchantID or info.enchantID
                state.enchantIcon = WeaponEnchantService.resolveEnchantIcon(slot, state.enchantID, info.nativeIconID)
                state.isMissing = false

                if hasExp and isSafeNumber(remMs) and remMs > 0 then
                    state.durationSec = remMs / 1000
                    state.expiration = now + state.durationSec
                else
                    state.durationSec = 0
                    state.expiration = 0
                end

                state.isExpiring = warnExpiring and (
                    (state.hasExpiration and state.durationSec > 0 and state.durationSec <= expireThreshold)
                    or (state.charges and state.charges == 1)
                ) or false
                state.active = true
            else
                state.hasEnchant = false
                state.hasExpiration = false
                state.durationSec = 0
                state.expiration = 0
                state.charges = nil
                state.enchantID = nil
                state.enchantIcon = nil
                state.isMissing = hasItem and warnMissing
                state.isExpiring = false
                state.active = state.isMissing
            end
        end
    end

    if queryFailed and not WeaponEnchantService.states[16] and not WeaponEnchantService.states[17] then
        return WeaponEnchantService.states
    end

    -- 音效提醒節流調用
    if cfg and cfg.playSound == true then
        for _, slot in ipairs(ENCHANT_SLOTS) do
            local s = WeaponEnchantService.states[slot]
            local slotWanted = (slot == 16 and cfg.showMainHand ~= false)
                or (slot == 17 and cfg.showOffHand ~= false)
                or (slot == 18 and cfg.showRanged == true)
            if slotWanted and s and (s.isMissing or s.isExpiring) and (now - (WeaponEnchantService.lastSoundAlertTime[slot] or 0)) > 30.0 then
                WeaponEnchantService.lastSoundAlertTime[slot] = now
                local ms = EAM.Services and EAM.Services.MediaService
                if ms and type(ms.playSound) == "function" then
                    ms.playSound(cfg.soundName or "ShayBell")
                elseif _G.PlaySoundFile then
                    pcall(_G.PlaySoundFile, "Sound\\Interface\\RaidWarning.ogg", "Master")
                end
            end
        end
    end

    -- 廣播狀態事件至 EventRouter
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router and type(router.fire) == "function" then
        for _, slot in ipairs(ENCHANT_SLOTS) do
            local s = WeaponEnchantService.states[slot]
            if s then
                router.fire("EAM_WEAPON_ENCHANT_STATE_CHANGED", s, slot)
            end
        end
    end

    return WeaponEnchantService.states
end

local function isSafeString(val)
    if type(val) ~= "string" or val == "" then return false end
    if Util and Util.isSecretValue and Util.isSecretValue(val) then return false end
    if issecretvalue and issecretvalue(val) then return false end
    return true
end

local function extractWeaponTooltipEnchantLine(tooltip, slot)
    if not tooltip or not tooltip.GetName then return nil end
    local okName, tipName = pcall(tooltip.GetName, tooltip)
    if not okName or type(tipName) ~= "string" or tipName == "" then return nil end
    local okNum, rawNum = tooltip.NumLines and pcall(tooltip.NumLines, tooltip)
    local numLines = (okNum and isSafeNumber(rawNum)) and rawNum or 0
    if type(numLines) ~= "number" or numLines <= 0 then return nil end
    for i = 2, numLines do
        local leftObj = _G[tipName .. "TextLeft" .. i]
        if leftObj and leftObj.GetText then
            local okTxt, txt = pcall(leftObj.GetText, leftObj)
            if okTxt and isSafeString(txt) and leftObj.GetTextColor then
                local okCol, r, g, b = pcall(leftObj.GetTextColor, leftObj)
                if okCol and isSafeNumber(r) and isSafeNumber(g) and isSafeNumber(b) then
                    -- 暴雪裝備臨時附魔文字通常為亮綠色 (0, 1, 0) 且多半帶括號時間或次數
                    if g > 0.85 and r < 0.25 and b < 0.25 then
                        if txt:find("%(") or txt:find("（") then
                            return txt
                        end
                    end
                end
            end
        end
    end
    return nil
end

function WeaponEnchantService.getOrCreateSubTooltip()
    if WeaponEnchantService.subTooltip then
        return WeaponEnchantService.subTooltip
    end
    local uiParent = _G.UIParent
    if not uiParent or type(api.CreateFrame) ~= "function" then
        return nil
    end
    local ok, sub = pcall(api.CreateFrame, "GameTooltip", "EAM_WeaponEnchantSubTooltip", uiParent, "GameTooltipTemplate")
    if not ok or not sub then
        ok, sub = pcall(api.CreateFrame, "GameTooltip", "EAM_WeaponEnchantSubTooltip", uiParent)
    end
    if not ok or not sub then
        return nil
    end
    if sub.SetFrameStrata then
        pcall(sub.SetFrameStrata, sub, "TOOLTIP")
    end
    if sub.Hide then
        pcall(sub.Hide, sub)
    end
    WeaponEnchantService.subTooltip = sub

    if not WeaponEnchantService._hookedGameTooltipHide and _G.GameTooltip and type(_G.GameTooltip.HookScript) == "function" then
        WeaponEnchantService._hookedGameTooltipHide = true
        pcall(_G.GameTooltip.HookScript, _G.GameTooltip, "OnHide", function()
            if WeaponEnchantService.subTooltip and WeaponEnchantService.subTooltip.Hide then
                pcall(WeaponEnchantService.subTooltip.Hide, WeaponEnchantService.subTooltip)
            end
        end)
    end
    return sub
end

function WeaponEnchantService.hideSubTooltip()
    if WeaponEnchantService.subTooltip and WeaponEnchantService.subTooltip.Hide then
        pcall(WeaponEnchantService.subTooltip.Hide, WeaponEnchantService.subTooltip)
    end
end

function WeaponEnchantService.hideEnchantTooltip()
    WeaponEnchantService.hideSubTooltip()
    if _G.GameTooltip and _G.GameTooltip.Hide then
        pcall(_G.GameTooltip.Hide, _G.GameTooltip)
    end
end

-- 取得特定槽位 Tooltip 資訊
function WeaponEnchantService.getEnchantTooltipInfo(slot)
    local state = WeaponEnchantService.states[slot]
    if not state then return nil end

    local title = getSlotDisplayName(slot)
    local now = getCurrentTime()
    local lines = {}
    local weaponLink = nil
    local enchantName = nil
    local enchantDescription = nil
    local spellID = nil

    if state.hasItem then
        local getLink = api.GetInventoryItemLink or _G.GetInventoryItemLink
        if type(getLink) == "function" then
            local okLink, link = pcall(getLink, "player", slot)
            if okLink and isSafeString(link) then
                weaponLink = link
            end
        end
    end

    if state.hasEnchant then
        spellID = WeaponEnchantService.resolveEnchantSpellID(state.enchantID, state.enchantIcon)
        if spellID then
            local cSpell = api.C_Spell or _G.C_Spell
            if cSpell and type(cSpell.GetSpellInfo) == "function" then
                local okInfo, spellInfo = pcall(cSpell.GetSpellInfo, spellID)
                if okInfo and type(spellInfo) == "table" and isSafeString(spellInfo.name) then
                    enchantName = spellInfo.name
                end
            end
            if cSpell and type(cSpell.GetSpellDescription) == "function" then
                local okDesc, desc = pcall(cSpell.GetSpellDescription, spellID)
                if okDesc and isSafeString(desc) then
                    enchantDescription = desc
                end
            end
        end
    end

    if not state.hasItem then
        lines[#lines + 1] = { text = "• 未裝備武器", r = 0.6, g = 0.6, b = 0.6 }
    elseif state.hasEnchant then
        if state.hasExpiration then
            local remaining = state.expiration > 0 and mathMax(0, state.expiration - now) or state.durationSec
            local durStr = WeaponEnchantService.formatDuration(remaining)
            lines[#lines + 1] = { text = string.format("• 附魔剩餘時間: %s", durStr ~= "" and durStr or "即將到期"), r = 0.2, g = 1.0, b = 0.4 }
        else
            lines[#lines + 1] = { text = "• 附魔作用中 (無預定到期時間)", r = 0.2, g = 1.0, b = 0.4 }
        end
        if state.charges and state.charges > 0 then
            lines[#lines + 1] = { text = string.format("• 剩餘次數: %d 次", state.charges), r = 1.0, g = 0.82, b = 0.2 }
        end
        if state.isExpiring then
            lines[#lines + 1] = { text = "• 【警戒】附魔即將到期，請及時補充！", r = 1.0, g = 0.3, b = 0.3 }
        end
    elseif state.isMissing then
        lines[#lines + 1] = { text = "• 【缺少附魔】已裝備武器但尚未施加臨時附魔！", r = 1.0, g = 0.2, b = 0.2 }
        lines[#lines + 1] = { text = "• 支援磨刀石、巫術之油、毒藥、風怒/火舌、符文熔鑄等", r = 0.8, g = 0.8, b = 0.8 }
    end

    return {
        title = title,
        weaponLink = weaponLink,
        enchantName = enchantName,
        enchantDescription = enchantDescription,
        spellID = spellID,
        lines = lines,
    }
end

local function appendTooltipLines(tooltip, lines)
    if not tooltip or not lines then return end
    for _, line in ipairs(lines) do
        if type(line) == "table" then
            tooltip:AddLine(line.text or "", line.r or 1, line.g or 1, line.b or 1, true)
        else
            tooltip:AddLine(tostring(line), 1, 1, 1, true)
        end
    end
end

function WeaponEnchantService.showEnchantTooltip(anchorFrame, slot)
    local info = WeaponEnchantService.getEnchantTooltipInfo(slot)
    local state = WeaponEnchantService.states[slot]
    local tooltip = _G.GameTooltip
    if not info or not tooltip then return end

    if anchorFrame then
        anchorFrame.auraType = "TempEnchant"
        if type(anchorFrame.SetID) == "function" then
            pcall(anchorFrame.SetID, anchorFrame, slot)
        end
    end

    tooltip:SetOwner(anchorFrame, "ANCHOR_RIGHT")
    tooltip:ClearLines()

    local weaponShown = false
    if state and state.hasItem and type(tooltip.SetInventoryItem) == "function" then
        local okItem, hasItem = pcall(tooltip.SetInventoryItem, tooltip, "player", slot)
        if okItem and hasItem then
            weaponShown = true
        end
    end

    if weaponShown then
        if state.hasEnchant then
            local sub = WeaponEnchantService.getOrCreateSubTooltip()
            if sub then
                local shoppingShown = _G.ShoppingTooltip1 and _G.ShoppingTooltip1.IsShown and _G.ShoppingTooltip1:IsShown()
                local sideAnchor = shoppingShown and _G.ShoppingTooltip1 or tooltip

                sub:SetOwner(sideAnchor, "ANCHOR_NONE")
                sub:ClearAllPoints()
                local placeLeft = false
                if sideAnchor.GetRight and _G.UIParent and _G.UIParent.GetRight then
                    local okS, sRight = pcall(sideAnchor.GetRight, sideAnchor)
                    local okU, uRight = pcall(_G.UIParent.GetRight, _G.UIParent)
                    if okS and okU and isSafeNumber(sRight) and isSafeNumber(uRight) and (uRight - sRight) < 260 then
                        placeLeft = true
                    end
                end
                if placeLeft then
                    sub:SetPoint("TOPRIGHT", tooltip, "TOPLEFT", -4, 0)
                else
                    sub:SetPoint("TOPLEFT", sideAnchor, "TOPRIGHT", 4, 0)
                end

                sub:ClearLines()
                local spellShown = false
                if info.spellID and type(sub.SetSpellByID) == "function" then
                    local okSpell = pcall(sub.SetSpellByID, sub, info.spellID)
                    if okSpell and (not sub.NumLines or sub:NumLines() > 0) then
                        spellShown = true
                    end
                end

                if not spellShown then
                    local extractedLine = extractWeaponTooltipEnchantLine(tooltip, slot)
                    sub:AddLine(info.enchantName or extractedLine or info.title or "武器臨時附魔", 0.2, 1.0, 0.4)
                    if info.enchantDescription then
                        sub:AddLine(info.enchantDescription, 1.0, 0.82, 0.0, true)
                    end
                end

                sub:AddLine(" ")
                appendTooltipLines(sub, info.lines)
                sub:Show()
            else
                tooltip:AddLine(" ")
                appendTooltipLines(tooltip, info.lines)
            end
        else
            WeaponEnchantService.hideSubTooltip()
            tooltip:AddLine(" ")
            appendTooltipLines(tooltip, info.lines)
        end
        tooltip:Show()
        return
    end

    WeaponEnchantService.hideSubTooltip()
    tooltip:AddLine(info.title or "武器臨時附魔", 1.0, 0.82, 0.0)
    if info.weaponLink then
        tooltip:AddLine(info.weaponLink, 1, 1, 1, true)
    end
    if info.enchantName then
        tooltip:AddLine(info.enchantName, 0.2, 1.0, 0.4, true)
    end
    if info.enchantDescription then
        tooltip:AddLine(info.enchantDescription, 1.0, 0.82, 0.0, true)
    end
    appendTooltipLines(tooltip, info.lines)
    tooltip:Show()
end

local function applyParentFramePoint(frame, cfg)
    if not frame or inCombat() then return end
    local layoutFrame = EAM.db and EAM.db.layout and EAM.db.layout.frames and EAM.db.layout.frames.weaponEnchant
    local point = (cfg and cfg.point) or (layoutFrame and layoutFrame.point) or "CENTER"
    local attachPoint = (layoutFrame and layoutFrame.attachPoint) or point
    local x = (cfg and isSafeNumber(cfg.x) and cfg.x) or (layoutFrame and isSafeNumber(layoutFrame.x) and layoutFrame.x) or 120
    local y = (cfg and isSafeNumber(cfg.y) and cfg.y) or (layoutFrame and isSafeNumber(layoutFrame.y) and layoutFrame.y) or -120
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, attachPoint, x, y)
end

-- 建立/取得武器附魔主父框架
local function ensureParentFrame()
    if WeaponEnchantService.parentFrame then return WeaponEnchantService.parentFrame end
    if inCombat() then return nil end

    local cfg = WeaponEnchantService.getConfig()
    local size = (cfg and cfg.iconSize) or 40
    local frame = api.CreateFrame("Frame", "EAM_AlertFrame_weaponEnchant", UIParent)
    frame:SetSize(size, size)
    frame.frameName = "weaponEnchant"
    applyParentFramePoint(frame, cfg)

    WeaponEnchantService.parentFrame = frame
    return frame
end

WeaponEnchantService.ensureParentFrame = ensureParentFrame

local function anchorBadgeToCorner(badgeFrame, parent, corner, isOutside)
    if not badgeFrame or not parent then return end
    badgeFrame:ClearAllPoints()
    if isOutside ~= false then
        if corner == "TOPRIGHT" then
            badgeFrame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 3, 0)
        elseif corner == "BOTTOMLEFT" then
            badgeFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMLEFT", -3, 0)
        elseif corner == "BOTTOMRIGHT" then
            badgeFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 3, 0)
        else
            badgeFrame:SetPoint("TOPRIGHT", parent, "TOPLEFT", -3, 0)
        end
    else
        if corner == "TOPRIGHT" then
            badgeFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 2, 2)
        elseif corner == "BOTTOMLEFT" then
            badgeFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -2, -2)
        elseif corner == "BOTTOMRIGHT" then
            badgeFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 2, -2)
        else
            badgeFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", -2, 2)
        end
    end
end

-- 建立/取得指定槽位的視覺框架 (Slot Frame + Corner Enchant Badge)
local function getOrCreateSlotFrame(slot)
    if WeaponEnchantService.frames[slot] then
        return WeaponEnchantService.frames[slot]
    end
    ensureParentFrame()

    local parent = WeaponEnchantService.parentFrame or UIParent
    local frame = api.CreateFrame("Frame", "EAM_AlertFrame_weaponEnchant_" .. tostring(slot), parent, "BackdropTemplate")
    frame:SetSize(40, 40)
    frame:SetFrameStrata("MEDIUM")
    frame.slot = slot
    frame.auraType = "TempEnchant"
    if type(frame.SetID) == "function" then
        pcall(frame.SetID, frame, slot)
    end

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.icon = icon

    -- 角落附魔小圖示 (Corner Enchant Sub-Icon Badge)
    local badgeFrame = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    badgeFrame:SetSize(18, 18)
    badgeFrame:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 1) + 3)
    badgeFrame.slot = slot
    badgeFrame.auraType = "TempEnchant"
    if type(badgeFrame.SetID) == "function" then
        pcall(badgeFrame.SetID, badgeFrame, slot)
    end
    badgeFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 0, edgeSize = 6,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    badgeFrame:SetBackdropColor(0.04, 0.04, 0.06, 0.95)
    badgeFrame:SetBackdropBorderColor(1.0, 0.82, 0.25, 0.95)
    local badgeIcon = badgeFrame:CreateTexture(nil, "ARTWORK")
    badgeIcon:SetPoint("TOPLEFT", badgeFrame, "TOPLEFT", 2, -2)
    badgeIcon:SetPoint("BOTTOMRIGHT", badgeFrame, "BOTTOMRIGHT", -2, 2)
    badgeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    badgeFrame.icon = badgeIcon
    badgeFrame:EnableMouse(true)
    badgeFrame:SetScript("OnEnter", function()
        if not WeaponEnchantService.isMoving then
            WeaponEnchantService.showEnchantTooltip(frame, frame.slot)
        end
    end)
    badgeFrame:SetScript("OnLeave", function()
        WeaponEnchantService.hideEnchantTooltip()
    end)
    badgeFrame:Hide()
    frame.badgeFrame = badgeFrame
    frame.badgeIcon = badgeIcon

    local timeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    timeText:SetTextColor(1, 1, 1, 1)
    frame.timeText = timeText

    local stackText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stackText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    stackText:SetTextColor(1, 0.9, 0.2, 1)
    frame.stackText = stackText

    local labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    labelText:SetTextColor(0.85, 0.75, 1.0, 1)
    frame.labelText = labelText

    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 0, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    frame:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
    frame:SetBackdropBorderColor(0.85, 0.55, 1.0, 0.9)

    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if not WeaponEnchantService.isMoving then
            WeaponEnchantService.showEnchantTooltip(self, self.slot)
        end
    end)
    frame:SetScript("OnLeave", function()
        WeaponEnchantService.hideEnchantTooltip()
    end)

    WeaponEnchantService.frames[slot] = frame
    return frame
end

WeaponEnchantService.getOrCreateSlotFrame = getOrCreateSlotFrame

-- 高亮邊框與發光處理（支援作用中與非作用中獨立選項）
local function applyFrameHighlight(frame, state, cfg, LBG)
    if state.isMissing then
        if cfg.glowMissing ~= false then
            if LBG and LBG.ShowOverlayGlow then
                LBG.ShowOverlayGlow(frame)
            end
        else
            if LBG and LBG.HideOverlayGlow then
                LBG.HideOverlayGlow(frame)
            end
        end
        if not WeaponEnchantService.isMoving then
            frame:SetBackdropBorderColor(1.0, 0.2, 0.2, 1.0)
        end
    elseif state.isExpiring then
        if cfg.glowExpiring ~= false or cfg.glowActive == true then
            if LBG and LBG.ShowOverlayGlow then
                LBG.ShowOverlayGlow(frame)
            end
        else
            if LBG and LBG.HideOverlayGlow then
                LBG.HideOverlayGlow(frame)
            end
        end
        if not WeaponEnchantService.isMoving then
            frame:SetBackdropBorderColor(1.0, 0.65, 0.1, 1.0)
        end
    elseif state.hasEnchant and cfg.glowActive == true then
        if LBG and LBG.ShowOverlayGlow then
            LBG.ShowOverlayGlow(frame)
        end
        if not WeaponEnchantService.isMoving then
            frame:SetBackdropBorderColor(0.30, 0.95, 0.55, 1.0)
        end
    else
        if LBG and LBG.HideOverlayGlow then
            LBG.HideOverlayGlow(frame)
        end
        if not WeaponEnchantService.isMoving then
            frame:SetBackdropBorderColor(0.85, 0.55, 1.0, 0.9)
        end
    end
end

-- 智慧控制 OnUpdate 生命週期：僅在有活躍倒數或啟用警報音效警示時運作
local function syncTickerState()
    local ticker = WeaponEnchantService.tickerFrame
    if not ticker then return end

    if not isServiceEnabled() then
        ticker:SetScript("OnUpdate", nil)
        return
    end

    local cfg = WeaponEnchantService.getConfig()
    local needTick = false
    for _, slot in ipairs(ENCHANT_SLOTS) do
        local s = WeaponEnchantService.states[slot]
        if s and s.shown then
            if s.hasEnchant and s.hasExpiration and s.expiration > 0 then
                needTick = true
                break
            end
            if cfg and cfg.playSound == true and (s.isMissing or s.isExpiring) then
                needTick = true
                break
            end
        end
    end

    if needTick then
        ticker:SetScript("OnUpdate", WeaponEnchantService._onTickerUpdate)
    else
        ticker:SetScript("OnUpdate", nil)
    end
end

-- 輕量倒數文字更新（不重查裝備與附魔 API、不重排錨點）
function WeaponEnchantService.tickCountdown()
    if not isServiceEnabled() then
        syncTickerState()
        return
    end

    local cfg = WeaponEnchantService.getConfig()
    local expireThreshold = (cfg and isSafeNumber(cfg.expireThreshold) and cfg.expireThreshold > 0) and cfg.expireThreshold or 300
    local warnExpiring = (cfg and cfg.warnExpiring ~= false)
    local now = getCurrentTime()
    local needFullResample = false

    for _, slot in ipairs(ENCHANT_SLOTS) do
        local state = WeaponEnchantService.states[slot]
        local frame = WeaponEnchantService.frames[slot]
        if state and state.shown then
            if state.hasEnchant and state.hasExpiration and state.expiration > 0 then
                local remaining = state.expiration - now
                if remaining <= 0 then
                    needFullResample = true
                    break
                end
                state.durationSec = remaining
                if frame and frame.timeText then
                    frame.timeText:SetText(WeaponEnchantService.formatDuration(remaining))
                end
                if warnExpiring and not state.isExpiring and remaining <= expireThreshold then
                    needFullResample = true
                    break
                end
                if frame and _G.GameTooltip and _G.GameTooltip.IsOwned and _G.GameTooltip:IsOwned(frame) then
                    local secKey = mathFloor(remaining + 0.5)
                    if state._lastTooltipSec ~= secKey then
                        state._lastTooltipSec = secKey
                        WeaponEnchantService.showEnchantTooltip(frame, slot)
                    end
                end
            end

            if cfg and cfg.playSound == true and (state.isMissing or state.isExpiring) then
                if (now - (WeaponEnchantService.lastSoundAlertTime[slot] or 0)) > 30.0 then
                    WeaponEnchantService.lastSoundAlertTime[slot] = now
                    local ms = EAM.Services and EAM.Services.MediaService
                    if ms and type(ms.playSound) == "function" then
                        ms.playSound(cfg.soundName or "ShayBell")
                    elseif _G.PlaySoundFile then
                        pcall(_G.PlaySoundFile, "Sound\\Interface\\RaidWarning.ogg", "Master")
                    end
                end
            end
        end
    end

    if needFullResample then
        WeaponEnchantService.update()
    end
end

-- 刷新畫面 HUD 與告警呈現（完整狀態與排版路徑）
function WeaponEnchantService.update()
    if not isServiceEnabled() then
        if WeaponEnchantService.parentFrame then
            WeaponEnchantService.parentFrame:Hide()
        end
        for _, slot in ipairs(ENCHANT_SLOTS) do
            local s = WeaponEnchantService.states[slot]
            if s then s.shown = false end
        end
        for _, f in pairs(WeaponEnchantService.frames) do
            f:Hide()
        end
        syncTickerState()
        return
    end

    if not WeaponEnchantService.parentFrame and not ensureParentFrame() then return end

    local cfg = WeaponEnchantService.getConfig()
    local states = WeaponEnchantService.sampleWeaponEnchants()

    applyParentFramePoint(WeaponEnchantService.parentFrame, cfg)

    for i = 1, #slotsToShowBuffer do
        slotsToShowBuffer[i] = nil
    end
    for _, slot in ipairs(ENCHANT_SLOTS) do
        activeSlotsBuffer[slot] = nil
        local s = states[slot]
        if s then s.shown = false end
    end

    local showSlotMap = {
        [16] = (cfg.showMainHand ~= false),
        [17] = (cfg.showOffHand ~= false),
        [18] = (cfg.showRanged == true),
    }

    for _, slot in ipairs(ENCHANT_SLOTS) do
        local s = states[slot]
        if s and showSlotMap[slot] then
            local showActiveEnchant = s.hasEnchant and (cfg.showActive ~= false)
            local showMissingAlert = s.isMissing and (cfg.warnMissing ~= false)
            if showActiveEnchant or showMissingAlert then
                s.shown = true
                slotsToShowBuffer[#slotsToShowBuffer + 1] = s
                activeSlotsBuffer[slot] = true
            end
        end
    end

    if #slotsToShowBuffer == 0 then
        if not WeaponEnchantService.isMoving then
            WeaponEnchantService.parentFrame:Hide()
        end
        for _, f in pairs(WeaponEnchantService.frames) do
            f:Hide()
        end
        syncTickerState()
        return
    end

    WeaponEnchantService.parentFrame:Show()

    local db = EAM.db
    local layoutFrame = db and db.layout and db.layout.frames and db.layout.frames.weaponEnchant
    local growDir = (isSafeNumber(cfg.growDirection) and cfg.growDirection)
        or (layoutFrame and layoutFrame.growDirection)
        or 1
    local spacing = (isSafeNumber(cfg.spacing) and cfg.spacing)
        or (db and db.layout and db.layout.spacing)
        or 6
    local size = cfg.iconSize or 40
    local badgeCorner = cfg.badgePosition or "TOPLEFT"
    local badgeSize = mathMax(12, mathFloor(size * (cfg.badgeScale or 0.45) + 0.5))

    local LBG = _G.LibStub and _G.LibStub("LibButtonGlow-1.0", true)

    for idx = 1, #slotsToShowBuffer do
        local state = slotsToShowBuffer[idx]
        local frame = getOrCreateSlotFrame(state.slot)
        frame:SetSize(size, size)
        frame:Show()

        if not WeaponEnchantService.isMoving then
            frame:ClearAllPoints()
            local offset = (idx - 1) * (size + spacing)
            local dx, dy = 0, 0
            if growDir == 1 then
                dx = offset
            elseif growDir == 2 then
                dx = -offset
            elseif growDir == 3 then
                dy = offset
            elseif growDir == 4 then
                dy = -offset
            end
            frame:SetPoint("CENTER", WeaponEnchantService.parentFrame, "CENTER", dx, dy)
        end

        frame.icon:SetTexture(state.icon or DEFAULT_WEAPON_ICON)
        frame.labelText:SetText(getSlotShortLabel(state.slot))

        applyFrameHighlight(frame, state, cfg, LBG)

        if state.hasEnchant then
            if state.hasExpiration then
                local durStr = WeaponEnchantService.formatDuration(state.durationSec)
                frame.timeText:SetText(durStr ~= "" and durStr or "1s")
                if state.isExpiring then
                    frame.timeText:SetTextColor(1.0, 0.4, 0.2, 1.0)
                else
                    frame.timeText:SetTextColor(1.0, 1.0, 1.0, 1.0)
                end
            else
                frame.timeText:SetText("")
            end

            if state.charges and state.charges > 0 then
                frame.stackText:SetText(tostring(state.charges))
                frame.stackText:SetTextColor(1.0, 0.9, 0.2, 1.0)
                frame.stackText:Show()
            else
                frame.stackText:Hide()
            end

            if frame.badgeFrame and frame.badgeIcon then
                if cfg.showEnchantBadge ~= false then
                    local baseLevel = (frame.GetFrameLevel and frame:GetFrameLevel()) or 1
                    local glowOverlay = frame.__LBGoverlay
                    local glowLevel = (glowOverlay and glowOverlay.GetFrameLevel and glowOverlay:GetFrameLevel()) or 0
                    frame.badgeFrame:SetFrameLevel(mathMax(baseLevel + 10, glowLevel + 2))
                    frame.badgeFrame:SetSize(badgeSize, badgeSize)
                    anchorBadgeToCorner(frame.badgeFrame, frame, badgeCorner, cfg.badgeOutside ~= false)
                    frame.badgeIcon:SetTexture(state.enchantIcon or DEFAULT_ENCHANT_BADGE_ICON)
                    frame.badgeFrame:Show()
                else
                    frame.badgeFrame:Hide()
                end
            end
        else
            -- 缺少附魔
            frame.timeText:SetText(localized("EAM_WEAPON_ENCHANT_MISSING", "缺少附魔"))
            frame.timeText:SetTextColor(1.0, 0.2, 0.2, 1.0)
            frame.stackText:SetText("!")
            frame.stackText:SetTextColor(1.0, 0.2, 0.2, 1.0)
            frame.stackText:Show()
            if frame.badgeFrame then
                frame.badgeFrame:Hide()
            end
        end
    end

    for slot, f in pairs(WeaponEnchantService.frames) do
        if not activeSlotsBuffer[slot] then
            f:Hide()
        end
    end

    syncTickerState()
end

-- 支援移動模式拖曳控制 (Mover HUD)
function WeaponEnchantService.setActiveAnchors(enable)
    if inCombat() then return false, "combatDeferred" end
    WeaponEnchantService.isMoving = (enable == true)

    if WeaponEnchantService.isMoving then
        WeaponEnchantService.hideEnchantTooltip()
        for _, f in pairs(WeaponEnchantService.frames) do
            if f.badgeFrame and f.badgeFrame.EnableMouse then
                f.badgeFrame:EnableMouse(false)
            end
        end
        ensureParentFrame()
        local parent = WeaponEnchantService.parentFrame
        if parent then
            parent:Show()
            parent:SetSize(120, 42)
            parent:SetMovable(true)
            parent:EnableMouse(true)
            parent:SetFrameStrata("FULLSCREEN_DIALOG")
            parent:SetClampedToScreen(true)
            parent:RegisterForDrag("LeftButton")

            if not parent.moverHUD then
                local hud = api.CreateFrame("Frame", nil, parent, "BackdropTemplate")
                hud:SetSize(140, 42)
                hud:SetPoint("CENTER", parent, "CENTER", 0, 0)
                hud:SetBackdrop({
                    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 }
                })
                hud:SetBackdropColor(0.20, 0.05, 0.25, 0.65)
                hud:SetBackdropBorderColor(0.85, 0.55, 1.0, 0.95)

                local title = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                title:SetPoint("TOP", hud, "TOP", 0, -4)
                title:SetTextColor(0.85, 0.55, 1.0, 1.0)
                title:SetText("★ " .. localized("EAM_WEAPON_ENCHANT_TITLE", "武器臨時附魔"))

                local sub = hud:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                sub:SetPoint("BOTTOM", hud, "BOTTOM", 0, 4)
                sub:SetTextColor(0.9, 0.9, 0.9, 0.9)
                sub:SetText("[左鍵拖曳 / 右鍵完成]")

                parent.moverHUD = hud
            end
            parent.moverHUD:Show()

            parent:SetScript("OnDragStart", parent.StartMoving)
            parent:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                local point, _, _, x, y = self:GetPoint()
                local rx = mathFloor((x or 120) + 0.5)
                local ry = mathFloor((y or -120) + 0.5)
                local cfg = WeaponEnchantService.getConfig()
                cfg.point = point or "CENTER"
                cfg.x = rx
                cfg.y = ry
                syncPositionToLayout(cfg)
                if EAM.UI.WeaponEnchantPanel and EAM.UI.WeaponEnchantPanel.refresh then
                    EAM.UI.WeaponEnchantPanel.refresh()
                end
                print("|cff00ff96EAM|r " .. string.format("武器附魔框架已儲存: X: %.1f, Y: %.1f", rx, ry))
            end)
            parent:SetScript("OnMouseUp", function(_, button)
                if button == "RightButton" and WeaponEnchantService.isMoving then
                    WeaponEnchantService.setActiveAnchors(false)
                    print("|cff00ff96EAM|r 已關閉武器附魔移動模式。")
                end
            end)
        end
    else
        if WeaponEnchantService.parentFrame then
            WeaponEnchantService.parentFrame:SetMovable(false)
            WeaponEnchantService.parentFrame:EnableMouse(false)
            WeaponEnchantService.parentFrame:SetFrameStrata("MEDIUM")
            if WeaponEnchantService.parentFrame.moverHUD then
                WeaponEnchantService.parentFrame.moverHUD:Hide()
            end
        end
        for _, f in pairs(WeaponEnchantService.frames) do
            f:SetMovable(false)
            f:EnableMouse(true)
            f:SetFrameStrata("MEDIUM")
            if f.badgeFrame and f.badgeFrame.EnableMouse then
                f.badgeFrame:EnableMouse(true)
            end
        end
        if EAM.UI.WeaponEnchantPanel and EAM.UI.WeaponEnchantPanel.refresh then
            EAM.UI.WeaponEnchantPanel.refresh()
        end
        WeaponEnchantService.update()
    end
    return true
end

-- 模組生命週期即時開關回呼 (ModuleController Toggle Hook)
function WeaponEnchantService.onModuleToggle(enabled)
    WeaponEnchantService.enabled = (enabled ~= false)
    if enabled == false then
        WeaponEnchantService.hideEnchantTooltip()
        if WeaponEnchantService.parentFrame then
            WeaponEnchantService.parentFrame:Hide()
        end
        for _, slot in ipairs(ENCHANT_SLOTS) do
            local s = WeaponEnchantService.states[slot]
            if s then s.shown = false end
        end
        for _, f in pairs(WeaponEnchantService.frames) do
            f:Hide()
        end
        if WeaponEnchantService.isMoving then
            WeaponEnchantService.setActiveAnchors(false)
        end
        syncTickerState()
    else
        WeaponEnchantService.update()
    end
end

-- 定期倒數計時器（每 0.20 秒更新剩餘時間文字，僅於需要時掛載 OnUpdate）
local function initTicker()
    if WeaponEnchantService.tickerFrame then return end
    local tickerFrame = api.CreateFrame("Frame")
    local elapsed = 0
    WeaponEnchantService._onTickerUpdate = function(_, delta)
        elapsed = elapsed + (delta or 0)
        if elapsed >= 0.20 then
            elapsed = 0
            WeaponEnchantService.tickCountdown()
        end
    end
    WeaponEnchantService.tickerFrame = tickerFrame
end

-- ============================================================================
-- 獨立武器臨時附魔設定面板 (EAM.UI.WeaponEnchantPanel)
-- ============================================================================

local Panel = {
    frame = nil,
    controls = {},
    syncing = false,
}
EAM.UI.WeaponEnchantPanel = Panel

local function setPanelControlText(target, key, fallback)
    local locale = getLocale()
    if locale and type(locale.bindText) == "function" then
        return locale.bindText(target, key, fallback)
    end
    if target and type(target.SetText) == "function" then
        target:SetText(localized(key, fallback))
    end
end

local function createPanelCheckbox(parent, key, fallback, x, y, fieldName, tipText)
    local apiTheme = getTheme()
    local cb = api.CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetWidth(250)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    setPanelControlText(text, key, fallback)
    if apiTheme and apiTheme.registerText then
        apiTheme.registerText(text, "body")
    end
    cb.text = text

    if EAM.UI.setTooltip and tipText then
        EAM.UI.setTooltip(cb, tipText, localized(key, fallback))
    end

    cb:SetScript("OnClick", function(self)
        if Panel.syncing then return end
        local checked = self:GetChecked() == true
        local cfg = WeaponEnchantService.getConfig()
        cfg[fieldName] = checked
        if fieldName == "enabled" then
            local saved = EAM.Modules and EAM.Modules.SavedVariables
            if saved and type(saved.updateModuleToggle) == "function" then
                saved.updateModuleToggle("weaponEnchant", checked)
            elseif EAM.db and EAM.db.config then
                EAM.db.config.enableWeaponEnchant = checked
            end
            WeaponEnchantService.onModuleToggle(checked)
        else
            WeaponEnchantService.update()
        end
        if EAM.Modules and EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.markRevisionChanged then
            EAM.Modules.SavedVariables.markRevisionChanged()
        end
        Panel.refresh()
    end)

    return cb
end

local function createPanelSlider(parent, key, fallback, minVal, maxVal, stepVal, x, y, width, fieldName, isPercent, syncLayout, tipText)
    local apiTheme = getTheme()
    local slider = api.CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetSize(width or 250, 14)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(stepVal)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    local valText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 4)
    valText:SetJustifyH("RIGHT")
    if apiTheme and apiTheme.registerText then
        apiTheme.registerText(valText, "body")
    end

    local label = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
    label:SetPoint("RIGHT", valText, "LEFT", -4, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    setPanelControlText(label, key, fallback)
    if apiTheme and apiTheme.registerText then
        apiTheme.registerText(label, "title")
    end

    slider.valText = valText
    slider.isPercent = isPercent
    slider.stepVal = stepVal

    if EAM.UI.setTooltip and tipText then
        EAM.UI.setTooltip(slider, tipText, localized(key, fallback))
    end

    slider:SetScript("OnValueChanged", function(_, value)
        local rounded = mathFloor((value / stepVal) + 0.5) * stepVal
        if isPercent then
            valText:SetText(string.format("%d%%", mathFloor(rounded * 100 + 0.5)))
        elseif fieldName == "expireThreshold" then
            valText:SetText(string.format("%ds", mathFloor(rounded + 0.5)))
        else
            valText:SetText(string.format("%d", mathFloor(rounded + 0.5)))
        end
        if Panel.syncing then return end

        local cfg = WeaponEnchantService.getConfig()
        cfg[fieldName] = rounded
        if syncLayout then
            syncPositionToLayout(cfg)
        end
        if EAM.Modules and EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.markRevisionChanged then
            EAM.Modules.SavedVariables.markRevisionChanged()
        end
        WeaponEnchantService.update()
    end)

    return slider
end

local function createPanelFrame()
    if Panel.frame then return Panel.frame end
    local uiParent = _G.UIParent
    if not uiParent then return nil end

    local theme = getTheme()

    local frame = api.CreateFrame("Frame", "EAM_WeaponEnchantOptionsFrame", uiParent, "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(620, 545)
    frame:SetPoint("CENTER", uiParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        local main = _G.EAM_MainOptionsFrame
        if main and main:IsShown() then
            main:StartMoving()
        else
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        local main = _G.EAM_MainOptionsFrame
        if main and main:IsShown() then
            main:StopMovingOrSizing()
        else
            frame:StopMovingOrSizing()
        end
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0.08, 0.06, 0.08, 0.97)
    frame:SetBackdropBorderColor(0.82, 0.60, 0.92, 1.0)
    if theme and theme.registerFrame then
        theme.registerFrame(frame, "window")
    end
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetTextColor(0.95, 0.85, 0.4, 1.0)
    setPanelControlText(title, "EAM_WEAPON_ENCHANT_PANEL_TITLE", "★ 武器臨時附魔獨立設定")
    if theme and theme.registerText then
        theme.registerText(title, "title")
    end

    local closeBtn = api.CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(26, 26)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function() Panel.hide() end)

    local inner = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    inner:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
    inner:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    inner:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    inner:SetBackdropColor(0.06, 0.05, 0.07, 0.85)
    inner:SetBackdropBorderColor(0.50, 0.35, 0.55, 0.85)
    if theme and theme.registerFrame then
        theme.registerFrame(inner, "panel")
    end

    -- 左欄：監控槽位與高亮開關
    local secSlots = inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secSlots:SetPoint("TOPLEFT", inner, "TOPLEFT", 14, -12)
    secSlots:SetTextColor(0.95, 0.85, 0.4, 1.0)
    secSlots:SetText("監控槽位與基礎開關")
    if theme and theme.registerText then
        theme.registerText(secSlots, "title")
    end

    Panel.controls.enabled = createPanelCheckbox(inner, "EAM_OPT_ENABLE_WEAPON_ENCHANT", "啟用武器暫時附魔提示", 14, -32, "enabled", "總開關：啟用或停用武器臨時附魔提醒")
    Panel.controls.showMainHand = createPanelCheckbox(inner, "EAM_WEAPON_ENCHANT_SHOW_MH", "顯示主手武器附魔 (Slot 16)", 14, -56, "showMainHand", "監控主手武器槽位臨時附魔與缺少警告")
    Panel.controls.showOffHand = createPanelCheckbox(inner, "EAM_WEAPON_ENCHANT_SHOW_OH", "顯示副手武器附魔 (Slot 17)", 14, -80, "showOffHand", "監控副手武器槽位臨時附魔與缺少警告")
    Panel.controls.showRanged = createPanelCheckbox(inner, "EAM_WEAPON_ENCHANT_SHOW_RANGED", "顯示遠程武器附魔 (Slot 18)", 14, -104, "showRanged", "監控遠程欄位的臨時附魔（例如瞄準鏡／魚餌等適用項目）")

    local secHighlight = inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secHighlight:SetPoint("TOPLEFT", inner, "TOPLEFT", 14, -134)
    secHighlight:SetTextColor(0.95, 0.85, 0.4, 1.0)
    secHighlight:SetText("作用中與未附魔高亮選擇")
    if theme and theme.registerText then
        theme.registerText(secHighlight, "title")
    end

    Panel.controls.showActive = createPanelCheckbox(inner, "EAM_WEAPON_ENCHANT_SHOW_ACTIVE", "作用中顯示圖示與倒數", 14, -154, "showActive", "已施加臨時附魔時，在畫面上顯示圖示與剩餘倒數")
    Panel.controls.glowActive = createPanelCheckbox(inner, "EAM_WEAPON_ENCHANT_GLOW_ACTIVE", "作用中發光高亮 (Active Glow)", 14, -178, "glowActive", "臨時附魔作用期間維持外框發光高亮")
    Panel.controls.warnExpiring = createPanelCheckbox(inner, "EAM_WEAPON_ENCHANT_PANEL_WARN_EXPIRING", "附魔即將到期提醒", 14, -202, "warnExpiring", "剩餘時間低於門檻或次數剩 1 次時進入到期警示狀態")
    Panel.controls.glowExpiring = createPanelCheckbox(inner, "EAM_WEAPON_ENCHANT_GLOW_EXPIRING", "即將到期時發光高亮", 14, -226, "glowExpiring", "進入即將到期狀態時顯示橘紅外框發光")
    Panel.controls.warnMissing = createPanelCheckbox(inner, "EAM_WEAPON_ENCHANT_PANEL_WARN_MISSING", "缺少武器附魔提醒 (未附魔警告)", 14, -250, "warnMissing", "已裝備武器但缺少臨時附魔時顯示警告圖示")
    Panel.controls.glowMissing = createPanelCheckbox(inner, "EAM_WEAPON_ENCHANT_GLOW_MISSING", "非作用中 (未附魔) 發光高亮", 14, -274, "glowMissing", "未附魔警告期間顯示紅色外框發光高亮")
    Panel.controls.playSound = createPanelCheckbox(inner, "EAM_WEAPON_ENCHANT_PLAY_SOUND", "缺附魔／到期時播放音效 (30s 節流)", 14, -298, "playSound", "缺附魔或即將到期時每 30 秒播放預設提示音效")

    Panel.controls.expireThreshold = createPanelSlider(
        inner, "EAM_WEAPON_ENCHANT_EXPIRE_THRESHOLD", "即將到期警戒閾值 (秒)", 30, 1800, 30, 18, -348, 255, "expireThreshold", false, false,
        "剩餘秒數低於此數值時判定為即將到期"
    )

    -- 右欄：角落附魔小圖示 & 自訂位置／排版
    local secBadge = inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secBadge:SetPoint("TOPLEFT", inner, "TOPLEFT", 310, -12)
    secBadge:SetTextColor(0.95, 0.85, 0.4, 1.0)
    secBadge:SetText("角落附魔小圖示設定")
    if theme and theme.registerText then
        theme.registerText(secBadge, "title")
    end

    Panel.controls.showEnchantBadge = createPanelCheckbox(inner, "EAM_WEAPON_ENCHANT_SHOW_BADGE", "角落顯示附魔小圖示", 310, -32, "showEnchantBadge", "主圖示維持武器圖片，在角落疊加附魔專屬小圖示")
    Panel.controls.badgeOutside = createPanelCheckbox(inner, "EAM_WEAPON_ENCHANT_BADGE_OUTSIDE", "小圖示置於框外 (防發光遮擋)", 310, -56, "badgeOutside", "將附魔小圖示錨定於武器圖示框外側，避免被作用中/到期發光特效 (Glow) 遮擋")

    local badgePosLabel = inner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badgePosLabel:SetPoint("TOPLEFT", inner, "TOPLEFT", 310, -84)
    setPanelControlText(badgePosLabel, "EAM_WEAPON_ENCHANT_BADGE_POS", "小圖示角落位置:")
    if theme and theme.registerText then
        theme.registerText(badgePosLabel, "body")
    end

    local cornerDefs = {
        { value = "TOPLEFT", key = "EAM_WEAPON_ENCHANT_CORNER_TL", fallback = "左上" },
        { value = "TOPRIGHT", key = "EAM_WEAPON_ENCHANT_CORNER_TR", fallback = "右上" },
        { value = "BOTTOMLEFT", key = "EAM_WEAPON_ENCHANT_CORNER_BL", fallback = "左下" },
        { value = "BOTTOMRIGHT", key = "EAM_WEAPON_ENCHANT_CORNER_BR", fallback = "右下" },
    }
    Panel.controls.cornerBtns = {}
    for idx, cDef in ipairs(cornerDefs) do
        local cBtn = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
        cBtn:SetSize(62, 22)
        cBtn:SetPoint("TOPLEFT", inner, "TOPLEFT", 310 + (idx - 1) * 66, -102)
        setPanelControlText(cBtn, cDef.key, cDef.fallback)
        if theme and theme.registerButton then theme.registerButton(cBtn) end
        cBtn.cornerValue = cDef.value
        cBtn:SetScript("OnClick", function()
            local cfg = WeaponEnchantService.getConfig()
            cfg.badgePosition = cDef.value
            WeaponEnchantService.update()
            Panel.refresh()
        end)
        Panel.controls.cornerBtns[idx] = cBtn
    end

    Panel.controls.badgeScale = createPanelSlider(
        inner, "EAM_WEAPON_ENCHANT_BADGE_SCALE", "角落小圖示比例", 0.30, 0.65, 0.05, 314, -152, 255, "badgeScale", true, false,
        "調整角落附魔小圖示相對於主武器圖示的大小比例 (30%~65%)"
    )

    local secPos = inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secPos:SetPoint("TOPLEFT", inner, "TOPLEFT", 310, -186)
    secPos:SetTextColor(0.95, 0.85, 0.4, 1.0)
    secPos:SetText("自訂位置與圖示排版")
    if theme and theme.registerText then
        theme.registerText(secPos, "title")
    end

    Panel.controls.iconSize = createPanelSlider(
        inner, "EAM_WEAPON_ENCHANT_ICON_SIZE", "圖示大小", 24, 80, 1, 314, -220, 120, "iconSize", false, false,
        "調整武器附魔主圖示尺寸 (24~80px)"
    )
    Panel.controls.spacing = createPanelSlider(
        inner, "EAM_WEAPON_ENCHANT_SPACING", "圖示間距", 0, 40, 1, 450, -220, 120, "spacing", false, false,
        "調整多把武器附魔圖示之間的間距 (0~40px)"
    )

    local dirLabel = inner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dirLabel:SetPoint("TOPLEFT", inner, "TOPLEFT", 310, -254)
    setPanelControlText(dirLabel, "EAM_OPT_DIR_TITLE", "圖示成長方向:")
    if theme and theme.registerText then
        theme.registerText(dirLabel, "body")
    end

    local dirDefs = {
        { value = 1, text = "→ 右" },
        { value = 2, text = "← 左" },
        { value = 3, text = "↑ 上" },
        { value = 4, text = "↓ 下" },
    }
    Panel.controls.dirBtns = {}
    for idx, dDef in ipairs(dirDefs) do
        local dBtn = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
        dBtn:SetSize(62, 22)
        dBtn:SetPoint("TOPLEFT", inner, "TOPLEFT", 310 + (idx - 1) * 66, -272)
        dBtn:SetText(dDef.text)
        if theme and theme.registerButton then theme.registerButton(dBtn) end
        dBtn.dirValue = dDef.value
        dBtn:SetScript("OnClick", function()
            local cfg = WeaponEnchantService.getConfig()
            cfg.growDirection = dDef.value
            syncPositionToLayout(cfg)
            WeaponEnchantService.update()
            Panel.refresh()
        end)
        Panel.controls.dirBtns[idx] = dBtn
    end

    Panel.controls.posX = createPanelSlider(
        inner, "EAM_WEAPON_ENCHANT_POS_X", "自訂水平位置 (X)", -1000, 1000, 1, 314, -322, 255, "x", false, true,
        "調整武器附魔框架水平座標 (-1000 ~ +1000)"
    )
    Panel.controls.posY = createPanelSlider(
        inner, "EAM_WEAPON_ENCHANT_POS_Y", "自訂垂直位置 (Y)", -600, 600, 1, 314, -372, 255, "y", false, true,
        "調整武器附魔框架垂直座標 (-600 ~ +600)"
    )

    local moveBtn = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    moveBtn:SetSize(130, 26)
    moveBtn:SetPoint("TOPLEFT", inner, "TOPLEFT", 310, -426)
    setPanelControlText(moveBtn, "EAM_WEAPON_ENCHANT_MOVE_BTN", "移動錨點位置")
    if theme and theme.registerButton then theme.registerButton(moveBtn) end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(moveBtn, "開啟或關閉武器附魔拖曳錨點，直接滑鼠左鍵拖放於畫面任意處", "移動錨點位置")
    end
    moveBtn:SetScript("OnClick", function()
        WeaponEnchantService.setActiveAnchors(not WeaponEnchantService.isMoving)
        Panel.refresh()
    end)
    Panel.controls.moveBtn = moveBtn

    local resetBtn = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    resetBtn:SetSize(130, 26)
    resetBtn:SetPoint("LEFT", moveBtn, "RIGHT", 8, 0)
    setPanelControlText(resetBtn, "EAM_WEAPON_ENCHANT_RESET_POS_BTN", "重設預設位置")
    if theme and theme.registerButton then theme.registerButton(resetBtn) end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(resetBtn, "還原武器附魔位置與排版為預設值 (CENTER, X: 120, Y: -120)", "重設預設位置")
    end
    resetBtn:SetScript("OnClick", function()
        local cfg = WeaponEnchantService.getConfig()
        cfg.point = "CENTER"
        cfg.x = 120
        cfg.y = -120
        cfg.iconSize = 40
        cfg.spacing = 6
        cfg.growDirection = 1
        cfg.badgeOutside = true
        syncPositionToLayout(cfg)
        WeaponEnchantService.update()
        Panel.refresh()
    end)

    Panel.frame = frame
    return frame
end

function Panel.refresh()
    if not Panel.frame then return end
    local cfg = WeaponEnchantService.getConfig()
    Panel.syncing = true

    if Panel.controls.enabled then Panel.controls.enabled:SetChecked(cfg.enabled ~= false) end
    if Panel.controls.showMainHand then Panel.controls.showMainHand:SetChecked(cfg.showMainHand ~= false) end
    if Panel.controls.showOffHand then Panel.controls.showOffHand:SetChecked(cfg.showOffHand ~= false) end
    if Panel.controls.showRanged then Panel.controls.showRanged:SetChecked(cfg.showRanged == true) end
    if Panel.controls.showActive then Panel.controls.showActive:SetChecked(cfg.showActive ~= false) end
    if Panel.controls.glowActive then Panel.controls.glowActive:SetChecked(cfg.glowActive == true) end
    if Panel.controls.warnExpiring then Panel.controls.warnExpiring:SetChecked(cfg.warnExpiring ~= false) end
    if Panel.controls.glowExpiring then Panel.controls.glowExpiring:SetChecked(cfg.glowExpiring ~= false) end
    if Panel.controls.warnMissing then Panel.controls.warnMissing:SetChecked(cfg.warnMissing ~= false) end
    if Panel.controls.glowMissing then Panel.controls.glowMissing:SetChecked(cfg.glowMissing ~= false) end
    if Panel.controls.showEnchantBadge then Panel.controls.showEnchantBadge:SetChecked(cfg.showEnchantBadge ~= false) end
    if Panel.controls.badgeOutside then Panel.controls.badgeOutside:SetChecked(cfg.badgeOutside ~= false) end
    if Panel.controls.playSound then Panel.controls.playSound:SetChecked(cfg.playSound == true) end

    if Panel.controls.expireThreshold then Panel.controls.expireThreshold:SetValue(cfg.expireThreshold or 300) end
    if Panel.controls.badgeScale then Panel.controls.badgeScale:SetValue(cfg.badgeScale or 0.45) end
    if Panel.controls.iconSize then Panel.controls.iconSize:SetValue(cfg.iconSize or 40) end
    if Panel.controls.spacing then Panel.controls.spacing:SetValue(cfg.spacing or 6) end
    if Panel.controls.posX then Panel.controls.posX:SetValue(cfg.x or 120) end
    if Panel.controls.posY then Panel.controls.posY:SetValue(cfg.y or -120) end

    local activeCorner = cfg.badgePosition or "TOPLEFT"
    for _, cBtn in ipairs(Panel.controls.cornerBtns or {}) do
        cBtn:SetAlpha(cBtn.cornerValue == activeCorner and 1.0 or 0.55)
    end

    local activeDir = cfg.growDirection or 1
    for _, dBtn in ipairs(Panel.controls.dirBtns or {}) do
        dBtn:SetAlpha(dBtn.dirValue == activeDir and 1.0 or 0.55)
    end

    if Panel.controls.moveBtn then
        if WeaponEnchantService.isMoving then
            Panel.controls.moveBtn:SetAlpha(1.0)
        else
            Panel.controls.moveBtn:SetAlpha(0.85)
        end
    end

    Panel.syncing = false
end

function Panel.open()
    if inCombat() then
        print("|cff00ff96EAM|r 戰鬥中暫不開啟武器附魔設定面板。")
        return false, "combatDeferred"
    end
    local f = createPanelFrame()
    if not f then return false, "unavailable" end

    local theme = getTheme()
    if theme then
        if theme.flushPending then theme.flushPending() end
        if theme.applyAll then theme.applyAll() end
    end

    local mainFrame = _G.EAM_MainOptionsFrame
    f:ClearAllPoints()
    if mainFrame and mainFrame:IsShown() then
        f:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 2, 0)
    else
        f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    end
    Panel.refresh()
    f:Show()
    return true
end

function Panel.hide()
    if Panel.frame then
        Panel.frame:Hide()
    end
end
Panel.close = Panel.hide

function Panel.toggle()
    if Panel.frame and Panel.frame:IsShown() then
        Panel.hide()
    else
        Panel.open()
    end
end

-- ============================================================================
-- 初始化
-- ============================================================================

function WeaponEnchantService.initialize()
    if not WeaponEnchantService.initialized then
        WeaponEnchantService.initialized = true
        local router = EAM.Modules and EAM.Modules.EventRouter
        if router and type(router.register) == "function" then
            local function onEvent()
                WeaponEnchantService.update()
            end
            local function onUnitInventory(_, unit)
                if unit == "player" then
                    onEvent()
                end
            end
            router.register("WEAPON_ENCHANT_CHANGED", onEvent)
            router.register("WEAPON_SLOT_CHANGED", onEvent)
            router.register("PLAYER_EQUIPMENT_CHANGED", onEvent)
            router.register("UNIT_INVENTORY_CHANGED", onUnitInventory)
            router.register("PLAYER_ENTERING_WORLD", onEvent)
            router.register("PLAYER_LOGIN", onEvent)
            router.register("PLAYER_REGEN_DISABLED", onEvent)
            router.register("PLAYER_REGEN_ENABLED", onEvent)
        end
    end
    initTicker()
    WeaponEnchantService.update()
end

WeaponEnchantService.init = WeaponEnchantService.initialize
WeaponEnchantService.refresh = WeaponEnchantService.update

pcall(WeaponEnchantService.initialize)
