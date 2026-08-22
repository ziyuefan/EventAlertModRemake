--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_Cooldown.lua

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
-- EventAlert_Cooldown.lua 全新實作（主線 11.1.7+）

local addonName, G = ...
_G[addonName] = _G[addonName] or G

--------------------------------------------------------------
-- 常用函式/變數本地化
--------------------------------------------------------------
local C_AddOns, C_Spell, C_Item, C_Container = C_AddOns, C_Spell, C_Item, C_Container
local CreateFrame = CreateFrame
local GetTime = GetTime
local floor = math.floor
local table_sort = table.sort
local table_unpack = table.unpack or unpack

-- Spell API
local GetSpellCooldown 		= type(GetSpellCooldown) == "function" 	and GetSpellCooldown 	 or C_Spell.GetSpellCooldown
local GetSpellBaseCooldown	= type(GetSpellCooldown) == "function" 	and GetSpellBaseCooldown or C_Spell.GetSpellBaseCooldown 
local GetSpellCharges 		= type(GetSpellCharges) == "function" 	and GetSpellCharges 	 or C_Spell.GetSpellCharges
local GetSpellTexture 		= type(GetSpellTexture) == "function" 	and GetSpellTexture 	 or C_Spell.GetSpellTexture
local IsUsableSpell 		= type(IsUsableSpell) == "function" 	and IsUsableSpell 		 or C_Spell.IsSpellUsable

-- Item/Inventory API
local GetInventoryItemCooldown = GetInventoryItemCooldown
local GetInventoryItemID = GetInventoryItemID
local GetItemSpell 		= type(GetItemSpell)	 == "function" and GetItemSpell		or C_Item.GetItemSpell
local GetItemCooldown 	= type(GetItemCooldown)	 == "function" and GetItemCooldown	or C_Item.GetItemCooldown

-- WOW API : Specialization   
local GetSpecialization 		= GetSpecialization 	and GetSpecialization 		or C_SpecializationInfo.GetSpecialization
local GetSpecializationInfo 	= GetSpecializationInfo	and GetSpecializationInfo 	or C_SpecializationInfo.GetSpecializationInfo
local GetActiveSpecGroup		= GetActiveSpecGroup	and GetActiveSpecGroup 		or C_SpecializationInfo.GetActiveSpecGroup

-- Frame API
local UIParent = UIParent

-- 其他環境
-- local EA_Config = EA_Config           -- 使用者設定
-- local EA_Position = EA_Position       -- 框架位置設定
local ScdItems = EA_ScdItems          -- 各職業冷卻表
local SPELLINFO_SCD = G.SPELLINFO_SCD -- 冷卻資訊快取

G.CachedPlayerName = G.CachedPlayerName or UnitName("player")
G.CachedPetName    = G.CachedPetName    or UnitName("pet")


-- 初始化冷卻列表
G.EA_ScdCurrentBuffs = G.EA_ScdCurrentBuffs or {}

----------------------------------------------------------------------
-- 辅助函式
----------------------------------------------------------------------

-- 取得技能冷卻，考慮 modRate，如無則回傳 0
local function GetNormalizedCooldown(spellId)
	
	if C_Secrets.ShouldSpellCooldownBeSecret(spellId) then return end
	
    local info = GetSpellCooldown(spellId)
    local start, duration, enable, modRate
    if type(info) == "table" then
        start = info.startTime
        duration = info.duration
        enable = info.isEnabled
        modRate = info.modRate or 1
        if duration > 0 then
            duration = duration / modRate
        end
    else
        start, duration, enable = GetSpellCooldown(spellId)
    end
    if not duration or duration == 0 then
        local _, baseMS = GetSpellBaseCooldown(spellId)
        if baseMS and baseMS > 0 then
            duration = baseMS / 1000
        else
            duration = 0 -- 代表無固定冷卻
        end
    end
	
	--GCD冷卻不進行倒數
	GCD_spellID = 61304
	local GCD = GetSpellCooldown(GCD_spellID)  	
	if GCD	then
		if type(GCD) == "table" then 
			if GCD.startTime > 0 and GCD.startTime == start then return 0, 0 , GCD.isEnabled end
		else
			local GCD_start, GCD_duration, GCD_enable = GetSpellCooldown(GCD_spellID)
			if GCD_start > 0 and GCD_start == start then return 0, 0 , GCD_enable end
		end		
	end
	
    return start or 0, duration or 0, enable
