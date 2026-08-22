# Preservation Harness — Phase 01 Gate

Date completed locally: 2026-07-17  
Additive Academy extension verified locally: 2026-07-18

Status: WBS-031–040 are complete. The rebuild now has a deterministic,
source-derived compatibility boundary for navigation, serialization, local
state, Supabase structure, archived domain payloads, deep-link intent,
capability ownership, and rollback baselines. The gate has zero unresolved P0
findings.

## Why this gate exists

Synapse is being radically restructured around medical education, but the
existing product and the absorbed StudyHUB capability set are not disposable.
Planning documents alone cannot detect an accidental route rename, persistence
key drift, enum identity change, RLS omission, or orphaned capability. This
harness turns those facts into generated fixtures and executable checks before
navigation or user-data behavior changes.

## Generated contract set

`tool/preservation/generate_preservation_contracts.py` parses the authoritative
Dart, SQL, and capability sources using the Python standard library and emits
the following versioned files under `contracts/preservation/`:

| Contract | Frozen evidence |
|---|---|
| `route-registry.v1.json` | 141 literal `GoRoute` declarations and 149 unique concrete routes after the two five-way `LibraryKind` expansions; parameters, samples, shell ownership, intent, and 89 helper variants |
| `module-registry.v1.json` | 12 stable `ModuleKey` IDs, five `ShellBranch` IDs, and all 38 serialized source enums, including `MotionModePref` |
| `persistence-keys.v1.json` | 15 owned schema-v1 persistence entries with type, default, call sites, compatibility, and migration metadata: 13 preserved keys plus the release-bound Academy session-checkpoint and stable-node Study Workspace registries |
| `supabase-schema.v1.json` | migrations 0001–0003: nine tables, all nine RLS enables, 11 policies, one function, one execute revocation, two triggers, and one view |
| `archived-domain-fixtures.v1.json` | four synthetic model payloads and all ten legacy `SynapseEvent` variants, including nested `RewardEvent` |
| `deep-link-fixtures.v1.json` | 447 fixtures: cold start, web refresh, and native location for each of 149 concrete routes |
| `capability-ledger.v1.json` | 76 Synapse/StudyHUB capability records with stable ID, honest state, current owner, target context, and verification owner |
| `rollback-bundle.v1.json` | checksummed route, local-state, schema, and capability restoration baselines |
| `preservation-manifest.v1.json` | hashes for every generated output and every source byte used to derive it, including the registered additive Academy capability source |

The 141/149 route counts are intentionally different: 141 is the literal
declaration count; 149 is the actual concrete path count after expanding two
dynamic library route declarations across five library kinds each. Neither
number is being hidden or conflated.

The preservation capability baseline remains exactly 76 records. The three
Academy capabilities are registered separately as additive owners for the new
`/academy` route family; accepting those owners proves that new work is
accountable without relabelling it as legacy behavior or mutating the frozen
baseline. Persistence follows the same rule: 13 legacy keys remain preserved,
while the Academy checkpoint and private stable-node Workspace are two explicit
additive Data Plane entries.

## Executable verification

`tool/preservation/verify_preservation_contracts.py` regenerates every contract
in memory, byte-compares all nine snapshots, and runs 31 semantic checks. It
also writes `preservation-verification.v1.json` as a deterministic receipt.

Latest result:

- status: `pass`;
- checks: 31/31;
- P0 findings: zero;
- manifest SHA-256: `499DD57781129AE08D5107E3C612B48A0B40894652F073050651555B0026595F`;
- rollback bundle SHA-256: `7800DD346A14BD274795194622769627072BE62B111CE5D9031CFDFEF629AC15`;
- verification receipt SHA-256: `C27DCB8E8A03B68A3ED35AF6D360B82A313ED66D3A8C7D3303FA993C5461EFA9`.

`packages/core/test/preservation_fixture_test.dart` then exercises the actual
pure-Dart production models rather than trusting Python extraction. It decodes
and re-encodes `Concept`, `ConceptMastery`, `SrsCard`, and `UserProfile`, plus
all ten `SynapseEvent` variants, and requires exact nested JSON parity.

Latest Dart result: two tests passed; `dart analyze` reports no issues.

## Reproduction

From the repository root:

```powershell
$python = 'C:\Users\K1\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $python -m py_compile tool/preservation/generate_preservation_contracts.py tool/preservation/verify_preservation_contracts.py
& $python tool/preservation/generate_preservation_contracts.py --check
& $python tool/preservation/verify_preservation_contracts.py
& $python tool/validate_wbs.py docs/codex/2026-07-15-synapse-medical-learning-os/14-wbs.md --expected 440
```

From `packages/core`:

```powershell
dart pub get
dart analyze
dart test test/preservation_fixture_test.dart
```

The generator is intentionally separate from the verifier. `--check` must pass
without rewriting snapshots in routine work. Regeneration is allowed only for
an intentional reviewed contract change with the necessary additive adapter,
migration, and rollback evidence.

## Change boundary now enforced

Later implementation may add presentation labels, adapters, aliases, routes,
schema, or contextual capability surfaces. It may not silently delete or
reinterpret an existing route intent, module/branch ID, persistence key,
database authority rule, model/event field, deep-link destination, or
capability. A destructive change still requires explicit user approval,
forward migration, tested restore behavior, and a deliberately updated
rollback baseline.

No medical lesson body, PHI, secret, or production user identifier is present
in these fixtures.

## Honest limits

This phase proves source and fixture compatibility. It does not yet prove:

1. Android/iOS/desktop host delivery of every deep link;
2. browser history restoration under a deployed web origin;
3. migration/RLS behavior against a disposable live Supabase project;
4. restoration of real user-owned files or production database rows.

Those are later runtime gates. This document must not be cited as native-host
or production-database proof.
