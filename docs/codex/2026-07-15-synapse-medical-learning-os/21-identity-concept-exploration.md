# Synapse Identity Concept Exploration

## Scope

This gate produces exactly ten custom `SYNAPSE` wordmark concepts and exactly ten app-icon/brand-mark concepts, each as its own image board. They all elaborate the user-approved VIS-09 Night Shift DNA; none creates a rival product theme.

The boards are raster concept evidence. After the user selects one wordmark and one icon—or an explicit blend—the chosen geometry must be redrawn deterministically as vector masters, character-by-character checked, optically corrected, exported for every platform, and verified at production sizes. ImageGen lettering is never shipped directly.

## English UI typeface decision

### Selected: Figtree

Figtree is the canonical live English UI typeface. The custom Synapse wordmark remains independent bespoke lettering and must be used as a vector/raster brand asset rather than a typed string where the identity treatment is required.

| Evidence | Figtree | Manrope | Plus Jakarta Sans |
|---|---:|---:|---:|
| Variable regular file | 62,712 B | 165,420 B | 176,288 B |
| Weight axis | 300–900 | 200–800 | 200–800 |
| Native variable italic in Google Fonts | yes | no | yes |
| Glyphs / Unicode code points | 459 / 391 | 742 / 678 | 1,188 / 721 |
| 14 px test-string aggregate width | 1,571 px | 1,617 px | 1,589 px |
| Useful OpenType features observed | case, frac, pnum, tnum, ss01, ss02 | calt, case, frac, liga, pnum, tnum | calt, case, frac, liga, pnum, tnum, ss01–03 |
| Medical-corpus gaps observed | `β`, `⁺`, `⁻` | `⁺`, `⁻` | `β` |
| Night Shift judgment | selected | precise but more technical/narrow | friendly but slightly more ornamental/wide |

Why Figtree wins:

- Its original design intent is a simple, friendly geometric sans, matching Synapse’s professional-but-humane learning personality.
- The actual Night Shift specimen is open, calm, highly legible at 12–32 px, and does not turn the interface into a clinical dashboard or a childish toy.
- It fit the tested long medical strings most compactly without looking condensed.
- Real regular and italic variable files cover the required weight range with about 125 KB combined before build compression/subsetting.
- It includes tabular/proportional numeral, fraction, case-sensitive, superscript/subscript, and stylistic-set features useful for UI/data roles.
- It is OFL-1.1 licensed and can be bundled offline, preserving the existing no-runtime-font-fetch contract.

Binding caveats:

- Figtree is not the scientific-symbol fallback. The measured missing `β`, `⁺`, and `⁻` glyphs must route to a separately licensed and corpus-tested bundled data fallback; no platform-dependent tofu is acceptable.
- Persian uses its own reviewed first-class RTL face and metrics; Figtree must not be forced onto Persian.
- Use live text and semantic font fallback for medical data, citations, warnings, controls, and localization. Do not flatten those strings into brand images.
- Production integration uses the official upstream files and license under `assets/font-evaluation/figtree-source/`, then copies approved production assets into the shared UI package only after the brand gate.
- Current Flutter 3.44 maps `FontWeight` to the `wght` axis of variable fonts. The actual project SDK contract, regular/italic selection, fallback order, web renderer, and all six OS targets still require runtime proof.

Evidence:

- Specimen: `assets/font-evaluation/2026-07-15_english-ui-font-candidates.png`
- Regular SHA-256: `26AD3DB9B31FF7DDE67A91FF515D022D2F495CD506590699CF264F0BFE6FB714`
- Italic SHA-256: `94DEC1F18B9275D69E8B4A91B6514BDC18199048347E1C36E1285B11B0B87653`
- OFL SHA-256: `140D37233E7F3CE7313798BEFA9600893BCCEAF41A55FA0FA5AD52F7F657A268`

## Shared concept-board rules

Every board must:

- use the exact product name `SYNAPSE`, never `NIGHT SHIFT` as a public sublabel;
- preserve the approved midnight navy, cyan/cobalt, coral repair, warm-gold mastery, frost, and warm-paper Evidence relationship;
- feel friendly, memorable, and gameful while retaining medical-professional trust;
- avoid brains, red/green medical crosses, pills, stethoscopes, literal hearts, ECG clichés, shields, infinity loops, atoms, generic network globes, generic AI sparkles, and copied Duolingo trade dress;
- remain original relative to LUMA’s approved folded-bridge construction and not turn LUMA into a tooth, ghost, pillow, moon, organ, or app-store cartoon clone;
- show one dominant idea, not a collage of unrelated marks;
- include practical small-size and dark/light-context tests, while keeping production-critical text live in the final app;
- treat ImageGen spelling, kerning, Bézier geometry, and safe-area output as concept-only.

## Ten wordmark concepts

Each output is one 1536×1024 concept board with one large exact `SYNAPSE` wordmark, a compact header version, a splash lockup, a warm-paper/light proof, a one-color proof, and small 24/48/96 px optical tests. No icon is selected on these boards; any small sign is only a construction cue.

