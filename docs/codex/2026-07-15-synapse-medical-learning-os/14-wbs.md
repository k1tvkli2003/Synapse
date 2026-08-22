# Atomic Work Breakdown Structure

- Target: 440 atomic steps.
- Status legend: `done`, `active`, `planned`, `blocked`.
- Dependency rule: a phase gate must pass before work that would make its failures expensive or destructive.
- Evidence rule: a step is not done until its named artifact/check exists; implementation steps require runtime evidence proportional to risk.
- Execution rule: ordinary in-scope decisions are made autonomously, critiqued once, verified, and recorded. After the user explicitly reversed the earlier no-subagent constraint, independent streams may run concurrently with exclusive ownership and root-agent integration.
- Goal overlay: `37-goal-charter-v2.md` is binding. These 440 rows are the atomic baseline, not a cap; newly discovered details become subordinate requirement/evidence records and cannot be hidden inside a prematurely completed parent row.
- Masterpiece rule: every capability must pass the contextual, Night Shift, state, EN/FA/RTL, accessibility, motion, Data Plane, performance, adversarial, and runtime gates before an implementation row can be considered complete.

## Phase 00 — Governance, Scope, and Durable Control (WBS-001–020)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-001 | done | Read the canonical goal file and normalize every explicit requirement. | none | rebuild + automate | `00-brief.md` and `07-requirement-ledger.md` cover the objective. |
| WBS-002 | done | Record the historical no-subagent instruction and its later explicit reversal authorizing parallel app and curriculum workstreams. | WBS-001 | orchestrator | State and ADR-018 preserve both decisions; active delegates have bounded ownership and evidence contracts. |
| WBS-003 | done | Read every explicitly named skill and all references required for the planning phase. | WBS-001 | orchestrator | Skill-use ledger in state/progress; no named planning skill omitted. |
| WBS-004 | done | Verify Synapse, StudyHUB, and Harrison-like source paths and repository boundaries. | WBS-001 | integrity | Paths and source roles recorded; no cross-repo writes during audit. |
| WBS-005 | done | Freeze Synapse commit and protected archive hashes. | WBS-004 | integrity | Commit and SHA-256 values in `02-state.md`. |
| WBS-006 | done | Create the durable work-docs task folder and index entry. | WBS-001 | work-docs | Task folder and `_index.md` exist. |
| WBS-007 | done | Define measurable success criteria and explicit initial-scope exclusions. | WBS-001 | rebuild + integrity | `00-brief.md` contains acceptance and no-lesson-body boundary. |
| WBS-008 | done | Establish an evidence naming convention for logs, screenshots, manifests, fixtures, and artifacts. | WBS-006 | work-docs | `assets/`, `logs/`, and verification naming policy documented. |
| WBS-009 | done | Create an architecture-decision-record template with contract and rollback fields. | WBS-006 | integrity | ADR template validates and first decisions are indexed. |
| WBS-010 | done | Create a living risk register with probability, impact, trigger, owner, mitigation, and contingency. | WBS-006 | critics | Risk file contains all audit P0/P1 risks. |
| WBS-011 | done | Define the additive-change boundary and removal gate. | WBS-005 | rebuild + integrity | `08-preservation-contract.md` is explicit and testable. |
| WBS-012 | done | Define phase-level Definition of Ready and Definition of Done. | WBS-007 | work-docs | Each implementation phase has entry/exit gates. |
| WBS-013 | done | Define P0 stop/rollback behavior for data loss, auth, reward, PHI, and clinical-claim failures. | WBS-010 | errors + backend | Incident/rollback matrix exists and is referenced by implementation plans. |
| WBS-014 | done | Define Education, Reference, and Clinical mode claim boundaries. | WBS-007 | integrity + backend | Product and requirement docs state separate mode behavior. |
| WBS-015 | done | Record source ownership/IP assumptions and the no-copy brand boundary. | WBS-001 | branding + integrity | Brief and mascot no-copy checklist exist. |
| WBS-016 | done | Freeze release separation: structural scaffolds are body-free; authored bodies require a separately validated content release. | WBS-007 | integrity | Requirements prevent raw/generated bodies from bypassing coverage, bilingual, evidence, medical, and publication gates. |
| WBS-017 | done | Record autonomous decision-making and no-approval-pause behavior. | WBS-001 | automate | Requirement R-020 and state decision exist. |
| WBS-018 | done | Finish this atomic WBS with unique IDs, owners, dependencies, and evidence. | WBS-007 | work-docs | 440 unique WBS rows parse successfully. |
| WBS-019 | done | Add a repository-local WBS validator for count, uniqueness, dependency syntax, and status values. | WBS-018 | function | Validator reports 440 ordered, unique, dependency-safe steps. |
| WBS-020 | done | Run a deliberate governance critique and close all P0 planning gaps. | WBS-008..019 | critics | Critique log has no unresolved P0 governance finding. |

## Phase 01 — Preservation and Baseline Contracts (WBS-021–040)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-021 | done | Inventory the 12 stable `ModuleKey` IDs and five `ShellBranch` values. | WBS-004 | rebuild | Preservation table contains exact enum IDs. |
| WBS-022 | done | Inventory route constants, typed helpers, GoRoutes, parameters, and shell ownership. | WBS-004 | anatomy + rebuild | Route audit records 137 reachable route intents and protected helpers. |
| WBS-023 | done | Inventory core IDs, Concept, LearnItem, Mastery, Evidence, rewards, and typed events. | WBS-004 | integrity | Protected model/event list is recorded. |
| WBS-024 | done | Inventory local persistence schema and SharedPreferences usage. | WBS-004 | integrity | `__synapse_schema` and key-owning providers are identified. |
| WBS-025 | done | Inventory Supabase migrations, tables, policies, triggers, and RPC authority. | WBS-004 | backend | Migrations `0001`–`0003` and risks are recorded. |
| WBS-026 | done | Inventory current real, partial, seed-only, and commitment capabilities. | WBS-004 | critics + function | Capability baseline and 19 Coming Soon commitments are classified. |
| WBS-027 | done | Inventory existing tests and analyzer/build baseline. | WBS-004 | function | Baseline verification records analyzer, six app tests, and web release build. |
| WBS-028 | done | Capture representative desktop/mobile screenshots from an isolated runtime copy. | WBS-027 | modernize | Eight baseline screenshots are stored under task assets. |
| WBS-029 | done | Freeze a read-only Critics report with evidence, owners, and verification targets. | WBS-021..028 | critics | 25-page, 16-finding PDF and hash are stored. |
| WBS-030 | done | Define the contract removal gate and compatibility obligations. | WBS-021..026 | rebuild + integrity | `08-preservation-contract.md` removal gate exists. |
| WBS-031 | done | Generate a machine-readable route snapshot from source. | WBS-022 | function | JSON fixture lists every canonical path, parameter, branch, and intent. |
| WBS-032 | done | Generate a machine-readable module/enum serialization snapshot. | WBS-021 | integrity | Golden fixture preserves IDs and presentation-independent semantics. |
| WBS-033 | done | Generate a machine-readable persistence-key inventory. | WBS-024 | integrity | Key registry includes owner, type, default, version, migration. |
| WBS-034 | done | Export sanitized Supabase schema/policy/function fixtures. | WBS-025 | backend | Reproducible schema snapshots exist without secrets. |
| WBS-035 | done | Add archived model/event deserialization fixtures. | WBS-023 | function + integrity | Legacy JSON/event fixtures round-trip in tests. |
| WBS-036 | done | Add legacy deep-link cold-start and refresh fixtures. | WBS-031 | anatomy + function | Route harness covers browser/native cold start and nested restoration. |
| WBS-037 | done | Add compatibility tests for all existing route helpers. | WBS-031 | function | Every helper resolves to the expected intent. |
| WBS-038 | done | Add a capability ledger file consumed by docs/tests. | WBS-026 | integrity | Every capability has stable ID, state, owner, target context, verification. |
| WBS-039 | done | Create rollback snapshots for route, local state, schema, and user-file migration tests. | WBS-031..035 | errors + backend | Rollback fixture bundle is versioned and checksumed. |
| WBS-040 | done | Pass the preservation phase gate before changing navigation or persistence. | WBS-030..039 | critics + rebuild | No unresolved P0; compatibility harness green. |

## Phase 02 — Research, Positioning, and Opportunity Proof (WBS-041–060)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-041 | done | Research integrated medical learning platforms through official product surfaces. | WBS-001 | ideas + branding | AMBOSS, Osmosis, UWorld, Geeky Medics, and Anki patterns documented. |
| WBS-042 | done | Research direct gamified-medical competitors. | WBS-001 | ideas | Pharmingo, Deduco, ORReady, and Step Gunner patterns documented. |
| WBS-043 | done | Research Duolingo path, adaptive lessons, and learning-quality metrics. | WBS-001 | gamify | Official path/adaptation/TSLW consequences documented. |
| WBS-044 | done | Research companion and focus-product retention patterns. | WBS-001 | gamify-mascot-studio | Finch and Forest patterns/risks documented. |
| WBS-045 | done | Research professional medical community and structured forum patterns. | WBS-001 | ideas + integrity | Figure 1 and Discord forum governance patterns documented. |
| WBS-046 | done | Research spaced repetition and retrieval-practice evidence. | WBS-001 | gamify | 2026 meta-analysis and 2024 systematic review documented with limits. |
| WBS-047 | done | Research gamification/serious-game evidence quality and higher-order learning gaps. | WBS-001 | gamify + critics | Reviews and SOLO findings documented. |
| WBS-048 | done | Research WHO health-AI governance and current FDA CDS guidance. | WBS-001 | backend + integrity | AI/CDS boundary consequences documented. |
| WBS-049 | done | Separate saturated features from structural differentiation. | WBS-041..048 | ideas | Saturation and opportunity tables exist. |
| WBS-050 | done | Define the defensible closed loop from curriculum to delayed mastery. | WBS-049 | branding + ideas | Research Atlas and product system share one loop. |
| WBS-051 | done | Define the Medical Learning OS working category and avoid unsupported uniqueness claims. | WBS-049 | branding | Positioning is framed as an inference and proof obligation. |
| WBS-052 | done | Generate at least 20 materially different product-direction recipes. | WBS-049 | ideas + modernize | 24 scored recipes exist. |
| WBS-053 | done | Shortlist six directions using a weighted product rubric. | WBS-052 | modernize | Six shortlisted concepts and risks documented. |
| WBS-054 | done | Compare three final directions and select Synapse Atlas autonomously. | WBS-053 | automate + modernize | Selection table records 94/89/86 scores. |
| WBS-055 | done | Identify structural opportunity set beyond current competitors. | WBS-049 | ideas | At least 18 opportunity hypotheses documented. |
| WBS-056 | planned | Convert every opportunity into a falsifiable product hypothesis and counter-metric. | WBS-055 | ideas + critics | Hypothesis register names user, behavior, measure, risk, kill criterion. |
| WBS-057 | planned | Prioritize opportunities by learning value, trust, coherence, cost, and reversibility. | WBS-056 | branding + bestvalue | Ranked opportunity portfolio with now/next/later/never. |
| WBS-058 | planned | Define discovery experiments for high-risk product assumptions. | WBS-056 | ideas | Prototype/test plan for Atlas navigation, prescriptions, mastery, and mascot restraint. |
| WBS-059 | planned | Recheck material market/regulatory facts before launch decisions. | WBS-041..048 | integrity | Dated refresh log uses primary/official sources. |
| WBS-060 | planned | Pass the research/positioning phase gate. | WBS-041..059 | critics + branding | No claim outruns evidence; differentiation maps to build behavior. |

