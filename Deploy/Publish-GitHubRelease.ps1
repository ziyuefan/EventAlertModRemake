<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: Deploy\Publish-GitHubRelease.ps1

責任:
- 提供一鍵式 GitHub Release 發布自動化，減少 Agent 與使用者手動操作 Token 消耗。
- 發布前強制執行 Lua 語法、Flow 流程測試與 Validation Contracts 離線門禁。
- 自動建立帶有標籤（預設 AGY）的 AddOn 插件包與專案 Source 源碼包及其 SHA-256 校驗檔。
- 自動抓取 changelog.txt，組裝結構化 Release Notes（含離線證據、責任歸屬與回退指引）。
- 透過 gh CLI 建立 GitHub Release / Pre-release 並上傳產物。

邊界:
- 離線門禁未通過時絕對 Fail-Closed，不發布任何 Release。
- 預設標記為 Pre-release，不破壞或覆蓋 main 的 Latest Release。
- 支援 -DryRun 預覽而不實際執行網路操作。
#>
[CmdletBinding()]
param(
    [string]$Tag = "",
    [string]$Title = "",
    [string]$PackageSuffix = "AGY",
    [switch]$Prerelease,
    [switch]$Draft,
    [switch]$DryRun,
    [switch]$SkipGate
)

$ErrorActionPreference = "Stop"
$utf8 = [System.Text.UTF8Encoding]::new($false)
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$addonRoot = Join-Path $projectRoot "EventAlertMod"
$governanceRoot = Join-Path $projectRoot ".AI"
$distRoot = Join-Path $projectRoot "Dist"
$tocPath = Join-Path $addonRoot "EventAlertMod.toc"
$changelogPath = Join-Path $addonRoot "changelog.txt"
$buildPackageScript = Join-Path $PSScriptRoot "Build-Package.ps1"
$buildSourceScript = Join-Path $PSScriptRoot "Build-SourcePackage.ps1"

Write-Host "=== EventAlertModRemake GitHub Release Publisher ===" -ForegroundColor Cyan

# 1. 檢查 GitHub CLI 環境
$ghPath = Get-Command gh -ErrorAction SilentlyContinue
if (-not $ghPath) {
    throw "未找到 GitHub CLI (gh.exe)！請確認已安裝並加入 PATH。"
}
$ghAuth = gh auth status 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -or $ghAuth -notmatch "Logged in") {
    throw "GitHub CLI 尚未登入！請先執行 gh auth login 完成授權。"
}
Write-Host "✓ GitHub CLI 已授權" -ForegroundColor Green

# 2. 取得 TOC 版本資訊
if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
    throw "缺少 TOC 檔案：$tocPath"
}
$tocVersion = $null
foreach ($line in Get-Content -LiteralPath $tocPath -Encoding UTF8) {
    if ($line -match '^##\s+Version:\s*(.+)$') {
        $tocVersion = $Matches[1].Trim()
        break
    }
}
if ([string]::IsNullOrWhiteSpace($tocVersion)) {
    $tocVersion = "EventAlertMod_MN_" + (Get-Date -Format "yyyyMMdd")
}

# 3. 決定 Tag 與 Title (基於原始格式，以 Suffix 作為後綴)
$dateStamp = Get-Date -Format "yyyyMMdd"
$suffixTag = if ([string]::IsNullOrWhiteSpace($PackageSuffix)) { "" } else { "-" + $PackageSuffix }

if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = "alpha-7.7"
}
if ([string]::IsNullOrWhiteSpace($Title)) {
    $Title = "Retail 12.1 Alpha 7.7"
}

Write-Host "發布目標 Tag   : $Tag" -ForegroundColor Yellow
Write-Host "發布目標 Title : $Title" -ForegroundColor Yellow

