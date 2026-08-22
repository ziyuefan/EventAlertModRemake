<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: Deploy\Deploy-EventAlertMod.ps1

責任:
- 以互動選單顯示 Retail、PTR、XPTR 與即時 ProductVersion。
- 將 EventAlertMod 實體來源部署到所選客戶端的 Interface\AddOns\EventAlertMod。
- 在任何寫入前阻擋 Reparse Point、錯誤路徑、執行中的 WoW 與來源不完整。

邊界:
- 絕不刪除、解除、覆蓋或跟隨 SymbolicLink／Junction。
- 不讀 WTF、不啟動或關閉 WoW、不修改 PATH。
- 只有使用者明確選擇部署且所有前檢通過時才寫入遊戲目錄。
#>
[CmdletBinding()]
param(
    [ValidateSet("Menu", "Status", "Retail", "PTR", "XPTR", "All")]
    [string]$Action = "Menu",
    [string]$WowRoot = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$utf8 = [System.Text.UTF8Encoding]::new($false)
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$addonRoot = Join-Path $projectRoot "EventAlertMod"
$governanceRoot = Join-Path $projectRoot ".AI"
$configPath = Join-Path $PSScriptRoot "DeploymentTargets.json"
$buildScript = Join-Path $PSScriptRoot "Build-Package.ps1"
$sourceBuildScript = Join-Path $PSScriptRoot "Build-SourcePackage.ps1"

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

function Test-WowIsRunning {
    return $null -ne (Get-Process -Name "Wow", "WowT" -ErrorAction SilentlyContinue | Select-Object -First 1)
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

    # if (Test-WowIsRunning) {
        # throw "偵測到 Wow.exe 或 WowT.exe 正在執行；請由玩家正常關閉遊戲後再部署。"
    # }

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
    Write-Host "[B] 從 EventAlertMod 建立插件 ZIP"
    Write-Host "[S] 建立 Project_EventAlertMod 原始碼 ZIP"
    Write-Host "[R] 重新讀取版本與目標狀態"
    Write-Host "[Q] 離開"
    $choice = (Read-Host "請選擇").Trim().ToUpperInvariant()
    if ($choice -eq "Q") {
        break
    }
    if ($choice -eq "R") {
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