## Phase 03 — Information Architecture and Task Flows (WBS-061–080)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-061 | done | Select Today/Path/Clinical/Rounds/You as presentation labels over stable branch contracts. | WBS-040 + WBS-054 | anatomy | IA mapping and compatibility rule documented. |
| WBS-062 | done | Define the one durable job owned by each destination. | WBS-061 | anatomy | Destination table has no duplicate job ownership. |
| WBS-063 | done | Define shell-global Search, Command, Copilot, Inbox, and Notification surfaces. | WBS-061 | anatomy | Global reachability policy documented. |
| WBS-064 | done | Define page-vs-tab-vs-inspector-vs-sheet-vs-command placement rules. | WBS-061 | anatomy + integrity | Page-sprawl checklist exists. |
| WBS-065 | done | Map every existing Synapse module into the unified topology. | WBS-062 | anatomy | Module absorption table covers all 12 IDs. |
| WBS-066 | done | Map existing global/reference/social/admin surfaces into the topology. | WBS-062 | anatomy | Capability absorption table covers current commitments. |
| WBS-067 | done | Map legacy workspace capabilities horizontally into the topology without a source-branded product surface. | WBS-062 | anatomy + integrity | Every protected source capability has a functional Synapse owner, surface, label, entry context, and analytics namespace. |
| WBS-068 | done | Define Course, Chapter, Unit/Micro-lesson, and Concept Atlas scales and outline equivalents. | WBS-054 | anatomy + modernize | Scale table defines spatial and semantic views. |
| WBS-069 | done | Define Today’s first-viewport prescription hierarchy. | WBS-062 | anatomy | One action, reason, time, workload, and adjust path are specified. |
| WBS-070 | done | Define the compact and expanded Margin Workspace composition. | WBS-067 | anatomy | Reader/notes/evidence/thread ownership documented. |
| WBS-071 | planned | Draw the authenticated and unauthenticated shell state machine. | WBS-061 + WBS-040 | anatomy | Diagram covers splash/onboarding/auth/deep-link/restoration. |
| WBS-072 | planned | Specify new-learner onboarding flow and optional diagnostic. | WBS-069 | anatomy + multilingual | Flow covers role, stage, goals, time, language, privacy, accessibility. |
| WBS-073 | planned | Specify returning-learner prescription and comeback flow. | WBS-069 | anatomy + gamify | Flow avoids backlog shame and preserves user choice. |
| WBS-074 | planned | Specify source-led study and artifact-lineage flow. | WBS-070 | anatomy | Source→highlight→note→card→review lineage is explicit. |
| WBS-075 | planned | Specify clinical-transfer flow from concept gap to case/evidence/debrief. | WBS-068 | anatomy + function | Route/state/event sequence documented. |
| WBS-076 | planned | Specify point-lookup-to-later-learning flow. | WBS-063 | anatomy + integrity | Clinical lookup stays quiet; saved micro-review is explicit. |
| WBS-077 | planned | Specify peer teach-back and reviewed-contribution flow. | WBS-066 | anatomy + integrity | Roles, citation, privacy, review, and mastery evidence boundaries documented. |
| WBS-078 | planned | Build a reachability matrix for top tasks by audience and form factor. | WBS-071..077 | anatomy | Student/resident/physician tasks meet target decision counts. |
| WBS-079 | planned | Prototype back, branch restoration, nested workspace, and deep-link behavior. | WBS-071 | anatomy + function | Interactive route prototype has no ambiguous exits/state loss. |
| WBS-080 | planned | Pass the IA phase gate with an adversarial task-flow critique. | WBS-061..079 | critics + anatomy | No unresolved P0 reachability, context-loss, or page-sprawl issue. |

## Phase 04 — Brand, Mascots, Visual Direction, and Preview Lock (WBS-081–100)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-081 | done | Preserve the brand-core invariants independent of any visual metaphor. | WBS-054 | branding + integrity | Synapse, medical education primacy, trust boundary, audiences, English/Persian, and no-copy rules remain fixed. |
| WBS-082 | done | Preserve and critique the rejected dry editorial Atlas preview as negative evidence. | WBS-081 | modernize + critics | Rejected asset, checksum, failure analysis, and user correction are recorded. |
| WBS-083 | done | Generate at least 24 broad product-world recipes across UX, topology, material, motion, data metaphor, and brand behavior. | WBS-081..082 | modernize + ideas | `18-visual-concept-exploration.md` contains 30 raw recipes. |
| WBS-084 | done | Shortlist ten genuinely distinct, usable global theme and brand-world candidates. | WBS-083 | modernize + branding | Ten candidate cards include UX, visual, mascot, Clinical, responsive, feasibility, and risk logic. |
| WBS-085 | done | Generate candidate preview 01: Synapse Spark. | WBS-084 | imagegen + modernize | Distinct real-UI board saved with prompt, provenance, and checksum. |
| WBS-086 | done | Generate candidate preview 02: Mediverse Odyssey. | WBS-084 | imagegen + modernize | Distinct real-UI board saved with prompt, provenance, and checksum. |
| WBS-087 | done | Generate candidate preview 03: Pulse City. | WBS-084 | imagegen + modernize | Distinct real-UI board saved with prompt, provenance, and checksum. |
| WBS-088 | done | Generate candidate preview 04: Prism Shift. | WBS-084 | imagegen + modernize | Distinct real-UI board saved with prompt, provenance, and checksum. |
| WBS-089 | done | Generate candidate preview 05: Vital Bloom. | WBS-084 | imagegen + modernize | Distinct real-UI board saved with prompt, provenance, and checksum. |
| WBS-090 | done | Generate candidate preview 06: Case Quest. | WBS-084 | imagegen + modernize | Distinct real-UI board saved with prompt, provenance, and checksum. |
| WBS-091 | done | Record the second visual correction, terminate the over-conceptual preview batch, and preserve rejected outputs as negative evidence. | WBS-085..090 | modernize + critics | User feedback, aborted Study Riot generation, and rejected-batch status are recorded. |
| WBS-092 | done | Define the non-negotiable clean Duolingo-medical interaction and visual grammar. | WBS-091 | modernize + gamify | Common grammar fixes simplicity, Path, mascot, CTA, feedback, whitespace, medical relevance, and Clinical restraint. |
| WBS-093 | done | Generate ten tightly scoped Duolingo-medical rough sparks that vary theme, mascot, path motif, and palette without losing the common grammar. | WBS-092 | modernize + ideas + branding | `19-duolingo-medical-concept-reset.md` contains ten comparable sparks. |
| WBS-094 | done | Present ten tightly scoped Duolingo-medical rough sparks and capture the requirement for individual visual proof. | WBS-093 | modernize | User explicitly requires all ten concepts to be previewed one by one before selection. |
| WBS-095 | done | Generate high-fidelity real-UI previews one by one until the user makes a binding selection, retaining ungenerated candidates as explicit retired concepts. | WBS-094 | imagegen + modernize | VIS-01..09 are independently saved with prompts, provenance, and checksums; VIS-10 is explicitly retired after VIS-09 selection. |
| WBS-096 | done | Run a deliberate critique and correction pass on the selected preview against the rejected directions and shared quality gates. | WBS-095 | critics + modernize + imagegen | `20-night-shift-selected-direction.md` records strengths, correction requirements, originality, safety, RTL, responsive, and composition gates. |
| WBS-097 | done | Capture the user’s selected preview or exact blend and activate Automate for ordinary brand/theme/product decisions. | WBS-096 | automate + work-docs + integrity | Binding user attachment, decision ledger, retired VIS-10 reason, and both asset checksums are recorded. |
| WBS-098 | active | Generate and refine the approved original mascot family, logo territory, states, and bounded reward scene. | WBS-097 | imagegen + gamify-mascot-studio | Production-reference assets pass no-copy, expression, suppression, and small-size tests. |
| WBS-099 | planned | Produce responsive English/Persian theme specimens and token proofs for the approved direction. | WBS-097..098 | multilingual + style | Mobile/tablet/desktop LTR/RTL specimens pass legibility, bidi, density, and accessibility critique. |
| WBS-100 | planned | Pass the brand/preview phase gate before implementing the new shell. | WBS-081..099 | critics + modernize | User-approved direction is frozen; no unresolved P0 trust/originality/composition issue. |

## Phase 05 — Repository, Toolchain, and Application Foundation (WBS-101–120)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-101 | done | Reconfirm Git status and isolate all planning artifacts from unrelated user changes. | WBS-020 | rebuild | Pre-implementation status snapshot and overlap check recorded. |
| WBS-102 | done | Resolve the Dart SDK constraint against the chosen supported Flutter channel. | WBS-101 | multi-os | `flutter pub get`, analyzer, and tests run without temporary constraint edits. |
| WBS-103 | done | Enable/record Windows Developer Mode or provide a supported no-symlink development path. | WBS-101 | multi-os | Plugin resolution succeeds on the Windows host. |
| WBS-104 | active | Add and commit deterministic dependency lockfiles for the Flutter app/workspace. | WBS-102 | integrity | Clean clone resolves the same dependency graph. |
| WBS-105 | done | Audit and update Melos workspace/package boundaries without collapsing protected packages. | WBS-102 | rebuild | Bootstrap, analyze, and test commands work from repository root. |
| WBS-106 | done | Add root task commands for format, analyze, test, build, verify, and docs validation. | WBS-105 | automate | One-command developer verification is documented and green. |
| WBS-107 | done | Define environment/config tiers for local, test, preview, staging, and production. | WBS-105 | backend | Typed config rejects missing/invalid production values. |
| WBS-108 | done | Remove hardcoded or client-exposed secrets and add a repository secret scan. | WBS-107 | backend + integrity | Scan passes and client bundles contain no protected credentials. |
| WBS-109 | done | Define a typed feature-flag registry with real consumers and safe defaults. | WBS-107 | function | Flag tests cover default, override, offline, and stale config. |
| WBS-110 | done | Add structured logging with redaction, correlation IDs, and environment-aware sinks. | WBS-107 | errors + backend | Sensitive-data tests and representative event logs pass. |
| WBS-111 | done | Define privacy-aware analytics events separate from authoritative domain events. | WBS-110 | integrity + backend | Analytics schema, consent, minimization, and deletion behavior documented/tested. |
| WBS-112 | done | Add crash/error reporting interfaces without binding core packages to a vendor. | WBS-110 | errors | Local/test sink and production adapter contract pass. |
| WBS-113 | done | Define app bootstrap states for config, local store, auth, sync, locale, and router. | WBS-107..112 | function | Bootstrap state machine tests cover failure/retry/offline. |
| WBS-114 | done | Add a pure-Dart clock, ID, randomness, network, and storage abstraction for deterministic tests. | WBS-105 | function | Domain tests run without platform globals. |
| WBS-115 | done | Define repository-wide immutable model/serialization/versioning conventions. | WBS-105 | integrity | Lints/tests reject unsafe enum/index and unversioned event persistence. |
| WBS-116 | done | Create a test-fixture package for routes, models, schemas, locales, events, and platform data. | WBS-114..115 | function | Fixtures are reusable across app/core/services/backend tests. |
| WBS-117 | done | Add code-generation and generated-file reproducibility checks where justified. | WBS-105 | automate | Clean regeneration causes no unreviewed diff. |
| WBS-118 | done | Define dependency-direction rules and enforce package import boundaries. | WBS-105 | integrity | Architecture test rejects app/platform imports in pure domain packages. |
| WBS-119 | done | Add baseline performance and bundle-budget configuration. | WBS-102 | performance | Budgets exist for startup, frames, memory, JS/WASM, assets, and packs. |
| WBS-120 | active | Pass the foundation phase gate on a clean workspace. | WBS-101..119 | critics + multi-os | Format/analyze/test/build/docs/secret/architecture checks green. |

