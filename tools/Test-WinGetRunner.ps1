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
    "Join-ProcessArguments",
    "Set-ProcessArguments",
    "Get-SafeFileName",
    "Get-TextExcerpt",
    "Get-WinGetOperationStatus"
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
}

if ($failures.Count -gt 0) {
    Write-Host "WinGet runner validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "WinGet runner validation passed."
