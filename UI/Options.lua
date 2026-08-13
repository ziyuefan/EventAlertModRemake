--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/Options
檔案: UI\Options.lua

理念:
- 保留 EAM 經典簡潔設定體驗，不使用 any XML 模板，100% Pure Lua 實作。
- 提供主設定面版、開闊且不重疊的圖示位置與滑桿面板、滾動法術清單、法術條件彈出視窗。
- 提供固定英文名稱的 Auto Detect 與可保存的多語系下拉選單；選擇後原地刷新 EAM 自有 UI。
- 專注於 profile 資料的讀寫，不直接承擔戰鬥中 alert 狀態的管理與渲染。

責任:
- 建立主設定 frame、滑桿與能量設定 panel、ScrollBox 滾動法術清單、法術條件 sub-frame。
- 讀取與寫入 EAM.db.config 與 EAM.db.alerts，並在變更時呼叫對應 Service 的刷新 API。
- 將語系選擇寫入 SavedVariables，透過穩定 EAM.L identity 與文字綁定立即刷新既有 UI。
- 戰鬥中防 taint 安全保護：戰鬥中限制開啟與 UI 的重構，於 PLAYER_REGEN_ENABLED 時安全延遲載入。
- 將物品冷卻監控獨立為單獨的第 5 個 UI 設定分類，行與列進行了無縫重塑與防重疊調整。

資料所有權:
- 擁有所有設定 UI 的 frame 與 widgets 生命週期與 state。

可變狀態:
- 讀寫 `EAM.db.config` 的 checkbox、slider 與 class powers 狀態。
- 讀寫 `EAM.db.alerts` 裡各類別提醒的 spellID 與 itemID 項目。

邊界:
- 整合 12.x C_Spell 與 C_Item API。
- 在技能/物品冷卻設定條件下隱藏 Value 1~4 光環細部數值勾選。
- 排版進行了大範圍重塑，Sliders 與文字標籤擁有充足的縱向間距，100% 告別擁擠。
- 支援 12 種經典 EAM 聲音與 FileDataID、自訂 ShaolinFootball MP3 音樂 PATH，極致簡潔播放！

]]
local _, EAM = ...

local Options = {
    frame = nil,
    posFrame = nil,
    listFrame = nil,
    condFrame = nil,
    soundDropdown = nil,
    languageDropdown = nil,
    languageMenu = nil,
    themeDropdown = nil,
    themeMenu = nil,
    fontDropdown = nil,
    fontMenu = nil,
    specDropdown = nil,
    currentSpecFilterName = nil,
    addEditBox = nil,
    currentCategory = 1,
    pendingOpen = false,
    currentEditingAlert = nil,
}
EAM.UI.Options = Options

local api = EAM.API
local Theme = EAM.Theme
local Locale = EAM.Locale
local mathFloor = math.floor

local function bindText(target, key, fallback)
    if Locale and type(Locale.bindText) == "function" then
        return Locale.bindText(target, key, fallback)
    end
    if target and type(target.SetText) == "function" then
        target:SetText((EAM.L and EAM.L[key]) or fallback or key)
        return true
    end
    return false
end

local function localized(key, fallback)
    return {
        eamLocaleKey = key,
        fallback = fallback,
    }
end

local function setWidgetText(target, value)
    if type(value) == "table" and type(value.eamLocaleKey) == "string" then
        return bindText(target, value.eamLocaleKey, value.fallback)
    end
    if target and type(target.SetText) == "function" then
        target:SetText(value)
        return true
    end
    return false
end

local MINIMAP_SVG_ASSET = "Interface\\AddOns\\EventAlertMod\\Media\\SVG\\eam-minimap.svg"
local MINIMAP_FALLBACK_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"

-- 12 種經典音效的 FileDataID 與自訂 PATH
local soundAssets = {
    ShayBell = 568154,
    FluteRun = 569642,
    Netherwind = 569487,
    PolyMorphCow = 568761,
    RockBiter = 569545,
    YarrrrImpact = 568382,
    BrokenHeart = 568945,
    MillhouseReady = 555336,
    MillhousePyro = 555337,
    SatyrePissed = 559630,
    MortarTeamPissed = 555839,
    ShaolinFootball = "Interface\\AddOns\\EventAlertMod\\Media\\Music\\ShaolinFootball.mp3",
}

local soundNames = {
    "ShayBell",
    "FluteRun",
    "Netherwind",
    "PolyMorphCow",
    "RockBiter",
    "YarrrrImpact",
    "BrokenHeart",
    "MillhouseReady",
    "MillhousePyro",
    "SatyrePissed",
    "MortarTeamPissed",
    "ShaolinFootball",
}

local function isAuraSoundAvailable()
    local service = EAM.Services and EAM.Services.AuraCapabilityService
    local snapshot = service and service.getSnapshot and service.getSnapshot() or nil
    return snapshot ~= nil and snapshot.hasAuraSound == true and snapshot.hasAuraSoundEnum == true
end

local function createAuraSoundEntry(asset)
    if type(asset) == "number" then
        return { soundFileID = asset }
    end
    if type(asset) == "string" then
        return { soundFileName = asset }
    end
    return nil
end

function Options.buildAuraSoundConfig(soundName, added, applicationsIncreased, removed)
    if not added and not applicationsIncreased and not removed then
        return nil
    end
    local asset = soundAssets[soundName] or soundAssets.ShayBell
    local sound = {}
    if added then
        sound.added = createAuraSoundEntry(asset)
    end
    if applicationsIncreased then
        sound.applicationsIncreased = createAuraSoundEntry(asset)
    end
    if removed then
        sound.removed = createAuraSoundEntry(asset)
    end
    return sound
end

function Options.resolveAuraSoundName(sound)
    if type(sound) ~= "table" then
        return nil
    end
    local entry = sound.added or sound.applicationsIncreased or sound.removed
    if type(entry) ~= "table" then
        return nil
    end
    local asset = entry.soundFileID or entry.soundFileName
    for index = 1, #soundNames do
        local soundName = soundNames[index]
        if soundAssets[soundName] == asset then
            return soundName
        end
    end
    return nil
end
-- 12.1 可由 Texture:SetSVG 載入插件自有 SVG；12.0.7 或載入失敗時使用穩定內建圖示。
function Options.applyMinimapTexture(texture)
    if not texture or type(texture.SetTexture) ~= "function" then
        return "unavailable"
    end

    texture:SetTexture(MINIMAP_FALLBACK_TEXTURE)
    if type(texture.SetSVG) ~= "function" then
        return "fallback"
    end

    local ok, accepted = pcall(texture.SetSVG, texture, MINIMAP_SVG_ASSET)
    if ok and accepted ~= false then
        return "svg"
    end

    -- SetSVG 可能在錯誤前留下部分狀態，失敗路徑再次明確恢復 fallback。
    texture:SetTexture(MINIMAP_FALLBACK_TEXTURE)
    return "fallback"
end


-- Native Aura 結構只能在重建窗口套用；一般設定先標記待套用。
local function markAuraSettingsDirty(reason)
    local service = EAM.Services and EAM.Services.AuraContainerService
    if service and service.markSettingsDirty then
        service.markSettingsDirty(reason or "OPTIONS_CONFIG_CHANGED")
        return true
    end
    if service and service.requestRebuild then
        service.requestRebuild(reason or "OPTIONS_CONFIG_CHANGED")
        return true
    end
    return false
end

function Options.notifyConfigChanged(rebuildNative)
    if rebuildNative ~= false then
        markAuraSettingsDirty("OPTIONS_CONFIG_CHANGED")
        if Options.refreshAuraBackendStatus then
            Options.refreshAuraBackendStatus()
        end
    end
    if EAM.Services.AuraService and EAM.Services.AuraService.refreshAll then
        EAM.Services.AuraService.refreshAll("OPTIONS_CONFIG_CHANGED")
    end
    if EAM.Services.CooldownService and EAM.Services.CooldownService.refreshAll then
        EAM.Services.CooldownService.refreshAll("OPTIONS_CONFIG_CHANGED")
    end
    if EAM.Services.ItemCooldownService and EAM.Services.ItemCooldownService.refreshAll then
        EAM.Services.ItemCooldownService.refreshAll("OPTIONS_CONFIG_CHANGED")
    end
    -- 立即更新 UI 版面配置
    if EAM.UI.Renderer and EAM.UI.Renderer.requestLayout then
        EAM.UI.Renderer.requestLayout()
    end
    if EAM.UI.Renderer and EAM.UI.Renderer.applyCooldownStyle then
        EAM.UI.Renderer.applyCooldownStyle()
    end
end

function Options.notifyTextLayoutChanged(reapplyNative)
    if EAM.UI.Renderer and EAM.UI.Renderer.applyTextLayout then
        EAM.UI.Renderer.applyTextLayout()
    end
    if reapplyNative then
        markAuraSettingsDirty("OPTIONS_NATIVE_TEXT_LAYOUT_CHANGED")
        Options.refreshAuraBackendStatus()
    end
end

local function notifyGroundEffectConfigChanged()
    local service = EAM.Services.GroundEffectService
    if service and service.onConfigChanged then
        service.onConfigChanged()
    end
end

local function notifyAuraSoundChanged()
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router and router.fire then
        local revision = EAM.db and EAM.db.revision or 0
        router.fire("EAM_AURA_SOUND_CHANGED", revision)
        return true
    end
    return false
end

function Options.refreshLanguageDropdown()
    if not Options.languageDropdown then
        return
    end

    local locale = EAM.Locale
    local selection = locale and locale.getSelection and locale.getSelection() or "auto"
    local label = locale and locale.getOptionLabel and locale.getOptionLabel(selection) or "Auto Detect"
    Options.languageDropdown:SetText((EAM.L.EAM_OPT_LANGUAGE_PREFIX or "Language: ") .. label)
end

function Options.refreshThemeDropdown()
    if not Options.themeDropdown then
        return
    end
    local theme = EAM.Theme
    local selection = theme and theme.getSelection and theme.getSelection() or "eam"
    local label = theme and theme.getOptionLabel and theme.getOptionLabel(selection) or "EAM"
    Options.themeDropdown:SetText((EAM.L.EAM_OPT_THEME_PREFIX or "Theme: ") .. label)
end

function Options.refreshFontDropdown()
    if not Options.fontDropdown then
        return
    end
    local config = EAM.db and EAM.db.config or nil
    local textPlacement = EAM.UI and EAM.UI.TextPlacement
    local family = textPlacement and textPlacement.getFontFamily and textPlacement.getFontFamily(config)
        or (config and config.fontFamily)
        or "STANDARD"
    local label = family
    local options = EAM.Constants and EAM.Constants.FONT_FAMILY_OPTIONS or {}
    for index = 1, #options do
        local option = options[index]
        if option.value == family then
            label = (EAM.L and EAM.L[option.labelKey]) or option.labelKey or option.value
            break
        end
    end
    Options.fontDropdown:SetText((EAM.L.EAM_OPT_FONT_PREFIX or "Font: ") .. label)
end

function Options.refreshAuraBackendStatus()
    if not Options.nativeAuraStatusLabel then
        return
    end
    local service = EAM.Services.AuraContainerService
    local status = service and service.getStatus and service.getStatus() or nil
    local backend = status and status.backend or EAM.Constants.AURA_BACKEND_UNSUPPORTED
    local suffix = ""
    if status and status.reloadRequired then
        suffix = " (/reload)"
    elseif status and status.settingsDirty then
        suffix = EAM.L.EAM_OPT_AURA_SETTINGS_DIRTY or "（待套用）"
    elseif status and status.pending then
        suffix = EAM.L.EAM_OPT_AURA_PENDING or "（等待脫戰）"
    end
    Options.nativeAuraStatusLabel:SetText(
        (EAM.L.EAM_OPT_AURA_BACKEND or "Aura 後端: ") .. tostring(backend) .. suffix
    )
end

function Options.refreshSoundDropdown()
    if not Options.soundDropdown then
        return
    end
    local soundName = EAM.db and EAM.db.config and EAM.db.config.soundName or "ShayBell"
    Options.soundDropdown:SetText((EAM.L.EAM_OPT_SOUND_PREFIX or "音效: ") .. soundName)
end

function Options.refreshSpecDropdown()
    if not Options.specDropdown then
        return
    end
    local filterName
    if Options.currentSpecFilter == nil then
        filterName = EAM.L.EAM_OPT_FILTER_ALL_VAL or "全部法術"
    elseif Options.currentSpecFilter == 0 then
        filterName = EAM.L.EAM_OPT_FILTER_GENERAL or "通用技能/自訂"
    else
        filterName = Options.currentSpecFilterName or tostring(Options.currentSpecFilter)
    end
    Options.specDropdown:SetText((EAM.L.EAM_OPT_FILTER_PREFIX or "篩選: ") .. filterName)
end

function Options.refreshConditionsLocalizedText()
    local cf = Options.condFrame
    local data = Options.currentEditingAlert
    if not cf or not data then
        return
    end

    local id = data.itemID or data.spellID
    if data.kind == "itemCooldown" or (data.itemID and not data.spellID) then
        cf.idText:SetText(id and string.format(EAM.L.EAM_OPT_COND_ITEM_ID_FORMAT or "Item ID: %d", id) or "")
    elseif data.spellID then
        cf.idText:SetText(string.format(EAM.L.EAM_OPT_COND_SPELL_ID_FORMAT or "Spell ID: %d", data.spellID))
    else
        cf.idText:SetText("")
    end

    local auraSoundName = Options.resolveAuraSoundName(type(data.sound) == "table" and data.sound or nil)
        or (EAM.db and EAM.db.config and EAM.db.config.soundName)
        or "ShayBell"
    if cf.auraSoundDropdown then
        cf.auraSoundDropdown:SetText((EAM.L.EAM_OPT_SOUND_PREFIX or "Sound: ") .. auraSoundName)
    end
