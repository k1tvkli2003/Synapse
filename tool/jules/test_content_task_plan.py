from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

from tool.jules.content_task_plan import (
    PlanningError,
    _default_plan_schema_path,
    _default_policy_path,
    _default_policy_schema_path,
    _validate_with_schema,
    build_plan,
    canonical_bytes,
    main,
)


def _write_json(path: Path, value: object) -> None:
    path.write_text(
        json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf-8",
    )


def _fixture_scan(chapter_count: int = 16) -> dict[str, object]:
    hierarchy: list[dict[str, object]] = [
        {
            "kind": "course",
            "ordinal": 6,
            "sourceKey": "harrison-sim/course/06",
            "parentSourceKey": None,
            "directoryName": "Part_06_Cardiology",
            "relativePath": "Part_06_Cardiology",
        }
    ]
    documents: list[dict[str, object]] = [
        {
            "id": "source.file.global-index",
            "artifactRole": "part_index",
            "chapterSourceKey": "harrison-sim/course/06/chapter/index",
            "detectedMime": "text/markdown",
        }
    ]
    atoms: list[dict[str, object]] = [
        {
            "id": "source.atom.global-index.1",
            "sourceDocumentId": "source.file.global-index",
            "instructionalDisposition": "non_instructional",
            "riskTier": "foundational",
            "atomType": "decorative_or_navigation",
        }
    ]
    for ordinal in range(1, chapter_count + 1):
        chapter_key = f"harrison-sim/course/06/chapter/{ordinal:03d}"
        hierarchy.append(
            {
                "kind": "chapter",
                "ordinal": ordinal,
                "sourceKey": chapter_key,
                "parentSourceKey": "harrison-sim/course/06",
                "directoryName": f"Chapter_{ordinal:03d}_Topic",
                "relativePath": f"Part_06_Cardiology/Chapter_{ordinal:03d}_Topic",
            }
        )
        if ordinal % 2 == 1:
            hierarchy.append(
                {
                    "kind": "source_lesson",
                    "ordinal": 1,
                    "sourceKey": f"{chapter_key}/source-lesson/001",
                    "parentSourceKey": chapter_key,
                    "directoryName": "Lesson_001_Topic",
                    "relativePath": (
                        f"Part_06_Cardiology/Chapter_{ordinal:03d}_Topic/"
                        "Lesson_001_Topic"
                    ),
                }
            )
        document_id = f"source.file.chapter-{ordinal:03d}"
        documents.append(
            {
                "id": document_id,
                "chapterSourceKey": chapter_key,
                "detectedMime": "text/markdown",
            }
        )
        if ordinal % 2 == 0:
            documents.append(
                {
                    "id": f"source.file.chapter-{ordinal:03d}-media",
                    "chapterSourceKey": chapter_key,
                    "detectedMime": "image/jpeg",
                }
            )
        dispositions = ("required", "duplicate_required", "non_instructional")
        for atom_ordinal in range(1, ordinal + 3):
            disposition = dispositions[(atom_ordinal - 1) % len(dispositions)]
            atoms.append(
                {
                    "id": f"source.atom.chapter-{ordinal:03d}.{atom_ordinal:03d}",
                    "sourceDocumentId": document_id,
                    "instructionalDisposition": disposition,
                    "riskTier": (
                        "safety_critical"
                        if atom_ordinal == ordinal + 2 and ordinal % 5 == 0
                        else "clinical_high"
                    ),
                    "atomType": "warning" if atom_ordinal % 7 == 0 else "claim",
                }
            )
    atoms_by_document: dict[str, list[dict[str, object]]] = {}
    for atom in atoms:
        atoms_by_document.setdefault(str(atom["sourceDocumentId"]), []).append(atom)
    document_coverage = []
    for document in documents:
        if not str(document["detectedMime"]).startswith("text/"):
            continue
        document_atoms = atoms_by_document.get(str(document["id"]), [])
        document_coverage.append(
            {
                "sourceDocumentId": document["id"],
                "canonicalCharacterCount": 1,
                "canonicalLineCount": 1,
                "atomCount": len(document_atoms),
                "atomCountsByType": {},
                "atomCountsByDisposition": {},
                "allNonWhitespaceSourceRepresentedByDocumentAtoms": True,
            }
        )
    return {
        "$schema": "../../contracts/curriculum/source-scan.schema.v1.json",
        "schemaVersion": 1,
        "contractId": "synapse.curriculum.source-scan.v1",
        "manifestId": "scan.harrison-sim.course-06.fixture",
        "scope": {
            "classification": "user-provided-simulated-medical-reference",
            "courseFilters": ["06"],
            "localRootDistributable": False,
            "sourceKey": "harrison-sim",
        },
        "sourceTreeSha256": "a" * 64,
        "parser": {
            "name": "synapse-static-source-atomizer",
            "version": "1.1.1",
            "typescriptPolicy": (
                "strict-static-literal-and-structure-atomization; "
                "inert-untrusted-bytes-never-executed"
            ),
            "locatorCharacterSemantics": "fixture",
            "locatorLineSemantics": "fixture",
        },
        "hierarchyNodes": hierarchy,
        "sourceDocuments": documents,
        "sourceAtoms": atoms,
        "documentCoverage": document_coverage,
        "summary": {
            "chapterCount": chapter_count,
            "fileCount": len(documents),
            "atomCount": len(atoms),
            "quarantinedDocumentCount": 0,
        },
    }


class ContentTaskPlanTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.scan_path = self.root / "scan.json"
        _write_json(self.scan_path, _fixture_scan())

    def _build(self, *, shards: int = 15) -> dict[str, object]:
        return build_plan(
            source_scan_path=self.scan_path,
            policy_path=_default_policy_path(),
            policy_schema_path=_default_policy_schema_path(),
            shard_count=shards,
            pilot_ordinals=(1, 2),
        )

    def test_policy_and_plan_validate_against_draft_2020_12_schemas(self) -> None:
        policy = json.loads(_default_policy_path().read_text(encoding="utf-8"))
        _validate_with_schema(policy, _default_policy_schema_path())
        plan = self._build()
        _validate_with_schema(plan, _default_plan_schema_path())

    def test_all_chapters_and_global_artifacts_reconcile_without_overlap(self) -> None:
        plan = self._build()
        chapter_keys = [
            chapter["chapterSourceKey"]
            for lane in plan["lanes"]
            for chapter in lane["chapters"]
        ]
        self.assertEqual(16, len(chapter_keys))
        self.assertEqual(16, len(set(chapter_keys)))
        self.assertEqual(1, plan["globalArtifacts"]["counts"]["documents"])
        self.assertEqual(1, plan["globalArtifacts"]["counts"]["atoms"])
        self.assertEqual(15, len(plan["lanes"]))
        self.assertTrue(all(lane["chapters"] for lane in plan["lanes"]))

    def test_plan_is_raw_text_free_blocked_and_capability_bounded(self) -> None:
        plan = self._build()
        encoded = canonical_bytes(plan).decode("utf-8")
        self.assertEqual("blocked_external_processing", plan["status"])
        self.assertFalse(plan["executionBoundary"]["remoteMutationAllowed"])
        self.assertFalse(plan["executionBoundary"]["julesManifestEmitted"])
        self.assertFalse(plan["executionBoundary"]["rawSourceTextIncluded"])
        self.assertEqual(
            [
                "lesson_writing",
                "embedded_quiz_writing",
                "bounded_reinforcement_summary",
            ],
            plan["phaseTemplates"][1]["authoringCapabilities"],
        )
        self.assertIn("enrich_writing", plan["policy"]["forbiddenProductionStages"])
        self.assertNotIn('"rawText"', encoded)
        self.assertNotIn('"sourceText"', encoded)
        rights = next(gate for gate in plan["gates"] if gate["id"] == "rights_clearance")
        self.assertEqual("blocked", rights["state"])

    def test_generation_is_deterministic_and_check_mode_detects_drift(self) -> None:
        first = self._build()
        second = self._build()
        self.assertEqual(canonical_bytes(first), canonical_bytes(second))
        output = self.root / "plan.json"
        self.assertEqual(
            0,
            main(
                [
                    "--source-scan",
                    str(self.scan_path),
                    "--pilot-chapters",
                    "1,2",
                    "--output",
                    str(output),
                ]
            ),
        )
        self.assertEqual(
            0,
            main(
                [
                    "--source-scan",
                    str(self.scan_path),
                    "--pilot-chapters",
                    "1,2",
                    "--check",
                    str(output),
                ]
            ),
        )
        output.write_text(output.read_text(encoding="utf-8") + " ", encoding="utf-8")
        self.assertEqual(
            2,
            main(
                [
                    "--source-scan",
                    str(self.scan_path),
                    "--pilot-chapters",
                    "1,2",
                    "--check",
                    str(output),
                ]
            ),
        )

    def test_plan_identity_changes_when_scan_receipt_changes(self) -> None:
        first = self._build()
        revised_scan = _fixture_scan()
        revised_scan["manifestId"] = "scan.harrison-sim.course-06.fixture-revised"
        _write_json(self.scan_path, revised_scan)
        second = self._build()

        self.assertEqual(
            first["source"]["sourceTreeSha256"],
            second["source"]["sourceTreeSha256"],
        )
        self.assertNotEqual(
            first["source"]["sourceScanSha256"],
            second["source"]["sourceScanSha256"],
        )
        self.assertNotEqual(first["planId"], second["planId"])

    def test_policy_cannot_enable_remote_mutation_or_fixed_quiz_counts(self) -> None:
        policy = json.loads(_default_policy_path().read_text(encoding="utf-8"))
        unsafe = copy.deepcopy(policy)
        unsafe["externalExecution"]["remoteMutationAllowedNow"] = True
        unsafe["embeddedQuizWriting"]["fixedQuestionCountAllowed"] = True
        unsafe_path = self.root / "unsafe-policy.json"
        _write_json(unsafe_path, unsafe)
        with self.assertRaises(PlanningError):
            build_plan(
                source_scan_path=self.scan_path,
                policy_path=unsafe_path,
                policy_schema_path=_default_policy_schema_path(),
                shard_count=15,
                pilot_ordinals=(1, 2),
            )


if __name__ == "__main__":
    unittest.main()
