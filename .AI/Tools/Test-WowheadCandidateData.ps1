<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: Tools\Test-WowheadCandidateData.ps1

責任:
- 離線驗證 Wowhead 候選資料的唯一 canonical 路徑、生成器輸出邊界與基本資料自洽性。
- 防止候選 JSON 被正式 TOC／Lua 載入，或被誤稱為 EAM shipped defaults、PTR／Retail 實機證據。

邊界:
- 不連網、不讀 WTF、不啟動或操作 WoW、不寫入 fixture、報告或任何其他 artifact。
- 固定高風險 ID 僅輸出警告；是否存在都不構成本測試的失敗條件。
#>
#Requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Resolve-EAMProject.ps1")
$eamPaths = Get-EAMProjectPaths
$root = $eamPaths.GovernanceRoot
$addonRoot = $eamPaths.AddonRoot
$canonicalPath = Join-Path $root "Data\wow_spells_and_auras.json"
$docsDuplicatePath = Join-Path $root "Docs\wow_spells_and_auras.json"
$fetchScriptPath = Join-Path $root "Tools\fetch_wowhead_spells.py"
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0
$warningCount = 0

function Assert-Contract {
    param(
        [bool]$Condition,
        [string]$Label,
        [string]$Detail = ""
    )

    if ($Condition) {
        $script:passed++
        Write-Host "PASS $Label"
        return
    }

    $message = if ($Detail) { "$Label - $Detail" } else { $Label }
    $script:failures.Add($message)
    Write-Host "FAIL $message"
}

function Write-CandidateWarning {
    param([string]$Message)

    $script:warningCount++
    Write-Warning $Message
}

function Test-HasProperty {
    param(
        [AllowNull()][object]$Value,
        [string]$Name
    )

    return $null -ne $Value -and $null -ne $Value.PSObject.Properties[$Name]
}

function Test-IsIntegerValue {
    param([AllowNull()][object]$Value)

    return $Value -is [sbyte] -or
        $Value -is [byte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64]
}

function Read-Utf8Text {
    param([string]$Path)

    return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
}

Write-CandidateWarning "CANDIDATE_ONLY: .AI/Data/wow_spells_and_auras.json 僅是 Wowhead 網頁候選資料；不是 EAM shipped defaults，也不是 PTR／Retail 實機證據。"

Assert-Contract (Test-Path -LiteralPath $canonicalPath -PathType Leaf) "Canonical candidate JSON exists at .AI/Data/wow_spells_and_auras.json"
Assert-Contract (-not (Test-Path -LiteralPath $docsDuplicatePath)) "Docs duplicate candidate JSON is absent"
Assert-Contract (Test-Path -LiteralPath $fetchScriptPath -PathType Leaf) "Wowhead fetch script exists"

if (Test-Path -LiteralPath $fetchScriptPath -PathType Leaf) {
    $fetchScriptText = Read-Utf8Text -Path $fetchScriptPath
    $pathlibRootPattern = '(?is)Path\s*\(\s*__file__\s*\)\s*\.resolve\s*\(\s*\)\s*(?:\.parents\s*\[\s*1\s*\]|\.parent\s*\.parent)'
    $osPathRootPattern = '(?is)os\.path\.dirname\s*\(\s*os\.path\.dirname\s*\(\s*os\.path\.abspath\s*\(\s*__file__\s*\)\s*\)\s*\)'
    $pathlibOutputPattern = '(?im)^\s*(?:out_file|output_file|output_path)\s*=\s*(?:str\s*\(\s*)?(?:governance_root|GOVERNANCE_ROOT)\s*/\s*["'']Data["'']\s*/\s*["'']wow_spells_and_auras\.json["'']'
    $directOsPathOutputPattern = '(?is)os\.path\.join\s*\(\s*(?:governance_root|GOVERNANCE_ROOT)\s*,\s*["'']Data["'']\s*,\s*["'']wow_spells_and_auras\.json["'']\s*\)'
    $osDataDirectoryPattern = '(?im)^\s*(?:data_dir|DATA_DIR)\s*=\s*os\.path\.join\s*\(\s*(?:governance_root|GOVERNANCE_ROOT)\s*,\s*["'']Data["'']\s*\)'
    $osDataFilePattern = '(?im)^\s*(?:out_file|output_file|output_path)\s*=\s*os\.path\.join\s*\(\s*(?:data_dir|DATA_DIR)\s*,\s*["'']wow_spells_and_auras\.json["'']\s*\)'
    $hasGovernanceRootAnchor = [regex]::IsMatch($fetchScriptText, $pathlibRootPattern) -or
        [regex]::IsMatch($fetchScriptText, $osPathRootPattern)
    $hasCanonicalOutput = [regex]::IsMatch($fetchScriptText, $pathlibOutputPattern) -or
        [regex]::IsMatch($fetchScriptText, $directOsPathOutputPattern) -or
        ([regex]::IsMatch($fetchScriptText, $osDataDirectoryPattern) -and
            [regex]::IsMatch($fetchScriptText, $osDataFilePattern))
    $hasForbiddenOutput = $fetchScriptText -match '(?i)ZebraPrinter' -or
        $fetchScriptText -match '(?i)Docs[\\/]+wow_spells_and_auras\.json'

    Assert-Contract $hasGovernanceRootAnchor "Fetch script derives governance root from its own location"
    Assert-Contract $hasCanonicalOutput "Fetch script outputs to governance_root/Data/wow_spells_and_auras.json"
    Assert-Contract (-not $hasForbiddenOutput) "Fetch script contains no legacy or Docs candidate output path"
}

