--[[
Name: LibSharedMedia-3.0
Revision: $Rev: 159 $
Author: Elkano (elkano@gmx.de)
Inspired By: SurfaceLib by Haste/Otravi (troeks@gmail.com)
Website: https://www.wowace.com/projects/libsharedmedia-3-0
Description: Shared handling of media data (fonts, sounds, textures, ...) between addons.
Dependencies: LibStub, CallbackHandler-1.0
License: LGPL v2.1
]]

local MAJOR, MINOR = "LibSharedMedia-3.0", 12000003 -- 12.0.0 v3 / increase manually on changes
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

local _G = getfenv(0)

local pairs		= _G.pairs
local type		= _G.type

local band			= _G.bit and _G.bit.band or function(a, b) return a end
local table_insert	= _G.table.insert
local table_sort	= _G.table.sort

local RESTRICTED_FILE_ACCESS = not not _G.C_VoiceChat -- starting with 8.2, some rules for file access have changed; classic has the new system too

local locale = _G.GetLocale and _G.GetLocale() or "enUS"
local locale_is_western
local LOCALE_MASK = 0
lib.LOCALE_BIT_koKR		= 1
lib.LOCALE_BIT_ruRU		= 2
lib.LOCALE_BIT_zhCN		= 4
lib.LOCALE_BIT_zhTW		= 8
lib.LOCALE_BIT_western	= 128

local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0")

lib.callbacks		= lib.callbacks or CallbackHandler:New(lib)

lib.DefaultMedia	= lib.DefaultMedia or {}
lib.MediaList		= lib.MediaList or {}
lib.MediaTable		= lib.MediaTable or {}
lib.OverrideMedia	= lib.OverrideMedia or {}

local defaultMedia = lib.DefaultMedia
local mediaList = lib.MediaList
local mediaTable = lib.MediaTable
local overrideMedia = lib.OverrideMedia


-- create mediatype constants
lib.MediaType = {
	BACKGROUND	= "background",			-- background textures
	BORDER		= "border",				-- border textures
	FONT		= "font",				-- fonts
	STATUSBAR	= "statusbar",			-- statusbar textures
	SOUND		= "sound",				-- sound files
}

local MediaType = lib.MediaType

-- BACKGROUND
if not mediaTable[MediaType.BACKGROUND] then mediaTable[MediaType.BACKGROUND] = {} end
mediaTable[MediaType.BACKGROUND]["None"]									= [[]]
mediaTable[MediaType.BACKGROUND]["Blizzard Collections Background"]			= [[Interface\Collections\CollectionsBackgroundTile]]
mediaTable[MediaType.BACKGROUND]["Blizzard Dialog Background"]				= [[Interface\DialogFrame\UI-DialogBox-Background]]
mediaTable[MediaType.BACKGROUND]["Blizzard Dialog Background Dark"]			= [[Interface\DialogFrame\UI-DialogBox-Background-Dark]]
mediaTable[MediaType.BACKGROUND]["Blizzard Dialog Background Gold"]			= [[Interface\DialogFrame\UI-DialogBox-Gold-Background]]
mediaTable[MediaType.BACKGROUND]["Blizzard Garrison Background"]			= [[Interface\Garrison\GarrisonUIBackground]]
mediaTable[MediaType.BACKGROUND]["Blizzard Garrison Background 2"]			= [[Interface\Garrison\GarrisonUIBackground2]]
mediaTable[MediaType.BACKGROUND]["Blizzard Garrison Background 3"]			= [[Interface\Garrison\GarrisonMissionUIInfoBoxBackgroundTile]]
mediaTable[MediaType.BACKGROUND]["Blizzard Low Health"]						= [[Interface\FullScreenTextures\LowHealth]]
mediaTable[MediaType.BACKGROUND]["Blizzard Marble"]							= [[Interface\FrameGeneral\UI-Background-Marble]]
mediaTable[MediaType.BACKGROUND]["Blizzard Out of Control"]					= [[Interface\FullScreenTextures\OutOfControl]]
mediaTable[MediaType.BACKGROUND]["Blizzard Parchment"]						= [[Interface\AchievementFrame\UI-Achievement-Parchment-Horizontal]]
mediaTable[MediaType.BACKGROUND]["Blizzard Parchment 2"]					= [[Interface\AchievementFrame\UI-GuildAchievement-Parchment-Horizontal]]
mediaTable[MediaType.BACKGROUND]["Blizzard Rock"]							= [[Interface\FrameGeneral\UI-Background-Rock]]
mediaTable[MediaType.BACKGROUND]["Blizzard Tabard Background"]				= [[Interface\TabardFrame\TabardFrameBackground]]
mediaTable[MediaType.BACKGROUND]["Blizzard Tooltip"]						= [[Interface\Tooltips\UI-Tooltip-Background]]
mediaTable[MediaType.BACKGROUND]["Solid"]									= [[Interface\Buttons\WHITE8X8]]
if not defaultMedia[MediaType.BACKGROUND] then defaultMedia[MediaType.BACKGROUND] = "None" end

