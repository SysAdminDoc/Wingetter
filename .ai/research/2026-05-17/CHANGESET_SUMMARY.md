# Changeset Summary

Research date: 2026-05-17.

## Files Created

- `PROJECT_CONTEXT.md` - canonical consolidated project context for future work.
- `.ai/research/2026-05-17/STATE_OF_REPO.md` - local repo reconnaissance memo.
- `.ai/research/2026-05-17/MEMORY_CONSOLIDATION.md` - reconciliation of local instructions, stale memory, docs, and roadmap claims.
- `.ai/research/2026-05-17/SOURCE_REGISTER.md` - local and external source register with evidence IDs.
- `.ai/research/2026-05-17/RESEARCH_LOG.md` - search passes, queries/classes covered, failed searches, saturation notes, limitations.
- `.ai/research/2026-05-17/COMPETITOR_MATRIX.md` - direct and adjacent competitor comparison.
- `.ai/research/2026-05-17/FEATURE_BACKLOG.md` - raw harvested backlog before prioritization.
- `.ai/research/2026-05-17/PRIORITIZATION_MATRIX.md` - scored candidate matrix and recommended sequence.
- `.ai/research/2026-05-17/SECURITY_AND_DEPENDENCY_REVIEW.md` - dependency/security findings and hardening ideas.
- `.ai/research/2026-05-17/DATASET_MODEL_INTEGRATION_REVIEW.md` - data/source/model/integration review.

## Files Modified

- `ROADMAP.md` - replaced prior loose roadmap with a prioritized, sourced, practical roadmap tied to source IDs.

## Files Intentionally Not Modified

- `AGENTS.md` - ignored/untracked local tool-specific pointer; left intact.
- `CLAUDE.md` - ignored/untracked and stale; left intact to avoid committing local tool notes.
- `README.md` - known drift documented, but not edited because this run's requested root deliverables were context and roadmap.
- `CHANGELOG.md` - known drift documented, but not edited because no product code/version release happened.
- `Wingetter.ps1` - no code changes were made in this research/planning run.

## Verification Performed

- PowerShell AST parse of `Wingetter.ps1`: zero parse errors.
- Catalog count check: 765 IDs, 765 unique IDs, 39 categories.
- PSScriptAnalyzer run: warnings captured in research notes.
- Local WinGet help/source/pin/download checks.
- GitHub metadata checked through authenticated `gh`.
- External sources reviewed and registered.

## Continuation File Decision

No `CONTINUE_FROM_HERE.md` was created because the required artifacts were completed in this session.

## Development Follow-up: 2026-05-17 Catalog And Metadata Batch

### Files Created

- `catalog/winget.json` - generated package catalog snapshot for v6.1.0.
- `catalog/groups.json` - generated built-in group snapshot for v6.1.0.
- `tools/Export-WingetterCatalog.ps1` - parser/exporter that regenerates catalog snapshots from the current script.
- `tools/Sync-EmbeddedCatalog.ps1` - sync tool that regenerates the embedded fallback from the JSON catalog and groups.
- `tools/Test-Catalog.ps1` - validation command for script parse health, generated JSON freshness, README count drift, duplicate IDs, group references, and changelog formatting.
- `tools/Test-ProfileJson.ps1` - non-UI smoke test for official WinGet JSON, Wingetter group JSON, and simple package ID array import/export helpers.
- `tools/Test-WinGetRunner.ps1` - non-installing smoke test for WinGet runner argument handling, safe log names, excerpts, and status classification.
- `tools/Test-Xaml.ps1` - WPF XAML load smoke test for named controls.
- `.github/workflows/validate.yml` - GitHub Actions workflow for catalog, profile JSON, runner, and XAML validation on Windows.

### Files Modified

