--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/SVGCapabilityProbe
檔案: Debug\SVGCapabilityProbe.lua

責任:
- 由玩家啟動 Texture:SetSVG 與 Frame:CreateVectorGraphics A/B 顯示測試。
- 驗證 SetSVG、HasSVG、GetSVGFileID 分類及 ClearSVG/reload 生命週期。
- 產生不含原始 fileID 的結構化 JSON 報告。

邊界:
- 不在戰鬥中建立 Region 或載入 SVG。
- 不自動操作遊戲、不讀 Secret 值、不把 API 接受冒充人工視覺通過。
- 12.0.7 缺少 API 時只回報 unsupported，不呼叫不存在的方法。
]]
local _, EAM = ...

local api = EAM.API
local Theme = EAM.Theme
local Locale = EAM.Locale
local Util = EAM.Util
local SVG_ASSET = "Interface\\AddOns\\EventAlertMod\\Media\\SVG\\eam-svg-probe.svg"
local CASE_IDS = {
    "svg.vector_graphics.set_svg",
    "svg.texture.set_svg",
}

local SVGCapabilityProbe = {
    schemaVersion = 1,
    initialized = false,
    active = false,
    frame = nil,
    cards = {},
    cases = {},
    observations = {},
    startedAt = nil,
    stoppedAt = nil,
    lastReport = nil,
    lastReportJSON = nil,
}

EAM.Debug.SVGCapabilityProbe = SVGCapabilityProbe

local function text(key, fallback)
    return EAM.L and EAM.L[key] or fallback
end

local function localized(key, fallback)
    return { key = key, fallback = fallback }
end

local function setWidgetText(target, value)
    if type(value) == "table" and type(value.key) == "string" then
        Locale.bindText(target, value.key, value.fallback)
    else
        target:SetText(value)
    end
end

local function sessionTime()
    return api.GetTime and api.GetTime() or 0
end

local function createButton(parent, label, width, point, relativeTo, relativePoint, x, y, callback)
    local button = api.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    if Theme and Theme.registerButton then Theme.registerButton(button) end
    button:SetSize(width, 24)
    button:SetPoint(point, relativeTo, relativePoint, x, y)
    setWidgetText(button, label)
    button:SetScript("OnClick", callback)
    return button
end

local function classifyHasSVG(target)
    if not target or type(target.HasSVG) ~= "function" then
        return "unavailable"
    end
    local ok, result = pcall(target.HasSVG, target)
    if not ok then
        return "error"
    end
    return result == true and "true" or "false"
end

local function classifyFileID(target)
    if not target or type(target.GetSVGFileID) ~= "function" then
        return "unavailable"
    end
    local ok, fileID = pcall(target.GetSVGFileID, target)
    if not ok then
        return "error"
    end
    if Util.isSafeNumber(fileID) then
        if fileID > 0 then
            return "positive-number"
        end
        return fileID < 0 and "negative-number" or "zero"
    end
    return "inaccessible"
end

local function runObjectCase(caseID, kind, target)
    local result = {
        id = caseID,
        kind = kind,
        apiAvailable = target ~= nil and type(target.SetSVG) == "function",
        setResult = "unsupported",
        hasSVG = "unavailable",
        fileIDClass = "unavailable",
        clearReload = "unavailable",
    }
    SVGCapabilityProbe.cases[caseID] = result
    if not result.apiAvailable then
        return result
    end

    local setOK, setResult = pcall(target.SetSVG, target, SVG_ASSET)
    if not setOK then
        result.setResult = "error"
        return result
    end
    result.setResult = setResult == true and "accepted" or "rejected"
    result.hasSVG = classifyHasSVG(target)
    result.fileIDClass = classifyFileID(target)

    if result.setResult ~= "accepted" or type(target.ClearSVG) ~= "function" then
        return result
    end

    local stateInspectable = type(target.HasSVG) == "function"
    local clearOK = pcall(target.ClearSVG, target)
    local clearedState = stateInspectable and classifyHasSVG(target) or "unavailable"
    local reloadOK, reloadResult = pcall(target.SetSVG, target, SVG_ASSET)
    local reloadedState = stateInspectable and classifyHasSVG(target) or "unavailable"
    local lifecycleAccepted = clearOK and reloadOK and reloadResult == true
    if stateInspectable then
        lifecycleAccepted = lifecycleAccepted
            and clearedState == "false"
            and reloadedState == "true"
    end
    if lifecycleAccepted then
        result.clearReload = "pass"
    else
        result.clearReload = "fail"
    end
    result.hasSVG = reloadedState
    result.fileIDClass = classifyFileID(target)
    return result
end

