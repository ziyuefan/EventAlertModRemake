--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_SpecialPower.lua

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
local print = print
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local type = type
local table = table
local select = select
local collectgarbage = collectgarbage
local hooksecurefunc = hooksecurefunc
-- lua table zone
local tinsert = table.insert
local tsort = table.sort
local tremove = table.remove
local tconcat = table.concat
local tcopy = table.copy
local foreach = table.foreach

-- lua sting zone
local format = format
local strsplit = string.split
local strfind = string.find
local strmatch = string.match
local strgub = string.gsub
local strdump = string.dump
local stlen = string.len
local strlower = string.lower
local strupper = string.upper
local strchar = string.char
local strbyte = string.byte
local strgmatch = string.gmatch
local strrep = string.rep
local strreverse = string.reverse
local strsub = string.sub
-- WOW API zone
local GetAddOnMetadata = GetAddOnMetadata or C_AddOns.GetAddOnMetadata
local CreateFrame 	= CreateFrame
-- local UnitBuff 		= type(UnitBuff)=="function"	and UnitBuff 	or C_UnitAuras.GetBuffDataByIndex
-- local UnitDebuff 	= type(UnitDebuff)=="function"	and UnitDebuff 	or C_UnitAuras.GetDebuffDataByIndex
-- local UnitAura 		= type(UnitAura)=="function"	and UnitAura 	or C_UnitAuras.GetAuraDataByIndex
local UnitBuff 		= C_UnitAuras.GetBuffDataByIndex
local UnitDebuff 	= C_UnitAuras.GetDebuffDataByIndex
local UnitAura 		= C_UnitAuras.GetAuraDataByIndex
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitAffectingCombat = UnitAffectingCombat
local UnitLevel = UnitLevel
local UnitClass = UnitClass
local UnitSpellHaste = UnitSpellHaste
local UnitName = UnitName
local UnitIsCorpse = UnitIsCorpse
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsEnemy = UnitIsEnemy
local UnitInRaid = UnitInRaid
local UnitInParty = UnitInParty
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitExists = UnitExists
local GetTime = GetTime

local GetInventoryItemCooldown 	= GetInventoryItemCooldown	
local GetInventoryItemID 		= GetInventoryItemID
local GetItemSpell 				= type(GetItemSpell)=="function"			and GetItemSpell 			or C_Item.GetItemSpell 
local GetItemCooldown			= type(GetItemCooldown)=="function"			and GetItemCooldown			or C_Item.GetItemCooldown
local GetContainerNumSlots 		= type(GetContainerNumSlots)=="function" 	and GetContainerNumSlots	or C_Container.GetContainerNumSlots
local GetContainerItemID 		= type(GetContainerItemID) == "function"  	and GetContainerItemID		or C_Container.GetContainerItemID

-- WOW API : Specialization   
local GetSpecialization 		= GetSpecialization 	and GetSpecialization 		or C_SpecializationInfo.GetSpecialization
local GetSpecializationInfo 	= GetSpecializationInfo	and GetSpecializationInfo 	or C_SpecializationInfo.GetSpecializationInfo
local GetActiveSpecGroup		= GetActiveSpecGroup	and GetActiveSpecGroup 		or C_SpecializationInfo.GetActiveSpecGroup
	
-- WOW API : ShapeshiftForm
local GetShapeshiftForm = GetShapeshiftForm
local GetShapeshiftFormID = GetShapeshiftFormID

-- WOW API : Spell
local GetSpellCharges 	= type(GetSpellCharges)=="function" 	and GetSpellCharges 	or C_Spell.GetSpellCharges
local GetSpellCooldown 	= type(GetSpellCooldown)=="function" 	and GetSpellCooldown 	or C_Spell.GetSpellCooldown
local GetSpellInfo 		= type(GetSpellInfo)=="function"		and GetSpellInfo 		or C_Spell.GetSpellInfo
local GetSpellLink 		= type(GetSpellLink)=="function"		and GetSpellLink 		or C_Spell.GetSpellLink
local GetSpellTexture 	= type(GetSpellTexture)=="function"		and GetSpellTexture 	or C_Spell.GetSpellTexture
local IsUsableSpell 	= type(IsUsableSpell)=="function"		and IsUsableSpell		or C_Spell.IsSpellUsable

local GetTotemInfo 		= GetTotemInfo
-- WOW API : Group
local GetNumSubgroupMembers = GetNumSubgroupMembers
-- WOW API : Widget
local UIParent = UIParent
local GameTooltip = GameTooltip
local UIFrameFadeIn = UIFrameFadeIn
local UIFrameFadeOut = UIFrameFadeOut
-- WOW API : System
local RegisterAllEvents = RegisterAllEvents
local RegisterEvent = RegisterEvent
local PlaySoundFile = PlaySoundFile

