param(
    [string]$ScriptPath = (Join-Path $PSScriptRoot "..\Wingetter.ps1"),
    [string]$CatalogPath = (Join-Path $PSScriptRoot "..\catalog\winget.json"),
    [string]$GroupsPath = (Join-Path $PSScriptRoot "..\catalog\groups.json"),
    [string]$ReadmePath = (Join-Path $PSScriptRoot "..\README.md"),
    [string]$ChangelogPath = (Join-Path $PSScriptRoot "..\CHANGELOG.md"),
    [switch]$CheckWingetAvailability,
    [int]$AvailabilitySampleSize = 25
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
}

function Read-JsonFile {
    param([string]$Path)
    if (!(Test-Path $Path)) {
        throw "Missing JSON file: $Path"
    }
    return (Get-Content -Path $Path -Raw | ConvertFrom-Json)
}

function Get-ScriptVersion {
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
    return @($versions | Select-Object -Unique)
}

function Get-ReadmeCategoryCounts {
    param([string]$Readme)
    $counts = @{}
    $section = [regex]::Match($Readme, '(?ms)^## Categories\s*(?<body>.*?)(?=^## |\z)')
    if (!$section.Success) {
        Add-Failure "README.md is missing the Categories section."
        return $counts
    }

    $rowPattern = '^\|\s*(?<left>[^|]+?)\s*\|\s*(?<leftCount>\d+)\s*\|\s*\|\s*(?<right>[^|]*?)\s*\|\s*(?<rightCount>\d*)\s*\|'
    foreach ($match in [regex]::Matches($section.Groups["body"].Value, $rowPattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)) {
        $left = $match.Groups["left"].Value.Trim()
        if ($left -and $left -ne "Category") {
            $counts[$left] = [int]$match.Groups["leftCount"].Value
        }
        $right = $match.Groups["right"].Value.Trim()
        $rightCount = $match.Groups["rightCount"].Value.Trim()
        if ($right -and $right -ne "Category" -and $rightCount) {
            $counts[$right] = [int]$rightCount
        }
    }
    return $counts
}

function Get-ReadmeGroupNames {
    param([string]$Readme)
    $names = New-Object System.Collections.Generic.List[string]
    $section = [regex]::Match($Readme, '(?ms)^## Built-in Groups\s*(?<body>.*?)(?=^## Categories)')
    if (!$section.Success) {
        Add-Failure "README.md is missing the Built-in Groups section."
        return @()
    }

    foreach ($match in [regex]::Matches($section.Groups["body"].Value, '^\|\s*(?<name>[^|]+?)\s*\|', [System.Text.RegularExpressions.RegexOptions]::Multiline)) {
        $name = $match.Groups["name"].Value.Trim()
        if ($name -and $name -ne "Group" -and $name -notmatch '^-+$') {
            $names.Add($name)
        }
    }
    return @($names)
}

function Assert-PackageAvailability {
    param(
        [object[]]$Apps,
        [int]$SampleSize
    )
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (!$winget) {
        Add-Failure "winget availability sampling was requested, but winget is not on PATH."
        return
    }

    foreach ($app in ($Apps | Select-Object -First $SampleSize)) {
        $stdoutPath = [System.IO.Path]::GetTempFileName()
        $stderrPath = [System.IO.Path]::GetTempFileName()
        try {
            $process = Start-Process -FilePath $winget.Source -ArgumentList @("show", "--id", $app.wingetId, "--exact", "--disable-interactivity") -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
            if ($process.ExitCode -ne 0) {
                $stderr = if (Test-Path $stderrPath) { (Get-Content -Path $stderrPath -Raw).Trim() } else { "" }
                if ($stderr.Length -gt 400) { $stderr = $stderr.Substring(0, 400) }
                Add-Failure "winget show failed for '$($app.wingetId)' with exit code $($process.ExitCode). $stderr"
            }
        } finally {
            Remove-Item -Path $stdoutPath,$stderrPath -Force -ErrorAction SilentlyContinue
        }
    }
}

