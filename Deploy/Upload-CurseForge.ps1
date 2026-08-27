<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: Deploy\Upload-CurseForge.ps1

責任:
- 提供本機手動發布至 CurseForge 的專用工具。
- 支援 CLI 傳參模式（供自動化/腳本調用）與 詢問模式（對話式互動確認）。
- 自動偵測 Dist/ 目錄下最新產出的插件包與版本說明 .md。
- 安全讀取本機 Token，絕不寫入磁碟、不提交 Git、不上傳雲端。

邊界:
- 僅在本機執行，不使用任何未受權的外部第三方套件。
- 支援 -DryRun 模式進行全真負載驗證與連線測試，不產生實際發布。
#>
[CmdletBinding()]
param(
    [string]$ZipPath = "",
    [string]$ReleaseNotesPath = "",
    [string]$Changelog = "",
    [ValidateSet("alpha", "beta", "release")]
    [string]$ReleaseType = "",
    [string]$DisplayName = "",
    [int[]]$GameVersionIds = @(),
    [string]$ProjectId = "826042",
    [string]$ApiToken = "",
    [switch]$DryRun,
    [switch]$NonInteractive,
    [switch]$FetchGameVersions,
    [switch]$SetToken,
    [string]$SaveToken = ""
)

$ErrorActionPreference = "Stop"
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$distDir = Join-Path $projectRoot "Dist"
$governanceDir = Join-Path $projectRoot ".AI"
$changelogPath = Join-Path $projectRoot "EventAlertMod\changelog.txt"
$tocPath = Join-Path $projectRoot "EventAlertMod\EventAlertMod.toc"

# ---------------------------------------------------------------------------
# 輔助函式：路徑與資訊探索
# ---------------------------------------------------------------------------

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]@([char]'\', [char]'/'))
}

function Get-LatestDistPackage {
    if (-not (Test-Path -LiteralPath $distDir -PathType Container)) {
        return $null
    }
    $zips = @(Get-ChildItem -LiteralPath $distDir -Filter "EventAlertMod_*.zip" -File | Sort-Object LastWriteTime -Descending)
    if ($zips.Count -gt 0) {
        return $zips[0].FullName
    }
    return $null
}

function Get-TocVersionInfo {
    if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
        return "Retail 12.1.0"
    }
    $version = "Retail 12.1.0"
    foreach ($line in Get-Content -LiteralPath $tocPath -Encoding UTF8) {
        if ($line -match '^##\s+Version:\s*(.+)$') {
            $version = $Matches[1].Trim()
            break
        }
    }
    return $version
}

function Get-LatestReleaseTitle {
    if (Test-Path -LiteralPath $changelogPath -PathType Leaf) {
        foreach ($line in Get-Content -LiteralPath $changelogPath -Encoding UTF8) {
            if ($line -match '^--\s*\[([^\]]+)\]') {
                $rawTitle = $Matches[1].Trim()
                if ($rawTitle -match '^(?:Retail\s+)?([0-9]+\.[0-9]+\.[0-9]+(?:\s+(?:Alpha|Beta|Release)\s+[0-9.]+)?|[0-9]+\.[0-9]+\.[0-9]+|(?:Alpha|Beta)\s+[0-9.]+)') {
                    return $Matches[1].Trim()
                }
            }
        }
    }
    return $null
}

function Extract-LatestChangelogSection {
    if (-not (Test-Path -LiteralPath $changelogPath -PathType Leaf)) {
        return "## EventAlertMod Update`n`n- Performance and compatibility update."
    }

    $lines = Get-Content -LiteralPath $changelogPath -Encoding UTF8
    $sectionLines = [System.Collections.Generic.List[string]]::new()
    $inSection = $false

    foreach ($line in $lines) {
        if ($line -match '^--\s*\[(.+)\]') {
            if ($inSection) {
                break
            }
            $inSection = $true
            $sectionLines.Add("### " + $Matches[1].Trim())
            $sectionLines.Add("")
            continue
        }
        if ($inSection) {
            $trimmed = $line.Trim()
            if ($trimmed.StartsWith("-")) {
                $sectionLines.Add($line)
            } elseif ($trimmed.Length -gt 0) {
                $sectionLines.Add($line)
            }
        }
    }

    if ($sectionLines.Count -gt 0) {
        return ($sectionLines -join "`r`n")
    }
    return "## EventAlertMod Update`n`n- Performance and compatibility update."
}

