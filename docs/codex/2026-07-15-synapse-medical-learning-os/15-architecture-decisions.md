# Architecture Decisions

This file summarizes accepted decisions. Material changes receive a dedicated ADR with context, alternatives, contracts, migration, rollback, security, localization, accessibility, performance, and verification fields.

## ADR Template

Every new material decision uses the following fields. A decision is accepted only when the status, protected contracts, rollback, and verification sections are concrete.

```markdown
## ADR-NNN — Short Decision Title

- Status: proposed | accepted | superseded | retired
- Date: YYYY-MM-DD
- Owners: named domain and verification owners
- Requirement links: R-NNN
- WBS links: WBS-NNN
- Context: observed problem, evidence, constraints, and affected users
- Decision: one unambiguous statement
- Alternatives considered: realistic options and rejection reasons
- Protected contracts: routes, IDs, data, events, files, public behavior, accessibility
- Data and migration: forward path, compatibility window, reconciliation, idempotency
- Rollback: safe trigger, reversible boundary, restoration steps, retained evidence
- Security and privacy: authority, RLS, secrets, PHI, abuse cases, audit
- Localization: locale neutrality, English/Persian behavior, bidi and terminology
- Accessibility: semantic equivalent, focus, input, motion, zoom, assistive tech
- Performance and operations: budgets, observability, deployment, failure mode
- Verification: automated checks, runtime proof, visual proof, reviewer, exit threshold
- Consequences: benefits, costs, new risks, follow-up decisions
```

## Accepted Decision Index

| ADR | Decision | Contract affected | Primary proof |
|---|---|---|---|
| ADR-001 | Additive radical rebuild | All current routes/data/capabilities | Preservation harness and rollback flags |
| ADR-002 | Medical education is the spine | IA, daily loop, curriculum | Today→Path vertical-slice evidence |
| ADR-003 | Preserve shell keys, change labels | Shell restoration/deep links | Legacy-route matrix |
| ADR-004 | Curriculum is not a module | Module IDs and learning graph | Domain/adapter tests |
| ADR-005 | Ordinal UUIDv5 identity | Curriculum progress identity | Golden/property tests |
| ADR-006 | Heading candidates never auto-publish | Lesson identity/reward | Importer quarantine tests |
| ADR-007 | Initial structural scaffold has zero lesson bodies | Phase boundary | Scaffold release assertion |
| ADR-008 | Immutable releases/channel pointers | Curriculum distribution | Release/hash/rollback tests |
| ADR-009 | StudyHUB is read-only legacy | Imported data authority | Dry-run/reconciliation/import tests |
| ADR-010 | Universal resource references | Notes/PDF/curriculum links | Schema constraints/migration fixtures |
| ADR-011 | Durable events, legacy projections | Event contracts/offline | Replay/idempotency/projection tests |
| ADR-012 | Mastery vector, XP projection | Competence claims | Deterministic mastery tests |
| ADR-013 | Server-authoritative reward ledger | Economy/balance/quests | Tamper/replay/reconciliation tests |
| ADR-014 | English source, Persian first-class | All user-visible surfaces | Catalog/RTL/bidi parity matrix |
| ADR-015 | Atlas has semantic outline twin | Navigation/accessibility | State parity and assistive-tech tests |
| ADR-016 | Study and Clinical lenses | Tone/safety/state continuity | Cross-lens workflow tests |
| ADR-017 | Superseded: MCR4-01 primary mascot and ICR4-04 icon | Historical brand decision | Preserved MCR4/ICR4 source/package receipts |
| ADR-018 | Bounded multi-agent continuous execution | Work coordination | Ownership map, integration evidence, state/progress/WBS continuity |
| ADR-019 | Fine-grained bilingual content follows the scaffold | Curriculum content and publication | Atom coverage, EN/FA parity, authoring-policy, safety, and review gates |
| ADR-020 | Curriculum packages use an immutable local registry with atomic channel pointers and receipt-backed recovery | Curriculum distribution, offline boot, rollback, quarantine, local repair | Service repository tests, transport/canonical hashes, activation/recovery receipts, integrity audit |
| ADR-021 | Restore LUMA Character System and ICR2-01 Facefront | Active brand assets and launcher/runtime identity | Locked source hashes, 37 source outputs, 188 package/install records, install-aware verifier |
| ADR-022 | Release-bound local session checkpoints are separate from content and rewards | Academy resume state, responses, completion, future sync | Repository tests, Academy route/restart tests, EN/FA Web runtime |
| ADR-023 | Catalog indexes are bounded, rebuildable, and non-authoritative | Academy hierarchy/search/cache/offline recovery | Scoped EN/FA search, LRU/single-flight/invalidation repository tests |
| ADR-024 | Learner releases require pinned Ed25519 trust or an explicit bundled boundary | Curriculum publication and activation | Trust-envelope, forged-signature, revocation and no-downgrade tests |
| ADR-025 | Study Workspace is stable-node learner state, not a StudyHUB sub-app | Private Notes/Bookmark/Focus and contextual navigation | Repository, route, restart, RTL and geometry tests |
| ADR-026 | Deep Study is an immutable bounded document, not a long reader | Bilingual instructional content runtime | Schema compatibility, provenance, gated-reveal and responsive tests |
| ADR-027 | Reading position uses semantic anchors in a separate additive registry | Academy reading continuity | Core/Services serialization, recovery and Workspace resume tests |
| ADR-028 | Private learner projections migrate to one encrypted indexed authority | Workspace graph, reading position, rollback and scale | 110 Services tests, provider migration proof, secure-key and Web asset gates |

## ADR-001 — Additive Radical Rebuild

- Decision: radically replace presentation and workflows while preserving operational identity through additive models, adapters, redirects, migrations, and archives.
- Why: the user requires both a complete rebuild and zero capability loss.
- Rejected: from-scratch replacement that drops current routes/data; visual reskin that preserves current product fragmentation.
- Consequence: more compatibility work up front, substantially lower data/contract risk.

## ADR-002 — Medical Education Is the Spine

