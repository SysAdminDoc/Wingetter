# Research - Wingetter

## Executive Summary
Verified: Wingetter is a local Windows PowerShell 5.1/WPF package cockpit for curated WinGet discovery, reviewed install/update runs, profile/gallery imports, source policy, update review, offline cache replay, diagnostics, and reproducible release evidence. Its strongest current shape is trustable workstation setup and rebuild review, not fleet automation or broad multi-manager write support. Highest-value direction: finish the existing trust/reliability roadmap, then add atomic state persistence, WinGet source-health diagnostics, self-update/provenance review, an editable update-policy UI, failed-run retry, and local catalog-change impact reporting. Priority order: make mutable app-state writes atomic; classify WinGet source-health failures; complete existing reviewed uninstall/source-policy/compliance/risk-warning items; add Wingetter self-update/provenance review; add update-policy editing; add failed-run retry; keep Scoop, DSC v3, localization, and broader adapter work behind fixture-tested boundaries.

## Product Map
- Core workflows: browse the curated 765-app catalog; select packages, groups, or gallery profiles; review WinGet install/update preflight plans; run operations with logs; export scripts, WinGet import/configuration files, migration reports, source policy, diagnostics bundles, and offline cache manifests.
- User personas: personal Windows rebuild user; small IT/helpdesk operator; privacy/corporate user with source allow/block needs; admin who wants local evidence without a server or endpoint agent.
- Platforms and distribution: Windows 10/11, Windows PowerShell 5.1+, WPF, MIT license, raw GitHub launcher, checked-in `Wingetter.exe`, optional `Microsoft.WinGet.Client`, optional PS2EXE build path, local validation through `tools\Invoke-Validation.ps1`.
- Key integrations and data flows: `winget.exe`; `%APPDATA%\Wingetter` settings, policies, groups, logs, caches, and diagnostics; `catalog\winget.json`; SHA256-verified `profiles\gallery\*.wingetter.json`; optional favicon retrieval unless private/offline icon mode is active; release hash data in `release\manifest.json`.

## Competitive Landscape
- Microsoft WinGet / WinGet.Client: does the package lifecycle, source management, repair commands, configuration export/import, and emerging DSC v3 resources well. Wingetter should learn from command feature gates and source diagnostics; avoid assuming prerelease WinGet behavior is available on stable clients.
- UniGetUI: does multi-manager GUI breadth, installed/update views, uninstall, bundles, logs, translations, and lifecycle parity well. Wingetter should learn from operation separation, view persistence, and warning surfacing; avoid copying write support for every package manager before adapter trust models are proven.
- Winget-AutoUpdate: does scheduled update checks, allow/block policy, deferrals, maintenance timing, system/user context handling, and failure reporting well. Wingetter should borrow policy-editing and source-health lessons; avoid auto-installing scheduled updates because the current product is review-first.
- winget-tui: does compact install/update/uninstall flows, source filtering, CSV export, background operations, pin awareness, and configurable columns well. Wingetter should borrow lifecycle parity and persisted review views; avoid keyboard-first assumptions in the WPF UI.
- Scoop / Awesome Scoop / Chocolatey GUI: show why source semantics matter: Scoop is portable/per-user/bucket-driven while Chocolatey is repository/admin/package-lifecycle driven. Wingetter should keep the existing read-only Scoop roadmap item first; avoid write-capable adapters until duplicate IDs, trust, and installed-state semantics are explicit.
- winstall / WinGet REST source: do package-list building, private/internal source patterns, and metadata ownership well. Wingetter should keep investing in policy/drift checks and exportable evidence; avoid becoming a source-hosting service.
- Ninite Pro / Patch My PC / PDQ: commercial tools emphasize batch reliability, detection, retry, compliance, scheduling, and downloadable evidence. Wingetter should borrow local compliance reports, retry queues, and diagnostics; avoid claiming endpoint-agent remediation, vulnerability SLAs, or fleet patch coverage.

