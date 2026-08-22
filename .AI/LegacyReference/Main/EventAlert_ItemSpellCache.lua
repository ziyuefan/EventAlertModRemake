--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_ItemSpellCache.lua

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
G.WOW_VERSION = select(4,	GetBuildInfo())	-- Numric Version 
-----------------------------------
-- 檢查Lib_ZYF是否有先載入
--------------------------------
if (Lib_ZYF == nil ) then
	print("No Lib_ZYF loaded")	
	return
else
	print("Lib_ZYF loaded")
end
--------------------------------
-- 常用函數設為區域變數以提昇效能
--------------------------------
-- lua default command zone
local print = print
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local type = type
local table = table
local select = select
local collectgarbage = collectgarbage
local hooksecurefunc = hooksecurefunc
-- lua table zone
local tinsert = table.insert
local tsort = table.sort
local tremove = table.remove
local tconcat = table.concat
local tcopy = table.copy
local foreach = table.foreach

-- lua sting zone
local format = format
local strsplit = string.split
local strfind = string.find
local strmatch = string.match
local strgub = string.gsub
local strdump = string.dump
local stlen = string.len
local strlower = string.lower
local strupper = string.upper
local strchar = string.char
local strbyte = string.byte
local strgmatch = string.gmatch
local strrep = string.rep
local strreverse = string.reverse
local strsub = string.sub
-- WOW API zone
local GetAddOnMetadata = GetAddOnMetadata or C_AddOns.GetAddOnMetadata
local CreateFrame 	= CreateFrame
-- local UnitBuff 		= type(UnitBuff)=="function"	and UnitBuff 	or C_UnitAuras.GetBuffDataByIndex
-- local UnitDebuff 	= type(UnitDebuff)=="function"	and UnitDebuff 	or C_UnitAuras.GetDebuffDataByIndex
-- local UnitAura 		= type(UnitAura)=="function"	and UnitAura 	or C_UnitAuras.GetAuraDataByIndex
local UnitBuff 		= C_UnitAuras.GetBuffDataByIndex
local UnitDebuff 	= C_UnitAuras.GetDebuffDataByIndex
local UnitAura 		= C_UnitAuras.GetAuraDataByIndex
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitAffectingCombat = UnitAffectingCombat
local UnitLevel = UnitLevel
local UnitClass = UnitClass
local UnitSpellHaste = UnitSpellHaste
local UnitName = UnitName
local UnitIsCorpse = UnitIsCorpse
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsEnemy = UnitIsEnemy
local UnitInRaid = UnitInRaid
local UnitInParty = UnitInParty
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitExists = UnitExists
local GetTime = GetTime
local GetActiveSpecGroup = GetActiveSpecGroup


local GetInventoryItemCooldown 	= GetInventoryItemCooldown	
local GetInventoryItemID 		= GetInventoryItemID
local GetItemSpell 				= type(GetItemSpell)=="function"			and GetItemSpell 			or C_Item.GetItemSpell 
local GetItemCooldown			= type(GetItemCooldown)=="function"			and GetItemCooldown			or C_Item.GetItemCooldown
local GetContainerNumSlots 		= type(GetContainerNumSlots)=="function" 	and GetContainerNumSlots	or C_Container.GetContainerNumSlots
local GetContainerItemID 		= type(GetContainerItemID) == "function"  	and GetContainerItemID		or C_Container.GetContainerItemID
	
-- WOW API : ShapeshiftForm
local GetShapeshiftForm = GetShapeshiftForm
local GetShapeshiftFormID = GetShapeshiftFormID
-- WOW API : Specialization
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
-- WOW API : Spell
local GetSpellCharges 	= type(GetSpellCharges)=="function" 	and GetSpellCharges 	or C_Spell.GetSpellCharges
local GetSpellCooldown 	= type(GetSpellCooldown)=="function" 	and GetSpellCooldown 	or C_Spell.GetSpellCooldown
local GetSpellInfo 		= type(GetSpellInfo)=="function"		and GetSpellInfo 		or C_Spell.GetSpellInfo
local GetSpellLink 		= type(GetSpellLink)=="function"		and GetSpellLink 		or C_Spell.GetSpellLink
local GetSpellTexture 	= type(GetSpellTexture)=="function"		and GetSpellTexture 	or C_Spell.GetSpellTexture
local IsUsableSpell 	= type(IsUsableSpell)=="function"		and IsUsableSpell		or C_Spell.IsSpellUsable