- Decision: curriculum, daily prescription, active sessions, mastery, and transfer own the product’s primary loop.
- Why: the explicit product thesis is a Duolingo-grade medical curriculum; current module cards obscure it.
- Consequence: reference, tools, AI, social, rewards, and workspace capabilities become contextual supporting systems.

## ADR-003 — Preserve Five Shell Keys, Change Presentation Labels

- Decision: keep `home/learn/clinical/social/profile` and current paths; present Today/Path/Clinical/Rounds/You.
- Why: preserves deep links, restoration, and user data while improving job-oriented IA.
- Consequence: aliases redirect to canonical old paths; labels are localized presentation data.

## ADR-004 — Curriculum Is Not a Module

- Decision: keep all 12 `ModuleKey` IDs; add a separate curriculum domain that links existing modules as learning methods/resources.
- Why: curriculum organizes the whole product and should not become a thirteenth tile/silo.
- Consequence: `CurriculumNodeRef` is additive to sessions/resources; module continues to identify practice method.

## ADR-005 — Ordinal UUIDv5 Identity

- Decision: derive canonical node UUIDs from a fixed project namespace and ordinal source keys.
- Why: titles, paths, hashes, locales, and releases are mutable; progress needs stable identity.
- Consequence: rename/revision does not change ID; split/merge requires explicit supersession/migration.

## ADR-006 — Heading Candidates Never Auto-Publish

- Decision: the 1,065 Chapters without explicit source Lesson anchors and the 73 Chapters with them are all atomized under one reviewed pipeline; headings and source directories provide boundary evidence only.
- Why: heading depth is inconsistent, 223 Chapters have no H2, and source Lesson size is far larger than the target micro-session budget.
- Consequence: candidates can aid editors and Jules task planning, but no permanent Unit, Concept Cluster, Micro-lesson, progress, or reward exists before atom coverage and review approval.

## ADR-007 — Initial Scaffold Contains Zero Lesson Bodies

- Decision: initial imports include identity/hierarchy/localized metadata only.
- Why: this isolated hierarchy, identity, routing, and import correctness before medical content production began.
- Consequence: the initial scaffold release asserts zero published documents. ADR-019 governs every subsequent content-bearing release and supersedes any interpretation that content population is permanently out of scope.

## ADR-008 — Immutable Releases and Channel Pointers

- Decision: scan/import releases are immutable; internal/beta/stable channels point at a release.
- Why: enables reproducibility, audit, rollback, and offline pack integrity.
- Consequence: corrections create a new release; rollback moves a pointer rather than deleting data.

## ADR-009 — StudyHUB Is a Read-Only Legacy Source

- Decision: absorb StudyHUB capability-by-capability into unified repositories; never mount its DB as permanent second authority.
- Why: its reader/workspace strengths are valuable, but shared credentials, secrets, schema collisions, and duplicate planner/SRS/XP authority are unsafe.
- Consequence: journaled idempotent import, legacy alias table, count/hash reconciliation, and a compatibility window.

## ADR-010 — Universal Resource References

- Decision: workspace artifacts target either a curriculum node or a document through one validated resource reference.
- Why: StudyHUB relationships are PDF-centric while Synapse must support lesson, document, case, and evidence contexts.
- Consequence: database constraints prevent ambiguous dual ownership; legacy foreign keys remain in import provenance.

## ADR-011 — Durable Events, Legacy Projections

- Decision: add versioned durable event envelopes/outbox and project them to existing in-memory `SynapseEvent` behavior where required.
- Why: the current EventBus has no durable subscribers/replay while existing typed events are protected contracts.
- Consequence: one authoritative event history; legacy UI/modules remain compatible during migration.

## ADR-012 — Mastery Is a Vector, XP Is a Reward Projection

- Decision: store mastery evidence across recall, discrimination, explanation, connection, application, reasoning, procedure, calibration, recency, and transfer.
- Why: a scalar XP cannot represent medical competence and encourages farming.
- Consequence: XP never drives competence claims; learning prescription uses mastery evidence and uncertainty.

## ADR-013 — Server-Authoritative Reward Ledger

- Decision: validated attempts produce idempotent server reward transactions and client-visible projections.
- Why: current client-authoritative economy is exploitable and divergent.
- Consequence: optimistic UI cannot alter balance; offline replay and rule versions are explicit.

## ADR-014 — English Source, Persian First-Class

- Decision: English is canonical; Persian ships with full key parity, RTL, mixed-script isolation, fonts, search aliases, and review status.
- Why: late translation would break layout, search, widgets, notifications, and medical terminology.
- Consequence: locale-neutral IDs; language separated from region/calendar/numerals/timezone.

## ADR-015 — Atlas Canvas Has a Semantic Outline Twin

- Decision: every spatial curriculum view has an equivalent ordered semantic view sharing state.
- Why: custom maps can harm accessibility, keyboard use, performance, and dense professional workflows.
- Consequence: users may choose/automatically receive outline mode without reduced function.

## ADR-016 — Study and Clinical Lenses Share Identity, Not Tone

- Decision: one object/data history supports a warm gameful Study lens and a quiet provenance-led Clinical lens.
- Why: friendliness helps learning; point-of-care contexts require restraint and explicit evidence.
- Consequence: mascots/rewards/shop/leagues suppress in critical Clinical contexts; no duplicate records.

## ADR-017 — Superseded MCR4-01 / ICR4-04 Identity Selection

- Status: superseded by ADR-021.
- Historical decision: MCR4-01 Sidecrest Companion owned the primary coach/character role and ICR4-04 Evidence Guide owned the app-icon composition at this checkpoint. Both direct selections and their deterministic production receipts remain preserved, but neither has current runtime authority.
- Why: the Round-3 anti-tooth work overcorrected into object-like forms. Round 4 restored a full actor with stable head, torso, limbs, gaze, pose, and role range while keeping one asymmetric crest instead of a molar crown. The selected Evidence Guide portrait then adds product meaning through one evidence tile without changing character species.
- Preserved: Night Shift midnight/frost/cyan material, calm humane expression, coach/evidence/quest/recovery jobs, Clinical suppression, original non-copied identity, and one coherent character whose launcher portrait derives from the full-body master.
- Consequence: production lock requires identity-preserving layered masters, optical variants, real raster/mask/launcher proof, blind association testing, no-copy/similarity, linguistic/trademark review, and user-supersession support. The evidence card remains a separable app-icon/role prop rather than part of the mascot anatomy. No secondary mascot enters production without its own role and approval evidence.

