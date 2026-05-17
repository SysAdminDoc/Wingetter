param(
    [string]$UiModulePath = (Join-Path $PSScriptRoot "..\src\Wingetter.Ui.ps1")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
}

if (!(Test-Path $UiModulePath)) {
    Add-Failure "Missing UI module: $UiModulePath"
} else {
    $text = Get-Content -Path $UiModulePath -Raw

    if ($text -match 'CornerRadius\s*=\s*"?999') {
        Add-Failure "UI still contains XAML pill CornerRadius=999."
    }
    if ($text -match 'CornerRadius\]::new\(999\)') {
        Add-Failure "UI still contains generated pill CornerRadius=999."
    }
    foreach ($required in @(
        'AutomationProperties.Name="Switch between dark and light mode"',
        'AutomationProperties.Name="Search apps by name, package ID, category, group, source, or state"'
    )) {
        if ($text -notmatch [regex]::Escape($required)) {
            Add-Failure "Missing accessibility metadata: $required"
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Visual/accessibility validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Visual/accessibility validation passed."
