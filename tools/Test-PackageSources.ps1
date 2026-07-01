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
    "Wingetter.Sources.ps1",
    "Wingetter.Scoop.ps1"
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
    $requiredOperations = @(
        "TestAvailability",
        "InstallManager",
        "Search",
        "GetDetails",
        "Install",
        "Upgrade",
        "Uninstall",
        "ExportProfile",
        "ImportProfile",
        "GetInstalledCatalogPackages",
        "GetPinStatus",
        "InvokePinOperation",
        "GetInstallCommand"
    )

    $adapter = Get-WingetterPackageSourceAdapter -Name "winget"
    if ($adapter.Name -ne "winget" -or $adapter.DisplayName -ne "Windows Package Manager") {
        Add-Failure "WinGet adapter identity was not registered correctly."
    }
    foreach ($operation in $requiredOperations) {
        if (@($adapter.Operations.Keys) -notcontains $operation) {
            Add-Failure "WinGet adapter is missing operation '$operation'."
        }
    }
    foreach ($capability in @("Search", "Details", "Install", "Upgrade", "Uninstall", "ExportProfile", "ImportProfile", "InstalledScan", "Pin", "Hold", "Bootstrap", "CommandPreview")) {
        if (!$adapter.Capabilities.Contains($capability) -or !$adapter.Capabilities[$capability]) {
            Add-Failure "WinGet adapter is missing capability '$capability'."
        }
    }

    $installCommand = Get-WingetterPackageSourceInstallCommand -SourceAdapter $adapter -PackageId "Google.Chrome" -Silent $true -AcceptAgreements $true
    foreach ($expected in @("winget install", "--id Google.Chrome", "--exact", "--verbose-logs", "--disable-interactivity", "--silent", "--accept-package-agreements", "--accept-source-agreements")) {
        if ($installCommand -notlike "*$expected*") {
            Add-Failure "Install command did not include '$expected': $installCommand"
        }
    }
    if ($installCommand -like "*--include-pinned*") {
        Add-Failure "Install command unexpectedly included --include-pinned."
    }
    $optionInstallCommand = Get-WingetterPackageSourceInstallCommand `
        -SourceAdapter $adapter `
        -PackageId "Example.Tool" `
        -SourceName "corp" `
        -Silent $false `
        -AcceptAgreements $true `
        -InstallOptions ([PSCustomObject]@{ Scope = "machine"; Location = "C:\Program Files\Example Tool" })
    foreach ($expected in @("--source corp", "--scope machine", '--location "C:\Program Files\Example Tool"')) {
        if ($optionInstallCommand -notlike "*$expected*") {
            Add-Failure "Install command with options did not include '$expected': $optionInstallCommand"
        }
    }

    $badAdapterRejected = $false
    try {
        New-WingetterPackageSourceAdapter -Name "broken" -DisplayName "Broken" -Operations @{ Search = {} } | Out-Null
    } catch {
        $badAdapterRejected = $true
    }
    if (!$badAdapterRejected) {
        Add-Failure "Adapter validation did not reject a missing operation contract."
    }

    $fakeOperations = @{}
    foreach ($operation in $requiredOperations) {
        $fakeOperations[$operation] = { "ok" }
    }
    $fakeAdapter = New-WingetterPackageSourceAdapter -Name "fake" -DisplayName "Fake Source" -CommandName "fake" -Capabilities @{ Search = $true } -Operations $fakeOperations
    Register-WingetterPackageSourceAdapter -Adapter $fakeAdapter | Out-Null
    $registeredFake = Get-WingetterPackageSourceAdapter -Name "fake"
    if ($registeredFake.DisplayName -ne "Fake Source") {
        Add-Failure "Package source adapter registration did not retain the fake adapter."
    }

    $scoopAdapter = Get-WingetterPackageSourceAdapter -Name "scoop"
    if ($scoopAdapter.Name -ne "scoop" -or $scoopAdapter.DisplayName -ne "Scoop") {
        Add-Failure "Scoop adapter identity was not registered correctly."
    }
    foreach ($operation in $requiredOperations) {
        if (@($scoopAdapter.Operations.Keys) -notcontains $operation) {
            Add-Failure "Scoop adapter is missing operation '$operation'."
        }
    }
    if ($scoopAdapter.Capabilities["InstalledScan"] -ne $true) {
        Add-Failure "Scoop adapter should have InstalledScan capability."
    }
    foreach ($readOnlyCap in @("Install", "Upgrade", "Uninstall")) {
        if ($scoopAdapter.Capabilities[$readOnlyCap]) {
            Add-Failure "Scoop adapter should NOT have $readOnlyCap capability (read-only)."
        }
    }
    $scoopAvailability = Invoke-WingetterPackageSourceOperation -SourceAdapter $scoopAdapter -Operation "TestAvailability"
    if ($scoopAvailability.Status -notin @("Available", "Missing")) {
        Add-Failure "Scoop availability returned unexpected status: $($scoopAvailability.Status)"
    }

    $missingOperationRejected = $false
    try {
        Invoke-WingetterPackageSourceOperation -SourceAdapter $adapter -Operation "MissingOperation" | Out-Null
    } catch {
        $missingOperationRejected = $true
    }
    if (!$missingOperationRejected) {
        Add-Failure "Missing source operation did not throw."
    }

    $uiModulePath = Join-Path $SourceDir "Wingetter.Ui.ps1"
    if (Test-Path $uiModulePath) {
        $uiText = Get-Content -Path $uiModulePath -Raw
        foreach ($forbidden in @(
            "Get-WinGetPackageDetails",
            "Get-WinGetPinStatus",
            "Invoke-WinGetPinOperation",
            "Invoke-WinGetPackageOperation",
            "Get-WinGetInstalledCatalogPackages",
            "Test-WinGet",
            "Install-WinGet",
            "Export-GroupAsWinGetJSON",
            "Import-PackageIdsFromJSON"
        )) {
            if ($uiText -match "\b$([regex]::Escape($forbidden))\b") {
                Add-Failure "UI module calls WinGet helper '$forbidden' directly instead of the source adapter."
            }
        }
    } else {
        Add-Failure "Missing UI module for source-adapter boundary check."
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Package source validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Package source validation passed."
