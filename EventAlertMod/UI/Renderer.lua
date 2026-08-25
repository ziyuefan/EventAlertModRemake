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
local TextPlacement = EAM.UI.TextPlacement
local DurationAdapter = EAM.Modules.DurationAdapter

local Renderer = {
    frames = {},
    deferred = {},
    deferredCount = 0,
    iconSize = 40,
    spacing = 6,
    isMoving = false,
    textLayoutPending = false,
    prewarmPending = false,
    anchorTogglePending = false,
}

local function readField(object, name)
    if not object then
        return nil
    end
    local ok, value = pcall(function()
        return object[name]
    end)
    if ok then
        return value
    end
    return nil
end

local function releaseTimerBinding(icon)
    if not icon or not icon.timerBinding then
        return
    end
    if DurationAdapter then
        DurationAdapter.releaseTextBinding(icon.timerBinding)
    end
    icon.timerBinding = nil
end

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
    if icon and icon.rendered
        and icon.rendered.activeToken == token
        and token.expTime == icon.rendered.scheduledExpirationTime
    then
        icon.rendered.activeToken = nil
        icon.rendered.scheduledExpirationTime = nil
        token.active = false
        local cooldownService = EAM.Services and EAM.Services.CooldownService
        if cooldownService and type(cooldownService.onVisualTimerExpired) == "function" then
            cooldownService.onVisualTimerExpired(token.alertID)
        else
            Renderer.render({ id = token.alertID, shown = false }, token.frameName)
        end
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

            local radialGauge = readField(icon, "radialGauge")
            if radialGauge and radialGauge.active and icon.rendered and icon.rendered.duration and icon.rendered.duration > 0 then
                local pct = timeLeft / icon.rendered.duration
                local isPandemic = icon.rendered.isPandemic or (timeLeft <= (icon.rendered.duration * 0.3))
                local RadialGauge = EAM.UI.RadialGauge
                if RadialGauge and RadialGauge.update then
                    RadialGauge.update(radialGauge, pct, isPandemic)
                end
            end
        else
            activeLegacyTimers[icon] = nil
            local radialGauge = readField(icon, "radialGauge")
            if radialGauge and radialGauge.active then
                local RadialGauge = EAM.UI.RadialGauge
                if RadialGauge and RadialGauge.update then
                    RadialGauge.update(radialGauge, 0, false)
                end
            end
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

function Renderer.getFrameParent(frameName)
    local fState = initFrameState(frameName)
    if fState and fState.parent then
        return fState.parent
    end
    return ensureParent(frameName)
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

local function formatChargeText(alertState)
    if not alertState or alertState.isChargeBased ~= true
        or alertState.chargesSafe ~= true
    then
        return nil
    end
    local currentCharges = alertState.displayValue
    local maximumCharges = alertState.displayMaxValue
    if not Util.isSafeNonNegativeNumber(currentCharges)
        or not Util.isSafePositiveNumber(maximumCharges)
    then
        return ""
    end
    return tostring(currentCharges) .. "/" .. tostring(maximumCharges)
end

local function formatAbsorbAmount(val)
    if not val or type(val) ~= "number" or val <= 0 then return nil end
    if val >= 1000000 then
        return string.format("%.1fM", val / 1000000)
    elseif val >= 10000 then
        return string.format("%.0fk", val / 1000)
    elseif val >= 1000 then
        return string.format("%.1fk", val / 1000)
    else
        return tostring(math.floor(val + 0.5))
    end
end

local function applyNameLayoutToIcon(icon, nameInside)
    if not icon or not icon.rendered or not icon.nameText then
        return false
    end

    local rendered = icon.rendered
    if rendered.nameInside == nameInside then
        rendered.nameLayoutPending = nil
        rendered.pendingNameInside = nil
        return false
    end

    if api.InCombatLockdown and api.InCombatLockdown() then
        rendered.nameLayoutPending = true
        rendered.pendingNameInside = nameInside
        return false, "combatDeferred"
    end

    local refFrame = icon.overlay or icon
    icon.nameText:ClearAllPoints()
    if nameInside then
        icon.nameText:SetPoint("BOTTOM", refFrame, "BOTTOM", 0, 2)
        icon.nameText:SetFontObject("GameFontHighlightSmall")
        TextPlacement.applyFont(icon.nameText, icon.rendered.nameFontSize or 12, EAM.db and EAM.db.config or nil)
    else
        icon.nameText:SetPoint("TOP", refFrame, "BOTTOM", 0, -2)
        icon.nameText:SetFontObject("GameFontNormalSmall")
        TextPlacement.applyFont(icon.nameText, icon.rendered.nameFontSize or 12, EAM.db and EAM.db.config or nil)
    end
    rendered.nameInside = nameInside
    rendered.nameLayoutPending = nil
    rendered.pendingNameInside = nil
    return true
