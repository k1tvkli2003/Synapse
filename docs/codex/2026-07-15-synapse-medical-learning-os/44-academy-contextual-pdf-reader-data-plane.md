# Academy Contextual PDF Reader Data Plane

**Status:** implemented and targeted-test green; production Data Plane migration remains open  
**Date:** 2026-07-22  
**Priority:** Academy learning core; contextual Deep Study references  
**Medical-content truth:** no Harrison-like body text was copied, generated, uploaded or published in this slice

## Outcome

Academy lessons can now own exact, explicit links to private PDF references and
open them inside one coherent Synapse Study Workspace. The product no longer
needs a parallel document brand or a generic library detour for the learner's
current source. The same full-screen Reader works from content-addressed bytes
on Web and content-addressed files on native targets.

The Reader provides:

- real PDF rendering with page navigation, direct page choice, zoom and fit;
- document-wide text search with previous/next match navigation;
- automatic page resume that is explicitly separate from mastery and rewards;
- page bookmarks and private page comments;
- selected-text highlights anchored by page offsets and a normalized-text hash;
- normalized freehand ink that remains stable across viewport sizes;
- a page artifact sheet with explicit tombstone deletion;
- English and Persian copy/direction, compact layouts and reduced-motion paths;
- forced PDF text semantics plus explicit screen-reader labels for icon-only
  and compact controls.

Importing or reading a document cannot award XP, advance a Session, reveal a
gated lesson Block, claim clinical competence or alter immutable curriculum.

## Context and identity

An Academy source attachment is an explicit
`ResourceCrossReferenceKind.supportingDocument` edge:

```text
curriculum node resource -> document resource
```

The Sources surface queries only those edges for the current Micro-lesson. It
does not present every private document as context. Detaching tombstones the
edge while retaining the PDF, reading place, bookmark, comments, highlights
and ink. That makes accidental detach reversible without manufacturing a
second authority.

PDF metadata uses a stable `ResourceDocumentId` and SHA-256 content address.
Raw native paths, browser blobs, base64 payloads and copied highlighted text do
not enter the metadata registries. Native paths exist only in an ephemeral
viewer handle; Web bytes exist only at the blob boundary.

## Storage boundaries

The implementation deliberately separates four concerns:

| Concern | Current owner | Contract |
|---|---|---|
| PDF bytes | native content-addressed filesystem / Web IndexedDB | SHA-256 keyed, deduplicated, validated PDF only |
| document metadata and cross-references | `LocalResourceWorkspaceRepository` | no raw bytes or device path |
| bookmarks, comments, highlights and ink | universal resource artifact registry | stable anchors, revisions and tombstones |
| page resume | `LocalResourceDocumentReadingStateRepository` | separate additive key; navigation only |

The additive reading key is:

```text
__synapse_resource_document_reading_state_v1
```

It stores document identity/digest, one-based page, page count, normalized
in-page offset, revision and timestamps. It stores no PDF body, selected text,
answer, score, completion, mastery, XP, currency or streak state.

SharedPreferences remains a bounded bootstrap registry for metadata and
artifacts. It is not the final indexed/encrypted learner Data Plane. The PDF
payload itself is already outside SharedPreferences: native app-support storage
uses a two-character SHA shard, while Web uses an IndexedDB object store.

## Anchor and artifact contracts

- `DocumentPageRangeResourceAnchor` owns a one-page or bounded page range.
- `DocumentTextRangeResourceAnchor` owns page-local start/end text offsets and
  the SHA-256 of normalized selected text.
- `DocumentRegionResourceAnchor` owns a page-local normalized region.
- `ResourceInkStroke` owns bounded millionth-coordinate points, width, color
  and opacity without retaining viewport pixels.
- `ResourceAnnotation`, `ResourceBookmark` and `ResourceCrossReference` use
  revisions, deterministic identity rules and tombstones rather than destructive
  removal.

Persisted text highlights are rehydrated from the current PDF text layer. The
Reader recomputes the normalized-text digest and skips a range when the source
drifts. It never writes the selected source sentence into learner storage.

## Integrity and failure behavior

Before publication of metadata, import validates size, `%PDF-` header, parseable
page count, SHA-256 and durable blob placement. Reimporting identical bytes is
idempotent and reuses the existing document record and exact contextual edge.

Native and Web resolve paths both verify byte length, PDF header and digest.
The native integration test additionally mutates a stored file without changing
its length; verification returns `digest_mismatch`, and resolve refuses the
blob with a privacy-safe error that contains no local path. Missing metadata,
missing private bytes and corrupt/unavailable source are distinct learner
states. No fallback document or fabricated evidence is substituted.

## Accessibility and responsive behavior

The Reader uses its Academy locale as the direction authority and keeps numeric
page counters LTR. Icon-only controls expose explicit localized semantics even
when visually disabled, and compact previous/next/zoom controls share the same
contract. The PDF text layer is forced into semantics. A Persian 390×844 test
at 200% text scale reaches the real PDF toolbar without overflow or exception
and confirms the localized Search semantic label.

Full, Reduced and Off motion behavior remains governed by the existing Synapse
motion preference. Reader zoom, restore and navigation durations collapse when
reduced motion is requested. Ink and search do not rely on celebratory motion.

## Current evidence

- `academy_resource_document_screen_test.dart`: four passing widget tests for
  missing metadata, missing private blob, a real one-page in-memory PDF, and
  Persian compact 200%-text/semantics behavior.
- `resource_document_blob_store_io_test.dart`: two passing disk integration
  tests for content addressing, deduplication, real PDF page parsing, resolve,
  verification and same-length digest drift refusal.
- `resource_document_import_service_test.dart`: two passing import boundary
  tests for metadata/cross-reference publication, dedupe and display-name
  sanitation.
- `academy_study_workspace_test.dart`: contextual Sources coverage verifies an
  unrelated document is excluded and detach preserves the private document
  while tombstoning only the lesson edge.
- Core/Services targeted suites prove resource model round trips, bounded ink,
  repository restart behavior, compare-and-set mutations and corruption audit.
- Flutter analysis is clean for the Reader, native store and their tests.
- Fresh preservation generation/check and all 31 semantic checks pass with 142
  route declarations, 150 concrete routes, 91 helpers, 45 enums, 18 persistence
  keys, 450 deep-link fixtures and 76 preserved capabilities.

These are source, widget and host-test proofs. They are not physical-device,
large-PDF, assistive-technology, backup, encryption or six-platform release
proof.

## Open production gates

1. Move metadata, reading positions and artifacts into a versioned indexed and
   encrypted adapter with an exact rollback fixture for all current local keys.
2. Add export/delete, backup eligibility, authenticated sync/outbox, conflict
   semantics and cross-process arbitration without making sync the local truth.
3. Journal legacy StudyHUB document, bookmark, highlight and note import through
   stable aliases; never mount its database as a second runtime authority.
4. Add large/complex/encrypted/malformed PDF fixtures, storage-pressure recovery,
   keyboard/focus traversal and real screen-reader checks.
5. Profile import hashing, first-page latency, search, highlight hydration,
   memory and ink frame pacing on representative Android, iOS, Windows, macOS,
   Linux and Web devices.
6. Exercise private backup/restore and deletion semantics on each platform,
   then run a fresh browser/native Academy journey.

The Reader capability remains `active`, not `verified`, until these gates and
the final `$perfect` convergence are complete.
