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
    Show-WinGetInstallerGUI *> $null
}