end

-- 檢查身上物品是否提供該 spellId 的冷卻（一般為飾品）
local function GetItemCooldownForSpell(spellId)
	
	local t0 = debugprofilestop()
	--
	local idFromItem
    local now = GetTime()
    local bestStart, bestDuration, bestEnable
    for slot = 17, 1, -1 do
        local itemId = GetInventoryItemID("player", slot)
        if itemId then
			
			if HeroDBC and HeroDBC.DBC.ItemSpell and HeroDBC.DBC.ItemSpell[itemId] then
				idFromItem =   HeroDBC.DBC.ItemSpell[itemId]
			else
				idFromItem =   select(2, GetItemSpell(itemId))
			end
            
            if idFromItem == spellId then
                local s, d, en = GetInventoryItemCooldown("player", slot)
                if not bestStart or (s + d - now) > (bestStart + bestDuration - now) then
                    bestStart, bestDuration, bestEnable = s, d, en				
                end
            end
        end
    end
    
	G:EAFun_testLabel("GetItemCooldownForSpell", t0, debugprofilestop())
	
	return bestStart, bestDuration, bestEnable
	
	
end

-- 從 SPELLINFO_SCD 取得手動覆寫設定
local function ApplySavedCooldownOverride(spellId, start, duration)
	local t0 = debugprofilestop()
	--
	
    local saved = SPELLINFO_SCD[spellId]
    if saved then
        if saved.start and saved.start > 0 then
            start = saved.start
        end
        if saved.duration and saved.duration > 0 then
            duration = saved.duration
        end
    end
	
	G:EAFun_testLabel("ApplySavedCooldownOverride", t0, debugprofilestop())
	
    return start, duration
end

-- 判斷是否有充能，並返回相關資料
local function GetChargeInfo(spellId)
    local info = GetSpellCharges(spellId)
    if type(info) == "table" then
        return info.currentCharges, info.maxCharges, info.cooldownStartTime, info.cooldownDuration
    else
        return GetSpellCharges(spellId)
    end
end

----------------------------------------------------------------------
-- 圖示管理函式
----------------------------------------------------------------------

-- 更新/建立冷卻圖示
local function UpdateScdFrame(eaf, spellId, timeLeft, chargeCur, chargeMax, chargeStart, chargeDur, redSecText)
    if not eaf or not spellId then return end
	
	local t0 = debugprofilestop()
	--

    -- 圖示（差異化更新）
    local icon = GetSpellTexture(spellId)
    if icon and icon ~= eaf._lastIcon then
        eaf.texture = eaf.texture or eaf:CreateTexture()
        eaf.texture:SetAllPoints(eaf)
        eaf.texture:SetTexture(icon)
        eaf._lastIcon = icon
    end

    -- 尺寸（差異化更新）
    local size = EA_Config.IconSize or 40
    local w, h = eaf:GetSize()
    if w ~= size or h ~= size then
        eaf:SetSize(size, size)
    end

    -- 冷卻環（Lazy 建立一次）
    if EA_Position.SCD_UseCooldown then
        if not eaf.cooldown then
            eaf.cooldown = CreateFrame("Cooldown", nil, eaf, "CooldownFrameTemplate")
            eaf.cooldown:SetAllPoints(eaf)
        end
        eaf.cooldown:SetSwipeColor(1, 1, 1, 0.5)
        eaf.cooldown:SetHideCountdownNumbers(true)
        eaf.cooldown:SetDrawSwipe(true)
    end

    -- 充能類型：顯示充能倒數與堆疊數
    if chargeCur and chargeMax then
        if EA_Position.SCD_UseCooldown and chargeStart and chargeDur and chargeDur > 0 then
            eaf.cooldown:SetCooldown(chargeStart, chargeDur)
        end
        G:EAFun_SetCountdownStackText(eaf, timeLeft or 0, chargeCur or 0, redSecText)

    elseif timeLeft and timeLeft > 0 then
        -- 一般冷卻：顯示倒數環
        if EA_Position.SCD_UseCooldown then
            eaf.cooldown:SetCooldown(GetTime(), timeLeft)
        end
        G:EAFun_SetCountdownStackText(eaf, timeLeft, 0, redSecText)

    else
        -- 無冷卻：清空倒數文字
        if eaf.spellTimer and eaf.spellTimer:GetText() ~= "" then
            eaf.spellTimer:SetText("")
        end
    end

    -- ===== 法術名稱顯示（差異化更新） =====
    if EA_Config.ShowName then
        -- 取名：優先用 SPELLINFO_SCD，退回 GetSpellInfo
        local name = (G.SPELLINFO_SCD[spellId] and G.SPELLINFO_SCD[spellId].name) or (GetSpellInfo(spellId) or "")
        if type(name) == "table" then name = name.name or "" end

        -- 應有一個 eaf.spellName（若沒有就建立一次）
        if not eaf.spellName then
            eaf.spellName = eaf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            -- 位置你可以依需求調整：圖示下方置中
            eaf.spellName:SetPoint("TOP", eaf, "BOTTOM", 0, -2)
        end

        -- 只在文字變化時更新（避免每幀 SetText）
        if eaf._lastName ~= name then
            eaf.spellName:SetText(name)
            eaf._lastName = name
        end

        -- 字級只在不同時調整（避免每幀 SetFont）
        local fName, fSize = eaf.spellName:GetFont()
        local targetSize = EA_Config.SNameFontSize or fSize or 12
        if fSize ~= targetSize then
            eaf.spellName:SetFont(fName, targetSize)
        end
    else
        -- 不顯示名稱時，避免每幀寫空字串
        if eaf.spellName and eaf._lastName ~= "" then
            eaf.spellName:SetText("")
            eaf._lastName = ""
        end
    end
	--
	G:EAFun_testLabel("UpdateScdFrame", t0, debugprofilestop())
