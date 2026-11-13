--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/WeaponEnchantService
檔案: Services\WeaponEnchantService.lua

理念:
- 將武器暫時性附魔 (磨刀石/巫術之油/薩滿火舌風怒/盜賊毒藥/DK符文熔鑄/影之哀傷等) 作為獨立告警模組提供全面監控。
- 為什麼不是常規光環？底層是裝備槽位（Slot 16 主手、17 副手、18 遠程）之物品臨時附魔 (Item Temporary Enchantment)，
  無 AuraInstanceID，在 C_UnitAuras 查不到。
- 專用 API：GetWeaponEnchantInfo() -> hasMH, mhExp, mhCharges, mhEnchantID, hasOH, ohExp, ohCharges, ohEnchantID, hasRanged, rangedExp, rangedCharges, rangedEnchantID。
- 專用事件：WEAPON_ENCHANT_CHANGED, PLAYER_EQUIPMENT_CHANGED, UNIT_INVENTORY_CHANGED, PLAYER_ENTERING_WORLD。
- 正式服 (Retail 12.x) 與永恆服 (Forever 1.60.1) 均完全支援 GetWeaponEnchantInfo()。

責任:
- 主手 (16)、副手 (17) 與遠程 (18) 臨時附魔之狀態取樣（剩餘時間、剩餘次數、裝備圖示）。
- 【缺少武器附魔提醒 (Missing Weapon Enchant Warning)】：當角色裝備了武器但未附魔時發出告警（圖示高亮、邊框發光、音效）。
- 【附魔即將到期提醒 (Expiring Warning)】：剩餘時間低於設定閾值（如 3 分鐘或 5 分鐘）或次數耗盡時提醒。
- 畫面 HUD 獨立渲染、自適應文字排版、與獨立位置自由拖曳支援。
]]

local _, EAM = ...

EAM.Services = EAM.Services or {}
EAM.UI = EAM.UI or {}

local api = EAM.API or {}
local Util = EAM.Util or {}
local Constants = EAM.Constants or {}

local WeaponEnchantService = {
    states = {},
    frames = {},
    parentFrame = nil,
    isMoving = false,
    lastSoundAlertTime = { [16] = 0, [17] = 0, [18] = 0 },
    enabled = true,
    lastSampleTime = 0,
    sampleThrottle = 0.2,
}

EAM.Services.WeaponEnchantService = WeaponEnchantService

local function inCombat()
    return api.InCombatLockdown and api.InCombatLockdown()
end

local function isSafeNumber(val)
    if val == nil then return false end
    if Util and Util.isSecretValue and Util.isSecretValue(val) then return false end
    if issecretvalue and issecretvalue(val) then return false end
    if Util and Util.isSafeNumber then return Util.isSafeNumber(val) end
    if type(val) ~= "number" then return false end
    return val == val and val ~= math.huge and val ~= -math.huge
end

function WeaponEnchantService.getConfig()
    local db = EAM.db
    if not db then return {} end
    if not db.weaponEnchant or type(db.weaponEnchant) ~= "table" then
        db.weaponEnchant = {
            enabled = true,
            showMainHand = true,
            showOffHand = true,
            showRanged = false,
            warnMissing = true,
            warnExpiring = true,
            expireThreshold = 300, -- 5 分鐘 (300 秒)
            glowMissing = true,
            glowExpiring = true,
            playSound = false,
            soundName = "ShayBell",
            iconSize = 40,
            growDirection = 1,
            spacing = 6,
        }
    end
    return db.weaponEnchant
end

local function isServiceEnabled()
    if not WeaponEnchantService.enabled then
        return false
    end
    local mc = EAM.Modules and EAM.Modules.ModuleController
    if mc and type(mc.isEnabled) == "function" then
        if not mc.isEnabled("weaponEnchant") then
            return false
        end
    end
    local cfg = WeaponEnchantService.getConfig()
    if cfg and cfg.enabled == false then
        return false
    end
    local config = EAM.db and EAM.db.config
    if config and config.enableWeaponEnchant == false then
        return false
    end
    return true
end

