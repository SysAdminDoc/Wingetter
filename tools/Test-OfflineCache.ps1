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
    "Wingetter.WinGet.ps1",
    "Wingetter.Sources.ps1",
    "Wingetter.OfflineCache.ps1"
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
    $downloadArgs = New-WingetterOfflineDownloadArguments -PackageId "Internal.Tool" -DownloadDirectory "C:\Cache" -SourceName "corp" -AcceptAgreements $true
    foreach ($expected in @("download", "--id", "Internal.Tool", "--exact", "--download-directory", "C:\Cache", "--source", "corp", "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity", "--verbose-logs")) {
        if ($downloadArgs -notcontains $expected) {
            Add-Failure "Offline download arguments did not include '$expected'."
        }
    }

    $before = @("C:\Cache\a.exe")
    $after = @("C:\Cache\a.exe", "C:\Cache\b.msi")
    $delta = @(Compare-WingetterOfflineCacheFiles -Before $before -After $after)
    if ($delta.Count -ne 1 -or $delta[0] -ne "C:\Cache\b.msi") {
        Add-Failure "Offline cache file comparison did not find only the new file."
    }

    $selected = @(
        [PSCustomObject]@{ Name = "Internal Tool"; WingetId = "Internal.Tool"; SourceName = "corp" }
    )
    $results = @(
        [PSCustomObject]@{
            PackageId       = "Internal.Tool"
            Status          = "SUCCESS"
            Command         = "winget download --id Internal.Tool --exact"
            DownloadedFiles = @("C:\Cache\Internal.Tool\tool.msi")
            ResultPath      = "C:\Logs\result.json"
        }
    )
    $manifest = New-WingetterOfflineCacheManifest -CacheDirectory "C:\Cache" -SelectedPackages $selected -DownloadResults $results
    if ($manifest.Schema -ne "Wingetter.OfflineCache.v1" -or $manifest.PackageCount -ne 1 -or $manifest.Packages[0].SourceName -ne "corp") {
        Add-Failure "Offline cache manifest did not preserve package metadata."
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-offline-cache-" + [System.Guid]::NewGuid().ToString("N"))
    try {
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $manifestPath = Join-Path $tempRoot "offline-manifest.json"
        $paths = Export-WingetterOfflineCacheManifest -Manifest $manifest -ManifestPath $manifestPath
        if (!(Test-Path $paths.ManifestPath) -or !(Test-Path $paths.ScriptPath)) {
            Add-Failure "Offline cache export did not create manifest and replay script."
        }
        $scriptText = Get-Content -Path $paths.ScriptPath -Raw
        if ($scriptText -notmatch "Start-Process" -or $scriptText -notmatch "offline-manifest.json") {
            Add-Failure "Offline replay script did not include installer launch logic."
        }
    } finally {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Offline cache validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Offline cache validation passed."
