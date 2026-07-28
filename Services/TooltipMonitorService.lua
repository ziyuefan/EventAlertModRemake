--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/TooltipMonitorService
檔案: Services\TooltipMonitorService.lua

理念:
- 以官方 TooltipDataProcessor 後處理回呼顯示安全 ID，並把加入監控導向 EAM 自有 Popup Menu。
- 不攔截 Blizzard 點擊、不查詢 AuraButton、不儲存 TooltipData/AuraData/Frame。

責任:
- 顯示 spell、item、macro 的安全 ID；12.1 Aura ID 交由官方 CVar 顯示。
- 管理短效、純 scalar 的候選項與 Ctrl+Alt 開啟流程。
- 將 Popup Menu 的確認動作路由到既有 SavedVariables 契約。

資料所有權:
- 只擁有短效候選項、能力狀態與匿名計數器。
- 不擁有監控清單；正式資料仍由 Core/SavedVariables.lua 管理。

邊界:
- UnitAura callback 絕不讀取 tooltipData。
- Macro callback 不信任 tooltipData.id；action slot 只把安全的 FrameXML private `GetAction` metadata 當 best-effort 來源，失敗即手動降級。
- 戰鬥中、鍵盤焦點存在或修飾鍵不精確時不開啟選單。

效能注意:
- Tooltip 與修飾鍵事件皆為低頻路徑；無 OnUpdate、無 C_Timer.After。
- TooltipDataProcessor 沒有解除註冊 API，因此 initialize 必須冪等。

Retail API 注意:
- 12.1 AuraButton 具 Forbidden Aspects；本模組不對其 HookScript 或 QueryFocus。
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
    auraIDDisplayEnabled = false,
    lastReason = "notInitialized",
}

EAM.Services.TooltipMonitorService = Service

local api = EAM.API or {}
local Util = EAM.Util or {}
local CANDIDATE_TTL_SECONDS = 5
local inCombat

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
    candidate.seenAt = 0
    if reason then
        Service.lastReason = reason
    end
end

local function reject(reason)
    Service.rejectCount = Service.rejectCount + 1
    clearCandidate(reason)
end

local function isGameTooltip(tooltip)
    return GameTooltip ~= nil and tooltip == GameTooltip
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

local function setCandidate(kind, spellID, itemID, macroID, tooltipType)
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
    candidate.seenAt = seenAt
    Service.candidateCount = Service.candidateCount + 1
    Service.lastReason = "candidateReady"
    return true
end

local function hasExactModifierChord()
    if not api.IsControlKeyDown
        or not api.IsAltKeyDown
        or not api.IsShiftKeyDown
        or not api.IsMetaKeyDown
    then
        return false
    end
    if not api.IsControlKeyDown() or not api.IsAltKeyDown() then
        return false
    end
    if api.IsShiftKeyDown() then
        return false
    end
    if api.IsMetaKeyDown() then
        return false
    end
    return true
end

local function hasKeyboardFocus()
    if not api.GetCurrentKeyBoardFocus then
        return true
    end
    local ok, focus = pcall(api.GetCurrentKeyBoardFocus)
    return not ok or focus ~= nil
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
    return now >= candidate.seenAt and now - candidate.seenAt <= CANDIDATE_TTL_SECONDS
end

local function isGameTooltipShown()
    if not GameTooltip or type(GameTooltip.IsShown) ~= "function" then
        return false
    end
    local ok, shown = pcall(GameTooltip.IsShown, GameTooltip)
    return ok and shown == true
end

local function isCandidateTooltipCurrent()
    if candidate.tooltipType == nil or not GameTooltip or type(GameTooltip.IsTooltipType) ~= "function" then
        return false
    end
    local ok, matches = pcall(GameTooltip.IsTooltipType, GameTooltip, candidate.tooltipType)
    return ok and matches == true
end

local function tryOpenMenu()
    if inCombat() then
        reject("combat")
        return false
    end
    if hasKeyboardFocus() then
        reject("keyboardFocus")
        return false
    end
    if not hasExactModifierChord() then
        return false
    end
    if not isCandidateFresh() then
        reject("candidateExpired")
        return false
    end
    if not isCandidateTooltipCurrent() then
        reject("tooltipTypeChanged")
        return false
    end
    if not isGameTooltipShown() then
        reject("tooltipHidden")
        return false
    end

    local menu = EAM.UI and EAM.UI.TooltipMonitorMenu
    if not menu or type(menu.open) ~= "function" then
        reject("menuUnavailable")
        return false
    end

    local snapshot = {
        kind = candidate.kind,
        spellID = candidate.spellID,
        itemID = candidate.itemID,
        macroID = candidate.macroID,
    }
    local ok, opened = pcall(menu.open, snapshot)
    if not ok or opened ~= true then
        reject("menuOpenFailed")
        return false
    end

    Service.menuOpenCount = Service.menuOpenCount + 1
    clearCandidate("menuOpened")
    return true
end

