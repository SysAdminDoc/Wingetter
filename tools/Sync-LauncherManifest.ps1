param(
    [string]$LauncherPath = (Join-Path $PSScriptRoot "..\Wingetter.ps1"),
    [string]$SourceDir = (Join-Path $PSScriptRoot "..\src"),
    [string]$CatalogPath = (Join-Path $PSScriptRoot "..\catalog\winget.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

if (!(Test-Path $LauncherPath)) {
    Write-Host "Missing launcher at $LauncherPath." -ForegroundColor Red
    exit 1
}
if (!(Test-Path $SourceDir)) {
    Write-Host "Missing source directory at $SourceDir." -ForegroundColor Red
    exit 1
}
if (!(Test-Path $CatalogPath)) {
    Write-Host "Missing canonical catalog at $CatalogPath." -ForegroundColor Red
    exit 1
}

$launcherText = Get-Content -Path $LauncherPath -Raw
$listMatch = [regex]::Match($launcherText, '(?ms)\$Script:WingetterModuleFiles\s*=\s*@\((?<list>.*?)\)')
if (-not $listMatch.Success) {
    Write-Host "Could not locate `$Script:WingetterModuleFiles in $LauncherPath." -ForegroundColor Red
    exit 1
}
$moduleFiles = @(
    ($listMatch.Groups['list'].Value -split ',') |
        ForEach-Object { $_.Trim().Trim('"').Trim("'") } |
        Where-Object { $_ -and $_.EndsWith('.ps1') }
)
$catalogHash = Get-WingetterFileSha256 -Path $CatalogPath

$rows = New-Object System.Collections.Generic.List[string]
foreach ($file in $moduleFiles) {
    $modulePath = Join-Path $SourceDir $file
    if (!(Test-Path $modulePath)) {
        Write-Host "Missing module file '$modulePath'." -ForegroundColor Red
        exit 1
    }
    $hash = Get-WingetterFileSha256 -Path $modulePath
    $rows.Add("    '$file' = '$hash'")
}

$nl = [Environment]::NewLine
$replacement = "# BEGIN WingetterModuleHashes" + $nl +
    "`$Script:WingetterModuleHashes = @{" + $nl +
    (($rows -join $nl)) + $nl +
    "}" + $nl +
    "# END WingetterModuleHashes"

# Replace the entire BEGIN/END block. Anchored markers make the replacement
# idempotent and avoid the regex-replace footgun where the body itself
# contains characters that look like regex metacharacters.
$blockPattern = '(?ms)# BEGIN WingetterModuleHashes.*?# END WingetterModuleHashes'
$blockMatch = [regex]::Match($launcherText, $blockPattern)
if (-not $blockMatch.Success) {
    Write-Host "Could not locate BEGIN/END WingetterModuleHashes markers in launcher." -ForegroundColor Red
    exit 1
}
$updated = $launcherText.Substring(0, $blockMatch.Index) + $replacement + $launcherText.Substring($blockMatch.Index + $blockMatch.Length)

$catalogReplacement = "# BEGIN WingetterCatalogHash" + $nl +
    "`$Script:WingetterCatalogHash = '$catalogHash'" + $nl +
    "# END WingetterCatalogHash"
$catalogBlockPattern = '(?ms)# BEGIN WingetterCatalogHash.*?# END WingetterCatalogHash'
$catalogBlockMatch = [regex]::Match($updated, $catalogBlockPattern)
if (-not $catalogBlockMatch.Success) {
    Write-Host "Could not locate BEGIN/END WingetterCatalogHash markers in launcher." -ForegroundColor Red
    exit 1
}
$updated = $updated.Substring(0, $catalogBlockMatch.Index) + $catalogReplacement + $updated.Substring($catalogBlockMatch.Index + $catalogBlockMatch.Length)

if ($updated -eq $launcherText) {
    Write-Host "Launcher hashtable is already current."
    exit 0
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $LauncherPath).Path, $updated, $utf8NoBom)
Write-Host "Updated $LauncherPath with refreshed module hashes for $($moduleFiles.Count) module(s)."
