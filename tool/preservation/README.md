# Preservation Contracts

These deterministic fixtures freeze operational identity before the additive rebuild changes navigation, persistence, or backend authority.

The canonical current generator and verifier are `generate_preservation_contracts.py` and `verify_preservation_contracts.py`. They cover routes, helpers, enums, persistence, schema, synthetic archived payloads, deep-link fixtures, the 76-record capability ledger, rollback checksums, and source hashes.

Generate after an intentional, reviewed contract change:

```powershell
python tool/preservation/generate_preservation_contracts.py
```

Verify without writing:

```powershell
python tool/preservation/generate_preservation_contracts.py --check
python tool/preservation/verify_preservation_contracts.py
python -m unittest tool/preservation/test_generate_contracts.py
```

The historical `generate_contracts.py` remains only as preserved pre-consolidation provenance; it is not a release or CI authority. A source change makes the canonical `--check` fail until the contract drift is deliberately reviewed, migrated, and regenerated. The fixtures contain no credentials, environment values, user records, or lesson bodies.