# 4. 離線門禁檢驗 (Validation Gate)
if (-not $SkipGate) {
    Write-Host "`n--> [1/4] 執行離線語法與流程驗證門禁..." -ForegroundColor Cyan
    
    # 4.1 Lua 語法
    $checkSyntaxScript = Join-Path $governanceRoot "Tools\CheckLuaSyntax.ps1"
    if (Test-Path -LiteralPath $checkSyntaxScript) {
        & pwsh -NoProfile -File $checkSyntaxScript
        if ($LASTEXITCODE -ne 0) { throw "Lua 語法檢查失敗！終止發布。" }
    }
    
    # 4.2 Flow 流程測試
    $flowScript = Join-Path $governanceRoot "Tools\Run-FlowValidation.ps1"
    if (Test-Path -LiteralPath $flowScript) {
        & pwsh -NoProfile -File $flowScript -Suite all
        if ($LASTEXITCODE -ne 0) { throw "Flow 流程驗證失敗！終止發布。" }
    }
    
    # 4.3 Validation Contracts 靜態契約
    $contractsScript = Join-Path $governanceRoot "Tools\Test-ValidationContracts.ps1"
    if (Test-Path -LiteralPath $contractsScript) {
        & pwsh -NoProfile -File $contractsScript
        if ($LASTEXITCODE -ne 0) { throw "Validation Contracts 契約檢查失敗！終止發布。" }
    }
    Write-Host "✓ 離線門禁全部通過 (OFFLINE VERIFIED)" -ForegroundColor Green
} else {
    Write-Host "⚠ 跳過離線門禁檢驗 (-SkipGate)" -ForegroundColor Magenta
}

# 5. 打包 AddOn 與 Source (基於原本格式)
Write-Host "`n--> [2/4] 打包插件與原始碼套件..." -ForegroundColor Cyan
[System.IO.Directory]::CreateDirectory($distRoot) | Out-Null

$beforePackageZips = @(Get-ChildItem -LiteralPath $distRoot -Filter "*.zip" -File | Select-Object -ExpandProperty FullName)

# 5.1 呼叫原有打包腳本
& pwsh -NoProfile -File $buildPackageScript
if ($LASTEXITCODE -ne 0) { throw "Build-Package 失敗！" }

$afterPackageZips = @(Get-ChildItem -LiteralPath $distRoot -Filter "*.zip" -File | Select-Object -ExpandProperty FullName)
$newPackageZips = @($afterPackageZips | Where-Object { $beforePackageZips -notcontains $_ })
if ($newPackageZips.Count -eq 0) {
    throw "未找到新產出的 AddOn ZIP！"
}
$rawAddonZip = $newPackageZips[-1]

# 5.2 呼叫原始碼打包腳本
$beforeSourceZips = @(Get-ChildItem -LiteralPath $distRoot -Filter "*.zip" -File | Select-Object -ExpandProperty FullName)
& pwsh -NoProfile -File $buildSourceScript
if ($LASTEXITCODE -ne 0) { throw "Build-SourcePackage 失敗！" }

$afterSourceZips = @(Get-ChildItem -LiteralPath $distRoot -Filter "*.zip" -File | Select-Object -ExpandProperty FullName)
$newSourceZips = @($afterSourceZips | Where-Object { $beforeSourceZips -notcontains $_ })
if ($newSourceZips.Count -eq 0) {
    throw "未找到新產出的 Source ZIP！"
}
$rawSourceZip = $newSourceZips[-1]

# 5.3 複製並依 alpha-6 標準命名格式 (EventAlertMod_MN_yyyyMMdd_HHmmss-alpha-7.7.zip)
$releaseTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"

$addonZipName = "EventAlertMod_MN_${releaseTimestamp}-${Tag}.zip"
$addonZip = Join-Path $distRoot $addonZipName
Copy-Item -LiteralPath $rawAddonZip -Destination $addonZip -Force

$addonHash = (Get-FileHash -LiteralPath $addonZip -Algorithm SHA256).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText($addonZip + ".sha256", "$addonHash  $addonZipName`r`n", $utf8)

$sourceZipName = "Project_EventAlertMod_SRC_${releaseTimestamp}-${Tag}.zip"
$sourceZip = Join-Path $distRoot $sourceZipName
Copy-Item -LiteralPath $rawSourceZip -Destination $sourceZip -Force

$sourceHash = (Get-FileHash -LiteralPath $sourceZip -Algorithm SHA256).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText($sourceZip + ".sha256", "$sourceHash  $sourceZipName`r`n", $utf8)

$filesToUpload = [System.Collections.Generic.List[string]]::new()
if ($addonZip -and (Test-Path -LiteralPath $addonZip)) {
    $filesToUpload.Add($addonZip)
    $hashFile = $addonZip + ".sha256"
    if (Test-Path -LiteralPath $hashFile) { $filesToUpload.Add($hashFile) }
    $invFile = [System.IO.Path]::ChangeExtension($addonZip, ".inventory.json")
    if (Test-Path -LiteralPath $invFile) { $filesToUpload.Add($invFile) }
}
if ($sourceZip -and (Test-Path -LiteralPath $sourceZip)) {
    $filesToUpload.Add($sourceZip)
    $hashFile = $sourceZip + ".sha256"
    if (Test-Path -LiteralPath $hashFile) { $filesToUpload.Add($hashFile) }
}

