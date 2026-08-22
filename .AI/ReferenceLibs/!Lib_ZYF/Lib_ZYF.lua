----------------------------------------------------
-- Assign addon space to local G var.  
-- For sync addon space to each lua fils
-----------------------------------------------------
local _
local _G = _G
local addonName, G = ... 
_G[addonName] = _G[addonName] or G
-----------------------------------

---------
if Lib_ZYF then 
	return 
else
	Lib_ZYF = {}
end

---------
local print = print
local type = type
local pairs = pairs
local ipairs = ipairs 
local tonumber = tonumber
local strmatch = string.match
local CreateFrame = CreateFrame 
local GetLocale = GetLocale
local GetSpellDescription = GetSpellDescription or C_Spell.GetSpellDescription

---------停止某個定時更新的frame,並清除frame
function Lib_ZYF:ClrOnUpdate(frame)
    if frame then
        frame:SetScript("OnUpdate", nil)
        frame._zyfOnUpdateData = nil
        frame:Hide()
        frame:SetParent(nil)
    end
end



--------停止某個定時更新的frame
function Lib_ZYF:StopOnUpdate(frame)
    if frame and frame._zyfOnUpdateData then
        frame._zyfOnUpdateData.active = false
        frame:SetScript("OnUpdate", nil)
    end
end

--------繼續某個定時更新的frame
function Lib_ZYF:ResumeOnUpdate(frame)
    local data = frame and frame._zyfOnUpdateData
    if not data or frame:GetScript("OnUpdate") then return end

    local SinceUpdateTime = 0
    local flagRunning = false

    frame:SetScript("OnUpdate", function(self, elapsed)
        if not data.active then return end
        SinceUpdateTime = SinceUpdateTime + elapsed

        if SinceUpdateTime >= data.interval then
            if not flagRunning then
                flagRunning = true
                pcall(data.callback, unpack(data.args))
                flagRunning = false
                SinceUpdateTime = 0
            end
        end
    end)
end

---------設定定時更新某個函式
function Lib_ZYF:SetOnUpdate(sec, callback, ...)
    if type(callback) ~= "function" then return nil end

    local args = {...}
    local SinceUpdateTime = 0
    local flagRunning = false

    local DummyFrame = CreateFrame("Frame", "ZYFOnUpdate_"..sec.."_"..math.random(100000))
    DummyFrame._zyfOnUpdateData = {
        interval = sec,
        callback = callback,
        args = args,
        active = true,
    }

    DummyFrame:SetScript("OnUpdate", function(self, elapsed)
        local data = self._zyfOnUpdateData
        if not data or not data.active then return end

        SinceUpdateTime = SinceUpdateTime + elapsed

        if SinceUpdateTime >= sec then
            if not flagRunning then
                flagRunning = true
                pcall(callback, unpack(args))  -- 安全執行
                flagRunning = false
                SinceUpdateTime = 0
            end
        end
    end)

    return DummyFrame
end

---------指定FRAME定時更新某個函式
function Lib_ZYF:FrameSetOnUpdate(frame, sec, callback, ...)
    if not frame or type(callback) ~= "function" then return end

    -- 清除舊的 OnUpdate
    frame:SetScript("OnUpdate", nil)

    local args = {...}
    local SinceUpdateTime = 0
    local flagRunning = false

    -- 儲存更新資訊以供後續 Resume / Stop / Debug
    frame._zyfOnUpdateData = {
        interval = sec,
        callback = callback,
        args = args,
        active = true,
    }

    frame:SetScript("OnUpdate", function(self, elapsed)
        if not frame._zyfOnUpdateData or not frame._zyfOnUpdateData.active then return end
        SinceUpdateTime = SinceUpdateTime + elapsed

        if SinceUpdateTime >= sec then
            if not flagRunning then
                flagRunning = true
                pcall(callback, frame, unpack(args))  -- 用 pcall 保險點
                flagRunning = false
                SinceUpdateTime = 0
            end
        end
    end)

    return frame
end