function Get-LatestReleaseNotes {
    param([string]$TargetZipPath)

    # 1. 優先檢查同名 .md (例如 Dist/EventAlertMod_MN_20260827_213621.md)
    if (-not [string]::IsNullOrWhiteSpace($TargetZipPath)) {
        $candidateMd = [System.IO.Path]::ChangeExtension($TargetZipPath, ".md")
        if (Test-Path -LiteralPath $candidateMd -PathType Leaf) {
            return @{ Path = $candidateMd; Content = [System.IO.File]::ReadAllText($candidateMd, [System.Text.Encoding]::UTF8) }
        }
        $candidateReleaseNotes = [System.IO.Path]::ChangeExtension($TargetZipPath, ".release_notes.md")
        if (Test-Path -LiteralPath $candidateReleaseNotes -PathType Leaf) {
            return @{ Path = $candidateReleaseNotes; Content = [System.IO.File]::ReadAllText($candidateReleaseNotes, [System.Text.Encoding]::UTF8) }
        }
    }

    # 2. 檢查 Dist/ 內最新的 .md 檔案
    if (Test-Path -LiteralPath $distDir -PathType Container) {
        $distMds = @(Get-ChildItem -LiteralPath $distDir -Filter "*.md" -File | Sort-Object LastWriteTime -Descending)
        if ($distMds.Count -gt 0) {
            $md = $distMds[0]
            return @{ Path = $md.FullName; Content = [System.IO.File]::ReadAllText($md.FullName, [System.Text.Encoding]::UTF8) }
        }
    }

    # 3. 從 changelog.txt 動態解析最新版本區塊
    $parsed = Extract-LatestChangelogSection
    return @{ Path = "(動態由 changelog.txt 解析)"; Content = $parsed }
}

$secCandidates = @(
    (Join-Path $governanceDir "API_TOKEN.SEC"),
    (Join-Path $PSScriptRoot "API_TOKEN.SEC"),
    (Join-Path $projectRoot "API_TOKEN.SEC")
)

function Protect-EAMToken {
    param(
        [Parameter(Mandatory = $true)][string]$PlainToken,
        [string]$TargetSecFile = (Join-Path $governanceDir "API_TOKEN.SEC")
    )

    $secureString = ConvertTo-SecureString -String $PlainToken.Trim() -AsPlainText -Force
    $encrypted = ConvertFrom-SecureString -SecureString $secureString
    [System.IO.File]::WriteAllText($TargetSecFile, $encrypted, [System.Text.Encoding]::UTF8)
    Write-Host "`n✔ 已成功將 API Token 透過 Windows DPAPI 安全加密儲存至: $TargetSecFile" -ForegroundColor Green
    Write-Host "  (此檔案僅能在當前 Windows 登入帳號下解密，且已列入 .gitignore，絕不上傳或封裝)" -ForegroundColor DarkGray
}

function Unprotect-EAMToken {
    foreach ($candidate in $secCandidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            try {
                $encrypted = [System.IO.File]::ReadAllText($candidate, [System.Text.Encoding]::UTF8).Trim()
                if (-not [string]::IsNullOrWhiteSpace($encrypted)) {
                    $secureString = ConvertTo-SecureString -String $encrypted
                    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
                    $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
                    if (-not [string]::IsNullOrWhiteSpace($plain)) {
                        return @{ Token = $plain.Trim(); Source = "DPAPI 加密檔 (API_TOKEN.SEC)" }
                    }
                }
            } catch {
                Write-Warning "無法解密 $candidate (可能由其他 Windows 帳號建立)：$($_.Exception.Message)"
            }
        }
    }
    return $null
}