end


-- 刪除冷卻圖示
local function RemoveScdFrame(spellId)
	
    local idx
    for i, v in ipairs(G.EA_ScdCurrentBuffs) do
        if v == spellId then
            idx = i
            break
        end
    end
    if idx then
        table.remove(G.EA_ScdCurrentBuffs, idx)
        local frame = _G["EAScdFrame_"..spellId]
        if frame then
			frame:Hide()
			
        end
    end
end

----------------------------------------------------------------------
-- 主更新函式（替代舊版 OnSCDUpdate）
----------------------------------------------------------------------
G.SCD_Updating = false
function G:OnSCDUpdate(spellId)

	local t0 = debugprofilestop()
	--
	
	if G.SCD_Updating == true then  return end
    G.SCD_Updating = true

    local sid = tonumber(spellId)	
	
    if not sid then G.SCD_Updating = false return end   	
	
	local eaf = _G["EAScdFrame_"..sid]	
    if not eaf then G.SCD_Updating = false return end
	
	local gStart, gDur, gEnds = G:_GetGCDWindow()
	local isGCD = G:IsOnlyOnGCD(sid, gStart, gDur)	
	
    -- 檢查是否啟用此技能的冷卻提示
	local ScdItems = EA_ScdItems          -- 各職業冷卻表	
    local scdList = ScdItems[G.playerClass]
	
    if not scdList or not G:EAFun_GetSpellItemEnable(scdList[sid]) then		
        G.SCD_Updating = false
        return
    end

    -- 取得基礎冷卻
    local start, duration, enable = GetNormalizedCooldown(sid)

    
	if EA_Config.SCD_ItemCooldown then   		
		-- local s2, d2, e2 = GetItemCooldownForSpell(sid)
		local itemID = G.EA_SPELL_ITEM[sid]
		if itemID then 		
			local s2, d2, e2 = GetItemCooldown(itemID)		
			if s2 then 			
				start, duration, enable = s2, d2, e2
			end
		end
	end

    -- 手動覆蓋
	 
    -- start, duration = ApplySavedCooldownOverride(sid, start, duration)

    -- 取得充能資訊
    local chargeCur, chargeMax, chargeStart, chargeDur = GetChargeInfo(sid)

    -- 計算剩餘時間
    local now = GetTime()
    local timeLeft = 0
    if chargeCur and chargeMax then
        timeLeft = (chargeStart + chargeDur) - now
    elseif duration and duration > 0 then
        timeLeft = (start + duration) - now
    else
        timeLeft = 0  -- 無固定冷卻，視為觸發型提示
    end

    -- 更新框架內容
    local redSecText = G:EAFun_GetSpellConditionRedSecText(scdList[sid])
    UpdateScdFrame(eaf, sid, timeLeft, chargeCur, chargeMax, chargeStart, chargeDur, redSecText)

    -- 高亮可用狀態
    
    -- local usable =  C_Spell.IsSpellUsable(sid) 
	if not C_Secrets.ShouldSpellCooldownBeSecret(sid) then 
		local usable =  C_Spell.IsSpellUsable(sid) and (C_Spell.GetSpellCooldown(sid).startTime == 0)
		G:FrameGlowShowOrHide(eaf, usable and EA_Config.SCD_GlowWhenUsable)
	end
    

	if timeLeft <= 0 then
		if EA_Config.SCD_RemoveWhenCooldown then
			RemoveScdFrame(sid)
			G.SCD_Updating = false
			return
		end
	end
    -- 排程下一次更新
	
    if chargeCur and chargeMax then
        -- 充能技能：在充能結束前加速更新
        local nextInterval = (timeLeft > 0.1 and timeLeft < 1) and (G.UpdateInterval / 11) or G.UpdateInterval
        -- Lib_ZYF:FrameSetOnUpdateOnce(eaf, nextInterval, G.OnSCDUpdate, sid)
		C_Timer.After(nextInterval, G.OnSCDUpdate, G, sid)
		-- C_Timer.After(nextInterval, function() G:OnSCDUpdate(sid) end )
    elseif duration and duration > 0 then
        -- 有固定冷卻：同樣根據剩餘時間調整        
		local nextInterval = (timeLeft > 0.1 and timeLeft < 1) and (G.UpdateInterval / 11) or G.UpdateInterval
        -- Lib_ZYF:FrameSetOnUpdateOnce(eaf, nextInterval, G.OnSCDUpdate, sid)
		C_Timer.After(nextInterval, G.OnSCDUpdate, G, sid)
		-- C_Timer.After(nextInterval, function() G:OnSCDUpdate(sid) end )
    end

    G.SCD_Updating = false
	--
	G:EAFun_testLabel("OnSCDUpdate", t0, debugprofilestop())
	