-- BORDER
if not mediaTable[MediaType.BORDER] then mediaTable[MediaType.BORDER] = {} end
mediaTable[MediaType.BORDER]["None"]								= [[]]
mediaTable[MediaType.BORDER]["Blizzard Achievement Wood"]			= [[Interface\AchievementFrame\UI-Achievement-WoodBorder]]
mediaTable[MediaType.BORDER]["Blizzard Chat Bubble"]				= [[Interface\Tooltips\ChatBubble-Backdrop]]
mediaTable[MediaType.BORDER]["Blizzard Dialog"]						= [[Interface\DialogFrame\UI-DialogBox-Border]]
mediaTable[MediaType.BORDER]["Blizzard Dialog Gold"]				= [[Interface\DialogFrame\UI-DialogBox-Gold-Border]]
mediaTable[MediaType.BORDER]["Blizzard Party"]						= [[Interface\CharacterFrame\UI-Party-Border]]
mediaTable[MediaType.BORDER]["Blizzard Tooltip"]					= [[Interface\Tooltips\UI-Tooltip-Border]]
if not defaultMedia[MediaType.BORDER] then defaultMedia[MediaType.BORDER] = "None" end

-- FONT
if not mediaTable[MediaType.FONT] then mediaTable[MediaType.FONT] = {} end
local SML_MT_font = mediaTable[MediaType.FONT]
if locale == "koKR" then
	LOCALE_MASK = lib.LOCALE_BIT_koKR
	SML_MT_font["굵은 글꼴"]		= [[Fonts\2002B.TTF]]
	SML_MT_font["기본 글꼴"]		= [[Fonts\2002.TTF]]
	SML_MT_font["데미지 글꼴"]		= [[Fonts\K_Damage.TTF]]
	SML_MT_font["퀘스트 글꼴"]		= [[Fonts\K_Pagetext.TTF]]
	if not defaultMedia[MediaType.FONT] then defaultMedia[MediaType.FONT] = "기본 글꼴" end
elseif locale == "zhCN" then
	LOCALE_MASK = lib.LOCALE_BIT_zhCN
	SML_MT_font["伤害数字"]			= [[Fonts\ARKai_C.ttf]]
	SML_MT_font["默认"]				= [[Fonts\ARKai_T.ttf]]
	SML_MT_font["聊天"]				= [[Fonts\ARHei.ttf]]
	if not defaultMedia[MediaType.FONT] then defaultMedia[MediaType.FONT] = "默认" end
elseif locale == "zhTW" then
	LOCALE_MASK = lib.LOCALE_BIT_zhTW
	SML_MT_font["提示訊息"]			= [[Fonts\bHEI00M.ttf]]
	SML_MT_font["聊天"]				= [[Fonts\bHEI01B.ttf]]
	SML_MT_font["傷害數字"]			= [[Fonts\bKAI00M.ttf]]
	SML_MT_font["預設"]				= [[Fonts\blei00d.TTF]]
	if not defaultMedia[MediaType.FONT] then defaultMedia[MediaType.FONT] = "預設" end
