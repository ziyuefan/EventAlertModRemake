--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_EAFun.lua

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
-----------------------------------------------------
-- EventAlertMod shared utility layer.
-- Rewritten as a compatibility facade: public names are kept, internals are
-- grouped by responsibility so the newer Aura/Cooldown modules can keep using
-- the same EAFun API while EAM is gradually split apart.
-----------------------------------------------------
local _
local _G = _G
local addonName, G = ...
_G[addonName] = _G[addonName] or G

if LibDebug then LibDebug() end

local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local type = type
local select = select
local format = format
local floor = math.floor
local ceil = math.ceil
local abs = math.abs
local max = math.max
local sin = math.sin
local cos = math.cos
local rad = math.rad
local tsort = table.sort
local tconcat = table.concat
local wipe = table.wipe or wipe or function(tbl)
    if type(tbl) == "table" then
        for key in pairs(tbl) do tbl[key] = nil end
    end
end
local strmatch = string.match
local strgmatch = string.gmatch
local strrep = string.rep
local strlower = string.lower

local CreateFrame = CreateFrame
local UIParent = UIParent
local GameTooltip = GameTooltip
local ItemRefTooltip = ItemRefTooltip
local StaticPopupDialogs = StaticPopupDialogs
local StaticPopup_Show = StaticPopup_Show
local GetBuildInfo = GetBuildInfo
local GetLocale = GetLocale
local hooksecurefunc = hooksecurefunc
local UnitName = UnitName
local UnitInRaid = UnitInRaid
local GetNumSubgroupMembers = GetNumSubgroupMembers
local GetInventoryItemID = GetInventoryItemID
local C_Spell = C_Spell
local C_Item = C_Item
local C_Container = C_Container
local C_UnitAuras = C_UnitAuras

local GetSpellInfo = type(GetSpellInfo) == "function" and GetSpellInfo or (C_Spell and C_Spell.GetSpellInfo)
local GetSpellLink = type(GetSpellLink) == "function" and GetSpellLink or (C_Spell and C_Spell.GetSpellLink)
local GetSpellTexture = type(GetSpellTexture) == "function" and GetSpellTexture or (C_Spell and C_Spell.GetSpellTexture)
local GetItemSpell = type(GetItemSpell) == "function" and GetItemSpell or (C_Item and C_Item.GetItemSpell)
local GetContainerItemID = type(GetContainerItemID) == "function" and GetContainerItemID or (C_Container and C_Container.GetContainerItemID)
local UnitAura = (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) or UnitAura

G.EAM = G.EAM or {}
G.TEST = G.TEST or {}
EA_TestLabel_EWMA_ALPHA = EA_TestLabel_EWMA_ALPHA or 0.2

local function SpellName(spellId)
    if not spellId or not GetSpellInfo then return "" end
    local info = GetSpellInfo(spellId)
    if type(info) == "table" then return info.name or "" end
    return info or ""
end

local function SpellTexture(spellId)
    if not spellId or not GetSpellTexture then return nil end
    return GetSpellTexture(spellId)
end

local function ItemSpell(itemId)
    if not itemId or not GetItemSpell then return nil, nil end
    return GetItemSpell(itemId)
end

local function AddTooltipLine(tooltip, left, right)
    if tooltip and left and right then
        tooltip:AddDoubleLine(left, right)
        tooltip:Show()
    end
end

