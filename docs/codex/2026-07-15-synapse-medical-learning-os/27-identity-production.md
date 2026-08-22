# Superseded Identity Production Pass — LUMA Foldkin

Date: 2026-07-17

Status: deterministic Foldkin production pass is technically implemented and locally verified but **superseded as identity authority**. Its launcher/runtime bytes were subsequently replaced by MCR4/ICR4 and then by the restored LUMA Facefront package. It remains historical evidence only; current authority is `32-restored-luma-facefront-production.md`. The deterministic WMR2-01 wordmark remains active; see `28-wordmark-production.md`.

> Historical evidence boundary: passing these geometry/platform checks proves the old exporter pipeline, not the selected identity. Foldkin must not be presented as the final mascot or app icon.

## Outcome

At this historical checkpoint ICR2-01 had been withdrawn and MCR3-04 Foldkin owned the working mascot/launcher identity. Neither statement is current: the latest direct user decision restores ICR2-01 LUMA Facefront and the original LUMA Character System.

This pass deliberately changes the silhouette rather than recoloring the rejected mark:

- no central crown valley, paired peaks, crossing roots, or enamel proportion;
- one softly asymmetric outer body with a broad grounded base;
- one short, blunt, open support pocket that remains visible in one color and at 16 px;
- face and cyan are removable; the silhouette remains the identity source;
- launcher masks are platform-owned and are never baked into the universal master.

Residual ghost, hood, page, ear, speech-bubble, and generic-assistant associations remain explicit blind-test risks. Passing the anti-tooth construction gate is not represented as passing public association or trademark review.

## Canonical sources

| Source | Role | SHA-256 |
|---|---|---|
| `assets/identity/production/mascot-icon/source/luma-foldkin-master.svg` | material character master | `51C1BF0316FEA090A72ADD3ED14AE89D5D7136E7489FAFC0B835A87873280668` |
| `assets/identity/production/mascot-icon/source/luma-foldkin-flat.svg` | flat character and adaptive foreground source | `F29DC6DA919A22A11B19005DF1DFA9F4EFAB02B5AC9B7E34DE75789570D687B9` |
| `assets/identity/production/mascot-icon/source/luma-foldkin-mark-monochrome.svg` | face-free one-color mark | `2DBD7C4FCD96C3693D8ADEBCC2A6759D6FEF7B92B16D9E51D5535EBBC0A0401D` |
| `assets/identity/production/mascot-icon/source/luma-foldkin-app-icon.svg` | unmasked opaque launcher master | `B4A9D29A1FE8F2D82B65F0D99DC99F07B4828E0E85F7E710D0C86DD717BBB3D6` |

Dedicated optical SVGs exist for 24 px and 16 px character and app-icon use. `geometry.md` records the canonical contour, landmarks, contour-trace method, face-hole mapping, and non-negotiable ambiguity controls.

## Render and small-size proof

`tool/identity/render_identity_assets.cjs` renders 34 canonical PNGs. `tool/identity/test_identity_assets.py` validates connected silhouette, open-pocket split rows, alpha clipping, face survival, and opaque launcher fields.

Measured proof:

| Asset | Bound or signal | Result |
|---|---:|---|
| transparent material 1024 | alpha bounds `118,155–905,867`; ratio `1.1052`; border `0` | pass |
| monochrome 16 | bounds `2,2–13,13`; one component; 3 split rows; border `0` | pass |
| monochrome 24 | one component; 6 split rows | pass |
| optical character 16 | 3 meaningful dark-detail pixels | pass |
| optical character 24 | 4 meaningful dark-detail pixels | pass |
| app-icon 1024 | opaque field covers all canvas edges | pass |

Canonical render evidence:

- `renders/render-manifest.json` — SHA-256 `6D05615DDDF4E408486D8D256136CD471DFCF20A53CE12F24BF4EE0A9F82C104`.
- `renders/verification.json` — SHA-256 `CF4F9D85B210559185EDAB0DEF197904474D2B96F6AE9486CAE4329D48AE42D1`.

## Platform package

`tool/identity/export_platform_identity.cjs --install` generates the independent package first and then installs the same bytes in `apps/app`. The final run records 152 package/install outputs.

