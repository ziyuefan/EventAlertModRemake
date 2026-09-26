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
    isAlertsSuppressed = false,
    escCloseFrame = nil,
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

local function safeCall(object, name, ...)
    local method = readField(object, name)
    if type(method) == "function" then
        return pcall(method, object, ...)
    end
    return false
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
        local handled = false
        if token.frameName == EAM.Constants.ALERT_FRAME_TYPES.spellCooldown then
            local cooldownService = EAM.Services and EAM.Services.CooldownService
            if cooldownService and type(cooldownService.onVisualTimerExpired) == "function" then
                handled = cooldownService.onVisualTimerExpired(token.alertID)
            end
        elseif token.frameName == EAM.Constants.ALERT_FRAME_TYPES.itemCooldown then
            local itemCooldownService = EAM.Services and EAM.Services.ItemCooldownService
            if itemCooldownService and type(itemCooldownService.onVisualTimerExpired) == "function" then
                handled = itemCooldownService.onVisualTimerExpired(token.alertID)
            end
        end
        if not handled then
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
            if icon.timerText then
                local colorToApply = { 1, 1, 1, 1 }
                local tcc = EAM.db and EAM.db.config and EAM.db.config.timerColorCurve
                if tcc and tcc.normalColor then
                    colorToApply = tcc.normalColor
                end
                if icon.countdownRedLimit and icon.countdownRedLimit > 0 and timeLeft <= icon.countdownRedLimit then
                    colorToApply = icon.countdownRedColor or { 1.0, 0.15, 0.15, 1.0 }
                elseif tcc and tcc.enabled and type(tcc.stages) == "table" then
                    for i = 1, #tcc.stages do
                        local stage = tcc.stages[i]
                        if stage and stage.threshold and timeLeft <= stage.threshold then
                            colorToApply = stage.color or colorToApply
                            break
                        end
                    end
                end
                if icon.timerText.SetTextColor then
                    icon.timerText:SetTextColor(colorToApply[1] or 1, colorToApply[2] or 1, colorToApply[3] or 1, colorToApply[4] or 1)
                end
                if icon.timerText.SetFormattedText then
                    if timeLeft < 3.05 then
                        icon.timerText:SetFormattedText("%.1f", timeLeft)
                    else
                        icon.timerText:SetFormattedText("%d", math.ceil(timeLeft))
                    end
                elseif icon.timerText.SetText then
                    if timeLeft < 3.05 then
                        icon.timerText:SetText(string.format("%.1f", timeLeft))
                    else
                        icon.timerText:SetText(string.format("%d", math.ceil(timeLeft)))
                    end
                end
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

function Renderer.applyFramePositions()
    if not EAM.db or not EAM.db.layout or not EAM.db.layout.frames then return end
    for frameName, frameConfig in pairs(EAM.db.layout.frames) do
        local fState = Renderer.frames and Renderer.frames[frameName]
        if fState and fState.parent then
            local point = frameConfig.point or "CENTER"
            local x = frameConfig.x or 0
            local y = frameConfig.y or 0
            fState.parent:ClearAllPoints()
            fState.parent:SetPoint(point, UIParent, point, x, y)
        end
    end
    if EAM.Services and EAM.Services.AuraContainerService and EAM.Services.AuraContainerService.applyContainerPositions then
        EAM.Services.AuraContainerService.applyContainerPositions()
    end
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
    return tostring(currentCharges)
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
    local spellNamePlacement = TextPlacement.getPlacement(EAM.db and EAM.db.config, "spellName") or "OUTSIDE_BOTTOM"
    if rendered.nameInside == nameInside and (nameInside or rendered.spellNamePlacement == spellNamePlacement) then
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
    if nameInside then
        icon.nameText:ClearAllPoints()
        icon.nameText:SetPoint("BOTTOM", refFrame, "BOTTOM", 0, 2)
        icon.nameText:SetFontObject("GameFontHighlightSmall")
        TextPlacement.applyFont(icon.nameText, icon.rendered.nameFontSize or 12, EAM.db and EAM.db.config or nil)
    else
        if TextPlacement and TextPlacement.apply then
            TextPlacement.apply(icon.nameText, refFrame, spellNamePlacement)
        else
            icon.nameText:ClearAllPoints()
            icon.nameText:SetPoint("TOP", refFrame, "BOTTOM", 0, -2)
        end
        icon.nameText:SetFontObject("GameFontNormalSmall")
        TextPlacement.applyFont(icon.nameText, icon.rendered.nameFontSize or 12, EAM.db and EAM.db.config or nil)
    end
    rendered.nameInside = nameInside
    rendered.spellNamePlacement = spellNamePlacement
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
    local fontFamily = TextPlacement.getFontFamily(config)
    local timerPlacement = TextPlacement.getPlacement(config, "timer")
    local applicationsPlacement = TextPlacement.getPlacement(config, "applications")
    local spellNamePlacement = TextPlacement.getPlacement(config, "spellName") or "OUTSIDE_BOTTOM"
    local timerFontSize = TextPlacement.getFontSize(config, "timer")
    local applicationsFontSize = TextPlacement.getFontSize(config, "applications")
    local nameFontSize = TextPlacement.getFontSize(config, "spellName") or 12
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
    if icon.nameText and not rendered.nameInside then
        if rendered.spellNamePlacement ~= spellNamePlacement then
            TextPlacement.apply(icon.nameText, refFrame, spellNamePlacement)
            rendered.spellNamePlacement = spellNamePlacement
        end
    end
    if rendered.timerFontSize ~= timerFontSize or rendered.fontFamily ~= fontFamily then
        TextPlacement.applyFont(icon.timerText, timerFontSize, config)
        rendered.timerFontSize = timerFontSize
    end
    if rendered.applicationsFontSize ~= applicationsFontSize or rendered.fontFamily ~= fontFamily then
        TextPlacement.applyFont(icon.stackText, applicationsFontSize, config)
        rendered.applicationsFontSize = applicationsFontSize
    end
    if icon.nameText and (rendered.nameFontSize ~= nameFontSize or rendered.fontFamily ~= fontFamily) then
        TextPlacement.applyFont(icon.nameText, nameFontSize, config)
        rendered.nameFontSize = nameFontSize
    end
    rendered.fontFamily = fontFamily

    if TextPlacement and TextPlacement.applyColor and TextPlacement.getColor then
        local timerColor = TextPlacement.getColor(config, "timer")
        local applicationsColor = TextPlacement.getColor(config, "applications")
        local spellNameColor = TextPlacement.getColor(config, "spellName")
        TextPlacement.applyColor(icon.timerText, timerColor)
        TextPlacement.applyColor(icon.stackText, applicationsColor)
        if icon.nameText then
            TextPlacement.applyColor(icon.nameText, spellNameColor)
        end
    end

    -- 顯隱控制與自訂名稱即時熱更新
    local st = rawget(icon, "alertState") or (rendered and rendered.alertState)
    local raw = st and st.rawAlert
    local customName = raw and raw.customName and raw.customName ~= "" and raw.customName
    local resolvedName = customName or (st and st.name and st.name ~= "" and st.name) or (rendered and rendered.name)
    if resolvedName and resolvedName ~= "" then
        setTextIfChanged(icon.nameText, rendered, "name", resolvedName)
    end
    local showSpellName = not config or config.showSpellName ~= false
    if raw and raw.showName ~= nil then
        showSpellName = raw.showName ~= false
    end
    local showTimeVal = not config or config.showTimeVal ~= false
    if icon.nameText and type(icon.nameText.Hide) == "function" and type(icon.nameText.Show) == "function" then
        if not showSpellName or not resolvedName or resolvedName == "" then
            icon.nameText:Hide()
        else
            icon.nameText:Show()
        end
    end
    if icon.timerText and type(icon.timerText.Hide) == "function" and type(icon.timerText.Show) == "function" then
        if not showTimeVal then
            icon.timerText:Hide()
        else
            local hasBinding = rawget(icon, "timerBinding") ~= nil
            local expTime = rawget(icon, "expirationTime")
            if hasBinding or (rendered.cooldownDuration and rendered.cooldownDuration > 0) or (expTime and expTime > 0) then
                icon.timerText:Show()
            end
        end
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
        for _, icon in pairs(fState.icons or {}) do
            if applyTextLayoutToIcon(icon, config) then
                updated = updated + 1
            end
        end
    end
    if IconPool and IconPool.active then
        for _, icon in pairs(IconPool.active) do
            if applyTextLayoutToIcon(icon, config) then
                updated = updated + 1
            end
        end
    end
    if Renderer.refreshPreviewLayout then
        Renderer.refreshPreviewLayout()
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
    if EAM.recordHotPath then
        EAM.recordHotPath("Renderer.layout")
    end
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
    local alpha = EAM.db and EAM.db.config and EAM.db.config.iconAlpha or 1.0
    local spacing = EAM.db and EAM.db.config and EAM.db.config.iconSpacing or (EAM.db and EAM.db.layout and EAM.db.layout.spacing) or Renderer.spacing
    local vSpacing = (EAM.db and EAM.db.layout and EAM.db.layout.verticalSpacing and EAM.db.layout.verticalSpacing > 0) and EAM.db.layout.verticalSpacing or spacing
    local count = fState.orderCount

    -- 讀取目前框架設定的成長方向 (1=RIGHT, 2=LEFT, 3=UP, 4=DOWN) 與換行欄數 (預設 8)
    local dbFrames = EAM.db and EAM.db.layout and EAM.db.layout.frames
    local frameConfig = dbFrames and dbFrames[frameName]
    local dirIdx = frameConfig and frameConfig.growDirection or 1
    if dirIdx < 1 or dirIdx > 4 then dirIdx = 1 end
    local maxCols = frameConfig and frameConfig.columns or 8
    if type(maxCols) ~= "number" or maxCols < 1 then maxCols = 8 end

    -- 職業能量框架作為獨立資源容器錨點，不套用單一列表隱藏邏輯
    if frameName == "classPower" then
        parent:Show()
        fState.layoutDirty = false
        fState.layoutBlocked = false
        return true, "classPowerAnchor"
    end

    if count > 1 then
        table.sort(fState.order, function(idA, idB)
            local iconA = fState.icons[idA]
            local iconB = fState.icons[idB]
            local orderA = (iconA and iconA.alertOrder) or 9999
            local orderB = (iconB and iconB.alertOrder) or 9999
            if orderA ~= orderB then
                return orderA < orderB
            end
            local numA = tonumber(string.match(tostring(idA), "(%d+)")) or 0
            local numB = tonumber(string.match(tostring(idB), "(%d+)")) or 0
            if numA ~= numB then
                return numA < numB
            end
            return tostring(idA) < tostring(idB)
        end)
    end

    parent:Hide()
    local layoutIndex = 0
    for index = 1, count do
        local id = fState.order[index]
        local icon = fState.icons[id]
        if icon and not icon.isParasite then
            layoutIndex = layoutIndex + 1
            local rendered = icon.rendered

            -- 計算 2D 網格欄列 (col, row)
            local itemIdx = layoutIndex - 1
            local col = itemIdx % maxCols
            local row = math.floor(itemIdx / maxCols)

            local offsetX, offsetY
            if dirIdx == 1 then -- RIGHT (向右排列，超過 maxCols 欄則向下換列)
                offsetX = col * (size + spacing)
                offsetY = -row * (size + vSpacing)
            elseif dirIdx == 2 then -- LEFT (向左排列，超過 maxCols 欄則向下換列)
                offsetX = -col * (size + spacing)
                offsetY = -row * (size + vSpacing)
            elseif dirIdx == 3 then -- UP (向上排列，超過 maxCols 列則向右開行)
                offsetX = row * (size + spacing)
                offsetY = col * (size + vSpacing)
            elseif dirIdx == 4 then -- DOWN (向下排列，超過 maxCols 列則向右開行)
                offsetX = row * (size + spacing)
                offsetY = -col * (size + vSpacing)
            end

            local hasNoPoints = (type(icon.GetNumPoints) == "function" and icon:GetNumPoints() == 0)
            if hasNoPoints or rendered.layoutX ~= offsetX or rendered.layoutY ~= offsetY or rendered.layoutSize ~= size then
                icon:ClearAllPoints()
                icon:SetPoint("CENTER", parent, "CENTER", offsetX, offsetY)
                icon:SetSize(size, size)
                rendered.layoutX = offsetX
                rendered.layoutY = offsetY
                rendered.layoutSize = size
            end
            if type(icon.IsShown) == "function" and not icon:IsShown() and type(icon.Show) == "function" then
                icon:Show()
            end
            local realAlpha = (type(icon.GetAlpha) == "function" and icon:GetAlpha()) or 0
            if rendered.layoutAlpha ~= alpha or math.abs(realAlpha - alpha) > 0.01 then
                if type(icon.SetAlpha) == "function" then
                    icon:SetAlpha(alpha)
                end
                rendered.layoutAlpha = alpha
            end
        end
    end

    -- 根據成長方向與圖示數量重調父框架大小
    if layoutIndex > 0 then
        local numCols = math.min(layoutIndex, maxCols)
        local numRows = math.ceil(layoutIndex / maxCols)
        local totalSpanX, totalSpanY
        if dirIdx == 1 or dirIdx == 2 then
            totalSpanX = (numCols * size) + ((numCols - 1) * spacing)
            totalSpanY = (numRows * size) + ((numRows - 1) * vSpacing)
        else
            totalSpanX = (numRows * size) + ((numRows - 1) * spacing)
            totalSpanY = (numCols * size) + ((numCols - 1) * vSpacing)
        end
        parent:SetSize(math.max(size, totalSpanX), math.max(size, totalSpanY))
        parent:Show()
    else
        parent:SetSize(size, size)
        parent:Hide()
    end

    fState.layoutDirty = false
    fState.layoutBlocked = false
    Renderer.checkEscFrameState()
    if Renderer.activeAnchorMap and Renderer.activeAnchorMap[frameName] then
        Renderer.refreshPreviewLayout()
    end
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