end

----------------------------------------------------------------------
-- 新增冷卻事件：當玩家施放或獲取法術時呼叫
----------------------------------------------------------------------
function G:ScdBuffs_Update(unitName, spellName, spellIdRaw, timestamp)
	local t0 = debugprofilestop()
	--
	
    -- 只處理玩家或寵物
    if unitName ~= G.CachedPlayerName and unitName ~= G.CachedPetName then return end

    local sid = tonumber(spellIdRaw)
    if not sid or sid <= 0 then return end
	local ScdItems = EA_ScdItems
    local scdList = ScdItems[G.playerClass]
	
    if not scdList or not G:EAFun_GetSpellItemEnable(scdList[sid]) then return end

    -- 若此技能不在列表中，加入並立即顯示
    local exists = false
    for _, v in ipairs(G.EA_ScdCurrentBuffs) do
        if v == sid then exists = true break end
    end
    if not exists then
        table.insert(G.EA_ScdCurrentBuffs, sid)
        -- 建立或取得對應框架
        local frameName = "EAScdFrame_"..sid
        local eaf = _G[frameName]
        if not eaf then
            eaf = CreateFrame("Frame", frameName, UIParent)
			
            eaf.spellTimer = eaf:CreateFontString(nil, "OVERLAY")
            eaf.spellTimer:SetPoint("BOTTOM", eaf, "TOP", 0, 2)
            eaf.spellTimer:SetFont(GameFontNormal:GetFont(), EA_Config.TimerFontSize, "OUTLINE")
			
            eaf.spellName  = eaf:CreateFontString(nil, "OVERLAY")
            eaf.spellName:SetPoint("TOP", eaf, "BOTTOM", 0, -2)
            eaf.spellName:SetFont(GameFontNormal:GetFont(), EA_Config.SNameFontSize, "OUTLINE")
			
            eaf.cooldown = eaf.cooldown or CreateFrame("Cooldown", nil, eaf, "CooldownFrameTemplate")
            eaf.cooldown:SetAllPoints(eaf)
        end
        eaf:Show()
    end

    -- 立即更新並排程後續
    G:OnSCDUpdate(sid)
	--
	G:EAFun_testLabel("ScdBuffs_Update", t0, debugprofilestop())
end

