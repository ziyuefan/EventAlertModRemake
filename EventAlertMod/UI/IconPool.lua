--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/IconPool
檔案: UI\IconPool.lua

理念:
- 所有 icon frame、texture、fontstring、cooldown region 由 pool 統一管理。
- Renderer 只借用 frame，不自行大量 CreateFrame。

責任:
- 負責 acquire/release icon records 與 controlled frame growth。
- 為 EAM 自有 legacy 圖示提供非戰鬥 spell/item Tooltip，不讀取 runtime Aura 或 power 原值。

資料所有權:
- 擁有 active/inactive icon pools 與 frame objects。

可變狀態:
- 可 mutate frame object 與 pool arrays。

邊界:
- 不查 aura/cooldown/item 狀態 API；Tooltip 只接收 Renderer 已驗證的靜態 ID。
- 不替 classPower power type 或 totem slot 偽造 spell Tooltip。
- 不寫 SavedVariables。

效能注意:
- 初始化或受控擴容時才 CreateFrame；release 不銷毀 frame。

Retail API 注意:
- UI frame template 與 protected frame 行為需 Retail 實機驗證。
- 為降低 taint/combat lockdown 風險，戰鬥中不建立新的 icon frame。

]]
local _, EAM = ...

local api = EAM.API
local Util = EAM.Util
local AlertBorderStyles = EAM.UI.AlertBorderStyles

local IconPool = {
    active = {},
    inactive = {},
    inactiveCount = 0,
    created = 0,
    prewarmCount = 16,
}

EAM.UI.IconPool = IconPool

-- 嚴格 mock 與 Retail 可選 UI 方法不可直接索引：缺少方法時讀取本身也可能拋錯。
local function getMethod(object, name)
    if not object then
        return nil
    end
    local ok, method = pcall(function()
        return object[name]
    end)
    if ok and type(method) == "function" then
        return method
    end
    return nil
end

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

local function isCombatLocked()
    local method = getMethod(api, "InCombatLockdown")
    if not method then
        return false
    end
    local ok, result = pcall(method)
    return ok and result == true
end

local ButtonGlow
do
    local libStub = _G and _G.LibStub
    local getLibrary = getMethod(libStub, "GetLibrary")
    if getLibrary then
        local ok, library = pcall(getLibrary, libStub, "LibButtonGlow-1.0", true)
        if ok and library then
            ButtonGlow = library
        end
    end
end
local function normalizeSwipeAlpha(config)
    local alpha = config and config.cooldownSwipeAlpha
    if not EAM.Util.isSafeNumber(alpha) then
        return 1
    end
    if alpha < 0 then
        return 0
    elseif alpha > 1 then
        return 1
    end
    return alpha
end

function IconPool.applyCooldownStyle(icon, config)
    local cooldown = icon and icon.cooldown
    if not cooldown then
        return false
    end
    local setDrawEdge = getMethod(cooldown, "SetDrawEdge")
    if setDrawEdge then
        pcall(setDrawEdge, cooldown, false)
    end
    local setDrawBling = getMethod(cooldown, "SetDrawBling")
    if setDrawBling then
        pcall(setDrawBling, cooldown, false)
    end
    local setDrawSwipe = getMethod(cooldown, "SetDrawSwipe")
    if setDrawSwipe then
        pcall(setDrawSwipe, cooldown, true)
    end
    local setSwipeColor = getMethod(cooldown, "SetSwipeColor")
    if setSwipeColor then
        pcall(setSwipeColor, cooldown, 1, 1, 1, normalizeSwipeAlpha(config))
        return true
    end
    return false
end
local CHARGE_LAYOUT_DEFAULT = "BOTTOM"
local CHARGE_LAYOUTS = EAM.Util.tableFreeze({
    TOP = true,
    BOTTOM = true,
    LEFT = true,
    RIGHT = true,
    RING = true,
})
local CHARGE_LINEAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local CHARGE_RING_TEXTURE = "Interface\\AddOns\\EventAlertMod\\Media\\Images\\eam-charge-ring.tga"
local CHARGE_RING_FALLBACK_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local CHARGE_BACKGROUND_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local MAX_CHARGE_DIVIDERS = 19
local TWO_PI = math.pi * 2

