--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Locale/enUS
檔案: Locale\enUS.lua

理念:
- 英文 fallback 字串表，任何語系缺字串時以此補底。
- 只註冊字串，不混入 UI 或設定邏輯。

責任:
- 透過 Locale.register("enUS") 寫入 L.* keys。

資料所有權:
- 擁有英文語系 key/value。

可變狀態:
- 只在載入時覆蓋 EAM.L 對應 key。

邊界:
- 不建立 EA_* globals。
- 不查 WoW runtime state。

效能注意:
- 載入期一次性賦值；不在 hot path 執行。

Retail API 注意:
- 保留舊 key 名稱供 migration，後續改名需提供對照。

]]
local _, EAM = ...

local Locale = EAM.Locale
if not Locale then
    return
end

Locale.register("enUS", function(L)

L.EA_SPELL_POWER_NAME = {
	Health 			= "Health",
	Mana 			= "Mana",
	Happiness 		= "Happiness",
	Energy 			= "Energy",				
	Rage 			= "Rage",
	Focus 			= "Focus",
	FocusPet 		= "Pet Focus",
	RunicPower 		= "Runic Power",
	Runes 			= "Runes",
	Pain 			= "Pain",
	Fury 			= "Fury",
	ComboPoints 	= "Combo Points",
	LunarPower 		= "Lunar Power",
	HolyPower 		= "Holy Power",
	ArcaneCharges 	= "Arcane Charges",
	Insanity 		= "Insanity",
	Maelstrom 		= "Maelstrom",
	SoulShards 		= "Soul Shards",
	Chi 			= "Chi",
	DemonicFury 	= "Demonic Fury",
	BurningEmbers 	= "Burning Embers",
	LifeBloom 		= "Lifebloom",
	Essence 		= "Essence",
	Vigor 			= "Vigor",
}

L.EA_TTIP_SPECFLAG_CHECK = {}
for k,v in pairs(L.EA_SPELL_POWER_NAME) do
	L.EA_TTIP_SPECFLAG_CHECK[k] = "Enable/disable, display in primary buff frame: "..v
end

L.EA_XGRPALERT_POWERTYPE = "Power Type:"
L.EA_XGRPALERT_POWERTYPES = {}
for k,v in pairs(L.EA_SPELL_POWER_NAME) do
	L.EA_XGRPALERT_POWERTYPES[#L.EA_XGRPALERT_POWERTYPES + 1]={}
	L.EA_XGRPALERT_POWERTYPES[#L.EA_XGRPALERT_POWERTYPES].text = v
	L.EA_XGRPALERT_POWERTYPES[#L.EA_XGRPALERT_POWERTYPES].value = Enum.PowerType[k]
end

L.EA_TTIP_DOALERTSOUND = "Whether to play sound when an event occurs."
L.EA_TTIP_ALERTSOUNDSELECT = "Select the sound to play when an event occurs."
L.EA_TTIP_LOCKFRAME = "Lock the alert frame to prevent it from being moved by mouse drag."
L.EA_TTIP_SHARESETTINGS = "All professions share the same frame position settings."
L.EA_TTIP_SHOWFRAME = "Show/Hide the alert frame when an event occurs."
L.EA_TTIP_SHOWNAME = "Show/Hide the name of the spell when an event occurs."
L.EA_TTIP_SHOWFLASH = "Show/Hide the full screen flash when an event occurs."
L.EA_TTIP_SHOWTIMER = "Show/Hide the remaining time of the spell when an event occurs."
L.EA_TTIP_CHANGETIMER = "Change the font size and position of the remaining time of the spell."
L.EA_TTIP_ICONSIZE = "Change the size of the icon displayed in the alert."
-- L.EA_TTIP_ICONSPACE = "Change the spacing between icons in the alert."
-- L.EA_TTIP_ICONDROPDOWN = "Change the direction of the expanded icons in the alert."
L.EA_TTIP_ALLOWESC = "Change whether the alert frame can be closed by the ESC key. (Note: UI needs to be reloaded)"
L.EA_TTIP_ALTALERTS = "Enable/Disable additional events triggered by EventAlertMod (non-buff/debuff events)."

	 L.EA_TTIP_ICONXOFFSET = "Adjust the horizontal spacing of the reminder frame."
L.EA_TTIP_ICONYOFFSET = "Adjust the vertical spacing of the reminder frame."
L.EA_TTIP_ICONREDDEBUFF = "Adjust the red depth of the self debuff icon."
L.EA_TTIP_ICONGREENDEBUFF = "Adjust the green depth of the target debuff icon."
L.EA_TTIP_ICONEXECUTION = "Adjust the health percentage for boss execute period. (0% to turn off execute reminder)"
L.EA_TTIP_PLAYERLV2BOSS = "Apply boss-level execute reminder for players who are 2 levels higher (e.g. 5-man instance bosses)."
L.EA_TTIP_SCD_USECOOLDOWN = "Use cooldown shadow for skill cooldown (requires UI reload to take effect)."
L.EA_TTIP_TAR_NEWLINE = "Adjust whether to display the target debuff on a separate line."
L.EA_TTIP_TAR_ICONXOFFSET = "Adjust the horizontal spacing between the target debuff line and the reminder frame."
L.EA_TTIP_TAR_ICONYOFFSET = "Adjust the vertical spacing between the target debuff line and the reminder frame."
L.EA_TTIP_TARGET_MYDEBUFF = "Adjust whether to display only the debuffs cast by the player on the target debuff line."
L.EA_TTIP_SPELLCOND_STACK = "Toggle to show/hide the frame only when the spell stack is greater than or equal to a certain number (minimum value is 2)."
L.EA_TTIP_SPELLCOND_SELF = "Toggle to show/hide only the spells cast by the player, to avoid monitoring the same spells cast by others."
L.EA_TTIP_SPELLCOND_OVERGROW = "Toggle to highlight the frame when the spell stack is greater than or equal to a certain number (minimum value is 1)."
L.EA_TTIP_SPELLCOND_REDSECTEXT = "Toggle to display the remaining seconds in larger red font when it is less than or equal to a certain number of seconds (minimum value is 1)."
L.EA_TTIP_SPELLCOND_ORDERWTD = "Toggle to set the priority of the display order. The larger the number, the higher the priority to display it in the innermost circle (can be set from 1 to 20)."

L.EA_TTIP_SPELLCOND_AURAVALUE1 = "Enable/Disable Aura Value 1 (Label editable on the right)"
L.EA_TTIP_SPELLCOND_AURAVALUE2 = "Enable/Disable Aura Value 2 (Label editable on the right)"
L.EA_TTIP_SPELLCOND_AURAVALUE3 = "Enable/Disable Aura Value 3 (Label editable on the right)"
L.EA_TTIP_SPELLCOND_AURAVALUE4 = "Enable/Disable Aura Value 4 (Label editable on the right)"

L.EA_TTIP_GRPCFG_ICONALPHA = "Change the transparency of the icon."
L.EA_TTIP_GRPCFG_TALENT = "Only applicable when in this specialization."
L.EA_TTIP_GRPCFG_HIDEONLEAVECOMBAT = "Hide icon when leaving combat."
L.EA_TTIP_GRPCFG_HIDEONLOSTTARGET = "Hide icon when there is no target."
L.EA_TTIP_GRPCFG_GLOWWHENTRUE = "Highlight icon when conditions are met."

L.EA_TTIP_SCD_ITEMCOOLDOWN = "Toggle item cooldown detection (May affect performance, requires UI reload)"
L.EA_TTIP_SCD_REMOVEWHENCOOLDOWN = "Remove Spell Icon When on Cooldown"
L.EA_TTIP_SCD_GLOWWHENUSABLE = "Make SCD Icon Glow When Usable"
L.EA_TTIP_SCD_NOCOMBATSTILLKEEP = "Keep SCD Icon Even When Out of Combat"
L.EA_TTIP_SHOWRUNESBAR = "Show Rune Bar above Buff Bar"

L.EA_TTIP_SNAMEFONTSIZE = "Adjust the font size of the spell name (affects aura values)"
L.EA_TTIP_TIMERFONTSIZE = "Adjust the countdown font size"
L.EA_TTIP_STACKFONTSIZE = "Adjust the stack count font size"


L.EA_XOPT_SCD_REMOVEWHENCOOLDOWN = "Remove Spell Icon When on Cooldown"
L.EA_XOPT_SCD_GLOWWHENUSABLE = "Make SCD Icon Glow When Usable"
L.EA_XOPT_SCD_NOCOMBATSTILLKEEP = "Keep SCD Icon Even When Out of Combat"
L.EA_XOPT_SCD_ITEMCOOLDOWN = "Toggle item cooldown detection "

L.EA_XOPT_SHOWRUNESBAR = "Show DK Rune Bar"

L.EA_XOPT_ICONPOSOPT = "Icon position & class-specific resources."
L.EA_XOPT_SHOW_ALTFRAME = "Show the main reminder frame."
L.EA_XOPT_SHOW_BUFFNAME = "Show the name of the spell."
L.EA_XOPT_SHOW_TIMER = "Show the countdown timer."
L.EA_XOPT_SHOW_OMNICC = "Show the timer within the frame."
L.EA_XOPT_SHOW_FULLFLASH = "Show full-screen flash reminder."
L.EA_XOPT_PLAY_SOUNDALERT = "Play sound alert."
L.EA_XOPT_ESC_CLOSEALERT = "Close alert with ESC."
L.EA_XOPT_SHOW_ALTERALERT = "Show additional reminder."
L.EA_XOPT_SHOW_CHECKLISTALERT = "Enable."
L.EA_XOPT_SHOW_CLASSALERT = "Class-specific buff/debuff reminders."
L.EA_XOPT_SHOW_OTHERALERT = "Cross-class buff/debuff reminders."
L.EA_XOPT_SHOW_TARGETALERT = "Target-specific buff/debuff reminders."
L.EA_XOPT_SHOW_SCDALERT = "Class-Specific CD Alert"
L.EA_XOPT_SHOW_GROUPALERT = "Class-Specific Condition Alert"
L.EA_XOPT_OKAY = "Close"
L.EA_XOPT_SAVE = "Save"
L.EA_XOPT_CANCEL = "Cancel"
L.EA_XOPT_VERURLTEXT = "EAM Release URL:\nwww.curseforge.com/wow/addons/eventalertmod"
L.EA_XOPT_VERBTN1 = "CorseForge"
L.EA_XOPT_VERURL1 = "http://www.curseforge.com/wow/addons/eventalertmod"
L.EA_XOPT_SPELLCOND_STACK = "Stacks >= to show frame:"
L.EA_XOPT_SPELLCOND_SELF = "Restrict to spells cast by player only"
L.EA_XOPT_SPELLCOND_OVERGROW = "Stacks >= to highlight:"
L.EA_XOPT_SPELLCOND_REDSECTEXT = "Countdown <= to show red text:"
L.EA_XOPT_SPELLCOND_ORDERWTD = "Priority weight (1-20):"

L.EA_XOPT_SPELLCOND_AURAVALUE1 = "Show Aura Value 1"
L.EA_XOPT_SPELLCOND_AURAVALUE2 = "Show Aura Value 2"
L.EA_XOPT_SPELLCOND_AURAVALUE3 = "Show Aura Value 3"
L.EA_XOPT_SPELLCOND_AURAVALUE4 = "Show Aura Value 4"


L.EA_XICON_LOCKFRAME = "Lock Example Frame"
L.EA_XICON_LOCKFRAMETIP = "Uncheck to move Alert Frame or reset frame position"
L.EA_XICON_SHARESETTING = "Share Frame Position Setting"
L.EA_XICON_ICONSIZE = "Icon Size"
-- L.EA_XICON_ICONSIZE2 = "Target Icon Size"
-- L.EA_XICON_ICONSIZE3 = "CD Icon Size"
L.EA_XICON_LARGE = "Large"
L.EA_XICON_SMALL = "Small"
L.EA_XICON_HORSPACE = "Horizontal Spacing"
L.EA_XICON_VERSPACE = "Vertical Spacing"
-- L.EA_XICON_ICONSPACE1 = "Self Icon Spacing"
-- L.EA_XICON_ICONSPACE2 = "Target Icon Spacing"
-- L.EA_XICON_ICONSPACE3 = "CD Icon Spacing"
L.EA_XICON_MORE = "More"
L.EA_XICON_LESS = "Less"
L.EA_XICON_REDDEBUFF = "Self Debuff Icon Red Intensity"
L.EA_XICON_GREENDEBUFF = "Target Debuff Icon Green Intensity"
L.EA_XICON_DEEP = "Deep"
L.EA_XICON_LIGHT = "Light"
-- L.EA_XICON_DIRECTION = "Expansion Direction"
-- L.EA_XICON_DIRUP = "Up"
-- L.EA_XICON_DIRDOWN = "Down"
-- L.EA_XICON_DIRLEFT = "Left"
-- L.EA_XICON_DIRRIGHT = "Right"
L.EA_XICON_TAR_NEWLINE = "Display target debuffs in a new line"
L.EA_XICON_TAR_HORSPACE = "Horizontal spacing with alert frame"
L.EA_XICON_TAR_VERSPACE = "Vertical spacing with alert frame"
L.EA_XICON_TOGGLE_ALERTFRAME = "Move Frame"
L.EA_XICON_RESET_FRAMEPOS = "Reset Frame Position"
L.EA_XICON_SELF_BUFF = "Self Buff"
L.EA_XICON_SELF_SPBUFF = "Self Debuff (1)\nor special frame"
L.EA_XICON_SELF_DEBUFF = "Self Debuff"
L.EA_XICON_TARGET_BUFF = "Target Buff"
L.EA_XICON_TARGET_SPBUFF = "Target Buff (1)\nor special frame"
L.EA_XICON_TARGET_DEBUFF = "Target Debuff"
L.EA_XICON_SCD = "Skill Cooldown"
L.EA_XICON_EXECUTION = "Alert for Boss-level Target Execution"
L.EA_XICON_EXEFULL = "100%"
L.EA_XICON_EXECLOSE = "Close"
L.EA_XICON_SCD_USECOOLDOWN = "Use countdown shadow for cooldowns (requires UI reload)"

L.EA_XICON_SNAMEFONTSIZE = "Spell Name Font Size"
L.EA_XICON_TIMERFONTSIZE = "Countdown Font Size"
L.EA_XICON_STACKFONTSIZE = "Stack Count Font Size"


EX_XCLSALERT_SELALL = "Select All"
EX_XCLSALERT_CLRALL = "Clear All"
EX_XCLSALERT_LOADDEFAULT = "Default"
EX_XCLSALERT_REMOVEALL = "Delete All"
EX_XCLSALERT_SPELL = "Spell ID:"
EX_XCLSALERT_ADDSPELL = "Add"
EX_XCLSALERT_DELSPELL = "Delete"
EX_XCLSALERT_HELP1 = "The above list is sorted by [Spell ID]."
EX_XCLSALERT_HELP2 = "If you want to check the Spell ID, it is recommended to enter the /eam help command."
EX_XCLSALERT_HELP3 = "Understand the various commands for [Query Spells] in the game."
EX_XCLSALERT_HELP4 = "The additional reminder area is the condition skill that is not of the Buff type."
EX_XCLSALERT_HELP5 = "For example, when the enemy's health enters the execute phase or is used after parrying."
EX_XCLSALERT_HELP6 = "It will not display Buffs, but can use skills."
EX_XCLSALERT_SPELLURL = "http://www.wowhead.com/spells"

L.EA_XTARALERT_TARGET_MYDEBUFF = "Only show player's debuffs"

L.EA_XGRPALERT_ICONALPHA = "Icon Transparency"
L.EA_XGRPALERT_GRPID = "Group ID:"
L.EA_XGRPALERT_TALENT1 = "Talent 1"
L.EA_XGRPALERT_TALENT2 = "Talent 2"
L.EA_XGRPALERT_TALENT3 = "Talent 3"
L.EA_XGRPALERT_TALENT4 = "Talent 4"
L.EA_XGRPALERT_HIDEONLEAVECOMBAT = "Hide when out of combat"
L.EA_XGRPALERT_HIDEONLOSTTARGET = "Hide when no target"
L.EA_XGRPALERT_GLOWWHENTRUE = "Glow when condition met"
L.EA_XGRPALERT_TALENTS = "All Talents"
L.EA_XGRPALERT_NEWSPELLBTN = "Add Spell"
L.EA_XGRPALERT_NEWCHECKBTN = "Add Parent Condition"
L.EA_XGRPALERT_NEWSUBCHECKBTN = "Add Child Condition"
L.EA_XGRPALERT_SPELLNAME = "Spell Name:"
L.EA_XGRPALERT_SPELLICON = "Spell Icon:"
L.EA_XGRPALERT_TITLECHECK = "Parent Condition:"
L.EA_XGRPALERT_TITLESUBCHECK = "Child Condition:"
L.EA_XGRPALERT_TITLEORDERUP = "Move Up"
L.EA_XGRPALERT_TITLEORDERDOWN = "Move Down"

L.EA_XGRPALERT_LOGICS = {
	[1]={text="And", value=1},
	[2]={text="Or", value=0},
	}

L.EA_XGRPALERT_EVENTTYPE = "Event Type:"

L.EA_XGRPALERT_EVENTTYPES = {
	[1]={text="Unit Power Changes", value="UNIT_POWER_UPDATE"},
	[2]={text="Unit Health Changes", value="UNIT_HEALTH"},
	[3]={text="Unit Buff/Debuff Changes", value="UNIT_AURA"},
	[4]={text="Combo Point Changes", value="UNIT_COMBO_POINTS"}, }

L.EA_XGRPALERT_UNITTYPE = "Target:"

L.EA_XGRPALERT_UNITTYPES = {
	[1]={text="Player", value="player"},
	[2]={text="Target", value="target"},
	[3]={text="Focus", value="focus"},
	[4]={text="Pet", value="pet"},
	[5]={text="Boss1", value="boss1"},
	[6]={text="Boss2", value="boss2"},
	[7] = {text="Boss3", value="boss3"},
	[8] = {text="Boss4", value="boss4"},
	[9] = {text="Party1", value="party1"},
	[10] = {text="Party2", value="party2"},
	[11] = {text="Party3", value="party3"},
	[12] = {text="Party4", value="party4"},
	[13] = {text="Raid1", value="raid1"},
	[14] = {text="Raid2", value="raid2"},
	[15] = {text="Raid3", value="raid3"},
	[16] = {text="Raid4", value="raid4"},
	[17] = {text="Raid5", value="raid5"},
	[18] = {text="Raid6", value="raid6"},
	[19] = {text="Raid7", value="raid7"},
	[20] = {text="Raid8", value="raid8"},
	[21] = {text="Raid9", value="raid9"},
}

L.EA_XGRPALERT_CHECKCD = "Check spell CD:"
L.EA_XGRPALERT_HEALTH = "Health:"

L.EA_XGRPALERT_COMPARETYPES = {
	[1] = {text="Value", value=1},
	[2] = {text="Percentage", value=2},
}
L.EA_XGRPALERT_CHECKAURA = "Buff/Debuff:"
L.EA_XGRPALERT_CHECKAURAS = {
	[1] = {text="Exist", value=1},
	[2] = {text="NotExist", value=2},
}
L.EA_XGRPALERT_AURATIME = "Time:"
L.EA_XGRPALERT_AURASTACK = "Stacks:"
L.EA_XGRPALERT_CASTBYPLAYER = "Casted by player only"
L.EA_XGRPALERT_COMBOPOINT = "Combo points:"

L.EA_XLOOKUP_START1 = "Search Spell Name"
L.EA_XLOOKUP_START2 = "Exact match"
L.EA_XLOOKUP_RESULT1 = "Search Result"
L.EA_XLOOKUP_RESULT2 = " matches"
L.EA_XLOAD_LOAD = "\124cffFFFF00EventAlertMod\124r:Spell monitoring and trigger alert, loaded version:\124cff00FFFF"

L.EA_XLOAD_FIRST_LOAD = "\124cffFF0000First time loading EventAlertMod, loading default parameters\124r.\n\n"..
"Please use \124cffFFFF00/eam opt\124r for parameter settings, spell monitoring, and position adjustment.\n\n"

L.EA_XLOAD_NEWVERSION_LOAD = "Please use \124cffFFFF00/eam help\124r for detailed command instructions.\n\n\n"..
"\124cff00FFFF- Main Update Items -\124r\n\n"..
"*New Feature: Event prompt function with multiple judgment conditions in a group.\n\n"..
"The currently supported detected events are:\n"..
"1. 'Object' 'energy', when 'greater than or equal to' or 'less than or equal to' a certain 'value or ratio' is triggered\n"..
"2. 'Object' 'health', when 'greater than or equal to' or 'less than or equal to' a certain 'value or ratio' is triggered\n"..
"3. 'Object' 'Buff/Debuff', when 'specific spell ID' is included (can be filtered by layer or seconds), or when 'specific spell ID' is not included is triggered\n"..
"4. 'Player' 'combo points' for 'target', when 'greater than or equal to' or 'less than or equal to' a certain 'value' is triggered\n"..
"All of the above conditions can be filtered by AND or OR, one or more conditions are used for filtering.\n"..
"When the filtering result is true, the specified icon is prompted.\n"..
"" -- END OF NEWVERSION

L.EA_XCMD_VER = " \124cff00FFFFBy Whitep@�p��\124r Version: "
L.EA_XCMD_DEBUG = " Mode: "
L.EA_XCMD_SELFLIST = " Display self Buff/Debuff: "
L.EA_XCMD_TARGETLIST = " Display target Debuff: "
L.EA_XCMD_CASTSPELL = " Display spell ID: "
L.EA_XCMD_AUTOADD_SELFLIST = " Automatically add self all auras: "
L.EA_XCMD_ENVADD_SELFLIST = " Automatically add self environmental auras: "
L.EA_XCMD_DEBUG_P0 = "Triggered Spell List"
L.EA_XCMD_DEBUG_P1 = "Spell"
L.EA_XCMD_DEBUG_P2 = "Spell ID"
L.EA_XCMD_DEBUG_P3 = "Stack"
L.EA_XCMD_DEBUG_P4 = "Duration"

L.EA_XCMD_CMDHELP = {
["TITLE"] = "\124cffFFFF00EventAlertMod\124r \124cff00FF00Command\124r Instructions(/eventalertmod or /eam):",
["OPT"] = "\124cff00FF00/eam options(or opt)\124r - Show/Hide main settings window.",
["HELP"] = "\124cff00FF00/eam help\124r - Show further command instructions.",
["SHOW"] = {
"\124cff00FF00/eam show [sec]\124r -",
"Start/Stop, continuously list >Player< all Buff/Debuff's spell ID, and the spells duration is within sec seconds",
},
["SHOWT"] = {
"\124cff00FF00/eam showtarget(or showt) [sec]\124r -",
"Start/Stop, continuously list >Target< all Debuff's spell ID, and the spells duration is within sec seconds",
},
["SHOWC"] = {
"\124cff00FF00/eam showcast(or showc)\124r -",
"Start/Stop, list the spell ID after a successful cast",
},

["SHOWA"] = {
"\124cff00FF00/eam showautoadd (or showa) [sec]\124r -",
"Start/stop automatically monitoring all Buff/Debuff spells on the >player< and add them to the watch list. Spells with a duration of within sec seconds (default is 60 seconds)",
},
["SHOWE"] = {
"\124cff00FF00/eam showenvadd (or showe) [sec]\124r -",
"Start/stop automatically monitoring all Buff/Debuff spells on the >player< (excluding those from raid and party members) and add them to the watch list. Spells with a duration of within sec seconds (default is 60 seconds)",
},
["LIST"] = {
"\124cff00FF00/eam list\124r - Show trigger spell list",
"Show/hide the output of the commands: show, showc, showt, lookup, and lookupfull",
},
["LOOKUP"] = {
"\124cff00FF00/eam lookup (or l) name\124r - Search for partial spell name",
"Search for all spells in the game and list all spell IDs that [partially match] the search name",
},
["LOOKUPFULL"] = {
"\124cff00FF00/eam lookupfull (or lf) name\124r - Search for complete spell name",
"Search for all spells in the game and list all spell IDs that [completely match] the search name",
},
}
-- EAM Rewrite Additions (Auto-generated)
L.EAM_FRAME_SELF_AURA = "EAM - Self Aura Frame"
L.EAM_FRAME_TARGET_AURA = "EAM - Target Aura Frame"
L.EAM_FRAME_SPELL_COOLDOWN = "EAM - Spell Cooldown Frame"
L.EAM_FRAME_ITEM_COOLDOWN = "EAM - Item Cooldown Frame"
L.EAM_FRAME_CLASS_POWER = "EAM - Class Power Frame"
L.EAM_FRAME_GROUND_EFFECT = "EAM - Ground Effect Frame"
L.EAM_FRAME_TOTEM = "EAM - Totem Frame"
L.EAM_FRAME_POS_SAVED = "Position saved: %s, X: %.1f, Y: %.1f"
L.EAM_MOVE_MODE_ON = "Multi-frame movement mode enabled! Drag frames to move, click button again to lock."
L.EAM_MOVE_MODE_OFF = "Multi-frame movement mode disabled. Layout applied."
L.EAM_POWER_CLASS_POWER = "Class Power"
L.EAM_POWER_HOLY_POWER = "Holy Power"
L.EAM_POWER_SOUL_SHARDS = "Soul Shards"
L.EAM_POWER_COMBO_POINTS = "Combo Points"
L.EAM_POWER_CHI = "Chi"
L.EAM_POWER_ARCANE_CHARGES = "Arcane Charges"
L.EAM_POWER_RUNIC_POWER = "Runic Power"
L.EAM_POWER_RAGE = "Rage"
L.EAM_POWER_FURY_PAIN = "Fury/Pain"
L.EAM_GROUND_SKILL_DEFAULT = "Ground Skill"
L.EAM_ITEM_PREFIX = "Item "
L.EAM_OPT_POS_AND_POWER_BTN = "Icon Position & Power Settings"
L.EAM_OPT_ENABLE_FRAME = "Enable Alert Frame"
L.EAM_OPT_SHOW_SPELL_NAME = "Show Spell Name"
L.EAM_OPT_SHOW_TIME_VAL = "Show Countdown"
L.EAM_OPT_SHOW_CHANGE_IN_OUT = "Toggle Inner/Outer"
L.EAM_OPT_SHOW_FLASH = "Enable Fullscreen Flash"
L.EAM_OPT_SHOW_SOUND = "Enable Sound Alert"
L.EAM_OPT_SOUND_PREFIX = "Sound: "
L.EAM_OPT_TEST_BTN = "Test"
L.EAM_OPT_ALLOW_ESC = "Allow ESC Close"
L.EAM_OPT_SHOW_EXTRA_ALERT = "Show Extra Alerts"
L.EAM_OPT_COOLDOWN_REMOVE = "Remove Aura on CD Done"
L.EAM_OPT_SHOW_SCD_OUTSIDE = "Show Spell CD OOC"
L.EAM_OPT_GLOW_SCD = "Glow Spell CD When Usable"
L.EAM_OPT_SHOW_DK_RUNE = "Show DK Rune Alert"
L.EAM_OPT_ENABLE_ITEM_CD = "Enable Item CD Alert"
L.EAM_OPT_ENABLE_CDM = "Attach to Blizzard CooldownViewer"
L.EAM_OPT_CLOSE_BTN = "Close Settings"
L.EAM_OPT_DEBUG_BTN = "Debug Diagnosis"
L.EAM_OPT_DEBUG_NOT_LOADED = "Debug module is not loaded!"
L.EAM_OPT_SLIDER_ICON_SIZE = "Icon Size"
L.EAM_OPT_SLIDER_ICON_SPACING = "Horizontal Spacing"
L.EAM_OPT_SLIDER_VERT_SPACING = "Vertical Spacing"
L.EAM_OPT_SLIDER_DEBUFF_RED = "Self Debuff Red"
L.EAM_OPT_SLIDER_DEBUFF_GREEN = "Target Debuff Green"
L.EAM_OPT_SLIDER_EXECUTE_LIMIT = "Execute Limit"
L.EAM_OPT_ENABLE_EXECUTE = "Enable Execute Alert"
L.EAM_OPT_SLIDER_FONT_SPELL = "Spell Font Size"
L.EAM_OPT_SLIDER_FONT_CD = "CD Font Size"
L.EAM_OPT_SLIDER_FONT_STACK = "Stack Font Size"
L.EAM_OPT_SLIDER_SHADOW_ALPHA = "CD Shadow Alpha"
L.EAM_OPT_DIR_TITLE = "Icon Growth Direction Settings"
L.EAM_OPT_DIR_RIGHT = "Right (→)"
L.EAM_OPT_DIR_LEFT = "Left (←)"
L.EAM_OPT_DIR_UP = "Up (↑)"
L.EAM_OPT_DIR_DOWN = "Down (↓)"
L.EAM_OPT_GROW_SELF_AURA = "Self Aura Growth"
L.EAM_OPT_GROW_TARGET_AURA = "Target Aura Growth"
L.EAM_OPT_GROW_SPELL_COOLDOWN = "Spell CD Growth"
L.EAM_OPT_GROW_ITEM_COOLDOWN = "Item CD Growth"
L.EAM_OPT_GROW_GROUND_EFFECT = "Ground Effect Growth"
L.EAM_OPT_GROW_TOTEM = "Totem Growth"
L.EAM_OPT_GROW_CLASS_POWER = "Class Power Growth"
L.EAM_OPT_TIMER_INSIDE = "Show Countdown Inside Icon"
L.EAM_OPT_TIMER_ALIGN = "Countdown Text Alignment"
L.EAM_OPT_POWER_MONITOR_TITLE = "Special Class Power Alerts"
L.EAM_OPT_MOVE_FRAME_BTN = "Move Alert Frames"
L.EAM_OPT_MOVE_MODE_ON_PRINT = "Movement mode enabled (use /eam to drag)"
L.EAM_OPT_RESET_FRAME_BTN = "Reset All Icons & Positions"
L.EAM_OPT_RESET_FRAME_SUCCESS = "Reset all alert frames to default layout."
L.EAM_OPT_LIST_TITLE = "Alert Spell List Settings"
L.EAM_OPT_SELECT_ALL = "Select All"
L.EAM_OPT_DESELECT_ALL = "Deselect All"
L.EAM_OPT_DEFAULTS_BTN = "Defaults"
L.EAM_OPT_DEFAULTS_SUCCESS = "Successfully loaded class default spells!"
L.EAM_OPT_DEFAULTS_FAIL = "No default spells found for current class."
L.EAM_OPT_DELETE_ALL = "Delete All"
L.EAM_OPT_FILTER_ALL = "Filter: All Spells"
L.EAM_OPT_FILTER_PREFIX = "Filter: "
L.EAM_OPT_FILTER_GENERAL = "General / Custom"
L.EAM_OPT_ADD_SUCCESS = "Added alert [ID: %s]"
L.EAM_OPT_ADD_FAIL = "Failed to add alert: %s"
L.EAM_OPT_DEL_SUCCESS = "Removed alert [ID: %s]"
L.EAM_OPT_DEL_FAIL = "Failed to remove alert: %s"
L.EAM_OPT_ADD_BTN = "Add"
L.EAM_OPT_DEL_BTN = "Delete"
L.EAM_OPT_ERR_INVALID_ID = "Please enter a valid ID!"
L.EAM_OPT_ADD_DEL_DESC = "Enter SpellID or ItemID and click Add / Delete."
L.EAM_OPT_COND_SPELL_NAME = "Spell Name"
L.EAM_OPT_COND_STACK = "Stack Threshold"
L.EAM_OPT_COND_GLOW = "Glow Threshold"
L.EAM_OPT_COND_RED_LIMIT = "Red Text CD Limit (sec)"
L.EAM_OPT_COND_PRIORITY = "Sort Priority"
L.EAM_OPT_COND_PLAYER_ONLY = "Only Cast By Player"
L.EAM_OPT_COND_VAL_TITLE = "Display Aura Values:"
L.EAM_OPT_COND_VAL1 = "Show Value 1"
L.EAM_OPT_COND_VAL2 = "Show Value 2"
L.EAM_OPT_COND_VAL3 = "Show Value 3"
L.EAM_OPT_COND_VAL4 = "Show Value 4"
L.EAM_OPT_COND_TOOLTIP = "Enable Tooltip Scrape"
L.EAM_OPT_COND_MANUAL_DUR = "Manual Duration (sec)"
L.EAM_OPT_COND_SCRAPE_BTN = "Scrape"
L.EAM_OPT_SCRAPE_SUCCESS = "Scraped duration: %s sec"
L.EAM_OPT_SCRAPE_FAIL = "Could not parse duration from tooltip, please set manually."
L.EAM_OPT_COND_SAVE_BTN = "Save"
L.EAM_OPT_COND_SAVE_SUCCESS = "Conditions saved."
L.EAM_OPT_COND_CANCEL_BTN = "Cancel"
L.EAM_OPT_COMBAT_WARNING = "Cannot open settings in combat. It will open automatically after combat."
L.EAM_OPT_MINIMAP_LCLICK = "Left-click: Toggle settings"
L.EAM_OPT_MINIMAP_RCLICK = "Right-click: Open debug menu"
L.EAM_OPT_MINIMAP_DRAG = "Drag to move minimap button"
L.EAM_ALIGN_CENTER = "Center"
L.EAM_ALIGN_TOP = "Top"
L.EAM_ALIGN_BOTTOM = "Bottom"
L.EAM_ALIGN_LEFT = "Left"
L.EAM_ALIGN_RIGHT = "Right"
L.EAM_ALIGN_TOPLEFT = "Top Left"
L.EAM_ALIGN_TOPRIGHT = "Top Right"
L.EAM_ALIGN_BOTTOMLEFT = "Bottom Left"
L.EAM_ALIGN_BOTTOMRIGHT = "Bottom Right"
L.EAM_OPT_CAT_SELF = "Self Buff/Debuff (Self)"
L.EAM_OPT_CAT_CLASS = "Class Buff/Debuff (Class)"
L.EAM_OPT_CAT_TARGET = "Target Buff/Debuff (Target)"
L.EAM_OPT_CAT_SPELL_CD = "Spell Cooldown (Spell CD)"
L.EAM_OPT_CAT_ITEM_CD = "Item Cooldown (Item CD)"
L.EAM_OPT_CAT_GROUND = "Ground Effects (Ground)"
L.EAM_OPT_CAT_LAYOUT = "Layout & Power (Layout)"
L.EAM_SLASH_HELP_OPT = "/eam opt - Toggle settings window"
L.EAM_SLASH_HELP_DOCTOR = "/eam doctor - Run API boundaries diagnostic"
L.EAM_SLASH_HELP_VALIDATE = "/eam validate - Same as /eam doctor"
L.EAM_SLASH_HELP_DEBUG = "/eam debug - Show debug summary"
L.EAM_SLASH_HELP_EXPORT = "/eam export - Export AI debug prompt"
L.EAM_SLASH_HELP_ADD = "/eam add <spellID> - Add player aura alert"
L.EAM_SLASH_HELP_ADD_TARGET = "/eam add target <spellID> - Add target aura alert"
L.EAM_SLASH_HELP_ADD_CD = "/eam add cd <spellID> - Add spell cooldown alert"
L.EAM_SLASH_HELP_ADD_ITEM = "/eam add item <itemID> - Add item cooldown alert"
L.EAM_SLASH_HELP_REMOVE = "/eam remove <spellID|target|cd|item> <id> - Remove alert"
L.EAM_SLASH_NOT_INIT = "SavedVariables not initialized."
L.EAM_SLASH_OP_FAIL = "Operation failed: "
L.EAM_SLASH_DEBUG_GROUND_START = "Debugging ground effect tooltip parsing (current locale: %s)..."
L.EAM_SLASH_DEBUG_GROUND_SUCCESS = "Spell [%d] parsed duration successfully: |cff00ff00%s sec|r"
L.EAM_SLASH_DEBUG_GROUND_FAIL = "Spell [%d] tooltip parsing failed, using default duration"
L.EAM_SLASH_GROUND_NOT_LOADED = "GroundEffectService is not loaded!"
L.EAM_SLASH_SPECIFY_SPELLID = "Please specify correct spell ID: /eam debug ground <spellID>"
L.EAM_OPT_FLOW_TEST_BTN = "Flow Tests"
L.EAM_SLASH_HELP_TEST = "/eam test [quick|core|boundary|all] - Open or run flow validation"
L.EAM_FLOW_PANEL_TITLE = "EAM Flow Validation & Developer Feedback"
L.EAM_FLOW_PANEL_DESC = "Offline Mock and Retail/PTR use the same cases. Mock pass is not a live-client pass."
L.EAM_FLOW_BUTTON_QUICK = "Quick Flow"
L.EAM_FLOW_BUTTON_CORE = "Core Flow"
L.EAM_FLOW_BUTTON_BOUNDARY = "Boundary Flow"
L.EAM_FLOW_BUTTON_AURA121 = "12.1 Aura"
L.EAM_OPT_AURA_BACKEND = "Aura backend: "
L.EAM_OPT_AURA_PENDING = " (pending combat end)"
L.EAM_OPT_AURA_REBUILD = "Rebuild"
L.EAM_FLOW_BUTTON_ALL = "Run All"
L.EAM_FLOW_BUTTON_COPY = "Copy Dev Report"
L.EAM_FLOW_BUTTON_CLOSE = "Close"
L.EAM_FLOW_STATUS_NO_REPORT = "No flow validation report yet."
L.EAM_FLOW_STATUS_SUMMARY = "Done: %d passed, %d failed, %d skipped."
L.EAM_FLOW_STATUS_COPIED = "Report copied for developer feedback."
L.EAM_FLOW_STATUS_COMBAT = "Flow validation does not run in combat."
L.EAM_FLOW_STATUS_UNAVAILABLE = "Flow validation module is unavailable."
L.EAM_FLOW_STATUS_RUNNING = "Flow validation is running..."
L.EAM_FLOW_STATUS_START_FAILED = "Cannot start flow validation: %s"
L.EAM_FLOW_STATUS_DEFERRED = "Flow validation panel will open after combat."
-- EAM Spec Filter Additions (Auto-generated)
L.EAM_OPT_FILTER_ALL_VAL = "All Spells"

L.EAM_TOOLTIP_SPELL_ID = "EAM Spell ID"
L.EAM_TOOLTIP_ITEM_ID = "EAM Item ID"
L.EAM_TOOLTIP_MACRO_ID = "EAM Macro ID"
L.EAM_TOOLTIP_OPEN_HINT = "Ctrl+Alt: open EAM monitor menu"
L.EAM_TOOLTIP_MACRO_MANUAL_HINT = "Macro source cannot be read safely; Ctrl+Alt opens manual EAM entry"
L.EAM_TOOLTIP_AURA_HINT = "Aura ID is shown by Blizzard; Ctrl+Alt opens EAM"
L.EAM_TOOLTIP_AURA_MANUAL_HINT = "Aura ID display is unavailable; Ctrl+Alt opens manual EAM entry"
L.EAM_POPUP_TITLE = "EAM Add Monitor"
L.EAM_POPUP_ID_UNRESOLVED = "Unresolved"
L.EAM_POPUP_DESC_SPELL = "Spell ID: %s"
L.EAM_POPUP_DESC_ITEM = "Item ID: %s"
L.EAM_POPUP_DESC_AURA = "Enter the Aura spell ID shown in the tooltip, then choose the unit to monitor."
L.EAM_POPUP_DESC_AURA_MANUAL = "Blizzard Aura ID display is unavailable. Enter a known Aura spell ID, then choose the unit to monitor."
L.EAM_POPUP_DESC_MACRO = "Macro ID: %s\nSpell ID: %s\nItem ID: %s"
L.EAM_POPUP_ID_INPUT = "Monitor ID"
L.EAM_POPUP_ADD_SPELL = "Add spell cooldown"
L.EAM_POPUP_ADD_ITEM = "Add item cooldown"
L.EAM_POPUP_ADD_AURA_PLAYER = "Add player aura"
L.EAM_POPUP_ADD_AURA_TARGET = "Add target aura"
L.EAM_POPUP_CANCEL = "Cancel"
L.EAM_POPUP_STATUS_ADDED = "Added to monitor list"
L.EAM_POPUP_STATUS_UPDATED = "Monitor updated"
L.EAM_POPUP_STATUS_UNCHANGED = "Already monitored"
L.EAM_POPUP_RESULT = "EAM: %s (ID %d)"
L.EAM_POPUP_RESULT_FAILED = "EAM: unable to add monitor (%s)"



end)

