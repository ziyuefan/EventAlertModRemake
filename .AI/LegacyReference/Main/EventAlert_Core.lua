--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_Core.lua

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
local UnitBuff 					= C_UnitAuras.GetBuffDataByIndex
local UnitDebuff 				= C_UnitAuras.GetDebuffDataByIndex
local UnitAura 					= C_UnitAuras.GetAuraDataByIndex
local UnitPower 				= UnitPower
local UnitPowerMax 				= UnitPowerMax
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
local InCombatLockdown			= InCombatLockdown

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


--------------------------------
-- EventAlertMod Var. 
--------------------------------
-- local EA_SPEC_expirationTime1 = 0
-- local EA_SPEC_expirationTime2 = 0
G.LISTSEC 	= 	{	SELF 	= 0, TARGET 	= 0,}
				
G.SPEC		=	{expirationTime = {[1] = 0,[2] = 0}	}
--------------------------------
local EA_FormType_FirstTimeCheck = true
local EA_ADDONS_NAME = addonName
G.EA_flagAllHidden = false

--------------------------------
G.DEBUG = {}
--------------------------------   
G.TEST = {}									  
--------------------------------
-- For OnUpdate Using, only Gloabal Var.
--------------------------------             
G.UpdateInterval						= 1
--------------------------------
-- The first event of this UI(Event sequence : "Onload"->"ADDON_LOADED")
------------------------------
function G:OnLoad(f)

	G.EventList_COMBAT_LOG_EVENT_UNFILTERED = {
		["SPELL_AURA_REFRESH"]			= G.COMBAT_LOG_EVENT_SPELL_AURA_REFRESH,
		["SPELL_SUMMON"]				= G.COMBAT_LOG_EVENT_SPELL_SUMMON,
		["SPELL_CAST_SUCCESS"]			= G.COMBAT_LOG_EVENT_SPELL_CAST_SUCCESS,
	}
	G.EventList = {         							
		["ADDON_LOADED"]					= G.ADDON_LOADED,
		-- ["VARIABLES_LOADED"]             = G.VARIABLES_LOADED,		
		["PLAYER_LOGIN"]					= G.PLAYER_LOGIN,
		["PLAYER_ENTERING_WORLD"]			= G.PLAYER_ENTERING_WORLD,
		["PLAYER_DEAD"]						= G.PLAYER_ENTERING_WORLD,
		["PLAYER_ENTER_COMBAT"]				= G.PLAYER_ENTER_COMBAT,
		["PLAYER_LEAVE_COMBAT"]				= G.PLAYER_LEAVE_COMBAT,
		["PLAYER_REGEN_DISABLED"]			= G.PLAYER_ENTER_COMBAT,
		["PLAYER_REGEN_ENABLED"]			= G.PLAYER_LEAVE_COMBAT,
		["PLAYER_TALENT_UPDATE"]			= G.PLAYER_TALENT_UPDATE,
		-- ["PLAYER_TALENT_WIPE"]			= G.PLAYER_TALENT_WIPE,
		["PLAYER_TARGET_CHANGED"]			= G.TARGET_CHANGED,
		["ACTIVE_TALENT_GROUP_CHANGED"]		= G.ACTIVE_TALENT_GROUP_CHANGED,
		["COMBAT_LOG_EVENT_UNFILTERED"]		= G.COMBAT_LOG_EVENT_UNFILTERED ,
		--["COMBAT_TEXT_UPDATE"]			= G.COMBAT_TEXT_UPDATE,		
		["SPELL_UPDATE_COOLDOWN"]			= G.SPELL_UPDATE_COOLDOWN,
		["SPELL_UPDATE_CHARGES"]			= G.SPELL_UPDATE_CHARGES,
		["SPELL_UPDATE_USABLE"]				= G.SPELL_UPDATE_USABLE,
		["ACTIONBAR_UPDATE_COOLDOWN"]		= G.ACTIONBAR_UPDATE_COOLDOWN,
		["ACTIONBAR_UPDATE_STATE"]			= G.ACTIONBAR_UPDATE_COOLDOWN,
		["PLAYER_TOTEM_UPDATE"]				= G.PLAYER_TOTEM_UPDATE,
		
		
		
		["UPDATE_SHAPESHIFT_FORM"]			= G.UPDATE_SHAPESHIFT_FORM,
		
		["UNIT_SPELLCAST_START"]			= G.UNIT_SPELLCAST_START,
		["UNIT_SPELLCAST_CHANNEL_START"]	= G.UNIT_SPELLCAST_CHANNEL_START,
		["UNIT_SPELLCAST_FAILED"]			= G.UNIT_SPELLCAST_FAILED,
		
		["UNIT_AURA"]						= G.UNIT_AURA,		
	--	["UNIT_COMBO_POINTS"]				= G.COMBO_POINTS,
		["UNIT_DISPLAYPOWER"]				= G.DISPLAYPOWER,
		["UNIT_HEALTH"]						= G.UNIT_HEALTH	,
		["UNIT_POWER_UPDATE"]				= G.UNIT_POWER_UPDATE,
		["UNIT_POWER_FREQUENT"]				= G.UNIT_POWER_UPDATE,
		["RUNE_TYPE_UPDATE"]				= G.RUNE_TYPE_UPDATE,
		["RUNE_POWER_UPDATE"]				= G.RUNE_POWER_UPDATE,
		["UNIT_SPELLCAST_SUCCEEDED"]		= G.UNIT_SPELLCAST_SUCCEEDED,		
		["UNIT_SPELLCAST_SENT"]				= G.UNIT_SPELLCAST_SENT,		
		["PLAYER_TOTEM_UPDATE"]				= G.UNIT_PLAYER_TOTEM_UPDATE,	
		["BAG_UPDATE_COOLDOWN"]				= G.BAG_UPDATE_COOLDOWN,		
		["UPDATE_UI_WIDGET"]				= G.UPDATE_UI_WIDGET,		
		["UNIT_SPELLCAST_EMPOWER_START"]	= G.EMPOWER_START,
		["UNIT_SPELLCAST_EMPOWER_UPDATE"]	= G.EMPOWER_UPDATE,
	}
	
	-- local event, func	
	-- for event, func in pairs(self.EventList) do		
	
		-- --若事件不存在就不註冊事件
		-- local success,err = pcall( function() f:RegisterEvent(event) end )
		
		-- if success then f:SetScript("OnEvent", function(self, event, ...)
				-- func = G.EventList[event]
				-- if type(func) == "function" then 
					-- func(self, event, ...)
				-- end
			-- end)
		-- end
	-- end
	
	
		-- 1. 建立同一個 Frame
		local eventFrame = f or CreateFrame("Frame", nil, nil)
		
		
		
		-- 2. 批次註冊事件
		for evt, handler in pairs(G.EventList) do		
			-- 使用 pcall 安全註冊，避免單一錯誤中斷整個註冊流程
			local ok, err = pcall(eventFrame.RegisterEvent, eventFrame, evt)
			if not ok then
				print("[EventAlertMod] 無法註冊事件", evt, err)
			end
		end
		

		-- 3. 統一 OnEvent 分派，減少重複設置 Script
		--    並做錯誤捕捉與平滑 GC
		eventFrame:SetScript("OnEvent", function(self, event, ...)
			local func = G.EventList[event]
			if type(func) == "function" then
				-- 防止 handler 重入
				if not self._flagRunning then
					self._flagRunning = true
					func(self,event,...)
					-- local ok, err = pcall(func, self, event, ...)
					-- if not ok then
						-- print("[EventAlertMod] 事件處理錯誤", event, err)
					-- end                            
					
					self._flagRunning = false
					
				end
			end
		end)
	
		if G.OnKeyDown then
			eventFrame:SetScript("OnKeyDown", G.OnKeyDown) 
		else
			print("Error: G.OnKeyDown function not found!")
		end
		
	-- Init Slash Command as function name 
	G:InitSlashCommand()
	-- Init Main Array
	-- G:InitArray()		
	 
	 local tempInterval = G.UpdateInterval 
	 -- Lib_ZYF:SetOnUpdate(tempInterval, G.Icon_Options_Frame_AdjustTimerFontSize)	

		G.Ticker = {}		
		-- G.Ticker.PositionFrames 	= C_Timer.NewTicker(tempInterval, G.PositionFrames)		
		-- G.Ticker.TarPositionFrames 	= C_Timer.NewTicker(tempInterval, G.TarPositionFrames)
		-- G.Ticker.ScdPositionFrames	= C_Timer.NewTicker(tempInterval, G.ScdPositionFrames)
		-- G.Ticker.SpecialFrame  		= C_Timer.NewTicker(tempInterval, G.SpecialFrame_Update)
		
		
		-- G.Ticker.PositionFrames 		=	Lib_ZYF:SetOnUpdate(tempInterval*1.5, G.PositionFrames)
		-- G.Ticker.TarPositionFrames 		=	Lib_ZYF:SetOnUpdate(tempInterval*1.5, G.TarPositionFrames)
		-- G.Ticker.ScdPositionFrames		=	Lib_ZYF:SetOnUpdate(tempInterval*1.5, G.ScdPositionFrames)	
		-- G.Ticker.SpecialFrame  			=	Lib_ZYF:SetOnUpdate(tempInterval*1.5, G.SpecialFrame_Update)
		local function RecurringFrameUpdate()
			G:PositionFrames()
			G:TarPositionFrames()
			G:ScdPositionFrames()
			G:SpecialFrame_Update()
			
			if GetFramerate() > 30 then
				C_Timer.After(tempInterval*1,	 RecurringFrameUpdate)
			else
				C_Timer.After(tempInterval*1.5,	 RecurringFrameUpdate)
			end
		end

		-- 啟動用
		C_Timer.After(tempInterval, RecurringFrameUpdate)
		
	-- Next Event : ADDON_LOADED
