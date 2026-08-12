--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/TooltipMonitorMenu
檔案: UI\TooltipMonitorMenu.lua

理念:
- 以 EAM 自有、非 secure 的 Popup Menu 取代對 Blizzard 圖示右鍵行為的攔截。
- 使用者必須在 EAM 按鈕上明確確認，才會寫入監控清單。

責任:
- 在游標旁呈現 Tooltip 候選項、必要的手動 ID 欄位與合法監控路由。
- 將確認動作交給 TooltipMonitorService，不直接寫 SavedVariables。

資料所有權:
- 只擁有 EAM Popup frame 與純 scalar 的當次顯示狀態。
- 不保存 Blizzard Frame、TooltipData、AuraData 或秘密值。

邊界:
- 不 Hook Blizzard frame，不使用 secure action attribute，不模擬滑鼠點擊。
- 戰鬥中不建立、顯示或變更 Popup 結構。

效能注意:
- 所有 frame 只建立一次，後續開啟僅重用文字、按鈕與 EditBox。
- 本模組不使用 OnUpdate 或計時器。

Retail API 注意:
- Aura 路由只接受使用者輸入的普通數字，不查詢 12.1 AuraButton/AuraData。
]]
local _, EAM = ...

local Menu = {
    initialized = false,
    waitingForCombat = false,
    frame = nil,
}

EAM.UI.TooltipMonitorMenu = Menu

local api = EAM.API or {}
local Theme = EAM.Theme
local Locale = EAM.Locale
local Util = EAM.Util or {}
local current = {
    kind = nil,
    spellID = nil,
    itemID = nil,
    macroID = nil,
}

local function inCombat()
    if not api.InCombatLockdown then
        return true
    end
    local ok, combat = pcall(api.InCombatLockdown)
    return not ok or combat == true
end

local function clearCurrent()
    current.kind = nil
    current.spellID = nil
    current.itemID = nil
    current.macroID = nil
end

local function safeIDText(value)
    if type(value) == "number" and value > 0 then
        return tostring(value)
    end
    return EAM.L.EAM_POPUP_ID_UNRESOLVED or "尚未解析"
end

local function safePositiveInteger(value)
    if not Util.isSafePositiveNumber or not Util.isSafePositiveNumber(value) then
        return nil
    end
    local integer = math.floor(value)
    if integer ~= value then
        return nil
    end
    return integer
end

local function hideButton(button)
    button.action = nil
    button:Hide()
end

local function showButton(button, label, action)
    button.action = action
    button:SetText(label)
    button:Show()
end

local function getManualID()
    local editBox = Menu.idEditBox
    if not editBox or not editBox:IsShown() then
        return nil
    end
    local value = editBox:GetNumber()
    if type(value) ~= "number" or value <= 0 then
        return nil
    end
    return value
end

local function commitAction(action)
    local service = EAM.Services and EAM.Services.TooltipMonitorService
    if not service or type(service.commitCandidate) ~= "function" then
        return false, "serviceUnavailable"
    end
    local source = {
        kind = current.kind,
        spellID = current.spellID,
        itemID = current.itemID,
        macroID = current.macroID,
    }
    local success, alertID, change = service.commitCandidate(source, action, getManualID())
    if success then
        Menu.hide()
    elseif Menu.idEditBox and Menu.idEditBox:IsShown() then
        Menu.idEditBox:SetFocus()
        Menu.idEditBox:HighlightText()
    end
    return success, alertID, change
end

local function onActionButton(button)
    if button.action then
        return commitAction(button.action)
    end
    return false, "actionUnavailable"
end

local function placeAtCursor()
    local frame = Menu.frame
    if not frame or not UIParent then
        return
    end
    local x, y = 0, 0
    if api.GetCursorPosition then
        local ok, cursorX, cursorY = pcall(api.GetCursorPosition)
        if ok and Util.isSafeNumber and Util.isSafeNumber(cursorX) and Util.isSafeNumber(cursorY) then
            x = cursorX
            y = cursorY
        end
    end
    local scale = UIParent:GetEffectiveScale()
    if type(scale) ~= "number" or scale <= 0 then
        scale = 1
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 12, y / scale - 12)
end

