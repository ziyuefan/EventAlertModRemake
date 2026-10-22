--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/CooldownTrace
檔案: Debug\CooldownTrace.lua

理念:
- 專為冷卻事件（SPELL_UPDATE_COOLDOWN、UNIT_SPELLCAST_SUCCEEDED、法術覆蓋與減 CD）打造的高精度飛行記錄器（Flight Recorder）。
- 解決線上減 CD 異步延遲、法術覆蓋（如冰霜射線遭彗星風暴覆蓋）生命週期診斷難題。
- 支援一鍵複製與 SavedVariables (EventAlertModDB.cooldownTrace) 持久化儲存，供玩家 /reload 後由 WTF 回傳或直接貼上。

責任:
- 維護容量為 300 條記錄的環形緩衝區 (Circular Ring Buffer)，保證零記憶體洩漏。
- 提供格式化字串匯出 (dumpToString)，包含微秒時間戳、事件類型、法術 ID、API 回傳冷卻 (startTime/dur/gcd/isEnabled) 與活躍警報狀態。
- 提供 UI 彈出視窗與 Slash 命令支援 (/eam trace)。
]]

local _, EAM = ...
EAM.Debug = EAM.Debug or {}

local Util = EAM.Util or {}
local api = EAM.API or {}

local CooldownTrace = {
    maxEntries = 300,
    entries = {},
    count = 0,
    head = 0,
    enabled = true,
    frame = nil,
    editBox = nil,
}
EAM.Debug.CooldownTrace = CooldownTrace

local function getTimestampStr()
    local t = (api.GetTime and api.GetTime()) or 0
    return string.format("%.3f", t)
end

-- 🛡️ 目標凍結與冬之寒意狀態探測器（戰鬥中安全靜默，杜絕 Secret Aura Taint）
function CooldownTrace.detectTargetFrozenState()
    if EAM.FlowTestEnvironment == "offline-mock" then
        return nil
    end
    -- 戰鬥中嚴禁讀取目標受保護秘密光環
    if (api.InCombatLockdown and api.InCombatLockdown()) or InCombatLockdown() then
        return nil
    end
    if not api.UnitExists or not api.UnitExists("target") then
        return nil
    end
    local cUnitAuras = api.C_UnitAuras
    local targetName = (api.UnitName and api.UnitName("target")) or "Unknown"
    local winterChillStacks = 0
    local isFrozen = false
    local otherFrozenAuras = {}

    if cUnitAuras and type(cUnitAuras.GetAuraDataByIndex) == "function" then
        for i = 1, 40 do
            local okAura, aura = pcall(cUnitAuras.GetAuraDataByIndex, "target", i, "HARMFUL")
            if not okAura or not aura then break end
            local sID = aura.spellId
            local name = aura.name
            local apps = aura.applications or 0
            if sID == 228358 or name == "冬之寒意" or name == "Winter's Chill" then
                winterChillStacks = math.max(apps, 1)
            elseif sID == 122 or sID == 33395 or sID == 113724 or sID == 228600
                or (name and (string.find(name, "凍結") or string.find(name, "Freeze") or string.find(name, "Frost Nova")))
            then
                isFrozen = true
                table.insert(otherFrozenAuras, name or tostring(sID))
            end
        end
    end

    return {
        name = targetName,
        winterChill = winterChillStacks,
        isFrozen = isFrozen,
        otherAuras = #otherFrozenAuras > 0 and table.concat(otherFrozenAuras, ",") or nil,
    }
end

