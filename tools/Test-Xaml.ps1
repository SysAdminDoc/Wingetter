param(
    [string]$UiModulePath = (Join-Path $PSScriptRoot "..\src\Wingetter.Ui.ps1")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$text = Get-Content -Path $UiModulePath -Raw
$match = [regex]::Match($text, '(?s)\$XAML = @"\r?\n(?<xaml>.*?)\r?\n"@')
if (!$match.Success) {
    Write-Host "XAML validation failed: XAML block not found." -ForegroundColor Red
    exit 1
}

try {
    Add-Type -AssemblyName PresentationFramework
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($match.Groups["xaml"].Value))
    $window = [Windows.Markup.XamlReader]::Load($reader)
    foreach ($requiredName in @(
        "CategoriesPanel",
        "PackageDetailsBorder",
        "LogPanelBorder",
        "InstallBtn",
        "ExportBtn",
        "ExportSourcesBtn",
        "DownloadCacheBtn",
        "ExportReportBtn",
        "ImportBtn",
        "GalleryBtn",
        "IncludePinnedCheck",
        "CorporateModeCheck",
        "DetailPinState",
        "PinPackageBtn",
        "PinBlockingBtn",
        "PinInstalledBtn",
        "RemovePinBtn"
    )) {
        if (!$window.FindName($requiredName)) {
            throw "Missing named XAML control '$requiredName'."
        }
    }
} catch {
    Write-Host "XAML validation failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

foreach ($requiredToken in @(
    "function Start-WingetterOperationWorker",
    "OperationRunning",
    "OperationCancelToken",
    "[System.Collections.Concurrent.ConcurrentQueue[object]]",
    "[System.Collections.Concurrent.ConcurrentDictionary[string,bool]]",
    ".BeginInvoke()"
)) {
    if ($text -notlike "*$requiredToken*") {
        Write-Host "XAML validation failed: async operation contract token '$requiredToken' not found." -ForegroundColor Red
        exit 1
    }
}

if ($text -match '-PumpUi\s+\{\s*\[System\.Windows\.Forms\.Application\]::DoEvents\(\)\s*\}') {
    Write-Host "XAML validation failed: package operation handlers must not pump UI with DoEvents." -ForegroundColor Red
    exit 1
}

$worker = $null
$stubRoot = $null
$previousWorkerSmokeRoot = $env:WINGETTER_WORKER_SMOKE_ROOT
try {
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms
    . $UiModulePath

    $stubRoot = Join-Path $env:TEMP ("wingetter-worker-smoke-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $stubRoot -Force | Out-Null
    $env:WINGETTER_WORKER_SMOKE_ROOT = $stubRoot
    Set-Content -Path (Join-Path $stubRoot "Wingetter.Common.ps1") -Value @'
function Get-WingetterRootPath { return $env:TEMP }
'@ -Encoding UTF8
    Set-Content -Path (Join-Path $stubRoot "Wingetter.WinGet.ps1") -Value @'
function New-WingetterRunLogDirectory {
    param([string]$Action)
    $path = Join-Path $env:WINGETTER_WORKER_SMOKE_ROOT ("log-" + $Action + "-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}
'@ -Encoding UTF8
    Set-Content -Path (Join-Path $stubRoot "Wingetter.Sources.ps1") -Value @'
function Get-WingetterPackageSourceAdapter {
    param([string]$Name)
    [PSCustomObject]@{ Name = $Name }
}
function Invoke-WingetterPackageSourcePackageOperation {
    param(
        [object]$SourceAdapter,
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
    [void]$InstallOptions
    foreach ($i in 1..80) {
        if (& $ShouldCancel) {
            return [PSCustomObject]@{
                Status = "CANCELLED"; Action = $Action; PackageId = $PackageId; PackageName = $PackageName; SourceName = $SourceName
                ExitCode = -1; Command = "fake"; ResultPath = ""; StdOutExcerpt = ""; StdErrExcerpt = ""
            }
        }
        Start-Sleep -Milliseconds 25
    }
    [PSCustomObject]@{
        Status = "SUCCESS"; Action = $Action; PackageId = $PackageId; PackageName = $PackageName; SourceName = $SourceName
        ExitCode = 0; Command = "fake"; ResultPath = ""; StdOutExcerpt = ""; StdErrExcerpt = ""
    }
}
function Get-WingetterPackageSourceInstalledCatalogPackages {
    [PSCustomObject]@{ Packages = @{} }
}
'@ -Encoding UTF8
    Set-Content -Path (Join-Path $stubRoot "Wingetter.Groups.ps1") -Value @'
function New-WingetterMigrationReport {
    param(
        [string]$ProfileName,
        [object[]]$SelectedPackages,
        [object[]]$RunResults,
        [hashtable]$InstalledRecords = @{},
        [string[]]$ImportWarnings = @(),
        [string]$RunLogDir = ""
    )
    [ordered]@{
        schema = "Wingetter.MigrationReport.v1"
        profileName = $ProfileName
        runLogDir = $RunLogDir
        summary = @{ selected = @($SelectedPackages).Count }
        packages = @($RunResults)
    }
}
function Export-WingetterMigrationReport {
    param([object]$Report, [string]$FilePath)
    $Report | ConvertTo-Json -Depth 8 | Set-Content -Path $FilePath -Encoding UTF8
}
'@ -Encoding UTF8
    Set-Content -Path (Join-Path $stubRoot "Wingetter.OfflineCache.ps1") -Value "" -Encoding UTF8

    $worker = Start-WingetterOperationWorker `
        -Mode "PackageOperation" `
        -SelectedPackages @([PSCustomObject]@{ Name = "Fake App"; WingetId = "Fake.App"; SourceName = "winget" }) `
        -PackageSourceName "winget" `
        -Operation "install" `
        -ModuleDirectory $stubRoot
    Start-Sleep -Milliseconds 100
    $worker.CancelToken["Cancelled"] = $true
    $deadline = [DateTime]::UtcNow.AddSeconds(8)
    while (-not $worker.Handle.IsCompleted -and [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 50
    }
    if (-not $worker.Handle.IsCompleted) { throw "Async operation worker did not stop after cancellation." }

    $messages = @()
    $item = $null
    while ($worker.Queue.TryDequeue([ref]$item)) { $messages += $item }
    if (-not @($messages | Where-Object { $_.Type -eq "Log" -and $_.Status -eq "CANCELLED" })) {
        throw "Async operation worker did not emit a cancellation log message."
    }
    $done = @($messages | Where-Object { $_.Type -eq "Done" } | Select-Object -Last 1)
    if ($done.Count -ne 1 -or -not [bool]$done[0].Cancelled) {
        throw "Async operation worker did not emit a cancelled done message."
    }
} catch {
    Write-Host "XAML validation failed: async worker smoke failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    if ($worker) {
        try {
            if ($worker.Handle -and $worker.Handle.IsCompleted) {
                $worker.PowerShell.EndInvoke($worker.Handle) | Out-Null
            } elseif ($worker.PowerShell) {
                $worker.PowerShell.Stop()
            }
        } catch {}
        try { if ($worker.PowerShell) { $worker.PowerShell.Dispose() } } catch {}
        try { if ($worker.Runspace) { $worker.Runspace.Close() } } catch {}
    }
    if ($stubRoot -and (Test-Path -LiteralPath $stubRoot)) {
        Remove-Item -LiteralPath $stubRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:WINGETTER_WORKER_SMOKE_ROOT = $previousWorkerSmokeRoot
}

Write-Host "XAML validation passed."
