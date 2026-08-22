# Synapse Motion Bible — Night Shift Medical Learning OS

## Status and authority

- Status: binding production plan; implementation evidence pending.
- Visual parent: VIS-09 Night Shift and the corrected LUMA production system.
- Product rule: medical learning and mastery are primary; motion supports comprehension, continuity, memory, recovery, and earned delight.
- Originality rule: the quality bar may be Duolingo-grade, but no protected motion signature, mascot behavior, sound, copy, trade dress, or celebration sequence may be copied.
- Safety rule: Study may be playful; Clinical and Evidence suppress reward theater and never animate uncertainty into false confidence.
- Truth rule: animation never grants progress or rewards. It presents immutable domain outcomes through an idempotent presentation receipt.

This document instantiates `C:/Users/K1/.codex/skills/_shared/gamified-motion-celebration-protocol.md` for Synapse. Every listed sequence remains `planned` until a storyboard/animatic, implementation, capture, accessibility fallback, and profiler evidence close its row.

## Motion thesis

Synapse should feel like a calm living night shift: knowledge travels through a luminous clinical path, evidence opens as warm paper, and LUMA responds like a humane coach. The motion language is **signal → bridge → settle**:

1. a restrained cyan signal establishes cause;
2. a folded bridge or path carries the state change;
3. the interface settles quickly into a stable, readable clinical-learning surface.

Gold appears only for earned mastery. Coral means repair, caution, or urgency—not failure shame. Celebration expands from the same path-and-fold grammar instead of importing generic confetti.

## Operating modes

| Mode | Character | Ambient motion | Feedback | Celebration | Default context |
|---|---|---|---|---|---|
| Full | expressive LUMA performances | restrained route/surface life | multi-beat | all eligible tiers | Study on capable device |
| Essential | single pose changes; short loops only | no ambient loops | short continuity and state cues | micro/standard summaries | user choice, low power, busy shift |
| Off / Minimal | semantic stills only | none | immediate state replacement | static receipt | explicit user choice or accessibility need |
| Quiet Clinical | LUMA Off or Essential | none | functional continuity only | deferred/suppressed | Clinical, Evidence, reference, patient-sensitive work |

System reduced-motion always overrides Full. A separate in-app control is required because this is an animation-heavy product. Skipping changes presentation state only; it never changes reward, mastery, schedule, or completion.

## Runtime and asset strategy

| Need | Preferred route | Use when | Required fallback |
|---|---|---|---|
| route, sheet, tab, progress, shared element | Flutter native explicit/implicit animation | layout and state remain live | instant or short fade/state swap |
| LUMA interactive performance | Rive state machine, subject to package/license/target spike | gaze, emotion blending, entry/loop/exit, responsive pose | canonical SVG/PNG still per semantic state |
| bounded authored one-shot | Lottie only after renderer-feature parity proof | a fixed vector sequence cannot be expressed economically in Rive/native | still hero frame plus live receipt |
| original route trails and bursts | CustomPainter/Canvas with deterministic seed | path energy, mastery propagation, bounded particles | static path highlight or short opacity pulse |
| rare showpiece material/light | Flutter fragment shader after target spike | chapter/course/specialty milestones only | pre-rendered lightweight layer or native gradient transition |
| sound | licensed original short stems/cues | semantic navigation, feedback, mastery, recovery | silent semantics and caption/announcement |
| haptics | platform adapter | touch-capable supported hardware | visual/audio cue; no error if unavailable |

No renderer is approved globally in advance. The first vertical slice must spike native motion, one LUMA Rive performance, one deterministic path effect, audio, haptic, and all fallbacks on representative targets before asset-scale production.

## Presentation contract

```text
authoritative domain event
  -> immutable reward/mastery/session summary
  -> presentation_receipt_id
  -> priority/coalescing queue
  -> motion state machine
  -> played | interrupted | skipped | reduced | suppressed | expired
  -> acknowledged without changing domain value
```

Minimum fields:

```text
presentationReceiptId
sourceEventIds[]
presentationFamily
motionId
tier
priority
createdAt
expiresAt?
state: pending | ready | playing | interrupted | acknowledged | skipped | suppressed | expired
suppressionReason?
replayPolicy
payloadSnapshot
locale
textDirection
motionPreference
```

Rules:

- One authoritative transaction set produces one receipt by default.
- Duplicate/offline/out-of-order deliveries cannot stack a second grant or second mandatory celebration.
- Low-value increments may coalesce; milestones preserve order.
- navigation, safety, error recovery, call interruption, and user input preempt celebration.
- Quiet Clinical may defer a receipt until Study mode; expired receipts collapse into a static inbox/history summary.
- Replays are cosmetic and read only from the immutable payload snapshot.

## Motion tokens

These are starting envelopes and must be tuned from real captures:

| Token family | Default | Intent |
|---|---:|---|
| `instant` | 0–80 ms | state substitution and no-motion path |
| `press` | 90–140 ms | tactile acknowledgement |
| `micro` | 160–260 ms | selection, toggle, tiny progress |
| `continuity` | 260–420 ms | route/sheet/shared-element change |
| `feedback` | 420–760 ms | correct, repair, explanation reveal |
| `standardCelebration` | 700–1200 ms | node, quest, bounded round result |
| `milestone` | 1200–2500 ms | achievement, lesson/chapter completion |
| `showpiece` | 2500–4000 ms | rare course/specialty mastery; always skippable |
| `ambientPeriod` | 2400–6000 ms | only subtle Full-mode breathing/route life |