local function updateCard(card, caseID)
    if not card or not card.resultText then
        return
    end
    local case = SVGCapabilityProbe.cases[caseID] or {}
    local visual = SVGCapabilityProbe.observations[caseID] or "pending"
    card.resultText:SetText((case.setResult or "pending") .. " / " .. visual)
end

local function createCard(parent, titleText, x, kind, caseID)
    local card = api.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(250, 190)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -58)
    card:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    card:SetBackdropColor(0.04, 0.04, 0.06, 0.95)

    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", card, "TOP", 0, -8)
    setWidgetText(title, titleText)

    local viewport = api.CreateFrame("Frame", nil, card, "BackdropTemplate")
    viewport:SetSize(104, 104)
    viewport:SetPoint("TOP", card, "TOP", 0, -30)
    viewport:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    viewport:SetBackdropColor(0.08, 0.08, 0.10, 1)

    local target
    if kind == "vector" and type(viewport.CreateVectorGraphics) == "function" then
        local ok, created = pcall(viewport.CreateVectorGraphics, viewport, nil, "ARTWORK")
        if ok then
            target = created
        end
    elseif kind == "texture" and type(viewport.CreateTexture) == "function" then
        target = viewport:CreateTexture(nil, "ARTWORK")
    end
    if target and type(target.SetAllPoints) == "function" then
        target:SetAllPoints(viewport)
    end

    local resultText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resultText:SetPoint("TOP", viewport, "BOTTOM", 0, -4)
    resultText:SetText("pending")

    local passButton = createButton(
        card,
        localized("EAM_SVG_PROBE_PASS", "顯示正常"),
        70,
        "BOTTOMLEFT",
        card,
        "BOTTOMLEFT",
        8,
        8,
        function()
            SVGCapabilityProbe.markVisual(caseID, "pass")
        end
    )
    createButton(
        card,
        localized("EAM_SVG_PROBE_FAIL", "顯示異常"),
        70,
        "LEFT",
        passButton,
        "RIGHT",
        4,
        0,
        function()
            SVGCapabilityProbe.markVisual(caseID, "fail")
        end
    )
    createButton(
        card,
        localized("EAM_SVG_PROBE_BLOCKED", "無法測試"),
        82,
        "BOTTOMRIGHT",
        card,
        "BOTTOMRIGHT",
        -8,
        8,
        function()
            SVGCapabilityProbe.markVisual(caseID, "blocked")
        end
    )

    return {
        frame = card,
        viewport = viewport,
        target = target,
        resultText = resultText,
        caseID = caseID,
        kind = kind,
    }
end

local function createFrame()
    if SVGCapabilityProbe.frame then
        return SVGCapabilityProbe.frame
    end
    if not api.CreateFrame or not UIParent then
        return nil
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return nil
    end

    local frame = api.CreateFrame("Frame", "EAM_SVGCapabilityFrame", UIParent, "BackdropTemplate")
    frame:SetSize(540, 300)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    frame:SetBackdropColor(0.03, 0.03, 0.05, 0.97)
    if Theme and Theme.registerFrame then Theme.registerFrame(frame, "window") end
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    Locale.bindText(title, "EAM_SVG_PROBE_TITLE", "SVG／VectorGraphics 能力測試")
    if Theme and Theme.registerText then Theme.registerText(title, "title") end

    local description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOP", frame, "TOP", 0, -34)
    Locale.bindText(
        description,
        "EAM_SVG_PROBE_DESC",
        "兩格應顯示相同的青框、黃紫三角圖案；請分別標記目視結果。"
    )

    SVGCapabilityProbe.cards.vector = createCard(
        frame,
        localized("EAM_SVG_PROBE_VECTOR", "VectorGraphics:SetSVG"),
        15,
        "vector",
        CASE_IDS[1]
    )
    SVGCapabilityProbe.cards.texture = createCard(
        frame,
        localized("EAM_SVG_PROBE_TEXTURE", "Texture:SetSVG"),
        275,
        "texture",
        CASE_IDS[2]
    )

    createButton(
        frame,
        localized("EAM_SVG_PROBE_FINISH", "完成並產生報告"),
        180,
        "BOTTOM",
        frame,
        "BOTTOM",
        0,
        12,
        function()
            local ok, report, reportJSON = SVGCapabilityProbe.stop()
            local panel = EAM.Debug.FlowTestPanel
            if ok and panel and panel.showExternalReport then
                panel.showExternalReport(
                    reportJSON,
                    text("EAM_SVG_PROBE_STOPPED", "SVG 能力報告已完成；請全選後按 Ctrl+C 回灌。"),
                    not report or report.status ~= "pass"
                )
            end
            if panel and panel.svgButton then
                panel.svgButton:SetText(text("EAM_FLOW_BUTTON_SVG", "SVG 能力"))
            end
        end
    )

    SVGCapabilityProbe.frame = frame
    return frame