elseif locale == "ruRU" then
	LOCALE_MASK = lib.LOCALE_BIT_ruRU
	SML_MT_font["Arial Narrow"]		= [[Fonts\ARIALN.TTF]]
	SML_MT_font["Friz Quadrata TT"]	= [[Fonts\FRIZQT___CYR.TTF]]
	SML_MT_font["Morpheus"]			= [[Fonts\MORPHEUS_CYR.TTF]]
	SML_MT_font["Nimrod MT"]		= [[Fonts\NIM_____.ttf]]
	SML_MT_font["Skurri"]			= [[Fonts\SKURRI_CYR.TTF]]
	if not defaultMedia[MediaType.FONT] then defaultMedia[MediaType.FONT] = "Friz Quadrata TT" end
else
	LOCALE_MASK = lib.LOCALE_BIT_western
	locale_is_western = true
	SML_MT_font["2002"]				= [[Fonts\2002.TTF]]
	SML_MT_font["2002 Bold"]		= [[Fonts\2002B.TTF]]
	SML_MT_font["AR CrystalzcuheiGBK Demibold"]	= [[Fonts\ARKai_C.ttf]]
	SML_MT_font["AR ZhongkaiGBK Medium (Combat)"] = [[Fonts\ARKai_C.ttf]]
	SML_MT_font["AR ZhongkaiGBK Medium"]		= [[Fonts\ARKai_T.ttf]]
	SML_MT_font["Arial Narrow"]		= [[Fonts\ARIALN.TTF]]
	SML_MT_font["Arheiuhk_bd"]		= [[Fonts\bHEI01B.ttf]]
	SML_MT_font["arheiuhk_bd"]		= [[Fonts\ARHei.ttf]]
	SML_MT_font["bHEI00M"]			= [[Fonts\bHEI00M.ttf]]
	SML_MT_font["bHEI01B"]			= [[Fonts\bHEI01B.ttf]]
	SML_MT_font["bKAI00M"]			= [[Fonts\bKAI00M.ttf]]
	SML_MT_font["blei00d"]			= [[Fonts\blei00d.TTF]]
	SML_MT_font["Friz Quadrata TT"]	= [[Fonts\FRIZQT__.TTF]]
	SML_MT_font["FrizQuadrataCTT"]	= [[Fonts\FRIZQT___CYR.TTF]]
	SML_MT_font["K_Damage"]			= [[Fonts\K_Damage.TTF]]
	SML_MT_font["K_Pagetext"]		= [[Fonts\K_Pagetext.TTF]]
	SML_MT_font["Morpheus"]			= [[Fonts\MORPHEUS.TTF]]
	SML_MT_font["Morpheus_CYR"]		= [[Fonts\MORPHEUS_CYR.TTF]]
	SML_MT_font["Nimrod MT"]		= [[Fonts\NIM_____.ttf]]
	SML_MT_font["Skurri"]			= [[Fonts\SKURRI.TTF]]
	SML_MT_font["Skurri_CYR"]		= [[Fonts\SKURRI_CYR.TTF]]
	if not defaultMedia[MediaType.FONT] then defaultMedia[MediaType.FONT] = "Friz Quadrata TT" end
end

-- STATUSBAR
if not mediaTable[MediaType.STATUSBAR] then mediaTable[MediaType.STATUSBAR] = {} end
mediaTable[MediaType.STATUSBAR]["Blizzard"]						= [[Interface\TargetingFrame\UI-StatusBar]]
mediaTable[MediaType.STATUSBAR]["Blizzard Character Skills Bar"] = [[Interface\PaperDollInfoFrame\UI-Character-Skills-Bar]]
mediaTable[MediaType.STATUSBAR]["Blizzard Raid Bar"]			= [[Interface\RaidFrame\Raid-Bar-Hp-Fill]]
mediaTable[MediaType.STATUSBAR]["Solid"]						= [[Interface\Buttons\WHITE8X8]]
if not defaultMedia[MediaType.STATUSBAR] then defaultMedia[MediaType.STATUSBAR] = "Blizzard" end

