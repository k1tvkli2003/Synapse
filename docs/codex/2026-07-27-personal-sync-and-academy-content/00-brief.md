# Personal Sync and Academy Content

- Task ID: `2026-07-27-personal-sync-and-academy-content`
- Status: `active`
- Created: 2026-07-27T05:45:27
- Language: en

## Request
Implement Synapse as a single-owner, local-first medical learning app for personal use. Keep the Duolingo-like Academy as the product center, add secure multi-device continuity through a private Go gateway, and prepare Respiratory, Kidney, and Oncology/Hematology as the first complete curriculum inventory.

## Success Criteria
- Windows is the initial root device; Android and Web can be securely paired without email-based registration.
- Learner data remains usable offline and syncs deterministically after reconnecting without duplicate XP, mastery, streak, or attempt history.
- Personal sync payloads are end-to-end encrypted; Flutter never directly accesses Supabase.
- The private content channel can safely deliver verified, signed, chapter-sharded packages.
- The three prioritized courses contain exactly 287 source chapters in the planned order: Respiratory (18), Kidney (86), Oncology/Hematology (183).
- The Academy remains the first-run focus; no public-release, marketplace, or multi-user product work is introduced.

## Context
Synapse already has a Flutter Academy, local encrypted learner persistence, a Night Shift visual direction, and an approved LUMA character/icon system. The user has enabled a Supabase MCP connection for the private cloud layer. The source corpus at `C:\Users\K1\Desktop\Harrison` is a user-created simulated Harrison-like corpus, not the original textbook.

## In Scope
- Private Go/Supabase gateway contracts, pairing, revocation, recovery, encrypted sync ledger, and signed content manifests.
- Flutter device identity, Recovery Kit, encrypted outbox, deterministic projection merge, and Academy checkpoint journaling.
- Source inventory, granular content planning, and a gated Jules workflow for bilingual micro-lessons.
- Academy-first integration of contextual Notes, Evidence, Review, and Library capabilities.

## Out of Scope
- App Store, Play Store, beta/public release, marketing, billing, public registration, multi-user RBAC, or publisher workflows.
- Direct Flutter access to Supabase tables, buckets, or credentials.
- Syncing raw free-text teach-back responses by default.

## Assumptions
- The Windows installation is the first trusted/root device.
- `internal` is the only visible personal content channel.
- Supabase is used only behind the Go gateway; its MCP connection is available for controlled schema and verification work.
- Remote Jules generation starts only after the account-wide quota/concurrency snapshot can be read successfully.
