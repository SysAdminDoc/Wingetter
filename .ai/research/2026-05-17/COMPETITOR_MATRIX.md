# Competitor Matrix

Research date: 2026-05-17.

## Summary

Wingetter is strongest as a local-first, broad, curated WinGet batch setup GUI. It should not try to immediately outbuild UniGetUI's full multi-manager surface. The practical path is to beat lightweight batch installers on trust/detail/reporting while keeping Ninite-style speed.

## Direct And Adjacent Projects

| Project | Type | Activity Snapshot | Notable Features | Lessons For Wingetter | Sources |
|---|---|---:|---|---|---|
| UniGetUI | OSS Windows package-manager GUI | 23,855 stars, pushed 2026-05-15, latest `v2026.1.10` on 2026-05-14 | WinGet, Scoop, Chocolatey, pip, npm, .NET Tool, PowerShell Gallery; install/update/uninstall; metadata; tray; auto-update; export/import; package links | Strongest benchmark. Do not chase multi-source UI inside the monolith; first build adapter boundaries and trust metadata. | E12 |
| Ninite | Commercial/web batch installer | Active website, claims large daily install/update volume | Ultra-simple picker, silent installs, skips up-to-date apps, reports in Pro silent mode | Keep Wingetter's setup flow fast. Reporting and "already current" handling matter more than feature density during install. | E13, E14 |
| winstall | Web winget repository browser/generator | Active website, 12,850+ packages claim at access time | Winget package browsing, field-prefixed search, shareable web model | Add metadata-rich search and eventual shareable profile import/export. | E19 |
| Winget-AutoUpdate | OSS scheduled updater | 1,852 stars, latest `v2.12.0` on 2026-05-11 | Scheduled updates, system/user context, allowlist/blocklist, notifications, metered connection handling, logs, GPO/Intune/SCCM paths | Use as model for update watcher, allow/block lists, log rotation, deployment-friendly settings. | E15 |
| WiGui / Winget-Install-GUI | OSS winget install GUI | 214 stars, marked not maintained; functionality folded into WAU | Search/add/install multiple apps, export/import app list, configure WAU | Confirms demand for a simple winget GUI, but also warns against unmaintained one-off GUI surfaces. | E21, E15 |
| guinget | OSS winget GUI | 140 stars, canonical move to Codeberg noted | Synaptic-like GUI; cache/package-list work; package detail/cache concerns | Manifest/cache indexing is a recurring challenge; Wingetter should own a validated local catalog layer. | E21 |
| Scoop | OSS Windows package manager | 24,132 stars; active | Buckets, portable app model, `aria2`, extras/main buckets | Good future source adapter; bucket model can inspire Wingetter catalogs and categories. | E16 |
| Chocolatey | OSS/commercial Windows package manager | 11,378 stars; latest `2.7.2` on 2026-05-12 | Community repo, package scripts, export, internal repository, business management features | Useful enterprise patterns, but source differences require an adapter and trust UI. | E17 |
| PowerShell Gallery / PSResourceGet | PowerShell package ecosystem | Active Microsoft docs, PSResourceGet latest docs | Modules/scripts discovery/install/update, repository cmdlets | Useful future tab/source for sysadmins; keep separate from app installer flow initially. | E18 |
| ChrisTitusTech winutil | OSS PowerShell Windows utility | 54,618 stars, active | Installs, debloat, tweaks, fixes, compiled single script pattern | Demonstrates huge appetite for PowerShell GUI/system setup tools; Wingetter should stay app-install focused and avoid broad tweak bloat. | E21 |
| Patch My PC Home Updater | Commercial/free home updater | Active commercial product site | Patching, supported apps, reporting/analytics, Intune/SCCM/Mac positioning | Reporting and app catalog trust matter for professional users. | E20 |
| PDQ package library | Commercial endpoint package library | Active commercial product site | Package library, deployment, asset/software inventory, vulnerability management | Enterprise products win with inventory, reporting, and remediation workflow; Wingetter can borrow lightweight reports. | E20 |

## Feature Pattern Frequency

| Pattern | Seen In | Priority Impact |
|---|---|---|
| Batch install/update | Wingetter, Ninite, UniGetUI, WiGui, Chocolatey, Scoop | Already core; improve reliability and reporting. |
| Official export/import/profile portability | WinGet, UniGetUI, Ninite Pro, Chocolatey | P0 for Wingetter because custom JSON is isolated. |
| Multi-source package managers | UniGetUI, Scoop, Chocolatey, PSResourceGet | P2 after source adapter refactor. |
| Update watcher/tray/scheduler | UniGetUI, Winget-AutoUpdate, commercial patchers | P2 after pins and structured results. |
| Source trust and internal repositories | WinGet source, Chocolatey business docs, commercial patchers | P0/P1 because current UI hides source trust. |
| Package metadata/details | UniGetUI, WinGet manifests, winstall, guinget | P0/P1 for better decisions before install. |
| Offline/cache/download | WinGet download, Chocolatey internalizer/cache, Scoop cache | P2 for rebuild/USB workflows. |
| Corporate deployment hooks | WAU, Chocolatey, Patch My PC, PDQ | P2, valuable but not first for a one-script app. |

## Positioning Recommendation

Do not position Wingetter as "UniGetUI but PowerShell." UniGetUI already owns broad multi-manager GUI package management. Position Wingetter as:

- Faster than UniGetUI for curated new-PC setup profiles.
- More transparent than Ninite for WinGet source/package metadata.
- Easier than raw `winget import` for editing and validating setup profiles.
- Lighter than enterprise patching suites while still producing useful audit reports.
