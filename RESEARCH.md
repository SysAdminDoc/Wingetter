# Research - Wingetter

## Executive Summary
Wingetter is a Windows-first PowerShell/WPF setup cockpit for curated WinGet discovery, bulk install/update, reusable profiles, source policy, scheduled check-only update scans, offline installer caches, and migration reports. Verified: the current repo is stronger than the prior research state because preflight plans, background operation runspaces, clean WinGet 1.29 output, redacted private-source export, offline-cache hash replay checks, launcher hash pinning, release-artifact verification, and a UI smoke harness now exist. Current blocker: `tools\Invoke-Validation.ps1` is red in the working tree because UI smoke, launcher manifest, and PSScriptAnalyzer checks fail against modified UI code. Highest-value direction: restore the local validation contract first, then keep pushing toward a trustworthy local setup/recovery tool rather than a broad package-manager clone. Top opportunities in priority order: restore validation; keep the existing UI smoke item honest by adding screen-reader/focus assertions; make release provenance and Authenticode status explicit; audit live source/catalog drift; preserve safe per-package install options and lockfile state; add diagnostics export; add update deferrals/maintenance windows; add private icon mode; persist window layout safely across DPI/display changes; normalize noisy installer logs; and add catalog freshness checks against live WinGet metadata.

## Product Map
- Core workflows: browse/search 765 curated WinGet apps; select individual apps, groups, or gallery profiles; review an install/update preflight plan; run WinGet operations with structured logs; export profiles/scripts/WinGet JSON/WinGet Configuration; build offline caches and migration reports.
- User personas: personal Windows power user rebuilding a PC; small IT/helpdesk user preparing repeatable workstation profiles; privacy/corporate user enforcing allowed sources; admin who wants local audit trails without a full endpoint-management suite.
- Platforms and distribution: Windows 10/11, Windows PowerShell 5.1+, WPF, raw GitHub quick-launch, checked-in bundled `Wingetter.exe`, MIT license, local validation via `tools\Invoke-Validation.ps1`.
- Key integrations and data flows: `winget.exe`; optional `Microsoft.WinGet.Client`; `%APPDATA%\Wingetter` groups/source policy/logs/cache; checked-in `catalog/*.json`; SHA256-verified `profiles/gallery/*.wingetter.json`; Google favicon URLs unless private icon mode is added.

## Competitive Landscape
- UniGetUI: strong at multi-manager breadth, per-package options, import/export, auto-update notifications, translations, log viewing, installer checksums, and active UI iteration. Wingetter should borrow option persistence, source trust messaging, and workflow polish; avoid cloning the full manager surface before the existing adapter contract is proven beyond WinGet.
- Winget-AutoUpdate: strong at scheduled updates, system/user context handling, allow/block lists, GPO/Intune-friendly configuration, metered-network behavior, log rotation, mods, locale/version arguments, and user-requested deferral controls. Wingetter should borrow deferral/maintenance policy and argument modeling while keeping updates check-only by default.
- Ninite/Ninite Pro: strong at fast batch install, skip-current behavior, simple patching, and reporting. Wingetter should keep the low-friction setup path but continue exposing source, pin, version, and command details.
- Patch My PC / PDQ: strong at tested package chains, reporting, deployment rings, vulnerability/workstation reporting, and package request workflows. Wingetter should borrow diagnostics and chain-of-custody ideas for local/offline runs; avoid claiming endpoint-management depth.
- Chocolatey GUI / Chocolatey for Business: mature Windows package-source and internal-repository patterns, plus issue templates that require debug logs and secret redaction. Wingetter should treat Chocolatey as a future adapter with separate trust semantics; avoid mixing Chocolatey assumptions into WinGet source policy.
- Scoop / Awesome Scoop: strong portable-app ecosystem, bucket indexes, repeatable script-friendly setup, and side-effect-minimized installs. Wingetter's planned read-only Scoop adapter is the right first step; write support should wait for bucket trust and duplicate-ID modeling.
- guinget / winstall-style tools / newer WinGet GUI wrappers: validate demand for simple WinGet browsing, profiles, and update views. Wingetter should keep its curated catalog, source policy, offline cache, and validation advantage; avoid becoming a stale one-screen wrapper.

