--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/SpellInfoService
檔案: Services\SpellInfoService.lua

理念:
- 集中 spell name/icon/link lookup，讓其他服務不重複查詢。
- 查詢結果只作為 safe facts cache，不承擔 alert 判斷。

責任:
- 提供 spellID lookup 與快取入口。

資料所有權:
- 擁有 SpellInfoService.cache。

可變狀態:
- 只 mutate lookup cache；不可寫 UI 或 SavedVariables。

邊界:
- 不做 aura/cooldown 狀態判斷。
- 不在戰鬥中跑大量 spell scan。

效能注意:
- 快取結果，避免重複 C_Spell.GetSpellInfo 查詢。

Retail API 注意:
- 使用 C_Spell.GetSpellInfo；不得回退到 GetSpellInfo 作為新架構核心。
- 回傳值逐欄位安全讀取；unsafe 欄位不進 safe facts cache。

]]
local _, EAM = ...

local Util = EAM.Util

local SpellInfoService = {
    cache = {},
}

EAM.Services.SpellInfoService = SpellInfoService

function SpellInfoService.initialize()
end

function SpellInfoService.getSpellInfo(spellID)
    if not spellID then
        return nil
    end

    local cached = SpellInfoService.cache[spellID]
    if cached and cached.factsSafe and cached.name then
        return cached
    end

    local api = EAM.API
    local record = cached
    if not record then
        record = {
            spellID = spellID,
            warnings = {},
            factsSafe = false,
        }
    else
        -- 複用先前失敗的快取 table 進行資料重寫，消滅 runtime GC 分配
        record.factsSafe = false
        wipe(record.warnings)
    end

    if api.C_Spell and api.C_Spell.GetSpellInfo then
        local info = api.C_Spell.GetSpellInfo(spellID)
        if type(info) == "table" and Util.canAccessTable(info) then
            local name, nameSafe = Util.readSafeField(info, "name", record.warnings, "spellInfo")
            local icon, iconSafe = Util.readSafeField(info, "iconID", record.warnings, "spellInfo")
            if icon == nil then
                icon, iconSafe = Util.readSafeField(info, "icon", record.warnings, "spellInfo")
            end
            record.name = name
            record.icon = icon
            record.factsSafe = nameSafe and iconSafe and (name ~= nil)
        else
            Util.appendBoundaryWarning(record.warnings, "spellInfo", "unavailable")
        end
    end

    -- 多層防禦性降級解析：當未完成快取或 GetSpellInfo 尚未載入時，直接透過專用 API 取得法術名稱與圖示
    if not record.name and api.C_Spell and type(api.C_Spell.GetSpellName) == "function" then
        local ok, sName = pcall(api.C_Spell.GetSpellName, spellID)
        if ok and Util.isSafeString(sName) and sName ~= "" then
            record.name = sName
        end
    end
    if not record.icon and api.C_Spell and type(api.C_Spell.GetSpellTexture) == "function" then
        local ok, sTex = pcall(api.C_Spell.GetSpellTexture, spellID)
        if ok and Util.isSafePositiveNumber(sTex) then
            record.icon = sTex
        end
    end
    if (not record.name or not record.icon) and api.C_Spell and type(api.C_Spell.GetBaseSpell) == "function" then
        local okBase, baseID = pcall(api.C_Spell.GetBaseSpell, spellID)
        if okBase and Util.isSafePositiveNumber(baseID) and baseID ~= spellID then
            if not record.name and type(api.C_Spell.GetSpellName) == "function" then
                local ok, bName = pcall(api.C_Spell.GetSpellName, baseID)
                if ok and Util.isSafeString(bName) and bName ~= "" then
                    record.name = bName
                end
            end
            if not record.icon and type(api.C_Spell.GetSpellTexture) == "function" then
                local ok, bTex = pcall(api.C_Spell.GetSpellTexture, baseID)
                if ok and Util.isSafePositiveNumber(bTex) then
                    record.icon = bTex
                end
            end
        end
    end
    if not record.name and EAM.Data and EAM.Data.SpellHeuristics and EAM.Data.SpellHeuristics[spellID] then
        local h = EAM.Data.SpellHeuristics[spellID]
        if h and h.name and h.name ~= "" then
            record.name = h.name
        end
    end
    if record.name and record.icon then
        record.factsSafe = true
    end

    SpellInfoService.cache[spellID] = record
    return record
end

function SpellInfoService.getOverrideSpell(spellID)
    if not Util.isSafePositiveNumber(spellID) then
        return spellID
    end
    local api = EAM.API
    if api.C_Spell and api.C_Spell.GetOverrideSpell then
        local ok, overrideID = pcall(api.C_Spell.GetOverrideSpell, spellID)
        if ok and Util.isSafePositiveNumber(overrideID) and overrideID > 0 then
            return overrideID
        end
    end
    return spellID
end
