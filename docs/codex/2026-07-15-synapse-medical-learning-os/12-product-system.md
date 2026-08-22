# Product System — Synapse Medical Learning OS

## Visual Direction Status

No global visual direction is currently selected. The first generated **Synapse Atlas — Atlas of Mastery** board was explicitly rejected by the user as dry and lifeless. Its useful structural ideas remain candidates at the UX layer, but its porcelain/editorial/cartographic expression is not the implementation spec.

Ten preview-backed alternatives are defined in `18-visual-concept-exploration.md`. The user’s selection or explicit blend becomes the binding visual direction before new-shell implementation. The information architecture and capability-preservation decisions below remain product invariants unless the chosen world reveals a concrete usability conflict.

## Rejected Structural Synthesis — Retained for Parts

It combines four compatible ideas:

- Atlas of Mastery: a navigable curriculum terrain at Course, Chapter, Unit, Micro-lesson, and Concept scales.
- Living Folio: a source reader and personal Margin Workspace absorbed into the learning context.
- Dual-Lens Ledger: one system with explicit Study and Clinical presentation/claim modes.
- Case Weave: concept, error, evidence, and patient-case threads remain visibly connected.

The experience is not a literal map everywhere. “Atlas” is a system metaphor expressed through hierarchy, scale, contour, thread, pins, folds, provenance, and a visible relationship between location and mastery.

## Core Loop

```text
Curriculum location
→ next-best prescription
→ short active session
→ feedback and misconception repair
→ source/evidence/workspace context
→ clinical application or skill transfer
→ peer teach-back when useful
→ delayed mastery check
→ updated prescription
```

All steps share stable curriculum nodes, Concept IDs, Evidence metadata, attempt/session identity, and a multidimensional Mastery Ledger.

## Direction Exploration

The selection rubric weights: core-loop fit 25, IA cohesion 20, clinical trust 15, brand distinctiveness 15, RTL/multilingual readiness 10, feasibility/performance 10, and mascot/world fit 5.

| # | Direction recipe | Score | Use |
|---|---|---:|---|
| 1 | Atlas of Mastery | 93 | Selected foundation |
| 2 | Apprenticeship Compass | 91 | Workload/career continuity layer |
| 3 | Case Weave | 90 | Case and mastery-thread interaction |
| 4 | Living Folio | 91 | Margin Workspace and source-reader system |
| 5 | Signal Observatory | 87 | ECG/Labs/Sounds visualization language |
| 6 | Rounds Theatre | 87 | Rounds episodes and event framing |
| 7 | Clinical Transit | 84 | Alternative outline/route view |
| 8 | Symptom Constellation | 81 | Differential visualization only |
| 9 | Patient Journey Timeline | 82 | Longitudinal case detail |
| 10 | Memory Conservatory | 79 | Rejected as too close to common growth metaphors |
| 11 | Evidence Forge | 79 | Achievement/craft subtheme only |
| 12 | Clinical Chessboard | 76 | Too narrow/tactical as global identity |
| 13 | Diagnostic Escape Rooms | 72 | Event mode only; risk of trivialization |
| 14 | Museum of Medicine | 78 | Discovery pattern, weak daily loop |
| 15 | Knowledge City | 72 | High world-building cost and lower precision |
| 16 | Procedure Workshop | 79 | Procedure/OSCE module pattern |
| 17 | Triage Flight Deck | 79 | Too stressful/dense for long study |
| 18 | Clerkship Seasons | 82 | Rotation and planning layer |
| 19 | Study Playlist | 78 | Session queue pattern |
| 20 | Learning Feed | 71 | Rejected as passive-feed risk |
| 21 | Medical Guild | 76 | Community subtheme; popularity risk |
| 22 | Memory Palace District | 71 | Cost, accessibility, and spatial-memory risk |
| 23 | Modular Lab Bench | 83 | Desktop workspace behavior |
| 24 | Dual-Lens Ledger | 90 | Selected invariant |

## Superseded First-Pass Direction Comparison

| Direction | Composition | Strength | Main risk | Score |
|---|---|---|---|---:|
| Synapse Atlas | Atlas + Folio + Dual Lens + Case Weave | Best fit for real hierarchy, StudyHUB absorption, Concept Graph, and cross-role continuity | Custom map semantics/performance | **94** |
| Guided Shift | Apprenticeship + Case Weave + Rounds Theatre | Strong daily/rotation coaching and teach-back | Can feel paternalistic and resident-centric | 89 |
| Signal Field | Observatory + Case Weave + Lab Bench | Distinctive for diagnostic signals and tools | Dark/sci-fi density and RTL routing | 86 |

This comparison predates generated visual evidence and is superseded for global styling and branding. Atlas still demonstrates one possible curriculum topology, but it no longer “wins” by default. The new ten-direction set deliberately varies energy, saturation, dimensionality, character language, and emotional promise while preserving the same audited product truth.

## Information Architecture

