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

    SpellInfoService.cache[spellID] = record
    return record
end
