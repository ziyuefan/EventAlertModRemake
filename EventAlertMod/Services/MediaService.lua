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
    { value = "ShayBell", labelKey = "EAM_OPT_SOUND_SHAYBELL", path = 568154 },
    { value = "FluteRun", labelKey = "EAM_OPT_SOUND_FLUTERUN", path = 569642 },
    { value = "Netherwind", labelKey = "EAM_OPT_SOUND_NETHERWIND", path = 569487 },
    { value = "PolyMorphCow", labelKey = "EAM_OPT_SOUND_COW", path = 568761 },
    { value = "RockBiter", labelKey = "EAM_OPT_SOUND_ROCKBITER", path = 569545 },
    { value = "YarrrrImpact", labelKey = "EAM_OPT_SOUND_YARRRR", path = 568382 },
    { value = "BrokenHeart", labelKey = "EAM_OPT_SOUND_BROKENHEART", path = 568945 },
    { value = "MillhouseReady", labelKey = "EAM_OPT_SOUND_MILLHOUSE_READY", path = 555336 },
    { value = "MillhousePyro", labelKey = "EAM_OPT_SOUND_MILLHOUSE_PYRO", path = 555337 },
    { value = "SatyrePissed", labelKey = "EAM_OPT_SOUND_SATYRE_PISSED", path = 559630 },
    { value = "MortarTeamPissed", labelKey = "EAM_OPT_SOUND_MORTAR_PISSED", path = 555839 },
    { value = "ShaolinFootball", labelKey = "EAM_OPT_SOUND_SHAOLIN", path = "Interface\\AddOns\\EventAlertMod\\Media\\Music\\ShaolinFootball.mp3" },
    -- 舊版相容別名
    { value = "ALARM_1", labelKey = "EAM_OPT_SOUND_ALARM1", path = 568154, aliasOf = "ShayBell" },
    { value = "ALARM_2", labelKey = "EAM_OPT_SOUND_ALARM2", path = 569642, aliasOf = "FluteRun" },
    { value = "BELL", labelKey = "EAM_OPT_SOUND_BELL", path = 568154, aliasOf = "ShayBell" },
    { value = "DRUM", labelKey = "EAM_OPT_SOUND_DRUM", path = 569545, aliasOf = "RockBiter" },
    { value = "WHISTLE", labelKey = "EAM_OPT_SOUND_WHISTLE", path = 568382, aliasOf = "YarrrrImpact" },
}

