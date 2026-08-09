--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/PromptExport
檔案: Debug\PromptExport.lua

理念:
- 將 DebugSnapshot、RuntimeProbe 與 EAM.DebugLog 轉成 AI 可讀、compact JSON-like output。
- 提供可手動複製的 UI 彈出視窗（Debug Export Window），方便玩家全選診斷資訊後回報給 AI。
- 專注於診斷匯出，與 Runtime Taint 保護隔離。

責任:
- 收集環境資訊、EAM 實體框架座標狀態、EventRouter 註冊事件、設定統計、提醒數量、Runtime 狀態、最近 40 條事件運行日誌與邊界警告。
- 建立並管理診斷 UI 視窗、多行 EditBox、捲軸與「全選診斷資訊」按鈕。

資料所有權:
- 擁有除錯視窗與文字框 widgets 的生命週期。
- 擁有 transient string builder buffers。

可變狀態:
- 僅在使用者點擊除錯診斷時 lazy-initialize 視窗並載入字串。

]]
local _, EAM = ...

local PromptExport = {
    frame = nil,
    editBox = nil,
    statusText = nil,
}
EAM.Debug.PromptExport = PromptExport

-- 產生精簡版 snapshot
function PromptExport.build()
    local snapshot = EAM.Debug.DebugState and EAM.Debug.DebugState.snapshot()
    if not snapshot then
        return "{}"
    end

    local report = snapshot.derived and snapshot.derived.migrationReport
    local initialized = snapshot.environment and snapshot.environment.initialized
    local warnings = snapshot.boundaryWarnings and #snapshot.boundaryWarnings or 0
    local derived = snapshot.derived or {}
    local auraCache = derived.auraCache or {}
    local renderer = derived.renderer or {}
    return "{environment:{interface:" .. tostring(EAM.Constants.INTERFACE)
        .. ",flavor:\"Retail\",initialized:" .. tostring(initialized)
        .. "},migration:{imported:" .. tostring(report and report.imported or 0)
        .. ",skipped:" .. tostring(report and report.skipped or 0)
        .. "},dbRevision:" .. tostring(derived.dbRevision or 0)
        .. ",auraCache:{player:" .. tostring(auraCache.playerInstances or 0)
        .. ",target:" .. tostring(auraCache.targetInstances or 0)
        .. "},renderer:{visible:" .. tostring(renderer.visibleIcons or 0)
        .. ",deferred:" .. tostring(renderer.deferred or 0)
        .. "},boundaryWarnings:" .. tostring(warnings) .. "}"
end