local function FrameAppendSpellTipDirect(frame, spellId)
    if not frame or not spellId then return end
    if EA_Config and EA_Config.ICON_APPEND_SPELL_TIP == false then
        frame:EnableMouse(false)
        frame:SetScript("OnEnter", nil)
        frame:SetScript("OnLeave", nil)
        return
    end

    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(spellId)
        elseif GetSpellLink then
            local link = GetSpellLink(spellId)
            if link then GameTooltip:SetHyperlink(link) end
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function FrameAppendAuraTipDirect(frame, units, spellId, isDebuff)
    if not frame or not units or not spellId then return end
    if EA_Config and EA_Config.ICON_APPEND_SPELL_TIP == false then
        frame:EnableMouse(false)
        frame:SetScript("OnEnter", nil)
        frame:SetScript("OnLeave", nil)
        return
    end

    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        local filter = isDebuff and "HARMFUL" or "HELPFUL"
        for unit in strgmatch(tostring(units), "([^,]+)") do
            local unitId = strlower(unit)
            local index
            if isDebuff and G.GetDebuffIndexOfSpellID then
                index = G:GetDebuffIndexOfSpellID(unitId, spellId)
            elseif G.GetBuffIndexOfSpellID then
                index = G:GetBuffIndexOfSpellID(unitId, spellId)
            end
            if index then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetUnitAura(unitId, index, filter)
                GameTooltip:Show()
                return
            end
        end
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-----------------------------------------------------
-- Version/search scroll frame
-----------------------------------------------------
function G:EAFun_CreateVersionFrame_ScrollEditBox()
    if not EA_Version_Frame then return end

    local frameWidth = EA_Version_Frame:GetWidth() - 45
    local frameHeight = EA_Version_Frame:GetHeight() - 70

    local panel = _G.EA_Version_ScrollFrame
    if not panel then
        panel = CreateFrame("ScrollFrame", "EA_Version_ScrollFrame", EA_Version_Frame, "UIPanelScrollFrameTemplate")
    end

    local list = _G.EA_Version_ScrollFrame_List
    if not list then
        list = CreateFrame("Frame", "EA_Version_ScrollFrame_List", panel)
        panel:SetScrollChild(list)
        panel:SetPoint("TOPLEFT", EA_Version_Frame, "TOPLEFT", 15, -30)
        panel:SetSize(frameWidth, frameHeight)
        list:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        list:SetSize(frameWidth, frameHeight)
        panel:SetScript("OnVerticalScroll", function() end)
        panel:EnableMouse(true)
        panel:SetVerticalScroll(0)
        panel:SetHorizontalScroll(0)

        if Lib_ZYF and Lib_ZYF.SetBackdrop then
            Lib_ZYF:SetBackdrop(EA_Version_Frame, {
                bgFile = "Interface/DialogFrame/UI-DialogBox-Gold-Background",
                edgeFile = "",
                tile = false,
                tileSize = 1,
                edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
        end
    end

    local edit = _G.EA_Version_ScrollFrame_EditBox
    if not edit then
        edit = CreateFrame("EditBox", "EA_Version_ScrollFrame_EditBox", list)
        edit:SetPoint("TOPLEFT", 0, 0)
        edit:SetFontObject(G.FONT_OBJECT or ChatFontNormal)
        edit:SetSize(frameWidth, frameHeight)
        edit:SetMultiLine(true)
        edit:SetMaxLetters(0)
        edit:SetAutoFocus(false)
    end
end

function G:EAFun_AddSpellToScrollFrame(spellId, otherMessage)
    spellId = tonumber(spellId)
    if not spellId then return end

    EA_ShowScrollSpells = EA_ShowScrollSpells or {}
    EA_ShowScrollSpell_YPos = EA_ShowScrollSpell_YPos or 25
    otherMessage = otherMessage or ""

    if EA_ShowScrollSpells[spellId] then return end
    EA_ShowScrollSpells[spellId] = true

    self:EAFun_CreateVersionFrame_ScrollEditBox()
    if not _G.EA_Version_ScrollFrame_List then return end

    local y = EA_ShowScrollSpell_YPos - 25
    EA_ShowScrollSpell_YPos = y

    local iconFrame = _G["EA_Version_ScrollFrame_Icon_" .. spellId]
    if not iconFrame then
        iconFrame = CreateFrame("Frame", "EA_Version_ScrollFrame_Icon_" .. spellId, EA_Version_ScrollFrame_List)
        iconFrame.texture = iconFrame:CreateTexture(nil, "ARTWORK")
        iconFrame.texture:SetAllPoints(iconFrame)
        iconFrame:SetSize(25, 25)
    end
    iconFrame:SetPoint("TOPLEFT", 0, y)
    iconFrame.texture:SetTexture(SpellTexture(spellId))
    iconFrame:Show()

    local edit = _G["EA_Version_ScrollFrame_EditBox_" .. spellId]
    if not edit then
        edit = CreateFrame("EditBox", "EA_Version_ScrollFrame_EditBox_" .. spellId, EA_Version_ScrollFrame_List)
        edit:SetFontObject(G.FONT_OBJECT or ChatFontNormal)
        edit:SetSize((EA_Version_Frame and EA_Version_Frame:GetWidth() or 400) + 50, 25)
        edit:SetMaxLetters(0)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEnter", function(self)
            self:SetTextColor(0, 1, 1)
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(spellId) end
        end)
        edit:SetScript("OnLeave", function(self)
            self:SetTextColor(1, 1, 1)
            self:HighlightText(0, 0)
            self:ClearFocus()
            GameTooltip:Hide()
        end)
    end
    edit:SetPoint("TOPLEFT", 30, y)
    edit:SetText((SpellName(spellId) or "") .. " [" .. spellId .. "]" .. otherMessage)
    edit:Show()
end

function G:EAFun_ClearSpellScrollFrame()
    if EA_Version_Frame_HeaderText and EA_XCMD_DEBUG_P0 then
        EA_Version_Frame_HeaderText:SetText(EA_XCMD_DEBUG_P0)
    end
    if EA_Version_ScrollFrame_EditBox then EA_Version_ScrollFrame_EditBox:Hide() end

    EA_ShowScrollSpells = EA_ShowScrollSpells or {}
    for spellId in pairs(EA_ShowScrollSpells) do
        local icon = _G["EA_Version_ScrollFrame_Icon_" .. spellId]
        local edit = _G["EA_Version_ScrollFrame_EditBox_" .. spellId]
        if icon then icon:Hide() end
        if edit then edit:Hide() end
    end
    wipe(EA_ShowScrollSpells)
    EA_ShowScrollSpell_YPos = 25
end

-----------------------------------------------------
-- Saved-variable migration and small helpers
-----------------------------------------------------
function G:EAFun_ExtendExecution_4505(EAItems)
    EAItems = EAItems or {}
    for key in self:pairsByKeys(EAItems) do
        if EAItems[key] then EAItems[key].Execution = 0 end
    end
    return EAItems
end

function G:EAFun_ChangeSavedVariblesFormat_4505(EAItems, EASelf)
    EAItems = EAItems or {}
    for classKey in self:pairsByKeys(EAItems) do
        for spellKey, enabled in self:pairsByKeys(EAItems[classKey]) do
            EAItems[classKey][spellKey] = EASelf and { enable = enabled, self = true } or { enable = enabled }
        end
    end
    return EAItems
end

function G:EAFun_GetCountOfTable(EAItems)
    local count = 0
    if type(EAItems) == "table" then
        for _ in self:pairsByKeys(EAItems) do count = count + 1 end
    end
    return count
end

function G:EAFun_GetUnitIDByName(unitName)
    if not unitName or unitName == "" then return "" end

    if UnitInRaid and UnitInRaid("player") then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitName(unit) == unitName then return unit end
        end
    elseif GetNumSubgroupMembers and GetNumSubgroupMembers() > 0 then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitName(unit) == unitName then return unit end
        end
    end

    for _, unit in ipairs({ "mouseover", "target", "focus", "player", "pet" }) do
        if UnitName(unit) == unitName then return unit end
    end
    return ""
end

function G:EAFun_GetSpellItemEnable(EAItems)
    return type(EAItems) == "table" and EAItems.enable or false
end

function G:EAFun_CheckSpellConditionMatch(EA_count, EA_unitCaster, EAItems)
    local count = tonumber(EA_count) or 0
    local orderWtd = 1
    local stack = 1
    local selfOnly = false

    if type(EAItems) == "table" then
        stack = tonumber(EAItems.stack) or stack
        selfOnly = EAItems.self == true
        orderWtd = tonumber(EAItems.orderwtd) or orderWtd
    end

    if stack > 1 and count < stack then return false, orderWtd end
    if selfOnly and strlower(tostring(EA_unitCaster or "")) ~= "player" then return false, orderWtd end
    return true, orderWtd
end

function G:EAFun_CheckSpellConditionOverGrow(EA_count, EAItems)
    local count = tonumber(EA_count) or 0
    if count <= 0 then count = 1 end
    local overGrow = type(EAItems) == "table" and tonumber(EAItems.overgrow) or nil
    return overGrow and overGrow > 0 and overGrow <= count or false
end

function G:EAFun_GetSpellConditionRedSecText(EAItems)
    local red = type(EAItems) == "table" and tonumber(EAItems.redsectext) or nil
    return red and red >= 1 and red or -1
end

-----------------------------------------------------
-- Tooltip integration
-----------------------------------------------------
function G:EAFun_DealTooltips()
    if not TooltipDataProcessor or not Enum or not Enum.TooltipDataType then return end

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
        local id = data and data.id
        if id then AddTooltipLine(tooltip, tconcat({ "(EAM)", EX_XCLSALERT_SPELL or "SpellID:" }), id) end
    end)

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Macro, function(tooltip, data)
        local id = data and data.lines and data.lines[1] and data.lines[1].tooltipID
        if id then AddTooltipLine(tooltip, tconcat({ "(EAM)", EX_XCLSALERT_SPELL or "SpellID:" }), id) end
    end)

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, function(tooltip, data)
        local id = data and data.id
        if id then AddTooltipLine(tooltip, tconcat({ "(EAM)", EX_XCLSALERT_SPELL or "SpellID:" }), id) end

        if id and type(G.Auras) == "table" then
            for _, unitAuras in pairs(G.Auras) do
                for _, auraData in pairs(unitAuras) do
                    if auraData and auraData.spellId == id and auraData.sourceUnit then
                        AddTooltipLine(tooltip, "(EAM)Caster:", UnitName(auraData.sourceUnit) or auraData.sourceUnit)
                        return
                    end
                end
            end
        end
    end)

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        local itemID = data and data.id
        if itemID then AddTooltipLine(tooltip, "(EAM)ItemID:", itemID) end

        local name, spellId = ItemSpell(itemID)
        if spellId then
            G.EA_SPELL_ITEM = G.EA_SPELL_ITEM or {}
            G.EA_SPELL_ITEM[spellId] = itemID
            AddTooltipLine(tooltip, tconcat({ "(EAM)", EX_XCLSALERT_SPELL or "SpellID:" }), tconcat({ spellId, "(", name or "", ")" }))
        end
    end)

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        local guid = data and data.guid
        if not guid and type(data) == "table" then
            for _, val in ipairs(data) do
                if type(val) == "table" and val.field == "guid" then
                    guid = val.guidVal
                    break
                end
            end
        end
        if guid then AddTooltipLine(tooltip, "(EAM)GUID:", guid) end
    end)