-- 🛡️ 玩家冰霜狀態與關鍵減 CD 天賦探測器（戰鬥中安全靜默，杜絕 Secret Aura Taint）
function CooldownTrace.detectPlayerFrostState()
    if EAM.FlowTestEnvironment == "offline-mock" then
        return nil
    end
    -- 戰鬥中嚴禁讀取受保護秘密光環
    if (api.InCombatLockdown and api.InCombatLockdown()) or InCombatLockdown() then
        return nil
    end
    local cUnitAuras = api.C_UnitAuras
    local fofStacks = 0
    if cUnitAuras and type(cUnitAuras.GetAuraDataByIndex) == "function" then
        for i = 1, 40 do
            local okAura, aura = pcall(cUnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not okAura or not aura then break end
            if aura.spellId == 44544 or aura.name == "寒冰指" or aura.name == "Fingers of Frost" then
                fofStacks = math.max(aura.applications or 0, 1)
                break
            end
        end
    end

    local isKnown = function(sID)
        if api.IsPlayerSpell and api.IsPlayerSpell(sID) then return true end
        local cSpell = api.C_Spell
        if cSpell and cSpell.IsSpellKnownOrOverridesKnown and cSpell.IsSpellKnownOrOverridesKnown(sID) then return true end
        return false
    end

    local talentNames = {}
    if isKnown(1247798) then table.insert(talentNames, "結冰") end
    if isKnown(1247799) then table.insert(talentNames, "冰之心") end
    if isKnown(378448) then table.insert(talentNames, "破裂冰霜") end
    if isKnown(56377) then table.insert(talentNames, "分裂寒冰") end
    if isKnown(1281638) then table.insert(talentNames, "白化") end

    return {
        fof = fofStacks,
        talents = #talentNames > 0 and table.concat(talentNames, "+") or "None",
    }
end

-- 🛡️ 快照當前正在倒數中的活躍冷卻
function CooldownTrace.snapshotActiveCooldowns()
    local cdService = EAM.Services and EAM.Services.CooldownService
    if not cdService or not cdService.states then return "None" end
    local now = (api.GetTime and api.GetTime()) or 0
    local list = {}
    for _, state in pairs(cdService.states) do
        if state and state.active and not state.completed and not state.isPlaceholder then
            local exp = state.timer and state.timer.expirationTime
            if exp and exp > now then
                local rem = exp - now
                table.insert(list, string.format("%d(%.1fs)", state.spellID or 0, rem))
            end
        end
    end
    return #list > 0 and table.concat(list, ", ") or "None"
end

function CooldownTrace.record(eventName, spellID, spellName, details)
    if not CooldownTrace.enabled then
        return
    end

    local cSpell = api.C_Spell
    local cdInfo = nil
    local chargeInfo = nil
    local overrideID = nil

    local isInternalEvent = (eventName == "ACTIVATE_MATCH" or eventName == "OVERRIDE_PRESERVED"
        or eventName == "HEURISTIC_INIT" or eventName == "CDR_SYNC_UPDATE"
        or eventName == "CDR_TRIGGER_CAST" or eventName == "SHATTER_IMPACT"
        or eventName == "CDR_DETECTED" or eventName == "CDR_POLL_EXPIRED")

    if not isInternalEvent then
        if cSpell and type(cSpell.GetSpellCooldown) == "function" and Util.isSafePositiveNumber(spellID) then
            local ok, info = pcall(cSpell.GetSpellCooldown, spellID)
            if ok and type(info) == "table" then
                cdInfo = {
                    startTime = Util.readSafeScalar(info.startTime, nil, "traceCD", "startTime"),
                    duration = Util.readSafeScalar(info.duration, nil, "traceCD", "duration"),
                    isEnabled = Util.readSafeScalar(info.isEnabled, nil, "traceCD", "isEnabled"),
                    isOnGCD = Util.readSafeScalar(info.isOnGCD, nil, "traceCD", "isOnGCD"),
                }
            end
        end

        if cSpell and type(cSpell.GetSpellCharges) == "function" and Util.isSafePositiveNumber(spellID) then
            local okCh, chInfo = pcall(cSpell.GetSpellCharges, spellID)
            if okCh and type(chInfo) == "table" and Util.canAccessTable(chInfo) then
                local cur = Util.readSafeScalar(chInfo.currentCharges, nil, "traceCharge", "currentCharges")
                local mx = Util.readSafeScalar(chInfo.maxCharges, nil, "traceCharge", "maxCharges")
                local chStart = Util.readSafeScalar(chInfo.cooldownStartTime, nil, "traceCharge", "cooldownStartTime")
                local chDur = Util.readSafeScalar(chInfo.cooldownDuration, nil, "traceCharge", "cooldownDuration")
                if mx and type(mx) == "number" and mx > 1 then
                    chargeInfo = {
                        current = cur,
                        max = mx,
                        startTime = chStart,
                        duration = chDur,
                    }
                end
            end
        end

        if cSpell and type(cSpell.GetOverrideSpell) == "function" and Util.isSafePositiveNumber(spellID) then
            local ok, ov = pcall(cSpell.GetOverrideSpell, spellID)
            if ok and Util.isSafePositiveNumber(ov) and ov ~= spellID then
                overrideID = ov
            end
        end
    end

    local entry = {
        time = getTimestampStr(),
        event = tostring(eventName or "UNKNOWN"),
        spellID = spellID,
        spellName = spellName,
        overrideID = overrideID,
        cd = cdInfo,
        charges = chargeInfo,
        details = details,
    }

    local max = CooldownTrace.maxEntries
    CooldownTrace.head = (CooldownTrace.head % max) + 1
    CooldownTrace.entries[CooldownTrace.head] = entry
    if CooldownTrace.count < max then
        CooldownTrace.count = CooldownTrace.count + 1
    end

    -- 同步持久化至 SavedVariables
    if EAM.db then
        if not EAM.db.cooldownTrace then
            EAM.db.cooldownTrace = {}
        end
        local dbList = EAM.db.cooldownTrace
        table.insert(dbList, entry)
        if #dbList > 200 then
            table.remove(dbList, 1)
        end
    end
end

function CooldownTrace.clear()
    CooldownTrace.entries = {}
    CooldownTrace.count = 0
    CooldownTrace.head = 0
    if EAM.db then
        EAM.db.cooldownTrace = {}
    end
end

function CooldownTrace.dumpToString()
    local lines = {}
    table.insert(lines, "=== EventAlertMod Cooldown & Override Flight Trace ===")
    table.insert(lines, "Generated At: " .. ((date and date("%Y-%m-%d %H:%M:%S")) or "now"))
    table.insert(lines, "Addon Version: " .. tostring(EAM.version or "unknown"))
    table.insert(lines, "Total Trace Entries: " .. tostring(CooldownTrace.count))
    table.insert(lines, "------------------------------------------------------")

    local max = CooldownTrace.maxEntries
    local count = CooldownTrace.count
    local startIndex = 1
    if count == max then
        startIndex = CooldownTrace.head + 1
    end

    for i = 0, count - 1 do
        local index = ((startIndex - 1 + i) % max) + 1
        local e = CooldownTrace.entries[index]
        if e then
            local line = string.format("[%s] [%s] Spell=%s(%s)",
                e.time or "0.000",
                e.event or "?",
                tostring(e.spellID or 0),
                tostring(e.spellName or "")
            )
            if e.overrideID then
                line = line .. string.format(" Override=%s", tostring(e.overrideID))
            end
            if e.cd then
                line = line .. string.format(" CD(st=%.2f, dur=%.2f, gcd=%s, en=%s)",
                    e.cd.startTime or 0,
                    e.cd.duration or 0,
                    tostring(e.cd.isOnGCD),
                    tostring(e.cd.isEnabled)
                )
            end
            if e.charges then
                line = line .. string.format(" Charges(%s/%s, dur=%.2f)",
                    tostring(e.charges.current or "?"),
                    tostring(e.charges.max or "?"),
                    e.charges.duration or 0
                )
            end
            if e.details then
                if type(e.details) == "table" then
                    local detParts = {}
                    for k, v in pairs(e.details) do
                        table.insert(detParts, string.format("%s=%s", tostring(k), tostring(v)))
                    end
                    line = line .. " | " .. table.concat(detParts, ", ")
                else
                    line = line .. " | " .. tostring(e.details)
                end
            end
            table.insert(lines, line)
        end
    end

    table.insert(lines, "------------------------------------------------------")
    table.insert(lines, "=== Frost State & CDR Environment Snapshot ===")
    local playerFrost = CooldownTrace.detectPlayerFrostState and CooldownTrace.detectPlayerFrostState()
    if playerFrost then
        table.insert(lines, string.format("  - Player: FoF(寒冰指)=%d | Talents(天賦)=%s", playerFrost.fof or 0, playerFrost.talents or "None"))
    end
    local targetFrost = CooldownTrace.detectTargetFrozenState and CooldownTrace.detectTargetFrozenState()
    if targetFrost then
        local otherStr = targetFrost.otherAuras and (" (" .. targetFrost.otherAuras .. ")") or ""
        table.insert(lines, string.format("  - Target: %s | Winter's Chill(冬之寒意)=%d | Frozen=%s%s",
            targetFrost.name or "Unknown", targetFrost.winterChill or 0, tostring(targetFrost.isFrozen), otherStr))
    else
        table.insert(lines, "  - Target: (No target selected)")
    end

    table.insert(lines, "------------------------------------------------------")
    table.insert(lines, "=== Active Cooldowns Snapshot ===")
    local cdService = EAM.Services and EAM.Services.CooldownService
    if cdService and cdService.states then
        local activeFound = false
        for id, state in pairs(cdService.states) do
            if state and state.active then
                activeFound = true
                local timer = state.timer
                local rem = 0
                local now = (api.GetTime and api.GetTime()) or 0
                if timer and timer.expirationTime and timer.expirationTime > now then
                    rem = timer.expirationTime - now
                end
                local chargeStr = ""
                if state.isChargeBased and state.charges then
                    chargeStr = string.format(" | Charges=%s/%s", tostring(state.charges), tostring(state.maxCharges or "?"))
                end
                local placeholderStr = state.isPlaceholder and " | Placeholder=true" or ""
                table.insert(lines, string.format("  - Alert ID: %s | Spell: %s(%s) | Active=%s | Completed=%s | Shown=%s | Rem=%.2fs | Exp=%.2f%s%s",
                    tostring(id),
                    tostring(state.spellID or 0),
                    tostring(state.name or ""),
                    tostring(state.active),
                    tostring(state.completed),
                    tostring(state.shown),
                    rem,
                    timer and timer.expirationTime or 0,
                    chargeStr,
                    placeholderStr
                ))
            end
        end
        if not activeFound then
            table.insert(lines, "  (No active cooldowns running)")
        end
    end

    return table.concat(lines, "\n")
end

local function createTraceWindow()
    if CooldownTrace.frame then
        return CooldownTrace.frame
    end

    local f = api.CreateFrame("Frame", "EAM_CooldownTraceFrame", UIParent, "BackdropTemplate")
    f:SetSize(620, 520)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:SetBackdropColor(0.10, 0.08, 0.07, 0.98)
    f:SetBackdropBorderColor(0.85, 0.65, 0.35, 1.0)
    if EAM.Theme and EAM.Theme.registerFrame then EAM.Theme.registerFrame(f, "window") end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -16)
    title:SetText("EAM 冷卻與法術覆蓋飛行記錄器 (Cooldown & Override Flight Trace)")

    local closeBtn = api.CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)

    local scrollFrame = api.CreateFrame("ScrollFrame", "EAM_CooldownTraceScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -48)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -36, 48)

    local editBox = api.CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetWidth(560)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)

    local copyBtn = api.CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    copyBtn:SetSize(140, 26)
    copyBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
    copyBtn:SetText("全選記錄 (Ctrl+C)")
    copyBtn:SetScript("OnClick", function()
        editBox:HighlightText()
        editBox:SetFocus()
    end)

    local clearBtn = api.CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(110, 26)
    clearBtn:SetPoint("LEFT", copyBtn, "RIGHT", 10, 0)
    clearBtn:SetText("清空記錄")
    clearBtn:SetScript("OnClick", function()
        CooldownTrace.clear()
        editBox:SetText(CooldownTrace.dumpToString())
    end)

    local refreshBtn = api.CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refreshBtn:SetSize(110, 26)
    refreshBtn:SetPoint("LEFT", clearBtn, "RIGHT", 10, 0)
    refreshBtn:SetText("即時刷新")
    refreshBtn:SetScript("OnClick", function()
        editBox:SetText(CooldownTrace.dumpToString())
    end)

    CooldownTrace.frame = f
    CooldownTrace.editBox = editBox
    return f
end

function CooldownTrace.openWindow()
    local f = createTraceWindow()
    if f and CooldownTrace.editBox then
        CooldownTrace.editBox:SetText(CooldownTrace.dumpToString())
        f:Show()
        CooldownTrace.editBox:HighlightText()
        CooldownTrace.editBox:SetFocus()
    end
end
