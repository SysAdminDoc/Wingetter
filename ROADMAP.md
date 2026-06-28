# Roadmap - Wingetter

## Research-Driven Additions

### P1

- [ ] P1 - Add a preflight run plan
  Why: Users should know before execution which selected packages are already current, pinned, blocked by source policy, unavailable, missing metadata, or likely to update.
  Evidence: Ninite skip-current reporting; WinGet import/export warning model; `src/Wingetter.WinGet.ps1:818-870`; `src/Wingetter.UpdateWatcher.ps1:184-205`.
  Touches: `src\Wingetter.WinGet.ps1`, `src\Wingetter.Sources.ps1`, `src\Wingetter.Ui.ps1`, `src\Wingetter.Groups.ps1`, `tools\Test-WinGetRunner.ps1`.
  Acceptance: clicking install/update first builds a reviewable JSON-backed plan with per-package action/status/reason/source/pin/version fields; blocked or unresolved packages are removable before execution; final migration report includes the plan.
  Complexity: L

- [ ] P1 - Add UI automation and screenshot accessibility smoke tests
  Why: Current tests parse XAML and control labels but do not exercise dark/light themes, profile/gallery dialogs, update mode, empty states, overflow, or screen-reader flow.
  Evidence: `tools\Test-VisualAccessibility.ps1`; `tools\Test-Xaml.ps1`; `src/Wingetter.Ui.ps1:624-680`; Chocolatey GUI issue #645; UniGetUI v2026.2.2 UI-state release notes.
  Touches: `tools\Test-UiSmoke.ps1` (new), `src\Wingetter.Ui.ps1`, `README.md`.
  Acceptance: an STA smoke test launches the app against fixture data, toggles themes, searches to empty state, opens profile gallery, enters/exits update mode, captures screenshots, and fails on missing focus labels or obvious clipping/overlap.
  Complexity: L

- [ ] P1 - Rebuild and verify release artifacts from the bundled launcher
  Why: Hash verification proves checked-in artifacts are unchanged, not that `Wingetter.exe` reflects the current modular source or carries a trusted signature/provenance.
  Evidence: `release/manifest.json`; `release/README.md:31-45`; `tools\Build-WingetterExe.ps1`; `tools\Test-Bundle.ps1`; Authenticode docs; SLSA provenance guidance.
  Touches: `tools\Build-WingetterExe.ps1`, `tools\Test-ReleaseArtifact.ps1`, `release\manifest.json`, `release\README.md`, `Wingetter.exe`.
  Acceptance: release verifier proves the EXE was built from the current bundled script hash; manifest records bundle hash, tool version, and Authenticode status; signing is applied when a code-signing cert is available or the unsigned state is explicit.
  Complexity: M

### P2

- [ ] P2 - Add source priority and source drift audit
  Why: WinGet 1.29 source priority changes search/disambiguation behavior, while Wingetter source policy currently stores allow/trust data without priority or live drift checks.
  Evidence: `microsoft/winget-cli` v1.29.280 release; `src/Wingetter.Sources.ps1:418-452`; `src/Wingetter.Sources.ps1:684-739`; Microsoft `winget source` docs.
  Touches: `src\Wingetter.Sources.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-SourcePolicy.ps1`, `README.md`.
  Acceptance: policy supports optional `Priority`; export emits priority-aware commands when WinGet supports them; a drift check compares policy to `winget source list` and reports missing, extra, changed, explicit, trust, and priority differences.
  Complexity: M

- [ ] P2 - Preserve safe per-package install options in profiles
  Why: WinGet and UniGetUI both support per-package scope/architecture/installer type/location/customization, but Wingetter profiles mostly preserve IDs and source names.
  Evidence: Microsoft install/upgrade docs; WinGet 1.29 preserved custom/override release note; `microsoft/winget-cli#3401`; `src/Wingetter.Groups.ps1:137-166`; `src/Wingetter.ProfileGallery.ps1:28-45`.
  Touches: `src\Wingetter.Groups.ps1`, `src\Wingetter.ProfileGallery.ps1`, `src\Wingetter.WinGet.ps1`, `src\Wingetter.Configuration.ps1`, `src\Wingetter.Ui.ps1`, `tools\Test-ProfileJson.ps1`.
  Acceptance: Wingetter group JSON can store vetted install options; official WinGet imports preserve safe fields as warnings/metadata; gallery profiles continue rejecting unsafe install-argument fields unless explicitly allowlisted; generated commands quote and test every option.
  Complexity: L

