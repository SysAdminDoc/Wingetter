# Research — Wingetter

## Executive Summary
Wingetter is a Windows-first PowerShell/WPF setup cockpit for curated WinGet discovery, bulk install/update, profile export/import, source policy, scheduled update checks, offline installer caching, and migration reports. Verified: the catalog is broad and internally consistent at 765 unique package IDs across 39 categories, the modular launcher hash-pins downloaded modules, and most validation scripts pass; the highest-value direction is to harden trust, release truth, and run recovery before adding more package managers. Top opportunities in order: restore one-command validation and fix current README/release drift; redact private source credentials from exports; hash-verify offline cache replay; adopt WinGet 1.29 clean-output/source-priority features; move long operations off the UI thread; add preflight run plans; add UI automation/accessibility smoke coverage; rebuild/sign release artifacts; add read-only non-WinGet adapters; export redacted diagnostics.

## Product Map
- Core workflows: browse/search curated Windows apps; select packages/groups/profiles; install/update serially through WinGet; export profiles/scripts/WinGet JSON/WinGet Configuration; inspect package trust/pins; build offline caches; run scheduled check-only update scans.
- User personas: personal power user rebuilding a PC; Windows admin preparing repeatable workstation profiles; small IT/helpdesk user who wants audit logs without an endpoint-management suite; privacy/corporate user who needs source allowlists.
- Platforms and distribution: Windows 10/11, Windows PowerShell 5.1+ WPF, raw `irm ... | iex` launcher, checked-in `Wingetter.exe`, local modular source under `src/`, no package manifest or external app framework.
- Key integrations and data flows: `winget.exe` for install/update/show/pin/download/source; `Microsoft.WinGet.Client` for object-based installed scans when available; `%APPDATA%\Wingetter` for groups/source policy/logs/cache; checked-in `catalog/*.json` and `profiles/gallery/*.wingetter.json`; Google favicon endpoint for remote icons.

## Competitive Landscape
- UniGetUI: does multi-manager install/update/uninstall, per-package options, export/import, tray updates, translations, security policy, and active release engineering well. Wingetter should learn from its package-source breadth, option persistence, warning about unofficial sources, and UI/state polish; avoid trying to clone its full package-manager manager surface before Wingetter's UI and adapter boundaries are smaller.
- Winget-AutoUpdate: does scheduled updates, allow/block lists, notifications, ADMX/Intune-friendly deployment, logs, user deferrals, and update-deadline thinking well. Wingetter should borrow check policy, deferral, logging, and rate-limit controls; avoid auto-installing updates by default because Wingetter's current philosophy is review-first and local-first.
- Ninite/Ninite Pro: does frictionless batch installs, silent patching, skip-current behavior, and simple reporting well. Wingetter should keep the new-PC setup path fast and make preflight/current-state reporting obvious; avoid hiding package source/trust details behind a too-simple picker.
- Patch My PC / PDQ: commercial tools win on tested package chains, reporting, vulnerability/deployment workflow, and package request loops. Wingetter should borrow chain-of-custody language for offline caches and diagnostics; avoid claiming enterprise endpoint management or vulnerability remediation.
- Chocolatey GUI / Chocolatey for Business: provides a mature Windows package ecosystem with GUI/package-source patterns and business/internal repository concepts. Wingetter should treat Chocolatey as a future adapter with separate trust semantics; avoid mixing Chocolatey scripts into WinGet-only source policy without clear capability flags.
- Scoop / Awesome Scoop: shows a portable-app bucket ecosystem and rich community indexes. Wingetter should prototype read-only discovery/installed-scan first; avoid write/install support until bucket trust, duplicate IDs, and portable install roots are modeled.
- Npackd/RuckZuck/guinget/winstall-style tools: validate demand for Windows package browsing, profile sharing, and simple GUI wrappers. Wingetter should keep its curated profile/reporting advantage; avoid stale one-off GUI surfaces with no validation/release story.

## Security, Privacy, and Reliability
- Validation-contract gap addressed after this research pass: README carries the `v6.1.0` badge, `tools\Invoke-Validation.ps1` is the one-command local runner, and release docs describe local validation/builds instead of removed workflow paths.
- Secret-leak risk addressed after this research pass: private REST source `Header` values and generated `winget source add --header` commands are redacted by default; raw header export now requires the explicit `-IncludeRawHeaders` switch and test coverage.
- Verified offline replay risk: `src/Wingetter.OfflineCache.ps1:162-180` records downloaded file paths but not file hashes; `src/Wingetter.OfflineCache.ps1:183-256` verifies path containment and extension allowlists before `Start-Process`, but does not verify file integrity before replay.
- Verified supply-chain gap: `Wingetter.ps1:43-56` hash-pins downloaded modules and `Wingetter.ps1:93-130` verifies staged module downloads, but the launcher script and checked-in EXE are not Authenticode-signed and the release verifier only checks hashes in `release/manifest.json`.
- Verified privacy gap: `src/Wingetter.Ui.ps1:3020-3060` fetches icons from remote favicon URLs in parallel and swallows failures; there is no private/offline icon mode, TTL, or timeout policy visible in settings.
- Verified reliability opportunity: WinGet 1.29 adds `--no-progress`, cleaner redirected list output, sortable `list`, source priority, and preserved custom/override export/import arguments; local installed WinGet is v1.28.240, so support must be version/feature detected.

