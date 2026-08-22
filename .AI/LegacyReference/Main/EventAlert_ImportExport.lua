--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: LegacyReference\Main\EventAlert_ImportExport.lua

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

-- ============================
-- 1. 序列化 / 反序列化 函式
-- ============================
local function SerializeTable(t)
    local function recurse(tbl, depth)
        if type(tbl) ~= "table" then
            if type(tbl) == "string" then
                return string.format("%q", tbl)
            else
                return tostring(tbl)
            end
        end
        local s = "{"
        local first = true
        for k, v in pairs(tbl) do
            if not first then
                s = s .. ","
            end
            local keyStr
            if type(k) == "string" and k:match("^%a[%a%d_]*$") then
                keyStr = k
            else
                keyStr = "[" .. recurse(k, depth + 1) .. "]"
            end
            s = s .. keyStr .. "=" .. recurse(v, depth + 1)
            first = false
        end
        s = s .. "}"
        return s
    end
    return recurse(t, 0)
end

local function DeserializeTable(str)
    local f, errorMsg = loadstring("return " .. str)
    if not f then
        return nil, errorMsg
    end
    local ok, result = pcall(f)
    if not ok then
        return nil, result
    end
    return result
end

-- ============================
-- 2. Base64 編碼 / 解碼 函式
-- ============================
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function EncodeBase64(data)
    return ((data:gsub('.', function(x)
        local r,b2='',x:byte()
        for i=8,1,-1 do 
            r = r .. (b2 % 2^i - b2 % 2^(i-1) > 0 and '1' or '0')
        end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i=1,6 do
            c = c + (x:sub(i,i)=='1' and 2^(6-i) or 0)
        end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[(#data % 3) + 1])
end

local function DecodeBase64(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if x == '=' then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do 
            r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0')
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do
            c = c + (x:sub(i,i)=='1' and 2^(8-i) or 0)
        end
        return string.char(c)
    end))
end

-- ============================
-- 3. Export / Import 封裝函式
-- ============================
function ExportTable(tbl)
    local serialized = SerializeTable(tbl)
    local encoded = EncodeBase64(serialized)
    return encoded
end

function ImportTable(encoded)
    local decoded = DecodeBase64(encoded)
    if not decoded or decoded == "" then
        return nil, "Decode failed or empty.";
    end
    return DeserializeTable(decoded)
end

------------------------------------------------------------------------------------
-- 取得用戶輸入的全域表格 (或任意路徑) 的輔助函式
------------------------------------------------------------------------------------
local function GetTableByPath(path)
    local chunk, err = loadstring("return " .. path)
    if not chunk then
        return nil, ("無效的表格路徑或語法錯誤: %s"):format(tostring(err))
    end
    local ok, ret = pcall(chunk)
    if not ok then
        return nil, ("呼叫失敗: %s"):format(tostring(ret))
    end
    if type(ret) ~= "table" then
        return nil, ("這不是一個 table: %s"):format(tostring(ret))
    end
    return ret
end

------------------------------------------------------------------------------------
-- 以下為介面本體 (主視窗 + Import/Export Frame)
------------------------------------------------------------------------------------

-- 先宣告變數
local MyAddonFrame
local importFrame
local exportFrame
local importButton
local exportButton

-- 1) 建立主框架
MyAddonFrame = CreateFrame("Frame", "MyAddonMainFrame", UIParent, "BasicFrameTemplateWithInset")
MyAddonFrame:SetSize(800, 600)
MyAddonFrame:SetPoint("CENTER")
MyAddonFrame:SetMovable(true)
MyAddonFrame:EnableMouse(true)
MyAddonFrame:RegisterForDrag("LeftButton")
MyAddonFrame:SetScript("OnDragStart", MyAddonFrame.StartMoving)
MyAddonFrame:SetScript("OnDragStop", MyAddonFrame.StopMovingOrSizing)

-- 標題文字
MyAddonFrame.title = MyAddonFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
MyAddonFrame.title:SetPoint("TOP", 0, -10)
MyAddonFrame.title:SetText("MyAddon Import/Export")

-------------------------------------------------
-- 2) Import 與 Export 兩個按鈕 (先建立本體)
-------------------------------------------------
importButton = CreateFrame("Button", nil, MyAddonFrame, "UIPanelButtonTemplate")
importButton:SetSize(80, 22)
importButton:SetPoint("BOTTOMLEFT", 10, 10)
importButton:SetText("Import")

exportButton = CreateFrame("Button", nil, MyAddonFrame, "UIPanelButtonTemplate")
exportButton:SetSize(80, 22)
exportButton:SetPoint("BOTTOMRIGHT", -10, 10)
exportButton:SetText("Export")

-------------------------------------------------
-- 3) 建立 ImportFrame
-------------------------------------------------
importFrame = CreateFrame("Frame", nil, MyAddonFrame, "BackdropTemplate")
importFrame:SetSize(760, 520)
importFrame:SetPoint("TOP", 0, -40)
importFrame:Hide()

importFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})

