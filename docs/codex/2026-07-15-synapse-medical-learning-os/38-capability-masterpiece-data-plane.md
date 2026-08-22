# Capability Masterpiece and Shared Data Plane

**Status:** contract and conservative baseline verified; one curriculum-package capability is active and no capability is verified  
**Authority:** `37-goal-charter-v2.md`  
**Coverage:** 76/76 preserved Synapse/absorbed StudyHUB records plus 3 registered Academy capabilities (79 current records)

## Outcome

The user's requirement that every option and section become a masterpiece is now executable rather than rhetorical. The preservation ledger still answers **what must not be lost**. The new completion ledger answers **what must be designed, implemented, and proven before any capability may be called complete**.

The generator currently reports:

- 79 expected records: 76 preserved plus 3 registered new capabilities;
- 78 planned records and 1 active curriculum-package record;
- zero verified records;
- 14 mandatory masterpiece gates per record;
- all 15 shared Data Plane concerns per record;
- explicit functional domain, surface, label, entry context, exposure class, page decision, canonical entity families, truth authority, state matrix, EN/FA/RTL, input, viewport, and motion requirements.

This is a portfolio-truth and anti-false-completion milestone. It is not evidence that the 79 capabilities are implemented.

## Artifacts

| Artifact | Role |
|---|---|
| `contracts/preservation/capability-ledger.v1.json` | Generated no-loss source authority. |
| `contracts/product/new-capability-registry.v1.json` | Reviewed authority for additive capabilities that are not part of the frozen preservation baseline. |
| `contracts/integrity/product-language-policy.v1.json` | Functional Synapse naming/placement for all 32 absorbed StudyHUB identities. |
| `contracts/product/data-plane.v1.json` | Fifteen cross-cutting data concerns and eleven domain profiles. |
| `contracts/product/capability-evidence.v1.json` | Reviewed hand-authored status/evidence overlay; generation never erases it. |
| `contracts/product/capability-completion.v1.json` | Generated union of the 76-record preservation baseline and the new-capability registry. |
| `contracts/product/capability-completion-verification.v1.json` | Current semantic verification receipt. |
| `tool/product/generate_capability_completion.py` | Exact coverage join and deterministic generator. |
| `tool/product/verify_capability_completion.py` | Semantic verifier and false-done prevention. |
| `tool/product/test_capability_completion.py` | Seven positive/adversarial tests. |

## Four-layer capability record

Each record keeps four concerns separate so none can impersonate another:

1. **Provenance and baseline:** source owner/document/row, current state, current routes, and no-loss rule.
2. **Product placement:** functional domain, surface, label, context, analytics namespace, exposure, capability intent, placement intent, and whether a standalone page is genuinely earned.
3. **Data Plane:** one primary profile, canonical entity families, truth authority, entity-schema status, and all 15 concern states.
4. **Delivery:** required UX states, locale/direction/input/viewport/motion parity, risk flags, verification owner, completion status, and 14 gates with evidence.

## Exposure and no-page-sprawl model

Allowed exposure classes are:

- `primary_destination`: a broad recurring job that owns a shell branch;
- `dedicated_workflow`: a sustained multi-step job with independent state and deep-link value;
- `embedded_section`: visible inside an existing destination but not a new top-level page;
- `contextual_surface`: inline, inspector, sheet, side pane, overlay, or action beside its owning object;
- `background_service`: observable through status/job/recovery surfaces only;
- `system_surface`: shell, onboarding, notification, widget, permission, command, or OS settings;
- `migration_only`: preservation/reconciliation with a receipt and no learner-facing destination.

Only `primary_destination` and `dedicated_workflow` may set `standalonePageEarned=true`. The verifier rejects every other combination.

## Fourteen masterpiece gates

1. Purpose and measurable outcome.
2. Earned placement and no-page-sprawl proof.
3. Complete workflow and recovery.
4. Intentional Night Shift visual craft.
5. Complete applicable state matrix.
6. Responsive and input parity.
7. EN/FA/RTL and long-string parity.
8. Accessibility parity.
9. Full/Reduced/Off motion and feedback parity.
10. Shared Data Plane implementation.
11. Security and privacy.
12. Performance budgets and profiler evidence.
13. Contract/runtime/platform verification.
14. Adversarial product-quality critique.

`verified` requires every gate to be `verified` or a reviewed `not_applicable`. A verified gate requires evidence. `not_applicable` requires both evidence and rationale. A capability cannot become `verified` while any gate, Data Plane concern, or entity schema remains planned, active, or blocked.

## Fifteen Data Plane concerns

The shared contract requires stable identity, schema/migration, provenance, validation, persistence, indexing/search, cache, offline queue, synchronization, conflict resolution, privacy/consent, security/authority, audit/history, backup/recovery, and observability.

The eleven profiles avoid pretending that one storage/sync pattern fits every domain:

- curriculum and learning;
- workspace and personal knowledge;
- planning and lifecycle;
- rewards and progress;
- clinical evidence;
- AI jobs;
- social collaboration;
- identity and governance;
- platform/system transport;
- commerce and entitlement;
- content pipeline.

Each profile freezes entity families, truth authority, offline behavior, conflict policy, privacy class, search policy, and recovery policy. Individual capabilities will replace `entitySchemaStatus=planned` only after concrete schemas, repositories, migrations, fixtures, and evidence exist.

## Conservative status rules

- Base generation is not implementation and starts with zero `verified`; only the reviewed evidence overlay can advance status, and the semantic verifier still blocks unsupported completion.
- Baseline `operational` means an old capability existed; it does not satisfy the new product gate.
- A passing unit test does not satisfy visual, runtime, platform, or release truth.
- A screenshot does not satisfy data integrity, migration, accessibility, performance, or security.
- A feature cannot be retired because it is inconvenient. `retired_authorized` requires explicit user authorization evidence.
- Legacy StudyHUB IDs remain only in provenance/migration keys. Product fields are scanned for source-brand leakage.

## Verification

Run:

```powershell
dart run melos run capabilities
```

Current result:

- generator parity: pass;
- seven tests: pass;
- semantic verifier: pass;
- records: 79;
- planned: 76;
- active: 3 (`synapse.academy.curriculum-packages`, `synapse.academy.curriculum-path`, `synapse.academy.learning-session`);
- verified: 0;
- issues: 0.

The adversarial tests prove rejection of a missing capability, missing gate, evidence-free `verified`, missing Data Plane concern, legacy-brand leakage, unearned standalone page, and unexplained `not_applicable` gate.

## Next implementation use

1. Keep the three exercised Academy capabilities `active` while closing their remaining real-content, scale, state, accessibility, motion, performance, Data Plane, and platform gates; do not promote them to `verified` from the synthetic slice.
2. Replace profile-level entity families with concrete schemas and repository contracts as each capability becomes implementation-ready; ADR-022 and `39-academy-session-progress-data-plane.md` are the first learner-progress specialization.
3. Store evidence links in the gate record rather than in prose-only progress notes.
4. Generate a compact completion dashboard from the ledger; never maintain a second hand-edited status source.
5. Keep `synapse-masterpiece-gate` and `synapse-capability-closure` synchronized with the preservation-plus-new registry model and validate them after every change.
