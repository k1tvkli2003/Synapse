# Academy Catalog Index and Cache

**Status:** implemented bounded in-memory derived index, local integrity boundary, and pinned Ed25519 verification path; production publisher-key/signing/distribution operations, real-catalog benchmark, on-disk search, and offline pack caches remain open  
**Date:** 2026-07-18  
**Scope:** immutable Academy curriculum manifests, EN/FA hierarchy search, rebuildable runtime indexes, and cache recovery  
**Authority boundary:** the immutable installed package remains truth; the index/cache is disposable and contains no learner state

## Outcome

The Academy runtime now builds one immutable query snapshot from a validated
curriculum manifest and treats every derived index as disposable acceleration.
Search and navigation can be rebuilt after eviction, memory pressure, or a
recovery action without deleting packages, activation receipts, session
progress, rewards, notes, or any other user-owned data.

This slice addresses the first local scale boundary without pretending that a
five-node synthetic fixture proves the future full catalog. It defines
deterministic behavior, budgets, concurrency, invalidation, and evidence that
can later be exercised against a rights-cleared real release.

## Derived indexes

`CurriculumCatalogSnapshot` precomputes and freezes:

- node-by-ID lookup;
- ordered parent→children lists;
- ancestor-ID sets for Course/Chapter-scoped search;
- normalized English, Persian, and source-key search documents;
- localization-unit lookup;
- Micro-lesson→Session and Session→Interaction playback indexes built only
  from each parent's explicit ordered ID queue.

Manifest validation now requires exact reciprocal ownership and ordinal parity:
every non-scaffold Micro-lesson node owns one body, every Micro-lesson declares
all and only its Sessions, and every Session declares all and only its
Interactions. Duplicate node ownership, wrong ancestry, reverse-linked extras,
and undeclared playback objects fail before a learner catalog can be built.

Normalization happens once per manifest build, not once per entry on every
query. Persian Arabic Yeh/Kaf variants, diacritics, ZWNJ, whitespace, and case
normalization remain deterministic. Search preserves the existing exact,
prefix, word-prefix, substring, cross-locale, and source-key ranking tiers and
adds an optional stable-node scope. Every result also records a truthful match
origin (`requestedLocale`, `fallbackLocale`, or `sourceKey`); source-key hits
do not pretend to have matched a locale. A missing scope fails explicitly as
`catalog_search_scope_missing`, including when the query is empty.

This is not yet transliteration, abbreviation, typo tolerance, stemming, or a
persistent full-text engine. Those remain separate multilingual/search work.

## Two-budget LRU cache

`PackageCurriculumCatalogRepository` uses a true least-recently-used cache with
two independent limits:

1. maximum cached releases (default 3);
2. maximum aggregate logical nodes (default 50,000).

A hit moves the release to most-recent position. A new snapshot evicts the
least-recent entries until both limits hold. A single snapshot larger than the
node budget is returned to the caller but never retained. The node limit is a
deterministic safety proxy, not a measured heap-byte claim; physical-device
memory profiling remains required before production tuning.

Concurrent `catalogForRelease` requests for the same immutable release share
one in-flight load/build. The package repository is still read and validates
the installed manifest before an index snapshot is accepted, so cache reuse
does not replace package integrity checks.

## Installed-package integrity and recovery

Bundled install requires two caller-supplied trust values: the SHA-256 of the
exact transport bytes and the canonical manifest SHA-256. These values belong
to the trusted application-artifact boundary and must not be derived from the
untrusted candidate inside the same call path. Remote/distributed install is a
separate API and requires a strict Ed25519 envelope that binds source, release,
channel, both hashes and byte lengths, signing time, algorithm/domain and a
pinned key ID. Unknown, revoked, out-of-scope, future and forged envelopes fail
closed and are quarantined without retaining the candidate body.

Stored bodies must equal canonical JSON byte for byte, and their record source,
release, channel, lifecycle, scaffold flag, canonical length, identity and hash
must agree with the decoded manifest. Trust kind and signed envelope provenance
are persisted. Signed records are re-audited after restart and cannot be
downgraded through bundled restore. Old pre-trust registries remain readable as
`legacyCallerHashes` but cannot become learner authority; a valid signed
reinstall of identical bundled bytes can upgrade trust metadata without
duplicating the content body.

An idempotent retry decodes and validates the installed body before returning
`alreadyInstalled`; it can no longer report success over corrupt bytes. Repair
is a separate `restoreInstalledRelease` operation requiring both trusted
hashes plus the caller-observed installed canonical hash as a compare-and-swap
precondition. It preserves the immutable release ID, replaces only a corrupt or
drifted local body, and appends a durable recovery receipt containing previous
and restored hashes. Activation/rollback mutation refuses a target whose
active pointer disagrees with its latest receipt.

