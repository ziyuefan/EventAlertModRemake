--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/PlayerResourcePanel
檔案: UI\PlayerResourcePanel.lua

責任:
- 顯示目前職業／專精的玩家資源候選集合與安全 capability metadata。
- 以 draft 編輯 class default 或目前專精 override，再透過 SavedVariables 單次提交。
- 提供每資源獨立啟用、renderer、前景／背景、文字、位置、尺寸、透明度與順序設定。

邊界:
- 不讀 UnitPower、UnitPowerMax 或 UnitPowerPercent，不顯示或保存 runtime raw value。
- SECRET_DISPLAY 只允許視覺 sink；需 Lua 數字的文字控制會停用。
- 戰鬥中不建立或開啟設定 frame；結構性套用由 PlayerResourceService 延後。
]]
local _, EAM = ...

local api = EAM.API or {}
local Theme = EAM.Theme
local Locale = EAM.Locale
local Catalog = EAM.Data.PlayerResourceCatalog
local Capability = EAM.Services.PlayerResourceCapability
local freeze = EAM.Util and EAM.Util.tableFreeze or function(value)
    return value
end

local Panel = {
    frame = nil,
    rows = {},
    controls = {},
    selectedKey = nil,
    specializationID = nil,
    scope = "spec",
    draft = nil,
    refreshing = false,
}

EAM.UI.PlayerResourcePanel = Panel

local SETTING_FIELDS = freeze({
    "enabled",
    "displayMode",
    "anchor",
    "position",
    "showForeground",
    "showBackground",
    "showValue",
    "showPercent",
    "fullGlow",
    "threshold",
    "fontFamily",
    "fontSize",
    "valueFontSize",
    "valueOffsetX",
    "valueOffsetY",
    "orientation",
    "offsetX",
    "offsetY",
    "scale",
    "alpha",
    "foregroundAlpha",
    "backgroundAlpha",
    "order",
    "barWidth",
    "barHeight",
    "iconSize",
    "spacing",
})

local SLIDER_SPECS = freeze({
    freeze({ field = "fontSize", key = "EAM_RESOURCE_FONT_SIZE", fallback = "資源名稱文字大小", min = 8, max = 36, step = 1, integer = true }),
    freeze({ field = "valueFontSize", key = "EAM_RESOURCE_VALUE_FONT_SIZE", fallback = "數字文字大小", min = 8, max = 36, step = 1, integer = true }),
    freeze({ field = "valueOffsetX", key = "EAM_RESOURCE_VALUE_OFFSET_X", fallback = "數字文字水平偏移", min = -100, max = 100, step = 1, integer = true }),
    freeze({ field = "valueOffsetY", key = "EAM_RESOURCE_VALUE_OFFSET_Y", fallback = "數字文字垂直偏移", min = -100, max = 100, step = 1, integer = true }),
    freeze({ field = "offsetX", key = "EAM_RESOURCE_OFFSET_X", fallback = "水平位置", min = -1000, max = 1000, step = 5, integer = true }),
    freeze({ field = "offsetY", key = "EAM_RESOURCE_OFFSET_Y", fallback = "垂直位置", min = -1000, max = 1000, step = 5, integer = true }),
    freeze({ field = "scale", key = "EAM_RESOURCE_SCALE", fallback = "縮放", min = 0.25, max = 4, step = 0.05 }),
    freeze({ field = "alpha", key = "EAM_RESOURCE_ALPHA", fallback = "整體透明度", min = 0, max = 1, step = 0.05, percent = true }),
    freeze({ field = "threshold", key = "EAM_RESOURCE_THRESHOLD", fallback = "高亮門檻", min = 0, max = 1, step = 0.05, percent = true }),
    freeze({ field = "foregroundAlpha", key = "EAM_RESOURCE_FOREGROUND_ALPHA", fallback = "前景透明度", min = 0, max = 1, step = 0.05, percent = true }),
    freeze({ field = "backgroundAlpha", key = "EAM_RESOURCE_BACKGROUND_ALPHA", fallback = "背景資源透明度", min = 0, max = 1, step = 0.05, percent = true }),
    freeze({ field = "barWidth", key = "EAM_RESOURCE_BAR_WIDTH", fallback = "資源條寬度", min = 64, max = 400, step = 2, integer = true }),
    freeze({ field = "barHeight", key = "EAM_RESOURCE_BAR_HEIGHT", fallback = "資源條高度", min = 8, max = 60, step = 1, integer = true }),
    freeze({ field = "iconSize", key = "EAM_RESOURCE_ICON_SIZE", fallback = "圖示大小", min = 16, max = 80, step = 1, integer = true }),
    freeze({ field = "spacing", key = "EAM_RESOURCE_SPACING", fallback = "圖示與資源條間距", min = 0, max = 60, step = 1, integer = true }),
    freeze({ field = "order", key = "EAM_RESOURCE_ORDER", fallback = "顯示順序", min = 1, max = 17, step = 1, integer = true }),
})

