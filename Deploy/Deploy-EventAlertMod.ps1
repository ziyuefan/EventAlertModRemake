<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: Deploy\Deploy-EventAlertMod.ps1

責任:
- 以互動選單顯示 Retail、PTR、XPTR 與即時 ProductVersion。
- 將 EventAlertMod 實體來源部署到所選客戶端的 Interface\AddOns\EventAlertMod。
- 在任何寫入前阻擋 Reparse Point、錯誤路徑與來源不完整；部署不檢查 WoW 程序是否執行。

邊界:
- 絕不刪除、解除、覆蓋或跟隨 SymbolicLink／Junction。
- WTF 僅由明確的備份／還原動作讀寫；不啟動或關閉 WoW、不修改 PATH。
- 只有使用者明確選擇部署且所有前檢通過時才寫入遊戲目錄。
#>
[CmdletBinding()]
param(
    [ValidateSet("Menu", "Status", "Retail", "PTR", "XPTR", "All", "Backup", "Restore")]
    [string]$Action = "Menu",
    [string]$WowRoot = "",
    [switch]$DryRun,
    [ValidateSet("Retail", "PTR", "XPTR", "All")]
    [string]$Channel = "",
    [string]$WtfBackupPath = ""
)

$ErrorActionPreference = "Stop"
$utf8 = [System.Text.UTF8Encoding]::new($false)
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$addonRoot = Join-Path $projectRoot "EventAlertMod"
$governanceRoot = Join-Path $projectRoot ".AI"
$configPath = Join-Path $PSScriptRoot "DeploymentTargets.json"
$buildScript = Join-Path $PSScriptRoot "Build-Package.ps1"
$sourceBuildScript = Join-Path $PSScriptRoot "Build-SourcePackage.ps1"
$uploadCurseForgeScript = Join-Path $PSScriptRoot "Upload-CurseForge.ps1"

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]@([char]'\', [char]'/'))
}

function Assert-ExactChildPath {
    param(
        [Parameter(Mandatory = $true)][string]$Parent,
        [Parameter(Mandatory = $true)][string]$Child
    )

    $parentPath = Get-NormalizedPath -Path $Parent
    $childPath = Get-NormalizedPath -Path $Child
    if (-not $childPath.StartsWith($parentPath + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "路徑越界：$childPath"
    }
}

function Get-RegistryWowCandidates {
    $items = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $views = @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32)
    $hives = @([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryHive]::CurrentUser)
    $locations = @("SOFTWARE\Blizzard Entertainment\World of Warcraft", "SOFTWARE\Blizzard Entertainment\Battle.net\Launch Options\WoW", "SOFTWARE\Blizzard Entertainment\Battle.net\Launch Options\World of Warcraft")
    foreach($hive in $hives){ foreach($view in $views){
        $base=$null
        try { $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey($hive,$view)
            foreach($location in $locations){
                $key=$null
                try { $key=$base.OpenSubKey($location); if($null -eq $key){continue}
                    $keys=@($key)
                    if($location -like "*Launch Options\*"){ foreach($sub in $key.GetSubKeyNames()){ $subKey=$key.OpenSubKey($sub); if($null -ne $subKey){$keys += $subKey} } }
                    foreach($candidateKey in $keys){ foreach($valueName in @("InstallPath","InstallLocation","GamePath","Path")){
                        $value=$candidateKey.GetValue($valueName,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                        if($value -is [string] -and -not [string]::IsNullOrWhiteSpace($value)){ $candidate=Get-NormalizedPath -Path $value.Trim().Trim('"'); if((Test-Path -LiteralPath $candidate -PathType Container) -and $seen.Add($candidate)){[void]$items.Add([pscustomobject]@{Source="${hive}/${view}/${location}:$valueName";Path=$candidate})} }
                    } }
                    foreach($candidateKey in $keys){if($candidateKey -ne $key){$candidateKey.Dispose()}}
                } catch { continue } finally {if($null -ne $key){$key.Dispose()}}
            }
        } catch { continue } finally {if($null -ne $base){$base.Dispose()}}
    }}
    return @($items)
}

function Resolve-WowRootPath {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Source)
    $normalized=Get-NormalizedPath -Path $Path.Trim().Trim('"')
    if(-not (Test-Path -LiteralPath $normalized -PathType Container)){throw "WoW 根目錄不存在：$normalized（來源：$Source）"}
    return [pscustomobject]@{Path=$normalized;Source=$Source}
}
function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$FullPath
    )

    $base = Get-NormalizedPath -Path $BasePath
    $full = Get-NormalizedPath -Path $FullPath
    Assert-ExactChildPath -Parent $base -Child $full
    return $full.Substring($base.Length + 1).Replace("\", "/")
}

