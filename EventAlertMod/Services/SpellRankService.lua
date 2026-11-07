--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail & Forever
Module: Services/SpellRankService
檔案: Services\SpellRankService.lua

理念:
- 為永恆服 (Forever 1.60.1 / Interface 16001 / Camelot) 提供全鏈路經典法術等級 (Spell Rank) 歸併管理。
- 暴雪原生 C_SpellBook 保留了所有等級 (Rank 1 ~ Rank N)，而原生 AuraContainer / Cooldown / Ground 需要將同一家族所有等級展開為雜湊集合。
- 嚴格隔離：在 Retail 12.x 下 (not EAM.isForever) 所有函式均為 O(1) 原樣返回，零行為改變、零額外開銷！

責任:
- 載入 ForeverCatalog 靜態多等級法術家族表。
- 於非戰鬥冷路徑掃描 C_SpellBook (Player & Pet bank) 自動歸併已學等級與未知等級。
- 提供安全公開介面：getRankSpellIDs, populateSpellIDSet, areSameSpellFamily, getHighestKnownRankSpellID, getSpellSubtext, observeSpellID。
- 監聽 SPELLS_CHANGED 與 PLAYER_REGEN_ENABLED，新等級學會時觸發容器與冷卻重構。

邊界:
- 戰鬥中嚴禁全量掃描 (嚴格防禦 Taint 與 CPU 尖峰)；若在戰鬥中收到 SPELLS_CHANGED 則標記 pendingScan 延至脫戰執行。
- 零閉包分配、零 Secret 數值比較。
]]

local _, EAM = ...

local SpellRankService = {}
EAM.Services = EAM.Services or {}
EAM.Services.SpellRankService = SpellRankService

local api = EAM.API or {}
local Util = EAM.Util or {}

local isForever = false
local initialized = false
local pendingScan = false

-- 內部快取字典
local spellIDToFamily = {}
local nameToFamily = {}
local families = {}
local spellSubtextCache = {}

local function safeNumber(val)
    if Util.isSafeNumber then
        return Util.isSafeNumber(val) and val or nil
    end
    return type(val) == "number" and val or nil
end

local function safeString(val)
    if Util.isSafeString then
        return Util.isSafeString(val) and val ~= "" and val or nil
    end
    return type(val) == "string" and val ~= "" and val or nil
end

