<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: Tools\Import-EAMFlowReport.ps1

理念:
- 將 Flow、真人實機、UnitPower 或 SVG 能力 JSON 從檔案／WTF SavedVariables 回灌至開發環境。
- 不信任報告自稱的 source/status；重新核對環境、矩陣與 summary。

邊界:
- 只讀輸入，不修改 WTF。
- 絕不將 WTF Account 絕對路徑寫入輸出。
- schema 1 Flow 只能列為 legacy-unverified，不得作為實機簽收。
#>
#Requires -Version 7.0
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [ValidateSet("Auto", "Flow", "Live", "UnitPower", "SVG")]
    [string]$ReportType = "Auto",
    [string]$OutputDirectory = "TestResults\Imported"
)

$ErrorActionPreference = "Stop"
$utf8 = [System.Text.UTF8Encoding]::new($false)

function ConvertFrom-LuaEscapedString {
    param([string]$Value)

    $builder = [System.Text.StringBuilder]::new()
    $index = 0
    while ($index -lt $Value.Length) {
        $character = $Value[$index]
        if ($character -ne "\") {
            [void]$builder.Append($character)
            $index++
            continue
        }

        $index++
        if ($index -ge $Value.Length) {
            throw "Invalid trailing escape in SavedVariables string."
        }

        $escaped = $Value[$index]
        if ($escaped -eq "n") {
            [void]$builder.Append([char]10)
        } elseif ($escaped -eq "r") {
            [void]$builder.Append([char]13)
        } elseif ($escaped -eq "t") {
            [void]$builder.Append([char]9)
        } elseif ($escaped -eq "\") {
            [void]$builder.Append("\")
        } elseif ($escaped -eq '"') {
            [void]$builder.Append('"')
        } elseif ([char]::IsDigit($escaped)) {
            $digits = [string]$escaped
            $lookahead = 1
            while ($lookahead -lt 3 -and ($index + 1) -lt $Value.Length -and [char]::IsDigit($Value[$index + 1])) {
                $index++
                $digits += $Value[$index]
                $lookahead++
            }
            [void]$builder.Append([char][int]$digits)
        } else {
            [void]$builder.Append($escaped)
        }
        $index++
    }

    return $builder.ToString()
}

function Escape-MarkdownCell {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) {
        return ""
    }
    return ([string]$Value).Replace("|", "\|").Replace([char]13, " ").Replace([char]10, " ")
}

