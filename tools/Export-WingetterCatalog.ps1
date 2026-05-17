param(
    [string]$ScriptPath = (Join-Path $PSScriptRoot "..\Wingetter.ps1"),
    [string]$CatalogPath = (Join-Path $PSScriptRoot "..\catalog\winget.json"),
    [string]$GroupsPath = (Join-Path $PSScriptRoot "..\catalog\groups.json"),
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoRelativePath {
    param([string]$Path)
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $resolved = [System.IO.Path]::GetFullPath($Path)
    if ($resolved.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $resolved.Substring($repoRoot.Length).TrimStart("\", "/") -replace "\\", "/"
    }
    return $resolved
}

function ConvertTo-CanonicalJson {
    param([object]$InputObject)
    return ($InputObject | ConvertTo-Json -Depth 20)
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Value
    )
    $directory = Split-Path -Parent $Path
    if ($directory -and !(Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, ($Value.TrimEnd() + [Environment]::NewLine), $encoding)
}

function Get-Section {
    param(
        [string]$Text,
        [string]$StartMarker,
        [string]$EndMarker
    )
    $start = $Text.IndexOf($StartMarker, [System.StringComparison]::Ordinal)
    if ($start -lt 0) {
        throw "Could not find section start marker: $StartMarker"
    }
    $end = $Text.IndexOf($EndMarker, $start, [System.StringComparison]::Ordinal)
    if ($end -lt 0) {
        throw "Could not find section end marker: $EndMarker"
    }
    return $Text.Substring($start, $end - $start)
}

function Get-ScriptVersions {
    param([string]$Text)
    $versions = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in @(
        '\$ver\.Text\s*=\s*"(?<version>v\d+\.\d+\.\d+)"',
        'Title="Wingetter (?<version>v\d+\.\d+\.\d+)',
        'HeaderVersion" Text="(?<version>v\d+\.\d+\.\d+)"'
    )) {
        foreach ($match in [regex]::Matches($Text, $pattern)) {
            $versions.Add($match.Groups["version"].Value)
        }
    }
    $uniqueVersions = @($versions | Select-Object -Unique)
    if ($uniqueVersions.Count -ne 1) {
        throw "Expected one script version, found: $($uniqueVersions -join ', ')"
    }
    return $uniqueVersions[0]
}

function Convert-AppMatch {
    param([System.Text.RegularExpressions.Match]$Match)
    $domain = $Match.Groups["domain"].Value.Trim()
    [ordered]@{
        name       = $Match.Groups["name"].Value.Trim()
        wingetId   = $Match.Groups["id"].Value.Trim()
        iconDomain = $domain
        iconUrl    = "https://www.google.com/s2/favicons?sz=32&domain=$domain"
    }
}

function Export-CatalogObject {
    param(
        [string]$Text,
        [string]$Version
    )

    $databaseSection = Get-Section `
        -Text $Text `
        -StartMarker '$Script:SoftwareDatabase = [ordered]@{' `
        -EndMarker '# WINGET DETECTION AND INSTALLATION'

    $categoryPattern = '(?ms)^\s*"(?<category>[^"]+)"\s*=\s*@\((?<body>.*?)^\s*\)\s*(?=^\s*"[^"]+"\s*=\s*@\(|^\s*\}\s*$)'
    $appPattern = '@\{\s*Name\s*=\s*"(?<name>[^"]+)";\s*WingetId\s*=\s*"(?<id>[^"]+)";\s*Icon\s*=\s*"\$\{f\}(?<domain>[^"]+)"\s*\}'

    $categories = New-Object System.Collections.ArrayList
    foreach ($categoryMatch in [regex]::Matches($databaseSection, $categoryPattern)) {
        $apps = New-Object System.Collections.ArrayList
        foreach ($appMatch in [regex]::Matches($categoryMatch.Groups["body"].Value, $appPattern)) {
            [void]$apps.Add((Convert-AppMatch -Match $appMatch))
        }
        if ($apps.Count -eq 0) {
            throw "Category '$($categoryMatch.Groups["category"].Value)' did not produce any apps."
        }
        [void]$categories.Add([ordered]@{
            name  = $categoryMatch.Groups["category"].Value
            count = $apps.Count
            apps  = @($apps)
        })
    }

    if ($categories.Count -eq 0) {
        throw "No catalog categories were parsed from $ScriptPath."
    }

    $appCount = 0
    foreach ($category in $categories) {
        $appCount += [int]$category.count
    }

    return [ordered]@{
        schemaVersion = 1
        version       = $Version
        sourceFile    = Get-RepoRelativePath -Path $ScriptPath
        appCount      = $appCount
        categoryCount = $categories.Count
        categories    = @($categories)
    }
}

function Export-GroupsObject {
    param(
        [string]$Text,
        [string]$Version
    )

    $groupsSection = Get-Section `
        -Text $Text `
        -StartMarker '$Script:BuiltInGroups = [ordered]@{' `
        -EndMarker '# THEME DEFINITIONS'

    $groupPattern = '(?ms)^\s*"(?<group>[^"]+)"\s*=\s*@\((?<body>.*?)^\s*\)'
    $idPattern = '"(?<id>[^"]+)"'

    $groups = New-Object System.Collections.ArrayList
    foreach ($groupMatch in [regex]::Matches($groupsSection, $groupPattern)) {
        $packageIds = New-Object System.Collections.Generic.List[string]
        foreach ($idMatch in [regex]::Matches($groupMatch.Groups["body"].Value, $idPattern)) {
            $packageIds.Add($idMatch.Groups["id"].Value)
        }
        if ($packageIds.Count -eq 0) {
            throw "Built-in group '$($groupMatch.Groups["group"].Value)' did not produce any package IDs."
        }
        [void]$groups.Add([ordered]@{
            name       = $groupMatch.Groups["group"].Value
            appCount   = $packageIds.Count
            packageIds = @($packageIds)
        })
    }

    if ($groups.Count -eq 0) {
        throw "No built-in groups were parsed from $ScriptPath."
    }

    return [ordered]@{
        schemaVersion = 1
        version       = $Version
        sourceFile    = Get-RepoRelativePath -Path $ScriptPath
        groupCount    = $groups.Count
        groups        = @($groups)
    }
}

$resolvedScriptPath = (Resolve-Path $ScriptPath).Path
$scriptText = [System.IO.File]::ReadAllText($resolvedScriptPath)
$version = Get-ScriptVersions -Text $scriptText
$catalogObject = Export-CatalogObject -Text $scriptText -Version $version
$groupsObject = Export-GroupsObject -Text $scriptText -Version $version

$catalogJson = ConvertTo-CanonicalJson -InputObject $catalogObject
$groupsJson = ConvertTo-CanonicalJson -InputObject $groupsObject

if ($Check) {
    $failed = $false
    foreach ($target in @(
        @{ Path = $CatalogPath; Expected = $catalogJson; Name = "catalog" },
        @{ Path = $GroupsPath; Expected = $groupsJson; Name = "groups" }
    )) {
        if (!(Test-Path $target.Path)) {
            Write-Error "Missing generated $($target.Name) file: $($target.Path)"
            $failed = $true
            continue
        }
        $actual = [System.IO.File]::ReadAllText((Resolve-Path $target.Path).Path).Trim()
        if ($actual -ne $target.Expected.Trim()) {
            Write-Error "Generated $($target.Name) file is stale: $($target.Path). Run tools/Export-WingetterCatalog.ps1."
            $failed = $true
        }
    }
    if ($failed) {
        exit 1
    }
    Write-Host "Catalog and group snapshots are current for $version ($($catalogObject.appCount) apps, $($catalogObject.categoryCount) categories)."
    exit 0
}

Write-Utf8NoBom -Path $CatalogPath -Value $catalogJson
Write-Utf8NoBom -Path $GroupsPath -Value $groupsJson
Write-Host "Wrote $CatalogPath and $GroupsPath for $version ($($catalogObject.appCount) apps, $($catalogObject.categoryCount) categories)."
