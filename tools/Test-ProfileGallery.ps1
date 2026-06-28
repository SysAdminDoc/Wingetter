param(
    [string]$SourceDir = (Join-Path $PSScriptRoot "..\src")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
}

foreach ($moduleName in @("Wingetter.Common.ps1", "Wingetter.Catalog.ps1", "Wingetter.Groups.ps1", "Wingetter.ProfileGallery.ps1")) {
    $modulePath = Join-Path $SourceDir $moduleName
    if (!(Test-Path $modulePath)) {
        Add-Failure "Missing source module '$moduleName'."
        continue
    }
    try {
        . (Resolve-Path $modulePath).Path
    } catch {
        Add-Failure "Could not import '$moduleName': $($_.Exception.Message)"
    }
}

if ($failures.Count -eq 0) {
    $catalogIds = @{}
    foreach ($category in $Script:SoftwareDatabase.Keys) {
        foreach ($app in @($Script:SoftwareDatabase[$category])) {
            $catalogIds[[string]$app.WingetId] = $true
        }
    }

    try {
        $profiles = @(Get-WingetterProfileGalleryIndex)
        if ($profiles.Count -lt 3) {
            Add-Failure "Expected at least 3 gallery profiles, found $($profiles.Count)."
        }

        $validation = Test-WingetterProfileGallery -Profiles $profiles -CatalogPackageIds $catalogIds
        if (!$validation.Valid) {
            foreach ($failure in @($validation.Failures)) {
                Add-Failure $failure
            }
        }

        $essential = $profiles | Where-Object { $_.Id -eq "essential-pc" } | Select-Object -First 1
        if (!$essential) {
            Add-Failure "Missing essential-pc gallery profile."
        } else {
            $item = Get-WingetterProfileGalleryItem -Profile $essential
            if (!$item.Verified -or $item.PackageIds -notcontains "Google.Chrome") {
                Add-Failure "essential-pc profile did not verify or include Google.Chrome."
            }
            $preview = ConvertTo-WingetterProfileGalleryPreviewText -GalleryItem $item
            if ($preview -notmatch "Google.Chrome" -or $preview -notmatch "source: winget" -or $preview -notmatch "does not install") {
                Add-Failure "Profile gallery preview text did not include package IDs, sources, and no-auto-run wording."
            }

            $badHashProfile = [PSCustomObject]@{}
            foreach ($property in $essential.PSObject.Properties) {
                $badHashProfile | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
            }
            $badHashProfile.Sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
            try {
                Get-WingetterProfileGalleryItem -Profile $badHashProfile | Out-Null
                Add-Failure "Profile hash mismatch was not rejected."
            } catch {
                if ($_.Exception.Message -notmatch "SHA256") {
                    Add-Failure "Profile hash mismatch failed with unexpected message: $($_.Exception.Message)"
                }
            }
        }

        $unsafeProfile = [PSCustomObject]@{
            Schema    = "Wingetter.PublicProfile.v1"
            ProfileId = "unsafe"
            Name      = "Unsafe"
            Packages  = @(
                [PSCustomObject]@{
                    PackageIdentifier = "Google.Chrome"
                    SourceName        = "winget"
                    Arguments         = "--override hidden"
                }
            )
        }
        try {
            ConvertFrom-WingetterPublicProfileJson -Content $unsafeProfile | Out-Null
            Add-Failure "Public profile parser accepted an unsupported package argument field."
        } catch {
            if ($_.Exception.Message -notmatch "unsupported field") {
                Add-Failure "Unsafe profile failed with unexpected message: $($_.Exception.Message)"
            }
        }

        # Oversized profile file should be rejected before parsing. Generate a
        # >1MB file on disk, point an entry at it, and confirm the hash check
        # never even runs.
        $tempProfileDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-profile-bigtest-" + [System.Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $tempProfileDir -Force | Out-Null
        try {
            $bigPath = Join-Path $tempProfileDir "big.wingetter.json"
            $padding = "x" * (1MB + 1024)
            Set-Content -Path $bigPath -Value ('{"Padding":"' + $padding + '"}') -Encoding UTF8
            $bigHash = Get-WingetterFileSha256 -Path $bigPath
            $bigEntry = [PSCustomObject]@{
                Id                  = "oversized"
                Name                = "Oversized"
                Description         = ""
                Publisher           = ""
                Tags                = @()
                ProfilePath         = "big.wingetter.json"
                ResolvedProfilePath = $bigPath
                Sha256              = $bigHash
                PackageCount        = 0
                SourceNames         = @()
            }
            $oversizedRejected = $false
            try {
                Get-WingetterProfileGalleryItem -Entry $bigEntry | Out-Null
            } catch {
                $oversizedRejected = ($_.Exception.Message -match "exceeds")
            }
            if (-not $oversizedRejected) {
                Add-Failure "Oversized profile file was not rejected by the gallery size guard."
            }
        } finally {
            Remove-Item -Path $tempProfileDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Add-Failure "Profile gallery validation threw: $($_.Exception.Message)"
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Profile gallery validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Profile gallery validation passed."
