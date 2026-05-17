# Wingetter Project Context

Last consolidated: 2026-05-17.

## Purpose

Wingetter is a Windows-first PowerShell/WPF GUI for discovering, selecting, grouping, exporting, installing, and updating applications through Windows Package Manager (`winget`). The product stance is "Ninite-style batch setup with deeper WinGet coverage and reusable local profiles."

## Canonical Current State

- Repository: `SysAdminDoc/Wingetter`, public GitHub repo, default branch `main`.
- Primary implementation: [Wingetter.ps1](Wingetter.ps1), a single PowerShell 5.1+ WPF script.
- Current runtime version shown in the script UI: `v6.1.0`.
- Local catalog: 765 unique `WingetId` entries across 39 categories.
- Generated catalog snapshots: `catalog/winget.json` and `catalog/groups.json`.
- Embedded fallback sync command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Sync-EmbeddedCatalog.ps1`.
- Validation command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Catalog.ps1`.
- Built-in groups in code: Essential PC Setup, Web Developer, Python Developer, Creative Suite, Gaming PC, Privacy & Security, System Admin, Streaming Setup, Office & Productivity, and 3D Printing Workshop.
- Persisted user groups: `%APPDATA%\Wingetter\groups.json`.
- Icon cache: `%TEMP%\WingetterIcons`.
- The root README version badge, category counts, and built-in group names are synced to the v6.1.0 catalog as of 2026-05-17.
- `CLAUDE.md` and `AGENTS.md` exist locally but are ignored/untracked. They are tool-specific working notes, not canonical shipped docs.

## Architecture

Wingetter is currently monolithic:

- The complete application, static catalog, WPF layout, theme definitions, built-in groups, WinGet bootstrap logic, export/import logic, install/update runner, installed-app scan, and icon loader all live in `Wingetter.ps1`.
- The app builds WPF controls in a large `Show-WinGetInstallerGUI` function rather than through separate XAML files or modules.
- `catalog/winget.json` and `catalog/groups.json` are the curation source files.
- The script still contains an embedded `[ordered]` hashtable catalog for one-file launch fallback; regenerate that fallback with `tools/Sync-EmbeddedCatalog.ps1`.
- When run from a local repo checkout, the script prefers `catalog/winget.json` and `catalog/groups.json` if present and falls back to the embedded catalog/groups if those files are unavailable or malformed.
- Search filters app name and WinGet ID only.
- Installs and updates run serially by launching `winget install` or `winget upgrade` with `--id`, `--exact`, and optional `--silent` / agreement flags.
- Installed app detection runs in a background runspace using `winget list --source winget` and regex parsing.
- Icons are loaded lazily across a 4-worker runspace pool from Google favicon URLs, with letter placeholders before network fetches complete.

## Verified Strengths

- Fast zero-install entry point: the README supports direct `irm ... | iex` execution.
- Broad curated local catalog with no duplicate package IDs.
- Familiar dark/light WPF UI with categories, sidebar navigation, collapsible sections, selection state, update review mode, log panel, and toast notification.
- Useful profile primitives already exist: save/load groups, import JSON, export JSON, export PowerShell installer script, and copy raw winget commands.
- The script parses successfully with no PowerShell parser errors.

## Important Gaps

- `CLAUDE.md` still says `v0.1.0`; it is ignored/untracked and should not be treated as shipped project truth.
- The repo README is now synced to 765 apps and 39 categories, but GitHub repo metadata may still need to be checked if it drifts outside git.
- `ROADMAP.md` previously included good ideas but lacked prioritization, source IDs, saturation notes, and live repo reconciliation.
- Catalog JSON, embedded fallback sync, and validation tooling now exist. The remaining catalog risk is that there is no CI job enforcing those checks yet.
- No CI, Pester tests, release build script, or GitHub Actions validation exists yet.
- Install/update result classification depends on localized stdout text and ignores stderr details.
- WinGet bootstrap downloads dependencies and the latest WinGet release without a recorded checksum verification path.
- Several GUI elements still use fully rounded `CornerRadius="999"` or `CornerRadius = 999`, which conflicts with the project-wide visual rule against pill backdrops.
- PSScriptAnalyzer reports warning-level issues: automatic variable shadowing, empty catch blocks, stale encoding assumptions, and other maintainability warnings.

## Strategic Direction

The next phase should move Wingetter from "large polished script" to "trustworthy setup cockpit":

1. Add CI so catalog validation and embedded fallback freshness cannot drift silently.
2. Support the official WinGet export/import schema alongside Wingetter groups.
3. Replace fragile text parsing with structured logs, stderr capture, and per-package result records.
4. Add source and manifest trust visibility: source, publisher, installer URL, hash, scope, installer type, and pin state.
5. Reconcile docs/versioning/release artifacts and add CI checks so counts and package IDs cannot drift silently.
6. Consider Scoop, Chocolatey, and PowerShell Gallery only after the catalog and execution layers are separated behind a package-source interface.

## Source Trail

The detailed evidence register, competitor review, backlog, prioritization, security review, and limitations are in `.ai/research/2026-05-17/`.