Integrity audit now checks unique activation/recovery receipt IDs, exact
per-target receipt chains, installed current/previous releases, rollback-source
inversion, non-regressing target timestamps, active-pointer/latest-receipt
parity, recovery-record parity, and package-record metadata. Issues that belong
to Preview carry the Preview target and do not block a healthy Learner boot;
shared package damage still blocks every target using that release.

This code path authenticates against configured pinned public-key policy; it is
not proof that production publisher operations exist. No real non-test key,
private-key custody/signing service, rotation/revocation distribution, signed
Cardiology release or end-to-end channel delivery has been provisioned or
verified. Security authority therefore remains `active`, never `verified`.

## Recovery and invalidation

The cache is never durable authority:

- `evictRelease` discards one release index without touching its package;
- `clearMemoryCache` discards every derived index without touching package or
  learner data;
- a global clear generation plus per-release eviction generations invalidate
  only builds that began before the relevant recovery action;
- active-pointer lookup itself is tracked, so eviction or clear during the
  pointer-read window cannot later repopulate the cache;
- active catalog loading rechecks the target pointer and retries when activation
  changes mid-load instead of returning a stale release;
- an invalidated build may still satisfy its original caller with a valid
  ephemeral snapshot, but it is not retained;
- an oversized or evicted snapshot rebuilds from the immutable package;
- failed or missing releases surface typed package/catalog errors and never
  synthesize learner content.

`CurriculumCatalogCacheStatus` exposes only release IDs and aggregate counts:
cached releases/nodes, hits, misses, evictions, oversized bypasses, invalidated
builds, in-flight builds, and aggregate active lookups. It contains no lesson body, query text, learner
identity, answer, progress, or PHI. It is diagnostic state, not analytics or a
production observability pipeline.

## Current evidence

`packages/services/test/curriculum_catalog_repository_test.dart` contains 22
passing tests, while package registry owns 17, signed release trust owns six,
session progress owns nine and Study Workspace owns six (60 Services tests in
the current targeted package suite). The catalog/package/trust cases prove:

- deterministic hierarchy and playback indexes;
- precomputed search-document parity with node count;
- English/Persian Yeh/Kaf/diacritic/ZWNJ normalization, cross-locale/source-key
  origin, kind/limit/tie ranking, and stable subtree scoping;
- rejection of duplicate or undeclared Micro-lesson/Session/Interaction
  ownership, wrong order, missing bodies, and wrong hierarchy lineage;
- explicit rejection of a missing scope;
- LRU rather than FIFO behavior under both release and node budgets;
- targeted eviction and rebuild without package loss;
- oversized-index bypass without package loss;
- coalesced concurrent builds with one package-store read;
- clear-during-build, targeted load, and active-pointer-read invalidation with
  no stale cache repopulation or unrelated-build invalidation;
- active-release changes mid-load retry rather than returning a stale snapshot;
- error cleanup/retry and same-release drift detection after first observation;
- transport/canonical hash validation, strict stored canonical bytes and record
  parity, non-destructive quarantine, truthful idempotency, trusted restore
  receipts, receipt-chain audit, cross-instance mutation serialization, and
  Preview/Learner fault isolation;
- offline-ready, corrupt, and unsupported bootstrap states remain truthful and
  non-destructive.
- strict signed-envelope round-trip and restart re-verification;
- forged signature/body drift, revoked/unknown/scope/time-invalid anchors and
  missing-policy rejection;
- signed-over-bundled trust upgrade, signed restore without downgrade, and
  pre-trust learner denial.

Targeted `flutter analyze packages/core packages/services` reports zero issues;
35 Core and 60 Services tests pass. The last integrated root receipt remains
recorded in `05-verification.md`; a new root-wide receipt must not be inferred
from these targeted commands.

## Open scale and offline work

This slice does **not** prove:

1. search latency or heap behavior at 1,138 chapters or future Micro-lesson
   scale;
2. an on-disk/content-addressed index or cache across app restarts;
3. offline media/body pack quotas, pinning, eviction, download resume, or
   checksum promotion;
4. transliteration, abbreviations, terminology aliases, typo tolerance, or
   medical-query quality;
5. cache observability SLOs, support tooling, or production telemetry;
6. background isolates/workers, platform storage pressure, or six-platform
   memory behavior;
7. production Cardiology package integration or reviewed EN/FA content.
8. production publisher-key provisioning, signer custody, rotation/revocation
   distribution and one real signed release delivered and re-audited across a
   cold start;
9. multi-isolate/process write arbitration beyond the current shared-store,
   same-isolate mutation queue.

The relevant Academy capabilities remain `active`, never `verified`, until
those gates and the broader capability profile have direct evidence.