## Security, Privacy, and Reliability
- Verified risk: mutable state writes are inconsistent. `src\Wingetter.Common.ps1:80-104` writes settings directly, while `src\Wingetter.WinGet.ps1:936-958` has an atomic helper used only in some modules; `src\Wingetter.UpdateWatcher.ps1:145-149` still writes update-check results with `Set-Content`. A crash or interrupted write can corrupt user settings, policy, update results, or reports.
- Verified risk: WinGet client readiness is now classified, but source-index/cache failures are not separately diagnosed. `src\Wingetter.WinGet.ps1:5-114` checks the client, while source failures such as Microsoft.WinGet.Source offline/deactivated states in `microsoft/winget-cli` issue #6015 can still look like package failures.
- Verified risk: `release\manifest.json` and `Wingetter.ps1:33-60` provide hash evidence for local launcher modules, but the WPF app has no self-update/provenance review against the current GitHub release/raw manifest; the checked-in release is also unsigned when no certificate is available.
- Verified risk: `src\Wingetter.Sources.ps1:144-162` exposes an uninstall capability, but the active roadmap item remains necessary because `New-WingetterRunPlan` only accepts `install`/`upgrade`; upstream WinGet uninstall issues #6116, #6215, and #6247 show dependency and portable PATH/symlink safety must be reviewed before UI exposure.
- Verified governance gap: `src\Wingetter.Sources.ps1:425-954` has source-policy storage/export/drift support, while `src\Wingetter.Ui.ps1:2739-2742` only toggles corporate mode; the existing editable allow/block UI item is still valid.
- Verified recovery gap: migration reports record run state, but `src\Wingetter.Ui.ps1:3515-3548` does not offer a "retry failed rows" path; commercial patch tools and Ninite Pro surface retry/current/skipped states as core operator controls.
- Missing guardrails: no central atomic/corrupt-state policy for every JSON write, no source-health status in startup/diagnostics, no in-app update/provenance review, no editable scheduled update-policy UI, no failed-run replay, and no local catalog curation diff before catalog/profile changes.
- Recovery and rollback needs: corrupt settings/policy/result files should be moved aside consistently; source repair/reset guidance should be non-mutating by default; failed package rows should be replayable from the last report; lockfile exports already on the roadmap should preserve resolved source/version/options before upstream drift.

## Architecture Assessment
- `src\Wingetter.Ui.ps1` remains the largest boundary. New workflow work should keep WPF handlers thin and put state, parsing, warnings, and plan logic in `Common`, `WinGet`, `Sources`, `Groups`, `UpdateWatcher`, and focused test fixtures.
- `src\Wingetter.Common.ps1` should own atomic file replacement and corrupt JSON recovery so settings, source policy, update policy, installed cache, update results, groups, reports, and exports follow one persistence contract.
- `src\Wingetter.WinGet.ps1` is the right boundary for source-health probes, uninstall plan construction, retryable result classification, warning parsing, and client feature gates because command building, result parsing, installed scans, and details parsing already live there.
- `src\Wingetter.Sources.ps1` already has a capability model; lifecycle UI should consume adapter capabilities rather than hard-code WinGet-only behavior as Scoop and future read-only adapters arrive.
- `src\Wingetter.Groups.ps1`, `src\Wingetter.ProfileGallery.ps1`, and `src\Wingetter.WinGet.ps1` contain the inputs needed for compliance, retry, and lockfile features: desired package IDs, imported profiles, installed records, update availability, pins, source policy, and run reports.
- `src\Wingetter.UpdateWatcher.ps1` already has a policy schema and validation tests, but the WPF UI should edit that schema directly rather than requiring manual JSON.
- Testing should continue through `tools\Invoke-Validation.ps1`; add focused fixture coverage to `tools\Test-WinGetRunner.ps1`, `tools\Test-SourcePolicy.ps1`, `tools\Test-UpdateWatcher.ps1`, `tools\Test-ProfileJson.ps1`, and UI smoke/accessibility tests.
- Category coverage: security, observability, testing, docs, distribution, offline resilience, migration, upgrade strategy, plugin ecosystem, accessibility, and i18n/l10n are represented by current or new roadmap items. Mobile and multi-user server features are intentionally rejected because Wingetter is a local Windows desktop reviewed-run tool.

