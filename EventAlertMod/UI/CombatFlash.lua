--[[
檔案: UI\CombatFlash.lua

理念:
- 實作經典進入戰鬥全螢幕紅框閃爍 (Full Screen Red Flash on Combat Enter)。
- 當玩家進入戰鬥 (PLAYER_REGEN_DISABLED) 且 showFlash 開啟時，以低血/紅光脈衝閃爍提醒。

責任:
- 監聽 PLAYER_REGEN_DISABLED 事件。
- 檢查 SavedVariables 的 showFlash 設定。
- 驅動原生 LowHealthFrame 或自建安全全螢幕漸層動畫 (EAM_CombatFlashFrame)。

邊界:
- 不干涉戰鬥中的按鈕點擊與技能施放。
- 不阻擋玩家視野（採用低延時平滑淡出與 ADD 混色）。
]]
local _, EAM = ...

EAM.UI = EAM.UI or {}

local api = EAM.API or {}
local CombatFlash = {
    frame = nil,
    animGroup = nil,
}
EAM.UI.CombatFlash = CombatFlash

local function createFlashFrame()
    if CombatFlash.frame then
        return CombatFlash.frame
    end

    local parent = _G.UIParent
    if not parent then return nil end

    local frame = api.CreateFrame and api.CreateFrame("Frame", "EAM_CombatFlashFrame", parent)
    if not frame then return nil end

    frame:SetAllPoints(parent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(false)
    frame:Hide()

    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(frame)
    local texPath = "Interface\\FullScreenTextures\\LowHealth"
    texture:SetTexture(texPath)
    texture:SetBlendMode("ADD")
    texture:SetVertexColor(1, 0.1, 0.1, 0.85)
    frame.texture = texture

    if frame.CreateAnimationGroup then
        local ag = frame:CreateAnimationGroup()
        local a1 = ag:CreateAnimation("Alpha")
        a1:SetFromAlpha(0)
        a1:SetToAlpha(0.85)
        a1:SetDuration(0.15)
        a1:SetOrder(1)

        local a2 = ag:CreateAnimation("Alpha")
        a2:SetFromAlpha(0.85)
        a2:SetToAlpha(0)
        a2:SetDuration(0.65)
        a2:SetOrder(2)

        ag:SetScript("OnFinished", function()
            frame:Hide()
        end)
        CombatFlash.animGroup = ag
    end

    CombatFlash.frame = frame
    return frame
end

function CombatFlash.trigger()
    local lhf = _G.LowHealthFrame
    local uiFadeIn = _G.UIFrameFadeIn
    local uiFadeOut = _G.UIFrameFadeOut
    if lhf and type(uiFadeIn) == "function" and type(uiFadeOut) == "function" then
        local ok = pcall(function()
            uiFadeIn(lhf, 0.15, 0, 1)
            uiFadeOut(lhf, 0.65, 1, 0)
        end)
        if ok then
            return true, "blizzard"
        end
    end

    local frame = createFlashFrame()
    if frame then
        frame:Show()
        if CombatFlash.animGroup then
            CombatFlash.animGroup:Stop()
            CombatFlash.animGroup:Play()
        elseif type(uiFadeIn) == "function" and type(uiFadeOut) == "function" then
            uiFadeIn(frame, 0.15, 0, 0.85)
            uiFadeOut(frame, 0.65, 0.85, 0)
        else
            frame:SetAlpha(0.85)
            if C_Timer and C_Timer.After then
                C_Timer.After(0.6, function()
                    if frame then frame:Hide() end
                end)
            else
                frame:Hide()
            end
        end
        return true, "custom"
    end
    return false, "unavailable"
end

local function onCombatEnter()
    local saved = EAM.Modules and EAM.Modules.SavedVariables
    local config = saved and type(saved.get) == "function" and saved.get()
    local showFlash = config and config.general and config.general.showFlash
    if showFlash == nil and config and config.config then
        showFlash = config.config.showFlash
    end
    if showFlash == nil then
        showFlash = true
    end

    if showFlash then
        CombatFlash.trigger()
    end
end

local function buildLowHealthCurve(threshold)
    local th = threshold or 0.35
    local cCurveUtil = api.C_CurveUtil or _G.C_CurveUtil
    if not cCurveUtil or type(cCurveUtil.CreateCurve) ~= "function" then
        return nil
    end
    local ok, curve = pcall(cCurveUtil.CreateCurve)
    if not ok or not curve or type(curve.AddPoint) ~= "function" then
        return nil
    end
    local curveType = api.LuaCurveType or (_G.Enum and _G.Enum.LuaCurveType)
    if curveType and curveType.Linear and type(curve.SetType) == "function" then
        pcall(curve.SetType, curve, curveType.Linear)
    end
    pcall(curve.AddPoint, curve, 0.0, 0.95)
    pcall(curve.AddPoint, curve, th * 0.5, 0.65)
    pcall(curve.AddPoint, curve, th, 0.20)
    pcall(curve.AddPoint, curve, th + 0.001, 0.0)
    pcall(curve.AddPoint, curve, 1.0, 0.0)
    return curve
end

function CombatFlash.getLowHealthFrame()
    if CombatFlash.lowHealthFrame then
        return CombatFlash.lowHealthFrame
    end
    local parent = _G.UIParent
    if not parent then return nil end

    local frame = api.CreateFrame and api.CreateFrame("Frame", "EAM_LowHealthWarningFrame", parent)
    if not frame then return nil end

    frame:SetAllPoints(parent)
    frame:SetFrameStrata("BACKGROUND")
    frame:EnableMouse(false)
    frame:Hide()

    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(frame)
    texture:SetTexture("Interface\\FullScreenTextures\\LowHealth")
    texture:SetBlendMode("ADD")
    texture:SetVertexColor(1, 0.05, 0.05, 1)
    frame.texture = texture

    CombatFlash.lowHealthFrame = frame
    return frame
end

local function onHealthUpdate(unit)
    if unit and unit ~= "player" then return end
    local saved = EAM.Modules and EAM.Modules.SavedVariables
    local cfg = saved and type(saved.get) == "function" and saved.get()
    local config = cfg and (cfg.config or cfg)
    if not config or config.lowHealthFlash == false then
        if CombatFlash.lowHealthFrame and CombatFlash.lowHealthFrame:IsShown() then
            CombatFlash.lowHealthFrame:Hide()
        end
        return
    end

    local th = config.lowHealthThreshold or 0.35
    if not CombatFlash.healthCurve or CombatFlash.cachedThreshold ~= th then
        CombatFlash.healthCurve = buildLowHealthCurve(th)
        CombatFlash.cachedThreshold = th
    end

    local alpha = 0
    if _G.UnitHealthPercent and CombatFlash.healthCurve then
        local ok, val = pcall(_G.UnitHealthPercent, "player", true, CombatFlash.healthCurve)
        if ok and type(val) == "number" then
            alpha = val
        end
    elseif _G.UnitHealth and _G.UnitHealthMax then
        local cur = _G.UnitHealth("player")
        local maxH = _G.UnitHealthMax("player")
        if cur and maxH and maxH > 0 then
            local pct = cur / maxH
            if CombatFlash.healthCurve then
                alpha = CombatFlash.healthCurve:Evaluate(pct)
            elseif pct <= th then
                alpha = (1 - (pct / th)) * 0.8 + 0.15
            end
        end
    end

    local frame = CombatFlash.getLowHealthFrame()
    if not frame then return end

    if alpha and alpha > 0.05 then
        frame:Show()
        frame:SetAlpha(math.min(alpha, 0.95))
    else
        frame:Hide()
    end
end

local function onCombatLeave()
    if CombatFlash.lowHealthFrame and CombatFlash.lowHealthFrame:IsShown() then
        CombatFlash.lowHealthFrame:Hide()
    end
end

CombatFlash.onCombatEnter = onCombatEnter
CombatFlash.onCombatLeave = onCombatLeave
CombatFlash.onHealthUpdate = onHealthUpdate

local router = EAM.Modules and EAM.Modules.EventRouter
if router and type(router.register) == "function" then
    router.register("PLAYER_REGEN_DISABLED", onCombatEnter)
    router.register("PLAYER_REGEN_ENABLED", onCombatLeave)
    router.register("UNIT_HEALTH", onHealthUpdate)
    router.register("UNIT_MAXHEALTH", onHealthUpdate)
end