## Architecture Assessment
- `src/Wingetter.Ui.ps1` is still the dominant module at 2,912 lines; install/update/offline click handlers run serial package operations from the UI event path with `System.Windows.Forms.Application.DoEvents()` (`src/Wingetter.Ui.ps1:2604-2674`) instead of a dedicated worker boundary.
- The source adapter contract is real, but only WinGet is registered (`src/Wingetter.Sources.ps1:58-75`, `src/Wingetter.Sources.ps1:218-224`); non-WinGet adapters should start read-only with source-specific capability flags.
- Profile/export models currently preserve package IDs/source names but not WinGet 1.29 custom/override arguments or install options (`src/Wingetter.Groups.ps1:137-166`, `src/Wingetter.Groups.ps1:185-271`); profile gallery strictness is good and should keep unsafe fields blocked by default (`src/Wingetter.ProfileGallery.ps1:28-45`).
- WinGet Configuration export emits only `id` and `source` resources (`src/Wingetter.Configuration.ps1:75-82`); this is correct for the current Microsoft resource surface, but should be documented as intentionally limited until upstream exposes more install settings.
- Testing is broad for helpers, parsers, XAML load, visual/accessibility linting, release hashes, launcher hashes, and bundling; the remaining gap is automated UI workflow/screenshot/screen-reader smoke that exercises major states across dark/light themes.
- Documentation hygiene still matters: ROADMAP should hold incomplete work only, README should point to `tools\Invoke-Validation.ps1`, and release docs should stay aligned with local-only build and artifact verification.

## Rejected Ideas
- Parallel installs now: rejected because current Microsoft docs describe multi-package install as sequential and local WinGet v1.28.240 help exposes no `--parallel`; parallelism would amplify installer contention and log/reboot risk.
- Auto-installing scheduled updates by default: rejected because Wingetter's watcher is explicitly check-only and WAU already serves unattended update automation; add review/deferral policy instead.
- Full enterprise SYSTEM/Intune agent: rejected because open WinGet issues still document SYSTEM-context and enterprise gaps; Wingetter should export compatible data and diagnostics, not become an endpoint agent.
- Cloud account sync: rejected because the product's local-first profile/export model is a strength; folder sync can work later without accounts.
- AI package recommendations: rejected because no repo evidence or ecosystem source shows this is higher leverage than trust, preflight, and recovery.
- Full UI localization as near-term work: rejected for now because locale-independent parsing already exists and the UI monolith needs smaller modules before string extraction; revisit after UI workflow tests and module split.
- Mobile/web companion: rejected because WinGet, WPF, App Installer, and offline replay are Windows desktop workflows.
- Immediate write-capable Scoop/Chocolatey adapters: rejected until a read-only adapter proves search, installed scan, source trust, duplicate handling, and tests.

## Sources
Official docs and platform:
- https://github.com/microsoft/winget-cli/releases/tag/v1.29.280
- https://learn.microsoft.com/en-us/windows/package-manager/winget/install
- https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade
- https://learn.microsoft.com/en-us/windows/package-manager/winget/export
- https://learn.microsoft.com/en-us/windows/package-manager/winget/import
- https://learn.microsoft.com/en-us/windows/package-manager/winget/source
- https://learn.microsoft.com/en-us/windows/package-manager/winget/pinning
- https://learn.microsoft.com/en-us/windows/package-manager/configuration/
- https://github.com/microsoft/winget-cli/blob/master/doc/Settings.md
- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-authenticodesignature

Competitors and adjacent tools:
- https://github.com/Devolutions/UniGetUI
- https://github.com/Devolutions/UniGetUI/releases/tag/v2026.2.2
- https://github.com/Devolutions/UniGetUI/issues/4984
- https://github.com/Devolutions/UniGetUI/issues/5004
- https://github.com/Romanitho/Winget-AutoUpdate
- https://github.com/Romanitho/Winget-AutoUpdate/issues/1153
- https://github.com/Romanitho/Winget-AutoUpdate/issues/1121
- https://github.com/Romanitho/Winget-AutoUpdate/issues/1166
- https://ninite.com/pro
- https://patchmypc.com/product/home-updater/
- https://www.pdq.com/package-library/
- https://github.com/chocolatey/ChocolateyGUI
- https://github.com/ScoopInstaller/Scoop
- https://github.com/ScoopInstaller/Awesome-Scoop
- https://github.com/npackd/npackd-cpp
- https://github.com/rzander/ruckzuck

Standards, security, and community signal:
- https://slsa.dev/spec/v1.2/
- https://github.com/microsoft/winget-cli/issues/6288
- https://github.com/microsoft/winget-cli/issues/5752
- https://github.com/microsoft/winget-cli/issues/3401

## Open Questions
None block prioritization. Code-signing certificate availability only changes whether release signing lands as Authenticode signing immediately or as hash/provenance verification first.
