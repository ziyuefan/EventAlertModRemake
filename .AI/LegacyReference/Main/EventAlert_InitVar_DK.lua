--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_InitVar_DK.lua

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

if LibDebug then LibDebug() end
-- -----------------------------------
-- EA_RUNE_TYPE = 1
-- -----------------------------------------------------------------
		-- RUNETYPE_BLOOD = 1
		-- RUNETYPE_FROST = 2
		-- RUNETYPE_UNHOLY = 3
		-- RUNETYPE_DEATH = 4		
		
		-- MAX_RUNES = 6
 
 
		-- iconTextures = {}
		-- iconTextures[RUNETYPE_BLOOD] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Blood"
		-- iconTextures[RUNETYPE_UNHOLY] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Unholy"
		-- iconTextures[RUNETYPE_FROST] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Frost"
		-- iconTextures[RUNETYPE_DEATH] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death"
		
		-- --[[
		-- runeTextures = {
		-- [RUNETYPE_BLOOD] = "Interface\\PlayerFrame\\UI-PlayerFrame-DeathKnight-Blood-Off.tga",
		-- [RUNETYPE_UNHOLY] = "Interface\\PlayerFrame\\UI-PlayerFrame-DeathKnight-Death-Off.tga",
		-- [RUNETYPE_FROST] = "Interface\\PlayerFrame\\UI-PlayerFrame-DeathKnight-Frost-Off.tga",
		-- [RUNETYPE_DEATH] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Chromatic-Off.tga",
		-- } 
		-- ]]--
		
		-- runeTextures = {
			-- [RUNETYPE_BLOOD] = "interface\\playerframe\\classoverlaydeathknightrunes.blp",
			-- [RUNETYPE_UNHOLY] = "interface\\playerframe\\classoverlaydeathknightrunes.blp",
			-- [RUNETYPE_FROST] = "interface\\playerframe\\classoverlaydeathknightrunes.blp",
			-- [RUNETYPE_DEATH] = "interface\\playerframe\\classoverlaydeathknightrunes.blp",
			-- } 
		
		-- runeSetTexCoord = {		
			-- [RUNETYPE_BLOOD] = {minX = 0.01+0, maxX = 0.01+1/4 ,minY = 0 ,maxY = 1/4 },
			-- [RUNETYPE_UNHOLY] = {minX = 0.01+0, maxX = 0.01+1/4 ,minY = 0.02+2/4 ,maxY = 0.02+3/4 },
			-- [RUNETYPE_FROST] = {minX = 0.025+1/4, maxX = 0.025+2/4 ,minY = 0.005+0 ,maxY = 0.005+1/4 },
			-- [RUNETYPE_DEATH] = {minX = 0.025+1/4, maxX = 0.025+2/4 ,minY = 0.005+1/4 ,maxY = 0.005+2/4 },
			-- } 
 
		-- runeEnergizeTextures = {
		-- [RUNETYPE_BLOOD] = "Interface\\PlayerFrame\\Deathknight-Energize-Blood",
		-- [RUNETYPE_UNHOLY] = "Interface\\PlayerFrame\\Deathknight-Energize-Unholy",
		-- [RUNETYPE_FROST] = "Interface\\PlayerFrame\\Deathknight-Energize-Frost",
		-- [RUNETYPE_DEATH] = "Interface\\PlayerFrame\\Deathknight-Energize-White",
		-- }
 
		-- runeColors = {
		-- [RUNETYPE_BLOOD] = {1, 0, 0},
		-- [RUNETYPE_UNHOLY] = {0, 0.5, 0},
		-- [RUNETYPE_FROST] = {0, 1, 1},
		-- [RUNETYPE_DEATH] = {0.8, 0.1, 1},
		-- }
		
		-- runeTypeText = {
		-- [RUNETYPE_BLOOD] = "血魄",
		-- [RUNETYPE_UNHOLY] = "穢邪",
		-- [RUNETYPE_FROST] = "冰霜",
		-- [RUNETYPE_DEATH] = "死亡",
		-- }
		
		-- RUNE_MAPPING = {
		-- [1] = 1,
		-- [2] = 2,
		-- [3] = 5,
		-- [4] = 6,
		-- [5] = 3,
		-- [6] = 4,
		-- }
