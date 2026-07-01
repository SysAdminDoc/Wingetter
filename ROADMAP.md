# Roadmap - Wingetter

## Audit-Driven Items

### P2

- [ ] P2 - Save-WingetterSettings cannot clear values back to null
  Why: The merge loop skips null values, so once a settings property is set non-null, it can never be reset to null through the API. Window bounds can never be cleared/reset.
  Where: `src\Wingetter.Common.ps1` Save-WingetterSettings

- [ ] P2 - Save-WingetterSettings read-modify-write race condition
  Why: Two rapid settings saves (window close + settings toggle) can lose one change because each read-modify-write cycle isn't atomic.
  Where: `src\Wingetter.Common.ps1` Save-WingetterSettings

- [ ] P2 - Version string hardcoded in 4+ locations must be kept in sync manually
  Why: v6.1.0 appears in Wingetter.ps1, XAML title, splash, Resources.ps1, header version text. A version bump that misses one creates user-visible inconsistency.
  Where: `Wingetter.ps1`, `src\Wingetter.Ui.ps1`, `src\Wingetter.Resources.ps1`

### P3

- [ ] P3 - Log entries rendered with stale theme after toggle
  Why: Log entry row background colors (#183a2c etc.) are determined at render time but never updated if the user toggles the theme mid-session. Already-rendered entries show stale colors.
  Where: `src\Wingetter.Ui.ps1` $AddLogEntry closure

- [ ] P3 - ExportGroupAsPS1 generated script counts "already installed" as success
  Why: The generated PS1 checks $LASTEXITCODE before checking output text, so a 0-exit "already installed" is counted as $ok instead of $skip, making the summary inaccurate.
  Where: `src\Wingetter.Groups.ps1` Export-GroupAsPS1

- [ ] P3 - Ambiguous toolbar button labels for screen readers
  Why: Buttons labeled "Diag", "Policy", "Sources" are ambiguous without their ToolTips. Screen readers read Content text, not ToolTips.
  Where: `src\Wingetter.Ui.ps1` XAML toolbar buttons
