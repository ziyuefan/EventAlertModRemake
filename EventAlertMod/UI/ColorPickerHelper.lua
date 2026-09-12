--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/ColorPickerHelper
檔案: UI\ColorPickerHelper.lua

責任:
- 封裝魔獸世界原生 ColorPickerFrame 調色盤呼叫，相容 12.x/11.x 現代 SetupColorPickerAndShow 與舊版降級。
- 提供色塊預覽按鈕 (Color Swatch Button) 建立工廠，支援即時顏色更新與懸停高亮。
- 嚴格守衛回呼參數，防止 Secret/Tainted 穿透。
]]

local _, EAM = ...

EAM.UI = EAM.UI or {}

local ColorPickerHelper = {}
EAM.UI.ColorPickerHelper = ColorPickerHelper

--- 開啟遊戲原生調色盤
--- @param opts table { r, g, b, a, hasOpacity, onColorChanged, onCancel }
function EAM.UI.openColorPicker(opts)
    if not opts then return end

    local initR = tonumber(opts.r) or 1.0
    local initG = tonumber(opts.g) or 1.0
    local initB = tonumber(opts.b) or 1.0
    local initA = tonumber(opts.a) or 1.0
    local hasOpacity = opts.hasOpacity or false
    local onColorChanged = opts.onColorChanged
    local onCancel = opts.onCancel

    local colorPicker = _G.ColorPickerFrame
    if not colorPicker then return end

    local function swatchCallback()
        local r, g, b = 1, 1, 1
        if colorPicker.GetColorRGB then
            r, g, b = colorPicker:GetColorRGB()
        end
        local a = 1.0
        if hasOpacity and _G.OpacitySliderFrame and _G.OpacitySliderFrame.GetValue then
            a = 1.0 - _G.OpacitySliderFrame:GetValue()
        end
        if onColorChanged then
            onColorChanged(r, g, b, a)
        end
    end

    local function cancelCallback(prev)
        local prevR = prev and prev.r or initR
        local prevG = prev and prev.g or initG
        local prevB = prev and prev.b or initB
        local prevA = prev and prev.a or initA
        if onCancel then
            onCancel(prevR, prevG, prevB, prevA)
        elseif onColorChanged then
            onColorChanged(prevR, prevG, prevB, prevA)
        end
    end

    if type(colorPicker.SetupColorPickerAndShow) == "function" then
        local info = {
            swatchFunc = swatchCallback,
            hasOpacity = hasOpacity,
            opacityFunc = swatchCallback,
            cancelFunc = cancelCallback,
            r = initR,
            g = initG,
            b = initB,
            opacity = hasOpacity and (1.0 - initA) or 0,
            previousValues = { r = initR, g = initG, b = initB, a = initA },
        }
        colorPicker:SetupColorPickerAndShow(info)
    else
        -- 舊版降級相容路徑
        colorPicker.func = swatchCallback
        colorPicker.hasOpacity = hasOpacity
        colorPicker.opacityFunc = swatchCallback
        colorPicker.cancelFunc = cancelCallback
        colorPicker.previousValues = { r = initR, g = initG, b = initB, a = initA }
        if colorPicker.SetColorRGB then
            colorPicker:SetColorRGB(initR, initG, initB)
        end
        colorPicker:Hide()
        colorPicker:Show()
    end
end

--- 建立通用色塊按鈕
--- @param parent Frame 父容器
--- @param width number 寬度
--- @param height number 高度
--- @param onClick function 點擊回呼
--- @return Button 色塊按鈕物件
function EAM.UI.createColorSwatchButton(parent, width, height, onClick)
    width = width or 24
    height = height or 24

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropBorderColor(0.8, 0.8, 0.8, 1.0)
    btn:SetBackdropColor(1, 1, 1, 1)

    local swatch = btn:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
    swatch:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
    swatch:SetColorTexture(1, 1, 1, 1)
    btn.swatch = swatch

    function btn:SetColor(r, g, b, a)
        swatch:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
    end

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.82, 0, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.8, 0.8, 0.8, 1.0)
    end)

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    return btn
end
