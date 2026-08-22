# Verification

## Summary
- Result: partially verified
- Last verified: 2026-07-27

## Checks
| Check | Command/Method | Result | Evidence |
|---|---|---|---|
| Go private gateway | `go test ./...` in `services/personal_sync` | passed | Bootstrap, pairing, approval, token, revoke, sync, content, and recovery coverage |
| Go schema-v2 content transport | `go test ./...` in `services/personal_sync` after envelope/timestamp work | passed | Gateway preserves full envelope, ETag behavior, and byte-integrity serving |
| Core content metadata | `dart analyze` + `dart test -r compact test/personal_sync_models_test.dart` in `packages/core` | passed | Schema-v2 manifest head binding and invalid hash rejection |
| Signed chapter delivery | Focused analyzer + `dart test -r compact test/personal_content_delivery_test.dart test/curriculum_release_trust_test.dart` in `packages/services` | passed | Ed25519 verification, hash rejection, shard composition, learner activation, and local head acceptance |
| App content dispatcher/keyring | Focused `flutter test --no-pub test/personal_content_trust_provider_test.dart test/personal_content_dispatcher_test.dart` | passed | Public keyring parsing, offline deferral, and bounded transient retry |
| Encrypted Flutter identity/recovery | Focused Flutter tests for identity, Recovery Kit, sync service, and learner key provider | passed | 13 tests |
| Outbox, merge, and Academy reconciliation | Focused `dart test -r compact` across outbox, projection, journal, reconciler, and progress repository tests in `packages/services` | passed | 22 tests, including reordered events, malformed receipts, cross-device conflict convergence, and multi-page drains |
| Flutter dispatcher and Academy integration | `flutter test --no-pub test/personal_sync_dispatcher_test.dart test/academy_screens_test.dart` | passed | 10 tests; the unpaired Academy path no longer emits the extra Data Plane creation warning |
| Flutter provider/Academy syntax and types | Focused `dart analyze` for app root, sync providers, device service, dispatcher, Academy, and Settings | passed | No issues |
| Selected corpus inventory | `python -m tool.curriculum.source_scan` for courses 07, 09, 04 | passed | 18 + 86 + 183 chapters, zero quarantine |
| Supabase boundary | Local migration inspection plus architecture checks | partial | Private schema is defined locally and Flutter has no direct data-plane path; current-session remote MCP inspection was unavailable |

## Not Run
- Real Windows, Android, and browser pairing/sync runtime tests.
- Thirty-day-offline convergence, backup/restore rehearsal, and content package rollback runtime tests.
- Applying or inspecting `20260727143000_personal_content_release_envelopes.sql` against the remote Supabase project, provisioning a real keyring, and serving a real signed package from private Storage.
- Full app verification suite and visual regression capture for the next package-activation work.

## Known Issues
- Jules quota discovery currently cannot prove safe scheduling because its API probe encountered a TLS handshake timeout. No remote generation session was created.
- The dispatcher is foreground-compatible with durable relaunch recovery; it is not yet proof of OS-guaranteed background execution or live connectivity detection on every platform.
