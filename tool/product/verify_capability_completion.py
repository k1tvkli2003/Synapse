#!/usr/bin/env python3
"""Verify full capability coverage and prevent evidence-free completion."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PRESERVATION_PATH = ROOT / "contracts/preservation/capability-ledger.v1.json"
LANGUAGE_POLICY_PATH = ROOT / "contracts/integrity/product-language-policy.v1.json"
DATA_PLANE_PATH = ROOT / "contracts/product/data-plane.v1.json"
NEW_CAPABILITIES_PATH = ROOT / "contracts/product/new-capability-registry.v1.json"
EVIDENCE_PATH = ROOT / "contracts/product/capability-evidence.v1.json"
COMPLETION_PATH = ROOT / "contracts/product/capability-completion.v1.json"
REPORT_PATH = ROOT / "contracts/product/capability-completion-verification.v1.json"

CAPABILITY_STATUSES = {
    "planned",
    "active",
    "blocked",
    "verified",
    "retired_authorized",
}
GATE_STATUSES = {"planned", "active", "blocked", "verified", "not_applicable"}
CONCERN_STATUSES = {"planned", "active", "blocked", "verified", "not_applicable"}
EXPOSURES = {
    "primary_destination",
    "dedicated_workflow",
    "embedded_section",
    "contextual_surface",
    "background_service",
    "system_surface",
    "migration_only",
}
LEGACY_BRAND = re.compile(r"study[\s_.-]*hub", re.IGNORECASE)


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _issue(
    issues: list[dict[str, str]],
    code: str,
    message: str,
    capability_id: str | None = None,
) -> None:
    issue = {"code": code, "message": message}
    if capability_id is not None:
        issue["capabilityId"] = capability_id
    issues.append(issue)


def _nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip()) and value == value.strip()


def verify_document(
    completion: dict[str, Any],
    preservation: dict[str, Any],
    language_policy: dict[str, Any],
    data_plane: dict[str, Any],
    new_capabilities: dict[str, Any],
) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    source_by_id = {
        entry["id"]: entry
        for entry in [*preservation["entries"], *new_capabilities["entries"]]
    }
    expected_ids = set(source_by_id)
    policy_by_id = {
        entry["sourceId"]: entry for entry in language_policy["capabilityMap"]
    }
    concern_ids = [concern["id"] for concern in data_plane["concerns"]]
    profile_by_id = {profile["id"]: profile for profile in data_plane["profiles"]}
    gate_ids = [gate["id"] for gate in completion.get("gateProfile", {}).get("gates", [])]

    if completion.get("schemaVersion") != 1:
        _issue(issues, "schema_version", "Completion schemaVersion must be 1.")
    if completion.get("contractId") != "synapse.capability-completion.v1":
        _issue(issues, "contract_id", "Unexpected completion contractId.")
    if len(concern_ids) != 15 or len(set(concern_ids)) != 15:
        _issue(issues, "data_plane_concerns", "Data Plane must define 15 unique concerns.")
    if len(gate_ids) != 14 or len(set(gate_ids)) != 14:
        _issue(issues, "masterpiece_gates", "Masterpiece profile must define 14 unique gates.")

    entries = completion.get("entries")
    if not isinstance(entries, list):
        _issue(issues, "entries_type", "entries must be an array.")
        return issues

    actual_ids = [entry.get("capabilityId") for entry in entries]
    if len(actual_ids) != len(set(actual_ids)):
        _issue(issues, "duplicate_capability", "Capability IDs must be unique.")
    if set(actual_ids) != expected_ids:
        missing = sorted(expected_ids - set(actual_ids))
        extra = sorted(set(actual_ids) - expected_ids)
        _issue(
            issues,
            "capability_coverage",
            f"Capability coverage drift. missing={missing} extra={extra}",
        )

    analytics_names: list[str] = []
    status_counts = {status: 0 for status in CAPABILITY_STATUSES}
    for entry in entries:
        capability_id = entry.get("capabilityId")
        if capability_id not in source_by_id:
            continue
        source = source_by_id[capability_id]
        provenance = entry.get("provenance", {})
        baseline = entry.get("baseline", {})
        product = entry.get("product", {})
        data = entry.get("dataPlane", {})
        experience = entry.get("experience", {})
        delivery = entry.get("delivery", {})

        expected_provenance = {
            "sourceOwner": source["currentOwner"],
            "sourceDocument": source["source"],
            "sourceSection": source["sourceSection"],
            "sourceRow": source["sourceRow"],
        }
        if provenance != expected_provenance:
            _issue(issues, "provenance_drift", "Preservation provenance drifted.", capability_id)
        if baseline.get("state") != source["baselineState"]:
            _issue(issues, "baseline_drift", "Baseline state drifted.", capability_id)
        if baseline.get("preservationRule") != source["preservation"]:
            _issue(issues, "preservation_rule", "Preservation rule drifted.", capability_id)

        required_product_fields = (
            "domain",
            "surface",
            "userFacingLabel",
            "entryContext",
            "analyticsNamespace",
            "exposure",
            "capabilityIntent",
            "placementIntent",
        )
        for field in required_product_fields:
            if not _nonempty_string(product.get(field)):
                _issue(issues, "product_field", f"product.{field} is required.", capability_id)
        if LEGACY_BRAND.search(json.dumps(product, ensure_ascii=False)):
            _issue(issues, "legacy_brand_leak", "Legacy source branding leaked into product fields.", capability_id)
        exposure = product.get("exposure")
        if exposure not in EXPOSURES:
            _issue(issues, "exposure", f"Unknown exposure {exposure!r}.", capability_id)
        page = product.get("pageDecision", {})
        if not isinstance(page.get("standalonePageEarned"), bool) or not _nonempty_string(page.get("rationale")):
            _issue(issues, "page_decision", "Page decision requires a boolean and rationale.", capability_id)
        should_be_earned = exposure in {"primary_destination", "dedicated_workflow"}
        if page.get("standalonePageEarned") != should_be_earned:
            _issue(issues, "page_sprawl", "Standalone-page decision conflicts with exposure class.", capability_id)
        analytics_names.append(product.get("analyticsNamespace"))

        if capability_id in policy_by_id:
            policy = policy_by_id[capability_id]
            for completion_field, policy_field in (
                ("domain", "canonicalDomain"),
                ("surface", "surface"),
                ("userFacingLabel", "userFacingLabel"),
                ("entryContext", "entryContext"),
                ("analyticsNamespace", "analyticsNamespace"),
            ):
                if product.get(completion_field) != policy[policy_field]:
                    _issue(issues, "language_policy_drift", f"product.{completion_field} drifted from naming policy.", capability_id)

        profile_id = data.get("profileId")
        if profile_id not in profile_by_id:
            _issue(issues, "data_profile", f"Unknown Data Plane profile {profile_id!r}.", capability_id)
        else:
            if data.get("entityFamilies") != profile_by_id[profile_id]["entityFamilies"]:
                _issue(issues, "entity_family_drift", "Entity families drifted from Data Plane profile.", capability_id)
            if data.get("truthAuthority") != profile_by_id[profile_id]["truthAuthority"]:
                _issue(issues, "truth_authority_drift", "Truth authority drifted from Data Plane profile.", capability_id)
        concern_state = data.get("concerns", {})
        if set(concern_state) != set(concern_ids):
            _issue(issues, "concern_coverage", "All 15 Data Plane concerns are required.", capability_id)
        for concern_id, status in concern_state.items():
            if status not in CONCERN_STATUSES:
                _issue(issues, "concern_status", f"Invalid {concern_id} status {status!r}.", capability_id)
        if data.get("entitySchemaStatus") not in CONCERN_STATUSES:
            _issue(issues, "entity_schema_status", "Entity schema requires an allowed status.", capability_id)

        if experience.get("locales") != ["en", "fa"]:
            _issue(issues, "locale_parity", "Every capability requires EN and FA.", capability_id)
        if experience.get("directions") != ["ltr", "rtl"]:
            _issue(issues, "direction_parity", "Every capability requires LTR and RTL.", capability_id)
        if set(experience.get("motionModes", [])) != {"full", "reduced", "off"}:
            _issue(issues, "motion_modes", "Full, Reduced, and Off are required.", capability_id)
        if set(experience.get("inputModes", [])) != {"touch", "pointer", "keyboard", "screen_reader"}:
            _issue(issues, "input_modes", "Touch, pointer, keyboard, and screen reader are required.", capability_id)
        if set(experience.get("viewportClasses", [])) != {"compact", "medium", "expanded", "wide"}:
            _issue(issues, "viewports", "Compact, medium, expanded, and wide are required.", capability_id)
        if experience.get("nightShiftRequired") is not True:
            _issue(issues, "night_shift", "Night Shift is required.", capability_id)
        if not experience.get("requiredStates"):
            _issue(issues, "state_matrix", "A required state matrix is mandatory.", capability_id)

        completion_status = delivery.get("completionStatus")
        if completion_status not in CAPABILITY_STATUSES:
            _issue(issues, "completion_status", f"Invalid completion status {completion_status!r}.", capability_id)
        else:
            status_counts[completion_status] += 1
        if not _nonempty_string(delivery.get("verificationOwner")):
            _issue(issues, "verification_owner", "A verification owner is required.", capability_id)
        gates = delivery.get("gates", {})
        if set(gates) != set(gate_ids):
            _issue(issues, "gate_coverage", "All 14 masterpiece gates are required.", capability_id)
        for gate_id, gate in gates.items():
            gate_status = gate.get("status")
            if gate_status not in GATE_STATUSES:
                _issue(issues, "gate_status", f"Invalid {gate_id} status {gate_status!r}.", capability_id)
            if gate_status == "verified" and not gate.get("evidence"):
                _issue(issues, "gate_evidence", f"Verified gate {gate_id} has no evidence.", capability_id)
            if gate_status == "not_applicable" and (
                not gate.get("evidence") or not _nonempty_string(gate.get("rationale"))
            ):
                _issue(issues, "gate_not_applicable", f"N/A gate {gate_id} needs evidence and rationale.", capability_id)

        if completion_status == "verified":
            unresolved_gates = [
                gate_id
                for gate_id, gate in gates.items()
                if gate.get("status") not in {"verified", "not_applicable"}
            ]
            unresolved_concerns = [
                concern_id
                for concern_id, status in concern_state.items()
                if status not in {"verified", "not_applicable"}
            ]
            if unresolved_gates or unresolved_concerns or data.get("entitySchemaStatus") != "verified":
                _issue(
                    issues,
                    "false_done",
                    f"Verified capability has unresolved gates={unresolved_gates}, concerns={unresolved_concerns}, or entity schema.",
                    capability_id,
                )
        if completion_status == "retired_authorized" and not delivery.get("retirementAuthorization"):
            _issue(issues, "retirement_authority", "Retirement requires explicit user authorization evidence.", capability_id)

    if len(analytics_names) != len(set(analytics_names)):
        _issue(issues, "analytics_namespace", "Analytics namespaces must be unique.")

    summary = completion.get("summary", {})
    expected_summary = {
        "expectedCapabilities": len(expected_ids),
        "planned": status_counts["planned"],
        "active": status_counts["active"],
        "blocked": status_counts["blocked"],
        "verified": status_counts["verified"],
        "retiredAuthorized": status_counts["retired_authorized"],
    }
    if summary != expected_summary:
        _issue(issues, "summary_drift", f"Summary must equal {expected_summary}.")
    return issues


def verify_source_receipts(completion: dict[str, Any]) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    receipts = {receipt["path"]: receipt["sha256"] for receipt in completion.get("sources", [])}
    expected_paths = (
        PRESERVATION_PATH,
        LANGUAGE_POLICY_PATH,
        DATA_PLANE_PATH,
        NEW_CAPABILITIES_PATH,
        EVIDENCE_PATH,
    )
    for path in expected_paths:
        relative = str(path.relative_to(ROOT)).replace("\\", "/")
        if receipts.get(relative) != _sha256(path):
            _issue(issues, "source_receipt", f"Source receipt drifted for {relative}.")
    return issues


def build_report(issues: list[dict[str, str]], completion: dict[str, Any]) -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "contractId": "synapse.capability-completion-verification.v1",
        "status": "pass" if not issues else "fail",
        "capabilityCount": len(completion.get("entries", [])),
        "verifiedCount": sum(
            1
            for entry in completion.get("entries", [])
            if entry.get("delivery", {}).get("completionStatus") == "verified"
        ),
        "issueCount": len(issues),
        "issues": issues,
        "inputs": {
            str(COMPLETION_PATH.relative_to(ROOT)).replace("\\", "/"): _sha256(COMPLETION_PATH),
            str(PRESERVATION_PATH.relative_to(ROOT)).replace("\\", "/"): _sha256(PRESERVATION_PATH),
            str(LANGUAGE_POLICY_PATH.relative_to(ROOT)).replace("\\", "/"): _sha256(LANGUAGE_POLICY_PATH),
            str(DATA_PLANE_PATH.relative_to(ROOT)).replace("\\", "/"): _sha256(DATA_PLANE_PATH),
            str(NEW_CAPABILITIES_PATH.relative_to(ROOT)).replace("\\", "/"): _sha256(NEW_CAPABILITIES_PATH),
            str(EVIDENCE_PATH.relative_to(ROOT)).replace("\\", "/"): _sha256(EVIDENCE_PATH),
        },
    }


def main() -> int:
    completion = _load(COMPLETION_PATH)
    issues = verify_document(
        completion,
        _load(PRESERVATION_PATH),
        _load(LANGUAGE_POLICY_PATH),
        _load(DATA_PLANE_PATH),
        _load(NEW_CAPABILITIES_PATH),
    )
    issues.extend(verify_source_receipts(completion))
    report = build_report(issues, completion)
    REPORT_PATH.write_text(
        json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(
        f"capability completion: {report['status']} | "
        f"records={report['capabilityCount']} verified={report['verifiedCount']} "
        f"issues={report['issueCount']}"
    )
    for issue in issues:
        suffix = f" [{issue['capabilityId']}]" if "capabilityId" in issue else ""
        print(f"- {issue['code']}{suffix}: {issue['message']}")
    return 0 if not issues else 1


if __name__ == "__main__":
    sys.exit(main())