function Get-EffectiveApiToken {
    param([string]$ExplicitToken)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitToken)) {
        return @{ Token = $ExplicitToken.Trim(); Source = "CLI 參數 (-ApiToken)" }
    }

    # 1. 優先從 Windows DPAPI 加密的 API_TOKEN.SEC 解密
    $secResult = Unprotect-EAMToken
    if ($secResult) {
        return $secResult
    }

    # 2. 檢查環境變數
    if (-not [string]::IsNullOrWhiteSpace($env:CF_API_TOKEN)) {
        return @{ Token = $env:CF_API_TOKEN.Trim(); Source = "環境變數 (\$env:CF_API_TOKEN)" }
    }
    if (-not [string]::IsNullOrWhiteSpace($env:CURSEFORGE_TOKEN)) {
        return @{ Token = $env:CURSEFORGE_TOKEN.Trim(); Source = "環境變數 (\$env:CURSEFORGE_TOKEN)" }
    }

    # 3. 檢查本機私有設定檔 .AI/local_secrets.json (若存在)
    $localSecretsFile = Join-Path $governanceDir "local_secrets.json"
    if (Test-Path -LiteralPath $localSecretsFile -PathType Leaf) {
        try {
            $json = Get-Content -LiteralPath $localSecretsFile -Encoding UTF8 -Raw | ConvertFrom-Json
            if ($json.CF_API_TOKEN) {
                return @{ Token = [string]($json.CF_API_TOKEN).Trim(); Source = ".AI/local_secrets.json" }
            }
        } catch {
            # 忽視解析錯誤
        }
    }

    return $null
}

# ---------------------------------------------------------------------------
# 輔助函式：CurseForge API 通訊
# ---------------------------------------------------------------------------

function Get-CurseForgeGameVersions {
    param([string]$Token)

    $url = "https://wow.curseforge.com/api/game/versions"

    # 1. 優先使用 curl.exe (Windows 內建，且具備最穩定的 WAF 白名單)
    $curlPath = Get-Command "curl.exe" -ErrorAction SilentlyContinue
    if ($curlPath) {
        try {
            $headers = @("-H", "User-Agent: BigWigs/Packager")
            if (-not [string]::IsNullOrWhiteSpace($Token)) {
                $headers += @("-H", "X-Api-Token: $Token")
            }
            $curlOut = & curl.exe -s --max-time 10 $headers $url
            if (-not [string]::IsNullOrWhiteSpace($curlOut)) {
                $versions = $curlOut | ConvertFrom-Json
                return $versions
            }
        } catch {
            # 忽視錯誤，轉至 HttpClient
        }
    }

    # 2. 備援：HttpClient (明確帶上 User-Agent)
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [System.TimeSpan]::FromSeconds(15)

    try {
        $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $url)
        $request.Headers.Add("User-Agent", "BigWigs/Packager")
        if (-not [string]::IsNullOrWhiteSpace($Token)) {
            $request.Headers.Add("X-Api-Token", $Token)
        }
        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        if ($response.IsSuccessStatusCode) {
            $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $versions = $body | ConvertFrom-Json
            return $versions
        }
    } catch {
        Write-Warning "無法連線至 CurseForge 遊戲版本 API：$($_.Exception.Message)"
    } finally {
        $client.Dispose()
        $handler.Dispose()
    }
    return $null
}

