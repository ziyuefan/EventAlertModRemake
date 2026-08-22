--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_Util.lua

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
local tinsert 		= table.insert
local tsort 		= table.sort
local tremove 		= table.remove
local tconcat 		= table.concat
local tmaxn 		= table.maxn
local tcreate		= table.create
local twipe			= table.wipe

-- table.concat(list [, sep, i, j]) - Concatenates the contents of a table to a string.
-- table.create(arraySizeHint [, nodeSizeHint]) #wow
-- table.insert |tinsert(list [, pos], value) - Insert value into the table at position pos (defaults to end of table).
-- table.maxn(list) - Returns the largest positive numerical index of the given table, or zero if the table has no positive numerical indices.
-- table.remove |tremove(list [, pos]) - Remove and return the table element at position pos (defaults to last entry in table).
-- table.removemulti(list [, pos [, count]]) #wow - Removes count elements from a table starting at index pos.
-- table.sort |sort(list [, comp]) - Sort the elements in the table in-place, optionally using a custom comparator.
-- table.wipe |wipe(list) #wow - Restore the table to its initial value (like tab = {} without the garbage).

-- These string functions are shorthand references to the Lua string library (which is available via "string.", see StringLibraryTutorial for more info),
	-- format(formatstring[, value[, ...]]) - Return a formatted string using values passed in.
	-- gmatch(string, pattern) - This returns a pattern finding iterator. The iterator will search through the string passed looking for instances of the pattern you passed.
	-- gsub(string,pattern,replacement[, limitCount]) - Globally substitute pattern for replacement in string.
	-- strbyte(string[, index]) - Returns the internal numeric code of the i-th character of string
	-- strchar(asciiCode[, ...]) - Returns a string with length equal to number of arguments, with each character assigned the internal code for that argument.
	-- strfind(string, pattern[, initpos[, plain]]) - Look for match of pattern in string, optionally from specific location or using plain substring.
	-- strlen(string) - Return length of the string.
	-- strlower(string) - Return string with all upper case changed to lower case.
	-- strmatch(string, pattern[, initpos]) - Similar to strfind but only returns the matches, not the string positions.
	-- strrep(seed,count) - Return a string which is count copies of seed.
	-- strrev(string) - Reverses a string; alias of string.reverse.
	-- strsub(string, index[, endIndex]) - Return a substring of string starting at index
	-- strupper(string) - Return string with all lower case changed to upper case.
	-- tonumber(arg[, base]) - Return a number if arg can be converted to number. Optional argument specifies the base to interpret the numeral. Bases other than 10 accept only unsigned integers.
	-- tostring(arg) - Convert arg to a string.

