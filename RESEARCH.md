# Research - Wingetter

## Executive Summary
Wingetter is a Windows-first PowerShell/WPF setup and recovery cockpit for curated WinGet browsing, reviewed bulk install/update runs, reusable profiles, source policy, scheduled check-only update scans, offline caches, and reproducible exports. Verified: the project is strongest when it stays a local trust-and-recovery tool rather than trying to become a fleet agent or a full multi-manager clone. Highest-value direction: harden the points where a user can get stuck or lose confidence before adding breadth. Top opportunities in priority order: classify WinGet policy/constrained-language blockers; keep the existing diagnostics, deferral, private icon, catalog freshness, lockfile, window restore, log normalization, and read-only Scoop roadmap items; add an editable source-policy workflow; add single-instance activation; split install/update and offline-download operation state; persist update-view sort/filter state; and prepare future WinGet DSC v3 export support behind feature detection.

## Product Map
- Core workflows: browse/search the 765-app curated catalog; select individual apps, groups, or gallery profiles; review an install/update plan; run WinGet operations with visible progress/logs; export Wingetter JSON, official WinGet JSON, PowerShell, and WinGet Configuration files; create offline caches and migration reports.
- User personas: personal Windows power user rebuilding a PC; small IT/helpdesk user preparing repeatable workstation profiles; privacy/corporate user enforcing allowed sources; admin who wants local evidence without a full endpoint-management stack.
- Platforms and distribution: Windows 10/11, Windows PowerShell 5.1+, WPF, raw GitHub quick-launch, checked-in `Wingetter.exe`, MIT license, local validation through `tools\Invoke-Validation.ps1`.
- Key integrations and data flows: `winget.exe`; optional `Microsoft.WinGet.Client`; `%APPDATA%\Wingetter` groups/source policy/logs/cache; `catalog\winget.json`; SHA256-verified `profiles\gallery\*.wingetter.json`; remote favicon URLs unless private/offline icon mode is implemented.

## Competitive Landscape
- UniGetUI: strong at multi-manager breadth, package options, import/export, update views, translations, and active log/UI iteration. Wingetter should learn from operation separation, remembered update ordering, and readable logs; avoid cloning all managers before the existing adapter boundary proves source-specific trust semantics.
- Winget-AutoUpdate: strong at scheduled update policy, allow/block lists, system/user-context behavior, metered-network handling, and deferrals. Wingetter should borrow policy/deferral and bootstrap-failure clarity while preserving its check-only scheduled update stance.
- Chocolatey GUI / Chocolatey: mature Windows package-source, internal repository, and log/error-reporting patterns. Wingetter should borrow single-instance handling and progress/error clarity; avoid applying Chocolatey assumptions to WinGet source policy.
- Scoop / Awesome Scoop: strong portable-app and bucket ecosystem with script-friendly repeatability. Wingetter's existing read-only Scoop adapter item is the right first step; write support should wait for duplicate-ID, bucket-trust, and portable-app state modeling.
- Ninite Pro / Patch My PC: strong at fast batch install, patching cadence, skip-current behavior, and reporting. Wingetter should borrow simple recovery/diagnostic artifacts and chain-of-custody thinking; avoid claiming endpoint-management or vulnerability-remediation coverage.

## Security, Privacy, and Reliability
- Verified risk: `src\Wingetter.WinGet.ps1:5-114` detects/repairs WinGet availability but does not classify Group Policy disabled CLI, constrained language mode, or broken App Installer registration as distinct blockers; WAU issues #1162 and #1112 show these are real operational failures.
- Verified risk: no `Mutex`/single-instance guard was found, while the UI uses background operations and `%APPDATA%\Wingetter` state; ChocolateyGUI issue #1099 shows a second package-manager instance silently failing is a user-visible reliability problem.
- Verified privacy gap: `src\Wingetter.Ui.ps1:134-180` remote favicon fetching and `src\Wingetter.Ui.ps1:4241-4304` icon queue processing still need the existing private/offline icon-mode roadmap item.
- Verified governance gap: `src\Wingetter.Sources.ps1:425-954` supports policy storage, export, drift, and private-source redaction, but `src\Wingetter.Ui.ps1:2739-2742` only toggles corporate mode; there is no safe GUI to edit allowlist/blocklist/source definitions.
- Verified recovery gap: offline cache metadata records files and SHA256 values, but profiles and migration outputs still need the existing lockfile roadmap item to capture resolved source/version/options before upstream WinGet manifests drift.
- Verified operational gap: `src\Wingetter.Ui.ps1:985` and `src\Wingetter.Ui.ps1:3263-3458` use one global `OperationRunning` state for package operations and offline-cache downloads; UniGetUI issue #5025 shows users expect downloads and installs to have clearer independent states.
- Verified upgrade-strategy gap: WinGet stable `v1.28.240` and prerelease `v1.29.280` differ on features Wingetter already probes, and WinGet issues #6330/#6289 show client self-update and native DSC resources are active platform changes; Wingetter should feature-detect rather than assume prerelease capabilities.

