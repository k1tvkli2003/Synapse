# Academy Deep Study Document Runtime

**Status:** immutable bilingual document/Block runtime, authoritative reveal and semantic resume implemented and targeted-test green  
**Date:** 2026-07-21  
**Priority:** Academy learning core; package-authored reading beside Guided Sessions  
**Content truth:** synthetic non-medical fixture only; no reviewed Harrison-derived medical body is claimed

## Outcome

The Study Workspace no longer stops at objectives and Session launch cards. A
validated curriculum package can now carry one bounded primary Deep Study
document for each published Micro-lesson and render its ordered semantic blocks
inside the same contextual Academy flow.

This is not a chapter-length reader and not a second StudyHUB surface. One
primary document is limited to twelve minutes per locale and twenty-four
blocks. Its job is to create a short, coherent understanding path before the
learner retrieves, discriminates and applies the material in Guided Sessions.

## Package and schema boundary

`CurriculumManifest` now writes schema v2 and continues to read schema v1:

- a v1 package re-emits without invented `studyDocuments` or `studyBlocks`;
- a v1 payload that declares either new field is rejected rather than silently
  ignored;
- a published v2 Micro-lesson requires exactly one `primary_lesson` document;
- internal v2 scaffolds may remain body-free;
- canonical bytes include the new entities only for v2, so installed v1 package
  identity is not rewritten by the reader.

The runtime models are `CurriculumStudyDocument` and
`CurriculumStudyBlock`. Supported first-slice shapes are:

1. prose;
2. key idea;
3. mechanism chain;
4. ordered steps;
5. bullet list;
6. comparison table;
7. clinical pearl;
8. safety warning;
9. worked example;
10. recap.

Shape bounds are data contracts, not renderer conventions: mechanism/step
chains have two to seven units, bullet lists two to five, comparison tables two
to seven rows and two to four columns, and prose/callout/recap shapes remain
short. English and Persian duration estimates must each remain at or below 720
seconds.

## Integrity and answer isolation

Manifest validation closes the following cross-record invariants:

- Document owner is a declared Micro-lesson hierarchy node.
- Document ordinals and Block ordinals are contiguous and match declared order.
- Every Block has exactly one Document owner; orphan, missing, reordered and
  cross-owned Blocks fail closed.
- Document source atoms, claims and concepts are subsets of its Micro-lesson.
- Block provenance is a subset of its Document; every referenced localization
  unit remains within the Block provenance scope.
- Only reading-safe semantic roles can appear in a study Block.
- Option labels, rubrics, why-correct, why-wrong and all feedback localization
  units are answer surfaces and cannot be reused by a study Block.
- An attempt/completion-gated Block names one Session inside the same
  Micro-lesson.

These checks are performed before a learner-visible package can enter the
Catalog. They do not replace medical review, source coverage reconciliation,
rights review or publisher signature authority.

## Catalog and presentation

`CurriculumCatalogSnapshot` now builds immutable, rebuildable indexes for:

- ordered study documents by Micro-lesson node;
- the primary document for one Micro-lesson;
- ordered Blocks by Document;
- privacy-safe aggregate document and Block counts.

The Workspace renders package-localized text only. Its cream evidence-paper
surface is deliberately distinct from midnight navigation and personal tools.
Compact and high-text-scale layouts recompose comparison tables into labeled
row cards; wide layouts retain the table. Mechanism chains, callouts and prose
keep live accessible text rather than flattening instructional content into an
image.

Gated Blocks now read a separate, read-only projection of the exact
release-bound Session checkpoint. A completion gate requires completed state;
an attempt gate requires completed state, a recorded choice, or a passive
advance with a post-start revision. Merely opening a Session or selecting an
option without recording the response is not attempt evidence. Release, node
and Session identities must all match. Loading, corruption and mismatches fail
closed, and gated heading/body localization is not resolved until reveal, so
the UI cannot leak recap/remediation content while checking progress.

Every rendered Block also owns a stable semantic target. Real scrolling
debounces into a separate local-first reading-position registry containing only
IDs, ordinal, approximate permille and provenance. Reopening the document
restores the exact Block; retired anchors fall back to the closest safe ordinal
or permille with visible disclosure. No package body, answer, raw pixel offset,
completion, mastery or reward is stored in this projection.

## Authoring contract

`content-contract.v1.json` now requires `studyDocuments` and `studyBlocks`,
defines the same shape/duration/reveal bounds, and records 100% document,
provenance and answer-isolation gates. JSON Schema covers local shape rules;
runtime Manifest validation remains authoritative for cross-entity ownership,
rectangular table equality, provenance subsets, exactly-one-primary and answer
surface reuse.

Jules or another generator may produce candidates against this contract, but
cannot publish, self-review, invent evidence, weaken EN/FA parity, or bypass the
signed immutable package path.

## Current targeted evidence

- Core: 46 tests pass, including five Deep Study model tests, three reading-position model tests and two v1/v2
  compatibility tests.
- Services: 66 tests pass, including Catalog document/Block indexes,
  published ownership/answer-isolation mutations and five local reading-state tests.
- App Workspace: eight focused tests pass, including exact reveal, no-leak
  failure, automatic save/restore, retired-anchor fallback, corruption recovery
  and Persian RTL at 200% text. Seven Academy geometry goldens remain green.
- Content contract: nine Python tests pass across Deep Study schema and source
  scan behavior.
- Analyzer is clean for Core, Services and the changed Academy surfaces.
- New geometry specimens:
  `academy-deep-study-compact-en.png` and
  `academy-deep-study-wide-en.png`; both were visually inspected.

The 2026-07-22 full-root receipt is also green: 223 tests, zero analyzer issues,
refreshed generated/preservation/architecture contracts, repeatable non-empty
Web output and 15 performance probes with zero warnings. This still does not
upgrade synthetic content or local contract evidence into production proof.

## Open closure order

1. Add universal document/PDF refs, checksummed offline blobs, page/search/zoom
   and accessible equivalents.
2. Add anchored notes/annotations, edit/history/tags, export/delete, indexed
   privacy-ready storage and journaled StudyHUB import.
3. Compile one rights-cleared reviewed Cardiology package, then profile real
   hierarchy search, memory, scrolling, storage and recovery.
4. Close keyboard/screen-reader and real Android/iOS/Windows/macOS/Linux/Web
   runtime evidence before changing the capability to `verified`.
