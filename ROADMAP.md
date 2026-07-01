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

- [ ] P3 - Prepare native WinGet DSC v3 PackageList export path
  Why: Current WinGet Configuration export uses schema `0.2.0` and per-package `Microsoft.WinGet.DSC/WinGetPackage`; native DSC v3 PackageList/Source/Pin resources are active upstream work that may simplify future reproducible exports.
  Evidence: `src\Wingetter.Configuration.ps1:55-91`; README WinGet Configuration section; microsoft/winget-cli issue #6289.
  Touches: `src\Wingetter.Configuration.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-ConfigurationExport.ps1`, `README.md`.
  Acceptance: configuration export has a feature-detected compatibility layer for native DSC v3 resources while defaulting to the current schema until stable; fixture tests cover current schema and simulated v3 resource availability without requiring prerelease WinGet on normal validation.
  Complexity: M

