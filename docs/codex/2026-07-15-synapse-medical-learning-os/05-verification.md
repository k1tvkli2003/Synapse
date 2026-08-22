# Verification

## Summary

- Result: partial
- Interpretation: audit/planning, restored LUMA identity production, WBS-031–040 preservation, foundation WBS-101–103/105–119, local Cardiology preparation, and the synthetic EN/FA Academy Course→Deep Study/Session→completion/resume slice pass their recorded local gates. The current real repository root gate proves immutable Deep Study, exact gated reveal, semantic reading resume, repeatable non-empty Web output and all current executable checks. WBS-104/120, real reviewed medical content, external processing/review, PDF/annotation/indexed learner storage, native deep-link/database/runtime proof, articulated motion, accessibility/performance breadth, real-host platforms, and release gates remain incomplete.
- Last verified: 2026-07-22
- Source repositories: Harrison-like corpus unchanged; Synapse worktree intentionally dirty and not staged/committed
- Verification rule: a compile-only signal never proves product completion

## Baseline Checks

| Check | Command or method | Result | Evidence |
|---|---|---|---|
| Synapse source identity | `git rev-parse HEAD` | pass: `9067be0834ae80495e1112728ef0c82ae36100cc` | Git repository |
| Protected archive identity | SHA-256 | pass: `084ED47D3817253D56E22ADE99318CF2A81465910B5CFF09B366DC2FF9F750F7` | `Synapse-App.rar` |
| Runtime dependency resolution | `flutter pub get` in isolated copy | partial: packages resolved; Windows symlink gate exited non-zero | isolated baseline log |
| Static analysis | `flutter analyze --no-pub` in isolated copy | pass: no issues | isolated baseline log |
| App tests | `flutter test --no-pub` in isolated copy | pass: 6 tests | isolated baseline log |
| Release web build | `flutter build web --release --no-pub` in isolated copy | pass; WASM dry run also passed | isolated baseline build |
| Live desktop/mobile runtime | local HTTP server + Chrome/Playwright | pass for representative onboarding, Today/home, Terms, lesson, ECG, Rounds, and Library routes | `assets/baseline/` |
| Harrison hierarchy | deterministic filesystem audit | pass as a measured snapshot: 20/1,138/186 | source audit |
| Critics JSON | parser validation | pass: 16 findings | frozen JSON outside repository |
| Critics PDF | Chrome render + Poppler page render + visual inspection | pass: 25 A4 pages; no remaining clipped titles/columns | `assets/critics-report-synapse-medical-learning-os-2026-07-15.pdf` |
| Critics PDF metadata | Poppler `pdfinfo` | pass: tagged, 25 pages, A4, no encryption, no JavaScript | `pdfinfo` output |
| Critics PDF identity | SHA-256 | pass: `17C042E181E5CD5839C69A97D89EFB30267808C45C2CAACFB9380FA6D5E4A11F` | frozen report |
| Atomic WBS | `python tool/validate_wbs.py ... --expected 440` | pass: 440 ordered, unique, dependency-safe steps | `14-wbs.md`, validator output |
| Preservation generation parity | bundled Python + `generate_preservation_contracts.py --check` | pass: nine outputs match fresh source derivation; zero failures | `contracts/preservation/preservation-manifest.v1.json` |
| Preservation semantic gate | bundled Python + `verify_preservation_contracts.py` | pass: 31 checks; zero P0; 141 declarations/149 concrete routes, 89 helpers, 16 owned persistence entries, 447 deep-link fixtures, 76 preserved capabilities plus three registered additive Academy route owners | `preservation-verification.v1.json`, SHA-256 `BCCCAAE5…2DC2` |
| Archived Dart models/events | `dart test test/preservation_fixture_test.dart` in `packages/core` | pass: two tests; four models and all ten `SynapseEvent` variants round-trip exactly | `packages/core/test/preservation_fixture_test.dart` |
| Pure-Dart core analysis | `dart analyze` in `packages/core` | pass: no issues | local command receipt |
| Curriculum manifest and canonical serialization | `dart test packages/core/test` plus root `dart analyze` | pass within the 46-test Core suite; deterministic key order/hash, source/release drift, missing localization, unpublishable pair, v1/v2 Deep Study compatibility, answer isolation, stable-node Workspace and semantic reading-position invariants | curriculum source/tests |
| Capability completion generator/tests | `dart run melos run capabilities` | pass: seven tests, exact 76-preserved-plus-3-new (79 total) parity; 76 planned, three reviewed Academy records active, zero verified | `tool/product/`; `capability-completion.v1.json` |
| Capability semantic verification | `verify_capability_completion.py` | pass: 79 records, 15 Data Plane concerns and 14 gates per record, zero issues, zero verified | `capability-completion-verification.v1.json`, SHA-256 `9C0F9C52…FEB5` |
| Synapse project skills | live auditor/closure runs plus Skill Creator `quick_validate.py` in UTF-8 mode | pass: both skills valid and execute against current ledger | `C:/Users/K1/.codex/skills/synapse-masterpiece-gate/`; `C:/Users/K1/.codex/skills/synapse-capability-closure/` |
| WMR2-01 wordmark renders | `tool/identity/render_wordmark_assets.cjs --install` + `test_wordmark_assets.py` | pass: 21 outputs; seven glyphs, surviving `A` counter, open `P`, zero clipping through 24 px | `28-wordmark-production.md`, `wordmark/renders/verification.json` |
| MCR4-01/ICR4-04 source extraction | bundled Python + `tool/identity/extract_mcr4_evidence_guide.py` | pass: exact approval hashes/dimensions locked; 37 deterministic source outputs | `31-selected-identity-production.md`, `identity-source-manifest.json` |
| Selected source verification | bundled Python + `tool/identity/test_mcr4_evidence_guide.py` | pass: zero failures; adaptive radius `301.597 ≤ 304`, one-component monochrome, optical 48/24/16 cues, six unclipped pose families | `identity-source-verification.json`, SHA-256 `121ADA3E…1481` |
| Selected platform export/install | bundled Node/Sharp + `tool/identity/export_mcr4_evidence_guide.cjs --install` | pass: 188 platform/package/install records and 27 Flutter runtime assets | `platform-manifest.json`, SHA-256 `8C50AE0E…7C9` |
| Selected platform verification | bundled Python + `tool/identity/test_mcr4_platform_identity.py --require-install` | pass: zero failures; installed-byte parity, Apple opacity, Android adaptive/themed safety, PWA masks, seven-size ICO, Linux and Flutter assets | `platform-verification.json`, SHA-256 `417529C2…F0A` |
| Restored LUMA source production | bundled Python + `tool/identity/build_luma_facefront.py --install` | pass: exact ICR2-01/LUMA source hashes locked; 37 source outputs, six clean mascot poses, 188 package/install records, and 27 active Flutter assets | `32-restored-luma-facefront-production.md`, source manifest SHA-256 `91A6D89A…EF5D`, platform manifest SHA-256 `C9702E87…A661` |
| Restored LUMA source/platform verification | bundled Python + `tool/identity/test_luma_facefront.py --require-install` | pass: zero failures; adaptive/monochrome safe zone `278.051 ≤ 304`, one-component mono, 48/24/16 px cues, install parity, Apple/PWA/ICO/Linux/Flutter checks; active runtime roots are forced to `luma_facefront` | source receipt SHA-256 `7B4DA20F…702F`, platform receipt SHA-256 `D35A3656…C88F` |
| Superseded Foldkin canonical renders | `tool/identity/render_identity_assets.cjs` + `test_identity_assets.py` | historical pass: 34 renders; proves old pipeline only, not selected identity | `27-identity-production.md`, `renders/verification.json` |
| Superseded Foldkin platform export | `tool/identity/export_platform_identity.cjs --install` | historical pass: 152 package/install outputs; installed bytes have since been replaced by the selected identity | `platforms/platform-manifest.json` |
| Superseded Foldkin platform verification | `tool/identity/test_platform_identity.py --require-install` | historical pass: hashes, dimensions, alpha, safe radius, themed icon, PWA masks, ICO, install parity | `platforms/platform-verification.json` |
| Presentation manifests | PowerShell JSON/XML parse | pass: PWA manifest, Android manifests/adaptive resources, iOS and macOS plists parse | installed Flutter platform files |
| Flutter identity widget format | `dart format apps/app/lib/brand/synapse_identity.dart` | pass: unchanged; dependency-resolution warning remains because package config is absent | source output |
| Locked workspace bootstrap | `dart run melos run bootstrap:locked` | pass on Flutter 3.44.0 / Dart 3.12.0 | root `pubspec.lock` |
| Root static analysis | `dart analyze` | pass: zero issues across workspace | `dart run melos run verify` |
| Root package tests | serial `flutter test --no-pub` across all packages with tests | pass: 223 tests across ten packages | app 37, config 14, core 46, engines 26, foundation 9, motion 10, observability 6, services 66, fixtures 4, UI 5 |
| Secret gate | unit tests + `tool/security/scan_secrets.py` | pass: 426 files / 4,333,156 bytes; zero findings | root verification receipt |
| Product-language gate | unit tests + `tool/integrity/verify_product_language.py` | pass: 242 product files / 32 absorbed capability names; one Synapse identity, zero legacy-brand leaks | root verification receipt |
| Architecture gate | unit tests + `tool/architecture/validate_architecture.py` | pass: nine packages / 157 Dart files | `architecture-verification.v1.json`, SHA-256 `AD5D4C48…3ECB` |
| Generated-output gate | `tool/generated/verify_generated.py` | pass: three checks / 11 hashed inputs | `generated-verification.v1.json`, SHA-256 `3CAF8367…63F4` |
| Real-repository Web release | `flutter build web --release --no-pub` through Melos | pass; WASM dry run succeeded | `apps/app/build/web` local artifact |
| Performance budget gate | unit tests + `tool/performance/verify_performance_budgets.py` | pass: 15 static probes / eight journeys / zero warnings | `contracts/performance/performance-verification.v1.json` |
| Web bundle baseline | deterministic artifact probes | pass/target: 48,540,155 B total / 75 files; 4,144,998 B main JS raw; 1,212,384 B gzip-9; 110,175 B deferred Workspace chunk; 7,229,467 B largest WASM; 43 Flutter assets / 5,467,781 B | performance receipt SHA-256 `61E23F5F…AC53` |
| Active Flutter asset budget | `flutter_declared_assets_bytes` reads `apps/app/pubspec.yaml` | pass/target: 35 declared files / 3,970,013 B; LUMA 27 files / 3,879,968 B; historical MCR4 assets are undeclared and not treated as shipped payload | `contracts/performance/performance-verification.v1.json`, SHA-256 `F9F8B8B0…46B4` |
| Foundation root gate | `dart run melos run verify` | pass for all current executable gates; not a clean-workspace/commit proof | `33-repository-toolchain-foundation.md` |
| Cardiology static source atomizer tests | `python -m unittest tool.curriculum.test_source_scan -v` | pass: 6 tests, including no-execution sentinel, exact locators, root-free determinism, false-positive rejection, static-template recognition, and drift detection | `tool/curriculum/test_source_scan.py` |
| Cardiology source-scan deterministic check | `python -m tool.curriculum.source_scan ... --course 06 --check ... --json-summary` | pass: 865 documents, 64,816 atoms, 0 quarantined documents; manifest `f4e61ebf…060a` | local v1.1.1 receipt; `38-content-authoring-policy-and-jules-plan.md` |
| Cardiology TypeScript safety/accounting | static scan finding audit | pass: 341 inert TypeScript documents, 0 static-parse failures, 0 unresolved dynamic/template findings, 43 statically linked media-template documents, and 69 contributor-only sidecars | local v1.1.1 receipt |
| Content authoring policy and plan schemas | Draft 2020-12 validation | pass for source scan, authoring policy, and content task plan | `contracts/curriculum/`; local receipts |
| Content task planner tests | `python -m unittest tool.jules.test_content_task_plan -v` | pass: 6 tests, including full reconciliation, raw-text-free boundary, policy hard gates, deterministic drift checks, and scan-sensitive plan identity | `tool/jules/test_content_task_plan.py` |
| Cardiology content task-plan deterministic check | `python -m tool.jules.content_task_plan ... --check ... --json-summary` | pass: 61 chapters / 865 documents / 64,816 atoms / 15 lanes; plan `8422c49b…37d0`; execution remains blocked | local v1.1.1 plan; `38-content-authoring-policy-and-jules-plan.md` |

