# Product language integrity

`verify_product_language.py` makes the unified-product naming rule executable.
It scans every committable user-facing Flutter, package, and native-platform
source, including untracked work, for the retired source-brand variants. It
also joins the preservation capability ledger to the naming contract and
requires every legacy capability to have one functional Synapse domain,
surface, label, entry context, exposure class, and `synapse.*` analytics
namespace.

Run the complete gate from the repository root:

```powershell
dart run melos run integrity
```

The old repository/product name is permitted only as technical provenance in
contracts, migration tools, fixtures, and historical documentation. Product
source has no blanket exclusion. A future migration adapter that genuinely
needs the literal must add an exact path/kind/rule/match-hash exception with a
reason, owner, and expiry date. Unused, approximate, or expired exceptions
fail the gate.

The contract is
`contracts/integrity/product-language-policy.v1.json`; its source IDs are
technical migration identities and its mapped names are the only candidates
for UI, navigation, notifications, accessibility labels, search, and analytics.