| Surface | Produced and installed | Boundary |
|---|---|---|
| Android | legacy density icons, round icons, adaptive foreground, opaque midnight background color, v26 adaptive XML, v33 monochrome/themed XML | foreground max radius `298.33/1024`, below the enforced `304/1024` safe radius |
| iOS/iPadOS | every existing asset-catalog slot from 20 px through 1024 px | default source installed; no rounded mask baked in |
| macOS | 16, 32, 64, 128, 256, 512, and 1024 catalog outputs | catalog installed; macOS host capture pending |
| Web/PWA | 192/512 regular, 192/512 maskable, 16/32/48 favicon, circle/squircle/rounded proofs | maskable field is fully opaque; foreground uses the bounded safe source |
| Windows | PNG proof ladder and PNG-compressed multi-entry ICO at 16/24/32/48/64/128/256 | ICO header and all seven entries parsed |
| Linux | hicolor 16–512 ladder plus scalable SVG | package prepared; desktop packaging/install mapping waits for the chosen Linux package formats |
| Flutter UI | material, flat, monochrome, 16/24 optical, 48/96/256/1024 fallbacks | installed under `apps/app/assets/identity/luma_foldkin/` |

Apple default/dark/tinted 1024 sources are prepared under `platforms/apple/sources/`. Only the default legacy catalog is wired on this Windows host. Dark/tinted appearance authoring through current Xcode/Icon Composer remains an Apple-host gate and is not claimed complete.

Platform implementation follows current primary guidance:

- Apple app-icon guidance: <https://developer.apple.com/design/human-interface-guidelines/app-icons/>
- Apple asset-catalog configuration: <https://developer.apple.com/documentation/xcode/configuring-your-app-icon>
- Apple Icon Composer: <https://developer.apple.com/documentation/Xcode/creating-your-app-icon-using-icon-composer>
- Android adaptive icons: <https://developer.android.com/develop/ui/compose/system/icon_design_adaptive>
- Android splash system: <https://developer.android.com/develop/ui/views/launch/splash-screen>
- PWA manifest and maskable behavior: <https://web.dev/learn/pwa/web-app-manifest>

## Flutter integration

- `apps/app/pubspec.yaml` declares `assets/identity/luma_foldkin/`.
- `apps/app/lib/brand/synapse_identity.dart` exposes canonical paths and the reusable `LumaFoldkin` widget.
- The widget selects material, flat, monochrome, and optical fallbacks by requested size.
- Decorative uses are excluded from semantics by default. A semantic image label is emitted only when the caller provides state-bearing copy.
- Static assets are the reduced-motion and failure-safe fallback for the future Rive/native state machine; they do not award rewards or invent state.

## Installed presentation metadata

The user-facing product name is now `Synapse` in Android, iOS, macOS display metadata, Windows title/product metadata, Linux window chrome, and Web/PWA metadata. Package IDs, namespaces, executable names, and bundle identifiers were intentionally preserved.

Night Shift presentation metadata now uses `#07182D` for PWA theme/background color. Android points at both regular and round launcher resources. PWA orientation is `any` so the same install remains usable across phone, tablet, foldable, and desktop windows.

## Reproduction

```powershell
$env:NODE_PATH='C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules;C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules\.pnpm\node_modules'
& 'C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' 'tool\identity\render_identity_assets.cjs'
& 'C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'tool\identity\test_identity_assets.py'
& 'C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' 'tool\identity\export_platform_identity.cjs' '--install'
& 'C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'tool\identity\test_platform_identity.py' '--require-install'
```

Final package evidence after the install run:

- `platforms/platform-manifest.json` — 152 outputs; SHA-256 `773EAE7BFEFC8FB011C868D42284D6FF83D495E235B8CF096F81C2299DF2BD18`.
- `platforms/platform-verification.json` — status `pass`; SHA-256 `BDBFE864A2CF3EEAC85699CB6FE113D6C5385E78B8BBF76FD54AE9C80A95DDE5`.
- exporter SHA-256 `C075610A0FD11667C556CD7E1F07C1A2A93D5B671BD9114348FC9DE8AEBA807D`.
- platform verifier SHA-256 `90595A0129B8BC8937C20F41C3A9ABB7BC86109071799EC2DB69AC970429B620`.

## Remaining gates

1. Blind no-name association testing on silhouette, 16/24/48 px launcher, and character renders.
2. Current visual-similarity, name, and trademark review before public release.
3. Android emulator/device launcher, themed-icon, splash, task-switcher, and notification captures.
4. Apple-host Xcode catalog/Icon Composer, Dock, task switcher, signing, and store-source proof.
5. Windows build/taskbar/installer and Linux package/menu capture on configured hosts.
6. Deterministic production SVG for the selected WMR2-01 wordmark.
7. Rive/native Foldkin state rig, Full/Reduced/Off behavior, interruption semantics, and profiler proof per `22-motion-bible.md`.