function G:PositionFrames_ScdClassic(list, prefix, anchor, baseX, baseY, xStep, yStep, maxPerRow)
    prefix    = prefix or "EAScdFrame_"
    anchor    = anchor or (EA_Position and EA_Position.ScdAnchor)    or "CENTER"
    baseX     = baseX  or (EA_Position and EA_Position.Scd_xOffset)  or 0
    baseY     = baseY  or (EA_Position and EA_Position.Scd_yOffset)  or 0
    xStep     = xStep  or (100 + (EA_Position and EA_Position.xOffset or 0))
    yStep     = yStep  or (0   + (EA_Position and EA_Position.yOffset or 0))
    maxPerRow = maxPerRow or (EA_Config and EA_Config.NewLineByIconCount) or 0

    local point, relPoint = "CENTER", "CENTER"

    if maxPerRow <= 0 then
        -- 單列：延續原本「相對上一顆」的佈局
        local prevFrame = "EA_Main_Frame"
        for i = 1, #list do
            local eaf = _G[prefix .. list[i]]
            if eaf then
                if i == 1 then
                    G:SetPointIfDiff(eaf, point, UIParent, anchor, baseX, baseY)
                else
                    G:SetPointIfDiff(eaf, point, prevFrame, relPoint, xStep, yStep)
                end
                prevFrame = eaf
            end
        end
        return
    end

    -- 格狀：用 (row, col) 算絕對座標（不靠 prevFrame，避免重疊）
    -- 列距離：若 yStep==0 就用 -abs(xStep) 當成往下排的預設位移（維持舊行為的感覺）
    local rowStep = (yStep ~= 0) and yStep or -math.abs(xStep)

    for i = 1, #list do
        local eaf = _G[prefix .. list[i]]
        if eaf then
            local idx = i - 1
            local row = math.floor(idx / maxPerRow)
            local col = idx % maxPerRow
            local x   = baseX + col * xStep
            local y   = baseY + row * rowStep
            G:SetPointIfDiff(eaf, point, UIParent, anchor, x, y)
        end
    end
end


----------------------------------------------------------------------
-- 依旗標自動選用 PiePipe 或 Classic
----------------------------------------------------------------------
function G:PositionFrames_ScdAuto(list, prefix)
    if EA_Config and EA_Config.SCD_PipeRange then
        -- 走既有 PiePipe
        return G:PositionFrames_PiePipe(
            list,
            prefix or "EAScdFrame_",
            EA_Position and EA_Position.ScdAnchor or "CENTER",
            EA_Position and EA_Position.Scd_xOffset or 0,
            EA_Position and EA_Position.Scd_yOffset or 0
        )
    else
        -- 走傳統格狀
        return G:PositionFrames_ScdClassic(
            list,
            prefix or "EAScdFrame_",
            EA_Position and EA_Position.ScdAnchor or "CENTER",
            EA_Position and EA_Position.Scd_xOffset or 0,
            EA_Position and EA_Position.Scd_yOffset or 0,
            (100 + (EA_Position and EA_Position.xOffset or 0)),
            (0   + (EA_Position and EA_Position.yOffset or 0)),
            EA_Config and EA_Config.NewLineByIconCount or 0
        )
    end
end


function G:ScdPositionFrames()
    -- 改用通用索引入口；若你想完全交由共用入口處理，直接 early return
    return G:EA_PositionFramesByIndex(3)
end

