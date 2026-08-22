# LUMA Foldkin Deterministic Geometry

Status: first production geometry pass; raster and association verification pending.

## Coordinate system

- Canonical viewBox: `0 0 1024 1024`.
- Geometric center: `(512, 512)`.
- Nominal traced body bounds: approximately `x=117..906`, `y=155..869`.
- The canonical path is a 49-point Catmull–Rom-to-cubic trace of the MCR3-04 flat master (`epsilon=1.6`, `tension=0.075`) rather than the rejected hand-inferred path.
- Source crop component: 39,139 foreground pixels, 1,264 raw boundary points, uniform mapping scale `3.164444…` into the canonical viewBox.
- App-icon composition transform: `translate(82 82) scale(.84)`; the universal master remains unmasked and transparent.
- Base curve grid: 8-unit planning grid with deliberate optical coordinates where curvature required it.

## Named contour landmarks

| Landmark | Approximate anchor | Function | Guardrail |
|---|---:|---|---|
| living dome | `(357, 156)` | primary visual mass and calm head/torso | never split into paired peaks |
| top descent | `(686, 321)` | directs mass toward shoulder | shallow; no leaf/page apex |
| rounded shoulder | `(841, 400)` | counterweight and posture | never sharpen into corner |
| outer waist | `(904, 643)` | rolls toward the support heel | no straight page edge |
| lower-right heel | `(775, 843)` | stable support and pocket opening boundary | blunt after optical cleanup; no tail |
| pocket terminal | `(582, 571)` | proprietary open support pocket | broad semicircle below/right of face |
| lower-left base | `(211, 836)` | grounding mass and optical counterweight | full, non-pointed, non-root-like |

## Face geometry

- Eye centers measured from enclosed flat-master holes: approximately `(339, 393)` and `(447, 393)`.
- Eye radii: `19×27` canonical units.
- Smile: starts `(356, 443)`, optical low point near `(393, 466)`, ends `(430, 443)`; `13`-unit round stroke.
- Face is intentionally high-left. It must never align with the support pocket as a second mouth.

## Support pocket and lamina

- The support pocket is exterior negative space created by the body contour; it is not a closed punched hole.
- The cyan lamina follows the pocket ceiling from lower-right toward the blunt terminal:
  `M758 808 C782 775 794 738 793 706 C792 661 774 626 746 606 C710 580 665 568 614 571 C578 573 550 586 531 606`.
- Flat stroke: `16` units. Dimensional visible stroke: `14` units plus a bounded blurred underlay.
- Monochrome identity cannot depend on this cyan path; the outer contour and open pocket must remain sufficient.

## Optical policy

- `>=48 px`: canonical face and lamina are eligible.
- `32 px`: enlarge eyes/smile optically only if real raster comparison shows loss; do not enlarge body or close the pocket.
- `24 px`: use `luma-foldkin-optical-24.svg`; face and lamina are deliberately enlarged and glow is removed.
- `16 px`: use `luma-foldkin-optical-16.svg` only where character expression is required. The face-free mark remains the default favicon/themed-icon fallback.
- App-icon 24/16 compositions use dedicated opaque optical sources; do not downsample the 1024 hero master blindly.
- Optical variants may change local curve/control points but must preserve landmark order, support-pocket topology, visual center, and association guards.

## Palette

| Token | Value | Role |
|---|---|---|
| `midnight` | `#07182D` | icon field and dark facial ink |
| `midnightLift` | `#12345F` | bounded app-icon field center |
| `frost` | `#DCE9FF` | flat body |
| `frostHighlight` | `#F7FAFF` | dimensional highlight only |
| `cobaltDepth` | `#83A8F0` | dimensional lower depth |
| `actionCyan` | `#2CC5FF` | support-pocket Study lamina |
| `repairCoral` | `#FF6B5C` | repair state only |
| `masteryGold` | `#FFC857` | earned mastery only |

## Source-of-truth rule

The SVG paths in `source/` are deterministic production candidates. The ImageGen board is composition evidence only. Any path edit must be recorded here, re-rendered at all optical sizes, visually inspected, and re-run through mask/association checks before runtime integration.
