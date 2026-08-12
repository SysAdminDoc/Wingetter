# ============================================================================
# WINGET DETECTION AND INSTALLATION
# ============================================================================

function ConvertTo-WinGetProbeText {
    param([object[]]$Parts = @())

    ($Parts | Where-Object { $null -ne $_ } | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            [string]$_.Exception.Message
        } else {
            [string]$_
        }
    }) -join "`n"
}

function Get-WinGetVersionTokenFromText {
    param([string]$Text)

    foreach ($line in @($Text -split "(`r`n|`n|`r)")) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^(v?\d+(?:\.\d+){1,3})(?:\s|$)') {
            return $matches[1]
        }
    }
    return ""
}

function Test-WinGetPolicyBlockedText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    return ($Text -match '(?i)group\s+policy|disabled\s+by\s+(?:your\s+)?administrator|windows\s+package\s+manager\s+.*disabled|app\s+installer\s+.*disabled')
}

function New-WinGetAvailabilityStatus {
    param(
        [ValidateSet("Available", "Missing", "PolicyBlocked", "ConstrainedLanguage", "BrokenRegistration")]
        [string]$Status,
        [bool]$Installed,
        [string]$Version = "",
        [string]$Path = "",
        [string]$Message = "",
        [string]$Blocker = "",
        [bool]$CanRepair = $false,
        [string]$LanguageMode = "",
        [object]$ExitCode = $null,
        [string]$ProbeOutput = ""
    )

    @{
        Installed    = [bool]$Installed
        Version      = if ($null -ne $Version) { [string]$Version } else { "" }
        Path         = if ($null -ne $Path) { [string]$Path } else { "" }
        Status       = $Status
        Blocker      = $Blocker
        Message      = $Message
        CanRepair    = [bool]$CanRepair
        LanguageMode = $LanguageMode
        ExitCode     = $ExitCode
        ProbeOutput  = Get-TextExcerpt -Text $ProbeOutput -MaxLength 800
    }
}

function ConvertTo-WinGetAvailabilityStatus {
    param(
        [bool]$CommandFound,
        [string]$Path = "",
        [object[]]$VersionOutput = @(),
        [object[]]$ErrorOutput = @(),
        [object]$ExitCode = $null,
        [string]$ExceptionMessage = "",
        [string]$LanguageMode = ""
    )

    $probeText = ConvertTo-WinGetProbeText -Parts @($VersionOutput + $ErrorOutput + @($ExceptionMessage))
    $version = Get-WinGetVersionTokenFromText -Text $probeText
    if ($CommandFound -and $version -and (($null -eq $ExitCode) -or ([int]$ExitCode -eq 0))) {
        return New-WinGetAvailabilityStatus -Status "Available" -Installed $true -Version $version -Path $Path -Message "WinGet is available." -Blocker "None" -CanRepair $false -LanguageMode $LanguageMode -ExitCode $ExitCode -ProbeOutput $probeText
    }

    if (Test-WinGetPolicyBlockedText -Text $probeText) {
        return New-WinGetAvailabilityStatus -Status "PolicyBlocked" -Installed $false -Path $Path -Message "WinGet is disabled by policy or administrator settings." -Blocker "GroupPolicy" -CanRepair $false -LanguageMode $LanguageMode -ExitCode $ExitCode -ProbeOutput $probeText
    }

    if ($LanguageMode -eq "ConstrainedLanguage") {
        return New-WinGetAvailabilityStatus -Status "ConstrainedLanguage" -Installed $false -Path $Path -Message "PowerShell constrained language mode prevents automated WinGet repair." -Blocker "ConstrainedLanguage" -CanRepair $false -LanguageMode $LanguageMode -ExitCode $ExitCode -ProbeOutput $probeText
    }

    if ($CommandFound) {
        return New-WinGetAvailabilityStatus -Status "BrokenRegistration" -Installed $false -Path $Path -Message "WinGet was found but could not run; App Installer registration may be broken." -Blocker "AppInstallerRegistration" -CanRepair $true -LanguageMode $LanguageMode -ExitCode $ExitCode -ProbeOutput $probeText
    }

    return New-WinGetAvailabilityStatus -Status "Missing" -Installed $false -Message "WinGet was not found on PATH." -Blocker "Missing" -CanRepair $true -LanguageMode $LanguageMode -ExitCode $ExitCode -ProbeOutput $probeText
}

function Test-WinGet {
    $languageMode = try { [string]$ExecutionContext.SessionState.LanguageMode } catch { "" }
    try {
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetPath) {
            $output = @()
            $exitCode = $null
            try {
                $output = @(& $wingetPath.Source --version 2>&1)
                $exitCode = $LASTEXITCODE
            } catch {
                return ConvertTo-WinGetAvailabilityStatus -CommandFound $true -Path $wingetPath.Source -ErrorOutput @($_) -ExitCode $LASTEXITCODE -ExceptionMessage $_.Exception.Message -LanguageMode $languageMode
            }
            return ConvertTo-WinGetAvailabilityStatus -CommandFound $true -Path $wingetPath.Source -VersionOutput $output -ExitCode $exitCode -LanguageMode $languageMode
        }
    } catch {
        return ConvertTo-WinGetAvailabilityStatus -CommandFound $false -ErrorOutput @($_) -ExceptionMessage $_.Exception.Message -LanguageMode $languageMode
    }
    return ConvertTo-WinGetAvailabilityStatus -CommandFound $false -LanguageMode $languageMode
}

