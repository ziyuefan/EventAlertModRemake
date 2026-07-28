<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: Tools\Import-EAMFlowReport.ps1

理念:
- 將遊戲內流程測試報告從 WTF SavedVariables 或 JSON 回灌至開發環境。
- 驗證 schema/type 並產生可追溯 JSON 與 Markdown。

邊界:
- 只讀輸入，不修改 WTF。
- 不將 Mock 報告誤標為 Retail/PTR 實機結果。
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$OutputDirectory = "TestResults\Imported"
)

$ErrorActionPreference = "Stop"
$utf8 = [System.Text.UTF8Encoding]::new($false)

function ConvertFrom-LuaEscapedString {
    param([string]$Value)

    $builder = [System.Text.StringBuilder]::new()
    $index = 0
    while ($index -lt $Value.Length) {
        $character = $Value[$index]
        if ($character -ne "\") {
            [void]$builder.Append($character)
            $index++
            continue
        }

        $index++
        if ($index -ge $Value.Length) {
            throw "Invalid trailing escape in SavedVariables string."
        }

        $escaped = $Value[$index]
        if ($escaped -eq "n") {
            [void]$builder.Append([char]10)
        } elseif ($escaped -eq "r") {
            [void]$builder.Append([char]13)
        } elseif ($escaped -eq "t") {
            [void]$builder.Append([char]9)
        } elseif ($escaped -eq "\") {
            [void]$builder.Append("\")
        } elseif ($escaped -eq '"') {
            [void]$builder.Append('"')
        } elseif ([char]::IsDigit($escaped)) {
            $digits = [string]$escaped
            $lookahead = 1
            while ($lookahead -lt 3 -and ($index + 1) -lt $Value.Length -and [char]::IsDigit($Value[$index + 1])) {
                $index++
                $digits += $Value[$index]
                $lookahead++
            }
            [void]$builder.Append([char][int]$digits)
        } else {
            [void]$builder.Append($escaped)
        }
        $index++
    }

    return $builder.ToString()
}

function Escape-MarkdownCell {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) {
        return ""
    }
    return ([string]$Value).Replace("|", "\|").Replace([char]13, " ").Replace([char]10, " ")
}

$resolvedInput = (Resolve-Path -LiteralPath $Path).Path
$inputText = [System.IO.File]::ReadAllText($resolvedInput)

if ([System.IO.Path]::GetExtension($resolvedInput) -ieq ".json") {
    $reportText = $inputText
} else {
    $pattern = 'EAM_FLOW_TEST_REPORT_JSON\s*=\s*"((?:\\.|[^"\\])*)"'
    $match = [regex]::Match($inputText, $pattern)
    if (-not $match.Success) {
        throw "EAM_FLOW_TEST_REPORT_JSON not found in SavedVariables file."
    }
    $reportText = ConvertFrom-LuaEscapedString $match.Groups[1].Value
}

try {
    $report = $reportText | ConvertFrom-Json
}
catch {
    throw "Invalid flow validation JSON: $($_.Exception.Message)"
}

if ($report.type -ne "EAM_FLOW_VALIDATION_REPORT" -or [int]$report.schema -ne 1) {
    throw "Unsupported flow report schema or type."
}

$workspace = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $reportDirectory = $OutputDirectory
} else {
    $reportDirectory = Join-Path $workspace $OutputDirectory
}
[System.IO.Directory]::CreateDirectory($reportDirectory) | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$source = if ($report.environment.source) { [string]$report.environment.source } else { "unknown" }
$safeSource = $source -replace '[^A-Za-z0-9_-]', '_'
$jsonPath = Join-Path $reportDirectory ("EAM_FlowValidation_" + $safeSource + "_" + $timestamp + ".json")
$markdownPath = Join-Path $reportDirectory ("EAM_FlowValidation_" + $safeSource + "_" + $timestamp + ".md")

$prettyJSON = $report | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($jsonPath, $prettyJSON + [Environment]::NewLine, $utf8)

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# EAM 流程驗證回灌報告")
$lines.Add("")
$lines.Add("- 匯入時間：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
$lines.Add("- 輸入：``$resolvedInput``")
$lines.Add("- Suite：``$($report.suite)``")
$lines.Add("- 證據來源：``$source``")
$lines.Add("- Interface：``$($report.environment.interface)``")
$lines.Add("- 結果：``$($report.status)``")
$lines.Add("- 通過／失敗／略過／待完成：$($report.summary.passed)／$($report.summary.failed)／$($report.summary.skipped)／$($report.summary.pending)")
$lines.Add("")
if ($source -eq "offline-mock") {
    $lines.Add("> 此為 Mock 證據，不得標記為 Retail／PTR 實機通過。")
} else {
    $lines.Add("> 此報告來自遊戲內 runner；仍需搭配 build、角色、場景與 taint／Lua error 證據完成 RQA 簽收。")
}
$lines.Add("")
$lines.Add("| 案例 | Suite | 狀態 | 耗時 ms | 訊息 |")
$lines.Add("| --- | --- | --- | ---: | --- |")
foreach ($case in $report.cases) {
    $lines.Add(
        "| $(Escape-MarkdownCell $case.id) | $(Escape-MarkdownCell $case.suite) | $(Escape-MarkdownCell $case.status) | $($case.durationMs) | $(Escape-MarkdownCell $case.message) |"
    )
}

[System.IO.File]::WriteAllLines($markdownPath, $lines, $utf8)

Write-Host "IMPORTED_FLOW_JSON=$jsonPath"
Write-Host "IMPORTED_FLOW_MARKDOWN=$markdownPath"
Write-Host "IMPORTED_FLOW_SOURCE=$source"
Write-Host "IMPORTED_FLOW_STATUS=$($report.status)"

if ([int]$report.summary.failed -gt 0 -or [int]$report.summary.pending -gt 0) {
    exit 1
}