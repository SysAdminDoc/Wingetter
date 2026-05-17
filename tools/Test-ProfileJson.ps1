param(
    [string]$ScriptPath = (Join-Path $PSScriptRoot "..\Wingetter.ps1")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
}

function Assert-EqualArray {
    param(
        [string[]]$Actual,
        [string[]]$Expected,
        [string]$Name
    )
    if ($Actual.Count -ne $Expected.Count) {
        Add-Failure "$Name count mismatch: expected $($Expected.Count), got $($Actual.Count)."
        return
    }
    for ($i = 0; $i -lt $Expected.Count; $i++) {
        if ($Actual[$i] -ne $Expected[$i]) {
            Add-Failure "$Name item $i mismatch: expected '$($Expected[$i])', got '$($Actual[$i])'."
        }
    }
}

$scriptText = [System.IO.File]::ReadAllText((Resolve-Path $ScriptPath).Path)
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptText, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) {
    foreach ($error in $parseErrors) {
        Add-Failure "PowerShell parser error at line $($error.Extent.StartLineNumber): $($error.Message)"
    }
}

$requiredFunctions = @(
    "Get-JsonPropertyValue",
    "Import-PackageIdsFromJSON",
    "Export-GroupAsWinGetJSON",
    "Export-GroupAsJSON"
)

foreach ($functionName in $requiredFunctions) {
    $functionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
    }, $true)

    if (!$functionAst) {
        Add-Failure "Could not find function '$functionName' in $ScriptPath."
        continue
    }

    Invoke-Expression $functionAst.Extent.Text
}

if ($failures.Count -eq 0) {
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("WingetterProfileJson_" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    try {
        $ids = [string[]]@("Google.Chrome", "Mozilla.Firefox", "7zip.7zip")

        $wingetPath = Join-Path $tempDir "winget-import.json"
        Export-GroupAsWinGetJSON -GroupName "Smoke" -PackageIds $ids -FilePath $wingetPath
        $wingetJson = Get-Content -Path $wingetPath -Raw | ConvertFrom-Json
        if ($wingetJson.'$schema' -ne "https://aka.ms/winget-packages.schema.2.0.json") {
            Add-Failure "Official WinGet JSON export has the wrong `$schema value."
        }
        $wingetPackages = @($wingetJson.Sources[0].Packages | ForEach-Object { $_.PackageIdentifier })
        Assert-EqualArray -Actual $wingetPackages -Expected $ids -Name "Official export package IDs"

        $wingetImport = Import-PackageIdsFromJSON -Content $wingetJson -FallbackGroupName "Smoke"
        Assert-EqualArray -Actual $wingetImport.PackageIds -Expected $ids -Name "Official import package IDs"
        if ($wingetImport.Format -ne "WinGet import JSON") {
            Add-Failure "Official import format was '$($wingetImport.Format)'."
        }

        $wingetterPath = Join-Path $tempDir "wingetter-group.json"
        Export-GroupAsJSON -GroupName "Smoke" -PackageIds $ids -FilePath $wingetterPath
        $wingetterJson = Get-Content -Path $wingetterPath -Raw | ConvertFrom-Json
        if ($wingetterJson.Schema -ne "Wingetter.Group.v1") {
            Add-Failure "Wingetter group JSON export has the wrong schema."
        }
        $wingetterImport = Import-PackageIdsFromJSON -Content $wingetterJson -FallbackGroupName "Smoke"
        Assert-EqualArray -Actual $wingetterImport.PackageIds -Expected $ids -Name "Wingetter import package IDs"
        if ($wingetterImport.GroupName -ne "Smoke") {
            Add-Failure "Wingetter import group name was '$($wingetterImport.GroupName)'."
        }

        $arrayImport = Import-PackageIdsFromJSON -Content $ids -FallbackGroupName "Array"
        Assert-EqualArray -Actual $arrayImport.PackageIds -Expected $ids -Name "Array import package IDs"
    } finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Profile JSON validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Profile JSON validation passed."