local SLIDER_MAP = {}
for index = 1, #SLIDER_SPECS do
    local spec = SLIDER_SPECS[index]
    SLIDER_MAP[spec.field] = spec
end

local POINT_OPTIONS = freeze({
    "TOPLEFT",
    "TOP",
    "TOPRIGHT",
    "LEFT",
    "CENTER",
    "RIGHT",
    "BOTTOMLEFT",
    "BOTTOM",
    "BOTTOMRIGHT",
})

local function inCombat()
    return type(api.InCombatLockdown) == "function" and api.InCombatLockdown() == true
end

local function localized(key, fallback)
    return EAM.L and EAM.L[key] or fallback
end

local function getSpecializationID()
    if type(api.GetSpecialization) ~= "function" or type(api.GetSpecializationInfo) ~= "function" then
        return nil
    end
    local okIndex, index = pcall(api.GetSpecialization)
    if not okIndex or not EAM.Util.isSafePositiveNumber(index) then
        return nil
    end
    local okInfo, specializationID = pcall(api.GetSpecializationInfo, index)
    if okInfo and EAM.Util.isSafePositiveNumber(specializationID) then
        return specializationID
    end
    return nil
end

local function getClassToken()
    local saved = EAM.Modules and EAM.Modules.SavedVariables
    local classToken = saved and saved.getActiveClassToken and saved.getActiveClassToken() or nil
    if classToken then
        return classToken
    end
    if type(api.UnitClass) == "function" then
        local ok, _, token = pcall(api.UnitClass, "player")
        if ok and EAM.Util.isSafeString(token) then
            return token
        end
    end
    return nil
end

local function getScopeSpecializationID()
    if Panel.scope == "spec" then
        return Panel.specializationID
    end
    return nil
end

local function capabilityText(value)
    if value == Capability.NUMERIC then
        return localized("EAM_RESOURCE_CAPABILITY_NUMERIC", "NUMERIC：可安全顯示數字")
    end
    if value == Capability.SECRET_DISPLAY then
        return localized("EAM_RESOURCE_CAPABILITY_SECRET", "SECRET_DISPLAY：僅原生視覺")
    end
    return localized("EAM_RESOURCE_CAPABILITY_UNAVAILABLE", "UNAVAILABLE：目前不可用")
end

local function copyDraft(config)
    local draft = {}
    for index = 1, #SETTING_FIELDS do
        local field = SETTING_FIELDS[index]
        draft[field] = config[field]
    end
    return draft
end

local function autoApplyDraft()
    if Panel.refreshing or not Panel.selectedKey or not Panel.draft then
        return
    end
    local saved = EAM.Modules and EAM.Modules.SavedVariables
    if not saved or type(saved.updatePlayerResourceConfig) ~= "function" then
        return
    end
    local ok, status = saved.updatePlayerResourceConfig(
        Panel.selectedKey,
        Panel.draft,
        getScopeSpecializationID()
    )
    if ok then
        local service = EAM.Services and EAM.Services.PlayerResourceService
        local serviceStatus = service and service.getStatus and service.getStatus() or nil
        if serviceStatus and serviceStatus.lastConfigResult == "combatRebuildDeferred" then
            Panel.statusText:SetText(localized("EAM_RESOURCE_STATUS_DEFERRED", "設定已保存，離開戰鬥後套用。"))
        else
            Panel.statusText:SetText(localized("EAM_RESOURCE_STATUS_APPLIED_NOW", "資源設定已即時生效。"))
        end
        if EAM.UI.PreviewPanel and EAM.UI.PreviewPanel.refresh then
            EAM.UI.PreviewPanel.refresh()
        end
    end
end

local function updateSliderValueText(slider, value)
    if slider.eamPercent then
        slider.valueText:SetText(math.floor(value * 100 + 0.5) .. "%")
    elseif slider.eamInteger then
        slider.valueText:SetText(math.floor(value + 0.5))
    else
        slider.valueText:SetText(string.format("%.2f", value))
    end
end

local function createCheckbox(parent, field, key, fallback, x, y, tooltipText, tooltipTitle)
    local checkbox = api.CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", checkbox, "RIGHT", 3, 0)
    Locale.bindText(label, key, fallback)
    if Theme and Theme.registerText then
        Theme.registerText(label, "body")
    end
    if tooltipText and EAM.UI.setTooltip then
        EAM.UI.setTooltip(checkbox, tooltipText, tooltipTitle or fallback)
    end
    checkbox:SetScript("OnClick", function(self)
        if not Panel.refreshing and Panel.draft then
            Panel.draft[field] = self:GetChecked() == true
            autoApplyDraft()
        end
    end)
    Panel.controls[field] = checkbox
    return checkbox
end