function Test-AddonSource {
    if (-not (Test-Path -LiteralPath $addonRoot -PathType Container)) {
        throw "插件來源不存在：$addonRoot"
    }
    $sourceItem = Get-Item -LiteralPath $addonRoot -Force
    if (($sourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "插件來源不得為 Reparse Point：$addonRoot"
    }
    $nestedReparse = @(Get-ChildItem -LiteralPath $addonRoot -Recurse -Force | Where-Object {
        ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    })
    if ($nestedReparse.Count -gt 0) {
        throw "插件來源內含 Reparse Point：$($nestedReparse[0].FullName)"
    }
    foreach ($required in @(
        "EventAlertMod.toc",
        "Managers\AlertManager.lua",
        "Managers\AuraRuleCompiler.lua",
        "README.md",
        "changelog.txt"
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $addonRoot $required) -PathType Leaf)) {
            throw "插件來源缺少必要檔案：$required"
        }
    }
    foreach ($document in @("README.md", "changelog.txt")) {
        $publicPath = Join-Path $projectRoot $document
        $addonPath = Join-Path $addonRoot $document
        if (-not (Test-Path -LiteralPath $publicPath -PathType Leaf)) {
            throw "根目錄缺少公開文件：$publicPath"
        }
        if (-not [string]::Equals(
            (Get-FileHash -LiteralPath $publicPath -Algorithm SHA256).Hash,
            (Get-FileHash -LiteralPath $addonPath -Algorithm SHA256).Hash,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw "公開文件與插件副本不同步：$document"
        }
    }
}

function Get-SourceInventory {
    return @(Get-ChildItem -LiteralPath $addonRoot -Recurse -Force -File | ForEach-Object {
        Get-RelativePath -BasePath $addonRoot -FullPath $_.FullName
    } | Sort-Object)
}

function Test-InventoryMatch {
    param([Parameter(Mandatory = $true)][string]$TargetRoot)

    Assert-PhysicalDirectoryTree -Path $TargetRoot
    $sourceFiles = @(Get-SourceInventory)
    $targetFiles = @(Get-ChildItem -LiteralPath $TargetRoot -Recurse -Force -File | ForEach-Object {
        Get-RelativePath -BasePath $TargetRoot -FullPath $_.FullName
    } | Sort-Object)
    return @(Compare-Object -ReferenceObject $sourceFiles -DifferenceObject $targetFiles).Count -eq 0
}

function Get-LinkTargetText {
    param([Parameter(Mandatory = $true)][System.IO.FileSystemInfo]$Item)

    $targets = @($Item.Target)
    if ($targets.Count -eq 0) {
        return ""
    }
    return [string]$targets[0]
}

function Get-ExistingReparseItem {
    param(
        [Parameter(Mandatory = $true)][string]$CandidatePath,
        [Parameter(Mandatory = $true)][string]$StopAtPath
    )

    $current = Get-NormalizedPath -Path $CandidatePath
    $stop = Get-NormalizedPath -Path $StopAtPath
    while ($true) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                return $item
            }
        }
        if ([string]::Equals($current, $stop, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $null
        }
        $parentInfo = [System.IO.DirectoryInfo]::new($current).Parent
        $parent = if ($null -ne $parentInfo) { $parentInfo.FullName } else { "" }
        if ([string]::IsNullOrWhiteSpace($parent) -or [string]::Equals($parent, $current, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $null
        }
        $current = Get-NormalizedPath -Path $parent
    }
}

function Assert-PhysicalDirectoryTree {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "實體資料夾不存在：$Path"
    }
    $rootItem = Get-Item -LiteralPath $Path -Force
    if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "資料夾是 Reparse Point，拒絕存取：$Path"
    }
    foreach ($entry in Get-ChildItem -LiteralPath $Path -Recurse -Force) {
        if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "資料夾樹含 Reparse Point，拒絕存取：$($entry.FullName)"
        }
    }
}

function Get-ClientState {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Definition,
        [Parameter(Mandatory = $true)][string]$RootPath
    )

    $versionRoot = Join-Path $RootPath ([string]$Definition.directory)
    $executablePath = Join-Path $versionRoot ([string]$Definition.executable)
    $addonsRoot = Join-Path $versionRoot "Interface\AddOns"
    $targetPath = Join-Path $addonsRoot "EventAlertMod"
    $rawProductVersion = ""
    $productVersion = ""
    $patch = ""
    $available = Test-Path -LiteralPath $versionRoot -PathType Container
    if (Test-Path -LiteralPath $executablePath -PathType Leaf) {
        $executable = Get-Item -LiteralPath $executablePath
        $rawProductVersion = [string]$executable.VersionInfo.ProductVersion
        $productVersion = $rawProductVersion
        if ($rawProductVersion -match '(?<patch>[0-9]+\.[0-9]+\.[0-9]+)\.(?<build>[0-9]+)') {
            $patch = $Matches.patch
            $productVersion = $Matches.patch + "." + $Matches.build
        }
    }

    $targetKind = "missing"
    $linkType = ""
    $linkTarget = ""
    $reparseItem = Get-ExistingReparseItem $targetPath $RootPath
    if ($null -ne $reparseItem) {
        $targetKind = "reparse"
        $linkType = [string]$reparseItem.LinkType
        $linkTarget = Get-LinkTargetText -Item $reparseItem
    } elseif (Test-Path -LiteralPath $targetPath) {
        $target = Get-Item -LiteralPath $targetPath -Force
        if ($target.PSIsContainer) {
            $targetKind = "physical"
        } else {
            $targetKind = "file"
        }
    }

    $menuLabel = if ([bool]$Definition.showVersionInMenu) {
        $versionLabel = if ($productVersion) { $productVersion } else { "版本未知" }
        "$($Definition.displayName)（$versionLabel）"
    } else {
        "$($Definition.displayName)（$($Definition.roleLabel)）"
    }

    return [pscustomobject][ordered]@{
        key = [string]$Definition.key
        directory = [string]$Definition.directory
        displayName = [string]$Definition.displayName
        roleLabel = [string]$Definition.roleLabel
        menuLabel = $menuLabel
        versionRoot = $versionRoot
        executablePath = $executablePath
        productVersion = $productVersion
        patch = $patch
        available = $available
        addonsRoot = $addonsRoot
        targetPath = $targetPath
        targetKind = $targetKind
        linkType = $linkType
        linkTarget = $linkTarget
    }
}

