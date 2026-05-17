# Memory Consolidation

Research date: 2026-05-17.

## Instruction Files Found

| File | Tracking State | Role | Reconciled Finding |
|---|---:|---|---|
| `AGENTS.md` | Ignored/untracked by global gitignore | Local agent pointer | Points to `CLAUDE.md` and shared global memory rules. It remains tool-specific and should not be used as shipped product documentation. |
| `CLAUDE.md` | Ignored/untracked by repo `.gitignore` | Local working notes | Stale: says `Wingetter v0.1.0` and `Files: ~7` while script UI is `v6.1.0` and repo has more tracked artifacts. |
| `README.md` | Tracked | User-facing docs | Mostly current on broad features and app/category totals, but category counts and built-in groups are stale. |
| old `ROADMAP.md` | Tracked | Planning notes | Contained useful ideas and competitor names, but lacked prioritization, source IDs, repo reconciliation, and saturation notes. Replaced with a scored roadmap. |
| `CHANGELOG.md` | Tracked | Release history | Malformed date and mixed version history under `v0.1.0`; needs future cleanup. |

## Shared Memory And Global Rules Consulted

- Global behavior rules and project instructions were read from `C:\Users\--\.claude\CLAUDE.md` and `C:\Users\--\CLAUDE.md`.
- Shared memory index was read from `C:\Users\--\.claude\projects\c--Users----repos\memory\MEMORY.md`.
- PowerShell stack memory was read from `stack-powershell.md` and `powershell-gotchas.md`.
- Codex memory was searched for Wingetter-related entries and did not contain a direct Wingetter project memory hit.

## Reconciled Project Facts

- Canonical current app version for product planning is `v6.1.0`, because it appears in the actual runtime script UI.
- Canonical app count is 765 unique package IDs, because the script catalog parser confirms 765 unique `WingetId` values.
- Canonical category count is 39, because the software database parser confirms 39 category keys.
- Canonical source of project architecture is now root `PROJECT_CONTEXT.md`; local ignored `CLAUDE.md` remains stale and should be updated only if the user wants local tool notes refreshed.
- The repo remains a single-script PowerShell/WPF project; no package manifest or build system exists beyond the checked-in script and executable.

## Contradictions

| Claim | Source | Contradiction | Resolution |
|---|---|---|---|
| Version is `v0.1.0` | ignored `CLAUDE.md`, `CHANGELOG.md` | Script UI and recent commit history show `v6.1.0` work. | Treat `v6.1.0` as current runtime version; roadmap includes version sync. |
| GitHub description says 734 apps | `gh repo view` | README/script say 765 apps. | Treat 765 as local truth; roadmap includes GitHub metadata/doc sync. |
| Built-in groups include Remote Worker, Media & Entertainment, Student Essentials | README | Script uses Streaming Setup, Office & Productivity, 3D Printing Workshop instead. | Treat script as truth; roadmap includes README count/group sync. |
| Parallel installs via `winget 1.11+ --parallel` | old ROADMAP | Local `winget install --help` for v1.28.240 did not list `--parallel`. | Move parallel install to deferred/unverified until official docs or local help prove it. |
| `CLAUDE.md` is source of truth | ignored `AGENTS.md` | `CLAUDE.md` is intentionally ignored and stale. | Use `PROJECT_CONTEXT.md` for durable repo context; keep `AGENTS.md`/`CLAUDE.md` tool-specific. |

## Extracted Durable Context

Durable project facts were moved into root `PROJECT_CONTEXT.md`:

- Purpose and product thesis.
- Canonical current state.
- Architecture.
- Verified strengths.
- Important gaps.
- Strategic direction.
- Source trail.

## Planning Material Moved Forward

The useful old roadmap ideas were retained but reorganized:

- Live catalog / `winget-pkgs` sync became catalog externalization and validation.
- Official export/import became P0 schema compatibility.
- Multi-source support moved behind a future adapter contract.
- Pins became a concrete package lifecycle item.
- Source/manifest/hash visibility became a P0 trust item.
- Offline mode became `winget download` based P2 work.
- Corporate/internal source mode became a private REST/explicit-source item.

## Open Conflicts

- Whether ignored `CLAUDE.md` should be updated locally: not changed in this run because it is intentionally untracked and tool-specific.
- Whether `Wingetter.exe` should remain tracked: not changed in this planning run. It should be evaluated in a future release/build-system pass.
- Whether to keep direct `irm | iex` launch as the primary quickstart: retained as a product feature, but future trust work should add hash/release guidance.

## Memory Update Decision

No global memory files were modified. The user requested repo-local consolidation artifacts, not a persistent cross-session memory update.
