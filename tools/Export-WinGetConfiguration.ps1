param(
    [Parameter(Mandatory = $true)][string[]]$PackageId,
    [string]$FilePath = (Join-Path (Get-Location) "configuration.winget"),
    [string]$SourceName = "winget"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceDir = Join-Path $PSScriptRoot "..\src"
foreach ($moduleName in @(
    "Wingetter.Configuration.ps1"
)) {
    . (Resolve-Path (Join-Path $sourceDir $moduleName)).Path
}

$entries = @($PackageId | ForEach-Object {
    New-WingetterConfigurationPackageEntry -Name $_ -PackageId $_ -SourceName $SourceName
})
Export-WingetterConfigurationFile -PackageEntries $entries -FilePath $FilePath | Out-Null
Write-Host "Exported WinGet Configuration to $FilePath"