end

local function inCombat()
    return api.InCombatLockdown and api.InCombatLockdown()
end

local function applyTextLayoutToIcon(icon, config)
    if not icon or not icon.rendered or not icon.timerText or not icon.stackText then
        return false
    end

    local rendered = icon.rendered
    local refFrame = icon.overlay or icon
    local timerPlacement = TextPlacement.getPlacement(config, "timer")
    local applicationsPlacement = TextPlacement.getPlacement(config, "applications")
    local timerFontSize = TextPlacement.getFontSize(config, "timer")
    local applicationsFontSize = TextPlacement.getFontSize(config, "applications")
    local nameFontSize = config and config.fontSizeSpellName or 12
    if not Util.isSafePositiveNumber(nameFontSize) then
        nameFontSize = 12
    end

    if rendered.timerPlacement ~= timerPlacement then
        TextPlacement.apply(icon.timerText, refFrame, timerPlacement)
        rendered.timerPlacement = timerPlacement
    end
    if rendered.applicationsPlacement ~= applicationsPlacement then
        TextPlacement.apply(icon.stackText, refFrame, applicationsPlacement)
        rendered.applicationsPlacement = applicationsPlacement
    end
    if rendered.timerFontSize ~= timerFontSize then
        TextPlacement.applyFont(icon.timerText, timerFontSize, config)
        rendered.timerFontSize = timerFontSize
    end
    if rendered.applicationsFontSize ~= applicationsFontSize then
        TextPlacement.applyFont(icon.stackText, applicationsFontSize, config)
        rendered.applicationsFontSize = applicationsFontSize
    end
    if icon.nameText and rendered.nameFontSize ~= nameFontSize then
        TextPlacement.applyFont(icon.nameText, nameFontSize, config)
        rendered.nameFontSize = nameFontSize
    end
    return true
end

function Renderer.applyTextLayout()
    if inCombat() then
        Renderer.textLayoutPending = true
        return false, "combatDeferred"
    end

    local config = EAM.db and EAM.db.config or nil
    local updated = 0
    for _, fState in pairs(Renderer.frames) do
        for _, icon in pairs(fState.icons) do
            if applyTextLayoutToIcon(icon, config) then
                updated = updated + 1
            end
        end
    end
    Renderer.textLayoutPending = false
    return true, updated
end

function Renderer.applyCooldownStyle()
    local config = EAM.db and EAM.db.config or nil
    local updated = 0
    for _, frameState in pairs(Renderer.frames) do
        for _, icon in pairs(frameState.icons or {}) do
            if IconPool.applyCooldownStyle(icon, config) then
                updated = updated + 1
            end
        end
    end
    return true, updated
end

