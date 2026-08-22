# Historical App Icon — ICR4-04 Evidence Guide

Date selected: 2026-07-17

Status: historical direct-selection evidence. It was superseded as the production app icon by the user's later restoration of ICR2-01 LUMA Facefront. Its production package remains preserved as reproducible decision history; it must not be reinstalled as the active runtime identity.

## Binding evidence

- Candidate ID: `ICR4-04`.
- Direction: `Evidence Guide`.
- Generated concept: `assets/identity/app-icon-round-1/2026-07-17_icr4-04_evidence-guide_concept.png`; SHA-256 `1EB72FB41BD37AD27ABEEA28CF5F0646BB164E3959F9939CDFE9C02341E0E473`.
- Exact user-reattached approval: `assets/identity/app-icon-round-1/2026-07-17_icr4-04_evidence-guide_user-approved.png`; SHA-256 `3B032C99C13E21435B7CACA293D12887629992C4AD7201158E17C98FBB6FC4D5`.
- Direct evidence: the user said `این ایکونو انتخاب میکنم` while attaching the Evidence Guide board.
- The four other Round-1 candidates remain unselected mock previews and have no launcher authority.

## Icon thesis

The icon is a close portrait of the selected MCR4-01 character holding one small luminous evidence tile. The mascot supplies relationship and memory; the tile communicates Synapse's defining promise: medical learning connected to evidence rather than generic gamification.

## Locked composition

- Head and upper torso occupy the dominant left/center mass.
- The same single side crest and cyan living seam from MCR4-01 remain fully visible.
- Direct calm gaze and a small reassuring smile are fixed default expression cues.
- One attached right hand holds one translucent midnight evidence tile at the lower-right; the tile never covers the face.
- The tile contains a simple cyan connected-signal glyph only. No letters, medical cross, caduceus, ECG, brain, heart, or unverified clinical content.
- Deep midnight background, restrained cobalt depth, frost-white character, and cyan evidence reflection follow Night Shift.
- Circle, squircle, rounded-square, maskable, 48 px, 24 px, and 16 px variants are optical exports from one identity—not separate regenerated characters.

## Preview-to-production decomposition

| Layer | Type | Platform rule |
|---|---|---|
| Midnight/cobalt field | opaque raster/vector background | full square for Apple/legacy; separate adaptive background on Android |
| Character portrait | transparent high-resolution raster fallback; future layered rig source | scale inside mask safe zones; never bake a universal rounded mask |
| Evidence tile body | separate translucent/dark asset | simplify opacity and edge at small sizes |
| Connected-signal glyph | deterministic vector/monochrome path | three nodes plus one short signal stroke; remains non-textual |
| Highlights and cyan reflection | decorative raster layers | removable in monochrome/high-contrast modes |
| Themed/monochrome source | simplified one-color character-plus-tile silhouette | no facial detail dependency; host color owns presentation |
| Optical variants | purpose-rendered raster outputs | enlarge/simplify card cue at 48/24/16 px; preserve face and crest first |

## Platform acceptance gates

1. Universal master is an opaque unmasked square with no baked Apple/Android corner shape.
2. Android adaptive foreground remains inside the current safe-zone bound under circle, squircle, rounded-square, and common OEM masks.
3. Android monochrome/themed icon remains recognizable without cyan, gradients, eyes, or background.
4. Apple 1024 source contains no transparency and no baked rounded-square mask; dark/tinted appearance work is verified on an Apple host.
5. PWA regular and maskable sources remain opaque and survive install crops; favicon 16/24/32/48 remains identifiable.
6. Windows ICO contains the complete size ladder; macOS/Linux assets remain coherent in Dock/taskbar/menu contexts.
7. Installed bytes match the platform package manifest; real launcher/task-switcher screenshots remain required.
8. Generated preview labels and fake optical specimens never ship as runtime assets.

All local acceptance gates above pass through the deterministic package documented in `31-selected-identity-production.md`: 37 source outputs, 188 platform/package/install records, a seven-size Windows ICO, 27 Flutter runtime assets, adaptive radius `301.597 ≤ 304`, and exact installed-byte parity.

## Motion boundary

The evidence tile may wake after the character settles during splash or an evidence-related accepted event. Motion must be brief, interruptible, non-looping, and suppressed in Reduced/Off modes. The icon and splash never imply a clinical answer or reward grant.