function Renderer.prewarmAlertFrames()
    if inCombat() then return end
    local savedVariables = EAM.Modules and EAM.Modules.SavedVariables
    local alerts = (savedVariables and savedVariables.getActiveAlerts and savedVariables.getActiveAlerts(EAM.db))
        or (EAM.db and EAM.db.alerts)
    if not alerts then return end

    local frameTypes = {
        spellCooldowns = EAM.Constants.ALERT_FRAME_TYPES.spellCooldown or "spellCooldown",
        itemCooldowns = EAM.Constants.ALERT_FRAME_TYPES.itemCooldown or "itemCooldown",
        groundEffects = EAM.Constants.ALERT_FRAME_TYPES.groundEffect or "groundEffect",
    }

    for alertType, fName in pairs(frameTypes) do
        local list = alerts[alertType]
        if list and type(list) == "table" then
            local parent = ensureParent(fName)
            local fState = initFrameState(fName)

            -- 1. 建立當前有效且已啟用的 alert 映射
            local activeAlerts = {}
            for _, alert in pairs(list) do
                if alert and alert.id and alert.enabled ~= false then
                    activeAlerts[alert.id] = alert
                end
            end

            -- 2. 清理已被停用 (enabled == false) 或自清單刪除的舊 Frame
            local newOrder = {}
            for i = 1, fState.orderCount do
                local id = fState.order[i]
                local alert = activeAlerts[id]
                if not alert then
                    local icon = fState.icons[id]
                    if icon then
                        if icon.SetAlpha then pcall(icon.SetAlpha, icon, 0) end
                        pcall(icon.Hide, icon)
                        IconPool.release(icon)
                        fState.icons[id] = nil
                        fState.layoutDirty = true
                    end
                else
                    newOrder[#newOrder + 1] = id
                    local icon = fState.icons[id]
                    if icon then
                        icon.alertOrder = alert.order
                    end
                end
            end
            fState.order = newOrder
            fState.orderCount = #newOrder

            -- 3. 為已啟用且尚未持有 Frame 的項目預熱 (僅常駐 Frame 備用，不加入排版 order)
            for _, alert in pairs(list) do
                if alert and alert.id and alert.enabled ~= false and not fState.icons[alert.id] then
                    local icon = IconPool.acquire()
                    if icon then
                        icon:SetParent(parent)
                        fState.icons[alert.id] = icon
                        icon.alertOrder = alert.order
                        icon:SetAlpha(0)
                        icon.isParasite = false
                        icon:ClearAllPoints()
                        icon:SetPoint("CENTER", parent, "CENTER", 0, 0)
                        local currentSize = EAM.db and EAM.db.config and EAM.db.config.iconSize or Renderer.iconSize or 40
                        icon:SetSize(currentSize, currentSize)
                        if not icon.rendered then
                            icon.rendered = {}
                        end
                        icon.rendered.layoutAlpha = 0
                        icon.rendered.layoutX = nil
                        icon.rendered.layoutY = nil
                        icon.rendered.layoutSize = nil
                        icon:Hide()
                    end
                end
            end
            if fState.layoutDirty then
                layout(fName)
            end
        end
    end
end

function Renderer.suppressAlerts(reason)
    Renderer.isAlertsSuppressed = true
    for fName, fState in pairs(Renderer.frames) do
        if fState and fState.icons then
            for _, icon in pairs(fState.icons) do
                if icon and icon.GetAlpha and icon.SetAlpha then
                    local currentAlpha = icon:GetAlpha()
                    if currentAlpha > 0 then
                        icon._eamPreSuppressAlpha = currentAlpha
                        pcall(icon.SetAlpha, icon, 0)
                    end
                end
            end
        end
    end
    local nativeService = EAM.Services and EAM.Services.AuraContainerService
    if nativeService and nativeService.current then
        if nativeService.current.player and nativeService.current.player.SetAlpha then
            pcall(nativeService.current.player.SetAlpha, nativeService.current.player, 0)
        end
        if nativeService.current.target and nativeService.current.target.SetAlpha then
            pcall(nativeService.current.target.SetAlpha, nativeService.current.target, 0)
        end
    end
    if Renderer.escCloseFrame and Renderer.escCloseFrame.Hide then
        Renderer.escCloseFrame.suppressOnHide = true
        pcall(Renderer.escCloseFrame.Hide, Renderer.escCloseFrame)
        Renderer.escCloseFrame.suppressOnHide = nil
    end
end

function Renderer.unsuppressAlerts(reason)
    if not Renderer.isAlertsSuppressed then
        return
    end
    Renderer.isAlertsSuppressed = false
    for fName, fState in pairs(Renderer.frames) do
        if fState and fState.icons then
            for _, icon in pairs(fState.icons) do
                if icon and icon.SetAlpha and icon._eamPreSuppressAlpha then
                    pcall(icon.SetAlpha, icon, icon._eamPreSuppressAlpha)
                    icon._eamPreSuppressAlpha = nil
                end
            end
        end
    end
    local nativeService = EAM.Services and EAM.Services.AuraContainerService
    if nativeService and nativeService.current then
        if nativeService.current.player and nativeService.current.player.SetAlpha then
            pcall(nativeService.current.player.SetAlpha, nativeService.current.player, 1)
        end
        if nativeService.current.target and nativeService.current.target.SetAlpha then
            pcall(nativeService.current.target.SetAlpha, nativeService.current.target, 1)
        end
    end
    Renderer.checkEscFrameState()
end

local function ensureEscCloseFrame()
    if Renderer.escCloseFrame then
        return Renderer.escCloseFrame
    end
    if inCombat() then
        return nil
    end
    if api.CreateFrame then
        local escFrame = api.CreateFrame("Frame", "EAM_EscAlertCloseFrame", UIParent)
        if escFrame then
            if escFrame.SetSize then escFrame:SetSize(1, 1) end
            if escFrame.SetPoint then escFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0) end
            if escFrame.Hide then escFrame:Hide() end
            if escFrame.SetScript then
                escFrame:SetScript("OnHide", function(self)
                    if self.suppressOnHide then return end
                    Renderer.suppressAlerts("ESC_KEY")
                end)
            end
            _G["EAM_EscAlertCloseFrame"] = escFrame
            if type(UISpecialFrames) == "table" then
                table.insert(UISpecialFrames, "EAM_EscAlertCloseFrame")
            end
            Renderer.escCloseFrame = escFrame
        end
    end
    return Renderer.escCloseFrame
