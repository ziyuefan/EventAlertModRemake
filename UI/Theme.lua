--[[
EventAlertMod Retail Rewrite
Module: UI/Theme
檔案: UI\Theme.lua

理念:
- 將 EAM 自有視窗的色彩、背景與邊框集中管理，讓主題切換不散落在各 UI 模組。
- 提供 EAM、FF7、Windows XP、Borland、DOS CRT 與 macOS Aqua 六個低風險 palette；不替換 Blizzard secure/protected widget。

責任:
- 保存靜態主題選項與目前選擇。
- 對已註冊的 EAM 視窗與文字區域套用背景、邊框與文字色彩。

邊界:
- 不讀取 aura、cooldown、UnitPower 或任何 Secret Value。
- 不修改 SavedVariables；持久化由 Core/SavedVariables.lua 管理。
- 不在戰鬥中建立 frame 或修改 Blizzard secure frame。

正式服 API 注意:
- 只使用一般 Frame backdrop 與 FontString 色彩 setter；12.0.7／12.1 均可降級至現有內建素材。
- FF7、Windows XP、Borland、DOS CRT 與 macOS Aqua 是 EAM 自有視覺 palette，不代表 Blizzard 官方主題或外部素材授權。
]]
local _, EAM = ...

EAM.UI = EAM.UI or {}

local Util = EAM.Util or {}
local freeze = Util.tableFreeze or function(value) return value end

local function color(red, green, blue, alpha)
    return freeze({ red, green, blue, alpha or 1 })
end

local function backdrop(bgFile, edgeFile, tile, tileSize, edgeSize, insets)
    return {
        bgFile = bgFile,
        edgeFile = edgeFile,
        tile = tile,
        tileSize = tileSize,
        edgeSize = edgeSize,
        insets = {
            left = insets.left,
            right = insets.right,
            top = insets.top,
            bottom = insets.bottom,
        },
    }
end

