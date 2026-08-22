--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_Aura_Self.lua

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

local tmp = {}
------------------------------------------------------------------
--
------------------------------------------------------------------
function G:Buff_Applied(spellId, flagAlert)
	-- DEFAULT_CHAT_FRAME:AddMessage("buff-applying: id: "..spellId)
	-- tinsert(G.EA_CurrentBuffs, spellId)
	-- G.EA_CurrentBuffs[#G.EA_CurrentBuffs + 1] = spellId	
	if flagAlert then G:DoAlert() end
	
	G:insertBuffValue(G.EA_CurrentBuffs, spellId)	
	G:OnUpdate(spellId)  
	G:PositionFrames()	
	
end        
------------------------------------------------------------------
--
------------------------------------------------------------------
function G:Buff_Dropped(spellId)
	
	-- DEFAULT_CHAT_FRAME:AddMessage("buff-dropping: id: "..spellId)
	local eaf = _G["EAFrame_"..spellId]
	local spellId = tonumber(spellId)
	if eaf ~= nil then
		G:FrameGlowShowOrHide(eaf, false)		
		eaf:Hide()                       		
		G:removeBuffValue(G.EA_CurrentBuffs, spellId)   	
		Lib_ZYF:StopOnUpdate(eaf)
	end
	G:PositionFrames()
end


local buffsCurrent 	= {}
local buffsToDelete = {}
local MAX_BUFFS = 40   
local PlayerItems
local OtherItems 

local function processAura(auraData, unitId)
	if not auraData or not auraData.spellId then return false end
	
	PlayerItems = EA_Items[G.playerClass]
	OtherItems  = EA_Items[EA_CLASS_OTHER]
	
	if (G.EA_DEBUGFLAG1) then
	   if (G.EA_LISTSEC_SELF == 0 or (0 < auraData.duration and auraData.duration <= G.EA_LISTSEC_SELF)) then
		  G:EAFun_AddSpellToScrollFrame(auraData.spellId, " /\124cffFFFF00"..EA_XCMD_DEBUG_P3.."\124r:"..auraData.applications.." /\124cffFFFF00"..EA_XCMD_DEBUG_P4.."\124r:"..auraData.duration)
		  -- DEFAULT_CHAT_FRAME:AddMessage("["..i.."]\124cffFFFF00"..EA_XCMD_DEBUG_P1.."\124r:"..name..
		  --  " /\124cffFFFF00"..EA_XCMD_DEBUG_P2.."\124r:"..spellId..
		  --  " /\124cffFFFF00"..EA_XCMD_DEBUG_P3.."\124r:"..count..
		  --  " /\124cffFFFF00"..EA_XCMD_DEBUG_P4.."\124r:"..duration)
	   end
	end


	local auraInstanceID = auraData.auraInstanceID	
	local objDuration = C_UnitAuras.GetAuraDuration(unitId, auraInstanceID)
	
	local SpellEnable = G:EAFun_GetSpellItemEnable(PlayerItems[auraData.spellId])  -- Check if the spell is enabled for the player (檢查法術是否為玩家啟用)
	local OtherEnable = G:EAFun_GetSpellItemEnable(OtherItems[auraData.spellId]) -- Check if the spell is enabled for general cases (檢查法術是否為通用啟用)

	local ifAdd_buffCur, orderWtd = false, 1
	if (SpellEnable) then
		-- Validate player-specific spell conditions (驗證玩家特定法術條件)
		ifAdd_buffCur, orderWtd = G:EAFun_CheckSpellConditionMatch(auraData.applications, auraData.sourceUnit, PlayerItems[auraData.spellId])
	elseif (OtherEnable) then
		-- Validate general spell conditions (驗證通用法術條件)
		ifAdd_buffCur, orderWtd = G:EAFun_CheckSpellConditionMatch(auraData.applications, auraData.sourceUnit, OtherItems[auraData.spellId])
	end

	if ifAdd_buffCur then
		-- Save spell information to SPELLINFO_SELF (將法術信息保存到SPELLINFO_SELF)
		local spellData = G.SPELLINFO_SELF[auraData.spellId]                       
		
		spellData.name 				= auraData.name			
		spellData.icon				= auraData.icon 	-- Spell icon (法術圖標)
		spellData.count 			= auraData.applications -- Stack count (疊加層數)
		-- spellData.duration	 		= auraData.duration, -- Duration of the buff (Buff持續時間)
		spellData.duration 			= objDuration:GetTotalDuration(Enum.DurationTimeModifier.RealTime)
		spellData.RemainDuration 	= objDuration:GetRemainingDuration(Enum.DurationTimeModifier.RealTime)
		-- spellData.RemainDuration 	= objDuration:GetRemainDuration(Enum.DurationTimeModifier.RealTime)
		-- spellData.expirationTime	= auraData.expirationTime, -- Expiration time (到期時間)		
		spellData.expirationTime 	= objDuration:GetEndTime(Enum.DurationTimeModifier.RealTime)
		spellData.unitCaster 		= unitId 			-- Caster unit (施法單位)
		spellData.isDebuff			= auraData.isHarmful -- Is it a debuff? (是否為Debuff？)
		spellData.orderwtd			= orderWtd 			-- Sorting weight (排序權重)
		spellData.value				= auraData.points 	-- Additional value (附加值)
		spellData.aura				= true 				-- Indicates this is a buff (標誌此為Buff)
		
		buffsCurrent[#buffsCurrent + 1] = auraData.spellId -- Add spell ID to current buffs (將法術ID加入當前Buff列表)
	end
end

------------------------------------------------------------------
--自身增減益:取得最新資訊(包含非光環式技能處理)
------------------------------------------------------------------

function G:Buffs_Update(doType , ...)   
	local t0 = debugprofilestop()
	
	wipe(buffsCurrent)
	wipe(buffsToDelete)
	PlayerItems = EA_Items[G.playerClass]
	OtherItems = EA_Items[EA_CLASS_OTHER]
	
	local SpellEnable, OtherEnable = false, false
	local ifAdd_buffCur = false
	local orderWtd = 1   
	
   
   -- DEFAULT_CHAT_FRAME:AddMessage("G:Buffs_Update")
	-- if (G.EA_DEBUGFLAG1) then
	--  DEFAULT_CHAT_FRAME:AddMessage("----"..EA_XCMD_SELFLIST.."----")
	-- end
	if (G.EA_DEBUGFLAG11 or G.EA_DEBUGFLAG21) then
		G:CreateFrames_EventsFrame_ClearSpellList(3)
	end	               	
	
	
	if (doType == "PLAYER_BUFFS") or (doType == "PET_BUFFS") 	then 		
	  
		local unitId, UnitAuraUpdateInfo = ... 		 		   
		local auraData
		if (unitId == "player") or (unitId == "pet") then
			
			for i = 1, MAX_BUFFS do
				if not C_Secrets.ShouldUnitAuraIndexBeSecret(unitId, i, "HELPFUL")  then 
					auraData = C_UnitAuras.GetAuraDataByIndex(unitId, i, "HELPFUL")
					if not auraData then break end
					processAura(auraData, unitId) -- Process helpful buffs (處理有益Buff)
					-- processAura(UnitAura(unitId, i, "HELPFUL"), unitId) -- Process helpful buffs (處理有益Buff)
				end     
			end
			
			for i = 1, MAX_BUFFS do		
				if not C_Secrets.ShouldUnitAuraIndexBeSecret(unitId, i, "HARMFUL")  then
					auraData = C_UnitAuras.GetAuraDataByIndex(unitId, i, "HARMFUL")
					if not auraData then break end
					processAura(auraData, unitId) -- Process helpful buffs (處理有益Buff)							
					-- processAura(UnitAura(unitId, i, "HARMFUL"), unitId) -- Process harmful buffs (處理有害Buff)
				end
			end
			-- for s, info in pairs(PlayerItems) do 
				-- auraData = C_UnitAuras.GetPlayerAuraBySpellID(s) 
				-- if auraData and info.enabled then  
					-- processAura(auraData, unitId) 
				-- end
			-- end
		end
	else	   		
		for k, v in pairs(G.EA_CurrentBuffs) do 
			buffsCurrent[k] = v 
		end	
	end   
	
   -- if (doType == "TOTEM_BUFFS") or (doType == "SPELL_SUMMON") 	then 	
   -- if (doType == "SPELL_SUMMON") 	then 	
	  -- --針對圖騰類法術進行偵測（如力之符文、屈心魔、邪DK華爾琪）
	  -- local	timestp, event, hideCaster, 
			-- surGUID, surName, surFlags, surRaidFlags, 
			-- dstGUID, dstName, dstFlags, dstRaidFlags, 
			-- spellId,  spellName = ...  
	  
	  -- local count = 1
	  -- local unitCaster = "player"      	  
	  -- local GetTotemInfo = GetTotemInfo
	  -- local haveTotem, TotemName, TotemStart, TotemDuration, TotemIcon	
	  -- for t = 1, 4 do			
	  
		 -- haveTotem, TotemName, TotemStart, TotemDuration, TotemIcon, spellId = GetTotemInfo(t)
		 
		 -- ifAdd_buffCur = false
		 -- SpellEnable = G:EAFun_GetSpellItemEnable(PlayerItems[spellId])			
		 
		 -- if (SpellEnable) then			
			-- ifAdd_buffCur, orderWtd = G:EAFun_CheckSpellConditionMatch(count, unitCaster, PlayerItems[spellId])	
		 -- end
		 
		 -- if (ifAdd_buffCur) then
			-- if haveTotem then
			   -- if (event == "SPELL_SUMMON") then
				  -- G.SPELLINFO_SELF[spellId] =	{	
												 -- name			=	spellName,											
												 -- icon 			= 	TotemIcon,
												 -- count			=	count,
												 -- duration		=	TotemDuration,
												 -- expirationTime	=	TotemStart + TotemDuration,
												 -- unitCaster 	= 	unitCaster,
												 -- isDebuff		= 	false,
												 -- orderwtd		=	orderWtd,											
												 -- totem			=	t,
												-- }
			   -- end 
			   -- --if (event == "SPELL_SUMMON")
			   
			   -- --tinsert(buffsCurrent, spellId)	
				-- buffsCurrent[#buffsCurrent + 1] = spellId			   
			-- end
			-- --if haveTotem
		 -- end 
		 -- -- if (ifAdd_buffCur) 
	  -- end 
	  -- -- end of for
   
	
	  -- local t, s
	  -- for _ ,s in pairs(G.EA_CurrentBuffs) do 		
		 -- if G.SPELLINFO_SELF[s] then 		
			-- t = G.SPELLINFO_SELF[s].totem 			
			-- if t and t > 0 then	 			
				-- haveTotem, TotemName, TotemStart, TotemDuration, TotemIcon ,spellId = GetTotemInfo(t)
				
				-- if haveTotem and GetTime() < G.SPELLINFO_SELF[s].expirationTime then			
					-- --tinsert(buffsCurrent, s)
					-- buffsCurrent[#buffsCurrent + 1] = s
				-- else
					-- G.SPELLINFO_SELF[s].totem = nil
					-- --tinsert(buffsToDelete, s)
					-- buffsToDelete[#buffsToDelete + 1] = s
				-- end
				-- -- end of if haveTotem and GetTime() < EA_SPELLINFO_SELF[s].expirationTime		
			-- end	
			-- -- end of if t and t > 0	 
		 -- end 
		 -- -- end of  if EA_SPELLINFO_SELF[s]
	  -- end 
	  -- -- end of for _ ,s in pairs(G.EA_CurrentBuffs)
   -- end 
   -- --  end of if (doType == "TOTEM_BUFFS") or (doType == "SPELL_SUMMON") 
	 
	if (doType == "SPELL_DURATION") then	
		
		local	timestp, event, hideCaster, 
			surGUID, surName, surFlags, surRaidFlags, 
			dstGUID, dstName, dstFlags, dstRaidFlags, 
			spellId, spellName = CombatLogGetCurrentEventInfo()
		count = 1
		unitCaster=""			
		-- unitCaster = (surGUID == UnitGUID("target")) and "target" or ""        
		unitCaster = (surGUID == UnitGUID("player")) and "player" or ""  	  	  
		if spellId and (unitCaster == "player") then  				
			if (event == "SPELL_AURA_APPLIED") or (event == "SPELL_AURA_REFRESH") then					
				if G.SPELLINFO_SELF[spellId] then
					 G.SPELLINFO_SELF[spellId].aura = true	
				end			
			end
			ifAdd_buffCur = false
			SpellEnable = G:EAFun_GetSpellItemEnable(PlayerItems[spellId])	
				
			if (SpellEnable) then					
				ifAdd_buffCur, orderWtd = G:EAFun_CheckSpellConditionMatch(count, unitCaster, PlayerItems[spellId])				
			end					 
			local EffectDuration = tonumber(Lib_ZYF.SpellDescParser:GetDuration(spellId))
			 
				if (ifAdd_buffCur) then		
					if (event == "SPELL_CAST_SUCCESS") and EffectDuration then				
						if not(G.SPELLINFO_SELF[spellId].aura) then								
							G.SPELLINFO_SELF[spellId] =	{	
													 name			=	spellName,											
													 icon 			= 	GetSpellTexture(spellId),
													 count			=	0,
													 duration		=	EffectDuration,
													 expirationTime	=	GetTime() + EffectDuration,
													 unitCaster 	= 	unitCaster,
													 isDebuff		= 	false,
													 orderwtd		=	orderWtd,											
													 spellcast		=	true,
													}
							--tinsert(buffsCurrent, spellId)  
							buffsCurrent[#buffsCurrent + 1] = spellId							
							
							
						end  --if (EA_SPELLINFO_SELF[spellId].aura ~= true)
					end  --if (event == "SPELL_CAST_SUCCESS")		  
				end  -- if (ifAdd_buffCur) then		 
		end --if spellId and (unitCaster == "player") 
	end --if (doType == "SPELL_DURATION") then	

	
	local spellcast								
	for _, s in pairs(G.EA_CurrentBuffs) do  								
		if G.SPELLINFO_SELF[s] then 		
			spellcast = G.SPELLINFO_SELF[s].spellcast
			if spellcast then					
				if  GetTime() < G.SPELLINFO_SELF[s].expirationTime then						
					buffsCurrent[#buffsCurrent + 1] = s
				else
					G.SPELLINFO_SELF[s].spellcast = false					
					buffsToDelete[#buffsToDelete + 1] = s					
				end			
			end -- if spellcast then							
		end -- if G.SPELLINFO_SELF[spellId]
	end -- end of for _, spellId in pairs(G.EA_CurrentBuffs)

	--[[
	-- Check: Buff dropped
	local v1 = table.foreach(G.EA_CurrentBuffs,
		function(i, v1)
			-- DEFAULT_CHAT_FRAME:AddMessage("buff-check: "..i.." id: "..v1)
			SpellEnable = false
			SpellEnable = G:EAFun_GetSpellItemEnable(EA_AltItems[G.playerClass][v1])
			if (not SpellEnable) then				
				local v3 = table.foreach(buffsCurrent,					
					function(k, v2)							
						if (v1==v2) then
							return v2
						end
					end
				)
				if(not v3) then					
					-- Buff dropped
					table.insert(buffsToDelete, v1)					
				end			
			end
		end
	)
	]]--
	-- Check: Buff dropped	
	
	
	--檢查指定變數是否存在於指定陣列,若有則傳回所在位置,否則傳回nil(20240213)
	local function InArray(var, t)
			for i,v in ipairs(t) do
				if v == var then return true end			
			end
			return nil
	end
	
	if #buffsCurrent > 0 then 
		-- Check: Buff dropped(20240213)	
		
		for _, v in ipairs(G.EA_CurrentBuffs) do 	
			 SpellEnable = false
			 SpellEnable = G:EAFun_GetSpellItemEnable(EA_AltItems[G.playerClass][v])
			 if SpellEnable == false then 			
				if InArray(v, buffsCurrent) == nil then 						
					--tinsert(buffsToDelete, v)				
					buffsToDelete[#buffsToDelete + 1] = v				
				end
			 end		
		end
		
		
		-- Drop Buffs(20240213)
		
		for _, v in ipairs(buffsToDelete) do	
			
			G:Buff_Dropped(v)
		end
		
		-- -- Drop Buffs
		-- foreach(buffsToDelete,
			-- function(i, v)			
				-- --DEFAULT_CHAT_FRAME:AddMessage("buff-dropped: id: "..v)			
				-- G:Buff_Dropped(v)
			-- end)
			
		-- Check: Buff applied(20240213)
		for _, v in ipairs(buffsCurrent) do
			if InArray(v, G.EA_CurrentBuffs) == nil then 
				G:Buff_Applied(v, true)
			end		
		end
		
		-- -- Check: Buff applied
		-- local v = foreach(buffsCurrent, function(i, v1)
				-- local v2 = foreach(G.EA_CurrentBuffs, function(k, v2)
					-- if (v1 == v2) then
						-- return v2
					-- end
				-- end)
				-- if(not v2) then
					-- -- Buff applied
					-- G:Buff_Applied(v1)
				-- end
			 -- end)

		-- G:PositionFrames()
		--
		
	end	
	
	if (G.EA_DEBUGFLAG11 or G.EA_DEBUGFLAG21) then
		G:CreateFrames_EventsFrame_RefreshSpellList(3)
	end
	
	--
	G:EAFun_testLabel("Buffs_Update", t0, debugprofilestop())
end


------------------------------------------------------------------
--自身增減益定時更新
------------------------------------------------------------------
local GetSpellCooldown = C_Spell.GetSpellCooldown
local tempFunc = function() end
function G:OnUpdate(spellId)
	local t0 = debugprofilestop()
	
	if not spellId then return end
	local eaf = _G["EAFrame_"..spellId]
	if not eaf then return end

	if eaf._updating then return end
	eaf._updating = true
	
	local info = G.SPELLINFO_SELF[spellId]	
	if not info then eaf._updating = false return end	 	
	
	local name        = info.name
	local count       = info.count or 0
	local expiration  = info.expirationTime or 0
	local isDebuff    = info.isDebuff or false	
	local now         = GetTime()
	local timeLeft    = expiration and (expiration - now) or 0
	
	-- local timeLeft 	  = info.RemainDuration
	

	-- 特殊處理可用技能的顯示 (AllowAltAlerts)
	
	if EA_Config.AllowAltAlerts and OtherItems[spellId] and OtherItems[spellId].enable then
		local usable = IsUsableSpell(spellId) 
		usable = usable and (GetSpellCooldown(spellId).startTime == 0)
		usable = usable and (GetSpellCooldown(spellId).duration  == 0)
		if not usable then
			G:Buff_Dropped(spellId)
			eaf._updating = false
			return
		else
			G.SPELLINFO_SELF[spellId] = {
				count = 0,
				expirationTime = 0,
				isDebuff = false,
			}
		end
	end
	
	-- local PlayerItems = EA_Items[G.playerClass]
	-- local OtherItems  = EA_Items[EA_CLASS_OTHER]
	
	-- 顯示倒數與堆疊數
	if EA_Config.ShowTimer then
		local redSec = G:EAFun_GetSpellConditionRedSecText(PlayerItems[spellId])
		if redSec == -1 then
			redSec = G:EAFun_GetSpellConditionRedSecText(OtherItems[spellId])
		end
		
		G:EAFun_SetCountdownStackText(eaf, timeLeft, count, redSec)
	else
		eaf.spellTimer:SetText("")
		eaf.spellStack:SetText("")
	end
	
	
	do
		-- local ShowAuraValueWhenOver = EA_Config.ShowAuraValueWhenOver
		
		wipe(tmp)
		if EA_Config.ShowName == true then	tinsert(tmp, name.."\n") end
		
		local value = info.value
		local av = PlayerItems[spellId] and PlayerItems[spellId].auravalue
		av = av or (OtherItems[spellId] and OtherItems[spellId].auravalue)
		if av then 
			for i , auravalue in ipairs(av) do
				local v, label
				if auravalue.enabled and value and value[i] then
					v = value[i]
					label = auravalue.label
				end
				
				if v then 
					v = G:EAFun_ShorterNumberByLocale(v)
					-- tmp = tmp.."\n"..v 				
					if label and strlen(label) > 0  then tinsert(tmp, label) end
					tinsert(tmp, v or "") 
					tinsert(tmp, "\n")
				end
			end
		end		
				
		SfontName, SfontSize = eaf.spellName:GetFont()
		if eaf.spellName:GetText() ~= tconcat(tmp)  then 	
			eaf.spellName:SetText(tconcat(tmp))														
		end
		if SfontSize ~= EA_Config.SNameFontSize then 				
			eaf.spellName:SetFont(SfontName, EA_Config.SNameFontSize)
		end
	end
	
	--是否高亮
	local isOverGrow = G:EAFun_CheckSpellConditionOverGrow(count, PlayerItems[spellId]) or
	G:EAFun_CheckSpellConditionOverGrow(EA_count, OtherItems[spellId])
	G:FrameGlowShowOrHide(eaf, isOverGrow)
	
	G:FrameAppendAuraTip(eaf, "PLAYER"	, spellId, G.SPELLINFO_SELF[spellId].isDebuff)
	G:FrameAppendAuraTip(eaf, "PET"		, spellId, G.SPELLINFO_SELF[spellId].isDebuff)
	
	-- 使用正確的 Timer 語法避免錯誤
	local delay = (timeLeft and timeLeft > 0 and timeLeft < 1) and (G.UpdateInterval / 11) or G.UpdateInterval
	if (G.SPELLINFO_SELF[spellId].spellcast and timeLeft > 0.1) or G:GetUnitAuraBySpellID("PLAYER", spellId) or G:GetUnitAuraBySpellID("PET", spellId) then 
		-- C_Timer.After(delay, G.OnUpdate, G ,spellId)	
		tempFunc = function() G.OnUpdate(spellId) end
		C_Timer.After(delay, tempFunc)				
	else
		G:Buff_Dropped(spellId)                           
	end
	
	eaf._updating = false	--
	G:EAFun_testLabel("OnUpdate", t0, debugprofilestop())
end    
----------------------------------------------------------------------
-- 排序＋佈局＋圖示更新（含 PiePipe 選擇）
----------------------------------------------------------------------
-- function G:PositionFrames()
    -- local t0 = debugprofilestop()

    -- if G.EA_flagAllHidden == true then EA_Main_Frame:SetAlpha(0)  return end 
    
	-- EA_Main_Frame:SetAlpha(1)
    

    -- -- 主框定位（ShowFrame 時才處理）
    -- if EA_Config.ShowFrame == true then
        -- EA_Main_Frame:ClearAllPoints()
        -- EA_Main_Frame:SetPoint(
            -- EA_Position.Anchor, UIParent,
            -- EA_Position.relativePoint, EA_Position.xLoc, EA_Position.yLoc
        -- )

        -- table.sort(G.EA_CurrentBuffs, function(a, b)
            -- local A = G.SPELLINFO_SELF[tonumber(a)]
            -- local B = G.SPELLINFO_SELF[tonumber(b)]
            -- local wa = (A and A.orderwtd) or 1
            -- local wb = (B and B.orderwtd) or 1
            -- return wa < wb
        -- end)

        -- -- 先「只做定位」：依旗標自動切換 PiePipe / Classic
        -- G:PositionFrames_SelfAuto(G.EA_CurrentBuffs, "EAFrame_")

        -- -- 再跑圖示屬性與 Tooltip（避免把 UI 重排和材質同時做）
        -- local IconSize = EA_Config.IconSize
        -- local infoTbl  = G.SPELLINFO_SELF
        -- for i = 1, #G.EA_CurrentBuffs do
            -- local v   = G.EA_CurrentBuffs[i]
            -- local eaf = _G["EAFrame_" .. v]
            -- if eaf then
                -- local spellId = tonumber(v)
                -- local info    = infoTbl[spellId]
                -- if info then
                    -- local isDebuff = info.isDebuff
                    -- local icon     = info.icon

                    -- G:SetSizeIfDiff(eaf, IconSize, IconSize)
                    -- local tex = G:EnsureTexture(eaf, icon)

                    -- -- 著色（自身Debuff 染紅，自身Buff 還原白色）
                    -- if isDebuff then
                        
						-- tex:SetVertexColor(1.0, EA_Position.RedDebuff, EA_Position.RedDebuff)
                    -- else
                        -- tex:SetVertexColor(1.0, 1.0, 1.0)
                    -- end

                    -- -- Tooltip（可再做快取降頻；先維持行為一致）
                    -- G:FrameAppendAuraTip(eaf, "player", spellId, isDebuff)
                    -- G:FrameAppendAuraTip(eaf, "pet",    spellId, isDebuff)
                -- end
            -- end
        -- end
    -- end

    -- G:EAFun_testLabel("PositionFrames", t0, debugprofilestop())
-- end




-- function G:PositionFrames()			
	-- local t0 = debugprofilestop()
	-- --
	
	-- if G.EA_flagAllHidden == true then 
		-- EA_Main_Frame:SetAlpha(0) 
		-- return 
	-- else
		-- EA_Main_Frame:SetAlpha(1) 
	-- end	
	
	-- local Anchor = EA_Position.Anchor
	
	-- if (EA_Config.ShowFrame == true) then
		-- EA_Main_Frame:ClearAllPoints()
		-- EA_Main_Frame:SetPoint(Anchor, UIParent, EA_Position.relativePoint, EA_Position.xLoc, EA_Position.yLoc)
		-- local prevFrame = "EA_Main_Frame"
		-- local prevFrame2 = "EA_Main_Frame"
		-- local xOffset = 100 + EA_Position.xOffset
		-- local yOffset = 0 + EA_Position.yOffset
		-- local SfontName, SfontSize = "", 0				
		
		-- -- G.EA_CurrentBuffs = G:EAFun_SortCurrBuffs2(1, G.EA_CurrentBuffs)
		
		-- -- -- 排序：依照 SPELLINFO_SELF[spellID].orderwtd 權重從小到大
		-- -- sort(G.EA_CurrentBuffs, function(a, b)
			-- -- local wa = (G.SPELLINFO_SELF[tonumber(a)] or {}).orderwtd or 1
			-- -- local wb = (G.SPELLINFO_SELF[tonumber(b)] or {}).orderwtd or 1
			-- -- return wa < wb
		-- -- end)
		
		-- table.sort(G.EA_CurrentBuffs, function(a, b)
			-- local A = G.SPELLINFO_SELF[tonumber(a)]
			-- local B = G.SPELLINFO_SELF[tonumber(b)]
			-- local wa = (A and A.orderwtd) or 1
			-- local wb = (B and B.orderwtd) or 1
			-- return wa < wb
		-- end)
		
		
		-- local IconSize = EA_Config.IconSize
		-- local ShowAuraValueWhenOver = EA_Config.ShowAuraValueWhenOver
		
		-- --for speedup
		-- local s,i,k,v 
		-- local eaf
		-- local spellId		
		-- local SPELLINFO_SELF_SPELLID
		-- local gsiName, gsiIcon, gsiValue, gsiIsDebuff					
		
		-- for i, v in ipairs(G.EA_CurrentBuffs) do
			
			-- eaf = _G["EAFrame_"..v]
			
			-- spellId = tonumber(v)	
			-- SPELLINFO_SELF_SPELLID = G.SPELLINFO_SELF[spellId]
			
			-- gsiName 	= SPELLINFO_SELF_SPELLID.name
			-- gsiIcon 	= SPELLINFO_SELF_SPELLID.icon
			-- gsiValue 	= SPELLINFO_SELF_SPELLID.value 			
			-- gsiIsDebuff = SPELLINFO_SELF_SPELLID.isDebuff
			
			-- if eaf ~= nil then
				 -- eaf:ClearAllPoints()
				-- if EA_Position.Tar_NewLine then
					-- if gsiIsDebuff then
						-- if (prevFrame2 == "EA_Main_Frame" or prevFrame2 == eaf) then
							-- prevFrame2 = "EA_Main_Frame"
							-- if G.SpecFrame_Self then
								-- eaf:SetPoint(Anchor, prevFrame2, Anchor, -4 * xOffset, -2 * yOffset)
							-- else
								-- eaf:SetPoint(Anchor, prevFrame2, Anchor, -1 * xOffset, -1 * yOffset)
							-- end
						-- else
							-- eaf:SetPoint("CENTER", prevFrame2, "CENTER", -1 * xOffset, -1 * yOffset)
						-- end
						-- prevFrame2 = eaf
					-- else
						-- if (prevFrame == "EA_Main_Frame" or prevFrame == eaf) then
							-- prevFrame = "EA_Main_Frame"
							-- eaf:SetPoint(Anchor, prevFrame, Anchor, 0, 0)
						-- else
							-- eaf:SetPoint("CENTER", prevFrame, "CENTER", xOffset, yOffset)
						-- end
						-- prevFrame = eaf
					-- end
				-- else
					-- if (prevFrame == "EA_Main_Frame" or prevFrame == eaf) then
						-- prevFrame = "EA_Main_Frame"
						-- eaf:SetPoint(Anchor, prevFrame, Anchor, 0, 0)
					-- else
						-- eaf:SetPoint("CENTER", prevFrame, "CENTER", xOffset, yOffset)
					-- end
					-- prevFrame = eaf
				-- end
				-- eaf:SetSize(IconSize,IconSize)
				-- -- eaf:SetWidth(IconSize)
				-- -- eaf:SetHeight(IconSize)
				-- --eaf:SetBackdrop({bgFile = gsiIcon})
				-- --for 7.0
				-- if not eaf.texture then eaf.texture = eaf:CreateTexture() end
				-- eaf.texture:SetAllPoints(eaf)
				-- eaf.texture:SetTexture(gsiIcon)
				-- --增加鼠標提示
				
				-- G:FrameAppendAuraTip(eaf, "player", spellId, gsiIsDebuff)				
				-- G:FrameAppendAuraTip(eaf, "pet",    spellId,  gsiIsDebuff)				
				-- --if gsiIsDebuff then eaf:SetBackdropColor(EA_Position.RedDebuff,0,0) end
				-- --if gsiIsDebuff then eaf.texture:SetColorTexture(1.0,EA_Position.RedDebuff,EA_Position.RedDebuff) end
				
				-- if gsiIsDebuff then 
					-- eaf.texture:SetVertexColor(1.0, EA_Position.RedDebuff, EA_Position.RedDebuff) 
				-- end
				
			-- end
		-- end
	-- end	
	
	-- --
	-- G:EAFun_testLabel("PositionFrames", t0, debugprofilestop())
-- end

function G:PositionFrames()
    return G:EA_PositionFramesByIndex(1)
end