end
------------------------------------------------------------------
--ESC鍵隱藏
------------------------------------------------------------------
function G:OnKeyDown(key)		
	if (EA_Config.AllowESC == true ) then
		if (key == "ESCAPE") and (G.EA_flagAllHidden == true) then			
			EA_Main_Frame:SetAlpha(1)
			G.EA_flagAllHidden = false
			
		elseif (key == "ESCAPE") and (G.EA_flagAllHidden == false) then
			--若使用Hide()隱藏將導致無法接受鍵盤事件,所以只能改用調整透明度為0以保持事件偵測
			EA_Main_Frame:SetAlpha(0)
			G.EA_flagAllHidden = true
			
		end		
	end
	--此行重要,防止按鍵卡在此函數,無法讓遊戲其他UI吃到按鍵
	--self:SetPropagateKeyboardInput(true)
end

--------------------------------
-- If 'OnLoad' event had loaded, then excute this 'ADDON_LOADED' event.
--------------------------------
function G:ADDON_LOADED(event, ...)
     local arg1, arg2 = ...
	
     if (arg1 == EA_ADDONS_NAME) then

          G.localizedPlayerClass, G.playerClass = UnitClass("player")
		  
		  G:LoadSpellArray()

          if G.WOW_VERSION >= 100000 then
               G:EAFun_DealTooltips()
          else
               G:EAFun_HookTooltips()               
          end
     end
end

function G:PLAYER_LOGIN(event, ...)			
          
          G:VersionCheck()
          DEFAULT_CHAT_FRAME:AddMessage(EA_XLOAD_LOAD..EA_Config.Version.."\124r")          
		  
          G:InitArrayConfig()
          G:InitArrayPosition()
          G:InitArrayPos()
		  
          if (EA_Config.ShareSettings ~= true) then
               EA_Position = G.Pos[G.playerClass]
               if EA_Position.Tar_NewLine == nil then EA_Position.Tar_NewLine = true end
               if EA_Position.Execution == nil then EA_Position.Execution = 0 end
               if EA_Position.PlayerLv2BOSS == nil then EA_Position.PlayerLv2BOSS = true end
          end
		  
		  G:Options_Init()
		   
		  G:Icon_Options_Frame_Init()
		-- G:Icon_Options_Frame_Init()
		--G:Class_Events_Frame_Init()
		--G:Other_Events_Frame_Init()
		--G:Target_Events_Frame_Init()
		--G:SCD_Events_Frame_Init()
		--G:Group_Events_Frame_Init()
		
		  G:CreateFrames()
		  
		  G:InitArraySpecCheckPower()
		
end
------------------------------------------------------------------
-- 
------------------------------------------------------------------
function G:SetNewValue(tbl, key, value) 
		
		if (type(tbl) == "table") and (type(key) == "string") then
			if tbl[key] == nil then 
				tbl[key] = value 
			end
		end
	end
	
------------------------------------------------------------------
--
------------------------------------------------------------------
function G:InitArrayConfig()	

	
	--若存檔(EA_Config)無紀錄,就從預設值(EA_Config2)複製一份
	for k, v in pairs(EA_Config2) do
		if EA_Config[k] == nil then 
			EA_Config[k] = EA_Config2[k]		
		end
	end	   	
	
	--第一次執行預設值
	G:SetNewValue(EA_Config, "AlertSound", 				568154)
	G:SetNewValue(EA_Config, "AlertSoundValue",			1)
	G:SetNewValue(EA_Config, "DoAlertSound",			true)
	G:SetNewValue(EA_Config, "LockFrame",				false)
	G:SetNewValue(EA_Config, "ShareSettings",			true)
	G:SetNewValue(EA_Config, "ShowFrame", 				true)
	G:SetNewValue(EA_Config, "ShowTimer", 				true)
	G:SetNewValue(EA_Config, "ShowFlash", 				true)
	G:SetNewValue(EA_Config, "ShowTimer",				true)
	G:SetNewValue(EA_Config, "IconSize",				45)
	G:SetNewValue(EA_Config, "ChangeTimer", 			true)
	G:SetNewValue(EA_Config, "AllowESC",				false)
	G:SetNewValue(EA_Config, "AllowAltAlerts",			false)
	G:SetNewValue(EA_Config, "Target_MyDebuff",			true)
	G:SetNewValue(EA_Config, "NewLineByIconCount",		0)
	
	G:SetNewValue(EA_Config, "TimerFontSize",			25)	
	G:SetNewValue(EA_Config, "StackFontSize",			15)	
	G:SetNewValue(EA_Config, "SNameFontSize",			15)		
	
	--調整字形尺寸
	-- G:Icon_Options_Frame_AdjustTimerFontSize()
	
	--以協程建立物品法術對應快取表
	
	--G:CreateSpellItemCache()
	