local function normalizeChargeLayout(config)
    local mode = config and config.chargeBarLayout or CHARGE_LAYOUT_DEFAULT
    if not CHARGE_LAYOUTS[mode] then
        mode = CHARGE_LAYOUT_DEFAULT
    end

    local lengthPercent = config and config.chargeBarLengthPercent or 150
    if not Util.isSafeNumber(lengthPercent) then
        lengthPercent = 150
    elseif lengthPercent < 100 then
        lengthPercent = 100
    elseif lengthPercent > 250 then
        lengthPercent = 250
    end

    local thickness = config and config.chargeBarThickness or 8
    if not Util.isSafeNumber(thickness) then
        thickness = 8
    elseif thickness < 4 then
        thickness = 4
    elseif thickness > 16 then
        thickness = 16
    end
    return mode, lengthPercent, thickness
end

local function setStatusBarTextureWithFallback(statusBar)
    local setStatusBarTexture = getMethod(statusBar, "SetStatusBarTexture")
    if not setStatusBarTexture then
        return false, nil
    end
    local ok, accepted = pcall(setStatusBarTexture, statusBar, CHARGE_RING_TEXTURE)
    if ok and accepted == true then
        return true, CHARGE_RING_TEXTURE
    end
    ok, accepted = pcall(setStatusBarTexture, statusBar, CHARGE_RING_FALLBACK_TEXTURE)
    if ok and accepted == true then
        return true, CHARGE_RING_FALLBACK_TEXTURE
    end
    return false, nil
end

local function createChargeVisual(parent, kind)
    local host = api.CreateFrame("Frame", nil, parent)
    local bar = api.CreateFrame("StatusBar", nil, host)
    bar:SetAllPoints(host)

    local radialAvailable = false
    local radialTexture = nil
    if kind == "RING" then
        local textureAccepted
        textureAccepted, radialTexture = setStatusBarTextureWithFallback(bar)
        local renderMode = Enum and Enum.StatusBarRenderMode and Enum.StatusBarRenderMode.Radial
        local setRenderMode = getMethod(bar, "SetRenderMode")
        local getRenderMode = getMethod(bar, "GetRenderMode")
        if textureAccepted and setRenderMode and getRenderMode and renderMode ~= nil then
            local setOK = pcall(setRenderMode, bar, renderMode)
            local getOK, effectiveMode = pcall(getRenderMode, bar)
            radialAvailable = setOK and getOK and effectiveMode == renderMode
        end
    else
        local setStatusBarTexture = getMethod(bar, "SetStatusBarTexture")
        if setStatusBarTexture then
            pcall(setStatusBarTexture, bar, CHARGE_LINEAR_TEXTURE)
        end
        local setOrientation = getMethod(bar, "SetOrientation")
        if setOrientation then
            pcall(setOrientation, bar, kind == "VERTICAL" and "VERTICAL" or "HORIZONTAL")
        end
    end

    local setStatusBarColor = getMethod(bar, "SetStatusBarColor")
    if setStatusBarColor then
        pcall(setStatusBarColor, bar, 0.1, 0.75, 1, 0.95)
    end

    local background = host:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(host)
    if kind == "RING" then
        background:SetTexture(radialTexture or CHARGE_RING_FALLBACK_TEXTURE)
        background:SetVertexColor(0.02, 0.08, 0.12, 0.8)
    else
        background:SetTexture(CHARGE_BACKGROUND_TEXTURE)
        background:SetVertexColor(0, 0, 0, 0.78)
    end
    host:Hide()
    return {
        host = host,
        bar = bar,
        background = background,
        kind = kind,
        radialAvailable = radialAvailable,
        radialTexture = radialTexture,
    }
end

local function hideChargeDividers(icon)
    local dividers = icon and icon.chargeDividers
    if not dividers then
        return
    end
    for index = 1, #dividers do
        dividers[index]:Hide()
    end
end

local function hideChargeVisuals(icon)
    local visuals = icon and icon.chargeVisuals
    if visuals then
        visuals.HORIZONTAL.host:Hide()
        visuals.VERTICAL.host:Hide()
        visuals.RING.host:Hide()
    end
    hideChargeDividers(icon)
