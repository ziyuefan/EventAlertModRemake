--[[
EventAlertMod Retail Rewrite
Module: UI/Theme
檔案: UI\Theme.lua

理念:
- 將 EAM 自有視窗的色彩、背景與邊框集中管理，讓主題切換不散落在各 UI 模組。
- 提供 EAM、FF7、Windows XP、Windows 7、Windows 10、Windows 3.1、Borland、DOS CRT、倚天中文、Red Alert 與 macOS Aqua 十一個低風險 palette；不替換 Blizzard secure/protected widget。

責任:
- 保存靜態主題選項與目前選擇。
- 對已註冊的 EAM 視窗與文字區域套用背景、邊框與文字色彩。

邊界:
- 不讀取 aura、cooldown、UnitPower 或任何 Secret Value。
- 不修改 SavedVariables；持久化由 Core/SavedVariables.lua 管理。
- 不在戰鬥中建立 frame 或修改 Blizzard secure frame。

正式服 API 注意:
- 只使用一般 Frame backdrop 與 FontString 色彩 setter；12.0.7／12.1 均可降級至現有內建素材。
- 所有選配主題都是 EAM 自有視覺 palette，不代表 Blizzard、Microsoft、Apple、Borland、倚天或 Red Alert 權利人的官方素材或授權。
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

local flatBackdrops = freeze({
    window = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 2, { left = 5, right = 5, top = 5, bottom = 5 })),
    panel = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 1, { left = 3, right = 3, top = 3, bottom = 3 })),
    menu = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 1, { left = 2, right = 2, top = 2, bottom = 2 })),
})

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
        background = color(0.08, 0.06, 0.05, 0.95),
        border = color(0.82, 0.65, 0.35, 1),
        panelBackground = color(0.05, 0.04, 0.03, 0.88),
        panelBorder = color(0.50, 0.38, 0.22, 0.90),
        menuBackground = color(0.05, 0.04, 0.03, 0.98),
        menuBorder = color(0.65, 0.48, 0.25, 1),
        titleText = color(1.00, 0.82, 0.00, 1),
        bodyText = color(0.95, 0.95, 0.90, 1),
        buttonNormal = color(0.68, 0.10, 0.08, 1),
        buttonHighlight = color(0.95, 0.22, 0.10, 1),
        buttonPushed = color(0.38, 0.05, 0.04, 1),
        buttonDisabled = color(0.24, 0.16, 0.16, 1),
        buttonBorder = color(0.60, 0.46, 0.25, 1),
        buttonText = color(1.00, 0.98, 0.92, 1),
        buttonDisabledText = color(0.55, 0.55, 0.55, 1),
    }),
    ff7 = freeze({
        label = "FF7",
        backdrops = freeze({
            window = freeze(backdrop(
                "Interface\\ChatFrame\\ChatFrameBackground",
                "Interface\\Tooltips\\UI-Tooltip-Border",
                true,
                16,
                16,
                { left = 6, right = 6, top = 6, bottom = 6 }
            )),
            panel = freeze(backdrop(
                "Interface\\ChatFrame\\ChatFrameBackground",
                "Interface\\Tooltips\\UI-Tooltip-Border",
                true,
                12,
                12,
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
        background = color(0.00, 0.02, 0.18, 0.98),
        border = color(1.00, 1.00, 1.00, 1),
        panelBackground = color(0.00, 0.02, 0.16, 0.96),
        panelBorder = color(1.00, 1.00, 1.00, 1),
        menuBackground = color(0.00, 0.01, 0.12, 0.99),
        menuBorder = color(1.00, 1.00, 1.00, 1),
        gradient = freeze({
            orientation = "VERTICAL",
            top = color(0.00, 0.12, 0.85, 0.98),
            bottom = color(0.00, 0.01, 0.10, 0.98),
        }),
        titleText = color(1.00, 0.92, 0.40, 1),
        bodyText = color(1.00, 1.00, 1.00, 1),
        buttonNormal = color(0.04, 0.14, 0.44, 0.92),
        buttonHighlight = color(0.15, 0.65, 1.00, 1),
        buttonPushed = color(0.02, 0.06, 0.22, 1),
        buttonDisabled = color(0.12, 0.16, 0.25, 1),
        buttonBorder = color(1.00, 1.00, 1.00, 1),
        buttonText = color(1.00, 1.00, 1.00, 1),
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
                3,
                { left = 5, right = 5, top = 5, bottom = 5 }
            )),
            panel = freeze(backdrop(
                "Interface\\Buttons\\WHITE8X8",
                "Interface\\Buttons\\WHITE8X8",
                false,
                1,
                2,
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
        background = color(0.92, 0.91, 0.86, 0.98),
        border = color(0.00, 0.33, 0.88, 1),
        panelBackground = color(0.96, 0.95, 0.92, 0.98),
        panelBorder = color(0.00, 0.33, 0.88, 1),
        menuBackground = color(0.98, 0.98, 0.98, 0.99),
        menuBorder = color(0.00, 0.33, 0.88, 1),
        titleText = color(0.00, 0.22, 0.65, 1),
        bodyText = color(0.05, 0.05, 0.08, 1),
        buttonNormal = color(0.88, 0.92, 0.96, 1),
        buttonHighlight = color(0.75, 0.88, 1.00, 1),
        buttonPushed = color(0.78, 0.82, 0.88, 1),
        buttonDisabled = color(0.52, 0.56, 0.64, 1),
        buttonBorder = color(0.00, 0.24, 0.45, 1),
        buttonText = color(0.00, 0.00, 0.00, 1),
        buttonDisabledText = color(0.50, 0.50, 0.50, 1),
    }),
    win7 = freeze({
        label = "Windows 7",
        backdrops = flatBackdrops,
        background = color(0.08, 0.22, 0.42, 0.80),
        border = color(0.55, 0.85, 1.00, 0.90),
        panelBackground = color(0.12, 0.28, 0.48, 0.85),
        panelBorder = color(0.55, 0.85, 1.00, 0.90),
        menuBackground = color(0.08, 0.20, 0.34, 0.95),
        menuBorder = color(0.64, 0.88, 1.00, 1),
        gradient = freeze({
            orientation = "VERTICAL",
            top = color(0.18, 0.42, 0.70, 0.85),
            bottom = color(0.06, 0.16, 0.32, 0.85),
        }),
        titleText = color(1.00, 1.00, 1.00, 1),
        bodyText = color(0.94, 0.97, 1.00, 1),
        buttonNormal = color(0.12, 0.35, 0.62, 0.85),
        buttonHighlight = color(0.25, 0.65, 0.95, 0.95),
        buttonPushed = color(0.08, 0.22, 0.45, 0.90),
        buttonDisabled = color(0.30, 0.38, 0.48, 1),
        buttonBorder = color(0.50, 0.80, 1.00, 0.90),
        buttonText = color(1.00, 1.00, 1.00, 1),
        buttonDisabledText = color(0.62, 0.70, 0.78, 1),
        buttonHighlightBlend = "ADD",
        buttonHighlightAlpha = 0.85,
    }),
    win10 = freeze({
        label = "Windows 10",
        backdrops = flatBackdrops,
        background = color(0.12, 0.12, 0.12, 0.98),
        border = color(0.00, 0.47, 0.84, 1),
        panelBackground = color(0.16, 0.16, 0.16, 0.98),
        panelBorder = color(0.00, 0.47, 0.84, 1),
        menuBackground = color(0.14, 0.14, 0.14, 0.99),
        menuBorder = color(0.00, 0.55, 0.95, 1),
        titleText = color(0.00, 0.55, 0.95, 1),
        bodyText = color(0.94, 0.95, 0.96, 1),
        buttonNormal = color(0.20, 0.20, 0.20, 1),
        buttonHighlight = color(0.00, 0.47, 0.84, 1),
        buttonPushed = color(0.00, 0.35, 0.62, 1),
        buttonDisabled = color(0.24, 0.25, 0.27, 1),
        buttonBorder = color(0.00, 0.47, 0.84, 1),
        buttonText = color(1.00, 1.00, 1.00, 1),
        buttonDisabledText = color(0.58, 0.60, 0.62, 1),
    }),
    win31 = freeze({
        label = "Windows 3.1",
        backdrops = flatBackdrops,
        background = color(0.75, 0.75, 0.75, 1.0),
        border = color(0.00, 0.00, 0.00, 1),
        panelBackground = color(0.75, 0.75, 0.75, 1.0),
        panelBorder = color(0.00, 0.00, 0.00, 1),
        menuBackground = color(0.85, 0.85, 0.85, 1.0),
        menuBorder = color(0.00, 0.00, 0.00, 1),
        titleText = color(0.00, 0.00, 0.50, 1),
        bodyText = color(0.00, 0.00, 0.00, 1),
        buttonNormal = color(0.75, 0.75, 0.75, 1),
        buttonHighlight = color(0.85, 0.85, 0.85, 1),
        buttonPushed = color(0.60, 0.60, 0.60, 1),
        buttonDisabled = color(0.50, 0.50, 0.50, 1),
        buttonBorder = color(0.00, 0.00, 0.00, 1),
        buttonText = color(0.00, 0.00, 0.00, 1),
        buttonDisabledText = color(0.45, 0.45, 0.45, 1),
    }),
    borland = freeze({
        label = "Borland C++ IDE",
        backdrops = freeze({
            window = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 2, { left = 3, right = 3, top = 3, bottom = 3 })),
            panel = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 1, { left = 2, right = 2, top = 2, bottom = 2 })),
            menu = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 1, { left = 1, right = 1, top = 1, bottom = 1 })),
        }),
        background = color(0.00, 0.00, 0.66, 1.0),
        border = color(0.00, 0.85, 0.85, 1),
        panelBackground = color(0.00, 0.00, 0.55, 1.0),
        panelBorder = color(0.00, 0.85, 0.85, 1),
        menuBackground = color(0.00, 0.00, 0.45, 1.0),
        menuBorder = color(0.00, 0.85, 0.85, 1),
        titleText = color(1.00, 1.00, 0.33, 1),
        bodyText = color(1.00, 1.00, 1.00, 1),
        buttonNormal = color(0.00, 0.55, 0.55, 1),
        buttonHighlight = color(0.00, 0.85, 0.85, 1),
        buttonPushed = color(0.00, 0.35, 0.35, 1),
        buttonDisabled = color(0.12, 0.12, 0.36, 1),
        buttonBorder = color(0.00, 0.85, 0.85, 1),
        buttonText = color(1.00, 1.00, 0.33, 1),
        buttonDisabledText = color(0.58, 0.58, 0.18, 1),
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
        background = color(0.00, 0.01, 0.00, 0.99),
        border = color(0.20, 1.00, 0.20, 1),
        panelBackground = color(0.00, 0.02, 0.00, 0.99),
        panelBorder = color(0.15, 0.85, 0.15, 1),
        menuBackground = color(0.00, 0.01, 0.00, 0.99),
        menuBorder = color(0.20, 1.00, 0.20, 1),
        titleText = color(0.20, 1.00, 0.20, 1),
        bodyText = color(0.20, 1.00, 0.20, 1),
        buttonNormal = color(0.00, 0.12, 0.02, 1),
        buttonHighlight = color(0.05, 0.45, 0.10, 1),
        buttonPushed = color(0.00, 0.06, 0.01, 1),
        buttonDisabled = color(0.04, 0.10, 0.05, 1),
        buttonBorder = color(0.20, 1.00, 0.20, 1),
        buttonText = color(0.20, 1.00, 0.20, 1),
        buttonDisabledText = color(0.10, 0.50, 0.10, 1),
        buttonHighlightBlend = "ADD",
        buttonHighlightAlpha = 1,
    }),
    eten = freeze({
        label = "倚天中文",
        backdrops = flatBackdrops,
        background = color(0.00, 0.00, 0.50, 1.0),
        border = color(0.00, 1.00, 1.00, 1),
        panelBackground = color(0.00, 0.00, 0.38, 1.0),
        panelBorder = color(0.00, 1.00, 1.00, 1),
        menuBackground = color(0.00, 0.00, 0.25, 1.0),
        menuBorder = color(1.00, 1.00, 0.00, 1),
        titleText = color(1.00, 1.00, 0.00, 1),
        bodyText = color(1.00, 1.00, 1.00, 1),
        buttonNormal = color(0.00, 0.00, 0.65, 1),
        buttonHighlight = color(0.00, 0.60, 0.80, 1),
        buttonPushed = color(0.00, 0.00, 0.35, 1),
        buttonDisabled = color(0.18, 0.18, 0.30, 1),
        buttonBorder = color(0.00, 1.00, 1.00, 1),
        buttonText = color(1.00, 1.00, 0.00, 1),
        buttonDisabledText = color(0.60, 0.60, 0.40, 1),
    }),
    redalert = freeze({
        label = "Red Alert",
        backdrops = flatBackdrops,
        background = color(0.08, 0.07, 0.07, 0.98),
        border = color(0.85, 0.10, 0.06, 1),
        panelBackground = color(0.12, 0.08, 0.08, 0.98),
        panelBorder = color(0.85, 0.10, 0.06, 1),
        menuBackground = color(0.06, 0.03, 0.03, 0.99),
        menuBorder = color(0.85, 0.10, 0.06, 1),
        titleText = color(1.00, 0.78, 0.15, 1),
        bodyText = color(0.92, 0.82, 0.65, 1),
        buttonNormal = color(0.35, 0.05, 0.03, 1),
        buttonHighlight = color(0.85, 0.12, 0.05, 1),
        buttonPushed = color(0.18, 0.02, 0.01, 1),
        buttonDisabled = color(0.20, 0.16, 0.14, 1),
        buttonBorder = color(0.85, 0.10, 0.06, 1),
        buttonText = color(1.00, 0.85, 0.20, 1),
        buttonDisabledText = color(0.48, 0.42, 0.34, 1),
    }),
    aqua = freeze({
        label = "macOS Aqua",
        backdrops = freeze({
            window = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 2, { left = 8, right = 8, top = 8, bottom = 8 })),
            panel = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 2, { left = 8, right = 8, top = 8, bottom = 8 })),
            menu = freeze(backdrop("Interface\\Buttons\\WHITE8X8", "Interface\\Buttons\\WHITE8X8", false, 1, 1, { left = 5, right = 5, top = 5, bottom = 5 })),
        }),
        background = color(0.86, 0.88, 0.91, 0.96),
        border = color(0.20, 0.55, 0.92, 1),
        panelBackground = color(0.80, 0.84, 0.88, 0.96),
        panelBorder = color(0.20, 0.55, 0.92, 1),
        menuBackground = color(0.88, 0.90, 0.94, 0.98),
        menuBorder = color(0.20, 0.55, 0.92, 1),
        gradient = freeze({
            orientation = "VERTICAL",
            top = color(0.90, 0.92, 0.95, 0.96),
            bottom = color(0.72, 0.76, 0.82, 0.96),
        }),
        titleText = color(0.10, 0.10, 0.15, 1),
        bodyText = color(0.15, 0.15, 0.20, 1),
        buttonNormal = color(0.20, 0.55, 0.92, 0.95),
        buttonHighlight = color(0.35, 0.70, 1.00, 1),
        buttonPushed = color(0.12, 0.38, 0.72, 1),
        buttonDisabled = color(0.55, 0.60, 0.68, 1),
        buttonBorder = color(0.15, 0.45, 0.80, 1),
        buttonText = color(1.00, 1.00, 1.00, 1),
        buttonDisabledText = color(0.62, 0.68, 0.76, 1),
        buttonHighlightBlend = "ADD",
        buttonHighlightAlpha = 0.90,
    }),
})