-------------------------------------------------------------------------------
-- 靜態表載入
-------------------------------------------------------------------------------
local function loadCatalogFamilies()
    local catalog = EAM.Data and EAM.Data.ForeverCatalog
    if not catalog or type(catalog.GetRankFamilies) ~= "function" then
        return
    end

    local catalogFamilies = catalog.GetRankFamilies()
    if type(catalogFamilies) ~= "table" then
        return
    end

    for familyKey, spellList in pairs(catalogFamilies) do
        local family = {
            key = familyKey,
            spellIDs = {},
            spellIDSet = {},
            highestKnownSpellID = nil,
            subtext = {},
        }
        for i = 1, #spellList do
            local sid = spellList[i]
            if safeNumber(sid) then
                family.spellIDs[#family.spellIDs + 1] = sid
                family.spellIDSet[sid] = true
                spellIDToFamily[sid] = family
            end
        end
        families[#families + 1] = family
    end
end

-------------------------------------------------------------------------------
-- 法術書非戰鬥掃描
-------------------------------------------------------------------------------
local function scanSpellBook()
    if not isForever then
        return
    end

    if api.InCombatLockdown and api.InCombatLockdown() then
        pendingScan = true
        return
    end
    pendingScan = false

    local cSpellBook = api.C_SpellBook or _G.C_SpellBook
    if not cSpellBook then
        return
    end

    local banks = {}
    local bankEnum = Enum and Enum.SpellBookSpellBank
    if bankEnum and bankEnum.Player then
        banks[#banks + 1] = bankEnum.Player
    else
        banks[#banks + 1] = "player"
    end
    if bankEnum and bankEnum.Pet then
        banks[#banks + 1] = bankEnum.Pet
    end

    local newlyLearned = false

    for b = 1, #banks do
        local bank = banks[b]
        local numSpells = 1024
        if type(cSpellBook.GetNumSpellBookItems) == "function" then
            local okNum, n = pcall(cSpellBook.GetNumSpellBookItems, bank)
            if okNum and type(n) == "number" and n > 0 then
                numSpells = n
            end
        end

        for slot = 1, numSpells do
            local itemType, actionID, spellID, subName, spellName
            if type(cSpellBook.GetSpellBookItemInfo) == "function" then
                local ok, info = pcall(cSpellBook.GetSpellBookItemInfo, slot, bank)
                if ok and type(info) == "table" then
                    spellID = safeNumber(info.spellID or info.actionID)
                    spellName = safeString(info.name)
                    subName = safeString(info.subName)
                end
            end

            if not spellID and type(cSpellBook.GetSpellBookItemType) == "function" then
                local okType, iType, actID = pcall(cSpellBook.GetSpellBookItemType, slot, bank)
                if okType then
                    spellID = safeNumber(actID)
                end
            end

            if spellID then
                if subName then
                    spellSubtextCache[spellID] = subName
                elseif api.C_Spell and type(api.C_Spell.GetSpellSubtext) == "function" then
                    local okSub, sText = pcall(api.C_Spell.GetSpellSubtext, spellID)
                    if okSub and safeString(sText) then
                        spellSubtextCache[spellID] = sText
                        subName = sText
                    end
                end

                if not spellName and api.C_Spell and type(api.C_Spell.GetSpellName) == "function" then
                    local okN, sName = pcall(api.C_Spell.GetSpellName, spellID)
                    if okN and safeString(sName) then
                        spellName = sName
                    end
                end

                -- 尋找現存家族或藉由名稱/目錄歸併
                local existingFamily = spellIDToFamily[spellID]
                if not existingFamily and spellName then
                    existingFamily = nameToFamily[spellName]
                end

                if not existingFamily and spellName then
                    existingFamily = {
                        key = "DYNAMIC_" .. spellName,
                        name = spellName,
                        spellIDs = {},
                        spellIDSet = {},
                        highestKnownSpellID = nil,
                        subtext = {},
                    }
                    families[#families + 1] = existingFamily
                    nameToFamily[spellName] = existingFamily
                end

                if existingFamily then
                    if spellName and not nameToFamily[spellName] then
                        nameToFamily[spellName] = existingFamily
                    end
                    if not existingFamily.spellIDSet[spellID] then
                        existingFamily.spellIDs[#existingFamily.spellIDs + 1] = spellID
                        existingFamily.spellIDSet[spellID] = true
                        spellIDToFamily[spellID] = existingFamily
                        newlyLearned = true
                    end
                    if subName then
                        existingFamily.subtext[spellID] = subName
                    end

                    -- 判定是否為玩家最高已知等級
                    local isLowRank = false
                    if type(cSpellBook.IsSpellBookItemLowRank) == "function" then
                        local okLow, low = pcall(cSpellBook.IsSpellBookItemLowRank, slot, bank)
                        if okLow and type(low) == "boolean" then
                            isLowRank = low
                        end
                    end
                    if not isLowRank then
                        existingFamily.highestKnownSpellID = spellID
                    end
                end
            elseif slot > 20 and not itemType then
                -- 超出有法術的槽位範圍，安全結束本 bank 掃描
                break
            end
        end
    end

    if newlyLearned then
        local containerService = EAM.Services and EAM.Services.AuraContainerService
        if containerService and type(containerService.requestRebuild) == "function" then
            containerService.requestRebuild("foreverSpellRankUpdated")
        end
        local router = EAM.Modules and EAM.Modules.EventRouter
        if router and type(router.fire) == "function" then
            router.fire("EAM_SPELL_RANKS_UPDATED")
        end
    end
end

-------------------------------------------------------------------------------
-- 公開查詢介面 (Public Safe APIs)
-------------------------------------------------------------------------------

-- 取得該法術同家族所有等級 ID 陣列（若非 Forever 或未找到則回傳原 ID）
function SpellRankService.getRankSpellIDs(spellID)
    local sID = safeNumber(spellID)
    if not sID then
        return {}
    end
    if not isForever then
        return { sID }
    end

    local family = spellIDToFamily[sID]
    if family and family.spellIDs and #family.spellIDs > 0 then
        return family.spellIDs
    end

    return { sID }
end

-- 將自身與同家族所有等級 ID 寫入 targetSet
function SpellRankService.populateSpellIDSet(spellID, targetSet)
    local sID = safeNumber(spellID)
    if not sID or type(targetSet) ~= "table" then
        return targetSet
    end

    if not isForever then
        targetSet[sID] = true
        return targetSet
    end

    local family = spellIDToFamily[sID]
    if family and family.spellIDs then
        for i = 1, #family.spellIDs do
            targetSet[family.spellIDs[i]] = true
        end
    else
        targetSet[sID] = true
    end

    return targetSet
end

-- 判定兩法術 ID 是否為同一技能家族
function SpellRankService.areSameSpellFamily(spellA, spellB)
    local a = safeNumber(spellA)
    local b = safeNumber(spellB)
    if not a or not b then
        return false
    end
    if a == b then
        return true
    end
    if not isForever then
        return false
    end

    local familyA = spellIDToFamily[a]
    if familyA and familyA.spellIDSet and familyA.spellIDSet[b] then
        return true
    end

    return false
end

-- 取得玩家已學最高等級 ID
function SpellRankService.getHighestKnownRankSpellID(spellID)
    local sID = safeNumber(spellID)
    if not sID or not isForever then
        return sID
    end

    local family = spellIDToFamily[sID]
    if family and family.highestKnownSpellID then
        return family.highestKnownSpellID
    end

    return sID
end

-- 取得法術等級字串（如 "等級 4" / "Rank 4"）
function SpellRankService.getSpellSubtext(spellID)
    local sID = safeNumber(spellID)
    if not sID or not isForever then
        return nil
    end

    if spellSubtextCache[sID] then
        return spellSubtextCache[sID]
    end

    if api.C_Spell and type(api.C_Spell.GetSpellSubtext) == "function" then
        local ok, subtext = pcall(api.C_Spell.GetSpellSubtext, sID)
        if ok and safeString(subtext) then
            spellSubtextCache[sID] = subtext
            return subtext
        end
    end

    local family = spellIDToFamily[sID]
    if family and family.subtext and family.subtext[sID] then
        return family.subtext[sID]
    end

    return nil
end

-- 動態觀察法術（非戰鬥名稱補齊）
function SpellRankService.observeSpellID(spellID)
    local sID = safeNumber(spellID)
    if not sID or not isForever then
        return
    end

    if spellIDToFamily[sID] then
        return
    end

    if api.InCombatLockdown and api.InCombatLockdown() then
        return
    end

    if api.C_Spell and type(api.C_Spell.GetSpellName) == "function" then
        local ok, sName = pcall(api.C_Spell.GetSpellName, sID)
        if ok and safeString(sName) then
            local family = nameToFamily[sName]
            if family then
                family.spellIDs[#family.spellIDs + 1] = sID
                family.spellIDSet[sID] = true
                spellIDToFamily[sID] = family
            end
        end
    end
end

function SpellRankService.getSummary()
    if not isForever then
        return nil
    end
    local famCount = 0
    for _ in pairs(families) do famCount = famCount + 1 end
    local spCount = 0
    for _ in pairs(spellIDToFamily) do spCount = spCount + 1 end

    return {
        enabled = true,
        familyCount = famCount,
        spellCount = spCount,
        pendingScan = pendingScan,
    }
end

-------------------------------------------------------------------------------
-- 初始化與事件綁定
-------------------------------------------------------------------------------
function SpellRankService.initialize()
    if initialized then
        return
    end
    initialized = true

    isForever = (EAM.isForever == true)

    if not isForever then
        return
    end

    loadCatalogFamilies()

    local router = EAM.Modules and EAM.Modules.EventRouter
    if router and type(router.register) == "function" then
        router.register("SPELLS_CHANGED", function()
            scanSpellBook()
        end)
        router.register("PLAYER_REGEN_ENABLED", function()
            if pendingScan then
                scanSpellBook()
            end
        end)
        router.register("PLAYER_ENTERING_WORLD", function()
            scanSpellBook()
        end)
    end

    scanSpellBook()
end

EAM.Modules = EAM.Modules or {}
