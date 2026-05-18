# Wingetter Project Context

Last consolidated: 2026-05-17.

## Purpose

Wingetter is a Windows-first PowerShell/WPF GUI for discovering, selecting, grouping, exporting, installing, and updating applications through Windows Package Manager (`winget`). The product stance is "Ninite-style batch setup with deeper WinGet coverage and reusable local profiles."

## Canonical Current State

- Repository: `SysAdminDoc/Wingetter`, public GitHub repo, default branch `main`.
- Launcher: [Wingetter.ps1](Wingetter.ps1), a PowerShell 5.1+ entry point that loads dot-sourced modules from `src/`.
- Source modules: `src/Wingetter.Common.ps1`, `src/Wingetter.Catalog.ps1`, `src/Wingetter.WinGet.ps1`, `src/Wingetter.Groups.ps1`, `src/Wingetter.ProfileGallery.ps1`, `src/Wingetter.Sources.ps1`, `src/Wingetter.OfflineCache.ps1`, `src/Wingetter.Configuration.ps1`, `src/Wingetter.UpdateWatcher.ps1`, `src/Wingetter.Ui.ps1`, and `src/Wingetter.App.ps1`.
- Current runtime version shown in the script UI: `v6.1.0`.
- Local catalog: 765 unique `WingetId` entries across 39 categories.
- Generated catalog snapshots: `catalog/winget.json` and `catalog/groups.json`.
- Embedded module fallback sync command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Sync-EmbeddedCatalog.ps1`.
- Validation command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Catalog.ps1`.
- CI workflow: `.github/workflows/validate.yml` runs catalog sync/count validation, profile JSON tests, profile gallery tests, WinGet runner helper tests (including locale-independent classification fixtures under `tools\fixtures\winget\`), search metadata tests, package-source adapter tests, source policy tests, update watcher tests, offline cache tests, WinGet Configuration export tests, visual/accessibility tests, WPF XAML load validation, release artifact hash verification (via `tools\Test-ReleaseArtifact.ps1`), and PSScriptAnalyzer (via `tools\Test-Analyzer.ps1` under pwsh) on Windows.
- Built-in groups in code: Essential PC Setup, Web Developer, Python Developer, Creative Suite, Gaming PC, Privacy & Security, System Admin, Streaming Setup, Office & Productivity, and 3D Printing Workshop.
- Persisted user groups: `%APPDATA%\Wingetter\groups.json`.
- Public profile gallery index: `profiles/gallery.json`; checked-in profile files: `profiles/gallery/*.wingetter.json`.
- Source policy profile: `%APPDATA%\Wingetter\source-policy.json`.
- Update-check logs: `%APPDATA%\Wingetter\logs\update-checks`.
- Icon cache: `%TEMP%\WingetterIcons`.
- Export formats: official WinGet import JSON, Wingetter group JSON, standalone PowerShell installer script, and WinGet Configuration `.winget` YAML.
- Import formats: official WinGet import/export JSON, Wingetter group JSON, simple package ID arrays, and SHA256-verified public gallery profiles.
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
- `src/Wingetter.ProfileGallery.ps1` owns the read-only public gallery index, SHA256 verification, strict profile parsing, package/source preview text, and gallery validation.
- `src/Wingetter.Sources.ps1` owns the package-source adapter contract. WinGet is the first registered adapter and currently backs search, details, install, upgrade, uninstall, export/import, installed scans, pin/hold operations, bootstrap, and copied install-command generation.
- `src/Wingetter.Sources.ps1` also owns source policy helpers for `Wingetter.SourcePolicy.v1`, allowed sources, private `Microsoft.Rest` source definitions, source trust summaries, `winget source add` command generation, and source policy export.
- `src/Wingetter.OfflineCache.ps1` owns offline `winget download` argument generation, per-package download execution, cache manifests, and replay script export.
- `src/Wingetter.Configuration.ps1` owns WinGet Configuration YAML generation and `.winget` export using `Microsoft.WinGet.DSC/WinGetPackage` resources.
- `src/Wingetter.UpdateWatcher.ps1` owns scheduled update-check summaries, metered-network detection, log writing/rotation, toast notifications, and scheduled-task registration helpers.
- `src/Wingetter.Ui.ps1` owns splash/icon helpers, WPF theme definitions, XAML, event wiring, installed-app scan UI, and package detail presentation.
- `src/Wingetter.App.ps1` owns runtime initialization and starts the GUI.
- `catalog/winget.json` and `catalog/groups.json` are the curation source files.
- Local checkout runs prefer `catalog/winget.json` and `catalog/groups.json` if present and fall back to embedded module data if those files are unavailable or malformed.
- Search uses local scoring across app name, WinGet ID, publisher-like ID prefix, category, built-in group membership, installed/update/pin state, source, and scope. Search results are re-ranked inside each category while preserving original ordering when no search is active.
- Installs and updates still run serially through WinGet, but the WPF layer now calls package-source adapter wrappers instead of WinGet package helpers directly.
- The adapter boundary is covered by `tools\Test-PackageSources.ps1`, which verifies the WinGet operation contract and rejects direct UI calls to WinGet package/profile helpers.
- WinGet install/update operations launch `winget install` or `winget upgrade` with `--id`, `--exact`, optional `--source`, and optional `--silent` / agreement flags.
- Corporate source policy can be enabled from the footer. When enabled, selected packages whose catalog source is not listed in the policy are refused before execution. The GUI can export the current source policy and reproducible source-add commands.
- Profile Gallery imports are selection-only: the GUI verifies the checked-in profile file hash, shows every package ID and source in a review dialog, then selects matching catalog packages without starting install/update.
- Scheduled update checks are check-only: they scan installed catalog packages, classify available updates as available/pinned/source-blocked/blocklisted/not allowlisted, write JSON logs, optionally show a toast, and never run upgrades.
- Offline cache mode uses `winget download --download-directory` for selected packages, respects source policy before download, writes per-package stdout/stderr/result records, exports `offline-manifest.json`, and generates `install-offline.ps1`.
- Install/update execution writes per-package stdout, stderr, and JSON result files under `%APPDATA%\Wingetter\logs\<timestamp>-<action>`, passes `--verbose-logs`, and records command, action, package ID, exit code, status, stdout/stderr excerpts, cancellation state, run log directory, and WinGet diagnostic log directory when available.
- Each completed or cancelled install/update run also builds a `Wingetter.MigrationReport.v1` report, writes `migration-report.json` into the run log directory, and enables GUI export as Markdown or JSON. Reports include selected packages, status counts, commands, result paths, version/source/scope state where available, scan timestamps, and import warnings.
- WinGet bootstrap/repair now tries documented App Installer registration, then the `Microsoft.WinGet.Client` PowerShell module with `Repair-WinGetPackageManager -Force -Latest`, logs JSONL audit entries under `%APPDATA%\Wingetter\logs`, and falls back to the Microsoft Store App Installer page for manual follow-up.
- Installed app detection runs in a background runspace using `Microsoft.WinGet.Client` `Get-WinGetPackage` object data when available, falls back to `winget list --source winget`, and writes `%APPDATA%\Wingetter\installed-cache.json` with package ID, installed version, available version, source, scope when available, detection method, and scan timestamp.
- Icons are loaded lazily across a 4-worker runspace pool from Google favicon URLs, with letter placeholders before network fetches complete.
- Profile import/export helpers now support the official WinGet JSON hierarchy: `Sources`, `Packages`, `PackageIdentifier`, and optional `Version` fields are accepted on import; exports generate a `https://aka.ms/winget-packages.schema.2.0.json` file with the `winget` source details. The UI reaches official source import/export through the current package-source adapter.
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
- The checked-in `Wingetter.exe` is hash-pinned via `release\manifest.json`, and `tools\Build-WingetterExe.ps1` now concatenates the dot-sourced modules into a parser-clean bundled launcher (PS2EXE packaging is opt-in via `-RunPS2EXE`). `tools\Test-Bundle.ps1` exercises the builder in CI so module-list drift or concatenation errors fail the build immediately. Refreshing the checked-in `Wingetter.exe` is now: run the builder with `-RunPS2EXE`, then `Test-ReleaseArtifact.ps1 -Update`, then commit.
- `ROADMAP.md` previously included good ideas but lacked prioritization, source IDs, saturation notes, and live repo reconciliation.
- Catalog JSON, embedded module fallback sync, validation tooling, and CI now exist.
- CI now covers catalog sync/counts, profile JSON helpers imported from modules, profile gallery hashes and catalog references, WinGet runner helpers imported from modules, source adapter boundaries, source policy behavior, update watcher classification, offline cache manifests, WinGet Configuration export generation, search metadata, visual/accessibility checks, and XAML loading. There is still no release build script or full GUI automation.
- Install/update result records now persist exit code, exit-code meaning, status, and matched classification signal; classification keys off a documented HRESULT lookup first and only falls back to English text when the exit code is generic. Pin classification keys off the `Pin type` column token before any text fallback.
- Fallback installed-app parsing still depends on text output when `Microsoft.WinGet.Client` is unavailable.
- WinGet bootstrap no longer downloads GitHub/AppX assets directly, but still depends on PowerShell Gallery availability when the `Microsoft.WinGet.Client` repair path is needed.
- Visual/accessibility validation now rejects `CornerRadius=999` regressions and checks baseline automation names, but deeper keyboard navigation and screen reader flow testing are still manual.
- PSScriptAnalyzer now runs in CI against `src\`, `tools\`, and `Wingetter.ps1` using `PSScriptAnalyzerSettings.psd1` (focused IncludeRules set). The previously reported automatic-variable shadowing (`$profile`, `$error`, `$args`, `$sender`) and write-only parameter findings have been fixed. Style-level rules (verb conventions, `SupportsShouldProcess` on internal helpers) and `PSAvoidUsingEmptyCatchBlock` for legitimate fire-and-forget cleanup are intentionally not enforced.

## Strategic Direction

R-020..R-026 advanced the "trustworthy setup cockpit" phase: locale-independent classification, fixture-based parser tests, PSScriptAnalyzer CI gate, release artifact hash verification, a reproducible bundle/build script for `Wingetter.exe`, adversarial edge-case coverage for profile imports (which uncovered and fixed a real `Sources = []` classification bug), and an audit-driven defensive hardening pass covering process disposal, async stream races, log-timestamp collisions, parser column collisions, atomic settings writes, corrupt-file recovery, profile/import size caps, YAML safety, offline-replay confirm-gating, clipboard error transparency, and launcher download integrity.

The remaining strategic threads are larger, multi-session efforts:

1. Prototype Scoop, Chocolatey, and PowerShell Gallery adapters now that the source-adapter contract (R-014), source policy (R-015), and locale-independent classification (R-020) are stable. Network access to bucket/source manifests should be optional so CI does not depend on remote services.
2. Continue moving UI-heavy workflow code in `src\Wingetter.Ui.ps1` (still the largest module) behind smaller functions in dedicated UI sub-modules; current monolith makes targeted reviews difficult.
3. Replace the still-manual keyboard navigation and screen reader testing with an automated check that parses the WPF XAML and asserts `TabIndex`, `KeyboardNavigation.TabNavigation`, and automation-name coverage on every focusable control.
4. Add an actual PS2EXE build job (gated on a release tag) that produces a fresh `Wingetter.exe` from the modular launcher and updates `release/manifest.json` automatically.

## Source Trail

The detailed evidence register, competitor review, backlog, prioritization, security review, and limitations are in `.ai/research/2026-05-17/`.
