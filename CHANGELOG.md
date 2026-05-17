# Changelog

All notable changes to Wingetter will be documented in this file.

## [Unreleased]

- Added: Generated catalog snapshots in `catalog/winget.json` and `catalog/groups.json`.
- Added: Catalog sync, export, and validation tools for package counts, duplicate IDs, built-in group references, embedded fallback freshness, README count drift, and changelog formatting.
- Changed: Local repo runs now prefer the generated catalog and group JSON when present, while retaining embedded data as the one-file fallback.
- Changed: `catalog/winget.json` and `catalog/groups.json` are now the curation source files; `tools/Sync-EmbeddedCatalog.ps1` regenerates the embedded fallback.
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
