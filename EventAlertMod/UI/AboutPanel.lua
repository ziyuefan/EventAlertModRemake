--[[
檔案: UI\AboutPanel.lua

理念:
- 將專案版本、API 基準、實際客戶端 Build 與官方專案網址集中顯示。
- API 基準與實際客戶端身分分列，避免把離線目標版本冒充目前執行環境。

責任:
- 低頻讀取 TOC metadata、GetBuildInfo 與已確認的實機 client channel。
- 建立並管理 EAM 自有的唯讀資訊視窗。

邊界:
- 不在戰鬥中建立或開啟視窗。
- 不自動開瀏覽器、不寫入剪貼簿、不讀角色或帳號資料。
]]
local _, EAM = ...

EAM.UI = EAM.UI or {}

local api = EAM.API
local Theme = EAM.Theme
local Locale = EAM.Locale
local Util = EAM.Util
local Constants = EAM.Constants
local tinsert = table.insert
local stringFormat = string.format

local AboutPanel = {
    frame = nil,
    infoText = nil,
}
EAM.UI.AboutPanel = AboutPanel

local function readAddonVersion()
    local addons = api.C_AddOns
    local getter = addons and addons.GetAddOnMetadata or nil
    if type(getter) == "function" then
        local ok, value = pcall(getter, EAM.name or "EventAlertMod", "Version")
        if ok and Util.isSafeString(value) and value ~= "" then
            return value
        end
    end
    return EAM.L.EAM_ABOUT_UNKNOWN or "未知"
end

local function readObservedBuild()
    local patch = EAM.L.EAM_ABOUT_UNKNOWN or "未知"
    local build = EAM.L.EAM_ABOUT_UNKNOWN or "未知"
    local interface = EAM.L.EAM_ABOUT_UNKNOWN or "未知"
    if type(api.GetBuildInfo) == "function" then
        local ok, observedPatch, observedBuild, _, observedInterface = pcall(api.GetBuildInfo)
        if ok then
            if Util.isSafeString(observedPatch) then patch = observedPatch end
            if Util.isSafeString(observedBuild) then build = observedBuild end
            if Util.isSafeNumber(observedInterface) then interface = tostring(observedInterface) end
        end
    end
    return patch, build, interface
end

local function readClientChannel()
    local validation = EAM.Debug and EAM.Debug.ValidationEnvironment or nil
    if validation and type(validation.snapshot) == "function" then
        local ok, environment = pcall(validation.snapshot)
        if ok and type(environment) == "table" and Util.canAccessTable(environment) then
            local channel = environment.clientChannel
            if Util.isSafeString(channel) and channel ~= "UNCONFIRMED" and channel ~= "OFFLINE" then
                return channel
            end
        end
    end
    return EAM.L.EAM_ABOUT_CHANNEL_UNCONFIRMED or "未確認通道"
end

function AboutPanel.getInformation()
    local patch, build, interface = readObservedBuild()
    return {
        addonVersion = readAddonVersion(),
        author = Constants.PROJECT_AUTHOR,
        apiBaseline = Constants.API_BASELINE_LABEL .. " (Build " .. Constants.API_BASELINE_BUILD .. ")",
        compatibility = Constants.RETAIL_COMPATIBILITY_LABEL,
        clientChannel = readClientChannel(),
        clientPatch = patch,
        clientBuild = build,
        clientInterface = interface,
        repositoryURL = Constants.PROJECT_REPOSITORY_URL,
        pagesURL = Constants.PROJECT_PAGES_URL,
    }
end

function AboutPanel.formatInformation(info)
    info = info or AboutPanel.getInformation()
    return table.concat({
        (EAM.L.EAM_ABOUT_ADDON_VERSION or "插件版本：") .. info.addonVersion,
        (EAM.L.EAM_ABOUT_AUTHOR or "作者：") .. info.author,
        (EAM.L.EAM_ABOUT_API_BASELINE or "API 基準：") .. info.apiBaseline,
        (EAM.L.EAM_ABOUT_COMPATIBILITY or "相容版本：Retail ") .. info.compatibility,
        stringFormat(
            EAM.L.EAM_ABOUT_CLIENT_FORMAT or "目前客戶端：%s %s (Build %s, Interface %s)",
            info.clientChannel,
            info.clientPatch,
            info.clientBuild,
            info.clientInterface
        ),
        "",
        (EAM.L.EAM_ABOUT_REPOSITORY or "GitHub：") .. info.repositoryURL,
        (EAM.L.EAM_ABOUT_PAGES or "專案頁面：") .. info.pagesURL,
    }, "\n")
end

local function refreshLocalizedText()
    if AboutPanel.infoText then
        AboutPanel.infoText:SetText(AboutPanel.formatInformation())
    end
end

if Locale and type(Locale.registerRefresh) == "function" then
    Locale.registerRefresh(refreshLocalizedText)
end

local function createFrame()
    if AboutPanel.frame then
        return AboutPanel.frame
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return nil, "combatBlocked"
    end

    local frame = api.CreateFrame("Frame", "EAM_AboutPanel", UIParent, "BackdropTemplate")
    frame:SetSize(560, 310)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
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
        frame:Hide()
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0.08, 0.06, 0.05, 0.97)
    frame:SetBackdropBorderColor(0.8, 0.6, 0.4, 1)
    if Theme and Theme.registerFrame then Theme.registerFrame(frame, "window") end
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    title:SetTextColor(0.95, 0.85, 0.4, 1)
    Locale.bindText(title, "EAM_ABOUT_TITLE", "關於 EventAlertMod")
    if Theme and Theme.registerText then Theme.registerText(title, "title") end

    local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    infoText:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -62)
    infoText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 58)
    infoText:SetJustifyH("LEFT")
    infoText:SetJustifyV("TOP")
    infoText:SetTextColor(0.94, 0.90, 0.82, 1)
    if Theme and Theme.registerText then Theme.registerText(infoText, "body") end
    frame.infoText = infoText

    local closeButton = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(closeButton) end
    closeButton:SetSize(128, 28)
    closeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 22)
    Locale.bindText(closeButton, "EAM_ABOUT_CLOSE", "關閉")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    AboutPanel.frame = frame
    AboutPanel.infoText = infoText
    _G.EAM_AboutPanel = frame
    tinsert(UISpecialFrames, "EAM_AboutPanel")
    return frame
end

function AboutPanel.open()
    if api.InCombatLockdown and api.InCombatLockdown() then
        print("|cff00ff96EAM|r " .. (EAM.L.EAM_ABOUT_COMBAT_BLOCKED or "戰鬥中不開啟關於視窗。"))
        return false, "combatBlocked"
    end
    local frame, reason = createFrame()
    if not frame then
        return false, reason or "frameUnavailable"
    end
    frame.infoText:SetText(AboutPanel.formatInformation())
    local mainFrame = _G.EAM_MainOptionsFrame
    if mainFrame and mainFrame:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 2, 0)
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
    frame:Show()
    frame:Raise()
    return true
end