end

function Renderer.checkEscFrameState()
    local config = EAM.db and EAM.db.config
    if not config or config.allowEscCancel ~= true then
        if Renderer.escCloseFrame and Renderer.escCloseFrame.IsShown and Renderer.escCloseFrame:IsShown() then
            Renderer.escCloseFrame.suppressOnHide = true
            pcall(Renderer.escCloseFrame.Hide, Renderer.escCloseFrame)
            Renderer.escCloseFrame.suppressOnHide = nil
        end
        return
    end

    if Renderer.isAlertsSuppressed then
        if Renderer.escCloseFrame and Renderer.escCloseFrame.IsShown and Renderer.escCloseFrame:IsShown() then
            Renderer.escCloseFrame.suppressOnHide = true
            pcall(Renderer.escCloseFrame.Hide, Renderer.escCloseFrame)
            Renderer.escCloseFrame.suppressOnHide = nil
        end
        return
    end

    local hasVisibleAlerts = false
    for fName, fState in pairs(Renderer.frames) do
        if fState and fState.icons then
            for _, icon in pairs(fState.icons) do
                if icon and icon.GetAlpha and icon:GetAlpha() > 0 then
                    hasVisibleAlerts = true
                    break
                end
            end
        end
        if hasVisibleAlerts then break end
    end

    if not hasVisibleAlerts then
        local nativeService = EAM.Services and EAM.Services.AuraContainerService
        if nativeService and nativeService.current and (nativeService.current.player or nativeService.current.target) then
            hasVisibleAlerts = true
        end
    end

    local escFrame = ensureEscCloseFrame()
    if escFrame then
        if hasVisibleAlerts then
            if not escFrame:IsShown() then
                pcall(escFrame.Show, escFrame)
            end
        else
            if escFrame:IsShown() then
                escFrame.suppressOnHide = true
                pcall(escFrame.Hide, escFrame)
                escFrame.suppressOnHide = nil
            end
        end
    end
end

function Renderer.applyTimerColorChanged()
    local tcc = EAM.db and EAM.db.config and EAM.db.config.timerColorCurve
    local normalColor = (tcc and tcc.normalColor) or { 1, 1, 1, 1 }
    for _, fState in pairs(Renderer.frames) do
        if fState and fState.icons then
            for _, icon in pairs(fState.icons) do
                if icon and icon.timerText and not icon.timerBinding then
                    if icon.timerText.SetTextColor then
                        icon.timerText:SetTextColor(normalColor[1] or 1, normalColor[2] or 1, normalColor[3] or 1, normalColor[4] or 1)
                    end
                end
            end
        end
    end
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

    Renderer.prewarmAlertFrames()

    -- 建立 ESC 關閉提示監聽 Frame 並註冊至 UISpecialFrames
    if not inCombat() then
        ensureEscCloseFrame()
    end

    local router = EAM.Modules.EventRouter
    if router then
        router.register("PLAYER_REGEN_ENABLED", Renderer.onCombatEnd)
        router.register("PLAYER_REGEN_DISABLED", function()
            Renderer.unsuppressAlerts("COMBAT_START")
        end)
        router.register("EAM_FONT_FAMILY_CHANGED", function()
            Renderer.applyTextLayout()
        end)
        router.register("EAM_TIMER_COLOR_CHANGED", function()
            Renderer.applyTimerColorChanged()
        end)
    end
end

