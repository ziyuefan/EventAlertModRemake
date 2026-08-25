--[[ EAM_FILE_COMMENTARY
Module: Services/MediaService
檔案: Services\MediaService.lua

理念:
- 無縫接入社群廣泛使用的 LibSharedMedia-3.0 (LSM)，擴展字型、音效與狀態條材質生態。
- 若環境中未安裝 LSM，100% 零錯誤平滑回退至 EAM 內建資源。

責任:
- 探測並雙向對接 LibSharedMedia-3.0 (font, sound, statusbar)。
- 向 LSM 註冊 EAM 自有字型、音效與材質。
- 提供統一的 getMediaList 與 fetchMedia 查詢介面。

邊界:
- 不讀取任何 Secret Value，不進行任何戰鬥邏輯判斷。
- 查詢結果為唯讀靜態字串或數字。
]]

local _, EAM = ...
local Util = EAM.Util or {}
local Constants = EAM.Constants or {}

local MediaService = {
    lsm = nil,
    hasLSM = false,
    registeredCallbacks = false,
    cache = {
        font = nil,
        sound = nil,
        statusbar = nil,
    },
}

EAM.Services = EAM.Services or {}
EAM.Services.MediaService = MediaService

local BUILTIN_FONTS = {
    { value = "STANDARD", labelKey = "EAM_OPT_FONT_STANDARD", path = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" },
    { value = "ARIALN", labelKey = "EAM_OPT_FONT_ARIALN", path = "Fonts\\ARIALN.TTF" },
    { value = "MORPHEUS", labelKey = "EAM_OPT_FONT_MORPHEUS", path = "Fonts\\MORPHEUS.TTF" },
    { value = "SKURRI", labelKey = "EAM_OPT_FONT_SKURRI", path = "Fonts\\SKURRI.TTF" },
}

local BUILTIN_SOUNDS = {
    { value = "NONE", labelKey = "EAM_OPT_SOUND_NONE", path = nil },
    { value = "ALARM_1", labelKey = "EAM_OPT_SOUND_ALARM1", path = "Sound\\Spells\\ShaysBell.ogg" },
    { value = "ALARM_2", labelKey = "EAM_OPT_SOUND_ALARM2", path = "Sound\\Spells\\PVPFlagCaptured.ogg" },
    { value = "BELL", labelKey = "EAM_OPT_SOUND_BELL", path = "Sound\\Spells\\SimonGame_LargeBlueTree.ogg" },
    { value = "DRUM", labelKey = "EAM_OPT_SOUND_DRUM", path = "Sound\\Spells\\Gong_Small.ogg" },
    { value = "WHISTLE", labelKey = "EAM_OPT_SOUND_WHISTLE", path = "Sound\\Spells\\GoblinLandMineArmed.ogg" },
}

local BUILTIN_STATUSBARS = {
    { value = "DEFAULT", labelKey = "EAM_OPT_BAR_DEFAULT", path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { value = "FLAT", labelKey = "EAM_OPT_BAR_FLAT", path = "Interface\\Buttons\\WHITE8X8" },
    { value = "SMOOTH", labelKey = "EAM_OPT_BAR_SMOOTH", path = "Interface\\AddOns\\EventAlertMod\\Textures\\Smooth" },
}

function MediaService.init()
    if _G.LibStub then
        local ok, lsm = pcall(_G.LibStub, "LibSharedMedia-3.0", true)
        if ok and lsm then
            MediaService.lsm = lsm
            MediaService.hasLSM = true
            MediaService.registerBuiltinsToLSM()
            if not MediaService.registeredCallbacks and lsm.RegisterCallback then
                lsm.RegisterCallback(MediaService, "LibSharedMedia_Registered", "onMediaRegistered")
                MediaService.registeredCallbacks = true
            end
        end
    end
end

function MediaService.onMediaRegistered(event, mediaType, key)
    if mediaType and MediaService.cache[mediaType] then
        MediaService.cache[mediaType] = nil
    end
end

function MediaService.registerBuiltinsToLSM()
    local lsm = MediaService.lsm
    if not lsm or type(lsm.Register) ~= "function" then
        return
    end
    for _, item in ipairs(BUILTIN_FONTS) do
        if item.path and item.path ~= "STANDARD" then
            pcall(lsm.Register, lsm, "font", "EAM " .. item.value, item.path)
        end
    end
    for _, item in ipairs(BUILTIN_SOUNDS) do
        if item.path then
            pcall(lsm.Register, lsm, "sound", "EAM " .. item.value, item.path)
        end
    end
    for _, item in ipairs(BUILTIN_STATUSBARS) do
        if item.path then
            pcall(lsm.Register, lsm, "statusbar", "EAM " .. item.value, item.path)
        end
    end
end

function MediaService.getMediaList(mediaType)
    mediaType = mediaType or "font"
    if MediaService.cache[mediaType] then
        return MediaService.cache[mediaType]
    end

    local list = {}
    local seen = {}

    local builtins = BUILTIN_FONTS
    if mediaType == "sound" then
        builtins = BUILTIN_SOUNDS
    elseif mediaType == "statusbar" then
        builtins = BUILTIN_STATUSBARS
    end

    for _, item in ipairs(builtins) do
        local label = EAM.L and EAM.L[item.labelKey] or item.value
        list[#list + 1] = {
            value = item.value,
            text = label,
            path = item.path,
            isBuiltin = true,
        }
        seen[item.value] = true
    end

    if MediaService.hasLSM and MediaService.lsm and MediaService.lsm.List then
        local ok, lsmKeys = pcall(MediaService.lsm.List, MediaService.lsm, mediaType)
        if ok and type(lsmKeys) == "table" then
            for _, key in ipairs(lsmKeys) do
                if not seen[key] then
                    local path = MediaService.lsm:Fetch(mediaType, key, true)
                    list[#list + 1] = {
                        value = key,
                        text = key,
                        path = path,
                        isLSM = true,
                    }
                    seen[key] = true
                end
            end
        end
    end

    MediaService.cache[mediaType] = list
    return list
end

function MediaService.fetchMedia(mediaType, key, fallback)
    if not key or key == "" or key == "NONE" then
        return fallback
    end

    if MediaService.hasLSM and MediaService.lsm and MediaService.lsm.Fetch then
        local ok, fetched = pcall(MediaService.lsm.Fetch, MediaService.lsm, mediaType, key, true)
        if ok and fetched then
            return fetched
        end
    end

    local builtins = BUILTIN_FONTS
    if mediaType == "sound" then
        builtins = BUILTIN_SOUNDS
    elseif mediaType == "statusbar" then
        builtins = BUILTIN_STATUSBARS
    end

    for _, item in ipairs(builtins) do
        if item.value == key then
            if item.path == "STANDARD" then
                return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
            end
            return item.path or fallback
        end
    end

    return fallback
end

function MediaService.getFontPath(key, fallback)
    return MediaService.fetchMedia("font", key, fallback or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
end

function MediaService.getSoundPath(key, fallback)
    return MediaService.fetchMedia("sound", key, fallback)
end

function MediaService.getStatusBarPath(key, fallback)
    return MediaService.fetchMedia("statusbar", key, fallback or "Interface\\TargetingFrame\\UI-StatusBar")
end
