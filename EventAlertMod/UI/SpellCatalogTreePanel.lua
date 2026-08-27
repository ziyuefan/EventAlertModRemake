--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/SpellCatalogTreePanel
檔案: UI\SpellCatalogTreePanel.lua

理念:
- 提供階層式全量法術庫與智慧預設面板（三態勾選樹）。
- 支援選擇目標模組清單（技能冷卻、自身光環、目標光環、特殊光環、地面效果）。
- 支援「依當前天賦自動勾選」一鍵同步與多維戰術情境範本套用。

責任:
- 呈現職業、專精、戰術分類（爆發/減傷/控場/地面）與英雄天賦之樹狀結構。
- 支援法術一鍵批次加入/移除至指定模組清單。
- 整合 SpellBookScannerService 動態探測。

邊界:
- 戰鬥中不開啟或變更結構。
- 所有法術啟用狀態透過 SavedVariables 與 GroupService 提交。
--]]
local _, EAM = ...

local api = EAM.API or {}
local Theme = EAM.Theme
local Locale = EAM.Locale
local Util = EAM.Util or {}

local Panel = {
    frame = nil,
    treeRows = {},
    controls = {},
    searchQuery = "",
    targetModule = "spellCooldowns", -- "spellCooldowns" | "playerAuras" | "targetAuras" | "specialAuras" | "groundEffects"
    expandedNodes = {}, -- [nodeKey] = bool
}
EAM.UI.SpellCatalogTreePanel = Panel

local function inCombat()
    if not api.InCombatLockdown then
        return false
    end
    local ok, combat = pcall(api.InCombatLockdown)
    return ok and combat == true
end

local function getSpellHeuristics()
    return EAM.Data and EAM.Data.SpellHeuristics
end

local function getScannerService()
    return EAM.Services and EAM.Services.SpellBookScannerService
end

local function getSavedVariables()
    return EAM.Modules and EAM.Modules.SavedVariables
end

local function localized(key, fallback)
    if EAM.L and EAM.L[key] then
        return EAM.L[key]
    end
    return fallback or key
end

local function getSpellDisplayInfo(sid)
    local sInfoService = EAM.Services and EAM.Services.SpellInfoService
    if sInfoService and sInfoService.getSpellInfo then
        local record = sInfoService.getSpellInfo(sid)
        if type(record) == "table" and record.name then
            return tostring(record.name), record.icon or 134400
        end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, sid)
        if ok and type(info) == "table" and info.name then
            return tostring(info.name), info.iconID or 134400
        end
    end
    return "Spell " .. tostring(sid), 134400
end

local MODULE_OPTIONS = {
    { id = "spellCooldowns", textKey = "EAM_CATALOG_MOD_COOLDOWNS", fallback = "技能冷卻" },
    { id = "playerAuras", textKey = "EAM_CATALOG_MOD_PLAYER_AURAS", fallback = "自身光環" },
    { id = "targetAuras", textKey = "EAM_CATALOG_MOD_TARGET_AURAS", fallback = "目標光環" },
    { id = "specialAuras", textKey = "EAM_CATALOG_MOD_SPECIAL_AURAS", fallback = "特殊光環" },
    { id = "groundEffects", textKey = "EAM_CATALOG_MOD_GROUND", fallback = "地面效果" },
}

local function getModuleName(modId)
    for _, opt in ipairs(MODULE_OPTIONS) do
        if opt.id == modId then
            return localized(opt.textKey, opt.fallback)
        end
    end
    return modId
end