end

function G:EAFun_HookTooltips()
    local function GetAuraSpellId(unitId, index, filter)
        if not UnitAura then return nil end
        local aura = UnitAura(unitId, index, filter)
        if type(aura) == "table" then return aura.spellId end
        return select(10, UnitAura(unitId, index, filter))
    end

    local function HookMethod(method, fn)
        if GameTooltip and GameTooltip[method] then
            hooksecurefunc(GameTooltip, method, fn)
        end
    end

    local function HookAura(method)
        HookMethod(method, function(self, unitId, index, filter)
            local spellId = GetAuraSpellId(unitId, index, filter)
            if spellId then
                AddTooltipLine(self, "(EAM)" .. (EX_XCLSALERT_SPELL or "SpellID:"), spellId .. "(" .. (UnitName(unitId) or unitId or "") .. ")")
            end
        end)
    end

    HookAura("SetUnitAura")
    HookAura("SetUnitBuff")
    HookAura("SetUnitDebuff")

    HookMethod("SetBagItem", function(self, bag, slot)
        local itemID = GetContainerItemID and GetContainerItemID(bag, slot)
        if itemID then AddTooltipLine(self, "(EAM)ItemID:", itemID) end
        local name, spellId = ItemSpell(itemID)
        if spellId then AddTooltipLine(self, tconcat({ "(EAM)", EX_XCLSALERT_SPELL or "SpellID:" }), tconcat({ spellId, "(", name or "", ")" })) end
    end)

    HookMethod("SetInventoryItem", function(self, unit, invslot)
        local itemID = GetInventoryItemID and GetInventoryItemID(unit, invslot)
        if itemID then AddTooltipLine(self, "(EAM)ItemID:", itemID) end
        local name, spellId = ItemSpell(itemID)
        if spellId then AddTooltipLine(self, tconcat({ "(EAM)", EX_XCLSALERT_SPELL or "SpellID:" }), tconcat({ spellId, "(", name or "", ")" })) end
    end)

    hooksecurefunc("SetItemRef", function(link)
        local spellId = tonumber(strmatch(link or "", "^spell:(%d+)"))
        local itemID = tonumber(strmatch(link or "", "item:(%d+)"))

        if spellId then
            AddTooltipLine(ItemRefTooltip, tconcat({ "(EAM)", EX_XCLSALERT_SPELL or "SpellID:" }), spellId)
            return
        end

        if itemID then
            AddTooltipLine(ItemRefTooltip, "(EAM)ItemID:", itemID)
            local name, itemSpellId = ItemSpell(itemID)
            if itemSpellId then
                AddTooltipLine(ItemRefTooltip, tconcat({ "(EAM)", EX_XCLSALERT_SPELL or "SpellID:" }), tconcat({ itemSpellId, "(", name or "", ")" }))
            end
        end
    end)

    if GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetSpell", function(self)
            local _, spellId = self:GetSpell()
            if spellId then AddTooltipLine(self, tconcat({ "(EAM)", EX_XCLSALERT_SPELL or "SpellID:" }), spellId) end
        end)
    end
