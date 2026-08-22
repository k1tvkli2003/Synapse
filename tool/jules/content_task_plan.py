from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Any, Iterable, Sequence


GENERATOR_NAME = "synapse-content-task-planner"
GENERATOR_VERSION = "1.0.0"
GENERATOR_ALGORITHM = "whole-chapter-lpt-v1"
SOURCE_SCAN_CONTRACT_ID = "synapse.curriculum.source-scan.v1"
CONTENT_CONTRACT_ID = "synapse.medical-microlearning-content.v1"
AUTHORING_POLICY_ID = "synapse.medical-authoring.v1"
TASK_PLAN_SCHEMA = "../../contracts/curriculum/content-task-plan.schema.v1.json"
DEFAULT_PILOT_CHAPTERS = (6, 54)
MAX_SHARDS = 15

COUNT_FIELDS = (
    "chapters",
    "sourceLessons",
    "documents",
    "mediaDocuments",
    "atoms",
    "requiredAtoms",
    "duplicateRequiredAtoms",
    "nonInstructionalAtoms",
    "clinicalHighAtoms",
    "safetyCriticalAtoms",
    "warningAtoms",
    "planningWeight",
)


class PlanningError(RuntimeError):
    """Raised when a source scan cannot produce a safe deterministic plan."""


def _repository_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _default_policy_path() -> Path:
    return _repository_root() / "contracts" / "curriculum" / "authoring-policy.v1.json"


def _default_policy_schema_path() -> Path:
    return _repository_root() / "contracts" / "curriculum" / "authoring-policy.schema.v1.json"


def _default_plan_schema_path() -> Path:
    return _repository_root() / "contracts" / "curriculum" / "content-task-plan.schema.v1.json"


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise PlanningError(f"missing JSON input: {path}") from exc
    except json.JSONDecodeError as exc:
        raise PlanningError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise PlanningError(f"JSON root must be an object: {path}")
    return value


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: Path) -> str:
    try:
        return _sha256_bytes(path.read_bytes())
    except FileNotFoundError as exc:
        raise PlanningError(f"missing hash input: {path}") from exc


def _empty_counts(*, chapters: int = 0) -> dict[str, int]:
    result = {field: 0 for field in COUNT_FIELDS}
    result["chapters"] = chapters
    return result


def _add_counts(target: dict[str, int], source: dict[str, int]) -> None:
    for field in COUNT_FIELDS:
        target[field] += int(source[field])


def _planning_weight(counts: dict[str, int]) -> int:
    return (
        counts["atoms"]
        + counts["mediaDocuments"] * 12
        + counts["clinicalHighAtoms"] // 5
        + counts["safetyCriticalAtoms"] * 50
        + counts["warningAtoms"] * 20
    )


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise PlanningError(message)


def _validate_with_schema(instance: dict[str, Any], schema_path: Path) -> None:
    try:
        import jsonschema  # type: ignore[import-not-found]
    except ImportError as exc:
        raise PlanningError(
            "jsonschema is required to validate content planning contracts"
        ) from exc
    schema = _read_json(schema_path)
    try:
        jsonschema.Draft202012Validator.check_schema(schema)
        jsonschema.Draft202012Validator(schema).validate(instance)
    except jsonschema.exceptions.SchemaError as exc:
        raise PlanningError(f"invalid JSON schema {schema_path}: {exc.message}") from exc
    except jsonschema.exceptions.ValidationError as exc:
        location = "/".join(str(item) for item in exc.absolute_path) or "<root>"
        raise PlanningError(
            f"schema validation failed at {location}: {exc.message}"
        ) from exc


def _validate_policy(policy: dict[str, Any], schema_path: Path) -> None:
    _validate_with_schema(policy, schema_path)
    boundary = policy["capabilityBoundary"]
    _require(
        boundary["allowedAuthoringCapabilities"]
        == [
            "lesson_writing",
            "embedded_quiz_writing",
            "bounded_reinforcement_summary",
        ],
        "authoring policy capability boundary drifted",
    )
    forbidden = set(boundary["forbiddenProductionStages"])
    _require("enrich_writing" in forbidden, "authoring policy must forbid Enrich")
    _require(
        "specialist_writing" in forbidden,
        "authoring policy must forbid specialist writing",
    )
    _require(
        policy["embeddedQuizWriting"]["fixedQuestionCountAllowed"] is False,
        "fixed quiz counts must remain forbidden",
    )
    _require(
        policy["boundedReinforcementSummary"]["standaloneProductionPhase"] is False,
        "summary must remain an in-session reinforcement role",
    )
    _require(
        policy["externalExecution"]["remoteMutationAllowedNow"] is False,
        "policy cannot activate remote processing implicitly",
    )