function New-WinGetBootstrapLogPath {
    $root = Join-Path $env:APPDATA "Wingetter\logs"
    if (!(Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    # Millisecond precision + short entropy so concurrent Install-WinGet calls
    # never share a log file. The Script-scope variable remains as the
    # "last log path" hint but the function's primary contract is the return.
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
    $entropy = [System.Guid]::NewGuid().ToString("N").Substring(0, 4)
    $path = Join-Path $root ("winget-bootstrap-$stamp-$entropy.jsonl")
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

    if ($wingetStatus.ContainsKey("CanRepair") -and -not [bool]$wingetStatus.CanRepair) {
        $logPath = New-WinGetBootstrapLogPath
        Write-WinGetBootstrapLog -Path $logPath -Step "blocked" -Status "blocked" -Message $wingetStatus.Message -Data $wingetStatus
        return $false
    }

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
            $escaped = $arg -replace '"', '\"'
            $escaped = [regex]::Replace($escaped, '(\\+)(?=")', { param($m) $m.Groups[1].Value + $m.Groups[1].Value })
            $escaped = [regex]::Replace($escaped, '(\\+)$', { param($m) $m.Groups[1].Value + $m.Groups[1].Value })
            '"' + $escaped + '"'
        } else {
            $arg
        }
    }) -join " "
}

$Script:WingetterWinGetVersionText = $null

function Get-WinGetCliVersionText {
    if ($null -ne $Script:WingetterWinGetVersionText) { return $Script:WingetterWinGetVersionText }
    $Script:WingetterWinGetVersionText = ""
    try {
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            $output = & $winget.Source --version 2>$null
            $Script:WingetterWinGetVersionText = [string](@($output) | Select-Object -First 1)
        }
    } catch {
        $Script:WingetterWinGetVersionText = ""
    }
    return $Script:WingetterWinGetVersionText
}

function ConvertTo-WinGetVersion {
    param([string]$VersionText)

    $match = [regex]::Match([string]$VersionText, '(?<major>\d+)\.(?<minor>\d+)(?:\.(?<patch>\d+))?')
    if (!$match.Success) { return $null }
    $patch = if ($match.Groups["patch"].Success) { [int]$match.Groups["patch"].Value } else { 0 }
    return [version]::new([int]$match.Groups["major"].Value, [int]$match.Groups["minor"].Value, $patch)
}

function Test-WinGetVersionAtLeast {
    param(
        [string]$VersionText,
        [version]$MinimumVersion
    )

    $version = ConvertTo-WinGetVersion -VersionText $VersionText
    return ($null -ne $version -and $version -ge $MinimumVersion)
}

function Test-WinGetCleanOutputSupported {
    param([string]$VersionText = "")

    if ([string]::IsNullOrWhiteSpace($VersionText)) {
        $VersionText = Get-WinGetCliVersionText
    }
    Test-WinGetVersionAtLeast -VersionText $VersionText -MinimumVersion ([version]"1.29.0")
}

function Add-WinGetCleanOutputArguments {
    param(
        [string[]]$Arguments,
        [string]$WinGetVersion = ""
    )

    $updated = @($Arguments)
    if ((Test-WinGetCleanOutputSupported -VersionText $WinGetVersion) -and $updated -notcontains "--no-progress") {
        $updated += "--no-progress"
    }
    return [string[]]$updated
}

function ConvertFrom-WinGetSourceListText {
    param([string]$Text)

    $sources = [System.Collections.ArrayList]::new()
    if ([string]::IsNullOrWhiteSpace($Text)) { return [object[]]$sources.ToArray() }
    $lines = @($Text -split '(?:\r\n|\n|\r)')
    $headerIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*Name\s+Argument') {
            $headerIndex = $i
            break
        }
    }
    if ($headerIndex -lt 0) { return [object[]]$sources.ToArray() }
    $header = $lines[$headerIndex]
    $argCol = $header.IndexOf("Argument")
    $typeCol = $header.IndexOf("Type")
    if ($argCol -lt 1) { return [object[]]$sources.ToArray() }
    $dataStart = $headerIndex + 1
    if ($dataStart -lt $lines.Count -and $lines[$dataStart] -match '^[-\s]+$') { $dataStart++ }
    for ($i = $dataStart; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.Length -le $argCol) { continue }
        $name = $line.Substring(0, [Math]::Min($argCol, $line.Length)).Trim()
        $argument = ""
        $type = ""
        if ($typeCol -gt $argCol -and $line.Length -gt $typeCol) {
            $argument = $line.Substring($argCol, $typeCol - $argCol).Trim()
            $type = $line.Substring($typeCol).Trim()
        } else {
            $argument = $line.Substring($argCol).Trim()
        }
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        [void]$sources.Add([PSCustomObject][ordered]@{
            Name     = $name
            Argument = $argument
            Type     = $type
        })
    }
    return [object[]]$sources.ToArray()
}

