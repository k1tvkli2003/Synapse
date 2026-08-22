# Capability Absorption Map

## Principle

Synapse is not rebuilt by deleting “extra” features or by assigning every option a page. It is rebuilt by giving each capability a stable job inside a coherent learner journey.

Destination ownership follows this rule:

- A top-level destination exists only for a durable user job.
- Local tabs switch closely related modes without losing context.
- Inspectors, sheets, peeks, and a resizable Margin Workspace hold context-sensitive tools.
- Search, Command, Copilot, Inbox, and Notifications are shell-level overlays.
- A deep route exists for a durable entity that must be restorable/shareable.
- Rare, administrative, or role-gated actions remain searchable/command-accessible without crowding primary navigation.

## Unified Product Topology

| Stable shell contract | Presentation label | Primary job | Supporting systems |
|---|---|---|---|
| `ShellBranch.home` / `/home` | Today | Decide and execute the highest-value next action. | Adaptive prescription, review debt, plan, focus, continuity, resume, notifications, small insight snapshot. |
| `ShellBranch.learn` / `/learn` | Path | Navigate the curriculum and build durable mastery. | Course Atlas, chapter trail, lesson station, session loop, methods, Margin Workspace, imports, personal knowledge. |
| `ShellBranch.clinical` / `/clinical` | Clinical | Practice clinical reasoning/skills and retrieve trustworthy reference. | Cases, OSCE, ECG, Sounds, Labs, Algorithms, OR Lab, drugs, diseases, calculators, Evidence Shelf, Clinical Peek. |
| `ShellBranch.social` / `/social` | Rounds | Learn with people in governed professional contexts. | Rounds, wards/cohorts, buddies, classes, case discussion, co-op quests, Arena, events, rooms, chat. |
| `ShellBranch.profile` / `/profile` | You | Understand identity, readiness, history, preferences, privacy, and rewards. | Mastery, insight, achievements, inventory, settings, subscription, data controls, role/lens. |
| shell global | Global | Find, ask, act, communicate, and create from anywhere. | Search, Command Palette, Copilot, Inbox, Notifications, Create, Admin, Org, Integrations. |

Old paths remain canonical compatibility paths. Optional aliases such as `/today` may redirect to `/home`; they must not create parallel navigation state.

## Capability States

- `operational`: a meaningful durable path exists.
- `partial`: useful behavior exists but one or more boundaries are seed-only, local-only, heuristic, or incomplete.
- `commitment`: the route/UI promises a capability but durable behavior is not yet implemented.
- `absorbed`: the capability is implemented in a new contextual owner while its legacy route remains as a filtered/redirected entry.

## Existing Synapse Module Absorption

| Capability / stable contract | Baseline state | Target role | Primary context | Legacy behavior |
|---|---|---|---|---|
| Copilot / `copilot` / `/copilot` | partial local keyword helper | Mode-aware tutor/assistant: explain, quiz, repair, evidence navigation, workflow commands; explicit Education/Reference/Clinical boundaries | Global dock + node/document threads | Route opens full thread history; old links preserved. |
| Terms / `terms` / `/learn/terms` | operational Course→Unit→Lesson→Exercise loop, 8 exercise types | Terminology, morphology, abbreviations, pronunciation, and translation lens attached to curriculum nodes | Path lesson method + Recall Clinic | Legacy home becomes filtered all-terms explorer. |
| Cards / `cards` / `/learn/cards` | operational/partial SRS and decks | Concept-linked retrieval queue, learner cards, source-derived cards, misconception cards | Today reviews + Path Margin Workspace + Recall Clinic | Deck/card IDs and routes remain. |
| Mnemonics / `mnemonics` | operational/partial local/community seeds | Optional memory hook, user artifact, lesson power-up, reviewed community contribution | Lesson inspector + personal workspace + Rounds | Collections, mine, tags, search, and detail routes preserved. |
| ECG / `ecg` / `/clinical/ecg` | operational generator/drills/cases | Deliberate signal interpretation with progressive scaffolding and case transfer | Clinical skill lab + curriculum checkpoints | All drill/case/review/generative/stats routes remain. |
| Sounds / `sounds` | operational/partial quiz and timer/audio | Auscultation library, discrimination practice, audio rounds, transcript/accessibility | Clinical skill lab + lesson encounter + Rounds | Library, detail, quiz, simulator, stats routes remain. |
| Labs / `labs` | operational/partial rules/reference | Panel interpretation, longitudinal trend reasoning, range/provenance-aware practice | Clinical skill lab + cases + Evidence Shelf | Panel/history/result/ruleset/learn routes remain. |
| Algorithms / `algorithms` | operational/partial branching player | Decision practice, “why next,” variation branches, learning-vs-CDS boundary | Clinical + chapter checkpoints | Play/edit/session/bookmark intents remain; authoring is governed. |
| OR Lab / `orLab` | operational/partial narrative drama | Episodic surgical learning, pre-case rehearsal, branching narrative, transcript | Clinical + Path boss/checkpoint | Home/detail/play/sim/transcript routes remain. |
| Rounds / `rounds` | partial seed feed | Citation-aware audio/case/teach-back feed with transcripts, tags, de-identification, moderation | Rounds | Feed/detail/discover/record/comments/remix routes remain. |
| Buddies / `buddies` | partial local match/chat | Study partner matching, small wards, peer teaching, accountability, safe group lifecycle | Rounds | Discover/requests/matches/groups/profile routes remain. |
| Arena / `arena` | operational/partial battle seeds | Optional pharmacology/microbiology challenge mode with mastery-weighted, nonessential rewards | Rounds events + Path optional encounter | Battle/deck/collection/capsules/shop/clan/league/season/replay routes remain. |