local function addSpellToTargetModule(sv, sid)
    if not sv then return end
    local mod = Panel.targetModule or "spellCooldowns"
    if mod == "playerAuras" then
        if sv.addAuraAlert then sv.addAuraAlert("player", sid, { enabled = true, fromPlayer = true }) end
    elseif mod == "targetAuras" then
        if sv.addAuraAlert then sv.addAuraAlert("target", sid, { enabled = true, fromPlayer = true }) end
    elseif mod == "specialAuras" then
        if sv.addAuraAlert then sv.addAuraAlert("special", sid, { enabled = true, fromPlayer = false }) end
    elseif mod == "groundEffects" then
        if sv.addGroundEffectAlert then sv.addGroundEffectAlert(sid, { enabled = true, durationMode = "AUTO" }) end
    else
        if sv.addSpellCooldownAlert then sv.addSpellCooldownAlert(sid, { enabled = true }) end
    end
end

local function removeSpellFromTargetModule(sv, sid)
    if not sv then return end
    local mod = Panel.targetModule or "spellCooldowns"
    if mod == "playerAuras" then
        if sv.removeAuraAlert then sv.removeAuraAlert("player", sid) end
    elseif mod == "targetAuras" then
        if sv.removeAuraAlert then sv.removeAuraAlert("target", sid) end
    elseif mod == "specialAuras" then
        if sv.removeAuraAlert then sv.removeAuraAlert("special", sid) end
    elseif mod == "groundEffects" then
        if sv.removeGroundEffectAlert then sv.removeGroundEffectAlert(sid) end
    else
        if sv.removeSpellCooldownAlert then sv.removeSpellCooldownAlert(sid) end
    end
end

