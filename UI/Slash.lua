--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: UI/Slash
檔案: UI\Slash.lua

理念:
- /eam 是使用者低成本入口，負責協調模組而非承擔業務邏輯。
- 指令語意保留舊 EAM 簡潔風格。

責任:
- 註冊 slash command、解析文字、呼叫 Options/Debug/SavedVariables/service API。

資料所有權:
- 擁有 slash command handler。

可變狀態:
- 可觸發其他模組公開 API；不可直接改 service/private tables。

邊界:
- 不做 combat automation。
- 不讀 secret/protected data。

效能注意:
- Slash 非 hot path；輸出字串只在使用者呼叫時建立。

Retail API 注意:
- SlashCmdList 是 WoW 標準入口；需實機確認 /eam 指令註冊。

]]
local _, EAM = ...

local Slash = {}
EAM.UI.Slash = Slash

local mathFloor = math.floor

local function printLine(text)
    print("|cff00ff96EAM|r " .. text)
end

local function nextToken(input)
    return string.gmatch(input or "", "%S+")
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
    printLine(EAM.L.EAM_SLASH_HELP_DOCTOR or "/eam doctor - 顯示 Retail/PTR API 邊界診斷")
    printLine(EAM.L.EAM_SLASH_HELP_VALIDATE or "/eam validate - 同 /eam doctor")
    printLine(EAM.L.EAM_SLASH_HELP_DEBUG or "/eam debug - 顯示除錯摘要")
    printLine(EAM.L.EAM_SLASH_HELP_EXPORT or "/eam export - 輸出精簡 AI debug 狀態")
    printLine(EAM.L.EAM_SLASH_HELP_TEST or "/eam test [quick|core|boundary|all] - 開啟或執行流程驗證")
    printLine(EAM.L.EAM_SLASH_HELP_ADD or "/eam add <spellID> - 新增 player aura")
    printLine(EAM.L.EAM_SLASH_HELP_ADD_TARGET or "/eam add target <spellID> - 新增 target aura")
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
                printLine(string.format(EAM.L.EAM_SLASH_DEBUG_GROUND_START or "正在除錯無光環地面技能 Tooltip 解析 (當前客戶端語系: %s)...", locale))
                if EAM.Services.GroundEffectService then
                    local dur = EAM.Services.GroundEffectService.scrapeDuration(spellID)
                    if dur then
                        printLine(string.format(EAM.L.EAM_SLASH_DEBUG_GROUND_SUCCESS or "法術 [%d] 成功解析持續時間: |cff00ff00%s 秒|r", spellID, tostring(dur)))
                    else
                        printLine(string.format(EAM.L.EAM_SLASH_DEBUG_GROUND_FAIL or "法術 [%d] Tooltip 解析失敗，將使用預設時間", spellID))
                    end
                else
                    printLine(EAM.L.EAM_SLASH_GROUND_NOT_LOADED or "GroundEffectService 未加載！")
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
            EAM.Debug.FlowTestPanel.open(true)
            EAM.Debug.FlowTestPanel.runSuite(suite)
        else
            EAM.Debug.FlowTestPanel.open()
        end
    elseif command == "export" and EAM.Debug.PromptExport then
        EAM.Debug.PromptExport.openWindow()
    elseif command == "add" or command == "remove" then
        mutateAlert(command, input)
    elseif command == "help" then
        printHelp()
    elseif command == "opt" and EAM.UI.Options then
        EAM.UI.Options.open()
    elseif EAM.UI.Options then
        EAM.UI.Options.open()
    end
end

SLASH_EAM1 = "/eam"
SlashCmdList.EAM = handleSlash
