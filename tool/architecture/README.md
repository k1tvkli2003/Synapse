# Architecture and serialization gate

This validator enforces the package dependency DAG, keeps domain and
infrastructure packages pure Dart, rejects enum-index JSON persistence, and
requires authoritative `SynapseEvent` persistence to pass through a versioned
envelope. UI-only enum indexing and algorithmic enum ordering remain legal.

```powershell
dart run tool/run_python.dart -m unittest tool/architecture/test_validate_architecture.py
dart run tool/run_python.dart tool/architecture/validate_architecture.py
```
