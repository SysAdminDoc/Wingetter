# ============================================================================
# RUNTIME BOOTSTRAP
# ============================================================================

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
