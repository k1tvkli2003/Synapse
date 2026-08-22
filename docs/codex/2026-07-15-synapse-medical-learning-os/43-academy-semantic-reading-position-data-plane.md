# Academy Semantic Reading Position Data Plane

**Status:** implemented and targeted-test green; local-first bootstrap only  
**Date:** 2026-07-21  
**Priority:** Academy learning core; automatic Deep Study continuity  
**Medical-content truth:** this projection stores no lesson or patient data

## Outcome

Deep Study now remembers where a learner was reading without confusing reading
with Session completion, mastery or reward. A real scroll settles for 650 ms,
resolves the semantic Block crossing the reading line and writes one bounded
anchor. Reopening the same document in a fresh provider/runtime container
restores that Block automatically.

The behavior is deliberately quiet. Opening a Workspace does not manufacture a
reading record, and a saved place is not presented as progress. A compact
status appears only while saving, after a record exists, or when recovery needs
the learner's attention.

## Identity and ownership

`CurriculumReadingPositionKey` is:

```text
sourceId | microLessonNodeId | documentId
```

Release and locale are not identity dimensions. Stable package-authored Block
and localization-unit IDs can therefore survive a reviewed release or a switch
between English and Persian. The record retains the last release and locale as
provenance so recovery and migration remain observable.

`CurriculumReadingPosition` stores only:

- stable source, Micro-lesson, document and Block IDs;
- one optional localization-unit anchor ID;
- the one-based Block ordinal;
- approximate document position from 0–1000 permille;
- last-read release and locale provenance;
- compare-and-set revision plus UTC create/update timestamps.

It does not store package text, notes, answers, feedback, evidence bodies, raw
pixel offsets, viewport geometry, completion, mastery, XP, currency, streaks,
clinical competence or patient data. Permille is a navigation fallback only.

## Persistence boundary

`LocalCurriculumReadingStateRepository` owns the separate additive key:

```text
__synapse_curriculum_reading_state_v1
```

The key is intentionally separate from both
`__synapse_curriculum_study_workspace_v1` and the release-bound Session
checkpoint registry. An older build can ignore this registry without rewriting
or deleting Notes, Bookmarks, Focus history or Session answers. Removing the UI
also leaves the record intact, making rollback presentation-safe.

Repository guarantees in this slice:

- strict schema, record and derived-integrity validation;
- same-store mutation serialization;
- compare-and-set stale-writer rejection;
- exact retry idempotency;
- non-destructive read/audit failure;
- source-scoped recency listing;
- revision-protected explicit clear;
- privacy-safe errors that never echo content.

SharedPreferences remains a bootstrap adapter, not the final learner-data
plane. Encryption, indexed queries, tombstones, backup, export/delete,
authenticated sync, multi-device conflict policy and cross-process arbitration
remain open before production verification.

## Restore and migration behavior

Restore order is deterministic:

1. match the exact stable Block ID;
2. if retired, use the saved one-based ordinal when it still exists;
3. otherwise map the approximate permille into the new ordered Block list;
4. disclose that the reviewed release changed the saved anchor;
5. keep the original record until a real learner scroll writes a new position.

If the Block survives but its localization-unit anchor changes, the Block still
restores and the same disclosure appears. If the registry is corrupt or a write
fails, the immutable reviewed lesson remains readable, the previous record is
not cleared, and a retry action is available. Motion-Off and platform reduced
motion resolve the restore without animated scrolling.

## Authority separation

- The immutable package owns document order, Block IDs and localized bodies.
- The reading registry owns only learner navigation continuity.
- The Session progress repository owns attempts, choices and completion.
- Reward/mastery services remain the only future authorities for their domains.
- Workspace Notes and Bookmarks keep their existing stable-node repository.

No reader event can reveal a gated Block. Reveal continues to require the exact
release-, node- and Session-bound progress evidence, and gated localization is
not resolved before that proof exists.

## Current evidence

- Three Core model tests prove JSON round-trip, release/locale-independent
  identity, bounds and invalid-input rejection.
- Five Services tests prove restart, idempotency, stale-write rejection,
  release/locale provenance updates, listing/clear and integrity-drift recovery.
- Eight Workspace tests now include automatic semantic save/restore, body and
  answer isolation in the persisted JSON, corrupt-registry non-blocking
  recovery, retired-anchor ordinal fallback and visible disclosure.
- Full Core and Services suites pass at 46 and 66 tests respectively.
- The changed Academy screen and providers pass Flutter analysis with zero
  issues.
- The 2026-07-22 root gate passes 223 tests across ten packages plus refreshed
  architecture, 16-key preservation, generated, release-Web, performance and
  docs gates.

This evidence uses a synthetic non-medical package. It does not prove Harrison
content quality, real-catalog performance, encrypted production storage,
cross-device sync, full accessibility or six-platform runtime behavior.

## Next closure order

1. Introduce canonical resource and text-range/page anchor contracts shared by
   PDFs, lesson Blocks, Notes, Bookmarks and annotations.
2. Move learner artifacts to a versioned indexed/encrypted adapter with a
   migration and rollback fixture from all current local keys.
3. Add authenticated, idempotent sync/outbox behavior with explicit conflicts,
   privacy export/delete and offline recovery.
4. Journal and reconcile legacy StudyHUB reading/bookmark/annotation imports by
   stable aliases without mounting the legacy database as runtime authority.
5. Profile restore, scrolling, storage growth and corruption recovery against a
   rights-cleared real-scale Cardiology package on representative devices.

The capability remains `active`, not `verified`, until those gates close.
