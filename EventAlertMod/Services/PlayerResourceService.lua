--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/PlayerResourceService
檔案: Services\PlayerResourceService.lua

責任:
- 依職業、專精、使用者設定與 12.1 runtime capability 編譯多資源 registry。
- 以 power token O(1) 分派 UNIT_POWER_UPDATE/FREQUENT/MAXPOWER。
- Numeric 資源可安全產生文字；Secret 資源只將 UnitPowerPercent 直送專屬 C 層 sink。

邊界:
- registry 只保存安全 metadata 與設定，不保存 current/max/percent。
- UNIT_DISPLAYPOWER 只更新 foreground metadata，不得刪除背景追蹤資源。
- 不使用每資源 OnUpdate／ticker；背景 sampler 僅在 Probe 明確標記事件不足且資源可見時共用排程。
]]
local _, EAM = ...

local api = EAM.API
local Util = EAM.Util
local Catalog = EAM.Data.PlayerResourceCatalog
local Capability = EAM.Services.PlayerResourceCapability
local ModuleController = EAM.Modules and EAM.Modules.ModuleController
local Scheduler = EAM.Modules and EAM.Modules.Scheduler

local PlayerResourceService = {
    initialized = false,
    eventsRegistered = false,
    registryByKey = {},
    registryByToken = {},
    registryByPowerType = {},
    orderedNodes = {},
    trackedResourceCount = 0,
    foregroundPowerType = nil,
    foregroundToken = nil,
    classToken = nil,
    specializationID = nil,
    pendingRebuild = false,
    rebuildCount = 0,
    dispatchCount = 0,
    ignoredEventCount = 0,
    nativeSinkWriteCount = 0,
    nativeSinkRejectCount = 0,
    numericUpdateCount = 0,
    secretDisplayUpdateCount = 0,
    unexpectedSecretFallbackCount = 0,
    unavailableUpdateCount = 0,
    runtimeRefreshCount = 0,
    lastResultClass = "uninitialized",
    lastConfigRevision = nil,
    lastConfigResourceKey = nil,
    lastConfigResult = "none",
    backgroundSamplingRequiredByKey = {},
    backgroundSamplerNodes = {},
    backgroundSamplerNodeCount = 0,
    backgroundSamplerRequestCount = 0,
    backgroundSamplerActive = false,
    backgroundSamplerDeferred = false,
    backgroundSamplerGeneration = 0,
    backgroundSamplerTickCount = 0,
    backgroundSamplerInterval = 0.5,
    backgroundSamplerLastReason = "notRequested",
    runeReadyByIndex = {},
    runeStateInitialized = false,
    runeReadyCount = 0,
    runeEventCount = 0,
    lastRuneResult = "uninitialized",
}

EAM.Services.PlayerResourceService = PlayerResourceService

local RUNE_SLOT_COUNT = 6

local function renderer()
    return EAM.UI and EAM.UI.PowerRenderer
end

local function savedVariables()
    return EAM.Modules and EAM.Modules.SavedVariables
end

local function moduleEnabled()
    return not ModuleController
        or ModuleController.isEnabled(EAM.Constants.MODULE_KEYS.classPower)
end

local function inCombat()
    return api.InCombatLockdown and api.InCombatLockdown() == true
end

local function getClassToken()
    if type(api.UnitClass) ~= "function" then
        return nil
    end
    local ok, _, classToken = pcall(api.UnitClass, "player")
    if ok and Util.isSafeString(classToken) and Catalog.ClassFallback[classToken] then
        return classToken
    end
    return nil
end

local function getSpecializationID()
    if type(api.GetSpecialization) ~= "function" or type(api.GetSpecializationInfo) ~= "function" then
        return nil
    end
    local okIndex, specializationIndex = pcall(api.GetSpecialization)
    if not okIndex or not Util.isSafePositiveNumber(specializationIndex) then
        return nil
    end
    local okInfo, specializationID = pcall(api.GetSpecializationInfo, specializationIndex)
    if okInfo and Util.isSafePositiveNumber(specializationID) then
        return specializationID
    end
    return nil
end

local function boundedNumber(value, fallback, minimum, maximum)
    if not Util.isSafeNumber(value) then
        return fallback
    end
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function resolveConfig(definition, specializationID, defaultOrder, savedOverride)
    local legacyEnabled = true
    local dbConfig = EAM.db and EAM.db.config
    if type(dbConfig) == "table" and definition.legacyConfigKey then
        legacyEnabled = dbConfig[definition.legacyConfigKey] ~= false
    end

    local saved = savedOverride
    if saved == nil then
        local sv = savedVariables()
        if sv and type(sv.getPlayerResourceConfig) == "function" then
            local ok, result = pcall(sv.getPlayerResourceConfig, definition.key, specializationID)
            if ok and type(result) == "table" then
                saved = result
            end
        end
    end

    local enabled = legacyEnabled
    if saved then
        enabled = saved.enabled ~= false
    end
    local displayMode = saved and saved.displayMode or "AUTO"
    if displayMode ~= "AUTO" and displayMode ~= "BAR" and displayMode ~= "POINTS" then
        displayMode = "AUTO"
    end

    return {
        enabled = enabled,
        displayMode = displayMode,
        anchor = saved and saved.anchor or "TOPLEFT",
        position = saved and saved.position or "TOPLEFT",
        showForeground = not saved or saved.showForeground ~= false,
        showBackground = not saved or saved.showBackground ~= false,
        showValue = not saved or saved.showValue ~= false,
        showPercent = saved and saved.showPercent == true or false,
        fullGlow = saved and saved.fullGlow == true or false,
        fontFamily = saved and saved.fontFamily
            or (EAM.Constants and EAM.Constants.FONT_FAMILY_DEFAULT or "STANDARD"),
        fontSize = boundedNumber(saved and saved.fontSize, 12, 8, 36),
        valueFontSize = boundedNumber(saved and saved.valueFontSize, 14, 8, 36),
        valueOffsetX = boundedNumber(saved and saved.valueOffsetX, 0, -100, 100),
        valueOffsetY = boundedNumber(saved and saved.valueOffsetY, 0, -100, 100),
        orientation = saved and saved.orientation == "VERTICAL"
            and "VERTICAL"
            or "HORIZONTAL",
        threshold = boundedNumber(saved and saved.threshold, 0.9, 0, 1),
        offsetX = boundedNumber(saved and saved.offsetX, 0, -2000, 2000),
        offsetY = boundedNumber(saved and saved.offsetY, 0, -2000, 2000),
        scale = boundedNumber(saved and saved.scale, 1, 0.25, 4),
        alpha = boundedNumber(saved and saved.alpha, 1, 0, 1),
        foregroundAlpha = boundedNumber(saved and saved.foregroundAlpha, 1, 0, 1),
        backgroundAlpha = boundedNumber(saved and saved.backgroundAlpha, 0.55, 0, 1),
        barWidth = boundedNumber(saved and saved.barWidth, 126, 64, 400),
        barHeight = boundedNumber(saved and saved.barHeight, 16, 8, 60),
        iconSize = boundedNumber(saved and saved.iconSize, 30, 16, 80),
        spacing = boundedNumber(saved and saved.spacing, 6, 0, 60),
        order = boundedNumber(saved and saved.order, defaultOrder, 1, Catalog.ResourceCount),
    }
