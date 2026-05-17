# Wingetter Roadmap

Last updated: 2026-05-17.

This roadmap is based on local repo reconnaissance plus external package-manager research captured in `.ai/research/2026-05-17/`. Evidence IDs refer to `.ai/research/2026-05-17/SOURCE_REGISTER.md`.

## Product Thesis

Wingetter should become the simplest trustworthy Windows setup cockpit for power users and sysadmins: Ninite-like batch selection, WinGet-native fidelity, transparent source/manifest trust, reusable local profiles, and export formats that survive machine rebuilds.

## P0 - Foundation And Trust

### [x] R-001 - Externalize the catalog and add validation

- Problem: the 765-app catalog is embedded directly inside `Wingetter.ps1`, making curation, review, counting, and stale package detection risky. Evidence: L02, L18.
- Build: move catalog data to a repo-owned data file such as `catalog/winget.json`; add a generator/validator script that checks unique IDs, category counts, built-in group references, JSON schema, and `winget show --id <id> --exact` availability sampling.
- Acceptance: `pwsh tools/Test-Catalog.ps1` exits nonzero for duplicate IDs, missing group IDs, invalid icon URLs, stale README counts, or malformed category records.
- Sources: L02, L18, E08, E09, E11.
- Completed 2026-05-17: added repo-owned catalog and group source files, local JSON loading with embedded fallback, `tools\Sync-EmbeddedCatalog.ps1` to regenerate the embedded fallback, `tools\Export-WingetterCatalog.ps1` for fallback parity checks, README/changelog count validation, duplicate-ID validation, group-reference validation, and optional `winget show` sampling.

### [x] R-002 - Reconcile versioning, README counts, changelog, and release artifacts

- Problem: script UI says `v6.1.0`, ignored `CLAUDE.md` says `v0.1.0`, README badge says `preview`, CHANGELOG has a malformed date, and GitHub metadata still says 734 apps. Evidence: L01, L09, L11, L14.
- Build: pick one project version, sync `Wingetter.ps1`, README badge/text, CHANGELOG, GitHub description, release artifact names, and screenshot captions; add a count-sync check.
- Acceptance: one command reports version/count agreement across script, README, changelog, and generated catalog metadata.
- Sources: L01, L09, L11, L14, L18.
- Completed 2026-05-17: chose `v6.1.0` as the shipped version, fixed the README version badge, corrected README category and built-in group tables, rewrote the malformed changelog header, and added `tools\Test-Catalog.ps1` as the count/version consistency check.

### [x] R-003 - Support official `winget export` / `winget import` schema

- Problem: Wingetter has custom group JSON, but WinGet already defines import/export JSON with `Sources`, `Packages`, `PackageIdentifier`, and optional versions.
- Build: import official WinGet JSON; export official WinGet JSON; preserve Wingetter-only metadata in a separate profile format; validate source names and package availability before execution.
- Acceptance: a file produced by `winget export` can be imported into Wingetter, edited, and exported back to a file usable by `winget import`.
- Sources: L04, E03, E04.
- Completed 2026-05-17: added official WinGet JSON export with `Sources`, `Packages`, `PackageIdentifier`, schema URL, and `winget` source details; import now accepts official WinGet JSON, Wingetter group JSON, and package ID arrays; the Wingetter-specific profile format remains separate as `Wingetter.Group.v1`; `tools\Test-ProfileJson.ps1` verifies round trips without launching the GUI.

### [x] R-004 - Harden install/update execution and result capture

- Problem: install/update launches `winget` serially with joined arguments, reads stdout asynchronously, discards stderr, and classifies results with brittle English text matches.
- Build: use `ProcessStartInfo.ArgumentList` when available, capture stdout and stderr, write per-package log files, pass `--verbose-logs`, store exit code plus parsed result, surface the WinGet log path, and include a retry/skip state.
- Acceptance: every package operation leaves a structured result record with command, package ID, action, exit code, stdout excerpt, stderr excerpt, WinGet log path, and final status.
- Sources: L07, E01, E02.
- Completed 2026-05-17: added `Invoke-WinGetPackageOperation` with structured argument handling, stdout/stderr capture, per-package log files, `--verbose-logs`, JSON result records, cancellation state, status classification, run log directory surfacing, WinGet diagnostic log directory hints, and `tools\Test-WinGetRunner.ps1` for non-installing runner smoke coverage.

### [x] R-005 - Add source, manifest, and trust detail panels