## ADR-018 — Bounded Multi-Agent Continuous Execution

- Decision: preserve uninterrupted root-agent ownership while running independent app, source-inventory, atomization, authoring-policy, and validation streams concurrently when this materially improves speed or quality.
- Why: the user explicitly reversed the earlier no-subagent constraint and required parallel application construction plus dataset extraction/authoring.
- Protected contracts: every delegate receives exclusive paths, a bounded deliverable, a verification contract, and no independent authority to upload, publish, push, stage, commit, or mutate user-owned source corpora.
- Consequence: the root agent reconciles every result against current requirements before acceptance; durable docs and deterministic artifacts preserve continuity across compaction and agent boundaries.

## ADR-019 — Fine-Grained Bilingual Content Follows the Scaffold

- Decision: after the body-free structural scaffold, the platform must atomize every meaningful source detail and publish only reviewed English/Persian semantic pairs through `Course → Chapter → Unit → Concept Cluster → Micro-lesson → Session → Interaction`.
- Why: the latest user direction requires complete dataset extraction, simultaneous English/Persian lessons, extremely fine segmentation, and short engaging sessions.
- Authoring boundary: only educational lesson writing, embedded quiz writing, and bounded reinforcement summaries are adapted from StudyHub prompts. There is no separate specialist-writing or `Enrich` stage; enrich-named sidecars are untrusted candidate inputs.
- Protected contracts: source-file and source-atom traceability, no silent detail loss, EN/FA claim/number/unit/answer parity, short-session budgets, current-authority validation for actionable medical claims, independent review, and immutable release receipts.
- Data and migration: existing scaffold node IDs remain stable; approved units, concept clusters, micro-lessons, sessions, and interactions are additive descendants with explicit supersession for split/merge changes.
- Rollback: content-bearing channels can move back to the scaffold or a prior validated release without deleting source inventory, drafts, review history, or learner-owned data.
- Verification: `content-contract.v1.json`, source inventory, atom coverage ledger, bilingual parity checks, medical-safety gates, and project authoring policy must all pass before promotion.

## ADR-020 — Immutable Local Curriculum Package Registry

- Status: accepted
- Date: 2026-07-17
- Owners: curriculum runtime, Data Plane, and service verification
- Requirement links: R-005, R-037, R-052, R-053, R-054
- WBS links: WBS-121–150, WBS-196–225, WBS-371–395
- Context: the pure-Dart curriculum model can validate an immutable manifest but the app still needs an offline repository that cannot overwrite releases, activate an unreviewed learner body, lose rollback history, or hide corruption.
- Decision: store validated canonical manifests in one versioned local registry; keep preview and learner activation pointers separate; require caller-supplied transport and canonical hashes for install/restore plus the observed installed canonical hash as a restore compare-and-swap precondition; make healthy installs and activation idempotent only after decoding stored truth; quarantine invalid candidates by hash/metadata without retaining their raw body; record every pointer change through a durable activation receipt; and repair corrupt/drifted installed bodies only through an explicit trusted-hash restore with a durable recovery receipt.
- Alternatives considered: mutable “current manifest” storage was rejected because it destroys audit/rollback; one pointer for preview and learner was rejected because scaffolds/drafts could leak; raw failed-body retention was rejected because of rights/privacy/storage risk; a second StudyHUB repository was rejected because it creates duplicate authority.
- Protected contracts: stable release/source IDs, exact canonical manifest bytes/hash/metadata, immutable release collision rejection, body-free scaffold not learner-visible, EN/FA publication validation, Preview/Learner pointer identity, activation/rollback/recovery receipts, and preservation keys outside the new registry.
- Data and migration: registry schema starts at v1 under one atomic key. Recovery receipts are a backwards-compatible optional v1 field: a frozen pre-field registry reads losslessly and the field appears on the next mutation. Future incompatible changes still require an explicit schema version, frozen fixtures, migration, and rollback proof. Existing seed repositories remain readable while the curriculum registry is additive. Repository instances sharing one store serialize mutations through one same-isolate queue; cross-isolate/process arbitration remains open.
- Rollback: Learner or Preview rollback moves the pointer to the previous installed release from the verified latest receipt; packages and receipts remain intact. Pointer/latest-receipt disagreement blocks mutation. Registry corruption is reported by integrity audit and never silently reset.
- Security and privacy: failed raw manifests are never persisted; quarantine stores only candidate ID, hashes, byte count, failure code/message, and timestamp. Expected transport/canonical hashes must come from release-channel evidence and cannot safely be derived from the untrusted candidate. Stored bodies must be byte-exact canonical JSON and records must match decoded source/release/channel/lifecycle/scaffold/length/hash truth. Local source roots and credentials are forbidden from distributable manifests. A signed/public-key or equivalent external trust anchor is still required before package authority can be verified across cold start or distribution.
- Localization: package validation uses atomic English/Persian localization contracts; preview can inspect validated scaffolds, while learner activation requires a published manifest.
- Accessibility: repository state has no visual-only semantics; UI must expose activation/download/error/recovery status accessibly when integrated.
- Performance and operations: canonical bytes are stored once per immutable release; active lookup is pointer-based; whole-registry writes provide a clear atomic boundary for the current key-value port. Large content bodies remain separate future pack blobs.
- Verification: 17 package-repository tests cover install/restart/backwards-compatible state, transport/canonical hash mismatch, strict stored bytes/metadata, truthful idempotency, immutable collisions, preview/learner eligibility, activation/rollback chain audit, corrupt-target mutation refusal, recovery receipts, self-consistent drift restore, and shared-store repository concurrency. Architecture tests explicitly allow services to consume pure-Dart foundation ports.
- Consequences: services now depend on `synapse_foundation` for `KeyValueStore`, `Clock`, and `IdSource`. Platform storage remains swappable; no Flutter import crosses the pure-Dart boundary.