- [ ] P2 - Prototype a read-only Scoop source adapter
  Why: The adapter contract exists but only WinGet is registered; Scoop is a high-signal adjacent ecosystem with buckets and portable-app semantics that should be proven read-only before install support.
  Evidence: `src/Wingetter.Sources.ps1:58-75`; `src/Wingetter.Sources.ps1:218-224`; UniGetUI README; Scoop README; Awesome Scoop.
  Touches: `src\Wingetter.Sources.ps1`, `src\Wingetter.Scoop.ps1` (new), `src\Wingetter.Ui.ps1`, `tools\Test-PackageSources.ps1`.
  Acceptance: if Scoop is installed, Wingetter can discover/search installed Scoop apps and show source-specific details under a capability flag; no Scoop install/update commands are emitted; tests use local fixture bucket data.
  Complexity: L

- [ ] P2 - Add redacted diagnostics bundle export
  Why: Logs, source policy, update checks, migration reports, WinGet info, sources, and pins are scattered, making support/recovery harder than competitor reporting workflows.
  Evidence: `src/Wingetter.WinGet.ps1:394-414`; `src/Wingetter.UpdateWatcher.ps1:107-147`; `src/Wingetter.Groups.ps1:274-382`; PDQ/Patch My PC reporting patterns.
  Touches: `src\Wingetter.Diagnostics.ps1` (new), `src\Wingetter.Ui.ps1`, `tools\Test-Diagnostics.ps1` (new), `README.md`.
  Acceptance: one GUI action and one CLI helper export a ZIP containing recent logs, migration report, update-check summaries, catalog/version info, `winget --info`, source list, pin list, and redacted policy; tests assert no private headers are included.
  Complexity: M

- [ ] P2 - Add update review deferrals and maintenance policy
  Why: Update checks are useful but lack deferral/maintenance controls that WAU users explicitly request for supply-chain delay and work-hours friendliness.
  Evidence: `src/Wingetter.UpdateWatcher.ps1:156-240`; Romanitho/Winget-AutoUpdate issues #1153 and #1121.
  Touches: `src\Wingetter.UpdateWatcher.ps1`, `src\Wingetter.Ui.ps1`, `tools\Invoke-UpdateCheck.ps1`, `tools\Register-UpdateWatcher.ps1`, `tools\Test-UpdateWatcher.ps1`.
  Acceptance: update-check policy can set per-package or global `NotBeforeUtc`, max deferrals, and maintenance windows; logs explain skipped/deferred updates; no path auto-installs packages.
  Complexity: M

- [ ] P2 - Add private/offline icon mode
  Why: Parallel Google favicon fetches improve polish but leak package-interest traffic and can slow restricted networks.
  Evidence: `src/Wingetter.Ui.ps1:3020-3060`; privacy-oriented profile/persona; prior security review.
  Touches: `src\Wingetter.Ui.ps1`, `src\Wingetter.Common.ps1`, `README.md`, `tools\Test-VisualAccessibility.ps1`.
  Acceptance: a persisted setting disables remote icon fetches and uses deterministic letter icons; remote icon fetches have timeout and TTL; UI remains responsive when network is blocked.
  Complexity: S

### P3

- [ ] P3 - Extract UI strings after workflow tests exist
  Why: Full UI localization is not the next reliability bottleneck, but the current monolithic XAML/event module makes future localization expensive.
  Evidence: `src/Wingetter.Ui.ps1` line count; UniGetUI translation infrastructure; existing locale-independent WinGet result fixtures.
  Touches: `src\Wingetter.Ui.ps1`, `src\Wingetter.Resources.ps1` (new), `tools\Test-UiSmoke.ps1`.
  Acceptance: user-facing strings are centralized after UI smoke tests land; existing English UI behavior and accessibility names remain unchanged; no locale is added until extraction is covered.
  Complexity: L