def _validate_source_scan(scan: dict[str, Any]) -> str:
    _require(scan.get("schemaVersion") == 1, "source scan schemaVersion must be 1")
    _require(
        scan.get("contractId") == SOURCE_SCAN_CONTRACT_ID,
        f"source scan contractId must be {SOURCE_SCAN_CONTRACT_ID}",
    )
    scope = scan.get("scope")
    _require(isinstance(scope, dict), "source scan scope is missing")
    _require(scope.get("sourceKey") == "harrison-sim", "unexpected source key")
    _require(
        scope.get("localRootDistributable") is False,
        "source scan must preserve the non-distributable local-root boundary",
    )
    course_filters = scope.get("courseFilters")
    _require(
        isinstance(course_filters, list) and len(course_filters) == 1,
        "task planning requires one course-scoped source scan",
    )
    course = str(course_filters[0])
    _require(re.fullmatch(r"[0-9]{2}", course) is not None, "invalid course filter")
    _require(
        isinstance(scan.get("sourceDocuments"), list),
        "sourceDocuments must be an array",
    )
    _require(isinstance(scan.get("sourceAtoms"), list), "sourceAtoms must be an array")
    _require(
        isinstance(scan.get("hierarchyNodes"), list),
        "hierarchyNodes must be an array",
    )
    parser = scan.get("parser")
    _require(isinstance(parser, dict), "source scan parser receipt is missing")
    _require(
        parser.get("name") == "synapse-static-source-atomizer"
        and parser.get("version") == "1.1.1",
        "source scan must use the static Markdown and TypeScript atomizer v1.1.1",
    )
    _require(
        "never-executed" in str(parser.get("typescriptPolicy", "")),
        "source scan does not prove the no-execution TypeScript boundary",
    )
    summary = scan.get("summary")
    _require(isinstance(summary, dict), "source scan summary is missing")
    _require(
        int(summary.get("quarantinedDocumentCount", -1)) == 0,
        "source scan contains quarantined documents and cannot enter task planning",
    )
    document_coverage = scan.get("documentCoverage")
    _require(
        isinstance(document_coverage, list),
        "source scan documentCoverage is missing",
    )
    coverage_by_document = {
        str(item.get("sourceDocumentId")): item
        for item in document_coverage
        if isinstance(item, dict)
    }
    for document in scan["sourceDocuments"]:
        if not isinstance(document, dict):
            raise PlanningError("source document must be an object")
        if not str(document.get("detectedMime", "")).startswith("text/"):
            continue
        document_id = str(document.get("id", ""))
        coverage = coverage_by_document.get(document_id)
        _require(coverage is not None, f"text document has no coverage receipt: {document_id}")
        _require(
            coverage.get("allNonWhitespaceSourceRepresentedByDocumentAtoms") is True,
            f"text document has incomplete lexical coverage: {document_id}",
        )
        _require(
            int(coverage.get("atomCount", 0)) > 0,
            f"text document has no source atoms: {document_id}",
        )
    _require(
        re.fullmatch(r"[a-f0-9]{64}", str(scan.get("sourceTreeSha256", "")))
        is not None,
        "sourceTreeSha256 is invalid",
    )
    return course