- Problem: users select names and package IDs but cannot inspect source, publisher, installer type, URL, hash, scope, or source trust before installing.
- Build: add a package detail drawer backed by `winget show`, manifest metadata, and source list data; show default sources, explicit sources, installer hash, local manifest warnings, and whether the package comes from `winget`, `msstore`, or another source.
- Acceptance: selecting a package displays source, publisher, installer type, installer URL when available, SHA256 when available, current installed version when present, and warnings for missing metadata.
- Sources: E01, E07, E08, E09, L20.
- Completed 2026-05-17: added a package detail panel above the activity log. App-row clicks now show source, publisher, installed/latest version, installer type, installer URL or homepage fallback, SHA256, and metadata warnings from `winget show` / `winget list`; XAML loading and detail parsing were verified.

### [x] R-006 - Replace risky WinGet bootstrap flow

- Problem: `Install-WinGet` downloads VCLibs, Microsoft.UI.Xaml, and latest WinGet assets, then installs them without an internal verification/audit path. This is a sensitive bootstrap path.
- Build: prefer documented Microsoft bootstrap paths such as App Installer registration and `Microsoft.WinGet.Client` `Repair-WinGetPackageManager`; if downloads remain, record source URL, expected signature/hash strategy, and clear error reporting.
- Acceptance: bootstrap has a documented path, does not silently swallow errors, and logs every downloaded file, source, size, and verification result.
- Sources: L03, E10, E22.
- Completed 2026-05-17: replaced direct VCLibs/UI.Xaml/GitHub asset downloads with App Installer registration, `Microsoft.WinGet.Client` module repair through `Repair-WinGetPackageManager -Force -Latest`, JSONL bootstrap logs, explicit error logging, verification steps, and Microsoft Store fallback. Manual file downloads are no longer performed by Wingetter bootstrap.

## P1 - Reliability, Workflow, And Maintainability

### [x] R-007 - Add CI and focused PowerShell tests

- Problem: no automated parse, lint, catalog, export/import, or count checks exist. PSScriptAnalyzer already reports warnings.
- Build: add Pester tests or script-level checks for parse success, package count, duplicate IDs, built-in group IDs, export/import round trip, and README count sync. Add GitHub Actions for `pwsh` validation.
- Acceptance: CI fails on parse errors, duplicate package IDs, stale counts, broken group references, or malformed JSON exports.
- Sources: L13, L18.
- Completed 2026-05-17: added `.github/workflows/validate.yml` on Windows plus focused scripts for catalog/README/changelog sync, embedded fallback freshness, official/Wingetter profile JSON round trips, WinGet runner helper behavior, and WPF XAML loading.

### [x] R-008 - Modularize without changing behavior

- Problem: a 3,283-line single script makes targeted fixes and reviews difficult.
- Build: split into `src/Wingetter.App.ps1`, `src/Wingetter.Catalog.ps1`, `src/Wingetter.Groups.ps1`, `src/Wingetter.WinGet.ps1`, `src/Wingetter.Ui.ps1`, and `Wingetter.ps1` as a thin launcher while keeping direct-run behavior.
- Acceptance: `Wingetter.ps1` still launches the GUI; tests can import non-UI modules independently.
- Sources: L01, L04, L07, L08.
- Completed 2026-05-17: split runtime code into `src/Wingetter.Common.ps1`, `src/Wingetter.Catalog.ps1`, `src/Wingetter.WinGet.ps1`, `src/Wingetter.Groups.ps1`, `src/Wingetter.Ui.ps1`, and `src/Wingetter.App.ps1`; reduced `Wingetter.ps1` to a launcher that loads local modules or downloads modules for raw GitHub quick launch; moved catalog/group embedded fallbacks into modules; updated validation tools so profile and WinGet helper tests import source modules directly.

### [x] R-009 - Add update pins and package lifecycle controls

- Problem: WinGet has first-class pins, but Wingetter only has install and update review primitives.
- Build: show current pin state; add pin, blocking pin, gating pin, remove pin, and "include pinned" update option with clear warnings.
- Acceptance: `winget pin list` state is visible and package rows can add/remove pins without leaving the GUI.
- Sources: E02, E05, L20.
- Completed 2026-05-17: added WinGet pin lookup helpers, pin-output parsing tests, package detail pin state, standard/blocking/installed-version pin buttons, remove-pin action, row-level pinned badges after lookup, and an "Include pinned updates" checkbox that adds `--include-pinned` to update operations.

