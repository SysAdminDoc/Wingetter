param(
    [string]$SourceDir = (Join-Path $PSScriptRoot "..\src")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
}

function Assert-EqualArray {
    param(
        [string[]]$Actual,
        [string[]]$Expected,
        [string]$Name
    )
    if ($Actual.Count -ne $Expected.Count) {
        Add-Failure "$Name count mismatch: expected $($Expected.Count), got $($Actual.Count)."
        return
    }
    for ($i = 0; $i -lt $Expected.Count; $i++) {
        if ($Actual[$i] -ne $Expected[$i]) {
            Add-Failure "$Name item $i mismatch: expected '$($Expected[$i])', got '$($Actual[$i])'."
        }
    }
}

foreach ($moduleName in @("Wingetter.Common.ps1", "Wingetter.Catalog.ps1", "Wingetter.Groups.ps1")) {
    $modulePath = Join-Path $SourceDir $moduleName
    if (!(Test-Path $modulePath)) {
        Add-Failure "Missing source module '$moduleName'."
        continue
    }
    try {
        . (Resolve-Path $modulePath).Path
    } catch {
        Add-Failure "Could not import '$moduleName': $($_.Exception.Message)"
    }
}

if ($failures.Count -eq 0) {
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("WingetterProfileJson_" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    try {
        $ids = [string[]]@("Google.Chrome", "Mozilla.Firefox", "7zip.7zip")

        $wingetPath = Join-Path $tempDir "winget-import.json"
        Export-GroupAsWinGetJSON -GroupName "Smoke" -PackageIds $ids -FilePath $wingetPath
        $wingetJson = Get-Content -Path $wingetPath -Raw | ConvertFrom-Json
        if ($wingetJson.'$schema' -ne "https://aka.ms/winget-packages.schema.2.0.json") {
            Add-Failure "Official WinGet JSON export has the wrong `$schema value."
        }
        $wingetPackages = @($wingetJson.Sources[0].Packages | ForEach-Object { $_.PackageIdentifier })
        Assert-EqualArray -Actual $wingetPackages -Expected $ids -Name "Official export package IDs"

        $wingetImport = Import-PackageIdsFromJSON -Content $wingetJson -FallbackGroupName "Smoke"
        Assert-EqualArray -Actual $wingetImport.PackageIds -Expected $ids -Name "Official import package IDs"
        if ($wingetImport.Format -ne "WinGet import JSON") {
            Add-Failure "Official import format was '$($wingetImport.Format)'."
        }

        $wingetterPath = Join-Path $tempDir "wingetter-group.json"
        Export-GroupAsJSON -GroupName "Smoke" -PackageIds $ids -FilePath $wingetterPath
        $wingetterJson = Get-Content -Path $wingetterPath -Raw | ConvertFrom-Json
        if ($wingetterJson.Schema -ne "Wingetter.Group.v1") {
            Add-Failure "Wingetter group JSON export has the wrong schema."
        }
        $wingetterImport = Import-PackageIdsFromJSON -Content $wingetterJson -FallbackGroupName "Smoke"
        Assert-EqualArray -Actual $wingetterImport.PackageIds -Expected $ids -Name "Wingetter import package IDs"
        if ($wingetterImport.GroupName -ne "Smoke") {
            Add-Failure "Wingetter import group name was '$($wingetterImport.GroupName)'."
        }

        $optionEntries = @(
            (New-WingetterGroupPackageEntry `
                -PackageId "Example.Tool" `
                -SourceName "winget" `
                -Name "Example Tool" `
                -InstallOptions ([PSCustomObject]@{
                    Version       = "1.2.3"
                    Scope         = "machine"
                    Architecture  = "x64"
                    InstallerType = "msi"
                    Locale        = "en-US"
                    Location      = "C:\Program Files\Example Tool"
                    Custom        = "/NoDesktopShortcut"
                }) `
                -AllowCustomInstallOptions)
        )
        $optionPath = Join-Path $tempDir "wingetter-group-options.json"
        Export-GroupAsJSON -GroupName "Options" -PackageIds @("Example.Tool") -PackageEntries $optionEntries -FilePath $optionPath
        $optionJson = Get-Content -Path $optionPath -Raw | ConvertFrom-Json
        if (!$optionJson.Packages[0].InstallOptions -or $optionJson.Packages[0].InstallOptions.Scope -ne "machine") {
            Add-Failure "Wingetter group JSON export did not persist install options."
        }
        $optionImport = Import-PackageIdsFromJSON -Content $optionJson -FallbackGroupName "Options"
        if ($optionImport.PackageEntries[0].InstallOptions.Location -ne "C:\Program Files\Example Tool" -or $optionImport.PackageEntries[0].InstallOptions.Custom -ne "/NoDesktopShortcut") {
            Add-Failure "Wingetter group JSON import did not preserve install options."
        }

        $optionWinGetPath = Join-Path $tempDir "winget-options.json"
        Export-GroupAsWinGetJSON -GroupName "Options" -PackageIds @("Example.Tool") -PackageEntries $optionEntries -FilePath $optionWinGetPath
        $optionWinGetJson = Get-Content -Path $optionWinGetPath -Raw | ConvertFrom-Json
        if ($optionWinGetJson.Sources[0].Packages[0].Version -ne "1.2.3") {
            Add-Failure "Official WinGet JSON export did not preserve safe version metadata."
        }
        if ($optionWinGetJson.Sources[0].Packages[0].PSObject.Properties["Scope"]) {
            Add-Failure "Official WinGet JSON export should not emit non-schema install option fields."
        }

        $optionScriptPath = Join-Path $tempDir "Install-Options.ps1"
        Export-GroupAsPS1 -GroupName "Options" -PackageIds @("Example.Tool") -PackageEntries $optionEntries -FilePath $optionScriptPath
        $optionScript = Get-Content -Path $optionScriptPath -Raw
        foreach ($expectedScriptText in @("InstallOptions = @", "Location = 'C:\Program Files\Example Tool'", "Custom = '/NoDesktopShortcut'", "& winget @wingetArgs")) {
            if ($optionScript -notlike "*$expectedScriptText*") {
                Add-Failure "PowerShell group export did not include install option script text '$expectedScriptText'."
            }
        }
        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($optionScriptPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
        if (@($parseErrors).Count -gt 0) {
            Add-Failure "PowerShell group export generated a script with parse errors: $($parseErrors[0].Message)"
        }

        $officialOptions = [PSCustomObject]@{
            Sources = @(
                [PSCustomObject]@{
                    SourceDetails = [PSCustomObject]@{ Name = "winget" }
                    Packages      = @(
                        [PSCustomObject]@{
                            PackageIdentifier = "Official.Tool"
                            Version           = "4.5.6"
                            Scope             = "user"
                            Architecture      = "arm64"
                            InstallerType     = "msix"
                            Locale            = "en-US"
                        }
                    )
                }
            )
        }
        $officialOptionsImport = Import-PackageIdsFromJSON -Content $officialOptions -FallbackGroupName "OfficialOptions"
        if ($officialOptionsImport.PackageEntries[0].InstallOptions.Version -ne "4.5.6" -or $officialOptionsImport.PackageEntries[0].InstallOptions.Architecture -ne "arm64") {
            Add-Failure "Official WinGet import metadata did not preserve safe install options."
        }
        if (@($officialOptionsImport.Warnings | Where-Object { $_ -match "Preserved safe install options" }).Count -ne 1) {
            Add-Failure "Official WinGet import metadata did not warn about preserved install options."
        }

        $unsafeOptionsRejected = $false
        try {
            Import-PackageIdsFromJSON -Content ([PSCustomObject]@{
                Schema   = "Wingetter.Group.v1"
                Packages = @([PSCustomObject]@{ PackageIdentifier = "Bad.Tool"; InstallOptions = [PSCustomObject]@{ Override = "/danger" } })
            }) -FallbackGroupName "UnsafeOptions" | Out-Null
        } catch {
            $unsafeOptionsRejected = ($_.Exception.Message -match "not supported")
        }
        if (-not $unsafeOptionsRejected) {
            Add-Failure "Wingetter group JSON accepted unsafe Override install options."
        }

        $arrayImport = Import-PackageIdsFromJSON -Content $ids -FallbackGroupName "Array"
        Assert-EqualArray -Actual $arrayImport.PackageIds -Expected $ids -Name "Array import package IDs"

        # R-025: edge cases for Import-PackageIdsFromJSON.

        # Duplicate package IDs deduplicate while preserving first-seen order.
        $dupContent = [PSCustomObject]@{
            Schema     = "Wingetter.Group.v1"
            PackageIds = @("A.A", "B.B", "A.A", "C.C", "B.B")
            GroupName  = "Dups"
        }
        $dupImport = Import-PackageIdsFromJSON -Content $dupContent -FallbackGroupName "FallbackDup"
        Assert-EqualArray -Actual $dupImport.PackageIds -Expected @("A.A", "B.B", "C.C") -Name "Duplicate ID deduplication"
        if ($dupImport.Format -ne "Wingetter group JSON") {
            Add-Failure "Duplicate-ID import format was '$($dupImport.Format)'."
        }
        if ($dupImport.GroupName -ne "Dups") {
            Add-Failure "Duplicate-ID import preferred fallback group name over GroupName."
        }

        # Missing PackageIdentifier warns once per offending package.
        $partialSources = [PSCustomObject]@{
            Sources = @(
                [PSCustomObject]@{
                    SourceDetails = [PSCustomObject]@{ Name = "winget" }
                    Packages      = @(
                        [PSCustomObject]@{ PackageIdentifier = "Good.One" },
                        [PSCustomObject]@{ },
                        [PSCustomObject]@{ PackageIdentifier = "Good.Two" }
                    )
                }
            )
        }
        $partialImport = Import-PackageIdsFromJSON -Content $partialSources -FallbackGroupName "Sources"
        Assert-EqualArray -Actual $partialImport.PackageIds -Expected @("Good.One", "Good.Two") -Name "Missing-PackageIdentifier filtered IDs"
        $missingIdentifierWarnings = @($partialImport.Warnings | Where-Object { $_ -match "PackageIdentifier" })
        if ($missingIdentifierWarnings.Count -ne 1) {
            Add-Failure "Missing PackageIdentifier should emit exactly one warning, got $($missingIdentifierWarnings.Count)."
        }
        Assert-EqualArray -Actual $partialImport.SourceNames -Expected @("winget") -Name "Source names with valid SourceDetails.Name"

        # Missing SourceDetails.Name warns; legacy Source.Name fallback succeeds.
        $missingSourceName = [PSCustomObject]@{
            Sources = @(
                [PSCustomObject]@{
                    SourceDetails = [PSCustomObject]@{ Argument = "https://example.com" }
                    Packages      = @([PSCustomObject]@{ PackageIdentifier = "Edge.One" })
                },
                [PSCustomObject]@{
                    Name     = "legacy"
                    Packages = @([PSCustomObject]@{ PackageIdentifier = "Edge.Two" })
                }
            )
        }
        $missingSourceImport = Import-PackageIdsFromJSON -Content $missingSourceName -FallbackGroupName "MissingSource"
        Assert-EqualArray -Actual $missingSourceImport.PackageIds -Expected @("Edge.One", "Edge.Two") -Name "Mixed-source-name imported IDs"
        Assert-EqualArray -Actual $missingSourceImport.SourceNames -Expected @("legacy") -Name "Legacy source name fallback"
        $missingNameWarnings = @($missingSourceImport.Warnings | Where-Object { $_ -match "SourceDetails.Name" })
        if ($missingNameWarnings.Count -ne 1) {
            Add-Failure "Missing SourceDetails.Name should emit exactly one warning, got $($missingNameWarnings.Count)."
        }

        # Empty Sources array yields zero packages and zero warnings.
        $emptySources = [PSCustomObject]@{ Sources = @() }
        $emptyImport = Import-PackageIdsFromJSON -Content $emptySources -FallbackGroupName "Empty"
        if ($emptyImport.PackageIds.Count -ne 0 -or $emptyImport.Warnings.Count -ne 0) {
            Add-Failure "Empty Sources should yield zero IDs and zero warnings."
        }
        if ($emptyImport.Format -ne "WinGet import JSON") {
            Add-Failure "Empty Sources should still classify as WinGet import JSON, got '$($emptyImport.Format)'."
        }

        # Mixed PackageIds + Sources: PackageIds wins (Wingetter group JSON format takes precedence).
        $mixedContent = [PSCustomObject]@{
            PackageIds = @("Mixed.One")
            Sources    = @(
                [PSCustomObject]@{
                    SourceDetails = [PSCustomObject]@{ Name = "winget" }
                    Packages      = @([PSCustomObject]@{ PackageIdentifier = "Should.Not.Win" })
                }
            )
        }
        $mixedImport = Import-PackageIdsFromJSON -Content $mixedContent -FallbackGroupName "Mixed"
        Assert-EqualArray -Actual $mixedImport.PackageIds -Expected @("Mixed.One") -Name "Mixed PackageIds + Sources precedence"
        if ($mixedImport.Format -ne "Wingetter group JSON") {
            Add-Failure "Mixed content should classify as Wingetter group JSON, got '$($mixedImport.Format)'."
        }

        # Multiple Sources with multiple packages each.
        $multiSources = [PSCustomObject]@{
            Sources = @(
                [PSCustomObject]@{
                    SourceDetails = [PSCustomObject]@{ Name = "winget" }
                    Packages      = @(
                        [PSCustomObject]@{ PackageIdentifier = "Source.A.One" },
                        [PSCustomObject]@{ PackageIdentifier = "Source.A.Two" }
                    )
                },
                [PSCustomObject]@{
                    SourceDetails = [PSCustomObject]@{ Name = "msstore" }
                    Packages      = @([PSCustomObject]@{ PackageIdentifier = "Source.B.One" })
                }
            )
        }
        $multiImport = Import-PackageIdsFromJSON -Content $multiSources -FallbackGroupName "Multi"
        Assert-EqualArray -Actual $multiImport.PackageIds -Expected @("Source.A.One", "Source.A.Two", "Source.B.One") -Name "Multi-source imported IDs"
        Assert-EqualArray -Actual $multiImport.SourceNames -Expected @("winget", "msstore") -Name "Multi-source captured names"

        # Flat Packages array (no Sources, no PackageIds) — third schema path.
        $flatContent = [PSCustomObject]@{
            Packages = @(
                [PSCustomObject]@{ PackageIdentifier = "Flat.One" },
                [PSCustomObject]@{ PackageIdentifier = "Flat.Two" }
            )
        }
        $flatImport = Import-PackageIdsFromJSON -Content $flatContent -FallbackGroupName "Flat"
        Assert-EqualArray -Actual $flatImport.PackageIds -Expected @("Flat.One", "Flat.Two") -Name "Flat Packages imported IDs"
        if ($flatImport.Format -ne "WinGet package list JSON") {
            Add-Failure "Flat Packages should classify as WinGet package list JSON, got '$($flatImport.Format)'."
        }

        # Unrecognized payload throws.
        $unrecognizedRejected = $false
        try {
            Import-PackageIdsFromJSON -Content ([PSCustomObject]@{ Foo = "bar" }) -FallbackGroupName "Reject" | Out-Null
        } catch {
            $unrecognizedRejected = ($_.Exception.Message -match "Unrecognized JSON format")
        }
        if (-not $unrecognizedRejected) {
            Add-Failure "Unrecognized JSON payload was not rejected with the expected error message."
        }

        # Excessively large payloads should be rejected up-front so a malicious
        # or corrupt JSON cannot cause runaway memory use or hang the UI on
        # tens of thousands of fake packages.
        $excessive = [PSCustomObject]@{
            Schema     = "Wingetter.Group.v1"
            PackageIds = @(1..($Script:WingetterImportMaxPackages + 5) | ForEach-Object { "Big.$_" })
        }
        $oversizedRejected = $false
        try {
            Import-PackageIdsFromJSON -Content $excessive -FallbackGroupName "Big" | Out-Null
        } catch {
            $oversizedRejected = $_.Exception.Message -match "exceeds the"
        }
        if (-not $oversizedRejected) {
            Add-Failure "Oversized import payload was not rejected by Import-PackageIdsFromJSON."
        }

        # Corrupt groups file should be moved aside (with a warning) and the
        # subsequent read should return an empty object rather than throwing.
        $corruptDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-corrupt-test-" + [System.Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $corruptDir -Force | Out-Null
        try {
            $corruptFile = Join-Path $corruptDir "groups.json"
            Set-Content -Path $corruptFile -Value "{not json" -Encoding UTF8
            Move-WingetterCorruptFileAside -Path $corruptFile 3>$null
            if (Test-Path $corruptFile) {
                Add-Failure "Move-WingetterCorruptFileAside did not move the source file aside."
            }
            $movedAsidePath = "$corruptFile.corrupt"
            if (!(Test-Path $movedAsidePath)) {
                Add-Failure "Move-WingetterCorruptFileAside did not produce a .corrupt sibling."
            }
        } finally {
            Remove-Item -Path $corruptDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        $installedRecords = @{
            "Google.Chrome" = [PSCustomObject]@{
                InstalledVersion = "124.0"
                AvailableVersion = "125.0"
                Source           = "winget"
                Scope            = "user"
                DetectionMethod  = "Microsoft.WinGet.Client"
                ScannedAtUtc     = "2026-05-17T00:00:00.0000000Z"
            }
        }
        $runResults = @(
            [PSCustomObject]@{
                PackageId     = "Google.Chrome"
                PackageName   = "Google Chrome"
                Action        = "install"
                Status        = "SUCCESS"
                ExitCode      = 0
                Command       = "winget install --id Google.Chrome --exact"
                ResultPath    = Join-Path $tempDir "chrome.result.json"
                StdOutExcerpt = "installed"
                StdErrExcerpt = ""
            },
            [PSCustomObject]@{
                PackageId     = "Mozilla.Firefox"
                PackageName   = "Mozilla Firefox"
                Action        = "install"
                Status        = "FAILED"
                ExitCode      = 1
                Command       = "winget install --id Mozilla.Firefox --exact"
                ResultPath    = Join-Path $tempDir "firefox.result.json"
                StdOutExcerpt = ""
                StdErrExcerpt = "failed"
            }
        )
        $runPlan = [PSCustomObject]@{
            Schema = "Wingetter.RunPlan.v1"
            Summary = [PSCustomObject]@{ runnable = 1; skipped = 1; blocked = 0 }
            Packages = @(
                [PSCustomObject]@{ Name = "Google Chrome"; PackageId = "Google.Chrome"; PlannedAction = "Install"; Status = "READY"; Reason = "Ready to run." },
                [PSCustomObject]@{ Name = "Mozilla Firefox"; PackageId = "Mozilla.Firefox"; PlannedAction = "Skip"; Status = "INSTALLED_CURRENT"; Reason = "Already installed." }
            )
        }
        $report = New-WingetterMigrationReport `
            -ProfileName "Smoke" `
            -SelectedPackages @(
                @{ Name = "Google Chrome"; WingetId = "Google.Chrome" },
                @{ Name = "Mozilla Firefox"; WingetId = "Mozilla.Firefox" }
            ) `
            -RunResults $runResults `
            -InstalledRecords $installedRecords `
            -ImportWarnings @("one warning") `
            -RunLogDir $tempDir `
            -RunPlan $runPlan
        if ($report.schema -ne "Wingetter.MigrationReport.v1") {
            Add-Failure "Migration report has the wrong schema."
        }
        if ($report.summary.succeeded -ne 1 -or $report.summary.failed -ne 1 -or $report.summary.selected -ne 2) {
            Add-Failure "Migration report summary counts were incorrect."
        }
        if (@($report.packages).Count -ne 2 -or $report.packages[0].installedVersion -ne "124.0") {
            Add-Failure "Migration report did not include package version state."
        }
        if ($report.runPlan.Schema -ne "Wingetter.RunPlan.v1" -or $report.runPlan.Summary.runnable -ne 1) {
            Add-Failure "Migration report did not include the preflight run plan."
        }
        $reportPath = Join-Path $tempDir "migration-report.json"
        Export-WingetterMigrationReport -Report $report -FilePath $reportPath
        $roundTripReport = Get-Content -Path $reportPath -Raw | ConvertFrom-Json
        if ($roundTripReport.schema -ne "Wingetter.MigrationReport.v1") {
            Add-Failure "Migration report JSON export did not round trip."
        }
        $markdown = ConvertTo-WingetterMigrationMarkdown -Report $report
        if ($markdown -notmatch "Wingetter Migration Report" -or $markdown -notmatch "Google.Chrome" -or $markdown -notmatch "Preflight Plan") {
            Add-Failure "Migration report Markdown export did not include expected content."
        }
    } finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$fixtureReport = [PSCustomObject]@{
    schema = "Wingetter.MigrationReport.v1"
    packages = @(
        [PSCustomObject]@{ name = "Chrome"; packageId = "Google.Chrome"; status = "SUCCESS"; source = "winget" },
        [PSCustomObject]@{ name = "Firefox"; packageId = "Mozilla.Firefox"; status = "FAILED"; source = "winget" },
        [PSCustomObject]@{ name = "7zip"; packageId = "7zip.7zip"; status = "CANCELLED"; source = "winget" },
        [PSCustomObject]@{ name = "VLC"; packageId = "VideoLAN.VLC"; status = "UP TO DATE"; source = "winget" },
        [PSCustomObject]@{ name = "Git"; packageId = "Git.Git"; status = "NOT RUN"; source = "winget" }
    )
    runPlan = $null
}
$retryPkgs = Get-WingetterRetryPackagesFromReport -Report $fixtureReport
if (@($retryPkgs).Count -ne 3) { Add-Failure "Retry packages should be 3 (FAILED/CANCELLED/NOT RUN), got $(@($retryPkgs).Count)." }
$retryIds = @($retryPkgs | ForEach-Object { $_.WingetId })
if ($retryIds -notcontains "Mozilla.Firefox") { Add-Failure "Retry packages missing FAILED package." }
if ($retryIds -notcontains "7zip.7zip") { Add-Failure "Retry packages missing CANCELLED package." }
if ($retryIds -notcontains "Git.Git") { Add-Failure "Retry packages missing NOT RUN package." }
if ($retryIds -contains "Google.Chrome") { Add-Failure "Retry packages should not include SUCCESS." }
if ($retryIds -contains "VideoLAN.VLC") { Add-Failure "Retry packages should not include UP TO DATE." }
$emptyRetry = Get-WingetterRetryPackagesFromReport -Report ([PSCustomObject]@{ packages = @([PSCustomObject]@{ name = "X"; packageId = "X.X"; status = "SUCCESS"; source = "winget" }) })
if (@($emptyRetry).Count -ne 0) { Add-Failure "Retry from all-success report should be empty." }
$nullRetry = Get-WingetterRetryPackagesFromReport -Report $null
if (@($nullRetry).Count -ne 0) { Add-Failure "Retry from null report should be empty." }

$complianceInstalled = @{
    "Google.Chrome" = [PSCustomObject]@{ PackageId = "Google.Chrome"; InstalledVersion = "124.0"; AvailableVersion = "125.0"; IsUpdateAvailable = $true; Source = "winget" }
    "Mozilla.Firefox" = [PSCustomObject]@{ PackageId = "Mozilla.Firefox"; InstalledVersion = "115.0"; AvailableVersion = ""; IsUpdateAvailable = $false; Source = "winget" }
}
$compliancePins = @{
    "Google.Chrome" = [PSCustomObject]@{ PackageId = "Google.Chrome"; IsPinned = $true; PinType = "Blocking" }
}
$compliancePolicy = [PSCustomObject]@{
    CorporateMode = $true; RequireAllowedSource = $true
    AllowedSources = @([PSCustomObject]@{ Name = "winget" })
}
$complianceDesired = @(
    [PSCustomObject]@{ WingetId = "Google.Chrome"; Name = "Chrome"; SourceName = "winget" },
    [PSCustomObject]@{ WingetId = "Mozilla.Firefox"; Name = "Firefox"; SourceName = "winget" },
    [PSCustomObject]@{ WingetId = "7zip.7zip"; Name = "7zip"; SourceName = "winget" },
    [PSCustomObject]@{ WingetId = "Internal.App"; Name = "Internal"; SourceName = "corp" }
)
$compReport = New-WingetterComplianceReport -ProfileName "Test" -DesiredPackages $complianceDesired -InstalledRecords $complianceInstalled -PinStatusesById $compliancePins -SourcePolicy $compliancePolicy
if ($compReport.Schema -ne "Wingetter.ComplianceReport.v1") { Add-Failure "Compliance report schema mismatch." }
if ($compReport.Summary.Pinned -ne 1) { Add-Failure "Compliance report should have 1 pinned (got $($compReport.Summary.Pinned))." }
if ($compReport.Summary.Current -ne 1) { Add-Failure "Compliance report should have 1 current (got $($compReport.Summary.Current))." }
if ($compReport.Summary.Missing -ne 1) { Add-Failure "Compliance report should have 1 missing (got $($compReport.Summary.Missing))." }
if ($compReport.Summary.SourceBlocked -ne 1) { Add-Failure "Compliance report should have 1 source-blocked (got $($compReport.Summary.SourceBlocked))." }

if ($failures.Count -gt 0) {
    Write-Host "Profile JSON validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Profile JSON validation passed."
