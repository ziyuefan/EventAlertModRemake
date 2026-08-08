<# EAM_FILE_COMMENTARY
EventAlertMod Retail Rewrite
檔案: Tools\Test-ValidationContracts.ps1

理念:
- 使用 JSON Schema 驗證標準資料，再交叉比對 WoW 執行期 Lua 靜態映射。
- 離線 fixture 永遠只能證明契約，不得成為 PTR／XPTR／正式服實機證據。

邊界:
- 不啟動或操作 WoW，不讀 WTF，不輸入遊戲行為，不修改來源檔案。
- 匯入器反例只在系統暫存目錄建立合成 JSON 與輸出，不得列為實機證據。
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$FlowReport
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0

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

function Assert-JsonSchema {
    param(
        [string]$DataPath,
        [string]$SchemaPath,
        [string]$Label
    )
    try {
        $valid = Test-Json -LiteralPath $DataPath -SchemaFile $SchemaPath -ErrorAction Stop
        Assert-Contract ($valid -eq $true) $Label
    }
    catch {
        Assert-Contract $false $Label $_.Exception.Message
    }
}

function Test-IsJsonSchemaValidationError {
    param(
        [AllowNull()][System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    if ($null -eq $ErrorRecord) {
        return $false
    }
    return $ErrorRecord.CategoryInfo.Category -eq [System.Management.Automation.ErrorCategory]::InvalidData -and
        $ErrorRecord.FullyQualifiedErrorId -like "InvalidJsonAgainstSchema*,Microsoft.PowerShell.Commands.TestJsonCommand"
}

function Get-JsonSchemaRejectionResult {
    param(
        [string]$DataPath,
        [string]$SchemaPath
    )
    try {
        $valid = Test-Json -LiteralPath $DataPath -SchemaFile $SchemaPath -ErrorAction Stop
        if ($valid -eq $true) {
            return [pscustomobject]@{
                ExpectedRejection = $false
                InfrastructureError = $false
                Detail = "Schema unexpectedly accepted the fixture."
            }
        }
        return [pscustomobject]@{
            ExpectedRejection = $true
            InfrastructureError = $false
            Detail = ""
        }
    }
    catch {
        $expectedRejection = Test-IsJsonSchemaValidationError -ErrorRecord $_
        $detail = if ($expectedRejection) {
            ""
        } else {
            "Unexpected Test-Json error: id=$($_.FullyQualifiedErrorId), category=$($_.CategoryInfo.Category), message=$($_.Exception.Message)"
        }
        return [pscustomobject]@{
            ExpectedRejection = $expectedRejection
            InfrastructureError = -not $expectedRejection
            Detail = $detail
        }
    }
}

function Assert-JsonSchemaRejected {
    param(
        [string]$DataPath,
        [string]$SchemaPath,
        [string]$Label
    )
    $result = Get-JsonSchemaRejectionResult -DataPath $DataPath -SchemaPath $SchemaPath
    Assert-Contract $result.ExpectedRejection $Label $result.Detail
}

function Read-Json {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
}

function Write-JsonFixture {
    param(
        [string]$Path,
        [object]$Value,
        [ValidateRange(1, 100)]
        [int]$Depth = 30
    )
    $json = $Value | ConvertTo-Json -Depth $Depth
    [System.IO.File]::WriteAllText(
        $Path,
        $json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Copy-JsonValue {
    param([object]$Value)
    return ($Value | ConvertTo-Json -Depth 30 | ConvertFrom-Json)
}

function Invoke-ImporterContract {
    param(
        [string]$ImporterPath,
        [string]$DataPath,
        [ValidateSet("Flow", "Live")]
        [string]$ReportType,
        [string]$OutputDirectory,
        [int]$ExpectedExitCode,
        [string]$Label,
        [string]$ExpectedText = ""
    )

    $hostExecutable = Join-Path $PSHOME "pwsh.exe"
    if (-not (Test-Path -LiteralPath $hostExecutable)) {
        $hostExecutable = Join-Path $PSHOME "pwsh"
    }
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $hostExecutable
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    [void]$startInfo.ArgumentList.Add("-NoProfile")
    [void]$startInfo.ArgumentList.Add("-File")
    [void]$startInfo.ArgumentList.Add($ImporterPath)
    [void]$startInfo.ArgumentList.Add("-Path")
    [void]$startInfo.ArgumentList.Add($DataPath)
    [void]$startInfo.ArgumentList.Add("-ReportType")
    [void]$startInfo.ArgumentList.Add($ReportType)
    [void]$startInfo.ArgumentList.Add("-OutputDirectory")
    [void]$startInfo.ArgumentList.Add($OutputDirectory)

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $standardOutput = $process.StandardOutput.ReadToEndAsync()
    $standardError = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $output = $standardOutput.GetAwaiter().GetResult() + $standardError.GetAwaiter().GetResult()
    Assert-Contract ($process.ExitCode -eq $ExpectedExitCode) $Label $output.Trim()
    if ($ExpectedText) {
        Assert-Contract ($output.Contains($ExpectedText)) ("$Label message") $output.Trim()
    }
    $process.Dispose()
}

$paths = @{
    PlacementData = Join-Path $root "Data\TextPlacementContract.json"
    PlacementSchema = Join-Path $root "Schemas\EAM_TextPlacementContract.schema.json"
    MatrixData = Join-Path $root "Data\LiveValidationMatrix.json"
    MatrixSchema = Join-Path $root "Schemas\EAM_LiveValidationMatrix.schema.json"
    ContinuityData = Join-Path $root "Data\ProjectContinuity.json"
    ContinuitySchema = Join-Path $root "Schemas\EAM_ProjectContinuity.schema.json"
    ContinuityDoc = Join-Path $root "Docs\28_PROJECT_CONTINUITY.md"
    IssueLog = Join-Path $root "Docs\15_DEVELOPMENT_ISSUE_LOG.md"
    Agents = Join-Path $root "AGENTS.md"
    Context = Join-Path $root "Docs\00_AI_CONTEXT.md"
    LiveFixture = Join-Path $root "Tests\Fixtures\EAM_LiveValidationReport.incomplete.json"
    LiveSchema = Join-Path $root "Schemas\EAM_LiveValidationReport.schema.json"
    FlowSchema = Join-Path $root "Schemas\EAM_FlowValidationReport.schema.json"
    PlacementLua = Join-Path $root "UI\TextPlacement.lua"
    SessionLua = Join-Path $root "Debug\LiveTestSession.lua"
    FlowLua = Join-Path $root "Debug\FlowTestRunner.lua"
    ConstantsLua = Join-Path $root "Core\Constants.lua"
    OptionsLua = Join-Path $root "UI\Options.lua"
    RendererLua = Join-Path $root "UI\Renderer.lua"
    NativeRendererLua = Join-Path $root "UI\NativeAuraRenderer.lua"
    UnitPowerProbeLua = Join-Path $root "Debug\UnitPowerCapabilityProbe.lua"
    AuraContainerLua = Join-Path $root "Services\AuraContainerService.lua"
    AuraCompilerLua = Join-Path $root "Managers\AuraRuleCompiler.lua"
    Importer = Join-Path $root "Tools\Import-EAMFlowReport.ps1"
    Toc = Join-Path $root "EventAlertMod.toc"
}

foreach ($jsonPath in @($paths.PlacementData, $paths.MatrixData, $paths.ContinuityData, $paths.LiveFixture, $paths.PlacementSchema, $paths.MatrixSchema, $paths.ContinuitySchema, $paths.LiveSchema, $paths.FlowSchema)) {
    try {
        [void](Read-Json $jsonPath)
        Assert-Contract $true ("JSON parse: " + [System.IO.Path]::GetFileName($jsonPath))
    }
    catch {
        Assert-Contract $false ("JSON parse: " + [System.IO.Path]::GetFileName($jsonPath)) $_.Exception.Message
    }
}

Assert-JsonSchema $paths.PlacementData $paths.PlacementSchema "Text placement JSON schema"
Assert-JsonSchema $paths.MatrixData $paths.MatrixSchema "Live matrix JSON schema"
Assert-JsonSchema $paths.ContinuityData $paths.ContinuitySchema "Project continuity JSON schema"
Assert-JsonSchema $paths.LiveFixture $paths.LiveSchema "Incomplete live fixture JSON schema"

if (-not $FlowReport) {
    $latestFlow = Get-ChildItem -LiteralPath (Join-Path $root "TestResults") -Filter "EAM_FlowValidation_all_*.json" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($latestFlow) {
        $FlowReport = $latestFlow.FullName
    }
}
Assert-Contract (-not [string]::IsNullOrWhiteSpace($FlowReport) -and (Test-Path -LiteralPath $FlowReport)) "Flow report available"
if ($FlowReport -and (Test-Path -LiteralPath $FlowReport)) {
    Assert-JsonSchema $FlowReport $paths.FlowSchema "Flow report JSON schema 2"
}

$placement = Read-Json $paths.PlacementData
$placementLua = [System.IO.File]::ReadAllText($paths.PlacementLua)
$definitionPattern = '(?m)^\s+(?<id>(?:INSIDE|OUTSIDE)_[A-Z_]+)\s*=\s*anchor\("(?<point>[A-Z]+)",\s*"(?<relative>[A-Z]+)",\s*(?<x>-?\d+),\s*(?<y>-?\d+)\),\s*$'
$definitionMatches = [regex]::Matches($placementLua, $definitionPattern)
$definitionMap = @{}
foreach ($match in $definitionMatches) {
    $definitionMap[$match.Groups["id"].Value] = $match
}
$orderedBlock = [regex]::Match($placementLua, '(?s)local orderedPlacements = freeze\(\{(?<body>.*?)\}\)')
$orderedIDs = @([regex]::Matches($orderedBlock.Groups["body"].Value, '"(?<id>(?:INSIDE|OUTSIDE)_[A-Z_]+)"') | ForEach-Object { $_.Groups["id"].Value })
$jsonPlacementIDs = @($placement.placements | ForEach-Object { [string]$_.id })
Assert-Contract ($definitionMap.Count -eq 21) "Lua placement definition count"
Assert-Contract (($orderedIDs -join "|") -eq ($jsonPlacementIDs -join "|")) "Placement order matches JSON"
foreach ($item in $placement.placements) {
    $match = $definitionMap[[string]$item.id]
    $same = $null -ne $match -and
        $match.Groups["point"].Value -eq [string]$item.point -and
        $match.Groups["relative"].Value -eq [string]$item.relativePoint -and
        [int]$match.Groups["x"].Value -eq [int]$item.x -and
        [int]$match.Groups["y"].Value -eq [int]$item.y
    Assert-Contract $same ("Placement tuple: " + $item.id)
}

$constantsLua = [System.IO.File]::ReadAllText($paths.ConstantsLua)
$timerDefaultPattern = 'TEXT_PLACEMENT_TIMER_DEFAULT\s*=\s*"' + [regex]::Escape($placement.defaultTimer) + '"'
$applicationsDefaultPattern = 'TEXT_PLACEMENT_APPLICATIONS_DEFAULT\s*=\s*"' + [regex]::Escape($placement.defaultApplications) + '"'
Assert-Contract ($constantsLua -match $timerDefaultPattern) "Timer default matches Constants"
Assert-Contract ($constantsLua -match $applicationsDefaultPattern) "Applications default matches Constants"
Assert-Contract ($constantsLua -match ("TEXT_FONT_SIZE_MIN\s*=\s*" + [int]$placement.fontSize.minimum + "\b")) "Minimum font matches Constants"
Assert-Contract ($constantsLua -match ("TEXT_FONT_SIZE_MAX\s*=\s*" + [int]$placement.fontSize.maximum + "\b")) "Maximum font matches Constants"

$optionsLua = [System.IO.File]::ReadAllText($paths.OptionsLua)
$sliderBlock = [regex]::Match(
    $optionsLua,
    '(?s)local function createSlider\(.*?\n\s*return slider\s*\nend'
)
Assert-Contract $sliderBlock.Success "Text slider implementation found"
Assert-Contract (
    $sliderBlock.Value.Contains('Options.notifyTextLayoutChanged(false)')
) "Text slider previews without Native rebuild"
Assert-Contract (
    $sliderBlock.Value.Contains('slider:HookScript("OnMouseUp", commitNativeChange)') -and
    $sliderBlock.Value.Contains('slider:HookScript("OnHide", commitNativeChange)') -and
    $sliderBlock.Value.Contains('Options.notifyTextLayoutChanged(true)')
) "Text slider commits one deferred Native rebuild"
Assert-Contract (
    $sliderBlock.Value.Contains('local isNativeStructureSlider = key == "iconSize" or key == "iconSpacing"') -and
    $sliderBlock.Value.Contains('Options.notifyConfigChanged(false)') -and
    $sliderBlock.Value.Contains('"OPTIONS_NATIVE_STRUCTURE_CHANGED"')
) "Native structure sliders preview without repeated rebuild"
Assert-Contract (
    $optionsLua.Contains('function Options.notifyTextLayoutChanged(reapplyNative)') -and
    $optionsLua.Contains('markAuraSettingsDirty("OPTIONS_NATIVE_TEXT_LAYOUT_CHANGED")') -and
    -not $optionsLua.Contains('EAM.Services.AuraContainerService.requestRebuild("OPTIONS_NATIVE_TEXT_LAYOUT_CHANGED")')
) "Text layout route rebuilds Native container only on commit"

$rendererLua = [System.IO.File]::ReadAllText($paths.RendererLua)
$nativeRendererLua = [System.IO.File]::ReadAllText($paths.NativeRendererLua)
$unitPowerProbeLua = [System.IO.File]::ReadAllText($paths.UnitPowerProbeLua)
$auraContainerLua = [System.IO.File]::ReadAllText($paths.AuraContainerLua)
$auraCompilerLua = [System.IO.File]::ReadAllText($paths.AuraCompilerLua)
Assert-Contract (
    $rendererLua.Contains('return false, "combatDeferred"') -and
    $rendererLua.Contains('Renderer.textLayoutPending = true')
) "General Renderer defers structural layout in combat"
Assert-Contract (
    $nativeRendererLua.Contains('function NativeAuraRenderer.createInitializer(rule, container, slotIndex)') -and
    $nativeRendererLua.Contains('initializeButton(auraButton, rule, container, slotIndex, style)') -and
    $nativeRendererLua.Contains('return false, "nativeRebuildRequired"') -and
    $nativeRendererLua.Contains('return true, "noPostInitializationMutation"') -and
    -not $nativeRendererLua.Contains('local registeredButtons = setmetatable')
) "Native text regions are initialization-only"
Assert-Contract (
    $unitPowerProbeLua.Contains('local ok, percent = pcall(api.UnitPowerPercent') -and
    $unitPowerProbeLua.Contains('if ok then') -and
    -not $unitPowerProbeLua.Contains('if ok and percent then') -and
    $unitPowerProbeLua.Contains('rawValuesCollected = false')
) "UnitPowerPercent bypasses Lua boolean tests and raw export"
Assert-Contract (
    $auraContainerLua.Contains('maxCreatedContainerCount = 18') -and
    $auraContainerLua.Contains('"nativeReloadRequired"')
) "Native container creation has a per-load hard bound"
Assert-Contract (
    -not $auraCompilerLua.Contains('tostring(plan.revision)') -and
    $auraCompilerLua.Contains('tostring(plan.layout.elementWidth)')
) "Aura fingerprint ignores unrelated revision and includes structure"

$importerText = [System.IO.File]::ReadAllText($paths.Importer)
$buildFlagFunctionCount = [regex]::Matches(
    $importerText,
    '(?m)^\s*function\s+Get-RecomputedBuildFlags\s*\{'
).Count
$flowSchemaStageCount = [regex]::Matches(
    $importerText,
    '(?m)^\s*\$flowSchemaPath\s*=\s*Join-Path\b'
).Count
$rawBuildFlagStageCount = [regex]::Matches(
    $importerText,
    '(?m)^\s*\$rawBuildFlags\s*=\s*Get-RecomputedBuildFlags\b'
).Count
Assert-Contract (
    $buildFlagFunctionCount -eq 1 -and
    $flowSchemaStageCount -eq 1 -and
    $rawBuildFlagStageCount -eq 1
) "Importer validation stages are unique" (
    "buildFlagFunction=$buildFlagFunctionCount, flowSchema=$flowSchemaStageCount, rawBuildFlags=$rawBuildFlagStageCount"
)

$matrix = Read-Json $paths.MatrixData
$sessionLua = [System.IO.File]::ReadAllText($paths.SessionLua)
$caseMatches = [regex]::Matches($sessionLua, 'freeze\(\{\s*id\s*=\s*"(?<id>live\.[^"]+)",\s*category\s*=\s*"(?<category>[^"]+)"')
$luaCaseMap = @{}
foreach ($match in $caseMatches) {
    $luaCaseMap[$match.Groups["id"].Value] = $match.Groups["category"].Value
}
Assert-Contract ($luaCaseMap.Count -eq $matrix.cases.Count) "Lua live case count"
foreach ($case in $matrix.cases) {
    Assert-Contract ($luaCaseMap[[string]$case.id] -eq [string]$case.category) ("Live case mapping: " + $case.id)
}
Assert-Contract ($sessionLua.Contains("local MATRIX_VERSION = `"$($matrix.matrixVersion)`"")) "Live session matrix version"
$flowLua = [System.IO.File]::ReadAllText($paths.FlowLua)
Assert-Contract ($flowLua.Contains("matrixVersion = `"$($matrix.matrixVersion)`"")) "Flow report matrix version"

$continuity = Read-Json $paths.ContinuityData
$continuityRaw = [System.IO.File]::ReadAllText($paths.ContinuityData)
$continuityDoc = [System.IO.File]::ReadAllText($paths.ContinuityDoc)
$issueLog = [System.IO.File]::ReadAllText($paths.IssueLog)
$agentsText = [System.IO.File]::ReadAllText($paths.Agents)
$contextText = [System.IO.File]::ReadAllText($paths.Context)
Assert-Contract ($continuityDoc.Contains([string]$continuity.snapshotVersion)) "Continuity document snapshot version"
Assert-Contract ($agentsText.Contains("Docs/28_PROJECT_CONTINUITY.md") -and $agentsText.Contains("Data/ProjectContinuity.json")) "AGENTS continuity routes"
Assert-Contract ($contextText.Contains("Docs/28_PROJECT_CONTINUITY.md") -and $contextText.Contains("Data/ProjectContinuity.json")) "AI context continuity routes"
Assert-Contract ([string]$continuity.current.liveValidation.matrixVersion -eq [string]$matrix.matrixVersion) "Continuity live matrix version"
Assert-Contract ([int]$continuity.current.liveValidation.required -eq $matrix.cases.Count) "Continuity live case count"
$offlineTotal = [int]$continuity.current.offlineValidation.passed +
    [int]$continuity.current.offlineValidation.failed +
    [int]$continuity.current.offlineValidation.skipped +
    [int]$continuity.current.offlineValidation.pending
Assert-Contract ($offlineTotal -eq [int]$continuity.current.offlineValidation.total) "Continuity offline summary arithmetic"
Assert-Contract (-not [regex]::IsMatch($continuityRaw, '(?i)[A-Z]:[\\/]')) "Continuity excludes absolute drive paths"
Assert-Contract (-not [regex]::IsMatch($continuityRaw, '(?i)\\\\')) "Continuity excludes UNC paths"
Assert-Contract (-not [regex]::IsMatch($continuityRaw, '(?i)\b(?:WTF|Account|SavedVariables)\b')) "Continuity excludes private game data terms"

$factIds = @{}
foreach ($fact in $continuity.facts) {
    $factID = [string]$fact.id
    Assert-Contract (-not $factIds.ContainsKey($factID)) ("Continuity unique fact: " + $factID)
    $factIds[$factID] = $true
}
$inferenceIds = @{}
foreach ($inference in $continuity.inferences) {
    $inferenceID = [string]$inference.id
    Assert-Contract (-not $inferenceIds.ContainsKey($inferenceID)) ("Continuity unique inference: " + $inferenceID)
    $inferenceIds[$inferenceID] = $true
    foreach ($factID in $inference.basedOnFactIds) {
        Assert-Contract ($factIds.ContainsKey([string]$factID)) ("Continuity inference fact reference: " + $inferenceID + " -> " + $factID)
    }
}
$workIds = @{}
$issueIds = @{}
foreach ($workItem in $continuity.workItems) {
    $workID = [string]$workItem.id
    $issueID = [string]$workItem.issueId
    Assert-Contract (-not $workIds.ContainsKey($workID)) ("Continuity unique work item: " + $workID)
    Assert-Contract (-not $issueIds.ContainsKey($issueID)) ("Continuity unique work issue: " + $issueID)
    $workIds[$workID] = $true
    $issueIds[$issueID] = $true
    $headingPattern = '(?m)^### [^\r\n]*' + [regex]::Escape($issueID) + '：'
    Assert-Contract ([regex]::Matches($issueLog, $headingPattern).Count -eq 1) ("Continuity issue heading: " + $issueID)
    foreach ($clientField in @("ptr", "xptr", "retail")) {
        if ([string]$workItem.validation.$clientField -eq "pass") {
            $hasLiveEvidence = @($workItem.evidenceRefs | Where-Object { [string]$_ -like "live:*" }).Count -gt 0
            Assert-Contract $hasLiveEvidence ("Continuity live pass evidence: " + $workID + "/" + $clientField)
        }
    }
}
$trialIds = @{}
foreach ($trial in $continuity.trials) {
    $trialID = [string]$trial.id
    Assert-Contract (-not $trialIds.ContainsKey($trialID)) ("Continuity unique trial: " + $trialID)
    Assert-Contract ($issueIds.ContainsKey([string]$trial.issueId)) ("Continuity trial issue reference: " + $trialID)
    $trialIds[$trialID] = $true
}
$unverifiedIds = @{}
foreach ($item in $continuity.unverified) {
    $itemID = [string]$item.id
    Assert-Contract (-not $unverifiedIds.ContainsKey($itemID)) ("Continuity unique unverified item: " + $itemID)
    $unverifiedIds[$itemID] = $true
}

$temporaryRoot = Join-Path (
    [System.IO.Path]::GetTempPath()
) ("EAM_ValidationContracts_" + [guid]::NewGuid().ToString("N"))
[void][System.IO.Directory]::CreateDirectory($temporaryRoot)
$temporaryImportOutput = Join-Path $temporaryRoot "Imported"
$missingDataPath = Join-Path $temporaryRoot "schema-probe-missing.json"
$missingDataResult = Get-JsonSchemaRejectionResult `
    -DataPath $missingDataPath `
    -SchemaPath $paths.LiveSchema
Assert-Contract (
    $missingDataResult.ExpectedRejection -eq $false -and
    $missingDataResult.InfrastructureError -eq $true
) "Schema rejection classifier refuses missing-file infrastructure errors" $missingDataResult.Detail

$malformedSchemaPath = Join-Path $temporaryRoot "malformed-schema.json"
[System.IO.File]::WriteAllText(
    $malformedSchemaPath,
    '{"type":',
    [System.Text.UTF8Encoding]::new($false)
)
$malformedSchemaResult = Get-JsonSchemaRejectionResult `
    -DataPath $paths.LiveFixture `
    -SchemaPath $malformedSchemaPath
Assert-Contract (
    $malformedSchemaResult.ExpectedRejection -eq $false -and
    $malformedSchemaResult.InfrastructureError -eq $true
) "Schema rejection classifier refuses malformed-schema infrastructure errors" $malformedSchemaResult.Detail

if ($FlowReport -and (Test-Path -LiteralPath $FlowReport)) {
    Invoke-ImporterContract `
        -ImporterPath $paths.Importer `
        -DataPath $FlowReport `
        -ReportType Flow `
        -OutputDirectory $temporaryImportOutput `
        -ExpectedExitCode 0 `
        -Label "Importer accepts schema 2 Flow contract" `
        -ExpectedText "IMPORTED_VALIDATION_STATUS=pass"

    $flowRawFlagMismatch = Copy-JsonValue (Read-Json $FlowReport)
    $flowRawFlagMismatch.environment.buildFlags.isPublicTestClient = $false
    $flowRawFlagMismatch.environment.buildFlags.isTestBuild = $false
    $flowRawFlagMismatch.environment.buildFlags.isBetaBuild = $false
    $flowRawFlagMismatchPath = Join-Path $temporaryRoot "flow-schema2-raw-flag-mismatch.json"
    Write-JsonFixture $flowRawFlagMismatchPath $flowRawFlagMismatch
    Assert-JsonSchema `
        $flowRawFlagMismatchPath `
        $paths.FlowSchema `
        "Flow raw-flag mismatch remains structurally valid"
    Invoke-ImporterContract `
        -ImporterPath $paths.Importer `
        -DataPath $flowRawFlagMismatchPath `
        -ReportType Flow `
        -OutputDirectory $temporaryImportOutput `
        -ExpectedExitCode 1 `
        -Label "Importer rejects schema 2 Flow raw-flag mismatch" `
        -ExpectedText "Build flag aggregate mismatch"
}
$syntheticCases = @(
    foreach ($definition in $matrix.cases) {
        [ordered]@{
            id = [string]$definition.id
            category = [string]$definition.category
            required = $true
            status = "pass"
            note = "synthetic contract only"
        }
    }
)
$syntheticLivePass = [ordered]@{
    schema = 1
    type = "EAM_LIVE_VALIDATION_REPORT"
    purpose = "rqa-signoff"
    matrixVersion = [string]$matrix.matrixVersion
    status = "pass"
    session = [ordered]@{
        id = "EAM-RQA-SYNTHETIC-CONTRACT-NOT-LIVE"
        phase = "complete"
        reloadSequence = 1
        resumedAfterReload = $true
        humanObserved = $true
    }
    environment = [ordered]@{
        product = "wow_retail"
        executionSource = "client"
        clientChannel = "PTR"
        declaredInstallation = "_ptr_"
        declaredInstallationEvidence = "user-asserted"
        patch = "12.1.0"
        build = "synthetic-not-live"
        buildDate = "synthetic"
        interface = 120100
        targetInterface = 120100
        projectID = 1
        isTestBuild = $true
        isTestBuildKnown = $true
        buildFlags = [ordered]@{
            isPublicTestClient = $true
            isTestBuild = $true
            isBetaBuild = $false
        }
        locale = "zhTW"
        source = "ptr-live-manual"
        channelValidation = "pass"
    }
    automation = [ordered]@{
        gameInputAutomated = $false
        reloadUIAutomated = $false
        playerOperated = $true
    }
    capabilities = [ordered]@{
        syntheticContract = $true
    }
    summary = [ordered]@{
        total = $matrix.cases.Count
        required = $matrix.cases.Count
        passed = $matrix.cases.Count
        failed = 0
        blocked = 0
        pending = 0
    }
    cases = $syntheticCases
    boundaryWarnings = @()
}

$syntheticPassPath = Join-Path $temporaryRoot "live-pass-synthetic.json"
Write-JsonFixture $syntheticPassPath $syntheticLivePass
Assert-JsonSchema $syntheticPassPath $paths.LiveSchema "Synthetic complete Live pass JSON schema"
Invoke-ImporterContract `
    -ImporterPath $paths.Importer `
    -DataPath $syntheticPassPath `
    -ReportType Live `
    -OutputDirectory $temporaryImportOutput `
    -ExpectedExitCode 1 `
    -Label "Importer rejects synthetic Live contract" `
    -ExpectedText "Synthetic or mock Live payload cannot be imported as player evidence."

$noReload = Copy-JsonValue $syntheticLivePass
$noReload.session.reloadSequence = 0
$noReload.session.resumedAfterReload = $false
$noReloadPath = Join-Path $temporaryRoot "live-pass-without-reload.json"
Write-JsonFixture $noReloadPath $noReload
Assert-JsonSchemaRejected $noReloadPath $paths.LiveSchema "Schema rejects Live pass without reload evidence"
$noReloadRejectionResult = Get-JsonSchemaRejectionResult `
    -DataPath $noReloadPath `
    -SchemaPath $paths.LiveSchema
Assert-Contract (
    $noReloadRejectionResult.ExpectedRejection -eq $true -and
    $noReloadRejectionResult.InfrastructureError -eq $false
) "Schema rejection classifier accepts validation failures only" $noReloadRejectionResult.Detail
Invoke-ImporterContract `
    -ImporterPath $paths.Importer `
    -DataPath $noReloadPath `
    -ReportType Live `
    -OutputDirectory $temporaryImportOutput `
    -ExpectedExitCode 1 `
    -Label "Importer rejects Live pass without reload evidence" `
    -ExpectedText "schema validation failed"

$unknownIdentity = Copy-JsonValue $syntheticLivePass
$unknownIdentity.environment.isTestBuild = $false
$unknownIdentity.environment.isTestBuildKnown = $false
$unknownIdentity.environment.buildFlags.isPublicTestClient = "unknown"
$unknownIdentity.environment.buildFlags.isTestBuild = "unknown"
$unknownIdentity.environment.buildFlags.isBetaBuild = "unknown"
$unknownIdentityPath = Join-Path $temporaryRoot "live-pass-unknown-build-identity.json"
Write-JsonFixture $unknownIdentityPath $unknownIdentity
Assert-JsonSchemaRejected $unknownIdentityPath $paths.LiveSchema "Schema rejects Live pass with unknown build identity"
Invoke-ImporterContract `
    -ImporterPath $paths.Importer `
    -DataPath $unknownIdentityPath `
    -ReportType Live `
    -OutputDirectory $temporaryImportOutput `
    -ExpectedExitCode 1 `
    -Label "Importer rejects Live pass with unknown build identity" `
    -ExpectedText "schema validation failed"

$rawUnknownAggregate = Copy-JsonValue $syntheticLivePass
$rawUnknownAggregate.environment.buildFlags.isPublicTestClient = "unknown"
$rawUnknownAggregate.environment.buildFlags.isTestBuild = "unknown"
$rawUnknownAggregate.environment.buildFlags.isBetaBuild = "unknown"
$rawUnknownAggregatePath = Join-Path $temporaryRoot "live-pass-raw-unknown-aggregate-known.json"
Write-JsonFixture $rawUnknownAggregatePath $rawUnknownAggregate
Assert-JsonSchemaRejected $rawUnknownAggregatePath $paths.LiveSchema "Schema rejects Live pass whose raw build flags are all unknown"
Invoke-ImporterContract `
    -ImporterPath $paths.Importer `
    -DataPath $rawUnknownAggregatePath `
    -ReportType Live `
    -OutputDirectory $temporaryImportOutput `
    -ExpectedExitCode 1 `
    -Label "Importer rejects raw-unknown aggregate-known Live report" `
    -ExpectedText "schema validation failed"

$rawFalseAggregateTrue = Copy-JsonValue $syntheticLivePass
$rawFalseAggregateTrue.environment.buildFlags.isPublicTestClient = $false
$rawFalseAggregateTrue.environment.buildFlags.isTestBuild = $false
$rawFalseAggregateTrue.environment.buildFlags.isBetaBuild = $false
$rawFalseAggregateTruePath = Join-Path $temporaryRoot "live-pass-raw-false-aggregate-true.json"
Write-JsonFixture $rawFalseAggregateTruePath $rawFalseAggregateTrue
Assert-JsonSchema $rawFalseAggregateTruePath $paths.LiveSchema "Raw-false aggregate-true fixture remains structurally valid"
Invoke-ImporterContract `
    -ImporterPath $paths.Importer `
    -DataPath $rawFalseAggregateTruePath `
    -ReportType Live `
    -OutputDirectory $temporaryImportOutput `
    -ExpectedExitCode 1 `
    -Label "Importer rejects raw-false aggregate-true Live report" `
    -ExpectedText "Build flag aggregate mismatch"

$rawTrueAggregateFalse = Copy-JsonValue $syntheticLivePass
$rawTrueAggregateFalse.environment.isTestBuild = $false
$rawTrueAggregateFalse.environment.buildFlags.isPublicTestClient = $true
$rawTrueAggregateFalse.environment.buildFlags.isTestBuild = $false
$rawTrueAggregateFalse.environment.buildFlags.isBetaBuild = $false
$rawTrueAggregateFalsePath = Join-Path $temporaryRoot "live-pass-raw-true-aggregate-false.json"
Write-JsonFixture $rawTrueAggregateFalsePath $rawTrueAggregateFalse
Assert-JsonSchema $rawTrueAggregateFalsePath $paths.LiveSchema "Raw-true aggregate-false fixture remains structurally valid"
Invoke-ImporterContract `
    -ImporterPath $paths.Importer `
    -DataPath $rawTrueAggregateFalsePath `
    -ReportType Live `
    -OutputDirectory $temporaryImportOutput `
    -ExpectedExitCode 1 `
    -Label "Importer rejects raw-true aggregate-false Live report" `
    -ExpectedText "Build flag aggregate mismatch"

$privacyFixture = Copy-JsonValue $syntheticLivePass
$privacyFixture.status = "incomplete"
$privacyFixture.session.phase = "active"
$privacyFixture.boundaryWarnings = @("syntheticPrivacyFixture")
$privacyFixture.cases[0].note = "D:\World of Warcraft\_ptr_\WTF\Account\PRIVATE"
$privacyPath = Join-Path $temporaryRoot "live-private-path.json"
Write-JsonFixture $privacyPath $privacyFixture
Assert-JsonSchema $privacyPath $paths.LiveSchema "Privacy fixture remains structurally valid"
Invoke-ImporterContract `
    -ImporterPath $paths.Importer `
    -DataPath $privacyPath `
    -ReportType Live `
    -OutputDirectory $temporaryImportOutput `
    -ExpectedExitCode 1 `
    -Label "Importer rejects private path values" `
    -ExpectedText "Forbidden privacy value"

$deepPrivacyFixture = Copy-JsonValue $syntheticLivePass
$deepCapabilities = [ordered]@{}
$deepCursor = $deepCapabilities
for ($depth = 1; $depth -le 31; $depth++) {
    $nextLevel = [ordered]@{}
    $deepCursor["level$depth"] = $nextLevel
    $deepCursor = $nextLevel
}
$deepCursor["privatePath"] = "D:\World of Warcraft\_ptr_\WTF\Account\PRIVATE"
$deepPrivacyFixture.capabilities = $deepCapabilities
$deepPrivacyPath = Join-Path $temporaryRoot "live-private-path-over-depth-limit.json"
Write-JsonFixture $deepPrivacyPath $deepPrivacyFixture -Depth 100
Assert-JsonSchema $deepPrivacyPath $paths.LiveSchema "Deep privacy fixture remains structurally valid"
Invoke-ImporterContract `
    -ImporterPath $paths.Importer `
    -DataPath $deepPrivacyPath `
    -ReportType Live `
    -OutputDirectory $temporaryImportOutput `
    -ExpectedExitCode 1 `
    -Label "Importer rejects payloads beyond privacy scan depth" `
    -ExpectedText "Privacy scan depth exceeded"

$summaryMismatch = Copy-JsonValue $syntheticLivePass
$summaryMismatch.status = "incomplete"
$summaryMismatch.session.phase = "active"
$summaryMismatch.boundaryWarnings = @("syntheticSummaryFixture")
$summaryMismatch.summary.passed = 17
$summaryMismatch.summary.pending = 1
$summaryMismatchPath = Join-Path $temporaryRoot "live-summary-mismatch.json"
Write-JsonFixture $summaryMismatchPath $summaryMismatch
Assert-JsonSchema $summaryMismatchPath $paths.LiveSchema "Summary mismatch fixture remains structurally valid"
Invoke-ImporterContract `
    -ImporterPath $paths.Importer `
    -DataPath $summaryMismatchPath `
    -ReportType Live `
    -OutputDirectory $temporaryImportOutput `
    -ExpectedExitCode 1 `
    -Label "Importer rejects recomputed summary mismatch" `
    -ExpectedText "Summary mismatch"

$legacyFlow = [ordered]@{
    schema = 1
    type = "EAM_FLOW_VALIDATION_REPORT"
    status = "pass"
    suite = "all"
    generatedAtSessionMs = 0
    environment = [ordered]@{
        source = "retail-client"
        declaredInstallation = "_retail_"
        patch = "12.0.7"
        build = "synthetic-not-live"
        interface = 120007
    }
    cases = @(
        [ordered]@{
            id = "synthetic.legacy"
            suite = "core"
            status = "pass"
            completed = $true
            durationMs = 0
            message = "synthetic contract only"
        }
    )
    boundaryWarnings = @()
    summary = [ordered]@{
        total = 1
        passed = 1
        failed = 0
        skipped = 0
        pending = 0
    }
}
$legacyFlowPath = Join-Path $temporaryRoot "flow-schema1-legacy.json"
Write-JsonFixture $legacyFlowPath $legacyFlow
Invoke-ImporterContract `
    -ImporterPath $paths.Importer `
    -DataPath $legacyFlowPath `
    -ReportType Flow `
    -OutputDirectory $temporaryImportOutput `
    -ExpectedExitCode 1 `
    -Label "Importer refuses schema 1 Flow signoff" `
    -ExpectedText "IMPORTED_VALIDATION_SOURCE=legacy-unverified"

$featureLocaleKeys = @(
    "EAM_LIVE_CASE_AURA_SINGLE_COUNTDOWN",
    "EAM_LIVE_CASE_AURA_DUAL_COUNTDOWN",
    "EAM_LIVE_CASE_SPELL_COOLDOWN",
    "EAM_LIVE_CASE_ITEM_COOLDOWN",
    "EAM_LIVE_CASE_GROUND_AUTO",
    "EAM_LIVE_CASE_GROUND_FALLBACK",
    "EAM_LIVE_CASE_SWIPE_ALPHA",
    "EAM_LIVE_CASE_TARGET_AURA_TRANSITION",
    "EAM_LIVE_CASE_NATIVE_BORDER",
    "EAM_LIVE_CASE_UNITPOWER_SECONDARY",
    "EAM_LIVE_CASE_UNITPOWER_PRIMARY",
    "EAM_FLOW_BUTTON_DUAL_COUNTDOWN",
    "EAM_FLOW_BUTTON_DUAL_COUNTDOWN_OFF",
    "EAM_FLOW_DUAL_COUNTDOWN_UNAVAILABLE",
    "EAM_FLOW_DUAL_COUNTDOWN_RELOAD",
    "EAM_FLOW_DUAL_COUNTDOWN_ENABLED",
    "EAM_FLOW_DUAL_COUNTDOWN_DISABLED",
    "EAM_FLOW_BUTTON_UNIT_POWER",
    "EAM_FLOW_BUTTON_UNIT_POWER_STOP",
    "EAM_UNIT_POWER_PROBE_UNAVAILABLE",
    "EAM_UNIT_POWER_PROBE_START_FAILED",
    "EAM_UNIT_POWER_PROBE_RUNNING",
    "EAM_UNIT_POWER_PROBE_STOPPED",
    "EAM_UNIT_POWER_PROBE_TITLE",
    "EAM_UNIT_POWER_PROBE_PRIMARY",
    "EAM_UNIT_POWER_PROBE_SELECTED",
    "EAM_UNIT_POWER_PROBE_PASS",
    "EAM_UNIT_POWER_PROBE_FAIL",
    "EAM_UNIT_POWER_PROBE_BLOCKED"
)

foreach ($locale in "enUS", "zhTW", "zhCN", "koKR", "ruRU") {
    $localeText = [System.IO.File]::ReadAllText((Join-Path $root ("Locale\$locale.lua")))
    $missing = @($jsonPlacementIDs | Where-Object { -not $localeText.Contains("EAM_PLACEMENT_$_") })
    Assert-Contract ($missing.Count -eq 0) ("Locale placement keys: $locale") ($missing -join ", ")

    $featureViolations = @()
    foreach ($featureKey in $featureLocaleKeys) {
        $pattern = "(?m)^\s*L\." + [regex]::Escape($featureKey) + "\s*="
        $count = [regex]::Matches($localeText, $pattern).Count
        if ($count -ne 1) {
            $featureViolations += "$featureKey=$count"
        }
    }
    Assert-Contract ($featureViolations.Count -eq 0) ("Locale feature keys exactly once: $locale") ($featureViolations -join ", ")
}

$toc = [System.IO.File]::ReadAllText($paths.Toc)
$textPlacementIndex = $toc.IndexOf("UI\TextPlacement.lua")
$nativeRendererIndex = $toc.IndexOf("UI\NativeAuraRenderer.lua")
$rendererIndex = $toc.IndexOf("UI\Renderer.lua")
$validationEnvironmentIndex = $toc.IndexOf("Debug\ValidationEnvironment.lua")
$liveSessionIndex = $toc.IndexOf("Debug\LiveTestSession.lua")
$livePanelIndex = $toc.IndexOf("Debug\LiveTestPanel.lua")
Assert-Contract ($textPlacementIndex -ge 0 -and $textPlacementIndex -lt $nativeRendererIndex -and $textPlacementIndex -lt $rendererIndex) "TOC text placement load order"
Assert-Contract ($validationEnvironmentIndex -ge 0 -and $validationEnvironmentIndex -lt $liveSessionIndex -and $liveSessionIndex -lt $livePanelIndex) "TOC live validation load order"

$packageScriptText = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "Build-CurseForgePackage.ps1"))
$packageExtensionFilterValid = $packageScriptText.Contains('$extension = $_.Extension.ToLowerInvariant()') -and
    $packageScriptText.Contains('$extension -eq ".lua" -or $extension -eq ".xml"') -and
    -not $packageScriptText.Contains('-Include "*.lua", "*.xml"')
Assert-Contract $packageExtensionFilterValid "Package TOC consistency filters Lua/XML by extension"

foreach ($scriptName in "CheckLuaSyntax.ps1", "Run-FlowValidation.ps1", "Import-EAMFlowReport.ps1", "Test-ValidationContracts.ps1", "Build-CurseForgePackage.ps1") {
    $tokens = $null
    $errors = $null
    $scriptPath = Join-Path $PSScriptRoot $scriptName
    [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
    Assert-Contract ($errors.Count -eq 0) ("PowerShell AST: $scriptName") (($errors | ForEach-Object { $_.Message }) -join "; ")
}

Write-Host "VALIDATION_CONTRACTS passed=$passed failed=$($failures.Count)"
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Host "CONTRACT_FAILURE=$failure"
    }
    exit 1
}
