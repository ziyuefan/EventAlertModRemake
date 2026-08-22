--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/ModulePanel
檔案: UIModulePanel.lua

理念:
- 用單一小面板呈現正式功能模組開關，不把服務生命週期混入一般 config checkbox。
- 使用者設定寫入一律經 SavedVariables.updateModuleToggle。

責任:
- 顯示八個 module toggle、目前狀態與套用結果。
- 戰鬥中不建立或開啟新結構，避免 UIParent 結構變更風險。

資料所有權:
- 只持有面板與 CheckButton 參考，不直接擁有設定。

邊界:
- 不直接呼叫任何 Aura、Cooldown、Item 或 UnitPower API。
]]
local _, EAM = ...

local api = EAM.API or {}
local Theme = EAM.Theme
local Locale = EAM.Locale
local ModulePanel = {
    frame = nil,
    checkboxes = {},
    statusText = nil,
}

EAM.UI.ModulePanel = ModulePanel

local function inCombat()
    return type(api.InCombatLockdown) == "function" and api.InCombatLockdown() == true
end

local function getToggleValue(key)
    local config = EAM.db and EAM.db.config
    local toggles = type(config) == "table" and config.moduleToggles or nil
    return type(toggles) ~= "table" or toggles[key] ~= false
end

function ModulePanel.refresh()
    for key, checkbox in pairs(ModulePanel.checkboxes) do
        checkbox:SetChecked(getToggleValue(key))
    end
end

local function createPanel()
    if ModulePanel.frame then
        return ModulePanel.frame
    end
    if inCombat() or type(api.CreateFrame) ~= "function" then
        return nil
    end

    local frame = api.CreateFrame(
        "Frame",
        "EAM_ModuleOptionsFrame",
        UIParent,
        "BackdropTemplate"
    )
    frame:SetSize(430, 300)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\ChatFrame\ChatFrameBackground",
        edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
        tile = true,
        tileSize = 24,
        edgeSize = 24,
        insets = { left = 7, right = 7, top = 7, bottom = 7 },
    })
    frame:SetBackdropColor(0.08, 0.06, 0.04, 0.98)
    frame:SetBackdropBorderColor(0.75, 0.55, 0.25, 1)
    if Theme and Theme.registerFrame then
        Theme.registerFrame(frame, "window")
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    Locale.bindText(title, "EAM_MODULE_PANEL_TITLE", "功能模組開關")
    if Theme and Theme.registerText then
        Theme.registerText(title, "title")
    end

    local description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -48)
    description:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -48)
    description:SetJustifyH("LEFT")
    Locale.bindText(
        description,
        "EAM_MODULE_PANEL_DESC",
        "停用後保留單次事件註冊，但停止 API 讀取並清除既有提醒。"
    )
    if Theme and Theme.registerText then
        Theme.registerText(description, "body")
    end

    local controller = EAM.Modules and EAM.Modules.ModuleController
    local options = controller and controller.ModuleOptions or {}
    for index = 1, #options do
        local definition = options[index]
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local checkbox = api.CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 24 + column * 205, -88 - row * 40)
        checkbox:SetSize(24, 24)
        checkbox.eamModuleKey = definition.key

        local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
        Locale.bindText(label, definition.labelKey, definition.key)
        if Theme and Theme.registerText then
            Theme.registerText(label, "body")
        end

        checkbox:SetScript("OnClick", function(self)
            local saved = EAM.Modules and EAM.Modules.SavedVariables
            local enabled = self:GetChecked() == true
            if not saved or type(saved.updateModuleToggle) ~= "function" then
                self:SetChecked(not enabled)
                return
            end
            local ok, status = saved.updateModuleToggle(self.eamModuleKey, enabled)
            if not ok then
                self:SetChecked(not enabled)
                ModulePanel.statusText:SetText(
                    (EAM.L.EAM_MODULE_STATUS_FAILED or "套用失敗：") .. tostring(status)
                )
                return
            end
            local stateText = enabled
                and (EAM.L.EAM_MODULE_ENABLED or "已啟用")
                or (EAM.L.EAM_MODULE_DISABLED or "已停用")
            ModulePanel.statusText:SetText(
                string.format(
                    EAM.L.EAM_MODULE_STATUS_FORMAT or "%s：%s",
                    EAM.L[definition.labelKey] or definition.key,
                    stateText
                )
            )
        end)

        ModulePanel.checkboxes[definition.key] = checkbox
    end

    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 24)
    statusText:SetWidth(290)
    statusText:SetJustifyH("LEFT")
    Locale.bindText(statusText, "EAM_MODULE_STATUS_READY", "模組設定已就緒。")
    if Theme and Theme.registerText then
        Theme.registerText(statusText, "body")
    end
    ModulePanel.statusText = statusText

    local closeButton = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetSize(90, 24)
    closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 18)
    Locale.bindText(closeButton, "EAM_ABOUT_CLOSE", "關閉")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    if Theme and Theme.registerButton then
        Theme.registerButton(closeButton)
    end

    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = "EAM_ModuleOptionsFrame"
    end
    frame:Hide()
    ModulePanel.frame = frame
    ModulePanel.refresh()
    return frame
end

function ModulePanel.open()
    if inCombat() then
        print(
            "|cff00ff96EAM|r "
                .. (EAM.L.EAM_MODULE_COMBAT_BLOCKED or "戰鬥中不開啟功能模組面板。")
        )
        return false, "combat"
    end
    local frame = createPanel()
    if not frame then
        return false, "frameUnavailable"
    end
    ModulePanel.refresh()
    frame:Show()
    return true
end

function ModulePanel.hide()
    if ModulePanel.frame then
        ModulePanel.frame:Hide()
    end
end