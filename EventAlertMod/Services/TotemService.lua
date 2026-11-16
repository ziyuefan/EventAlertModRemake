--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/TotemService
檔案: Services\TotemService.lua

理念:
- 獨立完整之圖騰狀態監控模組（薩滿四系火／地／水／風圖騰及通用召喚圖騰）。
- 預先於非戰鬥期間建立專屬 HUD 框架與 4 個槽位框體（EAM_TotemFrame / EAM_TotemSlotFrame1..4），
  徹底解決戰鬥中施放圖騰因通用 Renderer 延遲建框 (combatDeferred) 或過度嚴格的 Secret 早期返回導致不顯示之問題。
- 使用 12.x 全域 GetTotemInfo 與 GetTotemDuration API 取得圖騰事實與原生 DurationObject，相容 Forever 1.60.1 與 Retail 12.1.5。
- 內建獨立設定面板 (EAM.UI.TotemPanel / EAM_TotemOptionsFrame)，完整對齊 EAM 11 套動態主題系統，並支援獨立拖曳定位與 15 秒模擬預覽。

責任:
- 監聽 PLAYER_TOTEM_UPDATE、PLAYER_ENTERING_WORLD、PLAYER_LOGIN 與戰鬥進出事件。
- 逐一掃描 4 個圖騰插槽，保存 TotemService.activeStates 與觸發 EAM_TOTEM_STATE_CHANGED（並確保 TotemStatePool 與 secret boundary 測試契約完整）。
- 驅動專屬圖騰 HUD 渲染、即時倒數秒數、冷卻轉圈遮罩 (Swipe)、作用中/即將到期發光高亮、聲音警示與原生 GameTooltip:SetTotem(slot)。

資料所有權:
- 擁有圖騰插槽快取 (activeStates)、TotemStatePool 與專屬 HUD 框體。
- 讀取/更新 EAM.db.totem 與同步 EAM.db.layout.frames.totem 座標設定。

效能注意:
- 事件與倒數計時器只對 1..4 固定槽位執行無 GC 迴圈，tickerFrame 僅於有活躍圖騰時掛載 OnUpdate。
]]
local _, EAM = ...

EAM.Services = EAM.Services or {}
EAM.UI = EAM.UI or {}

local api = EAM.API or {}
local Util = EAM.Util or {}
local Constants = EAM.Constants or {}
local DurationAdapter = EAM.Modules and EAM.Modules.DurationAdapter
local ModuleController = EAM.Modules and EAM.Modules.ModuleController

local mathFloor = math.floor
local mathMax = math.max

local function getTheme()
    return EAM.Theme
end

local function getLocale()
    return EAM.Locale
end

local TOTEM_SLOTS = { 1, 2, 3, 4 }

local DEFAULT_SLOT_ICONS = {
    [1] = 135824, -- Fire (灼熱圖騰)
    [2] = 136098, -- Earth (石甲圖騰)
    [3] = 135861, -- Water (治療之泉圖騰)
    [4] = 136039, -- Air (風怒圖騰)
}

local SLOT_BORDER_COLORS = {
    [1] = { 1.00, 0.38, 0.15, 0.95 }, -- 火 Fire
    [2] = { 0.85, 0.65, 0.25, 0.95 }, -- 地 Earth
    [3] = { 0.20, 0.70, 1.00, 0.95 }, -- 水 Water
    [4] = { 0.75, 0.55, 1.00, 0.95 }, -- 風 Air
}

local TotemService = {
    activeStates = {}, -- [slot] = state
    frames = {},
    previewStates = {},
    previewMode = false,
    previewExpireAt = 0,
    parentFrame = nil,
    tickerFrame = nil,
    isMoving = false,
    initialized = false,
    enabled = true,
    hasDedicatedHUD = true,
    lastSoundAlertTime = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 },
}

EAM.Services.TotemService = TotemService

-- 預分配渲染緩衝表，避免熱路徑產生 GC
local slotsToShowBuffer = {}
local activeSlotsBuffer = {}

local function inCombat()
    return api.InCombatLockdown and api.InCombatLockdown()
end

local function getCurrentTime()
    return (api.GetTime and api.GetTime()) or (_G.GetTime and _G.GetTime()) or 0
end

local function isSafeNumber(val)
    if val == nil then return false end
    if Util and Util.isSecretValue and Util.isSecretValue(val) then return false end
    if issecretvalue and issecretvalue(val) then return false end
    if Util and Util.isSafeNumber then return Util.isSafeNumber(val) end
    if type(val) ~= "number" then return false end
    return val == val and val ~= math.huge and val ~= -math.huge
end

local function localized(key, fallback)
    return (EAM.L and EAM.L[key]) or fallback or key
end

local function getSlotElementName(slot)
    if slot == 1 then
        return localized("EAM_TOTEM_SLOT_FIRE", "火之圖騰")
    elseif slot == 2 then
        return localized("EAM_TOTEM_SLOT_EARTH", "大地圖騰")
    elseif slot == 3 then
        return localized("EAM_TOTEM_SLOT_WATER", "水之圖騰")
    end
    return localized("EAM_TOTEM_SLOT_AIR", "風之圖騰")
end

-- ============================================================================
-- TotemStatePool (維持低 GC 與 FlowTest 測試契約)
-- ============================================================================

local TotemStatePool = {
    recycleBin = {},
    binSize = 0,
}

TotemService.TotemStatePool = TotemStatePool

function TotemStatePool.initialize()
    for i = 1, 4 do
        local state = Util.tableCreate(0, 16)
        state.boundaryWarnings = Util.tableCreate(2, 0)
        state.timer = Util.tableCreate(0, 4)
        TotemStatePool.recycleBin[i] = state
    end
    TotemStatePool.binSize = 4
end

function TotemStatePool.acquire()
    local state
    if TotemStatePool.binSize > 0 then
        state = TotemStatePool.recycleBin[TotemStatePool.binSize]
        TotemStatePool.recycleBin[TotemStatePool.binSize] = nil
        TotemStatePool.binSize = TotemStatePool.binSize - 1
    else
        state = Util.tableCreate(0, 16)
        state.boundaryWarnings = Util.tableCreate(2, 0)
        state.timer = Util.tableCreate(0, 4)
    end
    state.releaseFunc = TotemStatePool.release
    return state
end

function TotemStatePool.release(state)
    if not state then return end

    state.id = nil
    state.slot = nil
    state.kind = nil
    state.spellID = nil
    state.name = nil
    state.icon = nil
    state.stacks = nil
    state.active = false
    state.shown = false
    state.factsSafe = false
    state.boundaryLimited = false
    state.releaseFunc = nil
    wipe(state.boundaryWarnings)
    wipe(state.timer)

    TotemStatePool.binSize = TotemStatePool.binSize + 1
    TotemStatePool.recycleBin[TotemStatePool.binSize] = state
end

-- ============================================================================
-- 設定存取與同步 (SavedVariables.totem)
-- ============================================================================