| ID | Name | Generative recipe | Signature | Risk to correct in vector redraw | Output |
|---|---|---|---|---|---|
| WM-01 | Synaptic Bridge | geometric capitals + continuous learning path + folded inner bridge | `Y–N–A` share one controlled bridge stroke; the word reads instantly | connected lettering must not become circuit/tech cliché | `assets/identity/wordmarks/2026-07-15_wm-01_synaptic-bridge_concept.png` |
| WM-02 | Living Fold | soft clinical geometry + LUMA high-fold/inner-bridge anatomy + membrane terminals | selected terminals fold inward like calm responsive material | must not read as tissue, tooth, ghost, or rounded toy font | `assets/identity/wordmarks/2026-07-15_wm-02_living-fold_concept.png` |
| WM-03 | Signal Spine | wide-tracked precision caps + one horizontal knowledge signal + bounded peaks | a single cyan spine crosses counters and resolves at the final `E` | avoid ECG/pulse-line cliché and preserve every letter | `assets/identity/wordmarks/2026-07-15_wm-03_signal-spine_concept.png` |
| WM-04 | Course Thread | Course→Chapter→Lesson topology + three node scales + bespoke ligatures | three subtle node weights progress through the word without dots everywhere | must remain a wordmark, not a map diagram | `assets/identity/wordmarks/2026-07-15_wm-04_course-thread_concept.png` |
| WM-05 | Evidence Cut | dark clinical ink + warm-paper negative-space cuts + cyan edge | evidence-page micro-cuts add trust and tactile originality | paper cuts cannot reduce small-size recognition | `assets/identity/wordmarks/2026-07-15_wm-05_evidence-cut_concept.png` |
| WM-06 | Node Ligature | humanist geometric capitals + two original bridge ligatures + optical spacing | `S–Y` and `P–S` transitions encode connection without a literal brain | ligatures must not resemble existing tech marks or hurt screen-reader naming | `assets/identity/wordmarks/2026-07-15_wm-06_node-ligature_concept.png` |
| WM-07 | Quiet Voltage | calm semi-wide capitals + energy held inside counters + dark clinical restraint | cyan voltage lives only within `A`/`P`, so exterior stays professional | internal glow must survive monochrome and small sizes | `assets/identity/wordmarks/2026-07-15_wm-07_quiet-voltage_concept.png` |
| WM-08 | Dual Lens | Study cyan layer + Clinical frost layer + exact shared skeleton | two materially distinct layers align into one word, expressing one product/two lenses | no chromatic blur, 3D-glasses effect, or duplicate unreadable word | `assets/identity/wordmarks/2026-07-15_wm-08_dual-lens_concept.png` |
| WM-09 | LUMA Imprint | disciplined custom capitals + one folded-bridge negative-space notch | the approved LUMA construction is implied inside `A` or `P`, never pasted beside the name | preserve LUMA originality and avoid mascot-as-letter gimmick | `assets/identity/wordmarks/2026-07-15_wm-09_luma-imprint_concept.png` |
| WM-10 | Mastery Horizon | premium wide caps + horizontal horizon + earned-gold terminal | the knowledge horizon grows from midnight cyan to one bounded gold completion | gold must not imply every state is mastered; no sci-fi title treatment | `assets/identity/wordmarks/2026-07-15_wm-10_mastery-horizon_concept.png` |

### Wordmark generation controls

Positive anchor:

`Exact custom lettering S-Y-N-A-P-S-E, readable on first glance, original geometric-humanist construction, friendly clinical precision, Night Shift navy/cyan/frost with bounded coral and mastery gold, mature gamified medical education, vector-logo concept board, optical small-size proofs.`

Negative anchor:

`No misspelling, no extra word, no NIGHT SHIFT subtitle, no generic font typed unchanged, no brain, neuron network ball, ECG line, medical cross, pill, stethoscope, shield, infinity, atom, DNA helix, AI sparkle, Duolingo green, owl, childish bubble lettering, ghost, tooth, pillow, excessive glow, cyberpunk, illegible ligature, fake app UI text, stock logo grid.`

## Ten icon / brand-mark concepts

Each output is one 1536×1024 concept board with a large mark, black/white/one-color versions, 16/24/48/96/256 px optical simplification, iOS light/dark/tinted context, Android foreground/background/monochrome layer concept, circle/squircle/web-favicon masks, and a no-text mark proof. Final icon production will follow official platform masks and safe zones rather than exporting the generated board.