## ADR-021 — Restore LUMA Facefront as Active Mascot and App Icon

- Status: accepted
- Date: 2026-07-17
- Owners: Synapse identity, Night Shift UI, multiplatform packaging, and visual verification
- Requirement links: R-013, R-014, R-015, R-052
- WBS links: WBS-081–100, WBS-171–195, WBS-251–275, WBS-396–420
- Context: the user explicitly requested restoration of the earlier mascot and its related app icon after the interim MCR4-01/ICR4-04 selection. Direct user corrections supersede older design decisions. The approved ICR2-01 and LUMA Character System boards remain available with exact hashes; the previously documented dental association remains a real launch risk.
- Decision: ICR2-01 LUMA Facefront and the original LUMA Character System own all active mascot, launcher, and runtime identity surfaces. WMR2-01 remains the wordmark. MCR4-01/ICR4-04 and Foldkin remain reproducible historical packages with no active runtime authority.
- Alternatives considered: retaining MCR4/ICR4 was rejected because it contradicts the latest direct decision; regenerating a new LUMA approximation was rejected because the approved boards are the binding visual source; deleting historical packages was rejected because it would erase provenance and rollback evidence.
- Protected contracts: current `SynapseCompanion`, `SynapseAppIcon`, and pose enum APIs remain source-compatible; package/bundle IDs, routes, persistence, and behavior are unchanged; all platform icons derive from the locked approved source rather than preview labels or regenerated art.
- Data and migration: Flutter switches its declared asset root from `mcr4_companion` to `luma_facefront`; launcher files are replaced in place for Android, iOS, macOS, Web, and Windows, with a Linux hicolor package. Historical source packages remain untouched.
- Rollback: current LUMA outputs are reproducible from two hash-locked boards through `tool/identity/build_luma_facefront.py`; prior MCR4 outputs remain available for forensic comparison but require a new explicit user decision before reactivation.
- Security and privacy: identity assets contain no user data, clinical claims, credentials, or hidden remote dependency. The build is local and deterministic.
- Localization: art contains no flattened user-facing strings. The accessible product/mascot label remains live and locale-owned outside the bitmap.
- Accessibility: decorative appearances stay excluded from semantics; meaningful mascot guidance requires a live semantic label. Reduced/Off motion uses these static pose fallbacks.
- Performance and operations: 16–1024 px optical outputs avoid runtime oversizing; adaptive/monochrome layers stay within the measured safe radius; motion scaling still requires profiler proof.
- Verification: exact source hashes, 37 source outputs, one-component monochrome, 48/24/16 px cues, six pose bounds, 188 platform/package/install records, seven-size ICO, safe-zone checks, and selected installed-byte parity pass in `tool/identity/test_luma_facefront.py --require-install`.
- Consequences: the prior dental/tooth reading is a mandatory blind-association and real-host review gate before public launch. It cannot silently trigger another replacement; any future identity change requires a new recorded user decision.

## ADR-022 — Release-Bound Local Session Checkpoints Are Separate from Content and Rewards

- Status: accepted
- Date: 2026-07-18
- Owners: Academy runtime, curriculum Data Plane, learner-state verification
- Requirement links: R-005, R-037, R-052, R-053, R-054
- WBS links: WBS-196–225, WBS-226–250, WBS-346–395
- Context: the immutable curriculum registry can activate a reviewed package, but the Academy needs restart-safe local progress without copying content bodies into learner storage, reinterpreting an old answer under a changed release, racing stale UI callbacks, or letting a device mint mastery and rewards. A single-package synthetic vertical slice also needs an honest boundary that can later connect to an authoritative event ledger without becoming a second authority.
- Decision: persist one versioned local checkpoint registry keyed by the exact `releaseId|microLessonNodeId|sessionId`; store only opaque stable IDs, choice outcome, UTC timestamps, local compare-and-set revision, and one completion receipt; keep content, free text, mastery, scheduling, and rewards outside this repository.
- Alternatives considered: keying by mutable title/path was rejected because localization and revisions would corrupt identity; writing progress into the immutable manifest was rejected because learner state and published content have different ownership/lifecycle; reusing reward/event state was rejected because it would make local completion authoritative; auto-clearing corrupt state was rejected because it destroys recovery evidence; storing a second imported-app progress database was rejected because Synapse must have one product authority.
- Protected contracts: immutable curriculum releases, stable curriculum IDs, existing routes and persistence keys, no source/raw body in application seeds, no free-text response in the local projection, no client-authoritative XP/currency/mastery, globally unique response/completion receipt IDs, idempotent completion, exact Course ancestor return, localized recovery messages, and preserved corrupt/future state.
- Data and migration: the installed storage slot remains `__synapse_curriculum_session_progress_v1` so an existing key is never renamed or abandoned, while the root document schema is now v2. Frozen v1 fixtures migrate losslessly and atomically to v2; v2 adds a derived record/choice-receipt/completion-receipt count summary and rejects global receipt duplication. That summary detects accidental corruption but is not a cryptographic signature or server authority. Future versions still require explicit fixtures, rollback compatibility, export/delete behavior, and reconciliation evidence; no legacy key may be cleared or repurposed.
- Rollback: presentation and repository wiring are additive. The Academy feature can be disabled without deleting checkpoints. The repository can export a non-mutating v1 rollback snapshot, a failed v1→v2 write leaves the original v1 value unchanged, and unsupported future state fails closed for a compatible recovery build.
- Security and privacy: no patient data, PHI, content body, free-text answer, token, credential, or reward balance is stored. Raw causes are log/support data and never learner copy. A future outbox must authenticate, redact, deduplicate by response/completion receipt ID, and receive server acknowledgement before projecting authoritative outcomes.
- Localization: identity is locale-neutral. Content resolves from the exact package localization unit; Academy chrome maps typed failures to English/Persian copy. Persian RTL does not mirror scientific content implicitly, and a release cannot reinterpret an answer by changing translated text.
- Accessibility: selection, progress, feedback, and completion have semantic equivalents; the compact status chip retains tooltip/semantic meaning; immediate and restored completion use one announcement surface. Keyboard and screen-reader end-to-end platform proof remains open.
- Performance and operations: local mutations and migration reads serialize through one mutation tail and one atomic registry write. The bounded v2 store is suitable for the first slice; large histories require indexed/event storage, compaction, observability, and measured migration before production scale.
- Verification: nine repository tests cover restart persistence, serialized advance/completion/idempotency, stale/conflicting writes, a frozen v1 fixture, lossless v1↔v2 compatibility, failed-write preservation, derived-summary tamper detection, global receipt duplication, and non-destructive future-schema audit. Six Academy widget tests cover hierarchy routing, package-bound feedback, Persian RTL, 200% text, and restart-restored completion. English and Persian Web runtime exercised Home → Course → Session → feedback → completion without browser warnings/errors. The exact boundary and remaining gaps are recorded in `39-academy-session-progress-data-plane.md` and `05-verification.md`.
- Consequences: `synapse.academy.curriculum-path` and `synapse.academy.learning-session` can truthfully remain `active`, but neither is verified. Future migration breadth, sync, backup, conflict resolution, privacy lifecycle, real content, mastery/reward authority, complete accessibility/performance, and six-platform runtime evidence remain separate required work.