end

local function configureChargeName(icon, mode, iconSize, length, thickness, visible)
    local rendered = icon and icon.rendered
    local nameText = icon and icon.nameText
    if not rendered or not nameText or rendered.nameInside == true then
        return
    end

    local key = visible and (mode .. ":" .. tostring(length) .. ":" .. tostring(thickness)) or "NONE"
    if rendered.chargeNameLayoutKey == key then
        return
    end

    local offset = 2
    if visible and mode == "BOTTOM" then
        offset = thickness + 4
    elseif visible and mode == "RING" then
        offset = math.max(2, ((length - iconSize) * 0.5) + 2)
    end

    local reference = icon.overlay or icon
    nameText:ClearAllPoints()
    nameText:SetPoint("TOP", reference, "BOTTOM", 0, -offset)
    rendered.chargeNameLayoutKey = key
end

local function configureChargeDividers(icon, visual, mode, maximumCharges, length, thickness)
    hideChargeDividers(icon)
    if not Util.isSafePositiveNumber(maximumCharges) then
        return
    end

    local segmentCount = math.floor(maximumCharges)
    if segmentCount <= 1 or segmentCount > MAX_CHARGE_DIVIDERS + 1 then
        return
    end

    local dividers = icon.chargeDividers
    local host = visual.host
    for index = 1, segmentCount - 1 do
        local divider = dividers[index]
        divider:ClearAllPoints()
        local setRotation = getMethod(divider, "SetRotation")
        if mode == "RING" then
            local angle = TWO_PI * index / segmentCount
            local radius = math.max(1, (length * 0.5) - (thickness * 0.5))
            divider:SetSize(2, thickness + 4)
            divider:SetPoint(
                "CENTER",
                host,
                "CENTER",
                math.sin(angle) * radius,
                math.cos(angle) * radius
            )
            if setRotation then
                pcall(setRotation, divider, -angle)
            end
        elseif mode == "LEFT" or mode == "RIGHT" then
            divider:SetSize(thickness + 2, 1)
            divider:SetPoint(
                "CENTER",
                host,
                "CENTER",
                0,
                (length * 0.5) - (length * index / segmentCount)
            )
            if setRotation then
                pcall(setRotation, divider, 0)
            end
        else
            divider:SetSize(1, thickness + 2)
            divider:SetPoint(
                "CENTER",
                host,
                "CENTER",
                (-length * 0.5) + (length * index / segmentCount),
                0
            )
            if setRotation then
                pcall(setRotation, divider, 0)
            end
        end
        divider:Show()
    end
end

