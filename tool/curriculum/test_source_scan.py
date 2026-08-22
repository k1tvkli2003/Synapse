from __future__ import annotations

import hashlib
import json
import os
import shutil
import tempfile
import unittest
from contextlib import contextmanager
from pathlib import Path

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from tool.curriculum.source_scan import (
    _canonical_text,
    main,
    manifest_bytes,
    scan_source,
)
from tool.curriculum.typescript_static_parser import atomize_typescript_sidecar


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONTENT_CONTRACT = PROJECT_ROOT / "contracts/curriculum/content-contract.v1.json"
SCAN_SCHEMA = PROJECT_ROOT / "contracts/curriculum/source-scan.schema.v1.json"


def long_path_aware(path: Path) -> Path:
    resolved = path.resolve()
    if os.name != "nt":
        return resolved
    value = str(resolved)
    if value.startswith("\\\\"):
        return Path("\\\\?\\UNC\\" + value[2:])
    return Path("\\\\?\\" + value)


@contextmanager
def temporary_directory():
    raw = Path(tempfile.mkdtemp())
    extended = long_path_aware(raw)
    try:
        yield extended
    finally:
        shutil.rmtree(extended)


def write(path: Path, value: str | bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(value, bytes):
        path.write_bytes(value)
    else:
        path.write_text(value, encoding="utf-8", newline="")


def fixture_source(root: Path) -> Path:
    source = root / "هاریسون-آزمایشی-با-مسیر-یونیک"
    part = source / "Part_06_Disorders_Cardiovascular_System"
    chapter = part / "Chapter_001_Approach_to_Cardiovascular_Disease"
    lesson = chapter / "Lesson_001_Clinical_Orientation"
    other_part = source / "Part_07_Respiratory_System"
    other_chapter = other_part / "Chapter_001_Respiratory_Orientation"

    write(
        part / "Part_06_Disorders_Cardiovascular_System_Chapters.md",
        "# Course index\n\n- Chapter 1\n",
    )
    canonical_markdown = """# Cardiovascular Orientation

This English claim also names قلب and refers to Chap. 12.

## Clinical Pearl

Key point: context changes interpretation.

## Warning

Warning: a threshold above 120 mm Hg needs verification.

- Compare symptoms with exertion.

| Finding | Meaning |
| :--- | ---: |
| Value | $x > 5$ and at least 10 mg |

![ECG strip](images/ecg.png)

FIGURE 1. Demonstration caption.

[^note]: Source footnote.
"""
    chapter_markdown = chapter / "Chapter_001_Approach_to_Cardiovascular_Disease.md"
    write(chapter_markdown, canonical_markdown)
    write(lesson / "Lesson_001_Clinical_Orientation.md", "## Lesson\n\nیک متن فارسی.\n")
    sidecars = {
        "find": (
            "throw new Error('must never execute');\n"
            "export const find = { title: 'درس', sections: [{ id: 's1', "
            "blocks: [{ id: 'b1', content: 'فشار بالاتر از 120 mm Hg نیاز به بررسی دارد.' }] }] };\n"
        ),
        "summary": (
            "export const summary = { title: 'مرور', sections: [{ id: 's1', "
            "blocks: [{ id: 'b1', content: 'این مرور فقط تقویت است.' }] }] };\n"
        ),
        "quiz": (
            "export const quiz = { quizQuestions: [{ id: 'q1', question: 'کدام گزینه؟', "
            "options: ['گزینه الف', 'گزینه ب', 'گزینه ج', 'گزینه د'], "
            "correctAnswer: 1, explanation: 'گزینه ب درست است و سه گزینه دیگر نادرست‌اند.' }] };\n"
        ),
        "enrich": (
            "export const enrich = { title: 'کاندید قدیمی', sections: [{ id: 's1', "
            "blocks: [{ id: 'b1', content: 'جزئیات کاندید باید بازبینی شود.' }] }] };\n"
        ),
        "contributors": (
            "export const CONTRIBUTORS = { professors: [], authors: ['نام نویسنده'] };\n"
        ),
    }
    for suffix, sidecar in sidecars.items():
        write(
            lesson / f"Lesson_001_Clinical_Orientation_{suffix}.ts",
            sidecar,
        )
    sentinel = root / "typescript-executed.txt"
    write(
        lesson / "Lesson_001_Clinical_Orientation_unknown.ts",
        "require('fs').writeFileSync('typescript-executed.txt', 'bad');\n",
    )
    write(chapter / "images" / "ecg.png", b"\xff\xd8\xff\xe0fixture-jpeg")

    # Same bytes under two different paths must remain present and be grouped.
    write(chapter / "duplicate-a.md", canonical_markdown)
    write(chapter / "duplicate-b.md", canonical_markdown)
    write(chapter / "empty.md", "")
    write(chapter / "malformed.md", "## Broken\n\n```ts\nnot executed\n")
    long_name = "مرجع_" + ("بسیار_" * 18) + "طولانی.md"
    write(chapter / long_name, "## نکته\n\nمتن فارسی و English.\n")

    write(
        other_part / "Part_07_Respiratory_System_Chapters.md",
        "# Respiratory\n",
    )
    write(
        other_chapter / "Chapter_001_Respiratory_Orientation.md",
        "# Other course\n",
    )
    return source


def validate_schema(manifest: dict[str, object]) -> None:
    contract = json.loads(CONTENT_CONTRACT.read_text(encoding="utf-8"))
    schema = json.loads(SCAN_SCHEMA.read_text(encoding="utf-8"))
    registry = Registry().with_resource(
        contract["$id"], Resource.from_contents(contract)
    )
    Draft202012Validator(schema, registry=registry).validate(manifest)


class SourceScanTest(unittest.TestCase):
    def test_typescript_review_findings_ignore_medical_prose_but_detect_code(self) -> None:
        _, prose_findings = atomize_typescript_sidecar(
            "export const lesson = { content: 'Assess ventricular function.' };",
            artifact_role="derived_find_sidecar",
        )
        self.assertNotIn(
            "typescript_dynamic_expression_requires_semantic_review",
            prose_findings,
        )

        _, arrow_findings = atomize_typescript_sidecar(
            "export const build = () => ({ content: 'Dynamic result.' });",
            artifact_role="derived_find_sidecar",
        )
        self.assertIn(
            "typescript_dynamic_expression_requires_semantic_review",
            arrow_findings,
        )

        _, function_findings = atomize_typescript_sidecar(
            "export function build() { return { content: 'Dynamic result.' }; }",
            artifact_role="derived_find_sidecar",
        )
        self.assertIn(
            "typescript_dynamic_expression_requires_semantic_review",
            function_findings,
        )

        _, static_template_findings = atomize_typescript_sidecar(
            "const unit = 'mm Hg'; export const x = { content: `Value ${unit}` };",
            artifact_role="derived_find_sidecar",
        )
        self.assertIn(
            "typescript_static_template_reference_atomized",
            static_template_findings,
        )
        self.assertNotIn(
            "typescript_template_interpolation_requires_semantic_review",
            static_template_findings,
        )

        _, template_findings = atomize_typescript_sidecar(
            "export const x = { content: `Value ${unit.toUpperCase()}` };",
            artifact_role="derived_find_sidecar",
        )
        self.assertIn(
            "typescript_template_interpolation_requires_semantic_review",
            template_findings,
        )

    def test_course_scan_classifies_every_artifact_without_executing_typescript(self) -> None:
        with temporary_directory() as temporary:
            root = temporary
            source = fixture_source(root)

            manifest = scan_source(
                source,
                courses=["06"],
                content_contract=CONTENT_CONTRACT,
            )

            validate_schema(manifest)
            self.assertFalse((root / "typescript-executed.txt").exists())
            self.assertEqual(manifest["scope"]["courseFilters"], ["06"])
            self.assertEqual(manifest["summary"]["courseCount"], 1)
            self.assertEqual(manifest["summary"]["chapterCount"], 1)
            self.assertEqual(manifest["summary"]["explicitSourceLessonCount"], 1)

            roles = {
                document["artifactRole"]
                for document in manifest["sourceDocuments"]
            }
            self.assertTrue(
                {
                    "part_index",
                    "chapter_markdown",
                    "lesson_markdown",
                    "supplemental_markdown",
                    "derived_find_sidecar",
                    "derived_summary_sidecar",
                    "derived_quiz_sidecar",
                    "derived_enrich_sidecar",
                    "contributor_metadata_sidecar",
                    "other_reviewed_source",
                    "media",
                }.issubset(roles)
            )
            sidecars = [
                document
                for document in manifest["sourceDocuments"]
                if document["claimedExtension"] == "ts"
            ]
            self.assertTrue(sidecars)
            self.assertTrue(
                all(
                    "untrusted_typescript_candidate_not_executed"
                    in document["findingCodes"]
                    for document in sidecars
                )
            )
            self.assertTrue(
                all(document["ingestState"] == "atomized" for document in sidecars)
            )
            coverage_by_document = {
                item["sourceDocumentId"]: item
                for item in manifest["documentCoverage"]
            }
            self.assertTrue(
                all(
                    sidecar["id"] in coverage_by_document
                    and coverage_by_document[sidecar["id"]]["atomCount"] > 0
                    and coverage_by_document[sidecar["id"]][
                        "allNonWhitespaceSourceRepresentedByDocumentAtoms"
                    ]
                    for sidecar in sidecars
                )
            )
            sidecar_ids = {sidecar["id"] for sidecar in sidecars}
            sidecar_atoms = [
                atom
                for atom in manifest["sourceAtoms"]
                if atom["sourceDocumentId"] in sidecar_ids
            ]
            sidecar_atom_types = {atom["atomType"] for atom in sidecar_atoms}
            self.assertTrue(
                {
                    "heading",
                    "claim",
                    "numeric_threshold",
                    "quiz_stem_candidate",
                    "quiz_option_candidate",
                    "quiz_explanation_candidate",
                    "contributor_metadata",
                    "decorative_or_navigation",
                }.issubset(sidecar_atom_types)
            )
            contributor_document = next(
                sidecar
                for sidecar in sidecars
                if sidecar["artifactRole"] == "contributor_metadata_sidecar"
            )
            contributor_atoms = [
                atom
                for atom in sidecar_atoms
                if atom["sourceDocumentId"] == contributor_document["id"]
                and atom["atomType"] == "contributor_metadata"
            ]
            self.assertTrue(contributor_atoms)
            self.assertTrue(
                all(
                    atom["instructionalDisposition"] == "non_instructional"
                    for atom in contributor_atoms
                )
            )

    def test_atoms_cover_required_markdown_signals_and_have_exact_locators(self) -> None:
        with temporary_directory() as temporary:
            source = fixture_source(temporary)
            manifest = scan_source(
                source,
                courses=["6"],
                content_contract=CONTENT_CONTRACT,
            )
            atom_types = {atom["atomType"] for atom in manifest["sourceAtoms"]}
            self.assertTrue(
                {
                    "heading",
                    "claim",
                    "list_item",
                    "table_header",
                    "table_cell",
                    "formula",
                    "numeric_threshold",
                    "warning",
                    "clinical_pearl",
                    "cross_reference",
                    "footnote",
                    "figure_reference",
                    "figure_caption",
                    "decorative_or_navigation",
                }.issubset(atom_types)
            )

            documents = {
                document["id"]: document for document in manifest["sourceDocuments"]
            }
            for atom in manifest["sourceAtoms"]:
                document = documents[atom["sourceDocumentId"]]
                path = source / document["relativePath"]
                canonical = _canonical_text(path.read_text(encoding="utf-8-sig"))
                locator = atom["locator"]
                start = locator["startCharacter"]
                end = locator["endCharacter"]
                selected = canonical[start:end]
                self.assertEqual(
                    hashlib.sha256(selected.encode("utf-8")).hexdigest(),
                    atom["sourceTextSha256"],
                )
                expected_start_line = canonical.count("\n", 0, start) + 1
                expected_end_line = canonical.count("\n", 0, max(start, end - 1)) + 1
                self.assertEqual(locator["startLine"], expected_start_line)
                self.assertEqual(locator["endLine"], expected_end_line)

    def test_mixed_locale_mime_mismatch_empty_malformed_and_duplicates_are_retained(self) -> None:
        with temporary_directory() as temporary:
            source = fixture_source(temporary)
            manifest = scan_source(
                source,
                courses=["06"],
                content_contract=CONTENT_CONTRACT,
            )
            documents = manifest["sourceDocuments"]
            chapter = next(
                document
                for document in documents
                if document["artifactRole"] == "chapter_markdown"
            )
            self.assertEqual(chapter["sourceLocale"], "mixed")

            media = next(
                document for document in documents if document["artifactRole"] == "media"
            )
            self.assertEqual(media["detectedMime"], "image/jpeg")
            self.assertIn("claimed_extension_mime_mismatch", media["findingCodes"])

            empty = next(
                document for document in documents if document["relativePath"].endswith("empty.md")
            )
            self.assertIn("empty_file", empty["findingCodes"])
            empty_atoms = [
                atom
                for atom in manifest["sourceAtoms"]
                if atom["sourceDocumentId"] == empty["id"]
            ]
            self.assertEqual(len(empty_atoms), 1)
            self.assertEqual(empty_atoms[0]["instructionalDisposition"], "non_instructional")

            malformed = next(
                document
                for document in documents
                if document["relativePath"].endswith("malformed.md")
            )
            self.assertIn("unclosed_code_fence", malformed["findingCodes"])
            self.assertEqual(malformed["ingestState"], "atomized")

            duplicate_markdown = [
                document
                for document in documents
                if "duplicate_raw_document" in document["findingCodes"]
                and document["rawSha256"] == chapter["rawSha256"]
            ]
            self.assertEqual(len(duplicate_markdown), 3)
            self.assertGreater(manifest["summary"]["duplicateAtomCount"], 0)

    def test_manifest_is_root_free_deterministic_and_check_mode_detects_drift(self) -> None:
        with temporary_directory() as first, temporary_directory() as second:
            first_source = fixture_source(first)
            second_source = fixture_source(second)
            first_manifest = scan_source(
                first_source,
                courses=["06"],
                content_contract=CONTENT_CONTRACT,
            )
            second_manifest = scan_source(
                second_source,
                courses=["06"],
                content_contract=CONTENT_CONTRACT,
            )
            first_bytes = manifest_bytes(first_manifest)
            second_bytes = manifest_bytes(second_manifest)
            self.assertEqual(first_bytes, second_bytes)
            self.assertNotIn(str(first_source).encode("utf-8"), first_bytes)
            self.assertNotIn(str(second_source).encode("utf-8"), second_bytes)

            output = Path(first) / "manifest.json"
            output.write_bytes(first_bytes)
            self.assertEqual(
                main(
                    [
                        "--source-root",
                        str(first_source),
                        "--course",
                        "06",
                        "--check",
                        str(output),
                        "--content-contract",
                        str(CONTENT_CONTRACT),
                    ]
                ),
                0,
            )
            output.write_text("{}\n", encoding="utf-8")
            self.assertEqual(
                main(
                    [
                        "--source-root",
                        str(first_source),
                        "--course",
                        "06",
                        "--check",
                        str(output),
                        "--content-contract",
                        str(CONTENT_CONTRACT),
                    ]
                ),
                1,
            )

    def test_full_mode_includes_all_parts_while_course_mode_is_scoped(self) -> None:
        with temporary_directory() as temporary:
            source = fixture_source(temporary)
            scoped = scan_source(
                source,
                courses=["06"],
                content_contract=CONTENT_CONTRACT,
            )
            full = scan_source(
                source,
                content_contract=CONTENT_CONTRACT,
            )
            self.assertEqual(scoped["summary"]["courseCount"], 1)
            self.assertEqual(full["summary"]["courseCount"], 2)
            self.assertGreater(full["summary"]["fileCount"], scoped["summary"]["fileCount"])
            self.assertEqual(full["scope"]["courseFilters"], [])


if __name__ == "__main__":
    unittest.main()