## ADR-023 — Catalog Indexes Are Bounded, Rebuildable, and Non-Authoritative

- Status: accepted
- Date: 2026-07-18
- Owners: Academy curriculum runtime, shared Data Plane, performance and recovery verification
- Requirement links: R-005, R-037, R-052, R-053, R-054
- WBS links: WBS-164, WBS-198–203, WBS-339, WBS-375
- Context: the immutable package repository can boot offline, but the initial catalog rebuilt normalized EN/FA strings on every search, cached releases in insertion order rather than true LRU order, had no aggregate node budget, duplicated concurrent builds, allowed undeclared reverse-linked playback content into derived queues, and allowed clear/evict or activation changes to race with an already-running build. Those defects become costly or misleading as Course/Chapter/Micro-lesson counts grow.
- Decision: require exact reciprocal and ordered Micro-lesson→Session→Interaction declarations; precompute immutable hierarchy/search/playback indexes per validated manifest; expose truthful requested/fallback/source-key match origin and stable-node subtree search; retain snapshots only in a two-budget LRU; coalesce same-release builds; remember observed release hashes for same-process drift rejection; expose privacy-safe cache status; use global-clear plus per-release generations (including active-pointer lookup) so pre-recovery builds cannot repopulate the cache; and recheck activation after load so a mid-load channel move cannot return stale content.
- Alternatives considered: persisting the first index format was rejected because migration, quota, encryption, and platform evidence do not yet exist; returning cache entries without re-reading package truth was rejected because corruption could be hidden; unbounded memoization was rejected because future catalog size is unknown; FIFO was rejected because it evicts recently reused Courses; clearing package storage to repair indexes was rejected because derived state must never own user or content truth.
- Protected contracts: immutable release/package identity, activation pointers and receipts, stable node IDs, deterministic order/ranking, English/Persian behavior, no raw corpus body in product seeds, no learner-state coupling, and no new persistence key.
- Data and migration: the index is derived in memory from the current immutable manifest and adds no schema or stored record. Future on-disk indexing requires its own versioned schema, migration, quota, checksum, and rollback evidence.
- Rollback: `evictRelease` or `clearMemoryCache` removes derived state only. The manifest remains installed and can rebuild a snapshot. Epoch invalidation prevents an earlier in-flight build from undoing recovery.
- Security and privacy: cache diagnostics contain release IDs and aggregate counts only. Query text, content bodies, user IDs, progress, answers, PHI, credentials, and rewards are not persisted or emitted. Cache counts are not an analytics pipeline.
- Localization: English/Persian/source-key normalized forms are computed once; Arabic Yeh/Kaf variants, diacritics, ZWNJ, whitespace, and cross-locale fallback preserve current deterministic behavior. Transliteration, abbreviation, typo tolerance, and medical terminology aliases remain open.
- Accessibility: scoped search supports the same ordered semantic hierarchy used by the visual Path; it introduces no canvas-only state. Search UI keyboard/screen-reader proof remains separate.
- Performance and operations: default retention is three releases and 50,000 aggregate logical nodes. Oversized snapshots bypass retention; same-release calls share one build. Targeted eviction does not invalidate unrelated builds; clear invalidates all. Node count is a deterministic safety proxy, not heap-byte or latency proof; full-catalog/device profiling remains required.
- Verification: 22 catalog/runtime tests include exact playback ownership, EN/FA normalization and scoped/source-origin ranking, missing scope, independent LRU release/node budgets, oversized bypass, same-release single-flight/drift rejection, error retry, clear/targeted/active-lookup invalidation, unrelated-build isolation, activation-race retry, target-isolated offline boot, and non-destructive corruption/unsupported-schema states. Targeted Core/Services analysis is clean. Exact evidence and honest limits are in `40-academy-catalog-index-cache.md` and `05-verification.md`.
- Consequences: `indexing_search`, `cache`, and the performance gate for `synapse.academy.curriculum-path` may move only to `active`. Real-catalog scale, on-disk/offline packs, full multilingual search, production telemetry, reviewed content, accessibility, and platform profiling still block `verified`.

## ADR-024 — Learner Releases Require Pinned Ed25519 Trust or an Explicit Bundled Boundary

