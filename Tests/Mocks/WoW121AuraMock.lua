--[[ EAM_FILE_COMMENTARY
Module: Tests/Mocks/WoW121AuraMock

責任:
- 提供 12.1 AuraContainer/AuraButton/AuraSound 的嚴格離線契約 mock。
- 未列入白名單的方法直接失敗，並記錄 Legacy Aura getter 與結構 mutation 次數。

邊界:
- 僅證明 EAM 呼叫流程，不代表 PTR Widget、Secret、taint 或聲音播放實機通過。
]]

local Mock = {
    interface = 120100,
    inCombat = false,
    keyboardFocus = nil,
    controlDown = false,
    altDown = false,
    shiftDown = false,
    metaDown = false,
    nextSoundID = 1,
    activeSounds = {},
    tooltipPostCalls = {},
    macroActions = {},
    macroSpells = {},
    macroItems = {},
    macroIDsByName = {},
    itemIDsByLink = {},
    secretTables = {},
    secretValues = {},
    cvars = {},
    lastMenuCandidate = nil,
    trace = {},
}

local restrictedTooltip = setmetatable({}, {
    __index = function()
        Mock.trace.restrictedTooltipAccesses = Mock.trace.restrictedTooltipAccesses + 1
        error("restricted AuraButtonTooltip read")
    end,
    __newindex = function()
        Mock.trace.restrictedTooltipAccesses = Mock.trace.restrictedTooltipAccesses + 1
        error("restricted AuraButtonTooltip write")
    end,
})

local function resetTrace()
    Mock.trace = {
        auraGetterCalls = 0,
        unitAuraPayloadReads = 0,
        containerCreates = 0,
        containerMutations = 0,
        slotAdds = 0,
        groupAdds = 0,
        groupLayouts = 0,
        initializedButtons = 0,
        pandemicRegionAdds = 0,
        dispelTextureAdds = 0,
        addAuraSoundCalls = 0,
        removeAuraSoundCalls = 0,
        tooltipPostCallRegistrations = 0,
        tooltipEmits = 0,
        tooltipLines = 0,
        rendererTooltipOwnerCalls = 0,
        rendererTooltipSpellCalls = 0,
        rendererTooltipItemCalls = 0,
        secretTooltipReads = 0,
        restrictedTooltipAccesses = 0,
        secretScalarOperations = 0,
        secretKeyTableOperations = 0,
        menuOpens = 0,
        configNotifications = 0,
        auraContainerRefreshes = 0,
        auraRefreshes = 0,
        cooldownRefreshes = 0,
        itemRefreshes = 0,
        layoutRefreshes = 0,
        regionSetPoints = 0,
        regionSetFonts = 0,
        postInitializationMutations = 0,
        auraAssignmentsCleared = 0,
        durationCreates = 0,
        durationSetTimeCalls = 0,
        durationBindingCreates = 0,
        durationBindingEnables = 0,
        cooldownDurationObjectCalls = 0,
        cooldownNumericCalls = 0,
        unitPowerReads = 0,
        unitPowerMaxReads = 0,
        unitPowerPercentReads = 0,
        nativePowerSinkWrites = 0,
        svgVectorCreates = 0,
        svgSetCalls = 0,
        svgClearCalls = 0,
        gameplayAutomationCalls = 0,
    }
end

local function noOperation()
end

local function assertInitializationOpen(widget)
    local owner = widget and rawget(widget, "_eamOwner") or widget
    if owner and rawget(owner, "_eamInitializationLocked") then
        Mock.trace.postInitializationMutations = Mock.trace.postInitializationMutations + 1
        error("AuraButton mutation after initializeFrame")
    end
end

local function regionNoOperation(self)
    assertInitializationOpen(self)
end

local regionMethods = {}
local regionMethodNames = {
    "SetAllPoints", "SetTexCoord",
    "SetText", "ClearText", "SetEnabled", "SetMouseMotionEnabled",
    "SetColorTexture", "SetRadialProgressBarStartOffset", "SetRadialProgressBarEndOffset",
    "SetRadialProgressBarFeather",
}

function regionMethods:SetTexture(value)
    assertInitializationOpen(self)
    self.texture = value
end

function regionMethods:SetBlendMode(value)
    assertInitializationOpen(self)
    self.blendMode = value
end

function regionMethods:SetVertexColor(red, green, blue, alpha)
    assertInitializationOpen(self)
    self.vertexColor = { red, green, blue, alpha }
end

function regionMethods:Show()
    assertInitializationOpen(self)
    self.shown = true
end

function regionMethods:Hide()
    assertInitializationOpen(self)
    self.shown = false
end
for index = 1, #regionMethodNames do
    regionMethods[regionMethodNames[index]] = regionNoOperation
end