end

local function clearRegistry()
    local draw = renderer()
    if draw and type(draw.hideAll) == "function" then
        draw.hideAll()
    end

    for key in pairs(PlayerResourceService.registryByKey) do
        PlayerResourceService.registryByKey[key] = nil
    end
    for token in pairs(PlayerResourceService.registryByToken) do
        PlayerResourceService.registryByToken[token] = nil
    end
    for powerType in pairs(PlayerResourceService.registryByPowerType) do
        PlayerResourceService.registryByPowerType[powerType] = nil
    end
    for index = 1, #PlayerResourceService.orderedNodes do
        PlayerResourceService.orderedNodes[index] = nil
    end
    for index = 1, RUNE_SLOT_COUNT do
        PlayerResourceService.runeReadyByIndex[index] = nil
    end
    PlayerResourceService.runeStateInitialized = false
    PlayerResourceService.runeReadyCount = 0
    PlayerResourceService.lastRuneResult = "registryCleared"
    PlayerResourceService.trackedResourceCount = 0
end

local function sortNodes(nodes)
    for index = 2, #nodes do
        local node = nodes[index]
        local cursor = index - 1
        while cursor >= 1 and nodes[cursor].config.order > node.config.order do
            nodes[cursor + 1] = nodes[cursor]
            cursor = cursor - 1
        end
        nodes[cursor + 1] = node
    end
end

local function updateForeground()
    local powerType = nil
    local token = nil
    if type(api.UnitPowerType) == "function" then
        local ok, currentType, currentToken = pcall(api.UnitPowerType, "player")
        if ok and Util.isSafeNonNegativeNumber(currentType) then
            powerType = currentType
        end
        if ok and Util.isSafeString(currentToken) then
            token = currentToken
        end
    end
    PlayerResourceService.foregroundPowerType = powerType
    PlayerResourceService.foregroundToken = token
    return powerType
end

local function isNodeForeground(node, foregroundPowerType)
    if node.definition.powerType == foregroundPowerType then
        return true
    end
    if not Catalog.ClassResourceKeys or Catalog.ClassResourceKeys[node.key] ~= true then
        return false
    end
    -- ComboPoints 只在 Energy 為主要資源時屬於前景；熊型態仍保留為背景追蹤。
    if node.key == "COMBO_POINTS" then
        local energyDefinition = Catalog.ByKey and Catalog.ByKey.ENERGY
        return energyDefinition ~= nil and foregroundPowerType == energyDefinition.powerType
    end
    return true
end

local function registerNode(node)
    PlayerResourceService.registryByKey[node.key] = node
    PlayerResourceService.registryByPowerType[node.definition.powerType] = node
    PlayerResourceService.registryByToken[node.definition.token] = node
    local count = PlayerResourceService.trackedResourceCount + 1
    PlayerResourceService.orderedNodes[count] = node
    PlayerResourceService.trackedResourceCount = count
end

local function readNumericValues(powerType)
    return api.UnitPower("player", powerType), api.UnitPowerMax("player", powerType)
end

local function readRuneSlot(runeIndex)
    if type(api.GetRuneCount) == "function" then
        local ok, count = pcall(api.GetRuneCount, runeIndex)
        if ok and Util.isSafeNonNegativeNumber(count) then
            return count > 0, "GetRuneCount"
        end
    end
    if type(api.GetRuneCooldown) == "function" then
        local ok, _, _, ready = pcall(api.GetRuneCooldown, runeIndex)
        if ok and Util.isSafeBoolean(ready) then
            return ready, "GetRuneCooldown"
        end
    end
    return nil, "runeSlotUnavailable"
end

local function resetRuneState(reason)
    for index = 1, RUNE_SLOT_COUNT do
        PlayerResourceService.runeReadyByIndex[index] = nil
    end
    PlayerResourceService.runeStateInitialized = false
    PlayerResourceService.runeReadyCount = 0
    PlayerResourceService.lastRuneResult = reason or "runeStateReset"
end

local function syncRuneState()
    local readyCount = 0
    for index = 1, RUNE_SLOT_COUNT do
        local ready, source = readRuneSlot(index)
        if ready == nil then
            resetRuneState(source)
            return false, source
        end
        PlayerResourceService.runeReadyByIndex[index] = ready
        if ready then
            readyCount = readyCount + 1
        end
    end
    PlayerResourceService.runeReadyCount = readyCount
    PlayerResourceService.runeStateInitialized = true
    PlayerResourceService.lastRuneResult = "runeStateSynchronized"
    return true, "runeStateSynchronized"
end