------------------------------------------------------------------
---
------------------------------------------------------------------
EA_SpecPower = {
				Mana 			= 	{
									powerId = Enum.PowerType.Mana,
									powerType = "MANA",									
									func = G.UpdateSinglePower,									
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.Mana},
									
									},
				Rage 			= 	{										    
									powerId = Enum.PowerType.Rage,
									powerType = "RAGE",
									func = G.UpdateSinglePower,									
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.Rage},
									},
				Focus 			= 	{
									powerId = Enum.PowerType.Focus,
									powerType = "FOCUS",
									--func=G:UpdateSinglePower,									
									func = G.UpdateFocus,
									has,
									frameindex = {
										1000000 + 10 * Enum.PowerType.Focus, 
										1000000 + 10 * Enum.PowerType.Focus + 1,
										},
									},
				Energy	 		= 	{
									powerId = Enum.PowerType.Energy,
									powerType = "ENERGY",
									func = G.UpdateSinglePower,
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.Energy},
									},
				-- Happiness	 		= 	{
									-- powerId = Enum.PowerType.Happiness,
									-- powerType = "HAPPINESS",
									-- func = G.UpdateSinglePower,
									-- has,
									-- frameindex = {1000000 + 10 * Enum.PowerType.Happiness},
									-- },
				ComboPoints		=   {
									powerId = Enum.PowerType.ComboPoints,
									powerType = "COMBO_POINTS",
									func = G.UpdateComboPoints,
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.ComboPoints},
									--frameindex = {1000000},
									},		
				Runes 			= 	{
									powerId = Enum.PowerType.Runes,
									powerType = "RUNES",
									func = G.UpdateRunes,									
									--func = G.UpdateSinglePower,
									has,
									frameindex={
												[0] = 1000000 + 10 * Enum.PowerType.Runes + 0,
												[1] = 1000000 + 10 * Enum.PowerType.Runes + 1,
												[2] = 1000000 + 10 * Enum.PowerType.Runes + 2,
												[3] = 1000000 + 10 * Enum.PowerType.Runes + 3,
												[4] = 1000000 + 10 * Enum.PowerType.Runes + 4,
												[5] = 1000000 + 10 * Enum.PowerType.Runes + 5,
												[6] = 1000000 + 10 * Enum.PowerType.Runes + 6,												
												},									
									},
				RunicPower		= 	{
									powerId = Enum.PowerType.RunicPower,
									powerType = "RUNIC_POWER",
									func = G.UpdateSinglePower,									
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.RunicPower},
									},
				SoulShards		= 	{
									powerId = Enum.PowerType.SoulShards,
									powerType = "SOUL_SHARDS",
									func = G.UpdateSinglePower,									
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.SoulShards},
									},
				LunarPower			= 	{
									powerId = Enum.PowerType.LunarPower,									
									powerType = "LUNAR_POWER",
									func = G.UpdateSinglePower,									
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.LunarPower},
									},
				HolyPower		= 	{
									powerId = Enum.PowerType.HolyPower,
									powerType = "HOLY_POWER",
									func = G.UpdateSinglePower,									
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.HolyPower},
									},
				Maelstrom		= 	{
									powerId = Enum.PowerType.Maelstrom,
									powerType = "MAELSTROM",
									func = G.UpdateSinglePower,									
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.Maelstrom},
									},
				Chi				= 	{
									powerId = Enum.PowerType.Chi,
									powerType = "CHI",
									func = G.UpdateSinglePower,
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.Chi},
									},
				Insanity		= 	{
									powerId = Enum.PowerType.Insanity,									
									powerType = "INSANITY",
									func = G.UpdateSinglePower,									
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.Insanity},
									},
				ArcaneCharges		= 	{
									powerId = Enum.PowerType.ArcaneCharges,
									powerType = "ARCANE_CHARGES",
									func = G.UpdateSinglePower,									
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.ArcaneCharges},
									},			
				Fury			= 	{
									powerId = Enum.PowerType.Fury,
									powerType = "FURY",
									func = G.UpdateSinglePower,									
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.Fury},
									},
				Pain			= 	{
									powerId = Enum.PowerType.Pain,
									powerType = "PAIN",
									func=G.UpdateSinglePower,									
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.Pain},
									},		
				Essence			= 	{
									powerId = Enum.PowerType.Essence,
									powerType = "ESSENCE",
									func=G.UpdateSinglePower,									
									has,
									frameindex = {1000000 + 10 * Enum.PowerType.Essence},
									},											
				Vigor			= 	{
									powerId,
									powerType = "",
									func = G.UpdateVigor,									
									has,
									frameindex = {362777},
									},
									
				LifeBloom		= 	{
									powerId,
									powerType = "",
									func = G.UpdateLifeBloom,									
									has,
									frameindex = {33763},
									},
									
				}


-----------------------------------------------------------------
-- Speciall Frame: UpdateComboPoint, for watching the combopoint of player
-----------------------------------------------------------------
function G:UpdateComboPoints()	

	if G.EA_flagAllHidden == true then 
		EA_Main_Frame:SetAlpha(0) 
		return 
	else
		EA_Main_Frame:SetAlpha(1) 
	end
	--EA_COMBO_POINTS = UnitPower("player",EA_SPELL_POWER_COMBO_POINT)
	G.COMBO_POINTS = UnitPower("player",Enum.PowerType.ComboPoints)
	local iComboPoint = G.COMBO_POINTS
	if (EA_Config.ShowFrame == true) then
		EA_Main_Frame:ClearAllPoints()
		EA_Main_Frame:SetPoint(EA_Position.Anchor, UIParent, EA_Position.relativePoint, EA_Position.xLoc, EA_Position.yLoc)
		local prevFrame = "EA_Main_Frame"
		local xOffset = 100 + EA_Position.xOffset
		local yOffset = 0 + EA_Position.yOffset
		local SfontName, SfontSize = "", 0
		local eaf = _G["EAFrameSpec_"..(EA_SpecPower.ComboPoints.frameindex[1])]
		if (eaf ~= nil) then
			if (iComboPoint > 0) then
				G.SpecFrame_Target = true
				eaf:ClearAllPoints()
				--eaf:SetPoint(EA_Position.TarAnchor, UIParent, EA_Position.TarAnchor, EA_Position.Tar_xOffset - xOffset * 1, EA_Position.Tar_yOffset - yOffset)
				if (EA_SpecPower.LunarPower.has and EA_Config.SpecPowerCheck.LunarPower) then
					eaf:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -4 * xOffset,  0 * yOffset)
				else
					eaf:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -1 * xOffset,  0 * yOffset)
				end
				if (EA_Config.ShowName) then
					eaf.spellName:SetText(EA_SPELL_POWER_NAME.ComboPoints)
					--eaf.spellName:SetText(EA_XSPECINFO_COMBOPOINT)
					SfontName, SfontSize = eaf.spellName:GetFont()
					eaf.spellName:SetFont(SfontName, EA_Config.SNameFontSize)
				else
					eaf.spellName:SetText("")
				end
				--G:EAFun_SetCountdownStackText(eaf, iComboPoint, 0, -1)
				G:EAFun_SetCountdownStackText(eaf, iComboPoint, 0, -1)
				eaf:Show()
				-- for 7.0 依據盜賊天賦決定連擊點高亮值
				local ComboPointMax = UnitPowerMax("player",Enum.PowerType.ComboPoints)				
				local GlowComboPoint = ComboPointMax 				
				--G:FrameGlowShowOrHide(eaf,(iComboPoint >= GlowComboPoint))
				G:FrameGlowShowOrHide(eaf,(iComboPoint >= GlowComboPoint))
			else
				G:FrameGlowShowOrHide(eaf, false)
				G.SpecFrame_Target = false
				eaf:Hide()
			end
			-- G:TarPositionFrames()
		end
	end
end

