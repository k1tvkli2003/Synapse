# Curriculum Spine, Source Atomization, and Importer Specification

## Architectural Position

The Curriculum Spine is additive. It is not a third app, not a replacement for Synapse engines, and not a raw migration of StudyHUB. The Harrison-like source defines the formal curriculum hierarchy; Synapse remains the concept, practice, SRS, case, event, and gamification system; StudyHUB becomes the contextual learner workspace.

```text
Harrison-like hierarchy          Synapse learning methods          Absorbed workspace capabilities
Course/Chapter/source anchor +   Terms/Cards/ECG/Cases/etc.   +   Reader/Notes/Planner/etc.
            \                         |                           /
             \---------------- Curriculum Spine ----------------/
                                  |
                         Concept + Mastery + Evidence
```

The curriculum itself is not a thirteenth `ModuleKey`. Existing module IDs remain stable learning methods and resource types. Curriculum nodes orchestrate those methods through links and activities.

## Non-Negotiable Invariants

- Existing Synapse migrations `0001`–`0003`, routes, IDs, models, keys, and data stay readable.
- StudyHUB schema v17 is treated as a read-only legacy source during import.
- Migration order is `expand → import → shadow-read → reconcile → activate`.
- No drop, destructive rename, or raw rewrite occurs during absorption.
- The structural scaffold release publishes hierarchy metadata only and remains body-free. Subsequent content releases must follow `content-contract.v1.json`; raw source, generated drafts, and partially reviewed locale variants never become learner-visible.
- Directory ordinals—not mutable titles, hashes, absolute paths, or locale—define source identity.
- A bare `chapterId` is never globally unique.
- TypeScript source files are never executed. If later needed, they are parsed with a strict AST allowlist in a quarantined importer process.
- The client cannot publish a catalog or grant progress/rewards directly.
- English metadata is canonical. Persian metadata is separately statused and reviewed; UI locale and content locale are independent.

## Frozen Source Snapshot

| Metric | Count |
|---|---:|
| Parts / Courses | 20 |
| Chapters | 1,138 |
| Chapters with explicit Lesson directories | 73 |
| Explicit Lessons | 186 |
| Unsegmented Chapters | 1,065 |
| Total files | 4,560 |
| Source size | 211.74 MiB |
| Markdown files | 1,340 |
| TypeScript sidecars | 927 |
| `.png` extensions | 2,263 |
| Actual PNG bytes | 10 |
| JPEG/JFIF bytes carrying `.png` | 2,253 |
| JPG files | 20 |
| SVG files | 8 |
| WebP files | 2 |

### Heading Distribution

- 32 chapter files have no heading.
- 16 have H1 as their shallowest heading.
- 899 have H2 as their shallowest heading.
- 126 have H3 as their shallowest heading.
- 65 have H4 as their shallowest heading.
- 223 chapters have no H2.

Therefore no universal H2 splitter is allowed. Headings may create segmentation candidates only.

### Known Integrity Anomalies

- 3 chapter Markdown files are zero bytes.
- 2 chapter Markdown files are near-empty.
- 7 Lesson directories lack canonical Markdown.
- Sidecar counts are asymmetric: contributors 185; find/enrichment/quiz/summary 184 each; 6 additional Lesson modules are anomalously named and remain unclassified candidates.
- 7 Lesson bodies are byte-identical to their parent Chapter body.
- Part 11 / Chapter 20 and both explicit Lessons share the same body.
- 74 exact-SHA duplicate groups contain 266 files and 192 redundant copies.
- Part indexes preserve count/order but point to a stale historical root.
- 30 absolute paths are at least 260 characters; the maximum is 304.

## Domain Model

```text
CurriculumSource
  └── CurriculumRelease
       └── CurriculumNode(kind=course / source Part)
            └── CurriculumNode(kind=chapter / source Chapter)
                 └── CurriculumNode(kind=unit)
                      └── CurriculumNode(kind=concept_cluster)
                           └── CurriculumNode(kind=micro_lesson)
                                └── Session
                                     └── Interaction
```

Recommended additive tables:

```text
synapse_curriculum_sources
synapse_curriculum_releases
synapse_curriculum_channels
synapse_curriculum_nodes
synapse_curriculum_node_versions
synapse_curriculum_localizations
synapse_curriculum_prerequisites
synapse_curriculum_node_concepts
synapse_curriculum_resource_links
synapse_curriculum_source_aliases
synapse_curriculum_segmentation_candidates

synapse_content_assets
synapse_content_asset_origins
synapse_content_asset_references
synapse_content_documents
synapse_content_import_batches
synapse_content_import_findings
synapse_content_release_manifests

synapse_user_curriculum_progress
synapse_user_activity_attempts
synapse_workspace_documents
synapse_workspace_artifacts
synapse_workspace_anchors
synapse_workspace_annotations
synapse_workspace_tags
synapse_workspace_threads
```

Core node shape:

```sql
create table synapse_curriculum_nodes (
  id uuid primary key,
  source_id uuid not null references synapse_curriculum_sources(id),
  source_key text not null unique,
  parent_id uuid null references synapse_curriculum_nodes(id),
  kind text not null check (kind in
    ('course','chapter','unit','concept_cluster','micro_lesson','checkpoint','boss_case')),
  ordinal integer not null check (ordinal > 0),
  identity_state text not null,
  created_at timestamptz not null default now(),
  retired_at timestamptz null
);
```

Hierarchy constraints:

- Course parent is null.
- Chapter parent is Course.
- Unit parent is Chapter.
- Concept Cluster parent is Unit.
- Micro-lesson parent is Concept Cluster.
- Session and Interaction are versioned delivery records linked to a Micro-lesson rather than unstable source folders.
- Checkpoint parent is Micro-lesson, Unit, Chapter, or Course according to its assessment scope.
- Boss case parent is Chapter or Course.
- `(source_id, parent_id, kind, ordinal)` is unique among active identities.

`node_versions` holds release-specific mutable metadata. Node identity remains stable when title, path, content, localization, or release changes.

## Stable Identity Contract

Use a project-owned fixed UUIDv5 namespace and deterministic source keys:

```text
harrison-sim/course/01
harrison-sim/course/06/chapter/001
harrison-sim/course/06/chapter/001/lesson/001
```

Rules:

- Titles, absolute paths, locale, hashes, and release versions never participate in node identity.
- Renaming a folder title does not change the ID if its ordinal lineage is unchanged.
- Content updates create versions, not identities.
- Progress, rewards, bookmarks, notes, and annotations link to canonical UUIDs.
- A future split/merge creates explicit supersession edges and progress migration; it never silently reuses an old ID.
- Candidate heading IDs may be deterministic for review, but accepted Lessons receive their own permanent editorial identity.

StudyHUB aliases use this composite mapping:

```text
(provider, entity_kind, legacy_id, legacy_scope) → canonical_id
```

For ambiguous chapter identities:

```text
legacy_scope = courseId + chapterId + mode
```

If the course scope is absent and collision is possible, the record is quarantined. The importer never guesses.

## Ingest State Machine

```text
discovered
→ normalized
→ candidate
→ validated
→ approved
→ published

Any stage may move to:
quarantined | rejected | superseded
```

Minimum finding codes:

```text
empty_body
near_empty_body
missing_canonical_markdown
missing_ts_role
unsafe_typescript
invalid_encoding
mime_extension_mismatch
decode_failed
unresolved_reference
ambiguous_reference
path_traversal
identity_collision
exact_byte_duplicate
probable_semantic_duplicate
parent_child_body_duplicate
stale_source_root
long_source_path
```

Each finding records severity, source path, source key if resolved, parser/importer version, evidence, decision, reviewer, and resolution. Quarantine is explicit product data, not a console warning.

## Discovery Pipeline

1. Resolve and record the source root without storing it in runtime locators.
2. Enumerate Part, Chapter, and Lesson directories using ordinal patterns.
3. Reject traversal, symlink escape, invalid ordinal, duplicate ordinal, and ambiguous casing.
4. Cross-check Part indexes for count and order only.
5. Locate canonical Markdown by deterministic filename rules.
6. Record, but do not execute, recognized TypeScript sidecars.
7. Enumerate media and compute byte length, SHA-256, claimed extension, detected MIME, and decode status.
8. Parse Markdown references into a graph without rewriting source files.
9. Emit an immutable scan manifest and findings.
10. Compare exact structural counts to the frozen baseline before an import batch may proceed.

