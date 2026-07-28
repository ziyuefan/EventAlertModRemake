--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/GroundEffectService
檔案: Services\GroundEffectService.lua

理念:
- 作為無光環地面技能（如暴風雪、寒冰寶珠等）的事實監控層。
- 採用極致效能與零 CPU 佔用的優化設計：法術施放瞬間渲染一次，將倒數交給 native Cooldown spiral 處理，以 Scheduler.after 進行到期釋放，完全免除 OnUpdate 輪詢。
- 提供「Tooltip 動態擷取」與「手動自訂秒數」雙軌持續時間計時。

責任:
- 監聽 COMBAT_LOG_EVENT_UNFILTERED，過濾玩家施放成功的地面技能。
- 動態調用低頻 C_TooltipInfo.GetSpellByID 擷取法術持續時間。
- 管理地面技能的生命週期與到期釋放。

資料所有權:
- 擁有地面技能的當前 active 計時表與預設配置庫。

可變狀態:
- 可 mutate GroundEffectService.activeAlerts 快取表。

邊界:
- 僅在施放當下解析 Tooltip 一次，完全不在熱路徑與每幀 OnUpdate 中 scrap Tooltip。
- 支援一鍵擷取 API 供 Options 面板調用。

]]
local _, EAM = ...

local issecretvalue = issecretvalue or function() return false end
local canaccessvalue = canaccessvalue or function() return true end
local canaccesstable = canaccesstable or function() return true end
local api = EAM.API
local Util = EAM.Util
local Scheduler = nil
local GroundEffectStatePool = nil

local GroundEffectService = {
    activeAlerts = {}, -- [spellID] = expireAt
    activeStates = {}, -- [spellID] = state
    -- 預設的地面技能配置庫
    defaults = {
        [19306]  = { enabled = true, durationMode = "TOOLTIP", manualDuration = 8, name = "暴風雪" },
        [84714]  = { enabled = true, durationMode = "TOOLTIP", manualDuration = 15, name = "寒冰寶珠" },
        [343292] = { enabled = true, durationMode = "TOOLTIP", manualDuration = 6, name = "火焰之環" },
    }
}

EAM.Services.GroundEffectService = GroundEffectService

-- 低 GC 的 GroundEffectState 物件快取池
GroundEffectStatePool = {
    recycleBin = {},
    binSize = 0,
}

GroundEffectService.GroundEffectStatePool = GroundEffectStatePool

function GroundEffectStatePool.initialize()
    -- 預先建立 10 個 GroundEffectState 對象備用
    for i = 1, 10 do
        local state = Util.tableCreate(0, 16)
        state.timer = Util.tableCreate(0, 4)
        GroundEffectStatePool.recycleBin[i] = state
    end
    GroundEffectStatePool.binSize = 10
end

function GroundEffectStatePool.acquire()
    local state
    if GroundEffectStatePool.binSize > 0 then
        state = GroundEffectStatePool.recycleBin[GroundEffectStatePool.binSize]
        GroundEffectStatePool.recycleBin[GroundEffectStatePool.binSize] = nil
        GroundEffectStatePool.binSize = GroundEffectStatePool.binSize - 1
    else
        state = Util.tableCreate(0, 16)
        state.timer = Util.tableCreate(0, 4)
    end
    state.releaseFunc = GroundEffectStatePool.release
    return state
end

function GroundEffectStatePool.release(state)
    if not state then return end
    
    state.id = nil
    state.kind = nil
    state.spellID = nil
    state.name = nil
    state.icon = nil
    state.stacks = nil
    state.active = false
    state.shown = false
    state.releaseFunc = nil
    wipe(state.timer)
    
    GroundEffectStatePool.binSize = GroundEffectStatePool.binSize + 1
    GroundEffectStatePool.recycleBin[GroundEffectStatePool.binSize] = state
end

-- 低頻 Tooltip 持續時間解析器 (支援 zhTW/zhCN/enUS/koKR/ruRU，極致效能與 numerically indexed loops)
local function parseTooltipDuration(spellID)
    -- 🛡️ Table 索引與 Secret 防禦：若 spellID 為 Secret 則拒絕處理
    if not Util.isSafePositiveNumber(spellID) then
        return nil
    end

    if not api.C_TooltipInfo or not api.C_TooltipInfo.GetSpellByID then
        return nil
    end

    local data = api.C_TooltipInfo.GetSpellByID(spellID)
    if not Util.isReadableTable(data) then
        return nil
    end
    local lines, linesSafe = Util.readSafeField(data, "lines")
    if not linesSafe or type(lines) ~= "table" then
        return nil
    end

    local locale = api.GetLocale and api.GetLocale() or "enUS"
    if locale == "enGB" then
        locale = "enUS"
    end

    local patterns = Util.MULTI_LOCALE_PATTERNS[locale] or Util.MULTI_LOCALE_PATTERNS.enUS

    for i = 1, #lines do
        local line = lines[i]
        if Util.isReadableTable(line) then
            local text, textSafe = Util.readSafeField(line, "leftText")
            if textSafe and Util.isSafeString(text) then
                for j = 1, #patterns do
                    local sec = string.match(text, patterns[j])
                    if sec then
                        local num = tonumber(sec)
                        if num and num > 0 then
                            return num
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- 提供給 Options UI 面板的一鍵擷取與自動填入 API
function GroundEffectService.scrapeDuration(spellID)
    return parseTooltipDuration(spellID)
end

