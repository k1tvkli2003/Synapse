# State

- Current status: `active`
- Last updated: 2026-07-27T21:10:00
- Owner: Codex

## Current State
The private sync foundation is implemented locally and in the Go service. Academy checkpoints create structured encrypted outbox events without waiting for the network; a foreground dispatcher drains them with bounded retry/backoff, pulls deltas, and reconciles safe structured Academy progress back into the local session repository. Its durable outbox supports a later app relaunch, but actual OS lifecycle and multi-device runtime proof remain open.

The signed content path is now locally executable: a schema-v2 internal manifest binds its own canonical metadata hash, each chapter shard carries a detached Ed25519 envelope, downloaded bytes are re-hashed before installation, the local registry composes shards, and learner activation advances only after the complete release succeeds. A separate content dispatcher retries transport failures without blocking or redefining Academy progress sync. A missing public keyring deliberately leaves remote activation disabled.

## Decisions
| Date | Decision | Reason | Source |
|---|---|---|---|
| 2026-07-27 | Supabase is a private persistence and storage substrate only. | Flutter must never hold direct database access. | User plan |
| 2026-07-27 | Windows is the root device and personal `internal` is the only active content channel. | This is a single-owner personal edition, not a public product. | User plan |
| 2026-07-27 | Raw teach-back/free-text stays local by default. | Sync only needs structured learning outcomes. | User plan |
| 2026-07-27 | Do not create a Jules remote generation session until quota/concurrency can be observed. | A quota probe timed out during TLS handshake. | Jules safety gate |
| 2026-07-27 | Content trust anchors are public, app-pinned, source-scoped, and internal-channel-only. | A private Go gateway transports bytes but must never become the learner's signing authority. | Schema-v2 content implementation |

## Blockers
- Remote Jules scheduling is intentionally deferred: a quota request failed with a TLS handshake timeout, so the account-wide concurrency snapshot is incomplete.
- Runtime verification on actual Windows, Android, and browser devices has not yet been performed.
- The new content-envelope migration has not been applied or inspected remotely in this session: the Supabase MCP is not callable from the current tool inventory.

## Done
- Added the additive schema-v2 content-envelope migration locally; remote application remains explicitly unverified in this session.
- Implemented and tested Go bootstrap, pairing, approval, device-token, revocation, encrypted sync, content-manifest, and recovery endpoints.
- Implemented Flutter device identity, encrypted Recovery Kit export, secure pairing UI/service, encrypted outbox, deterministic projection merge, and structured Academy checkpoint journal.
- Implemented a lazy Academy sync journal, idempotent multi-page push/pull coordinator, safe curriculum reconciler, foreground retry dispatcher, and local session invalidation after remote reconciliation.
- Implemented a schema-v2 signed content transport in Go/Flutter, chapter-shard registry composition, fail-closed public keyring parsing, transport re-hash, local quarantine/repair, atomic learner activation, and a separate non-blocking content dispatcher.
- Scanned the selected source corpus with zero quarantined files: Respiratory 18 chapters, Kidney 86 chapters, Oncology/Hematology 183 chapters (287 total).

## Remaining
- Connect real network/lifecycle signals and prove foreground/relaunch behavior against the deployed private gateway; do not overstate this as OS-guaranteed background sync.
- Extend the reconciler deliberately to the remaining eligible domains (notes, bookmarks, settings, reward/streak ledger) without syncing free-text teach-back.
- Apply and inspect the additive content-envelope migration through a callable controlled Supabase path; provision the real public publisher keyring without placing a private key in Flutter or Go.
- Run Jules behind its gates, validate bilingual packages, and connect verified chapters to the Academy runtime.
- Perform real multi-device offline/reconnect, accessibility, reduced-motion, backup, and restore verification.
