--[[ EAM_FILE_COMMENTARY
Module: Services/AuraContainerService

責任:
- 只在非戰鬥建立 player/target AuraContainer，套用 AuraSlot/AuraGroup 規則。
- 戰鬥中設定變更只記錄 pending，PLAYER_REGEN_ENABLED 後批次重建一次。

邊界:
- Native Aura 不建立 AuraState，不註冊 UNIT_AURA，不進入 AlertManager/Renderer。
- 公開 API 無 RemoveAuraSlot/RemoveAuraGroup；規則刪除以停用舊容器並重建處理。
]]

local _, EAM = ...
local api = EAM.API
local Constants = EAM.Constants

local AuraContainerService = {
    initialized = false,
    pending = false,
    pendingRevision = nil,
    current = nil,
    createdContainerCount = 0,
    maxCreatedContainerCount = 18,
    retiredContainerCount = 0,
    reloadRequired = false,
    rebuildCount = 0,
    failedRebuildCount = 0,
    settingsDirty = false,
    lastPlan = nil,
    lastReason = nil,
}

EAM.Services.AuraContainerService = AuraContainerService

local function inCombat()
    return api.InCombatLockdown and api.InCombatLockdown() == true
end

local function disableContainer(container)
    if not container then
        return
    end
    if container.SetEnabled then
        container:SetEnabled(false)
    end
    if container.Hide then
        container:Hide()
    end
end

local function retireContainers(containers)
    if not containers then
        return
    end
    disableContainer(containers.player)
    disableContainer(containers.target)
    AuraContainerService.retiredContainerCount = AuraContainerService.retiredContainerCount + 2
end