$candidate = $null
$candidateParsed = $false
if (Test-Path -LiteralPath $canonicalPath -PathType Leaf) {
    try {
        $candidateText = Read-Utf8Text -Path $canonicalPath
        $candidate = $candidateText | ConvertFrom-Json -Depth 100 -ErrorAction Stop
        $candidateParsed = $null -ne $candidate
        Assert-Contract $candidateParsed "Candidate JSON parses successfully"
    }
    catch {
        Assert-Contract $false "Candidate JSON parses successfully" $_.Exception.Message
    }
}

if ($candidateParsed) {
    $hasSpells = Test-HasProperty -Value $candidate -Name "spells"
    $hasTotalSpells = Test-HasProperty -Value $candidate -Name "total_spells"
    $hasTotalAuras = Test-HasProperty -Value $candidate -Name "total_auras"
    $hasClasses = Test-HasProperty -Value $candidate -Name "classes"
    $hasTraversal = Test-HasProperty -Value $candidate -Name "class_urls_traversed"

    Assert-Contract $hasSpells "Candidate JSON declares spells"
    Assert-Contract $hasTotalSpells "Candidate JSON declares total_spells"
    Assert-Contract $hasTotalAuras "Candidate JSON declares total_auras"
    Assert-Contract $hasClasses "Candidate JSON declares player classes"
    Assert-Contract $hasTraversal "Candidate JSON declares traversal evidence"

    if ($hasSpells) {
        $spells = @($candidate.spells)
        $invalidSpellIDs = @($spells | Where-Object {
            -not (Test-HasProperty -Value $_ -Name "spell_id") -or
            -not (Test-IsIntegerValue -Value $_.spell_id) -or
            [int64]$_.spell_id -le 0
        })
        $missingAuraFlags = @($spells | Where-Object {
            -not (Test-HasProperty -Value $_ -Name "has_aura") -or $_.has_aura -isnot [bool]
        })
        $duplicateSpellIDs = @(
            $spells |
                Where-Object { Test-HasProperty -Value $_ -Name "spell_id" } |
                Group-Object -Property spell_id |
                Where-Object { $_.Count -gt 1 }
        )
        $actualAuraCount = @($spells | Where-Object { $_.has_aura -eq $true }).Count

        Assert-Contract ($invalidSpellIDs.Count -eq 0) "Every spell_id is a positive integer" ("invalid={0}" -f $invalidSpellIDs.Count)
        Assert-Contract ($missingAuraFlags.Count -eq 0) "Every spell declares a Boolean has_aura flag" ("invalid={0}" -f $missingAuraFlags.Count)
        Assert-Contract ($duplicateSpellIDs.Count -eq 0) "spell_id values are unique" (($duplicateSpellIDs | Select-Object -First 20 -ExpandProperty Name) -join ",")

        if ($hasTotalSpells) {
            Assert-Contract (
                (Test-IsIntegerValue -Value $candidate.total_spells) -and
                [int64]$candidate.total_spells -eq $spells.Count
            ) "total_spells matches actual spell count" ("declared={0}, actual={1}" -f $candidate.total_spells, $spells.Count)
        }
        if ($hasTotalAuras) {
            Assert-Contract (
                (Test-IsIntegerValue -Value $candidate.total_auras) -and
                [int64]$candidate.total_auras -eq $actualAuraCount
            ) "total_auras matches actual has_aura count" ("declared={0}, actual={1}" -f $candidate.total_auras, $actualAuraCount)
        }

        $class14Spells = @($spells | Where-Object { $_.class_id -eq 14 })
        Assert-Contract ($class14Spells.Count -eq 0) "Class 14 is not used by spell records" ("records={0}" -f $class14Spells.Count)

        $highRiskIDs = [ordered]@{
            61250 = "null class/spec 0 PvP candidate"
            117828 = "cross-class SpellArray conflict"
            195457 = "Mage Brain Freeze versus Rogue Grappling Hook conflict"
            426815 = "cross-class hero label conflict"
            426817 = "cross-class hero label conflict"
            426821 = "cross-class hero label conflict"
            426831 = "cross-class hero label conflict"
            428815 = "cross-class hero label conflict"
            430703 = "Sentinel Mark versus Black Arrow conflict"
            1229376 = "multi-class helper collapsed to one class"
        }
        foreach ($entry in $highRiskIDs.GetEnumerator()) {
            $matches = @($spells | Where-Object { $_.spell_id -eq [int64]$entry.Key })
            if ($matches.Count -gt 0) {
                $details = $matches | ForEach-Object {
                    "id={0}, name={1}, class_id={2}" -f $_.spell_id, $_.name, $_.class_id
                }
                Write-CandidateWarning ("HIGH_RISK_ID present: {0}; reason={1}; {2}" -f $entry.Key, $entry.Value, ($details -join " | "))
            }
            else {
                Write-Host ("INFO HIGH_RISK_ID absent: {0}; reason={1}" -f $entry.Key, $entry.Value)
            }
        }
    }

    if ($hasClasses) {
        $playerClassIDs = @($candidate.classes | ForEach-Object { $_.id } | Sort-Object -Unique)
        $expectedPlayerClassIDs = @(1..13)
        $classSetDifferences = @(Compare-Object -ReferenceObject $expectedPlayerClassIDs -DifferenceObject $playerClassIDs)
        $classSetMatches = $playerClassIDs.Count -eq $expectedPlayerClassIDs.Count -and
            $classSetDifferences.Count -eq 0
        Assert-Contract $classSetMatches "Player class metadata contains exactly class IDs 1 through 13" ("actual={0}" -f ($playerClassIDs -join ","))
    }

    if ($hasTraversal) {
        $class14Traversal = @($candidate.class_urls_traversed | Where-Object { $_.class_id -eq 14 })
        Assert-Contract ($class14Traversal.Count -le 1) "Class 14 appears at most once as traversal evidence" ("records={0}" -f $class14Traversal.Count)
    }
}