-- 主要渲染入口
function Renderer.render(alertState, frameName)
    if EAM.recordHotPath then
        EAM.recordHotPath("Renderer.render")
    end
    -- 降級守衛：如果沒有指定框架，則預設歸入自身光環
    frameName = frameName or EAM.Constants.ALERT_FRAME_TYPES.selfAura

    if EAM.addDebugLog then
        EAM.addDebugLog("Renderer", "render", "Rendering id=" .. tostring(alertState and alertState.id) .. ", frame=" .. frameName .. ", active=" .. tostring(alertState and alertState.active) .. ", shown=" .. tostring(alertState and alertState.shown))
    end

    if not alertState or not alertState.id then
        return
    end

    if alertState.shown == true and Renderer.isAlertsSuppressed then
        Renderer.unsuppressAlerts("NEW_ALERT")
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

    -- 圖示隱藏/釋放處理 (冷卻與地面效果類型框架透過透明度 Alpha = 0 隱藏，保持 Frame 結構常駐)
    if not alertState.shown then
        local isCooldownFrame = (frameName == "spellCooldown" or frameName == "itemCooldown" or frameName == "groundEffect")
        if not icon and isCooldownFrame and not inCombat() and alertState.rawAlert and alertState.rawAlert.enabled ~= false then
            icon = IconPool.acquire()
            if icon then
                local parent = ensureParent(frameName)
                icon:SetParent(parent)
                fState.icons[alertState.id] = icon
                icon.alertOrder = alertState.order or alertState.rawAlert.order
                icon:SetAlpha(0)
                if icon.rendered then icon.rendered.layoutAlpha = 0 end
                icon:Hide()
            end
        end
        if icon then
            if isCooldownFrame then
                -- 若該冷卻項目已被停用 (enabled == false)，徹底自排版與圖示池清理釋放
                if alertState.rawAlert and alertState.rawAlert.enabled == false then
                    if icon.SetAlpha then pcall(icon.SetAlpha, icon, 0) end
                    pcall(icon.Hide, icon)
                    IconPool.release(icon)
                    fState.icons[alertState.id] = nil
                    local oIdx = 1
                    while oIdx <= fState.orderCount do
                        if fState.order[oIdx] == alertState.id then
                            table.remove(fState.order, oIdx)
                            fState.orderCount = fState.orderCount - 1
                        else
                            oIdx = oIdx + 1
                        end
                    end
                    fState.layoutDirty = true
                    if not isBatching then
                        layout(frameName)
                    else
                        batchDirtyFrames[frameName] = true
                    end
                    return
                end

                -- 若該冷卻圖示在排版順序中，將其自 order 移除，保證畫面不留空格
                local wasInOrder = false
                local oIdx = 1
                while oIdx <= fState.orderCount do
                    if fState.order[oIdx] == alertState.id then
                        table.remove(fState.order, oIdx)
                        fState.orderCount = fState.orderCount - 1
                        fState.layoutDirty = true
                        wasInOrder = true
                    else
                        oIdx = oIdx + 1
                    end
                end

                if icon.SetAlpha then pcall(icon.SetAlpha, icon, 0) end
                pcall(icon.Hide, icon)
                if icon.rendered then
                    icon.rendered.layoutAlpha = 0
                    icon.rendered.isShown = false
                end
                if icon.cooldown then
                    local setCooldown = icon.cooldown.SetCooldown
                    if setCooldown then pcall(setCooldown, icon.cooldown, 0, 0) end
                    pcall(icon.cooldown.Hide, icon.cooldown)
                end
                if icon.timerBinding then
                    local adapter = EAM.Modules.DurationAdapter
                    if adapter then adapter.releaseTextBinding(icon.timerBinding) end
                    icon.timerBinding = nil
                end
                if Renderer.unregisterLegacyTimer then
                    Renderer.unregisterLegacyTimer(icon)
                end
                if icon.timerText then
                    if icon.timerText.ClearText then icon.timerText:ClearText() else icon.timerText:SetText("") end
                end
                if icon.stackText then
                    if icon.stackText.ClearText then icon.stackText:ClearText() else icon.stackText:SetText("") end
                end
                IconPool.setGlow(icon, false)
                if icon.popAnimation and icon.popAnimation.Stop then pcall(icon.popAnimation.Stop, icon.popAnimation) end
                if icon.pandemicAnimation and icon.pandemicAnimation.Stop then pcall(icon.pandemicAnimation.Stop, icon.pandemicAnimation) end
                if wasInOrder then
                    if not isBatching then
                        layout(frameName)
                    else
                        batchDirtyFrames[frameName] = true
                    end
                end
                Renderer.checkEscFrameState()
                return
            end

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
            local oIdx = 1
            while oIdx <= fState.orderCount do
                if fState.order[oIdx] == alertState.id then
                    table.remove(fState.order, oIdx)
                    fState.orderCount = fState.orderCount - 1
                else
                    oIdx = oIdx + 1
                end
            end
            if icon.isParasite then
                icon:SetParent(UIParent)
                icon.isParasite = nil
            end
            IconPool.release(icon)
            if not isBatching then
                Renderer.requestLayout(frameName)
            else
                batchDirtyFrames[frameName] = true
            end
            Renderer.checkEscFrameState()
        else
            local wasInOrder = false
            local oIdx = 1
            while oIdx <= fState.orderCount do
                if fState.order[oIdx] == alertState.id then
                    table.remove(fState.order, oIdx)
                    fState.orderCount = fState.orderCount - 1
                    wasInOrder = true
                else
                    oIdx = oIdx + 1
                end
            end
            if wasInOrder then
                fState.layoutDirty = true
                if not isBatching then
                    Renderer.requestLayout(frameName)
                else
                    batchDirtyFrames[frameName] = true
                end
            end
        end
        return
    end

    -- 圖示獲取前置檢查：若圖示尚未建立且處於戰鬥中，延後渲染以防 Taint
    if not icon and inCombat() then
        fState.layoutDirty = true
        fState.layoutBlocked = true
        deferRender(alertState, frameName)
        return false, "combatDeferred"
    end

    -- 圖示獲取與初始化
    if not icon then
        icon = IconPool.acquire()
        if not icon then
            if inCombat() then
                deferRender(alertState, frameName)
            end
            return
        end
        fState.icons[alertState.id] = icon
        icon.isParasite = false
    end

    -- 確保 icon 存在於 fState.order 排版清單中
    local inOrder = false
    for i = 1, fState.orderCount do
        if fState.order[i] == alertState.id then
            inOrder = true
            break
        end
    end
    if not inOrder then
        fState.orderCount = fState.orderCount + 1
        fState.order[fState.orderCount] = alertState.id
        icon.alertOrder = alertState.order or (alertState.rawAlert and alertState.rawAlert.order)
        fState.layoutDirty = true
    else
        local targetOrder = alertState.order or (alertState.rawAlert and alertState.rawAlert.order)
        if targetOrder and icon.alertOrder ~= targetOrder then
            icon.alertOrder = targetOrder
            fState.layoutDirty = true
        end
    end

    local hostIcon = nil
    local shouldBeParasite = (hostIcon ~= nil)
    local rendered = icon.rendered
    if not rendered then
        icon.rendered = {}
        rendered = icon.rendered
    end

    local currentIsParasite = (icon.isParasite == true)
    if currentIsParasite ~= shouldBeParasite then
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
            rendered.layoutX = nil
            rendered.layoutY = nil
            rendered.layoutSize = nil
            fState.layoutDirty = true
        end
    else
        rendered.parasiteLayoutPending = nil
    end

    local newAlertOrder = alertState.order or (alertState.rawAlert and alertState.rawAlert.order) or nil
    if icon.alertOrder ~= newAlertOrder then
        icon.alertOrder = newAlertOrder
        fState.layoutDirty = true
    end

    local iconTex = alertState.icon
    if (not iconTex or iconTex == 136243) and alertState.spellID then
        local cSpell = api.C_Spell or C_Spell
        if cSpell and type(cSpell.GetSpellTexture) == "function" then
            local ok, sTex = pcall(cSpell.GetSpellTexture, alertState.spellID)
            if ok and Util.isSafePositiveNumber(sTex) then
                iconTex = sTex
            end
        end
        if (not iconTex or iconTex == 136243) and cSpell and type(cSpell.GetBaseSpell) == "function" then
            local okBase, baseID = pcall(cSpell.GetBaseSpell, alertState.spellID)
            if okBase and Util.isSafePositiveNumber(baseID) and type(cSpell.GetSpellTexture) == "function" then
                local ok, bTex = pcall(cSpell.GetSpellTexture, baseID)
                if ok and Util.isSafePositiveNumber(bTex) then
                    iconTex = bTex
                end
            end
        end
    end
    if iconTex and rendered.icon ~= iconTex and icon.texture then
        icon.texture:SetTexture(iconTex)
        rendered.icon = iconTex
    end

    local isPlaceholder = (alertState.isPlaceholder == true) or (alertState.isDesaturated == true)
    if icon.texture then
        if isPlaceholder then
            if icon.texture.SetDesaturated then icon.texture:SetDesaturated(true) end
            if icon.texture.SetVertexColor then icon.texture:SetVertexColor(0.4, 0.4, 0.4, 0.65) end
        else
            if icon.texture.SetDesaturated then icon.texture:SetDesaturated(false) end
            if icon.texture.SetVertexColor then icon.texture:SetVertexColor(1, 1, 1, 1) end
        end
    end

    IconPool.applyTooltipSource(icon, alertState)
    IconPool.applyTypeBorder(icon, alertState, frameName)
    if isPlaceholder and icon.typeBorder then
        icon.typeBorder:Hide()
    end

    local config = EAM.db and EAM.db.config or nil
    if inCombat() then
        Renderer.textLayoutPending = true
    else
        applyTextLayoutToIcon(icon, config)
    end
    IconPool.applyCooldownStyle(icon, config)

    local chargeText = formatChargeText(alertState)
    if chargeText ~= nil then
        setTextIfChanged(icon.stackText, rendered, "stacks", chargeText)
    elseif alertState.absorbAmount then
        local absorb = alertState.absorbAmount
        local isSecretAbsorb = Util.isSecretValue and Util.isSecretValue(absorb)
        if isSecretAbsorb then
            if icon.stackText and icon.stackText.SetFormattedText then
                pcall(icon.stackText.SetFormattedText, icon.stackText, "%d", absorb)
                rendered["stacks"] = "SECRET_ABSORB"
            else
                setTextIfChanged(icon.stackText, rendered, "stacks", "")
            end
        elseif Util.isSafePositiveNumber(absorb) then
            local absStr = formatAbsorbAmount(absorb)
            if alertState.stacks and Util.isSafeNumber(alertState.stacks) and alertState.stacks > 1 then
                setTextIfChanged(icon.stackText, rendered, "stacks", tostring(alertState.stacks) .. "(" .. absStr .. ")")
            else
                setTextIfChanged(icon.stackText, rendered, "stacks", absStr)
            end
        else
            setTextIfChanged(icon.stackText, rendered, "stacks", "")
        end
    else
        local val = alertState.displayValue ~= nil and alertState.displayValue or alertState.stacks
        local isSecretVal = Util.isSecretValue and Util.isSecretValue(val)
        if isSecretVal then
            if icon.stackText and icon.stackText.SetFormattedText then
                pcall(icon.stackText.SetFormattedText, icon.stackText, "%d", val)
                rendered["stacks"] = "SECRET_VALUE"
            else
                setTextIfChanged(icon.stackText, rendered, "stacks", "")
            end
        else
            local stacks = ""
            if val ~= nil and Util.canAccessValue(val) then
                if alertState.displayValue ~= nil then
                    stacks = Util.isSafeNonNegativeNumber(val) and tostring(val) or ""
                else
                    stacks = (Util.isSafeNumber(val) and val > 1) and tostring(val) or ""
                end
            end
            setTextIfChanged(icon.stackText, rendered, "stacks", stacks)
        end
    end

    local raw = alertState.rawAlert
    local showStacks = true
    if raw and raw.showStacks ~= nil then
        showStacks = raw.showStacks ~= false
    end
    if not showStacks and icon.stackText and type(icon.stackText.Hide) == "function" then
        icon.stackText:Hide()
    elseif showStacks and icon.stackText and type(icon.stackText.Show) == "function" and rendered.stacks and rendered.stacks ~= "" then
        icon.stackText:Show()
    end

    local nameInside = shouldBeParasite
    local currentPlacement = TextPlacement.getPlacement(config, "spellName") or "OUTSIDE_BOTTOM"
    if rendered.nameInside ~= nameInside or (not nameInside and rendered.spellNamePlacement ~= currentPlacement) then
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

    local name = (raw and raw.customName and raw.customName ~= "" and raw.customName) or alertState.name or ""
    if (name == "" or name == "地面技能") and alertState.spellID then
        local cSpell = api.C_Spell or C_Spell
        if cSpell and type(cSpell.GetSpellName) == "function" then
            local ok, sName = pcall(cSpell.GetSpellName, alertState.spellID)
            if ok and Util.isSafeString(sName) and sName ~= "" then
                name = sName
            end
        end
        if (name == "" or name == "地面技能") and cSpell and type(cSpell.GetBaseSpell) == "function" then
            local okBase, baseID = pcall(cSpell.GetBaseSpell, alertState.spellID)
            if okBase and Util.isSafePositiveNumber(baseID) and type(cSpell.GetSpellName) == "function" then
                local ok, bName = pcall(cSpell.GetSpellName, baseID)
                if ok and Util.isSafeString(bName) and bName ~= "" then
                    name = bName
                end
            end
        end
    end
    local showSpellName = not config or config.showSpellName ~= false
    if raw and raw.showName ~= nil then
        showSpellName = raw.showName ~= false
    end
    if showSpellName and name ~= "" then
        setTextIfChanged(icon.nameText, rendered, "name", name)
        if icon.nameText and type(icon.nameText.Show) == "function" and (type(icon.nameText.IsShown) ~= "function" or not icon.nameText:IsShown()) then
            icon.nameText:Show()
        end
    else
        setTextIfChanged(icon.nameText, rendered, "name", "")
        if icon.nameText and type(icon.nameText.Hide) == "function" and (type(icon.nameText.IsShown) ~= "function" or icon.nameText:IsShown()) then
            icon.nameText:Hide()
        end
    end

    -- Cooldown 與 DurationObject 倒數雙軌管道渲染
    local timer = alertState.timer
    local useNativeBinding = timer and timer.durationObject and DurationAdapter ~= nil

    local spellRedLimit = alertState.countdownRedLimit or (raw and raw.countdownRedLimit)
    local spellRedColor = alertState.countdownRedColor or (raw and raw.countdownRedColor)
    local hasSpellRedLimit = Util.isSafeNumber(spellRedLimit) and spellRedLimit > 0

    if useNativeBinding then
        if icon.cooldown and type(icon.cooldown.Show) == "function" then
            icon.cooldown:Show()
        end
        local curveToApply = nil
        if hasSpellRedLimit and DurationAdapter.buildSpellColorCurve then
            curveToApply = DurationAdapter.buildSpellColorCurve(spellRedLimit, spellRedColor)
        end

        if rendered.durationObject ~= timer.durationObject
            or rendered.countdownRedLimit ~= spellRedLimit
            or rendered.countdownRedColor ~= spellRedColor
        then
            releaseTimerBinding(icon)
            icon.timerBinding = DurationAdapter.createTextBinding(timer.durationObject, icon.timerText, curveToApply)
            
            local curveMode = EAM.db and EAM.db.config and EAM.db.config.cooldownProgressCurve
            local progressCurve = DurationAdapter.buildNonLinearProgressCurve and DurationAdapter.buildNonLinearProgressCurve(curveMode)
            if icon.cooldown.SetProgressCurve and progressCurve then
                pcall(icon.cooldown.SetProgressCurve, icon.cooldown, progressCurve)
            end

            if icon.cooldown.SetCooldownDuration and progressCurve then
                local ok = pcall(icon.cooldown.SetCooldownDuration, icon.cooldown, timer.durationObject, progressCurve)
                if not ok and icon.cooldown.SetCooldownFromDurationObject then
                    icon.cooldown:SetCooldownFromDurationObject(timer.durationObject)
                end
            elseif icon.cooldown.SetCooldownFromDurationObject then
                icon.cooldown:SetCooldownFromDurationObject(timer.durationObject)
            elseif timer.startTime and timer.duration then
                icon.cooldown:SetCooldown(timer.startTime, timer.duration)
            else
                icon.cooldown:SetCooldown(0, 0)
            end

            rendered.durationObject = timer.durationObject
            rendered.durationBindingAvailable = icon.timerBinding ~= nil
            rendered.countdownRedLimit = spellRedLimit
            rendered.countdownRedColor = spellRedColor
            rendered.cooldownStart = nil
            rendered.cooldownDuration = nil
        end
        if icon.timerBinding then
            Renderer.unregisterLegacyTimer(icon)
        elseif Util.isSafeNumber(timer.expirationTime) then
            icon.countdownRedLimit = hasSpellRedLimit and spellRedLimit or nil
            icon.countdownRedColor = hasSpellRedLimit and spellRedColor or nil
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
            icon.countdownRedLimit = hasSpellRedLimit and spellRedLimit or nil
            icon.countdownRedColor = hasSpellRedLimit and spellRedColor or nil
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

    local showTimeVal = not config or config.showTimeVal ~= false
    if raw and raw.showCountdown ~= nil then
        showTimeVal = raw.showCountdown ~= false
    end
    if icon.timerText then
        if not showTimeVal then
            if type(icon.timerText.Hide) == "function" then
                icon.timerText:Hide()
            end
        else
            local hasBinding = rawget(icon, "timerBinding") ~= nil
            local expTime = timer and Util.isSafeNumber(timer.expirationTime) and timer.expirationTime > 0
            if (hasBinding or expTime) and type(icon.timerText.Show) == "function" then
                icon.timerText:Show()
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

    if alertState.isChargeBased == true then
        if IconPool and type(IconPool.applyChargeProgress) == "function" then
            IconPool.applyChargeProgress(icon, alertState)
        end
    else
        if IconPool and type(IconPool.applyAuraApplicationProgress) == "function" then
            IconPool.applyAuraApplicationProgress(icon, alertState)
        end
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

    -- 🌡️ GPU 原生硬體加速動畫：Pandemic 呼吸動態控制
    if icon.pandemicAnimation then
        local isPlaying = icon.pandemicAnimation.IsPlaying and icon.pandemicAnimation:IsPlaying()
        if alertState.pandemicReady then
            if not isPlaying and icon.pandemicAnimation.Play then
                pcall(icon.pandemicAnimation.Play, icon.pandemicAnimation)
            end
        else
            if isPlaying and icon.pandemicAnimation.Stop then
                pcall(icon.pandemicAnimation.Stop, icon.pandemicAnimation)
            end
        end
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

    local targetAlpha = config and config.iconAlpha or 1.0
    if icon.SetAlpha then pcall(icon.SetAlpha, icon, targetAlpha) end
    if icon.Show then icon:Show() end
    rendered.layoutAlpha = targetAlpha
    icon.alertState = alertState

    -- 🚀 GPU 原生硬體加速動畫：圖示觸發 Pop 彈跳
    local wasShown = rendered.isShown
    rendered.isShown = true
    if not wasShown and icon.popAnimation and icon.popAnimation.Play then
        pcall(icon.popAnimation.Play, icon.popAnimation)
    end
    if fState.parent and not fState.parent:IsShown() then
        fState.parent:Show()
    end
    if not inCombat() and fState.parent and (not fState.parent:IsShown() or rendered.layoutX == nil) then
        fState.layoutDirty = true
    end
    if fState.layoutDirty then
        if isBatching then
            batchDirtyFrames[frameName] = true
        else
            Renderer.requestLayout(frameName)
        end
    end
    Renderer.checkEscFrameState()