## Media and MIME Pipeline

Magic bytes and successful decode are authoritative; file extension is a claim only.

```text
source bytes
→ sniff
→ decode in bounded worker
→ sanitize if vector
→ canonical encode
→ content-addressed storage
→ provenance link
```

Rules:

- JPEG/JFIF bytes are canonicalized as JPEG while retaining original path, extension, and SHA in provenance.
- Real PNG remains PNG.
- SVG is sanitized; scripts, external references, event handlers, and unsafe constructs are rejected.
- Polyglot/HTML/script payloads and decode failures are quarantined.
- Runtime storage keys are content-addressed and short:

```text
assets/sha256/ab/<canonical-sha256>.jpg
```

- Exact-byte duplicates deduplicate storage only; they do not auto-merge curriculum nodes or references.
- Responsive image variants and decode-size metadata are generated later, outside the scaffold body import.

## Reference Resolution

Audited baseline:

- 2,484 local media references.
- 2,233 strict-relative references resolve.
- 243 resolve only through a known parent fallback.
- 8 remain unresolved.
- 2,219 unique assets are reachable.
- 257 references repeat.
- 74 media files are unreferenced from Markdown.

Resolution order:

1. Strict relative to the document directory.
2. Known parent fallback, recorded as a compatibility repair.
3. Curated manual mapping.
4. Quarantine.

Unreferenced Markdown assets are checked against sidecar graphs before they become `orphan_candidate`. No source file is rewritten; the compiled document applies versioned reference mappings.

## Heading Segmentation Staging

For the 1,065 Chapters without explicit source Lesson directories:

- Create deterministic source atoms and segmentation candidates, not an immediately publishable learner lesson.
- Extract heading candidates with text, level, line range, anchor hash, surrounding context hash, parser-rule version, confidence, and proposed order.
- Present candidates to editorial review with parent document context.
- Allow merge, split, reorder, reject, and custom-boundary decisions.
- Promote only after coverage review assigns stable Unit/Concept Cluster/Micro-lesson identities and the compiled bilingual pack passes the content contract.
- Preserve old candidate provenance without tying progress to candidate identity.

An unsegmented Chapter can be browsed as scaffold metadata while decomposition is pending, but candidate content cannot create permanent completion, mastery, XP, streak credit, or public competence claims. Validated Micro-lessons created from its reviewed atom ledger may do so after activation.

## Immutable Manifest

Every scan produces a manifest like:

```json
{
  "schemaVersion": 1,
  "sourceKey": "harrison-sim",
  "releaseVersion": "2026.07.15-scaffold.1",
  "importerVersion": "<build>",
  "treeSha256": "<hash>",
  "counts": {
    "courses": 20,
    "chapters": 1138,
    "segmentedChapters": 73,
    "lessons": 186,
    "publishedDocuments": 0
  },
  "entries": []
}
```

Entry fields:

```text
source_key
node_id
parent_source_key
kind
ordinal
original_relative_path
short_storage_key
byte_length
original_sha256
canonical_sha256
claimed_extension
detected_mime
content_locale
reference_state
quarantine_state
finding_codes
```

Published releases are immutable. Channel activation changes a pointer:

```text
internal → release_id
beta     → release_id
stable   → release_id
```

Rollback changes the pointer; it does not delete history.

## Localization Model

```sql
create table synapse_curriculum_localizations (
  node_id uuid not null references synapse_curriculum_nodes(id),
  release_id uuid not null references synapse_curriculum_releases(id),
  locale text not null,
  title text not null,
  short_title text null,
  description text null,
  translation_status text not null,
  source_hash text null,
  reviewed_by uuid null,
  reviewed_at timestamptz null,
  primary key (node_id, release_id, locale)
);
```

Rules:

