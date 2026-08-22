--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_Aura_Target.lua

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
--
------------------------------------------------------------------
function G:TarBuff_Applied(spellId)
	-- DEFAULT_CHAT_FRAME:AddMessage("buff-applying: id: "..spellId)
	-- tinsert(G.EA_TarCurrentBuffs, spellId)
	-- G.EA_TarCurrentBuffs[#G.EA_TarCurrentBuffs + 1] = spellId
	G:insertBuffValue(G.EA_TarCurrentBuffs, spellId)
	G:OnTarUpdate(spellId)
	G:TarPositionFrames()
end

------------------------------------------------------------------
--
------------------------------------------------------------------
function G:TarBuff_Dropped(spellId)
	-- DEFAULT_CHAT_FRAME:AddMessage("buff-dropping: id: "..spellId)
	local eaf = _G["EATarFrame_"..spellId]
	local spellId = tonumber(spellId)
	if eaf ~= nil then		
		G:FrameGlowShowOrHide(eaf, false)
		eaf:Hide()
		G:removeBuffValue(G.EA_TarCurrentBuffs, spellId)
		Lib_ZYF:StopOnUpdate(eaf)		
	end
	G:TarPositionFrames()
end

------------------------------------------------------------------
--
------------------------------------------------------------------
function G:TarChange_ClearFrame()
	-- local TarBuff_Dropped = G:TarBuff_Dropped
	local ibuff = #G.EA_TarCurrentBuffs
	local i
	for i = 1, ibuff do
		G:TarBuff_Dropped(G.EA_TarCurrentBuffs[1])
	end
end

------------------------------------------------------------------
--目標增減益:取得最新資訊
------------------------------------------------------------------
local tmp = {}
local buffsCurrent 	= {}
local buffsToDelete = {}    
local MAX_BUFFS = 40
function G:TarBuffs_Update(doType, ...)	      
	local t0 = debugprofilestop()
	--
	if UnitExists("target") == false then return end		
	
	wipe(buffsCurrent)
	wipe(buffsToDelete)
	local SpellEnable = false
	local OtherEnable = false
	local ifAdd_buffCur = false
	local orderWtd = 1
	-- DEFAULT_CHAT_FRAME:AddMessage("G:Buffs_Update")
	-- if (G.EA_DEBUGFLAG2) then
	--  DEFAULT_CHAT_FRAME:AddMessage("--------"..EA_XCMD_TARGETLIST.."--------")
	-- end
		
   local TarItems = EA_TarItems[G.playerClass]
   local OtherItems = EA_Items[EA_CLASS_OTHER]
   local P, T = "player", "target"
   
   local function processAura(auraData, unitId)
        if not auraData or not auraData.spellId then return false end
		
		
		if (G.EA_DEBUGFLAG2) then
		   if (G.EA_LISTSEC_TARGET == 0 or (0 < auraData.duration and auraData.duration <= G.EA_LISTSEC_TARGET)) then
			  G:EAFun_AddSpellToScrollFrame(auraData.spellId, " /\124cffFFFF00"..EA_XCMD_DEBUG_P3.."\124r:"..auraData.applications.." /\124cffFFFF00"..EA_XCMD_DEBUG_P4.."\124r:"..auraData.duration)
			  -- DEFAULT_CHAT_FRAME:AddMessage("["..i.."]\124cffFFFF00"..EA_XCMD_DEBUG_P1.."\124r:"..name..
			  --  " /\124cffFFFF00"..EA_XCMD_DEBUG_P2.."\124r:"..spellId..
			  --  " /\124cffFFFF00"..EA_XCMD_DEBUG_P3.."\124r:"..count..
			  --  " /\124cffFFFF00"..EA_XCMD_DEBUG_P4.."\124r:"..duration)
		   end
		end

        local SpellEnable = G:EAFun_GetSpellItemEnable(TarItems[auraData.spellId]) -- Check if the spell is enabled for the player (檢查法術是否為玩家啟用)
        local OtherEnable = G:EAFun_GetSpellItemEnable(OtherItems[auraData.spellId]) -- Check if the spell is enabled for general cases (檢查法術是否為通用啟用)

        local ifAdd_buffCur, orderWtd = false, 1
        if (SpellEnable) then
            -- Validate player-specific spell conditions (驗證玩家特定法術條件)
            ifAdd_buffCur, orderWtd = G:EAFun_CheckSpellConditionMatch(auraData.applications, auraData.sourceUnit, TarItems[auraData.spellId])
        elseif (OtherEnable) then
            -- Validate general spell conditions (驗證通用法術條件)
            ifAdd_buffCur, orderWtd = G:EAFun_CheckSpellConditionMatch(auraData.applications, auraData.sourceUnit, OtherItems[auraData.spellId])
        end

        if ifAdd_buffCur then
            -- Save spell information to SPELLINFO_SELF (將法術信息保存到SPELLINFO_SELF)
            G.SPELLINFO_TARGET[auraData.spellId] = {
					name 				= auraData.name, -- Spell name (法術名稱)
					icon				= auraData.icon, -- Spell icon (法術圖標)
					count 				= auraData.applications, -- Stack count (疊加層數)
					duration 			= auraData.duration, -- Duration of the buff (Buff持續時間)
					expirationTime		= auraData.expirationTime, -- Expiration time (到期時間)
					unitCaster 			= unitId, -- Caster unit (施法單位)
					isDebuff 			= auraData.isHarmful, -- Is it a debuff? (是否為Debuff？)
					orderwtd 			= orderWtd, -- Sorting weight (排序權重)
					value 				= auraData.points, -- Additional value (附加值)
					aura 				= true, -- Indicates this is a buff (標誌此為Buff)
            }
			
            buffsCurrent[#buffsCurrent + 1] = auraData.spellId -- Add spell ID to current buffs (將法術ID加入當前Buff列表)
        end
    end
	
   if (doType == "TARGET_BUFFS") then	
	  local Auras = G.Auras
	  
	  local unitId, UnitAuraUpdateInfo = ... 
	  
	  -- if (UnitAuraUpdateInfo == nil) or UnitAuraUpdateInfo.isFullUpdate then
		 -- G:UpdateAurasFull(unitId) 
	  -- else		 
		 -- G:UpdateAurasIncremental(unitId, UnitAuraUpdateInfo) 
	  -- end
	  
	  -- if (Auras[unitId] ~= nil)  then
		local auraData
		for i = 1, #BuffFrame.auraInfo do
			-- processAura(UnitAura(unitId, i, "HELPFUL"), unitId) -- Process helpful buffs (處理有益Buff)
			if auraData == nil then break end
			auraData = C_UnitAuras.GetAuraDataByIndex(unitId,i,"HELPFUL")						
			processAura(auraData, unitId) -- Process helpful buffs (處理有益Buff)			
        end	
		for i = 1, #DebuffFrame.auraInfo do
			if auraData == nil then break end			
			auraData = C_UnitAuras.GetAuraDataByIndex(unitId,i,"HARMFUL")
			processAura(auraData, unitId) -- Process helpful buffs (處理有益Buff)			
			-- processAura(UnitAura(unitId, i, "HARMFUL"), unitId) -- Process helpful buffs (處理有害Buff)			
        end	
		
	  -- if (unitId == "target") or (unitId == "pet") then
		 
		 -- local auraData		 
		 -- -- for auraInstanceID, auraData in pairs(Auras[unitId]) do 								
		 -- for i= 1, 40 do
			
			-- -- auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unitId, auraInstanceID)
			-- auraData = UnitAura(unitId, i, "HELPFUL|HARMFUL")
			
			-- -- if (auraData.spellId == nil) then break end
			-- if (auraData == nil) then break end
			
		
			-- if (G.EA_DEBUGFLAG2) then
			   -- if (G.EA_LISTSEC_TARGET == 0 or (0 < auraData.duration and auraData.duration <= G.EA_LISTSEC_TARGET)) then
				  -- G:EAFun_AddSpellToScrollFrame(auraData.spellId, " /\124cffFFFF00"..EA_XCMD_DEBUG_P3.."\124r:"..auraData.applications.." /\124cffFFFF00"..EA_XCMD_DEBUG_P4.."\124r:"..auraData.duration)
				  -- -- DEFAULT_CHAT_FRAME:AddMessage("["..i.."]\124cffFFFF00"..EA_XCMD_DEBUG_P1.."\124r:"..name..
				  -- --  " /\124cffFFFF00"..EA_XCMD_DEBUG_P2.."\124r:"..spellId..
				  -- --  " /\124cffFFFF00"..EA_XCMD_DEBUG_P3.."\124r:"..count..
				  -- --  " /\124cffFFFF00"..EA_XCMD_DEBUG_P4.."\124r:"..duration)
			   -- end
			-- end
			
			-- ifAdd_buffCur = false     		
			-- SpellEnable = G:EAFun_GetSpellItemEnable(TarItems[auraData.spellId])
			-- OtherEnable = G:EAFun_GetSpellItemEnable(OtherItems[auraData.spellId])
			
			-- if (SpellEnable) then			   
			   -- ifAdd_buffCur, orderWtd = G:EAFun_CheckSpellConditionMatch(auraData.applications, auraData.sourceUnit, TarItems[auraData.spellId])			   
			-- elseif (OtherEnable) then
			   -- -- ifAdd_buffCur = true
			   -- ifAdd_buffCur, orderWtd = G:EAFun_CheckSpellConditionMatch(auraData.applications, auraData.sourceUnit, OtherItems[auraData.spellId])	
			-- end 
			
			-- if (ifAdd_buffCur) then								
				-- G.SPELLINFO_TARGET[auraData.spellId]	=	{
													-- name				=	auraData.name,
													-- icon				=	auraData.icon,
													-- count			=	auraData.applications,
													-- duration			=	auraData.duration,
													-- expirationTime	=	auraData.expirationTime,
													-- unitCaster		=	unitId,
													-- isDebuff			=	auraData.isHarmful,
													-- orderwtd			=	orderWtd,
													-- value			=	auraData.points,
													-- aura				=	true,
													-- }
				-- -- tinsert(buffsCurrent, auraData.spellId)
				-- buffsCurrent[#buffsCurrent + 1] = auraData.spellId
				
			-- end		
		 -- end
	  -- end
   end

	--檢查指定變數是否存在於指定陣列,若有則傳回所在位置,否則傳回nil
	local function InArray(var, t)
		local i,v
		for i, v in ipairs(t) do 
			if v == var then return i end
		end
		return false
	end
	
	-- Check: Buff dropped(20240213)	
	for _, v in ipairs(G.EA_TarCurrentBuffs) do 		
		if InArray(v, buffsCurrent)==false then 
			-- tinsert(buffsToDelete, v) 
			buffsToDelete[#buffsToDelete + 1] = v
		end
	end
	
	
	-- Drop Buffs(20240213)
	for _, v in ipairs(buffsToDelete) do
		-- DEFAULT_CHAT_FRAME:AddMessage("buff-dropped: id: "..v)
		G:TarBuff_Dropped(v)
	end
	
	-- -- Drop Buffs
	-- foreach(buffsToDelete,	
		-- function(i, v)
			-- -- DEFAULT_CHAT_FRAME:AddMessage("buff-dropped: id: "..v)
			-- G:TarBuff_Dropped(v)
		-- end)
	
		
	-- Check: Buff applied
	for _, v in ipairs(buffsCurrent) do 		
		if not InArray(v, G.EA_TarCurrentBuffs) then G:TarBuff_Applied(v) end
	end	
	
	--
	G:EAFun_testLabel("TarBuffs_Update", t0, debugprofilestop())
end

------------------------------------------------------------------
--目標增減益定時更新
------------------------------------------------------------------
G.Target_Updting = table.create(50,0)
function G:OnTarUpdate(spellId)		
	local t0 = debugprofilestop()  	--
	
	if spellId and G.Target_Updting[spellId] == true then return end
	G.Target_Updting[spellId] = true
	
	if UnitExists("target") == false then G.Target_Updting[spellId] = false return end

	local eaf = _G["EATarFrame_" .. spellId]
	if not eaf then  G.Target_Updting[spellId] = false return end
		
	local info = G.SPELLINFO_TARGET[spellId]
	if not info then  G.Target_Updting[spellId] = false return end
	
	local TargetItems = EA_TarItems[G.playerClass]

	local name        = info.name
	local count       = info.count or 0
	local expiration  = info.expirationTime
	local isDebuff    = info.isDebuff	
	local now         = GetTime()
	local timeLeft    = expiration and (expiration - now) or 0	
	
	local auravalue = {}	
	if info.value then 
		for i, v in ipairs(info.value) do 
			local av = TargetItems[spellId].auravalue			
			if (av and av[i]) and av[i].enabled then 
				auravalue[i] = { v , av[i].label}  
			end  
		end  
	end
	
	--------------------
	if EA_Config.ShowTimer then
		local redSec = G:EAFun_GetSpellConditionRedSecText(EA_TarItems[G.playerClass][spellId])
		if redSec == -1 then
			redSec = G:EAFun_GetSpellConditionRedSecText(EA_Items[EA_CLASS_OTHER][spellId])
		end

		G:EAFun_SetCountdownStackText(eaf, timeLeft, count, redSec)		
	else
		eaf.spellTimer:SetText("")
		eaf.spellStack:SetText("")
	end
	--------------------	
	
	-- local ShowAuraValueWhenOver = EA_Config.ShowAuraValueWhenOver
	do
		wipe(tmp)
		if EA_Config.ShowName == true then	tinsert(tmp, name.."\n") end
		
		local value = info.value
		local av = TargetItems[spellId] and TargetItems[spellId].auravalue
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
	local overGrow = G:EAFun_CheckSpellConditionOverGrow(count, EA_TarItems[G.playerClass][spellId])
	if not overGrow then
		overGrow = G:EAFun_CheckSpellConditionOverGrow(count, EA_Items[EA_CLASS_OTHER][spellId])
	end
	
	G:FrameGlowShowOrHide(eaf, overGrow)
	G:FrameAppendAuraTip(eaf, "TARGET"	, spellId, G.SPELLINFO_TARGET[spellId].isDebuff)
		
	
	-- 目標更新
	local delay = (timeLeft > 0.1 and timeLeft < 1) and (G.UpdateInterval / 11) or G.UpdateInterval
	if G:GetUnitAuraBySpellID("TARGET", spellId) then 	
		C_Timer.After(delay, G.OnTarUpdate, G, spellId)
		-- C_Timer.After(delay, function () G:OnTarUpdate(spellId) end)
	else
		G:Buff_Dropped(spellId)
	end                             		
	--------------------
	G.Target_Updting[spellId] = false 
	--
	G:EAFun_testLabel("OnTarUpdate", t0, debugprofilestop())
end



------------------------------------------------------------------
--
------------------------------------------------------------------
-- function G:TarPositionFrames()
	-- local t0 = debugprofilestop()
	-- --
	
	-- if UnitExists("target") == false then return end 	
	
	-- if G.EA_flagAllHidden == true then EA_Main_Frame:SetAlpha(0) return end
	
	-- EA_Main_Frame:SetAlpha(1) 
	
	-- local tonumber = tonumber
	-- local type = type
	-- local ipairs = ipairs
	-- local format = format
	-- local Anchor = EA_Position.TarAnchor
	
	-- if (EA_Config.ShowFrame == true) then
		-- EA_Main_Frame:ClearAllPoints()
		-- EA_Main_Frame:SetPoint(Anchor, UIParent, EA_Position.relativePoint, EA_Position.xLoc, EA_Position.yLoc)
		-- local prevFrame = "EA_Main_Frame"
		-- local prevFrame2 = "EA_Main_Frame"
		-- local xOffset = 100 + EA_Position.xOffset
		-- local yOffset = 0 + EA_Position.yOffset
		-- local SfontName, SfontSize = "", 0
		
		-- -- G.EA_TarCurrentBuffs = G:EAFun_SortCurrBuffs2(2, G.EA_TarCurrentBuffs)
		
		-- -- table.sort(G.EA_TarCurrentBuffs, function(a, b)
			-- -- local wa = (G.SPELLINFO_TARGET[tonumber(a)] or {}).orderwtd or 1
			-- -- local wb = (G.SPELLINFO_TARGET[tonumber(b)] or {}).orderwtd or 1
			-- -- return wa < wb
		-- -- end)
		
		-- -- 用 TARGET 表
		-- table.sort(G.EA_TarCurrentBuffs, function(a, b)
			-- local A = G.SPELLINFO_TARGET[tonumber(a)]
			-- local B = G.SPELLINFO_TARGET[tonumber(b)]
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
		-- local SPELLINFO_TARGET_SPELLID
		-- local gsiName, gsiIcon, gsiValue, gsiIsDebuff		
		
		-- for i, v in ipairs(G.EA_TarCurrentBuffs) do
			-- eaf = _G["EATarFrame_"..v]
			-- spellId = tonumber(v)
			-- SPELLINFO_TARGET_SPELLID = G.SPELLINFO_TARGET[spellId]			
			-- gsiName		 = SPELLINFO_TARGET_SPELLID.name
			-- gsiIcon		 = SPELLINFO_TARGET_SPELLID.icon
			-- gsiValue	 = SPELLINFO_TARGET_SPELLID.value
			-- gsiIsDebuff	 = SPELLINFO_TARGET_SPELLID.isDebuff
			
			-- if eaf ~= nil then
				
				
				-- -- eaf:ClearAllPoints()
				-- if EA_Position.Tar_NewLine then
					-- if gsiIsDebuff then
						-- if (prevFrame == "EA_Main_Frame" or prevFrame == eaf) then
							-- prevFrame = "EA_Main_Frame"
							-- G:SetPointIfDiff(eaf, EA_Position.TarAnchor, UIParent, EA_Position.TarAnchor, EA_Position.Tar_xOffset, EA_Position.Tar_yOffset)
							-- -- eaf:SetPoint(EA_Position.TarAnchor, UIParent, EA_Position.TarAnchor, EA_Position.Tar_xOffset, EA_Position.Tar_yOffset)
						-- else
							-- -- eaf:SetPoint("CENTER", prevFrame, "CENTER", xOffset, yOffset)
							-- G:SetPointIfDiff(eaf, "CENTER", prevFrame, "CENTER", xOffset, yOffset)
						-- end
						-- prevFrame = eaf
					-- else
						-- if (prevFrame2 == "EA_Main_Frame" or prevFrame2 == eaf) then
							-- prevFrame2 = "EA_Main_Frame"
							-- if G.SpecFrame_Target then
								-- G:SetPointIfDiff(eaf, EA_Position.TarAnchor, UIParent, EA_Position.TarAnchor, EA_Position.Tar_xOffset - 2 * xOffset, EA_Position.Tar_yOffset - 2 * yOffset)
								-- -- eaf:SetPoint(EA_Position.TarAnchor, UIParent, EA_Position.TarAnchor, EA_Position.Tar_xOffset - 2 * xOffset, EA_Position.Tar_yOffset - 2 * yOffset)
								-- -- eaf:SetPoint(EA_Position.TarAnchor, prevFrame2, EA_Position.TarAnchor, -2 * xOffset, -2 * yOffset)
							-- else
								-- G:SetPointIfDiff(eaf, EA_Position.TarAnchor, UIParent, EA_Position.TarAnchor, EA_Position.Tar_xOffset - xOffset, EA_Position.Tar_yOffset - yOffset)
								-- -- eaf:SetPoint(EA_Position.TarAnchor, UIParent, EA_Position.TarAnchor, EA_Position.Tar_xOffset - xOffset, EA_Position.Tar_yOffset - yOffset)
								-- -- eaf:SetPoint(EA_Position.TarAnchor, prevFrame2, EA_Position.TarAnchor, -1 * xOffset, -1 * yOffset)
							-- end
						-- else
							-- eaf:SetPoint("CENTER", prevFrame2, "CENTER", -1 * xOffset, -1 * yOffset)
						-- end
						-- prevFrame2 = eaf
					-- end
				-- else
					-- if (prevFrame == "EA_Main_Frame" or prevFrame == eaf) then
						-- prevFrame = "EA_Main_Frame"
						-- G:SetPointIfDiff(eaf, EA_Position.Anchor, prevFrame, EA_Position.Anchor, -1 * xOffset, -1 * yOffset)
						-- -- eaf:SetPoint(EA_Position.Anchor, prevFrame, EA_Position.Anchor, -1 * xOffset, -1 * yOffset)
					-- else
						-- G:SetPointIfDiff(eaf, "CENTER", prevFrame, "CENTER", -1 * xOffset, -1 * yOffset)
						-- -- eaf:SetPoint("CENTER", prevFrame, "CENTER", -1 * xOffset, -1 * yOffset)
					-- end
				-- end
				
				
				-- eaf:SetSize(IconSize, IconSize)				
				
				-- eaf.texture = eaf.texture or eaf:CreateTexture()
				-- -- if not eaf.texture then eaf.texture = eaf:CreateTexture() end
				
				-- eaf.texture:SetAllPoints(eaf)
				-- eaf.texture:SetTexture(gsiIcon)
				
				-- --增加鼠標提示				
				-- G:FrameAppendAuraTip(eaf, "target", spellId, gsiIsDebuff)				
			
				-- if gsiIsDebuff then 
					-- eaf.texture:SetVertexColor(EA_Position.GreenDebuff, 1.0 ,EA_Position.GreenDebuff) 
				-- end					
				
			-- end
		-- end
	-- end
	
	-- --
	-- G:EAFun_testLabel("TarPositionFrames", t0, debugprofilestop())
-- end

----------------------------------------------------------------------
-- 排序＋佈局＋圖示更新（含 PiePipe 選擇）
-- ----------------------------------------------------------------------
-- function G:TarPositionFrames()
    -- local t0 = debugprofilestop()
	
	-- if UnitExists("target") == false then return end 	
	
    -- if G.EA_flagAllHidden == true then EA_Main_Frame:SetAlpha(0) return end 
    
	-- EA_Main_Frame:SetAlpha(1)

    

    -- -- 主框定位（ShowFrame 時才處理）
    -- if EA_Config.ShowFrame == true then
        -- EA_Main_Frame:ClearAllPoints()
        -- EA_Main_Frame:SetPoint(
						-- EA_Position.TarAnchor, 
						-- UIParent,
						-- EA_Position.relativePoint, 
						-- EA_Position.xLoc, 
						-- EA_Position.yLoc
						-- )

		
        -- --依照權重排序 
        -- table.sort(G.EA_TarCurrentBuffs, function(a, b)
					  -- local A = G.SPELLINFO_TARGET[tonumber(a)]
					  -- local B = G.SPELLINFO_TARGET[tonumber(b)]
					  -- local wa = (A and A.orderwtd) or 1
					  -- local wb = (B and B.orderwtd) or 1
					  -- return wa < wb
					-- end)


        -- -- 先「只做定位」：依旗標自動切換 PiePipe / Classic
        -- G:PositionFrames_SelfAuto(G.EA_TarCurrentBuffs, "EATarFrame_")

        -- -- 再跑圖示屬性與 Tooltip（避免把 UI 重排和材質同時做）
        -- local IconSize = EA_Config.IconSize
        -- local infoTbl  = G.SPELLINFO_TARGET
        -- for i = 1, #G.EA_TarCurrentBuffs do
            -- local v   = G.EA_TarCurrentBuffs[i]
            -- local eaf = _G["EATarFrame_" .. v]
            -- if eaf then
                -- local spellId = tonumber(v)
                -- local info    = infoTbl[spellId]
                -- if info then
                    -- local isDebuff = info.isDebuff
                    -- local icon     = info.icon

                    -- G:SetSizeIfDiff(eaf, IconSize, IconSize)
                    -- local tex = G:EnsureTexture(eaf, icon)
					
					 -- -- 著色（目標Debuff 染綠，目標Buff 還原白色）
                    -- if isDebuff then
                        -- tex:SetVertexColor(EA_Position.GreenDebuff, 1.0, EA_Position.GreenDebuff)
                    -- else                                    
                        -- tex:SetVertexColor(1.0, 1.0, 1.0)
                    -- end

                    -- -- Tooltip（可再做快取降頻；先維持行為一致）
                    -- G:FrameAppendAuraTip(eaf, "target", spellId, isDebuff)
                    
                -- end
            -- end
        -- end
    -- end

    -- G:EAFun_testLabel("TarPositionFrames", t0, debugprofilestop())
-- end


function G:TarPositionFrames()
    return G:EA_PositionFramesByIndex(2)
end