-----------------------------------------------------------------
--
-----------------------------------------------------------------
function G:UpdateFocus()
	local iPowerType = Enum.PowerType.Focus
	local iUnitPower = UnitPower("player", iPowerType)
	local iPetPower = UnitPower("pet", iPowerType)
	if (EA_Config.ShowFrame == true) then
		EA_Main_Frame:ClearAllPoints()
		EA_Main_Frame:SetPoint(EA_Position.Anchor, UIParent, EA_Position.relativePoint, EA_Position.xLoc, EA_Position.yLoc)
		local prevFrame = "EA_Main_Frame"
		local xOffset = 100 + EA_Position.xOffset
		local yOffset = 0 + EA_Position.yOffset
		local SfontName, SfontSize = "", 0
		--local eaf1 = _G["EAFrameSpec_1000020"]
		--local eaf2 = _G["EAFrameSpec_1000021"]
		local eaf1 = _G["EAFrameSpec_"..EA_SpecPower.Focus.frameindex[1]]
		local eaf2 = _G["EAFrameSpec_"..EA_SpecPower.Focus.frameindex[2]]
		G.SpecFrame_Self = true
			if (eaf1 ~= nil) and (EA_Config.SpecPowerCheck.Focus) and (iUnitPower > 0) then
				eaf1:ClearAllPoints()
				eaf1:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -1 * xOffset, -1 * yOffset)
				if (EA_Config.ShowName == true) then
					eaf1.spellName:SetText(EA_SPELL_POWER_NAME.Focus)
					SfontName, SfontSize = eaf1.spellName:GetFont()
					if SfontSize ~= EA_Config.SNameFontSize then 
						eaf1.spellName:SetFont(SfontName, EA_Config.SNameFontSize)
					end
				else
					eaf1.spellName:SetText("")
				end
				eaf1.spellTimer:ClearAllPoints()
				if (EA_Config.ChangeTimer == true) then
					eaf1.spellTimer:SetPoint("CENTER", eaf2,"CENTER", 0, 0)
				else
					eaf1.spellTimer:SetPoint("BOTTOM",eaf2, "TOP", 0, 0)
				end
				local fontName, fontSize = eaf1.spellTimer:GetFont()
				if fontName ~= G.FONTS or fontSize ~= EA_Config.TimerFontSize then 					
					eaf1.spellTimer:SetFont(G.FONTS, EA_Config.TimerFontSize, "OUTLINE")
				end
				eaf1.spellTimer:SetFont(G.FONTS, EA_Config.TimerFontSize, "OUTLINE")
				eaf1.spellTimer:SetText(iUnitPower)		
				eaf1:Show()
			else
				if eaf1 then
					G:FrameGlowShowOrHide(eaf1, false)
					G.SpecFrame_Self = false					
					eaf1:Hide()
				end
			end		
			if (eaf2 ~= nil) and (EA_Config.SpecPowerCheck.FocusPet) and (iPetPower > 0) then
				eaf2:ClearAllPoints()
				eaf2:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -2 * xOffset, -1 * yOffset)
				if (EA_Config.ShowName == true) then
					eaf2.spellName:SetText(EA_SPELL_POWER_NAME.FocusPet)
					SfontName, SfontSize = eaf2.spellName:GetFont()
					if SfontSize ~= EA_Config.SNameFontSize then 
						eaf2.spellName:SetFont(SfontName, EA_Config.SNameFontSize)
					end
				else
					eaf2.spellName:SetText("")
				end
				eaf2.spellTimer:ClearAllPoints()
				if (EA_Config.ChangeTimer == true) then
					eaf2.spellTimer:SetPoint("CENTER", eaf2,"CENTER", 0, 0)
				else
					eaf2.spellTimer:SetPoint("BOTTOM",eaf2, "TOP", 0, 0)
				end
				
				local fontName, fontSize = eaf2.spellTimer:GetFont()
				if fontName ~= G.FONTS or fontSize ~= EA_Config.TimerFontSize then 					
					eaf2.spellTimer:SetFont(G.FONTS, EA_Config.TimerFontSize, "OUTLINE")					
				end
				
				eaf2.spellTimer:SetText(iPetPower)	
				G:FrameGlowShowOrHide(eaf2, iPetPower >= EA_Config.HUNTER_GlowPetFocus)
				eaf2:Show()				
			else
				if eaf2 then
					G:FrameGlowShowOrHide(eaf2, false)
					G.SpecFrame_Self = false					
					eaf2:Hide()
				end
			end							
	end
end

function G:HideRunesBar()
	local f 
	for i = 1, G.MAX_RUNES do
		f = _G["EAFrameSpec_"..EA_SpecPower.Runes.frameindex[i] ]
		if f and f:IsShown() then f:Hide() end
	end
end
-----------------------------------------------------------------
-- Speciall Frame: Update Runes
-----------------------------------------------------------------
function G:UpdateRunes()		
	
	if (G.playerClass ~= EA_CLASS_DK) then return end
	if not(EA_Config.SpecPowerCheck.Runes) then return end
	if not(EA_SpecPower.Runes.has) then return end
	
	G:UpdateSinglePower(Enum.PowerType.Runes)
	
	if EA_Config.ShowRunesBar == false then return end
	if (EA_Config.ShowFrame == true) then
		EA_Main_Frame:ClearAllPoints()
		EA_Main_Frame:SetPoint(EA_Position.Anchor, UIParent, EA_Position.relativePoint, EA_Position.xLoc, EA_Position.yLoc)
		local prevFrame = "EA_Main_Frame"
		local xOffset = 100 + EA_Position.xOffset
		local yOffset =  EA_Position.yOffset
		local SfontName, SfontSize = "", 0
		local eaf={}
		G.SpecFrame_Self = true
		local RunesFrame = EA_SpecPower.Runes.frameindex
		local IconSize = EA_Config.IconSize
		local TimerFontSize = EA_Config.TimerFontSize
		local GetRuneCooldown = GetRuneCooldown
		local GetTime = GetTime
		for i = 1, G.MAX_RUNES do
		
			eaf[i]=_G["EAFrameSpec_"..RunesFrame[i]]
			if not(eaf[i]) then
				G:CreateFrames_SpecialFrames_Show(RunesFrame[i])
				eaf[i] = _G["EAFrameSpec_"..RunesFrame[i]]
			end
			if eaf[i] then
				eaf[i]:SetWidth(IconSize * 0.8)
				eaf[i]:SetHeight(IconSize * 0.8)
				if (eaf[i]:IsShown() == false)  then							
					eaf[i]:Show()
				end			
			end	
			--slot=RUNE_MAPPING[i]
			slot = i
			--iRuneType = tonumber(GetRuneType(slot))
			iRuneType = G.RUNE_TYPE
			if (iRuneType >= 1) and (iRuneType < 4 ) then
				--eaf[i]:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, (i-G.MAX_RUNES-3) * xOffset * 0.6, (i-G.MAX_RUNES-3) * yOffset*0.6)
				eaf[i]:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, (IconSize+(i-2) * -xOffset*0.6), 1*(IconSize+(i-2) * yOffset*0.6))
				--if eaf[i].Backdrop == nil then 
					--Lib_ZYF:SetBackdrop(eaf[i],{bgFile=iconTextures[iRuneType]})
				--end
				eaf[i].texture:SetTexture(1630812)
				local coord
				-- if GetSpecialization then
				
				if G.WOW_VERSION >= 800000 then
					coord = G.runeSetTexCoord[GetSpecialization()]
				else
					iRuneType = tonumber(GetRuneType(slot))
					coord = G.runeSetTexCoord[iRuneType]
				end
				eaf[i].texture:SetTexCoord(coord.minX, coord.maxX, coord.minY, coord.maxY)	
				if (EA_Config.ShowName==true) then					
					--eaf[i].spellName:SetText(runeTypeText[iRuneType])
					--SfontName, SfontSize = eaf[i].spellName:GetFont()
					--eaf[i].spellName:SetFont(SfontName, EA_Config.SNameFontSize*0.8)
				else
					eaf[i].spellName:SetText("")
				end			
				eaf[i].spellTimer:ClearAllPoints()
				
				if (EA_Config.ChangeTimer == true) then
					eaf[i].spellTimer:SetPoint("CENTER", eaf[i], "CENTER", 0, 0)
					eaf[i].spellTimer:SetFont(G.FONTS, 0.8 * EA_Config.TimerFontSize, "OUTLINE")
				else
					eaf[i].spellTimer:SetPoint("BOTTOM", eaf[i], "TOP", 0, 0)
					eaf[i].spellTimer:SetFont(G.FONTS, 0.9 * EA_Config.TimerFontSize, "OUTLINE")
				end
				
				local EA_start, EA_duration, runeReady = GetRuneCooldown(i)
				local EA_timeLeft
				if not(EA_start) then return end
				--if not(EA_start) then break end
				if (runeReady) then
					EA_timeLeft = 0
				else
					EA_timeLeft = EA_start + EA_duration - GetTime()	
				end
				if (EA_timeLeft > EA_duration) then EA_timeLeft = EA_duration end
				--if (start>0) then
				if (EA_timeLeft > 0) then					
					G:EAFun_SetCountdownStackText(eaf[i], EA_timeLeft, 0, -1)
				else
					G:EAFun_SetCountdownStackText(eaf[i], 0, 0, -1)
				end			
				--[[
				if not(eaf[i]:HasScript("OnUpdate")) then 
					eaf[i]:SetScript("OnUpdate", function(self,elapsedTime)
					G:TimeSinceUpdate_Runes = G:TimeSinceUpdate_Runes + elapsedTime
					if G:TimeSinceUpdate_Runes > G:UpdateInterval then
						G:UpdateRunes()
						G:TimeSinceUpdate_Runes = 0
					end
					end)
					--eaf[i]:SetScript("OnUpdate",G:UpdateRunes)
				end	
				]]--
				if eaf[i] and (eaf[i]:IsShown()==false) then
					eaf[i]:Show()
				end
				--G:PositionFrames()
			end
			
			
			--若脫戰則隱藏符文框架
			if not InCombatLockdown() then	
				eaf[i]:Hide()
			else
				eaf[i]:Show()
			end		
		end
	end	
