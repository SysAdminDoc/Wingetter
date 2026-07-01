# ============================================================================
# SCOOP SOURCE ADAPTER (read-only)
# ============================================================================

function Get-WingetterScoopRoot {
    if (![string]::IsNullOrWhiteSpace($env:SCOOP)) { return $env:SCOOP }
    $default = Join-Path $env:USERPROFILE "scoop"
    if (Test-Path -LiteralPath $default) { return $default }
    return ""
}

function Test-WingetterScoopAvailable {
    $root = Get-WingetterScoopRoot
    if ([string]::IsNullOrWhiteSpace($root) -or !(Test-Path -LiteralPath $root)) {
        return New-WinGetAvailabilityStatus -Status "Missing" -Installed $false -Message "Scoop is not installed." -Blocker "Missing" -CanRepair $false
    }
    $scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue
    if (!$scoopCmd) {
        return New-WinGetAvailabilityStatus -Status "Missing" -Installed $false -Message "Scoop directory exists but scoop is not on PATH." -Blocker "Missing" -CanRepair $false
    }
    $version = ""
    try {
        $output = & scoop --version 2>&1 | Out-String
        if ($output -match '(\d+\.\d+[\.\d]*)') { $version = $matches[1] }
    } catch {}
    return New-WinGetAvailabilityStatus -Status "Available" -Installed $true -Version $version -Path ([string]$scoopCmd.Source) -Message "Scoop is available." -Blocker "None" -CanRepair $false
}

function Get-WingetterScoopInstalledApps {
    param([string]$ScoopRoot = (Get-WingetterScoopRoot))

    $apps = [System.Collections.ArrayList]::new()
    if ([string]::IsNullOrWhiteSpace($ScoopRoot)) { return [object[]]$apps.ToArray() }
    $appsDir = Join-Path $ScoopRoot "apps"
    if (!(Test-Path -LiteralPath $appsDir)) { return [object[]]$apps.ToArray() }
    foreach ($appDir in @(Get-ChildItem -LiteralPath $appsDir -Directory -ErrorAction SilentlyContinue)) {
        $name = $appDir.Name
        if ($name -eq "scoop") { continue }
        $currentDir = Join-Path $appDir.FullName "current"
        $version = ""
        $bucket = ""
        if (Test-Path -LiteralPath $currentDir) {
            $installJson = Join-Path $currentDir "install.json"
            if (Test-Path -LiteralPath $installJson) {
                try {
                    $install = Get-Content -LiteralPath $installJson -Raw | ConvertFrom-Json
                    if ($install.PSObject.Properties["bucket"]) { $bucket = [string]$install.bucket }
                } catch {}
            }
            $target = Get-Item -LiteralPath $currentDir -ErrorAction SilentlyContinue
            if ($target -and $target.PSObject.Properties["Target"]) {
                $linkTarget = [string]$target.Target
                if ($linkTarget -match '[\\/](\d[\d\.\-]+\d)[\\/]?$') { $version = $matches[1] }
            }
            if ([string]::IsNullOrWhiteSpace($version)) {
                $versionDirs = @(Get-ChildItem -LiteralPath $appDir.FullName -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "current" -and $_.Name -match '^\d' } | Sort-Object Name -Descending)
                if ($versionDirs.Count -gt 0) { $version = $versionDirs[0].Name }
            }
        }
        [void]$apps.Add([PSCustomObject][ordered]@{
            PackageId        = "scoop/$name"
            Name             = $name
            InstalledVersion = $version
            AvailableVersion = ""
            IsUpdateAvailable = $false
            Source           = if ($bucket) { "scoop/$bucket" } else { "scoop" }
            Scope            = "user"
            DetectionMethod  = "ScoopAppsDirectory"
            ScannedAtUtc     = (Get-Date).ToUniversalTime().ToString("o")
        })
    }
    return [object[]]$apps.ToArray()
}

function Get-WingetterScoopSourceAdapter {
    $capabilities = [ordered]@{
        Search             = $false
        Details            = $false
        Install            = $false
        Upgrade            = $false
        Uninstall          = $false
        ExportProfile      = $false
        ImportProfile      = $false
        InstalledScan      = $true
        Pin                = $false
        Hold               = $false
        Bootstrap          = $false
        CommandPreview     = $false
    }

    $notSupported = { throw "Scoop source adapter is read-only." }

    $operations = [ordered]@{
        TestAvailability = { Test-WingetterScoopAvailable }
        InstallManager = $notSupported
        Search = $notSupported
        GetDetails = {
            param([string]$PackageId, [string]$SourceName = "")
            [void]$PackageId; [void]$SourceName
            [PSCustomObject]@{ Source = "scoop"; Publisher = ""; InstallerType = ""; InstallerUrl = ""; InstallerHash = ""; ProductCode = ""; Description = "" }
        }
        Install = $notSupported
        Upgrade = $notSupported
        Uninstall = $notSupported
        ExportProfile = $notSupported
        ImportProfile = $notSupported
        GetInstalledCatalogPackages = {
            param([string[]]$PackageIds, [string]$SourceName = "")
            [void]$PackageIds; [void]$SourceName
            $apps = Get-WingetterScoopInstalledApps
            $records = @{}
            foreach ($app in @($apps)) { $records[[string]$app.PackageId] = $app }
            [PSCustomObject]@{
                Packages        = $records
                ScannedAtUtc    = (Get-Date).ToUniversalTime().ToString("o")
                DetectionMethod = "ScoopAppsDirectory"
                Error           = ""
            }
        }
        GetPinStatus = {
            param([string]$PackageId)
            [PSCustomObject]@{ PackageId = $PackageId; IsPinned = $false; PinType = "None"; Summary = "Not supported" }
        }
        InvokePinOperation = $notSupported
        GetInstallCommand = {
            param([string]$PackageId, [string]$SourceName = "", [bool]$Silent, [bool]$AcceptAgreements, [object]$InstallOptions = $null)
            [void]$SourceName; [void]$Silent; [void]$AcceptAgreements; [void]$InstallOptions
            $name = $PackageId -replace '^scoop/', ''
            "scoop install $name"
        }
    }

    New-WingetterPackageSourceAdapter -Name "scoop" -DisplayName "Scoop" -CommandName "scoop" -Capabilities $capabilities -Operations $operations
}