local function createSlider(parent, spec, x, y)
    local slider = api.CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetSize(210, 16)
    slider:SetMinMaxValues(spec.min, spec.max)
    slider:SetValueStep(spec.step)
    slider:SetObeyStepOnDrag(true)
    slider.eamField = spec.field
    slider.eamPercent = spec.percent == true
    slider.eamInteger = spec.integer == true

    local label = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 5)
    Locale.bindText(label, spec.key, spec.fallback)
    if Theme and Theme.registerText then
        Theme.registerText(label, "body")
    end

    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(slider, "調整此項資源之" .. (spec.fallback or "數值"), spec.fallback)
    end

    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 5)
    if Theme and Theme.registerText then
        Theme.registerText(valueText, "body")
    end
    slider.valueText = valueText
    slider:SetScript("OnValueChanged", function(self, value)
        updateSliderValueText(self, value)
        if not Panel.refreshing and Panel.draft then
            Panel.draft[self.eamField] = self.eamInteger and math.floor(value + 0.5) or value
            autoApplyDraft()
        end
    end)
    Panel.controls[spec.field] = slider
    return slider
end

local function pointLabel(field, value)
    local labelKey = field == "anchor" and "EAM_RESOURCE_ANCHOR" or "EAM_RESOURCE_POSITION"
    local fallback = field == "anchor" and "父框架錨點" or "資源框架定位點"
    return localized(labelKey, fallback) .. "：" .. (value or "TOPLEFT")
end

local function cyclePoint(field)
    if not Panel.draft then
        return
    end
    local current = Panel.draft[field]
    local nextIndex = 1
    for index = 1, #POINT_OPTIONS do
        if POINT_OPTIONS[index] == current then
            nextIndex = index % #POINT_OPTIONS + 1
            break
        end
    end
    local value = POINT_OPTIONS[nextIndex]
    Panel.draft[field] = value
    Panel.controls[field]:SetText(pointLabel(field, value))
    autoApplyDraft()
end

local function cycleOrientation()
    if not Panel.draft then
        return
    end
    Panel.draft.orientation = Panel.draft.orientation == "VERTICAL" and "HORIZONTAL" or "VERTICAL"
    Panel.orientationButton:SetText(
        localized("EAM_RESOURCE_ORIENTATION", "方向") .. "："
            .. localized("EAM_RESOURCE_ORIENTATION_" .. Panel.draft.orientation, Panel.draft.orientation)
    )
    autoApplyDraft()
end

local function getFontOptionsList()
    local MediaService = EAM.Services and EAM.Services.MediaService
    local mediaList = MediaService and MediaService.getMediaList and MediaService.getMediaList("font")
    if mediaList and #mediaList > 0 then
        return mediaList
    end
    return EAM.Constants and EAM.Constants.FONT_FAMILY_OPTIONS or {}
end

local function fontFamilyLabel(value)
    local MediaService = EAM.Services and EAM.Services.MediaService
    if MediaService and MediaService.getMediaList then
        local mediaList = MediaService.getMediaList("font")
        for _, item in ipairs(mediaList) do
            if item.value == value then
                return item.text or item.value
            end
        end
    end
    local options = EAM.Constants and EAM.Constants.FONT_FAMILY_OPTIONS or {}
    for index = 1, #options do
        if options[index].value == value then
            return localized(options[index].labelKey, value)
        end
    end
    return value or "STANDARD"
end

local function cycleFontFamily()
    if not Panel.draft then
        return
    end
    local options = getFontOptionsList()
    if #options == 0 then
        return
    end
    local nextIndex = 1
    for index = 1, #options do
        if options[index].value == Panel.draft.fontFamily then
            nextIndex = index % #options + 1
            break
        end
    end
    Panel.draft.fontFamily = options[nextIndex].value
    Panel.fontFamilyButton:SetText(
        localized("EAM_RESOURCE_FONT_FAMILY", "字型") .. "："
            .. fontFamilyLabel(Panel.draft.fontFamily)
    )
    autoApplyDraft()
end

local function refreshScopeButton()
    if not Panel.scopeButton then
        return
    end
    local text = Panel.scope == "spec"
        and localized("EAM_RESOURCE_SCOPE_SPEC", "目前專精覆寫")
        or localized("EAM_RESOURCE_SCOPE_CLASS", "職業預設")
    Panel.scopeButton:SetText(text)
    Panel.resetButton:SetEnabled(Panel.scope == "spec" and Panel.specializationID ~= nil)
end

