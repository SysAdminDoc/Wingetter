# Security And Dependency Review

Research date: 2026-05-17.

## Dependency Surface

Wingetter has no package manifest, lockfile, NuGet project, npm package, Python environment, or module manifest. Its active dependency surface is:

- Windows PowerShell 5.1+.
- WPF assemblies: PresentationFramework, PresentationCore, WindowsBase.
- System.Windows.Forms for DoEvents and dialogs.
- Windows Package Manager CLI (`winget`).
- Windows Runtime toast notification APIs.
- Network access to Google favicon URLs for package icons.
- Network access to Microsoft/GitHub URLs during WinGet bootstrap if WinGet is missing.
- Checked-in binary artifact: `Wingetter.exe`.

## WinGet Security Model Relevant To Wingetter

- WinGet install/upgrade already has installer hash validation and warns that `--ignore-security-hash` is not recommended.
- WinGet manifests include installer URL and SHA256 metadata.
- The `source` command warns to use secure, trusted sources and supports default, explicit, and REST source types.
- Local manifest installation requires an admin-enabled setting because it carries extra risk.
- WinGet Configuration files and DSC resources should be checked for trust before applying.

## Findings

### S-001 - Bootstrap path lacks visible verification

`Install-WinGet` downloads VCLibs, Microsoft.UI.Xaml, and a latest WinGet release asset, then installs them. It does not present or record a hash/signature verification result in Wingetter's own logs.

Recommended action:

- Prefer Microsoft-supported bootstrap/repair paths from `Microsoft.WinGet.Client` where possible.
- If direct downloads remain, log URL, destination path, size, and verification evidence.
- Surface failure reasons instead of returning `$false` from a broad catch.

Sources: L03, E10, E22.

### S-002 - Empty catch blocks hide meaningful failures

PSScriptAnalyzer found many empty catch blocks. In a GUI tool, silent failures make support and trust worse because users see missing icons, stale installed-state results, or failed toasts without diagnosis.

Recommended action:

- Add a lightweight internal log buffer and write structured warning records.
- Keep user-facing text concise but preserve technical detail in a log file.

Sources: L13.

### S-003 - Result parsing ignores stderr

The install/update handler redirects stderr but discards it, then classifies results from stdout and exit code. This hides installer errors, source failures, authentication failures, and hash warnings.

Recommended action:

- Capture stderr.
- Include stdout and stderr excerpts in per-package result records.
- Link to WinGet verbose logs.

Sources: L07, E01, E02.

### S-004 - Exported PS1 may hit PowerShell 5.1 encoding trap

Generated PS1 content begins with a block comment and is written with `Set-Content -Encoding UTF8`. The shared PowerShell stack notes that Windows PowerShell 5.1 adds a UTF-8 BOM for this encoding, which can corrupt block-comment parsing in some script-download patterns.

Recommended action:

- Use a deterministic no-BOM write helper for generated scripts when targeting PowerShell 5.1.
- Add an export/import round-trip test that executes `powershell -NoProfile -File` parse-only validation.

Sources: L04 and PowerShell stack memory consulted in this run.

### S-005 - External favicon requests create privacy and reliability concerns

The app fetches icons from Google favicon endpoints for hundreds of apps. This improves polish but leaks launch/package-interest network traffic and can slow or fail on restricted networks.

Recommended action:

- Add an "offline/private icons" option.
- Cache with TTL and timeout.
- Store icon source metadata in the future catalog.

Sources: L02, L08.

### S-006 - Pill backdrop visual rule violations

Several text-bearing badges use fully rounded backgrounds. This is a project-style rule violation and should be corrected during UI polish.

Recommended action:

- Replace text-bearing `CornerRadius=999` with 8-12.
- Preserve true circular progress/indicator use only where appropriate.

Sources: L16.

### S-007 - Source trust is invisible to users

The GUI currently presents package names and IDs but not the source, installer hash, installer type, publisher, or source trust level.

Recommended action:

- Add a trust/detail drawer before expanding beyond WinGet.
- Expose `winget source list` and package manifest metadata.

Sources: E07, E08, E09.

## Security-Positive Current Choices

- No `Invoke-Expression` use was found in the script body.
- Install/update commands use `--id` and `--exact`, reducing ambiguous package selection.
- No `--ignore-security-hash` path was found in current install/update commands.
- WinGet admin settings on this machine showed installer hash override disabled.
- Local parser check found zero PowerShell syntax errors.
- Public profile gallery imports are checked-in JSON only, SHA256-verified against `profiles/gallery.json`, reject unsupported install-argument fields, and select packages only after visible package/source review.

## Dependency Upgrade Opportunities

- Document and pin the ps2exe/build process for `Wingetter.exe`; current repo has a checked-in executable but no reproducible build script.
- Evaluate `Microsoft.WinGet.Client` for object-based package/list/source operations instead of relying on command text parsing.
- Keep direct `winget.exe` as the default install executor unless the module proves more reliable for GUI workflows.

## Suggested Security Acceptance Tests

- Validate no package ID duplicates.
- Validate every built-in group ID exists in the catalog.
- Validate no generated command includes unescaped user text.
- Validate `--ignore-security-hash` is not emitted except from an explicit advanced override.
- Validate official WinGet import JSON is parsed but not executed until user selects packages.
- Validate bootstrap failure displays actionable error text.
- Validate source list and source name are visible before install.