function TotemService.getConfig()
    local db = EAM.db
    if not db then return {} end
    if not db.totem or type(db.totem) ~= "table" then
        db.totem = {}
    end
    local cfg = db.totem
    local layoutFrame = db.layout and db.layout.frames and db.layout.frames.totem

    if cfg.enabled == nil then cfg.enabled = true end
    if cfg.showFire == nil then cfg.showFire = true end
    if cfg.showEarth == nil then cfg.showEarth = true end
    if cfg.showWater == nil then cfg.showWater = true end
    if cfg.showAir == nil then cfg.showAir = true end
    if cfg.showName == nil then cfg.showName = true end
    if cfg.showCooldownText == nil then cfg.showCooldownText = true end
    if cfg.showSwipe == nil then cfg.showSwipe = true end
    if cfg.glowActive == nil then cfg.glowActive = false end
    if cfg.warnExpiring == nil then cfg.warnExpiring = true end
    if cfg.glowExpiring == nil then cfg.glowExpiring = true end
    if not isSafeNumber(cfg.expireThreshold) or cfg.expireThreshold <= 0 then cfg.expireThreshold = 5 end
    if cfg.playSound == nil then cfg.playSound = false end
    if type(cfg.soundName) ~= "string" or cfg.soundName == "" then cfg.soundName = "ShayBell" end
    if not isSafeNumber(cfg.iconSize) or cfg.iconSize <= 0 then cfg.iconSize = 40 end
    if not isSafeNumber(cfg.growDirection) or cfg.growDirection < 1 or cfg.growDirection > 4 then
        cfg.growDirection = (layoutFrame and layoutFrame.growDirection) or 1
    end
    if not isSafeNumber(cfg.spacing) or cfg.spacing < 0 then
        cfg.spacing = (db.layout and isSafeNumber(db.layout.spacing) and db.layout.spacing) or 6
    end
    if not isSafeNumber(cfg.x) then
        cfg.x = (layoutFrame and isSafeNumber(layoutFrame.x) and layoutFrame.x) or 0
    end
    if not isSafeNumber(cfg.y) then
        cfg.y = (layoutFrame and isSafeNumber(layoutFrame.y) and layoutFrame.y) or -240
    end
    if type(cfg.point) ~= "string" or cfg.point == "" then
        cfg.point = (layoutFrame and layoutFrame.point) or "CENTER"
    end
    return cfg
end

local function syncPositionToLayout(cfg)
    local db = EAM.db
    if db and db.layout and db.layout.frames and cfg then
        db.layout.frames.totem = db.layout.frames.totem or {}
        local lf = db.layout.frames.totem
        lf.point = cfg.point or lf.point or "CENTER"
        lf.attachPoint = lf.attachPoint or lf.point or "CENTER"
        lf.x = isSafeNumber(cfg.x) and cfg.x or 0
        lf.y = isSafeNumber(cfg.y) and cfg.y or -240
        lf.growDirection = cfg.growDirection or 1
    end
end

local function moduleEnabled()
    local mc = EAM.Modules and EAM.Modules.ModuleController or ModuleController
    if mc and type(mc.isEnabled) == "function" then
        if not mc.isEnabled(Constants.MODULE_KEYS and Constants.MODULE_KEYS.totem or "totem") then
            return false
        end
    end
    if TotemService.enabled == false then
        return false
    end
    local db = EAM.db
    if type(db) == "table" then
        if type(db.totem) == "table" and db.totem.enabled == false then
            return false
        end
        if type(db.config) == "table" and db.config.enableTotem == false then
            return false
        end
    end
    return true
end

function TotemService.formatDuration(seconds)
    if not isSafeNumber(seconds) or seconds <= 0 then
        return ""
    end
    local secInt = mathMax(1, mathFloor(seconds + 0.5))
    if secInt >= 3600 then
        local hours = mathFloor(secInt / 3600)
        local mins = mathFloor((secInt % 3600) / 60)
        return string.format("%dh%dm", hours, mins)
    elseif secInt >= 60 then
        local mins = mathFloor(secInt / 60)
        local secs = secInt % 60
        return string.format("%d:%02d", mins, secs)
    else
        return string.format("%ds", secInt)
    end
end

-- ============================================================================
-- 圖騰狀態取樣 (相容 Secret Value 與 DurationObject)
-- ============================================================================

local function triggerState(state)
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router then
        router.trigger("EAM_TOTEM_STATE_CHANGED", state, Constants.ALERT_FRAME_TYPES and Constants.ALERT_FRAME_TYPES.totem or "totem")
    end
end

local function applyNativeDuration(slot, state)
    if type(api.GetTotemDuration) ~= "function" then
        return false
    end
    local ok, durationObject = pcall(api.GetTotemDuration, slot)
    if not ok or durationObject == nil then
        return false
    end
    state.timer.durationObject = durationObject
    return true
end

local function resolveSafeIcon(icon, safeSpellID, slot)
    if Util and Util.isSafePositiveNumber and Util.isSafePositiveNumber(icon) then
        return icon
    end
    if Util and Util.isSafeString and Util.isSafeString(icon) and icon ~= "" then
        return icon
    end
    if safeSpellID and safeSpellID > 0 then
        local cSpell = api.C_Spell or _G.C_Spell
        if cSpell and type(cSpell.GetSpellTexture) == "function" then
            local okTex, tex = pcall(cSpell.GetSpellTexture, safeSpellID)
            if okTex and tex and ((isSafeNumber(tex) and tex > 0) or (type(tex) == "string" and tex ~= "")) then
                return tex
            end
        end
    end
    return DEFAULT_SLOT_ICONS[slot] or 136243
end

local function preserveBoundaryState(slot, code, fallbackName, fallbackIcon, fallbackSpellID)
    local state = TotemService.activeStates[slot]
    if not state then
        if code == "slotSecret" then
            return
        end
        -- 若為新增圖騰但名稱為 Secret，仍必須建立 state 與原生時間物件讓 HUD 正常顯示
        state = TotemStatePool.acquire()
        state.id = "totem_" .. slot
        state.slot = slot
        state.kind = "totem"
        state.spellID = fallbackSpellID or slot
        state.name = fallbackName or getSlotElementName(slot)
        state.icon = fallbackIcon or DEFAULT_SLOT_ICONS[slot] or 136243
        state.stacks = 0
        state.active = true
        state.shown = true
        TotemService.activeStates[slot] = state
    else
        if fallbackName and fallbackName ~= "" then
            state.name = fallbackName
        end
        if fallbackIcon then
            state.icon = fallbackIcon
        end
        state.shown = true
        state.active = true
    end

    state.factsSafe = false
    wipe(state.boundaryWarnings)
    Util.clearTimer(state.timer, Constants.TIMER_PROTECTED or "protected")
    if applyNativeDuration(slot, state) then
        state.timer.mode = Constants.TIMER_DISPLAY_ONLY or "displayOnly"
    end
    Util.markBoundary(state, "totem", code)
    triggerState(state)
end

