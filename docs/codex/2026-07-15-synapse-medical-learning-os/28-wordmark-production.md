# WMR2-01 Wordmark Production

Date: 2026-07-17

Status: deterministic source, optical renders, Flutter runtime assets, and local geometry verification complete. Real-host presentation, linguistic, similarity, and trademark gates remain open.

## Binding approval evidence

- Direction: `WMR2-01 Warm Living Fold`.
- User-approved board: `assets/identity/wordmarks-round-2/2026-07-16_wmr2-01_warm-living-fold_user-approved.png`.
- Approval SHA-256: `65F99991C71730FE0C8336A85C7E57D184ECE6344635DFF4B494B72822AFBF71`.
- The generated board remains a visual specification; production text is deterministic vector/raster output, not extracted generated lettering at runtime.

## Deterministic sources

| Source | Role | SHA-256 |
|---|---|---|
| `assets/identity/production/wordmark/source/synapse-wordmark-one-color.svg` | canonical geometry and one-color master | `C26FCA84E412206B90443E0E2CC447E585501A5B1EEDF427C782A32944D52F2E` |
| `assets/identity/production/wordmark/source/synapse-wordmark-frost.svg` | Night Shift frost/cyan material master | `2FB7D68E4C46739582D05EA74FE26F2584615DC79815BD2A72EE8EEAB7771AA9` |
| `tool/identity/trace_wordmark.py` | reproducible approved-board trace and cleanup | `FE0C039CF5A4AE37AE0FF0AA1D8CA2DD19D0F11EC64433F4FECD97AF55306EBE` |
| `tool/identity/render_wordmark_assets.cjs` | optical render and Flutter installer | `B6B957DA7A8A25280813DA7E28B150971E16DC762F2A006DBF330CFAA9E8BAB7` |
| `tool/identity/test_wordmark_assets.py` | geometry/small-size verifier | `A1480170FCF689E0091059976313250CB9BBCCDD0BC2A9A489736FCBFB9FC6F4` |

Trace v2 uses the approved attachment, crop `100,70,1440,310`, threshold `60`, contour epsilon `2.2`, and curve tension `0.06`. Seven independent glyph contours are preserved. The `A` retains its intended counter while the `P` remains an open bowl rather than a hook or question mark.

## Render and verification evidence

- `renders/render-manifest.json`: 21 outputs; SHA-256 `BEBC571AB433A28F9334432C38C5B3A11B760D19D3DED9F0AD4E9556D7F2BD19`.
- `renders/verification.json`: status `pass`; SHA-256 `704FB2738D2E6E2C651617BC3E6BB0A0977044B6753DA89037A40307D53A4E9B`.
- `renders/synapse-wordmark-proof-board.png`: SHA-256 `DB599C38815EAF269C7347CCBB83C060A9EBCC7A6B9A9CE775C7A19DFEC407D7`.
- Every verified 240/96/48/24 px render has seven separate connected glyphs and zero border clipping.
- The `A` counter survives at 24 px; the `P` remains open at every tested size.
- Measured visible ratio remains approximately `6.89–7.03`, with optical padding rather than arbitrary stretching.

## Flutter integration

- Runtime assets are installed under `apps/app/assets/identity/wordmark/`.
- `apps/app/pubspec.yaml` declares the wordmark asset folder.
- `apps/app/lib/brand/synapse_identity.dart` exposes `SynapseWordmark`, selects optical assets by rendered height, and supplies the semantic label `Synapse` for non-decorative use.
- Figtree remains the live interface typeface. The custom wordmark is used only for identity surfaces and is never substituted for live UI text.

## Reproduction

```powershell
$env:NODE_PATH='C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules;C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules\.pnpm\node_modules'
& 'C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' 'tool\identity\render_wordmark_assets.cjs' '--install'
& 'C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'tool\identity\test_wordmark_assets.py'
```

## Remaining gates

1. Capture real app-header, splash, task-switcher, store, and marketing presentation on supported hosts.
2. Verify light/dark/high-contrast use, 200% text adjacency, English/Persian layouts, and reduced-transparency fallbacks.
3. Complete current visual-similarity, linguistic, domain, app-store, and trademark review before public release.
4. Build the approved restrained wake/follow/settle wordmark motion and static reduced/no-motion equivalent after MVS-MOTION-01 proves the rendering route.

