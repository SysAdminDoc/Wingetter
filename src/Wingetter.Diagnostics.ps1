# ============================================================================
# DIAGNOSTICS BUNDLE EXPORT
# ============================================================================

function Get-WingetterDiagnosticsDefaultOutputPath {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Join-Path (Get-Location).Path "Wingetter-Diagnostics-$stamp.zip"
}

function Get-WingetterDiagnosticsLogRoot {
    param([string]$AppDataRoot = (Get-WingetterAppDataPath))
    Join-Path $AppDataRoot "logs"
}

function Get-WingetterDiagnosticsSensitiveValues {
    param([object]$SourcePolicy = $null)

    $values = New-Object System.Collections.Generic.List[string]
    foreach ($candidate in @($env:USERPROFILE, $env:USERNAME, $env:COMPUTERNAME, $env:APPDATA)) {
        if (![string]::IsNullOrWhiteSpace([string]$candidate) -and [string]$candidate.Length -gt 2) {
            $values.Add([string]$candidate)
        }
    }

    if ($null -ne $SourcePolicy -and (Get-Command Get-WingetterSourcePolicyDefinitions -ErrorAction SilentlyContinue)) {
        foreach ($source in @(Get-WingetterSourcePolicyDefinitions -Policy $SourcePolicy)) {
            foreach ($propertyName in @("Header", "Password", "Token", "Secret")) {
                $property = $source.PSObject.Properties[$propertyName]
                if ($property -and ![string]::IsNullOrWhiteSpace([string]$property.Value) -and [string]$property.Value -ne (Get-WingetterRedactedSourceHeaderPlaceholder)) {
                    $values.Add([string]$property.Value)
                }
            }
        }
    }

    return [string[]]@($values | Select-Object -Unique)
}