-- SOUND
if not mediaTable[MediaType.SOUND] then mediaTable[MediaType.SOUND] = {} end
mediaTable[MediaType.SOUND]["None"]		= RESTRICTED_FILE_ACCESS and 1 or [[Interface\Quiet.ogg]]
if not defaultMedia[MediaType.SOUND] then defaultMedia[MediaType.SOUND] = "None" end

local function rebuildMediaList(mediatype)
	local mtable = mediaTable[mediatype]
	if not mtable then return end
	if not mediaList[mediatype] then mediaList[mediatype] = {} end
	local mlist = mediaList[mediatype]
	-- list can only get larger, so simply overwrite it (names will be sorted anyways)
	local i = 0
	for k in pairs(mtable) do
		i = i + 1
		mlist[i] = k
	end
	table_sort(mlist)
end

function lib:Register(mediatype, key, data, langmask)
	if type(mediatype) ~= "string" then
		error(MAJOR..":Register(mediatype, key, data, langmask) - mediatype must be string, got "..type(mediatype))
	end
	if type(key) ~= "string" then
		error(MAJOR..":Register(mediatype, key, data, langmask) - key must be string, got "..type(key))
	end
	mediatype = mediatype:lower()
	if mediatype == MediaType.FONT and ((langmask and band(langmask, LOCALE_MASK) == 0) or not (langmask or locale_is_western)) then
		-- ignore fonts that aren't flagged as supporting local glyphs on non-western clients
		return false
	end
	if type(data) == "string" and (mediatype == MediaType.BACKGROUND or mediatype == MediaType.BORDER or mediatype == MediaType.STATUSBAR or mediatype == MediaType.SOUND) then
		local path = data:lower()
		if RESTRICTED_FILE_ACCESS and not path:find("^interface") then
			-- files accessed via path only allowed from interface folder
			return false
		end
		if mediatype == MediaType.SOUND and not (path:find(".ogg", nil, true) or path:find(".mp3", nil, true)) then
			--Only ogg and mp3 are valid sounds.
			return false
		end
	end
	if not mediaTable[mediatype] then mediaTable[mediatype] = {} end
	local mtable = mediaTable[mediatype]
	if mtable[key] then return false end

	mtable[key] = data
	rebuildMediaList(mediatype)
	self.callbacks:Fire("LibSharedMedia_Registered", mediatype, key)
	return true
end

function lib:Fetch(mediatype, key, noDefault)
	local mtt = mediaTable[mediatype]
	local overridekey = overrideMedia[mediatype]
	local result = mtt and ((overridekey and mtt[overridekey] or mtt[key]) or (not noDefault and defaultMedia[mediatype] and mtt[defaultMedia[mediatype]])) or nil
	if result == "" then
		result = nil
	end
	return result
end

function lib:IsValid(mediatype, key)
	return mediaTable[mediatype] and (not key or mediaTable[mediatype][key]) and true or false
end

function lib:HashTable(mediatype)
	return mediaTable[mediatype]
end

function lib:List(mediatype)
	if not mediaTable[mediatype] then
		return nil
	end
	if not mediaList[mediatype] then
		rebuildMediaList(mediatype)
	end
	return mediaList[mediatype]
end

function lib:GetGlobal(mediatype)
	return overrideMedia[mediatype]
end

function lib:SetGlobal(mediatype, key)
	if not mediaTable[mediatype] then
		return false
	end
	overrideMedia[mediatype] = (key and mediaTable[mediatype][key]) and key or nil
	self.callbacks:Fire("LibSharedMedia_SetGlobal", mediatype, overrideMedia[mediatype])
	return true
end

function lib:GetDefault(mediatype)
	return defaultMedia[mediatype]
end

function lib:SetDefault(mediatype, key)
	if mediaTable[mediatype] and mediaTable[mediatype][key] and not defaultMedia[mediatype] then
		defaultMedia[mediatype] = key
		return true
	else
		return false
	end
end