## Phase 06 — Curriculum Domain, Manifest, and Importer (WBS-121–150)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-121 | planned | Implement pure-Dart `CurriculumSource`, `CurriculumRelease`, and channel models. | WBS-120 | function + integrity | Serialization and equality tests pass. |
| WBS-122 | planned | Implement stable Course/Chapter/Unit/ConceptCluster/MicroLesson node kinds plus separate Session/Interaction and checkpoint/boss-case experience roles. | WBS-121 | function | Parent-kind, ordinal, and hierarchy-versus-experience invariant tests pass. |
| WBS-123 | planned | Choose and freeze a project UUIDv5 namespace. | WBS-121 | integrity | Namespace ADR and deterministic golden IDs exist. |
| WBS-124 | planned | Implement locale/path/hash-independent source-key-to-UUID derivation. | WBS-123 | function | Rename, locale, and revision invariance property tests pass. |
| WBS-125 | planned | Implement curriculum localization and translation-status models. | WBS-121 | multilingual | Exact-locale/language/en fallback tests pass. |
| WBS-126 | planned | Implement segmentation-candidate and supersession models. | WBS-122 | integrity | Candidate cannot satisfy live Lesson/progress interfaces. |
| WBS-127 | planned | Implement content-asset origin, reference, MIME, checksum, and quarantine models. | WBS-121 | dataman + integrity | Model tests cover all audited anomaly codes. |
| WBS-128 | planned | Implement immutable release-manifest schema and canonical JSON encoding. | WBS-121..127 | integrity | Golden manifest is byte-stable and schema-versioned. |
| WBS-129 | planned | Implement the filesystem discovery adapter for Part/Chapter/Lesson ordinals. | WBS-128 | dataman | Fixture tree discovers deterministic hierarchy/order. |
| WBS-130 | planned | Reject path traversal, symlink escape, invalid/duplicate ordinals, and ambiguous casing. | WBS-129 | errors + integrity | Malicious/invalid fixture suite quarantines every case. |
| WBS-131 | planned | Implement deterministic canonical-Markdown discovery and quarantined source atomization without reading raw bodies into product seeds. | WBS-129 | dataman | Missing/empty status, hashes, locators, roles, and atoms are recorded; learner-visible body count stays zero until content validation. |
| WBS-132 | planned | Implement TypeScript sidecar discovery without execution. | WBS-129 | integrity | No runtime/child execution path exists; role counts match snapshot. |
| WBS-133 | planned | Implement magic-byte MIME sniffing and bounded decode validation. | WBS-127 | performance + integrity | JPEG-as-PNG, real PNG, SVG, WebP, corrupt, and polyglot fixtures pass. |
| WBS-134 | planned | Implement safe canonical media encoding and content-addressed storage keys. | WBS-133 | dataman + performance | Output extensions/MIME/checksums/length limits are correct. |
| WBS-135 | planned | Implement SVG sanitization with scripts/external references disabled. | WBS-133 | integrity | Adversarial SVG corpus is rejected or safely normalized. |
| WBS-136 | planned | Implement Markdown media-reference parsing without source rewrite. | WBS-131 | dataman | Strict/fallback/unresolved/repeated references match audited counts. |
| WBS-137 | planned | Implement strict-relative, recorded-parent-fallback, manual-map, quarantine resolution. | WBS-136 | dataman + integrity | Resolver decisions are deterministic and provenance-preserving. |
| WBS-138 | planned | Implement exact-byte storage deduplication without node auto-merge. | WBS-134 | dataman | Duplicate fixtures share blobs but retain distinct origins/references. |
| WBS-139 | planned | Implement heading-candidate extraction with parser version, lines, anchors, and confidence. | WBS-131 | dataman | 32/no-heading and non-H2 fixtures remain safe; no live Lessons created. |
| WBS-140 | planned | Implement stale-index cross-check that trusts count/order but not absolute roots. | WBS-129 | integrity | Old-root paths never become runtime locators. |
| WBS-141 | planned | Build full-source dry-run manifest tooling against a read-only source root. | WBS-129..140 | automate + dataman | Tool writes only to designated output and never mutates source. |
| WBS-142 | planned | Verify full manifest counts 20/1,138/73/186/1,065, body-free scaffold separation, and complete source-document/atom accounting. | WBS-141 | integrity | Structural counts, hashes, classification, and coverage baseline are exact and checksumed. |
| WBS-143 | planned | Verify all audited media/reference/path/empty/duplicate anomaly counts. | WBS-141 | integrity | Reconciliation report explains any drift before import. |
| WBS-144 | planned | Add forward-only Supabase curriculum source/release/node/localization migrations. | WBS-128 + WBS-040 | backend | Migration applies twice safely in disposable environments. |
| WBS-145 | planned | Add hierarchy, identity, release immutability, and channel-pointer constraints. | WBS-144 | backend + integrity | Constraint violation tests deny invalid trees/mutations. |
| WBS-146 | planned | Add asset/origin/reference/import-batch/finding/manifest tables and RLS. | WBS-144 | backend | Client writes deny; importer service writes and audit reads pass. |
| WBS-147 | planned | Implement transactional draft scaffold import with batch journal and idempotency. | WBS-142..146 | backend + function | Re-run creates zero duplicates; interrupted import resumes/reverts safely. |
| WBS-148 | planned | Implement shadow-read tree comparison against the filesystem manifest. | WBS-147 | integrity | Identity/order/count/localization parity is exact. |
| WBS-149 | planned | Implement `CurriculumNodeRef` and resource-link adapters without adding a module enum. | WBS-122 + WBS-040 | function + integrity | Existing LearnItem/module/event fixtures remain compatible. |
| WBS-150 | planned | Pass the curriculum/importer and source-atomization phase gate. | WBS-121..149 | critics + dataman | Structure, quarantine, identity, coverage, release separation, and security gates are green. |

## Phase 07 — English-First, Persian-Native Localization Foundation (WBS-151–170)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-151 | planned | Inventory every hardcoded user-facing string, semantic label, tooltip, notification, widget, and metadata value. | WBS-120 | multilingual + string | Extraction report has owner and replacement key for every string. |
| WBS-152 | planned | Define stable semantic localization-key naming and package ownership. | WBS-151 | multilingual | Key convention prevents page-text coupling and duplicate meanings. |
| WBS-153 | planned | Configure Flutter localization delegates, locale registry, and generated catalogs. | WBS-152 | multilingual | `en` and `fa` resolve in app tests. |
| WBS-154 | planned | Implement explicit locale resolution, system mode, persistence, and auth/profile reconciliation. | WBS-153 | multilingual + function | Restart/auth/device-locale test matrix passes. |
| WBS-155 | planned | Build the canonical English catalog for the foundation and preserved routes. | WBS-151..153 | multilingual + string | English key/placeholder/type coverage is 100%. |
| WBS-156 | planned | Build the Persian catalog with full key and placeholder parity. | WBS-155 | multilingual + string | Parity validator passes; review status is explicit. |
| WBS-157 | planned | Define native Persian tone, medical terminology, formal/informal address, and punctuation rules. | WBS-156 | multilingual + string | Persian writing guide has reviewed examples and anti-patterns. |
| WBS-158 | planned | Implement Dual Terminology Mode for Persian plus canonical English terms/abbreviations. | WBS-156 | multilingual | User preference and representative medical term tests pass. |
| WBS-159 | planned | Implement bidi isolation helpers for drugs, doses, genes, formulas, URLs, and abbreviations. | WBS-153 | multilingual + integrity | Mixed-script golden tests show correct order and copy behavior. |
| WBS-160 | planned | Define non-mirroring rules for anatomy laterality, ECG, radiology, plots, and scientific symbols. | WBS-153 | multilingual + integrity | Directionality component tests cover each scientific exception. |
| WBS-161 | planned | Select and license-test English/Persian/data font stack. | WBS-153 + WBS-100 | style + multilingual | Glyph, shaping, metrics, fallback, license, and bundle checks pass. |
| WBS-162 | planned | Normalize Persian characters/search forms without altering displayed source text. | WBS-156 | multilingual + function | Search handles ک/ك, ی/ي, spacing, diacritics, and transliteration aliases. |
| WBS-163 | planned | Separate language from region, calendar, numerals, timezone, and measurement preferences. | WBS-154 | multilingual + integrity | Persian locale does not silently alter safety-critical numeric formats. |
| WBS-164 | planned | Implement locale-aware, content-direction-aware search indexing contracts. | WBS-158..162 | multilingual + performance | English/Persian/transliteration/abbreviation queries return deterministic results. |
| WBS-165 | planned | Localize route labels, navigation semantics, empty/loading/error/offline/success states. | WBS-155..156 | multilingual + errors | Catalog coverage and screenshot states pass. |
| WBS-166 | planned | Localize notification, widget, email/export/share/PDF, subtitle, and TTS contracts. | WBS-155..156 | multilingual + widgets | Cross-surface parity inventory is complete. |
| WBS-167 | planned | Add pseudo-long English, pseudo-RTL, missing-key, and placeholder-mismatch tests. | WBS-153 | multilingual + errors | CI fails on truncation-prone or invalid catalogs. |
| WBS-168 | planned | Add English/Persian compact/expanded light/dark 200%-text screenshot matrix. | WBS-161..167 | multilingual + style | Goldens show no overflow, clipping, overlap, or wrong mirroring. |
| WBS-169 | planned | Run native Persian and medical terminology review on launch-critical strings. | WBS-156..168 | multilingual + integrity | Review log closes all P0 terminology/safety issues. |
| WBS-170 | planned | Pass the localization foundation gate. | WBS-151..169 | critics + multilingual | Catalog, persistence, RTL, bidi, font, search, and surface parity green. |

