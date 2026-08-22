<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: .AI\Tools\Test-LocalWoWEnvironment.ps1

責任:
- 以 WoW 主程式 ProductVersion 斷言本機支援通道。
- 在部署或實機驗證前，以 fail-closed 規則檢查 AddOns\EventAlertMod 目標型態。

邊界:
- 只讀執行檔、目錄存在性與 Reparse Point metadata；不啟動客戶端、不讀 WTF 內容。
- 不追蹤、不修改、不刪除、不重建任何 SymbolicLink、Junction 或 Reparse Point。
- missing 目標可由部署工具建立；既有 Reparse Point 一律阻擋。
#>
[CmdletBinding()]
param(
    [string]$WowRoot = "D:\World of Warcraft",
    [Alias("AddonRoot")]
    [string]$ProjectRoot = "",
    [string]$RetailExpectedPatch = "12.1.0",
    [string]$PtrExpectedPatch = "12.1.0",
    [string]$XPtrExpectedPatch = "12.0.7",
    [string]$OutputDirectory = "TestResults"
)

$ErrorActionPreference = "Stop"
$utf8 = [System.Text.UTF8Encoding]::new($false)
. (Join-Path $PSScriptRoot "Resolve-EAMProject.ps1")
$eamPaths = Get-EAMProjectPaths
$workspace = $eamPaths.GovernanceRoot
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = $eamPaths.AddonRoot
}

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]@([char]'\', [char]'/'))
}

$wowRootPath = Get-NormalizedPath -Path $WowRoot
$addonSourcePath = Get-NormalizedPath -Path $ProjectRoot
if (-not (Test-Path -LiteralPath $wowRootPath -PathType Container)) {
    throw "WoW root does not exist: $wowRootPath"
}
if (-not (Test-Path -LiteralPath $addonSourcePath -PathType Container)) {
    throw "Addon source does not exist: $addonSourcePath"
}

$sourceItem = Get-Item -LiteralPath $addonSourcePath -Force
if (($sourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Addon source must be a physical directory, not a Reparse Point: $addonSourcePath"
}
if (-not (Test-Path -LiteralPath (Join-Path $addonSourcePath "EventAlertMod.toc") -PathType Leaf)) {
    throw "Addon source is missing EventAlertMod.toc: $addonSourcePath"
}

$reportDirectory = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory
} else {
    Join-Path $workspace $OutputDirectory
}
[System.IO.Directory]::CreateDirectory($reportDirectory) | Out-Null

$definitions = @(
    [pscustomobject]@{ Key = "retail"; Directory = "_retail_"; Executable = "Wow.exe"; ExpectedPatch = $RetailExpectedPatch; Label = "Retail（正式服）" },
    [pscustomobject]@{ Key = "ptr"; Directory = "_ptr_"; Executable = "WowT.exe"; ExpectedPatch = $PtrExpectedPatch; Label = "PTR" },
    [pscustomobject]@{ Key = "xptr"; Directory = "_xptr_"; Executable = "WowT.exe"; ExpectedPatch = $XPtrExpectedPatch; Label = "XPTR" }
)

