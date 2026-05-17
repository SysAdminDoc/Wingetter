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

    $command = New-WingetterWinGetSourceAddCommand -Source $privateSource
    foreach ($expected in @("winget source add", "--name corp", "--arg https://packages.example.test/api", "--type Microsoft.Rest", "--trust-level trusted", "--explicit", "--header", "--accept-source-agreements", "--disable-interactivity")) {
        if ($command -notlike "*$expected*") {
            Add-Failure "Private source add command did not include '$expected': $command"
        }
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
        $saved = Save-WingetterSourcePolicy -Policy $policy -Path $tempPath
        $loaded = Get-WingetterSourcePolicy -Path $tempPath
        if (!$loaded.CorporateMode -or @($loaded.PrivateSources).Count -ne 1 -or $loaded.PrivateSources[0].Name -ne "corp") {
            Add-Failure "Source policy save/load did not preserve corporate private source state."
        }

        $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-source-policy-export-" + [System.Guid]::NewGuid().ToString("N") + ".json")
        $export = Export-WingetterSourcePolicy -Policy $saved -FilePath $exportPath
        if (!(Test-Path $exportPath) -or @($export.SourceAddCommands).Count -eq 0 -or $export.SourceAddCommands[0] -notlike "*Microsoft.Rest*") {
            Add-Failure "Source policy export did not write source add commands."
        }
        Remove-Item -Path $exportPath -Force -ErrorAction SilentlyContinue
    } finally {
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
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
