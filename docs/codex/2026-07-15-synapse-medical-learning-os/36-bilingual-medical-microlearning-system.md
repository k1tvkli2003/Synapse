# Bilingual Medical Microlearning System

- Status: implementation-ready content-system design
- Contract: `contracts/curriculum/content-contract.v1.json`
- Canonical content locale: English (`en`)
- Required paired locale: Persian (`fa`)
- Source corpus: `harrison-sim`, the user-provided simulated medical reference
- First authoring wave: Course 06, Cardiovascular System
- Product surface: Medical Academy inside Synapse

## Outcome

This system turns every medically meaningful detail in the source corpus into a
traceable, short, varied learning experience without shrinking the curriculum
or forcing a long source chapter into one exhausting lesson.

It separates two concerns that must never be confused:

1. **Source completeness:** every file and every instructional detail is
   inventoried, atomized, classified, and reconciled.
2. **Learner pacing:** the same complete detail graph is distributed across
   small Micro-lessons, Sessions, and Interactions that respect time, cognitive
   load, language, and activity-variety budgets.

The resulting hierarchy is:

```text
Course (source Part)
└── Chapter (source Chapter)
    └── Learning Path / Unit
        └── Concept Cluster
            └── Micro-lesson
                └── Session
                    └── Step / Interaction
```

An existing source `Lesson_*` directory remains valuable segmentation and
provenance evidence, but it is not forced to become one learner-facing lesson.
It may map one-to-many into Units, Concept Clusters, Micro-lessons, and Sessions.

## Scope Change and Release Boundary

The earlier scaffold requirement intentionally prohibited lesson bodies. The
latest user instruction supersedes that restriction for the new content-
production phase. The safe interpretation is additive:

- The historical scaffold release stays immutable and body-free.
- Bilingual authored content is produced only in later content releases under
  this contract.
- A content release never edits the scaffold release in place.
- Existing Course and Chapter identities remain stable.
- New approved Unit, Concept Cluster, Micro-lesson, Session, and Interaction
  identities are versioned and reviewable.

The older brief, requirement ledger, ADR, importer spec, WBS wording, and any
zero-body assertions must be rebaselined separately before the content phase is
declared active. This document does not silently rewrite those historical
records.

## Design Invariants

1. Every in-scope source file is accounted for.
2. Every instructional source atom is represented; a recap alone never counts.
3. Every authored factual claim traces back to source atoms and, when required,
   current authoritative evidence.
4. English and Persian are authored as one atomic semantic pair.
5. English and Persian share IDs, claims, numbers, units, evidence, answer keys,
   scoring, safety flags, and cognitive demand.
6. Persian is a native pedagogical adaptation, not a word-for-word translation.
7. No Session exceeds the time, concept, interaction, passive-reading, or
   monotony budget in either language.
8. Assessment is embedded across the learning path; it is not a mandatory bulk
   quiz dump.
9. Summary content reinforces learning but never replaces full instruction.
10. Deeper mechanisms live in the correct Micro-lesson; there is no separate
    specialist or enrichment production pipeline.
11. Generated output begins quarantined and cannot publish itself.
12. Medical, language, accessibility, and publication approvals are distinct.
13. Published content is immutable; correction creates a new release.
14. The system is educational and never presents patient-specific guidance.

## Two Interlocking Graphs

### 1. Source Detail Graph

The Source Detail Graph proves that nothing was skipped. It contains:

- source documents;
- deterministic source atoms and exact locators;
- claims and claim candidates;
- media assets and labels;
- duplicate groups;
- citations and evidence versions;
- coverage edges into learner-facing content;
- conflicts, quarantine findings, and supersession links.

### 2. Learning Experience Graph

The Learning Experience Graph makes the material usable. It contains:

- Course and Chapter identity nodes;
- reviewed Units and Concept Clusters;
- Micro-lessons and prerequisites;
- Sessions and cognitive targets;
- Steps/Interactions, answer keys, rubrics, and feedback;
- bilingual semantic units;
- mastery-evidence targets and delayed-retrieval links.

The bridge is the Coverage Ledger. Every source atom points to one or more
learner-facing representations, and every learner-facing claim points back to
its source atoms and evidence.