$clientResults = [System.Collections.Generic.List[object]]::new()
$passed = 0
$failed = 0
foreach ($definition in $definitions) {
    $versionRoot = Join-Path $wowRootPath $definition.Directory
    $executablePath = Join-Path $versionRoot $definition.Executable
    $wtfPath = Join-Path $versionRoot "WTF"
    $addonsPath = Join-Path $versionRoot "Interface\AddOns"
    $targetPath = Join-Path $addonsPath "EventAlertMod"
    $failures = [System.Collections.Generic.List[string]]::new()

    $productVersion = ""
    $fileVersion = ""
    $actualPatch = ""
    if (Test-Path -LiteralPath $executablePath -PathType Leaf) {
        $executable = Get-Item -LiteralPath $executablePath
        $productVersion = [string]$executable.VersionInfo.ProductVersion
        $fileVersion = [string]$executable.VersionInfo.FileVersion
        if ($productVersion -match '(?<patch>\d+\.\d+\.\d+)\.(?<build>\d+)') {
            $actualPatch = $Matches.patch
        } else {
            $failures.Add("ProductVersion format is unsupported: $productVersion")
        }
    } else {
        $failures.Add("Executable is missing: $executablePath")
    }

    $versionMatches = $actualPatch -eq [string]$definition.ExpectedPatch
    if (-not $versionMatches) {
        $failures.Add("Expected patch $($definition.ExpectedPatch), actual $actualPatch")
    }

    $hasWtf = Test-Path -LiteralPath $wtfPath -PathType Container
    $hasAddOns = Test-Path -LiteralPath $addonsPath -PathType Container
    if (-not $hasWtf) {
        $failures.Add("WTF directory is missing: $wtfPath")
    }
    if (-not $hasAddOns) {
        $failures.Add("AddOns directory is missing: $addonsPath")
    }

    $targetKind = "missing"
    $linkType = ""
    $linkTarget = ""
    $isReparsePoint = $false
    $targetReady = $true
    if (Test-Path -LiteralPath $targetPath) {
        $target = Get-Item -LiteralPath $targetPath -Force
        $isReparsePoint = ($target.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        $linkType = [string]$target.LinkType
        $targets = @($target.Target)
        if ($targets.Count -gt 0) {
            $linkTarget = [string]$targets[0]
        }

        if ($isReparsePoint) {
            $targetKind = "reparse-point"
            $targetReady = $false
            $failures.Add("Unsafe Reparse Point blocks deployment: $targetPath -> $linkTarget")
        } elseif (-not $target.PSIsContainer) {
            $targetKind = "file"
            $targetReady = $false
            $failures.Add("Deployment target is a file: $targetPath")
        } else {
            $targetKind = "physical-directory"
            $nestedReparse = @(Get-ChildItem -LiteralPath $targetPath -Recurse -Force | Where-Object {
                ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
            })
            if ($nestedReparse.Count -gt 0) {
                $targetReady = $false
                $failures.Add("Deployment target contains nested Reparse Points")
            }
            if (-not (Test-Path -LiteralPath (Join-Path $targetPath "EventAlertMod.toc") -PathType Leaf)) {
                $targetReady = $false
                $failures.Add("Physical deployment target is incomplete: EventAlertMod.toc is missing")
            }
        }
    }

    $status = if ($failures.Count -eq 0) { "pass" } else { "fail" }
    if ($status -eq "pass") { $passed++ } else { $failed++ }

    $clientResults.Add([pscustomobject][ordered]@{
        key = $definition.Key
        label = $definition.Label
        versionDirectory = $definition.Directory
        executable = $definition.Executable
        expectedPatch = [string]$definition.ExpectedPatch
        actualPatch = $actualPatch
        productVersion = $productVersion
        fileVersion = $fileVersion
        versionMatches = $versionMatches
        hasWtf = $hasWtf
        hasAddOns = $hasAddOns
        targetPath = $targetPath
        targetKind = $targetKind
        linkType = $linkType
        linkTarget = $linkTarget
        isReparsePoint = $isReparsePoint
        targetReady = $targetReady
        status = $status
        failures = @($failures)
    })
}

$report = [pscustomobject][ordered]@{
    schema = 2
    type = "EAM_LOCAL_WOW_ENVIRONMENT_ASSERTION"
    generatedAt = (Get-Date).ToString("o")
    status = if ($failed -eq 0) { "pass" } else { "fail" }
    wowRoot = $wowRootPath
    addonSource = $addonSourcePath
    summary = [pscustomobject][ordered]@{
        total = $definitions.Count
        passed = $passed
        failed = $failed
    }
    clients = @($clientResults)
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmssfff"
$jsonPath = Join-Path $reportDirectory ("EAM_LocalWoWEnvironment_" + $timestamp + ".json")
$markdownPath = Join-Path $reportDirectory ("EAM_LocalWoWEnvironment_" + $timestamp + ".md")
[System.IO.File]::WriteAllText($jsonPath, ($report | ConvertTo-Json -Depth 8 -Compress), $utf8)

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# EAM 本機 WoW 環境斷言報告")
$lines.Add("")
$lines.Add("- 產生時間：$($report.generatedAt)")
$lines.Add("- WoW 根目錄：$wowRootPath")
$lines.Add("- 插件來源：$addonSourcePath")
$lines.Add("- 結果：$($report.status)")
$lines.Add("- 通過／失敗：$passed／$failed")
$lines.Add("")
$lines.Add("| 通道 | 目錄 | ProductVersion | TargetKind | Ready | 結果 |")
$lines.Add("| --- | --- | --- | --- | --- | --- |")
foreach ($client in $clientResults) {
    $lines.Add("| $($client.label) | $($client.versionDirectory) | $($client.productVersion) | $($client.targetKind) | $($client.targetReady) | $($client.status) |")
    foreach ($failure in $client.failures) {
        $lines.Add("")
        $lines.Add("- $($client.versionDirectory)：$failure")
    }
}
$lines.Add("")
$lines.Add("> 此工具只驗證本機版本與部署邊界，不代表 WoW 實機流程、Secret、taint 或 UI 通過。")
[System.IO.File]::WriteAllLines($markdownPath, $lines, $utf8)

foreach ($client in $clientResults) {
    Write-Host ("WOW_ENV client={0} version={1} targetKind={2} ready={3} status={4}" -f $client.versionDirectory, $client.productVersion, $client.targetKind, $client.targetReady, $client.status)
}
Write-Host "WOW_ENV_REPORT_JSON=$jsonPath"
Write-Host "WOW_ENV_REPORT_MARKDOWN=$markdownPath"
Write-Host "WOW_ENV_SUMMARY=passed:$passed,failed:$failed"

if ($failed -gt 0) {
    exit 1
}