function Get-WingetterSourceHealthState {
    param(
        [string]$SourceName,
        [string]$StdOut = "",
        [string]$StdErr = "",
        [int]$ExitCode = 0,
        [bool]$TimedOut = $false
    )

    $combined = "$StdOut`n$StdErr"
    if ($TimedOut) {
        return [PSCustomObject][ordered]@{
            Status   = "Offline"
            Message  = "Source update timed out."
            Guidance = "Check network connectivity. If the source URL is unreachable, run: winget source reset --name '$SourceName' --force"
        }
    }
    if ($ExitCode -eq 0 -and $combined -notmatch '(?i)fail|error|corrupt') {
        return [PSCustomObject][ordered]@{
            Status   = "Ok"
            Message  = "Source is healthy."
            Guidance = ""
        }
    }
    if ($combined -match '(?i)corrupt|invalid\s*index|damaged|malformed') {
        return [PSCustomObject][ordered]@{
            Status   = "Corrupt"
            Message  = "Source index appears corrupted."
            Guidance = "Run: winget source reset --name '$SourceName' --force"
        }
    }
    if ($combined -match '(?i)authenticat|401|403|certificate.*error|credentials|access\s*denied') {
        return [PSCustomObject][ordered]@{
            Status   = "AuthRequired"
            Message  = "Source requires authentication or the token has expired."
            Guidance = "Re-add the source with a valid --header token: winget source remove --name '$SourceName' && winget source add --name '$SourceName' --arg <URL> --header <token>"
        }
    }
    if ($combined -match '(?i)connection|network|offline|unreachable|resolve|timeout|timed\s*out|WININET|could\s*not\s*connect') {
        return [PSCustomObject][ordered]@{
            Status   = "Offline"
            Message  = "Source is unreachable."
            Guidance = "Check network connectivity. For persistent failures: winget source reset --name '$SourceName' --force"
        }
    }
    [PSCustomObject][ordered]@{
        Status   = "Unknown"
        Message  = "Source update returned exit code $ExitCode."
        Guidance = "Inspect winget output. General reset: winget source reset --name '$SourceName' --force"
    }
}

function Get-WingetterSourceHealth {
    param(
        [int]$TimeoutSeconds = 10,
        [switch]$SkipLiveProbe,
        [object]$SourceListCapture = $null,
        [hashtable]$SourceUpdateCaptures = @{}
    )

    if ($null -eq $SourceListCapture -and -not $SkipLiveProbe) {
        $SourceListCapture = Invoke-WinGetCapture -Arguments @("source", "list", "--disable-interactivity") -TimeoutSeconds $TimeoutSeconds
    }
    $parsedSources = if ($SourceListCapture) { ConvertFrom-WinGetSourceListText -Text $SourceListCapture.StdOut } else { @() }
    $results = [System.Collections.ArrayList]::new()

    foreach ($source in @($parsedSources)) {
        $capture = $null
        if ($SourceUpdateCaptures.ContainsKey($source.Name)) {
            $capture = $SourceUpdateCaptures[$source.Name]
        } elseif (-not $SkipLiveProbe) {
            $capture = Invoke-WinGetCapture -Arguments @("source", "update", "--name", $source.Name, "--disable-interactivity") -TimeoutSeconds $TimeoutSeconds
        }

        if ($null -ne $capture) {
            $health = Get-WingetterSourceHealthState -SourceName $source.Name -StdOut $capture.StdOut -StdErr $capture.StdErr -ExitCode $capture.ExitCode -TimedOut $capture.TimedOut
        } else {
            $health = [PSCustomObject][ordered]@{
                Status   = "Unchecked"
                Message  = "Live probe was skipped."
                Guidance = "Run: winget source update --name $($source.Name)"
            }
        }
        [void]$results.Add([PSCustomObject][ordered]@{
            Source   = [string]$source.Name
            Url      = [string]$source.Argument
            Type     = [string]$source.Type
            Status   = [string]$health.Status
            Message  = [string]$health.Message
            Guidance = [string]$health.Guidance
        })
    }

    $okCount = @($results | Where-Object { $_.Status -eq "Ok" }).Count
    $totalCount = $results.Count
    $summary = if ($totalCount -eq 0) { "No sources found" }
               elseif ($okCount -eq $totalCount) { "All $totalCount source(s) healthy" }
               else { "$okCount/$totalCount source(s) healthy" }

    [PSCustomObject][ordered]@{
        Schema  = "Wingetter.SourceHealth.v1"
        ProbeAt = (Get-Date).ToUniversalTime().ToString("o")
        Sources = [object[]]$results.ToArray()
        Summary = [string]$summary
    }
}

