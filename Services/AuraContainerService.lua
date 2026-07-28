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
    retiredContainerCount = 0,
    rebuildCount = 0,
    failedRebuildCount = 0,
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
    local ok, container = pcall(api.CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if not ok or not container then
        return nil, "nativeContainerCreationFailed"
    end
    return container
end

local function buildCommonOptions(rule)
    local options = {
        templateNames = { "CustomAuraButtonTemplate" },
        initializeFrame = EAM.UI.NativeAuraRenderer.initializeFrame,
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

local function configureContainer(container, unit, plan)
    container:SetEnabled(false)
    container:SetUnit(unit)

    local layout = nil
    local slotIndex = 0
    for index = 1, #plan.rules do
        local rule = plan.rules[index]
        if rule.unit == unit and rule.backend == Constants.AURA_RULE_NATIVE_SLOT then
            local options = buildCommonOptions(rule)
            local auraButton = container:AddAuraSlot(rule.slotKey, rule.filterString, options)
            slotIndex = slotIndex + 1
            EAM.UI.NativeAuraRenderer.anchorSlot(auraButton, container, slotIndex, rule.layout)
        elseif rule.unit == unit and rule.backend == Constants.AURA_RULE_NATIVE_GROUP then
            local options = buildCommonOptions(rule)
            options.maxFrameCount = #rule.alertIDs
            options.layout = rule.layout
            container:AddAuraGroup(rule.groupKey, rule.filterString, options)
            container:SetAuraGroupLayout(rule.groupKey, rule.layout)
            layout = rule.layout
        end
    end

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

    local plan = EAM.Managers.AuraRuleCompiler.compile(EAM.db, capability.getSnapshot())
    if AuraContainerService.lastPlan
        and AuraContainerService.lastPlan.fingerprint == plan.fingerprint
        and AuraContainerService.current then
        disableContainer(probeContainer)
        AuraContainerService.pending = false
        AuraContainerService.pendingRevision = nil
        AuraContainerService.lastReason = "unchanged"
        return true, "unchanged"
    end

    local containers, failure = buildNativeContainers(plan, probeContainer)
    if not containers then
        AuraContainerService.failedRebuildCount = AuraContainerService.failedRebuildCount + 1
        AuraContainerService.lastReason = failure or "nativeRebuildFailed"
        return false, AuraContainerService.lastReason
    end

    retireContainers(AuraContainerService.current)
    AuraContainerService.current = containers
    AuraContainerService.lastPlan = plan
    AuraContainerService.rebuildCount = AuraContainerService.rebuildCount + 1
    AuraContainerService.pending = false
    AuraContainerService.pendingRevision = nil
    AuraContainerService.lastReason = reason or "rebuilt"

    if EAM.Services.AuraSoundService then
        EAM.Services.AuraSoundService.sync(plan, capability.getSnapshot())
    end
    return true, "rebuilt"
end

function AuraContainerService.onCombatEnd()
    if AuraContainerService.pending then
        AuraContainerService.requestRebuild("PLAYER_REGEN_ENABLED")
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
        rebuildCount = AuraContainerService.rebuildCount,
        failedRebuildCount = AuraContainerService.failedRebuildCount,
        retiredContainerCount = AuraContainerService.retiredContainerCount,
        limitationCount = limitationCount,
        lastReason = AuraContainerService.lastReason,
        fingerprint = AuraContainerService.lastPlan and AuraContainerService.lastPlan.fingerprint or nil,
        nativeSlotCount = AuraContainerService.lastPlan and AuraContainerService.lastPlan.nativeSlotCount or 0,
        nativeGroupCount = AuraContainerService.lastPlan and AuraContainerService.lastPlan.nativeGroupCount or 0,
    }
end
