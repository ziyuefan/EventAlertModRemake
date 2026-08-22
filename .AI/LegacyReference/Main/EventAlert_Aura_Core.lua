--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_Aura_Core.lua

理念:
- 保留舊版 EAM 行為參考，供 Retail rewrite migration 對照。
- 此檔不屬正式載入路徑；重寫時只取行為語意，不沿用舊架構。

責任:
- 說明此檔案在目前架構中的責任、資料所有權與維護定位。

邊界:
- 不得繞過 Secret/Protected Data。
- 不得在熱路徑製造不必要 table、closure 或字串配置。
- 若屬 LegacyReference，只能作為行為參考，不得直接成為新架構依賴。
]]
----------------------------------------------------
-- Assign addon space to local G var.  
-- For sync addon space to each lua fils
-----------------------------------------------------
local _
local _G = _G

local addonName, G = ... 
_G[addonName] = _G[addonName] or G
-----------------------------------
if LibDebug then LibDebug() end
-----------------------------------
G.WOW_VERSION = select(4,	GetBuildInfo())	-- Numric Version 
-----------------------------------
-- 檢查Lib_ZYF是否有先載入
--------------------------------
if (Lib_ZYF == nil ) then
	print("No Lib_ZYF loaded")	
	return
else
	print("Lib_ZYF loaded")
end
--------------------------------
-- 常用函數設為區域變數以提昇效能
--------------------------------
-- lua default command zone
local print 					= print
local pairs 					= pairs
local ipairs 					= ipairs
local tonumber 					= tonumber
local tostring 					= tostring
local type 						= type
local table 					= table
local select 					= select
local collectgarbage 			= collectgarbage
local hooksecurefunc 			= hooksecurefunc

-- lua table zone
local tinsert					= table.insert
local tsort 					= table.sort
local tremove 					= table.remove
local tconcat 					= table.concat
local tcopy 					= table.copy
local foreach 					= table.foreach
local wipe						= table.wipe

-- lua sting zone
local format 					= format
local strsplit 					= string.split
local strfind 					= string.find
local strmatch 					= string.match
local strgub 					= string.gsub
local strdump 					= string.dump
local stlen 					= string.len
local strlower 					= string.lower
local strupper 					= string.upper
local strchar 					= string.char
local strbyte 					= string.byte
local strgmatch 				= string.gmatch
local strrep 					= string.rep
local strreverse 				= string.reverse
local strsub 					= string.sub

-- WOW API zone
local CreateFrame 				= CreateFrame
local GetAddOnMetadata 			= GetAddOnMetadata or C_AddOns.GetAddOnMetadata
-- local UnitBuff 				= type(UnitBuff)=="function"	and UnitBuff 	or C_UnitAuras.GetBuffDataByIndex
-- local UnitDebuff 			= type(UnitDebuff)=="function"	and UnitDebuff 	or C_UnitAuras.GetDebuffDataByIndex
-- local UnitAura 				= type(UnitAura)=="function"	and UnitAura 	or C_UnitAuras.GetAuraDataByIndex
local UnitBuff 					= C_UnitAuras.GetBuffDataByIndex
local UnitDebuff 				= C_UnitAuras.GetDebuffDataByIndex
local UnitAura 					= C_UnitAuras.GetAuraDataByIndex
local UnitPower 				= UnitPower
local UnitPowerMax				= UnitPowerMax
local UnitPowerType 			= UnitPowerType
local UnitAffectingCombat 		= UnitAffectingCombat
local UnitLevel 				= UnitLevel
local UnitClass 				= UnitClass
local UnitSpellHaste 			= UnitSpellHaste
local UnitName 					= UnitName
local UnitIsCorpse 				= UnitIsCorpse
local UnitIsDeadOrGhost 		= UnitIsDeadOrGhost
local UnitIsEnemy 				= UnitIsEnemy
local UnitInRaid 				= UnitInRaid
local UnitInParty 				= UnitInParty
local UnitHealth 				= UnitHealth
local UnitHealthMax 			= UnitHealthMax
local UnitExists 				= UnitExists
local GetTime 					= GetTime

-- WOW API: Inventory & Item
local GetInventoryItemCooldown 	= GetInventoryItemCooldown	
local GetInventoryItemID 		= GetInventoryItemID
local GetItemSpell 				= type(GetItemSpell)=="function"			and GetItemSpell 			or C_Item.GetItemSpell 
local GetItemCooldown			= type(GetItemCooldown)=="function"			and GetItemCooldown			or C_Item.GetItemCooldown
local GetContainerNumSlots 		= type(GetContainerNumSlots)=="function" 	and GetContainerNumSlots	or C_Container.GetContainerNumSlots
local GetContainerItemID 		= type(GetContainerItemID) == "function"  	and GetContainerItemID		or C_Container.GetContainerItemID
	
