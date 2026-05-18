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

foreach ($moduleName in @(
    "Wingetter.Common.ps1",
    "Wingetter.WinGet.ps1",
    "Wingetter.Sources.ps1",
    "Wingetter.UpdateWatcher.ps1"
)) {
    $modulePath = Join-Path $SourceDir $moduleName
    if (!(Test-Path $modulePath)) {
        Add-Failure "Missing source module '$moduleName'."
        continue
    }
    try {
        . (Resolve-Path $modulePath).Path
    } catch {
        Add-Failure "Could not import source module '$moduleName': $($_.Exception.Message)"
    }
}

if ($failures.Count -eq 0) {
    $records = @(
        [PSCustomObject]@{
            PackageId        = "Google.Chrome"
            Name             = "Google Chrome"
            InstalledVersion = "124.0"
            AvailableVersion = "125.0"
            Source           = "winget"
            Scope            = "machine"
            IsUpdateAvailable = $true
        },
        [PSCustomObject]@{
            PackageId        = "Mozilla.Firefox"
            Name             = "Mozilla Firefox"
            InstalledVersion = "123.0"
            AvailableVersion = "124.0"
            Source           = "winget"
            Scope            = "user"
            IsUpdateAvailable = $true
        },
        [PSCustomObject]@{
            PackageId        = "Internal.Tool"
            Name             = "Internal Tool"
            InstalledVersion = "1.0"
            AvailableVersion = "1.1"
            Source           = "corp"
            Scope            = "machine"
            IsUpdateAvailable = $true
        },
        [PSCustomObject]@{
            PackageId        = "No.Update"
            Name             = "No Update"
            InstalledVersion = "1.0"
            AvailableVersion = ""
            Source           = "winget"
            Scope            = "machine"
            IsUpdateAvailable = $false
        }
    )

    $pinStatuses = @{
        "Mozilla.Firefox" = [PSCustomObject]@{
            PackageId = "Mozilla.Firefox"
            IsPinned  = $true
            PinType   = "Pinned"
            Summary   = "Pinned"
        }
    }
    $privateSource = New-WingetterPrivateRestSourceDefinition -Name "corp" -Argument "https://packages.example.test/api"
    $policy = New-WingetterDefaultSourcePolicy
    $policy.CorporateMode = $true
    $policy.AllowedSources = @($policy.AllowedSources[0], $privateSource)
    $policy.PrivateSources = @($privateSource)

    $result = New-WingetterUpdateCheckResult -InstalledPackages $records -SourcePolicy $policy -PinStatusesById $pinStatuses -BlockedPackageIds @("Google.Chrome")
    if ($result.Counts.Updates -ne 3) {
        Add-Failure "Update result count was '$($result.Counts.Updates)'."
    }
    if ($result.Counts.Blocked -ne 1 -or $result.Counts.Pinned -ne 1 -or $result.Counts.Available -ne 1) {
        Add-Failure "Update result status counts were unexpected: $($result.Counts | ConvertTo-Json -Compress)."
    }
    $corpItem = @($result.Updates | Where-Object { $_.PackageId -eq "Internal.Tool" } | Select-Object -First 1)
    if (!$corpItem -or $corpItem.Status -ne "Available" -or $corpItem.SourceTrust -ne "Private") {
        Add-Failure "Private source update was not marked available/trusted."
    }

    $metered = New-WingetterUpdateCheckResult -SkippedForMeteredNetwork $true
    if (!$metered.SkippedForMeteredNetwork) {
        Add-Failure "Metered-network skip flag was not preserved."
    }

    $taskArgs = New-WingetterUpdateWatcherTaskActionArguments -ScriptPath "C:\Wingetter\tools\Invoke-UpdateCheck.ps1" -SkipMeteredNetwork $true -Toast $true -KeepLogs 7
    foreach ($expected in @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "-SkipMeteredNetwork", "-Toast", "-KeepLogs", "7")) {
        if ($taskArgs -notcontains $expected) {
            Add-Failure "Scheduled task action arguments did not include '$expected'."
        }
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-update-watch-" + [System.Guid]::NewGuid().ToString("N"))
    try {
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $oldPath = Join-Path $tempRoot "20000101-000000-update-check.json"
        $newPath = Join-Path $tempRoot "20000102-000000-update-check.json"
        "{}" | Set-Content -Path $oldPath -Encoding UTF8
        Start-Sleep -Milliseconds 20
        "{}" | Set-Content -Path $newPath -Encoding UTF8
        Remove-OldWingetterUpdateCheckLogs -LogRoot $tempRoot -Keep 1
        if ((Test-Path $oldPath) -and (Test-Path $newPath)) {
            Add-Failure "Update watcher log rotation did not remove old logs."
        }

        $savedPath = Save-WingetterUpdateCheckResult -Result $result -LogRoot $tempRoot
        if (!(Test-Path $savedPath)) {
            Add-Failure "Update watcher result was not saved."
        }
    } finally {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Update watcher validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Update watcher validation passed."
