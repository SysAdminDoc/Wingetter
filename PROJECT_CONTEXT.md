# Wingetter Project Context

Last consolidated: 2026-05-17.

## Purpose

Wingetter is a Windows-first PowerShell/WPF GUI for discovering, selecting, grouping, exporting, installing, and updating applications through Windows Package Manager (`winget`). The product stance is "Ninite-style batch setup with deeper WinGet coverage and reusable local profiles."

## Canonical Current State

- Repository: `SysAdminDoc/Wingetter`, public GitHub repo, default branch `main`.
- Launcher: [Wingetter.ps1](Wingetter.ps1), a PowerShell 5.1+ entry point that loads dot-sourced modules from `src/`.
- Source modules: `src/Wingetter.Common.ps1`, `src/Wingetter.Catalog.ps1`, `src/Wingetter.WinGet.ps1`, `src/Wingetter.Groups.ps1`, `src/Wingetter.Ui.ps1`, and `src/Wingetter.App.ps1`.
- Current runtime version shown in the script UI: `v6.1.0`.
- Local catalog: 765 unique `WingetId` entries across 39 categories.
- Generated catalog snapshots: `catalog/winget.json` and `catalog/groups.json`.
- Embedded module fallback sync command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Sync-EmbeddedCatalog.ps1`.
- Validation command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Catalog.ps1`.
- CI workflow: `.github/workflows/validate.yml` runs catalog sync/count validation, profile JSON tests, WinGet runner helper tests, and WPF XAML load validation on Windows.
- Built-in groups in code: Essential PC Setup, Web Developer, Python Developer, Creative Suite, Gaming PC, Privacy & Security, System Admin, Streaming Setup, Office & Productivity, and 3D Printing Workshop.
- Persisted user groups: `%APPDATA%\Wingetter\groups.json`.
- Icon cache: `%TEMP%\WingetterIcons`.
- Export formats: official WinGet import JSON, Wingetter group JSON, and standalone PowerShell installer script.
- Import formats: official WinGet import/export JSON, Wingetter group JSON, and simple package ID arrays.
- The root README version badge, category counts, and built-in group names are synced to the v6.1.0 catalog as of 2026-05-17.
- `CLAUDE.md` and `AGENTS.md` exist locally but are ignored/untracked. They are tool-specific working notes, not canonical shipped docs.

## Architecture

Wingetter is now a launcher plus dot-sourced modules:

- `Wingetter.ps1` resolves the module directory, dot-sources the modules in order, and calls `Start-Wingetter`.
- Local checkout runs use `src/` directly. Raw `irm .../Wingetter.ps1 | iex` runs download the same module set from `https://raw.githubusercontent.com/SysAdminDoc/Wingetter/main/src` unless `WINGETTER_MODULE_BASE_URL` overrides it.
- `src/Wingetter.Common.ps1` owns shared root-path resolution.
- `src/Wingetter.Catalog.ps1` owns catalog conversion and the embedded catalog fallback.
- `src/Wingetter.WinGet.ps1` owns WinGet detection, bootstrap repair, command capture, result logging, installed version lookup, and package detail parsing.
- `src/Wingetter.Groups.ps1` owns saved groups, profile import/export, official WinGet JSON import/export, and built-in group fallback data.
- `src/Wingetter.Ui.ps1` owns splash/icon helpers, WPF theme definitions, XAML, event wiring, installed-app scan UI, and package detail presentation.
- `src/Wingetter.App.ps1` owns runtime initialization and starts the GUI.
- `catalog/winget.json` and `catalog/groups.json` are the curation source files.
- Local checkout runs prefer `catalog/winget.json` and `catalog/groups.json` if present and fall back to embedded module data if those files are unavailable or malformed.
- Search filters app name and WinGet ID only.
- Installs and updates run serially by launching `winget install` or `winget upgrade` with `--id`, `--exact`, and optional `--silent` / agreement flags.
- Install/update execution writes per-package stdout, stderr, and JSON result files under `%APPDATA%\Wingetter\logs\<timestamp>-<action>`, passes `--verbose-logs`, and records command, action, package ID, exit code, status, stdout/stderr excerpts, cancellation state, run log directory, and WinGet diagnostic log directory when available.
- Each completed or cancelled install/update run also builds a `Wingetter.MigrationReport.v1` report, writes `migration-report.json` into the run log directory, and enables GUI export as Markdown or JSON. Reports include selected packages, status counts, commands, result paths, version/source/scope state where available, scan timestamps, and import warnings.
- WinGet bootstrap/repair now tries documented App Installer registration, then the `Microsoft.WinGet.Client` PowerShell module with `Repair-WinGetPackageManager -Force -Latest`, logs JSONL audit entries under `%APPDATA%\Wingetter\logs`, and falls back to the Microsoft Store App Installer page for manual follow-up.
- Installed app detection runs in a background runspace using `Microsoft.WinGet.Client` `Get-WinGetPackage` object data when available, falls back to `winget list --source winget`, and writes `%APPDATA%\Wingetter\installed-cache.json` with package ID, installed version, available version, source, scope when available, detection method, and scan timestamp.
- Icons are loaded lazily across a 4-worker runspace pool from Google favicon URLs, with letter placeholders before network fetches complete.
- Profile import/export helpers now support the official WinGet JSON hierarchy: `Sources`, `Packages`, `PackageIdentifier`, and optional `Version` fields are accepted on import; exports generate a `https://aka.ms/winget-packages.schema.2.0.json` file with the `winget` source details.
- Clicking an app row opens a package detail panel that uses `winget show --id <id> --exact` plus `winget list --id <id> --exact` to surface source, publisher, installed/latest version, installer type, installer URL, SHA256, homepage fallback, and metadata warnings.
- The same package detail panel now shows WinGet pin state from `winget pin list --id <id> --exact` and can add standard pins, blocking pins, installed-version pins, or remove a pin. Update runs can opt into `--include-pinned`.

