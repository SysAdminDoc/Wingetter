# Feature Backlog

Research date: 2026-05-17.

This is the raw harvested backlog before final prioritization.

## Catalog And Data

- External `catalog/winget.json` or `catalog/winget.psd1`.
- Catalog schema with name, package ID, category, tags, icon source, source, publisher, description, homepage, installer type, scope hints, and notes.
- Catalog validator for duplicates, missing required fields, invalid groups, icon URL reachability, stale README counts, and `winget show` availability.
- Generated category counts for README.
- Generated app-count badges.
- Sparse checkout or API-based `winget-pkgs` metadata enrichment.
- Manifest metadata cache with refresh timestamp.
- Custom local catalog overlay in `%LOCALAPPDATA%\Wingetter\custom.json`.
- Per-profile source lock.
- Source conflict detection across `winget`, `msstore`, future Scoop, future Chocolatey.
- Package ID migration map for renamed packages.

## Install/Update Pipeline

- `ProcessStartInfo.ArgumentList`.
- Capture stdout and stderr.
- Per-package log file.
- Store `winget --verbose-logs` location.
- Structured operation result JSON.
- Retry failed package.
- Skip current package.
- Pause/resume queue.
- Queue reorder.
- Run report export.
- Post-install installed-state refresh.
- Detection for reboot-needed packages.
- Warn for packages with unknown installed versions.
- Respect pins.
- Include pinned option.
- Uninstall previous option for upgrade.
- Download-only mode via `winget download`.
- Dry run / preview mode that only validates package IDs and source availability.

## Profiles And Sharing

- Official WinGet import support.
- Official WinGet export support.
- Wingetter profile schema with metadata and source.
- Migration report for machine rebuilds.
- Profile diff: current machine vs selected profile.
- Profile validation before install.
- Profile lockfile with resolved package versions.
- Folder sync safe mode for OneDrive/Dropbox/Google Drive.
- Public profile gallery with explicit trust review.
- Profile signing/hash manifest.
- Export to WinGet Configuration YAML.
- Export to Intune/WAU list format.

## UX And Search

- Package details drawer.
- Metadata-rich search.
- Fuzzy search.
- Tag filters.
- Installed/update/pinned/source filters.
- "Why hidden?" explanation in update mode.
- Category count auto-sync.
- Dense mode after responsive audit.
- Better empty states.
- Keyboard navigation for accessibility only, not command shortcuts.
- Remove pill backdrops.
- Better dialog/no-confirmation flow alignment.
- Per-app status chips with bounded radius.
- Localized result handling.
- Toast click opens run report.

## Source And Trust

- Source list manager.
- Explicit/private source mode.
- Trusted source warnings.
- REST source support.
- Manifest SHA256 display.
- Installer URL display.
- Publisher and homepage display.
- Local manifest warning if user imports one.
- Bootstrap audit log.
- Microsoft.WinGet.Client repair/bootstrap path.
- No `--ignore-security-hash` path except explicit advanced override with warning.
- External icon fetch privacy option.
- User-agent and timeout settings for icon fetches.

## Multi-Source Expansion

- WinGet adapter interface.
- Scoop adapter.
- Chocolatey adapter.
- PowerShell Gallery / PSResourceGet adapter.
- Source-specific capability matrix.
- Dedupe view across source adapters.
- Source preference rules.
- Package manager install detection.
- Package manager bootstrap helpers with trust warnings.

## Testing And Release

- Pester tests for parser/catalog.
- Pester tests for export/import.
- Pester tests for generated commands.
- Snapshot test for README count generation.
- PSScriptAnalyzer baseline and gradual cleanup.
- GitHub Actions validation.
- Build script for `Wingetter.exe`.
- Document ps2exe version/command.
- Release checklist.
- Artifact hash file.
- Smoke test instructions.
- Screenshot refresh flow.

## Documentation

- `PROJECT_CONTEXT.md`.
- Updated `ROADMAP.md`.
- Changelog repair.
- README count/group sync.
- Architecture note.
- Catalog contribution guide.
- Security/trust model doc.
- Troubleshooting doc for WinGet unavailable, source corruption, Store missing, proxy, TLS, and system context.
- Release/build doc.