-- 刷新單個圖騰插槽狀態
function TotemService.refreshSlot(slot, skipHUDUpdate)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    if type(api.GetTotemInfo) ~= "function" then
        return
    end

    local ok, haveTotem, name, startTime, duration, icon, _, spellID = pcall(api.GetTotemInfo, slot)
    if not ok or not Util.isSafeBoolean(haveTotem) then
        preserveBoundaryState(slot, "slotSecret")
        if not skipHUDUpdate then
            TotemService.updateHUD()
        end
        return
    end

    if haveTotem == true then
        local safeSpellID = (Util.isSafePositiveNumber and Util.isSafePositiveNumber(spellID)) and spellID or nil
        local resolvedIcon = resolveSafeIcon(icon, safeSpellID, slot)

        if not Util.isSafeString(name) or name == "" then
            preserveBoundaryState(slot, "identitySecret", getSlotElementName(slot), resolvedIcon, safeSpellID)
            if not skipHUDUpdate then
                TotemService.updateHUD()
            end
            return
        end

        local timingFieldsSafe = Util.isSafeNumber(startTime) and Util.isSafeNumber(duration)
        local hasDuration = timingFieldsSafe and Util.isSafePositiveNumber(duration)
        local state = TotemService.activeStates[slot]

        if state then
            state.slot = slot
            state.name = name
            state.spellID = safeSpellID or state.spellID or slot
            state.icon = resolvedIcon
            state.shown = true
            state.active = true
        else
            state = TotemStatePool.acquire()
            state.id = "totem_" .. slot
            state.slot = slot
            state.kind = "totem"
            state.spellID = safeSpellID or slot
            state.name = name
            state.icon = resolvedIcon
            state.stacks = 0
            state.active = true
            state.shown = true

            TotemService.activeStates[slot] = state
        end

        state.factsSafe = timingFieldsSafe
        state.boundaryLimited = false
        wipe(state.boundaryWarnings)
        if hasDuration then
            Util.clearTimer(state.timer, Constants.TIMER_NUMERIC or "numeric")
            state.timer.startTime = startTime
            state.timer.duration = duration
            state.timer.expirationTime = startTime + duration
            if not applyNativeDuration(slot, state) and DurationAdapter then
                state.timer.durationObject = DurationAdapter.createFromStart(startTime, duration)
            end
        elseif timingFieldsSafe then
            Util.clearTimer(state.timer, Constants.TIMER_NONE or "none")
        else
            Util.clearTimer(state.timer, Constants.TIMER_PROTECTED or "protected")
            if applyNativeDuration(slot, state) then
                state.timer.mode = Constants.TIMER_DISPLAY_ONLY or "displayOnly"
            end
            Util.markBoundary(state, "totem", "timingProtected")
        end
        triggerState(state)
    else
        local state = TotemService.activeStates[slot]
        if state then
            state.shown = false
            state.active = false
            TotemService.activeStates[slot] = nil
            triggerState(state)
            TotemStatePool.release(state)
        end
    end

    if not skipHUDUpdate then
        TotemService.updateHUD()
    end
end

-- 掃描所有圖騰插槽
function TotemService.scanAll()
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    for slot = 1, 4 do
        TotemService.refreshSlot(slot, true)
    end
    TotemService.updateHUD()
end

-- ============================================================================
-- 專屬 HUD 框架與戰鬥安全渲染 (EAM_TotemFrame & EAM_TotemSlotFrame1..4)
-- ============================================================================

local function applyParentFramePoint(frame, cfg)
    if not frame or inCombat() then return end
    local layoutFrame = EAM.db and EAM.db.layout and EAM.db.layout.frames and EAM.db.layout.frames.totem
    local point = (cfg and cfg.point) or (layoutFrame and layoutFrame.point) or "CENTER"
    local attachPoint = (layoutFrame and layoutFrame.attachPoint) or point
    local x = (cfg and isSafeNumber(cfg.x) and cfg.x) or (layoutFrame and isSafeNumber(layoutFrame.x) and layoutFrame.x) or 0
    local y = (cfg and isSafeNumber(cfg.y) and cfg.y) or (layoutFrame and isSafeNumber(layoutFrame.y) and layoutFrame.y) or -240
    frame:ClearAllPoints()
    frame:SetPoint(point, _G.UIParent, attachPoint, x, y)
end

local function ensureParentFrame()
    if TotemService.parentFrame then return TotemService.parentFrame end
    if inCombat() then return nil end
    if not _G.UIParent or type(api.CreateFrame) ~= "function" then return nil end

    local cfg = TotemService.getConfig()
    local size = (cfg and cfg.iconSize) or 40
    local frame = api.CreateFrame("Frame", "EAM_TotemFrame", _G.UIParent)
    frame:SetSize(size, size)
    frame.frameName = "totem"
    applyParentFramePoint(frame, cfg)
    TotemService.parentFrame = frame
    return frame
end

TotemService.ensureParentFrame = ensureParentFrame

local function showSlotTooltip(slotFrame)
    if TotemService.isMoving or not _G.GameTooltip then return end
    local slot = slotFrame.slot
    _G.GameTooltip:SetOwner(slotFrame, "ANCHOR_RIGHT")

    if TotemService.previewMode then
        local st = TotemService.previewStates[slot]
        if st then
            _G.GameTooltip:ClearLines()
            _G.GameTooltip:SetText(st.name or getSlotElementName(slot), 1.0, 0.85, 0.25)
            _G.GameTooltip:AddLine(getSlotElementName(slot), 0.70, 0.88, 1.0)
            if st.timer and isSafeNumber(st.timer.expirationTime) then
                local rem = mathMax(0, st.timer.expirationTime - getCurrentTime())
                _G.GameTooltip:AddLine(string.format("%s: %s", localized("EAM_TOTEM_TOOLTIP_REMAINING", "剩餘時間"), TotemService.formatDuration(rem)), 0.8, 1.0, 0.8)
            end
            _G.GameTooltip:AddLine(localized("EAM_TOTEM_PREVIEW_HINT", "目前為測試模擬預覽狀態（右鍵關閉預覽）"), 0.7, 0.7, 0.7)
            _G.GameTooltip:Show()
        end
        return
    end

    local okSet = false
    if type(_G.GameTooltip.SetTotem) == "function" then
        okSet = pcall(_G.GameTooltip.SetTotem, _G.GameTooltip, slot)
    end
    if not okSet then
        local st = TotemService.activeStates[slot]
        if st then
            _G.GameTooltip:ClearLines()
            _G.GameTooltip:SetText(tostring(st.name or getSlotElementName(slot)), 1.0, 0.85, 0.25)
            _G.GameTooltip:AddLine(getSlotElementName(slot), 0.70, 0.88, 1.0)
            _G.GameTooltip:Show()
        end
    else
        _G.GameTooltip:Show()
    end
end

local function hideSlotTooltip()
    if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
    end
end

local function getOrCreateSlotFrame(slot)
    if TotemService.frames[slot] then
        return TotemService.frames[slot]
    end
    if inCombat() or type(api.CreateFrame) ~= "function" then
        return nil
    end
    ensureParentFrame()
    local parent = TotemService.parentFrame or _G.UIParent
    if not parent then return nil end

    local frame = api.CreateFrame("Frame", "EAM_TotemSlotFrame" .. tostring(slot), parent, "BackdropTemplate")
    frame:SetSize(40, 40)
    frame:SetFrameStrata("MEDIUM")
    frame.slot = slot
    if type(frame.SetID) == "function" then
        pcall(frame.SetID, frame, slot)
    end

    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 0, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
    local bc = SLOT_BORDER_COLORS[slot] or SLOT_BORDER_COLORS[1]
    frame:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4])

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.icon = icon

    local cooldown = api.CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    cooldown:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetReverse then cooldown:SetReverse(true) end
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
    frame.cooldown = cooldown

    local timeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    timeText:SetTextColor(1, 1, 1, 1)
    frame.timeText = timeText

    local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    nameText:SetTextColor(bc[1], mathMax(0.7, bc[2]), mathMax(0.6, bc[3]), 1)
    frame.nameText = nameText

    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        showSlotTooltip(self)
    end)
    frame:SetScript("OnLeave", function()
        hideSlotTooltip()
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            if TotemService.isMoving then
                TotemService.setActiveAnchors(false)
                return
            end
            if TotemService.previewMode then
                TotemService.previewMode = false
                TotemService.updateHUD()
                return
            end
            if not inCombat() and api.DestroyTotem then
                pcall(api.DestroyTotem, self.slot)
            end
        end
    end)

    frame:Hide()
    TotemService.frames[slot] = frame
    return frame
