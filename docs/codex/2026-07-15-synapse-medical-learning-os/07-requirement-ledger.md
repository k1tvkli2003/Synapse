# Requirement Ledger

This ledger is the acceptance source of truth. “Preserve” means preserve identity, data, behavior, or reachable intent through an unchanged contract, adapter, redirect, migration, or explicit archive. It never means silently keeping a broken implementation.

| ID | Priority | Requirement | Acceptance evidence |
|---|---|---|---|
| R-001 | P0 | Medical education is the primary product and IA axis. | Today opens with a next-best learning prescription; Path exposes the curriculum; usability tests reach next lesson/review without browsing module grids. |
| R-002 | P0 | Harrison Parts map one-to-one to Courses. | Manifest contains exactly 20 stable course source keys in audited ordinal order. |
| R-003 | P0 | Harrison Chapters map one-to-one to Chapters. | Manifest contains exactly 1,138 stable chapter source keys, continuous within each course. |
| R-004 | P0 | Explicit Lesson directories map one-to-one to immutable source-provenance anchors, never automatically to learner-facing lessons or sessions. | Manifest contains exactly 186 source-anchor keys under 73 Chapters; every approved Unit/Micro-lesson retains its source-atom lineage. |
| R-005 | P0 | Keep the structural scaffold body-free, then exhaustively extract and author the curriculum through a quarantined bilingual pipeline. | Every source atom is reconciled; EN/FA pairs pass schema, semantic, evidence, medical, accessibility, and review-separation gates before a content release becomes visible. |
| R-006 | P0 | Unsegmented chapters remain explicit and non-rewarding until reviewed. | 1,065 chapters use `content_state=unsegmented`; no permanent lesson/progress/reward IDs are minted. |
| R-007 | P0 | Preserve every current Synapse capability and commitment. | Capability ledger has an owner, target context, status, migration path, and verification target for every current route/module/surface. |
| R-008 | P0 | Preserve all existing route and deep-link contracts. | Snapshot tests cover all declared paths/helpers; changed destinations use explicit redirects/adapters. |
| R-009 | P0 | Preserve 12 `ModuleKey` IDs and five `ShellBranch` values. | Serialized registry snapshot remains compatible; additive presentation names do not mutate stable IDs. |
| R-010 | P0 | Preserve core domain IDs/models/events. | Archive fixtures deserialize; event translation tests cover legacy and new envelopes. |
| R-011 | P0 | Preserve SharedPreferences and app schema contracts. | Key inventory, schema fixture, migrations, and rollback/recovery tests exist. |
| R-012 | P0 | Preserve Supabase tables, policies, functions, and triggers until versioned migrations prove replacement. | Disposable-project migration and RLS matrix pass. |
| R-013 | P0 | Fully absorb the legacy StudyHUB source; do not bolt it on. | No source-branded tab/mini-app/iframe, label, accessibility name, notification channel, widget title, search category, or analytics namespace; every protected source capability maps to a functional Synapse context and domain owner. |
| R-014 | P0 | Preserve StudyHUB schema-v17 data and stable identities. | Migrations 2→17 are represented by fixtures/adapters; remoteId/sourceKey/contentHash/courseId and composite identities survive. |
| R-015 | P0 | Remove StudyHUB shared credentials and client secrets before reuse. | Secret scan, proxy architecture, user-scoped auth, redaction, and no-secret client artifacts. |
| R-016 | P0 | Flutter supports Android, iOS, Windows, macOS, Linux, and Web. | CI matrix plus real build/smoke evidence on suitable runners. |
| R-017 | P0 | English is the canonical source locale. | All user-facing strings use stable semantic keys in the English catalog. |
| R-018 | P0 | Persian is a first-class native RTL environment. | Catalog parity, locale persistence, RTL/mixed-script screenshots, fonts, bidi-safe components, widgets, notifications, search, and accessibility tests pass. |
| R-019 | P1 | Additional locales use readiness tiers and fallback policy. | Locale registry exposes shipped/beta/hidden states; incomplete catalogs cannot silently ship. |
| R-020 | P0 | No preference/approval pause for ordinary in-scope decisions. | Decision log records evidence, rubric, critique, choice, and verification; work continues autonomously. |
| R-021 | P1 | Research broadly across medical education, adjacent products, learning science, social systems, and unclaimed opportunities. | Opportunity Atlas contains dated sources, patterns, risks, hypotheses, and product consequences. |
| R-022 | P0 | Product is coherent and avoids page-per-option sprawl. | IA reachability matrix and task-flow tests; secondary actions live in contextual sheets/drawers/workspaces when appropriate. |
| R-023 | P0 | Preserve five-branch compatibility while relabeling presentation as Today/Path/Clinical/Rounds/You. | Branch-index behavior and old URLs work; new labels are localized presentation data. |
| R-024 | P1 | Search, Command, Copilot, Library/Evidence, and Margin Workspace are contextual cross-cutting surfaces. | They are reachable from relevant workflows without adding top-level branch clutter or a source-branded destination. |
| R-025 | P0 | Separate educational, reference, and clinical-decision-support claims. | Mode banners, provenance, citation, recency, uncertainty, scope, and escalation policies have tests. |
| R-026 | P0 | Protect privacy and PHI across notes, AI, community, analytics, and sync. | Data classification, consent, redaction, retention/deletion, least privilege, and audit-log evidence. |
| R-027 | P0 | Content governance separates author, reviewer, approver, and publisher. | RBAC/RLS prevents self-approval and unauthorized publication; evidence/version/date required. |
| R-028 | P0 | AI output is grounded, bounded, and quarantined until review. | Source requirements, uncertainty, refusal/escalation, PHI rules, evaluation suite, and audit trail pass. |
| R-029 | P0 | Reward economy is server-authoritative and event-ledger based. | Atomic/idempotent grant tests, replay, reconciliation, rule-version, caps, and anti-tamper tests pass. |
| R-030 | P0 | Rewards favor mastery and transfer, not tap volume. | Duplicate/farming/no-op events grant nothing; high-level retrieval and calibrated reasoning have bounded weight. |
| R-031 | P1 | Streaks are compassionate and compatible with clinical schedules. | Recovery/on-call/grace policy tests; no shame copy or coercive loss mechanics. |
| R-032 | P1 | Achievements, quests, leagues, co-op wards, and raids have a complete implementation-ready catalog. | Seed schema, stable IDs, localization keys, rarity, secret rules, telemetry, accessibility, and abuse checks. |
| R-033 | P0 | Brand and mascots are original, ownable, memorable, and professionally safe. | Multiple concept families, similarity screen, state/emotion matrix, small-size tests, dark/light/RTL compositions, asset provenance. |
| R-034 | P0 | Several genuinely different visual directions are generated and automatically scored. | Preview ledger includes prompts, assets, rubric scores, critique pass, selected direction, and rejection reasons. |
| R-035 | P0 | Study mode is warm/gameful; Clinical mode is quiet/evidence-led within one system. | Token/motion/content-density rules and representative screenshots pass coherence and trust rubrics. |
| R-036 | P0 | Accessibility is systemic. | Semantics, screen-reader, focus/keyboard, 200% text, reduced motion, contrast, touch target, and painter-equivalent tests. |
| R-037 | P0 | Offline-first behavior is bounded and honest. | Cache quotas, eviction, checksums, pack versions, stale states, conflict policy, recovery, and offline/restart tests. |
| R-038 | P0 | Raw 211.74 MiB corpus is not blindly bundled. | Versioned manifest and on-demand pack design; bundle and storage budgets pass. |
| R-039 | P0 | Importer sniffs real media bytes and validates references. | JPEG-in-PNG, parent fallback, unresolved, unreferenced, repeated, and corrupt assets are classified/quarantined. |
| R-040 | P0 | Importer handles path, empty-file, sidecar, duplicate, and heading anomalies safely. | All audited anomaly classes have deterministic fixtures and no auto-publish path. |
| R-041 | P1 | StudyHUB PDF, notes, annotations, planner, SRS, OCR/AI jobs, notifications, and widgets become first-class contextual capabilities. | Absorption matrix and end-to-end workflows pass with a single user/content/progress authority. |
| R-042 | P1 | Current modules become learning methods within the curriculum. | Terms/Cards/Mnemonics/ECG/Sounds/Labs/Algorithms/OR Lab/Cases/OSCE/Arena/Rounds/Buddies appear at contextually justified points. |
| R-043 | P1 | Learning progression supports Recall→Explain→Connect→Diagnose→Decide→Defend→Teach→Transfer. | Activity contracts, mastery dimensions, session plans, and transfer checks demonstrate each level. |
| R-044 | P1 | Personalization is explainable. | Every prescription exposes “why this now,” factors, alternatives, defer action, and privacy controls. |
| R-045 | P1 | Social design supports learning and professionalism. | De-identification, moderation, consent, citation, age/role boundaries, anti-harassment, and wellbeing controls pass. |
| R-046 | P1 | Professional and Study modes respect audience differences. | Student, resident, and physician workflows can tune density, goals, notifications, and game visibility without splitting the app. |
| R-047 | P0 | Error handling covers every durable boundary. | Loading/empty/error/stale/offline/permission/retry/conflict/recovery states and telemetry are verified. |
| R-048 | P0 | Performance is budgeted before breadth expands. | Startup, frame, memory, search, parser, media, list, network, and bundle budgets exist and are enforced. |
| R-049 | P0 | CI, signing, packaging, release metadata, widgets, notifications, and deep links are productionized. | Six-platform release checklist and artifact inspection pass. |
| R-050 | P0 | Planning contains at least 320 atomic, dependency-aware steps. | WBS validator reports count, unique IDs, owners, dependencies, acceptance evidence, and no unresolved P0 gaps. |
| R-051 | P0 | The final `$perfect` loop is mandatory. | Independent critic passes, issue ledger, repeated verification, and completion gate are recorded after implementation phases. |
| R-052 | P0 | Every preserved, absorbed, and new capability passes the Capability Masterpiece Gate; working happy-path code is not completion. | The 76/76 completion ledger requires purpose, placement, workflow, Night Shift craft, states, responsive/input, EN/FA/RTL, accessibility, motion, Data Plane, security, performance, verification, and adversarial evidence with no false-done state. |
| R-053 | P0 | A shared Data Plane governs every product domain rather than isolated feature storage. | Each capability names canonical entity families, truth authority, and all 15 identity/migration/provenance/validation/persistence/search/cache/offline/sync/conflict/privacy/security/audit/recovery/observability concerns. |
| R-054 | P0 | Capability status and evidence survive deterministic regeneration without permitting hand-edited generated truth. | Reviewed changes live in `capability-evidence.v1.json`; generation merges the overlay, source receipts pass, and the semantic verifier rejects unsupported `verified`, retirement, or `not_applicable`. |
| R-055 | P1 | Repeated high-risk Synapse workflows become validated project-specific skills rather than undocumented habits. | Each Goal-v2 skill has trigger-rich metadata, progressive disclosure, deterministic scripts/fixtures where needed, realistic forward tests, and passing `quick_validate.py`. |
| R-056 | P0 | Root application construction and Content Lead authoring remain separate with a versioned integration boundary. | Root owns Flutter/runtime/Data Plane/UX/platform work; Content Lead owns corpus/Jules/EN-FA bodies; reviewed packages cross only through validated contracts and no implicit upload. |
| R-057 | P0 | Approximately 90% of current implementation effort is allocated to the unified Academy learning core until its acceptance sequence passes. | Active plans, progress records, commits when authorized, and runtime evidence primarily advance the Guided Path, Study Workspace, EN/FA sessions, learning Data Plane, and directly enabling package/accessibility/motion/performance work. |
| R-058 | P0 | StudyHUB study capabilities dissolve into the contextual Synapse Academy workspace rather than surviving as a brand, sub-app, section, or parallel information architecture. | Reading, annotation, notes, bookmarks, documents, focus, planning, and recall are reachable from the active curriculum context; product-language and navigation gates report zero StudyHUB surfaces. |
| R-059 | P0 | Secondary super-app capabilities are preserved but broad expansion is deferred until the Academy learning-core acceptance sequence passes. | Preservation contracts stay green; current secondary routes/data remain intact; capability evidence never equates deferral with verification or authorized retirement. |

## Requirement Change Rule

New ideas may be added, but no P0 requirement is removed, weakened, or hidden by a presentation change. Any conflict is recorded as an architecture decision with affected contracts and evidence.