end

function Renderer.clearFrame(frameName)
    if EAM.recordHotPath then
        EAM.recordHotPath("Renderer.clearFrame")
    end
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
            break
        end
    end

    -- 徹底釋放所有殘餘未在 order 中的圖示與狀態 (防範孤兒 Frame 與未釋放 TimerBinding)
    if frameState.icons then
        for id, icon in pairs(frameState.icons) do
            if icon then
                frameState.icons[id] = nil
                if icon.isParasite then
                    icon:SetParent(UIParent)
                    icon.isParasite = nil
                end
                IconPool.release(icon)
            end
        end
        wipe(frameState.icons)
    end
    if frameState.order then
        wipe(frameState.order)
    end
    frameState.orderCount = 0
    frameState.layoutDirty = true
    if not isBatching then
        Renderer.requestLayout(frameName)
    else
        batchDirtyFrames[frameName] = true
    end
    Renderer.checkEscFrameState()
    return true, "cleared"
end

-- 離開戰鬥時，將戰鬥中被阻攔的渲染與 Layout 變更安全地釋放執行
function Renderer.onCombatEnd()
    -- 戰鬥結束後，重新嘗試確保所有框架 parent 已成功建立
    for fName in pairs(EAM.Constants.ALERT_FRAME_TYPES) do
        ensureParent(fName)
    end
    ensureEscCloseFrame()

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
    Renderer.prewarmAlertFrames()
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
    petAlert = {
        title = "EAM - 寵物監控框架",
        slots = {
            { text = "寵物Buff/CD(1)", step = 0, isPet = true, sampleStack = 3, sampleCD = 8 },
            { text = "寵物Debuff(2)", step = 1, isPet = true, isDebuff = true, sampleStack = nil, sampleCD = 12 },
        }
    },
}

local function getFrameDisplayName(fName)
    local labels = {
        selfAura = EAM.L.EAM_FRAME_SELF_AURA or "EAM - 自身光環框架",
        targetAura = EAM.L.EAM_FRAME_TARGET_AURA or "EAM - 目標光環框架",
        spellCooldown = EAM.L.EAM_FRAME_SPELL_COOLDOWN or "EAM - 技能冷卻框架",
        itemCooldown = EAM.L.EAM_FRAME_ITEM_COOLDOWN or "EAM - 物品冷卻框架",
        classPower = EAM.L.EAM_FRAME_CLASS_POWER or "EAM - 職業能量框架",
        groundEffect = EAM.L.EAM_FRAME_GROUND_EFFECT or "EAM - 地面效果框架",
        totem = EAM.L.EAM_FRAME_TOTEM or "EAM - 圖騰監控框架",
        playerStat = EAM.L.EAM_FRAME_PLAYER_STAT or "EAM - 角色屬性與吸收量框架",
        petAlert = EAM.L.EAM_FRAME_PET_ALERT or "EAM - 寵物監控框架",
    }
    return labels[fName] or fName