-- 產生詳盡、漂亮的 JSON-like 除錯資訊
function PromptExport.buildDetailed()
    local buffer = {}
    local function add(text)
        table.insert(buffer, text)
    end

    local snapshot = EAM.Debug.DebugState and EAM.Debug.DebugState.snapshot()
    local probe = EAM.Debug.RuntimeProbe and EAM.Debug.RuntimeProbe.snapshot({ runFrameProbe = false })

    add("{\n")
    add('  "addonVersion": "' .. tostring(EAM.version or "unknown") .. '",\n')

    -- Environment
    add('  "environment": {\n')
    if snapshot and snapshot.environment then
        local env = snapshot.environment
        add('    "interface": ' .. tostring(env.interface or 0) .. ',\n')
        add('    "flavor": "' .. tostring(env.flavor or "Retail") .. '",\n')
        add('    "initialized": ' .. tostring(env.initialized) .. ',\n')
        add('    "inCombat": ' .. tostring(env.inCombat) .. ',\n')
        add('    "fps": ' .. tostring(env.fps and math.floor(env.fps) or "null") .. ',\n')
        add('    "locale": "' .. tostring(probe and probe.environment and probe.environment.locale or "unknown") .. '"\n')
    else
        add('    "status": "unavailable"\n')
    end
    add('  },\n')

    -- Flow validation summary
    add('  "flowValidation": {\n')
    local flowSummary = snapshot and snapshot.derived and snapshot.derived.flowValidation
    if flowSummary then
        add('    "available": true,\n')
        add('    "total": ' .. tostring(flowSummary.total or 0) .. ',\n')
        add('    "passed": ' .. tostring(flowSummary.passed or 0) .. ',\n')
        add('    "failed": ' .. tostring(flowSummary.failed or 0) .. ',\n')
        add('    "skipped": ' .. tostring(flowSummary.skipped or 0) .. ',\n')
        add('    "pending": ' .. tostring(flowSummary.pending or 0) .. '\n')
    else
        add('    "available": false\n')
    end
    add('  },\n')

    -- EAM Frame 狀態探查
    add('  "alertFrame": {\n')
    local frameNames = { "selfAura", "targetAura", "spellCooldown", "itemCooldown", "classPower", "groundEffect", "totem" }
    local anyExists = false
    local frameInfoBuffer = {}
    for _, fName in ipairs(frameNames) do
        local fObj = _G["EAM_AlertFrame_" .. fName]
        if fObj then
            anyExists = true
            local p, rf, rp, x, y = fObj:GetPoint()
            local isShown = fObj:IsShown() == true
            local alpha = fObj:GetAlpha() or 1
            local scale = fObj:GetScale() or 1
            table.insert(frameInfoBuffer, '    "' .. fName .. '": {\n' ..
                '      "exists": true,\n' ..
                '      "isShown": ' .. tostring(isShown) .. ',\n' ..
                '      "alpha": ' .. tostring(alpha) .. ',\n' ..
                '      "point": "' .. tostring(p or "nil") .. '",\n' ..
                '      "xOffset": ' .. tostring(x or 0) .. ',\n' ..
                '      "yOffset": ' .. tostring(y or 0) .. ',\n' ..
                '      "scale": ' .. tostring(scale) .. '\n' ..
                '    }')
        else
            table.insert(frameInfoBuffer, '    "' .. fName .. '": {\n' ..
                '      "exists": false\n' ..
                '    }')
        end
    end
    add('    "exists": ' .. tostring(anyExists) .. ',\n')
    add(table.concat(frameInfoBuffer, ",\n"))
    add('\n  },\n')

    -- EventRouter 註冊事件探查
    add('  "eventRouter": {\n')
    local eventRouterList = {}
    if EAM.Modules.EventRouter and EAM.Modules.EventRouter.handlers then
        for ev, hd in pairs(EAM.Modules.EventRouter.handlers) do
            table.insert(eventRouterList, '    "' .. ev .. '": ' .. tostring(hd.count or 0))
        end
    end
    add(table.concat(eventRouterList, ",\n"))
    add('\n  },\n')

    -- EAM Config Stats
    add('  "config": {\n')
    local configList = {}
    if EAM.db and EAM.db.config then
        for k, v in pairs(EAM.db.config) do
            if type(v) == "boolean" or type(v) == "number" then
                table.insert(configList, '    "' .. k .. '": ' .. tostring(v))
            elseif type(v) == "string" and string.len(v) < 30 then
                table.insert(configList, '    "' .. k .. '": "' .. v .. '"')
            end
        end
    end
    add(table.concat(configList, ",\n"))
    add('\n  },\n')

    -- Alerts Counts
    local selfCount = 0
    local classCount = 0
    local targetCount = 0
    local spellCdCount = 0
    local itemCdCount = 0

    if EAM.db and EAM.db.alerts then
        local saved = EAM.Modules.SavedVariables
        if saved then
            local selfAlerts = saved.getAlertList(EAM.Constants.ALERT_KIND_AURA, "player") or {}
            for _, a in pairs(selfAlerts) do
                if a.fromPlayer == true or a.fromPlayer == nil then
                    selfCount = selfCount + 1
                else
                    classCount = classCount + 1
                end
            end
            local targetAlerts = saved.getAlertList(EAM.Constants.ALERT_KIND_AURA, "target") or {}
            for _ in pairs(targetAlerts) do targetCount = targetCount + 1 end

            local cdAlerts = saved.getAlertList(EAM.Constants.ALERT_KIND_SPELL_COOLDOWN, "player") or {}
            for _ in pairs(cdAlerts) do spellCdCount = spellCdCount + 1 end

            local itemAlerts = saved.getAlertList(EAM.Constants.ALERT_KIND_ITEM_COOLDOWN) or {}
            for _ in pairs(itemAlerts) do itemCdCount = itemCdCount + 1 end
        end
    end

    add('  "alertsCount": {\n')
    add('    "selfAura": ' .. selfCount .. ',\n')
    add('    "classAura": ' .. classCount .. ',\n')
    add('    "targetAura": ' .. targetCount .. ',\n')
    add('    "spellCd": ' .. spellCdCount .. ',\n')
    add('    "itemCd": ' .. itemCdCount .. '\n')
    add('  },\n')

    -- Runtime States
    local auraService = EAM.Services and EAM.Services.AuraService
    local cooldownService = EAM.Services and EAM.Services.CooldownService
    local itemCooldownService = EAM.Services and EAM.Services.ItemCooldownService
    local renderer = EAM.UI and EAM.UI.Renderer

    local auraStatesCount = 0
    if auraService and auraService.states then
        for _ in pairs(auraService.states) do auraStatesCount = auraStatesCount + 1 end
    end
    local cdStatesCount = 0
    if cooldownService and cooldownService.states then
        for _ in pairs(cooldownService.states) do cdStatesCount = cdStatesCount + 1 end
    end
    local itemStatesCount = 0
    if itemCooldownService and itemCooldownService.states then
        for _ in pairs(itemCooldownService.states) do itemStatesCount = itemStatesCount + 1 end
    end

    local memoryCount = collectgarbage and collectgarbage("count") or 0

    local auraActiveList = {}
    if auraService and auraService.states then
        for id, state in pairs(auraService.states) do
            if state.active then
                table.insert(auraActiveList, tostring(state.spellID or id))
            end
        end
    end

    local cdActiveList = {}
    if cooldownService and cooldownService.states then
        for id, state in pairs(cooldownService.states) do
            if state.active then
                table.insert(cdActiveList, tostring(state.spellID or id))
            end
        end
    end

    local itemActiveList = {}
    if itemCooldownService and itemCooldownService.states then
        for id, state in pairs(itemCooldownService.states) do
            if state.active then
                table.insert(itemActiveList, tostring(id))
            end
        end
    end

    local groundActiveList = {}
    local groundService = EAM.Services and EAM.Services.GroundEffectService
    if groundService and groundService.states then
        for id, state in pairs(groundService.states) do
            if state.active then
                table.insert(groundActiveList, tostring(state.spellID or id))
            end
        end
    end

    local totemActiveList = {}
    local totemService = EAM.Services and EAM.Services.TotemService
    if totemService and totemService.states then
        for id, state in pairs(totemService.states) do
            if state.active then
                table.insert(totemActiveList, tostring(id))
            end
        end
    end

    local powerActiveList = {}
    local powerService = EAM.Services and EAM.Services.ClassPowerService
    if powerService and powerService.states then
        for id, state in pairs(powerService.states) do
            if state.active then
                table.insert(powerActiveList, tostring(id))
            end
        end
    end

    local managerGlowList = {}
    local alertManager = EAM.Managers and EAM.Managers.AlertManager
    if alertManager and alertManager.glowSpells then
        for spellID, isGlowing in pairs(alertManager.glowSpells) do
            if isGlowing then
                table.insert(managerGlowList, tostring(spellID))
            end
        end
    end

    add('  "runtimeStats": {\n')
    add('    "memoryKB": ' .. string.format("%.1f", memoryCount) .. ',\n')
    add('    "auraStates": ' .. auraStatesCount .. ',\n')
    add('    "cooldownStates": ' .. cdStatesCount .. ',\n')
    add('    "itemCooldownStates": ' .. itemStatesCount .. ',\n')
    add('    "activeAuras": [' .. table.concat(auraActiveList, ",") .. '],\n')
    add('    "activeCooldowns": [' .. table.concat(cdActiveList, ",") .. '],\n')
    add('    "activeItemCooldowns": [' .. table.concat(itemActiveList, ",") .. '],\n')
    add('    "activeGroundEffects": [' .. table.concat(groundActiveList, ",") .. '],\n')
    add('    "activeTotems": [' .. table.concat(totemActiveList, ",") .. '],\n')
    add('    "activeClassPowers": [' .. table.concat(powerActiveList, ",") .. '],\n')
    add('    "managerGlowSpells": [' .. table.concat(managerGlowList, ",") .. '],\n')
    add('    "renderer": {\n')
    local visibleIconsCount = 0
    local anyLayoutDirty = false
    if renderer and renderer.frames then
        for _, fState in pairs(renderer.frames) do
            visibleIconsCount = visibleIconsCount + (fState.orderCount or 0)
            if fState.layoutDirty then
                anyLayoutDirty = true
            end
        end
    end
    local frameIconsInfo = {}
    if renderer and renderer.frames then
        for fName, fState in pairs(renderer.frames) do
            local iconList = {}
            for index = 1, fState.orderCount do
                local id = fState.order[index]
                local icon = fState.icons[id]
                if icon then
                    local renderInfo = icon.rendered or {}
                    table.insert(iconList, '{' ..
                        '"id":"' .. tostring(id) .. '",' ..
                        '"isParasite":' .. tostring(icon.isParasite == true) .. ',' ..
                        '"layoutX":' .. tostring(renderInfo.layoutX or 0) .. ',' ..
                        '"layoutY":' .. tostring(renderInfo.layoutY or 0) .. ',' ..
                        '"layoutSize":' .. tostring(renderInfo.layoutSize or 0) .. ',' ..
                        '"isShown":' .. tostring(icon:IsShown() == true) ..
                        '}')
                end
            end
            table.insert(frameIconsInfo, '        "' .. fName .. '": [' .. table.concat(iconList, ",") .. ']')
        end
    end
    add('      "visibleIcons": ' .. tostring(visibleIconsCount) .. ',\n')
    add('      "deferred": ' .. tostring(renderer and renderer.deferredCount or 0) .. ',\n')
    add('      "layoutDirty": ' .. tostring(anyLayoutDirty) .. ',\n')
    add('      "frameIcons": {\n')
    add(table.concat(frameIconsInfo, ",\n"))
    add('\n      }\n')
    add('    }\n')
    add('  },\n')

    -- Runtime Debug Logs
    add('  "debugLogs": [\n')
    local logList = {}
    if EAM.DebugLog then
        for i = 1, #EAM.DebugLog do
            local escaped = string.gsub(EAM.DebugLog[i], '"', '\\"')
            table.insert(logList, '    "' .. escaped .. '"')
        end
    end
    add(table.concat(logList, ",\n"))
    add('\n  ]\n')

    add("}")
    return table.concat(buffer)