local function configureChargeVisual(icon, alertState)
    local visuals = icon and icon.chargeVisuals
    local rendered = icon and icon.rendered
    if not visuals or not rendered then
        return nil, nil, "chargeVisualUnavailable"
    end

    local maximumCharges = alertState and alertState.maxCharges
    if not Util.isSafePositiveNumber(maximumCharges) then
        hideChargeVisuals(icon)
        configureChargeName(icon, CHARGE_LAYOUT_DEFAULT, 40, 40, 8, false)
        return nil, nil, "maximumUnavailable"
    end

    local config = EAM.db and EAM.db.config or nil
    local requestedMode, lengthPercent, thickness = normalizeChargeLayout(config)
    local iconSize = config and config.iconSize or 40
    if not Util.isSafePositiveNumber(iconSize) then
        iconSize = 40
    end
    local length = math.max(1, iconSize * lengthPercent / 100)
    local mode = requestedMode
    if mode == "RING" and visuals.RING.radialAvailable ~= true then
        mode = CHARGE_LAYOUT_DEFAULT
    end

    local visualKey = (mode == "LEFT" or mode == "RIGHT") and "VERTICAL"
        or (mode == "RING" and "RING" or "HORIZONTAL")
    local visual = visuals[visualKey]
    local layoutKey = mode .. ":" .. tostring(lengthPercent) .. ":" .. tostring(thickness)
    local canChangeLayout = not isCombatLocked() or rendered.chargeLayoutKey == nil
    if rendered.chargeLayoutKey ~= layoutKey and canChangeLayout then
        local host = visual.host
        host:ClearAllPoints()
        if mode == "TOP" then
            host:SetSize(length, thickness)
            host:SetPoint("BOTTOM", icon, "TOP", 0, 2)
        elseif mode == "BOTTOM" then
            host:SetSize(length, thickness)
            host:SetPoint("TOP", icon, "BOTTOM", 0, -2)
        elseif mode == "LEFT" then
            host:SetSize(thickness, length)
            host:SetPoint("RIGHT", icon, "LEFT", -2, 0)
        elseif mode == "RIGHT" then
            host:SetSize(thickness, length)
            host:SetPoint("LEFT", icon, "RIGHT", 2, 0)
        else
            length = math.max(length, iconSize + (thickness * 2))
            host:SetSize(length, length)
            host:SetPoint("CENTER", icon, "CENTER", 0, 0)
        end
        rendered.chargeLayoutKey = layoutKey
        rendered.chargeVisualKey = visualKey
        rendered.chargeEffectiveMode = mode
        rendered.chargeLength = length
        rendered.chargeThickness = thickness
    elseif rendered.chargeLayoutKey ~= layoutKey then
        visualKey = rendered.chargeVisualKey or "HORIZONTAL"
        mode = rendered.chargeEffectiveMode or CHARGE_LAYOUT_DEFAULT
        length = rendered.chargeLength or (iconSize * 1.5)
        thickness = rendered.chargeThickness or 8
        visual = visuals[visualKey]
    end

    visuals.HORIZONTAL.host:SetShown(visualKey == "HORIZONTAL")
    visuals.VERTICAL.host:SetShown(visualKey == "VERTICAL")
    visuals.RING.host:SetShown(visualKey == "RING")
    configureChargeDividers(icon, visual, mode, maximumCharges, length, thickness)
    configureChargeName(icon, mode, iconSize, length, thickness, true)
    return visual.bar, mode, requestedMode == "RING" and mode ~= "RING" and "radialFallback" or "configured"
end

-- 充能段數只代表剩餘可用次數；DurationObject 僅供圖示冷卻轉圈，不能驅動此列。
function IconPool.applyChargeProgress(icon, alertState)
    if not icon or not alertState or alertState.isChargeBased ~= true then
        hideChargeVisuals(icon)
        configureChargeName(icon, CHARGE_LAYOUT_DEFAULT, 40, 40, 8, false)
        return true, "hidden"
    end

    local statusBar, _, layoutReason = configureChargeVisual(icon, alertState)
    if not statusBar then
        return false, layoutReason
    end

    local service = EAM.Services and EAM.Services.CooldownService
    if not service or type(service.applyChargeStatusBar) ~= "function" then
        hideChargeVisuals(icon)
        return false, "chargeServiceUnavailable"
    end

    -- configureChargeVisual 已先完成全部結構與可見性；C sink 必須是最後一步。
    local accepted, sinkReason = service.applyChargeStatusBar(
        alertState.spellID,
        statusBar,
        alertState.chargeSpellID
    )
    if not accepted then
        hideChargeVisuals(icon)
        return false, sinkReason
    end
    return true, layoutReason == "radialFallback" and layoutReason or sinkReason
end

local function tryLibraryGlow(icon, enabled)
    if not ButtonGlow or not icon then
        return false
    end
    local overlay = readField(icon, "__LBGoverlay")
    if enabled == true then
        local show = getMethod(ButtonGlow, "ShowOverlayGlow")
        if not show then
            return false
        end
        -- LibButtonGlow 首次顯示會建立動畫框；戰鬥中不建立，避免不必要的框架變更。
        if isCombatLocked() and not overlay then
            return false
        end
        local ok = pcall(show, icon)
        return ok
    end
    if not overlay then
        return false
    end
    local hide = getMethod(ButtonGlow, "HideOverlayGlow")
    if not hide then
        return false
    end
    local ok = pcall(hide, icon)
    return ok
end