end
------------------------------------------------------------------
--
------------------------------------------------------------------
function G:InitArrayPosition()	
	
	
	EA_Position = EA_Position or {}
	
	G:SetNewValue(EA_Position,	"Anchor",			"CENTER"	)
	G:SetNewValue(EA_Position,	"relativePoint",	"CENTER"	)	
	G:SetNewValue(EA_Position,	"xLoc",				0			)
	G:SetNewValue(EA_Position,	"yLoc",				-140		)
	G:SetNewValue(EA_Position,	"xOffset", 			-40			)
	G:SetNewValue(EA_Position,	"yOffset", 			0			)
	
	G:SetNewValue(EA_Position,	"RedDebuff",		0.5			)
	G:SetNewValue(EA_Position,	"GreenDebuff", 		0.5			)
	
	G:SetNewValue(EA_Position,	"Tar_NewLine", 		true		)
	G:SetNewValue(EA_Position,	"TarAnchor", 		"CENTER"	)
	G:SetNewValue(EA_Position,	"TarrelativePoint",	"CENTER"	)
	G:SetNewValue(EA_Position,	"Tar_xOffset", 		0			)
	G:SetNewValue(EA_Position,	"Tar_yOffset", 		-220		)
	
	G:SetNewValue(EA_Position,	"ScdAnchor", 		"CENTER"	)
	G:SetNewValue(EA_Position,	"Scd_xOffset", 		0			)
	G:SetNewValue(EA_Position,	"Scd_yOffset", 		80			)
	G:SetNewValue(EA_Position,	"Execution", 		0			)
	G:SetNewValue(EA_Position,	"PlayerLv2BOSS",	true		)
	G:SetNewValue(EA_Position,	"SCD_UseCooldown", 	true		)
		
	-- if EA_Position.Anchor == nil then EA_Position.Anchor = "CENTER" end
	-- if EA_Position.relativePoint == nil then EA_Position.relativePoint = "CENTER" end
	-- if EA_Position.xLoc == nil then EA_Position.xLoc = 0 end
	-- if EA_Position.yLoc == nil then EA_Position.yLoc = -140 end
	-- if EA_Position.xOffset == nil then EA_Position.xOffset = -40 end
	-- if EA_Position.yOffset == nil then EA_Position.yOffset = 0 end
	-- if EA_Position.RedDebuff == nil then EA_Position.RedDebuff = 0.5 end
	-- if EA_Position.GreenDebuff == nil then EA_Position.GreenDebuff = 0.5 end
	-- if EA_Position.Tar_NewLine == nil then EA_Position.Tar_NewLine = true end
	-- if EA_Position.TarAnchor == nil then EA_Position.TarAnchor = "CENTER" end
	-- if EA_Position.TarrelativePoint == nil then EA_Position.TarrelativePoint = "CENTER" end
	-- if EA_Position.Tar_xOffset == nil then EA_Position.Tar_xOffset = 0 end
	-- if EA_Position.Tar_yOffset == nil then EA_Position.Tar_yOffset = -220 end
	-- if EA_Position.ScdAnchor == nil then EA_Position.ScdAnchor = "CENTER" end
	-- if EA_Position.Scd_xOffset == nil then EA_Position.Scd_xOffset = 0 end
	-- if EA_Position.Scd_yOffset == nil then EA_Position.Scd_yOffset = 80 end
	-- if EA_Position.Execution == nil then EA_Position.Execution = 0 end
	-- if EA_Position.PlayerLv2BOSS == nil then EA_Position.PlayerLv2BOSS = true end
	-- if EA_Position.SCD_UseCooldown == nil then EA_Position.SCD_UseCooldown = false end
end
------------------------------------------------------------------
--
------------------------------------------------------------------
function G:InitArrayPos()	
	
	G.Pos = G.Pos or {}
	G:SetNewValue(G.Pos,	EA_CLASS_DK,				EA_Position)
	G:SetNewValue(G.Pos,	EA_CLASS_DRUID,				EA_Position)
	G:SetNewValue(G.Pos,	EA_CLASS_HUNTER,			EA_Position)
	G:SetNewValue(G.Pos,	EA_CLASS_MAGE,				EA_Position)
	G:SetNewValue(G.Pos,	EA_CLASS_PALADIN,			EA_Position)
	G:SetNewValue(G.Pos,	EA_CLASS_PRIEST,			EA_Position)
	G:SetNewValue(G.Pos,	EA_CLASS_ROGUE,				EA_Position)
	G:SetNewValue(G.Pos,	EA_CLASS_SHAMAN,			EA_Position)
	G:SetNewValue(G.Pos,	EA_CLASS_WARLOCK,			EA_Position)
	G:SetNewValue(G.Pos,	EA_CLASS_WARRIOR,			EA_Position)
	G:SetNewValue(G.Pos,	EA_CLASS_MONK,				EA_Position)
	G:SetNewValue(G.Pos,	EA_CLASS_DEMONHUNTER,		EA_Position)
	G:SetNewValue(G.Pos,	EA_CLASS_EVOKER,			EA_Position)
	
     -- if EA_Pos == nil then EA_Pos = { } end
     -- if EA_Pos[EA_CLASS_DK] == nil then EA_Pos[EA_CLASS_DK] = EA_Position end
     -- if EA_Pos[EA_CLASS_DRUID] == nil then EA_Pos[EA_CLASS_DRUID] = EA_Position end
     -- if EA_Pos[EA_CLASS_HUNTER] == nil then EA_Pos[EA_CLASS_HUNTER] = EA_Position end
     -- if EA_Pos[EA_CLASS_MAGE] == nil then EA_Pos[EA_CLASS_MAGE] = EA_Position end
     -- if EA_Pos[EA_CLASS_PALADIN] == nil then EA_Pos[EA_CLASS_PALADIN] = EA_Position end
     -- if EA_Pos[EA_CLASS_PRIEST] == nil then EA_Pos[EA_CLASS_PRIEST] = EA_Position end
     -- if EA_Pos[EA_CLASS_ROGUE] == nil then EA_Pos[EA_CLASS_ROGUE] = EA_Position end
     -- if EA_Pos[EA_CLASS_SHAMAN] == nil then EA_Pos[EA_CLASS_SHAMAN] = EA_Position end
     -- if EA_Pos[EA_CLASS_WARLOCK] == nil then EA_Pos[EA_CLASS_WARLOCK] = EA_Position end
     -- if EA_Pos[EA_CLASS_WARRIOR] == nil then EA_Pos[EA_CLASS_WARRIOR] = EA_Position end
     -- if EA_Pos[EA_CLASS_MONK] == nil then EA_Pos[EA_CLASS_MONK] = EA_Position end
     -- if EA_Pos[EA_CLASS_DEMONHUNTER] == nil then EA_Pos[EA_CLASS_DEMONHUNTER] = EA_Position end
end
------------------------------------------------------------------
--
------------------------------------------------------------------
function G:InitArraySpecCheckPower()
     if EA_Config.SpecPowerCheck == nil then EA_Config.SpecPowerCheck = {} end
     for k,v in pairs(EA_SpecPower) do
          if EA_Config.SpecPowerCheck[k] == nil then
               EA_Config.SpecPowerCheck[k] = false
          end
     end
end

------------------------------------------------------------------
---
------------------------------------------------------------------

------------------------------------------------------------------
---事件:玩家進入戰鬥
------------------------------------------------------------------
function G:PLAYER_ENTER_COMBAT(event, ...)
     G:ShowAllScdCurrentBuff()
	 -- collectgarbage("stop")
end
------------------------------------------------------------------
---事件:玩家離開戰鬥
------------------------------------------------------------------
function G:PLAYER_LEAVE_COMBAT(event, ...)	
     if EA_Config.SCD_NocombatStillKeep == false then
          G:HideAllScdCurrentBuff()
     end
end
------------------------------------------------------------------
---事件:玩家進入遊戲世界
------------------------------------------------------------------
function G:PLAYER_ENTERING_WORLD(event, ...)

	 

     local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = ...
	

     G:PlayerSpecPower_Update()

     for p,tblPower in pairs(EA_SpecPower) do
          if (tblPower.func) and (EA_Config.SpecPowerCheck[k]) and (tblPower.has) then
               if (tblPower.powerId) then
                    tblPower.func(tblPower.powerId)
               else
                    tblPower.func()
               end
          end
     end  

     local v = foreach(G.EA_CurrentBuffs, function(i, v) if v==arg9 then return v end end)
     if v then
          local f = _G["EAFrame_"..v]
          f:Hide()
          G.EA_CurrentBuffs = wipe(G.EA_CurrentBuffs) 
     end
     G.ClassAltSpellName = G.ClassAltSpellName or {}

     local DoesSpellExist = C_Spell.DoesSpellExist     
     for i,v in pairs(EA_AltItems[G.playerClass]) do
          if DoesSpellExist(i) then
				local spellInfo = GetSpellInfo(i)
				--WOW 11.0 new GetSpellInfo , it return a table.
				if type(spellInfo) == "table" then
					G.ClassAltSpellName[spellInfo.name] = tonumber(i)
				else
					G.ClassAltSpellName[spellInfo] = tonumber(i)
				end
          end
     end
