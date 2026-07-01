# Roadmap - Wingetter

## Research-Driven Additions

### P2

### P3

- [ ] P3 - Extract UI strings after workflow tests exist
  Why: Full UI localization is not the next reliability bottleneck, but the current monolithic XAML/event module makes future localization expensive.
  Evidence: `src/Wingetter.Ui.ps1` line count; UniGetUI translation infrastructure; existing locale-independent WinGet result fixtures.
  Touches: `src\Wingetter.Ui.ps1`, `src\Wingetter.Resources.ps1` (new), `tools\Test-UiSmoke.ps1`.
  Acceptance: user-facing strings are centralized after UI smoke tests land; existing English UI behavior and accessibility names remain unchanged; no locale is added until extraction is covered.
  Complexity: L