end

TotemService.getOrCreateSlotFrame = getOrCreateSlotFrame

local function prewarmHUDFrames()
    if inCombat() then return end
    if not _G.UIParent or type(api.CreateFrame) ~= "function" then return end
    ensureParentFrame()
    for _, slot in ipairs(TOTEM_SLOTS) do
        getOrCreateSlotFrame(slot)
    end
end

local function applySlotHighlight(frame, slot, isExpiring, cfg, LBG)
    local bc = SLOT_BORDER_COLORS[slot] or SLOT_BORDER_COLORS[1]
    if isExpiring then
        if cfg.glowExpiring ~= false or cfg.glowActive == true then
            if LBG and LBG.ShowOverlayGlow then
                LBG.ShowOverlayGlow(frame)
            end
        else
            if LBG and LBG.HideOverlayGlow then
                LBG.HideOverlayGlow(frame)
            end
        end
        if not TotemService.isMoving then
            frame:SetBackdropBorderColor(1.0, 0.55, 0.10, 1.0)
        end
    elseif cfg.glowActive == true then
        if LBG and LBG.ShowOverlayGlow then
            LBG.ShowOverlayGlow(frame)
        end
        if not TotemService.isMoving then
            frame:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4])
        end
    else
        if LBG and LBG.HideOverlayGlow then
            LBG.HideOverlayGlow(frame)
        end
        if not TotemService.isMoving then
            frame:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4])
        end
    end
end

local function syncTickerState()
    local ticker = TotemService.tickerFrame
    if not ticker then return end

    if not moduleEnabled() then
        ticker:SetScript("OnUpdate", nil)
        return
    end

    local needTick = TotemService.previewMode == true
    if not needTick then
        for _, slot in ipairs(TOTEM_SLOTS) do
            local s = TotemService.activeStates[slot]
            if s and s.shown then
                needTick = true
                break
            end
        end
    end

    if needTick then
        ticker:SetScript("OnUpdate", TotemService._onTickerUpdate)
    else
        ticker:SetScript("OnUpdate", nil)
    end
end

function TotemService.tickCountdown()
    if not moduleEnabled() then
        syncTickerState()
        return
    end

    local now = getCurrentTime()
    if TotemService.previewMode and TotemService.previewExpireAt > 0 and now >= TotemService.previewExpireAt then
        TotemService.previewMode = false
        TotemService.updateHUD()
        return
    end

    local cfg = TotemService.getConfig()
    local expireThreshold = (cfg and isSafeNumber(cfg.expireThreshold) and cfg.expireThreshold > 0) and cfg.expireThreshold or 5
    local warnExpiring = (cfg and cfg.warnExpiring ~= false)
    local showTimeText = (cfg and cfg.showCooldownText ~= false)
    local LBG = _G.LibStub and _G.LibStub("LibButtonGlow-1.0", true)
    local sourceStates = TotemService.previewMode and TotemService.previewStates or TotemService.activeStates
    local needResample = false

    for _, slot in ipairs(TOTEM_SLOTS) do
        local state = sourceStates[slot]
        local frame = TotemService.frames[slot]
        if state and state.shown and frame and frame:IsShown() then
            local timer = state.timer
            if timer and timer.mode == (Constants.TIMER_NUMERIC or "numeric") and isSafeNumber(timer.expirationTime) then
                local remaining = timer.expirationTime - now
                if remaining <= 0 then
                    if TotemService.previewMode then
                        state.shown = false
                    else
                        needResample = true
                    end
                else
                    if showTimeText and frame.timeText then
                        frame.timeText:SetText(TotemService.formatDuration(remaining))
                        if warnExpiring and remaining <= expireThreshold then
                            frame.timeText:SetTextColor(1.0, 0.35, 0.2, 1.0)
                        else
                            frame.timeText:SetTextColor(1.0, 1.0, 1.0, 1.0)
                        end
                    elseif frame.timeText then
                        frame.timeText:SetText("")
                    end

                    local isExpiringNow = warnExpiring and remaining <= expireThreshold
                    if state._wasExpiring ~= isExpiringNow then
                        state._wasExpiring = isExpiringNow
                        applySlotHighlight(frame, slot, isExpiringNow, cfg, LBG)
                    end

                    if isExpiringNow and cfg and cfg.playSound == true then
                        if (now - (TotemService.lastSoundAlertTime[slot] or 0)) > 30.0 then
                            TotemService.lastSoundAlertTime[slot] = now
                            local ms = EAM.Services and EAM.Services.MediaService
                            if ms and type(ms.playSound) == "function" then
                                ms.playSound(cfg.soundName or "ShayBell")
                            elseif _G.PlaySoundFile then
                                pcall(_G.PlaySoundFile, "Sound\\Interface\\RaidWarning.ogg", "Master")
                            end
                        end
                    end
                end
            end
        end
    end

    if needResample then
        TotemService.scanAll()
    end
end

