--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Data/Defaults
檔案: Data\Defaults.lua

理念:
- 集中新 schema 的靜態預設資料，讓 SavedVariables migration 有固定基準。
- Defaults 是 template，不是 runtime state。

責任:
- 保存 alerts/layout 等新 profile 預設模板。

資料所有權:
- 擁有靜態 default templates。

可變狀態:
- 載入後不應改動；日後可 freeze 靜態模板。

邊界:
- 不保存角色 session 狀態。
- 不保存高頻 alert facts。

效能注意:
- default template 應小而穩定；深拷貝只在初始化/migration 執行。

Retail API 注意:
- schema 變更需同步 Core/SavedVariables 與 Docs/03_STATE_SCHEMA.md。

]]
local _, EAM = ...

EAM.Data.Defaults = {
    alerts = {},
    layout = {},
}