### [x] R-010 - Improve installed-app detection

- Problem: current detection parses `winget list --source winget` table output with regex and can miss wrapped/truncated or localized rows.
- Build: evaluate `Microsoft.WinGet.Client` PowerShell cmdlets for object-based installed package data; otherwise use machine-readable output if available and cache scan results with timestamps.
- Acceptance: installed detection includes package ID, installed version, available version, source, scope when available, and scan timestamp.
- Sources: L08, E22.
- Completed 2026-05-17: added `Microsoft.WinGet.Client` `Get-WinGetPackage` object-based detection with `winget list` fallback, installed package cache JSON under `%APPDATA%\Wingetter\installed-cache.json`, richer records for package ID, installed/available version, source, optional scope, detection method, and scan timestamp, UI consumption of those records, and parser tests for object and fallback paths.

### [x] R-011 - Add profile lifecycle and migration reports

- Problem: saved groups are useful but do not capture source, version intent, installed/current state, failures, or machine migration history.
- Build: add profile metadata, last run date, per-package state, import warnings, missing packages, unavailable packages, and a "migration report" export.
- Acceptance: after a run, users can export a report showing selected packages, installed/skipped/failed counts, versions, sources, and commands.
- Sources: L04, E03, E04, E13, E14.
- Completed 2026-05-17: added `Wingetter.MigrationReport.v1` report generation, automatic `migration-report.json` writing in each run log directory, GUI export to Markdown or JSON after install/update runs, import-warning capture, summary counts, per-package command/result paths, and installed/available version/source/scope state where available.

### [x] R-012 - Make search metadata-rich

- Problem: search only checks name and Winget ID.
- Build: after catalog externalization, index tags, descriptions, publisher, source, install scope, group membership, installed state, and category. Add fuzzy matching with simple local scoring before considering any model dependency.
- Acceptance: searching for "vpn privacy", "developer python", publisher names, tags, or partial IDs returns useful package rows with ranked matches.
- Sources: L06, E08, E19.
- Completed 2026-05-17: added pure catalog search scoring over names, package IDs, publisher-like ID prefixes, category, built-in group membership, source/scope, installed state, update state, and pin state; the UI now ranks matches within each category during active searches and restores curated order when the search is cleared; CI now covers representative searches like `vpn privacy`, `developer python`, publisher-like tokens, and source/scope/state queries.

### [x] R-013 - Fix visual rule violations and accessibility basics

- Problem: several UI elements use pill-style `CornerRadius=999`; dialogs and status badges should use bounded rectangular radii. Some command flows still rely on confirmation dialogs.
- Build: replace pill backdrops with 8-12px rectangular radii, preserve true circular progress/indicator use only where visually required, review contrast, focus states, text truncation, and button state clarity.
- Acceptance: no `CornerRadius="999"` or `CornerRadius = ...999` remains on text-bearing backdrops; common flows remain usable with visible focus and no text overlap.
- Sources: L16.
- Completed 2026-05-17: replaced remaining `CornerRadius=999` text-bearing badges and progress backdrops with bounded radii, added automation names for the theme toggle and package search box, and added `tools/Test-VisualAccessibility.ps1` plus CI coverage to prevent pill-radius regressions and missing baseline accessibility names.

## P2 - Ecosystem Expansion

### [x] R-014 - Package-source interface for WinGet first, then Scoop/Chocolatey/PowerShell Gallery

- Problem: multi-backend ideas are premature until catalog and execution are abstracted.
- Build: define a source adapter contract for search, show/details, install, upgrade, uninstall, export, import, and pin/hold equivalents; implement WinGet first; prototype Scoop, Chocolatey, and PowerShell Gallery after the contract stabilizes.
- Acceptance: WinGet behavior is unchanged behind an adapter; adding a second source does not require editing WPF event handlers directly.
- Sources: E12, E16, E17, E18.
- Completed 2026-05-17: added `src/Wingetter.Sources.ps1` with a validated package-source adapter contract; registered WinGet as the first backend for search, details, install, upgrade, uninstall, export/import, installed scans, pin/hold operations, bootstrap, and command previews; routed WPF details, official source profile import/export, install/update, pin controls, copied commands, and installed scans through adapter wrappers; and added `tools\Test-PackageSources.ps1` plus CI coverage to enforce the adapter boundary.

### [x] R-015 - Corporate/internal source mode

