# Unified Capability Naming

## Decision

Synapse is one product, one brand, and one information architecture. The
legacy source repository (technical identifier: `StudyHUB-Flutter`) contributes
capabilities and migration data only. Its name must never become a destination,
module, workspace, feature family, widget title, notification channel,
accessibility label, search category, localization key namespace, or analytics
namespace.

Names answer **what the clinician or learner is doing now**. They do not expose
which repository originally implemented the behavior.

## Stable Product Vocabulary

| Capability family | Synapse owner | Visible or contextual names | Placement rule |
|---|---|---|---|
| Curriculum and enrollment | Academy | Path, My Courses, Lesson, Lesson Versions | Course hierarchy lives in Path; it is never a nested imported app. |
| Documents and source intake | Library | Sources, My Sources, Add a Source, Reader | Open globally from Library or contextually from Course, Chapter, Unit, Micro-lesson, Concept, and Case. |
| Reading assistance | Learning Workspace | Find in Source, Overview, Expand, Listen | Actions remain inside Reader or Lesson state; they do not each claim a page. |
| Personal knowledge work | Learning Workspace | Margin Workspace, Notes, Annotations, Saved Places, Links & Tags | Margin opens beside the current object and preserves scroll, selection, and session state. |
| Concept relationships | Mastery | Concept Map | A synchronized view of the current concept graph, with an outline equivalent. |
| Planning and focus | Today | Today, Plan, Focus Session | Today owns prescription and workload; focus is a bounded mode, not a parallel planner. |
| Recall and practice | Review | Review, Practice, Create Practice | Due work enters through Today/Review; generated items remain drafts until governed. |
| AI assistance and background work | Copilot Platform | Copilot, Copilot Thread, Background Tasks | Copilot is scoped to the current lesson/source/concept/case; jobs are observable support, not a destination brand. |
| Progress and imported rewards | Progress & Rewards | Progress, Achievements, Imported Reward History | Historical imports reconcile once; the current reward ledger remains authoritative. |
| Device and account controls | You | Learning Preferences, Privacy & Security, App Lock | Existing Synapse settings own the behavior; no second settings system survives. |
| Notifications and glance surfaces | Today | Notifications, Synapse Today widget | Every item deep-links to its functional owner and uses the unified notification registry. |

The exhaustive 32-capability mapping is machine-readable in
`contracts/integrity/product-language-policy.v1.json`. Each record freezes the
technical source ID, canonical domain, surface, user-facing label, entry
context, exposure class, and a `synapse.*` analytics namespace.

## Placement Grammar

1. **Object before tool.** A learner opens a Course, Chapter, Unit, Micro-lesson, Concept,
   Case, or Source first; relevant tools appear in that context.
2. **One authoritative owner.** Notes do not become a Notes mini-app, planning
   does not become a planner mini-app, and review does not keep a second SRS
   identity.
3. **Pages are earned by workflows.** A capability receives a full page only
   when it has a durable browse/manage task; quick actions, transformations,
   and modes stay in a sheet, pane, command, or current workflow.
4. **Compact and expanded are the same feature.** Margin Workspace becomes a
   sheet on phone and a resizable pane on larger screens without changing its
   name or authority.
5. **Study and Clinical lenses change presentation, not identity.** Clinical
   surfaces reduce reward theater and increase provenance, but they do not
   rename or duplicate the underlying source, note, or concept.

## Technical Provenance Boundary

The old source identifier may remain only in:

- preservation ledgers and rollback manifests;
- schema-v2–17 fixtures and importer tests;
- read-only migration adapters and reconciliation receipts;
- historical work documentation that records where a contract came from.

Compatibility IDs may be aliased behind those boundaries. They cannot be
exported to UI strings, ARB catalogs, semantics/accessibility nodes, native
metadata, notifications, widgets, search facets, URLs intended for users, or
telemetry. New code uses the canonical domain and `synapse.*` event namespace.

## Executable Gate

`dart run melos run integrity` performs two independent checks:

1. scans all committable Flutter/package/native product sources, including
   untracked files, for compact or separated variants of the retired source
   brand; and
2. joins the capability naming contract to the preservation ledger so every
   source capability is mapped exactly once and no mapped product term uses a
   source brand or vague standalone `Hub` label.

There is no broad product-source exclusion. A migration-only literal requires
an exact match-hash allowlist record with a reason, owner, and expiry; stale,
approximate, and expired exceptions fail.

## Acceptance Gate

- Product-source scan reports zero legacy-brand findings.
- All 32 legacy capability identities have exactly one canonical mapping.
- Every analytics namespace begins with `synapse.`.
- The app has no source-branded route, branch, page, pane, dialog, menu,
  notification, widget, accessibility label, or localized string.
- Representative flows prove the capabilities are discoverable through Today,
  Path, Lesson, Review, Library, Margin Workspace, Copilot, and You without a
  sixth product authority.
