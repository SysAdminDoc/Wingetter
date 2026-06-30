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

- [ ] P2 - Add catalog freshness audit against live WinGet metadata
  Why: Static catalog validation catches local drift, but it does not prove all 765 curated IDs still resolve, still belong to the expected source, or still have trustworthy detail metadata.
  Evidence: `tools\Test-Catalog.ps1:192-279`; `catalog/winget.json`; Microsoft `winget show` docs; `microsoft/winget-cli` v1.29.280 source behavior.
  Touches: `tools\Test-Catalog.ps1`, `tools\Invoke-Validation.ps1`, `catalog\winget.json`, `src\Wingetter.Catalog.ps1`.
  Acceptance: a bounded opt-in audit samples or checks catalog IDs with `winget show --id --exact --source`, reports missing/renamed/source-drift/detail-metadata failures, caches results to avoid slow default validation, and never mutates the catalog automatically.
  Complexity: M

- [ ] P2 - Add profile/run lockfile exports for reproducible rebuilds
  Why: Profiles and migration reports record IDs/source/version state, but a rebuild can still drift when upstream manifests, installer hashes, or preserved WinGet 1.29 custom arguments change.
  Evidence: `src/Wingetter.Groups.ps1:137-269`; `src/Wingetter.OfflineCache.ps1:175-361`; WinGet 1.29 preserved custom/override release notes; Ninite/Patch My PC reporting patterns.
  Touches: `src\Wingetter.Groups.ps1`, `src\Wingetter.OfflineCache.ps1`, `src\Wingetter.WinGet.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-ProfileJson.ps1`, `tools\Test-OfflineCache.ps1`.
  Acceptance: after reviewed install/update/offline-cache runs, Wingetter can export a lockfile with package ID, source, resolved version, installer URL/hash when available, selected safe options, timestamp, and warnings; import shows drift before selecting packages.
  Complexity: L

- [ ] P2 - Persist window bounds with DPI and monitor safety checks
  Why: The main window currently starts centered at fixed 1450x920 dimensions, and package-manager users report off-screen or unstable window placement after UI changes and display scaling differences.
  Evidence: `src/Wingetter.Ui.ps1:780-781`; UniGetUI issue #4799.
  Touches: `src\Wingetter.Ui.ps1`, `src\Wingetter.Common.ps1`, `tools\Test-UiSmoke.ps1`.
  Acceptance: Wingetter saves main-window size/position/state under `%APPDATA%\Wingetter`, restores only when the bounds intersect a current monitor working area, clamps to minimum dimensions, and smoke tests cover invalid/off-screen saved bounds.
  Complexity: S