def _aggregate_scan(
    scan: dict[str, Any], course: str
) -> tuple[list[dict[str, Any]], dict[str, Any], dict[str, int]]:
    course_key = f"harrison-sim/course/{course}"
    chapters: dict[str, dict[str, Any]] = {}
    document_chapter: dict[str, str | None] = {}

    for node in scan["hierarchyNodes"]:
        if not isinstance(node, dict):
            raise PlanningError("hierarchy node must be an object")
        kind = node.get("kind")
        if kind == "chapter":
            key = str(node.get("sourceKey", ""))
            _require(
                key.startswith(f"{course_key}/chapter/"),
                f"chapter outside course scope: {key}",
            )
            _require(key not in chapters, f"duplicate chapter key: {key}")
            ordinal = node.get("ordinal")
            _require(isinstance(ordinal, int) and ordinal > 0, f"invalid ordinal: {key}")
            chapters[key] = {
                "chapterSourceKey": key,
                "ordinal": ordinal,
                "directoryName": str(node.get("directoryName", "")),
                "counts": _empty_counts(chapters=1),
            }

    _require(chapters, "source scan contains no chapters")

    for node in scan["hierarchyNodes"]:
        if isinstance(node, dict) and node.get("kind") == "source_lesson":
            parent = str(node.get("parentSourceKey", ""))
            _require(parent in chapters, f"source lesson has unknown chapter: {parent}")
            chapters[parent]["counts"]["sourceLessons"] += 1

    global_counts = _empty_counts()
    global_document_ids: list[str] = []
    global_atom_ids: list[str] = []

    for document in scan["sourceDocuments"]:
        if not isinstance(document, dict):
            raise PlanningError("source document must be an object")
        document_id = str(document.get("id", ""))
        _require(document_id != "", "source document ID is missing")
        _require(document_id not in document_chapter, f"duplicate document ID: {document_id}")
        chapter_key_value = document.get("chapterSourceKey")
        chapter_key = str(chapter_key_value) if chapter_key_value is not None else None
        if (
            document.get("artifactRole") == "part_index"
            or chapter_key == f"{course_key}/chapter/index"
        ):
            chapter_key = None
        if chapter_key is not None:
            _require(
                chapter_key in chapters,
                f"document references unknown chapter: {document_id} -> {chapter_key}",
            )
            counts = chapters[chapter_key]["counts"]
        else:
            counts = global_counts
            global_document_ids.append(document_id)
        document_chapter[document_id] = chapter_key
        counts["documents"] += 1
        if str(document.get("detectedMime", "")).startswith("image/"):
            counts["mediaDocuments"] += 1

    seen_atom_ids: set[str] = set()
    for atom in scan["sourceAtoms"]:
        if not isinstance(atom, dict):
            raise PlanningError("source atom must be an object")
        atom_id = str(atom.get("id", ""))
        document_id = str(atom.get("sourceDocumentId", ""))
        _require(atom_id != "", "source atom ID is missing")
        _require(atom_id not in seen_atom_ids, f"duplicate source atom ID: {atom_id}")
        _require(
            document_id in document_chapter,
            f"atom references unknown document: {atom_id} -> {document_id}",
        )
        seen_atom_ids.add(atom_id)
        chapter_key = document_chapter[document_id]
        counts = chapters[chapter_key]["counts"] if chapter_key else global_counts
        if chapter_key is None:
            global_atom_ids.append(atom_id)
        counts["atoms"] += 1
        disposition = atom.get("instructionalDisposition")
        if disposition == "required":
            counts["requiredAtoms"] += 1
        elif disposition == "duplicate_required":
            counts["duplicateRequiredAtoms"] += 1
        elif disposition == "non_instructional":
            counts["nonInstructionalAtoms"] += 1
        else:
            raise PlanningError(f"unclassified source atom: {atom_id}")
        risk_tier = atom.get("riskTier")
        if risk_tier == "clinical_high":
            counts["clinicalHighAtoms"] += 1
        elif risk_tier == "safety_critical":
            counts["safetyCriticalAtoms"] += 1
        if atom.get("atomType") == "warning":
            counts["warningAtoms"] += 1

    for chapter in chapters.values():
        chapter["counts"]["planningWeight"] = _planning_weight(chapter["counts"])
    global_counts["planningWeight"] = _planning_weight(global_counts)

    ordered_chapters = sorted(chapters.values(), key=lambda item: item["ordinal"])
    course_totals = _empty_counts()
    _add_counts(course_totals, global_counts)
    for chapter in ordered_chapters:
        _add_counts(course_totals, chapter["counts"])

    summary = scan.get("summary", {})
    if isinstance(summary, dict):
        _require(
            course_totals["chapters"] == int(summary.get("chapterCount", -1)),
            "chapter count does not reconcile with scan summary",
        )
        _require(
            course_totals["documents"] == int(summary.get("fileCount", -1)),
            "document count does not reconcile with scan summary",
        )
        _require(
            course_totals["atoms"] == int(summary.get("atomCount", -1)),
            "atom count does not reconcile with scan summary",
        )

    global_artifacts = {
        "documentIds": sorted(global_document_ids),
        "sourceAtomIds": sorted(global_atom_ids),
        "counts": global_counts,
        "disposition": "course_level_review_before_chapter_merge",
    }
    return ordered_chapters, global_artifacts, course_totals


