<#
.SYNOPSIS
    Wingetter - Comprehensive GUI for bulk software installation via winget
.DESCRIPTION
    A professional PowerShell GUI application for discovering, selecting, and bulk
    installing Windows software using Windows Package Manager (winget).
    Features: Dark/Light mode, category sidebar, collapse/expand, installed app detection,
    install/update modes, shift-click selection, per-app log panel, toast notifications,
    parallel icon loading, app icons with caching, search filter, package groups
    (save/load/export as PS1 or JSON), 765 apps across 39 categories.
.VERSION
    6.1.0
#>

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$Script:WingetterModuleFiles = @(
    "Wingetter.Common.ps1",
    "Wingetter.Catalog.ps1",
    "Wingetter.WinGet.ps1",
    "Wingetter.Groups.ps1",
    "Wingetter.ProfileGallery.ps1",
    "Wingetter.Sources.ps1",
    "Wingetter.OfflineCache.ps1",
    "Wingetter.Configuration.ps1",
    "Wingetter.UpdateWatcher.ps1",
    "Wingetter.Diagnostics.ps1",
    "Wingetter.Ui.ps1",
    "Wingetter.App.ps1"
)

# Canonical SHA256 of each module under `src/` at the time this launcher was
# released. The download path verifies each fetched module against this table
# before dot-sourcing so a tampered mirror, redirected URL, or cache-poisoning
# attack cannot inject code via WINGETTER_MODULE_BASE_URL or %TEMP%.
#
# Maintainer workflow: when any `src/Wingetter.*.ps1` file changes, run
#   pwsh -NoProfile -File .\tools\Sync-LauncherManifest.ps1
# to refresh this hashtable. `tools\Test-LauncherManifest.ps1` enforces it in
# local validation so the table never drifts from the modules on disk.
# BEGIN WingetterModuleHashes
$Script:WingetterModuleHashes = @{
    'Wingetter.Common.ps1' = 'FB83F32CD105FE67DD22A2EE0C0A59C7BF57E04462C9DE2EB7D9E32A72C0049F'
    'Wingetter.Catalog.ps1' = 'A4C3D02BD3CC1785F001204D3DBEF746798F9E7D7452D6102EFE5B5EEE7059F8'
    'Wingetter.WinGet.ps1' = '7BD01218AAC80153163620FE8AE8C3F6A7C2007AEDF1804843D707B94943B5AB'
    'Wingetter.Groups.ps1' = 'FD7A073720BC274329AF8426E2C3426B285CE2002E352984889F96F805ABD908'
    'Wingetter.ProfileGallery.ps1' = '34043F5BF1EFC70E0C0D7B611F5E30A0D9A547057D43B2C44BCDCC7C5C664D9D'
    'Wingetter.Sources.ps1' = 'E22BA29A96E8D0089F57BB6B6A11F6DEB08F3390EF71682D44D2477F27C48EC9'
    'Wingetter.OfflineCache.ps1' = 'A54EB903297BE8054D2E500E8DE0125DF6D5FB02F752EDAD019625A326E4BADD'
    'Wingetter.Configuration.ps1' = '27C13CA232E92DAC5AFD733E6154CF6A8E9EDDC552258F84F1835A0E2942DF20'
    'Wingetter.UpdateWatcher.ps1' = 'F914EC6E9FF884395CECDBD0D291FFD81F46A32E6D82ACC26C33480A2F94B91D'
    'Wingetter.Diagnostics.ps1' = 'BB8102B3F1F780728A5CF8A7E28D115FA6988BD2474AF673BEFCC156A0E23E43'
    'Wingetter.Ui.ps1' = 'ADE77F499C4BBAD8FEBDB3FEBB23E5FE6B42EC6F0F24CE4049F0B1450B38F307'
    'Wingetter.App.ps1' = 'E74AE740AFD1B9DCEC8E5CCF9CA1E6290D78F9FC86A75BC06E0DCDF7F9A2B952'
}
# END WingetterModuleHashes

function Get-WingetterFileSha256 {
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

function Test-WingetterModuleHash {
    param([string]$Path, [string]$FileName)
    $expected = $Script:WingetterModuleHashes[$FileName]
    if ([string]::IsNullOrWhiteSpace($expected)) {
        throw "Wingetter launcher has no expected SHA256 for module '$FileName'."
    }
    $actual = Get-WingetterFileSha256 -Path $Path
    if ($actual -ne $expected.ToUpperInvariant()) {
        throw "Wingetter module '$FileName' SHA256 mismatch. Expected $expected, got $actual. The downloaded module will not be loaded."
    }
}

function Test-WingetterModuleDirectory {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path $Path)) { return $false }
    foreach ($file in $Script:WingetterModuleFiles) {
        if (!(Test-Path (Join-Path $Path $file))) { return $false }
    }
    return $true
}

