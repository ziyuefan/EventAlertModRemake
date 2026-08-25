--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/TooltipMonitorService
檔案: Services\TooltipMonitorService.lua

理念:
- 以官方 TooltipDataProcessor 後處理回呼顯示安全 ID，並把加入監控導向 EAM 自有 Popup Menu。
- 不攔截 Blizzard 點擊、不查詢 AuraButton、不儲存 TooltipData/AuraData/Frame。

責任:
- 顯示 spell、item、macro 的安全 ID；巨集優先採用 action subtype 已解析的法術或物品 ID。
- 12.1 Aura ID 交由官方 CVar 顯示；隱藏 AuraButtonTooltip 只建立匿名短效候選。
- 管理短效、純 scalar 的候選項與 Ctrl+Alt 開啟流程。
- 將 Popup Menu 的確認動作路由到既有 SavedVariables 契約。

資料所有權:
- 只擁有短效候選項、能力狀態與匿名計數器。
- 不擁有監控清單；正式資料仍由 Core/SavedVariables.lua 管理。

邊界:
- UnitAura callback 絕不讀取 tooltipData；非 GameTooltip 物件亦不讀、不寫、不呼叫方法。
- Macro callback 不信任 tooltipData.id；action slot 只把安全的 FrameXML private `GetAction` metadata、action subtype 與巨集名稱當 best-effort 來源，失敗即手動降級。
- 戰鬥中、鍵盤焦點存在或修飾鍵不精確時不開啟選單。

效能注意:
- Tooltip 與修飾鍵事件皆為低頻路徑；無 OnUpdate、無 C_Timer.After。
- TooltipDataProcessor 沒有解除註冊 API，因此 initialize 必須冪等。

Retail API 注意:
- 12.1 AuraButton 具 Forbidden Aspects；本模組不對其 HookScript 或 QueryFocus。
- 目標框架 AuraButton 使用隱藏 AuraButtonTooltip；其 UnitAura post-call 只可作短效 heartbeat，不能當成可查詢的 GameTooltip。
- tooltipShowAuraSpellIDs 不跨 session 保存，每次登入以能力檢測重新啟用。
]]
local _, EAM = ...

local Service = {
    initialized = false,
    postCallCount = 0,
    candidateCount = 0,
    menuOpenCount = 0,
    commitCount = 0,
    rejectCount = 0,
    auraHeartbeatCandidateCount = 0,
    auraCallbackCount = 0,
    auraCandidateExpiredCount = 0,
    lastAuraCallbackAt = 0,
    lastAuraCandidateAt = 0,
    lastTryOpenReason = "notAttempted",
    lastModifierKey = nil,
    lastModifierDown = false,
    lastModifierAt = 0,
    auraCVarReadResult = "notAttempted",
    auraCVarSetResult = "notAttempted",
    auraIDDisplayEnabled = false,
    lastReason = "notInitialized",
}

EAM.Services.TooltipMonitorService = Service

local api = EAM.API or {}
local Util = EAM.Util or {}
local ModuleController = EAM.Modules and EAM.Modules.ModuleController
local CANDIDATE_TTL_SECONDS = 5
local AURA_HEARTBEAT_TTL_SECONDS = 0.75
local VALIDATION_GAME_TOOLTIP = "gameTooltip"
local VALIDATION_AURA_HEARTBEAT = "auraHeartbeat"
local inCombat

local function moduleEnabled()
    return not ModuleController
        or ModuleController.isEnabled(EAM.Constants.MODULE_KEYS.tooltipMonitor)
end

Service.ACTION_SPELL_COOLDOWN = "spellCooldown"
Service.ACTION_ITEM_COOLDOWN = "itemCooldown"
Service.ACTION_AURA_PLAYER = "auraPlayer"
Service.ACTION_AURA_TARGET = "auraTarget"

local function isKnownAction(action)
    if not Util.isSafeString or not Util.isSafeString(action) then
        return false
    end
    return action == Service.ACTION_SPELL_COOLDOWN
        or action == Service.ACTION_ITEM_COOLDOWN
        or action == Service.ACTION_AURA_PLAYER
        or action == Service.ACTION_AURA_TARGET
end

local candidate = {
    kind = nil,
    spellID = nil,
    itemID = nil,
    macroID = nil,
    tooltipType = nil,
    validationMode = nil,
    seenAt = 0,
}

local function safePositiveInteger(value)
    if not Util.isSafePositiveNumber or not Util.isSafePositiveNumber(value) then
        return nil
    end
    local integer = math.floor(value)
    if integer ~= value then
        return nil
    end
    return integer
end