Motion curves are semantic: firm deceleration for navigation, soft spring for LUMA/folded material, controlled overshoot for earned mastery, and no bounce for Clinical/Evidence/error states. Count-ups must end at the live value and may be skipped instantly.

## Whole-product sequence inventory

Legend: `μ` micro, `S` standard, `M` milestone, `X` showpiece, `F` functional/no celebration. “Fallback” always retains live text, semantics, and the final state.

### A. Startup, shell, and system state

| ID | Sequence | Trigger and choreography | Tier / route | Fallback and proof |
|---|---|---|---|---|
| MOT-SYS-001 | Cold launch bridge | Brand mark resolves from one cyan node into the Synapse bridge; shell is already loading beneath it; no artificial delay. | S / native + final vector | Static mark; measure launch milestone and time-to-first-action. |
| MOT-SYS-002 | Warm resume | Existing surface de-blurs/fades in place; LUMA does not replay greeting; pending critical state wins. | μ / native | Immediate restore; lifecycle and focus tests. |
| MOT-SYS-003 | Authenticated handoff | Successful auth chip travels into profile identity while intended route resumes. | S / shared element | Instant route plus success announcement. |
| MOT-SYS-004 | First-use role setup | Student/resident/physician choice unfolds the relevant workload examples without moving the primary CTA. | S / native layout | Immediate content swap; 200% text and keyboard proof. |
| MOT-SYS-005 | Theme Day ↔ Night | Surfaces cross through a restrained horizon wash; live content never disappears; warm Evidence stays readable. | S / native; shader spike optional | Token swap with 120 ms fade; all-platform capture. |
| MOT-SYS-006 | Study ↔ Quiet Clinical | Cyan/gold reward layers recede, LUMA exits, paper Evidence stabilizes, mode label remains explicit. | S / native state choreography | Immediate semantic mode swap; no reward leakage test. |
| MOT-SYS-007 | LTR ↔ RTL locale | Shell reflows through anchored regions, not a mirrored screenshot; directional path transitions adapt on next navigation. | F / native layout | Immediate re-layout; bidi and focus preservation. |
| MOT-SYS-008 | Responsive posture change | Active task remains anchored while nav, route, and Evidence regions recompose across phone/tablet/desktop/fold. | F / native layout | Snap to layout breakpoint; resize stress capture. |
| MOT-SYS-009 | Reduced-motion activation | Running spatial/loop motion settles to final state and subsequent receipts use reduced variants. | F / preference state | Immediate final state; no lost data/control. |
| MOT-SYS-010 | Low-power/data-saver adaptation | Ambient loops pause, heavy assets stop preloading, lightweight variants take over without visual penalty language. | F / policy | Static assets; energy/network tests. |
| MOT-SYS-011 | App update migration | Existing shell dims minimally, progress-safe migration status advances, then returns to the exact route. | F / native | Static progress and recovery actions; restart/rollback proof. |
| MOT-SYS-012 | Fatal bootstrap recovery | Calm repair surface replaces splash; retry signal travels only after user action; diagnostic copy stays live. | F / native | Static error; offline/corrupt-state tests. |

### B. Navigation, overlays, and workspace continuity

| ID | Sequence | Trigger and choreography | Tier / route | Fallback and proof |
|---|---|---|---|---|
| MOT-NAV-001 | Primary branch switch | Active branch marker slides along the shortest logical edge; page content crossfades with preserved state. | μ / native | Instant branch swap; tab restoration tests. |
| MOT-NAV-002 | Forward route | Selected object becomes the destination anchor; navigation direction follows logical reading/path direction. | S / shared element | Standard route fade; RTL/back-stack proof. |
| MOT-NAV-003 | Back route | Destination anchor returns to source position when available; otherwise stable reverse transition. | S / shared element | Instant pop; scroll/focus restoration. |
| MOT-NAV-004 | Deep-link arrival | Target surface appears first; breadcrumb/path context resolves afterward without fake traversal. | S / native | Immediate target and context text. |
| MOT-NAV-005 | Bottom sheet | Sheet follows touch/keyboard intent, preserves background context, and settles without elastic excess. | μ / native | Instant accessible dialog; drag/cancel tests. |
| MOT-NAV-006 | Evidence Shelf | Warm paper edge unfolds from the evidence affordance; source metadata leads, not decoration. | S / native | Static side sheet/dialog; focus trap/order tests. |
| MOT-NAV-007 | Margin Workspace | Current annotation/tool anchor stretches into compact sheet or desktop pane; task state never resets. | S / shared element | Immediate pane; resize/route persistence. |
| MOT-NAV-008 | Search/Command | Query field expands from shell command point; result groups stage in only after real data arrives. | μ / native | Immediate overlay; keyboard/screen-reader proof. |
| MOT-NAV-009 | Copilot dock | Dock opens as a bounded workspace tool, never floating over primary controls; response states use quiet progress. | S / native | Static pane; no-obstruction screenshots. |
| MOT-NAV-010 | Inbox/notification | Unread indicator resolves into the selected item; queued reward receipts remain separate from clinical alerts. | μ / native | Immediate list/detail; priority tests. |
| MOT-NAV-011 | Scroll-to-active restoration | Path/list returns to the last meaningful node with a short focus halo, not an automatic long camera flight. | S / native | Instant jump plus focus announcement. |
| MOT-NAV-012 | External-link return | App restores the exact surface and briefly confirms provenance/source context. | μ / native | Immediate restore; lifecycle/deep-link proof. |

