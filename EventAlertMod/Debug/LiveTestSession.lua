--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/LiveTestSession
檔案: Debug\LiveTestSession.lua

理念:
- 玩家操作遊戲、EAM 只記錄人工觀察，形成 PTR／XPTR／正式服可回灌 JSON。

責任:
- 管理 34 個實機案例、規範步驟、匿名能力快照、/reload checkpoint、摘要與 JSON 匯出。

邊界:
- 不施法、不使用物品、不執行巨集、不切換目標、不合成輸入、不呼叫 ReloadUI。
- 不讀帳號、角色、伺服器、AuraData、倒數文字或 applications 原值。
- 戰鬥中不寫入案例、備註、checkpoint 或完成狀態。
]]
local _, EAM = ...

local api = EAM.API or {}
local util = EAM.Util or {}
local freeze = util.tableFreeze or function(value)
    return value
end

local MATRIX_VERSION = "2026-08-14.1"
local PRIVACY_REDACTED_NOTE = "[privacy-redacted]"
local BOOT_TOKEN = {}
local CASES = freeze({
    freeze({ id = "live.environment.identity", category = "environment", labelKey = "EAM_LIVE_CASE_ENVIRONMENT" }),
    freeze({ id = "live.tooltip.spellbook", category = "tooltip", labelKey = "EAM_LIVE_CASE_SPELLBOOK" }),
    freeze({ id = "live.tooltip.actionbar_macro", category = "tooltip", labelKey = "EAM_LIVE_CASE_ACTIONBAR_MACRO" }),
    freeze({ id = "live.tooltip.bag_item", category = "tooltip", labelKey = "EAM_LIVE_CASE_BAG_ITEM" }),
    freeze({ id = "live.tooltip.player_aura", category = "tooltip", labelKey = "EAM_LIVE_CASE_PLAYER_AURA" }),
    freeze({ id = "live.tooltip.target_aura", category = "tooltip", labelKey = "EAM_LIVE_CASE_TARGET_AURA" }),
    freeze({ id = "live.tooltip.out_of_combat", category = "combat", labelKey = "EAM_LIVE_CASE_OUT_OF_COMBAT" }),
    freeze({ id = "live.tooltip.in_combat_rejected", category = "combat", labelKey = "EAM_LIVE_CASE_IN_COMBAT" }),
    freeze({ id = "live.popup.escape_cancel", category = "popup", labelKey = "EAM_LIVE_CASE_ESCAPE_CANCEL" }),
    freeze({ id = "live.popup.commit_added_unchanged", category = "popup", labelKey = "EAM_LIVE_CASE_COMMIT" }),
    freeze({ id = "live.tooltip.reload_resume", category = "reload", labelKey = "EAM_LIVE_CASE_RELOAD" }),
    freeze({ id = "live.blizzard_input_unchanged", category = "input", labelKey = "EAM_LIVE_CASE_INPUT" }),
    freeze({ id = "live.popup.combat_transition", category = "combat", labelKey = "EAM_LIVE_CASE_COMBAT_TRANSITION" }),
    freeze({ id = "live.tooltip.generation_switch", category = "tooltip", labelKey = "EAM_LIVE_CASE_GENERATION" }),
    freeze({ id = "live.api.load_order", category = "lifecycle", labelKey = "EAM_LIVE_CASE_LOAD_ORDER" }),
    freeze({ id = "live.errors.none_observed", category = "safety", labelKey = "EAM_LIVE_CASE_ERRORS" }),
    freeze({ id = "live.layout.timer_anchor_size", category = "layout", labelKey = "EAM_LIVE_CASE_TIMER_LAYOUT" }),
    freeze({ id = "live.layout.applications_anchor_size", category = "layout", labelKey = "EAM_LIVE_CASE_APPLICATIONS_LAYOUT" }),
    freeze({ id = "live.aura.single_countdown", category = "aura", labelKey = "EAM_LIVE_CASE_AURA_SINGLE_COUNTDOWN" }),
    freeze({ id = "live.aura.dual_countdown_diagnostic", category = "aura", labelKey = "EAM_LIVE_CASE_AURA_DUAL_COUNTDOWN" }),
    freeze({ id = "live.cooldown.spell_countdown", category = "cooldown", labelKey = "EAM_LIVE_CASE_SPELL_COOLDOWN" }),
    freeze({ id = "live.cooldown.item_trigger", category = "cooldown", labelKey = "EAM_LIVE_CASE_ITEM_COOLDOWN" }),
    freeze({ id = "live.ground.duration_auto", category = "ground", labelKey = "EAM_LIVE_CASE_GROUND_AUTO" }),
    freeze({ id = "live.ground.duration_manual_fallback", category = "ground", labelKey = "EAM_LIVE_CASE_GROUND_FALLBACK" }),
    freeze({ id = "live.visual.swipe_alpha", category = "visual", labelKey = "EAM_LIVE_CASE_SWIPE_ALPHA" }),
    freeze({ id = "live.aura.target_transition", category = "aura", labelKey = "EAM_LIVE_CASE_TARGET_AURA_TRANSITION" }),
    freeze({ id = "live.aura.native_border_capability", category = "aura", labelKey = "EAM_LIVE_CASE_NATIVE_BORDER" }),
    freeze({ id = "live.aura.native_pandemic_region", category = "aura", labelKey = "EAM_LIVE_CASE_NATIVE_PANDEMIC" }),
    freeze({ id = "live.aura.native_dispel_options", category = "aura", labelKey = "EAM_LIVE_CASE_NATIVE_DISPEL_OPTIONS" }),
    freeze({ id = "live.aura.container_disable_clear", category = "aura", labelKey = "EAM_LIVE_CASE_CONTAINER_DISABLE_CLEAR" }),
    freeze({ id = "live.aura.sound_added", category = "aura", labelKey = "EAM_LIVE_CASE_AURA_SOUND_ADDED" }),
    freeze({ id = "live.aura.sound_applications_increased", category = "aura", labelKey = "EAM_LIVE_CASE_AURA_SOUND_APPLICATIONS" }),
    freeze({ id = "live.aura.sound_removed", category = "aura", labelKey = "EAM_LIVE_CASE_AURA_SOUND_REMOVED" }),
    freeze({ id = "live.unitpower.secondary_numeric", category = "unitpower", labelKey = "EAM_LIVE_CASE_UNITPOWER_SECONDARY" }),
    freeze({ id = "live.unitpower.primary_native_sink", category = "unitpower", labelKey = "EAM_LIVE_CASE_UNITPOWER_PRIMARY" }),
    freeze({ id = "live.unitpower.combat_deferred", category = "unitpower", labelKey = "EAM_LIVE_CASE_UNITPOWER_COMBAT" }),
    freeze({ id = "live.aura.duration_zero_regression", category = "aura", labelKey = "EAM_LIVE_CASE_DURATION_ZERO" }),
})

