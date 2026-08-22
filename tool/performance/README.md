# Performance budget gate

`contracts/performance/performance-budgets.v1.json` is the versioned foundation
contract for startup, frames, memory, web JS/WASM, runtime assets, motion rigs,
fragment shaders, and curriculum packs.

The gate deliberately separates two kinds of evidence:

- deterministic static artifact probes are blocking above their explicit
  `blockingMaxBytes` ceiling;
- startup, frame, memory, interaction, and power measurements remain
  informational until a named physical-device profile has at least ten
  controlled profile/release runs.

Run the unit tests and live gate from the repository root:

```powershell
dart run tool/run_python.dart -m unittest tool/performance/test_verify_performance_budgets.py
dart run tool/run_python.dart tool/performance/verify_performance_budgets.py
```

After a release web build, refresh the checked evidence receipt explicitly:

```powershell
dart run tool/run_python.dart tool/performance/verify_performance_budgets.py --write-receipt
```

The full/reduced/off motion contract and standard/milestone/showpiece budgets
apply to Flutter procedural animation, fragment shaders, and Rive state
machines. Every non-trivial motion asset must also own an interruption path and
a deterministic renderer fallback before it can ship.