Each pack also pins the version and SHA-256 of the shared Concept,
terminology, misconception, numeric-token, and rubric registries. References to
those IDs are therefore resolvable and reproducible without duplicating the
global registries inside every Chapter pack.

## Source Inventory and Authority

Every file within an in-scope Part or Chapter is registered before authoring.
The filename does not decide medical authority.

| Artifact role | Use | Authority |
|---|---|---|
| Part index | Validate course order and source inventory | Order metadata only |
| Chapter Markdown | Primary instructional source | Primary user corpus |
| Supplemental Markdown | Unique notes, additions, corrections | Primary user corpus after reconciliation |
| Source Lesson Markdown | Segmentation evidence and content source | Primary user corpus |
| Find sidecar | Candidate explanation and structure | Derived candidate |
| Summary sidecar | Candidate recap and emphasis | Derived candidate; never coverage authority |
| Quiz sidecar | Candidate questions, distractors, misconceptions | Derived candidate |
| Enrich-named sidecar | Candidate detail only | Derived candidate; does not create an enrich phase |
| Contributor sidecar | Candidate authorship metadata | Metadata only; must be verified |
| Media | Visual or signal source | Media evidence subject to rights and medical review |
| Unknown file | Quarantine until classified | No authority |

Structured sidecars are parsed with a strict AST allowlist. They are never
executed. Their contents receive exact provenance and the same factual review
as any other derived candidate.

### Required SourceDocument Fields

Each source document records:

- stable document ID;
- Course, Chapter, and optional source Lesson lineage;
- artifact role and authority tier;
- relative path only;
- raw byte length and SHA-256;
- claimed extension, detected MIME, and optional canonical SHA-256;
- source locale;
- parser version;
- rights state;
- ingest state;
- every finding code.

Absolute local paths never enter a distributed content pack.

## Atomization: The Full-Coverage Unit

A source file is not “covered” merely because it was opened or summarized. It
is atomized into the smallest reviewable semantic units.

Required atom types include:

- headings and contextual paragraph bridges;
- individual factual claims and definitions;
- each link in a mechanism chain;
- every list item;
- each table header and instructional cell;
- formulas, units, numeric thresholds, and comparators;
- warnings, clinical pearls, footnotes, and cross-references;
- figure references, captions, panel labels, and meaningful annotations;
- quiz stems, options, and explanation candidates from source sidecars;
- verified contributor metadata;
- decorative or navigational material that must be accounted for but not taught.

Each atom stores:

```text
source document ID
atom ordinal and type
start/end line and character
heading path
optional table coordinates or media reference
exact-text SHA-256
normalized-text SHA-256
source locale
instructional disposition
duplicate group
risk tier
claim candidate IDs
```

### Claim-Sized, Not Sentence-Blind

Sentence boundaries are a parser aid, not the final unit. A sentence that
contains two independently testable claims becomes two claim atoms plus any
context atom needed to preserve meaning. A formula, threshold, exception, or
warning receives its own atom even when embedded in prose.

### Duplicate Handling

Exact or semantic duplicates are grouped to prevent repetitive teaching, but
every original occurrence remains in the ledger. One learning unit can satisfy
multiple duplicate atoms only through explicit `duplicate_reconciliation`
edges. Deduplication never deletes provenance.

### Non-Instructional Exclusion

Only navigation noise, decorative artifacts, or verified boilerplate may be
marked `non_instructional`. The atom, exclusion reason, and coverage reviewer
remain mandatory. Any medical fact, qualifier, exception, number, table cell,
caption, or warning is ineligible for this disposition.

## Coverage Ledger

Every edge records:

- source atom ID;
- target kind and target ID;
- coverage role;
- state;
- linked claim IDs;
- English/Persian parity state;
- reviewer and note.

Coverage roles are:

- primary instruction;
- mechanism explanation;
- worked example;
- reinforcement;
- assessment;
- media interpretation;
- duplicate reconciliation;
- non-instructional accounting.

Publication requires:

```text
100% source-document inventory
100% source-atom classification
100% required-atom representation
100% output-claim provenance
0 orphan required atoms
0 orphan authored claims
0 summary-only coverage edges
0 unreviewed exclusions
```

