# Academy Study Workspace Integration

**Status:** contextual Workspace, immutable Deep Study, progress-authoritative reveal and semantic reading resume implemented; PDFs, annotations, legacy import, indexed/encrypted storage, sync and full privacy lifecycle remain open  
**Date:** 2026-07-21  
**Priority:** learning-core execution override (~90% of current product effort)  
**Product authority:** Synapse only; `StudyHUB` is repository provenance and never learner-facing product language

## Outcome

Academy now has two connected learning surfaces rather than two adjacent apps:

1. **Guided Path** owns Course → Chapter → Unit → Concept Cluster → Micro-lesson → Session → Interaction.
2. **Study Workspace** owns deeper understanding and learner-authored work in the exact active curriculum context.

Course Path exposes `Open study workspace` for its next Micro-lesson. The
Session top bar exposes the same context without changing the package, node,
locale or progress identity. On wide screens the reviewed lesson context and
tools remain visible side-by-side. Compact screens use one scrollable flow and
do not create separate Notes, Focus or Sources pages.

The implementation displays only information that exists in the active
validated package: hierarchy lineage, localized objectives, a bounded primary
Deep Study document with ordered semantic blocks, Session metadata and
source-anchor provenance. It does not fabricate a citation, PDF, answer or
clinical claim. Attempt/completion-gated block bodies remain unresolved and
hidden unless the exact release-, node- and Session-bound progress record
proves the required attempt or completion.

## Capability absorption map

| Legacy source capability | Canonical Synapse placement | Current authority/state | Next closure |
|---|---|---|---|
| Course/lesson reader | Main Study Workspace pane beside Guided Path | Immutable bilingual bounded document/Block runtime, progress-authoritative reveal, semantic anchors and responsive renderer implemented | Real reviewed content and scale proof |
| PDF reader | Contextual Sources pane | Provenance/source anchors shown; full attachment explicitly unavailable | Universal resource refs, offline blob store, page/search/zoom/selection |
| Smart notes | Personal Notes tool in current node | Implemented, bounded, restart-safe, EN/FA direction-aware | Edit UI, anchors, tags, full-text search, export/delete, encrypted/indexed adapter |
| PDF/lesson bookmarks | Bookmark on current curriculum node | Implemented and restart-safe | Section/page anchors and canonical cross-resource bookmark list |
| Reading position | Automatic semantic resume inside the active Deep Study document | Separate block/localization-unit checkpoint implemented with release/locale provenance and safe ordinal fallback | Indexed storage, cross-device sync and journaled legacy mapping |
| Lesson/PDF annotations | Inline/Source annotations | Not active; no false placeholder | Section/text-range/page anchors, drawing data, conflict strategy |
| Pomodoro | Calm Focus tool inside current lesson | Implemented private timer aggregate; pause saves elapsed time | Lifecycle-resumable active timer, richer recovery, database history, optional widgets |
| Planner/tasks | Today/Plan prescription referencing curriculum nodes | Preserved elsewhere; not yet joined here | Add contextual `Plan this lesson` action and canonical task/resource ref |
| Review/SRS | Canonical Recall from actual curriculum performance | Preserved elsewhere; not duplicated | Send reviewed interaction evidence to Recall scheduling authority |
| Mind map | Concept Map generated from current node/concept IDs | Preserved capability, not yet joined | Contextual inspector/outline with semantic twin |
| AI jobs | Secure background work from current source/note context | Not exposed in this slice | Consent, redaction, citation, cancel/resume, review quarantine |
| Course/Lesson cache | Immutable package registry + rebuildable catalog index | Implemented package/index boundary | Real catalog scale, content-addressed offline packs and quota/eviction |
| Legacy achievements | Canonical reward event mappings | Explicitly outside workspace authority | Migration aliases and server-authoritative one-time grants |

No source route, screen title, database table name or repository brand becomes
user-facing IA. Capability migration is by job and data contract.

## Data ownership

### Immutable package authority

- localized objectives and titles;
- Micro-lesson and Session structure;
- source-atom references and curriculum source keys;
- interaction bodies, answers and reviewed feedback;
- release/channel/signature metadata.

### Learner-owned local authority

- personal note bodies and their authoring locale;
- node bookmark;
- private focus-time aggregate;
- last opened release provenance;
- local compare-and-set revision.

The separate reading-position authority stores only stable source, node,
document, Block and localization-unit IDs, Block ordinal, approximate document
permille, last locale/release provenance and revision/timestamps. It never
copies package text or implies completion, mastery, reward or competence.

### Separate existing authorities

- Session answers, attempt evidence and completion receipts remain in the release-bound progress repository;
- XP, mastery, streaks and rewards remain outside this repository;
- planner, Recall, documents, AI jobs and sync remain separate canonical services until their explicit joins land.