- [ ] P2 - Normalize noisy installer progress in operation logs
  Why: WinGet 1.29 `--no-progress` reduces CLI noise, but older WinGet builds and individual installers can still emit spinner/progress streams that make GUI logs hard to follow.
  Evidence: `src/Wingetter.WinGet.ps1:171-188`; `src/Wingetter.Ui.ps1:325-526`; UniGetUI issue #5004.
  Touches: `src\Wingetter.WinGet.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-WinGetRunner.ps1`, `tools\fixtures\winget\`.
  Acceptance: captured stdout/stderr records keep raw logs on disk but the GUI/log summary collapses repeated spinner/progress-only lines, preserves meaningful installer output, and tests cover common `|/-\` and carriage-return progress patterns.
  Complexity: M

## Research-Driven Additions

### P2

- [ ] P2 - Add editable source-policy allowlist and blocklist UI
  Why: Corporate source policy already exists but can only be toggled/exported in the UI, leaving source edits and blocklist maintenance to manual JSON changes.
  Evidence: `src\Wingetter.Sources.ps1:425-954`; `src\Wingetter.Ui.ps1:2739-2742`; Romanitho/Winget-AutoUpdate issue #1159; Microsoft `winget source` docs.
  Touches: `src\Wingetter.Sources.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-SourcePolicy.ps1`, `README.md`.
  Acceptance: a Source Policy dialog can add/edit/remove allowed sources and package/source block rules, validates names/URLs/priority/header redaction before save, imports/exports the existing schema, shows drift results, and preserves private headers only when explicitly requested.
  Complexity: M

- [ ] P2 - Add single-instance guard and activation handoff
  Why: Package-manager GUIs should not silently fail or race shared app-state/log paths when launched twice.
  Evidence: no `Mutex`/single-instance guard in repo scan; `src\Wingetter.Ui.ps1:985`; ChocolateyGUI issue #1099.
  Touches: `Wingetter.ps1`, `src\Wingetter.App.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-Catalog.ps1` or a focused helper test.
  Acceptance: first launch owns a named user-scoped mutex; a second launch sends an activation request to the existing window and exits with a clear status; if activation IPC fails, the second launch reports the lock owner and does not start package operations.
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

- [ ] P2 - Add profile compliance and drift report
  Why: Profiles, gallery imports, installed scans, pins, and source policy exist, but users cannot compare a desired profile against the current machine before deciding what to install, update, skip, or investigate.
  Evidence: `src\Wingetter.Groups.ps1:494-616`; `src\Wingetter.ProfileGallery.ps1`; `src\Wingetter.WinGet.ps1:692-925`; UniGetUI issue #5020; Ninite/Patch My PC reporting patterns.
  Touches: `src\Wingetter.Groups.ps1`, `src\Wingetter.ProfileGallery.ps1`, `src\Wingetter.WinGet.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-ProfileJson.ps1`, `tools\Test-WinGetRunner.ps1`.
  Acceptance: selecting a saved group, built-in group, or gallery profile can generate a no-mutation report with desired, installed, missing, current, update-available, extra, pinned, source-blocked, and unresolved package states; report exports JSON and Markdown; fixture tests cover stale metadata and source-blocked packages.
  Complexity: M

- [ ] P2 - Add structured package risk warnings
  Why: Package details show metadata warnings and SHA256 values, but WinGet is adding PUA warning semantics and users are asking package GUIs for pre-execution risk signals.
  Evidence: `src\Wingetter.WinGet.ps1:1079-1130`; `src\Wingetter.Ui.ps1:2171-2215`; microsoft/winget-cli PR #6293; Devolutions/UniGetUI issue #4822; SLSA package-manager supply-chain guidance.
  Touches: `src\Wingetter.WinGet.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-WinGetRunner.ps1`, `tools\fixtures\winget\`, `README.md`.
  Acceptance: `winget show/search --details` warning text and catalog risk notes map to severity-coded warnings shown in details and preflight; hard blocks are policy-driven, soft warnings remain reviewable, raw output is preserved in logs, and tests cover PUA, missing hash, unknown risk, and benign fixtures.
  Complexity: M

## Research-Driven Additions

### P1

- [ ] P1 - Make mutable app-state writes atomic and recoverable
  Why: Wingetter already has partial atomic writes, but settings and several update/report paths still use direct writes that can corrupt user state after a crash or interruption.
  Evidence: `src\Wingetter.Common.ps1:80-104`; `src\Wingetter.WinGet.ps1:936-958`; `src\Wingetter.UpdateWatcher.ps1:145-149`; NIST SSDF; SLSA package-management trust guidance.
  Touches: `src\Wingetter.Common.ps1`, `src\Wingetter.WinGet.ps1`, `src\Wingetter.Groups.ps1`, `src\Wingetter.Sources.ps1`, `src\Wingetter.UpdateWatcher.ps1`, `tools\Test-WinGetRunner.ps1`, `tools\Test-UpdateWatcher.ps1`, `tools\Test-SourcePolicy.ps1`.
  Acceptance: atomic write and corrupt-JSON recovery helpers live in `Common`; settings, groups, source policy, update policy, installed cache, update-check results, and user-facing JSON exports use same-directory temp plus replace; corrupt settings/policy/result files are moved aside; tests simulate interrupted and corrupt writes.
  Complexity: M

- [ ] P1 - Add WinGet source-health diagnostics and recovery guidance
  Why: Client readiness is now classified, but stale/offline/corrupt WinGet sources still appear as package failures unless source health is probed separately.
  Evidence: `src\Wingetter.WinGet.ps1:5-114`; `src\Wingetter.Diagnostics.ps1:309-424`; Microsoft WinGet troubleshooting docs; microsoft/winget-cli issues #6015 and #6329.
  Touches: `src\Wingetter.WinGet.ps1`, `src\Wingetter.Sources.ps1`, `src\Wingetter.Diagnostics.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-WinGetRunner.ps1`, `tools\Test-SourcePolicy.ps1`, `tools\Test-Diagnostics.ps1`.
  Acceptance: startup/status and diagnostics run bounded `winget source list/update` probes, classify ok/stale/offline/corrupt/auth-required/package-offline states, show non-mutating repair/reset guidance, include redacted source-health JSON in diagnostics, and cover fixture outputs/exit codes in tests.
  Complexity: M

### P2

- [ ] P2 - Add Wingetter self-update and provenance review
  Why: Launcher and release hashes are verified locally, but users cannot compare the running app or checked-in EXE to the current GitHub release/raw manifest from inside Wingetter.
  Evidence: `Wingetter.ps1:33-60`; `release\manifest.json`; README Quick Launch section; UniGetUI README; Patch My PC Home Updater; SLSA provenance guidance.
  Touches: `Wingetter.ps1`, `src\Wingetter.App.ps1`, `src\Wingetter.Diagnostics.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-ReleaseArtifact.ps1`, `tools\Test-LauncherManifest.ps1`.
  Acceptance: a non-mutating "Check Wingetter update" path fetches the release/raw manifest with a timeout, compares version/module/bundle hashes and Authenticode status, reports current/stale/tampered/unsigned states, writes diagnostics evidence, and never replaces files without explicit user action.
  Complexity: M

- [ ] P2 - Add scheduled update-policy editor UI
  Why: update-policy JSON supports deferrals and maintenance windows, but users cannot safely review or edit it from the WPF app.
  Evidence: `README.md:174`; `src\Wingetter.UpdateWatcher.ps1:120-153`; Winget-AutoUpdate policy/GUI docs; Patch My PC scheduler features.
  Touches: `src\Wingetter.UpdateWatcher.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-UpdateWatcher.ps1`, `tools\Test-UiSmoke.ps1`, `README.md`.
  Acceptance: a settings dialog edits global not-before, max deferrals, local maintenance windows, and per-package policy rows; validates UTC/local conversions and invalid windows; saves the existing schema; scheduled-task registration can consume the selected policy path; UI smoke covers invalid and saved policies.
  Complexity: M

- [ ] P2 - Add failed-run retry from the last migration report
  Why: migration reports capture per-package outcomes, but the UI cannot reselect only failed, cancelled, or unresolved rows for a fresh reviewed run.
  Evidence: `src\Wingetter.Groups.ps1:478-660`; `src\Wingetter.Ui.ps1:3515-3548`; Ninite Pro retry/current reporting; PDQ retry queue documentation.
  Touches: `src\Wingetter.Groups.ps1`, `src\Wingetter.WinGet.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-ProfileJson.ps1`, `tools\Test-UiSmoke.ps1`.
  Acceptance: after install/update completes, "Retry failed" builds a new preflight plan from last-run failed/cancelled/unresolved package IDs plus safe options/source, excludes successes/current rows, preserves original report links, and tests cover empty/no-failure and partial-failure runs.
  Complexity: M

- [ ] P2 - Add catalog curation diff and impact report
  Why: catalog validation proves current structure, but maintainers need a local review of package/category/source/profile impact before curated catalog changes land.
  Evidence: `catalog\winget.json`; `profiles\gallery.json`; `tools\Test-Catalog.ps1`; winstall package-list/search patterns.
  Touches: `tools\Test-Catalog.ps1`, `tools\Export-WingetterCatalog.ps1`, `catalog\winget.json`, `profiles\gallery.json`.
  Acceptance: a local tool compares current catalog/groups/profiles with `HEAD` or a supplied baseline and reports added, removed, renamed, category-moved, source/trust-changed, profile-referenced, README-count-drift, and validation-blocking deltas without mutating catalog data.
  Complexity: S