- Status: accepted
- Date: 2026-07-18
- Owners: curriculum distribution, package registry, security, release truth
- Requirement links: R-005, R-037, R-052, R-053, R-054
- WBS links: WBS-196–225, WBS-371–395, WBS-421–440
- Context: caller-supplied hashes detect transfer/storage drift only when the caller already owns trustworthy release-channel evidence. They cannot authenticate an untrusted remote candidate across cold start, distinguish an unknown publisher, enforce source/channel scope, or revoke a compromised signing key.
- Decision: keep bundled app artifacts as one explicit local trust boundary and add a separate signed-release path. A strict `CurriculumSignedReleaseEnvelope` binds source, release, channel, canonical/transport hashes and byte lengths, signing time, algorithm/domain and pinned key ID. `PinnedEd25519CurriculumReleaseTrustVerifier` accepts only a valid, in-scope, time-valid, non-revoked 32-byte trust anchor and re-verifies signed installed packages during restart audit. Legacy caller-hash records never silently become signed authority.
- Alternatives considered: a hash embedded beside the same download was rejected because an attacker can replace both; TOFU was rejected because first contact is not an adequate medical-content publication authority; one API that ambiguously accepts bundled and remote candidates was rejected because code review could miss the trust downgrade; mutable replacement of an installed body was rejected because release identity is immutable.
- Protected contracts: exact canonical bytes, immutable release identity, target-scoped activation/rollback receipts, non-destructive quarantine, old registry readability, Preview/Learner isolation, and no raw source path or corpus body in trust metadata.
- Data and migration: package records now carry an explicit trust kind and optional signed envelope. Pre-trust v1 records decode as `legacyCallerHashes`; they remain inspectable but cannot become learner authority. A valid signed reinstall of byte-identical bundled content upgrades trust metadata without duplicating or rewriting the canonical body. Signed content cannot be downgraded through the bundled restore path.
- Rollback: channel rollback remains pointer movement among installed releases and re-audits the target package's trust. Revoking a key or removing its policy fails closed without deleting the package, receipts, quarantine metadata, or learner data.
- Security and privacy: Ed25519 verification uses the cross-platform `cryptography` package. Private signing keys never belong in the app or repository. Real publisher-key provisioning, rotation, revocation distribution, threshold/operational signing and secure channel delivery remain mandatory release work; the implemented verifier is not a claim that those production controls exist.
- Verification: six trust tests cover envelope round-trip and restart, forged bytes/signatures, unknown/revoked/out-of-scope/future anchors, policy removal, no downgrade, byte-identical trust upgrade, and pre-trust learner denial. Services analysis passes. Production signing/distribution runtime evidence remains open.
- Consequences: the code path closes the local authentication design gap, but curriculum distribution remains `active`, not `verified`, until a real non-test public key, signer pipeline, rotation/revocation drill and distributed candidate are proven.

## ADR-025 — Study Workspace Is Stable-Node Learner State, Not a StudyHUB Sub-App

- Status: accepted
- Date: 2026-07-18
- Owners: Academy, shared Data Plane, StudyHUB absorption, Night Shift UI
- Requirement links: R-005, R-006, R-009, R-010, R-011, R-057, R-058, R-059
- WBS links: WBS-131–170, WBS-196–250, WBS-276–320
- Context: StudyHUB contains valuable reader, note, bookmark, focus, planner, review, mind-map and document behavior, but copying its route map or database as a visible section would create a second product and duplicate curriculum/progress authority. Binding personal notes to a package release would also orphan them after a reviewed content update.
- Decision: expose one contextual `Study Workspace` from the current Course Path and Session. Key learner material by stable `sourceId|nodeId`, store the last opened release as provenance, and keep published lesson bodies immutable. The initial workspace owns bounded private notes, node bookmark and focus totals; package objectives, sessions and source anchors remain read-only. Compact layouts compose one flow; wide layouts keep lesson and tools side by side.
- Alternatives considered: a top-level StudyHUB tab was rejected as brand/product fragmentation; separate Notes/Pomodoro/PDF dashboards were rejected as page sprawl; release-bound note identity was rejected as data loss; writing learner notes into the manifest was rejected as authority/lifecycle corruption; using focus time as XP/mastery was rejected as unsafe gamification.
- Protected contracts: no legacy user-facing brand, stable curriculum IDs, exact package content, session checkpoints, existing routes/persistence, English/Persian/RTL, no patient-specific guidance, and no implicit corpus/file upload.
- Data and migration: `LocalCurriculumStudyWorkspaceRepository` owns one isolated v1 registry key, strict JSON shape and integrity counts, same-store mutation serialization, compare-and-set revisions, bounded note bodies/count, idempotent latest focus segment and non-destructive corruption errors. It is a storage port, not permanent SharedPreferences authority; encrypted/indexed document storage, export/delete, sync/conflict and journaled StudyHUB import remain open.
- Rollback: the route and provider are additive. Removing the presentation does not delete the registry. A new package release reopens the same stable workspace and preserves notes/bookmark/focus while updating release provenance.
- Security and privacy: notes are learner-authored private data and never become medical authority or analytics. The current local bootstrap store is not claimed encrypted; sensitive-note classification, at-rest protection, authenticated sync and privacy lifecycle must close before production verification.
- Localization and accessibility: UI copy is English/Persian with RTL, note direction follows note locale, controls are semantic, timer success is not speed-dependent, and tests cover Persian at 200% text. Full keyboard/screen-reader/platform evidence remains open.
- Performance and operations: the first registry is intentionally bounded for a vertical slice. Large documents, page annotations, offline blobs, full-text personal search and long focus history require a database/blob adapter and representative scale proof.
- Verification: three core model/repository groups and six repository tests cover serialization, bounds, restart, release upgrade, stale writers/editors, idempotent focus retry, same-store concurrency and corruption privacy. Academy tests cover contextual navigation, Note/Bookmark restart, Focus logging, RTL/200% layout and compact/wide goldens. Exact evidence and remaining gaps are in `41-academy-study-workspace-integration.md` and `05-verification.md`.
- Consequences: Study Workspace is now a real Academy vertical slice and may remain `active`. It is not fully absorbed or `verified` until deep study blocks, documents/PDFs, annotations, legacy migration, planner/Recall links, indexed storage, privacy lifecycle and six-platform runtime proof are complete.

## ADR-026 — Deep Study Is an Immutable Bounded Document, Not a Long Reader