- Problem: sysadmin/MSP use cases need internal manifests, locked source lists, explicit sources, and audit trails.
- Build: add a settings profile that locks allowed sources, supports `Microsoft.Rest` private sources, shows source trust level, and exports source configuration.
- Acceptance: Wingetter can run against a private explicit source and refuse packages outside allowed sources when corporate mode is enabled.
- Sources: E07, E23, E15, E17.
- Completed 2026-05-17: added `Wingetter.SourcePolicy.v1` support under `%APPDATA%\Wingetter\source-policy.json`, a footer Corporate policy toggle, source trust summaries in package details, explicit `--source` command generation, policy refusal before install/update execution, `Microsoft.Rest` private source definitions with `--explicit` source-add command export, GUI Export Sources, and `tools\Test-SourcePolicy.ps1` plus CI coverage.

### [x] R-016 - Scheduled update watcher and tray/status workflow

- Problem: Wingetter is launch-driven, while adjacent tools compete on scheduled update checks and notifications.
- Build: optional scheduled task or tray companion that checks updates, respects pins/allowlists/blocklists, rotates logs, handles metered networks, and notifies with a concise summary.
- Acceptance: users can enable a local scheduled update check without forced auto-upgrades.
- Sources: E12, E15.
- Completed 2026-05-17: added `src/Wingetter.UpdateWatcher.ps1`, one-time update check and scheduled-task registration scripts, check-only update classification that respects pins/source policy/allowlists/blocklists, metered-network skip support, JSON log writing and rotation under `%APPDATA%\Wingetter\logs\update-checks`, toast summaries, and `tools\Test-UpdateWatcher.ps1` plus CI coverage.

### [x] R-017 - Offline download/cache mode

- Problem: air-gapped or low-bandwidth rebuild workflows need prefetch and verification, not just live install.
- Build: expose `winget download` into a "download selected installers" mode, save manifest metadata, and generate an install manifest for later use.
- Acceptance: selected packages can be downloaded to a folder with package IDs, source metadata, and a replay script/report.
- Sources: L21, E01, E08.
- Completed 2026-05-17: added `src/Wingetter.OfflineCache.ps1`, GUI Download Cache action, `tools\Invoke-OfflineCache.ps1`, `winget download --download-directory` argument generation, source-policy checks before download, per-package download result logs, `offline-manifest.json`, generated `install-offline.ps1` replay script, and `tools\Test-OfflineCache.ps1` plus CI coverage.

### [x] R-018 - WinGet Configuration export

- Problem: WinGet Configuration can express packages plus machine configuration as repeatable YAML, which is stronger than a linear PS1 installer for onboarding.
- Build: export selected packages into a minimal WinGet Configuration file, then later add optional DSC resources for common developer setup assertions.
- Acceptance: selected packages can be exported to a valid configuration file that `winget configure validate` accepts.
- Sources: E06, E24, L22.
- Completed 2026-05-17: added `src\Wingetter.Configuration.ps1` for WinGet Configuration YAML generation, GUI export as `*.winget`, `tools\Export-WinGetConfiguration.ps1` for CLI export, `tools\Test-ConfigurationExport.ps1` for static validation, and local `winget configure validate -f <file> --disable-interactivity` coverage against a generated `Microsoft.WinGet.DSC/WinGetPackage` configuration.

### [ ] R-019 - Public profile gallery with strict trust boundaries

- Problem: curated setup profiles are a differentiator, but public profiles can become supply-chain risk if they hide sources or override arguments.
- Build: read-only profile index using plain JSON and signed/hashed profile files; show every package ID and source before import; never auto-run imported profiles.
- Acceptance: gallery profiles are browseable and importable only after visible review and validation.
- Sources: E03, E04, E06, E12, E13.

## Rejected Or Deferred

- Parallel install as a near-term promise: the local WinGet 1.28.240 help output does not show a `--parallel` install option, so this remains deferred until verified in official docs or local help.
- Multi-source UI before refactor: UniGetUI proves the value, but adding sources inside the current monolith would increase coupling.
- Cloud sync by default: keep profiles local-first; optional folder sync can be added later without accounts.
- AI/package recommendations as a P0 feature: the project has useful catalog/search data, but trust and reliability are higher leverage first.

## Source Appendix

Primary source URLs are enumerated in `.ai/research/2026-05-17/SOURCE_REGISTER.md`; local file evidence is enumerated there with file and line references.