- `Wingetter.ps1` - added local JSON catalog/group loading with embedded fallback; added missing icon metadata for four package records; normalized the embedded fallback through the sync tool; added official WinGet import/export JSON helpers and UI wiring; replaced install/update process execution with structured run logging and result capture; added a package trust detail panel backed by `winget show` and `winget list`; replaced raw WinGet bootstrap downloads with App Installer registration, `Microsoft.WinGet.Client` repair, and JSONL audit logging.
- `README.md` - synced the version badge, built-in group list, category counts, and catalog validation instructions.
- `CHANGELOG.md` - replaced malformed historical header with `Unreleased`, `v6.1.0`, and `v6.0.0` entries.
- `PROJECT_CONTEXT.md` - recorded current catalog validation state and remaining source-of-truth gap.
- `ROADMAP.md` - converted roadmap entries to checklist headings and marked R-001/R-002/R-003/R-004/R-005/R-006/R-007 complete.
- GitHub repository description - synced app count from 734 to 765 through `gh repo edit`.

### Verification Performed

- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Export-WingetterCatalog.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Sync-EmbeddedCatalog.ps1 -Check`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-Catalog.ps1`

## Development Follow-up: 2026-05-17 Metadata Search Batch

### Files Created

- `tools/Test-SearchMetadata.ps1` - smoke tests for local metadata search scoring and ranking behavior.

### Files Modified

- `src/Wingetter.Catalog.ps1` - added pure search text normalization and scoring helpers.
- `src/Wingetter.Ui.ps1` - search now considers category, group membership, publisher-like ID tokens, installed/update/pin state, source, and scope, then ranks matches inside each category.
- `.github/workflows/validate.yml` - added search metadata validation to CI.
- `README.md`, `CHANGELOG.md`, `PROJECT_CONTEXT.md`, and `ROADMAP.md` - documented metadata-rich search and marked R-012 complete.

### Verification Performed

- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-SearchMetadata.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-ProfileJson.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-WinGetRunner.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -STA -File tools\Test-Xaml.ps1`

## Development Follow-up: 2026-05-17 Installed Detection Batch

### Files Modified

- `src/Wingetter.WinGet.ps1` - added `Microsoft.WinGet.Client` object-based installed package detection, `winget list` fallback parsing, cache writing, and conversion helpers for installed package records.
- `src/Wingetter.Ui.ps1` - changed the background installed-app scan to consume richer installed package records and show detected versions in package details.
- `tools/Test-WinGetRunner.ps1` - added object conversion and fallback text parsing tests for installed detection.
- `README.md`, `CHANGELOG.md`, `PROJECT_CONTEXT.md`, and `ROADMAP.md` - documented the richer installed detection path and marked R-010 complete.

### Verification Performed

- `Get-Module -ListAvailable Microsoft.WinGet.Client`
- `Get-Command -Module Microsoft.WinGet.Client`
- `Get-Help Get-WinGetPackage -Parameter *`
- `Get-WinGetPackage -Count 3 | Select-Object -First 3 | Format-List *`
- `winget list --help`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-Catalog.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-WinGetRunner.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -STA -File tools\Test-Xaml.ps1`
- Live helper smoke: `Get-WinGetInstalledCatalogPackages -PackageIds @('7zip.7zip','Google.Chrome','Mozilla.Firefox')`

## Development Follow-up: 2026-05-17 Migration Reports Batch

### Files Modified

- `src/Wingetter.Groups.ps1` - added `Wingetter.MigrationReport.v1` report creation, Markdown rendering, and JSON/Markdown export helpers.
- `src/Wingetter.Ui.ps1` - added Export Report action, automatic run report creation, automatic `migration-report.json` writing under the run log directory, and import-warning carry-forward.
- `tools/Test-ProfileJson.ps1` - added migration report summary, package state, JSON round-trip, and Markdown content coverage.
- `tools/Test-Xaml.ps1` - added `ExportReportBtn` to the required control smoke test.
- `README.md`, `CHANGELOG.md`, `PROJECT_CONTEXT.md`, and `ROADMAP.md` - documented migration reports and marked R-011 complete.