function Get-DetectedClientDirectory {
    param([string]$ResolvedPath)
    $normalized = $ResolvedPath.Replace("/", "\").ToLowerInvariant()
    foreach ($clientDirectory in "_retail_", "_ptr_", "_xptr_") {
        if ($normalized.Contains("\$clientDirectory\wtf\")) {
            return $clientDirectory
        }
    }
    return $null
}

function Get-SafeInputLabel {
    param(
        [string]$ResolvedPath,
        [AllowNull()][string]$DetectedClientDirectory
    )
    $leaf = [System.IO.Path]::GetFileName($ResolvedPath)
    if ($DetectedClientDirectory) {
        return "$DetectedClientDirectory\WTF\<REDACTED>\$leaf"
    }
    return $leaf
}

function Assert-NoForbiddenPropertyNames {
    param(
        [AllowNull()][object]$Value,
        [string]$Location = "report",
        [int]$Depth = 0
    )
    if ($Depth -gt 30) {
        throw "Privacy scan depth exceeded at $Location."
    }
    if ($null -eq $Value) {
        return
    }
    if ($Value -is [string]) {
        $privacyPattern = "(?i)([a-z]:[\\/]|[\\/]wtf[\\/]|[\\/]account[\\/]|[\\/]savedvariables[\\/]|\\\\[^\\\s]+\\[^\\\s]+)"
        if ([regex]::IsMatch([string]$Value, $privacyPattern)) {
            throw "Forbidden privacy value at $Location."
        }
        return
    }
    if ($Value -is [ValueType]) {
        return
    }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [System.Management.Automation.PSCustomObject]) {
        $itemIndex = 0
        foreach ($item in $Value) {
            Assert-NoForbiddenPropertyNames -Value $item -Location "$Location[$itemIndex]" -Depth ($Depth + 1)
            $itemIndex++
        }
        return
    }

    $forbidden = @(
        "account", "accountname", "character", "charactername", "realm", "realmname",
        "wtfpath", "absolutepath", "inputpath", "playername", "unitname", "guid"
    )
    foreach ($property in $Value.PSObject.Properties) {
        $lowerName = $property.Name.ToLowerInvariant()
        if ($forbidden -contains $lowerName) {
            throw "Forbidden privacy field '$($property.Name)' at $Location."
        }
        Assert-NoForbiddenPropertyNames -Value $property.Value -Location "$Location.$($property.Name)" -Depth ($Depth + 1)
    }
}

function Get-RecomputedSummary {
    param(
        [object[]]$Cases,
        [switch]$Live
    )
    $summary = [ordered]@{
        total = $Cases.Count
        passed = 0
        failed = 0
        skipped = 0
        blocked = 0
        pending = 0
    }
    foreach ($case in $Cases) {
        switch ([string]$case.status) {
            "pass" { $summary.passed++ }
            "fail" { $summary.failed++ }
            "skip" { $summary.skipped++ }
            "blocked" { $summary.blocked++ }
            "pending" { $summary.pending++ }
            default { throw "Unsupported case status '$($case.status)' in '$($case.id)'." }
        }
    }
    if ($Live -and $summary.skipped -gt 0) {
        throw "Live reports cannot use skip; use blocked or pending."
    }
    return [pscustomobject]$summary
}

function Assert-SummaryMatches {
    param(
        [object]$Reported,
        [object]$Computed,
        [switch]$Live
    )
    foreach ($name in "total", "passed", "failed", "pending") {
        if ([int]$Reported.$name -ne [int]$Computed.$name) {
            throw "Summary mismatch for '$name': report=$($Reported.$name), computed=$($Computed.$name)."
        }
    }
    if ($Live) {
        if ([int]$Reported.blocked -ne [int]$Computed.blocked) {
            throw "Summary mismatch for 'blocked'."
        }
    } elseif ([int]$Reported.skipped -ne [int]$Computed.skipped) {
        throw "Summary mismatch for 'skipped'."
    }
}

function Get-RecomputedBuildFlags {
    param([object]$BuildFlags)

    $known = $false
    $aggregate = $false
    foreach ($name in "isPublicTestClient", "isTestBuild", "isBetaBuild") {
        $value = $BuildFlags.$name
        if ($value -is [bool]) {
            $known = $true
            if ($value) {
                $aggregate = $true
            }
        }
    }
    return [pscustomobject]@{
        Known = $known
        Aggregate = $aggregate
    }
}

$resolvedInput = (Resolve-Path -LiteralPath $Path).Path
$inputText = [System.IO.File]::ReadAllText($resolvedInput)
$detectedClientDirectory = Get-DetectedClientDirectory -ResolvedPath $resolvedInput
$safeInputLabel = Get-SafeInputLabel -ResolvedPath $resolvedInput -DetectedClientDirectory $detectedClientDirectory

if ([System.IO.Path]::GetExtension($resolvedInput) -ieq ".json") {
    $reportText = $inputText
} else {
    $flowPattern = 'EAM_FLOW_TEST_REPORT_JSON\s*=\s*"((?:\\.|[^"\\])*)"'
    $livePattern = 'EAM_LIVE_TEST_REPORT_JSON\s*=\s*"((?:\\.|[^"\\])*)"'
    $unitPowerPattern = 'EAM_UNIT_POWER_CAPABILITY_REPORT_JSON\s*=\s*"((?:\\.|[^"\\])*)"'
    $svgPattern = 'EAM_SVG_CAPABILITY_REPORT_JSON\s*=\s*"((?:\\.|[^"\\])*)"'
    $flowMatch = [regex]::Match($inputText, $flowPattern)
    $liveMatch = [regex]::Match($inputText, $livePattern)
    $unitPowerMatch = [regex]::Match($inputText, $unitPowerPattern)
    $svgMatch = [regex]::Match($inputText, $svgPattern)
    if ($ReportType -eq "SVG") {
        if (-not $svgMatch.Success) {
            throw "EAM_SVG_CAPABILITY_REPORT_JSON not found in SavedVariables file."
        }
        $reportText = ConvertFrom-LuaEscapedString $svgMatch.Groups[1].Value
    } elseif ($ReportType -eq "UnitPower") {
        if (-not $unitPowerMatch.Success) {
            throw "EAM_UNIT_POWER_CAPABILITY_REPORT_JSON not found in SavedVariables file."
        }
        $reportText = ConvertFrom-LuaEscapedString $unitPowerMatch.Groups[1].Value
    } elseif ($ReportType -eq "Live" -or ($ReportType -eq "Auto" -and $liveMatch.Success)) {
        if (-not $liveMatch.Success) {
            throw "EAM_LIVE_TEST_REPORT_JSON not found in SavedVariables file."
        }
        $reportText = ConvertFrom-LuaEscapedString $liveMatch.Groups[1].Value
    } elseif ($ReportType -eq "Auto" -and $unitPowerMatch.Success) {
        $reportText = ConvertFrom-LuaEscapedString $unitPowerMatch.Groups[1].Value
    } elseif ($ReportType -eq "Auto" -and $svgMatch.Success) {
        $reportText = ConvertFrom-LuaEscapedString $svgMatch.Groups[1].Value
    } else {
        if (-not $flowMatch.Success) {
            throw "EAM_FLOW_TEST_REPORT_JSON not found in SavedVariables file."
        }
        $reportText = ConvertFrom-LuaEscapedString $flowMatch.Groups[1].Value
    }
}

try {
    $report = $reportText | ConvertFrom-Json
}
catch {
    throw "Invalid validation JSON: $($_.Exception.Message)"
}

Assert-NoForbiddenPropertyNames -Value $report

$workspace = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$validationNotes = [System.Collections.Generic.List[string]]::new()
$isLegacy = $false
$isLive = $report.type -eq "EAM_LIVE_VALIDATION_REPORT"
$isFlow = $report.type -eq "EAM_FLOW_VALIDATION_REPORT"
$isUnitPower = $report.type -eq "EAM_UNIT_POWER_CAPABILITY_REPORT"
$isSVG = $report.type -eq "EAM_SVG_CAPABILITY_REPORT"
if (-not $isLive -and -not $isFlow -and -not $isUnitPower -and -not $isSVG) {
    throw "Unsupported validation report type '$($report.type)'."
}
if (($ReportType -eq "Flow" -and -not $isFlow) -or
    ($ReportType -eq "Live" -and -not $isLive) -or
    ($ReportType -eq "UnitPower" -and -not $isUnitPower) -or
    ($ReportType -eq "SVG" -and -not $isSVG)) {
    throw "Requested report type '$ReportType' does not match payload type '$($report.type)'."
}
if ($isLive) {
    $liveSchemaPath = Join-Path $workspace "Schemas\EAM_LiveValidationReport.schema.json"
    try {
        $schemaValid = Test-Json -Json $reportText -SchemaFile $liveSchemaPath -ErrorAction Stop
    }
    catch {
        throw "Live report JSON schema validation failed: $($_.Exception.Message)"
    }
    if ($schemaValid -ne $true) {
        throw "Live report JSON schema validation failed."
    }
} elseif ($isFlow -and [int]$report.schema -eq 2) {
    $flowSchemaPath = Join-Path $workspace "Schemas\EAM_FlowValidationReport.schema.json"
    try {
        $schemaValid = Test-Json -Json $reportText -SchemaFile $flowSchemaPath -ErrorAction Stop
    }
    catch {
        throw "Flow report JSON schema validation failed: $($_.Exception.Message)"
    }
    if ($schemaValid -ne $true) {
        throw "Flow report JSON schema validation failed."
    }
} elseif ($isUnitPower) {
    $unitPowerSchemaPath = Join-Path $workspace "Schemas\EAM_UnitPowerCapabilityReport.schema.json"
    try {
        $schemaValid = Test-Json -Json $reportText -SchemaFile $unitPowerSchemaPath -ErrorAction Stop
    }
    catch {
        throw "UnitPower report JSON schema validation failed: $($_.Exception.Message)"
    }
    if ($schemaValid -ne $true) {
        throw "UnitPower report JSON schema validation failed."
    }
} elseif ($isSVG) {
    $svgSchemaPath = Join-Path $workspace "Schemas\EAM_SVGCapabilityReport.schema.json"
    try {
        $schemaValid = Test-Json -Json $reportText -SchemaFile $svgSchemaPath -ErrorAction Stop
    }
    catch {
        throw "SVG report JSON schema validation failed: $($_.Exception.Message)"
    }
    if ($schemaValid -ne $true) {
        throw "SVG report JSON schema validation failed."
    }
}

$cases = @($report.cases)
if ($isFlow -or $isLive) {
    $computed = Get-RecomputedSummary -Cases $cases -Live:$isLive
    Assert-SummaryMatches -Reported $report.summary -Computed $computed -Live:$isLive
}

if ($isLive -or $isUnitPower -or ($isFlow -and [int]$report.schema -eq 2)) {
    $rawBuildFlags = Get-RecomputedBuildFlags -BuildFlags $report.environment.buildFlags
    if ($report.environment.isTestBuildKnown -ne $rawBuildFlags.Known) {
        throw "Build flag known-state mismatch between raw flags and aggregate."
    }
    if ($report.environment.isTestBuild -ne $rawBuildFlags.Aggregate) {
        throw "Build flag aggregate mismatch between raw flags and isTestBuild."
    }
}

if ($isFlow) {
    if ([int]$report.schema -eq 1) {
        $isLegacy = $true
        $validationNotes.Add("schema 1 Flow 僅能列為 legacy-unverified，不得作實機簽收。")
    } elseif ([int]$report.schema -ne 2) {
        throw "Unsupported Flow report schema '$($report.schema)'."
    } else {
        $warningCount = @($report.boundaryWarnings).Count
        $expectedStatus = if ($computed.failed -gt 0) {
            "fail"
        } elseif ($computed.skipped -gt 0 -or
            $computed.pending -gt 0 -or
            $report.environment.channelValidation -ne "pass" -or
            $warningCount -gt 0) {
            "incomplete"
        } else {
            "pass"
        }
        if ($report.status -ne $expectedStatus) {
            throw "Flow status mismatch: report=$($report.status), computed=$expectedStatus."
        }
        if ($report.environment.executionSource -eq "offline-mock" -and $report.purpose -ne "offline-contract") {
            throw "Offline Flow report purpose must be offline-contract."
        }
    }
} elseif ($isLive) {
    if ([int]$report.schema -ne 1 -or $report.purpose -ne "rqa-signoff") {
        throw "Unsupported Live report schema or purpose."
    }
    if ($report.capabilities.syntheticContract -eq $true -or
        [string]$report.environment.source -match "(?i)(synthetic|mock)") {
        throw "Synthetic or mock Live payload cannot be imported as player evidence."
    }
    $automationMismatch = $report.automation.gameInputAutomated -ne $false -or
        $report.automation.reloadUIAutomated -ne $false -or
        $report.automation.playerOperated -ne $true
    if ($automationMismatch) {
        throw "Live report automation policy mismatch."
    }

    $matrixPath = Join-Path $workspace "Data\LiveValidationMatrix.json"
    $matrix = [System.IO.File]::ReadAllText($matrixPath) | ConvertFrom-Json
    if ($report.matrixVersion -ne $matrix.matrixVersion) {
        throw "Live matrix version mismatch."
    }
    $expectedIDs = @($matrix.cases | ForEach-Object { [string]$_.id })
    if ($cases.Count -ne $expectedIDs.Count) {
        throw "Live case count mismatch: report=$($cases.Count), expected=$($expectedIDs.Count)."
    }
    $seen = @{}
    foreach ($case in $cases) {
        $id = [string]$case.id
        if ($seen.ContainsKey($id)) {
            throw "Duplicate live case '$id'."
        }
        $seen[$id] = $true
        if ($expectedIDs -notcontains $id) {
            throw "Unknown live case '$id'."
        }
        if ($case.required -ne $true) {
            throw "All live matrix cases must remain required."
        }
    }
    foreach ($expectedID in $expectedIDs) {
        if (-not $seen.ContainsKey($expectedID)) {
            throw "Missing live case '$expectedID'."
        }
    }

    $profileMap = @{
        "_ptr_" = @{ Channel = "PTR"; Source = "ptr-live-manual"; Patch = "12.1.0"; Interface = 120100; TestBuild = $true }
        "_xptr_" = @{ Channel = "XPTR"; Source = "xptr-live-manual"; Patch = "12.0.7"; Interface = 120007; TestBuild = $true }
        "_retail_" = @{ Channel = "RETAIL"; Source = "retail-live-manual"; Patch = "12.0.7"; Interface = 120007; TestBuild = $false }
    }
    $declaredInstallation = [string]$report.environment.declaredInstallation
    $expectedProfile = $profileMap[$declaredInstallation]
    if (-not $expectedProfile) {
        throw "Live report has unsupported declared installation '$declaredInstallation'."
    }
    $environmentMismatch = $report.environment.executionSource -ne "client" -or
        $report.environment.declaredInstallationEvidence -ne "user-asserted" -or
        $report.environment.clientChannel -ne $expectedProfile.Channel -or
        $report.environment.source -ne $expectedProfile.Source -or
        $report.environment.patch -ne $expectedProfile.Patch -or
        [int]$report.environment.interface -ne $expectedProfile.Interface
    if ($environmentMismatch) {
        throw "Live environment/source/profile cross-check failed."
    }
    if ($report.environment.isTestBuildKnown -eq $true -and $report.environment.isTestBuild -ne $expectedProfile.TestBuild) {
        throw "Live test-build flag mismatch."
    }
    if ($detectedClientDirectory -and $detectedClientDirectory -ne $declaredInstallation) {
        throw "WTF client directory does not match the report declaration."
    }
    $pathEvidence = if ($detectedClientDirectory) { "match" } else { "unavailable" }
    $validationNotes.Add("WTF client directory cross-check: $pathEvidence")

    $warningCount = @($report.boundaryWarnings).Count
    $expectedStatus = if ($computed.failed -gt 0) {
        "fail"
    } elseif ($computed.blocked -gt 0 -or
        $computed.pending -gt 0 -or
        $report.environment.channelValidation -ne "pass" -or
        $warningCount -gt 0) {
        "incomplete"
    } else {
        "pass"
    }
    if ($report.status -ne $expectedStatus) {
        throw "Live status mismatch: report=$($report.status), computed=$expectedStatus."
    }
    if ($report.status -eq "pass") {
        if ($report.environment.isTestBuildKnown -ne $true) {
            throw "Live pass requires an observed test-build/public-build flag."
        }
        $incompletePass = $report.session.phase -ne "complete" -or
            $report.session.resumedAfterReload -ne $true -or
            [int]$report.session.reloadSequence -lt 1
        if ($incompletePass) {
            throw "Live pass requires a completed session resumed across /reload."
        }
    }
} elseif ($isUnitPower) {
    if ([int]$report.schema -ne 1 -or $report.purpose -ne "capability-probe") {
        throw "Unsupported UnitPower report schema or purpose."
    }
    $automationMismatch = $report.automation.gameInputAutomated -ne $false -or
        $report.automation.restrictionCVarModified -ne $false -or
        $report.automation.playerOperated -ne $true
    if ($automationMismatch) {
        throw "UnitPower report automation policy mismatch."
    }

    $profileMap = @{
        "_ptr_" = @{ Channel = "PTR"; Source = "ptr-live-manual"; Patch = "12.1.0"; Interface = 120100 }
        "_xptr_" = @{ Channel = "XPTR"; Source = "xptr-live-manual"; Patch = "12.0.7"; Interface = 120007 }
        "_retail_" = @{ Channel = "RETAIL"; Source = "retail-live-manual"; Patch = "12.0.7"; Interface = 120007 }
    }
    $declaredInstallation = [string]$report.environment.declaredInstallation
    $expectedProfile = $profileMap[$declaredInstallation]
    if (-not $expectedProfile) {
        throw "UnitPower report has unsupported declared installation '$declaredInstallation'."
    }
    $environmentMismatch = $report.environment.executionSource -ne "client" -or
        $report.environment.declaredInstallationEvidence -ne "user-asserted" -or
        $report.environment.clientChannel -ne $expectedProfile.Channel -or
        $report.environment.source -ne $expectedProfile.Source -or
        $report.environment.patch -ne $expectedProfile.Patch -or
        [int]$report.environment.interface -ne $expectedProfile.Interface
    if ($environmentMismatch) {
        throw "UnitPower environment/source/profile cross-check failed."
    }
    if ($detectedClientDirectory -and $detectedClientDirectory -ne $declaredInstallation) {
        throw "WTF client directory does not match the UnitPower report declaration."
    }
    $pathEvidence = if ($detectedClientDirectory) { "match" } else { "user-asserted-json" }
    $validationNotes.Add("UnitPower client directory evidence: $pathEvidence")

    $seen = @{}
    $hasFailedObservation = $false
    $hasBlockedObservation = $false
    $hasPendingObservation = $false
    $hasCapabilityGap = $false
    $radialRequired = $report.capabilities.radialSinkRequired -eq $true
    foreach ($case in $cases) {
        $id = [string]$case.id
        if ($seen.ContainsKey($id)) {
            throw "Duplicate UnitPower case '$id'."
        }
        $seen[$id] = $true
        if ($case.visualObservation -eq "fail") {
            $hasFailedObservation = $true
        } elseif ($case.visualObservation -eq "blocked") {
            $hasBlockedObservation = $true
        } elseif ($case.visualObservation -ne "pass") {
            $hasPendingObservation = $true
        }
        if ($case.powerTypeAvailable -ne $true -or $case.statusBarSink -ne "accepted") {
            $hasCapabilityGap = $true
        }
        if ($radialRequired -and $case.radialSink -ne "accepted") {
            $hasCapabilityGap = $true
        }
    }
    $hasStoppedAt = $null -ne $report.session.PSObject.Properties["stoppedAtSessionMs"]
    $warningCount = @($report.boundaryWarnings).Count
    $expectedStatus = if ($hasFailedObservation) {
        "fail"
    } elseif ($hasBlockedObservation) {
        "blocked"
    } elseif ($report.session.active -eq $true) {
        "active"
    } elseif ($hasPendingObservation -or
        $hasCapabilityGap -or
        -not $hasStoppedAt -or
        $report.environment.channelValidation -ne "pass" -or
        $warningCount -gt 0) {
        "incomplete"
    } else {
        "pass"
    }
    if ($report.status -ne $expectedStatus) {
        throw "UnitPower status mismatch: report=$($report.status), computed=$expectedStatus."
    }
} elseif ($isSVG) {
    if ([int]$report.schema -ne 1 -or $report.purpose -ne "capability-probe") {
        throw "Unsupported SVG report schema or purpose."
    }
    if ($report.rawFileIDsCollected -ne $false) {
        throw "SVG report must not collect raw file IDs."
    }
    $automationMismatch = $report.automation.gameInputAutomated -ne $false -or
        $report.automation.playerOperated -ne $true
    if ($automationMismatch) {
        throw "SVG report automation policy mismatch."
    }

    $profileMap = @{
        "_ptr_" = @{ Channel = "PTR"; Source = "ptr-live-manual"; Patch = "12.1.0"; Interface = 120100 }
        "_xptr_" = @{ Channel = "XPTR"; Source = "xptr-live-manual"; Patch = "12.0.7"; Interface = 120007 }
        "_retail_" = @{ Channel = "RETAIL"; Source = "retail-live-manual"; Patch = "12.0.7"; Interface = 120007 }
    }
    $declaredInstallation = [string]$report.environment.declaredInstallation
    $expectedProfile = $profileMap[$declaredInstallation]
    if (-not $expectedProfile) {
        throw "SVG report has unsupported declared installation '$declaredInstallation'."
    }
    $environmentMismatch = $report.environment.executionSource -ne "client" -or
        $report.environment.declaredInstallationEvidence -ne "user-asserted" -or
        $report.environment.clientChannel -ne $expectedProfile.Channel -or
        $report.environment.source -ne $expectedProfile.Source -or
        $report.environment.patch -ne $expectedProfile.Patch -or
        [int]$report.environment.interface -ne $expectedProfile.Interface
    if ($environmentMismatch) {
        throw "SVG environment/source/profile cross-check failed."
    }
    if ($detectedClientDirectory -and $detectedClientDirectory -ne $declaredInstallation) {
        throw "WTF client directory does not match the SVG report declaration."
    }
    $pathEvidence = if ($detectedClientDirectory) { "match" } else { "user-asserted-json" }
    $validationNotes.Add("SVG client directory evidence: $pathEvidence")

    $expectedIDs = @("svg.vector_graphics.set_svg", "svg.texture.set_svg")
    if ($cases.Count -ne $expectedIDs.Count) {
        throw "SVG case count mismatch: report=$($cases.Count), expected=$($expectedIDs.Count)."
    }
    $seen = @{}
    $hasFailedObservation = $false
    $hasBlockedObservation = $false
    $hasPendingObservation = $false
    $hasCapabilityGap = $false
    $interfaceRequired = [int]$report.environment.interface -ge 120100
    if ($report.capabilities.interfaceRequired -ne $interfaceRequired) {
        throw "SVG interface-required flag mismatch."
    }
    foreach ($case in $cases) {
        $id = [string]$case.id
        if ($seen.ContainsKey($id) -or $expectedIDs -notcontains $id) {
            throw "Duplicate or unknown SVG case '$id'."
        }
        $seen[$id] = $true
        if ($case.visualObservation -eq "fail") {
            $hasFailedObservation = $true
        } elseif ($case.visualObservation -eq "blocked") {
            $hasBlockedObservation = $true
        } elseif ($case.visualObservation -ne "pass") {
            $hasPendingObservation = $true
        }
        if ($interfaceRequired -and (
            $case.apiAvailable -ne $true -or
            $case.setResult -ne "accepted" -or
            $case.hasSVG -ne "true" -or
            $case.fileIDClass -ne "positive-number" -or
            $case.clearReload -ne "pass"
        )) {
            $hasCapabilityGap = $true
        }
    }
    foreach ($expectedID in $expectedIDs) {
        if (-not $seen.ContainsKey($expectedID)) {
            throw "Missing SVG case '$expectedID'."
        }
    }

    $hasStoppedAt = $null -ne $report.session.PSObject.Properties["stoppedAtSessionMs"]
    $warningCount = @($report.boundaryWarnings).Count
    $expectedStatus = if (-not $interfaceRequired) {
        "unsupported"
    } elseif ($hasFailedObservation) {
        "fail"
    } elseif ($hasBlockedObservation) {
        "blocked"
    } elseif ($report.session.active -eq $true) {
        "active"
    } elseif ($hasPendingObservation -or
        $hasCapabilityGap -or
        -not $hasStoppedAt -or
        $report.environment.channelValidation -ne "pass" -or
        $warningCount -gt 0) {
        "incomplete"
    } else {
        "pass"
    }
    if ($report.status -ne $expectedStatus) {
        throw "SVG status mismatch: report=$($report.status), computed=$expectedStatus."
    }
}

if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $reportDirectory = $OutputDirectory
} else {
    $reportDirectory = Join-Path $workspace $OutputDirectory
}
[System.IO.Directory]::CreateDirectory($reportDirectory) | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$claimedSource = if ($report.environment.source) { [string]$report.environment.source } else { "unknown" }
$source = if ($isLegacy) {
    "legacy-unverified"
} elseif (($isLive -or $isUnitPower -or $isSVG) -and -not $detectedClientDirectory) {
    "user-asserted-json"
} else {
    $claimedSource
}
$safeSource = $source -replace '[^A-Za-z0-9_-]', '_'
$prefix = if ($isLive) {
    "EAM_LiveValidation"
} elseif ($isUnitPower) {
    "EAM_UnitPowerCapability"
} elseif ($isSVG) {
    "EAM_SVGCapability"
} else {
    "EAM_FlowValidation"
}
$jsonPath = Join-Path $reportDirectory ("$prefix" + "_" + $safeSource + "_" + $timestamp + ".json")
$markdownPath = Join-Path $reportDirectory ("$prefix" + "_" + $safeSource + "_" + $timestamp + ".md")