The workspace key is `sourceId|nodeId`. Release ID is intentionally not part
of learner identity because curriculum nodes derive from stable source
ordinals. Opening a later reviewed release updates provenance and revision but
preserves notes, bookmark and focus totals.

## Local registry contract

`LocalCurriculumStudyWorkspaceRepository` currently provides:

- one isolated persistence key: `__synapse_curriculum_study_workspace_v1`;
- strict schema/root/record/key validation;
- derived record/note/focus-count integrity summary;
- same-store same-isolate mutation serialization;
- monotonic workspace and note compare-and-set revisions;
- 20,000-character note-body and 100-note-per-node bounds;
- newline normalization without changing published content;
- latest-focus-segment idempotency and conflict detection;
- privacy-safe integrity issues that never echo note text;
- non-destructive failures: package/progress repair cannot clear workspace data.

This is a first cross-platform bootstrap adapter, not the final personal-content
database. SharedPreferences is not claimed to provide encryption, large
document scale, relational indexes, full-text search, tombstones, backup,
export/delete, sync or conflict resolution. Those are explicit blockers before
the capability can become `verified`.

`LocalCurriculumReadingStateRepository` owns the additive
`__synapse_curriculum_reading_state_v1` registry. Its identity is
`sourceId|microLessonNodeId|documentId`, deliberately independent of release
and locale so stable semantic Blocks survive a reviewed release or language
switch. Writes are debounced from real scrolling, idempotent, serialized and
compare-and-set protected. On restore, an exact Block is preferred; if an
author deleted or split that anchor, the learner is moved to the closest safe
ordinal/permille Block and sees an explicit notice. Corruption or write failure
never blocks the immutable lesson and never clears the last good record.

## Interaction and visual contract

- Night Shift midnight/frost/cyan remains the visual authority.
- Restored LUMA appears as a calm study guide, not a decorative dashboard mascot.
- One cream evidence-paper surface distinguishes learner synthesis from published package panels.
- Notes, Focus and Sources are tabs/panes inside the sustained study job, not global pages.
- Bookmark remains in the top context bar and follows the stable node.
- Focus time is explicitly not XP, mastery, streak or clinical competence.
- Sources explicitly state the education-only boundary and current PDF/annotation limitation.
- Motion uses `AnimatedSwitcher` only when system motion is allowed; disabled animation resolves instantly.
- English/Persian strings are paired in the surface; note text direction follows its authoring locale.

## Current evidence

Targeted current-state evidence after implementation:

- Core workspace models: three tests pass (round-trip/stable identity, invalid aggregate/duplicate rejection, body bound).
- Services workspace repository: six tests pass (restart, release upgrade, stale writers/editors, focus idempotency/conflict, same-store concurrency, integrity privacy).
- Reading-position Core/Services: three model tests and five repository tests pass, including locale/release-stable identity, restart, idempotency, stale-writer rejection, integrity drift and body isolation.
- App Workspace: eight behavior tests pass, including Note/Bookmark restart, exact gated reveal, corrupt-progress fail-closed behavior, Focus log, automatic semantic save/restore, corrupt reading-state recovery, retired-anchor fallback and Persian RTL at 200% text.
- Academy navigation: seven tests pass, including Course Path → Study Workspace → Course Path.
- Academy visual suite: seven goldens pass, including compact/wide Workspace and dedicated compact/wide Deep Study specimens.
- Core/Services Deep Study and Data Plane pass inside the current 46-Core/66-Services suites.
- `dart analyze packages/core packages/services` and `flutter analyze` in `apps/app` report zero issues.
- The 2026-07-22 root gate passes 223 tests across ten packages, refreshed architecture/preservation/generated receipts, a repeatable non-empty release Web build and 15 performance probes with zero warnings.

These tests use a synthetic, explicitly non-medical package. They prove the
contract and presentation states, not medical content quality, real-corpus
coverage, platform packaging, font fidelity, physical-device accessibility,
performance at Harrison scale or production privacy.

## Next learning-core implementation order

1. Implement universal document/PDF resource references, local file/blob ownership, checksum promotion, offline quota and reader lifecycle.
2. Add anchored Notes edit/version history, tags, text-range/page annotations, full-text EN/FA search, export/delete and an indexed/encrypted adapter.
3. Build journaled, idempotent StudyHUB import with legacy aliases, count/hash reconciliation and rollback; never mount its database as authority.
4. Join contextual Plan, Recall and Concept Map actions to their canonical repositories.
5. Exercise a rights-cleared real-scale Cardiology hierarchy/package and profile memory, search, scroll/frame pacing and storage growth.
6. Run keyboard, screen-reader, touch/pointer, Full/Reduced/Off motion and real six-platform runtime gates.

Until these close, the Workspace is a meaningful implemented vertical slice
and remains `active`; it is not a complete StudyHUB absorption or production-ready medical-content reader.
