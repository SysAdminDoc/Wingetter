# Roadmap - Wingetter

## Audit-Driven Items

### P2

- [ ] P2 - Diagnostics bundle may miss header tokens in non-standard log positions
  Why: Header tokens in run log files are redacted via regex patterns, but tokens appearing in unexpected positions (e.g., stderr output, URL query parameters) may slip through the generic patterns.
  Where: `src\Wingetter.Diagnostics.ps1` redaction patterns

- [ ] P2 - WINGETTER_MODULE_BASE_URL env var enables download-source information leak
  Why: Any same-user process can set this env var to redirect module download requests to an attacker server. SHA256 hash verification prevents code execution but the attacker learns the user's IP and Wingetter usage.
  Where: `Wingetter.ps1` download path

- [ ] P2 - Top accent gradient bar never themed for light mode
  Why: The thin colored gradient bar at the very top of the window (green/blue/purple) stays fixed in both themes. Minor visual inconsistency.
  Where: `src\Wingetter.Ui.ps1` XAML lines ~1753-1755

### P3

- [ ] P3 - Run Plan dialog checkboxes use default WPF style instead of custom themed style
  Why: The plan review dialog creates checkboxes that inherit default WPF chrome instead of the main window's custom dark/light CheckBox template.
  Where: `src\Wingetter.Ui.ps1` Show-WingetterRunPlanDialog

- [ ] P3 - `$PumpUi` scriptblock is dead logic in background worker
  Why: The PumpUi parameter defaults to an empty scriptblock and is never set to anything useful by the UI tier. The 100ms polling loop serves only for cancel-checking.
  Where: `src\Wingetter.WinGet.ps1` Invoke-WinGetPackageOperation

- [ ] P3 - Embedded SoftwareDatabase in Catalog.ps1 can drift from external catalog JSON
  Why: The 765-app database is maintained both as PowerShell literals in source code and as JSON at catalog/winget.json. Sync requires running tools/Sync-EmbeddedCatalog.ps1 manually.
  Where: `src\Wingetter.Catalog.ps1`, `catalog\winget.json`

- [ ] P3 - `Restore-WingetterWindowBounds` depends on System.Windows.Forms loaded by App.ps1
  Why: Common.ps1 references `[System.Windows.Forms.Screen]::AllScreens` but is loaded before App.ps1 calls `Add-Type -AssemblyName System.Windows.Forms`. Works in practice because the function is only called after runtime init, but is a latent ordering dependency.
  Where: `src\Wingetter.Common.ps1`, `src\Wingetter.App.ps1`
