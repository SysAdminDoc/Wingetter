# ============================================================================
# SOFTWARE CATALOG - catalog/winget.json is the canonical source of truth.
# ============================================================================

$f = "https://www.google.com/s2/favicons?sz=32&domain="

function ConvertFrom-WingetterCatalogJsonText {
    param(
        [string]$Json,
        [string]$SourceLabel = "catalog/winget.json"
    )

    if ([string]::IsNullOrWhiteSpace($Json)) { return $null }

    try {
        $catalog = $Json | ConvertFrom-Json
        if ($catalog.schemaVersion -ne 1 -or !$catalog.categories) { return $null }

        $database = [ordered]@{}
        foreach ($category in @($catalog.categories)) {
            $apps = @()
            foreach ($app in @($category.apps)) {
                $domain = [string]$app.iconDomain
                if (![string]::IsNullOrWhiteSpace($domain) -and $domain -match '[/\\?#&=%;:@\s<>"'']') { $domain = "" }
                $icon = if ($app.iconUrl) { [string]$app.iconUrl } elseif ($domain) { "${f}$domain" } else { "" }
                $entry = @{
                    Name     = [string]$app.name
                    WingetId = [string]$app.wingetId
                    Icon     = $icon
                }
                foreach ($sourceProperty in @("source", "sourceName", "sourceType", "sourceTrustLevel")) {
                    $prop = $app.PSObject.Properties[$sourceProperty]
                    if ($prop -and ![string]::IsNullOrWhiteSpace([string]$prop.Value)) {
                        switch ($sourceProperty) {
                            "source" { $entry["Source"] = [string]$prop.Value }
                            "sourceName" { $entry["Source"] = [string]$prop.Value }
                            "sourceType" { $entry["SourceType"] = [string]$prop.Value }
                            "sourceTrustLevel" { $entry["SourceTrustLevel"] = [string]$prop.Value }
                        }
                    }
                }
                $apps += $entry
            }
            if ($apps.Count -gt 0) {
                $database[[string]$category.name] = $apps
            }
        }

        if ($database.Keys.Count -gt 0) { return $database }
    } catch {
        Write-Warning "Could not load catalog from '$SourceLabel': $($_.Exception.Message)."
    }

    return $null
}

function ConvertFrom-WingetterCatalogJson {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path)) { return $null }
    try {
        $json = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path)
        return ConvertFrom-WingetterCatalogJsonText -Json $json -SourceLabel $Path
    } catch {
        Write-Warning "Could not read catalog from '$Path': $($_.Exception.Message)."
        return $null
    }
}

function Get-WingetterEmbeddedCatalogJson {
    $variable = Get-Variable -Name WingetterEmbeddedCatalogJsonBase64 -ErrorAction SilentlyContinue
    if ($null -eq $variable -or [string]::IsNullOrWhiteSpace([string]$variable.Value)) { return "" }

    try {
        $bytes = [Convert]::FromBase64String([string]$variable.Value)
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    } catch {
        Write-Warning "Could not decode the packaged Wingetter catalog snapshot: $($_.Exception.Message)."
        return ""
    }
}

function ConvertFrom-WingetterGroupsJson {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path)) { return $null }

    try {
        $groupsJson = Get-Content -Path $Path -Raw | ConvertFrom-Json
        if ($groupsJson.schemaVersion -ne 1 -or !$groupsJson.groups) { return $null }

        $groups = [ordered]@{}
        foreach ($group in @($groupsJson.groups)) {
            $packageIds = @()
            foreach ($packageId in @($group.packageIds)) {
                $packageIds += [string]$packageId
            }
            if ($packageIds.Count -gt 0) {
                $groups[[string]$group.name] = $packageIds
            }
        }

        if ($groups.Keys.Count -gt 0) { return $groups }
    } catch {
        Write-Warning "Could not load built-in groups from '$Path': $($_.Exception.Message). Using embedded groups."
    }

    return $null
}

function ConvertTo-WingetterSearchText {
    param([string[]]$Values)

    $joined = (@($Values) | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) }) -join " "
    return (($joined.ToLowerInvariant() -replace '[^a-z0-9]+', ' ') -replace '\s+', ' ').Trim()
}

function Get-WingetterSearchScore {
    param(
        [string]$Query,
        [string]$Name,
        [string]$WingetId,
        [string]$Category = "",
        [string[]]$Groups = @(),
        [string]$Source = "",
        [string]$Scope = "",
        [bool]$IsInstalled = $false,
        [bool]$IsPinned = $false,
        [bool]$IsUpdateAvailable = $false
    )

    if ([string]::IsNullOrWhiteSpace($Query)) { return 1 }

    $tokens = @((ConvertTo-WingetterSearchText -Values @($Query)) -split '\s+' | Where-Object { $_ })
    if ($tokens.Count -eq 0) { return 1 }

    $publisher = ""
    if ($WingetId -match '^(?<publisher>[^.]+)\.') { $publisher = $matches.publisher }
    $stateTerms = @()
    if ($IsInstalled) { $stateTerms += "installed" }
    if ($IsPinned) { $stateTerms += "pinned pin" }
    if ($IsUpdateAvailable) { $stateTerms += "update available upgrade" }

    $nameText = ConvertTo-WingetterSearchText -Values @($Name)
    $idText = ConvertTo-WingetterSearchText -Values @($WingetId, ($WingetId -replace '[.\-_]', ' '))
    $categoryText = ConvertTo-WingetterSearchText -Values @($Category)
    $groupText = ConvertTo-WingetterSearchText -Values $Groups
    $publisherText = ConvertTo-WingetterSearchText -Values @($publisher)
    $stateText = ConvertTo-WingetterSearchText -Values @($Source, $Scope, $stateTerms)
    $allText = ConvertTo-WingetterSearchText -Values @($nameText, $idText, $categoryText, $groupText, $publisherText, $stateText)

    $score = 0
    foreach ($token in $tokens) {
        if (!$allText.Contains($token)) { return 0 }
        if ($nameText -eq $token) { $score += 90; continue }
        if ($nameText.StartsWith($token)) { $score += 70; continue }
        if ($nameText.Contains($token)) { $score += 50; continue }
        if ($idText.Contains($token)) { $score += 42; continue }
        if ($publisherText.Contains($token)) { $score += 34; continue }
        if ($categoryText.Contains($token)) { $score += 28; continue }
        if ($groupText.Contains($token)) { $score += 24; continue }
        if ($stateText.Contains($token)) { $score += 16; continue }
        $score += 5
    }

    return $score
}

$catalog = $null
$wingetterRoot = Get-WingetterRootPath
if (![string]::IsNullOrWhiteSpace($wingetterRoot)) {
    $catalogPath = Join-Path $wingetterRoot "catalog\winget.json"
    $catalog = ConvertFrom-WingetterCatalogJson -Path $catalogPath
}
if ($null -eq $catalog) {
    $catalog = ConvertFrom-WingetterCatalogJsonText -Json (Get-WingetterEmbeddedCatalogJson) -SourceLabel "packaged catalog snapshot"
}
if ($null -eq $catalog) {
    throw "Could not load the canonical Wingetter catalog from catalog/winget.json or the packaged snapshot."
}
$Script:SoftwareDatabase = $catalog
