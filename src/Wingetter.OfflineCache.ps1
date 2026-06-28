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
        [bool]$AcceptAgreements = $true,
        [string]$WinGetVersion = ""
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
    return Add-WinGetCleanOutputArguments -Arguments $arguments -WinGetVersion $WinGetVersion
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

function New-WingetterOfflineFileRecord {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path)) { return $null }
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $item = Get-Item -LiteralPath $resolved -ErrorAction Stop
    [PSCustomObject]@{
        Path   = $resolved
        Size   = [int64]$item.Length
        Sha256 = Get-WingetterFileSha256 -Path $resolved
    }
}

function Get-WingetterOfflineFileRecords {
    param([string[]]$Paths = @())

    $records = @()
    foreach ($path in @($Paths)) {
        $record = New-WingetterOfflineFileRecord -Path $path
        if ($null -ne $record) { $records += $record }
    }
    return @($records)
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
    $downloadedFileRecords = Get-WingetterOfflineFileRecords -Paths $downloadedFiles
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
        DownloadedFileRecords = @($downloadedFileRecords)
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
        $fileRecords = @()
        if ($result) {
            if ($result.PSObject.Properties["DownloadedFileRecords"]) {
                $fileRecords = @($result.DownloadedFileRecords)
            } else {
                $fileRecords = Get-WingetterOfflineFileRecords -Paths @($result.DownloadedFiles)
            }
        }
        $packages += [PSCustomObject]@{
            Name            = [string]$package.Name
            PackageId       = $id
            SourceName      = [string]$package.SourceName
            Status          = if ($result) { [string]$result.Status } else { "NOT RUN" }
            DownloadedFiles = if ($result) { @($result.DownloadedFiles) } else { @() }
            DownloadedFileRecords = @($fileRecords)
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
    # The replay script intentionally requires `-Confirm` before launching any
    # installer so a stale offline cache cannot run installers from an
    # unattended scheduled task or one-line invocation. The script also
    # constrains each launched installer to the manifest's cache directory and
    # an explicit allow-list of installer extensions.
    $content = @'
param(
    [string]$ManifestPath = (Join-Path $PSScriptRoot "offline-manifest.json"),
    [switch]$Confirm
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $Confirm) {
    Write-Host "This script will launch the installers cached alongside it. Re-run with -Confirm to proceed." -ForegroundColor Yellow
    return
}

if (!(Test-Path $ManifestPath)) {
    throw "Manifest not found at $ManifestPath."
}
$manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json
$cacheRoot = $null
if ($manifest.PSObject.Properties["CacheDirectory"]) {
    $cacheRoot = [string]$manifest.CacheDirectory
}
if ([string]::IsNullOrWhiteSpace($cacheRoot)) {
    $cacheRoot = Split-Path -Parent (Resolve-Path $ManifestPath).Path
}
$cacheRoot = (Resolve-Path -Path $cacheRoot -ErrorAction Stop).Path

$allowedExtensions = @(".exe", ".msi", ".msix", ".msixbundle", ".appx", ".appxbundle")

function Get-WingetterReplayFileSha256 {
    param([string]$Path)

    $hashCommand = Get-Command Get-FileHash -ErrorAction SilentlyContinue
    if ($hashCommand) {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $stream = [System.IO.File]::OpenRead($resolvedPath)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hashBytes = $sha256.ComputeHash($stream)
            return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToUpperInvariant()
        } finally {
            if ($sha256 -is [System.IDisposable]) { $sha256.Dispose() }
        }
    } finally {
        $stream.Dispose()
    }
}

foreach ($package in @($manifest.Packages)) {
    $fileRecords = @()
    if ($package.PSObject.Properties["DownloadedFileRecords"] -and @($package.DownloadedFileRecords).Count -gt 0) {
        $fileRecords = @($package.DownloadedFileRecords)
    } else {
        foreach ($legacyPath in @($package.DownloadedFiles)) {
            if ($legacyPath) {
                $fileRecords += [PSCustomObject]@{ Path = [string]$legacyPath; Size = $null; Sha256 = "" }
            }
        }
    }
    if ($fileRecords.Count -eq 0) {
        Write-Warning "No downloaded installer files found for $($package.PackageId)."
        continue
    }
    foreach ($record in $fileRecords) {
        $file = if ($record.PSObject.Properties["Path"]) { [string]$record.Path } else { [string]$record }
        if ([string]::IsNullOrWhiteSpace($file)) {
            Write-Warning "Skipping empty installer path for $($package.PackageId)."
            continue
        }
        $resolved = $null
        try { $resolved = (Resolve-Path -Path $file -ErrorAction Stop).Path } catch {
            Write-Warning "Could not resolve installer path '$file': $($_.Exception.Message)"
            continue
        }
        # Refuse to launch anything that escapes the manifest cache directory
        # (e.g., a maliciously edited manifest pointing at C:\Windows\...).
        if (-not $resolved.StartsWith($cacheRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Warning "Refusing to launch '$resolved' because it is outside the cache directory '$cacheRoot'."
            continue
        }
        $extension = [System.IO.Path]::GetExtension($resolved).ToLowerInvariant()
        if ($extension -notin $allowedExtensions) {
            Write-Warning "Skipping '$resolved' because '$extension' is not in the allowed installer extension list."
            continue
        }
        $fileInfo = Get-Item -LiteralPath $resolved -ErrorAction Stop
        $hasExpectedSize = $record.PSObject.Properties["Size"] -and $null -ne $record.Size -and ![string]::IsNullOrWhiteSpace([string]$record.Size)
        if ($hasExpectedSize) {
            $expectedSize = [int64]$record.Size
            if ($fileInfo.Length -ne $expectedSize) {
                Write-Warning "Refusing to launch '$resolved' because its size changed. Expected $expectedSize bytes, got $($fileInfo.Length) bytes."
                continue
            }
        }
        $expectedHash = if ($record.PSObject.Properties["Sha256"]) { ([string]$record.Sha256).ToUpperInvariant() } else { "" }
        if (![string]::IsNullOrWhiteSpace($expectedHash)) {
            $actualHash = Get-WingetterReplayFileSha256 -Path $resolved
            if ($actualHash -ne $expectedHash) {
                Write-Warning "Refusing to launch '$resolved' because its SHA256 changed. Expected $expectedHash, got $actualHash."
                continue
            }
        }
        Write-Host "Launching $($package.PackageId): $resolved"
        Start-Process -FilePath $resolved -Wait
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