-- 核心 Layout 排版演算法 (極致靜態陣列優化版)
local function layout(frameName)
    local fState = initFrameState(frameName)
    if inCombat() then
        fState.layoutDirty = true
        fState.layoutBlocked = true
        return false, "combatDeferred"
    end
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

    -- 職業能量框架作為獨立資源容器錨點，不套用單一列表隱藏邏輯
    if frameName == "classPower" then
        parent:Show()
        fState.layoutDirty = false
        fState.layoutBlocked = false
        return true, "classPowerAnchor"
    end

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
    return true, "updated"
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
        if inCombat() then
            fState.layoutBlocked = true
            return false, "combatDeferred"
        end
        return layout(frameName)
    end
    return false, "frameUnavailable"
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
        if inCombat() then
            Renderer.prewarmPending = true
        else
            local prewarmed = IconPool.prewarm()
            Renderer.prewarmPending = prewarmed == false
        end
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
        fState.layoutDirty = true
        fState.layoutBlocked = true
        deferRender(alertState, frameName)
        return false, "combatDeferred"
    end

    -- 確保 parent frame 存在
    parent = ensureParent(frameName)
    if not parent then
        deferRender(alertState, frameName)
        return
    end

    local icon = fState.icons[alertState.id]
    if not icon and inCombat() then
        fState.layoutDirty = true
        fState.layoutBlocked = true
        deferRender(alertState, frameName)
        return false, "combatDeferred"
    end

    -- 圖示隱藏/釋放處理
    if not alertState.shown then
        if icon then
            if icon.isParasite and inCombat() then
                if icon.rendered and icon.rendered.activeToken then
                    icon.rendered.activeToken.active = false
                    icon.rendered.activeToken = nil
                end
                icon.releasePending = true
                fState.layoutDirty = true
                fState.layoutBlocked = true
                deferRender(alertState, frameName)
                return false, "combatDeferred"
            end
            icon.releasePending = nil
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
    local rendered = icon.rendered

    if icon.isParasite ~= shouldBeParasite then
        if inCombat() then
            rendered.parasiteLayoutPending = true
            fState.layoutDirty = true
            fState.layoutBlocked = true
            deferRender(alertState, frameName)
        else
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
            icon.isParasite = shouldBeParasite
            rendered.parasiteLayoutPending = nil
            fState.layoutDirty = true
        end
    else
        rendered.parasiteLayoutPending = nil
    end

    if alertState.icon and rendered.icon ~= alertState.icon then
        icon.texture:SetTexture(alertState.icon)
        rendered.icon = alertState.icon
    end

    IconPool.applyTooltipSource(icon, alertState)
    IconPool.applyTypeBorder(icon, alertState, frameName)

    local config = EAM.db and EAM.db.config or nil
    if inCombat() then
        Renderer.textLayoutPending = true
    else
        applyTextLayoutToIcon(icon, config)
    end
    IconPool.applyCooldownStyle(icon, config)

    local stacks = formatChargeText(alertState)
    if stacks == nil then
        if alertState.absorbAmount and Util.isSafePositiveNumber(alertState.absorbAmount) then
            local absStr = formatAbsorbAmount(alertState.absorbAmount)
            if alertState.stacks and alertState.stacks > 1 then
                stacks = tostring(alertState.stacks) .. "(" .. absStr .. ")"
            else
                stacks = absStr
            end
        else
            stacks = alertState.displayValue
            if Util.isSecretValue(stacks) or not Util.canAccessValue(stacks) then
                stacks = ""
            elseif stacks ~= nil then
                stacks = Util.isSafeNonNegativeNumber(stacks) and tostring(stacks) or ""
            else
                stacks = alertState.stacks
                if Util.isSecretValue(stacks) or not Util.canAccessValue(stacks) then
                    stacks = ""
                else
                    stacks = (Util.isSafeNumber(stacks) and stacks > 1) and tostring(stacks) or ""
                end
            end
        end
    end
    setTextIfChanged(icon.stackText, rendered, "stacks", stacks)

    local nameInside = shouldBeParasite
    if rendered.nameInside ~= nameInside then
        if inCombat() then
            rendered.nameLayoutPending = true
            rendered.pendingNameInside = nameInside
            fState.layoutDirty = true
            fState.layoutBlocked = true
        else
            applyNameLayoutToIcon(icon, nameInside)
        end
    elseif rendered.nameLayoutPending then
        rendered.nameLayoutPending = nil
        rendered.pendingNameInside = nil
    end

    local name = alertState.name or ""
    setTextIfChanged(icon.nameText, rendered, "name", name)

    -- Cooldown 與 DurationObject 倒數雙軌管道渲染
    local timer = alertState.timer
    local useNativeBinding = timer and timer.durationObject and DurationAdapter ~= nil

    if useNativeBinding then
        if icon.cooldown and type(icon.cooldown.Show) == "function" then
            icon.cooldown:Show()
        end
        if rendered.durationObject ~= timer.durationObject then
            releaseTimerBinding(icon)
            icon.timerBinding = DurationAdapter.createTextBinding(timer.durationObject, icon.timerText)
            
            if icon.cooldown.SetCooldownFromDurationObject then
                icon.cooldown:SetCooldownFromDurationObject(timer.durationObject)
            elseif timer.startTime and timer.duration then
                icon.cooldown:SetCooldown(timer.startTime, timer.duration)
            else
                icon.cooldown:SetCooldown(0, 0)
            end

            rendered.durationObject = timer.durationObject
            rendered.durationBindingAvailable = icon.timerBinding ~= nil
            rendered.cooldownStart = nil
            rendered.cooldownDuration = nil
        end
        if icon.timerBinding then
            Renderer.unregisterLegacyTimer(icon)
        elseif Util.isSafeNumber(timer.expirationTime) then
            Renderer.registerLegacyTimer(icon, timer.expirationTime)
        else
            Renderer.unregisterLegacyTimer(icon)
        end
    elseif timer and Util.isSafeNumber(timer.startTime) and Util.isSafePositiveNumber(timer.duration) then
        if icon.cooldown and type(icon.cooldown.Show) == "function" then
            icon.cooldown:Show()
        end
        if rendered.cooldownStart ~= timer.startTime or rendered.cooldownDuration ~= timer.duration then
            icon.cooldown:SetCooldown(timer.startTime, timer.duration)
            rendered.cooldownStart = timer.startTime
            rendered.cooldownDuration = timer.duration
            rendered.durationObject = nil
        end
        releaseTimerBinding(icon)
        
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
        if icon.cooldown and type(icon.cooldown.Hide) == "function" then
            icon.cooldown:Hide()
        end
        rendered.cooldownStart = nil
        rendered.cooldownDuration = nil
        rendered.durationObject = nil
        rendered.durationBindingAvailable = nil
        releaseTimerBinding(icon)
        Renderer.unregisterLegacyTimer(icon)
        if icon.timerText then
            if icon.timerText.ClearText then
                icon.timerText:ClearText()
            else
                icon.timerText:SetText("")
            end
        end
    end

    rendered.duration = timer and timer.duration
    rendered.isPandemic = alertState.pandemicReady or alertState.isImportant
    local radialGauge = readField(icon, "radialGauge")
    if radialGauge then
        local RadialGauge = EAM.UI.RadialGauge
        if RadialGauge and RadialGauge.setVisible then
            local showRadial = EAM.db and EAM.db.config and EAM.db.config.showRadialGauge ~= false
            local hasDuration = timer and Util.isSafePositiveNumber(timer.duration)
            RadialGauge.setVisible(radialGauge, showRadial and hasDuration)
        end
    end

    if IconPool and type(IconPool.applyChargeProgress) == "function" then
        IconPool.applyChargeProgress(icon, alertState)
    end

    -- 🌡️ Pandemic (傳染累加)、重要法術與 Action Bar Glow 亮框顯示控制
    local shouldGlow = alertState.pandemicReady or alertState.overlayGlow or alertState.usableGlow or alertState.isImportant
    if IconPool and type(IconPool.setGlow) == "function" then
        IconPool.setGlow(icon, shouldGlow == true)
    elseif shouldGlow then
        if icon.glowBorder then icon.glowBorder:Show() end
    elseif icon.glowBorder then
        icon.glowBorder:Hide()
    end

    if icon.overlay and icon.cooldown and icon.cooldown.GetFrameLevel then
        local cooldownLevel = icon.cooldown:GetFrameLevel()
        if Util.isSafeNumber(cooldownLevel) then
            icon.overlay:SetFrameLevel(cooldownLevel + 5)
        end
    end

    -- 只在安全 expiration 改變時重排；中途重繪不得從完整 duration 重新計時。
    local expirationTime = timer and timer.expirationTime
    local now = api.GetTime and api.GetTime() or nil
    if Util.isSafeNumber(expirationTime) and Util.isSafeNumber(now) then
        local remaining = expirationTime - now
        if Util.isSafePositiveNumber(remaining)
            and rendered.scheduledExpirationTime ~= expirationTime
        then
            if rendered.activeToken then
                rendered.activeToken.active = false
                rendered.activeToken = nil
            end

            local token = acquireToken()
            token.icon = icon
            token.expTime = expirationTime
            token.active = true
            token.frameName = frameName
            token.alertID = alertState.id

            rendered.activeToken = token
            rendered.scheduledExpirationTime = expirationTime

            local Scheduler = EAM.Modules.Scheduler
            if Scheduler and Scheduler.after then
                Scheduler.after(remaining, onDurationTimerExpired, token)
            end
        elseif not Util.isSafePositiveNumber(remaining) then
            if rendered.activeToken then
                rendered.activeToken.active = false
                rendered.activeToken = nil
            end
            rendered.scheduledExpirationTime = nil
        end
    else
        if rendered.activeToken then
            rendered.activeToken.active = false
            rendered.activeToken = nil
        end
        rendered.scheduledExpirationTime = nil
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