-- (3-1) Base64輸入框 + ScrollFrame
local editScroll = CreateFrame("ScrollFrame", "MyAddonImportScroll", importFrame, "UIPanelScrollFrameTemplate")
editScroll:SetPoint("TOPLEFT", 10, -10)
editScroll:SetSize(740, 140)

importFrame.editBox = CreateFrame("EditBox", nil, editScroll)
importFrame.editBox:SetMultiLine(true)
importFrame.editBox:SetSize(720, 140)
importFrame.editBox:SetAutoFocus(false)
importFrame.editBox:SetFontObject("ChatFontNormal")
importFrame.editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

editScroll:SetScrollChild(importFrame.editBox)

-- (3-2) 解碼後預覽框 + ScrollFrame
local previewScroll = CreateFrame("ScrollFrame", "MyAddonPreviewScroll", importFrame, "UIPanelScrollFrameTemplate")
previewScroll:SetPoint("TOPLEFT", editScroll, "BOTTOMLEFT", 0, -20)
previewScroll:SetSize(740, 140)

importFrame.previewEditBox = CreateFrame("EditBox", nil, previewScroll)
importFrame.previewEditBox:SetMultiLine(true)
importFrame.previewEditBox:SetSize(720, 140)
importFrame.previewEditBox:SetAutoFocus(false)
importFrame.previewEditBox:SetFontObject("ChatFontNormal")
importFrame.previewEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

previewScroll:SetScrollChild(importFrame.previewEditBox)

-- (3-3) Decode 與 Load 按鈕
importFrame.decodeButton = CreateFrame("Button", nil, importFrame, "UIPanelButtonTemplate")
importFrame.decodeButton:SetSize(80, 22)
importFrame.decodeButton:SetPoint("BOTTOMLEFT", 140, 10)
importFrame.decodeButton:SetText("Decode")

importFrame.loadButton = CreateFrame("Button", nil, importFrame, "UIPanelButtonTemplate")
importFrame.loadButton:SetSize(80, 22)
importFrame.loadButton:SetPoint("BOTTOMRIGHT", -140, 10)
importFrame.loadButton:SetText("Load")

local function FinalImport(luaCode)
    local func, err = loadstring("return " .. luaCode)
    if not func then
        return nil, err
    end
    local ok, result = pcall(func)
    if not ok then
        return nil, result
    end
    return result
end

-------------------------------------------------
-- 4) 建立 ExportFrame
-------------------------------------------------
exportFrame = CreateFrame("Frame", nil, MyAddonFrame, "BackdropTemplate")
exportFrame:SetSize(760, 520)
exportFrame:SetPoint("TOP", 0, -40)
exportFrame:Hide()

exportFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})

exportFrame.label = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
exportFrame.label:SetPoint("TOPLEFT", 10, -10)
exportFrame.label:SetText("請輸入要匯出的表格 (例如: _G.EA_Config)")