local function refreshEditor()
    if not Panel.frame or not Panel.selectedKey then
        return
    end
    local saved = EAM.Modules and EAM.Modules.SavedVariables
    local definition = Catalog.getDefinition(Panel.selectedKey)
    if not saved or not definition then
        return
    end
    local config, reason = saved.getPlayerResourceConfig(
        Panel.selectedKey,
        getScopeSpecializationID()
    )
    if type(config) ~= "table" then
        Panel.statusText:SetText(localized("EAM_RESOURCE_STATUS_FAILED", "讀取設定失敗：") .. (reason or "unknown"))
        return
    end

    Panel.draft = copyDraft(config)
    Panel.refreshing = true
    Locale.bindText(Panel.selectedName, definition.nameKey, definition.fallbackName)
    local capability = Capability.classify(definition)
    Panel.capabilityText:SetText(capabilityText(capability))
    Panel.controls.enabled:SetChecked(config.enabled == true)
    Panel.controls.showForeground:SetChecked(config.showForeground == true)
    Panel.controls.showBackground:SetChecked(config.showBackground == true)
    local numericCapability = capability == Capability.NUMERIC
    Panel.controls.showValue:SetChecked(config.showValue == true)
    Panel.controls.showValue:SetEnabled(numericCapability)
    if Panel.controls.showPercent then
        Panel.controls.showPercent:SetChecked(config.showPercent == true)
        Panel.controls.showPercent:SetEnabled(numericCapability)
    end
    if Panel.controls.fullGlow then
        Panel.controls.fullGlow:SetChecked(config.fullGlow == true)
        Panel.controls.fullGlow:SetEnabled(numericCapability)
    end
    if Panel.controls.valueFontSize then
        Panel.controls.valueFontSize:SetEnabled(numericCapability)
    end
    if Panel.controls.valueOffsetX then
        Panel.controls.valueOffsetX:SetEnabled(numericCapability)
    end
    if Panel.controls.valueOffsetY then
        Panel.controls.valueOffsetY:SetEnabled(numericCapability)
    end
    if Panel.controls.threshold then
        Panel.controls.threshold:SetEnabled(numericCapability)
    end
    Panel.modeButton:SetText(
        localized("EAM_RESOURCE_DISPLAY_MODE", "顯示模式")
            .. "："
            .. localized("EAM_RESOURCE_MODE_" .. config.displayMode, config.displayMode)
    )
    Panel.controls.anchor:SetText(pointLabel("anchor", config.anchor))
Panel.controls.position:SetText(pointLabel("position", config.position))
    Panel.orientationButton:SetText(
        localized("EAM_RESOURCE_ORIENTATION", "方向") .. "："
            .. localized("EAM_RESOURCE_ORIENTATION_" .. config.orientation, config.orientation)
    )
    Panel.fontFamilyButton:SetText(
        localized("EAM_RESOURCE_FONT_FAMILY", "字型") .. "："
            .. fontFamilyLabel(config.fontFamily)
    )
    for index = 1, #SLIDER_SPECS do
        local spec = SLIDER_SPECS[index]
        local value = config[spec.field]
        Panel.controls[spec.field]:SetValue(value)
        updateSliderValueText(Panel.controls[spec.field], value)
    end
    Panel.refreshing = false
    refreshScopeButton()
end

local function selectResource(resourceKey)
    Panel.selectedKey = resourceKey
    for index = 1, #Panel.rows do
        local row = Panel.rows[index]
        if row.resourceKey == resourceKey then
            row.button:LockHighlight()
        else
            row.button:UnlockHighlight()
        end
    end
    refreshEditor()
end

function Panel.refresh()
    if not Panel.frame then
        return false, "frameUnavailable"
    end
    Panel.specializationID = getSpecializationID()
    if not Panel.specializationID then
        Panel.scope = "class"
    end
    local classToken = getClassToken()
    local resourceKeys = classToken and Catalog.getSpecResourceKeys(classToken, Panel.specializationID) or nil
    local selectedAvailable = false

    for index = 1, #Panel.rows do
        local row = Panel.rows[index]
        local key = resourceKeys and resourceKeys[index] or nil
        local definition = key and Catalog.getDefinition(key) or nil
        if definition then
            row.resourceKey = key
            Locale.bindText(row.nameText, definition.nameKey, definition.fallbackName)
            local capability = Capability.classify(definition)
            row.capabilityText:SetText(capabilityText(capability))
            row.button:Show()
            if key == Panel.selectedKey then
                selectedAvailable = true
            end
        else
            row.resourceKey = nil
            row.button:Hide()
        end
    end

    if not selectedAvailable then
        Panel.selectedKey = resourceKeys and resourceKeys[1] or nil
    end
    if Panel.selectedKey then
        selectResource(Panel.selectedKey)
    else
        Panel.selectedName:SetText(localized("EAM_RESOURCE_NONE", "沒有可設定的玩家資源"))
    end
    refreshScopeButton()
    return true, "refreshed"
end