function IconPool.setGlow(icon, enabled, r, g, b, a)
    local glow = icon and icon.glowBorder
    if not glow then
        return false, "glowUnavailable"
    end
    local customColor = Util.isSafeNumber(r)
        and Util.isSafeNumber(g)
        and Util.isSafeNumber(b)
    if enabled == true and not customColor then
        if tryLibraryGlow(icon, true) then
            local ownAnimation = readField(icon, "glowAnimation")
            local stop = getMethod(ownAnimation, "Stop")
            if stop then
                pcall(stop, ownAnimation)
            end
            glow:Hide()
            return true, "libraryShown"
        end
    elseif enabled ~= true then
        local libraryHidden = tryLibraryGlow(icon, false)
        local ownAnimation = readField(icon, "glowAnimation")
        local stop = getMethod(ownAnimation, "Stop")
        if stop then
            pcall(stop, ownAnimation)
        end
        glow:Hide()
        if libraryHidden then
            return true, "libraryHidden"
        end
        return true, "hidden"
    else
        -- 自訂顏色無法由 LibButtonGlow 保證，先關閉既有 library overlay，再走 EAM fallback。
        tryLibraryGlow(icon, false)
    end

    if enabled == true then
        if customColor then
            glow:SetVertexColor(
                r,
                g,
                b,
                Util.isSafeNumber(a) and a or 1
            )
        end
        glow:Show()
        local animation = readField(icon, "glowAnimation")
        local isPlaying = getMethod(animation, "IsPlaying")
        local play = getMethod(animation, "Play")
        if isPlaying and play then
            local ok, playing = pcall(isPlaying, animation)
            if ok and not playing then
                pcall(play, animation)
            end
        end
        return true, "fallbackShown"
    end
    return true, "hidden"
end
local TOOLTIP_KIND_SPELL = "spell"
local TOOLTIP_KIND_ITEM = "item"

local function hideIconTooltip()
    local tooltip = api.GameTooltip
    local hide = getMethod(tooltip, "Hide")
    if hide then
        pcall(hide, tooltip)
    end
end
local function showIconTooltip(icon)
    if isCombatLocked() then
        return false, "combatBlocked"
    end
    local rendered = icon and icon.rendered
    local tooltipKind = rendered and rendered.tooltipKind or nil
    local tooltipID = rendered and rendered.tooltipID or nil
    if not Util.isSafeString(tooltipKind) or not Util.isSafePositiveNumber(tooltipID) then
        return false, "sourceUnavailable"
    end
    local tooltip = api.GameTooltip
    local setOwner = getMethod(tooltip, "SetOwner")
    if not setOwner then
        return false, "tooltipUnavailable"
    end
    local ownerOK = pcall(setOwner, tooltip, icon, "ANCHOR_RIGHT")
    if not ownerOK then
        return false, "ownerRejected"
    end

    local method
    if tooltipKind == TOOLTIP_KIND_SPELL then
        method = getMethod(tooltip, "SetSpellByID")
    elseif tooltipKind == TOOLTIP_KIND_ITEM then
        method = getMethod(tooltip, "SetItemByID")
    end
    if not method then
        hideIconTooltip()
        return false, "methodUnavailable"
    end
    local setOK = pcall(method, tooltip, tooltipID)
    if not setOK then
        hideIconTooltip()
        return false, "contentRejected"
    end
    local show = getMethod(tooltip, "Show")
    if show then
        pcall(show, tooltip)
    end
    return true, tooltipKind
end
function IconPool.applyTooltipSource(icon, alertState)
    local rendered = icon and icon.rendered
    if not rendered then
        return false
    end
    local tooltipKind
    local tooltipID
    local alertKind = alertState and alertState.kind or nil
    if Util.isSafeString(alertKind) then
        if alertKind == EAM.Constants.ALERT_KIND_ITEM_COOLDOWN then
            local itemID = alertState.itemID
            if Util.isSafePositiveNumber(itemID) then
                tooltipKind = TOOLTIP_KIND_ITEM
                tooltipID = itemID
            end
        elseif alertKind == EAM.Constants.ALERT_KIND_AURA
            or alertKind == EAM.Constants.ALERT_KIND_SPELL_COOLDOWN
            or alertKind == EAM.Constants.ALERT_KIND_GROUND_EFFECT
        then
            local spellID = alertState.spellID
            if Util.isSafePositiveNumber(spellID) then
                tooltipKind = TOOLTIP_KIND_SPELL
                tooltipID = spellID
            end
        end
    end
    rendered.tooltipKind = tooltipKind
    rendered.tooltipID = tooltipID
    return tooltipKind ~= nil
