--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/GroupManagerPanel
檔案: UI\GroupManagerPanel.lua

理念:
- 提供獨立二級側窗面板（APPEND 模式），管理系統內建戰術群組與自訂群組。
- 支援群組主開關、情境過濾、外觀代表色與法術成員名冊複選。

責任:
- 渲染群組清單與選定群組之詳細設定介面。
- 支援法術在群組中的勾選綁定與即時同步。
- 遵循 EAM Theme、Locale 與側窗互斥機制。

邊界:
- 戰鬥中不開啟或變更結構。
- 所有資料變更透過 GroupService 與 SavedVariables 提交。
--]]
local _, EAM = ...

local api = EAM.API or {}
local Theme = EAM.Theme
local Locale = EAM.Locale
local Util = EAM.Util or {}

local Panel = {
    frame = nil,
    selectedGroupId = "burst",
    groupRows = {},
    spellRows = {},
    controls = {},
}
EAM.UI.GroupManagerPanel = Panel

local function inCombat()
    if not api.InCombatLockdown then
        return false
    end
    local ok, combat = pcall(api.InCombatLockdown)
    return ok and combat == true
end

local function getGroupService()
    return EAM.Services and EAM.Services.GroupService
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

local kindLabels = {
    playerAuras = "自身光環",
    targetAuras = "目標光環",
    specialAuras = "特殊光環",
    spellCooldowns = "技能冷卻",
    itemCooldowns = "物品冷卻",
    groundEffects = "地面效果",
}

local function resolveSpellItem(alert, rawKey, kind)
    local isItem = (kind == "itemCooldowns" or alert.kind == "itemCooldown")
    local numId = alert.spellID or alert.itemID
    if not numId and type(rawKey) == "string" then
        numId = tonumber(rawKey:match("(%d+)$"))
    elseif not numId and type(rawKey) == "number" then
        numId = rawKey
    end
    local sName, sIcon
    if isItem and numId then
        if C_Item and C_Item.GetItemInfo then
            local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(numId)
            sName = name
            sIcon = icon
        end
    elseif numId then
        sName, sIcon = getSpellDisplayInfo(numId)
    end
    sName = alert.name or sName or (isItem and ("Item " .. tostring(numId or rawKey)) or ("Spell " .. tostring(numId or rawKey)))
    sIcon = alert.icon or sIcon or 134400
    local kLabel = kindLabels[kind] or kind
    return {
        spellId = numId or rawKey,
        isItem = isItem,
        name = sName,
        icon = sIcon,
        alert = alert,
        kind = kind,
        kindLabel = kLabel,
    }
end