function Renderer.clearFrame(frameName)
    local frameState = Renderer.frames[frameName]
    for id, item in pairs(Renderer.deferred) do
        if item.frameName == frameName then
            Renderer.deferred[id] = nil
            Renderer.deferredCount = math.max(0, Renderer.deferredCount - 1)
        end
    end
    if not frameState then
        return true, "empty"
    end

    while frameState.orderCount > 0 do
        local alertID = frameState.order[frameState.orderCount]
        local before = frameState.orderCount
        Renderer.render({ id = alertID, shown = false }, frameName)
        if frameState.orderCount == before then
            return false, "combatDeferred"
        end
    end
    return true, "cleared"
end

-- 離開戰鬥時，將戰鬥中被阻攔的渲染與 Layout 變更安全地釋放執行
function Renderer.onCombatEnd()
    -- 戰鬥結束後，重新嘗試確保所有框架 parent 已成功建立
    for fName in pairs(EAM.Constants.ALERT_FRAME_TYPES) do
        ensureParent(fName)
    end

    if Renderer.prewarmPending and IconPool.prewarm then
        local prewarmed = IconPool.prewarm()
        if prewarmed ~= false then
            Renderer.prewarmPending = false
        end
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
        for _, icon in pairs(fState.icons) do
            local rendered = icon.rendered
            if rendered and rendered.nameLayoutPending then
                applyNameLayoutToIcon(icon, rendered.pendingNameInside)
            end
        end
        if fState.layoutDirty or fState.layoutBlocked then
            layout(fName)
        end
    end
    if Renderer.textLayoutPending then
        Renderer.applyTextLayout()
    end
    if Renderer.anchorTogglePending then
        Renderer.anchorTogglePending = false
        Renderer.toggleAnchors()
    end
