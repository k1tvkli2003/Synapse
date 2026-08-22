# Governance Critique — WBS-020

- Date: 2026-07-15
- Scope: requirements, preservation, research, product, curriculum, brand, architecture, risk, WBS, evidence, rollback, and work-docs controls
- Method: adversarial completeness review against the canonical objective, 51 requirements, 16 Critics findings, 35 risks, 18 ADRs, and 440 dependency-ordered steps
- Result: passed after corrections

## Findings and Closure

| Severity | Finding | Closure |
|---|---|---|
| P0 | No explicit cross-domain stop/rollback policy initially connected data loss, authorization, rewards, PHI, and clinical claims. | Added the P0 stop/rollback matrix in `17-governance-gates.md`. |
| P1 | Evidence artifacts had locations but no deterministic naming/provenance/redaction rule. | Added naming, storage, companion-metadata, immutability, and redaction rules. |
| P1 | Architecture decisions were summarized without a reusable full-field record template or index. | Added the ADR template and accepted-decision index to `15-architecture-decisions.md`. |
| P1 | Phase readiness and completion could be interpreted as “code exists” or “build passed.” | Added explicit Definition of Ready and Definition of Done covering runtime, contracts, localization, accessibility, security, performance, and rollback. |
| P1 | Preview and handoff documents still contained scaffold markers, making the durable package fail validation. | Replaced them with truthful queued-preview and active-handoff content; production proof remains explicitly partial. |
| P2 | The state/progress files described planning documents as unfinished after they existed. | Updated state, progress, verification, and remaining work to current reality. |

## Adversarial Questions

- Can the rebuild delete an inconvenient old capability? No; the removal gate requires replacement, migration, adapter, evidence, rollback, and an ADR.
- Can a heading become a rewarded Lesson automatically? No; ADR-006 and importer constraints keep candidates non-public and nonrewarding.
- Can StudyHUB run as a second sync/planner/SRS authority? No; ADR-009 and the absorption matrix make it a read-only legacy source.
- Can successful compilation close a phase? No; runtime, state, locale, accessibility, performance, security, and contract evidence are required where applicable.
- Can a clinical or PHI P0 ship as a limitation? No; the stop matrix requires containment and verified recovery.
- Can work proceed without user approval pauses? Yes for ordinary in-scope decisions; irreversible/external authority boundaries remain governed by the objective and safety rules.

## Exit

No unresolved P0 or P1 governance-planning finding remains. Product, platform, content, security, and implementation risks continue as explicitly owned work and cannot be treated as closed by this critique.