end

-----------------------------------------------------------------
-- Speciall Frame: UpdateSinglePower(holy power, runic power, soul shards), for watching the power of player
-----------------------------------------------------------------
function G:UpdateSinglePower(iPowerType)

	if iPowerType == nil then return end
	
	if G.EA_flagAllHidden == true then 
		EA_Main_Frame:SetAlpha(0) 
		return 
	else
		EA_Main_Frame:SetAlpha(1) 
	end                    
	
	local unit = "player"
	local _, playerClass = UnitClass(unit)
	local iUnitPower = UnitPower(unit, iPowerType)	
	--local iUnitPowerPet = UnitPower("pet", iPowerType)	
	local iPowerName = ""
	local iFrameIndex = 1000000 + iPowerType * 10	
	for i,v in ipairs(EA_XGRPALERT_POWERTYPES) do
		if iPowerType == v.value then
			iPowerName = v.text
			if GetSpecialization and iPowerType == Enum.PowerType.Runes then				
				local powerName = select(2, GetSpecializationInfo(GetSpecialization()))
				iPowerName = (powerName or "")..iPowerName
			end
			break			
		end
	end
	
	if (EA_Config.ShowFrame == true) then
		EA_Main_Frame:ClearAllPoints()
		EA_Main_Frame:SetPoint(EA_Position.Anchor, UIParent, EA_Position.relativePoint, EA_Position.xLoc, EA_Position.yLoc)
		local prevFrame = "EA_Main_Frame"
		--local xOffset = 100 + EA_Position.xOffset
		local xOffset = 100 + EA_Position.xOffset
		local yOffset = 0 + EA_Position.yOffset
		local SfontName, SfontSize = "", 0
		
		local eaf = _G["EAFrameSpec_"..iFrameIndex]	
		if (eaf ~= nil) then
		
			--若字體大小已與原本一樣就不要再SetFont, 避免性能消耗
			SfontName, SfontSize = eaf.spellName:GetFont()
			if SfontSize ~= EA_Config.SNameFontSize then 
				eaf.spellName:SetFont(SfontName, EA_Config.SNameFontSize)
			end
			
			--若有啟用技能名稱才顯示特殊能量名稱
			if (EA_Config.ShowName == true) then
				eaf.spellName:SetText(iPowerName) 				
			else
				eaf.spellName:SetText("")
			end  		
			
			--術士靈魂碎片數量處理
			if (iPowerType == Enum.PowerType.SoulShards) then						
				iUnitPower=UnitPower(unit, Enum.PowerType.SoulShards, true)/10
			end
			
			--DK符文數量處理
			if (iPowerType == Enum.PowerType.Runes) then
				iUnitPower = 0 
				for i = 1, G.MAX_RUNES do
					local start, duration, runeReady = GetRuneCooldown(i)					
					if runeReady then iUnitPower = iUnitPower + 1 end
				end
			end
			
			if (iUnitPower > 0) then
				G.SpecFrame_Self = true
				--eaf:ClearAllPoints()
				
				--能量框架位置設定
				if (iPowerType == Enum.PowerType.Energy) then		
					if (G.playerClass == EA_CLASS_ROGUE) then
						eaf:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -2 * xOffset, -2 * yOffset)																						
					else
						eaf:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -2 * xOffset, -2 * yOffset)																						
					end
				else
					eaf:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -1   * xOffset, -1 * yOffset)
					if (EA_SpecPower.Energy.has and EA_Config.SpecPowerCheck.Energy) then
						iFrameIndex2 = 1000000 + 10 * Enum.PowerType.Energy 
						eaf2 = _G["EAFrameSpec_"..iFrameIndex2]
						eaf2:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -2 * xOffset, -2 * yOffset)
					end
				end
				
				--星能框架位置設定
				if (iPowerType == Enum.PowerType.LunarPower) then
					eaf:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -1 * xOffset, -1 * yOffset)																						
				end  				
				
				--符文框架位置設定
				if (iPowerType == Enum.PowerType.Runes ) then
					local coord
					if GetSpecialization then
						coord = G.runeSetTexCoord[GetSpecialization()]						
					else
						coord = G.runeSetTexCoord[GetShapeshiftForm()]												
					end
					if coord then
						eaf.texture:SetTexCoord(coord.minX, coord.maxX, coord.minY, coord.maxY)	
					
						eaf:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -2 * xOffset, -2 * yOffset)	
					end
				end	
				
				--龍能框架位置設定
				if (iPowerType == Enum.PowerType.Essence ) then
					eaf:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -2 * xOffset, -2 * yOffset)						
				end	
				
				--法力增加百分比顯示  					
				local ManaScale = 1
				if (iPowerType == Enum.PowerType.Mana) then	
					ManaScale = 0.8
					if EA_Config.ShowName == true then 
						SfontName, SfontSize = eaf.spellName:GetFont()
						if SfontSize ~= EA_Config.SNameFontSize then 
							eaf.spellName:SetFont(SfontName, EA_Config.SNameFontSize)
						end
						eaf.spellName:SetFormattedText("%s\n(%d%%)",iPowerName, iUnitPower/UnitPowerMax(unit, Enum.PowerType.Mana) * 100)
					else
						eaf.spellName:SetText("")
					end
					
					local fontName, fontSize = eaf.spellTimer:GetFont()
					if fontSize ~= EA_Config.TimerFontSize then 
						eaf.spellTimer:SetFont(fontName, EA_Config.TimerFontSize * ManaScale, "OUTLINE")
					end
					
					eaf.spellTimer:ClearAllPoints()
					if (EA_Config.ChangeTimer == true) then
						eaf.spellTimer:SetPoint("CENTER", eaf,"CENTER", 0, 0)
					else
						eaf.spellTimer:SetPoint("BOTTOM",eaf, "TOP", 0, 0)
					end     
					
					
				else                    					
					eaf.spellName:SetText(iPowerName)												
				end	
				
				--若能量值超過10000就轉為K數顯示
				if iUnitPower > 10000 then 
					eaf.spellTimer:SetFormattedText("%dK", iUnitPower/1000)
					-- eaf.spellTimer:SetText(format("%dK",iUnitPower/1000))
				else
					eaf.spellTimer:SetText(iUnitPower)
				end
				
				eaf:Show()
				
				-- 能量達到指定高亮				
				if (iPowerType == Enum.PowerType.Energy) then
					
					--德魯伊兇猛撕咬50能量傷害最大化
					if playerClass == EA_CLASS_DRUID then 
						G:FrameGlowShowOrHide(eaf, (iUnitPower >= 50 ))
					end
					if playerClass == EA_CLASS_ROGUE then 
						G:FrameGlowShowOrHide(eaf, (iUnitPower >= 50 ))
					end
					
					if playerClass == EA_CLASS_MONK then 
						G:FrameGlowShowOrHide(eaf, (iUnitPower >= 50 ))
					end
				end
				
				-- 怒氣達到上限高亮				
				if (iPowerType == Enum.PowerType.Rage) then
					--若為戰士
					if (playerClass == EA_CLASS_WARRIOR) then						
						--若專精為狂怒表示有暴怒技能,80需求值高亮
						if GetSpecialization and (GetSpecialization() == 2) then														
							G:FrameGlowShowOrHide(eaf, (iUnitPower >= 80 ))							
						end
						--若為武器專精則以斬殺最高需求值40高亮
						if GetSpecialization and  (GetSpecialization() == 1) then
							--G:FrameGlowShowOrHide(eaf, (iUnitPower >= UnitPowerMax(unit, Enum.PowerType.Rage)))
							G:FrameGlowShowOrHide(eaf, (iUnitPower >= 40))
						end
						--若為防護專精則以無視苦痛需求值40高亮
						if GetSpecialization and  (GetSpecialization() == 3) then
							--G:FrameGlowShowOrHide(eaf, (iUnitPower >=UnitPowerMax(unit, Enum.PowerType.Rage)))					
							G:FrameGlowShowOrHide(eaf, (iUnitPower >= 40 ))					
						end						
					else
						G:FrameGlowShowOrHide(eaf, (iUnitPower >=UnitPowerMax(unit, Enum.PowerType.Rage)))
					end					
					if (playerClass == EA_CLASS_DRUID) then
						eaf:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -3 * xOffset, -3 * yOffset)	
					end
				end
				
				-- 法力達到上限高亮
				if (iPowerType == Enum.PowerType.Mana) then					
					G:FrameGlowShowOrHide(eaf, (iUnitPower >= UnitPowerMax(unit, Enum.PowerType.Mana)))					
				end
				
				-- 聖騎聖能達到上限高亮
				if (iPowerType == Enum.PowerType.HolyPower) then
					G:FrameGlowShowOrHide(eaf, (iUnitPower >= UnitPowerMax(unit, Enum.PowerType.HolyPower)))					
				end
				
				-- 暗牧瘋狂值達到瘟疫50需求值高亮
				if (iPowerType == Enum.PowerType.Insanity) then														
					--G:FrameGlowShowOrHide(eaf,(iUnitPower >= UnitPowerMax(unit,Enum.PowerType.Insanity)))
					G:FrameGlowShowOrHide(eaf,(iUnitPower >= 50))					
				end
				
				--武僧真氣滿上限高亮				
				if (iPowerType == Enum.PowerType.Chi) then					
					G:FrameGlowShowOrHide(eaf,(iUnitPower >= UnitPowerMax(unit, Enum.PowerType.Chi)))				
					--G:FrameGlowShowOrHide(eaf,(iUnitPower >= 4))				
				end
				
				--死騎符能達到上限高亮
				if (iPowerType == Enum.PowerType.RunicPower) then					
					G:FrameGlowShowOrHide(eaf,(iUnitPower >= UnitPowerMax(unit, Enum.PowerType.RunicPower)))				
				end
				
				--死騎符文達到上限高亮
				if (iPowerType == Enum.PowerType.Runes) then					
					G:FrameGlowShowOrHide(eaf,(iUnitPower >= G.MAX_RUNES))				
				end
				
				--術士靈魂碎片達到上限高亮
				if (iPowerType == Enum.PowerType.SoulShards) then						
					G:FrameGlowShowOrHide(eaf,(iUnitPower >= UnitPowerMax(unit, Enum.PowerType.SoulShards)))
				end
				
				--秘法充能達到上限高亮
				if (iPowerType == Enum.PowerType.ArcaneCharges) then					
					G:FrameGlowShowOrHide(eaf,(iUnitPower >= UnitPowerMax(unit, Enum.PowerType.ArcaneCharges)))				
				end
				
				--星能達到星隕術需求就高亮
				if (iPowerType == Enum.PowerType.LunarPower) then
					G:FrameGlowShowOrHide(eaf,(iUnitPower >= 50))
					--G:FrameGlowShowOrHide(eaf,(iUnitPower >=UnitPowerMax(unit, Enum.PowerType.LunarPower)))				
				end
				
				--增強薩、元素薩元能達到上限高亮
				if (iPowerType == Enum.PowerType.Maelstrom) then
					G:FrameGlowShowOrHide(eaf,(iUnitPower >= UnitPowerMax(unit, Enum.PowerType.Maelstrom)))				
				end
				
				--惡魔獵人魔怒達到上限高亮
				if (iPowerType == Enum.PowerType.Fury) then						
					G:FrameGlowShowOrHide(eaf,(iUnitPower >= UnitPowerMax(unit, Enum.PowerType.Fury)))
				end
				
				--惡魔獵人魔痛達到上限高亮
				-- if (iPowerType == Enum.PowerType.Pain) then						
					-- G:FrameGlowShowOrHide(eaf,(iUnitPower >= UnitPowerMax(unit, Enum.PowerType.Pain)))
				-- end
				
				--喚能師"龍能"達到上限高亮
				if (iPowerType == Enum.PowerType.Essence) then						
					G:FrameGlowShowOrHide(eaf,(iUnitPower >= UnitPowerMax(unit, Enum.PowerType.Essence)))
				end
				
			else
				G:FrameGlowShowOrHide(eaf, false)				
				G.SpecFrame_Self = false
				eaf:Hide()
			end
			--G:PositionFrames()
		end
	end
