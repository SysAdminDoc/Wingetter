# Research - Wingetter

## Executive Summary
Verified: Wingetter is a local Windows PowerShell/WPF cockpit for curated WinGet discovery, reviewed install/update runs, safe package options, source policy, profile/gallery import, update review, offline cache replay, and reproducible exports. Its strongest current shape is not breadth across every package manager; it is trustable workstation setup and recovery with visible preflight evidence. Highest-value direction: finish reliability/trust items already on ROADMAP.md, then close three net-new lifecycle gaps found in this pass: reviewed uninstall with dependency/path safeguards, profile compliance drift reporting, and structured package-risk warnings. Priority order: classify WinGet policy/constrained-language blockers; add reviewed uninstall preflight; add editable source-policy UI; add diagnostics bundle export; add profile compliance report; split operation/download state; persist update review state; add structured package-risk warnings; keep DSC v3/export work behind feature detection.

## Product Map
- Core workflows: search the 765-app catalog; choose packages, groups, or gallery profiles; review install/update preflight plans; run WinGet operations with logs; export PS1, Wingetter JSON, WinGet import JSON, WinGet Configuration, migration reports, source policy, and offline cache manifests.
- User personas: personal Windows rebuild user; small IT/helpdesk operator; privacy/corporate user with allowed sources; admin who wants local evidence without a fleet-management server.
- Platforms and distribution: Windows 10/11, Windows PowerShell 5.1+, WPF, MIT license, raw GitHub launch path, checked-in `Wingetter.exe`, local validation through `tools\Invoke-Validation.ps1`.
- Key integrations and data flows: `winget.exe`; optional `Microsoft.WinGet.Client`; `%APPDATA%\Wingetter` groups/policy/log/cache state; `catalog\winget.json`; SHA256-verified `profiles\gallery\*.wingetter.json`; remote favicon fetches unless private/offline icon mode lands.

## Competitive Landscape
- UniGetUI: does multi-manager GUI breadth, installed/update views, uninstall, package options, translations, package bundles, and active operation/log iteration well. Wingetter should learn from operation separation, lifecycle actions, and remembered views; avoid copying multi-manager write support before source-specific trust and state models are proven.
- Winget-AutoUpdate: does scheduled policy, allow/block lists, deferrals, system/user-context behavior, and operational failure reports well. Wingetter should borrow blocker classification and review-friendly deferral concepts; avoid auto-installing scheduled updates because the current product is deliberately check-only.
- Chocolatey GUI / Chocolatey: mature package lifecycle UI with install/upgrade/uninstall, internal repositories, and error-reporting lessons. Wingetter should learn from single-instance, progress, and uninstall crash reports; avoid assuming Chocolatey source semantics apply to WinGet.
- winget-tui: compact active TUI with install, uninstall, upgrade, pin awareness, source filtering, sortable columns, CSV export, background operations, and backend abstraction. Wingetter should borrow lifecycle parity and configurable view state; avoid keyboard-first UX assumptions in a WPF mouse-driven app.
- Scoop / Awesome Scoop: strong portable-app/bucket ecosystem and repeatable per-user installs. The existing read-only Scoop adapter item is the right first step; write support should wait for duplicate-ID, bucket-trust, and portable state handling.
- Ninite Pro / Patch My PC / PDQ: commercial tools emphasize batch install/patch reliability, skipped/current reporting, detection, compliance, and downloadable evidence. Wingetter should borrow local diagnostics and compliance-drift reporting; avoid claiming endpoint remediation, vulnerability SLAs, or fleet coverage.
- WinGetty / WinGet REST source projects: useful model for private/internal packages, HTTPS, source setup, auth gaps, and metadata ownership. Wingetter should keep investing in source-policy editing and drift checks; avoid becoming a source-hosting server.

## Security, Privacy, and Reliability
- Verified risk: `src\Wingetter.WinGet.ps1:5-114` detects and repairs missing WinGet, but does not yet classify Group Policy disabled CLI, constrained language mode, or broken App Installer registration as distinct blockers; WAU issues #1162/#1112 support the existing P1 roadmap item.
- Verified risk: `src\Wingetter.Sources.ps1:144-162` already wires an `Uninstall` adapter operation, and `New-WinGetPackageOperationArguments` emits `winget uninstall`, but `New-WingetterRunPlan` only accepts `install`/`upgrade` and `src\Wingetter.Ui.ps1:3458-3548` only exposes install/update execution. Upstream WinGet issues #6116, #6215, and #6247 show uninstall needs dependency and portable PATH/symlink safeguards before UI exposure.
- Verified risk: profile/group data and installed/update caches exist, but there is no desired-vs-current compliance report before running a profile; UniGetUI issue #5020 shows stale package-manager metadata can reintroduce software users removed outside the package manager.
- Verified privacy gap: `src\Wingetter.Ui.ps1:134-180` remote favicon fetching remains a package-interest leak until the existing private/offline icon-mode item is implemented.
- Verified governance gap: `src\Wingetter.Sources.ps1:425-954` has policy storage/export/drift and redaction, while `src\Wingetter.Ui.ps1:2739-2742` only toggles corporate mode; source allow/block editing remains an existing roadmap item.
- Verified trust gap: package details show publisher/source/URL/SHA256 and missing-metadata warnings, but there is no structured warning taxonomy for WinGet PUA warnings, stale/unknown manifest risk, or catalog risk notes; WinGet PR #6293 and UniGetUI issue #4822 show this is an active package-manager security UX area.
- Verified recovery gap: offline cache replay verifies size/SHA256, and migration reports include run state, but the existing lockfile roadmap item is still needed for resolved source/version/options before upstream manifests drift.

