# Content authoring policy and Cardiology Jules plan

**Status:** local preparation verified; external processing blocked  
**Owner:** dedicated Content Lead  
**Updated:** 2026-07-17  
**Application boundary:** no Flutter, domain-runtime, Data Plane, or publication-authority file is owned by this stream

## Outcome

The content stream now has a deterministic, non-executing source atomizer, a schema-validated EN/FA authoring policy, three project prompt templates, and a raw-text-free 15-lane Cardiology execution plan. These artifacts prepare Jules work without calling Jules, exposing source text, uploading the corpus, mutating a remote revision, or publishing content.

No lesson body has been generated or approved. External processing remains blocked until the corpus rights and exact remote-revision gates are explicitly cleared.

## Binding authoring boundary

Only these production capabilities are allowed:

1. `lesson_writing`
2. `embedded_quiz_writing`
3. `bounded_reinforcement_summary`

The policy explicitly forbids a Specialist/Enrich stage, standalone bulk quiz generation, standalone summaries as primary coverage, fixed quiz counts, and expansion for its own sake. Legacy `*_enrich.ts`, `*_find.ts`, `*_quiz.ts`, and `*_summary.ts` sidecars are untrusted source candidates; their filenames do not grant authority or define the production workflow.

English and Persian are authored together as atomic semantic pairs. Persian must be idiomatic and professionally friendly rather than literal. Each locale remains independently reviewable and publishable. The default session budget is 3–6 minutes, with a hard maximum of 8 minutes and 12 interactions; 1–3 new concepts is the target, four is the maximum, and interaction families must vary.

Primary policy artifacts:

- `contracts/curriculum/authoring-policy.v1.json`
- `contracts/curriculum/authoring-policy.schema.v1.json`
- `contracts/curriculum/content-task-plan.schema.v1.json`
- `tool/jules/prompts/atom_review_and_decomposition.md`
- `tool/jules/prompts/integrated_bilingual_authoring.md`
- `tool/jules/prompts/independent_content_validation.md`

## StudyHub prompt distillation

The reusable parts are:

- read every assigned source artifact before writing;
- maintain a complete atom-coverage ledger;
- explain why and how, and define a term at first meaningful use;
- use vignettes and media only when they improve the learning objective;
- explain both why the selected response is correct and why each distractor is wrong;
- reject placeholders and validate semantically beyond JSON shape;
- write native Persian rather than mechanically translated Persian.

The rejected legacy constraints are:

- fixed expansion quotas per source sentence;
- fixed 15–30 question batches;
- separate find/enrich/summary/quiz production stages;
- mandatory vignettes, names, slang, emojis, or narrator phrases;
- legacy TypeScript, CSS, folder, schema, and brand assumptions;
- treating the local corpus as current clinical authority.

## Source atomization receipt

The Cardiology scope is Part 06: 61 chapters, 69 source-Lesson provenance anchors, 865 files, and 45,105,748 bytes. Source Lesson folders remain segmentation/provenance anchors rather than learner-visible lesson boundaries.

Atomizer `synapse-static-source-atomizer` v1.1.1 produced:

| Measure | Result |
|---|---:|
| Total source atoms | 64,816 |
| Required | 23,290 |
| Duplicate-required | 9,573 |
| Non-instructional | 31,953 |
| Text/TypeScript documents | 130 / 341 |
| Media documents | 394 |
| Quarantined documents | 0 |
| TypeScript static-parse failures | 0 |
| Unresolved dynamic-expression findings | 0 |
| Unresolved template-interpolation findings | 0 |
| Statically linked `${IMAGES_BASE}` template documents | 43 |
| Contributor-only sidecars with no instructional literal | 69 |
| Claimed-extension/MIME mismatches retained for review | 371 |

Every TypeScript sidecar is treated as inert text. The scanner never imports, evaluates, transpiles, invokes, or shells out to it. A false-positive defect that interpreted medical prose such as “ventricular function” as executable `function` syntax was fixed by classifying only structural tokens. All 96 `${IMAGES_BASE}` uses across 43 documents resolve to quoted local `const` bindings and are recorded as static template references; complex or unresolved interpolation would remain a blocking semantic-review finding.