end

-----------------------------------------------------
-- Sorting and group-event helpers
-----------------------------------------------------
function G:EAFun_SortCurrBuffs2(TypeIndex, EACurrBuffs)
    local infoTbl
    if TypeIndex == 1 then
        infoTbl = G.SPELLINFO_SELF
    elseif TypeIndex == 2 then
        infoTbl = G.SPELLINFO_TARGET
    elseif TypeIndex == 3 then
        infoTbl = G.SPELLINFO_SCD
    else
        return EACurrBuffs
    end

    self:SortByOrderWeight(EACurrBuffs, infoTbl, false)
    return EACurrBuffs
end

function G.EAFun_FireEventCheckHide(self)
    if not self or not self.GC or not self.GC.GroupResult then return end
    self:SetSize(0, 0)
    self.GC.GroupIconID = 0
    self.GC.GroupResult = false
    if self.spellName then self.spellName:SetText("") end
    self:Hide()
end

function G.EAFun_FireEventSubCheckResult(self, iSpells, iChecks)
    if not self or not self.GC or not self.GC.Spells then return end
    local spellCfg = self.GC.Spells[iSpells]
    local checkCfg = spellCfg and spellCfg.Checks and spellCfg.Checks[iChecks]
    if not checkCfg or not checkCfg.SubChecks then return end

    local checkResult = true
    for _, subCheck in ipairs(checkCfg.SubChecks) do
        if subCheck.SubCheckAndOp then
            checkResult = checkResult and subCheck.SubCheckResult
        else
            checkResult = checkResult or subCheck.SubCheckResult
        end
    end
    checkCfg.CheckResult = checkResult

    local spellResult = true
    for _, check in ipairs(spellCfg.Checks) do
        if check.CheckAndOp then
            spellResult = spellResult and check.CheckResult
        else
            spellResult = spellResult or check.CheckResult
        end
    end
    spellCfg.SpellResult = spellResult

    local groupResult, spellName, iconID, iconPath = false, "", 0, ""
    for _, spell in ipairs(self.GC.Spells) do
        if spell.SpellResult then
            groupResult = true
            spellName = spell.SpellName or ""
            iconID = spell.SpellIconID or 0
            iconPath = spell.SpellIconPath or SpellTexture(iconID)
            break
        end
    end

    if groupResult then
        if (G.WOW_VERSION or select(4, GetBuildInfo())) < 100000 and G.IsActiveTalentBySpellID then
            local active, row, col = G:IsActiveTalentBySpellID(iconID)
            if row and row > 0 and col and col > 0 and not active then
                G.EAFun_FireEventCheckHide(self)
                return
            end
        elseif C_Spell and C_Spell.DoesSpellExist and not C_Spell.DoesSpellExist(iconID) then
            G.EAFun_FireEventCheckHide(self)
            return
        end
    end

    if not groupResult then
        G.EAFun_FireEventCheckHide(self)
        return
    end

    if self.GC.GroupResult and self.GC.GroupIconID == iconID then return end
    self.GC.GroupIconID = iconID
    self.GC.GroupResult = true

    self.texture = self.texture or self:CreateTexture(nil, "ARTWORK")
    self.texture:SetAllPoints(self)
    self.texture:SetTexture(iconPath)
    if self.GC.IconAlpha then self:SetAlpha(self.GC.IconAlpha) end
    self:SetPoint(self.GC.IconPoint, UIParent, self.GC.IconRelatePoint, self.GC.LocX, self.GC.LocY)
    self:SetSize(self.GC.IconSize, self.GC.IconSize)

    if self.spellName then
        if EA_Config and EA_Config.ShowName == true then
            self.spellName:SetText(spellName)
            local font = self.spellName:GetFont()
            self.spellName:SetFont(font, EA_Config.SNameFontSize)
        else
            self.spellName:SetText("")
        end
    end

    self:Show()
    if self.GC.GlowWhenTrue ~= nil and G.FrameGlowShowOrHide then
        G:FrameGlowShowOrHide(self, self.GC.GlowWhenTrue)
    end
