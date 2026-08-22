<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: .AI\Tools\CheckLuaSyntax.ps1

理念:
- 提供可重複執行的 Lua 5.1 語法檢查入口。
- 明確區分插件執行期與 .AI 離線測試來源。

邊界:
- 只做 luac -p 語法檢查，不代表 WoW Retail／PTR／XPTR 實機驗證。
#>
[CmdletBinding()]
param(
    [string]$LuaCompiler = "C:\Program Files (x86)\Lua\5.1\luac.exe",
    [switch]$AddonOnly
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Resolve-EAMProject.ps1")
$paths = Get-EAMProjectPaths

if (-not (Test-Path -LiteralPath $LuaCompiler)) {
    $command = Get-Command luac -ErrorAction SilentlyContinue
    if ($command) {
        $LuaCompiler = $command.Source
    }
}
if (-not (Test-Path -LiteralPath $LuaCompiler)) {
    throw "luac.exe not found. Install Lua 5.1 or pass -LuaCompiler <path>."
}

$sourceRoots = [System.Collections.Generic.List[string]]::new()
foreach ($name in @("Core", "Services", "Managers", "UI", "Debug", "Data", "Locale")) {
    $sourceRoots.Add((Join-Path $paths.AddonRoot $name))
}
if (-not $AddonOnly) {
    $sourceRoots.Add((Join-Path $paths.GovernanceRoot "Tests"))
}

$files = @($sourceRoots | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | ForEach-Object {
    Get-ChildItem -LiteralPath $_ -Recurse -Force -File -Filter "*.lua"
} | Sort-Object FullName -Unique)
if ($files.Count -eq 0) {
    throw "No Lua files found under the configured source roots."
}

$failed = [System.Collections.Generic.List[string]]::new()
foreach ($file in $files) {
    & $LuaCompiler -p $file.FullName
    if ($LASTEXITCODE -ne 0) {
        $failed.Add($file.FullName)
    }
}
if ($failed.Count -gt 0) {
    Write-Host "Lua syntax failures:"
    $failed | ForEach-Object { Write-Host $_ }
    exit 1
}

$scope = if ($AddonOnly) { "addon" } else { "addon+offline-tests" }
Write-Host "LUA_SYNTAX scope=$scope passed=$($files.Count) failed=0"