### C. Today, Course → Chapter → Unit → Micro-lesson, and path progression

| ID | Sequence | Trigger and choreography | Tier / route | Fallback and proof |
|---|---|---|---|---|
| MOT-PATH-001 | Today/Tonight arrival | Primary prescription and workload promise settle first; LUMA acknowledges quietly after content is usable. | S / native + LUMA | Static prescription and LUMA still. |
| MOT-PATH-002 | Prescription reason reveal | “Why this?” opens from the factor chip into a compact explanation; scores never animate as certainty theater. | μ / native | Static disclosure; semantics proof. |
| MOT-PATH-003 | Browse Path entry | Today CTA transforms into the active route node; visible path centers without disorienting pan. | S / shared element | Immediate Path with active focus. |
| MOT-PATH-004 | Course atlas entrance | Course families reveal by stable topology and progressive detail; no ornamental camera fly-through. | S / native/canvas | Ordered outline fallback; frame test. |
| MOT-PATH-005 | Course focus | Selected Course gains a bounded cyan contour and exposes Chapter count/mastery without resizing neighbors. | μ / native/canvas | Static selected state. |
| MOT-PATH-006 | Course → Chapter Trail | Course contour narrows into the Chapter route; breadcrumb remains visible throughout. | S / shared element | Standard route; deep-link/back proof. |
| MOT-PATH-007 | Chapter focus | Chapter node presents approved Units/Micro-lessons or an honest pending-atomization state; source anchors never impersonate playable lessons. | μ / native | Static focus; integrity fixture. |
| MOT-PATH-008 | Chapter → Lesson Station | Node core becomes the Lesson header marker; instructional focus arrives before contextual evidence and tools. | S / shared element | Standard route; loading/draft/published/reduced-motion state proof. |
| MOT-PATH-009 | Current-node pulse | One low-amplitude cyan breath in Full mode; pauses offscreen, when inactive, and in Clinical. | ambient / native/Rive | Static cyan ring. |
| MOT-PATH-010 | Locked node explanation | Lock does not shake; prerequisite path illuminates toward the missing requirement and offers a clear action. | S / canvas/native | Static prerequisite list. |
| MOT-PATH-011 | Node pressed | Folded node compresses along its material axis with semantic haptic; no uncontrolled bounce. | μ / native | Color/outline press. |
| MOT-PATH-012 | Node completed | Cyan signal closes the node ring, mastery value settles, then eligible downstream link wakes. | S / canvas/native | Static completed state plus announcement. |
| MOT-PATH-013 | Node unlock ripple | One deterministic path pulse travels only to genuinely unlocked nodes; duplicates coalesce. | S / canvas | Static unlocked markers; idempotency test. |
| MOT-PATH-014 | Review due | Completed node gains a calm return orbit, not a punishment red badge. | μ / native | Static due marker. |
| MOT-PATH-015 | Repair branch | Coral bridge grows from misconception to repair activity, then returns to the main route after evidence. | S / canvas/shared element | Static branch/breadcrumb; mastery separation proof. |
| MOT-PATH-016 | Checkpoint entrance | Route narrows into a focused case gate; LUMA shifts from companion to calm coach. | M / native + LUMA | Static checkpoint header. |
| MOT-PATH-017 | Chapter completion | Chapter nodes contribute light to one shared bridge, gold mastery seal appears, next Chapter stays optional. | M / canvas + LUMA | Static chapter receipt; skippable. |
| MOT-PATH-018 | Course completion showpiece | Earned Course signals form an original synaptic bridge around the verified Course title; evidence summary remains live. | X / canvas/shader spike + LUMA | Static mastery poster/receipt; preloaded and skippable. |
| MOT-PATH-019 | Specialty horizon | Multiple completed Courses connect into a restrained constellation/horizon; no fireworks or copied ladder motif. | X / canvas/shader | Static specialty map; rare only. |
| MOT-PATH-020 | Return from debrief | Receipt compresses into the completed node, route advances one step, focus lands on the recommended next action. | S / shared element | Immediate Path with updated state. |

### D. Lesson, activity, question, and feedback loop

