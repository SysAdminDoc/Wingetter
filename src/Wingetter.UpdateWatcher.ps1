# ============================================================================
# SCHEDULED UPDATE WATCHER
# ============================================================================

function Get-WingetterUpdateWatcherLogRoot {
    $root = Join-Path $env:APPDATA "Wingetter\logs\update-checks"
    if (!(Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    return $root
}

function Test-WingetterMeteredNetwork {
    try {
        [Windows.Networking.Connectivity.NetworkInformation, Windows.Networking.Connectivity, ContentType = WindowsRuntime] | Out-Null
        $networkProfile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
        if ($null -eq $networkProfile) { return $false }
        $cost = $networkProfile.GetConnectionCost()
        if ($null -eq $cost) { return $false }
        return ($cost.NetworkCostType.ToString() -ne "Unrestricted" -or [bool]$cost.Roaming -or [bool]$cost.OverDataLimit)
    } catch {
        return $false
    }
}

function New-WingetterUpdateCheckResult {
    param(
        [object[]]$InstalledPackages = @(),
        [object]$SourcePolicy = (New-WingetterDefaultSourcePolicy),
        [hashtable]$PinStatusesById = @{},
        [string[]]$AllowedPackageIds = @(),
        [string[]]$BlockedPackageIds = @(),
        [bool]$SkippedForMeteredNetwork = $false,
        [string]$DetectionMethod = "",
        [string]$ScanError = "",
        [string]$CachePath = ""
    )

    $allowedLookup = @{}
    foreach ($id in @($AllowedPackageIds)) {
        if (![string]::IsNullOrWhiteSpace($id)) { $allowedLookup[[string]$id] = $true }
    }
    $blockedLookup = @{}
    foreach ($id in @($BlockedPackageIds)) {
        if (![string]::IsNullOrWhiteSpace($id)) { $blockedLookup[[string]$id] = $true }
    }

    $items = @()
    foreach ($package in @($InstalledPackages)) {
        if (!$package.IsUpdateAvailable) { continue }
        $id = [string]$package.PackageId
        $sourceName = if (![string]::IsNullOrWhiteSpace([string]$package.Source)) { [string]$package.Source } else { "winget" }
        $policyCheck = Test-WingetterPackageAllowedBySourcePolicy -Policy $SourcePolicy -PackageId $id -SourceName $sourceName
        $pinStatus = if ($PinStatusesById.ContainsKey($id)) { $PinStatusesById[$id] } else { $null }

        $status = "Available"
        $reason = "Update is available."
        if ($blockedLookup.ContainsKey($id)) {
            $status = "Blocked"
            $reason = "Package is blocklisted for scheduled checks."
        } elseif ($allowedLookup.Count -gt 0 -and !$allowedLookup.ContainsKey($id)) {
            $status = "NotAllowlisted"
            $reason = "Package is not in the scheduled-check allowlist."
        } elseif (!$policyCheck.Allowed) {
            $status = "SourceBlocked"
            $reason = $policyCheck.Reason
        } elseif ($pinStatus -and $pinStatus.IsPinned) {
            $status = "Pinned"
            $reason = $pinStatus.Summary
        }

        $items += [PSCustomObject]@{
            PackageId        = $id
            Name             = [string]$package.Name
            InstalledVersion = [string]$package.InstalledVersion
            AvailableVersion = [string]$package.AvailableVersion
            Source           = $sourceName
            Scope            = [string]$package.Scope
            Status           = $status
            Reason           = $reason
            PinType          = if ($pinStatus) { [string]$pinStatus.PinType } else { "None" }
            SourceTrust      = [string]$policyCheck.TrustLevel
        }
    }

    $counts = [ordered]@{
        Installed       = @($InstalledPackages).Count
        Updates         = @($items).Count
        Available       = @($items | Where-Object { $_.Status -eq "Available" }).Count
        Pinned          = @($items | Where-Object { $_.Status -eq "Pinned" }).Count
        SourceBlocked   = @($items | Where-Object { $_.Status -eq "SourceBlocked" }).Count
        Blocked         = @($items | Where-Object { $_.Status -eq "Blocked" }).Count
        NotAllowlisted  = @($items | Where-Object { $_.Status -eq "NotAllowlisted" }).Count
    }

    [PSCustomObject]@{
        Schema                   = "Wingetter.UpdateCheck.v1"
        CheckedAtUtc             = (Get-Date).ToUniversalTime().ToString("o")
        SkippedForMeteredNetwork = [bool]$SkippedForMeteredNetwork
        DetectionMethod          = $DetectionMethod
        ScanError                = $ScanError
        CachePath                = $CachePath
        SourcePolicyCorporateMode = [bool](ConvertTo-WingetterSourcePolicy -Policy $SourcePolicy).CorporateMode
        Counts                   = [PSCustomObject]$counts
        Updates                  = @($items)
    }
}

function Save-WingetterUpdateCheckResult {
    param(
        [object]$Result,
        [string]$LogRoot = (Get-WingetterUpdateWatcherLogRoot)
    )

    if (!(Test-Path $LogRoot)) { New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $path = Join-Path $LogRoot "$stamp-update-check.json"
    $Result | ConvertTo-Json -Depth 8 | Set-Content -Path $path -Encoding UTF8
    return $path
}

function Remove-OldWingetterUpdateCheckLogs {
    param(
        [string]$LogRoot = (Get-WingetterUpdateWatcherLogRoot),
        [int]$Keep = 30
    )

    if ($Keep -lt 1 -or !(Test-Path $LogRoot)) { return }
    $logs = @(Get-ChildItem -Path $LogRoot -Filter "*-update-check.json" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending)
    foreach ($oldLog in @($logs | Select-Object -Skip $Keep)) {
        Remove-Item -Path $oldLog.FullName -Force -ErrorAction SilentlyContinue
    }
}

function Show-WingetterUpdateCheckToast {
    param([object]$Result)

    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
        $summary = if ($Result.SkippedForMeteredNetwork) {
            "Skipped on metered network"
        } else {
            "$($Result.Counts.Available) available, $($Result.Counts.Pinned) pinned, $($Result.Counts.SourceBlocked) source-blocked"
        }
        $toastXml = [Windows.Data.Xml.Dom.XmlDocument]::new()
        $toastXml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>Wingetter Update Check</text><text>$summary</text></binding></visual></toast>")
        $toast = [Windows.UI.Notifications.ToastNotification]::new($toastXml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Wingetter").Show($toast)
    } catch {}
}

function Invoke-WingetterUpdateCheck {
    param(
        [string[]]$PackageIds = @(),
        [object]$SourcePolicy = (Get-WingetterSourcePolicy),
        [string[]]$AllowedPackageIds = @(),
        [string[]]$BlockedPackageIds = @(),
        [bool]$SkipMeteredNetwork = $true,
        [bool]$Toast = $true,
        [int]$KeepLogs = 30,
        [string]$LogRoot = (Get-WingetterUpdateWatcherLogRoot)
    )

    if ($PackageIds.Count -eq 0 -and $Script:SoftwareDatabase) {
        foreach ($category in $Script:SoftwareDatabase.Keys) {
            foreach ($app in @($Script:SoftwareDatabase[$category])) {
                $PackageIds += [string]$app.WingetId
            }
        }
    }

    if ($SkipMeteredNetwork -and (Test-WingetterMeteredNetwork)) {
        $result = New-WingetterUpdateCheckResult -SkippedForMeteredNetwork $true -SourcePolicy $SourcePolicy
        $path = Save-WingetterUpdateCheckResult -Result $result -LogRoot $LogRoot
        Remove-OldWingetterUpdateCheckLogs -LogRoot $LogRoot -Keep $KeepLogs
        if ($Toast) { Show-WingetterUpdateCheckToast -Result $result }
        return [PSCustomObject]@{ Result = $result; LogPath = $path }
    }

    $scan = Get-WingetterPackageSourceInstalledCatalogPackages -SourceName "" -PackageIds $PackageIds
    $pinStatuses = @{}
    foreach ($record in @($scan.Packages.Values | Where-Object { $_.IsUpdateAvailable })) {
        try {
            $pinStatuses[[string]$record.PackageId] = Get-WingetterPackageSourcePinStatus -PackageId ([string]$record.PackageId)
        } catch {}
    }

    $result = New-WingetterUpdateCheckResult `
        -InstalledPackages @($scan.Packages.Values) `
        -SourcePolicy $SourcePolicy `
        -PinStatusesById $pinStatuses `
        -AllowedPackageIds $AllowedPackageIds `
        -BlockedPackageIds $BlockedPackageIds `
        -DetectionMethod $scan.DetectionMethod `
        -ScanError $scan.Error `
        -CachePath $scan.CachePath

    $path = Save-WingetterUpdateCheckResult -Result $result -LogRoot $LogRoot
    Remove-OldWingetterUpdateCheckLogs -LogRoot $LogRoot -Keep $KeepLogs
    if ($Toast) { Show-WingetterUpdateCheckToast -Result $result }
    return [PSCustomObject]@{ Result = $result; LogPath = $path }
}

function New-WingetterUpdateWatcherTaskActionArguments {
    param(
        [string]$ScriptPath,
        [bool]$SkipMeteredNetwork = $true,
        [bool]$Toast = $true,
        [int]$KeepLogs = 30
    )

    $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath, "-KeepLogs", [string]$KeepLogs)
    if ($SkipMeteredNetwork) { $arguments += "-SkipMeteredNetwork" }
    if ($Toast) { $arguments += "-Toast" }
    return [string[]]$arguments
}

function Register-WingetterUpdateWatcherTask {
    param(
        [string]$ScriptPath,
        [string]$TaskName = "Wingetter Update Check",
        [DateTime]$DailyAt = ([DateTime]::Today.AddHours(9)),
        [bool]$SkipMeteredNetwork = $true,
        [bool]$Toast = $true,
        [int]$KeepLogs = 30
    )

    $actionArguments = Join-ProcessArguments -Arguments (New-WingetterUpdateWatcherTaskActionArguments -ScriptPath $ScriptPath -SkipMeteredNetwork $SkipMeteredNetwork -Toast $Toast -KeepLogs $KeepLogs)
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $actionArguments
    $trigger = New-ScheduledTaskTrigger -Daily -At $DailyAt
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description "Checks Wingetter catalog packages for available updates without installing them." -Force | Out-Null
    Get-ScheduledTask -TaskName $TaskName
}

function Unregister-WingetterUpdateWatcherTask {
    param([string]$TaskName = "Wingetter Update Check")
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
}