-- 建立面板 Frame
local function createPanel()
    if Panel.frame then
        return Panel.frame
    end

    local frame = CreateFrame("Frame", "EAM_GroupManagerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(620, 520)
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
    Locale.bindText(title, "EAM_GROUP_MANAGER_TITLE", "★ 群組分類與標籤管理")
    Panel.controls.title = title

    local subTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subTitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    Locale.bindText(subTitle, "EAM_GROUP_MANAGER_SUBTITLE", "管理戰術分類與自訂標籤群組，支援多對多法術複選與情境過濾")

    -- 分隔線
    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -54)
    sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -54)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)

    -- 左側：群組清單 ScrollFrame
    local leftContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    leftContainer:SetSize(210, 400)
    leftContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -62)
    if Theme and Theme.applyContainerBackground then
        Theme.applyContainerBackground(leftContainer, true)
    end

    local leftScroll = CreateFrame("ScrollFrame", "EAM_GroupListScrollFrame", leftContainer, "UIPanelScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", leftContainer, "TOPLEFT", 6, -6)
    leftScroll:SetPoint("BOTTOMRIGHT", leftContainer, "BOTTOMRIGHT", -26, 6)

    local leftContent = CreateFrame("Frame", nil, leftScroll)
    leftContent:SetSize(180, 10)
    leftScroll:SetScrollChild(leftContent)
    Panel.controls.leftContent = leftContent

    -- 右側：群組詳情與法術指派
    local rightContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    rightContainer:SetSize(370, 400)
    rightContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -62)
    if Theme and Theme.applyContainerBackground then
        Theme.applyContainerBackground(rightContainer, true)
    end
    Panel.controls.rightContainer = rightContainer

    -- 右側控制項：群組名稱
    local nameLabel = rightContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameLabel:SetPoint("TOPLEFT", rightContainer, "TOPLEFT", 12, -12)
    Locale.bindText(nameLabel, "EAM_GROUP_NAME_LABEL", "群組名稱:")

    local nameEdit = CreateFrame("EditBox", nil, rightContainer, "InputBoxTemplate")
    nameEdit:SetSize(160, 22)
    nameEdit:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
    nameEdit:SetAutoFocus(false)

    local function commitGroupName()
        if not nameEdit then return end
        local text = (nameEdit:GetText() or ""):match("^%s*(.-)%s*$")
        local gs = getGroupService()
        if gs and Panel.selectedGroupId and text and text ~= "" then
            local sv = getSavedVariables()
            if sv and sv.setGroupProperty then
                sv.setGroupProperty(Panel.selectedGroupId, "name", text)
            end
            gs.refreshCache()
            Panel.refresh()
        end
        nameEdit:ClearFocus()
    end

    nameEdit:SetScript("OnEnterPressed", commitGroupName)
    nameEdit:SetScript("OnEditFocusLost", commitGroupName)
    Panel.controls.nameEdit = nameEdit

    local saveNameBtn = CreateFrame("Button", nil, rightContainer, "UIPanelButtonTemplate")
    saveNameBtn:SetSize(60, 22)
    saveNameBtn:SetPoint("LEFT", nameEdit, "RIGHT", 6, 0)
    Locale.bindText(saveNameBtn, "EA_XOPT_SAVE", "儲存")
    if Theme and Theme.registerButton then Theme.registerButton(saveNameBtn) end
    saveNameBtn:SetScript("OnClick", commitGroupName)
    Panel.controls.saveNameBtn = saveNameBtn

    -- 群組啟用 CheckBox
    local enableCb = CreateFrame("CheckButton", nil, rightContainer, "UICheckButtonTemplate")
    enableCb:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -8)
    local enableCbText = enableCb.text or _G[enableCb:GetName() .. "Text"]
    if enableCbText then
        Locale.bindText(enableCbText, "EAM_GROUP_ENABLE_ALL", "啟用此群組")
    end
    enableCb:SetScript("OnClick", function(self)
        local gs = getGroupService()
        if gs and Panel.selectedGroupId then
            gs.setGroupEnabled(Panel.selectedGroupId, self:GetChecked())
            Panel.refresh()
        end
    end)
    Panel.controls.enableCb = enableCb

    -- 僅戰鬥中顯示 CheckBox
    local combatCb = CreateFrame("CheckButton", nil, rightContainer, "UICheckButtonTemplate")
    combatCb:SetPoint("LEFT", enableCb, "RIGHT", 100, 0)
    local combatCbText = combatCb.text or _G[combatCb:GetName() .. "Text"]
    if combatCbText then
        Locale.bindText(combatCbText, "EAM_GROUP_IN_COMBAT_ONLY", "僅戰鬥中顯示")
    end
    combatCb:SetScript("OnClick", function(self)
        local sv = getSavedVariables()
        if sv and Panel.selectedGroupId then
            sv.setGroupProperty(Panel.selectedGroupId, "inCombatOnly", self:GetChecked())
            local gs = getGroupService()
            if gs then gs.refreshCache() end
        end
    end)
    Panel.controls.combatCb = combatCb

    -- 法術勾選清單標題
    local spellListTitle = rightContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spellListTitle:SetPoint("TOPLEFT", enableCb, "BOTTOMLEFT", 0, -10)
    Locale.bindText(spellListTitle, "EAM_GROUP_SPELLS_HEADER", "📋 納入此群組的法術清單 (可複選)：")

    -- 法術勾選清單 ScrollFrame
    local rightScroll = CreateFrame("ScrollFrame", "EAM_GroupSpellScrollFrame", rightContainer, "UIPanelScrollFrameTemplate")
    rightScroll:SetPoint("TOPLEFT", spellListTitle, "BOTTOMLEFT", 0, -6)
    rightScroll:SetPoint("BOTTOMRIGHT", rightContainer, "BOTTOMRIGHT", -26, 10)

    local rightContent = CreateFrame("Frame", nil, rightScroll)
    rightContent:SetSize(330, 10)
    rightScroll:SetScrollChild(rightContent)
    Panel.controls.rightContent = rightContent

    -- 底部按鈕：新增自訂群組
    local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    addBtn:SetSize(110, 24)
    addBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 16)
    Locale.bindText(addBtn, "EAM_GROUP_ADD_CUSTOM", "+ 新增群組")
    if Theme and Theme.registerButton then Theme.registerButton(addBtn) end
    addBtn:SetScript("OnClick", function()
        local gs = getGroupService()
        if gs then
            local newId = gs.createCustomGroup(localized("EAM_NEW_GROUP_DEFAULT_NAME", "自訂群組"), "FFFFFFFF", 134400)
            if newId then
                Panel.selectedGroupId = newId
                Panel.refresh()
            end
        end
    end)

    -- 底部按鈕：刪除所選群組
    local delBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    delBtn:SetSize(90, 24)
    delBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)
    Locale.bindText(delBtn, "EAM_GROUP_DELETE", "- 刪除群組")
    if Theme and Theme.registerButton then Theme.registerButton(delBtn) end
    delBtn:SetScript("OnClick", function()
        local gs = getGroupService()
        if gs and Panel.selectedGroupId then
            local g = gs.getGroup(Panel.selectedGroupId)
            if g and not g.isSystem then
                gs.deleteCustomGroup(Panel.selectedGroupId)
                Panel.selectedGroupId = "burst"
                Panel.refresh()
            end
        end
    end)
    Panel.controls.delBtn = delBtn

    -- 底部關閉按鈕
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 16)
    Locale.bindText(closeBtn, "EAM_ABOUT_CLOSE", "關閉")
    if Theme and Theme.registerButton then Theme.registerButton(closeBtn) end
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = "EAM_GroupManagerFrame"
    end

    Panel.frame = frame
    return frame
