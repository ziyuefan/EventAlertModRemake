<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: Deploy\Build-SourcePackage.ps1

責任:
- 建立未來 Release 用的完整 Project_EventAlertMod 原始碼包。
- 保留專案原始碼與 AI 治理資料，排除本機、衍生與敏感暫存內容。
- 產生 SHA256 與 archive inventory，並驗證 ZIP 內容。

邊界:
- 不部署、不上傳、不執行 Git。
- 不讀取或跟隨任何 Reparse Point。
- ZIP 根目錄固定為 Project_EventAlertMod/。
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$utf8 = [System.Text.UTF8Encoding]::new($false)
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

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
    $prefix = $base + [System.IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "路徑越界：$full"
    }
    return $full.Substring($prefix.Length).Replace("\", "/")
}

function Test-ExcludedDirectory {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $normalized = $RelativePath.Replace("\", "/").Trim("/")
    if ([string]::IsNullOrWhiteSpace($normalized)) { return $false }
    $parts = @($normalized.Split('/'))
    $leaf = $parts[-1]
    if ($parts[0] -in @(".git", "Dist", ".codex-remote-attachments", ".agents", "backup", "TestResults")) {
        return $true
    }
    if ($leaf -in @(".git", "backup", "TestResults", "cache", ".cache", "__pycache__", ".pytest_cache", ".mypy_cache", "node_modules", "nppBackup") -or $leaf -like ".trash_*") {
        return $true
    }
    if ($parts[0] -eq ".AI" -and $parts.Count -ge 2) {
        if ($parts[1] -in @("backup", "TestResults", "patch-temp") -or $parts[1] -like ".trash_*") {
            return $true
        }
    }
    return $false
}

function Test-ExcludedFile {
    param([Parameter(Mandatory = $true)][System.IO.FileInfo]$File)
    if ($File.Name -eq ".translation_cache.json") { return $true }
    if ($File.Name -like "*secret*" -or $File.Name -like "*token*" -or $File.Name -like ".env*") { return $true }
    if ($File.Extension.ToLowerInvariant() -in @(".pyc", ".log", ".zip", ".tmp", ".bak", ".swp", ".old")) { return $true }
    return $File.Name.EndsWith("~")
}

function Get-SourceFiles {
    $files = [System.Collections.Generic.List[object]]::new()
    $pending = [System.Collections.Generic.Stack[string]]::new()
    $pending.Push($projectRoot)
    while ($pending.Count -gt 0) {
        $current = $pending.Pop()
        foreach ($entry in Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop) {
            $relative = Get-RelativePath -BasePath $projectRoot -FullPath $entry.FullName
            if ($entry.PSIsContainer -and (Test-ExcludedDirectory -RelativePath $relative)) {
                continue
            }
            if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "原始碼包來源含 Reparse Point，拒絕追蹤：$($entry.FullName)"
            }
            if ($entry.PSIsContainer) {
                $pending.Push($entry.FullName)
                continue
            }
            if (-not (Test-ExcludedFile -File $entry)) {
                $files.Add([pscustomobject]@{
                    FullName = $entry.FullName
                    RelativePath = $relative
                })
            }
        }
    }
    return @($files | Sort-Object RelativePath)
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

if (-not (Test-Path -LiteralPath $projectRoot -PathType Container)) {
    throw "專案根目錄不存在：$projectRoot"
}
$projectItem = Get-Item -LiteralPath $projectRoot -Force
if (($projectItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "專案根目錄不得為 Reparse Point：$projectRoot"
}

$sourceFiles = @(Get-SourceFiles)
if ($sourceFiles.Count -eq 0) {
    throw "沒有可封裝的原始碼檔案。"
}

$outputRoot = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path $projectRoot "Dist"
} elseif ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    Get-NormalizedPath -Path $OutputDirectory
} else {
    Get-NormalizedPath -Path (Join-Path $projectRoot $OutputDirectory)
}
$outputRoot = Get-NormalizedPath -Path $outputRoot
if (-not $outputRoot.StartsWith((Get-NormalizedPath -Path $projectRoot) + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "原始碼包輸出目錄必須位於專案內：$outputRoot"
}
if (Test-Path -LiteralPath $outputRoot) {
    $outputItem = Get-Item -LiteralPath $outputRoot -Force
    if (($outputItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "原始碼包輸出目錄不得為 Reparse Point：$outputRoot"
    }
}
[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$zipPath = Join-Path $outputRoot ("Project_EventAlertMod_SRC_" + $timestamp + ".zip")
if (Test-Path -LiteralPath $zipPath) {
    throw "輸出 ZIP 已存在：$zipPath"
}
if ($DryRun) {
    Write-Host "SOURCE_PACKAGE_DRY_RUN=pass"
    Write-Host "SOURCE_PACKAGE_SOURCE=$projectRoot"
    Write-Host "SOURCE_PACKAGE_OUTPUT=$zipPath"
    Write-Host "SOURCE_PACKAGE_FILES=$($sourceFiles.Count)"
    return
}

$tempBase = Get-NormalizedPath -Path ([System.IO.Path]::GetTempPath())
$stageRoot = Join-Path $tempBase ("EAMSourcePackage_" + [guid]::NewGuid().ToString("N"))
$stageProject = Join-Path $stageRoot "Project_EventAlertMod"
try {
    [System.IO.Directory]::CreateDirectory($stageProject) | Out-Null
    foreach ($sourceFile in $sourceFiles) {
        $destination = Join-Path $stageProject ($sourceFile.RelativePath.Replace("/", "\"))
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
        Copy-Item -LiteralPath $sourceFile.FullName -Destination $destination -Force
    }
    Compress-Archive -LiteralPath $stageProject -DestinationPath $zipPath -CompressionLevel Optimal
    $expectedEntries = @($sourceFiles | ForEach-Object { "Project_EventAlertMod/" + $_.RelativePath } | Sort-Object)
    $archiveEntries = @(Get-ZipEntries -ZipPath $zipPath | Sort-Object)
    $difference = @(Compare-Object -ReferenceObject $expectedEntries -DifferenceObject $archiveEntries)
    if ($difference.Count -gt 0) {
        throw "原始碼 ZIP inventory 不一致：$($difference | Select-Object -First 5 | Out-String)"
    }
    $hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $hashPath = $zipPath + ".sha256"
    $inventoryPath = $zipPath + ".inventory.json"
    [System.IO.File]::WriteAllText($hashPath, "$hash  $([System.IO.Path]::GetFileName($zipPath))`r`n", $utf8)
    $inventory = [pscustomobject][ordered]@{
        schema = 1
        type = "EAM_SOURCE_PACKAGE_INVENTORY"
        generatedAt = (Get-Date).ToString("o")
        sourceRoot = $projectRoot
        archive = $zipPath
        rootEntry = "Project_EventAlertMod/"
        fileCount = $archiveEntries.Count
        sha256 = $hash
        entries = @($archiveEntries)
    }
    [System.IO.File]::WriteAllText($inventoryPath, ($inventory | ConvertTo-Json -Depth 8), $utf8)
    Write-Host "SOURCE_PACKAGE_PATH=$zipPath"
    Write-Host "SOURCE_PACKAGE_SHA256=$hash"
    Write-Host "SOURCE_PACKAGE_INVENTORY=$inventoryPath"
    Write-Host "SOURCE_PACKAGE_FILES=$($archiveEntries.Count)"
}
finally {
    if (Test-Path -LiteralPath $stageRoot) {
        $normalizedStage = Get-NormalizedPath -Path $stageRoot
        if (-not $normalizedStage.StartsWith($tempBase + [System.IO.Path]::DirectorySeparatorChar + "EAMSourcePackage_", [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "拒絕清理非預期暫存路徑：$normalizedStage"
        }
        Remove-Item -LiteralPath $normalizedStage -Recurse -Force
    }
}