function Get-ClientStates {
    param(
        [Parameter(Mandatory = $true)][object[]]$Definitions,
        [Parameter(Mandatory = $true)][string]$RootPath
    )

    return @($Definitions | ForEach-Object { Get-ClientState -Definition $_ -RootPath $RootPath })
}

function Get-WtfRootPath {
    param([Parameter(Mandatory = $true)][pscustomobject]$State)

    return Join-Path $State.versionRoot "WTF"
}

function Assert-WtfRoot {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$State,
        [switch]$AllowMissing
    )

    $wtfPath = Get-WtfRootPath -State $State
    $reparseItem = Get-ExistingReparseItem -CandidatePath $wtfPath -StopAtPath $State.versionRoot
    if ($null -ne $reparseItem) {
        throw "WTF 路徑含 Reparse Point；拒絕存取：$($reparseItem.FullName)"
    }
    if (-not (Test-Path -LiteralPath $wtfPath -PathType Container)) {
        if ($AllowMissing) {
            return $false
        }
        throw "WTF 資料夾不存在：$wtfPath"
    }
    $item = Get-Item -LiteralPath $wtfPath -Force
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "WTF 根資料夾是 Reparse Point；拒絕存取：$wtfPath"
    }
    Assert-PhysicalDirectoryTree -Path $wtfPath
    return $true
}

function Get-WtfRelatedFiles {
    param([Parameter(Mandatory = $true)][pscustomobject]$State)

    $exists = Assert-WtfRoot -State $State -AllowMissing
    if (-not $exists) {
        return @()
    }
    $wtfPath = Get-WtfRootPath -State $State
    return @(Get-ChildItem -LiteralPath $wtfPath -Recurse -Force -File | Where-Object {
        $relative = Get-RelativePath -BasePath $State.versionRoot -FullPath $_.FullName
        $_.Name -match '(?i)EventAlertMod' -or $relative -match '(?i)EventAlertMod'
    })
}

function Get-WtfBackupRoot {
    return Join-Path $governanceRoot "backup\wtf"
}

function Invoke-WtfBackup {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$State,
        [string]$Reason = "manual"
    )

    $files = @(Get-WtfRelatedFiles -State $State)
    $stamp = Get-Date -Format "yyyyMMddHHmmssfff"
    $backupRoot = Get-WtfBackupRoot
    $packagePath = Join-Path $backupRoot ($State.key + "__" + $stamp)
    if ($DryRun) {
        Write-Host ("WTF_BACKUP_DRY_RUN={0}:files={1}:root={2}" -f $State.key, $files.Count, (Get-WtfRootPath -State $State))
        return [pscustomobject][ordered]@{
            packagePath = $packagePath
            manifestPath = ""
            fileCount = $files.Count
            dryRun = $true
        }
    }

    [System.IO.Directory]::CreateDirectory($packagePath) | Out-Null
    $records = @()
    foreach ($file in $files) {
        $relative = Get-RelativePath -BasePath $State.versionRoot -FullPath $file.FullName
        $destination = Join-Path $packagePath $relative
        Assert-ExactChildPath -Parent $packagePath -Child $destination
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
        $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
        $records += [pscustomobject][ordered]@{
            relativePath = $relative.Replace("\", "/")
            length = [int64]$file.Length
            sha256 = $hash
        }
    }
    $manifest = [pscustomobject][ordered]@{
        schema = 1
        type = "EAM_WTF_BACKUP"
        reason = $Reason
        generatedAt = (Get-Date).ToString("o")
        client = [pscustomobject][ordered]@{
            key = $State.key
            directory = $State.directory
            displayName = $State.displayName
            productVersion = $State.productVersion
            patch = $State.patch
        }
        sourceRelativeRoot = "WTF"
        files = @($records)
    }
    $manifestPath = Join-Path $packagePath "manifest.json"
    [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), $utf8)
    Write-Host ("WTF_BACKUP_SUCCESS={0}:files={1}" -f $State.key, $records.Count)
    Write-Host "WTF_BACKUP_PACKAGE=$packagePath"
    Write-Host "WTF_BACKUP_MANIFEST=$manifestPath"
    return [pscustomobject][ordered]@{
        packagePath = $packagePath
        manifestPath = $manifestPath
        fileCount = $records.Count
        dryRun = $false
        manifest = $manifest
    }
}

