<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: .AI\Tools\Resolve-EAMProject.ps1

責任:
- 為治理工具提供唯一的新專案路徑契約。
- 明確區分 Git 專案根、插件來源、AI 治理、Dist 與 Deploy。

邊界:
- 只解析並驗證新專案路徑，不存取舊專案或 WoW 目錄。
#>
Set-StrictMode -Version Latest

function Get-EAMProjectPaths {
    $governanceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
    $projectRoot = (Resolve-Path -LiteralPath (Join-Path $governanceRoot "..")).Path
    $addonRoot = Join-Path $projectRoot "EventAlertMod"
    $deployRoot = Join-Path $projectRoot "Deploy"
    $distRoot = Join-Path $projectRoot "Dist"
    $testResultsRoot = Join-Path $governanceRoot "TestResults"

    if ([System.IO.Path]::GetFileName($governanceRoot) -ne ".AI") {
        throw "治理工具不在 .AI\Tools 下：$PSScriptRoot"
    }
    if (-not (Test-Path -LiteralPath $addonRoot -PathType Container)) {
        throw "插件來源不存在：$addonRoot"
    }

    return [pscustomobject][ordered]@{
        ProjectRoot = $projectRoot
        AddonRoot = $addonRoot
        GovernanceRoot = $governanceRoot
        ToolsRoot = $PSScriptRoot
        DeployRoot = $deployRoot
        DistRoot = $distRoot
        TestResultsRoot = $testResultsRoot
        TocPath = Join-Path $addonRoot "EventAlertMod.toc"
    }
}
