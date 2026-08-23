--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/Slash
檔案: UI\Slash.lua

理念:
- /eam 是使用者低成本入口，負責協調模組而非承擔業務邏輯。
- 在 Retail 12.1 安全邊界內恢復經典 EAM 的 list、lookup 與 showcast 使用習慣。

責任:
- 註冊 slash command、解析文字、呼叫 Options/Debug/SavedVariables/service API。

資料所有權:
- 擁有 slash command handler；不保存監控或探索資料。

可變狀態:
- 可觸發其他模組公開 API；不可直接改 service/private tables。

邊界:
- 不做 combat automation，不呼叫 UnitAura，不掃描整個 SpellID 空間。
- 不讀、比較、字串化或索引 secret/protected data。

效能注意:
- Slash 非 hot path；輸出字串只在使用者呼叫時建立。

Retail API 注意:
- SlashCmdList 是 WoW 標準入口；需實機確認 /eam 與 /eventalertmod 註冊。
]]
local _, EAM = ...

local Slash = {}
EAM.UI.Slash = Slash

local Util = EAM.Util
local mathFloor = math.floor
local stringFormat = string.format

local function printLine(text)
    print("|cff00ff96EAM|r " .. text)
end

local function nextToken(input)
    return string.gmatch(input or "", "%S+")
end

local function commandArguments(input)
    return string.match(input or "", "^%s*%S+%s+(.+)%s*$")
end

local function refreshAfterChange(kind, unit, numericID)
    if kind == "aura" and EAM.Services.AuraService then
        EAM.Services.AuraService.refreshUnit(unit or "player", "SLASH_CONFIG")
    elseif kind == "cooldown" and EAM.Services.CooldownService then
        EAM.Services.CooldownService.refreshSpell(numericID, "SLASH_CONFIG")
    elseif kind == "item" and EAM.Services.ItemCooldownService then
        EAM.Services.ItemCooldownService.refreshItem(numericID, "SLASH_CONFIG")
    end
end

local function printHelp()
    printLine(EAM.L.EAM_SLASH_HELP_OPT or "/eam opt - 開啟設定")
    printLine(EAM.L.EAM_SLASH_HELP_LIST or "/eam list - 顯示目前職業監控清單")
    printLine(EAM.L.EAM_SLASH_HELP_LOOKUP or "/eam lookup <名稱> - 查詢目前職業候選")
    printLine(EAM.L.EAM_SLASH_HELP_LOOKUPFULL or "/eam lookupfull <完整名稱> - 精確查詢目前職業候選")
    printLine(EAM.L.EAM_SLASH_HELP_SHOWCAST or "/eam showcast - 開始或停止本次登入施法記錄")
    printLine(EAM.L.EAM_SLASH_HELP_SHOW or "/eam show/showtarget - 顯示 12.1 安全替代說明")
    printLine(EAM.L.EAM_SLASH_HELP_DOCTOR or "/eam doctor - 顯示 Retail/PTR API 邊界診斷")
    printLine(EAM.L.EAM_SLASH_HELP_VALIDATE or "/eam validate - 同 /eam doctor")
    printLine(EAM.L.EAM_SLASH_HELP_DEBUG or "/eam debug - 顯示除錯摘要")
    printLine(EAM.L.EAM_SLASH_HELP_EXPORT or "/eam export - 輸出精簡 AI debug 狀態")
    printLine(EAM.L.EAM_SLASH_HELP_PROFILE or "/eam profile [export|import] - 開啟職業 profile JSON/Base64 分享")
    printLine(EAM.L.EAM_SLASH_HELP_TEST or "/eam test [quick|core|boundary|aura121|all|live] - 流程驗證或真人實機回報")
    printLine(EAM.L.EAM_SLASH_HELP_ADD or "/eam add <spellID> - 新增 player aura")
printLine(EAM.L.EAM_SLASH_HELP_ADD_TARGET or "/eam add target [spellID] - 新增 target aura；無 ID 開啟手動視窗")
    printLine(EAM.L.EAM_SLASH_HELP_UNITPOWER or "/eam unitpower background <RESOURCE_KEY> - 標記背景資源缺少事件，啟用共用 sampler")
    printLine(EAM.L.EAM_SLASH_HELP_ADD_CD or "/eam add cd <spellID> - 新增 spell cooldown")
    printLine(EAM.L.EAM_SLASH_HELP_ADD_ITEM or "/eam add item <itemID> - 新增 item cooldown")
    printLine(EAM.L.EAM_SLASH_HELP_REMOVE or "/eam remove <spellID|target|cd|item> <id> - 移除 alert")