local CASE_PROCEDURES = freeze({
    ["live.environment.identity"] = [=[確認玩家宣告的安裝目錄與 GetBuildInfo 觀測的 patch、build、Interface 及 test-build 屬性一致。]=],
    ["live.tooltip.spellbook"] = [=[玩家手動停留技能書法術，確認 ID 列、Ctrl+Alt 選單與技能冷卻加入流程。]=],
    ["live.tooltip.actionbar_macro"] = [=[玩家手動停留動作列巨集，確認可安全解析法術／物品，或明確降級為手動輸入。]=],
    ["live.tooltip.bag_item"] = [=[玩家手動停留背包物品，確認物品 ID、Ctrl+Alt 選單與物品冷卻加入流程。]=],
    ["live.tooltip.player_aura"] = [=[玩家手動停留自身光環；Retail／PTR 12.1 使用官方 Aura ID 顯示，XPTR 12.0.7 無能力時採已知 ID 手動輸入。]=],
    ["live.tooltip.target_aura"] = [=[玩家手動停留目標光環；Retail／PTR 12.1 使用官方 Aura ID 顯示，XPTR 12.0.7 無能力時採已知 ID 手動輸入。]=],
    ["live.tooltip.out_of_combat"] = [=[在非戰鬥狀態確認 Tooltip 與加入監控流程可用。]=],
    ["live.tooltip.in_combat_rejected"] = [=[玩家自行進入戰鬥後確認 Ctrl+Alt 不開啟／不重播選單；脫戰後再記錄結果。]=],
    ["live.popup.escape_cancel"] = [=[確認 ESC、取消與關閉不會寫入監控清單。]=],
    ["live.popup.commit_added_unchanged"] = [=[確認第一次加入回報 added，重複加入回報 unchanged，且儲存位置符合來源類型。]=],
    ["live.tooltip.reload_resume"] = [=[先建立 checkpoint，由玩家自行輸入 /reload，回來後確認 session、CVar 與 SavedVariables 行為。]=],
    ["live.blizzard_input_unchanged"] = [=[確認一般左鍵、右鍵與無修飾鍵操作仍維持 Blizzard 原始行為。]=],
    ["live.popup.combat_transition"] = [=[先開啟 EAM 選單再由玩家進入戰鬥，確認選單安全關閉且不執行延後寫入。]=],
    ["live.tooltip.generation_switch"] = [=[快速切換不同 Tooltip，確認只對最新來源開啟，沒有 stale candidate。]=],
    ["live.api.load_order"] = [=[確認 API 初始不可用或 Blizzard LoD 載入後不會重複註冊、重複加入或產生 Lua error。]=],
    ["live.errors.none_observed"] = [=[整輪確認 Lua error、taint、blocked action、Forbidden access 均未觀察到。]=],
    ["live.layout.timer_anchor_size"] = [=[確認倒數至少測試框內、框外、最小 8、預設 14、最大 32 字級，XPTR 12.0.7 與 Retail／PTR 12.1 行為一致。]=],
    ["live.layout.applications_anchor_size"] = [=[確認 applications 至少測試框內八方向、框外八角位與四面，以及最小 8、預設 12、最大 32 字級。]=],
    ["live.aura.single_countdown"] = [=[關閉雙倒數診斷後重建 Native Aura 容器；Retail／PTR 12.1 確認每個光環只顯示一套 EAM 可定位倒數，XPTR 12.0.7確認 Legacy 路徑也只有一套。]=],
    ["live.aura.dual_countdown_diagnostic"] = [=[僅在測試面板啟用雙倒數診斷；Retail／PTR 12.1 由玩家觀察開始、中段、最後 3 秒兩套數字是否同步，完成後關閉。兩者共用同一 DurationObject，不視為獨立資料源；XPTR 12.0.7 確認此 Native 模式不可用且無 Native 呼叫。]=],
    ["live.cooldown.spell_countdown"] = [=[玩家施放已監控且非 GCD 的技能，確認圖示、swipe 與倒數文字同時出現，充能技能消耗一層後也有回充倒數。]=],
    ["live.cooldown.item_trigger"] = [=[玩家使用已監控背包物品，確認 BAG_UPDATE_COOLDOWN 或 12.1 SPELL_UPDATE_COOLDOWN 的 itemID 能觸發正確物品，且其他物品事件不誤觸。]=],
    ["live.ground.duration_auto"] = [=[非戰鬥解析含明確秒數的技能說明，玩家施放後確認報告來源為 spellDescription 或 tooltipDescription，顯示時間符合靜態說明。]=],
    ["live.ground.duration_manual_fallback"] = [=[選用無法解析秒數的地面技能並設定手動秒數，玩家施放後確認來源為 manualFallback、時間採手動值且報告含 groundDurationManualFallback。]=],
    ["live.visual.swipe_alpha"] = [=[分別設定倒數轉圈透明度 0、0.5、1，確認一般冷卻、物品、地面效果與 Retail／PTR 12.1 Native Aura 在重建後皆符合設定。]=],
    ["live.aura.target_transition"] = [=[Retail／PTR 12.1 對 target Aura 測試目標切換、戰鬥內外、單層到多層、有限時間到永久、同 Spell ID 不同施法者；記錄圖示存在但文字空白時屬哪一類，不讀回 FontString。]=],
    ["live.aura.native_border_capability"] = [=[Retail／PTR 12.1 確認 capability 報告是否偵測 AddDispelTypeTexture；只判定官方驅散／靜態 border 能力，不將它宣稱為 Pandemic、Proc 或任意條件 Glow 的替代品。XPTR 12.0.7 應回報不可用。]=],
    ["live.aura.native_pandemic_region"] = [=[Retail／PTR 12.1 啟用單一 Pandemic Region，觀察官方 Pandemic Window 顯示與消失，確認 EAM 不讀 SecretAspect.Shown、不建立自己的 OnUpdate；XPTR 12.0.7 應降級且不呼叫 native API。]=],
    ["live.aura.native_dispel_options"] = [=[Retail／PTR 12.1 觀察 showAlways、Harmful／Helpful 與 Stealable／NotStealable option；確認 showAlways 不再同時輸出無作用的 stealableFilter，且不使用舊 AuraBorder alias。]=],
    ["live.aura.container_disable_clear"] = [=[Retail／PTR 12.1 停用 AuraContainer 後確認 AuraButton 與 ItemEnchantment 顯示資料清除但框架仍存在，重新啟用後不重複建立或產生 Lua error。]=],
    ["live.aura.sound_added"] = [=[Retail／PTR 12.1：在光環細部設定選擇可辨識素材，只勾「光環新增」，並確認全域音效已啟用；玩家手動取得該 player／target Aura，應只播放一次。XPTR 12.0.7 應停用控制項、保留設定且不得呼叫 AddAuraSound。]=],
    ["live.aura.sound_applications_increased"] = [=[Retail／PTR 12.1：只勾「層數增加」，先取得可堆疊 Aura，再由玩家逐層增加；每次增加應各播放一次，初次新增與移除不得誤播。XPTR 12.0.7 應維持 capability 降級。]=],
    ["live.aura.sound_removed"] = [=[Retail／PTR 12.1：只勾「光環移除」，由玩家讓 Aura 自然到期、驅散或實際移除；每次真實移除應播放一次，停用容器、改設定與 /reload 不得冒充 Aura 移除。XPTR 12.0.7 應維持 capability 降級。]=],
    ["live.unitpower.secondary_numeric"] = [=[由玩家切換可產生次要資源的專精並手動產生、消耗、歸零；確認 EAM 選中 HolyPower／ComboPoints／SoulShards／Chi／ArcaneCharges 等次要資源，數值 1 仍顯示。]=],
    ["live.unitpower.primary_native_sink"] = [=[從測試面板啟動 UnitPower 能力探針，由玩家產生／消耗主要資源；Retail／PTR 12.1 觀察 StatusBar 與 radial sink，XPTR 12.0.7 觀察 StatusBar fallback，標記結果並回傳 EAM_UNIT_POWER_CAPABILITY_REPORT。]=],
    ["live.unitpower.combat_deferred"] = [=[Retail／PTR 12.1 與 XPTR 12.0.7 進入戰鬥後觀察資源變化，確認安全 NUMERIC 資源與 Secret resource sink 仍依事件更新；不得以 Lua 讀回或匯出 Secret raw 值，也不得在戰鬥中做結構性重建。脫戰後只驗證 pending 結構變更由事件合併一次，報告保留 combatDeferred 邊界。]=],
    ["live.aura.duration_zero_regression"] = [=[Retail／PTR 12.1 測試永久、零或瞬間結束 Aura，確認 PTR8 修正不再把有效 duration text 錯顯示為 0，無安全 duration 時仍只顯示官方允許的狀態。]=],
})