## Academy Vertical Slice — 2026-07-18

| Check | Command or method | Result | Boundary |
|---|---|---|---|
| Targeted static analysis | `flutter analyze packages/core packages/services` | pass: zero issues | Does not replace full-root verification after all pending edits. |
| Local progress repository | `flutter test packages/services/test/curriculum_session_progress_repository_test.dart --no-pub` | pass: nine tests | Restart persistence, serialized advance/completion, idempotency, stale/conflicting writes, frozen-v1 migration, v1 rollback round-trip, failed-write preservation, v2 summary corruption, global receipt duplication, and non-destructive future-schema audit. |
| Immutable package registry | `flutter test packages/services/test/curriculum_package_repository_test.dart` | pass: 17 tests | Trusted transport/canonical hashes, strict stored canonical bytes/record parity, backwards-compatible v1 recovery field, truthful idempotency, quarantine, immutable collision, target eligibility, activation/rollback/recovery receipts and audit, corrupt-control-plane mutation refusal, self-consistent drift restore, and same-store repository serialization. Production publisher key custody/signing/distribution and cross-isolate/process arbitration remain open. |
| Catalog index/cache repository | `flutter test packages/services/test/curriculum_catalog_repository_test.dart` | pass: 22 tests | Exact declared playback ownership/lineage, deterministic scoped EN/FA/source-origin search, missing scope, kind/limit/tie behavior, independent LRU release/node budgets, oversized bypass, same-release single-flight/drift rejection, error retry, clear/targeted/active-lookup invalidation, unrelated-build isolation, activation-race retry, target-isolated offline boot, and non-destructive corrupt/unsupported states. Uses small synthetic manifests; it is contract/race proof, not real-catalog latency or heap proof. |
| Signed curriculum release trust | `dart test packages/services/test/curriculum_release_trust_test.dart` | pass within the 66-test Services suite | Strict envelope parsing, scoped/time-valid/revocable pinned Ed25519 anchors, restart re-audit, legacy-hash learner denial, bundled→signed upgrade, and signed no-downgrade behavior. This is verifier/repository code-path proof, not production signing/key-rotation/distribution proof. |
| Stable-node Study Workspace repository | `dart test packages/services/test/curriculum_study_workspace_repository_test.dart` | pass: six focused tests and within the 66-test Services suite | Notes/Bookmark/Focus persistence, release-stable identity/provenance, compare-and-set revisions, same-store serialization, idempotent latest focus receipt and corruption audit. The current bounded SharedPreferences adapter is neither indexed nor encrypted and is not the final migrated StudyHUB store. |
| Semantic reading-position repository | Core/Services reading-state tests | pass: three Core + five Services tests | Locale/release-stable semantic identity, JSON bounds, restart, exact-retry idempotency, stale-writer rejection, source listing, revision clear and privacy-safe integrity drift. Stores no package text, answer or progress authority. |
| Core + Services package suites | `dart test packages/core/test`; `dart test packages/services/test` | pass: 46 Core + 66 Services tests | Current package-wide source of truth after Deep Study, gated reveal and semantic resume. |
| App suite | `(cd apps/app) flutter test --reporter compact` | pass: 37 tests | Covers the current app suite, including Academy, Workspace, bootstrap, identity, presentation, cloud mapping and smoke tests; it is not native-device or backend integration proof. |
| Academy behavior/routes | `(cd apps/app) flutter test test/academy_screens_test.dart` | pass: seven tests | Closed package state, package-bound feedback, real hierarchy route, Course→Workspace navigation, Persian RTL, 200% text, and restart-restored completion. |
| Study Workspace behavior | `(cd apps/app) flutter test test/academy_study_workspace_test.dart` | pass: eight tests | Reviewed-context rendering, Notes/Bookmark restart, Focus logging, exact progress-authoritative recap reveal, corrupt-progress fail-closed behavior, automatic semantic save/restore, corrupt reading-state non-blocking recovery, retired-anchor fallback/disclosure and Persian RTL at 200% text. Actual PDF/page annotation and fresh browser/native Workspace runtime remain open. |
| Academy geometry goldens | `(cd apps/app) flutter test test/academy_visual_test.dart` | pass: seven specimens | Compact EN home, medium FA path, wide EN session, compact/wide Workspace and compact/wide Deep Study. Flutter Ahem makes these geometry/regression proof only, not font or final visual-fidelity proof. |
| English Web runtime | `flutter run -d web-server --web-port=59321 -t tool/academy_preview.dart` | pass | Actual Home → Course path → Session → selected answer → approved rationale → completion → Course return; no browser warning/error. Synthetic non-medical package only. |
| Persian Web runtime | `flutter run -d web-server --web-port=59323 -t tool/academy_preview.dart --dart-define=SYNAPSE_PREVIEW_LOCALE=fa` | pass | Actual RTL Home → Course path → Persian Session → Persian feedback → Persian completion; no browser warning/error. Mixed-language fixture labels found in the first pass were corrected and re-run. |
| Compact widget layout | 390×844 plus Persian 200% text widget tests | pass | Compact status is icon-only with semantics/tooltip; path rail has finite intrinsic height; no test overflow. |
| Compact live-browser capture | Browser viewport override at 390×844 | inconclusive: Flutter Canvas screenshot was tiled/blank after override | Treated as a browser-capture limitation, not UI pass/fail; widget and golden geometry remain the available compact evidence. Real compact-device runtime is still required. |
| Windows runtime | `flutter run -d windows -t tool/academy_preview.dart` | blocked: Flutter plugins require symlink support and Windows Developer Mode is disabled | No host setting was changed. Windows build/runtime remains open. |
| Runtime console | in-app browser warning/error log on EN and FA flows | pass: zero warning/error entries | Does not prove network, accessibility tree, frame pacing, or platform packaging. |

