# ============================================================================
# PUBLIC PROFILE GALLERY
# ============================================================================

function Get-WingetterGalleryJsonProperty {
    param([object]$InputObject, [string]$PropertyName)
    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($property) { return $property.Value }
    return $null
}

function Get-WingetterProfileGalleryIndexPath {
    param([string]$RootPath = (Get-WingetterRootPath))

    if ([string]::IsNullOrWhiteSpace($RootPath)) { return $null }
    return (Join-Path $RootPath "profiles\gallery.json")
}

function ConvertFrom-WingetterPublicProfileJson {
    param([object]$Content)

    $schema = Get-WingetterGalleryJsonProperty -InputObject $Content -PropertyName "Schema"
    if ($schema -ne "Wingetter.PublicProfile.v1") {
        throw "Unsupported public profile schema '$schema'."
    }

    $allowedProfileProperties = @("Schema", "ProfileId", "Name", "Description", "Publisher", "Generated", "Tags", "Packages", "AllowedInstallOptionFields")
    foreach ($property in @($Content.PSObject.Properties.Name)) {
        if ($allowedProfileProperties -notcontains $property) {
            throw "Public profile contains unsupported top-level field '$property'."
        }
    }

    $packages = Get-WingetterGalleryJsonProperty -InputObject $Content -PropertyName "Packages"
    if (!$packages) { throw "Public profile does not contain any packages." }
    $allowedInstallOptionFields = [string[]]@(
        (Get-WingetterGalleryJsonProperty -InputObject $Content -PropertyName "AllowedInstallOptionFields") |
            ForEach-Object { [string]$_ } |
            Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) }
    )
    $allowCustomInstallOptions = @($allowedInstallOptionFields | Where-Object { [string]::Equals([string]$_, "Custom", [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0

    $entries = [System.Collections.ArrayList]::new()
    $seenIds = @{}
    foreach ($package in @($packages)) {
        $allowedPackageProperties = @("PackageIdentifier", "SourceName", "Name", "InstallOptions")
        foreach ($property in @($package.PSObject.Properties.Name)) {
            if ($allowedPackageProperties -notcontains $property) {
                throw "Public profile package contains unsupported field '$property'."
            }
        }

        $packageId = [string](Get-WingetterGalleryJsonProperty -InputObject $package -PropertyName "PackageIdentifier")
        if ([string]::IsNullOrWhiteSpace($packageId)) {
            throw "Public profile package is missing PackageIdentifier."
        }
        if ($seenIds.ContainsKey($packageId)) {
            throw "Public profile contains duplicate package '$packageId'."
        }
        $seenIds[$packageId] = $true

        $sourceName = [string](Get-WingetterGalleryJsonProperty -InputObject $package -PropertyName "SourceName")
        if ([string]::IsNullOrWhiteSpace($sourceName)) { $sourceName = "winget" }
        $installOptions = Get-WingetterPackageEntryInstallOptions -Package $package -AllowCustomInstallOptions:$allowCustomInstallOptions -AllowedInstallOptionFields $allowedInstallOptionFields

        $entry = [ordered]@{
            Name              = [string](Get-WingetterGalleryJsonProperty -InputObject $package -PropertyName "Name")
            PackageIdentifier = $packageId
            SourceName        = $sourceName
        }
        if (!(Test-WingetterInstallOptionsEmpty -InstallOptions $installOptions)) {
            $entry["InstallOptions"] = $installOptions
        }
        [void]$entries.Add([PSCustomObject]$entry)
    }

    [PSCustomObject]@{
        ProfileId      = [string](Get-WingetterGalleryJsonProperty -InputObject $Content -PropertyName "ProfileId")
        Name           = [string](Get-WingetterGalleryJsonProperty -InputObject $Content -PropertyName "Name")
        Description    = [string](Get-WingetterGalleryJsonProperty -InputObject $Content -PropertyName "Description")
        Publisher      = [string](Get-WingetterGalleryJsonProperty -InputObject $Content -PropertyName "Publisher")
        Tags           = [string[]]@((Get-WingetterGalleryJsonProperty -InputObject $Content -PropertyName "Tags") | ForEach-Object { [string]$_ })
        PackageEntries = [object[]]$entries.ToArray()
        PackageIds     = [string[]]@($entries | ForEach-Object { [string]$_.PackageIdentifier })
        SourceNames    = [string[]]@($entries | ForEach-Object { [string]$_.SourceName } | Select-Object -Unique)
    }
}

function Get-WingetterProfileGalleryIndex {
    param([string]$IndexPath = (Get-WingetterProfileGalleryIndexPath))

    if ([string]::IsNullOrWhiteSpace($IndexPath) -or !(Test-Path $IndexPath)) { return @() }

    $rootPath = Split-Path -Parent (Split-Path -Parent (Resolve-Path $IndexPath).Path)
    $index = Get-Content -Path $IndexPath -Raw | ConvertFrom-Json
    if ($index.Schema -ne "Wingetter.ProfileGalleryIndex.v1") {
        throw "Unsupported profile gallery index schema '$($index.Schema)'."
    }

    $entries = [System.Collections.ArrayList]::new()
    foreach ($entry in @($index.Profiles)) {
        $profilePath = [string]$entry.ProfilePath
        if ([string]::IsNullOrWhiteSpace($profilePath)) {
            throw "Profile gallery entry '$($entry.Id)' is missing ProfilePath."
        }

        $resolvedProfilePath = if ([System.IO.Path]::IsPathRooted($profilePath)) {
            $profilePath
        } else {
            Join-Path $rootPath $profilePath
        }

        [void]$entries.Add([PSCustomObject]@{
            Id                  = [string]$entry.Id
            Name                = [string]$entry.Name
            Description         = [string]$entry.Description
            Publisher           = [string]$entry.Publisher
            Tags                = [string[]]@($entry.Tags | ForEach-Object { [string]$_ })
            ProfilePath         = $profilePath
            ResolvedProfilePath = $resolvedProfilePath
            Sha256              = ([string]$entry.Sha256).ToUpperInvariant()
            PackageCount        = [int]$entry.PackageCount
            SourceNames         = [string[]]@($entry.SourceNames | ForEach-Object { [string]$_ })
        })
    }

    return [object[]]$entries.ToArray()
}

$Script:WingetterProfileMaxBytes = 1MB
$Script:WingetterProfileMaxPackages = 2000

function Get-WingetterProfileGalleryItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Alias("Profile")]
        [object]$Entry
    )

    if ($null -eq $Entry) { throw "Profile gallery item is required." }
    if ([string]::IsNullOrWhiteSpace([string]$Entry.ResolvedProfilePath) -or !(Test-Path $Entry.ResolvedProfilePath)) {
        throw "Profile file '$($Entry.ProfilePath)' was not found."
    }

    # Guard against oversized profile files before reading them into memory.
    # The gallery is intended for small curated lists; a 1MB cap prevents a
    # rogue or corrupted file from causing a multi-GB allocation when parsed.
    $fileInfo = Get-Item -Path $Entry.ResolvedProfilePath -ErrorAction Stop
    if ($fileInfo.Length -gt $Script:WingetterProfileMaxBytes) {
        throw "Profile '$($Entry.Id)' is $([math]::Round($fileInfo.Length / 1KB, 1)) KB, which exceeds the $($Script:WingetterProfileMaxBytes / 1KB) KB gallery limit."
    }

    $actualHash = Get-WingetterFileSha256 -Path $Entry.ResolvedProfilePath
    $expectedHash = ([string]$Entry.Sha256).ToUpperInvariant()
    if ([string]::IsNullOrWhiteSpace($expectedHash) -or $actualHash -ne $expectedHash) {
        throw "Profile '$($Entry.Id)' failed SHA256 verification."
    }

    $content = Get-Content -Path $Entry.ResolvedProfilePath -Raw | ConvertFrom-Json
    $parsed = ConvertFrom-WingetterPublicProfileJson -Content $content
    # Require an exact PackageCount match when the index declares one. A
    # declared count that differs from the file's actual count is a strong
    # signal that the index and the file are out of sync; refusing the import
    # prevents partial selections from a tampered manifest.
    if ($Entry.PackageCount -gt 0 -and $parsed.PackageIds.Count -ne $Entry.PackageCount) {
        throw "Profile '$($Entry.Id)' declares $($Entry.PackageCount) packages but contains $($parsed.PackageIds.Count)."
    }
    if ($parsed.PackageIds.Count -gt $Script:WingetterProfileMaxPackages) {
        throw "Profile '$($Entry.Id)' contains $($parsed.PackageIds.Count) packages, which exceeds the $($Script:WingetterProfileMaxPackages)-package gallery limit."
    }

    [PSCustomObject]@{
        Id             = $Entry.Id
        Name           = if (![string]::IsNullOrWhiteSpace($parsed.Name)) { $parsed.Name } else { $Entry.Name }
        Description    = if (![string]::IsNullOrWhiteSpace($parsed.Description)) { $parsed.Description } else { $Entry.Description }
        Publisher      = if (![string]::IsNullOrWhiteSpace($parsed.Publisher)) { $parsed.Publisher } else { $Entry.Publisher }
        Tags           = $parsed.Tags
        PackageEntries = $parsed.PackageEntries
        PackageIds     = $parsed.PackageIds
        SourceNames    = $parsed.SourceNames
        Sha256         = $actualHash
        Verified       = $true
    }
}

