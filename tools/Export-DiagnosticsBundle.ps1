param(
    [string]$OutputPath = "",
    [string]$SourceDir = (Join-Path $PSScriptRoot "..\src"),
    [switch]$SkipLiveWinGet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

foreach ($moduleName in @(
    "Wingetter.Common.ps1",
    "Wingetter.Catalog.ps1",
    "Wingetter.WinGet.ps1",
    "Wingetter.Groups.ps1",
    "Wingetter.Sources.ps1",
    "Wingetter.UpdateWatcher.ps1",
    "Wingetter.Diagnostics.ps1"
)) {
    . (Resolve-Path -LiteralPath (Join-Path $SourceDir $moduleName)).Path
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Get-WingetterDiagnosticsDefaultOutputPath
}

$result = Export-WingetterDiagnosticsBundle -OutputPath $OutputPath -SkipLiveWinGet:$SkipLiveWinGet
Write-Host "Wingetter diagnostics bundle exported to $($result.ZipPath)"