| ID | Sequence | Trigger and choreography | Tier / route | Fallback and proof |
|---|---|---|---|---|
| MOT-LES-001 | Lesson intent entrance | Lesson title, time promise, activity count, and stop-without-penalty appear before Start; LUMA points once. | S / native + LUMA | Static intro. |
| MOT-LES-002 | Session start | Start control becomes progress rail while first prompt settles; no blank interstitial. | S / shared element | Immediate first prompt. |
| MOT-LES-003 | Prompt transition | Previous feedback settles before next prompt replaces it; shared evidence/media remains anchored when relevant. | S / native | Immediate content swap. |
| MOT-LES-004 | Text answer selection | Selected option gains depth/outline and a short signal; geometry stays fixed. | μ / native | Static selected state. |
| MOT-LES-005 | Multi-select composition | Each choice joins a visible reasoning set; Submit activates only from valid state. | μ / native | Static set and live count. |
| MOT-LES-006 | Ordering/reorder | Item follows pointer/keyboard with stable placeholder; final order settles once. | μ / native | Accessible move controls and announcements. |
| MOT-LES-007 | Match/connect | User-drawn bridge previews only valid endpoints; accepted pair becomes a calm stable link. | μ / canvas/native | Numbered/select controls. |
| MOT-LES-008 | Image/anatomy hotspot | Focus halo enlarges the target without hiding labels; zoom preserves orientation. | μ / native | Static focus ring and list alternative. |
| MOT-LES-009 | ECG/lab interaction | Cursor/selection moves functionally; the medical trace itself is never decoratively morphed or mirrored. | F / native/canvas | Static trace/table alternative. |
| MOT-LES-010 | Case timeline reveal | User-requested next datum joins the timeline with source/time context; no suspense animation for clinically important data. | S / native | Immediate datum and announcement. |
| MOT-LES-011 | Submit commit | CTA compresses once, locks against duplicate submit, and becomes a quiet evaluation state. | μ / native | Disabled/progress state; double-submit test. |
| MOT-LES-012 | Correct answer | Cyan confirmation traces cause → answer; concise explanation appears; gold is reserved for mastery, not every correct tap. | S / native + optional LUMA | Static correct state and announcement. |
| MOT-LES-013 | Wrong answer repair | Coral identifies the exact misconception region, response gently releases, and a repair action becomes primary; no shake/shame. | S / native + LUMA | Static repair panel and focus. |
| MOT-LES-014 | Partial answer | Accepted and missing reasoning components separate spatially; next step is explicit. | S / native | Static component summary. |
| MOT-LES-015 | Hint request | LUMA/evidence edge directs attention to one clue; the answer is not theatrically revealed. | S / LUMA + native | Static hint callout. |
| MOT-LES-016 | Why-not explanation | Selected distractor remains anchored while comparison panel unfolds beside/below it. | S / shared element | Static accordion/sheet. |
| MOT-LES-017 | Explanation zoom | Evidence, reasoning, and misconception layers expand in order; source metadata never trails behind claim text. | S / native | Immediate structured explanation. |
| MOT-LES-018 | Confidence capture | Confidence control fills calmly; no celebratory response until correctness and calibration are known. | μ / native | Static segmented control. |
| MOT-LES-019 | Calibration feedback | Correctness and confidence converge into a small calibration insight; never presents fake numerical certainty. | S / native | Static band/copy. |
| MOT-LES-020 | Mastery delta | Evidence fragments settle into a bounded mastery ring; `Why +n` remains available and count-up is skippable. | S / canvas/native | Final value plus reason text. |
| MOT-LES-021 | Combo/flow | Small signal chain acknowledges varied high-quality evidence; it breaks quietly without loss theater. | μ / native | Static label or omitted. |
| MOT-LES-022 | Session progress | Rail advances from committed activity completion only; resume restores exact position without replaying all motion. | μ / native | Immediate progress state. |
| MOT-LES-023 | Pause/lighter mode | Activity recedes into a safe resume capsule; LUMA offers lighter review without penalty language. | S / native + LUMA | Static pause sheet. |
| MOT-LES-024 | Resume after interruption | Exact prompt and draft restore; one subtle context cue explains elapsed sync/state if needed. | μ / native | Immediate restore. |
| MOT-LES-025 | Offline answer queued | Submit resolves locally into a clearly pending state; no reward/mastery celebration occurs before acceptance. | S / native | Static queued badge and retry info. |
| MOT-LES-026 | Sync accepted | Pending marker resolves; any reward presentation is generated once from accepted event and may coalesce. | μ/S / native | Static accepted state. |
| MOT-LES-027 | Sync conflict/rejection | Pending state opens a calm repair explanation with preserved input; no success animation rollback trick. | F / native | Static conflict path. |
| MOT-LES-028 | Session stop | User choice folds session into a resume record; no streak threat or guilt animation. | S / native + LUMA still | Immediate exit and resume entry. |
| MOT-LES-029 | Lesson debrief entrance | Final prompt becomes a three-layer receipt: evidence/mastery first, reward second, next/rest choice third. | M / shared element | Static debrief; values live. |
| MOT-LES-030 | Post-debrief choice | Continue, review, or stop each transforms into its true destination without autoplay pressure. | S / shared element | Immediate navigation. |

### E. Rewards, quests, achievements, continuity, and social play

