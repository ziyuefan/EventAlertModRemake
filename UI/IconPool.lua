--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/IconPool
檔案: UI\IconPool.lua

理念:
- 所有 icon frame、texture、fontstring、cooldown region 由 pool 統一管理。
- Renderer 只借用 frame，不自行大量 CreateFrame。

責任:
- 日後負責 acquire/release icon records 與 controlled frame growth。

資料所有權:
- 擁有 active/inactive icon pools 與 frame objects。

可變狀態:
- 可 mutate frame object 與 pool arrays。

邊界:
- 不查 aura/cooldown/item API。
- 不寫 SavedVariables。

效能注意:
- 初始化或受控擴容時才 CreateFrame；release 不銷毀 frame。

Retail API 注意:
- UI frame template 與 protected frame 行為需 Retail 實機驗證。
- 為降低 taint/combat lockdown 風險，戰鬥中不建立新的 icon frame。

]]
local _, EAM = ...

local api = EAM.API

local IconPool = {
    active = {},
    inactive = {},
    inactiveCount = 0,
    created = 0,
    prewarmCount = 16,
}

EAM.UI.IconPool = IconPool

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
    if cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(true)
    end
    button.cooldown = cooldown

    -- 建立高層級的文字與裝飾容器，徹底解決層級遮擋與 CDM 寄生裁切問題
    local overlay = api.CreateFrame("Frame", nil, button)
    overlay:SetAllPoints(button)
    button.overlay = overlay

    local stackText = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    stackText:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -1, 1)
    button.stackText = stackText

    local nameText = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOP", overlay, "BOTTOM", 0, -2)
    button.nameText = nameText

    local timerText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    timerText:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    button.timerText = timerText

    -- 🌡️ 內置安全、不帶 Taint 風險的 Pandemic 亮框 Gold Glow Overlay
    local glowBorder = button:CreateTexture(nil, "OVERLAY")
    glowBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glowBorder:SetBlendMode("ADD")
    glowBorder:SetAllPoints(button)
    glowBorder:SetVertexColor(1, 0.85, 0.4, 1) -- 亮金色
    glowBorder:Hide()
    button.glowBorder = glowBorder

    button.rendered = {}
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
        if type(icon.timerBinding.Unbind) == "function" then
            icon.timerBinding:Unbind()
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
    if icon.glowBorder then
        icon.glowBorder:Hide()
    end

    local count = IconPool.inactiveCount + 1
    IconPool.inactive[count] = icon
    IconPool.inactiveCount = count
end

function IconPool.prewarm(count)
    count = count or IconPool.prewarmCount
    while IconPool.created < count do
        local icon = createIcon()
        IconPool.release(icon)
    end
end