local CASE_BY_ID = {}
for index = 1, #CASES do
    CASE_BY_ID[CASES[index].id] = CASES[index]
end
CASE_BY_ID = freeze(CASE_BY_ID)

local LiveTestSession = {
    schemaVersion = 1,
    matrixVersion = MATRIX_VERSION,
    cases = CASES,
    caseByID = CASE_BY_ID,
    procedures = CASE_PROCEDURES,
}

EAM.Debug.LiveTestSession = LiveTestSession

local function isUNCComponentByte(byteValue)
    return byteValue ~= nil
        and byteValue ~= 9
        and byteValue ~= 10
        and byteValue ~= 13
        and byteValue ~= 32
        and byteValue ~= 47
        and byteValue ~= 92
end

local function containsUNCPath(value)
    local valueLength = #value
    for index = 1, valueLength - 3 do
        if string.byte(value, index) == 92 and string.byte(value, index + 1) == 92 then
            local serverStart = index + 2
            local cursor = serverStart
            while cursor <= valueLength and isUNCComponentByte(string.byte(value, cursor)) do
                cursor = cursor + 1
            end
            if cursor > serverStart and string.byte(value, cursor) == 92 then
                local shareStart = cursor + 1
                cursor = shareStart
                while cursor <= valueLength and isUNCComponentByte(string.byte(value, cursor)) do
                    cursor = cursor + 1
                end
                if cursor > shareStart then
                    return true
                end
            end
        end
    end
    return false
