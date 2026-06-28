param(
    [string]$SourceDir = (Join-Path $PSScriptRoot "..\src"),
    [switch]$ValidateWithWinget
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
}

foreach ($moduleName in @("Wingetter.Common.ps1", "Wingetter.Configuration.ps1")) {
    $modulePath = Join-Path $SourceDir $moduleName
    if (!(Test-Path $modulePath)) {
        Add-Failure "Missing source module '$moduleName'."
    } else {
        try {
            . (Resolve-Path $modulePath).Path
        } catch {
            Add-Failure "Could not import '$moduleName': $($_.Exception.Message)"
        }
    }
}

if ($failures.Count -eq 0) {
    $entries = @(
        (New-WingetterConfigurationPackageEntry -Name "Google Chrome" -PackageId "Google.Chrome" -SourceName "winget"),
        (New-WingetterConfigurationPackageEntry -Name "Internal Tool" -PackageId "Internal.Tool" -SourceName "corp")
    )
    $yaml = ConvertTo-WingetterConfigurationYaml -PackageEntries $entries
    foreach ($expected in @(
        "# yaml-language-server: `$schema=https://aka.ms/configuration-dsc-schema/0.2",
        "resource: Microsoft.WinGet.DSC/WinGetPackage",
        "configurationVersion: 0.2.0",
        "id: 'Google.Chrome'",
        "source: 'corp'"
    )) {
        if ($yaml -notlike "*$expected*") {
            Add-Failure "Configuration YAML did not include '$expected'."
        }
    }
    $versionYaml = ConvertTo-WingetterConfigurationYaml -PackageEntries @(
        (New-WingetterConfigurationPackageEntry -Name "Pinned Tool" -PackageId "Example.Tool" -SourceName "winget" -InstallOptions ([PSCustomObject]@{ Version = "1.2.3"; Scope = "machine" }))
    )
    if ($versionYaml -notlike "*version: '1.2.3'*") {
        Add-Failure "Configuration YAML did not preserve per-package version install option."
    }
    if ($versionYaml -like "*scope:*") {
        Add-Failure "Configuration YAML should not invent unsupported scope settings."
    }

    # Names with embedded newlines must be flattened so the generated YAML
    # stays parseable (single-quoted YAML scalars cannot contain raw newlines).
    $newlineEntries = @(
        New-WingetterConfigurationPackageEntry -Name "Multi`r`nLine Tool" -PackageId "Multi.Tool" -SourceName "winget"
    )
    $newlineYaml = ConvertTo-WingetterConfigurationYaml -PackageEntries $newlineEntries
    if ($newlineYaml -match "Install Multi\s+Line Tool[\r\n]+'") {
        # The newline should be collapsed to a single space, never preserved
        # inside the quoted scalar; this regex catches the broken shape.
        Add-Failure "Configuration YAML preserved a raw newline inside a single-quoted scalar."
    }
    if ($newlineYaml -notmatch "Multi Line Tool") {
        Add-Failure "Configuration YAML did not collapse a CR/LF in the package name."
    }

    # Invalid package identifiers must be rejected up-front so the YAML cannot
    # contain attacker-controlled characters.
    foreach ($badId in @("Bad Id With Space", "Bad;Id", "../Escape", "Bad`nNewline")) {
        $rejected = $false
        try {
            ConvertTo-WingetterConfigurationYaml -PackageEntries @(
                New-WingetterConfigurationPackageEntry -Name "Bad" -PackageId $badId -SourceName "winget"
            ) | Out-Null
        } catch {
            $rejected = $_.Exception.Message -match "not valid in a WinGet Configuration"
        }
        if (-not $rejected) {
            Add-Failure "Configuration YAML accepted an invalid package identifier: '$badId'"
        }
    }
    # And confirm the helper still accepts well-formed identifiers.
    if (-not (Test-WingetterConfigurationPackageId -PackageId "7zip.7zip")) {
        Add-Failure "Test-WingetterConfigurationPackageId rejected a known-good identifier '7zip.7zip'."
    }
    if (Test-WingetterConfigurationPackageId -PackageId "") {
        Add-Failure "Test-WingetterConfigurationPackageId accepted an empty identifier."
    }

    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-config-" + [System.Guid]::NewGuid().ToString("N") + ".winget")
    try {
        Export-WingetterConfigurationFile -PackageEntries $entries -FilePath $tempPath | Out-Null
        if (!(Test-Path $tempPath)) {
            Add-Failure "Configuration export did not write a file."
        }
        if ($ValidateWithWinget) {
            $winget = Get-Command winget -ErrorAction SilentlyContinue
            if (!$winget) {
                Add-Failure "winget configure validation was requested, but winget is unavailable."
            } else {
                $wingetValidationEntries = @(
                    New-WingetterConfigurationPackageEntry -Name "PowerShell" -PackageId "Microsoft.PowerShell" -SourceName "winget"
                )
                Export-WingetterConfigurationFile -PackageEntries $wingetValidationEntries -FilePath $tempPath | Out-Null
                & winget configure validate -f $tempPath --disable-interactivity | Out-Host
                if ($LASTEXITCODE -ne 0) {
                    Add-Failure "winget configure validate failed with exit code $LASTEXITCODE."
                }
            }
        }
    } finally {
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    Write-Host "WinGet Configuration export validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "WinGet Configuration export validation passed."
