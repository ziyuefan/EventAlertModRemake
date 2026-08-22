--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/RuntimeProbe
檔案: Debug\RuntimeProbe.lua

理念:
- P3 實機驗證需要一個低風險、on-demand 的環境診斷入口。
- 診斷只確認 API / widget / template 是否存在，不嘗試繞過 Secret 或 Protected Data。

責任:
- 提供 `/eam doctor` 與 `/eam validate` 可使用的 Retail/PTR feature detection。
- 輸出 build、Interface、combat 狀態、API 可用性與需要實機確認的降級資訊。

資料所有權:
- 擁有 transient probe snapshot；不寫 SavedVariables。
- 不擁有 service state、renderer state 或 UI frame pool。

可變狀態:
- 只在使用者明確呼叫診斷時建立短生命週期 table。
- frame template probe 只在非戰鬥中執行，且建立後立即 hide。

邊界:
- 不讀取 aura/cooldown facts，不處理 secret value。
- 不呼叫 debugstack/debuglocals，避免把 secret-tainted stack/local 輸出。
- 不把 PTR API 當成正式服必定存在；只回報 available/missing。

效能注意:
- 非 hot path；允許少量 transient table 與字串輸出。
- 不註冊事件、不使用 OnUpdate、不建立 timer。

Retail API 注意:
- 12.0.7 PTR API 以 feature detection 處理，例如 DurationTextBinding、C_UIFileAsset、GameTooltip_AddMoneyLine。
- Classic/PTR Classic 內容不進入本模組。
]]
local _, EAM = ...

local RuntimeProbe = {}
EAM.Debug.RuntimeProbe = RuntimeProbe

local api = EAM.API or {}
local util = EAM.Util or {}
local createTable = util.tableCreate or function()
    return {}
end

local stringFormat = string.format

local STATUS_AVAILABLE = "available"
local STATUS_MISSING = "missing"
local STATUS_DEFERRED = "deferred"
local STATUS_EXPECTED_MISSING = "expectedMissing"
local STATUS_AVOID = "avoid"
local STATUS_WARNING = "warning"

local statusText = {
    available = "可用",
    missing = "缺少",
    deferred = "延後",
    expectedMissing = "符合預期缺少",
    avoid = "存在但避免使用",
    warning = "需注意",
}

local function hasFunction(owner, name)
    return type(owner) == "table" and type(owner[name]) == "function"
end

local function functionStatus(owner, name)
    if hasFunction(owner, name) then
        return STATUS_AVAILABLE
    end
    return STATUS_MISSING
end

local function addCapability(snapshot, key, label, status, note)
    local capabilities = snapshot.capabilities
    local index = #capabilities + 1
    capabilities[index] = {
        key = key,
        label = label,
        status = status,
        note = note,
    }
end

local function addFunctionCapability(snapshot, key, label, owner, name, note)
    addCapability(snapshot, key, label, functionStatus(owner, name), note)
end

local function addGlobalCapability(snapshot, key, label, value, note)
    local status = type(value) == "function" and STATUS_AVAILABLE or STATUS_MISSING
    addCapability(snapshot, key, label, status, note)
end

local function addExpectedMissingCapability(snapshot, key, label, owner, name, note)
    local status = hasFunction(owner, name) and STATUS_WARNING or STATUS_EXPECTED_MISSING
    addCapability(snapshot, key, label, status, note)
end

local function addAvoidCapability(snapshot, key, label, value, note)
    local status = type(value) == "function" and STATUS_AVOID or STATUS_EXPECTED_MISSING
    addCapability(snapshot, key, label, status, note)
end