local palettes = freeze({
    eam = freeze({
        label = "EAM",
        backdrops = freeze({
            window = freeze(backdrop(
                "Interface\\ChatFrame\\ChatFrameBackground",
                "Interface\\DialogFrame\\UI-DialogBox-Border",
                true,
                32,
                32,
                { left = 8, right = 8, top = 8, bottom = 8 }
            )),
            panel = freeze(backdrop(
                "Interface\\ChatFrame\\ChatFrameBackground",
                "Interface\\Tooltips\\UI-Tooltip-Border",
                true,
                16,
                16,
                { left = 4, right = 4, top = 4, bottom = 4 }
            )),
            menu = freeze(backdrop(
                "Interface\\ChatFrame\\ChatFrameBackground",
                "Interface\\Tooltips\\UI-Tooltip-Border",
                true,
                12,
                12,
                { left = 3, right = 3, top = 3, bottom = 3 }
            )),
        }),
        background = color(0.12, 0.08, 0.06, 0.96),
        border = color(0.80, 0.60, 0.40, 1),
        panelBackground = color(0.08, 0.05, 0.03, 0.80),
        panelBorder = color(0.50, 0.35, 0.20, 0.80),
        menuBackground = color(0.05, 0.05, 0.05, 0.96),
        menuBorder = color(0.60, 0.40, 0.20, 1),
        titleText = color(0.95, 0.85, 0.40, 1),
        bodyText = color(0.94, 0.90, 0.82, 1),
        buttonNormal = color(0.42, 0.22, 0.08, 1),
        buttonHighlight = color(0.86, 0.62, 0.20, 1),
        buttonPushed = color(0.24, 0.10, 0.03, 1),
        buttonDisabled = color(0.22, 0.22, 0.22, 1),
        buttonText = color(1.00, 0.90, 0.55, 1),
        buttonDisabledText = color(0.55, 0.55, 0.55, 1),
    }),
    ff7 = freeze({
        label = "FF7",
        backdrops = freeze({
            window = freeze(backdrop(
                "Interface\\ChatFrame\\ChatFrameBackground",
                "Interface\\DialogFrame\\UI-DialogBox-Border",
                true,
                32,
                32,
                { left = 8, right = 8, top = 8, bottom = 8 }
            )),
            panel = freeze(backdrop(
                "Interface\\ChatFrame\\ChatFrameBackground",
                "Interface\\Tooltips\\UI-Tooltip-Border",
                true,
                16,
                16,
                { left = 4, right = 4, top = 4, bottom = 4 }
            )),
            menu = freeze(backdrop(
                "Interface\\ChatFrame\\ChatFrameBackground",
                "Interface\\Tooltips\\UI-Tooltip-Border",
                true,
                12,
                12,
                { left = 3, right = 3, top = 3, bottom = 3 }
            )),
        }),
        background = color(0.008, 0.012, 0.20, 0.98),
        border = color(0.12, 0.86, 1.00, 1),
        panelBackground = color(0.025, 0.055, 0.22, 0.96),
        panelBorder = color(0.28, 0.72, 1.00, 1),
        menuBackground = color(0.008, 0.018, 0.12, 0.99),
        menuBorder = color(0.72, 0.88, 1.00, 1),
        titleText = color(1.00, 0.90, 0.34, 1),
        bodyText = color(0.88, 0.96, 1.00, 1),
        buttonNormal = color(0.05, 0.18, 0.48, 1),
        buttonHighlight = color(0.10, 0.78, 1.00, 1),
        buttonPushed = color(0.025, 0.08, 0.27, 1),
        buttonDisabled = color(0.12, 0.16, 0.25, 1),
        buttonText = color(0.92, 0.98, 1.00, 1),
        buttonDisabledText = color(0.48, 0.58, 0.70, 1),
        buttonHighlightBlend = "ADD",
        buttonHighlightAlpha = 1,
    }),
    winxp = freeze({
        label = "Windows XP",
        backdrops = freeze({
            window = freeze(backdrop(
                "Interface\\Buttons\\WHITE8X8",
                "Interface\\Buttons\\WHITE8X8",
                false,
                1,
                2,
                { left = 5, right = 5, top = 5, bottom = 5 }
            )),
            panel = freeze(backdrop(
                "Interface\\Buttons\\WHITE8X8",
                "Interface\\Buttons\\WHITE8X8",
                false,
                1,
                1,
                { left = 3, right = 3, top = 3, bottom = 3 }
            )),
            menu = freeze(backdrop(
                "Interface\\Buttons\\WHITE8X8",
                "Interface\\Buttons\\WHITE8X8",
                false,
                1,
                1,
                { left = 2, right = 2, top = 2, bottom = 2 }
            )),
        }),
        background = color(0.74, 0.80, 0.90, 0.98),
        border = color(0.10, 0.30, 0.70, 1),
        panelBackground = color(0.86, 0.89, 0.94, 0.98),
        panelBorder = color(0.30, 0.48, 0.78, 1),
        menuBackground = color(0.96, 0.97, 0.99, 0.99),
        menuBorder = color(0.10, 0.30, 0.70, 1),
        titleText = color(0.03, 0.12, 0.35, 1),
        bodyText = color(0.05, 0.07, 0.12, 1),
        buttonNormal = color(0.16, 0.42, 0.82, 1),
        buttonHighlight = color(0.36, 0.66, 0.98, 1),
        buttonPushed = color(0.08, 0.24, 0.60, 1),
        buttonDisabled = color(0.52, 0.56, 0.64, 1),
        buttonText = color(1.00, 1.00, 1.00, 1),
        buttonDisabledText = color(0.70, 0.72, 0.78, 1),
    }),
    borland = freeze({
        label = "Borland C++ IDE",
        backdrops = freeze({
            window = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 2, { left = 3, right = 3, top = 3, bottom = 3 })),
            panel = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 1, { left = 2, right = 2, top = 2, bottom = 2 })),
            menu = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 1, { left = 1, right = 1, top = 1, bottom = 1 })),
        }),
        background = color(0.00, 0.00, 0.72, 0.99),
        border = color(0.00, 1.00, 1.00, 1),
        panelBackground = color(0.01, 0.02, 0.20, 0.98),
        panelBorder = color(0.00, 1.00, 1.00, 1),
        menuBackground = color(0.00, 0.02, 0.32, 0.99),
        menuBorder = color(0.00, 1.00, 1.00, 1),
        titleText = color(0.72, 1.00, 1.00, 1),
        bodyText = color(1.00, 1.00, 1.00, 1),
        buttonNormal = color(0.00, 0.08, 0.62, 1),
        buttonHighlight = color(0.00, 0.88, 1.00, 1),
        buttonPushed = color(0.00, 0.02, 0.30, 1),
        buttonDisabled = color(0.12, 0.18, 0.36, 1),
        buttonText = color(1.00, 1.00, 1.00, 1),
        buttonDisabledText = color(0.45, 0.58, 0.70, 1),
        buttonHighlightBlend = "ADD",
        buttonHighlightAlpha = 1,
    }),
    doscrt = freeze({
        label = "DOS CRT",
        backdrops = freeze({
            window = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 2, { left = 2, right = 2, top = 2, bottom = 2 })),
            panel = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 1, { left = 1, right = 1, top = 1, bottom = 1 })),
            menu = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 1, { left = 1, right = 1, top = 1, bottom = 1 })),
        }),
        background = color(0.00, 0.035, 0.01, 0.98),
        border = color(0.00, 1.00, 0.42, 1),
        panelBackground = color(0.015, 0.10, 0.025, 0.96),
        panelBorder = color(0.00, 0.92, 0.35, 1),
        menuBackground = color(0.00, 0.07, 0.015, 0.99),
        menuBorder = color(0.10, 1.00, 0.50, 1),
        titleText = color(0.15, 1.00, 0.55, 1),
        bodyText = color(0.18, 1.00, 0.48, 1),
        buttonNormal = color(0.00, 0.20, 0.05, 1),
        buttonHighlight = color(0.00, 0.75, 0.28, 1),
        buttonPushed = color(0.00, 0.08, 0.02, 1),
        buttonDisabled = color(0.10, 0.22, 0.14, 1),
        buttonText = color(0.25, 1.00, 0.62, 1),
        buttonDisabledText = color(0.30, 0.55, 0.38, 1),
        buttonHighlightBlend = "ADD",
        buttonHighlightAlpha = 1,
    }),
    aqua = freeze({
        label = "macOS Aqua",
        backdrops = freeze({
            window = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 2, { left = 8, right = 8, top = 8, bottom = 8 })),
            panel = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 2, { left = 8, right = 8, top = 8, bottom = 8 })),
            menu = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 1, { left = 5, right = 5, top = 5, bottom = 5 })),
        }),
        background = color(0.46, 0.54, 0.68, 0.97),
        border = color(0.18, 0.58, 0.96, 1),
        panelBackground = color(0.30, 0.38, 0.52, 0.96),
        panelBorder = color(0.48, 0.66, 0.90, 1),
        menuBackground = color(0.12, 0.18, 0.30, 0.98),
        menuBorder = color(0.24, 0.66, 1.00, 1),
        titleText = color(1.00, 1.00, 1.00, 1),
        bodyText = color(0.92, 0.96, 1.00, 1),
        buttonNormal = color(0.16, 0.36, 0.68, 1),
        buttonHighlight = color(0.20, 0.58, 1.00, 1),
        buttonPushed = color(0.10, 0.24, 0.50, 1),
        buttonDisabled = color(0.32, 0.38, 0.48, 1),
        buttonText = color(1.00, 1.00, 1.00, 1),
        buttonDisabledText = color(0.62, 0.68, 0.76, 1),
        buttonHighlightBlend = "ADD",
        buttonHighlightAlpha = 0.90,
    }),
})

