param(
    [string]$TaskName = "Wingetter Update Check",
    [string]$DailyAt = "09:00",
    [int]$KeepLogs = 30,
    [switch]$NoSkipMeteredNetwork,
    [switch]$NoToast,
    [switch]$Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceDir = Join-Path $PSScriptRoot "..\src"
foreach ($moduleName in @(
    "Wingetter.Common.ps1",
    "Wingetter.WinGet.ps1",
    "Wingetter.Sources.ps1",
    "Wingetter.UpdateWatcher.ps1"
)) {
    . (Resolve-Path (Join-Path $sourceDir $moduleName)).Path
}

if ($Unregister) {
    Unregister-WingetterUpdateWatcherTask -TaskName $TaskName
    Write-Host "Unregistered scheduled task '$TaskName'."
    return
}

$time = [DateTime]::Parse($DailyAt)
$invokeScript = (Resolve-Path (Join-Path $PSScriptRoot "Invoke-UpdateCheck.ps1")).Path
$task = Register-WingetterUpdateWatcherTask `
    -ScriptPath $invokeScript `
    -TaskName $TaskName `
    -DailyAt $time `
    -SkipMeteredNetwork (-not [bool]$NoSkipMeteredNetwork) `
    -Toast (-not [bool]$NoToast) `
    -KeepLogs $KeepLogs

Write-Host "Registered scheduled task '$($task.TaskName)' for $DailyAt."
