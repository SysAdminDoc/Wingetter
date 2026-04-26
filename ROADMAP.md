# Wingetter Roadmap

Forward-looking scope for the 765-app winget GUI. "Ninite, but with full winget coverage."

## Planned Features

### Catalog
- Pull catalog from the live winget manifest index (winget-pkgs repo) on first launch so app list stays current without script releases.
- Bucket second data source: Scoop main/extras buckets, Chocolatey community, PowerShell Gallery modules.
- Auto-detect duplicate packages across sources and prefer the one with the fewest install prompts.
- User-contributed catalog entries stored in `%LOCALAPPDATA%\Wingetter\custom.json` and merged at runtime.

### Install Pipeline
- Parallel install up to N concurrent sessions (winget 1.11+ `--parallel`) with per-app live log tails in expandable rows.
- Pre-flight dependency resolution: warn about missing VC++ redistributables before installing apps that need them, then batch-install.
- Post-install smoke test: verify the app's registered exe path resolves and launches `--version` (configurable per-app).
- Install queue pause/resume/skip and drag-to-reorder.
- Rollback last session: capture winget transaction log and offer one-click uninstall of everything Wingetter just installed.

### Profiles & Sharing
- Cloud-free profile sync via OneDrive/Dropbox/Google Drive folder (store JSON group, optional encrypted with user password).
- Public profile gallery: browse curated groups by category (streamer kit, homelab kit) via read-only GitHub Gist index.
- Corporate mode: lock the catalog to an internal manifest URL (signed JSON) for MSP/IT deployments.

### UX
- Fuzzy search across name, Winget ID, tags, description (currently name only).
- Per-app "last installed" timestamp and version pin indicator.
- Keyboard nav: arrow keys to move, Space to toggle, Enter to install selected (keeps existing "no keyboard shortcut" rule for commands, this is list nav).
- Compact/dense mode toggle that shows 2x the apps per viewport.
- Icon cache versioning: purge the favicon cache after 30 days so rebrands (e.g., X/Twitter) resolve.

## Competitive Research
- **UniGetUI (ex-WingetUI)** — multi-source (winget/scoop/choco/pip/npm) + bundle import/export + auto-update daemon. Wingetter's catalog size is a differentiator; its UX and multi-source are gaps.
- **Ninite** — web-picker + silent installer; the moat is simplicity. Wingetter's "Export as PS1" already covers this; ship curated "one-click" presets that fit on a single tile.
- **RuckZuck** — ~600 apps, CM integration; steal the "update all installed" continuous-scan mode.
- **winstall.app** — browser-based winget bundle builder; mirror its shareable URL schema so a Wingetter preset can be linked from docs/README.

## Nice-to-Haves
- Background "update available" tray icon like UniGetUI with Action Center toast on new versions.
- Install-time integrity: verify the package's SHA256 against the winget manifest before handing off to winget.
- Offline mode: pre-cache selected installers to a USB drive for air-gapped deployments.
- Publish as `Install-Module Wingetter` so CLI-only workflows can consume the catalog.
- Language pack manager tab (winget also installs MUI packs).
- Category editor so users can reassign apps to their own taxonomy without editing the script.

## Open-Source Research (Round 2)

### Related OSS Projects
- https://github.com/UniGetUI/UniGetUI — most active multi-backend GUI (winget/scoop/choco/pip/npm/dotnet)
- https://github.com/ChrisTitusTech/winutil — PowerShell WPF reference with curated app catalog
- https://github.com/marticliment/WingetUI — historical WingetUI repo (predecessor to UniGetUI)
- https://github.com/novus-package-manager/novus — Rust-based, auto-elevates, no admin terminal
- https://github.com/p32929/siin — Rust batch installer, Ninite-style
- https://github.com/2rf/winGetDebloated — winget bloatware removal, batch
- https://github.com/microsoft/winget-pkgs — upstream manifest repo (autocompletion source)
- https://github.com/valinet/ExplorerPatcher — example of a tool shipped via winget with admin manifest caveats

### Features to Borrow
- Export installed-apps JSON bundle, import on a new PC to re-install (UniGetUI)
- Multi-backend: same UI lists winget + scoop + choco packages, unified search (UniGetUI)
- Tray notifications on successful updates with batched summary (UniGetUI)
- Admin-elevation per package only when required, not globally (Novus)
- One-click custom-installer exe like Ninite: bundle selected package IDs into a runnable .ps1/.exe (siin)
- Source metadata panel: show manifest URL, publisher verification, SHA256 per install (winget-pkgs)
- "Pin" packages to skip updates (winget-native feature — expose in GUI)
- Dependency tree preview before install (winget supports requires chains)
- Category curation powered by YAML in the repo so the 765-app list is PR-reviewable
- Offline catalog: cache manifests locally so airplane-mode browsing works (winget sources local)

### Patterns & Architectures Worth Studying
- UniGetUI splits each backend behind a shared `IPackageManager` interface — new backends drop in
- Runspace-based background installs (WinUtil pattern) so UI stays responsive on long install lists
- Manifest autocompletion by pulling winget-pkgs via sparse git checkout or API index.json
- Per-app install-args override field with a diff against manifest defaults, logged for audit
- Progress reporting via `winget --verbose-logs` parsing + structured ETW rather than stdout regex