function Redact-WingetterDiagnosticText {
    param(
        [string]$Text,
        [string[]]$SensitiveValues = @()
    )

    $redacted = [string]$Text
    foreach ($value in @($SensitiveValues)) {
        if ([string]::IsNullOrWhiteSpace($value) -or [string]$value.Length -lt 3) { continue }
        $replacement = switch -Regex ($value) {
            ([regex]::Escape($env:APPDATA)) { "<appdata>"; break }
            ([regex]::Escape($env:USERPROFILE)) { "<user-profile>"; break }
            ([regex]::Escape($env:USERNAME)) { "<user>"; break }
            ([regex]::Escape($env:COMPUTERNAME)) { "<computer>"; break }
            default { "<redacted>" }
        }
        $redacted = [regex]::Replace($redacted, [regex]::Escape($value), $replacement, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }

    $redacted = [regex]::Replace($redacted, '(?i)(Authorization\s*[:=]\s*)(Bearer\s+)?[^\r\n;,"}]+', '${1}<redacted>')
    $redacted = [regex]::Replace($redacted, '(?i)(--header\s+)(?:"[^"]+"|\S+)', '${1}<redacted-header>')
    $redacted = [regex]::Replace($redacted, '(?i)\b(token|secret|password|api[-_ ]?key)(\s*[:=]\s*)[^\s,;"''}]+', '${1}${2}<redacted>')
    return $redacted
}

function Join-WingetterDiagnosticsPath {
    param(
        [string]$Root,
        [string]$RelativePath
    )

    $relative = ([string]$RelativePath).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
    $target = Join-Path $Root $relative
    $rootFull = [System.IO.Path]::GetFullPath(((Resolve-Path -LiteralPath $Root).Path).TrimEnd("\") + "\")
    $targetFull = [System.IO.Path]::GetFullPath($target)
    if (!$targetFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Diagnostics relative path '$RelativePath' escapes the staging directory."
    }
    $parent = Split-Path -Parent $targetFull
    if (![string]::IsNullOrWhiteSpace($parent) -and !(Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    return $targetFull
}

function Write-WingetterDiagnosticsTextFile {
    param(
        [string]$Root,
        [string]$RelativePath,
        [string]$Content,
        [string[]]$SensitiveValues = @()
    )

    $path = Join-WingetterDiagnosticsPath -Root $Root -RelativePath $RelativePath
    $safeContent = Redact-WingetterDiagnosticText -Text $Content -SensitiveValues $SensitiveValues
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($path, $safeContent, $utf8NoBom)
    return $RelativePath
}

function Write-WingetterDiagnosticsJsonFile {
    param(
        [string]$Root,
        [string]$RelativePath,
        [object]$InputObject,
        [string[]]$SensitiveValues = @(),
        [int]$Depth = 10
    )

    $json = $InputObject | ConvertTo-Json -Depth $Depth
    Write-WingetterDiagnosticsTextFile -Root $Root -RelativePath $RelativePath -Content ($json + [Environment]::NewLine) -SensitiveValues $SensitiveValues
}

function New-WingetterDiagnosticsCommandCapture {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [string]$StdOut = "",
        [string]$StdErr = "",
        [int]$ExitCode = 0,
        [bool]$TimedOut = $false
    )

    [PSCustomObject]@{
        Name      = $Name
        Command   = "winget " + (Join-ProcessArguments -Arguments $Arguments)
        Arguments = [string[]]$Arguments
        ExitCode  = [int]$ExitCode
        TimedOut  = [bool]$TimedOut
        StdOut    = [string]$StdOut
        StdErr    = [string]$StdErr
    }
}

function Invoke-WingetterDiagnosticsCommandCapture {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 10
    )

    if (!(Get-Command Invoke-WinGetCapture -ErrorAction SilentlyContinue)) {
        return New-WingetterDiagnosticsCommandCapture -Name $Name -Arguments $Arguments -StdErr "Invoke-WinGetCapture is unavailable." -ExitCode -1
    }

    $capture = Invoke-WinGetCapture -Arguments $Arguments -TimeoutSeconds $TimeoutSeconds
    New-WingetterDiagnosticsCommandCapture -Name $Name -Arguments $Arguments -StdOut $capture.StdOut -StdErr $capture.StdErr -ExitCode $capture.ExitCode -TimedOut ([bool]$capture.TimedOut)
}

function Write-WingetterDiagnosticsCommandFiles {
    param(
        [string]$Root,
        [object]$Capture,
        [string]$BaseName,
        [string[]]$SensitiveValues = @()
    )

    $files = New-Object System.Collections.Generic.List[string]
    $files.Add((Write-WingetterDiagnosticsJsonFile -Root $Root -RelativePath "winget/$BaseName.json" -InputObject $Capture -SensitiveValues $SensitiveValues -Depth 8))
    $text = @(
        "Command: $($Capture.Command)",
        "ExitCode: $($Capture.ExitCode)",
        "TimedOut: $($Capture.TimedOut)",
        "",
        "== STDOUT ==",
        [string]$Capture.StdOut,
        "",
        "== STDERR ==",
        [string]$Capture.StdErr
    ) -join [Environment]::NewLine
    $files.Add((Write-WingetterDiagnosticsTextFile -Root $Root -RelativePath "winget/$BaseName.txt" -Content ($text + [Environment]::NewLine) -SensitiveValues $SensitiveValues))
    return [string[]]$files.ToArray()
}

function Get-WingetterDiagnosticsCatalogInfo {
    $categories = 0
    $apps = 0
    if ($Script:SoftwareDatabase) {
        $categories = @($Script:SoftwareDatabase.Keys).Count
        foreach ($category in $Script:SoftwareDatabase.Keys) {
            $apps += @($Script:SoftwareDatabase[$category]).Count
        }
    }

    $root = Get-WingetterRootPath
    $version = ""
    if (![string]::IsNullOrWhiteSpace($root)) {
        $launcherPath = Join-Path $root "Wingetter.ps1"
        if (Test-Path -LiteralPath $launcherPath) {
            $text = Get-Content -LiteralPath $launcherPath -Raw
            $match = [regex]::Match($text, '(?m)^\s*\.VERSION\s*\r?\n\s*(?<version>[^\r\n]+)')
            if ($match.Success) { $version = [string]$match.Groups["version"].Value.Trim() }
        }
    }

    [PSCustomObject][ordered]@{
        Schema              = "Wingetter.DiagnosticsCatalog.v1"
        GeneratedAtUtc      = (Get-Date).ToUniversalTime().ToString("o")
        WingetterVersion    = $version
        PowerShellVersion   = [string]$PSVersionTable.PSVersion
        OSVersion           = [string][Environment]::OSVersion.VersionString
        ProcessArchitecture = [string][System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
        CatalogCategories   = [int]$categories
        CatalogApps         = [int]$apps
        RootPath            = $root
    }
}

function Copy-WingetterDiagnosticsRecentLogs {
    param(
        [string]$Root,
        [string]$LogRoot,
        [string[]]$SensitiveValues = @(),
        [int]$Keep = 20,
        [int]$MaxBytes = 262144
    )

    $files = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($LogRoot) -or !(Test-Path -LiteralPath $LogRoot)) {
        return [string[]]$files.ToArray()
    }

    $rootFull = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $LogRoot).Path)
    $logs = @(Get-ChildItem -LiteralPath $LogRoot -Recurse -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First $Keep)
    foreach ($log in $logs) {
        try {
            $relative = [System.IO.Path]::GetFullPath($log.FullName).Substring($rootFull.Length).TrimStart("\", "/")
            if ([string]::IsNullOrWhiteSpace($relative)) { $relative = $log.Name }
            $targetRelative = "logs/" + ($relative -replace '[<>:"|?*]', '_')
            $content = ""
            if ($log.Length -gt $MaxBytes) {
                $stream = [System.IO.File]::OpenRead($log.FullName)
                try {
                    $buffer = New-Object byte[] $MaxBytes
                    $read = $stream.Read($buffer, 0, $buffer.Length)
                    $content = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $read)
                    $content = "[truncated to $MaxBytes bytes]" + [Environment]::NewLine + $content
                    $targetRelative = "$targetRelative.truncated.txt"
                } finally {
                    $stream.Dispose()
                }
            } else {
                $content = [System.IO.File]::ReadAllText($log.FullName)
            }
            $files.Add((Write-WingetterDiagnosticsTextFile -Root $Root -RelativePath $targetRelative -Content $content -SensitiveValues $SensitiveValues))
        } catch {}
    }
    return [string[]]$files.ToArray()
}

function Get-WingetterDiagnosticsUpdateCheckSummaries {
    param(
        [string]$UpdateCheckLogRoot,
        [int]$Keep = 10
    )

    $summaries = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrWhiteSpace($UpdateCheckLogRoot) -or !(Test-Path -LiteralPath $UpdateCheckLogRoot)) {
        return [object[]]$summaries.ToArray()
    }

    $logs = @(Get-ChildItem -LiteralPath $UpdateCheckLogRoot -Filter "*-update-check.json" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First $Keep)
    foreach ($log in $logs) {
        try {
            $json = Get-Content -LiteralPath $log.FullName -Raw | ConvertFrom-Json
            $summaries.Add([PSCustomObject][ordered]@{
                FileName                 = $log.Name
                CheckedAtUtc             = [string]$json.CheckedAtUtc
                SkippedForMeteredNetwork = [bool]$json.SkippedForMeteredNetwork
                DetectionMethod          = [string]$json.DetectionMethod
                ScanError                = [string]$json.ScanError
                Counts                   = $json.Counts
            })
        } catch {
            $summaries.Add([PSCustomObject][ordered]@{
                FileName = $log.Name
                Error    = $_.Exception.Message
            })
        }
    }
    return [object[]]$summaries.ToArray()
}

