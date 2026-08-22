--[[ EAM_FILE_COMMENTARY
Module: UI/NativeAuraRenderer

責任:
- 為每條 Native Aura rule 建立 initializeFrame callback。
- 僅在 Blizzard 允許的初始化窗口建立、定位並綁定 AuraButton 子元件。

禁止事項:
- AuraButton 註冊完成後不得再改其子元件、錨點、大小或綁定。
- 不讀 AuraData、不讀 FontString 文字、不以 OnShow/OnHide 推導事實、不建立 OnUpdate。
]]

local _, EAM = ...
local api = EAM.API
local TextPlacement = EAM.UI.TextPlacement
local AlertBorderStyles = EAM.UI.AlertBorderStyles

local NativeAuraRenderer = {
    initializedButtonCount = 0,
    textLayoutApplyCount = 0,
    nativeBorderCapabilityCount = 0,
    dualCountdownButtonCount = 0,
    nativePandemicRegionCapabilityCount = 0,
    pandemicRegionBoundCount = 0,
    nativeDispelTextureBoundCount = 0,
}

EAM.UI = EAM.UI or {}
EAM.UI.NativeAuraRenderer = NativeAuraRenderer

local function safePositive(value, fallback)
    if EAM.Util.isSafePositiveNumber(value) then
        return value
    end
    return fallback
end

local function safeAlpha(value)
    if not EAM.Util.isSafeNumber(value) then
        return 1
    end
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end
    return value
end

local function snapshotStyle(rule)
    local config = EAM.db and EAM.db.config or nil
    local ruleStyle = rule and rule.style or nil
    return {
        iconSize = safePositive(config and config.iconSize, 40),
        nameFontSize = safePositive(config and config.fontSizeSpellName, 12),
        fontFamily = TextPlacement.getFontFamily(config),
        timerFontSize = TextPlacement.getFontSize(config, "timer"),
        applicationsFontSize = TextPlacement.getFontSize(config, "applications"),
        timerPlacement = TextPlacement.getPlacement(config, "timer"),
        applicationsPlacement = TextPlacement.getPlacement(config, "applications"),
        swipeAlpha = safeAlpha(config and config.cooldownSwipeAlpha),
        borderStyleKey = AlertBorderStyles.resolveAura(rule and rule.unit or nil, rule and rule.filterString or nil),
        dualCountdownProbe = config and config.nativeAuraDualCountdownProbe == true or false,
        showCountdown = not ruleStyle or ruleStyle.showCountdown ~= false,
        showStacks = not ruleStyle or ruleStyle.showStacks ~= false,
        showName = not ruleStyle or ruleStyle.showName ~= false,
        showPandemic = ruleStyle and ruleStyle.showPandemic == true or false,
        dispelMode = ruleStyle and ruleStyle.dispelMode or nil,
        dispelShowAlways = ruleStyle and ruleStyle.dispelShowAlways == true or false,
        dispelStealableFilter = ruleStyle and ruleStyle.dispelStealableFilter or nil,
        dispelStyle = ruleStyle and ruleStyle.dispelStyle or nil,
    }
end

