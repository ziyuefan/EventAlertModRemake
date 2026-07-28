--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/Renderer
檔案: UI\Renderer.lua

理念:
- Renderer 只把 normalized render state 寫入 UI，資料來源完全在 services。
- 支援多個完全隔離的 Alert Frame（告警框架），每個框架有各自的坐標與成長方向。
- 使用「靜態連續數字索引陣列（LAYOUT_OFFSETS）」配合 table.freeze，消除 Layout 邏輯中的字串 Hash 查找與條件分支開銷，以極致算術乘法取代多重 If-Else 判斷。
- 戰鬥中延後結構性 layout 變更，所有 UI 框架的操作皆有 InCombatLockdown() 守衛。

責任:
- 管理 7 大獨立告警框架的建立、顯示、隱藏與滑鼠拖曳定位保存。
- 接收並將 AlertState 渲染到特定的 UI 框架中，使用 Icon 緩衝池 (IconPool)。
- 當設定變更或圖示增減時，動態對特定框架進行排版更新 (Layout)。

資料所有權:
- 擁有這 7 個 Alert Frame 的 frame 物件生命週期與狀態對照表。
- 擁有各框架內的 icon visibility 與排列順序。

可變狀態:
- 只 mutate UI frames 與 renderer-local cache。
- 不得 mutate SavedVariables 中的其他無關設定。

邊界:
- 不得查 C_UnitAuras/C_Spell/C_Item。
- 不得推導 facts 或補猜 timer。
- 不執行 secure action，不 hook Blizzard protected frame。

效能注意:
- 所有 UI writes 需比較前值；layout 批次更新。
- timer text 只在安全 numeric 或 native DurationObject path 更新。

Retail API 注意:
- 支援 12.0.7 native Cooldown frame 與 DurationTextBinding。

]]
local _, EAM = ...

local api = EAM.API
local Util = EAM.Util
local IconPool = EAM.UI.IconPool

local Renderer = {
    frames = {},
    deferred = {},
    deferredCount = 0,
    iconSize = 40,
    spacing = 6,
    isMoving = false,
}

EAM.UI.Renderer = Renderer

-- 統一降級計時器 OnUpdate 系統，避免 timer-per-icon 開銷且提供 3 秒以下小數點倒數
local legacyTimerFrame = nil
local activeLegacyTimers = {}

local timerTokenPool = {
    recycleBin = {},
    binSize = 0,
}

local function acquireToken()
    if timerTokenPool.binSize > 0 then
        local token = timerTokenPool.recycleBin[timerTokenPool.binSize]
        timerTokenPool.recycleBin[timerTokenPool.binSize] = nil
        timerTokenPool.binSize = timerTokenPool.binSize - 1
        return token
    else
        return {}
    end
end

local function releaseToken(token)
    if not token then return end
    token.icon = nil
    token.expTime = nil
    token.active = nil
    token.frameName = nil
    token.alertID = nil
    timerTokenPool.binSize = timerTokenPool.binSize + 1
    timerTokenPool.recycleBin[timerTokenPool.binSize] = token
end

local function onDurationTimerExpired(token)
    if not token or not token.active then
        releaseToken(token)
        return
    end

    local icon = token.icon
    if icon and icon.rendered and icon.rendered.activeToken == token then
        icon.rendered.activeToken = nil
        token.active = false
        Renderer.render({ id = token.alertID, shown = false }, token.frameName)
    end

    releaseToken(token)
end

local function onLegacyTimerUpdate()
    local now = api.GetTime and api.GetTime() or 0
    if not Util.isSafeNumber(now) then
        return
    end
    local hasTimer = false
    
    for icon, expirationTime in pairs(activeLegacyTimers) do
        local timeLeft = Util.isSafeNumber(expirationTime) and expirationTime - now or 0
        if timeLeft > 0 then
            hasTimer = true
            local text
            if timeLeft < 3.05 then
                -- 3 秒以下顯示一位小數，如 2.4, 0.8
                text = string.format("%.1f", timeLeft)
            else
                -- 3 秒以上四捨五入整數
                text = string.format("%d", math.ceil(timeLeft))
            end
            
            if icon.timerText and icon.timerText.SetText then
                icon.timerText:SetText(text)
            end
        else
            activeLegacyTimers[icon] = nil
            if icon.timerText then
                if icon.timerText.ClearText then
                    icon.timerText:ClearText()
                else
                    icon.timerText:SetText("")
                end
            end
        end
    end
    
    if not hasTimer and legacyTimerFrame then
        legacyTimerFrame:SetScript("OnUpdate", nil)
    end