## Phase 08 — Design System, States, Motion, and Adaptive Shell (WBS-171–195)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-171 | planned | Translate the selected preview and `22-motion-bible.md` into semantic color, typography, spacing, radius, elevation, border, and motion/choreography tokens. | WBS-100 + WBS-170 | style | Token package has light/dark/high-contrast plus Full/Reduced/Off motion fixtures. |
| WBS-172 | planned | Implement Study and Clinical lens token overlays without separate component forks. | WBS-171 | style + integrity | Same component switches lens while identity/state remains stable. |
| WBS-173 | planned | Implement responsive breakpoints and posture-aware navigation policy. | WBS-171 | anatomy + multi-os | Phone/foldable/tablet/desktop layout tests pass. |
| WBS-174 | planned | Implement safe-area/inset/keyboard-aware shell geometry. | WBS-173 | anatomy | Bottom controls, dock, sheets, and IME never overlap content. |
| WBS-175 | planned | Implement Today/Path/Clinical/Rounds/You presentation labels over stable branches. | WBS-173 + WBS-040 | anatomy + multilingual | Old branch restoration/deep links pass with new labels. |
| WBS-176 | planned | Replace the floating Copilot FAB with a safe shell-level command dock. | WBS-174 | anatomy + function | Compact/expanded/keyboard/a11y tests show no obstruction. |
| WBS-177 | planned | Implement global Search/Command/Copilot/Inbox/Notification overlay contracts. | WBS-176 | anatomy | Overlays preserve underlying route/scroll/session and restore focus. |
| WBS-178 | planned | Implement porcelain canvas, paper surface, ribbon, contour, pin, thread, ring, and inspector primitives. | WBS-171 | style + frontend-design | Storybook/gallery shows intended grammar without generic card sprawl. |
| WBS-179 | planned | Implement accessible Atlas Station and semantic outline equivalents. | WBS-178 | anatomy + function | Pointer, keyboard, screen-reader, and 200%-text interactions pass. |
| WBS-180 | planned | Implement the compact sheet and expanded resizable Margin Workspace shell. | WBS-174 + WBS-178 | anatomy | State/size/route persistence tests pass. |
| WBS-181 | planned | Implement Clinical Peek and Evidence Shelf containers with provenance slots. | WBS-172 + WBS-178 | style + integrity | Source/date/version/uncertainty remain visible at supported widths. |
| WBS-182 | planned | Implement common loading, empty, error, offline, stale, permission, retry, success, and partial-data states. | WBS-171 | errors + style | Component gallery and semantic tests cover all state variants. |
| WBS-183 | planned | Implement form, validation, destructive-confirmation, and recovery patterns. | WBS-182 | errors + style | Keyboard, screen-reader, localization, and async failure tests pass. |
| WBS-184 | planned | Implement Full, Essential, Off/reduced-motion, high-contrast, bold-text, low-power, and data-saver adaptations. | WBS-171 | style + performance | Preference changes interrupt active choreography, settle truthfully, and lose no information. |
| WBS-185 | planned | Implement Motion Bible tokens, presentation queue, and state-preserving shell/route/workspace transitions as the foundation of MVS-MOTION-01. | WBS-184 | style + function | Timings, easing, cancellation, interruption, RTL, lifecycle restoration, and reduced/no-motion alternatives pass with runtime capture. |
| WBS-186 | planned | Integrate approved LUMA base assets as an entry/loop/exit state machine with canonical still fallbacks. | WBS-098 + WBS-184 | gamify-mascot-studio + style | Full/Essential/Off, interruption, offscreen pause, renderer failure, RTL anchor, and Clinical suppression tests pass. |
| WBS-187 | planned | Implement one bounded reward/debrief summary plate and exact-once Synaptic Return choreography. | WBS-186 | gamify + style + gamify-reward-engine | Live receipt is authoritative, skip changes presentation only, and no reward UI leaks into Clinical/task surfaces. |
| WBS-188 | planned | Fix role/display-name composition to eliminate `Dr. Dr.` and incorrect titles. | WBS-175 | function + multilingual | Student/resident/physician/name edge-case tests pass. |
| WBS-189 | planned | Build a component/interaction gallery across lenses, locales, sizes, and states. | WBS-171..188 | style | Gallery is runnable and screenshoted in CI. |
| WBS-190 | planned | Add semantic labels/equivalents for custom painters, maps, graphs, and rings. | WBS-178..189 | anatomy | Screen-reader and keyboard task audit passes. |
| WBS-191 | planned | Add automated contrast, touch-target, overflow, and focus-order checks. | WBS-189 | style + anatomy | CI reports no P0 accessibility violation. |
| WBS-192 | planned | Run visual overlap/alignment/crop/negative-space critique at target sizes. | WBS-189 | modernize + critics | Screenshot issue ledger closes all P0/P1 composition defects. |
| WBS-193 | planned | Profile design-system rebuild/repaint/image/font plus native/Rive/canvas/audio motion costs. | WBS-189 | performance | MVS-MOTION-01 frame, memory, asset/decode, lifecycle, battery/thermal, and fallback budgets pass in release/profile conditions. |
| WBS-194 | planned | Update legacy screens to consume shared states/tokens without deleting functionality. | WBS-171..193 | integrity + style | Preserved route screenshot smoke remains functional/coherent. |
| WBS-195 | planned | Pass the design-system and shell gate. | WBS-171..194 | critics + modernize | Responsive/RTL/a11y/perf/route matrices green. |

## Phase 09 — Today, Path, Atlas, and First Medical Academy Vertical Slice (WBS-196–225)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-196 | planned | Add read-only curriculum repository interfaces to the app layer. | WBS-150 + WBS-120 | function | Fake/local/cloud adapters pass contract tests. |
| WBS-197 | planned | Expose the internal scaffold release behind a safe feature flag. | WBS-196 + WBS-109 | function | Flag off preserves legacy Learn; flag on reads exact scaffold tree. |
| WBS-198 | planned | Implement Course Atlas data projection with stable sort and completion states. | WBS-196 | function | Projection handles 20 Courses and unknown/unsegmented states. |
| WBS-199 | planned | Implement a virtualized Course Atlas canvas. | WBS-198 + WBS-179 | frontend-design + performance | Pan/zoom/frame/memory tests pass on target devices. |
| WBS-200 | planned | Implement synchronized ordered Course outline alternative. | WBS-198 + WBS-179 | anatomy | Canvas/outline selection/focus/scroll state stays equivalent. |
| WBS-201 | planned | Implement Course detail with Chapter Trail/ribbon and explicit Browse/Continue actions. | WBS-198 | frontend-design + anatomy | 1,138-chapter corpus remains searchable and navigable without giant eager lists. |
| WBS-202 | planned | Implement Chapter detail showing approved Units/Micro-lessons separately from source-anchor and pending-atomization status. | WBS-201 | integrity + frontend-design | Source anchors or unreviewed candidates never appear as fabricated completion/reward controls. |
| WBS-203 | planned | Implement Lesson Station with an honest unavailable scaffold state and validated bilingual pack playback. | WBS-202 | frontend-design + errors | Source containers are reachable; only activated reviewed content renders and raw/draft bodies never leak. |
| WBS-204 | planned | Add additive `/learn/courses/**` and `/learn/session/:nodeId` routes. | WBS-197 + WBS-040 | anatomy + function | Route/deep-link/restoration/refresh tests pass. |
| WBS-205 | planned | Redirect/filter legacy Learn entry points to the appropriate new context without deleting them. | WBS-204 | rebuild + anatomy | All old `/learn/**` intent tests remain green. |
| WBS-206 | planned | Implement node-aware Margin Workspace context and route restoration. | WBS-180 + WBS-204 | function | Node/document/mode/pane state survives refresh and branch switches. |
| WBS-207 | planned | Implement one next-best prescription interface with explainability fields. | WBS-069 + WBS-196 | function + anatomy | Reason, time, factors, alternatives, and defer actions are modeled/tested. |
| WBS-208 | planned | Implement a deterministic fake prescription policy for UI/testing only. | WBS-207 | function | Fixtures cover new, returning, due-review, comeback, and offline states. |
| WBS-209 | planned | Build Today first viewport around one prescription and explicit Browse Path. | WBS-207..208 + WBS-195 | frontend-design | Usability smoke reaches next action in one decision. |
| WBS-210 | planned | Add bounded review debt, active-plan, resume, quest, and insight sections below the first viewport. | WBS-209 | anatomy | Secondary content cannot displace/compete with the primary action. |
| WBS-211 | planned | Implement lesson-session shell with intent, time, activity queue, progress semantics, and Motion Bible presentation-state hooks. | WBS-203 + WBS-195 | function + frontend-design | Session can start/resume/cancel/recover with fake activities without replaying or losing presentation state. |
| WBS-212 | planned | Adapt at least one existing Terms exercise type into a curriculum-linked activity. | WBS-211 + WBS-149 | function | Legacy Terms behavior works and carries CurriculumNodeRef. |
| WBS-213 | planned | Adapt at least one existing Cards/SRS exercise into the session. | WBS-211 + WBS-149 | function | Card identity/history remains compatible and node-linked. |
| WBS-214 | planned | Adapt one clinical mini-activity using existing ECG, Lab, or Case data. | WBS-211 + WBS-149 | function | Study lens can launch/return without duplicating Clinical entity identity. |
| WBS-215 | planned | Implement concise correct/repair/partial/hint feedback choreography, explanation zoom shell, and misconception placeholder contract. | WBS-211 | errors + frontend-design | Full/Reduced/Off, English/Persian, interruption, offline, and error states are accessible, localized, and capture-verified. |
| WBS-216 | planned | Implement session debrief with mastery evidence, uncertainty, scheduled-next placeholders, and live Motion Bible receipt fields. | WBS-215 | gamify + integrity | Debrief distinguishes evidence from XP, count-up is cosmetic/skippable, and no false competence claim exists. |
| WBS-217 | planned | Connect legacy `LessonCompleted` projection without granting client-authoritative rewards. | WBS-216 | function + gamify-reward-engine | Event adapter test fires once; reward write remains server-only. |
| WBS-218 | planned | Add Today/Path/lesson/session English and Persian strings. | WBS-209..216 + WBS-170 | multilingual | Key parity and representative screenshots pass. |
| WBS-219 | planned | Add compact/expanded/light/dark/LTR/RTL/reduced-motion goldens. | WBS-218 | modernize + multilingual | No overflow, overlap, crop, or incorrect mirroring. |
| WBS-220 | planned | Add keyboard/screen-reader/200%-text end-to-end task tests. | WBS-219 | anatomy | Course→Chapter→Unit→Micro-lesson→session→debrief is operable without pointer. |
| WBS-221 | planned | Add offline/stale/empty/quarantine states for curriculum browsing. | WBS-196 | errors | Honest status and recovery actions test green. |
| WBS-222 | planned | Add performance tests for 20 Courses, 1,138 Chapters, map pan/zoom, and long lists. | WBS-199..203 | performance | Agreed frame/memory/search/list budgets pass. |
| WBS-223 | planned | Run real web and available native runtime screenshot/smoke of the vertical slice. | WBS-209..222 | multi-os + modernize | Live artifacts and screenshots recorded, not widget tests alone. |
| WBS-224 | planned | Run an adversarial product/visual/integrity critique of the vertical slice. | WBS-223 | critics | All P0/P1 vertical-slice findings resolved or explicitly gated. |
| WBS-225 | planned | Pass the first Medical Academy Cardiology vertical-slice gate. | WBS-196..224 | rebuild + integrity | Curriculum-first loop plays a validated short EN/FA pack without breaking legacy contracts. |