function Read-WtfBackupManifest {
    param(
        [Parameter(Mandatory = $true)][string]$PackagePath,
        [Parameter(Mandatory = $true)][pscustomobject]$State
    )

    $resolvedPackage = if ([System.IO.Path]::IsPathRooted($PackagePath)) {
        Get-NormalizedPath -Path $PackagePath
    } else {
        Get-NormalizedPath -Path (Join-Path $projectRoot $PackagePath)
    }
    if (-not (Test-Path -LiteralPath $resolvedPackage -PathType Container)) {
        throw "WTF 備份資料夾不存在：$resolvedPackage"
    }
    $manifestPath = Join-Path $resolvedPackage "manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "WTF 備份缺少 manifest.json：$resolvedPackage"
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([int]$manifest.schema -ne 1 -or [string]$manifest.type -ne "EAM_WTF_BACKUP") {
        throw "WTF 備份 manifest schema/type 不符：$manifestPath"
    }
    if ([string]$manifest.client.key -ne [string]$State.key -or [string]$manifest.client.directory -ne [string]$State.directory) {
        throw "WTF 備份通道不符：manifest=$($manifest.client.key)/$($manifest.client.directory)，目標=$($State.key)/$($State.directory)"
    }
    $records = @($manifest.files)
    foreach ($record in $records) {
        $relative = ([string]$record.relativePath).Replace("\", "/")
        if ([string]::IsNullOrWhiteSpace($relative) -or $relative -notmatch '(?i)^WTF/' -or $relative -match '(^|/)\.\.(?:/|$)') {
            throw "WTF 備份相對路徑不安全：$relative"
        }
        $backupFile = Join-Path $resolvedPackage ($relative.Replace("/", [System.IO.Path]::DirectorySeparatorChar))
        Assert-ExactChildPath -Parent $resolvedPackage -Child $backupFile
        if (-not (Test-Path -LiteralPath $backupFile -PathType Leaf)) {
            throw "WTF 備份檔案不存在：$backupFile"
        }
        $actualHash = (Get-FileHash -LiteralPath $backupFile -Algorithm SHA256).Hash
        if (-not [string]::Equals($actualHash, [string]$record.sha256, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "WTF 備份 SHA-256 不符：$relative"
        }
    }
    return [pscustomobject][ordered]@{
        packagePath = $resolvedPackage
        manifestPath = $manifestPath
        manifest = $manifest
        records = $records
    }
}

function Get-WtfBackupCandidates {
    param([Parameter(Mandatory = $true)][pscustomobject]$State)

    $backupRoot = Get-WtfBackupRoot
    if (-not (Test-Path -LiteralPath $backupRoot -PathType Container)) {
        return @()
    }
    $candidates = @()
    foreach ($directory in @(Get-ChildItem -LiteralPath $backupRoot -Directory -Filter ($State.key + "__*") | Sort-Object LastWriteTime -Descending)) {
        try {
            $candidate = Read-WtfBackupManifest -PackagePath $directory.FullName -State $State
            $candidates += $candidate
        } catch {
            Write-Host ("略過無效 WTF 備份：{0}（{1}）" -f $directory.FullName, $_.Exception.Message) -ForegroundColor Yellow
        }
    }
    return @($candidates)
}

function Read-WtfBackupSelection {
    param([Parameter(Mandatory = $true)][pscustomobject]$State)

    $candidates = @(Get-WtfBackupCandidates -State $State)
    if ($candidates.Count -eq 0) {
        throw "找不到 $($State.menuLabel) 的有效 WTF 備份。"
    }
    Write-Host ""
    Write-Host "$($State.menuLabel) 可還原備份："
    for ($index = 0; $index -lt $candidates.Count; $index++) {
        $candidate = $candidates[$index]
        $manifest = $candidate.manifest
        Write-Host ("[{0}] {1} | files={2} | generatedAt={3} | reason={4}" -f ($index + 1), (Split-Path -Leaf $candidate.packagePath), @($candidate.records).Count, $manifest.generatedAt, $manifest.reason)
    }
    $answer = (Read-Host "輸入備份編號，Enter 使用最新一份").Trim()
    $selectedIndex = 0
    if (-not [string]::IsNullOrWhiteSpace($answer)) {
        if (-not [int]::TryParse($answer, [ref]$selectedIndex) -or $selectedIndex -lt 1 -or $selectedIndex -gt $candidates.Count) {
            throw "無效的備份編號：$answer"
        }
        $selectedIndex--
    }
    return $candidates[$selectedIndex]
}

function Get-ChannelStates {
    param(
        [Parameter(Mandatory = $true)][object[]]$States,
        [Parameter(Mandatory = $true)][string]$RequestedChannel
    )

    if ($RequestedChannel -eq "All") {
        return @($States)
    }
    $state = $States | Where-Object { $_.key -eq $RequestedChannel.ToLowerInvariant() } | Select-Object -First 1
    if ($null -eq $state) {
        throw "找不到指定版本通道：$RequestedChannel"
    }
    return @($state)
}

function Read-WtfStateSelection {
    param([Parameter(Mandatory = $true)][object[]]$States)

    Write-Host ""
    Write-Host "[1] WTF 備份／還原：$($States[0].menuLabel)"
    Write-Host "[2] WTF 備份／還原：$($States[1].menuLabel)"
    Write-Host "[3] WTF 備份／還原：$($States[2].menuLabel)"
    Write-Host "[4] WTF 備份／還原：全部通道"
    $choice = (Read-Host "選擇版本通道").Trim()
    $selected = switch ($choice) {
        "1" { @($States[0]) }
        "2" { @($States[1]) }
        "3" { @($States[2]) }
        "4" { @($States) }
        default { throw "無效版本通道選項：$choice" }
    }
    if ($choice -eq "2" -or $choice -eq "3") {
        $includeRetail = (Read-Host "是否同時包含 Retail？輸入 Y 加入，其他只處理目前通道").Trim().ToUpperInvariant()
        if ($includeRetail -eq "Y") {
            $selected = @($States[0]) + @($selected)
        }
    }
    return @($selected)
}

function Invoke-WtfRestore {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$State,
        [Parameter(Mandatory = $true)][pscustomobject]$Candidate,
        [switch]$SkipRollback
    )

    [void](Assert-WtfRoot -State $State)
    if ($DryRun) {
        Write-Host ("WTF_RESTORE_DRY_RUN={0}:package={1}:files={2}" -f $State.key, $Candidate.packagePath, @($Candidate.records).Count)
        return
    }

    $rollback = $null
    try {
        if (-not $SkipRollback) {
            $rollback = Invoke-WtfBackup -State $State -Reason "restore-rollback"
        }
        foreach ($record in @($Candidate.records)) {
            $relative = ([string]$record.relativePath).Replace("\", "/")
            $target = Join-Path $State.versionRoot ($relative.Replace("/", [System.IO.Path]::DirectorySeparatorChar))
            Assert-ExactChildPath -Parent $State.versionRoot -Child $target
            $targetParent = Split-Path -Parent $target
            $reparseParent = Get-ExistingReparseItem -CandidatePath $targetParent -StopAtPath (Get-WtfRootPath -State $State)
            if ($null -ne $reparseParent) {
                throw "還原目標父層含 Reparse Point：$($reparseParent.FullName)"
            }
            [System.IO.Directory]::CreateDirectory($targetParent) | Out-Null
            $reparseTarget = Get-ExistingReparseItem -CandidatePath $target -StopAtPath (Get-WtfRootPath -State $State)
            if ($null -ne $reparseTarget) {
                throw "還原目標含 Reparse Point：$($reparseTarget.FullName)"
            }
            $backupFile = Join-Path $Candidate.packagePath ($relative.Replace("/", [System.IO.Path]::DirectorySeparatorChar))
            Copy-Item -LiteralPath $backupFile -Destination $target -Force
            $actualHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
            if (-not [string]::Equals($actualHash, [string]$record.sha256, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "還原後 SHA-256 不符：$relative"
            }
        }
        Write-Host ("WTF_RESTORE_SUCCESS={0}:files={1}" -f $State.key, @($Candidate.records).Count)
        Write-Host "WTF_RESTORE_PACKAGE=$($Candidate.packagePath)"
        if ($null -ne $rollback) {
            Write-Host "WTF_RESTORE_ROLLBACK=$($rollback.packagePath)"
        }
    } catch {
        $failure = $_.Exception.Message
        if ($null -ne $rollback -and -not [string]::IsNullOrWhiteSpace($rollback.manifestPath)) {
            try {
                $rollbackCandidate = Read-WtfBackupManifest -PackagePath (Split-Path -Parent $rollback.manifestPath) -State $State
                Invoke-WtfRestore -State $State -Candidate $rollbackCandidate -SkipRollback
                Write-Host "WTF_RESTORE_ROLLBACK_APPLIED=$($rollback.packagePath)" -ForegroundColor Yellow
            } catch {
                Write-Host ("WTF rollback 失敗，請手動使用備份：$($rollback.packagePath)；原因：$($_.Exception.Message)") -ForegroundColor Red
            }
        }
        throw "WTF 還原 $($State.key) 失敗：$failure"
    }
}

function Invoke-SelectedWtfBackup {
    param([Parameter(Mandatory = $true)][object[]]$SelectedStates)

    foreach ($state in $SelectedStates) {
        [void](Assert-WtfRoot -State $state -AllowMissing)
    }
    foreach ($state in $SelectedStates) {
        [void](Invoke-WtfBackup -State $state -Reason "manual")
    }
}

function Invoke-SelectedWtfRestore {
    param(
        [Parameter(Mandatory = $true)][object[]]$SelectedStates,
        [string]$BackupPath = ""
    )

    foreach ($state in $SelectedStates) {
        $candidate = if (-not [string]::IsNullOrWhiteSpace($BackupPath)) {
            Read-WtfBackupManifest -PackagePath $BackupPath -State $state
        } else {
            Read-WtfBackupSelection -State $state
        }
        Invoke-WtfRestore -State $state -Candidate $candidate
    }
}
function Write-ClientStatus {
    param(
        [Parameter(Mandatory = $true)][object[]]$States,
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$RootSource
    )

    Write-Host ""
    Write-Host "EventAlertMod 部署狀態"
    Write-Host "來源：$addonRoot"
    Write-Host "WoW 根目錄：$RootPath"
    Write-Host "偵測來源：$RootSource"
    foreach ($state in $States) {
        $targetText = if ($state.targetKind -eq "reparse") {
            "BLOCKED $($state.linkType) -> $($state.linkTarget)"
        } else {
            $state.targetKind
        }
        Write-Host ("[{0}] {1} | ProductVersion={2} | Target={3}" -f $state.key.ToUpperInvariant(), $state.menuLabel, $state.productVersion, $targetText)
        Write-Host ("    {0}" -f $state.targetPath)
    }
    Write-Host ""
}

function Assert-DeployableState {
    param([Parameter(Mandatory = $true)][pscustomobject]$State)

    if (-not $State.available) {
        throw "版本資料夾不存在：$($State.versionRoot)"
    }
    if (-not (Test-Path -LiteralPath $State.executablePath -PathType Leaf)) {
        throw "遊戲執行檔不存在：$($State.executablePath)"
    }
    if (-not (Test-Path -LiteralPath $State.addonsRoot -PathType Container)) {
        throw "AddOns 資料夾不存在：$($State.addonsRoot)"
    }
    if ($State.targetKind -eq "reparse") {
        throw "部署目標是 $($State.linkType)；拒絕跟隨或覆蓋：$($State.targetPath) -> $($State.linkTarget)"
    }
    if ($State.targetKind -eq "file") {
        throw "部署目標是檔案而非資料夾：$($State.targetPath)"
    }

    $expected = Join-Path $State.addonsRoot "EventAlertMod"
    if (-not [string]::Equals((Get-NormalizedPath -Path $expected), (Get-NormalizedPath -Path $State.targetPath), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "部署目標不是預期的 Interface\AddOns\EventAlertMod：$($State.targetPath)"
    }
    Assert-ExactChildPath -Parent $State.addonsRoot -Child $State.targetPath
    if ($State.targetKind -eq "physical") {
        Assert-PhysicalDirectoryTree -Path $State.targetPath
    }
}

function Write-DeploymentReport {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$State,
        [Parameter(Mandatory = $true)][string]$Status,
        [AllowEmptyString()][string]$BackupPath,
        [int]$FileCount
    )

    $reportDirectory = Join-Path $governanceRoot "TestResults\Deployments"
    [System.IO.Directory]::CreateDirectory($reportDirectory) | Out-Null
    $stamp = Get-Date -Format "yyyyMMdd_HHmmssfff"
    $reportPath = Join-Path $reportDirectory ("EAM_Deployment_" + $State.key + "_" + $stamp + ".json")
    $report = [pscustomobject][ordered]@{
        schema = 1
        type = "EAM_DEPLOYMENT_REPORT"
        generatedAt = (Get-Date).ToString("o")
        status = $Status
        dryRun = $DryRun
        client = [pscustomobject][ordered]@{
            key = $State.key
            directory = $State.directory
            productVersion = $State.productVersion
            patch = $State.patch
        }
        source = $addonRoot
        target = $State.targetPath
        backup = $BackupPath
        files = $FileCount
        reparsePointUsed = $false
    }
    [System.IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 6), $utf8)
    Write-Host "DEPLOY_REPORT=$reportPath"
}

function Invoke-OneDeployment {
    param([Parameter(Mandatory = $true)][pscustomobject]$State)

    $stamp = Get-Date -Format "yyyyMMddHHmmssfff"
    $stagePath = Join-Path $State.addonsRoot (".EAM_EventAlertMod_stage_" + $State.key + "_" + $stamp)
    $backupParent = Join-Path $governanceRoot ("backup\deploy\" + $State.key + "__" + $stamp)
    $backupPath = Join-Path $backupParent "EventAlertMod"
    $failedPath = Join-Path $backupParent "EventAlertMod_failed"
    Assert-ExactChildPath -Parent $State.addonsRoot -Child $stagePath
    if (Test-Path -LiteralPath $stagePath) {
        throw "部署 staging 已存在：$stagePath"
    }

    $oldMoved = $false
    $newMoved = $false
    try {
        [System.IO.Directory]::CreateDirectory($stagePath) | Out-Null
        foreach ($entry in Get-ChildItem -LiteralPath $addonRoot -Force) {
            Copy-Item -LiteralPath $entry.FullName -Destination $stagePath -Recurse -Force
        }
        if (-not (Test-InventoryMatch -TargetRoot $stagePath)) {
            throw "部署 staging 與來源檔案清單不一致。"
        }

        if ($State.targetKind -eq "physical") {
            Assert-PhysicalDirectoryTree -Path $State.targetPath
            [System.IO.Directory]::CreateDirectory($backupParent) | Out-Null
            Move-Item -LiteralPath $State.targetPath -Destination $backupPath
            $oldMoved = $true
        }
        Move-Item -LiteralPath $stagePath -Destination $State.targetPath
        $newMoved = $true
        if (-not (Test-InventoryMatch -TargetRoot $State.targetPath)) {
            throw "部署後目標與來源檔案清單不一致。"
        }

        $count = @(Get-SourceInventory).Count
        Write-DeploymentReport -State $State -Status "pass" -BackupPath $(if ($oldMoved) { $backupPath } else { "" }) -FileCount $count
        Write-Host "DEPLOY_SUCCESS=$($State.key)"
        Write-Host "DEPLOY_TARGET=$($State.targetPath)"
        if ($oldMoved) {
            Write-Host "DEPLOY_BACKUP=$backupPath"
        }
    }
    catch {
        $failure = $_.Exception.Message
        if (Test-Path -LiteralPath $stagePath) {
            $normalizedStage = Get-NormalizedPath -Path $stagePath
            Assert-ExactChildPath -Parent $State.addonsRoot -Child $normalizedStage
            $expectedStagePrefix = ".EAM_EventAlertMod_stage_$($State.key)_"
            if (-not [System.IO.Path]::GetFileName($normalizedStage).StartsWith($expectedStagePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "拒絕清理非預期部署暫存路徑：$normalizedStage；原始錯誤：$failure"
            }
            $stageItem = Get-Item -LiteralPath $normalizedStage -Force
            if (($stageItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                Remove-Item -LiteralPath $normalizedStage -Recurse -Force
            }
        }
        if ($newMoved -and (Test-Path -LiteralPath $State.targetPath -PathType Container)) {
            $targetItem = Get-Item -LiteralPath $State.targetPath -Force
            if (($targetItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                [System.IO.Directory]::CreateDirectory($backupParent) | Out-Null
                Move-Item -LiteralPath $State.targetPath -Destination $failedPath
                $newMoved = $false
            }
        }
        if ($oldMoved -and -not (Test-Path -LiteralPath $State.targetPath) -and (Test-Path -LiteralPath $backupPath -PathType Container)) {
            Move-Item -LiteralPath $backupPath -Destination $State.targetPath
            $oldMoved = $false
        }
        throw "部署 $($State.key) 失敗，已執行回滾：$failure"
    }
}

function Invoke-SelectedDeployment {
    param([Parameter(Mandatory = $true)][object[]]$SelectedStates)

    Test-AddonSource
    foreach ($state in $SelectedStates) {
        Assert-DeployableState -State $state
    }

    if ($DryRun) {
        foreach ($state in $SelectedStates) {
            Write-Host "DEPLOY_DRY_RUN=pass:$($state.key):$($state.targetPath)"
        }
        return
    }

    foreach ($state in $SelectedStates) {
        Invoke-OneDeployment -State $state
    }
}

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "部署設定不存在：$configPath"
}
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($config.type -ne "EAM_DEPLOYMENT_TARGETS" -or [int]$config.schema -ne 1 -or @($config.targets).Count -ne 3) {
    throw "部署設定格式不符：$configPath"
}
$wowRootExplicit = -not [string]::IsNullOrWhiteSpace($WowRoot)
if ($wowRootExplicit) {
    $resolvedRoot = Resolve-WowRootPath -Path $WowRoot -Source "參數 -WowRoot"
} else {
    $registryCandidates = @(Get-RegistryWowCandidates)
    if ($registryCandidates.Count -gt 0) {
        $resolvedRoot = Resolve-WowRootPath -Path $registryCandidates[0].Path -Source $registryCandidates[0].Source
    } else {
        $resolvedRoot = Resolve-WowRootPath -Path ([string]$config.wowRoot) -Source "DeploymentTargets.json 後備"
    }
}
$wowRootPath = $resolvedRoot.Path
$wowRootSource = $resolvedRoot.Source
if ($Action -eq "Menu" -and -not $wowRootExplicit) {
    while ($true) {
        Write-Host ""
        Write-Host "偵測到 WoW 主目錄：$wowRootPath"
        Write-Host "偵測來源：$wowRootSource"
        $rootChoice = (Read-Host "Enter 接受；輸入 C 自訂其他主目錄").Trim().ToUpperInvariant()
        if ($rootChoice -ne "C") { break }
        $customRoot = (Read-Host "輸入 WoW 主目錄完整路徑").Trim().Trim('"')
        try {
            $resolvedRoot = Resolve-WowRootPath -Path $customRoot -Source "使用者自訂"
            $wowRootPath = $resolvedRoot.Path
            $wowRootSource = $resolvedRoot.Source
            break
        }
        catch {
            Write-Host ("自訂路徑無效：" + $_.Exception.Message) -ForegroundColor Red
        }
    }
}

function Find-State {
    param(
        [Parameter(Mandatory = $true)][object[]]$States,
        [Parameter(Mandatory = $true)][string]$Key
    )

    return $States | Where-Object { $_.key -eq $Key.ToLowerInvariant() } | Select-Object -First 1
}

if ($Action -eq "Backup" -or $Action -eq "Restore") {
    if ([string]::IsNullOrWhiteSpace($Channel)) {
        throw "-Action $Action 必須同時指定 -Channel Retail、PTR、XPTR 或 All。"
    }
    if ($Action -eq "Restore" -and $Channel -eq "All") {
        throw "-Action Restore 不接受 -Channel All；請逐通道指定 -WtfBackupPath。"
    }
    $states = @(Get-ClientStates -Definitions @($config.targets) -RootPath $wowRootPath)
    $selected = @(Get-ChannelStates -States $states -RequestedChannel $Channel)
    if ($Action -eq "Backup") {
        Invoke-SelectedWtfBackup -SelectedStates $selected
    } else {
        if ([string]::IsNullOrWhiteSpace($WtfBackupPath)) {
            throw "-Action Restore 必須指定 -WtfBackupPath，或使用互動選單 [U] 選擇備份。"
        }
        Invoke-SelectedWtfRestore -SelectedStates $selected -BackupPath $WtfBackupPath
    }
    return
}
if ($Action -eq "Status") {
    $states = @(Get-ClientStates -Definitions @($config.targets) -RootPath $wowRootPath)
    Write-ClientStatus -States $states -RootPath $wowRootPath -RootSource $wowRootSource
    return
}

if ($Action -ne "Menu") {
    $states = @(Get-ClientStates -Definitions @($config.targets) -RootPath $wowRootPath)
    Write-ClientStatus -States $states -RootPath $wowRootPath -RootSource $wowRootSource
    $selected = if ($Action -eq "All") {
        $states
    } else {
        @(Find-State -States $states -Key $Action)
    }
    Invoke-SelectedDeployment -SelectedStates @($selected)
    return
}

while ($true) {
    $states = @(Get-ClientStates -Definitions @($config.targets) -RootPath $wowRootPath)
    Write-ClientStatus -States $states -RootPath $wowRootPath -RootSource $wowRootSource
    Write-Host "[1] $($states[0].menuLabel)"
    Write-Host "[2] $($states[1].menuLabel)"
    Write-Host "[3] $($states[2].menuLabel)"
    Write-Host "[4] 全部通道"
    Write-Host "[W] 備份 WTF 中的 EventAlertMod 存檔"
    Write-Host "[U] 還原 WTF 中的 EventAlertMod 存檔"
    Write-Host "[B] 從 EventAlertMod 建立插件 ZIP"
    Write-Host "[S] 建立 Project_EventAlertMod 原始碼 ZIP"
    Write-Host "[C] 發布至 CurseForge"
    Write-Host "[R] 重新讀取版本與目標狀態"
    Write-Host "[Q] 離開"
    $choice = (Read-Host "請選擇").Trim().ToUpperInvariant()
    if ($choice -eq "Q") {
        break
    }
    if ($choice -eq "R") {
        continue
    }
    if ($choice -eq "C") {
        try {
            Write-Host ""
            Write-Host "即將啟動 CurseForge 發布程序..." -ForegroundColor Cyan
            Write-Host "【重要檢查】請確定是否已透過選項 [B] 在本地打包最新版本的插件包（Dist/*.zip）？" -ForegroundColor Yellow
            $cfConfirm = (Read-Host "輸入 UPLOAD 開始發布至 CurseForge（或輸入 DRYRUN 進行模擬測試，其他鍵取消）").Trim().ToUpperInvariant()
            if ($cfConfirm -eq "UPLOAD") {
                & $uploadCurseForgeScript
            } elseif ($cfConfirm -eq "DRYRUN") {
                & $uploadCurseForgeScript -DryRun
            } else {
                Write-Host "已取消 CurseForge 發布。"
            }
        }
        catch {
            Write-Host ("CurseForge 發布失敗：" + $_.Exception.Message) -ForegroundColor Red
        }
        continue
    }
    if ($choice -eq "W" -or $choice -eq "U") {
        try {
            $wtfSelected = Read-WtfStateSelection -States $states
            if ($choice -eq "W") {
                Write-Host ""
                Write-Host "將備份下列通道的 WTF EventAlertMod 相關檔案，保留原始相對路徑："
                foreach ($state in $wtfSelected) {
                    Write-Host ("- {0} | {1}" -f $state.menuLabel, (Get-WtfRootPath -State $state))
                }
                $confirmation = (Read-Host "輸入 BACKUP 確認，其他輸入取消").Trim().ToUpperInvariant()
                if ($confirmation -eq "BACKUP") {
                    Invoke-SelectedWtfBackup -SelectedStates $wtfSelected
                } else {
                    Write-Host "已取消 WTF 備份。"
                }
            } else {
                $restoreSelections = @()
                foreach ($state in $wtfSelected) {
                    $candidate = Read-WtfBackupSelection -State $state
                    $restoreSelections += [pscustomobject]@{ State = $state; Candidate = $candidate }
                }
                Write-Host ""
                Write-Host "將還原下列通道的 EventAlertMod 存檔；還原前會先建立 rollback 備份："
                foreach ($selection in $restoreSelections) {
                    Write-Host ("- {0} <= {1}" -f $selection.State.menuLabel, (Split-Path -Leaf $selection.Candidate.packagePath))
                }
                $confirmation = (Read-Host "輸入 RESTORE 確認，其他輸入取消").Trim().ToUpperInvariant()
                if ($confirmation -eq "RESTORE") {
                    foreach ($selection in $restoreSelections) {
                        Invoke-WtfRestore -State $selection.State -Candidate $selection.Candidate
                    }
                } else {
                    Write-Host "已取消 WTF 還原。"
                }
            }
        }
        catch {
            Write-Host ("WTF 備份／還原未執行：" + $_.Exception.Message) -ForegroundColor Red
        }
        continue
    }
    if ($choice -eq "B" -or $choice -eq "S") {
        try {
            if ($choice -eq "B") {
                & $buildScript
            } else {
                & $sourceBuildScript
            }
        }
        catch {
            Write-Host ("打包失敗：" + $_.Exception.Message) -ForegroundColor Red
        }
        continue
    }

    $selected = switch ($choice) {
        "1" { @($states[0]) }
        "2" { @($states[1]) }
        "3" { @($states[2]) }
        "4" { @($states) }
        default { @() }
    }
    if (@($selected).Count -eq 0) {
        Write-Host "無效選項。" -ForegroundColor Yellow
        continue
    }
    if ($choice -eq "2" -or $choice -eq "3") {
        $includeRetail = (Read-Host "是否同時包含 Retail？輸入 Y 加入，其他只部署目前通道").Trim().ToUpperInvariant()
        if ($includeRetail -eq "Y") {
            $selected = @($states[0]) + @($selected)
        }
    }
    Write-Host ""
    Write-Host "本次候選通道（全部先執行前檢）："
    foreach ($candidate in $selected) {
        Write-Host ("- {0} | 目錄={1} | ProductVersion={2}" -f $candidate.displayName, $candidate.directory, $candidate.productVersion)
        Write-Host ("  目標={0}" -f $candidate.targetPath)
    }
    if (-not $DryRun) {
        $confirmation = (Read-Host "輸入 DEPLOY 確認實際部署，其他輸入取消").Trim().ToUpperInvariant()
        if ($confirmation -ne "DEPLOY") {
            Write-Host "已取消部署。"
            continue
        }
    }
    try {
        Invoke-SelectedDeployment -SelectedStates @($selected)
    }
    catch {
        Write-Host ("部署未執行：" + $_.Exception.Message) -ForegroundColor Red
    }
}
