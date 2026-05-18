# ============================================================================
# WINGET DETECTION AND INSTALLATION
# ============================================================================

function Test-WinGet {
    try {
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetPath) {
            $version = (winget --version) 2>$null
            return @{ Installed = $true; Version = $version; Path = $wingetPath.Source }
        }
    } catch { }
    return @{ Installed = $false; Version = $null; Path = $null }
}

function New-WinGetBootstrapLogPath {
    $root = Join-Path $env:APPDATA "Wingetter\logs"
    if (!(Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    $path = Join-Path $root ("winget-bootstrap-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".jsonl")
    $Script:LastBootstrapLogPath = $path
    return $path
}

function Write-WinGetBootstrapLog {
    param(
        [string]$Path,
        [string]$Step,
        [string]$Status,
        [string]$Message,
        [hashtable]$Data = @{}
    )
    $entry = [ordered]@{
        TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
        Step         = $Step
        Status       = $Status
        Message      = $Message
        Data         = $Data
    }
    $entry | ConvertTo-Json -Depth 6 -Compress | Add-Content -Path $Path -Encoding UTF8
}

function Install-WinGet {
    $wingetStatus = Test-WinGet
    if ($wingetStatus.Installed) { return $true }

    $logPath = New-WinGetBootstrapLogPath
    Write-WinGetBootstrapLog -Path $logPath -Step "start" -Status "info" -Message "Starting WinGet bootstrap." -Data @{
        Method = "App Installer registration, then Microsoft.WinGet.Client Repair-WinGetPackageManager fallback"
        ManualDownloads = "none"
    }

    try {
        Write-WinGetBootstrapLog -Path $logPath -Step "register-app-installer" -Status "start" -Message "Requesting App Installer package registration by family name." -Data @{
            Command = "Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
            Source = "Windows App Installer registration"
        }
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
        Write-WinGetBootstrapLog -Path $logPath -Step "register-app-installer" -Status "ok" -Message "App Installer registration command completed."
    } catch {
        Write-WinGetBootstrapLog -Path $logPath -Step "register-app-installer" -Status "error" -Message $_.Exception.Message
    }

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Start-Sleep -Seconds 2
    $wingetStatus = Test-WinGet
    if ($wingetStatus.Installed) {
        Write-WinGetBootstrapLog -Path $logPath -Step "verify" -Status "ok" -Message "WinGet is available after App Installer registration." -Data $wingetStatus
        return $true
    }

    try {
        Write-WinGetBootstrapLog -Path $logPath -Step "install-module" -Status "start" -Message "Ensuring Microsoft.WinGet.Client module from PowerShell Gallery." -Data @{
            Module = "Microsoft.WinGet.Client"
            Repository = "PSGallery"
            Verification = "Import-Module and Repair-WinGetPackageManager availability"
        }
        if (!(Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null
        }
        if (!(Get-Module -ListAvailable -Name Microsoft.WinGet.Client)) {
            Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope CurrentUser -AllowClobber -ErrorAction Stop | Out-Null
        }
        Import-Module Microsoft.WinGet.Client -Force -ErrorAction Stop
        $repair = Get-Command Repair-WinGetPackageManager -ErrorAction Stop
        Write-WinGetBootstrapLog -Path $logPath -Step "install-module" -Status "ok" -Message "Microsoft.WinGet.Client module is available." -Data @{
            RepairCommand = $repair.Source
        }

        Write-WinGetBootstrapLog -Path $logPath -Step "repair-winget" -Status "start" -Message "Running Repair-WinGetPackageManager -Force -Latest."
        Repair-WinGetPackageManager -Force -Latest -ErrorAction Stop
        Write-WinGetBootstrapLog -Path $logPath -Step "repair-winget" -Status "ok" -Message "Repair-WinGetPackageManager completed."
    } catch {
        Write-WinGetBootstrapLog -Path $logPath -Step "repair-winget" -Status "error" -Message $_.Exception.Message
    }

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Start-Sleep -Seconds 2
    $wingetStatus = Test-WinGet
    if ($wingetStatus.Installed) {
        Write-WinGetBootstrapLog -Path $logPath -Step "verify" -Status "ok" -Message "WinGet is available after repair." -Data $wingetStatus
        return $true
    }

    try {
        Write-WinGetBootstrapLog -Path $logPath -Step "store-fallback" -Status "start" -Message "Opening Microsoft Store App Installer page as final manual fallback." -Data @{
            Uri = "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
        }
        Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
    } catch {
        Write-WinGetBootstrapLog -Path $logPath -Step "store-fallback" -Status "error" -Message $_.Exception.Message
    }

    Write-WinGetBootstrapLog -Path $logPath -Step "verify" -Status "failed" -Message "WinGet was not available after bootstrap attempts."
    return $false
}

function Join-ProcessArguments {
    param([string[]]$Arguments)
    @($Arguments | ForEach-Object {
        $arg = [string]$_
        if ($arg -match '[\s"]') {
            '"' + ($arg -replace '\\(?=")', '\\' -replace '"', '\"') + '"'
        } else {
            $arg
        }
    }) -join " "
}

function Set-ProcessArguments {
    param(
        [System.Diagnostics.ProcessStartInfo]$ProcessStartInfo,
        [string[]]$Arguments
    )
    $argumentListProperty = [System.Diagnostics.ProcessStartInfo].GetProperty("ArgumentList")
    if ($argumentListProperty) {
        foreach ($argument in $Arguments) {
            [void]$ProcessStartInfo.ArgumentList.Add($argument)
        }
    } else {
        $ProcessStartInfo.Arguments = Join-ProcessArguments -Arguments $Arguments
    }
}

function Invoke-WinGetCapture {
    param(
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 20
    )

    $stdout = ""
    $stderr = ""
    $exitCode = -1
    $timedOut = $false

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "winget"
        Set-ProcessArguments -ProcessStartInfo $psi -Arguments $Arguments
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            try { $proc.Kill() } catch {}
            try { $proc.WaitForExit() } catch {}
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = if ($timedOut) { -1 } else { $proc.ExitCode }
    } catch {
        $stderr = $_.Exception.Message
    }

    return [PSCustomObject]@{
        StdOut   = $stdout
        StdErr   = $stderr
        ExitCode = $exitCode
        TimedOut = $timedOut
    }
}

function Get-SafeFileName {
    param([string]$Value)
    $safe = $Value
    foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safe = $safe.Replace([string]$char, "_")
    }
    return ($safe -replace '[^\w\.-]', '_')
}

function New-WingetterRunLogDirectory {
    param([string]$Action)
    $root = Join-Path $env:APPDATA "Wingetter\logs"
    if (!(Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $path = Join-Path $root "$stamp-$Action"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Get-WinGetLogDirectory {
    $path = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"
    if (Test-Path $path) { return $path }
    return $null
}

function Get-TextExcerpt {
    param([string]$Text, [int]$MaxLength = 1000)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $clean = ($Text -replace '\s+', ' ').Trim()
    if ($clean.Length -le $MaxLength) { return $clean }
    return $clean.Substring(0, $MaxLength)
}

# Documented WinGet HRESULT exit codes that classify as a non-failure no-op rather
# than a real install/upgrade failure. Values come from the Microsoft Learn
# "winget return codes" reference and are locale-independent across WinGet UI
# languages. PowerShell surfaces $proc.ExitCode as an Int32, so the hex literals
# below (which the parser stores as Int32) compare equal to the signed forms a
# WinGet process actually returns; the inline comment lists the signed form for
# reviewers.
$Script:WinGetUpToDateExitCodes = @{
    # APPINSTALLER_CLI_ERROR_NO_APPLICABLE_UPDATE_FOUND (signed: -1978335189).
    0x8A15002B = 'NO_APPLICABLE_UPDATE_FOUND'
    # APPINSTALLER_CLI_ERROR_PACKAGE_ALREADY_INSTALLED (signed: -1978335135).
    0x8A150061 = 'PACKAGE_ALREADY_INSTALLED'
    # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE (signed: -1978335190).
    0x8A15002A = 'UPDATE_NOT_APPLICABLE'
}

function Get-WinGetExitCodeMeaning {
    param([int]$ExitCode)
    if ($Script:WinGetUpToDateExitCodes.ContainsKey($ExitCode)) {
        return $Script:WinGetUpToDateExitCodes[$ExitCode]
    }
    return $null
}

function Get-WinGetOperationStatus {
    param(
        [int]$ExitCode,
        [string]$StdOut,
        [string]$StdErr,
        [bool]$Cancelled,
        [ref]$Signal
    )
    if ($PSBoundParameters.ContainsKey('Signal')) { $Signal.Value = 'None' }
    if ($Cancelled) {
        if ($PSBoundParameters.ContainsKey('Signal')) { $Signal.Value = 'Cancelled' }
        return "CANCELLED"
    }

    $meaning = Get-WinGetExitCodeMeaning -ExitCode $ExitCode
    if ($meaning) {
        if ($PSBoundParameters.ContainsKey('Signal')) { $Signal.Value = 'ExitCode' }
        return "UP TO DATE"
    }

    $combined = "$StdOut`n$StdErr"
    if ($combined -match "already installed|No available upgrade|No newer package|No applicable update") {
        if ($PSBoundParameters.ContainsKey('Signal')) { $Signal.Value = 'Text' }
        return "UP TO DATE"
    }
    if ($ExitCode -eq 0) {
        if ($PSBoundParameters.ContainsKey('Signal')) { $Signal.Value = 'ExitCode' }
        return "SUCCESS"
    }
    if ($PSBoundParameters.ContainsKey('Signal')) { $Signal.Value = 'ExitCode' }
    return "FAILED"
}

function New-WinGetPackageOperationArguments {
    param(
        [string]$Action,
        [string]$PackageId,
        [string]$SourceName = "",
        [bool]$Silent,
        [bool]$AcceptAgreements,
        [bool]$IncludePinned
    )

    $arguments = @($Action, "--id", $PackageId, "--exact", "--verbose-logs", "--disable-interactivity")
    if (![string]::IsNullOrWhiteSpace($SourceName) -and $Action -ne "uninstall") {
        $arguments += "--source"
        $arguments += $SourceName
    }
    if ($Silent) { $arguments += "--silent" }
    if ($AcceptAgreements) {
        $arguments += "--accept-package-agreements"
        $arguments += "--accept-source-agreements"
    }
    if ($Action -eq "upgrade" -and $IncludePinned) {
        $arguments += "--include-pinned"
    }
    return [string[]]$arguments
}

function Invoke-WinGetPackageOperation {
    param(
        [string]$Action,
        [string]$PackageId,
        [string]$PackageName,
        [string]$SourceName = "",
        [bool]$Silent,
        [bool]$AcceptAgreements,
        [bool]$IncludePinned,
        [string]$RunLogDir,
        [scriptblock]$ShouldCancel = { $false },
        [scriptblock]$PumpUi = {}
    )

    $arguments = New-WinGetPackageOperationArguments -Action $Action -PackageId $PackageId -SourceName $SourceName -Silent $Silent -AcceptAgreements $AcceptAgreements -IncludePinned $IncludePinned

    $safeId = Get-SafeFileName -Value $PackageId
    $stamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
    $stdoutPath = Join-Path $RunLogDir "$stamp-$safeId.stdout.log"
    $stderrPath = Join-Path $RunLogDir "$stamp-$safeId.stderr.log"
    $resultPath = Join-Path $RunLogDir "$stamp-$safeId.result.json"

    $stdout = ""
    $stderr = ""
    $exitCode = $null
    $cancelled = $false

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "winget"
        Set-ProcessArguments -ProcessStartInfo $psi -Arguments $arguments
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()

        while (-not $proc.HasExited) {
            & $PumpUi
            Start-Sleep -Milliseconds 100
            if (& $ShouldCancel) {
                $cancelled = $true
                try { $proc.Kill() } catch {}
                break
            }
        }

        try { $proc.WaitForExit() } catch {}
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = if ($cancelled) { -1 } else { $proc.ExitCode }
    } catch {
        $stderr = $_.Exception.Message
        $exitCode = -1
    }

    Set-Content -Path $stdoutPath -Value $stdout -Encoding UTF8
    Set-Content -Path $stderrPath -Value $stderr -Encoding UTF8

    $signal = 'None'
    $status = Get-WinGetOperationStatus -ExitCode ([int]$exitCode) -StdOut $stdout -StdErr $stderr -Cancelled $cancelled -Signal ([ref]$signal)
    $exitCodeMeaning = Get-WinGetExitCodeMeaning -ExitCode ([int]$exitCode)
    $result = [ordered]@{
        TimestampUtc      = (Get-Date).ToUniversalTime().ToString("o")
        Action            = $Action
        PackageName       = $PackageName
        PackageId         = $PackageId
        SourceName        = $SourceName
        Command           = "winget " + (Join-ProcessArguments -Arguments $arguments)
        ExitCode          = $exitCode
        ExitCodeMeaning   = $exitCodeMeaning
        Status            = $status
        StatusSignal      = $signal
        Cancelled         = $cancelled
        StdOutPath        = $stdoutPath
        StdErrPath        = $stderrPath
        StdOutExcerpt     = Get-TextExcerpt -Text $stdout
        StdErrExcerpt     = Get-TextExcerpt -Text $stderr
        RunLogDir         = $RunLogDir
        WinGetLogDir      = Get-WinGetLogDirectory
        ResultPath        = $resultPath
    }
    $result | ConvertTo-Json -Depth 5 | Set-Content -Path $resultPath -Encoding UTF8

    return [PSCustomObject]$result
}

function Get-WinGetShowField {
    param([string]$Text, [string]$Label)
    $pattern = "(?im)^\s*$([regex]::Escape($Label)):\s*(?<value>.+?)\s*$"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups["value"].Value.Trim() }
    return ""
}

function Get-WinGetInstalledVersion {
    param(
        [string]$PackageId,
        [string]$SourceName = ""
    )

    $arguments = @("list", "--id", $PackageId, "--exact", "--disable-interactivity")
    if (![string]::IsNullOrWhiteSpace($SourceName)) {
        $arguments += "--source"
        $arguments += $SourceName
    }
    $capture = Invoke-WinGetCapture -Arguments $arguments -TimeoutSeconds 15
    if ($capture.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($capture.StdOut)) { return "" }

    foreach ($line in ($capture.StdOut -split "`r?`n")) {
        $index = $line.IndexOf($PackageId, [System.StringComparison]::OrdinalIgnoreCase)
        if ($index -ge 0) {
            $afterId = $line.Substring($index + $PackageId.Length).Trim()
            if ($afterId) {
                $parts = $afterId -split '\s+'
                if ($parts.Count -gt 0 -and $parts[0] -notmatch '^-+$') { return $parts[0] }
            }
        }
    }

    return ""
}

function Get-WingetterInstalledCachePath {
    $root = Join-Path $env:APPDATA "Wingetter"
    if (!(Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    return (Join-Path $root "installed-cache.json")
}

function ConvertFrom-WinGetPackageObject {
    param(
        [object]$Package,
        [string]$ScannedAtUtc,
        [string]$DetectionMethod = "Microsoft.WinGet.Client"
    )

    $availableVersions = @()
    $availableProperty = $Package.PSObject.Properties["AvailableVersions"]
    if ($availableProperty -and $availableProperty.Value) {
        $availableVersions = @($availableProperty.Value | ForEach-Object { [string]$_ })
    }

    $installedVersion = [string]$Package.InstalledVersion
    $availableVersion = ""
    $updateProperty = $Package.PSObject.Properties["IsUpdateAvailable"]
    $isUpdateAvailable = ($updateProperty -and [bool]$updateProperty.Value)
    if ($isUpdateAvailable -and $availableVersions.Count -gt 0) {
        $availableVersion = @($availableVersions | Where-Object { $_ -and $_ -ne $installedVersion } | Select-Object -First 1)
        if (!$availableVersion) { $availableVersion = $availableVersions[0] }
    }

    $scope = ""
    $scopeProperty = $Package.PSObject.Properties["Scope"]
    if ($scopeProperty -and $scopeProperty.Value) { $scope = [string]$scopeProperty.Value }

    [PSCustomObject]@{
        PackageId        = [string]$Package.Id
        Name             = [string]$Package.Name
        InstalledVersion = $installedVersion
        AvailableVersion = [string]$availableVersion
        Source           = [string]$Package.Source
        Scope            = $scope
        IsUpdateAvailable = [bool]$isUpdateAvailable
        DetectionMethod  = $DetectionMethod
        ScannedAtUtc     = $ScannedAtUtc
    }
}

function ConvertFrom-WinGetListText {
    param(
        [string]$Text,
        [string[]]$PackageIds,
        [string]$ScannedAtUtc
    )

    $records = @{}
    if ([string]::IsNullOrWhiteSpace($Text)) { return $records }

    foreach ($line in ($Text -split "`r?`n")) {
        foreach ($packageId in $PackageIds) {
            if ($records.ContainsKey($packageId)) { continue }
            $index = $line.IndexOf($packageId, [System.StringComparison]::OrdinalIgnoreCase)
            if ($index -lt 0) { continue }

            $name = $line.Substring(0, $index).Trim()
            $afterId = $line.Substring($index + $packageId.Length).Trim()
            if (!$afterId) { continue }
            $parts = @($afterId -split '\s+' | Where-Object { $_ })
            if ($parts.Count -eq 0 -or $parts[0] -match '^-+$') { continue }

            $installedVersion = [string]$parts[0]
            $source = ""
            $availableVersion = ""
            if ($parts.Count -ge 2) {
                $source = [string]$parts[$parts.Count - 1]
                if ($parts.Count -ge 3) { $availableVersion = [string]$parts[1] }
            }

            $records[$packageId] = [PSCustomObject]@{
                PackageId        = $packageId
                Name             = $name
                InstalledVersion = $installedVersion
                AvailableVersion = $availableVersion
                Source           = $source
                Scope            = ""
                IsUpdateAvailable = -not [string]::IsNullOrWhiteSpace($availableVersion)
                DetectionMethod  = "winget list"
                ScannedAtUtc     = $ScannedAtUtc
            }
        }
    }

    return $records
}

function Get-WinGetInstalledCatalogPackages {
    param(
        [string[]]$PackageIds,
        [string]$SourceName = ""
    )

    $scannedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    $packageIdSet = @{}
    foreach ($id in $PackageIds) { $packageIdSet[$id] = $true }

    $records = @{}
    $method = "Microsoft.WinGet.Client"
    $errorMessage = ""

    try {
        Import-Module Microsoft.WinGet.Client -Force -ErrorAction Stop
        foreach ($package in @(Get-WinGetPackage -ErrorAction Stop)) {
            $id = [string]$package.Id
            if ($packageIdSet.ContainsKey($id)) {
                $records[$id] = ConvertFrom-WinGetPackageObject -Package $package -ScannedAtUtc $scannedAtUtc -DetectionMethod $method
            }
        }
    } catch {
        $method = "winget list"
        $errorMessage = $_.Exception.Message
        try {
            $listSource = if ([string]::IsNullOrWhiteSpace($SourceName)) { "winget" } else { $SourceName }
            $capture = Invoke-WinGetCapture -Arguments @("list", "--source", $listSource, "--disable-interactivity") -TimeoutSeconds 45
            $records = ConvertFrom-WinGetListText -Text "$($capture.StdOut)`n$($capture.StdErr)" -PackageIds $PackageIds -ScannedAtUtc $scannedAtUtc
            if ($capture.ExitCode -ne 0 -and !$errorMessage) { $errorMessage = "winget list exited with code $($capture.ExitCode)." }
        } catch {
            $errorMessage = $_.Exception.Message
        }
    }

    $cachePath = Get-WingetterInstalledCachePath
    try {
        [ordered]@{
            scannedAtUtc    = $scannedAtUtc
            detectionMethod = $method
            sourceName      = $SourceName
            error           = $errorMessage
            packages        = @($records.Values)
        } | ConvertTo-Json -Depth 6 | Set-Content -Path $cachePath -Encoding UTF8
    } catch {}

    [PSCustomObject]@{
        Packages        = $records
        ScannedAtUtc    = $scannedAtUtc
        DetectionMethod = $method
        Error           = $errorMessage
        CachePath       = $cachePath
    }
}

function Get-WinGetPinTypeFromColumnValue {
    param([string]$Value)
    # The WinGet CLI emits non-localized pin-type tokens in the "Pin type" column
    # (winget-cli source: Pinning::PinType ToString). Compare on the token directly
    # so localization of surrounding prose ("There is a pinned package...") cannot
    # mis-classify the pin.
    $token = ($Value -as [string]).Trim()
    if ([string]::IsNullOrWhiteSpace($token)) { return "" }
    switch -Regex ($token) {
        '^(?i)Blocking$'         { return "Blocking" }
        '^(?i)Gating$'           { return "Gating" }
        '^(?i)PinnedByManifest$' { return "PinnedByManifest" }
        '^(?i)Pinning$'          { return "Pinned" }
        '^(?i)Pinned$'           { return "Pinned" }
        default                  { return "" }
    }
}

function Get-WinGetPinRowFromText {
    param(
        [string]$Text,
        [string]$PackageId
    )
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    foreach ($line in ($Text -split "`r?`n")) {
        $index = $line.IndexOf($PackageId, [System.StringComparison]::OrdinalIgnoreCase)
        if ($index -lt 0) { continue }
        $afterId = $line.Substring($index + $PackageId.Length).Trim()
        if ([string]::IsNullOrWhiteSpace($afterId)) { continue }
        $parts = @($afterId -split '\s+' | Where-Object { $_ -and $_ -notmatch '^-+$' })
        if ($parts.Count -lt 1) { continue }
        $pinTypeToken = $parts[$parts.Count - 1]
        return [PSCustomObject]@{
            Line         = $line
            PinTypeToken = [string]$pinTypeToken
            VersionToken = if ($parts.Count -ge 2) { [string]$parts[$parts.Count - 2] } else { "" }
        }
    }
    return $null
}

function Get-WinGetPinStatusFromText {
    param(
        [string]$Text,
        [string]$PackageId,
        [int]$ExitCode = 0,
        [bool]$TimedOut = $false
    )

    $combined = if ($null -eq $Text) { "" } else { $Text }
    $row = Get-WinGetPinRowFromText -Text $combined -PackageId $PackageId
    $isPinned = ($ExitCode -eq 0 -and $null -ne $row)
    $pinType = "None"
    $summary = "Not pinned"
    $signal = "None"

    if ($TimedOut) {
        $summary = "Pin lookup timed out"
        $signal = "Timeout"
    } elseif ($ExitCode -ne 0 -and -not $isPinned) {
        $summary = "Pin lookup failed"
        $signal = "ExitCode"
    } elseif ($isPinned) {
        $columnPinType = Get-WinGetPinTypeFromColumnValue -Value $row.PinTypeToken
        if ($columnPinType) {
            $pinType = $columnPinType
            $signal = "Column"
        } elseif ($combined -match "(?i)\bblocking\b") {
            $pinType = "Blocking"
            $signal = "Text"
        } elseif ($combined -match "(?i)\bgating\b") {
            $pinType = "Gating"
            $signal = "Text"
        } else {
            $pinType = "Pinned"
            $signal = "Text"
        }
        $summary = switch ($pinType) {
            "Blocking"          { "Blocking pin" }
            "Gating"            { "Version-gated pin" }
            "PinnedByManifest"  { "Manifest-pinned" }
            default             { "Pinned" }
        }
    }

    [PSCustomObject]@{
        PackageId = $PackageId
        IsPinned  = [bool]$isPinned
        PinType   = $pinType
        Summary   = $summary
        ExitCode  = $ExitCode
        Signal    = $signal
        Raw       = $combined
    }
}

function Get-WinGetPinStatus {
    param([string]$PackageId)

    $capture = Invoke-WinGetCapture -Arguments @("pin", "list", "--id", $PackageId, "--exact", "--disable-interactivity") -TimeoutSeconds 20
    $combined = "$($capture.StdOut)`n$($capture.StdErr)"
    return Get-WinGetPinStatusFromText -Text $combined -PackageId $PackageId -ExitCode $capture.ExitCode -TimedOut ([bool]$capture.TimedOut)
}

function Invoke-WinGetPinOperation {
    param(
        [string]$PackageId,
        [ValidateSet("Pin", "Block", "PinInstalled", "Remove")]
        [string]$Operation
    )

    switch ($Operation) {
        "Remove" {
            $arguments = @("pin", "remove", "--id", $PackageId, "--exact", "--disable-interactivity")
        }
        "Block" {
            $arguments = @("pin", "add", "--id", $PackageId, "--exact", "--blocking", "--force", "--accept-source-agreements", "--disable-interactivity")
        }
        "PinInstalled" {
            $arguments = @("pin", "add", "--id", $PackageId, "--exact", "--installed", "--force", "--accept-source-agreements", "--disable-interactivity")
        }
        default {
            $arguments = @("pin", "add", "--id", $PackageId, "--exact", "--force", "--accept-source-agreements", "--disable-interactivity")
        }
    }

    $capture = Invoke-WinGetCapture -Arguments $arguments -TimeoutSeconds 60
    $combined = "$($capture.StdOut)`n$($capture.StdErr)".Trim()
    [PSCustomObject]@{
        PackageId = $PackageId
        Operation = $Operation
        Command   = "winget " + (Join-ProcessArguments -Arguments $arguments)
        ExitCode  = $capture.ExitCode
        Success   = ($capture.ExitCode -eq 0 -and -not $capture.TimedOut)
        TimedOut  = [bool]$capture.TimedOut
        Output    = Get-TextExcerpt -Text $combined -MaxLength 600
    }
}

function Get-WinGetPackageDetails {
    param(
        [string]$PackageId,
        [string]$SourceName = ""
    )

    $arguments = @("show", "--id", $PackageId, "--exact", "--disable-interactivity", "--accept-source-agreements")
    if (![string]::IsNullOrWhiteSpace($SourceName)) {
        $arguments += "--source"
        $arguments += $SourceName
    }
    $capture = Invoke-WinGetCapture -Arguments $arguments -TimeoutSeconds 20
    $combined = "$($capture.StdOut)`n$($capture.StdErr)"
    $warnings = [System.Collections.ArrayList]::new()
    if ($capture.TimedOut) { [void]$warnings.Add("winget show timed out.") }
    if ($capture.ExitCode -ne 0) { [void]$warnings.Add("winget show exited with code $($capture.ExitCode).") }

    $publisher = Get-WinGetShowField -Text $combined -Label "Publisher"
    $source = Get-WinGetShowField -Text $combined -Label "Source"
    if (!$source) { $source = "winget" }
    $installerType = Get-WinGetShowField -Text $combined -Label "Installer Type"
    $installerUrl = Get-WinGetShowField -Text $combined -Label "Installer Url"
    if (!$installerUrl) { $installerUrl = Get-WinGetShowField -Text $combined -Label "Installer URL" }
    $sha256 = Get-WinGetShowField -Text $combined -Label "Installer SHA256"
    $homepage = Get-WinGetShowField -Text $combined -Label "Homepage"
    $version = Get-WinGetShowField -Text $combined -Label "Version"
    $installedVersion = Get-WinGetInstalledVersion -PackageId $PackageId -SourceName $SourceName

    foreach ($required in @(
        @{ Name = "publisher"; Value = $publisher },
        @{ Name = "installer type"; Value = $installerType },
        @{ Name = "installer URL"; Value = $installerUrl },
        @{ Name = "installer SHA256"; Value = $sha256 }
    )) {
        if ([string]::IsNullOrWhiteSpace($required.Value)) {
            [void]$warnings.Add("Missing $($required.Name) metadata.")
        }
    }

    [PSCustomObject]@{
        PackageId        = $PackageId
        SourceName       = $SourceName
        Publisher        = $publisher
        Source           = $source
        LatestVersion    = $version
        InstalledVersion = $installedVersion
        InstallerType    = $installerType
        InstallerUrl     = $installerUrl
        InstallerSha256  = $sha256
        Homepage         = $homepage
        Warnings         = [string[]]$warnings.ToArray([string])
        ExitCode         = $capture.ExitCode
    }
}
