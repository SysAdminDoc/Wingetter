param(
    [string]$SourceDir = (Join-Path $PSScriptRoot "..\src")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
}

foreach ($moduleName in @(
    "Wingetter.Common.ps1",
    "Wingetter.Catalog.ps1",
    "Wingetter.WinGet.ps1",
    "Wingetter.Groups.ps1",
    "Wingetter.Sources.ps1"
)) {
    $modulePath = Join-Path $SourceDir $moduleName
    if (!(Test-Path $modulePath)) {
        Add-Failure "Missing source module '$moduleName'."
        continue
    }
    try {
        . (Resolve-Path $modulePath).Path
    } catch {
        Add-Failure "Could not import source module '$moduleName': $($_.Exception.Message)"
    }
}

if ($failures.Count -eq 0) {
    $defaultPolicy = New-WingetterDefaultSourcePolicy
    $defaultCheck = Test-WingetterPackageAllowedBySourcePolicy -Policy $defaultPolicy -PackageId "Google.Chrome" -SourceName "unlisted"
    if (!$defaultCheck.Allowed) {
        Add-Failure "Default policy should allow packages while corporate mode is disabled."
    }

    $privateSource = New-WingetterPrivateRestSourceDefinition -Name "corp" -Argument "https://packages.example.test/api" -Header "Authorization=Bearer example"
    if ($privateSource.Type -ne "Microsoft.Rest" -or !$privateSource.Explicit -or !$privateSource.Private) {
        Add-Failure "Private REST source definition did not preserve Microsoft.Rest explicit/private metadata."
    }

    $policy = New-WingetterDefaultSourcePolicy
    $policy.CorporateMode = $true
    $policy.AllowedSources = @($privateSource)
    $policy.PrivateSources = @($privateSource)

    $blocked = Test-WingetterPackageAllowedBySourcePolicy -Policy $policy -PackageId "Google.Chrome" -SourceName "winget"
    if ($blocked.Allowed) {
        Add-Failure "Corporate source policy did not block an unlisted source."
    }
    $allowed = Test-WingetterPackageAllowedBySourcePolicy -Policy $policy -PackageId "Internal.Tool" -SourceName "corp"
    if (!$allowed.Allowed -or $allowed.TrustLevel -ne "Private" -or $allowed.SourceType -ne "Microsoft.Rest") {
        Add-Failure "Corporate source policy did not allow the private REST source."
    }

    $placeholder = Get-WingetterRedactedSourceHeaderPlaceholder

    $command = New-WingetterWinGetSourceAddCommand -Source $privateSource
    foreach ($expected in @("winget source add", "--name corp", "--arg https://packages.example.test/api", "--type Microsoft.Rest", "--trust-level trusted", "--explicit", "--header", "--accept-source-agreements", "--disable-interactivity")) {
        if ($command -notlike "*$expected*") {
            Add-Failure "Private source add command did not include '$expected': $command"
        }
    }
    if ($command -like "*Authorization=Bearer example*") {
        Add-Failure "Default private source add command leaked the raw header: $command"
    }
    if ($command -notlike "*$placeholder*") {
        Add-Failure "Default private source add command did not include the redacted header placeholder: $command"
    }

    $rawCommand = New-WingetterWinGetSourceAddCommand -Source $privateSource -IncludeRawHeader
    if ($rawCommand -notlike "*Authorization=Bearer example*") {
        Add-Failure "Explicit raw private source add command did not include the raw header: $rawCommand"
    }

    $prioritySource = New-WingetterSourceDefinition -Name "winget" -Type "Microsoft.PreIndexed.Package" -Argument "https://cdn.winget.microsoft.com/cache" -TrustLevel "Trusted" -Priority 10
    $priorityCommand = New-WingetterWinGetSourceAddCommand -Source $prioritySource -WinGetVersion "v1.29.280"
    if ($priorityCommand -notlike "*--priority 10*") {
        Add-Failure "WinGet 1.29 source add command did not include source priority: $priorityCommand"
    }
    $legacyPriorityCommand = New-WingetterWinGetSourceAddCommand -Source $prioritySource -WinGetVersion "v1.28.240"
    if ($legacyPriorityCommand -like "*--priority*") {
        Add-Failure "WinGet 1.28 source add command should not include unsupported source priority: $legacyPriorityCommand"
    }

    $adapter = Get-WingetterPackageSourceAdapter -Name "winget"
    $installCommand = Get-WingetterPackageSourceInstallCommand -SourceAdapter $adapter -PackageId "Internal.Tool" -SourceName "corp" -Silent $false -AcceptAgreements $true
    if ($installCommand -notlike "*--source corp*") {
        Add-Failure "Adapter install command did not include explicit source: $installCommand"
    }

    $catalogEntry = @{
        Name     = "Internal Tool"
        WingetId = "Internal.Tool"
        Source   = "corp"
    }
    if ((Get-WingetterPackageCatalogSourceName -App $catalogEntry -DefaultSource "winget") -ne "corp") {
        Add-Failure "Catalog source extraction did not read hashtable Source."
    }

    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-source-policy-" + [System.Guid]::NewGuid().ToString("N") + ".json")
    try {
        $policy.AllowedSources = @($prioritySource)
        $policy.PrivateSources = @($privateSource)
        $saved = Save-WingetterSourcePolicy -Policy $policy -Path $tempPath
        $loaded = Get-WingetterSourcePolicy -Path $tempPath
        if (!$loaded.CorporateMode -or @($loaded.PrivateSources).Count -ne 1 -or $loaded.PrivateSources[0].Name -ne "corp" -or $loaded.AllowedSources[0].Priority -ne 10) {
            Add-Failure "Source policy save/load did not preserve corporate private source state and priority."
        }

        $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-source-policy-export-" + [System.Guid]::NewGuid().ToString("N") + ".json")
        $rawExportPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-source-policy-raw-export-" + [System.Guid]::NewGuid().ToString("N") + ".json")
        $export = Export-WingetterSourcePolicy -Policy $saved -FilePath $exportPath -WinGetVersion "v1.29.280"
        $privateExportCommand = @($export.SourceAddCommands | Where-Object { $_ -like "*Microsoft.Rest*" } | Select-Object -First 1)
        if (!(Test-Path $exportPath) -or @($export.SourceAddCommands).Count -eq 0 -or !$privateExportCommand) {
            Add-Failure "Source policy export did not write source add commands."
        }
        $exportJson = Get-Content -Path $exportPath -Raw
        if ($exportJson -like "*Authorization=Bearer example*") {
            Add-Failure "Default source policy export leaked the raw private header."
        }
        if (!$export.HeadersRedacted -or $export.HeaderPlaceholder -ne $placeholder) {
            Add-Failure "Default source policy export did not mark headers as redacted."
        }
        if ($export.PrivateSources[0].Header -ne $placeholder) {
            Add-Failure "Default source policy export did not redact the PrivateSources header."
        }
        if ($privateExportCommand -notlike "*$placeholder*") {
            Add-Failure "Default source policy export command did not include the header placeholder."
        }
        if (@($export.SourceAddCommands | Where-Object { $_ -like "*--priority 10*" }).Count -ne 1) {
            Add-Failure "Source policy export did not include priority-aware winget source command."
        }

        $rawExport = Export-WingetterSourcePolicy -Policy $saved -FilePath $rawExportPath -IncludeRawHeaders
        $rawExportJson = Get-Content -Path $rawExportPath -Raw
        $rawPrivateExportCommand = @($rawExport.SourceAddCommands | Where-Object { $_ -like "*Microsoft.Rest*" } | Select-Object -First 1)
        if ($rawExport.HeadersRedacted -or $rawExportJson -notlike "*Authorization=Bearer example*" -or $rawPrivateExportCommand -notlike "*Authorization=Bearer example*") {
            Add-Failure "Explicit raw source policy export did not preserve the private header."
        }
        Remove-Item -Path $exportPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $rawExportPath -Force -ErrorAction SilentlyContinue
    } finally {
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    }

    $sourceListText = @"
Name    Argument                                      Type                          Explicit  TrustLevel  Priority
---------------------------------------------------------------------------------------------------------------
winget  https://changed.example.test/cache             Microsoft.PreIndexed.Package  true      Private     5
extra   https://extra.example.test/cache               Microsoft.PreIndexed.Package  false     Community   30
"@
    $liveSources = ConvertFrom-WingetterWinGetSourceListText -Text $sourceListText
    if (@($liveSources).Count -ne 2 -or $liveSources[0].Priority -ne 5 -or $liveSources[0].Explicit -ne $true) {
        Add-Failure "WinGet source list parser did not preserve priority and explicit fields."
    }
    $driftPolicy = [PSCustomObject]@{
        CorporateMode        = $true
        RequireAllowedSource = $true
        AllowedSources       = @($prioritySource, $privateSource)
        PrivateSources       = @()
    }
    $drift = Compare-WingetterSourcePolicyDrift -Policy $driftPolicy -LiveSources $liveSources
    $wingetDrift = @($drift.Items | Where-Object { $_.Name -eq "winget" } | Select-Object -First 1)
    if (!$wingetDrift -or $wingetDrift.Status -ne "Changed" -or $wingetDrift.Differences -notcontains "priority" -or $wingetDrift.Differences -notcontains "explicit" -or $wingetDrift.Differences -notcontains "trust") {
        Add-Failure "Source drift did not report changed priority/explicit/trust fields for winget."
    }
    if ($drift.Summary.missing -ne 1 -or $drift.Summary.extra -ne 1 -or $drift.Summary.changed -ne 1) {
        Add-Failure "Source drift summary did not report missing/extra/changed counts."
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Source policy validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Source policy validation passed."
