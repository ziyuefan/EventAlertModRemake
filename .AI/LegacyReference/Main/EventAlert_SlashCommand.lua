--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_SlashCommand.lua

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
------------------------------------------------------------------
-- The command parser
------------------------------------------------------------------
function G:SlashHandler(...)

	local msg = self
	
	local F_EA = "\124cffFFFF00EventAlertMod\124r"
	local F_ON = "\124cffFF0000".."[ON]".."\124r"
	local F_OFF = "\124cff00FFFF".."[OFF]".."\124r"
	local RtnMsg = ""
	local MoreHelp = false
	
	msg = string.lower(msg)
	local cmdtype, para1 = strsplit(" ", msg)
	--local cmdtype, para1, para2 = strsplit(" ", msg)
	
	local listSec = 0
	if para1 ~= nil then
		listSec = tonumber(para1)
	end
	
	if (cmdtype == "options" or cmdtype == "opt") then
		if not EA_Options_Frame:IsVisible() then
			-- ShowUIPanel(EA_Options_Frame)
			EA_Options_Frame:Show()
		else
			-- HideUIPanel(EA_Options_Frame)
			EA_Options_Frame:Hide()
		end
	-- elseif (cmdtype == "version" or cmdtype == "ver") then
	--  DEFAULT_CHAT_FRAME:AddMessage(F_EA..EA_XCMD_VER..EA_Config.Version)
	
	elseif (cmdtype == "show") then
		G.EA_DEBUGFLAG11 = false
		G.EA_DEBUGFLAG21 = false
		G.EA_LISTSEC_SELF = 0
		if (G.EA_DEBUGFLAG1) then
			G.EA_DEBUGFLAG1 = false
			RtnMsg = F_EA..EA_XCMD_SELFLIST..F_OFF
		else
			G.EA_DEBUGFLAG1 = true
			G.EA_LISTSEC_SELF = listSec
			RtnMsg = F_EA..EA_XCMD_SELFLIST..F_ON
			if G.EA_LISTSEC_SELF > 0 then RtnMsg = RtnMsg.." ("..G.EA_LISTSEC_SELF.." secs)" end
			G:EAFun_ClearSpellScrollFrame()
			EA_Version_Frame:Show()
		end
		DEFAULT_CHAT_FRAME:AddMessage(RtnMsg)
	
	elseif (cmdtype == "showtarget" or cmdtype == "showt") then
		G.EA_DEBUGFLAG11 = false
		G.EA_DEBUGFLAG21 = false
		G.EA_LISTSEC_TARGET = 0
		if (G.EA_DEBUGFLAG2) then
			G.EA_DEBUGFLAG2 = false
			RtnMsg = F_EA..EA_XCMD_TARGETLIST..F_OFF
		else
			G.EA_DEBUGFLAG2 = true
			G.EA_LISTSEC_TARGET = listSec
			RtnMsg = F_EA..EA_XCMD_TARGETLIST..F_ON
			if G.EA_LISTSEC_TARGET > 0 then RtnMsg = RtnMsg.." ("..G.EA_LISTSEC_TARGET.." secs)" end
			G:EAFun_ClearSpellScrollFrame()
			EA_Version_Frame:Show()
		end
		DEFAULT_CHAT_FRAME:AddMessage(RtnMsg)
	
	elseif (cmdtype == "showcast" or cmdtype == "showc") then
		G.EA_DEBUGFLAG11 = false
		G.EA_DEBUGFLAG21 = false
		if (G.EA_DEBUGFLAG3) then
			G.EA_DEBUGFLAG3 = false
			RtnMsg = F_EA..EA_XCMD_CASTSPELL..F_OFF
		else
			G.EA_DEBUGFLAG3 = true
			RtnMsg = F_EA..EA_XCMD_CASTSPELL..F_ON
			G:EAFun_ClearSpellScrollFrame()
			EA_Version_Frame:Show()
		end
		DEFAULT_CHAT_FRAME:AddMessage(RtnMsg)
		
	elseif (cmdtype == "showautoadd" or cmdtype == "showa") then
		G.EA_DEBUGFLAG1 = false
		G.EA_DEBUGFLAG2 = false
		G.EA_DEBUGFLAG3 = false
		G.EA_DEBUGFLAG21 = false
		G.EA_LISTSEC_SELF = 60
		if (G.EA_DEBUGFLAG11) then
			G.EA_DEBUGFLAG11 = false
			RtnMsg = F_EA..EA_XCMD_AUTOADD_SELFLIST..F_OFF
		else
			G.EA_DEBUGFLAG11 = true
			RtnMsg = F_EA..EA_XCMD_AUTOADD_SELFLIST..F_ON
			if listSec > 0 then G.EA_LISTSEC_SELF = listSec end
			if G.EA_LISTSEC_SELF > 0 then RtnMsg = RtnMsg.." ("..G.EA_LISTSEC_SELF.." secs)" end
		end
		DEFAULT_CHAT_FRAME:AddMessage(RtnMsg)
		
	elseif (cmdtype == "showenvadd" or cmdtype == "showe") then
		G.EA_DEBUGFLAG1 = false
		G.EA_DEBUGFLAG2 = false
		G.EA_DEBUGFLAG3 = false
		G.EA_DEBUGFLAG11 = false
		G.EA_LISTSEC_SELF = 60
		if (G.EA_DEBUGFLAG21) then
			G.EA_DEBUGFLAG21 = false
			RtnMsg = F_EA..EA_XCMD_ENVADD_SELFLIST..F_OFF
		else
			G.EA_DEBUGFLAG21 = true
			RtnMsg = F_EA..EA_XCMD_ENVADD_SELFLIST..F_ON
			if listSec > 0 then G.EA_LISTSEC_SELF = listSec end
			if G.EA_LISTSEC_SELF > 0 then RtnMsg = RtnMsg.." ("..G.EA_LISTSEC_SELF.." secs)" end
		end
		DEFAULT_CHAT_FRAME:AddMessage(RtnMsg)
		
	elseif (cmdtype == "lookup") or (cmdtype == "l")then
		G:Lookup(para1, false)
	
	elseif (cmdtype == "lookupfull") or (cmdtype == "lf") then
		G:Lookup(para1, true)
		
	elseif (cmdtype == "list") then
		EA_Version_Frame_HeaderText:SetText(EA_XCMD_DEBUG_P0)
		EA_Version_ScrollFrame_EditBox:Hide()
		EA_Version_Frame:Show()
		
    elseif (cmdtype == "minimap") then
		local f = EA_MinimapOption
		if para1 and para1=="reset" then
			f:ClearAllPoints()
			f:SetPoint("TOPRIGHT",Minimap,"BOTTOMLEFT",0,0)
			EA_Config.OPTION_ICON = true
			f:Show()
		else
			print("show or hide option icon.\n(left button:show option/right button:move option icon)")
			if EA_Config.OPTION_ICON == false  then	
				print("Show option icon nearby minimap")
				EA_Config.OPTION_ICON = true
				f:Show()		
			else			
				EA_Config.OPTION_ICON = false
				f:Hide()
			end
		end
	
	elseif (cmdtype == "iconappendspelltip") then
		local msg = " Spell Tooltip on alert icon"
		if EA_Config.ICON_APPEND_SPELL_TIP == false  then	
			EA_Config.ICON_APPEND_SPELL_TIP = true				
			print("show "..msg)
		else			
			EA_Config.ICON_APPEND_SPELL_TIP = false			
			print("hide "..msg)
		end		
		
	elseif (cmdtype == "updateinterval") then
		print("upper the onupdate interval if you feel lag.(max 1s)")
		local para_updateinterval = tonumber(para1) or 0.01
		if para_updateinterval > 1 then para_updateinterval = 1 end		
		G.UpdateInterval = para_updateinterval 
		print("OnUpdate Event Will Occur Each "..para_updateinterval.." seconds") 
		print("WARNING! : Don't more than 1 sec ")
		
	elseif (cmdtype == "scdremovewhencooldown") then
		print("To remove or keep icon when spell cooldown")
		if EA_Config.SCD_RemoveWhenCooldown == true then			
			EA_Config.SCD_RemoveWhenCooldown = false
			print("EA_Config.SCD_RemoveWhenCooldown = false")			
		else
			EA_Config.SCD_RemoveWhenCooldown = true
			print("EA_Config.SCD_RemoveWhenCooldown = true")
		end
	
	elseif (cmdtype == "scdnocombatstillkeep") then
		print("Keep or hide icon when exit combat status.")
		if EA_Config.SCD_NocombatStillKeep == true then			
			EA_Config.SCD_NocombatStillKeep = false
			print("EA_Config.SCD_NocombatStillKeep = false")					
		else
			EA_Config.SCD_NocombatStillKeep = true
			print("EA_Config.SCD_NocombatStillKeep = true")
		end
	
	elseif (cmdtype == "scdglowwhenusable") then
		print("Glow CD icon when the spell can use.(not only cooldown) ")
		if EA_Config.SCD_GlowWhenUsable == true then			
			EA_Config.SCD_GlowWhenUsable = false
			print("EA_Config.SCD_GlowWhenUsable = false")					
		else
			EA_Config.SCD_GlowWhenUsable = true
			print("EA_Config.SCD_GlowWhenUsable = true")
		end
	
	elseif (cmdtype == "newlinebyiconcount") then
		print("Assign counts of icons for change new line")
		local para_count = tonumber(para1)
		if para_count then
			EA_Config.NewLineByIconCount = para_count
			print("EA_Config.NewLineByIconCount = "..para_count )					
		else
			print("Not assign count of icon for change line")
		end
		
	elseif (cmdtype == "snamefontsize") or (cmdtype == "nfs") then
		print("Set the SpellName size of FONT to show number and name ")
		local para_count = tonumber(para1)
		if para_count then
		
			EA_Config.SNameFontSize = para_count
					  
			print("EA_Config.SNameFontSize = "..para_count )					
		else
			print("Not assign font size, current size is "..para_count)
		end
		
	elseif (cmdtype == "stackfontsize") or (cmdtype == "sfs") then
		print("Set the Stack size of FONT to show number and name ")
		local para_count = tonumber(para1)
		if para_count then
			EA_Config.StackFontSize = para_count			
			print("EA_Config.StackFontSize = "..para_count )					
		else
			print("Not assign font size, current size is "..para_count)
		end
		
	elseif (cmdtype == "timerfontsize") or (cmdtype == "tfs") then
		print("Set the TIMER size of FONT to show number and name ")
		local para_count = tonumber(para1)
		if para_count then
			EA_Config.TimerFontSize = para_count
			
			print("EA_Config.TimerFontSize = "..para_count )					
		else
			print("Not assign font size, current size is "..para_count)
		end
	
	elseif (cmdtype == "showeaconfig") then
		local print = print
		local pairs = pairs
		local type  = type
		print("EA_Config:")
		for k,v in pairs(EA_Config) do
			if type(v)=="table" then
				print(k.."={")
				for k2,v2 in pairs(v) do print("   ",k2," = ",v2) end
				print("}")
			else
				print(k," = ",v)
			end
		end
	
	elseif (cmdtype == "showeaposition") then
		print("EA_Position:")
		for k,v in pairs(EA_Position) do
			if type(v)=="table" then
				print(k.."={")
				for k2,v2 in pairs(v) do print("   ",k2," = ",v2) end
				print("}")
			else
				print(k," = ",v)
			end
		end
	
	elseif (cmdtype == "showrunesbar") then		
		print("Show DK's Runs bar")
		if EA_Config.ShowRunesBar == true then			
			EA_Config.ShowRunesBar = false
			print("EA_Config.ShowRunesBar = false")	
			local eaf
			for i = 1, G.MAX_RUNES do				
				eaf = _G["EAFrameSpec_"..EA_SpecPower.Runes.frameindex[i]]
				if eaf:IsShown()  then eaf:Hide() end
			end
		else
			EA_Config.ShowRunesBar = true
			print("EA_Config.ShowRunesBar = true")
		end
	
	--elseif (cmdtype == "var") then			
	
	elseif (cmdtype == "print") then
		-- table.foreach(G.ClassAltSpellName,
		-- function(i, v)
		--  if v == nil then v = "nil" end
		--  DEFAULT_CHAT_FRAME:AddMessage("["..i.."]G.ClassAltSpellName["..i.."]="..EA_ClassAltSpellName[i].." v="..v)
		-- end
		-- )
		-- G:EAFun_CreateVersionFrame_ScrollEditBox()
		-- EA_Version_Frame_HeaderText:SetText("Test")
		-- EA_Version_Frame:Show()
		-- print ("go print")
		-- for  i, v in pairsByKeys(EA_Items) do
		--  print (i)
		--  --if v.enable then
		--  --  print ("enable T")
		--  --else
		--  --  print ("enable F")
		--  --end
		-- end
	
	elseif (cmdtype == "play") then
		local eaf = _G.EventAlert_ExecutionFrame
		eaf:SetAlpha(1)
		eaf:Show()
		eaf:SetAlpha(0.8)
		eaf:Show() 
	 
		G.EAEXF.FrameCount = 0
		G.EAEXF.Prefraction = 0	 
		G.EAEXF:AnimateOut(eaf)
		G.EAEXF.AlreadyAlert = true 	
		
	elseif (cmdtype == "exportclasstodef") or (cmdtype == "ectd") then	
		
		G:ConvertClassSpellListToDefaultFormat( (select(2,UnitClass("player"))) )
		
		
	elseif (cmdtype == "createspellitemcache") then
	
		G:CreateSpellItemCache3()
		--G:CreateSpellItemCache()
		
	else
		if cmdtype == "help" then MoreHelp = true end
		DEFAULT_CHAT_FRAME:AddMessage(F_EA..EA_XCMD_VER..EA_Config.Version)
		DEFAULT_CHAT_FRAME:AddMessage(EA_XCMD_CMDHELP.TITLE)
		DEFAULT_CHAT_FRAME:AddMessage(EA_XCMD_CMDHELP.OPT)
		DEFAULT_CHAT_FRAME:AddMessage(EA_XCMD_CMDHELP.HELP)
		for i, v in ipairs(EA_XCMD_CMDHELP["SHOW"]) do
			if i == 1 then
				if G.EA_DEBUGFLAG1 then v = v..EA_XCMD_SELFLIST..F_ON else v = v..EA_XCMD_SELFLIST..F_OFF end
				DEFAULT_CHAT_FRAME:AddMessage(v)
			elseif MoreHelp then
				DEFAULT_CHAT_FRAME:AddMessage(v)
			end
		end
		for i, v in ipairs(EA_XCMD_CMDHELP["SHOWT"]) do
			if i == 1 then
				if G.EA_DEBUGFLAG2 then v = v..EA_XCMD_TARGETLIST..F_ON else v = v..EA_XCMD_TARGETLIST..F_OFF end
				DEFAULT_CHAT_FRAME:AddMessage(v)
			elseif MoreHelp then
				DEFAULT_CHAT_FRAME:AddMessage(v)
			end
		end
		for i, v in ipairs(EA_XCMD_CMDHELP["SHOWC"]) do
			if i == 1 then
				if G.EA_DEBUGFLAG3 then v = v..EA_XCMD_CASTSPELL..F_ON else v = v..EA_XCMD_CASTSPELL..F_OFF end
				DEFAULT_CHAT_FRAME:AddMessage(v)
			elseif MoreHelp then
				DEFAULT_CHAT_FRAME:AddMessage(v)
			end
		end
		for i, v in ipairs(EA_XCMD_CMDHELP["SHOWA"]) do
			if i == 1 then
				if G.EA_DEBUGFLAG11 then v = v..EA_XCMD_AUTOADD_SELFLIST..F_ON else v = v..EA_XCMD_AUTOADD_SELFLIST..F_OFF end
				DEFAULT_CHAT_FRAME:AddMessage(v)
			elseif MoreHelp then
				DEFAULT_CHAT_FRAME:AddMessage(v)
			end
		end
		for i, v in ipairs(EA_XCMD_CMDHELP["SHOWE"]) do
			if i == 1 then
				if G.EA_DEBUGFLAG21 then v = v..EA_XCMD_ENVADD_SELFLIST..F_ON else v = v..EA_XCMD_ENVADD_SELFLIST..F_OFF end
				DEFAULT_CHAT_FRAME:AddMessage(v)
			elseif MoreHelp then
				DEFAULT_CHAT_FRAME:AddMessage(v)
			end
		end
		for i, v in ipairs(EA_XCMD_CMDHELP["LIST"]) do
			if i == 1 then
				DEFAULT_CHAT_FRAME:AddMessage(v)
			elseif MoreHelp then
				DEFAULT_CHAT_FRAME:AddMessage(v)
			end
		end
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
	end
end
------------------------------------------------------------------
--
------------------------------------------------------------------
function G:InitSlashCommand()
	SlashCmdList["EVENTALERTMOD"] = G.SlashHandler
	SLASH_EVENTALERTMOD1 = "/eventalertmod"
	SLASH_EVENTALERTMOD2 = "/eam"
end
------------------------------------------------------------------