end

-- 刷新整個面板內容
function Panel.refresh()
    if not Panel.frame or not Panel.frame:IsShown() then
        return
    end

    local gs = getGroupService()
    if not gs then
        return
    end

    local groups = gs.getGroups()
    local sv = getSavedVariables()
    local alerts = sv and sv.getActiveAlerts and sv.getActiveAlerts() or {}

    -- 1. 渲染左側群組列表
    local leftParent = Panel.controls.leftContent
    for _, btn in ipairs(Panel.groupRows) do
        btn:Hide()
    end

    local yOffset = 0
    for idx, g in ipairs(groups) do
        local row = Panel.groupRows[idx]
        if not row then
            row = CreateFrame("Button", nil, leftParent, "BackdropTemplate")
            row:SetSize(175, 30)
            if Theme and Theme.applyContainerBackground then
                Theme.applyContainerBackground(row, true)
            end

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(20, 20)
            icon:SetPoint("LEFT", row, "LEFT", 4, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.icon = icon

            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            text:SetPoint("RIGHT", row, "RIGHT", -26, 0)
            text:SetJustifyH("LEFT")
            row.text = text

            local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            cb:SetSize(20, 20)
            cb:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            row.cb = cb

            Panel.groupRows[idx] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", leftParent, "TOPLEFT", 0, -yOffset)
        row.icon:SetTexture(g.icon or 134400)
        local displayName = g.nameKey and EAM.L and EAM.L[g.nameKey] or g.name
        row.text:SetText(displayName or g.id)

        row.cb:SetChecked(g.enabled ~= false)
        row.cb:SetScript("OnClick", function(self)
            gs.setGroupEnabled(g.id, self:GetChecked())
            Panel.refresh()
        end)

        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(displayName or g.id, 1, 0.82, 0)
            if g.isSystem then
                GameTooltip:AddLine(localized("EAM_GROUP_TIP_SYSTEM", "系統預設戰術群組"), 0.7, 0.7, 0.7)
            else
                GameTooltip:AddLine(localized("EAM_GROUP_TIP_CUSTOM", "玩家自訂標籤群組"), 0.7, 0.7, 0.7)
            end
            if g.inCombatOnly then
                GameTooltip:AddLine(localized("EAM_GROUP_TIP_COMBAT", "狀態: 僅戰鬥中顯示"), 0.9, 0.6, 0.2)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row:SetScript("OnClick", function()
            Panel.selectedGroupId = g.id
            Panel.refresh()
        end)

        if g.id == Panel.selectedGroupId then
            row:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            row:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        end

        row:Show()
        yOffset = yOffset + 34
    end
    leftParent:SetHeight(math.max(yOffset, 10))

    -- 2. 渲染右側選定群組詳情
    local curGroup = gs.getGroup(Panel.selectedGroupId)
    if curGroup then
        Panel.controls.nameEdit:SetText(curGroup.name or "")
        Panel.controls.enableCb:SetChecked(curGroup.enabled ~= false)
        Panel.controls.combatCb:SetChecked(curGroup.inCombatOnly == true)
        Panel.controls.delBtn:SetEnabled(not curGroup.isSystem)

        -- 渲染群組法術清單
        local rightParent = Panel.controls.rightContent
        for _, sRow in ipairs(Panel.spellRows) do
            sRow:Hide()
        end

        local allAlertsList = {}
        for kind, list in pairs(alerts) do
            if type(list) == "table" then
                for spellId, alert in pairs(list) do
                    if type(alert) == "table" then
                        allAlertsList[#allAlertsList + 1] = resolveSpellItem(alert, spellId, kind)
                    end
                end
            end
        end

        table.sort(allAlertsList, function(a, b)
            return tostring(a.spellId) < tostring(b.spellId)
        end)

        local sYOffset = 0
        for sIdx, item in ipairs(allAlertsList) do
            local sRow = Panel.spellRows[sIdx]
            if not sRow then
                sRow = CreateFrame("Button", nil, rightParent, "BackdropTemplate")
                sRow:SetSize(325, 26)
                if Theme and Theme.applyContainerBackground then
                    Theme.applyContainerBackground(sRow, true)
                end

                local sIcon = sRow:CreateTexture(nil, "ARTWORK")
                sIcon:SetSize(18, 18)
                sIcon:SetPoint("LEFT", sRow, "LEFT", 4, 0)
                sIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                sRow.icon = sIcon

                local sText = sRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                sText:SetPoint("LEFT", sIcon, "RIGHT", 6, 0)
                sText:SetPoint("RIGHT", sRow, "RIGHT", -30, 0)
                sText:SetJustifyH("LEFT")
                sRow.text = sText

                local sCb = CreateFrame("CheckButton", nil, sRow, "UICheckButtonTemplate")
                sCb:SetSize(18, 18)
                sCb:SetPoint("RIGHT", sRow, "RIGHT", -2, 0)
                sRow.cb = sCb

                Panel.spellRows[sIdx] = sRow
            end

            sRow:ClearAllPoints()
            sRow:SetPoint("TOPLEFT", rightParent, "TOPLEFT", 0, -sYOffset)
            sRow.icon:SetTexture(item.icon)
            sRow.text:SetText(string.format("[%s] %s (ID: %s)", tostring(item.kindLabel or item.kind), tostring(item.name), tostring(item.spellId)))

            -- 懸停法術/物品 Tooltip 提示
            sRow:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if item.isItem and item.spellId then
                    if GameTooltip.SetItemByID then
                        GameTooltip:SetItemByID(item.spellId)
                    else
                        GameTooltip:SetHyperlink("item:" .. tostring(item.spellId))
                    end
                elseif item.spellId then
                    local numericSpellId = tonumber(item.spellId)
                    if numericSpellId and GameTooltip.SetSpellByID then
                        GameTooltip:SetSpellByID(numericSpellId)
                    end
                end
                GameTooltip:Show()
            end)
            sRow:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            -- 判斷該法術是否已被勾選入此群組
            local isMember = false
            if item.alert.groups then
                for _, gid in ipairs(item.alert.groups) do
                    if gid == Panel.selectedGroupId then
                        isMember = true
                        break
                    end
                end
            end

            sRow.cb:SetChecked(isMember)
            sRow.cb:SetScript("OnClick", function(self)
                gs.toggleSpellGroup(item.alert, Panel.selectedGroupId)
                if sv and sv.markRevisionChanged then
                    sv.markRevisionChanged()
                end
                Panel.refresh()
            end)

            sRow:Show()
            sYOffset = sYOffset + 28
        end
        rightParent:SetHeight(math.max(sYOffset, 10))
    end
end

function Panel.open()
    if inCombat() then
        print("|cff00ff96EAM|r " .. localized("EAM_GROUP_COMBAT_BLOCKED", "戰鬥中不開啟群組管理設定。"))
        return false, "combat"
    end
    if EAM.UI and type(EAM.UI.closeAllSidePanels) == "function" then
        EAM.UI.closeAllSidePanels("group")
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
        Panel.frame:Hide()
    end
end

function Panel.close()
    Panel.hide()
end

if Locale and type(Locale.registerRefresh) == "function" then
    Locale.registerRefresh(Panel.refresh)
end
