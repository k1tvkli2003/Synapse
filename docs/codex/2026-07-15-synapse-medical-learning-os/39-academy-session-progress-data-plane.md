# Academy Session Progress Data Plane

**Status:** implemented local v2 boundary with lossless v1 migration/rollback; cloud sync, backup, and reward projection remain open  
**Date:** 2026-07-18  
**Scope:** reviewed Academy packages and learner-owned Course → Session resume state  
**Safety boundary:** the implementation contains no Harrison-like corpus body, no patient data, no free-text response, and no client-authoritative reward or competence claim

## Outcome

Synapse now has a release-bound local checkpoint projection that can open, resume, answer, advance, complete, and restore one reviewed curriculum session without mutating the immutable curriculum package. The runtime is deliberately narrower than the future shared learner-event plane: it proves safe local continuity and stable opaque response receipts while leaving server authority, outbox replay, mastery, scheduling, and rewards outside this repository.

The first wired vertical slice is:

```text
Academy home
→ Course path
→ Chapter → Unit → Concept Cluster → Micro-lesson
→ reviewed Session
→ choice selection
→ recorded response and approved feedback
→ completion receipt
→ return to the actual Course path
→ restart-safe completed state
```

Only the non-medical synthetic package in `apps/app/lib/dev/academy_synthetic_fixture.dart` is used for local UI/runtime evidence. Production entrypoints do not import that fixture.

## Truth and ownership

| Concern | Current authority | Current rule |
|---|---|---|
| Curriculum content | immutable activated `CurriculumManifest` release | The session UI resolves titles, prompt, options, and feedback only through package localization units. |
| Checkpoint identity | `releaseId + microLessonNodeId + sessionId` | Localized titles, paths, and mutable release pointers never define learner-state identity. |
| Choice response | local opaque response receipt | Stores stable IDs, correctness, and UTC time; never stores a content body or free text. |
| Completion | immutable local completion receipt | A duplicate completion returns the existing receipt and cannot mint another result. |
| Rewards/mastery | not this repository | No XP, currency, streak, mastery, scheduling, or competence state is written here. |
| Future cloud truth | authoritative event ledger plus idempotent outbox/inbox | Not implemented locally; response/completion IDs are ready to become replay idempotency keys. |

## Stable identity and schema v2

The stable checkpoint ID is a reversible collision-free composition:

```text
releaseId|microLessonNodeId|sessionId
```

The separator is excluded from the stable-ID alphabet. A prior response is therefore never reinterpreted against a later release with changed wording, ordering, or answer meaning.

The local registry uses one owned atomic key:

```text
__synapse_curriculum_session_progress_v1
```

The key suffix is an installed-storage-slot identity, not the root document schema. It intentionally remains unchanged while the root now contains `schemaVersion: 2`, a record map keyed by the stable checkpoint ID, and a derived integrity summary. Each record contains:

- immutable release, micro-lesson-node, and session IDs;
- `inProgress` or `completed` phase;
- current interaction index and monotonic compare-and-set revision;
- UTC start/update/completion timestamps;
- at most one pending selected option;
- immutable choice responses keyed by interaction ID;
- one completion receipt ID after completion.

The v2 summary records the number of checkpoints, choice receipts, and completion receipts. Decoding recomputes those counts and also rejects a receipt ID reused anywhere in the registry. This detects accidental truncation/count drift and duplicate idempotency keys; it is not cryptographic tamper proof and grants no client authority.

The repository owns only its new key and performs one whole-registry write through `KeyValueStore`. It neither clears nor repurposes the 13 preserved legacy keys.

### Migration and rollback

- a frozen hand-authored v1 fixture proves compatibility independently of the current serializer;
- any supported v1 read or mutation upgrades the full registry through the serialized mutation tail and one atomic write;
- stable checkpoint IDs, revisions, timestamps, choice receipts, and completion receipts survive byte-for-value;
- `migrateToCurrentSchema` returns a privacy-safe source/target/record-count receipt and is idempotent on v2;
- `createRollbackSnapshot(targetSchemaVersion: 1)` emits a non-mutating v1-compatible projection;
- a failed migration write leaves the original v1 value untouched;
- corrupt summaries, globally duplicated receipts, and unknown future schemas fail closed and are not rewritten.

## Supported operations and invariants

| Operation | Contract |
|---|---|
| `read` | Returns the exact release-bound checkpoint or no record. |
| `open` | Creates revision 1 once; otherwise resumes the existing record without award/completion side effects. |
| `incompleteForRelease` | Returns incomplete records for one release ordered by most recent update. |
| `migrateToCurrentSchema` | Losslessly upgrades supported v1 state to v2 and reports whether a write occurred. |
| `createRollbackSnapshot` | Exports a v1-compatible snapshot without downgrading installed state. |
| `selectOption` | Persists one pending stable option ID and rejects stale revisions. |
| `recordChoice` | Requires the persisted selection, creates one opaque response ID, and rejects a conflicting second answer. |
| `advance` | Advances exactly one interaction, optionally requires a recorded response, and clears pending selection. |
| `complete` | Optionally requires the final response, creates one completion receipt, and is idempotent after completion. |
| `auditIntegrity` | Reports typed schema/corruption issues without deleting or silently resetting learner state. |