---------設定定時更新某個函式幾次
function Lib_ZYF:SetOnUpdateTimes(sec, times, callback, ...)
    if type(callback) ~= "function" then return end

    local args = {...}
    local SinceUpdateTime, UpdateTimes = 0, 0
    local flagRunning = false

    local DummyFrame = CreateFrame("Frame", "ZYFOnUpdateTimes_"..sec.."_"..times.."_"..math.random(10000))
    DummyFrame._zyfOnUpdateData = {
        interval = sec,
        times = times,
        callback = callback,
        args = args,
        active = true,
    }

    DummyFrame:SetScript("OnUpdate", function(self, elapsed)
        if not self._zyfOnUpdateData or not self._zyfOnUpdateData.active then return end

        SinceUpdateTime = SinceUpdateTime + elapsed
        if SinceUpdateTime >= sec and not flagRunning then
            flagRunning = true
            pcall(callback, unpack(args))
            flagRunning = false
            SinceUpdateTime = 0
            UpdateTimes = UpdateTimes + 1
            if UpdateTimes >= times then
                Lib_ZYF:ClrOnUpdate(self)
            end
        end
    end)

    return DummyFrame
end

---------指定Frame設定定時更新某個函式幾次
function Lib_ZYF:FrameSetOnUpdateTimes(frame, sec, times, callback, ...)
    if not frame or type(callback) ~= "function" then return end

    frame:SetScript("OnUpdate", nil)  -- 清除舊腳本
    local args = {...}
    local SinceUpdateTime, UpdateTimes = 0, 0
    local flagRunning = false

    frame._zyfOnUpdateData = {
        interval = sec,
        times = times,
        callback = callback,
        args = args,
        active = true,
    }

    frame:SetScript("OnUpdate", function(self, elapsed)
        if not self._zyfOnUpdateData or not self._zyfOnUpdateData.active then return end

        SinceUpdateTime = SinceUpdateTime + elapsed
        if SinceUpdateTime >= sec and not flagRunning then
            flagRunning = true
            pcall(callback, self, unpack(args))
            flagRunning = false
            SinceUpdateTime = 0
            UpdateTimes = UpdateTimes + 1
            if UpdateTimes >= times then
                Lib_ZYF:StopOnUpdate(self)
            end
        end
    end)

    return frame
end
---------設定定時更新某個函式一次
function Lib_ZYF:SetOnUpdateOnce(sec, callback, ...)
    return Lib_ZYF:SetOnUpdateTimes(sec, 1, callback, ...)
end
---------指定Frame設定定時更新某個函式一次
function Lib_ZYF:FrameSetOnUpdateOnce(frame, sec, callback, ...)
    return Lib_ZYF:FrameSetOnUpdateTimes(frame, sec, 1, callback, ...)
end

