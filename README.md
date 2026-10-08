# Synapse

> One unified, cross-platform medical super-app. A single Flutter codebase targeting Android, iOS, macOS, Windows, Linux, and Web — natively, responsive to any screen size.

Synapse fuses twelve learning and clinical-companion ideas into one organism: every module is a surface over a shared core (Concept knowledge-graph, unified content model, Concept Mastery, typed Event Bus, shared reward/SRS engines). A weakness found anywhere pulls remediation from everywhere; a concept learned in one place raises mastery everywhere.

> For educational training only — not for real clinical decision making.

## What's inside

**Foundations**

- Melos monorepo: `apps/app` + `packages/{core, ui, engines, services, config, foundation, motion, observability, fixtures}`.
- Design system (`synapse_ui`): `SynapseTokens` theme extension, 4px spacing/radius/motion scale, Material 3 dark-default theme (`#050816`), responsive breakpoints (compact to xlarge), full widget library.
- Domain models (`synapse_core`): immutable, value-equal (no codegen) — Concept graph, unified `LearnItem`, `ConceptMastery`, reward economy, SRS, every module's types, typed Event Bus.

**Shared engines** (`synapse_engines`, pure Dart, unit-tested)

- Gamification: XP curve, streak rollover, hearts, leagues, cross-module quests, achievement catalogue.
- SRS scheduler (SM-2 variant) + forgetting forecast.
- Deterministic, versioned lab rule engine (CBC/BMP/LFT) with audit trail.
- ECG waveform generator (synthesised tracings, no image assets).
- Data-driven clinical calculator engine + drug-interaction checker.
- Predictive Learner Model: Bayesian Knowledge Tracing + retention forecast + shared difficulty policy.

**Twelve modules + flagship features**

| Area | Modules |
|------|---------|
| Learn | Terms (Duolingo-style, 8 exercise types), Cards (flashcards + SRS), Mnemonics (community, votes, contribute) |
| Clinical | ECG (generated tracings + drill), Sounds (auscultation quiz), Labs (live rule engine), Algorithms (flowchart player), OR Lab (audio drama), OSCE (AI standardized patient, rubric-scored) |
| Social | Rounds (audio feed), Study Buddies (matching), Arena (antibiotic-vs-bacteria battle), Community (rooms, channels, events, leaderboard) |
| Glue | Copilot (grounded, cited, safety-guarded), Cases (virtual patient), Study Plan (adaptive daily orchestrator), Command Palette, Daily Review, Global Search, Concept Hub, Insights |
| Reference | Diseases compendium, Drug Bank + interactions, data-driven Calculators, Library (atlas, imaging, procedures, guidelines, journal) |
| Platform | Shop, Synapse Pro entitlements, Settings (export/delete/privacy), CMS/admin + authoring, Cohort mode, Import/Export |

Every activity flows through one `GameNotifier` entry point: rewards, Concept Mastery updates, quest/achievement progress, and `SynapseEvent`s on the Event Bus. The `/concept/:id` hub shows everything related to a concept across modules and reference banks. Full route map in `ROUTES.md`, architecture in `ARCHITECTURE.md`.

## Tech stack

Flutter/Dart (Melos workspace), Supabase + AI gateway wired behind interfaces via `--dart-define` (`SUPABASE_URL`, `AI_GATEWAY_URL`), offline-first bundled repositories and seed data — no backend credentials needed to boot.

## Getting started

Requires the Flutter SDK (stable, Dart 3.5+).

```bash
flutter pub get -C apps/app
flutter run -C apps/app -d chrome
flutter run -C apps/app -d linux
flutter build web --release   # verified
flutter build apk --release
```

Melos scripts cover bootstrap from the committed lockfile, analyze, format check, per-package tests, and web build prep.

## Status

Active development across a large monorepo. Foundations, engines, and module surfaces exist with contracts and docs; backend wiring and content depth remain open work.