-- These are custom string functions available in WoW but not normal Lua.
	-- strcmputf8i(string, string) #wow - string comparison accounting for UTF-8 chars
	-- strlenutf8(string) #wow - Returns the number of characters in a UTF8-encoded string.
	-- strtrim(string[, chars]) #wow - Trim leading and trailing spaces or the characters passed to chars from string.
	-- strsplit(delimiter, string [, pieces) #wow - Splits a string using a delimiter.
	-- strsplittable(delimiter, subject [, pieces]) #wow
	-- strjoin(delimiter, string, string[, ...]) #wow - Join string arguments into a single string, separated by delimiter.
	-- strconcat(...) #wow - Returns a concatenation of all number/string arguments passed.
	-- tostringall(...) #wow - Converts all arguments to strings and returns them in the same order that they were passed.
	-- string.rtgsub(s, pattern, repl[, n] #framexml - A version of string.gsub which is able to be passed restricted tables.


-- WOW API : Spell
local GetSpellCharges 	= type(GetSpellCharges) 	== "function"	and GetSpellCharges 	or C_Spell.GetSpellCharges
local GetSpellCooldown 	= type(GetSpellCooldown)	== "function"	and GetSpellCooldown 	or C_Spell.GetSpellCooldown
local GetSpellInfo 		= type(GetSpellInfo)		== "function"	and GetSpellInfo 		or C_Spell.GetSpellInfo
local GetSpellLink 		= type(GetSpellLink)		== "function" 	and GetSpellLink 		or C_Spell.GetSpellLink
local GetSpellTexture 	= type(GetSpellTexture)		== "function" 	and GetSpellTexture 	or C_Spell.GetSpellTexture
local IsUsableSpell 	= type(IsUsableSpell)		== "function" 	and IsUsableSpell		or C_Spell.IsSpellUsable  

-- WOW API : Auras
local UnitBuff 			= type(UnitBuff) 	== "function"	and UnitBuff		or	C_UnitAuras.GetBuffDataByIndex
local UnitDebuff 		= type(UnitDebuff) 	== "function"	and UnitDebuff		or	C_UnitAuras.GetDebuffDataByIndex
local UnitAura 			= type(UnitAura) 	== "function"	and UnitAura		or 	C_UnitAuras.GetAuraDataByIndex

-- WOW API : Specialization   
local GetSpecialization 		= type(GetSpecialization) 		== "function" 	and GetSpecialization 		or C_SpecializationInfo.GetSpecialization
local GetSpecializationInfo 	= type(GetSpecializationInfo)	== "function" 	and GetSpecializationInfo 	or C_SpecializationInfo.GetSpecializationInfo
local GetActiveSpecGroup		= type(GetActiveSpecGroup) 		== "function" 	and GetActiveSpecGroup 		or C_SpecializationInfo.GetActiveSpecGroup
------------------------------------------------------------------
--
------------------------------------------------------------------
function G:IfPrint(flag, ...)
	if (flag) then
		print(...)
	end
end
------------------------------------------------------------------
--
------------------------------------------------------------------
function G:MyPrint(info)
	DEFAULT_CHAT_FRAME:AddMessage(info)
end
------------------------------------------------------------------
-- /run  _G.EventAlertMod.DumpTable(_G.EventAlertMod)
-- 以下以ChatGPT生成
------------------------------------------------------------------
function G:printTable(tbl, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            print(prefix .. tostring(k) .. " = {")
            self:printTable(v, indent + 1)
            print(prefix .. "}")
        else
            print(prefix .. tostring(k) .. " = " .. tostring(v))
        end
    end
end
------------------------------------------------------------------
--
------------------------------------------------------------------
function G:pairsByKeys (t, f)
	
	  local tinsert = table.insert
	  local tsort = table.sort
	  
	  local n
	  local a = {}	  
	  for n in pairs(t) do 
		 tinsert(a, n) 
	  end
	
	  tsort(a, f)
	  local i = 0 -- iterator variable
	  local iter = function () -- iterator function
		 i = i + 1
		 if a[i] == nil then
			 return nil
		 else
			 return a[i], t[a[i]]
		 end
	  end
	  
	  return iter
end
------------------------------------------------------------------
-- ButtonGlow_Start(frame[, color[, frequency]]])
-- Starts glow over target frame with set parameters:

-- frame - target frame to set glowing
-- color - {r,g,b,a}, color of particles and opacity, from 0 to 1. Defaul value is {0.95, 0.95, 0.32, 1}
-- frequency - frequency. Default value is 0.125

-- ButtonGlow_Stop(frame)
-- Stops glow over target frame
------------------------------------------------------------------
local GlowStart = LibStub("LibCustomGlow-1.0").ButtonGlow_Start 
local GlowStop  = LibStub("LibCustomGlow-1.0").ButtonGlow_Stop
function G:FrameGlowShowOrHide(eaf, boolShow)

   if eaf == nil then return end

     if boolShow then

          if (eaf.overgrow == nil) or (eaf.overgrow == false) then
               --LibStub("LibCustomGlow-1.0").PixelGlow_Start(eaf,{0.95,0.95,0.32,1.0},8,0.125,8,4,0,0,true)
               GlowStart(eaf, {0.95, 0.95, 0.5, 1}, 0.075)
               eaf.overgrow = true
          end
     else
          if (eaf.overgrow) then
               --LibStub("LibCustomGlow-1.0").PixelGlow_Stop(eaf)
               GlowStop(eaf)
               eaf.overgrow = false
          end
     end
end
------------------------------------------------------------------
-- 
------------------------------------------------------------------
function G:FrameShowOrHide(f, boolShow)
     if boolShow then
          f:Show()
     else
          f:Hide()
     end
end
-----------------------------------------------------------------
--在指定框架增加一個隨鼠標顯示的當前光環內容說明
-----------------------------------------------------------------
function G:FrameAppendAuraTip(eaf, unitId, spellId, gsiIsDebuff)	
	
	if EA_Config.ICON_APPEND_SPELL_TIP == false then		
		eaf:EnableMouse(false)
		eaf:SetScript("OnEnter", nil)
		eaf:SetScript("OnLeave", nil)
		return
	end
	
	local index = nil
	if not(gsiIsDebuff) then
		index = G:GetBuffIndexOfSpellID(unitId, spellId)				
	else		
		index = G:GetDebuffIndexOfSpellID(unitId, spellId)				
	end	
	
	-- for i = 1 , 40 do 
		-- if UnitAura(unitId, i) and UnitAura(unitId, i).spellId == spellId then
			-- index = i
			-- break
		-- end
	-- end
	
	if index then   		
		eaf:EnableMouse(true)
		eaf:SetScript("OnEnter", function()
									GameTooltip:SetOwner(eaf, "ANCHOR_RIGHT")
									if not(gsiIsDebuff) then
										-- GameTooltip:SetUnitBuff(unitId, index)										
										GameTooltip:SetUnitAura(unitId, index,"HELPFUL")
									else
										-- GameTooltip:SetUnitDebuff(unitId, index)										
										GameTooltip:SetUnitAura(unitId, index,"HARMFUL")
									end
								end
					)
		eaf:SetScript("OnLeave",function() GameTooltip:Hide() end )							
	end
end
-----------------------------------------------------------------
--在指定框架增加一個隨鼠標顯示的技能說明
-----------------------------------------------------------------
function G:FrameAppendSpellTip(eaf, spellId)

	if not eaf or not spellId then return end	
	
	if EA_Config.ICON_APPEND_SPELL_TIP == false then
        eaf:EnableMouse(false)  -- 停用滑鼠互動
        eaf:SetScript("OnEnter", nil)
        eaf:SetScript("OnLeave", nil)
		eaf.appendtip = nil
        return
    end
	
	if eaf.appendtip ~= true then 
		eaf:EnableMouse(true)				
		eaf:SetScript("OnEnter", function()
									GameTooltip:SetOwner(eaf, "ANCHOR_RIGHT")
									GameTooltip:SetSpellByID(spellId)
								 end)								 
		
		eaf:SetScript("OnLeave", function()
									GameTooltip:Hide()
								 end)
		eaf.appendtip = true
	end
end
-----------------------------------------------------------------
--
-----------------------------------------------------------------
function G:RemoveAllScdCurrentBuff()
	
	local tonumber = tonumber
	local tconcat = table.concat
	local SpellName, SpellIcon, HasSpell
	local eaf
	local spellId
	local i,k,v 
	local spellInfo
	
	for i, v in ipairs(G.EA_ScdCurrentBuffs) do
		spellInfo = GetSpellInfo(v)
		SpellName = (type(spellInfo) == "table") and spellInfo.name or select(1, spellInfo)
		SpellIcon = GetSpellTexture(v)
		HasSpell = GetSpellInfo(SpellName)
		if HasSpell == nil then
			eaf = _G[tconcat({"EAScdFrame_",v})]
			spellId = tonumber(v)
			-- eaf:Hide()//
			G:removeBuffValue(G.EA_ScdCurrentBuffs, spellId)
			-- removeBuffValue(EA_ScdCurrentBuffs,v)
			-- eaf:SetScript("OnUpdate", nil)			
			Lib_ZYF:StopOnUpdate(eaf)

		end
	end
end
-----------------------------------------------------------------
--
-----------------------------------------------------------------
function G:RemoveSingleSCDCurrentBuff(spellId)
		
		local SpellName, SpellIcon = GetSpellInfo(spellId), GetSpellTexture(spellId)
		-- local HasSpell = GetSpellInfo(SpellName).name
		--if HasSpell==nil then
			local eaf = _G["EAScdFrame_"..spellId]
			local spellId = tonumber(spellId)
			eaf:Hide()			
			G:removeBuffValue(G.EA_ScdCurrentBuffs, spellId)
			Lib_ZYF:StopOnUpdate(eaf)			
		--end	
end
-----------------------------------------------------------------
--
-----------------------------------------------------------------
function G:ShowAllScdCurrentBuff()
			
	if G.EA_flagAllHidden == true then 
		EA_Main_Frame:SetAlpha(0) 
		return 
	else
		EA_Main_Frame:SetAlpha(1) 
	end
		
	local eaf
	local i, spellId
	
	for i, spellId in ipairs(G.EA_ScdCurrentBuffs) do
	
		eaf = _G[tconcat({"EAScdFrame_", spellId})]
		
		eaf:Show()
		
		if eaf.cooldown then eaf.cooldown:Show() end
		
	end
end
-----------------------------------------------------------------
--
-----------------------------------------------------------------
function G:HideAllScdCurrentBuff()
		
	local GetSpellInfo = GetSpellInfo
	local GetSpellTexture = GetSpellTexture
	local ipairs = ipairs
	local i, spellId
	local eaf
	for i, spellId in ipairs(G.EA_ScdCurrentBuffs) do
		
		eaf = _G[tconcat({"EAScdFrame_", spellId})]		
		
		eaf:Hide()
		if eaf.cooldown then 
			eaf.cooldown:SetCooldown(0, 0)
			eaf.cooldown:Hide()
			Lib_ZYF:StopOnUpdate(eaf)
		end
	end
end
------------------------------------------------------------------
--
------------------------------------------------------------------

function G:insertBuffValue(tbl, value)
    local n = #tbl
    for i = 1, n do
        if tbl[i] == value then
            return
        end
    end
    tbl[n+1] = value
end
------------------------------------------------------------------
--
------------------------------------------------------------------
-- function G:insertBuffValue(tbl, value)
	
	-- local tinsert = table.insert
	-- local ipairs = ipairs
	
	-- local isExist = false	
	-- local pos, name
	-- for pos, name in ipairs(tbl) do
		-- if (name == value) then
			-- isExist = true
		-- end
	-- end
	
	-- if not isExist then 
	  -- tinsert(tbl, value)
    -- end
	
-- end
------------------------------------------------------------------
-- 
------------------------------------------------------------------
-- 此程式碼由 OpenAI o4-mini 模型產生
-- 從 tbl 中移除值 value，並保留原始順序
-- function G:removeBuffValue(tbl, value)
    -- local n = #tbl
    -- -- 遍歷 tbl 直到找到目標值
    -- for i = 1, n do
        -- if tbl[i] == value then
            -- -- 從索引 i 開始，將後續元素依序往前移一格
            -- for j = i, n - 1 do
                -- tbl[j] = tbl[j + 1]
            -- end
            -- -- 最後一格清空，縮減長度
            -- tbl[n] = nil
            -- return
        -- end
    -- end
-- end

function G:removeBuffValue(tbl, value)
	local tremove = table.remove
	local ipairs = ipairs
	local pos, name
	for pos, name in ipairs(tbl) do
		if (name == value) then
			tremove(tbl, pos)
		end
	end
end

local MAX_AURAS = 50   -- 單一 filter 掃描上限。50 足以涵蓋玩家身上所有 buff/debuff

--[[--------------------------------------------------------------------
    函式：G:GetUnitAuraBySpellID(unit, spellId[, filter])
    功能：回傳指定單位(unit)身上指定法術(spellId)的光環資料 (AuraData)
    支援版本分流：
      - 11.2.5 以上：使用原生 C_UnitAuras.GetUnitAuraBySpellID
      - 舊版或重導環境：使用 UnitAura (假設已指向 C_UnitAuras.GetAuraDataByIndex)
    備註：
      - 若未找到對應光環，回傳 nil
      - filter 可為 "HELPFUL", "HARMFUL"，或包含 "INCLUDE_NAME_PLATE_ONLY"
      - 已加入上限 MAX_AURAS，避免無限迴圈造成遊戲當機
----------------------------------------------------------------------]]


function G:GetUnitAuraBySpellID(unit, spellId, filter)
    -- === 1. 輸入檢查：單位與法術ID必須存在 ===
    if not unit or not spellId then
        return nil
    end

    -- === 2. 取得目前遊戲版本 (Build TOC number) ===
    local toc = select(4, GetBuildInfo())

    -- === 3. 若為 11.2.5 以上版本，且支援原生API，直接呼叫 ===
    -- if toc and toc >= 110205 then
	if C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID then
        -- 有提供 filter 時傳入，否則使用預設參數簽章
        if filter then
            return C_UnitAuras.GetUnitAuraBySpellID(unit, spellId, filter)
        else
            return C_UnitAuras.GetUnitAuraBySpellID(unit, spellId)
        end
    else
        ----------------------------------------------------------------
        -- 舊版或重新導向的 UnitAura（等價於 GetAuraDataByIndex）
        -- 以 for 迴圈逐一掃描索引直到上限，避免無限迴圈。
        ----------------------------------------------------------------
        local a
        for i = 1, MAX_AURAS do
            -- 有傳 filter 則一併傳入，否則略過
            if filter then
                a = UnitAura(unit, i, filter)
            else
                a = UnitAura(unit, i)
            end

            -- 若已無更多光環資料則中止（避免浪費迴圈）
            if not a then
                break
            end

            -- 確認 spellId 是否符合，若符合立即回傳該 AuraData
            if a.spellId == spellId then
                return a
            end
        end
    end

    -- === 4. 未找到任何符合的光環，安全回傳 nil ===
    return nil
end

----------------------------------------------------------------
--取得法術ID在指定單位身上的 BUFF索引
------------------------------------------------------------------
function G:GetBuffIndexOfSpellID(argUnitId, argSpellId)

	
	local spellId
	local i
	local aura
	for i = 1, MAX_AURAS do
		
		if not C_Secrets.ShouldUnitAuraIndexBeSecret(argUnitId, i, "HELPFUL")  then
			aura = UnitAura(argUnitId, i, "HELPFUL")
			if aura then
				if type(aura) == "table" then 
					spellId  = aura.spellId 
				else	
					spellId = select(10, UnitAura(argUnitId, i, "HELPFUL"))
				end
				
			end   			
			
			if (argSpellId == spellId)	then 
				return i
			end
		end
	end
	return nil 
end
------------------------------------------------------------------
--取得法術ID在指定單位身上的 DEBUFF索引
------------------------------------------------------------------
-- AuraUtil.ForEachAura(unit, filter, [maxCount], func)
function G:GetDebuffIndexOfSpellID(argUnitId, argSpellId)		
	
	
	local spellId
	local i
	local aura
	for i = 1, MAX_AURAS do
		if not C_Secrets.ShouldUnitAuraIndexBeSecret(argUnitId, i, "HARMFUL")  then
			aura = UnitAura(argUnitId, i, "HARMFUL")
			if aura then
				if type(aura) == "table" then 
					spellId  = aura.spellId 
				else	
					spellId = select(10, UnitAura(argUnitId, i, "HARMFUL"))
				end
				
			end
			
			
			if (argSpellId == spellId)	then 
				return i
			end
		end
	end
	return nil 
end

------------------------------------------------------------------
--當前角色是否已學會該法術技能
------------------------------------------------------------------
function G:IsLearnSpell(spellId)
	
	if IsPlayerSpell then 
	  return(IsPlayerSpell(spellId))
    else
		local spellInfo = GetSpellInfo(spellId)
		local sName = (type(spellInfo) == "table") and spellInfo.name or select(1, spellInfo)
		return GetSpellInfo(sName) 
	end
end
------------------------------------------------------------------
--
------------------------------------------------------------------
function G:IsActiveTalentBySpellID(Chk_spellId)
	local r=0
	local c=0
	local talent_row_max = 7
	local talent_col_max = 3
	local playerSpecGroup = GetActiveSpecGroup()
	local talent_row = 0
	local talent_col = 0
	local isActiveTalentSpellID = false
	for r = 1, talent_row_max do
		for c = 1, talent_col_max do
			local _,_,_,talentSelected,_,spellId = GetTalentInfo(r, c, playerSpecGroup)
			if Chk_spellId == spellId then
				talent_row = r
				talent_col = c				
				if talentSelected then
					isActiveTalentSpellID = true
				end
			end
		end
	end
	return isActiveTalentSpellID,talent_row,talent_col
end
------------------------------------------------------------------
--
------------------------------------------------------------------