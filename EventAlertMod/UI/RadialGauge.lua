--[[ EAM_FILE_COMMENTARY
Module: UI/RadialGauge
檔案: UI\RadialGauge.lua

理念:
- 利用魔獸 12.1 原生 C++ 向量圓形進度條 (SetRadialProgressBarPercent) 繪製環形光環倒數。
- 零額外 CPU 負擔，支援平滑邊緣羽化 (Feathering) 與斬殺期 (Pandemic) 變色高亮。
- 在 12.0 或經典服無原生 API 時，自動平滑回退。

責任:
- 封裝 12.1 原生 Radial ProgressBar 的建立、配置與百分比刷新。
- 支援順逆時針、起始角度、羽化係數與動態色彩。

邊界:
- 只操作 UI 紋理屬性，不讀取 AuraData 或 Secret 內部結構。
]]

local _, EAM = ...
local Util = EAM.Util or {}

local RadialGauge = {
    nativeSupported = false,
    probed = false,
}

EAM.UI = EAM.UI or {}
EAM.UI.RadialGauge = RadialGauge

local RING_TEXTURE = "Interface\\AddOns\\EventAlertMod\\Textures\\ChargeRing128"

function RadialGauge.isSupported()
    if not RadialGauge.probed then
        if UIParent and UIParent.CreateTexture then
            local testTex = UIParent:CreateTexture(nil, "BACKGROUND")
            if testTex and type(testTex.SetRadialProgressBarPercent) == "function" then
                RadialGauge.nativeSupported = true
            end
            if testTex then
                testTex:Hide()
            end
        end
        RadialGauge.probed = true
    end
    return RadialGauge.nativeSupported
end

function RadialGauge.create(parent, size, options)
    if not parent then
        return nil
    end

    options = options or {}
    local tex = parent:CreateTexture(nil, options.drawLayer or "OVERLAY")
    tex:SetSize(size or 40, size or 40)
    tex:SetPoint("CENTER", parent, "CENTER", 0, 0)
    tex:SetTexture(options.texture or RING_TEXTURE)
    tex:SetBlendMode(options.blendMode or "ADD")

    local isNative = RadialGauge.isSupported()
    if isNative then
        pcall(tex.SetRadialProgressBarStartOffset, tex, options.startOffset or 0)
        pcall(tex.SetRadialProgressBarEndOffset, tex, options.endOffset or 1)
        pcall(tex.SetRadialProgressBarReverse, tex, options.reverse == true)
        pcall(tex.SetRadialProgressBarFeather, tex, options.feather or 0.08)
        pcall(tex.SetRadialProgressBarPercent, tex, 1.0)
    end

    local gauge = {
        texture = tex,
        parent = parent,
        isNative = isNative,
        active = false,
        lastPercent = 1.0,
    }

    return gauge
end

function RadialGauge.update(gauge, percent, isPandemic, r, g, b, a)
    if not gauge or not gauge.texture then
        return
    end

    percent = tonumber(percent) or 0
    if percent < 0 then
        percent = 0
    elseif percent > 1 then
        percent = 1
    end

    local tex = gauge.texture
    if gauge.isNative then
        pcall(tex.SetRadialProgressBarPercent, tex, percent)
    end

    if isPandemic then
        -- 斬殺/刷新期: 琥珀金高亮
        tex:SetVertexColor(1.0, 0.82, 0.0, a or 0.95)
    elseif r and g and b then
        tex:SetVertexColor(r, g, b, a or 0.85)
    else
        -- 預設水藍色光環
        tex:SetVertexColor(0.2, 0.8, 1.0, a or 0.85)
    end

    gauge.lastPercent = percent
end

function RadialGauge.setVisible(gauge, visible)
    if not gauge or not gauge.texture then
        return
    end
    if visible then
        gauge.texture:Show()
        gauge.active = true
    else
        gauge.texture:Hide()
        gauge.active = false
    end
end
