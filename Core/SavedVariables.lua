--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Core/SavedVariables
檔案: Core\SavedVariables.lua

理念:
- 用版本化 schema 接管舊 EAM SavedVariables，讓重寫可穩定 migration。
- SavedVariables 只保存設定，不保存 runtime facts。

責任:
- 初始化 EAM_DB、保存 defaults、執行舊 EA_* migration、提供語系與 alert add/remove mutation API。

資料所有權:
- 擁有 EAM_DB schema 與 persistent config 的唯一寫入入口。

可變狀態:
- 只在載入、migration、語系或其他使用者設定變更時寫入；語系變更不在此模組觸發 ReloadUI。
- 不得 freeze EAM_DB 或舊 EA_* tables。

邊界:
- 不讀 aura/cooldown API。
- 不寫入每 frame 或事件 hot path 狀態。

效能注意:
- migration 應一次性執行；大量修正需分批且避免戰鬥中處理。
- add/remove 是使用者觸發路徑，不進事件 hot path。

Retail API 注意:
- 保留舊 EA_* SavedVariables 名稱在 TOC，供 Retail-only migration 使用。

]]
local _, EAM = ...

local mathFloor = math.floor

local SavedVariables = {
    activeClassToken = nil,
    migrationReport = {
        imported = 0,
        skipped = 0,
    },
}
EAM.Modules.SavedVariables = SavedVariables

local defaults = {
    schemaVersion = EAM.Constants.SCHEMA_VERSION,
    revision = 0,
    debug = false,
    profiles = {
        classes = {},
    },
    layout = {
        iconSize = 40,
        spacing = 6,
        frames = {
            selfAura = { growDirection = 1, x = 0, y = 120, point = "CENTER" },      -- 1 = RIGHT (向右)
            targetAura = { growDirection = 1, x = 0, y = 200, point = "CENTER" },
            spellCooldown = { growDirection = 1, x = -120, y = 0, point = "CENTER" },
            itemCooldown = { growDirection = 1, x = 120, y = 0, point = "CENTER" },
            classPower = { growDirection = 1, x = 0, y = -80, point = "CENTER" },
            groundEffect = { growDirection = 1, x = 0, y = -160, point = "CENTER" },
            totem = { growDirection = 1, x = 0, y = -240, point = "CENTER" },
        }
    },
    config = {
        language = "auto",
        theme = "eam",
        fontFamily = "STANDARD",
        auraBackend = "AUTO",
        moduleToggles = {
            playerAura = true,
            targetAura = true,
            spellCooldown = true,
            itemCooldown = true,
            groundEffect = true,
            classPower = true,
            totem = true,
            tooltipMonitor = true,
        },
        showFrame = true,
        showSpellName = true,
        showTimeVal = true,
        showChangeInOut = true,
        showFlash = true,
        showSound = true,
        soundName = "ShayBell",
        allowEscCancel = false,
        showExtraAlert = false,
        cooldownRemoveAura = false,
        showSCDOutsideCombat = true,
        glowSCDWhenUsable = true,
        showDKRune = true,
        enableItemCooldown = true,
        enableCDM = false,
        
        -- 滑桿數值
        iconSize = 40,
        iconSpacing = 6,
        verticalSpacing = 0,
        selfDebuffRed = 0.5,
        targetDebuffGreen = 0.5,
        bossExecuteThreshold = 0.2,
        enableBossExecute = false,
        fontSizeSpellName = 12,
        fontSizeTimeVal = 14,
        fontSizeStack = 12,
        textLayout = {
            schema = 1,
            timer = {
                placement = "OUTSIDE_TOP",
                fontSize = 14,
            },
            applications = {
                placement = "INSIDE_BOTTOM_RIGHT",
                fontSize = 12,
            },
        },
        cooldownShadow = true,
        cooldownSwipeAlpha = 1,
        nativeAuraDualCountdownProbe = false,
        
        -- 職業特殊能量 (20種)
        powerHoly = true,
        powerShard = true,
        powerCombo = true,
        powerChi = true,
        powerRage = true,
        powerInsanity = true,
        powerMaelstrom = true,
        powerRunic = true,
        powerAstral = true,
        powerLifebloom = true,
        powerEnergy = true,
        powerFocus = true,
        powerArcane = true,
        powerRunes = true,
        powerFury = true,
        powerFrenzy = true,
        powerMana = true,
        powerPetFocus = true,
        powerPetEnergy = true,
        powerVigor = true,
    }
}

local function copySerializable(value, seen)
    local valueType = type(value)
    if valueType == "nil" or valueType == "boolean" or valueType == "number" or valueType == "string" then
        return value
    end
    if valueType ~= "table" then
        return nil
    end
    seen = seen or {}
    if seen[value] then
        return nil
    end
    seen[value] = true
    local copy = {}
    for key, nestedValue in pairs(value) do
        local keyType = type(key)
        if keyType == "string" or keyType == "number" then
            local copiedValue = copySerializable(nestedValue, seen)
            if copiedValue ~= nil then
                copy[key] = copiedValue
            end
        end
    end
    seen[value] = nil
    return copy
end

local VALID_CLASS_TOKENS = {
    WARRIOR = true,
    PALADIN = true,
    HUNTER = true,
    ROGUE = true,
    PRIEST = true,
    DEATHKNIGHT = true,
    SHAMAN = true,
    MAGE = true,
    WARLOCK = true,
    MONK = true,
    DRUID = true,
    DEMONHUNTER = true,
    EVOKER = true,
}

local function createAlertLists()
    return {
        playerAuras = {},
        targetAuras = {},
        spellCooldowns = {},
        itemCooldowns = {},
        groundEffects = {},
    }
end

local function isValidClassToken(value)
    return type(value) == "string" and VALID_CLASS_TOKENS[value] == true
end

local function getPlayerClassToken()
    local unitClass = EAM.API and EAM.API.UnitClass or UnitClass
    if type(unitClass) ~= "function" then
        return nil
    end
    local ok, _, classToken = pcall(unitClass, "player")
    if ok and isValidClassToken(classToken) then
        return classToken
    end
    return nil
end

