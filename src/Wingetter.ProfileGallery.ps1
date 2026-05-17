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

    $allowedProfileProperties = @("Schema", "ProfileId", "Name", "Description", "Publisher", "Generated", "Tags", "Packages")
    foreach ($property in @($Content.PSObject.Properties.Name)) {
        if ($allowedProfileProperties -notcontains $property) {
            throw "Public profile contains unsupported top-level field '$property'."
        }
    }

    $packages = Get-WingetterGalleryJsonProperty -InputObject $Content -PropertyName "Packages"
    if (!$packages) { throw "Public profile does not contain any packages." }

    $entries = [System.Collections.ArrayList]::new()
    $seenIds = @{}
    foreach ($package in @($packages)) {
        $allowedPackageProperties = @("PackageIdentifier", "SourceName", "Name")
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

        [void]$entries.Add([PSCustomObject]@{
            Name              = [string](Get-WingetterGalleryJsonProperty -InputObject $package -PropertyName "Name")
            PackageIdentifier = $packageId
            SourceName        = $sourceName
        })
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

    $profiles = [System.Collections.ArrayList]::new()
    foreach ($profile in @($index.Profiles)) {
        $profilePath = [string]$profile.ProfilePath
        if ([string]::IsNullOrWhiteSpace($profilePath)) {
            throw "Profile gallery entry '$($profile.Id)' is missing ProfilePath."
        }

        $resolvedProfilePath = if ([System.IO.Path]::IsPathRooted($profilePath)) {
            $profilePath
        } else {
            Join-Path $rootPath $profilePath
        }

        [void]$profiles.Add([PSCustomObject]@{
            Id                  = [string]$profile.Id
            Name                = [string]$profile.Name
            Description         = [string]$profile.Description
            Publisher           = [string]$profile.Publisher
            Tags                = [string[]]@($profile.Tags | ForEach-Object { [string]$_ })
            ProfilePath         = $profilePath
            ResolvedProfilePath = $resolvedProfilePath
            Sha256              = ([string]$profile.Sha256).ToUpperInvariant()
            PackageCount        = [int]$profile.PackageCount
            SourceNames         = [string[]]@($profile.SourceNames | ForEach-Object { [string]$_ })
        })
    }

    return [object[]]$profiles.ToArray()
}

function Get-WingetterProfileGalleryItem {
    param([object]$Profile)

    if ($null -eq $Profile) { throw "Profile gallery item is required." }
    if ([string]::IsNullOrWhiteSpace([string]$Profile.ResolvedProfilePath) -or !(Test-Path $Profile.ResolvedProfilePath)) {
        throw "Profile file '$($Profile.ProfilePath)' was not found."
    }

    $actualHash = (Get-FileHash -Path $Profile.ResolvedProfilePath -Algorithm SHA256).Hash.ToUpperInvariant()
    $expectedHash = ([string]$Profile.Sha256).ToUpperInvariant()
    if ([string]::IsNullOrWhiteSpace($expectedHash) -or $actualHash -ne $expectedHash) {
        throw "Profile '$($Profile.Id)' failed SHA256 verification."
    }

    $content = Get-Content -Path $Profile.ResolvedProfilePath -Raw | ConvertFrom-Json
    $parsed = ConvertFrom-WingetterPublicProfileJson -Content $content
    if ($Profile.PackageCount -gt 0 -and $parsed.PackageIds.Count -ne $Profile.PackageCount) {
        throw "Profile '$($Profile.Id)' declares $($Profile.PackageCount) packages but contains $($parsed.PackageIds.Count)."
    }

    [PSCustomObject]@{
        Id             = $Profile.Id
        Name           = if (![string]::IsNullOrWhiteSpace($parsed.Name)) { $parsed.Name } else { $Profile.Name }
        Description    = if (![string]::IsNullOrWhiteSpace($parsed.Description)) { $parsed.Description } else { $Profile.Description }
        Publisher      = if (![string]::IsNullOrWhiteSpace($parsed.Publisher)) { $parsed.Publisher } else { $Profile.Publisher }
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
        [void]$sb.AppendLine("- $($package.PackageIdentifier) | source: $($package.SourceName)$name")
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
    foreach ($profile in @($Profiles)) {
        try {
            $item = Get-WingetterProfileGalleryItem -Profile $profile
            if (!$item.Verified) {
                [void]$failures.Add("Profile '$($profile.Id)' did not verify.")
            }
            foreach ($packageId in @($item.PackageIds)) {
                if ($CatalogPackageIds.Count -gt 0 -and !$CatalogPackageIds.ContainsKey($packageId)) {
                    [void]$failures.Add("Profile '$($profile.Id)' references package '$packageId' that is not in the catalog.")
                }
            }
            foreach ($sourceName in @($item.SourceNames)) {
                if ([string]::IsNullOrWhiteSpace([string]$sourceName)) {
                    [void]$failures.Add("Profile '$($profile.Id)' has a package without an explicit source.")
                }
            }
        } catch {
            [void]$failures.Add("Profile '$($profile.Id)' failed validation: $($_.Exception.Message)")
        }
    }

    [PSCustomObject]@{
        Valid    = ($failures.Count -eq 0)
        Failures = [string[]]$failures.ToArray([string])
    }
}
