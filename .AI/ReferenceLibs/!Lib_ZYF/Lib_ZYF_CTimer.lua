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

-- 取得 C_Timer 引用，避免每次呼叫時全域查找
-- 本地化常用 API，避免反覆查表
local C_Timer = C_Timer
local collectgarbage = collectgarbage
-- 取用 table.unpack；如果舊版環境沒有 table.unpack，則退回全域 unpack
local t_unpack = table.unpack or unpack

-- 任務池：以更新間隔 (sec) 為索引，每一個池包含多個任務與對應的 ticker
Lib_ZYF.pools = {}
Lib_ZYF.framePools = {}

-- 取得或創建指定間隔的任務池
local function GetPool(poolTable, sec)
    local pool = poolTable[sec]
    if not pool then
        pool = { tasks = {}, ticker = nil }
        poolTable[sec] = pool

        -- 建立 ticker，迭代執行池中的所有任務
        local function OnTick()
            for i = #pool.tasks, 1, -1 do
                local task = pool.tasks[i]
                -- 檢查是否需要移除：Frame 已隱藏，或達到執行次數
                if (task.frame and not task.frame:IsShown()) or (task.times and task.count >= task.times) then
                    table.remove(pool.tasks, i)
                    if task.frame then task.frame._zyfTask = nil end
                else
                    -- 避免回調重入
                    if not task.running then
                        task.running = true
                        local args = task.args or {}
                        -- 安全呼叫回調；Frame 為第一參數，其餘參數由 args 展開
                        local ok, err = pcall(task.callback, task.frame or nil, t_unpack(args))
						
                        task.running = false
                        if not ok then
                            print("Lib_ZYF_CTimer callback error:", err)
                        end
                        -- 計次任務累積次數
                        if task.times then
                            task.count = (task.count or 0) + 1
                        end
                    end
                end
            end
            -- 池若已空，停止 ticker 並從表中移除
            if #pool.tasks == 0 then
                pool.ticker:Cancel()
                poolTable[sec] = nil
            else
                -- 根據任務數量執行平滑垃圾回收
                collectgarbage("step", 50 * #pool.tasks)
            end
        end

        pool.ticker = C_Timer.NewTicker(sec, OnTick)
    end
    return pool
end

------------------------------------------------------------------------------
--  一次性延遲調用：sec 秒後執行一次回調
------------------------------------------------------------------------------
function Lib_ZYF:SetOnUpdateOnce(sec, callback, ...)
    if type(callback) ~= "function" or type(sec) ~= "number" then return end
    local args = select('#', ...) > 0 and { ... } or {}
    C_Timer.After(sec, function()
        local ok, err = pcall(callback, t_unpack(args))
        if not ok then print("Lib_ZYF_CTimer SetOnUpdateOnce error:", err) end
        collectgarbage("step", 100)
    end)
end

------------------------------------------------------------------------------
--  週期性定時調用：無執行次數限制
------------------------------------------------------------------------------
function Lib_ZYF:SetOnUpdate(sec, callback, ...)
    if type(callback) ~= "function" or type(sec) ~= "number" then return end
    local pool = GetPool(Lib_ZYF.pools, sec)
    local task = {
        callback = callback,
        args     = select('#', ...) > 0 and { ... } or {},
        running  = false,
    }
    table.insert(pool.tasks, task)

    -- 回傳控制器，可用於手動取消
    return {
        Cancel = function()
            for i, t in ipairs(pool.tasks) do
                if t == task then
                    table.remove(pool.tasks, i)
                    break
                end
            end
            if #pool.tasks == 0 then
                pool.ticker:Cancel()
                Lib_ZYF.pools[sec] = nil
            end
        end
    }
end

------------------------------------------------------------------------------
--  週期性定時調用：指定執行 times 次後自動取消
------------------------------------------------------------------------------
function Lib_ZYF:SetOnUpdateTimes(sec, times, callback, ...)
    if type(callback) ~= "function" or type(sec) ~= "number" or type(times) ~= "number" or times <= 0 then
        return
    end
    local pool = GetPool(Lib_ZYF.pools, sec)
    local task = {
        callback = callback,
        args     = select('#', ...) > 0 and { ... } or {},
        times    = times,
        count    = 0,
        running  = false,
    }
    table.insert(pool.tasks, task)

    return {
        Cancel = function()
            for i, t in ipairs(pool.tasks) do
                if t == task then
                    table.remove(pool.tasks, i)
                    break
                end
            end
            if #pool.tasks == 0 then
                pool.ticker:Cancel()
                Lib_ZYF.pools[sec] = nil
            end
        end
    }
end

------------------------------------------------------------------------------
--  與 Frame 綁定的週期性更新：Frame 必須持續顯示，否則自動取消
------------------------------------------------------------------------------
function Lib_ZYF:FrameSetOnUpdate(frame, sec, callback, ...)
    if not frame or type(callback) ~= "function" or type(sec) ~= "number" then return end
    -- 先取消 Frame 既有任務
    if frame._zyfTask then
        self:StopOnUpdate(frame)
    end
    local pool = GetPool(Lib_ZYF.framePools, sec)
    local task = {
        frame    = frame,
        callback = callback,
        args     = select('#', ...) > 0 and { ... } or {},
        running  = false,
    }
    table.insert(pool.tasks, task)
    frame._zyfTask = { pool = pool, task = task }
    frame:Show()
    return frame
end

------------------------------------------------------------------------------
--  與 Frame 綁定的一次性延遲調用：sec 秒後呼叫一次 callback
------------------------------------------------------------------------------
function Lib_ZYF:FrameSetOnUpdateOnce(frame, sec, callback, ...)
    if not frame or type(callback) ~= "function" or type(sec) ~= "number" then return end
    local args = { ... }
    C_Timer.After(sec, function()
        local ok, err = pcall(callback, frame, t_unpack(args))
        if not ok then print("Lib_ZYF_CTimer FrameSetOnUpdateOnce error:", err) end        
    end)
    return frame
end

------------------------------------------------------------------------------
--  停止與 Frame 綁定的週期性更新，但不隱藏或釋放 Frame
------------------------------------------------------------------------------
function Lib_ZYF:StopOnUpdate(frame)
    if not frame or not frame._zyfTask then return end
    local pool = frame._zyfTask.pool
    local task = frame._zyfTask.task
    -- 從任務池中移除
    for i, t in ipairs(pool.tasks) do
        if t == task then
            table.remove(pool.tasks, i)
            break
        end
    end
    -- 如果池已空，取消 ticker
    if #pool.tasks == 0 and pool.ticker then
        pool.ticker:Cancel()
        Lib_ZYF.framePools[task.sec] = nil
    end
    frame._zyfTask = nil
end

------------------------------------------------------------------------------
--  完全清除與 Frame 綁定的更新並釋放 Frame
------------------------------------------------------------------------------
function Lib_ZYF:ClrOnUpdate(frame)
    if not frame then return end
    self:StopOnUpdate(frame)
    frame:Hide()
    frame:SetParent(nil)
end

------------------------------------------------------------------------------
--  其他事件及 CombatLog 函式可沿用舊版或在此繼續封裝。
--  例如：
--  function Lib_ZYF:SetEvent(event, callback, ...)
--      frame:RegisterEvent(event)
--      frame:SetScript("OnEvent", function(_, ...)
--          callback(...)
--      end)
--  end
--  ...
---

---------設定事件要執行的函式
Lib_ZYF.Events = {}
function Lib_ZYF:SetEvent(event, callback, ...)
---------
	return EventRegistry:RegisterCallback(event, callback,  ...)
	
	-- local arg = ...	
	-- local t = Lib_ZYF		
	-- local f = CreateFrame("Frame","ZYFCombatEvent_"..GetTime(), nil)
	-- f:RegisterEvent(event)
	-- f:SetScript("OnEvent", callback, arg)
	-- --Lib_ZYF.Events[#Lib_ZYF.Events + 1] = f
	-- table.insert(t.Events, f)
	-- return f
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