local themeOptions = freeze({
    { value = "eam", label = "EAM", labelKey = "EAM_THEME_EAM" },
    { value = "ff7", label = "FF7", labelKey = "EAM_THEME_FF7" },
    { value = "winxp", label = "Windows XP", labelKey = "EAM_THEME_WINXP" },
    { value = "win7", label = "Windows 7", labelKey = "EAM_THEME_WIN7" },
    { value = "win10", label = "Windows 10", labelKey = "EAM_THEME_WIN10" },
    { value = "win31", label = "Windows 3.1", labelKey = "EAM_THEME_WIN31" },
    { value = "borland", label = "Borland C++ IDE", labelKey = "EAM_THEME_BORLAND" },
    { value = "doscrt", label = "DOS CRT", labelKey = "EAM_THEME_DOSCRT" },
    { value = "eten", label = "倚天中文", labelKey = "EAM_THEME_ETEN" },
    { value = "redalert", label = "Red Alert", labelKey = "EAM_THEME_REDALERT" },
    { value = "aqua", label = "macOS Aqua", labelKey = "EAM_THEME_AQUA" },
})

local api = EAM.API or {}
local BUTTON_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local BUTTON_BORDER_SIZE = 2

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
    for index = 1, #themeOptions do
        local option = themeOptions[index]
        if option.value == normalized then
            return (EAM.L and option.labelKey and EAM.L[option.labelKey]) or option.label
        end
    end
    return "EAM"