end


function Options.refreshLocalizedText()
    Options.refreshSoundDropdown()
    Options.refreshLanguageDropdown()
    Options.refreshThemeDropdown()
    Options.refreshFontDropdown()
    Options.refreshAuraBackendStatus()
    if Options.rebuildSpecMenu then
        Options.rebuildSpecMenu()
    end
    Options.refreshSpecDropdown()
    Options.refreshConditionsLocalizedText()
    Options.refreshList()
end

if Locale and type(Locale.registerRefresh) == "function" then
    Locale.registerRefresh(Options.refreshLocalizedText)
end

-- 取得當前類別對應的 alert list
function Options.getCurrentCategoryList()
    local saved = EAM.Modules.SavedVariables
    if not saved or not EAM.db then return {} end
    
    if Options.currentCategory == 1 or Options.currentCategory == 2 then
        return saved.getAlertList(EAM.Constants.ALERT_KIND_AURA, "player") or {}
    elseif Options.currentCategory == 3 then
        return saved.getAlertList(EAM.Constants.ALERT_KIND_AURA, "target") or {}
    elseif Options.currentCategory == 4 then
        return saved.getAlertList(EAM.Constants.ALERT_KIND_SPELL_COOLDOWN, "player") or {}
    elseif Options.currentCategory == 5 then
        return saved.getAlertList(EAM.Constants.ALERT_KIND_ITEM_COOLDOWN) or {}
    elseif Options.currentCategory == 6 then
        return saved.getAlertList("groundEffect") or {}
    end
    return {}
end

Options.currentSpecFilter = nil

local function getSpellSpec(spellID)
    if not spellID then return nil end
    local classToken = select(2, UnitClass("player"))
    local classData = EAM.Data.SpellArray and EAM.Data.SpellArray[classToken]
    if not classData then return nil end

    if classData.general then
        for _, sp in ipairs(classData.general) do
            if sp.id == spellID then return 0 end
        end
    end

    for specIdx = 1, 4 do
        if classData[specIdx] then
            for _, sp in ipairs(classData[specIdx]) do
                if sp.id == spellID then return specIdx end
            end
        end
    end
    return nil
end

-- 刷新滾動列表
function Options.refreshList()
    if not Options.listFrame or not Options.listFrame:IsShown() then return end
    
    local saved = EAM.Modules.SavedVariables
    if not saved then return end
    
    local listData = {}
    local rawList = Options.getCurrentCategoryList()
    
    for id, alert in pairs(rawList) do
        local matches = false
        if Options.currentCategory == 1 then
            if alert.fromPlayer == true or alert.fromPlayer == nil then
                matches = true
            end
        elseif Options.currentCategory == 2 then
            if alert.fromPlayer == false then
                matches = true
            end
        elseif Options.currentCategory == 3 then
            matches = true
        elseif Options.currentCategory == 4 then
            matches = true
        elseif Options.currentCategory == 5 then
            matches = true
        elseif Options.currentCategory == 6 then
            matches = true
        end
        
        if matches then
            local passSpec = true
            if Options.currentSpecFilter ~= nil then
                local specOfSpell = getSpellSpec(alert.spellID)
                if Options.currentSpecFilter == 0 then
                    passSpec = (specOfSpell == 0 or specOfSpell == nil)
                else
                    passSpec = (specOfSpell == Options.currentSpecFilter)
                end
            end

            if passSpec then
                table.insert(listData, alert)
            end
        end
    end
    
    table.sort(listData, function(a, b)
        local idA = a.spellID or a.itemID or 0
        local idB = b.spellID or b.itemID or 0
        return idA < idB
    end)
    
    local dataProvider = CreateDataProvider()
    for _, alert in ipairs(listData) do
        dataProvider:Insert(alert)
    end
    Options.scrollBox:SetDataProvider(dataProvider)
    
    -- 強制原生 WowScrollBox 進行重新佈局與可見元件重繪，100% 解決新增刪除不即時更新的官方 BUG！
    if Options.scrollBox.FullUpdate then
        Options.scrollBox:FullUpdate()
    elseif Options.scrollBox.Rebuild then
        Options.scrollBox:Rebuild()
    end
end

-- 批次操作 (Select All, Deselect All, Delete All)
local function batchOperation(action)
    local saved = EAM.Modules.SavedVariables
    if not saved then return end
    
    local rawList = Options.getCurrentCategoryList()
    for id, alert in pairs(rawList) do
        local matches = false
        if Options.currentCategory == 1 then
            if alert.fromPlayer == true or alert.fromPlayer == nil then matches = true end
        elseif Options.currentCategory == 2 then
            if alert.fromPlayer == false then matches = true end
        elseif Options.currentCategory == 3 then
            matches = true
        elseif Options.currentCategory == 4 then
            matches = true
        elseif Options.currentCategory == 5 then
            matches = true
        elseif Options.currentCategory == 6 then
            matches = true
        end
        
        if matches then
            if action == "select" then
                alert.enabled = true
            elseif action == "deselect" then
                alert.enabled = false
            elseif action == "delete" then
                rawList[id] = nil
            end
        end
    end
    
    if EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.markRevisionChanged then
        EAM.Modules.SavedVariables.markRevisionChanged()
    end
    Options.notifyConfigChanged()
    if Options.currentCategory == 6 then
        notifyGroundEffectConfigChanged()
    end
    Options.refreshList()
end

-- 新增單個提醒
function Options.addAlertToCurrentCategory(id)
    local saved = EAM.Modules.SavedVariables
    if not saved then return end
    
    local ok, alertID, status
    if Options.currentCategory == 1 then
        ok, alertID, status = saved.addAuraAlert("player", id, { fromPlayer = true })
    elseif Options.currentCategory == 2 then
        ok, alertID, status = saved.addAuraAlert("player", id, { fromPlayer = false })
    elseif Options.currentCategory == 3 then
        ok, alertID, status = saved.addAuraAlert("target", id)
    elseif Options.currentCategory == 4 then
        ok, alertID, status = saved.addSpellCooldownAlert(id)
    elseif Options.currentCategory == 5 then
        ok, alertID, status = saved.addItemCooldownAlert(id)
    elseif Options.currentCategory == 6 then
        ok, alertID, status = saved.addGroundEffectAlert(id)
    end
    
    if ok then
        Options.notifyConfigChanged()
        if Options.currentCategory == 6 then
            notifyGroundEffectConfigChanged()
        end
        Options.refreshList()
        print(string.format(EAM.L.EAM_OPT_ADD_SUCCESS or "|cff00ff96EAM|r 成功新增監控提醒 [ID: %s]", id))
    else
        print(string.format(EAM.L.EAM_OPT_ADD_FAIL or "|cff00ff96EAM|r 新增監控提醒失敗: %s", tostring(status or alertID)))
    end
end

-- 刪除單個提醒
function Options.removeAlertFromCurrentCategory(id)
    local saved = EAM.Modules.SavedVariables
    if not saved then return end
    
    local ok, alertID, status
    if Options.currentCategory == 1 or Options.currentCategory == 2 then
        ok, alertID, status = saved.removeAuraAlert("player", id)
    elseif Options.currentCategory == 3 then
        ok, alertID, status = saved.removeAuraAlert("target", id)
    elseif Options.currentCategory == 4 then
        ok, alertID, status = saved.removeSpellCooldownAlert(id)
    elseif Options.currentCategory == 5 then
        ok, alertID, status = saved.removeItemCooldownAlert(id)
    elseif Options.currentCategory == 6 then
        ok, alertID, status = saved.removeGroundEffectAlert(id)
    end
    
    if ok then
        Options.notifyConfigChanged()
        if Options.currentCategory == 6 then
            notifyGroundEffectConfigChanged()
        end
        Options.refreshList()
        print(string.format(EAM.L.EAM_OPT_DEL_SUCCESS or "|cff00ff96EAM|r 成功移除監控提醒 [ID: %s]", id))
    else
        print(string.format(EAM.L.EAM_OPT_DEL_FAIL or "|cff00ff96EAM|r 移除監控提醒失敗: %s", tostring(status or alertID)))
    end
end

-- 建立通用 Checkbox
local function createCheckbox(parent, text, key, x, y, onChange)
    local cb = api.CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    setWidgetText(cb.text, text)
    
    cb:SetScript("OnShow", function(self)
        if EAM.db and EAM.db.config then
            self:SetChecked(EAM.db.config[key])
        end
    end)
    
    cb:SetScript("OnClick", function(self)
        if EAM.db and EAM.db.config then
            EAM.db.config[key] = self:GetChecked()
            if EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.markRevisionChanged then
                EAM.Modules.SavedVariables.markRevisionChanged()
            end
            local rebuildNative = true
            if onChange and onChange(self:GetChecked()) == false then
                rebuildNative = false
            end
            Options.notifyConfigChanged(rebuildNative)
        end
    end)
    return cb
end

-- 建立通用紅色按鈕
local function createRedButton(parent, text, x, y, width, height, onClick)
    local btn = api.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(btn) end
    btn:SetSize(width or 120, height or 24)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    setWidgetText(btn, text)
    
    local nTex = btn:GetNormalTexture()
    if nTex then nTex:SetVertexColor(0.8, 0.2, 0.2, 1) end
    local pTex = btn:GetPushedTexture()
    if pTex then pTex:SetVertexColor(0.6, 0.1, 0.1, 1) end
    if Theme and Theme.registerButton then Theme.registerButton(btn) end
    
    btn:SetScript("OnClick", onClick)
    return btn
end

-- 建立通用 Slider
local function createSlider(parent, text, key, minVal, maxVal, step, x, y, width, isPercent, isFloat)
    local slider = api.CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetSize(width or 160, 16)

    local sliderText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sliderText:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 5)
    setWidgetText(sliderText, text)

    local valText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 5)

    local function updateText(val)
        if isPercent then
            valText:SetText(math.floor(val * 100) .. "%")
        elseif isFloat then
            valText:SetText(string.format("%.1f", val))
        else
            valText:SetText(math.floor(val))
        end
    end

    local isTextLayoutSlider = key == "fontSizeSpellName"
        or key == "fontSizeTimeVal"
        or key == "fontSizeStack"
    local isNativeStructureSlider = key == "iconSize" or key == "iconSpacing"
    local isNativeVisualSlider = key == "cooldownSwipeAlpha"
    local function commitNativeChange()
        if not slider.eamNativeChangeDirty then
            return
        end
        slider.eamNativeChangeDirty = false
        if isTextLayoutSlider then
            Options.notifyTextLayoutChanged(true)
        elseif isNativeStructureSlider or isNativeVisualSlider then
            markAuraSettingsDirty("OPTIONS_NATIVE_STRUCTURE_CHANGED")
            Options.refreshAuraBackendStatus()
        end
    end

    slider:SetScript("OnShow", function(self)
        if EAM.db and EAM.db.config then
            local val = EAM.db.config[key]
            if val == nil then
                val = minVal
            elseif type(val) == "boolean" then
                val = val and maxVal or minVal
            elseif type(val) ~= "number" then
                val = tonumber(val) or minVal
            end
            if val < minVal then val = minVal end
            if val > maxVal then val = maxVal end
            self:SetValue(val)
            updateText(val)
        end
    end)

    slider:SetScript("OnValueChanged", function(self, val)
        if not EAM.db or not EAM.db.config then
            return
        end

        updateText(val)
        local changed = false
        local savedVariables = EAM.Modules.SavedVariables
        if key == "fontSizeTimeVal" and savedVariables and savedVariables.updateTextLayout then
            local ok, state = savedVariables.updateTextLayout("timer", nil, val)
            changed = ok == true and state == "updated"
        elseif key == "fontSizeStack" and savedVariables and savedVariables.updateTextLayout then
            local ok, state = savedVariables.updateTextLayout("applications", nil, val)
            changed = ok == true and state == "updated"
        elseif key == "cooldownSwipeAlpha" and savedVariables and savedVariables.updateConfigNumber then
            local ok, state = savedVariables.updateConfigNumber(key, val)
            changed = ok == true and state == "updated"
        elseif EAM.db.config[key] ~= val then
            EAM.db.config[key] = val
            changed = true
            if savedVariables and savedVariables.markRevisionChanged then
                savedVariables.markRevisionChanged()
            end
        end

        if changed then
            if isTextLayoutSlider then
                self.eamNativeChangeDirty = true
                Options.notifyTextLayoutChanged(false)
            elseif isNativeStructureSlider or isNativeVisualSlider then
                self.eamNativeChangeDirty = true
                Options.notifyConfigChanged(false)
            else
                Options.notifyConfigChanged()
            end
        end
    end)
    if isTextLayoutSlider or isNativeStructureSlider or isNativeVisualSlider then
        slider:HookScript("OnMouseUp", commitNativeChange)
        slider:HookScript("OnHide", commitNativeChange)
    end

    return slider
end