-----------------------------------------------------------------	

G.RUNE_TYPE = 1
-----------------------------------------------------------------
		G.RUNETYPE_BLOOD = 1
		G.RUNETYPE_FROST = 2
		G.RUNETYPE_UNHOLY = 3
		G.RUNETYPE_DEATH = 4		
		
		G.MAX_RUNES = 6 
 
		G.iconTextures = {}
		G.iconTextures[G.RUNETYPE_BLOOD] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Blood"
		G.iconTextures[G.RUNETYPE_UNHOLY] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Unholy"
		G.iconTextures[G.RUNETYPE_FROST] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Frost"
		G.iconTextures[G.RUNETYPE_DEATH] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death"
		
		--[[
		runeTextures = {
		[RUNETYPE_BLOOD] = "Interface\\PlayerFrame\\UI-PlayerFrame-DeathKnight-Blood-Off.tga",
		[RUNETYPE_UNHOLY] = "Interface\\PlayerFrame\\UI-PlayerFrame-DeathKnight-Death-Off.tga",
		[RUNETYPE_FROST] = "Interface\\PlayerFrame\\UI-PlayerFrame-DeathKnight-Frost-Off.tga",
		[RUNETYPE_DEATH] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Chromatic-Off.tga",
		} 
		]]--
		
		G.runeTextures = {
			[G.RUNETYPE_BLOOD] = "interface\\playerframe\\classoverlaydeathknightrunes.blp",
			[G.RUNETYPE_UNHOLY] = "interface\\playerframe\\classoverlaydeathknightrunes.blp",
			[G.RUNETYPE_FROST] = "interface\\playerframe\\classoverlaydeathknightrunes.blp",
			[G.RUNETYPE_DEATH] = "interface\\playerframe\\classoverlaydeathknightrunes.blp",
			} 
		
		G.runeSetTexCoord = {		
			[G.RUNETYPE_BLOOD] = {minX = 0.01+0, maxX = 0.01+1/4 ,minY = 0 ,maxY = 1/4 },
			[G.RUNETYPE_UNHOLY] = {minX = 0.01+0, maxX = 0.01+1/4 ,minY = 0.02+2/4 ,maxY = 0.02+3/4 },
			[G.RUNETYPE_FROST] = {minX = 0.025+1/4, maxX = 0.025+2/4 ,minY = 0.005+0 ,maxY = 0.005+1/4 },
			[G.RUNETYPE_DEATH] = {minX = 0.025+1/4, maxX = 0.025+2/4 ,minY = 0.005+1/4 ,maxY = 0.005+2/4 },
			} 
 
		G.runeEnergizeTextures = {
			[G.RUNETYPE_BLOOD] = "Interface\\PlayerFrame\\Deathknight-Energize-Blood",
			[G.RUNETYPE_UNHOLY] = "Interface\\PlayerFrame\\Deathknight-Energize-Unholy",
			[G.RUNETYPE_FROST] = "Interface\\PlayerFrame\\Deathknight-Energize-Frost",
			[G.RUNETYPE_DEATH] = "Interface\\PlayerFrame\\Deathknight-Energize-White",
			}
 
		G.runeColors = {
			[G.RUNETYPE_BLOOD] = {1, 0, 0},
			[G.RUNETYPE_UNHOLY] = {0, 0.5, 0},
			[G.RUNETYPE_FROST] = {0, 1, 1},
			[G.RUNETYPE_DEATH] = {0.8, 0.1, 1},
			}
		
		G.runeTypeText = {
			[G.RUNETYPE_BLOOD] = "血魄",
			[G.RUNETYPE_UNHOLY] = "穢邪",
			[G.RUNETYPE_FROST] = "冰霜",
			[G.RUNETYPE_DEATH] = "死亡",
			}
		
		G.RUNE_MAPPING = {
			[1] = 1,
			[2] = 2,
			[3] = 5,
			[4] = 6,
			[5] = 3,
			[6] = 4,
			}
-----------------------------------------------------------------	