end

local frameGradients = setmetatable({}, { __mode = "k" })

local function applyGradient(frame, role, gradientSpec)
    if not frame or type(frame.CreateTexture) ~= "function" then
        return
    end
    local bg = frameGradients[frame]
    if not bg then
        local ok, tex = pcall(frame.CreateTexture, frame, nil, "BACKGROUND", nil, 1)
        if not ok or not tex then
            ok, tex = pcall(frame.CreateTexture, frame, nil, "BACKGROUND")
        end
        if ok and tex then
            bg = tex
            frameGradients[frame] = bg
        end
    end
    if not bg then
        return
    end
    local insets = (role == "window" and 2) or (role == "panel" and 2) or 1
    if bg.ClearAllPoints then bg:ClearAllPoints() end
    if bg.SetPoint then
        bg:SetPoint("TOPLEFT", frame, "TOPLEFT", insets, -insets)
        bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -insets, insets)
    end
    if bg.SetDrawLayer then
        pcall(bg.SetDrawLayer, bg, "BACKGROUND", 1)
    end
    if bg.SetTexture then
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    end

    local top = gradientSpec.top or { 0.00, 0.12, 0.85, 0.98 }
    local bottom = gradientSpec.bottom or { 0.00, 0.01, 0.10, 0.98 }

    local cMin, cMax
    if _G.CreateColor then
        cMin = _G.CreateColor(bottom[1], bottom[2], bottom[3], bottom[4])
        cMax = _G.CreateColor(top[1], top[2], top[3], top[4])
    else
        cMin = { r = bottom[1], g = bottom[2], b = bottom[3], a = bottom[4], GetRGBA = function() return bottom[1], bottom[2], bottom[3], bottom[4] end }
        cMax = { r = top[1], g = top[2], b = top[3], a = top[4], GetRGBA = function() return top[1], top[2], top[3], top[4] end }
    end

    if bg.SetGradient then
        pcall(bg.SetGradient, bg, "VERTICAL", cMin, cMax)
    elseif bg.SetGradientAlpha then
        pcall(bg.SetGradientAlpha, bg, "VERTICAL", bottom[1], bottom[2], bottom[3], bottom[4], top[1], top[2], top[3], top[4])
    end
    if bg.Show then bg:Show() end
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
    if selectedRole == "row" then
        if type(frame.SetBackdrop) == "function" then
            frame:SetBackdrop(copyBackdrop(palette.backdrops.menu or palette.backdrops.panel))
        end
        local existingBg = frameGradients[frame]
        if existingBg and existingBg.Hide then
            existingBg:Hide()
        end
        setColor(frame, "SetBackdropColor", { 0.04, 0.04, 0.06, 0.35 })
        setColor(frame, "SetBackdropBorderColor", { 0.35, 0.35, 0.40, 0.50 })
        return true
    end
    local backdropSet = palette.backdrops[selectedRole] or palette.backdrops.window
    if type(frame.SetBackdrop) == "function" and backdropSet then
        frame:SetBackdrop(copyBackdrop(backdropSet))
    end
    if palette.gradient and (selectedRole == "window" or selectedRole == "panel") then
        applyGradient(frame, selectedRole, palette.gradient)
        if type(frame.SetBackdropColor) == "function" then
            frame:SetBackdropColor(0, 0, 0, 0)
        end
        if selectedRole == "panel" then
            setColor(frame, "SetBackdropBorderColor", palette.panelBorder)
        else
            setColor(frame, "SetBackdropBorderColor", palette.border)
        end
    else
        local existingBg = frameGradients[frame]
        if existingBg and existingBg.Hide then
            existingBg:Hide()
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