function TotemService.updateHUD()
    if not moduleEnabled() then
        TotemService.previewMode = false
        if TotemService.parentFrame then
            TotemService.parentFrame:Hide()
        end
        for _, f in pairs(TotemService.frames) do
            f:Hide()
        end
        syncTickerState()
        return
    end

    if not TotemService.parentFrame and not ensureParentFrame() then
        return
    end

    local cfg = TotemService.getConfig()
    applyParentFramePoint(TotemService.parentFrame, cfg)

    for i = 1, #slotsToShowBuffer do
        slotsToShowBuffer[i] = nil
    end
    for _, slot in ipairs(TOTEM_SLOTS) do
        activeSlotsBuffer[slot] = nil
    end

    local showSlotMap = {
        [1] = (cfg.showFire ~= false),
        [2] = (cfg.showEarth ~= false),
        [3] = (cfg.showWater ~= false),
        [4] = (cfg.showAir ~= false),
    }

    local sourceStates = TotemService.previewMode and TotemService.previewStates or TotemService.activeStates
    for _, slot in ipairs(TOTEM_SLOTS) do
        local s = sourceStates[slot]
        if s and s.shown and showSlotMap[slot] then
            slotsToShowBuffer[#slotsToShowBuffer + 1] = s
            activeSlotsBuffer[slot] = true
        end
    end

    if #slotsToShowBuffer == 0 then
        if not TotemService.isMoving then
            TotemService.parentFrame:Hide()
        end
        for _, f in pairs(TotemService.frames) do
            f:Hide()
        end
        syncTickerState()
        return
    end

    TotemService.parentFrame:Show()

    local db = EAM.db
    local layoutFrame = db and db.layout and db.layout.frames and db.layout.frames.totem
    local growDir = (isSafeNumber(cfg.growDirection) and cfg.growDirection)
        or (layoutFrame and layoutFrame.growDirection)
        or 1
    local spacing = (isSafeNumber(cfg.spacing) and cfg.spacing)
        or (db and db.layout and db.layout.spacing)
        or 6
    local size = cfg.iconSize or 40
    local expireThreshold = (cfg and isSafeNumber(cfg.expireThreshold) and cfg.expireThreshold > 0) and cfg.expireThreshold or 5
    local warnExpiring = (cfg and cfg.warnExpiring ~= false)
    local showName = (cfg and cfg.showName ~= false)
    local showTimeText = (cfg and cfg.showCooldownText ~= false)
    local showSwipe = (cfg and cfg.showSwipe ~= false)
    local now = getCurrentTime()
    local LBG = _G.LibStub and _G.LibStub("LibButtonGlow-1.0", true)

    for idx = 1, #slotsToShowBuffer do
        local state = slotsToShowBuffer[idx]
        local slot = state.slot or idx
        local frame = getOrCreateSlotFrame(slot)
        if frame then
            frame:SetSize(size, size)
            frame:Show()

            frame:ClearAllPoints()
            local offset = (idx - 1) * (size + spacing)
            local dx, dy = 0, 0
            if growDir == 1 then
                dx = offset
            elseif growDir == 2 then
                dx = -offset
            elseif growDir == 3 then
                dy = offset
            elseif growDir == 4 then
                dy = -offset
            end
            frame:SetPoint("CENTER", TotemService.parentFrame, "CENTER", dx, dy)

            if frame.icon then
                pcall(frame.icon.SetTexture, frame.icon, state.icon or DEFAULT_SLOT_ICONS[slot] or 136243)
            end

            if frame.nameText then
                if showName then
                    frame.nameText:SetText(state.name or getSlotElementName(slot))
                    frame.nameText:Show()
                else
                    frame.nameText:Hide()
                end
            end

            local timer = state.timer
            local isNumeric = timer and timer.mode == (Constants.TIMER_NUMERIC or "numeric")
                and isSafeNumber(timer.startTime) and isSafeNumber(timer.duration) and timer.duration > 0
            local remaining = (isNumeric and isSafeNumber(timer.expirationTime)) and mathMax(0, timer.expirationTime - now) or 0
            local isExpiring = isNumeric and warnExpiring and remaining > 0 and remaining <= expireThreshold
            state._wasExpiring = isExpiring

            if frame.cooldown then
                if showSwipe then
                    local dbConfig = db and db.config
                    local swipeAlpha = (dbConfig and isSafeNumber(dbConfig.cooldownSwipeAlpha)) and dbConfig.cooldownSwipeAlpha or 0.5
                    local swipeColor = (dbConfig and type(dbConfig.cooldownSwipeColor) == "table") and dbConfig.cooldownSwipeColor or nil
                    if frame.cooldown.SetSwipeColor then
                        pcall(frame.cooldown.SetSwipeColor, frame.cooldown, (swipeColor and swipeColor.r) or 0, (swipeColor and swipeColor.g) or 0, (swipeColor and swipeColor.b) or 0, swipeAlpha)
                    end
                    frame.cooldown:Show()
                    if timer and timer.durationObject and type(frame.cooldown.SetCooldownFromDurationObject) == "function" then
                        pcall(frame.cooldown.SetCooldownFromDurationObject, frame.cooldown, timer.durationObject)
                    elseif isNumeric then
                        pcall(frame.cooldown.SetCooldown, frame.cooldown, timer.startTime, timer.duration)
                    elseif frame.cooldown.Clear then
                        pcall(frame.cooldown.Clear, frame.cooldown)
                    end
                    if frame.cooldown.SetHideCountdownNumbers then
                        -- 當無法取得安全數值倒數時 (12.x Secret Mode)，開放 Blizzard 原生 C 側數字顯示
                        pcall(frame.cooldown.SetHideCountdownNumbers, frame.cooldown, isNumeric or not showTimeText)
                    end
                else
                    frame.cooldown:Hide()
                end
            end

            if frame.timeText then
                if isNumeric and showTimeText and remaining > 0 then
                    frame.timeText:SetText(TotemService.formatDuration(remaining))
                    if isExpiring then
                        frame.timeText:SetTextColor(1.0, 0.35, 0.2, 1.0)
                    else
                        frame.timeText:SetTextColor(1.0, 1.0, 1.0, 1.0)
                    end
                    frame.timeText:Show()
                else
                    frame.timeText:SetText("")
                    frame.timeText:Hide()
                end
            end

            applySlotHighlight(frame, slot, isExpiring, cfg, LBG)
        end
    end

    for slot, f in pairs(TotemService.frames) do
        if not activeSlotsBuffer[slot] then
            if LBG and LBG.HideOverlayGlow then
                LBG.HideOverlayGlow(f)
            end
            f:Hide()
        end
    end

    syncTickerState()
end

-- 模擬測試圖騰預覽 (15 秒)
function TotemService.triggerTestPreview()
    local now = getCurrentTime()
    local samples = {
        [1] = { name = localized("EAM_TOTEM_SAMPLE_FIRE", "灼熱圖騰"), icon = 135824, dur = 15 },
        [2] = { name = localized("EAM_TOTEM_SAMPLE_EARTH", "石甲圖騰"), icon = 136098, dur = 15 },
        [3] = { name = localized("EAM_TOTEM_SAMPLE_WATER", "治療之泉圖騰"), icon = 135861, dur = 15 },
        [4] = { name = localized("EAM_TOTEM_SAMPLE_AIR", "風怒圖騰"), icon = 136039, dur = 15 },
    }
    for slot = 1, 4 do
        local info = samples[slot]
        local durObj = DurationAdapter and DurationAdapter.createFromStart(now, info.dur) or nil
        TotemService.previewStates[slot] = {
            id = "totem_preview_" .. slot,
            slot = slot,
            kind = "totem",
            spellID = slot,
            name = info.name,
            icon = info.icon,
            active = true,
            shown = true,
            factsSafe = true,
            timer = {
                mode = Constants.TIMER_NUMERIC or "numeric",
                startTime = now,
                duration = info.dur,
                expirationTime = now + info.dur,
                durationObject = durObj,
            },
        }
    end
    TotemService.previewMode = true
    TotemService.previewExpireAt = now + 15
    TotemService.updateHUD()
    print("|cff00ff96EAM|r " .. localized("EAM_TOTEM_PREVIEW_STARTED", "已啟動圖騰測試預覽（15 秒後自動關閉，或右鍵圖示提早關閉）。"))
end

-- ============================================================================
-- 獨立拖曳錨點控制 (Mover HUD)
-- ============================================================================

function TotemService.setActiveAnchors(enable)
    if inCombat() then return false, "combatDeferred" end
    TotemService.isMoving = (enable == true)

    if TotemService.isMoving then
        hideSlotTooltip()
        ensureParentFrame()
        local parent = TotemService.parentFrame
        if parent then
            parent:Show()
            parent:SetSize(140, 42)
            parent:SetMovable(true)
            parent:EnableMouse(true)
            parent:SetFrameStrata("FULLSCREEN_DIALOG")
            parent:SetClampedToScreen(true)
            parent:RegisterForDrag("LeftButton")

            if not parent.moverHUD then
                local hud = api.CreateFrame("Frame", nil, parent, "BackdropTemplate")
                hud:SetSize(160, 42)
                hud:SetPoint("CENTER", parent, "CENTER", 0, 0)
                hud:SetBackdrop({
                    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 },
                })
                hud:SetBackdropColor(0.05, 0.16, 0.22, 0.72)
                hud:SetBackdropBorderColor(0.25, 0.85, 1.0, 0.95)

                local title = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                title:SetPoint("TOP", hud, "TOP", 0, -4)
                title:SetTextColor(0.35, 0.90, 1.0, 1.0)
                title:SetText("★ " .. localized("EAM_TOTEM_TITLE", "圖騰狀態監控"))

                local sub = hud:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                sub:SetPoint("BOTTOM", hud, "BOTTOM", 0, 4)
                sub:SetTextColor(0.9, 0.9, 0.9, 0.9)
                sub:SetText("[左鍵拖曳 / 右鍵完成]")

                parent.moverHUD = hud
            end
            parent.moverHUD:Show()

            parent:SetScript("OnDragStart", parent.StartMoving)
            parent:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                local point, _, _, x, y = self:GetPoint()
                local rx = mathFloor((x or 0) + 0.5)
                local ry = mathFloor((y or -240) + 0.5)
                local cfg = TotemService.getConfig()
                cfg.point = point or "CENTER"
                cfg.x = rx
                cfg.y = ry
                syncPositionToLayout(cfg)
                if EAM.Modules and EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.markRevisionChanged then
                    EAM.Modules.SavedVariables.markRevisionChanged()
                end
                if EAM.UI.TotemPanel and EAM.UI.TotemPanel.refresh then
                    EAM.UI.TotemPanel.refresh()
                end
                print("|cff00ff96EAM|r " .. string.format("圖騰監控框架已儲存: X: %.1f, Y: %.1f", rx, ry))
            end)
            parent:SetScript("OnMouseUp", function(_, button)
                if button == "RightButton" and TotemService.isMoving then
                    TotemService.setActiveAnchors(false)
                    print("|cff00ff96EAM|r 已關閉圖騰監控移動模式。")
                end
            end)
        end
    else
        if TotemService.parentFrame then
            TotemService.parentFrame:SetMovable(false)
            TotemService.parentFrame:EnableMouse(false)
            TotemService.parentFrame:SetFrameStrata("MEDIUM")
            if TotemService.parentFrame.moverHUD then
                TotemService.parentFrame.moverHUD:Hide()
            end
        end
        if EAM.UI.TotemPanel and EAM.UI.TotemPanel.refresh then
            EAM.UI.TotemPanel.refresh()
        end
        TotemService.updateHUD()
    end
    return true
