<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
File: Tools\Build-CurseForgePackage.ps1

Concept:
- Establish a repeatable CurseForge package build pipeline.
- Package only the files needed by the Retail addon, avoiding legacy/reference/dev tools.
- Strict release exclusions and security checks to prevent credential leaks and dead code.

Responsibility:
- Verify TOC load paths validity.
- Verify TOC consistency against physical files to prevent unlisted module leaks.
- Run Lua 5.1 syntax checks.
- Run offline flow validation and retain JSON/Markdown evidence.
- Scan for sensitive keys, tokens, and webhooks.
- Build Dist/EventAlertMod_MN_yyyyMMdd_HHmmss.zip.

Boundary:
- Do not modify addon source code.
- Exclude LegacyReference, ReferenceLibs, Tools, backup, .github, .vscode.
- Packaging success does not equal WoW Retail test verification.
#>

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

$workspace = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
Set-Location -LiteralPath $workspace

$addonName = "EventAlertMod"
$tocPath = Join-Path $workspace "EventAlertMod.toc"
if (-not (Test-Path -LiteralPath $tocPath)) {
    throw "Missing EventAlertMod.toc"
}

function Get-TocValue {
    param([string]$Key)
    $pattern = "^##\s+$([regex]::Escape($Key)):\s*(.+)$"
    foreach ($line in Get-Content -LiteralPath $tocPath) {
        if ($line -match $pattern) {
            return $Matches[1].Trim()
        }
    }
    return $null
}

function Test-TocPaths {
    $missing = @()
    foreach ($line in Get-Content -LiteralPath $tocPath) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("##")) {
            continue
        }

        $path = Join-Path $workspace $trimmed
        if (-not (Test-Path -LiteralPath $path)) {
            $missing += $trimmed
        }
    }

    if ($missing.Count -gt 0) {
        Write-Host "Missing TOC files:"
        $missing | ForEach-Object { Write-Host "  $_" }
        throw "TOC validation failed."
    }
}

# Check consistency between physical files and TOC declarations
function Test-TocConsistency {
    param(
        [string[]]$SourceDirs
    )
    Write-Host "Checking TOC consistency..."
    
    # 1. Parse all files declared in TOC
    $tocFiles = @{}
    foreach ($line in Get-Content -LiteralPath $tocPath) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("##")) {
            continue
        }
        $key = $trimmed.Replace("\", "/").ToLower()
        $tocFiles[$key] = $true
    }

    # 2. Get all physical Lua and XML files under build directories
    $unlistedFiles = @()
    foreach ($dir in $SourceDirs) {
        $physicalDir = Join-Path $workspace $dir
        if (-not (Test-Path -LiteralPath $physicalDir)) {
            continue
        }
        
        Get-ChildItem -LiteralPath $physicalDir -Recurse -File | Where-Object {
            $extension = $_.Extension.ToLowerInvariant()
            $extension -eq ".lua" -or $extension -eq ".xml"
        } | ForEach-Object {
            $relative = $_.FullName.Substring($workspace.Length).TrimStart("\", "/").Replace("\", "/")
            $relativeKey = $relative.ToLower()
            if (-not $tocFiles.ContainsKey($relativeKey)) {
                $unlistedFiles += $relative
            }
        }
    }

    if ($unlistedFiles.Count -gt 0) {
        Write-Warning "Found Lua/XML files not listed in TOC! These might be legacy, temporary, or unlisted modules:"
        foreach ($f in $unlistedFiles) {
            Write-Warning "  - $f"
        }
        return $unlistedFiles
    }
    
    Write-Host "TOC consistency check completed. No unlisted Lua/XML files found."
    return $null
}

