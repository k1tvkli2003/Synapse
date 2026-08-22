# Harrison-like Source Inventory and Curriculum Decomposition Baseline

## Decision and scope

This is the read-only baseline for the user-provided corpus at
`C:\Users\K1\Desktop\Harrison`. The user classifies it as a self-created,
simulated Harrison-like source rather than the Harrison textbook. No lesson
was authored, no source file was changed, and nothing was uploaded to Jules or
another external service during this audit.

The machine-readable authority is
`contracts/curriculum/source-inventory.v1.json`. It records every observed file,
its normalized relative path, deterministic source-file ID, role, byte size,
SHA-256, hierarchy anchors, text/interaction signals, media signature and
dimensions, reference state, and current coverage disposition.

## Snapshot

| Measure | Observed value |
|---|---:|
| Parts / future canonical Courses | 20 |
| Chapter directories | 1,138 |
| Explicit source `Lesson_*` directories | 186 |
| Chapters with explicit source Lesson anchors | 73 (6.41%) |
| Chapters without explicit source Lesson anchors | 1,065 (93.59%) |
| Structurally complete explicit source Lesson anchors | 176 / 186 |
| Directories below the source root | 2,022 |
| Files | 4,560 |
| Bytes | 222,028,893 (211.743 MiB) |
| Canonical chapter-source words | 4,088,473 |
| Raw words across all Markdown and TypeScript | 5,030,470 |
| Raw Persian-script word signals | 416,525 |
| Markdown tables / table rows | 1,467 / 20,249 |
| Declared Markdown image references | 4,421 |
| Existing TypeScript quiz questions | 2,610 |
| Existing TypeScript flashcards | 2,021 |
| Corpus manifest SHA-256 | `0fee55c0ad18ca1c71c42a19e23e279f1d498c10fec8187503cf589ecd997d0d` |

### File formats

| Extension | Files | Bytes | Notes |
|---|---:|---:|---|
| `.png` | 2,263 | 158,326,016 | 2,253 contain JPEG signatures; preserve source identity and normalize only through derived-asset receipts. |
| `.md` | 1,340 | 35,033,153 | Part manifests, canonical chapters, source Lesson slices, and three supplemental files. |
| `.ts` | 927 | 6,465,007 | Existing find, summary, enrichment, quiz, contributor, and six anomalously named modules. |
| `.jpg` | 20 | 20,597,991 | JPEG signatures confirmed. |
| `.svg` | 8 | 994,414 | Vector media; dimensions resolve from width/height or viewBox. |
| `.webp` | 2 | 612,312 | WebP signatures confirmed. |

### File roles

| Role | Count | Treatment |
|---|---:|---|
| Canonical chapter Markdown | 1,138 | Primary semantic segmentation source. |
| Chapter media | 2,231 | Preserve chapter scope; never flatten generic basenames. |
| Explicit source Lesson Markdown | 179 | Derived/source slices; may overlap canonical chapter text. |
| Lesson find / summary / enrichment / quiz modules | 184 each | Existing Persian-oriented derived artifacts; audit claims and interaction atoms independently. |
| Lesson contributor modules | 185 | Provenance metadata input, not medical authority. |
| Lesson media | 61 | Preserve explicit source Lesson scope. |
| Part manifests | 20 | Structural indexes only, not educational content. |
| Anomalously named Lesson modules | 6 | Retain and reconcile explicitly. |
| Supplemental chapter / Lesson Markdown | 2 / 1 | Independent provenance artifacts; cannot be silently ignored. |
| Misplaced Lesson media | 1 | Preserve at current path and map to its matching Lesson anchor. |

## The source hierarchy is not the product hierarchy

The product ladder is frozen as:

`Course > Chapter > Learning Path > Unit > Concept Cluster > Micro-lesson > Session > Step/Interaction`

The source ladder is only:

`Part directory > Chapter directory > optional Lesson directory > files/media`

Mapping rules:

1. One `Part_NN_*` directory becomes one canonical Course.
2. One `Chapter_NNN_*` directory becomes one canonical Chapter.
3. A `Lesson_NNN_*` directory is a provenance anchor, never an automatic
   in-app lesson boundary.
4. A source Lesson may fan out to zero, one, or many concept clusters and
   micro-lessons after semantic segmentation.
5. The 1,065 chapters without source Lesson directories still require complete
   decomposition from the canonical chapter plus every supplemental artifact.
6. Title translation cannot change identity or order.

Deterministic source IDs use `source.part.NN`,
`source.part.NN.chapter.NNN`, and
`source.part.NN.chapter.NNN.source-lesson.NNN`. Destination IDs use the
course/chapter/path/unit/cluster/micro/session/step grammar embedded in the JSON
contract. File IDs are the first 24 hex characters of SHA-256 over the
NFC-normalized relative path; content identity remains a full SHA-256.

## Short-session decomposition model