local function readTooltipDataID(data)
    if not Util.isReadableTable or not Util.isReadableTable(data) then
        return nil
    end
    return safePositiveInteger(data.id)
end

local function onSpellTooltip(tooltip, data)
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

local function readActionMacroID(tooltip)
    if type(tooltip.GetProcessingTooltipInfo) ~= "function" then
        return nil
    end
    local ok, info = pcall(tooltip.GetProcessingTooltipInfo, tooltip)
    if not ok or not Util.isReadableTable or not Util.isReadableTable(info) then
        return nil
    end
    if not Util.isSafeString or not Util.isSafeString(info.getterName) or info.getterName ~= "GetAction" then
        return nil
    end
    local args = info.getterArgs
    if not Util.isReadableTable(args) then
        return nil
    end
    local actionSlot = safePositiveInteger(args[1])
    if not actionSlot or not api.GetActionInfo then
        return nil
    end
    local actionOK, actionType, actionID = pcall(api.GetActionInfo, actionSlot)
    if not actionOK or not Util.isSafeString(actionType) or actionType ~= "macro" then
        return nil
    end
    return safePositiveInteger(actionID)
end

local function resolveMacroSpellID(macroID)
    if not api.GetMacroSpell then
        return nil
    end
    local ok, spellID = pcall(api.GetMacroSpell, macroID)
    if not ok then
        return nil
    end
    return safePositiveInteger(spellID)
end

local function resolveMacroItemID(macroID)
    if not api.GetMacroItem or not api.C_Item or not api.C_Item.GetItemInfoInstant then
        return nil
    end
    local ok, _, itemLink = pcall(api.GetMacroItem, macroID)
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
    if not isGameTooltip(tooltip) then
        return
    end
    local macroID = readActionMacroID(tooltip)
    if not macroID then
        if setCandidate("macro", nil, nil, nil, api.TooltipDataType and api.TooltipDataType.Macro) then
            addHintLine(tooltip, EAM.L.EAM_TOOLTIP_MACRO_MANUAL_HINT
                or "Macro source cannot be read safely; Ctrl+Alt opens manual EAM entry")
        end
        return
    end

    local spellID = resolveMacroSpellID(macroID)
    local itemID = resolveMacroItemID(macroID)
    addDoubleLine(tooltip, EAM.L.EAM_TOOLTIP_MACRO_ID or "EAM Macro ID", macroID)
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

local function onAuraTooltip(tooltip)
    if not isGameTooltip(tooltip) then
        return
    end
    local hint = Service.auraIDDisplayEnabled
        and (EAM.L.EAM_TOOLTIP_AURA_HINT or "Aura ID is shown by Blizzard; Ctrl+Alt opens EAM")
        or (EAM.L.EAM_TOOLTIP_AURA_MANUAL_HINT
            or "Aura ID display is unavailable; Ctrl+Alt opens manual EAM entry")
    if setCandidate("aura", nil, nil, nil, api.TooltipDataType and api.TooltipDataType.UnitAura) then
        addHintLine(tooltip, hint)
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
    local cvar = api.C_CVar
    if not cvar or type(cvar.GetCVar) ~= "function" or type(cvar.SetCVar) ~= "function" then
        Service.lastReason = "auraIDCVarUnavailable"
        return false
    end
    local ok, current = pcall(cvar.GetCVar, "tooltipShowAuraSpellIDs")
    if not ok or current == nil or (Util.isSafeValue and not Util.isSafeValue(current)) then
        Service.lastReason = "auraIDCVarUnavailable"
        return false
    end
    local setOK = pcall(cvar.SetCVar, "tooltipShowAuraSpellIDs", "1")
    if not setOK then
        Service.lastReason = "auraIDCVarSetFailed"
        return false
    end
    local verifyOK, verified = pcall(cvar.GetCVar, "tooltipShowAuraSpellIDs")
    Service.auraIDDisplayEnabled = verifyOK
        and Util.isSafeString
        and Util.isSafeString(verified)
        and verified == "1"
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

local function onModifierStateChanged(_, _, down)
    if down == 1 then
        tryOpenMenu()
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

    enableAuraIDDisplay()
    local types = api.TooltipDataType
    if types then
        registerPostCall(types.Spell, onSpellTooltip)
        registerPostCall(types.Item, onItemTooltip)
        registerPostCall(types.UnitAura, onAuraTooltip)
        registerPostCall(types.Macro, onMacroTooltip)
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

function Service.getStatus()
    return {
        initialized = Service.initialized,
        postCallCount = Service.postCallCount,
        auraIDDisplayEnabled = Service.auraIDDisplayEnabled,
        candidateCount = Service.candidateCount,
        menuOpenCount = Service.menuOpenCount,
        commitCount = Service.commitCount,
        rejectCount = Service.rejectCount,
        lastReason = Service.lastReason,
    }
end

if EAM.FlowTestEnvironment == "offline-mock" then
    Service._clearCandidateForTest = clearCandidate
    Service._tryOpenMenuForTest = tryOpenMenu
end