local function appendProfileWarning(db, warning)
    db.migrationWarnings = type(db.migrationWarnings) == "table" and db.migrationWarnings or {}
    db.migrationWarnings[#db.migrationWarnings + 1] = warning
end

local function ensureClassProfile(db, classToken)
    if type(db) ~= "table" or not isValidClassToken(classToken) then
        return nil
    end
    db.profiles = type(db.profiles) == "table" and db.profiles or {}
    db.profiles.classes = type(db.profiles.classes) == "table" and db.profiles.classes or {}
    local profile = db.profiles.classes[classToken]
    if type(profile) ~= "table" then
        profile = {
            profileSchema = 1,
            defaultsSeeded = false,
            legacyImportVersion = 0,
            alerts = createAlertLists(),
        }
        db.profiles.classes[classToken] = profile
    end
    profile.profileSchema = 1
    profile.alerts = type(profile.alerts) == "table" and profile.alerts or createAlertLists()
    local alerts = profile.alerts
    alerts.playerAuras = type(alerts.playerAuras) == "table" and alerts.playerAuras or {}
    alerts.targetAuras = type(alerts.targetAuras) == "table" and alerts.targetAuras or {}
    alerts.spellCooldowns = type(alerts.spellCooldowns) == "table" and alerts.spellCooldowns or {}
    alerts.itemCooldowns = type(alerts.itemCooldowns) == "table" and alerts.itemCooldowns or {}
    alerts.groundEffects = type(alerts.groundEffects) == "table" and alerts.groundEffects or {}
    return profile
end

local function getProfileAlerts(db, classToken, create)
    if type(db) ~= "table" then
        return nil
    end
    classToken = classToken or SavedVariables.activeClassToken
    if not isValidClassToken(classToken) then
        return nil
    end
    local profiles = db.profiles
    local classes = type(profiles) == "table" and profiles.classes or nil
    local profile = type(classes) == "table" and classes[classToken] or nil
    if type(profile) ~= "table" and create then
        profile = ensureClassProfile(db, classToken)
    end
    return type(profile) == "table" and profile.alerts or nil, profile
end

local function serializableValuesEqual(left, right, seen)
    if type(left) ~= type(right) then
        return false
    end
    if type(left) ~= "table" then
        return left == right
    end
    seen = seen or {}
    if seen[left] == right then
        return true
    end
    seen[left] = right
    for key, value in pairs(left) do
        if not serializableValuesEqual(value, right[key], seen) then
            return false
        end
    end
    for key in pairs(right) do
        if left[key] == nil then
            return false
        end
    end
    return true
end

local function restoreSerializable(target, backup)
    wipe(target)
    for key, value in pairs(backup) do
        target[key] = value
    end
end

local function migrateAuraListV1(list)
    if type(list) ~= "table" then
        return
    end
    for _, alert in pairs(list) do
        if type(alert) == "table" then
            if alert.nativeBackend == nil then
                alert.nativeBackend = "AUTO"
            end
            if alert.showStacks == nil then
                alert.showStacks = true
            end
            if alert.showName == nil then
                alert.showName = true
            end
            if alert.showCountdown == nil then
                alert.showCountdown = true
            end
        end
    end
end

local function migrateV1ToV2(db)
    db.migrationBackups = type(db.migrationBackups) == "table" and db.migrationBackups or {}
    if db.migrationBackups.auraSchemaV1 == nil then
        db.migrationBackups.auraSchemaV1 = copySerializable({
            playerAuras = db.alerts and db.alerts.playerAuras or {},
            targetAuras = db.alerts and db.alerts.targetAuras or {},
        })
    end
    if type(db.alerts) == "table" then
        migrateAuraListV1(db.alerts.playerAuras)
        migrateAuraListV1(db.alerts.targetAuras)
    end
    db.schemaVersion = 2
end

local VALID_TEXT_PLACEMENTS = {
    INSIDE_CENTER = true,
    INSIDE_TOP = true,
    INSIDE_TOP_RIGHT = true,
    INSIDE_RIGHT = true,
    INSIDE_BOTTOM_RIGHT = true,
    INSIDE_BOTTOM = true,
    INSIDE_BOTTOM_LEFT = true,
    INSIDE_LEFT = true,
    INSIDE_TOP_LEFT = true,
    OUTSIDE_TOP_AT_LEFT = true,
    OUTSIDE_LEFT_AT_TOP = true,
    OUTSIDE_TOP = true,
    OUTSIDE_TOP_AT_RIGHT = true,
    OUTSIDE_RIGHT_AT_TOP = true,
    OUTSIDE_RIGHT = true,
    OUTSIDE_RIGHT_AT_BOTTOM = true,
    OUTSIDE_BOTTOM_AT_RIGHT = true,
    OUTSIDE_BOTTOM = true,
    OUTSIDE_BOTTOM_AT_LEFT = true,
    OUTSIDE_LEFT_AT_BOTTOM = true,
    OUTSIDE_LEFT = true,
}

local LEGACY_INSIDE_PLACEMENTS = {
    CENTER = "INSIDE_CENTER",
    TOP = "INSIDE_TOP",
    TOPRIGHT = "INSIDE_TOP_RIGHT",
    RIGHT = "INSIDE_RIGHT",
    BOTTOMRIGHT = "INSIDE_BOTTOM_RIGHT",
    BOTTOM = "INSIDE_BOTTOM",
    BOTTOMLEFT = "INSIDE_BOTTOM_LEFT",
    LEFT = "INSIDE_LEFT",
    TOPLEFT = "INSIDE_TOP_LEFT",
}

local LEGACY_OUTSIDE_PLACEMENTS = {
    TOP = "OUTSIDE_TOP",
    TOPRIGHT = "OUTSIDE_TOP_AT_RIGHT",
    RIGHT = "OUTSIDE_RIGHT",
    BOTTOMRIGHT = "OUTSIDE_BOTTOM_AT_RIGHT",
    BOTTOM = "OUTSIDE_BOTTOM",
    BOTTOMLEFT = "OUTSIDE_BOTTOM_AT_LEFT",
    LEFT = "OUTSIDE_LEFT",
    TOPLEFT = "OUTSIDE_TOP_AT_LEFT",
}

local function appendMigrationWarning(db, warning)
    db.migrationWarnings = type(db.migrationWarnings) == "table" and db.migrationWarnings or {}
    db.migrationWarnings[#db.migrationWarnings + 1] = warning
end

local function normalizeTextFontSize(value, fallback)
    local numberValue = tonumber(value)
    if not numberValue then
        return fallback
    end
    numberValue = mathFloor(numberValue)
    if numberValue < EAM.Constants.TEXT_FONT_SIZE_MIN then
        return EAM.Constants.TEXT_FONT_SIZE_MIN
    elseif numberValue > EAM.Constants.TEXT_FONT_SIZE_MAX then
        return EAM.Constants.TEXT_FONT_SIZE_MAX
    end
    return numberValue
end

local function normalizeTextPlacement(value, fallback)
    if type(value) == "string" and VALID_TEXT_PLACEMENTS[value] then
        return value
    end
    return fallback
end

local function migrateLegacyPlacement(isInside, position, fallback)
    if isInside == true then
        return LEGACY_INSIDE_PLACEMENTS[position] or fallback
    elseif isInside == false then
        return LEGACY_OUTSIDE_PLACEMENTS[position] or fallback
    end
    return fallback
end

local function normalizeLanguageSelection(value)
    local locale = EAM.Locale
    if locale and type(locale.normalizeSelection) == "function" then
        return locale.normalizeSelection(value)
    end
    if value == "auto" or value == "enUS" or value == "zhTW" or value == "zhCN" or value == "koKR" or value == "ruRU" then
        return value
    end
    return "auto"
end

local function normalizeLanguageConfig(db)
    local config = type(db.config) == "table" and db.config or {}
    db.config = config
    local normalized = normalizeLanguageSelection(config.language)
    if config.language ~= nil and config.language ~= normalized then
        appendMigrationWarning(db, "invalidLanguageDefaulted")
    end
    config.language = normalized
end

local function normalizeThemeSelection(value)
    if value == "eam" or value == "ff7" or value == "winxp" or value == "borland" or value == "doscrt" or value == "aqua" then
        return value
    end
    return "eam"
end

local function normalizeFontFamilySelection(value)
    local options = EAM.Constants and EAM.Constants.FONT_FAMILY_OPTIONS or {}
    for index = 1, #options do
        if options[index].value == value then
            return value
        end
    end
    return EAM.Constants.FONT_FAMILY_DEFAULT or "STANDARD"
end

local function normalizeFontFamilyConfig(db)
    local config = type(db.config) == "table" and db.config or {}
    db.config = config
    local normalized = normalizeFontFamilySelection(config.fontFamily)
    if config.fontFamily ~= nil and config.fontFamily ~= normalized then
        appendMigrationWarning(db, "invalidFontFamilyDefaulted")
    end
    config.fontFamily = normalized
end
local function normalizeThemeConfig(db)
    local config = type(db.config) == "table" and db.config or {}
    db.config = config
    local normalized = normalizeThemeSelection(config.theme)
    if config.theme ~= nil and config.theme ~= normalized then
        appendMigrationWarning(db, "invalidThemeDefaulted")
    end
    config.theme = normalized
end

local function normalizeModuleToggles(db)
    local config = type(db.config) == "table" and db.config or {}
    db.config = config
    local toggles = type(config.moduleToggles) == "table" and config.moduleToggles or {}
    config.moduleToggles = toggles
    local invalidFound = false
    for key, defaultValue in pairs(defaults.config.moduleToggles) do
        if type(toggles[key]) ~= "boolean" then
            if toggles[key] ~= nil then
                invalidFound = true
            end
            toggles[key] = defaultValue
        end
    end
    if invalidFound then
        appendMigrationWarning(db, "invalidModuleToggleDefaulted")
    end
    config.enableItemCooldown = toggles.itemCooldown
end

local function normalizeTextLayout(db, preserveLegacy)
    local config = type(db.config) == "table" and db.config or {}
    db.config = config
    local textLayout = type(config.textLayout) == "table" and config.textLayout or {}
    config.textLayout = textLayout

    local timer = type(textLayout.timer) == "table" and textLayout.timer or {}
    local applications = type(textLayout.applications) == "table" and textLayout.applications or {}
    textLayout.timer = timer
    textLayout.applications = applications
    textLayout.schema = EAM.Constants.TEXT_LAYOUT_SCHEMA_VERSION

    local timerFallback = EAM.Constants.TEXT_PLACEMENT_TIMER_DEFAULT
    local applicationsFallback = EAM.Constants.TEXT_PLACEMENT_APPLICATIONS_DEFAULT
    if preserveLegacy then
        timerFallback = migrateLegacyPlacement(config.timerInside, config.timerPosition, timerFallback)
        applicationsFallback = migrateLegacyPlacement(config.stackInside, config.stackPosition, applicationsFallback)
    end

    local normalizedTimerPlacement = normalizeTextPlacement(timer.placement, timerFallback)
    local normalizedApplicationsPlacement = normalizeTextPlacement(applications.placement, applicationsFallback)
    if timer.placement ~= nil and timer.placement ~= normalizedTimerPlacement then
        appendMigrationWarning(db, "invalidTimerPlacementDefaulted")
    end
    if applications.placement ~= nil and applications.placement ~= normalizedApplicationsPlacement then
        appendMigrationWarning(db, "invalidApplicationsPlacementDefaulted")
    end

    timer.placement = normalizedTimerPlacement
    timer.fontSize = normalizeTextFontSize(timer.fontSize or config.fontSizeTimeVal, 14)
    applications.placement = normalizedApplicationsPlacement
    applications.fontSize = normalizeTextFontSize(applications.fontSize or config.fontSizeStack, 12)
    config.fontSizeTimeVal = timer.fontSize
    config.fontSizeStack = applications.fontSize
end

local function migrateV2ToV3(db)
    db.migrationBackups = type(db.migrationBackups) == "table" and db.migrationBackups or {}
    if db.migrationBackups.textLayoutV2 == nil then
        local config = type(db.config) == "table" and db.config or {}
        db.migrationBackups.textLayoutV2 = copySerializable({
            timerInside = config.timerInside,
            timerPosition = config.timerPosition,
            stackInside = config.stackInside,
            stackPosition = config.stackPosition,
            fontSizeTimeVal = config.fontSizeTimeVal,
            fontSizeStack = config.fontSizeStack,
            showChangeInOut = config.showChangeInOut,
            textLayout = config.textLayout,
        })
    end
    normalizeTextLayout(db, true)
    db.schemaVersion = 3
end

local function normalizeGroundDurationMode(value)
    if value == EAM.Constants.GROUND_DURATION_MANUAL then
        return EAM.Constants.GROUND_DURATION_MANUAL
    end
    return EAM.Constants.GROUND_DURATION_AUTO
end

local function normalizeGroundDuration(value, fallback)
    local numberValue = nil
    if type(value) == "number" and EAM.Util.isSafeNumber(value) then
        numberValue = value
    elseif type(value) == "string" then
        numberValue = tonumber(value)
    end
    if not numberValue then
        return fallback or 8
    end
    if numberValue < 0.1 then
        return 0.1
    elseif numberValue > 3600 then
        return 3600
    end
    return numberValue
end

local function extractGroundSpellID(key, alert)
    local value = type(alert) == "table" and alert.spellID or nil
    if value == nil then
        value = key
    end
    if type(value) == "string" then
        value = tonumber(value) or tonumber(string.match(value, "^groundEffect:player:(%d+)$"))
    end
    if not EAM.Util.isSafePositiveNumber(value) then
        return nil
    end
    return mathFloor(value)
end

local function normalizeGroundEffectsForAlerts(db, alerts, appendWarnings)
    local source = type(alerts.groundEffects) == "table" and alerts.groundEffects or {}
    local normalized = {}
    local priorities = {}

    for key, alert in pairs(source) do
        local spellID = extractGroundSpellID(key, alert)
        if spellID and type(alert) == "table" then
            local id = "groundEffect:player:" .. spellID
            local priority = key == id and 2 or 1
            if not normalized[id] or priority > priorities[id] then
                local record = copySerializable(alert) or {}
                record.id = id
                record.kind = EAM.Constants.ALERT_KIND_GROUND_EFFECT
                record.spellID = spellID
                record.itemID = nil
                record.unit = "player"
                record.enabled = alert.enabled ~= false
                record.durationMode = normalizeGroundDurationMode(alert.durationMode)
                record.manualDuration = normalizeGroundDuration(alert.manualDuration, 8)
                normalized[id] = record
                priorities[id] = priority
            elseif appendWarnings then
                appendMigrationWarning(db, "duplicateGroundEffectAlertSkipped")
            end
        elseif appendWarnings then
            appendMigrationWarning(db, "invalidGroundEffectAlertSkipped")
        end
    end

    alerts.groundEffects = normalized
end

local function normalizeGroundEffects(db, appendWarnings)
    local alerts = type(db.alerts) == "table" and db.alerts or createAlertLists()
    db.alerts = alerts
    normalizeGroundEffectsForAlerts(db, alerts, appendWarnings)
end

local function normalizeProfileGroundEffects(db)
    local profiles = db and db.profiles
    local classes = type(profiles) == "table" and profiles.classes or nil
    if type(classes) ~= "table" then
        return
    end
    for classToken, profile in pairs(classes) do
        if isValidClassToken(classToken) and type(profile) == "table" then
            local alerts = profile.alerts
            if type(alerts) == "table" then
                normalizeGroundEffectsForAlerts(db, alerts, false)
            end
        end
    end
end

local function migrateV3ToV4(db)
    db.migrationBackups = type(db.migrationBackups) == "table" and db.migrationBackups or {}
    if db.migrationBackups.groundEffectsV3 == nil then
        db.migrationBackups.groundEffectsV3 = copySerializable(db.alerts and db.alerts.groundEffects or {})
    end
    if db.migrationBackups.cooldownVisualV3 == nil then
        local config = type(db.config) == "table" and db.config or {}
        db.migrationBackups.cooldownVisualV3 = copySerializable({
            cooldownShadow = config.cooldownShadow,
            cooldownSwipeAlpha = config.cooldownSwipeAlpha,
            nativeAuraDualCountdownProbe = config.nativeAuraDualCountdownProbe,
        })
    end

    normalizeGroundEffects(db, true)
    db.config = type(db.config) == "table" and db.config or {}
    local legacyAlpha = db.config.cooldownShadow
    local alpha = db.config.cooldownSwipeAlpha
    if not EAM.Util.isSafeNumber(alpha) then
        alpha = type(legacyAlpha) == "number" and EAM.Util.isSafeNumber(legacyAlpha) and legacyAlpha or 1
    end
    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end
    db.config.cooldownSwipeAlpha = alpha
    db.config.nativeAuraDualCountdownProbe = db.config.nativeAuraDualCountdownProbe == true
    db.schemaVersion = 4
end

local ALERT_LIST_NAMES = {
    "playerAuras",
    "targetAuras",
    "spellCooldowns",
    "itemCooldowns",
    "groundEffects",
}

local function alertListsHaveEntries(alerts)
    if type(alerts) ~= "table" then
        return false
    end
    for index = 1, #ALERT_LIST_NAMES do
        local list = alerts[ALERT_LIST_NAMES[index]]
        if type(list) == "table" and next(list) ~= nil then
            return true
        end
    end
    return false
end

local function migrateV4ToV5(db)
    db.migrationBackups = type(db.migrationBackups) == "table" and db.migrationBackups or {}
    local sourceAlerts = type(db.alerts) == "table" and db.alerts or createAlertLists()
    if db.migrationBackups.globalAlertsV4 == nil then
        db.migrationBackups.globalAlertsV4 = copySerializable(sourceAlerts) or createAlertLists()
    end

    db.profiles = type(db.profiles) == "table" and db.profiles or {}
    db.profiles.classes = type(db.profiles.classes) == "table" and db.profiles.classes or {}
    local classToken = getPlayerClassToken()
    if classToken then
        local profile = ensureClassProfile(db, classToken)
        if profile and not alertListsHaveEntries(profile.alerts) then
            profile.alerts = copySerializable(sourceAlerts) or createAlertLists()
            ensureClassProfile(db, classToken)
            profile.defaultsSeeded = alertListsHaveEntries(sourceAlerts)
            profile.legacyImportVersion = 0
            appendProfileWarning(db, "globalAlertsV4AssignedToActiveClass:" .. classToken)
        end
    else
        db.profiles.unassignedLegacy = copySerializable(sourceAlerts) or createAlertLists()
        appendProfileWarning(db, "globalAlertsV4AwaitingClassAssignment")
    end

    db.config = type(db.config) == "table" and db.config or {}
    local moduleToggles = type(db.config.moduleToggles) == "table" and db.config.moduleToggles or {}
    db.config.moduleToggles = moduleToggles
    for key, defaultValue in pairs(defaults.config.moduleToggles) do
        if type(moduleToggles[key]) ~= "boolean" then
            moduleToggles[key] = defaultValue
        end
    end
    if type(db.config.enableItemCooldown) == "boolean" then
        moduleToggles.itemCooldown = db.config.enableItemCooldown
    end
    db.config.enableItemCooldown = moduleToggles.itemCooldown

    db.alerts = nil
    db.schemaVersion = 5
end

local MIGRATIONS = {
    [1] = migrateV1ToV2,
    [2] = migrateV2ToV3,
    [3] = migrateV3ToV4,
    [4] = migrateV4ToV5,
}

local function runMigrations(db)
    local version = tonumber(db.schemaVersion) or 1
    if version > EAM.Constants.SCHEMA_VERSION then
        return false, "futureSchemaPreserved", version
    end

    while version < EAM.Constants.SCHEMA_VERSION do
        local migration = MIGRATIONS[version]
        if not migration then
            db.migrationWarnings = type(db.migrationWarnings) == "table" and db.migrationWarnings or {}
            db.migrationWarnings[#db.migrationWarnings + 1] = "migrationPathMissing"
            return false, "migrationPathMissing", version
        end
        local rollback = copySerializable(db)
        local ok = pcall(migration, db)
        if not ok then
            restoreSerializable(db, rollback)
            db.migrationWarnings = type(db.migrationWarnings) == "table" and db.migrationWarnings or {}
            db.migrationWarnings[#db.migrationWarnings + 1] = "migrationFailed"
            return false, "migrationFailed", version
        end
        version = tonumber(db.schemaVersion) or version
    end
    return true
end

local function activateClassProfile(db)
    local classToken = getPlayerClassToken()
    SavedVariables.activeClassToken = classToken
    if not classToken then
        return nil, nil, "classUnavailable"
    end

    local profile = ensureClassProfile(db, classToken)
    local profiles = db.profiles
    local unassigned = type(profiles) == "table" and profiles.unassignedLegacy or nil
    if type(unassigned) == "table" and profile and not alertListsHaveEntries(profile.alerts) then
        profile.alerts = copySerializable(unassigned) or createAlertLists()
        ensureClassProfile(db, classToken)
        profile.defaultsSeeded = alertListsHaveEntries(unassigned)
        profiles.unassignedLegacy = nil
        appendProfileWarning(db, "unassignedLegacyAssignedToActiveClass:" .. classToken)
    end
    return profile, classToken, "active"
end

SavedVariables.defaults = defaults

local function ensureTable(parent, key)
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end
    return parent[key]
end

local function normalizePositiveInteger(value)
    local numberValue = tonumber(value)
    if not numberValue or numberValue <= 0 then
        return nil
    end
    numberValue = mathFloor(numberValue)
    return numberValue > 0 and numberValue or nil
end

local AURA_SOUND_TRIGGER_KEYS = {
    "added",
    "applicationsIncreased",
    "removed",
}

local function normalizeAuraSoundEntry(value)
    if type(value) ~= "table" then
        return nil
    end

    local soundFileID = normalizePositiveInteger(value.soundFileID)
    local soundFileName = type(value.soundFileName) == "string" and value.soundFileName or nil
    if soundFileName and not soundFileName:find("%S") then
        soundFileName = nil
    end
    if not soundFileID and not soundFileName then
        return nil
    end

    local normalized = {}
    if soundFileID then
        normalized.soundFileID = soundFileID
    else
        normalized.soundFileName = soundFileName
    end
    if type(value.outputChannel) == "string" and value.outputChannel:find("%S") then
        normalized.outputChannel = value.outputChannel
    end
    return normalized
end

local function normalizeAuraSound(value)
    if type(value) ~= "table" then
        return nil
    end

    local normalized = {}
    local count = 0
    for index = 1, #AURA_SOUND_TRIGGER_KEYS do
        local key = AURA_SOUND_TRIGGER_KEYS[index]
        local entry = normalizeAuraSoundEntry(value[key])
        if entry then
            normalized[key] = entry
            count = count + 1
        end
    end
    return count > 0 and normalized or nil
end

local function normalizeAlertPriority(value)
    local numberValue = tonumber(value)
    if not numberValue then
        return 10
    end
    numberValue = mathFloor(numberValue)
    if numberValue < 1 then
        return 1
    end
    if numberValue > 20 then
        return 20
    end
    return numberValue
end

local function normalizeAuraPriorityList(list)
    if type(list) ~= "table" then
        return false
    end
    local changed = false
    for _, alert in pairs(list) do
        if type(alert) == "table" then
            local normalized = normalizeAlertPriority(alert.priority)
            if alert.priority ~= normalized then
                alert.priority = normalized
                changed = true
            end
        end
    end
    return changed
end

local function normalizeAuraPriorities(db)
    local changed = false
    local profiles = db and db.profiles
    local classes = type(profiles) == "table" and profiles.classes or nil
    if type(classes) == "table" then
        for classToken, profile in pairs(classes) do
            if isValidClassToken(classToken) and type(profile) == "table" then
                local alerts = profile.alerts
                if type(alerts) == "table" then
                    if normalizeAuraPriorityList(alerts.playerAuras) then
                        changed = true
                    end
                    if normalizeAuraPriorityList(alerts.targetAuras) then
                        changed = true
                    end
                end
            end
        end
    elseif type(db and db.alerts) == "table" then
        changed = normalizeAuraPriorityList(db.alerts.playerAuras)
        if normalizeAuraPriorityList(db.alerts.targetAuras) then
            changed = true
        end
    end
    return changed
end

local function normalizeAuraSoundList(list)
    if type(list) ~= "table" then
        return false
    end
    local changed = false
    for _, alert in pairs(list) do
        if type(alert) == "table" and alert.sound ~= nil then
            local normalized = normalizeAuraSound(alert.sound)
            if not serializableValuesEqual(alert.sound, normalized) then
                alert.sound = normalized
                changed = true
            end
        end
    end
    return changed
end

local function normalizeProfileAuraSounds(db)
    local changed = false
    local profiles = db and db.profiles
    local classes = type(profiles) == "table" and profiles.classes or nil
    if type(classes) == "table" then
        for classToken, profile in pairs(classes) do
            if isValidClassToken(classToken) and type(profile) == "table" then
                local alerts = profile.alerts
                if type(alerts) == "table" then
                    if normalizeAuraSoundList(alerts.playerAuras) then
                        changed = true
                    end
                    if normalizeAuraSoundList(alerts.targetAuras) then
                        changed = true
                    end
                end
            end
        end
    elseif type(db and db.alerts) == "table" then
        changed = normalizeAuraSoundList(db.alerts.playerAuras)
        if normalizeAuraSoundList(db.alerts.targetAuras) then
            changed = true
        end
    end
    if changed then
        appendMigrationWarning(db, "invalidAuraSoundNormalized")
    end
    return changed
end

local function buildAlertID(kind, unit, spellID, itemID)
    if kind == EAM.Constants.ALERT_KIND_ITEM_COOLDOWN then
        if not itemID then
            return nil
        end
        return kind .. ":item:" .. itemID
    end

    if not spellID then
        return nil
    end

    return kind .. ":" .. (unit or "player") .. ":" .. spellID
end

local function getAlertList(db, kind, unit, classToken)
    if not db then
        return nil
    end

    local alerts = nil
    if type(db.profiles) == "table" then
        alerts = getProfileAlerts(db, classToken, true)
    elseif type(db.alerts) == "table" then
        alerts = db.alerts
    else
        alerts = getProfileAlerts(db, classToken, true)
    end
    if type(alerts) ~= "table" then
        return nil
    end
    if kind == EAM.Constants.ALERT_KIND_AURA then
        if unit == "target" then
            return ensureTable(alerts, "targetAuras")
        end
        return ensureTable(alerts, "playerAuras")
    elseif kind == EAM.Constants.ALERT_KIND_SPELL_COOLDOWN then
        return ensureTable(alerts, "spellCooldowns")
    elseif kind == EAM.Constants.ALERT_KIND_ITEM_COOLDOWN then
        return ensureTable(alerts, "itemCooldowns")
    elseif kind == "groundEffect" then
        return ensureTable(alerts, "groundEffects")
    end

    return nil
end

local function touchRevision(db)
    if not db then
        return
    end
    db.revision = (db.revision or 0) + 1
end

local function copyMissingDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            local child = ensureTable(target, key)
            copyMissingDefaults(child, value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function addAlert(list, kind, spellID, itemID, unit, sourceTable, sourceKey, options)
    if type(list) ~= "table" then
        return false
    end

    local id = buildAlertID(kind, unit, spellID, itemID)
    if not id then
        return false
    end

    if list[id] then
        return false
    end

    list[id] = {
        id = id,
        kind = kind,
        spellID = spellID,
        itemID = itemID,
        unit = unit,
        enabled = options and options.enable ~= false,
        fromPlayer = options and options.self == true,
        legacy = {
            tableName = sourceTable,
            key = sourceKey,
        },
    }
    return true
end

local function importSpellTable(target, source, kind, unit, tableName)
    if type(source) ~= "table" then
        return 0, 0
    end

    local imported = 0
    local skipped = 0
    for spellID, options in pairs(source) do
        local numericID = tonumber(spellID)
        if numericID then
            if addAlert(target, kind, numericID, nil, unit, tableName, spellID, options) then
                imported = imported + 1
            end
        else
            skipped = skipped + 1
        end
    end

    return imported, skipped
end

local function importLegacyTables(db)
    local report = SavedVariables.migrationReport
    local classToken = SavedVariables.activeClassToken
    local alerts, profile = getProfileAlerts(db, classToken, true)
    if not alerts or not profile or (tonumber(profile.legacyImportVersion) or 0) >= 1 then
        return 0, 0
    end

    local playerAuras = alerts.playerAuras
    local targetAuras = alerts.targetAuras
    local spellCooldowns = alerts.spellCooldowns
    local totalImported = 0
    local totalSkipped = 0
    local imported, skipped
    if type(EA_Items) == "table" then
        imported, skipped = importSpellTable(playerAuras, EA_Items[classToken], "aura", "player", "EA_Items")
        totalImported = totalImported + imported
        totalSkipped = totalSkipped + skipped
        imported, skipped = importSpellTable(playerAuras, EA_Items.OTHER, "aura", "player", "EA_Items")
        totalImported = totalImported + imported
        totalSkipped = totalSkipped + skipped
    end

    if type(EA_AltItems) == "table" then
        imported, skipped = importSpellTable(playerAuras, EA_AltItems[classToken], "aura", "player", "EA_AltItems")
        totalImported = totalImported + imported
        totalSkipped = totalSkipped + skipped
    end

    if type(EA_TarItems) == "table" then
        imported, skipped = importSpellTable(targetAuras, EA_TarItems[classToken], "aura", "target", "EA_TarItems")
        totalImported = totalImported + imported
        totalSkipped = totalSkipped + skipped
    end

    if type(EA_ScdItems) == "table" then
        imported, skipped = importSpellTable(spellCooldowns, EA_ScdItems[classToken], "spellCooldown", "player", "EA_ScdItems")
        totalImported = totalImported + imported
        totalSkipped = totalSkipped + skipped
    end

    profile.legacyImportVersion = 1
    report.imported = report.imported + totalImported
    report.skipped = report.skipped + totalSkipped
    if totalImported > 0 then
        touchRevision(db)
    end
    return totalImported, totalSkipped
end

local function seedActiveProfileDefaults(profile, classToken)
    if not profile or profile.defaultsSeeded == true then
        return false, "alreadySeeded"
    end
    local spellArray = EAM.Data and EAM.Data.SpellArray
    local classData = spellArray and spellArray[classToken]
    if type(classData) ~= "table" then
        return false, "classDefaultsUnavailable"
    end

    profile.defaultsSeeded = true
    local function loadDefaultList(sourceList)
        if type(sourceList) ~= "table" then
            return
        end
        for index = 1, #sourceList do
            local spell = sourceList[index]
            if type(spell) == "table" then
                if spell.type == EAM.Constants.ALERT_KIND_ITEM_COOLDOWN then
                    SavedVariables.addAlert(spell.type, spell.unit, nil, spell.id, spell)
                elseif spell.type == EAM.Constants.ALERT_KIND_AURA
                    or spell.type == EAM.Constants.ALERT_KIND_SPELL_COOLDOWN
                    or spell.type == EAM.Constants.ALERT_KIND_GROUND_EFFECT
                then
                    SavedVariables.addAlert(spell.type, spell.unit, spell.id, nil, spell)
                end
            end
        end
    end

    loadDefaultList(classData.general)
    for specializationIndex = 1, 4 do
        loadDefaultList(classData[specializationIndex])
    end
    return true, "seeded"
end

function SavedVariables.initialize()
    EAM_DB = EAM_DB or {}
    local migrated, migrationReason, sourceVersion = runMigrations(EAM_DB)
    if not migrated and migrationReason == "futureSchemaPreserved" then
        SavedVariables.migrationReport.futureSchemaPreserved = true
        SavedVariables.migrationReport.futureSchemaVersion = sourceVersion
        local runtimeDB = copySerializable(defaults)
        runtimeDB.migrationWarnings = { "futureSchemaPreserved" }
        runtimeDB.futureSchemaSourceVersion = sourceVersion
        EAM.db = runtimeDB
        SavedVariables.activeClassToken = getPlayerClassToken()
        if SavedVariables.activeClassToken then
            ensureClassProfile(runtimeDB, SavedVariables.activeClassToken)
        end
        return runtimeDB
    end

    copyMissingDefaults(EAM_DB, defaults)
    EAM.db = EAM_DB
    local activeProfile, activeClassToken = activateClassProfile(EAM_DB)
    normalizeLanguageConfig(EAM_DB)
    normalizeThemeConfig(EAM_DB)
    normalizeFontFamilyConfig(EAM_DB)
    normalizeModuleToggles(EAM_DB)
    normalizeTextLayout(EAM_DB, false)
    normalizeProfileGroundEffects(EAM_DB)
    normalizeAuraPriorities(EAM_DB)
    normalizeProfileAuraSounds(EAM_DB)

    -- 多框架升級相容與舊坐標遷移
    if EAM_DB.layout and type(EAM_DB.layout.frames) ~= "table" then
        EAM_DB.layout.frames = {}
        for fName, fDef in pairs(defaults.layout.frames) do
            EAM_DB.layout.frames[fName] = {
                growDirection = fDef.growDirection,
                x = fDef.x,
                y = fDef.y,
                point = fDef.point,
            }
        end
        -- 舊的全域坐標映射給自身光環 (selfAura)
        if EAM_DB.layout.x and EAM_DB.layout.y then
            EAM_DB.layout.frames.selfAura.x = EAM_DB.layout.x
            EAM_DB.layout.frames.selfAura.y = EAM_DB.layout.y
            EAM_DB.layout.frames.selfAura.point = EAM_DB.layout.point or "CENTER"
            EAM_DB.layout.x = nil
            EAM_DB.layout.y = nil
            EAM_DB.layout.point = nil
        end
    end

    importLegacyTables(EAM_DB)
    seedActiveProfileDefaults(activeProfile, activeClassToken)

    return EAM_DB
end

function SavedVariables.buildAlertID(kind, unit, spellID, itemID)
    return buildAlertID(kind, unit, spellID, itemID)
end

function SavedVariables.getActiveClassToken()
    return SavedVariables.activeClassToken
end

function SavedVariables.getClassProfile(classToken, db)
    if not isValidClassToken(classToken) then
        return nil
    end
    local _, profile = getProfileAlerts(db or EAM.db, classToken, false)
    return profile
end

function SavedVariables.getActiveAlerts(db)
    local targetDB = db or EAM.db
    local alerts = getProfileAlerts(targetDB, SavedVariables.activeClassToken, false)
    if type(alerts) == "table" then
        return alerts
    end
    return type(targetDB) == "table" and targetDB.alerts or nil
end

function SavedVariables.getAlertList(kind, unit, classToken)
    return getAlertList(EAM.db, kind, unit, classToken)
end

function SavedVariables.markRevisionChanged()
    if type(EAM.db) ~= "table" then
        return false
    end
    touchRevision(EAM.db)
    return true, EAM.db.revision
end

function SavedVariables.updateLanguage(selection)
    local db = EAM.db
    if type(db) ~= "table" or type(db.config) ~= "table" then
        return false, "dbUnavailable"
    end

    local normalized = normalizeLanguageSelection(selection)
    local router = EAM.Modules and EAM.Modules.EventRouter
    if db.config.language == normalized then
        if router then
            router.fire("EAM_LANGUAGE_CHANGED", normalized, db.revision, "unchanged")
        end
        return true, "unchanged"
    end

    db.config.language = normalized
    touchRevision(db)
    if router then
        router.fire("EAM_LANGUAGE_CHANGED", normalized, db.revision, "updated")
    end
    return true, "updated", db.revision
end

function SavedVariables.updateTheme(selection)
    local db = EAM.db
    if type(db) ~= "table" or type(db.config) ~= "table" then
        return false, "dbUnavailable"
    end

    local normalized = normalizeThemeSelection(selection)
    if db.config.theme == normalized then
        return true, "unchanged"
    end

    db.config.theme = normalized
    touchRevision(db)
    return true, "updated", db.revision
end

function SavedVariables.updateFontFamily(selection)
    local db = EAM.db
    if type(db) ~= "table" or type(db.config) ~= "table" then
        return false, "dbUnavailable"
    end
    local normalized = normalizeFontFamilySelection(selection)
    if db.config.fontFamily == normalized then
        return true, "unchanged", db.revision
    end
    db.config.fontFamily = normalized
    touchRevision(db)
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router then
        router.fire("EAM_FONT_FAMILY_CHANGED", normalized, db.revision)
    end
    return true, "updated", db.revision
end
function SavedVariables.updateModuleToggle(key, enabled)
    local db = EAM.db
    local moduleDefaults = defaults.config.moduleToggles
    if type(db) ~= "table" or type(db.config) ~= "table" then
        return false, "dbUnavailable"
    end
    if moduleDefaults[key] == nil then
        return false, "invalidModuleKey"
    end
    if type(enabled) ~= "boolean" then
        return false, "invalidModuleValue"
    end

    local toggles = type(db.config.moduleToggles) == "table" and db.config.moduleToggles or {}
    db.config.moduleToggles = toggles
    if toggles[key] == enabled then
        return true, "unchanged", db.revision
    end

    toggles[key] = enabled
    if key == EAM.Constants.MODULE_KEYS.itemCooldown then
        db.config.enableItemCooldown = enabled
    end
    touchRevision(db)
    local router = EAM.Modules.EventRouter
    if router then
        router.fire("EAM_MODULE_TOGGLE_CHANGED", key, enabled, db.revision)
    end
    return true, "updated", db.revision
end

function SavedVariables.updateTextLayout(kind, placement, fontSize)
    local db = EAM.db
    if type(db) ~= "table" or type(db.config) ~= "table" then
        return false, "dbUnavailable"
    end
    if kind ~= "timer" and kind ~= "applications" then
        return false, "invalidTextLayoutKind"
    end

    normalizeTextLayout(db, false)
    local section = db.config.textLayout[kind]
    local changed = false
    if placement ~= nil then
        local normalizedPlacement = normalizeTextPlacement(placement, nil)
        if not normalizedPlacement then
            return false, "invalidTextPlacement"
        end
        if section.placement ~= normalizedPlacement then
            section.placement = normalizedPlacement
            changed = true
        end
    end
    if fontSize ~= nil then
        local fallback = kind == "timer" and 14 or 12
        local normalizedFontSize = normalizeTextFontSize(fontSize, fallback)
        if section.fontSize ~= normalizedFontSize then
            section.fontSize = normalizedFontSize
            changed = true
        end
        if kind == "timer" then
            db.config.fontSizeTimeVal = normalizedFontSize
        else
            db.config.fontSizeStack = normalizedFontSize
        end
    end

    if not changed then
        return true, "unchanged"
    end
    touchRevision(db)
    return true, "updated", db.revision
end

function SavedVariables.addAlert(kind, unit, spellID, itemID, options)
    local db = EAM.db
    if type(db) ~= "table" then
        return false, "dbUnavailable"
    end

    spellID = spellID and normalizePositiveInteger(spellID) or nil
    itemID = itemID and normalizePositiveInteger(itemID) or nil
    local list = getAlertList(db, kind, unit)
    if not list then
        return false, "invalidKind"
    end

    local id = buildAlertID(kind, unit, spellID, itemID)
    if not id then
        return false, "invalidID"
    end

    if list[id] then
        local existing = list[id]
        local changed = false
        if existing.enabled ~= true then
            existing.enabled = true
            changed = true
        end
        if options and existing.fromPlayer ~= (options.fromPlayer == true or nil) then
            existing.fromPlayer = options.fromPlayer == true or nil
            changed = true
        end
        if kind == EAM.Constants.ALERT_KIND_AURA and options then
            local auraFilter = nil
            if options.auraFilter == "HELPFUL" or options.auraFilter == "HARMFUL" then
                auraFilter = options.auraFilter
            end
            if auraFilter and existing.auraFilter ~= auraFilter then
                existing.auraFilter = auraFilter
                changed = true
            end
            local fields = { "showStacks", "showName", "showCountdown" }
            for index = 1, #fields do
                local field = fields[index]
                if options[field] ~= nil and existing[field] ~= (options[field] == true) then
                    existing[field] = options[field] == true
                    changed = true
                end
            end
            if options.priority ~= nil then
                local priority = normalizeAlertPriority(options.priority)
                if existing.priority ~= priority then
                    existing.priority = priority
                    changed = true
                end
            end
            if options.sound ~= nil then
                local sound = normalizeAuraSound(options.sound)
                if not serializableValuesEqual(existing.sound, sound) then
                    existing.sound = sound
                    changed = true
                end
            end
        end
        if kind == EAM.Constants.ALERT_KIND_GROUND_EFFECT and options then
            local durationMode = normalizeGroundDurationMode(options.durationMode)
            local manualDuration = normalizeGroundDuration(options.manualDuration, 8)
            if existing.durationMode ~= durationMode then
                existing.durationMode = durationMode
                changed = true
            end
            if existing.manualDuration ~= manualDuration then
                existing.manualDuration = manualDuration
                changed = true
            end
        end
        if changed then
            touchRevision(db)
            if kind == EAM.Constants.ALERT_KIND_AURA and EAM.Modules.EventRouter then
                EAM.Modules.EventRouter.fire("EAM_AURA_CONFIG_CHANGED", db.revision)
            end
            return true, id, "updated"
        end
        return true, id, "unchanged"
    end

    list[id] = {
        id = id,
        kind = kind,
        spellID = spellID,
        itemID = itemID,
        unit = unit,
        enabled = true,
        fromPlayer = options and options.fromPlayer == true or nil,
        nativeBackend = kind == EAM.Constants.ALERT_KIND_AURA and "AUTO" or nil,
        auraFilter = kind == EAM.Constants.ALERT_KIND_AURA and options
            and (options.auraFilter == "HELPFUL" or options.auraFilter == "HARMFUL")
            and options.auraFilter or nil,
        showStacks = kind == EAM.Constants.ALERT_KIND_AURA and (not options or options.showStacks ~= false) or nil,
        showName = kind == EAM.Constants.ALERT_KIND_AURA and (not options or options.showName ~= false) or nil,
        showCountdown = kind == EAM.Constants.ALERT_KIND_AURA and (not options or options.showCountdown ~= false) or nil,
        priority = kind == EAM.Constants.ALERT_KIND_AURA and normalizeAlertPriority(options and options.priority) or nil,
        sound = kind == EAM.Constants.ALERT_KIND_AURA and options and normalizeAuraSound(options.sound) or nil,
        durationMode = kind == EAM.Constants.ALERT_KIND_GROUND_EFFECT
            and normalizeGroundDurationMode(options and options.durationMode) or nil,
        manualDuration = kind == EAM.Constants.ALERT_KIND_GROUND_EFFECT
            and normalizeGroundDuration(options and options.manualDuration, 8) or nil,
    }
    touchRevision(db)
    if kind == EAM.Constants.ALERT_KIND_AURA and EAM.Modules.EventRouter then
        EAM.Modules.EventRouter.fire("EAM_AURA_CONFIG_CHANGED", db.revision)
    end
    return true, id, "added"
end

function SavedVariables.updateAlertPriority(kind, unit, spellID, itemID, value)
    local db = EAM.db
    if type(db) ~= "table" then
        return false, "dbUnavailable"
    end
    local numericSpellID = spellID and normalizePositiveInteger(spellID) or nil
    local numericItemID = itemID and normalizePositiveInteger(itemID) or nil
    local list = getAlertList(db, kind, unit)
    local id = buildAlertID(kind, unit, numericSpellID, numericItemID)
    if not list or not id then
        return false, "invalidID"
    end
    local alert = list[id]
    if type(alert) ~= "table" then
        return false, "notFound"
    end
    local priority = normalizeAlertPriority(value)
    if alert.priority == priority then
        return true, "unchanged", priority
    end
    alert.priority = priority
    touchRevision(db)
    if kind == EAM.Constants.ALERT_KIND_AURA and EAM.Modules.EventRouter then
        EAM.Modules.EventRouter.fire("EAM_AURA_CONFIG_CHANGED", db.revision)
    end
    return true, "updated", db.revision
end
function SavedVariables.updateAuraSound(unit, spellID, sound)
    local db = EAM.db
    if type(db) ~= "table" or (unit ~= "player" and unit ~= "target") then
        return false, "invalidUnit"
    end

    local numericSpellID = normalizePositiveInteger(spellID)
    local list = getAlertList(db, EAM.Constants.ALERT_KIND_AURA, unit)
    local id = numericSpellID and buildAlertID(EAM.Constants.ALERT_KIND_AURA, unit, numericSpellID) or nil
    local alert = id and list and list[id] or nil
    if type(alert) ~= "table" then
        return false, "notFound"
    end

    local normalized = normalizeAuraSound(sound)
    if serializableValuesEqual(alert.sound, normalized) then
        return true, "unchanged", db.revision
    end

    alert.sound = normalized
    touchRevision(db)
    if EAM.Modules.EventRouter then
        EAM.Modules.EventRouter.fire("EAM_AURA_SOUND_CHANGED", db.revision)
    end
    return true, "updated", db.revision
end

local PROFILE_IMPORT_DEFINITIONS = {
    playerAura = { listName = "playerAuras", kind = EAM.Constants.ALERT_KIND_AURA, unit = "player", idField = "spellID" },
    targetAura = { listName = "targetAuras", kind = EAM.Constants.ALERT_KIND_AURA, unit = "target", idField = "spellID" },
    spellCooldown = { listName = "spellCooldowns", kind = EAM.Constants.ALERT_KIND_SPELL_COOLDOWN, unit = "player", idField = "spellID" },
    itemCooldown = { listName = "itemCooldowns", kind = EAM.Constants.ALERT_KIND_ITEM_COOLDOWN, unit = nil, idField = "itemID" },
    groundEffect = { listName = "groundEffects", kind = EAM.Constants.ALERT_KIND_GROUND_EFFECT, unit = "player", idField = "spellID" },
}

local function buildImportedAlert(moduleName, record)
    local definition = PROFILE_IMPORT_DEFINITIONS[moduleName]
    if not definition or type(record) ~= "table" then
        return nil, "recordInvalid"
    end
    local numericID = record[definition.idField]
    if type(numericID) ~= "number" or numericID % 1 ~= 0 or numericID <= 0 then
        return nil, "recordIDInvalid"
    end
    local alertID = buildAlertID(definition.kind, definition.unit, definition.kind == EAM.Constants.ALERT_KIND_ITEM_COOLDOWN and nil or numericID, definition.kind == EAM.Constants.ALERT_KIND_ITEM_COOLDOWN and numericID or nil)
    if not alertID then
        return nil, "recordIDInvalid"
    end

    local alert = {
        id = alertID,
        kind = definition.kind,
        spellID = definition.kind == EAM.Constants.ALERT_KIND_ITEM_COOLDOWN and nil or numericID,
        itemID = definition.kind == EAM.Constants.ALERT_KIND_ITEM_COOLDOWN and numericID or nil,
        unit = definition.unit,
        enabled = record.enabled ~= false,
    }

    if definition.kind == EAM.Constants.ALERT_KIND_AURA then
        alert.fromPlayer = record.fromPlayer == true or nil
        alert.nativeBackend = "AUTO"
        alert.auraFilter = (record.auraFilter == "HELPFUL" or record.auraFilter == "HARMFUL") and record.auraFilter or nil
        alert.showStacks = record.showStacks ~= false
        alert.showName = record.showName ~= false
        alert.showCountdown = record.showCountdown ~= false
        alert.priority = normalizeAlertPriority(record.priority)
        if record.sound ~= nil then
            alert.sound = normalizeAuraSound(record.sound)
            if not alert.sound then
                return nil, "soundInvalid"
            end
        end
    elseif definition.kind == EAM.Constants.ALERT_KIND_GROUND_EFFECT then
        alert.durationMode = normalizeGroundDurationMode(record.durationMode)
        alert.manualDuration = normalizeGroundDuration(record.manualDuration, 8)
    end
    return alert
end

local function exportComparableImportedAlert(moduleName, alert)
    local definition = PROFILE_IMPORT_DEFINITIONS[moduleName]
    if not definition or type(alert) ~= "table" then
        return nil
    end
    local record = {
        [definition.idField] = alert[definition.idField],
        enabled = alert.enabled ~= false,
    }
    if definition.kind == EAM.Constants.ALERT_KIND_AURA then
        record.fromPlayer = alert.fromPlayer == true
        record.auraFilter = alert.auraFilter
        record.showStacks = alert.showStacks ~= false
        record.showName = alert.showName ~= false
        record.showCountdown = alert.showCountdown ~= false
        record.priority = normalizeAlertPriority(alert.priority)
        record.sound = normalizeAuraSound(alert.sound)
    elseif definition.kind == EAM.Constants.ALERT_KIND_GROUND_EFFECT then
        record.durationMode = normalizeGroundDurationMode(alert.durationMode)
        record.manualDuration = normalizeGroundDuration(alert.manualDuration, 8)
    end
    return record
end

function SavedVariables.applyProfileImport(classToken, moduleRecords, mode)
    local db = EAM.db
    if type(db) ~= "table" or type(moduleRecords) ~= "table" then
        return false, "dbUnavailable"
    end
    if not isValidClassToken(classToken) then
        return false, "invalidClass"
    end
    if mode ~= "merge" and mode ~= "replace" then
        return false, "invalidMode"
    end
    if EAM.API and type(EAM.API.InCombatLockdown) == "function" and EAM.API.InCombatLockdown() then
        return false, "combatDeferred"
    end

    local alerts, profile = getProfileAlerts(db, classToken, true)
    if type(alerts) ~= "table" or type(profile) ~= "table" then
        return false, "profileUnavailable"
    end

    local prepared = {}
    local changed = false
    local auraChanged = false
    local soundChanged = false
    local report = { added = 0, updated = 0, unchanged = 0, removed = 0 }
    for moduleName, records in pairs(moduleRecords) do
        local definition = PROFILE_IMPORT_DEFINITIONS[moduleName]
        if not definition or type(records) ~= "table" then
            return false, "moduleInvalid"
        end
        local preparedModule = {}
        local count = 0
        for index, record in pairs(records) do
            if type(index) ~= "number" or index % 1 ~= 0 or index < 1 then
                return false, "recordsNotArray"
            end
            count = count + 1
            if count > 1024 then
                return false, "moduleLimit"
            end
            local alert, reason = buildImportedAlert(moduleName, record)
            if not alert then
                return false, reason
            end
            if preparedModule[alert.id] then
                return false, "duplicateAlertID"
            end
            preparedModule[alert.id] = alert
        end
        prepared[moduleName] = preparedModule
    end

    local snapshots = {}
    local nextLists = {}
    for moduleName, imported in pairs(prepared) do
        local definition = PROFILE_IMPORT_DEFINITIONS[moduleName]
        local current = alerts[definition.listName]
        if type(current) ~= "table" then
            current = {}
        end
        if mode == "replace" then
            snapshots[moduleName] = copySerializable(current) or {}
            nextLists[moduleName] = {}
        else
            nextLists[moduleName] = copySerializable(current) or {}
        end
        local nextList = nextLists[moduleName]
        for alertID, alert in pairs(imported) do
            local existing = current[alertID]
            local comparable = existing and exportComparableImportedAlert(moduleName, existing) or nil
            local incoming = exportComparableImportedAlert(moduleName, alert)
            if existing and comparable and serializableValuesEqual(comparable, incoming) then
                report.unchanged = report.unchanged + 1
            else
                if existing then
                    report.updated = report.updated + 1
                else
                    report.added = report.added + 1
                end
                changed = true
                if definition.kind == EAM.Constants.ALERT_KIND_AURA then
                    auraChanged = true
                    soundChanged = true
                end
            end
            nextList[alertID] = copySerializable(alert) or alert
        end
        if mode == "replace" then
            for alertID in pairs(current) do
                if not imported[alertID] then
                    report.removed = report.removed + 1
                    changed = true
                    if definition.kind == EAM.Constants.ALERT_KIND_AURA then
                        auraChanged = true
                        soundChanged = true
                    end
                end
            end
        end
    end

    if not changed then
        return true, "unchanged", report
    end

    if mode == "replace" then
        profile.importBackups = type(profile.importBackups) == "table" and profile.importBackups or {}
        local backupEntry = {
            revision = db.revision or 0,
            modules = snapshots,
        }
        profile.importBackups[#profile.importBackups + 1] = backupEntry
        while #profile.importBackups > 3 do
            table.remove(profile.importBackups, 1)
        end
    end
    for moduleName, nextList in pairs(nextLists) do
        local definition = PROFILE_IMPORT_DEFINITIONS[moduleName]
        alerts[definition.listName] = nextList
    end
    touchRevision(db)
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router and auraChanged then
        router.fire("EAM_AURA_CONFIG_CHANGED", db.revision)
    end
    if router and soundChanged then
        router.fire("EAM_AURA_SOUND_CHANGED", db.revision)
    end
    return true, "updated", report
end
function SavedVariables.removeAlert(kind, unit, spellID, itemID)
    local db = EAM.db
    if type(db) ~= "table" then
        return false, "dbUnavailable"
    end

    spellID = spellID and normalizePositiveInteger(spellID) or nil
    itemID = itemID and normalizePositiveInteger(itemID) or nil
    local list = getAlertList(db, kind, unit)
    if not list then
        return false, "invalidKind"
    end

    local id = buildAlertID(kind, unit, spellID, itemID)
    if not id then
        return false, "invalidID"
    end

    if not list[id] then
        return false, "notFound"
    end

    list[id] = nil
    touchRevision(db)
    if kind == EAM.Constants.ALERT_KIND_AURA and EAM.Modules.EventRouter then
        EAM.Modules.EventRouter.fire("EAM_AURA_CONFIG_CHANGED", db.revision)
    end
    return true, id, "removed"
end

function SavedVariables.addAuraAlert(unit, spellID, options)
    return SavedVariables.addAlert(EAM.Constants.ALERT_KIND_AURA, unit or "player", spellID, nil, options)
end

function SavedVariables.removeAuraAlert(unit, spellID)
    return SavedVariables.removeAlert(EAM.Constants.ALERT_KIND_AURA, unit or "player", spellID, nil)
end

function SavedVariables.addSpellCooldownAlert(spellID, options)
    return SavedVariables.addAlert(EAM.Constants.ALERT_KIND_SPELL_COOLDOWN, "player", spellID, nil, options)
end

function SavedVariables.removeSpellCooldownAlert(spellID)
    return SavedVariables.removeAlert(EAM.Constants.ALERT_KIND_SPELL_COOLDOWN, "player", spellID, nil)
end

function SavedVariables.addItemCooldownAlert(itemID, options)
    return SavedVariables.addAlert(EAM.Constants.ALERT_KIND_ITEM_COOLDOWN, nil, nil, itemID, options)
end

function SavedVariables.removeItemCooldownAlert(itemID)
    return SavedVariables.removeAlert(EAM.Constants.ALERT_KIND_ITEM_COOLDOWN, nil, nil, itemID)
end

function SavedVariables.addGroundEffectAlert(spellID, options)
    return SavedVariables.addAlert(EAM.Constants.ALERT_KIND_GROUND_EFFECT, "player", spellID, nil, options)
end

function SavedVariables.removeGroundEffectAlert(spellID)
    return SavedVariables.removeAlert(EAM.Constants.ALERT_KIND_GROUND_EFFECT, "player", spellID, nil)
end

function SavedVariables.updateGroundEffectAlert(spellID, durationMode, manualDuration)
    local numericID = normalizePositiveInteger(spellID)
    local list = getAlertList(EAM.db, EAM.Constants.ALERT_KIND_GROUND_EFFECT, "player")
    local id = numericID and buildAlertID(EAM.Constants.ALERT_KIND_GROUND_EFFECT, "player", numericID) or nil
    local alert = id and list and list[id] or nil
    if not alert then
        return false, "notFound"
    end

    local normalizedMode = normalizeGroundDurationMode(durationMode)
    local normalizedDuration = normalizeGroundDuration(manualDuration, 8)
    if alert.durationMode == normalizedMode and alert.manualDuration == normalizedDuration then
        return true, "unchanged"
    end
    alert.durationMode = normalizedMode
    alert.manualDuration = normalizedDuration
    touchRevision(EAM.db)
    return true, "updated", EAM.db.revision
end

function SavedVariables.updateConfigNumber(key, value)
    if key ~= "cooldownSwipeAlpha" or type(EAM.db) ~= "table" then
        return false, "invalidConfigKey"
    end
    local numberValue = type(value) == "number" and value or tonumber(value)
    if not EAM.Util.isSafeNumber(numberValue) then
        return false, "invalidConfigValue"
    end
    if numberValue < 0 then
        numberValue = 0
    elseif numberValue > 1 then
        numberValue = 1
    end
    if EAM.db.config[key] == numberValue then
        return true, "unchanged"
    end
    EAM.db.config[key] = numberValue
    touchRevision(EAM.db)
    return true, "updated", EAM.db.revision
end

function SavedVariables.updateConfigBoolean(key, value)
    if key ~= "nativeAuraDualCountdownProbe" or type(EAM.db) ~= "table" then
        return false, "invalidConfigKey"
    end
    local booleanValue = value == true
    if EAM.db.config[key] == booleanValue then
        return true, "unchanged"
    end
    EAM.db.config[key] = booleanValue
    touchRevision(EAM.db)
    return true, "updated", EAM.db.revision
end