end

local function nowValue()
    if type(api.GetServerTime) == "function" then
        local ok, value = pcall(api.GetServerTime)
        if ok and type(value) == "number" and not (util.isSecretValue and util.isSecretValue(value)) then
            return value
        end
    end
    if type(api.GetTime) == "function" then
        local value = api.GetTime()
        if type(value) == "number" and not (util.isSecretValue and util.isSecretValue(value)) then
            return math.floor(value)
        end
    end
    return 0
end

local function safeNote(value)
    if type(value) ~= "string" then
        return ""
    end
    if util.isSecretValue and util.isSecretValue(value) then
        return ""
    end
    if util.canAccessValue and not util.canAccessValue(value) then
        return ""
    end
    value = string.gsub(value, "[%z\1-\8\11\12\14-\31]", " ")
    local lowered = string.lower(value)
    local containsSavedVariablesPath = string.find(lowered, "savedvariables", 1, true) ~= nil
    local containsPrivatePath = string.match(value, "%a:[/\\]") ~= nil
        or string.find(lowered, "\\wtf\\", 1, true) ~= nil
        or string.find(lowered, "/wtf/", 1, true) ~= nil
        or string.find(lowered, "\\account\\", 1, true) ~= nil
        or string.find(lowered, "/account/", 1, true) ~= nil
    if containsPrivatePath or containsUNCPath(value) or containsSavedVariablesPath then
        return PRIVACY_REDACTED_NOTE
    end
    local characters = 0
    for index = 1, #value do
        local byte = string.byte(value, index)
        if byte < 128 or byte >= 192 then
            characters = characters + 1
            if characters > 500 then
                return string.sub(value, 1, index - 1)
            end
        end
    end
    return value