local function clearCandidate(reason)
    candidate.kind = nil
    candidate.spellID = nil
    candidate.itemID = nil
    candidate.macroID = nil
    candidate.tooltipType = nil
    candidate.validationMode = nil
    candidate.seenAt = 0
    if reason then
        Service.lastReason = reason
    end
end

local function reject(reason)
    Service.rejectCount = Service.rejectCount + 1
    if reason == "candidateExpired" and candidate.kind == "aura" then
        Service.auraCandidateExpiredCount = Service.auraCandidateExpiredCount + 1
    end
    clearCandidate(reason)
end

local function markTryOpenReason(reason)
    if Util.isSafeString and Util.isSafeString(reason) then
        Service.lastTryOpenReason = reason
    else
        Service.lastTryOpenReason = "unknown"
    end
end

local function isGameTooltip(tooltip)
    return GameTooltip ~= nil and rawequal(tooltip, GameTooltip)
end

local function addDoubleLine(tooltip, label, value)
    if not isGameTooltip(tooltip) or type(tooltip.AddDoubleLine) ~= "function" then
        return
    end
    tooltip:AddDoubleLine(label, tostring(value), 0.20, 0.80, 1.00, 1.00, 1.00, 1.00)
end

local function addHintLine(tooltip, text)
    if not isGameTooltip(tooltip) or type(tooltip.AddLine) ~= "function" then
        return
    end
    tooltip:AddLine(text, 0.55, 0.85, 1.00, true)
end

local function setCandidate(kind, spellID, itemID, macroID, tooltipType, validationMode)
    if not inCombat or inCombat() then
        reject("combatCandidateBlocked")
        return false
    end
    if not api.GetTime or not Util.isSafeNonNegativeNumber then
        reject("timeUnavailable")
        return false
    end
    local timeOK, seenAt = pcall(api.GetTime)
    if not timeOK or not Util.isSafeNonNegativeNumber(seenAt) then
        reject("timeUnavailable")
        return false
    end
    candidate.kind = kind
    candidate.spellID = spellID
    candidate.itemID = itemID
    candidate.macroID = macroID
    candidate.tooltipType = tooltipType
    candidate.validationMode = validationMode or VALIDATION_GAME_TOOLTIP
    candidate.seenAt = seenAt
    Service.candidateCount = Service.candidateCount + 1
    if kind == "aura" then
        Service.lastAuraCandidateAt = seenAt
    end
    Service.lastReason = "candidateReady"
    return true
end

local function hasExactModifierChord()
    if not api.IsControlKeyDown or not api.IsAltKeyDown then
        return false
    end
    local isCtrlOK, isCtrl = pcall(api.IsControlKeyDown)
    local isAltOK, isAlt = pcall(api.IsAltKeyDown)
    if not isCtrlOK or not isCtrl or not isAltOK or not isAlt then
        return false
    end
    if api.IsShiftKeyDown then
        local isShiftOK, isShift = pcall(api.IsShiftKeyDown)
        if isShiftOK and isShift == true then
            return false
        end
    end
    if api.IsMetaKeyDown then
        local isMetaOK, isMeta = pcall(api.IsMetaKeyDown)
        if isMetaOK and isMeta == true then
            return false
        end
    end
    return true
end

local function hasKeyboardFocus()
    local getFocus = api.GetCurrentKeyBoardFocus or api.GetKeyboardFocus or GetKeyboardFocus
    if not getFocus then
        return false
    end
    local ok, focus = pcall(getFocus)
    return ok and focus ~= nil
end

inCombat = function()
    if not api.InCombatLockdown then
        return true
    end
    local ok, combat = pcall(api.InCombatLockdown)
    return not ok or combat == true
end

local function isCandidateFresh()
    if not candidate.kind then
        return false
    end
    if not api.GetTime or not Util.isSafeNonNegativeNumber then
        return false
    end
    local ok, now = pcall(api.GetTime)
    if not ok or not Util.isSafeNonNegativeNumber(now) then
        return false
    end
    local ttl = CANDIDATE_TTL_SECONDS
    if candidate.validationMode == VALIDATION_AURA_HEARTBEAT then
        ttl = AURA_HEARTBEAT_TTL_SECONDS
    end
    return now >= candidate.seenAt and now - candidate.seenAt <= ttl
end

local function isGameTooltipShown()
    if not GameTooltip or type(GameTooltip.IsShown) ~= "function" then
        return false
    end
    local ok, shown = pcall(GameTooltip.IsShown, GameTooltip)
    return ok and shown == true
end

