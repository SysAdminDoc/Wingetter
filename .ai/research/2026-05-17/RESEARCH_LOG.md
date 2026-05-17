# Research Log

Research date: 2026-05-17.

## Local Reconnaissance Passes

1. Loaded global and repo instructions.
2. Checked recent Git history and branch status.
3. Inventoried repo files, ignored files, and tracked files.
4. Read repo `AGENTS.md`, `CLAUDE.md`, `README.md`, old `ROADMAP.md`, `CHANGELOG.md`, and `.gitignore`.
5. Parsed `Wingetter.ps1` with the PowerShell AST: zero parse errors.
6. Counted catalog package IDs and categories from the script body.
7. Inspected key code paths: WinGet bootstrap, group persistence, export/import, GUI state, install/update execution, installed scan, and icon loading.
8. Ran `Invoke-ScriptAnalyzer`.
9. Queried local WinGet version, source list, pin list, and command help for install/upgrade/export/import/pin/configure/download.
10. Compared README, CHANGELOG, script version strings, GitHub metadata, and old roadmap claims for drift.

## External Research Passes

### Pass 1 - Official WinGet Capabilities

Queries and sources:

- Microsoft Learn WinGet overview, install, upgrade, export, import, pinning, source, configuration, manifest, and repository docs.
- Local `winget --help` subcommands for current installed CLI behavior.
- GitHub metadata for `microsoft/winget-cli`, `microsoft/winget-pkgs`, `microsoft/winget-cli-restsource`, and `microsoft/winget-dsc`.

Findings:

- Official import/export schemas already cover machine rebuild profiles.
- WinGet source management supports default, explicit, and REST sources.
- Pinning has three distinct behaviors: pinning, blocking, and gating.
- WinGet Configuration can express repeatable machine setup through YAML plus DSC.
- Manifest data includes installer URL and SHA256, which supports trust/detail UI.
- Local WinGet help did not support the old roadmap's `--parallel` claim.

### Pass 2 - Direct Competitors

Sources:

- UniGetUI README, release metadata, and GitHub metadata.
- Ninite home and silent-mode docs.
- winstall web app.
- Romanitho Winget-AutoUpdate and Winget-Install-GUI READMEs.
- DrewNaylor guinget README.

Findings:

- UniGetUI is the strongest direct open-source benchmark: multi-manager support, package details, bulk operations, tray/update workflows, export/import, and enterprise stewardship.
- Ninite's moat is low-friction batch selection, silent operation, and clear reporting.
- winstall demonstrates a web-first package browser/search/linking model.
- Winget-AutoUpdate is strong on scheduled system/user-context updates, allow/block lists, notifications, logs, and deployment-management integration.
- Older or smaller winget GUIs show the demand for a simple GUI, but many are stale or narrower than Wingetter.

### Pass 3 - Adjacent Ecosystem

Sources:

- Scoop README and bucket metadata.
- Chocolatey repo/docs and export docs.
- PowerShell Gallery / PSResourceGet docs.
- Patch My PC and PDQ package library pages.

Findings:

- Scoop adds portable-app and bucket concepts that are useful for a future source adapter.
- Chocolatey adds mature internal repository and business deployment patterns.
- PSResourceGet expands source coverage for modules/scripts but should not be mixed into the current monolith before adapter work.
- Commercial patching tools focus on reporting, compliance, app catalogs, endpoint management, and update automation.

### Pass 4 - Security And Reliability

Sources:

- WinGet install/source/configuration/manifest/repository docs.
- Local WinGet admin settings.
- PSScriptAnalyzer.
- PowerShell stack memory on `Set-Content -Encoding UTF8`.

Findings:

- The current app should surface WinGet's own trust model instead of reinventing package verification.
- Bootstrap needs better logging and a documented Microsoft-supported path.
- Empty catch blocks reduce supportability.
- Exported PS1 scripts should avoid Windows PowerShell 5.1 BOM traps when a block comment starts at byte zero.
- Source trust, explicit source mode, and REST/private sources are relevant for a future corporate mode.

## Failed Or Thin Searches

- RuckZuck website refused connection during this run, so it is not used as a primary source in the new roadmap.
- Some GitHub API calls initially hit unauthenticated rate limits through `Invoke-RestMethod`; authenticated `gh api` was used afterward.
- `microsoft/wingetcreate` and some old repository names returned 404 or redirects; no roadmap claim depends on them.
- No direct AI/ML product need was found. Dataset/model opportunities are thin and captured separately.

## Saturation Test

Source saturation was considered adequate for planning because additional searches stopped producing new high-priority themes. Repeated patterns across official docs, UniGetUI, Ninite, Winget-AutoUpdate, Scoop, Chocolatey, and commercial patching tools converged on the same themes:

- Catalog freshness and validation.
- Export/import/profile portability.
- Source and manifest trust transparency.
- Reliable execution/logging/reporting.
- Update lifecycle, pins, allowlists/blocklists.
- Source abstraction only after foundation work.
- Optional offline/corporate/configuration workflows.

## Limitations

- No GUI launch/screenshot was performed because this was a research and planning run, not a UI implementation change.
- GitHub metadata is point-in-time and should be refreshed before marketing/release claims.
- Competitor pages can change; URLs are recorded in `SOURCE_REGISTER.md`.
- Local WinGet behavior reflects v1.28.240 on this machine on 2026-05-17.