end

local function hasReloadEvidence(state)
    return state
        and state.resumedAfterReload == true
        and type(state.reloadSequence) == "number"
        and state.reloadSequence >= 1
end

local function validState(state)
    return type(state) == "table"
        and state.schema == LiveTestSession.schemaVersion
        and state.matrixVersion == MATRIX_VERSION
        and type(state.cases) == "table"
end

local function getState()
    local state = _G.EAM_LIVE_TEST_SESSION
    return validState(state) and state or nil
end

local function createCaseState()
    local caseState = {}
    for index = 1, #CASES do
        caseState[CASES[index].id] = {
            status = "pending",
            note = "",
        }
    end
    return caseState
end

local function buildSessionID(declaredInstallation, sequence)
    local normalized = string.gsub(declaredInstallation, "[^%w]", "")
    return string.format("EAM-RQA-%s-%d-%d", normalized, nowValue(), sequence)
end

local function collectCapabilities()
    local auraCapability = EAM.Services and EAM.Services.AuraCapabilityService
    local tooltipMonitor = EAM.Services and EAM.Services.TooltipMonitorService
    local auraSnapshot = auraCapability and auraCapability.getSnapshot and auraCapability.getSnapshot() or {}
    local tooltipStatus = tooltipMonitor and tooltipMonitor.getStatus and tooltipMonitor.getStatus() or {}
    local nativeRenderer = EAM.UI and EAM.UI.NativeAuraRenderer
    local nativeStatus = nativeRenderer and nativeRenderer.getStatus and nativeRenderer.getStatus() or {}
    local groundEffect = EAM.Services and EAM.Services.GroundEffectService
    local groundStatus = groundEffect and groundEffect.getStatus and groundEffect.getStatus() or {}
    local cSecrets = api.C_Secrets
    return {
        hasGetBuildInfo = type(api.GetBuildInfo) == "function",
        hasTooltipDataProcessor = type(_G.TooltipDataProcessor) == "table"
            and type(_G.TooltipDataProcessor.AddTooltipPostCall) == "function",
        hasTooltipMonitor = tooltipMonitor and tooltipMonitor.initialized == true or false,
        auraBackend = type(auraSnapshot.selectedBackend) == "string" and auraSnapshot.selectedBackend or "unknown",
        hasAuraContainer = auraSnapshot.hasAuraContainer == true,
        hasAuraSlot = auraSnapshot.hasAuraSlot == true,
        hasAuraGroup = auraSnapshot.hasAuraGroup == true,
        auraSpellIDDisplayEnabled = tooltipStatus.auraIDDisplayEnabled == true,
        hasTextPlacementContract = EAM.UI and EAM.UI.TextPlacement ~= nil or false,
        hasDurationAdapter = EAM.Modules and EAM.Modules.DurationAdapter ~= nil or false,
        nativeAuraSingleCountdownDefault = nativeStatus.dualCountdownProbeEnabled ~= true,
        nativeAuraDispelBorderAvailable = nativeStatus.nativeDispelBorderAvailable == true,
        nativeAuraPandemicRegionAvailable = nativeStatus.hasPandemicRegionAPI == true,
        nativeAuraPandemicRegionBoundCount = nativeStatus.pandemicRegionBoundCount or 0,
        nativeAuraDispelTextureBoundCount = nativeStatus.nativeDispelTextureBoundCount or 0,
        hasUnitPower = type(api.UnitPower) == "function",
        hasUnitPowerMax = type(api.UnitPowerMax) == "function",
        hasUnitPowerPercent = type(api.UnitPowerPercent) == "function",
        hasUnitPowerSecretPredicate = cSecrets
            and type(cSecrets.ShouldUnitPowerBeSecret) == "function" or false,
        hasUnitPowerMaxSecretPredicate = cSecrets
            and type(cSecrets.ShouldUnitPowerMaxBeSecret) == "function" or false,
        hasUnitPowerCapabilityProbe = EAM.Debug and EAM.Debug.UnitPowerCapabilityProbe ~= nil or false,
        groundEffectStatus = groundStatus,
    }