end

local COW_ICON = "Interface\\Icons\\Spell_Nature_Polymorph_Cow"

local PREVIEW_CONFIG = {
    selfAura = {
        title = "EAM - 自身光環框架",
        slots = {
            { text = "本身Debuff(2)", step = -2, isDebuff = true, isSelfDebuff = true, sampleStack = 2, sampleCD = 6 },
            { text = "本身Debuff(1)\n或特殊框架", step = -1, isDebuff = true, isSelfDebuff = true, sampleStack = 1, sampleCD = 8 },
            { text = "本身Buff(1)", step = 0, isBuff = true, sampleStack = nil, sampleCD = 10 },
            { text = "本身Buff(2)", step = 1, isBuff = true, sampleStack = 5, sampleCD = 4 },
        }
    },
    targetAura = {
        title = "EAM - 目標光環框架",
        slots = {
            { text = "目標Buff(2)", step = -2, isBuff = true, sampleStack = 3, sampleCD = 5 },
            { text = "目標Buff(1)\n或特殊框架", step = -1, isBuff = true, sampleStack = nil, sampleCD = 12 },
            { text = "目標Debuff(1)", step = 0, isDebuff = true, isTargetDebuff = true, sampleStack = nil, sampleCD = 9 },
            { text = "目標Debuff(2)", step = 1, isDebuff = true, isTargetDebuff = true, sampleStack = 4, sampleCD = 3 },
        }
    },
    spellCooldown = {
        title = "EAM - 技能冷卻框架",
        slots = {
            { text = "技能CD(1)", step = 0, isCooldown = true, sampleStack = nil, sampleCD = 15 },
            { text = "技能CD(2)", step = 1, isCooldown = true, sampleStack = 2, sampleCD = 6 },
        }
    },
    itemCooldown = {
        title = "EAM - 物品冷卻框架",
        slots = {
            { text = "物品CD(1)", step = 0, isCooldown = true, sampleStack = 1, sampleCD = 30 },
            { text = "物品CD(2)", step = 1, isCooldown = true, sampleStack = nil, sampleCD = 10 },
        }
    },
    groundEffect = {
        title = "EAM - 地面效果框架",
        slots = {
            { text = "地面效果(1)", step = 0, isGround = true, sampleStack = nil, sampleCD = 8 },
            { text = "地面效果(2)", step = 1, isGround = true, sampleStack = nil, sampleCD = 4 },
        }
    },
    classPower = {
        title = "EAM - 職業能量框架",
        slots = {
            { text = "★ 玩家職業資源", step = 0, isPower = true, sampleStack = nil, sampleCD = nil },
        }
    },
    totem = {
        title = "EAM - 圖騰監控框架",
        slots = {
            { text = "圖騰監控(1)", step = 0, isTotem = true, sampleStack = nil, sampleCD = 15 },
        }
    },
    playerStat = {
        title = "EAM - 角色屬性與吸收量框架",
        slots = {
            { text = "★ 屬性/吸收量", step = 0, isStat = true, sampleStack = nil, sampleCD = nil },
        }
    },
}