The synthetic fixture is under `apps/app/lib/dev/`, is explicitly non-medical, and is not imported by production entrypoints. No corpus body was copied into app source and no remote processing occurred. ADR-022 and `39-academy-session-progress-data-plane.md` define the exact implemented and open boundaries.

## Contextual PDF Reader — 2026-07-22

| Check | Command or method | Result | Boundary |
|---|---|---|---|
| Real Reader widget path | `(cd apps/app) flutter test --no-pub test/academy_resource_document_screen_test.dart` | pass: four tests | Includes a valid one-page PDF parsed/rendered by `pdfrx`, truthful metadata/blob failure states, toolbar/page state and no Flutter exception. It is a host widget test, not a physical-device render proof. |
| Persian compact accessibility | same Reader suite at 390×844 and 200% text | pass | Confirms RTL at the live title, localized controls, explicit Search semantics and zero overflow/exception. It does not replace TalkBack/VoiceOver/Narrator testing. |
| Native content-addressed disk store | `(cd apps/app) flutter test --no-pub test/resource_document_blob_store_io_test.dart` | pass: two tests | Real temporary filesystem, SHA-256 sharding, one-page parse, dedupe, resolve and same-length corruption refusal; mobile/desktop application-support permissions remain device gates. |
| Reader/native-store static analysis | `(cd apps/app) flutter analyze --no-pub ...` over four source/test paths | pass: zero issues | Targeted only; a fresh root verification follows after the next coherent Data Plane slice. |
| Universal resource model/repository | `dart test packages/core/test/resource_artifact_models_test.dart packages/services/test/resource_workspace_repository_test.dart` | pass: 15 tests | Covers serialization, bounded ink and local restart/integrity behavior; the current JSON registry is not the final indexed/encrypted store. |
| PDF import publication boundary | `(cd apps/app) flutter test --no-pub test/resource_document_import_service_test.dart` | pass: two tests | Metadata/cross-reference publication, dedupe and name sanitation; no external upload or medical content review. |
| Contextual Sources behavior | `(cd apps/app) flutter test --no-pub test/academy_study_workspace_test.dart` | pass in the nine-test Workspace suite | Only explicitly attached documents appear; detach tombstones the edge without deleting the private PDF or artifacts. |
| Fresh preservation generation/check | `python tool/preservation/generate_preservation_contracts.py --check --json` plus semantic verifier | pass: 31 checks | 142 route declarations, 150 concrete routes, 91 helpers, 45 enums, 18 persistence keys, 450 deep-link fixtures and 76 preserved capabilities; source/fixture compatibility only. |