## Existing Synapse Global Capability Absorption

| Capability | Baseline state | Unified owner | Product treatment |
|---|---|---|---|
| Home module grid | operational but generic | Today | Replace first viewport with one prescription, small workload/continuity context, resume, and explicit Browse Path; module inventory remains accessible through Search/Explore. |
| Review | operational/partial | Today + Recall Clinic | Unified review queue explains source, due reason, expected effort, and deferral consequence. |
| Search | operational/partial | Global Search | Index curriculum, concepts, dual-language terminology, evidence, user artifacts, people, routes, and commands; preserve `/search`. |
| Command Palette | operational/partial | Global Command | Rare tools/actions/admin routes; keyboard and touch; role- and context-aware. |
| Concept Hub | operational/partial | Mastery Thread | One concept dossier: mastery dimensions, curriculum locations, errors, resources, evidence, notes, cases, discussions. |
| Cases | operational seeds/player | Clinical + Path checkpoints | Longitudinal patients, forks, confidence, decisions, evidence, debrief, delayed transfer. |
| OSCE | partial keyword scoring | Clinical + Path checkpoint | Rubric-governed station plans, roles, recording/consent, self/peer/AI feedback boundaries. |
| Plan | partial/local | Today | Workload-aware prescription, rotations/on-call/easy days, review debt caps, explainable scheduling. |
| Insights | partial | You + contextual snapshots | Multidimensional mastery, calibration, workload, retention, transfer, gaps, and data confidence. |
| Rewards | client-authoritative risk | You + summary moments | Server-ledger projection; learning-first; no reward clutter in Clinical. |
| Achievements | limited catalog | You + relevant moments | Stable localized catalog tied to meaningful competency/behavior, with secret/accessibility rules. |
| Quests | limited/local | Today + Rounds | Bounded personal/co-op learning missions with caps and alternative paths. |
| Streak | fragile/local | Today + You | Compassionate continuity seam with on-call grace, recovery, and no shame. |
| Shop/Pro | partial/local | You | Cosmetics/subscription transparency; no pay-to-learn critical content, loot boxes, or manipulative scarcity. |
| Profile customization | partial | You | Role, stage, goals, density, game visibility, companion setting, professional identity; display name separate from title. |
| Notifications | partial | Global/Today | Explainable, bundled, quiet-hours/on-call aware, localized, deep-linked, user-controlled. |
| Inbox/chat | partial seeds | Global + Rounds | Threaded, safe, reportable, retention-scoped; node/case context preserved. |
| Library | operational seeds | Evidence Shelf + Clinical | Contextual peek for in-flow use; full library route remains for deliberate browse/search. |
| Diseases | operational seeds | Clinical Evidence Shelf | Structured reference with sources, dates, uncertainty, compare, and learning links. |
| Drugs/classes/interactions | operational/partial | Clinical Evidence Shelf | Drug identity, class, interactions, provenance, safety warnings; separate educational examples from clinical advice. |
| Calculators/tools | operational/partial; range enforcement gap | Clinical tools | Validate inputs and bounds, show formula/source/version/units/limitations, store no PHI by default. |
| Community/rooms/events | partial seeds | Rounds | Structured forums, cohorts, events, moderation, tags, verified roles; not a generic feed. |
| Classes/org | commitment/partial | Rounds + role workspace | Assignments, curriculum alignment, cohorts, faculty insight, institution isolation. |
| Admin/create | unsafe role/self-approval risk | Global role workspace | Evidence-gated studio; author/reviewer/approver/publisher separation; audit and staged preview. |
| Import/export/integrations | toast/commitment | Global command + Workspace | Real background jobs, file validation, progress, errors, retry/resume, checksum, privacy, provenance. |
| Privacy/data | local switches/commitment | You | Real consent, export, delete, retention, AI/social/analytics controls, audit and confirmation. |
| Entitlement/Pro | local-only | You + server authority | Signed/server entitlement, offline grace, restore purchase, transparent feature matrix. |
| Network banner | fixed/partial | Shell state system | Real connectivity/degraded/stale state with offline-capable actions and queued effects. |
| EventBus | in-memory/no subscribers | Domain event layer | Durable outbox/inbox, idempotent consumers, legacy projection, observability, replay/conflict tests. |
| Cloud sync | profile/headline game only | Unified sync boundary | Scoped repositories, conflict policy, dirty/outbox state, user-visible status, reconciliation. |