function Get-WinGetClientReadiness {
    param(
        [object]$AvailabilityStatus,
        [string]$LatestStableVersion = "1.28.240",
        [string]$LatestPrereleaseVersion = "1.29.280"
    )

    $installed = ($null -ne $AvailabilityStatus -and [bool]$AvailabilityStatus.Installed)
    $versionText = if ($installed -and $AvailabilityStatus.Version) { [string]$AvailabilityStatus.Version } else { "" }
    $version = ConvertTo-WinGetVersion -VersionText $versionText
    $stableVersion = ConvertTo-WinGetVersion -VersionText $LatestStableVersion
    $prereleaseVersion = ConvertTo-WinGetVersion -VersionText $LatestPrereleaseVersion
    $warnings = [System.Collections.ArrayList]::new()
    $channel = "Unavailable"
    $isStale = $false
    $isPrerelease = $false

    if ($installed) {
        if ($null -eq $version) {
            $channel = "Unknown"
            [void]$warnings.Add("Could not parse WinGet version '$versionText'.")
        } elseif ($stableVersion -and $version -lt $stableVersion) {
            $channel = "Old"
            $isStale = $true
            [void]$warnings.Add("Installed WinGet $versionText is older than the known stable $LatestStableVersion.")
        } elseif ($prereleaseVersion -and $version -ge $prereleaseVersion) {
            $channel = "Prerelease"
            $isPrerelease = $true
        } else {
            $channel = "Stable"
        }
    } elseif ($AvailabilityStatus -and $AvailabilityStatus.Status) {
        $channel = [string]$AvailabilityStatus.Status
        if ($AvailabilityStatus.Message) { [void]$warnings.Add([string]$AvailabilityStatus.Message) }
    }

    $features = [ordered]@{
        CleanOutputNoProgress = [bool]($installed -and (Test-WinGetCleanOutputSupported -VersionText $versionText))
        StableListSort        = [bool]($installed -and (Test-WinGetCleanOutputSupported -VersionText $versionText))
        SourcePriority        = [bool]($installed -and (Test-WinGetVersionAtLeast -VersionText $versionText -MinimumVersion ([version]"1.29.0")))
    }
    $supportedFeatures = @($features.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { $_.Key })
    $unsupportedFeatures = @($features.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
    $updateCommand = "winget upgrade --id Microsoft.AppInstaller --exact --source msstore --accept-package-agreements --accept-source-agreements"
    $repairCommand = "Repair-WinGetPackageManager -Force -Latest"
    $summary = if ($installed) {
        "WinGet $versionText ($channel)"
    } elseif ($AvailabilityStatus -and $AvailabilityStatus.Message) {
        [string]$AvailabilityStatus.Message
    } else {
        "WinGet unavailable"
    }
    $detail = New-Object System.Collections.Generic.List[string]
    $detail.Add($summary)
    $detail.Add("Supported features: $(if ($supportedFeatures.Count -gt 0) { $supportedFeatures -join ', ' } else { 'none' })")
    $detail.Add("Unsupported features: $(if ($unsupportedFeatures.Count -gt 0) { $unsupportedFeatures -join ', ' } else { 'none' })")
    $detail.Add("Update command: $updateCommand")
    $detail.Add("Repair command: $repairCommand")
    if ($warnings.Count -gt 0) { $detail.Add("Warnings: $($warnings -join ' ')") }

    [PSCustomObject][ordered]@{
        Installed           = [bool]$installed
        Status              = if ($AvailabilityStatus -and $AvailabilityStatus.Status) { [string]$AvailabilityStatus.Status } else { "" }
        VersionText         = $versionText
        ParsedVersion       = if ($version) { [string]$version } else { "" }
        Channel             = $channel
        IsPrerelease        = [bool]$isPrerelease
        IsStale             = [bool]$isStale
        Features            = [PSCustomObject]$features
        SupportedFeatures   = [string[]]$supportedFeatures
        UnsupportedFeatures = [string[]]$unsupportedFeatures
        UpdateCommand       = $updateCommand
        RepairCommand       = $repairCommand
        Warnings            = [string[]]$warnings.ToArray([string])
        Summary             = $summary
        Detail              = [string[]]$detail.ToArray()
    }
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
    $proc = $null

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
        # Kill() can race with the async ReadToEndAsync tasks, surfacing an
        # IOException or OperationCanceledException. Treat those as "no output
        # captured" rather than letting them propagate out of the capture path.
        try { $stdout = $stdoutTask.GetAwaiter().GetResult() } catch { $stdout = "" }
        try { $stderr = $stderrTask.GetAwaiter().GetResult() } catch { $stderr = "" }
        $exitCode = if ($timedOut) { -1 } else { $proc.ExitCode }
    } catch {
        $stderr = $_.Exception.Message
    } finally {
        if ($null -ne $proc) {
            try { $proc.Dispose() } catch {}
        }
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
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
    $entropy = [System.Guid]::NewGuid().ToString("N").Substring(0, 4)
    $path = Join-Path $root "$stamp-$entropy-$Action"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function New-WingetterRunPlan {
    param(
        [ValidateSet("install", "upgrade", "uninstall")]
        [string]$Action,
        [object[]]$SelectedPackages,
        [hashtable]$InstalledRecords = @{},
        [object]$SourcePolicy = $null,
        [hashtable]$PinStatusesById = @{},
        [bool]$IncludePinned = $false,
        [string]$ProfileName = "Manual selection"
    )

    $items = New-Object System.Collections.ArrayList
    $summary = [ordered]@{
        total           = 0
        runnable        = 0
        skipped         = 0
        blocked         = 0
        unresolved      = 0
        current         = 0
        updateAvailable = 0
        pinned          = 0
    }

    foreach ($package in @($SelectedPackages)) {
        $summary.total++
        $packageId = if ($package.WingetId) { [string]$package.WingetId } elseif ($package.PackageId) { [string]$package.PackageId } else { "" }
        $name = if ($package.Name) { [string]$package.Name } else { $packageId }
        $sourceName = if ($package.SourceName) { [string]$package.SourceName } else { "winget" }
        $installOptions = if ($package.PSObject.Properties["InstallOptions"]) { ConvertTo-WingetterInstallOptions -InstallOptions $package.InstallOptions -AllowCustom $true } else { ConvertTo-WingetterInstallOptions -InstallOptions $null }
        $installOptionsSummary = ConvertTo-WingetterInstallOptionsSummary -InstallOptions $installOptions
        $installed = if ($InstalledRecords -and $InstalledRecords.ContainsKey($packageId)) { $InstalledRecords[$packageId] } else { $null }
        $pinStatus = if ($PinStatusesById -and $PinStatusesById.ContainsKey($packageId)) { $PinStatusesById[$packageId] } else { $null }
        $isInstalled = ($null -ne $installed)
        $isUpdateAvailable = ($isInstalled -and [bool]$installed.IsUpdateAvailable)
        $status = "READY"
        $plannedAction = if ($Action -eq "upgrade") { "Upgrade" } else { "Install" }
        $reason = "Ready to run."
        $canRun = $true
        $policyAllowed = $true
        $policyReason = ""

        if ([string]::IsNullOrWhiteSpace($packageId)) {
            $status = "UNRESOLVED"
            $plannedAction = "Skip"
            $reason = "Missing package identifier."
            $canRun = $false
        } elseif (Get-Command Test-WingetterPackageAllowedBySourcePolicy -ErrorAction SilentlyContinue) {
            $policyCheck = Test-WingetterPackageAllowedBySourcePolicy -Policy $SourcePolicy -PackageId $packageId -SourceName $sourceName
            $policyAllowed = [bool]$policyCheck.Allowed
            $policyReason = [string]$policyCheck.Reason
            if (!$policyAllowed) {
                $status = "BLOCKED"
                $plannedAction = "Skip"
                $reason = $policyReason
                $canRun = $false
            }
        }

        if ($canRun -and $Action -eq "uninstall") {
            if (!$isInstalled) {
                $status = "NOT_INSTALLED"
                $plannedAction = "Skip"
                $reason = "Package is not detected as installed."
                $canRun = $false
            } else {
                $plannedAction = "Uninstall"
                $reason = "Ready to uninstall."
            }
        } elseif ($canRun -and $Action -eq "upgrade") {
            if (!$isInstalled) {
                $status = "NOT_INSTALLED"
                $plannedAction = "Skip"
                $reason = "Package is not detected as installed."
                $canRun = $false
            } elseif (!$isUpdateAvailable) {
                $status = "CURRENT"
                $plannedAction = "Skip"
                $reason = "Installed package is already current."
                $canRun = $false
            }
        } elseif ($canRun -and $Action -eq "install" -and $isInstalled) {
            $status = if ($isUpdateAvailable) { "INSTALLED_UPDATE_AVAILABLE" } else { "INSTALLED_CURRENT" }
            $plannedAction = "Skip"
            $reason = if ($isUpdateAvailable) { "Already installed; update is available in update mode." } else { "Already installed." }
            $canRun = $false
        }

        if ($pinStatus -and $pinStatus.IsPinned) {
            $summary.pinned++
            if ($canRun -and $Action -eq "upgrade" -and !$IncludePinned) {
                $status = "PINNED"
                $plannedAction = "Skip"
                $reason = $pinStatus.Summary
                $canRun = $false
            }
        }

        if ($isUpdateAvailable) { $summary.updateAvailable++ }
        switch ($status) {
            "BLOCKED" { $summary.blocked++ }
            "UNRESOLVED" { $summary.unresolved++ }
            "CURRENT" { $summary.current++ }
            "INSTALLED_CURRENT" { $summary.current++ }
        }
        if ($canRun) { $summary.runnable++ } else { $summary.skipped++ }

        [void]$items.Add([PSCustomObject][ordered]@{
            Name             = $name
            PackageId        = $packageId
            SourceName       = $sourceName
            RequestedAction  = $Action
            PlannedAction    = $plannedAction
            Status           = $status
            Reason           = $reason
            CanRun           = [bool]$canRun
            SelectedForRun   = [bool]$canRun
            IsInstalled      = [bool]$isInstalled
            IsUpdateAvailable = [bool]$isUpdateAvailable
            InstalledVersion = if ($installed) { [string]$installed.InstalledVersion } else { "" }
            AvailableVersion = if ($installed) { [string]$installed.AvailableVersion } else { "" }
            PinStatus        = if ($pinStatus) { [string]$pinStatus.Summary } else { "" }
            PinType          = if ($pinStatus) { [string]$pinStatus.PinType } else { "None" }
            SourceAllowed    = [bool]$policyAllowed
            SourceReason     = $policyReason
            InstallOptions   = $installOptions
            InstallOptionsSummary = $installOptionsSummary
        })
    }

    [PSCustomObject][ordered]@{
        Schema          = "Wingetter.RunPlan.v1"
        GeneratedAtUtc  = (Get-Date).ToUniversalTime().ToString("o")
        ProfileName     = $ProfileName
        RequestedAction = $Action
        IncludePinned   = [bool]$IncludePinned
        Summary         = [PSCustomObject]$summary
        Packages        = @($items)
    }
}

function Export-WingetterRunPlan {
    param(
        [object]$RunPlan,
        [string]$FilePath
    )

    $json = $RunPlan | ConvertTo-Json -Depth 8
    Set-WingetterFileAtomic -Path $FilePath -Content $json -Encoding UTF8
    return $FilePath
}

function Get-WinGetLogDirectory {
    $path = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"
    if (Test-Path $path) { return $path }
    return $null
}

function Remove-WingetterProgressNoise {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $lines = @($Text -split '(?:\r\n|\n|\r)')
    $clean = [System.Collections.ArrayList]::new()
    $collapsedCount = 0
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed -match '^[\|/\-\\]+$') { $collapsedCount++; continue }
        if ($trimmed -match '^\r') { $collapsedCount++; continue }
        if ($trimmed -match '(?:^[\s\x08]*[\|/\-\\][\s\x08]*$)') { $collapsedCount++; continue }
        if ($trimmed -match '^\[[\s=\-#>\.oO]*\]\s*\d+%?$') { $collapsedCount++; continue }
        if ($trimmed -match '^(?:\d{1,3}%|\.{2,}|={2,}|-{3,})$') { $collapsedCount++; continue }
        if ($trimmed -match '^\x1b\[') { $trimmed = $trimmed -replace '\x1b\[[0-9;]*[A-Za-z]', '' }
        $trimmed = $trimmed.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        [void]$clean.Add($trimmed)
    }
    $result = $clean -join "`n"
    if ($collapsedCount -gt 0 -and $clean.Count -gt 0) {
        $result += "`n[collapsed $collapsedCount progress line(s)]"
    }
    return $result
}