end

local function showMoverHUD(moverFrame, text)
    if not moverFrame then return end
    local hud = rawget(moverFrame, "hudFrame")
    if not hud then
        hud = api.CreateFrame("Frame", nil, moverFrame, "BackdropTemplate")
        hud:SetFrameStrata("TOOLTIP")
        hud:SetSize(240, 36)
        hud:SetPoint("CENTER", moverFrame, "CENTER", 0, 0)
        hud:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 12, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        hud:SetBackdropColor(0.04, 0.08, 0.05, 0.92)
        hud:SetBackdropBorderColor(0.2, 1.0, 0.4, 0.95)
        local str = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
        str:SetPoint("CENTER", hud, "CENTER", 0, 0)
        str:SetTextColor(1, 0.88, 0.25, 1)
        rawset(hud, "text", str)
        rawset(moverFrame, "hudFrame", hud)
    end
    local hudText = rawget(hud, "text")
    if hudText then hudText:SetText(text) end
    hud:Show()
    hud.hideTimer = 1.6
    hud:SetScript("OnUpdate", function(self, elapsed)
        self.hideTimer = (self.hideTimer or 1.6) - elapsed
        if self.hideTimer <= 0 then
            self:Hide()
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local function safeCall(obj, method, ...)
    if not obj then return nil end
    local success, fn = pcall(function() return obj[method] end)
    if success and type(fn) == "function" then
        local ok, ret = pcall(fn, obj, ...)
        if ok then return ret end
    end
    return nil
end

local function saveFrameCenterPosition(parent, pName, fLabel)
    if not parent then return end
    if type(parent.StopMovingOrSizing) == "function" then
        parent:StopMovingOrSizing()
    end
    pName = pName or rawget(parent, "frameName")
    local pCenterX, pCenterY
    if type(parent.GetCenter) == "function" then
        pCenterX, pCenterY = parent:GetCenter()
    end
    local uCenterX, uCenterY
    if UIParent and type(UIParent.GetCenter) == "function" then
        uCenterX, uCenterY = UIParent:GetCenter()
    elseif type(GetScreenWidth) == "function" and type(GetScreenHeight) == "function" then
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        if sw and sh and sw > 0 and sh > 0 then
            uCenterX = sw / 2
            uCenterY = sh / 2
        end
    end
    local xOffset = (pCenterX and uCenterX) and (pCenterX - uCenterX) or 0
    local yOffset = (pCenterY and uCenterY) and (pCenterY - uCenterY) or 0
    if not (pCenterX and uCenterX and pCenterY and uCenterY) and type(parent.GetPoint) == "function" then
        local pt, rel, relPt, curX, curY = parent:GetPoint()
        if pt == "BOTTOMLEFT" and uCenterX and uCenterY then
            local w, h = 40, 40
            if type(parent.GetSize) == "function" then
                local pw, ph = parent:GetSize()
                w = pw or 40
                h = ph or 40
            end
            xOffset = ((curX or 0) + (w or 40) / 2) - uCenterX
            yOffset = ((curY or 0) + (h or 40) / 2) - uCenterY
        else
            xOffset = curX or 0
            yOffset = curY or 0
        end
    end
    if type(parent.ClearAllPoints) == "function" then
        parent:ClearAllPoints()
    end
    if type(parent.SetPoint) == "function" then
        parent:SetPoint("CENTER", UIParent, "CENTER", xOffset, yOffset)
    end

    if EAM.db and EAM.db.layout and EAM.db.layout.frames and pName and EAM.db.layout.frames[pName] then
        local cfg = EAM.db.layout.frames[pName]
        cfg.point = "CENTER"
        cfg.x = xOffset
        cfg.y = yOffset
        if EAM.Modules and EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.markRevisionChanged then
            EAM.Modules.SavedVariables.markRevisionChanged()
        end
    end
    if EAM.Services and EAM.Services.AuraContainerService and EAM.Services.AuraContainerService.applyContainerPositions then
        EAM.Services.AuraContainerService.applyContainerPositions()
    end
    local nameLabels = {
        selfAura = (EAM.L and EAM.L.EAM_FRAME_SELF_AURA) or "EAM - 自身光環框架",
        targetAura = (EAM.L and EAM.L.EAM_FRAME_TARGET_AURA) or "EAM - 目標光環框架",
        spellCooldown = (EAM.L and EAM.L.EAM_FRAME_SPELL_COOLDOWN) or "EAM - 技能冷卻框架",
        itemCooldown = (EAM.L and EAM.L.EAM_FRAME_ITEM_COOLDOWN) or "EAM - 物品冷卻框架",
        classPower = (EAM.L and EAM.L.EAM_FRAME_CLASS_POWER) or "EAM - 職業能量框架",
        groundEffect = (EAM.L and EAM.L.EAM_FRAME_GROUND_EFFECT) or "EAM - 地面效果框架",
        totem = (EAM.L and EAM.L.EAM_FRAME_TOTEM) or "EAM - 圖騰監控框架",
        playerStat = (EAM.L and EAM.L.EAM_FRAME_PLAYER_STAT) or "EAM - 屬性與能量框架",
        petAlert = (EAM.L and EAM.L.EAM_FRAME_PET_ALERT) or "EAM - 寵物監控框架",
    }
    local fLabelStr = (pName and nameLabels[pName]) or (fLabel or pName or "AlertFrame")
    print("|cff00ff96EAM|r [" .. fLabelStr .. "] " .. string.format((EAM.L and EAM.L.EAM_FRAME_POS_SAVED) or "位置已保存: %s, X: %.1f, Y: %.1f", "CENTER", xOffset or 0, yOffset or 0))
end

local function getOrCreateMoverFrame(parent, fName, fLabel)
    local existing = rawget(parent, "moverFrame")
    if existing then
        return existing
    end

    local mover = api.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mover:SetFrameStrata("FULLSCREEN_DIALOG")
    local parentLevel = safeCall(parent, "GetFrameLevel") or 1
    safeCall(mover, "SetFrameLevel", parentLevel + 5)
    mover:EnableMouse(true)
    safeCall(mover, "EnableMouseWheel", true)
    mover:RegisterForDrag("LeftButton")
    mover:SetClampedToScreen(true)

    mover:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    -- 半透明綠色背景與鮮明綠色邊框
    mover:SetBackdropColor(0.02, 0.28, 0.12, 0.35)
    mover:SetBackdropBorderColor(0.20, 1.00, 0.45, 0.95)

    -- 頂部標題與操作指南
    local title = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("BOTTOM", mover, "TOP", 0, 4)
    title:SetTextColor(0.3, 1.0, 0.5, 1.0)
    title:SetText(string.format("[%s] (左鍵拖曳 / 右鍵完成)", fLabel or fName))
    rawset(mover, "titleText", title)

    -- 底部快捷提示
    local subHint = mover:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subHint:SetPoint("TOP", mover, "BOTTOM", 0, -4)
    subHint:SetTextColor(0.8, 0.9, 0.8, 0.9)
    subHint:SetText("[Ctrl+滾輪]水平間距  [Alt+滾輪]垂直間距  [Shift+滾輪]大小")
    rawset(mover, "subHint", subHint)

    -- 拖曳邏輯：委派至 parent 進行移動與座標儲存
    mover:SetScript("OnDragStart", function()
        parent:StartMoving()
    end)
    mover:SetScript("OnDragStop", function()
        local pName = rawget(parent, "frameName") or fName
        saveFrameCenterPosition(parent, pName, fLabel)
    end)
    mover:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and Renderer.isMoving then
            Renderer.setActiveAnchors(nil)
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_MOVE_MODE_OFF or "已關閉「多框架移動模式」並成功套用新排版。"))
        end
    end)

    -- 滾輪事件：Ctrl 調整水平間距、Alt 調整垂直間距、Shift 調整圖示大小
    mover:SetScript("OnMouseWheel", function(self, delta)
        local isCtrl = api.IsControlKeyDown and api.IsControlKeyDown()
        local isAlt = api.IsAltKeyDown and api.IsAltKeyDown()
        local isShift = api.IsShiftKeyDown and api.IsShiftKeyDown()

        if isCtrl then
            local cfg = EAM.db and EAM.db.config
            local cur = (cfg and cfg.iconSpacing) or (EAM.db and EAM.db.layout and EAM.db.layout.spacing) or 6
            local step = delta > 0 and 1 or -1
            local nextVal = math.max(0, math.min(100, cur + step))
            if cfg then cfg.iconSpacing = nextVal end
            if EAM.db and EAM.db.layout then EAM.db.layout.spacing = nextVal end
            showMoverHUD(self, string.format(EAM.L.EAM_MOVER_HUD_H_SPACING or "水平間距: %d px", nextVal))
        elseif isAlt then
            local cfg = EAM.db and EAM.db.config
            local cur = (cfg and cfg.verticalSpacing) or (EAM.db and EAM.db.layout and EAM.db.layout.verticalSpacing) or 0
            local step = delta > 0 and 1 or -1
            local nextVal = math.max(0, math.min(100, cur + step))
            if cfg then cfg.verticalSpacing = nextVal end
            if EAM.db and EAM.db.layout then EAM.db.layout.verticalSpacing = nextVal end
            showMoverHUD(self, string.format(EAM.L.EAM_MOVER_HUD_V_SPACING or "垂直間距: %d px", nextVal))
        elseif isShift then
            local cfg = EAM.db and EAM.db.config
            local cur = (cfg and cfg.iconSize) or (EAM.db and EAM.db.layout and EAM.db.layout.iconSize) or 40
            local step = delta > 0 and 2 or -2
            local nextVal = math.max(20, math.min(120, cur + step))
            if cfg then cfg.iconSize = nextVal end
            if EAM.db and EAM.db.layout then EAM.db.layout.iconSize = nextVal end
            showMoverHUD(self, string.format(EAM.L.EAM_MOVER_HUD_SIZE or "圖示大小: %d px", nextVal))
        else
            showMoverHUD(self, EAM.L.EAM_MOVER_HINT_WHEEL or "[Ctrl+滾輪] 水平間距 | [Alt+滾輪] 垂直間距 | [Shift+滾輪] 大小")
            return
        end

        if EAM.Modules and EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.markRevisionChanged then
            EAM.Modules.SavedVariables.markRevisionChanged()
        end
        if Options and Options.notifyConfigChanged then
            Options.notifyConfigChanged()
        end
        Renderer.refreshPreviewLayout()
    end)

    rawset(parent, "moverFrame", mover)
    return mover
