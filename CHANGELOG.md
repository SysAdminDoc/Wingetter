# Changelog

All notable changes to Wingetter will be documented in this file.

## [Unreleased]

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
- Changed: Local repo runs now prefer the generated catalog and group JSON when present, while retaining embedded module data as fallback.
- Changed: `Wingetter.ps1` is now a thin launcher that loads local modules or downloads the module set for raw GitHub quick-launch runs.
- Changed: `catalog/winget.json` and `catalog/groups.json` are now the curation source files; `tools/Sync-EmbeddedCatalog.ps1` regenerates the embedded module fallbacks.
- Changed: Profile JSON, WinGet runner, catalog, and XAML tests now validate the module split rather than extracting helpers from the launcher.
- Changed: WinGet runner tests now cover pin parsing and update argument generation for pinned updates.
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
