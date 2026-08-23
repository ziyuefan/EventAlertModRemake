--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/ProfileCodecPanel
檔案: UI\ProfileCodecPanel.lua

理念:
- 以可人工複製的 EditBox 提供 EAMAP1 profile 分享，不依賴聊天框或系統剪貼簿 API。

責任:
- 開啟、匯出、預覽、合併套用與取代套用目前職業 profile。
- 將套用交易交給 Core/ProfileCodec 與 Core/SavedVariables。

邊界:
- 不在戰鬥中建立或修改 UI 結構。
- 不執行外部字串、不直接修改 EAM_DB。
]]
local _, EAM = ...

local api = EAM.API or {}
local Theme = EAM.Theme
local Locale = EAM.Locale
local Codec = EAM.Modules and EAM.Modules.ProfileCodec

local Panel = {
    frame = nil,
    scrollFrame = nil,
    editBox = nil,
    statusText = nil,
    pendingPlan = nil,
    checkboxes = {},
}
EAM.UI.ProfileCodecPanel = Panel

local MODULE_KEYS = {
    "playerAura",
    "targetAura",
    "spellCooldown",
    "itemCooldown",
    "groundEffect",
}

local SECTION_KEYS = {
    "layout",
    "playerResources",
    "generalConfig",
}

local function inCombat()
    return type(api.InCombatLockdown) == "function" and api.InCombatLockdown() == true
end

local function bindText(target, key, fallback)
    if Locale and type(Locale.bindText) == "function" then
        return Locale.bindText(target, key, fallback)
    end
    if target and type(target.SetText) == "function" then
        target:SetText((EAM.L and EAM.L[key]) or fallback or key)
        return true
    end
    return false
end

local function setStatus(key, fallback, ...)
    if not Panel.statusText then
        return
    end
    local text = (EAM.L and EAM.L[key]) or fallback or key
    if select("#", ...) > 0 then
        text = string.format(text, ...)
    end
    Panel.statusText:SetText(text)
end

local function selectAllForCopy()
    if not Panel.editBox then
        return
    end
    local ok = EAM.Util and EAM.Util.prepareEditBoxManualCopy
        and EAM.Util.prepareEditBoxManualCopy(Panel.editBox)
    if ok then
        setStatus("EAM_PROFILE_CODEC_STATUS_SELECTED", "已全選 payload；請按 Ctrl+C 複製。")
    else
        setStatus("EAM_PROFILE_CODEC_STATUS_SELECT_FAILED", "無法自動全選，請在文字欄位按 Ctrl+A、Ctrl+C。")
    end
end