If the corpus conflicts with current authoritative evidence, the atom is not
erased. The learning unit explains the discrepancy, current status, applicable
version or jurisdiction, and the reason the older statement cannot be repeated
as current guidance.

## Hierarchy and Identity

| Level | Identity source | Purpose | Progress-bearing? |
|---|---|---|---|
| Course | Source Part ordinal | Top-level curriculum | Yes |
| Chapter | Source Chapter ordinal under Course | Formal source chapter | Yes |
| Unit | Reviewed conceptual route inside Chapter | Coherent learning path segment | Yes |
| Concept Cluster | Reviewed related Concept IDs | Mental-model grouping | Yes |
| Micro-lesson | Approved editorial ordinal under cluster | Small learner-facing objective | Yes |
| Session | Approved ordinal under Micro-lesson | One short learning event | Yes |
| Interaction | Approved ordinal under Session | One active or explanatory step | Attempt evidence only |
| Source Lesson directory | Source container and segmentation evidence | Provenance and boundary candidate | No automatic progress identity |
| Heading candidate | Editorial boundary candidate | Suggested segmentation | No |

### Stable Identity Rules

- Course and Chapter use the existing project-owned UUIDv5 ordinal lineage.
- Locale, mutable title, path, content hash, and release version never define a
  learner-facing node identity.
- Approved IDs are never silently reassigned.
- Split and merge operations create explicit supersession and migration edges.
- A source document version changes when its byte hash changes.
- A source atom version changes when its document, parser version, AST locator,
  or semantic content changes; reconciliation links old and new atoms.
- English and Persian share one semantic-unit ID.
- Answer keys reference option IDs, never translated option positions.

### Hash Rules

- Source bytes: SHA-256 before decoding or transformation.
- Text: UTF-8, NFC, LF line endings; retain medically meaningful symbols,
  punctuation, formula spacing, units, and comparators.
- Structured records: RFC 8785 canonical JSON before SHA-256.
- Media: both raw and canonical-transform SHA-256.
- Reviews and promotions bind to the exact artifact hash that was reviewed.

## Decomposition Pipeline

### Stage 0 — Freeze and Inventory

1. Pin a source-tree hash and importer/parser version.
2. Enumerate every file under the target Course or Chapter.
3. Detect MIME from bytes and bounded decode.
4. Classify artifact role, authority, source locale, rights, and findings.
5. Reconcile the exact file count with the scan manifest.

### Stage 1 — Parse and Atomize

1. Parse Markdown without rewriting it.
2. Parse structured sidecars with a non-executing AST allowlist.
3. Extract prose claims, definitions, mechanisms, lists, tables, formulas,
   thresholds, citations, cross-references, captions, and media labels.
4. Generate deterministic atom locators and hashes.
5. Group exact and probable duplicates without dropping occurrences.
6. Quarantine undecodable, ambiguous, empty, unsafe, or unclassifiable input.

### Stage 2 — Build the Claim and Evidence Graph

1. Convert claim candidates into canonical English claim records.
2. Assign claim type, risk, temporality, jurisdiction, and evidence requirement.
3. Link all contributing source atoms.
4. Resolve current authoritative evidence for time-sensitive or high-risk claims.
5. Verify each citation locator and cited support.
6. Mark conflicts, outdated claims, uncertainty, and supersession explicitly.

### Stage 3 — Design the Fine-Grained Learning Topology

1. Preserve Course and Chapter identity.
2. Use source Lesson directories and headings only as boundary evidence.
3. Group prerequisite-compatible claims into Units.
4. Group tightly related Concepts into Concept Clusters.
5. Give each Micro-lesson one coherent learner promise.
6. Split Micro-lessons into short Sessions using both locale budgets.
7. Sequence Sessions across the cognitive ladder without claiming false mastery.
8. Record source atom ranges, prerequisites, split rationale, and continuity.

### Stage 4 — Author English and Persian Together

1. Freeze a locale-neutral semantic skeleton.
2. Author clear canonical English.
3. Author natural Persian from the same skeleton, not from English word order.
4. Link both variants to the same claims, atoms, terms, numbers, and evidence.
5. Recompute semantic skeleton and text hashes.
6. Block incomplete or mismatched pairs.

### Stage 5 — Compose Sessions and Embedded Assessment

