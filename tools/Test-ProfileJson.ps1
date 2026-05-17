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

        $arrayImport = Import-PackageIdsFromJSON -Content $ids -FallbackGroupName "Array"
        Assert-EqualArray -Actual $arrayImport.PackageIds -Expected $ids -Name "Array import package IDs"

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
        $report = New-WingetterMigrationReport `
            -ProfileName "Smoke" `
            -SelectedPackages @(
                @{ Name = "Google Chrome"; WingetId = "Google.Chrome" },
                @{ Name = "Mozilla Firefox"; WingetId = "Mozilla.Firefox" }
            ) `
            -RunResults $runResults `
            -InstalledRecords $installedRecords `
            -ImportWarnings @("one warning") `
            -RunLogDir $tempDir
        if ($report.schema -ne "Wingetter.MigrationReport.v1") {
            Add-Failure "Migration report has the wrong schema."
        }
        if ($report.summary.succeeded -ne 1 -or $report.summary.failed -ne 1 -or $report.summary.selected -ne 2) {
            Add-Failure "Migration report summary counts were incorrect."
        }
        if (@($report.packages).Count -ne 2 -or $report.packages[0].installedVersion -ne "124.0") {
            Add-Failure "Migration report did not include package version state."
        }
        $reportPath = Join-Path $tempDir "migration-report.json"
        Export-WingetterMigrationReport -Report $report -FilePath $reportPath
        $roundTripReport = Get-Content -Path $reportPath -Raw | ConvertFrom-Json
        if ($roundTripReport.schema -ne "Wingetter.MigrationReport.v1") {
            Add-Failure "Migration report JSON export did not round trip."
        }
        $markdown = ConvertTo-WingetterMigrationMarkdown -Report $report
        if ($markdown -notmatch "Wingetter Migration Report" -or $markdown -notmatch "Google.Chrome") {
            Add-Failure "Migration report Markdown export did not include expected content."
        }
    } finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Profile JSON validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Profile JSON validation passed."
