# Release artifacts

`Wingetter.exe` and the bundled icons are checked into the repository so a
contributor can verify and use the launcher without rebuilding it. The hashes
in `manifest.json` are the contract: if any artifact is mutated in the working
tree without an accompanying manifest update, CI fails.

## Verifying

```powershell
pwsh -NoProfile -File .\tools\Test-ReleaseArtifact.ps1
```

The verifier reads `release/manifest.json`, recomputes SHA256 against each
listed `path`, and exits nonzero on the first mismatch. CI runs the same script
as part of `.github/workflows/validate.yml`.

## Updating

When a new `Wingetter.exe` is checked in (typically at release tag time), update
`release/manifest.json` with the new hash and size and bump the `version` and
`generatedAtUtc` fields. The same tool can regenerate the hashes for you:

```powershell
pwsh -NoProfile -File .\tools\Test-ReleaseArtifact.ps1 -Update
```

`-Update` rewrites `release/manifest.json` from the live file hashes; commit the
result alongside the binary change in the same PR.

## Building

`Wingetter.exe` is produced from the `Wingetter.ps1` launcher using
[PS2EXE](https://www.powershellgallery.com/packages/ps2exe) on a Windows host:

```powershell
Install-Module -Name PS2EXE -Scope CurrentUser
Invoke-PS2EXE -InputFile .\Wingetter.ps1 -OutputFile .\Wingetter.exe -IconFile .\Wingetter.ico -Title "Wingetter" -Product "Wingetter" -NoConsole
```

The current `Wingetter.exe` (`v6.1.0`) predates the dot-sourced module split.
Rebuilding from the modular launcher requires either bundling the `src/`
modules into the EXE (e.g., by concatenating `Common`, `Catalog`, `WinGet`,
`Groups`, `Sources`, `Configuration`, `UpdateWatcher`, `OfflineCache`,
`ProfileGallery`, `Ui`, and `App` into a single script before invoking PS2EXE)
or relying on the launcher's raw-GitHub module-download path. A future change
should consolidate this into `tools\Build-WingetterExe.ps1`.
