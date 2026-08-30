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
    chargeBarDropdown = nil,
    chargeBarMenu = nil,
    chargeBarOptions = nil,
    specDropdown = nil,
    currentSpecFilterName = nil,
    addEditBox = nil,
    batchFrame = nil,
    batchScrollFrame = nil,
    batchEditBox = nil,
    batchStatusText = nil,
    batchCategory = nil,
    currentCategory = 1,
    pendingOpen = false,
    currentEditingAlert = nil,
}
EAM.UI.Options = Options

local api = EAM.API
local Theme = EAM.Theme
local Locale = EAM.Locale
local mathFloor = math.floor

local COOLDOWN_BEHAVIOR_OPTIONS = {
    {
        field = "cooldownRemoveAura",
        labelKey = "EAM_OPT_COND_CD_REMOVE",
        labelFallback = "完成後移除",
    },
    {
        field = "showSCDOutsideCombat",
        labelKey = "EAM_OPT_COND_CD_OUTSIDE",
        labelFallback = "非戰鬥顯示",
    },
    {
        field = "glowSCDWhenUsable",
        labelKey = "EAM_OPT_COND_CD_GLOW",
        labelFallback = "可用時高亮",
    },
    {
        field = "cooldownPreRender",
        labelKey = "EAM_OPT_PRERENDER_PLACEHOLDER",
        labelFallback = "預渲染佔位",
    },
}

local function cooldownBehaviorStateLabel(value)
    if value == true then
        return (EAM.L and EAM.L.EAM_OPT_COND_CD_OVERRIDE_ON) or "覆寫：開"
    elseif value == false then
        return (EAM.L and EAM.L.EAM_OPT_COND_CD_OVERRIDE_OFF) or "覆寫：關"
    end
    return (EAM.L and EAM.L.EAM_OPT_COND_CD_GLOBAL) or "全域"
end

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

local function resolveText(value)
    if not value then return nil end
    if type(value) == "table" and value.eamLocaleKey then
        return (EAM.L and EAM.L[value.eamLocaleKey]) or value.fallback or value.eamLocaleKey
    end
    if type(value) == "string" and EAM.L and EAM.L[value] then
        return EAM.L[value]
    end
    return tostring(value)
end

local function setTooltip(widget, tooltipText, tooltipTitle)
    if not widget or not tooltipText then return end
    
    local origOnEnter = widget:GetScript("OnEnter")
    local origOnLeave = widget:GetScript("OnLeave")
    
    widget:SetScript("OnEnter", function(self, ...)
        if origOnEnter then origOnEnter(self, ...) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local title = resolveText(tooltipTitle)
        if title and title ~= "" then
            GameTooltip:AddLine(title, 0.95, 0.85, 0.4)
        end
        local desc = resolveText(tooltipText)
        if desc and desc ~= "" then
            GameTooltip:AddLine(desc, 1.0, 1.0, 1.0, true)
        end
        GameTooltip:Show()
    end)
    
    widget:SetScript("OnLeave", function(self, ...)
        if origOnLeave then origOnLeave(self, ...) end
        GameTooltip:Hide()
    end)
end
EAM.UI.setTooltip = setTooltip

local MINIMAP_FALLBACK_TEXTURE = "Interface\\Icons\\Trade_Engineering"

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
    local MediaService = EAM.Services and EAM.Services.MediaService
    local asset = (MediaService and MediaService.getSoundPath(soundName))
        or soundAssets[soundName]
        or soundAssets.ShayBell
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
    local MediaService = EAM.Services and EAM.Services.MediaService
    if MediaService and MediaService.getMediaList then
        local soundList = MediaService.getMediaList("sound")
        for _, item in ipairs(soundList) do
            if item.path == asset or item.value == asset then
                return item.value
            end
        end
    end
    for index = 1, #soundNames do
        local soundName = soundNames[index]
        if soundAssets[soundName] == asset then
            return soundName
        end
    end
end
-- Texture:SetSVG 在 12.1 實機可接受呼叫但不保證繪製；小地圖固定使用經典齒輪避免空白或問號。
function Options.applyMinimapTexture(texture)
    if not texture or type(texture.SetTexture) ~= "function" then
        return "unavailable"
    end

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
    if EAM.UI.Renderer and EAM.UI.Renderer.refreshPreviewLayout then
        EAM.UI.Renderer.refreshPreviewLayout()
    end
    if EAM.Services and EAM.Services.PlayerResourceService and EAM.Services.PlayerResourceService.refreshActiveResources then
        EAM.Services.PlayerResourceService.refreshActiveResources("OPTIONS_TEXT_LAYOUT_CHANGED")
    end
    if EAM.Services and EAM.Services.PlayerStatService and EAM.Services.PlayerStatService.updateDisplay then
        EAM.Services.PlayerStatService.updateDisplay()
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
    local MediaService = EAM.Services and EAM.Services.MediaService
    local mediaList = MediaService and MediaService.getMediaList("font")
    if mediaList then
        for _, item in ipairs(mediaList) do
            if item.value == family then
                label = item.text or item.value
                break
            end
        end
    else
        local options = EAM.Constants and EAM.Constants.FONT_FAMILY_OPTIONS or {}
        for index = 1, #options do
            local option = options[index]
            if option.value == family then
                label = (EAM.L and EAM.L[option.labelKey]) or option.labelKey or option.value
                break
            end
        end
    end
    Options.fontDropdown:SetText((EAM.L.EAM_OPT_FONT_PREFIX or "Font: ") .. label)
end

function Options.refreshChargeBarDropdown()
    if not Options.chargeBarDropdown or type(Options.chargeBarOptions) ~= "table" then
        return
    end
    local selection = EAM.db and EAM.db.config and EAM.db.config.chargeBarLayout or "BOTTOM"
    local label = selection
    for index = 1, #Options.chargeBarOptions do
        local option = Options.chargeBarOptions[index]
        if option.value == selection then
            label = (EAM.L and EAM.L[option.labelKey]) or option.fallback
            break
        end
    end
    setWidgetText(Options.chargeBarDropdown, label)
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
    local label = soundName
    local MediaService = EAM.Services and EAM.Services.MediaService
    if MediaService and MediaService.getMediaList then
        local soundList = MediaService.getMediaList("sound")
        for _, item in ipairs(soundList) do
            if item.value == soundName then
                label = item.text or item.value
                break
            end
        end
    end
    Options.soundDropdown:SetText((EAM.L.EAM_OPT_SOUND_PREFIX or "音效: ") .. label)
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

function Options.refreshCooldownBehaviorControls()
    local cf = Options.condFrame
    if not cf or type(cf.cooldownBehaviorButtons) ~= "table" then
        return
    end
    for index = 1, #COOLDOWN_BEHAVIOR_OPTIONS do
        local definition = COOLDOWN_BEHAVIOR_OPTIONS[index]
        local button = cf.cooldownBehaviorButtons[definition.field]
        if button then
            local label = (EAM.L and EAM.L[definition.labelKey]) or definition.labelFallback
            button:SetText(label .. ": " .. cooldownBehaviorStateLabel(button.eamValue))
        end
    end
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
    Options.refreshCooldownBehaviorControls()
end


function Options.refreshPlayerResourceSummary()
    if not Options.playerResourceStatusLabel then
        return
    end
    local service = EAM.Services.PlayerResourceService
    local count = service and service.getTrackedResourceCount
        and service.getTrackedResourceCount()
        or 0
    if not EAM.Util.isSafeNonNegativeNumber(count) then
        count = 0
    end
    Options.playerResourceStatusLabel:SetText(
        string.format(
            EAM.L.EAM_RESOURCE_OPTIONS_STATUS or "目前追蹤 %d 種玩家資源。",
            count
        )
    )
end

function Options.refreshLocalizedText()
    Options.refreshSoundDropdown()
    Options.refreshLanguageDropdown()
    Options.refreshThemeDropdown()
    Options.refreshFontDropdown()
    Options.refreshChargeBarDropdown()
    Options.refreshAuraBackendStatus()
    Options.refreshPlayerResourceSummary()
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

-- 取得指定類別對應的 alert list；player 自身與跨職業共用同一 SavedVariables list，由 catalogScope 分流。
function Options.getCategoryList(category)
    local saved = EAM.Modules.SavedVariables
    if not saved or not EAM.db then return {} end

    if category == 1 or category == 2 then
        return saved.getAlertList(EAM.Constants.ALERT_KIND_AURA, "player") or {}
    elseif category == 3 then
        return saved.getAlertList(EAM.Constants.ALERT_KIND_AURA, "target") or {}
    elseif category == 4 then
        return saved.getAlertList(EAM.Constants.ALERT_KIND_SPELL_COOLDOWN, "player") or {}
    elseif category == 5 then
        return saved.getAlertList(EAM.Constants.ALERT_KIND_ITEM_COOLDOWN) or {}
    elseif category == 6 then
        return saved.getAlertList("groundEffect") or {}
    end
    return {}
end

function Options.getCurrentCategoryList()
    return Options.getCategoryList(Options.currentCategory)
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

local function getSafeSpellInfo(spellID)
    if type(spellID) ~= "number" or spellID % 1 ~= 0 or spellID <= 0 then
        return nil
    end
    local service = EAM.Services and EAM.Services.SpellInfoService
    if not service or type(service.getSpellInfo) ~= "function" then
        return nil
    end
    local ok, info = pcall(service.getSpellInfo, spellID)
    if not ok
        or type(info) ~= "table"
        or info.factsSafe ~= true
        or type(info.name) ~= "string"
        or info.name == "" then
        return nil
    end
    return info
end

local function isExistingSpell(spellID)
    return getSafeSpellInfo(spellID) ~= nil
end

local function isCurrentClassSpell(spellID)
    if getSpellSpec(spellID) ~= nil then
        return true
    end
    local spellBook = api and api.C_SpellBook
    if not spellBook or type(spellBook.IsSpellInSpellBook) ~= "function" then
        return false
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false
    end
    local spellBank = api.SpellBookSpellBank and api.SpellBookSpellBank.Player
    local ok, result
    if spellBank ~= nil then
        ok, result = pcall(spellBook.IsSpellInSpellBook, spellID, spellBank, true)
    else
        ok, result = pcall(spellBook.IsSpellInSpellBook, spellID)
    end
    return ok
        and EAM.Util
        and EAM.Util.isSafeBoolean(result)
        and result == true
end

local function resolveAuraCatalogScope(alertOrSpellID)
    if type(alertOrSpellID) == "table" then
        local scope = alertOrSpellID.catalogScope
        if scope == EAM.Constants.AURA_CATALOG_SCOPE_SELF
            or scope == EAM.Constants.AURA_CATALOG_SCOPE_CROSS_CLASS then
            return scope
        end
        alertOrSpellID = alertOrSpellID.spellID
    end
    if isCurrentClassSpell(alertOrSpellID) then
        return EAM.Constants.AURA_CATALOG_SCOPE_SELF
    end
    return EAM.Constants.AURA_CATALOG_SCOPE_CROSS_CLASS
end

local function alertMatchesCategory(alert, category)
    if category == 1 then
        return resolveAuraCatalogScope(alert) == EAM.Constants.AURA_CATALOG_SCOPE_SELF
    end
    if category == 2 then
        return resolveAuraCatalogScope(alert) == EAM.Constants.AURA_CATALOG_SCOPE_CROSS_CLASS
    end
    return category >= 3 and category <= 6
end

local function isAlertDisplayable(alert)
    if type(alert) ~= "table" then
        return false
    end
    if alert.itemID ~= nil then
        return type(alert.itemID) == "number" and alert.itemID % 1 == 0 and alert.itemID > 0
    end
    return isExistingSpell(alert.spellID)
end

local function migratePlayerAuraCatalogScopes(rawList)
    if type(rawList) ~= "table" then
        return false
    end
    local changed = false
    for _, alert in pairs(rawList) do
        if type(alert) == "table" and isExistingSpell(alert.spellID) then
            local scope = resolveAuraCatalogScope(alert.spellID)
            if alert.catalogScope ~= scope then
                alert.catalogScope = scope
                changed = true
            end
            if scope == EAM.Constants.AURA_CATALOG_SCOPE_CROSS_CLASS
                and alert.fromPlayer ~= nil then
                alert.fromPlayer = nil
                changed = true
            end
        end
    end
    if changed then
        local saved = EAM.Modules and EAM.Modules.SavedVariables
        if saved and saved.commitAlertBatch then
            saved.commitAlertBatch(EAM.Constants.ALERT_KIND_AURA, true)
        end
        Options.notifyConfigChanged()
    end
    return changed
end

local function addAlertToCategory(category, id, deferCommit)
    local saved = EAM.Modules and EAM.Modules.SavedVariables
    if not saved then
        return false, nil, "savedVariablesUnavailable"
    end
    id = tonumber(id)
    if type(id) ~= "number" or id % 1 ~= 0 or id <= 0 then
        return false, nil, "invalidID"
    end
    if category ~= 5 and not isExistingSpell(id) then
        return false, nil, "spellNotFound"
    end

    local options = deferCommit and { deferCommit = true } or {}
    local reclassified = false
    local ok, alertID, status
    if category == 1 then
        if type(saved.addAuraAlert) ~= "function" then
            return false, nil, "savedVariablesMethodUnavailable"
        end
        local scope = resolveAuraCatalogScope(id)
        options.catalogScope = scope
        options.fromPlayer = scope == EAM.Constants.AURA_CATALOG_SCOPE_SELF
        reclassified = scope == EAM.Constants.AURA_CATALOG_SCOPE_CROSS_CLASS
        ok, alertID, status = saved.addAuraAlert("player", id, options)
    elseif category == 2 then
        if type(saved.addAuraAlert) ~= "function" then
            return false, nil, "savedVariablesMethodUnavailable"
        end
        options.catalogScope = EAM.Constants.AURA_CATALOG_SCOPE_CROSS_CLASS
        options.fromPlayer = false
        ok, alertID, status = saved.addAuraAlert("player", id, options)
    elseif category == 3 then
        if type(saved.addAuraAlert) ~= "function" then
            return false, nil, "savedVariablesMethodUnavailable"
        end
        options.catalogScope = resolveAuraCatalogScope(id)
        options.fromPlayer = true
        ok, alertID, status = saved.addAuraAlert("target", id, options)
    elseif category == 4 then
        if type(saved.addSpellCooldownAlert) ~= "function" then
            return false, nil, "savedVariablesMethodUnavailable"
        end
        ok, alertID, status = saved.addSpellCooldownAlert(id, options)
    elseif category == 5 then
        if type(saved.addItemCooldownAlert) ~= "function" then
            return false, nil, "savedVariablesMethodUnavailable"
        end
        ok, alertID, status = saved.addItemCooldownAlert(id, options)
    elseif category == 6 then
        if type(saved.addGroundEffectAlert) ~= "function" then
            return false, nil, "savedVariablesMethodUnavailable"
        end
        ok, alertID, status = saved.addGroundEffectAlert(id, options)
    else
        return false, nil, "invalidCategory"
    end
    return ok, alertID, status, reclassified