## Legacy Workspace Capability Absorption

The audited StudyHUB repository is named here only as technical source
provenance. It does not receive a navigation tab, visible section name,
analytics taxonomy, or permanent second database. Its schema-v17 database is a
read-only import source. Each capability receives a functional Synapse domain
owner and task-based name.

| Legacy source capability | Baseline | Synapse owner | Absorbed experience | Contract notes |
|---|---|---|---|---|
| PDF import | operational/partial | Margin Workspace / Evidence Shelf | Import from chapter/course/global command; background validation and provenance | Preserve file hash, remote/source IDs, user ownership, job history. |
| PDF storage | mobile/web implementations | Workspace document repository | Content-addressed user documents with quota/eviction/offline policy | No base64 large blobs; preserve legacy byte/hash reconciliation. |
| PDF reader | strongest operational capability | Margin Workspace | Search, zoom, page progress, side-by-side lesson/evidence, compact bottom sheet | Reader state is per document/user/device-sync policy. |
| Reading progress | operational | Workspace anchor | Resume from Today and chapter; progress never equals lesson mastery | Preserve reading-position fixtures. |
| Bookmarks | operational | Workspace anchors | Document/page/range anchors surfaced in chapter and personal search | Stable mapping through document hashes/versions. |
| Smart notes | operational/partial | Workspace artifacts | Note linked to exact source selection, node, concept, and provenance | Preserve created/updated timestamps and ownership. |
| Annotations | operational/schema-protected | Workspace annotations | Highlight, ink, comment, tag, resolve, share/export policy | PDF and lesson annotations use universal resource refs. |
| Tags and xrefs | schema-protected | Unified personal taxonomy | Cross-link notes, documents, concepts, cases, and cards | Preserve legacy keys and relationships. |
| Legacy `*_find.ts` artifacts | operational/partial | Contextual source search | Locate key terms/claims inside source with concept/search links | Legacy filename stays in provenance only; no AI claim without a source span. |
| Legacy `*_summary.ts` artifacts | operational/partial | Lesson recap | Bounded retrieval recap inside a micro-lesson with source/version/review state | A recap never replaces instruction or satisfies source coverage. |
| Legacy `*_enrich.ts` artifacts | operational/partial | Candidate evidence/detail inputs | Review potentially useful explanations, diagrams, cases, and evidence inside the normal lesson-writing flow | No learner-visible `Enrich` mode, specialist stage, or separate content pipeline; filename grants no authority. |
| Legacy `*_quiz.ts` artifacts | operational/partial | Embedded practice | Node-linked interaction sets and generated-draft review | Practice is embedded in sessions; attempts write durable events and the client cannot reward. |
| Markdown/LaTeX/table renderer | operational | Unified document renderer | Lesson/evidence/note rendering with sanitize and bidi semantics | Security fixtures for unsafe markup. |
| OCR mobile | operational/partial | Evidence ingestion action | Extract draft text from image/PDF with page anchors and confidence | Never overwrite source; review before use. |
| AI service/contracts | partial; client-secret risk | Secure AI gateway | Node/document-scoped tutor/jobs with consent, redaction, citations, model/prompt audit | Remove embedded secrets/shared auth. |
| Chat | schema-protected | Copilot thread | Threads scoped to a node/document/case; resumable and exportable | Preserve legacy messages and content policy. |
| Quiz/card/outline generation | partial | Creator draft pipeline | Draft artifacts with source spans, confidence, review queue | No automatic publication or reward. |
| TTS and cache | partial/schema-protected | Media/accessibility service | Read source/note/lesson with locale voice, playback state, offline cache | User controls, quota, cache invalidation. |
| Planner | operational/partial | Today plan | Unified constraints, availability, due reviews, goals, rotations, on-call grace | One scheduler/source of truth. |
| SRS | operational/partial | Recall Clinic | Migrate review history to canonical cards/concepts and calibrated scheduler | Reconcile intervals/history; preserve timestamps. |
| XP constants | no ledger | Reward projection | Discard client authority, preserve historical intent through import alias if needed | No direct amount migration without audit. |
| 8 achievements | limited | Achievement catalog aliases | Map legacy unlocks to canonical IDs and retain unlock timestamp | No duplicate reward on import. |
| Pomodoro/focus | operational/partial | Today focus mode | Start from prescription; distraction-safe; optional; no passive-time XP | Resume/cancel/notification behavior tested. |
| Mind map | prototype | Mastery Thread / Workspace | Concept map as one view, not a separate app/page | Semantic outline equivalent and performance limits. |
| Dashboard | legacy/generic | Today | Valuable metrics/actions are absorbed; old dashboard itself is not nested. | Preserve intents, not duplicate layout. |
| Notifications | partial | Unified notification service | Plan/review/import/focus reminders with one ID/deep-link registry | Preserve legacy IDs via aliases. |
| Android widget | partial | Today/Recall widgets | Next action, review count, focus/resume; privacy-safe glance states | Preserve migration channel/widget keys. |
| Settings/biometric | partial | You settings/security | One registry/source of truth; device capabilities and fallbacks | Preserve keys and secure-store semantics. |
| Onboarding | operational/partial | Unified onboarding | Role/stage/goals/time/language/privacy/mascot setting; progressive, skippable | Do not force RTL globally before locale. |
| Lesson forks | dormant schema | User-created artifact | Personal/institutional fork with lineage, review, version, share scope | Preserve fork parent/identity. |
| AI jobs | dormant schema | Server job queue | Background, resumable, observable, cancelable, quota-aware | Preserve job history/status; redact payloads. |
| Enrolled courses | dormant schema | Curriculum enrollment | Enrollment/goal/order/preferences against canonical Course IDs | Alias legacy courses; quarantine ambiguous IDs. |