| ID | Sequence | Trigger and choreography | Tier / route | Fallback and proof |
|---|---|---|---|---|
| MOT-RWD-001 | Reward receipt | Immutable `Why +n` line arrives first, final total second, optional LUMA response last. | S / native + LUMA | Static receipt; exactly-once tests. |
| MOT-RWD-002 | XP/mastery count-up | Count-up is cosmetic, bounded, tap-to-final, and never calculates value. | μ/S / native | Final live value immediately. |
| MOT-RWD-003 | Daily quest increment | One quest token advances; multiple low-value events coalesce into one update. | μ / native | Static progress. |
| MOT-RWD-004 | Daily quest complete | Quest folds into a claimed-ready seal; deterministic reward summary remains visible. | S / native + optional LUMA | Static complete state. |
| MOT-RWD-005 | Weekly quest complete | Week path closes with a calm gold bridge and workload-care message. | M / canvas + LUMA | Static weekly receipt. |
| MOT-RWD-006 | Achievement discovered | Badge silhouette resolves from its defining behavior, then title/meaning/reward; no mystery loot reveal. | M / Rive/native | Static badge card and announcement. |
| MOT-RWD-007 | Achievement tier-up | Existing badge evolves in place; previous identity remains recognizable. | M / vector/native | Final badge and tier delta. |
| MOT-RWD-008 | Secret achievement | Delightful but non-essential reveal; reason becomes clear after reveal; no hidden monetization. | M / authored one-shot/native | Static revealed card. |
| MOT-RWD-009 | Level-up | Mastery signals lift the profile level marker; practical meaning/unlock is stated live. | M / canvas + LUMA | Static level receipt. |
| MOT-RWD-010 | Continuity/streak day kept | A warm signal completes today’s link; duration is secondary to meaningful work. | S / native | Static continuity state. |
| MOT-RWD-011 | Streak safeguard | Shield/freeze cliché is avoided; a humane bridge safely spans the missed day and explains grace. | M / canvas + LUMA | Static grace explanation. |
| MOT-RWD-012 | Comeback | Dormant path gently relights from the nearest achievable step; no backlog wall flies at user. | M / canvas + LUMA | Static comeback plan. |
| MOT-RWD-013 | Post-call protection | Recovery Companion settles beside a shorter plan; streak/reward noise is muted and stopping is celebrated as care. | S / LUMA + native | Static protected plan. |
| MOT-RWD-014 | Deterministic chest/package | If retained, container opens only to an already-known reward set; contents and odds never create gambling suspense. | M / Rive/native | Static reward list; no chance mechanics. |
| MOT-RWD-015 | Cosmetic unlock | New cosmetic appears on the real profile/mascot preview with apply/later choice. | M / shared element | Static preview. |
| MOT-RWD-016 | League movement | Position changes along a calm list with reason/time window; no humiliating drop or urgency siren. | S / native | Static rank change. |
| MOT-RWD-017 | Personal-best round | Previous and new evidence traces align, then new mark is acknowledged without confetti overload. | S / native | Static comparison. |
| MOT-RWD-018 | Co-op Ward contribution | User’s accepted contribution joins a shared goal; no PHI, spam reward, or competitive dominance animation. | S / canvas/native | Static contribution ledger. |
| MOT-RWD-019 | Ward goal complete | Contributors’ signals form one original shared bridge; individual contribution remains privacy-safe. | M / canvas | Static team receipt. |
| MOT-RWD-020 | Grand Rounds challenge intro | Case gate opens with calm stakes, scope, and time; no combat or patient-as-boss framing. | M / native + LUMA | Static challenge brief. |
| MOT-RWD-021 | Grand Rounds complete | Reasoning steps illuminate in sequence; outcome celebrates disciplined evidence, not a patient victory metaphor. | X / canvas + LUMA | Static reasoning poster; skippable. |
| MOT-RWD-022 | Reward queue digest | Deferred low-priority receipts compress into one chronological summary after Clinical mode or long absence. | S / native | Static inbox list. |

### F. LUMA and character performance inventory

