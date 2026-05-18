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

### [x] R-019 - Public profile gallery with strict trust boundaries

- Problem: curated setup profiles are a differentiator, but public profiles can become supply-chain risk if they hide sources or override arguments.
- Build: read-only profile index using plain JSON and signed/hashed profile files; show every package ID and source before import; never auto-run imported profiles.
- Acceptance: gallery profiles are browseable and importable only after visible review and validation.
- Sources: E03, E04, E06, E12, E13.
- Completed 2026-05-17: added `profiles\gallery.json` plus hashed profile files under `profiles\gallery\`, `src\Wingetter.ProfileGallery.ps1` for strict schema/hash/package-source validation and review text, a GUI Profile Gallery dialog that verifies SHA256 and previews every package before selection-only import, and `tools\Test-ProfileGallery.ps1` plus CI coverage.

## P1 - Reliability Followups

### [x] R-026 - Defensive hardening pass (audit-driven)

- Problem: a deep cross-module audit (three parallel reviewers covering UI, launcher/WinGet runner, Groups/Sources/Gallery/OfflineCache/Configuration/UpdateWatcher) surfaced a cluster of high-confidence defects: process handles leaked on timeout, async stream-reader exceptions after `Kill()`, second-precision timestamps that collide under load, install/install-cache and update-check logs racing on concurrent writes, parser collisions where a short package id is a substring of a longer one, no recovery from a corrupted settings file, oversized profile/import payloads accepted without bound, single-quoted YAML scalars that could embed a literal newline, an offline replay script that ran installers without a confirm gate and without constraining their path, a clipboard copy that silently failed under contention, and a module-download launcher that wrote modules in place with no integrity check and no retry.
- Build: harden each of these paths with focused fixes plus regression tests; keep the architectural surface unchanged so users do not have to relearn anything; raise the existing CI bar so the new behaviors cannot regress.
- Acceptance: `tools\Test-WinGetRunner.ps1`, `tools\Test-ProfileJson.ps1`, `tools\Test-ProfileGallery.ps1`, `tools\Test-ConfigurationExport.ps1`, and `tools\Test-OfflineCache.ps1` all exit zero against the current tree and exit nonzero if any of the hardened behaviors regress. The audit-spawned changes do not require a fresh `Wingetter.exe`; the bundle continues to parse and PSScriptAnalyzer continues to pass.
- Sources: cross-module audit 2026-05-18.
- Completed 2026-05-18:
  - `src\Wingetter.WinGet.ps1`: `Invoke-WinGetCapture` and `Invoke-WinGetPackageOperation` now dispose the process in `finally`, catch async stream-reader exceptions thrown after `Kill()`, and tag per-package log files with 7-digit fractional seconds plus a 4-char GUID prefix so two installs that share a millisecond cannot collide on disk; bootstrap-log paths follow the same pattern.
  - `Find-WinGetPackageIdColumn` (new) anchors package-id lookups to whitespace boundaries; `ConvertFrom-WinGetListText` now picks the LONGEST unconsumed match per row so a short id that happens to be a substring of another row's Name column does not steal the version. `Get-WinGetInstalledVersion`, `ConvertFrom-WinGetListText`, and `Get-WinGetPinRowFromText` all skip separator-only rows. A new `list-name-collision.txt` fixture and CI assertions cover this.
  - `Set-WingetterFileAtomic` (new) writes settings/cache JSON to a sibling temp file and renames into place; `installed-cache.json`, `groups.json`, and `source-policy.json` use it. CI now verifies the helper writes the destination and cleans up its temp file on success.
  - `Move-WingetterCorruptFileAside` (new) renames unparseable settings/policy files to `<file>.corrupt` and surfaces a warning so a corrupt save does not silently revert the user to defaults on next launch; covered by a CI smoke test.
  - `Save-WingetterUpdateCheckResult` now uses millisecond + GUID-suffixed timestamps so a manual + scheduled check colliding on the second does not lose the second run's report.
  - `src\Wingetter.ProfileGallery.ps1` rejects profile files larger than 1 MB and profiles with more than 2,000 packages before parsing; `Import-PackageIdsFromJSON` rejects imports above 5,000 packages. The size guard is covered by a CI fixture that materializes a >1 MB file and confirms the loader refuses it.
  - `src\Wingetter.Configuration.ps1` collapses CR/LF inside YAML single-quoted scalars and rejects package identifiers that fall outside `^[A-Za-z0-9][A-Za-z0-9._+\-]*$`, with CI cases for newline names, spaces, semicolons, path-escape sequences, and embedded newlines.
  - `src\Wingetter.OfflineCache.ps1` generates a replay script that requires `-Confirm` to launch anything, refuses paths outside the manifest's `CacheDirectory`, and restricts launches to a fixed installer-extension allow-list; CI invokes the generated script without `-Confirm` and asserts it short-circuits.
  - `src\Wingetter.Ui.ps1` `CopyCommandBtn` now catches clipboard contention and tells the user to retry instead of falsely reporting success.
  - `Wingetter.ps1` launcher: per-launch random subdirectory, partial+rename downloads, head-line sanity check, 3 retries with backoff; partial files never become dot-source candidates.
  - `ConvertTo-Json -Depth 5` instances in `Wingetter.Groups.ps1` (group JSON export) and the per-package result file in `Wingetter.WinGet.ps1` bumped to `-Depth 8` to match the rest of the codebase and avoid silent truncation of nested data.
  - All 17 CI checks (catalog, profile JSON, profile gallery, WinGet runner with collision fixture, search metadata, package sources, source policy, update watcher, offline cache with `-Confirm` smoke, configuration export with YAML validation, visual/accessibility, release artifact hashes, XAML load, bundle parse, PSScriptAnalyzer) remain green.

### [x] R-025 - Profile import edge-case coverage

- Problem: `Import-PackageIdsFromJSON` accepts three distinct schemas (`Wingetter.Group.v1`, official WinGet import/export JSON, and flat package-ID arrays) plus partial inputs (missing `PackageIdentifier`, missing `SourceDetails.Name`, duplicate IDs, empty `Sources`), but `tools\Test-ProfileJson.ps1` only exercises the happy path. A regression in warning emission or deduplication would slip through unnoticed.
- Build: extend `tools\Test-ProfileJson.ps1` with adversarial inputs (duplicate IDs, missing `PackageIdentifier`, missing `SourceDetails.Name`, empty `Sources`, empty `Packages`, mixed `PackageIds`+`Sources`, multiple sources with multiple packages, flat `Packages` array, and unrecognized payloads); assert the format classification, deduplication, warning capture, and source-name capture for each case.
- Acceptance: `tools\Test-ProfileJson.ps1` continues to exit zero against the current tree and exits nonzero if `Import-PackageIdsFromJSON` regresses on any of the documented edge cases.
- Sources: L04, E03, E04.
- Completed 2026-05-18: added duplicate-ID, missing-PackageIdentifier, missing-SourceDetails.Name (with legacy Source.Name fallback), empty Sources, mixed PackageIds+Sources, multi-source, flat Packages, and unrecognized-payload cases to `tools\Test-ProfileJson.ps1`. The empty-Sources case surfaced a real bug where `elseif ($wingetSources)` treated `[]` as falsy and fell into the `Unrecognized JSON format` throw; replaced the truthiness checks in `Import-PackageIdsFromJSON` with property-presence checks via a new `Test-JsonPropertyPresence` helper so explicitly empty `Sources`/`Packages` arrays still classify as their respective WinGet schema (zero packages, zero warnings).

### [x] R-024 - Reproducible Wingetter.exe build script

- Problem: `release\README.md` documents the PS2EXE build steps in prose, but there is no script that actually performs the build, so the dot-sourced modular launcher cannot be packaged into a standalone EXE without manual concatenation. As a result the checked-in `Wingetter.exe` still represents the pre-module-split v6.1.0 launcher, not the current `src\` modules.
- Build: add `tools\Build-WingetterExe.ps1` that concatenates the dot-sourced modules in the order declared by `Wingetter.ps1` into a single bundled script, parses the bundle to catch concatenation errors, optionally invokes PS2EXE if available, and writes the bundle to `release\Wingetter.bundled.ps1` for inspection; add `tools\Test-Bundle.ps1` that parses the bundle and verifies it includes every module + a `Start-Wingetter` call.
- Acceptance: `tools\Test-Bundle.ps1` produces a parser-clean bundled script from the current `src\` tree and fails if a referenced module is missing or the bundle no longer parses.
- Sources: L01, L09, L11.
- Completed 2026-05-18: added `tools\Build-WingetterExe.ps1` that reads the canonical module list from `Wingetter.ps1`, concatenates the dot-sourced modules under `src\` (with module section markers), parses the bundle, optionally runs PS2EXE when `-RunPS2EXE` is supplied, and writes to `release\Wingetter.bundled.ps1` by default (gitignored); added `tools\Test-Bundle.ps1` that drives the builder, parses the generated bundle, asserts every expected module section is present, and verifies the final `Start-Wingetter` call; wired bundle validation into `.github/workflows/validate.yml`.

### [x] R-023 - Verifiable release artifact manifest

- Problem: `Wingetter.exe` and `Wingetter.ico` are checked into the repository root with no provenance. There is no record of what produced them, no integrity hash to catch an accidental binary swap, and no tool to verify that the binaries on `main` match the binaries a contributor downloads.
- Build: capture SHA256, size, and source description for each checked-in release artifact in `release\manifest.json`; add `tools\Test-ReleaseArtifact.ps1` that recomputes the hashes and fails when they drift from the manifest; document how the executable is currently produced (PS2EXE from the `Wingetter.ps1` launcher and the `src\` modules at `v6.1.0`); wire the verifier into `.github/workflows/validate.yml` so an accidental binary edit triggers CI failure.
- Acceptance: `tools\Test-ReleaseArtifact.ps1` exits zero against the current tree and exits nonzero if the checked-in `Wingetter.exe` or `Wingetter.ico` is mutated without updating the manifest.
- Sources: L01, L09, L11.
- Completed 2026-05-18: added `release\manifest.json` with the `Wingetter.ReleaseArtifactManifest.v1` schema, SHA256+size for `Wingetter.exe`, `Wingetter.ico`, and `icon.ico`, build provenance notes; added `tools\Test-ReleaseArtifact.ps1` (with `-Update` to regenerate hashes when the binary changes intentionally); added `release\README.md` documenting verification, update, and PS2EXE build steps; wired the verifier into `.github/workflows/validate.yml`.

### [x] R-020 - Locale-independent WinGet result and pin classification

- Problem: `Get-WinGetOperationStatus` matches English phrases like "already installed", "No available upgrade", "No newer package", and "No applicable update"; `Get-WinGetPinStatusFromText` matches "blocking" / "gating" / "version"; if WinGet is localized (German, Spanish, etc.) these classifications silently drift to FAILED or to the wrong pin type. WinGet documents HRESULT exit codes that are locale-independent.
- Build: introduce a documented HRESULT lookup table for "already installed", "no applicable upgrade", and similar non-failure outcomes; have `Get-WinGetOperationStatus` consult the exit code first and only fall back to English text patterns when the exit code is generic; have pin classification key off the `Pin type` column position instead of English words; record the matched signal (`ExitCode`, `Text`, or `None`) on the result for diagnosability.
- Acceptance: an `UP TO DATE` result classifies correctly when stdout/stderr are empty but the WinGet HRESULT is one of the known no-op codes; a blocking-pin row classifies correctly when the `Pin type` column says `Blocking` regardless of surrounding English prose; existing English-text fixtures still pass.
- Sources: L07, E01, E02.
- Completed 2026-05-17: added `$Script:WinGetUpToDateExitCodes` HRESULT lookup, `Get-WinGetExitCodeMeaning`, and a `-Signal` ref output on `Get-WinGetOperationStatus`; rewrote `Get-WinGetPinStatusFromText` to drive off the `Pin type` column token (`Blocking` / `Gating` / `Pinning` / `PinnedByManifest`) with English-text only as fallback; install/upgrade and offline-cache result records now persist `ExitCodeMeaning` and `StatusSignal` for diagnosability.

### [x] R-022 - PSScriptAnalyzer CI gate and automatic-variable cleanup

- Problem: PROJECT_CONTEXT.md notes PSScriptAnalyzer reports warnings about automatic variable shadowing, empty catch blocks, and stale encoding assumptions, but CI does not run the analyzer, so warning-level regressions are invisible. Concrete current shadowing examples include `foreach ($profile in ...)` in `src\Wingetter.ProfileGallery.ps1` and `src\Wingetter.Ui.ps1`, and `$profile = ...` in `src\Wingetter.UpdateWatcher.ps1`, all of which shadow `$PROFILE`.
- Build: add `PSScriptAnalyzerSettings.psd1` at the repo root with a curated rule set that surfaces high-value warnings and excludes rules the codebase intentionally relies on (best-effort `catch {}` for process kill / runspace dispose); add `tools\Test-Analyzer.ps1` that installs/imports the analyzer and runs it against `src\` and `tools\`; wire it into `.github/workflows/validate.yml`; rename the shadowed `$profile` loop and assignment variables in `Wingetter.ProfileGallery.ps1`, `Wingetter.Ui.ps1`, and `Wingetter.UpdateWatcher.ps1`.
- Acceptance: `tools\Test-Analyzer.ps1` exits zero against the current tree and exits nonzero if a shadowed-automatic-variable warning, undeclared write-only parameter, or `Set-Content` without `-Encoding` is reintroduced.
- Sources: L13, L18.
- Completed 2026-05-18: added `PSScriptAnalyzerSettings.psd1` with a focused `IncludeRules` set covering `PSAvoidAssignmentToAutomaticVariable`, `PSReviewUnusedParameter`, and a handful of security/correctness rules; added `tools\Test-Analyzer.ps1` (installs analyzer on demand, runs under pwsh, reports findings); wired a `pwsh`-shell step into `.github/workflows/validate.yml`; renamed shadowed `$profile`/`$error`/`$args`/`$sender` variables across `Wingetter.ProfileGallery.ps1`, `Wingetter.Ui.ps1`, `Wingetter.UpdateWatcher.ps1`, `tools\Test-Catalog.ps1`, `tools\Test-OfflineCache.ps1`, and `tools\Test-UpdateWatcher.ps1`; documented the intentionally inert `[void]$param` marker for adapter/symmetry parameters (`AcceptAgreements`/`IncludePinned` on Uninstall, `GroupName` on `Export-GroupAsWinGetJSON`, `ManifestPath` on `Export-WingetterOfflineReplayScript`).

### [x] R-021 - Parser fixture coverage for WinGet output drift

- Problem: WinGet output parsers (`Get-WinGetOperationStatus`, `Get-WinGetPinStatusFromText`, `ConvertFrom-WinGetListText`, `Get-WinGetShowField`) are validated against minimal inline strings; localized WinGet output, indented `winget show` blocks, and progress-bar noise are not represented, so regressions are easy to miss.
- Build: add a fixture directory under `tools\fixtures\winget\` with representative captured outputs (English install success, English up-to-date, German up-to-date, Spanish up-to-date, blocking pin, gating pin, `winget list` with available updates, `winget show` with full installer block, `winget pin list` with no pins); extend `tools\Test-WinGetRunner.ps1` to load each fixture and verify the expected classification/parsed fields; keep fixtures readable plain text so future contributors can add new locales.
- Acceptance: `tools\Test-WinGetRunner.ps1` exits zero against the fixtures and exits nonzero if any expected classification regresses; the fixtures directory is small enough to review by eye.
- Sources: L07, L08, E01, E02.
- Completed 2026-05-17: added `tools\fixtures\winget\` with English install success, English/German/Spanish up-to-date, install failure, blocking/gating/pinning/empty pin list, `winget list` with available updates, and full `winget show` fixtures plus a fixtures README; `tools\Test-WinGetRunner.ps1` now consumes each fixture and asserts the expected status, signal source, pin type, parsed list rows, and parsed show fields.

## Rejected Or Deferred

- Parallel install as a near-term promise: the local WinGet 1.28.240 help output does not show a `--parallel` install option, so this remains deferred until verified in official docs or local help.
- Multi-source UI before refactor: UniGetUI proves the value, but adding sources inside the current monolith would increase coupling.
- Cloud sync by default: keep profiles local-first; optional folder sync can be added later without accounts.
- AI/package recommendations as a P0 feature: the project has useful catalog/search data, but trust and reliability are higher leverage first.

## Source Appendix

Primary source URLs are enumerated in `.ai/research/2026-05-17/SOURCE_REGISTER.md`; local file evidence is enumerated there with file and line references.
