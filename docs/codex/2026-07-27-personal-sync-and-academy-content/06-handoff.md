# Handoff

## Outcome
The personal-edition foundation is actively being built. It has a private Supabase boundary, an implementation-tested Go gateway, secure Flutter device primitives, an Academy-first encrypted event journal, a tested foreground reconciliation path, and a locally tested schema-v2 signed chapter-package path. It is not yet a complete multi-device product because remote migration/key provisioning, runtime proof, OS lifecycle behavior, and real package delivery remain open.

## Changed Artifacts
- `services/personal_sync/` — private Go gateway contracts, cryptography, persistence adapters, and tests.
- `supabase/migrations/20260726113451_synapse_private_personal_sync_gateway.sql` — private schema and bucket boundary.
- `supabase/migrations/20260727143000_personal_content_release_envelopes.sql` — additive full Ed25519 chapter-envelope columns and consistency gate (not remotely applied/verified in this session).
- `apps/app/lib/data/personal_sync/` and `apps/app/lib/state/personal_sync_provider.dart` — Flutter identity, recovery, pairing, and provider wiring.
- `packages/services/lib/src/sync/` — encrypted outbox, projection store, Academy curriculum journal, and Academy reconciler.
- `apps/app/lib/data/personal_sync/personal_sync_dispatcher.dart` — foreground coalescing/retry dispatcher with durable relaunch recovery.
- `packages/services/lib/src/sync/personal_content_delivery.dart` and `apps/app/lib/data/personal_sync/personal_content_dispatcher.dart` — verified signed shard transport plus independent foreground retry scheduling.
- `docs/codex/2026-07-27-personal-sync-and-academy-content/` — truthful state, plan, and verification record.

## How To Continue
1. Apply and inspect the additive Supabase migration through a callable controlled path, then provision the real public keyring through `SYNAPSE_CONTENT_TRUST_ANCHORS_JSON` (never a private key).
2. Add real connectivity/lifecycle hooks around the existing foreground dispatchers without delaying the session player.
3. Re-run Jules quota discovery; only then schedule bounded, validation-gated batches in Respiratory → Kidney → Oncology/Hematology order.
4. Verify real Windows root + Android + Web pairing, content activation, and offline convergence before claiming readiness.

## Done
- The 287-chapter source inventory is known and planned with no corpus text leaked into planning artifacts.
- The Academy write path is local-authoritative and safely no-ops if sync is unavailable.
- Existing visual direction and unrelated user work were preserved.

## Remaining
- Remote content migration/key provisioning, real content delivery, validated bilingual lesson generation, real connectivity/lifecycle integration, multi-device runtime tests, and encrypted backup/restore rehearsal.

## Verification
- See `05-verification.md`; focused tests passed, while full runtime/device proof remains explicitly outstanding.