local function getOrCreatePreviewIcon(parent, index)
    parent.previewIcons = parent.previewIcons or {}
    if parent.previewIcons[index] then
        return parent.previewIcons[index]
    end

    local icon = api.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    icon:SetFrameStrata("HIGH")

    -- 經典奶牛頭貼圖
    local tex = icon:CreateTexture(nil, "BACKGROUND")
    tex:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
    tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    tex:SetTexture(COW_ICON)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.texture = tex

    -- 倒數扇形轉圈 Cooldown 框架 (即時預覽扇形倒數轉圈)
    local cd = api.CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    cd:SetAllPoints(icon)
    cd:SetDrawEdge(true)
    cd:SetDrawBling(false)
    cd:SetDrawSwipe(true)
    cd:SetReverse(true)
    icon.cooldown = cd

    -- TIME LEFT / 倒數文字
    local timerText = icon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timerText:SetPoint("BOTTOM", icon, "TOP", 0, 3)
    timerText:SetText("TIME LEFT")
    timerText:SetTextColor(1, 1, 1, 1)
    icon.timerText = timerText

    -- 槽位說明文字 (名稱)
    local nameText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOP", icon, "BOTTOM", 0, -3)
    nameText:SetTextColor(1, 0.95, 0.5, 1)
    icon.nameText = nameText

    -- 堆疊層數文字
    local stackText = icon:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stackText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    stackText:SetTextColor(1, 1, 1, 1)
    icon.stackText = stackText

    icon:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 0, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    parent.previewIcons[index] = icon
    return icon
end