end
------------------------------------------------------------------
--- 事件:玩家變換目標
------------------------------------------------------------------
function G:TARGET_CHANGED(event, ...)
     G:TarChange_ClearFrame()
     if UnitName("player") ~= UnitName("target") then
		  G.Auras = G.Auras or {}
          G.Auras["target"] = {}
          G:TarBuffs_Update("TARGET_BUFFS", "target")
          if (EA_Config.SpecPowerCheck.ComboPoints and EA_SpecPower.ComboPoints.has) then
               G:UpdateComboPoints()
          end
          G:CheckExecution()
     end
end
------------------------------------------------------------------
--- 事件:某單位成功施放技能
------------------------------------------------------------------
function G:UNIT_SPELLCAST_SUCCEEDED(event, ...)     
	 local unitCaster, castGUID, spellId = ...	 	 
     local spellName = GetSpellInfo(spellId)
	 local surName = UnitName(unitCaster)	 
	 
     G:ScdBuffs_Update(surName, spellName, spellId, GetTime())	
	
end
------------------------------------------------------------------
--- 事件:某單位開始施放技能
------------------------------------------------------------------
function G:UNIT_SPELLCAST_SENT(event, ...)     
	 local unitPlayer, unitTarget, castGUID, spellId = ...	 	 
     local spellName = GetSpellInfo(spellId)
	 local surName = UnitName(unitPlayer)	
	 
     G:ScdBuffs_Update(surName, spellName, spellId, GetTime())
	 
end
------------------------------------------------------------------
--- 戰鬥事件(CLEU)
------------------------------------------------------------------
-- EventAlertMod COMBAT_LOG_EVENT_UNFILTERED 處理函式
-- 此程式碼由 OpenAI o4-mini 模型產生

-- 在登入時緩存玩家 GUID 與名稱，供後續使用
G.PlayerGUID = G.PlayerGUID or UnitGUID("player")
G.PlayerName = G.PlayerName or UnitName("player")

function G:COMBAT_LOG_EVENT_UNFILTERED()

	
	local t0 = debugprofilestop()
	
	
	
    -- 一次取得所有參數
    local timestamp, subEvent, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID,   destName,   destFlags,   destRaidFlags,
          spellId,    spellName   = CombatLogGetCurrentEventInfo()

    -- 僅處理來源為玩家、自身寵物或當前目標
    if sourceGUID ~= G.PlayerGUID
       and sourceGUID ~= UnitGUID("pet")
       and sourceGUID ~= UnitGUID("target") then
        return
    end

    -- 轉成數字並快速排除無效 ID
    local sid = tonumber(spellId)
    if not (sid and sid > 0 and sid < (10^7 -1)) then
        return
    end

    -- 只處理有註冊 handler 的事件
    local handler = G.EventList_COMBAT_LOG_EVENT_UNFILTERED[subEvent]
    if handler then
        -- 安全呼叫，捕捉錯誤不影響主流程
        local ok, err = pcall(handler,
            timestamp, subEvent, hideCaster,
            sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
            destGUID, destName, destFlags, destRaidFlags,
            sid, spellName
        )
        if not ok then
            -- 可改為記錄日誌或 UI 提示
            print("[EventAlertMod] 處理錯誤：", err)
        end
    end

    -- Druid LifeBloom 特例，只在 SPELL_AURA_APPLIED 時處理
    if subEvent == "SPELL_AURA_APPLIED"
       and G.playerClass == EA_CLASS_DRUID
       and EA_Config.SpecPowerCheck.LifeBloom
       and EA_SpecPower.LifeBloom.has
       -- and UnitPower("player", 8) == 0
       and sourceName == G.PlayerName
       and sid == 33763
    then
        -- 去掉伺服器名
        local dst = destName and strsplit("-", destName, 2) or nil
        local unitID
        if dst == G.PlayerName then
            unitID = "player"
        elseif dst == G.SpecFrame_LifeBloom.UnitName then
            unitID = G.SpecFrame_LifeBloom.UnitID
        else
            unitID = G:EAFun_GetUnitIDByName(dst)
        end
        if unitID then
            G:UpdateLifeBloom(unitID)
        end
    end
	
	 -- 記錄效能
    G:EAFun_testLabel("COMBAT_LOG_EVENT_UNFILTERED", t0, debugprofilestop())
end


-- function G:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
     -- local 	timestp,
     -- event,
     -- hideCaster,
     -- surGUID,
     -- surName,
     -- surFlags,
     -- surRaidFlags,
     -- dstGUID,
     -- dstName,
     -- dstFlags,
     -- dstRaidFlags,
     -- spellId,
     -- spellName = CombatLogGetCurrentEventInfo()

     -- local f = G.EventList_COMBAT_LOG_EVENT_UNFILTERED[event]

     -- if type(f) == "function" then 
		-- f(CombatLogGetCurrentEventInfo()) 
	 -- end
	 
     -- spellId = tonumber(spellId)
     -- if (dstName ~= nil) then dstName = strsplit("-", dstName, 2) end
     -- if ((spellId ~= nil) and (spellId > 0 and spellId < 10000000)) then
          -- -- "/ea showc" will also display in this function
          
		  -- -- G:ScdBuffs_Update(surName, spellName, spellId, timestp) -- WOW 4.1 Change with spellId
		  
          -- local iUnitPower = UnitPower("player", 8)
          -- if (G.playerClass == EA_CLASS_DRUID and EA_Config.SpecPowerCheck.LifeBloom and EA_SpecPower.LifeBloom.has and iUnitPower == 0) then
               -- local EA_PlayerName = UnitName("player")
               -- if (surName == EA_PlayerName and spellId == 33763 and dstName ~= nil) then
                    -- -- print ("tar="..arg8.." /spid="..arg10)
                    -- local EA_UnitID = ""
                    -- if (dstName == EA_PlayerName) then
                         -- EA_UnitID = "player"
                    -- elseif dstName == G.SpecFrame_LifeBloom.UnitName then
                         -- EA_UnitID = G.SpecFrame_LifeBloom.UnitID
                    -- else
                         -- EA_UnitID = G:EAFun_GetUnitIDByName(dstName)
                    -- end
                    -- G:UpdateLifeBloom(EA_UnitID)
               -- end
          -- end
          -- --if (G.playerClass == EA_CLASS_DK) then
          -- --G:UpdateRunes()
          -- --end
     -- end
	 
-- end
------------------------------------------------------------------
---戰鬥子事件:光環更新
------------------------------------------------------------------
function G:COMBAT_LOG_EVENT_SPELL_AURA_REFRESH(...)
	  
	-- local 	timestp, event, hideCaster, 
			-- surGUID, surName, surFlags, surRaidFlags, 
			-- dstGUID, dstName, dstFlags, dstRaidFlags, 
			-- spellId, spellName = CombatLogGetCurrentEventInfo()
	
	-- -- 此段開了會不斷閃爍
	-- if (dstGUID == UnitGUID("player")) 		then
		-- G:Buffs_Update("PLAYER_BUFFS", "player")
	-- elseif 	(dstGUID == UnitGUID("pet"))	then
		-- G:Buffs_Update("PET_BUFFS", "pet")
	-- elseif 	(dstGUID == UnitGUID("target"))	then
		-- G:TarBuffs_Update("TARGET_BUFFS", "target")
	-- end	
