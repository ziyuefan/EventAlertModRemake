--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Debug/EngineProfiler
檔案: Debug\EngineProfiler.lua

理念:
- 集中暴雪原生 C++ AddOn Profiler (C_AddOnProfiler) 遙測指標讀取與格式化。
- 監控 CPU 耗時、峰值、首領戰均值與刺波 (spike) 幀數，輔助除錯與效能調優。

責任:
- 查詢 C_AddOnProfiler 原生引擎計量 (RecentAverageTime, PeakTime, CountTimeOver1Ms, EncounterAverageTime 等)。
- 提供安全能力檢定 (Capability Gate)，API 不可用或被客戶端停用時安全回退。
- 提供格式化摘要字串供 /eam metrics 與除錯面板使用。

資料所有權:
- 唯讀讀取暴雪引擎層計量。
- 不持久化儲存業務狀態。

邊界:
- 不修改 CVar 或 profiler 啟用狀態。
- 不執行任何遊戲內部保護動作。
]]

local _, EAM = ...

EAM.Debug = EAM.Debug or {}
EAM.Modules = EAM.Modules or {}

local EngineProfiler = {}
EAM.Debug.EngineProfiler = EngineProfiler
EAM.Modules.EngineProfiler = EngineProfiler

local ADDON_NAME = "EventAlertMod"

function EngineProfiler.isEnabled()
    local profiler = rawget(_G, "C_AddOnProfiler")
    if not profiler or type(profiler.IsEnabled) ~= "function" then
        return false, "unavailable"
    end
    local ok, enabled = pcall(profiler.IsEnabled)
    if ok and enabled then
        return true, "enabled"
    end
    return false, ok and "disabled" or "error"
end

function EngineProfiler.getMetrics(addonName)
    local targetAddon = addonName or ADDON_NAME
    local profiler = rawget(_G, "C_AddOnProfiler")
    if not profiler or type(profiler.IsEnabled) ~= "function" then
        return {
            supported = false,
            enabled = false,
            addon = targetAddon,
            reason = "C_AddOnProfiler unavailable",
        }
    end

    local ok, enabled = pcall(profiler.IsEnabled)
    if not ok or not enabled then
        return {
            supported = true,
            enabled = false,
            addon = targetAddon,
            reason = "Profiler disabled in client",
        }
    end

    local metricsEnum = (rawget(_G, "Enum") and rawget(_G, "Enum").AddOnProfilerMetric)
        or (EAM.API and EAM.API.AddOnProfilerMetric)
        or rawget(_G, "AddOnProfilerMetric")

    local getMetric = profiler.GetAddOnMetric
    if not metricsEnum or type(getMetric) ~= "function" then
        return {
            supported = true,
            enabled = true,
            partial = true,
            addon = targetAddon,
            reason = "AddOnProfilerMetric enum or GetAddOnMetric function unavailable",
        }
    end

    local safeQuery = function(metricId)
        if metricId == nil then return 0 end
        local qOk, val = pcall(getMetric, targetAddon, metricId)
        return (qOk and type(val) == "number") and val or 0
    end

    return {
        supported = true,
        enabled = true,
        addon = targetAddon,
        recentMs = safeQuery(metricsEnum.RecentAverageTime),
        peakMs = safeQuery(metricsEnum.PeakTime),
        countOver1Ms = safeQuery(metricsEnum.CountTimeOver1Ms),
        encounterMs = safeQuery(metricsEnum.EncounterAverageTime),
        sessionMs = safeQuery(metricsEnum.SessionAverageTime),
        lastMs = safeQuery(metricsEnum.LastTime),
        over1Ms = safeQuery(metricsEnum.CountTimeOver1Ms),
        over5Ms = safeQuery(metricsEnum.CountTimeOver5Ms),
        over10Ms = safeQuery(metricsEnum.CountTimeOver10Ms),
        over50Ms = safeQuery(metricsEnum.CountTimeOver50Ms),
    }
end

function EngineProfiler.formatSummary(metrics)
    metrics = metrics or EngineProfiler.getMetrics()
    if not metrics.supported then
        return "C_AddOnProfiler 不支援"
    end
    if not metrics.enabled then
        return "C_AddOnProfiler 已停用 (需於客戶端啟用)"
    end
    return string.format(
        "近期均值: %.3f ms | 歷史峰值: %.3f ms | 首領戰均值: %.3f ms | 刺波(>1ms/5ms): %d / %d 幀",
        metrics.recentMs or 0,
        metrics.peakMs or 0,
        metrics.encounterMs or 0,
        metrics.over1Ms or metrics.countOver1Ms or 0,
        metrics.over5Ms or 0
    )
end