| ID | Performance | Full choreography | Reduced / Off |
|---|---|---|---|
| MOT-LUM-001 | Neutral idle | Slow fold-breath, tiny eye shift toward active task; pauses offscreen. | Canonical neutral still. |
| MOT-LUM-002 | Greeting | Small bridge-open gesture tied to Today content readiness, once per meaningful return. | Friendly still; no autoplay repeat. |
| MOT-LUM-003 | Prompt | Gaze and one hand/edge gesture toward the prompt, never covering content. | Prompt pose still. |
| MOT-LUM-004 | Thinking | Inner bridge carries a slow signal; no endless spinner mimic. | Thinking still plus live loading text. |
| MOT-LUM-005 | Hint | Light travels from LUMA toward one permitted clue; gaze anchors target. | Hint still and callout. |
| MOT-LUM-006 | Correct | Short high-fold lift and cyan follow-through; gold only for true mastery milestones. | Correct still. |
| MOT-LUM-007 | Repair | Torso leans closer, coral repair token is offered, expression stays calm and non-judgmental. | Repair still. |
| MOT-LUM-008 | Partial | Two small bridge segments show accepted and remaining reasoning. | Partial still. |
| MOT-LUM-009 | Mastery | Inner bridge closes into a warm-gold accent, then returns to cyan baseline. | Mastery still with live summary. |
| MOT-LUM-010 | Quest host | Holds/points to the real quest token; pose does not become a separate unrelated costume creature. | Quest still. |
| MOT-LUM-011 | Achievement lead | Introduces badge, then yields center stage to meaning and evidence. | Badge-side still. |
| MOT-LUM-012 | Streak safe | Physically bridges a gap rather than copying a shield/freeze pose. | Bridge pose still. |
| MOT-LUM-013 | Comeback guide | Relights one reachable route segment and steps aside. | Comeback still. |
| MOT-LUM-014 | Recovery Companion | Canonical high-fold torso reclines without collapsing into a pillow/blob; removable warm lower fold signals rest. | Recovery still. |
| MOT-LUM-015 | Post-call | Low-energy but reassuring; offers shorter plan and stop choice, no guilt. | Post-call still. |
| MOT-LUM-016 | Offline | Holds a disconnected route segment while the UI explains pending state. | Offline still. |
| MOT-LUM-017 | Error helper | Points to recovery action, not error code; no alarm behavior. | Error still. |
| MOT-LUM-018 | Clinical exit | Quietly folds out of the task region before Clinical controls stabilize. | Absent; mode label remains. |
| MOT-LUM-019 | Evidence Guide | Glasses/tablet role accent may orient provenance, but never speaks clinical conclusions. | Evidence-side still or absent. |
| MOT-LUM-020 | Celebration lead | Conducts original signal/bridge motif, never generic confetti or copied mascot dance. | Final celebration still. |
| MOT-LUM-021 | Sleep/rest | Canonical torso and face remain recognizable; loop stops after a bounded settle. | Rest still. |
| MOT-LUM-022 | Audio speaking | Mouth/face motion only when original localized voice exists; subtitle and skip remain available. | Still plus live subtitle. |

LUMA state-machine inputs must include at least: `role`, `semanticState`, `intensity`, `gazeTarget`, `motionPreference`, `mode`, `localeDirection`, `isVisible`, `isInterrupted`, and `presentationReceiptId`. Transitions require explicit entry/loop/exit ownership; no state may strand the character on background/resume.

### G. Clinical, Evidence, and preserved Synapse capabilities

| ID | Sequence | Trigger and choreography | Tier / route | Fallback and proof |
|---|---|---|---|---|
| MOT-CLN-001 | Clinical mode entry | Reward layers and LUMA recede before patient/reference task appears; explicit mode and education boundary remain visible. | F / native | Immediate Clinical surface. |
| MOT-CLN-002 | Evidence source open | Claim anchor connects to warm-paper citation; source/date/version/confidence appear together. | S / shared element | Static evidence sheet. |
| MOT-CLN-003 | Evidence freshness change | Status changes without celebratory motion; stale/updated provenance is explicit and non-color-only. | F / native | Static status. |
| MOT-CLN-004 | ECG route | ECG trace remains medically fixed; selection cursors and annotations move, not the waveform semantics. | F / canvas | Static trace/table equivalent. |
| MOT-CLN-005 | Lab trend inspect | Focus travels along real time order; RTL does not reverse chronology or data meaning. | F / chart-native | Static table and focus labels. |
| MOT-CLN-006 | Case reasoning step | Accepted reasoning node joins the live chain; outcome waits for committed evaluation. | S / canvas/native | Static ordered reasoning list. |
| MOT-CLN-007 | Differential compare | Candidate rows reweight/reorder only with clear cause and reduced-motion-safe stable focus. | F / native | Instant sort with announcement. |
| MOT-CLN-008 | Drug/reference inspect | Selected entity anchors the reference panel; safety/warning information never animates away. | S / shared element | Static detail. |
| MOT-CLN-009 | Critical warning | No celebratory spring/particle; immediate high-contrast state, stable focus, calm haptic where appropriate. | F / native | Static warning and announcement. |
| MOT-CLN-010 | Return to Study | Clinical state is safely saved, then the Study world regains restrained cyan/gold and eligible deferred digest. | S / native | Immediate Study state. |
| MOT-CLN-011 | Rounds entry | Round objective and educational status appear before timers/progress; no combat framing. | S / native | Static brief. |
| MOT-CLN-012 | Round complete | Reasoning/evidence receipt leads; reward is bounded and optional; Clinical mode remains quiet. | M / native | Static debrief. |

### H. Notes, recall, planning, and absorbed StudyHUB workflows

