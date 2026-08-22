# Governance Gates

## Evidence Naming and Storage

Evidence names use lowercase ASCII, hyphens, and this shape:

`yyyy-mm-dd_wbs-nnn_phase_surface_platform_locale_state_kind[_sequence].ext`

Examples:

- `2026-07-15_wbs-028_baseline-today_web_en-us_desktop_screenshot_01.png`
- `2026-07-15_wbs-141_curriculum-importer_cli_neutral_quarantine_log.txt`
- `2026-07-15_wbs-409_android-widget_android_fa-ir_offline_runtime.mp4`

Storage rules:

| Evidence | Location | Required companions |
|---|---|---|
| Commands and validators | `logs/` | command, cwd, tool versions, exit code, timestamp |
| Generated previews | `assets/previews/` | prompt, seed/model metadata when available, scorecard, selection status |
| Runtime screenshots/video | `assets/runtime/<platform>/<locale>/` | route/state, viewport/device, build identity |
| Golden/fixture data | repository test/fixture directory | schema/version, source hash, expected result |
| Build and release metadata | `assets/releases/<platform>/` | commit, toolchain, signing/provenance status, checksum |
| External reports | `assets/reports/` or task asset root | source, generated date, checksum, inspection note |

Evidence is append-only after a gate is frozen. A correction receives a new name and explicit supersession note. PHI, credentials, tokens, personal paths inside distributable artifacts, and proprietary lesson bodies are forbidden. Logs are redacted before preservation.

## Phase Definition of Ready

A phase is ready only when all applicable checks pass:

1. Requirement and WBS IDs are linked; dependencies are `done` and validator-safe.
2. Protected routes, IDs, schemas, files, events, and user-visible commitments are named.
3. Inputs and fixtures are available, hashed when mutable, and free of secrets/PHI.
4. Architecture/security/localization/accessibility/performance decisions are explicit.
5. Failure, offline, rollback, migration, and feature-flag behavior are defined.
6. Acceptance evidence names the exact command, runtime surface, platform, locale, and threshold.
7. No unresolved P0 planning finding exists; P1 risks have owner and mitigation.
8. A smaller reversible vertical slice is selected before broad mutation.

## Phase Definition of Done

A phase is done only when all applicable checks pass:

1. Every WBS row has its named artifact or proof; status matches reality.
2. Analyzer, unit/property/integration/security checks pass at the relevant layer.
3. Real runtime behavior is inspected for representative success, empty, loading, offline, error, recovery, and restricted states.
4. English/Persian, LTR/RTL, compact/expanded, text-scale, reduced-motion, keyboard, and semantics checks pass where UI changed.
5. Route, persistence, schema, archive, event, and deep-link compatibility tests pass where contracts changed.
6. Performance budgets and observability signals are captured rather than inferred from compilation.
7. Risk register, ADRs, state, progress, verification, preview ledger, and handoff reflect the implementation.
8. No in-scope P0 or P1 finding remains without an explicit accepted external blocker; rollback remains available until activation proof passes.

## P0 Stop and Rollback Matrix

| Failure class | Immediate stop trigger | Automatic containment | Rollback boundary | Recovery proof required before resume |
|---|---|---|---|---|
| Data loss/corruption | Count/hash mismatch, unreadable archive fixture, destructive migration, lost note/progress | Stop writer and activation; preserve DB/log snapshot; disable affected flag | Prior reader/channel pointer; forward-only repair or restored export | Reconciliation is exact; idempotent rerun; old and new readers pass fixtures |
| Authentication/authorization | Privilege escalation, cross-user/tenant read, client role mutation, bypassed RLS | Revoke policy/RPC/flag; expire affected sessions; preserve audit | Last known-good policy/function/client minimum version | Adversarial RLS matrix passes; credentials rotated if exposed; audit scope closed |
| Rewards/entitlements | Client can mint value, duplicate replay, negative/incorrect reconciliation | Disable rule version and optimistic mutation; freeze settlement | Prior rule/channel projection; ledger remains append-only | Tamper/farming/replay/property tests pass and balances reconcile exactly |
| PHI/privacy | Unredacted sensitive data enters AI, social, analytics, logs, export, or wrong account | Disable channel; block processing; quarantine artifacts; initiate incident log | Last privacy-safe capability/config; delete derived data when allowed | Red-team fixtures pass; affected scope, deletion, access, and notification actions documented |
| Clinical claim/content | Unsupported/hallucinated recommendation, unsafe calculator result, self-approved medical release | Unpublish/disable surface; show honest unavailable state; preserve provenance | Prior reviewed content/formula/model/config version | Independent medical/editorial review plus source/version/boundary tests pass |

P0 incidents never become “known limitations” in a production-ready claim. A P0 can be closed only by evidence, not by copy changes or reduced visibility.

## Change and Removal Gate

No current capability, route, ID, persistence key, schema field, event contract, user file, or documented commitment is removed merely because the new IA no longer exposes it directly. Removal requires:

1. usage and reachability evidence;
2. mapped contextual replacement;
3. data migration/export and legacy redirect/adapter;
4. user- and operator-facing communication where applicable;
5. compatibility and rollback proof;
6. explicit product/safety owner decision recorded as an ADR.

## Governance Gate Result

- Result: passed
- Scope: planning controls for WBS-008 through WBS-020.
- Open P0 findings: zero.
- Open P1 planning findings: zero; implementation risks remain owned in `16-risk-register.md`.
- Next gate: generated preview comparison and autonomous direction lock.
