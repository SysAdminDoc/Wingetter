param(
    [switch]$SkipMeteredNetwork,
    [switch]$Toast,
    [int]$KeepLogs = 30,
    [string]$LogRoot = "",
    [string]$UpdatePolicyPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceDir = Join-Path $PSScriptRoot "..\src"
foreach ($moduleName in @(
    "Wingetter.Common.ps1",
    "Wingetter.Catalog.ps1",
    "Wingetter.WinGet.ps1",
    "Wingetter.Groups.ps1",
    "Wingetter.Sources.ps1",
    "Wingetter.UpdateWatcher.ps1"
)) {
    . (Resolve-Path (Join-Path $sourceDir $moduleName)).Path
}

$parameters = @{
    SkipMeteredNetwork = [bool]$SkipMeteredNetwork
    Toast              = [bool]$Toast
    KeepLogs           = $KeepLogs
    UpdatePolicy       = if (![string]::IsNullOrWhiteSpace($UpdatePolicyPath)) { Get-WingetterUpdatePolicy -Path $UpdatePolicyPath } else { Get-WingetterUpdatePolicy }
}
if (![string]::IsNullOrWhiteSpace($LogRoot)) {
    $parameters["LogRoot"] = $LogRoot
}

$run = Invoke-WingetterUpdateCheck @parameters
Write-Host "Wingetter update check complete. Log: $($run.LogPath)"
Write-Host "Updates: $($run.Result.Counts.Updates); Available: $($run.Result.Counts.Available); Deferred: $($run.Result.Counts.Deferred); Outside window: $($run.Result.Counts.OutsideWindow); Pinned: $($run.Result.Counts.Pinned); Source-blocked: $($run.Result.Counts.SourceBlocked)"