end

function Renderer.registerLegacyTimer(icon, expirationTime)
    if not icon or not Util.isSafeNumber(expirationTime) then return end
    activeLegacyTimers[icon] = expirationTime
    
    if not legacyTimerFrame then
        legacyTimerFrame = api.CreateFrame("Frame")
    end
    legacyTimerFrame:SetScript("OnUpdate", onLegacyTimerUpdate)
end

function Renderer.unregisterLegacyTimer(icon)
    if not icon then return end
    activeLegacyTimers[icon] = nil
end

local isBatching = false
local batchDirtyFrames = {}

function Renderer.BeginBatch()
    isBatching = true
    wipe(batchDirtyFrames)
end

function Renderer.EndBatch()
    isBatching = false
    for frameName, dirty in pairs(batchDirtyFrames) do
        if dirty then
            Renderer.requestLayout(frameName)
        end
    end
    wipe(batchDirtyFrames)
end

-- 初始化 7 大告警框架的私有資料表
local function initFrameState(frameName)
    if not frameName then
        return nil
    end
    if not Renderer.frames[frameName] then
        Renderer.frames[frameName] = {
            parent = nil,
            icons = {},
            order = {},
            orderCount = 0,
            layoutDirty = false,
            layoutBlocked = false,
        }
    end
    return Renderer.frames[frameName]
end

-- 取得或建立特定 Alert Frame
local function ensureParent(frameName)
    local fState = initFrameState(frameName)
    if fState.parent then
        return fState.parent
    end

    -- 戰鬥中防 taint 守衛，若在戰鬥中，延後框架的實體創建
    if api.InCombatLockdown and api.InCombatLockdown() then
        return nil
    end

    local dbFrames = EAM.db and EAM.db.layout and EAM.db.layout.frames
    local frameConfig = dbFrames and dbFrames[frameName]
    
    local point = "CENTER"
    local x = 0
    local y = 0
    if frameConfig then
        point = frameConfig.point or "CENTER"
        x = frameConfig.x or 0
        y = frameConfig.y or 0
    end

    if EAM.db then
        Renderer.iconSize = (EAM.db.config and EAM.db.config.iconSize) or (EAM.db.layout and EAM.db.layout.iconSize) or 40
        Renderer.spacing = (EAM.db.config and EAM.db.config.iconSpacing) or (EAM.db.layout and EAM.db.layout.spacing) or 6
    end

    -- 建立孤兒 Frame，徹底避免與 UIParent 核心執行鏈相互污染
    local frame = api.CreateFrame("Frame", "EAM_AlertFrame_" .. frameName, UIParent)
    frame:SetSize(Renderer.iconSize, Renderer.iconSize)
    frame:SetPoint(point, UIParent, point, x, y)
    frame.frameName = frameName

    fState.parent = frame
    return frame
end

local function setTextIfChanged(fontString, rendered, key, value)
    value = value or ""
    if rendered[key] ~= value then
        if value == "" and fontString.ClearText then
            fontString:ClearText()
        else
            fontString:SetText(value)
        end
        rendered[key] = value
    end
end

local function inCombat()
    return api.InCombatLockdown and api.InCombatLockdown()
end