def _balance_lanes(
    chapters: list[dict[str, Any]], shard_count: int
) -> list[dict[str, Any]]:
    _require(1 <= shard_count <= MAX_SHARDS, f"shards must be between 1 and {MAX_SHARDS}")
    _require(
        shard_count <= len(chapters),
        "shard count cannot exceed the number of chapters",
    )
    lanes = [
        {
            "id": f"lane-{ordinal:02d}",
            "ordinal": ordinal,
            "counts": _empty_counts(),
            "chapters": [],
        }
        for ordinal in range(1, shard_count + 1)
    ]
    work_queue = sorted(
        chapters,
        key=lambda item: (-item["counts"]["planningWeight"], item["ordinal"]),
    )
    for chapter in work_queue:
        lane = min(
            lanes,
            key=lambda item: (item["counts"]["planningWeight"], item["ordinal"]),
        )
        lane["chapters"].append(chapter)
        _add_counts(lane["counts"], chapter["counts"])
    for lane in lanes:
        lane["chapters"].sort(key=lambda item: item["ordinal"])
    return lanes


def _pilot_reason(chapter: dict[str, Any]) -> str:
    counts = chapter["counts"]
    segmentation = (
        "explicitly segmented"
        if counts["sourceLessons"] > 0
        else "unsegmented and requiring reviewed decomposition"
    )
    return (
        f"{segmentation}; {counts['mediaDocuments']} media documents, "
        f"{counts['atoms']} source atoms, {counts['clinicalHighAtoms']} clinical-high "
        f"atoms, {counts['warningAtoms']} warning atoms, and "
        f"{counts['safetyCriticalAtoms']} safety-critical atoms exercise the hard "
        "content, coverage, bilingual, evidence, and session-budget gates."
    )


def _phase_templates() -> list[dict[str, Any]]:
    return [
        {
            "id": "atom_review_and_decomposition",
            "purpose": (
                "Review every source document and atom disposition, resolve duplicates and "
                "findings, build claims/evidence candidates, and propose the fine-grained "
                "Unit to Session topology without authoring learner-visible bodies."
            ),
            "promptTemplate": "tool/jules/prompts/atom_review_and_decomposition.md",
            "inputAuthority": (
                "Exact source scan, source bytes visible at the approved remote revision, "
                "content contract, and authoring policy."
            ),
            "outputOwnership": (
                "One chapter-scoped decomposition draft and coverage ledger; no other "
                "chapter or shared registry may be edited."
            ),
            "dependsOn": [],
            "authoringCapabilities": [],
            "acceptance": [
                "100% chapter documents and atoms receive a reviewed disposition",
                "no source TypeScript is executed",
                "every proposed split preserves source-atom lineage",
                "no learner-visible content or publication state is created",
            ],
        },
        {
            "id": "integrated_bilingual_authoring",
            "purpose": (
                "Author approved short EN/FA session pairs containing lesson instruction, "
                "embedded quiz interactions with complete feedback, and optional bounded "
                "reinforcement recap; never create a specialist or Enrich stage."
            ),
            "promptTemplate": "tool/jules/prompts/integrated_bilingual_authoring.md",
            "inputAuthority": (
                "Approved chapter decomposition, locale-neutral semantic skeleton, claims, "
                "evidence candidates, source atoms, content contract, and authoring policy."
            ),
            "outputOwnership": (
                "Only the assigned immutable session-pair draft IDs and their chapter-local "
                "coverage edges; shared registries remain read-only."
            ),
            "dependsOn": ["atom_review_and_decomposition"],
            "authoringCapabilities": [
                "lesson_writing",
                "embedded_quiz_writing",
                "bounded_reinforcement_summary",
            ],
            "acceptance": [
                "English and Persian are authored together from one semantic skeleton",
                "all session and interaction budgets pass in both locales",
                "every distractor has complete why-wrong feedback",
                "recap introduces no new claim and carries no primary coverage",
                "outputs remain raw drafts with no self-approval or publication",
            ],
        },
        {
            "id": "independent_content_validation",
            "purpose": (
                "Independently validate coverage, provenance, EN/FA parity, evidence, "
                "medical safety, accessibility, assessment quality, and monotony without "
                "silently rewriting the authored artifact."
            ),
            "promptTemplate": "tool/jules/prompts/independent_content_validation.md",
            "inputAuthority": (
                "Exact authored artifact hashes, source/decomposition receipts, content "
                "contract, authoring policy, and reviewer assignment."
            ),
            "outputOwnership": (
                "Validation findings and receipts only; authoring outputs are read-only and "
                "blocking defects return to the author as explicit findings."
            ),
            "dependsOn": ["integrated_bilingual_authoring"],
            "authoringCapabilities": [],
            "acceptance": [
                "all required 100% metrics reconcile",
                "all zero-tolerance counts are zero",
                "review identities are independent of author and generator",
                "validation does not activate a learner-visible channel",
            ],
        },
    ]