----------------------------------------------------------------------
-- 排序並佈局冷卻圖示（重寫版）
----------------------------------------------------------------------
-- function G:ScdPositionFrames()
    -- local t0 = debugprofilestop()

    -- -- 快速路徑：全部隱藏
    -- if G.EA_flagAllHidden then
        -- EA_Main_Frame:SetAlpha(0)
        -- return
    -- end
    -- EA_Main_Frame:SetAlpha(1)

    -- -- 離開戰鬥是否仍顯示
    -- if not InCombatLockdown() and not EA_Config.SCD_NocombatStillKeep then
        -- G:HideAllScdCurrentBuff()
        -- return
    -- end

    -- -- 在地化常用全域，降低查表次數
    -- local sort    = table.sort
    -- local pairs   = pairs
    -- local ipairs  = ipairs
    -- local SPELLINFO_SCD = G.SPELLINFO_SCD or SPELLINFO_SCD  -- 兼容舊字段
    -- local ScdItems = EA_ScdItems

    -- -- 同步權重/紅字文字設定（只寫有給值的）
    -- local classTbl = ScdItems and G.playerClass and ScdItems[G.playerClass]
    -- if classTbl then
        -- for spellId, cfg in pairs(classTbl) do
            -- local info = SPELLINFO_SCD and SPELLINFO_SCD[spellId]
            -- if info and cfg then
                -- local ow = cfg.orderwtd
                -- if ow ~= nil then info.orderwtd = ow end
                -- local rst = cfg.redsectext
                -- if rst ~= nil then info.redsectext = rst end
            -- end
        -- end
    -- end

    -- -- 排序：權重大者優先；相同則以 spellId 遞增
    -- sort(G.EA_ScdCurrentBuffs, function(a, b)
        -- local ia = SPELLINFO_SCD and SPELLINFO_SCD[a]
        -- local ib = SPELLINFO_SCD and SPELLINFO_SCD[b]
        -- local wa = (ia and ia.orderwtd) or 1
        -- local wb = (ib and ib.orderwtd) or 1
        -- if wa == wb then
            -- return a < b
        -- else
            -- return wa > wb
        -- end
    -- end)

    -- -- 佈局：依旗標自動切換
    -- G:PositionFrames_ScdAuto(G.EA_ScdCurrentBuffs, "EAScdFrame_")

    -- -- 後處理：更新字樣 / Tooltip（避免多餘操作）
    -- local showName = (EA_Config.ShowName == true)
    -- local desiredFontSize = EA_Config.SNameFontSize
    -- for i = 1, #G.EA_ScdCurrentBuffs do
        -- local spellId = G.EA_ScdCurrentBuffs[i]
        -- local eaf = _G["EAScdFrame_" .. spellId]
        -- if eaf then
            -- if showName then
                -- local gsiName = SPELLINFO_SCD and SPELLINFO_SCD[spellId] and SPELLINFO_SCD[spellId].name
                -- if type(gsiName) == "table" then
                    -- gsiName = gsiName.name
                -- end
                -- -- 以 frame 快取避免重複 SetText / GetFont / SetFont
                -- if eaf._lastSpellName ~= gsiName then
                    -- eaf.spellName:SetText(gsiName or "")
                    -- eaf._lastSpellName = gsiName
                -- end
                -- if eaf._lastFontSize ~= desiredFontSize then
                    -- local sFont, _ = eaf.spellName:GetFont()
                    -- eaf.spellName:SetFont(sFont, desiredFontSize)
                    -- eaf._lastFontSize = desiredFontSize
                -- end
            -- else
                -- if eaf._lastSpellName ~= "" then
                    -- eaf.spellName:SetText("")
                    -- eaf._lastSpellName = ""
                -- end
            -- end

            -- G:FrameAppendSpellTip(eaf, spellId)
            -- -- 若之後要開回即時更新：G:OnSCDUpdate(spellId)
        -- end
    -- end

    -- -- 記錄效能
    -- G:EAFun_testLabel("ScdPositionFrames", t0, debugprofilestop())
-- end

		   -- 可調參數：時間容差（秒），避免浮點與幀率誤差
G.GCD_EPS = G.GCD_EPS or 0.06

-- 讀取目前 GCD 視窗（spellID 61304）
function G:_GetGCDWindow()
    local s, d = GetSpellCooldown(61304)
    if d and d > 0 then
        return s, d, s + d   -- start, duration, endsAt
    end
    return nil, 0, 0
end

-- 判斷某 spellID 此刻是否「只有在吃 GCD」（不是技能自身 CD/充能）
function G:IsOnlyOnGCD(spellID, gStart, gDur)
    if not gStart or not gDur or gDur == 0 then return false end

    local sStart, sDur = GetSpellCooldown(spellID)
    if not sStart or sDur == 0 then return false end

    -- 充能類：正在回充就不是純 GCD
    local charges, maxCharges, cStart, cDur = GetSpellCharges(spellID)
    if maxCharges and maxCharges > 0 then
        if charges == 0 and cDur and cDur > 0 then
            return false
        end
    end

    -- 明顯有自身基礎冷卻就不是純 GCD
    local baseMS = GetSpellBaseCooldown(spellID) or 0
    if baseMS > 0 then
        local baseSec = baseMS / 1000
        -- 若技能基礎 CD 顯著大於 GCD，排除（1.6 是人性化門檻，可依職業調整 1.2~1.6）
        if baseSec > (gDur + 0.1) then
            return false
        end
    end

    -- 精準比對（起點＆時長都約等於 GCD）
    local eps = G.GCD_EPS
    local sameStart = math.abs(sStart - gStart) <= eps
    local sameDur   = math.abs(sDur   - gDur)   <= eps
    return sameStart and sameDur
end