-- 建立面板 Frame
local function createPanel()
    if Panel.frame then
        return Panel.frame
    end

    local frame = CreateFrame("Frame", "EAM_SpellCatalogTreeFrame", UIParent, "BackdropTemplate")
    frame:SetSize(650, 560)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    if Theme and Theme.applyContainerBackground then
        Theme.applyContainerBackground(frame)
    else
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
    end

    -- 標題
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
    Locale.bindText(title, "EAM_CATALOG_TREE_TITLE", "★ 全量法術庫與智慧預設")
    Panel.controls.title = title

    local subTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subTitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    Locale.bindText(subTitle, "EAM_CATALOG_TREE_SUBTITLE", "以階層樹狀檢視全職業核心技能，支援自選目標模組、戰術分類與依天賦智慧同步")

    -- 搜尋框
    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("TOPLEFT", subTitle, "BOTTOMLEFT", 0, -12)
    Locale.bindText(searchLabel, "EAM_SEARCH_LABEL", "搜尋:")

    local searchEdit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchEdit:SetSize(110, 20)
    searchEdit:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
    searchEdit:SetAutoFocus(false)
    searchEdit:SetScript("OnTextChanged", function(self)
        Panel.searchQuery = self:GetText():lower()
        Panel.refresh()
    end)
    Panel.controls.searchEdit = searchEdit

    -- 目標模組下拉選單 (Target Module List Dropdown)
    local modDropdown = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    modDropdown:SetSize(140, 22)
    modDropdown:SetPoint("LEFT", searchEdit, "RIGHT", 10, 0)
    if Theme and Theme.registerButton then Theme.registerButton(modDropdown) end
    Panel.controls.modDropdown = modDropdown

    local modMenu = CreateFrame("Frame", "EAM_CatalogModMenu", frame, "BackdropTemplate")
    modMenu:SetSize(140, #MODULE_OPTIONS * 24 + 8)
    modMenu:SetPoint("TOPLEFT", modDropdown, "BOTTOMLEFT", 0, -2)
    modMenu:SetFrameStrata("TOOLTIP")
    modMenu:SetClampedToScreen(true)
    modMenu:Hide()
    if Theme and Theme.applyContainerBackground then
        Theme.applyContainerBackground(modMenu, true)
    end
    Panel.controls.modMenu = modMenu

    for idx, opt in ipairs(MODULE_OPTIONS) do
        local mBtn = CreateFrame("Button", nil, modMenu, "UIPanelButtonTemplate")
        mBtn:SetSize(130, 20)
        mBtn:SetPoint("TOPLEFT", modMenu, "TOPLEFT", 5, -4 - (idx - 1) * 24)
        mBtn:SetText(localized(opt.textKey, opt.fallback))
        if Theme and Theme.registerButton then Theme.registerButton(mBtn) end
        mBtn:SetScript("OnClick", function()
            Panel.targetModule = opt.id
            modMenu:Hide()
            Panel.refresh()
        end)
    end

    modDropdown:SetScript("OnClick", function()
        if modMenu:IsShown() then
            modMenu:Hide()
        else
            modMenu:Show()
        end
    end)

    -- 智慧同步按鈕：依當前天賦自動勾選
    local syncBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    syncBtn:SetSize(140, 22)
    syncBtn:SetPoint("LEFT", modDropdown, "RIGHT", 8, 0)
    Locale.bindText(syncBtn, "EAM_AUTO_SYNC_TALENTS", "依當前天賦智慧勾選")
    if Theme and Theme.registerButton then Theme.registerButton(syncBtn) end
    syncBtn:SetScript("OnClick", function()
        local scanner = getScannerService()
        if scanner then
            scanner.scan()
            local sh = getSpellHeuristics()
            local sv = getSavedVariables()
            if sh and sv and scanner.knownSpells then
                for spellId in pairs(scanner.knownSpells) do
                    if sh.SPELL_META and sh.SPELL_META[spellId] then
                        addSpellToTargetModule(sv, spellId)
                    end
                end
                print("|cff00ff96EAM|r " .. localized("EAM_TALENT_SYNC_SUCCESS", "已成功依照當前天賦自動同步核心技能！"))
                Panel.refresh()
            end
        end
    end)
    Panel.controls.syncBtn = syncBtn

    -- 展開/收合全部
    local toggleAllBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    toggleAllBtn:SetSize(80, 22)
    toggleAllBtn:SetPoint("LEFT", syncBtn, "RIGHT", 6, 0)
    Locale.bindText(toggleAllBtn, "EAM_TOGGLE_ALL", "展開/收合")
    if Theme and Theme.registerButton then Theme.registerButton(toggleAllBtn) end
    toggleAllBtn:SetScript("OnClick", function()
        Panel.allExpanded = not Panel.allExpanded
        Panel.refresh()
    end)

    -- 分隔線
    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -86)
    sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -86)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- 中央 ScrollFrame
    local treeContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    treeContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -94)
    treeContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 46)
    if Theme and Theme.applyContainerBackground then
        Theme.applyContainerBackground(treeContainer, true)
    end

    local treeScroll = CreateFrame("ScrollFrame", "EAM_CatalogTreeScrollFrame", treeContainer, "UIPanelScrollFrameTemplate")
    treeScroll:SetPoint("TOPLEFT", treeContainer, "TOPLEFT", 6, -6)
    treeScroll:SetPoint("BOTTOMRIGHT", treeContainer, "BOTTOMRIGHT", -26, 6)

    local treeContent = CreateFrame("Frame", nil, treeScroll)
    treeContent:SetSize(580, 10)
    treeScroll:SetScrollChild(treeContent)
    Panel.controls.treeContent = treeContent

    -- 底部關閉按鈕
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)
    Locale.bindText(closeBtn, "EAM_ABOUT_CLOSE", "關閉")
    if Theme and Theme.registerButton then Theme.registerButton(closeBtn) end
    closeBtn:SetScript("OnClick", function()
        if Panel.controls.modMenu then Panel.controls.modMenu:Hide() end
        frame:Hide()
    end)

    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = "EAM_SpellCatalogTreeFrame"
    end

    Panel.frame = frame
    return frame
end

