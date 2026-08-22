import json
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = (
    PROJECT_ROOT / "contracts" / "curriculum" / "content-contract.v1.json"
)


class DeepStudyContentContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))

    def validator_for(self, definition: str) -> Draft202012Validator:
        return Draft202012Validator(
            {
                "$schema": "https://json-schema.org/draft/2020-12/schema",
                "$defs": self.contract["$defs"],
                "$ref": f"#/$defs/{definition}",
            }
        )

    def test_accepts_runtime_aligned_document_and_semantic_blocks(self) -> None:
        document = {
            "id": "study.document.preview.001",
            "microLessonNodeId": "node.micro-lesson.preview.001",
            "ordinal": 1,
            "kind": "primary_lesson",
            "titleUnitId": "l10n.study.preview.title",
            "blockIds": ["study.block.preview.key-idea"],
            "sourceAtomIds": ["source.atom.preview.001"],
            "claimIds": ["claim.preview.001"],
            "conceptIds": ["concept.preview.001"],
            "estimatedSeconds": {"en": 300, "fa": 340},
        }
        block = self._block()

        self.validator_for("studyDocument").validate(document)
        self.validator_for("studyBlock").validate(block)

    def test_rejects_unbounded_or_malformed_study_shapes(self) -> None:
        document = {
            "id": "study.document.preview.001",
            "microLessonNodeId": "node.micro-lesson.preview.001",
            "ordinal": 1,
            "kind": "primary_lesson",
            "titleUnitId": "l10n.study.preview.title",
            "blockIds": [f"study.block.preview.{index}" for index in range(25)],
            "sourceAtomIds": ["source.atom.preview.001"],
            "claimIds": [],
            "conceptIds": ["concept.preview.001"],
            "estimatedSeconds": {"en": 721, "fa": 340},
        }
        mechanism = self._block()
        mechanism["kind"] = "mechanism_chain"
        table = self._block()
        table["kind"] = "comparison_table"
        table["contentUnitIds"] = []
        table["tableRows"] = [
            ["l10n.table.a", "l10n.table.b"],
            ["l10n.table.row"],
        ]

        self.assertFalse(self.validator_for("studyDocument").is_valid(document))
        self.assertFalse(self.validator_for("studyBlock").is_valid(mechanism))
        # Rectangularity is a runtime/cross-field invariant; schema still
        # rejects this sample because a comparison row cannot be one cell.
        self.assertFalse(self.validator_for("studyBlock").is_valid(table))

    def test_reveal_gate_requires_a_session_and_always_forbids_one(self) -> None:
        gated = self._block()
        gated["revealPolicy"] = "after_session_completion"
        always_with_gate = self._block()
        always_with_gate["revealedAfterSessionId"] = "session.preview.001"

        self.assertFalse(self.validator_for("studyBlock").is_valid(gated))
        self.assertFalse(
            self.validator_for("studyBlock").is_valid(always_with_gate)
        )

        gated["revealedAfterSessionId"] = "session.preview.001"
        self.validator_for("studyBlock").validate(gated)

    @staticmethod
    def _block() -> dict[str, object]:
        return {
            "id": "study.block.preview.key-idea",
            "documentId": "study.document.preview.001",
            "ordinal": 1,
            "kind": "key_idea",
            "headingUnitId": "l10n.study.preview.heading",
            "contentUnitIds": ["l10n.study.preview.body"],
            "tableRows": [],
            "sourceAtomIds": ["source.atom.preview.001"],
            "claimIds": ["claim.preview.001"],
            "conceptIds": ["concept.preview.001"],
            "revealPolicy": "always",
            "revealedAfterSessionId": None,
        }


if __name__ == "__main__":
    unittest.main()
