# Repository and Toolchain Foundation

## Outcome

WBS-101–103 and WBS-105–119 are implemented and verified locally. The Flutter
3.44.0 / Dart 3.12.0 workspace now has deterministic dependency resolution,
typed configuration and feature flags, privacy-aware observability, a tested
bootstrap state machine, stable serialization rules, reusable fixtures,
architecture and generated-output gates, and executable performance budgets.

WBS-104 and WBS-120 remain active because the lockfile has not been committed
and the accumulated in-scope working tree is intentionally not clean. No
commit, staging, reset, or destructive cleanup was performed without explicit
user authorization.

## Foundation Installed

- The root is a Dart Pub Workspace managed by Melos 7 with a single root
  `pubspec.lock` and locked bootstrap command.
- Root commands cover bootstrap, changed-file format, analysis, all package
  tests, secret scanning, architecture, preservation, reproducibility, Web
  release build, performance budgets, and durable-doc validation.
- `packages/config` owns five environment tiers and 17 typed flags. Local,
  remote, offline, stale, and invalid override behavior is tested; the existing
  Generative ECG capability has a real guarded consumer and remains enabled by
  its compatibility-safe default.
- `packages/foundation` owns pure-Dart clock, ID, randomness, network, key-value
  storage, and bootstrap abstractions. Critical retry, optional degradation,
  and offline continuation are deterministic.
- `packages/observability` separates allowlisted/redacted structured logs,
  consent-gated analytics, and vendor-neutral crash reporting. Analytics
  revocation purges queued events and crash capture never serializes raw
  exception messages.
- Authoritative events now use a versioned envelope and stable enum names while
  preserving legacy decoding. The architecture gate rejects unsafe enum-index
  persistence and platform imports in pure-Dart packages.
- `packages/fixtures` provides synthetic, PHI-free route, model, schema,
  English/Persian catalog, event, and six-platform fixtures without lesson
  bodies.
- Generated preservation and selected-identity artifacts have clean
  regeneration/parity gates.
- Python cache products are ignored without removing any user-owned files.

## Motion Execution Stack

No connector or design plugin is required to implement Synapse motion. The
planned stack is intentionally hybrid:

1. Flutter animation primitives, `CustomPainter`, and fragment shaders own
   navigation continuity, path motion, feedback, particles, and procedural
   celebrations.
2. Rive owns the articulated restored-LUMA companion, facial/hand rig, state machine,
   and data-bound emotional reactions when the MVS-MOTION-01 bake-off proves it
   against the same budgets.
3. A Rive dependency is not installed yet. It will be added only with a real
   rig consumer, state contract, binary-size measurement, interruption tests,
   and deterministic frozen/raster fallback.
4. Lottie is reserved for a bounded linear cinematic only when a Flutter or
   Rive implementation would be less maintainable.

The Rive editor can be used in its browser surface; a Windows desktop install is
optional. The shipped app needs only the verified runtime dependency. Full,
Reduced, and Off modes must converge on the same semantic reward/domain state.

Primary implementation references:

- [Flutter animation overview](https://docs.flutter.dev/ui/animations/overview)
- [Flutter fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)
- [Flutter performance guidance](https://docs.flutter.dev/perf/best-practices)
- [Rive Flutter runtime](https://rive.app/docs/runtimes/flutter/flutter)
- [Rive state machines](https://rive.app/docs/editor/state-machine/state-machine)
- [Rive data binding](https://rive.app/docs/runtimes/flutter/data-binding)

## Performance Contract

`contracts/performance/performance-budgets.v1.json` defines three thresholds—
target, warning, and blocking—for 15 deterministic probes plus provisional
runtime budgets. Static artifact limits are enforced now. Startup, frame,
memory, input latency, and power remain informational until each named physical
device profile has at least ten controlled profile/release runs.

The shipping-asset probe reads the active `flutter/assets` declarations from
`apps/app/pubspec.yaml` rather than treating every archived source asset as
runtime payload. A missing declaration target fails the probe; preserved,
undeclared historical identity evidence remains reproducible without distorting
the release budget.

The fresh Web release baseline is:

| Measurement | Bytes | Tier |
|---|---:|---|
| Complete Web deployment | 47,848,130 | target |
| `main.dart.js` raw | 3,577,749 | target |
| `main.dart.js` deterministic gzip-9 | 1,066,263 | target |
| Largest renderer WASM | 7,229,467 | target |
| Emitted Flutter Web assets | 5,453,180 | target |
| Declared Flutter app assets | 3,970,013 | target |
| Restored LUMA companion/icon assets | 3,879,968 | target |
| Selected wordmark assets | 90,045 | target |
| Largest bundled identity raster | 453,429 | target |

Rive, fragment-shader, and curriculum-pack measurements are currently zero;
their non-zero ceilings are already enforced for future implementation. Eight
named journeys cover launch, navigation, answer feedback, standard/milestone/
showpiece motion, interruption, and Full/Reduced/Off/fallback parity.

## Verification Receipt

`dart run melos run verify` passed from the real repository:

- locked dependency resolution;
- 112 changed Dart files formatted with zero modifications;
- analyzer: zero issues;
- 199 Flutter/Dart tests across ten packages;
- secret scan: 415 files / 4,154,959 bytes, zero findings;
- product language: 238 product files / 32 absorbed capability names, zero
  legacy-brand leaks;
- capability completion: 79 records (76 preserved plus three Academy), zero
  falsely verified;
- architecture: nine packages / 151 Dart files;
- preservation: 31 checks; 141 declarations / 149 concrete routes, 89 route
  helpers, 15 owned persistence entries, 447 deep-link fixtures, and 76
  preserved capabilities plus three registered additive Academy route owners;
- generated identity/contracts: three checks / 11 hashed inputs;
- release Web build, including successful WASM dry run;
- performance: 15 static probes, eight journeys, zero warnings;
- WBS: 440 ordered, unique, dependency-safe steps;
- durable task-doc structure: pass.

The machine-readable performance evidence is
`contracts/performance/performance-verification.v1.json` (SHA-256
`F9F8B8B02BBD2F860D2E679AFD51DD215AC11114BAA77088C35F3F5B10BD46B4`).

## Honest Host Boundaries

- Android SDK 37 is present, but some Android licenses are unaccepted.
- Chrome/Web tooling is available and the release Web artifact is proven.
- Visual Studio with Desktop Development with C++ is absent, so Windows native
  build/runtime proof is not yet available even though Flutter lists Windows as
  a connected target.
- Apple builds require an Apple host; Linux proof requires a Linux host or CI.
- Current plugin resolution and root dependency bootstrap succeed on this
  Windows host. Developer Mode registry flags are not asserted as enabled.
- The dirty worktree contains accumulated approved/in-scope implementation and
  identity work; it has not been staged or committed.
