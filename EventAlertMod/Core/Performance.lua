--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Core/Performance
檔案: Core\Performance.lua

理念:
- 將效能節流與 shared pool 集中，避免各服務自行判斷戰鬥與 FPS。
- 所有重工作先經過 canDoHeavyWork 之類決策點。

責任:
- 提供 shared table pool、combat-aware heavy work gate、日後 profiling counter。

資料所有權:
- 擁有 Performance.tablePool 與 profiling/session counters。

可變狀態:
- 只 mutate performance-local pools/counters。

邊界:
- 不做業務資料查詢。
- 不建立 UI 或更改 SavedVariables。

效能注意:
- pool object 不得 freeze；release 時必須 wipe。
- 低 FPS 與 combat lockdown 策略後續在此集中。

Retail API 注意:
- InCombatLockdown 是保守 gate；不能用來繞過 protected data。

]]
local _, EAM = ...

local Performance = {
    tablePool = { count = 0 },
    minFPS = 30,
}

EAM.Modules.Performance = Performance

function Performance.acquireTable()
    return EAM.Util.acquireTable(Performance.tablePool)
end

function Performance.releaseTable(value)
    EAM.Util.releaseTable(Performance.tablePool, value)
end

function Performance.canDoHeavyWork()
    local api = EAM.API
    if api.InCombatLockdown and api.InCombatLockdown() then
        return false
    end
    if api.GetFramerate then
        local fps = api.GetFramerate()
        if fps and fps > 0 and fps < Performance.minFPS then
            return false
        end
    end
    return true
end
