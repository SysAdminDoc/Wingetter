# State Of Repo

Research date: 2026-05-17.

## Snapshot

- CWD: `C:\Users\--\repos\Wingetter`.
- Branch: `main`, tracking `origin/main`.
- Remote: `https://github.com/SysAdminDoc/Wingetter.git`.
- GitHub repo metadata says the project is public and describes 734 apps; local README/script now describe 765 apps.
- Latest commit at start of research: `f9b7c0d Sync ROADMAP, branding cleanup, README polish`.
- `rtk` was requested by global instructions but was not available in this PowerShell session; plain `git`, `gh`, `winget`, and PowerShell commands were used.

## File Layout

Tracked files before this research run:

- `.gitignore`
- `CHANGELOG.md`
- `LICENSE`
- `README.md`
- `ROADMAP.md`
- `Wingetter.exe`
- `Wingetter.ico`
- `Wingetter.ps1`
- `icon.ico`
- `icon.png`
- `screenshot.png`

Ignored/untracked local instruction files:

- `AGENTS.md` ignored by global gitignore.
- `CLAUDE.md` ignored by repo `.gitignore`.

## Current Application

- `Wingetter.ps1` is 3,283 lines and parses with zero PowerShell parser errors.
- The script declares `#Requires -Version 5.1`.
- The GUI title and splash/header show `v6.1.0`.
- The local static catalog contains 765 unique package IDs across 39 categories.
- The catalog is embedded directly in the script.
- There are 13 PowerShell functions.
- Built-in groups in code total 10, not the README's older group list.

## Runtime Behavior Observed From Code

- WinGet detection calls `Get-Command winget` and `winget --version`.
- Missing WinGet bootstrap downloads Microsoft VCLibs, Microsoft.UI.Xaml 2.8.6, and the latest `winget-cli` release asset, then attempts Appx installation/provisioning.
- User groups are stored in `%APPDATA%\Wingetter\groups.json`.
- Export supports a custom JSON format and generated PS1 scripts.
- Import accepts the custom JSON shape and simple JSON arrays, not the official WinGet import schema yet.
- Search checks app name and `WingetId`.
- Install/update commands run serially with `winget install --id <id> --exact` or `winget upgrade --id <id> --exact`.
- The installed-app scan uses `winget list --source winget` and regex extraction.
- Icon loading uses Google favicon URLs and a `%TEMP%\WingetterIcons` cache.

## Local Tool Output

- Local WinGet version: `v1.28.240`.
- Local default sources: `msstore`, `winget`, and explicit `winget-font`.
- Local pins: none configured.
- Local WinGet admin settings showed local manifests, certificate pinning bypass, installer hash override, local archive malware scan override, and proxy command-line options disabled.
- Local `winget install --help` did not show a `--parallel` option; the old roadmap's "winget 1.11+ --parallel" item is unverified/likely stale.

## Static Analysis

`Invoke-ScriptAnalyzer -Path Wingetter.ps1` produced warning-level findings:

- Assignment to automatic variable `$sender` in event handlers.
- Many empty catch blocks.
- `PSUseBOMForUnicodeEncodedFile` due non-ASCII content without BOM.
- `PSUseShouldProcessForStateChangingFunctions` for several functions.
- Unused handler parameters.
- Singular noun rule warning for `Get-SavedGroups`.

Targeted grep also found fully rounded/pill backdrops:

- XAML progress/header badge `CornerRadius="999"`.
- Category count, installed status, and log status badges created with `CornerRadius = 999`.

## Documentation Drift

- README says 765 apps and 39 categories, which matches parsed totals.
- README category row counts are stale for several categories after the latest catalog expansion.
- README built-in groups list does not match code. Code includes `Streaming Setup`, `Office & Productivity`, and `3D Printing Workshop`; README still lists older groups such as Remote Worker, Media & Entertainment, and Student Essentials.
- `CLAUDE.md` says `Wingetter v0.1.0`; it is ignored/untracked and stale.
- `CHANGELOG.md` has a malformed date line and mixes old commit summaries under `v0.1.0`.

## Immediate Engineering Risks

- The bootstrap path installs downloaded package assets without an explicit in-app verification record.
- Result parsing is brittle because it depends on English stdout phrases and does not expose stderr.
- Empty catch blocks hide failures in icon loading, installed scan cleanup, toast creation, and other paths.
- `Set-Content -Encoding UTF8` can produce BOMs in Windows PowerShell 5.1 exports; this is a known stack-level issue for generated scripts.
- The monolithic file shape makes precise review and tests difficult.

## Repository Philosophy Inferred

- Keep the app simple to launch and local-first.
- Prefer broad curated Windows app coverage and reusable setup groups over enterprise endpoint management complexity.
- Use WinGet as the primary trusted install engine rather than downloading installers directly.
- Keep a polished GUI but preserve script portability.