end

-----------------------------------------------------
-- Timer/stack text
-----------------------------------------------------
function G:EAFun_GetFormattedTime(timeLeft)
    local seconds = tonumber(timeLeft) or 0
    if seconds < 0 then seconds = 0 end

    if seconds <= 60 then
        if EA_Config and seconds < (EA_Config.UseFloatSec or 0) then
            return format("%.1f", seconds)
        end
        local build = GetBuildInfo and select(4, GetBuildInfo()) or 0
        return format("%d", build < 100000 and ceil(seconds) or floor(seconds))
    elseif seconds <= 3600 then
        return format("%d:%02d", floor(seconds / 60), floor(seconds % 60))
    end
    return format("%d:%02d:%02d", floor(seconds / 3600), floor((seconds % 3600) / 60), floor(seconds % 60))
end

function G:EAFun_ShorterNumberByLocale(n)
    local value = tonumber(n)
    if not value then return n end

    local locale = GetLocale and GetLocale() or ""
    if locale == "zhTW" then
        if value >= 10000 then return format("%.1f萬", value / 10000) end
    elseif locale == "zhCN" then
        if value >= 10000 then return format("%.1f万", value / 10000) end
    else
        if value >= 1000000 then return format("%.1fM", value / 1000000) end
        if value >= 1000 then return format("%.1fK", value / 1000) end
    end
    return value
end

function G:EAFun_SetCountdownStackText(eaf, EA_timeLeft, EA_count, SC_RedSecText)
    if not eaf or not eaf.spellTimer or not eaf.spellStack then return end

    local showTimer = not EA_Config or EA_Config.ShowTimer == true
    if showTimer then eaf.spellTimer:Show() else eaf.spellTimer:Hide() end

    local timeLeft = tonumber(EA_timeLeft) or 0
    local count = tonumber(EA_count) or 0
    local redSec = tonumber(SC_RedSecText) or -1
    if redSec <= 0 then redSec = -1 end

    eaf.spellTimer:ClearAllPoints()
    if EA_Config and EA_Config.ChangeTimer == true then
        eaf.spellTimer:SetPoint("CENTER", eaf, "CENTER", 0, 0)
    else
        eaf.spellTimer:SetPoint("BOTTOM", eaf, "TOP", 0, 0)
    end

    if timeLeft > 0 and showTimer then
        local targetSize = (EA_Config and EA_Config.TimerFontSize) or 25
        local font = G.FONTS or select(1, eaf.spellTimer:GetFont())
        local useRed = redSec > 0 and timeLeft < redSec + 1
        eaf.spellTimer:SetFont(font, useRed and targetSize * 1.1 or targetSize, "OUTLINE")
        if useRed then
            eaf.spellTimer:SetTextColor(1, 0, 0)
        else
            eaf.spellTimer:SetTextColor(1, 1, 1)
            eaf.spellTimer:SetShadowColor(0, 0, 0)
            eaf.spellTimer:SetShadowOffset(2, -2)
        end
        eaf.spellTimer:SetText(self:EAFun_GetFormattedTime(timeLeft))
    else
        eaf.spellTimer:SetText("")
    end

    eaf.spellStack:ClearAllPoints()
    if count > 1 then
        if EA_Config and EA_Config.ChangeTimer == true then
            eaf.spellStack:SetPoint("BOTTOMRIGHT", eaf, "BOTTOMRIGHT", -eaf:GetWidth() * 0.05, eaf:GetHeight() * 0.05)
            eaf.spellTimer:ClearAllPoints()
            eaf.spellTimer:SetPoint("BOTTOMRIGHT", eaf.spellStack, "TOPLEFT", eaf:GetWidth() * 0.1, -eaf:GetHeight() * 0.1)
        else
            eaf.spellStack:SetPoint("BOTTOMRIGHT", eaf, "BOTTOMRIGHT", -eaf:GetWidth() * 0.05, eaf:GetHeight() * 0.05)
        end
        eaf.spellStack:SetTextColor(1, 1, 0)
        eaf.spellStack:SetShadowColor(0, 0, 0)
        eaf.spellStack:SetShadowOffset(2, -2)
        eaf.spellStack:SetFont(G.FONTS or select(1, eaf.spellStack:GetFont()), (EA_Config and EA_Config.StackFontSize) or 15, "OUTLINE")
        eaf.spellStack:SetFormattedText("%d", count)
    else
        eaf.spellStack:SetText("")
    end
end

-----------------------------------------------------
-- Debug/export helpers
-----------------------------------------------------
function G:ShowCopyURLPopup(url)
    StaticPopupDialogs.COPY_URL_DIALOG = {
        text = "EventAlertMod site link at CurseForge :",
        button1 = "Close",
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(self)
            self.editBox:SetText(url or "")
            self.editBox:HighlightText()
            self.editBox:SetWidth(250)
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    }
    StaticPopup_Show("COPY_URL_DIALOG")
end