function Get-TextExcerpt {
    param([string]$Text, [int]$MaxLength = 1000)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $clean = (Remove-WingetterProgressNoise -Text $Text) -replace '\s+', ' '
    $clean = $clean.Trim()
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
        [bool]$IncludePinned,
        [object]$InstallOptions = $null,
        [string]$WinGetVersion = ""
    )

    $arguments = @($Action, "--id", $PackageId, "--exact", "--verbose-logs", "--disable-interactivity")
    if (![string]::IsNullOrWhiteSpace($SourceName) -and $Action -ne "uninstall") {
        $arguments += "--source"
        $arguments += $SourceName
    }
    $options = ConvertTo-WingetterInstallOptions -InstallOptions $InstallOptions -AllowCustom $true
    if ($Action -in @("install", "upgrade")) {
        if ($options.PSObject.Properties["Version"]) {
            $arguments += "--version"
            $arguments += [string]$options.Version
        }
        if ($options.PSObject.Properties["Scope"]) {
            $arguments += "--scope"
            $arguments += [string]$options.Scope
        }
        if ($options.PSObject.Properties["Architecture"]) {
            $arguments += "--architecture"
            $arguments += [string]$options.Architecture
        }
        if ($options.PSObject.Properties["InstallerType"]) {
            $arguments += "--installer-type"
            $arguments += [string]$options.InstallerType
        }
        if ($options.PSObject.Properties["Locale"]) {
            $arguments += "--locale"
            $arguments += [string]$options.Locale
        }
        if ($Action -eq "install" -and $options.PSObject.Properties["Location"]) {
            $arguments += "--location"
            $arguments += [string]$options.Location
        }
        if ($options.PSObject.Properties["Custom"]) {
            $arguments += "--custom"
            $arguments += [string]$options.Custom
        }
    }
    if ($Silent) { $arguments += "--silent" }
    if ($AcceptAgreements) {
        $arguments += "--accept-package-agreements"
        $arguments += "--accept-source-agreements"
    }
    if ($Action -eq "upgrade" -and $IncludePinned) {
        $arguments += "--include-pinned"
    }
    return Add-WinGetCleanOutputArguments -Arguments $arguments -WinGetVersion $WinGetVersion
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
        [object]$InstallOptions = $null,
        [string]$RunLogDir,
        [scriptblock]$ShouldCancel = { $false }
    )

    $options = ConvertTo-WingetterInstallOptions -InstallOptions $InstallOptions -AllowCustom $true
    $arguments = New-WinGetPackageOperationArguments -Action $Action -PackageId $PackageId -SourceName $SourceName -Silent $Silent -AcceptAgreements $AcceptAgreements -IncludePinned $IncludePinned -InstallOptions $options

    $safeId = Get-SafeFileName -Value $PackageId
    # 7-digit fractional seconds (100-ns ticks) avoids collisions when two
    # operations launch within the same millisecond (e.g., from a UI that fans
    # out installs in a tight loop). Adding a short random suffix keeps the
    # path unique even if the clock has the same tick value across runs.
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss-fffffff"
    $entropy = [System.Guid]::NewGuid().ToString("N").Substring(0, 4)
    $stdoutPath = Join-Path $RunLogDir "$stamp-$entropy-$safeId.stdout.log"
    $stderrPath = Join-Path $RunLogDir "$stamp-$entropy-$safeId.stderr.log"
    $resultPath = Join-Path $RunLogDir "$stamp-$entropy-$safeId.result.json"

    $stdout = ""
    $stderr = ""
    $exitCode = $null
    $cancelled = $false
    $proc = $null

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
            Start-Sleep -Milliseconds 100
            if (& $ShouldCancel) {
                $cancelled = $true
                try { $proc.Kill() } catch {}
                break
            }
        }

        try { $proc.WaitForExit() } catch {}
        # Async stream readers can throw after Kill() races them; capture
        # whatever was buffered before cancellation rather than letting the
        # exception bubble out and abort the install loop.
        try { $stdout = $stdoutTask.GetAwaiter().GetResult() } catch { $stdout = "" }
        try { $stderr = $stderrTask.GetAwaiter().GetResult() } catch { $stderr = "" }
        $exitCode = if ($cancelled) { -1 } else { $proc.ExitCode }
    } catch {
        $stderr = $_.Exception.Message
        $exitCode = -1
    } finally {
        if ($null -ne $proc) {
            try { $proc.Dispose() } catch {}
        }
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
        InstallOptions    = $options
        InstallOptionsSummary = ConvertTo-WingetterInstallOptionsSummary -InstallOptions $options
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
    $result | ConvertTo-Json -Depth 8 | Set-Content -Path $resultPath -Encoding UTF8

    return [PSCustomObject]$result
}