1. Start with a retrieval, prediction, or purposeful orientation.
2. Teach the smallest necessary model or causal chain.
3. Require the learner to construct, discriminate, interpret, or apply.
4. Give immediate concise feedback and available deep reasoning.
5. Repair the smallest identified misconception.
6. Change representation or context for a second attempt.
7. Finish with recall commitment and a short debrief.
8. Schedule delayed retrieval or transfer when justified.

### Stage 6 — Review, Validate, and Promote

1. Run schema and referential-integrity validation.
2. Run coverage, provenance, citation, and rights gates.
3. Run English/Persian semantic, numeric, answer-key, and terminology parity.
4. Run duration, concept-load, active-step, and monotony gates per locale.
5. Run assessment, feedback, placeholder, and misconception checks.
6. Run medical, accessibility, RTL, media, and safety review.
7. Promote `raw → reviewed → validated → published` only on exact hashes.

## Micro-lesson Budgets

### Micro-lesson

| Metric | Target | Hard maximum |
|---|---:|---:|
| Sessions | 2–5 | 7 |
| Total time per locale | 8–20 min | 28 min |
| Concepts | 2–5 | 7 |

### Session

| Metric | Target | Hard maximum/minimum |
|---|---:|---:|
| Time per locale | 3–6 min | 8 min maximum |
| Interactions | 5–9 | 12 maximum |
| New concepts | 1–3 | 4 maximum |
| Independent claims introduced | — | 9 maximum |
| Consecutive passive steps | — | 2 maximum |
| Consecutive same template | — | 2 maximum |
| Interaction families | — | 3 minimum |
| Active-step ratio | — | 45% minimum |
| Time without learner action | — | 90 s maximum |

### Interaction

| Metric | Target | Hard maximum |
|---|---:|---:|
| Completion time per locale | 12–45 s | 75 s |
| Passive prose | 1–3 sentences | 3 sentences |
| Flash feedback | ≤8 s | Deep explanation remains available |

Both locale estimates must pass. Persian cannot be made shorter by deleting
meaning; the content must be split structurally.

## Mandatory Split Rules

Split a Session or Micro-lesson when any condition is true:

- a new learner objective is required;
- a mechanism chain exceeds seven meaningful links;
- a list has more than five independently teachable items;
- a table has more than six instructional rows or four comparison dimensions;
- a figure has more than three instructional panels or recognition targets;
- any locale exceeds a time, concept, claim, interaction, or monotony budget;
- management, dosing, contraindication, or safety content needs a distinct
  evidence version, jurisdiction, or review boundary;
- an unmastered prerequisite blocks safe understanding;
- the activity changes from foundational understanding to complex application
  strongly enough to require a new session intent.

Never split solely by:

- heading level;
- arbitrary word count;
- generator-task boundary;
- English sentence shape imposed on Persian;
- a legacy sidecar filename;
- an aesthetic desire to make every session identical in size.

Every split keeps prior/next Concept links, prerequisite IDs, source-atom ranges,
and a recorded rationale.

## Session Grammar

Not every Session uses every phase, but the shortest coherent arc contains at
least three meaningful phases:

```text
orient
→ retrieve or predict
→ explain or model
→ guided construction
→ discriminate
→ apply
→ calibrate
→ repair
→ recall commit
→ debrief
```

### Cognitive Ladder

```text
Recall → Explain → Connect → Diagnose → Decide → Defend → Teach → Transfer
```

The ladder is not one global level. A learner may recall a concept while still
being weak at discrimination or transfer. A single session targets the smallest
justified span and emits only the mastery evidence it actually observed.

## Interaction Families

| Family | Representative interactions | Primary use |
|---|---|---|
| Orientation | orient card, learning promise | Set intent without a lecture |
| Retrieval | predict, cloze, short answer, recap retrieval | Recall before cueing |
| Explanation | concise model, evidence peek | Teach why/how |
| Construction | causal-chain build, sequence order, concept match | Build a mental model |
| Discrimination | compare/contrast, single-best answer, multi-select | Separate look-alikes |
| Application | vignette, branching decision, ECG, lab, image, audio | Use knowledge in context |
| Confidence | confidence rating | Calibrate certainty |
| Reflection | teach-back, debrief | Explain, defend, and plan review |