end
-----------------------------------------------------------------
-- Speciall Frame: UpdateLifeBloom & OnLifeBloomUpdate, for watching the currently(max-stack) lifebloom of player
-----------------------------------------------------------------
function G:OnLifeBloomUpdate()
	local iFrameIndex = 33763
	local eaf = _G["EAFrameSpec_"..iFrameIndex]
	if (eaf ~= nil) then
		local EA_timeLeft = 0
		if (G.SpecFrame_LifeBloom.ExpireTime ~= nil) then
			EA_timeLeft = G.SpecFrame_LifeBloom.ExpireTime - GetTime()
		end
		if (EA_timeLeft > 0) then
			if (EA_Config.ShowTimer) then
				G:EAFun_SetCountdownStackText(eaf, EA_timeLeft, G.SpecFrame_LifeBloom.Stack, -1)
				if EA_timeLeft < 4 then
				 	eaf.spellTimer:SetFont(G.FONTS, EA_Config.TimerFontSize+5, "OUTLINE")
					eaf.spellTimer:SetTextColor(1, 0, 0)
				else
				 	eaf.spellTimer:SetFont(G.FONTS, EA_Config.TimerFontSize, "OUTLINE")
					eaf.spellTimer:SetTextColor(1, 1, 1)
				end
			end
		else
			G.SpecFrame_LifeBloom.UnitID = ""
			G.SpecFrame_LifeBloom.UnitName = ""
			G.SpecFrame_LifeBloom.ExpireTime = 0
			G.SpecFrame_LifeBloom.Stack = 0
			EA_SpecFrame_Self = false
			-- eaf:SetScript("OnUpdate", nil)
			Lib_ZYF:StopOnUpdate(eaf)
			if eaf:IsVisible() then eaf:Hide() end
			--G:PositionFrames()
		end
	end