## Security, Privacy, and Reliability
- Verified supply-chain gap: `Wingetter.ps1` hash-pins downloaded modules, and `release\manifest.json` verifies checked-in artifacts, but the launcher/EXE still need explicit Authenticode status and build-input provenance as tracked in the existing release roadmap item.
- Verified source-trust gap: `src\Wingetter.Sources.ps1` has allow-source/private-source helpers, but source priority and live drift comparison against `winget source list` remain unfinished and are already captured in ROADMAP.
- Verified privacy gap: `src\Wingetter.Ui.ps1:131-180` and icon-loading state use remote favicon URLs with a temp cache; private/offline icon mode remains a worthwhile P2 already in ROADMAP.
- Verified catalog freshness gap: `tools\Test-Catalog.ps1:192-279` validates local structure, counts, generated fallbacks, README, and changelog, but only one optional `winget show` path is visible and there is no bounded live audit for removed/renamed IDs, metadata drift, or icon URL drift across the 765-app catalog.
- Verified recovery gap: offline caches now hash-check replay files, but exported profiles do not yet carry a lockfile of resolved source, version, installer hash, and options, so migration can still drift when upstream manifests change.
- Verified UX reliability gap: `src\Wingetter.Ui.ps1:780-781` starts at fixed 1450x920 centered dimensions; no persisted safe restore exists for multi-monitor or DPI changes, while competitor issue traffic shows window placement still matters for package managers.
- Verified log-readability gap: WinGet 1.29 `--no-progress` support helps, but older WinGet or installer-specific spinner/progress output can still flood logs; UniGetUI issue traffic shows users need readable operation logs during long package runs.
- Verified validation blocker: `tools\Invoke-Validation.ps1` currently fails in the working tree. UI smoke throws from `ShowDialog`, launcher manifest reports a stale `Wingetter.Ui.ps1` hash, and PSScriptAnalyzer flags `src\Wingetter.Ui.ps1:3591` for assigning to automatic variable `$eventArgs`.

## Architecture Assessment
- `src\Wingetter.Ui.ps1` is still the dominant module at 3995 lines; feature additions should keep moving durable policy, diagnostics, window settings, and log normalization into small helper modules instead of adding more event-handler bulk.
- `tools\Test-UiSmoke.ps1` is present and is wired into validation, but the current smoke run fails before it can prove the screenshots; the existing P1 UI smoke roadmap item should be interpreted as stabilizing the harness plus adding focus/screen-reader/overlap assertions.
- Profile import/export lives in `src\Wingetter.Groups.ps1:137-269` and currently centers on IDs/source names/warnings; WinGet 1.29 preserved custom/override arguments make safe option persistence and lockfile export more valuable now.
- Offline cache metadata in `src\Wingetter.OfflineCache.ps1:175-361` already records package files and SHA256; a profile/run lockfile should reuse that model rather than inventing a separate provenance format.
- Scheduled update checks in `src\Wingetter.UpdateWatcher.ps1` are check-only and already respect metered networks/log rotation; roadmap deferrals should extend this policy layer without introducing unattended installs.
- `tools\Invoke-Validation.ps1` is the right local validation contract; research-driven changes should add targeted tests there instead of new one-off validation entry points.

## Rejected Ideas
- Full enterprise agent: rejected because Wingetter's strength is local setup/recovery and reviewed runs; WAU, Patch My PC, PDQ, and Intune already cover unattended fleet deployment.
- Auto-installing scheduled updates: rejected because current update watcher is deliberately check-only; deferrals and maintenance windows should improve review timing, not bypass review.
- Immediate write-capable Scoop/Chocolatey adapters: rejected until the read-only adapter proves search, installed scan, duplicate handling, and trust UI.
- Mobile or web companion: rejected because WinGet, App Installer, WPF, source policy, and offline replay are Windows desktop workflows.
- Recommendation engine: rejected because repo and competitor evidence points to trust, recovery, catalog quality, and workflow reliability first.
- Full localization before UI module/test cleanup: rejected because UI string extraction is already correctly deferred until workflow tests and smaller boundaries exist.

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
- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-authenticodesignature
- https://slsa.dev/spec/v1.2/

Competitors and adjacent tools:
- https://github.com/Devolutions/UniGetUI
- https://github.com/Devolutions/UniGetUI/releases/tag/v2026.2.2
- https://github.com/Devolutions/UniGetUI/issues/5018
- https://github.com/Devolutions/UniGetUI/issues/5004
- https://github.com/Devolutions/UniGetUI/issues/4799
- https://github.com/Romanitho/Winget-AutoUpdate
- https://github.com/Romanitho/Winget-AutoUpdate/issues/1153
- https://github.com/Romanitho/Winget-AutoUpdate/issues/1121
- https://ninite.com/pro
- https://patchmypc.com/product/home-updater/
- https://www.pdq.com/package-library/
- https://github.com/chocolatey/ChocolateyGUI
- https://github.com/ScoopInstaller/Scoop
- https://github.com/ScoopInstaller/Awesome-Scoop
- https://github.com/DrewNaylor/guinget
- https://winstall.app/

## Open Questions
None block prioritization. Code-signing certificate availability only changes whether release provenance lands first as Authenticode signing or as explicit unsigned build-input verification.
