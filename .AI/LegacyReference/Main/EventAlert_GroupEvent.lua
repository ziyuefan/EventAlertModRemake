--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_GroupEvent.lua

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
-----------------------------------------------------
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

-- WOW API : Spell
local GetSpellCharges 	= type(GetSpellCharges)=="function" 	and GetSpellCharges 	or C_Spell.GetSpellCharges
local GetSpellCooldown 	= type(GetSpellCooldown)=="function" 	and GetSpellCooldown 	or C_Spell.GetSpellCooldown
local GetSpellInfo 		= type(GetSpellInfo)=="function"		and GetSpellInfo 		or C_Spell.GetSpellInfo
local GetSpellLink 		= type(GetSpellLink)=="function"		and GetSpellLink 		or C_Spell.GetSpellLink
local GetSpellTexture 	= type(GetSpellTexture)=="function"		and GetSpellTexture 	or C_Spell.GetSpellTexture
local IsUsableSpell 	= type(IsUsableSpell)=="function"		and IsUsableSpell		or C_Spell.IsSpellUsable
local GetTotemInfo 		= GetTotemInfo                 
------------------------------------------------------------------
-- GroupEvent: GroupFrameUnitDie. If target/focus Unit is died, then notice all UNIT_HEALTH event with this target/focus Unit.
-----------------------------------------------------------------
function G.GroupFrameUnitDie_OnEvent(self, event, ...)
	local iSpells, iChecks, iSubChecks = 0, 0, 0
	local iGroupIndex = self.GC.GroupIndex
	local SubCheck = {}
	-- if (event == "UNIT_HEALTH") then
	local sUnitType = ...
	-- SPEC EVENT FIRED, To check all INDEXD-EVENTCFG about this frame(by GroupIndex).
	if (G.GC_IndexOfGroupFrame[event] ~= nil) then
		if (G.GC_IndexOfGroupFrame[event][iGroupIndex] ~= nil) then
			for iIndex, aValue in ipairs(G.GC_IndexOfGroupFrame[event][iGroupIndex]) do
				iSpells = G.GC_IndexOfGroupFrame[event][iGroupIndex][iIndex].Spells
				iChecks = G.GC_IndexOfGroupFrame[event][iGroupIndex][iIndex].Checks
				iSubChecks = G.GC_IndexOfGroupFrame[event][iGroupIndex][iIndex].SubChecks
				SubCheck = self.GC.Spells[iSpells].Checks[iChecks].SubChecks[iSubChecks]
				if (sUnitType == SubCheck.UnitType) then -- "player"
					self.GC.Spells[iSpells].Checks[iChecks].SubChecks[iSubChecks].SubCheckResult = false
					G.EAFun_FireEventSubCheckResult(self, iSpells, iChecks)
				end
			end
		end
	end
	-- end
end
-----------------------------------------------------------------
-- GroupEvent: CurrValueCompCfgValue. The 5 ways of comparison.
-----------------------------------------------------------------
function G:EAFun_CurrValueCompCfgValue(CompType, CurrValue, CfgValue)
	
	local fResult = falase
	if (CompType == 1) then		-- Curr < Cfg
		if (CurrValue < CfgValue) then fResult = true end
	elseif (CompType == 2) then	-- Curr <= Cfg
		if (CurrValue <= CfgValue) then fResult = true end
	elseif (CompType == 3) then	-- Curr = Cfg
		if (CurrValue == CfgValue) then fResult = true end
	elseif (CompType == 4) then	-- Curr >= Cfg
		if (CurrValue >= CfgValue) then fResult = true end
	elseif (CompType == 5) then	-- Curr > Cfg
		if (CurrValue > CfgValue) then fResult = true end
	elseif (CompType == 6) then	-- Curr <> Cfg		
		if (CurrValue ~= CfgValue) then fResult = true end		
	elseif (CompType == 7) then	-- Cfg = any
		fResult = true
	end
	return fResult
end

