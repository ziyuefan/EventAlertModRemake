<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: Tools\Run-FlowValidation.ps1

理念:
- 提供可重複、可阻擋發布的離線流程驗證入口。
- 直接執行 Tests/FlowValidationHarness.lua，產生 JSON 與 Markdown 證據。

邊界:
- Mock 通過不代表 WoW Retail/PTR 實機通過。
- 不連網、不讀取 WTF、不修改 AddOn 原始碼。
#>
param(
    [ValidateSet("quick", "core", "boundary", "aura121", "all")]
    [string]$Suite = "all",
    [string]$OutputDirectory = "TestResults",
    [string]$LuaInterpreter = "C:\Program Files (x86)\Lua\5.1\lua.exe"
)

$ErrorActionPreference = "Stop"
$utf8 = [System.Text.UTF8Encoding]::new($false)

$workspace = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$harness = Join-Path $workspace "Tests\FlowValidationHarness.lua"

if (-not (Test-Path -LiteralPath $harness)) {
    throw "Missing flow validation harness: $harness"
}

if (-not (Test-Path -LiteralPath $LuaInterpreter)) {
    $luaCommand = Get-Command lua -ErrorAction SilentlyContinue
    if ($luaCommand) {
        $LuaInterpreter = $luaCommand.Source
    }
}

if (-not (Test-Path -LiteralPath $LuaInterpreter)) {
    throw "lua.exe not found. Install Lua 5.1 or pass -LuaInterpreter <path>."
}

if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $reportDirectory = $OutputDirectory
} else {
    $reportDirectory = Join-Path $workspace $OutputDirectory
}
[System.IO.Directory]::CreateDirectory($reportDirectory) | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$jsonPath = Join-Path $reportDirectory ("EAM_FlowValidation_" + $Suite + "_" + $timestamp + ".json")
$markdownPath = Join-Path $reportDirectory ("EAM_FlowValidation_" + $Suite + "_" + $timestamp + ".md")

Push-Location -LiteralPath $workspace
try {
    & $LuaInterpreter $harness --suite $Suite --output $jsonPath
    $luaExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $jsonPath)) {
    throw "Flow validation did not produce JSON report. Lua exit code: $luaExitCode"
}

$reportText = [System.IO.File]::ReadAllText($jsonPath)
try {
    $report = $reportText | ConvertFrom-Json
}
catch {
    throw "Invalid flow validation JSON: $($_.Exception.Message)"
}

if ($report.type -ne "EAM_FLOW_VALIDATION_REPORT" -or [int]$report.schema -ne 2) {
    throw "Unsupported flow report schema or type."
}

function Escape-MarkdownCell {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) {
        return ""
    }
    return ([string]$Value).Replace("|", "\|").Replace([char]13, " ").Replace([char]10, " ")
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# EAM 離線流程驗證報告")
$lines.Add("")
$lines.Add("- 產生時間：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
$lines.Add("- Suite：``$($report.suite)``")
$lines.Add("- 來源：``$($report.environment.source)``")
$lines.Add("- Interface：``$($report.environment.interface)``")
$lines.Add("- 結果：``$($report.status)``")
$lines.Add("- 通過／失敗／略過／待完成：$($report.summary.passed)／$($report.summary.failed)／$($report.summary.skipped)／$($report.summary.pending)")
$lines.Add("")
$lines.Add("> 此報告為 Lua 5.1 Mock 離線證據，不代表 WoW Retail／PTR 實機通過。")
$lines.Add("")
$lines.Add("| 案例 | Suite | 狀態 | 耗時 ms | 訊息 |")
$lines.Add("| --- | --- | --- | ---: | --- |")
foreach ($case in $report.cases) {
    $lines.Add(
        "| $(Escape-MarkdownCell $case.id) | $(Escape-MarkdownCell $case.suite) | $(Escape-MarkdownCell $case.status) | $($case.durationMs) | $(Escape-MarkdownCell $case.message) |"
    )
}
$lines.Add("")
$lines.Add("## 開發回灌")
$lines.Add("")
$lines.Add("- JSON：``$jsonPath``")
$lines.Add("- 下一步：若改動涉及 WoW API、戰鬥或 Widget，需在遊戲內執行 ``/eam test`` 並匯入實機報告。")

[System.IO.File]::WriteAllLines($markdownPath, $lines, $utf8)

Write-Host "FLOW_REPORT_JSON=$jsonPath"
Write-Host "FLOW_REPORT_MARKDOWN=$markdownPath"
Write-Host "FLOW_SUMMARY=passed:$($report.summary.passed),failed:$($report.summary.failed),skipped:$($report.summary.skipped),pending:$($report.summary.pending)"

if ($luaExitCode -ne 0 -or
    $report.status -ne "pass" -or
    [int]$report.summary.failed -gt 0 -or
    [int]$report.summary.skipped -gt 0 -or
    [int]$report.summary.pending -gt 0 -or
    @($report.boundaryWarnings).Count -gt 0) {
    exit 1
}
