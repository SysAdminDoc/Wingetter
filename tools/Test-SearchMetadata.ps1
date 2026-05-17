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

foreach ($moduleName in @("Wingetter.Common.ps1", "Wingetter.Catalog.ps1")) {
    $modulePath = Join-Path $SourceDir $moduleName
    if (!(Test-Path $modulePath)) {
        Add-Failure "Missing source module '$moduleName'."
        continue
    }
    try {
        . (Resolve-Path $modulePath).Path
    } catch {
        Add-Failure "Could not import '$moduleName': $($_.Exception.Message)"
    }
}

if ($failures.Count -eq 0) {
    $cases = @(
        @{
            Name = "category plus group tokens"
            Query = "vpn privacy"
            Args = @{
                Name = "Mullvad VPN"; WingetId = "MullvadVPN.MullvadVPN"; Category = "VPN & Privacy"; Groups = @("Privacy & Security")
            }
        },
        @{
            Name = "developer language intent"
            Query = "developer python"
            Args = @{
                Name = "Python"; WingetId = "Python.Python.3.12"; Category = "Developer Tools"; Groups = @("Python Developer")
            }
        },
        @{
            Name = "publisher-like id token"
            Query = "google"
            Args = @{
                Name = "Chrome"; WingetId = "Google.Chrome"; Category = "Web Browsers"; Groups = @()
            }
        },
        @{
            Name = "source scope and state"
            Query = "winget machine update"
            Args = @{
                Name = "PowerShell"; WingetId = "Microsoft.PowerShell"; Category = "Developer Tools"; Groups = @(); Source = "winget"; Scope = "machine"; IsInstalled = $true; IsUpdateAvailable = $true
            }
        }
    )

    foreach ($case in $cases) {
        $parameters = $case.Args
        $score = Get-WingetterSearchScore -Query $case.Query @parameters
        if ($score -le 0) {
            Add-Failure "Search case '$($case.Name)' did not match query '$($case.Query)'."
        }
    }

    $miss = Get-WingetterSearchScore -Query "definitely absent" -Name "Chrome" -WingetId "Google.Chrome" -Category "Web Browsers" -Groups @()
    if ($miss -ne 0) {
        Add-Failure "Unrelated search query unexpectedly matched."
    }

    $direct = Get-WingetterSearchScore -Query "chrome" -Name "Google Chrome" -WingetId "Google.Chrome" -Category "Web Browsers" -Groups @()
    $categoryOnly = Get-WingetterSearchScore -Query "browser" -Name "Google Chrome" -WingetId "Google.Chrome" -Category "Web Browsers" -Groups @()
    if ($direct -le $categoryOnly) {
        Add-Failure "Direct name matches should rank above category-only matches."
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Search metadata validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Search metadata validation passed."
