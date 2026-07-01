# ============================================================================
# SCHEDULED UPDATE WATCHER
# ============================================================================

function Get-WingetterUpdateWatcherLogRoot {
    $root = Join-Path $env:APPDATA "Wingetter\logs\update-checks"
    if (!(Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    return $root
}

function Get-WingetterUpdatePolicyPath {
    Join-Path (Get-WingetterAppDataPath) "update-policy.json"
}

function New-WingetterUpdateMaintenanceWindow {
    param(
        [string]$Name = "Default",
        [string[]]$DaysOfWeek = @("Everyday"),
        [string]$StartLocalTime = "00:00",
        [string]$EndLocalTime = "23:59"
    )

    [PSCustomObject][ordered]@{
        Name           = $Name
        DaysOfWeek     = [string[]]@($DaysOfWeek)
        StartLocalTime = $StartLocalTime
        EndLocalTime   = $EndLocalTime
    }
}

function New-WingetterUpdatePackagePolicy {
    param(
        [string]$PackageId,
        [string]$NotBeforeUtc = "",
        [Nullable[int]]$MaxDeferrals = $null,
        [int]$DeferralCount = 0
    )

    [PSCustomObject][ordered]@{
        PackageId     = $PackageId
        NotBeforeUtc  = $NotBeforeUtc
        MaxDeferrals  = $MaxDeferrals
        DeferralCount = [int][math]::Max(0, $DeferralCount)
    }
}

function New-WingetterDefaultUpdatePolicy {
    [PSCustomObject][ordered]@{
        Schema             = "Wingetter.UpdatePolicy.v1"
        GlobalNotBeforeUtc = ""
        MaxDeferrals       = 0
        MaintenanceWindows = @()
        PackagePolicies    = @()
        UpdatedAtUtc       = (Get-Date).ToUniversalTime().ToString("o")
    }
}

function ConvertTo-WingetterUpdateMaintenanceWindow {
    param([object]$Window)

    if ($null -eq $Window) { return $null }
    $name = [string](Get-WingetterObjectPropertyValue -InputObject $Window -PropertyName "Name")
    $days = @(Get-WingetterObjectPropertyValue -InputObject $Window -PropertyName "DaysOfWeek")
    $start = [string](Get-WingetterObjectPropertyValue -InputObject $Window -PropertyName "StartLocalTime")
    $end = [string](Get-WingetterObjectPropertyValue -InputObject $Window -PropertyName "EndLocalTime")
    if ([string]::IsNullOrWhiteSpace($name)) { $name = "Default" }
    if (@($days).Count -eq 0) { $days = @("Everyday") }
    if ([string]::IsNullOrWhiteSpace($start)) { $start = "00:00" }
    if ([string]::IsNullOrWhiteSpace($end)) { $end = "23:59" }
    New-WingetterUpdateMaintenanceWindow -Name $name -DaysOfWeek ([string[]]@($days)) -StartLocalTime $start -EndLocalTime $end
}

function ConvertTo-WingetterUpdatePackagePolicy {
    param([object]$Policy)

    if ($null -eq $Policy) { return $null }
    $packageId = [string](Get-WingetterObjectPropertyValue -InputObject $Policy -PropertyName "PackageId")
    if ([string]::IsNullOrWhiteSpace($packageId)) { return $null }
    $notBefore = [string](Get-WingetterObjectPropertyValue -InputObject $Policy -PropertyName "NotBeforeUtc")
    $maxValue = Get-WingetterObjectPropertyValue -InputObject $Policy -PropertyName "MaxDeferrals"
    $maxDeferrals = $null
    if ($null -ne $maxValue -and "$maxValue" -match '^\d+$') { $maxDeferrals = [int]$maxValue }
    $countValue = Get-WingetterObjectPropertyValue -InputObject $Policy -PropertyName "DeferralCount"
    $deferralCount = if ($null -ne $countValue -and "$countValue" -match '^\d+$') { [int]$countValue } else { 0 }
    New-WingetterUpdatePackagePolicy -PackageId $packageId -NotBeforeUtc $notBefore -MaxDeferrals $maxDeferrals -DeferralCount $deferralCount
}

function ConvertTo-WingetterUpdatePolicy {
    param([object]$Policy)

    $defaultPolicy = New-WingetterDefaultUpdatePolicy
    if ($null -eq $Policy) { return $defaultPolicy }

    $globalNotBefore = [string](Get-WingetterObjectPropertyValue -InputObject $Policy -PropertyName "GlobalNotBeforeUtc")
    $maxValue = Get-WingetterObjectPropertyValue -InputObject $Policy -PropertyName "MaxDeferrals"
    $maxDeferrals = if ($null -ne $maxValue -and "$maxValue" -match '^\d+$') { [int]$maxValue } else { 0 }

    $windows = @()
    foreach ($window in @((Get-WingetterObjectPropertyValue -InputObject $Policy -PropertyName "MaintenanceWindows"))) {
        $converted = ConvertTo-WingetterUpdateMaintenanceWindow -Window $window
        if ($converted) { $windows += $converted }
    }

    $packagePolicies = @()
    foreach ($packagePolicy in @((Get-WingetterObjectPropertyValue -InputObject $Policy -PropertyName "PackagePolicies"))) {
        $converted = ConvertTo-WingetterUpdatePackagePolicy -Policy $packagePolicy
        if ($converted) { $packagePolicies += $converted }
    }

    [PSCustomObject][ordered]@{
        Schema             = "Wingetter.UpdatePolicy.v1"
        GlobalNotBeforeUtc = $globalNotBefore
        MaxDeferrals       = [int][math]::Max(0, $maxDeferrals)
        MaintenanceWindows = @($windows)
        PackagePolicies    = @($packagePolicies)
        UpdatedAtUtc       = [string](Get-WingetterObjectPropertyValue -InputObject $Policy -PropertyName "UpdatedAtUtc")
    }
}

function Get-WingetterUpdatePolicy {
    param([string]$Path = (Get-WingetterUpdatePolicyPath))

    if (![string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path)) {
        try {
            return ConvertTo-WingetterUpdatePolicy -Policy (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
        } catch {
            Move-WingetterCorruptFileAside -Path $Path
        }
    }
    return New-WingetterDefaultUpdatePolicy
}

function Save-WingetterUpdatePolicy {
    param(
        [object]$Policy,
        [string]$Path = (Get-WingetterUpdatePolicyPath)
    )

    $normalized = ConvertTo-WingetterUpdatePolicy -Policy $Policy
    $normalized.UpdatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    Set-WingetterFileAtomic -Path $Path -Content ($normalized | ConvertTo-Json -Depth 8) -Encoding UTF8
    return $normalized
}

function Get-WingetterUpdatePolicyDateTime {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $parsed = [DateTime]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
    if ([DateTime]::TryParse($Value, [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)) {
        return $parsed.ToUniversalTime()
    }
    return $null
}

function Get-WingetterUpdatePolicyPackageRule {
    param(
        [object]$Policy,
        [string]$PackageId
    )

    $normalized = ConvertTo-WingetterUpdatePolicy -Policy $Policy
    foreach ($packagePolicy in @($normalized.PackagePolicies)) {
        if ([string]::Equals([string]$packagePolicy.PackageId, [string]$PackageId, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $packagePolicy
        }
    }
    return $null
}

function Test-WingetterUpdatePolicyMaintenanceWindow {
    param(
        [object]$Policy,
        [DateTime]$NowUtc = (Get-Date).ToUniversalTime()
    )

    $normalized = ConvertTo-WingetterUpdatePolicy -Policy $Policy
    if (@($normalized.MaintenanceWindows).Count -eq 0) {
        return [PSCustomObject]@{ Allowed = $true; Reason = "No maintenance window policy is configured."; WindowName = "" }
    }

    $localNow = $NowUtc.ToLocalTime()
    $localDay = [string]$localNow.DayOfWeek
    $localTime = $localNow.TimeOfDay
    foreach ($window in @($normalized.MaintenanceWindows)) {
        $days = [string[]]@($window.DaysOfWeek)
        $dayMatches = ($days -contains "Everyday" -or $days -contains "Daily" -or $days -contains "All" -or $days -contains $localDay)
        if (!$dayMatches) { continue }

        $start = [TimeSpan]::Zero
        $end = [TimeSpan]::Zero
        if (![TimeSpan]::TryParse([string]$window.StartLocalTime, [ref]$start)) { continue }
        if (![TimeSpan]::TryParse([string]$window.EndLocalTime, [ref]$end)) { continue }
        if ($end -eq $start) { continue }
        $inside = if ($end -gt $start) {
            ($localTime -ge $start -and $localTime -lt $end)
        } else {
            ($localTime -ge $start -or $localTime -lt $end)
        }
        if ($inside) {
            return [PSCustomObject]@{ Allowed = $true; Reason = "Within maintenance window '$($window.Name)'."; WindowName = [string]$window.Name }
        }
    }

    return [PSCustomObject]@{ Allowed = $false; Reason = "Outside configured maintenance windows."; WindowName = "" }
}

function Get-WingetterUpdatePolicyDecision {
    param(
        [object]$Policy,
        [string]$PackageId,
        [DateTime]$NowUtc = (Get-Date).ToUniversalTime()
    )

    $normalized = ConvertTo-WingetterUpdatePolicy -Policy $Policy
    $windowDecision = Test-WingetterUpdatePolicyMaintenanceWindow -Policy $normalized -NowUtc $NowUtc
    if (!$windowDecision.Allowed) {
        return [PSCustomObject]@{
            Allowed       = $false
            Status        = "OutsideMaintenanceWindow"
            Reason        = $windowDecision.Reason
            NotBeforeUtc  = ""
            DeferralCount = 0
            MaxDeferrals  = [int]$normalized.MaxDeferrals
            WindowName    = ""
        }
    }

    $packageRule = Get-WingetterUpdatePolicyPackageRule -Policy $normalized -PackageId $PackageId
    $notBefore = if ($packageRule -and ![string]::IsNullOrWhiteSpace([string]$packageRule.NotBeforeUtc)) { [string]$packageRule.NotBeforeUtc } else { [string]$normalized.GlobalNotBeforeUtc }
    $maxDeferrals = if ($packageRule -and $null -ne $packageRule.MaxDeferrals) { [int]$packageRule.MaxDeferrals } else { [int]$normalized.MaxDeferrals }
    $deferralCount = if ($packageRule) { [int]$packageRule.DeferralCount } else { 0 }
    $notBeforeDate = Get-WingetterUpdatePolicyDateTime -Value $notBefore
    if ($notBeforeDate -and $NowUtc -lt $notBeforeDate) {
        if ($maxDeferrals -gt 0 -and $deferralCount -ge $maxDeferrals) {
            return [PSCustomObject]@{
                Allowed       = $true
                Status        = "Available"
                Reason        = "Deferral limit reached ($deferralCount/$maxDeferrals); update is available for review."
                NotBeforeUtc  = $notBeforeDate.ToString("o")
                DeferralCount = $deferralCount
                MaxDeferrals  = $maxDeferrals
                WindowName    = [string]$windowDecision.WindowName
            }
        }
        return [PSCustomObject]@{
            Allowed       = $false
            Status        = "Deferred"
            Reason        = "Deferred until $($notBeforeDate.ToString("o")) ($deferralCount/$maxDeferrals deferrals used)."
            NotBeforeUtc  = $notBeforeDate.ToString("o")
            DeferralCount = $deferralCount
            MaxDeferrals  = $maxDeferrals
            WindowName    = [string]$windowDecision.WindowName
        }
    }

    return [PSCustomObject]@{
        Allowed       = $true
        Status        = "Available"
        Reason        = "Update is available."
        NotBeforeUtc  = if ($notBeforeDate) { $notBeforeDate.ToString("o") } else { "" }
        DeferralCount = $deferralCount
        MaxDeferrals  = $maxDeferrals
        WindowName    = [string]$windowDecision.WindowName
    }
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
        [object]$UpdatePolicy = (New-WingetterDefaultUpdatePolicy),
        [DateTime]$NowUtc = (Get-Date).ToUniversalTime(),
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

    $normalizedUpdatePolicy = ConvertTo-WingetterUpdatePolicy -Policy $UpdatePolicy
    $items = @()
    foreach ($package in @($InstalledPackages)) {
        if (!$package.IsUpdateAvailable) { continue }
        $id = [string]$package.PackageId
        $sourceName = if (![string]::IsNullOrWhiteSpace([string]$package.Source)) { [string]$package.Source } else { "winget" }
        $policyCheck = Test-WingetterPackageAllowedBySourcePolicy -Policy $SourcePolicy -PackageId $id -SourceName $sourceName
        $updatePolicyDecision = Get-WingetterUpdatePolicyDecision -Policy $normalizedUpdatePolicy -PackageId $id -NowUtc $NowUtc
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
        } elseif (!$updatePolicyDecision.Allowed) {
            $status = [string]$updatePolicyDecision.Status
            $reason = [string]$updatePolicyDecision.Reason
        } elseif ([string]$updatePolicyDecision.Reason -ne "Update is available.") {
            $reason = [string]$updatePolicyDecision.Reason
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
            NotBeforeUtc     = [string]$updatePolicyDecision.NotBeforeUtc
            DeferralCount    = [int]$updatePolicyDecision.DeferralCount
            MaxDeferrals     = [int]$updatePolicyDecision.MaxDeferrals
            MaintenanceWindow = [string]$updatePolicyDecision.WindowName
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
        Deferred        = @($items | Where-Object { $_.Status -eq "Deferred" }).Count
        OutsideWindow   = @($items | Where-Object { $_.Status -eq "OutsideMaintenanceWindow" }).Count
    }

    [PSCustomObject]@{
        Schema                   = "Wingetter.UpdateCheck.v1"
        CheckedAtUtc             = (Get-Date).ToUniversalTime().ToString("o")
        SkippedForMeteredNetwork = [bool]$SkippedForMeteredNetwork
        DetectionMethod          = $DetectionMethod
        ScanError                = $ScanError
        CachePath                = $CachePath
        SourcePolicyCorporateMode = [bool](ConvertTo-WingetterSourcePolicy -Policy $SourcePolicy).CorporateMode
        UpdatePolicy             = [PSCustomObject][ordered]@{
            GlobalNotBeforeUtc = [string]$normalizedUpdatePolicy.GlobalNotBeforeUtc
            MaxDeferrals       = [int]$normalizedUpdatePolicy.MaxDeferrals
            MaintenanceWindows = @($normalizedUpdatePolicy.MaintenanceWindows)
            PackagePolicies    = @($normalizedUpdatePolicy.PackagePolicies)
        }
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
    # Millisecond precision + short GUID suffix: prevents two checks launched
    # within the same second (manual trigger + scheduled task firing back to
    # back, retries after transient WinGet failure) from clobbering each
    # other's log files.
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
    $entropy = [System.Guid]::NewGuid().ToString("N").Substring(0, 4)
    $path = Join-Path $LogRoot "$stamp-$entropy-update-check.json"
    Set-WingetterFileAtomic -Path $path -Content ($Result | ConvertTo-Json -Depth 8) -Encoding UTF8
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
            "$($Result.Counts.Available) available, $($Result.Counts.Deferred) deferred, $($Result.Counts.Pinned) pinned, $($Result.Counts.SourceBlocked) source-blocked"
        }
        $toastXml = [Windows.Data.Xml.Dom.XmlDocument]::new()
        $safeSummary = [System.Security.SecurityElement]::Escape($summary)
        $toastXml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>Wingetter Update Check</text><text>$safeSummary</text></binding></visual></toast>")
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
        [object]$UpdatePolicy = (Get-WingetterUpdatePolicy),
        [bool]$SkipMeteredNetwork = $true,
        [bool]$Toast = $true,
        [int]$KeepLogs = 30,
        [string]$LogRoot = (Get-WingetterUpdateWatcherLogRoot)
    )

    if ($PackageIds.Count -eq 0 -and $Script:SoftwareDatabase) {
        $collected = [System.Collections.ArrayList]::new()
        foreach ($category in $Script:SoftwareDatabase.Keys) {
            foreach ($app in @($Script:SoftwareDatabase[$category])) {
                [void]$collected.Add([string]$app.WingetId)
            }
        }
        $PackageIds = [string[]]$collected.ToArray([string])
    }

    if ($SkipMeteredNetwork -and (Test-WingetterMeteredNetwork)) {
        $result = New-WingetterUpdateCheckResult -SkippedForMeteredNetwork $true -SourcePolicy $SourcePolicy -UpdatePolicy $UpdatePolicy
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
        -UpdatePolicy $UpdatePolicy `
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
        [int]$KeepLogs = 30,
        [string]$UpdatePolicyPath = ""
    )

    $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath, "-KeepLogs", [string]$KeepLogs)
    if ($SkipMeteredNetwork) { $arguments += "-SkipMeteredNetwork" }
    if ($Toast) { $arguments += "-Toast" }
    if (![string]::IsNullOrWhiteSpace($UpdatePolicyPath)) {
        $arguments += "-UpdatePolicyPath"
        $arguments += $UpdatePolicyPath
    }
    return [string[]]$arguments
}

function Register-WingetterUpdateWatcherTask {
    param(
        [string]$ScriptPath,
        [string]$TaskName = "Wingetter Update Check",
        [DateTime]$DailyAt = ([DateTime]::Today.AddHours(9)),
        [bool]$SkipMeteredNetwork = $true,
        [bool]$Toast = $true,
        [int]$KeepLogs = 30,
        [string]$UpdatePolicyPath = ""
    )

    $actionArguments = Join-ProcessArguments -Arguments (New-WingetterUpdateWatcherTaskActionArguments -ScriptPath $ScriptPath -SkipMeteredNetwork $SkipMeteredNetwork -Toast $Toast -KeepLogs $KeepLogs -UpdatePolicyPath $UpdatePolicyPath)
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
