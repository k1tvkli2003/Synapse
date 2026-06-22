# Synapse

> **One unified, cross-platform medical super-app.** A single **Flutter** codebase
> targeting **Android, iOS, macOS, Windows, Linux and Web** — natively, and
> responsive to any screen size.

Synapse fuses twelve learning + clinical-companion ideas into **one organism**:
every module is a *surface* over a shared core (a Concept knowledge-graph, a
unified content model, Concept Mastery, a typed Event Bus, and shared
reward/SRS engines). A weakness found anywhere pulls remediation from
everywhere; a concept learned in one place raises its mastery in all.

> ⚕️ **For educational training only — not for real clinical decision making.**

---

## What's inside

**Foundations**
- A **Melos monorepo**: `apps/app` + `packages/{core, ui, engines, services, config}`.
- A **design system** (`synapse_ui`) — `SynapseTokens` theme extension, a 4px
  spacing/radius/motion scale, Material 3 dark-default theme (`#050816`), a
  responsive breakpoint system (compact→xlarge), and a full widget library.
- **Domain models** (`synapse_core`) — immutable, value-equal (no codegen), the
  Concept graph, the unified `LearnItem` model, `ConceptMastery`, the reward
  economy, SRS, every module's types, and the typed **Event Bus**.

**Shared engines** (`synapse_engines`, pure Dart, unit-tested)
- Gamification: XP curve, streak rollover, hearts, leagues, cross-module quests,
  an achievement catalogue.
- SRS scheduler (SM-2 variant) + forgetting forecast.
- A deterministic, versioned **lab rule engine** (CBC/BMP/LFT) with an audit trail.
- An **ECG waveform generator** (no image assets — tracings are synthesised).

**The twelve modules + flagship features**
| Area | Modules |
|------|---------|
| Learn | **Terms** (Duolingo-style, 8 exercise types) · **Cards** (flashcards + SRS) · **Mnemonics** (community, votes, contribute) |
| Clinical | **ECG** (generated tracings + drill) · **Sounds** (auscultation quiz + audio bar) · **Labs** (live rule engine) · **Algorithms** (flowchart player) · **OR Lab** (audio drama with synced cues) |
| Social | **Rounds** (audio feed) · **Study Buddies** (matching) · **Arena** (antibiotic-vs-bacteria lane battle) |
| Glue | **Copilot** (grounded, cited AI tutor) · **Cases** (multi-module Virtual Patient) · Daily Review · Global Search · Concept Hub · Insights · Rewards/Quests/Achievements |

**Integration backbone** — every activity flows through one `GameNotifier` entry
point that awards rewards, updates Concept Mastery, advances quests/achievements
and publishes `SynapseEvent`s on the Event Bus. The `/concept/:id` hub shows
every related item across all modules — the "see also" that makes the knowledge
feel connected.

---

## Run it

Requires the Flutter SDK (stable, Dart 3.5+).

```bash
# from the repo root
flutter pub get -C apps/app          # resolves the path-dependency graph

# run on any platform
flutter run -C apps/app -d chrome    # Web
flutter run -C apps/app -d linux     # Linux desktop
flutter run -C apps/app -d macos     # macOS
flutter run -C apps/app              # connected Android/iOS device

# build
flutter build web    --release  # (verified)
flutter build apk    --release
flutter build linux  --release
```

The app is **offline-first**: it boots on bundled local repositories + seed
data with no backend credentials. Supabase/AI gateway can be wired behind the
same interfaces via `--dart-define` (`SUPABASE_URL`, `AI_GATEWAY_URL`, …).

### With Melos
```bash
dart pub global activate melos
melos bootstrap
melos run analyze   # flutter analyze across all packages
melos run test
```

---

## Verify

```bash
cd packages/engines && dart test     # 17 engine tests
cd apps/app && flutter test          # app boot smoke test
cd apps/app && flutter analyze       # zero issues
```

---

## Design & engineering notes

- **No code generation.** Models use hand-written immutable classes (+
  `equatable`) and Riverpod uses manual providers — a deliberate choice for a
  deterministic, single-pass build. The architecture is otherwise faithful to
  the spec (freezed/riverpod-gen could be swapped in later).
- **Fully offline visuals.** No runtime font fetching; ECG tracings, waveforms,
  charts and the knowledge graph are drawn with `CustomPainter`.
- Built applying the project's skill playbooks: **/style** (visual system),
  **/anatomy** (IA & flows), **/function** (wiring & correctness), **/dataman**
  (real seed datasets) and **/ideas** (the "one organism" product thesis).

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the canonical decisions, the
monorepo layout, the state topology and the module-integration contract.

The original step-by-step prompt series lives in `Synapse-App.rar`.
