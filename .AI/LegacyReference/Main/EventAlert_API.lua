--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_API.lua

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


-- lua table zone
G.tinsert 	= table.insert
G.tsort 	= table.sort
G.tremove 	= table.remove
G.tconcat 	= table.concat
G.tcopy 	= table.copy
G.foreach 	= table.foreach

-- lua sting zone
G.format 		= format
G.strsplit 		= string.split
G.strfind 		= string.find
G.strmatch 		= string.match
G.strgub 		= string.gsub
G.strdump 		= string.dump
G.stlen 		= string.len
G.strlower 		= string.lower
G.strupper 		= string.upper
G.strchar 		= string.char
G.strbyte		= string.byte
G.strgmatch 	= string.gmatch
G.strrep 		= string.rep
G.strreverse 	= string.reverse
G.strsub 		= string.sub
G.CreateFrame 	= CreateFrame

-- WOW API zone

-- local UnitBuff 		= type(UnitBuff)=="function"	and UnitBuff 	or C_UnitAuras.GetBuffDataByIndex
-- local UnitDebuff 	= type(UnitDebuff)=="function"	and UnitDebuff 	or C_UnitAuras.GetDebuffDataByIndex
-- local UnitAura 		= type(UnitAura)=="function"	and UnitAura 	or C_UnitAuras.GetAuraDataByIndex
G.GetAddOnMetadata	 		= GetAddOnMetadata or C_AddOns.GetAddOnMetadata
G.UnitBuff 					= C_UnitAuras.GetBuffDataByIndex
G.UnitDebuff 				= C_UnitAuras.GetDebuffDataByIndex
G.UnitAura 					= C_UnitAuras.GetAuraDataByIndex
G.UnitPower					= UnitPower
G.UnitPowerMax 				= UnitPowerMax
G.UnitPowerType 			= UnitPowerType
G.UnitAffectingCombat 		= UnitAffectingCombat
G.UnitLevel					= UnitLevel
G.UnitClass 				= UnitClass
G.UnitSpellHaste 			= UnitSpellHaste
G.UnitName 					= UnitName
G.UnitIsCorpse 				= UnitIsCorpse
G.UnitIsDeadOrGhost 		= UnitIsDeadOrGhost
G.UnitIsEnemy 				= UnitIsEnemy
G.UnitInRaid 				= UnitInRaid
G.UnitInParty 				= UnitInParty
G.UnitHealth 				= UnitHealth
G.UnitHealthMax				= UnitHealthMax
G.UnitExists 				= UnitExists
G.GetTime 					= GetTime
G.GetActiveSpecGroup		= GetActiveSpecGroup


G.GetInventoryItemCooldown 	= GetInventoryItemCooldown	
G.GetInventoryItemID 		= GetInventoryItemID
G.GetItemSpell 				= type(GetItemSpell)=="function"			and GetItemSpell 			or C_Item.GetItemSpell 
G.GetItemCooldown			= type(GetItemCooldown)=="function"			and GetItemCooldown			or C_Container.GetItemCooldown
G.GetContainerNumSlots 		= type(GetContainerNumSlots)=="function" 	and GetContainerNumSlots	or C_Container.GetContainerNumSlots
G.GetContainerItemID 		= type(GetContainerItemID) == "function"  	and GetContainerItemID		or C_Container.GetContainerItemID
	
-- WOW API : ShapeshiftForm
G.GetShapeshiftForm 		= GetShapeshiftForm
G.GetShapeshiftFormID		= GetShapeshiftFormID

-- WOW API : Specialization
G.GetSpecialization 		= GetSpecialization 	and GetSpecialization 		or C_SpecializationInfo.GetSpecialization
G.GetSpecializationInfo 	= GetSpecializationInfo	and GetSpecializationInfo 	or C_SpecializationInfo.GetSpecializationInfo
G.GetActiveSpecGroup		= GetActiveSpecGroup	and GetActiveSpecGroup 		or C_SpecializationInfo.GetActiveSpecGroup
-- WOW API : Spell
G.GetSpellCharges 			= type(GetSpellCharges)=="function" 	and GetSpellCharges 	or C_Spell.GetSpellCharges
G.GetSpellCooldown 			= type(GetSpellCooldown)=="function" 	and GetSpellCooldown 	or C_Spell.GetSpellCooldown
G.GetSpellInfo 				= type(GetSpellInfo)=="function"		and GetSpellInfo 		or C_Spell.GetSpellInfo
G.GetSpellLink 				= type(GetSpellLink)=="function"		and GetSpellLink 		or C_Spell.GetSpellLink
G.GetSpellTexture 			= type(GetSpellTexture)=="function"		and GetSpellTexture 	or C_Spell.GetSpellTexture
G.IsUsableSpell 			= type(IsUsableSpell)=="function"		and IsUsableSpell		or C_Spell.IsSpellUsable

G.GetTotemInfo 				= GetTotemInfo
-- WOW API : Group
G.GetNumSubgroupMembers = GetNumSubgroupMembers
-- WOW API : Widget
G.UIParent = UIParent
G.GameTooltip = GameTooltip
G.UIFrameFadeIn = UIFrameFadeIn
G.UIFrameFadeOut = UIFrameFadeOut
-- WOW API : System
G.RegisterAllEvents = RegisterAllEvents
G.RegisterEvent = RegisterEvent
G.PlaySoundFile = PlaySoundFile