-- 即時熱更新所有作用中預覽框架的尺寸、間距、透明度、轉圈與顏色
function Renderer.refreshPreviewLayout()
    if inCombat() then return end
    if not Renderer.activeAnchorMap then return end

    local cfg = EAM.db and EAM.db.config or {}
    local layoutCfg = EAM.db and EAM.db.layout or {}
    local framesCfg = layoutCfg.frames or {}

    local size = cfg.iconSize or layoutCfg.iconSize or Renderer.iconSize
    local spacing = cfg.iconSpacing or layoutCfg.spacing or Renderer.spacing
    local vertSpacing = cfg.verticalSpacing or spacing
    local alpha = cfg.iconAlpha or 1.0
    local swipeAlpha = cfg.cooldownSwipeAlpha or 0.8
    local selfDebuffRed = cfg.selfDebuffRed or 0.5
    local targetDebuffGreen = cfg.targetDebuffGreen or 0.5

    local fontSpell = cfg.fontSizeSpellName or 12
    local fontTime = cfg.fontSizeTimeVal or 12
    local fontStack = cfg.fontSizeStack or 12

    local now = (api.GetTime and api.GetTime()) or 0

    for fName, active in pairs(Renderer.activeAnchorMap) do
        if active then
            local parent = ensureParent(fName)
            local pCfg = PREVIEW_CONFIG[fName]
            local fLayout = framesCfg[fName] or {}
            local growDir = fLayout.growDirection or 1

            if parent and pCfg and pCfg.slots then
                parent:SetSize(size, size)

                for sIdx, slot in ipairs(pCfg.slots) do
                    local pIcon = getOrCreatePreviewIcon(parent, sIdx)
                    pIcon:SetSize(size, size)
                    pIcon:SetAlpha(alpha)

                    -- 依照成長方向 (1:右, 2:左, 3:上, 4:下) 計算偏移
                    local dx = 0
                    local dy = 0
                    local step = slot.step or 0
                    if growDir == 1 then
                        dx = step * (size + spacing)
                    elseif growDir == 2 then
                        dx = -step * (size + spacing)
                    elseif growDir == 3 then
                        dy = step * (size + vertSpacing)
                    elseif growDir == 4 then
                        dy = -step * (size + vertSpacing)
                    end

                    pIcon:ClearAllPoints()
                    pIcon:SetPoint("CENTER", parent, "CENTER", dx, dy)

                    -- 文字與字型大小即時更新
                    pIcon.nameText:SetText(slot.text)
                    if TextPlacement and TextPlacement.applyFont then
                        TextPlacement.applyFont(pIcon.nameText, fontSpell, cfg)
                        TextPlacement.applyFont(pIcon.timerText, fontTime, cfg)
                        TextPlacement.applyFont(pIcon.stackText, fontStack, cfg)
                    end

                    pIcon.stackText:SetText(slot.sampleStack and tostring(slot.sampleStack) or "")

                    -- 扇形倒數轉圈與透明度即時預覽
                    if pIcon.cooldown then
                        pIcon.cooldown:SetSwipeColor(0, 0, 0, swipeAlpha)
                        if slot.sampleCD then
                            pIcon.cooldown:SetCooldown(now - 2, slot.sampleCD)
                            pIcon.cooldown:Show()
                            pIcon.timerText:SetText(string.format("%.1f", math.max(0.1, slot.sampleCD - 2)))
                        else
                            pIcon.cooldown:Hide()
                            pIcon.timerText:SetText("TIME LEFT")
                        end
                    end

                    -- 顏色即時預覽 (紅/綠色度與常規邊框)
                    if slot.isSelfDebuff then
                        local r = 1.0
                        local g = math.max(0, 1.0 - selfDebuffRed * 0.7)
                        local b = math.max(0, 1.0 - selfDebuffRed * 0.7)
                        pIcon:SetBackdropBorderColor(r, g, b, 1.0)
                        pIcon.texture:SetVertexColor(r, math.max(0.2, 1.0 - selfDebuffRed * 0.35), math.max(0.2, 1.0 - selfDebuffRed * 0.35), 1.0)
                    elseif slot.isTargetDebuff then
                        local r = math.max(0, 1.0 - targetDebuffGreen * 0.7)
                        local g = 1.0
                        local b = math.max(0, 1.0 - targetDebuffGreen * 0.7)
                        pIcon:SetBackdropBorderColor(r, g, b, 1.0)
                        pIcon.texture:SetVertexColor(math.max(0.2, 1.0 - targetDebuffGreen * 0.35), g, math.max(0.2, 1.0 - targetDebuffGreen * 0.35), 1.0)
                    elseif slot.isPower then
                        pIcon:SetBackdropBorderColor(0.4, 0.8, 1.0, 1.0)
                        pIcon.texture:SetVertexColor(0.8, 0.95, 1.0, 1.0)
                    else
                        pIcon:SetBackdropBorderColor(0.85, 0.85, 0.85, 1.0)
                        pIcon.texture:SetVertexColor(1.0, 1.0, 1.0, 1.0)
                    end
                    pIcon:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
                    pIcon:Show()
                end

                if parent.previewIcons then
                    for sIdx = #pCfg.slots + 1, #parent.previewIcons do
                        parent.previewIcons[sIdx]:Hide()
                    end
                end

                if parent.dragHint then
                    parent.dragHint:Show()
                end
                parent:Show()
            end
        end
    end
end

