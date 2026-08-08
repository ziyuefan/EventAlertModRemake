--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Core/SavedVariables
檔案: Core\SavedVariables.lua

理念:
- 用版本化 schema 接管舊 EAM SavedVariables，讓重寫可穩定 migration。
- SavedVariables 只保存設定，不保存 runtime facts。

責任:
- 初始化 EAM_DB、保存 defaults、執行舊 EA_* migration、提供 alert add/remove mutation API。

資料所有權:
- 擁有 EAM_DB schema 與 persistent config 的唯一寫入入口。

可變狀態:
- 只在載入、migration、使用者設定變更時寫入。
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
    alerts = {
        playerAuras = {},
        targetAuras = {},
        spellCooldowns = {},
        itemCooldowns = {},
        groundEffects = {}, -- 新增地面效果配置
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
        auraBackend = "AUTO",
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

local function normalizeGroundEffects(db, appendWarnings)
    local alerts = type(db.alerts) == "table" and db.alerts or {}
    db.alerts = alerts
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

local MIGRATIONS = {
    [1] = migrateV1ToV2,
    [2] = migrateV2ToV3,
    [3] = migrateV3ToV4,
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
    return mathFloor(numberValue)
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

local function getAlertList(db, kind, unit)
    if not db then
        return nil
    end

    local alerts = ensureTable(db, "alerts")
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
    local _, playerClass = UnitClass and UnitClass("player")
    playerClass = playerClass or "OTHER"

    local alerts = ensureTable(db, "alerts")
    local playerAuras = ensureTable(alerts, "playerAuras")
    local targetAuras = ensureTable(alerts, "targetAuras")
    local spellCooldowns = ensureTable(alerts, "spellCooldowns")

    local imported, skipped
    if type(EA_Items) == "table" then
        imported, skipped = importSpellTable(playerAuras, EA_Items[playerClass], "aura", "player", "EA_Items")
        report.imported = report.imported + imported
        report.skipped = report.skipped + skipped
        imported, skipped = importSpellTable(playerAuras, EA_Items.OTHER, "aura", "player", "EA_Items")
        report.imported = report.imported + imported
        report.skipped = report.skipped + skipped
    end

    if type(EA_AltItems) == "table" then
        imported, skipped = importSpellTable(playerAuras, EA_AltItems[playerClass], "aura", "player", "EA_AltItems")
        report.imported = report.imported + imported
        report.skipped = report.skipped + skipped
    end

    if type(EA_TarItems) == "table" then
        imported, skipped = importSpellTable(targetAuras, EA_TarItems[playerClass], "aura", "target", "EA_TarItems")
        report.imported = report.imported + imported
        report.skipped = report.skipped + skipped
    end

    if type(EA_ScdItems) == "table" then
        imported, skipped = importSpellTable(spellCooldowns, EA_ScdItems[playerClass], "spellCooldown", "player", "EA_ScdItems")
        report.imported = report.imported + imported
        report.skipped = report.skipped + skipped
    end
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
        return runtimeDB
    end

    copyMissingDefaults(EAM_DB, defaults)
    normalizeTextLayout(EAM_DB, false)
    normalizeGroundEffects(EAM_DB, false)

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

    EAM.db = EAM_DB

    -- 🛡️ 載入預設監控法術 (全新安裝或無 WTF 檔案時之防空機制)
    if EAM_DB.alerts then
        local count = 0
        for _ in pairs(EAM_DB.alerts.playerAuras) do count = count + 1 break end
        for _ in pairs(EAM_DB.alerts.targetAuras) do count = count + 1 break end
        for _ in pairs(EAM_DB.alerts.spellCooldowns) do count = count + 1 break end
        for _ in pairs(EAM_DB.alerts.itemCooldowns) do count = count + 1 break end
        
        if count == 0 then
            local _, classToken = UnitClass("player")
            local spellArray = EAM.Data and EAM.Data.SpellArray
            local classData = classToken and spellArray and spellArray[classToken]
            if classData then
                -- 導入 general 預設法術
                if classData.general then
                    for _, sp in ipairs(classData.general) do
                        if sp.type == "aura" or sp.type == "spellCooldown" or sp.type == "itemCooldown" or sp.type == "groundEffect" then
                            SavedVariables.addAlert(sp.type, sp.unit, sp.id, nil)
                        end
                    end
                end
                -- 導入各專精預設法術
                for specIdx = 1, 4 do
                    local specList = classData[specIdx]
                    if specList then
                        for _, sp in ipairs(specList) do
                            if sp.type == "aura" or sp.type == "spellCooldown" or sp.type == "itemCooldown" or sp.type == "groundEffect" then
                                SavedVariables.addAlert(sp.type, sp.unit, sp.id, nil)
                            end
                        end
                    end
                end
            end
        end
    end

    return EAM_DB
end

function SavedVariables.buildAlertID(kind, unit, spellID, itemID)
    return buildAlertID(kind, unit, spellID, itemID)
end

function SavedVariables.getAlertList(kind, unit)
    return getAlertList(EAM.db, kind, unit)
end

function SavedVariables.markRevisionChanged()
    if type(EAM.db) ~= "table" then
        return false
    end
    touchRevision(EAM.db)
    return true, EAM.db.revision
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
            if options.sound ~= nil then
                local sound = copySerializable(options.sound)
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
        sound = kind == EAM.Constants.ALERT_KIND_AURA and options and copySerializable(options.sound) or nil,
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
