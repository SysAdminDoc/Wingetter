# Roadmap - Wingetter

## Research-Driven Additions

### P2

- [ ] P2 - Prototype a read-only Scoop source adapter
  Why: The adapter contract exists but only WinGet is registered; Scoop is a high-signal adjacent ecosystem with buckets and portable-app semantics that should be proven read-only before install support.
  Evidence: `src/Wingetter.Sources.ps1:58-75`; `src/Wingetter.Sources.ps1:218-224`; UniGetUI README; Scoop README; Awesome Scoop.
  Touches: `src\Wingetter.Sources.ps1`, `src\Wingetter.Scoop.ps1` (new), `src\Wingetter.Ui.ps1`, `tools\Test-PackageSources.ps1`.
  Acceptance: if Scoop is installed, Wingetter can discover/search installed Scoop apps and show source-specific details under a capability flag; no Scoop install/update commands are emitted; tests use local fixture bucket data.
  Complexity: L

### P3

- [ ] P3 - Extract UI strings after workflow tests exist
  Why: Full UI localization is not the next reliability bottleneck, but the current monolithic XAML/event module makes future localization expensive.
  Evidence: `src/Wingetter.Ui.ps1` line count; UniGetUI translation infrastructure; existing locale-independent WinGet result fixtures.
  Touches: `src\Wingetter.Ui.ps1`, `src\Wingetter.Resources.ps1` (new), `tools\Test-UiSmoke.ps1`.
  Acceptance: user-facing strings are centralized after UI smoke tests land; existing English UI behavior and accessibility names remain unchanged; no locale is added until extraction is covered.
  Complexity: L

### P2

- [ ] P2 - Add profile/run lockfile exports for reproducible rebuilds
  Why: Profiles and migration reports record IDs/source/version state, but a rebuild can still drift when upstream manifests, installer hashes, or preserved WinGet 1.29 custom arguments change.
  Evidence: `src/Wingetter.Groups.ps1:137-269`; `src/Wingetter.OfflineCache.ps1:175-361`; WinGet 1.29 preserved custom/override release notes; Ninite/Patch My PC reporting patterns.
  Touches: `src\Wingetter.Groups.ps1`, `src\Wingetter.OfflineCache.ps1`, `src\Wingetter.WinGet.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-ProfileJson.ps1`, `tools\Test-OfflineCache.ps1`.
  Acceptance: after reviewed install/update/offline-cache runs, Wingetter can export a lockfile with package ID, source, resolved version, installer URL/hash when available, selected safe options, timestamp, and warnings; import shows drift before selecting packages.
  Complexity: L

## Research-Driven Additions

### P2

- [ ] P2 - Add editable source-policy allowlist and blocklist UI
  Why: Corporate source policy already exists but can only be toggled/exported in the UI, leaving source edits and blocklist maintenance to manual JSON changes.
  Evidence: `src\Wingetter.Sources.ps1:425-954`; `src\Wingetter.Ui.ps1:2739-2742`; Romanitho/Winget-AutoUpdate issue #1159; Microsoft `winget source` docs.
  Touches: `src\Wingetter.Sources.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-SourcePolicy.ps1`, `README.md`.
  Acceptance: a Source Policy dialog can add/edit/remove allowed sources and package/source block rules, validates names/URLs/priority/header redaction before save, imports/exports the existing schema, shows drift results, and preserves private headers only when explicitly requested.
  Complexity: M

- [ ] P2 - Split install/update and offline-cache operation state
  Why: One global `OperationRunning` flag blocks and reports installs, upgrades, and offline downloads the same way, even though downloads and mutating package operations need different queue and cancellation semantics.
  Evidence: `src\Wingetter.Ui.ps1:985`; `src\Wingetter.Ui.ps1:3263-3458`; Devolutions/UniGetUI issue #5025.
  Touches: `src\Wingetter.Ui.ps1`, `src\Wingetter.OfflineCache.ps1`, `src\Wingetter.WinGet.ps1`, `tools\Test-UiSmoke.ps1`.
  Acceptance: UI state tracks package operations and offline downloads separately, prevents overlapping mutating installs/upgrades, allows safe non-conflicting cache downloads, shows separate progress/cancel text, and smoke tests verify the enabled/disabled control matrix.
  Complexity: L