end
------------------------------------------------------------------
---戰鬥子事件:成功施放技能
------------------------------------------------------------------
function G:COMBAT_LOG_EVENT_SPELL_CAST_SUCCESS(...)     
	
	-- 一次取得所有參數
    local timestamp, subEvent, hideCaster,
          sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID,   destName,   destFlags,   destRaidFlags,
          spellId,    spellName   = ...
	 
     -- G:ScdBuffs_Update(sourceName, spellName, spellId, timestamp )
	 -- 安全呼叫，捕捉錯誤不影響主流程
        local ok, err = pcall( G.ScdBuffs_Update, G,  sourceName, spellName, spellId, timestamp)
        if not ok then
            -- 若需要可改成寫到日誌或 UI 提示
            print("EventAlertMod 處理錯誤：", err)
        end
		
	 -- G:Buffs_Update("SPELL_DURATION", CombatLogGetCurrentEventInfo())
	 -- 安全呼叫，捕捉錯誤不影響主流程
        local ok, err = pcall(G.Buffs_Update, G,  "SPELL_DURATION", CombatLogGetCurrentEventInfo() )        
        if not ok then
            -- 若需要可改成寫到日誌或 UI 提示
            print("EventAlertMod 處理錯誤：", err)
        end
		
     
	 
	-- local tmpSpellID	
	-- tmpSpellID = select(2, GetItemSpell(GetInventoryItemID("player",13)))
	-- if tmpSpellID then 
		-- G:ScdBuffs_Update("player",GetSpellInfo(tmpSpellID), tmpSpellID, GetTime())
	-- end 	
	
	-- tmpSpellID = select(2,GetItemSpell(GetInventoryItemID("player",14)))
	-- if tmpSpellID then
		-- G:ScdBuffs_Update("player", GetSpellInfo(tmpSpellID), tmpSpellID, GetTime())
	-- end
	
end
------------------------------------------------------------------
--- 戰鬥子事件:召喚
------------------------------------------------------------------
function G:COMBAT_LOG_EVENT_SPELL_SUMMON(...)
     local 	timestp, event, hideCaster,
     surGUID, surName, surFlags, surRaidFlags,
     dstGUID, dstName, dstFlags, dstRaidFlags,
     spellId, spellName = ...

     G:Buffs_Update("SPELL_SUMMON", ... )

     --若 /eam showc 啟用，則也顯示招喚圖騰型法術ID
     if (G.EA_DEBUGFLAG3) then
          sSpellLink = GetSpellLink(spellId)
          if (sSpellLink ~= nil) then
               -- DEFAULT_CHAT_FRAME:AddMessage("\124cffFFFF00"..EA_XCMD_DEBUG_P2.."\124r="..EA_spellId.." / \124cffFFFF00"..EA_XCMD_DEBUG_P1.."\124r="..sSpellLink)
               G:EAFun_AddSpellToScrollFrame(spellId, "")
               print("SUMMON SPELL ID:",spellId, sSpellLink)
          end
     end
	 
end
-----------------------------------------------------------
--- 事件:圖騰更新
------------------------------------------------------------------
function G:PLAYER_TOTEM_UPDATE(event, totemIndex)
	--print(totemIndex)
	G:Buffs_Update("TOTEM_BUFFS", totemIndex)
end
------------------------------------------------------------------
--- 事件:光環新增、移除、更新
------------------------------------------------------------------
function G:UNIT_AURA(event, ...)
	local functionStartTime = debugprofilestop()
	--

   local unitId , unpdateInfo = ...	      
	
   if (unitId == "player") 	then	G:Buffs_Update("PLAYER_BUFFS", 		...)	end
   if (unitId == "pet")		then	G:Buffs_Update("PET_BUFFS",		 	...)	end   
   if (unitId == "target") 	then	G:TarBuffs_Update("TARGET_BUFFS",	...)	end
	
	if (EA_FormType_FirstTimeCheck) then
		--DEFAULT_CHAT_FRAME:AddMessage("First time check FormType")
		G:PlayerSpecPower_Update()
		EA_FormType_FirstTimeCheck = false
	end
	
	--
	G:EAFun_testLabel("UNIT_AURA", functionStartTime ,debugprofilestop())
end
------------------------------------------------------------------
---事件:戰鬥文字更新
------------------------------------------------------------------
-- function G:COMBAT_TEXT_UPDATE(self, event, ...)
	-- local arg1, arg2 = ...
	-- if (arg1 == "SPELL_ACTIVE") then
		-- G:COMBAT_TEXT_SPELL_ACTIVE(arg2)
	-- end
-- end
------------------------------------------------------------------
---事件:連擊點數更新
------------------------------------------------------------------
function G:UNIT_COMBO_POINTS(event, ...)
	local functionStartTime = debugprofilestop()
	--	
	if (EA_Config.SpecPowerCheck.ComboPoints and EA_SpecPower.ComboPoints.has) then
		G:UpdateComboPoints()
	end
	--
	G:EAFun_testLabel("UNIT_COMBO_POINTS", functionStartTime ,debugprofilestop())
end
------------------------------------------------------------------
--- 事件:血量更新
------------------------------------------------------------------
function G:UNIT_HEALTH(event, ...)
	local functionStartTime = debugprofilestop()
	--	
		local arg1 = ...
		if arg1 == "target" then
			G:CheckExecution()
		end
	--
	G:EAFun_testLabel("UNIT_HEALTH", functionStartTime ,debugprofilestop())
end
------------------------------------------------------------------
---事件:開始詠唱法術
------------------------------------------------------------------
function G:UNIT_SPELLCAST_START(event, unitCaster, CastGUID, spellId)
	if (G.EA_DEBUGFLAG3) then
		sSpellLink = GetSpellLink(spellId)
		--if (sSpellLink ~= nil) then
			-- DEFAULT_CHAT_FRAME:AddMessage("\124cffFFFF00"..EA_XCMD_DEBUG_P2.."\124r="..EA_spellId.." / \124cffFFFF00"..EA_XCMD_DEBUG_P1.."\124r="..sSpellLink)
			G:EAFun_AddSpellToScrollFrame(spellId, "")
		--end
	end
end
------------------------------------------------------------------
---事件:開始引導法術
------------------------------------------------------------------
function G:UNIT_SPELLCAST_CHANNEL_START(event, unitCaster, CastGUID, spellId)
	if (G.EA_DEBUGFLAG3) then
		sSpellLink = GetSpellLink(spellId)
		--if (sSpellLink ~= nil) then
			-- DEFAULT_CHAT_FRAME:AddMessage("\124cffFFFF00"..EA_XCMD_DEBUG_P2.."\124r="..EA_spellId.." / \124cffFFFF00"..EA_XCMD_DEBUG_P1.."\124r="..sSpellLink)
			G:EAFun_AddSpellToScrollFrame(spellId, "")
		--end
	end
end
------------------------------------------------------------------
--- 事件:施放技能法術失敗
------------------------------------------------------------------
function G:UNIT_SPELLCAST_FAILED(event, unitCaster, CastGUID, spellId)
	
	-- if unitCaster == "player" then
		-- G:ScdBuffs_Update(unitCaster,GetSpellInfo(spellId), spellId, GetTime())
	-- end
end
------------------------------------------------------------------
---事件:背包內物品觸發冷卻事件
------------------------------------------------------------------
local BAG_UPDATE_COOLDOWN_RUNNING = false
function G:BAG_UPDATE_COOLDOWN(event, ...)	
	
	if BAG_UPDATE_COOLDOWN_RUNNING then return end
	BAG_UPDATE_COOLDOWN_RUNNING = true
	local functionStartTime = debugprofilestop()
	--
		
	for slot = 13, 14 do
		local itemID = GetInventoryItemID("player", slot)
		if not itemID then
			-- 該欄位沒裝備，跳過
		else
			local _, spellID = GetItemSpell(itemID)
			if spellID then
				local name = GetSpellInfo(spellID)
				G:ScdBuffs_Update(UnitName("player"), name, spellID, GetTime())
			end
		end
	end

	
	
	-- local tmpSpellID	
	-- local tmpItemID
	-- tmpItemID = GetInventoryItemID("player",13)
	-- if tmpItemID then 
		-- tmpSpellID = select(2, GetItemSpell(GetInventoryItemID("player",13)))
	-- end	
	-- if tmpSpellID then 
		
		-- G:ScdBuffs_Update("player", GetSpellInfo(tmpSpellID).name, tmpSpellID, GetTime())
	-- end 	
	
	-- tmpItemID = GetInventoryItemID("player",14)
	-- if tmpItemID then 
		-- tmpSpellID = select(2, GetItemSpell(GetInventoryItemID("player",14)))
	-- end
	
	-- if tmpSpellID then
		
		-- G:ScdBuffs_Update("player", GetSpellInfo(tmpSpellID).name, tmpSpellID, GetTime())
	-- end
	
	
	--
	G:EAFun_testLabel("BAG_UPDATE_COOLDOWN", functionStartTime ,debugprofilestop())
	BAG_UPDATE_COOLDOWN_RUNNING = false