local function getDispelOptions(style)
    local options = {
        showAlways = style.dispelShowAlways == true or style.dispelMode == "ALWAYS",
        showWhenHarmful = false,
        showWhenHelpful = false,
        showWithoutDispelType = false,
    }
    local mode = style.dispelMode
    if not options.showAlways then
        if mode == "HARMFUL" then
            options.showWhenHarmful = true
        elseif mode == "HELPFUL" then
            options.showWhenHelpful = true
        elseif mode == "ANY_DISPEL" then
            options.showWhenHarmful = true
            options.showWhenHelpful = true
        elseif mode == "NO_DISPEL" then
            options.showWithoutDispelType = true
        elseif mode == "STEALABLE" or mode == "NOT_STEALABLE" then
            options.showWhenHelpful = true
        else
            return nil
        end
    end

    local filterEnum = Enum and Enum.CustomAuraButtonDispelTypeStealableFilter or nil
    if filterEnum then
        if mode == "STEALABLE" then
            options.stealableFilter = filterEnum.Stealable
        elseif mode == "NOT_STEALABLE" then
            options.stealableFilter = filterEnum.NotStealable
        elseif style.dispelStealableFilter == "STEALABLE" then
            options.stealableFilter = filterEnum.Stealable
        elseif style.dispelStealableFilter == "NOT_STEALABLE" then
            options.stealableFilter = filterEnum.NotStealable
        end
    end

    local styleEnum = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle or nil
    if styleEnum then
        local styleKey = style.dispelStyle
        if styleKey == "BORDER" then
            options.style = styleEnum.Border
        elseif styleKey == "ICON" then
            options.style = styleEnum.Icon
        elseif styleKey == "PRESERVE_ASSET" then
            options.style = styleEnum.PreserveAsset
        elseif styleKey == "CUSTOM_ASSET" then
            options.style = styleEnum.CustomAsset
        else
            options.style = styleEnum.BorderWithIcon
        end
    end
    return options
end

local function bindPandemicRegion(auraButton, style)
    local hasAPI = type(auraButton.AddPandemicRegion) == "function"
        and type(auraButton.RemovePandemicRegion) == "function"
        and type(auraButton.ClearPandemicRegions) == "function"
    if hasAPI then
        NativeAuraRenderer.nativePandemicRegionCapabilityCount =
            NativeAuraRenderer.nativePandemicRegionCapabilityCount + 1
    end
    if not style.showPandemic or not hasAPI then
        return false
    end

    local region = auraButton:CreateTexture(nil, "OVERLAY")
    region:SetAllPoints(auraButton)
    if type(region.SetColorTexture) == "function" then
        region:SetColorTexture(1, 0.72, 0.12, 0.85)
    end
    local ok = pcall(auraButton.AddPandemicRegion, auraButton, region)
    if ok then
        NativeAuraRenderer.pandemicRegionBoundCount =
            NativeAuraRenderer.pandemicRegionBoundCount + 1
        return true
    end
    return false
end

local function bindDispelTypeTexture(auraButton, style)
    local hasAPI = type(auraButton.AddDispelTypeTexture) == "function"
        and type(auraButton.RemoveDispelTypeTexture) == "function"
        and type(auraButton.ClearDispelTypeTextures) == "function"
    if hasAPI then
        NativeAuraRenderer.nativeBorderCapabilityCount =
            NativeAuraRenderer.nativeBorderCapabilityCount + 1
    end
    local options = getDispelOptions(style)
    if not hasAPI or not options then
        return false
    end

    local texture = auraButton:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(auraButton)
    local ok = pcall(auraButton.AddDispelTypeTexture, auraButton, texture, options)
    if ok then
        NativeAuraRenderer.nativeDispelTextureBoundCount =
            NativeAuraRenderer.nativeDispelTextureBoundCount + 1
        return true
    end
    return false
end
local function applySlotAnchor(auraButton, container, slotIndex, layout)
    if not slotIndex then
        return
    end
    local width = layout and layout.elementWidth or 40
    local spacing = layout and layout.elementSpacing or 6
    auraButton:ClearAllPoints()
    auraButton:SetPoint("TOPLEFT", container, "TOPLEFT", (slotIndex - 1) * (width + spacing), 0)
end

