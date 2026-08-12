# Wingetter

A powerful PowerShell GUI application for discovering, selecting, and bulk installing Windows software using [Windows Package Manager (winget)](https://learn.microsoft.com/en-us/windows/package-manager/winget/). Think Ninite, but with 765 apps and full winget integration.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell&logoColor=white)
![Version](https://img.shields.io/badge/version-v6.2.0-blue)
![Apps](https://img.shields.io/badge/Apps-765-green)
![Categories](https://img.shields.io/badge/Categories-39-orange)
![License](https://img.shields.io/badge/License-MIT-yellow)

---


![Screenshot](screenshot.png)

## Quick Launch

```powershell
irm "https://raw.githubusercontent.com/SysAdminDoc/Wingetter/main/Wingetter.ps1" | iex
```

Paste the above into any PowerShell window to download and run Wingetter instantly. No installation required.

---

## Features

**765 applications** across **39 categories** with a polished WPF interface:

- **Dark / Light mode** -- defaults to dark, toggle with one click
- **Premium discovery workspace** -- responsive search and command hierarchy, three-column catalog density, and a persistent reviewed-selection panel with per-app removal
- **Accessible catalog navigation** -- keyboard-operable app rows, category sections, sidebar jumps, visible focus states, and screen-reader package labels
- **Metadata-rich search** -- ranked local search across names, package IDs, categories, built-in groups, publisher-like ID tokens, installed state, source, scope, update state, and pin state
- **Favicon icons** -- parallel-fetched from app domains with colored letter fallbacks and local caching
- **Private icon mode** -- disable remote favicon fetches and use deterministic letter icons for restricted or privacy-sensitive networks
- **Bulk install** -- select any combination and install them all in sequence via a responsive background worker
- **Preflight run plan** -- review what will run, skip current/pinned/blocked/unresolved packages, and save the JSON plan with the run logs
- **Update mode** -- toggle between Install and Update mode to upgrade already-installed apps
- **Installed app detection** -- background scan prefers `Microsoft.WinGet.Client`, falls back to `winget list`, and caches detected versions under `%APPDATA%\Wingetter`
- **Package trust details** -- click an app to inspect source, publisher, installed/latest version, installer type, URL, SHA256, and metadata warnings
- **WinGet pin controls** -- inspect pin state, add standard/blocking/installed-version pins, remove pins, and opt into pinned updates
- **Corporate source policy** -- optional allowed-source mode can block packages outside trusted sources and export `winget source add` commands, including explicit `Microsoft.Rest` private sources
- **Silent install & auto-accept agreements** -- toggleable checkboxes for hands-free deployment
- **Copy command** -- grab the raw `winget install` commands to clipboard
- **Save / Load groups** -- persist custom selections as named groups for reuse
- **Per-package install options** -- Wingetter group profiles can preserve vetted WinGet `version`, `scope`, `architecture`, `installer-type`, `locale`, `location`, and `custom` options
- **Profile Gallery** -- browse checked-in public profiles, verify SHA256 hashes, review every package ID/source, and import only as a selection
- **Export as PS1, Wingetter JSON, official WinGet JSON, or WinGet Configuration** -- generate standalone installer scripts, reusable Wingetter group profiles, files usable with `winget import`, or declarative `.winget` configuration files
- **Import JSON profiles** -- load official WinGet export/import JSON, Wingetter group JSON, or simple package ID arrays
- **10 built-in quick-select groups** -- one-click presets for common setups
- **Category sidebar** -- quick-jump navigation panel for all 39 categories
- **Collapsible categories** -- click any category header to collapse/expand
- **Shift-click range selection** -- hold Shift to select a range of apps at once
- **Enhanced tooltips** -- hover to see app name and WingetId
- **Install log panel** -- color-coded per-app results (success/skipped/failed) with summary
- **Structured run logs** -- per-package stdout, stderr, and JSON result records under `%APPDATA%\Wingetter\logs`; WinGet 1.29+ runs use cleaner `--no-progress` output where supported
- **Redacted diagnostics bundle** -- export catalog/version info, recent logs, update-check summaries, migration reports, WinGet info, source and pin lists, and redacted source policy data as one support ZIP
- **Migration reports** -- completed install/update runs create exportable Markdown or JSON reports with the preflight plan, summary counts, commands, result paths, versions, and sources
- **Scheduled update checks** -- optional Windows scheduled task checks for available updates, respects pins/source policy/deferrals/maintenance windows, can skip metered networks, rotates logs, and never auto-installs
- **Offline download cache** -- download selected installers in the background with `winget download`, write an offline manifest, and generate a replay script for later installer launch
- **Toast notifications** -- Windows notification when batch install completes
- **Splash screen** -- loading progress indicator while icons are fetched
- **Select All / Deselect All** per category or globally
- **WinGet auto-detection** -- checks for winget on launch, distinguishes missing/disabled/constrained/broken states, and reports stable/prerelease/old client readiness with feature gates
- **Audited WinGet repair** -- uses App Installer registration and `Microsoft.WinGet.Client` repair with JSONL bootstrap logs instead of raw package downloads, and skips repair when policy or constrained language mode blocks success

## Built-in Groups

Pre-configured package groups for common use cases:

| Group | Description |
|---|---|
| Essential PC Setup | Chrome, Firefox, 7-Zip, VLC, Notepad++, Everything, and more |
| Web Developer | VS Code, Git, Node.js, Docker, Postman, Windows Terminal |
| Python Developer | VS Code, Git, Python 3.13, Miniconda, PyCharm, DBeaver |
| Creative Suite | GIMP, Krita, Inkscape, Blender, OBS, DaVinci Resolve |
| Gaming PC | Steam, Discord, Epic, GOG, Playnite, Moonlight, Sunshine |
| Privacy & Security | Firefox, Mullvad Browser, Bitwarden, ProtonVPN, VeraCrypt, simplewall |
| System Admin | PowerShell 7, Windows Terminal, WinSCP, PuTTY, Sysinternals |
| Streaming Setup | OBS, Streamlabs, VoiceMeeter, Discord, ShareX, FFmpeg |
| Office & Productivity | LibreOffice, Thunderbird, Bitwarden, Todoist, Obsidian, PDF24 |
| 3D Printing Workshop | Cura, PrusaSlicer, Bambu Studio, OrcaSlicer, FreeCAD, OpenSCAD |

## Categories

| Category | Apps | | Category | Apps |
|---|---:|---|---|---:|
| System Utilities | 54 | | Runtimes & SDKs | 52 |
| Messaging & Email | 39 | | Developer Tools | 37 |
| CLI Tools | 37 | | Code Editors & IDEs | 36 |
| Networking & Remote | 33 | | Hardware & Diagnostics | 32 |
| File Management | 31 | | Gaming | 28 |
| Desktop Customization | 23 | | Video Tools | 23 |
| Imaging & Design | 22 | | Note-Taking | 20 |
| Web Browsers | 20 | | Music & Audio | 18 |
| Media Players | 17 | | Cloud & DevOps | 16 |
| Security | 16 | | Science & Education | 15 |
| Productivity | 14 | | VPN & Privacy | 14 |
| PDF & E-Books | 14 | | Passwords & Encryption | 13 |
| Documents & Office | 13 | | Other | 13 |
| Emulators | 12 | | Audio Production | 11 |
| Cloud Storage | 11 | | AI & LLM Tools | 11 |
| 3D Printing & CAD | 10 | | Screenshot & Recording | 10 |
| Terminals & Shells | 10 | | Backup & Sync | 9 |
| VC++ Redistributables | 8 | | Database Tools | 8 |
| Virtualization | 7 | | Compression | 5 |
| Package Managers | 3 | | | |

## Requirements

- **Windows 10 / 11**
- **PowerShell 5.1+** (ships with Windows 10+)
- **Windows Package Manager (winget)** -- Wingetter will detect and offer to install it if missing
- Internet connection for package installation and icon fetching

## Usage

### Quick Start

```powershell
# Run directly
.\Wingetter.ps1

# Or from anywhere
powershell -ExecutionPolicy Bypass -File "C:\Path\To\Wingetter.ps1"
```

### Workflow

1. Launch the script -- the splash screen loads while icons are fetched
2. Browse categories using the sidebar or use the search bar to find apps
3. Check the boxes for everything you want to install (Shift-click for range selection)
4. Optionally toggle **Silent Install** and **Auto-accept Agreements**
5. Click **Install Selected** to review the preflight plan and remove anything that should not run
6. Start the reviewed plan and monitor results in the log panel -- color-coded per app
7. Save your selection as a named group for next time, or export it as a standalone PS1/JSON

### Exporting

**Export as WinGet Import JSON** creates an official `winget import` compatible file with `Sources`, `Packages`, and `PackageIdentifier` entries.

**Export as Wingetter Group JSON** creates a portable Wingetter profile that can be imported back into Wingetter on any machine. It keeps legacy `PackageIds` for compatibility and adds `Packages` entries when a package carries vetted install options.

**Export as PS1** generates a self-contained PowerShell script that installs your selected packages with no dependencies -- hand it to a coworker or drop it in your deployment pipeline. Generated scripts use PowerShell argument arrays so source names, install locations, and custom installer values with spaces stay quoted correctly.

**Export as WinGet Configuration** creates a declarative `.winget` file using `Microsoft.WinGet.DSC/WinGetPackage` resources. Validate it with `winget configure validate -f .\configuration.winget --disable-interactivity` before applying it on another machine.

**Export Report** becomes available after an install or update run and writes a migration report as Markdown or JSON. The report includes selected packages, status counts, commands, result log paths, installed/available versions, sources, scan timestamps, and import warnings when applicable.

**Diagnostics** writes a redacted support ZIP from the toolbar, or from the CLI with `tools\Export-DiagnosticsBundle.ps1`. The bundle includes catalog/version metadata, recent `%APPDATA%\Wingetter\logs` files, update-check summaries, the latest migration report when available, `winget --info`, `winget source list`, `winget pin list`, and source policy exports with private REST headers redacted.

**Import JSON** accepts official WinGet import/export JSON, Wingetter group JSON, or a simple JSON array of package IDs. Packages not present in the Wingetter catalog are reported and skipped during selection. Safe package metadata such as WinGet `Version` plus Wingetter `InstallOptions` is preserved with an import warning so it can be reviewed before a run starts; raw `Override` / arbitrary argument fields are rejected.

**Profile Gallery** opens the read-only checked-in profile index from `profiles/gallery.json`. Each profile file under `profiles/gallery/` must match its SHA256 hash, may contain only package IDs/names/sources plus constrained safe install options, and is imported only after the package review dialog is accepted. Gallery import selects packages in Wingetter; it never starts install or update.

**Private icon mode** is stored in `%APPDATA%\Wingetter\settings.json`. Enable **Private icons** in the footer to disable all remote favicon downloads and keep deterministic letter icons. When remote icons are enabled, cached icons expire after the configured TTL and network fetches use short timeouts so restricted networks do not stall the UI.

**Corporate source policy** is stored at `%APPDATA%\Wingetter\source-policy.json`. Enable **Corporate policy** in the footer to refuse selected packages whose source is not listed in that policy. Sources can include optional WinGet 1.29+ priority values, and **Export Sources** writes reproducible `winget source add` commands with `--priority` only when the detected WinGet version supports it. Private source headers are redacted by default; use `Export-WingetterSourcePolicy -IncludeRawHeaders` only when deliberately creating a secret-bearing policy file. `Get-WingetterSourcePolicyDrift` compares policy sources with live `winget source list` output and reports missing, extra, changed, explicit, trust, and priority drift.

### Scheduled Update Checks

Run a one-time check without installing updates:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Invoke-UpdateCheck.ps1 -SkipMeteredNetwork -Toast
```

Register a daily current-user scheduled task:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Register-UpdateWatcher.ps1 -DailyAt 09:00
```

Update-check logs are written under `%APPDATA%\Wingetter\logs\update-checks`.

Update policy is stored at `%APPDATA%\Wingetter\update-policy.json` or passed with `-UpdatePolicyPath`. The policy supports global `GlobalNotBeforeUtc`, `MaxDeferrals`, local maintenance windows, and per-package `PackagePolicies` with `PackageId`, `NotBeforeUtc`, `MaxDeferrals`, and `DeferralCount`. Deferred and outside-window updates are logged in the check result; Wingetter still only reports updates and never auto-installs them.

### Offline Download Cache

Use **Download Cache** in the toolbar, or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Invoke-OfflineCache.ps1 -PackageId Google.Chrome,Mozilla.Firefox -AcceptAgreements
```

The cache folder contains `offline-manifest.json`, per-package download metadata, and `install-offline.ps1`. The manifest records each cached installer's SHA256 and byte size, and the replay script refuses to launch files that changed after download.

## Catalog Validation

The repo includes generated catalog snapshots in `catalog/` and validation tools in `tools/`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Invoke-Validation.ps1
```

`Invoke-Validation.ps1` runs the catalog, profile, gallery, WinGet runner, search, package-source, source-policy, update, diagnostics, offline-cache, configuration, accessibility, UI smoke screenshot, release-artifact, launcher-manifest, bundle, XAML, and PSScriptAnalyzer checks. Pass `-SkipAnalyzerInstall` if the validation run should fail instead of installing PSScriptAnalyzer when it is missing.

`Wingetter.ps1` is the launcher. Runtime code lives in `src/Wingetter.Common.ps1`, `src/Wingetter.Catalog.ps1`, `src/Wingetter.WinGet.ps1`, `src/Wingetter.Groups.ps1`, `src/Wingetter.ProfileGallery.ps1`, `src/Wingetter.Sources.ps1`, `src/Wingetter.OfflineCache.ps1`, `src/Wingetter.Configuration.ps1`, `src/Wingetter.UpdateWatcher.ps1`, `src/Wingetter.Diagnostics.ps1`, `src/Wingetter.Ui.ps1`, and `src/Wingetter.App.ps1`. The raw GitHub quick-launch command still works: when a local `src/` directory is not available, the launcher downloads those modules and the canonical catalog from fixed, hash-verified GitHub URLs.

`catalog/winget.json` is the single source of truth for the app catalog and `catalog/groups.json` is the source for built-in groups. Local runs load the catalog JSON directly; packaged runs embed a base64 snapshot generated from that same JSON. `Sync-EmbeddedCatalog.ps1` refreshes only the built-in group fallback and verifies that the catalog module uses the canonical JSON loader. `Test-Catalog.ps1` checks launcher/module parse health, version agreement, unique package IDs, built-in group references, canonical catalog loading, README counts, and changelog formatting.

## Contributing

Contributions are welcome. To add applications to the database, edit `catalog/winget.json`, run `tools\Sync-EmbeddedCatalog.ps1`, and then run `tools\Test-Catalog.ps1`. Each module fallback entry follows this format:

```powershell
@{ Name = "App Name"; WingetId = "Publisher.PackageName"; Icon = "${f}domain.com" }
```

The `${f}` variable expands to the Google Favicon API prefix. Use the app's primary domain for the best icon match.

## License

MIT

---

Made with PowerShell and too much caffeine.
