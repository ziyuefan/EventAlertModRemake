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
    if unit == "pet" then
        return keys.petAlert
    end
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
    if frameName == frameTypes.petAlert then
        return keys.petAlert
    end
    return nil
end

function AlertBorderStyles.getColor(styleKey)
    local config = EAM.db and EAM.db.config
    if config then
        if config.showBorder == false then
            return nil
        end
        local borderEnabled = config.borderEnabled
        if borderEnabled and borderEnabled[styleKey] == false then
            return nil
        end
        local borderColors = config.borderColors
        if borderColors and borderColors[styleKey] then
            local c = borderColors[styleKey]
            if type(c) == "table" and c[1] and c[2] and c[3] then
                if (c[4] or 1.0) <= 0.001 then
                    return nil
                end
                return c
            end
        end
    end
    if styleKey == keys.selfHelpful then return colors.selfHelpful end
    if styleKey == keys.selfHarmful then return colors.selfHarmful end
    if styleKey == keys.targetHelpful then return colors.targetHelpful end
    if styleKey == keys.targetHarmful then return colors.targetHarmful end
    if styleKey == keys.spellCooldown then return colors.spellCooldown end
    if styleKey == keys.itemCooldown then return colors.itemCooldown end
    if styleKey == keys.groundEffect then return colors.groundEffect end
    if styleKey == keys.petAlert then return colors.petAlert end
    return nil
end

local BORDER_LINE_THICKNESS = 2