All mutations are serialized through one local mutation tail. UI callbacks must carry their expected revision; an older screen, retry, or concurrent callback cannot overwrite a newer checkpoint.

## Failure and recovery behavior

- Missing records with an expected revision fail as `progress_checkpoint_missing`.
- Changed interaction indices fail as `stale_progress_checkpoint`.
- Changed revisions fail as `stale_progress_revision`.
- A recorded answer that does not match the stored selection fails as `selection_mismatch`.
- A conflicting answer to an already recorded interaction fails as `choice_already_recorded`.
- Completing or advancing without the required response fails as `required_choice_missing`.
- Future schema versions fail as `unsupported_progress_schema`.
- Unsupported rollback targets fail as `unsupported_progress_rollback_schema`.
- Reused response/completion receipt IDs fail as `duplicate_progress_receipt`.
- Invalid registry shape/identity fails as `corrupt_progress_registry`.
- Corrupt or future state is preserved for recovery; it is never auto-cleared.
- Presentation maps typed codes to localized recovery copy and never exposes raw causes to the learner.

## Product integration

The Flutter Academy surface now resolves an activated catalog, projects the real package hierarchy, routes by stable query IDs, and opens the repository through Riverpod. Immediate completion and restart-restored completion share one semantic result surface and one `Back to path` action. The CTA resolves the actual Course ancestor instead of assuming a hardcoded route.

The implementation includes:

- honest no-package, loading, unavailable-route, missing-content, progress-failure, feedback, and completed states;
- package-bound English/Persian content plus localized Academy chrome;
- LTR/RTL layout, compact status semantics, 200% Persian text coverage, and reduced-motion fixture mode;
- static restored-LUMA pose fallbacks and Night Shift visual grammar;
- no extra StudyHUB brand or second navigation authority.
- bounded rebuildable hierarchy/search/playback indexes with scoped EN/FA
  search, two-budget LRU, single-flight builds, and recovery-safe invalidation;
  see `40-academy-catalog-index-cache.md`.

## Current evidence

| Evidence | Result |
|---|---|
| `packages/services/test/curriculum_session_progress_repository_test.dart` | Nine tests cover restart persistence, advance/completion/idempotency, stale/conflicting writes, frozen-v1 migration, v1 rollback round-trip, failed-write preservation, summary corruption, duplicate receipts, and non-destructive future-schema audit. |
| `packages/services/test/curriculum_catalog_repository_test.dart` | Twenty-two tests cover exact playback ownership/lineage, deterministic/scoped EN/FA/source-origin indexes, independent LRU/node budgets, oversized bypass, single-flight/drift/error recovery, clear/targeted/active-lookup invalidation, activation-race freshness, target-isolated offline boot, and non-destructive integrity failures. |
| `packages/services/test/curriculum_package_repository_test.dart` | Seventeen tests cover dual trusted hashes, canonical stored bytes/record parity, backwards-compatible recovery state, truthful idempotency, immutable collision, target eligibility, activation/rollback/recovery receipts and audit, explicit restore, corrupt-pointer mutation refusal, and same-store serialization. |
| `apps/app/test/academy_screens_test.dart` | Six tests cover closed package state, package-bound content/feedback, real hierarchy routing, Persian RTL, 200% text, and restart-restored completion. |
| `apps/app/test/academy_visual_test.dart` | Three geometry-regression specimens cover compact English home, medium Persian path, and wide English session. Flutter's Ahem test font means these are not typography-fidelity proof. |
| local Web runtime | English and Persian Home → Course → Session → feedback → completion were exercised with no browser warning/error; the exact receipt is recorded in `05-verification.md`. |
| `dart analyze apps/app packages/core packages/services` | Zero issues at the recorded checkpoint. |

## Open Data Plane work

The following concerns remain active or planned and block any capability-level `verified` claim:

1. Migration-chain and downgrade fixtures beyond the now-proven v1↔v2 boundary.
2. Platform-backed encrypted/appropriate storage classification and backup/restore policy.
3. Durable outbox/inbox, authenticated sync, replay, deduplication, and server acknowledgements.
4. Cross-device conflict policy beyond local compare-and-set serialization.
5. Server-authoritative attempt, mastery, retrieval schedule, and reward projections.
6. Consent/privacy lifecycle, export, deletion, retention, and account reconciliation.
7. Real-catalog performance plus on-disk search and offline-pack cache contracts beyond the now-proven bounded in-memory index/cache.
8. Signed/public-key or equivalent release-channel authentication for expected transport/canonical hashes across cold start, plus cross-isolate/process storage arbitration.
8. Privacy-safe observability, failure receipts, recovery telemetry, and support tooling.
9. Production package integration and reviewed Cardiology EN/FA content; the current UI fixture is synthetic only.
10. Keyboard/screen-reader task proof, real compact-device runtime capture, performance profiling, and six-platform smoke evidence.

## Completion boundary

This document proves an implemented local slice and a safe data boundary. It does **not** prove the complete Academy, a medical-content release, cloud synchronization, mastery/reward authority, all accessibility states, all viewports, or six-platform readiness. `synapse.academy.curriculum-path` and `synapse.academy.learning-session` may advance only to `active` in the reviewed capability evidence overlay.
