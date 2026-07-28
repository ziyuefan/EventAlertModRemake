--[[ EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
Module: Tests/FlowValidationHarness
檔案: Tests\FlowValidationHarness.lua

理念:
- 在 Lua 5.1 離線環境直接載入正式模組，執行與實機相同的流程案例。
- 使用最小 WoW API mock 驗證 EventRouter、Scheduler、SavedVariables 與報告閉環。

責任:
- 建立 deterministic 時間與 Frame mock。
- 執行指定 suite、推進 Scheduler、輸出 JSON 並以 exit code 表示結果。

邊界:
- 本檔不列入 EventAlertMod.toc，不得宣稱 Mock 等於 Retail/PTR 實機驗證。
- 不連網、不讀 WTF、不載入 LegacyReference。
]]
local suite = "all"
local outputPath = nil

local index = 1
while index <= #arg do
    if arg[index] == "--suite" then
        suite = arg[index + 1] or suite
        index = index + 2
    elseif arg[index] == "--output" then
        outputPath = arg[index + 1]
        index = index + 2
    else
        index = index + 1
    end
end

if not outputPath then
    io.stderr:write("Missing --output <path>\n")
    os.exit(2)
end

local currentTime = 100
local createdFrames = {}

local function noOperation()
end

local frameMethods = {}

function frameMethods:SetScript(name, callback)
    self.scripts[name] = callback
end

function frameMethods:GetScript(name)
    return self.scripts[name]
end

function frameMethods:RegisterEvent(event)
    self.events[event] = true
end

function frameMethods:UnregisterEvent(event)
    self.events[event] = nil
end

function frameMethods:Hide()
    self.shown = false
end

function frameMethods:Show()
    self.shown = true
end

function frameMethods:IsShown()
    return self.shown == true
end

function frameMethods:CreateFontString()
    return {
        ClearText = noOperation,
    }
end

local function createFrame()
    local frame = {
        scripts = {},
        events = {},
        shown = false,
    }
    setmetatable(frame, {
        __index = function(_, key)
            return frameMethods[key] or noOperation
        end,
    })
    createdFrames[#createdFrames + 1] = frame
    return frame
end

CreateFrame = createFrame
GetTime = function()
    return currentTime
end
InCombatLockdown = function()
    return false
end
GetFramerate = function()
    return 120
end
GetBuildInfo = function()
    return "12.0.7", "mock-build", "2026-06-21", 120007
end
GetLocale = function()
    return "enUS"
end
UnitClass = function()
    return "Mage", "MAGE", 8
end
UnitGUID = function()
    return "Player-Mock"
end
UnitExists = function()
    return true
end
UnitIsUnit = function(left, right)
    return left == right
end
UnitPower = function()
    return 0
end
debugprofilestop = function()
    return currentTime * 1000
end
canaccesstable = function(value)
    return type(value) == "table"
end
canaccessvalue = function()
    return true
end
issecretvalue = function()
    return false
end
issecrettable = function()
    return false
end
hasanysecretvalues = function()
    return false
end
wipe = function(value)
    for key in pairs(value) do
        value[key] = nil
    end
    return value
end

table.create = table.create or function()
    return {}
end
table.freeze = table.freeze or function(value)
    return value
end
table.isfrozen = table.isfrozen or function()
    return false
end

Enum = {
    PowerType = {},
}

C_Spell = {
    GetSpellCooldown = noOperation,
    GetSpellCharges = noOperation,
    GetSpellInfo = noOperation,
}
C_Item = {
    GetItemCooldown = noOperation,
}
C_UnitAuras = {
    GetAuraDataByIndex = noOperation,
    GetAuraDataByAuraInstanceID = noOperation,
}
C_TooltipInfo = {}
C_DurationUtil = {}
C_UIFileAsset = {}
C_AddOns = {}
C_Secrets = {}
UIParent = createFrame()
UISpecialFrames = {}

local flowMock = nil
if suite == "aura121" or suite == "boundary" or suite == "all" then
    flowMock = dofile("Tests/Mocks/WoW121AuraMock.lua")
    flowMock.install(120100)
end

local EAM = {
    FlowTestEnvironment = "offline-mock",
    FlowTestMock = flowMock,
    FlowTestAdvanceTime = function(delta)
        if type(delta) == "number" then
            currentTime = currentTime + delta
        end
        return currentTime
    end,
}

local function loadModule(path)
    local chunk, errorMessage = loadfile(path)
    if not chunk then
        error(errorMessage)
    end
    return chunk("EventAlertMod", EAM)
end

loadModule("Core/Env.lua")
EAM.FlowTestEnvironment = "offline-mock"
loadModule("Core/Util.lua")
loadModule("Core/Constants.lua")
loadModule("Core/EventRouter.lua")
loadModule("Core/Scheduler.lua")
loadModule("Core/SavedVariables.lua")
loadModule("Locale/Common.lua")
loadModule("Locale/enUS.lua")
EAM.Modules.SavedVariables.initialize()
EAM.Modules.Main = {
    initialized = true,
}
loadModule("UI/TooltipMonitorMenu.lua")
loadModule("Services/AuraCapabilityService.lua")
loadModule("Managers/AuraRuleCompiler.lua")
loadModule("UI/NativeAuraRenderer.lua")
loadModule("Services/AuraSoundService.lua")
loadModule("Services/AuraService.lua")
loadModule("Services/AuraContainerService.lua")
loadModule("Services/TooltipMonitorService.lua")
loadModule("UI/Options.lua")
if flowMock then
    local notifyConfigChanged = EAM.UI.Options.notifyConfigChanged
    EAM.UI.Options.notifyConfigChanged = function(...)
        flowMock.recordConfigNotification()
        return notifyConfigChanged(...)
    end
end
EAM.UI.TooltipMonitorMenu.initialize()
EAM.Services.AuraCapabilityService.initialize()
EAM.Services.AuraService.initialize()
EAM.Services.AuraContainerService.initialize()
EAM.Services.TooltipMonitorService.initialize()
loadModule("Debug/RuntimeProbe.lua")
loadModule("Debug/FlowTestRunner.lua")

local completedReport = nil
local completedJSON = nil
local started, reason = EAM.Debug.FlowTestRunner.runSuite(suite, function(report, reportJSON)
    completedReport = report
    completedJSON = reportJSON
end)

if not started then
    io.stderr:write("Flow suite did not start: " .. tostring(reason) .. "\n")
    os.exit(3)
end

local scheduler = EAM.Modules.Scheduler
local iterations = 0
while scheduler.count > 0 and iterations < 20 do
    iterations = iterations + 1
    currentTime = currentTime + 0.05
    local onUpdate = scheduler.frame and scheduler.frame:GetScript("OnUpdate")
    if onUpdate then
        onUpdate()
    else
        break
    end
end

if not completedReport or not completedJSON then
    io.stderr:write("Flow suite did not complete\n")
    os.exit(4)
end

local output, openError = io.open(outputPath, "wb")
if not output then
    io.stderr:write("Cannot write report: " .. tostring(openError) .. "\n")
    os.exit(5)
end
output:write(completedJSON)
output:write("\n")
output:close()

local summary = completedReport.summary or {}
io.write(string.format(
    "FLOW_VALIDATION suite=%s total=%d passed=%d failed=%d skipped=%d pending=%d output=%s\n",
    tostring(suite),
    summary.total or 0,
    summary.passed or 0,
    summary.failed or 0,
    summary.skipped or 0,
    summary.pending or 0,
    outputPath
))

if (summary.failed or 0) > 0 or (summary.pending or 0) > 0 then
    os.exit(1)
end