local function updateRunePoints(node)
    if not node or not node.numericSink then
        PlayerResourceService.unavailableUpdateCount = PlayerResourceService.unavailableUpdateCount + 1
        PlayerResourceService.lastRuneResult = "runeSinkUnavailable"
        return false, "runeSinkUnavailable"
    end
    if not PlayerResourceService.runeStateInitialized then
        local synchronized, reason = syncRuneState()
        if not synchronized then
            PlayerResourceService.unavailableUpdateCount = PlayerResourceService.unavailableUpdateCount + 1
            return false, reason
        end
    end

    local currentValue = PlayerResourceService.runeReadyCount
    local maximumValue = RUNE_SLOT_COUNT
    local percent = currentValue / maximumValue
    local rendered, reason = node.numericSink(
        node.key,
        node.definition.powerType,
        currentValue,
        maximumValue,
        percent,
        node.config.showValue,
        node.config.showPercent,
        node.config.fullGlow,
        node.config.threshold
    )
    if rendered then
        PlayerResourceService.nativeSinkWriteCount = PlayerResourceService.nativeSinkWriteCount + 1
        PlayerResourceService.numericUpdateCount = PlayerResourceService.numericUpdateCount + 1
        PlayerResourceService.lastRuneResult = "runePointsRendered"
    else
        PlayerResourceService.nativeSinkRejectCount = PlayerResourceService.nativeSinkRejectCount + 1
        PlayerResourceService.lastRuneResult = reason or "runeSinkRejected"
    end
    return rendered, reason
end

local function applyRuneEvent(node, runeIndex, added)
    if not Util.isSafePositiveNumber(runeIndex)
        or runeIndex % 1 ~= 0
        or runeIndex > RUNE_SLOT_COUNT
        or not Util.isSafeTableKey(runeIndex)
    then
        PlayerResourceService.ignoredEventCount = PlayerResourceService.ignoredEventCount + 1
        PlayerResourceService.lastRuneResult = "runeIndexUnsafe"
        return false, "runeIndexUnsafe"
    end

    if not PlayerResourceService.runeStateInitialized then
        local synchronized, reason = syncRuneState()
        if not synchronized then
            return false, reason
        end
    end

    local ready
    if Util.isSafeBoolean(added) then
        ready = added
    end
    if ready == nil then
        ready = readRuneSlot(runeIndex)
    end
    if ready == nil then
        PlayerResourceService.lastRuneResult = "runeStateUnsafe"
        return false, "runeStateUnsafe"
    end

    local previous = PlayerResourceService.runeReadyByIndex[runeIndex]
    PlayerResourceService.runeReadyByIndex[runeIndex] = ready
    if previous ~= ready then
        local count = 0
        for slot = 1, RUNE_SLOT_COUNT do
            if PlayerResourceService.runeReadyByIndex[slot] == true then
                count = count + 1
            end
        end
        PlayerResourceService.runeReadyCount = count
    end
    PlayerResourceService.runeEventCount = PlayerResourceService.runeEventCount + 1
    return updateRunePoints(node)
end

local function updateSecretDisplay(node)
    if not node.secretSource or node.curve == nil or not node.secretSink then
        PlayerResourceService.unavailableUpdateCount = PlayerResourceService.unavailableUpdateCount + 1
        return false, "secretSinkUnavailable"
    end

    local percent = node.secretSource(
        "player",
        node.definition.powerType,
        false,
        node.curve
    )

    local rendered, reason = node.secretSink(
        node.key,
        node.definition.powerType,
        percent
    )
    percent = nil
    if rendered then
        PlayerResourceService.nativeSinkWriteCount = PlayerResourceService.nativeSinkWriteCount + 1
        PlayerResourceService.secretDisplayUpdateCount = PlayerResourceService.secretDisplayUpdateCount + 1
    else
        PlayerResourceService.nativeSinkRejectCount = PlayerResourceService.nativeSinkRejectCount + 1
    end
    return rendered, reason
end

local function updateNumeric(node)
    -- NUMERIC capability 已在 cold path 驗證；戰鬥中直接讀取普通數字並送入自有 sink。
    -- 若能力在版本漂移後回傳 Secret/非數字，立即轉交原生百分比 sink；不保存、不索引、不序列化 raw value。
    -- 這是能力漂移時的 fail-closed 規格例外：不在熱事件重新 pcall，直接轉入 C 層安全 sink。

    if not node.numericSource or not node.numericSink then
        PlayerResourceService.unavailableUpdateCount = PlayerResourceService.unavailableUpdateCount + 1
        return false, "numericSourceUnavailable"
    end

    local currentValue, maximumValue = node.numericSource(node.definition.powerType)
    if not Util.isSafeNonNegativeNumber(currentValue)
        or not Util.isSafePositiveNumber(maximumValue)
    then
        currentValue = nil
        maximumValue = nil
        PlayerResourceService.unexpectedSecretFallbackCount =
            PlayerResourceService.unexpectedSecretFallbackCount + 1
        return updateSecretDisplay(node)
    end

    local percent = currentValue / maximumValue
    if not Util.isSafeNumber(percent) then
        currentValue = nil
        maximumValue = nil
        percent = nil
        PlayerResourceService.unavailableUpdateCount = PlayerResourceService.unavailableUpdateCount + 1
        return false, "numericPercentInvalid"
    end

    local rendered, reason = node.numericSink(
        node.key,
        node.definition.powerType,
        currentValue,
        maximumValue,
        percent,
        node.config.showValue,
        node.config.showPercent,
        node.config.fullGlow,
        node.config.threshold
    )
    currentValue = nil
    maximumValue = nil
    percent = nil
    if rendered then
        PlayerResourceService.nativeSinkWriteCount = PlayerResourceService.nativeSinkWriteCount + 1
        PlayerResourceService.numericUpdateCount = PlayerResourceService.numericUpdateCount + 1
    else
        PlayerResourceService.nativeSinkRejectCount = PlayerResourceService.nativeSinkRejectCount + 1
    end
    return rendered, reason
end

