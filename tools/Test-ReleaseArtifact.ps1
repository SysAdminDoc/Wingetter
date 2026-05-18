param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot ".."),
    [switch]$Update
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
    $actualHash = (Get-FileHash -Path $fullPath -Algorithm SHA256).Hash.ToUpperInvariant()
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
    $updated | ConvertTo-Json -Depth 6 | Set-Content -Path $manifestPath -Encoding UTF8
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