end

function IconPool.applyTypeBorder(icon, alertState, frameName)
    local rendered = icon and icon.rendered
    local border = icon and icon.typeBorder
    if not rendered or not border or not AlertBorderStyles then
        return false, "borderUnavailable"
    end
    local styleKey = AlertBorderStyles.resolve(frameName, alertState)
    if rendered.borderStyleKey == styleKey then
        return styleKey ~= nil, styleKey or "styleUnavailable"
    end
    rendered.borderStyleKey = styleKey
    return AlertBorderStyles.apply(border, styleKey)
end

local function createIcon()
    local name = "EAM_RetailAlertIcon" .. (IconPool.created + 1)
    local button = api.CreateFrame("Frame", name, UIParent)
    button:SetSize(40, 40)
    button:Hide()

    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints(button)
    button.texture = texture

    local cooldown = api.CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    local setHideCountdownNumbers = getMethod(cooldown, "SetHideCountdownNumbers")
    if setHideCountdownNumbers then
        pcall(setHideCountdownNumbers, cooldown, true)
    end
    button.cooldown = cooldown
    IconPool.applyCooldownStyle(button, EAM.db and EAM.db.config or nil)
    cooldown:Hide()

    -- 建立高層級的文字與裝飾容器，徹底解決層級遮擋與 CDM 寄生裁切問題
    local overlay = api.CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    button.overlay = overlay

    -- 三種 C 層 StatusBar 預先建立；接收 Secret 後不再切換同一 bar 的 render mode。
    local horizontalCharge = createChargeVisual(overlay, "HORIZONTAL")
    horizontalCharge.host:SetSize(60, 8)
    horizontalCharge.host:SetPoint("TOP", button, "BOTTOM", 0, -2)
    local verticalCharge = createChargeVisual(overlay, "VERTICAL")
    verticalCharge.host:SetSize(8, 60)
    verticalCharge.host:SetPoint("LEFT", button, "RIGHT", 2, 0)
    local radialCharge = createChargeVisual(overlay, "RING")
    radialCharge.host:SetSize(60, 60)
    radialCharge.host:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.chargeVisuals = {
        HORIZONTAL = horizontalCharge,
        VERTICAL = verticalCharge,
        RING = radialCharge,
    }

    local chargeDividers = EAM.Util.tableCreate(MAX_CHARGE_DIVIDERS, 0)
    for index = 1, MAX_CHARGE_DIVIDERS do
        local divider = overlay:CreateTexture(nil, "OVERLAY")
        divider:SetTexture(CHARGE_BACKGROUND_TEXTURE)
        divider:SetVertexColor(0.92, 0.96, 1, 0.95)
        divider:Hide()
        chargeDividers[index] = divider
    end
    button.chargeDividers = chargeDividers

    local stackText = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    stackText:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -1, 1)
    button.stackText = stackText

    local nameText = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOP", overlay, "BOTTOM", 0, -2)
    button.nameText = nameText

    local timerText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    timerText:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    button.timerText = timerText

    local typeBorder = button:CreateTexture(nil, "BORDER")
    typeBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    typeBorder:SetBlendMode("BLEND")
    AlertBorderStyles.anchorTexture(typeBorder, button)
    typeBorder:Hide()
    button.typeBorder = typeBorder
    -- 🌡️ 內置安全、不帶 Taint 風險的 Pandemic 亮框 Gold Glow Overlay
    local glowBorder = button:CreateTexture(nil, "OVERLAY")
    glowBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glowBorder:SetBlendMode("ADD")
    glowBorder:SetAllPoints(button)
    glowBorder:SetVertexColor(1, 0.85, 0.4, 1) -- 亮金色
    glowBorder:Hide()
    button.glowBorder = glowBorder
    local glowAnimation
    local createAnimationGroup = getMethod(glowBorder, "CreateAnimationGroup")
    if createAnimationGroup then
        local ok, group = pcall(createAnimationGroup, glowBorder)
        local createAnimation = getMethod(group, "CreateAnimation")
        if ok and createAnimation then
            local animationOK, pulse = pcall(createAnimation, group, "Alpha")
            if animationOK and pulse then
                local setFromAlpha = getMethod(pulse, "SetFromAlpha")
                if setFromAlpha then
                    pcall(setFromAlpha, pulse, 0.35)
                end
                local setToAlpha = getMethod(pulse, "SetToAlpha")
                if setToAlpha then
                    pcall(setToAlpha, pulse, 1)
                end
                local setDuration = getMethod(pulse, "SetDuration")
                if setDuration then
                    pcall(setDuration, pulse, 0.6)
                end
                local setOrder = getMethod(pulse, "SetOrder")
                if setOrder then
                    pcall(setOrder, pulse, 1)
                end
                local setLooping = getMethod(group, "SetLooping")
                if setLooping then
                    pcall(setLooping, group, "BOUNCE")
                end
                glowAnimation = group
            end
        end
    end
    button.glowAnimation = glowAnimation

    local RadialGauge = EAM.UI.RadialGauge
    if RadialGauge and RadialGauge.create then
        button.radialGauge = RadialGauge.create(overlay, 40, {
            feather = 0.08,
            blendMode = "ADD",
        }) or false
    else
        button.radialGauge = false
    end

    button.rendered = {}
    button:EnableMouse(true)
    button:SetScript("OnEnter", showIconTooltip)
    button:SetScript("OnLeave", hideIconTooltip)
    IconPool.created = IconPool.created + 1
    return button