function G:TableToLuaString(tbl, indent)
    indent = indent or 0
    if type(tbl) ~= "table" then return tostring(tbl) end

    local out = { "{\n" }
    local spacing = strrep("    ", indent + 1)
    for key, value in pairs(tbl) do
        local keyStr = type(key) == "string" and format("[%q]", key) or format("[%s]", tostring(key))
        local valueStr
        if type(value) == "table" then
            valueStr = self:TableToLuaString(value, indent + 1)
        elseif type(value) == "string" then
            valueStr = format("%q", value)
        else
            valueStr = tostring(value)
        end
        out[#out + 1] = spacing .. keyStr .. " = " .. valueStr .. ",\n"
    end
    out[#out + 1] = strrep("    ", indent) .. "}"
    return tconcat(out)
end

function G:ShowTableInEditBox(tbl, rootKey)
    local luaString = 'EADef_Items["' .. tostring(rootKey or "") .. '"] = ' .. self:TableToLuaString(tbl) .. "\n"

    local frame = _G.MyEditBoxFrame
    if not frame then
        frame = CreateFrame("Frame", "MyEditBoxFrame", UIParent, "BasicFrameTemplateWithInset")
        frame:SetSize(600, 400)
        frame:SetPoint("CENTER")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
        scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, -50)

        local editBox = CreateFrame("EditBox", "MyEditBox", scrollFrame, "InputBoxTemplate")
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetSize(550, 300)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scrollFrame:SetScrollChild(editBox)

        local copyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        copyButton:SetSize(100, 25)
        copyButton:SetPoint("BOTTOM", 0, 10)
        copyButton:SetText("複製")
        copyButton:SetScript("OnClick", function()
            editBox:HighlightText()
            editBox:SetFocus()
        end)
    end

    _G.MyEditBox:SetText(luaString)
    _G.MyEditBox:HighlightText()
    frame:Show()
end

function G:DeepCopy(orig, copies)
    if type(orig) ~= "table" then return orig end
    copies = copies or {}
    if copies[orig] then return copies[orig] end

    local copy = {}
    copies[orig] = copy
    for k, v in pairs(orig) do
        copy[self:DeepCopy(k, copies)] = self:DeepCopy(v, copies)
    end
    return setmetatable(copy, getmetatable(orig))
end

function G:ConvertClassSpellListToDefaultFormat(className)
    if not className then return end
    local tmpDef = { [className] = {} }
    local mapTbl = {
        ITEMS = "EA_Items",
        ALTITEMS = "EA_AltItems",
        TARITEMS = "EA_TarItems",
        SCDITEMS = "EA_ScdItems",
        GRPITEMS = "EA_GrpItems",
    }

    for item, globalName in pairs(mapTbl) do
        local src = _G[globalName]
        tmpDef[className][item] = self:DeepCopy(src and src[className] or {})
    end
    self:ShowTableInEditBox(tmpDef[className], className)
end

-----------------------------------------------------
-- Layout/profiling helpers
-----------------------------------------------------
function G:PositionFrames_PiePipe(currentBuffs, baseFramePrefix, anchorPoint, offsetX, offsetY)
    currentBuffs = currentBuffs or {}
    local n = #currentBuffs
    if n == 0 then return end

    local radius = 80 + n * 8
    local angleStep = 2 * math.pi / n
    local anchor = anchorPoint or "CENTER"
    local baseX = offsetX or 0
    local baseY = offsetY or 0

    for i, spellId in ipairs(currentBuffs) do
        local frame = _G[(baseFramePrefix or "") .. tostring(spellId)]
        if frame then
            local angle = (i - 1) * angleStep - math.pi / 2
            self:SetPointIfDiff(frame, "CENTER", UIParent, anchor, cos(angle) * radius + baseX, sin(angle) * radius + baseY)
        end
    end
end

function G:PositionFrames_PiePipe_Safe(list, prefix, anchor, baseX, baseY, opts)
    list = list or {}
    prefix = prefix or "EAScdFrame_"
    anchor = anchor or "CENTER"
    baseX = baseX or 0
    baseY = baseY or 0
    opts = opts or {}

    local n = #list
    if n == 0 then return end

    local iconSize = EA_Config and EA_Config.IconSize or 40
    local radius = opts.radius or (EA_Config and EA_Config.SCD_PipeRadius) or max(iconSize * 1.25, 60)
    local rangeDeg = opts.rangeDeg or (EA_Config and EA_Config.SCD_PipeRangeWidth) or 120
    local startDeg = opts.startDeg or (-rangeDeg * 0.5)
    local clockwise = opts.clockwise == true
    local anchorPoint = opts.anchorPoint or "CENTER"

    if n == 1 then
        local frame = _G[prefix .. tostring(list[1])]
        if frame then self:SetPointIfDiff(frame, anchorPoint, UIParent, anchor, baseX, baseY) end
        return
    end

    local step = rangeDeg / (n - 1)
    for i = 1, n do
        local frame = _G[prefix .. tostring(list[i])]
        if frame then
            local deg = startDeg + (i - 1) * step
            if clockwise then deg = -deg end
            local r = rad(deg)
            self:SetPointIfDiff(frame, anchorPoint, UIParent, anchor, baseX + radius * cos(r), baseY + radius * sin(r))
        end
    end
end

function G:EAFun_testLabel(label, startTime, endTime)
    if not label then return end
    local rec = G.TEST[label]
    if not rec then
        rec = { count = 0, ticker = 0, average = 0 }
        G.TEST[label] = rec
    end

    local dt = (endTime or 0) - (startTime or 0)
    if dt ~= dt or dt < 0 then dt = 0 end

    local n = rec.count + 1
    rec.count = n
    rec.ticker = rec.ticker + dt
    rec.average = rec.average + (dt - rec.average) / n
    rec.last = dt
    rec.min = rec.min and (dt < rec.min and dt or rec.min) or dt
    rec.max = rec.max and (dt > rec.max and dt or rec.max) or dt

    local alpha = EA_TestLabel_EWMA_ALPHA
    if alpha and alpha > 0 and alpha < 1 then
        rec.ewma = rec.ewma and (alpha * dt + (1 - alpha) * rec.ewma) or dt
    end
end

function G:SetPointIfDiff(frame, point, relativeTo, relativePoint, x, y)
    if not frame then return false end
    local rel = type(relativeTo) == "string" and _G[relativeTo] or (relativeTo or UIParent)
    local p, rTo, rP, ox, oy = frame:GetPoint(1)
    if p ~= point or rTo ~= rel or rP ~= relativePoint or ox ~= x or oy ~= y then
        frame:ClearAllPoints()
        frame:SetPoint(point, rel, relativePoint, x or 0, y or 0)
        if not frame:IsShown() then frame:Show() end
        return true
    end
    if not frame:IsShown() then frame:Show() end
    return false
end

function G:SetSizeIfDiff(frame, w, h)
    if not frame then return false end
    local cw, ch = frame:GetSize()
    if cw ~= w or ch ~= h then
        frame:SetSize(w, h)
        return true
    end
    return false
end

function G:EnsureTexture(eaf, icon)
    if not eaf then return nil end
    local tex = eaf.texture
    if not tex then
        tex = eaf:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints(eaf)
        eaf.texture = tex
        eaf._lastIcon = nil
    end
    if icon and eaf._lastIcon ~= icon then
        tex:SetTexture(icon)
        eaf._lastIcon = icon
    end
    return tex
end

function G:LayoutSelf_Classic(list, prefix)
    local t0 = debugprofilestop()
    list = list or {}
    prefix = prefix or "EAFrame_"

    local isTarget = prefix == "EATarFrame_"
    local anchor = (EA_Position and (isTarget and EA_Position.TarAnchor or EA_Position.Anchor)) or "CENTER"
    local baseX = (EA_Position and (isTarget and EA_Position.Tar_xOffset or EA_Position.xLoc)) or 0
    local baseY = (EA_Position and (isTarget and EA_Position.Tar_yOffset or EA_Position.yLoc)) or 0
    local xStep = 100 + ((EA_Position and EA_Position.xOffset) or 0)
    local yStep = 0 + ((EA_Position and EA_Position.yOffset) or 0)
    local maxPerRow = tonumber(EA_Config and EA_Config.NewLineByIconCount) or 0
    local twoRows = EA_Position and EA_Position.Tar_NewLine == true
    local rowStep = yStep ~= 0 and yStep or -abs(xStep)
    local infoTbl = isTarget and G.SPELLINFO_TARGET or G.SPELLINFO_SELF

    local buffs, debuffs = list, nil
    if twoRows then
        buffs, debuffs = {}, {}
        for i = 1, #list do
            local id = tonumber(list[i])
            local info = id and infoTbl and infoTbl[id]
            if info and info.isDebuff then debuffs[#debuffs + 1] = id else buffs[#buffs + 1] = id end
        end
    end

    local function LayoutRow(rowList, startX, startY)
        for i = 1, #rowList do
            local frame = _G[prefix .. tostring(rowList[i])]
            if frame then
                local idx = i - 1
                local col = maxPerRow > 0 and (idx % maxPerRow) or idx
                local row = maxPerRow > 0 and floor(idx / maxPerRow) or 0
                self:SetPointIfDiff(frame, "CENTER", UIParent, anchor, startX + col * xStep, startY + row * rowStep + (maxPerRow <= 0 and idx * yStep or 0))
            end
        end
    end

    LayoutRow(buffs, baseX, baseY)
    if debuffs then LayoutRow(debuffs, baseX, baseY + rowStep) end
    self:EAFun_testLabel("LayoutSelf_Classic", t0, debugprofilestop())
end

function G:PositionFrames_SelfAuto(list, prefix)
    prefix = prefix or "EAFrame_"
    local isTarget = prefix == "EATarFrame_"
    local usePie = (EA_Config and EA_Config.Self_PipeRange ~= nil) and EA_Config.Self_PipeRange or (EA_Config and EA_Config.SCD_PipeRange)

    if usePie then
        return self:PositionFrames_PiePipe_Safe(
            list or {},
            prefix,
            EA_Position and (isTarget and EA_Position.TarAnchor or EA_Position.Anchor) or "CENTER",
            EA_Position and (isTarget and EA_Position.Tar_xOffset or EA_Position.xLoc) or 0,
            EA_Position and (isTarget and EA_Position.Tar_yOffset or EA_Position.yLoc) or 0
        )
    end
    return self:LayoutSelf_Classic(list or {}, prefix)
end

function G:GetLayoutContextByIndex(idx)
    if idx == 1 then
        return {
            type = "SELF",
            prefix = "EAFrame_",
            list = G.EA_CurrentBuffs or {},
            infoTbl = G.SPELLINFO_SELF or {},
            weightAsc = false,
        }
    elseif idx == 2 then
        return {
            type = "TARGET",
            prefix = "EATarFrame_",
            list = G.EA_TarCurrentBuffs or {},
            infoTbl = G.SPELLINFO_TARGET or {},
            weightAsc = false,
        }
    elseif idx == 3 then
        return {
            type = "SCD",
            prefix = "EAScdFrame_",
            list = G.EA_ScdCurrentBuffs or {},
            infoTbl = G.SPELLINFO_SCD or {},
            weightAsc = false,
        }
    end
    return nil
end

function G:CompactIdList(list, infoTbl)
    local out = {}
    if type(list) ~= "table" then return out end
    for i = 1, #list do
        local id = tonumber(list[i])
        if id and infoTbl and infoTbl[id] then out[#out + 1] = id end
    end
    return out
end

function G:SortByOrderWeight(list, infoTbl, asc)
    if type(list) ~= "table" or #list < 2 then return end
    tsort(list, function(a, b)
        local ia = tonumber(a)
        local ib = tonumber(b)
        local wa = (ia and infoTbl and infoTbl[ia] and tonumber(infoTbl[ia].orderwtd)) or 1
        local wb = (ib and infoTbl and infoTbl[ib] and tonumber(infoTbl[ib].orderwtd)) or 1
        if wa ~= wb then
            return asc and wa < wb or wa > wb
        end
        if ia and ib then return ia < ib end
        return tostring(a) < tostring(b)
    end)
end

function G:DoLayoutByIndex(ctx)
    if not ctx then return end
    if ctx.type == "SCD" then
        if self.PositionFrames_ScdAuto then
            return self:PositionFrames_ScdAuto(ctx.list, ctx.prefix)
        end
        return self:PositionFrames_PiePipe(ctx.list, ctx.prefix, EA_Position and EA_Position.ScdAnchor or "CENTER", EA_Position and EA_Position.Scd_xOffset or 0, EA_Position and EA_Position.Scd_yOffset or 0)
    end
    return self:PositionFrames_SelfAuto(ctx.list, ctx.prefix)
end

function G:PostUpdateIconAndTip(ctx)
    if not ctx then return end
    local iconSize = (EA_Config and EA_Config.IconSize) or 45

    for i = 1, #ctx.list do
        local id = tonumber(ctx.list[i])
        local info = id and ctx.infoTbl and ctx.infoTbl[id]
        local frame = id and _G[ctx.prefix .. id]
        if frame and info then
            local tex = self:EnsureTexture(frame, info.icon or (ctx.type == "SCD" and SpellTexture(id)))
            self:SetSizeIfDiff(frame, iconSize, iconSize)

            if tex then
                if ctx.type == "SCD" then
                    tex:SetVertexColor(1, 1, 1)
                elseif info.isDebuff and ctx.type == "TARGET" then
                    local green = EA_Position and EA_Position.GreenDebuff or 0.5
                    tex:SetVertexColor(green, 1, green)
                elseif info.isDebuff then
                    local red = EA_Position and EA_Position.RedDebuff or 0.5
                    tex:SetVertexColor(1, red, red)
                else
                    tex:SetVertexColor(1, 1, 1)
                end
            end

            if ctx.type == "SCD" then
                local kind, raw = info._kind, info._rawid
                if not kind or not raw then
                    if id >= 200000000 then
                        kind, raw = "slot", id - 200000000
                    elseif id >= 100000000 then
                        kind, raw = "item", id - 100000000
                    else
                        kind, raw = "spell", id
                    end
                end
                self:_BindTip_Safe(frame, kind, raw)
            elseif ctx.type == "TARGET" then
                self:_BindTip_Safe(frame, "aura", "target", id, info.isDebuff)
            else
                self:_BindTip_Safe(frame, "aura", "player,pet", id, info.isDebuff)
            end
        end
    end
end

function G:EA_PositionFramesByIndex(idx)
    local t0 = debugprofilestop()
    local ctx = self:GetLayoutContextByIndex(idx)
    if not ctx then return end

    if G.EA_flagAllHidden == true then
        if EA_Main_Frame then EA_Main_Frame:SetAlpha(0) end
        return
    elseif EA_Main_Frame then
        EA_Main_Frame:SetAlpha(1)
    end

    if idx == 1 and EA_Config and EA_Config.ShowFrame == true and EA_Main_Frame and EA_Position then
        EA_Main_Frame:ClearAllPoints()
        EA_Main_Frame:SetPoint(EA_Position.Anchor or "CENTER", UIParent, EA_Position.relativePoint or "CENTER", EA_Position.xLoc or 0, EA_Position.yLoc or 0)
    end

    local compact = self:CompactIdList(ctx.list, ctx.infoTbl)
    wipe(ctx.list)
    for i = 1, #compact do ctx.list[i] = compact[i] end
    self:SortByOrderWeight(ctx.list, ctx.infoTbl, ctx.weightAsc)
    self:DoLayoutByIndex(ctx)
    self:PostUpdateIconAndTip(ctx)
    self:EAFun_testLabel("EA_PositionFramesByIndex(" .. tostring(idx) .. ")", t0, debugprofilestop())
end

function G:_BindTip_Safe(frame, kind, a, b, c)
    if not frame or not kind then return end
    local sig = tconcat({ kind, ":", tostring(a), ":", tostring(b), ":", tostring(c) })
    if frame._tipSig == sig then return end
    frame._tipSig = sig
    frame.appendtip = nil
    frame:SetScript("OnEnter", nil)
    frame:SetScript("OnLeave", nil)

    if kind == "aura" then
        FrameAppendAuraTipDirect(frame, a, b, c)
    elseif kind == "spell" then
        FrameAppendSpellTipDirect(frame, a)
    elseif kind == "item" then
        self:FrameAppendItemTip(frame, a)
    elseif kind == "slot" then
        self:FrameAppendInvSlotTip(frame, a)
    end
end

function G:FrameAppendItemTip(frame, itemID)
    if not frame or not itemID then return end
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(itemID) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function G:FrameAppendInvSlotTip(frame, slot)
    if not frame or not slot then return end
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player", slot)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
