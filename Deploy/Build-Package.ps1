<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: Deploy\Build-Package.ps1

責任:
- 只從專案根目錄的 EventAlertMod 實體資料夾建立 ZIP。
- 驗證 TOC、Lua/XML 清單、Managers、敏感資訊與 Reparse Point 邊界。
- 以一次性系統暫存建立頂層 EventAlertMod/，完成後清除暫存。

邊界:
- 不從 .AI、Deploy、Dist 或任何常駐 staging 取用插件檔案。
- 不上傳 GitHub、CurseForge 或 WoWInterface。
- 離線驗證通過不等於 WoW 實機簽收。
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = "",
    [string]$PackageLabel = "",
    [switch]$DryRun,
    [switch]$SkipLuaCheck,
    [switch]$SkipFlowValidation,
    [string]$LuaCompiler = "C:\Program Files (x86)\Lua\5.1\luac.exe"
)

$ErrorActionPreference = "Stop"
$utf8 = [System.Text.UTF8Encoding]::new($false)
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$addonRoot = Join-Path $projectRoot "EventAlertMod"
$governanceRoot = Join-Path $projectRoot ".AI"
$tocPath = Join-Path $addonRoot "EventAlertMod.toc"

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]@([char]'\', [char]'/'))
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$FullPath
    )

    $base = Get-NormalizedPath -Path $BasePath
    $full = Get-NormalizedPath -Path $FullPath
    if (-not $full.StartsWith($base + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside base directory: $full"
    }
    return $full.Substring($base.Length + 1).Replace("\", "/")
}

function Get-TocValue {
    param([Parameter(Mandatory = $true)][string]$Key)

    $pattern = "^##\s+$([regex]::Escape($Key)):\s*(.+)$"
    foreach ($line in Get-Content -LiteralPath $tocPath -Encoding UTF8) {
        if ($line -match $pattern) {
            return $Matches[1].Trim()
        }
    }
    return $null
}

function Get-TocFiles {
    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($line in Get-Content -LiteralPath $tocPath -Encoding UTF8) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("#")) {
            continue
        }
        $files.Add($trimmed.Replace("\", "/"))
    }
    return @($files)
}

function Test-AddonSource {
    if (-not (Test-Path -LiteralPath $addonRoot -PathType Container)) {
        throw "插件來源不存在：$addonRoot"
    }

    $sourceItem = Get-Item -LiteralPath $addonRoot -Force
    if (($sourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "插件來源不得為 Reparse Point：$addonRoot"
    }

    $reparseItems = @(Get-ChildItem -LiteralPath $addonRoot -Recurse -Force | Where-Object {
        ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    })
    if ($reparseItems.Count -gt 0) {
        throw "插件來源內含 Reparse Point：$($reparseItems[0].FullName)"
    }

    if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
        throw "缺少 EventAlertMod.toc：$tocPath"
    }

    foreach ($requiredFile in @(
        "Managers\AlertManager.lua",
        "Managers\AuraRuleCompiler.lua",
        "README.md",
        "changelog.txt"
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $addonRoot $requiredFile) -PathType Leaf)) {
            throw "缺少必要插件檔案：$requiredFile"
        }
    }

    foreach ($document in @("README.md", "changelog.txt")) {
        $publicPath = Join-Path $projectRoot $document
        $addonPath = Join-Path $addonRoot $document
        if (-not (Test-Path -LiteralPath $publicPath -PathType Leaf)) {
            throw "根目錄缺少公開文件：$publicPath"
        }
        $publicHash = (Get-FileHash -LiteralPath $publicPath -Algorithm SHA256).Hash
        $addonHash = (Get-FileHash -LiteralPath $addonPath -Algorithm SHA256).Hash
        if (-not [string]::Equals($publicHash, $addonHash, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "根目錄與插件副本文件雜湊不一致：$document"
        }
    }

    foreach ($forbiddenName in @(".AI", "Deploy", "Dist", "Docs", "Tools", "Tests", "TestResults", "backup", "LegacyReference", "ReferenceLibs", "Schemas", "nppBackup")) {
        if (Test-Path -LiteralPath (Join-Path $addonRoot $forbiddenName)) {
            throw "插件來源混入治理或暫存目錄：$forbiddenName"
        }
    }

    $temporaryFiles = @(Get-ChildItem -LiteralPath $addonRoot -Recurse -Force -File | Where-Object {
        $_.Name -match '(?i)(\.bak|\.tmp|\.swp|\.old|~)$'
    })
    if ($temporaryFiles.Count -gt 0) {
        throw "插件來源混入暫存／備份檔：$($temporaryFiles[0].FullName)"
    }

    $tocFiles = @(Get-TocFiles)
    $tocMap = @{}
    foreach ($relative in $tocFiles) {
        $physicalPath = Join-Path $addonRoot ($relative.Replace("/", "\"))
        if (-not (Test-Path -LiteralPath $physicalPath -PathType Leaf)) {
            throw "TOC 指向不存在檔案：$relative"
        }
        $tocMap[$relative.ToLowerInvariant()] = $true
    }

    $unlisted = [System.Collections.Generic.List[string]]::new()
    Get-ChildItem -LiteralPath $addonRoot -Recurse -Force -File | Where-Object {
        $_.Extension -in @(".lua", ".xml")
    } | ForEach-Object {
        $relative = Get-RelativePath -BasePath $addonRoot -FullPath $_.FullName
        if (-not $tocMap.ContainsKey($relative.ToLowerInvariant())) {
            $unlisted.Add($relative)
        }
    }
    if ($unlisted.Count -gt 0) {
        throw "插件來源包含未列入 TOC 的 Lua/XML：$($unlisted -join ', ')"
    }

    $version = Get-TocValue -Key "Version"
    if ([string]::IsNullOrWhiteSpace($version) -or $version -notmatch '^EventAlertMod_[A-Za-z0-9]+_[0-9]{8}$') {
        throw "TOC Version 格式不符：$version"
    }

    return $version
}

function Export-PackageReleaseNotes {
    param([Parameter(Mandatory = $true)][string]$DestinationPath)

    $changelogFile = Join-Path $addonRoot "changelog.txt"
    if (-not (Test-Path -LiteralPath $changelogFile -PathType Leaf)) {
        return
    }

    $lines = Get-Content -LiteralPath $changelogFile -Encoding UTF8
    $sectionLines = [System.Collections.Generic.List[string]]::new()
    $inSection = $false

    foreach ($line in $lines) {
        if ($line -match '^--\s*\[(.+)\](?:\s*\((.+)\))?') {
            if ($inSection) {
                break
            }
            $inSection = $true
            $sectionLines.Add("## " + $Matches[1].Trim())
            if ($Matches[2]) {
                $sectionLines.Add("> 📅 **發布日期 / Release Date**: " + $Matches[2].Trim())
                $sectionLines.Add("")
            }
            continue
        }
        if ($inSection) {
            $sectionLines.Add($line)
        }
    }

    if ($sectionLines.Count -gt 0) {
        $content = ($sectionLines -join "`r`n").Trim() + "`r`n"
        [System.IO.File]::WriteAllText($DestinationPath, $content, $utf8)
    }
}

function Test-SensitiveInfo {
    $patterns = @(
        '(?i)https://discord\.com/api/webhooks/',
        '(?i)https://hooks\.slack\.com/services/',
        '(?i)(api_?key|client_secret|app_secret|password|credential)\s*=\s*["''][^"'']+["'']'
    )
    foreach ($file in Get-ChildItem -LiteralPath $addonRoot -Recurse -Force -File | Where-Object {
        $_.Extension -in @(".lua", ".xml", ".toc")
    }) {
        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $file.FullName -Encoding UTF8) {
            $lineNumber++
            $trimmed = $line.Trim()
            if ($trimmed.StartsWith("--") -or $trimmed.StartsWith("##")) {
                continue
            }
            foreach ($pattern in $patterns) {
                if ($line -match $pattern) {
                    throw "可能含敏感資訊：$($file.FullName):$lineNumber"
                }
            }
        }
    }
}

function Invoke-PowerShellTool {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) {
        throw "需要 PowerShell 7 (pwsh)：$ScriptPath"
    }
    & $pwsh.Source -NoProfile -File $ScriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "工具失敗（exit $LASTEXITCODE）：$ScriptPath"
    }
}

