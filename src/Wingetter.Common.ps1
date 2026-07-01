# Shared helpers for dot-sourced Wingetter modules.
function Get-WingetterRootPath {
    $rootVar = Get-Variable -Name WingetterRoot -Scope Script -ErrorAction SilentlyContinue
    if ($rootVar -and ![string]::IsNullOrWhiteSpace([string]$rootVar.Value)) {
        return [string]$rootVar.Value
    }
    if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return (Split-Path -Parent $PSScriptRoot)
    }
    return $null
}

function Get-WingetterAppDataPath {
    $root = Join-Path $env:APPDATA "Wingetter"
    if (!(Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    return $root
}

function Get-WingetterSettingsPath {
    Join-Path (Get-WingetterAppDataPath) "settings.json"
}

function Move-WingetterCorruptFileAside {
    # Preserve the unreadable file for manual recovery instead of replacing it
    # with fresh defaults on the next save.
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path)) { return }
    $corruptPath = "$Path.corrupt"
    try {
        if (Test-Path -LiteralPath $corruptPath) {
            Remove-Item -LiteralPath $corruptPath -Force -ErrorAction SilentlyContinue
        }
        Move-Item -LiteralPath $Path -Destination $corruptPath -Force -ErrorAction Stop
        Write-Warning "Wingetter could not parse '$Path'; moved it to '$corruptPath' so a clean file can be written. The original is preserved for manual recovery."
    } catch {
        Write-Warning "Wingetter could not parse '$Path' and also could not move it aside: $($_.Exception.Message)"
    }
}

function New-WingetterDefaultSettings {
    [PSCustomObject][ordered]@{
        Schema          = "Wingetter.Settings.v1"
        PrivateIconMode = $false
        IconCacheTtlDays = 30
        WindowLeft      = $null
        WindowTop       = $null
        WindowWidth     = $null
        WindowHeight    = $null
        WindowState     = $null
        UpdateSortBy    = "Name"
        UpdatedAtUtc    = (Get-Date).ToUniversalTime().ToString("o")
    }
}

function Save-WingetterWindowBounds {
    param(
        [System.Windows.Window]$Window,
        [string]$Path = (Get-WingetterSettingsPath)
    )

    if ($null -eq $Window) { return }
    $state = [string]$Window.WindowState
    $bounds = if ($Window.WindowState -eq [System.Windows.WindowState]::Normal) {
        @{ Left = $Window.Left; Top = $Window.Top; Width = $Window.Width; Height = $Window.Height }
    } elseif ($null -ne $Window.RestoreBounds -and $Window.RestoreBounds.Width -gt 0) {
        @{ Left = $Window.RestoreBounds.Left; Top = $Window.RestoreBounds.Top; Width = $Window.RestoreBounds.Width; Height = $Window.RestoreBounds.Height }
    } else {
        return
    }
    $settings = Get-WingetterSettings -Path $Path
    $settings.WindowLeft = [math]::Round($bounds.Left)
    $settings.WindowTop = [math]::Round($bounds.Top)
    $settings.WindowWidth = [math]::Round($bounds.Width)
    $settings.WindowHeight = [math]::Round($bounds.Height)
    $settings.WindowState = $state
    Save-WingetterSettings -Settings $settings -Path $Path
}