- All scaffold Courses, Chapters, and explicit source Lesson containers receive English metadata derived from directory metadata before body processing.
- Every authored learner-facing semantic unit requires English and Persian in the same atomic task; Persian is native-authored and remains `draft` until native-language and medical review.
- Fallback is `exact locale → language fallback → en`.
- IDs and routes are locale-neutral.
- UI direction derives from UI locale; user/source content direction is independently modeled.
- Existing Persian sidecar content is classified `content_locale=fa`, never mislabeled as English.
- English/Persian search aliases are future resources, not identity fields.

## Synapse Integration

`ContentRepository` becomes a facade without deleting current seed getters:

```text
SeedContentSource
CurriculumMetadataSource
WorkspaceContentSource
CloudContentSource
          ↓
Unified ContentRepository
```

Curriculum nodes do not become a new module enum. Instead:

- A `CurriculumNodeRef` is added to adaptable `LearnItem`/session/context contracts.
- `module` continues to identify the learning method (Terms, Cards, ECG, Cases, and so on).
- `curriculum_resource_links` connects a node to existing resources and routes.
- Existing Terms `Lesson` type is not renamed; the new type is `CurriculumLesson`.
- Headings never create Concepts automatically. Concept candidates enter editorial staging.
- Existing events continue through a compatibility adapter while durable curriculum envelopes are added.

Additive canonical routes:

```text
/learn/courses
/learn/courses/:courseId
/learn/courses/:courseId/chapters/:chapterId
/learn/courses/:courseId/chapters/:chapterId/lessons/:lessonId
/learn/session/:nodeId
```

Existing `/learn/**`, `/clinical/**`, `/social/**`, `/library/**`, global routes, deep links, and widget keys remain valid.

## Durable Event Contract

Example envelope:

```json
{
  "schemaVersion": 1,
  "eventId": "uuidv7",
  "type": "curriculum.activity.completed.v1",
  "actorId": "<user>",
  "deviceId": "<device>",
  "sessionId": "<session>",
  "attemptId": "<attempt>",
  "nodeId": "<node>",
  "contentRevisionId": "<revision>",
  "courseId": "<course>",
  "chapterId": "<chapter>",
  "lessonId": "<lesson>",
  "conceptOutcomes": [],
  "score": 0.85,
  "correct": 17,
  "total": 20,
  "occurredAt": "<instant>",
  "offlineSequence": 42,
  "idempotencyKey": "<key>"
}
```

Initial taxonomy:

```text
curriculum.enrolled.v1
curriculum.node.started.v1
curriculum.activity.answered.v1
curriculum.activity.completed.v1
curriculum.lesson.completed.v1
curriculum.checkpoint.completed.v1
curriculum.boss_case.completed.v1
curriculum.review.scheduled.v1
workspace.document.imported.v1
workspace.annotation.created.v1
workspace.flashcard.created.v1
content.pack.installed.v1
```

Reward path:

```text
validated attempt
→ idempotent durable event
→ versioned server rule
→ atomic reward transaction
→ RewardSummary
→ legacy SynapseEvent projection
```

Suggested idempotency scope:

```text
userId:eventType:attemptId:ruleVersion
```

The client never supplies a trusted XP/currency amount. Downloads, opens, scaffold views, passive time, and unreviewed candidates grant no reward.

## Supabase/RLS Boundary

Canonical catalog:

- Anonymous/authenticated users read only channel-visible published releases/nodes.
- Draft, candidate, rejected, and quarantined data is limited to importer/editor services and authorized staff.
- No client policy permits canonical catalog insertion/update/publication.

User data:

- Progress, attempts, workspace, annotations, and documents are owner-only except explicit controlled collaboration.
- Attempt acceptance and reward projection occur through authoritative RPC/server functions.
- Cross-user reads/writes deny by default.
- Reward ledgers are not client-writable.

Staff identity:

- Do not trust a user-editable profile role for admin/editorial authority.
- Add server-managed staff/tenant memberships and separation-of-duty policies.
- Service credentials remain in importer/Edge Function infrastructure only.

Content security:

- Raw corpus bucket is private.
- Compiled assets use release/hash keys and signed/authenticated delivery.
- Markdown/LaTeX/HTML is sanitized.
- TypeScript is never executed.
- AI payloads are minimized/redacted and never automatically published.

