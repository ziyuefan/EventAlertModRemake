--[[
Name: LibSharedMedia-3.0
Revision: $Rev: 120 $
Author: Elkano (elkano@gmx.de)
Website: http://www.wowace.com/projects/libsharedmedia-3-0/
Description: Shared handling of media data (fonts, sounds, textures, ...) between addons.
Dependencies: LibStub, CallbackHandler-1.0
License: LGPL v2.1
]]

local MAJOR, MINOR = "LibSharedMedia-3.0", 8000
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

local _G = getfenv(0)

local pairs = _G.pairs
local type = _G.type
local table_insert = _G.table.insert
local table_sort = _G.table.sort

local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0")

lib.callbacks = lib.callbacks or CallbackHandler:New(lib)

lib.DefaultMedia = lib.DefaultMedia or {}
lib.MediaList = lib.MediaList or {}
lib.MediaTable = lib.MediaTable or {}
lib.OverrideMedia = lib.OverrideMedia or {}

local defaultMedia = lib.DefaultMedia
local mediaList = lib.MediaList
local mediaTable = lib.MediaTable
local overrideMedia = lib.OverrideMedia

-- Media types
lib.MediaType = {
	BACKGROUND	= "background",
	BORDER		= "border",
	FONT		= "font",
	STATUSBAR	= "statusbar",
	SOUND		= "sound",
}

local MediaType = lib.MediaType

for _, mType in pairs(MediaType) do
	mediaList[mType] = mediaList[mType] or {}
	mediaTable[mType] = mediaTable[mType] or {}
end

function lib:Register(mType, key, data, langmask)
	if type(mType) ~= "string" then
		error(MAJOR .. ":Register(mType, key, data, langmask) - mType must be string, got " .. type(mType))
	end
	if type(key) ~= "string" then
		error(MAJOR .. ":Register(mType, key, data, langmask) - key must be string, got " .. type(key))
	end
	mType = mType:lower()
	if not mediaTable[mType] then
		mediaList[mType] = {}
		mediaTable[mType] = {}
	end
	local mTable = mediaTable[mType]
	local mList = mediaList[mType]

	if not mTable[key] then
		mTable[key] = data
		table_insert(mList, key)
		table_sort(mList)
		self.callbacks:Fire("LibSharedMedia_Registered", mType, key)
		return true
	end
	return false
end

function lib:Fetch(mType, key, noDefault, customDefault)
	mType = mType:lower()
	local mTable = mediaTable[mType]
	if not mTable then return nil end

	local result = overrideMedia[mType] or mTable[key]
	if not result and not noDefault then
		result = customDefault or (defaultMedia[mType] and mTable[defaultMedia[mType]])
	end
	return result
end

function lib:List(mType)
	mType = mType:lower()
	return mediaList[mType] or {}
end

function lib:HashTable(mType)
	mType = mType:lower()
	return mediaTable[mType] or {}
end

function lib:IsValid(mType, key)
	mType = mType:lower()
	return mediaTable[mType] and mediaTable[mType][key] ~= nil
end

function lib:SetDefault(mType, key)
	mType = mType:lower()
	if mediaTable[mType] and mediaTable[mType][key] then
		defaultMedia[mType] = key
		return true
	end
	return false
end

function lib:GetGlobal(mType)
	mType = mType:lower()
	return overrideMedia[mType]
end

function lib:SetGlobal(mType, key)
	mType = mType:lower()
	if not key or (mediaTable[mType] and mediaTable[mType][key]) then
		overrideMedia[mType] = key
		self.callbacks:Fire("LibSharedMedia_SetGlobal", mType, key)
		return true
	end
	return false
end

-- Pre-register built-in WoW assets
local locale = GetLocale and GetLocale() or "enUS"

-- Default Fonts
lib:Register(MediaType.FONT, "Friz Quadrata TTF", "Fonts\\FRIZQT__.TTF")
lib:Register(MediaType.FONT, "Arial Narrow", "Fonts\\ARIALN.TTF")
lib:Register(MediaType.FONT, "Skurri", "Fonts\\SKURRI.TTF")
lib:Register(MediaType.FONT, "Morpheus", "Fonts\\MORPHEUS.TTF")

if locale == "zhTW" then
	lib:Register(MediaType.FONT, "預設字型 (Default)", "Fonts\\blei00d.TTF")
elseif locale == "zhCN" then
	lib:Register(MediaType.FONT, "默认字体 (Default)", "Fonts\\ARKai_T.ttf")
elseif locale == "koKR" then
	lib:Register(MediaType.FONT, "기본 글꼴 (Default)", "Fonts\\2002.TTF")
elseif locale == "ruRU" then
	lib:Register(MediaType.FONT, "Стандартный шрифт (Default)", "Fonts\\FRIZQT___CYR.TTF")
end

-- Default Statusbars
lib:Register(MediaType.STATUSBAR, "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar")
lib:Register(MediaType.STATUSBAR, "Solid", "Interface\\Buttons\\WHITE8X8")

-- Default Backgrounds
lib:Register(MediaType.BACKGROUND, "Blizzard Dialog Background", "Interface\\DialogFrame\\UI-DialogBox-Background")
lib:Register(MediaType.BACKGROUND, "Blizzard Tooltip", "Interface\\Tooltips\\UI-Tooltip-Background")
lib:Register(MediaType.BACKGROUND, "Solid", "Interface\\Buttons\\WHITE8X8")

-- Default Borders
lib:Register(MediaType.BORDER, "Blizzard Dialog", "Interface\\DialogFrame\\UI-DialogBox-Border")
lib:Register(MediaType.BORDER, "Blizzard Tooltip", "Interface\\Tooltips\\UI-Tooltip-Border")

-- Default Sounds
lib:Register(MediaType.SOUND, "Shays Bell", "Sound\\Spells\\ShaysBell.ogg")
lib:Register(MediaType.SOUND, "Flag Captured", "Sound\\Spells\\PVPFlagCaptured.ogg")
lib:Register(MediaType.SOUND, "Simon Tree", "Sound\\Spells\\SimonGame_LargeBlueTree.ogg")
lib:Register(MediaType.SOUND, "Gong", "Sound\\Spells\\Gong_Small.ogg")
lib:Register(MediaType.SOUND, "Landmine", "Sound\\Spells\\GoblinLandMineArmed.ogg")

lib:SetDefault(MediaType.FONT, "Friz Quadrata TTF")
lib:SetDefault(MediaType.STATUSBAR, "Blizzard")
lib:SetDefault(MediaType.BACKGROUND, "Blizzard Dialog Background")
lib:SetDefault(MediaType.BORDER, "Blizzard Dialog")