# Scan code files for sensitive tokens or webhooks
function Scan-SensitiveInfo {
    param(
        [string]$Directory
    )
    Write-Host "Performing sensitive information security audit..."
    $sensitiveDetected = $false
    $filesToScan = Get-ChildItem -LiteralPath $Directory -Recurse -File -Include "*.lua", "*.toc", "*.xml"
    
    # Scan for assignment patterns like key = "..." or webhook urls
    $patterns = @(
        '=\s*"[^"]*(?:api_?key|token|client_secret|app_secret|password|webhook|credential)[^"]*"',
        "=\s*'[^']*(?:api_?key|token|client_secret|app_secret|password|webhook|credential)[^']*'",
        'https://discord\.com/api/webhooks/',
        'https://api\.slack\.com/services/'
    )

    foreach ($file in $filesToScan) {
        $lines = @(Get-Content -LiteralPath $file.FullName)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            # Ignore comments in Lua and TOC
            if ($line.StartsWith("--") -or $line.StartsWith("##")) {
                continue
            }
            foreach ($pattern in $patterns) {
                if ($line -match $pattern) {
                    Write-Warning "[SECURITY WARNING] $($file.FullName) at line $($i+1) may contain sensitive credentials or keys:"
                    Write-Warning "  Content: $line"
                    $sensitiveDetected = $true
                }
            }
        }
    }
    return $sensitiveDetected
}

# Copy directory and filter files using a strict extension whitelist
function Copy-DirectoryToPackage {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        return
    }

    $allowedExtensions = @(".lua", ".xml", ".tga", ".blp", ".mp3", ".wav", ".ogg", ".png", ".txt", ".md")

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -LiteralPath $Source -Recurse -File | ForEach-Object {
        $ext = [System.IO.Path]::GetExtension($_.Name).ToLower()
        
        # Skip hidden files
        if ($_.Name.StartsWith(".")) {
            Write-Host "  [Skip] Hidden file: $($_.Name)"
            return
        }
        
        # Skip unallowed extensions
        if ($allowedExtensions -notcontains $ext) {
            Write-Host "  [Skip] Unallowed extension: $($_.Name)"
            return
        }
        
        # Skip temporary/backup files
        if ($_.Name -match '\.(bak|tmp|swp|temp|old)$' -or $_.Name.EndsWith("~")) {
            Write-Host "  [Skip] Temporary/Backup file: $($_.Name)"
            return
        }

        $relative = $_.FullName.Substring($Source.Length).TrimStart("\", "/")
        $target = Join-Path $Destination $relative
        $targetDir = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $_.FullName -Destination $target -Force
    }
}

# --- Execution Workflow ---

if ($DevMode) {
    Write-Host "--------------------------------------------------"
    Write-Host "Running in DEV Mode (No Filters, Full Package)"
    Write-Host "--------------------------------------------------"
    $ExpansionCode = "DEV"
    $SkipLuaCheck = $true
}

# 1. Verify TOC paths exist
if (-not $DevMode) {
    Test-TocPaths
}

# 2. Check consistency between TOC and physical files
$sourceDirs = @(
    "Core",
    "Services",
    "UI",
    "Debug",
    "Data",
    "Locale"
)
if (-not $DevMode) {
    $unlisted = Test-TocConsistency -SourceDirs $sourceDirs
    if ($unlisted -and -not $SkipLuaCheck) {
        throw "Packaging failed: Found Lua/XML files not listed in TOC. To prevent package pollution, add them to TOC or move them out of the packaging directories."
    }
}

# 3. Check Lua syntax
if (-not $SkipLuaCheck) {
    $checkScript = Join-Path $workspace "Tools\CheckLuaSyntax.ps1"
    if (Test-Path -LiteralPath $checkScript) {
        & powershell -ExecutionPolicy Bypass -File $checkScript -LuaCompiler $LuaCompiler
        if ($LASTEXITCODE -ne 0) {
            throw "Lua syntax check failed."
        }
    }
}

