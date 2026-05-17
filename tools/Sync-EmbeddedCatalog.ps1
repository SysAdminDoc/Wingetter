param(
    [string]$CatalogModulePath = (Join-Path $PSScriptRoot "..\src\Wingetter.Catalog.ps1"),
    [string]$GroupsModulePath = (Join-Path $PSScriptRoot "..\src\Wingetter.Groups.ps1"),
    [string]$CatalogPath = (Join-Path $PSScriptRoot "..\catalog\winget.json"),
    [string]$GroupsPath = (Join-Path $PSScriptRoot "..\catalog\groups.json"),
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-JsonFile {
    param([string]$Path)
    if (!(Test-Path $Path)) {
        throw "Missing JSON file: $Path"
    }
    return (Get-Content -Path $Path -Raw | ConvertFrom-Json)
}

function ConvertTo-DoubleQuotedLiteral {
    param([string]$Value)
    return '"' + (($Value -replace '`', '``') -replace '"', '`"') + '"'
}

function Get-IconDomain {
    param([object]$App)
    if ($App.iconDomain) {
        return [string]$App.iconDomain
    }
    if ($App.iconUrl -match '[?&]domain=(?<domain>[^&]+)') {
        return [System.Uri]::UnescapeDataString($matches.domain)
    }
    throw "App '$($App.name)' is missing iconDomain and a parseable iconUrl."
}

function New-CatalogBlock {
    param([object]$Catalog)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('$Script:SoftwareDatabase = [ordered]@{')
    $lines.Add('')

    foreach ($category in @($Catalog.categories)) {
        $lines.Add("    $(ConvertTo-DoubleQuotedLiteral ([string]$category.name)) = @(")
        foreach ($app in @($category.apps)) {
            $domain = Get-IconDomain -App $app
            $line = '        @{ Name = ' +
                (ConvertTo-DoubleQuotedLiteral ([string]$app.name)) +
                '; WingetId = ' +
                (ConvertTo-DoubleQuotedLiteral ([string]$app.wingetId)) +
                '; Icon = "' + '${f}' + $domain + '" }'
            $lines.Add($line)
        }
        $lines.Add('    )')
        $lines.Add('')
    }

    if ($lines[$lines.Count - 1] -eq '') {
        $lines.RemoveAt($lines.Count - 1)
    }
    $lines.Add('}')

    return ($lines -join [Environment]::NewLine)
}

function New-GroupsBlock {
    param([object]$Groups)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('$Script:BuiltInGroups = [ordered]@{')

    foreach ($group in @($Groups.groups)) {
        $lines.Add("    $(ConvertTo-DoubleQuotedLiteral ([string]$group.name)) = @(")
        $packageIds = @($group.packageIds | ForEach-Object { ConvertTo-DoubleQuotedLiteral ([string]$_) })
        for ($i = 0; $i -lt $packageIds.Count; $i += 5) {
            $end = [Math]::Min($i + 4, $packageIds.Count - 1)
            $chunk = @($packageIds[$i..$end])
            $suffix = if ($end -lt ($packageIds.Count - 1)) { "," } else { "" }
            $lines.Add("        $($chunk -join ',')$suffix")
        }
        $lines.Add('    )')
    }

    $lines.Add('}')
    return ($lines -join [Environment]::NewLine)
}

function Replace-SingleBlock {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Replacement,
        [string]$Name,
        [string]$Path
    )

    $match = [regex]::Match($Text, $Pattern)
    if (!$match.Success) {
        throw "Could not find embedded $Name block in $Path."
    }

    return $Text.Substring(0, $match.Index) + $Replacement.TrimEnd() + [Environment]::NewLine + $Text.Substring($match.Index + $match.Length)
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Value
    )
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Value, $encoding)
}

function ConvertTo-NormalizedText {
    param([string]$Value)
    return (($Value -replace "`r`n", "`n") -replace "`r", "`n")
}

$catalog = Read-JsonFile -Path $CatalogPath
$groups = Read-JsonFile -Path $GroupsPath
$resolvedCatalogModulePath = (Resolve-Path $CatalogModulePath).Path
$resolvedGroupsModulePath = (Resolve-Path $GroupsModulePath).Path
$catalogText = [System.IO.File]::ReadAllText($resolvedCatalogModulePath)
$groupsText = [System.IO.File]::ReadAllText($resolvedGroupsModulePath)

$catalogBlock = New-CatalogBlock -Catalog $catalog
$groupsBlock = New-GroupsBlock -Groups $groups

$databasePattern = '(?ms)^\$Script:SoftwareDatabase = \[ordered\]@\{.*?^\}\s*(?=^\$wingetterRoot = Get-WingetterRootPath)'
$groupsPattern = '(?ms)^\$Script:BuiltInGroups = \[ordered\]@\{.*?^\}\s*(?=^\$wingetterRoot = Get-WingetterRootPath)'

$updatedCatalogText = Replace-SingleBlock -Text $catalogText -Pattern $databasePattern -Replacement $catalogBlock -Name "catalog" -Path $resolvedCatalogModulePath
$updatedGroupsText = Replace-SingleBlock -Text $groupsText -Pattern $groupsPattern -Replacement $groupsBlock -Name "groups" -Path $resolvedGroupsModulePath

if ($Check) {
    $failed = $false
    if ((ConvertTo-NormalizedText $updatedCatalogText) -ne (ConvertTo-NormalizedText $catalogText)) {
        Write-Host "Embedded catalog fallback is stale. Run tools/Sync-EmbeddedCatalog.ps1." -ForegroundColor Red
        $failed = $true
    }
    if ((ConvertTo-NormalizedText $updatedGroupsText) -ne (ConvertTo-NormalizedText $groupsText)) {
        Write-Host "Embedded groups fallback is stale. Run tools/Sync-EmbeddedCatalog.ps1." -ForegroundColor Red
        $failed = $true
    }
    if ($failed) { exit 1 }
    Write-Host "Embedded catalog and groups fallbacks are current for $($catalog.version)."
    exit 0
}

Write-Utf8NoBom -Path $resolvedCatalogModulePath -Value $updatedCatalogText
Write-Utf8NoBom -Path $resolvedGroupsModulePath -Value $updatedGroupsText
Write-Host "Updated embedded catalog fallback in $resolvedCatalogModulePath and group fallback in $resolvedGroupsModulePath."