exportFrame.inputBox = CreateFrame("EditBox", nil, exportFrame, "InputBoxTemplate")
exportFrame.inputBox:SetSize(300, 30)
exportFrame.inputBox:SetPoint("TOPLEFT", exportFrame.label, "BOTTOMLEFT", 0, -5)
exportFrame.inputBox:SetAutoFocus(false)
exportFrame.inputBox:SetFontObject("ChatFontNormal")
exportFrame.inputBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
exportFrame.inputBox:SetText("")

exportFrame.exportBtn = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
exportFrame.exportBtn:SetSize(80, 22)
exportFrame.exportBtn:SetPoint("LEFT", exportFrame.inputBox, "RIGHT", 10, 0)
exportFrame.exportBtn:SetText("Export")

local exportScroll = CreateFrame("ScrollFrame", "MyAddonExportScroll", exportFrame, "UIPanelScrollFrameTemplate")
exportScroll:SetPoint("BOTTOM", 0, 10)
exportScroll:SetSize(740, 300)

exportFrame.editBox = CreateFrame("EditBox", nil, exportScroll)
exportFrame.editBox:SetMultiLine(true)
exportFrame.editBox:SetSize(720, 300)
exportFrame.editBox:SetAutoFocus(false)
exportFrame.editBox:SetFontObject("ChatFontNormal")
exportFrame.editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

exportScroll:SetScrollChild(exportFrame.editBox)

-------------------------------------------------------------------------------------
-- 5) 現在才來綁定各按鈕的事件 (此時 importFrame/exportFrame 都已宣告)
-------------------------------------------------------------------------------------

-- [Import Button]: 顯示 importFrame, 隱藏 exportFrame
importButton:SetScript("OnClick", function()
    exportFrame:Hide()
    importFrame:Show()
end)

-- [Export Button]: 顯示 exportFrame, 隱藏 importFrame
exportButton:SetScript("OnClick", function()
    importFrame:Hide()
    exportFrame:Show()
    -- 清空或保留上次結果都可以
    exportFrame.editBox:SetText("")
    exportFrame.editBox:ClearFocus()
end)

-- [ImportFrame] Decode 按鈕
importFrame.decodeButton:SetScript("OnClick", function()
    local text = importFrame.editBox:GetText() or ""
    if text == "" then
        print("|cffff0000[MyAddon]|r No input found.")
        return
    end

    local decodedStr = DecodeBase64(text)
    if not decodedStr or decodedStr == "" then
        print("|cffff0000[MyAddon]|r Decode Error: unable to decode or empty")
        return
    end

    importFrame.previewEditBox:SetText(decodedStr)
    importFrame.previewEditBox:HighlightText()
    print("|cff00ff00[MyAddon]|r Decoded. Please confirm before loading.")
end)

-- [ImportFrame] Load 按鈕
importFrame.loadButton:SetScript("OnClick", function()
    local luaCode = importFrame.previewEditBox:GetText() or ""
    if luaCode == "" then
        print("|cffff0000[MyAddon]|r No decoded string found.")
        return
    end

    StaticPopupDialogs["MYADDON_IMPORT_CONFIRM"] = {
        text = "確定要匯入嗎？這可能會覆蓋現有設定。",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            local t, err = FinalImport(luaCode)
            if t then
                print("|cff00ff00[MyAddon]|r Import Success!")
                -- 這裡可把匯入的資料套用到插件資料，例如:
                -- MyAddonDB = t
            else
                print("|cffff0000[MyAddon]|r Import Failed:", err)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("MYADDON_IMPORT_CONFIRM")
end)

-- [ExportFrame] Export 按鈕
exportFrame.exportBtn:SetScript("OnClick", function()
    local path = exportFrame.inputBox:GetText()
    if not path or path == "" then
        print("|cffff0000[MyAddon]|r 請輸入表格名稱/路徑!")
        return
    end

    local tbl, err = GetTableByPath(path)
    if not tbl then
        print("|cffff0000[MyAddon]|r 找不到有效的表格: " .. err)
        return
    end

    -- 匯出
    local encoded = ExportTable(tbl)
    exportFrame.editBox:SetText(encoded)
    exportFrame.editBox:HighlightText()

    print("|cff00ff00[MyAddon]|r Export Success! 已將匯出結果顯示於下方")
end)
