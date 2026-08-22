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
    if not cooldown or type(cooldown.SetSwipeColor) ~= "function" then
        return false
    end
    cooldown:SetSwipeColor(1, 1, 1, normalizeSwipeAlpha(config))
    return true
end

local TOOLTIP_KIND_SPELL = "spell"
local TOOLTIP_KIND_ITEM = "item"

local function hideIconTooltip()
    local tooltip = api.GameTooltip
    if tooltip and type(tooltip.Hide) == "function" then
        pcall(tooltip.Hide, tooltip)
    end
end

local function showIconTooltip(icon)
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatBlocked"
    end
    local rendered = icon and icon.rendered
    local tooltipKind = rendered and rendered.tooltipKind or nil
    local tooltipID = rendered and rendered.tooltipID or nil
    if not Util.isSafeString(tooltipKind) or not Util.isSafePositiveNumber(tooltipID) then
        return false, "sourceUnavailable"
    end
    local tooltip = api.GameTooltip
    if not tooltip or type(tooltip.SetOwner) ~= "function" then
        return false, "tooltipUnavailable"
    end
    local ownerOK = pcall(tooltip.SetOwner, tooltip, icon, "ANCHOR_RIGHT")
    if not ownerOK then
        return false, "ownerRejected"
    end

    local method
    if tooltipKind == TOOLTIP_KIND_SPELL then
        method = tooltip.SetSpellByID
    elseif tooltipKind == TOOLTIP_KIND_ITEM then
        method = tooltip.SetItemByID
    end
    if type(method) ~= "function" then
        hideIconTooltip()
        return false, "methodUnavailable"
    end
    local setOK = pcall(method, tooltip, tooltipID)
    if not setOK then
        hideIconTooltip()
        return false, "contentRejected"
    end
    if type(tooltip.Show) == "function" then
        pcall(tooltip.Show, tooltip)
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
    if cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(true)
    end
    button.cooldown = cooldown
    IconPool.applyCooldownStyle(button, EAM.db and EAM.db.config or nil)

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
    if icon.typeBorder then
        icon.typeBorder:Hide()
    end
    if icon.glowBorder then
        icon.glowBorder:Hide()
    end

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