local function callButtonSetter(button, methodName, value)
    local ok, method = pcall(function()
        return button[methodName]
    end)
    if not ok or type(method) ~= "function" then
        return false
    end
    return pcall(method, button, value)
end

local function createButtonBorder(button, firstPoint, secondPoint, horizontal)
    local ok, texture = pcall(button.CreateTexture, button, nil, "OVERLAY", nil, 7)
    if not ok or not texture then
        return nil
    end
    local configured = pcall(function()
        texture:SetColorTexture(1, 1, 1, 1)
        texture:SetPoint(firstPoint, button, firstPoint, 0, 0)
        texture:SetPoint(secondPoint, button, secondPoint, 0, 0)
        if horizontal then
            texture:SetHeight(BUTTON_BORDER_SIZE)
        else
            texture:SetWidth(BUTTON_BORDER_SIZE)
        end
    end)
    return configured and texture or nil
end

local function ensureButtonChrome(button)
    local ok, chrome = pcall(function()
        return button.eamThemeChrome
    end)
    if ok and chrome then
        return chrome
    end

    callButtonSetter(button, "SetNormalTexture", BUTTON_TEXTURE)
    callButtonSetter(button, "SetPushedTexture", BUTTON_TEXTURE)
    callButtonSetter(button, "SetDisabledTexture", BUTTON_TEXTURE)
    callButtonSetter(button, "SetHighlightTexture", BUTTON_TEXTURE)

    local borders = {
        createButtonBorder(button, "TOPLEFT", "TOPRIGHT", true),
        createButtonBorder(button, "BOTTOMLEFT", "BOTTOMRIGHT", true),
        createButtonBorder(button, "TOPLEFT", "BOTTOMLEFT", false),
        createButtonBorder(button, "TOPRIGHT", "BOTTOMRIGHT", false),
    }
    chrome = { borders = borders }
    pcall(function()
        button.eamThemeChrome = chrome
    end)
    return chrome
