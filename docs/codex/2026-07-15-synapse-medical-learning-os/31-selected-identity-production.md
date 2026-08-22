# Historical Identity Production — MCR4-01 + ICR4-04

Date completed locally: 2026-07-17

Status: historical production receipt. The exact user-selected MCR4-01 Sidecrest Companion and ICR4-04 Evidence Guide were reconstructed, installed, and locally verified at this checkpoint. The latest direct user decision supersedes them with restored LUMA Facefront assets; their package is preserved as reproducible history and must not be treated as current runtime authority.

## Binding authority

- Mascot selection contract: `29-selected-mcr4-01-character.md`.
- App-icon selection contract: `30-selected-app-icon-evidence-guide.md`.
- Exact mascot approval SHA-256: `4370396EE1193B8CE04788AF7B25809360F0C8D924EBFD6302C604F4BB748F75`.
- Exact icon approval SHA-256: `3B032C99C13E21435B7CACA293D12887629992C4AD7201158E17C98FBB6FC4D5`.
- Production root: `assets/identity/production/mcr4-01-evidence-guide/`.
- Production proof board: `renders/mcr4-01-icr4-04-production-proof-board.png`; SHA-256 `DC7066BB8B5F48EFF33E37689CABA257EAFE484DC5008E3A0B4370E2CC778C67`.

The approval boards remain selection evidence. Shipping assets are extracted production outputs: they do not include preview labels, specimen rows, guides, or a baked universal corner mask.

## Deterministic source package

`tool/identity/extract_mcr4_evidence_guide.py` locks both approval-file hashes and dimensions before extraction. It creates an opaque unmasked launcher master, transparent portrait and adaptive layers, a one-component monochrome layer, optical-size proofs, six role poses, mask proofs, and a production board.

| Artifact | Result |
|---|---|
| Extractor | SHA-256 `EFEFCA6555871AD632E8FCAD47472B18712C78B3B7CA3382EAD04DD5819511D5` |
| Source manifest | 37 outputs; SHA-256 `D5DAF42C6388BEE7C715FEFCB8B22DDA939C6858EEE829727F1EB65A9888C761` |
| Source verifier | SHA-256 `AB71770F0DC529E7A34D82C8EE722F6995F88ECB9A975A33B8E5EDAB1D95EC68` |
| Verification receipt | status `pass`; SHA-256 `121ADA3EC7ABF78A758A8559CA81E0347B9C3FF79FFFD740590EC544CFE31481` |
| App-icon master | `source/icr4-04-app-icon-master-1024.png`; SHA-256 `1E64306287558345921D77F56F93447BE30583C7DE184B18DA487B476F51898F` |
| Adaptive foreground | maximum radius `301.597/1024`, below the locked safe radius `304` |
| Monochrome foreground | same safe radius; one connected component |
| Optical proof | 48, 24, and 16 px retain both dark facial detail and cyan evidence cues |
| Mascot fallbacks | hero-pointing, encouraging, thinking, evidence-guide, quest-host, and recovery; no clipped corners |

## Cross-platform package and installation

`tool/identity/export_mcr4_evidence_guide.cjs --install` derives all host assets from the selected source package and records source hashes, renderer versions, geometry, destinations, and installed-byte parity.

| Surface | Installed result |
|---|---|
| Android | legacy, round, adaptive foreground/background, and monochrome/themed resources |
| iOS | complete AppIcon slot ladder plus default/dark/tinted source proofs |
| macOS | complete AppIcon slot ladder plus Dock-ready source |
| Web/PWA | regular, maskable, circle/squircle/rounded mask proofs, and favicon ladder |
| Windows | seven-entry ICO: 16, 24, 32, 48, 64, 128, and 256 px |
| Linux | hicolor ladder and 512 px raster source |
| Flutter runtime | app icon, adaptive and monochrome layers, plus six poses at 1x/2x/3x: 27 installed assets |

The platform package contains 188 generated/package/install records. Its manifest SHA-256 is `8C50AE0EF151E58515A8DE0F6922A2C15CE9CB05B66CE2F84CF0D5EFB50797C9`; the install-aware verification receipt SHA-256 is `417529C20ABB48083171914FCBB62E981396C129FF9098B1B1543A615DF27F0A`.

## Flutter identity API

- Runtime assets are installed at `apps/app/assets/identity/mcr4_companion/` and declared in `apps/app/pubspec.yaml`.
- `apps/app/lib/brand/synapse_identity.dart` exposes `SynapseCompanionPose`, `SynapseCompanion`, and `SynapseAppIcon` alongside `SynapseWordmark`; SHA-256 `874DAFAA0D1CE1CFE3D5BC13BF39D26086692DB1FB4201D3FBA9AEBF9F395C94`.
- The deprecated `LumaFoldkin` wrapper is retained only as a source-compatibility bridge and now resolves to selected MCR4 assets. It is not a visual or naming authority.
- The old `luma_foldkin/` folder is no longer declared or loaded. It remains historical workspace evidence unless a later cleanup proves deletion safe.

## Reproduction and verification

The image tests require Pillow and NumPy. In the Codex desktop workspace, use the bundled Python runtime and expose the bundled Node modules for Sharp:

```powershell
$python = 'C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$node = 'C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'
$env:NODE_PATH = 'C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules'

& $python tool/identity/extract_mcr4_evidence_guide.py
& $python tool/identity/test_mcr4_evidence_guide.py
& $node tool/identity/export_mcr4_evidence_guide.cjs --install
& $python tool/identity/test_mcr4_platform_identity.py --require-install
dart format apps/app/lib/brand/synapse_identity.dart
```

Latest local results:

- source verifier: `pass`, zero failures;
- platform verifier with `--require-install`: `pass`, 188 outputs, zero failures;
- installed-byte parity: `pass`;
- Android adaptive and monochrome safe-zone checks: `pass`;
- Apple master opacity/no baked mask, PWA mask proofs, Windows ICO ladder, Linux master, and Flutter runtime assets: `pass`;
- Dart formatting: `pass`; dependency-resolution warning remains because the current app package configuration is not resolved under the installed Dart baseline.

## Honest remaining gates

Local deterministic production does not prove public-launch clearance or animated character performance. Still required:

1. real launcher, splash, task switcher, Dock, taskbar, PWA-install, and themed-icon screenshots on suitable Android, Apple, Windows, Linux, and Web hosts;
2. blind no-name silhouette/association testing and current visual-similarity/trademark review;
3. the layered facial/limb rig, event state machine, interruption rules, Full/Reduced/Off outputs, and profiler-backed MVS-MOTION-01 spike;
4. Flutter composition screenshots in English/Persian, LTR/RTL, compact/expanded, text-scale, high-contrast, and reduced-motion modes.

Until those gates pass, the correct claim is **selected identity locally produced and installed**, not **brand launch complete**.