-----------------------------------------------------------------
-- GroupEvent: GroupFrameCheck. The core checking routine for GroupEvent Conditions.
-----------------------------------------------------------------
local SubCheck = {}
function G.GroupFrameCheck_OnEvent(self, event, ...)
	
	local iSpells, iChecks, iSubChecks = 0, 0, 0
	local iGroupIndex = self.GC.GroupIndex
	local SubCheck = wipe(SubCheck)
	local iActiveTalentGroup = 0
	local fAllUnitMonitor = false
	local fShowResult = true	
	-- If this GroupCheck is Enabled / Disabled
	if (self.GC.enable ~= nil) then
		if (not self.GC.enable) then
			fShowResult = false
		end
	end
	-- If the Active-Talent should be checked
	if (fShowResult) then
		if (self.GC.ActiveTalentGroup ~= nil) then
			--5.1:GetActiveTalentGroup() -> GetActiveSpecGroup()
			--iActiveTalentGroup = GetActiveSpecGroup()
			--7.0 GetActiveSpecGroup() -> GetSpecialization()
			iActiveTalentGroup =  GetSpecialization and GetSpecialization()
			if (iActiveTalentGroup ~= self.GC.ActiveTalentGroup) then
				fShowResult = false
			end
		end
	end
	-- If the Hide-On-Leave-of-Combat should be checked
	if (fShowResult) then
		if (self.GC.HideOnLeaveCombat ~= nil) then
			if (self.GC.HideOnLeaveCombat) then
				if not InCombatLockdown() then
					fShowResult = false
				end
			end
		end
	end
	-- If the Hide-On-Lost-Target should be checked
	if (fShowResult) then
		if (self.GC.HideOnLostTarget ~= nil) then
			if (self.GC.HideOnLostTarget) then
				if (not UnitExists("target")) then
					fShowResult = false
				end
			end
		end
	end
	local sTempUnitType = "target"
	if ((not UnitExists(sTempUnitType)) or UnitIsCorpse(sTempUnitType) or UnitIsDeadOrGhost(sTempUnitType)) then
		G.GroupFrameUnitDie_OnEvent(self, "UNIT_HEALTH", sTempUnitType)
	end
	sTempUnitType = "focus"
	if ((not UnitExists(sTempUnitType)) or UnitIsCorpse(sTempUnitType) or UnitIsDeadOrGhost(sTempUnitType)) then
		G.GroupFrameUnitDie_OnEvent(self, "UNIT_HEALTH", sTempUnitType)
	end
	if (not fShowResult) then
		G.EAFun_FireEventCheckHide(self)
	else
		if (event == "ACTIVE_TALENT_GROUP_CHANGED") then
			-- If the Active-Talent should be checked
			--5.1:GetActiveTalentGroup() -> GetActiveSpecGroup()
			--7.0 GetActiveSpecGroup() -> GetSpecialization()
			iActiveTalentGroup = GetSpecialization()
			if (iActiveTalentGroup ~= self.GC.ActiveTalentGroup) then
				fShowResult = false
				G.EAFun_FireEventCheckHide(self)
			end
		elseif (event == "PLAYER_REGEN_ENABLED") then
			-- If the Hide-On-Leave-of-Combat should be checked
			if (self.GC.HideOnLeaveCombat ~= nil) then
				if (self.GC.HideOnLeaveCombat) then
					if InCombatLockdown() then
						fShowResult = false
						G.EAFun_FireEventCheckHide(self)
					end
				end
			end
		elseif (event == "PLAYER_TARGET_CHANGED") then
			-- If the Hide-On-Lost-Target should be checked
			if (self.GC.HideOnLostTarget ~= nil) then
				if (self.GC.HideOnLostTarget) then
					if (not UnitExists("target")) then
						fShowResult = false
						G.EAFun_FireEventCheckHide(self)
					end
				end
			end
		elseif (event == "UNIT_POWER_UPDATE") then
			local sUnitType, sPowerType = ...
			-- SPEC EVENT FIRED, To check all INDEXD-EVENTCFG about this frame(by GroupIndex).
			-- G.GC_IndexOfGroupFrame["UNIT_POWER"] = {[1]={Spells=1,Checks=1,SubChecks=1,},}
			for iIndex, aValue in ipairs(G.GC_IndexOfGroupFrame[event][iGroupIndex]) do
				iSpells = G.GC_IndexOfGroupFrame[event][iGroupIndex][iIndex].Spells
				iChecks = G.GC_IndexOfGroupFrame[event][iGroupIndex][iIndex].Checks
				iSubChecks = G.GC_IndexOfGroupFrame[event][iGroupIndex][iIndex].SubChecks
				SubCheck = self.GC.Spells[iSpells].Checks[iChecks].SubChecks[iSubChecks]
				if (sUnitType == SubCheck.UnitType or SubCheck.UnitType == "all") then -- "player"
					if (sPowerType == SubCheck.PowerType) then						
						fShowResult = true
						if (fShowResult) then
							if (SubCheck.CheckCD ~= nil) then
								local iStart, iDuration, iEnable 
								local spellCooldownInfo = GetSpellCooldown(SubCheck.CheckCD)
								if type(spellCooldownInfo) == "table" then
									iStart		=	spellCooldownInfo.startTime 
									iDuration	=	spellCooldownInfo.duration 
									iEnable		=	spellCooldownInfo.isEnabled and 1 or 0
								else
									iStart, iDuration, iEnable = GetSpellCooldown(SubCheck.CheckCD)
								end
								
								if (iStart <= 0) or (iStart >= 0 and iDuration <= 1.5) then
									if IsUsableSpell(SubCheck.CheckCD) then
										fShowResult = true
									end																
								else
									fShowResult = false
								end
							end
						end
						if (fShowResult) then
							local iCurrPowerValue, iCheckPowerValue = 0
							if SubCheck.PowerLessThanValue ~= nil then								
								iCurrPowerValue = UnitPower(sUnitType, SubCheck.PowerTypeNum)
								iCheckPowerValue = SubCheck.PowerLessThanValue
							elseif SubCheck.PowerLessThanPercent ~= nil then
								iCurrPowerValue = (UnitPower(sUnitType, SubCheck.PowerTypeNum) * 100) / UnitPowerMax(sUnitType, SubCheck.PowerTypeNum)
								iCheckPowerValue = SubCheck.PowerLessThanPercent
							end
							fShowResult = G:EAFun_CurrValueCompCfgValue(SubCheck.PowerCompType, iCurrPowerValue, iCheckPowerValue)
						end
						
						self.GC.Spells[iSpells].Checks[iChecks].SubChecks[iSubChecks].SubCheckResult = fShowResult
						G.EAFun_FireEventSubCheckResult(self, iSpells, iChecks)
					end
				end
			end
		elseif (event == "UNIT_HEALTH") then
			local sUnitType = ...
			-- SPEC EVENT FIRED, To check all INDEXD-EVENTCFG about this frame(by GroupIndex).
			for iIndex, aValue in ipairs(G.GC_IndexOfGroupFrame[event][iGroupIndex]) do
				iSpells = G.GC_IndexOfGroupFrame[event][iGroupIndex][iIndex].Spells
				iChecks = G.GC_IndexOfGroupFrame[event][iGroupIndex][iIndex].Checks
				iSubChecks = G.GC_IndexOfGroupFrame[event][iGroupIndex][iIndex].SubChecks
				SubCheck = self.GC.Spells[iSpells].Checks[iChecks].SubChecks[iSubChecks]
				if (sUnitType == SubCheck.UnitType or SubCheck.UnitType == "all") then -- "player"
					fShowResult = true
					if (fShowResult) then
						if (SubCheck.CheckCD ~= nil) then
							local iStart, iDuration, iEnable 
							local spellCooldownInfo = GetSpellCooldown(SubCheck.CheckCD)
							if type(spellCooldownInfo) == "table" then 
								iStart		= 	spellCooldownInfo.startTime
								iDuration	=	spellCooldownInfo.duration
								iEnable		=	spellCooldownInfo.isEnabled and 1 or 0
							else
								iStart, iDuration, iEnable = GetSpellCooldown(SubCheck.CheckCD)
							end
							
							
							if (iStart <= 0) or (iStart >= 0 and iDuration <= 1.5) then
								fShowResult = true
							else
								fShowResult = false
							end
						end
					end
					if (fShowResult) then
						local iCurrHealthValue, iCheckHealthValue = 0
						if SubCheck.HealthLessThanValue ~= nil then
							iCurrHealthValue = UnitHealth(sUnitType)
							iCheckHealthValue = SubCheck.HealthLessThanValue
						elseif SubCheck.HealthLessThanPercent ~= nil then
							iCurrHealthValue = (UnitHealth(sUnitType) * 100) / UnitHealthMax(sUnitType)
							iCheckHealthValue = SubCheck.HealthLessThanPercent
						end
						fShowResult = G:EAFun_CurrValueCompCfgValue(SubCheck.HealthCompType, iCurrHealthValue, iCheckHealthValue)
					end
					self.GC.Spells[iSpells].Checks[iChecks].SubChecks[iSubChecks].SubCheckResult = fShowResult
					G.EAFun_FireEventSubCheckResult(self, iSpells, iChecks)
				end
			end
		elseif (event == "UNIT_AURA") then
			local sUnitType = ...
			
			local sAuraFilter = ""
			-- SPEC EVENT FIRED, To check all INDEXD-EVENTCFG about this frame(by GroupIndex).
			for iIndex, aValue in ipairs(G.GC_IndexOfGroupFrame[event][iGroupIndex]) do
				iSpells = G.GC_IndexOfGroupFrame[event][iGroupIndex][iIndex].Spells
				iChecks = G.GC_IndexOfGroupFrame[event][iGroupIndex][iIndex].Checks
				iSubChecks = G.GC_IndexOfGroupFrame[event][iGroupIndex][iIndex].SubChecks
				SubCheck = self.GC.Spells[iSpells].Checks[iChecks].SubChecks[iSubChecks]
				
				if (sUnitType == SubCheck.UnitType or SubCheck.UnitType == "all") then -- "player"
					
					fShowResult = true
					if (fShowResult) then
						if (SubCheck.CheckCD ~= nil) then
							local iStart, iDuration, iEnable 
							local spellCooldownInfo = GetSpellCooldown(SubCheck.CheckCD)
							if (type(spellCooldownInfo) == "table") then								
									iStart		=	spellCooldownInfo.startTime 
									iDuration	=	spellCooldownInfo.duration 
									iEnable		=	spellCooldownInfo.isEnabled and 1 or 0
							else
								iStart, iDuration, iEnable = GetSpellCooldown(SubCheck.CheckCD)
							end
							
							
							if (iStart <= 0) or (iStart >= 0 and iDuration <= 1.5) then
								fShowResult = true
							else
								fShowResult = false
							end
						end
					end
					
										
					if (fShowResult) then
						sAuraFilter = ""
						if (SubCheck.CastByPlayer ~= nil) then
							if (SubCheck.CastByPlayer) then
								sAuraFilter = "|PLAYER"
							end
						end
						if (SubCheck.CheckAuraExist ~= nil) then
							fShowResult = false
							local spellInfo = GetSpellInfo(SubCheck.CheckAuraExist)
							
							local sSpellName = (type(spellInfo) == "table") and spellInfo.name or select(1, spellInfo) 
							
							local sCurrSpellName,  _, iStack, _, _, iExpireTime = AuraUtil.FindAuraByName(sSpellName, sUnitType, "HELPFUL"..sAuraFilter)							
							
							if sCurrSpellName ~= nil then
								fShowResult = true
							else
								sCurrSpellName, _, iStack, _, _, iExpireTime = AuraUtil.FindAuraByName(sSpellName, sUnitType, "HARMFUL"..sAuraFilter)
								if sCurrSpellName ~= nil then
									fShowResult = true
								end
							end
							-- ToDo: If Exists, Then Check seconds, stacks
							-- Modify: Show When Stack "OR" Remain Time match config value
							if (fShowResult) then
								
								if (SubCheck.StackCompType ~= nil) then
									fShowResult1 = G:EAFun_CurrValueCompCfgValue(SubCheck.StackCompType, iStack, SubCheck.StackLessThanValue)
								end							
								if (SubCheck.TimeCompType ~= nil) then
									local iLeftTime = iExpireTime - GetTime()
									fShowResult2 = G:EAFun_CurrValueCompCfgValue(SubCheck.TimeCompType, iLeftTime, SubCheck.TimeLessThanValue)
								end
								
								fShowResult = fShowResult1 and fShowResult2								
							end
						end
						
						
						if (SubCheck.CheckAuraNotExist ~= nil) then						
							
							fShowResult = false
							local spellInfo = GetSpellInfo(SubCheck.CheckAuraNotExist)
							local sSpellName = (type(spellInfo) == "table") and spellInfo.name or select(1,spellInfo)
							
							local sCurrSpellName = AuraUtil.FindAuraByName(sSpellName,sUnitType, "HELPFUL"..sAuraFilter)
							if sCurrSpellName == nil then
								sCurrSpellName = AuraUtil.FindAuraByName(sSpellName,sUnitType, "HARMFUL"..sAuraFilter)
								if sCurrSpellName == nil then
									fShowResult = true
								end
							end
						end
					end
					
					self.GC.Spells[iSpells].Checks[iChecks].SubChecks[iSubChecks].SubCheckResult = fShowResult
					G.EAFun_FireEventSubCheckResult(self, iSpells, iChecks)
				end
			end
		elseif (event == "UNIT_COMBO_POINTS") then
		end
	end
end