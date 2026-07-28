--[[ EAM_FILE_COMMENTARY
Module: UI/NativeAuraRenderer

責任:
- 僅在 AuraContainer initializeFrame 階段建立並綁定顯示 Region。
- 由 Blizzard AuraButton 接管圖示、DurationObject、層數與 Tooltip 更新。

禁止事項:
- 不讀 AuraData、不以 OnShow/OnHide/IsShown 推導狀態、不建立 OnUpdate。
- 不進入 AlertManager、Renderer 或 Scheduler 的 Aura 熱路徑。
]]

local _, EAM = ...
local api = EAM.API

local NativeAuraRenderer = {
    initializedButtonCount = 0,
}

EAM.UI = EAM.UI or {}
EAM.UI.NativeAuraRenderer = NativeAuraRenderer

local function safeConfigNumber(value, fallback)
    if EAM.Util.isSafePositiveNumber(value) then
        return value
    end
    return fallback
end

function NativeAuraRenderer.initializeFrame(auraButton)
    if not auraButton or auraButton.eamNativeRegions then
        return
    end

    local config = EAM.db and EAM.db.config or nil
    local iconSize = safeConfigNumber(config and config.iconSize, 40)
    local nameSize = safeConfigNumber(config and config.fontSizeSpellName, 12)
    local timerSize = safeConfigNumber(config and config.fontSizeTimeVal, 14)
    local stackSize = safeConfigNumber(config and config.fontSizeStack, 12)

    auraButton:SetSize(iconSize, iconSize)

    local icon = auraButton:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(auraButton)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local cooldown = api.CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
    cooldown:SetAllPoints(auraButton)

    local timerText = auraButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
    timerText:SetPoint("CENTER", auraButton, "CENTER", 0, 0)
    timerText:SetFont(STANDARD_TEXT_FONT, timerSize, "OUTLINE")

    local stackText = auraButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightOutline")
    stackText:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", -2, 2)
    stackText:SetFont(STANDARD_TEXT_FONT, stackSize, "OUTLINE")

    local nameText = auraButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
    nameText:SetPoint("TOP", auraButton, "BOTTOM", 0, -2)
    nameText:SetFont(STANDARD_TEXT_FONT, nameSize, "OUTLINE")

    auraButton:SetIcon(icon)
    auraButton:SetDurationCooldown(cooldown)
    auraButton:SetDurationText(timerText)
    auraButton:SetApplicationCount(stackText)
    auraButton:SetSpellName(nameText)
    if auraButton.SetHideTooltipInCombat then
        auraButton:SetHideTooltipInCombat(true)
    end

    auraButton.eamNativeRegions = {
        icon = icon,
        cooldown = cooldown,
        timerText = timerText,
        stackText = stackText,
        nameText = nameText,
    }
    NativeAuraRenderer.initializedButtonCount = NativeAuraRenderer.initializedButtonCount + 1
end

function NativeAuraRenderer.anchorSlot(auraButton, container, index, layout)
    if not auraButton or not container then
        return
    end
    local width = layout and layout.elementWidth or 40
    local spacing = layout and layout.elementSpacing or 6
    auraButton:ClearAllPoints()
    auraButton:SetPoint("TOPLEFT", container, "TOPLEFT", (index - 1) * (width + spacing), 0)
end

function NativeAuraRenderer.getStatus()
    return {
        initializedButtonCount = NativeAuraRenderer.initializedButtonCount,
        usesAuraState = false,
        usesOnUpdate = false,
    }
end