end

function IconPool.acquire()
    if EAM.addDebugLog then
        EAM.addDebugLog("IconPool", "acquire", "Acquiring icon frame, inactiveCount=" .. tostring(IconPool.inactiveCount))
    end
    if IconPool.inactiveCount > 0 then
        local icon = IconPool.inactive[IconPool.inactiveCount]
        IconPool.inactive[IconPool.inactiveCount] = nil
        IconPool.inactiveCount = IconPool.inactiveCount - 1
        IconPool.applyCooldownStyle(icon, EAM.db and EAM.db.config or nil)
        return icon
    end

    if api.InCombatLockdown and api.InCombatLockdown() then
        return nil, "combatPoolExhausted"
    end

    return createIcon()
end

function IconPool.release(icon)
    if not icon then
        return
    end

    icon:Hide()
    local rendered = icon.rendered
    if rendered then
        wipe(rendered)
    end

    if icon.timerBinding then
        local adapter = EAM.Modules.DurationAdapter
        if adapter then
            adapter.releaseTextBinding(icon.timerBinding)
        end
        icon.timerBinding = nil
    end
    if EAM.UI.Renderer and EAM.UI.Renderer.unregisterLegacyTimer then
        EAM.UI.Renderer.unregisterLegacyTimer(icon)
    end
    if icon.timerText then
        if icon.timerText.ClearText then
            icon.timerText:ClearText()
        else
            icon.timerText:SetText("")
        end
    end
    if icon.cooldown then
        local setCooldown = getMethod(icon.cooldown, "SetCooldown")
        if setCooldown then
            pcall(setCooldown, icon.cooldown, 0, 0)
        end
        icon.cooldown:Hide()
    end
    if icon.typeBorder then
        icon.typeBorder:Hide()
    end
    hideChargeVisuals(icon)
    local radialGauge = readField(icon, "radialGauge")
    if radialGauge then
        local RadialGauge = EAM.UI.RadialGauge
        if RadialGauge and RadialGauge.setVisible then
            RadialGauge.setVisible(radialGauge, false)
        end
    end
    IconPool.setGlow(icon, false)

    local count = IconPool.inactiveCount + 1
    IconPool.inactive[count] = icon
    IconPool.inactiveCount = count
end

function IconPool.prewarm(count)
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end

    count = count or IconPool.prewarmCount
    while IconPool.created < count do
        local icon = createIcon()
        IconPool.release(icon)
    end
    return true, IconPool.created
end