end

-----------------------------------------------------------------
-- 更新生命之花
-----------------------------------------------------------------
function G:UpdateLifeBloom(EA_Unit)
	local iFrameIndex = 33763
	local fNewToShow = false
	local eaf = _G["EAFrameSpec_"..iFrameIndex]
	if (eaf ~= nil) then
		if (EA_Unit ~= "") then
			if (EA_Config.ShowFrame == true) then
				EA_Main_Frame:ClearAllPoints()
				EA_Main_Frame:SetPoint(EA_Position.Anchor, UIParent, EA_Position.relativePoint, EA_Position.xLoc, EA_Position.yLoc)
				local prevFrame = "EA_Main_Frame"
				local xOffset = 100 + EA_Position.xOffset
				local yOffset = 0 + EA_Position.yOffset
				local SfontName, SfontSize = "", 0
				local infoBuff 
				for i=1, 40 do
					local auraData = UnitBuff(EA_Unit, i)
					if type(auraData)=="table" then 					
						local count 			= auraData.applications
						local expirationTime 	= auraData.expirationTime
						local unitCaster 		= auraData.sourceUnit
						local spellId 			= auraData.spellId
					else
						local _,  _, count, _, _, expirationTime, unitCaster, _, _, spellId = UnitBuff(EA_Unit, i)
					end
					
					if (not spellId) then
						break
					end
					if (spellId == iFrameIndex) and (unitCaster == "player") then
						local iShiftFormID = GetShapeshiftFormID()
						fNewToShow = false
						if (iShiftFormID == nil) then
							fNewToShow = true	-- Non-Lift of tree, single lifebloom
						elseif (iShiftFormID == 2) then -- Life of tree form, multi lifebloom
							if (count > G.SpecFrame_LifeBloom.Stack) then
								fNewToShow = true
							elseif (count == G.SpecFrame_LifeBloom.Stack and expirationTime >= G.SpecFrame_LifeBloom.ExpireTime) then
								fNewToShow = true
							end
						end
						if (fNewToShow) then
							G.SpecFrame_LifeBloom.UnitID = EA_Unit
							G.SpecFrame_LifeBloom.UnitName = UnitName(EA_Unit)
							G.SpecFrame_LifeBloom.ExpireTime = expirationTime
							G.SpecFrame_LifeBloom.Stack = count
						end
						break
					end
				end
				if (fNewToShow) then
					G.SpecFrame_Self = true
					eaf:ClearAllPoints()
					eaf:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -1 * xOffset, -1 * yOffset)
					eaf:SetWidth(EA_Config.IconSize)
					eaf:SetHeight(EA_Config.IconSize)
					if (EA_Config.ShowName == true) then
						eaf.spellName:SetText(G.SpecFrame_LifeBloom.UnitName)
						SfontName, SfontSize = eaf.spellName:GetFont()
						eaf.spellName:SetFont(SfontName, EA_Config.SNameFontSize)
					else
						eaf.spellName:SetText("")
					end
					
					-- Lib_ZYF:FrameSetOnUpdate(eaf, G.UpdateInterval, G.OnLifeBloomUpdate)
					if eaf.spellTimer:GetText() and eaf.spellTimer:GetText() * 1 <= 1 then					
						-- Lib_ZYF:FrameSetOnUpdateOnce(eaf, G.UpdateInterval / 10 , G.OnLifeBloomUpdate)
						C_Timer.After(G.UpdateInterval / 11 , G.OnLifeBloomUpdate)
					else
						-- Lib_ZYF:FrameSetOnUpdateOnce(eaf, G.UpdateInterVal , G.OnLifeBloomUpdate)
						C_Timer.After(G.UpdateInterval , G.OnLifeBloomUpdate)
					end
					
					-- eaf:SetScript("OnUpdate", function(self,elapsedTime)
					-- G:TimeSinceUpdate_LifeBloom =G:TimeSinceUpdate_LifeBloom + elapsedTime
					-- if G:TimeSinceUpdate_LifeBloom > G:UpdateInterval then
						-- G:OnLifeBloomUpdate()
						-- G:TimeSinceUpdate_LifeBloom = 0
					-- end
					-- end)
					
					if eaf:IsShown()==false then  eaf:Show() end
				end
				--G:PositionFrames()
			end
		else
			-- print ("fNewToShow = false 1")
			G.SpecFrame_LifeBloom.UnitID = ""
			G.SpecFrame_LifeBloom.UnitName = ""
			G.SpecFrame_LifeBloom.ExpireTime = 0
			G.SpecFrame_LifeBloom.Stack = 0
			G.SpecFrame_Self = false
			-- eaf:SetScript("OnUpdate", nil)
			-- Lib_ZYF:StopOnUpdate(eaf)
			if eaf:IsVisible() then eaf:Hide() end
			--G:PositionFrames()
		end
	end
