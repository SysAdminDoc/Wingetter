# Roadmap - Wingetter

Actionable work only. Historical and completed roadmap material is archived in CHANGELOG.md; blocked work is kept in Roadmap_Blocked.md.

## Actionable Items

- [ ] P3 - `Restore-WingetterWindowBounds` depends on System.Windows.Forms loaded by App.ps1
  Why: Common.ps1 references `[System.Windows.Forms.Screen]::AllScreens` but is loaded before App.ps1 calls `Add-Type -AssemblyName System.Windows.Forms`. Works in practice because the function is only called after runtime init, but is a latent ordering dependency.
  Where: `src\Wingetter.Common.ps1`, `src\Wingetter.App.ps1`