No family should exceed half of a Session unless an accessibility adaptation
requires it. A template cannot appear more than twice consecutively.

## Interaction Record

Every interaction contains:

- stable Session and ordinal identity;
- step role, interaction family and kind;
- cognitive target;
- bilingual prompt and instruction semantic-unit IDs;
- localized and media stimuli;
- response type and structural constraints;
- locale-neutral answer key or rubric;
- scoring version and mastery dimensions;
- complete flash, repair, and deep feedback;
- why-correct feedback;
- why-wrong feedback for every distractor;
- linked source atoms, claims, Concepts, and misconceptions;
- English and Persian time estimates;
- keyboard, screen-reader, color-independent, and scientific-mirroring rules.

## Embedded Quiz and Assessment Policy

Assessment is distributed through learning, repair, application, challenge, and
checkpoint sessions.

There is no mandatory separate quiz-authoring phase, no fixed 15–30 question
file, and no requirement to exhaust a learner after each Micro-lesson.

### Rules

1. A question assesses taught claim IDs unless it is explicitly diagnostic.
2. Diagnostic items do not punish mastery or grant a competence claim.
3. Four or five choices are used only when cue-based discrimination is useful.
4. Constructed response is preferred when choices would trivialize recall.
5. Every correct answer includes mechanism or clinical reasoning.
6. Every distractor maps to a plausible misconception or explicit error rule.
7. Every distractor has a complete why-wrong explanation.
8. No placeholder, irrelevant trivia, answer-length cue, invented fact, or trick
   wording is allowed.
9. A second attempt changes representation or context.
10. A clinical vignette is short, synthetic, de-identified, and present only
    when a patient context materially improves learning.
11. Every major Concept and every high-risk claim is assessed before Chapter
    validation and appears in a delayed-retrieval plan.
12. Not every source atom needs a unique question; assessment coverage is at the
    Concept and claim level.

### Feedback Layers

- **Flash:** correct, incorrect, partial, and the key distinction.
- **Repair:** the smallest misconception and corrective move.
- **Deep:** mechanism, why-correct, every why-wrong, evidence, and nuance.
- **Debrief:** performance pattern, calibration, uncertainty, and next review.

Deep feedback must exist in the data even when the default flow shows only
Flash feedback.

## Summary Boundary

Summary is a reinforcement role, not a production phase and not a coverage
shortcut.

A recap or debrief may:

- prompt retrieval;
- compress a mental model already taught;
- show a comparison already grounded;
- identify uncertainty and next review;
- link back to the relevant Micro-lessons and evidence.

It may not:

- be the only representation of a source atom;
- introduce an unsupported claim;
- replace primary instruction;
- hide omitted tables, qualifiers, exceptions, or warnings;
- become a separate bulk summarization pipeline.

## No Separate Enrichment Workflow

There is no specialist-writing or “enrich” stage in this architecture.

If a mechanism, nuance, differential, or safety detail is necessary, it is:

1. represented as a source atom or evidence-backed claim;
2. placed in the correct Unit and Concept Cluster;
3. taught in a bounded Micro-lesson or optional deep-feedback layer;
4. reviewed under the same medical and bilingual gates.

An enrich-named source sidecar may contribute candidate details, but the name
does not grant authority and does not create a separate learner mode.

## English–Persian Semantic Pair

Every learner-facing string is a locale-neutral semantic unit with two required
variants.

### Shared Fields

Both variants share:

- semantic unit ID and role;
- semantic skeleton SHA-256;
- source atom and claim IDs;
- Concept and terminology IDs;
- structured numeric and unit tokens;
- evidence and safety status;
- interaction intent and cognitive demand;
- option IDs and answer key;
- scoring and mastery target.

### Allowed Adaptation

English and Persian may differ in:

- sentence count;
- information order;
- analogy and idiom;
- explicitness needed for natural comprehension;
- where a standard English/Latin term is introduced.

They may not differ in medical meaning, qualification, number, unit, comparator,
answer, risk, evidence, or required learner action.

### Atomic Pair Publication

- Both variants are authored in the same task.
- Missing English or Persian blocks the pair.
- Published lesson bodies do not silently fall back to the other language.
- Semantic parity, medical parity, and answer-key parity must be 100%.
- Each variant has its own text hash and review status.

