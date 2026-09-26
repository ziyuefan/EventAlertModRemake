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

-- Hot Path 頻率追蹤器 (Profile-Guided Optimization Counters)
local hotPaths = {}
local cumulative = {}
local totalCalls = 0
local sessionStartTime = 0

if GetTime then
    local ok, t = pcall(GetTime)
    if ok and type(t) == "number" then
        sessionStartTime = t
    end
end

local function recordHotPath(pathKey, amount)
    if not pathKey then return end
    local n = amount or 1
    hotPaths[pathKey] = (hotPaths[pathKey] or 0) + n
    totalCalls = totalCalls + n
end

Performance.recordHotPath = recordHotPath
EAM.recordHotPath = recordHotPath

function Performance.getHotPaths()
    return hotPaths
end

function Performance.getCumulative()
    return cumulative
end

function Performance.getTotalCalls()
    return totalCalls
end

function Performance.getSessionDuration()
    local now = 0
    if GetTime then
        local ok, t = pcall(GetTime)
        if ok and type(t) == "number" then
            now = t
        end
    end
    if sessionStartTime > 0 and now >= sessionStartTime then
        return now - sessionStartTime
    end
    return 0
end

function Performance.loadFromDB(db)
    local target = db or EAM.db or _G["EAM_DB"]
    if type(target) ~= "table" then return end
    local metrics = target.hotPathMetrics
    if type(metrics) == "table" and type(metrics.cumulative) == "table" then
        for k, v in pairs(metrics.cumulative) do
            if type(v) == "number" then
                cumulative[k] = v
            end
        end
    end
end

function Performance.saveToDB(db)
    local target = db or EAM.db or _G["EAM_DB"]
    if type(target) ~= "table" then return end
    target.hotPathMetrics = target.hotPathMetrics or {}
    local m = target.hotPathMetrics
    m.cumulative = m.cumulative or {}

    for k, v in pairs(hotPaths) do
        m.cumulative[k] = (m.cumulative[k] or 0) + v
        cumulative[k] = m.cumulative[k]
    end

    local lastSession = {}
    for k, v in pairs(hotPaths) do
        lastSession[k] = v
    end
    m.lastSession = lastSession

    local duration = Performance.getSessionDuration()
    m.totalRuntimeSeconds = (m.totalRuntimeSeconds or 0) + math.floor(duration)
    m.totalSessionCalls = totalCalls
    if date then
        local ok, dStr = pcall(date, "%Y-%m-%d %H:%M:%S")
        if ok and type(dStr) == "string" then
            m.lastSavedAt = dStr
        end
    end
end

function Performance.resetMetrics(scope)
    if scope == "session" or not scope or scope == "all" then
        for k in pairs(hotPaths) do
            hotPaths[k] = nil
        end
        totalCalls = 0
        if GetTime then
            local ok, t = pcall(GetTime)
            if ok and type(t) == "number" then
                sessionStartTime = t
            end
        end
    end
    if scope == "cumulative" or scope == "all" then
        for k in pairs(cumulative) do
            cumulative[k] = nil
        end
        local target = EAM.db or _G["EAM_DB"]
        if type(target) == "table" and type(target.hotPathMetrics) == "table" then
            target.hotPathMetrics.cumulative = {}
            target.hotPathMetrics.totalRuntimeSeconds = 0
            target.hotPathMetrics.lastSession = {}
        end
    end
end

function Performance.getEngineProfilerMetrics()
    local api = EAM.API or {}
    local profiler = api.C_AddOnProfiler or _G.C_AddOnProfiler
    if not profiler or type(profiler.IsEnabled) ~= "function" then
        return {
            supported = false,
            enabled = false,
            reason = "C_AddOnProfiler 不可用",
        }
    end

    local ok, enabled = pcall(profiler.IsEnabled)
    if not ok or not enabled then
        return {
            supported = true,
            enabled = false,
            reason = "Profiler disabled in client",
        }
    end

    local metricsEnum = api.AddOnProfilerMetric or (Enum and Enum.AddOnProfilerMetric)
    local getMetric = profiler.GetAddOnMetric
    if not metricsEnum or type(getMetric) ~= "function" then
        return {
            supported = true,
            enabled = true,
            partial = true,
            reason = "AddOnProfilerMetric or GetAddOnMetric unavailable",
        }
    end

    local addonName = "EventAlertMod"
    local safeQuery = function(metricId)
        if not metricId then return 0 end
        local qOk, val = pcall(getMetric, addonName, metricId)
        return (qOk and type(val) == "number") and val or 0
    end

    return {
        supported = true,
        enabled = true,
        recentMs = safeQuery(metricsEnum.RecentAverageTime),
        sessionMs = safeQuery(metricsEnum.SessionAverageTime),
        encounterMs = safeQuery(metricsEnum.EncounterAverageTime),
        peakMs = safeQuery(metricsEnum.PeakTime),
        lastMs = safeQuery(metricsEnum.LastTime),
        over1Ms = safeQuery(metricsEnum.CountTimeOver1Ms),
        over5Ms = safeQuery(metricsEnum.CountTimeOver5Ms),
        over10Ms = safeQuery(metricsEnum.CountTimeOver10Ms),
        over50Ms = safeQuery(metricsEnum.CountTimeOver50Ms),
    }
end

function Performance.getSnapshot()
    local duration = Performance.getSessionDuration()
    local safeDur = duration > 0.001 and duration or 0.001
    local cps = totalCalls / safeDur

    local sorted = {}
    for k, count in pairs(hotPaths) do
        sorted[#sorted + 1] = {
            key = k,
            count = count,
            cps = count / safeDur,
            cumulativeCount = (cumulative[k] or 0) + count,
        }
    end
    table.sort(sorted, function(a, b)
        return a.count > b.count
    end)

    return {
        sessionDuration = duration,
        totalSessionCalls = totalCalls,
        callsPerSecond = cps,
        hotPaths = hotPaths,
        cumulative = cumulative,
        topPaths = sorted,
        engineProfiler = Performance.getEngineProfilerMetrics(),
    }
end

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
