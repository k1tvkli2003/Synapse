#!/usr/bin/env python3
"""Generate the conservative Synapse capability-completion ledger.

The preservation ledger remains the no-loss authority. This generator joins it
to functional product placement, the shared Data Plane, and the full
masterpiece gate. It intentionally emits zero verified capabilities: evidence,
not generation, is allowed to advance completion.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PRESERVATION_PATH = ROOT / "contracts/preservation/capability-ledger.v1.json"
LANGUAGE_POLICY_PATH = ROOT / "contracts/integrity/product-language-policy.v1.json"
DATA_PLANE_PATH = ROOT / "contracts/product/data-plane.v1.json"
NEW_CAPABILITIES_PATH = ROOT / "contracts/product/new-capability-registry.v1.json"
EVIDENCE_PATH = ROOT / "contracts/product/capability-evidence.v1.json"
OUTPUT_PATH = ROOT / "contracts/product/capability-completion.v1.json"


GATES: tuple[tuple[str, str], ...] = (
    ("purpose", "User, job, context, measurable outcome, risk, and non-goals are explicit."),
    ("placement", "Entry surfaces and page-sprawl decision are intentional and evidence-backed."),
    ("workflow", "First use, happy path, resume, cancel, undo, partial completion, and recovery are complete."),
    ("visual_craft", "Night Shift composition, hierarchy, density, type, imagery, mascot role, and semantic color are approved."),
    ("state_completeness", "Applicable loading, empty, stale, offline, permission, partial, conflict, error, retry, success, and recovery states exist."),
    ("responsive_input", "Compact through wide layouts plus touch, pointer, keyboard, rotation, safe-area, and multi-window behavior are proven."),
    ("localization_rtl", "English, Persian, RTL, long strings, locale formatting, bidi safety, and text scaling are proven."),
    ("accessibility", "Semantics, focus, keyboard, screen reader, target size, contrast, color independence, and cognitive access are proven."),
    ("motion_feedback", "Full, Reduced, and Off motion plus interruption, receipts, fallback, sound, and haptic semantics are proven."),
    ("data_plane", "Canonical entities and all shared Data Plane concerns have implementation and evidence."),
    ("security_privacy", "Authority, access, secrets, consent, sensitive data, retention, abuse, audit, export, and deletion are safe."),
    ("performance", "Representative budgets, profiler evidence, degradation, memory, battery, and large-data behavior pass."),
    ("verification", "Contract, unit, migration, integration, visual, accessibility, runtime, and platform evidence is linked."),
    ("adversarial_quality", "Independent critique finds no generic, incoherent, duplicative, unsafe, or unearned-page implementation."),
)


COMMON_STATES = (
    "first_use",
    "loading",
    "skeleton",
    "empty",
    "populated",
    "partial",
    "stale",
    "offline",
    "permission_denied",
    "conflict",
    "error",
    "retrying",
    "success",
    "recovery",
)
BACKGROUND_STATES = (
    "idle",
    "queued",
    "running",
    "paused",
    "offline",
    "rate_limited",
    "partial",
    "cancel_requested",
    "cancelled",
    "error",
    "retrying",
    "completed",
    "recovery",
)
SYSTEM_STATES = (
    "unavailable",
    "permission_required",
    "disabled",
    "enabled",
    "degraded",
    "offline",
    "stale",
    "error",
    "recovery",
)
MIGRATION_STATES = (
    "not_required",
    "eligible",
    "preview",
    "running",
    "partial",
    "conflict",
    "failed",
    "rolled_back",
    "completed",
    "receipt_available",
)


# Exact classification is deliberate. Unknown capabilities fail generation.
STUDYHUB_PROFILES = {
    "studyhub.8-achievements": "rewards_progress",
    "studyhub.ai-jobs": "ai_jobs",
    "studyhub.ai-service-contracts": "ai_jobs",
    "studyhub.android-widget": "planning_lifecycle",
    "studyhub.annotations": "workspace_knowledge",
    "studyhub.bookmarks": "workspace_knowledge",
    "studyhub.chat": "ai_jobs",
    "studyhub.dashboard": "planning_lifecycle",
    "studyhub.enrich-mode": "content_pipeline",
    "studyhub.enrolled-courses": "curriculum_learning",
    "studyhub.find-mode": "workspace_knowledge",
    "studyhub.lesson-forks": "content_pipeline",
    "studyhub.markdown-latex-table-renderer": "content_pipeline",
    "studyhub.mind-map": "workspace_knowledge",
    "studyhub.notifications": "planning_lifecycle",
    "studyhub.ocr-mobile": "content_pipeline",
    "studyhub.onboarding": "identity_governance",
    "studyhub.pdf-import": "workspace_knowledge",
    "studyhub.pdf-reader": "workspace_knowledge",
    "studyhub.pdf-storage": "workspace_knowledge",
    "studyhub.planner": "planning_lifecycle",
    "studyhub.pomodoro-focus": "planning_lifecycle",
    "studyhub.quiz-card-outline-generation": "content_pipeline",
    "studyhub.quiz-mode": "curriculum_learning",
    "studyhub.reading-progress": "workspace_knowledge",
    "studyhub.settings-biometric": "identity_governance",
    "studyhub.smart-notes": "workspace_knowledge",
    "studyhub.srs": "curriculum_learning",
    "studyhub.summary-mode": "content_pipeline",
    "studyhub.tags-and-xrefs": "workspace_knowledge",
    "studyhub.tts-and-cache": "workspace_knowledge",
    "studyhub.xp-constants": "rewards_progress",
}


# domain, surface, user-facing label, entry context, exposure, Data Plane profile
SYNAPSE_SPECS: dict[str, tuple[str, str, str, str, str, str]] = {
    "synapse.academy.curriculum-packages": ("Content Platform", "Curriculum Downloads", "Curriculum Downloads", "Path download/status controls and contextual recovery surfaces", "background_service", "curriculum_learning"),
    "synapse.academy.curriculum-path": ("Academy", "Path", "Curriculum Path", "Primary navigation > Path", "primary_destination", "curriculum_learning"),
    "synapse.academy.learning-session": ("Academy", "Learning Session", "Learn", "Path > Micro-lesson > Session", "dedicated_workflow", "curriculum_learning"),
    "synapse.global.achievements": ("Progress & Rewards", "Progress", "Achievements", "You > Progress and earned moments", "embedded_section", "rewards_progress"),
    "synapse.global.admin-create": ("Creator Platform", "Review Studio", "Review Studio", "Role-gated command and creator workspace", "dedicated_workflow", "content_pipeline"),
    "synapse.global.calculators-tools": ("Clinical", "Clinical Tools", "Clinical Tools", "Clinical context, Evidence, or global command", "contextual_surface", "clinical_evidence"),
    "synapse.global.cases": ("Clinical", "Case Rounds", "Cases", "Clinical and Path checkpoints", "dedicated_workflow", "clinical_evidence"),
    "synapse.global.classes-org": ("Rounds", "Learning Groups", "Learning Groups", "Rounds and role workspace", "dedicated_workflow", "social_collaboration"),
    "synapse.global.cloud-sync": ("Platform", "Sync Status", "Sync", "Shell status, affected artifact, and You > Data", "background_service", "platform_system"),
    "synapse.global.command-palette": ("Navigation", "Global Command", "Command", "Keyboard shortcut, long press, or global action", "system_surface", "platform_system"),
    "synapse.global.community-rooms-events": ("Rounds", "Rooms & Events", "Rounds", "Primary Rounds destination and contextual discussions", "primary_destination", "social_collaboration"),
    "synapse.global.concept-hub": ("Mastery", "Mastery Thread", "Mastery Thread", "Concept, lesson, error, or search result", "dedicated_workflow", "curriculum_learning"),
    "synapse.global.diseases": ("Clinical Evidence", "Evidence Shelf", "Conditions", "Clinical, Path, case, or search context", "contextual_surface", "clinical_evidence"),
    "synapse.global.drugs-classes-interactions": ("Clinical Evidence", "Evidence Shelf", "Medicines", "Clinical, Path, case, or search context", "contextual_surface", "clinical_evidence"),
    "synapse.global.entitlement-pro": ("Account", "Plan & Access", "Plan & Access", "You > Plan & Access and gated-feature explanation", "embedded_section", "commerce_entitlement"),
    "synapse.global.eventbus": ("Platform", "Domain Events", "Domain Events", "Background transport with diagnostics-only visibility", "background_service", "platform_system"),
    "synapse.global.home-module-grid": ("Today", "Today", "Today", "Primary navigation > Today", "primary_destination", "planning_lifecycle"),
    "synapse.global.import-export-integrations": ("Data & Integrations", "Transfers", "Import & Export", "Global command, Workspace, or You > Data", "dedicated_workflow", "platform_system"),
    "synapse.global.inbox-chat": ("Rounds", "Messages", "Messages", "Rounds, profile, group, assignment, or case context", "dedicated_workflow", "social_collaboration"),
    "synapse.global.insights": ("Progress & Rewards", "Insights", "Insights", "You > Progress and contextual summaries", "dedicated_workflow", "rewards_progress"),
    "synapse.global.library": ("Learning Workspace", "Evidence Shelf", "Library", "Path, Clinical, Search, or deliberate browse", "dedicated_workflow", "workspace_knowledge"),
    "synapse.global.network-banner": ("Platform", "Shell State", "Connection Status", "Shell and affected actions", "system_surface", "platform_system"),
    "synapse.global.notifications": ("Today", "Notifications", "Notifications", "Today, system delivery, and You > Notifications", "system_surface", "planning_lifecycle"),
    "synapse.global.osce": ("Clinical", "OSCE Lab", "OSCE Practice", "Clinical and Path checkpoints", "dedicated_workflow", "clinical_evidence"),
    "synapse.global.plan": ("Today", "Plan", "Plan", "Today > Adjust Plan", "dedicated_workflow", "planning_lifecycle"),
    "synapse.global.privacy-data": ("Account", "Privacy & Data", "Privacy & Data", "You > Settings > Privacy & Data", "dedicated_workflow", "identity_governance"),
    "synapse.global.profile-customization": ("You", "Learning Profile", "Learning Profile", "You and onboarding preferences", "embedded_section", "identity_governance"),
    "synapse.global.quests": ("Progress & Rewards", "Missions", "Missions", "Today and Rounds context", "embedded_section", "rewards_progress"),
    "synapse.global.review": ("Recall", "Recall Clinic", "Review", "Today due work and primary Review entry", "dedicated_workflow", "curriculum_learning"),
    "synapse.global.rewards": ("Progress & Rewards", "Reward Moments", "Rewards", "Session summaries, milestones, and You > Progress", "embedded_section", "rewards_progress"),
    "synapse.global.search": ("Navigation", "Global Search", "Search", "Global shell and context-preserving deep links", "dedicated_workflow", "platform_system"),
    "synapse.global.shop-pro": ("Account", "Cosmetics & Plan", "Cosmetics & Plan", "You > Plan & Access", "embedded_section", "commerce_entitlement"),
    "synapse.global.streak": ("Progress & Rewards", "Continuity", "Continuity", "Today and You > Progress", "embedded_section", "rewards_progress"),
    "synapse.module.algorithms": ("Clinical", "Decision Practice", "Decision Practice", "Clinical and chapter checkpoints", "contextual_surface", "clinical_evidence"),
    "synapse.module.arena": ("Rounds", "Optional Challenges", "Challenges", "Rounds events and optional Path encounters", "contextual_surface", "social_collaboration"),
    "synapse.module.buddies": ("Rounds", "Study Partners", "Study Partners", "Rounds and accountability setup", "embedded_section", "social_collaboration"),
    "synapse.module.cards": ("Recall", "Recall Clinic", "Cards", "Today reviews, Path Margin, and Recall Clinic", "contextual_surface", "curriculum_learning"),
    "synapse.module.copilot": ("Copilot", "Contextual Copilot", "Copilot", "Global dock and node, document, or case threads", "contextual_surface", "ai_jobs"),
    "synapse.module.ecg": ("Clinical", "Signal Lab", "ECG Practice", "Clinical skill lab and curriculum checkpoints", "dedicated_workflow", "clinical_evidence"),
    "synapse.module.labs": ("Clinical", "Lab Interpretation", "Lab Practice", "Clinical skill lab, cases, and Evidence", "dedicated_workflow", "clinical_evidence"),
    "synapse.module.mnemonics": ("Learning Workspace", "Memory Hooks", "Memory Hooks", "Lesson inspector, personal workspace, and reviewed Rounds contribution", "contextual_surface", "curriculum_learning"),
    "synapse.module.orLab": ("Clinical", "Procedure Lab", "Procedure Lab", "Clinical and Path boss checkpoints", "dedicated_workflow", "clinical_evidence"),
    "synapse.module.rounds": ("Rounds", "Teach-back Feed", "Teach-back Rounds", "Rounds destination and course or case context", "dedicated_workflow", "social_collaboration"),
    "synapse.module.sounds": ("Clinical", "Sound Lab", "Sound Practice", "Clinical skill lab, lesson encounters, and Rounds", "dedicated_workflow", "clinical_evidence"),
    "synapse.module.terms": ("Academy", "Terminology Lens", "Terms", "Path lesson method and Recall Clinic", "contextual_surface", "curriculum_learning"),
    "synapse.system.onboarding": ("Welcome", "Learning Setup", "Set Up Your Learning", "First run and You > Learning Preferences", "system_surface", "identity_governance"),
    "synapse.system.profile": ("You", "Profile", "Profile", "Primary navigation > You", "primary_destination", "identity_governance"),
}


STUDYHUB_EXPOSURE_OVERRIDES = {
    "studyhub.android-widget": "system_surface",
    "studyhub.dashboard": "primary_destination",
    "studyhub.notifications": "system_surface",
    "studyhub.onboarding": "system_surface",
    "studyhub.pdf-storage": "dedicated_workflow",
    "studyhub.planner": "dedicated_workflow",
    "studyhub.srs": "dedicated_workflow",
}


EXPOSURE_FROM_POLICY = {
    "visible": "embedded_section",
    "contextual": "contextual_surface",
    "background": "background_service",
    "migration-only": "migration_only",
}


PAGE_DECISIONS = {
    "primary_destination": (True, "A primary product branch owns a broad recurring job and preserves context across multiple workflows."),
    "dedicated_workflow": (True, "The capability has a sustained multi-step job, deep-link value, and independent state that earns a focused workflow."),
    "embedded_section": (False, "The capability is discoverable inside an existing destination and does not create another top-level or source-branded page."),
    "contextual_surface": (False, "The capability is meaningful only beside its owning lesson, source, concept, case, or artifact and stays in context."),
    "background_service": (False, "The capability runs in the background and appears only through status, job, recovery, or diagnostic surfaces."),
    "system_surface": (False, "The capability is exposed through shell, onboarding, notification, widget, command, permission, or platform settings surfaces."),
    "migration_only": (False, "The capability exists only to preserve and reconcile legacy state with a receipt; it never earns a product destination."),
}


def _load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _studyhub_product(
    capability_id: str, policy_by_id: dict[str, dict[str, Any]]
) -> dict[str, Any]:
    policy = policy_by_id[capability_id]
    exposure = STUDYHUB_EXPOSURE_OVERRIDES.get(
        capability_id, EXPOSURE_FROM_POLICY[policy["exposure"]]
    )
    return {
        "domain": policy["canonicalDomain"],
        "surface": policy["surface"],
        "userFacingLabel": policy["userFacingLabel"],
        "entryContext": policy["entryContext"],
        "analyticsNamespace": policy["analyticsNamespace"],
        "exposure": exposure,
    }


def _synapse_product(capability_id: str) -> dict[str, Any]:
    domain, surface, label, entry, exposure, _ = SYNAPSE_SPECS[capability_id]
    analytics_suffix = capability_id.removeprefix("synapse.").replace("-", "_")
    return {
        "domain": domain,
        "surface": surface,
        "userFacingLabel": label,
        "entryContext": entry,
        "analyticsNamespace": f"synapse.{analytics_suffix}",
        "exposure": exposure,
    }


def _states(exposure: str) -> list[str]:
    if exposure == "background_service":
        return list(BACKGROUND_STATES)
    if exposure == "system_surface":
        return list(SYSTEM_STATES)
    if exposure == "migration_only":
        return list(MIGRATION_STATES)
    return list(COMMON_STATES)


def _page_decision(exposure: str) -> dict[str, Any]:
    earned, rationale = PAGE_DECISIONS[exposure]
    return {"standalonePageEarned": earned, "rationale": rationale}


def _gate_state() -> dict[str, Any]:
    return {"status": "planned", "evidence": [], "rationale": None}


def _entry(
    source: dict[str, Any],
    product: dict[str, Any],
    data_profile: dict[str, Any],
    concern_ids: list[str],
) -> dict[str, Any]:
    capability_id = source["id"]
    exposure = product["exposure"]
    risk_flags = []
    if source["baselineState"] in {"at-risk", "commitment", "dormant"}:
        risk_flags.append(f"baseline_{source['baselineState'].replace('-', '_')}")
    if capability_id == "studyhub.enrich-mode":
        risk_flags.append("no_specialist_or_enrich_authoring_stage")
    if capability_id.startswith("studyhub."):
        risk_flags.append("legacy_source_name_migration_only")

    return {
        "capabilityId": capability_id,
        "provenance": {
            "sourceOwner": source["currentOwner"],
            "sourceDocument": source["source"],
            "sourceSection": source["sourceSection"],
            "sourceRow": source["sourceRow"],
        },
        "baseline": {
            "state": source["baselineState"],
            "detail": source["baselineDetail"],
            "currentRoutes": source["currentRoutes"],
            "preservationRule": source["preservation"],
        },
        "product": {
            **product,
            "capabilityIntent": source["canonicalOwner"],
            "placementIntent": source["targetContext"],
            "pageDecision": _page_decision(exposure),
        },
        "dataPlane": {
            "profileId": data_profile["id"],
            "entityFamilies": data_profile["entityFamilies"],
            "truthAuthority": data_profile["truthAuthority"],
            "entitySchemaStatus": "planned",
            "concerns": {concern_id: "planned" for concern_id in concern_ids},
        },
        "experience": {
            "requiredStates": _states(exposure),
            "locales": ["en", "fa"],
            "directions": ["ltr", "rtl"],
            "motionModes": ["full", "reduced", "off"],
            "inputModes": ["touch", "pointer", "keyboard", "screen_reader"],
            "viewportClasses": ["compact", "medium", "expanded", "wide"],
            "nightShiftRequired": True,
        },
        "delivery": {
            "completionStatus": "planned",
            "verificationOwner": source["verificationOwner"],
            "riskFlags": risk_flags,
            "gates": {gate_id: _gate_state() for gate_id, _ in GATES},
        },
    }


def _apply_evidence(
    entry: dict[str, Any], override: dict[str, Any]
) -> dict[str, Any]:
    allowed = {
        "capabilityId",
        "completionStatus",
        "entitySchemaStatus",
        "concerns",
        "gates",
        "retirementAuthorization",
    }
    unknown = set(override) - allowed
    if unknown:
        raise ValueError(
            f"Unknown evidence fields for {entry['capabilityId']}: {sorted(unknown)}"
        )
    delivery = entry["delivery"]
    data_plane = entry["dataPlane"]
    if "completionStatus" in override:
        delivery["completionStatus"] = override["completionStatus"]
    if "entitySchemaStatus" in override:
        data_plane["entitySchemaStatus"] = override["entitySchemaStatus"]
    for concern_id, status in override.get("concerns", {}).items():
        if concern_id not in data_plane["concerns"]:
            raise ValueError(
                f"Unknown Data Plane concern {concern_id!r} for {entry['capabilityId']}"
            )
        data_plane["concerns"][concern_id] = status
    for gate_id, gate_override in override.get("gates", {}).items():
        if gate_id not in delivery["gates"]:
            raise ValueError(
                f"Unknown masterpiece gate {gate_id!r} for {entry['capabilityId']}"
            )
        unknown_gate_fields = set(gate_override) - {
            "status",
            "evidence",
            "rationale",
        }
        if unknown_gate_fields:
            raise ValueError(
                f"Unknown {gate_id} evidence fields: {sorted(unknown_gate_fields)}"
            )
        delivery["gates"][gate_id].update(gate_override)
    if "retirementAuthorization" in override:
        delivery["retirementAuthorization"] = override["retirementAuthorization"]
    return entry


def generate(evidence: dict[str, Any] | None = None) -> dict[str, Any]:
    preservation = _load(PRESERVATION_PATH)
    language_policy = _load(LANGUAGE_POLICY_PATH)
    data_plane = _load(DATA_PLANE_PATH)
    new_capabilities = _load(NEW_CAPABILITIES_PATH)
    evidence = _load(EVIDENCE_PATH) if evidence is None else evidence

    if (
        new_capabilities.get("schemaVersion") != 1
        or new_capabilities.get("contractId")
        != "synapse.new-capability-registry.v1"
    ):
        raise ValueError("Unsupported new capability registry.")
    source_entries = [*preservation["entries"], *new_capabilities["entries"]]
    source_ids = {entry["id"] for entry in source_entries}
    expected_ids = set(STUDYHUB_PROFILES) | set(SYNAPSE_SPECS)
    if source_ids != expected_ids:
        missing = sorted(source_ids - expected_ids)
        stale = sorted(expected_ids - source_ids)
        raise ValueError(f"Capability classification drift. missing={missing} stale={stale}")

    policy_by_id = {
        entry["sourceId"]: entry for entry in language_policy["capabilityMap"]
    }
    if set(policy_by_id) != set(STUDYHUB_PROFILES):
        raise ValueError("Functional product-language coverage drifted from StudyHUB IDs.")

    if evidence.get("schemaVersion") != 1 or evidence.get("contractId") != "synapse.capability-evidence.v1":
        raise ValueError("Unsupported capability evidence contract.")
    evidence_entries = evidence.get("entries")
    if not isinstance(evidence_entries, list):
        raise ValueError("Capability evidence entries must be an array.")
    evidence_by_id: dict[str, dict[str, Any]] = {}
    for override in evidence_entries:
        capability_id = override.get("capabilityId")
        if capability_id not in source_ids:
            raise ValueError(f"Unknown evidence capability ID {capability_id!r}.")
        if capability_id in evidence_by_id:
            raise ValueError(f"Duplicate evidence capability ID {capability_id!r}.")
        evidence_by_id[capability_id] = override

    profiles = {profile["id"]: profile for profile in data_plane["profiles"]}
    concerns = [concern["id"] for concern in data_plane["concerns"]]
    entries = []
    for source in sorted(source_entries, key=lambda value: value["id"]):
        capability_id = source["id"]
        if capability_id.startswith("studyhub."):
            product = _studyhub_product(capability_id, policy_by_id)
            profile_id = STUDYHUB_PROFILES[capability_id]
        else:
            product = _synapse_product(capability_id)
            profile_id = SYNAPSE_SPECS[capability_id][5]
        entry = _entry(source, product, profiles[profile_id], concerns)
        if capability_id in evidence_by_id:
            entry = _apply_evidence(entry, evidence_by_id[capability_id])
        entries.append(entry)

    status_counts = {
        status: sum(
            1
            for entry in entries
            if entry["delivery"]["completionStatus"] == status
        )
        for status in (
            "planned",
            "active",
            "blocked",
            "verified",
            "retired_authorized",
        )
    }

    return {
        "schemaVersion": 1,
        "contractId": "synapse.capability-completion.v1",
        "goalAuthority": "docs/codex/2026-07-15-synapse-medical-learning-os/37-goal-charter-v2.md",
        "generatedBy": "tool/product/generate_capability_completion.py",
        "sources": [
            {
                "path": str(PRESERVATION_PATH.relative_to(ROOT)).replace("\\", "/"),
                "sha256": _sha256(PRESERVATION_PATH),
            },
            {
                "path": str(LANGUAGE_POLICY_PATH.relative_to(ROOT)).replace("\\", "/"),
                "sha256": _sha256(LANGUAGE_POLICY_PATH),
            },
            {
                "path": str(DATA_PLANE_PATH.relative_to(ROOT)).replace("\\", "/"),
                "sha256": _sha256(DATA_PLANE_PATH),
            },
            {
                "path": str(NEW_CAPABILITIES_PATH.relative_to(ROOT)).replace("\\", "/"),
                "sha256": _sha256(NEW_CAPABILITIES_PATH),
            },
            {
                "path": str(EVIDENCE_PATH.relative_to(ROOT)).replace("\\", "/"),
                "sha256": _sha256(EVIDENCE_PATH),
            },
        ],
        "statusPolicy": {
            "allowed": ["planned", "active", "blocked", "verified", "retired_authorized"],
            "verifiedRule": "Every required gate and Data Plane concern must be verified with current evidence; not_applicable requires a reviewed rationale and evidence.",
            "generatorRule": "Base generation never marks a capability or gate verified; only the reviewed evidence overlay may advance status, and semantic verification still governs completion.",
        },
        "gateProfile": {
            "id": "synapse.masterpiece.v1",
            "gates": [
                {"id": gate_id, "requirement": requirement}
                for gate_id, requirement in GATES
            ],
        },
        "summary": {
            "expectedCapabilities": len(source_entries),
            "planned": status_counts["planned"],
            "active": status_counts["active"],
            "blocked": status_counts["blocked"],
            "verified": status_counts["verified"],
            "retiredAuthorized": status_counts["retired_authorized"],
        },
        "entries": entries,
    }


def render(output: dict[str, Any]) -> str:
    return json.dumps(output, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail if the checked-in ledger differs from fresh generation.",
    )
    args = parser.parse_args()
    output = generate()
    expected = render(output)
    if args.check:
        if not OUTPUT_PATH.exists() or OUTPUT_PATH.read_text(encoding="utf-8") != expected:
            print(f"stale generated capability ledger: {OUTPUT_PATH.relative_to(ROOT)}")
            return 1
        print(f"capability generation parity: pass | records={len(output['entries'])}")
        return 0

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(expected, encoding="utf-8")
    print(
        f"generated {len(output['entries'])} capability records at "
        f"{OUTPUT_PATH.relative_to(ROOT)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