function AlertBorderStyles.createBorder(owner, drawLayer, thickness, padding)
    if not owner or type(owner.CreateTexture) ~= "function" then
        return nil
    end
    thickness = (Util.isSafePositiveNumber(thickness) and thickness) or BORDER_LINE_THICKNESS
    padding = (Util.isSafeNumber(padding) and padding) or 0
    drawLayer = drawLayer or "OVERLAY"

    local host = owner
    local getFrameLevel = nil
    local okLevel, fnLevel = pcall(function() return owner.GetFrameLevel end)
    if okLevel and type(fnLevel) == "function" then
        getFrameLevel = fnLevel
    end

    if getFrameLevel then
        local okHost, borderHost = pcall(function()
            if not owner.eamBorderHost then
                local bh = (Util and Util.createFrame and Util.createFrame("Frame", nil, owner)) or (EAM.API and EAM.API.CreateFrame and EAM.API.CreateFrame("Frame", nil, owner)) or CreateFrame("Frame", nil, owner)
                if bh then
                    bh:SetAllPoints(owner)
                    local baseLevel = getFrameLevel(owner) or 1
                    bh:SetFrameLevel(baseLevel + 8)
                    if bh.Show then
                        bh:Show()
                    end
                    owner.eamBorderHost = bh
                end
            else
                local baseLevel = getFrameLevel(owner) or 1
                owner.eamBorderHost:SetFrameLevel(baseLevel + 8)
            end
            return owner.eamBorderHost
        end)
        if okHost and borderHost then
            host = borderHost
        end
    end

    local top = host:CreateTexture(nil, drawLayer, nil, 6)
    local bottom = host:CreateTexture(nil, drawLayer, nil, 6)
    local left = host:CreateTexture(nil, drawLayer, nil, 6)
    local right = host:CreateTexture(nil, drawLayer, nil, 6)

    local function setupLine(line)
        if type(line.SetColorTexture) == "function" then
            line:SetColorTexture(1, 1, 1, 1)
        elseif type(line.SetTexture) == "function" then
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
        end
        if type(line.Hide) == "function" then
            line:Hide()
        end
    end
    setupLine(top)
    setupLine(bottom)
    setupLine(left)
    setupLine(right)

    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", owner, "TOPLEFT", -padding, padding)
    top:SetPoint("TOPRIGHT", owner, "TOPRIGHT", padding, padding)
    top:SetHeight(thickness)

    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", -padding, -padding)
    bottom:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", padding, -padding)
    bottom:SetHeight(thickness)

    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", owner, "TOPLEFT", -padding, padding)
    left:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", -padding, -padding)
    left:SetWidth(thickness)

    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", owner, "TOPRIGHT", padding, padding)
    right:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", padding, -padding)
    right:SetWidth(thickness)

    if Util and Util.snapToPixels then
        Util.snapToPixels(host)
        Util.snapToPixels(top)
        Util.snapToPixels(bottom)
        Util.snapToPixels(left)
        Util.snapToPixels(right)
    end

    local chrome = {
        host = host,
        top = top,
        bottom = bottom,
        left = left,
        right = right,
        isBorderChrome = true,
        thickness = thickness,
        padding = padding,
        shown = false,
        vertexColor = nil,
    }

    function chrome:SetVertexColor(r, g, b, a)
        self.vertexColor = { r, g, b, a }
        if type(self.top.SetVertexColor) == "function" then
            self.top:SetVertexColor(r, g, b, a)
            self.bottom:SetVertexColor(r, g, b, a)
            self.left:SetVertexColor(r, g, b, a)
            self.right:SetVertexColor(r, g, b, a)
        end
    end

    function chrome:Show()
        self.shown = true
        if self.host and self.host ~= owner and self.host.Show then
            self.host:Show()
        end
        self.top:Show()
        self.bottom:Show()
        self.left:Show()
        self.right:Show()
    end

    function chrome:Hide()
        self.shown = false
        if self.host and self.host ~= owner and self.host.Hide then
            self.host:Hide()
        end
        self.top:Hide()
        self.bottom:Hide()
        self.left:Hide()
        self.right:Hide()
    end

    function chrome:SetShown(shown)
        if shown then self:Show() else self:Hide() end
    end

    function chrome:IsShown()
        return self.shown == true
    end

    function chrome:SetColorTexture(r, g, b, a)
        self.vertexColor = { r, g, b, a }
        if type(self.top.SetColorTexture) == "function" then
            self.top:SetColorTexture(r, g, b, a)
            self.bottom:SetColorTexture(r, g, b, a)
            self.left:SetColorTexture(r, g, b, a)
            self.right:SetColorTexture(r, g, b, a)
        end
    end

    function chrome:SetTexture(tex)
        if type(self.top.SetTexture) == "function" then
            self.top:SetTexture(tex)
            self.bottom:SetTexture(tex)
            self.left:SetTexture(tex)
            self.right:SetTexture(tex)
        end
    end

    function chrome:SetBlendMode(mode)
        if type(self.top.SetBlendMode) == "function" then
            self.top:SetBlendMode(mode)
            self.bottom:SetBlendMode(mode)
            self.left:SetBlendMode(mode)
            self.right:SetBlendMode(mode)
        end
    end

    function chrome:ClearAllPoints()
    end

    function chrome:SetPoint(...)
    end

    return chrome
end

function AlertBorderStyles.anchorTexture(texture, owner)
    if not texture or not owner then
        return false, "anchorUnavailable"
    end
    if texture.isBorderChrome then
        return true, texture.padding or 0
    end
    if type(texture.ClearAllPoints) ~= "function"
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
    texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1.0)
    if type(texture.Show) == "function" then
        texture:Show()
    end
    return true, styleKey
end

function AlertBorderStyles.refreshAll()
    local IconPool = EAM.UI and EAM.UI.IconPool
    local Renderer = EAM.UI and EAM.UI.Renderer
    if Renderer and Renderer.frames and IconPool and IconPool.applyTypeBorder then
        for frameName, fState in pairs(Renderer.frames) do
            for _, icon in pairs(fState.icons or {}) do
                if icon and icon.typeBorder then
                    if icon.rendered then
                        icon.rendered.borderStyleKey = nil
                    end
                    IconPool.applyTypeBorder(icon, icon.alertState, frameName)
                end
            end
        end
    end
    local NativeAuraRenderer = EAM.UI and EAM.UI.NativeAuraRenderer
    if NativeAuraRenderer and type(NativeAuraRenderer.refreshBorders) == "function" then
        pcall(NativeAuraRenderer.refreshBorders)
    end
end