- Status: accepted
- Date: 2026-07-18
- Owners: Academy curriculum runtime, bilingual content contract, Study Workspace and shared Data Plane
- Requirement links: R-005, R-037, R-052, R-053, R-054, R-057, R-058, R-059
- WBS links: WBS-121–170, WBS-196–250, WBS-321–345, WBS-371–395
- Context: the first Study Workspace could show reviewed objectives and launch short Sessions but had no package-owned instructional body. Inventing app-local prose would violate source truth; rendering whole Chapters would recreate fatigue; reusing answer/feedback strings could leak assessment content; and adding new fields to schema v1 without an explicit reader boundary could make old apps ignore new bodies.
- Decision: schema v2 adds immutable `CurriculumStudyDocument` and ordered `CurriculumStudyBlock` entities while retaining strict v1 read/re-emit compatibility. Every published v2 Micro-lesson owns exactly one primary document bounded to twelve minutes per locale and twenty-four semantic Blocks. The first shape grammar is prose, key idea, mechanism chain, ordered steps, bullet list, comparison table, clinical pearl, safety warning, worked example and recap. Documents, Blocks and localization units inherit narrowing provenance from the Micro-lesson. Attempt/completion-gated content names a same-Micro-lesson Session and remains completely hidden until a progress-authoritative join exists.
- Alternatives considered: app-authored placeholder lessons were rejected because application code cannot become medical-content authority; arbitrary Markdown/HTML blobs were rejected because they erase semantic shape, accessibility and answer-isolation guarantees; one giant Chapter reader was rejected because it conflicts with the fatigue budget; copying option/feedback localizations into reading was rejected because it leaks answers; dropping v1 packages or silently ignoring v2 fields was rejected because both break installed-release truth.
- Protected contracts: canonical immutable package bytes, existing v1 package readability, stable Micro-lesson/Session IDs, atomic EN/FA localization, exact source/claim/concept provenance, no answer-surface reuse, no learner edits to published bodies, no patient-specific advice, and no second StudyHUB product authority.
- Data and migration: the current writer emits Manifest v2; the reader accepts v1 and v2 only. v1 omits the new arrays when re-emitted. A v1 payload that declares either array fails explicitly. The Catalog derives in-memory Document/Block indexes and adds no learner key. Future schema changes still require frozen fixtures, migration, canonical-hash and rollback proof.
- Rollback: an installed v1 package remains readable and byte-shape stable. A channel may move back to a prior validated release without deleting learner notes/progress. Removing the renderer does not mutate packages; unsupported/future schema remains a non-destructive recovery state.
- Security and privacy: answer/feedback/rubric localizations are denied inside study Blocks; provenance must narrow at every layer; source paths and raw corpus files remain undistributable; learner notes stay in their separate repository. Real medical bodies still require review, rights and signed publisher authority.
- Localization and accessibility: every displayed unit is the reviewed EN/FA pair from the active package. Compact/RTL/high-text-scale layouts recompose semantic tables without deleting meaning. Instructional text stays live. Gated headings and bodies are not previewed. Full keyboard/screen-reader/device proof remains open.
- Performance and operations: Document and Block counts are bounded; Catalog indexes are rebuildable and non-authoritative. The synthetic geometry is safe at compact/wide and Persian 200% text, but real-catalog heap, scroll/frame pacing and offline-pack size remain unproven.
- Verification: 42 Core, 61 Services and 32 App targeted tests pass; seven Academy geometry goldens pass; the Deep Study content-contract/source-scan suite passes nine Python tests. Exact implementation and open limits are recorded in `42-academy-deep-study-document-runtime.md` and `05-verification.md`.
- Consequences: package-authored Deep Study may remain `active`, not `verified`. Session-authoritative reveal and semantic reading position are now implemented; PDF/offline blobs, annotations, indexed privacy storage, journaled legacy import, reviewed Cardiology content, production signing and six-platform runtime proof remain mandatory.

## ADR-027 — Reading Position Uses Semantic Anchors in a Separate Additive Registry

- Status: accepted
- Date: 2026-07-21
- Owners: Academy Study Workspace, shared Data Plane, learner-data migration and privacy
- Requirement links: R-005, R-006, R-009, R-037, R-052, R-053, R-054, R-057, R-058, R-059
- WBS links: WBS-131–170, WBS-196–250, WBS-276–320, WBS-371–395
- Context: Deep Study needs automatic continuity, but raw scroll offsets are viewport-dependent, release-bound identity would orphan learners after reviewed updates, writing into Session checkpoints would reinterpret reading as performance, and copying text into local state would duplicate immutable medical content. The existing Workspace v1 registry also needs a rollback-safe boundary while its Notes/Bookmark/Focus contract remains stable.
- Decision: persist one semantic reading-position projection keyed by `sourceId|microLessonNodeId|documentId` under the additive `__synapse_curriculum_reading_state_v1` key. Store stable Block/localization-unit IDs, ordinal, approximate document permille, release/locale provenance, revision and UTC timestamps only. Debounce actual scrolling; do not create a record on view. Restore exact Block identity first, then ordinal/permille with explicit disclosure when an authoring revision retires the anchor.
- Alternatives considered: raw pixels were rejected because layout, text scale, device and locale change them; package-release identity was rejected because it strands stable learner continuity; Session progress was rejected because reading is not attempt/completion evidence; Workspace v1 mutation was rejected because it expands an established rollback surface; copied headings/body snippets were rejected because they create stale content/privacy/search authority; silently clearing missing anchors was rejected because it destroys migration evidence.
- Protected contracts: immutable package bodies, exact progress/reveal authority, existing Workspace and Session keys, stable curriculum IDs, English/Persian switching, no learner reward/mastery claim, no patient data, no user-facing legacy brand and non-destructive rollback.
- Data and migration: registry schema starts at v1 with a derived record-count and permille-total integrity summary. Old builds ignore the additive key. Future indexed/encrypted storage must import this registry transactionally, retain a rollback snapshot, and prove count/hash/identity reconciliation before promotion. StudyHUB import maps through stable aliases and a journal; its database never becomes live authority.
- Rollback: removing the reader wiring does not mutate or delete any learner registry. Corrupt or unsupported reading state fails independently while the reviewed lesson, Workspace material and Session checkpoints remain available. A missing Block remains recorded until real user scrolling safely advances it.
- Security and privacy: no package text, notes, answer/feedback body, raw corpus path, PHI, credential, reward, mastery or clinical claim is stored or logged. Current SharedPreferences storage is not claimed encrypted; production privacy lifecycle, export/delete and authenticated sync remain mandatory.
- Localization and accessibility: identity is locale-neutral; the last locale is provenance only. Restore targets a semantic live-text Block in both LTR and RTL. Motion-Off resolves immediately, and errors/moved anchors have live semantic notices. Keyboard and screen-reader platform proof remains open.
- Performance and operations: the record is bounded and scroll writes settle after 650 ms. Exact retries are idempotent, stale writers fail compare-and-set and same-store mutations serialize. Permille is a navigation hint, never a completion percentage. Real-catalog/device frame pacing and cross-process arbitration remain open.
- Verification: three Core, five Services and three dedicated Workspace behaviors cover round-trip/bounds, restart/idempotency/stale state, body isolation, corruption recovery, automatic fresh-container resume and retired-anchor fallback. The complete current evidence and limits are in `43-academy-semantic-reading-position-data-plane.md`.
- Consequences: semantic reading continuity may remain `active`, not `verified`. PDF/page/text-range anchors, indexed encrypted storage, journaled legacy migration, sync/conflict, privacy lifecycle, reviewed real content and six-platform runtime proof remain required.

