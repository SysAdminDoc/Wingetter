# Source Register

Research date: 2026-05-17.

This register maps claims in the research artifacts and roadmap to local evidence, command output, or external URLs.

## Local Evidence

| ID | Source | Evidence Used |
|---|---|---|
| L01 | `Wingetter.ps1:1-15`, `Wingetter.ps1:95-97`, `Wingetter.ps1:1454-1458`, `Wingetter.ps1:1717` | Script description, PowerShell 5.1 requirement, and runtime UI version `v6.1.0`. |
| L02 | `Wingetter.ps1:257-1142` | Static `[ordered]` software database. Parsed as 765 unique `WingetId` values across 39 categories. |
| L03 | `Wingetter.ps1:1148-1188` | WinGet detection and bootstrap logic, including VCLibs, Microsoft.UI.Xaml, GitHub latest release, and Appx install paths. |
| L04 | `Wingetter.ps1:1195-1295` | Group storage path, saved group JSON, PS1 export, JSON export. |
| L05 | `Wingetter.ps1:1297-1349` | Built-in group list and package IDs. |
| L06 | `Wingetter.ps1:2172-2201` | Search/filter behavior checks name and Winget ID and update-mode installed state. |
| L07 | `Wingetter.ps1:3082-3165` | Install/update handler, process launch, stdout/stderr handling, result classification, toast notification. |
| L08 | `Wingetter.ps1:3345-3514` | Background installed-app detection and parallel icon loader. |
| L09 | `README.md:13-59`, `README.md:78-104`, `README.md:140-146` | Product claims, app/category counts, features, category table, contribution instructions. |
| L10 | old `ROADMAP.md:1-75` before replacement | Prior loose roadmap and competitor notes. |
| L11 | `CHANGELOG.md:1-16` | Malformed changelog date and mixed historic version entries. |
| L12 | `git log -10 --oneline --decorate`, `git show --stat -5` | Recent history, especially `f9b7c0d`, `a7cca43`, and version/doc cleanup history. |
| L13 | `Invoke-ScriptAnalyzer -Path Wingetter.ps1` | PSScriptAnalyzer warnings: automatic variable shadowing, empty catches, encoding, ShouldProcess, unused parameters. |
| L14 | `gh repo view SysAdminDoc/Wingetter --json ...` | GitHub repo metadata: public repo, description says 734 apps, 2 stars, no issues. |
| L15 | `git ls-files`, `git status --ignored --untracked-files=all`, `git check-ignore -v` | Tracked files and ignored `AGENTS.md` / `CLAUDE.md`. |
| L16 | `Select-String` for `CornerRadius=999` | Pill/fully rounded backdrop violations in XAML and generated controls. |
| L17 | `winget --version`, `winget --info` | Local WinGet version 1.28.240, default directories, admin settings state. |
| L18 | catalog parser command over `Wingetter.ps1` | Counts: 765 package IDs, 765 unique package IDs, 39 categories, 3,283 script lines, 13 functions. |
| L19 | `winget install --help`, `winget upgrade --help`, `winget export --help`, `winget import --help`, `winget pin --help`, `winget configure --help` | Local current CLI options and absence of a local `--parallel` install flag in WinGet 1.28.240 help. |
| L20 | `winget source list`, `winget pin list` | Local default sources: `msstore`, `winget`, `winget-font`; no configured pins. |
| L21 | `winget download --help` | Local download/offline installer mode options. |

## External Evidence