-- 建立 UI 主流程
local function createFrame()
    if Options.frame then
        return Options.frame
    end

    if api.InCombatLockdown and api.InCombatLockdown() then
        return nil
    end

    if Theme and EAM.db and EAM.db.config then
        Theme.setSelection(EAM.db.config.theme)
    end

    -- ==========================================
    -- 1. Main Options Frame (Left Panel, 380x600)
    -- ==========================================
    local frame = api.CreateFrame("Frame", "EAM_MainOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(380, 600)
    frame:SetPoint("LEFT", UIParent, "LEFT", 100, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0.12, 0.08, 0.06, 0.96)
    frame:SetBackdropBorderColor(0.8, 0.6, 0.4, 1)
    if Theme and Theme.registerFrame then Theme.registerFrame(frame, "window") end
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetTextColor(0.95, 0.85, 0.4, 1.0)
    title:SetText("EventAlertMod")
    if Theme and Theme.registerText then Theme.registerText(title, "title") end
    local moduleButton = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(moduleButton) end
    moduleButton:SetSize(72, 22)
    moduleButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -13)
    bindText(moduleButton, "EAM_OPT_MODULES_BTN", "功能模組")
    moduleButton:SetScript("OnClick", function()
        local modulePanel = EAM.UI and EAM.UI.ModulePanel or nil
        if modulePanel and type(modulePanel.open) == "function" then
            modulePanel.open()
        end
    end)

    local aboutButton = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(aboutButton) end
    aboutButton:SetSize(62, 22)
    aboutButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -13)
    bindText(aboutButton, "EAM_OPT_ABOUT_BTN", "關於")
    aboutButton:SetScript("OnClick", function()
        local aboutPanel = EAM.UI and EAM.UI.AboutPanel or nil
        if aboutPanel and type(aboutPanel.open) == "function" then
            aboutPanel.open()
        end
    end)

    -- 內邊框
    local inner = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    inner:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
    inner:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    inner:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    inner:SetBackdropColor(0.08, 0.05, 0.03, 0.8)
    inner:SetBackdropBorderColor(0.5, 0.35, 0.2, 0.8)
    if Theme and Theme.registerFrame then Theme.registerFrame(inner, "panel") end

    -- 頂部黃色按鈕
    local togglePosBtn = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(togglePosBtn) end
    togglePosBtn:SetSize(160, 26)
    togglePosBtn:SetPoint("TOPLEFT", inner, "TOPLEFT", 12, -10)
    bindText(togglePosBtn, "EAM_OPT_POS_AND_POWER_BTN", "圖示位置與能量設定")
    local tFont = togglePosBtn:GetFontString()
    if tFont then tFont:SetTextColor(0.95, 0.85, 0.2, 1) end
    if Theme and Theme.registerButton then Theme.registerButton(togglePosBtn) end
    local function togglePositionFrame()
        if Options.posFrame:IsShown() then
            Options.posFrame:Hide()
        else
            Options.posFrame:Show()
            Options.listFrame:Hide()
        end
    end
    togglePosBtn:SetScript("OnClick", togglePositionFrame)

    local themeDropdown = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(themeDropdown) end
    themeDropdown:SetSize(150, 22)
    themeDropdown:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -12, -10)
    Options.themeDropdown = themeDropdown

    local themeMenu = api.CreateFrame("Frame", nil, inner, "BackdropTemplate")
    themeMenu:SetSize(180, (#(Theme and Theme.ThemeOptions or {}) * 22) + 8)
    themeMenu:SetPoint("TOPRIGHT", themeDropdown, "BOTTOMRIGHT", 0, -2)
    themeMenu:SetFrameStrata("DIALOG")
    themeMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    themeMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
    themeMenu:SetBackdropBorderColor(0.6, 0.4, 0.2, 1)
    if Theme and Theme.registerFrame then Theme.registerFrame(themeMenu, "menu") end
    themeMenu:Hide()
    Options.themeMenu = themeMenu

    local themeOptions = Theme and Theme.ThemeOptions or {}
    for index = 1, #themeOptions do
        local option = themeOptions[index]
        local menuButton = api.CreateFrame("Button", nil, themeMenu)
        menuButton:SetSize(144, 20)
        menuButton:SetPoint("TOPLEFT", themeMenu, "TOPLEFT", 3, -3 - (index - 1) * 22)
        menuButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        if Theme and Theme.registerButton then Theme.registerButton(menuButton or menuBtn) end
        local menuButtonText = menuButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        menuButtonText:SetPoint("LEFT", menuButton, "LEFT", 6, 0)
        bindText(menuButtonText, option.labelKey, option.label)
        if Theme and Theme.registerText then Theme.registerText(menuButtonText, "button") end
        menuButton:SetScript("OnClick", function()
            local saved = EAM.Modules and EAM.Modules.SavedVariables
            if saved and saved.updateTheme then
                local ok, status = saved.updateTheme(option.value)
                if ok and Theme and Theme.setSelection then
                    local applied, applyStatus = Theme.setSelection(option.value)
                    Options.refreshThemeDropdown()
                    if status == "updated" and applied then
                        print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_THEME_CHANGED or "Theme applied."))
                    elseif applyStatus == "combatDeferred" then
                        print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_THEME_COMBAT or "Theme will apply after combat."))
                    end
                end
            end
            themeMenu:Hide()
        end)
    end
    themeDropdown:SetScript("OnClick", function()
        if themeMenu:IsShown() then
            themeMenu:Hide()
        else
            themeMenu:Show()
        end
    end)
    Options.refreshThemeDropdown()

    -- 6 個核心複選框
    createCheckbox(inner, localized("EAM_OPT_ENABLE_FRAME", "啟用提醒框架"), "showFrame", 12, -46)
    createCheckbox(inner, localized("EAM_OPT_SHOW_SPELL_NAME", "顯示法術名稱"), "showSpellName", 180, -46)
    createCheckbox(inner, localized("EAM_OPT_SHOW_TIME_VAL", "顯示倒數秒數"), "showTimeVal", 12, -74)
    local textLayoutButton = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(textLayoutButton) end
    textLayoutButton:SetSize(160, 24)
    textLayoutButton:SetPoint("TOPLEFT", inner, "TOPLEFT", 180, -70)
    bindText(textLayoutButton, "EAM_OPT_TEXT_LAYOUT_BTN", "倒數／堆疊位置設定")
    textLayoutButton:SetScript("OnClick", togglePositionFrame)
    createCheckbox(inner, localized("EAM_OPT_SHOW_FLASH", "啟用全螢幕閃爍"), "showFlash", 12, -102)
    createCheckbox(
        inner,
        localized("EAM_OPT_SHOW_SOUND", "啟用音效警告"),
        "showSound",
        180,
        -102,
        function()
            notifyAuraSoundChanged()
            return false
        end
    )

    -- 自製 Sound Dropdown
    local soundDropdown = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(soundDropdown) end
    soundDropdown:SetSize(140, 22)
    soundDropdown:SetPoint("TOPLEFT", inner, "TOPLEFT", 12, -136)
    soundDropdown:SetText((EAM.L.EAM_OPT_SOUND_PREFIX or "音效: ") .. "ShayBell")
    Options.soundDropdown = soundDropdown

    local playSoundBtn = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(playSoundBtn) end
    playSoundBtn:SetSize(60, 22)
    playSoundBtn:SetPoint("LEFT", soundDropdown, "RIGHT", 6, 0)
    bindText(playSoundBtn, "EAM_OPT_TEST_BTN", "測試")

    local soundMenu = api.CreateFrame("Frame", nil, inner, "BackdropTemplate")
    soundMenu:SetSize(140, 268)
    soundMenu:SetPoint("TOPLEFT", soundDropdown, "BOTTOMLEFT", 0, -2)
    soundMenu:SetFrameStrata("DIALOG")
    soundMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    soundMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
    soundMenu:SetBackdropBorderColor(0.6, 0.4, 0.2, 1)
    soundMenu:Hide()

    -- 12 種經典音效選單

    for idx, sName in ipairs(soundNames) do
        local menuBtn = api.CreateFrame("Button", nil, soundMenu)
        menuBtn:SetSize(134, 20)
        menuBtn:SetPoint("TOPLEFT", soundMenu, "TOPLEFT", 3, -3 - (idx - 1) * 22)
        menuBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        if Theme and Theme.registerButton then Theme.registerButton(menuButton or menuBtn) end
        
        local menuBtnText = menuBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        menuBtnText:SetPoint("LEFT", menuBtn, "LEFT", 6, 0)
        menuBtnText:SetText(sName)
        if Theme and Theme.registerText then Theme.registerText(menuBtnText, "button") end
        
        menuBtn:SetScript("OnClick", function()
            if EAM.db and EAM.db.config then
                EAM.db.config.soundName = sName
                if EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.markRevisionChanged then
                    EAM.Modules.SavedVariables.markRevisionChanged()
                end
                Options.refreshSoundDropdown()
                notifyAuraSoundChanged()
                Options.notifyConfigChanged(false)
            end
            soundMenu:Hide()
        end)
    end

    soundDropdown:SetScript("OnClick", function()
        if soundMenu:IsShown() then
            soundMenu:Hide()
        else
            soundMenu:Show()
        end
    end)

    -- 語系選擇會保存並同步原地刷新 EAM.L 與已綁定的 EAM 自有 UI。
    local languageDropdown = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(languageDropdown) end
    languageDropdown:SetSize(124, 22)
    languageDropdown:SetPoint("TOPLEFT", inner, "TOPLEFT", 220, -136)
    Options.languageDropdown = languageDropdown

    local languageMenu = api.CreateFrame("Frame", nil, inner, "BackdropTemplate")
    languageMenu:SetSize(124, 138)
    languageMenu:SetPoint("TOPLEFT", languageDropdown, "BOTTOMLEFT", 0, -2)
    languageMenu:SetFrameStrata("DIALOG")
    languageMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    languageMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
    languageMenu:SetBackdropBorderColor(0.6, 0.4, 0.2, 1)
    languageMenu:Hide()
    Options.languageMenu = languageMenu

    local languageOptions = EAM.Locale and EAM.Locale.LanguageOptions or {}
    for index = 1, #languageOptions do
        local option = languageOptions[index]
        local menuButton = api.CreateFrame("Button", nil, languageMenu)
        menuButton:SetSize(118, 20)
        menuButton:SetPoint("TOPLEFT", languageMenu, "TOPLEFT", 3, -3 - (index - 1) * 22)
        menuButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        if Theme and Theme.registerButton then Theme.registerButton(menuButton or menuBtn) end

        local menuButtonText = menuButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        menuButtonText:SetPoint("LEFT", menuButton, "LEFT", 6, 0)
        bindText(menuButtonText, option.labelKey, option.label)
        if Theme and Theme.registerText then Theme.registerText(menuButtonText, "button") end

        menuButton:SetScript("OnClick", function()
            local saved = EAM.Modules and EAM.Modules.SavedVariables
            if saved and saved.updateLanguage then
                local ok, status = saved.updateLanguage(option.value)
                if ok then
                    Options.refreshLanguageDropdown()
                    if status == "updated" then
                        print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_LANGUAGE_RELOAD or "Language applied immediately and saved."))
                    end
                end
            end
            languageMenu:Hide()
        end)
    end

    languageDropdown:SetScript("OnClick", function()
        if languageMenu:IsShown() then
            languageMenu:Hide()
        else
            languageMenu:Show()
        end
    end)
    Options.refreshLanguageDropdown()

    playSoundBtn:SetScript("OnClick", function()
        local sName = (EAM.db and EAM.db.config and EAM.db.config.soundName) or "ShayBell"
        local asset = soundAssets[sName] or 568154
        PlaySoundFile(asset, "Master")
    end)

    -- 7 個額外選項 Checkboxes
    createCheckbox(inner, localized("EAM_OPT_ALLOW_ESC", "啟用 ESC 鍵關閉"), "allowEscCancel", 12, -170)
    createCheckbox(inner, localized("EAM_OPT_SHOW_EXTRA_ALERT", "顯示額外輔助提醒"), "showExtraAlert", 180, -170)
    
    createCheckbox(inner, localized("EAM_OPT_COOLDOWN_REMOVE", "冷卻完成移除光環"), "cooldownRemoveAura", 12, -198)
    createCheckbox(inner, localized("EAM_OPT_SHOW_SCD_OUTSIDE", "非戰鬥顯示技能冷卻"), "showSCDOutsideCombat", 180, -198)
    
    createCheckbox(inner, localized("EAM_OPT_GLOW_SCD", "可用時高亮技能冷卻"), "glowSCDWhenUsable", 12, -226)
    createCheckbox(inner, localized("EAM_OPT_SHOW_DK_RUNE", "顯示 DK 符文提醒"), "showDKRune", 180, -226)
    
    -- 物品冷卻總開關已移至 ModulePanel，避免 legacy mirror 與 canonical toggle 雙寫。
    local nativeAuraStatusLabel = inner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nativeAuraStatusLabel:SetPoint("TOPLEFT", inner, "TOPLEFT", 180, -250)
    nativeAuraStatusLabel:SetWidth(112)
    nativeAuraStatusLabel:SetJustifyH("LEFT")
    Options.nativeAuraStatusLabel = nativeAuraStatusLabel

    local nativeAuraRebuildButton = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(nativeAuraRebuildButton) end
    nativeAuraRebuildButton:SetSize(54, 20)
    nativeAuraRebuildButton:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -8, -246)
    bindText(nativeAuraRebuildButton, "EAM_OPT_AURA_APPLY", "套用")
    nativeAuraRebuildButton:SetScript("OnClick", function()
        local service = EAM.Services.AuraContainerService
        if service and service.requestRebuild then
            service.requestRebuild("OPTIONS_MANUAL_REBUILD")
        end
        Options.refreshAuraBackendStatus()
    end)
    Options.refreshAuraBackendStatus()

    -- 6 個類別按鈕 (物品冷卻獨立分類，排版壓縮至 32px 以容納第 6 個按鈕而不重疊)
    -- 7 個類別按鈕 (地面效果獨立為第 6 分類，滑桿與能量設定改為第 7 分類)
    local categories = {
        { key = "EAM_OPT_CAT_SELF", fallback = "自端增益/減益提醒 (Self)" },
        { key = "EAM_OPT_CAT_CLASS", fallback = "跨職業增益/減益提醒 (Class)" },
        { key = "EAM_OPT_CAT_TARGET", fallback = "目標增益/減益提醒 (Target)" },
        { key = "EAM_OPT_CAT_SPELL_CD", fallback = "技能冷卻監控設定 (Spell CD)" },
        { key = "EAM_OPT_CAT_ITEM_CD", fallback = "物品冷卻監控設定 (Item CD)" },
        { key = "EAM_OPT_CAT_GROUND", fallback = "地面技能與效果設定 (Ground Effect)" },
        { key = "EAM_OPT_CAT_LAYOUT", fallback = "圖示位置與能量設定 (Layout & Power)" },
    }
    Options.categoryDefinitions = categories

    for idx, category in ipairs(categories) do
        createRedButton(inner, localized(category.key, category.fallback), 12, -264 - (idx - 1) * 32, 332, 28, function()
            if idx <= 6 then
                Options.currentCategory = idx
                Options.listFrame:Show()
                if Options.posFrame then Options.posFrame:Hide() end

                if Options.listTitleText then
                    bindText(Options.listTitleText, category.key, category.fallback)
                end
                Options.refreshList()
            else
                if Options.posFrame then
                    Options.posFrame:Show()
                end
                if Options.listFrame then
                    Options.listFrame:Hide()
                end
            end
        end)
    end

    -- 底部操作按鈕：關閉、診斷、流程驗證
    createRedButton(inner, localized("EAM_OPT_CLOSE_BTN", "關閉設定 (Close)"), 12, -490, 104, 36, function()
        frame:Hide()
    end)

    createRedButton(inner, localized("EAM_OPT_DEBUG_BTN", "除錯診斷 (Debug)"), 122, -490, 104, 36, function()
        if EAM.Debug.PromptExport and EAM.Debug.PromptExport.openWindow then
            EAM.Debug.PromptExport.openWindow()
        else
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_DEBUG_NOT_LOADED or "除錯診斷模組尚未加載！"))
        end
    end)

    createRedButton(inner, localized("EAM_OPT_FLOW_TEST_BTN", "流程測試"), 232, -490, 112, 36, function()
        if EAM.Debug.FlowTestPanel and EAM.Debug.FlowTestPanel.open then
            EAM.Debug.FlowTestPanel.open()
        else
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_FLOW_STATUS_UNAVAILABLE or "流程測試模組尚未載入。"))
        end
    end)

    Options.frame = frame


    -- ===================================================
    -- 2. Position & Energy Frame (Right Sliding Panel)
    -- ===================================================
    -- ===================================================
    -- 2. Position & Energy Frame (Right Sliding Panel)
    -- ===================================================
    local posFrame = api.CreateFrame("Frame", "EAM_PositionOptionsFrame", frame, "BackdropTemplate")
    posFrame:SetSize(560, 600)
    posFrame:SetPoint("LEFT", frame, "RIGHT", 2, 0)
    posFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    posFrame:SetBackdropColor(0.12, 0.08, 0.06, 0.96)
    posFrame:SetBackdropBorderColor(0.8, 0.6, 0.4, 1)
    if Theme and Theme.registerFrame then Theme.registerFrame(posFrame, "window") end
    posFrame:Hide()

    local posTitle = posFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    posTitle:SetPoint("TOP", posFrame, "TOP", 0, -14)
    posTitle:SetTextColor(0.95, 0.85, 0.4, 1.0)
    bindText(posTitle, "EAM_OPT_POS_AND_POWER_BTN", "圖示位置與能量設定")

    local posInner = api.CreateFrame("Frame", nil, posFrame, "BackdropTemplate")
    posInner:SetPoint("TOPLEFT", posFrame, "TOPLEFT", 12, -40)
    posInner:SetPoint("BOTTOMRIGHT", posFrame, "BOTTOMRIGHT", -12, 12)
    posInner:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    posInner:SetBackdropColor(0.08, 0.05, 0.03, 0.8)
    posInner:SetBackdropBorderColor(0.5, 0.35, 0.2, 0.8)

    -- ---------------------------------------------------
    -- 【左側欄位】：10 個 Sliders 與 7 大告警框架成長方向下拉選單
    -- ---------------------------------------------------
    createSlider(posInner, localized("EAM_OPT_SLIDER_ICON_SIZE", "圖示大小 (Icon Size)"), "iconSize", 20, 100, 1, 16, -25, 110)
    createSlider(posInner, localized("EAM_OPT_SLIDER_ICON_SPACING", "水平間距 (Horizontal Spacing)"), "iconSpacing", -200, 200, 1, 140, -25, 110)
    
    createSlider(posInner, localized("EAM_OPT_SLIDER_VERT_SPACING", "垂直間距 (Vertical Spacing)"), "verticalSpacing", -200, 200, 1, 16, -75, 110)
    createSlider(posInner, localized("EAM_OPT_SLIDER_DEBUFF_RED", "自端減益色度 (Self Debuff Red)"), "selfDebuffRed", 0.0, 1.0, 0.05, 140, -75, 110, true)
    
    createSlider(posInner, localized("EAM_OPT_SLIDER_DEBUFF_GREEN", "目標減益色度 (Target Debuff Green)"), "targetDebuffGreen", 0.0, 1.0, 0.05, 16, -125, 110, true)
    createSlider(posInner, localized("EAM_OPT_SLIDER_EXECUTE_LIMIT", "斬殺血量閾值 (Execute Limit)"), "bossExecuteThreshold", 0.0, 1.0, 0.05, 140, -125, 110, true)
    createCheckbox(posInner, localized("EAM_OPT_ENABLE_EXECUTE", "啟用斬殺線"), "enableBossExecute", 140, -150)

    createSlider(posInner, localized("EAM_OPT_SLIDER_FONT_SPELL", "法術名稱字型 (Spell Font)"), "fontSizeSpellName", 8, 32, 1, 16, -175, 110)
    createSlider(posInner, localized("EAM_OPT_SLIDER_FONT_CD", "秒數倒數字型 (CD Font)"), "fontSizeTimeVal", 8, 32, 1, 140, -175, 110)
    
    createSlider(posInner, localized("EAM_OPT_SLIDER_FONT_STACK", "堆疊層數字型 (Stack Font)"), "fontSizeStack", 8, 32, 1, 16, -225, 110)
    createSlider(posInner, localized("EAM_OPT_SLIDER_SHADOW_ALPHA", "倒數轉圈透明度 (Swipe Alpha)"), "cooldownSwipeAlpha", 0, 1, 0.05, 140, -225, 110, true)

    -- 告警框架成長方向設定標題
    local dirTitle = posInner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dirTitle:SetPoint("TOPLEFT", posInner, "TOPLEFT", 16, -270)
    dirTitle:SetTextColor(0.95, 0.85, 0.4, 1.0)
    bindText(dirTitle, "EAM_OPT_DIR_TITLE", "告警框架圖示成長方向設定")

    local fontLabel = posInner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontLabel:SetPoint("TOPLEFT", posInner, "TOPLEFT", 350, -270)
    fontLabel:SetTextColor(0.85, 0.75, 0.65, 1)
    bindText(fontLabel, "EAM_OPT_FONT_PREFIX", "字型：")

    local fontDropdown = api.CreateFrame("Button", nil, posInner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(fontDropdown) end
    fontDropdown:SetSize(160, 20)
    fontDropdown:SetPoint("TOPLEFT", posInner, "TOPLEFT", 350, -284)
    Options.fontDropdown = fontDropdown

    local fontOptions = EAM.Constants and EAM.Constants.FONT_FAMILY_OPTIONS or {}
    local fontMenu = api.CreateFrame("Frame", nil, posInner, "BackdropTemplate")
    fontMenu:SetSize(176, (#fontOptions * 22) + 8)
    fontMenu:SetPoint("TOPLEFT", fontDropdown, "BOTTOMLEFT", 0, -2)
    fontMenu:SetFrameStrata("DIALOG")
    fontMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    fontMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
    fontMenu:SetBackdropBorderColor(0.6, 0.4, 0.2, 1)
    if Theme and Theme.registerFrame then Theme.registerFrame(fontMenu, "menu") end
    fontMenu:Hide()
    Options.fontMenu = fontMenu

    for index = 1, #fontOptions do
        local option = fontOptions[index]
        local menuButton = api.CreateFrame("Button", nil, fontMenu)
        menuButton:SetSize(170, 20)
        menuButton:SetPoint("TOPLEFT", fontMenu, "TOPLEFT", 3, -3 - (index - 1) * 22)
        menuButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        if Theme and Theme.registerButton then Theme.registerButton(menuButton) end
        local menuButtonText = menuButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        menuButtonText:SetPoint("LEFT", menuButton, "LEFT", 6, 0)
        bindText(menuButtonText, option.labelKey, option.value)
        if Theme and Theme.registerText then Theme.registerText(menuButtonText, "button") end
        menuButton:SetScript("OnClick", function()
            local saved = EAM.Modules and EAM.Modules.SavedVariables
            if saved and saved.updateFontFamily then
                local ok, status = saved.updateFontFamily(option.value)
                if ok and status == "updated" then
                    Options.refreshFontDropdown()
                    Options.notifyTextLayoutChanged(true)
                elseif ok then
                    Options.refreshFontDropdown()
                end
            end
            fontMenu:Hide()
        end)
    end
    fontDropdown:SetScript("OnClick", function()
        if fontMenu:IsShown() then
            fontMenu:Hide()
        else
            fontMenu:Show()
        end
    end)
    Options.refreshFontDropdown()

    -- 輔助下拉選單建立器 (無 Taint Backdrop 單純 Lua 下拉選單)
    local function createDirectionDropdown(parent, labelText, frameName, x, y)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        label:SetTextColor(0.85, 0.75, 0.65, 1)
        setWidgetText(label, labelText)

        local btn = api.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        if Theme and Theme.registerButton then Theme.registerButton(btn) end
        btn:SetSize(110, 20)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 14)
        
        local directions = {
            localized("EAM_OPT_DIR_RIGHT", "往右 (→)"),
            localized("EAM_OPT_DIR_LEFT", "往左 (←)"),
            localized("EAM_OPT_DIR_UP", "往上 (↑)"),
            localized("EAM_OPT_DIR_DOWN", "往下 (↓)"),
        }

        local function updateBtnText()
            if EAM.db and EAM.db.layout and EAM.db.layout.frames and EAM.db.layout.frames[frameName] then
                local dirIdx = EAM.db.layout.frames[frameName].growDirection or 1
                setWidgetText(btn, directions[dirIdx] or directions[1])
            end
        end

        btn:SetScript("OnShow", updateBtnText)

        local menu = api.CreateFrame("Frame", nil, parent, "BackdropTemplate")
        menu:SetSize(110, 84)
        menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        menu:SetFrameStrata("DIALOG")
        menu:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 12, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        menu:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
        menu:SetBackdropBorderColor(0.6, 0.4, 0.2, 1)
        menu:Hide()

        for idx, direction in ipairs(directions) do
            local menuBtn = api.CreateFrame("Button", nil, menu)
            menuBtn:SetSize(104, 18)
            menuBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 3, -3 - (idx - 1) * 20)
            menuBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            if Theme and Theme.registerButton then Theme.registerButton(menuButton or menuBtn) end
            
            local menuBtnText = menuBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            menuBtnText:SetPoint("LEFT", menuBtn, "LEFT", 6, 0)
            setWidgetText(menuBtnText, direction)
            if Theme and Theme.registerText then Theme.registerText(menuBtnText, "button") end
            
            menuBtn:SetScript("OnClick", function()
                if EAM.db and EAM.db.layout and EAM.db.layout.frames and EAM.db.layout.frames[frameName] then
                    EAM.db.layout.frames[frameName].growDirection = idx
                    updateBtnText()
                    if EAM.UI.Renderer and EAM.UI.Renderer.requestLayout then
                        EAM.UI.Renderer.requestLayout(frameName)
                    end
                end
                menu:Hide()
            end)
        end

        btn:SetScript("OnClick", function()
            if menu:IsShown() then
                menu:Hide()
            else
                menu:Show()
            end
        end)

        return btn
    end

    -- 建立 7 大框架成長方向選單
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_SELF_AURA", "自身光環成長"), "selfAura", 16, -295)
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_TARGET_AURA", "目標光環成長"), "targetAura", 140, -295)
    
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_SPELL_COOLDOWN", "技能冷卻成長"), "spellCooldown", 16, -335)
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_ITEM_COOLDOWN", "物品冷卻成長"), "itemCooldown", 140, -335)
    
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_GROUND_EFFECT", "地面效果成長"), "groundEffect", 16, -375)
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_TOTEM", "圖騰監控成長"), "totem", 140, -375)
    
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_CLASS_POWER", "職業能量成長"), "classPower", 16, -415)

    -- 倒數與 applications 共用 21 點白名單位置，避免任意字串進入 SetPoint。
    local function createTextPlacementDropdown(parent, labelText, kind, x, y)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        label:SetTextColor(0.85, 0.75, 0.65, 1)
        setWidgetText(label, labelText)

        local btn = api.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        if Theme and Theme.registerButton then Theme.registerButton(btn) end
        btn:SetSize(110, 20)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 14)

        local function placementText(placement)
            local key = "EAM_PLACEMENT_" .. placement
            return EAM.L[key] or placement
        end

        local function updateBtnText()
            if EAM.db and EAM.db.config then
                local placement = EAM.UI.TextPlacement.getPlacement(EAM.db.config, kind)
                bindText(btn, "EAM_PLACEMENT_" .. placement, placement)
            end
        end

        btn:SetScript("OnShow", updateBtnText)

        local menu = api.CreateFrame("Frame", nil, parent, "BackdropTemplate")
        menu:SetSize(236, 226)
        menu:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 2)
        menu:SetFrameStrata("DIALOG")
        menu:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 12, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        menu:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
        menu:SetBackdropBorderColor(0.6, 0.4, 0.2, 1)
        menu:Hide()

        local options = EAM.UI.TextPlacement.orderedPlacements
        for index = 1, #options do
            local placement = options[index]
            local column = math.floor((index - 1) / 11)
            local row = (index - 1) % 11
            local menuButton = api.CreateFrame("Button", nil, menu)
            menuButton:SetSize(112, 18)
            menuButton:SetPoint("TOPLEFT", menu, "TOPLEFT", 3 + column * 116, -3 - row * 20)
            menuButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            if Theme and Theme.registerButton then Theme.registerButton(menuButton or menuBtn) end

            local menuButtonText = menuButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            menuButtonText:SetPoint("LEFT", menuButton, "LEFT", 5, 0)
            bindText(menuButtonText, "EAM_PLACEMENT_" .. placement, placement)
            if Theme and Theme.registerText then Theme.registerText(menuButtonText, "button") end

            menuButton:SetScript("OnClick", function()
                local savedVariables = EAM.Modules.SavedVariables
                if savedVariables and savedVariables.updateTextLayout then
                    local ok, state = savedVariables.updateTextLayout(kind, placement, nil)
                    if ok and state == "updated" then
                        updateBtnText()
                        Options.notifyTextLayoutChanged(true)
                    end
                end
                menu:Hide()
            end)
        end

        btn:SetScript("OnClick", function()
            if menu:IsShown() then
                menu:Hide()
            else
                menu:Show()
            end
        end)
    end

    createTextPlacementDropdown(posInner, localized("EAM_OPT_TIMER_ALIGN", "秒數倒數位置"), "timer", 16, -455)
    createTextPlacementDropdown(posInner, localized("EAM_OPT_APPLICATIONS_ALIGN", "堆疊層數位置"), "applications", 140, -455)

    -- ---------------------------------------------------
    -- 【右側欄位】：職業特殊能量條件監控
    -- ---------------------------------------------------
    local powerTitle = posInner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    powerTitle:SetPoint("TOPLEFT", posInner, "TOPLEFT", 280, -15)
    powerTitle:SetTextColor(0.95, 0.85, 0.4, 1.0)
    bindText(powerTitle, "EAM_OPT_POWER_MONITOR_TITLE", "職業特殊能量條件監控")

    -- 20 個 Checkboxes 兩列排版 (x=280 與 x=410，y 從 -40 開始縱向 10 排)
    local powersList = {
        { localeKey = "EA_SPELL_POWER_NAME.HolyPower", fallback = "聖能", key = "powerHoly" },
        { localeKey = "EA_SPELL_POWER_NAME.SoulShards", fallback = "靈魂碎片", key = "powerShard" },
        { localeKey = "EA_SPELL_POWER_NAME.ComboPoints", fallback = "連擊點", key = "powerCombo" },
        { localeKey = "EA_SPELL_POWER_NAME.Chi", fallback = "真氣", key = "powerChi" },
        { localeKey = "EA_SPELL_POWER_NAME.RunicPower", fallback = "符文能量", key = "powerRunic" },
        { localeKey = "EA_SPELL_POWER_NAME.Rage", fallback = "狂怒值", key = "powerRage" },
        { localeKey = "EA_SPELL_POWER_NAME.Insanity", fallback = "瘋狂值", key = "powerInsanity" },
        { localeKey = "EA_SPELL_POWER_NAME.LunarPower", fallback = "星界能量", key = "powerAstral" },
        { localeKey = "EA_SPELL_POWER_NAME.Maelstrom", fallback = "漩渦值", key = "powerMaelstrom" },
        { localeKey = "EA_SPELL_POWER_NAME.LifeBloom", fallback = "生命之花", key = "powerLifebloom" },
        { localeKey = "EA_SPELL_POWER_NAME.Energy", fallback = "能量值", key = "powerEnergy" },
        { localeKey = "EA_SPELL_POWER_NAME.Focus", fallback = "集中值", key = "powerFocus" },
        { localeKey = "EA_SPELL_POWER_NAME.ArcaneCharges", fallback = "秘法充能", key = "powerArcane" },
        { localeKey = "EA_SPELL_POWER_NAME.Runes", fallback = "符文", key = "powerRunes" },
        { localeKey = "EA_SPELL_POWER_NAME.Fury", fallback = "惡魔怒氣", key = "powerFury" },
        { localeKey = "EAM_OPT_POWER_FRENZY", fallback = "狂暴值", key = "powerFrenzy" },
        { localeKey = "EA_SPELL_POWER_NAME.Mana", fallback = "法力值", key = "powerMana" },
        { localeKey = "EA_SPELL_POWER_NAME.FocusPet", fallback = "寵物集中", key = "powerPetFocus" },
        { localeKey = "EAM_OPT_POWER_PET_ENERGY", fallback = "寵物能量", key = "powerPetEnergy" },
        { localeKey = "EA_SPELL_POWER_NAME.Vigor", fallback = "活力值", key = "powerVigor" },
    }

    for idx, pInfo in ipairs(powersList) do
        local isRightCol = (idx > 10)
        local rowIdx = (idx - 1) % 10
        local cx = isRightCol and 410 or 280
        local cy = -40 - (rowIdx * 22)
        createCheckbox(posInner, localized(pInfo.localeKey, pInfo.fallback), pInfo.key, cx, cy, function()
            -- 勾選變動時，即時刷新職業能量 Service 的顯示狀態
            if EAM.Services.ClassPowerService and EAM.Services.ClassPowerService.updatePower then
                EAM.Services.ClassPowerService.updatePower()
            end
        end)
    end

    -- ---------------------------------------------------
    -- 【底部按鈕】：對稱分欄，重置 7 個框架的所有狀態
    -- ---------------------------------------------------
    createRedButton(posInner, localized("EAM_OPT_MOVE_FRAME_BTN", "移動提醒框架"), 16, -516, 240, 28, function()
        if EAM.UI.Renderer and EAM.UI.Renderer.toggleAnchors then
            EAM.UI.Renderer.toggleAnchors()
        else
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_MOVE_MODE_ON_PRINT or "移動模式已啟動（請使用 /eam 拖曳）"))
        end
    end)

    createRedButton(posInner, localized("EAM_OPT_RESET_FRAME_BTN", "重設所有圖示與位置"), 280, -516, 240, 28, function()
        if EAM.db and EAM.db.layout then
            EAM.db.layout.iconSize = 40
            EAM.db.layout.spacing = 6
            
            local defaults = EAM.Modules.SavedVariables.defaults
            if defaults and defaults.layout and defaults.layout.frames then
                EAM.db.layout.frames = {}
                for fName, fDef in pairs(defaults.layout.frames) do
                    EAM.db.layout.frames[fName] = {
                        growDirection = fDef.growDirection,
                        x = fDef.x,
                        y = fDef.y,
                        point = fDef.point,
                    }
                end
            end
            
            Options.notifyConfigChanged()
            
            -- 重置 7 個告警框架 Layout
            if EAM.UI.Renderer and EAM.UI.Renderer.requestLayout then
                for fName in pairs(EAM.Constants.ALERT_FRAME_TYPES) do
                    EAM.UI.Renderer.requestLayout(fName)
                end
            end
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_RESET_FRAME_SUCCESS or "已將所有告警框架位置與成長方向重設為預設配置。"))
        end
    end)

    Options.posFrame = posFrame


    -- ===================================================
    -- 3. Spell/Item List Frame (Right Scrolling List)
    -- ===================================================
    local listFrame = api.CreateFrame("Frame", "EAM_SpellListOptionsFrame", frame, "BackdropTemplate")
    listFrame:SetSize(400, 600)
    listFrame:SetPoint("LEFT", frame, "RIGHT", 2, 0)
    listFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    listFrame:SetBackdropColor(0.12, 0.08, 0.06, 0.96)
    listFrame:SetBackdropBorderColor(0.8, 0.6, 0.4, 1)
    if Theme and Theme.registerFrame then Theme.registerFrame(listFrame, "window") end
    listFrame:Hide()

    local listTitle = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    listTitle:SetPoint("TOP", listFrame, "TOP", 0, -14)
    listTitle:SetTextColor(0.95, 0.85, 0.4, 1.0)
    bindText(listTitle, "EAM_OPT_LIST_TITLE", "法術提醒清單設定")
    Options.listTitleText = listTitle

    local listInner = api.CreateFrame("Frame", nil, listFrame, "BackdropTemplate")
    listInner:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 12, -40)
    listInner:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -12, 12)
    listInner:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    listInner:SetBackdropColor(0.08, 0.05, 0.03, 0.8)
    listInner:SetBackdropBorderColor(0.5, 0.35, 0.2, 0.8)

    -- 頂部批次 Action 按鈕
    local selectAllBtn = api.CreateFrame("Button", nil, listInner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(selectAllBtn) end
    selectAllBtn:SetSize(86, 22)
    selectAllBtn:SetPoint("TOPLEFT", listInner, "TOPLEFT", 8, -8)
    bindText(selectAllBtn, "EAM_OPT_SELECT_ALL", "全部選擇")
    selectAllBtn:SetScript("OnClick", function() batchOperation("select") end)

    local deselectAllBtn = api.CreateFrame("Button", nil, listInner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(deselectAllBtn) end
    deselectAllBtn:SetSize(86, 22)
    deselectAllBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 4, 0)
    bindText(deselectAllBtn, "EAM_OPT_DESELECT_ALL", "全部取消")
    deselectAllBtn:SetScript("OnClick", function() batchOperation("deselect") end)

    local defaultsBtn = api.CreateFrame("Button", nil, listInner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(defaultsBtn) end
    defaultsBtn:SetSize(86, 22)
    defaultsBtn:SetPoint("LEFT", deselectAllBtn, "RIGHT", 4, 0)
    bindText(defaultsBtn, "EAM_OPT_DEFAULTS_BTN", "預設值")
    defaultsBtn:SetScript("OnClick", function()
        local classToken = select(2, UnitClass("player"))
        local classData = EAM.Data.SpellArray and EAM.Data.SpellArray[classToken]
        if classData then
            local saved = EAM.Modules.SavedVariables
            if saved then
                local function loadDefaultList(sourceList)
                    if not sourceList then return end
                    for _, sp in ipairs(sourceList) do
                        if Options.currentCategory == 1 or Options.currentCategory == 2 then
                            if sp.type == "aura" and sp.unit == "player" then
                                local fromPl = (Options.currentCategory == 1)
                                saved.addAuraAlert("player", sp.id, { fromPlayer = fromPl })
                            end
                        elseif Options.currentCategory == 3 then
                            if sp.type == "aura" and sp.unit == "target" then
                                saved.addAuraAlert("target", sp.id)
                            end
                        elseif Options.currentCategory == 4 then
                            if sp.type == "spellCooldown" then
                                saved.addSpellCooldownAlert(sp.id)
                            end
                        end
                    end
                end

                loadDefaultList(classData.general)
                for i = 1, 4 do
                    loadDefaultList(classData[i])
                end
                
                print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_DEFAULTS_SUCCESS or "成功加載當前職業的熱門常用預設法術！"))
                Options.notifyConfigChanged()
                Options.refreshList()
            end
        else
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_DEFAULTS_FAIL or "未找到當前職業的預設法術配置。"))
        end
    end)

    local deleteAllBtn = api.CreateFrame("Button", nil, listInner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(deleteAllBtn) end
    deleteAllBtn:SetSize(86, 22)
    deleteAllBtn:SetPoint("LEFT", defaultsBtn, "RIGHT", 4, 0)
    bindText(deleteAllBtn, "EAM_OPT_DELETE_ALL", "全部刪除")
    deleteAllBtn:SetScript("OnClick", function() batchOperation("delete") end)

    -- 專精篩選下拉選單按鈕
    local specDropdown = api.CreateFrame("Button", nil, listInner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(specDropdown) end
    specDropdown:SetSize(160, 22)
    specDropdown:SetPoint("TOPLEFT", listInner, "TOPLEFT", 8, -36)
    Options.specDropdown = specDropdown
    Options.refreshSpecDropdown()

    local specMenu = api.CreateFrame("Frame", nil, listInner, "BackdropTemplate")
    specMenu:SetFrameStrata("DIALOG")
    specMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    specMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
    specMenu:SetBackdropBorderColor(0.6, 0.4, 0.2, 1)
    specMenu:Hide()

    local CLASS_TOKEN_TO_ID = {
        WARRIOR = 1,
        PALADIN = 2,
        HUNTER = 3,
        ROGUE = 4,
        PRIEST = 5,
        DEATHKNIGHT = 6,
        SHAMAN = 7,
        MAGE = 8,
        WARLOCK = 9,
        MONK = 10,
        DRUID = 11,
        DEMONHUNTER = 12,
        EVOKER = 13,
    }

    local function rebuildSpecMenu()
        if specMenu.buttons then
            for _, b in ipairs(specMenu.buttons) do b:Hide() end
        end
        specMenu.buttons = {}

        local classToken = select(2, UnitClass("player"))
        local classData = EAM.Data.SpellArray and EAM.Data.SpellArray[classToken]
        local menuItems = {
            { name = EAM.L.EAM_OPT_FILTER_ALL_VAL or "全部法術", val = nil },
            { name = EAM.L.EAM_OPT_FILTER_GENERAL or "通用技能/自訂", val = 0 }
        }
        if classData and classData.specs then
            local classID = CLASS_TOKEN_TO_ID[classToken]
            for idx, specName in ipairs(classData.specs) do
                local localizedSpecName
                if classID and GetSpecializationInfoForClassID then
                    local _, name = GetSpecializationInfoForClassID(classID, idx)
                    if name then
                        localizedSpecName = name
                    end
                end
                localizedSpecName = localizedSpecName or specName
                table.insert(menuItems, { name = localizedSpecName, val = idx })
            end
        end

        local selectedName = menuItems[1] and menuItems[1].name or ""
        for index = 1, #menuItems do
            if menuItems[index].val == Options.currentSpecFilter then
                selectedName = menuItems[index].name
                break
            end
        end
        Options.currentSpecFilterName = selectedName

        local menuHeight = #menuItems * 22 + 6
        specMenu:SetSize(160, menuHeight)

        for idx, item in ipairs(menuItems) do
            local menuBtn = api.CreateFrame("Button", nil, specMenu)
            menuBtn:SetSize(154, 20)
            menuBtn:SetPoint("TOPLEFT", specMenu, "TOPLEFT", 3, -3 - (idx - 1) * 22)
            menuBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            if Theme and Theme.registerButton then Theme.registerButton(menuButton or menuBtn) end
            
            local btnText = menuBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btnText:SetPoint("LEFT", menuBtn, "LEFT", 6, 0)
            btnText:SetText(item.name)
            if Theme and Theme.registerText then Theme.registerText(btnText, "button") end
            
            menuBtn:SetScript("OnClick", function()
                Options.currentSpecFilter = item.val
                Options.currentSpecFilterName = item.name
                Options.refreshSpecDropdown()
                specMenu:Hide()
                Options.refreshList()
            end)
            table.insert(specMenu.buttons, menuBtn)
        end
    end

    Options.rebuildSpecMenu = rebuildSpecMenu

    specDropdown:SetScript("OnClick", function()
        if specMenu:IsShown() then
            specMenu:Hide()
        else
            rebuildSpecMenu()
            specMenu:SetPoint("TOPLEFT", specDropdown, "BOTTOMLEFT", 0, -2)
            specMenu:Show()
        end
    end)

    -- Scrolling List (適配物品與法術雙模式)
    local scrollBox = api.CreateFrame("Frame", nil, listInner, "WowScrollBoxList")
    scrollBox:SetSize(340, 360)
    scrollBox:SetPoint("TOPLEFT", listInner, "TOPLEFT", 8, -66)

    local scrollBar = api.CreateFrame("EventFrame", nil, listInner, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(32)
    view:SetElementInitializer("Frame", function(itemFrame, data)
        itemFrame:SetSize(340, 32)
        
        if not itemFrame.initialized then
            itemFrame.initialized = true
            
            -- 半透明背景
            itemFrame.bg = itemFrame:CreateTexture(nil, "BACKGROUND")
            itemFrame.bg:SetAllPoints(itemFrame)
            itemFrame.bg:SetColorTexture(1, 1, 1, 0.02)
            
            -- Icon
            itemFrame.icon = itemFrame:CreateTexture(nil, "ARTWORK")
            itemFrame.icon:SetSize(24, 24)
            itemFrame.icon:SetPoint("LEFT", itemFrame, "LEFT", 6, 0)
            
            -- Checkbox
            itemFrame.checkbox = api.CreateFrame("CheckButton", nil, itemFrame, "UICheckButtonTemplate")
            itemFrame.checkbox:SetSize(22, 22)
            itemFrame.checkbox:SetPoint("LEFT", itemFrame.icon, "RIGHT", 6, 0)
            
            -- Spell Name Text
            itemFrame.nameText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            itemFrame.nameText:SetPoint("LEFT", itemFrame.checkbox, "RIGHT", 6, 0)
            itemFrame.nameText:SetWidth(125)
            itemFrame.nameText:SetJustifyH("LEFT")
            
            -- Spell ID Text
            itemFrame.idText = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            itemFrame.idText:SetPoint("LEFT", itemFrame.nameText, "RIGHT", 4, 0)

            -- Red "X" Quick Delete Button
            itemFrame.delBtn = api.CreateFrame("Button", nil, itemFrame)
            itemFrame.delBtn:SetSize(16, 16)
            itemFrame.delBtn:SetPoint("RIGHT", itemFrame, "RIGHT", -10, 0)
            
            local delText = itemFrame.delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            delText:SetPoint("CENTER", itemFrame.delBtn, "CENTER", 0, 0)
            delText:SetTextColor(1.0, 0.2, 0.2, 1.0)
            delText:SetText("X")
            itemFrame.delBtn.text = delText
            
            itemFrame.delBtn:SetScript("OnEnter", function(self)
                delText:SetTextColor(1.0, 0.5, 0.5, 1.0)
            end)
            itemFrame.delBtn:SetScript("OnLeave", function(self)
                delText:SetTextColor(1.0, 0.2, 0.2, 1.0)
            end)
            
            -- White Gear Button
            itemFrame.gearBtn = api.CreateFrame("Button", nil, itemFrame)
            itemFrame.gearBtn:SetSize(18, 18)
            itemFrame.gearBtn:SetPoint("RIGHT", itemFrame.delBtn, "LEFT", -8, 0)
            itemFrame.gearBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
            local gTex = itemFrame.gearBtn:GetNormalTexture()
            if gTex then
                gTex:SetVertexColor(1, 1, 1, 0.95)
            end
        end
        
        -- 取得圖示
        local texture
        if data.kind == "itemCooldown" or (data.itemID and not data.spellID) then
            texture = C_Item.GetItemIconByID(data.itemID)
        elseif data.spellID then
            texture = C_Spell.GetSpellTexture(data.spellID)
        end
        itemFrame.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        
        -- Checkbox
        itemFrame.checkbox:SetChecked(data.enabled)
        itemFrame.checkbox:SetScript("OnClick", function(self)
            data.enabled = self:GetChecked()
            Options.notifyConfigChanged()
            
            local idVal = data.spellID or data.itemID
            if idVal and Options.addEditBox then
                Options.addEditBox:SetText(tostring(idVal))
            end
        end)
        
        -- Name
        local name = EAM.L.EAM_OPT_UNKNOWN or "Unknown"
        if data.kind == "itemCooldown" or (data.itemID and not data.spellID) then
            name = C_Item.GetItemNameByID(data.itemID) or ((EAM.L.EAM_ITEM_PREFIX or "物品 ") .. data.itemID)
        elseif data.spellID then
            local spellInfo = C_Spell.GetSpellInfo(data.spellID)
            name = spellInfo and spellInfo.name or ((EAM.L.EAM_OPT_COND_SPELL_NAME or "法術 ") .. data.spellID)
        end
        itemFrame.nameText:SetText(name)
        
        -- ID
        local showID = data.spellID or data.itemID or 0
        itemFrame.idText:SetText("[" .. showID .. "]")
        
        -- Del click
        itemFrame.delBtn:SetScript("OnClick", function()
            local idVal = data.spellID or data.itemID
            if idVal then
                Options.removeAlertFromCurrentCategory(idVal)
            end
        end)

        -- Gear click
        itemFrame.gearBtn:SetScript("OnClick", function()
            Options.openConditionsFrame(data)
        end)
        
        -- Click row item to auto-populate Spell ID
        itemFrame:SetScript("OnMouseDown", function()
            local idVal = data.spellID or data.itemID
            if idVal and Options.addEditBox then
                Options.addEditBox:SetText(tostring(idVal))
            end
        end)

        -- Tooltip Hover
        itemFrame:SetScript("OnEnter", function(self)
            itemFrame.bg:SetColorTexture(1, 1, 1, 0.08)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if data.kind == "itemCooldown" or (data.itemID and not data.spellID) then
                GameTooltip:SetItemByID(data.itemID)
            elseif data.spellID then
                GameTooltip:SetSpellByID(data.spellID)
            end
            GameTooltip:Show()
        end)
        itemFrame:SetScript("OnLeave", function()
            itemFrame.bg:SetColorTexture(1, 1, 1, 0.02)
            GameTooltip:Hide()
        end)
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    Options.scrollBox = scrollBox

    -- 底部輸入框與 Add/Delete 按鈕 (等高、緊湊排版)
    local addEditBox = api.CreateFrame("EditBox", nil, listInner, "InputBoxTemplate")
    addEditBox:SetSize(140, 24)
    addEditBox:SetPoint("BOTTOMLEFT", listInner, "BOTTOMLEFT", 12, 38)
    addEditBox:SetAutoFocus(false)
    addEditBox:SetNumeric(true)
    Options.addEditBox = addEditBox

    local addBtn = createRedButton(listInner, localized("EAM_OPT_ADD_BTN", "新增"), 158, 0, 60, 24, function()
        local idVal = tonumber(addEditBox:GetText())
        if not idVal or idVal <= 0 then
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_ERR_INVALID_ID or "請輸入正確的 ID！"))
            return
        end
        Options.addAlertToCurrentCategory(idVal)
        addEditBox:SetText("")
    end)
    addBtn:ClearAllPoints()
    addBtn:SetPoint("BOTTOMLEFT", listInner, "BOTTOMLEFT", 158, 38)

    local delBtn = createRedButton(listInner, localized("EAM_OPT_DEL_BTN", "刪除"), 224, 0, 60, 24, function()
        local idVal = tonumber(addEditBox:GetText())
        if not idVal or idVal <= 0 then
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_ERR_INVALID_ID or "請輸入正確的 ID！"))
            return
        end
        Options.removeAlertFromCurrentCategory(idVal)
        addEditBox:SetText("")
    end)
    delBtn:ClearAllPoints()
    delBtn:SetPoint("BOTTOMLEFT", listInner, "BOTTOMLEFT", 224, 38)

    addEditBox:SetScript("OnEnterPressed", function(self)
        local idVal = tonumber(self:GetText())
        if idVal and idVal > 0 then
            Options.addAlertToCurrentCategory(idVal)
        else
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_ERR_INVALID_ID or "請輸入正確的 ID！"))
        end
        self:SetText("")
        self:ClearFocus()
    end)

    local descText = listInner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    descText:SetPoint("BOTTOMLEFT", listInner, "BOTTOMLEFT", 12, 12)
    descText:SetTextColor(0.8, 0.8, 0.8, 1)
    bindText(descText, "EAM_OPT_ADD_DEL_DESC", "請輸入 SpellID 或 ItemID 並點擊新增 / 刪除。")

    Options.listFrame = listFrame


    -- ===================================================
    -- 4. Spell Conditions Frame (Popup Sub-Window)
    -- ===================================================
    local condFrame = api.CreateFrame("Frame", "EAM_SpellConditionsFrame", UIParent, "BackdropTemplate")
    condFrame:SetSize(340, 520)
    condFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    condFrame:SetFrameStrata("DIALOG")
    condFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    condFrame:SetBackdropColor(0.15, 0.1, 0.08, 0.98)
    condFrame:SetBackdropBorderColor(0.8, 0.6, 0.4, 1)
    if Theme and Theme.registerFrame then Theme.registerFrame(condFrame, "window") end
    condFrame:Hide()
    condFrame:SetMovable(true)
    condFrame:EnableMouse(true)
    condFrame:RegisterForDrag("LeftButton")
    condFrame:SetScript("OnDragStart", condFrame.StartMoving)
    condFrame:SetScript("OnDragStop", condFrame.StopMovingOrSizing)

    -- Spell Icon 大圖標
    local condIcon = condFrame:CreateTexture(nil, "ARTWORK")
    condIcon:SetSize(48, 48)
    condIcon:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -20)
    condFrame.icon = condIcon

    -- Spell Name Plate
    local condNameFrame = api.CreateFrame("Frame", nil, condFrame, "BackdropTemplate")
    condNameFrame:SetSize(232, 24)
    condNameFrame:SetPoint("LEFT", condIcon, "RIGHT", 10, 10)
    condNameFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    condNameFrame:SetBackdropColor(0.6, 0.1, 0.1, 0.8)
    condNameFrame:SetBackdropBorderColor(0.8, 0.4, 0.4, 1)

    local condNameText = condNameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    condNameText:SetPoint("LEFT", condNameFrame, "LEFT", 8, 0)
    condNameText:SetText(EAM.L.EAM_OPT_COND_SPELL_NAME or "法術名稱")
    condFrame.nameText = condNameText

    local condIDText = condFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    condIDText:SetPoint("TOPLEFT", condNameFrame, "BOTTOMLEFT", 2, -4)
    condIDText:SetText(string.format(EAM.L.EAM_OPT_COND_SPELL_ID_FORMAT or "Spell ID: %d", 0))
    condFrame.idText = condIDText

    -- Sliders (左側排版，Label 偏上 5px 防重疊)
    local stackSlider = api.CreateFrame("Slider", nil, condFrame, "OptionsSliderTemplate")
    stackSlider:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -100)
    stackSlider:SetMinMaxValues(0, 10)
    stackSlider:SetValueStep(1)
    stackSlider:SetObeyStepOnDrag(true)
    stackSlider:SetSize(130, 16)
    local stackLabel = stackSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stackLabel:SetPoint("BOTTOMLEFT", stackSlider, "TOPLEFT", 0, 5)
    bindText(stackLabel, "EAM_OPT_COND_STACK", "堆疊層數閾值")
    local stackVal = stackSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stackVal:SetPoint("BOTTOMRIGHT", stackSlider, "TOPRIGHT", 0, 5)
    stackSlider:SetScript("OnValueChanged", function(self, val)
        stackVal:SetText(mathFloor(val))
    end)
    condFrame.stackSlider = stackSlider

    local glowSlider = api.CreateFrame("Slider", nil, condFrame, "OptionsSliderTemplate")
    glowSlider:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -155)
    glowSlider:SetMinMaxValues(0, 10)
    glowSlider:SetValueStep(1)
    glowSlider:SetObeyStepOnDrag(true)
    glowSlider:SetSize(130, 16)
    local glowLabel = glowSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    glowLabel:SetPoint("BOTTOMLEFT", glowSlider, "TOPLEFT", 0, 5)
    bindText(glowLabel, "EAM_OPT_COND_GLOW", "堆疊高亮閾值")
    local glowVal = glowSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    glowVal:SetPoint("BOTTOMRIGHT", glowSlider, "TOPRIGHT", 0, 5)
    glowSlider:SetScript("OnValueChanged", function(self, val)
        glowVal:SetText(mathFloor(val))
    end)
    condFrame.glowSlider = glowSlider

    local redLimitSlider = api.CreateFrame("Slider", nil, condFrame, "OptionsSliderTemplate")
    redLimitSlider:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -210)
    redLimitSlider:SetMinMaxValues(0, 10)
    redLimitSlider:SetValueStep(1)
    redLimitSlider:SetObeyStepOnDrag(true)
    redLimitSlider:SetSize(130, 16)
    local redLimitLabel = redLimitSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    redLimitLabel:SetPoint("BOTTOMLEFT", redLimitSlider, "TOPLEFT", 0, 5)
    bindText(redLimitLabel, "EAM_OPT_COND_RED_LIMIT", "倒數紅字限制 (秒)")
    local redLimitVal = redLimitSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    redLimitVal:SetPoint("BOTTOMRIGHT", redLimitSlider, "TOPRIGHT", 0, 5)
    redLimitSlider:SetScript("OnValueChanged", function(self, val)
        redLimitVal:SetText(mathFloor(val))
    end)
    condFrame.redLimitSlider = redLimitSlider

    local prioritySlider = api.CreateFrame("Slider", nil, condFrame, "OptionsSliderTemplate")
    prioritySlider:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -265)
    prioritySlider:SetMinMaxValues(1, 20)
    prioritySlider:SetValueStep(1)
    prioritySlider:SetObeyStepOnDrag(true)
    prioritySlider:SetSize(130, 16)
    local priorityLabel = prioritySlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priorityLabel:SetPoint("BOTTOMLEFT", prioritySlider, "TOPLEFT", 0, 5)
    bindText(priorityLabel, "EAM_OPT_COND_PRIORITY", "排序優先級 (Priority)")
    local priorityVal = prioritySlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    priorityVal:SetPoint("BOTTOMRIGHT", prioritySlider, "TOPRIGHT", 0, 5)
    prioritySlider:SetScript("OnValueChanged", function(self, val)
        priorityVal:SetText(mathFloor(val))
    end)
    condFrame.prioritySlider = prioritySlider

    -- Checkboxes (右側排版)
    local fromPlayerCb = api.CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
    fromPlayerCb:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 175, -96)
    fromPlayerCb.text = fromPlayerCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fromPlayerCb.text:SetPoint("LEFT", fromPlayerCb, "RIGHT", 4, 1)
    bindText(fromPlayerCb.text, "EAM_OPT_COND_PLAYER_ONLY", "僅監控自己施放")
    condFrame.fromPlayerCb = fromPlayerCb

    local valTitle = condFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valTitle:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 175, -135)
    valTitle:SetTextColor(0.95, 0.85, 0.4, 1.0)
    bindText(valTitle, "EAM_OPT_COND_VAL_TITLE", "顯示光環細部數值:")
    condFrame.valTitle = valTitle

    local val1Cb = api.CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
    val1Cb:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 175, -160)
    val1Cb.text = val1Cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val1Cb.text:SetPoint("LEFT", val1Cb, "RIGHT", 4, 1)
    bindText(val1Cb.text, "EAM_OPT_COND_VAL1", "顯示數值 1 (Value 1)")
    condFrame.val1Cb = val1Cb

    local val2Cb = api.CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
    val2Cb:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 175, -190)
    val2Cb.text = val2Cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val2Cb.text:SetPoint("LEFT", val2Cb, "RIGHT", 4, 1)
    bindText(val2Cb.text, "EAM_OPT_COND_VAL2", "顯示數值 2 (Value 2)")
    condFrame.val2Cb = val2Cb

    local val3Cb = api.CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
    val3Cb:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 175, -220)
    val3Cb.text = val3Cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val3Cb.text:SetPoint("LEFT", val3Cb, "RIGHT", 4, 1)
    bindText(val3Cb.text, "EAM_OPT_COND_VAL3", "顯示數值 3 (Value 3)")
    condFrame.val3Cb = val3Cb

    local val4Cb = api.CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
    val4Cb:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 175, -250)
    val4Cb.text = val4Cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val4Cb.text:SetPoint("LEFT", val4Cb, "RIGHT", 4, 1)
    bindText(val4Cb.text, "EAM_OPT_COND_VAL4", "顯示數值 4 (Value 4)")
    condFrame.val4Cb = val4Cb

    -- 地面技能專屬控制項
    local durationModeCb = api.CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
    durationModeCb:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -100)
    durationModeCb.text = durationModeCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    durationModeCb.text:SetPoint("LEFT", durationModeCb, "RIGHT", 4, 1)
    bindText(durationModeCb.text, "EAM_OPT_COND_TOOLTIP", "啟用動態 Tooltip 擷取")
    condFrame.durationModeCb = durationModeCb

    local manualDurationLabel = condFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    manualDurationLabel:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -145)
    bindText(manualDurationLabel, "EAM_OPT_COND_MANUAL_DUR", "手動設定時間 (秒)")
    condFrame.manualDurationLabel = manualDurationLabel

    local manualDurationEditBox = api.CreateFrame("EditBox", nil, condFrame, "InputBoxTemplate")
    manualDurationEditBox:SetSize(80, 20)
    manualDurationEditBox:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -165)
    manualDurationEditBox:SetAutoFocus(false)
    manualDurationEditBox:SetNumeric(false)
    condFrame.manualDurationEditBox = manualDurationEditBox

    local scrapeBtn = api.CreateFrame("Button", nil, condFrame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(scrapeBtn) end
    scrapeBtn:SetSize(80, 20)
    scrapeBtn:SetPoint("LEFT", manualDurationEditBox, "RIGHT", 10, 0)
    bindText(scrapeBtn, "EAM_OPT_COND_SCRAPE_BTN", "一鍵擷取")
    scrapeBtn:SetScript("OnClick", function()
        local d = Options.currentEditingAlert
        if d and d.spellID then
            if EAM.Services.GroundEffectService and EAM.Services.GroundEffectService.scrapeDuration then
                local num = EAM.Services.GroundEffectService.scrapeDuration(d.spellID)
                if num then
                    manualDurationEditBox:SetText(tostring(num))
                    print(string.format(EAM.L.EAM_OPT_SCRAPE_SUCCESS or "|cff00ff96EAM|r 成功擷取當前持續時間: %s 秒", num))
                else
                    print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_SCRAPE_FAIL or "未能在說明中解析出秒數，請手動輸入。"))
                end
            end
        end
    end)
    condFrame.scrapeBtn = scrapeBtn

    -- 12.1 AuraSound：使用 SavedVariables 的普通 Spell ID 與素材，不讀取 AuraData。
    local auraSoundTitle = condFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    auraSoundTitle:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -310)
    bindText(auraSoundTitle, "EAM_OPT_AURA_SOUND_TITLE", "12.1 光環事件音效")
    condFrame.auraSoundTitle = auraSoundTitle

    local auraSoundDropdown = api.CreateFrame("Button", nil, condFrame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(auraSoundDropdown) end
    auraSoundDropdown:SetSize(140, 22)
    auraSoundDropdown:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -330)
    condFrame.auraSoundDropdown = auraSoundDropdown

    local auraSoundMenu = api.CreateFrame("Frame", nil, condFrame, "BackdropTemplate")
    auraSoundMenu:SetSize(140, 268)
    auraSoundMenu:SetPoint("TOPLEFT", auraSoundDropdown, "BOTTOMLEFT", 0, -2)
    auraSoundMenu:SetFrameStrata("TOOLTIP")
    auraSoundMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    auraSoundMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
    auraSoundMenu:SetBackdropBorderColor(0.6, 0.4, 0.2, 1)
    auraSoundMenu:Hide()
    condFrame.auraSoundMenu = auraSoundMenu

    for index = 1, #soundNames do
        local soundName = soundNames[index]
        local menuButton = api.CreateFrame("Button", nil, auraSoundMenu)
        menuButton:SetSize(134, 20)
        menuButton:SetPoint("TOPLEFT", auraSoundMenu, "TOPLEFT", 3, -3 - (index - 1) * 22)
        menuButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        if Theme and Theme.registerButton then Theme.registerButton(menuButton) end
        local menuText = menuButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        menuText:SetPoint("LEFT", menuButton, "LEFT", 6, 0)
        menuText:SetText(soundName)
        if Theme and Theme.registerText then Theme.registerText(menuText, "button") end
        menuButton:SetScript("OnClick", function()
            condFrame.auraSoundName = soundName
            auraSoundDropdown:SetText((EAM.L.EAM_OPT_SOUND_PREFIX or "音效: ") .. soundName)
            auraSoundMenu:Hide()
        end)
    end

    auraSoundDropdown:SetScript("OnClick", function()
        if not isAuraSoundAvailable() then
            return
        end
        if auraSoundMenu:IsShown() then
            auraSoundMenu:Hide()
        else
            auraSoundMenu:Show()
        end
    end)

    local auraSoundTestButton = api.CreateFrame("Button", nil, condFrame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(auraSoundTestButton) end
    auraSoundTestButton:SetSize(80, 22)
    auraSoundTestButton:SetPoint("LEFT", auraSoundDropdown, "RIGHT", 8, 0)
    bindText(auraSoundTestButton, "EAM_OPT_AURA_SOUND_TEST_ASSET_ONLY", "試聽素材")
    auraSoundTestButton:SetScript("OnClick", function()
        if not isAuraSoundAvailable() then
            return
        end
        local asset = soundAssets[condFrame.auraSoundName] or soundAssets.ShayBell
        PlaySoundFile(asset, "Master")
    end)
    condFrame.auraSoundTestButton = auraSoundTestButton

    local function createAuraSoundCheckbox(key, fallback, x, y)
        local checkbox = api.CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", condFrame, "TOPLEFT", x, y)
        checkbox.text = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 4, 1)
        bindText(checkbox.text, key, fallback)
        return checkbox
    end

    condFrame.auraSoundAddedCb = createAuraSoundCheckbox(
        "EAM_OPT_AURA_SOUND_ADDED", "光環新增", 20, -365
    )
    condFrame.auraSoundApplicationsCb = createAuraSoundCheckbox(
        "EAM_OPT_AURA_SOUND_APPLICATIONS_INCREASED", "層數增加", 175, -365
    )
    condFrame.auraSoundRemovedCb = createAuraSoundCheckbox(
        "EAM_OPT_AURA_SOUND_REMOVED", "光環移除", 20, -395
    )

    local auraSoundHint = condFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    auraSoundHint:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -425)
    auraSoundHint:SetWidth(300)
    auraSoundHint:SetJustifyH("LEFT")
    bindText(auraSoundHint, "EAM_OPT_AURA_SOUND_INHERIT", "三項皆未勾選時沿用全域音效；實際觸發需 PTR 真人驗證。")
    condFrame.auraSoundHint = auraSoundHint

    -- 底部按鈕
    createRedButton(condFrame, localized("EAM_OPT_COND_SAVE_BTN", "儲存設定 (Save)"), 20, -470, 130, 26, function()
        local d = Options.currentEditingAlert
        if d then
            if d.kind == "groundEffect" then
                local savedVariables = EAM.Modules.SavedVariables
                if savedVariables and savedVariables.updateGroundEffectAlert then
                    savedVariables.updateGroundEffectAlert(
                        d.spellID,
                        condFrame.durationModeCb:GetChecked() and "AUTO" or "MANUAL",
                        condFrame.manualDurationEditBox:GetText()
                    )
                end
            else
                local savedVariables = EAM.Modules.SavedVariables
                local isAura = d.kind == EAM.Constants.ALERT_KIND_AURA
                local detailsChanged = false
                local function assignDetail(field, value)
                    if d[field] ~= value then
                        d[field] = value
                        detailsChanged = true
                    end
                end

                assignDetail("stackThreshold", condFrame.stackSlider:GetValue())
                assignDetail("stackGlowThreshold", condFrame.glowSlider:GetValue())
                assignDetail("countdownRedLimit", condFrame.redLimitSlider:GetValue())
                local priority = condFrame.prioritySlider:GetValue()
                local priorityUpdated = false
                if isAura then
                    assignDetail("priority", priority)
                elseif savedVariables and savedVariables.updateAlertPriority then
                    priorityUpdated = savedVariables.updateAlertPriority(
                        d.kind,
                        d.unit,
                        d.spellID,
                        d.itemID,
                        priority
                    ) == true
                end
                if not isAura and not priorityUpdated then
                    d.priority = priority
                end

                assignDetail("fromPlayer", condFrame.fromPlayerCb:GetChecked())
                assignDetail("showValue1", condFrame.val1Cb:GetChecked())
                assignDetail("showValue2", condFrame.val2Cb:GetChecked())
                assignDetail("showValue3", condFrame.val3Cb:GetChecked())
                assignDetail("showValue4", condFrame.val4Cb:GetChecked())

                local soundUpdated = false
                if isAura
                    and isAuraSoundAvailable()
                    and savedVariables
                    and savedVariables.updateAuraSound
                then
                    local soundOK, soundState = savedVariables.updateAuraSound(
                        d.unit,
                        d.spellID,
                        Options.buildAuraSoundConfig(
                            condFrame.auraSoundName,
                            condFrame.auraSoundAddedCb:GetChecked(),
                            condFrame.auraSoundApplicationsCb:GetChecked(),
                            condFrame.auraSoundRemovedCb:GetChecked()
                        )
                    )
                    soundUpdated = soundOK and soundState == "updated"
                end

                if isAura and detailsChanged and not soundUpdated then
                    if savedVariables and savedVariables.markRevisionChanged then
                        savedVariables.markRevisionChanged()
                    end
                    local router = EAM.Modules and EAM.Modules.EventRouter
                    if router and router.fire then
                        router.fire("EAM_AURA_CONFIG_CHANGED", EAM.db and EAM.db.revision or 0)
                    end
                end
            end

            local isAura = d.kind == EAM.Constants.ALERT_KIND_AURA
            Options.notifyConfigChanged(not isAura)
            if d.kind == "groundEffect" then
                notifyGroundEffectConfigChanged()
            end
            condFrame.auraSoundMenu:Hide()
            condFrame:Hide()
            Options.refreshList()
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_COND_SAVE_SUCCESS or "條件已儲存。"))
        end
    end)

    local cancelBtn = api.CreateFrame("Button", nil, condFrame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(cancelBtn) end
    cancelBtn:SetSize(130, 26)
    cancelBtn:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 190, -470)
    bindText(cancelBtn, "EAM_OPT_COND_CANCEL_BTN", "取消關閉 (Cancel)")
    cancelBtn:SetScript("OnClick", function()
        condFrame.auraSoundMenu:Hide()
        condFrame:Hide()
    end)

    Options.condFrame = condFrame

    _G["EAM_MainOptionsFrame"] = frame
    tinsert(UISpecialFrames, "EAM_MainOptionsFrame")

    return frame