-- 核心 Layout 排版演算法 (極致靜態陣列優化版)
local function layout(frameName)
    local fState = initFrameState(frameName)
    local parent = ensureParent(frameName)
    if not parent then
        fState.layoutBlocked = true
        return
    end

    local size = EAM.db and EAM.db.config and EAM.db.config.iconSize or (EAM.db and EAM.db.layout and EAM.db.layout.iconSize) or Renderer.iconSize
    local spacing = EAM.db and EAM.db.config and EAM.db.config.iconSpacing or (EAM.db and EAM.db.layout and EAM.db.layout.spacing) or Renderer.spacing
    local count = fState.orderCount

    -- 讀取目前框架設定的成長方向 (1=RIGHT, 2=LEFT, 3=UP, 4=DOWN)
    local dbFrames = EAM.db and EAM.db.layout and EAM.db.layout.frames
    local frameConfig = dbFrames and dbFrames[frameName]
    local dirIdx = frameConfig and frameConfig.growDirection or 1
    if dirIdx < 1 or dirIdx > 4 then dirIdx = 1 end

    -- 提取凍結好的連續數字索引方向偏量陣列 (Array Part)
    local offset = EAM.Constants.LAYOUT_OFFSETS[dirIdx]
    local dx, dy = offset[1], offset[2]

    parent:Hide()
    local layoutIndex = 0
    for index = 1, count do
        local id = fState.order[index]
        local icon = fState.icons[id]
        if icon and not icon.isParasite then
            layoutIndex = layoutIndex + 1
            local rendered = icon.rendered
            -- 計算此圖示相對於中央點的位移距離
            local dist = (layoutIndex - 1) * (size + spacing)
            local offsetX = dx * dist
            local offsetY = dy * dist

            if rendered.layoutX ~= offsetX or rendered.layoutY ~= offsetY or rendered.layoutSize ~= size then
                icon:ClearAllPoints()
                icon:SetPoint("CENTER", parent, "CENTER", offsetX, offsetY)
                icon:SetSize(size, size)
                rendered.layoutX = offsetX
                rendered.layoutY = offsetY
                rendered.layoutSize = size
            end
        end
    end

    -- 根據成長方向與圖示數量重調父框架大小
    if layoutIndex > 0 then
        local totalSpan = (layoutIndex * size) + ((layoutIndex - 1) * spacing)
        if dx ~= 0 then
            parent:SetSize(totalSpan, size)
        else
            parent:SetSize(size, totalSpan)
        end
        parent:Show()
    else
        parent:SetSize(size, size)
        parent:Hide()
    end

    fState.layoutDirty = false
    fState.layoutBlocked = false
end

-- 請求重新排版
function Renderer.requestLayout(frameName)
    if not frameName then
        for fName in pairs(Renderer.frames) do
            Renderer.requestLayout(fName)
        end
        return
    end

    local fState = initFrameState(frameName)
    if fState then
        fState.layoutDirty = true
        layout(frameName)
    end
end

-- 延遲戰鬥中渲染
local function deferRender(alertState, frameName)
    if not alertState or not alertState.id then
        return
    end

    if not Renderer.deferred[alertState.id] then
        Renderer.deferredCount = Renderer.deferredCount + 1
    end
    Renderer.deferred[alertState.id] = { alertState = alertState, frameName = frameName }
end

function Renderer.initialize()
    -- 在初始化時嘗試為所有預設框架預熱，若在戰鬥中則會自動在 onCombatEnd 執行
    for fName in pairs(EAM.Constants.ALERT_FRAME_TYPES) do
        ensureParent(fName)
        initFrameState(fName)
    end

    if IconPool.prewarm then
        IconPool.prewarm()
    end

    local router = EAM.Modules.EventRouter
    if router then
        router.register("PLAYER_REGEN_ENABLED", Renderer.onCombatEnd)
    end
end

