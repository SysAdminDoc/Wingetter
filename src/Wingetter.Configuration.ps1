# ============================================================================
# WINGET CONFIGURATION EXPORT
# ============================================================================

function ConvertTo-WingetterYamlSingleQuotedValue {
    param([string]$Value)
    if ($null -eq $Value) { return "''" }
    # Single-quoted YAML scalars cannot embed literal line breaks; collapse any
    # newlines (which can show up in catalog descriptions) into single spaces
    # so the generated configuration is always parseable, then escape any
    # embedded single quote per the YAML spec ('' inside '...').
    $normalized = ([string]$Value) -replace "[\r\n]+", " "
    "'" + ($normalized -replace "'", "''") + "'"
}

function Test-WingetterConfigurationPackageId {
    # WinGet package identifiers follow `Publisher.Name[.Suffix]` with at most a
    # narrow set of characters. Reject anything outside that set so the
    # generated WinGet Configuration cannot contain an attacker-controlled
    # YAML string with surprise characters (control chars, quotes, brackets).
    param([string]$PackageId)
    if ([string]::IsNullOrWhiteSpace($PackageId)) { return $false }
    return [bool]([regex]::IsMatch($PackageId, '^[A-Za-z0-9][A-Za-z0-9._+\-]*$'))
}

function ConvertTo-WingetterConfigurationResourceId {
    param(
        [string]$PackageId,
        [int]$Index
    )

    $safe = ([string]$PackageId -replace '[^A-Za-z0-9_]', '_').Trim("_")
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = "package" }
    if ($safe -notmatch '^[A-Za-z_]') { $safe = "pkg_$safe" }
    return "${safe}_$Index"
}

function New-WingetterConfigurationPackageEntry {
    param(
        [string]$Name,
        [string]$PackageId,
        [string]$SourceName = "winget",
        [object]$InstallOptions = $null
    )

    $options = ConvertTo-WingetterInstallOptions -InstallOptions $InstallOptions -AllowCustom $true
    [PSCustomObject]@{
        Name           = $Name
        WingetId       = $PackageId
        SourceName     = if ([string]::IsNullOrWhiteSpace($SourceName)) { "winget" } else { $SourceName }
        InstallOptions = $options
    }
}

function Test-WingetterDscV3Available {
    try {
        $dscModule = Get-Module -ListAvailable -Name "Microsoft.WinGet.DSC" -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending | Select-Object -First 1
        if ($null -ne $dscModule -and $dscModule.Version -ge [version]"3.0.0") { return $true }
    } catch {}
    return $false
}

function ConvertTo-WingetterConfigurationYaml {
    param(
        [object[]]$PackageEntries,
        [string]$ConfigurationVersion = "0.2.0",
        [ValidateSet("Auto", "PerPackage", "PackageList")]
        [string]$ResourceFormat = "Auto"
    )

    $usePackageList = $false
    if ($ResourceFormat -eq "PackageList") {
        $usePackageList = $true
    } elseif ($ResourceFormat -eq "Auto") {
        $usePackageList = Test-WingetterDscV3Available
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# yaml-language-server: `$schema=https://aka.ms/configuration-dsc-schema/0.2")
    $lines.Add("properties:")
    $lines.Add("  resources:")

    $validEntries = [System.Collections.ArrayList]::new()
    foreach ($package in @($PackageEntries)) {
        $packageId = [string]$package.WingetId
        if ([string]::IsNullOrWhiteSpace($packageId)) { continue }
        if (-not (Test-WingetterConfigurationPackageId -PackageId $packageId)) {
            throw "Package identifier '$packageId' contains characters that are not valid in a WinGet Configuration file."
        }
        [void]$validEntries.Add($package)
    }

    if ($usePackageList -and $validEntries.Count -gt 0) {
        $lines.Add("    - resource: Microsoft.WinGet.DSC/WinGetPackageList")
        $lines.Add("      id: wingetter_packages")
        $lines.Add("      directives:")
        $lines.Add("        description: $(ConvertTo-WingetterYamlSingleQuotedValue -Value "Install $($validEntries.Count) packages")")
        $lines.Add("      settings:")
        $lines.Add("        packages:")
        foreach ($package in $validEntries) {
            $packageId = [string]$package.WingetId
            $sourceName = if (![string]::IsNullOrWhiteSpace([string]$package.SourceName)) { [string]$package.SourceName } else { "winget" }
            $lines.Add("          - id: $(ConvertTo-WingetterYamlSingleQuotedValue -Value $packageId)")
            $lines.Add("            source: $(ConvertTo-WingetterYamlSingleQuotedValue -Value $sourceName)")
            $installOptions = if ($package.PSObject.Properties["InstallOptions"]) { ConvertTo-WingetterInstallOptions -InstallOptions $package.InstallOptions -AllowCustom $true } else { ConvertTo-WingetterInstallOptions -InstallOptions $null }
            if ($installOptions.PSObject.Properties["Version"]) {
                $lines.Add("            version: $(ConvertTo-WingetterYamlSingleQuotedValue -Value ([string]$installOptions.Version))")
            }
        }
    } else {
        $index = 0
        foreach ($package in $validEntries) {
            $index++
            $packageId = [string]$package.WingetId
            $name = if (![string]::IsNullOrWhiteSpace([string]$package.Name)) { [string]$package.Name } else { $packageId }
            $sourceName = if (![string]::IsNullOrWhiteSpace([string]$package.SourceName)) { [string]$package.SourceName } else { "winget" }
            $installOptions = if ($package.PSObject.Properties["InstallOptions"]) { ConvertTo-WingetterInstallOptions -InstallOptions $package.InstallOptions -AllowCustom $true } else { ConvertTo-WingetterInstallOptions -InstallOptions $null }
            $resourceId = ConvertTo-WingetterConfigurationResourceId -PackageId $packageId -Index $index

            $lines.Add("    - resource: Microsoft.WinGet.DSC/WinGetPackage")
            $lines.Add("      id: $resourceId")
            $lines.Add("      directives:")
            $lines.Add("        description: $(ConvertTo-WingetterYamlSingleQuotedValue -Value "Install $name")")
            $lines.Add("      settings:")
            $lines.Add("        id: $(ConvertTo-WingetterYamlSingleQuotedValue -Value $packageId)")
            $lines.Add("        source: $(ConvertTo-WingetterYamlSingleQuotedValue -Value $sourceName)")
            if ($installOptions.PSObject.Properties["Version"]) {
                $lines.Add("        version: $(ConvertTo-WingetterYamlSingleQuotedValue -Value ([string]$installOptions.Version))")
            }
        }
    }

    $lines.Add("  configurationVersion: $ConfigurationVersion")
    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

function Export-WingetterConfigurationFile {
    param(
        [object[]]$PackageEntries,
        [string]$FilePath
    )

    $yaml = ConvertTo-WingetterConfigurationYaml -PackageEntries $PackageEntries
    Set-WingetterFileAtomic -Path $FilePath -Content $yaml -Encoding UTF8 -NoBom
    return $FilePath
}