## Architecture Assessment
- `src\Wingetter.Ui.ps1` remains the largest boundary; new uninstall, policy, diagnostics, compliance, warning, window-state, and operation-state work should put durable logic in helper modules and keep WPF handlers thin.
- `src\Wingetter.WinGet.ps1` is the right boundary for readiness classification, uninstall plan construction, warning parsing, and client feature gates because command building, result classification, installed scans, and details parsing already live there.
- `src\Wingetter.Sources.ps1` already has a capability model with `Uninstall`; new UI should consume capabilities and reject unsupported lifecycle operations per adapter rather than hard-coding WinGet-only assumptions.
- `src\Wingetter.Groups.ps1`, `src\Wingetter.ProfileGallery.ps1`, and `src\Wingetter.WinGet.ps1` already contain the inputs needed for a profile compliance report: desired packages, imports, installed records, update availability, pins, and source policy.
- `src\Wingetter.Configuration.ps1:55-91` emits configuration schema `0.2.0` with `Microsoft.WinGet.DSC/WinGetPackage`; native DSC v3 PackageList/Source/Pin support should remain feature-detected because upstream resources are active but not the default stable path.
- Testing should keep flowing through `tools\Invoke-Validation.ps1`; roadmap work should add focused fixtures to `tools\Test-WinGetRunner.ps1`, `tools\Test-PackageSources.ps1`, `tools\Test-ProfileJson.ps1`, and UI smoke/accessibility tests rather than new ad hoc scripts.
- Accessibility, i18n/l10n, observability, distribution, offline resilience, migration, upgrade strategy, plugin ecosystem, mobile, and multi-user review: accessibility tests exist and should grow with UI items; i18n is already deferred until workflow tests exist; diagnostics/lockfile/offline-cache/client-readiness items cover observability, migration, resilience, and upgrade strategy; source adapters are the plugin boundary; mobile and multi-user server features do not fit a local WPF reviewed-run tool.

## Rejected Ideas
- Full unattended fleet agent: rejected from WAU, Patch My PC, Ninite Pro, and PDQ evidence because Wingetter's verified value is reviewed local setup/recovery, not endpoint-agent remediation.
- Scheduled auto-install updates: rejected because `src\Wingetter.UpdateWatcher.ps1` is intentionally check-only; maintenance windows and deferrals should improve review timing, not bypass review.
- Write-capable Scoop/Chocolatey adapters now: rejected until the existing read-only Scoop roadmap item proves installed-state, search, duplicate handling, and trust UI.
- Native DSC v3 as the default export now: rejected because upstream WinGet DSC work is still active; keep a compatibility layer and fixture tests first.
- Direct VirusTotal integration now: rejected because UniGetUI issue #4822 requires BYOK API keys/rate-limit handling/custom proxy choices; Wingetter should first add a local structured warning model that can accept future external signals.
- Repair/reinstall automation now: rejected because WinGet issue #6144 depends on upstream API/CLI/PowerShell surfacing; add non-mutating guidance later only when feature detection can prove support.
- Mobile/web companion: rejected because WinGet repair, offline replay, WPF state, and local App Installer behavior are Windows desktop workflows.
- Full localization before boundary/test cleanup: rejected because ROADMAP.md already defers string extraction until workflow tests and smaller UI boundaries exist.

## Sources
Official docs, releases, and standards:
- https://learn.microsoft.com/en-us/windows/package-manager/winget/
- https://learn.microsoft.com/en-us/windows/package-manager/winget/uninstall
- https://learn.microsoft.com/en-us/windows/package-manager/winget/repair
- https://learn.microsoft.com/en-us/windows/package-manager/configuration/
- https://github.com/microsoft/winget-cli/releases/tag/v1.28.240
- https://github.com/microsoft/winget-cli/releases/tag/v1.29.280
- https://www.powershellgallery.com/packages/Microsoft.WinGet.Client/1.9.25190
- https://github.com/microsoft/winget-cli/issues/6116
- https://github.com/microsoft/winget-cli/issues/6215
- https://github.com/microsoft/winget-cli/issues/6247
- https://github.com/microsoft/winget-cli/issues/6144
- https://github.com/microsoft/winget-cli/pull/6293

OSS competitors and adjacent projects:
- https://github.com/Devolutions/UniGetUI
- https://github.com/Devolutions/UniGetUI/issues/4822
- https://github.com/Devolutions/UniGetUI/issues/5020
- https://github.com/Romanitho/Winget-AutoUpdate
- https://github.com/Romanitho/Winget-AutoUpdate/releases/tag/v2.12.0
- https://github.com/chocolatey/ChocolateyGUI
- https://github.com/chocolatey/ChocolateyGUI/issues/900
- https://github.com/shanselman/winget-tui
- https://github.com/thilojaeggi/WinGetty
- https://github.com/ScoopInstaller/Awesome-Scoop

Commercial, community, and supply-chain research:
- https://ninite.com/pro
- https://patchmypc.com/product/home-updater/
- https://www.pdq.com/package-library/
- https://stackoverflow.com/questions/tagged/winget
- https://slsa.dev/spec/v1.2/
- https://slsa.dev/blog/2024/08/dep-confusion-and-typosquatting
- https://csrc.nist.gov/pubs/sp/800/218/final
- https://nesbitt.io/2025/11/13/package-management-papers.html

## Open Questions
None block prioritization. Code-signing certificate availability only changes future release packaging, not the feature order above.