-- 主要渲染入口
function Renderer.render(alertState, frameName)
    -- 降級守衛：如果沒有指定框架，則預設歸入自身光環
    frameName = frameName or EAM.Constants.ALERT_FRAME_TYPES.selfAura

    if EAM.addDebugLog then
        EAM.addDebugLog("Renderer", "render", "Rendering id=" .. tostring(alertState and alertState.id) .. ", frame=" .. frameName .. ", active=" .. tostring(alertState and alertState.active) .. ", shown=" .. tostring(alertState and alertState.shown))
    end

    if not alertState or not alertState.id then
        return
    end

    -- 戰鬥中防 Taint 鎖定：若在戰鬥中且該框架的 parent 尚未建立，延後渲染
    local fState = initFrameState(frameName)
    local parent = fState.parent
    if not parent and inCombat() then
        deferRender(alertState, frameName)
        return
    end

    -- 確保 parent frame 存在
    parent = ensureParent(frameName)
    if not parent then
        deferRender(alertState, frameName)
        return
    end

    local icon = fState.icons[alertState.id]

    -- 圖示隱藏/釋放處理
    if not alertState.shown then
        if icon then
            if icon.rendered and icon.rendered.activeToken then
                icon.rendered.activeToken.active = false
                icon.rendered.activeToken = nil
            end
            fState.icons[alertState.id] = nil
            for index = 1, fState.orderCount do
                if fState.order[index] == alertState.id then
                    fState.order[index] = fState.order[fState.orderCount]
                    fState.order[fState.orderCount] = nil
                    fState.orderCount = fState.orderCount - 1
                    break
                end
            end
            if icon.isParasite then
                icon:SetParent(UIParent)
                icon.isParasite = nil
            end
            IconPool.release(icon)
            Renderer.requestLayout(frameName)
        end
        return
    end

    -- 圖示獲取與初始化
    if not icon then
        icon = IconPool.acquire()
        if not icon then
            return
        end
        fState.icons[alertState.id] = icon
        fState.orderCount = fState.orderCount + 1
        fState.order[fState.orderCount] = alertState.id
        fState.layoutDirty = true
        icon.isParasite = nil
    end

    local hostIcon = nil
    local shouldBeParasite = (hostIcon ~= nil)
    
    if icon.isParasite ~= shouldBeParasite then
        icon.isParasite = shouldBeParasite
        if shouldBeParasite then
            icon:SetParent(hostIcon)
            icon:ClearAllPoints()
            icon:SetAllPoints(hostIcon)
            -- 🛡️ 提權 Frame Level 確保 EAM 圖示及其文字不被暴雪原生元件遮擋
            pcall(function()
                icon:SetFrameStrata("MEDIUM")
                icon:SetFrameLevel(hostIcon:GetFrameLevel() + 10)
            end)
        else
            icon:SetParent(parent)
            icon:ClearAllPoints()
            -- 恢復預設層級
            pcall(function()
                icon:SetFrameStrata("MEDIUM")
                icon:SetFrameLevel(parent:GetFrameLevel() + 1)
            end)
        end
        fState.layoutDirty = true
    end

    local rendered = icon.rendered
    if alertState.icon and rendered.icon ~= alertState.icon then
        icon.texture:SetTexture(alertState.icon)
        rendered.icon = alertState.icon
    end

    local refFrame = icon.overlay or icon

    -- 根據 timerInside 與 timerPosition 對齊秒數倒數文字位置 (使用快取避免 redundant SetPoint)
    local timerInside = EAM.db and EAM.db.config and EAM.db.config.timerInside
    local timerPos = EAM.db and EAM.db.config and EAM.db.config.timerPosition or "TOP"
    
    if rendered.timerInside ~= timerInside or rendered.timerPos ~= timerPos then
        icon.timerText:ClearAllPoints()
        if timerInside then
            if timerPos == "CENTER" then
                icon.timerText:SetPoint("CENTER", refFrame, "CENTER", 0, 0)
            elseif timerPos == "TOP" then
                icon.timerText:SetPoint("TOP", refFrame, "TOP", 0, -2)
            elseif timerPos == "BOTTOM" then
                icon.timerText:SetPoint("BOTTOM", refFrame, "BOTTOM", 0, 2)
            elseif timerPos == "LEFT" then
                icon.timerText:SetPoint("LEFT", refFrame, "LEFT", 2, 0)
            elseif timerPos == "RIGHT" then
                icon.timerText:SetPoint("RIGHT", refFrame, "RIGHT", -2, 0)
            elseif timerPos == "TOPLEFT" then
                icon.timerText:SetPoint("TOPLEFT", refFrame, "TOPLEFT", 2, -2)
            elseif timerPos == "TOPRIGHT" then
                icon.timerText:SetPoint("TOPRIGHT", refFrame, "TOPRIGHT", -2, -2)
            elseif timerPos == "BOTTOMLEFT" then
                icon.timerText:SetPoint("BOTTOMLEFT", refFrame, "BOTTOMLEFT", 2, 2)
            elseif timerPos == "BOTTOMRIGHT" then
                icon.timerText:SetPoint("BOTTOMRIGHT", refFrame, "BOTTOMRIGHT", -2, 2)
            else
                icon.timerText:SetPoint("CENTER", refFrame, "CENTER", 0, 0)
            end
        else
            if timerPos == "TOP" then
                icon.timerText:SetPoint("BOTTOM", refFrame, "TOP", 0, 2)
            elseif timerPos == "BOTTOM" then
                icon.timerText:SetPoint("TOP", refFrame, "BOTTOM", 0, -2)
            elseif timerPos == "LEFT" then
                icon.timerText:SetPoint("RIGHT", refFrame, "LEFT", -4, 0)
            elseif timerPos == "RIGHT" then
                icon.timerText:SetPoint("LEFT", refFrame, "RIGHT", 4, 0)
            elseif timerPos == "TOPLEFT" then
                icon.timerText:SetPoint("BOTTOMRIGHT", refFrame, "TOPLEFT", -2, 2)
            elseif timerPos == "TOPRIGHT" then
                icon.timerText:SetPoint("BOTTOMLEFT", refFrame, "TOPRIGHT", 2, 2)
            elseif timerPos == "BOTTOMLEFT" then
                icon.timerText:SetPoint("TOPRIGHT", refFrame, "BOTTOMLEFT", -2, -2)
            elseif timerPos == "BOTTOMRIGHT" then
                icon.timerText:SetPoint("TOPLEFT", refFrame, "BOTTOMRIGHT", 2, -2)
            else
                icon.timerText:SetPoint("BOTTOM", refFrame, "TOP", 0, 2)
            end
        end
        rendered.timerInside = timerInside
        rendered.timerPos = timerPos
    end

    -- 根據 stackInside 與 stackPosition 對齊堆疊數文字位置
    local stackInside = true
    if EAM.db and EAM.db.config and EAM.db.config.stackInside ~= nil then
        stackInside = EAM.db.config.stackInside
    end
    local stackPos = EAM.db and EAM.db.config and EAM.db.config.stackPosition or "BOTTOMRIGHT"
    
    if rendered.stackInside ~= stackInside or rendered.stackPos ~= stackPos then
        icon.stackText:ClearAllPoints()
        if stackInside then
            if stackPos == "BOTTOMRIGHT" then
                icon.stackText:SetPoint("BOTTOMRIGHT", refFrame, "BOTTOMRIGHT", -1, 1)
            elseif stackPos == "BOTTOMLEFT" then
                icon.stackText:SetPoint("BOTTOMLEFT", refFrame, "BOTTOMLEFT", 1, 1)
            elseif stackPos == "TOPRIGHT" then
                icon.stackText:SetPoint("TOPRIGHT", refFrame, "TOPRIGHT", -1, -1)
            elseif stackPos == "TOPLEFT" then
                icon.stackText:SetPoint("TOPLEFT", refFrame, "TOPLEFT", 1, -1)
            elseif stackPos == "CENTER" then
                icon.stackText:SetPoint("CENTER", refFrame, "CENTER", 0, 0)
            else
                icon.stackText:SetPoint("BOTTOMRIGHT", refFrame, "BOTTOMRIGHT", -1, 1)
            end
        else
            if stackPos == "TOP" then
                icon.stackText:SetPoint("BOTTOM", refFrame, "TOP", 0, 2)
            elseif stackPos == "BOTTOM" then
                icon.stackText:SetPoint("TOP", refFrame, "BOTTOM", 0, -2)
            elseif stackPos == "LEFT" then
                icon.stackText:SetPoint("RIGHT", refFrame, "LEFT", -4, 0)
            elseif stackPos == "RIGHT" then
                icon.stackText:SetPoint("LEFT", refFrame, "RIGHT", 4, 0)
            else
                icon.stackText:SetPoint("BOTTOMRIGHT", refFrame, "BOTTOMRIGHT", -1, 1)
            end
        end
        rendered.stackInside = stackInside
        rendered.stackPos = stackPos
    end

    local stacks = alertState.stacks
    if stacks and (Util.isSecretValue(stacks) or not Util.canAccessValue(stacks)) then
        stacks = ""
    else
        stacks = (stacks and stacks > 1) and tostring(stacks) or ""
    end
    setTextIfChanged(icon.stackText, rendered, "stacks", stacks)

    local nameInside = shouldBeParasite
    if rendered.nameInside ~= nameInside then
        icon.nameText:ClearAllPoints()
        if nameInside then
            -- 寄生模式下，為了防止 ClipsChildren 裁切，將技能名稱移至圖示內側底端並設為 Highlight 顯色
            icon.nameText:SetPoint("BOTTOM", refFrame, "BOTTOM", 0, 2)
            icon.nameText:SetFontObject("GameFontHighlightSmall")
        else
            -- 一般模式下，字放在圖示下方，恢復預設 Normal 顏色
            icon.nameText:SetPoint("TOP", refFrame, "BOTTOM", 0, -2)
            icon.nameText:SetFontObject("GameFontNormalSmall")
        end
        rendered.nameInside = nameInside
    end

    local name = alertState.name or ""
    setTextIfChanged(icon.nameText, rendered, "name", name)

    -- Cooldown 與 DurationObject 倒數雙軌管道渲染
    local timer = alertState.timer
    local useNativeBinding = false
    if timer and timer.durationObject and api.C_DurationUtil and api.C_DurationUtil.CreateDurationTextBinding then
        useNativeBinding = true
    end

    if useNativeBinding then
        if rendered.durationObject ~= timer.durationObject then
            if icon.timerBinding then
                if type(icon.timerBinding.Unbind) == "function" then
                    icon.timerBinding:Unbind()
                end
            end
            icon.timerBinding = api.C_DurationUtil.CreateDurationTextBinding(timer.durationObject, icon.timerText)
            
            if icon.cooldown.SetCooldownFromDurationObject then
                icon.cooldown:SetCooldownFromDurationObject(timer.durationObject)
            elseif timer.startTime and timer.duration then
                icon.cooldown:SetCooldown(timer.startTime, timer.duration)
            else
                icon.cooldown:SetCooldown(0, 0)
            end

            rendered.durationObject = timer.durationObject
            rendered.cooldownStart = nil
            rendered.cooldownDuration = nil
        end
        Renderer.unregisterLegacyTimer(icon)
    elseif timer and Util.isSafeNumber(timer.startTime) and Util.isSafePositiveNumber(timer.duration) then
        if rendered.cooldownStart ~= timer.startTime or rendered.cooldownDuration ~= timer.duration then
            icon.cooldown:SetCooldown(timer.startTime, timer.duration)
            rendered.cooldownStart = timer.startTime
            rendered.cooldownDuration = timer.duration
            rendered.durationObject = nil
        end
        if icon.timerBinding then
            if type(icon.timerBinding.Unbind) == "function" then
                icon.timerBinding:Unbind()
            end
            icon.timerBinding = nil
        end
        
        -- 走降級定時 OnUpdate 字串倒數通道
        if Util.isSafeNumber(timer.expirationTime) then
            Renderer.registerLegacyTimer(icon, timer.expirationTime)
        else
            Renderer.unregisterLegacyTimer(icon)
            if icon.timerText then
                if icon.timerText.ClearText then
                    icon.timerText:ClearText()
                else
                    icon.timerText:SetText("")
                end
            end
        end
    else
        icon.cooldown:SetCooldown(0, 0)
        rendered.cooldownStart = nil
        rendered.cooldownDuration = nil
        rendered.durationObject = nil
        if icon.timerBinding then
            if type(icon.timerBinding.Unbind) == "function" then
                icon.timerBinding:Unbind()
            end
            icon.timerBinding = nil
        end
        Renderer.unregisterLegacyTimer(icon)
        if icon.timerText then
            if icon.timerText.ClearText then
                icon.timerText:ClearText()
            else
                icon.timerText:SetText("")
            end
        end
    end

    -- 🌡️ Pandemic (傳染累加) 與 Action Bar Glow 亮框顯示控制
    local shouldGlow = alertState.pandemicReady or alertState.overlayGlow
    if shouldGlow then
        if icon.glowBorder then
            icon.glowBorder:Show()
        end
    else
        if icon.glowBorder then
            icon.glowBorder:Hide()
        end
    end

    if icon.overlay and icon.cooldown and icon.cooldown.GetFrameLevel then
        local cooldownLevel = icon.cooldown:GetFrameLevel()
        if Util.isSafeNumber(cooldownLevel) then
            icon.overlay:SetFrameLevel(cooldownLevel + 5)
        end
    end

    -- 註冊/更新 Scheduler 延時回收 token
    local duration = timer and timer.duration
    if Util.isSafePositiveNumber(duration) then
        if rendered.activeToken then
            rendered.activeToken.active = false
            rendered.activeToken = nil
        end
        
        local token = acquireToken()
        token.icon = icon
        token.expTime = timer.expirationTime
        token.active = true
        token.frameName = frameName
        token.alertID = alertState.id
        
        rendered.activeToken = token
        
        local Scheduler = EAM.Modules.Scheduler
        if Scheduler and Scheduler.after then
            Scheduler.after(duration, onDurationTimerExpired, token)
        end
    else
        if rendered.activeToken then
            rendered.activeToken.active = false
            rendered.activeToken = nil
        end
    end

    icon:Show()
    if fState.layoutDirty then
        if isBatching then
            batchDirtyFrames[frameName] = true
        else
            Renderer.requestLayout(frameName)
        end
    end