end

-- 開啟 Spell Conditions 子編輯框
function Options.openConditionsFrame(data)
    local cf = Options.condFrame
    if not cf then return end

    Options.currentEditingAlert = data

    -- 獲取法術/物品名稱與圖標
    local texture
    local name = EAM.L.EAM_OPT_UNKNOWN or "Unknown"
    local idStr = ""
    if data.kind == "itemCooldown" or (data.itemID and not data.spellID) then
        texture = C_Item.GetItemIconByID(data.itemID)
        name = C_Item.GetItemNameByID(data.itemID) or ((EAM.L.EAM_ITEM_PREFIX or "物品 ") .. data.itemID)
        idStr = string.format(EAM.L.EAM_OPT_COND_ITEM_ID_FORMAT or "Item ID: %d", data.itemID)
    elseif data.spellID then
        texture = C_Spell.GetSpellTexture(data.spellID)
        local spellInfo = C_Spell.GetSpellInfo(data.spellID)
        name = spellInfo and spellInfo.name or ((EAM.L.EAM_OPT_COND_SPELL_NAME or "法術 ") .. data.spellID)
        idStr = string.format(EAM.L.EAM_OPT_COND_SPELL_ID_FORMAT or "Spell ID: %d", data.spellID)
    end

    cf.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    cf.nameText:SetText(name)
    cf.idText:SetText(idStr)

    -- 判斷是否為地面技能效果
    local isGround = (data.kind == "groundEffect")
    local isAura = data.kind == EAM.Constants.ALERT_KIND_AURA
    local auraSoundAvailable = isAura and isAuraSoundAvailable()
    local auraSound = type(data.sound) == "table" and data.sound or nil
    local auraSoundName = Options.resolveAuraSoundName(auraSound)
        or (EAM.db and EAM.db.config and EAM.db.config.soundName)
        or "ShayBell"
    cf.auraSoundName = auraSoundName
    cf.auraSoundDropdown:SetText((EAM.L.EAM_OPT_SOUND_PREFIX or "音效: ") .. auraSoundName)
    cf.auraSoundAddedCb:SetChecked(auraSound and auraSound.added ~= nil)
    cf.auraSoundApplicationsCb:SetChecked(auraSound and auraSound.applicationsIncreased ~= nil)
    cf.auraSoundRemovedCb:SetChecked(auraSound and auraSound.removed ~= nil)
    cf.auraSoundMenu:Hide()

    local auraSoundWidgets = {
        cf.auraSoundTitle,
        cf.auraSoundDropdown,
        cf.auraSoundTestButton,
        cf.auraSoundAddedCb,
        cf.auraSoundApplicationsCb,
        cf.auraSoundRemovedCb,
        cf.auraSoundHint,
    }
    for index = 1, #auraSoundWidgets do
        if isAura then
            auraSoundWidgets[index]:Show()
        else
            auraSoundWidgets[index]:Hide()
        end
    end
    cf.auraSoundDropdown:SetEnabled(auraSoundAvailable)
    cf.auraSoundTestButton:SetEnabled(auraSoundAvailable)
    cf.auraSoundAddedCb:SetEnabled(auraSoundAvailable)
    cf.auraSoundApplicationsCb:SetEnabled(auraSoundAvailable)
    cf.auraSoundRemovedCb:SetEnabled(auraSoundAvailable)
    local auraSoundAlpha = auraSoundAvailable and 1 or 0.45
    cf.auraSoundDropdown:SetAlpha(auraSoundAlpha)
    cf.auraSoundTestButton:SetAlpha(auraSoundAlpha)
    cf.auraSoundAddedCb:SetAlpha(auraSoundAlpha)
    cf.auraSoundApplicationsCb:SetAlpha(auraSoundAlpha)
    cf.auraSoundRemovedCb:SetAlpha(auraSoundAlpha)
    if auraSoundAvailable then
        bindText(cf.auraSoundHint, "EAM_OPT_AURA_SOUND_INHERIT", "三項皆未勾選時沿用全域音效；實際觸發需 PTR 真人驗證。")
    else
        bindText(cf.auraSoundHint, "EAM_OPT_AURA_SOUND_DISABLED", "此客戶端不支援 12.1 AuraSound；現有設定不會被改寫。")
    end

    if isGround then
        -- 顯示地面效果專屬控制項
        cf.durationModeCb:Show()
        cf.manualDurationLabel:Show()
        cf.manualDurationEditBox:Show()
        cf.scrapeBtn:Show()

        cf.durationModeCb:SetChecked(data.durationMode == "AUTO" or data.durationMode == "TOOLTIP" or data.durationMode == nil)
        cf.manualDurationEditBox:SetText(tostring(data.manualDuration or 8))

        -- 隱藏一般的 sliders
        cf.stackSlider:Hide()
        cf.glowSlider:Hide()
        cf.redLimitSlider:Hide()
        cf.prioritySlider:Hide()
        cf.fromPlayerCb:Hide()
        if cf.valTitle then cf.valTitle:Hide() end
        cf.val1Cb:Hide()
        cf.val2Cb:Hide()
        cf.val3Cb:Hide()
        cf.val4Cb:Hide()
    else
        -- 隱藏地面效果專屬控制項
        cf.durationModeCb:Hide()
        cf.manualDurationLabel:Hide()
        cf.manualDurationEditBox:Hide()
        cf.scrapeBtn:Hide()

        -- 顯示一般的 sliders
        cf.stackSlider:Show()
        cf.glowSlider:Show()
        cf.redLimitSlider:Show()
        cf.prioritySlider:Show()
        cf.fromPlayerCb:Show()

        cf.stackSlider:SetValue(data.stackThreshold or 0)
        cf.glowSlider:SetValue(data.stackGlowThreshold or 0)
        cf.redLimitSlider:SetValue(data.countdownRedLimit or 0)
        cf.prioritySlider:SetValue(data.priority or 10)
        cf.fromPlayerCb:SetChecked(data.fromPlayer == true)

        cf.val1Cb:SetChecked(data.showValue1 == true)
        cf.val2Cb:SetChecked(data.showValue2 == true)
        cf.val3Cb:SetChecked(data.showValue3 == true)
        cf.val4Cb:SetChecked(data.showValue4 == true)

        -- 技能與物品冷卻監控模組均不用顯示數值1~4
        local isCooldown = (data.kind == EAM.Constants.ALERT_KIND_SPELL_COOLDOWN or data.kind == EAM.Constants.ALERT_KIND_ITEM_COOLDOWN)
        if isCooldown then
            if cf.valTitle then cf.valTitle:Hide() end
            cf.val1Cb:Hide()
            cf.val2Cb:Hide()
            cf.val3Cb:Hide()
            cf.val4Cb:Hide()
        else
            if cf.valTitle then cf.valTitle:Show() end
            cf.val1Cb:Show()
            cf.val2Cb:Show()
            cf.val3Cb:Show()
            cf.val4Cb:Show()
        end
    end

    cf:Show()