local function probeFrameTemplates(snapshot)
    if api.InCombatLockdown and api.InCombatLockdown() then
        addCapability(snapshot, "templates", "Options / widget template probe", STATUS_DEFERRED, "戰鬥中不建立測試 frame")
        return
    end

    if type(api.CreateFrame) ~= "function" or not UIParent then
        addCapability(snapshot, "templates", "Options / widget template probe", STATUS_MISSING, "CreateFrame 或 UIParent 不可用")
        return
    end

    local ok, frame = pcall(api.CreateFrame, "Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    if not ok or not frame then
        addCapability(snapshot, "template.basicFrame", "BasicFrameTemplateWithInset", STATUS_MISSING, tostring(frame))
        return
    end

    frame:Hide()
    addCapability(snapshot, "template.basicFrame", "BasicFrameTemplateWithInset", STATUS_AVAILABLE, nil)

    local editOk, editBox = pcall(api.CreateFrame, "EditBox", nil, frame, "InputBoxTemplate")
    if editOk and editBox then
        addCapability(snapshot, "template.inputBox", "InputBoxTemplate", STATUS_AVAILABLE, nil)
    else
        addCapability(snapshot, "template.inputBox", "InputBoxTemplate", STATUS_MISSING, tostring(editBox))
    end

    local buttonOk, button = pcall(api.CreateFrame, "Button", nil, frame, "UIPanelButtonTemplate")
    if buttonOk and button then
        addCapability(snapshot, "template.panelButton", "UIPanelButtonTemplate", STATUS_AVAILABLE, nil)
    else
        addCapability(snapshot, "template.panelButton", "UIPanelButtonTemplate", STATUS_MISSING, tostring(button))
    end

    local fontString = frame.CreateFontString and frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if fontString and type(fontString.ClearText) == "function" then
        addCapability(snapshot, "fontString.clearText", "FontString:ClearText", STATUS_AVAILABLE, nil)
    else
        addCapability(snapshot, "fontString.clearText", "FontString:ClearText", STATUS_MISSING, nil)
    end

    local cooldownOk, cooldown = pcall(api.CreateFrame, "Cooldown", nil, frame, "CooldownFrameTemplate")
    if cooldownOk and cooldown and type(cooldown.SetCooldownFromDurationObject) == "function" then
        addCapability(snapshot, "cooldown.durationObject", "Cooldown:SetCooldownFromDurationObject", STATUS_AVAILABLE, nil)
    elseif cooldownOk and cooldown then
        addCapability(snapshot, "cooldown.durationObject", "Cooldown:SetCooldownFromDurationObject", STATUS_MISSING, nil)
    else
        addCapability(snapshot, "cooldown.durationObject", "CooldownFrameTemplate", STATUS_MISSING, tostring(cooldown))
    end
end

local function collectCapabilities(snapshot, runFrameProbe)
    addFunctionCapability(snapshot, "unitAuras.index", "C_UnitAuras.GetAuraDataByIndex", api.C_UnitAuras, "GetAuraDataByIndex", "AuraService full scan")
    addFunctionCapability(snapshot, "unitAuras.instance", "C_UnitAuras.GetAuraDataByAuraInstanceID", api.C_UnitAuras, "GetAuraDataByAuraInstanceID", "AuraService delta cache")
    addFunctionCapability(snapshot, "spell.cooldown", "C_Spell.GetSpellCooldown", api.C_Spell, "GetSpellCooldown", "spell cooldown facts")
    addFunctionCapability(snapshot, "spell.charges", "C_Spell.GetSpellCharges", api.C_Spell, "GetSpellCharges", "charge cooldown facts")
    addFunctionCapability(snapshot, "spell.info", "C_Spell.GetSpellInfo", api.C_Spell, "GetSpellInfo", "spell name/icon cache")
    addFunctionCapability(snapshot, "item.cooldown", "C_Item.GetItemCooldown", api.C_Item, "GetItemCooldown", "item cooldown facts")

    addFunctionCapability(snapshot, "duration.create", "C_DurationUtil.CreateDuration", api.C_DurationUtil, "CreateDuration", "DurationObject base")
    addFunctionCapability(snapshot, "duration.textBinding", "C_DurationUtil.CreateDurationTextBinding", api.C_DurationUtil, "CreateDurationTextBinding", "12.0.7 PTR feature")
    addFunctionCapability(snapshot, "duration.manualClock", "C_DurationUtil.CreateManualClock", api.C_DurationUtil, "CreateManualClock", "12.0.7 PTR feature")
    addExpectedMissingCapability(snapshot, "duration.removedCurrentTime", "C_DurationUtil.GetCurrentTime", api.C_DurationUtil, "GetCurrentTime", "12.0.7 移除項，存在時需複核")

    addFunctionCapability(snapshot, "fileAsset.fileID", "C_UIFileAsset.GetFileID", api.C_UIFileAsset, "GetFileID", "12.0.7 PTR feature")
    addFunctionCapability(snapshot, "fileAsset.known", "C_UIFileAsset.IsKnownFile", api.C_UIFileAsset, "IsKnownFile", "12.0.7 PTR feature")
    addFunctionCapability(snapshot, "fileAsset.loose", "C_UIFileAsset.IsLooseFile", api.C_UIFileAsset, "IsLooseFile", "12.0.7 PTR feature")

    addGlobalCapability(snapshot, "tooltip.moneyLine", "GameTooltip_AddMoneyLine", api.GameTooltip_AddMoneyLine, "12.0.7 PTR tooltip money path")
    addAvoidCapability(snapshot, "tooltip.setMoney", "SetTooltipMoney", api.SetTooltipMoney, "舊 money tooltip path；存在也避免使用")
    addFunctionCapability(snapshot, "tooltip.postCall", "TooltipDataProcessor.AddTooltipPostCall", api.TooltipDataProcessor, "AddTooltipPostCall", "EAM ID display callback")
    addGlobalCapability(snapshot, "tooltip.actionInfo", "GetActionInfo", api.GetActionInfo, "macro action source verification")
    addGlobalCapability(snapshot, "tooltip.macroSpell", "GetMacroSpell", api.GetMacroSpell, "macro spell resolution")
    addGlobalCapability(snapshot, "tooltip.macroItem", "GetMacroItem", api.GetMacroItem, "macro item resolution")
    addFunctionCapability(snapshot, "tooltip.auraIDCVar", "C_CVar.SetCVar", api.C_CVar, "SetCVar", "12.1 tooltipShowAuraSpellIDs session capability")
    addGlobalCapability(snapshot, "tooltip.modifierCtrl", "IsControlKeyDown", api.IsControlKeyDown, "EAM Popup modifier chord")
    addGlobalCapability(snapshot, "tooltip.modifierAlt", "IsAltKeyDown", api.IsAltKeyDown, "EAM Popup modifier chord")

    addGlobalCapability(snapshot, "secret.canAccessTable", "canaccesstable", api.canaccesstable, "Secret boundary predicate")
    addGlobalCapability(snapshot, "secret.canAccessValue", "canaccessvalue", api.canaccessvalue, "Secret boundary predicate")
    addGlobalCapability(snapshot, "secret.isSecretValue", "issecretvalue", api.issecretvalue, "Secret boundary predicate")

    addGlobalCapability(snapshot, "profile.eventCPU", "GetEventCPUUsage", api.GetEventCPUUsage, "on-demand profiling only")
    addGlobalCapability(snapshot, "profile.functionCPU", "GetFunctionCPUUsage", api.GetFunctionCPUUsage, "on-demand profiling only")
    addGlobalCapability(snapshot, "profile.scriptCPU", "GetScriptCPUUsage", api.GetScriptCPUUsage, "on-demand profiling only")

    if runFrameProbe then
        probeFrameTemplates(snapshot)
    else
        addCapability(snapshot, "templates", "Options / widget template probe", STATUS_DEFERRED, "使用 /eam doctor 執行實體 frame probe")
    end
end

local function countStatuses(capabilities)
    local counts = {
        available = 0,
        missing = 0,
        deferred = 0,
        expectedMissing = 0,
        avoid = 0,
        warning = 0,
    }

    for index = 1, #capabilities do
        local status = capabilities[index].status or STATUS_MISSING
        counts[status] = (counts[status] or 0) + 1
    end

    return counts
end

function RuntimeProbe.snapshot(options)
    local runFrameProbe = options and options.runFrameProbe == true
    local version, build, buildDate, tocVersion
    if api.GetBuildInfo then
        version, build, buildDate, tocVersion = api.GetBuildInfo()
    end

    local snapshot = {
        environment = {
            addonVersion = EAM.version,
            expectedInterface = EAM.Constants and EAM.Constants.INTERFACE or 0,
            clientVersion = version,
            clientBuild = build,
            clientBuildDate = buildDate,
            clientInterface = tocVersion,
            locale = api.GetLocale and api.GetLocale() or nil,
            inCombat = api.InCombatLockdown and api.InCombatLockdown() or false,
            initialized = EAM.Modules and EAM.Modules.Main and EAM.Modules.Main.initialized or false,
        },
        capabilities = createTable(32, 0),
        boundaryWarnings = createTable(0, 4),
    }

    collectCapabilities(snapshot, runFrameProbe)
    local auraCapability = EAM.Services.AuraCapabilityService
    local auraContainer = EAM.Services.AuraContainerService
    local auraSound = EAM.Services.AuraSoundService
    snapshot.nativeAura = {
        capability = auraCapability and auraCapability.getSnapshot and auraCapability.getSnapshot() or nil,
        container = auraContainer and auraContainer.getStatus and auraContainer.getStatus() or nil,
        sound = auraSound and auraSound.getStatus and auraSound.getStatus() or nil,
    }
    local tooltipMonitor = EAM.Services.TooltipMonitorService
    snapshot.tooltipMonitor = tooltipMonitor and tooltipMonitor.getStatus and tooltipMonitor.getStatus() or nil
    local groundEffect = EAM.Services.GroundEffectService
    snapshot.groundEffect = groundEffect and groundEffect.getStatus and groundEffect.getStatus() or nil
    snapshot.summary = countStatuses(snapshot.capabilities)

    return snapshot
end

function RuntimeProbe.buildLines(snapshot)
    local lines = createTable(40, 0)
    local env = snapshot.environment or {}
    local summary = snapshot.summary or {}

    lines[#lines + 1] = "|cff00ff96EAM Doctor|r Retail/PTR feature detection"
    lines[#lines + 1] = stringFormat("build=%s (%s), clientInterface=%s, expected=%s, combat=%s",
        tostring(env.clientVersion or "unknown"),
        tostring(env.clientBuild or "unknown"),
        tostring(env.clientInterface or "unknown"),
        tostring(env.expectedInterface or "unknown"),
        tostring(env.inCombat == true))
    lines[#lines + 1] = stringFormat("capabilities: 可用=%d, 缺少=%d, 符合預期缺少=%d, 延後=%d, 避免=%d, 警告=%d",
        summary.available or 0,
        summary.missing or 0,
        summary.expectedMissing or 0,
        summary.deferred or 0,
        summary.avoid or 0,
        summary.warning or 0)

    local nativeAura = snapshot.nativeAura or {}
    local nativeCapability = nativeAura.capability or {}
    local nativeContainer = nativeAura.container or {}
    local nativeSound = nativeAura.sound or {}
    lines[#lines + 1] = stringFormat(
        "nativeAura: backend=%s, pending=%s, rebuild=%d, failed=%d, slots=%d, groups=%d, sounds=%d, limitation=%s",
        tostring(nativeCapability.selectedBackend or "UNSUPPORTED"),
        tostring(nativeContainer.pending == true),
        nativeContainer.rebuildCount or 0,
        nativeContainer.failedRebuildCount or 0,
        nativeContainer.nativeSlotCount or 0,
        nativeContainer.nativeGroupCount or 0,
        nativeSound.activeCount or 0,
        tostring(nativeCapability.limitationReason or nativeContainer.lastReason or "none")
    )

    local tooltipMonitor = snapshot.tooltipMonitor or {}
    lines[#lines + 1] = stringFormat(
        "tooltipMonitor: callbacks=%d, auraIDCVar=%s, candidates=%d, menus=%d, commits=%d, rejects=%d, reason=%s",
        tooltipMonitor.postCallCount or 0,
        tostring(tooltipMonitor.auraIDDisplayEnabled == true),
        tooltipMonitor.candidateCount or 0,
        tooltipMonitor.menuOpenCount or 0,
        tooltipMonitor.commitCount or 0,
        tooltipMonitor.rejectCount or 0,
        tostring(tooltipMonitor.lastReason or "none")
    )

    -- 7 大獨立告警框架的偵測診斷 (為少年欸目標性提供實機測試資訊)
    lines[#lines + 1] = "|cff00ff96EAM Multi-Frame Diagnostics|r"
    local directions = { "往右 (→)", "往左 (←)", "往上 (↑)", "往下 (↓)" }
    if EAM.UI.Renderer and EAM.UI.Renderer.frames then
        for fName, fState in pairs(EAM.UI.Renderer.frames) do
            local parentExists = fState.parent ~= nil
            local iconCount = fState.orderCount or 0
            local cfg = EAM.db and EAM.db.layout and EAM.db.layout.frames and EAM.db.layout.frames[fName]
            local dirIdx = cfg and cfg.growDirection or 1
            local dirStr = directions[dirIdx] or "未知"
            local x = cfg and cfg.x or 0
            local y = cfg and cfg.y or 0
            local point = cfg and cfg.point or "CENTER"
            
            lines[#lines + 1] = stringFormat("- 框架 [%s]: 已建立=%s, 當前圖示數=%d, 成長方向=%s, 坐標=(%s, %.1f, %.1f)",
                tostring(fName),
                tostring(parentExists),
                iconCount,
                dirStr,
                point,
                x,
                y)
        end
    else
        lines[#lines + 1] = "- 警告: 渲染器框架資料表不可用！"
    end

    -- 3 個新增服務狀態偵測
    lines[#lines + 1] = "|cff00ff96EAM New Services Diagnostics|r"
    local services = {
        { name = "職業特殊能量監控 (ClassPowerService)", mod = EAM.Services.ClassPowerService },
        { name = "無光環地面技能監控 (GroundEffectService)", mod = EAM.Services.GroundEffectService },
        { name = "圖騰狀態監控 (TotemService)", mod = EAM.Services.TotemService },
    }
    for _, s in ipairs(services) do
        local loaded = s.mod ~= nil
        lines[#lines + 1] = stringFormat("- %s: 已加載=%s", s.name, tostring(loaded))
    end

    lines[#lines + 1] = "|cff00ff96EAM API Capabilities|r"

    for index = 1, #snapshot.capabilities do
        local item = snapshot.capabilities[index]
        local readable = statusText[item.status] or tostring(item.status)
        if item.note then
            lines[#lines + 1] = stringFormat("- [%s] %s (%s)", readable, item.label, item.note)
        else
            lines[#lines + 1] = stringFormat("- [%s] %s", readable, item.label)
        end
    end

    return lines
end

function RuntimeProbe.printReport()
    local snapshot = RuntimeProbe.snapshot({ runFrameProbe = true })
    local lines = RuntimeProbe.buildLines(snapshot)
    for index = 1, #lines do
        print(lines[index])
    end
end