def _gates() -> list[dict[str, str]]:
    return [
        {
            "id": "rights_clearance",
            "state": "blocked",
            "evidenceRequired": (
                "Explicit text and media rights clearance for external model processing "
                "and the intended distribution boundary."
            ),
        },
        {
            "id": "exact_remote_revision",
            "state": "blocked",
            "evidenceRequired": (
                "Exact connected Jules source resource, starting branch, and immutable "
                "commit SHA approved for the content run."
            ),
        },
        {
            "id": "remote_inputs_visible",
            "state": "blocked",
            "evidenceRequired": (
                "Every source fragment, contract, prompt, and schema referenced by a task "
                "exists at the approved remote commit."
            ),
        },
        {
            "id": "task_prompt_review",
            "state": "pending",
            "evidenceRequired": "Human review of exact prompts, task ownership, and acceptance gates.",
        },
        {
            "id": "non_overlapping_chapter_ownership",
            "state": "pass",
            "evidenceRequired": "Deterministic whole-chapter lane reconciliation in this plan.",
        },
        {
            "id": "secret_and_phi_scan",
            "state": "pending",
            "evidenceRequired": "Zero secrets and PHI in the exact remote task inputs and logs.",
        },
        {
            "id": "quota_and_concurrency_snapshot",
            "state": "pending",
            "evidenceRequired": "Fresh account-wide Jules Pro rolling-24-hour and active-session snapshot.",
        },
        {
            "id": "policy_schema",
            "state": "pass",
            "evidenceRequired": "Authoring policy validated against its Draft 2020-12 schema.",
        },
        {
            "id": "source_scan_contract",
            "state": "pass",
            "evidenceRequired": "Source scan reconciles chapter, document, atom, and disposition counts.",
        },
        {
            "id": "source_scan_recheck",
            "state": "pending",
            "evidenceRequired": "Check-mode regeneration against the exact source snapshot before activation.",
        },
        {
            "id": "medical_review_ownership",
            "state": "pending",
            "evidenceRequired": "Named independent medical reviewers for the exact release scope.",
        },
        {
            "id": "native_persian_review_ownership",
            "state": "pending",
            "evidenceRequired": "Named native Persian reviewer independent from the generator.",
        },
        {
            "id": "publisher_separation",
            "state": "pending",
            "evidenceRequired": "Publisher identity differs from author and generator identities.",
        },
    ]


