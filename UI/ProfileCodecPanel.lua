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
    editBox = nil,
    statusText = nil,
    pendingPlan = nil,
}
EAM.UI.ProfileCodecPanel = Panel

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

local function exportCurrent()
    if not Codec then
        setStatus("EAM_PROFILE_CODEC_STATUS_UNAVAILABLE", "Profile codec 尚未載入。")
        return false
    end
    local payload, report = Codec.exportProfile()
    if not payload then
        Panel.pendingPlan = nil
        setStatus("EAM_PROFILE_CODEC_STATUS_FAILED", "匯出失敗：%s", tostring(report))
        return false
    end
    Panel.pendingPlan = nil
    Panel.editBox:SetText(payload)
    setStatus(
        "EAM_PROFILE_CODEC_STATUS_EXPORTED",
        "已匯出 %s；編碼後端：%s，請按全選後 Ctrl+C。",
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
    setStatus(
        "EAM_PROFILE_CODEC_STATUS_PREVIEW",
        "預覽 %s：新增 %d、更新 %d、未變更 %d、移除 %d。",
        mode,
        counts.add or 0,
        counts.update or 0,
        counts.unchanged or 0,
        counts.remove or 0
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
    local report, reason = Codec.applyImport(Panel.pendingPlan, mode)
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
    frame:SetSize(720, 520)
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
    description:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -42)
    description:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -42)
    description:SetJustifyH("LEFT")
    bindText(description, "EAM_PROFILE_CODEC_DESC", "貼上 EAMAP1: payload；預覽後再選擇合併或取代。Base64 不是加密。")
    if Theme and Theme.registerText then Theme.registerText(description, "body") end

    local editBox = api.CreateFrame("EditBox", nil, frame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(262144)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -70)
    editBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 88)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    editBox:SetScript("OnTextChanged", function()
        Panel.pendingPlan = nil
    end)
    Panel.editBox = editBox

    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 58)
    statusText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 58)
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

    makeButton("EAM_PROFILE_CODEC_EXPORT", "匯出目前職業", 112, { "BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18 }, exportCurrent)
    makeButton("EAM_PROFILE_CODEC_PREVIEW", "預覽匯入", 100, { "LEFT", frame, "BOTTOMLEFT", 138, 18 }, function() preview("merge") end)
    makeButton("EAM_PROFILE_CODEC_MERGE", "合併套用", 100, { "LEFT", frame, "BOTTOMLEFT", 244, 18 }, function() apply("merge") end)
    makeButton("EAM_PROFILE_CODEC_REPLACE", "取代套用", 100, { "LEFT", frame, "BOTTOMLEFT", 350, 18 }, function() apply("replace") end)
    makeButton("EAM_PROFILE_CODEC_SELECT", "全選複製", 100, { "LEFT", frame, "BOTTOMLEFT", 456, 18 }, selectAllForCopy)
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
        print("|cff00ff96EAM|r " .. (EAM.L.EAM_PROFILE_CODEC_COMBAT or "戰鬥中不開啟 profile 分享面板。"))
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