## ADR-028 — Private Learner Projections Migrate to One Encrypted Indexed Authority

- Status: accepted
- Date: 2026-07-23
- Owners: Academy Study Workspace, shared learner Data Plane, privacy, migration and CI verification
- Requirement links: R-005, R-006, R-009, R-037, R-052, R-053, R-054, R-057, R-058, R-059
- WBS links: WBS-131–170, WBS-276–320, WBS-346–395, WBS-421–440
- Context: the contextual PDF/annotation graph and semantic reading positions had correct bounded contracts but remained separate SharedPreferences JSON registries. Scaling them would expose clear learner-authored material, truncate naïve 500-record scans, make crash recovery ambiguous and risk turning legacy and indexed stores into simultaneous authorities. Drift Web also depended on unverified worker/WASM bytes, and the repository had no CI workflow that exercised the complete product gate.
- Decision: use one Drift/SQLite private-record store with AES-256-GCM payloads, authenticated metadata and HMAC-SHA256 opaque identity/scope indexes; project Workspace and reading state through isolated namespaces; migrate deterministic legacy snapshots through a durable journal and bounded idempotent coordinator; promote exactly one migration-aware repository authority; retain legacy bytes for explicit verified rollback; use opaque keyset pagination; and gate the exact Web runtime assets plus complete workspace verification in a least-privilege SHA-pinned GitHub Actions workflow.
- Alternatives considered: clear SQLite columns were rejected because learner-authored notes/annotations and stable source identity are private; encrypting one monolithic JSON blob was rejected because it prevents bounded indexed queries and atomic record repair; dual-writing during migration was rejected because divergence makes rollback and conflict ownership ambiguous; deleting legacy keys on first success was rejected because it destroys rollback evidence; timing out a non-cancellable database migration into fallback was rejected because it can produce background writes after authority switches; CI release/deploy workflows were rejected until signing lineage, channels and platform evidence exist.
- Protected contracts: all existing persistence keys and exact JSON rollback shapes, stable resource/document/anchor IDs, immutable curriculum bodies, Session progress and reward authority separation, English/Persian behavior, no learner data/corpus/key in CI artifacts, application identifiers and signing lineage, and non-destructive corrupt-state evidence.
- Data and migration: `synapse_learner_v1` stores operational metadata plus encrypted records. The versioned secure root key stays outside the database. Migration journals bind a source snapshot hash, cursor and counts; import is chunked, compare-and-set and restart-safe. Promotion requires destination reconstruction/audit. Success uses Indexed only; failure uses Legacy only. Explicit quiesced rollback exports the current Indexed projection into legacy format and verifies parity before the journal becomes rolled back. Legacy keys are retained; this ADR authorizes no retirement.
- Rollback: presentation can be disabled independently. A migration failure never deletes or partially activates source state. Completed migrations retain source JSON and support a verified reverse export. Corrupt encrypted rows and journals remain for recovery evidence. CI is additive and read-only; removing it does not change runtime data or release channels.
- Security and privacy: payloads use AES-256-GCM; associated data binds namespace, opaque indexes, revision, tombstone and timestamps. HMAC-SHA256 hides record/scope identities. Secure-vault reads/writes are bounded and fail closed; key material is excluded from database, logs, exports and analytics. Real platform-vault hardening, key rotation, backup/restore, authenticated sync, user export/delete and cryptographic-erasure proof remain open.
- Localization: records use stable locale-neutral identity; locale is bounded provenance where required. No localized content body is copied into the reading projection, and the migration does not reinterpret English/Persian data.
- Accessibility: storage migration is presentation-neutral. Existing semantic Reader/Workspace controls, RTL and 200%-text behavior remain protected; real assistive-technology target proof remains open.
- Performance and operations: private writes are transactional; batches are bounded to 500; opaque keyset pages cover more than 500 records without loss or duplication. Drift native uses application support storage and cross-isolate sharing; Web uses explicitly hashed SQLite WASM and worker assets. Real-scale heap/latency/storage-pressure and cross-process/platform measurements remain required.
- Verification: the complete Services suite passes 110 tests, including 503-record tied-timestamp pagination and projection reconciliation. App provider proof covers exact migration, retained rollback JSON, completed journal and Indexed-only post-activation writes. Secure key tests cover concurrency, corruption, timeout and retry. Reader/Workspace suites prove explicit Legacy fallback separately. The generated gate validates lock versions and exact Web runtime bytes. Workflow YAML parses locally but has not been committed, pushed or observed on GitHub-hosted runners. Full evidence and open limits are in `45-academy-indexed-private-data-plane-and-quality-ci.md` and `05-verification.md`.
- Consequences: the first Academy private-data transition can remain `active`, not `verified`. Privacy lifecycle, StudyHUB import, sync/conflicts, large-scale proof, real target vault/database behavior, observed CI and all release/signing/deployment gates remain separate required work.