end
------------------------------------------------------------------
--事件:切換專精
------------------------------------------------------------------
function G:ACTIVE_TALENT_GROUP_CHANGED(event, ...)	
	--G:PLAYER_ENTERING_WORLD()
	
	G:PlayerSpecPower_Update()	
	G:RemoveAllScdCurrentBuff()
end
------------------------------------------------------------------
---事件:當資源條更新
------------------------------------------------------------------
function G:UNIT_DISPLAYPOWER(event, ...)
	G:PlayerSpecPower_Update()
	--RemoveAllScdCurrentBuff()
end
------------------------------------------------------------------
---事件:變身
------------------------------------------------------------------
function G:UPDATE_SHAPESHIFT_FORM(event, ...)
	G:PlayerSpecPower_Update()
	--RemoveAllScdCurrentBuff()
end
------------------------------------------------------------------
---事件:天賦更新
------------------------------------------------------------------
function G:PLAYER_TALENT_UPDATE(event, ...)
	G:PlayerSpecPower_Update()
	G:RemoveAllScdCurrentBuff()
end
------------------------------------------------------------------
---事件:天賦移除
------------------------------------------------------------------
function G:PLAYER_TALENT_WIPE(event, ...)
	G:PlayerSpecPower_Update()
	G:RemoveAllScdCurrentBuff()
end
------------------------------------------------------------------
---事件:更新一般技能冷卻
------------------------------------------------------------------
function G:SPELL_UPDATE_COOLDOWN(event, ...)
	local functionStartTime = debugprofilestop()
--
	
	for i, spellId in ipairs(G.EA_ScdCurrentBuffs) do
		G:OnSCDUpdate(spellId)
	end	
	-- G:ScdPositionFrames()
	
	--
	G:EAFun_testLabel("SPELL_UPDATE_COOLDOWN", functionStartTime ,debugprofilestop())
	
end
------------------------------------------------------------------
---事件:更新充能技能冷卻
------------------------------------------------------------------
function G:SPELL_UPDATE_CHARGES(event, ...)
	local functionStartTime = debugprofilestop()
	--
	
	for i, spellId in ipairs(G.EA_ScdCurrentBuffs) do
		G:OnSCDUpdate(spellId)
	end
	-- G:ScdPositionFrames()
	
	--
	G:EAFun_testLabel("SPELL_UPDATE_CHARGES", functionStartTime ,debugprofilestop())
end
------------------------------------------------------------------
---事件:符文類型更新
------------------------------------------------------------------
function G:RUNE_TYPE_UPDATE(event, ...)
	local functionStartTime = debugprofilestop()
	--
	G:UpdateRunes()
	--
	G:EAFun_testLabel("RUNE_TYPE_UPDATE", functionStartTime ,debugprofilestop())
end
------------------------------------------------------------------
---事件:符文數量更新
------------------------------------------------------------------
function G:RUNE_POWER_UPDATE(event, ...)
	
	local functionStartTime = debugprofilestop()
	--
	G:UpdateRunes()
	--
	G:EAFun_testLabel("RUNE_POWER_UPDATE", functionStartTime, debugprofilestop())
end
------------------------------------------------------------------
---事件:聚能類法術技能開始施放
------------------------------------------------------------------
function G:EMPOWER_START(event, ...)
	local unitTarget, castGUID, spellId = ...	
end
------------------------------------------------------------------
---事件:聚能類法術技能更新
------------------------------------------------------------------
function G:EMPOWER_UPDATE(event,...)
	local unitTarget, castGUID, spellId = ...    	
end
------------------------------------------------------------------
---事件:小部件有更新,這裡特別處理飛龍活力值(Vigor)
------------------------------------------------------------------
function G:UPDATE_UI_WIDGET(event,...)
	local functionStartTime = debugprofilestop()
	---
	local UIWidgetInfo = ...
	-- local widgetID, widgetSetID, widgetType, unitToken = UIWidgetInfo		
	
	if UIWidgetInfo.widgetType == 24 then 
		
		local widgetInfo 		= 	C_UIWidgetManager.GetFillUpFramesWidgetVisualizationInfo(UIWidgetInfo.widgetID)
		
		--Debug Test
		 -- for k,v in pairs(widgetInfo) do print(k,v) end
					
		local numTotalFrames 	= 	widgetInfo.numTotalFrames
		local numFullFrames		= 	widgetInfo.numFullFrames
		local fillMax 			=	widgetInfo.fillMax
		local fillValue			= 	widgetInfo.fillValue
		local icon				= 	widgetInfo.textureKit
		local shownState		=	widgetInfo.shownState   			
		
		local vigorCount		= 	numFullFrames
		local vigorCountMax		= 	numTotalFrames
		-- local vigor 			= 	numFullFrames 	* fillMax + fillValue
		local vigor 			= 	fillValue
		local vigorMax 			= 	numTotalFrames	* fillMax 
		
		if  shownState == Enum.WidgetShownState.Hidden then 
			G.vigorCount = G.vigorCount or vigorCountMax
			G.fillValue	 = G.fillValue	or 0
			if G.vigorCount < vigorCountMax then 					
				if 	(fillValue < G.fillValue)	then 
					G.vigorCount = G.vigorCount + 1
					G.vigorCount = (G.vigorCount > vigorCountMax) and vigorCountMax or G.vigorCount
				end
				vigor		=	fillValue
				G.fillValue =	fillValue
			else
				vigor	=	0
			end
			
			vigorCount 	= G.vigorCount
		else
			G.vigor					=	vigor
			G.vigorMax				=	vigorMax
			G.vigorCount			=	vigorCount
			G.vigorCountMax			=	vigorCountMax
			G.fillValue 			=	fillValue
		end
		
		G:UpdateVigor(vigor, vigorMax, vigorCount, vigorCountMax)
		
	end
	---
	G:EAFun_testLabel("UPDATE_UI_WIDGET", functionStartTime ,debugprofilestop())
end
------------------------------------------------------------------
--- 事件:特殊資源更新
------------------------------------------------------------------
function G:UNIT_POWER_UPDATE(event, ...)
	local functionStartTime = debugprofilestop()
	---
	local arg1, arg2 = ...		
	if (arg1 == "player") or (arg1 == "pet") then
		for p,	tblPower in pairs(EA_SpecPower) do
			if (arg2 == tblPower.powerType) then
				if (tblPower.func) and (EA_Config.SpecPowerCheck[p]) and (tblPower.has) then	
					if(tblPower.powerId) then					
							tblPower.func(tblPower.powerId)						
					else
						tblPower.func()
					end
				end	
				break
			end
		end			
	end
	---
	G:EAFun_testLabel("UNIT_POWER_UPDATE", functionStartTime ,debugprofilestop())
end

------------------------------------------------------------------
--事件:當某技能可用時觸發
------------------------------------------------------------------
function G:SPELL_UPDATE_USABLE()
	
	local functionStartTime = debugprofilestop()
	
	local tonumber = tonumber	
	local AltItems = EA_AltItems[G.playerClass]
	local SpellEnable = false
	local s,v,v2,i2
	local spellId
	local flagUsable, flagNomana
	local startTime, duration, enabled, modRate
	if (EA_Config.AllowAltAlerts == true) then
		-- DEFAULT_CHAT_FRAME:AddMessage("spell-active: "..spellName)
		-- searching for the spell-id, because we only get the name of the spell
		for s, v in pairs(AltItems) do
			spellId = tonumber(s)
			SpellEnable = v.enable
			local v2 = table.foreach(G.EA_CurrentBuffs,
				function(i2, v2)					
					if v2 == spellId then						
						return v2
					end
				end)
				
			flagUsable, flagNomana = IsUsableSpell(spellId)
			local startTime, duration, enabled, modRate 
			local spellCooldownInfo = GetSpellCooldown(spellId) 
			if (type(spellCooldownInfo) == "table") then				
				startTime 	= spellCooldownInfo.startTime
				duration 	= spellCooldownInfo.duration
				enabled 	= spellCooldownInfo.isEnabled and 1 or 0
				modRate 	= spellCooldownInfo.modRate					
			else
				startTime, duration, enabled, modRate = GetSpellCooldown(spellId) 
			end
			if SpellEnable and flagUsable and (startTime == 0) then
				if (not v2) then
					-- DEFAULT_CHAT_FRAME:AddMessage("G:Buff_Applied("..spellId..")")
					G:Buff_Applied(spellId, false)    					
				end
			else
				if (v2) then
					G:Buff_Dropped(spellId)					
				end
			end
		end
	end	
	
	--local functionStartTime = debugprofilestop()
	G:EAFun_testLabel("SPELL_UPDATE_USABLE", functionStartTime ,debugprofilestop())
