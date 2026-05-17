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

$modulePath = Join-Path $SourceDir "Wingetter.Configuration.ps1"
if (!(Test-Path $modulePath)) {
    Add-Failure "Missing source module 'Wingetter.Configuration.ps1'."
} else {
    try {
        . (Resolve-Path $modulePath).Path
    } catch {
        Add-Failure "Could not import 'Wingetter.Configuration.ps1': $($_.Exception.Message)"
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
