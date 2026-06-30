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

foreach ($moduleName in @("Wingetter.Common.ps1", "Wingetter.WinGet.ps1")) {
    $modulePath = Join-Path $SourceDir $moduleName
    if (!(Test-Path $modulePath)) {
        Add-Failure "Missing source module '$moduleName'."
    } else {
        try {
            . (Resolve-Path $modulePath).Path
        } catch {
            Add-Failure "Could not import '$moduleName': $($_.Exception.Message)"
        }
    }
}

$sourcesModulePath = Join-Path $SourceDir "Wingetter.Sources.ps1"
if (!(Test-Path $sourcesModulePath)) {
    Add-Failure "Missing source module 'Wingetter.Sources.ps1'."
} else {
    try {
        . (Resolve-Path $sourcesModulePath).Path
    } catch {
        Add-Failure "Could not import 'Wingetter.Sources.ps1': $($_.Exception.Message)"
    }
}

if ($failures.Count -eq 0) {
    $joined = Join-ProcessArguments -Arguments @("install", "--id", "Example.Package", "--exact", "--custom", "value with spaces")
    if ($joined -ne 'install --id Example.Package --exact --custom "value with spaces"') {
        Add-Failure "Join-ProcessArguments produced unexpected output: $joined"
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    Set-ProcessArguments -ProcessStartInfo $psi -Arguments @("show", "--id", "Google.Chrome")
    $argumentListProperty = [System.Diagnostics.ProcessStartInfo].GetProperty("ArgumentList")
    if ($argumentListProperty) {
        if ($psi.ArgumentList.Count -ne 3 -or $psi.ArgumentList[2] -ne "Google.Chrome") {
            Add-Failure "Set-ProcessArguments did not populate ArgumentList as expected."
        }
    } elseif ($psi.Arguments -ne "show --id Google.Chrome") {
        Add-Failure "Set-ProcessArguments did not populate Arguments as expected."
    }

    $safeName = Get-SafeFileName -Value "Publisher.Package:Beta/Canary"
    if ($safeName -match '[:/\\]') {
        Add-Failure "Get-SafeFileName did not remove path separators: $safeName"
    }

    $excerpt = Get-TextExcerpt -Text ("a" * 1100) -MaxLength 100
    if ($excerpt.Length -ne 100) {
        Add-Failure "Get-TextExcerpt did not honor MaxLength."
    }

    if ((Get-WinGetOperationStatus -ExitCode 0 -StdOut "Successfully installed" -StdErr "" -Cancelled $false) -ne "SUCCESS") {
        Add-Failure "Status classifier did not classify success."
    }
    if ((Get-WinGetOperationStatus -ExitCode 1 -StdOut "No available upgrade" -StdErr "" -Cancelled $false) -ne "UP TO DATE") {
        Add-Failure "Status classifier did not classify up-to-date output."
    }
    if ((Get-WinGetOperationStatus -ExitCode -1 -StdOut "" -StdErr "" -Cancelled $true) -ne "CANCELLED") {
        Add-Failure "Status classifier did not classify cancellation."
    }
    if ((Get-WinGetOperationStatus -ExitCode 42 -StdOut "" -StdErr "boom" -Cancelled $false) -ne "FAILED") {
        Add-Failure "Status classifier did not classify failure."
    }

    # R-020: classification signal should report whether the verdict came from the
    # exit code, the English-text fallback, the cancel flag, or nothing.
    $signal = 'None'
    [void](Get-WinGetOperationStatus -ExitCode 0 -StdOut "Successfully installed" -StdErr "" -Cancelled $false -Signal ([ref]$signal))
    if ($signal -ne 'ExitCode') { Add-Failure "Status classifier signal should be ExitCode for plain success, got '$signal'." }
    $signal = 'None'
    [void](Get-WinGetOperationStatus -ExitCode 1 -StdOut "No available upgrade" -StdErr "" -Cancelled $false -Signal ([ref]$signal))
    if ($signal -ne 'Text') { Add-Failure "Status classifier signal should be Text when only English-text matches, got '$signal'." }
    $signal = 'None'
    [void](Get-WinGetOperationStatus -ExitCode -1 -StdOut "" -StdErr "" -Cancelled $true -Signal ([ref]$signal))
    if ($signal -ne 'Cancelled') { Add-Failure "Status classifier signal should be Cancelled when cancellation flag is set, got '$signal'." }

    # R-020: documented WinGet HRESULT codes classify as UP TO DATE without any
    # English text in stdout/stderr, even when the user's WinGet is localized.
    foreach ($hresultCode in @(-1978335189, -1978335135, -1978335190)) {
        $signal = 'None'
        $status = Get-WinGetOperationStatus -ExitCode $hresultCode -StdOut "" -StdErr "" -Cancelled $false -Signal ([ref]$signal)
        if ($status -ne 'UP TO DATE' -or $signal -ne 'ExitCode') {
            Add-Failure "Documented WinGet exit code $hresultCode should classify as UP TO DATE via ExitCode signal, got '$status'/'$signal'."
        }
        $meaning = Get-WinGetExitCodeMeaning -ExitCode $hresultCode
        if ([string]::IsNullOrWhiteSpace($meaning)) {
            Add-Failure "Get-WinGetExitCodeMeaning should map documented exit code $hresultCode to a non-empty meaning."
        }
    }
    if ($null -ne (Get-WinGetExitCodeMeaning -ExitCode 1603)) {
        Add-Failure "Get-WinGetExitCodeMeaning should return `$null for unknown exit codes."
    }

    $availableStatus = ConvertTo-WinGetAvailabilityStatus -CommandFound $true -Path "C:\Windows\winget.exe" -VersionOutput @("v1.29.280") -ExitCode 0 -LanguageMode "FullLanguage"
    if (-not $availableStatus.Installed -or $availableStatus.Status -ne "Available" -or $availableStatus.Version -ne "v1.29.280") {
        Add-Failure "WinGet availability classifier did not classify an available client."
    }
    $missingStatus = ConvertTo-WinGetAvailabilityStatus -CommandFound $false -LanguageMode "FullLanguage"
    if ($missingStatus.Installed -or $missingStatus.Status -ne "Missing" -or -not $missingStatus.CanRepair) {
        Add-Failure "WinGet availability classifier did not classify a missing client as repairable."
    }
    $policyStatus = ConvertTo-WinGetAvailabilityStatus -CommandFound $true -Path "C:\Windows\winget.exe" -ErrorOutput @("This command has been disabled by your administrator through Group Policy.") -ExitCode 1 -LanguageMode "FullLanguage"
    if ($policyStatus.Installed -or $policyStatus.Status -ne "PolicyBlocked" -or $policyStatus.CanRepair -or $policyStatus.Blocker -ne "GroupPolicy") {
        Add-Failure "WinGet availability classifier did not classify a policy-disabled client."
    }
    $constrainedStatus = ConvertTo-WinGetAvailabilityStatus -CommandFound $false -LanguageMode "ConstrainedLanguage"
    if ($constrainedStatus.Installed -or $constrainedStatus.Status -ne "ConstrainedLanguage" -or $constrainedStatus.CanRepair) {
        Add-Failure "WinGet availability classifier did not classify constrained language mode as non-repairable."
    }
    $brokenStatus = ConvertTo-WinGetAvailabilityStatus -CommandFound $true -Path "C:\Windows\winget.exe" -ErrorOutput @("App Installer registration failed. Class not registered.") -ExitCode 1 -LanguageMode "FullLanguage"
    if ($brokenStatus.Installed -or $brokenStatus.Status -ne "BrokenRegistration" -or -not $brokenStatus.CanRepair -or $brokenStatus.Blocker -ne "AppInstallerRegistration") {
        Add-Failure "WinGet availability classifier did not classify broken App Installer registration as repairable."
    }

    $stableReadiness = Get-WinGetClientReadiness -AvailabilityStatus (New-WinGetAvailabilityStatus -Status "Available" -Installed $true -Version "v1.28.240" -Path "winget")
    if ($stableReadiness.Channel -ne "Stable" -or $stableReadiness.IsStale -or $stableReadiness.Features.CleanOutputNoProgress -or $stableReadiness.Features.SourcePriority) {
        Add-Failure "WinGet readiness did not classify v1.28.240 as stable without 1.29 feature gates."
    }
    $prereleaseReadiness = Get-WinGetClientReadiness -AvailabilityStatus (New-WinGetAvailabilityStatus -Status "Available" -Installed $true -Version "v1.29.280" -Path "winget")
    if ($prereleaseReadiness.Channel -ne "Prerelease" -or -not $prereleaseReadiness.IsPrerelease -or -not $prereleaseReadiness.Features.CleanOutputNoProgress -or -not $prereleaseReadiness.Features.SourcePriority) {
        Add-Failure "WinGet readiness did not classify v1.29.280 as prerelease with 1.29 feature gates."
    }
    $oldReadiness = Get-WinGetClientReadiness -AvailabilityStatus (New-WinGetAvailabilityStatus -Status "Available" -Installed $true -Version "v1.4.10173" -Path "winget")
    $oldReadinessDetail = $oldReadiness.Detail -join "`n"
    if ($oldReadiness.Channel -ne "Old" -or -not $oldReadiness.IsStale -or $oldReadiness.Warnings.Count -lt 1 -or $oldReadinessDetail -notmatch "Update command:") {
        Add-Failure "WinGet readiness did not classify old clients with a stale warning and update command."
    }
    $unknownReadiness = Get-WinGetClientReadiness -AvailabilityStatus (New-WinGetAvailabilityStatus -Status "Available" -Installed $true -Version "winget-preview" -Path "winget")
    $unknownReadinessDetail = $unknownReadiness.Detail -join "`n"
    if ($unknownReadiness.Channel -ne "Unknown" -or $unknownReadiness.Warnings.Count -lt 1 -or $unknownReadinessDetail -notmatch "Repair command:") {
        Add-Failure "WinGet readiness did not classify unparsable versions with warnings and repair command detail."
    }

    if (Test-WinGetCleanOutputSupported -VersionText "v1.28.240") {
        Add-Failure "WinGet clean-output support should be disabled for v1.28.240."
    }
    if (-not (Test-WinGetCleanOutputSupported -VersionText "v1.29.280")) {
        Add-Failure "WinGet clean-output support should be enabled for v1.29.280."
    }

    # R-021: fixture-based parser coverage.
    $fixtureRoot = Join-Path $PSScriptRoot "fixtures\winget"
    if (!(Test-Path $fixtureRoot)) {
        Add-Failure "Missing fixture directory '$fixtureRoot'."
    } else {
        function Get-Fixture {
            param([string]$Name)
            $path = Join-Path $fixtureRoot $Name
            if (!(Test-Path $path)) { throw "Missing fixture '$Name'." }
            return Get-Content -Path $path -Raw
        }

        $installSuccess = Get-Fixture "install-success-en.txt"
        if ((Get-WinGetOperationStatus -ExitCode 0 -StdOut $installSuccess -StdErr "" -Cancelled $false) -ne 'SUCCESS') {
            Add-Failure "install-success-en.txt fixture should classify as SUCCESS."
        }

        $uptodateEn = Get-Fixture "upgrade-uptodate-en.txt"
        $signal = 'None'
        $status = Get-WinGetOperationStatus -ExitCode 0 -StdOut $uptodateEn -StdErr "" -Cancelled $false -Signal ([ref]$signal)
        if ($status -ne 'UP TO DATE') {
            Add-Failure "upgrade-uptodate-en.txt fixture should classify as UP TO DATE."
        }

        # Locale-independence: German/Spanish fixtures should classify on the HRESULT alone.
        $uptodateDe = Get-Fixture "upgrade-uptodate-de.txt"
        $signal = 'None'
        $status = Get-WinGetOperationStatus -ExitCode -1978335189 -StdOut $uptodateDe -StdErr "" -Cancelled $false -Signal ([ref]$signal)
        if ($status -ne 'UP TO DATE' -or $signal -ne 'ExitCode') {
            Add-Failure "German up-to-date fixture should classify as UP TO DATE via ExitCode, got '$status'/'$signal'."
        }
        $uptodateEs = Get-Fixture "upgrade-uptodate-es.txt"
        $signal = 'None'
        $status = Get-WinGetOperationStatus -ExitCode -1978335190 -StdOut $uptodateEs -StdErr "" -Cancelled $false -Signal ([ref]$signal)
        if ($status -ne 'UP TO DATE' -or $signal -ne 'ExitCode') {
            Add-Failure "Spanish up-to-date fixture should classify as UP TO DATE via ExitCode, got '$status'/'$signal'."
        }

        $installFailure = Get-Fixture "install-failure-en.txt"
        if ((Get-WinGetOperationStatus -ExitCode 1603 -StdOut $installFailure -StdErr "" -Cancelled $false) -ne 'FAILED') {
            Add-Failure "install-failure-en.txt fixture should classify as FAILED."
        }

        $pinBlocking = Get-WinGetPinStatusFromText -Text (Get-Fixture "pin-list-blocking.txt") -PackageId "Google.Chrome"
        if (-not $pinBlocking.IsPinned -or $pinBlocking.PinType -ne 'Blocking' -or $pinBlocking.Signal -ne 'Column') {
            Add-Failure "pin-list-blocking.txt fixture should classify as Blocking via Column signal."
        }
        $pinGating = Get-WinGetPinStatusFromText -Text (Get-Fixture "pin-list-gating.txt") -PackageId "Mozilla.Firefox"
        if (-not $pinGating.IsPinned -or $pinGating.PinType -ne 'Gating' -or $pinGating.Signal -ne 'Column') {
            Add-Failure "pin-list-gating.txt fixture should classify as Gating via Column signal."
        }
        $pinPinning = Get-WinGetPinStatusFromText -Text (Get-Fixture "pin-list-pinning.txt") -PackageId "7zip.7zip"
        if (-not $pinPinning.IsPinned -or $pinPinning.PinType -ne 'Pinned' -or $pinPinning.Signal -ne 'Column') {
            Add-Failure "pin-list-pinning.txt fixture should classify as Pinned via Column signal."
        }
        $pinEmpty = Get-WinGetPinStatusFromText -Text (Get-Fixture "pin-list-empty.txt") -PackageId "Google.Chrome"
        if ($pinEmpty.IsPinned -or $pinEmpty.PinType -ne 'None') {
            Add-Failure "pin-list-empty.txt fixture should classify as not pinned."
        }

        $listText = Get-Fixture "list-updates-available.txt"
        $listRecords = ConvertFrom-WinGetListText -Text $listText -PackageIds @("Google.Chrome", "Mozilla.Firefox") -ScannedAtUtc "2026-05-17T00:00:00.0000000Z"
        if (-not $listRecords.ContainsKey("Google.Chrome") -or $listRecords["Google.Chrome"].AvailableVersion -ne "125.0") {
            Add-Failure "list-updates-available.txt fixture should expose Google.Chrome's available version."
        }
        if (-not $listRecords.ContainsKey("Mozilla.Firefox") -or $listRecords["Mozilla.Firefox"].IsUpdateAvailable) {
            Add-Failure "list-updates-available.txt fixture should mark Mozilla.Firefox as up to date."
        }

        $showFull = Get-Fixture "show-full-en.txt"
        if ((Get-WinGetShowField -Text $showFull -Label "Publisher") -ne "Google LLC") {
            Add-Failure "show-full-en.txt fixture should expose Publisher."
        }
        if ((Get-WinGetShowField -Text $showFull -Label "Installer Type") -ne "msi") {
            Add-Failure "show-full-en.txt fixture should expose indented Installer Type."
        }
        if ((Get-WinGetShowField -Text $showFull -Label "Installer SHA256") -ne "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa") {
            Add-Failure "show-full-en.txt fixture should expose indented Installer SHA256."
        }

        # Column-boundary collision: a package id that is a strict substring of
        # another row's id (Test vs TestTools.Pro) must classify the correct
        # row. Without word-boundary anchoring the parser would assign
        # TestTools.Pro's version to Test.
        $collisionText = Get-Fixture "list-name-collision.txt"
        $collisionRecords = ConvertFrom-WinGetListText -Text $collisionText -PackageIds @("Test", "TestTools.Pro") -ScannedAtUtc "2026-05-18T00:00:00.0000000Z"
        if (-not $collisionRecords.ContainsKey("Test") -or $collisionRecords["Test"].InstalledVersion -ne "1.0.0") {
            Add-Failure "list-name-collision.txt fixture: 'Test' package version was not isolated from TestTools.Pro."
        }
        if (-not $collisionRecords.ContainsKey("TestTools.Pro") -or $collisionRecords["TestTools.Pro"].InstalledVersion -ne "2.0.0") {
            Add-Failure "list-name-collision.txt fixture: 'TestTools.Pro' row was not parsed correctly."
        }
        # And the helper itself: substring-only matches do not count.
        if ((Find-WinGetPackageIdColumn -Line "Other Test       Test            1.0.0             winget" -PackageId "TestTools") -ne -1) {
            Add-Failure "Find-WinGetPackageIdColumn returned a positive index for a non-token substring."
        }
        if ((Find-WinGetPackageIdColumn -Line "Other Test       Test            1.0.0             winget" -PackageId "Test") -lt 0) {
            Add-Failure "Find-WinGetPackageIdColumn did not find a real token-boundary match."
        }
    }

    # Atomic file write: write to a path, kill the temp file mid-flight is not
    # representative without race injection, so just verify that the helper
    # writes the destination and leaves no .tmp siblings on success.
    $atomicDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-atomic-test-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $atomicDir -Force | Out-Null
    try {
        $atomicTarget = Join-Path $atomicDir "atomic.json"
        Set-WingetterFileAtomic -Path $atomicTarget -Content '{"ok":true}' -Encoding UTF8
        if (-not (Test-Path $atomicTarget)) { Add-Failure "Set-WingetterFileAtomic did not write the target file." }
        $stragglers = @(Get-ChildItem -Path $atomicDir -Filter ".*.tmp" -Force -ErrorAction SilentlyContinue)
        if ($stragglers.Count -gt 0) { Add-Failure "Set-WingetterFileAtomic left $($stragglers.Count) temp file(s) behind." }
    } finally {
        Remove-Item -Path $atomicDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    $upgradeArgs = New-WinGetPackageOperationArguments -Action "upgrade" -PackageId "Google.Chrome" -Silent $true -AcceptAgreements $true -IncludePinned $true
    if ($upgradeArgs -notcontains "--include-pinned") {
        Add-Failure "Upgrade arguments did not include --include-pinned when requested."
    }
    $installArgs = New-WinGetPackageOperationArguments -Action "install" -PackageId "Google.Chrome" -Silent $false -AcceptAgreements $false -IncludePinned $true
    if ($installArgs -contains "--include-pinned") {
        Add-Failure "Install arguments unexpectedly included --include-pinned."
    }
    $sourceArgs = New-WinGetPackageOperationArguments -Action "install" -PackageId "Internal.Tool" -SourceName "corp" -Silent $false -AcceptAgreements $true -IncludePinned $false
    if ($sourceArgs -notcontains "--source" -or $sourceArgs -notcontains "corp") {
        Add-Failure "Install arguments did not include an explicit source."
    }
    $legacyArgs = New-WinGetPackageOperationArguments -Action "install" -PackageId "Google.Chrome" -Silent $false -AcceptAgreements $false -IncludePinned $false -WinGetVersion "v1.28.240"
    if ($legacyArgs -contains "--no-progress") {
        Add-Failure "WinGet 1.28 install arguments unexpectedly included --no-progress."
    }
    $cleanArgs = New-WinGetPackageOperationArguments -Action "install" -PackageId "Google.Chrome" -Silent $false -AcceptAgreements $false -IncludePinned $false -WinGetVersion "v1.29.280"
    if ($cleanArgs -notcontains "--no-progress") {
        Add-Failure "WinGet 1.29 install arguments did not include --no-progress."
    }
    $optionArgs = New-WinGetPackageOperationArguments `
        -Action "install" `
        -PackageId "Example.Tool" `
        -SourceName "corp" `
        -Silent $true `
        -AcceptAgreements $true `
        -IncludePinned $false `
        -InstallOptions ([PSCustomObject]@{
            Version       = "1.2.3"
            Scope         = "machine"
            Architecture  = "x64"
            InstallerType = "msi"
            Locale        = "en-US"
            Location      = "C:\Program Files\Example Tool"
            Custom        = "/NoDesktopShortcut"
        })
    foreach ($expectedOptionArg in @("--version", "1.2.3", "--scope", "machine", "--architecture", "x64", "--installer-type", "msi", "--locale", "en-US", "--location", "C:\Program Files\Example Tool", "--custom", "/NoDesktopShortcut")) {
        if ($optionArgs -notcontains $expectedOptionArg) {
            Add-Failure "Install arguments with options did not include '$expectedOptionArg'."
        }
    }
    $optionCommand = "winget " + (Join-ProcessArguments -Arguments $optionArgs)
    if ($optionCommand -notlike '*--location "C:\Program Files\Example Tool"*') {
        Add-Failure "Install command preview did not quote a location containing spaces: $optionCommand"
    }
    $unsafeOptionsRejected = $false
    try {
        New-WinGetPackageOperationArguments -Action "install" -PackageId "Bad.Tool" -Silent $false -AcceptAgreements $false -IncludePinned $false -InstallOptions ([PSCustomObject]@{ Override = "/danger" }) | Out-Null
    } catch {
        $unsafeOptionsRejected = ($_.Exception.Message -match "not supported")
    }
    if (-not $unsafeOptionsRejected) {
        Add-Failure "WinGet operation arguments accepted unsafe Override install options."
    }
    $legacyListArgs = New-WinGetListArguments -SourceName "winget" -WinGetVersion "v1.28.240"
    if ($legacyListArgs -contains "--no-progress" -or $legacyListArgs -contains "--sort") {
        Add-Failure "WinGet 1.28 list arguments unexpectedly included clean-output/sort arguments."
    }
    $cleanListArgs = New-WinGetListArguments -SourceName "winget" -WinGetVersion "v1.29.280"
    foreach ($expectedListArg in @("--no-progress", "--sort", "name", "--ascending")) {
        if ($cleanListArgs -notcontains $expectedListArg) {
            Add-Failure "WinGet 1.29 list arguments did not include '$expectedListArg'."
        }
    }

    $policy = [PSCustomObject]@{
        CorporateMode        = $true
        RequireAllowedSource = $true
        AllowedSources       = @([PSCustomObject]@{ Name = "winget"; Type = "Microsoft.PreIndexed.Package"; Argument = ""; TrustLevel = "Trusted"; Explicit = $false; Private = $false; Header = "" })
        PrivateSources       = @()
    }
    $installedRecords = @{
        "Google.Chrome" = [PSCustomObject]@{
            PackageId = "Google.Chrome"; InstalledVersion = "124.0"; AvailableVersion = "125.0"; IsUpdateAvailable = $true
            Source = "winget"; Scope = "machine"; DetectionMethod = "fixture"; ScannedAtUtc = "2026-06-27T00:00:00.0000000Z"
        }
        "Mozilla.Firefox" = [PSCustomObject]@{
            PackageId = "Mozilla.Firefox"; InstalledVersion = "115.0"; AvailableVersion = ""; IsUpdateAvailable = $false
            Source = "winget"; Scope = "user"; DetectionMethod = "fixture"; ScannedAtUtc = "2026-06-27T00:00:00.0000000Z"
        }
    }
    $pinStatuses = @{
        "Google.Chrome" = [PSCustomObject]@{ PackageId = "Google.Chrome"; IsPinned = $true; PinType = "Blocking"; Summary = "Blocking pin" }
    }
    $planPackages = @(
        [PSCustomObject]@{ Name = "Google Chrome"; WingetId = "Google.Chrome"; SourceName = "winget" },
        [PSCustomObject]@{ Name = "Mozilla Firefox"; WingetId = "Mozilla.Firefox"; SourceName = "winget" },
        [PSCustomObject]@{ Name = "Internal Tool"; WingetId = "Internal.Tool"; SourceName = "corp" },
        [PSCustomObject]@{ Name = "New App"; WingetId = "Example.NewApp"; SourceName = "winget"; InstallOptions = [PSCustomObject]@{ Scope = "user"; Architecture = "x64" } }
    )
    $installPlan = New-WingetterRunPlan -Action "install" -SelectedPackages $planPackages -InstalledRecords $installedRecords -SourcePolicy $policy -PinStatusesById $pinStatuses -IncludePinned $false -ProfileName "Fixture"
    $installById = @{}
    foreach ($item in @($installPlan.Packages)) { $installById[[string]$item.PackageId] = $item }
    if (!$installById["Example.NewApp"].CanRun -or $installById["Example.NewApp"].PlannedAction -ne "Install") {
        Add-Failure "Install preflight plan did not mark a new allowed package as runnable."
    }
    if ($installById["Example.NewApp"].InstallOptions.Scope -ne "user" -or $installById["Example.NewApp"].InstallOptionsSummary -notmatch "Architecture=x64") {
        Add-Failure "Install preflight plan did not preserve per-package install options."
    }
    if ($installById["Mozilla.Firefox"].CanRun -or $installById["Mozilla.Firefox"].Status -ne "INSTALLED_CURRENT") {
        Add-Failure "Install preflight plan did not skip an already installed/current package."
    }
    if ($installById["Internal.Tool"].CanRun -or $installById["Internal.Tool"].Status -ne "BLOCKED" -or $installById["Internal.Tool"].SourceAllowed) {
        Add-Failure "Install preflight plan did not block a disallowed corporate source package."
    }

    $upgradePlan = New-WingetterRunPlan -Action "upgrade" -SelectedPackages $planPackages -InstalledRecords $installedRecords -SourcePolicy $policy -PinStatusesById $pinStatuses -IncludePinned $false -ProfileName "Fixture"
    $upgradeById = @{}
    foreach ($item in @($upgradePlan.Packages)) { $upgradeById[[string]$item.PackageId] = $item }
    if ($upgradeById["Google.Chrome"].CanRun -or $upgradeById["Google.Chrome"].Status -ne "PINNED") {
        Add-Failure "Upgrade preflight plan did not skip a pinned update when include-pinned is disabled."
    }
    if ($upgradeById["Mozilla.Firefox"].CanRun -or $upgradeById["Mozilla.Firefox"].Status -ne "CURRENT") {
        Add-Failure "Upgrade preflight plan did not skip a current installed package."
    }
    $includePinnedPlan = New-WingetterRunPlan -Action "upgrade" -SelectedPackages @($planPackages[0]) -InstalledRecords $installedRecords -SourcePolicy $policy -PinStatusesById $pinStatuses -IncludePinned $true -ProfileName "Fixture"
    if (-not $includePinnedPlan.Packages[0].CanRun -or $includePinnedPlan.Packages[0].PlannedAction -ne "Upgrade") {
        Add-Failure "Upgrade preflight plan did not allow a pinned update when include-pinned is enabled."
    }
    $planPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-plan-" + [System.Guid]::NewGuid().ToString("N") + ".json")
    try {
        Export-WingetterRunPlan -RunPlan $installPlan -FilePath $planPath | Out-Null
        $savedPlan = Get-Content -Path $planPath -Raw | ConvertFrom-Json
        if ($savedPlan.Schema -ne "Wingetter.RunPlan.v1" -or $savedPlan.Summary.blocked -lt 1) {
            Add-Failure "Exported preflight plan JSON did not preserve schema and summary."
        }
    } finally {
        Remove-Item -Path $planPath -Force -ErrorAction SilentlyContinue
    }

    $showSample = @"
Version: 1.2.3
Publisher: Example Publisher
Installer:
  Installer Type: wix
  Installer Url: https://example.com/app.msi
  Installer SHA256: abcdef
"@
    if ((Get-WinGetShowField -Text $showSample -Label "Publisher") -ne "Example Publisher") {
        Add-Failure "Get-WinGetShowField did not parse Publisher."
    }
    if ((Get-WinGetShowField -Text $showSample -Label "Installer Url") -ne "https://example.com/app.msi") {
        Add-Failure "Get-WinGetShowField did not parse indented Installer Url."
    }

    $objectPackage = [PSCustomObject]@{
        Id                = "Google.Chrome"
        Name              = "Google Chrome"
        InstalledVersion  = "124.0"
        IsUpdateAvailable = $true
        Source            = "winget"
        AvailableVersions = @("125.0", "124.0")
    }
    $objectRecord = ConvertFrom-WinGetPackageObject -Package $objectPackage -ScannedAtUtc "2026-05-17T00:00:00.0000000Z"
    if ($objectRecord.PackageId -ne "Google.Chrome" -or $objectRecord.InstalledVersion -ne "124.0" -or $objectRecord.AvailableVersion -ne "125.0" -or $objectRecord.Source -ne "winget") {
        Add-Failure "ConvertFrom-WinGetPackageObject did not preserve object-based installed package fields."
    }

    $listSample = @"
Name            Id               Version Available Source
----------------------------------------------------------
Google Chrome   Google.Chrome    124.0   125.0     winget
Mozilla Firefox Mozilla.Firefox  123.0             winget
"@
    $listRecords = ConvertFrom-WinGetListText -Text $listSample -PackageIds @("Google.Chrome", "Mozilla.Firefox") -ScannedAtUtc "2026-05-17T00:00:00.0000000Z"
    if (!$listRecords.ContainsKey("Google.Chrome") -or $listRecords["Google.Chrome"].InstalledVersion -ne "124.0" -or $listRecords["Google.Chrome"].AvailableVersion -ne "125.0") {
        Add-Failure "ConvertFrom-WinGetListText did not parse installed and available versions."
    }

    $pinSample = @"
Name          Id            Version Pin type
---------------------------------------------
Google Chrome Google.Chrome 124.0   Blocking
"@
    $pinStatus = Get-WinGetPinStatusFromText -Text $pinSample -PackageId "Google.Chrome"
    if (!$pinStatus.IsPinned -or $pinStatus.PinType -ne "Blocking") {
        Add-Failure "Get-WinGetPinStatusFromText did not parse a blocking pin."
    }
    $noPinStatus = Get-WinGetPinStatusFromText -Text "There are no pins configured." -PackageId "Google.Chrome"
    if ($noPinStatus.IsPinned -or $noPinStatus.PinType -ne "None") {
        Add-Failure "Get-WinGetPinStatusFromText did not parse an unpinned package."
    }

    $bootstrapLogPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-bootstrap-test-" + [System.Guid]::NewGuid().ToString("N") + ".jsonl")
    try {
        Write-WinGetBootstrapLog -Path $bootstrapLogPath -Step "test" -Status "ok" -Message "bootstrap log smoke" -Data @{ ManualDownloads = "none" }
        $entry = Get-Content -Path $bootstrapLogPath -Raw | ConvertFrom-Json
        if ($entry.Step -ne "test" -or $entry.Data.ManualDownloads -ne "none") {
            Add-Failure "Write-WinGetBootstrapLog did not write the expected JSONL entry."
        }
    } finally {
        Remove-Item -Path $bootstrapLogPath -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    Write-Host "WinGet runner validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "WinGet runner validation passed."