## Persian Authoring and RTL

Persian content must:

- read like natural modern Persian for medical learners;
- use Persian `ی` and `ک` and correct half-spaces;
- remain warm and encouraging without forced slang or a repeated catchphrase;
- preserve standard English or Latin medical terms when useful and explain them
  naturally at first meaningful use;
- isolate drug names, abbreviations, formulas, values, units, URLs, IDs, ECG lead
  names, and other LTR fragments;
- store medical numbers structurally rather than baking locale-specific glyphs
  into answer logic;
- separate language from region, calendar, timezone, and numeral preference;
- receive both native Persian review and medical review.

RTL presentation mirrors navigation and reading flow. It never mirrors ECG
traces, anatomy laterality, radiology orientation, plots, formulas, or other
fixed scientific directionality.

## Claims and Evidence

Each claim records:

- canonical English meaning;
- claim type;
- risk tier;
- stable, versioned, or time-sensitive status;
- jurisdiction;
- source atom IDs;
- evidence citation IDs;
- required evidence strength;
- support, conflict, outdated, withdrawn, or quarantine state;
- as-of and next-review dates where relevant;
- supersession link.

### Evidence Requirement by Risk

| Risk | Minimum evidence |
|---|---|
| Foundational | Corpus provenance plus medical review |
| Clinical low | Claim review plus explicit educational scope |
| Clinical high | Current authoritative source, version/date/jurisdiction, medical review, limitations |
| Safety critical | Designated primary or multiple authoritative sources, independent approval, forced recency, withdrawal path |

Current authoritative evidence is always required for:

- diagnostic criteria;
- management recommendations;
- drug selection or dose;
- contraindications and safety warnings;
- procedural safety steps;
- guideline staging;
- time-sensitive epidemiology.

### Citation Gate

A citation is accepted only when:

1. its URL, DOI, PMID, document locator, or source-document key resolves;
2. title, publisher, date/version, retrieval time, and jurisdiction are recorded;
3. the cited passage or section is located;
4. the cited material actually supports the linked claim;
5. a content hash is captured;
6. rights or use basis is recorded where applicable.

A generated citation string is not evidence. A disclaimer cannot repair an
unsupported claim.

## Media Provenance and Accessibility

Every used asset records:

- origin type;
- source document and atom IDs;
- raw and canonical hashes;
- detected MIME;
- content-addressed storage key;
- rights state;
- educational purpose;
- English/Persian caption and alt-text units;
- accessible alternative;
- medical review result;
- deterministic transform log.

Rules:

- Magic bytes and bounded decode override extension.
- No source asset is referenced through an absolute local path.
- Decorative stock imagery does not belong in an educational pack.
- Generated medical illustrations are labeled and medically reviewed.
- An attractive but anatomically uncertain image is rejected.
- Pattern-recognition media needs a nonvisual route without claiming that the
  alternative proves visual mastery.
- Image labels, panels, legends, and captions are source atoms and part of the
  coverage ledger.

## Accessibility Contract

Every Interaction is:

- keyboard operable;
- screen-reader comprehensible;
- independent of color alone;
- untimed by default;
- usable at 200% text scale;
- available in Full, Reduced, and Off motion modes;
- equipped with an alternative when drag, hotspot, audio, or visual recognition
  cannot be performed;
- explicit about whether scientific content may mirror.

Accessibility alternatives preserve the learning objective and scoring boundary.
They do not pretend that a different sensory task produces identical mastery
evidence when it does not.

## Promotion State Machine

```text
raw
→ reviewed
→ validated
→ published

side states:
quarantined | withdrawn | superseded
```

### Raw

- complete source inventory and deterministic atomization;
- candidate claims and evidence;
- draft fine-grained hierarchy;
- simultaneous English/Persian authoring;
- complete interactions and generator provenance;
- unavailable to learners.

### Reviewed

The exact artifact hash has approvals from:

- source coverage reviewer;
- medical reviewer;
- English editor;
- Persian native reviewer;
- accessibility reviewer.

All blocking review findings are resolved.

### Validated

Automated and deterministic checks pass for:

- schema and references;
- identities, ordering, versioning, and hashes;
- source coverage and output provenance;
- citation validity and evidence requirements;
- English/Persian entity, semantic, numeric, and answer parity;
- time, concept, activity-variety, active-step, and monotony budgets;
- assessment blueprint and feedback completeness;
- media existence, MIME, rights, captions, and accessibility;
- medical safety and recency;
- real content consumer load and pack reconciliation.

Blocking findings: zero.

### Published

- Publisher is distinct from author.
- Generator cannot approve or publish.
- Validated release is immutable.
- Activation changes a channel pointer.
- Correction creates a new release.
- Rollback restores the previous pointer without deleting history.

## Hard Safety Stops

Any item below blocks promotion and quarantines the smallest safe release unit:

- unsupported or fabricated claim;
- fabricated, unresolved, or non-supporting citation;
- English/Persian mismatch in a dose, threshold, comparator, unit, answer,
  contraindication, or warning;
- outdated time-sensitive guidance presented as current;
- self-approval;
- patient-specific recommendation;
- hidden decision-support behavior;
- unreviewed generated medical media;
- open safety-critical finding;
- missing source or output provenance.

Recovery preserves the finding and prior version, repairs the content, obtains
fresh independent review, revalidates, and publishes a new immutable release.

## Quality Metrics and Acceptance Gates

### Required 100% Metrics

- source-document inventory;
- source-atom classification;
- required-atom representation;
- output-claim provenance;
- English/Persian entity parity;
- English/Persian semantic-skeleton parity;
- answer-key parity;
- valid citation locators and support;
- media references and accessible alternatives;
- terminology first-use handling;
- Interaction accessibility;
- reviewer separation.

### Zero-Tolerance Counts

- unclassified documents or atoms;
- orphan required source atoms;
- summary-only coverage;
- orphan output claims;
- unsupported claims;
- fabricated or unverified citations;
- semantic, answer, numeric, unit, warning, or safety locale mismatches;
- placeholder or TODO text;
- broken or rights-unknown published media;
- Session budget violations;
- monotony violations;
- open blocking or safety-critical findings;
- author/publisher identity collision.

### Chapter Acceptance

A Chapter can be validated only when:

1. every in-scope source file and source atom reconciles;
2. every approved Micro-lesson and Session passes both locale budgets;
3. every major Concept and high-risk claim appears in the assessment blueprint
   and delayed-retrieval plan;
4. no learner-facing content depends on a separate summary, quiz, or enrichment
   mode to be complete;
5. the compiled pack loads in the real content consumer;
6. deterministic IDs, order, references, and hashes remain stable;
7. raw-to-published reconciliation accounts for every added, changed,
   quarantined, superseded, and excluded record.

## Concurrency-Safe Content Sharding

External generation can work in parallel only after this contract and the
source inventory are frozen.

Safe shard boundary:

```text
one Chapter
or
one approved Unit inside a very large Chapter
```

Each shard receives:

- immutable source-document and source-atom manifest;
- preallocated ID namespace;
- exact allowed output path;
- required Concepts and prerequisite context;
- evidence requirements;
- English/Persian pair requirement;
- budgets and acceptance gates;
- expected artifact hash inputs;
- no secret material.

Parallel shards may not:

- allocate overlapping IDs;
- edit shared registries directly;
- invent cross-shard prerequisites;
- publish;
- resolve merge conflicts by dropping source atoms;
- change the contract or parser version.

The deterministic merge validates all IDs, global references, Course/Chapter
order, source-atom coverage, duplicate groups, and cross-shard prerequisites
before promotion.

## Cardiology-First Rollout

The first content wave is `harrison-sim/course/06`, Disorders of the
Cardiovascular System.

Recommended progression:

1. Freeze the complete Course 06 file and atom inventory.
2. Pilot two structurally different Chapters:
   - one explicitly segmented Chapter with source Lesson directories;
   - one unsegmented, media-rich Chapter requiring reviewed decomposition.
3. Validate the full bilingual and coverage pipeline on both.
4. Lock parser, atomizer, schema, budgets, and review forms.
5. Expand across Course 06 in non-overlapping Chapter shards.
6. Run Course-wide duplicate, prerequisite, terminology, evidence, and coverage
   reconciliation.
7. Publish to `internal`, then `beta`, before any stable channel activation.
8. Apply the proven system to the next medically important Course.