function regionMethods:SetPoint(point, relativeTo, relativePoint, x, y)
    assertInitializationOpen(self)
    self.lastPoint = {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
    Mock.trace.regionSetPoints = Mock.trace.regionSetPoints + 1
end

function regionMethods:ClearAllPoints()
    assertInitializationOpen(self)
    self.lastPoint = nil
end

function regionMethods:SetSize(width, height)
    assertInitializationOpen(self)
    self.width = width
    self.height = height
end

function regionMethods:SetFont(font, size, flags)
    assertInitializationOpen(self)
    self.font = font
    self.fontSize = size
    self.fontFlags = flags
    Mock.trace.regionSetFonts = Mock.trace.regionSetFonts + 1
end

function regionMethods:SetHideCountdownNumbers(value)
    assertInitializationOpen(self)
    self.hideCountdownNumbers = value == true
end

function regionMethods:SetSwipeColor(red, green, blue, alpha)
    assertInitializationOpen(self)
    self.swipeColor = { red, green, blue, alpha }
    self.swipeAlpha = alpha
end

function regionMethods:SetCooldownFromDurationObject(durationObject)
    assertInitializationOpen(self)
    self.durationObject = durationObject
    Mock.trace.cooldownDurationObjectCalls = Mock.trace.cooldownDurationObjectCalls + 1
end

function regionMethods:SetCooldown(startTime, duration)
    assertInitializationOpen(self)
    self.startTime = startTime
    self.duration = duration
    Mock.trace.cooldownNumericCalls = Mock.trace.cooldownNumericCalls + 1
end

function regionMethods:SetRadialProgressBarPercent(value)
    assertInitializationOpen(self)
    self.radialPercentClass = Mock.secretValues[value] == true and "secret" or type(value)
    Mock.trace.nativePowerSinkWrites = Mock.trace.nativePowerSinkWrites + 1
end

function regionMethods:SetSVG(asset)
    assertInitializationOpen(self)
    self.svgAsset = asset
    Mock.trace.svgSetCalls = Mock.trace.svgSetCalls + 1
    return true
end

function regionMethods:ClearSVG()
    assertInitializationOpen(self)
    self.svgAsset = nil
    Mock.trace.svgClearCalls = Mock.trace.svgClearCalls + 1
end

function regionMethods:HasSVG()
    return rawget(self, "svgAsset") ~= nil
end

function regionMethods:GetSVGFileID()
    return rawget(self, "svgAsset") and 700001 or 0
end

local function createRegion(owner, regionType)
    return setmetatable({
        _eamOwner = owner,
        regionType = regionType,
        shown = true,
    }, {
        __index = function(_, key)
            local method = regionMethods[key]
            if method then
                return method
            end
            error("Unknown strict region method: " .. tostring(key))
        end,
    })
end

local auraButtonMethods = {}

function auraButtonMethods:SetSize(width, height)
    assertInitializationOpen(self)
    self.width = width
    self.height = height
end

function auraButtonMethods:CreateTexture()
    assertInitializationOpen(self)
    local region = createRegion(self, "Texture")
    self.createdTextures[#self.createdTextures + 1] = region
    return region
end

function auraButtonMethods:CreateFontString()
    assertInitializationOpen(self)
    local region = createRegion(self, "FontString")
    self.createdFontStrings[#self.createdFontStrings + 1] = region
    return region
end

function auraButtonMethods:SetIcon(value)
    assertInitializationOpen(self)
    self.icon = value
end

function auraButtonMethods:SetDurationCooldown(value)
    assertInitializationOpen(self)
    self.cooldown = value
end

function auraButtonMethods:SetDurationText(value)
    assertInitializationOpen(self)
    self.durationText = value
end

function auraButtonMethods:SetApplicationCount(value)
    assertInitializationOpen(self)
    self.applicationCount = value
end

function auraButtonMethods:SetSpellName(value)
    assertInitializationOpen(self)
    self.spellName = value
end

function auraButtonMethods:SetHideTooltipInCombat(value)
    assertInitializationOpen(self)
    self.hideTooltipInCombat = value
end

function auraButtonMethods:ClearAllPoints()
    assertInitializationOpen(self)
    self.lastPoint = nil
end

function auraButtonMethods:SetPoint(point, relativeTo, relativePoint, x, y)
    assertInitializationOpen(self)
    self.lastPoint = {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

function auraButtonMethods:AddPandemicRegion(region)
    assertInitializationOpen(self)
    self.pandemicRegions[#self.pandemicRegions + 1] = region
    Mock.trace.pandemicRegionAdds = Mock.trace.pandemicRegionAdds + 1
    return #self.pandemicRegions
end

function auraButtonMethods:RemovePandemicRegion(index)
    assertInitializationOpen(self)
    table.remove(self.pandemicRegions, index)
end

function auraButtonMethods:ClearPandemicRegions()
    assertInitializationOpen(self)
    self.pandemicRegions = {}
end

function auraButtonMethods:AddDispelTypeTexture(texture, options)
    assertInitializationOpen(self)
    self.dispelTypeTextures[#self.dispelTypeTextures + 1] = {
        texture = texture,
        options = options,
    }
    Mock.trace.dispelTextureAdds = Mock.trace.dispelTextureAdds + 1
    return #self.dispelTypeTextures
end

function auraButtonMethods:RemoveDispelTypeTexture(index)
    assertInitializationOpen(self)
    table.remove(self.dispelTypeTextures, index)
end

function auraButtonMethods:ClearDispelTypeTextures()
    assertInitializationOpen(self)
    self.dispelTypeTextures = {}
end

function auraButtonMethods:GetDispelTypeTextureCount()
    return #self.dispelTypeTextures
end

function auraButtonMethods:GetDispelTypeTexture(index)
    return self.dispelTypeTextures[index]
end

local function createAuraButton()
    local button = setmetatable({
        createdTextures = {},
        createdFontStrings = {},
        pandemicRegions = {},
        dispelTypeTextures = {},
    }, {
        __index = function(_, key)
            if key == "eamNativeRegions" or key == "eamNativeInitialized" then
                return nil
            end
            local method = auraButtonMethods[key]
            if method then
                return method
            end
            error("Unknown strict AuraButton method: " .. tostring(key))
        end,
    })
    Mock.lastAuraButton = button
    return button
end

local function lockAuraButton(button)
    rawset(button, "_eamInitializationLocked", true)
    return button
end

local auraContainerMethods = {}

local function countMutation()
    Mock.trace.containerMutations = Mock.trace.containerMutations + 1
end

function auraContainerMethods:SetUnit(unit)
    countMutation()
    self.unit = unit
end

function auraContainerMethods:SetEnabled(enabled)
    countMutation()
    self.enabled = enabled
    if not enabled then
        for index = 1, #self.buttons do
            local button = self.buttons[index]
            button.icon = nil
            button.cooldown = nil
            button.durationText = nil
            button.applicationCount = nil
            button.spellName = nil
            Mock.trace.auraAssignmentsCleared = Mock.trace.auraAssignmentsCleared + 1
        end
    end
end

function auraContainerMethods:AddAuraSlot(key, filterString, options)
    countMutation()
    Mock.trace.slotAdds = Mock.trace.slotAdds + 1
    assert(type(key) == "string", "slot key must be string")
    assert(type(filterString) == "string", "slot filter must be string")
    assert(type(options) == "table" and type(options.initializeFrame) == "function", "slot options incomplete")
    local button = createAuraButton()
    self.buttons[#self.buttons + 1] = button
    options.initializeFrame(button)
    lockAuraButton(button)
    Mock.trace.initializedButtons = Mock.trace.initializedButtons + 1
    return button
end

function auraContainerMethods:AddAuraGroup(key, filterString, options)
    countMutation()
    Mock.trace.groupAdds = Mock.trace.groupAdds + 1
    assert(type(key) == "string", "group key must be string")
    assert(type(filterString) == "string", "group filter must be string")
    assert(type(options) == "table" and type(options.initializeFrame) == "function", "group options incomplete")
    local count = math.min(options.maxFrameCount or 1, 10)
    for _ = 1, count do
        local button = createAuraButton()
        self.buttons[#self.buttons + 1] = button
        options.initializeFrame(button)
        lockAuraButton(button)
        Mock.trace.initializedButtons = Mock.trace.initializedButtons + 1
    end
end

function auraContainerMethods:SetAuraGroupLayout(key, layout)
    countMutation()
    Mock.trace.groupLayouts = Mock.trace.groupLayouts + 1
    assert(type(key) == "string" and type(layout) == "table", "group layout incomplete")
end

function auraContainerMethods:SetSize()
    countMutation()
end

function auraContainerMethods:ClearAllPoints()
    countMutation()
end

function auraContainerMethods:SetPoint()
    countMutation()
end

function auraContainerMethods:Show()
    countMutation()
    self.shown = true
end

function auraContainerMethods:Hide()
    countMutation()
    self.shown = false
end

local function createAuraContainer()
    Mock.trace.containerCreates = Mock.trace.containerCreates + 1
    return setmetatable({
        buttons = {},
        enabled = true,
    }, {
        __index = function(_, key)
            local method = auraContainerMethods[key]
            if method then
                return method
            end
            error("Unknown strict AuraContainer method: " .. tostring(key))
        end,
    })
end

local function createGenericFrame(frameType, frameName)
    local frame = {
        scripts = {},
        events = {},
        shown = true,
        text = "",
        frameType = frameType or "Frame",
        frameName = frameName,
        timerBinding = false,
    }

    function frame:SetScript(name, callback)
        self.scripts[name] = callback
    end

    function frame:GetScript(name)
        return self.scripts[name]
    end

    function frame:RegisterEvent(event)
        self.events[event] = true
    end

    function frame:UnregisterEvent(event)
        self.events[event] = nil
    end

    function frame:CreateTexture()
        return createRegion(nil, "Texture")
    end

    function frame:CreateVectorGraphics()
        Mock.trace.svgVectorCreates = Mock.trace.svgVectorCreates + 1
        return createRegion(nil, "VectorGraphics")
    end

    function frame:CreateFontString()
        return createGenericFrame("FontString")
    end

    function frame:Show()
        local wasShown = self.shown
        self.shown = true
        if not wasShown and self.scripts.OnShow then
            self.scripts.OnShow(self)
        end
    end

    function frame:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then
            self.scripts.OnHide(self)
        end
    end

    function frame:IsShown()
        return self.shown == true
    end

    function frame:SetText(value)
        self.text = value == nil and "" or value
    end

    function frame:GetText()
        return self.text
    end

    function frame:GetNumber()
        return tonumber(self.text) or 0
    end

    function frame:ClearText()
        self.text = ""
    end

    function frame:SetValue(value)
        self.valueClass = Mock.secretValues[value] == true and "secret" or type(value)
        Mock.trace.nativePowerSinkWrites = Mock.trace.nativePowerSinkWrites + 1
    end

    function frame:SetMinMaxValues(minimum, maximum)
        self.minimum = minimum
        self.maximum = maximum
    end

    function frame:SetFocus()
        Mock.keyboardFocus = self
    end

    function frame:ClearFocus()
        if Mock.keyboardFocus == self then
            Mock.keyboardFocus = nil
        end
    end

    function frame:HighlightText()
    end

    function frame:GetName()
        return self.frameName
    end

    function frame:GetEffectiveScale()
        return 1
    end

    function frame:Raise()
    end

    function frame:Click(...)
        local callback = self.scripts.OnClick
        if callback then
            return callback(self, ...)
        end
    end

    local noOperationMethods = {
        "SetAllPoints", "SetTexCoord", "SetPoint", "ClearAllPoints", "SetSize", "SetFont",
        "SetEnabled", "SetMouseMotionEnabled", "SetFrameStrata", "SetToplevel",
        "SetClampedToScreen", "EnableMouse", "SetBackdrop", "SetJustifyH", "SetJustifyV",
        "SetHeight", "SetAutoFocus", "SetNumeric", "SetMaxLetters", "SetBackdropColor",
        "SetStatusBarTexture", "SetStatusBarColor",
    }
    for index = 1, #noOperationMethods do
        frame[noOperationMethods[index]] = noOperation
    end

    return setmetatable(frame, {
        __index = function(_, key)
            error("Unknown strict generic frame method: " .. tostring(key))
        end,
    })
end

local function createGameTooltip()
    local tooltip = {
        shown = false,
        lines = {},
        processingInfo = nil,
        currentType = nil,
        owner = nil,
        anchor = nil,
        lastSpellID = nil,
        lastItemID = nil,
    }


    function tooltip:SetOwner(owner, anchor)
        self.owner = owner
        self.anchor = anchor
        Mock.trace.rendererTooltipOwnerCalls = Mock.trace.rendererTooltipOwnerCalls + 1
    end

    function tooltip:SetSpellByID(spellID)
        self.lastSpellID = spellID
        self.lastItemID = nil
        Mock.trace.rendererTooltipSpellCalls = Mock.trace.rendererTooltipSpellCalls + 1
    end

    function tooltip:SetItemByID(itemID)
        self.lastItemID = itemID
        self.lastSpellID = nil
        Mock.trace.rendererTooltipItemCalls = Mock.trace.rendererTooltipItemCalls + 1
    end
    function tooltip:AddDoubleLine(leftText, rightText)
        self.lines[#self.lines + 1] = {
            kind = "double",
            leftText = leftText,
            rightText = rightText,
        }
        Mock.trace.tooltipLines = Mock.trace.tooltipLines + 1
    end

    function tooltip:AddLine(text)
        self.lines[#self.lines + 1] = {
            kind = "single",
            leftText = text,
        }
        Mock.trace.tooltipLines = Mock.trace.tooltipLines + 1
    end

    function tooltip:GetProcessingTooltipInfo()
        return self.processingInfo
    end

    function tooltip:IsShown()
        return self.shown == true
    end

    function tooltip:IsTooltipType(tooltipType)
        return self.currentType == tooltipType
    end

    function tooltip:Show()
        self.shown = true
    end

    function tooltip:Hide()
        self.shown = false
    end

    return tooltip
end

function Mock.install(interfaceVersion)
    Mock.interface = interfaceVersion or 120100
    Mock.inCombat = false
    Mock.keyboardFocus = nil
    Mock.controlDown = false
    Mock.altDown = false
    Mock.shiftDown = false
    Mock.metaDown = false
    Mock.nextSoundID = 1
    Mock.activeSounds = {}
    Mock.tooltipPostCalls = {}
    Mock.macroActions = {}
    Mock.macroSpells = {}
    Mock.macroItems = {}
    Mock.macroIDsByName = {}
    Mock.itemIDsByLink = {}
    Mock.secretTables = {}
    Mock.secretValues = {}
    Mock.cvars = {
        tooltipShowAuraSpellIDs = "0",
    }
    Mock.lastMenuCandidate = nil
    Mock.lastAuraButton = nil
    resetTrace()

    CreateFrame = function(frameType, frameName, parent)
        if frameType == "AuraContainer" then
            return createAuraContainer()
        end
        if frameType == "Cooldown" then
            return createRegion(parent, "Cooldown")
        end
        return createGenericFrame(frameType, frameName)
    end
    InCombatLockdown = function()
        return Mock.inCombat
    end
    GetCurrentKeyBoardFocus = function()
        return Mock.keyboardFocus
    end
    GetCursorPosition = function()
        return 640, 360
    end
    IsControlKeyDown = function()
        return Mock.controlDown
    end
    IsAltKeyDown = function()
        return Mock.altDown
    end
    IsShiftKeyDown = function()
        return Mock.shiftDown
    end
    IsMetaKeyDown = function()
        return Mock.metaDown
    end
    C_AddOns = C_AddOns or {}
    C_AddOns.GetAddOnMetadata = function(_, field)
        if field == "Version" then
            return "EventAlertMod_MN_test"
        end
        return nil
    end    GetBuildInfo = function()
        if Mock.interface >= 120100 then
            return "12.1.0", "mock-68914", "2026-07-26", Mock.interface
        end
        return "12.0.7", "mock-68887", "2026-07-26", Mock.interface
    end
    -- PTR 69189 的真實 raw flags 是 publicTest=true、testBuild=false、beta=false。
    IsTestBuild = function()
        return false
    end
    IsPublicTestClient = function()
        return true
    end
    IsBetaBuild = function()
        return false
    end
    WOW_PROJECT_ID = 1
    local function rejectGameplayAutomation(apiName)
        return function()
            Mock.trace.gameplayAutomationCalls = Mock.trace.gameplayAutomationCalls + 1
            error("forbidden gameplay automation API: " .. apiName)
        end
    end
    CastSpellByID = rejectGameplayAutomation("CastSpellByID")
    UseAction = rejectGameplayAutomation("UseAction")
    RunMacro = rejectGameplayAutomation("RunMacro")
    TargetUnit = rejectGameplayAutomation("TargetUnit")
    ReloadUI = rejectGameplayAutomation("ReloadUI")
    Mock.unitClassToken = "PALADIN"
    Mock.unitPowerType = 0
    Mock.unitPowerToken = "MANA"
    Mock.unitPowerValues = {}
    Mock.unitPowerMaxValues = {}
    Mock.secretPowerTypes = {}
    Mock.secretPowerMaxTypes = {}
    UnitClass = function()
        return "Paladin", Mock.unitClassToken, 2
    end
    UnitPowerType = function()
        return Mock.unitPowerType, Mock.unitPowerToken
    end
    UnitHasPowerType = function(_, powerType)
        return Mock.unitPowerMaxValues[powerType] ~= nil
    end
    UnitPower = function(_, powerType)
        Mock.trace.unitPowerReads = Mock.trace.unitPowerReads + 1
        if Mock.secretPowerTypes[powerType] then
            return Mock.createSecretScalar()
        end
        return Mock.unitPowerValues[powerType] or 0
    end
    UnitPowerMax = function(_, powerType)
        Mock.trace.unitPowerMaxReads = Mock.trace.unitPowerMaxReads + 1
        if Mock.secretPowerMaxTypes[powerType] then
            return Mock.createSecretScalar()
        end
        return Mock.unitPowerMaxValues[powerType] or 0
    end
    UnitPowerPercent = function(_, powerType)
        Mock.trace.unitPowerPercentReads = Mock.trace.unitPowerPercentReads + 1
        if Mock.secretPowerTypes[powerType] then
            return Mock.createSecretScalar()
        end
        local maximum = Mock.unitPowerMaxValues[powerType] or 0
        if maximum <= 0 then
            return 0
        end
        return (Mock.unitPowerValues[powerType] or 0) * 100 / maximum
    end
    Mock.totems = {}
    GetTotemInfo = function(slot)
        local totem = Mock.totems[slot]
        if not totem then
            return false, "", 0, 0, 0, 1, 0
        end
        return true, totem.name, totem.startTime, totem.duration, totem.icon, 1, totem.spellID
    end
    GetTotemDuration = function(slot)
        local totem = Mock.totems[slot]
        if not totem then
            return nil
        end
        return C_DurationUtil.CreateDuration()
    end
    STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    AuraContainerSortMethod = { Default = 0 }
    AuraContainerSortDirection = { Normal = 0 }
    Enum = Enum or {}
    Enum.PowerType = {
        Mana = 0,
        Rage = 1,
        Focus = 2,
        Energy = 3,
        ComboPoints = 4,
        Runes = 5,
        RunicPower = 6,
        SoulShards = 7,
        LunarPower = 8,
        HolyPower = 9,
        Maelstrom = 11,
        Chi = 12,
        Insanity = 13,
        ArcaneCharges = 16,
        Fury = 17,
        Pain = 18,
        Essence = 19,
    }
    Enum.SecretAspect = { Shown = 1, BarValue = 2, RadialProgress = 3 }
    Enum.CustomAuraButtonDispelTypeStealableFilter = {
        Stealable = 1,
        NotStealable = 2,
    }
    Enum.CustomAuraButtonDispelTypeTextureStyle = {
        Border = 1,
        BorderWithIcon = 2,
        Icon = 3,
        PreserveAsset = 4,
        CustomAsset = 5,
    }
    Enum.UnitAuraSoundTrigger = {
        Added = 0,
        ApplicationsIncreased = 1,
        Removed = 2,
    }
    Enum.TooltipDataType = {
        Item = 0,
        Spell = 1,
        UnitAura = 7,
        Macro = 25,
    }
    Enum.TooltipDataLineType = {
        SpellDescription = 13,
    }
    Enum.SecondsFormatterAbbreviation = {
        OneLetter = 1,
    }
    Enum.SecondsFormatterIntervalWhitespace = {
        Strip = 1,
    }
    C_DurationUtil = {
        CreateDuration = function()
            Mock.trace.durationCreates = Mock.trace.durationCreates + 1
            local durationObject = {}
            function durationObject:SetTimeFromStart(startTime, duration)
                self.startTime = startTime
                self.duration = duration
                Mock.trace.durationSetTimeCalls = Mock.trace.durationSetTimeCalls + 1
            end
            return durationObject
        end,
        CreateDurationTextBinding = function()
            Mock.trace.durationBindingCreates = Mock.trace.durationBindingCreates + 1
            local binding = {}
            function binding:SetFontString(fontString)
                self.fontString = fontString
            end
            function binding:SetDuration(durationObject)
                self.durationObject = durationObject
            end
            function binding:SetFormatter(formatter)
                self.formatter = formatter
            end
            function binding:SetZeroDurationText(value)
                self.zeroDurationText = value
            end
            function binding:SetExpiredText(value)
                self.expiredText = value
            end
            function binding:SetEnabled(value)
                self.enabled = value == true
                Mock.trace.durationBindingEnables = Mock.trace.durationBindingEnables + 1
            end
            function binding:Disable()
                self.enabled = false
            end
            function binding:SetToDefaults()
                self.reset = true
            end
            return binding
        end,
    }
    C_StringUtil = {
        CreateSecondsFormatter = function()
            local formatter = {}
            function formatter:SetDefaultAbbreviation(value)
                self.abbreviation = value
            end
            function formatter:SetStripIntervalWhitespace(value)
                self.stripWhitespace = value
            end
            function formatter:SetMillisecondsThreshold(value)
                self.millisecondsThreshold = value
            end
            return formatter
        end,
    }
    C_Secrets = {
        ShouldUnitPowerBeSecret = function(_, powerType)
            return Mock.secretPowerTypes[powerType] == true
        end,
        ShouldUnitPowerMaxBeSecret = function(_, powerType)
            return Mock.secretPowerMaxTypes[powerType] == true
        end,
        GetPowerTypeSecrecy = function(powerType)
            return Mock.secretPowerTypes[powerType] and "ContextuallySecret" or "NeverSecret"
        end,
    }
    TooltipDataProcessor = {
        AddTooltipPostCall = function(tooltipType, callback)
            local callbacks = Mock.tooltipPostCalls[tooltipType]
            if not callbacks then
                callbacks = {}
                Mock.tooltipPostCalls[tooltipType] = callbacks
            end
            callbacks[#callbacks + 1] = callback
            Mock.trace.tooltipPostCallRegistrations = Mock.trace.tooltipPostCallRegistrations + 1
        end,
    }
    GameTooltip = createGameTooltip()
    C_CVar = {
        GetCVar = function(name)
            return Mock.cvars[name]
        end,
        SetCVar = function(name, value)
            if Mock.cvars[name] == nil then
                return false
            end
            Mock.cvars[name] = tostring(value)
            return true
        end,
    }
    GetActionInfo = function(slot)
        local action = Mock.macroActions[slot]
        if not action then
            return nil
        end
        return "macro", action.actionID, action.subType
    end
    GetMacroIndexByName = function(macroName)
        return Mock.macroIDsByName[macroName] or 0
    end
    GetMacroSpell = function(macroReference)
        return Mock.macroSpells[macroReference]
    end
    GetMacroItem = function(macroReference)
        local item = Mock.macroItems[macroReference]
        if not item then
            return nil, nil
        end
        return item.name, item.link
    end
    C_ActionBar = {
        GetActionText = function(slot)
            local action = Mock.macroActions[slot]
            return action and action.macroName or nil
        end,
    }
    C_Item = C_Item or {}
    C_Item.GetItemInfoInstant = function(itemLink)
        return Mock.itemIDsByLink[itemLink]
    end
    issecretvalue = function(value)
        return Mock.secretValues[value] == true
    end
    canaccessvalue = function(value)
        return Mock.secretValues[value] ~= true
    end
    issecrettable = function(value)
        return Mock.secretTables[value] == true
    end
    canaccesstable = function(value)
        return type(value) == "table" and Mock.secretTables[value] ~= true
    end
    hasanysecretvalues = function(value)
        if Mock.secretTables[value] == true then
            return true
        end
        if type(value) ~= "table" then
            return false
        end
        for _, fieldValue in pairs(value) do
            if Mock.secretValues[fieldValue] == true then
                return true
            end
        end
        return false
    end
    C_UnitAuras = {
        GetAuraDataByIndex = function()
            Mock.trace.auraGetterCalls = Mock.trace.auraGetterCalls + 1
            error("12.1 native path called legacy aura getter")
        end,
        GetAuraDataByAuraInstanceID = function()
            Mock.trace.auraGetterCalls = Mock.trace.auraGetterCalls + 1
            error("12.1 native path called legacy aura getter")
        end,
        AddAuraSound = function(_, info)
            assert(type(info) == "table", "sound info required")
            local registrationID = Mock.nextSoundID
            Mock.nextSoundID = registrationID + 1
            Mock.activeSounds[registrationID] = true
            Mock.trace.addAuraSoundCalls = Mock.trace.addAuraSoundCalls + 1
            return registrationID
        end,
        RemoveAuraSound = function(registrationID)
            assert(Mock.activeSounds[registrationID], "unknown sound registration")
            Mock.activeSounds[registrationID] = nil
            Mock.trace.removeAuraSoundCalls = Mock.trace.removeAuraSoundCalls + 1
        end,
    }
    UIParent = createGenericFrame("Frame", "UIParent")
    return Mock
end

function Mock.setCombat(value)
    Mock.inCombat = value == true
end

function Mock.setKeyboardFocus(value)
    Mock.keyboardFocus = value
end

function Mock.setModifiers(controlDown, altDown, shiftDown, metaDown)
    Mock.controlDown = controlDown == true
    Mock.altDown = altDown == true
    Mock.shiftDown = shiftDown == true
    Mock.metaDown = metaDown == true
end

function Mock.setMacroAction(slot, macroID, spellID, itemID)
    local macroName = "Mock Macro " .. tostring(macroID)
    local actionID = spellID or itemID or macroID
    local subType = spellID and "spell" or (itemID and "item" or nil)
    Mock.macroActions[slot] = {
        macroID = macroID,
        macroName = macroName,
        actionID = actionID,
        subType = subType,
    }
    Mock.macroIDsByName[macroName] = macroID
    Mock.macroSpells[macroID] = spellID
    Mock.macroSpells[macroName] = spellID
    if itemID then
        local link = "item:" .. tostring(itemID)
        local item = {
            name = "Mock Item " .. tostring(itemID),
            link = link,
        }
        Mock.macroItems[macroID] = item
        Mock.macroItems[macroName] = item
        Mock.itemIDsByLink[link] = itemID
    else
        Mock.macroItems[macroID] = nil
        Mock.macroItems[macroName] = nil
    end
end

function Mock.setSecretMacroAction(slot, actionID)
    Mock.macroActions[slot] = {
        actionID = actionID,
        subType = nil,
    }
end

function Mock.emitTooltip(typeName, data, processingInfo)
    local tooltipType = Enum.TooltipDataType[typeName]
    assert(tooltipType ~= nil, "unknown tooltip type: " .. tostring(typeName))
    GameTooltip.lines = {}
    GameTooltip.processingInfo = processingInfo
    GameTooltip.currentType = tooltipType
    GameTooltip.shown = true
    Mock.trace.tooltipEmits = Mock.trace.tooltipEmits + 1
    local callbacks = Mock.tooltipPostCalls[tooltipType] or {}
    for index = 1, #callbacks do
        callbacks[index](GameTooltip, data)
    end
    return GameTooltip
end

function Mock.emitRestrictedTooltip(typeName, data)
    local tooltipType = Enum.TooltipDataType[typeName]
    assert(tooltipType ~= nil, "unknown tooltip type: " .. tostring(typeName))
    GameTooltip.lines = {}
    GameTooltip.processingInfo = nil
    GameTooltip.currentType = nil
    GameTooltip.shown = false
    Mock.trace.tooltipEmits = Mock.trace.tooltipEmits + 1
    local callbacks = Mock.tooltipPostCalls[tooltipType] or {}
    for index = 1, #callbacks do
        callbacks[index](restrictedTooltip, data)
    end
    return restrictedTooltip
end

function Mock.setTooltipType(typeName)
    GameTooltip.currentType = Enum.TooltipDataType[typeName]
end

function Mock.recordMenuOpen(source)
    Mock.trace.menuOpens = Mock.trace.menuOpens + 1
    Mock.lastMenuCandidate = {
        kind = source.kind,
        spellID = source.spellID,
        itemID = source.itemID,
        macroID = source.macroID,
    }
end

function Mock.clearMenuCapture()
    Mock.lastMenuCandidate = nil
end

function Mock.recordConfigNotification()
    Mock.trace.configNotifications = Mock.trace.configNotifications + 1
end

function Mock.recordConfigRefresh(kind)
    if kind == "auraContainer" then
        Mock.trace.auraContainerRefreshes = Mock.trace.auraContainerRefreshes + 1
    elseif kind == "aura" then
        Mock.trace.auraRefreshes = Mock.trace.auraRefreshes + 1
    elseif kind == "cooldown" then
        Mock.trace.cooldownRefreshes = Mock.trace.cooldownRefreshes + 1
    elseif kind == "item" then
        Mock.trace.itemRefreshes = Mock.trace.itemRefreshes + 1
    elseif kind == "layout" then
        Mock.trace.layoutRefreshes = Mock.trace.layoutRefreshes + 1
    else
        error("unknown config refresh kind")
    end
end

function Mock.resetTooltipScenario()
    Mock.inCombat = false
    Mock.keyboardFocus = nil
    Mock.controlDown = false
    Mock.altDown = false
    Mock.shiftDown = false
    Mock.metaDown = false
    Mock.macroActions = {}
    Mock.macroSpells = {}
    Mock.macroItems = {}
    Mock.macroIDsByName = {}
    Mock.itemIDsByLink = {}
    Mock.lastMenuCandidate = nil
    if GameTooltip then
        GameTooltip.lines = {}
        GameTooltip.processingInfo = nil
        GameTooltip.currentType = nil
        GameTooltip.shown = false
        GameTooltip.owner = nil
        GameTooltip.anchor = nil
        GameTooltip.lastSpellID = nil
        GameTooltip.lastItemID = nil
    end
end

function Mock.setTooltipShown(value)
    GameTooltip.shown = value == true
end


function Mock.getGameTooltipState()
    return {
        shown = GameTooltip.shown == true,
        owner = GameTooltip.owner,
        anchor = GameTooltip.anchor,
        lastSpellID = GameTooltip.lastSpellID,
        lastItemID = GameTooltip.lastItemID,
    }
end
function Mock.getTooltipLines()
    return GameTooltip.lines
end

function Mock.createSecretTooltipData()
    local value = setmetatable({}, {
        __index = function()
            Mock.trace.secretTooltipReads = Mock.trace.secretTooltipReads + 1
            error("secret tooltip data read")
        end,
    })
    Mock.secretTables[value] = true
    return value
end

function Mock.createSecretScalar()
    local function recordOperation()
        Mock.trace.secretScalarOperations = Mock.trace.secretScalarOperations + 1
    end
    local value = setmetatable({}, {
        __index = function()
            recordOperation()
            return nil
        end,
        __tostring = function()
            recordOperation()
            return "<secret>"
        end,
        __concat = function()
            recordOperation()
            return "<secret>"
        end,
        __add = function()
            recordOperation()
            return 0
        end,
        __sub = function()
            recordOperation()
            return 0
        end,
        __mul = function()
            recordOperation()
            return 0
        end,
        __div = function()
            recordOperation()
            return 0
        end,
        __lt = function()
            recordOperation()
            return false
        end,
        __le = function()
            recordOperation()
            return false
        end,
        __eq = function()
            recordOperation()
            return false
        end,
    })
    Mock.secretValues[value] = true
    return value
end

function Mock.createSecretKeyGuardedTable()
    local values = {}
    return setmetatable({
        buttons = {},
        enabled = true,
    }, {
        __index = function(_, key)
            if Mock.secretValues[key] == true then
                Mock.trace.secretKeyTableOperations = Mock.trace.secretKeyTableOperations + 1
                error("secret key table read")
            end
            return values[key]
        end,
        __newindex = function(_, key, value)
            if Mock.secretValues[key] == true then
                Mock.trace.secretKeyTableOperations = Mock.trace.secretKeyTableOperations + 1
                error("secret key table write")
            end
            values[key] = value
        end,
    })
end

function Mock.resetTrace()
    resetTrace()
end

function Mock.createAuraButtonForTest()
    return createAuraButton()
end

function Mock.lockAuraButtonForTest(button)
    return lockAuraButton(button)
end

function Mock.setUnitPowerScenario(classToken, values, maximums, secretTypes, secretMaxTypes)
    Mock.unitClassToken = classToken or "PALADIN"
    Mock.unitPowerValues = values or {}
    Mock.unitPowerMaxValues = maximums or {}
    Mock.secretPowerTypes = secretTypes or {}
    Mock.secretPowerMaxTypes = secretMaxTypes or {}
end

function Mock.createSecretUnitAuraPayload()
    return setmetatable({}, {
        __index = function()
            Mock.trace.unitAuraPayloadReads = Mock.trace.unitAuraPayloadReads + 1
            error("secret UNIT_AURA payload read")
        end,
    })
end

return Mock
