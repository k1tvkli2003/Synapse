# Security gates

`scan_secrets.py` inspects tracked and non-ignored untracked text that could be
committed. It never prints a matched value: findings contain only path, line,
rule ID, and a short non-reversible fingerprint.

The frozen binary archive and generated visual evidence are not parsed as text.
StudyHUB remains an external quarantined source until its later sanitized
importer phase; no StudyHUB environment or credential file may be copied here.

```powershell
dart run tool/run_python.dart -m unittest tool/security/test_scan_secrets.py
dart run tool/run_python.dart tool/security/scan_secrets.py
```
