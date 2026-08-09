--[[
檔案: UI\AlertBorderStyles.lua

理念:
- 以單一不可變色盤統一 Legacy IconPool 與 12.1 Native AuraButton 的類型邊框。
- 邊框分類只依 SavedVariables 編譯結果與 EAM 框架類型，不讀取戰鬥中的 Secret Aura facts。

責任:
- 將 unit、auraFilter 與 alert frame type 正規化為固定樣式鍵。
- 將固定 RGBA 套用到 EAM 自有 Texture。

邊界:
- 不建立 Frame，不 Hook Blizzard UI，不讀 UnitAura。
- classPower 與 totem 尚無指定色，回傳 nil 以保留既有外觀。
]]
local _, EAM = ...

EAM.UI = EAM.UI or {}

local Util = EAM.Util
local Constants = EAM.Constants
local keys = Constants.ALERT_BORDER_STYLE_KEYS
local colors = Constants.ALERT_BORDER_COLORS
local BORDER_TEXTURE_PADDING = 3

local AlertBorderStyles = {}
EAM.UI.AlertBorderStyles = AlertBorderStyles

local function normalizePolarity(unit, auraFilter)
    if Util.isSafeString(auraFilter) then
        if string.find(auraFilter, "HARMFUL", 1, true) == 1 then
            return "HARMFUL"
        end
        if string.find(auraFilter, "HELPFUL", 1, true) == 1 then
            return "HELPFUL"
        end
    end
    return unit == "target" and "HARMFUL" or "HELPFUL"
end

function AlertBorderStyles.resolveAura(unit, auraFilter)
    if unit ~= "player" and unit ~= "target" then
        return nil
    end
    local polarity = normalizePolarity(unit, auraFilter)
    if unit == "player" then
        return polarity == "HARMFUL" and keys.selfHarmful or keys.selfHelpful
    end
    return polarity == "HARMFUL" and keys.targetHarmful or keys.targetHelpful
end

function AlertBorderStyles.resolve(frameName, alertState)
    local frameTypes = Constants.ALERT_FRAME_TYPES
    if frameName == frameTypes.selfAura then
        return AlertBorderStyles.resolveAura("player", alertState and alertState.auraFilter or nil)
    end
    if frameName == frameTypes.targetAura then
        return AlertBorderStyles.resolveAura("target", alertState and alertState.auraFilter or nil)
    end
    if frameName == frameTypes.spellCooldown then
        return keys.spellCooldown
    end
    if frameName == frameTypes.itemCooldown then
        return keys.itemCooldown
    end
    if frameName == frameTypes.groundEffect then
        return keys.groundEffect
    end
    return nil
end

function AlertBorderStyles.getColor(styleKey)
    if styleKey == keys.selfHelpful then return colors.selfHelpful end
    if styleKey == keys.selfHarmful then return colors.selfHarmful end
    if styleKey == keys.targetHelpful then return colors.targetHelpful end
    if styleKey == keys.targetHarmful then return colors.targetHarmful end
    if styleKey == keys.spellCooldown then return colors.spellCooldown end
    if styleKey == keys.itemCooldown then return colors.itemCooldown end
    if styleKey == keys.groundEffect then return colors.groundEffect end
    return nil
end

function AlertBorderStyles.anchorTexture(texture, owner)
    if not texture or not owner
        or type(texture.ClearAllPoints) ~= "function"
        or type(texture.SetPoint) ~= "function"
    then
        return false, "anchorUnavailable"
    end
    texture:ClearAllPoints()
    texture:SetPoint(
        "TOPLEFT",
        owner,
        "TOPLEFT",
        -BORDER_TEXTURE_PADDING,
        BORDER_TEXTURE_PADDING
    )
    texture:SetPoint(
        "BOTTOMRIGHT",
        owner,
        "BOTTOMRIGHT",
        BORDER_TEXTURE_PADDING,
        -BORDER_TEXTURE_PADDING
    )
    return true, BORDER_TEXTURE_PADDING
end

AlertBorderStyles.borderTexturePadding = BORDER_TEXTURE_PADDING

function AlertBorderStyles.apply(texture, styleKey)
    if not texture then
        return false, "textureUnavailable"
    end
    local color = AlertBorderStyles.getColor(styleKey)
    if not color or type(texture.SetVertexColor) ~= "function" then
        if type(texture.Hide) == "function" then
            texture:Hide()
        end
        return false, "styleUnavailable"
    end
    texture:SetVertexColor(color[1], color[2], color[3], color[4])
    if type(texture.Show) == "function" then
        texture:Show()
    end
    return true, styleKey
end