local function assignNodeUpdate(node)
    local draw = renderer()
    local curveConstants = api.CurveConstants
    node.secretSource = type(api.UnitPowerPercent) == "function" and api.UnitPowerPercent or nil
    node.secretSink = draw and type(draw.applySecretPercent) == "function"
        and draw.applySecretPercent or nil
    node.curve = curveConstants and curveConstants.ZeroToOne or nil
    node.numericSource = type(api.UnitPower) == "function" and type(api.UnitPowerMax) == "function"
        and readNumericValues or nil
    node.numericSink = draw and type(draw.applyNumeric) == "function" and draw.applyNumeric or nil
    if node.key == "RUNES"
        and (
            type(api.GetRuneCount) == "function"
            or type(api.GetRuneCooldown) == "function"
        )
        and node.numericSink
    then
        node.capability = Capability.NUMERIC
        node.capabilityReason = "runeSlotAPI"
        node.update = updateRunePoints
    elseif node.capability == Capability.NUMERIC then
        node.update = updateNumeric
    elseif node.capability == Capability.SECRET_DISPLAY then
        node.update = updateSecretDisplay
    else
        node.update = nil
    end
end

local function applyNodeVisualState(node)
    local draw = renderer()
    local available = node.capability ~= Capability.UNAVAILABLE
    if not draw or type(draw.setResourceState) ~= "function" then
        node.visible = false
        return false, "rendererStateUnavailable"
    end
    local visible, reason = draw.setResourceState(
        node.key,
        node.foreground == true,
        available
    )
    node.visible = visible == true
    return visible, reason
end

local function updateNode(node)
    if not node then
        return false, "resourceNotTracked"
    end
    if node.capability == Capability.UNAVAILABLE or type(node.update) ~= "function" then
        return false, "resourceUnavailable"
    end
    if node.visible == false then
        return false, "resourceHiddenByConfig"
    end
    return node.update(node)
end
local backgroundSamplerTick

local function stopBackgroundSampler(reason, clearRequirements)
    PlayerResourceService.backgroundSamplerGeneration =
        PlayerResourceService.backgroundSamplerGeneration + 1
    PlayerResourceService.backgroundSamplerActive = false
    PlayerResourceService.backgroundSamplerDeferred = false
    PlayerResourceService.backgroundSamplerLastReason = reason or "stopped"
    for index = 1, PlayerResourceService.backgroundSamplerNodeCount do
        PlayerResourceService.backgroundSamplerNodes[index] = nil
    end
    PlayerResourceService.backgroundSamplerNodeCount = 0
    if clearRequirements then
        for key in pairs(PlayerResourceService.backgroundSamplingRequiredByKey) do
            PlayerResourceService.backgroundSamplingRequiredByKey[key] = nil
        end
        PlayerResourceService.backgroundSamplerRequestCount = 0
    end
end

local function queueBackgroundSampler()
    if not PlayerResourceService.backgroundSamplerActive then
        return false, "samplerInactive"
    end
    if not Scheduler or type(Scheduler.after) ~= "function" then
        stopBackgroundSampler("schedulerUnavailable", false)
        return false, "schedulerUnavailable"
    end
    return Scheduler.after(
        PlayerResourceService.backgroundSamplerInterval,
        backgroundSamplerTick,
        PlayerResourceService.backgroundSamplerGeneration
    )
end

local function rebuildBackgroundSampler(reason)
    PlayerResourceService.backgroundSamplerGeneration =
        PlayerResourceService.backgroundSamplerGeneration + 1
    PlayerResourceService.backgroundSamplerActive = false
    PlayerResourceService.backgroundSamplerDeferred = false
    for index = 1, PlayerResourceService.backgroundSamplerNodeCount do
        PlayerResourceService.backgroundSamplerNodes[index] = nil
    end
    PlayerResourceService.backgroundSamplerNodeCount = 0
    if PlayerResourceService.backgroundSamplerRequestCount == 0 then
        PlayerResourceService.backgroundSamplerLastReason = "notRequested"
        return false, "notRequested"
    end
    if not moduleEnabled() then
        PlayerResourceService.backgroundSamplerLastReason = "moduleDisabled"
        return false, "moduleDisabled"
    end
    if inCombat() then
        PlayerResourceService.backgroundSamplerDeferred = true
        PlayerResourceService.backgroundSamplerLastReason = "combatSamplerDeferred"
        return false, "combatSamplerDeferred"
    end
    local count = 0
    for index = 1, PlayerResourceService.trackedResourceCount do
        local node = PlayerResourceService.orderedNodes[index]
        if PlayerResourceService.backgroundSamplingRequiredByKey[node.key] == true
            and node.foreground ~= true and node.visible ~= false
            and node.capability ~= Capability.UNAVAILABLE
        then
            count = count + 1
            PlayerResourceService.backgroundSamplerNodes[count] = node
        end
    end
    PlayerResourceService.backgroundSamplerNodeCount = count
    if count == 0 then
        PlayerResourceService.backgroundSamplerLastReason = "noEligibleBackgroundResource"
        return false, "noEligibleBackgroundResource"
    end
    PlayerResourceService.backgroundSamplerActive = true
    PlayerResourceService.backgroundSamplerLastReason = reason or "samplingRequired"
    return queueBackgroundSampler()
end

backgroundSamplerTick = function(generation)
    if generation ~= PlayerResourceService.backgroundSamplerGeneration
        or not PlayerResourceService.backgroundSamplerActive
    then
        return
    end
    if not moduleEnabled() then
        stopBackgroundSampler("moduleDisabled", true)
        return
    end
    if inCombat() then
        stopBackgroundSampler("combatSamplerDeferred", false)
        PlayerResourceService.backgroundSamplerDeferred = true
        return
    end
    for index = 1, PlayerResourceService.backgroundSamplerNodeCount do
        updateNode(PlayerResourceService.backgroundSamplerNodes[index])
    end
    PlayerResourceService.backgroundSamplerTickCount =
        PlayerResourceService.backgroundSamplerTickCount + 1
    queueBackgroundSampler()
end
local function refreshNodeCapability(node, updateAfterRefresh)

    local capability, capabilityReason = Capability.classify(node.definition)
    node.capability = capability
    node.capabilityReason = capabilityReason
    assignNodeUpdate(node)
    applyNodeVisualState(node)
    if updateAfterRefresh and node.capability ~= Capability.UNAVAILABLE then
        return updateNode(node)
    end
    return true, capabilityReason
