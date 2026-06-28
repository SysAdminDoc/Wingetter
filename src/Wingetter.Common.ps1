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