The inventory deliberately estimates workload without pretending the
curriculum has already been authored. It targets 1–3 minute micro-lessons,
2–5 minute sessions, 5–9 interactions per session, and one or two new concepts
per micro-lesson. Long passive reading is not an allowed destination shape.

For each canonical chapter, the estimator combines heading structure and
source-word density:

- concept-cluster minimum = maximum of one, H4–H6 heading count, or one cluster
  per 650 words;
- concept-cluster maximum = at least one cluster per 320 words;
- micro-lesson range = at least one per cluster and roughly one per 240–120
  source words;
- units group approximately three to six concept clusters;
- one planning session is reserved per micro-lesson, with five to nine
  interaction steps.

This produces a whole-corpus planning range of 1,795–4,910 units,
7,254–13,416 concept clusters, 17,639–34,631 micro-lessons/sessions, and
88,195–311,679 interaction steps. These are capacity estimates, not final
medical or pedagogical decisions. Semantic authoring may split a range further,
but it may not merge away source fragments without a reviewed disposition.

## Cardiology-first baseline

`Part_06_Disorders_Cardiovascular_System` is the exact Cardiology course source
and production rank 1.

| Cardiology measure | Value |
|---|---:|
| Chapters | 61 |
| Chapters with / without explicit source Lesson anchors | 27 / 34 |
| Explicit source Lesson anchors | 69 |
| Structurally complete source Lesson anchors | 66 |
| Files | 865 |
| Bytes | 45,105,748 |
| Canonical chapter words | 336,909 |
| Estimated units | 119–383 |
| Estimated concept clusters | 566–1,085 |
| Estimated short micro-lessons/sessions | 1,436–2,838 |
| Estimated interaction steps | 7,180–25,542 |

Cardiology already contains useful explicit anchors around the examination,
ECG, imaging, catheterization, electrophysiology, arrhythmias, heart failure,
cardiomyopathy, and myocarditis. It also contains 34 unsegmented chapters,
including much of the valvular, congenital, pericardial, ischemic, acute
coronary, hypertension, aortic, peripheral vascular, venous, and pulmonary
hypertension surface. Existing source Lesson boundaries therefore cannot be the
only sharding strategy.

Three Cardiology source Lesson anchors are structurally incomplete:

- Chapter 018 / Lesson 003 lacks its Markdown source slice.
- Chapter 023 / Lesson 001 uses five bare names such as `_find.ts` and lacks
  the expected prefixed files and Markdown source slice.
- Chapter 027 / Lesson 001 has Markdown and contributors only; find, summary,
  enrichment, and quiz modules are absent.

Chapter 015 also stores `images_Lesson_003_Cardiomyopathies_and_VF` at the
chapter root. It is inventoried as misplaced Lesson media and must be mapped,
not moved or discarded during extraction.

## Production priority map

This is a product sequencing proposal, not a clinical-triage claim. Structural
readiness is measured separately so a later clinical domain can still serve as
a pipeline-validation corpus.

| Rank | Wave | Part | Chapters | Canonical words | Source Lesson anchors | Reason |
|---:|---|---|---:|---:|---:|---|
| 1 | Cardiology | 06 Cardiovascular | 61 | 336,909 | 69 | User-mandated first, broad and clinically central. |
| 2 | Acute core | 02 Cardinal manifestations | 87 | 392,906 | 0 | Cross-system presentation and differential prerequisites. |
| 3 | Acute core | 08 Critical care | 39 | 63,618 | 0 | Time-critical resident workflows and case practice. |
| 4 | Acute core | 07 Respiratory | 18 | 93,892 | 0 | Tight coupling to Cardiology and Critical Care. |
| 5 | Acute core | 09 Kidney/urinary tract | 86 | 107,126 | 0 | Renal, electrolyte, acid-base, and cardiorenal foundations. |
| 6 | Major systems | 05 Infectious diseases | 225 | 949,415 | 0 | Largest broad clinical/differential surface. |
| 7 | Major systems | 13 Neurology | 68 | 330,145 | 0 | High-value emergencies and localization. |
| 8 | Major systems | 12 Endocrinology/metabolism | 82 | 412,730 | 0 | Recurrent metabolic prerequisites. |
| 9 | Major systems | 10 Gastrointestinal | 143 | 319,748 | 0 | Large common inpatient/outpatient domain. |
| 10 | Major systems | 03 Pharmacology | 4 | 13,865 | 0 | Best taught contextually after foundational pathways. |
| 11 | Complex specialties | 04 Oncology/hematology | 183 | 472,443 | 0 | Large, complex, safety- and freshness-sensitive. |
| 12 | Complex specialties | 11 Immune/rheumatology | 46 | 187,911 | 117 | Highest structural readiness (95.62); strong second pipeline-validation source. |
| 13 | Complex specialties | 14 Poisoning/overdose | 9 | 39,221 | 0 | Urgent, compact, and freshness-sensitive. |
| 14–20 | Cross-cutting/maintained | 01, 19, 16, 15, 18, 17, 20 | 87 | 368,544 | 0 | Professional, consultative, genetics, exposure, aging, global, and volatile emerging-topic lenses. |