function Invoke-OfflineValidation {
    if (-not $SkipLuaCheck) {
        $luaScript = Join-Path $governanceRoot "Tools\CheckLuaSyntax.ps1"
        Invoke-PowerShellTool -ScriptPath $luaScript -Arguments @("-AddonOnly", "-LuaCompiler", $LuaCompiler)
    }

    if (-not $SkipFlowValidation) {
        $flowScript = Join-Path $governanceRoot "Tools\Run-FlowValidation.ps1"
        $contractScript = Join-Path $governanceRoot "Tools\Test-ValidationContracts.ps1"
        Invoke-PowerShellTool -ScriptPath $flowScript -Arguments @("-Suite", "all")
        Invoke-PowerShellTool -ScriptPath $contractScript
    }
}

function Get-ZipEntries {
    param([Parameter(Mandatory = $true)][string]$ZipPath)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        return @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) } | ForEach-Object {
            $_.FullName.Replace("\", "/")
        })
    }
    finally {
        $archive.Dispose()
    }
}

$version = Test-AddonSource
Test-SensitiveInfo
Invoke-OfflineValidation

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $outputRoot = Join-Path $projectRoot "Dist"
} elseif ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $outputRoot = Get-NormalizedPath -Path $OutputDirectory
} else {
    $outputRoot = Get-NormalizedPath -Path (Join-Path $projectRoot $OutputDirectory)
}