local function configureForCandidate(source)
    local service = EAM.Services.TooltipMonitorService
    if not service then
        return false
    end
    local actionOne = Menu.actionButtons[1]
    local actionTwo = Menu.actionButtons[2]
    hideButton(actionOne)
    hideButton(actionTwo)
    Menu.idEditBox:Hide()
    Menu.idLabel:Hide()
    Menu.idEditBox:SetText("")

    if source.kind == "spell" then
        Menu.description:SetText(string.format(
            EAM.L.EAM_POPUP_DESC_SPELL or "法術 ID：%s",
            safeIDText(source.spellID)
        ))
        showButton(
            actionOne,
            EAM.L.EAM_POPUP_ADD_SPELL or "加入技能冷卻監控",
            service.ACTION_SPELL_COOLDOWN
        )
        return true
    end

    if source.kind == "item" then
        Menu.description:SetText(string.format(
            EAM.L.EAM_POPUP_DESC_ITEM or "物品 ID：%s",
            safeIDText(source.itemID)
        ))
        showButton(
            actionOne,
            EAM.L.EAM_POPUP_ADD_ITEM or "加入物品冷卻監控",
            service.ACTION_ITEM_COOLDOWN
        )
        return true
    end

    if source.kind == "aura" then
        local description = service.auraIDDisplayEnabled
            and (EAM.L.EAM_POPUP_DESC_AURA
                or "請輸入 Tooltip 顯示的 Aura 法術 ID，再選擇監控單位。")
            or (EAM.L.EAM_POPUP_DESC_AURA_MANUAL
                or "官方 Aura ID 顯示不可用。請輸入已知的 Aura 法術 ID，再選擇監控單位。")
        Menu.description:SetText(description)
        Menu.idLabel:Show()
        Menu.idEditBox:Show()
        showButton(
            actionOne,
            EAM.L.EAM_POPUP_ADD_AURA_PLAYER or "加入玩家光環監控",
            service.ACTION_AURA_PLAYER
        )
        showButton(
            actionTwo,
            EAM.L.EAM_POPUP_ADD_AURA_TARGET or "加入目標光環監控",
            service.ACTION_AURA_TARGET
        )
        return true
    end

    if source.kind == "macro" then
        Menu.description:SetText(string.format(
            EAM.L.EAM_POPUP_DESC_MACRO or "巨集 ID：%s\n法術 ID：%s\n物品 ID：%s",
            safeIDText(source.macroID),
            safeIDText(source.spellID),
            safeIDText(source.itemID)
        ))
        local actionCount = 0
        if source.spellID then
            actionCount = actionCount + 1
            showButton(
                Menu.actionButtons[actionCount],
                EAM.L.EAM_POPUP_ADD_SPELL or "加入技能冷卻監控",
                service.ACTION_SPELL_COOLDOWN
            )
        end
        if source.itemID then
            actionCount = actionCount + 1
            showButton(
                Menu.actionButtons[actionCount],
                EAM.L.EAM_POPUP_ADD_ITEM or "加入物品冷卻監控",
                service.ACTION_ITEM_COOLDOWN
            )
        end
        if actionCount == 0 then
            Menu.idLabel:Show()
            Menu.idEditBox:Show()
            showButton(
                actionOne,
                EAM.L.EAM_POPUP_ADD_SPELL or "加入技能冷卻監控",
                service.ACTION_SPELL_COOLDOWN
            )
            showButton(
                actionTwo,
                EAM.L.EAM_POPUP_ADD_ITEM or "加入物品冷卻監控",
                service.ACTION_ITEM_COOLDOWN
            )
        end
        return true
    end

    return false
end

local function refreshLocalizedText()
    if not Menu.frame or not current.kind then
        return
    end
    local manualText
    if Menu.idEditBox and Menu.idEditBox:IsShown() then
        manualText = Menu.idEditBox:GetText()
    end
    if configureForCandidate(current) and manualText and Menu.idEditBox:IsShown() then
        Menu.idEditBox:SetText(manualText)
    end
end

if Locale and type(Locale.registerRefresh) == "function" then
    Locale.registerRefresh(refreshLocalizedText)
end

local function createActionButton(parent, index, anchor, relativeTo, relativePoint, x, y)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(button) end
    button:SetSize(158, 24)
    button:SetPoint(anchor, relativeTo, relativePoint, x, y)
    button:SetScript("OnClick", onActionButton)
    Menu.actionButtons[index] = button
end

