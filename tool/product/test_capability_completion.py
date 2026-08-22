from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


TOOL_DIR = Path(__file__).resolve().parent
if str(TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(TOOL_DIR))

import generate_capability_completion as generator
import verify_capability_completion as verifier


class CapabilityCompletionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.preservation = generator._load(generator.PRESERVATION_PATH)
        cls.language_policy = generator._load(generator.LANGUAGE_POLICY_PATH)
        cls.data_plane = generator._load(generator.DATA_PLANE_PATH)
        cls.new_capabilities = generator._load(generator.NEW_CAPABILITIES_PATH)

    def verify(self, document):
        return verifier.verify_document(
            document,
            self.preservation,
            self.language_policy,
            self.data_plane,
            self.new_capabilities,
        )

    def test_generated_contract_covers_all_capabilities_without_false_done(self):
        document = generator.generate()
        self.assertEqual(79, len(document["entries"]))
        self.assertEqual(0, document["summary"]["verified"])
        self.assertEqual(3, document["summary"]["active"])
        self.assertEqual([], self.verify(document))

    def test_missing_capability_and_gate_are_rejected(self):
        document = generator.generate()
        document["entries"].pop()
        issues = self.verify(document)
        self.assertIn("capability_coverage", {issue["code"] for issue in issues})

        document = generator.generate()
        document["entries"][0]["delivery"]["gates"].pop("visual_craft")
        issues = self.verify(document)
        self.assertIn("gate_coverage", {issue["code"] for issue in issues})

    def test_evidence_free_verified_status_is_rejected(self):
        document = generator.generate()
        entry = document["entries"][0]
        entry["delivery"]["completionStatus"] = "verified"
        document["summary"]["planned"] -= 1
        document["summary"]["verified"] += 1

        issues = self.verify(document)
        self.assertIn("false_done", {issue["code"] for issue in issues})

    def test_data_plane_and_product_integrity_are_required(self):
        document = generator.generate()
        entry = document["entries"][0]
        entry["dataPlane"]["concerns"].pop("backup_recovery")
        entry["product"]["surface"] = "StudyHub Legacy"

        codes = {issue["code"] for issue in self.verify(document)}
        self.assertIn("concern_coverage", codes)
        self.assertIn("legacy_brand_leak", codes)

    def test_unearned_page_and_unexplained_na_are_rejected(self):
        document = generator.generate()
        entry = document["entries"][0]
        entry["product"]["pageDecision"]["standalonePageEarned"] = True
        entry["delivery"]["gates"]["motion_feedback"]["status"] = "not_applicable"

        codes = {issue["code"] for issue in self.verify(document)}
        self.assertIn("page_sprawl", codes)
        self.assertIn("gate_not_applicable", codes)

    def test_generation_is_deterministic(self):
        self.assertEqual(generator.generate(), copy.deepcopy(generator.generate()))

    def test_reviewed_overlay_advances_state_without_losing_full_coverage(self):
        evidence = {
            "schemaVersion": 1,
            "contractId": "synapse.capability-evidence.v1",
            "entries": [
                {
                    "capabilityId": "synapse.global.eventbus",
                    "completionStatus": "active",
                    "entitySchemaStatus": "active",
                    "concerns": {"stable_identity": "active"},
                    "gates": {
                        "purpose": {
                            "status": "active",
                            "evidence": [],
                            "rationale": "Domain-event implementation is underway.",
                        }
                    },
                }
            ],
        }

        document = generator.generate(evidence)
        eventbus = next(
            entry
            for entry in document["entries"]
            if entry["capabilityId"] == "synapse.global.eventbus"
        )
        self.assertEqual("active", eventbus["delivery"]["completionStatus"])
        self.assertEqual(78, document["summary"]["planned"])
        self.assertEqual(1, document["summary"]["active"])
        self.assertEqual([], self.verify(document))


if __name__ == "__main__":
    unittest.main()