end

local function parseKindAndID(iterator)
    local kind = "aura"
    local unit = "player"
    local token = iterator()
    if not token then
        return nil
    end

    token = string.lower(token)
    if token == "player" or token == "self" then
        unit = "player"
        token = iterator()
    elseif token == "target" then
        unit = "target"
        token = iterator()
    elseif token == "cd" or token == "cooldown" or token == "spellcooldown" then
        kind = "cooldown"
        unit = "player"
        token = iterator()
    elseif token == "item" or token == "itemcooldown" then
        kind = "item"
        unit = nil
        token = iterator()
    end

    local numericID = tonumber(token)
    if not numericID or numericID <= 0 then
        return nil
    end

    return kind, unit, mathFloor(numericID)
end

local function mutateAlert(action, input)
    local savedVariables = EAM.Modules.SavedVariables
    if not savedVariables then
        printLine(EAM.L.EAM_SLASH_NOT_INIT or "SavedVariables 尚未初始化。")
        return
    end

    if action == "add" and string.match(input, "^%s*add%s+target%s*$") then
        local service = EAM.Services and EAM.Services.TooltipMonitorService
        if service and type(service.openManualTargetAuraMenu) == "function" then
            local opened, reason = service.openManualTargetAuraMenu()
            if opened then
                printLine(EAM.L.EAM_SLASH_TARGET_POPUP_OPENED or "EAM：已開啟目標光環手動加入視窗。")
            else
                printLine((EAM.L.EAM_SLASH_TARGET_POPUP_FAILED or "EAM：無法開啟目標光環手動視窗：") .. tostring(reason))
            end
        else
            printLine(EAM.L.EAM_SLASH_TARGET_POPUP_FAILED or "EAM：目標光環手動視窗尚未載入。")
        end
        return
    end

    local iterator = nextToken(input)
    iterator()
    local kind, unit, numericID = parseKindAndID(iterator)
    if not kind then
        printHelp()
        return
    end

    local ok, id, status
    if kind == "aura" then
        if action == "add" then
            ok, id, status = savedVariables.addAuraAlert(unit, numericID)
        else
            ok, id, status = savedVariables.removeAuraAlert(unit, numericID)
        end
    elseif kind == "cooldown" then
        if action == "add" then
            ok, id, status = savedVariables.addSpellCooldownAlert(numericID)
        else
            ok, id, status = savedVariables.removeSpellCooldownAlert(numericID)
        end
    elseif kind == "item" then
        if action == "add" then
            ok, id, status = savedVariables.addItemCooldownAlert(numericID)
        else
            ok, id, status = savedVariables.removeItemCooldownAlert(numericID)
        end
    end

    if ok then
        refreshAfterChange(kind, unit, numericID)
        printLine(status .. ": " .. id)
    else
        printLine((EAM.L.EAM_SLASH_OP_FAIL or "操作失敗: ") .. tostring(status or id))
    end
end

local function getSafeSpellName(spellID)
    local service = EAM.Services and EAM.Services.SpellInfoService
    local info = service and service.getSpellInfo and service.getSpellInfo(spellID)
    if info and info.factsSafe and Util.isSafeString(info.name) then
        return info.name
    end
    return EAM.L.EAM_SLASH_UNKNOWN_NAME or "名稱尚不可用"
end

local function printAlertList(label, list, idField)
    if not Util.isReadableTable(list) then
        return 0
    end
    local count = 0
    for index = 1, #list do
        local alert = list[index]
        if Util.isReadableTable(alert) then
            local numericID = Util.readSafeScalar(alert[idField])
            if Util.isSafePositiveNumber(numericID) then
                numericID = mathFloor(numericID)
                local name = idField == "spellID" and getSafeSpellName(numericID)
                    or (EAM.L.EAM_SLASH_ITEM_LABEL or "Item")
                printLine(stringFormat(
                    EAM.L.EAM_SLASH_LIST_LINE or "%s | %s | ID: %d",
                    label,
                    name,
                    numericID
                ))
                count = count + 1
            end
        end
    end
    return count
end

