# Curriculum source scan

`source_scan.py` creates a deterministic, source-root-free receipt for every
file in the user-provided Harrison-like corpus. It atomizes Markdown and uses a
strict static object/array-literal parser to account for TypeScript sidecar
strings, quiz candidates, table values, media labels, numeric answer metadata,
comments, and remaining structural syntax. It does not author lessons, infer
medical truth, contact Jules, or execute source-side TypeScript.

Cardiology-first scan:

```powershell
python -m tool.curriculum.source_scan `
  --source-root 'C:\Users\K1\Desktop\Harrison' `
  --course 06 `
  --output "$env:TEMP\synapse-course-06-source-scan.json" `
  --json-summary
```

Full-corpus scan: omit `--course`. Verify a checked-in or promoted receipt
without rewriting it by replacing `--output <path>` with `--check <path>`.

Validation:

```powershell
python -m unittest tool.curriculum.test_source_scan -v
```

Safety invariants:

- all paths in the receipt are NFC-normalized and repository-relative;
- file and tree identities are SHA-256 based and stable across source roots;
- MIME is identified from magic bytes before the claimed extension is trusted;
- `.ts` and `.tsx` files are inert untrusted candidates: the scanner tokenizes
  and statically walks literal structure but never imports, evaluates,
  transpiles, invokes, or shells out to them;
- simple template references such as `${IMAGES_BASE}` are recognized only when
  the referenced identifier has an inert quoted `const` binding; complex or
  unresolved interpolation remains an explicit semantic-review finding;
- duplicate and non-instructional material is accounted for, never silently
  dropped;
- all authoring candidates remain draft inputs requiring rights confirmation
  and medical claim verification.