end

-- 形態／主要資源切換只更新安全的 foreground metadata 與顯示角色。
-- 不在 UNIT_DISPLAYPOWER、UPDATE_SHAPESHIFT_FORM 或脫戰事件批量重讀所有資源；
-- 各資源數值仍由自身事件或 C 層 sink 驅動，避免治療／脫戰造成全清單重繪。
local function refreshForegroundState(reason)
    local foregroundPowerType = updateForeground()
    local foregroundChanged = false
    for index = 1, PlayerResourceService.trackedResourceCount do
        local node = PlayerResourceService.orderedNodes[index]
        local previousForeground = node.foreground == true
        local currentForeground = isNodeForeground(node, foregroundPowerType)
        node.foreground = currentForeground
        if previousForeground ~= currentForeground then
            foregroundChanged = true
        end
        -- setResourceState 只處理角色可見性與 alpha，不讀取資源數值。
        applyNodeVisualState(node)
    end
    PlayerResourceService.runtimeRefreshCount = PlayerResourceService.runtimeRefreshCount + 1
    PlayerResourceService.lastResultClass = reason or "foregroundStateRefreshed"
    -- foreground 變更可能改變背景取樣資格，但不重繪任何資源值。
    rebuildBackgroundSampler("foregroundStateRefreshed")
    return true, PlayerResourceService.lastResultClass, foregroundChanged
end

-- 設定面板開關只觸發視覺復原，不重建拓撲、不清除 registry，也不讀取原始資源值。
function PlayerResourceService.refreshVisualState(reason)
    if not moduleEnabled() then
        PlayerResourceService.lastResultClass = "moduleDisabled"
        return false, "moduleDisabled"
    end
    if inCombat() then
        PlayerResourceService.lastResultClass = "combatVisualRefreshDeferred"
        return false, "combatVisualRefreshDeferred"
    end
    local foregroundPowerType = updateForeground()
    local visibleCount = 0
    for index = 1, PlayerResourceService.trackedResourceCount do
        local node = PlayerResourceService.orderedNodes[index]
        node.foreground = isNodeForeground(node, foregroundPowerType)
        assignNodeUpdate(node)
        applyNodeVisualState(node)
        if node.visible == true then
            visibleCount = visibleCount + 1
            updateNode(node)
        end
    end
    PlayerResourceService.runtimeRefreshCount = PlayerResourceService.runtimeRefreshCount + 1
    PlayerResourceService.lastResultClass = reason or "visualStateRefreshed"
    rebuildBackgroundSampler("visualStateRefreshed")
    return visibleCount > 0, PlayerResourceService.lastResultClass
end

local function applyResourceConfigChange(resourceKey, effectiveConfig, specializationID)
    if not Util.isSafeString(resourceKey) or type(effectiveConfig) ~= "table" then
        return false, "topologyRequired"
    end
    if inCombat() then
        PlayerResourceService.pendingRebuild = true
        PlayerResourceService.lastResultClass = "combatRebuildDeferred"
        return false, "combatRebuildDeferred"
    end

    local node = PlayerResourceService.registryByKey[resourceKey]
    if not node or (specializationID and specializationID ~= PlayerResourceService.specializationID) then
        return false, "topologyRequired"
    end
    local draw = renderer()
    if not draw or type(draw.configureResource) ~= "function" then
        return false, "rendererUnavailable"
    end

    node.config = resolveConfig(
        node.definition,
        PlayerResourceService.specializationID,
        node.config and node.config.order or node.definition.defaultOrder,
        effectiveConfig
    )
    node.enabled = node.config.enabled == true
    local displayName = EAM.L and EAM.L[node.definition.nameKey]
        or node.definition.fallbackName
    local orderIndex = 1
    for index = 1, PlayerResourceService.trackedResourceCount do
        if PlayerResourceService.orderedNodes[index] == node then
            orderIndex = index
            break
        end
    end
    local configured, configureReason = draw.configureResource(
        node.definition,
        node.config,
        displayName,
        orderIndex
    )
    if not configured then
        return false, configureReason or "resourceConfigureFailed"
    end
    sortNodes(PlayerResourceService.orderedNodes)
    if type(draw.reflowResourceFrames) == "function" then
        local reflowed, reflowReason = draw.reflowResourceFrames(
            PlayerResourceService.orderedNodes,
            PlayerResourceService.trackedResourceCount
        )
        if reflowed == false then
            PlayerResourceService.lastResultClass = reflowReason or "resourceReflowFailed"
            return false, PlayerResourceService.lastResultClass
        end
    end
    local foregroundPowerType = PlayerResourceService.foregroundPowerType
    node.foreground = isNodeForeground(node, foregroundPowerType)
    assignNodeUpdate(node)
    applyNodeVisualState(node)
    updateNode(node)
    rebuildBackgroundSampler("configApplied")
    PlayerResourceService.lastResultClass = "configApplied"
    return true, "configApplied"
end

function PlayerResourceService.updateAll()
    if not moduleEnabled() then
        PlayerResourceService.lastResultClass = "moduleDisabled"
        return false, "moduleDisabled"
    end

    local wroteAny = false
    local lastReason = "noTrackedResources"
    for index = 1, PlayerResourceService.trackedResourceCount do
        local rendered, reason = updateNode(PlayerResourceService.orderedNodes[index])
        if rendered then
            wroteAny = true
        end
        lastReason = reason
    end
    PlayerResourceService.lastResultClass = lastReason
    return wroteAny, lastReason
end