local function getOrCreateTreeRow(rowIndex, treeParent)
    local row = Panel.treeRows[rowIndex]
    if not row then
        row = CreateFrame("Button", nil, treeParent, "BackdropTemplate")
        row:SetSize(580, 26)
        if Theme and Theme.applyContainerBackground then
            Theme.applyContainerBackground(row, true)
        end

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", row, "LEFT", 28, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.icon = icon

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", row, "LEFT", 10, 0)
        text:SetJustifyH("LEFT")
        row.text = text

        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(20, 20)
        cb:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.cb = cb

        Panel.treeRows[rowIndex] = row
    end
    return row
end

-- 刷新勾選樹
function Panel.refresh()
    if not Panel.frame or not Panel.frame:IsShown() then
        return
    end

    local sh = getSpellHeuristics()
    if not sh or not sh.SPEC_PRESETS then
        return
    end

    local sv = getSavedVariables()
    local alerts = sv and sv.getActiveAlerts and sv.getActiveAlerts() or {}
    local activeSpells = {}

    local mod = Panel.targetModule or "spellCooldowns"
    if Panel.controls.modDropdown then
        Panel.controls.modDropdown:SetText((localized("EAM_CATALOG_TARGET_MODULE", "目標模組: ")) .. getModuleName(mod))
    end

    if mod == "playerAuras" and alerts.playerAuras then
        for sId, alert in pairs(alerts.playerAuras) do
            if alert and (alert.enabled ~= false and alert.enable ~= false) then
                activeSpells[tonumber(sId) or sId] = true
            end
        end
    elseif mod == "targetAuras" and alerts.targetAuras then
        for sId, alert in pairs(alerts.targetAuras) do
            if alert and (alert.enabled ~= false and alert.enable ~= false) then
                activeSpells[tonumber(sId) or sId] = true
            end
        end
    elseif mod == "specialAuras" and alerts.specialAuras then
        for sId, alert in pairs(alerts.specialAuras) do
            if alert and (alert.enabled ~= false and alert.enable ~= false) then
                activeSpells[tonumber(sId) or sId] = true
            end
        end
    elseif mod == "groundEffects" and alerts.groundEffects then
        for sId, alert in pairs(alerts.groundEffects) do
            if alert and (alert.enabled ~= false and alert.enable ~= false) then
                activeSpells[tonumber(sId) or sId] = true
            end
        end
    else
        if alerts.spellCooldowns then
            for sId, alert in pairs(alerts.spellCooldowns) do
                if alert and (alert.enabled ~= false and alert.enable ~= false) then
                    activeSpells[tonumber(sId) or sId] = true
                end
            end
        end
    end

    local treeParent = Panel.controls.treeContent
    for _, row in ipairs(Panel.treeRows) do
        row:Hide()
    end

    local _, _, playerClassId = UnitClass("player")
    playerClassId = playerClassId or 1

    local specs = sh.SPEC_PRESETS[playerClassId] or {}
    local yOffset = 0
    local rowIndex = 1

    for specId, spellList in pairs(specs) do
        local nodeKey = "spec_" .. specId
        local isExpanded = Panel.allExpanded or Panel.expandedNodes[nodeKey] or true

        -- Spec 父節點
        local row = getOrCreateTreeRow(rowIndex, treeParent)
        row:SetSize(580, 26)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", treeParent, "TOPLEFT", 0, -yOffset)
        if row.icon then row.icon:Hide() end
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", row, "LEFT", 10, 0)
        row.text:SetPoint("RIGHT", row.cb, "LEFT", -6, 0)

        local arrow = isExpanded and "▼ " or "▶ "
        row.text:SetText(string.format("%s專精 %s (共 %d 個推薦法術)", arrow, tostring(specId), #spellList))

        -- 檢查該專精下的法術是否全選
        local allChecked = true
        for _, sid in ipairs(spellList) do
            if not activeSpells[sid] then
                allChecked = false
                break
            end
        end
        row.cb:SetChecked(allChecked)
        row.cb:SetScript("OnClick", function(self)
            local checkVal = self:GetChecked()
            for _, sid in ipairs(spellList) do
                if checkVal then
                    addSpellToTargetModule(sv, sid)
                else
                    removeSpellFromTargetModule(sv, sid)
                end
            end
            Panel.refresh()
        end)

        row:SetScript("OnClick", function()
            Panel.expandedNodes[nodeKey] = not isExpanded
            Panel.refresh()
        end)

        row:Show()
        yOffset = yOffset + 30
        rowIndex = rowIndex + 1

        -- 展開子法術項目
        if isExpanded then
            for _, sid in ipairs(spellList) do
                local sMeta = sh.SPELL_META and sh.SPELL_META[sid] or {}
                local spellName, spellIcon = getSpellDisplayInfo(sid)
                spellName = spellName or ("Spell " .. sid)

                -- 搜尋過濾
                local matchesSearch = true
                if Panel.searchQuery ~= "" then
                    matchesSearch = spellName:lower():find(Panel.searchQuery, 1, true) or tostring(sid):find(Panel.searchQuery, 1, true)
                end

                if matchesSearch then
                    local sRow = getOrCreateTreeRow(rowIndex, treeParent)
                    sRow:SetSize(560, 24)
                    sRow:ClearAllPoints()
                    sRow:SetPoint("TOPLEFT", treeParent, "TOPLEFT", 16, -yOffset)
                    if sRow.icon then
                        sRow.icon:Show()
                        sRow.icon:ClearAllPoints()
                        sRow.icon:SetPoint("LEFT", sRow, "LEFT", 28, 0)
                        sRow.icon:SetTexture(spellIcon or 134400)
                    end
                    sRow.text:ClearAllPoints()
                    if sRow.icon then
                        sRow.text:SetPoint("LEFT", sRow.icon, "RIGHT", 6, 0)
                    else
                        sRow.text:SetPoint("LEFT", sRow, "LEFT", 28, 0)
                    end
                    sRow.text:SetPoint("RIGHT", sRow.cb, "LEFT", -6, 0)

                    local tagLabel = ""
                    if sMeta.tags and #sMeta.tags > 0 then
                        tagLabel = " [" .. table.concat(sMeta.tags, ", ") .. "]"
                    end
                    sRow.text:SetText(string.format("%s (ID: %s)%s", tostring(spellName or ("Spell " .. sid)), tostring(sid), tagLabel))

                    local isChecked = activeSpells[sid] == true
                    sRow.cb:SetChecked(isChecked)
                    sRow.cb:SetScript("OnClick", function(self)
                        if self:GetChecked() then
                            addSpellToTargetModule(sv, sid)
                        else
                            removeSpellFromTargetModule(sv, sid)
                        end
                        Panel.refresh()
                    end)

                    sRow:Show()
                    yOffset = yOffset + 26
                    rowIndex = rowIndex + 1
                end
            end
        end
    end

    treeParent:SetHeight(math.max(yOffset, 10))
end

function Panel.open()
    if inCombat() then
        print("|cff00ff96EAM|r " .. localized("EAM_CATALOG_COMBAT_BLOCKED", "戰鬥中不開啟法術庫勾選面板。"))
        return false, "combat"
    end
    if EAM.UI and type(EAM.UI.closeAllSidePanels) == "function" then
        EAM.UI.closeAllSidePanels("catalog")
    end
    local frame = createPanel()
    if not frame then
        return false, "frameUnavailable"
    end
    Panel.refresh()
    local mainFrame = _G.EAM_MainOptionsFrame
    if mainFrame and mainFrame:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 2, 0)
    else
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    end
    frame:Show()
    return true, "opened"
end

function Panel.hide()
    if Panel.frame then
        if Panel.controls.modMenu then Panel.controls.modMenu:Hide() end
        Panel.frame:Hide()
    end
end

function Panel.close()
    Panel.hide()
end

if Locale and type(Locale.registerRefresh) == "function" then
    Locale.registerRefresh(Panel.refresh)
end