The exact data/security/rollback decision is recorded in
`44-academy-contextual-pdf-reader-data-plane.md`. Large/encrypted/malformed PDF
coverage, storage pressure, indexed/encrypted learner state, export/delete,
sync conflicts, backup/restore, real assistive technology and all six native/Web
runtime paths remain open.

## Indexed Private Data Plane and Quality CI — 2026-07-23

| Check | Command or method | Result | Boundary |
|---|---|---|---|
| Complete Services suite | `dart test packages/services/test --reporter compact` | pass: 110 tests | Includes encrypted record store, Workspace/reading projections, journal, coordinator, rollback, migration-aware gateways and 503-record keyset pagination. It is host logic/database proof, not real platform secure-vault proof. |
| App Data Plane composition | `(cd apps/app) flutter test --no-pub test/learner_data_plane_provider_test.dart` | pass | In-memory Drift proves exact migration, retained rollback JSON, completed journal and Indexed-only post-activation writes. |
| Secure key boundary | `(cd apps/app) flutter test --no-pub test/secure_learner_data_key_provider_test.dart` | pass: four tests | Concurrent creation/reuse, corrupt envelope, stalled-vault timeout and retry; no Android/iOS/macOS/Windows/Linux/Web vault runtime claim. |
| Reader downgrade regression | `(cd apps/app) flutter test --no-pub test/academy_resource_document_screen_test.dart` | pass: four tests | Explicit Legacy overrides prove safe fallback behavior independently from Indexed activation. |
| Workspace downgrade regression | `(cd apps/app) flutter test --no-pub test/academy_study_workspace_test.dart` | pass: nine tests | Explicit Legacy overrides protect Reader/Workspace UX, RTL and 200%-text behavior. |
| Drift Web runtime bytes | `verify_web_runtime_assets(Path.cwd())` through `tool/generated/verify_generated.py` | pass | Locks `sqlite3.wasm` and `drift_worker.js` bytes to Drift 2.34.2 / sqlite3 3.5.0; fresh browser persistence proof remains open. |
| GitHub workflow syntax/policy | PyYAML parse plus `python -m unittest tool.actions.test_verify_actions_workflows` | pass: mappings and four policy tests | Enforces full-SHA pins, least privilege, safe triggers, credentials, Flutter/lockfile/full-gate contracts; `actionlint` is not installed and no GitHub-hosted run exists. |