def _validate_plan_semantics(plan: dict[str, Any]) -> None:
    lanes = plan["lanes"]
    chapter_keys = [
        chapter["chapterSourceKey"]
        for lane in lanes
        for chapter in lane["chapters"]
    ]
    _require(len(chapter_keys) == len(set(chapter_keys)), "chapter assigned more than once")
    _require(
        len(chapter_keys) == plan["courseTotals"]["chapters"],
        "not every chapter is assigned to exactly one lane",
    )
    reconciled = _empty_counts()
    _add_counts(reconciled, plan["globalArtifacts"]["counts"])
    for lane in lanes:
        expected = _empty_counts()
        for chapter in lane["chapters"]:
            _add_counts(expected, chapter["counts"])
        _require(expected == lane["counts"], f"lane counts drifted: {lane['id']}")
        _add_counts(reconciled, lane["counts"])
    _require(reconciled == plan["courseTotals"], "course totals do not reconcile")
    phase_ids = [phase["id"] for phase in plan["phaseTemplates"]]
    _require(
        phase_ids
        == [
            "atom_review_and_decomposition",
            "integrated_bilingual_authoring",
            "independent_content_validation",
        ],
        "phase order drifted",
    )
    authoring_phase = plan["phaseTemplates"][1]
    _require(
        authoring_phase["authoringCapabilities"]
        == [
            "lesson_writing",
            "embedded_quiz_writing",
            "bounded_reinforcement_summary",
        ],
        "integrated authoring capabilities drifted",
    )
    serialized = json.dumps(plan, ensure_ascii=False, sort_keys=True)
    forbidden_raw_keys = ("sourceRoot", "absolutePath", "rawText", "sourceText")
    _require(
        all(f'"{key}"' not in serialized for key in forbidden_raw_keys),
        "plan leaked raw/local source material",
    )


def build_plan(
    *,
    source_scan_path: Path,
    policy_path: Path,
    policy_schema_path: Path,
    shard_count: int,
    pilot_ordinals: Sequence[int],
) -> dict[str, Any]:
    scan = _read_json(source_scan_path)
    policy = _read_json(policy_path)
    _validate_policy(policy, policy_schema_path)
    course = _validate_source_scan(scan)
    chapters, global_artifacts, course_totals = _aggregate_scan(scan, course)
    lanes = _balance_lanes(chapters, shard_count)
    chapter_by_ordinal = {chapter["ordinal"]: chapter for chapter in chapters}
    _require(len(pilot_ordinals) >= 2, "pilot requires at least two chapters")
    _require(
        len(pilot_ordinals) == len(set(pilot_ordinals)),
        "pilot chapter ordinals must be unique",
    )
    missing = [ordinal for ordinal in pilot_ordinals if ordinal not in chapter_by_ordinal]
    _require(not missing, f"pilot chapters missing from scan: {missing}")
    pilot_chapters = [chapter_by_ordinal[ordinal] for ordinal in pilot_ordinals]
    policy_sha256 = _sha256_file(policy_path)
    source_scan_sha256 = _sha256_file(source_scan_path)
    source_tree_sha256 = str(scan["sourceTreeSha256"])
    plan = {
        "$schema": TASK_PLAN_SCHEMA,
        "schemaVersion": 1,
        "planId": (
            f"content-plan.course-{course}.{source_tree_sha256[:12]}."
            f"{source_scan_sha256[:12]}.{policy_sha256[:12]}"
        ),
        "status": "blocked_external_processing",
        "generator": {
            "name": GENERATOR_NAME,
            "version": GENERATOR_VERSION,
            "algorithm": GENERATOR_ALGORITHM,
        },
        "source": {
            "sourceKey": "harrison-sim",
            "courseSourceKey": f"harrison-sim/course/{course}",
            "sourceScanManifestId": str(scan["manifestId"]),
            "sourceTreeSha256": source_tree_sha256,
            "sourceScanSha256": source_scan_sha256,
            "localRootDistributable": False,
        },
        "policy": {
            "policyId": policy["policyId"],
            "policySha256": policy_sha256,
            "allowedAuthoringCapabilities": policy["capabilityBoundary"][
                "allowedAuthoringCapabilities"
            ],
            "forbiddenProductionStages": policy["capabilityBoundary"][
                "forbiddenProductionStages"
            ],
        },
        "executionBoundary": {
            "remoteMutationAllowed": False,
            "julesManifestEmitted": False,
            "rawSourceTextIncluded": False,
            "automaticPullRequest": False,
            "planApprovalRequired": True,
            "maxConcurrentTasks": 15,
            "maxRolling24HourTasks": 100,
            "schedulerProfile": "pro",
        },
        "courseTotals": course_totals,
        "globalArtifacts": global_artifacts,
        "pilot": {
            "chapterSourceKeys": [chapter["chapterSourceKey"] for chapter in pilot_chapters],
            "selectionReasons": {
                chapter["chapterSourceKey"]: _pilot_reason(chapter)
                for chapter in pilot_chapters
            },
            "requiredContentClasses": [
                "mechanism_heavy",
                "signal_or_image_interpretation",
                "management_or_safety",
            ],
            "sequence": [
                "atom_review_and_decomposition",
                "integrated_bilingual_authoring",
                "independent_content_validation",
            ],
            "state": "planned_not_submitted",
        },
        "phaseTemplates": _phase_templates(),
        "lanes": lanes,
        "gates": _gates(),
    }
    _validate_plan_semantics(plan)
    return plan