local themeOptions = freeze({
    { value = "eam", label = "EAM" },
    { value = "ff7", label = "FF7" },
    { value = "winxp", label = "Windows XP" },
    { value = "borland", label = "Borland C++ IDE" },
    { value = "doscrt", label = "DOS CRT" },
    { value = "aqua", label = "macOS Aqua" },
})

local api = EAM.API or {}

local Theme = {
    selection = "eam",
    pendingSelection = nil,
    frames = setmetatable({}, { __mode = "k" }),
    texts = setmetatable({}, { __mode = "k" }),
    buttons = setmetatable({}, { __mode = "k" }),
}
EAM.UI.Theme = Theme
EAM.Theme = Theme
Theme.Palettes = palettes
Theme.ThemeOptions = themeOptions

local function getPalette(selection)
    return palettes[selection] or palettes.eam
end

local function setColor(target, methodName, value)
    if target and type(target[methodName]) == "function" and value then
        target[methodName](target, value[1], value[2], value[3], value[4])
        return true
    end
    return false
end

local function copyBackdrop(value)
    return {
        bgFile = value.bgFile,
        edgeFile = value.edgeFile,
        tile = value.tile,
        tileSize = value.tileSize,
        edgeSize = value.edgeSize,
        insets = {
            left = value.insets.left,
            right = value.insets.right,
            top = value.insets.top,
            bottom = value.insets.bottom,
        },
    }
end

function Theme.normalizeSelection(value)
    if palettes[value] then
        return value
    end
    return "eam"
end

function Theme.getSelection()
    return Theme.pendingSelection or Theme.selection
end

function Theme.getOptionLabel(value)
    local normalized = Theme.normalizeSelection(value)
    local palette = palettes[normalized]
    return palette and palette.label or "EAM"
end