end

-- function G:COMBAT_TEXT_SPELL_ACTIVE(spellName)
	-- local SpellEnable = false
	-- if (EA_Config.AllowAltAlerts==true) then
		-- -- DEFAULT_CHAT_FRAME:AddMessage("spell-active: "..spellName)
		-- -- searching for the spell-id, because we only get the name of the spell
		-- local spellId = table.foreach(G.ClassAltSpellName,
		-- function(i, spellId)
			-- -- DEFAULT_CHAT_FRAME:AddMessage("G.ClassAltSpellName("..spellId..")")
			-- print(i,spellId)
			-- if i==spellName then
				-- return spellId
			-- end
		-- end)
		-- if spellId then
			-- spellId = tonumber(spellId)
			-- SpellEnable = G:EAFun_GetSpellItemEnable(EA_AltItems[G.playerClass][spellId])
			-- if (SpellEnable) then
				-- local v2 = table.foreach(G.EA_CurrentBuffs,
				-- function(i2, v2)
					-- if v2==spellId then
						-- return v2
					-- end
				-- end)
				-- if (not v2) then
					-- -- DEFAULT_CHAT_FRAME:AddMessage("G:Buff_Applied("..spellId..")")
					-- G:Buff_Applied(spellId)
					-- G:PositionFrames()
				-- end
			-- end
		-- end
	-- end
-- end


------------------------------------------------------------------
--  觸發BUFF時紅光+音效
------------------------------------------------------------------
function G:DoAlert()
	local functionStartTime = debugprofilestop()
	
	local running 
	local function innerDoAlert()
		if running then return end
		running = true
		if (EA_Config.ShowFlash == true) then
			UIFrameFadeIn(LowHealthFrame, 1, 0, 1)
			UIFrameFadeOut(LowHealthFrame, 2, 1, 0)
		end
		if (EA_Config.DoAlertSound == true) then
			if G.PlaySoundHandle then 
				StopSound(G.PlaySoundHandle)
				G.PlaySoundHandle = nil
			end
			_, G.PlaySoundHandle = PlaySoundFile(EA_Config.AlertSound, "Master")
		end
		running = false
	end                           	
	
	innerDoAlert()
	G:EAFun_testLabel("DoAlert", functionStartTime ,debugprofilestop())
end



-----------------------------------------------------------------
-- The URLs of update
-----------------------------------------------------------------
function G:ShowVerURL(SiteIndex)
	local VerUrl = ""
	VerUrl = EA_XOPT_VERURL1
	if SiteIndex ~= 1 then
		VerUrl = "https://www.curseforge.com/wow/addons/eventalertmod"
	end
	DEFAULT_CHAT_FRAME:AddMessage(VerUrl)
end

-----------------------------------------------------------------
--版本檢查
-----------------------------------------------------------------
function G:VersionCheck()
	
	local EA_TocVersion = GetAddOnMetadata("EventAlertMod", "Version")
	
	-- local F_EA = "\124cffFFFF00EventAlertMod\124r"
	G:EAFun_CreateVersionFrame_ScrollEditBox()
	EA_Version_Frame_Okay:SetText(EA_XOPT_OKAY)
	
	EA_Items 		= EA_Items 		or {}
	EA_AltItems		= EA_AltItems 	or {}
	EA_TarItems		= EA_TarItems 	or {}
	EA_ScdItems		= EA_ScdItems 	or {}
	EA_GrpItems		= EA_GrpItems	or {}
	
	if (EA_Config.Version ~= EA_TocVersion and EA_Config.Version ~= nil) then
			
		
		
		if (EA_Config.Version < "4.5.01" and EA_TocVersion < "4.5.04") then
			-- Ver 4.5.01 is For WOW 4.0.1+
			-- Many WOW 3.x spells are canceled or integrated,
			-- so the saved-spells should be clear, and to load the new spells.
			
			-- EA_Items = { }
			-- EA_AltItems = { }
			-- EA_TarItems = { }
			-- EA_ScdItems = { }
			-- EA_GrpItems = { }
		end
		if (EA_Config.Version < "4.5.05" and EA_TocVersion <= "4.7.02") then
			-- EventAlert SpellArray Format Change, from true/false values to parameters values
			-- so, it should formate old parameters to new
			
			EA_Pos = G:EAFun_ExtendExecution_4505(EA_Pos)
			
			-- EA_Items = G:EAFun_ChangeSavedVariblesFormat_4505(EA_Items, false)
			-- EA_AltItems = G:EAFun_ChangeSavedVariblesFormat_4505(EA_AltItems, false)
			-- EA_TarItems = G:EAFun_ChangeSavedVariblesFormat_4505(EA_TarItems, true)
			-- EA_ScdItems = G:EAFun_ChangeSavedVariblesFormat_4505(EA_ScdItems, false)
			-- EA_GrpItems = { }
		end
		EA_Config.Version = EA_TocVersion
		-- if (EA_XLOAD_NEWVERSION_LOAD ~= "") then
		-- 	EA_Version_ScrollFrame_EditBox:SetText(F_EA..EA_XCMD_VER..EA_Config.Version.."\n\n\n"..EA_XLOAD_NEWVERSION_LOAD)
		-- 	EA_Version_Frame:Show()
		-- end
		G:LoadClassSpellArray(9)
	elseif (EA_Config.Version == nil) then
		
		
		-- EA_Items = { }
		-- EA_AltItems = { }
		-- EA_TarItems = { }
		-- EA_ScdItems = { }
		-- EA_GrpItems = { }
		EA_Config.Version = EA_TocVersion
		-- if (EA_XLOAD_FIRST_LOAD ~= "") then
		-- 	EA_Version_ScrollFrame_EditBox:SetText(F_EA..EA_XCMD_VER..EA_Config.Version.."\n\n\n"..EA_XLOAD_FIRST_LOAD..EA_XLOAD_NEWVERSION_LOAD)
		-- 	EA_Version_Frame:Show()
		-- end
		G:LoadClassSpellArray(9)
	elseif G:EAFun_GetCountOfTable(EA_Items[G.playerClass]) <= 0 then		
		G:LoadClassSpellArray(9)
	end	
	
	if EA_Items[G.playerClass] 		== nil then EA_Items[G.playerClass] 		= {} end
	if EA_AltItems[G.playerClass] 	== nil then EA_AltItems[G.playerClass] 		= {} end
	if EA_Items[EA_CLASS_OTHER]		== nil then EA_Items[EA_CLASS_OTHER]		= {} end
	if EA_TarItems[G.playerClass] 	== nil then EA_TarItems[G.playerClass] 		= {} end
	if EA_ScdItems[G.playerClass] 	== nil then EA_ScdItems[G.playerClass] 		= {} end
	if EA_GrpItems[G.playerClass] 	== nil then EA_GrpItems[G.playerClass]		= {} end
	-- G:LoadClassSpellArray(6)
	-- After confirm the version, set the VersionText in the EA_Options_Frame.
	EA_Options_Frame_VersionText:SetText("Ver:\124cffFFFFFF"..EA_Config.Version.."\124r")
end