## Phase 10 — Activity Engine, Mastery, Retrieval, and Planning (WBS-226–250)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-226 | planned | Define versioned activity, prompt, response, evaluation, feedback, and rubric contracts. | WBS-225 | function | Pure-Dart schema supports existing and planned exercise families. |
| WBS-227 | planned | Map all eight current Terms exercise types into the versioned activity contract. | WBS-226 | function | Parity tests preserve behavior, semantics, and IDs. |
| WBS-228 | planned | Define activity variants for recall, explain, connect, diagnose, decide, defend, teach, and transfer. | WBS-226 | gamify + integrity | Each variant has evidence type, scoring boundary, accessibility fallback. |
| WBS-229 | planned | Implement attempt/session IDs, lifecycle, resume, abandonment, and timeout semantics. | WBS-226 | function | Repeated/restarted/offline attempts cannot collide or double-complete. |
| WBS-230 | planned | Implement answer evaluation separated from reward and UI feedback. | WBS-226 | function + integrity | Evaluator is deterministic and reward-free. |
| WBS-231 | planned | Implement confidence capture and calibration outcome modeling. | WBS-230 | function | Correct/incorrect × confidence cases produce bounded calibration evidence. |
| WBS-232 | planned | Implement misconception taxonomy and evidence-linked repair recommendations. | WBS-230 | function + integrity | Wrong distractor/reasoning-step fixtures map to explicit repair codes. |
| WBS-233 | planned | Implement why-not distractor and explanation-zoom data contracts. | WBS-230 | integrity | Source/review/version fields are required for publishable explanations. |
| WBS-234 | planned | Define the multidimensional Mastery Ledger schema and evidence weights. | WBS-228..233 | integrity + gamify | Dimensions cannot be confused with XP; uncertainty is explicit. |
| WBS-235 | planned | Implement append-only mastery evidence events and deterministic projections. | WBS-234 | function | Replay/order/idempotency/property tests pass. |
| WBS-236 | planned | Implement decay/recency/stability semantics without presenting false precision. | WBS-235 | function + integrity | Time-travel tests and UI confidence bands pass. |
| WBS-237 | planned | Implement concept-level review eligibility from mastery evidence. | WBS-235 | gamify | Rule tests distinguish new, due, repair, transfer, and mastered states. |
| WBS-238 | planned | Evaluate current SRS engine against FSRS-like workload/retention requirements. | WBS-237 | gamify + performance | ADR selects adapt/replace path with benchmark and migration consequences. |
| WBS-239 | planned | Implement the selected versioned scheduling algorithm behind an interface. | WBS-238 | gamify + function | Golden schedules and clock/property tests pass. |
| WBS-240 | planned | Implement workload caps, easy days, on-call constraints, and review-debt behavior. | WBS-239 | gamify | Planner never creates unbounded catch-up walls. |
| WBS-241 | planned | Implement explainable next-best prescription scoring. | WBS-235 + WBS-239 | function + integrity | Every selection has factor breakdown, alternatives, and deterministic tests. |
| WBS-242 | planned | Add user-controlled goal, availability, exam, rotation, and professional-stage constraints. | WBS-241 | function | Constraint changes produce transparent plan changes. |
| WBS-243 | planned | Implement defer, snooze, swap, lighter mode, and stop-without-penalty actions. | WBS-241 | gamify + function | User-choice tests preserve schedule integrity and avoid reward exploits. |
| WBS-244 | planned | Implement interleaving across new learning, recall, repair, case, and transfer. | WBS-241 | gamify | Session-plan tests meet configured mix and prerequisite boundaries. |
| WBS-245 | planned | Implement a unified Recall Clinic projection for Cards, Terms, and curriculum activities. | WBS-237..244 | function | One queue preserves legacy card history and curriculum context. |
| WBS-246 | planned | Implement offline attempt outbox, sequence, replay, and conflict rules. | WBS-229 + WBS-235 | backend + errors | Restart/reorder/duplicate/conflict tests produce one accepted outcome. |
| WBS-247 | planned | Add mastery/scheduler migration fixtures for legacy Synapse and StudyHUB history. | WBS-238..246 | integrity | Counts, timestamps, intervals, and aliases reconcile. |
| WBS-248 | planned | Add session/mastery/SRS/planner performance and scale tests. | WBS-235..247 | performance | Large history projection and queue generation meet budgets. |
| WBS-249 | planned | Add explainability, fairness, and false-competence critique tests. | WBS-234..247 | critics + integrity | No P0 issue in opaque selection, biased workload, or misleading mastery. |
| WBS-250 | planned | Pass the learning-engine phase gate. | WBS-226..249 | critics + function | Activity, mastery, SRS, planning, offline, and migration matrices green. |

## Phase 11 — Reward Ledger, Streaks, Quests, Achievements, and Companions (WBS-251–275)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-251 | planned | Define versioned rewardable event taxonomy and explicitly non-rewardable events. | WBS-250 | gamify-reward-engine | Downloads, opens, passive time, duplicates, and unreviewed content grant zero. |
| WBS-252 | planned | Define append-only reward transaction, balance projection, rule version, and reason schemas. | WBS-251 | gamify-reward-engine + integrity | Ledger replay equals stored projection in tests. |
| WBS-253 | planned | Add authoritative reward tables/RPC/functions with client-write denial. | WBS-252 | backend + gamify-reward-engine | RLS/tamper/cross-user tests deny unauthorized grants. |
| WBS-254 | planned | Implement idempotency keys and atomic attempt-to-reward transactions. | WBS-253 | backend | Retry/offline/replay/concurrency tests grant once. |
| WBS-255 | planned | Implement daily/weekly/campaign caps and diminishing-return rules. | WBS-252 | gamify-reward-engine | Farming simulations stay bounded and explainable. |
| WBS-256 | planned | Weight rewards toward delayed mastery, repair, transfer, and teaching quality. | WBS-251 + WBS-235 | gamify-reward-engine | Rule fixtures show harder-looking volume cannot outrank learning value by default. |
| WBS-257 | planned | Define currency purposes, sinks, expirations, refunds, and non-pay-to-win boundaries. | WBS-252 | gamify-reward-engine + branding | Economy spec prevents critical learning access from depending on spend. |
| WBS-258 | planned | Decide against learning-blocking hearts/energy and define optional capacity metaphors only. | WBS-257 | gamify + integrity | ADR prohibits error punishment and critical-content locks. |
| WBS-259 | planned | Implement compassionate continuity/streak state with grace and recovery. | WBS-240 + WBS-252 | gamify-reward-engine | Timezone, illness/on-call grace, comeback, and no-shame tests pass. |
| WBS-260 | planned | Implement one authoritative RewardSummary plus immutable presentation receipt per committed transaction set. | WBS-254 | gamify-reward-engine | UI receives one localized summary/receipt, duplicate presentation coalesces, and animation never has balance authority. |
| WBS-261 | planned | Design a stable achievement ID/schema with tier, rarity, secret, progress, and localization fields. | WBS-252 | gamify-achievement-catalog | Schema validates all planned catalog entries. |
| WBS-262 | planned | Inventory and alias existing Synapse and StudyHUB achievements. | WBS-261 | gamify-achievement-catalog + integrity | Unlock timestamps map without duplicate grants. |
| WBS-263 | planned | Author the learning/mastery achievement family. | WBS-261 | gamify-achievement-catalog | Entries reward durable/varied evidence, not raw taps. |
| WBS-264 | planned | Author repair, calibration, consistency, comeback, and workload-care achievement families. | WBS-261 | gamify-achievement-catalog | No shame, diagnosis leakage, or unhealthy behavior incentive. |
| WBS-265 | planned | Author clinical-skill, case, teaching, evidence, and community achievement families. | WBS-261 | gamify-achievement-catalog + integrity | Clinical claims are scoped; peer review is required where appropriate. |
| WBS-266 | planned | Define daily/weekly/personal/co-op quest schemas and alternative completion paths. | WBS-252 | gamify-achievement-catalog | Quest validation enforces caps, accessibility, and no required social participation. |
| WBS-267 | planned | Implement quest progress from authoritative events. | WBS-266 + WBS-253 | gamify-reward-engine | Replay/idempotency/offline tests pass. |
| WBS-268 | planned | Define leagues as optional small-cohort or comparable-effort experiences. | WBS-257 | gamify + integrity | Opt-out, privacy, matchmaking, anti-cheat, and role/schedule fairness rules exist. |
| WBS-269 | planned | Define cooperative Ward goals and Grand Rounds challenge rules. | WBS-266 | gamify + integrity | Contribution quality and team completion do not expose PHI or reward spam. |
| WBS-270 | planned | Implement server projections for achievements, quests, continuity, and optional leagues. | WBS-253..269 | backend | Projection reconciliation and policy tests pass. |
| WBS-271 | planned | Integrate LUMA role/performance states only from committed domain events and immutable presentation receipts. | WBS-260 + WBS-186 | gamify-mascot-studio | No mascot celebrates optimistic/unconfirmed state; duplicate, replay, interruption, and fallback tests pass. |
| WBS-272 | planned | Implement Full/Essential/Off and Quiet Clinical critical suppression/deferred digest across reward/quest surfaces. | WBS-271 | integrity | Functional/a11y parity passes without characters/motion and suppressed receipts never leak or double-play. |
| WBS-273 | planned | Add economy/achievement/quest localization and semantic descriptions. | WBS-261..272 + WBS-170 | multilingual | English/Persian parity and secret-achievement accessibility pass. |
| WBS-274 | planned | Run anti-farming, concurrency, timezone, tamper, wellbeing, and fairness simulations. | WBS-253..273 | critics + gamify-reward-engine | No unresolved P0 exploit or harmful incentive. |
| WBS-275 | planned | Pass the gamification and Motion Bible phase gate. | WBS-251..274 | critics + integrity | Ledger, catalog, quests, continuity, companions, original choreography, receipts, Full/Reduced/Off, Clinical suppression, capture, and profiler matrices are green. |