local function isCandidateTooltipCurrent()
    if candidate.validationMode == VALIDATION_AURA_HEARTBEAT or candidate.kind == "aura" then
        return true
    end
    if candidate.validationMode ~= VALIDATION_GAME_TOOLTIP then
        return false
    end
    if not isGameTooltipShown() then
        return false
    end
    if candidate.tooltipType == nil or not GameTooltip or type(GameTooltip.IsTooltipType) ~= "function" then
        return false
    end
    local ok, matches = pcall(GameTooltip.IsTooltipType, GameTooltip, candidate.tooltipType)
    return ok and matches == true
end

local function tryOpenMenu()
    if not moduleEnabled() then
        clearCandidate("moduleDisabled")
        markTryOpenReason("moduleDisabled")
        return false, "moduleDisabled"
    end
    if inCombat() then
        reject("combat")
        markTryOpenReason("combat")
        return false, "combat"
    end
    if hasKeyboardFocus() then
        reject("keyboardFocus")
        markTryOpenReason("keyboardFocus")
        return false, "keyboardFocus"
    end
    if not hasExactModifierChord() then
        markTryOpenReason("modifierMismatch")
        return false, "modifierMismatch"
    end
    if not isCandidateFresh() then
        markTryOpenReason("candidateExpired")
        reject("candidateExpired")
        return false, "candidateExpired"
    end
    if not isCandidateTooltipCurrent() then
        markTryOpenReason("tooltipTypeChanged")
        reject("tooltipTypeChanged")
        return false, "tooltipTypeChanged"
    end
    if candidate.kind ~= "aura" and candidate.validationMode == VALIDATION_GAME_TOOLTIP and not isGameTooltipShown() then
        markTryOpenReason("tooltipHidden")
        reject("tooltipHidden")
        return false, "tooltipHidden"
    end

    local menu = EAM.UI and EAM.UI.TooltipMonitorMenu
    if not menu or type(menu.open) ~= "function" then
        markTryOpenReason("menuUnavailable")
        reject("menuUnavailable")
        return false, "menuUnavailable"
    end

    local snapshot = {
        kind = candidate.kind,
        spellID = candidate.spellID,
        itemID = candidate.itemID,
        macroID = candidate.macroID,
    }
    local ok, opened = pcall(menu.open, snapshot)
    if not ok or opened ~= true then
        markTryOpenReason("menuOpenFailed")
        reject("menuOpenFailed")
        return false, "menuOpenFailed"
    end

    Service.menuOpenCount = Service.menuOpenCount + 1
    clearCandidate("menuOpened")
    markTryOpenReason("opened")
    return true, "opened"
end

function Service.openManualTargetAuraMenu()
    if not moduleEnabled() then
        Service.lastReason = "manualModuleDisabled"
        Service.lastTryOpenReason = "manualModuleDisabled"
        return false, "manualModuleDisabled"
    end
    if inCombat() then
        Service.lastReason = "manualCombatBlocked"
        Service.lastTryOpenReason = "manualCombatBlocked"
        return false, "manualCombatBlocked"
    end

    local menu = EAM.UI and EAM.UI.TooltipMonitorMenu
    if not menu or type(menu.open) ~= "function" then
        Service.lastReason = "manualMenuUnavailable"
        Service.lastTryOpenReason = "manualMenuUnavailable"
        return false, "manualMenuUnavailable"
    end

    local ok, opened = pcall(menu.open, { kind = "aura" })
    if not ok or opened ~= true then
        Service.lastReason = "manualMenuOpenFailed"
        Service.lastTryOpenReason = "manualMenuOpenFailed"
        return false, "manualMenuOpenFailed"
    end

    Service.menuOpenCount = Service.menuOpenCount + 1
    clearCandidate("manualTargetPopupOpened")
    Service.lastTryOpenReason = "manualTargetPopupOpened"
    return true, "manualTargetPopupOpened"
end
local function readTooltipDataID(data)
    if not Util.isReadableTable or not Util.isReadableTable(data) then
        return nil
    end
    return safePositiveInteger(data.id)
end

local function onSpellTooltip(tooltip, data)
    if not moduleEnabled() then
        return
    end
    if not isGameTooltip(tooltip) then
        return
    end
    local spellID = readTooltipDataID(data)
    if not spellID then
        reject("unsafeSpellID")
        return
    end
    addDoubleLine(tooltip, EAM.L.EAM_TOOLTIP_SPELL_ID or "EAM Spell ID", spellID)
    if setCandidate("spell", spellID, nil, nil, api.TooltipDataType and api.TooltipDataType.Spell) then
        addHintLine(tooltip, EAM.L.EAM_TOOLTIP_OPEN_HINT or "Ctrl+Alt: open EAM monitor menu")
    end
