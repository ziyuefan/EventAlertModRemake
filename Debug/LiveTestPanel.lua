--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/LiveTestPanel
檔案: Debug\LiveTestPanel.lua

理念:
- 以玩家逐案操作與確認取代任何遊戲自動化，讓 PTR／XPTR／正式服結果可安全回灌。

責任:
- 選擇 client directory、瀏覽案例、記錄 pass/fail/blocked/note、建立 reload checkpoint、複製 JSON。

邊界:
- 戰鬥中不建立、開啟或寫入 session；不合成輸入、不呼叫 ReloadUI、不操作 Blizzard protected frame。
]]
local _, EAM = ...

local api = EAM.API or {}
local LiveTestPanel = {
    frame = nil,
    reportEditBox = nil,
    noteEditBox = nil,
    caseTitle = nil,
    caseID = nil,
    caseStatus = nil,
    environmentText = nil,
    summaryText = nil,
    currentIndex = 1,
    pendingOpen = false,
    cancelArmed = false,
}

EAM.Debug.LiveTestPanel = LiveTestPanel

local function text(key, fallback)
    return EAM.L and EAM.L[key] or fallback
end

local function setMessage(message, isError)
    if not LiveTestPanel.summaryText then
        return
    end
    LiveTestPanel.summaryText:SetTextColor(isError and 1.0 or 0.2, isError and 0.25 or 1.0, 0.25, 1.0)
    LiveTestPanel.summaryText:SetText(message or "")
end

local function currentDefinition()
    local session = EAM.Debug.LiveTestSession
    return session and session.cases[LiveTestPanel.currentIndex] or nil
end

local function saveCurrentNote()
    local definition = currentDefinition()
    local noteEditBox = LiveTestPanel.noteEditBox
    local session = EAM.Debug.LiveTestSession
    if definition and noteEditBox and session then
        session.setCaseNote(definition.id, noteEditBox:GetText() or "")
    end
end

local function refreshPanel()
    local session = EAM.Debug.LiveTestSession
    local state = session and session.getState()
    local report, reportJSON = session and session.buildReport()
    if LiveTestPanel.reportEditBox then
        LiveTestPanel.reportEditBox:SetText(reportJSON or "{}")
        LiveTestPanel.reportEditBox:SetCursorPosition(0)
    end

    if report and LiveTestPanel.environmentText then
        LiveTestPanel.environmentText:SetText(string.format(
            text("EAM_LIVE_ENVIRONMENT_FORMAT", "環境：%s / %s / Interface %s / %s"),
            tostring(report.environment.declaredInstallation),
            tostring(report.environment.patch),
            tostring(report.environment.interface),
            tostring(report.environment.channelValidation)
        ))
    elseif LiveTestPanel.environmentText then
        LiveTestPanel.environmentText:SetText(text("EAM_LIVE_ENVIRONMENT_UNSET", "尚未建立實機簽收 session。"))
    end

    local definition = currentDefinition()
    local savedCase = state and definition and state.cases[definition.id]
    if definition and LiveTestPanel.caseTitle then
        LiveTestPanel.caseTitle:SetText(string.format(
            "%d / %d  %s",
            LiveTestPanel.currentIndex,
            #session.cases,
            text(definition.labelKey, definition.id)
        ))
        LiveTestPanel.caseID:SetText(definition.id)
        LiveTestPanel.caseStatus:SetText(string.format(
            text("EAM_LIVE_CASE_STATUS", "狀態：%s"),
            savedCase and savedCase.status or "pending"
        ))
        LiveTestPanel.noteEditBox:SetText(savedCase and savedCase.note or "")
    end

    if report then
        local summary = report.summary
        setMessage(string.format(
            text("EAM_LIVE_SUMMARY_FORMAT", "報告 %s：通過 %d、失敗 %d、受限 %d、待測 %d。"),
            report.status,
            summary.passed,
            summary.failed,
            summary.blocked,
            summary.pending
        ), report.status == "fail")
    end