local BUILTIN_STATUSBARS = {
    { value = "DEFAULT", labelKey = "EAM_OPT_BAR_DEFAULT", path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { value = "FLAT", labelKey = "EAM_OPT_BAR_FLAT", path = "Interface\\Buttons\\WHITE8X8" },
    { value = "SMOOTH", labelKey = "EAM_OPT_BAR_SMOOTH", path = "Interface\\AddOns\\EventAlertMod\\Textures\\Smooth" },
}

function MediaService.ensureLSM()
    if MediaService.hasLSM and MediaService.lsm then
        return MediaService.lsm
    end
    if _G.LibStub then
        local ok, lsm = pcall(_G.LibStub, "LibSharedMedia-3.0", true)
        if ok and lsm then
            MediaService.lsm = lsm
            MediaService.hasLSM = true
            MediaService.registerBuiltinsToLSM()
            if not MediaService.registeredCallbacks and lsm.RegisterCallback then
                lsm.RegisterCallback(MediaService, "LibSharedMedia_Registered", "onMediaRegistered")
                lsm.RegisterCallback(MediaService, "LibSharedMedia_SetGlobal", "onMediaRegistered")
                MediaService.registeredCallbacks = true
            end
            return lsm
        end
    end
    return nil
end

function MediaService.clearCache(mediaType)
    if mediaType then
        MediaService.cache[mediaType] = nil
    else
        MediaService.cache.font = nil
        MediaService.cache.sound = nil
        MediaService.cache.statusbar = nil
    end
end

function MediaService.init()
    MediaService.ensureLSM()
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router and router.register then
        router.register("PLAYER_LOGIN", function()
            MediaService.ensureLSM()
            MediaService.clearCache()
        end)
    end
end

function MediaService.onMediaRegistered(selfOrEvent, eventOrMediaType, mediaTypeOrKey, key)
    local mType = nil
    if type(selfOrEvent) == "string" and (selfOrEvent == "LibSharedMedia_Registered" or selfOrEvent == "LibSharedMedia_SetGlobal") then
        mType = eventOrMediaType
    elseif type(eventOrMediaType) == "string" and (eventOrMediaType == "LibSharedMedia_Registered" or eventOrMediaType == "LibSharedMedia_SetGlobal") then
        mType = mediaTypeOrKey
    end

    if mType and MediaService.cache[mType] then
        MediaService.cache[mType] = nil
    else
        MediaService.clearCache()
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
        if item.path and not item.aliasOf then
            pcall(lsm.Register, lsm, "sound", "EAM " .. item.value, item.path)
        end
    end
    for _, item in ipairs(BUILTIN_STATUSBARS) do
        if item.path then
            pcall(lsm.Register, lsm, "statusbar", "EAM " .. item.value, item.path)
        end
    end
end

function MediaService.getMediaList(mediaType, forceRefresh)
    mediaType = mediaType or "font"
    MediaService.ensureLSM()

    if not forceRefresh and MediaService.cache[mediaType] then
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
        if not item.aliasOf and not seen[item.value] then
            local label = EAM.L and EAM.L[item.labelKey] or item.value
            list[#list + 1] = {
                value = item.value,
                text = label,
                path = item.path,
                isBuiltin = true,
            }
            seen[item.value] = true
        end
    end

    local lsm = MediaService.lsm
    if lsm then
        if lsm.List then
            local ok, lsmKeys = pcall(lsm.List, lsm, mediaType)
            if ok and type(lsmKeys) == "table" then
                for _, key in ipairs(lsmKeys) do
                    if not seen[key] then
                        local path = lsm.Fetch and lsm:Fetch(mediaType, key, true)
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
        if lsm.HashTable then
            local okHash, lsmHash = pcall(lsm.HashTable, lsm, mediaType)
            if okHash and type(lsmHash) == "table" then
                for key, path in pairs(lsmHash) do
                    if not seen[key] then
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
    end

    MediaService.cache[mediaType] = list
    return list
end

function MediaService.isValidMedia(mediaType, key)
    if not key or key == "" then
        return false
    end
    if key == "NONE" and mediaType == "sound" then
        return true
    end
    MediaService.ensureLSM()
    if MediaService.hasLSM and MediaService.lsm and MediaService.lsm.IsValid then
        local ok, valid = pcall(MediaService.lsm.IsValid, MediaService.lsm, mediaType, key)
        if ok and valid then
            return true
        end
    end

    local builtins = BUILTIN_FONTS
    if mediaType == "sound" then
        builtins = BUILTIN_SOUNDS
    elseif mediaType == "statusbar" then
        builtins = BUILTIN_STATUSBARS
    end

    for _, item in ipairs(builtins) do
        if item.value == key or (item.aliasOf and item.aliasOf == key) then
            return true
        end
    end

    return false
end

function MediaService.fetchMedia(mediaType, key, fallback)
    if not key or key == "" or key == "NONE" then
        return fallback
    end

    MediaService.ensureLSM()
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
        if item.value == key or (item.aliasOf and item.aliasOf == key) then
            if item.path == "STANDARD" then
                return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
            end
            return item.path or fallback
        end
    end

    -- 若 key 本身即為數字 FileDataID 或字串檔案路徑
    if type(key) == "number" or (type(key) == "string" and (key:find("\\") or key:find("/"))) then
        return key
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

function MediaService.playSound(soundName, channel)
    channel = channel or "Master"
    if not soundName or soundName == "" or soundName == "NONE" then
        return false
    end
    MediaService.ensureLSM()
    local asset = MediaService.getSoundPath(soundName)
    if not asset then
        return false
    end
    if type(asset) == "number" then
        if _G.PlaySoundFile then
            local ok, handle = pcall(_G.PlaySoundFile, asset, channel)
            if ok and handle then return true end
        end
        if _G.PlaySound then
            local ok, handle = pcall(_G.PlaySound, asset, channel)
            if ok and handle then return true end
        end
    elseif type(asset) == "string" then
        if _G.PlaySoundFile then
            local ok, handle = pcall(_G.PlaySoundFile, asset, channel)
            if ok and handle then return true end
        end
        if _G.PlaySound then
            pcall(_G.PlaySound, asset, channel)
            return true
        end
    end
    return false
end

-- 模組載入時立即嘗試連接 LSM
pcall(MediaService.init)
