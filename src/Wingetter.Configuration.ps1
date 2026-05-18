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
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = "package_$Index" }
    if ($safe -notmatch '^[A-Za-z_]') { $safe = "package_$safe" }
    return $safe
}

function New-WingetterConfigurationPackageEntry {
    param(
        [string]$Name,
        [string]$PackageId,
        [string]$SourceName = "winget"
    )

    [PSCustomObject]@{
        Name       = $Name
        WingetId   = $PackageId
        SourceName = if ([string]::IsNullOrWhiteSpace($SourceName)) { "winget" } else { $SourceName }
    }
}

function ConvertTo-WingetterConfigurationYaml {
    param(
        [object[]]$PackageEntries,
        [string]$ConfigurationVersion = "0.2.0"
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# yaml-language-server: `$schema=https://aka.ms/configuration-dsc-schema/0.2")
    $lines.Add("properties:")
    $lines.Add("  resources:")

    $index = 0
    foreach ($package in @($PackageEntries)) {
        $index++
        $packageId = [string]$package.WingetId
        if ([string]::IsNullOrWhiteSpace($packageId)) { continue }
        if (-not (Test-WingetterConfigurationPackageId -PackageId $packageId)) {
            throw "Package identifier '$packageId' contains characters that are not valid in a WinGet Configuration file."
        }
        $name = if (![string]::IsNullOrWhiteSpace([string]$package.Name)) { [string]$package.Name } else { $packageId }
        $sourceName = if (![string]::IsNullOrWhiteSpace([string]$package.SourceName)) { [string]$package.SourceName } else { "winget" }
        $resourceId = ConvertTo-WingetterConfigurationResourceId -PackageId $packageId -Index $index

        $lines.Add("    - resource: Microsoft.WinGet.DSC/WinGetPackage")
        $lines.Add("      id: $resourceId")
        $lines.Add("      directives:")
        $lines.Add("        description: $(ConvertTo-WingetterYamlSingleQuotedValue -Value "Install $name")")
        $lines.Add("      settings:")
        $lines.Add("        id: $(ConvertTo-WingetterYamlSingleQuotedValue -Value $packageId)")
        $lines.Add("        source: $(ConvertTo-WingetterYamlSingleQuotedValue -Value $sourceName)")
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
    $parent = Split-Path -Parent $FilePath
    if (![string]::IsNullOrWhiteSpace($parent) -and !(Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -Path $FilePath -Value $yaml -Encoding UTF8
    return $FilePath
}
