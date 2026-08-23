--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/PowerRenderer
檔案: UI\PowerRenderer.lua

責任:
- 在脫戰初始化期為 17 種玩家資源各自預建獨立 Frame 與 StatusBar。
- Secret 百分比只直送對應 StatusBar:SetValue；普通數值才允許產生數字文字。
- 依每資源設定處理尺寸、位置、顯示模式與前景／背景可見性。

邊界:
- 不呼叫 UnitPower API、不讀回 StatusBar、不保存 current/max/percent。
- 不使用 OnUpdate；幾何與樣式只由冷路徑設定。
- Secret sink frame 永不交給 Aura／Cooldown 或其他資源重用。
- POINTS 使用固定分隔線加單一 C 層百分比填色，不在 Lua 拆解 Secret 點數。
]]
local _, EAM = ...

local api = EAM.API
local Util = EAM.Util
local Renderer = EAM.UI.Renderer
local Catalog = EAM.Data.PlayerResourceCatalog
local TextPlacement = EAM.UI.TextPlacement

local PowerRenderer = {
    frames = {},
    initialized = false,
    acceptedWriteCount = 0,
    rejectedWriteCount = 0,
}

EAM.UI.PowerRenderer = PowerRenderer

local ROW_HEIGHT = 38
local VALID_ANCHOR_POINTS = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true,
}

local function inCombat()
    return api.InCombatLockdown and api.InCombatLockdown() == true
end

local function clearNumericText(frame)
    frame.valueText:ClearText()
    frame.valueText:Hide()
end

local function setNumericTextFormatted(frame, currentValue, maximumValue, percent, showValue, showPercent)
    local roundedPercent = math.floor(percent * 100 + 0.5)
    if showValue ~= false and showPercent == true then
        frame.valueText:SetFormattedText("%d / %d (%d%%)", currentValue, maximumValue, roundedPercent)
    elseif showValue ~= false then
        frame.valueText:SetFormattedText("%d / %d", currentValue, maximumValue)
    elseif showPercent == true then
        frame.valueText:SetFormattedText("%d%%", roundedPercent)
    else
        clearNumericText(frame)
        return
    end
    frame.valueText:Show()
end