end

-- Slash 命令外部唯一呼叫介面
function Options.open()
    if api.InCombatLockdown and api.InCombatLockdown() then
        Options.pendingOpen = true
        print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_COMBAT_WARNING or "少年欸！戰鬥中暫不開啟設定視窗，脫離戰鬥後會自動為你開啟。"))
        return
    end

    local frame = createFrame()
    if not frame then
        return
    end

    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        if Options.posFrame then Options.posFrame:Hide() end
        if Options.listFrame then Options.listFrame:Hide() end
        
        -- 低頻刷新所有由多段語系字串組合而成的控制項。
        Options.refreshLocalizedText()
    end
end

local function createMinimapButton()
    if EAM.db and EAM.db.config and EAM.db.config.showMinimapButton == false then
        if EAM.UI.MinimapButton then EAM.UI.MinimapButton:Hide() end
        return
    end

    if EAM.UI.MinimapButton then
        EAM.UI.MinimapButton:Show()
        return
    end

    local btn = api.CreateFrame("Button", "EAM_MinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetPoint("CENTER", Minimap, "CENTER", 80, 80)
    btn:SetMovable(true)
    btn:RegisterForClicks("AnyUp")

    -- 背景：12.1 優先使用 EAM 自有 SVG；12.0.7 與失敗路徑保留內建 fallback。
    local back = btn:CreateTexture(nil, "BACKGROUND")
    back:SetSize(21, 21)
    back:SetPoint("CENTER", btn, "CENTER", 0, 0)
    Options.applyMinimapTexture(back)

    -- 邊框
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("CENTER", btn, "CENTER", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- 點擊效果
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local function updatePosition(angle)
        local rad = math.rad(angle)
        local x = math.cos(rad) * 80
        local y = math.sin(rad) * 80
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    btn:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function(s)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            local angle = math.deg(math.atan2(py - my, px - mx))
            if angle < 0 then angle = angle + 360 end
            if EAM.db and EAM.db.config then
                EAM.db.config.minimapAngle = angle
            end
            updatePosition(angle)
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)

    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            Options.open()
        elseif button == "RightButton" then
            if EAM.Debug.PromptExport and EAM.Debug.PromptExport.openWindow then
                EAM.Debug.PromptExport.openWindow()
            end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("EventAlertMod", 0.95, 0.85, 0.4)
        GameTooltip:AddLine(EAM.L.EAM_OPT_MINIMAP_LCLICK or "左鍵點擊: 開啟/關閉設定面板", 1, 1, 1)
        GameTooltip:AddLine(EAM.L.EAM_OPT_MINIMAP_RCLICK or "右鍵點擊: 開啟系統除錯診斷", 1, 1, 1)
        GameTooltip:AddLine(EAM.L.EAM_OPT_MINIMAP_DRAG or "拖曳小圖示可移動位置", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    btn:RegisterForDrag("LeftButton")

    -- 初始化位置
    local initAngle = (EAM.db and EAM.db.config and EAM.db.config.minimapAngle) or 45
    updatePosition(initAngle)

    EAM.UI.MinimapButton = btn
end

EAM.UI.createMinimapButton = createMinimapButton

-- Taint 延遲載入監聽 Frame
local eventFrame = api.CreateFrame("Frame", nil, nil)
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        createMinimapButton()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if EAM.Theme and EAM.Theme.flushPending then
            EAM.Theme.flushPending()
        end
        if Options.pendingOpen then
            Options.pendingOpen = false
            Options.open()
        end
    end
end)