ADR-028 and `45-academy-indexed-private-data-plane-and-quality-ci.md` define
the single-authority migration, rollback and CI boundaries. User-facing privacy
lifecycle, StudyHUB import, authenticated sync/conflicts, key rotation,
backup/restore, real target storage/vault behavior and release/signing/deploy
workflows remain open.

## Baseline Visual Findings

- The current dark theme is internally consistent and safety notices are a useful foundation.
- The home experience presents a generic card grid rather than an educational prescription or visible curriculum.
- Bottom controls and the floating Copilot action can overlap or clip content at 390x844.
- Study and clinical contexts share nearly the same visual tone.
- A visible `Dr. Dr.` profile-label defect exists.
- The current product has no memorable original mascot system or visual narrative.

## Required Verification Matrix for Implementation

Every completed phase must provide the relevant subset of this matrix:

- Unit and property tests for deterministic domain logic.
- Golden and screenshot tests for English/Persian, LTR/RTL, light/dark, compact/expanded, text scale, and reduced motion.
- Compatibility tests for route strings, deep links, IDs, persistence keys, archived schema fixtures, and import manifests.
- Integration tests for offline/restart/replay/conflict behavior.
- Security tests for role boundaries, RLS, secrets, PHI redaction, idempotency, tamper attempts, and client/server authority.
- Accessibility checks for semantics, screen readers, keyboard/focus traversal, touch targets, contrast, zoom, and zero-overflow layouts.
- Performance budgets for startup, frame pacing, memory, bundle/pack sizes, parsing, media decode, search, and long-list behavior.
- Real platform builds and smoke tests for Android, iOS, Windows, macOS, Linux, and Web on suitable hosts.
- Signed artifact metadata, manifest/entitlement, deep-link, notification, widget, and store-identity checks.