| Destination | One stable job | Primary objects | Contextual tools |
|---|---|---|---|
| Today | Choose and complete the best next action. | Prescription, workload, review debt, continuity, active plan, resume | Focus, defer/adjust, quick insight, notifications |
| Path | Navigate curriculum and build mastery. | Course Atlas, Chapter Trail, Unit path, Micro-lesson Station, session, Mastery Thread | Margin Workspace, Terms, Cards, Mnemonics, source/evidence |
| Clinical | Practice reasoning/skills and retrieve trustworthy guidance. | Cases, OSCE, ECG, Sounds, Labs, Algorithms, OR Lab, reference/tools | Clinical Peek, Evidence Shelf, calculator, save-to-review |
| Rounds | Learn and teach with verified people. | Case discussion, audio round, ward/cohort, class, event, co-op quest | Transcript, citation, moderation, accepted reasoning |
| You | Understand identity, readiness, history, preferences, and rewards. | Mastery, insight, achievement, inventory, settings, privacy, role | Export, subscription, companion/game visibility |
| Global | Find, ask, communicate, act, and author. | Search, Command, Copilot, Inbox, Notification, Create/Admin/Org | Context-aware actions and role gates |

## Scale Model

The Atlas supports multiple equivalent views so spatial novelty never blocks access:

| Scale | Visual view | Semantic alternative | Primary action |
|---|---|---|---|
| Whole curriculum | 20 Course regions | Searchable ordered Course list | Choose/resume Course |
| Course | Chapter terrain/ribbons | Chapter outline with progress and status | Continue Chapter |
| Chapter | Lesson trail/stations | Ordered Lesson list and checkpoints | Start/continue Lesson |
| Lesson | Session route + Margin Workspace | Activity queue + source outline | Continue activity |
| Concept | Mastery Thread and related resources | Structured concept dossier | Repair/practice/apply |

Map and outline share the same state. Keyboard, screen reader, reduced-motion, low-power, and dense professional preferences can default to the outline without losing function.

## Today Prescription

Today is not a dashboard collage. Its first viewport contains:

1. One next-best action with a direct start/continue control.
2. A concise explanation of why it is next.
3. Expected time and activity composition.
4. Current workload/continuity context.
5. A visible adjustment/defer path.

Secondary content follows in a bounded order:

- Due review/repair queue.
- Resume reader/audio/session.
- Active plan milestones.
- One relevant quest or ward goal.
- Small mastery/workload insight.
- Browse Path escape hatch.

Today never rewards opening the app or passive time. Its objective is high-value learning completed under a sustainable workload.

## Session Architecture

### Session Types

- Learn: introduce and connect a concept.
- Recall: retrieve without cue dependence.
- Repair: diagnose and correct a misconception.
- Apply: use knowledge in a case or signal.
- Challenge: integrate several concepts under constraints.
- Exam: simulate assessment conditions.
- Teach: explain or defend for another learner/reviewer.
- Transfer: solve a delayed, novel, or cross-context problem.

### Activity Ladder

```text
Recall → Explain → Connect → Diagnose → Decide → Defend → Teach → Transfer
```

The ladder is not a single linear level number. A concept may be strong in recall but weak in discrimination, confidence, or application.

### Session Flow

1. Intent and time expectation.
2. Calibration prompt when appropriate.
3. Retrieval/application activity.
4. Immediate concise feedback.
5. Optional explanation zoom.
6. Error classification and repair.
7. Interleaved second attempt or different representation.
8. Evidence/source access without leaving context.
9. Session debrief: what changed, what remains uncertain, what returns later.
10. One authoritative reward summary after the server transaction.

### Feedback Levels

- Flash: correct/incorrect/partially correct and the key distinction.
- Repair: why the reasoning failed and the smallest corrective action.
- Deep: mechanism, why-not distractors, evidence, nuance, and related concepts.
- Debrief: session patterns, calibration, transfer, and scheduled next step.

## Mastery Model

Mastery is a vector, not XP:

| Dimension | Meaning | Example evidence |
|---|---|---|
| Recall | Retrieve the core fact/concept without excessive cueing. | Short answer, cloze, image label |
| Discrimination | Separate look-alikes and tempting wrong alternatives. | Contrast set, why-not distractor |
| Explain | State mechanism/causal rationale accurately. | Teach-back, ordered explanation |
| Connect | Relate concepts across systems or representations. | Concept link, mechanism chain |
| Application | Use knowledge in a familiar clinical context. | Focused vignette |
| Reasoning | Integrate uncertainty and multiple findings. | Differential/case branch |
| Procedure | Recall and execute ordered/safety-critical steps. | OSCE/procedural rubric |
| Confidence calibration | Match certainty and escalation to actual performance. | Confidence vs outcome history |
| Recency/stability | Demonstrate durable retention over time. | Spaced delayed retrieval |
| Transfer | Apply knowledge in a novel/distant context. | New case, cross-specialty problem |