---------設定事件要執行的函式
Lib_ZYF.Events = {}
function Lib_ZYF:SetEvent(event, callback, ...)
---------
	local arg = ...	
	local t = Lib_ZYF		
	local f = CreateFrame("Frame","ZYFCombatEvent_"..GetTime())
	f:RegisterEvent(event)
	f:SetScript("OnEvent",callback,arg)
	--Lib_ZYF.Events[#Lib_ZYF.Events + 1] = f
	table.insert(t.Events, f)
	return f
end

---------設定戰鬥事件要執行的函式(模擬RegisterCombatEvent)
Lib_ZYF.CombatEvents = {}
function Lib_ZYF:SetCombatLogEvent(subEvent,callback,...)
---------
	local arg = ...
	local idx	
	local t = Lib_ZYF		
	t.CombatEvents[subEvent] = t.CombatEvents[subEvent] or {}
	
	--idx = #Lib_ZYF.CombatEvents[subEvent] + 1
	--self.CombatEvents[subEvent][idx] = callback
	table.insert(t.CombatEvents[subEvent], callback)
	
end
---------
Lib_ZYF:SetEvent("COMBAT_LOG_EVENT_UNFILTERED", function()
---------		
		local 	t = Lib_ZYF		
		local 	tmp = CombatLogGetCurrentEventInfo()	
		local 	timestp, event, hideCaster, 
				surGUID, surName, surFlags, surRaidFlags, 
				dstGUID, dstName, dstFlags, dstRaidFlags, 
				spellID, spellName = tmp	
		
		if t.CombatEvents[event] then
			for i, func in ipairs(t.CombatEvents[event]) do 
				if func and type(func) == "function" then 
					-- func(CombatLogGetCurrentEventInfo())
					func(tmp)
				end				
			end
		end
	end)

---------------------------------------------
--定時更新玩家座標並儲存,供其他函式取用
---------------------------------------------
Lib_ZYF.map = {}
Lib_ZYF.map.ID = nil
Lib_ZYF.map.PosObject = nil
Lib_ZYF.map.PositionX = 0
Lib_ZYF.map.PositionY = 0
Lib_ZYF.map.subZoneText = ""
Lib_ZYF.map.zoneText = ""
function Lib_ZYF:UpdatePlayerPosition()

	local t = Lib_ZYF
	--local t = self
	
	t.map.subZoneText = _G.GetSubZoneText() or ""
	t.map.zoneText = _G.GetRealZoneText() or ""
	
	t.map.ID = _G.C_Map.GetBestMapForUnit("player")
	if (t.map.ID == nil) then
		return
	end
	
	t.map.PosObject = _G.C_Map.GetPlayerMapPosition(t.map.ID, "player" )
	if (t.map.PosObject) then        
		t.map.PositionX, t.map.PositionY = t.map.PosObject:GetXY()
		--print(Lib_ZYF.zoneText,":",Lib_ZYF.subZoneText,format("(%.1f",Lib_ZYF.mapPositionX*100),format(", %.1f)",Lib_ZYF.mapPositionY*100))
	end

	if (t.map.PositionX == nil) then
		t.map.PositionX = 0
	end
	if (t.map.PositionY == nil) then
		t.map.PositionY = 0
	end
	
end	
---------------------------------------------
--每10秒儲存一次玩家當前座標及區域資訊	
---------------------------------------------

-- Lib_ZYF:SetOnUpdate(10, Lib_ZYF.UpdatePlayerPosition)

---------------------------------------------
--依據儲存的資訊回傳座標
---------------------------------------------
function Lib_ZYF:GetPlayerPosition()
	local t = Lib_ZYF
	--local t = self
	return {t.map.PositionX, t.map.PositionY}	
end

---------------------------------------------
--依據儲存的資訊回傳當前地區
---------------------------------------------
function Lib_ZYF:GetPlayerZone()
	local t = Lib_ZYF
	--local t = self
	return t.map.zoneText
end

---------------------------------------------
--依據儲存的資訊回傳當前子區域
---------------------------------------------
function Lib_ZYF:GetPlayerSubZone()
	local t = Lib_ZYF
	--local t = self
	return t.map.subZoneText
end

---------------------------------------------
-- SetBackdrop for Shadowland version 
---------------------------------------------
function Lib_ZYF:SetBackdrop(frame, backdropInfo)
    if not frame then return end

    if not backdropInfo then
        if frame.Backdrop then
            frame.Backdrop:Hide()
            frame.Backdrop:SetParent(nil)
            frame.Backdrop = nil
        end
        return nil
    end

    local frameLevel = (frame:GetFrameLevel() > 1) and frame:GetFrameLevel() or 2

    if not frame.Backdrop then
        frame.Backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.Backdrop:SetFrameLevel(frameLevel - 1)
        frame.Backdrop:SetAllPoints()
    end

    -- 避免過度頻繁調用 Apply
    local current = frame.Backdrop.backdropInfo
    if not current or current.bgFile ~= backdropInfo.bgFile or current.edgeFile ~= backdropInfo.edgeFile then
        frame.Backdrop.backdropInfo = backdropInfo
        if frame.Backdrop.ApplyBackdrop then
            frame.Backdrop:ApplyBackdrop()
        end
    end

    frame.Backdrop:Show()
    return frame.Backdrop
end


-- 共用建立 backdrop 方法
function Lib_ZYF:EnsureBackdrop(frame)
	if not frame then return nil end
	if frame.Backdrop and frame.Backdrop:IsObjectType("Frame") then
		return frame.Backdrop
	end

	local frameLevel = (frame:GetFrameLevel() > 1) and frame:GetFrameLevel() or 2
	local bd = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	bd:SetFrameLevel(frameLevel - 1)
	bd:SetAllPoints()
	frame.Backdrop = bd
	return bd
end

-- 設定背景顏色
function Lib_ZYF:SetBackdropColor(frame, r, g, b, a)
	local bd = self:EnsureBackdrop(frame)
	if bd then
		bd:SetBackdropColor(r, g, b, a)
		return bd
	end
end

-- 設定邊框顏色
function Lib_ZYF:SetBackdropBorderColor(frame, r, g, b, a)
	local bd = self:EnsureBackdrop(frame)
	if bd then
		bd:SetBackdropBorderColor(r, g, b, a)
		return bd
	end
end

-- 移除 backdrop，並釋放資源
function Lib_ZYF:ReleaseBackdrop(frame)
	if frame and frame.Backdrop then
		frame.Backdrop:Hide()
		frame.Backdrop:SetParent(nil)
		frame.Backdrop = nil
	end
end

function Lib_ZYF:GetDefaultBackdrop(style)
	style = style or "dark"
	if style == "dark" then
		return {
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		}
	elseif style == "flat" then
		return {
			bgFile = "Interface\\Buttons\\WHITE8x8",
			tile = true, tileSize = 8, edgeSize = 0,
			insets = { left = 0, right = 0, top = 0, bottom = 0 },
		}
	end
end

---------------------------------------------
-- Get Spell Time From GetSpellDescription()
---------------------------------------------
Lib_ZYF.SpellDurationByDesc = {}
Lib_ZYF.SpellDurationByDesc["zhTW"] = {
	
	{pattern = "(在|持續|效力|)(%s|)%d+%p*%d*(%s|)(秒(内|))",		mul=1},
	{pattern = "(在|持續|效力|)(%s|)%d+%p*%d*(%s|)(分(内|))",		mul=60},
	{pattern = "(在|持續|效力|)(%s|)%d+%p*%d*(%s|)(小時(内|))",	mul=60*60},
	{pattern = "(在|持續|效力|)(%s|)%d+%p*%d*(%s|)(天(内|))",		mul=60*60*24},
	{pattern = "(在|持續|效力|)(%s|)%d+%p*%d*(%s|)(週(内|))",		mul=60*60*24*7},
	
	{pattern = "在%d+%p?%d*秒",		mul=1},
	{pattern = "持續%d+%p?%d*秒",	mul=1},
	{pattern = "%d+%p?%d*秒內",		mul=1},
	{pattern = "效力%d+%p?%d*秒",	mul=1},
	
	{pattern = "在%d+%p?%d*分", 		mul=60},
	{pattern = "持續%d+%p?%d*分",	mul=60},
	{pattern = "%d+%p?%d*分內", 		mul=60},
	{pattern = "效力%d+%p?%d*分", 	mul=60},
	
	{pattern = "在%d+%p?%d*小時", 	mul=3600},
	{pattern = "持續%d+%p?%d*小時",	mul=3600},
	{pattern = "%d+%p?%d*小時內", 	mul=3600},
	{pattern = "效力%d+%p?%d*小時", 	mul=3600},
}
Lib_ZYF.SpellDurationByDesc["zhCN"] = {
	{pattern = "在%d+%p?%d*秒", 		mul=1},
	{pattern = "持续%d+%p?%d*秒",	mul=1},
	{pattern = "%d+%p?%d*秒内",		mul=1},
	{pattern = "效力%d+%p?%d*秒",	mul=1},
	
	
	
	{pattern = "在%d+%p?%d*分",		mul=60},
	{pattern = "持续%d+%p?%d*分",	mul=60},
	{pattern = "%d+%p?%d*分内",		mul=60},
	{pattern = "效力%d+%p?%d*分", 	mul=60},
	
	
	{pattern = "在%d+%p?%d*小时",	mul=3600},
	{pattern = "持续%d+%p?%d*小时",	mul=3600},
	{pattern = "%d+%p?%d*小时内",	mul=3600},	
	{pattern = "效力%d+%p?%d*小时", 	mul=3600},
	
	{pattern = "(在|持续|效力|)(%s|)%d+%p*%d*(%s|)(秒(内|))",		mul=1},
	{pattern = "(在|持续|效力|)(%s|)%d+%p*%d*(%s|)(分(内|))",		mul=60},
	{pattern = "(在|持续|效力|)(%s|)%d+%p*%d*(%s|)(小时(内|))",	mul=60*60},
	{pattern = "(在|持续|效力|)(%s|)%d+%p*%d*(%s|)(天(内|))",		mul=60*60*24},
	{pattern = "(在|持续|效力|)(%s|)%d+%p*%d*(%s|)(周(内|))",		mul=60*60*24*7},
}
Lib_ZYF.SpellDurationByDesc["enUS"] = {
	{pattern = "(for|lasts|for up to|)(%s|)%d+%p*%d*(%s|)(sec|)",	mul=1},
	{pattern = "(for|lasts|for up to|)(%s|)%d+%p*%d*(%s|)(min|)",	mul=60},
	{pattern = "(for|lasts|for up to|)(%s|)%d+%p*%d*(%s|)(hour|)",	mul=60*60},
	{pattern = "(for|lasts|for up to|)(%s|)%d+%p*%d*(%s|)(day|)",	mul=60*60*24},
	{pattern = "(for|lasts|for up to|)(%s|)%d+%p*%d*(%s|)(week|)",	mul=60*60*24*7},
	
	{pattern = "for %d+%p?%d* sec",			mul=1},
	{pattern = "lasts %d+%p?%d* sec",		mul=1},
	{pattern = "for up to %d+%p?%d* sec",	mul=1},
	
	{pattern = "for %d+%p?%d* min",			mul=60},
	{pattern = "lasts %d+%p?%d* min",		mul=60},
	{pattern = "for up to %d+%p?%d* min",	mul=60},
	
	{pattern = "for%d+%p?%d* hour",			mul=3600},
	{pattern = "lasts%d+%p?%d* hour",		mul=3600},
	{pattern = "for up to %d+%p?%d* hour",	mul=3600},	
}
Lib_ZYF.SpellDurationByDesc["koKR"] = {
	
	{pattern = "(for|lasts|for up to|)(%s|)%d+%p*%d*(%s|)(sec|)",	mul=1},
	{pattern = "(for|lasts|for up to|)(%s|)%d+%p*%d*(%s|)(min|)",	mul=60},
	{pattern = "(for|lasts|for up to|)(%s|)%d+%p*%d*(%s|)(hour|)",	mul=60*60},
	{pattern = "(for|lasts|for up to|)(%s|)%d+%p*%d*(%s|)(day|)",	mul=60*60*24},
	{pattern = "(for|lasts|for up to|)(%s|)%d+%p*%d*(%s|)(week|)",	mul=60*60*24*7},
	
	{pattern = "for %d+%p?%d* sec",			mul=1},
	{pattern = "lasts %d+%p?%d* sec",		mul=1},
	{pattern = "for up to %d+%p?%d* sec",	mul=1},
	
	{pattern = "for %d+%p?%d* min",			mul=60},
	{pattern = "lasts %d+%p?%d* min",		mul=60},
	{pattern = "for up to %d+%p?%d* min",	mul=60},
	
	{pattern = "for%d+%p?%d* hour",			mul=3600},
	{pattern = "lasts%d+%p?%d* hour",		mul=3600},
	{pattern = "for up to %d+%p?%d* hour",	mul=3600},	
}

function Lib_ZYF:GetSpellDurationByDesc(spellID)	

	return M:GetDuration(spellID)
	-- local t = Lib_ZYF
	-- --local t = self	
	
	-- local spellDescription = GetSpellDescription(spellID)			
	-- local strSpellDuration
	-- local numSpellDuration			
	-- local SpellDurationByDesc = t.SpellDurationByDesc[GetLocale()]
	
	-- local p
		
	-- for _, p in ipairs(SpellDurationByDesc) do 
		-- strSpellDuration = strmatch(spellDescription, p.pattern)				
		-- if strSpellDuration then		
			-- numSpellDuration = tonumber(strmatch(strSpellDuration,"%d+%p?%d*")) * p.mul
			-- return numSpellDuration			
		-- end
	-- end			
	-- return 0
end		


-- Lib_ZYF Spell Description Parser 模組化版本
Lib_ZYF.SpellDescParser = {}
local M = Lib_ZYF.SpellDescParser

-- 語系模式表（簡化版）
M.DurationPatterns = {
    zhTW = {
        {pattern = "[在持續效力]?%s*(%d+[%p%d]*)%s*秒[內]?", mul=1},
        {pattern = "[在持續效力]?%s*(%d+[%p%d]*)%s*分[內]?", mul=60},
        {pattern = "[在持續效力]?%s*(%d+[%p%d]*)%s*小時[內]?", mul=3600},
        {pattern = "[在持續效力]?%s*(%d+[%p%d]*)%s*天[內]?", mul=86400},
        {pattern = "[在持續效力]?%s*(%d+[%p%d]*)%s*週[內]?", mul=604800},
        {pattern = "[在持續效力]?%s*(%d+[%p%d]*)%s*月[內]?", mul=2592000}, -- 約30天
        {pattern = "[在持續效力]?%s*(%d+[%p%d]*)%s*年[內]?", mul=31536000}, -- 365天
    },
    zhCN = {
        {pattern = "[在持续效力]?%s*(%d+[%p%d]*)%s*秒[内]?", mul=1},
        {pattern = "[在持续效力]?%s*(%d+[%p%d]*)%s*分[内]?", mul=60},
        {pattern = "[在持续效力]?%s*(%d+[%p%d]*)%s*小时[内]?", mul=3600},
        {pattern = "[在持续效力]?%s*(%d+[%p%d]*)%s*天[内]?", mul=86400},
        {pattern = "[在持续效力]?%s*(%d+[%p%d]*)%s*周[内]?", mul=604800},
        {pattern = "[在持续效力]?%s*(%d+[%p%d]*)%s*月[内]?", mul=2592000},
        {pattern = "[在持续效力]?%s*(%d+[%p%d]*)%s*年[内]?", mul=31536000},
    },
    enUS = {
        {pattern = "(%d+[%p%d]*) sec", mul=1},
        {pattern = "(%d+[%p%d]*) min", mul=60},
        {pattern = "(%d+[%p%d]*) hour", mul=3600},
        {pattern = "(%d+[%p%d]*) day", mul=86400},
        {pattern = "(%d+[%p%d]*) week", mul=604800},
        {pattern = "(%d+[%p%d]*) month", mul=2592000},
        {pattern = "(%d+[%p%d]*) year", mul=31536000},
    },
    koKR = {
        {pattern = "(%d+[%p%d]*)초", mul=1},
        {pattern = "(%d+[%p%d]*)분", mul=60},
        {pattern = "(%d+[%p%d]*)시간", mul=3600},
        {pattern = "(%d+[%p%d]*)일", mul=86400},
        {pattern = "(%d+[%p%d]*)주", mul=604800},
        {pattern = "(%d+[%p%d]*)개월", mul=2592000},
        {pattern = "(%d+[%p%d]*)년", mul=31536000},
    }
}

-- 主解析函式：給 spell description 或 spellID，回傳秒數
function M:GetDuration(descOrID, locale)
    local desc = type(descOrID) == "number" and GetSpellDescription(descOrID) or descOrID
    if not desc or desc == "" then return 0 end

    locale = locale or GetLocale()
    local patterns = M.DurationPatterns[locale] or M.DurationPatterns["enUS"]

    for _, rule in ipairs(patterns) do
        local match = strmatch(desc, rule.pattern)
        if match then
            local num = tonumber(match)
            if num then
                return num * rule.mul
            end
        end
    end

    return 0
end

-- 說明：你可以這樣使用
-- local dur = Lib_ZYF.SpellDescParser:GetDuration(spellID)
-- local dur2 = Lib_ZYF.SpellDescParser:GetDuration("持續8秒")

----------------------------------------------
-- 
----------------------------------------------

----------------------------------------------
-- 
----------------------------------------------

----------------------------------------------
-- 
----------------------------------------------