function Restore-WingetterWindowBounds {
    param(
        [System.Windows.Window]$Window,
        [string]$Path = (Get-WingetterSettingsPath)
    )

    if ($null -eq $Window) { return }
    $settings = Get-WingetterSettings -Path $Path
    if ($null -eq $settings.WindowWidth -or $null -eq $settings.WindowHeight) { return }
    $w = [int]$settings.WindowWidth
    $h = [int]$settings.WindowHeight
    $minW = if ($Window.MinWidth -gt 0) { [int]$Window.MinWidth } else { 800 }
    $minH = if ($Window.MinHeight -gt 0) { [int]$Window.MinHeight } else { 500 }
    if ($w -lt $minW -or $h -lt $minH -or $w -gt 8000 -or $h -gt 5000) { return }
    $left = if ($null -ne $settings.WindowLeft) { [int]$settings.WindowLeft } else { 0 }
    $top = if ($null -ne $settings.WindowTop) { [int]$settings.WindowTop } else { 0 }
    $intersects = $false
    foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        $work = $screen.WorkingArea
        $overlapL = [math]::Max($left, $work.Left)
        $overlapT = [math]::Max($top, $work.Top)
        $overlapR = [math]::Min($left + $w, $work.Right)
        $overlapB = [math]::Min($top + $h, $work.Bottom)
        if (($overlapR - $overlapL) -gt 50 -and ($overlapB - $overlapT) -gt 50) {
            $intersects = $true
            break
        }
    }
    if (-not $intersects) { return }
    $Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
    $Window.Left = $left
    $Window.Top = $top
    $Window.Width = $w
    $Window.Height = $h
    if ($settings.WindowState -eq "Maximized") {
        $Window.WindowState = [System.Windows.WindowState]::Maximized
    }
}

function Get-WingetterSettings {
    param([string]$Path = (Get-WingetterSettingsPath))

    $settings = New-WingetterDefaultSettings
    if (Test-Path -LiteralPath $Path) {
        try {
            $loaded = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
            foreach ($propertyName in Get-WingetterObjectPropertyNames -InputObject $settings) {
                $value = Get-WingetterObjectPropertyValue -InputObject $loaded -PropertyName $propertyName
                if ($null -ne $value) {
                    $settings.$propertyName = $value
                }
            }
        } catch {
            Move-WingetterCorruptFileAside -Path $Path
        }
    }

    $settings.Schema = "Wingetter.Settings.v1"
    $settings.PrivateIconMode = [bool]$settings.PrivateIconMode
    if ($null -eq $settings.IconCacheTtlDays -or "$($settings.IconCacheTtlDays)" -notmatch '^\d+$') {
        $settings.IconCacheTtlDays = 30
    } else {
        $settings.IconCacheTtlDays = [int]$settings.IconCacheTtlDays
    }
    return $settings
}

function Save-WingetterSettings {
    param(
        [object]$Settings,
        [string]$Path = (Get-WingetterSettingsPath)
    )

    $defaults = New-WingetterDefaultSettings
    $settingsToSave = [PSCustomObject][ordered]@{}
    foreach ($propertyName in Get-WingetterObjectPropertyNames -InputObject $defaults) {
        $value = Get-WingetterObjectPropertyValue -InputObject $Settings -PropertyName $propertyName
        if ($null -eq $value) { $value = Get-WingetterObjectPropertyValue -InputObject $defaults -PropertyName $propertyName }
        $settingsToSave | Add-Member -MemberType NoteProperty -Name $propertyName -Value $value
    }
    $settingsToSave.Schema = "Wingetter.Settings.v1"
    $settingsToSave.PrivateIconMode = [bool]$settingsToSave.PrivateIconMode
    $settingsToSave.UpdatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")

    $json = ($settingsToSave | ConvertTo-Json -Depth 6) + [Environment]::NewLine
    Set-WingetterFileAtomic -Path $Path -Content $json -Encoding UTF8
    return $settingsToSave
}

function Set-WingetterPrivateIconMode {
    param(
        [bool]$Enabled,
        [string]$Path = (Get-WingetterSettingsPath)
    )

    $settings = Get-WingetterSettings -Path $Path
    $settings.PrivateIconMode = [bool]$Enabled
    Save-WingetterSettings -Settings $settings -Path $Path
}

function Set-WingetterFileAtomic {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content,
        [string]$Encoding = "UTF8"
    )
    $directory = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($directory) -and !(Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $tempName = ".$([System.IO.Path]::GetFileName($Path)).$([System.Guid]::NewGuid().ToString('N')).tmp"
    $tempPath = if ($directory) { Join-Path $directory $tempName } else { $tempName }
    try {
        Set-Content -Path $tempPath -Value $Content -Encoding $Encoding -ErrorAction Stop
        Move-Item -Path $tempPath -Destination $Path -Force -ErrorAction Stop
    } catch {
        if (Test-Path $tempPath) {
            try { Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue } catch {}
        }
        throw
    }
}

