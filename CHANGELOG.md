# Changelog

All notable changes to Wingetter will be documented in this file.

## [Unreleased]

- Security: Diagnostics bundles now redact bearer credentials, API keys, and token-like query parameters wherever they appear in captured output, including stderr and JSON log lines.
- Security: Raw-launch module downloads now use only the canonical GitHub source URL; the same-user `WINGETTER_MODULE_BASE_URL` override was removed to prevent redirecting usage metadata to an untrusted mirror.
- Refactored: Removed the unused `PumpUi` callback from package-source and offline-cache workers; their polling loops now perform only cancellation checks.
- Changed: `catalog/winget.json` is now the single catalog source of truth. Local runs load it directly, raw launches download it with SHA256 verification, and packaged builds embed a snapshot generated from the same JSON; the duplicate 765-app PowerShell literal was removed.

## [v6.2.0] - 2026-07-09

- Changed: Reimagined the main WPF shell around a premium discovery workspace with a full-width command area, responsive search, denser three-column catalog, and a persistent selection and run-options panel.
- Added: Live reviewed-selection queue with package names, IDs, compact identity marks, per-package remove actions, clear-all action, count-aware install/update calls to action, and helpful empty guidance.
- Fixed: Light theme now updates every new action-panel surface, border, primary/secondary text, and accent resource instead of retaining unreadable dark-theme values.
- Changed: Unified primary actions around an indigo accent while preserving semantic green for WinGet readiness and installed state and amber for update navigation.
- Changed: Refined catalog, empty, installed-app, profile-gallery, save-group, source-policy, update-policy, and run-plan surfaces with a shared navy/indigo visual language and bounded radius scale.
- Added: Keyboard activation and automation labels for app rows, category headers, category select-all controls, sidebar destinations, and selected-package remove actions.
- Fixed: Background UI smoke no longer opens the centered topmost splash, and screenshot rendering now uses a deterministic visual brush so theme and mode transitions are captured without black regions.
- Changed: Disabled report/stop utilities stay hidden until they are relevant, update-only pin options stay hidden in browse mode, and microcopy now describes actions and privacy/source behavior directly.

