param(
    [string]$ScriptPath = (Join-Path $PSScriptRoot "..\Wingetter.ps1"),
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
        [string]$Name
    )

    $match = [regex]::Match($Text, $Pattern)
    if (!$match.Success) {
        throw "Could not find embedded $Name block in $ScriptPath."
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

$catalog = Read-JsonFile -Path $CatalogPath
$groups = Read-JsonFile -Path $GroupsPath
$resolvedScriptPath = (Resolve-Path $ScriptPath).Path
$scriptText = [System.IO.File]::ReadAllText($resolvedScriptPath)

$catalogBlock = New-CatalogBlock -Catalog $catalog
$groupsBlock = New-GroupsBlock -Groups $groups

$databasePattern = '(?ms)^\$Script:SoftwareDatabase = \[ordered\]@\{.*?^\}\s*(?=^if \(!\[string\]::IsNullOrWhiteSpace\(\$PSScriptRoot\)\) \{\r?\n\s+\$catalogPath)'
$groupsPattern = '(?ms)^\$Script:BuiltInGroups = \[ordered\]@\{.*?^\}\s*(?=^if \(!\[string\]::IsNullOrWhiteSpace\(\$PSScriptRoot\)\) \{\r?\n\s+\$groupsPath)'

$updatedText = Replace-SingleBlock -Text $scriptText -Pattern $databasePattern -Replacement $catalogBlock -Name "catalog"
$updatedText = Replace-SingleBlock -Text $updatedText -Pattern $groupsPattern -Replacement $groupsBlock -Name "groups"

if ($Check) {
    if ($updatedText -ne $scriptText) {
        Write-Error "Embedded catalog fallback is stale. Run tools/Sync-EmbeddedCatalog.ps1."
        exit 1
    }
    Write-Host "Embedded catalog fallback is current for $($catalog.version)."
    exit 0
}

Write-Utf8NoBom -Path $resolvedScriptPath -Value $updatedText
Write-Host "Updated embedded catalog fallback in $resolvedScriptPath from $CatalogPath and $GroupsPath."
