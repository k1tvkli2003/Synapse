# Plan

## Approach
Keep the learner experience local and responsive, then layer a private, encrypted synchronization plane beneath it. The Go modular monolith owns all Supabase interaction. The Academy writes only structured, encrypted events locally; the foreground coordinator then drains durable deltas, pulls projections, and hydrates safe learner state without blocking a lesson.

## Steps
| Step | Status | Notes |
|---|---|---|
| 1 | completed | Record preservation boundaries and remove public-release work from this execution track. |
| 2 | in progress | Finish secure pairing, Recovery Kit, revocation, and device-token lifecycle through the Go gateway. |
| 3 | completed | Persist encrypted structured Academy events locally and implement deterministic merge projections plus safe Academy hydration. |
| 4 | in progress | Keep the foreground reconciliation coordinator reliable across retry/backoff and durable relaunch recovery; add real connectivity/lifecycle integration and runtime proof later. |
| 5 | in progress | Schema-v2 signed immutable chapter packages now install/verify/activate locally; remote migration, publisher key provisioning, and deployed storage proof remain open. |
| 6 | in progress | Inventory the three source courses, plan granular bilingual micro-lessons, then execute Jules generation only behind validation gates. |
| 7 | planned | Connect verified packages to the Night Shift Academy, test offline/online convergence on Windows, Android, and Web, and rehearse encrypted backup/restore. |

## Interfaces and Artifacts
- Go API: bootstrap, pairing, device-token, devices, encrypted sync push/pull, manifest/packages, recovery rotation.
- Supabase schema: `synapse_private` tables plus private `synapse-personal-content` storage bucket.
- Flutter: `PersonalDeviceSyncService`, encrypted outbox/projection store, `PersonalSyncCurriculumJournal`, and `personalSyncCurriculumJournalProvider`.
- Content delivery: public pinned-key configuration, schema-v2 channel head verification, chapter-shard install/repair, activation only after a complete signed release, and a foreground retry dispatcher independent from learner-event sync.
- Content preparation: `.jules/preparation/` source scans and task plans; no raw corpus text is copied into those files.

## Risks
- Jules account quota visibility is currently not reliable because the quota request hit a TLS handshake timeout; remote generation must not be scheduled blindly.
- Device sync is not ready until its new reconciliation path is proven against the real Go gateway on Windows, Android, and Web, including offline/reconnect and concurrent-device cases.
- Cross-device correctness needs runtime proof, not only unit tests.
- The current tool context does not expose a callable Supabase MCP operation. The additive schema migration is present locally but its remote application must be verified through an available controlled path before deployment.

## Acceptance Checks
- Pairing tokens, QR expiration, revocation, recovery rotation, replay protection, and event idempotency are tested.
- Clock-skewed concurrent merges converge deterministically; tombstones do not resurrect deleted state.
- Academy checkpoint journaling never blocks local learning or stores raw free text remotely.
- A malformed/unsigned content package cannot activate.
- Three devices can pair, study offline, reconnect, and converge without data loss or duplicate rewards.