end

-- ============================================================================
-- 事件接收與模組開關生命週期
-- ============================================================================

function TotemService.onEvent(event, slot)
    if not moduleEnabled() then
        return false, "moduleDisabled"
    end
    if event == "PLAYER_TOTEM_UPDATE" and slot then
        TotemService.refreshSlot(slot)
    else
        TotemService.scanAll()
    end
end

function TotemService.onModuleToggle(enabled)
    TotemService.enabled = (enabled ~= false)
    if enabled == false then
        TotemService.previewMode = false
        hideSlotTooltip()
        local router = EAM.Modules and EAM.Modules.EventRouter
        for slot, state in pairs(TotemService.activeStates) do
            state.shown = false
            state.active = false
            TotemService.activeStates[slot] = nil
            if router then
                router.fire("EAM_TOTEM_STATE_CHANGED", state, Constants.ALERT_FRAME_TYPES and Constants.ALERT_FRAME_TYPES.totem or "totem")
            end
            TotemStatePool.release(state)
        end
        if TotemService.parentFrame then
            TotemService.parentFrame:Hide()
        end
        for _, f in pairs(TotemService.frames) do
            f:Hide()
        end
        if TotemService.isMoving then
            TotemService.setActiveAnchors(false)
        end
        syncTickerState()
        return true, "disabled"
    end
    prewarmHUDFrames()
    TotemService.scanAll()
    return true, "enabled"
end

local function initTicker()
    if TotemService.tickerFrame or type(api.CreateFrame) ~= "function" then return end
    local tickerFrame = api.CreateFrame("Frame")
    local elapsed = 0
    TotemService._onTickerUpdate = function(_, delta)
        elapsed = elapsed + (delta or 0)
        if elapsed >= 0.20 then
            elapsed = 0
            TotemService.tickCountdown()
        end
    end
    TotemService.tickerFrame = tickerFrame
end

-- ============================================================================
-- 獨立圖騰狀態監控設定面板 (EAM.UI.TotemPanel)
-- ============================================================================

local Panel = {
    frame = nil,
    controls = {},
    syncing = false,
}
EAM.UI.TotemPanel = Panel

local function setPanelControlText(target, key, fallback)
    local locale = getLocale()
    if locale and type(locale.bindText) == "function" then
        return locale.bindText(target, key, fallback)
    end
    if target and type(target.SetText) == "function" then
        target:SetText(localized(key, fallback))
    end
end

local function createPanelCheckbox(parent, key, fallback, x, y, fieldName, tipText)
    local apiTheme = getTheme()
    local cb = api.CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetWidth(250)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    setPanelControlText(text, key, fallback)
    if apiTheme and apiTheme.registerText then
        apiTheme.registerText(text, "body")
    end
    cb.text = text

    if EAM.UI.setTooltip and tipText then
        EAM.UI.setTooltip(cb, tipText, localized(key, fallback))
    end

    cb:SetScript("OnClick", function(self)
        if Panel.syncing then return end
        local checked = self:GetChecked() == true
        local cfg = TotemService.getConfig()
        cfg[fieldName] = checked
        if fieldName == "enabled" then
            local saved = EAM.Modules and EAM.Modules.SavedVariables
            if saved and type(saved.updateModuleToggle) == "function" then
                saved.updateModuleToggle("totem", checked)
            elseif EAM.db and EAM.db.config then
                EAM.db.config.enableTotem = checked
            end
            TotemService.onModuleToggle(checked)
        else
            TotemService.updateHUD()
        end
        if EAM.Modules and EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.markRevisionChanged then
            EAM.Modules.SavedVariables.markRevisionChanged()
        end
        Panel.refresh()
    end)

    return cb
end