-- 7 大告警框架特定/全部移動模式控制
function Renderer.setActiveAnchors(targetFrames)
    if inCombat() then
        return false, "combatDeferred"
    end

    local nameLabels = {
        selfAura = EAM.L.EAM_FRAME_SELF_AURA or "EAM - 自身光環框架",
        targetAura = EAM.L.EAM_FRAME_TARGET_AURA or "EAM - 目標光環框架",
        spellCooldown = EAM.L.EAM_FRAME_SPELL_COOLDOWN or "EAM - 技能冷卻框架",
        itemCooldown = EAM.L.EAM_FRAME_ITEM_COOLDOWN or "EAM - 物品冷卻框架",
        classPower = EAM.L.EAM_FRAME_CLASS_POWER or "EAM - 職業能量框架",
        groundEffect = EAM.L.EAM_FRAME_GROUND_EFFECT or "EAM - 地面效果框架",
        totem = EAM.L.EAM_FRAME_TOTEM or "EAM - 圖騰監控框架",
        playerStat = EAM.L.EAM_FRAME_PLAYER_STAT or "EAM - 角色屬性與吸收量框架",
    }

    local activeMap = {}
    if targetFrames == "all" then
        for fName in pairs(nameLabels) do
            activeMap[fName] = true
        end
    elseif type(targetFrames) == "table" then
        for _, fName in ipairs(targetFrames) do
            activeMap[fName] = true
        end
    elseif type(targetFrames) == "string" and targetFrames ~= "" then
        activeMap[targetFrames] = true
    end

    Renderer.activeAnchorMap = activeMap

    local anyActive = false
    for fName in pairs(nameLabels) do
        local parent = ensureParent(fName)
        local fState = initFrameState(fName)
        if parent then
            if not parent.dragSetupDone then
                parent.dragSetupDone = true
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
                    local fLabel = (nameLabels and nameLabels[self.frameName]) or self.frameName
                    print("|cff00ff96EAM|r [" .. fLabel .. "] " .. string.format(EAM.L.EAM_FRAME_POS_SAVED or "位置已保存: %s, X: %.1f, Y: %.1f", point or "CENTER", xOffset or 0, yOffset or 0))
                end)

                local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                hint:SetPoint("TOP", parent, "BOTTOM", 0, -26)
                hint:SetTextColor(0.4, 0.9, 1.0, 1.0)
                hint:SetText((nameLabels[fName] or fName) .. " (按住左鍵拖曳)")
                parent.dragHint = hint
            end

            if activeMap[fName] then
                anyActive = true
                parent:SetMovable(true)
                parent:EnableMouse(true)
                parent:SetFrameStrata("HIGH")
                parent:SetClampedToScreen(true)
            else
                parent:SetMovable(false)
                parent:EnableMouse(false)
                if parent.dragHint then parent.dragHint:Hide() end
                if parent.previewIcons then
                    for _, pIcon in ipairs(parent.previewIcons) do
                        pIcon:Hide()
                    end
                end
                if fState then
                    fState.layoutDirty = true
                    layout(fName)
                end
            end
        end
    end

    Renderer.isMoving = anyActive
    if anyActive then
        Renderer.refreshPreviewLayout()
    end
    if EAM.Services and EAM.Services.PlayerStatService and EAM.Services.PlayerStatService.setActiveAnchors then
        EAM.Services.PlayerStatService.setActiveAnchors(anyActive, activeMap["playerStat"] and "playerStat" or nil)
    end
    return true, anyActive
end

-- 7 大告警框架同步拖曳與位置調整模式開關
function Renderer.toggleAnchors()
    if inCombat() then
        Renderer.anchorTogglePending = not Renderer.anchorTogglePending
        return false, "combatDeferred"
    end
    Renderer.anchorTogglePending = false
    local nextState = not Renderer.isMoving
    Renderer.setActiveAnchors(nextState and "all" or nil)

    if Renderer.isMoving then
        print("|cff00ff96EAM|r " .. (EAM.L.EAM_MOVE_MODE_ON or "已開啟「多框架移動模式」！所有框架已亮起，請用滑鼠左鍵拖曳移動它們，再次點擊按鈕可關閉。"))
    else
        print("|cff00ff96EAM|r " .. (EAM.L.EAM_MOVE_MODE_OFF or "已關閉「多框架移動模式」並成功套用新排版。"))
    end
    return true, Renderer.isMoving
end