if (-not (Get-Command Get-WingetterFileSha256 -ErrorAction SilentlyContinue)) {
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
}

function Get-WingetterObjectPropertyValue {
    param(
        [object]$InputObject,
        [string]$PropertyName
    )

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($PropertyName)) { return $InputObject[$PropertyName] }
        foreach ($key in @($InputObject.Keys)) {
            if ([string]::Equals([string]$key, $PropertyName, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $InputObject[$key]
            }
        }
        return $null
    }

    foreach ($property in @($InputObject.PSObject.Properties)) {
        if ([string]::Equals([string]$property.Name, $PropertyName, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $property.Value
        }
    }
    return $null
}

function Get-WingetterObjectPropertyNames {
    param([object]$InputObject)

    if ($null -eq $InputObject) { return @() }
    if ($InputObject -is [System.Collections.IDictionary]) {
        return [string[]]@($InputObject.Keys | ForEach-Object { [string]$_ })
    }
    return [string[]]@($InputObject.PSObject.Properties | ForEach-Object { [string]$_.Name })
}

$Script:WingetterInstallOptionAliases = @{
    "PackageVersion" = "Version"
    "Version"        = "Version"
    "Scope"          = "Scope"
    "Architecture"   = "Architecture"
    "InstallerType"  = "InstallerType"
    "Installer"      = "InstallerType"
    "Locale"         = "Locale"
    "Location"       = "Location"
    "InstallLocation" = "Location"
    "Custom"         = "Custom"
}

$Script:WingetterInstallOptionUnsafeNames = @(
    "Arguments",
    "Argument",
    "InstallArguments",
    "InstallerArguments",
    "Override",
    "Command",
    "CommandLine",
    "Script",
    "Header",
    "Proxy",
    "IgnoreSecurityHash"
)