The product may summarize these for users, but it must not collapse them into a deceptive single “medical competence” number.

## Study and Clinical Lenses

| Attribute | Study lens | Clinical lens |
|---|---|---|
| Objective | Learn, practice, recover, progress | Retrieve, reason, verify, act within scope |
| Tone | Warm, encouraging, characterful | Quiet, precise, provenance-led |
| Mascot | Full/Essential/Off according to setting | Essential/Off by default; absent during critical warnings |
| Rewards | Visible at bounded summaries | Hidden from the task surface |
| Motion | Expressive but brief and reducible | Minimal state-preserving transitions |
| Density | Guided and progressive disclosure | Information-dense with strong hierarchy |
| Claims | Educational | Reference or explicitly bounded CDS |
| Evidence | Available in context | Prominent source/date/version/uncertainty |
| Error state | Coaching and repair | Safety-first, explicit limitation/escalation |

The same object can be seen through both lenses without duplicating identity or history.

## Margin Workspace

The Margin Workspace is the contextual reading, evidence, annotation, and
knowledge-work surface. Its name describes the learner's task; the legacy
repository that supplied some capabilities is never exposed as a product area.

### Compact

- Bottom sheet or full-screen contextual layer.
- Tabs/modes: Source, Notes, Evidence, Thread.
- Preserves lesson activity state underneath.
- Quick highlight-to-note/card and resume.

### Expanded

- Resizable side workspace next to Atlas/session/case.
- Source reader with page/search/zoom.
- Anchored notes/annotations/tags.
- Concept thread/mind map.
- Evidence provenance and related resources.
- Copilot thread scoped to current node/document.

The workspace is stateful per node/document but uses one unified repository and universal resource reference.

## Core End-to-End Flows

### New learner

Onboarding → role/stage/goals/time/language/privacy → diagnostic optional → first prescription → Path orientation → short session → summary → next scheduled action.

### Returning learner

Today → resume/repair/review → activity → debrief → Atlas progress update → optional deeper source or stop.

### Source-led study

Path Chapter → Margin Source → highlight/note → create card/question draft → practice → delayed review → source lineage retained.

### Clinical transfer

Lesson mastery gap → case/ECG/lab encounter → confidence + decision → evidence peek → debrief → repair scheduled.

### Point lookup to learning

Clinical Search → reference result with provenance → optional “review later” → quiet save confirmation → later Today micro-review.

### Peer teaching

Mastered/uncertain concept → private Ward prompt → teach-back/case reasoning → peer/faculty rubric → accepted artifact → mastery evidence (bounded, not automatic truth).

### Comeback

Return after absence → no backlog wall → workload reset choices → short reorientation/diagnostic → compassionate continuity repair → new sustainable plan.

## Interaction Grammar

- Atlas canvas: spatial curriculum navigation.
- Ribbon: ordered scope/phase without a generic card.
- Station: startable Lesson/Checkpoint entity.
- Mastery ring: multidimensional state with text/semantic equivalent.
- Thread: visible relationship among misconception, concept, evidence, resource, and case.
- Evidence pin: sourced/versioned support.
- Margin inspector: contextual tools and personal artifacts.
- Clinical Peek: fast, provenance-first reference without context loss.
- Command dock: safe-area-aware global search/action/Copilot entry; replaces the overlapping always-floating button.
- Summary plate: one bounded reward/debrief moment.

Generic cards remain for true independent artifacts, not as the default container for every section.

## Responsive Composition

| Width/context | Navigation | Atlas | Workspace | Global command |
|---|---|---|---|---|
| Compact phone | Bottom destinations; safe-area aware | Full viewport; outline toggle | Sheet/full screen | Dock/button integrated above navigation |
| Large phone/foldable | Bottom/rail based on posture | Canvas + collapsible details | Side sheet when space permits | Persistent compact dock |
| Tablet | Navigation rail | Canvas + inline chapter ribbon | Resizable side pane | Keyboard/touch command |
| Desktop/Web | Rail/sidebar with destinations | Virtualized canvas and outline | Dockable/resizable pane | Command palette + shortcuts |

RTL mirrors navigation and logical path flow where directional. Anatomy laterality, ECG traces, radiology, plots, formulas, and other scientific directionality do not mirror.

## Product Integrity Gates

- One primary action is visible on Today, Course, Chapter, Unit/Micro-lesson, and session summary.
- A user can always view the full syllabus, search, or choose an alternative; personalization does not imprison them.
- Map and outline states are equivalent and synchronized.
- Mascot/rewards/shop/league elements never obstruct medical content or appear in critical Clinical warnings.
- Source/evidence access preserves current task and scroll/session state.
- Route refresh/deep link restores the correct destination, node, mode, and accessible focus.
- Every surface has loading, empty, error, offline, stale, permission, retry, and recovery behavior.
- English/Persian, compact/expanded, 200% text, keyboard/screen-reader, reduced-motion, and low-power states are designed before sign-off.
