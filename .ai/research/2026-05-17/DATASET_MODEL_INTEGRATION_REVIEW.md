# Dataset, Model, And Integration Review

Research date: 2026-05-17.

## Relevance

Wingetter is not an AI/ML product. There is no current model, embedding index, analytics pipeline, scraper, benchmark, or cloud API dependency. This file is intentionally thinner than the package-manager and security reviews.

The project does have data and integration opportunities because its core asset is a curated software catalog.

## Data Sources

| Source | Use | Notes |
|---|---|---|
| `Wingetter.ps1` static catalog | Current canonical catalog | 765 unique IDs, 39 categories, inline app names/icons. |
| `microsoft/winget-pkgs` | Manifest metadata | Package IDs, versions, installers, SHA256, tags, publishers, descriptions, release notes when available. |
| WinGet source cache / `winget show` | Current package details | Preferred runtime source for exact installed/available package metadata. |
| Official WinGet export JSON | Machine profile import/export | Provides compatible profile format. |
| Scoop buckets | Future source adapter | JSON manifests and bucket taxonomy. |
| Chocolatey community repository | Future source adapter | Package metadata, internal repo patterns, export command. |
| PowerShell Gallery / PSResourceGet | Future source adapter | Modules/scripts for sysadmin workflows. |

## Non-ML Integration Opportunities

- Catalog validation and enrichment pipeline.
- Source adapter contract for WinGet, then Scoop/Chocolatey/PSResourceGet.
- Official WinGet import/export compatibility.
- WinGet Configuration export.
- Private REST source support.
- Offline download/cache mode.
- Run reports suitable for helpdesk or personal rebuild records.

## Possible Local Intelligence Features

These do not require an LLM:

- Fuzzy search with weighted fields.
- Profile diff: selected profile vs current machine.
- Duplicate package detection across sources.
- Source preference scoring.
- "Missing from this PC" and "already current" scoring.
- Suggested profile starter groups based on selected apps.

## Possible Model-Assisted Features

These are deferred because trust/reliability work is higher priority:

- Natural-language package search over catalog descriptions.
- Local embedding index over package names, tags, descriptions, and categories.
- "Build me a developer workstation profile" assistant that drafts a profile but never executes it without explicit package review.
- Package categorization suggestions for new catalog entries.
- Duplicate/near-duplicate package grouping from metadata.

## Evaluation Ideas

- Catalog freshness: percent of catalog IDs that `winget show --id --exact` resolves.
- Search quality: curated query set with expected packages and top-N recall.
- Install reliability: success/skipped/failed rate across a safe sample package set.
- Export/import compatibility: round-trip official WinGet JSON fixtures.
- Source trust completeness: percent of selected packages with publisher, installer type, URL, and SHA256 visible.
- Profile portability: packages installed on a clean VM from an exported profile.

## Recommendation

Do not add model dependencies now. Build structured catalog data, metadata enrichment, and evaluation fixtures first. Those assets will make future local search or recommendation features safer and measurable.
