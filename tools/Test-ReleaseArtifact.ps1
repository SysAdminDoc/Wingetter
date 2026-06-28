param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot ".."),
    [switch]$Update
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

$repoRoot = (Resolve-Path $RepoRoot).Path
$manifestPath = Join-Path $repoRoot "release\manifest.json"
if (!(Test-Path $manifestPath)) {
    Write-Host "Missing release manifest at $manifestPath." -ForegroundColor Red
    exit 1
}

$manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema -ne "Wingetter.ReleaseArtifactManifest.v1") {
    Write-Host "Unexpected manifest schema '$($manifest.schema)'." -ForegroundColor Red
    exit 1
}

$artifacts = @($manifest.artifacts)
if ($artifacts.Count -eq 0) {
    Write-Host "Release manifest declares no artifacts to verify." -ForegroundColor Yellow
    exit 0
}

$failures = New-Object System.Collections.Generic.List[string]
$updates = New-Object System.Collections.Generic.List[hashtable]

foreach ($artifact in $artifacts) {
    $relativePath = [string]$artifact.path
    $expectedHash = ([string]$artifact.sha256).ToUpperInvariant()
    $expectedSize = [int64]$artifact.size
    $fullPath = Join-Path $repoRoot $relativePath
    if (!(Test-Path $fullPath)) {
        $failures.Add("Missing release artifact '$relativePath'.")
        continue
    }
    $actualHash = Get-WingetterFileSha256 -Path $fullPath
    $actualSize = (Get-Item $fullPath).Length

    if ($Update) {
        $updates.Add(@{
            Path = $relativePath
            Sha256 = $actualHash
            Size = [int64]$actualSize
            Description = [string]$artifact.description
        })
        continue
    }

    if ($actualHash -ne $expectedHash) {
        $failures.Add("SHA256 mismatch for '$relativePath'. Expected $expectedHash, got $actualHash.")
    }
    if ($actualSize -ne $expectedSize) {
        $failures.Add("Size mismatch for '$relativePath'. Expected $expectedSize bytes, got $actualSize bytes.")
    }
}

if ($Update) {
    $updated = [ordered]@{
        schema          = "Wingetter.ReleaseArtifactManifest.v1"
        version         = [string]$manifest.version
        generatedAtUtc  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        build           = $manifest.build
        artifacts       = @($updates | ForEach-Object {
            [ordered]@{
                path        = $_.Path
                sha256      = $_.Sha256
                size        = $_.Size
                description = $_.Description
            }
        })
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($manifestPath, (($updated | ConvertTo-Json -Depth 6) + [Environment]::NewLine), $utf8NoBom)
    Write-Host "Updated $manifestPath with current artifact hashes."
    exit 0
}

if ($failures.Count -gt 0) {
    Write-Host "Release artifact verification failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    Write-Host "If the binary change is intentional, run:" -ForegroundColor Yellow
    Write-Host "  pwsh -NoProfile -File .\tools\Test-ReleaseArtifact.ps1 -Update" -ForegroundColor Yellow
    exit 1
}

Write-Host "Release artifact verification passed ($($artifacts.Count) artifact(s))."
exit 0
