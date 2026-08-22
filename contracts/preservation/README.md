# Synapse preservation contracts

This directory is the machine-readable compatibility boundary for the Synapse
rebuild. It freezes observable facts from the current Synapse and StudyHUB
surfaces before navigation, persistence, database, or capability ownership is
changed.

## What is protected

- `route-registry.v1.json`: 137 source `GoRoute` declarations, 145 concrete
  paths after typed library expansion, parameters, branches, intents, and 82
  route-helper variants.
- `module-registry.v1.json`: stable module, shell-branch, and serialized-enum
  identities.
- `persistence-keys.v1.json`: local schema-v1 keys, owners, defaults, call
  sites, migration rules, and restore expectations.
- `supabase-schema.v1.json`: sanitized tables, columns, RLS policies,
  functions, revocations, triggers, and views derived from migrations.
- `archived-domain-fixtures.v1.json`: synthetic legacy JSON for four models and
  all ten `SynapseEvent` variants. It contains no lesson body, PHI, secret, or
  production identifier.
- `deep-link-fixtures.v1.json`: cold-start, web-refresh, and native-location
  fixtures for every concrete route.
- `capability-ledger.v1.json`: stable ownership and verification metadata for
  the 76 inventoried Synapse and StudyHUB capabilities.
- `rollback-bundle.v1.json`: checksummed restoration baselines.
- `preservation-manifest.v1.json`: source and generated-output checksums.
- `preservation-verification.v1.json`: deterministic receipt from the verifier.

All files except this README and the verification receipt are generated from
the authoritative source tree by `tool/preservation/generate_preservation_contracts.py`.
Do not hand-edit generated snapshots.

## Required verification

From the repository root:

```powershell
python tool/preservation/generate_preservation_contracts.py --check
python tool/preservation/verify_preservation_contracts.py
```

From `packages/core`:

```powershell
dart pub get
dart test test/preservation_fixture_test.dart
```

Regenerate only after reviewing an intentional, additive contract change:

```powershell
python tool/preservation/generate_preservation_contracts.py
python tool/preservation/verify_preservation_contracts.py
```

## Change rule

A rebuild may add adapters, aliases, routes, schema, or presentation layers. It
must not silently delete or reinterpret an existing route intent, serialized
identifier, persistence key, database policy, model/event field, deep-link
behavior, or capability. Destructive changes require explicit user approval,
a forward migration, a tested restore path, and an updated rollback fixture.

This gate proves source and fixture compatibility. It does not claim native
host deep-link execution or production-database parity; those require their
later platform and disposable-Supabase runtime gates.