function Invoke-CurseForgeUpload {
    param(
        [Parameter(Mandatory = $true)][string]$ZipFilePath,
        [Parameter(Mandatory = $true)][string]$Project,
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][hashtable]$Metadata,
        [switch]$IsDryRun
    )

    $url = "https://wow.curseforge.com/api/projects/$Project/upload-file"
    $metadataJson = $Metadata | ConvertTo-Json -Depth 6 -Compress

    if ($IsDryRun) {
        Write-Host "`n=== [DRY-RUN 模擬發布模式] ===" -ForegroundColor Cyan
        Write-Host "目標網址: $url" -ForegroundColor DarkGray
        Write-Host "專案 ID : $Project" -ForegroundColor DarkGray
        Write-Host "認證標頭: X-Api-Token: (長度: $($Token.Length) 字元, 已遮蔽)" -ForegroundColor DarkGray
        Write-Host "上傳檔案: $ZipFilePath ($( [Math]::Round((Get-Item -LiteralPath $ZipFilePath).Length / 1KB, 2) ) KB)" -ForegroundColor DarkGray
        Write-Host "發布資料 (Metadata JSON):" -ForegroundColor DarkGray
        Write-Host ($Metadata | ConvertTo-Json -Depth 6) -ForegroundColor Yellow
        Write-Host "`n✔ Dry-Run 模擬完成：所有參數與封裝校驗合法，未實際送出網路請求。" -ForegroundColor Green
        return [pscustomobject]@{
            success = $true
            id = 0
            isDryRun = $true
        }
    }

    Write-Host "`n正在上傳插件包至 CurseForge..." -ForegroundColor Cyan

    # 1. 優先使用 Windows 內建 curl.exe (最穩固支援大檔串流與 Cloudflare WAF 白名單)
    $curlCmd = Get-Command "curl.exe" -ErrorAction SilentlyContinue
    if ($curlCmd) {
        try {
            $metaArgs = "metadata=$metadataJson;type=application/json"
            $fileArgs = "file=@$ZipFilePath;type=application/zip"

            $curlArgs = @(
                "-s",
                "-S",
                "--max-time", "180",
                "-H", "User-Agent: BigWigs/Packager",
                "-H", "X-Api-Token: $Token",
                "-F", $metaArgs,
                "-F", $fileArgs,
                $url
            )

            $curlResponse = & curl.exe @curlArgs
            if (-not [string]::IsNullOrWhiteSpace($curlResponse)) {
                try {
                    $jsonRes = $curlResponse | ConvertFrom-Json
                    if ($jsonRes.id) {
                        Write-Host "`n🎉 上傳成功！CurseForge 檔案 ID: $($jsonRes.id)" -ForegroundColor Green
                        Write-Host "專案頁面: https://www.curseforge.com/wow/addons/eventalertmod" -ForegroundColor Cyan
                        return [pscustomobject]@{
                            success = $true
                            id = $jsonRes.id
                            body = $curlResponse
                        }
                    } elseif ($jsonRes.errorMessage) {
                        Write-Host "`n❌ 上傳失敗 (CurseForge API 回應)：" -ForegroundColor Red
                        Write-Host "$($jsonRes.errorMessage) (代碼: $($jsonRes.errorCode))" -ForegroundColor Yellow
                        return [pscustomobject]@{
                            success = $false
                            statusCode = 400
                            error = $curlResponse
                        }
                    }
                } catch {
                    Write-Host "`n❌ 上傳失敗 (回應非預期格式)：" -ForegroundColor Red
                    Write-Host $curlResponse -ForegroundColor Yellow
                    return [pscustomobject]@{
                        success = $false
                        statusCode = 500
                        error = $curlResponse
                    }
                }
            }
        } catch {
            Write-Warning "curl.exe 上傳嘗試失敗，切換至 .NET HttpClient 備援通道：$($_.Exception.Message)"
        }
    }

    # 2. 備援通道：.NET HttpClient (帶有完整 User-Agent 與 Content-Type)
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [System.TimeSpan]::FromMinutes(3)

    $form = [System.Net.Http.MultipartFormDataContent]::new()
    $fileStream = [System.IO.File]::OpenRead($ZipFilePath)
    $fileContent = [System.Net.Http.StreamContent]::new($fileStream)
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/zip")

    $metadataContent = [System.Net.Http.StringContent]::new($metadataJson, [System.Text.Encoding]::UTF8, "application/json")

    $form.Add($metadataContent, "metadata")
    $form.Add($fileContent, "file", [System.IO.Path]::GetFileName($ZipFilePath))

    try {
        $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $url)
        $request.Headers.Add("User-Agent", "BigWigs/Packager")
        $request.Headers.Add("X-Api-Token", $Token)
        $request.Content = $form

        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

        if ($response.IsSuccessStatusCode) {
            $resultJson = $responseBody | ConvertFrom-Json
            Write-Host "`n🎉 上傳成功！CurseForge 檔案 ID: $($resultJson.id)" -ForegroundColor Green
            Write-Host "專案頁面: https://www.curseforge.com/wow/addons/eventalertmod" -ForegroundColor Cyan
            return [pscustomobject]@{
                success = $true
                id = $resultJson.id
                body = $responseBody
            }
        } else {
            $statusCode = [int]$response.StatusCode
            Write-Host "`n❌ 上傳失敗 (HTTP $statusCode $response.ReasonPhrase)：" -ForegroundColor Red
            Write-Host $responseBody -ForegroundColor Yellow
            if ($statusCode -eq 401 -or $statusCode -eq 403) {
                Write-Host "提示：請確認您的 CurseForge API Token 是否有效且具備此專案的發布權限。" -ForegroundColor Yellow
            }
            return [pscustomobject]@{
                success = $false
                statusCode = $statusCode
                error = $responseBody
            }
        }
    } finally {
        $fileStream.Dispose()
        $form.Dispose()
        $client.Dispose()
        $handler.Dispose()
    }
}

