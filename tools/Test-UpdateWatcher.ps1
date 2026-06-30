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

    $future = (Get-Date).ToUniversalTime().AddDays(3).ToString("o")
    $deferPolicy = New-WingetterDefaultUpdatePolicy
    $deferPolicy.GlobalNotBeforeUtc = $future
    $deferPolicy.MaxDeferrals = 3
    $deferred = New-WingetterUpdateCheckResult -InstalledPackages @($records[2]) -SourcePolicy $policy -UpdatePolicy $deferPolicy
    $deferredItem = @($deferred.Updates | Select-Object -First 1)
    if ($deferredItem.Status -ne "Deferred" -or $deferred.Counts.Deferred -ne 1 -or $deferredItem.Reason -notlike "*Deferred until*") {
        Add-Failure "Global NotBefore policy did not defer an available update."
    }

    $limitPolicy = New-WingetterDefaultUpdatePolicy
    $limitPolicy.PackagePolicies = @(
        New-WingetterUpdatePackagePolicy -PackageId "Internal.Tool" -NotBeforeUtc $future -MaxDeferrals 2 -DeferralCount 2
    )
    $limitResult = New-WingetterUpdateCheckResult -InstalledPackages @($records[2]) -SourcePolicy $policy -UpdatePolicy $limitPolicy
    $limitItem = @($limitResult.Updates | Select-Object -First 1)
    if ($limitItem.Status -ne "Available" -or $limitItem.Reason -notlike "*Deferral limit reached*") {
        Add-Failure "Per-package max deferral policy did not allow review after the limit."
    }

    $localNow = (Get-Date).ToUniversalTime().ToLocalTime()
    $otherDay = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday") | Where-Object { $_ -ne [string]$localNow.DayOfWeek } | Select-Object -First 1
    $windowPolicy = New-WingetterDefaultUpdatePolicy
    $windowPolicy.MaintenanceWindows = @(New-WingetterUpdateMaintenanceWindow -Name "Other day" -DaysOfWeek @($otherDay) -StartLocalTime "00:00" -EndLocalTime "23:59")
    $windowResult = New-WingetterUpdateCheckResult -InstalledPackages @($records[2]) -SourcePolicy $policy -UpdatePolicy $windowPolicy
    $windowItem = @($windowResult.Updates | Select-Object -First 1)
    if ($windowItem.Status -ne "OutsideMaintenanceWindow" -or $windowResult.Counts.OutsideWindow -ne 1) {
        Add-Failure "Maintenance-window policy did not mark the update outside the allowed window."
    }

    $policyPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-update-policy-" + [System.Guid]::NewGuid().ToString("N") + ".json")
    try {
        $savedPolicy = Save-WingetterUpdatePolicy -Policy $limitPolicy -Path $policyPath
        $loadedPolicy = Get-WingetterUpdatePolicy -Path $policyPath
        if ($savedPolicy.Schema -ne "Wingetter.UpdatePolicy.v1" -or @($loadedPolicy.PackagePolicies).Count -ne 1 -or $loadedPolicy.PackagePolicies[0].PackageId -ne "Internal.Tool") {
            Add-Failure "Update policy save/load did not preserve per-package deferral rules."
        }
    } finally {
        Remove-Item -Path $policyPath -Force -ErrorAction SilentlyContinue
    }

    $metered = New-WingetterUpdateCheckResult -SkippedForMeteredNetwork $true
    if (!$metered.SkippedForMeteredNetwork) {
        Add-Failure "Metered-network skip flag was not preserved."
    }

    $taskArgs = New-WingetterUpdateWatcherTaskActionArguments -ScriptPath "C:\Wingetter\tools\Invoke-UpdateCheck.ps1" -SkipMeteredNetwork $true -Toast $true -KeepLogs 7 -UpdatePolicyPath "C:\Wingetter\update-policy.json"
    foreach ($expected in @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "-SkipMeteredNetwork", "-Toast", "-KeepLogs", "7", "-UpdatePolicyPath", "C:\Wingetter\update-policy.json")) {
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
