# Synapse integrated bilingual session authoring

## Outcome

Author only the assigned approved session-pair IDs as one integrated learning
experience. The only authoring capabilities in this task are:

1. lesson writing;
2. embedded quiz writing;
3. bounded reinforcement summary.

There is no specialist-writing stage, no Enrich stage, no standalone quiz dump,
and no standalone summary pipeline.

## Binding inputs

The activated task must provide immutable repository-relative paths and hashes
for the approved decomposition, locale-neutral semantic skeleton, source atoms,
claims, evidence candidates, terminology, media, `content-contract.v1.json`,
`authoring-policy.v1.json`, and the task-owned output IDs.

Stop with a structured blocking finding when source, evidence, rights, safety,
or schema inputs are missing. Never fill a gap with model memory or an invented
citation.

## Lesson writing

- Author English and Persian together from one locale-neutral skeleton.
- Keep semantic IDs, claims, source atoms, concepts, numbers, comparators,
  units, evidence, safety flags, interaction intent, option IDs, answer IDs,
  scoring, and mastery target identical across locales.
- Write clear international medical English.
- Write natural modern Persian with Persian `ی` and `ک`, correct half-spaces,
  professional warmth, and proper LTR isolation for medical terms, drug names,
  ECG leads, formulas, numbers, and units.
- Explain terminology at first meaningful use. Preserve why/how reasoning and
  causal links without inflating a sentence to an arbitrary length.
- Use a synthetic vignette or media task only when it adds real mechanism,
  discrimination, interpretation, diagnosis, or transfer value. Demographics
  must be relevant to the teaching point.
- Split rather than exceed any session budget: 3–6 minutes target and 8 minutes
  hard maximum per locale; 5–9 interactions target and 12 maximum; 1–3 new
  concepts target and 4 maximum; 9 independent claims maximum; at least three
  interaction families; at least 45% active steps; no more than two passive or
  same-template steps consecutively; learner action at least every 90 seconds.

## Embedded quiz writing

- Distribute retrieval, discrimination, application, repair, calibration, and
  checkpoint interactions through the lesson. Do not create a fixed question
  count or a separate quiz file.
- Assess taught claim IDs unless an item is explicitly diagnostic-only and
  non-punitive.
- Use selected response only when answer choices provide useful discrimination;
  otherwise prefer short answer, cloze, matching, sequence, causal construction,
  compare/contrast, image or ECG interpretation, branching choice, or teach-back.
- When selected response is justified, use four or five stable option IDs and a
  correct answer ID rather than a locale-dependent index.
- Store complete why-correct reasoning and a specific why-wrong explanation plus
  misconception or plausible-error rationale for every distractor.
- Reject placeholders, tricks, trivia, unsupported facts, answer-length cues,
  and verbatim retry items.

## Bounded reinforcement summary

- A recap is optional reinforcement inside the session or debrief, never an
  independent production phase.
- Keep it to 30–60 seconds per locale and never beyond 75 seconds.
- Use at most four takeaways and at least one retrieval prompt.
- Reinforce only already-taught claims. Introduce no new claim, citation,
  warning, dose, threshold, or management recommendation.
- A recap may not carry primary source-atom coverage.

## Forbidden actions

- Do not change decomposition, shared registries, another task's IDs,
  application code, branches, commits, pull requests, or publication channels.
- Do not execute source TypeScript or trust a derived sidecar as medical
  authority.
- Do not use legacy product names, narrator personas, CSS markup, TypeScript
  output shapes, forced emojis, forced slang, or mandatory reader address.
- Do not provide patient-specific guidance or self-approve generated content.

## Output and acceptance

Write only the assigned raw content-pack fragment. It must validate against the
Synapse content contract and include complete generator provenance, source and
claim links, EN/FA localization units, interactions, feedback, coverage edges,
duration estimates, accessibility data, and unresolved findings. Missing either
locale, any answer mismatch, unsupported claim, unverified citation, budget
violation, or placeholder blocks acceptance. The result remains `raw` and
unpublished.