## Phase 12 — Clinical Practice, Evidence, Reference, and Safety (WBS-276–300)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-276 | planned | Implement explicit Education/Reference/Clinical mode metadata and UI policy. | WBS-195 + WBS-014 | integrity | Mode is visible, restorable, and testable on every clinical/reference route. |
| WBS-277 | planned | Define Evidence metadata: source, citation, version/date, jurisdiction, strength, freshness, reviewer, uncertainty. | WBS-276 | integrity + backend | Publish validation rejects incomplete governed evidence. |
| WBS-278 | planned | Implement contextual Evidence Shelf and Clinical Peek data contracts. | WBS-277 + WBS-181 | function | Peek opens/closes without losing task state and exposes provenance. |
| WBS-279 | planned | Migrate Library/disease/drug/tool seeds behind unified reference repositories. | WBS-278 + WBS-040 | function | Legacy IDs/routes remain and repository parity tests pass. |
| WBS-280 | planned | Enforce calculator input type, unit, min/max, missing, and clinically invalid ranges. | WBS-279 | function + integrity | Boundary/property tests cover every calculator. |
| WBS-281 | planned | Add formula/source/version/limitations and result-copy semantics to calculators. | WBS-280 | integrity + multilingual | Representative English/Persian clinical screenshots pass. |
| WBS-282 | planned | Harden drug interaction and drug/class surfaces with provenance and safety language. | WBS-279 | integrity | Missing/stale/conflict states never fabricate reassurance. |
| WBS-283 | planned | Rebuild Cases around longitudinal patient arcs, decisions, confidence, evidence, and debrief. | WBS-250 + WBS-278 | function + frontend-design | Existing case IDs/routes work; new forks write durable attempts. |
| WBS-284 | planned | Implement case why-not distractors and misconception repair links. | WBS-283 + WBS-232 | function | Case errors schedule traceable repair without automatic diagnosis claims. |
| WBS-285 | planned | Replace OSCE keyword scoring with versioned rubrics and explicit evaluator provenance. | WBS-250 | function + integrity | Human/self/peer/AI evaluation modes are distinguishable and auditable. |
| WBS-286 | planned | Implement OSCE role, station, checklist, feedback, and debrief workflows. | WBS-285 | frontend-design | Single/group/observer paths are accessible and privacy-aware. |
| WBS-287 | planned | Integrate ECG generator/drill/case into curriculum links and mastery dimensions. | WBS-250 + WBS-149 | function | Existing ECG routes work; signal interpretation evidence is stored correctly. |
| WBS-288 | planned | Integrate Sounds library/quiz with transcripts, discrimination tasks, and offline media. | WBS-250 + WBS-149 | function + performance | Audio focus, captions/transcripts, cache, interruption tests pass. |
| WBS-289 | planned | Integrate Labs reference/rules with trend, range, unit, and case interpretation. | WBS-250 + WBS-149 | function + integrity | Rule provenance and unit/range tests pass. |
| WBS-290 | planned | Integrate Algorithms as learning simulations with explicit non-CDS boundaries. | WBS-250 + WBS-276 | function + integrity | Play/session/bookmark routes preserve state; clinical claims stay bounded. |
| WBS-291 | planned | Integrate OR Lab narrative, transcript, simulation, and future voice rehearsal contracts. | WBS-250 + WBS-149 | function | Existing drama IDs/routes and new activity links pass. |
| WBS-292 | planned | Add save-to-later-learning from quiet clinical lookup. | WBS-278 + WBS-241 | function | Save creates a bounded future review without reward at lookup time. |
| WBS-293 | planned | Implement Clinical lens mascot/reward/shop/league suppression. | WBS-276 + WBS-272 | integrity + style | Critical and point-of-care screenshots contain no game clutter. |
| WBS-294 | planned | Add content freshness, withdrawal, jurisdiction, and supersession behavior. | WBS-277 | backend + errors | Withdrawn/stale content is visible, non-silent, and safely linked. |
| WBS-295 | planned | Add citation rendering, source opening, offline citation state, and export. | WBS-277 | function + multilingual | Citation semantics and bilingual/mixed-script rendering pass. |
| WBS-296 | planned | Add PHI-safe recent/history behavior for clinical searches and tools. | WBS-276 | integrity + backend | Default retention/minimization and user-clear tests pass. |
| WBS-297 | planned | Add clinical error/escalation/refusal states and safety telemetry. | WBS-276 + WBS-182 | errors + integrity | Critical scenarios produce correct warning and no mascot/misleading success. |
| WBS-298 | planned | Run medical-editorial review on representative reference, case, OSCE, and tool flows. | WBS-279..297 | integrity | Review log closes P0 factual/claim/scope issues. |
| WBS-299 | planned | Run clinical accessibility, RTL, offline, performance, and deep-link matrix. | WBS-279..297 | multi-os + performance | Representative routes pass all targeted states. |
| WBS-300 | planned | Pass the Clinical/Evidence phase gate. | WBS-276..299 | critics + integrity | No unresolved P0 safety, provenance, PHI, calculator, or mode issue. |

## Phase 13 — Rounds, Community, Cohorts, and Institutional Workflows (WBS-301–320)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-301 | planned | Define verified identity, role, institution, pseudonym, and public/private scope models. | WBS-300 | backend + integrity | Identity model does not expose protected data or trust self-edited roles. |
| WBS-302 | planned | Define Rounds artifact types: case, audio round, pearl, misconception repair, teach-back, evidence challenge, event. | WBS-301 | function + integrity | Each type has required structure, source, privacy, and moderation fields. |
| WBS-303 | planned | Implement de-identification checklist and submission gate for case artifacts. | WBS-302 | integrity | Known PHI fixtures block submission and log safe remediation. |
| WBS-304 | planned | Implement citation/evidence requirements and accepted-reasoning workflow. | WBS-302 | integrity + backend | Popularity cannot mark content scientifically accepted. |
| WBS-305 | planned | Define moderation taxonomy, report, triage, appeal, sanction, and restoration lifecycle. | WBS-301 | integrity + errors | Abuse/medical-misinformation/PHI scenarios have owners and SLAs. |
| WBS-306 | planned | Implement persistent tagged discussion threads rather than chat-only comments. | WBS-302 + WBS-305 | function | Search/filter/archive/lock/reopen/moderation tests pass. |
| WBS-307 | planned | Rebuild Rounds feed as bounded, user-controlled, non-doomscroll collections. | WBS-306 | anatomy + frontend-design | No infinite passive autoplay; filters and explicit end states exist. |
| WBS-308 | planned | Implement audio round record/upload/transcript/caption/playback contracts. | WBS-302 | function + performance | Consent, interruption, retry, transcript, accessibility, and quota tests pass. |
| WBS-309 | planned | Implement Buddies discovery/matching with safety, consent, availability, and block/report. | WBS-301 + WBS-305 | function | Matching never exposes sensitive schedule/location by default. |
| WBS-310 | planned | Implement private Ward/cohort lifecycle, roles, goals, membership, and audit. | WBS-301 | backend + function | Create/invite/join/leave/remove/archive/restore tests pass. |
| WBS-311 | planned | Implement cooperative mastery goals from authoritative events. | WBS-269 + WBS-310 | gamify-reward-engine | Spam/passive/social-only actions cannot complete goals. |
| WBS-312 | planned | Implement peer teach-back submission and rubric review attached to curriculum nodes. | WBS-304 + WBS-310 | function + integrity | Review provenance and bounded mastery evidence pass. |
| WBS-313 | planned | Implement Classes and assignments without a separate learning system. | WBS-310 + WBS-150 | backend + anatomy | Assignments reference canonical nodes/activities and preserve student privacy. |
| WBS-314 | planned | Implement Org/tenant isolation and server-managed staff memberships. | WBS-301 + WBS-313 | backend | Cross-tenant RLS tests deny every unauthorized path. |
| WBS-315 | planned | Implement Events and Grand Rounds challenge lifecycle. | WBS-302 + WBS-310 | function + gamify | Schedule/timezone/capacity/recording/replay/reward rules pass. |
| WBS-316 | planned | Reframe Arena as optional governed challenge content inside Rounds. | WBS-300 + WBS-275 | gamify + integrity | Legacy routes work; no pay-to-win or false competence signal. |
| WBS-317 | planned | Implement Inbox/chat with thread context, retention, blocking, reporting, and safe notifications. | WBS-305 + WBS-310 | function + errors | Offline/retry/duplicate/block/report/retention tests pass. |
| WBS-318 | planned | Localize and accessibility-test Rounds/community/cohort workflows. | WBS-306..317 + WBS-170 | multilingual + anatomy | English/Persian/RTL/screen-reader matrix passes. |
| WBS-319 | planned | Run abuse, misinformation, PHI, popularity-bias, and wellbeing red-team scenarios. | WBS-303..318 | critics + integrity | No unresolved P0 community safety issue. |
| WBS-320 | planned | Pass the Rounds/community/institutional phase gate. | WBS-301..319 | critics + backend | Identity, moderation, evidence, tenant, co-op, and preserved routes green. |

## Phase 14 — Complete Legacy Workspace Absorption and Migration (WBS-321–345)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-321 | planned | Freeze sanitized StudyHUB database fixtures for every reachable schema version 2–17. | WBS-040 | integrity | Fixture archive has schema/hash/count metadata and no secrets/PHI. |
| WBS-322 | planned | Freeze StudyHUB stable IDs, composite keys, settings, notification, widget, deep-link, and migration-channel registries. | WBS-321 | integrity | Machine-readable legacy contract registry exists. |
| WBS-323 | planned | Remove/quarantine shared email/password sync and embedded AvalAI/client secrets. | WBS-321 | backend + integrity | Secret scan and client artifact inspection pass. |
| WBS-324 | planned | Define a unified local database schema for curriculum cache, workspace, outbox, and user state. | WBS-150 + WBS-250 | backend + function | Schema ADR avoids permanent second authority and supports migrations. |
| WBS-325 | planned | Implement read-only legacy DB opening and version detection. | WBS-321 + WBS-324 | function | Unsupported/corrupt/locked database states fail safely. |
| WBS-326 | planned | Reproduce/test legacy migration chain 2→17 against archived fixtures. | WBS-325 | function | Every version reaches v17 with expected counts/keys. |
| WBS-327 | planned | Implement journaled, resumable, idempotent StudyHUB import batches. | WBS-325 | function + errors | Interrupt/retry/re-run/rollback tests create no duplicates or loss. |
| WBS-328 | planned | Implement canonical alias mapping for course/chapter/lesson with collision quarantine. | WBS-327 + WBS-124 | integrity | `remoteId/sourceKey/contentHash/courseId` round-trip and ambiguous IDs quarantine. |
| WBS-329 | planned | Import PDF/document bytes and metadata into content-addressed user storage. | WBS-327 | function + performance | Byte/hash/count/ownership reconciliation passes. |
| WBS-330 | planned | Import reading position and bookmarks into universal workspace anchors. | WBS-329 | function | Page/range/document-version mappings reconcile. |
| WBS-331 | planned | Import PDF/lesson annotations, notes, tags, and cross-references. | WBS-329 | function + integrity | Counts, ownership, anchors, relationships, timestamps reconcile. |
| WBS-332 | planned | Import lesson forks and lineage as user-created artifacts. | WBS-328 | function | Parent/version/share scope and timestamps are preserved. |
| WBS-333 | planned | Import SRS/cards/review history through audited scheduler migration. | WBS-247 + WBS-327 | gamify + integrity | History/interval/due/count reconciliation and no duplicate reward pass. |
| WBS-334 | planned | Import planner/goals/activity history into unified plan/event history. | WBS-242 + WBS-327 | function | Constraints/history are preserved without creating duplicate authority. |
| WBS-335 | planned | Import achievements through canonical aliases while retaining unlock timestamps. | WBS-262 + WBS-327 | gamify-achievement-catalog | Imported unlocks do not re-grant rewards. |
| WBS-336 | planned | Import Copilot/chat threads with node/document scope and privacy classification. | WBS-327 | backend + integrity | Messages reconcile; unsafe payloads quarantine/redact. |
| WBS-337 | planned | Import AI job history without executing or resubmitting legacy payloads. | WBS-327 | backend + integrity | Status/history preserved; secrets/PHI scans pass. |
| WBS-338 | planned | Import TTS cache metadata selectively and rebuild device-specific cache safely. | WBS-327 | performance | No stale/unportable binary assumption; quota/eviction tests pass. |
| WBS-339 | planned | Implement PDF reader/search/zoom/progress in the Margin Workspace. | WBS-180 + WBS-329 | frontend-design + performance | Mobile/web/desktop reader matrix and large-PDF budgets pass. |
| WBS-340 | planned | Implement highlight/annotation/note/tag/card actions with source lineage. | WBS-331 + WBS-339 | function | Every artifact links to exact source/node and survives restart/sync. |
| WBS-341 | planned | Absorb contextual source search, bounded lesson recaps, reviewed evidence details, and embedded practice without exposing legacy mode or sub-brand names. | WBS-339 + WBS-226 | function + integrity | No AI draft publishes; functional placement, source provenance, and the no-separate-Enrich boundary pass. |
| WBS-342 | planned | Implement OCR/TTS/background AI job interfaces through secure server/device boundaries. | WBS-339 | backend + function | Consent, redaction, cancel/retry, progress, failure, and quota tests pass. |
| WBS-343 | planned | Bridge legacy widget/notification/deep-link keys to Today/Recall/Workspace intents. | WBS-322 + WBS-339 | widgets + function | Old keys/intents open correct new state. |
| WBS-344 | planned | Run full StudyHUB reconciliation and cross-platform export/import tests. | WBS-326..343 | integrity + multi-os | Counts/hashes/keys/relationships/user files match; no secret/PHI leak. |
| WBS-345 | planned | Pass the StudyHUB absorption gate and keep legacy source read-only until restore proof expires. | WBS-321..344 | critics + rebuild | No second tab/DB authority; all protected capabilities/contracts accounted for. |