end

local function buildReport()
    local state = getState()
    if not state then
        return nil, nil, "sessionUnavailable"
    end
    local validationEnvironment = EAM.Debug.ValidationEnvironment
    local environment, environmentWarnings = validationEnvironment.snapshot()
    local reportCases = {}
    local summary = {
        total = #CASES,
        required = #CASES,
        passed = 0,
        failed = 0,
        blocked = 0,
        pending = 0,
    }
    local privacyNoteRedacted = false
    for index = 1, #CASES do
        local definition = CASES[index]
        local savedCase = state.cases[definition.id] or {}
        local status = savedCase.status
        if status ~= "pass" and status ~= "fail" and status ~= "blocked" then
            status = "pending"
        end
        if status == "pass" then
            summary.passed = summary.passed + 1
        elseif status == "fail" then
            summary.failed = summary.failed + 1
        elseif status == "blocked" then
            summary.blocked = summary.blocked + 1
        else
            summary.pending = summary.pending + 1
        end
        local note = safeNote(savedCase.note)
        if note == PRIVACY_REDACTED_NOTE then
            privacyNoteRedacted = true
        end
        reportCases[index] = {
            id = definition.id,
            category = definition.category,
            required = true,
            status = status,
            note = note,
        }
    end

    local warnings = {}
    for index = 1, #environmentWarnings do
        warnings[#warnings + 1] = environmentWarnings[index]
    end
    if privacyNoteRedacted then
        warnings[#warnings + 1] = "privacyNoteRedacted"
    end
    if not hasReloadEvidence(state) then
        warnings[#warnings + 1] = "reloadCheckpointNotCompleted"
    end
    if environment.executionSource ~= "client" then
        warnings[#warnings + 1] = "offlineCannotSignoff"
    end

    local status = "pass"
    if summary.failed > 0 then
        status = "fail"
    elseif summary.blocked > 0
        or summary.pending > 0
        or state.phase ~= "complete"
        or environment.channelValidation ~= "pass"
        or environment.executionSource ~= "client"
        or #warnings > 0
    then
        status = "incomplete"
    end

    local report = {
        schema = LiveTestSession.schemaVersion,
        type = "EAM_LIVE_VALIDATION_REPORT",
        purpose = "rqa-signoff",
        matrixVersion = MATRIX_VERSION,
        status = status,
        session = {
            id = state.id,
            phase = state.phase,
            reloadSequence = state.reloadSequence or 0,
            resumedAfterReload = state.resumedAfterReload == true,
            humanObserved = true,
        },
        environment = environment,
        automation = {
            gameInputAutomated = false,
            reloadUIAutomated = false,
            playerOperated = true,
        },
        capabilities = collectCapabilities(),
        summary = summary,
        cases = reportCases,
        boundaryWarnings = warnings,
    }
    local encoder = EAM.Debug.FlowTestRunner and EAM.Debug.FlowTestRunner.encodeJSON
    if not encoder then
        return report, nil, "jsonEncoderUnavailable"
    end
    local reportJSON = encoder(report)
    _G.EAM_LIVE_TEST_REPORT_JSON = reportJSON
    return report, reportJSON, nil
end

local function reportReadyForCompletion(report)
    return report
        and report.summary.total == #CASES
        and report.summary.passed == #CASES
        and report.summary.failed == 0
        and report.summary.blocked == 0
        and report.summary.pending == 0
        and report.environment.executionSource == "client"
        and report.environment.channelValidation == "pass"
        and report.environment.isTestBuildKnown == true
        and #report.boundaryWarnings == 0
end

function LiveTestSession.getState()
    return getState()
end

function LiveTestSession.start(declaredInstallation)
    local existing = getState()
    if existing and existing.phase == "active" then
        return false, "sessionAlreadyActive"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    local validationEnvironment = EAM.Debug.ValidationEnvironment
    local ok, reason = validationEnvironment.setDeclaredInstallation(declaredInstallation)
    if not ok then
        return false, reason
    end
    local sequence = existing and (existing.sequence or 0) + 1 or 1
    _G.EAM_LIVE_TEST_SESSION = {
        schema = LiveTestSession.schemaVersion,
        matrixVersion = MATRIX_VERSION,
        id = buildSessionID(declaredInstallation, sequence),
        sequence = sequence,
        phase = "active",
        declaredInstallation = declaredInstallation,
        startedAt = nowValue(),
        reloadSequence = 0,
        resumedAfterReload = false,
        reloadCheckpoint = nil,
        cases = createCaseState(),
    }
    buildReport()
    return true, _G.EAM_LIVE_TEST_SESSION.id
end

function LiveTestSession.setCaseStatus(caseID, status, note)
    local state = getState()
    if not state or state.phase ~= "active" then
        return false, "sessionUnavailable"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    if not CASE_BY_ID[caseID] then
        return false, "unknownCase"
    end
    if status ~= "pending" and status ~= "pass" and status ~= "fail" and status ~= "blocked" then
        return false, "invalidStatus"
    end
    local savedCase = state.cases[caseID]
    savedCase.status = status
    if note ~= nil then
        savedCase.note = safeNote(note)
    end
    savedCase.observedAt = nowValue()
    buildReport()
    return true, status
end

function LiveTestSession.setCaseNote(caseID, note)
    local state = getState()
    if not state or not state.cases[caseID] then
        return false, "sessionUnavailable"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    state.cases[caseID].note = safeNote(note)
    buildReport()
    return true
end

function LiveTestSession.prepareReload()
    local state = getState()
    if not state or state.phase ~= "active" then
        return false, "sessionUnavailable"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    state.reloadCheckpoint = {
        pending = true,
        requestedAt = nowValue(),
        expectedSequence = (state.reloadSequence or 0) + 1,
        bootToken = BOOT_TOKEN,
    }
    buildReport()
    return true, "checkpointSaved"
end

function LiveTestSession.resumePendingReload()
    local state = getState()
    local checkpoint = state and state.reloadCheckpoint
    if not checkpoint or checkpoint.pending ~= true then
        return false, "checkpointUnavailable"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    if checkpoint.bootToken == BOOT_TOKEN then
        return false, "sameLoadRejected"
    end
    checkpoint.pending = false
    checkpoint.bootToken = nil
    checkpoint.resumed = true
    checkpoint.resumedAt = nowValue()
    state.reloadSequence = checkpoint.expectedSequence or ((state.reloadSequence or 0) + 1)
    state.resumedAfterReload = true
    buildReport()
    return true, "checkpointResumed"
end

function LiveTestSession.buildReport()
    return buildReport()
end

function LiveTestSession.complete()
    local state = getState()
    if not state then
        return false, "sessionUnavailable"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    if not hasReloadEvidence(state) then
        local report = buildReport()
        return false, "reloadRequired", report
    end
    local report = buildReport()
    if not reportReadyForCompletion(report) then
        return false, "sessionIncomplete", report
    end
    state.phase = "complete"
    report = buildReport()
    return true, "complete", report
end

function LiveTestSession.cancel()
    local state = getState()
    if not state or state.phase ~= "active" then
        return false, "sessionUnavailable"
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    _G.EAM_LIVE_TEST_SESSION = nil
    _G.EAM_LIVE_TEST_REPORT_JSON = nil
    return true, "cancelled"
end

LiveTestSession.resumePendingReload()
