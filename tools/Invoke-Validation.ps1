param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot ".."),
    [switch]$SkipAnalyzerInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path $RepoRoot).Path
$windowsPowerShell = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if (!(Test-Path $windowsPowerShell)) {
    $windowsPowerShell = (Get-Process -Id $PID).Path
}

$failures = New-Object System.Collections.Generic.List[string]

function Invoke-WingetterValidationStep {
    param(
        [string]$Name,
        [string]$RelativePath,
        [string[]]$Arguments = @(),
        [switch]$UseSta
    )

    $scriptPath = Join-Path $script:repoRoot $RelativePath
    if (!(Test-Path $scriptPath)) {
        $script:failures.Add("Missing validation script '$RelativePath'.")
        return
    }

    Write-Host ""
    Write-Host "==> $Name" -ForegroundColor Cyan

    $powerShellArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass")
    if ($UseSta) { $powerShellArgs += "-STA" }
    $powerShellArgs += @("-File", $scriptPath)
    $powerShellArgs += $Arguments

    & $script:windowsPowerShell @powerShellArgs
    $exitCode = if ($null -ne $global:LASTEXITCODE) { [int]$global:LASTEXITCODE } else { 0 }
    if ($exitCode -ne 0) {
        $script:failures.Add("$Name failed with exit code $exitCode.")
    }
}

$analyzerArguments = @()
if (-not $SkipAnalyzerInstall) {
    $analyzerArguments += "-InstallIfMissing"
}

$steps = @(
    @{ Name = "Catalog"; RelativePath = "tools\Test-Catalog.ps1" },
    @{ Name = "Profile JSON"; RelativePath = "tools\Test-ProfileJson.ps1" },
    @{ Name = "Profile Gallery"; RelativePath = "tools\Test-ProfileGallery.ps1" },
    @{ Name = "WinGet Runner"; RelativePath = "tools\Test-WinGetRunner.ps1" },
    @{ Name = "Search Metadata"; RelativePath = "tools\Test-SearchMetadata.ps1" },
    @{ Name = "Package Sources"; RelativePath = "tools\Test-PackageSources.ps1" },
    @{ Name = "Source Policy"; RelativePath = "tools\Test-SourcePolicy.ps1" },
    @{ Name = "Update Watcher"; RelativePath = "tools\Test-UpdateWatcher.ps1" },
    @{ Name = "Offline Cache"; RelativePath = "tools\Test-OfflineCache.ps1" },
    @{ Name = "WinGet Configuration"; RelativePath = "tools\Test-ConfigurationExport.ps1" },
    @{ Name = "Visual Accessibility"; RelativePath = "tools\Test-VisualAccessibility.ps1" },
    @{ Name = "UI Smoke"; RelativePath = "tools\Test-UiSmoke.ps1"; UseSta = $true },
    @{ Name = "Release Artifact"; RelativePath = "tools\Test-ReleaseArtifact.ps1" },
    @{ Name = "Launcher Manifest"; RelativePath = "tools\Test-LauncherManifest.ps1" },
    @{ Name = "Bundle"; RelativePath = "tools\Test-Bundle.ps1" },
    @{ Name = "XAML"; RelativePath = "tools\Test-Xaml.ps1"; UseSta = $true },
    @{ Name = "PSScriptAnalyzer"; RelativePath = "tools\Test-Analyzer.ps1"; Arguments = $analyzerArguments }
)

foreach ($step in $steps) {
    $arguments = if ($step.ContainsKey("Arguments")) { [string[]]$step.Arguments } else { @() }
    $useSta = $step.ContainsKey("UseSta") -and [bool]$step.UseSta
    Invoke-WingetterValidationStep -Name $step.Name -RelativePath $step.RelativePath -Arguments $arguments -UseSta:$useSta
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "Wingetter validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Wingetter validation passed ($($steps.Count) checks)." -ForegroundColor Green