function Theme.applyFrame(frame, role)
    if not frame then
        return false
    end
    if type(api.InCombatLockdown) == "function" and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    local palette = getPalette(Theme.selection)
    local selectedRole = role or "window"
    local backdropSet = palette.backdrops[selectedRole] or palette.backdrops.window
    if type(frame.SetBackdrop) == "function" and backdropSet then
        frame:SetBackdrop(copyBackdrop(backdropSet))
    end
    if selectedRole == "panel" then
        setColor(frame, "SetBackdropColor", palette.panelBackground)
        setColor(frame, "SetBackdropBorderColor", palette.panelBorder)
    elseif selectedRole == "menu" then
        setColor(frame, "SetBackdropColor", palette.menuBackground)
        setColor(frame, "SetBackdropBorderColor", palette.menuBorder)
    else
        setColor(frame, "SetBackdropColor", palette.background)
        setColor(frame, "SetBackdropBorderColor", palette.border)
    end
    return true
end

function Theme.applyText(fontString, role)
    if type(api.InCombatLockdown) == "function" and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    local palette = getPalette(Theme.selection)
    local selectedRole = role or "body"
    if selectedRole == "title" then
        return setColor(fontString, "SetTextColor", palette.titleText)
    elseif selectedRole == "button" then
        return setColor(fontString, "SetTextColor", palette.buttonText)
    elseif selectedRole == "buttonDisabled" then
        return setColor(fontString, "SetTextColor", palette.buttonDisabledText)
    end
    return setColor(fontString, "SetTextColor", palette.bodyText)
end

local function setTextureColor(texture, value)
    if texture and type(texture.SetVertexColor) == "function" and value then
        texture:SetVertexColor(value[1], value[2], value[3], value[4])
        return true
    end
    return false
end

local function setTexturePresentation(texture, blendMode, alpha)
    if not texture then
        return
    end
    local function call(methodName, value)
        if value == nil then
            return
        end
        local ok, method = pcall(function()
            return texture[methodName]
        end)
        if ok and type(method) == "function" then
            pcall(method, texture, value)
        end
    end
    call("SetBlendMode", blendMode)
    call("SetAlpha", alpha)
end

local function callButtonMethod(button, methodName)
    local ok, result = pcall(function()
        local method = button[methodName]
        if type(method) ~= "function" then
            return nil
        end
        return method(button)
    end)
    if ok then
        return result
    end
    return nil
end

function Theme.applyButton(button)
    if not button then
        return false
    end
    if type(api.InCombatLockdown) == "function" and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    local palette = getPalette(Theme.selection)
    setTextureColor(callButtonMethod(button, "GetNormalTexture"), palette.buttonNormal)
    setTextureColor(callButtonMethod(button, "GetHighlightTexture"), palette.buttonHighlight)
    setTextureColor(callButtonMethod(button, "GetPushedTexture"), palette.buttonPushed)
    setTextureColor(callButtonMethod(button, "GetDisabledTexture"), palette.buttonDisabled)
    local fontString = callButtonMethod(button, "GetFontString")
    if fontString then
        Theme.applyText(fontString, "button")
    end
    return true
end

function Theme.registerButton(button)
    if not button then
        return false
    end
    Theme.buttons[button] = true
    return Theme.applyButton(button)
end
function Theme.registerFrame(frame, role)
    if not frame then
        return false
    end
    Theme.frames[frame] = role or "window"
    return Theme.applyFrame(frame, role)
end

function Theme.registerText(fontString, role)
    if not fontString then
        return false
    end
    Theme.texts[fontString] = role or "body"
    return Theme.applyText(fontString, role)
end

function Theme.applyAll()
    if type(api.InCombatLockdown) == "function" and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    for frame, role in pairs(Theme.frames) do
        if frame then
            Theme.applyFrame(frame, role)
        end
    end
    for fontString, role in pairs(Theme.texts) do
        if fontString then
            Theme.applyText(fontString, role)
        end
    end
    for button in pairs(Theme.buttons) do
        if button then
            Theme.applyButton(button)
        end
    end
    return true
end
function Theme.setSelection(value)
    local normalized = Theme.normalizeSelection(value)
    if type(api.InCombatLockdown) == "function" and api.InCombatLockdown() then
        Theme.pendingSelection = normalized
        return false, "combatDeferred"
    end
    Theme.pendingSelection = nil
    if Theme.selection == normalized then
        Theme.applyAll()
        return true, "unchanged"
    end
    Theme.selection = normalized
    Theme.applyAll()
    return true, "updated"
end

function Theme.flushPending()
    if not Theme.pendingSelection then
        return false, "none"
    end
    if type(api.InCombatLockdown) == "function" and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    local pending = Theme.pendingSelection
    Theme.pendingSelection = nil
    Theme.selection = pending
    Theme.applyAll()
    return true, "updated"
end