local GetTotemInfo 		= GetTotemInfo
-- WOW API : Group
local GetNumSubgroupMembers = GetNumSubgroupMembers
-- WOW API : Widget
local UIParent = UIParent
local GameTooltip = GameTooltip
local UIFrameFadeIn = UIFrameFadeIn
local UIFrameFadeOut = UIFrameFadeOut
-- WOW API : System
local RegisterAllEvents = RegisterAllEvents
local RegisterEvent = RegisterEvent
local PlaySoundFile = PlaySoundFile
------------------------------------------------------------------
--以協程平滑獲取伺服器物品資料,避免卡頓
function G:CreateSpellItemCache()

     local max_itemID = 10^7-1
     local i	 
     for i = max_itemID, 1, -1 do
          if C_Item.DoesItemExistByID(i) then
               max_itemID = i
               break
          end
     end

     EA_Config.EA_SPELL_ITEM =  EA_Config.EA_SPELL_ITEM or (G.EA_SPELL_ITEM or {})
     -- 定義一個從伺服器獲取數據的協程
     local function getAllItemSpell()

          --為避免每次都重頭建立,所以以最後建立的ID開始搜尋, 直到全部搜尋完成
          local begin = EA_Config.EA_SPELL_ITEM.LastUpdate or 1
          local spellId, i

          for i = begin, max_itemID do

               _, spellId = GetItemSpell(i)

               if spellId then
                    EA_Config.EA_SPELL_ITEM[spellId] = i
                    EA_Config.EA_SPELL_ITEM.LastUpdate = i
               end
               coroutine.yield()
          end

          EA_Config.EA_SPELL_ITEM.LastUpdate = nil
          print("EAM Item map Spell Cache had created done!")
     end

     -- 創建一個定時器，每0.005秒執行一次 getAllItemSpell()
     local co = coroutine.create(getAllItemSpell)
     G.tickerGetItemSpell = C_Timer.NewTicker(0.01, function()

								 -- 如果協程已經結束，取消定時器
								 if coroutine.status(co) == "dead" then
									  G.tickerGetItemSpell:Cancel()
									  return
								 end

								 -- 恢復協程的執行，繼續獲取數據
								 coroutine.resume(co)
							 end)

     -- 啟動協程執行
     coroutine.resume(co)
end


--以ItemMixin獲取伺服器物品資料,避免卡頓
function G:CreateSpellItemCache2()

	 local DoesItemExistByID = C_Item.DoesItemExistByID
	 
     local max_itemID = 10^7-1
     local i	 
     for i = max_itemID, 1, -1 do
          if DoesItemExistByID(i) then
               max_itemID = i
               break
          end
     end

     EA_Config.EA_SPELL_ITEM =  EA_Config.EA_SPELL_ITEM or (G.EA_SPELL_ITEM or {})
	 
	 local objItem = {}
	 local begin = EA_Config.EA_SPELL_ITEM.LastUpdate or 1
     local spellId, i
	 for i = begin, max_itemID do
	 
		objItem[i] = Item:CreateFromItemID(i)		
		if objItem[i]:IsItemDataCached() then
			
			_, spellId = GetItemSpell(i)
			if spellId then
				EA_Config.EA_SPELL_ITEM[spellId] = i
                EA_Config.EA_SPELL_ITEM.LastUpdate = i
            end					

			if i == max_itemID then
				 EA_Config.EA_SPELL_ITEM.LastUpdate = nil
				 print("EAM Item map Spell Cache had created done!")
			end
			
			objItem[i] = nil
			
		else
			objItem[i]:ContinueOnItemLoad(function()			
			
						_, spellId = GetItemSpell(i)
						if spellId then
							EA_Config.EA_SPELL_ITEM[spellId] = i
							EA_Config.EA_SPELL_ITEM.LastUpdate = i
						end					

						if i == max_itemID then
							EA_Config.EA_SPELL_ITEM.LastUpdate = nil
							print("EAM Item map Spell Cache had created done!")
						end
						
						objItem[i] = nil
					end)
		end--if				
		
	 end--for

end

--ChatGPT版本
function G:CreateSpellItemCache3()
    local DoesItemExistByID = C_Item.DoesItemExistByID
    local max_itemID = 10^7 - 1
	
	local objItem = {}
	
    -- 找到最大的存在的物品 ID
    for i = max_itemID, 1, -1 do
        if DoesItemExistByID(i) then			
            max_itemID = i
            break
        end
    end
	
	--建立純索引陣列加快存取性能
	for i = 1, max_itemID do
		objItem[i] = nil
	end

    EA_Config.EA_SPELL_ITEM = EA_Config.EA_SPELL_ITEM or (G.EA_SPELL_ITEM or {})

    
    local begin = EA_Config.EA_SPELL_ITEM.LastUpdate or 1

    local itemsPerBatch = 10  -- 每批處理的物品數量
    local currentItem = begin

    local function ProcessBatch()
        local endItem = math.min(currentItem + itemsPerBatch - 1, max_itemID)

        for i = currentItem, endItem do
            local currentItemID = i
            objItem[currentItemID] = Item:CreateFromItemID(currentItemID)
            local item = objItem[currentItemID]

            if item:IsItemDataCached() then
                local _, spellId = GetItemSpell(currentItemID)
                if spellId then
                    EA_Config.EA_SPELL_ITEM[spellId] = currentItemID
                    EA_Config.EA_SPELL_ITEM.LastUpdate = currentItemID
                end

                objItem[currentItemID] = nil
            else
                item:ContinueOnItemLoad(function()
                    local _, spellId = GetItemSpell(currentItemID)
                    if spellId then
                        EA_Config.EA_SPELL_ITEM[spellId] = currentItemID
                        EA_Config.EA_SPELL_ITEM.LastUpdate = currentItemID
                    end
					
                    objItem[currentItemID] = nil
                end)
            end
        end

        if endItem < max_itemID then
            currentItem = endItem + 1
            C_Timer.After(1, ProcessBatch)  -- 延遲 0.01 秒後繼續處理下一批
        else
            EA_Config.EA_SPELL_ITEM.LastUpdate = nil
            print("EAM Item map Spell Cache had created done!")
            
        end
    end

    -- 開始處理
    ProcessBatch()
end