| ID | Source | Evidence Used |
|---|---|---|
| E01 | Microsoft Learn, `winget install`: https://learn.microsoft.com/en-us/windows/package-manager/winget/install | Exact ID matching, install options, silent/agreement flags, local manifest warning, multiple install/import/configure guidance. |
| E02 | Microsoft Learn, `winget upgrade`: https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade | Upgrade options, `--all`, unknown versions, pinned package behavior, uninstall previous behavior. |
| E03 | Microsoft Learn, `winget export`: https://learn.microsoft.com/en-us/windows/package-manager/winget/export | Official export JSON, source/package hierarchy, version option, export warnings. |
| E04 | Microsoft Learn, `winget import`: https://learn.microsoft.com/en-us/windows/package-manager/winget/import | Official import JSON, serial install behavior, ignore flags, schema hierarchy. |
| E05 | Microsoft Learn, `winget pin`: https://learn.microsoft.com/en-us/windows/package-manager/winget/pinning | Pinning, blocking, gating, include-pinned behavior, pin subcommands. |
| E06 | Microsoft Learn, WinGet Configuration: https://learn.microsoft.com/en-us/windows/package-manager/configuration/ | Declarative YAML setup, DSC integration, trust warning, validation/test/apply flow. |
| E07 | Microsoft Learn, `winget source`: https://learn.microsoft.com/en-us/windows/package-manager/winget/source | Default sources, source add/list/update/remove/reset/export, explicit sources, REST source type, trusted sources warning. |
| E08 | Microsoft Learn, manifest creation: https://learn.microsoft.com/en-us/windows/package-manager/package/manifest | Manifest YAML, schema, installer URL, installer SHA256, metadata fields, manifest version. |
| E09 | Microsoft Learn, manifest repository submission: https://learn.microsoft.com/en-us/windows/package-manager/package/repository | `winget-pkgs` validation, malware checks, sparse checkout guidance, manifest folder structure. |
| E10 | Microsoft Learn, WinGet overview: https://learn.microsoft.com/en-us/windows/package-manager/winget/ | WinGet purpose, supported platforms, Microsoft.WinGet.Client bootstrap path, supported installer formats, open source details. |
| E11 | GitHub API, `microsoft/winget-pkgs`: https://github.com/microsoft/winget-pkgs | Active manifest repo metadata, stars/forks/open issues, current pushed timestamp. |
| E12 | UniGetUI README and GitHub metadata: https://github.com/Devolutions/UniGetUI | Multi-manager GUI positioning, supported managers, metadata/detail views, bulk install/update/uninstall, auto-update, tray, export/import, Devolutions stewardship. |
| E13 | Ninite home page: https://ninite.com/ | Batch install/update positioning, no-toolbar/no-click-next simplicity, large daily install/update claim. |
| E14 | Ninite silent mode help: https://ninite.com/help/features/silent.html | Silent mode, reports, skip-up-to-date behavior, repair flag. |
| E15 | Winget-AutoUpdate README: https://github.com/Romanitho/Winget-AutoUpdate | Scheduled updates, system/user context, allowlist/blocklist, notification levels, logs, Intune/SCCM deployment, GPO settings. |
| E16 | Scoop README and GitHub metadata: https://github.com/ScoopInstaller/Scoop | Buckets, portable install model, `aria2`, default and extra buckets. |
| E17 | Chocolatey docs and GitHub metadata: https://github.com/chocolatey/choco and https://docs.chocolatey.org/en-us/choco/commands/export/ | Windows package manager positioning, community repository, export command, business/internal repository patterns. |
| E18 | PowerShell Gallery / PSResourceGet docs: https://learn.microsoft.com/en-us/powershell/gallery/overview and https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/ | PowerShell package ecosystem, PSResourceGet replacement, module/script discovery/install/update cmdlets. |
| E19 | winstall app: https://winstall.app/ | Web-based winget repository browser, field-prefixed search, 12,850+ packages claim at access time. |
| E20 | Patch My PC Home Updater and PDQ package library: https://patchmypc.com/home-updater and https://www.pdq.com/package-library/ | Commercial/adjacent patching, reporting, package library, deployment positioning. |
| E21 | GitHub CLI search results on 2026-05-17 | Adjacent winget GUI/script projects including Romanitho/Winget-Install-GUI and DrewNaylor/guinget. |
| E22 | PowerShell Gallery, Microsoft.WinGet.Client: https://www.powershellgallery.com/packages/Microsoft.WinGet.Client/ | Official WinGet PowerShell module availability and package metadata. |
| E23 | Microsoft REST source reference implementation: https://github.com/microsoft/winget-cli-restsource | Private/REST source opportunity for corporate mode. |

## Notes On Source Quality

- Microsoft Learn and official GitHub repositories were treated as primary sources for WinGet capabilities.
- Competitor claims were taken from project READMEs, official pages, or GitHub metadata collected on 2026-05-17.
- GitHub API/CLI metadata is time-sensitive and should be refreshed before release decisions.
- Community web pages and commercial marketing pages were used only for positioning and feature comparison, not for implementation details.