## Phase 15 — Backend Authority, Sync, Security, Governance, and AI (WBS-346–370)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-346 | planned | Define authoritative ownership for profile, curriculum, mastery, reward, workspace, social, entitlement, and settings data. | WBS-345 | backend + integrity | Data-authority matrix has exactly one writer/source of truth per field. |
| WBS-347 | planned | Implement real user-scoped authentication and session lifecycle. | WBS-323 | backend | Sign-up/in/out/refresh/revoke/multi-device/offline-expiry tests pass. |
| WBS-348 | planned | Implement server-managed staff, role, tenant, and separation-of-duty memberships. | WBS-314 + WBS-347 | backend + integrity | Profile self-edit cannot escalate roles; RLS matrix passes. |
| WBS-349 | planned | Implement durable client outbox/server inbox/event deduplication. | WBS-246 + WBS-347 | backend | Offline/retry/reorder/duplicate/conflict/restart tests pass. |
| WBS-350 | planned | Implement scoped sync repositories and field-level conflict policies. | WBS-346 + WBS-349 | backend + function | Profile/settings/progress/workspace/social fixtures reconcile deterministically. |
| WBS-351 | planned | Implement user-visible sync state, last-success, pending count, conflict, retry, and recovery. | WBS-350 | errors + frontend-design | Offline/degraded/stale/auth-failed/conflict screenshots and semantics pass. |
| WBS-352 | planned | Replace fixed online provider assumptions with real connectivity/reachability/degraded signals. | WBS-350 | function + errors | Network transition tests do not lose or duplicate work. |
| WBS-353 | planned | Implement content author/reviewer/approver/publisher workflow and independent-review policy. | WBS-348 + WBS-146 | backend + integrity | Self-approval and unauthorized publish attempts deny. |
| WBS-354 | planned | Require evidence, version/date, source ownership, change reason, and review history for publishable medical artifacts. | WBS-353 | integrity | Publish validator and audit fixtures pass. |
| WBS-355 | planned | Implement immutable audit log for privileged, publication, reward, moderation, and migration actions. | WBS-348..354 | backend | Audit writes are append-only, queryable, redacted, and actor-correlated. |
| WBS-356 | planned | Implement the Jules execution fabric with environment-held secrets, exact Source/branch discovery, resumable manifests, artifact harvesting, and 15/100 Pro limits. | WBS-150 + WBS-347 | backend + ai | No key enters repo/logs; pagination, quota, concurrency, retry, resume, and artifact tests pass. |
| WBS-357 | planned | Freeze project authoring policy to lesson writing, embedded quiz writing, and bounded reinforcement summaries with no separate specialist/`enrich` workflow. | WBS-356 + WBS-276 | integrity + ai | Task prompts and validators enforce full coverage, micro-session budgets, and the explicit adaptation boundary. |
| WBS-358 | planned | Implement corpus-rights boundaries, data minimization, PHI/secret detection, redaction, and no-log fields for Jules tasks. | WBS-356 | backend + integrity | Adversarial corpus/PHI/secret fixtures block or redact correctly. |
| WBS-359 | planned | Implement source-grounding/citation requirements and retrieval provenance. | WBS-356 + WBS-277 | ai + integrity | Unsupported citations/claims fail evaluation and show safe UI. |
| WBS-360 | planned | Implement Cardiology-first staged Jules queues for atom review, decomposition, simultaneous EN/FA authoring, and validation with account-wide rolling quota. | WBS-356..359 | backend + errors | Fifteen non-overlapping shards run safely, stop at 100/24h, resume idempotently, and never publish directly. |
| WBS-361 | planned | Implement AI draft quarantine, review, edit, approve, reject, and supersede workflows. | WBS-353 + WBS-360 | backend + integrity | No draft can enter published curriculum/reference without review gates. |
| WBS-362 | planned | Build evaluation suites for lesson quality, embedded quiz/feedback, bounded summary, source coverage, EN/FA parity, evidence, medical safety, accessibility, and monotony. | WBS-357..361 | ai + critics | Accuracy, grounding, coverage, parity, safety, accessibility, and engagement baselines exist. |
| WBS-363 | planned | Implement rate limits, abuse limits, cost budgets, and user-visible quota/recovery. | WBS-356 + WBS-360 | backend | Burst/abuse/cost simulations remain bounded and understandable. |
| WBS-364 | planned | Implement secure file upload scanning, type/size limits, checksum, quarantine, and retention. | WBS-329 + WBS-347 | backend + integrity | Malicious/corrupt/oversize/duplicate upload tests pass. |
| WBS-365 | planned | Implement user data export with manifest, hashes, provenance, and portable formats. | WBS-346 | backend + integrity | Export can be validated and re-imported in a test account. |
| WBS-366 | planned | Implement deletion/retention/legal-hold workflows with explicit scope and delayed purge. | WBS-346 + WBS-355 | backend + integrity | Delete/cancel/hold/audit/reconciliation tests pass. |
| WBS-367 | planned | Implement entitlement/subscription authority, restore, grace, refund, and offline receipt behavior. | WBS-346 | backend + function | Client cannot self-grant; platform-store sandbox tests pass where available. |
| WBS-368 | planned | Add backend metrics, traces, structured errors, SLOs, and privacy-safe dashboards. | WBS-349..367 | backend + errors | Key flows have correlation and alert thresholds without sensitive payloads. |
| WBS-369 | planned | Run RLS, role escalation, cross-tenant, reward tamper, PHI, upload, AI, and audit red-team suites. | WBS-347..368 | critics + integrity | No unresolved P0 security/governance failure. |
| WBS-370 | planned | Pass the backend/security/AI phase gate. | WBS-346..369 | critics + backend | Authority, sync, governance, AI, privacy, entitlement, and observability green. |

## Phase 16 — Errors, Offline Resilience, Accessibility, and Performance (WBS-371–395)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-371 | planned | Build an end-to-end failure-boundary inventory for UI, domain, storage, sync, backend, AI, media, platform, and release. | WBS-370 | errors | Every durable boundary has owner, user state, telemetry, retry, and recovery. |
| WBS-372 | planned | Define typed failure codes and user-safe localized message mapping. | WBS-371 | errors + multilingual | Domain errors do not leak stack/secrets and map to actionable UI. |
| WBS-373 | planned | Implement global uncaught Flutter/Dart/platform error capture and redaction. | WBS-372 | errors | Debug/test/prod behavior and crash correlation tests pass. |
| WBS-374 | planned | Implement retry policies with backoff, jitter, idempotency, cancellation, and retry budgets. | WBS-371 | errors + backend | Simulated transient/permanent failures behave correctly. |
| WBS-375 | planned | Implement cache quota, eviction, pinning, stale-while-offline, and corruption recovery. | WBS-339 + WBS-371 | errors + performance | Disk-full/corrupt/eviction/restart tests preserve user data. |
| WBS-376 | planned | Implement resumable content-pack/file/media/job downloads with atomic promotion. | WBS-375 | errors + backend | Network loss/checksum/cancel/retry/rollback tests pass. |
| WBS-377 | planned | Implement conflict review/recovery UI for irreconcilable user artifacts. | WBS-350 + WBS-372 | errors + frontend-design | User can compare/choose/duplicate/export without silent loss. |
| WBS-378 | planned | Implement backup/recovery for local migration and import interruption. | WBS-327 + WBS-375 | errors + integrity | Kill-at-every-step tests recover or roll back deterministically. |
| WBS-379 | planned | Audit every interactive control for semantics, role, name, state, value, and hint. | WBS-345 | anatomy | Automated/manual semantics inventory has no unlabeled critical control. |
| WBS-380 | planned | Implement complete keyboard/focus traversal and visible focus across all destinations/workspaces. | WBS-379 | anatomy | Desktop/web task matrix passes without pointer. |
| WBS-381 | planned | Implement screen-reader equivalents for Atlas, mastery rings, graphs, ECG, lab trends, and mind maps. | WBS-379 | anatomy | VoiceOver/TalkBack/Narrator semantic task scripts have equivalents. |
| WBS-382 | planned | Verify touch targets, gestures, alternatives, drag/zoom controls, and switch access. | WBS-379 | anatomy | No gesture-only critical action; target-size checks pass. |
| WBS-383 | planned | Verify 200% text, system bold, display zoom, landscape, split-screen, and foldable postures. | WBS-379 | anatomy + multi-os | Zero-overflow screenshot/task matrix passes. |
| WBS-384 | planned | Verify contrast, color-blind distinctions, high contrast, reduced transparency, and dark mode. | WBS-379 | style | Automated and manual contrast/state checks pass. |
| WBS-385 | planned | Profile cold/warm startup and time-to-first-action by platform. | WBS-345 | performance | Traces identify budgets and regressions; targets pass or have owned fixes. |
| WBS-386 | planned | Profile Path/atlas pan/zoom, long lists, graphs, custom painters, LUMA state machines, particles/shaders, audio startup, and animation frame pacing. | WBS-345 | performance | P50/P95/P99 frame, build/raster, memory, asset/decode, battery, and fallback budgets pass on representative hardware. |
| WBS-387 | planned | Profile memory, image decode, PDF, audio/TTS, cache, and large-session histories. | WBS-345 | performance | No unbounded growth; memory budgets and disposal tests pass. |
| WBS-388 | planned | Profile search/index, manifest parsing, import, event replay, mastery projection, and scheduling. | WBS-345 | performance | Representative corpus/history benchmarks meet targets. |
| WBS-389 | planned | Audit web JS/WASM, fonts, images, initial route, lazy loading, and service-worker cache size. | WBS-345 | performance | Bundle budgets and repeat-load behavior pass. |
| WBS-390 | planned | Audit Android/iOS/desktop binary size and native asset/plugin impact. | WBS-345 | performance + multi-os | Per-platform size reports have enforced budgets. |
| WBS-391 | planned | Add automated performance regression benchmarks to CI-capable targets. | WBS-385..390 | performance + actions | Baseline comparison fails on material regressions. |
| WBS-392 | planned | Run chaos scenarios for offline, latency, auth expiry, stale config, partial sync, disk full, and backend outage. | WBS-371..378 | errors | User can continue/recover safely; no duplicate/lost authoritative state. |
| WBS-393 | planned | Run accessibility matrix with real assistive technologies on representative platforms. | WBS-379..384 | anatomy + multi-os | Manual evidence and defects are recorded/resolved. |
| WBS-394 | planned | Resolve all P0/P1 error, accessibility, and performance findings. | WBS-371..393 | critics | Issue ledger has no unresolved P0/P1 without explicit external blocker. |
| WBS-395 | planned | Pass the resilience/accessibility/performance gate. | WBS-371..394 | critics + performance | Failure, offline, a11y, and budget matrices green. |

