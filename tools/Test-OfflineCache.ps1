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
    $recordRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-offline-records-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $recordRoot -Force | Out-Null
    $installerPath = Join-Path $recordRoot "tool.exe"
    [System.IO.File]::WriteAllText($installerPath, "AAAA")
    $results = @(
        [PSCustomObject]@{
            PackageId       = "Internal.Tool"
            Status          = "SUCCESS"
            Command         = "winget download --id Internal.Tool --exact"
            DownloadedFiles = @($installerPath)
            ResultPath      = "C:\Logs\result.json"
        }
    )
    try {
        $manifest = New-WingetterOfflineCacheManifest -CacheDirectory $recordRoot -SelectedPackages $selected -DownloadResults $results
        if ($manifest.Schema -ne "Wingetter.OfflineCache.v1" -or $manifest.PackageCount -ne 1 -or $manifest.Packages[0].SourceName -ne "corp") {
            Add-Failure "Offline cache manifest did not preserve package metadata."
        }
        $fileRecord = @($manifest.Packages[0].DownloadedFileRecords)[0]
        if ($null -eq $fileRecord -or $fileRecord.Path -ne $installerPath -or $fileRecord.Size -ne 4 -or [string]::IsNullOrWhiteSpace([string]$fileRecord.Sha256)) {
            Add-Failure "Offline cache manifest did not record installer path, size, and SHA256."
        }
    } finally {
        Remove-Item -Path $recordRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-offline-cache-" + [System.Guid]::NewGuid().ToString("N"))
    try {
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $cachedInstaller = Join-Path $tempRoot "tool.exe"
        [System.IO.File]::WriteAllText($cachedInstaller, "AAAA")
        $tamperResults = @(
            [PSCustomObject]@{
                PackageId       = "Internal.Tool"
                Status          = "SUCCESS"
                Command         = "winget download --id Internal.Tool --exact"
                DownloadedFiles = @($cachedInstaller)
                ResultPath      = "C:\Logs\result.json"
            }
        )
        $tamperManifest = New-WingetterOfflineCacheManifest -CacheDirectory $tempRoot -SelectedPackages $selected -DownloadResults $tamperResults
        $manifestPath = Join-Path $tempRoot "offline-manifest.json"
        $paths = Export-WingetterOfflineCacheManifest -Manifest $tamperManifest -ManifestPath $manifestPath
        if (!(Test-Path $paths.ManifestPath) -or !(Test-Path $paths.ScriptPath)) {
            Add-Failure "Offline cache export did not create manifest and replay script."
        }
        $scriptText = Get-Content -Path $paths.ScriptPath -Raw
        if ($scriptText -notmatch "Start-Process" -or $scriptText -notmatch "offline-manifest.json") {
            Add-Failure "Offline replay script did not include installer launch logic."
        }
        # The replay script must require an explicit -Confirm gate and refuse
        # paths outside the cache directory, so a stale manifest cannot
        # silently launch installers from somewhere on disk.
        if ($scriptText -notmatch "\[switch\]\`$Confirm") {
            Add-Failure "Offline replay script does not require a -Confirm switch."
        }
        if ($scriptText -notmatch "Refusing to launch" -or $scriptText -notmatch "outside the cache directory") {
            Add-Failure "Offline replay script does not refuse installer paths outside the cache directory."
        }
        if ($scriptText -notmatch "allowed installer extension") {
            Add-Failure "Offline replay script does not constrain installer extensions."
        }
        if ($scriptText -notmatch "SHA256 changed" -or $scriptText -notmatch "size changed") {
            Add-Failure "Offline replay script does not verify installer size and SHA256 before launch."
        }

        # Executing the generated script without -Confirm must short-circuit
        # so a misclick or scheduled job cannot run installers.
        $invokeOutput = & pwsh -NoProfile -File $paths.ScriptPath -ManifestPath $paths.ManifestPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Add-Failure "Replay script returned non-zero exit ($LASTEXITCODE) when invoked without -Confirm."
        }
        if ($invokeOutput -notmatch "-Confirm") {
            Add-Failure "Replay script did not print the -Confirm hint when invoked without the switch."
        }

        [System.IO.File]::WriteAllText($cachedInstaller, "BBBB")
        $tamperOutput = & pwsh -NoProfile -File $paths.ScriptPath -ManifestPath $paths.ManifestPath -Confirm 2>&1
        if ($LASTEXITCODE -ne 0) {
            Add-Failure "Replay script returned non-zero exit ($LASTEXITCODE) when refusing a tampered installer."
        }
        if ($tamperOutput -notmatch "SHA256 changed") {
            Add-Failure "Replay script did not report the tampered installer SHA256 mismatch."
        }
        if ($tamperOutput -match "Launching") {
            Add-Failure "Replay script attempted to launch a tampered installer."
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