local function getSelectedModulesAndSections()
    local modules = {}
    for i = 1, #MODULE_KEYS do
        local key = MODULE_KEYS[i]
        local cb = Panel.checkboxes[key]
        if cb and cb:GetChecked() then
            modules[#modules + 1] = key
        end
    end

    local sections = {
        modules = #modules > 0,
        layout = Panel.checkboxes.layout and Panel.checkboxes.layout:GetChecked() == true,
        playerResources = Panel.checkboxes.playerResources and Panel.checkboxes.playerResources:GetChecked() == true,
        generalConfig = Panel.checkboxes.generalConfig and Panel.checkboxes.generalConfig:GetChecked() == true,
    }
    return modules, sections
end

local function setAllCheckboxes(state)
    for _, cb in pairs(Panel.checkboxes) do
        if cb and cb.SetChecked then
            cb:SetChecked(state)
        end
    end
end

local function exportCurrent()
    if not Codec then
        setStatus("EAM_PROFILE_CODEC_STATUS_UNAVAILABLE", "Profile codec 尚未載入。")
        return false
    end
    local modules, sections = getSelectedModulesAndSections()
    local payload, report = Codec.exportProfile(modules, sections)
    if not payload then
        Panel.pendingPlan = nil
        setStatus("EAM_PROFILE_CODEC_STATUS_FAILED", "匯出失敗：%s", tostring(report))
        return false
    end
    Panel.pendingPlan = nil
    Panel.editBox:SetText(payload)
    if Panel.scrollFrame then
        Panel.scrollFrame:SetVerticalScroll(0)
    end
    setStatus(
        "EAM_PROFILE_CODEC_STATUS_EXPORTED",
        "已匯出 %s 項告警；編碼後端：%s，請按全選後 Ctrl+C 複製。",
        tostring(report.alertCount or 0),
        tostring(report.encodingBackend or "unknown")
    )
    return true
end

local function preview(mode)
    if not Codec or not Panel.editBox then
        return false
    end
    local text = Panel.editBox:GetText()
    local plan, reason = Codec.previewImport(text, { mode = mode })
    if not plan then
        Panel.pendingPlan = nil
        setStatus("EAM_PROFILE_CODEC_STATUS_FAILED", "預覽失敗：%s", tostring(reason))
        return false
    end
    Panel.pendingPlan = plan
    local counts = plan.counts
    local sec = plan.sections or {}
    
    if sec.layout ~= nil and Panel.checkboxes.layout then
        Panel.checkboxes.layout:SetChecked(sec.layout == true)
    end
    if sec.playerResources ~= nil and Panel.checkboxes.playerResources then
        Panel.checkboxes.playerResources:SetChecked(sec.playerResources == true)
    end
    if sec.generalConfig ~= nil and Panel.checkboxes.generalConfig then
        Panel.checkboxes.generalConfig:SetChecked(sec.generalConfig == true)
    end

    local secSummary = {}
    if sec.layout then secSummary[#secSummary + 1] = (EAM.L and EAM.L.EAM_PROFILE_SEC_LAYOUT) or "框架排版" end
    if sec.playerResources then secSummary[#secSummary + 1] = (EAM.L and EAM.L.EAM_PROFILE_SEC_RESOURCE) or "職業資源" end
    if sec.generalConfig then secSummary[#secSummary + 1] = (EAM.L and EAM.L.EAM_PROFILE_SEC_CONFIG) or "一般設定" end
    local secText = #secSummary > 0 and ("；包含設定: " .. table.concat(secSummary, ", ")) or ""

    setStatus(
        "EAM_PROFILE_CODEC_STATUS_PREVIEW",
        "預覽 %s：告警新增 %d、更新 %d、未變更 %d、移除 %d%s。",
        mode,
        counts.add or 0,
        counts.update or 0,
        counts.unchanged or 0,
        counts.remove or 0,
        secText
    )
    return true
end

local function apply(mode)
    if not Panel.pendingPlan and not preview(mode) then
        return false
    end
    if not Codec then
        return false
    end
    local _, sections = getSelectedModulesAndSections()
    local report, reason = Codec.applyImport(Panel.pendingPlan, mode, nil, sections)
    if not report then
        setStatus("EAM_PROFILE_CODEC_STATUS_FAILED", "套用失敗：%s", tostring(reason))
        return false
    end
    Panel.pendingPlan = nil
    if EAM.UI.Options and EAM.UI.Options.notifyConfigChanged then
        EAM.UI.Options.notifyConfigChanged(false)
    end
    setStatus(
        "EAM_PROFILE_CODEC_STATUS_APPLIED",
        "已套用：新增 %d、更新 %d、未變更 %d、移除 %d。",
        report.added or 0,
        report.updated or 0,
        report.unchanged or 0,
        report.removed or 0
    )
    return true
end

local function createFrame()
    if Panel.frame then
        return Panel.frame
    end
    if inCombat() or type(api.CreateFrame) ~= "function" then
        return nil, "combatBlocked"
    end

    local frame = api.CreateFrame("Frame", "EAM_ProfileCodecPanel", UIParent, "BackdropTemplate")
    frame:SetSize(760, 600)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0.08, 0.06, 0.05, 0.98)
    frame:SetBackdropBorderColor(0.8, 0.6, 0.4, 1)
    if Theme and Theme.registerFrame then Theme.registerFrame(frame, "window") end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    bindText(title, "EAM_PROFILE_CODEC_TITLE", "EAM Profile 分享")
    if Theme and Theme.registerText then Theme.registerText(title, "title") end

    local description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -40)
    description:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -40)
    description:SetJustifyH("LEFT")
    bindText(description, "EAM_PROFILE_CODEC_DESC", "勾選要匯出或匯入的項目，支援告警清單、框架排版、職業資源與一般設定。")
    if Theme and Theme.registerText then Theme.registerText(description, "body") end

    -- Checkboxes Row 1 (告警模組)
    local function makeCheckbox(name, textKey, fallbackText, x, y)
        local cb = api.CreateFrame("CheckButton", "EAM_ProfileCB_" .. name, frame, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        cb:SetChecked(true)
        local label = cb.text or _G[cb:GetName() .. "Text"]
        if label then
            bindText(label, textKey, fallbackText)
            if Theme and Theme.registerText then Theme.registerText(label, "body") end
        end
        Panel.checkboxes[name] = cb
        return cb
    end

    makeCheckbox("playerAura", "EAM_PROFILE_SEC_SELF", "自身光環", 18, -62)
    makeCheckbox("targetAura", "EAM_PROFILE_SEC_TARGET", "目標光環", 140, -62)
    makeCheckbox("spellCooldown", "EAM_PROFILE_SEC_SPELL_CD", "技能冷卻", 262, -62)
    makeCheckbox("itemCooldown", "EAM_PROFILE_SEC_ITEM_CD", "物品冷卻", 384, -62)
    makeCheckbox("groundEffect", "EAM_PROFILE_SEC_GROUND", "地面效果", 506, -62)

    -- Checkboxes Row 2 (排版與設定)
    makeCheckbox("layout", "EAM_PROFILE_SEC_LAYOUT", "框架排版位置", 18, -92)
    makeCheckbox("playerResources", "EAM_PROFILE_SEC_RESOURCE", "職業資源設定", 160, -92)
    makeCheckbox("generalConfig", "EAM_PROFILE_SEC_CONFIG", "一般偏好設定", 302, -92)

    -- Quick selection buttons
    local function makeQuickBtn(textKey, fallbackText, width, x, y, handler)
        local btn = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(width, 22)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        bindText(btn, textKey, fallbackText)
        btn:SetScript("OnClick", handler)
        if Theme and Theme.registerButton then Theme.registerButton(btn) end
        return btn
    end

    makeQuickBtn("EAM_PROFILE_BTN_SELECT_ALL", "全選", 55, 480, -94, function()
        setAllCheckboxes(true)
    end)
    makeQuickBtn("EAM_PROFILE_BTN_ALERTS_ONLY", "僅告警清單", 95, 540, -94, function()
        setAllCheckboxes(false)
        for i = 1, #MODULE_KEYS do
            if Panel.checkboxes[MODULE_KEYS[i]] then Panel.checkboxes[MODULE_KEYS[i]]:SetChecked(true) end
        end
    end)
    makeQuickBtn("EAM_PROFILE_BTN_LAYOUT_ONLY", "僅排版設定", 95, 640, -94, function()
        setAllCheckboxes(false)
        for i = 1, #SECTION_KEYS do
            if Panel.checkboxes[SECTION_KEYS[i]] then Panel.checkboxes[SECTION_KEYS[i]]:SetChecked(true) end
        end
    end)

    -- ScrollFrame & EditBox
    local scrollFrame = api.CreateFrame(
        "ScrollFrame",
        "EAM_ProfileCodecScrollFrame",
        frame,
        "UIPanelScrollFrameTemplate"
    )
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -126)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 88)
    scrollFrame:EnableMouseWheel(true)
    local scrollBar = scrollFrame.ScrollBar or _G.EAM_ProfileCodecScrollFrameScrollBar
    if scrollBar then
        scrollBar.scrollStep = 39
    end
    Panel.scrollFrame = scrollFrame

    local editBox = api.CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(262144)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    editBox:SetWidth(694)
    editBox:SetHeight(1)
    scrollFrame:SetScrollChild(editBox)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    editBox:SetScript("OnTextChanged", function(self)
        Panel.pendingPlan = nil
        local fontString = type(self.GetFontString) == "function" and self:GetFontString() or nil
        local textHeight = fontString and type(fontString.GetStringHeight) == "function"
            and fontString:GetStringHeight()
            or 1
        local viewportHeight = type(scrollFrame.GetHeight) == "function" and scrollFrame:GetHeight() or 1
        self:SetHeight(math.max(viewportHeight or 1, textHeight + 12))
        scrollFrame:UpdateScrollChildRect()
    end)
    editBox:SetScript("OnCursorChanged", function(_, _, y, _, height)
        if type(y) ~= "number" or type(height) ~= "number" then
            return
        end
        local current = scrollFrame:GetVerticalScroll() or 0
        local viewportHeight = scrollFrame:GetHeight() or 0
        local cursorTop = -y
        local cursorBottom = cursorTop + height
        local target = current
        if cursorTop < current then
            target = cursorTop
        elseif cursorBottom > current + viewportHeight then
            target = cursorBottom - viewportHeight
        end
        local maximum = scrollFrame:GetVerticalScrollRange() or 0
        target = math.max(0, math.min(maximum, target))
        if target ~= current then
            scrollFrame:SetVerticalScroll(target)
        end
    end)
    Panel.editBox = editBox

    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 56)
    statusText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 56)
    statusText:SetJustifyH("LEFT")
    if Theme and Theme.registerText then Theme.registerText(statusText, "body") end
    Panel.statusText = statusText

    local function makeButton(key, fallback, width, point, handler)
        local button = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(width, 26)
        button:SetPoint(unpack(point))
        bindText(button, key, fallback)
        button:SetScript("OnClick", handler)
        if Theme and Theme.registerButton then Theme.registerButton(button) end
        return button
    end

    makeButton("EAM_PROFILE_CODEC_EXPORT", "匯出所選項目", 120, { "BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18 }, exportCurrent)
    makeButton("EAM_PROFILE_CODEC_SELECT", "全選複製", 90, { "LEFT", frame, "BOTTOMLEFT", 146, 18 }, selectAllForCopy)
    makeButton("EAM_PROFILE_CODEC_PREVIEW", "預覽匯入", 95, { "LEFT", frame, "BOTTOMLEFT", 244, 18 }, function() preview("merge") end)
    makeButton("EAM_PROFILE_CODEC_MERGE", "合併套用", 95, { "LEFT", frame, "BOTTOMLEFT", 347, 18 }, function() apply("merge") end)
    makeButton("EAM_PROFILE_CODEC_REPLACE", "取代套用", 95, { "LEFT", frame, "BOTTOMLEFT", 450, 18 }, function() apply("replace") end)
    makeButton("EAM_PROFILE_CODEC_CLOSE", "關閉", 80, { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18 }, function() frame:Hide() end)

    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = "EAM_ProfileCodecPanel"
    end
    frame:Hide()
    Panel.frame = frame
    return frame
end

function Panel.open()
    if inCombat() then
        print("|cff00ff96EAM|r " .. ((EAM.L and EAM.L.EAM_PROFILE_CODEC_COMBAT) or "戰鬥中不開啟 profile 分享面板。"))
        return false, "combatBlocked"
    end
    local frame, reason = createFrame()
    if not frame then return false, reason or "frameUnavailable" end
    frame:Show()
    frame:Raise()
    return true
end

function Panel.openExport()
    local ok, reason = Panel.open()
    if not ok then return false, reason end
    exportCurrent()
    return true
end

function Panel.hide()
    if Panel.frame then Panel.frame:Hide() end
end