## Phase 17 — Six Platforms, Widgets, Notifications, CI, Packaging, and Release (WBS-396–420)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-396 | planned | Freeze production app/package/bundle identities across Android, iOS, Windows, macOS, Linux, and Web. | WBS-395 | multi-os + branding | Identity matrix is consistent and migration implications documented. |
| WBS-397 | planned | Replace template display names, descriptions, icons, manifests, and web metadata. | WBS-396 + WBS-099 | multi-os + branding | Platform inspectors show final identity/assets. |
| WBS-398 | planned | Configure Android permissions, network security, deep links, backup, signing, and release variants. | WBS-396 | multi-os | Release manifest/signing/intent/runtime smoke pass. |
| WBS-399 | planned | Configure iOS bundle, entitlements, universal links, privacy manifests, notifications, widgets, and signing. | WBS-396 | multi-os + widgets | Apple runner archive and entitlement inspection pass. |
| WBS-400 | planned | Configure macOS bundle, sandbox/network/file entitlements, links, notifications, widgets, signing, and notarization plan. | WBS-396 | multi-os + widgets | macOS runner archive/runtime/entitlement checks pass. |
| WBS-401 | planned | Configure Windows identity, installer/package, protocol links, notifications, app icon, signing, and migration. | WBS-396 | multi-os | Clean Windows install/update/uninstall/deep-link smoke pass. |
| WBS-402 | planned | Configure Linux desktop metadata, packaging, protocol links, notifications, icons, and supported distro matrix. | WBS-396 | multi-os | Linux runner package/install/runtime smoke pass. |
| WBS-403 | planned | Configure Web manifest, icons, installability, routing/refresh, CSP, service worker, offline, and deployment headers. | WBS-396 | multi-os + backend | Lighthouse/install/refresh/offline/security-header tests pass. |
| WBS-404 | planned | Define one notification intent registry with locale, privacy, category, action, and deep-link contracts. | WBS-395 | widgets + multilingual | All existing/new notification IDs map through aliases without collision. |
| WBS-405 | planned | Implement permission education, quiet hours, on-call mode, bundling, throttling, and user controls. | WBS-404 | widgets + integrity | Permission-denied/timezone/DST/quiet/on-call tests pass. |
| WBS-406 | planned | Implement Android/iOS local/push notification adapters and action handling. | WBS-404..405 | widgets + multi-os | Device/simulator actions open correct state and reconcile duplicates. |
| WBS-407 | planned | Implement desktop/web notification adapters with honest platform fallbacks. | WBS-404..405 | widgets + multi-os | Supported/denied/unavailable states behave correctly. |
| WBS-408 | planned | Define widget surfaces for next action, review count, continuity, focus, and resume. | WBS-404 | widgets + anatomy | Privacy-safe glance-state specs and data budgets exist. |
| WBS-409 | planned | Implement Android home-screen widget with legacy-key bridge. | WBS-408 + WBS-343 | widgets | Install/update/resize/tap/offline/localization tests pass. |
| WBS-410 | planned | Implement Apple widget extension and shared-container contract. | WBS-408 | widgets + multi-os | Timeline/privacy/deep-link/localization tests pass on Apple runner. |
| WBS-411 | planned | Define desktop/web widget-equivalent surfaces without pretending unsupported native features. | WBS-408 | widgets | Platform capability table and fallbacks are implemented. |
| WBS-412 | planned | Create GitHub Actions validation workflow for format, analyze, unit, docs, secret, and architecture checks. | WBS-120 | actions | PR workflow is least-privilege, pinned, cached, and green. |
| WBS-413 | planned | Create Android/Web build and artifact-inspection workflow. | WBS-398 + WBS-403 | actions + multi-os | Versioned artifacts, manifests, hashes, and smoke evidence publish. |
| WBS-414 | planned | Create Windows/Linux build, package, and smoke workflow. | WBS-401..402 | actions + multi-os | Clean-runner artifacts and runtime smoke pass. |
| WBS-415 | planned | Create iOS/macOS build, sign, archive, and smoke workflow on Apple runners. | WBS-399..400 | actions + multi-os | Archive/export/entitlement/signature evidence publish. |
| WBS-416 | planned | Add localization, golden, accessibility, compatibility, migration, RLS, and performance jobs. | WBS-170 + WBS-395 | actions | Required matrix jobs fail on representative regressions. |
| WBS-417 | planned | Implement versioning, changelog, release-channel, provenance, SBOM, and artifact checksum workflow. | WBS-412..416 | actions + integrity | Every artifact is traceable to commit/dependency/config and channel. |
| WBS-418 | planned | Configure secret environments, approvals, least privilege, concurrency, and protected production release. | WBS-412..417 | actions + backend | Workflow security audit has no unpinned/excessive-secret path. |
| WBS-419 | planned | Run clean-install, update, rollback, deep-link, notification, widget, offline, and data-migration smoke per platform. | WBS-396..418 | multi-os | Platform release evidence matrix is complete. |
| WBS-420 | planned | Pass the multi-OS/release gate. | WBS-396..419 | critics + multi-os | Six-platform targets have real artifacts or explicitly proven host blockers. |

## Phase 18 — Comprehensive Verification, Launch Readiness, and `$perfect` Loop (WBS-421–440)

| ID | Status | Atomic task | Dependency | Owner | Exit evidence |
|---|---|---|---|---|---|
| WBS-421 | planned | Re-run the complete requirement ledger and link each requirement to current evidence. | WBS-420 | integrity + work-docs | R-001..R-051 have pass/fail/evidence/owner; no silent omission. |
| WBS-422 | planned | Re-run the complete preservation/capability ledger and route/data compatibility suites. | WBS-420 | rebuild + integrity | No current Synapse/StudyHUB capability or contract is unaccounted for. |
| WBS-423 | planned | Re-run full curriculum/importer/source-atom/content-pack reconciliation. | WBS-420 | dataman + integrity | Counts, anomalies, identity, quarantine, 100% required-atom coverage, bilingual parity, and release-separation gates remain exact. |
| WBS-424 | planned | Re-run English/Persian and all cross-surface localization parity checks. | WBS-420 | multilingual | App/widgets/notifications/export/TTS/share catalogs and screenshots green. |
| WBS-425 | planned | Re-run end-to-end learner flows for new, returning, comeback, offline, and migrated users. | WBS-420 | function | Real runtime traces and state reconciliation pass. |
| WBS-426 | planned | Re-run end-to-end Clinical, Evidence, case, OSCE, tool, and safety scenarios. | WBS-420 | integrity + function | No unsupported clinical claim, missing provenance, or unsafe calculator state. |
| WBS-427 | planned | Re-run Rounds/community/institutional abuse, privacy, moderation, and tenant scenarios. | WBS-420 | integrity + backend | No P0 cross-user/tenant/PHI/misinformation failure. |
| WBS-428 | planned | Re-run reward/economy/achievement/quest anti-farming and reconciliation simulations. | WBS-420 | gamify-reward-engine | Server ledger/projections remain exact under concurrency/replay/tamper. |
| WBS-429 | planned | Re-run backend/RLS/auth/AI/upload/export/delete/entitlement security suites. | WBS-420 | backend + critics | No P0 security/privacy/governance failure. |
| WBS-430 | planned | Re-run accessibility and performance matrices on representative real platforms. | WBS-420 | anatomy + performance | Budgets and assistive-technology tasks pass with evidence. |
| WBS-431 | planned | Capture final mobile/tablet/desktop/web screenshots for every primary destination and critical state. | WBS-424..430 | modernize | Visual matrix shows no overlap, clipping, generic regression, or mode leakage. |
| WBS-432 | planned | Conduct final brand/mascot originality, small-size, RTL, Clinical-restraint, and provenance audit. | WBS-431 | branding + gamify-mascot-studio | Asset ledger and no-copy checklist fully pass. |
| WBS-433 | planned | Conduct an independent read-only Critics audit against the original frozen baseline. | WBS-421..432 | critics | New report compares resolved/new findings with severity/evidence. |
| WBS-434 | planned | Start the explicitly requested `$perfect` loop with the complete issue ledger. | WBS-433 | perfect | Perfect state records scope, gates, evidence, and first ranked defects. |
| WBS-435 | planned | Fix the highest-impact coherent batch without weakening preservation or safety. | WBS-434 | perfect + integrity | Batch diff is reviewed and targeted verification passes. |
| WBS-436 | planned | Re-run targeted plus broad regression, runtime, screenshot, and artifact checks. | WBS-435 | perfect | No regression; issue ledger/evidence updated. |
| WBS-437 | planned | Repeat critique→fix→verify until no actionable in-scope P0/P1 and no material craft defect remains. | WBS-436 | perfect + critics | Loop history demonstrates convergence, not a single self-review. |
| WBS-438 | planned | Record durable project-specific lessons from failures, rejected visuals, and successful patterns. | WBS-437 | self-improve | Project guidance/learning ledger changes are scoped, validated, and non-dogmatic. |
| WBS-439 | planned | Produce final handoff, operations, recovery, release, content-governance, and continuation documentation. | WBS-437..438 | work-docs | `06-handoff.md`, runbooks, release notes, known limits, and evidence links complete. |
| WBS-440 | planned | Mark the goal complete only after every requirement is proven or an explicit accepted external blocker remains. | WBS-421..439 | integrity + perfect | Goal completion report includes final verification, artifacts, limitations, and no unfinished required work. |
