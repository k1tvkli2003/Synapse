# Generated artifact gate

The gate performs byte-for-byte regeneration checks for preservation contracts
and verifies the selected mascot, app icon, wordmark, platform packages, and
installed Flutter assets against their deterministic manifests. It also binds
the Drift web worker and SQLite WASM bytes to the versions in `pubspec.lock`
through `contracts/generated/web-runtime-assets.v1.json`. Synapse does not
currently commit generated Dart source.

Update the deterministic receipt only after reviewing an intentional generator
or manifest change:

```powershell
dart run tool/run_python.dart tool/generated/verify_generated.py --write-receipt
```
