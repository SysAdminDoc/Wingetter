# ============================================================================
# RUNTIME BOOTSTRAP
# ============================================================================

function Get-WingetterSelfUpdateStatus {
    param(
        [string]$ManifestUrl = "https://raw.githubusercontent.com/SysAdminDoc/Wingetter/main/release/manifest.json",
        [int]$TimeoutSeconds = 10,
        [string]$LocalManifestPath = ""
    )

    $localVersion = "unknown"
    $localBundleHash = ""
    try {
        $root = Get-WingetterRootPath
        if ($root) {
            $localManifest = Join-Path $root "release\manifest.json"
            if (![string]::IsNullOrWhiteSpace($LocalManifestPath)) { $localManifest = $LocalManifestPath }
            if (Test-Path -LiteralPath $localManifest) {
                $local = Get-Content -LiteralPath $localManifest -Raw | ConvertFrom-Json
                $localVersion = [string]$local.version
                $localBundleHash = [string]$local.build.bundle.sha256
            }
        }
    } catch {}

    $remoteVersion = ""
    $remoteBundleHash = ""
    $fetchError = ""
    try {
        $response = Invoke-WebRequest -Uri $ManifestUrl -UseBasicParsing -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        $remote = $response.Content | ConvertFrom-Json
        $remoteVersion = [string]$remote.version
        $remoteBundleHash = [string]$remote.build.bundle.sha256
    } catch {
        $fetchError = $_.Exception.Message
    }

    $status = "Unknown"
    if (![string]::IsNullOrWhiteSpace($fetchError)) {
        $status = "FetchFailed"
    } elseif ($localVersion -eq $remoteVersion -and $localBundleHash -eq $remoteBundleHash) {
        $status = "Current"
    } elseif ($localVersion -ne $remoteVersion) {
        $status = "UpdateAvailable"
    } elseif ($localBundleHash -ne $remoteBundleHash) {
        $status = "HashMismatch"
    }

    $authenticode = [PSCustomObject]@{ Status = "Unknown"; Subject = ""; Thumbprint = "" }
    try {
        $exePath = if ($root) { Join-Path $root "Wingetter.exe" } else { "" }
        if (![string]::IsNullOrWhiteSpace($exePath) -and (Test-Path -LiteralPath $exePath)) {
            $sig = Get-AuthenticodeSignature -FilePath $exePath -ErrorAction SilentlyContinue
            if ($sig) {
                $authenticode = [PSCustomObject]@{
                    Status     = [string]$sig.Status
                    Subject    = if ($sig.SignerCertificate) { [string]$sig.SignerCertificate.Subject } else { "" }
                    Thumbprint = if ($sig.SignerCertificate) { [string]$sig.SignerCertificate.Thumbprint } else { "" }
                }
            }
        }
    } catch {}

    [PSCustomObject][ordered]@{
        Schema            = "Wingetter.SelfUpdateStatus.v1"
        CheckedAtUtc      = (Get-Date).ToUniversalTime().ToString("o")
        Status            = $status
        LocalVersion      = $localVersion
        RemoteVersion     = $remoteVersion
        LocalBundleHash   = $localBundleHash
        RemoteBundleHash  = $remoteBundleHash
        FetchError        = $fetchError
        Authenticode      = $authenticode
        ManifestUrl       = $ManifestUrl
    }
}

function Initialize-WingetterRuntime {
    if (-not ("Native.Win32" -as [type])) {
        $memberDefinition = @(
            '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();',
            '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
        ) -join [Environment]::NewLine
        Add-Type -Name Win32 -Namespace Native -MemberDefinition $memberDefinition
    }
    try {
        $hwnd = [Native.Win32]::GetConsoleWindow()
        if ($hwnd -ne [IntPtr]::Zero) { [Native.Win32]::ShowWindow($hwnd, 0) | Out-Null }
    } catch {}

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Windows.Forms
}

function Start-Wingetter {
    Initialize-WingetterRuntime

    $mutexName = "Local\Wingetter_SingleInstance_$([System.Environment]::UserName)"
    $createdNew = $false
    $mutex = $null
    try {
        $mutex = [System.Threading.Mutex]::new($true, $mutexName, [ref]$createdNew)
    } catch {
        $createdNew = $false
    }

    if (-not $createdNew) {
        try {
            $existingProcesses = @(Get-Process | Where-Object {
                $_.MainWindowTitle -like "Wingetter*"
            } | Select-Object -First 1)
            if ($existingProcesses.Count -gt 0) {
                $hwnd = $existingProcesses[0].MainWindowHandle
                if ($hwnd -ne [IntPtr]::Zero) {
                    if (-not ("Native.Win32Activate" -as [type])) {
                        Add-Type -Name Win32Activate -Namespace Native -MemberDefinition @(
                            '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);',
                            '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);',
                            '[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);'
                        ) -join [Environment]::NewLine
                    }
                    if ([Native.Win32Activate]::IsIconic($hwnd)) {
                        [Native.Win32Activate]::ShowWindow($hwnd, 9) | Out-Null
                    }
                    [Native.Win32Activate]::SetForegroundWindow($hwnd) | Out-Null
                }
            }
        } catch {}
        [System.Windows.MessageBox]::Show(
            "Wingetter is already running. The existing window has been brought to the foreground.",
            "Wingetter",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
        return
    }

    try {
        Show-WinGetInstallerGUI *> $null
    } finally {
        if ($null -ne $mutex) {
            try { $mutex.ReleaseMutex() } catch {}
            $mutex.Dispose()
        }
    }
}