end

function Renderer.getOrCreateMoverFrame(parentOrFrameName, fName, fLabel)
    local parent, actualFName, actualFLabel
    if type(parentOrFrameName) == "string" then
        actualFName = parentOrFrameName
        parent = ensureParent(actualFName)
        actualFLabel = fName or actualFName
    else
        parent = parentOrFrameName
        actualFName = fName
        actualFLabel = fLabel
    end
    return getOrCreateMoverFrame(parent, actualFName, actualFLabel)
end

local function getOrCreatePreviewIcon(parent, index)
    local previewIcons = rawget(parent, "previewIcons")
    if not previewIcons then
        previewIcons = {}
        rawset(parent, "previewIcons", previewIcons)
    end
    if previewIcons[index] then
        return previewIcons[index]
    end

    local icon = api.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    safeCall(icon, "SetFrameStrata", "FULLSCREEN_DIALOG")

    -- 經典奶牛頭貼圖
    local tex = icon:CreateTexture(nil, "BACKGROUND")
    safeCall(tex, "SetPoint", "TOPLEFT", icon, "TOPLEFT", 2, -2)
    safeCall(tex, "SetPoint", "BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    safeCall(tex, "SetTexture", COW_ICON)
    safeCall(tex, "SetTexCoord", 0.08, 0.92, 0.08, 0.92)
    icon.texture = tex

    -- 倒數扇形轉圈 Cooldown 框架 (即時預覽扇形倒數轉圈)
    local cd = api.CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    if cd then
        safeCall(cd, "SetAllPoints", icon)
        safeCall(cd, "SetDrawEdge", true)
        safeCall(cd, "SetDrawBling", false)
        safeCall(cd, "SetDrawSwipe", true)
        safeCall(cd, "SetReverse", true)
    end
    icon.cooldown = cd

    -- TIME LEFT / 倒數文字
    local timerText = icon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    safeCall(timerText, "SetPoint", "BOTTOM", icon, "TOP", 0, 3)
    safeCall(timerText, "SetText", "TIME LEFT")
    safeCall(timerText, "SetTextColor", 1, 1, 1, 1)
    icon.timerText = timerText

    -- 槽位說明文字 (名稱)
    local nameText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    safeCall(nameText, "SetPoint", "TOP", icon, "BOTTOM", 0, -3)
    safeCall(nameText, "SetTextColor", 1, 0.95, 0.5, 1)
    icon.nameText = nameText

    -- 堆疊層數文字
    local stackText = icon:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    safeCall(stackText, "SetPoint", "BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    safeCall(stackText, "SetTextColor", 1, 1, 1, 1)
    icon.stackText = stackText

    safeCall(icon, "SetBackdrop", {
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 0, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    -- 預覽圖示滑鼠拖曳、滾輪調節與右鍵完成支援：委派至父框架以確保點擊圖示時能正常拖曳與滾輪調節
    safeCall(icon, "EnableMouse", true)
    safeCall(icon, "EnableMouseWheel", true)
    safeCall(icon, "RegisterForDrag", "LeftButton")
    safeCall(icon, "SetScript", "OnDragStart", function(self)
        local p = self:GetParent()
        if p and p.StartMoving then
            p:StartMoving()
        end
    end)
    safeCall(icon, "SetScript", "OnDragStop", function(self)
        local p = self:GetParent()
        local mover = p and rawget(p, "moverFrame")
        if mover and mover:GetScript("OnDragStop") then
            mover:GetScript("OnDragStop")(mover)
        elseif p and p.StopMovingOrSizing then
            p:StopMovingOrSizing()
        end
    end)
    safeCall(icon, "SetScript", "OnMouseWheel", function(self, delta)
        local p = self:GetParent()
        local mover = p and rawget(p, "moverFrame")
        if mover and mover:GetScript("OnMouseWheel") then
            mover:GetScript("OnMouseWheel")(mover, delta)
        end
    end)
    icon:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and Renderer.isMoving then
            Renderer.setActiveAnchors(nil)
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_MOVE_MODE_OFF or "已關閉「多框架移動模式」並成功套用新排版。"))
        end
    end)

    previewIcons[index] = icon
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
    local swipeColor = cfg.cooldownSwipeColor or {}
    local swipeR = tonumber(swipeColor.r) or 0
    local swipeG = tonumber(swipeColor.g) or 0
    local swipeB = tonumber(swipeColor.b) or 0
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
                local fState = Renderer.frames and Renderer.frames[fName]
                local hasRealIcons = false
                local realMinX, realMaxX, realMinY, realMaxY = 0, 0, 0, 0
                local firstReal = true

                if fState and fState.order and fState.orderCount and fState.orderCount > 0 then
                    for i = 1, fState.orderCount do
                        local id = fState.order[i]
                        local icon = fState.icons and fState.icons[id]
                        if icon and not icon.isParasite then
                            local isShown = (icon.IsShown and icon:IsShown()) or (icon.rendered and icon.rendered.isShown)
                            local rAlpha = (icon.rendered and icon.rendered.layoutAlpha) or (icon.GetAlpha and icon:GetAlpha()) or 0
                            if isShown and rAlpha > 0 then
                                hasRealIcons = true
                                local ix = (icon.rendered and icon.rendered.layoutX) or 0
                                local iy = (icon.rendered and icon.rendered.layoutY) or 0
                                local isz = (icon.rendered and icon.rendered.layoutSize) or size
                                local left = ix - isz / 2
                                local right = ix + isz / 2
                                local bottom = iy - isz / 2
                                local top = iy + isz / 2
                                if firstReal then
                                    realMinX, realMaxX, realMinY, realMaxY = left, right, bottom, top
                                    firstReal = false
                                else
                                    if left < realMinX then realMinX = left end
                                    if right > realMaxX then realMaxX = right end
                                    if bottom < realMinY then realMinY = bottom end
                                    if top > realMaxY then realMaxY = top end
                                end
                            end
                        end
                    end
                end

                local minX, maxX = 0, 0
                local minY, maxY = 0, 0
                if hasRealIcons then
                    minX, maxX, minY, maxY = realMinX, realMaxX, realMinY, realMaxY
                else
                    local first = true
                    for _, slot in ipairs(pCfg.slots) do
                        local step = slot.step or 0
                        local dx, dy = 0, 0
                        if growDir == 1 then
                            dx = step * (size + spacing)
                        elseif growDir == 2 then
                            dx = -step * (size + spacing)
                        elseif growDir == 3 then
                            dy = step * (size + vertSpacing)
                        elseif growDir == 4 then
                            dy = -step * (size + vertSpacing)
                        end
                        local left = dx - size / 2
                        local right = dx + size / 2
                        local bottom = dy - size / 2
                        local top = dy + size / 2
                        if first then
                            minX, maxX, minY, maxY = left, right, bottom, top
                            first = false
                        else
                            if left < minX then minX = left end
                            if right > maxX then maxX = right end
                            if bottom < minY then minY = bottom end
                            if top > maxY then maxY = top end
                        end
                    end
                end

                local padX = 8
                local padYTop = 14
                local padYBottom = 22
                local boxW = math.max(size + padX * 2, (maxX - minX) + padX * 2)
                local boxH = math.max(size + padYTop + padYBottom, (maxY - minY) + padYTop + padYBottom)
                local centerOffsetX = (minX + maxX) / 2
                local centerOffsetY = (minY + maxY) / 2 - (padYBottom - padYTop) / 2

                parent:SetSize(size, size)

                local mover = getOrCreateMoverFrame(parent, fName, getFrameDisplayName(fName))
                mover:ClearAllPoints()
                mover:SetPoint("CENTER", parent, "CENTER", centerOffsetX, centerOffsetY)
                mover:SetSize(boxW, boxH)
                local titleText = rawget(mover, "titleText")
                if titleText then
                    titleText:SetText(string.format("[%s] (左鍵拖曳 / 右鍵完成)", getFrameDisplayName(fName)))
                end
                mover:Show()

                local previewIcons = rawget(parent, "previewIcons")
                if hasRealIcons then
                    -- 🛡️ 實體避讓核心：當前框架已有真實圖示（預渲染或運行中），佔位牛頭人全部 Hide，徹底杜絕遮蔽與疊圖
                    if previewIcons then
                        for sIdx = 1, #previewIcons do
                            safeCall(previewIcons[sIdx], "Hide")
                        end
                    end
                else
                    for sIdx, slot in ipairs(pCfg.slots) do
                        local pIcon = getOrCreatePreviewIcon(parent, sIdx)
                        pIcon:SetSize(size, size)
                        pIcon:SetAlpha(alpha)
                        local mLevel = safeCall(mover, "GetFrameLevel") or 6
                        safeCall(pIcon, "SetFrameLevel", mLevel + 2)

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

                        -- 文字錨點位置 (21 種排版)
                        if TextPlacement and TextPlacement.apply and TextPlacement.getPlacement then
                            local timerPlacement = TextPlacement.getPlacement(cfg, "timer")
                            TextPlacement.apply(pIcon.timerText, pIcon, timerPlacement)
                            local appPlacement = TextPlacement.getPlacement(cfg, "applications")
                            TextPlacement.apply(pIcon.stackText, pIcon, appPlacement)
                            local namePlacement = TextPlacement.getPlacement(cfg, "spellName") or "OUTSIDE_BOTTOM"
                            TextPlacement.apply(pIcon.nameText, pIcon, namePlacement)
                        else
                            -- 法術名稱位置 (Fallback)
                            pIcon.nameText:ClearAllPoints()
                            if cfg.nameInside then
                                pIcon.nameText:SetPoint("BOTTOM", pIcon, "BOTTOM", 0, 2)
                            else
                                pIcon.nameText:SetPoint("TOP", pIcon, "BOTTOM", 0, -2)
                            end
                        end

                        if TextPlacement and TextPlacement.applyColor and TextPlacement.getColor then
                            local timerColor = TextPlacement.getColor(cfg, "timer")
                            local appColor = TextPlacement.getColor(cfg, "applications")
                            local nameColor = TextPlacement.getColor(cfg, "spellName")
                            TextPlacement.applyColor(pIcon.timerText, timerColor)
                            TextPlacement.applyColor(pIcon.stackText, appColor)
                            TextPlacement.applyColor(pIcon.nameText, nameColor)
                        end

                        -- 顯隱控制
                        if cfg.showSpellName == false then
                            pIcon.nameText:Hide()
                        else
                            pIcon.nameText:Show()
                        end

                        if cfg.showTimeVal == false then
                            pIcon.timerText:Hide()
                        else
                            pIcon.timerText:Show()
                        end

                        pIcon.stackText:SetText(slot.sampleStack and tostring(slot.sampleStack) or "")

                        -- 扇形倒數轉圈與透明度即時預覽
                        local cd = rawget(pIcon, "cooldown")
                        if cd then
                            if cfg.cooldownShadow == false then
                                safeCall(cd, "Hide")
                            else
                                safeCall(cd, "SetSwipeColor", swipeR, swipeG, swipeB, swipeAlpha)
                                if slot.sampleCD then
                                    safeCall(cd, "SetCooldown", now - 2, slot.sampleCD)
                                    safeCall(cd, "Show")
                                    pIcon.timerText:SetText(string.format("%.1f", math.max(0.1, slot.sampleCD - 2)))
                                else
                                    safeCall(cd, "Hide")
                                    pIcon.timerText:SetText("TIME LEFT")
                                end
                            end
                        end

                        -- 倒數文字變色曲線套用
                        local timerSampleTime = slot.sampleCD and math.max(0.1, slot.sampleCD - 2) or 5.0
                        local timerColor = { 1, 1, 1, 1 }
                        local tcc = cfg.timerColorCurve
                        if tcc and tcc.normalColor then
                            timerColor = tcc.normalColor
                        end
                        if tcc and tcc.enabled and type(tcc.stages) == "table" then
                            for i = 1, #tcc.stages do
                                local stage = tcc.stages[i]
                                if stage and stage.threshold and timerSampleTime <= stage.threshold then
                                    timerColor = stage.color or timerColor
                                    break
                                end
                            end
                        end
                        pIcon.timerText:SetTextColor(timerColor[1] or 1, timerColor[2] or 1, timerColor[3] or 1, timerColor[4] or 1)

                        -- 顏色即時預覽 (紅/綠色度與常規邊框)
                        local tex = rawget(pIcon, "texture")
                        if slot.isSelfDebuff then
                            local r = 1.0
                            local g = math.max(0, 1.0 - selfDebuffRed * 0.7)
                            local b = math.max(0, 1.0 - selfDebuffRed * 0.7)
                            safeCall(pIcon, "SetBackdropBorderColor", r, g, b, 1.0)
                            if tex then safeCall(tex, "SetVertexColor", r, math.max(0.2, 1.0 - selfDebuffRed * 0.35), math.max(0.2, 1.0 - selfDebuffRed * 0.35), 1.0) end
                        elseif slot.isTargetDebuff then
                            local r = math.max(0, 1.0 - targetDebuffGreen * 0.7)
                            local g = 1.0
                            local b = math.max(0, 1.0 - targetDebuffGreen * 0.7)
                            safeCall(pIcon, "SetBackdropBorderColor", r, g, b, 1.0)
                            if tex then safeCall(tex, "SetVertexColor", math.max(0.2, 1.0 - targetDebuffGreen * 0.35), g, math.max(0.2, 1.0 - targetDebuffGreen * 0.35), 1.0) end
                        elseif slot.isPower then
                            safeCall(pIcon, "SetBackdropBorderColor", 0.4, 0.8, 1.0, 1.0)
                            if tex then safeCall(tex, "SetVertexColor", 0.8, 0.95, 1.0, 1.0) end
                        elseif slot.isPet then
                            safeCall(pIcon, "SetBackdropBorderColor", 0.35, 0.95, 0.55, 1.0)
                            if tex then safeCall(tex, "SetVertexColor", 0.85, 1.0, 0.85, 1.0) end
                        else
                            safeCall(pIcon, "SetBackdropBorderColor", 0.85, 0.85, 0.85, 1.0)
                            if tex then safeCall(tex, "SetVertexColor", 1.0, 1.0, 1.0, 1.0) end
                        end
                        safeCall(pIcon, "SetBackdropColor", 0.08, 0.08, 0.08, 0.8)
                        safeCall(pIcon, "Show")
                    end

                    if previewIcons then
                        for sIdx = #pCfg.slots + 1, #previewIcons do
                            safeCall(previewIcons[sIdx], "Hide")
                        end
                    end
                end

                local dHint = rawget(parent, "dragHint")
                if dHint then
                    safeCall(dHint, "Hide")
                end
                safeCall(parent, "Show")
            end
        end
    end
end

-- 9 大告警框架特定/全部移動模式控制
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
        petAlert = EAM.L.EAM_FRAME_PET_ALERT or "EAM - 寵物監控框架",
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
            if not rawget(parent, "dragSetupDone") then
                rawset(parent, "dragSetupDone", true)
                parent:RegisterForDrag("LeftButton")
                parent:SetScript("OnDragStart", parent.StartMoving)
                parent:SetScript("OnDragStop", function(self)
                    local pName = rawget(self, "frameName") or fName
                    saveFrameCenterPosition(self, pName, nameLabels and nameLabels[pName])
                end)
                parent:SetScript("OnMouseUp", function(self, button)
                    if button == "RightButton" and Renderer.isMoving then
                        Renderer.setActiveAnchors(nil)
                        print("|cff00ff96EAM|r " .. (EAM.L.EAM_MOVE_MODE_OFF or "已關閉「多框架移動模式」並成功套用新排版。"))
                    end
                end)
            end

            if activeMap[fName] then
                anyActive = true
                parent:SetMovable(true)
                parent:EnableMouse(false)
                parent:SetFrameStrata("FULLSCREEN_DIALOG")
                parent:SetClampedToScreen(true)

                -- 暫時禁用此框架內真實告警圖示的滑鼠攔截，避免透明或靜態冷卻圖示吃掉點擊
                if fState and fState.icons then
                    for _, realIcon in pairs(fState.icons) do
                        if realIcon and realIcon.EnableMouse then
                            pcall(realIcon.EnableMouse, realIcon, false)
                        end
                    end
                end
            else
                parent:SetMovable(false)
                parent:EnableMouse(false)
                parent:SetFrameStrata("MEDIUM")
                safeCall(parent, "SetBackdrop", nil)
                local mover = rawget(parent, "moverFrame")
                if mover then
                    mover:Hide()
                end
                local dHint = rawget(parent, "dragHint")
                if dHint then safeCall(dHint, "Hide") end
                local previewIcons = rawget(parent, "previewIcons")
                if previewIcons then
                    for _, pIcon in ipairs(previewIcons) do
                        safeCall(pIcon, "Hide")
                    end
                end
                -- 還原真實圖示的滑鼠響應
                if fState and fState.icons then
                    for _, realIcon in pairs(fState.icons) do
                        if realIcon and realIcon.EnableMouse then
                            pcall(realIcon.EnableMouse, realIcon, true)
                        end
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
