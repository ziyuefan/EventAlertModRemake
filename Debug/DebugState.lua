--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/DebugState
檔案: Debug\DebugState.lua

理念:
- Debug snapshot 提供 AI 與人工分析用的最小結構化狀態。
- facts/derived/boundaryWarnings 分離，避免把猜測當事實。

責任:
- 日後收集各模組 snapshot 並組合 DebugSnapshot。

資料所有權:
- 擁有 transient debug snapshot records。

可變狀態:
- 只 mutate debug/session records；不寫 SavedVariables hot path。

邊界:
- Debug 預設關閉。
- 不輸出巨大 log，不讀取 secret value。

效能注意:
- snapshot/export on-demand；不在 event hot path 組大字串。

Retail API 注意:
- environment 欄位記錄 Interface/flavor；不宣稱未實測結果。

]]
local _, EAM = ...

local DebugState = {}
EAM.Debug.DebugState = DebugState

local function countTableEntries(source)
    local count = 0
    if type(source) ~= "table" then
        return 0
    end

    for _ in pairs(source) do
        count = count + 1
    end
    return count
end

local function collectWarnings(target, states, source)
    if type(states) ~= "table" then
        return
    end

    for id, state in pairs(states) do
        local warnings = state and state.boundaryWarnings
        if type(warnings) == "table" then
            for index = 1, #warnings do
                target[#target + 1] = {
                    id = id,
                    source = source,
                    code = warnings[index],
                }
            end
        end
    end
end

function DebugState.snapshot()
    local auraService = EAM.Services and EAM.Services.AuraService
    local cooldownService = EAM.Services and EAM.Services.CooldownService
    local itemCooldownService = EAM.Services and EAM.Services.ItemCooldownService
    local savedVariables = EAM.Modules and EAM.Modules.SavedVariables
    local renderer = EAM.UI and EAM.UI.Renderer
    local db = EAM.db

    local boundaryWarnings = {}
    collectWarnings(boundaryWarnings, auraService and auraService.states, "AuraService")
    collectWarnings(boundaryWarnings, cooldownService and cooldownService.states, "CooldownService")
    collectWarnings(boundaryWarnings, itemCooldownService and itemCooldownService.states, "ItemCooldownService")

    return {
        facts = {
            auraStates = auraService and auraService.states or {},
            cooldownStates = cooldownService and cooldownService.states or {},
            itemCooldownStates = itemCooldownService and itemCooldownService.states or {},
        },
        derived = {
            migrationReport = savedVariables and savedVariables.migrationReport or nil,
            dbRevision = db and db.revision or 0,
            flowValidation = EAM.Debug.FlowTestRunner and EAM.Debug.FlowTestRunner.getLastSummary() or nil,
            auraCache = auraService and {
                playerInstances = countTableEntries(auraService.unitCaches and auraService.unitCaches.player and auraService.unitCaches.player.byInstance),
                targetInstances = countTableEntries(auraService.unitCaches and auraService.unitCaches.target and auraService.unitCaches.target.byInstance),
            } or nil,
            renderer = renderer and (function()
                local visibleCount = 0
                local anyLayoutDirty = false
                if renderer.frames then
                    for _, fState in pairs(renderer.frames) do
                        visibleCount = visibleCount + (fState.orderCount or 0)
                        if fState.layoutDirty then
                            anyLayoutDirty = true
                        end
                    end
                end
                return {
                    visibleIcons = visibleCount,
                    deferred = renderer.deferredCount or 0,
                    layoutDirty = anyLayoutDirty,
                }
            end)() or nil,
        },
        humanNotes = {},
        boundaryWarnings = boundaryWarnings,
        environment = {
            interface = EAM.Constants.INTERFACE,
            flavor = EAM.Constants.ADDON_FLAVOR,
            initialized = EAM.Modules.Main and EAM.Modules.Main.initialized or false,
            inCombat = EAM.API.InCombatLockdown and EAM.API.InCombatLockdown() or false,
            fps = EAM.API.GetFramerate and EAM.API.GetFramerate() or nil,
        },
    }
end

function DebugState.printSummary()
    local snapshot = DebugState.snapshot()
    local report = snapshot.derived.migrationReport
    if report then
        print("EventAlertMod Retail rewrite: imported " .. tostring(report.imported) .. " legacy alerts, skipped " .. tostring(report.skipped) .. ", boundary warnings " .. tostring(#snapshot.boundaryWarnings) .. ".")
    else
        print("EventAlertMod Retail rewrite: debug snapshot available.")
    end
end