end

function Theme.applyButton(button)
    if not button then
        return false
    end
    if type(api.InCombatLockdown) == "function" and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    local palette = getPalette(Theme.selection)
    local chrome = ensureButtonChrome(button)
    local highlightTexture = callButtonMethod(button, "GetHighlightTexture")
    setTextureColor(callButtonMethod(button, "GetNormalTexture"), palette.buttonNormal)
    setTextureColor(highlightTexture, palette.buttonHighlight)
    setTexturePresentation(
        highlightTexture,
        palette.buttonHighlightBlend or "BLEND",
        palette.buttonHighlightAlpha or 1
    )
    setTextureColor(callButtonMethod(button, "GetPushedTexture"), palette.buttonPushed)
    setTextureColor(callButtonMethod(button, "GetDisabledTexture"), palette.buttonDisabled)
    local borderColor = palette.buttonBorder or palette.border
    local borders = chrome and chrome.borders or nil
    if borders then
        for index = 1, #borders do
            setTextureColor(borders[index], borderColor)
        end
    end
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

function Theme.applyContainerBackground(frame, roleOrIsPanel)
    if not frame then
        return false
    end
    local role = "window"
    if roleOrIsPanel == true or roleOrIsPanel == "panel" then
        role = "panel"
    elseif roleOrIsPanel == "row" then
        role = "row"
    elseif roleOrIsPanel == "menu" then
        role = "menu"
    elseif type(roleOrIsPanel) == "string" then
        role = roleOrIsPanel
    end
    return Theme.registerFrame(frame, role)
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