function Get-WingetterInstallOptionCanonicalName {
    param([string]$Name)

    foreach ($key in @($Script:WingetterInstallOptionAliases.Keys)) {
        if ([string]::Equals($key, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [string]$Script:WingetterInstallOptionAliases[$key]
        }
    }
    return ""
}

function Test-WingetterUnsafeInstallOptionName {
    param([string]$Name)

    foreach ($unsafe in $Script:WingetterInstallOptionUnsafeNames) {
        if ([string]::Equals($unsafe, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Assert-WingetterInstallOptionText {
    param(
        [string]$Name,
        [string]$Value,
        [int]$MaxLength = 256,
        [bool]$AllowLeadingDash = $false
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { throw "Install option '$Name' cannot be empty." }
    if ($Value.Length -gt $MaxLength) { throw "Install option '$Name' is longer than $MaxLength characters." }
    if ([regex]::IsMatch($Value, '[\x00-\x1F\x7F]')) { throw "Install option '$Name' cannot contain control characters." }
    if (!$AllowLeadingDash -and $Value.StartsWith("-", [System.StringComparison]::Ordinal)) {
        throw "Install option '$Name' cannot start with '-'."
    }
}

function ConvertTo-WingetterInstallOptions {
    param(
        [object]$InstallOptions,
        [string[]]$AllowedProperties = @(),
        [bool]$AllowCustom = $false
    )

    $result = [ordered]@{}
    if ($null -eq $InstallOptions) { return [PSCustomObject]$result }
    if ($InstallOptions -is [string]) { throw "InstallOptions must be a JSON object, not a string." }

    $allowed = @{}
    foreach ($propertyName in @($AllowedProperties)) {
        $canonicalAllowed = Get-WingetterInstallOptionCanonicalName -Name $propertyName
        if ([string]::IsNullOrWhiteSpace($canonicalAllowed)) { throw "Unsupported install option allow-list field '$propertyName'." }
        $allowed[$canonicalAllowed] = $true
    }

    foreach ($propertyName in Get-WingetterObjectPropertyNames -InputObject $InstallOptions) {
        if (Test-WingetterUnsafeInstallOptionName -Name $propertyName) {
            throw "Install option field '$propertyName' is not supported. Use constrained InstallOptions fields instead of raw installer arguments."
        }

        $canonical = Get-WingetterInstallOptionCanonicalName -Name $propertyName
        if ([string]::IsNullOrWhiteSpace($canonical)) {
            throw "Unsupported install option field '$propertyName'."
        }
        if ($allowed.Count -gt 0 -and !$allowed.ContainsKey($canonical)) {
            throw "Install option '$canonical' is not allow-listed for this profile."
        }
        if ($canonical -eq "Custom" -and !$AllowCustom) {
            throw "Install option 'Custom' requires explicit allow-listing."
        }

        $rawValue = Get-WingetterObjectPropertyValue -InputObject $InstallOptions -PropertyName $propertyName
        if ($null -eq $rawValue) { continue }
        $value = ([string]$rawValue).Trim()
        if ([string]::IsNullOrWhiteSpace($value)) { continue }

        switch ($canonical) {
            "Version" {
                Assert-WingetterInstallOptionText -Name $canonical -Value $value -MaxLength 128
                $result[$canonical] = $value
            }
            "Scope" {
                $normalized = $value.ToLowerInvariant()
                if (@("user", "machine") -notcontains $normalized) { throw "Install option 'Scope' must be 'user' or 'machine'." }
                $result[$canonical] = $normalized
            }
            "Architecture" {
                $normalized = $value.ToLowerInvariant()
                if (@("x86", "x64", "arm", "arm64", "neutral") -notcontains $normalized) { throw "Install option 'Architecture' has unsupported value '$value'." }
                $result[$canonical] = $normalized
            }
            "InstallerType" {
                $normalized = $value.ToLowerInvariant()
                $validInstallerTypes = @("exe", "msi", "msix", "appx", "zip", "inno", "nullsoft", "wix", "burn", "portable", "font")
                if ($validInstallerTypes -notcontains $normalized) { throw "Install option 'InstallerType' has unsupported value '$value'." }
                $result[$canonical] = $normalized
            }
            "Locale" {
                Assert-WingetterInstallOptionText -Name $canonical -Value $value -MaxLength 64
                if ($value -notmatch '^[A-Za-z]{2,8}(-[A-Za-z0-9]{2,8})*$') { throw "Install option 'Locale' is not a valid locale tag." }
                $result[$canonical] = $value
            }
            "Location" {
                Assert-WingetterInstallOptionText -Name $canonical -Value $value -MaxLength 260 -AllowLeadingDash $true
                $result[$canonical] = $value
            }
            "Custom" {
                Assert-WingetterInstallOptionText -Name $canonical -Value $value -MaxLength 512 -AllowLeadingDash $true
                $result[$canonical] = $value
            }
        }
    }

    return [PSCustomObject]$result
}

function Test-WingetterInstallOptionsEmpty {
    param([object]$InstallOptions)

    if ($null -eq $InstallOptions) { return $true }
    return (@($InstallOptions.PSObject.Properties).Count -eq 0)
}

function ConvertTo-WingetterInstallOptionsSummary {
    param([object]$InstallOptions)

    $options = ConvertTo-WingetterInstallOptions -InstallOptions $InstallOptions -AllowCustom $true
    $parts = [System.Collections.ArrayList]::new()
    foreach ($name in @("Version", "Scope", "Architecture", "InstallerType", "Locale", "Location", "Custom")) {
        $property = $options.PSObject.Properties[$name]
        if ($property -and ![string]::IsNullOrWhiteSpace([string]$property.Value)) {
            [void]$parts.Add("$name=$($property.Value)")
        }
    }
    return ([string[]]$parts.ToArray([string]) -join "; ")
}