The source tree SHA-256 is `da2cd7eaebf1349bcbfdf4c44b5d56a094bc7bf2f114191b4f204111f38e3064`. The deterministic v1.1.1 scan manifest SHA-256 is `f4e61ebf12956eb03d3ab8bd2c0618e30a27d7a3a313892fd48f72356e6a060a`.

The full scan is intentionally not copied into the repository. It contains no raw source text, but it is an 82 MB local receipt and remains reproducible from the local corpus. The checked local receipt is:

`C:\Users\K1\AppData\Local\Temp\synapse-course-06-source-scan.v1.1.1.json`

## Raw-text-free Cardiology task plan

The local planner uses deterministic whole-chapter LPT balancing across the maximum 15 concurrent lanes. The planning weight accounts for atom volume, media, clinical-high material, warnings, and safety-critical atoms. It reconciles every course-level artifact, chapter, document, and atom without overlap.

| Measure | Result |
|---|---:|
| Lanes | 15 |
| Chapters / documents / atoms | 61 / 865 / 64,816 |
| Minimum / maximum lane weight | 5,729 / 6,839 |
| Pilot | Chapter 006 and Chapter 054 |
| Plan ID | `content-plan.course-06.da2cd7eaebf1.f4e61ebf1295.6707049c1884` |
| Plan SHA-256 | `8422c49b01285d3873d22afed5c2744f65c100d9ddc639f689ec4852ccdd37d0` |
| Execution state | `blocked_external_processing` |
| Raw source text included | no |
| Jules manifest emitted | no |
| Remote mutation allowed | no |

Chapter 006 exercises explicit segmentation plus image/signal interpretation. Chapter 054 exercises unsegmented mechanism, management, and safety material. Selection is planning evidence only, not permission to submit either chapter.

The `planId` includes the source-tree hash, exact source-scan receipt hash, and authoring-policy hash. This prevents two atomizer revisions over the same source tree from colliding under one task-plan identity.

The checked local plan is:

`C:\Users\K1\AppData\Local\Temp\synapse-course-06-content-task-plan.v1.1.1.json`

## Activation gates

All external work remains blocked until the exact run has evidence for:

1. text and media rights clearance;
2. exact private remote repository, branch, and commit visibility;
3. proof that every task input exists in that revision;
4. review of the rendered task prompts and ownership;
5. secret, privacy, and PHI scanning;
6. Jules authentication and read-only doctor checks;
7. quota and 15-lane concurrency allocation;
8. named independent medical reviewers;
9. named native Persian reviewers independent from generation;
10. author/reviewer/publisher separation;
11. output destination and quarantine handling;
12. explicit no-auto-PR/no-auto-merge behavior;
13. rollback, cancellation, and artifact-harvest receipts.

Until then, the project may continue local scan, planning, fixture, schema, and prompt-policy work only.

## Reproduction and verification

```powershell
python -m unittest tool.curriculum.test_source_scan -v
python -m unittest tool.jules.test_content_task_plan -v

python -m tool.curriculum.source_scan `
  --source-root 'C:\Users\K1\Desktop\Harrison' `
  --course 06 `
  --check 'C:\Users\K1\AppData\Local\Temp\synapse-course-06-source-scan.v1.1.1.json' `
  --json-summary

python -m tool.jules.content_task_plan `
  --source-scan 'C:\Users\K1\AppData\Local\Temp\synapse-course-06-source-scan.v1.1.1.json' `
  --shards 15 `
  --pilot-chapters 006,054 `
  --check 'C:\Users\K1\AppData\Local\Temp\synapse-course-06-content-task-plan.v1.1.1.json' `
  --json-summary
```

Current result: six source-scan tests and six content-plan tests pass; both real artifacts regenerate byte-for-byte; both Draft 2020-12 schemas validate.

## Next content action

After rights and exact-revision clearance, render the exact pilot prompts, run the atom-review/decomposition phase for Chapters 006 and 054, independently validate its coverage ledger, and only then begin paired EN/FA micro-lesson authoring. Generated medical copy remains quarantined until independent medical, safety, Persian, parity, coverage, and package-integrity review passes.