end

-- Lazy-initialize除錯視窗 UI
local function createDebugFrame()
    if PromptExport.frame then
        return PromptExport.frame
    end

    local api = EAM.API
    local f = api.CreateFrame("Frame", "EAM_DebugExportFrame", UIParent, "BackdropTemplate")
    f:SetSize(500, 480)
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
    f:SetBackdropColor(0.12, 0.08, 0.06, 0.98)
    f:SetBackdropBorderColor(0.8, 0.6, 0.4, 1.0)

    _G["EAM_DebugExportFrame"] = f
    tinsert(UISpecialFrames, "EAM_DebugExportFrame")

    -- 頂部標題
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -16)
    title:SetTextColor(0.95, 0.85, 0.4, 1.0)
    title:SetText("EAM 系統診斷與除錯資訊匯出 (Debug)")

    -- 內邊框
    local scrollBG = api.CreateFrame("Frame", nil, f, "BackdropTemplate")
    scrollBG:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -45)
    scrollBG:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 60)
    scrollBG:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    scrollBG:SetBackdropColor(0.05, 0.03, 0.02, 0.9)
    scrollBG:SetBackdropBorderColor(0.5, 0.35, 0.2, 0.8)

    -- ScrollFrame
    local sf = api.CreateFrame("ScrollFrame", "EAM_DebugExportScrollFrame", scrollBG, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", scrollBG, "TOPLEFT", 8, -8)
    sf:SetPoint("BOTTOMRIGHT", scrollBG, "BOTTOMRIGHT", -28, 8)

    -- ScrollChild 容器
    local scrollChild = api.CreateFrame("Frame", nil, sf)
    scrollChild:SetSize(430, 340)
    sf:SetScrollChild(scrollChild)

    -- EditBox 文字欄位
    local eb = api.CreateFrame("EditBox", nil, scrollChild)
    eb:SetSize(420, 330)
    eb:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -4)
    eb:SetMultiLine(true)
    eb:SetMaxLetters(999999)
    eb:SetFontObject("ChatFontNormal")
    eb:SetAutoFocus(false)

    eb:SetScript("OnTextChanged", function(self)
        local textHeight = self:GetHeight()
        if textHeight < 330 then textHeight = 330 end
        scrollChild:SetHeight(textHeight + 10)
    end)

    eb:SetScript("OnEscapePressed", function(self)
        f:Hide()
    end)

    PromptExport.editBox = eb

    -- 狀態提示字串 (綠色)
    local statusText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 46)
    statusText:SetTextColor(0.2, 1.0, 0.2, 1.0)
    statusText:SetText("")
    PromptExport.statusText = statusText

    -- 底部按鈕 1: 聚焦並全選，玩家再按 Ctrl+C
    local copyBtn = api.CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    copyBtn:SetSize(180, 26)
    copyBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 18)
    copyBtn:SetText(EAM.L.EAM_PROMPT_COPY_SELECT or "全選診斷資訊")
    local cnTex = copyBtn:GetNormalTexture()
    if cnTex then cnTex:SetVertexColor(0.8, 0.2, 0.2, 1) end
    local cpTex = copyBtn:GetPushedTexture()
    if cpTex then cpTex:SetVertexColor(0.6, 0.1, 0.1, 1) end
    copyBtn:SetScript("OnClick", function()
        local prepared = EAM.Util.prepareEditBoxManualCopy(eb)
        if prepared then
            statusText:SetText(EAM.L.EAM_PROMPT_COPY_SELECTED or "|cff20ff20診斷資訊已全選；請按 Ctrl+C 複製後回報。|r")
        else
            statusText:SetText(EAM.L.EAM_COPY_SELECTION_FAILED or "無法全選文字，請手動按 Ctrl+A、Ctrl+C。")
        end
    end)

    -- 底部按鈕 2: 重新整理
    local refreshBtn = api.CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    refreshBtn:SetSize(100, 26)
    refreshBtn:SetPoint("LEFT", copyBtn, "RIGHT", 10, 0)
    refreshBtn:SetText("重新整理")
    local rnTex = refreshBtn:GetNormalTexture()
    if rnTex then rnTex:SetVertexColor(0.8, 0.2, 0.2, 1) end
    refreshBtn:SetScript("OnClick", function()
        eb:SetText(PromptExport.buildDetailed())
        eb:HighlightText()
        statusText:SetText("")
    end)

    -- 底部按鈕 3: 關閉視窗
    local closeBtn = api.CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 26)
    closeBtn:SetPoint("LEFT", refreshBtn, "RIGHT", 10, 0)
    closeBtn:SetText("關閉視窗")
    local clnTex = closeBtn:GetNormalTexture()
    if clnTex then clnTex:SetVertexColor(0.8, 0.2, 0.2, 1) end
    closeBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    PromptExport.frame = f
    return f
end

-- 開啟除錯診斷與匯出視窗
function PromptExport.openWindow()
    local f = createDebugFrame()
    if not f then return end

    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        if PromptExport.editBox then
            PromptExport.editBox:SetText(PromptExport.buildDetailed())
            PromptExport.editBox:HighlightText()
        end
        if PromptExport.statusText then
            PromptExport.statusText:SetText("")
        end
    end
end
