# Release artifacts

`Wingetter.exe` and the bundled icons are checked into the repository so a
contributor can verify and use the launcher without rebuilding it. The hashes
in `manifest.json` are the contract: if any artifact is mutated in the working
tree without an accompanying manifest update, local validation fails.

## Verifying

```powershell
pwsh -NoProfile -File .\tools\Test-ReleaseArtifact.ps1
```

The verifier reads `release/manifest.json`, recomputes SHA256 against each
listed `path`, regenerates the bundled launcher from the current modular source,
checks that the manifest and `Wingetter.exe` version metadata reference that
bundle hash, and compares the recorded Authenticode status with the live EXE.
The repository-level validation command also runs this check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Invoke-Validation.ps1
```

## Updating

When a new `Wingetter.exe` is checked in (typically at release tag time), update
`release/manifest.json` with the new hash, size, bundled-source hash, PS2EXE
version, EXE metadata, and Authenticode status. The same tool can regenerate the
manifest for you:

```powershell
pwsh -NoProfile -File .\tools\Test-ReleaseArtifact.ps1 -Update
```

`-Update` rewrites `release/manifest.json` from the live file hashes and current
source bundle; commit the result alongside the binary change.

## Building

`Wingetter.exe` is produced from the bundled launcher using
[PS2EXE](https://www.powershellgallery.com/packages/ps2exe) on a Windows host:

```powershell
Install-Module -Name PS2EXE -Scope CurrentUser
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-WingetterExe.ps1 -RunPS2EXE
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-ReleaseArtifact.ps1 -Update
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Invoke-Validation.ps1
```

`tools\Build-WingetterExe.ps1` rebuilds from the current modular source by
concatenating the `src\` modules into a parser-checked bundled launcher before
PS2EXE packages it. The build embeds the bundled launcher SHA256 into EXE
version metadata and signs with a local code-signing certificate when one is
available. If no certificate is available, keep the unsigned state explicit in
`release\manifest.json` and rely on the checked SHA256, size, bundled-source
hash, and Authenticode status contract.
