param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot ".."),
    [switch]$InstallIfMissing
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path $RepoRoot).Path
$settingsPath = Join-Path $repoRoot "PSScriptAnalyzerSettings.psd1"
if (!(Test-Path $settingsPath)) {
    Write-Host "Missing PSScriptAnalyzerSettings.psd1 at $settingsPath." -ForegroundColor Red
    exit 1
}

$module = Get-Module -ListAvailable -Name PSScriptAnalyzer | Sort-Object Version -Descending | Select-Object -First 1
if (-not $module) {
    if ($InstallIfMissing) {
        try {
            if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
                Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
            }
            Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -Repository PSGallery -AllowClobber -ErrorAction Stop | Out-Null
            $module = Get-Module -ListAvailable -Name PSScriptAnalyzer | Sort-Object Version -Descending | Select-Object -First 1
        } catch {
            Write-Host "Failed to install PSScriptAnalyzer: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "PSScriptAnalyzer is not installed. Re-run with -InstallIfMissing or install it manually:" -ForegroundColor Yellow
        Write-Host "  Install-Module PSScriptAnalyzer -Scope CurrentUser" -ForegroundColor Yellow
        exit 1
    }
}

Import-Module PSScriptAnalyzer -Force | Out-Null

$targets = @(
    Join-Path $repoRoot "src"
    Join-Path $repoRoot "tools"
    Join-Path $repoRoot "Wingetter.ps1"
)

$diagnostics = New-Object System.Collections.Generic.List[object]
foreach ($target in $targets) {
    if (!(Test-Path $target)) { continue }
    $isDir = (Get-Item $target).PSIsContainer
    $analyzeArgs = @{
        Path     = $target
        Settings = $settingsPath
    }
    if ($isDir) { $analyzeArgs["Recurse"] = $true }
    $results = Invoke-ScriptAnalyzer @analyzeArgs
    foreach ($r in $results) { $diagnostics.Add($r) | Out-Null }
}

if ($diagnostics.Count -eq 0) {
    Write-Host "PSScriptAnalyzer validation passed (analyzer $($module.Version))."
    exit 0
}

Write-Host "PSScriptAnalyzer reported $($diagnostics.Count) finding(s):" -ForegroundColor Red
$diagnostics |
    Sort-Object Severity, ScriptName, Line |
    ForEach-Object {
        $location = "$($_.ScriptName):$($_.Line):$($_.Column)"
        Write-Host (" - [{0}] {1} {2} :: {3}" -f $_.Severity, $_.RuleName, $location, $_.Message) -ForegroundColor Red
    }
exit 1