local function createPanel()
    if Panel.frame then
        return Panel.frame
    end
    if inCombat() or type(api.CreateFrame) ~= "function" then
        return nil
    end

    local frame = api.CreateFrame("Frame", "EAM_PlayerResourceOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(720, 520)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        local mainFrame = _G.EAM_MainOptionsFrame
        if mainFrame and mainFrame:IsShown() then
            mainFrame:StartMoving()
        else
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        local mainFrame = _G.EAM_MainOptionsFrame
        if mainFrame and mainFrame:IsShown() then
            mainFrame:StopMovingOrSizing()
        else
            frame:StopMovingOrSizing()
        end
    end)
    local titleClose = api.CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    titleClose:SetSize(28, 28)
    titleClose:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    titleClose:SetScript("OnClick", function()
        Panel.hide()
    end)

    local previewBtn = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    previewBtn:SetSize(88, 22)
    previewBtn:SetPoint("RIGHT", titleClose, "LEFT", -6, 0)
    previewBtn:SetText(localized("EAM_PREVIEW_BTN", "效果預覽"))
    if Theme and Theme.registerButton then Theme.registerButton(previewBtn) end
    if EAM.UI.setTooltip then EAM.UI.setTooltip(previewBtn, "開啟或關閉獨立的即時效果預覽小視窗", "效果預覽") end
    previewBtn:SetScript("OnClick", function()
        if EAM.UI.PreviewPanel and EAM.UI.PreviewPanel.toggle then
            EAM.UI.PreviewPanel.toggle()
        end
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
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
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    Locale.bindText(title, "EAM_RESOURCE_PANEL_TITLE", "玩家職業資源")
    if Theme and Theme.registerText then
        Theme.registerText(title, "title")
    end

    local description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -38)
    description:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -38)
    description:SetJustifyH("LEFT")
    Locale.bindText(description, "EAM_RESOURCE_PANEL_DESC", "每種資源獨立設定；Secret 資源只送入原生視覺，不顯示 Lua 數字。")
    if Theme and Theme.registerText then
        Theme.registerText(description, "body")
    end

    -- 左側：資源清單面板
    local listPanel = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -58)
    listPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 52)
    listPanel:SetWidth(190)
    listPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    listPanel:SetBackdropColor(0.08, 0.05, 0.03, 0.8)
    listPanel:SetBackdropBorderColor(0.5, 0.35, 0.2, 0.8)
    if Theme and Theme.registerFrame then
        Theme.registerFrame(listPanel, "panel")
    end

    local scopeButton = api.CreateFrame("Button", nil, listPanel, "UIPanelButtonTemplate")
    scopeButton:SetSize(174, 24)
    scopeButton:SetPoint("TOP", listPanel, "TOP", 0, -10)
    if Theme and Theme.registerButton then
        Theme.registerButton(scopeButton)
    end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(scopeButton, "切換目前專精專屬設定或全職業通用預設配置", "設定範圍")
    end
    scopeButton:SetScript("OnClick", function()
        if Panel.specializationID then
            Panel.scope = Panel.scope == "spec" and "class" or "spec"
            refreshEditor()
        end
    end)
    Panel.scopeButton = scopeButton

    for index = 1, 5 do
        local button = api.CreateFrame("Button", nil, listPanel, "UIPanelButtonTemplate")
        button:SetSize(174, 40)
        button:SetPoint("TOP", listPanel, "TOP", 0, -40 - (index - 1) * 46)
        if Theme and Theme.registerButton then
            Theme.registerButton(button)
        end
        if EAM.UI.setTooltip then
            EAM.UI.setTooltip(button, "點擊選取此項資源進行細部顯示與排版設定", "選擇資源")
        end
        local nameText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        nameText:SetPoint("TOPLEFT", button, "TOPLEFT", 8, -5)
        local capabilityLabel = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        capabilityLabel:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 8, 4)
        if Theme and Theme.registerText then
            Theme.registerText(nameText, "button")
            Theme.registerText(capabilityLabel, "buttonDisabled")
        end
        local row = {
            button = button,
            nameText = nameText,
            capabilityText = capabilityLabel,
            resourceKey = nil,
        }
        button:SetScript("OnClick", function()
            if row.resourceKey then
                selectResource(row.resourceKey)
            end
        end)
        Panel.rows[index] = row
    end

    -- 右側頂部：當前選取資源名稱與安全 Capability
    local selectedName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    selectedName:SetPoint("TOPLEFT", frame, "TOPLEFT", 216, -58)
    if Theme and Theme.registerText then
        Theme.registerText(selectedName, "title")
    end
    Panel.selectedName = selectedName

    local capabilityLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    capabilityLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 216, -84)
    if Theme and Theme.registerText then
        Theme.registerText(capabilityLabel, "body")
    end
    Panel.capabilityText = capabilityLabel

    -- 右側 Tab 分頁系統 (4 大分類)
    local tabDefs = {
        { key = "EAM_RESOURCE_TAB_DISPLAY", fallback = "顯示與模式" },
        { key = "EAM_RESOURCE_TAB_SIZING", fallback = "條形與尺寸" },
        { key = "EAM_RESOURCE_TAB_POSITION", fallback = "位置與錨點" },
        { key = "EAM_RESOURCE_TAB_TEXT", fallback = "數值與文字" },
    }

    local tabButtons = {}
    local tabPages = {}
    local currentTab = 1

    local editorInner = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    editorInner:SetPoint("TOPLEFT", frame, "TOPLEFT", 216, -136)
    editorInner:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 52)
    editorInner:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    editorInner:SetBackdropColor(0.08, 0.05, 0.03, 0.8)
    editorInner:SetBackdropBorderColor(0.5, 0.35, 0.2, 0.8)
    if Theme and Theme.registerFrame then
        Theme.registerFrame(editorInner, "panel")
    end

    local function selectTab(tabIdx)
        currentTab = tabIdx
        for idx = 1, #tabDefs do
            local page = tabPages[idx]
            local btn = tabButtons[idx]
            if page then
                if idx == tabIdx then
                    page:Show()
                else
                    page:Hide()
                end
            end
            if btn then
                if idx == tabIdx then
                    btn:SetAlpha(1.0)
                    if btn.tabText then
                        btn.tabText:SetTextColor(1.0, 0.85, 0.2, 1.0)
                    end
                else
                    btn:SetAlpha(0.65)
                    if btn.tabText then
                        btn.tabText:SetTextColor(0.75, 0.75, 0.75, 1.0)
                    end
                end
            end
        end
    end

    local tabStartX = 216
    local tabWidth = 117
    local tabGap = 6
    for idx, def in ipairs(tabDefs) do
        local btn = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        if Theme and Theme.registerButton then Theme.registerButton(btn) end
        btn:SetSize(tabWidth, 24)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", tabStartX + (idx - 1) * (tabWidth + tabGap), -108)

        local tabText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tabText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        Locale.bindText(tabText, def.key, def.fallback)
        btn.tabText = tabText

        btn:SetScript("OnClick", function()
            selectTab(idx)
        end)
        tabButtons[idx] = btn

        local page = api.CreateFrame("Frame", nil, editorInner)
        page:SetAllPoints(editorInner)
        page:Hide()
        tabPages[idx] = page
    end

    -- 【Tab 1: 顯示與模式 (Display & Mode)】
    local pageDisplay = tabPages[1]
    createCheckbox(pageDisplay, "enabled", "EAM_RESOURCE_ENABLED", "啟用此資源", 16, -14, "啟用/停用此項職業資源之畫面監控", "啟用此資源")
    createCheckbox(pageDisplay, "showForeground", "EAM_RESOURCE_SHOW_FOREGROUND", "前景時顯示", 165, -14, "主要資源或前景焦點時顯示", "前景時顯示")
    createCheckbox(pageDisplay, "showBackground", "EAM_RESOURCE_SHOW_BACKGROUND", "背景時顯示", 315, -14, "非主要焦點或背景資源時顯示", "背景時顯示")

    local modeButton = api.CreateFrame("Button", nil, pageDisplay, "UIPanelButtonTemplate")
    modeButton:SetSize(210, 24)
    modeButton:SetPoint("TOPLEFT", pageDisplay, "TOPLEFT", 16, -48)
    if Theme and Theme.registerButton then
        Theme.registerButton(modeButton)
    end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(modeButton, "切換資源條顯示風格（自動/長條條形/離散點數）", "顯示模式")
    end
    modeButton:SetScript("OnClick", function()
        if not Panel.draft then
            return
        end
        local current = Panel.draft.displayMode
        Panel.draft.displayMode = current == "AUTO" and "BAR" or current == "BAR" and "POINTS" or "AUTO"
        modeButton:SetText(
            localized("EAM_RESOURCE_DISPLAY_MODE", "顯示模式")
                .. "："
                .. localized("EAM_RESOURCE_MODE_" .. Panel.draft.displayMode, Panel.draft.displayMode)
        )
        autoApplyDraft()
    end)
    Panel.modeButton = modeButton

    local orientationButton = api.CreateFrame("Button", nil, pageDisplay, "UIPanelButtonTemplate")
    orientationButton:SetSize(210, 24)
    orientationButton:SetPoint("TOPLEFT", pageDisplay, "TOPLEFT", 250, -48)
    if Theme and Theme.registerButton then
        Theme.registerButton(orientationButton)
    end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(orientationButton, "切換資源條生長排列方向（水平或垂直）", "排列方向")
    end
    orientationButton:SetScript("OnClick", cycleOrientation)
    Panel.orientationButton = orientationButton

    createCheckbox(pageDisplay, "fullGlow", "EAM_RESOURCE_FULL_GLOW", "高於門檻時高亮", 16, -88, "當資源達到高亮門檻時觸發閃爍流光特效", "高於門檻時高亮")

    createSlider(pageDisplay, SLIDER_MAP.threshold, 16, -135)
    createSlider(pageDisplay, SLIDER_MAP.order, 250, -135)
    createSlider(pageDisplay, SLIDER_MAP.alpha, 16, -185)
    createSlider(pageDisplay, SLIDER_MAP.foregroundAlpha, 250, -185)
    createSlider(pageDisplay, SLIDER_MAP.backgroundAlpha, 16, -235)

    -- 【Tab 2: 條形與尺寸 (Bar & Dimensions)】
    local pageSizing = tabPages[2]
    createSlider(pageSizing, SLIDER_MAP.barWidth, 16, -25)
    createSlider(pageSizing, SLIDER_MAP.barHeight, 250, -25)
    createSlider(pageSizing, SLIDER_MAP.iconSize, 16, -85)
    createSlider(pageSizing, SLIDER_MAP.spacing, 250, -85)
    createSlider(pageSizing, SLIDER_MAP.scale, 16, -145)

    -- 【Tab 3: 位置與錨點 (Position & Anchor)】
    local pagePosition = tabPages[3]
    local anchorButton = api.CreateFrame("Button", nil, pagePosition, "UIPanelButtonTemplate")
    anchorButton:SetSize(210, 24)
    anchorButton:SetPoint("TOPLEFT", pagePosition, "TOPLEFT", 16, -18)
    if Theme and Theme.registerButton then
        Theme.registerButton(anchorButton)
    end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(anchorButton, "循環切換資源框架相對於父錨點的位置", "父框架錨點")
    end
    anchorButton:SetScript("OnClick", function()
        cyclePoint("anchor")
    end)
    Panel.controls.anchor = anchorButton

    local positionButton = api.CreateFrame("Button", nil, pagePosition, "UIPanelButtonTemplate")
    positionButton:SetSize(210, 24)
    positionButton:SetPoint("TOPLEFT", pagePosition, "TOPLEFT", 250, -18)
    if Theme and Theme.registerButton then
        Theme.registerButton(positionButton)
    end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(positionButton, "循環切換自身定位錨點", "資源框架定位點")
    end
    positionButton:SetScript("OnClick", function()
        cyclePoint("position")
    end)
    Panel.controls.position = positionButton

    createSlider(pagePosition, SLIDER_MAP.offsetX, 16, -75)
    createSlider(pagePosition, SLIDER_MAP.offsetY, 250, -75)

    local posDesc = pagePosition:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    posDesc:SetPoint("TOPLEFT", pagePosition, "TOPLEFT", 16, -135)
    posDesc:SetWidth(440)
    posDesc:SetJustifyH("LEFT")
    posDesc:SetText("父框架錨點決定參考點，定位點決定資源自身的對齊原點；偏移數值正負代表相對於原點的像素距離。")

    -- 【Tab 4: 數值與文字 (Values & Text)】
    local pageText = tabPages[4]
    createCheckbox(pageText, "showValue", "EAM_RESOURCE_SHOW_VALUE", "顯示安全數字", 16, -14, "在資源條旁顯示即時能量數值（僅非秘密資源支援）", "顯示安全數字")
    createCheckbox(pageText, "showPercent", "EAM_RESOURCE_SHOW_PERCENT", "顯示百分比", 250, -14, "在資源條旁顯示即時能量百分比", "顯示百分比")

    local fontFamilyButton = api.CreateFrame("Button", nil, pageText, "UIPanelButtonTemplate")
    fontFamilyButton:SetSize(444, 24)
    fontFamilyButton:SetPoint("TOPLEFT", pageText, "TOPLEFT", 16, -48)
    if Theme and Theme.registerButton then
        Theme.registerButton(fontFamilyButton)
    end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(fontFamilyButton, "切換資源文字所使用的字型", "字型選擇")
    end
    fontFamilyButton:SetScript("OnClick", cycleFontFamily)
    Panel.fontFamilyButton = fontFamilyButton

    createSlider(pageText, SLIDER_MAP.fontSize, 16, -100)
    createSlider(pageText, SLIDER_MAP.valueFontSize, 250, -100)
    createSlider(pageText, SLIDER_MAP.valueOffsetX, 16, -160)
    createSlider(pageText, SLIDER_MAP.valueOffsetY, 250, -160)

    -- 預設選取 Tab 1
    selectTab(1)

    -- 底部狀態與操作按鈕
    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 20)
    statusText:SetWidth(380)
    statusText:SetJustifyH("LEFT")
    Locale.bindText(statusText, "EAM_RESOURCE_STATUS_READY", "玩家資源設定已就緒。")
    if Theme and Theme.registerText then
        Theme.registerText(statusText, "body")
    end
    Panel.statusText = statusText

    local closeButton = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetSize(80, 24)
    closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
    Locale.bindText(closeButton, "EAM_ABOUT_CLOSE", "關閉")
    if Theme and Theme.registerButton then
        Theme.registerButton(closeButton)
    end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(closeButton, "關閉玩家職業資源設定面板", "關閉")
    end
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    local resetButton = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetButton:SetSize(115, 24)
    resetButton:SetPoint("RIGHT", closeButton, "LEFT", -6, 0)
    Locale.bindText(resetButton, "EAM_RESOURCE_RESET_SPEC", "清除專精覆寫")
    if Theme and Theme.registerButton then
        Theme.registerButton(resetButton)
    end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(resetButton, "清除當前專精之專屬覆寫並恢復為職業預設值", "清除專精覆寫")
    end
    resetButton:SetScript("OnClick", function()
        if Panel.scope ~= "spec" or not Panel.specializationID or not Panel.selectedKey then
            return
        end
        local saved = EAM.Modules and EAM.Modules.SavedVariables
        local ok, status = saved.updatePlayerResourceConfig(
            Panel.selectedKey,
            { resetToClass = true },
            Panel.specializationID
        )
        if ok then
            local service = EAM.Services and EAM.Services.PlayerResourceService
            local serviceStatus = service and service.getStatus and service.getStatus() or nil
            if serviceStatus and serviceStatus.lastConfigResult == "combatRebuildDeferred" then
                Panel.statusText:SetText(localized("EAM_RESOURCE_STATUS_DEFERRED", "設定已保存，離開戰鬥後套用。"))
            else
                Panel.statusText:SetText(localized("EAM_RESOURCE_STATUS_APPLIED_NOW", "資源設定已立即套用。"))
            end
            Panel.refresh()
        elseif status == "unchanged" then
            Panel.statusText:SetText(localized("EAM_RESOURCE_STATUS_UNCHANGED", "設定沒有變更。"))
        else
            Panel.statusText:SetText(localized("EAM_RESOURCE_STATUS_FAILED", "套用失敗：") .. (status or "unknown"))
        end
    end)
    Panel.resetButton = resetButton

    local applyButton = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    applyButton:SetSize(85, 24)
    applyButton:SetPoint("RIGHT", resetButton, "LEFT", -6, 0)
    Locale.bindText(applyButton, "EAM_RESOURCE_APPLY", "套用")
    if Theme and Theme.registerButton then
        Theme.registerButton(applyButton)
    end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(applyButton, "立即提交並套用當前資源的所有設定", "套用")
    end
    applyButton:SetScript("OnClick", function()
        local saved = EAM.Modules and EAM.Modules.SavedVariables
        if not saved or not Panel.selectedKey or not Panel.draft then
            return
        end
        local ok, status = saved.updatePlayerResourceConfig(
            Panel.selectedKey,
            Panel.draft,
            getScopeSpecializationID()
        )
        if ok then
            local service = EAM.Services and EAM.Services.PlayerResourceService
            local serviceStatus = service and service.getStatus and service.getStatus() or nil
            if serviceStatus and serviceStatus.lastConfigResult == "combatRebuildDeferred" then
                Panel.statusText:SetText(localized("EAM_RESOURCE_STATUS_DEFERRED", "設定已保存，離開戰鬥後套用。"))
            else
                Panel.statusText:SetText(localized("EAM_RESOURCE_STATUS_APPLIED_NOW", "資源設定已立即套用。"))
            end
            Panel.refresh()
        elseif status == "unchanged" then
            Panel.statusText:SetText(localized("EAM_RESOURCE_STATUS_UNCHANGED", "設定沒有變更。"))
        else
            Panel.statusText:SetText(localized("EAM_RESOURCE_STATUS_FAILED", "套用失敗：") .. (status or "unknown"))
        end
    end)

    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = "EAM_PlayerResourceOptionsFrame"
    end
    frame:Hide()
    Panel.frame = frame
    Panel.refresh()
    return frame