end

-- 離開戰鬥時，將戰鬥中被阻攔的渲染與 Layout 變更安全地釋放執行
function Renderer.onCombatEnd()
    -- 戰鬥結束後，重新嘗試確保所有框架 parent 已成功建立
    for fName in pairs(EAM.Constants.ALERT_FRAME_TYPES) do
        ensureParent(fName)
    end

    if Renderer.deferredCount > 0 then
        for id, item in pairs(Renderer.deferred) do
            Renderer.deferred[id] = nil
            Renderer.deferredCount = Renderer.deferredCount - 1
            Renderer.render(item.alertState, item.frameName)
        end
        Renderer.deferredCount = 0
    end

    for fName, fState in pairs(Renderer.frames) do
        if fState.layoutDirty or fState.layoutBlocked then
            layout(fName)
        end
    end
end

-- 7 大告警框架同步拖曳與位置調整模式開關
function Renderer.toggleAnchors()
    Renderer.isMoving = not Renderer.isMoving

    local nameLabels = {
        selfAura = EAM.L.EAM_FRAME_SELF_AURA or "EAM - 自身光環框架",
        targetAura = EAM.L.EAM_FRAME_TARGET_AURA or "EAM - 目標光環框架",
        spellCooldown = EAM.L.EAM_FRAME_SPELL_COOLDOWN or "EAM - 技能冷卻框架",
        itemCooldown = EAM.L.EAM_FRAME_ITEM_COOLDOWN or "EAM - 物品冷卻框架",
        classPower = EAM.L.EAM_FRAME_CLASS_POWER or "EAM - 職業能量框架",
        groundEffect = EAM.L.EAM_FRAME_GROUND_EFFECT or "EAM - 地面效果框架",
        totem = EAM.L.EAM_FRAME_TOTEM or "EAM - 圖騰監控框架",
    }

    for fName, fState in pairs(Renderer.frames) do
        local parent = ensureParent(fName)
        if parent then
            if not parent.dragTexture then
                -- 建立半透明移動背景
                local bg = parent:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints(parent)
                bg:SetColorTexture(0.8, 0.2, 0.2, 0.5)
                parent.dragTexture = bg

                -- 建立移動提示文字
                local txt = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                txt:SetPoint("CENTER", parent, "CENTER", 0, 0)
                txt:SetText(nameLabels[fName] or fName)
                parent.dragText = txt

                parent:RegisterForDrag("LeftButton")
                parent:SetScript("OnDragStart", parent.StartMoving)
                parent:SetScript("OnDragStop", function(self)
                    self:StopMovingOrSizing()
                    local point, relativeTo, relativePoint, xOffset, yOffset = self:GetPoint()
                    if EAM.db and EAM.db.layout and EAM.db.layout.frames and EAM.db.layout.frames[self.frameName] then
                        local cfg = EAM.db.layout.frames[self.frameName]
                        cfg.point = point or "CENTER"
                        cfg.x = xOffset or 0
                        cfg.y = yOffset or 0
                    end
                    print("|cff00ff96EAM|r [" .. (nameLabels[self.frameName] or self.frameName) .. "] " .. string.format(EAM.L.EAM_FRAME_POS_SAVED or "位置已保存: %s, X: %.1f, Y: %.1f", point, xOffset, yOffset))
                end)
            end

            if Renderer.isMoving then
                parent:SetMovable(true)
                parent:EnableMouse(true)
                parent.dragTexture:Show()
                parent.dragText:Show()
                -- 給定基礎大小，以防它空載時無面積可供鼠標點選
                local size = EAM.db and EAM.db.layout and EAM.db.layout.iconSize or Renderer.iconSize
                parent:SetSize(400, size)
                parent:Show()
            else
                parent:SetMovable(false)
                parent:EnableMouse(false)
                parent.dragTexture:Hide()
                parent.dragText:Hide()
                -- 恢復正常的佈局與大小
                fState.layoutDirty = true
                layout(fName)
            end
        end
    end

    if Renderer.isMoving then
        print("|cff00ff96EAM|r " .. (EAM.L.EAM_MOVE_MODE_ON or "已開啟「多框架移動模式」！所有框架已亮起，請用滑鼠左鍵拖曳移動它們，再次點擊按鈕可關閉。"))
    else
        print("|cff00ff96EAM|r " .. (EAM.L.EAM_MOVE_MODE_OFF or "已關閉「多框架移動模式」並成功套用新排版。"))
    end
end