## Verified Strengths

- Fast zero-install entry point: the README supports direct `irm ... | iex` execution.
- Broad curated local catalog with no duplicate package IDs.
- Familiar dark/light WPF UI with categories, sidebar navigation, collapsible sections, selection state, update review mode, log panel, and toast notification.
- Useful profile primitives exist: save/load groups, import official WinGet JSON, import Wingetter JSON, export official WinGet JSON, export Wingetter JSON, export PowerShell installer script, and copy raw winget commands.
- The launcher and source modules parse successfully with no PowerShell parser errors.

## Important Gaps

- `CLAUDE.md` still says `v0.1.0`; it is ignored/untracked and should not be treated as shipped project truth.
- The repo README is now synced to 765 apps and 39 categories, but GitHub repo metadata may still need to be checked if it drifts outside git.
- `ROADMAP.md` previously included good ideas but lacked prioritization, source IDs, saturation notes, and live repo reconciliation.
- Catalog JSON, embedded module fallback sync, validation tooling, and CI now exist.
- CI now covers catalog sync/counts, profile JSON helpers imported from modules, WinGet runner helpers imported from modules, and XAML loading. There is still no release build script or full GUI automation.
- Install/update result records now capture stderr and exit codes, but status and pin classification still use some English WinGet output phrases for "already current" and pin-type cases.
- Fallback installed-app parsing still depends on text output when `Microsoft.WinGet.Client` is unavailable.
- WinGet bootstrap no longer downloads GitHub/AppX assets directly, but still depends on PowerShell Gallery availability when the `Microsoft.WinGet.Client` repair path is needed.
- Several GUI elements still use fully rounded `CornerRadius="999"` or `CornerRadius = 999`, which conflicts with the project-wide visual rule against pill backdrops.
- PSScriptAnalyzer reports warning-level issues: automatic variable shadowing, empty catch blocks, stale encoding assumptions, and other maintainability warnings.

## Strategic Direction

The next phase should move Wingetter from "modularized WinGet GUI" to "trustworthy setup cockpit":

1. Make search metadata-rich using tags, publisher/source/state fields, and local scoring.
2. Add deeper tests for import/export edge cases, install-result fixtures, pin-output fixtures, and installed-app parsing.
3. Continue moving UI-heavy workflow code behind smaller functions now that the source is split into modules.
4. Consider Scoop, Chocolatey, and PowerShell Gallery only after the WinGet execution layer is separated behind a package-source interface.

## Source Trail

The detailed evidence register, competitor review, backlog, prioritization, security review, and limitations are in `.ai/research/2026-05-17/`.