| ID | Sequence | Trigger and choreography | Tier / route | Fallback and proof |
|---|---|---|---|---|
| MOT-HUB-001 | Save note/annotation | Ink/selection anchors into Margin Workspace; save state confirms without page-level celebration. | μ / native | Static saved status. |
| MOT-HUB-002 | Link note to curriculum | A thin bridge connects note and Course/Chapter/Unit/Micro-lesson reference; entity identities stay singular. | S / shared element | Static reference chip. |
| MOT-HUB-003 | Card creation | Selected source becomes a recall-card draft in the workspace; no duplicate mini-app transition. | S / shared element | Immediate draft. |
| MOT-HUB-004 | Recall card flip | Accessible content transition preserves focus and reading order; no 3D vestibular flip in reduced mode. | μ / native | Instant face swap. |
| MOT-HUB-005 | SRS rating | Selected rating settles once and next due date explains itself; scheduling is not reward animation. | μ / native | Static result. |
| MOT-HUB-006 | Terms exercise handoff | Legacy exercise enters the unified session shell through its curriculum anchor. | S / shared element | Standard route. |
| MOT-HUB-007 | Planner reschedule | Task moves along a visible time axis with conflict explanation; no gamified penalty. | S / native | Instant list/calendar update. |
| MOT-HUB-008 | Focus timer start/pause/end | Calm ring motion follows real time and lifecycle; end does not grant passive XP. | F / native | Numeric timer and notification. |
| MOT-HUB-009 | Goal progress | Meaningful committed events advance the goal; raw app-open/passive time does not. | μ / native | Static progress. |
| MOT-HUB-010 | Import/sync | Items resolve into their unified Synapse homes with counts/errors; no false success cascade. | F / native | Static progress/log. |
| MOT-HUB-011 | Search result to workspace | Result anchors into the chosen Study/Clinical/Note context without losing query state. | S / shared element | Standard route. |
| MOT-HUB-012 | Community/peer review | Contribution status changes quietly; accepted quality may receive bounded acknowledgement, never popularity fireworks. | S / native | Static status. |

### I. Widgets, notifications, and platform surfaces

| ID | Sequence | Trigger and choreography | Tier / route | Fallback and proof |
|---|---|---|---|---|
| MOT-OS-001 | App icon/splash continuity | Final icon geometry aligns with splash mark and first shell anchor; OS owns outer launch behavior. | F/S / native platform + Flutter | Static icon/mark. |
| MOT-OS-002 | Notification open | Notification object becomes target context; duplicate reward UI does not replay on open. | S / shared element where supported | Direct deep link. |
| MOT-OS-003 | Widget progress update | System widget uses stable static states; no unsupported looping animation. | F / platform widget | Static accessible progress. |
| MOT-OS-004 | Live activity/session surface | Real session/timer state updates without decorative reward motion. | F / supported platform | Notification/static widget. |
| MOT-OS-005 | Desktop window activation | Active workspace regains focus without replaying route/mascot entrances. | μ / native | Immediate focus. |
| MOT-OS-006 | Web history navigation | Browser back/forward preserves state and uses direction-correct transition only when safe. | S / native web/Flutter | Instant history navigation. |
| MOT-OS-007 | System share | Share card preview is static and provenance-safe; success feedback is bounded. | μ / native | Static success. |
| MOT-OS-008 | Unsupported renderer | State machine selects the deterministic still/native fallback before content becomes interactive. | F / adapter | Fallback-path telemetry and screenshot. |

## Signature showpieces to storyboard before code

### SP-01 — The Synaptic Return

Used after a lesson debrief. The final mastery signal leaves the live receipt, travels through a short shared bridge, seals the completed path node, wakes only the next eligible route segment, and hands focus to Continue/Rest. It is the everyday signature and must prove interruption, exact-once replay, RTL direction, and reduced motion first.

### SP-02 — Chapter Constellation

Every completed lesson contributes one real node. On Chapter completion, the nodes do not explode; they align into the Chapter’s bridge, LUMA conducts a two-beat settle, and a live evidence summary explains what was demonstrated and what remains uncertain. Gold is bounded to the final earned seal.

### SP-03 — Course Horizon

A rare, optional, four-second maximum performance. Completed Chapter bridges connect across a midnight horizon and fold into a Course emblem behind the live Course title. A warm Evidence page then becomes primary, showing mastery dimensions and future review. Full sequence is preloaded, skippable, and replaceable by one static poster plus receipt.

### SP-04 — Humane Comeback

The dormant path relights from the nearest achievable review rather than replaying missed debt. Recovery LUMA keeps the canonical high-fold silhouette, offers a smaller round, and physically bridges only one gap. No loss animation, red countdown, or guilt copy is permitted.

### SP-05 — Quiet Clinical Handoff

When entering Clinical/Evidence, particles, loops, gold, reward HUD, and character performance settle out in a strict order before safety-sensitive content becomes active. The return transition restores the Study layer without replaying old celebrations; eligible receipts appear only as an optional digest.

## Audio and haptic score

| Family | Audio character | Haptic | Prohibitions |
|---|---|---|---|
| press/navigation | dry soft tick / short air bridge | light selection | no cue on every scroll/focus |
| correct | short rising cyan interval | light success | no casino coin sound |
| repair | warm low two-note resolve | gentle soft pulse | no buzzer/alarm/shame sound |
| mastery | restrained glassy-gold resolution | medium success | not on every answer |
| quest/achievement | family motif with tier variation | tiered but bounded | no mystery-box suspense for known rewards |
| recovery/comeback | warm slow chord/air | optional soft pulse | no sad loss cue |
| Clinical warning | calm unmistakable neutral alert | platform-appropriate warning | never reused as ordinary wrong-answer cue |

Audio must be original/licensed, versioned, captioned or semantically duplicated, fatigue-tested, and independently mutable from visuals. Respect mute, DND, headset, clinical context, and unsupported haptics.

## Performance budgets

Initial release/profile targets, refined after baseline:

- 60 Hz: p95 frame time ≤ 16.7 ms and p99 ≤ 25 ms during standard motion on representative mid-tier hardware.
- 90/120 Hz: animation remains refresh-rate aware; no hardcoded 60 Hz stepping.
- No single standard sequence allocates an unbounded particle/controller/listener set.
- LUMA idle pauses when hidden, offscreen, backgrounded, in Off mode, or in Quiet Clinical.
- First high-value animation asset is ready before trigger or uses the native/still fallback; no blank wait for celebration.
- Decoded textures, vector complexity, blur/overdraw, shader compilation, audio latency, and installed/transfer size get explicit per-asset budgets in the asset manifest.
- Repeating a lesson plus debrief ten times must not show monotonic memory/controller growth.
- Full-lesson battery/thermal and celebration stress runs are required on representative Android, iOS CI/device availability, Windows, Web, and the feasible desktop targets.

The numbers are guardrails, not claims. Debug-mode impressions never close a performance row.

## Accessibility and directionality gates

- Full, Reduced, and Off captures are required for every signature sequence.
- Reduced mode removes large travel, parallax, camera movement, looping bounce, and particle storms; it keeps cause/effect through short opacity/color/state changes.
- Screen readers announce the semantic final result once; count-up frames, particles, mascot loops, and decorative intermediate beats are hidden.
- User input, back, pause, skip, and safety state always interrupt motion cleanly.
- No flashing, rapid high-contrast flicker, disorienting zoom, or essential motion-only information.
- Directional route/entrance motion mirrors logically in Persian RTL. ECG, anatomy, chronology, numerals, Latin abbreviations, brand mark, and semantically fixed diagrams do not auto-mirror.
- 200% text, long English/Persian strings, mixed medical terminology, keyboard, mouse, touch, gamepad where supported, and high contrast are capture requirements.

## Cross-platform parity matrix

For Android, iOS, Windows, macOS, Linux, and Web, record per motion family:

- renderer and exact supported feature subset;
- foreground/background lifecycle behavior;
- audio/haptic implementation or substitution;
- shader/graphics backend and fallback;
- asset packaging, preload, decode, cache, and eviction;
- reduced-motion source and in-app override;
- pointer/keyboard/touch interruption;
- release/profile build capture and frame trace;
- known deviation and approved reason.

A successful build does not prove animation parity. Windows-host limitations for Apple targets must be carried into macOS CI/device verification without implied local success.

## First implementation spike — MVS-MOTION-01

The first executable motion slice must include, in one real journey:

1. cold/warm launch continuity using the final selected icon/wordmark;
2. Today/Tonight prescription → Path shared-element transition;
3. current-node idle and node press;
4. Path → Lesson intent → first prompt;
5. one correct and one repair feedback path;
6. one LUMA Rive performance with canonical still fallback;
7. immutable mastery/reward receipt with exactly-once presentation;
8. lesson debrief → Synaptic Return → completed node/unlock;
9. Study → Quiet Clinical suppression and return digest;
10. Full, Reduced, Off, English LTR, Persian RTL, offline, interruption, and duplicate-event tests;
11. release/profile video captures plus frame, memory, asset, audio, and lifecycle traces on feasible targets.

Do not scale to the remaining catalog until this spike proves the state/event architecture and renderer/fallback matrix.

## Production waves

| Wave | Scope | Exit evidence |
|---|---|---|
| 0 | final icon/wordmark continuity, tokens, event/presentation schema, storyboards/animatics | approved artifacts and testable contracts |
| 1 | MVS-MOTION-01 vertical slice | real Flutter journey, captures, traces, reduced/RTL/offline proof |
| 2 | complete lesson/activity feedback grammar | all activity types and interruptions pass |
| 3 | LUMA state machine and role variants | canonical identity, state coverage, fallback and profile matrix |
| 4 | quest/achievement/continuity/recovery catalog | exactly-once receipts, tier discipline, wellbeing critique |
| 5 | Chapter/Course/signature showpieces | animatic match, preloading, skip, fallback, multi-OS profile proof |
| 6 | Clinical/Evidence, StudyHUB workflows, widgets, notifications | reward suppression, functional parity, platform behavior |
| 7 | perfection loop | mismatch, jank, fatigue, accessibility, originality, and edge-case ledgers closed |

## Verification artifacts

Every implemented row needs:

- approved storyboard/animatic or explicit “native functional transition” classification;
- motion spec with exact beats and state diagram;
- asset/audio/haptic manifest and licenses;
- unit/state-machine tests and presentation-idempotency tests;
- golden key frames and a recorded full-speed capture;
- Full/Reduced/Off and English/Persian evidence;
- interruption, back/resume, offline/duplicate, renderer-failure, and missing-asset proof;
- release/profile frame pacing, CPU/GPU, memory, decode, transfer/package, and energy notes;
- mismatch ledger against the approved source and any accepted deviations.

## Completion gate

The Synapse motion system is not complete because animations exist or look attractive in one recording. Completion requires every in-scope inventory row to have truthful triggers, original choreography, live accessible information, interruption and skip semantics, reduced/off variants, correct RTL behavior, deterministic offline/idempotent presentation, cross-platform fallbacks, licensed assets, runtime captures, profiler evidence, and a closed mismatch ledger. Clinical and Evidence surfaces must independently prove that reward theater cannot leak into safety-sensitive work.