local function printConfiguredList()
    local saved = EAM.Modules and EAM.Modules.SavedVariables
    if not saved or not saved.getAlertList then
        printLine(EAM.L.EAM_SLASH_NOT_INIT or "SavedVariables 尚未初始化。")
        return
    end

    local classToken = saved.getActiveClassToken and saved.getActiveClassToken() or "UNKNOWN"
    printLine(stringFormat(EAM.L.EAM_SLASH_LIST_HEADER or "%s 目前職業監控清單", classToken))
    local count = 0
    count = count + printAlertList(
        EAM.L.EAM_MODULE_PLAYER_AURA or "玩家光環",
        saved.getAlertList("aura", "player"),
        "spellID"
    )
    count = count + printAlertList(
        EAM.L.EAM_MODULE_TARGET_AURA or "目標光環",
        saved.getAlertList("aura", "target"),
        "spellID"
    )
    count = count + printAlertList(
        EAM.L.EAM_MODULE_SPELL_COOLDOWN or "技能冷卻",
        saved.getAlertList("cooldown"),
        "spellID"
    )
    count = count + printAlertList(
        EAM.L.EAM_MODULE_ITEM_COOLDOWN or "物品冷卻",
        saved.getAlertList("item"),
        "itemID"
    )
    count = count + printAlertList(
        EAM.L.EAM_MODULE_GROUND_EFFECT or "地面效果",
        saved.getAlertList("groundEffect"),
        "spellID"
    )
    if count == 0 then
        printLine(EAM.L.EAM_SLASH_LIST_EMPTY or "目前職業沒有監控項目。")
    end
end

local function printCastList(service)
    local count = service.forEachCastSpell(function(spellID)
        printLine(stringFormat(
            EAM.L.EAM_SLASH_CAST_LINE or "%s | Spell ID: %d",
            getSafeSpellName(spellID),
            spellID
        ))
    end)
    if count == 0 then
        printLine(EAM.L.EAM_SLASH_SHOWCAST_EMPTY or "本次登入尚未記錄到玩家施法。")
    end
end

local function toggleShowCast()
    local service = EAM.Services and EAM.Services.LegacyDiscoveryService
    if not service then
        printLine(EAM.L.EAM_SLASH_DISCOVERY_UNAVAILABLE or "經典探索服務尚未載入。")
        return
    end
    local enabled = not service.isCastCaptureEnabled()
    local ok = service.setCastCaptureEnabled(enabled)
    if not ok then
        printLine(EAM.L.EAM_SLASH_OP_FAIL or "操作失敗。")
        return
    end
    printLine(enabled and (EAM.L.EAM_SLASH_SHOWCAST_ENABLED or "已開始記錄玩家成功施放的法術。")
        or (EAM.L.EAM_SLASH_SHOWCAST_DISABLED or "已停止記錄玩家施法。"))
    printCastList(service)
end

local function runLookup(input, exact)
    local query = commandArguments(input)
    if not query or query == "" then
        printLine(EAM.L.EAM_SLASH_LOOKUP_USAGE or "用法：/eam lookup <法術名稱>")
        return
    end
    local service = EAM.Services and EAM.Services.LegacyDiscoveryService
    if not service then
        printLine(EAM.L.EAM_SLASH_DISCOVERY_UNAVAILABLE or "經典探索服務尚未載入。")
        return
    end

    local count = service.lookup(query, exact, function(spellID, name)
        printLine(stringFormat(
            EAM.L.EAM_SLASH_LOOKUP_LINE or "%s | Spell ID: %d",
            name,
            spellID
        ))
    end)
    if count == 0 then
        printLine(EAM.L.EAM_SLASH_LOOKUP_NONE or "目前職業的有限候選中沒有符合項目。")
    end
end

local function printAuraSafetyGuidance()
    printLine(EAM.L.EAM_SLASH_SHOW_UNSUPPORTED
        or "Retail 12.1 不以舊式 UnitAura 掃描完整光環；請將滑鼠移到光環圖示後按 Ctrl+Alt 加入監控。")
end

local function printAutoAddGuidance()
    printLine(EAM.L.EAM_SLASH_AUTOADD_UNSUPPORTED
        or "Retail 12.1 不自動寫入掃描結果；請以 Tooltip 的 Ctrl+Alt 視窗確認後加入。")
end

local function handleUnitPower(input)
    local iterator = nextToken(input)
    iterator()
    local action = iterator()
    local resourceKey = iterator()
    if string.lower(action or "") ~= "background" or not resourceKey then
        printLine(EAM.L.EAM_SLASH_HELP_UNITPOWER
            or "/eam unitpower background <RESOURCE_KEY>")
        return
    end
    resourceKey = string.upper(resourceKey)
    local probe = EAM.Debug and EAM.Debug.PlayerResourceProbe
    if not probe or type(probe.markBackgroundEventMissing) ~= "function" then
        printLine(EAM.L.EAM_SLASH_RESOURCE_SAMPLER_FAILED or "EAM：資源 Probe 尚未啟動。")
        return
    end
    local ok, reason = probe.markBackgroundEventMissing(resourceKey)
    if ok then
        printLine(stringFormat(
            EAM.L.EAM_SLASH_RESOURCE_SAMPLER_MARKED or "EAM：已為背景資源 %s 啟用共用 sampler。",
            resourceKey
        ))
    else
        printLine((EAM.L.EAM_SLASH_RESOURCE_SAMPLER_FAILED or "EAM：無法啟用資源 sampler：") .. tostring(reason))
    end
