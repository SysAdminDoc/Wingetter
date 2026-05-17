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

function Get-WinGetOperationStatus {
    param(
        [int]$ExitCode,
        [string]$StdOut,
        [string]$StdErr,
        [bool]$Cancelled
    )
    if ($Cancelled) { return "CANCELLED" }
    $combined = "$StdOut`n$StdErr"
    if ($combined -match "already installed|No available upgrade|No newer package|No applicable update") { return "UP TO DATE" }
    if ($ExitCode -eq 0) { return "SUCCESS" }
    return "FAILED"
}

function Invoke-WinGetPackageOperation {
    param(
        [string]$Action,
        [string]$PackageId,
        [string]$PackageName,
        [bool]$Silent,
        [bool]$AcceptAgreements,
        [string]$RunLogDir,
        [scriptblock]$ShouldCancel = { $false },
        [scriptblock]$PumpUi = {}
    )

    $arguments = @($Action, "--id", $PackageId, "--exact", "--verbose-logs", "--disable-interactivity")
    if ($Silent) { $arguments += "--silent" }
    if ($AcceptAgreements) {
        $arguments += "--accept-package-agreements"
        $arguments += "--accept-source-agreements"
    }

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

    $status = Get-WinGetOperationStatus -ExitCode ([int]$exitCode) -StdOut $stdout -StdErr $stderr -Cancelled $cancelled
    $result = [ordered]@{
        TimestampUtc  = (Get-Date).ToUniversalTime().ToString("o")
        Action        = $Action
        PackageName   = $PackageName
        PackageId     = $PackageId
        Command       = "winget " + (Join-ProcessArguments -Arguments $arguments)
        ExitCode      = $exitCode
        Status        = $status
        Cancelled     = $cancelled
        StdOutPath    = $stdoutPath
        StdErrPath    = $stderrPath
        StdOutExcerpt = Get-TextExcerpt -Text $stdout
        StdErrExcerpt = Get-TextExcerpt -Text $stderr
        RunLogDir     = $RunLogDir
        WinGetLogDir  = Get-WinGetLogDirectory
        ResultPath    = $resultPath
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
    param([string]$PackageId)

    $capture = Invoke-WinGetCapture -Arguments @("list", "--id", $PackageId, "--exact", "--disable-interactivity") -TimeoutSeconds 15
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

function Get-WinGetPackageDetails {
    param([string]$PackageId)

    $capture = Invoke-WinGetCapture -Arguments @("show", "--id", $PackageId, "--exact", "--disable-interactivity", "--accept-source-agreements") -TimeoutSeconds 20
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
    $installedVersion = Get-WinGetInstalledVersion -PackageId $PackageId

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