$scriptText = [System.IO.File]::ReadAllText((Resolve-Path $ScriptPath).Path)
$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseInput($scriptText, [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count -gt 0) {
    foreach ($error in $parseErrors) {
        Add-Failure "PowerShell parser error at line $($error.Extent.StartLineNumber): $($error.Message)"
    }
}

$catalog = Read-JsonFile -Path $CatalogPath
$groups = Read-JsonFile -Path $GroupsPath

if ($catalog.schemaVersion -ne 1) { Add-Failure "catalog/winget.json schemaVersion must be 1." }
if ($groups.schemaVersion -ne 1) { Add-Failure "catalog/groups.json schemaVersion must be 1." }

$scriptVersions = @(Get-ScriptVersion -Text $scriptText)
if ($scriptVersions.Count -ne 1) {
    Add-Failure "Expected exactly one script version, found: $($scriptVersions -join ', ')"
} elseif ($catalog.version -ne $scriptVersions[0] -or $groups.version -ne $scriptVersions[0]) {
    Add-Failure "Version mismatch: script=$($scriptVersions[0]), catalog=$($catalog.version), groups=$($groups.version)."
}
$version = if ($scriptVersions.Count -eq 1) { $scriptVersions[0] } else { $catalog.version }

$allApps = New-Object System.Collections.ArrayList
$categoryCounts = @{}
foreach ($category in @($catalog.categories)) {
    if ([string]::IsNullOrWhiteSpace($category.name)) { Add-Failure "Catalog contains a category with an empty name." }
    if ($categoryCounts.ContainsKey($category.name)) { Add-Failure "Duplicate catalog category '$($category.name)'." }
    $categoryCounts[$category.name] = @($category.apps).Count
    if ([int]$category.count -ne @($category.apps).Count) {
        Add-Failure "Category '$($category.name)' count is $($category.count), but contains $(@($category.apps).Count) apps."
    }
    foreach ($app in @($category.apps)) {
        if ([string]::IsNullOrWhiteSpace($app.name)) { Add-Failure "Category '$($category.name)' contains an app with an empty name." }
        if ([string]::IsNullOrWhiteSpace($app.wingetId)) { Add-Failure "Category '$($category.name)' contains '$($app.name)' with an empty wingetId." }
        if ([string]::IsNullOrWhiteSpace($app.iconUrl) -or $app.iconUrl -notmatch '^https?://') {
            Add-Failure "App '$($app.name)' has an invalid iconUrl '$($app.iconUrl)'."
        }
        [void]$allApps.Add($app)
    }
}

if ([int]$catalog.categoryCount -ne $categoryCounts.Count) {
    Add-Failure "Catalog categoryCount is $($catalog.categoryCount), but contains $($categoryCounts.Count) categories."
}
if ([int]$catalog.appCount -ne $allApps.Count) {
    Add-Failure "Catalog appCount is $($catalog.appCount), but contains $($allApps.Count) apps."
}

$duplicateIds = @($allApps | Group-Object wingetId | Where-Object { $_.Count -gt 1 })
foreach ($duplicate in $duplicateIds) {
    Add-Failure "Duplicate WingetId '$($duplicate.Name)' appears $($duplicate.Count) times."
}

$allIds = @{}
foreach ($app in $allApps) {
    $allIds[$app.wingetId] = $true
}

$groupNames = New-Object System.Collections.Generic.List[string]
foreach ($group in @($groups.groups)) {
    if ([string]::IsNullOrWhiteSpace($group.name)) { Add-Failure "Built-in group with empty name." }
    $groupNames.Add($group.name)
    $packageIds = @($group.packageIds)
    if ([int]$group.appCount -ne $packageIds.Count) {
        Add-Failure "Group '$($group.name)' appCount is $($group.appCount), but contains $($packageIds.Count) package IDs."
    }
    foreach ($id in $packageIds) {
        if (!$allIds.ContainsKey($id)) {
            Add-Failure "Group '$($group.name)' references missing package ID '$id'."
        }
    }
}

if ([int]$groups.groupCount -ne @($groups.groups).Count) {
    Add-Failure "groups.json groupCount is $($groups.groupCount), but contains $(@($groups.groups).Count) groups."
}

$exportScript = Join-Path $PSScriptRoot "Export-WingetterCatalog.ps1"
$syncScript = Join-Path $PSScriptRoot "Sync-EmbeddedCatalog.ps1"
& $syncScript -ScriptPath $ScriptPath -CatalogPath $CatalogPath -GroupsPath $GroupsPath -Check
if ($LASTEXITCODE -ne 0) {
    Add-Failure "Embedded catalog fallback is stale."
}

& $exportScript -ScriptPath $ScriptPath -CatalogPath $CatalogPath -GroupsPath $GroupsPath -Check
if ($LASTEXITCODE -ne 0) {
    Add-Failure "Generated catalog snapshots are stale."
}

$readme = Get-Content -Path $ReadmePath -Raw
$changelog = Get-Content -Path $ChangelogPath -Raw

if ($readme -notmatch "version-$([regex]::Escape($version))") {
    Add-Failure "README version badge does not mention $version."
}
if ($readme -notmatch "Apps-$($catalog.appCount)") {
    Add-Failure "README apps badge does not mention $($catalog.appCount)."
}
if ($readme -notmatch "Categories-$($catalog.categoryCount)") {
    Add-Failure "README categories badge does not mention $($catalog.categoryCount)."
}
if ($readme -notmatch "\*\*$($catalog.appCount) applications\*\* across \*\*$($catalog.categoryCount) categories\*\*") {
    Add-Failure "README feature summary does not match catalog totals."
}
if ($changelog -notmatch "## \[$([regex]::Escape($version))\]") {
    Add-Failure "CHANGELOG.md does not contain an entry for $version."
}
if ($changelog -match '%Y-|HEAD ->|origin/main|origin/HEAD') {
    Add-Failure "CHANGELOG.md still contains malformed git/date text."
}

$readmeCounts = Get-ReadmeCategoryCounts -Readme $readme
foreach ($categoryName in $categoryCounts.Keys) {
    if (!$readmeCounts.ContainsKey($categoryName)) {
        Add-Failure "README category table is missing '$categoryName'."
    } elseif ($readmeCounts[$categoryName] -ne $categoryCounts[$categoryName]) {
        Add-Failure "README category '$categoryName' count is $($readmeCounts[$categoryName]), expected $($categoryCounts[$categoryName])."
    }
}
foreach ($readmeCategory in $readmeCounts.Keys) {
    if (!$categoryCounts.ContainsKey($readmeCategory)) {
        Add-Failure "README category table includes unknown category '$readmeCategory'."
    }
}

$readmeGroups = Get-ReadmeGroupNames -Readme $readme
$missingReadmeGroups = @($groupNames | Where-Object { $readmeGroups -notcontains $_ })
foreach ($groupName in $missingReadmeGroups) {
    Add-Failure "README built-in group table is missing '$groupName'."
}
$unknownReadmeGroups = @($readmeGroups | Where-Object { $groupNames -notcontains $_ })
foreach ($groupName in $unknownReadmeGroups) {
    Add-Failure "README built-in group table includes unknown group '$groupName'."
}

if ($CheckWingetAvailability) {
    Assert-PackageAvailability -Apps @($allApps) -SampleSize $AvailabilitySampleSize
}

if ($failures.Count -gt 0) {
    Write-Host "Catalog validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Catalog validation passed for ${version}: $($catalog.appCount) apps, $($catalog.categoryCount) categories, $($groups.groupCount) built-in groups."