-- 取得指定槽位狀態物件
local function getOrCreateSlotState(slot)
    local state = WeaponEnchantService.states[slot]
    if not state then
        state = {
            slot = slot,
            hasItem = false,
            hasEnchant = false,
            expiration = 0,
            charges = nil,
            enchantID = nil,
            durationSec = 0,
            icon = nil,
            name = nil,
            isMissing = false,
            isExpiring = false,
            active = false,
            shown = false,
            kind = Constants.ALERT_KIND_WEAPON_ENCHANT or "weaponEnchant",
        }
        WeaponEnchantService.states[slot] = state
    end
    return state
end

-- 格式化剩餘時間 (MM:SS 或 M / S)
function WeaponEnchantService.formatDuration(seconds)
    if not isSafeNumber(seconds) or seconds <= 0 then
        return ""
    end
    seconds = math.floor(seconds + 0.5)
    if seconds >= 3600 then
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        return string.format("%dh%dm", hours, mins)
    elseif seconds >= 60 then
        local mins = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%d:%02d", mins, secs)
    else
        return string.format("%ds", seconds)
    end
end

-- 採樣與狀態推導 (核心業務狀態機)
function WeaponEnchantService.sampleWeaponEnchants()
    local getEnchantInfo = api.GetWeaponEnchantInfo or _G.GetWeaponEnchantInfo
    if type(getEnchantInfo) ~= "function" then
        return WeaponEnchantService.states
    end

    local cfg = WeaponEnchantService.getConfig()
    local expireThreshold = (cfg and isSafeNumber(cfg.expireThreshold) and cfg.expireThreshold > 0) and cfg.expireThreshold or 300
    local warnMissing = (cfg and cfg.warnMissing ~= false)
    local warnExpiring = (cfg and cfg.warnExpiring ~= false)
    local now = (api.GetTime and api.GetTime()) or (_G.GetTime and _G.GetTime()) or 0

    local ok, hasMH, mhExp, mhCharges, mhID, hasOH, ohExp, ohCharges, ohID, hasRanged, rangedExp, rangedCharges, rangedID = pcall(getEnchantInfo)
    if not ok then
        return WeaponEnchantService.states
    end

    local getItemTex = api.GetInventoryItemTexture or _G.GetInventoryItemTexture
    local getItemID = api.GetInventoryItemID or _G.GetInventoryItemID

    -- 1. 主手槽位 (Slot 16)
    local mhState = getOrCreateSlotState(16)
    local mhHasItem = false
    if getItemID and getItemID("player", 16) then
        mhHasItem = true
    elseif getItemTex and getItemTex("player", 16) then
        mhHasItem = true
    end
    mhState.hasItem = mhHasItem
    mhState.icon = (type(getItemTex) == "function" and getItemTex("player", 16)) or 136518
    mhState.name = (EAM.L and EAM.L.EAM_WEAPON_ENCHANT_MH) or "主手附魔"

    local mhHasEnchant = (hasMH == true and isSafeNumber(mhExp) and mhExp > 0)
    mhState.hasEnchant = mhHasEnchant
    if mhHasEnchant then
        mhState.durationSec = mhExp / 1000
        mhState.expiration = now + mhState.durationSec
        mhState.charges = isSafeNumber(mhCharges) and mhCharges or nil
        mhState.enchantID = mhID
        mhState.isMissing = false
        mhState.isExpiring = warnExpiring and ((mhState.durationSec <= expireThreshold) or (mhState.charges and mhState.charges == 1))
        mhState.active = true
    else
        mhState.durationSec = 0
        mhState.expiration = 0
        mhState.charges = nil
        mhState.enchantID = nil
        mhState.isMissing = mhHasItem and warnMissing
        mhState.isExpiring = false
        mhState.active = mhState.isMissing
    end

    -- 2. 副手槽位 (Slot 17)
    local ohState = getOrCreateSlotState(17)
    local ohHasItem = false
    if getItemID and getItemID("player", 17) then
        ohHasItem = true
    elseif getItemTex and getItemTex("player", 17) then
        ohHasItem = true
    end
    ohState.hasItem = ohHasItem
    ohState.icon = (type(getItemTex) == "function" and getItemTex("player", 17)) or 136518
    ohState.name = (EAM.L and EAM.L.EAM_WEAPON_ENCHANT_OH) or "副手附魔"

    local ohHasEnchant = (hasOH == true and isSafeNumber(ohExp) and ohExp > 0)
    ohState.hasEnchant = ohHasEnchant
    if ohHasEnchant then
        ohState.durationSec = ohExp / 1000
        ohState.expiration = now + ohState.durationSec
        ohState.charges = isSafeNumber(ohCharges) and ohCharges or nil
        ohState.enchantID = ohID
        ohState.isMissing = false
        ohState.isExpiring = warnExpiring and ((ohState.durationSec <= expireThreshold) or (ohState.charges and ohState.charges == 1))
        ohState.active = true
    else
        ohState.durationSec = 0
        ohState.expiration = 0
        ohState.charges = nil
        ohState.enchantID = nil
        ohState.isMissing = ohHasItem and warnMissing
        ohState.isExpiring = false
        ohState.active = ohState.isMissing
    end

    -- 音效提醒節流調用
    if cfg and cfg.playSound == true then
        for _, s in ipairs({ mhState, ohState }) do
            if (s.isMissing or s.isExpiring) and (now - (WeaponEnchantService.lastSoundAlertTime[s.slot] or 0)) > 30.0 then
                WeaponEnchantService.lastSoundAlertTime[s.slot] = now
                local ms = EAM.Services and EAM.Services.MediaService
                if ms and type(ms.playSound) == "function" then
                    ms.playSound(cfg.soundName or "ShayBell")
                elseif _G.PlaySoundFile then
                    pcall(_G.PlaySoundFile, "Sound\\Interface\\RaidWarning.ogg", "Master")
                end
            end
        end
    end

    -- 廣播狀態事件至 EventRouter
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router and type(router.fire) == "function" then
        router.fire("EAM_WEAPON_ENCHANT_STATE_CHANGED", mhState, 16)
        router.fire("EAM_WEAPON_ENCHANT_STATE_CHANGED", ohState, 17)
    end

    return WeaponEnchantService.states