- Fixed: Top accent gradient bar now uses theme-appropriate colors in light mode (darker blues/greens) instead of the fixed dark-mode palette.
- Fixed: Run Plan dialog checkboxes now use a fully themed ControlTemplate (custom border, hover highlight, checkmark color) instead of default WPF chrome.
- Fixed: `Get-WingetterString` format string calls now wrapped in try/catch to prevent unhandled FormatException when callers pass mismatched argument counts.
- Removed: Stale codex-branding comments and fixed indentation in icon-loading section.
- Fixed: Run Plan dialog buttons now use proper themed background/foreground/border styling instead of default WPF chrome. Previously the computed theme colors were calculated but never applied to the button controls.
- Fixed: DOWNLOADED log entries now render with success-green background at creation time, matching the ApplyTheme re-theme behavior. Previously they fell through to the default neutral background.
- Fixed: Shift-click range selection in app list now wrapped in try/catch to prevent unhandled exceptions from crashing the WPF dispatcher thread.
- Fixed: Details background worker now stores its async handle and calls Stop() before Dispose() during cleanup, preventing potential hangs and leaked async results.
- Fixed: During cache downloads, selection-dependent toolbar buttons (Install, Export, Copy Commands) now stay enabled correctly instead of flickering between enabled/disabled states due to conflicting OperationRunning checks.
- Fixed: `$ui["HoverBg"]` and `$ui["SelectedBg"]` initialization now matches the dark theme's actual `AppHoverBg`/`AppSelectedBg` values instead of non-theme colors.
- Fixed: Offline cache download log filenames now include GUID entropy suffix (matching install/update log pattern) to prevent timestamp collisions.
- Fixed: WinGet Configuration YAML export now writes UTF-8 without BOM via `Set-WingetterFileAtomic -NoBom`, preventing `winget configure` rejections on systems that don't accept BOM-prefixed YAML.
- Fixed: Configuration resource IDs now include an index suffix (`_1`, `_2`, etc.) to prevent duplicate IDs when package names differ only in characters that get normalized to underscores (e.g., `Foo.Bar` vs `Foo-Bar`).
- Fixed: Compliance report now correctly classifies packages with blank/malformed IDs as "Unresolved" instead of always falling through to "Missing" or "Current".
- Fixed: Diagnostics redaction now checks `$env:APPDATA` before `$env:USERPROFILE` so APPDATA paths get the correct `<appdata>` label instead of the less-specific `<user-profile>` label.
- Fixed: WinGet status dot colors now use theme tokens (`AccentGreen`, `LogSkip`, `LogFail`) instead of hardcoded hex values, adapting to light/dark mode.
- Fixed: "Review Updates" button and "Install Selected" button now use DynamicResource bindings (`UpdateBtnBg`/`UpdateBtnHover`, `AccentGreenBg`) so their colors update when the theme toggles, instead of staying fixed amber/green in both modes.
- Removed: Dead `Color` field from background worker log messages — these hex values were computed but discarded by `$AddLogEntry`.
- Security: External catalog `iconDomain` validation now also rejects semicolons, colons, at-signs, whitespace, angle brackets, and quotes in addition to the existing URL metacharacter checks.
- Fixed: Log entry rows now update their background, text, and status badge colors when the user toggles dark/light mode mid-session, instead of showing stale colors from the original render.
- Fixed: Generated PS1 install scripts now check for "already installed" text before checking exit code, correctly counting re-installs as skipped instead of newly installed.
- Fixed: Toolbar buttons "Diag", "Policy", "Sources" now have descriptive `AutomationProperties.Name` attributes for screen readers ("Export diagnostics bundle", "Edit update policy", "Edit source policy").
- Refactored: Version string is now defined once in `$Script:WingetterVersion` (Common.ps1) and referenced by Resources.ps1, splash screen, header badge, and window title. Version bumps now require changing only one line.
- Fixed: `Save-WingetterSettings` no longer re-reads settings from disk before writing, eliminating the read-modify-write race condition where two rapid saves could lose one change. Settings values (including null) are now written directly from the caller's object.
- Fixed: XAML ControlTemplate trigger colors (hover/focus borders, disabled button backgrounds) now use DynamicResource bindings to the theme system instead of hardcoded dark-mode hex values. Light mode hover borders now use the correct blue, and disabled Install/Update buttons use theme-appropriate muted backgrounds.
- Changed: Clicking a package row now loads details asynchronously in a background runspace instead of blocking the UI thread for 2-10+ seconds. The detail panel shows "loading..." placeholders immediately and fills in metadata when the background fetch completes. Rapid clicks on different packages correctly discard stale results via fetch-ID tracking.
- Fixed: Offline download error now correctly clears `CacheDownloadRunning` instead of `PackageOperationRunning`, preventing the UI from becoming permanently locked after a failed cache download.
- Fixed: All UI event handlers that call external functions (WinGet repair, settings save, group load/save/delete, package details, pin operations, corporate mode toggle) are now wrapped in try/catch to prevent unhandled exceptions from killing the WPF dispatcher thread.
- Fixed: Run log directory names now include millisecond precision and GUID entropy, consistent with other timestamped paths, preventing directory collision on rapid successive runs.
- Fixed: `Invoke-WingetterUpdateCheck` package ID collection now uses ArrayList instead of O(n^2) string array concatenation for 700+ packages.
- Removed: Dead code block in `Export-WingetterRunLockfile` that read result files and matched version patterns but never used the captured values.
- Removed: Dead `$ui["OperationMode"]` state that was set but never read.
- Fixed: Pin badges now use theme-system colors (`PinBadgeBg`, `PinBadgeBorder`, `PinBadgeText`) and are updated when the user toggles dark/light mode. Previously they used hardcoded dark-mode colors that were invisible in light mode.
- Fixed: Empty state eyebrow text (`"Nothing to show"`) is now themed via `CategoryTitle` instead of hardcoded `#8cd2ff`.
- Fixed: Sidebar internal header border is now themed via `SidebarBorder` instead of hardcoded `#1d2a3a`.
- Fixed: Update sort label is now themed via `FooterText` instead of hardcoded `#94a7bc`.
- Fixed: Version pill badge in the header now uses `StatusPillBg`/`StatusPillBorder` theme tokens instead of hardcoded dark-mode colors.
- Fixed: Source health guidance strings now quote `$SourceName` in generated shell commands to prevent issues with special characters when users copy-paste the suggested commands.
- Fixed: Tooltip ID text now uses `AppSubtleText` theme token instead of hardcoded `#6c7a89`.
- Fixed: Log entry status text colors now use the theme's `LogSuccess`/`LogFail`/`LogSkip` values instead of hardcoded worker-sent colors that didn't match any theme. Status badge background uses `LogEntryBg`.
- Added: `Wingetter.Resources.ps1` centralizes user-facing UI strings into a keyed `$Script:WingetterStrings` hashtable with `Get-WingetterString` accessor supporting `[string]::Format` placeholders. Initial extraction covers progress bar defaults, button labels, update view hints, and empty-state text. The pattern is established for incremental extraction of remaining strings.
- Added: WinGet DSC v3 `PackageList` export support. `ConvertTo-WingetterConfigurationYaml` accepts a `-ResourceFormat` parameter (`Auto`, `PerPackage`, `PackageList`). Auto-detection probes for `Microsoft.WinGet.DSC` v3+ and falls back to per-package `WinGetPackage` resources when unavailable. The `PackageList` format emits a single resource with a packages array instead of one resource per package.
- Added: Source Policy editor dialog accessible via the toolbar "Sources" button. Edits corporate mode toggle, allowed sources (Name,Type,URL,TrustLevel per line), and private REST sources (Name,URL per line). Validates source names and field counts before saving. The dialog respects the current theme and refreshes the corporate mode checkbox on save.
- Added: Update Policy editor dialog accessible via the toolbar "Update Policy" button. Edits global not-before UTC, max deferrals, and maintenance windows (Name,Days,Start,End format). Validates datetime format and time ranges before saving. The dialog respects the current theme and preserves existing per-package policies.
- Added: Update view now has a sort control (Name, Category, Installed Version) that persists the selected sort order in `settings.json` under `UpdateSortBy`. The sort is applied when entering update mode and when changed, and falls back to "Name" for invalid saved values.
- Changed: Install/update and offline-cache operations now use separate state tracking (`PackageOperationRunning` / `CacheDownloadRunning`). Package operations block all controls as before. Cache downloads block only install/update/download buttons but allow browsing, selection, search, export, and group management to continue. Both types prevent starting the other type concurrently.
- Added: Read-only Scoop source adapter (`Wingetter.Scoop.ps1`). Detects Scoop installation via `$env:SCOOP` or `~/scoop`, discovers installed apps from the apps directory with version/bucket metadata, and registers as a package source with `InstalledScan` capability. All mutating operations (install/upgrade/uninstall) throw as expected for a read-only adapter. Tests verify adapter contract, capabilities, and availability status.
- Fixed: XmlReader and StringReader instances for the main window, save-group dialog, and profile gallery dialog are now disposed after `XamlReader.Load()` returns, preventing native resource leaks during a session.
- Refactored: `Get-WingetterFileSha256` in `Wingetter.Common.ps1` is now guarded by `Get-Command` so the launcher's pre-existing definition is reused instead of silently shadowed. Eliminates the fragile manual-sync requirement between the two identical copies.
- Fixed: ProgressBar fill gradient is now theme-aware. Dark mode uses `#1fb879`-`#34d399`; light mode uses `#198754`-`#20a76e`. The ControlTemplate now binds to `Foreground` so `ApplyTheme` can update the gradient at runtime.
- Security: External catalog `iconDomain` values are now validated to reject URL-encoding tricks and injected query parameters (`/`, `\`, `?`, `#`, `&`, `=`, `%`). Invalid domains fall back to an empty icon URL.
- Fixed: Offline download process streams now use try/catch around `GetAwaiter().GetResult()` after `Kill()`, preventing `IOException`/`OperationCanceledException` from aborting the download loop on cancel. Process is also properly disposed in a `finally` block.
- Fixed: Background installed-scan runspace now loads `Wingetter.Common.ps1` so `Set-WingetterFileAtomic`, `Get-WingetterAppDataPath`, and other Common helpers are available. Previously the installed-cache file was silently never persisted from background scans.
- Fixed: Toast notification XML now escapes interpolated values via `SecurityElement.Escape()` so source names or statuses containing `&`, `<`, `>` cannot break the XML.
- Fixed: `Join-ProcessArguments` now doubles trailing backslashes before the closing quote per MSVC CRT argument parsing convention. Paths like `C:\path to\` no longer produce broken arguments where the backslash escapes the closing quote.
- Fixed: `Export-WingetterConfigurationFile` now uses `Set-WingetterFileAtomic` instead of direct `Set-Content`, consistent with all other file-writing paths.
- Fixed: Maintenance window with equal start and end times is now skipped (zero-width window) instead of matching for one second. End boundary is now exclusive to match standard interval semantics.
- Fixed: Icon cache filename is now derived from the URL instead of the display name, preventing cache collisions between apps whose names differ only in non-word characters.
- Security: Icon downloads now validate that URLs use HTTPS scheme before fetching, preventing SSRF via crafted external catalog entries with `file://` or internal HTTP URLs.
- Fixed: Markdown migration report tables now pipe-escape all fields (name, ID, status, versions, source), not just the command and reason columns.
- Fixed: JSON import flow rejects files larger than 5 MB before parsing to prevent OOM on oversized inputs.
- Fixed: Splash window is now closed in a `finally` block so it cannot remain orphaned on screen if an exception occurs during initialization.
- Fixed: Replaced `System.Windows.Forms.Application.DoEvents()` with `Dispatcher.Invoke` to prevent reentrancy during package detail loading and pin operations.
- Fixed: `ClearSearchBtn` now has `AutomationProperties.Name="Clear search filter"` for screen reader users.
- Fixed: Launcher now cleans up stale `%TEMP%\Wingetter\src-*` download directories, keeping only the 3 most recent.
- Fixed: Plan review, profile gallery, and save group dialogs now respect the current theme (dark/light) instead of using hardcoded dark-mode colors. All three dialogs derive their background, text, border, input, and button colors from the active theme state.
- Fixed: `Export-GroupAsPS1` now escapes the group name via `ConvertTo-WingetterPowerShellSingleQuotedString` in the generated script, preventing syntax errors when group names contain backticks, dollar signs, or quotes.
- Added: Uninstall preflight plan support in `New-WingetterRunPlan`. The `uninstall` action validates that packages are installed before marking them runnable, refuses non-installed packages (NOT_INSTALLED skip), applies source-policy blocking, and generates a reviewed plan with the same schema as install/upgrade plans.
- Added: `Export-WingetterRunLockfile` generates a lockfile from a migration report with package ID, source, installed version, available version, and install options for all successful packages. `Compare-WingetterLockfile` checks a lockfile against current installed state and reports Missing/VersionChanged/None drift per entry.
- Added: `Get-WingetterPackageRiskWarnings` parses `winget show` output and catalog risk notes into structured severity-coded warnings: PUA_WARNING (Critical), MISSING_HASH/HTTP_INSTALLER (Warning), DEPRECATED/NO_LICENSE/CATALOG_NOTE (Info). Fixture tests cover PUA, missing hash, HTTP installer, catalog risk notes, and benign package output.
- Added: `New-WingetterComplianceReport` generates a no-mutation drift report comparing desired profile packages against installed state, classifying each as Current/Missing/UpdateAvailable/Pinned/SourceBlocked with installed version, available version, source, and pin details. Fixture tests cover pinned, blocked, missing, and current states.
- Added: `Get-WingetterRetryPackagesFromReport` extracts failed, cancelled, and not-run packages from a migration report for retry. Preserves original install options from the run plan and marks each package with its prior status. Tests cover all-success, partial-failure, and null report inputs.
- Added: `Get-WingetterSelfUpdateStatus` non-mutating self-update check. Fetches the remote `release/manifest.json` with a timeout, compares version and bundle hash against the local manifest, checks Authenticode signature on `Wingetter.exe`, and reports Current/UpdateAvailable/HashMismatch/FetchFailed status. Included in the diagnostics bundle as `metadata/self-update-status.json`. Never replaces files.
- Added: Catalog freshness audit with result caching. The `-CheckWingetAvailability` flag in `Test-Catalog.ps1` now runs `winget show --id --exact --source winget` probes, caches results per package in `%APPDATA%\Wingetter\catalog-audit-cache.json` with a configurable TTL (default 7 days), skips already-cached packages, and reports missing/error status per failed ID.
- Added: `tools\Compare-WingetterCatalog.ps1` diff tool that compares the current catalog against a git baseline (default `HEAD`) and reports added, removed, renamed, and category-moved packages plus gallery profile impact. Removed packages referenced by gallery profiles are flagged as breaking.
- Added: Single-instance guard with activation handoff. `Start-Wingetter` acquires a user-scoped named mutex; a second launch detects the existing instance, brings it to the foreground (restoring from minimized if needed), shows an informational message, and exits without starting package operations.
- Added: `Remove-WingetterProgressNoise` collapses spinner (`|/-\`), progress bar (`[====]`), percentage-only, and ANSI escape lines from captured WinGet stdout/stderr while preserving meaningful installer output. `Get-TextExcerpt` now filters through it so GUI log summaries and migration report excerpts show only actionable text; raw logs remain unmodified on disk.
- Added: Window bounds persistence with DPI and monitor safety. The main window saves its position, size, and state to `settings.json` on close and restores them on next launch; saved bounds are only applied when they overlap a current monitor working area by at least 50px and meet minimum dimension requirements.
- Added: WinGet source-health diagnostics. `ConvertFrom-WinGetSourceListText` parses `winget source list` column output, `Get-WingetterSourceHealthState` classifies per-source update results into Ok/Corrupt/AuthRequired/Offline/Unknown states with non-mutating reset/repair guidance, `Get-WingetterSourceHealth` runs bounded probes and returns a structured summary, and the diagnostics bundle now includes a `source-health/source-health.json` file. Fixture-based tests cover all classification paths.
- Changed: `Set-WingetterFileAtomic` moved from `Wingetter.WinGet.ps1` to `Wingetter.Common.ps1` so all modules use it directly without `Get-Command` fallback guards. Settings, groups, source policy, update policy, update-check results, run-plan exports, migration reports, group exports, offline-cache manifests, and source-policy exports now all write via temp-file-plus-rename, preventing partial files from concurrent writes or interrupted saves.
- Added: Scheduled update policy controls. Update checks now load `%APPDATA%\Wingetter\update-policy.json`, support global and per-package `NotBeforeUtc` deferrals, max-deferral limits, maintenance windows, deferred/outside-window counts, and scheduled-task propagation through `-UpdatePolicyPath`.
- Added: Redacted diagnostics bundle export. The GUI **Diagnostics** action and `tools\Export-DiagnosticsBundle.ps1` write a ZIP with catalog/version metadata, recent logs, update-check summaries, migration report evidence, `winget --info`, source and pin captures, and source policy data with private headers redacted.
- Added: Private icon mode. A persisted `settings.json` flag disables remote favicon fetches, keeps deterministic letter icons, and the non-private icon loader now uses cache TTL checks plus short network timeouts.
- Added: WinGet client readiness reporting now labels stable, prerelease, old, and unparsable clients, exposes supported feature gates for clean output/list sorting/source priority, and shows exact update and repair commands in the GUI status tooltip.
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

## Roadmap archive — 2026-08-10 — ROADMAP.md

<details>
<summary>Original roadmap snapshot</summary>

```markdown
# Roadmap - Wingetter

## Audit-Driven Items

### P2

- [ ] P2 - Diagnostics bundle may miss header tokens in non-standard log positions
  Why: Header tokens in run log files are redacted via regex patterns, but tokens appearing in unexpected positions (e.g., stderr output, URL query parameters) may slip through the generic patterns.
  Where: `src\Wingetter.Diagnostics.ps1` redaction patterns

- [ ] P2 - WINGETTER_MODULE_BASE_URL env var enables download-source information leak
  Why: Any same-user process can set this env var to redirect module download requests to an attacker server. SHA256 hash verification prevents code execution but the attacker learns the user's IP and Wingetter usage.
  Where: `Wingetter.ps1` download path

### P3

- [ ] P3 - `$PumpUi` scriptblock is dead logic in background worker
  Why: The PumpUi parameter defaults to an empty scriptblock and is never set to anything useful by the UI tier. The 100ms polling loop serves only for cancel-checking.
  Where: `src\Wingetter.WinGet.ps1` Invoke-WinGetPackageOperation

- [ ] P3 - Embedded SoftwareDatabase in Catalog.ps1 can drift from external catalog JSON
  Why: The 765-app database is maintained both as PowerShell literals in source code and as JSON at catalog/winget.json. Sync requires running tools/Sync-EmbeddedCatalog.ps1 manually.
  Where: `src\Wingetter.Catalog.ps1`, `catalog\winget.json`

- [ ] P3 - `Restore-WingetterWindowBounds` depends on System.Windows.Forms loaded by App.ps1
  Why: Common.ps1 references `[System.Windows.Forms.Screen]::AllScreens` but is loaded before App.ps1 calls `Add-Type -AssemblyName System.Windows.Forms`. Works in practice because the function is only called after runtime init, but is a latent ordering dependency.
  Where: `src\Wingetter.Common.ps1`, `src\Wingetter.App.ps1`
```

</details>
