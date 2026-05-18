# Changelog

All notable changes to Wingetter will be documented in this file.

## [Unreleased]

- Added: `tools\Build-WingetterExe.ps1` to concatenate the dot-sourced `src\` modules into a single bundled launcher (and optionally run PS2EXE), plus `tools\Test-Bundle.ps1` that parses the bundle and verifies module-section presence; wired into CI.
- Added: Verifiable release artifact manifest at `release\manifest.json` with SHA256 hashes for `Wingetter.exe`, `Wingetter.ico`, and `icon.ico`, plus `tools\Test-ReleaseArtifact.ps1` (with `-Update` mode) and a CI step that fails on unexplained binary changes.
- Added: `release\README.md` documenting how to verify, update, and (re)build the checked-in `Wingetter.exe` from `Wingetter.ps1` via PS2EXE.
- Added: PSScriptAnalyzer CI gate with a project-tuned `PSScriptAnalyzerSettings.psd1` and `tools\Test-Analyzer.ps1` runner that enforces `PSAvoidAssignmentToAutomaticVariable`, `PSReviewUnusedParameter`, and security/correctness rules.
- Changed: Renamed shadowed `$profile`, `$error`, `$args`, and `$sender` variables across modules and tools; documented intentionally inert adapter/symmetry parameters with `[void]$param` markers.
- Added: Locale-independent WinGet result classification using documented HRESULTs, with the matched signal (`ExitCode`/`Text`/`Cancelled`/`None`) and exit-code meaning persisted on per-package result records.
- Added: Pin classification driven by the `Pin type` column token (`Blocking` / `Gating` / `Pinning` / `PinnedByManifest`) instead of English keywords, with text-pattern fallback.
- Added: `tools\fixtures\winget\` with English, German, and Spanish output samples for install/upgrade outcomes, multiple pin types, `winget list`, and `winget show`; `tools\Test-WinGetRunner.ps1` consumes the fixtures and verifies classification and parsed field extraction.
- Added: Generated catalog snapshots in `catalog/winget.json` and `catalog/groups.json`.
- Added: Catalog sync, export, and validation tools for package counts, duplicate IDs, built-in group references, embedded fallback freshness, README count drift, and changelog formatting.
- Added: Official WinGet import/export JSON support using `Sources`, `Packages`, and `PackageIdentifier`.
- Added: Profile JSON smoke tests for official WinGet JSON, Wingetter group JSON, and simple package ID arrays.
- Added: Structured install/update run logging with per-package stdout, stderr, JSON result records, command capture, exit code capture, and WinGet verbose log directory hints.
- Added: WinGet runner smoke tests for process argument handling and status classification.
- Added: Package detail panel backed by `winget show` and `winget list` for source, publisher, version, installer type, installer URL, SHA256, and metadata warnings.
- Added: Audited WinGet bootstrap logging under `%APPDATA%\Wingetter\logs`.
- Added: GitHub Actions validation for catalog, profile JSON, WinGet runner helpers, and WPF XAML loading.
- Added: Source modules under `src/` for common helpers, catalog data, WinGet operations, group/profile helpers, UI, and runtime bootstrap.
- Added: WinGet pin state lookup plus package detail controls for standard pins, blocking pins, installed-version pins, and pin removal.
- Added: Include pinned updates checkbox that passes `--include-pinned` during update runs.
- Added: Object-based installed package detection through `Microsoft.WinGet.Client` with `winget list` fallback and `%APPDATA%\Wingetter\installed-cache.json` scan caching.
- Added: Migration report generation for install/update runs, including GUI export to Markdown or JSON.
- Added: Metadata-rich local search scoring across names, IDs, categories, built-in groups, publisher-like ID prefixes, source/scope state, installed/update state, and pin state.
- Added: Search metadata validation script and CI coverage.
- Added: Visual/accessibility validation that rejects `CornerRadius=999` regressions and checks baseline automation names for key controls.
- Added: Package-source adapter contract with WinGet as the first registered backend and validation for the adapter/UI boundary.
- Added: Corporate source policy profile at `%APPDATA%\Wingetter\source-policy.json`, including allowed-source enforcement, explicit-source command generation, and `Microsoft.Rest` private source support.
- Added: Source policy export from the GUI and source policy validation coverage.
- Added: Scheduled update-check workflow with no auto-upgrades, metered-network skip support, pin/source-policy classification, JSON logs, log rotation, toast summaries, and scheduled-task registration scripts.
- Added: Offline download cache workflow using `winget download`, with GUI and CLI entry points, per-package download logs, `offline-manifest.json`, and generated `install-offline.ps1` replay script.
- Added: WinGet Configuration export using `Microsoft.WinGet.DSC/WinGetPackage` resources, with GUI and CLI entry points plus local validation coverage.
- Added: Public profile gallery with hashed checked-in profile files, package/source review, GUI import, and validation coverage.
- Changed: Local repo runs now prefer the generated catalog and group JSON when present, while retaining embedded module data as fallback.
- Changed: `Wingetter.ps1` is now a thin launcher that loads local modules or downloads the module set for raw GitHub quick-launch runs.
- Changed: `catalog/winget.json` and `catalog/groups.json` are now the curation source files; `tools/Sync-EmbeddedCatalog.ps1` regenerates the embedded module fallbacks.
- Changed: Profile JSON, WinGet runner, catalog, and XAML tests now validate the module split rather than extracting helpers from the launcher.
- Changed: WinGet runner tests now cover pin parsing and update argument generation for pinned updates.
- Changed: Installed app scan now tracks installed version, available version, source, scope when available, detection method, and scan timestamp instead of only package IDs.
- Changed: Profile JSON tests now cover migration report summary, package state, JSON export, and Markdown rendering.
- Changed: Search results are ranked inside each category when a query is active, while default catalog ordering is restored for empty searches.
- Changed: Replaced remaining pill-style text-bearing UI radii with bounded rectangular radii and added accessible names to the theme toggle and search box.
- Changed: GUI package details, official source profile import/export, install/update execution, installed scans, pin controls, and copied install commands now route through the package-source adapter instead of calling WinGet helpers directly.
- Changed: WinGet install/update/detail helpers can pass explicit `--source` values from catalog/source policy metadata.
- Changed: CI now validates update watcher summary classification, scheduled-task action arguments, and update-check log rotation.
- Changed: CI now validates offline cache argument generation, manifest export, replay script generation, and cache file delta tracking.
- Changed: CI now validates WinGet Configuration YAML generation.
- Changed: CI now validates profile gallery hashes, catalog references, preview text, and rejection of unsupported install-argument fields.
- Changed: Install/update execution now uses structured process arguments where available, captures stderr, passes `--verbose-logs`, and surfaces the run log directory after completion or cancellation.
- Changed: WinGet repair now prefers App Installer registration and `Microsoft.WinGet.Client` `Repair-WinGetPackageManager` instead of downloading GitHub/AppX assets directly.
- Changed: Synced README version badge, built-in groups, and category counts with the v6.1.0 script catalog.

## [v6.1.0] - 2026-03-13

- Added: Screenshot to README.
- Changed: Audit fixes and usability improvements.
- Changed: Flat single-column update view and fixed upgrade detection.
- Changed: Redesigned Update All as an update view with selectable installed apps.
- Changed: Grayed out installed apps and added an Update All button.
- Removed: Runtime `Write-Host` calls that caused popups in compiled EXE builds.
- Fixed: EXE compilation issues around Ellipse namespace usage and `.Add()` output.

## [v6.0.0] - 2026-03-13

- Changed: Major UI overhaul and new features.