function Add-WingetterDiagnosticsMigrationReport {
    param(
        [string]$Root,
        [object]$LastRunReport = $null,
        [string]$LogRoot = "",
        [string[]]$SensitiveValues = @()
    )

    $files = New-Object System.Collections.Generic.List[string]
    if ($null -ne $LastRunReport) {
        $files.Add((Write-WingetterDiagnosticsJsonFile -Root $Root -RelativePath "last-run/migration-report.json" -InputObject $LastRunReport -SensitiveValues $SensitiveValues -Depth 10))
        if (Get-Command ConvertTo-WingetterMigrationMarkdown -ErrorAction SilentlyContinue) {
            $files.Add((Write-WingetterDiagnosticsTextFile -Root $Root -RelativePath "last-run/migration-report.md" -Content (ConvertTo-WingetterMigrationMarkdown -Report $LastRunReport) -SensitiveValues $SensitiveValues))
        }
        return [string[]]$files.ToArray()
    }

    if (![string]::IsNullOrWhiteSpace($LogRoot) -and (Test-Path -LiteralPath $LogRoot)) {
        $latest = @(Get-ChildItem -LiteralPath $LogRoot -Recurse -Filter "migration-report.json" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
        if ($latest.Count -gt 0) {
            $content = [System.IO.File]::ReadAllText($latest[0].FullName)
            $files.Add((Write-WingetterDiagnosticsTextFile -Root $Root -RelativePath "last-run/migration-report.latest.json" -Content $content -SensitiveValues $SensitiveValues))
        }
    }
    return [string[]]$files.ToArray()
}

function Export-WingetterDiagnosticsBundle {
    param(
        [string]$OutputPath = (Get-WingetterDiagnosticsDefaultOutputPath),
        [object]$SourcePolicy = (Get-WingetterSourcePolicy),
        [object]$LastRunReport = $null,
        [string]$AppDataRoot = (Get-WingetterAppDataPath),
        [string]$LogRoot = "",
        [string]$UpdateCheckLogRoot = "",
        [int]$RecentLogCount = 20,
        [int]$MaxLogFileBytes = 262144,
        [hashtable]$CommandCaptures = $null,
        [switch]$SkipLiveWinGet
    )

    if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Get-WingetterDiagnosticsDefaultOutputPath }
    if ([string]::IsNullOrWhiteSpace($LogRoot)) { $LogRoot = Get-WingetterDiagnosticsLogRoot -AppDataRoot $AppDataRoot }
    if ([string]::IsNullOrWhiteSpace($UpdateCheckLogRoot)) { $UpdateCheckLogRoot = Join-Path $LogRoot "update-checks" }

    $stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-diagnostics-" + [System.Guid]::NewGuid().ToString("N"))
    $files = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $sensitiveValues = Get-WingetterDiagnosticsSensitiveValues -SourcePolicy $SourcePolicy

    try {
        New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

        $files.Add((Write-WingetterDiagnosticsJsonFile -Root $stageRoot -RelativePath "metadata/catalog.json" -InputObject (Get-WingetterDiagnosticsCatalogInfo) -SensitiveValues $sensitiveValues))

        try {
            $settings = Get-WingetterSettings
            $files.Add((Write-WingetterDiagnosticsJsonFile -Root $stageRoot -RelativePath "metadata/settings.json" -InputObject $settings -SensitiveValues $sensitiveValues))
        } catch {
            $warnings.Add("Could not include settings: $($_.Exception.Message)")
        }

        try {
            $policyPath = Join-WingetterDiagnosticsPath -Root $stageRoot -RelativePath "source-policy/source-policy-redacted.json"
            $policyExport = Export-WingetterSourcePolicy -Policy $SourcePolicy -FilePath $policyPath
            $policyText = [System.IO.File]::ReadAllText($policyPath)
            [void](Write-WingetterDiagnosticsTextFile -Root $stageRoot -RelativePath "source-policy/source-policy-redacted.json" -Content $policyText -SensitiveValues $sensitiveValues)
            $files.Add("source-policy/source-policy-redacted.json")
            $files.Add((Write-WingetterDiagnosticsJsonFile -Root $stageRoot -RelativePath "source-policy/source-policy-summary.json" -InputObject $policyExport -SensitiveValues $sensitiveValues -Depth 8))
        } catch {
            $warnings.Add("Could not include source policy: $($_.Exception.Message)")
        }

        foreach ($file in @(Copy-WingetterDiagnosticsRecentLogs -Root $stageRoot -LogRoot $LogRoot -SensitiveValues $sensitiveValues -Keep $RecentLogCount -MaxBytes $MaxLogFileBytes)) {
            $files.Add($file)
        }
        $files.Add((Write-WingetterDiagnosticsJsonFile -Root $stageRoot -RelativePath "update-checks/update-check-summary.json" -InputObject (Get-WingetterDiagnosticsUpdateCheckSummaries -UpdateCheckLogRoot $UpdateCheckLogRoot) -SensitiveValues $sensitiveValues -Depth 8))
        foreach ($file in @(Add-WingetterDiagnosticsMigrationReport -Root $stageRoot -LastRunReport $LastRunReport -LogRoot $LogRoot -SensitiveValues $sensitiveValues)) {
            $files.Add($file)
        }

        $captureMap = if ($CommandCaptures) { $CommandCaptures } else { @{} }
        $commandSpecs = @(
            @{ Key = "info"; BaseName = "winget-info"; Arguments = @("--info") },
            @{ Key = "source-list"; BaseName = "source-list"; Arguments = (Add-WinGetCleanOutputArguments -Arguments @("source", "list", "--disable-interactivity")) },
            @{ Key = "pin-list"; BaseName = "pin-list"; Arguments = (Add-WinGetCleanOutputArguments -Arguments @("pin", "list", "--disable-interactivity")) }
        )
        foreach ($spec in $commandSpecs) {
            try {
                $capture = if ($captureMap.ContainsKey($spec.Key)) {
                    $captureMap[$spec.Key]
                } elseif ($SkipLiveWinGet) {
                    New-WingetterDiagnosticsCommandCapture -Name $spec.Key -Arguments $spec.Arguments -StdErr "Skipped by request." -ExitCode 0
                } else {
                    Invoke-WingetterDiagnosticsCommandCapture -Name $spec.Key -Arguments $spec.Arguments -TimeoutSeconds 10
                }
                foreach ($file in @(Write-WingetterDiagnosticsCommandFiles -Root $stageRoot -Capture $capture -BaseName $spec.BaseName -SensitiveValues $sensitiveValues)) {
                    $files.Add($file)
                }
            } catch {
                $warnings.Add("Could not capture $($spec.Key): $($_.Exception.Message)")
            }
        }

        try {
            if (Get-Command Get-WingetterSourceHealth -ErrorAction SilentlyContinue) {
                $sourceHealth = Get-WingetterSourceHealth -TimeoutSeconds 10 -SkipLiveProbe:$SkipLiveWinGet
                $files.Add((Write-WingetterDiagnosticsJsonFile -Root $stageRoot -RelativePath "source-health/source-health.json" -InputObject $sourceHealth -SensitiveValues $sensitiveValues -Depth 8))
            }
        } catch {
            $warnings.Add("Could not probe source health: $($_.Exception.Message)")
        }

        try {
            if (Get-Command Get-WingetterSelfUpdateStatus -ErrorAction SilentlyContinue) {
                $updateStatus = if ($SkipLiveWinGet) {
                    Get-WingetterSelfUpdateStatus -TimeoutSeconds 1 -ManifestUrl "http://localhost:0/skip"
                } else {
                    Get-WingetterSelfUpdateStatus -TimeoutSeconds 10
                }
                $files.Add((Write-WingetterDiagnosticsJsonFile -Root $stageRoot -RelativePath "metadata/self-update-status.json" -InputObject $updateStatus -SensitiveValues $sensitiveValues -Depth 8))
            }
        } catch {
            $warnings.Add("Could not check self-update status: $($_.Exception.Message)")
        }

        $manifest = [PSCustomObject][ordered]@{
            Schema              = "Wingetter.DiagnosticsBundle.v1"
            GeneratedAtUtc      = (Get-Date).ToUniversalTime().ToString("o")
            Files               = [string[]]@($files | Select-Object -Unique | Sort-Object)
            Redaction           = [PSCustomObject][ordered]@{
                Enabled             = $true
                SourceHeadersRedacted = $true
                SensitiveValueCount = @($sensitiveValues).Count
            }
            Warnings            = [string[]]$warnings.ToArray()
        }
        $files.Add((Write-WingetterDiagnosticsJsonFile -Root $stageRoot -RelativePath "manifest.json" -InputObject $manifest -SensitiveValues $sensitiveValues -Depth 8))

        $parent = Split-Path -Parent $OutputPath
        if (![string]::IsNullOrWhiteSpace($parent) -and !(Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($stageRoot, $OutputPath)

        return [PSCustomObject][ordered]@{
            Schema         = "Wingetter.DiagnosticsBundleResult.v1"
            ZipPath        = (Resolve-Path -LiteralPath $OutputPath).Path
            FileCount      = @($files | Select-Object -Unique).Count
            Files          = [string[]]@($files | Select-Object -Unique | Sort-Object)
            Warnings       = [string[]]$warnings.ToArray()
            RedactedValues = @($sensitiveValues).Count
        }
    } finally {
        if (Test-Path -LiteralPath $stageRoot) {
            $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
            $stageFull = [System.IO.Path]::GetFullPath($stageRoot)
            if ($stageFull.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $stageFull) -like "wingetter-diagnostics-*") {
                Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