function PlayerResourceService.rebuildTopology(reason)
    if not moduleEnabled() then
        stopBackgroundSampler("moduleDisabled", true)
        clearRegistry()
        PlayerResourceService.lastResultClass = "moduleDisabled"
        return false, "moduleDisabled"
    end
    if inCombat() then
        PlayerResourceService.pendingRebuild = true
        PlayerResourceService.lastResultClass = "combatRebuildDeferred"
        return false, "combatRebuildDeferred"
    end

    local draw = renderer()
    if not draw or type(draw.initialize) ~= "function" then
        return false, "rendererUnavailable"
    end
    local initialized, initializeReason = draw.initialize()
    if not initialized then
        return false, initializeReason
    end

    stopBackgroundSampler("topologyRebuilding", false)
    clearRegistry()
    local classToken = getClassToken()
    local specializationID = getSpecializationID()
    PlayerResourceService.classToken = classToken
    PlayerResourceService.specializationID = specializationID

    local resourceKeys = classToken and Catalog.getSpecResourceKeys(classToken, specializationID) or nil
    if not resourceKeys then
        PlayerResourceService.lastResultClass = "classTopologyUnavailable"
        return false, "classTopologyUnavailable"
    end

    local candidates = {}
    for index = 1, #resourceKeys do
        local definition = Catalog.getDefinition(resourceKeys[index])
        if definition then
            -- Tracked topology 與使用者 enabled 狀態分離；停用資源仍保留
            -- registry/frame ownership，避免形態或設定切換時遺失事件與 frame。
            local config = resolveConfig(definition, specializationID, index)
            local capability, capabilityReason = Capability.classify(definition)
            candidates[#candidates + 1] = {
                key = definition.key,
                definition = definition,
                config = config,
                tracked = true,
                enabled = config.enabled == true,
                capability = capability,
                capabilityReason = capabilityReason,
                foreground = false,
                visible = false,
                update = nil,
            }
        end
    end

    sortNodes(candidates)
    for index = 1, #candidates do
        local node = candidates[index]
        local displayName = EAM.L and EAM.L[node.definition.nameKey]
            or node.definition.fallbackName
        local configured = draw.configureResource(
            node.definition,
            node.config,
            displayName,
            index
        )
        if configured then
            registerNode(node)
        end
    end

    local foregroundPowerType = updateForeground()
    for index = 1, PlayerResourceService.trackedResourceCount do
        local node = PlayerResourceService.orderedNodes[index]
        node.foreground = isNodeForeground(node, foregroundPowerType)
        assignNodeUpdate(node)
        applyNodeVisualState(node)
    end

    PlayerResourceService.pendingRebuild = false
    PlayerResourceService.rebuildCount = PlayerResourceService.rebuildCount + 1
    local topologyResult = PlayerResourceService.trackedResourceCount > 0
        and "topologyReady"
        or "noAvailableResources"
    PlayerResourceService.lastResultClass = topologyResult
    PlayerResourceService.updateAll()
    rebuildBackgroundSampler("topologyRebuilt")
    -- updateAll 的細節結果不應覆寫設定事件的 topology 套用結果。
    PlayerResourceService.lastResultClass = topologyResult
    return PlayerResourceService.trackedResourceCount > 0, topologyResult
end

local function updateByToken(unit, powerToken)
    if unit ~= "player" then
        PlayerResourceService.ignoredEventCount = PlayerResourceService.ignoredEventCount + 1
        return false, "unitIgnored"
    end
    if not Util.isSafeString(powerToken) then
        PlayerResourceService.ignoredEventCount = PlayerResourceService.ignoredEventCount + 1
        return false, "powerTokenUnsafe"
    end
    local node = PlayerResourceService.registryByToken[powerToken]
    if not node then
        PlayerResourceService.ignoredEventCount = PlayerResourceService.ignoredEventCount + 1
        return false, "powerTokenNotTracked"
    end
    PlayerResourceService.dispatchCount = PlayerResourceService.dispatchCount + 1
    local rendered, reason = updateNode(node)
    PlayerResourceService.lastResultClass = reason
    return rendered, reason
end

function PlayerResourceService.onEvent(eventName, unit, powerToken, revision, specializationID)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end

    if eventName == "EAM_PLAYER_RESOURCE_CONFIG_CHANGED" then
        local applied, result = applyResourceConfigChange(unit, powerToken, specializationID)
        PlayerResourceService.lastConfigRevision = revision
        PlayerResourceService.lastConfigResourceKey = unit
        if result ~= "topologyRequired" then
            PlayerResourceService.lastConfigResult = result or (applied and "configApplied" or "configDeferred")
            return applied, result
        end
        local rebuilt, rebuiltResult = PlayerResourceService.rebuildTopology("configChanged")
        PlayerResourceService.lastConfigResult = rebuiltResult or (rebuilt and "configApplied" or "configDeferred")
        if rebuiltResult == "combatRebuildDeferred" then
            return false, rebuiltResult
        end
        return rebuilt, rebuiltResult
    end

    if eventName == "UNIT_POWER_UPDATE" or eventName == "UNIT_POWER_FREQUENT" then
        return updateByToken(unit, powerToken)
    end

    if eventName == "UNIT_MAXPOWER" then
        if unit ~= "player" or not Util.isSafeString(powerToken) then
            return false, "unitOrTokenIgnored"
        end
        local node = PlayerResourceService.registryByToken[powerToken]
        if not node then
            -- 候選拓樸已於登入/專精重建時預熱；資源事件不得要求全域重建。
            PlayerResourceService.ignoredEventCount = PlayerResourceService.ignoredEventCount + 1
            return false, "powerTokenNotTracked"
        end
        PlayerResourceService.dispatchCount = PlayerResourceService.dispatchCount + 1
        return refreshNodeCapability(node, true)
    end

    if eventName == "RUNE_POWER_UPDATE" then
        local runeNode = PlayerResourceService.registryByKey.RUNES
        if not runeNode then
            PlayerResourceService.ignoredEventCount = PlayerResourceService.ignoredEventCount + 1
            return false, "runesNotTracked"
        end
        PlayerResourceService.dispatchCount = PlayerResourceService.dispatchCount + 1
        return applyRuneEvent(runeNode, unit, powerToken)
    end

    if eventName == "UNIT_DISPLAYPOWER" then
        if unit and unit ~= "player" then
            return false, "unitIgnored"
        end
        return refreshForegroundState("foregroundUpdated")
    end

    if eventName == "UPDATE_SHAPESHIFT_FORM" then
        return refreshForegroundState("formForegroundUpdated")
    end

    if eventName == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
        return false, "unitIgnored"
    end

    if eventName == "PLAYER_REGEN_ENABLED" and not PlayerResourceService.pendingRebuild then
        return refreshForegroundState("combatEndedForegroundRefreshed")
    end

    return PlayerResourceService.rebuildTopology(eventName)
