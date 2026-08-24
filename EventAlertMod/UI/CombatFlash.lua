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

CombatFlash.onCombatEnter = onCombatEnter

local router = EAM.Modules and EAM.Modules.EventRouter
if router and type(router.register) == "function" then
    router.register("PLAYER_REGEN_DISABLED", onCombatEnter)
end