local function createPanelSlider(parent, key, fallback, minVal, maxVal, stepVal, x, y, width, fieldName, syncLayout, tipText)
    local apiTheme = getTheme()
    local slider = api.CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetSize(width or 255, 14)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(stepVal)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    local valText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 4)
    valText:SetJustifyH("RIGHT")
    if apiTheme and apiTheme.registerText then
        apiTheme.registerText(valText, "body")
    end

    local label = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
    label:SetPoint("RIGHT", valText, "LEFT", -4, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    setPanelControlText(label, key, fallback)
    if apiTheme and apiTheme.registerText then
        apiTheme.registerText(label, "title")
    end

    slider.valText = valText
    slider.stepVal = stepVal

    if EAM.UI.setTooltip and tipText then
        EAM.UI.setTooltip(slider, tipText, localized(key, fallback))
    end

    slider:SetScript("OnValueChanged", function(_, value)
        local rounded = mathFloor((value / stepVal) + 0.5) * stepVal
        if fieldName == "expireThreshold" then
            valText:SetText(string.format("%ds", mathFloor(rounded + 0.5)))
        else
            valText:SetText(string.format("%d", mathFloor(rounded + 0.5)))
        end
        if Panel.syncing then return end

        local cfg = TotemService.getConfig()
        cfg[fieldName] = rounded
        if syncLayout then
            syncPositionToLayout(cfg)
        end
        if EAM.Modules and EAM.Modules.SavedVariables and EAM.Modules.SavedVariables.markRevisionChanged then
            EAM.Modules.SavedVariables.markRevisionChanged()
        end
        TotemService.updateHUD()
    end)

    return slider
end

local function createPanelFrame()
    if Panel.frame then return Panel.frame end
    local uiParent = _G.UIParent
    if not uiParent then return nil end

    local theme = getTheme()

    local frame = api.CreateFrame("Frame", "EAM_TotemOptionsFrame", uiParent, "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(620, 545)
    frame:SetPoint("CENTER", uiParent, "CENTER", 0, 0)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        local main = _G.EAM_MainOptionsFrame
        if main and main:IsShown() then
            main:StartMoving()
        else
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        local main = _G.EAM_MainOptionsFrame
        if main and main:IsShown() then
            main:StopMovingOrSizing()
        else
            frame:StopMovingOrSizing()
        end
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0.08, 0.06, 0.08, 0.97)
    frame:SetBackdropBorderColor(0.45, 0.78, 0.95, 1.0)
    if theme and theme.registerFrame then
        theme.registerFrame(frame, "window")
    end
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetTextColor(0.95, 0.85, 0.4, 1.0)
    setPanelControlText(title, "EAM_TOTEM_PANEL_TITLE", "★ 圖騰狀態監控獨立設定")
    if theme and theme.registerText then
        theme.registerText(title, "title")
    end

    local closeBtn = api.CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(26, 26)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function() Panel.hide() end)

    local inner = api.CreateFrame("Frame", nil, frame, "BackdropTemplate")
    inner:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
    inner:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    inner:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    inner:SetBackdropColor(0.06, 0.05, 0.07, 0.85)
    inner:SetBackdropBorderColor(0.35, 0.55, 0.72, 0.85)
    if theme and theme.registerFrame then
        theme.registerFrame(inner, "panel")
    end

    -- 左欄：圖騰元素槽位與高亮開關
    local secSlots = inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secSlots:SetPoint("TOPLEFT", inner, "TOPLEFT", 14, -12)
    secSlots:SetTextColor(0.95, 0.85, 0.4, 1.0)
    setPanelControlText(secSlots, "EAM_TOTEM_SEC_SLOTS", "圖騰槽位與顯示開關")
    if theme and theme.registerText then
        theme.registerText(secSlots, "title")
    end

    Panel.controls.enabled = createPanelCheckbox(inner, "EAM_TOTEM_ENABLE", "啟用圖騰狀態監控模組", 14, -32, "enabled", "總開關：啟用或停用獨立圖騰狀態監控")
    Panel.controls.showFire = createPanelCheckbox(inner, "EAM_TOTEM_SHOW_FIRE", "顯示火之圖騰 (Slot 1)", 14, -56, "showFire", "顯示火元素圖騰或 1 號召喚槽位")
    Panel.controls.showEarth = createPanelCheckbox(inner, "EAM_TOTEM_SHOW_EARTH", "顯示大地圖騰 (Slot 2)", 14, -80, "showEarth", "顯示地元素圖騰或 2 號召喚槽位")
    Panel.controls.showWater = createPanelCheckbox(inner, "EAM_TOTEM_SHOW_WATER", "顯示水之圖騰 (Slot 3)", 14, -104, "showWater", "顯示水元素圖騰或 3 號召喚槽位")
    Panel.controls.showAir = createPanelCheckbox(inner, "EAM_TOTEM_SHOW_AIR", "顯示風之圖騰 (Slot 4)", 14, -128, "showAir", "顯示風元素圖騰或 4 號召喚槽位")
    Panel.controls.showName = createPanelCheckbox(inner, "EAM_TOTEM_SHOW_NAME", "顯示圖騰名稱標籤", 14, -152, "showName", "在圖騰圖示下方顯示圖騰或元素名稱")
    Panel.controls.showCooldownText = createPanelCheckbox(inner, "EAM_TOTEM_SHOW_TIME", "顯示剩餘倒數秒數", 14, -176, "showCooldownText", "在圖騰圖示上方顯示精確倒數秒數")
    Panel.controls.showSwipe = createPanelCheckbox(inner, "EAM_TOTEM_SHOW_SWIPE", "顯示冷卻轉圈遮罩 (Swipe)", 14, -200, "showSwipe", "在圖騰圖示上顯示原生時間轉圈陰影遮罩")

    local secHighlight = inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secHighlight:SetPoint("TOPLEFT", inner, "TOPLEFT", 14, -232)
    secHighlight:SetTextColor(0.95, 0.85, 0.4, 1.0)
    setPanelControlText(secHighlight, "EAM_TOTEM_SEC_HIGHLIGHT", "作用中與到期警示高亮")
    if theme and theme.registerText then
        theme.registerText(secHighlight, "title")
    end

    Panel.controls.glowActive = createPanelCheckbox(inner, "EAM_TOTEM_GLOW_ACTIVE", "作用中發光高亮 (Active Glow)", 14, -252, "glowActive", "圖騰存在期間持續顯示外框發光高亮")
    Panel.controls.warnExpiring = createPanelCheckbox(inner, "EAM_TOTEM_WARN_EXPIRING", "圖騰即將到期提醒", 14, -276, "warnExpiring", "剩餘秒數低於門檻時變色並觸發到期提醒")
    Panel.controls.glowExpiring = createPanelCheckbox(inner, "EAM_TOTEM_GLOW_EXPIRING", "即將到期時發光高亮", 14, -300, "glowExpiring", "圖騰剩餘秒數進入警戒閾值時播放橘紅發光高亮")
    Panel.controls.playSound = createPanelCheckbox(inner, "EAM_TOTEM_PLAY_SOUND", "即將到期播放音效 (30s 節流)", 14, -324, "playSound", "圖騰即將到期時播放提示音效（同槽位 30 秒節流）")

    -- 右欄：閾值、排版尺寸、座標與預覽
    local secLayout = inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secLayout:SetPoint("TOPLEFT", inner, "TOPLEFT", 310, -12)
    secLayout:SetTextColor(0.95, 0.85, 0.4, 1.0)
    setPanelControlText(secLayout, "EAM_TOTEM_SEC_LAYOUT", "到期門檻與自訂排版")
    if theme and theme.registerText then
        theme.registerText(secLayout, "title")
    end

    Panel.controls.expireThreshold = createPanelSlider(
        inner, "EAM_TOTEM_EXPIRE_THRESHOLD", "即將到期警戒閾值 (秒)", 2, 30, 1, 314, -52, 255, "expireThreshold", false,
        "圖騰剩餘時間低於此秒數時判定為即將到期 (2~30秒)"
    )

    Panel.controls.iconSize = createPanelSlider(
        inner, "EAM_TOTEM_ICON_SIZE", "圖示大小", 24, 80, 1, 314, -104, 120, "iconSize", false,
        "調整圖騰圖示大小 (24~80px)"
    )
    Panel.controls.spacing = createPanelSlider(
        inner, "EAM_TOTEM_SPACING", "圖示間距", 0, 40, 1, 450, -104, 120, "spacing", false,
        "調整圖騰圖示之間的排列間距 (0~40px)"
    )

    local dirLabel = inner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dirLabel:SetPoint("TOPLEFT", inner, "TOPLEFT", 310, -138)
    setPanelControlText(dirLabel, "EAM_OPT_DIR_TITLE", "圖示成長方向:")
    if theme and theme.registerText then
        theme.registerText(dirLabel, "body")
    end

    local dirDefs = {
        { value = 1, text = "→ 右" },
        { value = 2, text = "← 左" },
        { value = 3, text = "↑ 上" },
        { value = 4, text = "↓ 下" },
    }
    Panel.controls.dirBtns = {}
    for idx, dDef in ipairs(dirDefs) do
        local dBtn = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
        dBtn:SetSize(62, 22)
        dBtn:SetPoint("TOPLEFT", inner, "TOPLEFT", 310 + (idx - 1) * 66, -156)
        dBtn:SetText(dDef.text)
        if theme and theme.registerButton then theme.registerButton(dBtn) end
        dBtn.dirValue = dDef.value
        dBtn:SetScript("OnClick", function()
            local cfg = TotemService.getConfig()
            cfg.growDirection = dDef.value
            syncPositionToLayout(cfg)
            TotemService.updateHUD()
            Panel.refresh()
        end)
        Panel.controls.dirBtns[idx] = dBtn
    end

    Panel.controls.posX = createPanelSlider(
        inner, "EAM_TOTEM_POS_X", "自訂水平位置 (X)", -1000, 1000, 1, 314, -210, 255, "x", true,
        "調整圖騰監控框架水平座標 (-1000 ~ +1000)"
    )
    Panel.controls.posY = createPanelSlider(
        inner, "EAM_TOTEM_POS_Y", "自訂垂直位置 (Y)", -600, 600, 1, 314, -262, 255, "y", true,
        "調整圖騰監控框架垂直座標 (-600 ~ +600)"
    )

    local moveBtn = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    moveBtn:SetSize(130, 26)
    moveBtn:SetPoint("TOPLEFT", inner, "TOPLEFT", 310, -320)
    setPanelControlText(moveBtn, "EAM_TOTEM_MOVE_BTN", "移動錨點位置")
    if theme and theme.registerButton then theme.registerButton(moveBtn) end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(moveBtn, "開啟或關閉圖騰拖曳錨點，直接滑鼠左鍵拖放於畫面任意處", "移動錨點位置")
    end
    moveBtn:SetScript("OnClick", function()
        TotemService.setActiveAnchors(not TotemService.isMoving)
        Panel.refresh()
    end)
    Panel.controls.moveBtn = moveBtn

    local resetBtn = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    resetBtn:SetSize(130, 26)
    resetBtn:SetPoint("LEFT", moveBtn, "RIGHT", 8, 0)
    setPanelControlText(resetBtn, "EAM_TOTEM_RESET_POS_BTN", "重設預設位置")
    if theme and theme.registerButton then theme.registerButton(resetBtn) end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(resetBtn, "還原圖騰位置與排版為預設值 (CENTER, X: 0, Y: -240)", "重設預設位置")
    end
    resetBtn:SetScript("OnClick", function()
        local cfg = TotemService.getConfig()
        cfg.point = "CENTER"
        cfg.x = 0
        cfg.y = -240
        cfg.iconSize = 40
        cfg.spacing = 6
        cfg.growDirection = 1
        syncPositionToLayout(cfg)
        TotemService.updateHUD()
        Panel.refresh()
    end)

    local previewBtn = api.CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
    previewBtn:SetSize(268, 26)
    previewBtn:SetPoint("TOPLEFT", inner, "TOPLEFT", 310, -356)
    setPanelControlText(previewBtn, "EAM_TOTEM_PREVIEW_BTN", "測試圖騰預覽 (15秒)")
    if theme and theme.registerButton then theme.registerButton(previewBtn) end
    if EAM.UI.setTooltip then
        EAM.UI.setTooltip(previewBtn, "立即在畫面上顯示四系模擬圖騰與倒數效果，方便非戰鬥期間調校位置與高亮風格", "測試圖騰預覽")
    end
    previewBtn:SetScript("OnClick", function()
        TotemService.triggerTestPreview()
        Panel.refresh()
    end)
    Panel.controls.previewBtn = previewBtn

    Panel.frame = frame
    return frame