def canonical_bytes(plan: dict[str, Any]) -> bytes:
    return (json.dumps(plan, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode(
        "utf-8"
    )


def _atomic_write(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _pilot_values(value: str) -> tuple[int, ...]:
    items = [item.strip() for item in value.split(",") if item.strip()]
    if not items:
        raise argparse.ArgumentTypeError("pilot chapter list cannot be empty")
    values: list[int] = []
    for item in items:
        if re.fullmatch(r"[0-9]{1,3}", item) is None:
            raise argparse.ArgumentTypeError(f"invalid pilot chapter ordinal: {item}")
        values.append(int(item))
    if len(values) != len(set(values)):
        raise argparse.ArgumentTypeError("pilot chapter ordinals must be unique")
    return tuple(values)


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Create a deterministic, raw-text-free and rights-gated Jules content task "
            "plan. This command never calls Jules and never emits a Jules batch manifest."
        )
    )
    parser.add_argument("--source-scan", type=Path, required=True)
    parser.add_argument("--policy", type=Path, default=_default_policy_path())
    parser.add_argument(
        "--policy-schema", type=Path, default=_default_policy_schema_path()
    )
    parser.add_argument("--plan-schema", type=Path, default=_default_plan_schema_path())
    parser.add_argument("--shards", type=int, default=15)
    parser.add_argument(
        "--pilot-chapters",
        type=_pilot_values,
        default=DEFAULT_PILOT_CHAPTERS,
        help="comma-separated chapter ordinals; defaults to 006,054",
    )
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument("--output", type=Path)
    destination.add_argument("--check", type=Path)
    parser.add_argument("--json-summary", action="store_true")
    return parser.parse_args(argv)


def _summary(plan: dict[str, Any], plan_sha256: str) -> dict[str, Any]:
    lane_weights = [lane["counts"]["planningWeight"] for lane in plan["lanes"]]
    return {
        "status": "pass",
        "planId": plan["planId"],
        "planSha256": plan_sha256,
        "executionState": plan["status"],
        "chapters": plan["courseTotals"]["chapters"],
        "documents": plan["courseTotals"]["documents"],
        "atoms": plan["courseTotals"]["atoms"],
        "shards": len(plan["lanes"]),
        "minimumLaneWeight": min(lane_weights),
        "maximumLaneWeight": max(lane_weights),
        "pilotChapters": plan["pilot"]["chapterSourceKeys"],
        "remoteMutationAllowed": False,
        "julesManifestEmitted": False,
        "rawSourceTextIncluded": False,
    }


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        plan = build_plan(
            source_scan_path=args.source_scan.resolve(),
            policy_path=args.policy.resolve(),
            policy_schema_path=args.policy_schema.resolve(),
            shard_count=args.shards,
            pilot_ordinals=args.pilot_chapters,
        )
        _validate_with_schema(plan, args.plan_schema.resolve())
        payload = canonical_bytes(plan)
        plan_sha256 = _sha256_bytes(payload)
        if args.check is not None:
            expected = args.check.resolve()
            try:
                existing = expected.read_bytes()
            except FileNotFoundError as exc:
                raise PlanningError(f"check target is missing: {expected}") from exc
            if existing != payload:
                raise PlanningError(
                    "task plan drift: "
                    f"expected {_sha256_bytes(existing)}, generated {plan_sha256}"
                )
        else:
            _atomic_write(args.output.resolve(), payload)
        summary = _summary(plan, plan_sha256)
        if args.json_summary:
            print(json.dumps(summary, ensure_ascii=False, sort_keys=True, indent=2))
        else:
            print(
                "Content task plan PASS: "
                f"{summary['chapters']} chapters, {summary['documents']} documents, "
                f"{summary['atoms']} atoms, {summary['shards']} shards, "
                f"plan {plan_sha256}"
            )
        return 0
    except PlanningError as exc:
        print(f"Content task plan FAIL: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