local function createResourceFrame(anchor, definition)
    local container = api.CreateFrame("Frame", "EAM_PlayerResource_" .. definition.key, anchor)
    container:SetSize(166, 34)

    local icon = container:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("LEFT", container, "LEFT", 0, 0)
    icon:SetTexture(definition.icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local statusBar = api.CreateFrame("StatusBar", "EAM_PlayerResourceBar_" .. definition.key, container)
    statusBar:SetSize(126, 16)
    statusBar:SetPoint("LEFT", icon, "RIGHT", 6, -7)
    statusBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    statusBar:SetStatusBarColor(
        definition.color[1],
        definition.color[2],
        definition.color[3],
        definition.color[4]
    )
    statusBar:SetMinMaxValues(0, 1)
    statusBar:SetValue(0)

    local background = statusBar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(statusBar)
    background:SetColorTexture(0.02, 0.02, 0.02, 0.55)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", statusBar, "TOPLEFT", 0, 2)
    label:SetText(definition.fallbackName)

    local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("CENTER", statusBar, "CENTER", 0, 0)
    valueText:SetText("")

    local glow = statusBar:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(icon)
    glow:SetVertexColor(1, 0.82, 0.15, 0.95)
    glow:Hide()

    local markers = {}
    local maxPoints = definition.maxPoints or 5
    for index = 1, maxPoints - 1 do
        local marker = statusBar:CreateTexture(nil, "OVERLAY")
        marker:SetSize(1, 16)
        marker:SetPoint("LEFT", statusBar, "LEFT", 126 * index / maxPoints, 0)
        marker:SetColorTexture(0, 0, 0, 0.75)
        marker:Hide()
        markers[index] = marker
    end

    local slotBars = {}
    if definition.rendererKind == "POINTS" and maxPoints and maxPoints > 0 then
        for index = 1, maxPoints do
            local slotBar = api.CreateFrame("StatusBar", nil, container)
            slotBar:SetSize(20, 3)
            slotBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            slotBar:SetStatusBarColor(
                definition.color[1],
                definition.color[2],
                definition.color[3],
                0.9
            )
            slotBar:SetMinMaxValues(0, 1)
            slotBar:SetValue(1)

            local slotBg = slotBar:CreateTexture(nil, "BACKGROUND")
            slotBg:SetAllPoints(slotBar)
            slotBg:SetColorTexture(0.02, 0.02, 0.02, 0.65)
            slotBar.bg = slotBg
            slotBar:Hide()
            slotBars[index] = slotBar
        end
    end

    container:Hide()
    return {
        key = definition.key,
        definition = definition,
        anchor = anchor,
        container = container,
        icon = icon,
        statusBar = statusBar,
        background = background,
        label = label,
        valueText = valueText,
        numericTextSink = setNumericTextFormatted,
        glow = glow,
        markers = markers,
        slotBars = slotBars,
        configured = false,
        visible = false,
        available = false,
        foreground = false,
        powerType = definition.powerType,
        config = nil,
    }
end

function PowerRenderer.initialize()
    if PowerRenderer.initialized then
        return true, "unchanged"
    end
    if inCombat() then
        return false, "combatDeferred"
    end
    if not Renderer or type(Renderer.getFrameParent) ~= "function"
        or not Catalog or type(Catalog.Definitions) ~= "table"
    then
        return false, "dependencyUnavailable"
    end

    local anchor = Renderer.getFrameParent(EAM.Constants.ALERT_FRAME_TYPES.classPower)
    if not anchor then
        return false, "anchorUnavailable"
    end

    for index = 1, #Catalog.Definitions do
        local definition = Catalog.Definitions[index]
        PowerRenderer.frames[definition.key] = createResourceFrame(anchor, definition)
    end
    PowerRenderer.initialized = true
    return true, "initialized"
end

function PowerRenderer.configureResource(definition, config, displayName, orderIndex, specializationID)
    if not PowerRenderer.initialized then
        local initialized, reason = PowerRenderer.initialize()
        if not initialized then
            return false, reason
        end
    end
    if inCombat() then
        return false, "combatDeferred"
    end

    local frame = definition and PowerRenderer.frames[definition.key] or nil
    if not frame then
        return false, "resourceFrameUnavailable"
    end

    local Catalog = EAM.Data.PlayerResourceCatalog
    local iconTexture = Catalog and Catalog.getResourceIcon and Catalog.getResourceIcon(definition.key, specializationID)
        or definition.icon

    local x = Util.isSafeNumber(config and config.offsetX) and config.offsetX or 0
    local y = Util.isSafeNumber(config and config.offsetY) and config.offsetY or 0
    local scale = Util.isSafePositiveNumber(config and config.scale) and config.scale or 1
    local barWidth = Util.isSafePositiveNumber(config and config.barWidth) and config.barWidth or 126
    local barHeight = Util.isSafePositiveNumber(config and config.barHeight) and config.barHeight or 16
    local iconSize = Util.isSafePositiveNumber(config and config.iconSize) and config.iconSize or 30
    local spacing = Util.isSafeNonNegativeNumber(config and config.spacing) and config.spacing or 6

    local position = config and VALID_ANCHOR_POINTS[config.position] and config.position or "TOPLEFT"
    local anchorPoint = config and VALID_ANCHOR_POINTS[config.anchor] and config.anchor or "TOPLEFT"
    frame.container:ClearAllPoints()
    frame.container:SetPoint(
        position,
        frame.anchor,
        anchorPoint,
        x,
        y - ((orderIndex or 1) - 1) * ROW_HEIGHT
    )
    frame.container:SetSize(iconSize + spacing + barWidth, math.max(iconSize, barHeight + 18))
    frame.container:SetScale(scale)

    frame.icon:ClearAllPoints()
    frame.icon:SetSize(iconSize, iconSize)
    frame.icon:SetPoint("LEFT", frame.container, "LEFT", 0, 0)
    frame.icon:SetTexture(iconTexture)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.statusBar:ClearAllPoints()
    frame.statusBar:SetSize(barWidth, barHeight)
    frame.statusBar:SetPoint("LEFT", frame.icon, "RIGHT", spacing, 0)
    frame.background:SetAllPoints(frame.statusBar)

    frame.label:ClearAllPoints()
    frame.label:SetPoint("BOTTOMLEFT", frame.statusBar, "TOPLEFT", 0, 2)

    frame.glow:ClearAllPoints()
    frame.glow:SetAllPoints(frame.icon)

    local displayMode = config and config.displayMode or "AUTO"
    local orientation = config and config.orientation == "VERTICAL"
        and "VERTICAL"
        or "HORIZONTAL"
    -- StatusBar:SetOrientation 在不同 client/mock 可能不存在，索引與呼叫一併置於 pcall。
    pcall(function()
        frame.statusBar:SetOrientation(orientation)
    end)
    if TextPlacement and type(TextPlacement.applyFont) == "function" then
        local fontSize = Util.isSafePositiveNumber(config and config.fontSize)
            and config.fontSize
            or 12
        local valueFontSize = Util.isSafePositiveNumber(config and config.valueFontSize)
            and config.valueFontSize
            or 14
        local valueOffsetX = Util.isSafeNumber(config and config.valueOffsetX)
            and config.valueOffsetX
            or 0
        local valueOffsetY = Util.isSafeNumber(config and config.valueOffsetY)
            and config.valueOffsetY
            or 0
        TextPlacement.applyFont(frame.label, fontSize, config and config.fontFamily)
        TextPlacement.applyFont(frame.valueText, valueFontSize, config and config.fontFamily)
        frame.valueText:ClearAllPoints()
        frame.valueText:SetPoint("CENTER", frame.icon, "CENTER", valueOffsetX, valueOffsetY)
    end
    local effectiveKind = displayMode == "AUTO" and definition.rendererKind or displayMode
    local maxPoints = definition.maxPoints or 5
    for index = 1, #frame.markers do
        local marker = frame.markers[index]
        marker:ClearAllPoints()
        marker:SetSize(1, barHeight)
        marker:SetPoint("LEFT", frame.statusBar, "LEFT", barWidth * index / maxPoints, 0)
        if effectiveKind == "POINTS" then
            marker:Show()
        else
            marker:Hide()
        end
    end

    if frame.slotBars then
        local slotWidth = math.max(1, (barWidth / maxPoints) - 1)
        for index = 1, #frame.slotBars do
            local slotBar = frame.slotBars[index]
            slotBar:ClearAllPoints()
            slotBar:SetSize(slotWidth, 3)
            slotBar:SetPoint(
                "TOPLEFT",
                frame.statusBar,
                "BOTTOMLEFT",
                (index - 1) * (barWidth / maxPoints),
                -2
            )
            if effectiveKind == "POINTS" then
                slotBar:Show()
            else
                slotBar:Hide()
            end
        end
    end

    frame.label:SetText(displayName or definition.fallbackName)
    frame.valueText:ClearText()
    frame.valueText:Hide()
    frame.glow:Hide()
    frame.container:Hide()
    frame.configured = true
    frame.visible = false
    frame.available = false
    frame.foreground = false
    frame.powerType = definition.powerType
    frame.config = config
    return true, "configured"
end

function PowerRenderer.applyRuneCooldowns(resourceKey, slotProgressTable)
    local frame = PowerRenderer.frames[resourceKey]
    if not frame or not frame.slotBars or type(slotProgressTable) ~= "table" then
        return false, "sinkUnavailable"
    end
    for index = 1, #frame.slotBars do
        local progress = slotProgressTable[index]
        if Util.isSafeNumber(progress) then
            pcall(frame.slotBars[index].SetValue, frame.slotBars[index], progress)
        end
    end
    return true, "cooldownsRendered"
end

function PowerRenderer.reflowResourceFrames(nodes, count)
    if not PowerRenderer.initialized or type(nodes) ~= "table" then
        return false, "rendererUnavailable"
    end
    local total = count or #nodes
    for index = 1, total do
        local node = nodes[index]
        local frame = node and PowerRenderer.frames[node.key] or nil
        local config = frame and frame.config or nil
        if frame and frame.configured and config then
            local x = Util.isSafeNumber(config.offsetX) and config.offsetX or 0
            local y = Util.isSafeNumber(config.offsetY) and config.offsetY or 0
            local position = VALID_ANCHOR_POINTS[config.position] and config.position or "TOPLEFT"
            local anchorPoint = VALID_ANCHOR_POINTS[config.anchor] and config.anchor or "TOPLEFT"
            frame.container:ClearAllPoints()
            frame.container:SetPoint(
                position,
                frame.anchor,
                anchorPoint,
                x,
                y - (index - 1) * ROW_HEIGHT
            )
        end
    end
    return true, "reflowed"
end

function PowerRenderer.setResourceState(resourceKey, foreground, available)
    local frame = PowerRenderer.frames[resourceKey]
    if not frame or not frame.configured then
        return false, "resourceFrameUnavailable"
    end
    frame.foreground = foreground == true
    frame.available = available == true
    local config = frame.config or {}
    local showForRole = false
    if frame.foreground then
        showForRole = config.showForeground ~= false
    else
        showForRole = config.showBackground ~= false
    end
    local visible = frame.available and config.enabled ~= false and showForRole
    local alpha = Util.isSafeNumber(config.alpha) and config.alpha or 1
    local roleAlpha = frame.foreground
        and (Util.isSafeNumber(config.foregroundAlpha) and config.foregroundAlpha or 1)
        or (Util.isSafeNumber(config.backgroundAlpha) and config.backgroundAlpha or 0.55)
    frame.container:SetAlpha(alpha * roleAlpha)
    if visible then
        frame.container:Show()
    else
        frame.container:Hide()
        frame.valueText:ClearText()
        frame.valueText:Hide()
    end
    frame.visible = visible
    return visible, visible and "visible" or "hidden"
end

local function applyPercent(frame, powerType, percent)
    if not frame or not frame.configured or not frame.visible or powerType ~= frame.powerType then
        PowerRenderer.rejectedWriteCount = PowerRenderer.rejectedWriteCount + 1
        return false, "sinkUnavailable"
    end
    local ok = pcall(frame.statusBar.SetValue, frame.statusBar, percent)
    percent = nil
    if ok then
        PowerRenderer.acceptedWriteCount = PowerRenderer.acceptedWriteCount + 1
        return true, "nativeRendered"
    end
    PowerRenderer.rejectedWriteCount = PowerRenderer.rejectedWriteCount + 1
    return false, "nativeRejected"
end

function PowerRenderer.applySecretPercent(resourceKey, powerType, percent)
    local frame = PowerRenderer.frames[resourceKey]
    if frame and frame.valueText then
        frame.valueText:ClearText()
        frame.valueText:Hide()
    end
    if frame and frame.glow then
        frame.glow:Hide()
    end
    return applyPercent(frame, powerType, percent)
end

function PowerRenderer.applyNumeric(resourceKey, powerType, currentValue, maximumValue, percent, showValue, showPercent, fullGlow, threshold)
    if not Util.isSafeNonNegativeNumber(currentValue)
        or not Util.isSafePositiveNumber(maximumValue)
        or not Util.isSafeNumber(percent)
    then
        return false, "unsafeNumericValue"
    end

    local frame = PowerRenderer.frames[resourceKey]
    if not frame then
        return false, "sinkUnavailable"
    end
    frame.numericTextSink(
        frame,
        currentValue,
        maximumValue,
        percent,
        showValue,
        showPercent
    )
    if frame.glow then
        local glowThreshold = Util.isSafeNumber(threshold) and threshold or 0.9
        if fullGlow == true and percent >= glowThreshold then
            frame.glow:Show()
        else
            frame.glow:Hide()
        end
    end
    return applyPercent(frame, powerType, percent)
end

function PowerRenderer.hideResource(resourceKey)
    local frame = PowerRenderer.frames[resourceKey]
    if frame then
        frame.container:Hide()
        frame.valueText:ClearText()
        frame.valueText:Hide()
        if frame.glow then
            frame.glow:Hide()
        end
        if frame.configured then
            pcall(frame.statusBar.SetValue, frame.statusBar, 0)
        end
        frame.visible = false
        frame.available = false
        frame.foreground = false
        frame.configured = false
        frame.config = nil
    end
end

function PowerRenderer.hideAll()
    for index = 1, #Catalog.Definitions do
        PowerRenderer.hideResource(Catalog.Definitions[index].key)
    end
end

PowerRenderer.hide = PowerRenderer.hideAll

function PowerRenderer.getStatus()
    local configuredCount = 0
    local visibleCount = 0
    for index = 1, #Catalog.Definitions do
        local frame = PowerRenderer.frames[Catalog.Definitions[index].key]
        if frame and frame.configured then
            configuredCount = configuredCount + 1
        end
        if frame and frame.visible then
            visibleCount = visibleCount + 1
        end
    end
    return {
        initialized = PowerRenderer.initialized,
        resourceFrameCount = Catalog.ResourceCount,
        configuredCount = configuredCount,
        visibleCount = visibleCount,
        acceptedWriteCount = PowerRenderer.acceptedWriteCount,
        rejectedWriteCount = PowerRenderer.rejectedWriteCount,
        dedicatedSecretFrames = true,
        rawValuesExposed = false,
    }
end