end

local function createButton(parent, label, width, point, relativeTo, relativePoint, x, y, callback)
    local button = api.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 25)
    button:SetPoint(point, relativeTo, relativePoint, x, y)
    button:SetText(label)
    button:SetScript("OnClick", callback)
    return button
end

local function startSession(declaredInstallation)
    LiveTestPanel.cancelArmed = false
    local ok, reason = EAM.Debug.LiveTestSession.start(declaredInstallation)
    if not ok then
        setMessage(string.format(text("EAM_LIVE_START_FAILED", "無法開始實機簽收：%s"), tostring(reason)), true)
        return
    end
    LiveTestPanel.currentIndex = 1
    refreshPanel()
end

local function setCurrentStatus(status)
    local definition = currentDefinition()
    if not definition then
        return
    end
    local note = LiveTestPanel.noteEditBox and LiveTestPanel.noteEditBox:GetText() or ""
    local ok, reason = EAM.Debug.LiveTestSession.setCaseStatus(definition.id, status, note)
    if not ok then
        setMessage(string.format(text("EAM_LIVE_CASE_SAVE_FAILED", "無法儲存案例：%s"), tostring(reason)), true)
        return
    end
    refreshPanel()
end

local function changeCase(delta)
    saveCurrentNote()
    local count = #EAM.Debug.LiveTestSession.cases
    LiveTestPanel.currentIndex = LiveTestPanel.currentIndex + delta
    if LiveTestPanel.currentIndex < 1 then
        LiveTestPanel.currentIndex = count
    elseif LiveTestPanel.currentIndex > count then
        LiveTestPanel.currentIndex = 1
    end
    refreshPanel()
end

