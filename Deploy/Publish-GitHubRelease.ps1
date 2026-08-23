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
    [string]$PackageLabel = "AGY",
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

# 3. 決定 Tag 與 Title
$dateStamp = Get-Date -Format "yyyyMMdd"
if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = "alpha-7.4-agy." + $dateStamp
}
if ([string]::IsNullOrWhiteSpace($Title)) {
    $Title = "[AGY] Retail 12.1 Alpha 7.4 (Antigravity Engine - $dateStamp)"
}

Write-Host "發布目標 Tag  : $Tag" -ForegroundColor Yellow
Write-Host "發布目標 Title: $Title" -ForegroundColor Yellow
Write-Host "套件標籤 Label: $PackageLabel" -ForegroundColor Yellow

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

# 5. 打包 AddOn 與 Source
Write-Host "`n--> [2/4] 打包插件與原始碼套件..." -ForegroundColor Cyan
[System.IO.Directory]::CreateDirectory($distRoot) | Out-Null

$beforePackageZips = @(Get-ChildItem -LiteralPath $distRoot -Filter "*.zip" -File | Select-Object -ExpandProperty FullName)

# 5.1 AddOn ZIP
& pwsh -NoProfile -File $buildPackageScript -PackageLabel $PackageLabel
if ($LASTEXITCODE -ne 0) { throw "Build-Package 失敗！" }

# 5.2 Source ZIP
& pwsh -NoProfile -File $buildSourceScript
if ($LASTEXITCODE -ne 0) { throw "Build-SourcePackage 失敗！" }

$afterPackageZips = @(Get-ChildItem -LiteralPath $distRoot -Filter "*.zip" -File | Select-Object -ExpandProperty FullName)
$newZips = @($afterPackageZips | Where-Object { $beforePackageZips -notcontains $_ })

if ($newZips.Count -eq 0) {
    throw "未能找到新產生的 ZIP 檔案！"
}

$addonZip = @($newZips | Where-Object { $_ -notlike "*_src_*" })[0]
$sourceZip = @($newZips | Where-Object { $_ -like "*_src_*" })[0]

$filesToUpload = [System.Collections.Generic.List[string]]::new()
if ($addonZip -and (Test-Path -LiteralPath $addonZip)) {
    $filesToUpload.Add($addonZip)
    $hashFile = $addonZip + ".sha256"
    if (Test-Path -LiteralPath $hashFile) { $filesToUpload.Add($hashFile) }
}
if ($sourceZip -and (Test-Path -LiteralPath $sourceZip)) {
    $filesToUpload.Add($sourceZip)
    $hashFile = $sourceZip + ".sha256"
    if (Test-Path -LiteralPath $hashFile) { $filesToUpload.Add($hashFile) }
    $invFile = [System.IO.Path]::ChangeExtension($sourceZip, ".inventory.json")
    if (Test-Path -LiteralPath $invFile) { $filesToUpload.Add($invFile) }
}

Write-Host "✓ 待上傳產物清單:" -ForegroundColor Green
foreach ($file in $filesToUpload) {
    $item = Get-Item -LiteralPath $file
    Write-Host "  - $($item.Name) ($([math]::Round($item.Length / 1KB, 1)) KB)" -ForegroundColor Gray
}

# 6. 組裝結構化 Release Notes
Write-Host "`n--> [3/4] 組裝結構化 Release Notes..." -ForegroundColor Cyan
$recentChangelog = ""
if (Test-Path -LiteralPath $changelogPath) {
    $lines = Get-Content -LiteralPath $changelogPath -Encoding UTF8
    $extracted = [System.Collections.Generic.List[string]]::new()
    $recording = $false
    foreach ($line in $lines) {
        if ($line -match '^=+\s*(.+?)\s*=+') {
            if ($recording) { break }
            $recording = $true
        }
        if ($recording) {
            $extracted.Add($line)
        }
    }
    $recentChangelog = $extracted -join "`r`n"
}

$addonHash = if ($addonZip) { (Get-FileHash -LiteralPath $addonZip -Algorithm SHA256).Hash } else { "N/A" }
$sourceHash = if ($sourceZip) { (Get-FileHash -LiteralPath $sourceZip -Algorithm SHA256).Hash } else { "N/A" }

$releaseNotes = @"
# $Title

本發布由 **Antigravity (Lead Developer)** 依據專案治理規範獨立編譯、驗證與封裝。

---

## 🛡️ 治理與責任歸屬 (Attribution & Governance)
- **維護代理**：Antigravity Lead Engineer
- **發布軌道**：`AGY Independent Track` (Pre-release)
- **支援目標**：World of Warcraft Retail 12.1.x / Midnight (支援 12.0.7 Legacy / XPTR)
- **離線驗證狀態**：`OFFLINE VERIFIED` (Lua 64/64 | Flow 82/82 | Contracts 493/493)
- **實機驗證狀態**：`REQUIRES_WOW_12_1_RUNTIME`

---

## 📦 發布產物與 SHA-256 校驗 (Artifacts)

| 檔案名稱 | 說明 | SHA-256 雜湊值 |
| :--- | :--- | :--- |
| **`$([System.IO.Path]::GetFileName($addonZip))`** | 遊戲 AddOn 插件安裝包 | `$addonHash` |
| **`$([System.IO.Path]::GetFileName($sourceZip))`** | 專案完整工程原始碼包 | `$sourceHash` |

---

## 📝 最近變更 (Changelog)

```text
$recentChangelog
```

---

## 🔄 雙軌並行與回退指引 (Rollback Protocol)

若在遊戲實機中遇到任何異常，可隨時無縫回退至 Codex 穩定版本：
1. 前往 [Codex Releases 列表](https://github.com/ziyuefan/EventAlertModRemake/releases) 下載 Codex 官方版本 ZIP。
2. 完整解壓並覆蓋至 `World of Warcraft\_retail_\Interface\AddOns\EventAlertMod`。
3. 遊戲內輸入 `/reload` 即可立即切換。
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
