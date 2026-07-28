<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: Tools\CheckLuaSyntax.ps1

理念:
- 提供可重複執行的 Lua 5.1 語法檢查入口。
- 讓靜態驗證成為每次實作 pass 的固定流程。

邊界:
- 只做 luac -p 語法檢查，不代表 WoW Retail 實機驗證。
#>
param(
    [string]$LuaCompiler = "C:\Program Files (x86)\Lua\5.1\luac.exe"
)

$ErrorActionPreference = "Stop"

$workspace = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
Set-Location -LiteralPath $workspace

if (-not (Test-Path -LiteralPath $LuaCompiler)) {
    $command = Get-Command luac -ErrorAction SilentlyContinue
    if ($command) {
        $LuaCompiler = $command.Source
    }
}

if (-not (Test-Path -LiteralPath $LuaCompiler)) {
    throw "luac.exe not found. Install Lua for Windows or pass -LuaCompiler <path>."
}

$sourceRoots = @(
    "Core",
    "Services",
    "UI",
    "Debug",
    "Data",
    "Locale",
    "Tests"
)

$files = foreach ($root in $sourceRoots) {
    if (Test-Path -LiteralPath $root) {
        Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.lua"
    }
}

$failed = @()
foreach ($file in $files) {
    & $LuaCompiler -p $file.FullName
    if ($LASTEXITCODE -ne 0) {
        $failed += $file.FullName
    }
}

if ($failed.Count -gt 0) {
    Write-Host "Lua syntax failures:"
    $failed | ForEach-Object { Write-Host $_ }
    exit 1
}

Write-Host "Lua syntax OK: $($files.Count) files"
