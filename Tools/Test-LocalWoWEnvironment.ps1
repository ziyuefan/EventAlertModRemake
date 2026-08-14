<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: Tools\Test-LocalWoWEnvironment.ps1

理念:
- 以 WoW 主程式 ProductVersion 作為本機版本樹斷言。
- 在實機流程前確認 EventAlertMod AddOns 路徑仍是指向實體專案的 Reparse Point。

邊界:
- 只讀執行檔與檔案系統中繼資料，不啟動客戶端、不讀 WTF、不修改或修復 SymbolicLink。
- 版本斷言鎖定 patch train，不鎖定會隨更新變動的 build 尾碼。
#>
[CmdletBinding()]
param(
    [string]$WowRoot = "D:\World of Warcraft",
    [string]$ProjectRoot = "",
    [string]$RetailExpectedPatch = "12.1.0",
    [string]$PtrExpectedPatch = "12.1.0",
    [string]$XPtrExpectedPatch = "12.0.7",
    [string]$OutputDirectory = "TestResults"
)

$ErrorActionPreference = "Stop"
$utf8 = [System.Text.UTF8Encoding]::new($false)
$workspace = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = $workspace
}

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    return $fullPath.TrimEnd([char[]]@([char]'\', [char]'/'))
}

function Get-ExpectedTargetPath {
    param(
        [Parameter(Mandatory = $true)][System.IO.DirectoryInfo]$Link,
        [Parameter(Mandatory = $true)][string]$RawTarget
    )

    if ([System.IO.Path]::IsPathRooted($RawTarget)) {
        return Get-NormalizedPath -Path $RawTarget
    }
    return Get-NormalizedPath -Path (Join-Path $Link.Parent.FullName $RawTarget)
}

$wowRootPath = Get-NormalizedPath -Path $WowRoot
$projectRootPath = Get-NormalizedPath -Path $ProjectRoot
if (-not (Test-Path -LiteralPath $wowRootPath -PathType Container)) {
    throw "WoW root does not exist: $wowRootPath"
}
if (-not (Test-Path -LiteralPath $projectRootPath -PathType Container)) {
    throw "Project root does not exist: $projectRootPath"
}

if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $reportDirectory = $OutputDirectory
} else {
    $reportDirectory = Join-Path $workspace $OutputDirectory
}
[System.IO.Directory]::CreateDirectory($reportDirectory) | Out-Null

$definitions = @(
    [pscustomobject]@{ Key = "retail"; Directory = "_retail_"; Executable = "Wow.exe"; ExpectedPatch = $RetailExpectedPatch },
    [pscustomobject]@{ Key = "ptr"; Directory = "_ptr_"; Executable = "WowT.exe"; ExpectedPatch = $PtrExpectedPatch },
    [pscustomobject]@{ Key = "xptr"; Directory = "_xptr_"; Executable = "WowT.exe"; ExpectedPatch = $XPtrExpectedPatch }
)

$clientResults = [System.Collections.Generic.List[object]]::new()
$passed = 0
$failed = 0
foreach ($definition in $definitions) {
    $versionRoot = Join-Path $wowRootPath $definition.Directory
    $executablePath = Join-Path $versionRoot $definition.Executable
    $wtfPath = Join-Path $versionRoot "WTF"
    $addonsPath = Join-Path $versionRoot "Interface\AddOns"
    $linkPath = Join-Path $addonsPath "EventAlertMod"
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

    $linkType = ""
    $rawTarget = ""
    $normalizedTarget = ""
    $isReparsePoint = $false
    $targetMatches = $false
    if (Test-Path -LiteralPath $linkPath) {
        $link = Get-Item -LiteralPath $linkPath -Force
        $linkType = [string]$link.LinkType
        $rawTargets = @($link.Target)
        if ($rawTargets.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$rawTargets[0])) {
            $rawTarget = [string]$rawTargets[0]
            $normalizedTarget = Get-ExpectedTargetPath -Link $link -RawTarget $rawTarget
        }
        $isReparsePoint = ($link.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        $targetMatches = -not [string]::IsNullOrWhiteSpace($normalizedTarget) -and [string]::Equals(
            $normalizedTarget,
            $projectRootPath,
            [System.StringComparison]::OrdinalIgnoreCase
        )
        if (-not $isReparsePoint) {
            $failures.Add("EventAlertMod path is not a Reparse Point: $linkPath")
        }
        if (-not $targetMatches) {
            $failures.Add("EventAlertMod target mismatch: $rawTarget")
        }
    } else {
        $failures.Add("EventAlertMod link is missing: $linkPath")
    }

    $status = if ($failures.Count -eq 0) { "pass" } else { "fail" }
    if ($status -eq "pass") {
        $passed++
    } else {
        $failed++
    }

    $clientResults.Add([pscustomobject][ordered]@{
        key = $definition.Key
        versionDirectory = $definition.Directory
        executable = $definition.Executable
        expectedPatch = [string]$definition.ExpectedPatch
        actualPatch = $actualPatch
        productVersion = $productVersion
        fileVersion = $fileVersion
        versionMatches = $versionMatches
        hasWtf = $hasWtf
        hasAddOns = $hasAddOns
        linkPath = $linkPath
        linkType = $linkType
        linkTarget = $rawTarget
        normalizedLinkTarget = $normalizedTarget
        isReparsePoint = $isReparsePoint
        targetMatches = $targetMatches
        status = $status
        failures = @($failures)
    })
}

$report = [pscustomobject][ordered]@{
    schema = 1
    type = "EAM_LOCAL_WOW_ENVIRONMENT_ASSERTION"
    generatedAt = (Get-Date).ToString("o")
    status = if ($failed -eq 0) { "pass" } else { "fail" }
    wowRoot = $wowRootPath
    projectRoot = $projectRootPath
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
$lines.Add("- WoW 根目錄：``$wowRootPath``")
$lines.Add("- EAM 實體專案：``$projectRootPath``")
$lines.Add("- 結果：``$($report.status)``")
$lines.Add("- 通過／失敗：$passed／$failed")
$lines.Add("")
$lines.Add("| 版本樹 | 預期 Patch | ProductVersion | 版本 | Reparse | Target | 結果 |")
$lines.Add("| --- | --- | --- | --- | --- | --- | --- |")
foreach ($client in $clientResults) {
    $lines.Add("| $($client.versionDirectory) | $($client.expectedPatch) | $($client.productVersion) | $($client.versionMatches) | $($client.isReparsePoint) | $($client.normalizedLinkTarget) | $($client.status) |")
    foreach ($failure in $client.failures) {
        $lines.Add("")
        $lines.Add("- ``$($client.versionDirectory)``：$failure")
    }
}
$lines.Add("")
$lines.Add("> 此工具只驗證本機版本與連結邊界，不代表 WoW 實機流程、Secret、taint 或 UI 通過。")
[System.IO.File]::WriteAllLines($markdownPath, $lines, $utf8)

foreach ($client in $clientResults) {
    Write-Host ("WOW_ENV client={0} expected={1} actual={2} reparse={3} target={4} status={5}" -f $client.versionDirectory, $client.expectedPatch, $client.actualPatch, $client.isReparsePoint, $client.normalizedLinkTarget, $client.status)
}
Write-Host "WOW_ENV_REPORT_JSON=$jsonPath"
Write-Host "WOW_ENV_REPORT_MARKDOWN=$markdownPath"
Write-Host "WOW_ENV_SUMMARY=passed:$passed,failed:$failed"

if ($failed -gt 0) {
    exit 1
}