## Not Yet Run

- App-wide tests for capabilities not yet implemented in the later rebuild phases; the current 37-test App suite and Phase-01 pure-Dart compatibility suites pass.
- Fresh real-browser and native runtime traversal of the new Study Workspace; current EN/FA Web runtime evidence predates that surface.
- Native Android runtime on a device.
- Windows desktop build/runtime on a host with the required Visual Studio workload.
- iOS/macOS build, signing, and runtime.
- Linux build/runtime.
- Backend migration and RLS tests against a disposable Supabase project.
- App-wide Persian catalog/layout, font, bidi/scientific mirroring, search, and non-Academy surface checks beyond the representative Academy slice.
- Final medical-domain editorial review.
- External Jules pilot and all generated lesson/quiz/recap review; intentionally not run because corpus rights and exact remote-revision visibility are not cleared.
- Real-host launcher, splash, task-switcher, Dock/taskbar, PWA-install, themed-icon, Apple, and Linux proof for restored LUMA Facefront.
- Blind no-name association (including dental/tooth reading), trademark, and current visual-similarity review for restored LUMA Facefront and WMR2-01.
- Work-docs content validation after governance closeout.

## Known Baseline Issues

- The deterministic root lockfile exists but is not committed; WBS-104 and the clean-workspace WBS-120 gate remain active.
- Plugin resolution and root bootstrap now succeed, but Windows native build proof still requires the missing Visual Studio C++ workload.
- Some Android SDK licenses are unaccepted.
- Android release signing and metadata are not production-ready; main manifest lacks the expected network declaration.
- macOS network entitlement and platform packaging identities are incomplete.
- A local least-privilege quality workflow is present, but it is uncommitted,
  unpushed and unobserved on GitHub-hosted runners; no release/deploy/signing
  workflow exists.
- Current reward, admin/content governance, sync, localization, and several product claims are not production-authoritative.