- [ ] P2 - Persist update-view sort and filter state
  Why: Update review is a repeated workflow, and users expect sort/order choices to survive refreshes instead of resetting during each update-mode rebuild.
  Evidence: `src\Wingetter.Ui.ps1:3553-3680`; Devolutions/UniGetUI issue #4984.
  Touches: `src\Wingetter.Ui.ps1`, `src\Wingetter.Common.ps1`, `tools\Test-UiSmoke.ps1`.
  Acceptance: update mode exposes explicit sort/filter controls for name, category, source, installed version, available version, and blocked/deferred status; choices persist under `%APPDATA%\Wingetter`; invalid saved state falls back safely.
  Complexity: M

### P3

- [ ] P3 - Prepare native WinGet DSC v3 PackageList export path
  Why: Current WinGet Configuration export uses schema `0.2.0` and per-package `Microsoft.WinGet.DSC/WinGetPackage`; native DSC v3 PackageList/Source/Pin resources are active upstream work that may simplify future reproducible exports.
  Evidence: `src\Wingetter.Configuration.ps1:55-91`; README WinGet Configuration section; microsoft/winget-cli issue #6289.
  Touches: `src\Wingetter.Configuration.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-ConfigurationExport.ps1`, `README.md`.
  Acceptance: configuration export has a feature-detected compatibility layer for native DSC v3 resources while defaulting to the current schema until stable; fixture tests cover current schema and simulated v3 resource availability without requiring prerelease WinGet on normal validation.
  Complexity: M

## Research-Driven Additions

### P2

- [ ] P2 - Add reviewed uninstall workflow with safety preflight
  Why: The WinGet source adapter already exposes uninstall, but the UI and run-plan gate only support install/update; upstream WinGet issues show uninstall can affect dependencies and portable PATH links if exposed without review.
  Evidence: `src\Wingetter.Sources.ps1:144-162`; `src\Wingetter.WinGet.ps1:280-401`; `src\Wingetter.Ui.ps1:3458-3548`; Microsoft WinGet uninstall docs; microsoft/winget-cli issues #6116, #6215, and #6247; ChocolateyGUI issue #900.
  Touches: `src\Wingetter.WinGet.ps1`, `src\Wingetter.Sources.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-WinGetRunner.ps1`, `tools\Test-PackageSources.ps1`, `tools\Test-UiSmoke.ps1`.
  Acceptance: installed packages can be selected for a reviewed uninstall plan that refuses non-installed packages, shows command/source/detection details, warns on dependency and portable PATH/symlink risk, exports the preflight plan, and only runs selected safe rows after confirmation; tests cover uninstall args, blocked rows, and fixture warning parsing.
  Complexity: L

## Research-Driven Additions

### P2

- [ ] P2 - Add scheduled update-policy editor UI
  Why: update-policy JSON supports deferrals and maintenance windows, but users cannot safely review or edit it from the WPF app.
  Evidence: `README.md:174`; `src\Wingetter.UpdateWatcher.ps1:120-153`; Winget-AutoUpdate policy/GUI docs; Patch My PC scheduler features.
  Touches: `src\Wingetter.UpdateWatcher.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-UpdateWatcher.ps1`, `tools\Test-UiSmoke.ps1`, `README.md`.
  Acceptance: a settings dialog edits global not-before, max deferrals, local maintenance windows, and per-package policy rows; validates UTC/local conversions and invalid windows; saves the existing schema; scheduled-task registration can consume the selected policy path; UI smoke covers invalid and saved policies.
  Complexity: M