## Offline Packs

```text
packs/<release>/<locale>/<course-id>/index.json
packs/<release>/<locale>/<course-id>/chunk-000.zip
```

Requirements:

- Content-addressed shared blob cache.
- Bounded resumable chunks.
- SHA-256 for manifests and chunks.
- Download to a staging directory; atomically promote only after verification.
- Retain the prior active pack until promotion succeeds.
- Handle disk-full, checksum mismatch, interruption, cancellation, stale manifest, quota, and eviction.
- Keep English fallback packs independent.
- Do not base64-store large PDF/audio/TTS blobs.
- Reading state, annotations, and progress are independent of a pack version.

## Rollout Sequence

1. Freeze Git, route inventory, schema dumps, persistence keys, StudyHUB fixtures, and source manifest.
2. Ratify the Preservation Contract.
3. Add pure-Dart curriculum domain and repository interfaces behind a feature flag.
4. Add forward-only Supabase migrations for source/release/node/localization/RLS.
5. Add progress/workspace/outbox tables additively.
6. Implement the importer and validator outside the runtime client.
7. Run a transaction-rollback scaffold dry run.
8. Import a draft structural release containing exactly 20/1,138/186 source identities plus metadata and zero published bodies.
9. Atomize every source document and media detail, reconcile the coverage ledger, then create quarantined simultaneous English/Persian Cardiology packs through Jules.
10. Shadow-read and compare tree, order, count, identity, and localization parity.
11. Add the unified local cache and read-only StudyHUB importer.
12. Dual-read legacy preferences until reconciliation passes.
13. Connect LearnItem, Concept, session, and event adapters.
14. Add routes without deleting legacy routes.
15. Activate `internal`, test offline packs, then `beta`.
16. Validate source coverage, semantic/numeric/answer parity, evidence, medical safety, accessibility, interaction budgets, and reviewer separation for every content pack.
17. Switch `stable` pointers only after the structural and content acceptance gates pass independently.
18. Consider cleanup only after explicit restore proof and compatibility-window review.

Rollback:

- Disable feature flag.
- Restore the prior active release pointer.
- Keep legacy routes/repositories operational.
- Leave additive migrations in place.
- Revert only records journaled by an import batch.
- Never delete user progress, rewards, workspace artifacts, or source files.

## Acceptance Gates

### Structure

- Exactly 20 Courses, 1,138 Chapters, 73 explicitly segmented Chapters, 186 explicit Lessons, and 1,065 unsegmented Chapters.
- Zero source-key or UUID collisions.
- Continuous ordinal/order checks pass.
- No absolute source root appears in runtime locators.
- Published medical body count is exactly zero in the structural scaffold release; a content release may contain bodies only when its exact hash is `validated` under `content-contract.v1.json`.
- No heading candidate is a live Lesson.

### Corpus Integrity

- All 2,253 JPEG-as-PNG files are correctly classified/canonicalized; all 10 real PNGs remain PNG.
- All 2,484 references are classified; 243 fallbacks are recorded; 8 unresolved references block publication.
- All storage keys meet the length budget.
- All 74 duplicate groups deduplicate bytes without merging identities.
- Empty/near-empty files, missing Lesson Markdown, sidecar gaps, parent-child duplicates, and Part 11/Chapter 20 are quarantined.
- No TypeScript executes.

### Identity and Progress

- Title/path/locale/revision changes do not change node IDs.
- Re-running an import creates no duplicates.
- Offline replay cannot double-reward.
- Later segmentation does not erase or silently reassign progress.
- Bare chapter collision tests pass.

### Localization

- English scaffold metadata coverage is 100%.
- Persian entity/key parity is 100% with explicit review status.
- Fallback is deterministic.
- Locale switching preserves route, selected node, scroll/zoom where applicable, and session state.

### Offline and Platforms

- Checksum mismatch, interrupted download, disk-full, cancellation, eviction, upgrade, and rollback tests pass.
- Web, Android, and Windows cache/path smoke tests run locally when host-ready.
- Apple and Linux tests run on suitable CI hosts.
