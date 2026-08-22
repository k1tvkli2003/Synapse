#!/usr/bin/env python3
"""Generate deterministic preservation contracts from the current Synapse source.

The snapshots are an additive rebuild guard. They intentionally describe stable
operational identity (routes, serialized enums, persistence keys and database
objects) rather than presentation. Run without arguments to refresh fixtures;
run with ``--check`` in CI to fail on an unreviewed contract drift.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


SCHEMA_VERSION = 1


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def source_ref(root: Path, path: Path) -> dict[str, str]:
    return {
        "path": path.relative_to(root).as_posix(),
        "sha256": sha256(path),
    }


def _quoted_value(expression: str) -> str | None:
    value = expression.strip()
    if len(value) >= 2 and value[0] in {"'", '"'} and value[-1] == value[0]:
        return value[1:-1]
    return None


def _parameters(path: str) -> list[str]:
    return re.findall(r":([A-Za-z_][A-Za-z0-9_]*)", path)


def _branch_for(path: str) -> str:
    if path == "/home" or path.startswith("/home/"):
        return "home"
    if path == "/learn" or path.startswith("/learn/"):
        return "learn"
    if path == "/clinical" or path.startswith("/clinical/"):
        return "clinical"
    if path == "/social" or path.startswith("/social/"):
        return "social"
    if path == "/profile" or path.startswith("/profile/") or path.startswith("/u/"):
        return "profile"
    return "global"


def _relative_parent(path: str) -> str | None:
    head = path.split("/", 1)[0]
    if head in {"terms", "cards", "mnemonics"}:
        return "/learn"
    if head in {"ecg", "sounds", "labs", "algorithms", "or-lab"}:
        return "/clinical"
    if head in {"rounds", "buddies", "arena"}:
        return "/social"
    return None


def _normalise_helper_template(expression: str) -> str:
    value = _quoted_value(expression) or expression.strip()
    value = re.sub(r"\$([A-Za-z_]\w*)", r":\1", value)
    value = re.sub(r"\$\{([A-Za-z_]\w*)\.route\}", r":\1Route", value)
    value = re.sub(r"\$\{([A-Za-z_]\w*)\.join\([^}]+\)\}", r":\1Csv", value)
    return value


def _balanced_call_blocks(text: str, name: str) -> Iterable[tuple[int, str]]:
    token = f"{name}("
    cursor = 0
    while True:
        start = text.find(token, cursor)
        if start < 0:
            return
        index = start + len(name)
        depth = 0
        quote: str | None = None
        escaped = False
        line_comment = False
        block_comment = False
        while index < len(text):
            char = text[index]
            nxt = text[index + 1] if index + 1 < len(text) else ""
            if line_comment:
                if char == "\n":
                    line_comment = False
                index += 1
                continue
            if block_comment:
                if char == "*" and nxt == "/":
                    block_comment = False
                    index += 2
                else:
                    index += 1
                continue
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
                index += 1
                continue
            if char == "/" and nxt == "/":
                line_comment = True
                index += 2
                continue
            if char == "/" and nxt == "*":
                block_comment = True
                index += 2
                continue
            if char in {"'", '"'}:
                quote = char
                index += 1
                continue
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    yield start, text[start : index + 1]
                    cursor = index + 1
                    break
            index += 1
        else:
            raise ValueError(f"Unbalanced {name} call at offset {start}")


def _parse_route_constants(routes_text: str) -> dict[str, str]:
    return {
        match.group("name"): match.group("path")
        for match in re.finditer(
            r"static\s+const\s+(?P<name>[A-Za-z_]\w*)\s*=\s*['\"](?P<path>/[^'\"]*)['\"]\s*;",
            routes_text,
        )
    }


def _parse_library_routes(library_text: str) -> list[dict[str, str]]:
    values_match = re.search(r"enum\s+LibraryKind\s*\{(?P<body>.*?)\;", library_text, re.S)
    if not values_match:
        raise ValueError("LibraryKind enum was not found")
    kinds = [item.strip() for item in values_match.group("body").split(",") if item.strip()]
    mapping = {
        match.group("kind"): match.group("route")
        for match in re.finditer(
            r"LibraryKind\.(?P<kind>\w+)\s*=>\s*['\"](?P<route>/library/[^'\"]+)['\"]",
            library_text,
        )
    }
    missing = sorted(set(kinds) - set(mapping))
    if missing:
        raise ValueError(f"LibraryKind route mapping missing: {', '.join(missing)}")
    return [{"kind": kind, "route": mapping[kind]} for kind in kinds]


def _resolve_route_expression(
    expression: str,
    constants: dict[str, str],
    library_routes: list[dict[str, str]],
) -> list[tuple[str, str | None]]:
    expr = expression.strip()
    route_const = re.fullmatch(r"Routes\.([A-Za-z_]\w*)", expr)
    if route_const:
        name = route_const.group(1)
        if name not in constants:
            raise ValueError(f"Unknown route constant: {expr}")
        return [(constants[name], name)]
    if expr == "kind.route":
        return [(item["route"], f"library_{item['kind']}") for item in library_routes]
    quoted = _quoted_value(expr)
    if quoted is None:
        raise ValueError(f"Unsupported GoRoute path expression: {expr}")
    if quoted == "${kind.route}/:id":
        return [(f"{item['route']}/:id", f"library_{item['kind']}_detail") for item in library_routes]
    if not quoted.startswith("/"):
        parent = _relative_parent(quoted)
        if parent is None:
            raise ValueError(f"Unowned relative GoRoute path: {quoted}")
        quoted = f"{parent}/{quoted}"
    return [(quoted, None)]


def _intent_from_path(path: str) -> str:
    clean = re.sub(r"[^A-Za-z0-9]+", "_", path).strip("_")
    return clean or "root"


def build_routes_contract(root: Path) -> dict[str, Any]:
    routes_path = root / "apps/app/lib/router/routes.dart"
    router_path = root / "apps/app/lib/router/router.dart"
    library_path = root / "packages/core/lib/src/models/library.dart"
    routes_text = routes_path.read_text(encoding="utf-8")
    router_text = router_path.read_text(encoding="utf-8")
    library_text = library_path.read_text(encoding="utf-8")
    constants = _parse_route_constants(routes_text)
    library_routes = _parse_library_routes(library_text)

    helpers: list[dict[str, Any]] = []
    helper_re = re.compile(
        r"static\s+String\s+(?P<name>[A-Za-z_]\w*)\s*\((?P<args>.*?)\)\s*=>\s*(?P<expr>.*?);",
        re.S,
    )
    for match in helper_re.finditer(routes_text):
        expression = match.group("expr").strip()
        template = _normalise_helper_template(expression)
        helpers.append(
            {
                "name": match.group("name"),
                "arguments": " ".join(match.group("args").split()),
                "sourceExpression": expression,
                "template": template,
                "parameters": _parameters(template),
                "sourceLine": line_number(routes_text, match.start()),
            }
        )

    reverse_constants = {value: name for name, value in constants.items()}
    routes: list[dict[str, Any]] = []
    for offset, block in _balanced_call_blocks(router_text, "GoRoute"):
        path_match = re.search(r"\bpath\s*:\s*(?P<expr>[^,\r\n]+)", block)
        if not path_match:
            continue
        expression = path_match.group("expr").strip()
        target_match = re.search(r"=>\s*(?:const\s+)?(?P<target>[A-Za-z_]\w*)\s*\(", block)
        target = target_match.group("target") if target_match else "dynamic"
        for resolved, generated_intent in _resolve_route_expression(expression, constants, library_routes):
            intent = generated_intent or reverse_constants.get(resolved) or _intent_from_path(resolved)
            routes.append(
                {
                    "path": resolved,
                    "pathExpression": expression,
                    "intent": intent,
                    "branch": _branch_for(resolved),
                    "parameters": _parameters(resolved),
                    "target": target,
                    "state": "commitment" if target == "ComingSoonScreen" else "implemented-route",
                    "sourceLine": line_number(router_text, offset),
                }
            )

    routes.sort(key=lambda item: (item["path"], item["sourceLine"], item["intent"]))
    duplicate_paths = sorted(
        path for path in {item["path"] for item in routes} if sum(1 for item in routes if item["path"] == path) > 1
    )
    return {
        "schemaVersion": SCHEMA_VERSION,
        "contract": "synapse-routes",
        "sources": [
            source_ref(root, routes_path),
            source_ref(root, router_path),
            source_ref(root, library_path),
        ],
        "routeConstants": [
            {
                "name": name,
                "path": path,
                "branch": _branch_for(path),
                "parameters": _parameters(path),
            }
            for name, path in sorted(constants.items())
        ],
        "routeHelpers": sorted(helpers, key=lambda item: item["name"]),
        "libraryKinds": library_routes,
        "goRoutes": routes,
        "summary": {
            "routeConstantCount": len(constants),
            "routeHelperCount": len(helpers),
            "goRouteCount": len(routes),
            "uniquePathCount": len({item["path"] for item in routes}),
            "commitmentRouteCount": sum(1 for item in routes if item["state"] == "commitment"),
            "duplicatePaths": duplicate_paths,
        },
    }


def build_modules_contract(root: Path) -> dict[str, Any]:
    path = root / "packages/core/lib/src/models/module_key.dart"
    text = path.read_text(encoding="utf-8")
    branches_match = re.search(r"enum\s+ShellBranch\s*\{(?P<body>[^}]*)\}", text, re.S)
    if not branches_match:
        raise ValueError("ShellBranch enum was not found")
    branches = [item.strip() for item in branches_match.group("body").split(",") if item.strip()]
    module_body = re.search(r"enum\s+ModuleKey\s*\{(?P<body>.*?);", text, re.S)
    if not module_body:
        raise ValueError("ModuleKey enum body was not found")
    entry_re = re.compile(
        r"(?P<id>[A-Za-z_]\w*)\s*\(\s*"
        r"title:\s*'(?P<title>[^']*)',\s*"
        r"source:\s*'(?P<source>[^']*)',\s*"
        r"branch:\s*ShellBranch\.(?P<branch>\w+),\s*"
        r"tagline:\s*'(?P<tagline>[^']*)',\s*"
        r"accentHex:\s*(?P<accent>0x[0-9A-Fa-f]+),\s*\)",
        re.S,
    )
    modules = [match.groupdict() for match in entry_re.finditer(module_body.group("body"))]
    if not modules:
        raise ValueError("No ModuleKey entries were parsed")
    unknown = sorted({item["branch"] for item in modules} - set(branches))
    if unknown:
        raise ValueError(f"ModuleKey references unknown branches: {', '.join(unknown)}")
    return {
        "schemaVersion": SCHEMA_VERSION,
        "contract": "synapse-module-serialization",
        "sources": [source_ref(root, path)],
        "shellBranches": [{"id": branch, "ordinal": index} for index, branch in enumerate(branches)],
        "modules": [
            {
                "id": item["id"],
                "ordinal": index,
                "title": item["title"],
                "legacySource": item["source"],
                "branch": item["branch"],
                "tagline": item["tagline"],
                "accentArgb": item["accent"].upper().replace("0X", "0x"),
            }
            for index, item in enumerate(modules)
        ],
        "invariants": {
            "serializedId": "ModuleKey.name",
            "parseRule": "exact case-sensitive ModuleKey.name match",
            "ordinalIsNotStableIdentity": True,
        },
        "summary": {"shellBranchCount": len(branches), "moduleCount": len(modules)},
    }


PERSISTENCE_METADATA: dict[str, dict[str, Any]] = {
    "__synapse_schema": {
        "owner": "PersistedStore",
        "storageType": "int",
        "default": "appSchemaVersion",
        "version": 1,
        "migration": "Current v1 constructor stamps/restamps; future versions require a forward migration before increment.",
    },
    "personalization": {
        "owner": "EntitlementController",
        "storageType": "json-object",
        "default": "free entitlement and default personalization",
        "version": 1,
        "migration": "Field-fallback deserialization; preserve unknown legacy state through an explicit adapter before schema change.",
    },
    "settings": {
        "owner": "SettingsController",
        "storageType": "json-object",
        "default": "UserPrefs defaults",
        "version": 1,
        "migration": "UserPrefs.fromJson field fallbacks.",
    },
    "profile": {
        "owner": "UserController",
        "storageType": "json-object",
        "default": "seed/default user profile",
        "version": 1,
        "migration": "UserProfile.fromJson field fallbacks.",
    },
    "game_state": {
        "owner": "GameController",
        "storageType": "json-object",
        "default": "GameState initial values",
        "version": 1,
        "migration": "GameState.fromJson field fallbacks; reconcile with authoritative ledger before replacement.",
    },
    "mastery": {
        "owner": "GameController",
        "storageType": "json-map",
        "default": "empty concept mastery map",
        "version": 1,
        "migration": "Per-entry ConceptMastery.fromJson fallback.",
    },
    "quests": {
        "owner": "GameController",
        "storageType": "json-map",
        "default": "quest definitions with zero progress",
        "version": 1,
        "migration": "Quest progress must preserve quest IDs and claimed state.",
    },
    "counters": {
        "owner": "GameController",
        "storageType": "json-map",
        "default": "empty event counter map",
        "version": 1,
        "migration": "Preserve counter keys until reward-ledger reconciliation is complete.",
    },
    "unlocked_at": {
        "owner": "GameController",
        "storageType": "json-map<achievement-id,iso8601>",
        "default": "empty achievement timestamp map",
        "version": 1,
        "migration": "Preserve achievement IDs and ISO-8601 timestamps.",
    },
    "study_plan_done": {
        "owner": "StudyPlanController",
        "storageType": "json-object",
        "default": "empty completion/reschedule state",
        "version": 1,
        "migration": "Preserve item IDs, completion dates and reschedule state.",
    },
    "srs_cards": {
        "owner": "SrsController",
        "storageType": "json-object",
        "default": "seed queue or empty user queue",
        "version": 1,
        "migration": "Preserve card IDs, interval, ease, repetitions, lapses and due timestamps.",
    },
    "motion_presentation_queue_v1": {
        "owner": "PresentationQueueController",
        "storageType": "json-object",
        "default": "empty authoritative presentation-receipt queue",
        "version": 1,
        "migration": "Optional presentation state; recover to an empty queue on malformed or future snapshots without changing rewards or learning progress.",
    },
}


def build_persistence_contract(root: Path) -> dict[str, Any]:
    state_dir = root / "apps/app/lib/state"
    files = sorted(state_dir.glob("*.dart"))
    found: dict[str, dict[str, Any]] = {}
    key_re = re.compile(r"static\s+const\s+(?P<const>_[A-Za-z_]\w*)\s*=\s*['\"](?P<key>[^'\"]+)['\"]\s*;")
    for path in files:
        text = path.read_text(encoding="utf-8")
        for match in key_re.finditer(text):
            key = match.group("key")
            if key in found:
                raise ValueError(f"Duplicate persistence key literal {key!r}")
            found[key] = {
                "constant": match.group("const"),
                "source": path.relative_to(root).as_posix(),
                "sourceLine": line_number(text, match.start()),
            }
    unknown = sorted(set(found) - set(PERSISTENCE_METADATA))
    stale = sorted(set(PERSISTENCE_METADATA) - set(found))
    if unknown or stale:
        raise ValueError(f"Persistence metadata drift; unknown={unknown}, stale={stale}")
    version_path = root / "packages/config/lib/src/version.dart"
    version_text = version_path.read_text(encoding="utf-8")
    version_match = re.search(r"const\s+int\s+appSchemaVersion\s*=\s*(\d+)\s*;", version_text)
    if not version_match:
        raise ValueError("appSchemaVersion was not found")
    app_schema_version = int(version_match.group(1))
    entries = []
    for key in sorted(found):
        item = {"key": key, **PERSISTENCE_METADATA[key], **found[key]}
        entries.append(item)
    return {
        "schemaVersion": SCHEMA_VERSION,
        "contract": "synapse-local-persistence",
        "sources": [source_ref(root, path) for path in files if any(item["source"] == path.relative_to(root).as_posix() for item in found.values())]
        + [source_ref(root, version_path)],
        "appSchemaVersion": app_schema_version,
        "keys": entries,
        "invariants": {
            "unknownKeysFailGeneration": True,
            "keyRenameRequiresAliasOrMigration": True,
            "schemaVersionIncrementRequiresForwardMigration": True,
        },
        "summary": {"keyCount": len(entries)},
    }


@dataclass(frozen=True)
class SqlObject:
    name: str
    migration: str
    source_line: int


def _sql_objects(root: Path, pattern: str) -> list[SqlObject]:
    items: list[SqlObject] = []
    for path in sorted((root / "supabase/migrations").glob("*.sql")):
        text = path.read_text(encoding="utf-8")
        for match in re.finditer(pattern, text, re.I | re.S):
            items.append(SqlObject(match.group("name"), path.name, line_number(text, match.start())))
    return items


def _sql_item(item: SqlObject) -> dict[str, Any]:
    return {"name": item.name, "migration": item.migration, "sourceLine": item.source_line}


def build_supabase_contract(root: Path) -> dict[str, Any]:
    migration_paths = sorted((root / "supabase/migrations").glob("*.sql"))
    if not migration_paths:
        raise ValueError("No Supabase migrations found")
    tables = _sql_objects(root, r"create\s+table\s+if\s+not\s+exists\s+public\.(?P<name>[A-Za-z_]\w*)")
    functions = _sql_objects(root, r"create\s+or\s+replace\s+function\s+public\.(?P<name>[A-Za-z_]\w*)\s*\(")
    views = _sql_objects(root, r"create\s+or\s+replace\s+view\s+public\.(?P<name>[A-Za-z_]\w*)")
    triggers = _sql_objects(root, r"create\s+trigger\s+(?P<name>[A-Za-z_]\w*)\b")
    policies = _sql_objects(root, r"create\s+policy\s+(?P<name>[A-Za-z_]\w*)\b")
    rls_tables = _sql_objects(root, r"alter\s+table\s+public\.(?P<name>[A-Za-z_]\w*)\s+enable\s+row\s+level\s+security")
    revoked_functions = _sql_objects(root, r"revoke\s+execute\s+on\s+function\s+public\.(?P<name>[A-Za-z_]\w*)\s*\(")
    return {
        "schemaVersion": SCHEMA_VERSION,
        "contract": "synapse-supabase-schema",
        "migrations": [source_ref(root, path) for path in migration_paths],
        "tables": [_sql_item(item) for item in tables],
        "functions": [_sql_item(item) for item in functions],
        "views": [_sql_item(item) for item in views],
        "triggers": [_sql_item(item) for item in triggers],
        "policies": [_sql_item(item) for item in policies],
        "rlsEnabledTables": [_sql_item(item) for item in rls_tables],
        "executeRevokedFunctions": [_sql_item(item) for item in revoked_functions],
        "invariants": {
            "fixturesContainSecrets": False,
            "migrationOrder": "lexicographic filename order",
            "futureChangesAreForwardOnly": True,
        },
        "summary": {
            "migrationCount": len(migration_paths),
            "tableCount": len(tables),
            "functionCount": len(functions),
            "viewCount": len(views),
            "triggerCount": len(triggers),
            "policyCount": len(policies),
            "rlsTableCount": len(rls_tables),
        },
    }


def generate_all(root: Path) -> dict[str, dict[str, Any]]:
    return {
        "routes.v1.json": build_routes_contract(root),
        "modules.v1.json": build_modules_contract(root),
        "persistence.v1.json": build_persistence_contract(root),
        "supabase.v1.json": build_supabase_contract(root),
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output-dir", type=Path, default=None)
    parser.add_argument("--check", action="store_true", help="Fail when committed fixtures differ from generated output.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = args.repo_root.resolve()
    output_dir = (args.output_dir or (root / "tool/preservation/fixtures")).resolve()
    generated = generate_all(root)
    if args.check:
        failures: list[str] = []
        for name, value in generated.items():
            path = output_dir / name
            expected = canonical_json(value)
            if not path.exists():
                failures.append(f"missing {path.relative_to(root) if path.is_relative_to(root) else path}")
            elif path.read_text(encoding="utf-8") != expected:
                failures.append(f"stale {path.relative_to(root) if path.is_relative_to(root) else path}")
        if failures:
            print("Preservation contracts FAILED:")
            for failure in failures:
                print(f"- {failure}")
            print("Run: python tool/preservation/generate_contracts.py")
            return 1
        print(f"Preservation contracts OK: {len(generated)} deterministic fixtures")
        return 0

    output_dir.mkdir(parents=True, exist_ok=True)
    for name, value in generated.items():
        (output_dir / name).write_text(canonical_json(value), encoding="utf-8", newline="\n")
    summary = ", ".join(f"{name}={value['summary']}" for name, value in generated.items())
    print(f"Wrote {len(generated)} preservation contracts to {output_dir}")
    print(summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
