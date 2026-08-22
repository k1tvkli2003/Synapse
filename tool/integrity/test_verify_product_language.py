from __future__ import annotations

import json
import tempfile
import unittest
from datetime import date
from pathlib import Path

from tool.integrity.verify_product_language import (
    compile_rules,
    scan_repository,
    scan_value,
    validate_policy,
)


def fixture_policy() -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "policyId": "fixture.unified-naming",
        "productName": "Synapse",
        "capabilityLedger": "contracts/preservation/capability-ledger.v1.json",
        "legacyCapabilityIdPrefix": "studyhub.",
        "scanGlobs": ["apps/app/lib/**", "packages/*/lib/**"],
        "textSuffixes": [".dart", ".json"],
        "forbiddenRules": [
            {
                "id": "legacy-brand",
                "pattern": r"(?i)\bstudy[ \t_.-]*hub\b",
            }
        ],
        "allowlist": [],
        "capabilityMap": [
            {
                "sourceId": "studyhub.pdf-reader",
                "canonicalDomain": "Library",
                "surface": "Reader",
                "userFacingLabel": "Reader",
                "entryContext": "Open a source from Library or a lesson",
                "analyticsNamespace": "synapse.library.reader",
                "exposure": "contextual",
            }
        ],
    }


def write_fixture_ledger(root: Path) -> None:
    path = root / "contracts/preservation/capability-ledger.v1.json"
    path.parent.mkdir(parents=True)
    path.write_text(
        json.dumps({"entries": [{"id": "studyhub.pdf-reader"}]}),
        encoding="utf-8",
    )


class ProductLanguageTest(unittest.TestCase):
    def test_detects_compact_and_separated_legacy_brand_variants(self) -> None:
        rules = compile_rules(fixture_policy())
        for value in (
            "StudyHUB",
            "Study Hub",
            "study_hub",
            "Study-Hub",
            "Study.Hub",
        ):
            with self.subTest(value=value):
                self.assertEqual(
                    len(scan_value("screen.dart", value, rules, kind="content")),
                    1,
                )

    def test_allows_logical_product_terms(self) -> None:
        rules = compile_rules(fixture_policy())
        value = "Study Rooms · Concept Map · Margin Workspace · Review"
        self.assertEqual(scan_value("screen.dart", value, rules, kind="content"), [])

    def test_scans_product_surfaces_but_not_technical_docs(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            write_fixture_ledger(root)
            app_file = root / "apps/app/lib/screen.dart"
            docs_file = root / "docs/migration.md"
            app_file.parent.mkdir(parents=True)
            docs_file.parent.mkdir(parents=True)
            app_file.write_text("const title = 'StudyHUB';", encoding="utf-8")
            docs_file.write_text("StudyHUB source provenance", encoding="utf-8")

            result = scan_repository(
                root,
                fixture_policy(),
                paths=["apps/app/lib/screen.dart", "docs/migration.md"],
            )

            self.assertEqual(result["status"], "fail")
            self.assertEqual(len(result["findings"]), 1)
            self.assertEqual(result["findings"][0]["path"], "apps/app/lib/screen.dart")

    def test_capability_map_must_cover_every_legacy_source_id(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "contracts/preservation/capability-ledger.v1.json"
            path.parent.mkdir(parents=True)
            path.write_text(
                json.dumps(
                    {
                        "entries": [
                            {"id": "studyhub.pdf-reader"},
                            {"id": "studyhub.annotations"},
                        ]
                    }
                ),
                encoding="utf-8",
            )

            result = scan_repository(root, fixture_policy(), paths=[])

            self.assertEqual(result["status"], "fail")
            self.assertIn(
                "unmapped legacy capabilities: studyhub.annotations",
                result["policyErrors"],
            )

    def test_vague_hub_is_rejected_as_a_surface_name(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            write_fixture_ledger(root)
            policy = fixture_policy()
            policy["capabilityMap"][0]["surface"] = "Reader Hub"

            result = scan_repository(root, policy, paths=[])

            self.assertEqual(result["status"], "fail")
            self.assertTrue(
                any("vague standalone Hub" in item for item in result["policyErrors"])
            )

    def test_allowlist_requires_owner_reason_and_unexpired_date(self) -> None:
        policy = fixture_policy()
        policy["allowlist"] = [
            {
                "path": "apps/app/lib/migration/adapter.dart",
                "kind": "content",
                "ruleId": "legacy-brand",
                "matchSha256": "ABC",
                "reason": "",
                "owner": "migration",
                "expiresOn": "2026-01-01",
            }
        ]

        errors = validate_policy(policy, today=date(2026, 7, 17))

        self.assertTrue(any("concrete reason and owner" in item for item in errors))
        self.assertTrue(any("expired" in item for item in errors))


if __name__ == "__main__":
    unittest.main()