-- WOW API : ShapeshiftForm
local GetShapeshiftForm 		= GetShapeshiftForm
local GetShapeshiftFormID 		= GetShapeshiftFormID

-- WOW API : Specialization   
local GetSpecialization 		= GetSpecialization 	and GetSpecialization 		or C_SpecializationInfo.GetSpecialization
local GetSpecializationInfo 	= GetSpecializationInfo	and GetSpecializationInfo 	or C_SpecializationInfo.GetSpecializationInfo
local GetActiveSpecGroup		= GetActiveSpecGroup	and GetActiveSpecGroup 		or C_SpecializationInfo.GetActiveSpecGroup

-- WOW API : Spell
local GetSpellCharges 			= type(GetSpellCharges)=="function" 	and GetSpellCharges 	or C_Spell.GetSpellCharges
local GetSpellCooldown 			= type(GetSpellCooldown)=="function" 	and GetSpellCooldown 	or C_Spell.GetSpellCooldown
local GetSpellInfo 				= type(GetSpellInfo)=="function"		and GetSpellInfo 		or C_Spell.GetSpellInfo
local GetSpellLink 				= type(GetSpellLink)=="function"		and GetSpellLink 		or C_Spell.GetSpellLink
local GetSpellTexture 			= type(GetSpellTexture)=="function"		and GetSpellTexture 	or C_Spell.GetSpellTexture
local IsUsableSpell 			= type(IsUsableSpell)=="function"		and IsUsableSpell		or C_Spell.IsSpellUsable
-- WOW API : Totem
local GetTotemInfo 				= GetTotemInfo

-- WOW API : Group
local GetNumSubgroupMembers 	= GetNumSubgroupMembers

-- WOW API : Widget
local UIParent 					= UIParent
local GameTooltip 				= GameTooltip
local UIFrameFadeIn 			= UIFrameFadeIn
local UIFrameFadeOut 			= UIFrameFadeOut

-- WOW API : System
local RegisterAllEvents 		= RegisterAllEvents
local RegisterEvent 			= RegisterEvent
local PlaySoundFile				= PlaySoundFile


------------------------------------------------------------------
---
------------------------------------------------------------------
function G:UpdateAurasFull(unitId)		
	local t0 = debugprofilestop()
	--
	G.Auras = G.Auras or {}
	local Auras = G.Auras 
	
	Auras[unitId] = Auras[unitId] or {}		
	
    local function HandleAura(auraData)
		 -- G.Auras[unitId][aura.auraInstanceID] = G.Auras[unitId][aura.auraInstanceID] or {}
		 Auras[unitId][auraData.auraInstanceID] = auraData
        -- Perform any setup or update tasks for this aura here.
    end

    local batchCount = nil
    local usePackedAura = true
    AuraUtil.ForEachAura(unitId, "HELPFUL", batchCount, HandleAura, usePackedAura)
    AuraUtil.ForEachAura(unitId, "HARMFUL", batchCount, HandleAura, usePackedAura)
	G:EAFun_testLabel("UpdateAurasFull", t0, debugprofilestop())
end
------------------------------------------------------------------
--
------------------------------------------------------------------
function G:UpdateAurasIncremental(unitId, UnitAuraUpdateInfo)	
	
	local t0 = debugprofilestop()
	--
	
	G.Auras = G.Auras or {}
	local Auras = G.Auras 
	
	Auras[unitId] = Auras[unitId] or {}	
	
	local auraData	
    if UnitAuraUpdateInfo.addedAuras then	
        for _, auraData in pairs(UnitAuraUpdateInfo.addedAuras) do							
            Auras[unitId][auraData.auraInstanceID] = auraData
			-- print(GetTime().." Add:"..auraData.spellId)
        end
    end

    if UnitAuraUpdateInfo.updatedAuraInstanceIDs then
        for _, auraInstanceID in pairs(UnitAuraUpdateInfo.updatedAuraInstanceIDs) do			
            Auras[unitId][auraInstanceID] = C_UnitAuras.GetAuraDataByAuraInstanceID(unitId, auraInstanceID)
			-- print(GetTime().." Refresh:"..Auras[unitId][auraInstanceID].spellId)
        end
    end

    if UnitAuraUpdateInfo.removedAuraInstanceIDs then
        for _, auraInstanceID in pairs(UnitAuraUpdateInfo.removedAuraInstanceIDs) do						
			Auras[unitId][auraInstanceID] = nil			
			
        end
    end
	
	G:EAFun_testLabel("UpdateAurasIncremental", t0, debugprofilestop())
end
