# Wingetter

A powerful PowerShell GUI application for discovering, selecting, and bulk installing Windows software using [Windows Package Manager (winget)](https://learn.microsoft.com/en-us/windows/package-manager/winget/). Think Ninite, but with 765 apps and full winget integration.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell&logoColor=white)
![Apps](https://img.shields.io/badge/Apps-765-green)
![Categories](https://img.shields.io/badge/Categories-39-orange)
![License](https://img.shields.io/badge/License-MIT-yellow)

---

## Quick Launch

```powershell
irm "https://raw.githubusercontent.com/SysAdminDoc/Wingetter/main/Wingetter.ps1" | iex
```

Paste the above into any PowerShell window to download and run Wingetter instantly. No installation required.

---

## Features

**765 applications** across **39 categories** with a polished WPF interface:

- **Dark / Light mode** -- defaults to dark, toggle with one click
- **Live search** -- instantly filter across all 765 packages
- **Favicon icons** -- parallel-fetched from app domains with colored letter fallbacks and local caching
- **Bulk install** -- select any combination and install them all in sequence via winget
- **Update mode** -- toggle between Install and Update mode to upgrade already-installed apps
- **Installed app detection** -- background scan via `winget list` with green dot indicators
- **Silent install & auto-accept agreements** -- toggleable checkboxes for hands-free deployment
- **Copy command** -- grab the raw `winget install` commands to clipboard
- **Save / Load groups** -- persist custom selections as named groups for reuse
- **Export as PS1 or JSON** -- generate standalone installer scripts or portable JSON configs
- **Import groups** -- load previously exported PS1/JSON files back in
- **10 built-in quick-select groups** -- one-click presets for common setups
- **Category sidebar** -- quick-jump navigation panel for all 39 categories
- **Collapsible categories** -- click any category header to collapse/expand
- **Shift-click range selection** -- hold Shift to select a range of apps at once
- **Enhanced tooltips** -- hover to see app name and WingetId
- **Install log panel** -- color-coded per-app results (success/skipped/failed) with summary
- **Toast notifications** -- Windows notification when batch install completes
- **Splash screen** -- loading progress indicator while icons are fetched
- **Select All / Deselect All** per category or globally
- **WinGet auto-detection** -- checks for winget on launch and offers to install it if missing

## Built-in Groups

Pre-configured package groups for common use cases:

| Group | Description |
|---|---|
| Essential PC Setup | Chrome, Firefox, 7-Zip, VLC, Notepad++, Everything, and more |
| Web Developer | VS Code, Git, Node.js, Docker, Postman, Windows Terminal |
| Python Developer | VS Code, Git, Python 3.13, Miniconda, PyCharm, DBeaver |
| Creative Suite | GIMP, Krita, Inkscape, Blender, OBS, DaVinci Resolve |
| Gaming PC | Steam, Discord, Epic, GOG, MSI Afterburner, DS4Windows |
| Privacy & Security | Bitwarden, KeePassXC, VeraCrypt, Tor, Mullvad, ProtonVPN |
| System Admin | PowerShell 7, Windows Terminal, WinSCP, PuTTY, Sysinternals |
| Remote Worker | Zoom, Teams, Slack, AnyDesk, Notion, Bitwarden |
| Media & Entertainment | VLC, Plex, Spotify, Stremio, MPC-HC, foobar2000 |
| Student Essentials | Firefox, LibreOffice, Notion, Zotero, Python, VS Code |

## Categories

| Category | Apps | | Category | Apps |
|---|---:|---|---|---:|
| System Utilities | 53 | | Networking & Remote | 33 |
| Runtimes & SDKs | 49 | | File Management | 31 |
| Messaging & Email | 39 | | Gaming | 25 |
| CLI Tools | 37 | | Hardware & Diagnostics | 24 |
| Developer Tools | 35 | | Video Tools | 23 |
| Code Editors & IDEs | 34 | | Desktop Customization | 23 |
| Imaging & Design | 21 | | Web Browsers | 20 |
| Note-Taking | 20 | | Music & Audio | 18 |
| Media Players | 17 | | Cloud & DevOps | 16 |
| Science & Education | 15 | | PDF & E-Books | 14 |
| VPN & Privacy | 14 | | Documents & Office | 13 |
| Security | 13 | | Passwords & Encryption | 13 |
| Other | 13 | | Emulators | 12 |
| Productivity | 12 | | Audio Production | 11 |
| Screenshot & Recording | 10 | | Terminals & Shells | 10 |
| 3D Printing & CAD | 10 | | Cloud Storage | 9 |
| Backup & Sync | 9 | | VC++ Redistributables | 8 |
| Database Tools | 8 | | Virtualization | 7 |
| AI & LLM Tools | 7 | | Compression | 5 |
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
5. Click **Install Selected** to kick off the batch install
6. Review results in the log panel -- color-coded per app
7. Save your selection as a named group for next time, or export it as a standalone PS1/JSON

### Exporting

**Export as PS1** generates a self-contained PowerShell script that installs your selected packages with no dependencies -- hand it to a coworker or drop it in your deployment pipeline.

**Export as JSON** creates a portable config file that can be imported back into Wingetter on any machine.

## Contributing

Contributions are welcome. To add applications to the database, edit the `$Script:SoftwareDatabase` hashtable in `Wingetter.ps1`. Each entry follows this format:

```powershell
@{ Name = "App Name"; WingetId = "Publisher.PackageName"; Icon = "${f}domain.com" }
```

The `${f}` variable expands to the Google Favicon API prefix. Use the app's primary domain for the best icon match.

## License

MIT

---

Made with PowerShell and too much caffeine.