-- 到期釋放 Callback
local function onAlertExpired(spellID)
    -- 🛡️ Table 索引防禦
    if not spellID or issecretvalue(spellID) then
        return
    end

    local now = api.GetTime and api.GetTime() or 0
    local expireAt = GroundEffectService.activeAlerts[spellID]
    
    -- 多發覆蓋守衛：如果目前時間未達到過期時間，代表中途有新的施放覆蓋了它，不作處理
    if not expireAt or now < (expireAt - 0.05) then
        return
    end

    local state = GroundEffectService.activeStates[spellID]
    if state then
        state.shown = false
        
        local router = EAM.Modules.EventRouter
        if router then
            router.trigger("EAM_GROUND_EFFECT_STATE_CHANGED", state, EAM.Constants.ALERT_FRAME_TYPES.groundEffect)
        end
        
        GroundEffectService.activeStates[spellID] = nil
    end
    
    GroundEffectService.activeAlerts[spellID] = nil
end

-- 處理成功施放地面技能
local function triggerGroundEffect(spellID)
    -- 🛡️ Table 索引與 Secret 防禦
    if not spellID or issecretvalue(spellID) then
        return
    end

    if not Scheduler then
        Scheduler = EAM.Modules.Scheduler
    end

    -- 讀取配置 (已防禦 Secret Key)
    local cfg = EAM.db and EAM.db.alerts and EAM.db.alerts.groundEffects and EAM.db.alerts.groundEffects[spellID]
    if not cfg then
        cfg = GroundEffectService.defaults[spellID]
    end

    if not cfg or cfg.enabled == false then
        return
    end

    -- 取得持續時間
    local duration = cfg.manualDuration or 8
    if cfg.durationMode == "TOOLTIP" then
        local tooltipDuration = parseTooltipDuration(spellID)
        if tooltipDuration then
            duration = tooltipDuration
        end
    end

    local now = api.GetTime and api.GetTime() or 0
    GroundEffectService.activeAlerts[spellID] = now + duration

    local state = GroundEffectService.activeStates[spellID]
    if state then
        -- 覆蓋現有計時
        state.timer.startTime = now
        state.timer.duration = duration
        state.timer.expirationTime = now + duration
        if api.C_DurationUtil and api.C_DurationUtil.CreateDuration then
            state.timer.durationObject = api.C_DurationUtil.CreateDuration(duration)
        else
            state.timer.durationObject = nil
        end
    else
        -- 獲取法術基本資訊
        local name = cfg.name or EAM.L.EAM_GROUND_SKILL_DEFAULT or "地面技能"
        local icon = 136243 -- 預設問號 icon
        
        if api.C_Spell and api.C_Spell.GetSpellInfo then
            local spellInfo = api.C_Spell.GetSpellInfo(spellID)
            if spellInfo then
                name = spellInfo.name or name
                icon = spellInfo.iconID or icon
            end
        end

        state = GroundEffectStatePool.acquire()
        state.id = "groundEffect_" .. spellID
        state.kind = "groundEffect"
        state.spellID = spellID
        state.name = name
        state.icon = icon
        state.stacks = 0
        state.active = true
        state.shown = true
        
        state.timer.mode = EAM.Constants.TIMER_NUMERIC
        state.timer.startTime = now
        state.timer.duration = duration
        state.timer.expirationTime = now + duration
        if api.C_DurationUtil and api.C_DurationUtil.CreateDuration then
            state.timer.durationObject = api.C_DurationUtil.CreateDuration(duration)
        else
            state.timer.durationObject = nil
        end
        
        GroundEffectService.activeStates[spellID] = state
    end

    local router = EAM.Modules.EventRouter
    if router then
        router.trigger("EAM_GROUND_EFFECT_STATE_CHANGED", state, EAM.Constants.ALERT_FRAME_TYPES.groundEffect)
    end

    -- 排程到期釋放，100% 零 OnUpdate 負擔！
    if Scheduler and Scheduler.after then
        Scheduler.after(duration, onAlertExpired, spellID)
    end
end

-- 處理玩家自身施法成功事件（替代已失效的 CLEU）
function GroundEffectService.onSpellcastSucceeded(_, unit, castGUID, spellID)
    -- 🛡️ Table 索引與 Secret 防禦：防止 spellID 為 Secret 時查表崩潰
    if not spellID or issecretvalue(spellID) then
        return
    end

    -- 僅監控玩家自身的施法
    if unit ~= "player" then
        return
    end

    -- 判斷該法術是否在監控清單中 (已防禦 Secret Key)
    local hasAlert = false
    if EAM.db and EAM.db.alerts and EAM.db.alerts.groundEffects and EAM.db.alerts.groundEffects[spellID] then
        hasAlert = EAM.db.alerts.groundEffects[spellID].enabled ~= false
    elseif GroundEffectService.defaults[spellID] then
        hasAlert = true
    end

    if hasAlert then
        triggerGroundEffect(spellID)
    end
end

function GroundEffectService.initialize()
    Scheduler = EAM.Modules.Scheduler
    GroundEffectStatePool.initialize()

    -- 預配置 EAM.db.alerts.groundEffects 預設值，若不存在則填入 defaults
    if EAM.db and EAM.db.alerts then
        if type(EAM.db.alerts.groundEffects) ~= "table" then
            EAM.db.alerts.groundEffects = {}
        end
        for spellID, def in pairs(GroundEffectService.defaults) do
            if EAM.db.alerts.groundEffects[spellID] == nil then
                EAM.db.alerts.groundEffects[spellID] = {
                    enabled = def.enabled,
                    durationMode = def.durationMode,
                    manualDuration = def.manualDuration,
                    name = def.name,
                }
            end
        end
    end

    local router = EAM.Modules.EventRouter
    if router then
        router.register("UNIT_SPELLCAST_SUCCEEDED", GroundEffectService.onSpellcastSucceeded)
    end
end

