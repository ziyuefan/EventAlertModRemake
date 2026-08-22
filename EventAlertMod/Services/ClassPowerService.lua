--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Services/ClassPowerService
檔案: Services\ClassPowerService.lua

責任:
- 保留既有 ClassPowerService 名稱，轉接至多資源 PlayerResourceService。
- 讓 ModuleController、Main、Probe 與舊呼叫點無須同一版全面改名。

邊界:
- 本 facade 不讀取 UnitPower、不保存 activePowerType，也不建立第二套事件處理。
]]
local _, EAM = ...

local service = EAM.Services.PlayerResourceService
if not service then
    error("PlayerResourceService must load before ClassPowerService")
end

EAM.Services.ClassPowerService = service