function Get-WingetterModuleDirectory {
    if (![string]::IsNullOrWhiteSpace($env:WINGETTER_SOURCE_DIR) -and (Test-WingetterModuleDirectory -Path $env:WINGETTER_SOURCE_DIR)) {
        $Script:WingetterRoot = (Split-Path -Parent (Resolve-Path $env:WINGETTER_SOURCE_DIR).Path)
        return (Resolve-Path $env:WINGETTER_SOURCE_DIR).Path
    }

    if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $localSource = Join-Path $PSScriptRoot "src"
        if (Test-WingetterModuleDirectory -Path $localSource) {
            $Script:WingetterRoot = $PSScriptRoot
            return (Resolve-Path $localSource).Path
        }
    }

    $baseUrl = if (![string]::IsNullOrWhiteSpace($env:WINGETTER_MODULE_BASE_URL)) {
        $env:WINGETTER_MODULE_BASE_URL.TrimEnd("/")
    } else {
        "https://raw.githubusercontent.com/SysAdminDoc/Wingetter/main/src"
    }
    # Use a per-process subdirectory so two concurrent launches don't race on
    # the same destination paths. Older runs are cleaned up on a best-effort
    # basis if the parent grows beyond a small number of stale subdirs.
    $sessionId = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    $downloadRoot = Join-Path $env:TEMP ("Wingetter\src-" + $sessionId)
    New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null

    $parentDir = Join-Path $env:TEMP "Wingetter"
    try {
        $staleDirs = @(Get-ChildItem -Path $parentDir -Directory -Filter "src-*" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne "src-$sessionId" } |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -Skip 3)
        foreach ($stale in $staleDirs) {
            try { Remove-Item -Path $stale.FullName -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        }
    } catch {}

    foreach ($file in $Script:WingetterModuleFiles) {
        # Download to a temp file first, sanity-check the contents, then
        # rename into place. Failed downloads/parses re-try up to 3 times so a
        # transient network blip does not leave a partial PS1 sitting in
        # %TEMP% that would be dot-sourced and silently broken.
        $target = Join-Path $downloadRoot $file
        $url = "$baseUrl/$file"
        $stagePath = "$target.partial"
        $success = $false
        $lastError = $null
        for ($attempt = 1; $attempt -le 3 -and -not $success; $attempt++) {
            try {
                if (Test-Path $stagePath) { Remove-Item -Path $stagePath -Force -ErrorAction SilentlyContinue }
                Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile $stagePath -ErrorAction Stop
                $info = Get-Item -Path $stagePath -ErrorAction Stop
                if ($info.Length -lt 100) {
                    throw "Module '$file' downloaded as $($info.Length) bytes, which is too small to be the real source."
                }
                $head = (Get-Content -Path $stagePath -TotalCount 5 -ErrorAction Stop) -join "`n"
                if ($head -notmatch '^\s*#') {
                    throw "Module '$file' did not begin with a comment header; the download may be corrupted or redirected."
                }
                # Hash-pin the staged file against the launcher's embedded
                # manifest BEFORE renaming it into place, so a tampered or
                # wrong-source module never lands at $target.
                Test-WingetterModuleHash -Path $stagePath -FileName $file
                Move-Item -Path $stagePath -Destination $target -Force -ErrorAction Stop
                $success = $true
            } catch {
                $lastError = $_
                if (Test-Path $stagePath) { Remove-Item -Path $stagePath -Force -ErrorAction SilentlyContinue }
                Start-Sleep -Seconds ([math]::Min(5, $attempt))
            }
        }
        if (-not $success) {
            throw "Could not download Wingetter module '$file' from $url after 3 attempts. Last error: $($lastError.Exception.Message)"
        }
    }

    $Script:WingetterRoot = (Split-Path -Parent $downloadRoot)
    return $downloadRoot
}

$moduleDir = Get-WingetterModuleDirectory
foreach ($moduleFile in $Script:WingetterModuleFiles) {
    . (Join-Path $moduleDir $moduleFile)
}

Start-Wingetter