if ($outputRoot.StartsWith((Get-NormalizedPath -Path $addonRoot) + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "輸出目錄不得位於插件來源內：$outputRoot"
}
[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$outputItem = Get-Item -LiteralPath $outputRoot -Force
if (($outputItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "輸出目錄不得為 Reparse Point：$outputRoot"
}

$label = if ([string]::IsNullOrWhiteSpace($PackageLabel)) { $version } else { "EventAlertMod_" + $PackageLabel }
if ($label -notmatch '^[A-Za-z0-9_.-]+$') {
    throw "PackageLabel 含不允許字元：$PackageLabel"
}
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$zipPath = Join-Path $outputRoot ($label + "_" + $timestamp + ".zip")
$hashPath = $zipPath + ".sha256"
if (Test-Path -LiteralPath $zipPath) {
    throw "輸出 ZIP 已存在：$zipPath"
}
if ($DryRun) {
    Write-Host "PACKAGE_DRY_RUN=pass"
    Write-Host "PACKAGE_SOURCE=$addonRoot"
    Write-Host "PACKAGE_OUTPUT=$zipPath"
    return
}

$tempBase = Get-NormalizedPath -Path ([System.IO.Path]::GetTempPath())
$stageRoot = Join-Path $tempBase ("EAMPackage_" + [guid]::NewGuid().ToString("N"))
$stageAddon = Join-Path $stageRoot "EventAlertMod"
try {
    [System.IO.Directory]::CreateDirectory($stageAddon) | Out-Null
    foreach ($entry in Get-ChildItem -LiteralPath $addonRoot -Force) {
        Copy-Item -LiteralPath $entry.FullName -Destination $stageAddon -Recurse -Force
    }

    Compress-Archive -LiteralPath $stageAddon -DestinationPath $zipPath -CompressionLevel Optimal

    $sourceEntries = @(Get-ChildItem -LiteralPath $addonRoot -Recurse -Force -File | ForEach-Object {
        "EventAlertMod/" + (Get-RelativePath -BasePath $addonRoot -FullPath $_.FullName)
    } | Sort-Object)
    $zipEntries = @(Get-ZipEntries -ZipPath $zipPath | Sort-Object)
    $difference = @(Compare-Object -ReferenceObject $sourceEntries -DifferenceObject $zipEntries)
    if ($difference.Count -gt 0) {
        throw "ZIP 與插件來源清單不一致：$($difference | Select-Object -First 5 | Out-String)"
    }
    foreach ($requiredEntry in @(
        "EventAlertMod/EventAlertMod.toc",
        "EventAlertMod/Managers/AlertManager.lua",
        "EventAlertMod/Managers/AuraRuleCompiler.lua"
    )) {
        if ($zipEntries -notcontains $requiredEntry) {
            throw "ZIP 缺少必要檔案：$requiredEntry"
        }
    }
    if (@($zipEntries | Where-Object { $_ -match '^EventAlertMod/(?:\.AI|Deploy|Dist|Docs|Tools|Tests|TestResults|backup|LegacyReference|ReferenceLibs|Schemas|nppBackup)(?:/|$)' }).Count -gt 0) {
        throw "ZIP 混入治理或暫存內容。"
    }

    $hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllText($hashPath, "$hash  $([System.IO.Path]::GetFileName($zipPath))`r`n", $utf8)
    $inventoryPath = $zipPath + ".inventory.json"
    $inventory = [pscustomobject][ordered]@{
        schema = 1
        type = "EAM_ADDON_PACKAGE_INVENTORY"
        generatedAt = (Get-Date).ToString("o")
        sourceRoot = $addonRoot
        archive = $zipPath
        rootEntry = "EventAlertMod/"
        fileCount = $zipEntries.Count
        sha256 = $hash
        entries = @($zipEntries)
    }
    [System.IO.File]::WriteAllText($inventoryPath, ($inventory | ConvertTo-Json -Depth 8), $utf8)

    $releaseNotesPath = [System.IO.Path]::ChangeExtension($zipPath, ".md")
    Export-PackageReleaseNotes -DestinationPath $releaseNotesPath

    Write-Host "PACKAGE_PATH=$zipPath"
    Write-Host "PACKAGE_SHA256=$hash"
    Write-Host "PACKAGE_INVENTORY=$inventoryPath"
    Write-Host "PACKAGE_RELEASENOTES=$releaseNotesPath"
    Write-Host "PACKAGE_FILES=$($zipEntries.Count)"
    Write-Host "PACKAGE_SOURCE=$addonRoot"
    Write-Host "PACKAGE_MANAGERS=pass"
}
finally {
    if (Test-Path -LiteralPath $stageRoot) {
        $normalizedStage = Get-NormalizedPath -Path $stageRoot
        if (-not $normalizedStage.StartsWith($tempBase + [System.IO.Path]::DirectorySeparatorChar + "EAMPackage_", [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "拒絕清理非預期暫存路徑：$normalizedStage"
        }
        Remove-Item -LiteralPath $normalizedStage -Recurse -Force
    }
}
