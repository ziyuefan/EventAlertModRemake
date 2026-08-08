--[[ EAM_FILE_COMMENTARY
Module: Managers/AuraRuleCompiler

責任:
- 將 SavedVariables 中可序列化的 Aura Alert 編譯為穩定 Runtime Rule。
- 只處理設定資料，不讀取 AuraData、不操作 UI、不執行戰鬥中結構修改。

資料邊界:
- Spell ID、unit、filter 與 stable key 只來自 EAM 設定。
- Runtime Frame、DurationObject 與 AuraContainer 絕不可寫回 SavedVariables。
]]

local _, EAM = ...
local Constants = EAM.Constants
local Util = EAM.Util

local AuraRuleCompiler = {}

EAM.Managers = EAM.Managers or {}
EAM.Managers.AuraRuleCompiler = AuraRuleCompiler

local SOUND_ASSETS = {
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

local function append(list, value)
    list[#list + 1] = value
end

local function appendLimitation(rule, code)
    append(rule.limitations, code)
end

local function sanitizeKey(value)
    return (string.gsub(value, "[^%w_]", "_"))
end
local function normalizeDispelMode(value)
    if value == "ALWAYS"
        or value == "HARMFUL"
        or value == "HELPFUL"
        or value == "ANY_DISPEL"
        or value == "NO_DISPEL"
        or value == "STEALABLE"
        or value == "NOT_STEALABLE"
    then
        return value
    end
    return nil
end

local function normalizeStealableFilter(value)
    if value == "STEALABLE" or value == "NOT_STEALABLE" then
        return value
    end
    return nil
end

local function normalizeDispelStyle(value)
    if value == "BORDER"
        or value == "BORDER_WITH_ICON"
        or value == "ICON"
        or value == "PRESERVE_ASSET"
        or value == "CUSTOM_ASSET"
    then
        return value
    end
    return nil
end

local function collectAlerts(db)
    local records = {}
    local alerts = db and db.alerts
    if type(alerts) ~= "table" then
        return records
    end

    local function collectUnit(list, unit)
        if type(list) ~= "table" then
            return
        end
        for id, alert in pairs(list) do
            if type(alert) == "table" and alert.enabled ~= false then
                local spellID = alert.spellID
                if Util.isSafePositiveNumber(spellID) and spellID % 1 == 0 then
                    append(records, {
                        alertID = Util.isSafeString(alert.id) and alert.id or tostring(id),
                        unit = unit,
                        spellID = spellID,
                        fromPlayer = alert.fromPlayer == true,
                        auraFilter = Util.isSafeString(alert.auraFilter) and alert.auraFilter or nil,
                        showStacks = alert.showStacks ~= false,
                        showName = alert.showName ~= false,
                        showCountdown = alert.showCountdown ~= false,
                        showPandemic = alert.showPandemic == true,
                        dispelMode = normalizeDispelMode(alert.dispelMode),
                        dispelShowAlways = alert.dispelShowAlways == true,
                        dispelStealableFilter = normalizeStealableFilter(alert.dispelStealableFilter),
                        dispelStyle = normalizeDispelStyle(alert.dispelStyle),
                        sound = type(alert.sound) == "table" and alert.sound or nil,
                    })
                end
            end
        end
    end

    collectUnit(alerts.playerAuras, "player")
    collectUnit(alerts.targetAuras, "target")
    table.sort(records, function(left, right)
        if left.unit == right.unit then
            if left.spellID == right.spellID then
                return left.alertID < right.alertID
            end
            return left.spellID < right.spellID
        end
        return left.unit < right.unit
    end)
    return records
end

local function resolveFilter(record, rule)
    local filter = record.auraFilter
    if filter ~= "HELPFUL" and filter ~= "HARMFUL" then
        filter = record.unit == "target" and "HARMFUL" or "HELPFUL"
        appendLimitation(rule, "auraFilterInferred")
    end

    if record.fromPlayer then
        return filter .. "|PLAYER", filter
    end
    return filter, filter
end

local function buildBaseRule(record, capability, defaultSound)
    local stableID = sanitizeKey(record.alertID)
    local rule = {
        alertID = record.alertID,
        unit = record.unit,
        spellID = record.spellID,
        backend = Constants.AURA_RULE_DISPLAY_UNSUPPORTED,
        slotKey = "EAM_SLOT_" .. stableID,
        filterString = nil,
        candidateFilters = {
            includeSpellIDs = {
                [record.spellID] = true,
            },
        },
        style = {
            showStacks = record.showStacks,
            showName = record.showName,
            showCountdown = record.showCountdown,
            showPandemic = record.showPandemic,
            dispelMode = record.dispelMode,
            dispelShowAlways = record.dispelShowAlways,
            dispelStealableFilter = record.dispelStealableFilter,
            dispelStyle = record.dispelStyle,
        },
        layout = capability.layout,
        sound = record.sound or defaultSound,
        limitations = {},
    }

    local polarity
    rule.filterString, polarity = resolveFilter(record, rule)
    if record.fromPlayer then
        rule.candidateFilters.isFromPlayerOrPlayerPet = true
    end

    local backend = capability.backend or capability.selectedBackend
    if backend == Constants.AURA_BACKEND_NATIVE then
        rule.backend = Constants.AURA_RULE_NATIVE_SLOT
        if record.unit == "player" and polarity == "HARMFUL" then
            appendLimitation(rule, "secretIdentityFilterMayBeRejected")
        elseif record.unit == "target" and polarity == "HELPFUL" then
            appendLimitation(rule, "secretIdentityFilterMayBeRejected")
        end
    elseif backend == Constants.AURA_BACKEND_LEGACY then
        rule.backend = Constants.AURA_RULE_READABLE_LEGACY
    else
        appendLimitation(rule, capability.reason or capability.limitationReason or "nativeAuraUnavailable")
    end

    if record.showStacks then
        appendLimitation(rule, "stackDisplayRequiresNativeAccess")
    end
    return rule
end

local function buildGroup(groupID, rules, layout)
    local first = rules[1]
    local spellIDs = {}
    local alertIDs = {}
    local limitations = {}
    for index = 1, #rules do
        local rule = rules[index]
        spellIDs[rule.spellID] = true
        append(alertIDs, rule.alertID)
        for limitationIndex = 1, #rule.limitations do
            append(limitations, rule.limitations[limitationIndex])
        end
    end

    return {
        alertID = table.concat(alertIDs, ","),
        alertIDs = alertIDs,
        backend = Constants.AURA_RULE_NATIVE_GROUP,
        unit = first.unit,
        groupKey = "EAM_GROUP_" .. sanitizeKey(groupID),
        filterString = first.filterString,
        candidateFilters = {
            includeSpellIDs = spellIDs,
            isFromPlayerOrPlayerPet = first.candidateFilters.isFromPlayerOrPlayerPet,
        },
        layout = layout,
        style = first.style,
        sound = nil,
        limitations = limitations,
    }
end

local function buildLayout(db)
    local config = db and db.config or nil
    local iconSize = config and config.iconSize or 40
    local spacing = config and config.iconSpacing or 6
    if not Util.isSafePositiveNumber(iconSize) then
        iconSize = 40
    end
    if not Util.isSafeNonNegativeNumber(spacing) then
        spacing = 6
    end
    return {
        elementWidth = iconSize,
        elementHeight = iconSize,
        elementSpacing = spacing,
        lineSpacing = spacing,
        groupSpacing = spacing,
        groupLineSpacing = spacing,
    }
end

local function buildFingerprint(plan)
    local parts = {
        tostring(plan.schemaVersion),
        tostring(plan.backend),
        tostring(plan.visualFingerprint or "-"),
        tostring(plan.layout.elementWidth),
        tostring(plan.layout.elementHeight),
        tostring(plan.layout.elementSpacing),
        tostring(plan.layout.lineSpacing),
        tostring(plan.layout.groupSpacing),
        tostring(plan.layout.groupLineSpacing),
    }
    for index = 1, #plan.rules do
        local rule = plan.rules[index]
        append(parts, rule.backend)
        append(parts, rule.unit)
        append(parts, rule.slotKey or rule.groupKey or "-")
        append(parts, rule.filterString or "-")
        append(parts, tostring(rule.style and rule.style.showStacks == true))
        append(parts, tostring(rule.style and rule.style.showName == true))
        append(parts, tostring(rule.style and rule.style.showCountdown == true))
        append(parts, tostring(rule.style and rule.style.showPandemic == true))
        append(parts, tostring(rule.style and rule.style.dispelMode or "-"))
        append(parts, tostring(rule.style and rule.style.dispelShowAlways == true))
        append(parts, tostring(rule.style and rule.style.dispelStealableFilter or "-"))
        append(parts, tostring(rule.style and rule.style.dispelStyle or "-"))
        if rule.spellID then
            append(parts, tostring(rule.spellID))
        elseif rule.alertIDs then
            for alertIndex = 1, #rule.alertIDs do
                append(parts, rule.alertIDs[alertIndex])
            end
        end
    end
    local soundKeys = { "added", "applicationsIncreased", "removed" }
    for index = 1, #plan.soundRules do
        local rule = plan.soundRules[index]
        append(parts, "sound:" .. rule.alertID)
        for keyIndex = 1, #soundKeys do
            local config = rule.sound and rule.sound[soundKeys[keyIndex]]
            if config then
                append(parts, soundKeys[keyIndex])
                append(parts, tostring(config.soundFileID or config.soundFileName or "-"))
                append(parts, tostring(config.outputChannel or "-"))
            end
        end
    end
    return table.concat(parts, "|")
end

local function buildVisualFingerprint(db)
    local config = db and db.config or nil
    local textLayout = config and config.textLayout or nil
    local timer = textLayout and textLayout.timer or nil
    local applications = textLayout and textLayout.applications or nil
    return table.concat({
        tostring(config and config.fontSizeSpellName or 12),
        tostring(timer and timer.placement or Constants.TEXT_PLACEMENT_TIMER_DEFAULT),
        tostring(timer and timer.fontSize or 14),
        tostring(applications and applications.placement or Constants.TEXT_PLACEMENT_APPLICATIONS_DEFAULT),
        tostring(applications and applications.fontSize or 12),
        tostring(config and config.cooldownSwipeAlpha or 1),
        tostring(config and config.nativeAuraDualCountdownProbe == true),
    }, ":")
end

local function buildDefaultSound(db)
    local config = db and db.config or nil
    if not config or config.showSound ~= true then
        return nil
    end
    local asset = SOUND_ASSETS[config.soundName or "ShayBell"] or SOUND_ASSETS.ShayBell
    local added = {}
    if type(asset) == "number" then
        added.soundFileID = asset
    else
        added.soundFileName = asset
    end
    return { added = added }
end

function AuraRuleCompiler.compile(db, capability)
    capability = capability or {
        backend = Constants.AURA_BACKEND_UNSUPPORTED,
        reason = "capabilityUnavailable",
    }
    local layout = buildLayout(db)
    capability.layout = layout
    local selectedBackend = capability.backend or capability.selectedBackend
    local plan = {
        schemaVersion = Constants.SCHEMA_VERSION,
        revision = db and db.revision or 0,
        backend = selectedBackend,
        layout = layout,
        rules = {},
        soundRules = {},
        limitations = {},
        visualFingerprint = buildVisualFingerprint(db),
        nativeSlotCount = 0,
        nativeGroupCount = 0,
        legacyCount = 0,
        unsupportedCount = 0,
    }

    local records = collectAlerts(db)
    local defaultSound = buildDefaultSound(db)
    local nativeRules = {}
    for index = 1, #records do
        local rule = buildBaseRule(records[index], capability, defaultSound)
        if rule.sound then
            append(plan.soundRules, rule)
        end
        if rule.backend == Constants.AURA_RULE_NATIVE_SLOT then
            append(nativeRules, rule)
        else
            append(plan.rules, rule)
            if rule.backend == Constants.AURA_RULE_READABLE_LEGACY then
                plan.legacyCount = plan.legacyCount + 1
            else
                plan.unsupportedCount = plan.unsupportedCount + 1
            end
        end
    end

    if selectedBackend == Constants.AURA_BACKEND_NATIVE then
        local slotsByUnit = {}
        local groups = {}
        for index = 1, #nativeRules do
            local rule = nativeRules[index]
            if not slotsByUnit[rule.unit] then
                slotsByUnit[rule.unit] = true
                append(plan.rules, rule)
                plan.nativeSlotCount = plan.nativeSlotCount + 1
            else
                local groupID = rule.unit
                    .. "_" .. rule.filterString
                    .. "_" .. tostring(rule.candidateFilters.isFromPlayerOrPlayerPet == true)
                    .. "_" .. tostring(rule.style.showStacks)
                    .. "_" .. tostring(rule.style.showName)
                    .. "_" .. tostring(rule.style.showCountdown)
                    .. "_" .. tostring(rule.style.showPandemic)
                    .. "_" .. tostring(rule.style.dispelMode or "-")
                    .. "_" .. tostring(rule.style.dispelShowAlways)
                    .. "_" .. tostring(rule.style.dispelStealableFilter or "-")
                    .. "_" .. tostring(rule.style.dispelStyle or "-")
                local group = groups[groupID]
                if not group then
                    group = {}
                    groups[groupID] = group
                end
                append(group, rule)
            end
        end
        local groupIDs = {}
        for groupID in pairs(groups) do
            append(groupIDs, groupID)
        end
        table.sort(groupIDs)
        for index = 1, #groupIDs do
            append(plan.rules, buildGroup(groupIDs[index], groups[groupIDs[index]], layout))
            plan.nativeGroupCount = plan.nativeGroupCount + 1
        end
    end

    plan.fingerprint = buildFingerprint(plan)
    return plan
end