end

local function onItemTooltip(tooltip, data)
    if not moduleEnabled() then
        return
    end
    if not isGameTooltip(tooltip) then
        return
    end
    local itemID = readTooltipDataID(data)
    if not itemID then
        reject("unsafeItemID")
        return
    end
    addDoubleLine(tooltip, EAM.L.EAM_TOOLTIP_ITEM_ID or "EAM Item ID", itemID)
    if setCandidate("item", nil, itemID, nil, api.TooltipDataType and api.TooltipDataType.Item) then
        addHintLine(tooltip, EAM.L.EAM_TOOLTIP_OPEN_HINT or "Ctrl+Alt: open EAM monitor menu")
    end
end

local function readActionMacroContext(tooltip)
    if type(tooltip.GetProcessingTooltipInfo) ~= "function" then
        return false
    end
    local ok, info = pcall(tooltip.GetProcessingTooltipInfo, tooltip)
    if not ok or not Util.isReadableTable or not Util.isReadableTable(info) then
        return false
    end
    if not Util.isSafeString or not Util.isSafeString(info.getterName) or info.getterName ~= "GetAction" then
        return false
    end
    local args = info.getterArgs
    if not Util.isReadableTable(args) then
        return false
    end
    local actionSlot = safePositiveInteger(args[1])
    if not actionSlot or not api.GetActionInfo then
        return false
    end
    local actionOK, actionType, actionID, actionSubType = pcall(api.GetActionInfo, actionSlot)
    if not actionOK or not Util.isSafeString(actionType) or actionType ~= "macro" then
        return false
    end

    local macroName
    local actionBar = api.C_ActionBar
    if actionBar and type(actionBar.GetActionText) == "function" then
        local nameOK, actionText = pcall(actionBar.GetActionText, actionSlot)
        if nameOK and Util.isSafeString(actionText) and actionText ~= "" then
            macroName = actionText
        end
    end

    local macroID
    if macroName and api.GetMacroIndexByName then
        local indexOK, macroIndex = pcall(api.GetMacroIndexByName, macroName)
        if indexOK then
            macroID = safePositiveInteger(macroIndex)
        end
    end

    local resolvedActionID = safePositiveInteger(actionID)
    local actionSubTypeIsSafe = Util.isSafeValue and Util.isSafeValue(actionSubType)
    local spellID
    local itemID
    if actionSubTypeIsSafe and Util.isSafeString(actionSubType) then
        if actionSubType == "spell" then
            spellID = resolvedActionID
        elseif actionSubType == "item" then
            itemID = resolvedActionID
        end
    end

    local macroReference = macroID or macroName
    if not macroReference and actionSubTypeIsSafe and actionSubType == nil then
        macroID = resolvedActionID
        macroReference = macroID
    end
    return true, macroID, macroReference, spellID, itemID
end

local function resolveMacroSpellID(macroReference)
    if not macroReference or not api.GetMacroSpell then
        return nil
    end
    local ok, spellID = pcall(api.GetMacroSpell, macroReference)
    if not ok then
        return nil
    end
    return safePositiveInteger(spellID)
end

local function resolveMacroItemID(macroReference)
    if not macroReference or not api.GetMacroItem or not api.C_Item or not api.C_Item.GetItemInfoInstant then
        return nil
    end
    local ok, _, itemLink = pcall(api.GetMacroItem, macroReference)
    if not ok or not Util.isSafeString(itemLink) then
        return nil
    end
    local itemOK, itemID = pcall(api.C_Item.GetItemInfoInstant, itemLink)
    if not itemOK then
        return nil
    end
    return safePositiveInteger(itemID)
end

local function onMacroTooltip(tooltip)
    if not moduleEnabled() then
        return
    end
    if not isGameTooltip(tooltip) then
        return
    end
    if inCombat() then
        reject("combatCandidateBlocked")
        return
    end
    local isMacroAction, macroID, macroReference, spellID, itemID = readActionMacroContext(tooltip)
    if not isMacroAction then
        if setCandidate("macro", nil, nil, nil, api.TooltipDataType and api.TooltipDataType.Macro) then
            addHintLine(tooltip, EAM.L.EAM_TOOLTIP_MACRO_MANUAL_HINT
                or "Macro source cannot be read safely; Ctrl+Alt opens manual EAM entry")
        end
        return
    end

    spellID = spellID or resolveMacroSpellID(macroReference)
    itemID = itemID or resolveMacroItemID(macroReference)
    if macroID then
        addDoubleLine(tooltip, EAM.L.EAM_TOOLTIP_MACRO_ID or "EAM Macro ID", macroID)
    end
    if spellID then
        addDoubleLine(tooltip, EAM.L.EAM_TOOLTIP_SPELL_ID or "EAM Spell ID", spellID)
    end
    if itemID then
        addDoubleLine(tooltip, EAM.L.EAM_TOOLTIP_ITEM_ID or "EAM Item ID", itemID)
    end
    if setCandidate("macro", spellID, itemID, macroID, api.TooltipDataType and api.TooltipDataType.Macro) then
        addHintLine(tooltip, EAM.L.EAM_TOOLTIP_OPEN_HINT or "Ctrl+Alt: open EAM monitor menu")
    end
