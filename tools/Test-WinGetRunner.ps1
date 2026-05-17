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

$modulePath = Join-Path $SourceDir "Wingetter.WinGet.ps1"
if (!(Test-Path $modulePath)) {
    Add-Failure "Missing source module 'Wingetter.WinGet.ps1'."
} else {
    try {
        . (Resolve-Path $modulePath).Path
    } catch {
        Add-Failure "Could not import 'Wingetter.WinGet.ps1': $($_.Exception.Message)"
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

    $upgradeArgs = New-WinGetPackageOperationArguments -Action "upgrade" -PackageId "Google.Chrome" -Silent $true -AcceptAgreements $true -IncludePinned $true
    if ($upgradeArgs -notcontains "--include-pinned") {
        Add-Failure "Upgrade arguments did not include --include-pinned when requested."
    }
    $installArgs = New-WinGetPackageOperationArguments -Action "install" -PackageId "Google.Chrome" -Silent $false -AcceptAgreements $false -IncludePinned $true
    if ($installArgs -contains "--include-pinned") {
        Add-Failure "Install arguments unexpectedly included --include-pinned."
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