# 3b. Run offline flow validation
if (-not $SkipFlowValidation) {
    $flowScript = Join-Path $workspace "Tools\Run-FlowValidation.ps1"
    if (-not (Test-Path -LiteralPath $flowScript)) {
        throw "Missing flow validation script: $flowScript"
    }

    & powershell -NoProfile -ExecutionPolicy Bypass -File $flowScript -Suite all -OutputDirectory "TestResults"
    if ($LASTEXITCODE -ne 0) {
        throw "Offline flow validation failed."
    }
}

# 3c. Validate JSON schemas and Lua/TOC contract synchronization
if (-not $SkipFlowValidation) {
    $contractScript = Join-Path $workspace "Tools\Test-ValidationContracts.ps1"
    if (-not (Test-Path -LiteralPath $contractScript)) {
        throw "Missing validation contract script: $contractScript"
    }
    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwshCommand) {
        throw "PowerShell 7 (pwsh) is required for JSON Schema validation."
    }

    & $pwshCommand.Source -NoProfile -File $contractScript
    if ($LASTEXITCODE -ne 0) {
        throw "JSON/Lua validation contracts failed."
    }
}
# 4. Verify version format match
$packDate = Get-Date -Format "yyyyMMdd"
$packTime = Get-Date -Format "HHmmss"
$expectedVersion = "${addonName}_${ExpansionCode}_${packDate}"
$currentVersion = Get-TocValue "Version"
if (-not $DevMode -and $currentVersion -ne $expectedVersion) {
    throw "TOC Version mismatch. Expected '$expectedVersion', found '$currentVersion'. Update EventAlertMod.toc before packaging."
}

# 5. Prepare build stage folders
$distRoot = Join-Path $workspace $OutputDirectory
$stageRoot = Join-Path $distRoot "_stage"
$packageRoot = Join-Path $stageRoot $addonName
$zipPath = Join-Path $distRoot "${addonName}_${ExpansionCode}_${packDate}_${packTime}.zip"

if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
New-Item -ItemType Directory -Path $distRoot -Force | Out-Null

if ($DevMode) {
    # 6. Copy everything under workspace to packageRoot, excluding Dist and .git
    Write-Host "Copying all workspace files (DevMode)..."
    Get-ChildItem -LiteralPath $workspace -Force | ForEach-Object {
        if ($_.Name -ne $OutputDirectory -and $_.Name -ne ".git") {
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $packageRoot $_.Name) -Recurse -Force
        }
    }
} else {
    # 6. Copy root metadata files
    $rootFiles = @(
        "EventAlertMod.toc",
        "README.md",
        "readme.html",
        "changelog.txt"
    )

    foreach ($file in $rootFiles) {
        $source = Join-Path $workspace $file
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $packageRoot $file) -Force
        }
    }

    # 7. Copy directories with whitelist filtering
    $allDirsToPack = $sourceDirs + "Media"
    foreach ($dir in $allDirsToPack) {
        Copy-DirectoryToPackage -Source (Join-Path $workspace $dir) -Destination (Join-Path $packageRoot $dir)
    }

    if ($IncludeDocs) {
        Copy-DirectoryToPackage -Source (Join-Path $workspace "Docs") -Destination (Join-Path $packageRoot "Docs")
        Copy-Item -LiteralPath (Join-Path $workspace "AGENTS.md") -Destination (Join-Path $packageRoot "AGENTS.md") -Force
    }
}

# 8. Run security check (sensitive keys / token check)
$leakDetected = Scan-SensitiveInfo -Directory $packageRoot
if ($leakDetected -and -not $SkipLuaCheck) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
    throw "Packaging failed: Suspected sensitive keys/credentials detected. Please clean them up before packaging, or use -SkipLuaCheck to bypass."
}

# 9. Perform archive compression
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path $packageRoot -DestinationPath $zipPath -CompressionLevel Optimal
Remove-Item -LiteralPath $stageRoot -Recurse -Force

Write-Host "--------------------------------------------------"
Write-Host "Package build successful!"
Write-Host "Package path: $zipPath"
Write-Host "--------------------------------------------------"
