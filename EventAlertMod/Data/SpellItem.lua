--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Data/SpellItem
檔案: Data\SpellItem.lua

理念:
- 保存 spell/item 關聯靜態資料或 migration 暫存資料。
- item cooldown runtime mapping 由 ItemCooldownService 控制。

責任:
- 日後保存必要且小型的 item/spell static records。

資料所有權:
- 擁有靜態 item/spell reference data。

可變狀態:
- 載入後不應改動；動態 cache 不放這裡。

邊界:
- 不掃描大型 item range。
- 不在資料檔查 C_Item。

效能注意:
- 避免建立巨大 table；必要 mapping 應 opt-in incremental。

Retail API 注意:
- 只保留 Retail 有效資料，Classic item/spell 分支移出正式資料。

]]
local _, EAM = ...

EAM.Data.SpellItem = {}