local function createFrame()
    local frame = CreateFrame("Frame", "EAMTooltipMonitorMenu", UIParent, "BackdropTemplate")
    frame:SetSize(380, 250)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    if Theme and Theme.registerFrame then Theme.registerFrame(frame, "window") end
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -20)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, -20)
    Locale.bindText(title, "EAM_POPUP_TITLE", "EAM 加入監控")
    if Theme and Theme.registerText then Theme.registerText(title, "title") end

    local description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    description:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -14)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    description:SetHeight(70)
    if Theme and Theme.registerText then Theme.registerText(description, "body") end
    Menu.description = description

    local idLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    idLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -119)
    Locale.bindText(idLabel, "EAM_POPUP_ID_INPUT", "監控 ID")
    Menu.idLabel = idLabel

    local idEditBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    idEditBox:SetSize(190, 24)
    idEditBox:SetPoint("LEFT", idLabel, "RIGHT", 12, 0)
    idEditBox:SetAutoFocus(false)
    idEditBox:SetNumeric(true)
    idEditBox:SetMaxLetters(10)
    idEditBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    idEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        Menu.hide()
    end)
    Menu.idEditBox = idEditBox

    Menu.actionButtons = {}
    createActionButton(frame, 1, "TOPLEFT", frame, "TOPLEFT", 24, -158)
    createActionButton(frame, 2, "TOPRIGHT", frame, "TOPRIGHT", -24, -158)

    local cancelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(cancelButton) end
    cancelButton:SetSize(158, 24)
    cancelButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 22)
    Locale.bindText(cancelButton, "EAM_POPUP_CANCEL", "取消")
    cancelButton:SetScript("OnClick", function()
        Menu.hide()
    end)
    Menu.cancelButton = cancelButton

    frame:SetScript("OnHide", function()
        idEditBox:ClearFocus()
        clearCurrent()
    end)

    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()
    end
    Menu.frame = frame
end

local function onCombatEnded()
    Menu.waitingForCombat = false
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router and type(router.unregister) == "function" then
        router.unregister("PLAYER_REGEN_ENABLED", onCombatEnded)
    end
    Menu.initialize()
end

function Menu.initialize()
    if Menu.initialized or Menu.waitingForCombat then
        return
    end
    if inCombat() then
        local router = EAM.Modules and EAM.Modules.EventRouter
        if router and type(router.register) == "function" then
            Menu.waitingForCombat = true
            router.register("PLAYER_REGEN_ENABLED", onCombatEnded)
        end
        return
    end
    if not UIParent or not CreateFrame then
        return
    end
    createFrame()
    Menu.initialized = true
end

function Menu.open(source)
    if inCombat()
        or not Util.isReadableTable
        or not Util.isReadableTable(source)
        or not Util.isSafeString
        or not Util.isSafeString(source.kind)
    then
        Menu.hide()
        return false
    end
    if not Menu.initialized then
        Menu.initialize()
    end
    if not Menu.initialized or not Menu.frame then
        return false
    end

    current.kind = source.kind
    current.spellID = safePositiveInteger(source.spellID)
    current.itemID = safePositiveInteger(source.itemID)
    current.macroID = safePositiveInteger(source.macroID)
    if not configureForCandidate(current) then
        Menu.hide()
        return false
    end

    placeAtCursor()
    Menu.frame:Show()
    Menu.frame:Raise()
    if Menu.idEditBox:IsShown() then
        Menu.idEditBox:SetFocus()
    end
    return true
end

function Menu.hide()
    if Menu.frame then
        Menu.frame:Hide()
    end
    clearCurrent()
end

function Menu.isShown()
    return Menu.frame and Menu.frame:IsShown() or false
end

if EAM.FlowTestEnvironment == "offline-mock" then
    function Menu._getStateForTest()
        local actionOne = Menu.actionButtons and Menu.actionButtons[1]
        local actionTwo = Menu.actionButtons and Menu.actionButtons[2]
        return {
            kind = current.kind,
            spellID = current.spellID,
            itemID = current.itemID,
            macroID = current.macroID,
            shown = Menu.isShown(),
            inputShown = Menu.idEditBox and Menu.idEditBox:IsShown() or false,
            description = Menu.description and Menu.description:GetText() or nil,
            actionOne = actionOne and actionOne:IsShown() and actionOne.action or nil,
            actionTwo = actionTwo and actionTwo:IsShown() and actionTwo.action or nil,
        }
    end

    function Menu._clickActionForTest(index, manualID)
        local button = Menu.actionButtons and Menu.actionButtons[index]
        if not button or not button:IsShown() then
            return false, "buttonUnavailable"
        end
        if manualID ~= nil and Menu.idEditBox then
            Menu.idEditBox:SetText(tostring(manualID))
        end
        return button:Click()
    end
end
