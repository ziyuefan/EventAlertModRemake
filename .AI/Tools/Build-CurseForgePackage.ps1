<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: .AI\Tools\Build-CurseForgePackage.ps1

責任:
- 保留舊命令名稱，轉交給 Deploy\Build-Package.ps1。
- 插件包永遠以 EventAlertMod 整個資料夾為唯一來源。

邊界:
- 不再自行挑選 Core、Managers、UI 等子資料夾。
- 不上傳 CurseForge、GitHub 或 WoWInterface。
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = "Dist",
    [string]$ExpansionCode = "MN",
    [switch]$IncludeDocs,
    [switch]$SkipLuaCheck,
    [switch]$SkipFlowValidation,
    [switch]$DevMode,
    [string]$LuaCompiler = "C:\Program Files (x86)\Lua\5.1\luac.exe"
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Resolve-EAMProject.ps1")
$eamPaths = Get-EAMProjectPaths
$buildScript = Join-Path $eamPaths.DeployRoot "Build-Package.ps1"
$resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $eamPaths.ProjectRoot $OutputDirectory }
$parameters = @{
    OutputDirectory = $resolvedOutput
    LuaCompiler = $LuaCompiler
    SkipLuaCheck = $SkipLuaCheck
    SkipFlowValidation = $SkipFlowValidation
}
if ($DevMode) {
    $parameters.PackageLabel = "DEV"
}
if ($IncludeDocs) {
    Write-Warning "IncludeDocs 已淘汰；EventAlertMod/ 內的 README.md 與 changelog.txt 固定納入插件包。"
}
if ($ExpansionCode -ne "MN") {
    Write-Warning "ExpansionCode 只保留相容參數，實際版本取自 EventAlertMod.toc。"
}
& $buildScript @parameters
exit $LASTEXITCODE
