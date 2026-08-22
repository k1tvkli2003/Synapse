#!/usr/bin/env python3
"""Generate the immutable pre-rebuild compatibility baseline for Synapse.

The generator intentionally reads source instead of importing the Flutter app.
That keeps the preservation gate runnable even when a host cannot resolve the
full six-platform Flutter toolchain. The independent verifier recomputes every
payload, checks cross-contract invariants, and compares installed snapshots.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "contracts" / "preservation"
SCHEMA_VERSION = 1
SOURCE_DATE = "2026-07-21"

ROUTES_SOURCE = ROOT / "apps" / "app" / "lib" / "router" / "routes.dart"
ROUTER_SOURCE = ROOT / "apps" / "app" / "lib" / "router" / "router.dart"
MODULE_SOURCE = ROOT / "packages" / "core" / "lib" / "src" / "models" / "module_key.dart"
LIBRARY_SOURCE = ROOT / "packages" / "core" / "lib" / "src" / "models" / "library.dart"
PERSISTENCE_SOURCE = ROOT / "apps" / "app" / "lib" / "state" / "persistence.dart"
SESSION_PROGRESS_SOURCE = (
    ROOT
    / "packages"
    / "services"
    / "lib"
    / "src"
    / "curriculum"
    / "curriculum_session_progress_repository.dart"
)
STUDY_WORKSPACE_SOURCE = (
    ROOT
    / "packages"
    / "services"
    / "lib"
    / "src"
    / "curriculum"
    / "curriculum_study_workspace_repository.dart"
)
READING_STATE_SOURCE = (
    ROOT
    / "packages"
    / "services"
    / "lib"
    / "src"
    / "curriculum"
    / "curriculum_reading_state_repository.dart"
)
RESOURCE_WORKSPACE_SOURCE = (
    ROOT
    / "packages"
    / "services"
    / "lib"
    / "src"
    / "workspace"
    / "resource_workspace_repository.dart"
)
DOCUMENT_READING_STATE_SOURCE = (
    ROOT
    / "packages"
    / "services"
    / "lib"
    / "src"
    / "workspace"
    / "resource_document_reading_state_repository.dart"
)
VERSION_SOURCE = ROOT / "packages" / "config" / "lib" / "src" / "version.dart"
CAPABILITY_SOURCE = (
    ROOT
    / "docs"
    / "codex"
    / "2026-07-15-synapse-medical-learning-os"
    / "10-capability-absorption.md"
)
NEW_CAPABILITY_SOURCE = (
    ROOT / "contracts" / "product" / "new-capability-registry.v1.json"
)


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def json_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    ).encode("utf-8")


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def slug(value: str) -> str:
    value = re.sub(r"`[^`]*`", "", value)
    value = value.lower().replace("&", " and ")
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return value or "unnamed"


# These source filenames are technical provenance only.  They retain the
# stable capability IDs issued by the original preservation ledger while the
# learner-facing map uses functional Synapse names.
LEGACY_WORKSPACE_ARTIFACT_IDS = {
    "*_find.ts": "find-mode",
    "*_summary.ts": "summary-mode",
    "*_enrich.ts": "enrich-mode",
    "*_quiz.ts": "quiz-mode",
}


def normalize_space(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def mask_literals_and_comments(text: str) -> str:
    """Return equal-length Dart text with literals/comments replaced by spaces."""

    chars = list(text)
    i = 0
    state = "code"
    quote = ""
    while i < len(chars):
        ch = chars[i]
        nxt = chars[i + 1] if i + 1 < len(chars) else ""
        if state == "code":
            if ch in {"'", '"'}:
                quote = ch
                chars[i] = " "
                state = "string"
            elif ch == "/" and nxt == "/":
                chars[i] = chars[i + 1] = " "
                i += 1
                state = "line_comment"
            elif ch == "/" and nxt == "*":
                chars[i] = chars[i + 1] = " "
                i += 1
                state = "block_comment"
        elif state == "string":
            chars[i] = " "
            if ch == "\\" and i + 1 < len(chars):
                chars[i + 1] = " "
                i += 1
            elif ch == quote:
                state = "code"
        elif state == "line_comment":
            if ch == "\n":
                state = "code"
            else:
                chars[i] = " "
        elif state == "block_comment":
            chars[i] = " "
            if ch == "*" and nxt == "/":
                chars[i + 1] = " "
                i += 1
                state = "code"
        i += 1
    return "".join(chars)


def find_matching(text: str, opening: int, opener: str, closer: str) -> int:
    mask = mask_literals_and_comments(text)
    depth = 0
    for index in range(opening, len(mask)):
        ch = mask[index]
        if ch == opener:
            depth += 1
        elif ch == closer:
            depth -= 1
            if depth == 0:
                return index
    raise ValueError(f"unmatched {opener!r} at offset {opening}")


def split_top_level(text: str, delimiter: str = ",") -> list[str]:
    mask = mask_literals_and_comments(text)
    parts: list[str] = []
    start = 0
    stack: list[str] = []
    pairs = {")": "(", "]": "[", "}": "{"}
    for index, ch in enumerate(mask):
        if ch in "([{":
            stack.append(ch)
        elif ch in ")]}":
            if stack and stack[-1] == pairs[ch]:
                stack.pop()
        elif ch == delimiter and not stack:
            parts.append(text[start:index].strip())
            start = index + 1
    parts.append(text[start:].strip())
    return [part for part in parts if part]


def named_argument(body: str, name: str) -> str | None:
    mask = mask_literals_and_comments(body)
    depth = 0
    pairs = {")": "(", "]": "[", "}": "{"}
    stack: list[str] = []
    pattern = re.compile(rf"\b{re.escape(name)}\s*:")
    for match in pattern.finditer(mask):
        prefix = mask[: match.start()]
        stack.clear()
        for ch in prefix:
            if ch in "([{":
                stack.append(ch)
            elif ch in ")]}":
                if stack and stack[-1] == pairs[ch]:
                    stack.pop()
        depth = len(stack)
        if depth != 0:
            continue
        expr_start = match.end()
        local_stack: list[str] = []
        for index in range(expr_start, len(mask)):
            ch = mask[index]
            if ch in "([{":
                local_stack.append(ch)
            elif ch in ")]}":
                if local_stack and local_stack[-1] == pairs[ch]:
                    local_stack.pop()
            elif ch == "," and not local_stack:
                return body[expr_start:index].strip()
        return body[expr_start:].strip()
    return None


@dataclass(frozen=True)
class CallBlock:
    start: int
    opening: int
    end: int
    body: str


def call_blocks(text: str, call_pattern: str) -> list[CallBlock]:
    blocks: list[CallBlock] = []
    for match in re.finditer(call_pattern, mask_literals_and_comments(text)):
        opening = text.find("(", match.start(), match.end() + 1)
        if opening < 0:
            continue
        end = find_matching(text, opening, "(", ")")
        blocks.append(CallBlock(match.start(), opening, end, text[opening + 1 : end]))
    return blocks


def dart_string(expression: str) -> str:
    expression = expression.strip()
    if not expression or expression[0] not in {"'", '"'}:
        raise ValueError(f"expected Dart string literal, got {expression!r}")
    try:
        value = ast.literal_eval(expression)
        if isinstance(value, str):
            return value
    except (SyntaxError, ValueError):
        pass
    quote = expression[0]
    if expression[-1] != quote:
        raise ValueError(f"unterminated Dart string literal: {expression!r}")
    return expression[1:-1].replace(r"\'", "'").replace(r'\"', '"')


def parse_route_constants(source: str) -> dict[str, str]:
    constants: dict[str, str] = {}
    pattern = re.compile(
        r"static\s+const\s+(?P<name>\w+)\s*=\s*(?P<value>'(?:\\.|[^'])*'|\"(?:\\.|[^\"])*\")\s*;"
    )
    for match in pattern.finditer(source):
        constants[match.group("name")] = dart_string(match.group("value"))
    return constants


def parse_library_routes(source: str) -> dict[str, str]:
    match = re.search(r"String\s+get\s+route\s*=>\s*switch\s*\(this\)\s*\{(?P<body>.*?)\};", source, re.S)
    if not match:
        raise ValueError("LibraryKind.route switch not found")
    routes: dict[str, str] = {}
    for item in re.finditer(
        r"LibraryKind\.(?P<kind>\w+)\s*=>\s*(?P<path>'(?:\\.|[^'])*'|\"(?:\\.|[^\"])*\")",
        match.group("body"),
    ):
        routes[item.group("kind")] = dart_string(item.group("path"))
    if len(routes) != 5:
        raise ValueError(f"expected five LibraryKind routes, found {len(routes)}")
    return routes


def expand_router_path(
    expression: str,
    constants: dict[str, str],
    library_routes: dict[str, str],
) -> list[tuple[str, str | None]]:
    expression = expression.strip()
    constant_match = re.fullmatch(r"Routes\.(\w+)", expression)
    if constant_match:
        name = constant_match.group(1)
        if name not in constants:
            raise ValueError(f"unknown route constant: {expression}")
        return [(constants[name], None)]
    if expression == "kind.route":
        return [(path, kind) for kind, path in library_routes.items()]
    if expression.startswith(("'", '"')):
        value = dart_string(expression)
        if "${kind.route}" in value:
            return [
                (value.replace("${kind.route}", path), kind)
                for kind, path in library_routes.items()
            ]
        return [(value, None)]
    raise ValueError(f"unsupported GoRoute path expression: {expression}")


def path_shape(path: str) -> tuple[str, ...]:
    path = path.split("?", 1)[0]
    return tuple("*" if segment.startswith(":") else segment for segment in path.split("/") if segment)


def concrete_path(pattern: str, query_parameters: Iterable[str] = ()) -> str:
    result = re.sub(r":([A-Za-z_]\w*)", lambda m: f"fixture-{m.group(1)}", pattern)
    query = []
    for name in query_parameters:
        value = "fixture-a,fixture-b" if name == "ids" else f"fixture-{name}"
        query.append(f"{name}={value}")
    if query:
        result += ("&" if "?" in result else "?") + "&".join(query)
    return result


def parse_router() -> tuple[list[dict[str, Any]], dict[str, str], dict[str, str]]:
    routes_source = ROUTES_SOURCE.read_text(encoding="utf-8")
    router_source = ROUTER_SOURCE.read_text(encoding="utf-8")
    constants = parse_route_constants(routes_source)
    library_routes = parse_library_routes(LIBRARY_SOURCE.read_text(encoding="utf-8"))
    blocks = call_blocks(router_source, r"\bGoRoute\s*\(")
    shell_blocks = call_blocks(router_source, r"\bStatefulShellRoute\.indexedStack\s*\(")
    if len(shell_blocks) != 1:
        raise ValueError(f"expected one StatefulShellRoute, found {len(shell_blocks)}")
    shell_range = shell_blocks[0]

    parents: dict[int, int | None] = {}
    for index, block in enumerate(blocks):
        containers = [
            (other.end - other.start, other_index)
            for other_index, other in enumerate(blocks)
            if other.start < block.start and other.end > block.end
        ]
        parents[index] = min(containers)[1] if containers else None

    resolved: dict[int, list[tuple[str, str | None]]] = {}
    branches: dict[int, str | None] = {}
    records: list[dict[str, Any]] = []
    shell_roots = {
        "/home": "home",
        "/learn": "learn",
        "/clinical": "clinical",
        "/social": "social",
        "/profile": "profile",
    }

    for index, block in enumerate(blocks):
        path_expression = named_argument(block.body, "path")
        if path_expression is None:
            raise ValueError(f"GoRoute at line {line_number(router_source, block.start)} has no path")
        expanded = expand_router_path(path_expression, constants, library_routes)
        parent_index = parents[index]
        if parent_index is not None:
            parent_paths = resolved[parent_index]
            if len(parent_paths) != 1:
                raise ValueError("dynamic GoRoute cannot own nested static routes")
            parent_path = parent_paths[0][0].rstrip("/")
            expanded = [
                (
                    path if path.startswith("/") else f"{parent_path}/{path.lstrip('/')}",
                    variant,
                )
                for path, variant in expanded
            ]
        resolved[index] = expanded

        inherited_branch = branches.get(parent_index) if parent_index is not None else None
        own_branch = inherited_branch
        if shell_range.start < block.start < shell_range.end:
            for path, _ in expanded:
                if path in shell_roots:
                    own_branch = shell_roots[path]
                    break
        branches[index] = own_branch

        builder_expression = named_argument(block.body, "builder") or ""
        builder_match = re.search(r"=>\s*(?:const\s+)?([A-Za-z_]\w*)", builder_expression)
        builder = builder_match.group(1) if builder_match else "unknown"
        query_parameters = sorted(
            set(re.findall(r"queryParameters\[['\"]([^'\"]+)['\"]\]", builder_expression))
        )
        for path, variant in expanded:
            path_parameters = re.findall(r":([A-Za-z_]\w*)", path)
            record_id = "route:" + path
            if variant:
                record_id += f"#{variant}"
            records.append(
                {
                    "id": record_id,
                    "path": path,
                    "pathExpression": normalize_space(path_expression),
                    "pathParameters": path_parameters,
                    "queryParameters": query_parameters,
                    "shellBranch": own_branch,
                    "presentation": "shell" if own_branch else "root",
                    "intent": builder,
                    "source": relative(ROUTER_SOURCE),
                    "sourceLine": line_number(router_source, block.start),
                    "variant": variant,
                    "sampleLocation": concrete_path(path, query_parameters),
                }
            )

    paths = [record["path"] for record in records]
    duplicates = sorted({path for path in paths if paths.count(path) > 1})
    if duplicates:
        raise ValueError(f"duplicate resolved GoRoute paths: {duplicates}")
    return records, constants, library_routes


def helper_output(
    expression: str,
    parameters: list[str],
    library_routes: dict[str, str],
    constants: dict[str, str],
) -> list[tuple[str, str | None]]:
    normalized = normalize_space(expression)
    uri_match = re.fullmatch(
        r"Uri\(\s*path:\s*([A-Za-z_]\w*)\s*,\s*queryParameters:\s*\{(.*?)\}\s*,?\s*\)\.toString\(\)",
        normalized,
    )
    if uri_match:
        path_name = uri_match.group(1)
        if path_name not in constants:
            raise ValueError(f"URI helper references unknown path constant {path_name}")
        query_pairs = re.findall(
            r"['\"]([^'\"]+)['\"]\s*:\s*([A-Za-z_]\w*)",
            uri_match.group(2),
        )
        if not query_pairs or any(value not in parameters for _, value in query_pairs):
            raise ValueError("URI helper has an unknown or empty query-parameter map")
        query = "&".join(f"{name}=fixture-{value}" for name, value in query_pairs)
        return [(f"{constants[path_name]}?{query}", None)]

    value = dart_string(expression.strip())
    variants: list[tuple[str, str | None]] = [(value, None)]
    if "${kind.route}" in value:
        variants = [
            (value.replace("${kind.route}", route), kind)
            for kind, route in library_routes.items()
        ]
    output: list[tuple[str, str | None]] = []
    samples = {name: f"fixture-{name}" for name in parameters}
    samples["ids"] = "fixture-a,fixture-b"
    for candidate, variant in variants:
        candidate = candidate.replace("${ids.join(',')}", samples["ids"])
        for name, sample in samples.items():
            candidate = candidate.replace(f"${{{name}}}", sample).replace(f"${name}", sample)
        output.append((candidate, variant))
    return output


def match_registered_route(
    location: str,
    routes: list[dict[str, Any]],
    *,
    require_query_parameters: bool = True,
) -> dict[str, Any] | None:
    location_path, _, query = location.partition("?")
    location_shape = tuple(location_path.split("/")[1:])
    query_names = {part.split("=", 1)[0] for part in query.split("&") if part}
    for route in routes:
        pattern_segments = route["path"].split("/")[1:]
        if len(pattern_segments) != len(location_shape):
            continue
        if not all(
            pattern.startswith(":") or pattern == actual
            for pattern, actual in zip(pattern_segments, location_shape, strict=True)
        ):
            continue
        if require_query_parameters and not set(route["queryParameters"]).issubset(
            query_names
        ):
            continue
        return route
    return None


def parse_route_helpers(
    routes: list[dict[str, Any]],
    constants: dict[str, str],
    library_routes: dict[str, str],
) -> list[dict[str, Any]]:
    source = ROUTES_SOURCE.read_text(encoding="utf-8")
    helpers: list[dict[str, Any]] = []
    for name, path in sorted(constants.items()):
        matched = match_registered_route(
            path,
            routes,
            require_query_parameters=False,
        )
        helpers.append(
            {
                "name": name,
                "kind": "constant",
                "parameters": [],
                "sampleOutput": path,
                "matchedRouteId": matched["id"] if matched else None,
            }
        )

    function_pattern = re.compile(
        r"^\s*static\s+String\s+(?P<name>\w+)\s*\((?P<params>.*?)\)\s*=>\s*(?P<expr>.*?);\s*$",
        re.M | re.S,
    )
    for match in function_pattern.finditer(source):
        raw_parameters = split_top_level(match.group("params"))
        parameters = []
        for item in raw_parameters:
            parameter = re.search(r"([A-Za-z_]\w*)\s*$", item)
            if parameter is None:
                raise ValueError(
                    f"cannot parse parameter {item!r} for Routes.{match.group('name')}"
                )
            parameters.append(parameter.group(1))
        outputs = helper_output(
            match.group("expr"),
            parameters,
            library_routes,
            constants,
        )
        for output, variant in outputs:
            matched = match_registered_route(output, routes)
            helpers.append(
                {
                    "name": match.group("name"),
                    "kind": "function",
                    "parameters": parameters,
                    "variant": variant,
                    "sampleOutput": output,
                    "matchedRouteId": matched["id"] if matched else None,
                }
            )

    helpers.extend(
        [
            {
                "name": "BuildContext.goConcept",
                "kind": "extension-delegate",
                "parameters": ["id"],
                "delegate": "Routes.concept",
                "sampleOutput": "/concept/fixture-id",
                "matchedRouteId": (
                    match_registered_route("/concept/fixture-id", routes) or {}
                ).get("id"),
            },
            {
                "name": "BuildContext.goRoute",
                "kind": "generic-passthrough",
                "parameters": ["route"],
                "policy": "caller must supply a location from the central registry or compatibility table",
                "sampleOutput": "/home",
                "matchedRouteId": (match_registered_route("/home", routes) or {}).get("id"),
            },
        ]
    )
    return sorted(helpers, key=lambda item: (item["name"], item.get("variant") or ""))


def enum_values(body: str) -> list[str]:
    mask = mask_literals_and_comments(body)
    depth = 0
    cutoff = len(body)
    for index, ch in enumerate(mask):
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == ";" and depth == 0:
            cutoff = index
            break
    entries = split_top_level(body[:cutoff])
    values: list[str] = []
    for entry in entries:
        match = re.match(r"\s*([A-Za-z_]\w*)", entry)
        if match:
            values.append(match.group(1))
    return values


def parse_enums() -> list[dict[str, Any]]:
    roots = [
        ROOT / "packages" / "core" / "lib" / "src" / "models",
        ROOT / "apps" / "app" / "lib" / "state",
    ]
    records: list[dict[str, Any]] = []
    for source_path in sorted(path for root in roots for path in root.glob("*.dart")):
        source = source_path.read_text(encoding="utf-8")
        mask = mask_literals_and_comments(source)
        for match in re.finditer(r"\benum\s+([A-Za-z_]\w*)\s*\{", mask):
            opening = source.find("{", match.start(), match.end())
            end = find_matching(source, opening, "{", "}")
            values = enum_values(source[opening + 1 : end])
            records.append(
                {
                    "name": match.group(1),
                    "values": values,
                    "source": relative(source_path),
                    "sourceLine": line_number(source, match.start()),
                }
            )
    return sorted(records, key=lambda item: item["name"])


def parse_module_registry(enums: list[dict[str, Any]]) -> dict[str, Any]:
    source = MODULE_SOURCE.read_text(encoding="utf-8")
    modules: list[dict[str, Any]] = []
    pattern = re.compile(
        r"^\s{2}(?P<id>[A-Za-z_]\w*)\(\s*"
        r"title:\s*'(?P<title>[^']*)',\s*"
        r"source:\s*'(?P<source>[^']*)',\s*"
        r"branch:\s*ShellBranch\.(?P<branch>\w+),\s*"
        r"tagline:\s*'(?P<tagline>[^']*)',\s*"
        r"accentHex:\s*(?P<accent>0x[0-9A-Fa-f]+),\s*\)",
        re.M,
    )
    for ordinal, match in enumerate(pattern.finditer(source)):
        modules.append(
            {
                "id": match.group("id"),
                "ordinal": ordinal,
                "title": match.group("title"),
                "sourceIdea": match.group("source"),
                "shellBranch": match.group("branch"),
                "tagline": match.group("tagline"),
                "accentArgb": match.group("accent").upper(),
            }
        )
    shell = next(item for item in enums if item["name"] == "ShellBranch")
    return {
        "schemaVersion": SCHEMA_VERSION,
        "sourceDate": SOURCE_DATE,
        "canonicalOwner": relative(MODULE_SOURCE),
        "shellBranches": [
            {"id": value, "ordinal": ordinal}
            for ordinal, value in enumerate(shell["values"])
        ],
        "modules": modules,
        "serializedEnums": enums,
    }


PERSISTENCE_METADATA: dict[str, dict[str, Any]] = {
    "__synapse_schema": {
        "owner": "PersistedStore",
        "type": "int",
        "default": "appSchemaVersion",
        "version": 1,
        "migration": "v1 initializes missing values; current legacy behavior restamps mismatches without shape migration",
        "risk": "restamp-only behavior must be replaced by explicit forward migrations before schema v2",
    },
    "profile": {
        "owner": "UserNotifier",
        "type": "json:UserProfile",
        "default": "DemoSeed.user",
        "version": 1,
        "migration": "decode with UserProfile.fromJson; preserve unknown future keys through a versioned adapter before schema changes",
    },
    "settings": {
        "owner": "SettingsNotifier",
        "type": "json:UserPrefs",
        "default": "const UserPrefs()",
        "version": 1,
        "migration": "decode with UserPrefs.fromJson defaults; locale/theme/motion keys remain backward compatible",
    },
    "onboarded": {
        "owner": "SettingsNotifier",
        "type": "bool",
        "default": False,
        "version": 1,
        "migration": "missing remains false; never reset true during shell rebuild",
    },
    "game_state": {
        "owner": "GameNotifier",
        "type": "json:GamificationState",
        "default": "const GamificationState()",
        "version": 1,
        "migration": "decode with GamificationState.fromJson; future reward ledger imports this as a non-authoritative legacy projection",
    },
    "mastery": {
        "owner": "GameNotifier",
        "type": "json:Map<ConceptId,ConceptMastery>",
        "default": {},
        "version": 1,
        "migration": "decode each entry with ConceptMastery.fromJson; preserve concept IDs and per-module enum names",
    },
    "counters": {
        "owner": "GameNotifier",
        "type": "json:Map<String,int>",
        "default": {},
        "version": 1,
        "migration": "preserve metric keys and integer totals; map into canonical achievement counters without duplicate grants",
    },
    "unlocked_at": {
        "owner": "GameNotifier",
        "type": "json:Map<String,ISO-8601>",
        "default": {},
        "version": 1,
        "migration": "preserve achievement IDs and earliest valid unlock timestamps",
    },
    "quests": {
        "owner": "GameNotifier",
        "type": "json:{list:List<Quest>}",
        "default": "DemoSeed.quests()",
        "version": 1,
        "migration": "preserve quest IDs/progress; legacy rewards are not re-granted during import",
    },
    "srs_cards": {
        "owner": "SrsNotifier",
        "type": "json:{list:List<SrsCard>}",
        "default": "ContentRepository.seedCards(userId)",
        "version": 1,
        "migration": "round-trip SrsCard IDs, origin, schedule, dueAt, lapses, and reps before scheduler replacement",
    },
    "study_plan_done": {
        "owner": "StudyPlanNotifier",
        "type": "json:{date:String,ids:List<String>}",
        "default": {"date": "current-local-day", "ids": []},
        "version": 1,
        "migration": "preserve same-day task IDs as completion hints; never convert them directly into mastery evidence",
    },
    "personalization": {
        "owner": "PersonalizationNotifier",
        "type": "json:Personalization",
        "default": {"tier": "free", "owned": []},
        "version": 1,
        "migration": "preserve cosmetic IDs/equipment; local tier is not trusted as server entitlement",
    },
    "motion_presentation_queue_v1": {
        "owner": "PresentationQueueController",
        "type": "json:PresentationQueue",
        "default": "empty authoritative presentation-receipt queue",
        "version": 1,
        "migration": "optional UI presentation state; recover to an empty queue on malformed or future snapshots without changing rewards or learning progress",
    },
    "__synapse_curriculum_session_progress_v1": {
        "owner": "LocalCurriculumSessionProgressRepository",
        "type": "json:CurriculumSessionProgressRegistry.v1",
        "default": {"schemaVersion": 1, "records": {}},
        "version": 1,
        "migration": "preserve release-bound checkpoint IDs and receipts; unsupported future schemas fail closed and remain stored until an explicit forward migration is verified",
        "risk": "whole-registry writes are a bounded v1 adapter and must migrate to indexed/event storage before production-scale history",
    },
    "__synapse_curriculum_study_workspace_v1": {
        "owner": "LocalCurriculumStudyWorkspaceRepository",
        "type": "json:CurriculumStudyWorkspaceRegistry.v1",
        "default": {"schemaVersion": 1, "records": {}},
        "version": 1,
        "migration": "preserve stable source-and-node workspace IDs, note IDs, author locales, bookmarks, focus totals, release provenance and revisions; unsupported future schemas fail closed and remain stored until an explicit forward migration is verified",
        "risk": "personal learner material is private and irreplaceable; the bounded whole-registry adapter must migrate by journaled copy-and-verify into indexed privacy-ready storage without orphaning notes across curriculum releases",
    },
    "__synapse_curriculum_reading_state_v1": {
        "owner": "LocalCurriculumReadingStateRepository",
        "type": "json:CurriculumReadingStateRegistry.v1",
        "default": {
            "schemaVersion": 1,
            "records": {},
            "integrity": {"recordCount": 0, "positionPermilleTotal": 0},
        },
        "version": 1,
        "migration": "preserve stable source, Micro-lesson, document, Block and localization-unit IDs plus ordinal/permille, locale/release provenance, revisions and timestamps; never convert navigation position into completion, mastery or rewards",
        "risk": "semantic learner continuity must migrate separately from immutable package bodies and Session progress; unsupported/corrupt registries fail independently and remain stored for explicit recovery",
    },
    "__synapse_resource_workspace_v1": {
        "owner": "LocalResourceWorkspaceRepository",
        "type": "json:ResourceWorkspaceRegistry.v1",
        "default": {
            "schemaVersion": 1,
            "documents": {},
            "anchors": {},
            "annotations": {},
            "bookmarks": {},
            "crossReferences": {},
            "integrity": {
                "documentCount": 0,
                "anchorCount": 0,
                "annotationCount": 0,
                "bookmarkCount": 0,
                "crossReferenceCount": 0,
                "uniqueBlobCount": 0,
                "uniqueBlobBytes": 0,
            },
        },
        "version": 1,
        "migration": "preserve content-addressed document metadata, universal resource and anchor identities, private annotation revisions, bookmark tombstones and resource cross-reference tombstones; reconcile every relationship and digest before indexed-storage promotion",
        "risk": "learner annotations and bookmarks are private and irreplaceable; the bounded bootstrap registry excludes binary bytes and must migrate by journaled copy-and-verify without reviving tombstones or reusing legacy PDF IDs as ownership",
    },
    "__synapse_resource_document_reading_state_v1": {
        "owner": "LocalResourceDocumentReadingStateRepository",
        "type": "json:ResourceDocumentReadingStateRegistry.v1",
        "default": {
            "schemaVersion": 1,
            "records": {},
            "integrity": {
                "recordCount": 0,
                "pageNumberTotal": 0,
                "revisionTotal": 0,
            },
        },
        "version": 1,
        "migration": "preserve document ID, immutable content digest, bounded page position, revisions and timestamps; never translate document navigation into lesson completion, mastery, XP or streak state",
        "risk": "private resume continuity is additive and reward-neutral; migrate independently from document blobs, universal annotations and curriculum checkpoints, with copy-and-verify before deleting the legacy key",
    },
}


def parse_persistence_inventory() -> dict[str, Any]:
    state_root = ROOT / "apps" / "app" / "lib" / "state"
    call_pattern = re.compile(
        r"\.(readJson|writeJson|readBool|writeBool|read|write)\s*\(([^,\)]+)"
    )
    call_sites: dict[str, list[dict[str, Any]]] = {}
    discovered: set[str] = {"__synapse_schema"}
    persistence_sources = [
        *sorted(state_root.glob("*.dart")),
        SESSION_PROGRESS_SOURCE,
        STUDY_WORKSPACE_SOURCE,
        READING_STATE_SOURCE,
        RESOURCE_WORKSPACE_SOURCE,
        DOCUMENT_READING_STATE_SOURCE,
    ]
    for source_path in persistence_sources:
        source = source_path.read_text(encoding="utf-8")
        constants = {
            match.group("name"): match.group("value")
            for match in re.finditer(
                r"(?:static\s+)?const\s+(?P<name>[A-Za-z_]\w*)\s*=\s*'(?P<value>[^']+)'",
                source,
            )
        }
        for match in call_pattern.finditer(source):
            argument = match.group(2).strip()
            if argument.startswith("'") and argument.endswith("'"):
                key = argument[1:-1]
            elif argument in constants:
                key = constants[argument]
            else:
                continue
            discovered.add(key)
            call_sites.setdefault(key, []).append(
                {
                    "operation": match.group(1),
                    "source": relative(source_path),
                    "sourceLine": line_number(source, match.start()),
                }
            )
    missing_metadata = sorted(discovered - PERSISTENCE_METADATA.keys())
    stale_metadata = sorted(PERSISTENCE_METADATA.keys() - discovered)
    if missing_metadata or stale_metadata:
        raise ValueError(
            f"persistence metadata drift: missing={missing_metadata}, stale={stale_metadata}"
        )
    entries = []
    for key in sorted(discovered):
        entry = {"key": key, **PERSISTENCE_METADATA[key]}
        entry["callSites"] = call_sites.get(
            key,
            [
                {
                    "operation": "schemaStamp",
                    "source": relative(PERSISTENCE_SOURCE),
                    "sourceLine": 11,
                }
            ],
        )
        entries.append(entry)
    version_source = VERSION_SOURCE.read_text(encoding="utf-8")
    version_match = re.search(r"const\s+int\s+appSchemaVersion\s*=\s*(\d+)", version_source)
    return {
        "schemaVersion": SCHEMA_VERSION,
        "sourceDate": SOURCE_DATE,
        "appSchemaVersion": int(version_match.group(1)) if version_match else None,
        "canonicalOwner": relative(PERSISTENCE_SOURCE),
        "entries": entries,
        "invariants": [
            "no key may be renamed or removed without a versioned migration and rollback fixture",
            "missing or malformed data must not erase unrelated keys",
            "reward and entitlement projections remain untrusted during server-authority migration",
        ],
    }


def sql_statements(text: str) -> list[str]:
    statements: list[str] = []
    start = 0
    i = 0
    in_single = False
    in_double = False
    in_dollar = False
    in_line_comment = False
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if in_line_comment:
            if ch == "\n":
                in_line_comment = False
            i += 1
            continue
        if not in_single and not in_double and not in_dollar and ch == "-" and nxt == "-":
            in_line_comment = True
            i += 2
            continue
        if not in_double and not in_dollar and ch == "'":
            in_single = not in_single
        elif not in_single and not in_dollar and ch == '"':
            in_double = not in_double
        elif not in_single and not in_double and text.startswith("$$", i):
            in_dollar = not in_dollar
            i += 1
        elif ch == ";" and not in_single and not in_double and not in_dollar:
            statement = text[start : i + 1].strip()
            if statement:
                statements.append(statement)
            start = i + 1
        i += 1
    tail = text[start:].strip()
    if tail:
        statements.append(tail)
    return statements


def parse_table_columns(body: str) -> tuple[list[dict[str, str]], list[str]]:
    columns: list[dict[str, str]] = []
    constraints: list[str] = []
    for part in split_top_level(body):
        normalized = normalize_space(part)
        if re.match(r"(?i)^(primary|unique|foreign|check|constraint)\b", normalized):
            constraints.append(normalized)
            continue
        match = re.match(r'(?P<name>"[^"]+"|[A-Za-z_]\w*)\s+(?P<definition>.*)', normalized)
        if match:
            columns.append(
                {
                    "name": match.group("name").strip('"'),
                    "definition": match.group("definition"),
                }
            )
    return columns, constraints


def parse_supabase_schema() -> dict[str, Any]:
    migration_root = ROOT / "supabase" / "migrations"
    migration_paths = sorted(migration_root.glob("*.sql"))
    tables: dict[str, dict[str, Any]] = {}
    policies: list[dict[str, Any]] = []
    triggers: list[dict[str, Any]] = []
    functions: list[dict[str, Any]] = []
    views: list[dict[str, Any]] = []
    rls_tables: set[str] = set()
    revocations: list[str] = []
    migrations: list[dict[str, Any]] = []
    secret_findings: list[dict[str, Any]] = []

    for migration_path in migration_paths:
        source = migration_path.read_text(encoding="utf-8")
        migration_name = relative(migration_path)
        migrations.append(
            {
                "path": migration_name,
                "sha256": sha256_file(migration_path),
                "bytes": migration_path.stat().st_size,
            }
        )
        for pattern in [r"(?i)password\s*=", r"(?i)service_role\s*[:=]", r"eyJ[A-Za-z0-9_-]{30,}"]:
            for finding in re.finditer(pattern, source):
                secret_findings.append(
                    {"migration": migration_name, "line": line_number(source, finding.start())}
                )

        mask = mask_literals_and_comments(source)
        for match in re.finditer(
            r"(?i)create\s+table\s+if\s+not\s+exists\s+public\.([A-Za-z_]\w*)\s*\(",
            mask,
        ):
            opening = source.find("(", match.start(), match.end())
            end = find_matching(source, opening, "(", ")")
            columns, constraints = parse_table_columns(source[opening + 1 : end])
            name = match.group(1)
            tables[name] = {
                "name": name,
                "columns": columns,
                "constraints": constraints,
                "createdIn": migration_name,
            }

        for statement in sql_statements(source):
            clean_statement = re.sub(r"(?m)--.*$", "", statement).strip()
            if not clean_statement:
                continue
            normalized = normalize_space(clean_statement)
            alter = re.match(r"(?i)alter table public\.([A-Za-z_]\w*)\s+(.*);$", normalized)
            if alter and "add column" in alter.group(2).lower():
                table_name = alter.group(1)
                for addition in re.finditer(
                    r"(?i)add\s+column\s+if\s+not\s+exists\s+([A-Za-z_]\w*)\s+(.+?)(?=,\s*add\s+column|$)",
                    alter.group(2),
                ):
                    tables[table_name]["columns"].append(
                        {
                            "name": addition.group(1),
                            "definition": addition.group(2).strip().rstrip(","),
                            "addedIn": migration_name,
                        }
                    )
            policy = re.match(
                r"(?i)create\s+policy\s+([A-Za-z_]\w*)\s+on\s+public\.([A-Za-z_]\w*)\s+for\s+([A-Za-z_]+)\s+(.*);$",
                normalized,
            )
            if policy:
                remainder = policy.group(4)
                using_match = re.search(r"(?i)using\s*\((.*?)\)(?:\s+with\s+check|$)", remainder)
                check_match = re.search(r"(?i)with\s+check\s*\((.*?)\)$", remainder)
                policies.append(
                    {
                        "name": policy.group(1),
                        "table": policy.group(2),
                        "command": policy.group(3).lower(),
                        "using": using_match.group(1) if using_match else None,
                        "withCheck": check_match.group(1) if check_match else None,
                        "migration": migration_name,
                    }
                )
            trigger = re.match(
                r"(?i)create\s+trigger\s+([A-Za-z_]\w*)\s+(.*?)\s+on\s+((?:public|auth)\.[A-Za-z_]\w*)\s+(.*);$",
                normalized,
            )
            if trigger:
                triggers.append(
                    {
                        "name": trigger.group(1),
                        "timingAndEvent": trigger.group(2),
                        "table": trigger.group(3),
                        "definition": trigger.group(4),
                        "migration": migration_name,
                    }
                )
            function = re.match(
                r"(?is)create\s+or\s+replace\s+function\s+public\.([A-Za-z_]\w*)\s*\((.*?)\)(.*)",
                clean_statement,
            )
            if function:
                functions.append(
                    {
                        "name": function.group(1),
                        "arguments": normalize_space(function.group(2)),
                        "securityDefiner": "security definer" in function.group(3).lower(),
                        "definitionSha256": sha256_bytes(normalized.encode("utf-8")),
                        "migration": migration_name,
                    }
                )
            view = re.match(
                r"(?is)create\s+or\s+replace\s+view\s+public\.([A-Za-z_]\w*)\s+as\s+(.*);$",
                clean_statement,
            )
            if view:
                views.append(
                    {
                        "name": view.group(1),
                        "definition": normalize_space(view.group(2)),
                        "migration": migration_name,
                    }
                )
            rls = re.match(
                r"(?i)alter\s+table\s+public\.([A-Za-z_]\w*)\s+enable\s+row\s+level\s+security;",
                normalized,
            )
            if rls:
                rls_tables.add(rls.group(1))
            if normalized.lower().startswith("revoke execute on function"):
                revocations.append(normalized)

    if secret_findings:
        raise ValueError(f"secret-like values found in migration fixture source: {secret_findings}")
    for table in tables.values():
        table["columns"] = sorted(table["columns"], key=lambda item: item["name"])
    return {
        "schemaVersion": SCHEMA_VERSION,
        "sourceDate": SOURCE_DATE,
        "sanitized": True,
        "migrations": migrations,
        "tables": sorted(tables.values(), key=lambda item: item["name"]),
        "rlsEnabledTables": sorted(rls_tables),
        "policies": sorted(policies, key=lambda item: item["name"]),
        "functions": sorted(functions, key=lambda item: item["name"]),
        "triggers": sorted(triggers, key=lambda item: item["name"]),
        "views": sorted(views, key=lambda item: item["name"]),
        "revocations": sorted(revocations),
        "secretFindings": [],
        "restorePolicy": "apply the immutable 0001..0003 chain to a disposable project; never edit applied migration history or run production rollback from this fixture",
    }


def markdown_table(section_heading: str) -> tuple[list[str], list[list[str]]]:
    lines = CAPABILITY_SOURCE.read_text(encoding="utf-8").splitlines()
    try:
        start = lines.index(section_heading)
    except ValueError as error:
        raise ValueError(f"capability section not found: {section_heading}") from error
    table_lines: list[str] = []
    for line in lines[start + 1 :]:
        if line.startswith("## "):
            break
        if line.startswith("|"):
            table_lines.append(line)
    if len(table_lines) < 2:
        raise ValueError(f"no table in section {section_heading}")

    def cells(line: str) -> list[str]:
        return [cell.strip() for cell in line.strip().strip("|").split("|")]

    headers = cells(table_lines[0])
    rows = [
        cells(line)
        for line in table_lines[2:]
        if not re.fullmatch(r"[|:\-\s]+", line)
    ]
    return headers, rows


def baseline_state(detail: str) -> str:
    value = detail.lower()
    if "dormant" in value:
        return "dormant"
    if "prototype" in value:
        return "prototype"
    if "commitment" in value or "toast" in value:
        return "commitment"
    if "risk" in value or "unsafe" in value or "client-authoritative" in value:
        return "at-risk"
    if "partial" in value or "local" in value or "seed" in value or "limited" in value:
        return "partial"
    if "operational" in value or "schema-protected" in value:
        return "operational"
    return "partial"


def capability_entries_from_docs() -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    sections = [
        (
            "## Existing Synapse Module Absorption",
            "synapse.module",
            "Synapse",
        ),
        (
            "## Existing Synapse Global Capability Absorption",
            "synapse.global",
            "Synapse",
        ),
        (
            "## Legacy Workspace Capability Absorption",
            "studyhub",
            "StudyHUB-Flutter",
        ),
    ]
    for heading, namespace, current_owner in sections:
        headers, rows = markdown_table(heading)
        for row_index, row in enumerate(rows, start=1):
            if len(row) != len(headers):
                raise ValueError(
                    f"capability row width mismatch in {heading}: {row}"
                )
            record = dict(zip(headers, row, strict=True))
            label = row[0]
            baseline = row[1]
            target_owner = row[2]
            target_context = row[3] if len(row) > 3 else target_owner
            if namespace == "synapse.module":
                tokens = re.findall(r"`([^`]+)`", label)
                module_id = next((token for token in tokens if not token.startswith("/")), None)
                if module_id is None:
                    raise ValueError(f"module stable ID missing from {label!r}")
                stable_id = f"{namespace}.{module_id}"
            elif namespace == "studyhub":
                tokens = re.findall(r"`([^`]+)`", label)
                legacy_artifact = next(
                    (token for token in tokens if token in LEGACY_WORKSPACE_ARTIFACT_IDS),
                    None,
                )
                stable_suffix = (
                    LEGACY_WORKSPACE_ARTIFACT_IDS[legacy_artifact]
                    if legacy_artifact is not None
                    else slug(label)
                )
                stable_id = f"{namespace}.{stable_suffix}"
            else:
                stable_id = f"{namespace}.{slug(label)}"
            routes = sorted(set(re.findall(r"`(/[^`]+)`", " | ".join(row))))
            entries.append(
                {
                    "id": stable_id,
                    "label": re.sub(r"\s*/\s*`.*", "", label).strip(),
                    "baselineState": baseline_state(baseline),
                    "baselineDetail": baseline,
                    "currentOwner": current_owner,
                    "canonicalOwner": target_owner,
                    "targetContext": target_context,
                    "currentRoutes": routes,
                    "preservation": row[-1],
                    "verificationOwner": (
                        "contracts/preservation/route-registry.v1.json"
                        if current_owner == "Synapse"
                        else "WBS-321..345 StudyHUB fixture/import gates"
                    ),
                    "source": relative(CAPABILITY_SOURCE),
                    "sourceSection": heading.removeprefix("## "),
                    "sourceRow": row_index,
                }
            )
    return entries


SYSTEM_CAPABILITIES = [
    {
        "id": "synapse.system.onboarding",
        "label": "Splash and onboarding",
        "baselineState": "operational",
        "baselineDetail": "reachable splash and onboarding routes",
        "currentOwner": "Synapse",
        "canonicalOwner": "Unified onboarding",
        "targetContext": "launch",
        "currentRoutes": ["/splash", "/onboarding"],
        "preservation": "cold/warm launch and onboarded persistence remain compatible",
        "verificationOwner": "contracts/preservation/deep-link-fixtures.v1.json",
        "source": relative(ROUTER_SOURCE),
        "sourceSection": "route-only system capability",
        "sourceRow": 1,
    },
    {
        "id": "synapse.system.profile",
        "label": "Profile identity",
        "baselineState": "partial",
        "baselineDetail": "local profile plus public/profile edit routes",
        "currentOwner": "Synapse",
        "canonicalOwner": "You",
        "targetContext": "identity and professional preferences",
        "currentRoutes": ["/profile", "/profile/edit", "/u/:handle"],
        "preservation": "preserve profile ID, handle, role, prefs, and legacy entry points",
        "verificationOwner": "contracts/preservation/archived-domain-fixtures.v1.json",
        "source": relative(ROUTER_SOURCE),
        "sourceSection": "route-only system capability",
        "sourceRow": 2,
    },
]


def capability_for_route(path: str) -> str:
    checks = [
        (("/splash", "/onboarding"), "synapse.system.onboarding"),
        (("/academy/session",), "synapse.academy.learning-session"),
        (("/academy",), "synapse.academy.curriculum-path"),
        (("/copilot",), "synapse.module.copilot"),
        (("/learn/terms",), "synapse.module.terms"),
        (("/learn/cards",), "synapse.module.cards"),
        (("/learn/mnemonics",), "synapse.module.mnemonics"),
        (("/clinical/ecg",), "synapse.module.ecg"),
        (("/clinical/sounds",), "synapse.module.sounds"),
        (("/clinical/labs",), "synapse.module.labs"),
        (("/clinical/algorithms",), "synapse.module.algorithms"),
        (("/clinical/or-lab",), "synapse.module.orLab"),
        (("/social/rounds",), "synapse.module.rounds"),
        (("/social/buddies",), "synapse.module.buddies"),
        (("/social/arena",), "synapse.module.arena"),
        (("/home", "/learn", "/clinical", "/social"), "synapse.global.home-module-grid"),
        (("/review",), "synapse.global.review"),
        (("/search",), "synapse.global.search"),
        (("/concept",), "synapse.global.concept-hub"),
        (("/cases",), "synapse.global.cases"),
        (("/clinical/osce",), "synapse.global.osce"),
        (("/plan",), "synapse.global.plan"),
        (("/insights", "/profile/stats"), "synapse.global.insights"),
        (("/rewards",), "synapse.global.rewards"),
        (("/achievements",), "synapse.global.achievements"),
        (("/quests",), "synapse.global.quests"),
        (("/notifications",), "synapse.global.notifications"),
        (("/inbox", "/chat"), "synapse.global.inbox-chat"),
        (("/library/diseases",), "synapse.global.diseases"),
        (("/library/drugs",), "synapse.global.drugs-classes-interactions"),
        (("/library/tools",), "synapse.global.calculators-tools"),
        (("/library",), "synapse.global.library"),
        (("/social/rooms", "/social/community", "/social/events", "/social/leaderboard"), "synapse.global.community-rooms-events"),
        (("/classes", "/org"), "synapse.global.classes-org"),
        (("/admin", "/create"), "synapse.global.admin-create"),
        (("/integrations", "/learn/cards/import"), "synapse.global.import-export-integrations"),
        (("/settings/data", "/settings/privacy", "/legal"), "synapse.global.privacy-data"),
        (("/settings/redeem", "/settings/subscription", "/shop", "/pro"), "synapse.global.shop-pro"),
        (("/profile/customize",), "synapse.global.profile-customization"),
        (("/settings",), "synapse.global.privacy-data"),
        (("/profile", "/u"), "synapse.system.profile"),
    ]
    for prefixes, capability_id in checks:
        if any(path == prefix or path.startswith(prefix + "/") for prefix in prefixes):
            return capability_id
    raise ValueError(f"route has no capability owner: {path}")


def build_capability_ledger(routes: list[dict[str, Any]]) -> dict[str, Any]:
    entries = capability_entries_from_docs() + SYSTEM_CAPABILITIES
    by_id = {entry["id"]: entry for entry in entries}
    if len(by_id) != len(entries):
        raise ValueError("duplicate capability IDs")
    new_registry = json.loads(NEW_CAPABILITY_SOURCE.read_text(encoding="utf-8"))
    if (
        new_registry.get("schemaVersion") != 1
        or new_registry.get("contractId") != "synapse.new-capability-registry.v1"
    ):
        raise ValueError("invalid additive capability registry")
    additive_ids = {entry["id"] for entry in new_registry["entries"]}
    if additive_ids & set(by_id):
        raise ValueError("additive capability ID collides with preserved baseline")
    allowed_route_owners = set(by_id) | additive_ids
    route_coverage: list[dict[str, str]] = []
    for route in routes:
        capability_id = capability_for_route(route["path"])
        if capability_id not in allowed_route_owners:
            raise ValueError(
                f"route {route['path']} maps to missing capability {capability_id}"
            )
        route["capabilityId"] = capability_id
        route_coverage.append(
            {"routeId": route["id"], "path": route["path"], "capabilityId": capability_id}
        )
    return {
        "schemaVersion": SCHEMA_VERSION,
        "sourceDate": SOURCE_DATE,
        "canonicalSource": relative(CAPABILITY_SOURCE),
        "registeredAdditiveCapabilitySource": relative(NEW_CAPABILITY_SOURCE),
        "registeredAdditiveCapabilityIds": sorted(additive_ids),
        "entries": sorted(entries, key=lambda item: item["id"]),
        "routeCoverage": sorted(route_coverage, key=lambda item: item["path"]),
        "invariants": [
            "no current Synapse capability disappears because it no longer owns a standalone page",
            "new routes may be owned by a registered additive capability without rewriting the preserved 76-entry baseline",
            "StudyHUB capabilities are absorbed into contextual owners and never become a sixth top-level authority",
            "partial, commitment, prototype, dormant, and at-risk states remain labeled honestly until proven",
        ],
    }


def archived_domain_fixtures() -> dict[str, Any]:
    at = "2026-07-17T00:00:00.000Z"
    return {
        "schemaVersion": SCHEMA_VERSION,
        "sourceDate": SOURCE_DATE,
        "models": {
            "Concept": {
                "id": "concept.hyponatremia",
                "name": "Hyponatremia",
                "aliases": ["low sodium"],
                "domain": "lab",
                "tags": ["electrolytes"],
                "summary": "fixture-only compatibility text",
                "links": [
                    {"to": "concept.sodium", "relation": "related"}
                ],
            },
            "ConceptMastery": {
                "conceptId": "concept.hyponatremia",
                "mastery": 0.625,
                "attempts": 8,
                "correct": 5,
                "lastStudied": at,
                "perModule": {"cards": 3, "labs": 5},
            },
            "SrsCard": {
                "id": "card.fixture.001",
                "ownerId": "user.fixture.001",
                "conceptId": "concept.hyponatremia",
                "origin": "cards",
                "front": "Compatibility fixture question",
                "back": "Compatibility fixture answer",
                "box": 2,
                "ease": 2.35,
                "intervalDays": 6,
                "dueAt": at,
                "lapses": 1,
                "reps": 4,
            },
            "UserProfile": {
                "id": "user.fixture.001",
                "handle": "fixture_user",
                "displayName": "Fixture Learner",
                "avatarUrl": None,
                "role": "resident",
                "specialty": "Internal Medicine",
                "year": 2,
                "bio": "Synthetic preservation fixture",
                "prefs": {
                    "theme": "dark",
                    "locale": "fa",
                    "analyticsOptIn": False,
                    "reduceMotion": True,
                    "dailyGoalXp": 60,
                    "notifications": {
                        "dailyReminder": True,
                        "reminderHour": 19,
                        "streakAlerts": False,
                        "social": True,
                        "leagues": False,
                    },
                    "interests": ["terms", "labs"],
                },
                "createdAt": at,
                "updatedAt": at,
            },
        },
        "events": [
            {"type": "ConceptStudied", "at": at, "conceptId": "concept.fixture", "source": "terms", "correct": True},
            {"type": "ConceptStruggled", "at": at, "conceptId": "concept.fixture", "source": "cards"},
            {"type": "ItemMastered", "at": at, "conceptId": "concept.fixture"},
            {"type": "LessonCompleted", "at": at, "source": "terms", "correct": 4, "total": 5, "conceptIds": ["concept.fixture"]},
            {"type": "CaseCompleted", "at": at, "caseId": "case.fixture", "conceptIds": ["concept.fixture"]},
            {"type": "RewardGranted", "at": at, "event": {"source": "cards", "kind": "review", "xp": 5, "gems": 0, "conceptIds": ["concept.fixture"], "firstTry": True, "at": at}},
            {"type": "StreakChanged", "at": at, "current": 7},
            {"type": "ContentCreated", "at": at, "source": "mnemonics", "itemId": "mnemonic.fixture"},
            {"type": "SocialInteraction", "at": at, "source": "rounds", "kind": "comment"},
            {"type": "QuestProgressed", "at": at, "questId": "quest.fixture"},
        ],
        "rules": [
            "fixtures are synthetic and contain no lesson bodies, PHI, secrets, or production identifiers",
            "unknown enum values require explicit compatibility behavior rather than silent identity remapping",
            "event type names and field semantics are immutable facts for legacy adapters",
        ],
    }


def deep_link_fixtures(routes: list[dict[str, Any]]) -> dict[str, Any]:
    fixtures: list[dict[str, Any]] = []
    for route in routes:
        for mode in ("coldStart", "webRefresh", "nativeLocation"):
            fixtures.append(
                {
                    "id": f"{route['id']}::{mode}",
                    "mode": mode,
                    "location": route["sampleLocation"],
                    "expectedRouteId": route["id"],
                    "expectedPathPattern": route["path"],
                    "expectedIntent": route["intent"],
                    "expectedShellBranch": route["shellBranch"],
                    "authExpectation": "unchanged-current-router-has-no-global-auth-redirect",
                    "backStackExpectation": (
                        "restore indexed shell branch and nested location"
                        if route["shellBranch"]
                        else "root navigator owns the full-screen location"
                    ),
                }
            )
    return {
        "schemaVersion": SCHEMA_VERSION,
        "sourceDate": SOURCE_DATE,
        "fixtures": fixtures,
        "transports": {
            "coldStart": "GoRouter initial location fixture",
            "webRefresh": "browser path/query refresh fixture",
            "nativeLocation": "platform-delivered location fixture; no unverified custom scheme is asserted",
        },
    }


OUTPUT_NAMES = [
    "route-registry.v1.json",
    "module-registry.v1.json",
    "persistence-keys.v1.json",
    "supabase-schema.v1.json",
    "archived-domain-fixtures.v1.json",
    "deep-link-fixtures.v1.json",
    "capability-ledger.v1.json",
    "rollback-bundle.v1.json",
    "preservation-manifest.v1.json",
]


def git_head() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def build_contracts() -> dict[str, Any]:
    routes, constants, library_routes = parse_router()
    helpers = parse_route_helpers(routes, constants, library_routes)
    capability = build_capability_ledger(routes)
    route_registry = {
        "schemaVersion": SCHEMA_VERSION,
        "sourceDate": SOURCE_DATE,
        "canonicalSources": [relative(ROUTES_SOURCE), relative(ROUTER_SOURCE)],
        "initialLocation": "/splash",
        "errorIntent": "ComingSoonScreen:not-found",
        "routes": sorted(routes, key=lambda item: (item["sourceLine"], item["path"])),
        "helpers": helpers,
        "libraryKindRoutes": library_routes,
    }
    enums = parse_enums()
    payloads: dict[str, Any] = {
        "route-registry.v1.json": route_registry,
        "module-registry.v1.json": parse_module_registry(enums),
        "persistence-keys.v1.json": parse_persistence_inventory(),
        "supabase-schema.v1.json": parse_supabase_schema(),
        "archived-domain-fixtures.v1.json": archived_domain_fixtures(),
        "deep-link-fixtures.v1.json": deep_link_fixtures(routes),
        "capability-ledger.v1.json": capability,
    }
    source_paths = sorted(
        {
            ROUTES_SOURCE,
            ROUTER_SOURCE,
            MODULE_SOURCE,
            LIBRARY_SOURCE,
            PERSISTENCE_SOURCE,
            SESSION_PROGRESS_SOURCE,
            STUDY_WORKSPACE_SOURCE,
            READING_STATE_SOURCE,
            RESOURCE_WORKSPACE_SOURCE,
            DOCUMENT_READING_STATE_SOURCE,
            VERSION_SOURCE,
            CAPABILITY_SOURCE,
            NEW_CAPABILITY_SOURCE,
            *sorted((ROOT / "apps" / "app" / "lib" / "state").glob("*.dart")),
            *sorted((ROOT / "packages" / "core" / "lib" / "src" / "models").glob("*.dart")),
            *sorted((ROOT / "supabase" / "migrations").glob("*.sql")),
        },
        key=relative,
    )
    rollback_entries = [
        {
            "artifact": name,
            "sha256": sha256_bytes(json_bytes(payload)),
            "restoreBoundary": (
                "route and deep-link compatibility"
                if "route" in name or "deep-link" in name
                else "local persistence and archived model/event compatibility"
                if "persistence" in name or "archived" in name
                else "cloud schema/policy/function compatibility"
                if "supabase" in name
                else "capability ownership and absorption compatibility"
            ),
        }
        for name, payload in sorted(payloads.items())
    ]
    payloads["rollback-bundle.v1.json"] = {
        "schemaVersion": SCHEMA_VERSION,
        "sourceDate": SOURCE_DATE,
        "sourceCommit": git_head(),
        "entries": rollback_entries,
        "restoreProcedure": [
            "stop before any destructive or compatibility-affecting operation",
            "compare current sources and generated snapshots against this bundle",
            "restore source from the protected Git commit or Synapse-App.rar baseline; never overwrite user data with fixture data",
            "reapply immutable Supabase migrations only to a disposable recovery project and verify RLS before any production action",
            "run tool/preservation/verify_preservation_contracts.py and the archived Dart fixture tests before resuming",
        ],
    }
    manifest_outputs = [
        {
            "path": f"contracts/preservation/{name}",
            "sha256": sha256_bytes(json_bytes(payload)),
            "bytes": len(json_bytes(payload)),
        }
        for name, payload in sorted(payloads.items())
    ]
    payloads["preservation-manifest.v1.json"] = {
        "schemaVersion": SCHEMA_VERSION,
        "sourceDate": SOURCE_DATE,
        "sourceCommit": git_head(),
        "sources": [
            {
                "path": relative(path),
                "sha256": sha256_file(path),
                "bytes": path.stat().st_size,
            }
            for path in source_paths
        ],
        "outputs": manifest_outputs,
        "counts": {
            "routeDeclarations": len({route["sourceLine"] for route in routes}),
            "resolvedRoutes": len(routes),
            "routeHelpers": len(helpers),
            "modules": len(payloads["module-registry.v1.json"]["modules"]),
            "shellBranches": len(payloads["module-registry.v1.json"]["shellBranches"]),
            "serializedEnums": len(enums),
            "persistenceKeys": len(payloads["persistence-keys.v1.json"]["entries"]),
            "supabaseTables": len(payloads["supabase-schema.v1.json"]["tables"]),
            "supabasePolicies": len(payloads["supabase-schema.v1.json"]["policies"]),
            "domainModels": len(payloads["archived-domain-fixtures.v1.json"]["models"]),
            "legacyEvents": len(payloads["archived-domain-fixtures.v1.json"]["events"]),
            "deepLinkFixtures": len(payloads["deep-link-fixtures.v1.json"]["fixtures"]),
            "capabilities": len(payloads["capability-ledger.v1.json"]["entries"]),
        },
    }
    if set(payloads) != set(OUTPUT_NAMES):
        raise ValueError(f"output inventory drift: {sorted(payloads)}")
    return payloads


def write_contracts(payloads: dict[str, Any]) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for name in OUTPUT_NAMES:
        (OUTPUT_DIR / name).write_bytes(json_bytes(payloads[name]))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="Compare generated bytes with the installed contract snapshots",
    )
    parser.add_argument("--json", action="store_true", help="Print the generation summary as JSON")
    args = parser.parse_args()
    payloads = build_contracts()
    failures: list[str] = []
    if args.check:
        for name in OUTPUT_NAMES:
            path = OUTPUT_DIR / name
            expected = json_bytes(payloads[name])
            if not path.exists():
                failures.append(f"missing {relative(path)}")
            elif path.read_bytes() != expected:
                failures.append(f"stale {relative(path)}")
    else:
        write_contracts(payloads)
    summary = {
        "status": "fail" if failures else "pass",
        "mode": "check" if args.check else "write",
        "outputDirectory": relative(OUTPUT_DIR),
        "outputs": len(payloads),
        "counts": payloads["preservation-manifest.v1.json"]["counts"],
        "failures": failures,
    }
    print(json.dumps(summary, indent=2) if args.json or failures else normalize_space(json.dumps(summary)))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