end

-- 取得特定槽位 Tooltip 資訊
function WeaponEnchantService.getEnchantTooltipInfo(slot)
    local state = WeaponEnchantService.states[slot]
    if not state then return nil end

    local title = (slot == 16 and ((EAM.L and EAM.L.EAM_WEAPON_ENCHANT_MH) or "主手武器附魔"))
        or ((EAM.L and EAM.L.EAM_WEAPON_ENCHANT_OH) or "副手武器附魔")

    local lines = {}
    if not state.hasItem then
        lines[#lines + 1] = { text = "• 未裝備武器", r = 0.6, g = 0.6, b = 0.6 }
    elseif state.hasEnchant then
        local durStr = WeaponEnchantService.formatDuration(state.durationSec)
        lines[#lines + 1] = { text = string.format("• 附魔剩餘時間: %s", durStr ~= "" and durStr or "即將到期"), r = 0.2, g = 1.0, b = 0.4 }
        if state.charges and state.charges > 0 then
            lines[#lines + 1] = { text = string.format("• 剩餘次數: %d 次", state.charges), r = 1.0, g = 0.82, b = 0.2 }
        end
        if state.isExpiring then
            lines[#lines + 1] = { text = "• 【警戒】附魔即將到期，請及時補充！", r = 1.0, g = 0.3, b = 0.3 }
        end
    elseif state.isMissing then
        lines[#lines + 1] = { text = "• 【缺少附魔】已裝備武器但尚未施加臨時附魔！", r = 1.0, g = 0.2, b = 0.2 }
        lines[#lines + 1] = { text = "• 支援磨刀石、巫術之油、毒藥、風怒/火舌、符文熔鑄等", r = 0.8, g = 0.8, b = 0.8 }
    end

    return { title = title, lines = lines }
end

function WeaponEnchantService.showEnchantTooltip(anchorFrame, slot)
    local info = WeaponEnchantService.getEnchantTooltipInfo(slot)
    if not info or not _G.GameTooltip then return end
    local tooltip = _G.GameTooltip
    tooltip:SetOwner(anchorFrame, "ANCHOR_RIGHT")
    tooltip:ClearLines()
    tooltip:AddLine(info.title or "武器臨時附魔", 1.0, 0.82, 0.0)
    if info.lines then
        for _, line in ipairs(info.lines) do
            if type(line) == "table" then
                tooltip:AddLine(line.text or "", line.r or 1, line.g or 1, line.b or 1, true)
            else
                tooltip:AddLine(tostring(line), 1, 1, 1, true)
            end
        end
    end
    tooltip:Show()
end

-- 建立/取得武器附魔主父框架
local function ensureParentFrame()
    if WeaponEnchantService.parentFrame then return WeaponEnchantService.parentFrame end
    if inCombat() then return nil end

    local frame = api.CreateFrame("Frame", "EAM_AlertFrame_weaponEnchant", UIParent)
    local size = 40
    frame:SetSize(size, size)
    frame:SetPoint("CENTER", UIParent, "CENTER", 120, -120)
    frame.frameName = "weaponEnchant"

    if EAM.db and EAM.db.layout and EAM.db.layout.frames and EAM.db.layout.frames.weaponEnchant then
        local cfg = EAM.db.layout.frames.weaponEnchant
        frame:ClearAllPoints()
        frame:SetPoint(cfg.point or "CENTER", UIParent, cfg.attachPoint or cfg.point or "CENTER", cfg.x or 120, cfg.y or -120)
    end

    WeaponEnchantService.parentFrame = frame
    return frame
end

WeaponEnchantService.ensureParentFrame = ensureParentFrame

-- 建立/取得指定槽位的視覺框架 (Slot Frame)
local function getOrCreateSlotFrame(slot)
    if WeaponEnchantService.frames[slot] then
        return WeaponEnchantService.frames[slot]
    end
    ensureParentFrame()

    local parent = WeaponEnchantService.parentFrame or UIParent
    local frame = api.CreateFrame("Frame", "EAM_AlertFrame_weaponEnchant_" .. tostring(slot), parent, "BackdropTemplate")
    frame:SetSize(40, 40)
    frame:SetFrameStrata("MEDIUM")
    frame.slot = slot

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.icon = icon

    local timeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetPoint("BOTTOM", frame, "TOP", 0, 2)
    timeText:SetTextColor(1, 1, 1, 1)
    frame.timeText = timeText

    local stackText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stackText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    stackText:SetTextColor(1, 0.9, 0.2, 1)
    frame.stackText = stackText

    local labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    labelText:SetTextColor(0.85, 0.75, 1.0, 1)
    frame.labelText = labelText

    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, tileSize = 0, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    frame:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
    frame:SetBackdropBorderColor(0.85, 0.55, 1.0, 0.9)

    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if not WeaponEnchantService.isMoving then
            WeaponEnchantService.showEnchantTooltip(self, self.slot)
        end
    end)
    frame:SetScript("OnLeave", function(self)
        if _G.GameTooltip then
            _G.GameTooltip:Hide()
        end
    end)

    WeaponEnchantService.frames[slot] = frame
    return frame
end

WeaponEnchantService.getOrCreateSlotFrame = getOrCreateSlotFrame

-- 刷新畫面 HUD 與告警呈現
function WeaponEnchantService.update()
    if not isServiceEnabled() then
        if WeaponEnchantService.parentFrame then
            WeaponEnchantService.parentFrame:Hide()
        end
        for _, f in pairs(WeaponEnchantService.frames) do
            f:Hide()
        end
        return
    end

    if not WeaponEnchantService.parentFrame and not ensureParentFrame() then return end

    local cfg = WeaponEnchantService.getConfig()
    local states = WeaponEnchantService.sampleWeaponEnchants()

    local slotsToShow = {}
    if cfg.showMainHand ~= false and states[16] and (states[16].hasEnchant or states[16].isMissing) then
        slotsToShow[#slotsToShow + 1] = states[16]
    end
    if cfg.showOffHand ~= false and states[17] and (states[17].hasEnchant or states[17].isMissing) then
        slotsToShow[#slotsToShow + 1] = states[17]
    end

    if #slotsToShow == 0 then
        WeaponEnchantService.parentFrame:Hide()
        for _, f in pairs(WeaponEnchantService.frames) do
            f:Hide()
        end
        return
    end

    WeaponEnchantService.parentFrame:Show()

    local db = EAM.db
    local growDir = (db and db.layout and db.layout.frames and db.layout.frames.weaponEnchant and db.layout.frames.weaponEnchant.growDirection) or cfg.growDirection or 1
    local spacing = (db and db.layout and db.layout.spacing) or cfg.spacing or 6
    local size = cfg.iconSize or 40

    local LBG = _G.LibStub and _G.LibStub("LibButtonGlow-1.0", true)

    for idx, state in ipairs(slotsToShow) do
        local frame = getOrCreateSlotFrame(state.slot)
        frame:SetSize(size, size)
        frame:Show()

        if not WeaponEnchantService.isMoving then
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
            frame:SetPoint("CENTER", WeaponEnchantService.parentFrame, "CENTER", dx, dy)
        end

        frame.icon:SetTexture(state.icon or 136518)

        -- 標籤與時間文字更新
        if state.slot == 16 then
            frame.labelText:SetText((EAM.L and EAM.L.EAM_WEAPON_ENCHANT_MH) or "主手")
        else
            frame.labelText:SetText((EAM.L and EAM.L.EAM_WEAPON_ENCHANT_OH) or "副手")
        end

        if state.hasEnchant then
            local durStr = WeaponEnchantService.formatDuration(state.durationSec)
            frame.timeText:SetText(durStr)
            if state.isExpiring then
                frame.timeText:SetTextColor(1.0, 0.4, 0.2, 1.0)
            else
                frame.timeText:SetTextColor(1.0, 1.0, 1.0, 1.0)
            end

            if state.charges and state.charges > 0 then
                frame.stackText:SetText(tostring(state.charges))
                frame.stackText:Show()
            else
                frame.stackText:Hide()
            end
        else
            -- 缺少附魔
            frame.timeText:SetText((EAM.L and EAM.L.EAM_WEAPON_ENCHANT_MISSING) or "缺少附魔")
            frame.timeText:SetTextColor(1.0, 0.2, 0.2, 1.0)
            frame.stackText:SetText("!")
            frame.stackText:SetTextColor(1.0, 0.2, 0.2, 1.0)
            frame.stackText:Show()
        end

        -- 邊框發光與視覺反饋
        if state.isMissing and cfg.glowMissing ~= false then
            if LBG and LBG.ShowOverlayGlow then
                LBG.ShowOverlayGlow(frame)
            end
            if not WeaponEnchantService.isMoving then
                frame:SetBackdropBorderColor(1.0, 0.2, 0.2, 1.0)
            end
        elseif state.isExpiring and cfg.glowExpiring ~= false then
            if LBG and LBG.ShowOverlayGlow then
                LBG.ShowOverlayGlow(frame)
            end
            if not WeaponEnchantService.isMoving then
                frame:SetBackdropBorderColor(1.0, 0.65, 0.1, 1.0)
            end
        else
            if LBG and LBG.HideOverlayGlow then
                LBG.HideOverlayGlow(frame)
            end
            if not WeaponEnchantService.isMoving then
                frame:SetBackdropBorderColor(0.85, 0.55, 1.0, 0.9)
            end
        end
    end

    -- 隱藏未顯示的 slot
    local activeSlots = {}
    for _, s in ipairs(slotsToShow) do activeSlots[s.slot] = true end
    for slot, f in pairs(WeaponEnchantService.frames) do
        if not activeSlots[slot] then
            f:Hide()
        end
    end
end

-- 支援移動模式拖曳控制 (Mover HUD)
function WeaponEnchantService.setActiveAnchors(enable)
    if inCombat() then return false, "combatDeferred" end
    WeaponEnchantService.isMoving = enable

    if enable then
        ensureParentFrame()
        local parent = WeaponEnchantService.parentFrame
        if parent then
            parent:Show()
            parent:SetSize(120, 42)
            parent:SetMovable(true)
            parent:EnableMouse(true)
            parent:SetFrameStrata("FULLSCREEN_DIALOG")
            parent:SetClampedToScreen(true)
            parent:RegisterForDrag("LeftButton")

            if not parent.moverHUD then
                local hud = api.CreateFrame("Frame", nil, parent, "BackdropTemplate")
                hud:SetSize(140, 42)
                hud:SetPoint("CENTER", parent, "CENTER", 0, 0)
                hud:SetBackdrop({
                    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12,
                    insets = { left = 3, right = 3, top = 3, bottom = 3 }
                })
                hud:SetBackdropColor(0.20, 0.05, 0.25, 0.65)
                hud:SetBackdropBorderColor(0.85, 0.55, 1.0, 0.95)

                local title = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                title:SetPoint("TOP", hud, "TOP", 0, -4)
                title:SetTextColor(0.85, 0.55, 1.0, 1.0)
                title:SetText("★ 武器臨時附魔")

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
                local db = EAM.db
                if db and db.layout and db.layout.frames then
                    db.layout.frames.weaponEnchant = db.layout.frames.weaponEnchant or {}
                    db.layout.frames.weaponEnchant.point = point or "CENTER"
                    db.layout.frames.weaponEnchant.x = x or 120
                    db.layout.frames.weaponEnchant.y = y or -120
                end
                print("|cff00ff96EAM|r " .. string.format("武器附魔框架已儲存: X: %.1f, Y: %.1f", x or 120, y or -120))
            end)
            parent:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and WeaponEnchantService.isMoving then
                    WeaponEnchantService.setActiveAnchors(false)
                    print("|cff00ff96EAM|r 已關閉武器附魔移動模式。")
                end
            end)
        end
    else
        if WeaponEnchantService.parentFrame then
            WeaponEnchantService.parentFrame:SetMovable(false)
            WeaponEnchantService.parentFrame:EnableMouse(false)
            WeaponEnchantService.parentFrame:SetFrameStrata("MEDIUM")
            if WeaponEnchantService.parentFrame.moverHUD then
                WeaponEnchantService.parentFrame.moverHUD:Hide()
            end
        end
        for _, f in pairs(WeaponEnchantService.frames) do
            f:SetMovable(false)
            f:EnableMouse(true)
            f:SetFrameStrata("MEDIUM")
        end
        WeaponEnchantService.update()
    end
    return true
end

-- 模組生命週期即時開關回呼 (ModuleController Toggle Hook)
function WeaponEnchantService.onModuleToggle(enabled, reason)
    WeaponEnchantService.enabled = (enabled ~= false)
    if enabled == false then
        if WeaponEnchantService.parentFrame then
            WeaponEnchantService.parentFrame:Hide()
        end
        for _, f in pairs(WeaponEnchantService.frames) do
            f:Hide()
        end
        if WeaponEnchantService.isMoving then
            WeaponEnchantService.setActiveAnchors(false)
        end
    else
        WeaponEnchantService.update()
    end
end

-- 定期更新計時器 (每 0.25 秒刷新一次)
local tickerFrame = nil
local function initTicker()
    if tickerFrame then return end
    tickerFrame = api.CreateFrame("Frame")
    local elapsed = 0
    tickerFrame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.25 then
            elapsed = 0
            WeaponEnchantService.update()
        end
    end)
    WeaponEnchantService.tickerFrame = tickerFrame
end

function WeaponEnchantService.initialize()
    local router = EAM.Modules and EAM.Modules.EventRouter
    if router and type(router.register) == "function" then
        local onEvent = function()
            WeaponEnchantService.update()
        end
        router.register("WEAPON_ENCHANT_CHANGED", onEvent)
        router.register("PLAYER_EQUIPMENT_CHANGED", onEvent)
        router.register("UNIT_INVENTORY_CHANGED", function(eventName, unit)
            if unit == "player" then
                onEvent()
            end
        end)
        router.register("PLAYER_ENTERING_WORLD", onEvent)
        router.register("PLAYER_LOGIN", onEvent)
        router.register("PLAYER_REGEN_DISABLED", onEvent)
        router.register("PLAYER_REGEN_ENABLED", onEvent)
    end
    initTicker()
    WeaponEnchantService.update()
end

WeaponEnchantService.init = WeaponEnchantService.initialize
WeaponEnchantService.refresh = WeaponEnchantService.update

pcall(WeaponEnchantService.initialize)