-----------------------------------------------------------------
-- 特殊框架:處理斬殺血量
-----------------------------------------------------------------
function G:CheckExecution()
	
	local functionStartTime = debugprofilestop()
	
	local P,T = "player", "target"
	local EAEXF = G.EAEXF
	
	local execution = tonumber(EA_Position.Execution)
	
	if (execution > 0) then
		
		local iDead 	= UnitIsDeadOrGhost(T)
		local iEnemy 	= UnitCanAttack(P, T)
		local iLevel 	= 3		
		if ((iDead == false) and (iEnemy == true)) then
		
			local iLvPlayer, iLvTarget = UnitLevel(P), UnitLevel(T)		
			if ((EA_Position.PlayerLv2BOSS and iLvTarget == -1) or (iLvPlayer >= iLvTarget)) then
				print(UnitHealth(T,true))
				
				local iHppTarget = (UnitHealth(T, true) * 100) / UnitHealthMax(T)
				if (iHppTarget <= execution) then
			
					if (not EAEXF.AlreadyAlert) then
			
						local eaf = _G["EventAlert_ExecutionFrame"]
						eaf:SetAlpha(0.75)
						eaf:Show()						
						EAEXF.FrameCount = 0
						EAEXF.Prefraction = 0
						EAEXF:AnimateOut(eaf)
						EAEXF.AlreadyAlert = true
					end
				else
					EAEXF.AlreadyAlert = false
				end
			end
		else
			EAEXF.AlreadyAlert = false
		end
	end	
		
	G:EAFun_testLabel("CheckExecution", functionStartTime ,debugprofilestop())
	
end
-----------------------------------------------------------------
-- 以部分文字找尋技能ID
-----------------------------------------------------------------
function G:Lookup(para1, fullmatch)
	local startTime = debugprofilestop()
	local sFMatch = ""
	local sName = ""
	local iCount = 0
	local sSpellLink = ""
	local fGoPrint = false
	if (para1 == nil) then
		for i, v in ipairs(EA_XCMD_CMDHELP["LOOKUP"]) do
			if i == 1 then
				DEFAULT_CHAT_FRAME:AddMessage(v)
			elseif MoreHelp then
				DEFAULT_CHAT_FRAME:AddMessage(v)
			end
		end
		for i, v in ipairs(EA_XCMD_CMDHELP["LOOKUPFULL"]) do
			if i == 1 then
				DEFAULT_CHAT_FRAME:AddMessage(v)
			elseif MoreHelp then
				DEFAULT_CHAT_FRAME:AddMessage(v)
			end
		end
		return
	end
	if fullmatch then sFMatch = " / "..EA_XLOOKUP_START2 end
	DEFAULT_CHAT_FRAME:AddMessage(EA_XLOOKUP_START1..": [\124cffFFFF00"..para1.."\124r]"..sFMatch)
	DEFAULT_CHAT_FRAME:AddMessage("使用協程背景查詢中,目前在查詢速度與卡頓取得一個平衡點,會有輕微卡頓,請勿中斷或重新查詢")
	G:EAFun_ClearSpellScrollFrame()
	local strfind = strfind
	local DoesSpellExist = C_Spell.DoesSpellExist		
	local maxspellid = 10^7 - 1
	local spellInfo 
	local function getAllSpell()		
		EA_Version_Frame:Show()
		for i = 1, maxspellid do	
			
			if DoesSpellExist(i) then
				local spellInfo = GetSpellInfo(i)
				sName = (type(spellInfo) == "table") and spellInfo.name or select(1, spellInfo)
				fGoPrint = false
				if (sName ~= nil) then			
					if (fullmatch) then
						if (sName == para1) then fGoPrint = true end
					else
						if (strfind(sName, para1)) then fGoPrint = true end
					end
					if (fGoPrint) then
						sSpellLink = GetSpellLink(i)
						--if (sSpellLink ~= nil) then
							iCount = iCount + 1
							-- DEFAULT_CHAT_FRAME:AddMessage("["..tostring(iCount).."]\124cffFFFF00"..EA_XCMD_DEBUG_P2.."\124r="..tostring(i).." / \124cffFFFF00"..EA_XCMD_DEBUG_P1.."\124r="..sSpellLink)
							G:EAFun_AddSpellToScrollFrame(i, "")
						--end
					end		
				end						
			end
			
			
			if (i % 1000) == 0 or GetFramerate() < 40  or InCombatLockdown() then				
				-- DEFAULT_CHAT_FRAME:AddMessage(EA_XLOOKUP_RESULT1..": \124cffFFFF00"..tostring(iCount).."\124r"..EA_XLOOKUP_RESULT2)
				coroutine.yield() 
			end                   			
		end
		
		
		
		print(format("查詢共花費:%.3f毫秒(Milliseconds)", debugprofilestop() - startTime))
		
	end
	
	
	-- 創建一個定時器，每1/N秒執行一次 getAllSpell()
	local co = coroutine.create(getAllSpell)
	G.tickerGetSpell = C_Timer.NewTicker( 1 / GetFramerate(), function()	
	
		-- 如果協程已經結束，取消定時器		
		if coroutine.status(co) == "dead" then 						
			G.tickerGetSpell:Cancel()
			return
		end                 
		
		-- 恢復協程的執行，繼續獲取數據
		coroutine.resume(co)
	end)

	-- 啟動協程執行
	coroutine.resume(co)
	
end
local ACTION_UPDATE_COOLDOWN_RUNNING = false
function G:ACTIONBAR_UPDATE_COOLDOWN()
	
	if ACTION_UPDATE_COOLDOWN_RUNNING then return end
	ACTION_UPDATE_COOLDOWN_RUNNING = true
	
	local functionStartTime = debugprofilestop()
	--
	-- 戰鬥中不需要更新冷卻狀態,其他事件已足夠,但脫離戰鬥後必須更新
	if not InCombatLockdown() then for i,v in ipairs(G.EA_ScdCurrentBuffs) do G:OnSCDUpdate(v) end end	
	
	-- for i,v in ipairs(G.EA_ScdCurrentBuffs) do G:OnSCDUpdate(v) end 
	for i,v in ipairs(G.EA_CurrentBuffs) 	do G:OnUpdate(v) 	end 
	for i,v in ipairs(G.EA_TarCurrentBuffs) do G:OnTarUpdate(v) end
	
	--
	G:EAFun_testLabel("ACTIONBAR_UPDATE_COOLDOWN", functionStartTime, debugprofilestop())
	ACTION_UPDATE_COOLDOWN_RUNNING = false
end


function G:PLAYER_TOTEM_UPDATE(totemSlot)
	local t0 = debugprofilestop()
	--
	
	
	local PlayerItems = EA_Items[G.playerClass]
	local OtherItems = EA_Items[EA_CLASS_OTHER]
	local count = 1	
	local unitCaster = "player"      	  
	local GetTotemInfo = GetTotemInfo
	local haveTotem, totemName, startTime, duration, icon, modRate, spellID = GetTotemInfo(totemSlot)
	
			 
	local ifAdd_buffCur = false
	local SpellEnable = G:EAFun_GetSpellItemEnable(PlayerItems[spellId])			
	 
	 if (SpellEnable) then			
		ifAdd_buffCur, orderWtd = G:EAFun_CheckSpellConditionMatch(count, unitCaster, PlayerItems[spellId])	
	 end
	 
	 if ifAdd_buffCur then
		if haveTotem then
			G.SPELLINFO_SELF[spellId] =	{	
										 name			=	spellName,											
										 icon 			= 	TotemIcon,
										 count			=	count,
										 duration		=	TotemDuration,
										 expirationTime	=	TotemStart + TotemDuration,
										 unitCaster 	= 	unitCaster,
										 isDebuff		= 	false,
										 orderwtd		=	orderWtd,											
										 totem			=	totemSlot,
										}		   
			buffsCurrent[#buffsCurrent + 1] = spellId			   
		end		
	 end 	 
   
	--
	G:EAFun_testLabel("PLAYER_TOTEM_UPDATE", t0, debugprofilestop())
end