# ---------------------------------------------------------------------------
# 主流程：CLI 模式 與 詢問模式 判斷
# ---------------------------------------------------------------------------

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  EventAlertMod CurseForge Local Upload Tool" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 0. 快速設定與加密儲存 API Token
if ($SetToken -or (-not [string]::IsNullOrWhiteSpace($SaveToken))) {
    $tokenToSave = $SaveToken
    if ([string]::IsNullOrWhiteSpace($tokenToSave)) {
        Write-Host "`n=== [CurseForge API Token Windows DPAPI 加密設定] ===" -ForegroundColor Cyan
        Write-Host "請輸入欲加密儲存的 CurseForge API Token (輸入時隱藏)：" -ForegroundColor Yellow
        $secInput = Read-Host -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secInput)
        $tokenToSave = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
    if ([string]::IsNullOrWhiteSpace($tokenToSave)) {
        throw "未輸入任何 Token，取消設定。"
    }
    Protect-EAMToken -PlainToken $tokenToSave
    return
}

# 1. 探索 ZIP 檔案
if ([string]::IsNullOrWhiteSpace($ZipPath)) {
    $foundZip = Get-LatestDistPackage
    if ($foundZip) {
        $ZipPath = $foundZip
    }
}

# 2. 探索版本說明
$discoveredNotes = Get-LatestReleaseNotes -TargetZipPath $ZipPath
if ([string]::IsNullOrWhiteSpace($Changelog)) {
    if (-not [string]::IsNullOrWhiteSpace($ReleaseNotesPath) -and (Test-Path -LiteralPath $ReleaseNotesPath -PathType Leaf)) {
        $Changelog = [System.IO.File]::ReadAllText($ReleaseNotesPath, [System.Text.Encoding]::UTF8)
    } else {
        $Changelog = $discoveredNotes.Content
        $ReleaseNotesPath = $discoveredNotes.Path
    }
}

# 3. 預設值推導
$releaseTitle = Get-LatestReleaseTitle
if ([string]::IsNullOrWhiteSpace($DisplayName)) {
    if ($releaseTitle) {
        $DisplayName = "EventAlertMod " + $releaseTitle
    } else {
        $tocVer = Get-TocVersionInfo
        $cleanVer = $tocVer -replace '^EventAlertMod_', ''
        $DisplayName = "EventAlertMod " + $cleanVer
    }
}
if ([string]::IsNullOrWhiteSpace($ReleaseType)) {
    if ($DisplayName -match '(?i)alpha') {
        $ReleaseType = "alpha"
    } elseif ($DisplayName -match '(?i)beta') {
        $ReleaseType = "beta"
    } else {
        $ReleaseType = "release"
    }
}

# 預設遊戲版本 (12.1.0: 16519)
if ($GameVersionIds.Count -eq 0) {
    # 預設 12.1.0 官方版本 ID: 16519
    $GameVersionIds = @(16519) # 12.1.0
}

# 4. 判斷是否進入互動詢問模式
$isInteractive = (-not $NonInteractive) -and ([string]::IsNullOrWhiteSpace($PSBoundParameters["ZipPath"]) -or [string]::IsNullOrWhiteSpace($PSBoundParameters["ApiToken"]))

