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
        "ExportReportBtn",
        "ImportBtn",
        "IncludePinnedCheck",
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

Write-Host "XAML validation passed."