end
local function registerServiceEvents()
    if PlayerResourceService.eventsRegistered then
        return true, "unchanged"
    end
    local router = EAM.Modules.EventRouter
    if not router or type(router.register) ~= "function" then
        return false, "eventRouterUnavailable"
    end
    router.register("UNIT_POWER_UPDATE", PlayerResourceService.onEvent)
    router.register("UNIT_POWER_FREQUENT", PlayerResourceService.onEvent)
    router.register("UNIT_MAXPOWER", PlayerResourceService.onEvent)
    router.register("RUNE_POWER_UPDATE", PlayerResourceService.onEvent)
    router.register("UNIT_DISPLAYPOWER", PlayerResourceService.onEvent)
    router.register("PLAYER_ENTERING_WORLD", PlayerResourceService.onEvent)
    router.register("UPDATE_SHAPESHIFT_FORM", PlayerResourceService.onEvent)
    router.register("PLAYER_TALENT_UPDATE", PlayerResourceService.onEvent)
    router.register("PLAYER_SPECIALIZATION_CHANGED", PlayerResourceService.onEvent)
    router.register("ACTIVE_TALENT_GROUP_CHANGED", PlayerResourceService.onEvent)
    router.register("TRAIT_CONFIG_UPDATED", PlayerResourceService.onEvent)
    router.register("PLAYER_REGEN_ENABLED", PlayerResourceService.onEvent)
    router.register("EAM_PLAYER_RESOURCE_CONFIG_CHANGED", PlayerResourceService.onEvent)
    router.register("EAM_LANGUAGE_CHANGED", PlayerResourceService.onEvent)
    PlayerResourceService.eventsRegistered = true
    return true, "registered"
end

local function unregisterServiceEvents()
    if not PlayerResourceService.eventsRegistered then
        return true, "unchanged"
    end
    local router = EAM.Modules.EventRouter
    if not router or type(router.unregister) ~= "function" then
        return false, "eventRouterUnavailable"
    end
    router.unregister("UNIT_POWER_UPDATE", PlayerResourceService.onEvent)
    router.unregister("UNIT_POWER_FREQUENT", PlayerResourceService.onEvent)
    router.unregister("UNIT_MAXPOWER", PlayerResourceService.onEvent)
    router.unregister("RUNE_POWER_UPDATE", PlayerResourceService.onEvent)
    router.unregister("UNIT_DISPLAYPOWER", PlayerResourceService.onEvent)
    router.unregister("PLAYER_ENTERING_WORLD", PlayerResourceService.onEvent)
    router.unregister("UPDATE_SHAPESHIFT_FORM", PlayerResourceService.onEvent)
    router.unregister("PLAYER_TALENT_UPDATE", PlayerResourceService.onEvent)
    router.unregister("PLAYER_SPECIALIZATION_CHANGED", PlayerResourceService.onEvent)
    router.unregister("ACTIVE_TALENT_GROUP_CHANGED", PlayerResourceService.onEvent)
    router.unregister("TRAIT_CONFIG_UPDATED", PlayerResourceService.onEvent)
    router.unregister("PLAYER_REGEN_ENABLED", PlayerResourceService.onEvent)
    router.unregister("EAM_PLAYER_RESOURCE_CONFIG_CHANGED", PlayerResourceService.onEvent)
    router.unregister("EAM_LANGUAGE_CHANGED", PlayerResourceService.onEvent)
    PlayerResourceService.eventsRegistered = false
    return true, "unregistered"
end

function PlayerResourceService.onModuleToggle(enabled)
    if enabled == false then
        PlayerResourceService.pendingRebuild = false
        stopBackgroundSampler("moduleDisabled", true)
        local probe = EAM.Debug and EAM.Debug.PlayerResourceProbe
        if probe and type(probe.isActive) == "function" and probe.isActive()
            and type(probe.stop) == "function"
        then
            probe.stop()
        end
        unregisterServiceEvents()
        clearRegistry()
        PlayerResourceService.lastResultClass = "moduleDisabled"
        return true, "disabled"
    end
    local registered, reason = registerServiceEvents()
    if not registered then
        return false, reason
    end
    return PlayerResourceService.rebuildTopology("moduleEnabled")
end

function PlayerResourceService.isTracked(resourceKeyOrPowerType)
    local node = type(resourceKeyOrPowerType) == "number"
        and PlayerResourceService.registryByPowerType[resourceKeyOrPowerType]
        or PlayerResourceService.registryByKey[resourceKeyOrPowerType]
    return node ~= nil
end

function PlayerResourceService.isForeground(resourceKeyOrPowerType)
    local node = type(resourceKeyOrPowerType) == "number"
        and PlayerResourceService.registryByPowerType[resourceKeyOrPowerType]
        or PlayerResourceService.registryByKey[resourceKeyOrPowerType]
    return node ~= nil and node.foreground == true
end

function PlayerResourceService.getCapability(resourceKeyOrPowerType)
    local node = type(resourceKeyOrPowerType) == "number"
        and PlayerResourceService.registryByPowerType[resourceKeyOrPowerType]
        or PlayerResourceService.registryByKey[resourceKeyOrPowerType]
    if not node then
        return Capability.UNAVAILABLE
    end
    return node.capability
end
function PlayerResourceService.getTrackedResourceCount()
    return PlayerResourceService.trackedResourceCount
end

function PlayerResourceService.getTrackedResourceKeys()
    local keys = {}
    for index = 1, PlayerResourceService.trackedResourceCount do
        keys[index] = PlayerResourceService.orderedNodes[index].key
    end
    return keys
end

function PlayerResourceService.getForegroundPowerType()
    return PlayerResourceService.foregroundPowerType
end

function PlayerResourceService.getForegroundToken()
    return PlayerResourceService.foregroundToken
end

