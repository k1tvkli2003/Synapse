# Academy Indexed Private Data Plane and Quality CI

Date: 2026-07-23  
Status: implemented locally; release/deployment intentionally not configured

## Outcome

The private learner Workspace graph and semantic document-reading positions now
have one encrypted, indexed Drift/SQLite authority behind migration-aware
repositories. Existing SharedPreferences registries remain intact as exact
rollback sources; they are neither deleted nor dual-written. Application
providers activate the indexed repository only after a journaled migration and
reconciliation pass succeeds. A failed migration keeps the legacy adapter as
the sole live authority for that run.

This closes the first production-shaped storage transition for the Academy
vertical slice. It does not claim complete privacy lifecycle, cloud sync,
backup/restore, StudyHUB import, six-platform runtime proof, or public release
readiness.

## Runtime Architecture

| Layer | Implemented boundary | Authority rule |
|---|---|---|
| Platform key vault | `SecureLearnerDataKeyProvider` stores one versioned 32-byte root-key envelope through `flutter_secure_storage`; read/write operations time out after five seconds and failed initialization is retryable. | Key material never enters SQLite, SharedPreferences, exports, analytics, or logs. A missing/corrupt/stalled vault fails closed. |
| Indexed store | `EncryptedIndexedLearnerRecordStore` uses AES-256-GCM payload encryption, authenticated associated data and keyed HMAC-SHA256 identity/scope indexes. | SQLite sees operational namespace/kind/revision/tombstone/time fields, never clear learner IDs, source scopes, note bodies or artifact payloads. |
| Workspace projection | `IndexedResourceWorkspaceRepository` reconstructs the complete resource/document/anchor/artifact graph from private records and validates repository-level invariants. | Curriculum/package bodies remain immutable; only learner-owned graph state lives here. |
| Reading projection | `IndexedResourceDocumentReadingStateRepository` stores reward-neutral semantic resume state with compare-and-set revisions and tombstone clear. | Reading position never becomes Session completion, mastery, XP or clinical authority. |
| Migration journal | `LearnerDataMigrationJournal` records source snapshot hash, cursor, counts, state and privacy-safe error code across running/completed/failed/rolled-back states. | The journal is control evidence, not learner content or a second projection. |
| Migration coordinator | `LegacyLearnerDataMigrationCoordinator` imports deterministic snapshots in bounded chunks, tolerates commit-then-interruption retry, audits/reconciles the destination and retains the original legacy keys. | Promotion occurs only after exact post-import proof. No legacy key is cleared. |
| Runtime gateway | Migration-aware Workspace/reading repositories queue callers behind one activation attempt. | Success routes all calls to Indexed; failure routes all calls to Legacy. There is no dual-write window. |
| Application composition | Riverpod providers own the Drift database, secure key store, encrypted record store, journal, coordinator and migration-aware public repositories. | Screens consume the gateway interfaces rather than selecting a storage engine. |

## Scale and Integrity

- Private mutations are transactional, compare-and-set and bounded to 500
  records per batch.
- Queries expose opaque HMAC-bound keyset cursors ordered by timestamp and
  record hash. Projection scans therefore do not truncate at the former
  500-record boundary; tests reconcile 503 tied-timestamp records exactly once.
- Tombstones preserve delete intent without making absence ambiguous during
  migration or future sync work.
- Store audits decrypt and authenticate each record, while projection audits
  filter by namespace and continue schema checks even when another namespace is
  damaged.
- Migration rollback is explicit and requires quiesced writes. The coordinator
  exports the current Indexed projection back into the retained legacy schema,
  verifies it, and only then marks the journal rolled back.

## Web Runtime Asset Contract

Drift Web depends on two separately shipped runtime files. The generated-output
gate now binds `apps/app/web/sqlite3.wasm` and
`apps/app/web/drift_worker.js` to byte length, SHA-256 and the exact `drift` and
`sqlite3` versions in `pubspec.lock`. The contract lives at
`contracts/generated/web-runtime-assets.v1.json`; package upgrades must
regenerate and review both assets in the same change.

## GitHub Actions Boundary

`.github/workflows/quality.yml` is a least-privilege quality workflow, not a
release workflow. It:

- runs on `main` pushes, `main` pull requests and manual dispatch;
- grants only `contents: read`;
- pins checkout, Flutter setup and artifact upload actions to reviewed commit
  SHAs;
- installs Flutter 3.44.0 stable, disables telemetry, enforces the committed
  lockfile and rejects lockfile mutation;
- runs the complete `dart run melos run verify` product gate;
- self-verifies trigger, permission, credential, version and immutable action-pin
  policy through the root `actions` gate;
- retains the public Web build for seven days and non-user-data verification
  receipts for fourteen days;
- cancels superseded pull-request runs but never cancels a main-branch run.

`.github/dependabot.yml` proposes weekly, reviewable GitHub Actions and Dart/pub
dependency updates. It does not bypass the same quality gate.

No signing secret, OIDC trust, environment, store credential, Pages deploy,
release tag, artifact publication or production channel was created. Existing
application identifiers and signing lineage remain unchanged. A release
workflow is blocked on an explicit identity/channel/signing decision and real
platform evidence, not on CI syntax.

## Verification

| Proof | Current result | Honest boundary |
|---|---|---|
| Full Services suite | 110 tests pass | Includes encrypted store, cursor pagination, indexed projections, journal, migration, rollback and gateways; not device secure-vault proof. |
| App provider integration | pass | In-memory Drift proves migration, retained rollback JSON, completed journal and Indexed-only writes after activation. |
| Secure key provider | four tests pass | Covers reuse, concurrent initialization, corrupt envelope, timeout and retry; real Android/iOS/macOS/Windows/Linux/Web vault behavior remains open. |
| Reader and Workspace regression | four Reader plus nine Workspace tests pass | Tests intentionally override Legacy to prove safe downgrade; the separate provider test proves Indexed activation. |
| Web runtime contract | local check passes | Exact current bytes and lock versions pass; browser persistence/runtime still needs a fresh host traversal. |
| Workflow syntax/policy | both YAML documents parse locally; four policy tests pass | The workflow has not been committed, pushed, or observed on GitHub-hosted runners. |

## Rollback and Failure Policy

1. A secure-vault or migration failure must not start a background Indexed
   mutation and then expose Legacy fallback concurrently.
2. Legacy source keys and rollback snapshots remain until an explicit,
   evidence-backed retirement decision; this phase authorizes no deletion.
3. Corrupt encrypted rows are preserved for repair/export evidence and never
   silently replaced by empty learner state.
4. Feature presentation may be disabled without deleting either storage form.
5. CI artifacts contain public build output and deterministic receipts only;
   corpus sources, learner records, keys and local databases are excluded.

## Remaining Gates

- user-facing export/delete plus verified cryptographic erasure semantics;
- root-key rotation, lost-vault recovery and backup/restore drills;
- authenticated outbox/sync, server acknowledgements and conflict UX;
- journaled StudyHUB documents/Notes/Bookmarks/positions/annotations import;
- indexed personal search, note history/tags and representative large-PDF
  storage/pressure/corruption benchmarks;
- real Web IndexedDB/worker restart and all five native target vault/database
  runtime proofs;
- observed GitHub-hosted CI; platform matrix, signing, store and deployment
  workflows only after their identities, channels and credentials are approved.
