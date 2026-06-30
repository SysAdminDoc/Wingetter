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
    'Wingetter.Common.ps1' = '69EEDA1A59F8F6BBFFC07762A7A8E98CE1284B2E0370D0F32E3CE9C75425AB4C'
    'Wingetter.Catalog.ps1' = '03B4E753D4709DC12934407B4D91801BA759BCE63D5EFD7AB1F1914283C53488'
    'Wingetter.WinGet.ps1' = '11C3094708EF096DD0C8BED3217CA78109CAC3EE5AD1C77298FEE07C23D5BE67'
    'Wingetter.Groups.ps1' = '7759F12B8197DE5FFC49AE9B8A0F1D365DAB689D39A64B0929BB459E44962245'
    'Wingetter.ProfileGallery.ps1' = '34043F5BF1EFC70E0C0D7B611F5E30A0D9A547057D43B2C44BCDCC7C5C664D9D'
    'Wingetter.Sources.ps1' = '4015E652118AF2621C5300466C8325455D9E5D950F85CE5BCC62D57C49CCF8B4'
    'Wingetter.OfflineCache.ps1' = '22C0642115EB05AA19C18F63BBC18397569AF3F83BD7A0E7F39D962C3A7A1049'
    'Wingetter.Configuration.ps1' = '0C0818D7ED188EC7351A3119347E692C727BBA48FC2C71110E91F56A32871A2B'
    'Wingetter.UpdateWatcher.ps1' = '8440AD94B6388B7BA19B72FF9F58670C1123014B761D0CBAF7FF8F9274CDD479'
    'Wingetter.Ui.ps1' = 'D850727B0B4393849DD165C054FC98A428CFB028ECFD4DFF91FB45644755E2BE'
    'Wingetter.App.ps1' = 'CC89FD7D93EA85BF465F8E7169219251F14F4AC4D429F0F35AA4666C6F7F8BB4'
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