end

Options.addAlertToCategory = addAlertToCategory
-- 刷新滾動列表
function Options.refreshList()
    if not Options.listFrame or not Options.listFrame:IsShown() then return end
    
    local saved = EAM.Modules.SavedVariables
    if not saved then return end
    
    local listData = {}
    local rawList = Options.getCurrentCategoryList()
    
    if Options.currentCategory == 1 or Options.currentCategory == 2 then
        migratePlayerAuraCatalogScopes(rawList)
    end

    for _, alert in pairs(rawList) do
        if alertMatchesCategory(alert, Options.currentCategory) and isAlertDisplayable(alert) then
            local passSpec = true
            if Options.currentSpecFilter ~= nil then
                local specOfSpell = getSpellSpec(alert.spellID)
                if Options.currentSpecFilter == 0 then
                    passSpec = specOfSpell == 0 or specOfSpell == nil
                else
                    passSpec = specOfSpell == Options.currentSpecFilter
                end
            end
            if passSpec then
                listData[#listData + 1] = alert
            end
        end
    end
    table.sort(listData, function(a, b)
        local orderA = a.order or 9999
        local orderB = b.order or 9999
        if orderA ~= orderB then
            return orderA < orderB
        end
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

local function moveAlertInCurrentList(targetAlert, delta)
    if not targetAlert then return end
    local rawList = Options.getCurrentCategoryList()
    if not rawList then return end
    
    local listData = {}
    for _, alert in pairs(rawList) do
        if alertMatchesCategory(alert, Options.currentCategory) and isAlertDisplayable(alert) then
            listData[#listData + 1] = alert
        end
    end
    table.sort(listData, function(a, b)
        local orderA = a.order or 9999
        local orderB = b.order or 9999
        if orderA ~= orderB then return orderA < orderB end
        local idA = a.spellID or a.itemID or 0
        local idB = b.spellID or b.itemID or 0
        return idA < idB
    end)
    
    local targetIdx = nil
    for idx = 1, #listData do
        if listData[idx] == targetAlert or (listData[idx].id and listData[idx].id == targetAlert.id) then
            targetIdx = idx
            break
        end
    end
    if not targetIdx then return end
    
    local destIdx = targetIdx + delta
    if destIdx < 1 or destIdx > #listData then return end
    
    local item = table.remove(listData, targetIdx)
    table.insert(listData, destIdx, item)
    
    for idx = 1, #listData do
        listData[idx].order = idx
    end
    
    if EAM.Modules and EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.markRevisionChanged then
        EAM.Modules.SavedVariables.markRevisionChanged()
    end
    Options.notifyConfigChanged()
    Options.refreshList()
end

local function swapAlertsInCurrentList(alertA, alertB)
    if not alertA or not alertB or alertA == alertB then return end
    local rawList = Options.getCurrentCategoryList()
    if not rawList then return end
    
    local listData = {}
    for _, alert in pairs(rawList) do
        if alertMatchesCategory(alert, Options.currentCategory) and isAlertDisplayable(alert) then
            listData[#listData + 1] = alert
        end
    end
    table.sort(listData, function(a, b)
        local orderA = a.order or 9999
        local orderB = b.order or 9999
        if orderA ~= orderB then return orderA < orderB end
        local idA = a.spellID or a.itemID or 0
        local idB = b.spellID or b.itemID or 0
        return idA < idB
    end)
    
    local idxA, idxB
    for idx = 1, #listData do
        if listData[idx] == alertA or (listData[idx].id and listData[idx].id == alertA.id) then
            idxA = idx
        end
        if listData[idx] == alertB or (listData[idx].id and listData[idx].id == alertB.id) then
            idxB = idx
        end
    end
    if not idxA or not idxB then return end
    
    local item = table.remove(listData, idxA)
    table.insert(listData, idxB, item)
    
    for idx = 1, #listData do
        listData[idx].order = idx
    end
    
    if EAM.Modules and EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.markRevisionChanged then
        EAM.Modules.SavedVariables.markRevisionChanged()
    end
    Options.notifyConfigChanged()
    Options.refreshList()
end

-- 批次操作 (Select All, Deselect All, Delete All)
local function batchOperation(action)
    local saved = EAM.Modules.SavedVariables
    if not saved then return end
    
    local rawList = Options.getCurrentCategoryList()
    for id, alert in pairs(rawList) do
        if alertMatchesCategory(alert, Options.currentCategory) then
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
    local ok, alertID, status, reclassified = addAlertToCategory(Options.currentCategory, id, false)
    if ok then
        if status ~= "unchanged" then
            Options.notifyConfigChanged()
            if Options.currentCategory == 6 then
                notifyGroundEffectConfigChanged()
            end
        end
        Options.refreshList()
        if reclassified then
            print(string.format(
                EAM.L.EAM_OPT_ADD_RECLASSIFIED
                    or "|cff00ff96EAM|r [ID: %s] 不屬於目前職業，已加入跨職業增減益清單。",
                id
            ))
        else
            print(string.format(EAM.L.EAM_OPT_ADD_SUCCESS or "|cff00ff96EAM|r 成功新增監控提醒 [ID: %s]", id))
        end
        return true, status, reclassified
    end

    if status == "spellNotFound" then
        print(string.format(
            EAM.L.EAM_OPT_ERR_SPELL_NOT_FOUND
                or "|cff00ff96EAM|r 找不到 SpellID %s；未加入且不會顯示。",
            tostring(id)
        ))
    else
        print(string.format(EAM.L.EAM_OPT_ADD_FAIL or "|cff00ff96EAM|r 新增監控提醒失敗: %s", tostring(status or alertID)))
    end
    return false, status
end
local function getCategoryAlertKind(category)
    if category == 1 or category == 2 or category == 3 then
        return EAM.Constants.ALERT_KIND_AURA
    elseif category == 4 then
        return EAM.Constants.ALERT_KIND_SPELL_COOLDOWN
    elseif category == 5 then
        return EAM.Constants.ALERT_KIND_ITEM_COOLDOWN
    elseif category == 6 then
        return EAM.Constants.ALERT_KIND_GROUND_EFFECT
    end
    return nil
end

function Options.parseBatchIDs(value)
    local ids = {}
    local seen = {}
    local invalid = 0
    value = type(value) == "string" and value:gsub("；", ";") or ""
    for token in value:gmatch("[^%s;,]+") do
        local id = tonumber(token)
        if type(id) == "number" and id % 1 == 0 and id > 0 then
            if not seen[id] then
                seen[id] = true
                ids[#ids + 1] = id
            end
        else
            invalid = invalid + 1
        end
    end
    table.sort(ids)
    return ids, invalid
end

function Options.buildCurrentCategoryIDText(category)
    local rawList = Options.getCategoryList(category)
    local ids = {}
    for _, alert in pairs(rawList) do
        if alertMatchesCategory(alert, category) and isAlertDisplayable(alert) then
            local id = alert.spellID or alert.itemID
            if type(id) == "number" and id % 1 == 0 and id > 0 then
                ids[#ids + 1] = id
            end
        end
    end
    table.sort(ids)
    local values = {}
    for index = 1, #ids do
        values[index] = tostring(ids[index])
    end
    return table.concat(values, "; ")
end

function Options.applyBatchIDs(category, value)
    local ids, invalid = Options.parseBatchIDs(value)
    local report = {
        total = #ids,
        added = 0,
        updated = 0,
        unchanged = 0,
        invalid = invalid,
        reclassified = 0,
    }
    local kind = getCategoryAlertKind(category)
    if not kind or #ids == 0 then
        return false, report, kind and "empty" or "invalidCategory"
    end

    local changed = false
    for index = 1, #ids do
        local ok, _, status, reclassified = addAlertToCategory(category, ids[index], true)
        if ok then
            if status == "added" then
                report.added = report.added + 1
                changed = true
            elseif status == "updated" then
                report.updated = report.updated + 1
                changed = true
            else
                report.unchanged = report.unchanged + 1
            end
            if reclassified then
                report.reclassified = report.reclassified + 1
            end
        else
            report.invalid = report.invalid + 1
        end
    end

    local saved = EAM.Modules and EAM.Modules.SavedVariables
    if saved and saved.commitAlertBatch then
        saved.commitAlertBatch(kind, changed)
    end
    if changed then
        Options.notifyConfigChanged()
        if category == 6 then
            notifyGroundEffectConfigChanged()
        end
    end
    if category == Options.currentCategory then
        Options.refreshList()
    end
    return true, report, changed and "updated" or "unchanged"
end

local function makeTitleCloseButton(parent, onClick)
    local btn = api.CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    btn:SetSize(28, 28)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)
    btn:SetScript("OnClick", function()
        if type(onClick) == "function" then
            onClick()
        else
            parent:Hide()
        end
    end)
    return btn
end

local function safeClosePanel(panel)
    if not panel then return end
    if type(panel.close) == "function" then
        panel.close()
    elseif type(panel.hide) == "function" then
        panel.hide()
    elseif panel.frame and panel.frame.Hide then
        panel.frame:Hide()
    end
end

function Options.closeAllSidePanels(except)
    if except ~= "list" and Options.listFrame then
        Options.listFrame:Hide()
        if Options.condFrame then Options.condFrame:Hide() end
        if Options.batchFrame then Options.batchFrame:Hide() end
    end
    if except ~= "pos" and Options.posFrame then
        Options.posFrame:Hide()
    end
    if except ~= "resource" then
        safeClosePanel(EAM.UI and EAM.UI.PlayerResourcePanel)
    end
    if except ~= "stat" then
        safeClosePanel(EAM.UI and EAM.UI.PlayerStatPanel)
    end
    if except ~= "debug" then
        safeClosePanel(EAM.UI and EAM.UI.DebugCenterPanel)
    end
    if except ~= "profile" then
        safeClosePanel(EAM.UI and EAM.UI.ProfileCodecPanel)
    end
    if except ~= "module" then
        safeClosePanel(EAM.UI and EAM.UI.ModulePanel)
    end
    if except ~= "about" then
        safeClosePanel(EAM.UI and EAM.UI.AboutPanel)
    end
    if except ~= "group" then
        safeClosePanel(EAM.UI and EAM.UI.GroupManagerPanel)
    end
    if except ~= "catalog" then
        safeClosePanel(EAM.UI and EAM.UI.SpellCatalogTreePanel)
    end
    if not except and EAM.UI.Renderer and EAM.UI.Renderer.setActiveAnchors then
        EAM.UI.Renderer.setActiveAnchors(nil)
    end
end
EAM.UI = EAM.UI or {}
EAM.UI.closeAllSidePanels = Options.closeAllSidePanels

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
local function createCheckbox(parent, text, key, x, y, onChange, tooltipText, tooltipTitle)
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
    if tooltipText then
        setTooltip(cb, tooltipText, tooltipTitle or text)
    end
    return cb
end

-- 建立由 Theme 統一控制底色、狀態色與邊框的 EAM 按鈕。
local function createThemedButton(parent, text, x, y, width, height, onClick, tooltipText, tooltipTitle)
    local btn = api.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 120, height or 24)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    setWidgetText(btn, text)
    if Theme and Theme.registerButton then Theme.registerButton(btn) end

    btn:SetScript("OnClick", onClick)
    if tooltipText then
        setTooltip(btn, tooltipText, tooltipTitle or text)
    end
    return btn
end

local DROPDOWN_TEXTURE = "Interface\\Buttons\\WHITE8X8"

local function getFrameLevel(frame)
    if not frame or type(frame.GetFrameLevel) ~= "function" then
        return 0
    end
    local ok, level = pcall(frame.GetFrameLevel, frame)
    if ok and type(level) == "number" then
        return level
    end
    return 0
end

-- 自製下拉選單必須同時套用主題、提高層級，避免 backdrop 蓋住列文字。
local function registerDropdownMenu(menu, anchor)
    if not menu then
        return
    end
    local parent = type(menu.GetParent) == "function" and menu:GetParent() or nil
    if type(menu.SetFrameLevel) == "function" then
        menu:SetFrameLevel(math.max(getFrameLevel(parent), getFrameLevel(anchor)) + 10)
    end
    if Theme and Theme.registerFrame then
        Theme.registerFrame(menu, "menu")
    end
end

-- 裸 Button 沒有 normal/pushed 材質；先建立材質再註冊 Theme，當前主題才能立即著色。
local function finalizeDropdownMenuButton(button, label, menu)
    if not button then
        return
    end
    button:SetNormalTexture(DROPDOWN_TEXTURE)
    button:SetPushedTexture(DROPDOWN_TEXTURE)
    button:SetDisabledTexture(DROPDOWN_TEXTURE)
    button:SetHighlightTexture(DROPDOWN_TEXTURE)
    if type(button.SetFrameLevel) == "function" then
        button:SetFrameLevel(getFrameLevel(menu) + 1)
    end
    if Theme and Theme.registerButton then
        Theme.registerButton(button)
    end
    if label and Theme and Theme.registerText then
        Theme.registerText(label, "button")
    end
end

local function buildScrollableDropdownMenu(menuFrame, parentButton, getListFunc, onSelectFunc, menuWidth, maxVisibleItems)
    menuWidth = menuWidth or 200
    maxVisibleItems = maxVisibleItems or 10
    local itemHeight = 22
    local scrollFrame = menuFrame.scrollFrame
    local scrollChild = menuFrame.scrollChild
    local buttons = menuFrame.buttons or {}
    menuFrame.buttons = buttons

    if not scrollFrame then
        scrollFrame = api.CreateFrame("ScrollFrame", nil, menuFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 4, -4)
        scrollFrame:SetPoint("BOTTOMRIGHT", menuFrame, "BOTTOMRIGHT", -24, 4)
        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(self, delta)
            local current = self:GetVerticalScroll() or 0
            local maxScroll = self:GetVerticalScrollRange() or 0
            local step = itemHeight * 2
            local target = math.max(0, math.min(maxScroll, current - delta * step))
            self:SetVerticalScroll(target)
        end)
        scrollChild = api.CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
        scrollFrame:SetScrollChild(scrollChild)
        menuFrame.scrollFrame = scrollFrame
        menuFrame.scrollChild = scrollChild
    end

    local list = getListFunc() or {}
    local total = #list
    local visibleCount = math.min(total, maxVisibleItems)
    local menuHeight = math.max(30, (visibleCount * itemHeight) + 8)

    local buttonWidth = total > maxVisibleItems and (menuWidth - 30) or (menuWidth - 8)
    menuFrame:SetSize(menuWidth, menuHeight)
    scrollChild:SetSize(buttonWidth, math.max(1, total * itemHeight))
    if total <= maxVisibleItems then
        scrollFrame:SetPoint("BOTTOMRIGHT", menuFrame, "BOTTOMRIGHT", -4, 4)
        local scrollBar = scrollFrame.ScrollBar or (scrollFrame.GetName and _G[scrollFrame:GetName() .. "ScrollBar"])
        if scrollBar then scrollBar:Hide() end
    else
        scrollFrame:SetPoint("BOTTOMRIGHT", menuFrame, "BOTTOMRIGHT", -24, 4)
        local scrollBar = scrollFrame.ScrollBar or (scrollFrame.GetName and _G[scrollFrame:GetName() .. "ScrollBar"])
        if scrollBar then scrollBar:Show() end
    end
    scrollFrame:SetVerticalScroll(0)

    for i = 1, #buttons do
        buttons[i]:Hide()
    end

    for index = 1, total do
        local item = list[index]
        local btn = buttons[index]
        if not btn then
            btn = api.CreateFrame("Button", nil, scrollChild)
            btn:SetSize(buttonWidth, 20)
            local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btnText:SetPoint("LEFT", btn, "LEFT", 6, 0)
            btn.text = btnText
            finalizeDropdownMenuButton(btn, btnText, menuFrame)
            buttons[index] = btn
        end
        btn:SetSize(buttonWidth, 20)
        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, -2 - (index - 1) * itemHeight)
        btn.text:SetText(item.text or item.value)
        btn:SetScript("OnClick", function()
            onSelectFunc(item)
            menuFrame:Hide()
        end)
        btn:Show()
    end
end

-- 建立通用 Slider
local function createSlider(parent, text, key, minVal, maxVal, step, x, y, width, isPercent, isFloat, tooltipText, tooltipTitle)
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
    local isChargeBarSlider = key == "chargeBarLengthPercent" or key == "chargeBarThickness"
    local function commitNativeChange()
        if not slider.eamNativeChangeDirty then
            return
        end
        slider.eamNativeChangeDirty = false
        if isTextLayoutSlider then
            Options.notifyTextLayoutChanged(true)
        elseif isChargeBarSlider then
            Options.notifyConfigChanged(false)
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
        elseif (key == "cooldownSwipeAlpha"
            or key == "chargeBarLengthPercent"
            or key == "chargeBarThickness")
            and savedVariables and savedVariables.updateConfigNumber
        then
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
            elseif isNativeStructureSlider or isNativeVisualSlider or isChargeBarSlider then
                self.eamNativeChangeDirty = true
                Options.notifyConfigChanged(false)
            else
                Options.notifyConfigChanged()
            end
            if EAM.UI.Renderer and EAM.UI.Renderer.refreshPreviewLayout then
                EAM.UI.Renderer.refreshPreviewLayout()
            end
        end
    end)
    if isTextLayoutSlider or isNativeStructureSlider or isNativeVisualSlider or isChargeBarSlider then
        slider:HookScript("OnMouseUp", commitNativeChange)
        slider:HookScript("OnHide", commitNativeChange)
    end

    if tooltipText then
        setTooltip(slider, tooltipText, tooltipTitle or text)
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
    frame:SetClampedToScreen(true)
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
    setTooltip(moduleButton, "開啟或關閉各項獨立功能模組（自身、目標、冷卻、物品、地面、資源、屬性等）", "功能模組")
    moduleButton:SetScript("OnClick", function()
        Options.closeAllSidePanels("module")
        local modulePanel = EAM.UI and EAM.UI.ModulePanel or nil
        if modulePanel and type(modulePanel.open) == "function" then
            modulePanel.open()
        end
    end)

    local aboutButton = api.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(aboutButton) end
    aboutButton:SetSize(56, 22)
    aboutButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -13)
    bindText(aboutButton, "EAM_OPT_ABOUT_BTN", "關於")
    setTooltip(aboutButton, "查看插件版本資訊、作者、更新日誌與技術架構說明", "關於 EventAlertMod")
    aboutButton:SetScript("OnClick", function()
        Options.closeAllSidePanels("about")
        local aboutPanel = EAM.UI and EAM.UI.AboutPanel or nil
        if aboutPanel and type(aboutPanel.open) == "function" then
            aboutPanel.open()
        end
    end)
    makeTitleCloseButton(frame, function()
        frame:Hide()
    end)
    frame:SetScript("OnHide", function()
        Options.closeAllSidePanels()
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

    local themeDropdown = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(themeDropdown) end
    themeDropdown:SetSize(154, 22)
    themeDropdown:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -12, -10)
    setTooltip(themeDropdown, "切換 EAM 設定介面之邊框與按鈕主題外觀風格", "介面佈局主題")
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
    registerDropdownMenu(themeMenu, themeDropdown)
    themeMenu:Hide()
    Options.themeMenu = themeMenu

    local themeOptions = Theme and Theme.ThemeOptions or {}
    for index = 1, #themeOptions do
        local option = themeOptions[index]
        local menuButton = api.CreateFrame("Button", nil, themeMenu)
        menuButton:SetSize(174, 20)
        menuButton:SetPoint("TOPLEFT", themeMenu, "TOPLEFT", 3, -3 - (index - 1) * 22)
        local menuButtonText = menuButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        menuButtonText:SetPoint("LEFT", menuButton, "LEFT", 6, 0)
        bindText(menuButtonText, option.labelKey, option.label)
        finalizeDropdownMenuButton(menuButton, menuButtonText, themeMenu)
        menuButton:SetScript("OnClick", function()
            local saved = EAM.Modules and EAM.Modules.SavedVariables
            if saved and saved.updateTheme then
                local ok, status = saved.updateTheme(option.value)
                if ok and Theme and Theme.setSelection then
                    local applied, applyStatus = Theme.setSelection(option.value)
                    Theme.flushPending()
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

    -- 自製 Sound Dropdown
    local soundDropdown = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(soundDropdown) end
    soundDropdown:SetSize(130, 22)
    soundDropdown:SetPoint("TOPLEFT", inner, "TOPLEFT", 12, -10)
    soundDropdown:SetText((EAM.L.EAM_OPT_SOUND_PREFIX or "音效: ") .. "ShayBell")
    setTooltip(soundDropdown, "選擇觸發提醒時播放的預設音效", "音效警告")
    Options.soundDropdown = soundDropdown

    local playSoundBtn = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(playSoundBtn) end
    playSoundBtn:SetSize(44, 22)
    playSoundBtn:SetPoint("LEFT", soundDropdown, "RIGHT", 6, 0)
    bindText(playSoundBtn, "EAM_OPT_TEST_BTN", "測試")
    setTooltip(playSoundBtn, "播放當前選擇的音效檔案進行試聽", "測試音效")

    local soundMenu = api.CreateFrame("Frame", nil, inner, "BackdropTemplate")
    soundMenu:SetSize(220, 228)
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
    registerDropdownMenu(soundMenu, soundDropdown)
    soundMenu:Hide()

    local function populateSoundMenu()
        buildScrollableDropdownMenu(
            soundMenu,
            soundDropdown,
            function()
                local MediaService = EAM.Services and EAM.Services.MediaService
                if MediaService and MediaService.getMediaList then
                    return MediaService.getMediaList("sound", true)
                end
                local list = {}
                for _, sName in ipairs(soundNames) do
                    list[#list + 1] = { value = sName, text = sName }
                end
                return list
            end,
            function(item)
                if EAM.db and EAM.db.config then
                    EAM.db.config.soundName = item.value
                    if EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.markRevisionChanged then
                        EAM.Modules.SavedVariables.markRevisionChanged()
                    end
                    Options.refreshSoundDropdown()
                    notifyAuraSoundChanged()
                    Options.notifyConfigChanged(false)
                    local MediaService = EAM.Services and EAM.Services.MediaService
                    if MediaService and MediaService.playSound then
                        MediaService.playSound(item.value)
                    end
                end
            end,
            220,
            10
        )
        for _, btn in ipairs(soundMenu.buttons or {}) do
            finalizeDropdownMenuButton(btn, btn.text, soundMenu)
        end
    end

    soundDropdown:SetScript("OnClick", function()
        if soundMenu:IsShown() then
            soundMenu:Hide()
        else
            populateSoundMenu()
            soundMenu:Show()
        end
    end)

    playSoundBtn:SetScript("OnClick", function()
        local sName = (EAM.db and EAM.db.config and EAM.db.config.soundName) or "ShayBell"
        local MediaService = EAM.Services and EAM.Services.MediaService
        if MediaService and MediaService.playSound then
            MediaService.playSound(sName)
        else
            local asset = soundAssets[sName] or 568154
            PlaySoundFile(asset, "Master")
        end
    end)

    -- 語系選擇下拉選單
    local languageDropdown = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(languageDropdown) end
    languageDropdown:SetSize(158, 22)
    languageDropdown:SetPoint("TOPLEFT", inner, "TOPLEFT", 12, -38)
    setTooltip(languageDropdown, "切換插件顯示之語系（繁體中文/簡體中文/英文/韓文/俄文/自動偵測）", "插件語言")
    Options.languageDropdown = languageDropdown

    local languageMenu = api.CreateFrame("Frame", nil, inner, "BackdropTemplate")
    languageMenu:SetSize(158, 138)
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
    registerDropdownMenu(languageMenu, languageDropdown)
    languageMenu:Hide()
    Options.languageMenu = languageMenu

    local languageOptions = EAM.Locale and EAM.Locale.LanguageOptions or {}
    for index = 1, #languageOptions do
        local option = languageOptions[index]
        local menuButton = api.CreateFrame("Button", nil, languageMenu)
        menuButton:SetSize(152, 20)
        menuButton:SetPoint("TOPLEFT", languageMenu, "TOPLEFT", 3, -3 - (index - 1) * 22)

        local menuButtonText = menuButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        menuButtonText:SetPoint("LEFT", menuButton, "LEFT", 6, 0)
        menuButtonText:SetText(option.label)
        finalizeDropdownMenuButton(menuButton, menuButtonText, languageMenu)

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

    local nativeAuraStatusLabel = inner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nativeAuraStatusLabel:SetPoint("TOPLEFT", inner, "TOPLEFT", 180, -42)
    nativeAuraStatusLabel:SetWidth(108)
    nativeAuraStatusLabel:SetJustifyH("LEFT")
    Options.nativeAuraStatusLabel = nativeAuraStatusLabel

    local nativeAuraRebuildButton = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(nativeAuraRebuildButton) end
    nativeAuraRebuildButton:SetSize(54, 20)
    nativeAuraRebuildButton:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -12, -38)
    bindText(nativeAuraRebuildButton, "EAM_OPT_AURA_APPLY", "套用")
    setTooltip(nativeAuraRebuildButton, "立即手動重建暴雪底層 Native Aura 結構以套用最新光環設定", "套用 Native Aura")
    nativeAuraRebuildButton:SetScript("OnClick", function()
        local service = EAM.Services.AuraContainerService
        if service and service.requestRebuild then
            service.requestRebuild("OPTIONS_MANUAL_REBUILD")
        end
        Options.refreshAuraBackendStatus()
    end)
    Options.refreshAuraBackendStatus()

    -- 11 個核心設定 Checkboxes（對齊 2 欄 6 行）與獨立測試閃爍按鈕
    createCheckbox(inner, localized("EAM_OPT_ENABLE_FRAME", "啟用提醒框架"), "showFrame", 12, -66, nil, "總開關：開啟或暫停所有畫面中央告警框架的顯示", "啟用提醒框架")
    createCheckbox(inner, localized("EAM_OPT_SHOW_SPELL_NAME", "顯示法術名稱"), "showSpellName", 180, -66, nil, "在告警圖示上方或下方顯示技能與物品名稱", "顯示法術名稱")

    createCheckbox(inner, localized("EAM_OPT_SHOW_TIME_VAL", "顯示倒數秒數"), "showTimeVal", 12, -90, nil, "在告警圖示上即時顯示剩餘持續時間或冷卻秒數", "顯示倒數秒數")
    createCheckbox(
        inner,
        localized("EAM_OPT_SHOW_SOUND", "啟用音效警告"),
        "showSound",
        180,
        -90,
        function()
            notifyAuraSoundChanged()
            return false
        end,
        "當新提醒觸發時播放對應警示音效",
        "啟用音效警告"
    )

    createCheckbox(inner, localized("EAM_OPT_SHOW_FLASH", "啟用全螢幕閃爍"), "showFlash", 12, -114, nil, "當特定重大光環觸發或進入戰鬥時，全螢幕邊緣閃爍紅框", "啟用全螢幕閃爍")
    createCheckbox(inner, localized("EAM_OPT_ALLOW_ESC", "啟用 ESC 鍵關閉"), "allowEscCancel", 180, -114, nil, "按鍵盤 ESC 鍵時自動關閉 EAM 設定視窗", "啟用 ESC 鍵關閉")

    createCheckbox(inner, localized("EAM_OPT_SHOW_EXTRA_ALERT", "顯示額外輔助提醒"), "showExtraAlert", 12, -138, nil, "啟用特異光環與特殊職業機制的輔助提示", "顯示額外輔助提醒")
    createCheckbox(inner, localized("EAM_OPT_SHOW_SCD_OUTSIDE", "非戰鬥顯示技能冷卻"), "showSCDOutsideCombat", 180, -138, nil, "脫離戰鬥後仍持續顯示技能冷卻倒數", "非戰鬥顯示技能冷卻")

    createCheckbox(inner, localized("EAM_OPT_COOLDOWN_REMOVE", "冷卻完成移除光環"), "cooldownRemoveAura", 12, -162, nil, "技能或物品冷卻結束時自動隱藏圖示，不留常駐圖示", "冷卻完成移除光環")
    createCheckbox(inner, localized("EAM_OPT_GLOW_SCD", "可用時高亮技能冷卻"), "glowSCDWhenUsable", 180, -162, nil, "技能冷卻完畢且可用時，圖示外框發出流光動畫提示", "可用時高亮技能冷卻")

    createCheckbox(inner, localized("EAM_OPT_COOLDOWN_PRERENDER", "冷卻預渲染佔位 (未使用灰色遮罩)"), "cooldownPreRender", 12, -186, nil, localized("EAM_OPT_COOLDOWN_PRERENDER_TIP", "在脫戰狀態下預先建立並排列冷卻圖示槽位。尚未進入冷卻的技能以暗色灰階圖示佔位顯示，徹底解決戰鬥中首次施放因戰鬥鎖定無法排版渲染的問題。"), "冷卻預渲染佔位")
    createCheckbox(inner, localized("EAM_OPT_RADIAL_GAUGE", "啟用 12.1 原生圓形光環倒數光圈"), "showRadialGauge", 180, -186, nil, "在光環與冷卻圖示周圍繪製 12.1 原生向量平滑消退光圈與斬殺期高亮", "原生圓形進度光圈")

    -- 11 個主要功能大按鈕（職業資源第 7 項、角色屬性第 8 項、群組管理第 9 項、全量法術庫第 10 項、排版第 11 項）
    local categories = {
        { key = "EAM_OPT_CAT_SELF", fallback = "自身增益/減益提醒 (Self)", tip = "設定玩家自身身上觸發的 Buff 與 Debuff 告警清單" },
        { key = "EAM_OPT_CAT_CLASS", fallback = "跨職業增益/減益提醒 (Class)", tip = "設定所有其他職業之通用或重要光環監控" },
        { key = "EAM_OPT_CAT_TARGET", fallback = "目標增益/減益提醒 (Target)", tip = "設定當前選取目標身上的 Buff/Debuff（如斬殺、流血、易傷等）" },
        { key = "EAM_OPT_CAT_SPELL_CD", fallback = "技能冷卻監控設定 (Spell CD)", tip = "設定主要技能的冷卻時間、充能層數與可用高亮提醒" },
        { key = "EAM_OPT_CAT_ITEM_CD", fallback = "物品冷卻監控設定 (Item CD)", tip = "設定飾品、藥水、主動使用裝備之冷卻時間監控" },
        { key = "EAM_OPT_CAT_GROUND", fallback = "地面技能與效果設定 (Ground Effect)", tip = "設定死亡凋零、奉獻等無目標地面法術之持續時間提醒" },
        { key = "EAM_OPT_CAT_RESOURCE", fallback = localized("EAM_RESOURCE_OPEN", "★ 玩家職業資源設定 (Player Resource)"), tip = "設定連擊點、聖能、符文、真氣、魂片、奧術充能等能量條與數值" },
        { key = "EAM_OPT_CAT_STAT", fallback = localized("EAM_STAT_OPEN", "★ 角色屬性與吸收量監控 (Player Stats)"), tip = "設定力量/敏捷/致命/加速/精通/跑速/飛龍騎術/護甲/吸收盾等即時監控" },
        { key = "EAM_OPT_CAT_GROUP", fallback = localized("EAM_GROUP_OPEN", "★ 群組分類與標籤管理 (Group Management)"), tip = "管理戰術分類與自訂標籤群組，支援多對多法術複選與情境過濾" },
        { key = "EAM_OPT_CAT_CATALOG", fallback = localized("EAM_CATALOG_OPEN", "★ 全量法術庫與智慧預設 (Spell Catalog)"), tip = "以階層樹狀檢視全職業核心技能，支援三態勾選與依天賦智慧同步" },
        { key = "EAM_OPT_CAT_LAYOUT", fallback = "告警框架位置與排版 (Alert Frame Layout)", tip = "調整各告警模組圖示大小、間距、排列方向、字型大小與排版" },
    }
    Options.categoryDefinitions = categories

    local categoryFrameMap = {
        [1] = "selfAura",
        [2] = "selfAura",
        [3] = "targetAura",
        [4] = "spellCooldown",
        [5] = "itemCooldown",
        [6] = "groundEffect",
        [7] = "classPower",
        [8] = "playerStat",
        [9] = nil,
        [10] = nil,
        [11] = "all",
    }

    for idx, category in ipairs(categories) do
        createThemedButton(inner, localized(category.key, category.fallback), 12, -214 - (idx - 1) * 24, 332, 22, function()
            if idx <= 6 then
                Options.closeAllSidePanels("list")
                Options.currentCategory = idx
                Options.listFrame:Show()
                if Options.listTitleText then
                    bindText(Options.listTitleText, category.key, category.fallback)
                end
                Options.refreshList()
                if EAM.UI.Renderer and EAM.UI.Renderer.setActiveAnchors then
                    EAM.UI.Renderer.setActiveAnchors(categoryFrameMap[idx])
                end
            elseif idx == 7 then
                Options.closeAllSidePanels("resource")
                local panel = EAM.UI and EAM.UI.PlayerResourcePanel
                if panel and type(panel.open) == "function" then
                    panel.open()
                end
                if EAM.UI.Renderer and EAM.UI.Renderer.setActiveAnchors then
                    EAM.UI.Renderer.setActiveAnchors("classPower")
                end
            elseif idx == 8 then
                Options.closeAllSidePanels("stat")
                local panel = EAM.UI and EAM.UI.PlayerStatPanel
                if panel and type(panel.open) == "function" then
                    panel.open()
                end
                if EAM.UI.Renderer and EAM.UI.Renderer.setActiveAnchors then
                    EAM.UI.Renderer.setActiveAnchors("playerStat")
                end
            elseif idx == 9 then
                Options.closeAllSidePanels("group")
                local panel = EAM.UI and EAM.UI.GroupManagerPanel
                if panel and type(panel.open) == "function" then
                    panel.open()
                end
            elseif idx == 10 then
                Options.closeAllSidePanels("catalog")
                local panel = EAM.UI and EAM.UI.SpellCatalogTreePanel
                if panel and type(panel.open) == "function" then
                    panel.open()
                end
            else
                Options.closeAllSidePanels("pos")
                if Options.posFrame then
                    Options.posFrame:Show()
                end
                if EAM.UI.Renderer and EAM.UI.Renderer.setActiveAnchors then
                    EAM.UI.Renderer.setActiveAnchors("all")
                end
            end
        end, category.tip, category.fallback)
    end

    -- 底部操作按鈕：Profile 匯入/匯出、整合診斷中心與關閉按鈕
    createThemedButton(inner, localized("EAM_OPT_PROFILE_BTN", "Profile 匯入／匯出"), 12, -484, 162, 22, function()
        Options.closeAllSidePanels("profile")
        local profilePanel = EAM.UI and EAM.UI.ProfileCodecPanel
        if profilePanel and type(profilePanel.open) == "function" then
            profilePanel.open()
        else
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_PROFILE_CODEC_STATUS_UNAVAILABLE or "Profile codec 尚未載入。"))
        end
    end, "將當前職業設定匯出為 JSON/Base64 字串，或從其他玩家字串匯入", "Profile 匯入／匯出")

    createThemedButton(inner, localized("EAM_OPT_DEBUG_CENTER_BTN", "除錯與測試診斷中心"), 182, -484, 162, 22, function()
        Options.closeAllSidePanels("debug")
        local debugCenter = EAM.UI and EAM.UI.DebugCenterPanel
        if debugCenter and type(debugCenter.open) == "function" then
            debugCenter.open()
        elseif EAM.Debug and EAM.Debug.PromptExport and EAM.Debug.PromptExport.openWindow then
            EAM.Debug.PromptExport.openWindow()
        else
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_DEBUG_NOT_LOADED or "除錯診斷模組尚未載入！"))
        end
    end, "執行流程自動化驗證、實機回報、運行探針與 AI 診斷報告輸出", "除錯與測試診斷中心")

    createThemedButton(inner, localized("EAM_OPT_CLOSE_BTN", "關閉設定 (Close)"), 12, -510, 332, 24, function()
        frame:Hide()
    end, "關閉主設定面板與所有二級子視窗", "關閉設定")

    Options.frame = frame


    -- ===================================================
    -- 2. Position & Energy Frame (Right Sliding Panel)
    -- ===================================================
    local posFrame = api.CreateFrame("Frame", "EAM_PositionOptionsFrame", frame, "BackdropTemplate")
    posFrame:SetSize(620, 560)
    posFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, 0)
    posFrame:EnableMouse(true)
    posFrame:RegisterForDrag("LeftButton")
    posFrame:SetScript("OnDragStart", function() frame:StartMoving() end)
    posFrame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    posFrame:SetScript("OnHide", function()
        if EAM.UI.Renderer and EAM.UI.Renderer.setActiveAnchors then
            EAM.UI.Renderer.setActiveAnchors(nil)
        end
    end)
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
    makeTitleCloseButton(posFrame, function() posFrame:Hide() end)

    local posTitle = posFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    posTitle:SetPoint("TOP", posFrame, "TOP", 0, -14)
    posTitle:SetTextColor(0.95, 0.85, 0.4, 1.0)
    bindText(posTitle, "EAM_OPT_POS_AND_POWER_BTN", "告警框架位置與排版設定")

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
    -- 【左側欄位】：告警圖示尺寸、間距與字型滑桿（寬度 250px）
    -- ---------------------------------------------------
    createSlider(posInner, localized("EAM_OPT_SLIDER_ICON_SIZE", "圖示大小 (Icon Size)"), "iconSize", 20, 100, 1, 16, -20, 250, nil, nil, "調整自身、目標、技能冷卻等所有告警圖示的寬高像素尺寸", "圖示大小")
    createSlider(posInner, localized("EAM_OPT_SLIDER_ICON_SPACING", "水平間距 (Horizontal Spacing)"), "iconSpacing", -200, 200, 1, 16, -68, 250, nil, nil, "調整相鄰告警圖示之間的水平間距像素距離", "水平間距")
    createSlider(posInner, localized("EAM_OPT_SLIDER_VERT_SPACING", "垂直間距 (Vertical Spacing)"), "verticalSpacing", -200, 200, 1, 16, -116, 250, nil, nil, "調整圖示換行或垂直成長時的垂直間距像素距離", "垂直間距")
    createSlider(posInner, localized("EAM_OPT_SLIDER_FONT_SPELL", "法術名稱字型 (Spell Font)"), "fontSizeSpellName", 8, 32, 1, 16, -164, 250, nil, nil, "調整顯示在圖示上方之法術與物品名稱的文字大小", "法術名稱字型")
    createSlider(posInner, localized("EAM_OPT_SLIDER_FONT_CD", "秒數倒數字型 (CD Font)"), "fontSizeTimeVal", 8, 32, 1, 16, -212, 250, nil, nil, "調整顯示在圖示上之剩餘秒數倒數計時數字大小", "秒數倒數字型")
    createSlider(posInner, localized("EAM_OPT_SLIDER_FONT_STACK", "堆疊層數字型 (Stack Font)"), "fontSizeStack", 8, 32, 1, 16, -260, 250, nil, nil, "調整顯示在圖示上之 Buff/Debuff 堆疊層數數字大小", "堆疊層數字型")
    createSlider(posInner, localized("EAM_OPT_SLIDER_SHADOW_ALPHA", "倒數轉圈透明度 (Swipe Alpha)"), "cooldownSwipeAlpha", 0, 1, 0.05, 16, -308, 250, true, nil, "調整技能冷卻時扇形倒數陰影遮罩的透明度 (0~100%)", "倒數轉圈透明度")
    createSlider(posInner, localized("EAM_OPT_SLIDER_DEBUFF_RED", "自身減益色度 (Self Debuff Red)"), "selfDebuffRed", 0.0, 1.0, 0.05, 16, -356, 250, true, nil, "自身受到減益效果 (Debuff) 時圖示邊框的紅色著色程度", "自身減益色度")
    createSlider(posInner, localized("EAM_OPT_SLIDER_DEBUFF_GREEN", "目標減益色度 (Target Debuff Green)"), "targetDebuffGreen", 0.0, 1.0, 0.05, 16, -404, 250, true, nil, "目標身上為減益效果時圖示邊框的綠色著色程度", "目標減益色度")
    
    createSlider(posInner, localized("EAM_OPT_SLIDER_EXECUTE_LIMIT", "斬殺血量閾值 (Execute Limit)"), "bossExecuteThreshold", 0.0, 1.0, 0.05, 16, -452, 130, true, nil, "設定目標斬殺血量比例門檻（例如 20% 或 35%）", "斬殺血量閾值")
    createCheckbox(posInner, localized("EAM_OPT_ENABLE_EXECUTE", "啟用斬殺線"), "enableBossExecute", 160, -458, nil, "啟用目標進入斬殺血量時之高亮提示與警示外框", "啟用斬殺線")

    -- ---------------------------------------------------
    -- 【右側欄位】：框架成長方向、文字錨點、全域字型與充能條
    -- ---------------------------------------------------
    local dirTitle = posInner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dirTitle:SetPoint("TOPLEFT", posInner, "TOPLEFT", 300, -15)
    dirTitle:SetTextColor(0.95, 0.85, 0.4, 1.0)
    bindText(dirTitle, "EAM_OPT_DIR_TITLE", "告警框架圖示成長方向設定")

    -- 輔助下拉選單建立器
    local function createDirectionDropdown(parent, labelText, frameName, x, y)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        label:SetTextColor(0.85, 0.75, 0.65, 1)
        setWidgetText(label, labelText)

        local btn = api.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        if Theme and Theme.registerButton then Theme.registerButton(btn) end
        btn:SetSize(130, 20)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 14)
        setTooltip(btn, "選擇此模組多個告警圖示出現時的排列延伸方向（向右/向左/向上/向下）", labelText)
        
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
        menu:SetSize(130, 84)
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
        registerDropdownMenu(menu, btn)
        menu:Hide()

        for idx, direction in ipairs(directions) do
            local menuBtn = api.CreateFrame("Button", nil, menu)
            menuBtn:SetSize(124, 18)
            menuBtn:SetPoint("TOPLEFT", menu, "TOPLEFT", 3, -3 - (idx - 1) * 20)

            local menuBtnText = menuBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            menuBtnText:SetPoint("LEFT", menuBtn, "LEFT", 6, 0)
            setWidgetText(menuBtnText, direction)
            finalizeDropdownMenuButton(menuBtn, menuBtnText, menu)

            menuBtn:SetScript("OnClick", function()
                if EAM.db and EAM.db.layout and EAM.db.layout.frames and EAM.db.layout.frames[frameName] then
                    EAM.db.layout.frames[frameName].growDirection = idx
                    updateBtnText()
                    if EAM.UI.Renderer and EAM.UI.Renderer.requestLayout then
                        EAM.UI.Renderer.requestLayout(frameName)
                    end
                    if EAM.UI.Renderer and EAM.UI.Renderer.refreshPreviewLayout then
                        EAM.UI.Renderer.refreshPreviewLayout()
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

    -- 建立 7 大框架成長方向選單（2 欄排列）
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_SELF_AURA", "自身光環成長"), "selfAura", 300, -38)
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_TARGET_AURA", "目標光環成長"), "targetAura", 445, -38)
    
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_SPELL_COOLDOWN", "技能冷卻成長"), "spellCooldown", 300, -78)
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_ITEM_COOLDOWN", "物品冷卻成長"), "itemCooldown", 445, -78)
    
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_GROUND_EFFECT", "地面效果成長"), "groundEffect", 300, -118)
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_TOTEM", "圖騰監控成長"), "totem", 445, -118)
    
    createDirectionDropdown(posInner, localized("EAM_OPT_GROW_CLASS_POWER", "職業能量成長"), "classPower", 300, -158)

    -- 倒數與 applications 共用 21 點白名單位置
    local function createTextPlacementDropdown(parent, labelText, kind, x, y)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        label:SetTextColor(0.85, 0.75, 0.65, 1)
        setWidgetText(label, labelText)

        local btn = api.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        if Theme and Theme.registerButton then Theme.registerButton(btn) end
        btn:SetSize(130, 20)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 14)
        setTooltip(btn, "選擇文字或數字在圖示上的相對錨點位置（正中央、上方、下方、角落等）", labelText)

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
        registerDropdownMenu(menu, btn)
        menu:Hide()

        local options = EAM.UI.TextPlacement.orderedPlacements
        for index = 1, #options do
            local placement = options[index]
            local column = math.floor((index - 1) / 11)
            local row = (index - 1) % 11
            local menuButton = api.CreateFrame("Button", nil, menu)
            menuButton:SetSize(112, 18)
            menuButton:SetPoint("TOPLEFT", menu, "TOPLEFT", 3 + column * 116, -3 - row * 20)

            local menuButtonText = menuButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            menuButtonText:SetPoint("LEFT", menuButton, "LEFT", 5, 0)
            bindText(menuButtonText, "EAM_PLACEMENT_" .. placement, placement)
            finalizeDropdownMenuButton(menuButton, menuButtonText, menu)

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

    createTextPlacementDropdown(posInner, localized("EAM_OPT_TIMER_ALIGN", "秒數倒數位置"), "timer", 300, -198)
    createTextPlacementDropdown(posInner, localized("EAM_OPT_APPLICATIONS_ALIGN", "堆疊層數位置"), "applications", 445, -198)

    -- 全域字型選擇
    local fontLabel = posInner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontLabel:SetPoint("TOPLEFT", posInner, "TOPLEFT", 300, -242)
    fontLabel:SetTextColor(0.85, 0.75, 0.65, 1)
    bindText(fontLabel, "EAM_OPT_FONT_PREFIX", "字型：")

    local fontDropdown = api.CreateFrame("Button", nil, posInner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(fontDropdown) end
    fontDropdown:SetSize(275, 20)
    fontDropdown:SetPoint("TOPLEFT", posInner, "TOPLEFT", 300, -256)
    setTooltip(fontDropdown, "切換所有告警文字與數字所使用的全局字型", "全域字型選擇")
    Options.fontDropdown = fontDropdown

    local fontMenu = api.CreateFrame("Frame", nil, posInner, "BackdropTemplate")
    fontMenu:SetSize(275, 100)
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
    registerDropdownMenu(fontMenu, fontDropdown)
    fontMenu:Hide()
    Options.fontMenu = fontMenu
    Options.fontMenuItems = {}

    local function populateFontMenu()
        buildScrollableDropdownMenu(
            fontMenu,
            fontDropdown,
            function()
                local MediaService = EAM.Services and EAM.Services.MediaService
                if MediaService and MediaService.getMediaList then
                    return MediaService.getMediaList("font", true)
                end
                local fontOptions = EAM.Constants and EAM.Constants.FONT_FAMILY_OPTIONS or {}
                local list = {}
                for _, opt in ipairs(fontOptions) do
                    list[#list + 1] = { value = opt.value, text = (EAM.L and EAM.L[opt.labelKey]) or opt.value }
                end
                return list
            end,
            function(item)
                local saved = EAM.Modules and EAM.Modules.SavedVariables
                if saved and saved.updateFontFamily then
                    local ok, status = saved.updateFontFamily(item.value)
                    if ok and status == "updated" then
                        Options.refreshFontDropdown()
                        Options.notifyTextLayoutChanged(true)
                    elseif ok then
                        Options.refreshFontDropdown()
                    end
                end
            end,
            275,
            10
        )
        for _, btn in ipairs(fontMenu.buttons or {}) do
            finalizeDropdownMenuButton(btn, btn.text, fontMenu)
        end
    end

    fontDropdown:SetScript("OnClick", function()
        if fontMenu:IsShown() then
            fontMenu:Hide()
        else
            populateFontMenu()
            fontMenu:Show()
        end
    end)
    Options.refreshFontDropdown()

    -- 充能技能剩餘次數列
    local chargeBarTitle = posInner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chargeBarTitle:SetPoint("TOPLEFT", posInner, "TOPLEFT", 300, -290)
    bindText(chargeBarTitle, "EAM_CHARGE_BAR_TITLE", "充能技能剩餘次數列")

    local chargeBarOptions = {
        { value = "BOTTOM", labelKey = "EAM_CHARGE_BAR_BOTTOM", fallback = "圖示下方" },
        { value = "TOP", labelKey = "EAM_CHARGE_BAR_TOP", fallback = "圖示上方" },
        { value = "LEFT", labelKey = "EAM_CHARGE_BAR_LEFT", fallback = "圖示左側（直向）" },
        { value = "RIGHT", labelKey = "EAM_CHARGE_BAR_RIGHT", fallback = "圖示右側（直向）" },
        { value = "RING", labelKey = "EAM_CHARGE_BAR_RING", fallback = "環形" },
    }
    Options.chargeBarOptions = chargeBarOptions

    local chargeBarDropdown = api.CreateFrame("Button", nil, posInner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(chargeBarDropdown) end
    chargeBarDropdown:SetSize(275, 22)
    chargeBarDropdown:SetPoint("TOPLEFT", posInner, "TOPLEFT", 300, -310)
    setTooltip(chargeBarDropdown, "選擇技能充能次數條的顯示樣式（圖示下方、上方、左側、右側、環形）", "充能技能剩餘次數列")
    Options.chargeBarDropdown = chargeBarDropdown

    local chargeBarMenu = api.CreateFrame("Frame", nil, posInner, "BackdropTemplate")
    chargeBarMenu:SetSize(275, 112)
    chargeBarMenu:SetPoint("TOPLEFT", chargeBarDropdown, "BOTTOMLEFT", 0, -2)
    chargeBarMenu:SetFrameStrata("DIALOG")
    chargeBarMenu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    chargeBarMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
    chargeBarMenu:SetBackdropBorderColor(0.6, 0.4, 0.2, 1)
    registerDropdownMenu(chargeBarMenu, chargeBarDropdown)
    chargeBarMenu:Hide()
    Options.chargeBarMenu = chargeBarMenu

    for index = 1, #chargeBarOptions do
        local option = chargeBarOptions[index]
        local menuButton = api.CreateFrame("Button", nil, chargeBarMenu)
        menuButton:SetSize(269, 20)
        menuButton:SetPoint("TOPLEFT", chargeBarMenu, "TOPLEFT", 3, -3 - (index - 1) * 21)
        local menuText = menuButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        menuText:SetPoint("LEFT", menuButton, "LEFT", 6, 0)
        bindText(menuText, option.labelKey, option.fallback)
        finalizeDropdownMenuButton(menuButton, menuText, chargeBarMenu)
        menuButton:SetScript("OnClick", function()
            local saved = EAM.Modules and EAM.Modules.SavedVariables
            if saved and saved.updateChargeBarLayout then
                local ok, state = saved.updateChargeBarLayout(option.value)
                if ok then
                    Options.refreshChargeBarDropdown()
                    if state == "updated" then
                        Options.notifyConfigChanged(false)
                    end
                end
            end
            chargeBarMenu:Hide()
        end)
    end
    chargeBarDropdown:SetScript("OnClick", function()
        if chargeBarMenu:IsShown() then
            chargeBarMenu:Hide()
        else
            chargeBarMenu:Show()
        end
    end)
    Options.refreshChargeBarDropdown()

    createSlider(
        posInner,
        localized("EAM_CHARGE_BAR_LENGTH", "長度／環徑（圖示 %）"),
        "chargeBarLengthPercent",
        100, 250, 5, 300, -345, 275, nil, nil, "調整充能條長度佔圖示寬度的百分比", "充能條長度"
    )
    createSlider(
        posInner,
        localized("EAM_CHARGE_BAR_THICKNESS", "厚度（px）"),
        "chargeBarThickness",
        4, 16, 1, 300, -393, 275, nil, nil, "調整充能條本身的粗細像素高度", "充能條粗細"
    )

    local chargeBarHint = posInner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chargeBarHint:SetPoint("TOPLEFT", posInner, "TOPLEFT", 300, -433)
    chargeBarHint:SetWidth(275)
    chargeBarHint:SetJustifyH("LEFT")
    bindText(
        chargeBarHint,
        "EAM_CHARGE_BAR_HINT",
        "分段代表剩餘可用次數；恢復時間只顯示於冷卻轉圈。"
    )

    createCheckbox(posInner, localized("EAM_OPT_RADIAL_GAUGE", "啟用 12.1 原生圓形光環倒數光圈"), "showRadialGauge", 300, -462, nil, "在光環與冷卻圖示周圍繪製 12.1 原生向量平滑消退光圈與斬殺期高亮", "原生圓形進度光圈")

    -- ---------------------------------------------------
    -- 【底部按鈕】：對稱分欄，重置 7 個框架的所有狀態
    -- ---------------------------------------------------
    createThemedButton(posInner, localized("EAM_OPT_MOVE_FRAME_BTN", "移動提醒框架"), 16, -516, 250, 28, function()
        if EAM.UI.Renderer and EAM.UI.Renderer.toggleAnchors then
            EAM.UI.Renderer.toggleAnchors()
        else
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_MOVE_MODE_ON_PRINT or "移動模式已啟動（請使用 /eam 拖曳）"))
        end
    end, "在畫面上亮起半透明移動錨點框，方便使用滑鼠直觀拖曳調整在畫面上的定位", "移動提醒框架")

    createThemedButton(posInner, localized("EAM_OPT_RESET_FRAME_BTN", "重設所有圖示與位置"), 300, -516, 275, 28, function()
        if EAM.db and EAM.db.layout then
            EAM.db.layout.iconSize = 40
            EAM.db.layout.spacing = 6
            if EAM.db.config then
                EAM.db.config.chargeBarLayout = "BOTTOM"
                EAM.db.config.chargeBarLengthPercent = 150
                EAM.db.config.chargeBarThickness = 8
                Options.refreshChargeBarDropdown()
            end
            
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
            if EAM.UI.Renderer and EAM.UI.Renderer.refreshPreviewLayout then
                EAM.UI.Renderer.refreshPreviewLayout()
            end
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_RESET_FRAME_SUCCESS or "已將所有告警框架位置與成長方向重設為預設配置。"))
        end
    end, "將所有告警模組之框架位置、成長方向、圖示尺寸與間距全部恢復為系統預設值", "重設所有圖示與位置")

    Options.posFrame = posFrame


    -- ===================================================
    -- 3. Spell/Item List Frame (Right Scrolling List)
    -- ===================================================
    local listFrame = api.CreateFrame("Frame", "EAM_SpellListOptionsFrame", frame, "BackdropTemplate")
    listFrame:SetSize(400, 600)
    listFrame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, 0)
    listFrame:EnableMouse(true)
    listFrame:RegisterForDrag("LeftButton")
    listFrame:SetScript("OnDragStart", function() frame:StartMoving() end)
    listFrame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    listFrame:SetScript("OnHide", function()
        if Options.condFrame then Options.condFrame:Hide() end
        if Options.batchFrame then Options.batchFrame:Hide() end
        if EAM.UI.Renderer and EAM.UI.Renderer.setActiveAnchors then
            EAM.UI.Renderer.setActiveAnchors(nil)
        end
    end)
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
    makeTitleCloseButton(listFrame, function() listFrame:Hide() end)

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
    setTooltip(selectAllBtn, "一鍵勾選啟用清單中的所有監控項目", "全部選擇")
    selectAllBtn:SetScript("OnClick", function() batchOperation("select") end)

    local deselectAllBtn = api.CreateFrame("Button", nil, listInner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(deselectAllBtn) end
    deselectAllBtn:SetSize(86, 22)
    deselectAllBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 4, 0)
    bindText(deselectAllBtn, "EAM_OPT_DESELECT_ALL", "全部取消")
    setTooltip(deselectAllBtn, "一鍵取消勾選清單中的所有監控項目", "全部取消")
    deselectAllBtn:SetScript("OnClick", function() batchOperation("deselect") end)

    local defaultsBtn = api.CreateFrame("Button", nil, listInner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(defaultsBtn) end
    defaultsBtn:SetSize(86, 22)
    defaultsBtn:SetPoint("LEFT", deselectAllBtn, "RIGHT", 4, 0)
    bindText(defaultsBtn, "EAM_OPT_DEFAULTS_BTN", "預設值")
    setTooltip(defaultsBtn, "自動載入當前職業之推薦常用法術監控清單", "載入預設值")
    defaultsBtn:SetScript("OnClick", function()
        if Options.currentCategory == 2 then
            print("|cff00ff96EAM|r " .. (
                EAM.L.EAM_OPT_DEFAULTS_CROSS_EMPTY
                    or "跨職業增減益不自動灌入目前職業法術；請用批次輸入加入已確認的 SpellID。"
            ))
            return
        end

        local classToken = select(2, UnitClass("player"))
        local classData = EAM.Data.SpellArray and EAM.Data.SpellArray[classToken]
        if not classData then
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_DEFAULTS_FAIL or "未找到當前職業的預設法術配置。"))
            return
        end

        local changed = false
        local accepted = 0
        local function loadDefaultList(sourceList)
            if not sourceList then return end
            for index = 1, #sourceList do
                local spell = sourceList[index]
                local matches = (Options.currentCategory == 1 and spell.type == "aura" and spell.unit == "player")
                    or (Options.currentCategory == 3 and spell.type == "aura" and spell.unit == "target")
                    or (Options.currentCategory == 4 and spell.type == "spellCooldown")
                if matches then
                    local ok, _, status = addAlertToCategory(Options.currentCategory, spell.id, true)
                    if ok then
                        accepted = accepted + 1
                        if status == "added" or status == "updated" then
                            changed = true
                        end
                    end
                end
            end
        end

        loadDefaultList(classData.general)
        for index = 1, 4 do
            loadDefaultList(classData[index])
        end

        local saved = EAM.Modules and EAM.Modules.SavedVariables
        local kind = getCategoryAlertKind(Options.currentCategory)
        if saved and saved.commitAlertBatch and kind then
            saved.commitAlertBatch(kind, changed)
        end
        if changed then
            Options.notifyConfigChanged()
        end
        Options.refreshList()
        if accepted > 0 then
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_DEFAULTS_SUCCESS or "成功載入目前職業的常用預設法術。"))
        else
            print("|cff00ff96EAM|r " .. (
                EAM.L.EAM_OPT_DEFAULTS_EMPTY_CATEGORY
                    or "這個分類沒有可驗證的職業預設法術。"
            ))
        end
    end)
    local deleteAllBtn = api.CreateFrame("Button", nil, listInner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(deleteAllBtn) end
    deleteAllBtn:SetSize(86, 22)
    deleteAllBtn:SetPoint("LEFT", defaultsBtn, "RIGHT", 4, 0)
    bindText(deleteAllBtn, "EAM_OPT_DELETE_ALL", "全部刪除")
    setTooltip(deleteAllBtn, "清空當前分類下的所有法術與物品監控項目", "全部刪除")
    deleteAllBtn:SetScript("OnClick", function() batchOperation("delete") end)

    -- 專精篩選下拉選單按鈕
    local specDropdown = api.CreateFrame("Button", nil, listInner, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(specDropdown) end
    specDropdown:SetSize(160, 22)
    specDropdown:SetPoint("TOPLEFT", listInner, "TOPLEFT", 8, -36)
    setTooltip(specDropdown, "依當前職業天賦專精過濾顯示專屬推薦技能清單", "天賦專精過濾")
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
    registerDropdownMenu(specMenu, specDropdown)
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

            local btnText = menuBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btnText:SetPoint("LEFT", menuBtn, "LEFT", 6, 0)
            btnText:SetText(item.name)
            finalizeDropdownMenuButton(menuBtn, btnText, specMenu)

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
            itemFrame.delBtn:SetPoint("RIGHT", itemFrame, "RIGHT", -6, 0)
            setTooltip(itemFrame.delBtn, "從監控清單中移除此法術/物品", "刪除監控")
            
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
            itemFrame.gearBtn:SetSize(16, 16)
            itemFrame.gearBtn:SetPoint("RIGHT", itemFrame.delBtn, "LEFT", -4, 0)
            itemFrame.gearBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
            setTooltip(itemFrame.gearBtn, "開啟此法術之進階條件（倒數、堆疊、自訂替代圖示、音效警示、冷卻覆寫等）", "條件設定")
            local gTex = itemFrame.gearBtn:GetNormalTexture()
            if gTex then
                gTex:SetVertexColor(1, 1, 1, 0.95)
            end

            -- Down Button (▼)
            itemFrame.downBtn = api.CreateFrame("Button", nil, itemFrame)
            itemFrame.downBtn:SetSize(16, 16)
            itemFrame.downBtn:SetPoint("RIGHT", itemFrame.gearBtn, "LEFT", -4, 0)
            local downText = itemFrame.downBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            downText:SetPoint("CENTER", itemFrame.downBtn, "CENTER", 0, 0)
            downText:SetText("▼")
            downText:SetTextColor(0.7, 0.8, 0.9, 1.0)
            itemFrame.downBtn.text = downText
            setTooltip(itemFrame.downBtn, EAM.L.EAM_OPT_MOVE_DOWN or "下移順位", "下移")
            itemFrame.downBtn:SetScript("OnEnter", function(self)
                downText:SetTextColor(1.0, 1.0, 1.0, 1.0)
            end)
            itemFrame.downBtn:SetScript("OnLeave", function(self)
                downText:SetTextColor(0.7, 0.8, 0.9, 1.0)
            end)

            -- Up Button (▲)
            itemFrame.upBtn = api.CreateFrame("Button", nil, itemFrame)
            itemFrame.upBtn:SetSize(16, 16)
            itemFrame.upBtn:SetPoint("RIGHT", itemFrame.downBtn, "LEFT", -4, 0)
            local upText = itemFrame.upBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            upText:SetPoint("CENTER", itemFrame.upBtn, "CENTER", 0, 0)
            upText:SetText("▲")
            upText:SetTextColor(0.7, 0.8, 0.9, 1.0)
            itemFrame.upBtn.text = upText
            setTooltip(itemFrame.upBtn, EAM.L.EAM_OPT_MOVE_UP or "上移順位", "上移")
            itemFrame.upBtn:SetScript("OnEnter", function(self)
                upText:SetTextColor(1.0, 1.0, 1.0, 1.0)
            end)
            itemFrame.upBtn:SetScript("OnLeave", function(self)
                upText:SetTextColor(0.7, 0.8, 0.9, 1.0)
            end)
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
        setTooltip(itemFrame.checkbox, "勾選以啟用此項目在畫面上的告警提示", "啟用/停用")
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

        -- Up / Down click
        itemFrame.upBtn:SetScript("OnClick", function()
            moveAlertInCurrentList(data, -1)
        end)
        itemFrame.downBtn:SetScript("OnClick", function()
            moveAlertInCurrentList(data, 1)
        end)

        -- Drag and drop reordering
        itemFrame:RegisterForDrag("LeftButton")
        itemFrame:SetScript("OnDragStart", function(self)
            Options.draggingAlert = data
        end)
        itemFrame:SetScript("OnReceiveDrag", function(self)
            if Options.draggingAlert and Options.draggingAlert ~= data then
                swapAlertsInCurrentList(Options.draggingAlert, data)
                Options.draggingAlert = nil
            end
        end)
        itemFrame:SetScript("OnMouseUp", function(self)
            if Options.draggingAlert and Options.draggingAlert ~= data then
                swapAlertsInCurrentList(Options.draggingAlert, data)
                Options.draggingAlert = nil
            end
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
    setTooltip(addEditBox, "輸入要加入或刪除的法術 ID (Spell ID) 或物品 ID (Item ID)", "輸入法術/物品 ID")
    Options.addEditBox = addEditBox

    local addBtn = createThemedButton(listInner, localized("EAM_OPT_ADD_BTN", "新增"), 158, 0, 60, 24, function()
        local idVal = tonumber(addEditBox:GetText())
        if not idVal or idVal <= 0 then
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_ERR_INVALID_ID or "請輸入正確的 ID！"))
            return
        end
        Options.addAlertToCurrentCategory(idVal)
        addEditBox:SetText("")
    end, "將輸入框中的 ID 加入當前分類之監控清單", "新增監控")
    addBtn:ClearAllPoints()
    addBtn:SetPoint("BOTTOMLEFT", listInner, "BOTTOMLEFT", 158, 38)

    local delBtn = createThemedButton(listInner, localized("EAM_OPT_DEL_BTN", "刪除"), 224, 0, 60, 24, function()
        local idVal = tonumber(addEditBox:GetText())
        if not idVal or idVal <= 0 then
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_ERR_INVALID_ID or "請輸入正確的 ID！"))
            return
        end
        Options.removeAlertFromCurrentCategory(idVal)
        addEditBox:SetText("")
    end, "將輸入框中的 ID 從當前分類中移除", "刪除監控")
    delBtn:ClearAllPoints()
    delBtn:SetPoint("BOTTOMLEFT", listInner, "BOTTOMLEFT", 224, 38)

    local batchBtn = createThemedButton(listInner, localized("EAM_OPT_BATCH_OPEN", "批次輸入"), 290, 0, 72, 24, function()
        if Options.openBatchFrame then
            Options.openBatchFrame()
        end
    end, "開啟多行文字方塊，一次匯入、備份或管理多個法術 ID", "批次輸入")
    batchBtn:ClearAllPoints()
    batchBtn:SetPoint("BOTTOMLEFT", listInner, "BOTTOMLEFT", 290, 38)

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

    local batchFrame = api.CreateFrame("Frame", "EAM_AlertBatchFrame", UIParent, "BackdropTemplate")
    batchFrame:SetSize(620, 460)
    batchFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    batchFrame:SetFrameStrata("DIALOG")
    batchFrame:SetMovable(true)
    batchFrame:EnableMouse(true)
    batchFrame:RegisterForDrag("LeftButton")
    batchFrame:SetScript("OnDragStart", function()
        if frame and frame:IsShown() then
            frame:StartMoving()
        else
            batchFrame:StartMoving()
        end
    end)
    batchFrame:SetScript("OnDragStop", function()
        if frame and frame:IsShown() then
            frame:StopMovingOrSizing()
        else
            batchFrame:StopMovingOrSizing()
        end
    end)
    batchFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    batchFrame:SetBackdropColor(0.08, 0.06, 0.05, 0.98)
    batchFrame:SetBackdropBorderColor(0.8, 0.6, 0.4, 1)
    if Theme and Theme.registerFrame then Theme.registerFrame(batchFrame, "window") end
    makeTitleCloseButton(batchFrame, function()
        batchFrame:Hide()
    end)

    local batchTitle = batchFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    batchTitle:SetPoint("TOP", batchFrame, "TOP", 0, -16)
    bindText(batchTitle, "EAM_OPT_BATCH_TITLE", "EAM 批次法術／物品 ID")
    if Theme and Theme.registerText then Theme.registerText(batchTitle, "title") end

    local batchDescription = batchFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    batchDescription:SetPoint("TOPLEFT", batchFrame, "TOPLEFT", 18, -42)
    batchDescription:SetPoint("TOPRIGHT", batchFrame, "TOPRIGHT", -18, -42)
    batchDescription:SetJustifyH("LEFT")
    bindText(
        batchDescription,
        "EAM_OPT_BATCH_DESC",
        "每行或以分號分隔一個 ID；先載入目前清單以複製，或貼上後一鍵加入目前分類。"
    )
    if Theme and Theme.registerText then Theme.registerText(batchDescription, "body") end

    local batchScrollFrame = api.CreateFrame(
        "ScrollFrame",
        "EAM_AlertBatchScrollFrame",
        batchFrame,
        "UIPanelScrollFrameTemplate"
    )
    batchScrollFrame:SetPoint("TOPLEFT", batchFrame, "TOPLEFT", 18, -70)
    batchScrollFrame:SetPoint("BOTTOMRIGHT", batchFrame, "BOTTOMRIGHT", -40, 104)
    batchScrollFrame:EnableMouseWheel(true)
    local batchScrollBar = batchScrollFrame.ScrollBar or _G.EAM_AlertBatchScrollFrameScrollBar
    if batchScrollBar then
        batchScrollBar.scrollStep = 39
    end

    local batchEditBox = api.CreateFrame("EditBox", nil, batchScrollFrame)
    batchEditBox:SetMultiLine(true)
    batchEditBox:SetMaxLetters(65535)
    batchEditBox:SetAutoFocus(false)
    batchEditBox:SetFontObject("ChatFontNormal")
    batchEditBox:SetPoint("TOPLEFT", batchScrollFrame, "TOPLEFT", 0, 0)
    batchEditBox:SetWidth(554)
    batchEditBox:SetHeight(1)
    batchScrollFrame:SetScrollChild(batchEditBox)
    batchEditBox:SetScript("OnTextChanged", function(self)
        local fontString = type(self.GetFontString) == "function" and self:GetFontString() or nil
        local textHeight = fontString and type(fontString.GetStringHeight) == "function"
            and fontString:GetStringHeight()
            or 1
        local viewportHeight = type(batchScrollFrame.GetHeight) == "function"
            and batchScrollFrame:GetHeight()
            or 1
        self:SetHeight(math.max(viewportHeight, textHeight + 12))
        batchScrollFrame:UpdateScrollChildRect()
    end)
    batchEditBox:SetScript("OnCursorChanged", function(_, _, y, _, height)
        if type(y) ~= "number" or type(height) ~= "number" then return end
        local current = batchScrollFrame:GetVerticalScroll() or 0
        local viewportHeight = batchScrollFrame:GetHeight() or 0
        local cursorTop = -y
        local cursorBottom = cursorTop + height
        local target = current
        if cursorTop < current then
            target = cursorTop
        elseif cursorBottom > current + viewportHeight then
            target = cursorBottom - viewportHeight
        end
        local maximum = batchScrollFrame:GetVerticalScrollRange() or 0
        target = math.max(0, math.min(maximum, target))
        if target ~= current then
            batchScrollFrame:SetVerticalScroll(target)
        end
    end)
    batchEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        batchFrame:Hide()
    end)

    local batchStatusText = batchFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    batchStatusText:SetPoint("BOTTOMLEFT", batchFrame, "BOTTOMLEFT", 18, 72)
    batchStatusText:SetPoint("BOTTOMRIGHT", batchFrame, "BOTTOMRIGHT", -18, 72)
    batchStatusText:SetJustifyH("LEFT")
    if Theme and Theme.registerText then Theme.registerText(batchStatusText, "body") end

    local function setBatchStatus(key, fallback, ...)
        local formatValue = (EAM.L and EAM.L[key]) or fallback
        batchStatusText:SetText(string.format(formatValue, ...))
    end

    local function loadBatchCurrent()
        local category = Options.batchCategory or Options.currentCategory
        batchEditBox:SetText(Options.buildCurrentCategoryIDText(category))
        batchScrollFrame:SetVerticalScroll(0)
        setBatchStatus("EAM_OPT_BATCH_LOADED", "已載入目前清單，可按全選複製。")
    end

    local function makeBatchButton(key, fallback, width, point, handler, tooltipText, tooltipTitle)
        local button = api.CreateFrame("Button", nil, batchFrame, "UIPanelButtonTemplate")
        button:SetSize(width, 26)
        button:SetPoint(unpack(point))
        bindText(button, key, fallback)
        button:SetScript("OnClick", handler)
        if tooltipText then
            setTooltip(button, tooltipText, tooltipTitle or fallback)
        end
        if Theme and Theme.registerButton then Theme.registerButton(button) end
        return button
    end

    makeBatchButton(
        "EAM_OPT_BATCH_LOAD",
        "載入目前清單",
        108,
        { "BOTTOMLEFT", batchFrame, "BOTTOMLEFT", 18, 24 },
        loadBatchCurrent,
        "讀取當前分類已啟用的所有法術 ID 至多行文字框中",
        "載入目前清單"
    )
    makeBatchButton(
        "EAM_OPT_BATCH_SELECT",
        "全選複製",
        90,
        { "LEFT", batchFrame, "BOTTOMLEFT", 132, 24 },
        function()
            local ok = EAM.Util and EAM.Util.prepareEditBoxManualCopy
                and EAM.Util.prepareEditBoxManualCopy(batchEditBox)
            if not ok then
                setBatchStatus("EAM_OPT_BATCH_COPY_FAILED", "無法自動選取，請按 Ctrl+A、Ctrl+C。")
            end
        end,
        "全選輸入框中的所有文字以便按 Ctrl+C 複製分享",
        "全選複製"
    )
    makeBatchButton(
        "EAM_OPT_BATCH_ADD",
        "一鍵加入",
        90,
        { "LEFT", batchFrame, "BOTTOMLEFT", 228, 24 },
        function()
            local ok, report = Options.applyBatchIDs(
                Options.batchCategory or Options.currentCategory,
                batchEditBox:GetText()
            )
            if not ok then
                setBatchStatus("EAM_OPT_BATCH_EMPTY", "沒有可加入的有效 ID。")
                return
            end
            setBatchStatus(
                "EAM_OPT_BATCH_RESULT",
                "完成：新增 %d、更新 %d、未變更 %d、無效 %d、移至跨職業 %d。",
                report.added,
                report.updated,
                report.unchanged,
                report.invalid,
                report.reclassified
            )
        end,
        "解析並將輸入框中的所有 ID 批次新增至當前分類",
        "一鍵加入"
    )
    makeBatchButton(
        "EAM_OPT_BATCH_CLEAR",
        "清空",
        70,
        { "LEFT", batchFrame, "BOTTOMLEFT", 324, 24 },
        function()
            batchEditBox:SetText("")
            batchStatusText:SetText("")
        end,
        "清空多行輸入框中的所有文字",
        "清空"
    )
    makeBatchButton(
        "EAM_OPT_BATCH_CLOSE",
        "關閉",
        70,
        { "BOTTOMRIGHT", batchFrame, "BOTTOMRIGHT", -18, 24 },
        function()
            batchEditBox:ClearFocus()
            batchFrame:Hide()
        end,
        "關閉批次輸入視窗",
        "關閉"
    )

    function Options.openBatchFrame()
        if api.InCombatLockdown and api.InCombatLockdown() then
            print("|cff00ff96EAM|r " .. (
                EAM.L.EAM_OPT_BATCH_COMBAT
                    or "戰鬥中不開啟批次輸入視窗。"
            ))
            return false, "combatBlocked"
        end
        Options.batchCategory = Options.currentCategory
        loadBatchCurrent()
        if listFrame and listFrame:IsShown() then
            batchFrame:ClearAllPoints()
            batchFrame:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", 2, 0)
        else
            batchFrame:ClearAllPoints()
            batchFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        end
        batchFrame:Show()
        batchFrame:Raise()
        return true
    end

    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = "EAM_AlertBatchFrame"
    end
    batchFrame:Hide()
    Options.batchFrame = batchFrame
    Options.batchScrollFrame = batchScrollFrame
    Options.batchEditBox = batchEditBox
    Options.batchStatusText = batchStatusText
    Options.listFrame = listFrame


    -- ===================================================
    -- 4. Spell Conditions Frame (Popup Sub-Window)
    -- ===================================================
    local condFrame = api.CreateFrame("Frame", "EAM_SpellConditionsFrame", UIParent, "BackdropTemplate")
    condFrame:SetSize(360, 660)
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
    condFrame:SetScript("OnDragStart", function()
        if frame and frame:IsShown() then
            frame:StartMoving()
        else
            condFrame:StartMoving()
        end
    end)
    condFrame:SetScript("OnDragStop", function()
        if frame and frame:IsShown() then
            frame:StopMovingOrSizing()
        else
            condFrame:StopMovingOrSizing()
        end
    end)
    makeTitleCloseButton(condFrame, function()
        if condFrame.groupMenu then condFrame.groupMenu:Hide() end
        if condFrame.auraSoundMenu then condFrame.auraSoundMenu:Hide() end
        condFrame:Hide()
    end)

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

    -- 所屬群組多選下拉選單 (Group Multi-select Dropdown)
    local groupSelectLabel = condFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    groupSelectLabel:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -70)
    bindText(groupSelectLabel, "EAM_GROUP_ASSIGN_LABEL", "所屬群組 (可複選):")
    condFrame.groupSelectLabel = groupSelectLabel

    local groupDropdown = api.CreateFrame("Button", nil, condFrame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(groupDropdown) end
    groupDropdown:SetSize(315, 22)
    groupDropdown:SetPoint("TOPLEFT", groupSelectLabel, "BOTTOMLEFT", 0, -3)
    setTooltip(groupDropdown, "點擊展開選單，為此技能複選歸屬戰術群組或自訂群組", "所屬群組")
    condFrame.groupDropdown = groupDropdown

    local groupMenu = api.CreateFrame("Frame", "EAM_CondGroupDropdownMenu", condFrame, "BackdropTemplate")
    groupMenu:SetPoint("TOPLEFT", groupDropdown, "BOTTOMLEFT", 0, -2)
    groupMenu:SetSize(315, 160)
    groupMenu:SetFrameStrata("TOOLTIP")
    groupMenu:SetClampedToScreen(true)
    groupMenu:Hide()
    if Theme and Theme.applyContainerBackground then
        Theme.applyContainerBackground(groupMenu, true)
    else
        groupMenu:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 12, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        groupMenu:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
        groupMenu:SetBackdropBorderColor(0.6, 0.4, 0.2, 1)
    end
    registerDropdownMenu(groupMenu, groupDropdown)
    condFrame.groupMenu = groupMenu

    local function updateGroupDropdownText(alertData)
        if not alertData or not groupDropdown then return end
        local GroupService = EAM.Services and EAM.Services.GroupService
        local groups = GroupService and GroupService.getGroups and GroupService.getGroups() or {}
        local selectedNames = {}
        if type(alertData.groups) == "table" and #alertData.groups > 0 then
            for _, g in ipairs(groups) do
                for _, gid in ipairs(alertData.groups) do
                    if gid == g.id then
                        local gName = g.nameKey and EAM.L and EAM.L[g.nameKey] or g.name or g.id
                        selectedNames[#selectedNames + 1] = tostring(gName)
                        break
                    end
                end
            end
        end
        local noneText = (EAM.L and EAM.L.EAM_GROUP_NONE) or "(未指定群組)"
        local selectedFmt = (EAM.L and EAM.L.EAM_GROUP_SELECTED_COUNT) or "已選 %d 個群組"
        if #selectedNames == 0 then
            groupDropdown:SetText(tostring(noneText))
        elseif #selectedNames <= 2 then
            groupDropdown:SetText(table.concat(selectedNames, ", "))
        else
            groupDropdown:SetText(string.format(selectedFmt, #selectedNames))
        end
    end
    condFrame.updateGroupDropdownText = updateGroupDropdownText

    local function populateGroupMenu(alertData)
        if not alertData then return end
        local GroupService = EAM.Services and EAM.Services.GroupService
        local groups = GroupService and GroupService.getGroups and GroupService.getGroups() or {}
        
        local menuWidth = 315
        local itemHeight = 22
        local maxVisible = 7
        local visibleCount = math.min(#groups, maxVisible)
        groupMenu:SetSize(menuWidth, math.max(30, visibleCount * itemHeight + 8))

        local buttons = groupMenu.buttons or {}
        groupMenu.buttons = buttons

        for i = 1, #buttons do
            buttons[i]:Hide()
        end

        for idx, g in ipairs(groups) do
            local btn = buttons[idx]
            if not btn then
                btn = api.CreateFrame("Button", nil, groupMenu)
                btn:SetSize(menuWidth - 10, itemHeight)
                
                local icon = btn:CreateTexture(nil, "ARTWORK")
                icon:SetSize(16, 16)
                icon:SetPoint("LEFT", btn, "LEFT", 6, 0)
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                btn.icon = icon

                local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
                text:SetPoint("RIGHT", btn, "RIGHT", -30, 0)
                text:SetJustifyH("LEFT")
                btn.text = text

                local cb = api.CreateFrame("CheckButton", nil, btn, "UICheckButtonTemplate")
                cb:SetSize(18, 18)
                cb:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
                btn.cb = cb

                finalizeDropdownMenuButton(btn, text, groupMenu)
                buttons[idx] = btn
            end

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", groupMenu, "TOPLEFT", 5, -4 - (idx - 1) * itemHeight)
            btn.icon:SetTexture(g.icon or 134400)
            local gName = g.nameKey and EAM.L and EAM.L[g.nameKey] or g.name or g.id
            btn.text:SetText(gName)

            local isSelected = false
            if type(alertData.groups) == "table" then
                for _, gid in ipairs(alertData.groups) do
                    if gid == g.id then
                        isSelected = true
                        break
                    end
                end
            end
            btn.cb:SetChecked(isSelected)

            local function toggle()
                if GroupService and GroupService.toggleSpellGroup then
                    GroupService.toggleSpellGroup(alertData, g.id)
                end
                populateGroupMenu(alertData)
                updateGroupDropdownText(alertData)
            end

            btn:SetScript("OnClick", toggle)
            btn.cb:SetScript("OnClick", toggle)
            btn:Show()
        end
    end

    groupDropdown:SetScript("OnClick", function()
        if groupMenu:IsShown() then
            groupMenu:Hide()
        else
            if condFrame.auraSoundMenu then condFrame.auraSoundMenu:Hide() end
            populateGroupMenu(Options.currentEditingAlert)
            groupMenu:Show()
        end
    end)

    -- Sliders (左側排版，Label 偏上 5px 防重疊)
    local stackSlider = api.CreateFrame("Slider", nil, condFrame, "OptionsSliderTemplate")
    stackSlider:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -135)
    stackSlider:SetMinMaxValues(0, 10)
    stackSlider:SetValueStep(1)
    stackSlider:SetObeyStepOnDrag(true)
    stackSlider:SetSize(130, 16)
    setTooltip(stackSlider, "當光環堆疊層數達到或超過此數值時才顯示提醒（0 表示無限制）", "堆疊層數閾值")
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
    glowSlider:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -190)
    glowSlider:SetMinMaxValues(0, 10)
    glowSlider:SetValueStep(1)
    glowSlider:SetObeyStepOnDrag(true)
    glowSlider:SetSize(130, 16)
    setTooltip(glowSlider, "當光環堆疊層數達到此數值時觸發外框高亮流光動畫", "堆疊高亮閾值")
    local glowLabel = glowSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    glowLabel:SetPoint("BOTTOMLEFT", glowSlider, "TOPLEFT", 0, 5)
    bindText(glowLabel, "EAM_OPT_COND_GLOW", "堆疊高亮閾值")
    local glowVal = glowSlider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    glowVal:SetPoint("BOTTOMRIGHT", glowSlider, "TOPRIGHT", 0, 5)
    glowSlider:SetScript("OnValueChanged", function(self, val)
        stackVal:SetText(mathFloor(val))
    end)
    condFrame.glowSlider = glowSlider

    local redLimitSlider = api.CreateFrame("Slider", nil, condFrame, "OptionsSliderTemplate")
    redLimitSlider:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -245)
    redLimitSlider:SetMinMaxValues(0, 10)
    redLimitSlider:SetValueStep(1)
    redLimitSlider:SetObeyStepOnDrag(true)
    redLimitSlider:SetSize(130, 16)
    setTooltip(redLimitSlider, "剩餘秒數低於此數值時倒數數字變為紅色警戒顯示", "倒數紅字限制")
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
    prioritySlider:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -300)
    prioritySlider:SetMinMaxValues(1, 20)
    prioritySlider:SetValueStep(1)
    prioritySlider:SetObeyStepOnDrag(true)
    prioritySlider:SetSize(130, 16)
    setTooltip(prioritySlider, "決定多個告警圖示並存時的排序優先權重（數值越大越靠前）", "排序優先級")
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
    fromPlayerCb:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 175, -131)
    fromPlayerCb.text = fromPlayerCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fromPlayerCb.text:SetPoint("LEFT", fromPlayerCb, "RIGHT", 4, 1)
    bindText(fromPlayerCb.text, "EAM_OPT_COND_PLAYER_ONLY", "僅監控自己施放")
    setTooltip(fromPlayerCb, "勾選時僅監控由玩家自己施放的光環，忽略其他玩家施放的相同技能", "僅監控自己施放")
    condFrame.fromPlayerCb = fromPlayerCb

    condFrame.cooldownBehaviorButtons = {}
    for index = 1, #COOLDOWN_BEHAVIOR_OPTIONS do
        local definition = COOLDOWN_BEHAVIOR_OPTIONS[index]
        local button = createThemedButton(
            condFrame,
            "",
            175,
            -131 - (index - 1) * 34,
            160,
            26,
            function(self)
                if self.eamValue == nil then
                    self.eamValue = true
                elseif self.eamValue == true then
                    self.eamValue = false
                else
                    self.eamValue = nil
                end
                Options.refreshCooldownBehaviorControls()
            end,
            "自訂此技能之冷卻狀態判斷行為（預設/強制啟用/強制停用）",
            "冷卻行為覆寫"
        )
        button.eamBehaviorField = definition.field
        button.eamValue = nil
        condFrame.cooldownBehaviorButtons[definition.field] = button
    end

    local valTitle = condFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valTitle:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 175, -170)
    valTitle:SetTextColor(0.95, 0.85, 0.4, 1.0)
    bindText(valTitle, "EAM_OPT_COND_VAL_TITLE", "顯示光環細部數值:")
    condFrame.valTitle = valTitle

    local val1Cb = api.CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
    val1Cb:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 175, -195)
    val1Cb.text = val1Cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val1Cb.text:SetPoint("LEFT", val1Cb, "RIGHT", 4, 1)
    bindText(val1Cb.text, "EAM_OPT_COND_VAL1", "顯示數值 1 (Value 1)")
    setTooltip(val1Cb, "在圖示旁顯示暴雪光環數據中的第 1 個附加數值（如護盾吸收量）", "顯示數值 1")
    condFrame.val1Cb = val1Cb

    local val2Cb = api.CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
    val2Cb:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 175, -225)
    val2Cb.text = val2Cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val2Cb.text:SetPoint("LEFT", val2Cb, "RIGHT", 4, 1)
    bindText(val2Cb.text, "EAM_OPT_COND_VAL2", "顯示數值 2 (Value 2)")
    setTooltip(val2Cb, "在圖示旁顯示暴雪光環數據中的第 2 個附加數值", "顯示數值 2")
    condFrame.val2Cb = val2Cb

    local val3Cb = api.CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
    val3Cb:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 175, -255)
    val3Cb.text = val3Cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val3Cb.text:SetPoint("LEFT", val3Cb, "RIGHT", 4, 1)
    bindText(val3Cb.text, "EAM_OPT_COND_VAL3", "顯示數值 3 (Value 3)")
    setTooltip(val3Cb, "在圖示旁顯示暴雪光環數據中的第 3 個附加數值", "顯示數值 3")
    condFrame.val3Cb = val3Cb

    local val4Cb = api.CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
    val4Cb:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 175, -285)
    val4Cb.text = val4Cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val4Cb.text:SetPoint("LEFT", val4Cb, "RIGHT", 4, 1)
    bindText(val4Cb.text, "EAM_OPT_COND_VAL4", "顯示數值 4 (Value 4)")
    setTooltip(val4Cb, "在圖示旁顯示暴雪光環數據中的第 4 個附加數值", "顯示數值 4")
    condFrame.val4Cb = val4Cb

    -- 地面技能專屬控制項
    local durationModeCb = api.CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
    durationModeCb:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -135)
    durationModeCb.text = durationModeCb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    durationModeCb.text:SetPoint("LEFT", durationModeCb, "RIGHT", 4, 1)
    bindText(durationModeCb.text, "EAM_OPT_COND_TOOLTIP", "啟用動態 Tooltip 擷取")
    setTooltip(durationModeCb, "自動解析法術說明文字 (Tooltip) 中的秒數作為地面效果持續時間", "動態 Tooltip 擷取")
    condFrame.durationModeCb = durationModeCb

    local manualDurationLabel = condFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    manualDurationLabel:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -175)
    bindText(manualDurationLabel, "EAM_OPT_COND_MANUAL_DUR", "手動設定時間 (秒)")
    condFrame.manualDurationLabel = manualDurationLabel

    local manualDurationEditBox = api.CreateFrame("EditBox", nil, condFrame, "InputBoxTemplate")
    manualDurationEditBox:SetSize(80, 20)
    manualDurationEditBox:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -195)
    manualDurationEditBox:SetAutoFocus(false)
    manualDurationEditBox:SetNumeric(false)
    setTooltip(manualDurationEditBox, "若無法自動解析 Tooltip，可手動在此輸入固定持續秒數", "手動設定時間")
    condFrame.manualDurationEditBox = manualDurationEditBox

    local scrapeBtn = api.CreateFrame("Button", nil, condFrame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(scrapeBtn) end
    scrapeBtn:SetSize(80, 20)
    scrapeBtn:SetPoint("LEFT", manualDurationEditBox, "RIGHT", 10, 0)
    bindText(scrapeBtn, "EAM_OPT_COND_SCRAPE_BTN", "一鍵擷取")
    setTooltip(scrapeBtn, "立即解析當前法術說明文字並填入持續秒數", "一鍵擷取")
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
    auraSoundTitle:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -345)
    bindText(auraSoundTitle, "EAM_OPT_AURA_SOUND_TITLE", "12.1 光環事件音效")
    condFrame.auraSoundTitle = auraSoundTitle

    local auraSoundDropdown = api.CreateFrame("Button", nil, condFrame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(auraSoundDropdown) end
    auraSoundDropdown:SetSize(160, 22)
    auraSoundDropdown:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -365)
    setTooltip(auraSoundDropdown, "選擇此法術專屬觸發時播放的音效", "光環專屬音效")
    condFrame.auraSoundDropdown = auraSoundDropdown

    local auraSoundMenu = api.CreateFrame("Frame", nil, condFrame, "BackdropTemplate")
    auraSoundMenu:SetSize(220, 228)
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
    registerDropdownMenu(auraSoundMenu, auraSoundDropdown)
    auraSoundMenu:Hide()
    condFrame.auraSoundMenu = auraSoundMenu

    local function populateAuraSoundMenu()
        buildScrollableDropdownMenu(
            auraSoundMenu,
            auraSoundDropdown,
            function()
                local MediaService = EAM.Services and EAM.Services.MediaService
                if MediaService and MediaService.getMediaList then
                    return MediaService.getMediaList("sound", true)
                end
                local list = {}
                for _, sName in ipairs(soundNames) do
                    list[#list + 1] = { value = sName, text = sName }
                end
                return list
            end,
            function(item)
                condFrame.auraSoundName = item.value
                auraSoundDropdown:SetText((EAM.L.EAM_OPT_SOUND_PREFIX or "音效: ") .. (item.text or item.value))
                local MediaService = EAM.Services and EAM.Services.MediaService
                if MediaService and MediaService.playSound then
                    MediaService.playSound(item.value)
                end
            end,
            220,
            10
        )
        for _, btn in ipairs(auraSoundMenu.buttons or {}) do
            finalizeDropdownMenuButton(btn, btn.text, auraSoundMenu)
        end
    end

    auraSoundDropdown:SetScript("OnClick", function()
        if not isAuraSoundAvailable() then
            return
        end
        if auraSoundMenu:IsShown() then
            auraSoundMenu:Hide()
        else
            if condFrame.groupMenu then condFrame.groupMenu:Hide() end
            populateAuraSoundMenu()
            auraSoundMenu:Show()
        end
    end)

    local auraSoundTestButton = api.CreateFrame("Button", nil, condFrame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(auraSoundTestButton) end
    auraSoundTestButton:SetSize(80, 22)
    auraSoundTestButton:SetPoint("LEFT", auraSoundDropdown, "RIGHT", 8, 0)
    bindText(auraSoundTestButton, "EAM_OPT_AURA_SOUND_TEST_ASSET_ONLY", "試聽素材")
    setTooltip(auraSoundTestButton, "試聽目前選擇的光環專屬音效", "試聽素材")
    auraSoundTestButton:SetScript("OnClick", function()
        if not isAuraSoundAvailable() then
            return
        end
        local sName = condFrame.auraSoundName or (EAM.db and EAM.db.config and EAM.db.config.soundName) or "ShayBell"
        local MediaService = EAM.Services and EAM.Services.MediaService
        if MediaService and MediaService.playSound then
            MediaService.playSound(sName)
        else
            local asset = soundAssets[sName] or soundAssets.ShayBell
            PlaySoundFile(asset, "Master")
        end
    end)
    condFrame.auraSoundTestButton = auraSoundTestButton

    local function createAuraSoundCheckbox(key, fallback, x, y, tipText)
        local checkbox = api.CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", condFrame, "TOPLEFT", x, y)
        checkbox.text = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 4, 1)
        bindText(checkbox.text, key, fallback)
        if tipText then
            setTooltip(checkbox, tipText, fallback)
        end
        return checkbox
    end

    condFrame.auraSoundAddedCb = createAuraSoundCheckbox(
        "EAM_OPT_AURA_SOUND_ADDED", "光環新增", 20, -395, "獲得此光環時播放音效"
    )
    condFrame.auraSoundApplicationsCb = createAuraSoundCheckbox(
        "EAM_OPT_AURA_SOUND_APPLICATIONS_INCREASED", "層數增加", 175, -395, "光環堆疊層數增加時播放音效"
    )
    condFrame.auraSoundRemovedCb = createAuraSoundCheckbox(
        "EAM_OPT_AURA_SOUND_REMOVED", "光環移除", 20, -425, "光環結束消失時播放音效"
    )

    local auraSoundHint = condFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    auraSoundHint:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -450)
    auraSoundHint:SetWidth(320)
    auraSoundHint:SetJustifyH("LEFT")
    bindText(auraSoundHint, "EAM_OPT_AURA_SOUND_INHERIT", "三項皆未勾選時沿用全域音效；實際觸發需 PTR 真人驗證。")
    condFrame.auraSoundHint = auraSoundHint

    -- 自訂替代圖示 (代碼或材質路徑)
    local customIconLabel = condFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    customIconLabel:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -475)
    bindText(customIconLabel, "EAM_OPT_CUSTOM_ICON_LABEL", "自訂替代圖示 (代碼或材質路徑):")
    condFrame.customIconLabel = customIconLabel

    local customIconEditBox = api.CreateFrame("EditBox", nil, condFrame, "InputBoxTemplate")
    customIconEditBox:SetSize(250, 20)
    customIconEditBox:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 24, -493)
    customIconEditBox:SetAutoFocus(false)
    setTooltip(customIconEditBox, "輸入替代圖示的 FileDataID 數字代碼或材質路徑（留空使用技能預設圖示）", "自訂替代圖示")
    condFrame.customIconEditBox = customIconEditBox

    local customIconPreview = condFrame:CreateTexture(nil, "OVERLAY")
    customIconPreview:SetSize(22, 22)
    customIconPreview:SetPoint("LEFT", customIconEditBox, "RIGHT", 6, 0)
    customIconPreview:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    condFrame.customIconPreview = customIconPreview

    customIconEditBox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText()
        if txt and txt ~= "" then
            local iconTex = tonumber(txt) or txt
            customIconPreview:SetTexture(iconTex)
            customIconPreview:Show()
        else
            customIconPreview:SetTexture(condFrame.icon:GetTexture() or 134400)
        end
    end)

    local customIconHint = condFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    customIconHint:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -518)
    customIconHint:SetText("可在 WoW.tools / Wago Tools 查詢圖示代碼與路徑:")
    condFrame.customIconHint = customIconHint

    local customIconUrl = api.CreateFrame("EditBox", nil, condFrame, "InputBoxTemplate")
    customIconUrl:SetSize(285, 18)
    customIconUrl:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 24, -534)
    customIconUrl:SetAutoFocus(false)
    customIconUrl:SetText("https://wago.tools/icons")
    setTooltip(customIconUrl, "點擊反白複製網址前往 Wago Tools 查詢圖示代碼", "圖示查詢網站")
    customIconUrl:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    condFrame.customIconUrl = customIconUrl

    -- 底部按鈕
    createThemedButton(condFrame, localized("EAM_OPT_COND_SAVE_BTN", "儲存設定 (Save)"), 20, -580, 130, 26, function()
        local d = Options.currentEditingAlert
        if d then
            local customIconText = condFrame.customIconEditBox:GetText()
            if customIconText then
                customIconText = customIconText:gsub("^%s*(.-)%s*$", "%1")
                if customIconText == "" then customIconText = nil end
                if customIconText and tonumber(customIconText) then customIconText = tonumber(customIconText) end
            end
            d.customIcon = customIconText

            if d.kind == "groundEffect" then
                local savedVariables = EAM.Modules.SavedVariables
                if savedVariables and savedVariables.updateGroundEffectAlert then
                    savedVariables.updateGroundEffectAlert(
                        d.spellID,
                        condFrame.durationModeCb:GetChecked() and "AUTO" or "MANUAL",
                        condFrame.manualDurationEditBox:GetText()
                    )
                end
            elseif d.kind == EAM.Constants.ALERT_KIND_SPELL_COOLDOWN then
                local savedVariables = EAM.Modules.SavedVariables
                for index = 1, #COOLDOWN_BEHAVIOR_OPTIONS do
                    local definition = COOLDOWN_BEHAVIOR_OPTIONS[index]
                    local button = condFrame.cooldownBehaviorButtons[definition.field]
                    local value
                    if button then
                        value = button.eamValue
                    end
                    if savedVariables and savedVariables.updateCooldownBehavior then
                        local ok = savedVariables.updateCooldownBehavior(
                            d.spellID,
                            definition.field,
                            value
                        )
                        if ok then
                            d[definition.field] = value
                        end
                    else
                        d[definition.field] = value
                    end
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

            local GroupService = EAM.Services and EAM.Services.GroupService
            if GroupService and GroupService.refreshCache then
                GroupService.refreshCache()
            end
            local savedVariables = EAM.Modules.SavedVariables
            if savedVariables and savedVariables.markRevisionChanged then
                savedVariables.markRevisionChanged()
            end

            local isAura = d.kind == EAM.Constants.ALERT_KIND_AURA
            Options.notifyConfigChanged(not isAura)
            if d.kind == "groundEffect" then
                notifyGroundEffectConfigChanged()
            end
            if condFrame.groupMenu then condFrame.groupMenu:Hide() end
            condFrame.auraSoundMenu:Hide()
            condFrame:Hide()
            Options.refreshList()
            print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_COND_SAVE_SUCCESS or "條件已儲存。"))
        end
    end, "儲存並套用當前法術的所有進階條件與替代圖示設定", "儲存設定")

    local cancelBtn = api.CreateFrame("Button", nil, condFrame, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(cancelBtn) end
    cancelBtn:SetSize(130, 26)
    cancelBtn:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 190, -580)
    bindText(cancelBtn, "EAM_OPT_COND_CANCEL_BTN", "取消關閉 (Cancel)")
    setTooltip(cancelBtn, "放棄變更並關閉條件設定視窗", "取消關閉")
    cancelBtn:SetScript("OnClick", function()
        if condFrame.groupMenu then condFrame.groupMenu:Hide() end
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

    -- 判斷是否為地面技能效果、技能冷卻或物品冷卻。
    local isGround = (data.kind == "groundEffect")
    local isSpellCooldown = data.kind == EAM.Constants.ALERT_KIND_SPELL_COOLDOWN
    local isCooldown = isSpellCooldown or data.kind == EAM.Constants.ALERT_KIND_ITEM_COOLDOWN
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
    if cf.groupMenu then cf.groupMenu:Hide() end
    if cf.updateGroupDropdownText then cf.updateGroupDropdownText(data) end

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
        for index = 1, #COOLDOWN_BEHAVIOR_OPTIONS do
            local definition = COOLDOWN_BEHAVIOR_OPTIONS[index]
            cf.cooldownBehaviorButtons[definition.field]:Hide()
        end
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
        if isAura then
            cf.fromPlayerCb:Show()
        else
            cf.fromPlayerCb:Hide()
        end

        for index = 1, #COOLDOWN_BEHAVIOR_OPTIONS do
            local definition = COOLDOWN_BEHAVIOR_OPTIONS[index]
            local button = cf.cooldownBehaviorButtons[definition.field]
            if isSpellCooldown then
                button.eamValue = data[definition.field]
                button:Show()
            else
                button.eamValue = nil
                button:Hide()
            end
        end
        Options.refreshCooldownBehaviorControls()

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
        -- isCooldown 已於上方依資料種類判定。
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

    if cf.customIconEditBox then
        cf.customIconEditBox:SetText(data.customIcon and tostring(data.customIcon) or "")
        local previewTex = data.customIcon and (tonumber(data.customIcon) or data.customIcon) or (texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        cf.customIconPreview:SetTexture(previewTex)
    end

    if Options.listFrame and Options.listFrame:IsShown() then
        cf:ClearAllPoints()
        cf:SetPoint("TOPLEFT", Options.listFrame, "TOPRIGHT", 2, 0)
    else
        cf:ClearAllPoints()
        cf:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    cf:Show()
    cf:Raise()
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

-- 將主視窗重置回螢幕正中央
function Options.resetPosition()
    if api.InCombatLockdown and api.InCombatLockdown() then
        print("|cff00ff96EAM|r " .. (EAM.L.EAM_OPT_COMBAT_WARNING or "少年欸！戰鬥中暫不開啟設定視窗，脫離戰鬥後會自動為你開啟。"))
        return
    end

    local frame = createFrame()
    if not frame then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetClampedToScreen(true)
    frame:Show()
    frame:Raise()

    if Options.posFrame then Options.posFrame:Hide() end
    if Options.listFrame then Options.listFrame:Hide() end
    Options.closeAllSidePanels()
    Options.refreshLocalizedText()

    print("|cff00ff96EAM|r " .. (EAM.L.EAM_SLASH_RESET_POS_SUCCESS or "已將 EAM 主視窗重置回螢幕中央。"))
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

    -- MiniMap-TrackingBorder 是 53x53 複合材質；內層圖示需依 Blizzard/LibDBIcon 幾何偏移，不能與按鈕置中。
    local background = btn:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -5)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -6)
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    Options.applyMinimapTexture(icon)
    btn.icon = icon

    -- 邊框
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    btn.border = border

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
            if IsShiftKeyDown() then
                Options.resetPosition()
            else
                Options.open()
            end
        elseif button == "RightButton" then
            if IsShiftKeyDown() then
                Options.resetPosition()
            else
                if EAM.Debug.PromptExport and EAM.Debug.PromptExport.openWindow then
                    EAM.Debug.PromptExport.openWindow()
                end
            end
        elseif button == "MiddleButton" then
            Options.resetPosition()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("EventAlertMod", 0.95, 0.85, 0.4)
        GameTooltip:AddLine(EAM.L.EAM_OPT_MINIMAP_LCLICK or "左鍵點擊: 開啟/關閉設定面板", 1, 1, 1)
        GameTooltip:AddLine(EAM.L.EAM_OPT_MINIMAP_RCLICK or "右鍵點擊: 開啟系統除錯診斷", 1, 1, 1)
        GameTooltip:AddLine(EAM.L.EAM_OPT_MINIMAP_MCLICK or "中鍵 / Shift+點擊: 重置主視窗至螢幕中央", 0.2, 1, 0.2)
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