end

-----------------------------------------------------------------
--Update Vigor(活力)
-----------------------------------------------------------------
function G:UpdateVigor(...)
	if ... == nil then return end 
	
	local vigor, vigorMax, vigorCount, vigorCountMax = ...
	
	if G.EA_flagAllHidden == true then 
		EA_Main_Frame:SetAlpha(0) 
		return 
	else
		EA_Main_Frame:SetAlpha(1) 
	end	
	
	if (EA_Config.ShowFrame == true) then
		EA_Main_Frame:ClearAllPoints()
		EA_Main_Frame:SetPoint(EA_Position.Anchor, UIParent, EA_Position.relativePoint, EA_Position.xLoc, EA_Position.yLoc)
		local prevFrame = "EA_Main_Frame"
		local xOffset = 100 + EA_Position.xOffset
		local yOffset = 0 + EA_Position.yOffset
		local SfontName, SfontSize = "", 0
		local eaf = _G["EAFrameSpec_".."362777"]				
		
		if (eaf ~= nil) then			
				
				eaf:ClearAllPoints()				
				eaf:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -4 * xOffset,  -4 * yOffset)
				
				if (EA_Config.ShowName) then
					--顯示活力名稱及最大值
					eaf.spellName:SetText(EA_SPELL_POWER_NAME.Vigor.."\n("..vigorCountMax..")")
					SfontName, SfontSize = eaf.spellName:GetFont()
					if SfontName ~= G.FONTS or SfontSize ~= EA_Config.SNameFontSize then 
						eaf.spellName:SetFont(SfontName, EA_Config.SNameFontSize)
					end
				else
					eaf.spellName:SetText("")
				end
				
				eaf.spellTimer:ClearAllPoints()
				eaf.spellStack:ClearAllPoints()
				if (EA_Config.ChangeTimer == true) then
				
					--活力值顯示於框架內  					
					eaf.spellTimer:SetPoint("CENTER"     , eaf, "CENTER"     ,0 , 0)
					--活力個數顯示於右下角
					eaf.spellStack:SetPoint("BOTTOMRIGHT", eaf, "BOTTOMRIGHT",-4 , 2)					
				
				else                                              
					--活力值顯示於框架外					
					eaf.spellTimer:SetPoint("BOTTOM",eaf, "TOP"   , 0, 0)
					--活力個數顯示於框架內中央
					eaf.spellStack:SetPoint("CENTER",eaf, "CENTER", 0, 0)     					
				end
				
				local fontName,fontSize = "",0
				fontName, fontSize = eaf.spellTimer:GetFont()
				if fontName ~= G.FONTS or fontSize ~= EA_Config.TimerFontSize then 
					eaf.spellTimer:SetFont(G.FONTS, EA_Config.TimerFontSize, "OUTLINE")
				end
				
				fontName, fontSize = eaf.spellStack:GetFont()
				if fontName ~= G.FONTS or fontSize ~= EA_Config.StackFontSize then 
					eaf.spellStack:SetFont(G.FONTS, EA_Config.StackFontSize, "OUTLINE")
				end
				
				--若為0則不顯示
				eaf.spellTimer:SetText((vigor 		> 0) and vigor	 	or "")
				eaf.spellStack:SetText((vigorCount 	> 0) and vigorCount or "")
				
				eaf:Show()
				
				--精力達到上限高亮
				G:FrameGlowShowOrHide(eaf, (vigorCount == vigorCountMax))
				
		end
	end
end