$prettyJSON = $report | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText($jsonPath, $prettyJSON + [Environment]::NewLine, $utf8)

$lines = [System.Collections.Generic.List[string]]::new()
if ($isLive) {
    $lines.Add("# EAM 真人實機驗證回灌報告")
} elseif ($isUnitPower) {
    $lines.Add("# EAM UnitPower 能力回灌報告")
} elseif ($isSVG) {
    $lines.Add("# EAM SVG 能力回灌報告")
} else {
    $lines.Add("# EAM 流程驗證回灌報告")
}
$lines.Add("")
$lines.Add("- 匯入時間：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
$lines.Add("- 輸入：``$safeInputLabel``")
$lines.Add("- 類型：``$($report.type)`` / schema ``$($report.schema)``")
$lines.Add("- 證據來源：``$source``")
$lines.Add("- 報告自稱來源：``$claimedSource``")
$lines.Add("- 宣告安裝：``$($report.environment.declaredInstallation)``")
$lines.Add("- Patch／Build／Interface：``$($report.environment.patch)``／``$($report.environment.build)``／``$($report.environment.interface)``")
$lines.Add("- 結果：``$($report.status)``")
$lines.Add("")
if ($isLegacy) {
    $lines.Add("> 舊 schema 缺少可信 client identity，只能保存為 legacy-unverified。")
} elseif ($report.environment.executionSource -eq "offline-mock") {
    $lines.Add("> 此為 Mock 證據，不得標記為 Retail／PTR／XPTR 實機通過。")
} elseif ($isLive) {
    if ($detectedClientDirectory) {
        $lines.Add("> 此為從對應 WTF SavedVariables 匯入的玩家人工操作報告；匯入器已重算矩陣與環境證據，仍應保留截圖／錯誤紀錄供 RQA 終審。")
    } else {
        $lines.Add("> 此為玩家自行提供的 JSON；client directory 僅屬 user-asserted，不能單靠此檔宣稱已證明 WTF 來源。")
    }
} elseif ($isUnitPower) {
    if ($detectedClientDirectory) {
        $lines.Add("> 此為從對應 WTF SavedVariables 匯入的玩家 UnitPower 能力觀測；只含分類與 sink 結果，不含資源原值。")
    } else {
        $lines.Add("> 此為玩家自行提供的 UnitPower JSON；client directory 僅屬 user-asserted，仍需保留實機畫面或錯誤紀錄。")
    }
} elseif ($isSVG) {
    if ($detectedClientDirectory) {
        $lines.Add("> 此為從對應 WTF SavedVariables 匯入的玩家 SVG A/B 能力觀測；只保存 API 分類與人工結果，不保存 raw file ID。")
    } else {
        $lines.Add("> 此為玩家自行提供的 SVG JSON；client directory 僅屬 user-asserted，仍需保留實機畫面或錯誤紀錄。")
    }
} else {
    $lines.Add("> 此為遊戲內能力流程報告，不等同於 34 案人工 RQA 簽收。")
}
foreach ($note in $validationNotes) {
    $lines.Add("- $note")
}
$lines.Add("")
$lines.Add("| 案例 | 分類／Suite | 狀態 | 訊息／備註 |")
$lines.Add("| --- | --- | --- | --- |")
foreach ($case in $cases) {
    if ($isUnitPower) {
        $category = $case.role
        $caseStatus = $case.visualObservation
        $message = "result=$($case.resultClass); statusBar=$($case.statusBarSink); radial=$($case.radialSink)"
    } elseif ($isSVG) {
        $category = $case.kind
        $caseStatus = $case.visualObservation
        $message = "set=$($case.setResult); hasSVG=$($case.hasSVG); fileID=$($case.fileIDClass); clearReload=$($case.clearReload)"
    } else {
        $category = if ($isLive) { $case.category } else { $case.suite }
        $caseStatus = $case.status
        $message = if ($isLive) { $case.note } else { $case.message }
    }
    $lines.Add("| $(Escape-MarkdownCell $case.id) | $(Escape-MarkdownCell $category) | $(Escape-MarkdownCell $caseStatus) | $(Escape-MarkdownCell $message) |")
}
[System.IO.File]::WriteAllLines($markdownPath, $lines, $utf8)

Write-Host "IMPORTED_VALIDATION_JSON=$jsonPath"
Write-Host "IMPORTED_VALIDATION_MARKDOWN=$markdownPath"
Write-Host "IMPORTED_VALIDATION_SOURCE=$source"
Write-Host "IMPORTED_VALIDATION_STATUS=$($report.status)"

$hasComputedFailure = ($isFlow -or $isLive) -and (
    [int]$computed.failed -gt 0 -or
    [int]$computed.pending -gt 0 -or
    ($isLive -and [int]$computed.blocked -gt 0)
)
$mustReject = $isLegacy -or
    $report.status -ne "pass" -or
    $hasComputedFailure
if ($mustReject) {
    exit 1
}
