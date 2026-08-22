# Restored Identity Production — LUMA Facefront

Date completed locally: 2026-07-17

Status: the latest direct user decision restores the original LUMA pairing as the active Synapse mascot and launcher identity. This document is the active runtime authority for the mascot/icon; it supersedes `29-selected-mcr4-01-character.md`, `30-selected-app-icon-evidence-guide.md`, and `31-selected-identity-production.md` without erasing their historical evidence.

## Binding evidence

- **Mascot source:** LUMA Character System reference board, `assets/previews/2026-07-15_refine-01_luma-character-system.png`; 1536×1024; SHA-256 `939F98A302D269A03CBFC08995D7A62A5E4939896FDE212D8D56AA63CA99CD94`.
- **App-icon source:** `ICR2-01 LUMA Facefront`, `assets/identity/icons-round-2/2026-07-16_icr2-01_luma-facefront_concept.png`; 1536×1024; SHA-256 `352FC04100F77A4203115BAE9DD090D8D0116AEDC541466DFB3656D33727FD19`.
- **Wordmark:** WMR2-01 Warm Living Fold remains unchanged.
- **Decision trail:** the 2026-07-16 tooth/dental association concern is retained as a blind-association and real-host launch-review gate. It is not a reason to retain MCR4-01/ICR4-04 after the user explicitly restored LUMA.

## Deterministic package

`tool/identity/build_luma_facefront.py` locks both source hashes and dimensions, uses only text-free crop rectangles recorded in the manifest, removes board-only labels/frames without repainting the selected art, and builds the following outputs:

- opaque universal 1024 launcher master, transparent foreground, Android adaptive and one-component monochrome layers, frost-tinted proof, 16–512 px optical masters, and circle/squircle/rounded mask proofs;
- six transparent mascot fallbacks: hero pointing, encouraging, thinking, evidence guide, quest host, and recovery;
- complete Android, iOS, macOS, Web/PWA, Windows ICO, Linux hicolor, and Flutter runtime exports;
- `apps/app/assets/identity/luma_facefront/` with 27 runtime assets and an unchanged generic `SynapseCompanion` / `SynapseAppIcon` API surface.

| Artifact | Result |
|---|---|
| Builder | `tool/identity/build_luma_facefront.py`; SHA-256 `1F26052C5CE0CD35686A2C1A34601CF6CDEC239CD897CD2197B0215D1CC439A1` |
| Verifier | `tool/identity/test_luma_facefront.py`; SHA-256 `FE2D8F4917619AD89F54050C240B1B2FB2B108FD9CCE940B16ED7D550EFB80DA` |
| Source manifest | 37 outputs; SHA-256 `91A6D89A5B7348DD13A90900F58D15EFF83244B9BD7010B108D22A649A48EF5D` |
| Source verification receipt | pass, zero failures; SHA-256 `7B4DA20F1474CE41E5AF9FCE06A56C759998236D9995FA87E48FE47F86F4702F` |
| Platform manifest | 188 package/install records; SHA-256 `C9702E874C290AA3A395D89DAD666D4A3575A44AE2D75ACD3DF3F8A439B1A661` |
| Platform verification receipt | pass, zero failures; SHA-256 `D35A365653A731A709F32BD72C70157C12AFBDFEFCF3B8BB706A2EF25DC6C88F` |
| Production proof board | `renders/luma-facefront-production-proof-board.png`; SHA-256 `431A2F359240007220EF07BF123A04528EB5758F718449A75CD48F1A498987DC` |

## Local gates that passed

- source input hashes and dimensions are locked before extraction;
- every generated output has byte/hash manifest parity;
- app master is opaque, unmasked, and free of board labels/frames;
- adaptive and monochrome layers are transparent at every corner and remain within `278.051 / 304` safe-radius pixels;
- monochrome layer is exactly one connected component;
- 48, 24, and 16 px masters retain dark facial detail and a cyan fold cue;
- all six mascot outputs have non-empty transparent bounds without clipped corners;
- Android adaptive/themed layers, Apple ladders, PWA regular/maskable assets, a seven-entry Windows ICO (16–256), Linux hicolor sizes, Flutter runtime copies, and package-to-install byte parity pass.
- the root generated-output gate runs the restored LUMA verifier and rejects any active MCR4 runtime declaration in the Flutter API or `pubspec.yaml`.
- the performance contract derives shipping assets from `pubspec.yaml`: 35 declared files / 3,970,013 B, including 27 LUMA assets / 3,879,968 B; preserved MCR4 files remain undeclared historical evidence rather than a false runtime cost.

## Reproduce

```powershell
$python = 'C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'

& $python tool/identity/build_luma_facefront.py --install
& $python tool/identity/test_luma_facefront.py --require-install
dart format apps/app/lib/brand/synapse_identity.dart
```

The previous MCR4/ICR4 assets and scripts are not deleted. They remain historical, reproducible evidence, while `pubspec.yaml` declares only the restored `luma_facefront` runtime directory.

## Honest remaining gates

Local deterministic production does not prove brand-launch clearance or articulated performance. Before public release, still obtain:

1. launcher, splash, task-switcher, Dock/taskbar, themed-icon, and PWA-install captures on appropriate Android, Apple, Windows, Linux, and Web hosts;
2. blind no-name association testing across 256/96/48/24/16 px, explicitly including the prior dental/tooth reading risk;
3. current visual-similarity/trademark review;
4. layered/Rive mascot motion, Full/Reduced/Off state parity, interruption behavior, and profiler-backed runtime evidence;
5. integrated Flutter screenshots in English/Persian, LTR/RTL, compact/expanded, text-scale, high-contrast, and reduced-motion conditions.
