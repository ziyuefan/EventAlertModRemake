--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/SpellBookScannerService
檔案: Services\SpellBookScannerService.lua

理念:
- 在非戰鬥中動態探測玩家法術書（C_SpellBook）與天賦節點（C_Traits），快取當前已點出的有效技能。
- 自動識別無光環地面效果（Ground Effects），為智慧推薦與「一鍵依當前天賦同步」提供資料基礎。

責任:
- 監聽 PLAYER_LOGIN、SPELLS_CHANGED、TRAIT_CONFIG_UPDATED。
- 快取 knownSpells、activeTraitSpells 與 activeGroundEffects。
- 提供 isSpellKnown(spellId) 與 isSpellInActiveBuild(spellId) 查詢。

邊界:
- 嚴格僅在非戰鬥中執行掃描（耗時 < 10ms）；戰鬥中 100% 關閉掃描，零 GC 零 Taint。
--]]
local _, EAM = ...

EAM.Services = EAM.Services or {}

local SpellBookScannerService = {
    knownSpells = {},         -- [spellId] = true
    activeTraitSpells = {},   -- [spellId] = true
    activeGroundEffects = {}, -- [spellId] = { duration = 10, name = "..." }
    isScanning = false,
    lastScanTime = 0,
}
EAM.Services.SpellBookScannerService = SpellBookScannerService

local function getSpellHeuristics()
    return EAM.Data and EAM.Data.SpellHeuristics
end

-- 掃描玩家法術書中的主動與被動技能
local function scanSpellBook()
    local known = {}

    -- 現代 Retail 12.x C_SpellBook API 遍歷
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local numSkillLines = C_SpellBook.GetNumSpellBookSkillLines()
        for skillLineIndex = 1, numSkillLines do
            local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)
            if skillLineInfo and skillLineInfo.numSpellBookItems then
                local offset = skillLineInfo.itemIndexOffset or 0
                for itemIndex = offset + 1, offset + skillLineInfo.numSpellBookItems do
                    local itemType, actionID, spellID = C_SpellBook.GetSpellBookItemType(itemIndex, Enum.SpellBookSpellBank.Player)
                    if spellID and spellID > 0 then
                        known[spellID] = true
                    elseif actionID and actionID > 0 then
                        known[actionID] = true
                    end
                end
            end
        end
    end

    return known
end

-- 掃描玩家當前天賦樹與英雄天賦節點 (C_Traits / C_ClassTalents)
local function scanActiveTraits()
    local traitSpells = {}

    if C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo then
        local configID = C_ClassTalents.GetActiveConfigID()
        if configID then
            local configInfo = C_Traits.GetConfigInfo(configID)
            if configInfo and configInfo.treeIDs then
                for _, treeID in ipairs(configInfo.treeIDs) do
                    local nodes = C_Traits.GetTreeNodes(treeID)
                    if nodes then
                        for _, nodeID in ipairs(nodes) do
                            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                            if nodeInfo and (nodeInfo.activeEntry or (nodeInfo.ranksPurchased and nodeInfo.ranksPurchased > 0)) then
                                local entryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID or (nodeInfo.entryIDs and nodeInfo.entryIDs[1])
                                if entryID then
                                    local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                                    if entryInfo and entryInfo.definitionID then
                                        local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                                        if defInfo and defInfo.spellID and defInfo.spellID > 0 then
                                            traitSpells[defInfo.spellID] = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return traitSpells
end

-- 完整掃描（限制在非戰鬥中執行）
function SpellBookScannerService.scan()
    if InCombatLockdown() then
        return
    end

    SpellBookScannerService.isScanning = true

    -- 1. 掃描法術書
    local known = scanSpellBook()

    -- 2. 掃描天賦樹
    local traitSpells = scanActiveTraits()

    -- 合併為有效技能池
    for sId in pairs(traitSpells) do
        known[sId] = true
    end

    SpellBookScannerService.knownSpells = known
    SpellBookScannerService.activeTraitSpells = traitSpells

    -- 3. 自動識別並比對無光環地面效果 (Ground Effects)
    local sh = getSpellHeuristics()
    local groundKnown = {}
    if sh and sh.GROUND_EFFECTS then
        for sId, gInfo in pairs(sh.GROUND_EFFECTS) do
            if known[sId] then
                groundKnown[sId] = gInfo
            end
        end
    end
    SpellBookScannerService.activeGroundEffects = groundKnown

    SpellBookScannerService.lastScanTime = GetTime()
    SpellBookScannerService.isScanning = false
end

-- 檢查某法術是否為玩家已學
function SpellBookScannerService.isSpellKnown(spellId)
    if not spellId then
        return false
    end
    return SpellBookScannerService.knownSpells[spellId] == true
end

-- 檢查某法術是否在當前天賦配點中有效
function SpellBookScannerService.isSpellInActiveBuild(spellId)
    if not spellId then
        return false
    end
    return SpellBookScannerService.activeTraitSpells[spellId] == true or SpellBookScannerService.knownSpells[spellId] == true
end

-- 註冊生命週期與事件監聽
function SpellBookScannerService.init()
    if EAM.EventRouter and EAM.EventRouter.register then
        EAM.EventRouter.register("PLAYER_LOGIN", function()
            SpellBookScannerService.scan()
        end)
        EAM.EventRouter.register("SPELLS_CHANGED", function()
            SpellBookScannerService.scan()
        end)
        EAM.EventRouter.register("TRAIT_CONFIG_UPDATED", function()
            SpellBookScannerService.scan()
        end)
        EAM.EventRouter.register("PLAYER_REGEN_ENABLED", function()
            -- 脫戰後若距離上次掃描超過 30 秒則自動刷新
            if GetTime() - SpellBookScannerService.lastScanTime > 30 then
                SpellBookScannerService.scan()
            end
        end)
    end
end
