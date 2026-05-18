# ============================================================================
# OFFLINE DOWNLOAD CACHE
# ============================================================================

function New-WingetterOfflineCacheDirectory {
    param([string]$BaseDirectory = "")

    if ([string]::IsNullOrWhiteSpace($BaseDirectory)) {
        $BaseDirectory = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads"
    }
    $path = Join-Path $BaseDirectory ("Wingetter-OfflineCache-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function New-WingetterOfflineDownloadArguments {
    param(
        [string]$PackageId,
        [string]$DownloadDirectory,
        [string]$SourceName = "winget",
        [bool]$AcceptAgreements = $true
    )

    $arguments = @("download", "--id", $PackageId, "--exact", "--download-directory", $DownloadDirectory, "--disable-interactivity", "--verbose-logs")
    if (![string]::IsNullOrWhiteSpace($SourceName)) {
        $arguments += "--source"
        $arguments += $SourceName
    }
    if ($AcceptAgreements) {
        $arguments += "--accept-package-agreements"
        $arguments += "--accept-source-agreements"
    }
    return [string[]]$arguments
}

function Get-WingetterOfflineCacheFiles {
    param([string]$Directory)

    if ([string]::IsNullOrWhiteSpace($Directory) -or !(Test-Path $Directory)) { return @() }
    @(Get-ChildItem -Path $Directory -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
}

function Compare-WingetterOfflineCacheFiles {
    param(
        [string[]]$Before = @(),
        [string[]]$After = @()
    )

    $beforeSet = @{}
    foreach ($path in @($Before)) { $beforeSet[[string]$path] = $true }
    @($After | Where-Object { !$beforeSet.ContainsKey([string]$_) })
}

function Invoke-WingetterOfflinePackageDownload {
    param(
        [string]$PackageId,
        [string]$PackageName,
        [string]$SourceName = "winget",
        [string]$DownloadDirectory,
        [string]$RunLogDir,
        [bool]$AcceptAgreements = $true,
        [scriptblock]$ShouldCancel = { $false },
        [scriptblock]$PumpUi = {}
    )

    if (!(Test-Path $DownloadDirectory)) { New-Item -ItemType Directory -Path $DownloadDirectory -Force | Out-Null }
    if (!(Test-Path $RunLogDir)) { New-Item -ItemType Directory -Path $RunLogDir -Force | Out-Null }

    $beforeFiles = Get-WingetterOfflineCacheFiles -Directory $DownloadDirectory
    $arguments = New-WingetterOfflineDownloadArguments -PackageId $PackageId -DownloadDirectory $DownloadDirectory -SourceName $SourceName -AcceptAgreements $AcceptAgreements
    $safeId = Get-SafeFileName -Value $PackageId
    $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
    $stdoutPath = Join-Path $RunLogDir "$stamp-$safeId.download.stdout.log"
    $stderrPath = Join-Path $RunLogDir "$stamp-$safeId.download.stderr.log"
    $resultPath = Join-Path $RunLogDir "$stamp-$safeId.download.result.json"

    $stdout = ""
    $stderr = ""
    $exitCode = -1
    $cancelled = $false

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "winget"
        Set-ProcessArguments -ProcessStartInfo $psi -Arguments $arguments
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()

        while (-not $proc.HasExited) {
            & $PumpUi
            Start-Sleep -Milliseconds 100
            if (& $ShouldCancel) {
                $cancelled = $true
                try { $proc.Kill() } catch {}
                break
            }
        }

        try { $proc.WaitForExit() } catch {}
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = if ($cancelled) { -1 } else { $proc.ExitCode }
    } catch {
        $stderr = $_.Exception.Message
        $exitCode = -1
    }

    Set-Content -Path $stdoutPath -Value $stdout -Encoding UTF8
    Set-Content -Path $stderrPath -Value $stderr -Encoding UTF8

    $afterFiles = Get-WingetterOfflineCacheFiles -Directory $DownloadDirectory
    $downloadedFiles = Compare-WingetterOfflineCacheFiles -Before $beforeFiles -After $afterFiles
    $signal = 'None'
    $status = Get-WinGetOperationStatus -ExitCode ([int]$exitCode) -StdOut $stdout -StdErr $stderr -Cancelled $cancelled -Signal ([ref]$signal)
    $exitCodeMeaning = Get-WinGetExitCodeMeaning -ExitCode ([int]$exitCode)

    $result = [ordered]@{
        TimestampUtc      = (Get-Date).ToUniversalTime().ToString("o")
        Action            = "download"
        PackageName       = $PackageName
        PackageId         = $PackageId
        SourceName        = $SourceName
        Command           = "winget " + (Join-ProcessArguments -Arguments $arguments)
        ExitCode          = $exitCode
        ExitCodeMeaning   = $exitCodeMeaning
        Status            = $status
        StatusSignal      = $signal
        Cancelled         = $cancelled
        DownloadDirectory = $DownloadDirectory
        DownloadedFiles   = @($downloadedFiles)
        StdOutPath        = $stdoutPath
        StdErrPath        = $stderrPath
        StdOutExcerpt     = Get-TextExcerpt -Text $stdout
        StdErrExcerpt     = Get-TextExcerpt -Text $stderr
        ResultPath        = $resultPath
    }
    $result | ConvertTo-Json -Depth 8 | Set-Content -Path $resultPath -Encoding UTF8

    return [PSCustomObject]$result
}

function New-WingetterOfflineCacheManifest {
    param(
        [string]$CacheDirectory,
        [object[]]$SelectedPackages,
        [object[]]$DownloadResults,
        [object]$SourcePolicy = (Get-WingetterSourcePolicy)
    )

    $resultById = @{}
    foreach ($result in @($DownloadResults)) { $resultById[[string]$result.PackageId] = $result }
    $packages = @()
    foreach ($package in @($SelectedPackages)) {
        $id = [string]$package.WingetId
        $result = if ($resultById.ContainsKey($id)) { $resultById[$id] } else { $null }
        $packages += [PSCustomObject]@{
            Name            = [string]$package.Name
            PackageId       = $id
            SourceName      = [string]$package.SourceName
            Status          = if ($result) { [string]$result.Status } else { "NOT RUN" }
            DownloadedFiles = if ($result) { @($result.DownloadedFiles) } else { @() }
            Command         = if ($result) { [string]$result.Command } else { "" }
            ResultPath      = if ($result) { [string]$result.ResultPath } else { "" }
        }
    }

    [PSCustomObject]@{
        Schema                    = "Wingetter.OfflineCache.v1"
        CreatedAtUtc              = (Get-Date).ToUniversalTime().ToString("o")
        CacheDirectory            = $CacheDirectory
        SourcePolicyCorporateMode = [bool](ConvertTo-WingetterSourcePolicy -Policy $SourcePolicy).CorporateMode
        PackageCount              = @($packages).Count
        Packages                  = @($packages)
    }
}

function Export-WingetterOfflineReplayScript {
    param(
        [string]$ManifestPath,
        [string]$ScriptPath
    )

    # ManifestPath is taken at call time for symmetry with other Export-* helpers
    # and so the generated replay script can advertise its own default. The actual
    # path is hard-coded into the generated PS1 below via PSScriptRoot, which is
    # the more robust default when the cache directory is later moved.
    [void]$ManifestPath
    $content = @'
param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot "offline-manifest.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
foreach ($package in @($manifest.Packages)) {
    $files = @($package.DownloadedFiles | Where-Object { $_ -and (Test-Path $_) })
    if ($files.Count -eq 0) {
        Write-Warning "No downloaded installer files found for $($package.PackageId)."
        continue
    }
    foreach ($file in $files) {
        $extension = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
        if ($extension -notin @(".exe", ".msi", ".msix", ".msixbundle", ".appx", ".appxbundle")) { continue }
        Write-Host "Launching $($package.PackageId): $file"
        Start-Process -FilePath $file -Wait
    }
}
'@
    Set-Content -Path $ScriptPath -Value $content -Encoding UTF8
    return $ScriptPath
}

function Export-WingetterOfflineCacheManifest {
    param(
        [object]$Manifest,
        [string]$ManifestPath
    )

    $parent = Split-Path -Parent $ManifestPath
    if (![string]::IsNullOrWhiteSpace($parent) -and !(Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $Manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $ManifestPath -Encoding UTF8
    $scriptPath = Join-Path (Split-Path -Parent $ManifestPath) "install-offline.ps1"
    Export-WingetterOfflineReplayScript -ManifestPath $ManifestPath -ScriptPath $scriptPath | Out-Null
    return [PSCustomObject]@{
        ManifestPath = $ManifestPath
        ScriptPath   = $scriptPath
    }
}
