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
    6.2.1
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
    "Wingetter.Scoop.ps1",
    "Wingetter.OfflineCache.ps1",
    "Wingetter.Configuration.ps1",
    "Wingetter.UpdateWatcher.ps1",
    "Wingetter.Diagnostics.ps1",
    "Wingetter.Resources.ps1",
    "Wingetter.Ui.ps1",
    "Wingetter.App.ps1"
)

# Canonical SHA256 of each module under `src/` at the time this launcher was
# released. The download path verifies each fetched module against this table
# before dot-sourcing so a tampered response or cache-poisoning attack cannot
# inject code via the fixed upstream source or %TEMP%.
#
# Maintainer workflow: when any `src/Wingetter.*.ps1` file changes, run
#   pwsh -NoProfile -File .\tools\Sync-LauncherManifest.ps1
# to refresh this hashtable. `tools\Test-LauncherManifest.ps1` enforces it in
# local validation so the table never drifts from the modules on disk.
# BEGIN WingetterModuleHashes
$Script:WingetterModuleHashes = @{
    'Wingetter.Common.ps1' = '17CD19D63CAF566EB6DD5E2865A3D16F49D7CC31E1166EA57BF011FFE7564B18'
    'Wingetter.Catalog.ps1' = 'D0F23C563AC5422DB6DFF6B96C29291783CB4550B8B8399FC5758755CE7DD913'
    'Wingetter.WinGet.ps1' = 'E5951FEA33EC4522914BB59CA12FC8D76007B7B0F094AB0A5C7C57E80D5761AA'
    'Wingetter.Groups.ps1' = '7EFCEB9EC4E73313D9251C58402029FEBD9906EE9EC460529B5755BA4D487783'
    'Wingetter.ProfileGallery.ps1' = '34043F5BF1EFC70E0C0D7B611F5E30A0D9A547057D43B2C44BCDCC7C5C664D9D'
    'Wingetter.Sources.ps1' = '2121FBA40D398A3970E1844AF82C8171957EF38F5B34062F1DB0E464890C5222'
    'Wingetter.Scoop.ps1' = 'EB1B64B8A526EF72D5F38DF803EED2A310DEACE9C2C87359F41D3AA7D80D5254'
    'Wingetter.OfflineCache.ps1' = 'F0761E2FBD9035B77115BF8154F9E1D4DED9EB8E16E570ADC71ED6E5D4D2BEEF'
    'Wingetter.Configuration.ps1' = '9F8C5F4F3F1C5517ED5B5B16C1DE2A279D239E5DF33FF464239D8F5641420DB2'
    'Wingetter.UpdateWatcher.ps1' = 'A29485CA41EFAE7C4E961B94F356159659CD1F04D5DF6F3E72F481A94005B744'
    'Wingetter.Diagnostics.ps1' = 'A5F67874FCE0DF16DDAF1DE5F1E9B3A753FDD0C68072793AF5413FCD7308BF80'
    'Wingetter.Resources.ps1' = '6D8D973568B3C0E2F08F1F43E6B2CC7D2EAAC86CF04C49C655980883659FC413'
    'Wingetter.Ui.ps1' = '1E8A778D875145C35AF8A5D5B464174E4A1604682C61B28EB97CBB86359CE2B4'
    'Wingetter.App.ps1' = 'E74AE740AFD1B9DCEC8E5CCF9CA1E6290D78F9FC86A75BC06E0DCDF7F9A2B952'
}
# END WingetterModuleHashes

# BEGIN WingetterCatalogHash
$Script:WingetterCatalogHash = '30495113BCFBAFA39953EB9C745BF9C4BCD93641A19EECA30F1320BD675D0F8F'
# END WingetterCatalogHash

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

function Test-WingetterCatalogHash {
    param([string]$Path)
    $expected = $Script:WingetterCatalogHash
    if ([string]::IsNullOrWhiteSpace($expected)) {
        throw "Wingetter launcher has no expected SHA256 for the catalog."
    }
    $actual = Get-WingetterFileSha256 -Path $Path
    if ($actual -ne $expected.ToUpperInvariant()) {
        throw "Wingetter catalog SHA256 mismatch. Expected $expected, got $actual. The downloaded catalog will not be loaded."
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

    $baseUrl = "https://raw.githubusercontent.com/SysAdminDoc/Wingetter/main/src"
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

    $catalogDirectory = Join-Path (Split-Path -Parent $downloadRoot) "catalog"
    New-Item -ItemType Directory -Path $catalogDirectory -Force | Out-Null
    $catalogTarget = Join-Path $catalogDirectory "winget.json"
    $catalogStagePath = "$catalogTarget.partial"
    $catalogUrl = "https://raw.githubusercontent.com/SysAdminDoc/Wingetter/main/catalog/winget.json"
    $catalogSuccess = $false
    $catalogLastError = $null
    for ($attempt = 1; $attempt -le 3 -and -not $catalogSuccess; $attempt++) {
        try {
            if (Test-Path $catalogStagePath) { Remove-Item -Path $catalogStagePath -Force -ErrorAction SilentlyContinue }
            Invoke-WebRequest -Uri $catalogUrl -UseBasicParsing -OutFile $catalogStagePath -ErrorAction Stop
            Test-WingetterCatalogHash -Path $catalogStagePath
            Move-Item -Path $catalogStagePath -Destination $catalogTarget -Force -ErrorAction Stop
            $catalogSuccess = $true
        } catch {
            $catalogLastError = $_
            if (Test-Path $catalogStagePath) { Remove-Item -Path $catalogStagePath -Force -ErrorAction SilentlyContinue }
            Start-Sleep -Seconds ([math]::Min(5, $attempt))
        }
    }
    if (-not $catalogSuccess) {
        throw "Could not download the Wingetter catalog from $catalogUrl after 3 attempts. Last error: $($catalogLastError.Exception.Message)"
    }

    $Script:WingetterRoot = (Split-Path -Parent $downloadRoot)
    return $downloadRoot
}

$moduleDir = Get-WingetterModuleDirectory
foreach ($moduleFile in $Script:WingetterModuleFiles) {
    . (Join-Path $moduleDir $moduleFile)
}

Start-Wingetter