-----------------------------------------------------------------				
-- Death Knight 
-- 250 - Blood 血魄
-- 251 - Frost 冰霜
-- 252 - Unholy 穢邪
-- Druid 
-- 102 - Balance 平衡
-- 103 - Feral Combat 野性戰鬥
-- 104 - Guardian 守護者
-- 105 - Restoration 恢復
-- Hunter 
-- 253 - Beast Mastery 獸王
-- 254 - Marksmanship 射擊
-- 255 - Survival 生存
-- Mage 
-- 62 - Arcane 秘法
-- 63 - Fire 火焰
-- 64 - Frost 冰霜
-- Monk 
-- 268 - BrewMaster 釀酒(坦)
-- 269 - WindWalker 風行(近戰DD)
-- 270 - MistWeaver 織霧(治療)
-- Paladin 
-- 65 - Holy		 神聖
-- 66 - Protection	防護
-- 70 - Retribution 懲戒
-- Priest 
-- 256 Discipline 戒律
-- 257 Holy  神聖
-- 258 Shadow  暗影
-- Rogue 
-- 259 - Assassination 刺殺 
-- 260 - Combat 戰鬥
-- 261 - Subtlety 敏銳
-- Shaman 
-- 262 - Elemental 元素
-- 263 - Enhancement 增強
-- 264 - Restoration 恢復
-- Warlock 
-- 265 - Affliction 痛苦
-- 266 - Demonology 惡魔
-- 267 - Destruction 毀滅
-- Warrior
-- 71 - Arms 武器
-- 72 - Furry 狂暴
-- 73 - Protection 防護
-----------------------------------------------------------------				
--
-----------------------------------------------------------------				
function G:PlayerSpecPower_Update()
	local EA_SpecPower = EA_SpecPower
	local p,tblPower
	local pairs = pairs 
	for p,tblPower in pairs(EA_SpecPower) do
		if (tblPower) then
			tblPower.has = false
		end
	end
	--local id,_,_,icon,_,_ = GetSpecializationInfo(GetActiveSpecGroup())
	local id = 0
	local icon = "NONE"
	local powerType = 0
	local powerTypeString = "NONE"
	local pClass = "NONE"
	--取得當前職業專精索引(1~3或4)
	local CurrentSpecCode = GetSpecialization and GetSpecialization() 
	
	--若無職業專精索引表示尚未啟用任一專精
	--若有，則將此索引傳入GetSpecializationInfo()來取得全職業專精唯一代碼
	if CurrentSpecCode then id,_,_,icon,_,_ = GetSpecializationInfo(CurrentSpecCode) end
	
	--取得玩家當前形態的特殊資源
	powerType, powerTypeString = UnitPowerType("player")
	
	--取得玩家職業
	_, pClass = UnitClass("player")
	
	--取得玩家姿態或形態
	local shapeindex = GetShapeshiftForm()
	local shapeID = GetShapeshiftFormID()
	--若玩家為法師、牧師、術士、德魯伊、聖騎、薩滿表示有法力值
	if 	(pClass == EA_CLASS_MAGE) 		or
		(pClass == EA_CLASS_WARLOCK) 	or
		(pClass == EA_CLASS_DRUID)		or
		(pClass == EA_CLASS_PALADIN) 	or
		(pClass == EA_CLASS_PRIEST)		or
		(pClass == EA_CLASS_EVOKER) 	or
		(pClass == EA_CLASS_SHAMAN)		or
		--WOW 4.0開始獵人取消法力值, 以集中值代替
		(pClass == EA_CLASS_HUNTER and G.WOW_VERSION < 40000)
	then 
		EA_SpecPower.Mana.has = true 
	end
	
	--若玩家為獵人表示有快樂值
	-- if (pClass == EA_CLASS_HUNTER) then
		-- EA_SpecPower.Happiness.has = true
	-- end
	
	--若玩家為戰士表示有怒氣
	if (pClass == EA_CLASS_WARRIOR) then EA_SpecPower.Rage.has = true 	end
	
	--若玩家為德魯伊表示有怒氣
	if (pClass == EA_CLASS_DRUID) 	then EA_SpecPower.Rage.has = true	end
	
	--若玩家為獵人且版本大於等於4.0表示有集中值
	if (pClass == EA_CLASS_HUNTER and G.WOW_VERSION >= 40000) then	
		EA_SpecPower.Focus.has = true
	end
	--若玩家為盜賊表示有能量
	if (pClass == EA_CLASS_ROGUE) then 	EA_SpecPower.Energy.has = true end
	
	--若玩家為德魯伊表示有能量
	if (pClass == EA_CLASS_DRUID) then	EA_SpecPower.Energy.has = true	end
	
	--若玩家為風行武僧表示有能量
	if (pClass == EA_CLASS_MONK) then
		--釀酒或風行擁有能量條
		if (id == 268) or (id==269) then 
			EA_SpecPower.Energy.has = true
		else
			EA_SpecPower.Energy.has = false
		end
		--7.0只有風僧有真氣
		if (id == 269) then EA_SpecPower.Chi.has = true end
	end
	
	--若玩家為死騎，則表示有符文及符能
	if (pClass == EA_CLASS_DK) then
		EA_SpecPower.RunicPower.has = true
		EA_SpecPower.Runes.has = true
		if (id == 250 ) then G.RUNE_TYPE = G.RUNETYPE_BLOOD end
		if (id == 251 ) then G.RUNE_TYPE = G.RUNETYPE_FROST end
		if (id == 252 ) then G.RUNE_TYPE = G.RUNETYPE_UNHOLY end				
	end
	
	--7.0開始三系術士資源均統一為靈魂碎片
	if (id == 265) then  EA_SpecPower.SoulShards.has = true	end
	if (id == 266) then EA_SpecPower.SoulShards.has = true 	end
	if (id == 267) then EA_SpecPower.SoulShards.has = true 	end	
	
	--若玩家為德魯伊且專精是平衡，則表示有星能
	if (id == 102) then 
		EA_SpecPower.LunarPower.has = true
	end
	
	--若玩家為聖騎，則表示有聖能
	if (pClass == EA_CLASS_PALADIN) then 
		EA_SpecPower.HolyPower.has = true
	end
	
	--若玩家為盜賊表示擁有連擊點數
	if (pClass == EA_CLASS_ROGUE) then
		EA_SpecPower.ComboPoints.has = true
	end
	
	--若玩家為德魯伊表示擁有連擊點數
	if (pClass == EA_CLASS_DRUID) then
		EA_SpecPower.ComboPoints.has = true 
	end
	
	--若玩家為恢復德魯伊表示有生命之花
	if (id == 105) then 
		EA_SpecPower.LifeBloom.has = true 
	end
	
	--若玩家為暗影牧師表示有暗影能量
	if (id == 258) then	
		EA_SpecPower.Insanity.has = true 
	end
	
	--若玩家為秘法表示有秘法充能
	if (id == 62) then
		EA_SpecPower.ArcaneCharges.has = true 
	end
	
	--若玩家為增強薩或元素薩表示有元能(漩渦值)
	if (id == 262) or (id == 263) then
		EA_SpecPower.Maelstrom.has = true 
	end	
	
	--若玩家為惡魔獵人表示有魔怒,魔痛
	if (pClass == EA_CLASS_DEMONHUNTER) then 		
		if (id == 577) or (id == 581) then
			EA_SpecPower.Fury.has = true 
		end				
	end
	
	--若玩家為喚能師表示有龍能
	if (pClass == EA_CLASS_EVOKER) then 		
		EA_SpecPower.Essence.has = true 
	end
	
	--若已學會飛龍騎術表示有活力值
	if G:IsLearnSpell(376777) then		
		EA_SpecPower.Vigor.has = true
	end
	
	G:SpecialFrame_Update()	
end                           
------------------------------------------------------------------
---
------------------------------------------------------------------
function G:SpecialFrame_Update()
	local type  = type
	local pairs = pairs
	local SpecPowerCheck = EA_Config.SpecPowerCheck
	local k,tblPower
	local k2,f
	
	for k,tblPower in pairs(EA_SpecPower) do
		--if (type(tblPower)=="table") and (EA_Config.SpecPowerCheck[k]) and (tblPower.has) then
		if (type(tblPower)=="table") then
			if(tblPower.frameindex) then
				for k2,f in pairs(tblPower.frameindex) do					
					if ( f and (SpecPowerCheck[k]) and (tblPower.has) ) then						
						G:CreateFrames_SpecialFrames_Show(f)				
					else
						G:CreateFrames_SpecialFrames_Hide(f)
					end
				end
			end			
		end		
	end
	
end       