if ($isInteractive) {
    Write-Host "`n[ 模式: 互動詢問確認模式 (Interactive Mode) ]" -ForegroundColor Green
    Write-Host "提示：您的 API Token 僅留存在本機記憶體中，絕不上傳或存檔。`n" -ForegroundColor DarkGray

    # --- 步驟 1: 確認 ZIP 檔案 ---
    Write-Host "1. 發布套件 (ZIP Archive)：" -ForegroundColor Yellow
    if (Test-Path -LiteralPath $ZipPath -PathType Leaf) {
        $fileSize = [Math]::Round((Get-Item -LiteralPath $ZipPath).Length / 1KB, 2)
        Write-Host "   預設最新檔案: $ZipPath ($fileSize KB)" -ForegroundColor White
        $userZip = Read-Host "   請按 [Enter] 使用預設檔案，或輸入自訂 ZIP 路徑"
        if (-not [string]::IsNullOrWhiteSpace($userZip)) {
            $ZipPath = $userZip.Trim('"')
        }
    } else {
        $ZipPath = Read-Host "   請輸入欲上傳的 ZIP 檔案路徑"
        $ZipPath = $ZipPath.Trim('"')
    }

    if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
        throw "指定的 ZIP 檔案不存在：$ZipPath"
    }

    # --- 步驟 2: 確認發布類型 ---
    Write-Host "`n2. 發布通道類型 (Release Type)：" -ForegroundColor Yellow
    Write-Host "   [1] alpha (測試版 / 預設)" -ForegroundColor White
    Write-Host "   [2] beta (公開測試版)" -ForegroundColor White
    Write-Host "   [3] release (正式穩定版)" -ForegroundColor White
    $typeChoice = Read-Host "   請選擇發布通道 [預設: 1]"
    switch ($typeChoice) {
        "2" { $ReleaseType = "beta" }
        "3" { $ReleaseType = "release" }
        default { $ReleaseType = "alpha" }
    }

    # --- 步驟 3: 確認發布名稱 ---
    Write-Host "`n3. 發布顯示標題 (Display Name)：" -ForegroundColor Yellow
    Write-Host "   預設名稱: $DisplayName" -ForegroundColor White
    $userDisplayName = Read-Host "   請按 [Enter] 使用預設名稱，或輸入自訂名稱"
    if (-not [string]::IsNullOrWhiteSpace($userDisplayName)) {
        $DisplayName = $userDisplayName.Trim()
    }

    # --- 步驟 4: 確認版本說明 (Changelog) ---
    Write-Host "`n4. 版本更新說明 (Release Notes / Changelog)：" -ForegroundColor Yellow
    Write-Host "   來源檔案: $ReleaseNotesPath" -ForegroundColor DarkGray
    Write-Host "   --- [預覽前 6 行] ---" -ForegroundColor DarkGray
    $previewLines = ($Changelog -split "`r?`n") | Select-Object -First 6
    foreach ($pLine in $previewLines) {
        Write-Host "   $pLine" -ForegroundColor Gray
    }
    Write-Host "   --------------------" -ForegroundColor DarkGray
    Write-Host "   [1] 使用目前預設的說明 (Markdown)" -ForegroundColor White
    Write-Host "   [2] 指定其他 .md 檔案路徑" -ForegroundColor White
    $notesChoice = Read-Host "   請選擇 [預設: 1]"
    if ($notesChoice -eq "2") {
        $customNotesPath = Read-Host "   請輸入 .md 檔案路徑"
        $customNotesPath = $customNotesPath.Trim('"')
        if (Test-Path -LiteralPath $customNotesPath -PathType Leaf) {
            $Changelog = [System.IO.File]::ReadAllText($customNotesPath, [System.Text.Encoding]::UTF8)
            $ReleaseNotesPath = $customNotesPath
            Write-Host "   ✔ 已載入自訂版本說明。" -ForegroundColor Green
        } else {
            Write-Warning "檔案不存在，維持原預設說明。"
        }
    }

    # --- 步驟 5: 確認 API Token ---
    $tokenInfo = Get-EffectiveApiToken -ExplicitToken $ApiToken
    if (-not $tokenInfo) {
        Write-Host "`n5. CurseForge API Token 驗證：" -ForegroundColor Yellow
        Write-Host "   未在 DPAPI 加密檔 (API_TOKEN.SEC)、環境變數或本機設定中偵測到 Token。" -ForegroundColor DarkYellow
        $secureInput = Read-Host "   請輸入您的 CurseForge API Token (輸入時隱藏)" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureInput)
        $resolvedToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        if (-not [string]::IsNullOrWhiteSpace($resolvedToken)) {
            $saveChoice = Read-Host "   是否將此 Token 加密保存為本機 API_TOKEN.SEC (Windows DPAPI 雙重防護，日後免再輸入)？ [Y/N] [預設: Y]"
            if ($saveChoice -ne "N" -and $saveChoice -ne "n") {
                Protect-EAMToken -PlainToken $resolvedToken
            }
        }
    } else {
        $resolvedToken = $tokenInfo.Token
        Write-Host "`n5. CurseForge API Token 驗證：" -ForegroundColor Yellow
        Write-Host "   ✔ 已成功從 $($tokenInfo.Source) 載入有效 Token (已遮蔽保護)。" -ForegroundColor Green
    }

    if ([string]::IsNullOrWhiteSpace($resolvedToken)) {
        throw "未提供有效的 API Token，無法進行上傳。"
    }

    # --- 步驟 6: 確認遊戲版本 ---
    Write-Host "`n6. 魔獸世界版本 (Game Versions)：" -ForegroundColor Yellow
    Write-Host "   預設目標版本 ID: $($GameVersionIds -join ', ') (Retail 12.1.0)" -ForegroundColor White

    # --- 最終摘要卡片與確認 ---
    Write-Host "`n================ [ 發布資訊摘要確認 ] ================" -ForegroundColor Cyan
    Write-Host "  專案 ID   : $ProjectId" -ForegroundColor White
    Write-Host "  發布檔案 : $ZipPath" -ForegroundColor White
    Write-Host "  檔案大小 : $( [Math]::Round((Get-Item -LiteralPath $ZipPath).Length / 1KB, 2) ) KB" -ForegroundColor White
    Write-Host "  發布通道 : $ReleaseType" -ForegroundColor ($ReleaseType -eq "release" ? "Green" : "Yellow")
    Write-Host "  顯示標題 : $DisplayName" -ForegroundColor White
    Write-Host "  版本說明 : $($Changelog.Length) 字元 ($ReleaseNotesPath)" -ForegroundColor White
    Write-Host "  目標版本 : $($GameVersionIds -join ', ')" -ForegroundColor White
    Write-Host "========================================================" -ForegroundColor Cyan

    $confirm = Read-Host "`n確認執行發布？ [Y: 確定上傳 / D: 僅執行 Dry-Run 模擬 / N: 取消退出]"
    if ($confirm -eq "D" -or $confirm -eq "d") {
        $DryRun = $true
    } elseif ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "已取消發布作業。" -ForegroundColor Yellow
        return
    }
} else {
    # CLI 模式下的 Token 取得
    $tokenInfo = Get-EffectiveApiToken -ExplicitToken $ApiToken
    if (-not $tokenInfo) {
        throw "CLI 模式缺少 API Token。請傳入 -ApiToken、設定 \$env:CF_API_TOKEN 或執行 .\Deploy\Upload-CurseForge.ps1 -SetToken 加密保存。"
    }
    $resolvedToken = $tokenInfo.Token
    if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
        throw "指定的 ZIP 檔案不存在：$ZipPath"
    }
}

# ---------------------------------------------------------------------------
# 執行上傳
# ---------------------------------------------------------------------------

$metadataPayload = @{
    changelog = $Changelog
    changelogType = "markdown"
    displayName = $DisplayName
    gameVersions = $GameVersionIds
    releaseType = $ReleaseType
}

$result = Invoke-CurseForgeUpload `
    -ZipFilePath $ZipPath `
    -Project $ProjectId `
    -Token $resolvedToken `
    -Metadata $metadataPayload `
    -IsDryRun:$DryRun

if (-not $result.success) {
    exit 1
}
