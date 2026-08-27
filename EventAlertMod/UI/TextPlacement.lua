--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/TextPlacement
檔案: UI\TextPlacement.lua

理念:
- 倒數與 applications 共用單一白名單錨點契約，確保 12.0.7 與 12.1 顯示一致。
- JSON 事實來源為 Data/TextPlacementContract.json；本檔是 WoW 執行期的靜態 Lua 映射。

責任:
- 驗證 placement ID、解析 SavedVariables 設定、套用固定 SetPoint 與字級範圍。

邊界:
- 不讀取倒數或 applications 文字，不查 AuraData，不接受任意 SetPoint 字串。
- 只操作 EAM 自己建立的 FontString；Native 路徑僅能在 initializeFrame 期間呼叫。
]]
local _, EAM = ...

local freeze = EAM.Util and EAM.Util.tableFreeze or function(value)
    return value
end

local function anchor(point, relativePoint, x, y)
    return freeze({ point, relativePoint, x, y })
end

local placements = freeze({
    INSIDE_CENTER = anchor("CENTER", "CENTER", 0, 0),
    INSIDE_TOP = anchor("TOP", "TOP", 0, -2),
    INSIDE_TOP_RIGHT = anchor("TOPRIGHT", "TOPRIGHT", -2, -2),
    INSIDE_RIGHT = anchor("RIGHT", "RIGHT", -2, 0),
    INSIDE_BOTTOM_RIGHT = anchor("BOTTOMRIGHT", "BOTTOMRIGHT", -2, 2),
    INSIDE_BOTTOM = anchor("BOTTOM", "BOTTOM", 0, 2),
    INSIDE_BOTTOM_LEFT = anchor("BOTTOMLEFT", "BOTTOMLEFT", 2, 2),
    INSIDE_LEFT = anchor("LEFT", "LEFT", 2, 0),
    INSIDE_TOP_LEFT = anchor("TOPLEFT", "TOPLEFT", 2, -2),
    OUTSIDE_TOP_AT_LEFT = anchor("BOTTOMLEFT", "TOPLEFT", 0, 2),
    OUTSIDE_LEFT_AT_TOP = anchor("TOPRIGHT", "TOPLEFT", -4, 0),
    OUTSIDE_TOP = anchor("BOTTOM", "TOP", 0, 2),
    OUTSIDE_TOP_AT_RIGHT = anchor("BOTTOMRIGHT", "TOPRIGHT", 0, 2),
    OUTSIDE_RIGHT_AT_TOP = anchor("TOPLEFT", "TOPRIGHT", 4, 0),
    OUTSIDE_RIGHT = anchor("LEFT", "RIGHT", 4, 0),
    OUTSIDE_RIGHT_AT_BOTTOM = anchor("BOTTOMLEFT", "BOTTOMRIGHT", 4, 0),
    OUTSIDE_BOTTOM_AT_RIGHT = anchor("TOPRIGHT", "BOTTOMRIGHT", 0, -2),
    OUTSIDE_BOTTOM = anchor("TOP", "BOTTOM", 0, -2),
    OUTSIDE_BOTTOM_AT_LEFT = anchor("TOPLEFT", "BOTTOMLEFT", 0, -2),
    OUTSIDE_LEFT_AT_BOTTOM = anchor("BOTTOMRIGHT", "BOTTOMLEFT", -4, 0),
    OUTSIDE_LEFT = anchor("RIGHT", "LEFT", -4, 0),
})

local orderedPlacements = freeze({
    "INSIDE_CENTER",
    "INSIDE_TOP",
    "INSIDE_TOP_RIGHT",
    "INSIDE_RIGHT",
    "INSIDE_BOTTOM_RIGHT",
    "INSIDE_BOTTOM",
    "INSIDE_BOTTOM_LEFT",
    "INSIDE_LEFT",
    "INSIDE_TOP_LEFT",
    "OUTSIDE_TOP_AT_LEFT",
    "OUTSIDE_LEFT_AT_TOP",
    "OUTSIDE_TOP",
    "OUTSIDE_TOP_AT_RIGHT",
    "OUTSIDE_RIGHT_AT_TOP",
    "OUTSIDE_RIGHT",
    "OUTSIDE_RIGHT_AT_BOTTOM",
    "OUTSIDE_BOTTOM_AT_RIGHT",
    "OUTSIDE_BOTTOM",
    "OUTSIDE_BOTTOM_AT_LEFT",
    "OUTSIDE_LEFT_AT_BOTTOM",
    "OUTSIDE_LEFT",
})

local TextPlacement = {
    placements = placements,
    orderedPlacements = orderedPlacements,
}

