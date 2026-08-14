--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Core/Env
檔案: Core\Env.lua

理念:
- 作為 Retail rewrite 的 namespace 與 API alias 錨點，讓後續模組只依賴 EAM 命名空間。
- 將常用 WoW API 集中到 EAM.API，降低全域查找與錯誤覆寫風險。

責任:
- 初始化 addon 名稱、版本、Retail-only 旗標與各模組容器。
- 建立 EAM.API 靜態 API alias table，供 Core/Services/UI/Debug 使用。

資料所有權:
- 擁有 EAM namespace 的初始結構。
- 不擁有 SavedVariables、runtime cache 或 UI frame。

可變狀態:
- 只在 addon 載入初期初始化 EAM 欄位。
- 載入後不應再修改 EAM.API 內容；freeze 由 Core/Util 完成。

邊界:
- 不讀取 aura/cooldown/item 資料。
- 不建立事件 frame、UI frame 或 scheduler。
- 不做 Classic/MOP 相容判斷。

效能注意:
- API alias table 是熱路徑依賴，應保持穩定。
- 新增 API alias 時避免加入會在載入時觸發重工作或配置的值。

Retail API 注意:
- 僅錨定 Retail 12.x/Midnight-era API；任何新增 C_* API 需先查證。
- 不得加入 Classic-only API fallback。

]]
local addonName, EAM = ...

EAM.name = addonName
EAM.version = "Retail_12.1_Native_Aura"
EAM.isRetailOnly = true

EAM.Modules = EAM.Modules or {}
EAM.Services = EAM.Services or {}
EAM.UI = EAM.UI or {}
EAM.Debug = EAM.Debug or {}
EAM.Data = EAM.Data or {}

EAM.API = {
    CreateFrame = CreateFrame,
    GetTime = GetTime,
    InCombatLockdown = InCombatLockdown,
    UnitGUID = UnitGUID,
    UnitExists = UnitExists,
    UnitIsUnit = UnitIsUnit,
    UnitClass = UnitClass,
    UnitPower = UnitPower,
    UnitPowerMax = UnitPowerMax,
    UnitPowerPercent = UnitPowerPercent,
    UnitPowerType = UnitPowerType,
    UnitHasPowerType = UnitHasPowerType,
    GetTotemInfo = GetTotemInfo,
    GetTotemDuration = GetTotemDuration,
    GetFramerate = GetFramerate,
    GetBuildInfo = GetBuildInfo,
    GetServerTime = GetServerTime,
    GetLocale = GetLocale,
    IsTestBuild = IsTestBuild,
    IsBetaBuild = IsBetaBuild,
    IsPublicTestClient = IsPublicTestClient,
    WOW_PROJECT_ID = WOW_PROJECT_ID,
    GetActionInfo = GetActionInfo,
    GetMacroIndexByName = GetMacroIndexByName,
    GetMacroSpell = GetMacroSpell,
    GetMacroItem = GetMacroItem,
    GetCursorPosition = GetCursorPosition,
    GetCurrentKeyBoardFocus = GetCurrentKeyBoardFocus,
    IsControlKeyDown = IsControlKeyDown,
    IsAltKeyDown = IsAltKeyDown,
    IsShiftKeyDown = IsShiftKeyDown,
    IsMetaKeyDown = IsMetaKeyDown,
    debugprofilestop = debugprofilestop,
    GetEventCPUUsage = GetEventCPUUsage,
    GetFunctionCPUUsage = GetFunctionCPUUsage,
    GetScriptCPUUsage = GetScriptCPUUsage,
    GameTooltip = GameTooltip,
    GameTooltip_AddMoneyLine = GameTooltip_AddMoneyLine,
    SetTooltipMoney = SetTooltipMoney,
    TooltipDataProcessor = TooltipDataProcessor,
    TooltipDataType = Enum and Enum.TooltipDataType,
    TooltipDataLineType = Enum and Enum.TooltipDataLineType,
    SecondsFormatterAbbreviation = Enum and Enum.SecondsFormatterAbbreviation,
    SecondsFormatterIntervalWhitespace = Enum and Enum.SecondsFormatterIntervalWhitespace,
    canaccesstable = canaccesstable or function(t) return type(t) == "table" end,
    canaccessvalue = canaccessvalue or function() return true end,
    issecretvalue = issecretvalue or function() return false end,
    issecrettable = issecrettable or function() return false end,
    hasanysecretvalues = hasanysecretvalues or function() return false end,
    C_ActionBar = C_ActionBar,
    C_Spell = C_Spell,
    C_SpellBook = C_SpellBook,
    SpellBookSpellBank = Enum and Enum.SpellBookSpellBank,
    C_Item = C_Item,
    C_UnitAuras = C_UnitAuras,
    C_TooltipInfo = C_TooltipInfo,
    C_DurationUtil = C_DurationUtil,
    C_StringUtil = C_StringUtil,
    C_UIFileAsset = C_UIFileAsset,
    C_AddOns = C_AddOns,
    C_CVar = C_CVar,
    C_Secrets = C_Secrets,
}

EAM.DebugLog = {}
EAM.DebugLogCount = 0

function EAM.addDebugLog(moduleName, action, msg)
    local count = EAM.DebugLogCount + 1
    if count > 40 then
        table.remove(EAM.DebugLog, 1)
        count = 40
    end
    local timeStr = ""
    if GetTime then
        timeStr = string.format("[%.2f] ", GetTime())
    end
    EAM.DebugLog[count] = timeStr .. "[" .. tostring(moduleName) .. "] " .. tostring(action) .. ": " .. tostring(msg)
    EAM.DebugLogCount = count
end

_G["EAM"] = EAM