local function createFrame()
    if LiveTestPanel.frame then
        return LiveTestPanel.frame
    end
    if not api.CreateFrame or not UIParent then
        return nil
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return nil
    end

    local frame = api.CreateFrame("Frame", "EAM_LiveTestFrame", UIParent, "BackdropTemplate")
    frame:SetSize(780, 660)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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
    frame:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
    frame:SetBackdropBorderColor(0.35, 0.65, 0.95, 1.0)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText(text("EAM_LIVE_PANEL_TITLE", "EAM 真人實機簽收與 JSON 回報"))

    local policy = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    policy:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -44)
    policy:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -44)
    policy:SetJustifyH("LEFT")
    policy:SetText(text(
        "EAM_LIVE_PANEL_POLICY",
        "只記錄玩家手動操作；EAM 不施法、不點擊、不執行巨集、不切換目標，也不自動 /reload。"
    ))

    local retailButton = createButton(
        frame, text("EAM_LIVE_START_RETAIL", "開始正式服"), 120,
        "TOPLEFT", frame, "TOPLEFT", 20, -72,
        function() startSession("_retail_") end
    )
    local ptrButton = createButton(
        frame, text("EAM_LIVE_START_PTR", "開始 PTR 12.1"), 130,
        "LEFT", retailButton, "RIGHT", 8, 0,
        function() startSession("_ptr_") end
    )
    local xptrButton = createButton(
        frame, text("EAM_LIVE_START_XPTR", "開始 XPTR 12.0.7"), 145,
        "LEFT", ptrButton, "RIGHT", 8, 0,
        function() startSession("_xptr_") end
    )
    createButton(
        frame, text("EAM_LIVE_CANCEL_SESSION", "取消目前 session"), 130,
        "LEFT", xptrButton, "RIGHT", 8, 0,
        function()
            local session = EAM.Debug.LiveTestSession
            local state = session and session.getState()
            if not state or state.phase ~= "active" then
                LiveTestPanel.cancelArmed = false
                setMessage(text("EAM_LIVE_CANCEL_NOT_ACTIVE", "目前沒有進行中的實機 session。"), true)
                return
            end
            if not LiveTestPanel.cancelArmed then
                LiveTestPanel.cancelArmed = true
                setMessage(text("EAM_LIVE_CANCEL_CONFIRM", "再按一次「取消目前 session」確認清除本次進度。"), true)
                return
            end
            LiveTestPanel.cancelArmed = false
            local ok, reason = session.cancel()
            LiveTestPanel.currentIndex = 1
            refreshPanel()
            setMessage(
                ok and text("EAM_LIVE_CANCELLED", "目前 session 已取消，可重新選擇 client。")
                    or string.format(text("EAM_LIVE_CANCEL_FAILED", "無法取消 session：%s"), tostring(reason)),
                not ok
            )
        end
    )

    local environmentText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    environmentText:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -106)
    environmentText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -106)
    environmentText:SetJustifyH("LEFT")
    LiveTestPanel.environmentText = environmentText

    local caseTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    caseTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -132)
    caseTitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -132)
    caseTitle:SetJustifyH("LEFT")
    LiveTestPanel.caseTitle = caseTitle

    local caseID = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    caseID:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -154)
    caseID:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -154)
    caseID:SetJustifyH("LEFT")
    LiveTestPanel.caseID = caseID

    local caseStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    caseStatus:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -176)
    LiveTestPanel.caseStatus = caseStatus

    local noteBackground = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    noteBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -200)
    noteBackground:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -200)
    noteBackground:SetHeight(62)
    noteBackground:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    noteBackground:SetBackdropColor(0.02, 0.02, 0.02, 0.95)

    local noteEditBox = api.CreateFrame("EditBox", nil, noteBackground)
    noteEditBox:SetPoint("TOPLEFT", noteBackground, "TOPLEFT", 8, -8)
    noteEditBox:SetPoint("BOTTOMRIGHT", noteBackground, "BOTTOMRIGHT", -8, 8)
    noteEditBox:SetMultiLine(true)
    noteEditBox:SetMaxLetters(500)
    noteEditBox:SetFontObject("ChatFontNormal")
    noteEditBox:SetAutoFocus(false)
    LiveTestPanel.noteEditBox = noteEditBox

    local previousButton = createButton(
        frame, text("EAM_LIVE_PREVIOUS", "上一案"), 82,
        "TOPLEFT", frame, "TOPLEFT", 20, -272,
        function() changeCase(-1) end
    )
    local nextButton = createButton(
        frame, text("EAM_LIVE_NEXT", "下一案"), 82,
        "LEFT", previousButton, "RIGHT", 6, 0,
        function() changeCase(1) end
    )
    local passButton = createButton(
        frame, text("EAM_LIVE_PASS", "符合"), 82,
        "LEFT", nextButton, "RIGHT", 14, 0,
        function() setCurrentStatus("pass") end
    )
    local failButton = createButton(
        frame, text("EAM_LIVE_FAIL", "不符合"), 82,
        "LEFT", passButton, "RIGHT", 6, 0,
        function() setCurrentStatus("fail") end
    )
    local blockedButton = createButton(
        frame, text("EAM_LIVE_BLOCKED", "無法測試"), 92,
        "LEFT", failButton, "RIGHT", 6, 0,
        function() setCurrentStatus("blocked") end
    )
    createButton(
        frame, text("EAM_LIVE_RESET_CASE", "重設待測"), 92,
        "LEFT", blockedButton, "RIGHT", 6, 0,
        function() setCurrentStatus("pending") end
    )

    local reloadButton = createButton(
        frame, text("EAM_LIVE_RELOAD_CHECKPOINT", "建立 /reload 檢查點"), 160,
        "TOPLEFT", frame, "TOPLEFT", 20, -306,
        function()
            saveCurrentNote()
            local ok, reason = EAM.Debug.LiveTestSession.prepareReload()
            refreshPanel()
            setMessage(
                ok and text("EAM_LIVE_RELOAD_READY", "檢查點已保存；請由玩家自行輸入 /reload。")
                    or string.format(text("EAM_LIVE_RELOAD_FAILED", "無法建立檢查點：%s"), tostring(reason)),
                not ok
            )
        end
    )
    createButton(
        frame, text("EAM_LIVE_COMPLETE", "完成並產生 JSON"), 160,
        "LEFT", reloadButton, "RIGHT", 8, 0,
        function()
            saveCurrentNote()
            local ok, reason = EAM.Debug.LiveTestSession.complete()
            refreshPanel()
            if not ok then
                setMessage(string.format(text("EAM_LIVE_COMPLETE_FAILED", "尚不能簽收：%s"), tostring(reason)), true)
            else
                setMessage(text(
                    "EAM_LIVE_COMPLETE_READY",
                    "JSON 已完成；直接複製即為最新。若要從 WTF 匯入，請由玩家再輸入 /reload 或正常登出保存。"
                ))
            end
        end
    )

    local outputBackground = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    outputBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -346)
    outputBackground:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 78)
    outputBackground:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    outputBackground:SetBackdropColor(0.02, 0.02, 0.02, 0.95)

    local scrollFrame = api.CreateFrame("ScrollFrame", nil, outputBackground, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", outputBackground, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", outputBackground, "BOTTOMRIGHT", -28, 8)
    local scrollChild = api.CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(690, 220)
    scrollFrame:SetScrollChild(scrollChild)

    local reportEditBox = api.CreateFrame("EditBox", nil, scrollChild)
    reportEditBox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -4)
    reportEditBox:SetSize(680, 212)
    reportEditBox:SetMultiLine(true)
    reportEditBox:SetMaxLetters(999999)
    reportEditBox:SetFontObject("ChatFontNormal")
    reportEditBox:SetAutoFocus(false)
    reportEditBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    LiveTestPanel.reportEditBox = reportEditBox

    local summaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summaryText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 54)
    summaryText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 54)
    summaryText:SetJustifyH("LEFT")
    LiveTestPanel.summaryText = summaryText

    local copyButton = createButton(
        frame, text("EAM_LIVE_COPY", "複製實機 JSON"), 150,
        "BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 18,
        function()
            saveCurrentNote()
            refreshPanel()
            reportEditBox:SetFocus()
            reportEditBox:HighlightText()
            reportEditBox:Copy()
            setMessage(text("EAM_LIVE_COPIED", "JSON 已複製；回報時請連同 PTR／XPTR／正式服標籤提供。"), false)
        end
    )
    createButton(
        frame, text("EAM_FLOW_BUTTON_CLOSE", "關閉"), 100,
        "LEFT", copyButton, "RIGHT", 8, 0,
        function()
            saveCurrentNote()
            frame:Hide()
        end
    )

    _G.EAM_LiveTestFrame = frame
    if UISpecialFrames then
        UISpecialFrames[#UISpecialFrames + 1] = "EAM_LiveTestFrame"
    end
    LiveTestPanel.frame = frame
    return frame
end

function LiveTestPanel.open(forceShow)
    if api.InCombatLockdown and api.InCombatLockdown() then
        LiveTestPanel.pendingOpen = true
        print("|cff00ff96EAM|r " .. text("EAM_LIVE_DEFERRED", "實機簽收面板將於脫離戰鬥後開啟。"))
        return
    end
    local frame = createFrame()
    if not frame then
        return
    end
    if frame:IsShown() and not forceShow then
        frame:Hide()
        return
    end
    frame:Show()
    refreshPanel()
end

local function onRegenEnabled()
    if not LiveTestPanel.pendingOpen then
        return
    end
    LiveTestPanel.pendingOpen = false
    LiveTestPanel.open(true)
end

if EAM.Modules and EAM.Modules.EventRouter then
    EAM.Modules.EventRouter.register("PLAYER_REGEN_ENABLED", onRegenEnabled)
end