end

local function resolvePetActionSpellID(tooltip, data)
    local rawID = readTooltipDataID(data)
    if rawID and rawID > 20 and api.C_Spell and api.C_Spell.GetSpellInfo then
        local ok, info = pcall(api.C_Spell.GetSpellInfo, rawID)
        if ok and info then
            return rawID
        end
    end

    if rawID and rawID >= 1 and rawID <= 10 then
        if api.GetPetActionInfo then
            local ok, _, _, _, _, _, _, spellID = pcall(api.GetPetActionInfo, rawID)
            if ok and safePositiveInteger(spellID) then
                return safePositiveInteger(spellID)
            end
        end
        if api.GetPetActionSpell then
            local ok, spellID = pcall(api.GetPetActionSpell, rawID)
            if ok and safePositiveInteger(spellID) then
                return safePositiveInteger(spellID)
            end
        end
    end

    if isGameTooltip(tooltip) and type(tooltip.GetProcessingTooltipInfo) == "function" then
        local ok, info = pcall(tooltip.GetProcessingTooltipInfo, tooltip)
        if ok and Util.isReadableTable(info) and Util.isReadableTable(info.getterArgs) then
            local slot = safePositiveInteger(info.getterArgs[1])
            if slot and slot >= 1 and slot <= 10 then
                if api.GetPetActionInfo then
                    local ok2, _, _, _, _, _, _, spellID = pcall(api.GetPetActionInfo, slot)
                    if ok2 and safePositiveInteger(spellID) then
                        return safePositiveInteger(spellID)
                    end
                end
                if api.GetPetActionSpell then
                    local ok2, spellID = pcall(api.GetPetActionSpell, slot)
                    if ok2 and safePositiveInteger(spellID) then
                        return safePositiveInteger(spellID)
                    end
                end
            end
        end
    end

    if rawID and rawID > 0 then
        return rawID
    end
    return nil
end

local function onPetActionTooltip(tooltip, data)
    if not moduleEnabled() then
        return
    end
    if not isGameTooltip(tooltip) then
        return
    end
    local spellID = resolvePetActionSpellID(tooltip, data)
    if not spellID then
        reject("unsafePetSpellID")
        return
    end
    addDoubleLine(tooltip, EAM.L.EAM_TOOLTIP_SPELL_ID or "EAM Spell ID", spellID)
    if setCandidate("spell", spellID, nil, nil, api.TooltipDataType and api.TooltipDataType.PetAction) then
        addHintLine(tooltip, EAM.L.EAM_TOOLTIP_OPEN_HINT or "Ctrl+Alt: open EAM monitor menu")
    end
end

local function resolveUnitAuraSpellID(tooltip, data)
    local rawID = readTooltipDataID(data)
    if rawID and rawID > 0 and api.C_Spell and api.C_Spell.GetSpellInfo then
        local ok, info = pcall(api.C_Spell.GetSpellInfo, rawID)
        if ok and info then
            return rawID
        end
    end

    if isGameTooltip(tooltip) and type(tooltip.GetProcessingTooltipInfo) == "function" then
        local ok, info = pcall(tooltip.GetProcessingTooltipInfo, tooltip)
        if ok and Util.isReadableTable(info) and Util.isReadableTable(info.getterArgs) then
            local getterName = info.getterName
            local args = info.getterArgs
            local unit = args[1]
            local cUnitAuras = api.C_UnitAuras or C_UnitAuras
            if cUnitAuras and Util.isSafeString(unit) then
                if getterName == "GetUnitAura" or getterName == "GetUnitBuff" or getterName == "GetUnitDebuff" then
                    local index = safePositiveInteger(args[2])
                    local filter = args[3]
                    if index and type(cUnitAuras.GetAuraDataByIndex) == "function" then
                        local aOK, aura = pcall(cUnitAuras.GetAuraDataByIndex, unit, index, filter)
                        if aOK and type(aura) == "table" and safePositiveInteger(aura.spellId) then
                            return safePositiveInteger(aura.spellId)
                        end
                    end
                elseif getterName == "GetUnitAuraByAuraInstanceID" then
                    local auraInstanceID = safePositiveInteger(args[2])
                    if auraInstanceID and type(cUnitAuras.GetAuraDataByAuraInstanceID) == "function" then
                        local aOK, aura = pcall(cUnitAuras.GetAuraDataByAuraInstanceID, unit, auraInstanceID)
                        if aOK and type(aura) == "table" and safePositiveInteger(aura.spellId) then
                            return safePositiveInteger(aura.spellId)
                        end
                    end
                end
            end
        end
    end

    if rawID and rawID > 0 then
        return rawID
    end
    return nil
