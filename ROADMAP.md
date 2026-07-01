# Roadmap - Wingetter

## Audit-Driven Items

### P2

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
