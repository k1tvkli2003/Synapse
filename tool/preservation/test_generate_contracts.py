from __future__ import annotations

import sys
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

import generate_preservation_contracts as contracts  # noqa: E402


class PreservationContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.generated = contracts.build_contracts()

    def test_modules_preserve_stable_serialized_ids(self) -> None:
        value = self.generated["module-registry.v1.json"]
        self.assertEqual(5, len(value["shellBranches"]))
        self.assertEqual(12, len(value["modules"]))
        self.assertEqual(
            ["copilot", "terms", "cards", "mnemonics", "ecg", "sounds", "labs", "algorithms", "orLab", "rounds", "buddies", "arena"],
            [item["id"] for item in value["modules"]],
        )

    def test_routes_include_legacy_deep_links_and_dynamic_library_families(self) -> None:
        value = self.generated["route-registry.v1.json"]
        paths = {item["path"] for item in value["routes"]}
        for required in {
            "/home",
            "/academy",
            "/academy/course",
            "/academy/session",
            "/academy/workspace",
            "/academy/document",
            "/learn/terms/lesson/:lessonId",
            "/clinical/ecg/case/:caseId",
            "/social/rounds/:roundId/comments",
            "/library/atlas/:id",
            "/library/journal/:id",
            "/chat/:threadId",
        }:
            self.assertIn(required, paths)
        self.assertEqual(150, len(paths))
        coverage = {
            item["path"]: item["capabilityId"]
            for item in self.generated["capability-ledger.v1.json"]["routeCoverage"]
        }
        self.assertEqual(
            "synapse.academy.curriculum-path", coverage["/academy/course"]
        )
        self.assertEqual(
            "synapse.academy.learning-session", coverage["/academy/session"]
        )
        self.assertEqual(
            "synapse.academy.curriculum-path", coverage["/academy/workspace"]
        )
        self.assertEqual(
            "synapse.academy.curriculum-path", coverage["/academy/document"]
        )
        helpers = {
            item["name"]: item
            for item in self.generated["route-registry.v1.json"]["helpers"]
        }
        self.assertEqual(
            "/academy/course?courseId=fixture-courseId",
            helpers["academyCourseFor"]["sampleOutput"],
        )
        self.assertEqual(
            "/academy/session?microLessonNodeId=fixture-microLessonNodeId&sessionId=fixture-sessionId",
            helpers["academySessionFor"]["sampleOutput"],
        )
        self.assertEqual(
            "/academy/workspace?nodeId=fixture-nodeId",
            helpers["academyWorkspaceFor"]["sampleOutput"],
        )
        self.assertEqual(
            "/academy/document?documentId=fixture-documentId&nodeId=fixture-nodeId",
            helpers["academyDocumentFor"]["sampleOutput"],
        )

    def test_persistence_registry_has_no_unowned_keys(self) -> None:
        value = self.generated["persistence-keys.v1.json"]
        self.assertEqual(18, len(value["entries"]))
        self.assertEqual(1, value["appSchemaVersion"])
        keys = {item["key"] for item in value["entries"]}
        self.assertIn("__synapse_schema", keys)
        self.assertIn("game_state", keys)
        self.assertIn("srs_cards", keys)
        self.assertIn("motion_presentation_queue_v1", keys)
        self.assertIn("__synapse_curriculum_session_progress_v1", keys)
        self.assertIn("__synapse_curriculum_study_workspace_v1", keys)
        self.assertIn("__synapse_curriculum_reading_state_v1", keys)
        self.assertIn("__synapse_resource_workspace_v1", keys)
        self.assertIn("__synapse_resource_document_reading_state_v1", keys)

    def test_supabase_snapshot_covers_all_current_authority_objects(self) -> None:
        value = self.generated["supabase-schema.v1.json"]
        self.assertEqual(3, len(value["migrations"]))
        self.assertEqual(9, len(value["tables"]))
        self.assertEqual(9, len(value["rlsEnabledTables"]))
        self.assertTrue(
            any("synapse_handle_new_user" in item for item in value["revocations"])
        )


if __name__ == "__main__":
    unittest.main()