function Get-WinGetShowField {
    param([string]$Text, [string]$Label)
    $pattern = "(?im)^\s*$([regex]::Escape($Label)):\s*(?<value>.+?)\s*$"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups["value"].Value.Trim() }
    return ""
}

function Get-WingetterPackageRiskWarnings {
    param(
        [string]$ShowText,
        [object]$CatalogEntry = $null
    )

    $warnings = [System.Collections.ArrayList]::new()
    if ([string]::IsNullOrWhiteSpace($ShowText) -and $null -eq $CatalogEntry) { return [object[]]$warnings.ToArray() }

    if (![string]::IsNullOrWhiteSpace($ShowText)) {
        if ($ShowText -match '(?im)^\s*Installer SHA256:\s*$' -or $ShowText -match '(?i)no\s*hash|hash\s*missing|SHA256:\s*$') {
            [void]$warnings.Add([PSCustomObject][ordered]@{
                Severity = "Warning"
                Code     = "MISSING_HASH"
                Message  = "Installer hash is not published. The package cannot be verified at install time."
            })
        }
        if ($ShowText -match '(?i)potentially\s*unwanted|PUA|unwanted\s*application|unwanted\s*software') {
            [void]$warnings.Add([PSCustomObject][ordered]@{
                Severity = "Critical"
                Code     = "PUA_WARNING"
                Message  = "This package has been flagged as a potentially unwanted application."
            })
        }
        if ($ShowText -match '(?i)deprecated|end.of.life|EOL|no\s*longer\s*maintained') {
            [void]$warnings.Add([PSCustomObject][ordered]@{
                Severity = "Info"
                Code     = "DEPRECATED"
                Message  = "This package may be deprecated or no longer maintained."
            })
        }

        $license = Get-WinGetShowField -Text $ShowText -Label "License"
        if ([string]::IsNullOrWhiteSpace($license)) {
            [void]$warnings.Add([PSCustomObject][ordered]@{
                Severity = "Info"
                Code     = "NO_LICENSE"
                Message  = "No license information is published for this package."
            })
        }

        $installerUrl = Get-WinGetShowField -Text $ShowText -Label "Installer Url"
        if (![string]::IsNullOrWhiteSpace($installerUrl) -and $installerUrl -match '^http://') {
            [void]$warnings.Add([PSCustomObject][ordered]@{
                Severity = "Warning"
                Code     = "HTTP_INSTALLER"
                Message  = "Installer URL uses HTTP instead of HTTPS."
            })
        }
    }

    if ($null -ne $CatalogEntry) {
        $riskNotes = if ($CatalogEntry.PSObject.Properties["riskNotes"]) { $CatalogEntry.riskNotes } else { $null }
        if ($riskNotes) {
            foreach ($note in @($riskNotes)) {
                [void]$warnings.Add([PSCustomObject][ordered]@{
                    Severity = if ($note.PSObject.Properties["severity"]) { [string]$note.severity } else { "Info" }
                    Code     = if ($note.PSObject.Properties["code"]) { [string]$note.code } else { "CATALOG_NOTE" }
                    Message  = if ($note.PSObject.Properties["message"]) { [string]$note.message } else { [string]$note }
                })
            }
        }
    }

    return [object[]]$warnings.ToArray()
}