end

local function onAuraTooltip(tooltip, data)
    if not moduleEnabled() then
        return
    end
    Service.auraCallbackCount = Service.auraCallbackCount + 1
    if api.GetTime and Util.isSafeNonNegativeNumber then
        local timeOK, callbackAt = pcall(api.GetTime)
        if timeOK and Util.isSafeNonNegativeNumber(callbackAt) then
            Service.lastAuraCallbackAt = callbackAt
        end
    end
    if tooltip == nil then
        reject("auraTooltipUnavailable")
        return
    end
    local usesGameTooltip = isGameTooltip(tooltip)
    local validationMode = usesGameTooltip and VALIDATION_GAME_TOOLTIP or VALIDATION_AURA_HEARTBEAT
    local spellID = resolveUnitAuraSpellID(tooltip, data)
    if spellID and usesGameTooltip then
        addDoubleLine(tooltip, EAM.L.EAM_TOOLTIP_SPELL_ID or "EAM Spell ID", spellID)
    end

    local hint = (spellID ~= nil or Service.auraIDDisplayEnabled)
        and (EAM.L.EAM_TOOLTIP_AURA_HINT or "Aura ID is shown by Blizzard; Ctrl+Alt opens EAM")
        or (EAM.L.EAM_TOOLTIP_AURA_MANUAL_HINT
            or "Aura ID display is unavailable; Ctrl+Alt opens manual EAM entry")
    if setCandidate("aura", spellID, nil, nil, api.TooltipDataType and api.TooltipDataType.UnitAura, validationMode) then
        if usesGameTooltip then
            addHintLine(tooltip, hint)
        else
            Service.auraHeartbeatCandidateCount = Service.auraHeartbeatCandidateCount + 1
        end
    end
end

local function registerPostCall(tooltipType, callback)
    local processor = api.TooltipDataProcessor
    if tooltipType == nil or not processor or type(processor.AddTooltipPostCall) ~= "function" then
        return false
    end
    local ok = pcall(processor.AddTooltipPostCall, tooltipType, callback)
    if not ok then
        Service.lastReason = "postCallRegistrationFailed"
        return false
    end
    Service.postCallCount = Service.postCallCount + 1
    return true
end

local function enableAuraIDDisplay()
    Service.auraCVarReadResult = "unavailable"
    Service.auraCVarSetResult = "unavailable"
    local cvar = api.C_CVar
    if not cvar or type(cvar.GetCVar) ~= "function" or type(cvar.SetCVar) ~= "function" then
        Service.lastReason = "auraIDCVarUnavailable"
        return false
    end
    local ok, current = pcall(cvar.GetCVar, "tooltipShowAuraSpellIDs")
    if not ok then
        Service.auraCVarReadResult = "readFailed"
        Service.lastReason = "auraIDCVarUnavailable"
        return false
    end
    if current == nil then
        Service.auraCVarReadResult = "readUnavailable"
        Service.lastReason = "auraIDCVarUnavailable"
        return false
    end
    if Util.isSafeValue and not Util.isSafeValue(current) then
        Service.auraCVarReadResult = "readUnsafe"
        Service.lastReason = "auraIDCVarUnavailable"
        return false
    end
    Service.auraCVarReadResult = "readSafe"

    local setOK, setAccepted = pcall(cvar.SetCVar, "tooltipShowAuraSpellIDs", "1")
    if not setOK or setAccepted == false then
        Service.auraCVarSetResult = "rejected"
        Service.lastReason = "auraIDCVarSetFailed"
        return false
    end
    Service.auraCVarSetResult = "accepted"

    local verifyOK, verified = pcall(cvar.GetCVar, "tooltipShowAuraSpellIDs")
    if not verifyOK then
        Service.auraCVarReadResult = "verifyFailed"
    elseif not Util.isSafeString or not Util.isSafeString(verified) then
        Service.auraCVarReadResult = "verifyUnsafe"
    elseif verified ~= "1" then
        Service.auraCVarReadResult = "verifiedOff"
    else
        Service.auraCVarReadResult = "verifiedOn"
    end
    Service.auraIDDisplayEnabled = Service.auraCVarReadResult == "verifiedOn"
    if not Service.auraIDDisplayEnabled then
        Service.lastReason = "auraIDCVarVerifyFailed"
    end
    return Service.auraIDDisplayEnabled
