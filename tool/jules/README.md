# Project content planning for Jules

This directory owns project-specific content task planning. The global
`C:/Users/K1/.codex/skills/jules` skill owns Jules platform operation; it does
not own Synapse pedagogy, source coverage, bilingual semantics, or publication.

`content_task_plan.py` creates a deterministic, raw-text-free, whole-chapter
15-lane plan from a course-scoped source scan. It never calls Jules, emits a
Jules batch manifest, uploads corpus data, changes Git, or enables an automatic
pull request. Its output stays `blocked_external_processing` until every rights
and exact-remote-revision gate is cleared separately.

## Cardiology plan

```powershell
$scan = Join-Path $env:TEMP 'synapse-course-06-source-scan.json'
$plan = Join-Path $env:TEMP 'synapse-course-06-content-task-plan.json'

python -m tool.jules.content_task_plan `
  --source-scan $scan `
  --shards 15 `
  --pilot-chapters 006,054 `
  --output $plan `
  --json-summary

python -m tool.jules.content_task_plan `
  --source-scan $scan `
  --shards 15 `
  --pilot-chapters 006,054 `
  --check $plan `
  --json-summary
```

The pilot intentionally combines Chapter 006 (explicitly segmented,
media/signal-heavy imaging) with Chapter 054 (unsegmented, mechanism and
management-heavy hypertension). The pilot is only a planning selection until
rights, exact connected source/branch/commit, input visibility, prompt review,
secret/PHI scan, quota, and reviewer-separation evidence pass.

## Validation

```powershell
python -m unittest tool.jules.test_content_task_plan -v
```

The three prompt templates are project policy artifacts. Activation must render
them into exact task-owned prompts only after the external-processing gates are
explicitly cleared. Integrated authoring always contains lesson writing,
embedded quiz writing, and optional bounded recap in one session-pair task;
there is no specialist or Enrich task family.