## Cross-Capability Learning Loop

Example of one coherent loop rather than page hopping:

1. Today prescribes a Chapter review because delayed recall and confidence diverged.
2. Path opens the Chapter Trail at the relevant Lesson Station.
3. A short retrieval activity identifies a medication-mechanism misconception.
4. The lesson opens a Terms contrast and a source excerpt in the Margin Workspace.
5. The user annotates the excerpt and creates a concept-linked card.
6. A related lab/case fork tests transfer in Clinical.
7. The debrief explains why-not distractors, shows evidence/version, and updates mastery dimensions.
8. The user records a 60-second teach-back for a private Ward in Rounds.
9. Peer/faculty review becomes a governed teaching artifact.
10. A delayed review confirms or revises mastery; authoritative rewards summarize once.

All ten steps retain the same curriculum node, concept IDs, evidence lineage, session/attempt IDs, and user state.

## Page-Sprawl Prevention Checklist

Before adding a page, answer:

- Is this a stable entity or durable job that must be shareable/restorable?
- Could it be a mode inside the current task?
- Could it be a contextual inspector, sheet, peek, or workspace tool?
- Is it rare enough for Search/Command?
- Does a separate page preserve context or destroy it?
- What existing route must remain, and can that route open the filtered contextual state?

If a page is still justified, it must have one primary job, one primary action, explicit entry/exit, restored state, accessibility, localization, loading/empty/error/offline states, and route ownership.

## Absorption Acceptance Gates

- Every current Synapse route/capability has a row in the machine-readable capability ledger.
- Every StudyHUB protected entity/key has a migration or archive owner.
- No sixth top-level or contextual source-branded destination exists.
- Every mapped label, surface, entry context, and analytics namespace passes
  `contracts/integrity/product-language-policy.v1.json`.
- No duplicate planner, SRS, reward, profile, settings, notification, or sync authority exists.
- Legacy deep links resolve to the same intent through filtered new surfaces or compatibility adapters.
- Critical capabilities are reachable in at most two deliberate navigation decisions from their relevant context.
- Rare features are discoverable through Search/Command and role/context suggestions.
- Clinical contexts contain no irrelevant mascot celebration, shop, league, or XP overlay.
- User files and histories reconcile by count, hash, key, ownership, and relationship after import.
- “Partial” and “commitment” capabilities are labeled honestly until durable behavior is proven.