end
local function notifyConfigChanged()
    local options = EAM.UI and EAM.UI.Options
    if options and type(options.notifyConfigChanged) == "function" then
        pcall(options.notifyConfigChanged)
        return
    end
    if EAM.Services.AuraService and EAM.Services.AuraService.refreshAll then
        pcall(EAM.Services.AuraService.refreshAll, "TOOLTIP_MONITOR_CHANGED")
    end
    if EAM.Services.CooldownService and EAM.Services.CooldownService.refreshAll then
        pcall(EAM.Services.CooldownService.refreshAll, "TOOLTIP_MONITOR_CHANGED")
    end
    if EAM.Services.ItemCooldownService and EAM.Services.ItemCooldownService.refreshAll then
        pcall(EAM.Services.ItemCooldownService.refreshAll, "TOOLTIP_MONITOR_CHANGED")
    end
end

local function printResult(success, change, identifier)
    if success then
        local changeText = EAM.L.EAM_POPUP_STATUS_ADDED or "added"
        if change == "updated" then
            changeText = EAM.L.EAM_POPUP_STATUS_UPDATED or "updated"
        elseif change == "unchanged" then
            changeText = EAM.L.EAM_POPUP_STATUS_UNCHANGED or "unchanged"
        end
        print(string.format(EAM.L.EAM_POPUP_RESULT or "EAM: %s (ID %d)", changeText, identifier))
        return
    end
    print(string.format(EAM.L.EAM_POPUP_RESULT_FAILED or "EAM: add monitor failed (%s)", tostring(change)))
end

function Service.commitCandidate(source, action, manualID)
    if not moduleEnabled() then
        Service.lastReason = "moduleDisabled"
        return false, "moduleDisabled"
    end
    if inCombat() then
        Service.lastReason = "combatCommitBlocked"
        printResult(false, "combat", 0)
        return false, "combat"
    end
    if not isKnownAction(action) then
        Service.lastReason = "invalidAction"
        printResult(false, "invalidAction", 0)
        return false, "invalidAction"
    end
    if not Util.isReadableTable or not Util.isReadableTable(source) then
        Service.lastReason = "invalidCandidate"
        return false, "invalidCandidate"
    end

    local saved = EAM.Modules and EAM.Modules.SavedVariables
    if not saved then
        Service.lastReason = "savedVariablesUnavailable"
        return false, "savedVariablesUnavailable"
    end

    local identifier
    local operation
    local unit
    if source.kind == "spell" and action == Service.ACTION_SPELL_COOLDOWN then
        identifier = safePositiveInteger(source.spellID)
        operation = saved.addSpellCooldownAlert
    elseif source.kind == "item" and action == Service.ACTION_ITEM_COOLDOWN then
        identifier = safePositiveInteger(source.itemID)
        operation = saved.addItemCooldownAlert
    elseif source.kind == "aura" then
        identifier = safePositiveInteger(manualID)
        operation = saved.addAuraAlert
        if action == Service.ACTION_AURA_PLAYER then
            unit = "player"
        elseif action == Service.ACTION_AURA_TARGET then
            unit = "target"
        else
            operation = nil
        end
    elseif source.kind == "macro" and action == Service.ACTION_SPELL_COOLDOWN then
        identifier = safePositiveInteger(source.spellID) or safePositiveInteger(manualID)
        operation = saved.addSpellCooldownAlert
    elseif source.kind == "macro" and action == Service.ACTION_ITEM_COOLDOWN then
        identifier = safePositiveInteger(source.itemID) or safePositiveInteger(manualID)
        operation = saved.addItemCooldownAlert
    end

    if not identifier or type(operation) ~= "function" then
        Service.lastReason = "invalidCommitRoute"
        printResult(false, "invalidID", 0)
        return false, "invalidCommitRoute"
    end

    local callOK
    local success
    local alertID
    local change
    if unit then
        callOK, success, alertID, change = pcall(operation, unit, identifier)
    else
        callOK, success, alertID, change = pcall(operation, identifier)
    end
    if not callOK or success ~= true then
        local reason = callOK and alertID or "luaError"
        Service.lastReason = reason or "commitFailed"
        printResult(false, reason or "commitFailed", identifier)
        return false, reason or "commitFailed"
    end

    Service.commitCount = Service.commitCount + 1
    Service.lastReason = change or "committed"
    if change ~= "unchanged" then
        notifyConfigChanged()
    end
    printResult(true, change, identifier)
    return true, alertID, change
