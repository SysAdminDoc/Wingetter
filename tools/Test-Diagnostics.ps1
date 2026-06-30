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
    "Wingetter.Catalog.ps1",
    "Wingetter.WinGet.ps1",
    "Wingetter.Groups.ps1",
    "Wingetter.Sources.ps1",
    "Wingetter.UpdateWatcher.ps1",
    "Wingetter.Diagnostics.ps1"
)) {
    $modulePath = Join-Path $SourceDir $moduleName
    if (!(Test-Path -LiteralPath $modulePath)) {
        Add-Failure "Missing source module '$moduleName'."
        continue
    }
    try {
        . (Resolve-Path -LiteralPath $modulePath).Path
    } catch {
        Add-Failure "Could not import '$moduleName': $($_.Exception.Message)"
    }
}

if ($failures.Count -eq 0) {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-diagnostics-test-" + [System.Guid]::NewGuid().ToString("N"))
    $extractRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-diagnostics-extract-" + [System.Guid]::NewGuid().ToString("N"))
    $zipPath = Join-Path $tempRoot "diagnostics.zip"
    try {
        $logRoot = Join-Path $tempRoot "logs"
        $updateRoot = Join-Path $logRoot "update-checks"
        New-Item -ItemType Directory -Path $updateRoot -Force | Out-Null
        Set-Content -Path (Join-Path $logRoot "winget-bootstrap-test.jsonl") -Value '{"Header":"Authorization=Bearer secret-token","Path":"C:\\Users\\operator"}' -Encoding UTF8
        [PSCustomObject]@{
            Schema       = "Wingetter.UpdateCheck.v1"
            CheckedAtUtc = "2026-06-30T00:00:00Z"
            Counts       = @{ Available = 1; Pinned = 0; SourceBlocked = 0 }
            ScanError    = ""
        } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $updateRoot "20260630-000000-000-test-update-check.json") -Encoding UTF8

        $privateSource = New-WingetterPrivateRestSourceDefinition -Name "corp" -Argument "https://packages.example.test/api" -Header "Authorization=Bearer secret-token"
        $policy = New-WingetterDefaultSourcePolicy
        $policy.CorporateMode = $true
        $policy.AllowedSources = @($privateSource)
        $policy.PrivateSources = @($privateSource)

        $report = New-WingetterMigrationReport `
            -ProfileName "Fixture" `
            -SelectedPackages @([PSCustomObject]@{ Name = "Internal Tool"; WingetId = "Internal.Tool" }) `
            -RunResults @([PSCustomObject]@{ PackageId = "Internal.Tool"; PackageName = "Internal Tool"; Status = "SUCCESS"; Action = "install"; ExitCode = 0; Command = "winget install --id Internal.Tool"; ResultPath = ""; StdOutExcerpt = ""; StdErrExcerpt = "" }) `
            -InstalledRecords @{} `
            -RunLogDir $logRoot

        $captures = @{
            "info" = New-WingetterDiagnosticsCommandCapture -Name "info" -Arguments @("--info") -StdOut "Windows Package Manager v1.29.280" -ExitCode 0
            "source-list" = New-WingetterDiagnosticsCommandCapture -Name "source-list" -Arguments @("source", "list", "--disable-interactivity") -StdOut "Name  Argument`ncorp  https://packages.example.test/api" -ExitCode 0
            "pin-list" = New-WingetterDiagnosticsCommandCapture -Name "pin-list" -Arguments @("pin", "list", "--disable-interactivity") -StdOut "There are no pins configured." -ExitCode 0
        }

        $result = Export-WingetterDiagnosticsBundle `
            -OutputPath $zipPath `
            -SourcePolicy $policy `
            -LastRunReport $report `
            -AppDataRoot $tempRoot `
            -LogRoot $logRoot `
            -UpdateCheckLogRoot $updateRoot `
            -CommandCaptures $captures

        if (!(Test-Path -LiteralPath $result.ZipPath) -or $result.FileCount -lt 8) {
            Add-Failure "Diagnostics bundle was not written with the expected file count."
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($result.ZipPath, $extractRoot)
        foreach ($requiredPath in @(
            "manifest.json",
            "metadata\catalog.json",
            "source-policy\source-policy-redacted.json",
            "source-policy\source-policy-summary.json",
            "update-checks\update-check-summary.json",
            "winget\winget-info.txt",
            "winget\source-list.txt",
            "winget\pin-list.txt",
            "last-run\migration-report.json"
        )) {
            if (!(Test-Path -LiteralPath (Join-Path $extractRoot $requiredPath))) {
                Add-Failure "Diagnostics bundle is missing '$requiredPath'."
            }
        }

        $combined = ""
        foreach ($file in @(Get-ChildItem -LiteralPath $extractRoot -Recurse -File)) {
            $combined += [System.IO.File]::ReadAllText($file.FullName)
        }
        if ($combined -like "*secret-token*" -or $combined -like "*Authorization=Bearer*") {
            Add-Failure "Diagnostics bundle leaked a private source header."
        }
        if ($combined -notlike "*<redacted*" -and $combined -notlike "*<redacted-header>*") {
            Add-Failure "Diagnostics bundle did not contain any redaction marker."
        }
        if ($combined -notlike "*Wingetter.DiagnosticsBundle.v1*") {
            Add-Failure "Diagnostics manifest schema was not present."
        }
    } finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Diagnostics validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Diagnostics validation passed."
