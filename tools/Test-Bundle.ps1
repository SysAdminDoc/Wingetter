param(
    [string]$RepoRoot = (Join-Path $PSScriptRoot "..")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path $RepoRoot).Path
$bundlePath = Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-bundle-test-" + [System.Guid]::NewGuid().ToString("N") + ".ps1")

$buildScript = Join-Path $repoRoot "tools\Build-WingetterExe.ps1"
if (!(Test-Path $buildScript)) {
    Write-Host "Missing tools\Build-WingetterExe.ps1." -ForegroundColor Red
    exit 1
}

try {
    & pwsh -NoProfile -File $buildScript -RepoRoot $repoRoot -BundleOutput $bundlePath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build script exited $LASTEXITCODE while bundling." -ForegroundColor Red
        exit 1
    }

    if (!(Test-Path $bundlePath)) {
        Write-Host "Build script did not produce bundle at $bundlePath." -ForegroundColor Red
        exit 1
    }

    $bundle = Get-Content -Path $bundlePath -Raw
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseInput($bundle, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) {
        Write-Host "Bundled script failed to parse:" -ForegroundColor Red
        foreach ($parseError in $parseErrors) {
            Write-Host (" - line {0}: {1}" -f $parseError.Extent.StartLineNumber, $parseError.Message) -ForegroundColor Red
        }
        exit 1
    }

    $launcherPath = Join-Path $repoRoot "Wingetter.ps1"
    $launcherText = Get-Content -Path $launcherPath -Raw
    $listMatch = [regex]::Match($launcherText, '(?ms)\$Script:WingetterModuleFiles\s*=\s*@\((?<list>.*?)\)')
    if (!$listMatch.Success) {
        Write-Host "Could not parse module list from Wingetter.ps1." -ForegroundColor Red
        exit 1
    }
    $expectedModules = @(
        ($listMatch.Groups['list'].Value -split ',') |
            ForEach-Object { $_.Trim().Trim('"').Trim("'") } |
            Where-Object { $_ -and $_.EndsWith('.ps1') }
    )

    $missing = @()
    foreach ($module in $expectedModules) {
        $marker = "# ===== BEGIN $module ====="
        if ($bundle.IndexOf($marker, [System.StringComparison]::Ordinal) -lt 0) {
            $missing += $module
        }
    }
    if ($missing.Count -gt 0) {
        Write-Host ("Bundled script is missing module sections: " + ($missing -join ", ")) -ForegroundColor Red
        exit 1
    }

    if ($bundle.IndexOf("Start-Wingetter", [System.StringComparison]::Ordinal) -lt 0) {
        Write-Host "Bundled script does not call Start-Wingetter." -ForegroundColor Red
        exit 1
    }

    Write-Host "Bundle validation passed ($($expectedModules.Count) modules, $($bundle.Length) bytes)."
} finally {
    if (Test-Path $bundlePath) { Remove-Item -Path $bundlePath -Force -ErrorAction SilentlyContinue }
}