| ID | Name | Generative recipe | Signature | Risk to correct in vector redraw | Output |
|---|---|---|---|---|---|
| IC-01 | Bridge Knot | two folded route ribbons + one synaptic meeting point + strong negative space | unmistakable bridge/junction silhouette in only three shapes | must not become infinity, chain link, butterfly, or generic network | `assets/identity/icons/2026-07-15_ic-01_bridge-knot_concept.png` |
| IC-02 | Learning Portal | open mastery loop + ascending three-node path + welcoming gap | the learner enters through a route rather than being trapped in a ring | avoid location pin, power button, or generic progress icon | `assets/identity/icons/2026-07-15_ic-02_learning-portal_concept.png` |
| IC-03 | LUMA Fold Mark | canonical high-fold/inner-bridge/low-wave abstraction without face | LUMA’s construction becomes a serious standalone silhouette | must not read as tooth, ghost, pillow, moon, tissue, or animal | `assets/identity/icons/2026-07-15_ic-03_luma-fold-mark_concept.png` |
| IC-04 | Evidence Spark | midnight bridge + warm-paper wedge + cyan signal handoff | one mark expresses Study energy becoming governed Evidence | avoid document icon, page-corner cliché, or AI sparkle | `assets/identity/icons/2026-07-15_ic-04_evidence-spark_concept.png` |
| IC-05 | Mastery Orbit | incomplete orbit + one route node + earned closing segment | progress remains open until evidence closes the final segment | avoid generic loading/progress ring or planet icon | `assets/identity/icons/2026-07-15_ic-05_mastery-orbit_concept.png` |
| IC-06 | Neuro Route | abstract `S` path + three semantic nodes + bridge crossing | reads first as an original route, second as a hidden Synapse initial | avoid crypto/fintech S mark and literal neural network | `assets/identity/icons/2026-07-15_ic-06_neuro-route_concept.png` |
| IC-07 | Learning Triad | nested Course/Chapter/Lesson gates + one continuous direction | three hierarchy levels resolve into one compact crestless mark | avoid chevrons, play button, corporate stack, or medical badge | `assets/identity/icons/2026-07-15_ic-07_learning-triad_concept.png` |
| IC-08 | Signal Seed | central knowledge seed + recall/reasoning/evidence branches | a compact source produces three distinct learning outputs | avoid flower, atom, spark, fan, or biology-organelle cliché | `assets/identity/icons/2026-07-15_ic-08_signal-seed_concept.png` |
| IC-09 | Quiet Pulse Bridge | one low waveform transforms into a structural bridge | “pulse” is architectural and calm, never a literal ECG | avoid heart monitor, cardiology-only identity, and waveform app cliché | `assets/identity/icons/2026-07-15_ic-09_quiet-pulse-bridge_concept.png` |
| IC-10 | Prism Fold | three folded layers for learn/reason/evidence + one cyan core | premium dimensional mark with a decisive flat monochrome silhouette | avoid generic prism, gem, cube, origami bird, or metaverse logo | `assets/identity/icons/2026-07-15_ic-10_prism-fold_concept.png` |

### Icon generation controls

Positive anchor:

`Original Synapse app icon and brand mark, simple strong silhouette, two to four deliberate shapes, Night Shift midnight/cyan/frost with bounded mastery gold and optional warm-paper cue, mature friendly medical-learning game, flat vector master with restrained dimensional variant, survives 16 px and monochrome, adaptive-icon layer logic, generous safe area.`

Negative anchor:

`No text, letter soup, brain, neuron web, medical cross, heart, ECG, pill, stethoscope, shield, infinity, atom, DNA, generic S tech logo, location pin, power button, flower, butterfly, gem, cube, owl, Duolingo green, copied mascot, clip-art, many tiny nodes, thin strokes, excessive glow, photorealism, pre-masked rounded square, embedded drop shadow, unsafe edge contact.`

## Platform gates after selection

- Apple master: 1024×1024 source, no baked mask, deliberate light/dark/tinted variants, centered memorable silhouette, small-size and notification/settings proofs.
- Android adaptive: separate foreground/background and optional monochrome layers on the 108 dp canvas; core logo stays inside the 66 dp safe zone and survives circle/squircle/squircle variants.
- Web/PWA: 512/192 plus maskable and monochrome/favicon proofs.
- Windows/macOS/Linux: required installer/store/taskbar/dock/file metadata sizes and transparent/opaque behavior.
- Wordmark: full, compact, one-color, reversed, warm-paper, horizontal, splash, and minimum-size variants; exact `SYNAPSE` spelling and accessible text equivalent.
- Trademark, domain, app-store, linguistic, visual-similarity, and no-copy checks remain required before public release.

## Queue and selection gate

Generation order is WM-01→WM-10, then IC-01→IC-10. Every finished board receives an ImageGen provenance log, dimensions, SHA-256, critique, and queue status. No user choice is requested until all twenty are visible. After selection, rejected concepts remain evidence but cannot dilute the chosen master.

## 2026-07-16 user feedback and Round-2 gate

- `WM-02 Living Fold` is the strongest Round-1 typography direction, but **is not approved** and none of the ten wordmarks fully satisfies the user.
- The useful DNA is fold geometry living inside the letters. Round 2 must correct cold metallic/fashion-tech tone, inconsistent letter grammar, weak whole-word rhythm, insufficient medical-learning personality, and loss of distinctiveness in flat/24 px states.
- None of the icon concepts shown so far is accepted. Do not continue the same abstract-tech family merely to complete the old table.
- Round-1 icon generation stops after IC-05. IC-06→IC-10 remain documented sparks only and are superseded before generation.
- Icon Round 2 must deliberately compare actual mascot-led icons, optically symmetric icons, and intentionally asymmetric icons.
- The binding Round-2 brief, quotas, filenames, and gates live in `23-identity-round-2.md`.
