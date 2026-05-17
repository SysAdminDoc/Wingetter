param(
    [Parameter(Mandatory = $true)][string[]]$PackageId,
    [string]$DownloadDirectory = "",
    [switch]$AcceptAgreements
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
    "Wingetter.OfflineCache.ps1"
)) {
    . (Resolve-Path (Join-Path $sourceDir $moduleName)).Path
}

$cacheDir = if ([string]::IsNullOrWhiteSpace($DownloadDirectory)) {
    New-WingetterOfflineCacheDirectory
} else {
    New-Item -ItemType Directory -Path $DownloadDirectory -Force | Out-Null
    (Resolve-Path $DownloadDirectory).Path
}
$runLogDir = New-WingetterRunLogDirectory -Action "download"

$selected = @($PackageId | ForEach-Object {
    [PSCustomObject]@{
        Name       = $_
        WingetId   = $_
        SourceName = "winget"
    }
})

$results = @()
foreach ($package in $selected) {
    $results += Invoke-WingetterOfflinePackageDownload `
        -PackageId $package.WingetId `
        -PackageName $package.Name `
        -SourceName $package.SourceName `
        -DownloadDirectory $cacheDir `
        -RunLogDir $runLogDir `
        -AcceptAgreements ([bool]$AcceptAgreements)
}

$manifest = New-WingetterOfflineCacheManifest -CacheDirectory $cacheDir -SelectedPackages $selected -DownloadResults $results
$paths = Export-WingetterOfflineCacheManifest -Manifest $manifest -ManifestPath (Join-Path $cacheDir "offline-manifest.json")

Write-Host "Offline cache complete. Manifest: $($paths.ManifestPath)"
Write-Host "Replay script: $($paths.ScriptPath)"