## Architecture Assessment
- `src\Wingetter.Ui.ps1` remains the dominant boundary; new source-policy, diagnostics, single-instance, window-state, operation-queue, and log-normalization work should move durable logic into focused helper modules instead of growing event handlers.
- `src\Wingetter.WinGet.ps1` is the right place to extend `Test-WinGet` into a structured readiness object because operation argument building, WinGet version gates, and bootstrap repair already live there.
- `src\Wingetter.Sources.ps1` already has the policy model needed for an editor; the missing work is validation UX and tests, not a new policy format.
- `src\Wingetter.Configuration.ps1:55-91` emits configuration schema `0.2.0` with `Microsoft.WinGet.DSC/WinGetPackage`; future DSC v3 PackageList/Source/Pin support should be a compatibility layer, not a rewrite.
- `tools\Invoke-Validation.ps1` is the local quality gate; every roadmap implementation should add targeted tests there instead of new one-off validation scripts.
- Accessibility, i18n, and mobile/multi-user paths are consciously sequenced: UI smoke/accessibility checks exist and should be extended with each UI item, string extraction is already deferred in ROADMAP.md, and mobile/multi-user/fleet management do not match a local WPF reviewed-run tool.

## Rejected Ideas
- Full unattended fleet agent: rejected because WAU, Patch My PC, and Ninite Pro already target unattended or managed deployment; Wingetter's verified strength is reviewed local setup and recovery.
- Auto-install scheduled updates: rejected because `src\Wingetter.UpdateWatcher.ps1` is intentionally check-only; deferrals and maintenance windows should improve review timing, not bypass it.
- Immediate write-capable Scoop/Chocolatey adapters: rejected until the read-only adapter proves search, installed-state mapping, duplicate handling, and trust UI.
- Native DSC v3 as the default export now: rejected because WinGet `v1.29.280` is prerelease; add feature detection and fixtures first.
- Mobile/web companion: rejected because WinGet, WPF, offline replay, source policy, and App Installer repair are Windows desktop workflows.
- Full localization before UI boundary/test cleanup: rejected because ROADMAP.md already correctly defers string extraction until workflow tests and smaller UI boundaries exist.

## Sources
Official docs, releases, and standards:
- https://learn.microsoft.com/en-us/windows/package-manager/winget/
- https://learn.microsoft.com/en-us/windows/package-manager/winget/install
- https://learn.microsoft.com/en-us/windows/package-manager/winget/source
- https://learn.microsoft.com/en-us/windows/package-manager/configuration/
- https://github.com/microsoft/winget-cli/releases/tag/v1.28.240
- https://github.com/microsoft/winget-cli/releases/tag/v1.29.280
- https://github.com/microsoft/winget-cli/issues/6289
- https://github.com/microsoft/winget-cli/issues/6330
- https://slsa.dev/spec/v1.2/

OSS competitors and adjacent projects:
- https://github.com/Devolutions/UniGetUI
- https://github.com/Devolutions/UniGetUI/issues/5025
- https://github.com/Devolutions/UniGetUI/issues/4984
- https://github.com/Devolutions/UniGetUI/issues/5004
- https://github.com/Devolutions/UniGetUI/issues/4799
- https://github.com/Romanitho/Winget-AutoUpdate
- https://github.com/Romanitho/Winget-AutoUpdate/releases/tag/v2.12.0
- https://github.com/Romanitho/Winget-AutoUpdate/issues/1162
- https://github.com/Romanitho/Winget-AutoUpdate/issues/1112
- https://github.com/Romanitho/Winget-AutoUpdate/issues/1153
- https://github.com/Romanitho/Winget-AutoUpdate/issues/1121
- https://github.com/Romanitho/Winget-AutoUpdate/issues/1159
- https://github.com/chocolatey/ChocolateyGUI
- https://github.com/chocolatey/ChocolateyGUI/issues/1099
- https://github.com/chocolatey/ChocolateyGUI/issues/1092
- https://github.com/ScoopInstaller/Scoop
- https://github.com/ScoopInstaller/Awesome-Scoop

Commercial and community signal:
- https://ninite.com/pro
- https://patchmypc.com/product/home-updater/
- https://www.reddit.com/r/sysadmin/comments/1t22xqy/winget_is_this_awesome_as_it_seems/
- https://stackoverflow.com/questions/tagged/winget

## Open Questions
None block prioritization. Code-signing certificate availability only changes whether future release hardening lands as Authenticode signing or as explicit unsigned-build provenance.
