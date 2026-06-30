# Changelog

All notable changes to Wingetter will be documented in this file.

## [Unreleased]

- Changed: WinGet availability detection now returns structured states for available, missing, disabled-by-policy, constrained-language, and broken App Installer registration cases. The GUI surfaces the exact blocker and skips automated repair when policy or constrained language mode makes repair impossible.
- Added: Per-package install options in Wingetter profiles and command generation. Wingetter group JSON now preserves vetted `Version`, `Scope`, `Architecture`, `InstallerType`, `Locale`, `Location`, and explicitly allow-listed `Custom` options, official WinGet imports preserve safe package metadata with review warnings, public gallery profiles still reject raw installer argument fields, run plans/results show option summaries, and generated WinGet/PS1 commands use argument arrays so option values with spaces stay quoted correctly.
- Added: Source policy priority and drift audit support. Source definitions can carry optional WinGet 1.29+ `Priority`, exported `winget source add` commands include `--priority` only when supported, policy trust summaries show priority, and `Get-WingetterSourcePolicyDrift` compares policy sources against live `winget source list` data for missing, extra, changed, explicit, trust, and priority drift.
- Changed: Release artifact verification now regenerates the bundled launcher, records and verifies its SHA256/size in `release\manifest.json`, checks that `Wingetter.exe` version metadata references the same bundle hash, records PS2EXE version metadata, and stores the live Authenticode status with an explicit unsigned reason when no code-signing certificate is available.
- Added: STA UI smoke validation in `tools\Test-UiSmoke.ps1`. It launches the real WPF surface with fixture installed-package data, toggles dark/light themes, verifies empty search state, opens the profile gallery, enters/exits update mode, captures nonblank PNG screenshots, and is wired into `tools\Invoke-Validation.ps1`.
- Added: Preflight run plans for install/update. Wingetter now writes a JSON `preflight-plan.json`, shows a review dialog with per-package action/status/reason/source/pin/version fields, skips blocked/current/unresolved rows before execution, and embeds the plan in migration reports.
- Changed: Install, update, and offline-cache runs now execute in a background runspace with queued UI progress/log updates and a shared cancellation token, keeping Stop responsive without `DoEvents` pumping and preventing reentry while a run is active.
- Added: WinGet 1.29 clean-output support. Command builders feature-detect 1.29+ before adding `--no-progress`, and fallback `winget list` scans use stable `--sort name --ascending` arguments when available while keeping 1.28-compatible fallback behavior.
- Fixed: Offline cache manifests now record cached installer SHA256 and byte size, and `install-offline.ps1` refuses to launch files whose size or hash no longer matches the manifest.
- Fixed: Source policy export now redacts private REST `Header` values and generated `winget source add --header` arguments by default; raw headers require the explicit `-IncludeRawHeaders` export switch.
- Added: `tools\Invoke-Validation.ps1` as the single local validation contract. It runs catalog, profile, gallery, WinGet runner, search, package-source, source-policy, update, offline-cache, configuration, accessibility, release-artifact, launcher-manifest, bundle, XAML, and PSScriptAnalyzer checks from one command.
- Changed: README, release notes, project context, and validation guardrails now describe local validation and local release builds instead of removed GitHub workflow paths.
- Fixed: Launcher, profile gallery, release-artifact, and launcher-manifest SHA256 checks now fall back to a .NET SHA256 stream helper when `Get-FileHash` is unavailable in Windows PowerShell.
- Changed: Rebuilt `Wingetter.exe` locally with `tools\Build-WingetterExe.ps1` and refreshed `release\manifest.json` build notes for the bundled-launcher path.
- Changed: `ExportBtn` selection-export now drives the SaveFileDialog filter and dispatch from a single `$exportFormats` array (Label/Extension/DefaultFileName/Handler), so adding or reordering an export format is a one-line edit instead of three separately maintained parts. The four existing formats produce byte-identical output.
- Added: Hash-pinned launcher module downloads. `Wingetter.ps1` carries an embedded `$Script:WingetterModuleHashes` table with the canonical SHA256 of every `src\Wingetter.*.ps1` module and refuses to dot-source any downloaded module whose hash differs (catches tampered mirrors, redirected URLs, and `%TEMP%` cache poisoning). `tools\Sync-LauncherManifest.ps1` regenerates the table; `tools\Test-LauncherManifest.ps1` enforces it in local validation and probes both the positive and negative verification paths.
- Removed: Remote release workflow references; release builds and artifact publication are local-only.
- Added: Automated accessibility sweep in `tools\Test-VisualAccessibility.ps1` over every named focusable XAML control (Button / TextBox / ComboBox / CheckBox / ToggleButton / ListBox / RadioButton); requires an accessible label source on every control and refuses `Focusable="False"` / `IsTabStop="False"` outside style template parts.
- Added: `AutomationProperties.Name` on `GroupCombo` ("Saved package groups"), `GroupNameBox` ("Group name"), `ProfilesList` ("Available profile gallery profiles"), and `PreviewBox` ("Profile package review") so screen readers can describe these previously-unlabeled controls.
- Fixed: `Invoke-WinGetCapture` and `Invoke-WinGetPackageOperation` now dispose the launched process in a `finally` block and tolerate async stream-reader exceptions thrown when `Kill()` races the redirected stdout/stderr readers, so a cancelled or timed-out install no longer leaks file handles or surfaces a raw `OperationCanceledException`.
- Fixed: Per-package install/upgrade log files, the WinGet bootstrap log, and update-check logs all use 7-digit fractional-second timestamps plus a short GUID suffix; concurrent installs or a manual+scheduled update check colliding on the same second can no longer overwrite each other's logs.
- Fixed: `ConvertFrom-WinGetListText`, `Get-WinGetInstalledVersion`, and `Get-WinGetPinRowFromText` now anchor package-id matches to whitespace column boundaries via a new `Find-WinGetPackageIdColumn` helper and pick the LONGEST unconsumed match on each row, so a short id that happens to be a substring of another row's Name column no longer steals that row's version. Added a `list-name-collision.txt` fixture.
- Added: `Set-WingetterFileAtomic` helper that writes JSON to a sibling temp file and renames it into place. Used for `installed-cache.json`, `groups.json`, and `source-policy.json` so concurrent writers cannot leave a partially-written file behind.
- Added: `Move-WingetterCorruptFileAside` helper that renames an unparseable settings file to `<file>.corrupt` and surfaces a warning; `Get-SavedGroups` and `Get-WingetterSourcePolicy` now use it instead of silently falling back to defaults.
- Added: Profile gallery file-size cap (1 MB) and per-profile package-count cap (2000); `Import-PackageIdsFromJSON` rejects payloads above 5000 packages so an oversized or malicious profile cannot run the UI out of memory.
- Fixed: `Wingetter.Configuration.ps1` rejects package identifiers that fall outside `^[A-Za-z0-9][A-Za-z0-9._+\-]*$` and collapses CR/LF inside YAML single-quoted scalars; the generated `.winget` file is guaranteed to be parser-safe.
- Fixed: The offline-cache replay script generated by `Export-WingetterOfflineReplayScript` now requires `-Confirm` before launching anything, refuses installer paths that fall outside the manifest's `CacheDirectory`, and restricts launches to a fixed installer-extension allow-list.
- Fixed: `CopyCommandBtn` in the UI catches clipboard contention (`CLIPBRD_E_CANT_OPEN`) and tells the user to retry instead of falsely reporting "copied".
- Fixed: `Wingetter.ps1` launcher downloads each module to a per-launch random subdirectory via a `.partial` staging file with a head-line sanity check and 3 retries with backoff; a partial or empty download is never dot-sourced.
- Changed: Group-export JSON and per-package install/upgrade result files now use `ConvertTo-Json -Depth 8` (was 5) for parity with the rest of the codebase.
- Fixed: `Import-PackageIdsFromJSON` no longer throws `Unrecognized JSON format` for valid WinGet exports with an explicitly empty `Sources` or `Packages` array; classification now keys off property presence via a new `Test-JsonPropertyPresence` helper.
- Added: Adversarial test coverage for `Import-PackageIdsFromJSON` (duplicate IDs, missing `PackageIdentifier`, missing `SourceDetails.Name`, empty `Sources`, mixed `PackageIds`+`Sources`, multi-source, flat `Packages`, unrecognized payloads) in `tools\Test-ProfileJson.ps1`.
- Added: `tools\Build-WingetterExe.ps1` to concatenate the dot-sourced `src\` modules into a single bundled launcher (and optionally run PS2EXE), plus `tools\Test-Bundle.ps1` that parses the bundle and verifies module-section presence; covered by local validation.
- Added: Verifiable release artifact manifest at `release\manifest.json` with SHA256 hashes for `Wingetter.exe`, `Wingetter.ico`, and `icon.ico`, plus `tools\Test-ReleaseArtifact.ps1` (with `-Update` mode) and a local validation step that fails on unexplained binary changes.
- Added: `release\README.md` documenting how to verify, update, and (re)build the checked-in `Wingetter.exe` from `Wingetter.ps1` via PS2EXE.
- Added: PSScriptAnalyzer local validation gate with a project-tuned `PSScriptAnalyzerSettings.psd1` and `tools\Test-Analyzer.ps1` runner that enforces `PSAvoidAssignmentToAutomaticVariable`, `PSReviewUnusedParameter`, and security/correctness rules.
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
- Added: Local validation for catalog, profile JSON, WinGet runner helpers, and WPF XAML loading.
- Added: Source modules under `src/` for common helpers, catalog data, WinGet operations, group/profile helpers, UI, and runtime bootstrap.
- Added: WinGet pin state lookup plus package detail controls for standard pins, blocking pins, installed-version pins, and pin removal.
- Added: Include pinned updates checkbox that passes `--include-pinned` during update runs.
- Added: Object-based installed package detection through `Microsoft.WinGet.Client` with `winget list` fallback and `%APPDATA%\Wingetter\installed-cache.json` scan caching.
- Added: Migration report generation for install/update runs, including GUI export to Markdown or JSON.
- Added: Metadata-rich local search scoring across names, IDs, categories, built-in groups, publisher-like ID prefixes, source/scope state, installed/update state, and pin state.
- Added: Search metadata validation script and local validation coverage.
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
- Changed: Local validation now validates update watcher summary classification, scheduled-task action arguments, and update-check log rotation.
- Changed: Local validation now validates offline cache argument generation, manifest export, replay script generation, and cache file delta tracking.
- Changed: Local validation now validates WinGet Configuration YAML generation.
- Changed: Local validation now validates profile gallery hashes, catalog references, preview text, and rejection of unsupported install-argument fields.
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
