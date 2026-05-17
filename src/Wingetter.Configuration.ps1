# ============================================================================
# WINGET CONFIGURATION EXPORT
# ============================================================================

function ConvertTo-WingetterYamlSingleQuotedValue {
    param([string]$Value)
    if ($null -eq $Value) { return "''" }
    "'" + ([string]$Value -replace "'", "''") + "'"
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
