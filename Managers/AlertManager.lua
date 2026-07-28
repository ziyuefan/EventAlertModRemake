--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Managers/AlertManager
檔案: d:\EventAlertMod\Managers\AlertManager.lua

理念:
- 作為 EAM 的警報決策與協調器 (Controller)，解耦數據服務 (Services) 與視圖渲染 (UI)。
- 監聽 EAM_AURA_STATE_CHANGED 事件，決定何時繪製 UI。
- 採用非同步節流 (Throttle) 與批次 (Batch) 策略，在同一 Frame 內合併多次更新，只觸發一次 Layout 重排，降低 GC Churn 與 CPU 抖動。

責任:
- 監聽 EventRouter 發送的警報變更事件。
- 對光環等警報狀態進行排程與合併更新。
- 呼叫 Renderer.BeginBatch / Renderer.EndBatch 驅動渲染器。
- 渲染隱藏結束後，調用 AuraService.AuraStatePool.release 回收對象。

資料所有權:
- 擁有 pendingAuraUpdates 與 throttle 任務記錄。
- 不擁有 AlertState 或是 SavedVariables。

可變狀態:
- 只 mutate 本地 queue 變數與 isPending 標記。
]]

local _, EAM = ...
local api = EAM.API
local Util = EAM.Util

local AlertManager = {
    pendingUpdates = {},
    isPending = false,
}

EAM.Managers = EAM.Managers or {}
EAM.Managers.AlertManager = AlertManager

-- 批次更新處理
local function flushUpdates()
    AlertManager.isPending = false

    local Renderer = EAM.UI and EAM.UI.Renderer
    if not Renderer or not Renderer.render then
        return
    end

    -- 啟用 Renderer 批次渲染模式，延後 Layout
    if Renderer.BeginBatch then
        Renderer.BeginBatch()
    end

    for id, update in pairs(AlertManager.pendingUpdates) do
        local state = update.state
        local frameName = update.frameName
        
        Renderer.render(state, frameName)
        
        -- 若此告警已隱藏（shown == false），且已完成渲染，多型調用其 releaseFunc 安全回收 state Table
        if not state.shown and state.releaseFunc then
            state.releaseFunc(state)
        end
        
        AlertManager.pendingUpdates[id] = nil
    end

    -- 結束 Renderer 批次渲染模式，這會一次性重排所有受影響的 Layout 框架
    if Renderer.EndBatch then
        Renderer.EndBatch()
    end
end

-- 儲存當前原生處於發光狀態的技能列表
local glowSpells = {}

local function updateGlowForActiveStates(spellID, hasGlow)
    local AuraService = EAM.Services and EAM.Services.AuraService
    local CooldownService = EAM.Services and EAM.Services.CooldownService
    local GroundEffectService = EAM.Services and EAM.Services.GroundEffectService

    if AuraService and AuraService.states then
        for id, state in pairs(AuraService.states) do
            if state.spellID == spellID then
                state.overlayGlow = hasGlow
                local frameName = state.unit == "target" and EAM.Constants.ALERT_FRAME_TYPES.targetAura or EAM.Constants.ALERT_FRAME_TYPES.selfAura
                AlertManager.onAlertStateChanged(nil, state, frameName)
            end
        end
    end

    if CooldownService and CooldownService.states then
        for id, state in pairs(CooldownService.states) do
            if state.spellID == spellID then
                state.overlayGlow = hasGlow
                AlertManager.onAlertStateChanged(nil, state, EAM.Constants.ALERT_FRAME_TYPES.spellCooldown)
            end
        end
    end

    if GroundEffectService and GroundEffectService.activeStates then
        for id, state in pairs(GroundEffectService.activeStates) do
            if state.spellID == spellID then
                state.overlayGlow = hasGlow
                AlertManager.onAlertStateChanged(nil, state, EAM.Constants.ALERT_FRAME_TYPES.groundEffect)
            end
        end
    end
end

local function onGlowShow(_, spellID)
    if not Util.isSafePositiveNumber(spellID) or not Util.isSafeTableKey(spellID) then
        return
    end
    glowSpells[spellID] = true
    updateGlowForActiveStates(spellID, true)
end

local function onGlowHide(_, spellID)
    if not Util.isSafePositiveNumber(spellID) or not Util.isSafeTableKey(spellID) then
        return
    end
    glowSpells[spellID] = nil
    updateGlowForActiveStates(spellID, nil)
end

function AlertManager.initialize()
    local router = EAM.Modules.EventRouter
    if router then
        router.register("EAM_AURA_STATE_CHANGED", AlertManager.onAlertStateChanged)
        router.register("EAM_COOLDOWN_STATE_CHANGED", AlertManager.onAlertStateChanged)
        router.register("EAM_ITEM_COOLDOWN_STATE_CHANGED", AlertManager.onAlertStateChanged)
        router.register("EAM_GROUND_EFFECT_STATE_CHANGED", AlertManager.onAlertStateChanged)
        router.register("EAM_TOTEM_STATE_CHANGED", AlertManager.onAlertStateChanged)
        
        -- 註冊原生快捷列金色亮框事件
        router.register("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", onGlowShow)
        router.register("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", onGlowHide)
    end
end

function AlertManager.onAlertStateChanged(_, state, frameName)
    if not state or not Util.isSafeTableKey(state.id) then
        return
    end

    -- 被動裝飾：若此 spellID 當前正處於發光狀態，自動套用發光屬性
    if Util.isSafeTableKey(state.spellID) and glowSpells[state.spellID] then
        state.overlayGlow = true
    end

    -- 將變更暫存至更新佇列中
    AlertManager.pendingUpdates[state.id] = { state = state, frameName = frameName }

    -- 若尚未註冊批次更新，則利用 Scheduler 註冊在下一個 Tick 執行
    if not AlertManager.isPending then
        AlertManager.isPending = true
        local Scheduler = EAM.Modules.Scheduler
        if Scheduler and Scheduler.after then
            Scheduler.after(0, flushUpdates)
        else
            -- 若 Scheduler 不可用（加載期邊界），則立即 flush 降級
            flushUpdates()
        end
    end
end

