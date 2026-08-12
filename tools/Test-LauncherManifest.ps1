param(
    [string]$LauncherPath = (Join-Path $PSScriptRoot "..\Wingetter.ps1"),
    [string]$SourceDir = (Join-Path $PSScriptRoot "..\src")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
}

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
    Add-Failure "Missing launcher at $LauncherPath."
}
if (!(Test-Path $SourceDir)) {
    Add-Failure "Missing source directory at $SourceDir."
}

if ($failures.Count -eq 0) {
    $launcherText = Get-Content -Path $LauncherPath -Raw

    if ($launcherText -match 'WINGETTER_MODULE_BASE_URL') {
        Add-Failure "Launcher must use the canonical module source URL; environment-controlled redirects are not allowed."
    }

    # Extract the module file list.
    $listMatch = [regex]::Match($launcherText, '(?ms)\$Script:WingetterModuleFiles\s*=\s*@\((?<list>.*?)\)')
    if (-not $listMatch.Success) {
        Add-Failure "Launcher does not declare `$Script:WingetterModuleFiles."
    } else {
        $expectedFiles = @(
            ($listMatch.Groups['list'].Value -split ',') |
                ForEach-Object { $_.Trim().Trim('"').Trim("'") } |
                Where-Object { $_ -and $_.EndsWith('.ps1') }
        )

        # Extract the embedded hashtable.
        $hashesMatch = [regex]::Match($launcherText, '(?ms)\$Script:WingetterModuleHashes\s*=\s*@\{(?<body>.*?)\}')
        if (-not $hashesMatch.Success) {
            Add-Failure "Launcher does not declare `$Script:WingetterModuleHashes."
        } else {
            $body = $hashesMatch.Groups['body'].Value
            $entries = @{}
            foreach ($line in $body -split "`r?`n") {
                $entry = [regex]::Match($line, "^\s*'(?<file>[^']+)'\s*=\s*'(?<hash>[A-F0-9]+)'\s*$")
                if ($entry.Success) {
                    $entries[$entry.Groups['file'].Value] = $entry.Groups['hash'].Value.ToUpperInvariant()
                }
            }

            if ($entries.Count -ne $expectedFiles.Count) {
                Add-Failure "Launcher hashtable has $($entries.Count) entries but the module list has $($expectedFiles.Count)."
            }

            foreach ($file in $expectedFiles) {
                if (-not $entries.ContainsKey($file)) {
                    Add-Failure "Launcher hashtable is missing an entry for '$file'."
                    continue
                }
                $modulePath = Join-Path $SourceDir $file
                if (!(Test-Path $modulePath)) {
                    Add-Failure "Source module '$modulePath' does not exist."
                    continue
                }
                $actual = Get-WingetterFileSha256 -Path $modulePath
                if ($actual -ne $entries[$file]) {
                    Add-Failure "Launcher hashtable for '$file' is stale. Expected (from disk) $actual, embedded $($entries[$file]). Re-run tools\Sync-LauncherManifest.ps1."
                }
            }

            foreach ($entryKey in @($entries.Keys)) {
                if ($expectedFiles -notcontains $entryKey) {
                    Add-Failure "Launcher hashtable contains '$entryKey' which is not in the module list."
                }
            }
        }
    }

    # Exercise the verifier directly: extract the embedded hashtable + the
    # Test-WingetterModuleHash function from the launcher into the current
    # scope, then call it against a real source file (positive) and a
    # deliberately tampered copy (negative). This proves the launcher's
    # verification path catches a hash mismatch.
    if ($failures.Count -eq 0) {
        $tampered = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-tampered-" + [System.Guid]::NewGuid().ToString("N") + ".ps1")
        try {
            "# tampered content" | Set-Content -Path $tampered -Encoding UTF8

            $hashtableBlock = [regex]::Match($launcherText, '(?ms)\$Script:WingetterModuleHashes\s*=\s*@\{.*?\}').Value
            $functionBlock = [regex]::Match($launcherText, '(?ms)function Test-WingetterModuleHash\s*\{.*?\n\}').Value
            if ([string]::IsNullOrWhiteSpace($hashtableBlock) -or [string]::IsNullOrWhiteSpace($functionBlock)) {
                Add-Failure "Could not extract hashtable or Test-WingetterModuleHash function from launcher for probe."
            } else {
                . ([scriptblock]::Create($hashtableBlock + "`n" + $functionBlock))

                $positiveOk = $false
                try {
                    Test-WingetterModuleHash -Path (Join-Path $SourceDir "Wingetter.Common.ps1") -FileName "Wingetter.Common.ps1"
                    $positiveOk = $true
                } catch {
                    Add-Failure "Test-WingetterModuleHash rejected a canonical module: $($_.Exception.Message)"
                }

                if ($positiveOk) {
                    $negativeOk = $false
                    try {
                        Test-WingetterModuleHash -Path $tampered -FileName "Wingetter.Common.ps1"
                    } catch {
                        if ($_.Exception.Message -match "SHA256 mismatch") {
                            $negativeOk = $true
                        } else {
                            Add-Failure "Test-WingetterModuleHash failed on a tampered file with unexpected message: $($_.Exception.Message)"
                        }
                    }
                    if (-not $negativeOk) {
                        Add-Failure "Test-WingetterModuleHash accepted a tampered file - the hash-pin defense is broken."
                    }
                }
            }
        } finally {
            Remove-Item -Path $tampered -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Launcher manifest validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Launcher manifest validation passed."
