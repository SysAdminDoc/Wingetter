# Shared helpers for dot-sourced Wingetter modules.
function Get-WingetterRootPath {
    $rootVar = Get-Variable -Name WingetterRoot -Scope Script -ErrorAction SilentlyContinue
    if ($rootVar -and ![string]::IsNullOrWhiteSpace([string]$rootVar.Value)) {
        return [string]$rootVar.Value
    }
    if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return (Split-Path -Parent $PSScriptRoot)
    }
    return $null
}