local function initializeButton(auraButton, rule, container, slotIndex, style)
    if not auraButton or auraButton.eamNativeInitialized then
        return
    end

    auraButton:SetSize(style.iconSize, style.iconSize)
    applySlotAnchor(auraButton, container, slotIndex, rule and rule.layout)

    local icon = auraButton:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(auraButton)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local typeBorder = auraButton:CreateTexture(nil, "BORDER")
    typeBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    typeBorder:SetBlendMode("BLEND")
    AlertBorderStyles.anchorTexture(typeBorder, auraButton)
    AlertBorderStyles.apply(typeBorder, style.borderStyleKey)
    auraButton.eamTypeBorder = typeBorder
    local cooldown = api.CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
    cooldown:SetAllPoints(auraButton)
    if type(cooldown.SetHideCountdownNumbers) == "function" then
        cooldown:SetHideCountdownNumbers(not style.dualCountdownProbe)
    end
    if type(cooldown.SetSwipeColor) == "function" then
        cooldown:SetSwipeColor(1, 1, 1, style.swipeAlpha)
    end

    local timerText = auraButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
    local stackText = auraButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
    local nameText = auraButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
    nameText:SetPoint("TOP", auraButton, "BOTTOM", 0, -2)

    TextPlacement.apply(timerText, auraButton, style.timerPlacement)
    TextPlacement.applyFont(timerText, style.timerFontSize, style.fontFamily)
    TextPlacement.apply(stackText, auraButton, style.applicationsPlacement)
    TextPlacement.applyFont(stackText, style.applicationsFontSize, style.fontFamily)
    TextPlacement.applyFont(nameText, style.nameFontSize, style.fontFamily)

    auraButton:SetIcon(icon)
    auraButton:SetDurationCooldown(cooldown)
    if style.showCountdown or style.dualCountdownProbe then
        auraButton:SetDurationText(timerText)
    else
        timerText:Hide()
    end
    if style.showStacks then
        auraButton:SetApplicationCount(stackText)
    else
        stackText:Hide()
    end
    if style.showName then
        auraButton:SetSpellName(nameText)
    else
        nameText:Hide()
    end
    if type(auraButton.SetHideTooltipInCombat) == "function" then
        auraButton:SetHideTooltipInCombat(true)
    end

    bindPandemicRegion(auraButton, style)
    bindDispelTypeTexture(auraButton, style)
    if style.dualCountdownProbe then
        NativeAuraRenderer.dualCountdownButtonCount =
            NativeAuraRenderer.dualCountdownButtonCount + 1
    end

    auraButton.eamNativeInitialized = true
    NativeAuraRenderer.initializedButtonCount =
        NativeAuraRenderer.initializedButtonCount + 1
    NativeAuraRenderer.textLayoutApplyCount =
        NativeAuraRenderer.textLayoutApplyCount + 1
end

function NativeAuraRenderer.createInitializer(rule, container, slotIndex)
    local style = snapshotStyle(rule)
    return function(auraButton)
        initializeButton(auraButton, rule, container, slotIndex, style)
    end
end

function NativeAuraRenderer.applyTextLayout()
    return false, "nativeRebuildRequired"
end

function NativeAuraRenderer.onCombatEnd()
    return true, "noPostInitializationMutation"
end

function NativeAuraRenderer.anchorSlot()
    return false, "initializeFrameOnly"
end

function NativeAuraRenderer.getStatus()
    local config = EAM.db and EAM.db.config or nil
    return {
        initializedButtonCount = NativeAuraRenderer.initializedButtonCount,
        trackedButtonCount = 0,
        textLayoutPending = false,
        textLayoutApplyCount = NativeAuraRenderer.textLayoutApplyCount,
        nativeBorderCapabilityCount = NativeAuraRenderer.nativeBorderCapabilityCount,
        nativeDispelBorderAvailable = NativeAuraRenderer.nativeBorderCapabilityCount > 0,
        hasPandemicRegionAPI = NativeAuraRenderer.nativePandemicRegionCapabilityCount > 0,
        nativePandemicRegionCapabilityCount = NativeAuraRenderer.nativePandemicRegionCapabilityCount,
        pandemicRegionBoundCount = NativeAuraRenderer.pandemicRegionBoundCount,
        nativeDispelTextureBoundCount = NativeAuraRenderer.nativeDispelTextureBoundCount,
        blizzardPandemicOnUpdateManaged = NativeAuraRenderer.pandemicRegionBoundCount > 0,
        dualCountdownProbeEnabled = config and config.nativeAuraDualCountdownProbe == true or false,
        dualCountdownButtonCount = NativeAuraRenderer.dualCountdownButtonCount,
        postInitializationMutationEnabled = false,
        usesAuraState = false,
        usesOnUpdate = false,
    }
end