This pilot must include at least one mechanism-heavy topic, one signal or image
interpretation topic, and one management/safety topic so the contract is tested
against the hardest content classes early.

## Adaptation Boundary

The legacy authoring prompt corpus contributes only these useful principles:

- read every relevant source file;
- preserve full coverage;
- teach why and how;
- explain terminology at first meaningful use;
- use purposeful vignettes and media explanations;
- provide complete why-correct and why-wrong feedback;
- reject placeholders;
- validate content quality beyond syntax.

It does **not** contribute:

- any legacy product name, narrator persona, folder convention, or TypeScript
  output shape;
- a specialist or enrichment workflow;
- a summary phase that may replace full coverage;
- a bulk quiz file or fixed question count;
- provider-specific research commands;
- forced images, scenarios, cross-links, or arbitrary patient-name rules.

The content contract remains provider-neutral. Platform usage and task
orchestration belong to the platform skill; they cannot weaken artifact gates.

## Validator Responsibilities

Implementation should provide validators for:

1. JSON Schema compliance.
2. Unique IDs and complete foreign-key references.
3. Parent-kind and ordinal hierarchy rules.
4. Source file count and hash reconciliation.
5. Source atom locators, duplicates, and coverage edges.
6. Claim-to-source and claim-to-evidence traceability.
7. Citation resolution and claim-support review state.
8. Media MIME, existence, rights, hashes, captions, and alternatives.
9. English/Persian presence, semantic skeleton, claims, terms, numeric tokens,
   answer key, scoring, safety, and status parity.
10. Session duration, claim, concept, interaction, passive-step, active-step, and
    template-diversity budgets in both locales.
11. Complete feedback and misconception mapping.
12. Placeholder, filler, unsupported claim, and duplicate-content detection.
13. Review separation and exact-hash approval.
14. Promotion transition legality.
15. Real pack-loader and content-consumer smoke tests.

## Implementation Handoff

The next implementation slice should create, in order:

1. source inventory and atom schemas matching the contract;
2. Markdown and allowlisted sidecar parsers;
3. deterministic atomizer and duplicate detector;
4. claim/evidence and media provenance stores;
5. hierarchy decomposition manifest and ID allocator;
6. bilingual semantic-unit authoring format;
7. Session/Interaction composer and budget calculator;
8. coverage, parity, safety, accessibility, and promotion validators;
9. immutable Chapter-pack builder;
10. a Cardiology pilot task pack and local validation run.

No actual medical lesson, external generation session, remote publication,
commit, stage, or push is performed by this design artifact.

## Known Risks

| Risk | Mitigation |
|---|---|
| Fine atomization creates very large ledgers | Stream by Chapter, store hashes/locators, and compile compact release indexes |
| Full coverage produces bloated lessons | Preserve atoms in the ledger and split across more Micro-lessons/Sessions |
| Persian becomes a late translation | Atomic pair schema and no published-body fallback |
| English and Persian answers diverge | Option IDs, numeric tokens, and semantic skeleton parity |
| Legacy sidecars are treated as truth | Derived-candidate authority and medical/evidence review |
| Summaries hide omissions | Summary-only coverage is a blocking finding |
| Parallel generation collides | Frozen shard manifests and preallocated non-overlapping IDs |
| Generated citations look plausible | Resolve locator, verify supporting passage, and hash evidence |
| Time-sensitive guidance becomes stale | Claim temporality, as-of date, next review, withdrawal, and supersession |
| Rich media harms accessibility | Captions, alt text, alternatives, and evidence-type honesty |
| Gamification encourages speed over learning | Untimed interactions and mastery evidence independent of raw tap volume |

## Design Verification Performed

- The contract is valid JSON and parses without error.
- It is a Draft 2020-12 JSON Schema with project-specific policy annotations.
- Required English and Persian variants are structurally explicit.
- Every required hierarchy level is represented across node, session, and
  interaction records.
- Source, claim, evidence, media, coverage, promotion, and QA records have
  explicit required fields.
- The full-coverage, micro-budget, split, activity, bilingual, safety,
  accessibility, and raw-to-published gates are machine-readable under
  `x-synapse`.
- No medical lesson bodies or external sessions were created.
