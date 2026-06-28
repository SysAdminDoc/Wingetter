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

function Get-WingetterFileSha256 {
    param([string]$Path)

    $hashCommand = Get-Command Get-FileHash -ErrorAction SilentlyContinue
    if ($hashCommand) {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $stream = [System.IO.File]::OpenRead($resolvedPath)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hashBytes = $sha256.ComputeHash($stream)
            return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToUpperInvariant()
        } finally {
            if ($sha256 -is [System.IDisposable]) { $sha256.Dispose() }
        }
    } finally {
        $stream.Dispose()
    }
}