function ConvertTo-WingetterProfileGalleryPreviewText {
    param([object]$GalleryItem)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("Profile: $($GalleryItem.Name)")
    [void]$sb.AppendLine("Publisher: $($GalleryItem.Publisher)")
    [void]$sb.AppendLine("SHA256: $($GalleryItem.Sha256)")
    [void]$sb.AppendLine("Packages: $(@($GalleryItem.PackageEntries).Count)")
    if (![string]::IsNullOrWhiteSpace([string]$GalleryItem.Description)) {
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine($GalleryItem.Description)
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Package review")
    foreach ($package in @($GalleryItem.PackageEntries)) {
        $name = if (![string]::IsNullOrWhiteSpace([string]$package.Name)) { " - $($package.Name)" } else { "" }
        $optionsSummary = if ($package.PSObject.Properties["InstallOptions"]) { ConvertTo-WingetterInstallOptionsSummary -InstallOptions $package.InstallOptions } else { "" }
        $optionsText = if (![string]::IsNullOrWhiteSpace($optionsSummary)) { " | options: $optionsSummary" } else { "" }
        [void]$sb.AppendLine("- $($package.PackageIdentifier) | source: $($package.SourceName)$name$optionsText")
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Importing this profile only selects packages in Wingetter. It does not install or update anything.")
    return $sb.ToString()
}

function Test-WingetterProfileGallery {
    param(
        [object[]]$Profiles = (Get-WingetterProfileGalleryIndex),
        [hashtable]$CatalogPackageIds = @{}
    )

    $failures = [System.Collections.ArrayList]::new()
    foreach ($entry in @($Profiles)) {
        try {
            $item = Get-WingetterProfileGalleryItem -Entry $entry
            if (!$item.Verified) {
                [void]$failures.Add("Profile '$($entry.Id)' did not verify.")
            }
            foreach ($packageId in @($item.PackageIds)) {
                if ($CatalogPackageIds.Count -gt 0 -and !$CatalogPackageIds.ContainsKey($packageId)) {
                    [void]$failures.Add("Profile '$($entry.Id)' references package '$packageId' that is not in the catalog.")
                }
            }
            foreach ($sourceName in @($item.SourceNames)) {
                if ([string]::IsNullOrWhiteSpace([string]$sourceName)) {
                    [void]$failures.Add("Profile '$($entry.Id)' has a package without an explicit source.")
                }
            }
        } catch {
            [void]$failures.Add("Profile '$($entry.Id)' failed validation: $($_.Exception.Message)")
        }
    }

    [PSCustomObject]@{
        Valid    = ($failures.Count -eq 0)
        Failures = [string[]]$failures.ToArray([string])
    }
}
