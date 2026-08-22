--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_InitVar.lua

理念:
- 保留舊版 EAM 行為參考，供 Retail rewrite migration 對照。
- 此檔不屬正式載入路徑；重寫時只取行為語意，不沿用舊架構。

責任:
- 說明此檔案在目前架構中的責任、資料所有權與維護定位。

邊界:
- 不得繞過 Secret/Protected Data。
- 不得在熱路徑製造不必要 table、closure 或字串配置。
- 若屬 LegacyReference，只能作為行為參考，不得直接成為新架構依賴。
]]
----------------------------------------------------
-- Assign addon space to local G var.  
-- For sync addon space to each lua fils
-----------------------------------------------------
local _
local _G = _G
local addonName, G = ... 
_G[addonName] = _G[addonName] or G
-----------------------------------
if LibDebug then LibDebug() end
-----------------------------------
EA_Config = {
			SpecPowerCheck = {
				DarkForce,
				BurningEmbers,
				DemonicFury,				
				Eclipse,
				FocusPet,
				ComboPoints,
				Mana,
				Rage, 
				Focus,
				Energy,
				Runes,
				RunicPower,
				Runes,
				SoulShards,				
				LunarPower,
				HolyPower,				
				Chi,				
				Insanity,				
				ArcaneCharges,
				Maelstrom,
				Fury,			
				Pain,
				Happiness,
				LifeBloom,	
				Essence,
				Vigor,
				},
			DoAlertSound,
			AlertSound,
			AlertSoundValue,
			LockFrame,
			ShareSettings,
			ShowFrame,
			ShowName,
			ShowFlash,
			ShowTimer,
			BaseFontSize,
			TimerFontSize,
			StackFontSize,
			SNameFontSize,
			ChangeTimer,
			Version,
			AllowESC,
			AllowAltAlerts,
			Target_MyDebuff,
			
			}   
-----------------------------------------------------------------
--STANDARD_TEXT_FONT表示針對該語系所指向的系統預設字型
G.FONTS 		= STANDARD_TEXT_FONT
G.FONT_OBJECT 	= GameFontHighlight
--G.FONT_OBJECT = GameFontNormal
--G.FONT_OBJECT = GameFontNormalSmall
--G.FONT_OBJECT = GameFontNormalLarge
--G.FONT_OBJECT = GameFontHighlightSmall
--G.FONT_OBJECT = GameFontHighlightSmallOutline
--G.FONT_OBJECT = GameFontHighlightLarge
--G.FONT_OBJECT = GameFontDisable
--G.FONT_OBJECT = GameFontDisableSmall
--G.FONT_OBJECT = GameFontDisableLarge
--G.FONT_OBJECT = GameFontGreen
--G.FONT_OBJECT = GameFontGreenSmall
--G.FONT_OBJECT = GameFontGreenLarge
--G.FONT_OBJECT = GameFontRed
--G.FONT_OBJECT = GameFontRedSmall
--G.FONT_OBJECT = GameFontRedLarge
--G.FONT_OBJECT = GameFontWhite
--G.FONT_OBJECT = GameFontDarkGraySmall
--G.FONT_OBJECT = NumberFontNormalYellow
--G.FONT_OBJECT = NumberFontNormalSmallGray
--G.FONT_OBJECT = QuestFontNormalSmall
--G.FONT_OBJECT = DialogButtonHighlightText
--G.FONT_OBJECT = ErrorFont
--G.FONT_OBJECT = TextStatusBarText
--G.FONT_OBJECT = CombatLogFont
-----------------------------------------------------------------
EA_Position = 	{
				Anchor,
				relativePoint,
				xLoc,
				yLoc,
				xOffset,
				yOffset,
				RedDebuff,
				GreenDebuff,
				Tar_NewLine,
				TarAnchor,
				TarrelativePoint,
				Tar_xOffset,
				Tar_yOffset,
				ScdAnchor,
				Scd_xOffset,
				Scd_yOffset,
				Execution,
				PlayerLv2BOSS,
				SCD_UseCooldown,
				}
-----------------------------------------------------------------
-- EA_Pos = {}
-- EA_SPELLINFO_SELF = {}
-- EA_SPELLINFO_TARGET = {}
-- EA_SPELLINFO_SCD = {}
-- EA_ClassAltSpellName = {}
-- GC_IndexOfGroupFrame = {}

G.Pos = {}
G.SPELLINFO_SELF = {}
G.SPELLINFO_TARGET = {}
G.SPELLINFO_SCD = {}
G.ClassAltSpellName = {}
G.GC_IndexOfGroupFrame = {}
-----------------------------------------------------------------
G.EA_DEBUGFLAG1 = false
G.EA_DEBUGFLAG2 = false
G.EA_DEBUGFLAG3 = false
G.EA_DEBUGFLAG11= false
G.EA_DEBUGFLAG21= false

G.DEBUGFLAG1 	= false
G.DEBUGFLAG2 	= false
G.DEBUGFLAG3 	= false
G.DEBUGFLAG11 	= false
G.DEBUGFLAG21 	= false
-----------------------------------------------------------------
G.EA_DEBUGFLAG601 = false	--Deubg for
G.EA_DEBUGFLAG602 = false	--Deubg for
G.EA_DEBUGFLAG603 = false	--Deubg for
G.EA_DEBUGFLAG604 = false	--Deubg for
G.EA_DEBUGFLAG605 = false	--Deubg for
G.EA_DEBUGFLAG606 = false	--Deubg for
G.EA_DEBUGFLAG607 = false	--Deubg for
G.EA_DEBUGFLAG608 = false	--Deubg for
G.EA_DEBUGFLAG609 = false	--Deubg for
G.EA_DEBUGFLAG610 = false	--Deubg for
G.EA_DEBUGFLAG611 = false	--Deubg for
-----------------------------------------------------------------
-- EA_CurrentBuffs = {}
-- EA_TarCurrentBuffs = {}
-- EA_ScdCurrentBuffs = {}
EA_ShowScrollSpells = {}
EA_ShowScrollSpell_YPos = 25

G.EA_CurrentBuffs = {}
G.EA_TarCurrentBuffs = {}
G.EA_ScdCurrentBuffs = {}
G.EA_ShowScrollSpells = {}
G.EA_ShowScrollSpell_YPos = 25
-----------------------------------------------------------------
G.EA_LISTSEC_SELF = 0
G.EA_LISTSEC_TARGET = 0
-----------------------------------------------------------------
-- EA_SpecFrame_Self = false
-- EA_SpecFrame_Target = false
-- EA_SpecFrame_LifeBloom = { UnitID = "", UnitName = "", ExpireTime = 0, Stack = 0 }
-- EA_COMBO_POINTS = 0
-- EA_playerClass  = nil
-- EA_SpecID = nil

G.SpecFrame_Self = false
G.SpecFrame_Target = false
G.SpecFrame_LifeBloom = { UnitID = "", UnitName = "", ExpireTime = 0, Stack = 0 }
G.COMBO_POINTS = 0
G.playerClass  = nil
G.SpecID = nil

G.localizedPlayerClass, G.playerClass = UnitClass("player")

