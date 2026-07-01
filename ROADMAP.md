# Roadmap - Wingetter

## Research-Driven Additions

### P2

- [ ] P2 - Add editable source-policy allowlist and blocklist UI
  Why: Corporate source policy already exists but can only be toggled/exported in the UI, leaving source edits and blocklist maintenance to manual JSON changes.
  Evidence: `src\Wingetter.Sources.ps1:425-954`; `src\Wingetter.Ui.ps1:2739-2742`; Romanitho/Winget-AutoUpdate issue #1159; Microsoft `winget source` docs.
  Touches: `src\Wingetter.Sources.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-SourcePolicy.ps1`, `README.md`.
  Acceptance: a Source Policy dialog can add/edit/remove allowed sources and package/source block rules, validates names/URLs/priority/header redaction before save, imports/exports the existing schema, shows drift results, and preserves private headers only when explicitly requested.
  Complexity: M

- [ ] P2 - Add scheduled update-policy editor UI
  Why: update-policy JSON supports deferrals and maintenance windows, but users cannot safely review or edit it from the WPF app.
  Evidence: `README.md:174`; `src\Wingetter.UpdateWatcher.ps1:120-153`; Winget-AutoUpdate policy/GUI docs; Patch My PC scheduler features.
  Touches: `src\Wingetter.UpdateWatcher.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-UpdateWatcher.ps1`, `tools\Test-UiSmoke.ps1`, `README.md`.
  Acceptance: a settings dialog edits global not-before, max deferrals, local maintenance windows, and per-package policy rows; validates UTC/local conversions and invalid windows; saves the existing schema; scheduled-task registration can consume the selected policy path; UI smoke covers invalid and saved policies.
  Complexity: M

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