end

local function onModifierStateChanged(_, key, down)
    if not moduleEnabled() then
        return
    end
    if Util.isSafeString and Util.isSafeString(key) then
        Service.lastModifierKey = key
    else
        Service.lastModifierKey = "unknown"
    end
    Service.lastModifierDown = down == 1 or down == true
    if api.GetTime and Util.isSafeNonNegativeNumber then
        local timeOK, modifierAt = pcall(api.GetTime)
        if timeOK and Util.isSafeNonNegativeNumber(modifierAt) then
            Service.lastModifierAt = modifierAt
        end
    end
    if Service.lastModifierDown then
        tryOpenMenu()
    else
        markTryOpenReason("modifierUp")
    end
end

local function onCombatStarted()
    clearCandidate("combat")
    local menu = EAM.UI and EAM.UI.TooltipMonitorMenu
    if menu and type(menu.hide) == "function" then
        pcall(menu.hide)
    end
end

function Service.initialize()
    if Service.initialized then
        return
    end
    Service.initialized = true

    if moduleEnabled() then
        enableAuraIDDisplay()
    end
    local types = api.TooltipDataType
    if types then
        registerPostCall(types.Spell, onSpellTooltip)
        registerPostCall(types.Item, onItemTooltip)
        registerPostCall(types.UnitAura, onAuraTooltip)
        registerPostCall(types.Macro, onMacroTooltip)
        if types.PetAction then
            registerPostCall(types.PetAction, onPetActionTooltip)
        end
    end

    local router = EAM.Modules and EAM.Modules.EventRouter
    if router and type(router.register) == "function" then
        router.register("MODIFIER_STATE_CHANGED", onModifierStateChanged)
        router.register("PLAYER_REGEN_DISABLED", onCombatStarted)
    end

    if Service.postCallCount > 0 and Service.auraIDDisplayEnabled then
        Service.lastReason = "ready"
    elseif Service.postCallCount > 0 and Service.lastReason == "notInitialized" then
        Service.lastReason = "ready"
    else
        if Service.postCallCount == 0 then
            Service.lastReason = "tooltipProcessorUnavailable"
        end
    end
end

function Service.onModuleToggle(enabled, reason)
    if enabled == false then
        clearCandidate("moduleDisabled")
        local menu = EAM.UI and EAM.UI.TooltipMonitorMenu
        if menu and type(menu.hide) == "function" then
            pcall(menu.hide)
        end
        Service.lastReason = "moduleDisabled"
        return true, "disabled"
    end
    enableAuraIDDisplay()
    Service.lastReason = Service.postCallCount > 0 and "ready" or "tooltipProcessorUnavailable"
    return true, "enabled"
end

function Service.getStatus()
    return {
        initialized = Service.initialized,
        postCallCount = Service.postCallCount,
        auraIDDisplayEnabled = Service.auraIDDisplayEnabled,
        candidateCount = Service.candidateCount,
        menuOpenCount = Service.menuOpenCount,
        commitCount = Service.commitCount,
        rejectCount = Service.rejectCount,
        auraHeartbeatFallbackAvailable = true,
        auraHeartbeatCandidateCount = Service.auraHeartbeatCandidateCount,
        auraCallbackCount = Service.auraCallbackCount,
        auraCandidateActive = candidate.kind == "aura",
        auraCandidateSeenAt = candidate.kind == "aura" and candidate.seenAt or 0,
        lastAuraCallbackAt = Service.lastAuraCallbackAt,
        lastAuraCandidateAt = Service.lastAuraCandidateAt,
        auraCandidateExpiredCount = Service.auraCandidateExpiredCount,
        lastTryOpenReason = Service.lastTryOpenReason,
        lastModifierKey = Service.lastModifierKey,
        lastModifierDown = Service.lastModifierDown,
        lastModifierAt = Service.lastModifierAt,
        auraCVarReadResult = Service.auraCVarReadResult,
        auraCVarSetResult = Service.auraCVarSetResult,
        lastReason = Service.lastReason,
    }
end

if EAM.FlowTestEnvironment == "offline-mock" then
    Service._clearCandidateForTest = clearCandidate
    Service._tryOpenMenuForTest = tryOpenMenu
end