local function createContainer()
    if not api.CreateFrame then
        return nil, "createFrameUnavailable"
    end
    if AuraContainerService.createdContainerCount >= AuraContainerService.maxCreatedContainerCount then
        AuraContainerService.reloadRequired = true
        return nil, "nativeReloadRequired"
    end
    local ok, container = pcall(api.CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if not ok or not container then
        return nil, "nativeContainerCreationFailed"
    end
    AuraContainerService.createdContainerCount = AuraContainerService.createdContainerCount + 1
    return container
end

local function buildCommonOptions(rule, container, slotIndex)
    local options = {
        templateNames = { "CustomAuraButtonTemplate" },
        initializeFrame = EAM.UI.NativeAuraRenderer.createInitializer(rule, container, slotIndex),
        candidateFilters = rule.candidateFilters,
    }
    if AuraContainerSortMethod and AuraContainerSortMethod.Default ~= nil then
        options.sortMethod = AuraContainerSortMethod.Default
    end
    if AuraContainerSortDirection and AuraContainerSortDirection.Normal ~= nil then
        options.sortDirection = AuraContainerSortDirection.Normal
    end
    return options
end

local function setFlowLayoutPadding(container, left, right, top, bottom)
    local ok, method = pcall(function()
        return container.SetFlowLayoutPadding
    end)
    if not ok or type(method) ~= "function" then
        return false
    end
    local applied = pcall(method, container, left, right, top, bottom)
    return applied == true
end

local function configureContainer(container, unit, plan)
    container:SetEnabled(false)
    local moduleController = EAM.Modules and EAM.Modules.ModuleController
    if moduleController and not moduleController.isAuraUnitEnabled(unit) then
        if container.Hide then
            container:Hide()
        end
        return
    end
    container:SetUnit(unit)

    local layout = nil
    local slotIndex = 0
    for index = 1, #plan.rules do
        local rule = plan.rules[index]
        if rule.unit == unit and rule.backend == Constants.AURA_RULE_NATIVE_SLOT then
            slotIndex = slotIndex + 1
            local options = buildCommonOptions(rule, container, slotIndex)
            container:AddAuraSlot(rule.slotKey, rule.filterString, options)
        elseif rule.unit == unit and rule.backend == Constants.AURA_RULE_NATIVE_GROUP then
            local options = buildCommonOptions(rule, container, nil)
            options.maxFrameCount = #rule.alertIDs
            options.layout = rule.layout
            container:AddAuraGroup(rule.groupKey, rule.filterString, options)
            container:SetAuraGroupLayout(rule.groupKey, rule.layout)
            layout = rule.layout
        end
    end

    local slotPadding = slotIndex * ((plan.layout and plan.layout.elementWidth or 40) + (plan.layout and plan.layout.elementSpacing or 6))
    setFlowLayoutPadding(container, slotPadding, 0, 0, 0)

    layout = layout or {
        elementWidth = EAM.db and EAM.db.config and EAM.db.config.iconSize or 40,
        elementHeight = EAM.db and EAM.db.config and EAM.db.config.iconSize or 40,
        elementSpacing = EAM.db and EAM.db.config and EAM.db.config.iconSpacing or 6,
    }
    container:SetSize((layout.elementWidth + layout.elementSpacing) * 10, layout.elementHeight * 2)
    container:ClearAllPoints()
    if unit == "player" then
        container:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    else
        container:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
    container:SetEnabled(true)
    container:Show()
end

local function buildNativeContainers(plan, probeContainer)
    local containers = {
        player = probeContainer,
        target = nil,
    }
    if not containers.player then
        local reason
        containers.player, reason = createContainer()
        if not containers.player then
            return nil, reason
        end
    end

    local reason
    containers.target, reason = createContainer()
    if not containers.target then
        disableContainer(containers.player)
        return nil, reason
    end

    local ok, failure = pcall(function()
        configureContainer(containers.player, "player", plan)
        configureContainer(containers.target, "target", plan)
    end)
    if not ok then
        disableContainer(containers.player)
        disableContainer(containers.target)
        return nil, tostring(failure)
    end
    return containers
end

local function ensureNativeCapability()
    local capability = EAM.Services.AuraCapabilityService
    if capability.isNative() then
        return true, nil
    end
    local probe, reason = createContainer()
    if not probe then
        capability.rejectContainer(reason)
        return false, nil
    end
    if not capability.acceptContainer(probe) then
        disableContainer(probe)
        return false, nil
    end
    return true, probe
end

function AuraContainerService.requestRebuild(reason)
    local capability = EAM.Services.AuraCapabilityService
    if not capability or not capability.initialized then
        return false, "capabilityUnavailable"
    end
    if capability.clientInterface < Constants.INTERFACE then
        return false, "legacyBackend"
    end
    if capability.nativeRuntimeAllowed ~= true then
        AuraContainerService.lastReason = capability.limitationReason or "nativePtrOnlyGate"
        return false, AuraContainerService.lastReason
    end
    if inCombat() then
        AuraContainerService.pending = true
        AuraContainerService.pendingRevision = EAM.db and EAM.db.revision or 0
        AuraContainerService.lastReason = "combatDeferred"
        return false, "combatDeferred"
    end

    local nativeAvailable, probeContainer = ensureNativeCapability()
    if not nativeAvailable then
        AuraContainerService.lastReason = capability.limitationReason
        return false, capability.limitationReason
    end

    local capabilitySnapshot = capability.getSnapshot()
    local plan = EAM.Managers.AuraRuleCompiler.compile(EAM.db, capabilitySnapshot)
    if AuraContainerService.lastPlan
        and AuraContainerService.lastPlan.fingerprint == plan.fingerprint
        and AuraContainerService.current then
        disableContainer(probeContainer)
        AuraContainerService.pending = false
        AuraContainerService.pendingRevision = nil
        AuraContainerService.reloadRequired = false
        AuraContainerService.settingsDirty = false
        AuraContainerService.lastPlan = plan
        local soundService = EAM.Services.AuraSoundService
        if soundService then
            local soundOK, soundReason = soundService.sync(plan, capabilitySnapshot)
            if not soundOK then
                AuraContainerService.lastReason = soundReason or "auraSoundSyncFailed"
                return false, AuraContainerService.lastReason
            end
            if soundReason ~= "unchanged" then
                AuraContainerService.lastReason = soundReason
                return true, soundReason
            end
        end
        AuraContainerService.lastReason = "unchanged"
        return true, "unchanged"
    end

    if AuraContainerService.current
        and AuraContainerService.createdContainerCount + 2 > AuraContainerService.maxCreatedContainerCount
    then
        AuraContainerService.pending = false
        AuraContainerService.pendingRevision = nil
        AuraContainerService.reloadRequired = true
        AuraContainerService.lastReason = "nativeReloadRequired"
        return false, "nativeReloadRequired"
    end

    local containers, failure = buildNativeContainers(plan, probeContainer)
    if not containers then
        if failure == "nativeReloadRequired" then
            AuraContainerService.reloadRequired = true
        else
            AuraContainerService.failedRebuildCount = AuraContainerService.failedRebuildCount + 1
        end
        AuraContainerService.lastReason = failure or "nativeRebuildFailed"
        return false, AuraContainerService.lastReason
    end

    retireContainers(AuraContainerService.current)
    AuraContainerService.current = containers
    AuraContainerService.lastPlan = plan
    AuraContainerService.rebuildCount = AuraContainerService.rebuildCount + 1
    AuraContainerService.pending = false
    AuraContainerService.pendingRevision = nil
    AuraContainerService.reloadRequired = false
    AuraContainerService.settingsDirty = false
    AuraContainerService.lastReason = reason or "rebuilt"

    if EAM.Services.AuraSoundService then
        local soundOK, soundReason = EAM.Services.AuraSoundService.sync(plan, capabilitySnapshot)
        if not soundOK then
            AuraContainerService.lastReason = soundReason or "auraSoundSyncFailed"
            return false, AuraContainerService.lastReason
        end
    end
    return true, "rebuilt"
end

function AuraContainerService.onModuleToggle(enabled, unit, reason)
    if not AuraContainerService.initialized then
        return true, "notInitialized"
    end
    return AuraContainerService.requestRebuild(
        "MODULE_TOGGLE_" .. tostring(unit) .. "_" .. tostring(reason or enabled)
    )
end

function AuraContainerService.markSettingsDirty(reason)
    AuraContainerService.settingsDirty = true
    AuraContainerService.lastReason = reason or "settingsDirty"
    return true, "settingsDirty"
end

function AuraContainerService.onCombatEnd()
    if AuraContainerService.pending then
        AuraContainerService.requestRebuild("PLAYER_REGEN_ENABLED")
    end
    local nativeRenderer = EAM.UI and EAM.UI.NativeAuraRenderer
    if nativeRenderer and nativeRenderer.onCombatEnd then
        nativeRenderer.onCombatEnd()
    end
end

function AuraContainerService.initialize()
    if AuraContainerService.initialized then
        return
    end
    AuraContainerService.initialized = true

    local capability = EAM.Services.AuraCapabilityService
    capability.initialize()
    local router = EAM.Modules.EventRouter
    if router then
        router.register("PLAYER_REGEN_ENABLED", AuraContainerService.onCombatEnd)
        router.register("PLAYER_SPECIALIZATION_CHANGED", AuraContainerService.requestRebuild)
        router.register("EAM_AURA_CONFIG_CHANGED", AuraContainerService.requestRebuild)
        router.register("EAM_AURA_STYLE_CHANGED", AuraContainerService.requestRebuild)
        router.register("EAM_AURA_SOUND_CHANGED", AuraContainerService.requestRebuild)
    end

    if capability.clientInterface >= Constants.INTERFACE then
        AuraContainerService.requestRebuild("initialize")
    end
end

function AuraContainerService.getStatus()
    local capability = EAM.Services.AuraCapabilityService
    local limitationCount = 0
    local rules = AuraContainerService.lastPlan and AuraContainerService.lastPlan.rules or nil
    if rules then
        for ruleIndex = 1, #rules do
            limitationCount = limitationCount + #(rules[ruleIndex].limitations or {})
        end
    end
    return {
        backend = capability and capability.selectedBackend or Constants.AURA_BACKEND_UNSUPPORTED,
        pending = AuraContainerService.pending,
        pendingRevision = AuraContainerService.pendingRevision,
        reloadRequired = AuraContainerService.reloadRequired,
        createdContainerCount = AuraContainerService.createdContainerCount,
        maxCreatedContainerCount = AuraContainerService.maxCreatedContainerCount,
        rebuildCount = AuraContainerService.rebuildCount,
        failedRebuildCount = AuraContainerService.failedRebuildCount,
        settingsDirty = AuraContainerService.settingsDirty,
        retiredContainerCount = AuraContainerService.retiredContainerCount,
        limitationCount = limitationCount,
        lastReason = AuraContainerService.lastReason,
        fingerprint = AuraContainerService.lastPlan and AuraContainerService.lastPlan.fingerprint or nil,
        nativeSlotCount = AuraContainerService.lastPlan and AuraContainerService.lastPlan.nativeSlotCount or 0,
        nativeGroupCount = AuraContainerService.lastPlan and AuraContainerService.lastPlan.nativeGroupCount or 0,
    }
end