## Rejected Ideas
- Full unattended fleet agent: rejected from WAU, Patch My PC, Ninite Pro, and PDQ evidence because Wingetter's verified value is local reviewed setup/recovery, not endpoint-agent remediation.
- Scheduled auto-install updates: rejected because `src\Wingetter.UpdateWatcher.ps1` is intentionally check-only; maintenance windows and deferrals should improve review timing, not bypass review.
- Write-capable Scoop/Chocolatey adapters now: rejected because Scoop/Chocolatey have different source, trust, and installed-state semantics; the existing read-only Scoop roadmap item is the correct first step.
- Native DSC v3 as the default export now: rejected because `microsoft/winget-cli` issue #6289 shows upstream resources are still active/planning work; keep feature detection and fixtures before changing defaults.
- Direct VirusTotal or BYOK reputation integration now: rejected because UniGetUI issue #4822 shows it introduces API-key, rate-limit, proxy, and privacy choices; Wingetter should first ship local structured warning taxonomy.
- Repair/reinstall automation now: rejected because WinGet repair/self-update behavior is still evolving; Wingetter should surface non-mutating guidance and provenance checks before mutating itself or installed apps.
- Mobile/web companion: rejected because the high-value workflows depend on local WinGet, WPF state, App Installer repair, offline cache paths, and Windows desktop user context.
- Full localization before boundary/test cleanup: rejected because `ROADMAP.md` already defers string extraction until workflow tests and smaller UI boundaries exist.
- PowerShell 7 security-advisory chase as primary hardening work: rejected because Wingetter's verified runtime is Windows PowerShell 5.1 and the reviewed PowerShell advisory does not create a current repo dependency upgrade path.

## Sources
Official docs, releases, and standards:
- https://learn.microsoft.com/en-us/windows/package-manager/winget/
- https://learn.microsoft.com/en-us/windows/package-manager/winget/source
- https://learn.microsoft.com/en-us/windows/package-manager/winget/troubleshooting
- https://learn.microsoft.com/en-us/windows/package-manager/configuration/
- https://github.com/microsoft/winget-cli/releases
- https://www.powershellgallery.com/packages/Microsoft.WinGet.Client/1.28.240
- https://github.com/PowerShell/Announcements/issues/82
- https://slsa.dev/blog/2024/08/dep-confusion-and-typosquatting
- https://csrc.nist.gov/pubs/sp/800/218/final

WinGet upstream issues and PRs:
- https://github.com/microsoft/winget-cli/issues/6015
- https://github.com/microsoft/winget-cli/issues/6329
- https://github.com/microsoft/winget-cli/issues/6289
- https://github.com/microsoft/winget-cli/pull/6293
- https://github.com/microsoft/winget-cli/issues/6116
- https://github.com/microsoft/winget-cli/issues/6215
- https://github.com/microsoft/winget-cli/issues/6247
- https://github.com/microsoft/winget-cli/issues/6266

OSS competitors and adjacent projects:
- https://github.com/Devolutions/UniGetUI
- https://github.com/Romanitho/Winget-AutoUpdate
- https://github.com/shanselman/winget-tui
- https://docs.chocolatey.org/en-us/chocolatey-gui/
- https://github.com/ScoopInstaller/Scoop
- https://github.com/ScoopInstaller/Awesome-Scoop
- https://winstall.app/
- https://github.com/microsoft/winget-cli-restsource

Commercial and community:
- https://ninite.com/pro
- https://patchmypc.com/product/home-updater/
- https://docs.pdq.com/current-version/Deploy/retry-queue-or-wol.htm
- https://www.windowscentral.com/software-apps/windows-11/hate-winget-auto-update-is-a-tool-you-need

## Open Questions
- Code-signing certificate availability changes future release packaging and self-update trust wording, but does not block implementation priority.
