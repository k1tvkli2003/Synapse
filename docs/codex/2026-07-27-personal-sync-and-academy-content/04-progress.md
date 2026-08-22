# Progress

## Log
| Time | Status | Entry | Evidence |
|---|---|---|---|
| 2026-07-27T05:45:27 | active | Task docs created. | docs/codex/2026-07-27-personal-sync-and-academy-content/ |
| 2026-07-27 | recorded | Existing private Supabase baseline migration is retained; current-session remote MCP verification is unavailable. | `supabase/migrations/20260726113451_synapse_private_personal_sync_gateway.sql` |
| 2026-07-27 | completed | Go pairing/recovery/sync/content contracts and Flutter secure device identity were implemented. | `services/personal_sync/`, `apps/app/lib/data/personal_sync/` |
| 2026-07-27 | completed | Academy checkpoint journal writes only structured encrypted outbox events after local persistence. | `packages/services/lib/src/sync/personal_sync_curriculum_journal.dart` |
| 2026-07-27 | completed | Source scans and no-mutation Jules plans established the 287-chapter curriculum inventory. | `.jules/preparation/` |
| 2026-07-27 | completed | Academy events now drain through an idempotent delta coordinator and reconcile safe progress into the local session store. | `personal_sync_outbox.dart`, `personal_sync_curriculum_reconciler.dart` |
| 2026-07-27 | completed | App-level foreground dispatcher coalesces requests, backs off transient gateway failures, and retries durable work after relaunch. | `apps/app/lib/data/personal_sync/personal_sync_dispatcher.dart` |
| 2026-07-27 | completed locally | Schema-v2 content metadata/envelope, chapter-shard install/repair, pinned public-key parsing, and a separate content refresh dispatcher were added with focused tests. | `supabase/migrations/20260727143000_personal_content_release_envelopes.sql`, `personal_content_delivery.dart`, `personal_content_dispatcher.dart` |

## Done So Far
- Device keys, Recovery Kit encryption/export, bootstrap, QR pairing, approval, token refresh, revocation, and gateway tests are in place.
- The encrypted outbox serializes valid Data Plane kind names and the projection store covers exact-once ledger records, monotonic progress, deterministic LWW state, and tombstones.
- Academy remote hydration reconstructs only structured attempts/history/progress, rejects malformed receipt identities, and never transports raw teach-back/free text.
- An unpaired Academy session no longer opens the encrypted Data Plane merely to make a sync no-op.
- Respiratory, Kidney, and Oncology/Hematology were scanned before any content generation or remote mutation.
- The content channel refuses v1 manifests, a non-`internal` channel, a lower/equivocating head, incomplete authorization, a transport hash mismatch, unsigned content, or learner activation of a scaffold.

## Next
- Apply/verify the additive content-envelope migration and provision a real public keyring before attempting remote package delivery.
- Add real connectivity/lifecycle hooks and run the private gateway on Windows, Android, and Web before claiming multi-device readiness.
- Retry Jules discovery only after the quota API can provide an authoritative full account view.
