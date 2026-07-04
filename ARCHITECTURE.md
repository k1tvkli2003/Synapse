# Synapse — Architecture

The canonical, non-negotiable decisions every part of the app respects.

## 1. Stack
- **Flutter** (stable) / **Dart 3**, sound null-safety, Material 3.
- **One codebase → six platforms**: Android, iOS, macOS, Windows, Linux, Web.
- **Routing:** `go_router` (declarative, deep links, web URLs) — `StatefulShellRoute`.
- **State / DI:** **Riverpod 2** (manual providers; no codegen).
- **Local/offline:** `shared_preferences` via a schema-versioned `PersistedStore`.
  The data layer is abstracted so Supabase/drift can be swapped in later.
- **Models:** hand-written immutable classes with `equatable` value-equality.

> Deliberate deviation from the prompt series: **freezed + riverpod-gen are not
> used.** Hand-written models + manual providers keep the build deterministic and
> dependency-light. The contracts (immutability, copyWith, JSON, value equality,
> notifiers, async providers) are identical, so the generators can be reintroduced
> without changing call sites.

## 2. Monorepo layout (Melos)
```
synapse/
  apps/app/                 # the Flutter app — all 6 platforms, all UI
  packages/
    core/      (synapse_core)     # domain models, Concept graph, Event Bus,
                                  #   reference + evidence models            (pure Dart)
    ui/        (synapse_ui)       # tokens, theme, responsive, widget library,
                                  #   reference widgets, haptics/sfx services
    engines/   (synapse_engines)  # gamification, SRS, lab rules, ECG gen,
                                  #   calculators, interactions, learner model (pure Dart)
    services/  (synapse_services) # repositories + seed data (offline-first):
                                  #   12 modules + Diseases/Drugs/Tools/Library/OSCE
    config/    (synapse_config)   # AppConfig, FeatureFlags, version
  melos.yaml  pubspec.yaml  analysis_options.yaml  ROUTES.md
```
Dependency direction: `config` ← `core` ← `engines`/`ui` ← `services` ← `app`.
The shared packages guarantee the twelve modules **and the Part III reference
banks** reuse identical models, widgets and reward/SRS/mastery logic instead of
forking. Reference entries (diseases, drugs, tools, library) are Concept-anchored
`LearnItem`s, so they are searchable and appear on the `/concept/:id` hub exactly
like study content — reference and practice are one body of knowledge.

## 3. Responsive contract
Breakpoints: `compact (<600)`, `medium (600–839)`, `expanded (840–1199)`,
`large (1200–1599)`, `xlarge (≥1600)` via `context.bp`. Adaptive navigation:
`NavigationBar` (compact) → `NavigationRail` (medium/expanded) → extended rail
(large+). Hub grid reflows 2→3→4→5 columns. List/detail modules use
`TwoPaneScaffold` on wide screens. No fixed pixel widths.

## 4. State topology (Riverpod)
**Global**
- `sharedPreferencesProvider` (overridden in `main`), `appConfigProvider`,
  `featureFlagsProvider`, `repositoryProvider`, `eventBusProvider`,
  `networkOnlineProvider`.
- `settingsProvider` (persisted `UserPrefs`) → `themeModeProvider`.
- `userProvider` (persisted profile).
- **`gameProvider` (`GameNotifier`) — the integration hub.** Owns gamification
  state + concept mastery + quests + achievement counters. Persisted.
- `srsProvider`, `notificationsProvider`, `copilotProvider`, `audioProvider`,
  `mnemonicsProvider`, `toastProvider`.
- Fine-grained selectors: `xpProvider`, `heartsProvider`, `streakProvider`,
  `leagueProvider`, `walletProvider`, `dueCountProvider`, `weakConceptsProvider`,
  `masteryMapProvider`, `achievementsProvider`, `questsListProvider`.

Rules: no provider reaches into another's internals; cross-cutting effects flow
through `gameProvider` and the event bus. Persist prefs/progress, not caches.

## 5. The Event Bus & integration contract
`SynapseEvent` (sealed) is published on `EventBus` (a broadcast stream). Modules
**publish** on meaningful actions; `gameProvider` is the single transactional
entry point that, for one activity:
1. publishes `ConceptStudied` / `ConceptStruggled` per concept,
2. updates `ConceptMastery` (EMA aggregation across modules),
3. awards XP/gems/hearts/streak via `GamificationEngine`,
4. advances cross-module quests (`QuestEngine`),
5. updates achievement counters (`AchievementEngine`),
6. publishes `RewardGranted` / `LessonCompleted` / `CaseCompleted`,
7. fires toasts.

This is why an action in one module produces effects in ≥2 others (proved by
tests). The `/concept/:id` hub renders every related `LearnItem` across modules.

**Every module** links its items to `Concept`s, registers `LearnItem`s (search +
hub), reports outcomes through `gameProvider`, and uses the shared shells
(`ModuleScaffold`, `DrillShell`, `QuizFeedbackBanner`, `AudioPlayerBar`) and the
route map. No bespoke nav/state/social stacks.

## 6. Design system
`SynapseTokens` (a `ThemeExtension`) is the single source of brand semantics:
colors, the module-accent map (`tokens.accentOf(module)`), spacing, radii,
motion. Dark is default (`#050816`), light is fully supported, theme switching is
animated. WCAG-minded contrast, 44dp targets, `Semantics`, and `reduceMotion`
support throughout.

## 7. Routing
See `lib/router/routes.dart` for the typed path helpers and `router.dart` for the
five-branch `StatefulShellRoute`. Drills/players render full-screen above the
shell; list/detail/hub screens live inside their branch. Feature-flagged routes
resolve to a "coming soon" surface so deep links never break.

## 8. Testing
- `packages/engines/test` — deterministic unit tests for every engine.
- `apps/app/test` — a boot smoke test.
- `flutter analyze` is clean across the workspace.
