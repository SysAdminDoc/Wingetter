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

$groupsBlock = New-GroupsBlock -Groups $groups

$groupsPattern = '(?ms)^\$Script:BuiltInGroups = \[ordered\]@\{.*?^\}\s*(?=^\$wingetterRoot = Get-WingetterRootPath)'

$updatedGroupsText = Replace-SingleBlock -Text $groupsText -Pattern $groupsPattern -Replacement $groupsBlock -Name "groups" -Path $resolvedGroupsModulePath
$catalogUsesCanonicalSource = $catalogText -match 'catalog/winget\.json' -and $catalogText -match 'Get-WingetterEmbeddedCatalogJson' -and $catalogText -notmatch '\$Script:SoftwareDatabase\s*=\s*\[ordered\]@\{'

if ($Check) {
    $failed = $false
    if (!$catalogUsesCanonicalSource) {
        Write-Host "Catalog module does not use catalog/winget.json as its canonical source." -ForegroundColor Red
        $failed = $true
    }
    if ((ConvertTo-NormalizedText $updatedGroupsText) -ne (ConvertTo-NormalizedText $groupsText)) {
        Write-Host "Embedded groups fallback is stale. Run tools/Sync-EmbeddedCatalog.ps1." -ForegroundColor Red
        $failed = $true
    }
    if ($failed) { exit 1 }
    Write-Host "Canonical catalog loader and embedded group fallback are current for $($catalog.version)."
    exit 0
}

Write-Utf8NoBom -Path $resolvedGroupsModulePath -Value $updatedGroupsText
Write-Host "Catalog loads from catalog/winget.json; updated embedded group fallback in $resolvedGroupsModulePath."