function Find-WinGetPackageIdColumn {
    param([string]$Line, [string]$PackageId)
    # Return the column index where $PackageId appears as a whitespace-delimited
    # token, or -1 if no such occurrence exists. WinGet's tabular output places
    # the Id column AFTER the Name column, so when a package id is a substring
    # of another row's name (e.g., "Test" inside "Other Test"), the real Id
    # column is the RIGHTMOST word-boundary occurrence; preferring the last
    # match instead of the first one keeps the parser correct on those rows.
    if ([string]::IsNullOrEmpty($Line) -or [string]::IsNullOrEmpty($PackageId)) { return -1 }
    $result = -1
    $startIndex = 0
    while ($startIndex -lt $Line.Length) {
        $found = $Line.IndexOf($PackageId, $startIndex, [System.StringComparison]::OrdinalIgnoreCase)
        if ($found -lt 0) { break }
        $before = if ($found -eq 0) { ' ' } else { $Line[$found - 1] }
        $afterPos = $found + $PackageId.Length
        $after = if ($afterPos -ge $Line.Length) { ' ' } else { $Line[$afterPos] }
        if ([char]::IsWhiteSpace([char]$before) -and ([char]::IsWhiteSpace([char]$after) -or $afterPos -eq $Line.Length)) {
            $result = $found
        }
        $startIndex = $found + 1
    }
    return $result
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
        # Skip separator rows so a package id that happens to contain only
        # hyphens (impossible in practice, but cheap to guard) cannot pick up
        # the dashed separator that follows the header row.
        if ($line -match '^\s*-+\s*$') { continue }
        $index = Find-WinGetPackageIdColumn -Line $line -PackageId $PackageId
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

function New-WinGetListArguments {
    param(
        [string]$SourceName = "",
        [string]$WinGetVersion = ""
    )

    $arguments = @("list", "--disable-interactivity")
    if (![string]::IsNullOrWhiteSpace($SourceName)) {
        $arguments += "--source"
        $arguments += $SourceName
    }
    if (Test-WinGetCleanOutputSupported -VersionText $WinGetVersion) {
        $arguments += "--sort"
        $arguments += "name"
        $arguments += "--ascending"
    }
    return Add-WinGetCleanOutputArguments -Arguments $arguments -WinGetVersion $WinGetVersion
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
        if ($line -match '^\s*-+\s*$') { continue }
        # On a given row, multiple package ids in the search set may match at
        # different column boundaries (e.g., a short id that appears inside the
        # Name column and a long id that is the Id column for the same row).
        # Pick the LONGEST unconsumed match so the actual Id column wins over
        # any incidental Name-column collision.
        $bestId = $null
        $bestIndex = -1
        $bestLength = -1
        foreach ($packageId in $PackageIds) {
            if ($records.ContainsKey($packageId)) { continue }
            $index = Find-WinGetPackageIdColumn -Line $line -PackageId $packageId
            if ($index -lt 0) { continue }
            if ($packageId.Length -gt $bestLength) {
                $bestId = $packageId
                $bestIndex = $index
                $bestLength = $packageId.Length
            }
        }
        if ($null -eq $bestId) { continue }
        $packageId = $bestId
        $index = $bestIndex

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
            $capture = Invoke-WinGetCapture -Arguments (New-WinGetListArguments -SourceName $listSource) -TimeoutSeconds 45
            $records = ConvertFrom-WinGetListText -Text "$($capture.StdOut)`n$($capture.StdErr)" -PackageIds $PackageIds -ScannedAtUtc $scannedAtUtc
            if ($capture.ExitCode -ne 0 -and !$errorMessage) { $errorMessage = "winget list exited with code $($capture.ExitCode)." }
        } catch {
            $errorMessage = $_.Exception.Message
        }
    }

    $cachePath = Get-WingetterInstalledCachePath
    try {
        $cacheJson = [ordered]@{
            scannedAtUtc    = $scannedAtUtc
            detectionMethod = $method
            sourceName      = $SourceName
            error           = $errorMessage
            packages        = @($records.Values)
        } | ConvertTo-Json -Depth 8
        Set-WingetterFileAtomic -Path $cachePath -Content $cacheJson -Encoding UTF8
    } catch {
        Write-Warning "Failed to persist installed-cache.json: $($_.Exception.Message)"
    }

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
        if ($line -match '^\s*-+\s*$') { continue }
        $index = Find-WinGetPackageIdColumn -Line $line -PackageId $PackageId
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

    $arguments = Add-WinGetCleanOutputArguments -Arguments @("pin", "list", "--id", $PackageId, "--exact", "--disable-interactivity")
    $capture = Invoke-WinGetCapture -Arguments $arguments -TimeoutSeconds 20
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

    $arguments = Add-WinGetCleanOutputArguments -Arguments $arguments
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
    $arguments = Add-WinGetCleanOutputArguments -Arguments $arguments
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