end

local function handleSlash(input)
    input = input or ""
    local commandIterator = nextToken(input)
    local command = commandIterator() or "opt"
    command = string.lower(command)

    if command == "debug" then
        local nextTokenVal = commandIterator()
        if nextTokenVal and string.lower(nextTokenVal) == "ground" then
            local spellIDToken = commandIterator()
            local spellID = tonumber(spellIDToken)
            if spellID then
                local locale = EAM.API.GetLocale and EAM.API.GetLocale() or "enUS"
                printLine(stringFormat(EAM.L.EAM_SLASH_DEBUG_GROUND_START or "正在除錯無光環地面技能 Tooltip 解析 (當前客戶端語系: %s)...", locale))
                if EAM.Services.GroundEffectService then
                    local duration = EAM.Services.GroundEffectService.scrapeDuration(spellID)
                    if duration then
                        printLine(stringFormat(EAM.L.EAM_SLASH_DEBUG_GROUND_SUCCESS or "法術 [%d] 成功解析持續時間: |cff00ff00%s 秒|r", spellID, tostring(duration)))
                    else
                        printLine(stringFormat(EAM.L.EAM_SLASH_DEBUG_GROUND_FAIL or "法術 [%d] Tooltip 解析失敗，將使用預設時間", spellID))
                    end
                else
                    printLine(EAM.L.EAM_SLASH_GROUND_NOT_LOADED or "GroundEffectService 未載入！")
                end
            else
                printLine(EAM.L.EAM_SLASH_SPECIFY_SPELLID or "請指定正確的法術 ID: /eam debug ground <spellID>")
            end
        elseif EAM.Debug.PromptExport then
            EAM.Debug.PromptExport.openWindow()
        end
    elseif (command == "doctor" or command == "validate") and EAM.Debug.RuntimeProbe then
        EAM.Debug.RuntimeProbe.printReport()
    elseif command == "test" and EAM.Debug.FlowTestPanel then
        local suite = commandIterator()
        if suite then
            suite = string.lower(suite)
            if (suite == "live" or suite == "manual") and EAM.Debug.LiveTestPanel then
                EAM.Debug.LiveTestPanel.open(true)
            else
                EAM.Debug.FlowTestPanel.open(true)
                EAM.Debug.FlowTestPanel.runSuite(suite)
            end
        else
            EAM.Debug.FlowTestPanel.open()
        end
    elseif command == "profile" then
        local action = commandIterator()
        local panel = EAM.UI and EAM.UI.ProfileCodecPanel
        if not panel then
            printLine(EAM.L.EAM_PROFILE_CODEC_STATUS_UNAVAILABLE or "Profile codec 尚未載入。")
        elseif action and string.lower(action) == "export" then
            panel.openExport()
        else
            panel.open()
        end
elseif command == "unitpower" then
        handleUnitPower(input)
    elseif command == "export" and EAM.Debug.PromptExport then
        EAM.Debug.PromptExport.openWindow()
    elseif command == "add" or command == "remove" then
        mutateAlert(command, input)
    elseif command == "list" then
        printConfiguredList()
    elseif command == "lookup" or command == "l" then
        runLookup(input, false)
    elseif command == "lookupfull" or command == "lf" then
        runLookup(input, true)
    elseif command == "showcast" or command == "showc" then
        toggleShowCast()
    elseif command == "show" or command == "shows" or command == "showtarget" or command == "showt" then
        printAuraSafetyGuidance()
    elseif command == "showautoadd" or command == "showa"
        or command == "showenvadd" or command == "showe"
    then
        printAutoAddGuidance()
    elseif command == "help" then
        printHelp()
    elseif (command == "opt" or command == "option" or command == "options") and EAM.UI.Options then
        EAM.UI.Options.open()
    elseif command == "" and EAM.UI.Options then
        EAM.UI.Options.open()
    else
        printHelp()
    end
end

Slash.handleSlash = handleSlash

SLASH_EAM1 = "/eam"
SLASH_EAM2 = "/eventalertmod"
SlashCmdList.EAM = handleSlash