The exact rank, rationale, counts, readiness score, and wave for all 20 Parts
are available in `priorityMap` in the JSON inventory.

## Coverage and no-silent-drop contract

The snapshot reconciles 4,560 OS-enumerated files to 4,560 manifest records,
4,560 unique relative paths, 4,560 unique file IDs, and the same 222,028,893
bytes. There are zero file-ID or normalized/case path collisions. Every file
has exactly one role, including structurally anomalous files.

Promotion of a generated curriculum pack must fail unless every source file and
every extracted heading, paragraph, list, table row, figure, media item, quiz
item, and code/content block has exactly one reviewed disposition:

- `mapped` to destination IDs;
- `duplicate_alias_with_target` with an explicit canonical source target;
- `intentionally_excluded_with_reason`; or
- `blocked_with_owner`.

Each receipt must bind source file SHA-256, fragment locator, transformation
version, aligned EN/FA destination IDs, and review state. A missing file ID,
unmapped fragment, or changed source hash fails promotion. Exact byte duplicates
remain separate provenance records until an alias receipt exists.

## Structural and media anomalies

- 10 explicit source Lesson directories have an expected-component mismatch;
  the JSON records each missing and extra filename.
- 3 canonical chapter Markdown files are zero bytes: Oncology chapter 081 and
  Infectious Diseases chapters 105 and 162. They are blocked sources, not empty
  lessons.
- 2,253 files named `.png` have JPEG signatures. Only 40 of the 2,293 media
  files match their declared extension; dimensions resolve for all 2,293 from
  their detected format.
- 30 files have absolute Windows paths of at least 260 characters; the maximum
  is 304. Long-path-aware enumeration and task packing are mandatory.
- 1,937 blank Markdown image targets coexist with populated image references;
  there are zero unresolved nonblank static media references.
- 39 media files have no parsed static reference. They may be dynamic,
  supplemental, or unused; none can be deleted without an explicit disposition.
- 74 exact-content duplicate groups cover 266 files and 4,013,388 redundant
  bytes. Hash equality permits payload reuse only after provenance aliasing.

## Data-boundary and safety gates

1. **Rights clearance is required before external processing.** The user
   classifies the corpus as self-created/simulated, while observed content also
   contains textbook-like chapter numbering, named authors, bibliographic prose,
   and 237 files with “reproduced with permission” language. The inventory does
   not establish ownership. Text and media rights must be confirmed before a
   Jules upload, public/private repository publication, model processing, or
   user distribution.
2. **Medical freshness is not established.** Source prose and derived
   TypeScript contain prevalence figures, treatments, clinical claims, quiz
   answers, and dates without a normalized claim/evidence/version ledger.
   Destination lessons remain educational drafts until current authoritative
   sources and medical review validate actionable claims and answer keys.
3. **Current English/Persian material is asymmetric.** Canonical chapter
   Markdown is predominantly English while many derived interactive modules are
   Persian. This is not proof of an aligned bilingual curriculum. Destination
   pairs need shared concept, claim, activity, and answer IDs with locale-specific
   pedagogy.
4. **Basenames are not identities.** Generic names such as `image_001.png`
   repeat across chapters. Preserve the scoped path and deterministic file ID.

## Reproducible verification

PowerShell source totals:

```powershell
$root = 'C:\Users\K1\Desktop\Harrison'
$files = Get-ChildItem -LiteralPath $root -Recurse -File -Force
$dirs = Get-ChildItem -LiteralPath $root -Recurse -Directory -Force
"files=$($files.Count) dirs=$($dirs.Count) bytes=$(($files | Measure-Object Length -Sum).Sum)"
```

Parse and conservation checks:

```powershell
$path = 'C:\Users\K1\Desktop\Projects\Synapse\contracts\curriculum\source-inventory.v1.json'
$inventory = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -Depth 100
$inventory.coverageProof | Format-List
Get-FileHash -LiteralPath $path -Algorithm SHA256
```

Expected conservation proof:

- `osEnumeratedFileCount = manifestRecordCount = uniqueRelativePathCount = uniqueFileIdCount = 4560`
- `enumeratedByteSum = manifestByteSum = 222028893`
- `allFilesAccounted = true`
- `allBytesAccounted = true`
- `unassignedRoleCount = 0`
- `fileIdCollisions = []`
- `normalizedCasePathCollisions = []`

## Next controlled action

Build task packs from the Cardiology chapter anchors, but do not submit them to
Jules until the rights boundary is explicitly cleared. The first local pack
should prove fragment extraction, deterministic IDs, EN/FA alignment, media
signature normalization, evidence status, and 100% coverage receipts on a small
Cardiology slice before scaling to 15 concurrent tasks.