end

function Panel.refresh()
    if not Panel.frame then return end
    local cfg = TotemService.getConfig()
    Panel.syncing = true

    if Panel.controls.enabled then Panel.controls.enabled:SetChecked(cfg.enabled ~= false) end
    if Panel.controls.showFire then Panel.controls.showFire:SetChecked(cfg.showFire ~= false) end
    if Panel.controls.showEarth then Panel.controls.showEarth:SetChecked(cfg.showEarth ~= false) end
    if Panel.controls.showWater then Panel.controls.showWater:SetChecked(cfg.showWater ~= false) end
    if Panel.controls.showAir then Panel.controls.showAir:SetChecked(cfg.showAir ~= false) end
    if Panel.controls.showName then Panel.controls.showName:SetChecked(cfg.showName ~= false) end
    if Panel.controls.showCooldownText then Panel.controls.showCooldownText:SetChecked(cfg.showCooldownText ~= false) end
    if Panel.controls.showSwipe then Panel.controls.showSwipe:SetChecked(cfg.showSwipe ~= false) end
    if Panel.controls.glowActive then Panel.controls.glowActive:SetChecked(cfg.glowActive == true) end
    if Panel.controls.warnExpiring then Panel.controls.warnExpiring:SetChecked(cfg.warnExpiring ~= false) end
    if Panel.controls.glowExpiring then Panel.controls.glowExpiring:SetChecked(cfg.glowExpiring ~= false) end
    if Panel.controls.playSound then Panel.controls.playSound:SetChecked(cfg.playSound == true) end

    if Panel.controls.expireThreshold then Panel.controls.expireThreshold:SetValue(cfg.expireThreshold or 5) end
    if Panel.controls.iconSize then Panel.controls.iconSize:SetValue(cfg.iconSize or 40) end
    if Panel.controls.spacing then Panel.controls.spacing:SetValue(cfg.spacing or 6) end
    if Panel.controls.posX then Panel.controls.posX:SetValue(cfg.x or 0) end
    if Panel.controls.posY then Panel.controls.posY:SetValue(cfg.y or -240) end

    local activeDir = cfg.growDirection or 1
    for _, dBtn in ipairs(Panel.controls.dirBtns or {}) do
        dBtn:SetAlpha(dBtn.dirValue == activeDir and 1.0 or 0.55)
    end

    if Panel.controls.moveBtn then
        Panel.controls.moveBtn:SetAlpha(TotemService.isMoving and 1.0 or 0.85)
    end

    Panel.syncing = false
end

function Panel.open()
    if inCombat() then
        print("|cff00ff96EAM|r 戰鬥中暫不開啟圖騰設定面板。")
        return false, "combatDeferred"
    end
    local f = createPanelFrame()
    if not f then return false, "unavailable" end

    local theme = getTheme()
    if theme then
        if theme.flushPending then theme.flushPending() end
        if theme.applyAll then theme.applyAll() end
    end

    local mainFrame = _G.EAM_MainOptionsFrame
    f:ClearAllPoints()
    if mainFrame and mainFrame:IsShown() then
        f:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 2, 0)
    else
        f:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    end
    Panel.refresh()
    f:Show()
    return true
end

function Panel.hide()
    if Panel.frame then
        Panel.frame:Hide()
    end
end
Panel.close = Panel.hide

function Panel.toggle()
    if Panel.frame and Panel.frame:IsShown() then
        Panel.hide()
    else
        Panel.open()
    end
end

-- ============================================================================
-- 初始化
-- ============================================================================

function TotemService.initialize()
    if not TotemService.initialized then
        TotemService.initialized = true
        TotemStatePool.initialize()

        local router = EAM.Modules and EAM.Modules.EventRouter
        if router then
            router.register("PLAYER_TOTEM_UPDATE", TotemService.onEvent)
            router.register("PLAYER_ENTERING_WORLD", TotemService.onEvent)
            router.register("PLAYER_LOGIN", TotemService.onEvent)
            router.register("PLAYER_REGEN_DISABLED", TotemService.onEvent)
            router.register("PLAYER_REGEN_ENABLED", TotemService.onEvent)
        end
    end
    initTicker()
    prewarmHUDFrames()
end

TotemService.init = TotemService.initialize
TotemService.refresh = TotemService.scanAll