$tocFiles = @(Get-ChildItem -LiteralPath $addonRoot -File -Filter "*.toc")
Assert-Contract ($tocFiles.Count -gt 0) "At least one addon TOC is available for candidate isolation checks"

$candidateReferencePattern = '(?i)wow_spells_and_auras(?:\.json)?'
$tocReferences = [System.Collections.Generic.List[string]]::new()
$loadedLuaReferences = [System.Collections.Generic.List[string]]::new()

foreach ($tocFile in $tocFiles) {
    $tocText = Read-Utf8Text -Path $tocFile.FullName
    if ($tocText -match $candidateReferencePattern) {
        $tocReferences.Add($tocFile.FullName)
    }

    foreach ($line in [System.IO.File]::ReadAllLines($tocFile.FullName, [System.Text.UTF8Encoding]::new($false))) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#") -or $trimmed -notmatch '(?i)\.lua$') {
            continue
        }
        $relativeLuaPath = $trimmed -replace '[\\/]', [System.IO.Path]::DirectorySeparatorChar
        $luaPath = Join-Path $addonRoot $relativeLuaPath
        if (-not (Test-Path -LiteralPath $luaPath -PathType Leaf)) {
            continue
        }
        $luaText = Read-Utf8Text -Path $luaPath
        if ($luaText -match $candidateReferencePattern) {
            $loadedLuaReferences.Add($relativeLuaPath)
        }
    }
}

Assert-Contract ($tocReferences.Count -eq 0) "Candidate JSON is not referenced by addon TOC files" ($tocReferences -join ",")
Assert-Contract ($loadedLuaReferences.Count -eq 0) "Candidate JSON is not referenced by TOC-loaded Lua" ($loadedLuaReferences -join ",")

Write-Host "WOWHEAD_CANDIDATE_DATA passed=$passed failed=$($failures.Count) warnings=$warningCount"
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host "CANDIDATE_DATA_FAILURE=$failure"
    }
    exit 1
}