end

function Panel.open()
    if inCombat() then
        print("|cff00ff96EAM|r " .. localized("EAM_RESOURCE_COMBAT_BLOCKED", "戰鬥中不開啟玩家資源設定。"))
        return false, "combat"
    end
    if EAM.UI and type(EAM.UI.closeAllSidePanels) == "function" then
        EAM.UI.closeAllSidePanels("resource")
    end
    local frame = createPanel()
    if not frame then
        return false, "frameUnavailable"
    end
    Panel.refresh()
    local mainFrame = _G.EAM_MainOptionsFrame
    if mainFrame and mainFrame:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 2, 0)
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    end
    frame:Show()
    local service = EAM.Services and EAM.Services.PlayerResourceService
    if service and type(service.refreshVisualState) == "function" then
        service.refreshVisualState("resourcePanelOpened")
    end
    if EAM.UI and EAM.UI.Renderer and EAM.UI.Renderer.setActiveAnchors then
        EAM.UI.Renderer.setActiveAnchors("classPower")
    end
    return true, "opened"
end

function Panel.hide()
    if Panel.frame then
        Panel.frame:Hide()
        local service = EAM.Services and EAM.Services.PlayerResourceService
        if service and type(service.refreshVisualState) == "function" then
            service.refreshVisualState("resourcePanelClosed")
        end
    end
    if EAM.UI and EAM.UI.Renderer and EAM.UI.Renderer.setActiveAnchors then
        EAM.UI.Renderer.setActiveAnchors(nil)
    end
end

function Panel.close()
    Panel.hide()
end

if Locale and type(Locale.registerRefresh) == "function" then
    Locale.registerRefresh(Panel.refresh)
end