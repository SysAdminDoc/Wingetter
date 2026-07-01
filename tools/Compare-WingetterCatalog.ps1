param(
    [string]$CatalogPath = (Join-Path $PSScriptRoot "..\catalog\winget.json"),
    [string]$GroupsPath = (Join-Path $PSScriptRoot "..\catalog\groups.json"),
    [string]$GalleryPath = (Join-Path $PSScriptRoot "..\profiles\gallery.json"),
    [string]$BaselineRef = "HEAD"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-BaselineContent {
    param([string]$RelativePath, [string]$Ref)
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $gitPath = ($RelativePath -replace '\\', '/')
    try {
        $content = git -C $repoRoot show "${Ref}:${gitPath}" 2>$null
        if ($LASTEXITCODE -eq 0 -and $content) { return ($content -join "`n") }
    } catch {}
    return $null
}

function Get-CatalogIndex {
    param([object]$Catalog)
    $index = [ordered]@{}
    foreach ($cat in @($Catalog.categories)) {
        foreach ($app in @($cat.apps)) {
            $index[[string]$app.wingetId] = [PSCustomObject]@{
                Name       = [string]$app.name
                WingetId   = [string]$app.wingetId
                Category   = [string]$cat.name
                IconDomain = if ($app.PSObject.Properties["iconDomain"]) { [string]$app.iconDomain } else { "" }
            }
        }
    }
    return $index
}

function Get-GalleryPackageIds {
    param([object]$Gallery)
    $ids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    foreach ($profile in @($Gallery.Profiles)) {
        $profilePath = Join-Path $repoRoot $profile.ProfilePath
        if (Test-Path -LiteralPath $profilePath) {
            try {
                $profileData = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
                $packages = if ($profileData.PSObject.Properties["Packages"]) { $profileData.Packages } elseif ($profileData.PSObject.Properties["PackageIds"]) { $profileData.PackageIds } else { @() }
                foreach ($pkg in @($packages)) {
                    $id = if ($pkg -is [string]) { $pkg } elseif ($pkg.PSObject.Properties["PackageIdentifier"]) { [string]$pkg.PackageIdentifier } else { "" }
                    if (![string]::IsNullOrWhiteSpace($id)) { [void]$ids.Add($id) }
                }
            } catch {}
        }
    }
    return $ids
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$catalogRelative = [System.IO.Path]::GetFullPath($CatalogPath).Substring($repoRoot.Length).TrimStart("\", "/")
$groupsRelative = [System.IO.Path]::GetFullPath($GroupsPath).Substring($repoRoot.Length).TrimStart("\", "/")
$galleryRelative = [System.IO.Path]::GetFullPath($GalleryPath).Substring($repoRoot.Length).TrimStart("\", "/")

$currentCatalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json
$currentIndex = Get-CatalogIndex -Catalog $currentCatalog

$baselineCatalogText = Get-BaselineContent -RelativePath $catalogRelative -Ref $BaselineRef
if ($null -eq $baselineCatalogText) {
    Write-Host "No baseline catalog found at $BaselineRef. Reporting current catalog as all-new."
    $baselineIndex = [ordered]@{}
} else {
    $baselineCatalog = $baselineCatalogText | ConvertFrom-Json
    $baselineIndex = Get-CatalogIndex -Catalog $baselineCatalog
}

$galleryIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if (Test-Path -LiteralPath $GalleryPath) {
    $gallery = Get-Content -LiteralPath $GalleryPath -Raw | ConvertFrom-Json
    $galleryIds = Get-GalleryPackageIds -Gallery $gallery
}

$added = [System.Collections.ArrayList]::new()
$removed = [System.Collections.ArrayList]::new()
$categoryMoved = [System.Collections.ArrayList]::new()
$renamed = [System.Collections.ArrayList]::new()

foreach ($id in @($currentIndex.Keys)) {
    if (-not $baselineIndex.Contains($id)) {
        $profileRefs = $galleryIds.Contains($id)
        [void]$added.Add([PSCustomObject][ordered]@{
            PackageId       = $id
            Name            = $currentIndex[$id].Name
            Category        = $currentIndex[$id].Category
            ProfileReferenced = $profileRefs
        })
    } else {
        $cur = $currentIndex[$id]
        $base = $baselineIndex[$id]
        if ($cur.Category -ne $base.Category) {
            [void]$categoryMoved.Add([PSCustomObject][ordered]@{
                PackageId    = $id
                Name         = $cur.Name
                FromCategory = $base.Category
                ToCategory   = $cur.Category
            })
        }
        if ($cur.Name -ne $base.Name) {
            [void]$renamed.Add([PSCustomObject][ordered]@{
                PackageId = $id
                FromName  = $base.Name
                ToName    = $cur.Name
            })
        }
    }
}

foreach ($id in @($baselineIndex.Keys)) {
    if (-not $currentIndex.Contains($id)) {
        $profileRefs = $galleryIds.Contains($id)
        [void]$removed.Add([PSCustomObject][ordered]@{
            PackageId       = $id
            Name            = $baselineIndex[$id].Name
            Category        = $baselineIndex[$id].Category
            ProfileReferenced = $profileRefs
        })
    }
}

$currentAppCount = $currentIndex.Count
$baselineAppCount = $baselineIndex.Count
$currentCatCount = @($currentCatalog.categories).Count
$baselineCatCount = if ($baselineCatalogText) { @(($baselineCatalogText | ConvertFrom-Json).categories).Count } else { 0 }

$report = [PSCustomObject][ordered]@{
    Schema          = "Wingetter.CatalogDiff.v1"
    BaselineRef     = $BaselineRef
    CurrentAppCount = $currentAppCount
    BaselineAppCount = $baselineAppCount
    CurrentCategoryCount = $currentCatCount
    BaselineCategoryCount = $baselineCatCount
    Added           = [object[]]$added.ToArray()
    Removed         = [object[]]$removed.ToArray()
    CategoryMoved   = [object[]]$categoryMoved.ToArray()
    Renamed         = [object[]]$renamed.ToArray()
    AddedCount      = $added.Count
    RemovedCount    = $removed.Count
    CategoryMovedCount = $categoryMoved.Count
    RenamedCount    = $renamed.Count
}

$hasChanges = ($added.Count + $removed.Count + $categoryMoved.Count + $renamed.Count) -gt 0

if ($hasChanges) {
    Write-Host "Catalog diff against $BaselineRef :" -ForegroundColor Cyan
    Write-Host "  Apps: $baselineAppCount -> $currentAppCount ($(if ($currentAppCount -ge $baselineAppCount) { '+' })$($currentAppCount - $baselineAppCount))"
    Write-Host "  Categories: $baselineCatCount -> $currentCatCount"
    if ($added.Count -gt 0) {
        Write-Host "`n  Added ($($added.Count)):" -ForegroundColor Green
        foreach ($a in $added) {
            $refTag = if ($a.ProfileReferenced) { " [gallery-referenced]" } else { "" }
            Write-Host "    + $($a.PackageId) ($($a.Category))$refTag"
        }
    }
    if ($removed.Count -gt 0) {
        Write-Host "`n  Removed ($($removed.Count)):" -ForegroundColor Red
        foreach ($r in $removed) {
            $refTag = if ($r.ProfileReferenced) { " [gallery-referenced - BREAKING]" } else { "" }
            Write-Host "    - $($r.PackageId) ($($r.Category))$refTag" -ForegroundColor $(if ($r.ProfileReferenced) { "Red" } else { "Yellow" })
        }
    }
    if ($categoryMoved.Count -gt 0) {
        Write-Host "`n  Category moved ($($categoryMoved.Count)):" -ForegroundColor Yellow
        foreach ($m in $categoryMoved) { Write-Host "    ~ $($m.PackageId): $($m.FromCategory) -> $($m.ToCategory)" }
    }
    if ($renamed.Count -gt 0) {
        Write-Host "`n  Renamed ($($renamed.Count)):" -ForegroundColor Yellow
        foreach ($r in $renamed) { Write-Host "    ~ $($r.PackageId): '$($r.FromName)' -> '$($r.ToName)'" }
    }
} else {
    Write-Host "No catalog changes detected against $BaselineRef." -ForegroundColor Green
}

$report | ConvertTo-Json -Depth 8
