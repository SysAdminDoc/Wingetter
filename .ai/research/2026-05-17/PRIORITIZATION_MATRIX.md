# Prioritization Matrix

Research date: 2026-05-17.

Scoring: 5 is highest. Total = impact + evidence + feasibility + risk reduction.

| ID | Candidate | Tier | Impact | Evidence | Feasibility | Risk Reduction | Total | Rationale |
|---|---|---|---:|---:|---:|---:|---:|---|
| R-001 | Externalize catalog and add validation | P0 | 5 | 5 | 4 | 5 | 19 | Unlocks nearly every other roadmap item and prevents silent data drift. |
| R-002 | Reconcile versioning, README, changelog, metadata | P0 | 4 | 5 | 5 | 4 | 18 | Current public docs disagree with code and GitHub metadata. |
| R-003 | Official WinGet import/export schema | P0 | 5 | 5 | 4 | 4 | 18 | Directly aligns with Microsoft-supported rebuild workflows. |
| R-004 | Harden install/update execution and result capture | P0 | 5 | 5 | 4 | 5 | 19 | Reduces most user-visible failures and support blind spots. |
| R-005 | Source/manifest/trust detail panel | P0 | 5 | 5 | 3 | 5 | 18 | Strong differentiator against simple batch installers; improves install trust. |
| R-006 | Safer WinGet bootstrap | P0 | 4 | 5 | 3 | 5 | 17 | Sensitive path; should be more auditable before broader distribution. |
| R-007 | CI and focused PowerShell tests | P1 | 4 | 5 | 4 | 5 | 18 | Makes future refactors and catalog work safer. |
| R-008 | Modularize script | P1 | 4 | 5 | 3 | 4 | 16 | Needed for maintainability but should follow tests/catalog extraction. |
| R-009 | Pins and lifecycle controls | P1 | 4 | 5 | 4 | 4 | 17 | Native WinGet capability missing from UI. |
| R-010 | Improve installed-app detection | P1 | 4 | 4 | 3 | 4 | 15 | Current regex table parsing is fragile. |
| R-011 | Profile lifecycle and migration reports | P1 | 4 | 5 | 4 | 3 | 16 | Builds on existing groups and Ninite/WinGet patterns. |
| R-012 | Metadata-rich search | P1 | 4 | 4 | 3 | 2 | 13 | High UX value after catalog metadata exists. |
| R-013 | Visual/accessibility cleanup | P1 | 3 | 5 | 4 | 3 | 15 | Known rule violations and straightforward UI polish. |
| R-014 | Source adapter for future managers | P2 | 5 | 5 | 2 | 3 | 15 | Strategic, but unsafe before monolith boundaries are reduced. |
| R-015 | Corporate/internal source mode | P2 | 4 | 5 | 3 | 4 | 16 | Strong sysadmin value after source/trust foundation. |
| R-016 | Scheduled watcher/tray workflow | P2 | 4 | 4 | 3 | 3 | 14 | Valuable but more stateful and support-heavy. |
| R-017 | Offline download/cache mode | P2 | 3 | 4 | 3 | 4 | 14 | Good rebuild/air-gap feature after trust metadata exists. |
| R-018 | WinGet Configuration export | P2 | 3 | 5 | 3 | 3 | 14 | Useful advanced export path; lower mainstream demand. |
| R-019 | Public profile gallery | P2 | 3 | 4 | 2 | 2 | 11 | Nice growth feature but trust/security burden is significant. |

## Tier Rationale

P0 items are foundational because they improve correctness, trust, or compatibility before new surface area is added.

P1 items deepen reliability and maintainability once the foundation is in place.

P2 items expand ecosystem reach and advanced workflows after the app has a stronger data/execution architecture.

## Highest Confidence Sequence

1. R-002: quick public consistency win.
2. R-001: catalog extraction and validation.
3. R-007: CI/parser/catalog checks.
4. R-003: official import/export compatibility.
5. R-004: structured execution/reporting.
6. R-005 and R-009: trust detail and pins.
7. R-008: modularization with test support.

## Items Deferred From Old Roadmap

- Parallel install: deferred until verified by current official docs or local `winget install --help`.
- Multi-source aggregation: deferred until adapter boundaries exist.
- Cloud sync: deferred; folder sync can remain local-first later.
- Language pack manager: not supported by current evidence as a near-term differentiator.