-- 舊 API 名稱保留為相容別名；語意只代表 foreground metadata，不代表唯一追蹤資源。
function PlayerResourceService.getActivePowerType()
    return PlayerResourceService.getForegroundPowerType()
end

function PlayerResourceService.getSupportedPowerTypeCount()
    return Catalog.ResourceCount
end

function PlayerResourceService.isSupportedPowerType(powerType)
    return Catalog.ByPowerType[powerType] ~= nil
end

function PlayerResourceService.setBackgroundSamplingRequired(resourceKey, required)
    if not Util.isSafeString(resourceKey) then
        return false, "resourceKeyUnsafe"
    end
    local node = PlayerResourceService.registryByKey[resourceKey]
    if required == true then
        if not node or node.tracked ~= true or node.foreground == true
            or node.visible == false or node.capability == Capability.UNAVAILABLE
        then
            return false, "resourceNotEligibleForBackgroundSampling"
        end
        if PlayerResourceService.backgroundSamplingRequiredByKey[resourceKey] == true then
            return true, "unchanged"
        end
        PlayerResourceService.backgroundSamplingRequiredByKey[resourceKey] = true
        PlayerResourceService.backgroundSamplerRequestCount =
            PlayerResourceService.backgroundSamplerRequestCount + 1
        return rebuildBackgroundSampler("probeConfirmedMissingEvent")
    end
    if PlayerResourceService.backgroundSamplingRequiredByKey[resourceKey] ~= true then
        return true, "unchanged"
    end
    PlayerResourceService.backgroundSamplingRequiredByKey[resourceKey] = nil
    PlayerResourceService.backgroundSamplerRequestCount =
        PlayerResourceService.backgroundSamplerRequestCount - 1
    return rebuildBackgroundSampler("eventObserved")
end

function PlayerResourceService.clearBackgroundSamplingRequirements()
    stopBackgroundSampler("requirementsCleared", true)
    return true, "requirementsCleared"
end
function PlayerResourceService.getStatus()
    local resources = {}
    for index = 1, PlayerResourceService.trackedResourceCount do
        local node = PlayerResourceService.orderedNodes[index]
        resources[index] = {
            key = node.key,
            powerType = node.definition.powerType,
            token = node.definition.token,
            capability = node.capability,
            capabilityReason = node.capabilityReason,
            tracked = node.tracked == true,
            enabled = node.config and node.config.enabled == true or false,
            available = node.capability ~= Capability.UNAVAILABLE,
            foreground = node.foreground == true,
            background = node.foreground ~= true,
            backgroundSamplingRequired =
                PlayerResourceService.backgroundSamplingRequiredByKey[node.key] == true,
        }
    end
    return {
        active = PlayerResourceService.trackedResourceCount > 0,
        foregroundPowerType = PlayerResourceService.foregroundPowerType,
        foregroundToken = PlayerResourceService.foregroundToken,
        -- 舊報告欄位保留；不得將其解讀成單一資源 topology。
        activePowerType = PlayerResourceService.foregroundPowerType,
        activePowerToken = PlayerResourceService.foregroundToken,
        classToken = PlayerResourceService.classToken,
        specializationID = PlayerResourceService.specializationID,
        trackedResourceCount = PlayerResourceService.trackedResourceCount,
        resources = resources,
        pendingRebuild = PlayerResourceService.pendingRebuild,
        eventsRegistered = PlayerResourceService.eventsRegistered,
        backgroundSamplerActive = PlayerResourceService.backgroundSamplerActive,
        backgroundSamplerDeferred = PlayerResourceService.backgroundSamplerDeferred,
        backgroundSamplerNodeCount = PlayerResourceService.backgroundSamplerNodeCount,
        backgroundSamplerRequestCount = PlayerResourceService.backgroundSamplerRequestCount,
        backgroundSamplerTickCount = PlayerResourceService.backgroundSamplerTickCount,
        backgroundSamplerInterval = PlayerResourceService.backgroundSamplerInterval,
        backgroundSamplerLastReason = PlayerResourceService.backgroundSamplerLastReason,
        runeStateInitialized = PlayerResourceService.runeStateInitialized,
        runeReadyCount = PlayerResourceService.runeReadyCount,
        runeEventCount = PlayerResourceService.runeEventCount,
        lastRuneResult = PlayerResourceService.lastRuneResult,
        runeSlotAPIAvailable = type(api.GetRuneCount) == "function"
            or type(api.GetRuneCooldown) == "function",
        rebuildCount = PlayerResourceService.rebuildCount,
        dispatchCount = PlayerResourceService.dispatchCount,
        ignoredEventCount = PlayerResourceService.ignoredEventCount,
        nativeSinkWriteCount = PlayerResourceService.nativeSinkWriteCount,
        nativeSinkRejectCount = PlayerResourceService.nativeSinkRejectCount,
        numericUpdateCount = PlayerResourceService.numericUpdateCount,
        secretDisplayUpdateCount = PlayerResourceService.secretDisplayUpdateCount,
        unexpectedSecretFallbackCount = PlayerResourceService.unexpectedSecretFallbackCount,
        unavailableUpdateCount = PlayerResourceService.unavailableUpdateCount,
        runtimeRefreshCount = PlayerResourceService.runtimeRefreshCount,
        lastResultClass = PlayerResourceService.lastResultClass,
        lastConfigRevision = PlayerResourceService.lastConfigRevision,
        lastConfigResourceKey = PlayerResourceService.lastConfigResourceKey,
        lastConfigResult = PlayerResourceService.lastConfigResult,
        supportedPowerTypeCount = Catalog.ResourceCount,
        rawValuesExposed = false,
    }
end

PlayerResourceService.detectClassPower = PlayerResourceService.rebuildTopology
PlayerResourceService.updatePower = PlayerResourceService.updateAll

function PlayerResourceService.initialize()
    if PlayerResourceService.initialized then
        return true, "unchanged"
    end
    PlayerResourceService.initialized = true

    if moduleEnabled() then
        local registered, reason = registerServiceEvents()
        if not registered then
            return false, reason
        end
    end

    return PlayerResourceService.rebuildTopology("initialize")
end