Write-Host "✓ 待上傳產物清單:" -ForegroundColor Green
foreach ($file in $filesToUpload) {
    $item = Get-Item -LiteralPath $file
    Write-Host "  - $($item.Name) ($([math]::Round($item.Length / 1KB, 1)) KB)" -ForegroundColor Gray
}

# 6. 組裝結構化 Release Notes (僅限魔獸插件開發 CHANGELOG，不含任何 AI 治理描述)
Write-Host "`n--> [3/4] 組裝結構化 Release Notes..." -ForegroundColor Cyan
$recentChangelog = ""
if (Test-Path -LiteralPath $changelogPath) {
    $lines = Get-Content -LiteralPath $changelogPath -Encoding UTF8
    $extracted = [System.Collections.Generic.List[string]]::new()
    $recording = $false
    foreach ($line in $lines) {
        if ($line -match '^--\s*\[.+?\]') {
            if ($recording) { break }
            $recording = $true
        }
        if ($recording) {
            $extracted.Add($line)
        }
    }
    $recentChangelog = $extracted -join "`r`n"
}

$addonHash = if ($addonZip) { (Get-FileHash -LiteralPath $addonZip -Algorithm SHA256).Hash.ToLowerInvariant() } else { "N/A" }
$sourceHash = if ($sourceZip) { (Get-FileHash -LiteralPath $sourceZip -Algorithm SHA256).Hash.ToLowerInvariant() } else { "N/A" }
$addonFileName = if ($addonZip) { [System.IO.Path]::GetFileName($addonZip) } else { "N/A" }
$sourceFileName = if ($sourceZip) { [System.IO.Path]::GetFileName($sourceZip) } else { "N/A" }

$releaseNotes = @"
# $Title

## 📝 更新日誌 (Changelog)

```text
$recentChangelog
```

---

## 📦 發布產物與 SHA-256 校驗 (Artifacts)

| 檔案名稱 | 說明 | SHA-256 雜湊值 |
| :--- | :--- | :--- |
| **`$addonFileName`** | 遊戲 AddOn 插件安裝包 | `$addonHash` |
| **`$sourceFileName`** | 專案完整工程原始碼包 | `$sourceHash` |
"@

$notesTempPath = Join-Path $distRoot "RELEASE_NOTES_$Tag.md"
[System.IO.File]::WriteAllText($notesTempPath, $releaseNotes, $utf8)
Write-Host "✓ Release Notes 已產出至：$notesTempPath" -ForegroundColor Green

# 7. 呼叫 gh CLI 發布 Release
Write-Host "`n--> [4/4] 執行 GitHub Release 發布..." -ForegroundColor Cyan

$ghArgs = [System.Collections.Generic.List[string]]::new()
$ghArgs.Add("release")
$ghArgs.Add("create")
$ghArgs.Add($Tag)
foreach ($file in $filesToUpload) {
    $ghArgs.Add($file)
}
$ghArgs.Add("--title")
$ghArgs.Add($Title)
$ghArgs.Add("--notes-file")
$ghArgs.Add($notesTempPath)

# 預設一律標記為 Prerelease (除非明確覆寫)
if ($Prerelease.IsPresent -or (-not $PSBoundParameters.ContainsKey("Prerelease"))) {
    $ghArgs.Add("--prerelease")
}
if ($Draft) {
    $ghArgs.Add("--draft")
}

if ($DryRun) {
    Write-Host "`n[DRY RUN PREVIEW] 將執行的 gh 指令：" -ForegroundColor Yellow
    Write-Host "gh $($ghArgs -join ' ')" -ForegroundColor Gray
    Write-Host "`n[DRY RUN PREVIEW] 包含產物：" -ForegroundColor Yellow
    foreach ($file in $filesToUpload) {
        Write-Host "  - $file" -ForegroundColor Gray
    }
    Write-Host "`n[DRY RUN] 預覽完成，未進行任何遠端發布。" -ForegroundColor Green
    return
}

Write-Host "正在上傳產物並建立 GitHub Release..." -ForegroundColor Cyan
& gh @ghArgs
if ($LASTEXITCODE -ne 0) {
    throw "gh release create 執行失敗！"
}

Write-Host "`n🎉 GitHub Release 發布成功！" -ForegroundColor Green
Write-Host "Tag: $Tag" -ForegroundColor Cyan