### Verification Performed

- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-ProfileJson.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -STA -File tools\Test-Xaml.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-Catalog.ps1`

## Development Follow-up: 2026-05-17 Pin Controls Batch

### Files Modified

- `src/Wingetter.WinGet.ps1` - added package operation argument builder, `--include-pinned` support for update operations, pin status parsing, pin status lookup, and pin add/block/installed/remove commands.
- `src/Wingetter.Ui.ps1` - added pin status and controls to the package detail panel, row-level pinned badges after lookup, and an Include pinned updates checkbox.
- `tools/Test-WinGetRunner.ps1` - added pin parser coverage and update argument checks for `--include-pinned`.
- `tools/Test-Xaml.ps1` - added required pin controls to the XAML smoke test.
- `README.md`, `CHANGELOG.md`, `PROJECT_CONTEXT.md`, and `ROADMAP.md` - documented pin controls and marked R-009 complete.

### Verification Performed

- `winget pin --help`
- `winget pin add --help`
- `winget pin remove -?`
- `winget pin list --help --disable-interactivity`
- `winget upgrade -?`
- `winget pin list --id Google.Chrome --exact --disable-interactivity`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-Catalog.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-ProfileJson.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-WinGetRunner.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -STA -File tools\Test-Xaml.ps1`
- XAML load smoke command confirming `PackageDetailsBorder` exists.
- Live package detail extraction for `Google.Chrome` using the new helper functions.
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-Catalog.ps1 -CheckWingetAvailability -AvailabilitySampleSize 5`

## Development Follow-up: 2026-05-17 Modularization Batch

### Files Created

- `src/Wingetter.Common.ps1` - shared module helper for resolving the repository/root path.
- `src/Wingetter.Catalog.ps1` - catalog conversion plus embedded catalog fallback data.
- `src/Wingetter.WinGet.ps1` - WinGet detection, bootstrap repair, process capture, result logging, and package detail helpers.
- `src/Wingetter.Groups.ps1` - saved group, profile import/export, official WinGet JSON, and built-in group fallback helpers.
- `src/Wingetter.Ui.ps1` - splash/icon helpers, theme definitions, XAML, and GUI event wiring.
- `src/Wingetter.App.ps1` - WPF/runtime bootstrap and `Start-Wingetter`.

### Files Modified

- `Wingetter.ps1` - reduced to a launcher that loads local `src/` modules, supports `WINGETTER_SOURCE_DIR`, and downloads modules from raw GitHub for `irm ... | iex` quick-launch runs when no local `src/` is available.
- `catalog/winget.json` and `catalog/groups.json` - updated `embeddedFallbackFile` metadata to point at the source modules.
- `tools/Sync-EmbeddedCatalog.ps1` - now regenerates embedded fallback data inside `src/Wingetter.Catalog.ps1` and `src/Wingetter.Groups.ps1`.
- `tools/Export-WingetterCatalog.ps1` - now exports catalog/group snapshots from source modules instead of the launcher.
- `tools/Test-Catalog.ps1` - now parses the launcher and all `src/*.ps1` modules.
- `tools/Test-ProfileJson.ps1` - now imports `src` modules directly for JSON profile coverage.
- `tools/Test-WinGetRunner.ps1` - now imports the WinGet module directly for runner helper coverage.
- `tools/Test-Xaml.ps1` - now validates the XAML block from `src/Wingetter.Ui.ps1`.
- `README.md`, `CHANGELOG.md`, `PROJECT_CONTEXT.md`, and `ROADMAP.md` - updated for the module architecture and marked R-008 complete.

### Verification Performed

- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Sync-EmbeddedCatalog.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Export-WingetterCatalog.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-Catalog.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-ProfileJson.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\Test-WinGetRunner.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -STA -File tools\Test-Xaml.ps1`
