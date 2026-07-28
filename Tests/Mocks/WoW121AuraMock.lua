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
    itemIDsByLink = {},
    secretTables = {},
    secretValues = {},
    cvars = {},
    lastMenuCandidate = nil,
    trace = {},
}

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
        addAuraSoundCalls = 0,
        removeAuraSoundCalls = 0,
        tooltipPostCallRegistrations = 0,
        tooltipEmits = 0,
        tooltipLines = 0,
        secretTooltipReads = 0,
        secretScalarOperations = 0,
        secretKeyTableOperations = 0,
        menuOpens = 0,
        configNotifications = 0,
        auraContainerRefreshes = 0,
        auraRefreshes = 0,
        cooldownRefreshes = 0,
        itemRefreshes = 0,
        layoutRefreshes = 0,
    }
end

local function noOperation()
end

local regionMethods = {}
local regionMethodNames = {
    "SetAllPoints", "SetTexCoord", "SetPoint", "ClearAllPoints", "SetSize", "SetFont",
    "SetText", "ClearText", "Show", "Hide", "SetEnabled", "SetMouseMotionEnabled",
}
for index = 1, #regionMethodNames do
    regionMethods[regionMethodNames[index]] = noOperation
end

local function createRegion()
    return setmetatable({}, {
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

function auraButtonMethods:SetSize()
end

function auraButtonMethods:CreateTexture()
    return createRegion()
end

function auraButtonMethods:CreateFontString()
    return createRegion()
end

function auraButtonMethods:SetIcon(value)
    self.icon = value
end

function auraButtonMethods:SetDurationCooldown(value)
    self.cooldown = value
end

function auraButtonMethods:SetDurationText(value)
    self.durationText = value
end

function auraButtonMethods:SetApplicationCount(value)
    self.applicationCount = value
end

function auraButtonMethods:SetSpellName(value)
    self.spellName = value
end

function auraButtonMethods:SetHideTooltipInCombat(value)
    self.hideTooltipInCombat = value
end

function auraButtonMethods:ClearAllPoints()
end

function auraButtonMethods:SetPoint()
end

local function createAuraButton()
    return setmetatable({}, {
        __index = function(_, key)
            if key == "eamNativeRegions" then
                return nil
            end
            local method = auraButtonMethods[key]
            if method then
                return method
            end
            error("Unknown strict AuraButton method: " .. tostring(key))
        end,
    })
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
end

function auraContainerMethods:AddAuraSlot(key, filterString, options)
    countMutation()
    Mock.trace.slotAdds = Mock.trace.slotAdds + 1
    assert(type(key) == "string", "slot key must be string")
    assert(type(filterString) == "string", "slot filter must be string")
    assert(type(options) == "table" and type(options.initializeFrame) == "function", "slot options incomplete")
    local button = createAuraButton()
    options.initializeFrame(button)
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
        options.initializeFrame(createAuraButton())
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
    return setmetatable({}, {
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
        return createRegion()
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
        "SetHeight", "SetAutoFocus", "SetNumeric", "SetMaxLetters",
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
    }

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
    Mock.itemIDsByLink = {}
    Mock.secretTables = {}
    Mock.secretValues = {}
    Mock.cvars = {
        tooltipShowAuraSpellIDs = "0",
    }
    Mock.lastMenuCandidate = nil
    resetTrace()

    CreateFrame = function(frameType, frameName)
        if frameType == "AuraContainer" then
            return createAuraContainer()
        end
        if frameType == "Cooldown" then
            return createRegion()
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
    GetBuildInfo = function()
        if Mock.interface >= 120100 then
            return "12.1.0", "mock-68914", "2026-07-26", Mock.interface
        end
        return "12.0.7", "mock-68887", "2026-07-26", Mock.interface
    end
    UnitPowerType = function()
        return 0, "MANA"
    end
    STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    AuraContainerSortMethod = { Default = 0 }
    AuraContainerSortDirection = { Normal = 0 }
    Enum = Enum or {}
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
        return "macro", action.macroID, nil
    end
    GetMacroSpell = function(macroID)
        return Mock.macroSpells[macroID]
    end
    GetMacroItem = function(macroID)
        local item = Mock.macroItems[macroID]
        if not item then
            return nil, nil
        end
        return item.name, item.link
    end
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
    Mock.macroActions[slot] = {
        macroID = macroID,
    }
    Mock.macroSpells[macroID] = spellID
    if itemID then
        local link = "item:" .. tostring(itemID)
        Mock.macroItems[macroID] = {
            name = "Mock Item " .. tostring(itemID),
            link = link,
        }
        Mock.itemIDsByLink[link] = itemID
    else
        Mock.macroItems[macroID] = nil
    end
end

function Mock.setSecretMacroAction(slot, macroID)
    Mock.macroActions[slot] = {
        macroID = macroID,
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
    Mock.itemIDsByLink = {}
    Mock.lastMenuCandidate = nil
    if GameTooltip then
        GameTooltip.lines = {}
        GameTooltip.processingInfo = nil
        GameTooltip.currentType = nil
        GameTooltip.shown = false
    end
end

function Mock.setTooltipShown(value)
    GameTooltip.shown = value == true
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
    return setmetatable({}, {
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

function Mock.createSecretUnitAuraPayload()
    return setmetatable({}, {
        __index = function()
            Mock.trace.unitAuraPayloadReads = Mock.trace.unitAuraPayloadReads + 1
            error("secret UNIT_AURA payload read")
        end,
    })
end

return Mock
