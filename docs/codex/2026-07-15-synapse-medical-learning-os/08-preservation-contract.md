# Preservation Contract

## Purpose

The rebuild is radical in product experience but additive in operational identity. This contract is the safety boundary that prevents a beautiful redesign from deleting routes, corrupting progress, orphaning user content, weakening policies, or silently abandoning a capability.

## Immutable Until Migrated and Proven

| Contract class | Frozen baseline | Allowed change | Required proof |
|---|---|---|---|
| Source archive | `Synapse-App.rar`, SHA-256 `084ED47D3817253D56E22ADE99318CF2A81465910B5CFF09B366DC2FF9F750F7` | None; reference only | Hash check |
| Module registry | `copilot`, `terms`, `cards`, `mnemonics`, `ecg`, `sounds`, `labs`, `algorithms`, `orLab`, `rounds`, `buddies`, `arena` | Add presentation metadata or adapters; never reuse IDs | Serialization snapshot |
| Shell branches | `home`, `learn`, `clinical`, `social`, `profile` | Labels/layout may become Today/Path/Clinical/Rounds/You | Indexed-stack and deep-link tests |
| Routes | All constants/helpers in `apps/app/lib/router/routes.dart` plus all paths in `router.dart` | New canonical route plus explicit redirect/adapter | Route inventory and deep-link matrix |
| Core identity | Concept, LearnItem, ConceptMastery, Evidence, typed IDs and existing domain model fields | Add versioned fields/envelopes | Archived JSON/database fixtures |
| Events | Existing `SynapseEvent` variants and semantics | Translate into durable envelopes/outbox; keep legacy adapter | Replay and subscriber tests |
| Local persistence | `__synapse_schema` and every discovered SharedPreferences key | Versioned migration only | Before/after fixtures, recovery test |
| Cloud persistence | Existing Supabase migrations, table/column names, policies, functions, triggers | Forward-only migration with compatibility view/RPC if needed | Disposable-project migration + RLS tests |
| StudyHUB database | `nexus_study_database`, schema v17, migration chain 2→17 | Import into unified store only through adapter/archive migration | Fixture migration and parity report |
| StudyHUB stable identity | `remoteId`, `sourceKey`, `contentHash`, `courseId`, composite keys | Namespace/alias through mapping table | Collision and round-trip tests |
| StudyHUB platform contracts | Settings keys, notification IDs, Android migration channel, widget/deep-link keys | Versioned bridge | Native integration tests |
| User files | PDFs, annotations, notes, bookmarks, imports/exports, caches with user value | Move/copy only after checksum and rollback strategy | Byte/hash, count, referential-integrity checks |
| Responsive behavior | Existing compact/expanded access to all reachable functions | Recompose IA, not remove reachability | Task reachability + screenshot matrix |

## Capability Preservation Rule

Every current capability is assigned one of four honest implementation states:

- `operational`: durable behavior and source of truth exist.
- `partial`: meaningful behavior exists but one or more boundaries are local, seed-only, or incomplete.
- `commitment`: a reachable route or UI promise exists but durable behavior does not.
- `retired-by-replacement`: allowed only after a verified successor, migration, redirect, data archive, telemetry window, and explicit decision record exist.

No capability may disappear because it does not deserve a page. The correct response is usually contextual absorption into a lesson, evidence drawer, margin workspace, command action, practice method, profile control, or professional workflow.

## Synapse Capability Spine

