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

function Get-WingetterJsonProperty {
    param([object]$InputObject, [string]$PropertyName)
    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($property) { return $property.Value }
    return $null
}

function Get-WingetterReleaseBundleInfo {
    param([string]$RepoRoot)

    $buildScript = Join-Path $RepoRoot "tools\Build-WingetterExe.ps1"
    if (!(Test-Path $buildScript)) {
        throw "Missing release build script at $buildScript."
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-release-bundle-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    try {
        $tempBundle = Join-Path $tempRoot "Wingetter.bundled.ps1"
        & $buildScript -RepoRoot $RepoRoot -BundleOutput $tempBundle | Out-Null
        if (!(Test-Path $tempBundle)) {
            throw "Build script did not create a bundled launcher at $tempBundle."
        }
        $bundleItem = Get-Item -LiteralPath $tempBundle
        return [PSCustomObject]@{
            Path   = $tempBundle
            Sha256 = Get-WingetterFileSha256 -Path $tempBundle
            Size   = [int64]$bundleItem.Length
        }
    } finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-WingetterAuthenticodeSummary {
    param([string]$Path)

    $signatureCommand = Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue
    if ($signatureCommand) {
        try {
            $signature = Get-AuthenticodeSignature -FilePath $Path -ErrorAction Stop
            return [ordered]@{
                status           = [string]$signature.Status
                statusMessage    = [string]$signature.StatusMessage
                signerSubject    = if ($signature.SignerCertificate) { [string]$signature.SignerCertificate.Subject } else { "" }
                signerThumbprint = if ($signature.SignerCertificate) { [string]$signature.SignerCertificate.Thumbprint } else { "" }
                timestamp        = if ($signature.TimeStamperCertificate) { [string]$signature.TimeStamperCertificate.NotBefore.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") } else { "" }
                unsignedReason   = if ([string]$signature.Status -eq "NotSigned") { "No code-signing certificate was available in the local build environment." } else { "" }
            }
        } catch {
            # Fall through to the certificate probe below. Some locked-down or
            # mixed-host sessions can fail to load Microsoft.PowerShell.Security
            # type data even though release verification still needs to record
            # whether the EXE carries an embedded signature.
        }
    }

    try {
        $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromSignedFile((Resolve-Path -LiteralPath $Path).Path)
        return [ordered]@{
            status           = "SignedStatusUnavailable"
            statusMessage    = "Embedded signature certificate was found, but Get-AuthenticodeSignature was unavailable in this host."
            signerSubject    = [string]$certificate.Subject
            signerThumbprint = [string]$certificate.Thumbprint
            timestamp        = ""
            unsignedReason   = ""
        }
    } catch {
        return [ordered]@{
            status           = "NotSigned"
            statusMessage    = "No embedded Authenticode signature was found; Get-AuthenticodeSignature was unavailable in this host."
            signerSubject    = ""
            signerThumbprint = ""
            timestamp        = ""
            unsignedReason   = "No code-signing certificate was available in the local build environment."
        }
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

$bundleInfo = Get-WingetterReleaseBundleInfo -RepoRoot $repoRoot
$artifacts = @($manifest.artifacts)
if ($artifacts.Count -eq 0) {
    Write-Host "Release manifest declares no artifacts to verify." -ForegroundColor Yellow
    exit 0
}

$failures = New-Object System.Collections.Generic.List[string]
$updates = New-Object System.Collections.Generic.List[hashtable]
$exePath = Join-Path $repoRoot "Wingetter.exe"
$exeVersionInfo = if (Test-Path $exePath) { [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath) } else { $null }
$authenticode = if (Test-Path $exePath) { Get-WingetterAuthenticodeSummary -Path $exePath } else { $null }

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
    $ps2exeModule = Get-Module -ListAvailable -Name PS2EXE | Sort-Object Version -Descending | Select-Object -First 1
    $updated = [ordered]@{
        schema          = "Wingetter.ReleaseArtifactManifest.v1"
        version         = [string]$manifest.version
        generatedAtUtc  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        build           = [ordered]@{
            source        = "Bundled launcher generated from Wingetter.ps1 plus the dot-sourced modules under src/ at $($manifest.version)"
            tool          = "tools\\Build-WingetterExe.ps1"
            ps2exeVersion = if ($ps2exeModule) { [string]$ps2exeModule.Version } else { "" }
            bundle        = [ordered]@{
                path        = "release\\Wingetter.bundled.ps1"
                sha256      = $bundleInfo.Sha256
                size        = [int64]$bundleInfo.Size
                generatedBy = "tools\\Build-WingetterExe.ps1"
            }
            exe           = [ordered]@{
                path                    = "Wingetter.exe"
                builtFromBundleSha256   = $bundleInfo.Sha256
                fileDescription         = if ($exeVersionInfo) { [string]$exeVersionInfo.FileDescription } else { "" }
                comments                = if ($exeVersionInfo) { [string]$exeVersionInfo.Comments } else { "" }
                productName             = if ($exeVersionInfo) { [string]$exeVersionInfo.ProductName } else { "" }
                productVersion          = if ($exeVersionInfo) { [string]$exeVersionInfo.ProductVersion } else { "" }
                fileVersion             = if ($exeVersionInfo) { [string]$exeVersionInfo.FileVersion } else { "" }
            }
            authenticode = $authenticode
            notes        = if ($authenticode -and $authenticode.status -eq "Valid") {
                "Wingetter.exe is rebuilt locally from a parser-checked bundled launcher and carries a valid Authenticode signature."
            } else {
                "Wingetter.exe is rebuilt locally from a parser-checked bundled launcher. No code-signing certificate was available in this environment; install trust is provided by the checked SHA256, size, bundled-source hash, and explicit Authenticode status."
            }
        }
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

$manifestBundle = Get-WingetterJsonProperty -InputObject $manifest.build -PropertyName "bundle"
if ($null -eq $manifestBundle) {
    $failures.Add("Release manifest build metadata is missing bundle provenance.")
} else {
    $manifestBundleHash = ([string](Get-WingetterJsonProperty -InputObject $manifestBundle -PropertyName "sha256")).ToUpperInvariant()
    $manifestBundleSize = [int64](Get-WingetterJsonProperty -InputObject $manifestBundle -PropertyName "size")
    if ([string]::IsNullOrWhiteSpace($manifestBundleHash)) {
        $failures.Add("Release manifest build metadata is missing bundle SHA256.")
    } elseif ($manifestBundleHash -ne $bundleInfo.Sha256) {
        $failures.Add("Bundled launcher SHA256 mismatch. Current source bundle is $($bundleInfo.Sha256), manifest records $manifestBundleHash.")
    }
    if ($manifestBundleSize -ne [int64]$bundleInfo.Size) {
        $failures.Add("Bundled launcher size mismatch. Current source bundle is $($bundleInfo.Size) bytes, manifest records $manifestBundleSize bytes.")
    }
}

$manifestExe = Get-WingetterJsonProperty -InputObject $manifest.build -PropertyName "exe"
if ($null -eq $manifestExe) {
    $failures.Add("Release manifest build metadata is missing EXE provenance.")
} else {
    $builtFromBundleHash = ([string](Get-WingetterJsonProperty -InputObject $manifestExe -PropertyName "builtFromBundleSha256")).ToUpperInvariant()
    if ($builtFromBundleHash -ne $bundleInfo.Sha256) {
        $failures.Add("EXE provenance does not match current bundled launcher hash. Current source bundle is $($bundleInfo.Sha256), manifest records $builtFromBundleHash.")
    }
    $versionMetadata = if ($exeVersionInfo) { "$($exeVersionInfo.FileDescription) $($exeVersionInfo.Comments)" } else { "" }
    if ($exeVersionInfo -and ($versionMetadata -notmatch [regex]::Escape($bundleInfo.Sha256))) {
        $failures.Add("Wingetter.exe version metadata does not include the current bundled launcher SHA256.")
    }
}

$manifestAuthenticode = Get-WingetterJsonProperty -InputObject $manifest.build -PropertyName "authenticode"
if ($null -eq $manifestAuthenticode) {
    $failures.Add("Release manifest build metadata is missing Authenticode status.")
} elseif ($authenticode) {
    $manifestStatus = [string](Get-WingetterJsonProperty -InputObject $manifestAuthenticode -PropertyName "status")
    if ($manifestStatus -ne [string]$authenticode.status) {
        $failures.Add("Authenticode status mismatch. Current Wingetter.exe is '$($authenticode.status)', manifest records '$manifestStatus'.")
    }
    if ($authenticode.status -eq "NotSigned") {
        $unsignedReason = [string](Get-WingetterJsonProperty -InputObject $manifestAuthenticode -PropertyName "unsignedReason")
        if ([string]::IsNullOrWhiteSpace($unsignedReason)) {
            $failures.Add("Wingetter.exe is unsigned, but the manifest does not record an explicit unsignedReason.")
        }
    }
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