end

local function buildCaseList()
    local list = {}
    for index = 1, #CASE_IDS do
        local source = SVGCapabilityProbe.cases[CASE_IDS[index]] or {}
        list[index] = {
            id = CASE_IDS[index],
            kind = source.kind or (index == 1 and "vector" or "texture"),
            apiAvailable = source.apiAvailable == true,
            setResult = source.setResult or "pending",
            hasSVG = source.hasSVG or "pending",
            fileIDClass = source.fileIDClass or "pending",
            clearReload = source.clearReload or "pending",
            visualObservation = SVGCapabilityProbe.observations[CASE_IDS[index]] or "pending",
        }
    end
    return list
end

function SVGCapabilityProbe.buildReport()
    local validationEnvironment = EAM.Debug.ValidationEnvironment
    local environment, environmentWarnings
    if validationEnvironment and validationEnvironment.snapshot then
        environment, environmentWarnings = validationEnvironment.snapshot()
    else
        environment = { executionSource = "client", channelValidation = "unknown" }
        environmentWarnings = { "validationEnvironmentUnavailable" }
    end

    local warnings = {}
    for index = 1, #(environmentWarnings or {}) do
        warnings[#warnings + 1] = environmentWarnings[index]
    end
    local cases = buildCaseList()
    local required = Util.isSafeNumber(environment.interface) and environment.interface >= 120100
    local aggregateObservation = "pass"
    local capabilityPass = true
    for index = 1, #cases do
        local case = cases[index]
        if case.visualObservation == "fail" then
            aggregateObservation = "fail"
        elseif case.visualObservation == "blocked" and aggregateObservation ~= "fail" then
            aggregateObservation = "blocked"
        elseif case.visualObservation == "pending" and aggregateObservation == "pass" then
            aggregateObservation = "pending"
        end
        if required then
            if case.setResult ~= "accepted" then
                warnings[#warnings + 1] = "svgSetRejected:" .. case.id
                capabilityPass = false
            end
            if case.kind == "vector" then
                if case.hasSVG ~= "true" then
                    warnings[#warnings + 1] = "svgHasStateInvalid:" .. case.id
                    capabilityPass = false
                end
                if case.fileIDClass ~= "positive-number"
                    and case.fileIDClass ~= "zero"
                    and case.fileIDClass ~= "negative-number"
                then
                    warnings[#warnings + 1] = "svgFileIDInvalid:" .. case.id
                    capabilityPass = false
                end
            else
                if case.hasSVG ~= "unavailable" and case.hasSVG ~= "true" then
                    warnings[#warnings + 1] = "svgHasStateInvalid:" .. case.id
                    capabilityPass = false
                end
                if case.fileIDClass ~= "unavailable"
                    and case.fileIDClass ~= "positive-number"
                    and case.fileIDClass ~= "zero"
                    and case.fileIDClass ~= "negative-number"
                then
                    warnings[#warnings + 1] = "svgFileIDInvalid:" .. case.id
                    capabilityPass = false
                end
            end
            if case.clearReload ~= "pass" then
                warnings[#warnings + 1] = "svgLifecycleFailed:" .. case.id
                capabilityPass = false
            end
            if case.visualObservation == "pending" then
                warnings[#warnings + 1] = "humanVisualConfirmationRequired:" .. case.id
            end
        end
    end

    local status = SVGCapabilityProbe.active and "active" or "incomplete"
    if not required then
        status = "unsupported"
    elseif aggregateObservation == "fail" then
        status = "fail"
    elseif aggregateObservation == "blocked" then
        status = "blocked"
    elseif aggregateObservation == "pass"
        and capabilityPass
        and SVGCapabilityProbe.active == false
        and SVGCapabilityProbe.stoppedAt ~= nil
        and #warnings == 0
        and environment.executionSource == "client"
        and environment.channelValidation == "pass"
    then
        status = "pass"
    end

    local vectorTarget = SVGCapabilityProbe.cards.vector and SVGCapabilityProbe.cards.vector.target
    local textureTarget = SVGCapabilityProbe.cards.texture and SVGCapabilityProbe.cards.texture.target
    local report = {
        schema = SVGCapabilityProbe.schemaVersion,
        type = "EAM_SVG_CAPABILITY_REPORT",
        purpose = "capability-probe",
        status = status,
        rawFileIDsCollected = false,
        asset = {
            relativePath = "Media/SVG/eam-svg-probe.svg",
            externalReferences = false,
            packagedAssetRequired = true,
        },
        session = {
            active = SVGCapabilityProbe.active,
            startedAtSessionMs = SVGCapabilityProbe.startedAt,
            stoppedAtSessionMs = SVGCapabilityProbe.stoppedAt,
            visualObservation = aggregateObservation,
        },
        environment = environment,
        automation = {
            playerOperated = true,
            gameInputAutomated = false,
        },
        capabilities = {
            createVectorGraphics = vectorTarget ~= nil,
            vectorSetSVG = vectorTarget and type(vectorTarget.SetSVG) == "function" or false,
            vectorClearSVG = vectorTarget and type(vectorTarget.ClearSVG) == "function" or false,
            vectorHasSVG = vectorTarget and type(vectorTarget.HasSVG) == "function" or false,
            vectorGetSVGFileID = vectorTarget and type(vectorTarget.GetSVGFileID) == "function" or false,
            textureSetSVG = textureTarget and type(textureTarget.SetSVG) == "function" or false,
            textureClearSVG = textureTarget and type(textureTarget.ClearSVG) == "function" or false,
            textureHasSVG = textureTarget and type(textureTarget.HasSVG) == "function" or false,
            textureGetSVGFileID = textureTarget and type(textureTarget.GetSVGFileID) == "function" or false,
            interfaceRequired = required,
        },
        cases = cases,
        boundaryWarnings = warnings,
    }
    local encoder = EAM.Debug.FlowTestRunner and EAM.Debug.FlowTestRunner.encodeJSON
    local reportJSON = encoder and encoder(report) or nil
    SVGCapabilityProbe.lastReport = report
    SVGCapabilityProbe.lastReportJSON = reportJSON
    _G.EAM_SVG_CAPABILITY_REPORT_JSON = reportJSON
    return report, reportJSON
end

function SVGCapabilityProbe.markVisual(caseID, status)
    if not SVGCapabilityProbe.active
        or (caseID ~= CASE_IDS[1] and caseID ~= CASE_IDS[2])
    then
        return false, "inactiveOrUnknownCase"
    end
    if status ~= "pass" and status ~= "fail" and status ~= "blocked" then
        return false, "invalidStatus"
    end
    SVGCapabilityProbe.observations[caseID] = status
    local card = caseID == CASE_IDS[1] and SVGCapabilityProbe.cards.vector
        or SVGCapabilityProbe.cards.texture
    updateCard(card, caseID)
    SVGCapabilityProbe.buildReport()
    return true, status
end

function SVGCapabilityProbe.initialize()
    if SVGCapabilityProbe.initialized then
        return true
    end
    local frame = createFrame()
    if not frame then
        return false, "combatDeferred"
    end
    SVGCapabilityProbe.initialized = true
    return true
end

function SVGCapabilityProbe.start()
    if EAM.FlowTestEnvironment ~= "offline-mock" then
        local validationEnvironment = EAM.Debug.ValidationEnvironment
        local declaredInstallation = validationEnvironment
            and validationEnvironment.getDeclaredInstallation
            and validationEnvironment.getDeclaredInstallation()
        if not declaredInstallation then
            return false, "clientInstallationUnconfirmed"
        end
        local environment = validationEnvironment.snapshot()
        if environment.channelValidation ~= "pass" then
            return false, "clientEnvironmentMismatch"
        end
    end
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false, "combatDeferred"
    end
    local initialized, reason = SVGCapabilityProbe.initialize()
    if not initialized then
        return false, reason
    end

    wipe(SVGCapabilityProbe.cases)
    wipe(SVGCapabilityProbe.observations)
    for index = 1, #CASE_IDS do
        SVGCapabilityProbe.observations[CASE_IDS[index]] = "pending"
    end
    SVGCapabilityProbe.active = true
    SVGCapabilityProbe.startedAt = sessionTime()
    SVGCapabilityProbe.stoppedAt = nil
    SVGCapabilityProbe.frame:Show()

    runObjectCase(CASE_IDS[1], "vector", SVGCapabilityProbe.cards.vector.target)
    runObjectCase(CASE_IDS[2], "texture", SVGCapabilityProbe.cards.texture.target)
    updateCard(SVGCapabilityProbe.cards.vector, CASE_IDS[1])
    updateCard(SVGCapabilityProbe.cards.texture, CASE_IDS[2])
    local report, reportJSON = SVGCapabilityProbe.buildReport()
    return true, report, reportJSON
end

function SVGCapabilityProbe.stop()
    if not SVGCapabilityProbe.active then
        return false, "inactive"
    end
    SVGCapabilityProbe.active = false
    SVGCapabilityProbe.stoppedAt = sessionTime()
    SVGCapabilityProbe.frame:Hide()
    local report, reportJSON = SVGCapabilityProbe.buildReport()
    return true, report, reportJSON
end

function SVGCapabilityProbe.isActive()
    return SVGCapabilityProbe.active
end

function SVGCapabilityProbe.getLastReportJSON()
    return SVGCapabilityProbe.lastReportJSON
end