| Existing capability | Stable identity | Unified role | Preservation mechanism |
|---|---|---|---|
| Copilot | `ModuleKey.copilot`, `/copilot` | Bounded tutor and workflow assistant with education/reference/clinical modes | Keep route; add mode-aware gateway, provenance, history adapter |
| Terms | `terms`, `/learn/terms` | Terminology and morphology drills inside chapter paths | Legacy route redirects to filtered Path method view |
| Cards | `cards`, `/learn/cards` | Retrieval queue and concept-linked recall clinic | Keep deck/card identities; add curriculum links |
| Mnemonics | `mnemonics` | Learner/community memory hooks and optional lesson power-ups | Preserve creations/collections; add evidence and moderation |
| ECG | `ecg` | Skill lab nodes, deliberate practice, case evidence | Preserve generator/cases/routes; link mastery dimensions |
| Sounds | `sounds` | Auscultation skill lab and audio rounds | Preserve media/quiz routes; add transcript/offline/accessibility |
| Labs | `labs` | Pattern interpretation and longitudinal cases | Preserve rules/reference; enforce ranges and provenance |
| Algorithms | `algorithms` | Decision challenges and clinical pathway practice | Preserve sessions; separate learning simulation from live CDS |
| OR Lab | `orLab` | Narrative surgical lesson arcs and branching simulation | Preserve drama routes; add content governance and progress |
| Rounds | `rounds` | Professional, citation-aware, audio-first learning community | Preserve feed routes; add de-identification/moderation |
| Buddies | `buddies` | Study groups, accountability, peer teaching, ward co-op | Preserve matching/chat intent; add safety and group lifecycle |
| Arena | `arena` | Optional pharmacology/microbiology battle method | Preserve IDs/routes; make rewards mastery-weighted and nonessential |
| Cases | global `/cases` | Longitudinal patient arcs and boss checkpoints | Preserve case IDs; add forks, reflection, transfer checks |
| OSCE | `/clinical/osce` | Skills checkpoints, rubric feedback, practice station plans | Preserve routes; replace keyword-only scoring with governed rubrics |
| Library/drugs/tools | `/library/**` | Contextual Evidence Shelf and Clinical Peek, plus full reference route | Keep all deep links; add provenance/recency/mode boundary |
| Plan/Insights | `/plan`, `/insights` | Today prescription, workload protector, mastery atlas | Preserve routes/data; replace local-only scheduling with unified model |
| Rewards/quests/shop | global routes | Fair learning economy and optional cosmetics | Preserve inventory intent; migrate to server ledger |
| Community/classes/org | social/institutional routes | Cohorts, wards, classrooms, faculty review, grand rounds | Preserve reachability; implement role/tenant/privacy boundaries |
| Admin/create | `/admin`, `/create` | Evidence-gated curriculum studio and publishing pipeline | Preserve routes; require RBAC, separation of duties, audit log |

## Route Compatibility Harness

Before changing navigation:

1. Generate a machine-readable inventory of every `GoRoute`, route constant, typed helper, path parameter, query parameter, and shell branch.
2. Freeze expected route-to-intent snapshots and representative deep-link fixtures.
3. Add new canonical route names without deleting old strings.
4. Map each old route to the same intent, a filtered new surface, or an explicit archive screen with next action.
5. Test cold start, authenticated start, unauthenticated redirect, browser refresh, native deep link, nested back stack, and branch restoration.
6. Prohibit raw route strings in new feature code except the central registry and compatibility table.

## Data Compatibility Harness

Before changing models or storage:

1. Inventory every persisted key, serialized enum value, table, column, index, policy, trigger, RPC, storage bucket, notification ID, widget key, and file naming rule.
2. Capture sanitized fixtures at each known schema version.
3. Test forward migration, repeated migration, interrupted migration, rollback/recovery, and mixed-version sync.
4. Maintain alias tables for source keys and old IDs; never infer identity from mutable titles.
5. Reconcile counts, checksums, foreign keys, user ownership, progress totals, and reward-ledger projections.
6. Retain an export path before destructive or irreversible operations.

## Safety Invariants

- A client cannot grant XP, currency, streak protection, achievements, entitlements, publication approval, or clinical authority.
- An author cannot approve or publish the same medical artifact without a policy-defined independent review.
- An AI draft cannot become published medical content without source, version, date, model/prompt provenance, review, and approval.
- PHI, credentials, API keys, and private notes cannot cross an AI, analytics, social, or logging boundary without explicit policy and redaction.
- An unsegmented or quarantined source item cannot generate permanent mastery, rewards, or public curriculum identity.
- A missing reference or stale/offline state is visible; the UI never fabricates freshness or success.
- A legacy capability that remains partial is labeled honestly and has no fake compliance or cloud-sync claim.

## Removal Gate

A route, model, key, table, asset, or capability may be removed only when all conditions are true:

- A successor or explicit archive intent exists.
- All reachable entry points have a tested redirect or migration.
- User data is migrated or exportable with checksums and rollback.
- Backward compatibility has an agreed support window.
- Telemetry and support evidence show no unresolved use.
- Security, accessibility, localization, and platform owners sign off in the decision record.
- The coordinator records the removal as a deliberate architecture decision.

Until then, the default is additive adaptation.
