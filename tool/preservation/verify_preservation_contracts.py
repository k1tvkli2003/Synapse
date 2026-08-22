#!/usr/bin/env python3
"""Adversarial verifier for the Synapse pre-rebuild preservation bundle."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from generate_preservation_contracts import (
    OUTPUT_DIR,
    OUTPUT_NAMES,
    ROOT,
    SOURCE_DATE,
    build_contracts,
    json_bytes,
    relative,
    sha256_bytes,
    sha256_file,
)


RECEIPT = OUTPUT_DIR / "preservation-verification.v1.json"


class Verification:
    def __init__(self) -> None:
        self.failures: list[str] = []
        self.checks: list[dict[str, Any]] = []

    def check(self, identifier: str, condition: bool, detail: str) -> None:
        self.checks.append(
            {"id": identifier, "status": "pass" if condition else "fail", "detail": detail}
        )
        if not condition:
            self.failures.append(f"{identifier}: {detail}")


def verify() -> dict[str, Any]:
    verification = Verification()
    generated = build_contracts()

    for name in OUTPUT_NAMES:
        path = OUTPUT_DIR / name
        expected = json_bytes(generated[name])
        verification.check(
            f"snapshot.{name}",
            path.exists() and path.read_bytes() == expected,
            f"{relative(path)} exists and equals a fresh source-derived generation",
        )

    route_registry = generated["route-registry.v1.json"]
    routes = route_registry["routes"]
    helpers = route_registry["helpers"]
    route_paths = [route["path"] for route in routes]
    declaration_count = len({route["sourceLine"] for route in routes})
    verification.check(
        "routes.declarations",
        declaration_count == 142,
        f"expected 142 GoRoute declarations, found {declaration_count}",
    )
    verification.check(
        "routes.resolved",
        len(routes) == 150 and len(set(route_paths)) == 150,
        f"expected 150 unique concrete route paths after LibraryKind expansion, found {len(routes)}",
    )
    verification.check(
        "routes.parameters",
        all(
            ":" not in route["sampleLocation"]
            and set(route["pathParameters"])
            == set(re.findall(r":([A-Za-z_]\w*)", route["path"]))
            and all(f"{name}=" in route["sampleLocation"] for name in route["queryParameters"])
            for route in routes
        ),
        "every path/query parameter is inventoried and has a concrete fixture value",
    )
    verification.check(
        "routes.branches",
        all(
            route["shellBranch"] in {None, "home", "learn", "clinical", "social", "profile"}
            for route in routes
        )
        and all(route["intent"] != "unknown" for route in routes),
        "all routes have a known intent and either a protected shell branch or root ownership",
    )
    verification.check(
        "routes.helpers",
        len(helpers) == 91 and all(helper.get("matchedRouteId") for helper in helpers),
        f"all {len(helpers)} constant/function/extension helper variants resolve to a registered intent",
    )

    module_registry = generated["module-registry.v1.json"]
    module_ids = [module["id"] for module in module_registry["modules"]]
    branch_ids = [branch["id"] for branch in module_registry["shellBranches"]]
    expected_modules = [
        "copilot",
        "terms",
        "cards",
        "mnemonics",
        "ecg",
        "sounds",
        "labs",
        "algorithms",
        "orLab",
        "rounds",
        "buddies",
        "arena",
    ]
    expected_branches = ["home", "learn", "clinical", "social", "profile"]
    verification.check(
        "modules.stable-ids",
        module_ids == expected_modules,
        f"ModuleKey serialization remains {expected_modules}",
    )
    verification.check(
        "modules.shell-branches",
        branch_ids == expected_branches,
        f"ShellBranch serialization remains {expected_branches}",
    )
    enum_map = {
        item["name"]: item["values"] for item in module_registry["serializedEnums"]
    }
    verification.check(
        "modules.enum-parity",
        enum_map.get("ModuleKey") == expected_modules
        and enum_map.get("ShellBranch") == expected_branches
        and enum_map.get("MotionModePref") == ["full", "reduced", "off"]
        and len(enum_map) == 45,
        "all 45 source enums are snapshotted; protected registries and motion preference values match canonical contracts",
    )

    persistence = generated["persistence-keys.v1.json"]
    persistence_keys = {entry["key"] for entry in persistence["entries"]}
    expected_keys = {
        "__synapse_schema",
        "profile",
        "settings",
        "onboarded",
        "game_state",
        "mastery",
        "counters",
        "unlocked_at",
        "quests",
        "srs_cards",
        "study_plan_done",
        "personalization",
        "motion_presentation_queue_v1",
        "__synapse_curriculum_session_progress_v1",
        "__synapse_curriculum_study_workspace_v1",
        "__synapse_curriculum_reading_state_v1",
        "__synapse_resource_workspace_v1",
        "__synapse_resource_document_reading_state_v1",
    }
    verification.check(
        "persistence.complete",
        persistence_keys == expected_keys and persistence["appSchemaVersion"] == 1,
        "all 13 preserved legacy keys plus five Academy/Data Plane v1 keys have owner/type/default/migration metadata",
    )
    verification.check(
        "persistence.restore-contract",
        all(entry["callSites"] and entry["migration"] for entry in persistence["entries"]),
        "every persisted key has source call sites and an explicit compatibility rule",
    )

    schema = generated["supabase-schema.v1.json"]
    tables = {table["name"]: table for table in schema["tables"]}
    expected_tables = {
        "synapse_profiles",
        "synapse_game_state",
        "synapse_concept_mastery",
        "synapse_srs_cards",
        "synapse_user_quests",
        "synapse_user_achievements",
        "synapse_notifications",
        "synapse_content_items",
        "synapse_content_reports",
    }
    game_columns = {column["name"] for column in tables["synapse_game_state"]["columns"]}
    verification.check(
        "supabase.schema",
        set(tables) == expected_tables
        and {"hearts_max", "next_refill_at", "last_active_day", "freezes"}.issubset(game_columns),
        "all nine tables and migration-0002 fidelity columns are present",
    )
    verification.check(
        "supabase.rls",
        set(schema["rlsEnabledTables"]) == expected_tables
        and len(schema["policies"]) == 11,
        "RLS is enabled on every exposed table and all 11 policies are frozen",
    )
    verification.check(
        "supabase.functions",
        len(schema["functions"]) == 1
        and schema["functions"][0]["name"] == "synapse_handle_new_user"
        and schema["functions"][0]["securityDefiner"]
        and len(schema["revocations"]) == 1
        and len(schema["triggers"]) == 2
        and len(schema["views"]) == 1,
        "function, execute revocation, triggers, and leaderboard view are captured",
    )
    verification.check(
        "supabase.sanitized",
        schema["sanitized"] is True and schema["secretFindings"] == [],
        "schema fixture contains structural metadata and no detected secret value",
    )

    archived = generated["archived-domain-fixtures.v1.json"]
    expected_models = {"Concept", "ConceptMastery", "SrsCard", "UserProfile"}
    expected_events = {
        "ConceptStudied",
        "ConceptStruggled",
        "ItemMastered",
        "LessonCompleted",
        "CaseCompleted",
        "RewardGranted",
        "StreakChanged",
        "ContentCreated",
        "SocialInteraction",
        "QuestProgressed",
    }
    verification.check(
        "archives.models-events",
        set(archived["models"]) == expected_models
        and {event["type"] for event in archived["events"]} == expected_events,
        "four serialized models and all ten SynapseEvent variants have synthetic fixtures",
    )
    verification.check(
        "archives.synthetic",
        "fixture" in json.dumps(archived).lower()
        and "service_role" not in json.dumps(archived).lower(),
        "archived payloads are synthetic and contain no privileged key marker",
    )

    deep_links = generated["deep-link-fixtures.v1.json"]["fixtures"]
    fixture_ids = {fixture["id"] for fixture in deep_links}
    expected_fixture_ids = {
        f"{route['id']}::{mode}"
        for route in routes
        for mode in ("coldStart", "webRefresh", "nativeLocation")
    }
    verification.check(
        "deep-links.matrix",
        len(deep_links) == 450 and fixture_ids == expected_fixture_ids,
        "every concrete route has cold-start, web-refresh, and native-location fixtures",
    )
    verification.check(
        "deep-links.intent-parity",
        all(
            fixture["expectedRouteId"] in {route["id"] for route in routes}
            and fixture["expectedIntent"] != "unknown"
            for fixture in deep_links
        ),
        "all deep-link fixtures preserve route intent and branch ownership",
    )

    capabilities = generated["capability-ledger.v1.json"]
    capability_ids = {entry["id"] for entry in capabilities["entries"]}
    additive_capability_ids = set(capabilities["registeredAdditiveCapabilityIds"])
    route_coverage = capabilities["routeCoverage"]
    verification.check(
        "capabilities.inventory",
        len(capability_ids) == 76
        and any(item.startswith("studyhub.") for item in capability_ids)
        and all(item["baselineState"] in {"operational", "partial", "commitment", "at-risk", "prototype", "dormant"} for item in capabilities["entries"]),
        "76 Synapse/StudyHUB capabilities have stable IDs, honest state, owner, target, and verification ownership",
    )
    verification.check(
        "capabilities.route-coverage",
        len(route_coverage) == len(routes)
        and {item["routeId"] for item in route_coverage} == {route["id"] for route in routes}
        and additive_capability_ids
        == {
            "synapse.academy.curriculum-packages",
            "synapse.academy.curriculum-path",
            "synapse.academy.learning-session",
        }
        and all(
            item["capabilityId"] in capability_ids | additive_capability_ids
            for item in route_coverage
        ),
        "every route is owned by exactly one preserved or registered additive capability",
    )

    rollback = generated["rollback-bundle.v1.json"]
    rollback_ok = all(
        entry["artifact"] in generated
        and entry["sha256"] == sha256_bytes(json_bytes(generated[entry["artifact"]]))
        for entry in rollback["entries"]
    )
    verification.check(
        "rollback.checksums",
        rollback_ok and len(rollback["entries"]) == 7,
        "route/local/schema/capability rollback baselines are versioned and checksummed",
    )

    manifest = generated["preservation-manifest.v1.json"]
    manifest_output_ok = all(
        item["path"].removeprefix("contracts/preservation/") in generated
        and item["sha256"]
        == sha256_bytes(
            json_bytes(
                generated[item["path"].removeprefix("contracts/preservation/")]
            )
        )
        for item in manifest["outputs"]
    )
    manifest_source_ok = all(
        (ROOT / item["path"]).exists()
        and sha256_file(ROOT / item["path"]) == item["sha256"]
        for item in manifest["sources"]
    )
    verification.check(
        "manifest.integrity",
        manifest_output_ok and manifest_source_ok,
        "manifest output hashes and all source hashes match current bytes",
    )

    receipt = {
        "schemaVersion": 1,
        "sourceDate": SOURCE_DATE,
        "status": "pass" if not verification.failures else "fail",
        "p0Findings": verification.failures,
        "checks": verification.checks,
        "counts": manifest["counts"],
        "manifestSha256": sha256_bytes(json_bytes(manifest)),
        "rollbackBundleSha256": sha256_bytes(json_bytes(rollback)),
        "limits": [
            "this gate proves source/fixture compatibility, not native host runtime or production database state",
            "Dart fixture round-trip tests are a separate required command",
            "destructive route, key, schema, or user-file changes still require explicit approval and tested restore evidence",
        ],
    }
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--no-write-receipt", action="store_true")
    args = parser.parse_args()
    receipt = verify()
    if not args.no_write_receipt:
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        RECEIPT.write_bytes(json_bytes(receipt))
    if args.json or receipt["status"] != "pass":
        print(json.dumps(receipt, ensure_ascii=False, indent=2))
    else:
        print(
            "Preservation gate PASS: "
            f"{len(receipt['checks'])} checks, "
            f"{receipt['counts']['routeDeclarations']} route declarations / "
            f"{receipt['counts']['resolvedRoutes']} concrete routes, "
            f"{receipt['counts']['persistenceKeys']} persistence keys, "
            f"{receipt['counts']['capabilities']} capabilities"
        )
    return 0 if receipt["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