EAM.UI = EAM.UI or {}
EAM.UI.TextPlacement = TextPlacement

local function fallbackFor(kind)
    if kind == "applications" then
        return EAM.Constants.TEXT_PLACEMENT_APPLICATIONS_DEFAULT
    end
    return EAM.Constants.TEXT_PLACEMENT_TIMER_DEFAULT
end

function TextPlacement.normalize(placement, fallback)
    if type(placement) == "string" and placements[placement] then
        return placement
    end
    if type(fallback) == "string" and placements[fallback] then
        return fallback
    end
    return nil
end

function TextPlacement.getPlacement(config, kind)
    local textLayout = config and config.textLayout
    local section = textLayout and textLayout[kind]
    return TextPlacement.normalize(section and section.placement, fallbackFor(kind))
end

function TextPlacement.getFontSize(config, kind)
    local fallback = kind == "applications" and 12 or 14
    local textLayout = config and config.textLayout
    local section = textLayout and textLayout[kind]
    local value = section and section.fontSize
    if type(value) ~= "number" then
        value = fallback
    end
    if value < EAM.Constants.TEXT_FONT_SIZE_MIN then
        return EAM.Constants.TEXT_FONT_SIZE_MIN
    elseif value > EAM.Constants.TEXT_FONT_SIZE_MAX then
        return EAM.Constants.TEXT_FONT_SIZE_MAX
    end
    return value
end

function TextPlacement.apply(fontString, relativeFrame, placement)
    local resolved = TextPlacement.normalize(placement)
    local definition = resolved and placements[resolved]
    if not fontString or not relativeFrame or not definition then
        return false
    end
    fontString:ClearAllPoints()
    fontString:SetPoint(definition[1], relativeFrame, definition[2], definition[3], definition[4])
    return true, definition[1], definition[2], definition[3], definition[4]
end

function TextPlacement.normalizeFontFamily(value)
    if type(value) ~= "string" or value == "" then
        return EAM.Constants and EAM.Constants.FONT_FAMILY_DEFAULT or "STANDARD"
    end
    local options = EAM.Constants and EAM.Constants.FONT_FAMILY_OPTIONS or {}
    for index = 1, #options do
        if options[index].value == value then
            return value
        end
    end
    local MediaService = EAM.Services and EAM.Services.MediaService
    if MediaService then
        if MediaService.isValidMedia and MediaService.isValidMedia("font", value) then
            return value
        elseif MediaService.hasLSM then
            return value
        end
    end
    if _G.LibStub then
        local ok, lsm = pcall(_G.LibStub, "LibSharedMedia-3.0", true)
        if ok and lsm and lsm.IsValid and lsm:IsValid("font", value) then
            return value
        end
    end
    return EAM.Constants and EAM.Constants.FONT_FAMILY_DEFAULT or "STANDARD"
end

function TextPlacement.getFontFamily(config)
    local value = type(config) == "table" and config.fontFamily or nil
    if value == nil and EAM.db and EAM.db.config then
        value = EAM.db.config.fontFamily
    end
    return TextPlacement.normalizeFontFamily(value)
end

function TextPlacement.getFontPath(configOrFamily)
    local family
    if type(configOrFamily) == "table" then
        family = TextPlacement.getFontFamily(configOrFamily)
    elseif type(configOrFamily) == "string" then
        family = TextPlacement.normalizeFontFamily(configOrFamily)
    else
        family = TextPlacement.getFontFamily()
    end
    local MediaService = EAM.Services and EAM.Services.MediaService
    if MediaService then
        return MediaService.getFontPath(family, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
    end
    local options = EAM.Constants and EAM.Constants.FONT_FAMILY_OPTIONS or {}
    for index = 1, #options do
        local option = options[index]
        if option.value == family then
            if option.path == "STANDARD" then
                return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
            end
            return option.path
        end
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

function TextPlacement.applyFont(fontString, size, configOrFamily)
    if not fontString then
        return false
    end
    local normalized = tonumber(size)
    if not normalized then
        return false
    end
    if normalized < EAM.Constants.TEXT_FONT_SIZE_MIN then
        normalized = EAM.Constants.TEXT_FONT_SIZE_MIN
    elseif normalized > EAM.Constants.TEXT_FONT_SIZE_MAX then
        normalized = EAM.Constants.TEXT_FONT_SIZE_MAX
    end
    local path = TextPlacement.getFontPath(configOrFamily)
    fontString:SetFont(path, normalized, "OUTLINE")
    return true, normalized, TextPlacement.getFontFamily(configOrFamily)
end
