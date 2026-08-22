#!/usr/bin/env python3
"""Validate Synapse performance budgets and deterministic static artifacts."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import struct
import sys
from pathlib import Path
from typing import Any, Iterable


DEFAULT_BUDGETS = Path("contracts/performance/performance-budgets.v1.json")
DEFAULT_RECEIPT = Path("contracts/performance/performance-verification.v1.json")
PROBE_TYPES = {
    "file_bytes",
    "flutter_declared_assets_bytes",
    "gzip_file_bytes",
    "largest_file_bytes",
    "largest_png_decoded_rgba_bytes",
    "tree_bytes",
    "tree_extension_bytes",
}


class BudgetError(ValueError):
    """Raised when a performance contract is invalid or unsafe."""


def canonical_bytes(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, indent=2) + "\n").encode("utf-8")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def _number(value: Any, label: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise BudgetError(f"{label} must be numeric")
    if value < 0:
        raise BudgetError(f"{label} must be non-negative")
    return float(value)


def validate_thresholds(thresholds: dict[str, Any], label: str) -> None:
    required = ("targetMax", "warningMax", "blockingMax")
    missing = [key for key in required if key not in thresholds]
    if missing:
        raise BudgetError(f"{label} is missing thresholds: {', '.join(missing)}")
    target, warning, blocking = (
        _number(thresholds[key], f"{label}.{key}") for key in required
    )
    if not target < warning < blocking:
        raise BudgetError(
            f"{label} thresholds must satisfy targetMax < warningMax < blockingMax"
        )


def _resolve_under(root: Path, relative: str) -> Path:
    path = (root / relative).resolve()
    try:
        path.relative_to(root)
    except ValueError as error:
        raise BudgetError(f"probe path escapes repository root: {relative}") from error
    return path


def _extensions(probe: dict[str, Any]) -> set[str] | None:
    raw = probe.get("extensions")
    if raw is None:
        return None
    if not isinstance(raw, list) or not all(isinstance(item, str) for item in raw):
        raise BudgetError("probe.extensions must be a string list")
    return {item.lower() for item in raw}


def _files(path: Path, extensions: set[str] | None = None) -> Iterable[Path]:
    if not path.exists():
        return ()
    candidates = (path,) if path.is_file() else path.rglob("*")
    return (
        candidate
        for candidate in candidates
        if candidate.is_file()
        and (extensions is None or candidate.suffix.lower() in extensions)
    )


def _png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise BudgetError(f"invalid PNG header: {path}")
    if header[12:16] != b"IHDR":
        raise BudgetError(f"missing PNG IHDR: {path}")
    return struct.unpack(">II", header[16:24])


def _strip_yaml_inline_comment(value: str) -> str:
    """Remove a YAML comment without treating a quoted # as a comment."""

    quote: str | None = None
    escaped = False
    for index, character in enumerate(value):
        if quote is not None:
            if quote == '"' and character == "\\" and not escaped:
                escaped = True
                continue
            if character == quote and not escaped:
                quote = None
            escaped = False
            continue
        if character in {"'", '"'}:
            quote = character
        elif character == "#" and (index == 0 or value[index - 1].isspace()):
            return value[:index]
    return value


def _parse_flutter_asset_scalar(value: str, line_number: int) -> str:
    scalar = _strip_yaml_inline_comment(value).strip()
    if not scalar:
        raise BudgetError(f"empty Flutter asset declaration at pubspec line {line_number}")
    if scalar[0] in {"'", '"'}:
        quote = scalar[0]
        closing = scalar.find(quote, 1)
        if closing == -1:
            raise BudgetError(
                f"unterminated Flutter asset declaration at pubspec line {line_number}"
            )
        trailing = _strip_yaml_inline_comment(scalar[closing + 1 :]).strip()
        if trailing:
            raise BudgetError(
                f"unsupported Flutter asset declaration at pubspec line {line_number}"
            )
        scalar = scalar[1:closing]
    elif scalar[0] in "[{!&*|>" or ":" in scalar:
        raise BudgetError(
            f"unsupported Flutter asset declaration at pubspec line {line_number}"
        )
    if not scalar:
        raise BudgetError(f"empty Flutter asset declaration at pubspec line {line_number}")
    return scalar


def _flutter_declared_asset_entries(root: Path, pubspec: Path) -> list[tuple[str, Path]]:
    """Read the simple, supported `flutter/assets` list from a package pubspec.

    The production app deliberately uses scalar asset entries rather than YAML
    mappings. Keeping the parser narrow makes the performance gate deterministic
    without introducing a second YAML dependency into the repository.
    """

    if not pubspec.is_file():
        return []

    package_root = pubspec.parent.resolve()
    try:
        package_root.relative_to(root)
    except ValueError as error:
        raise BudgetError(f"Flutter pubspec escapes repository root: {pubspec}") from error

    flutter_indent: int | None = None
    assets_indent: int | None = None
    entries: list[tuple[str, Path]] = []
    for line_number, raw_line in enumerate(
        pubspec.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if "\t" in raw_line[: len(raw_line) - len(raw_line.lstrip())]:
            raise BudgetError(f"tab indentation in pubspec at line {line_number}")
        line = _strip_yaml_inline_comment(raw_line)
        stripped = line.strip()
        if not stripped:
            continue
        indentation = len(line) - len(line.lstrip(" "))

        if flutter_indent is None:
            if indentation == 0 and stripped == "flutter:":
                flutter_indent = indentation
            continue
        if assets_indent is None:
            if indentation <= flutter_indent:
                break
            if stripped == "assets:":
                assets_indent = indentation
            continue
        if indentation <= assets_indent:
            break
        if not stripped.startswith("-") or len(stripped) == 1 or not stripped[1].isspace():
            raise BudgetError(
                f"unsupported Flutter assets entry at pubspec line {line_number}"
            )
        declared = _parse_flutter_asset_scalar(stripped[1:].strip(), line_number)
        asset_path = (package_root / declared).resolve()
        try:
            asset_path.relative_to(package_root)
        except ValueError as error:
            raise BudgetError(
                f"Flutter asset path escapes package root at pubspec line {line_number}: {declared}"
            ) from error
        entries.append((declared, asset_path))
    return entries


def _measure_flutter_declared_assets(root: Path, pubspec: Path) -> dict[str, Any]:
    entries = _flutter_declared_asset_entries(root, pubspec)
    files_by_path: dict[Path, Path] = {}
    missing: list[str] = []
    for declared, asset_path in entries:
        if not asset_path.exists():
            missing.append(declared)
            continue
        for candidate in _files(asset_path):
            files_by_path[candidate.resolve()] = candidate

    files = sorted(files_by_path.values(), key=lambda candidate: candidate.as_posix())
    largest = max(files, key=lambda candidate: candidate.stat().st_size) if files else None
    return {
        "valueBytes": sum(candidate.stat().st_size for candidate in files),
        "present": pubspec.is_file() and bool(entries) and not missing and bool(files),
        "filesMeasured": len(files),
        "declaredAssetPaths": [declared for declared, _ in entries],
        "missingDeclaredAssetPaths": missing,
        **(
            {"largestPath": largest.relative_to(root).as_posix()}
            if largest is not None
            else {}
        ),
    }


def measure_probe(root: Path, probe: dict[str, Any]) -> dict[str, Any]:
    probe_type = probe.get("type")
    if probe_type not in PROBE_TYPES:
        raise BudgetError(f"unsupported probe type: {probe_type}")
    relative = probe.get("path")
    if not isinstance(relative, str) or not relative:
        raise BudgetError("probe.path must be a non-empty string")
    path = _resolve_under(root, relative)
    extensions = _extensions(probe)
    present = path.exists()

    if probe_type == "flutter_declared_assets_bytes":
        return _measure_flutter_declared_assets(root, path)
    if probe_type == "file_bytes":
        files = list(_files(path))
        value = path.stat().st_size if path.is_file() else 0
        largest = path if path.is_file() else None
    elif probe_type == "gzip_file_bytes":
        files = list(_files(path))
        value = len(gzip.compress(path.read_bytes(), compresslevel=9, mtime=0)) if path.is_file() else 0
        largest = path if path.is_file() else None
    else:
        effective_extensions = extensions
        if probe_type == "largest_png_decoded_rgba_bytes":
            effective_extensions = {".png"}
        files = list(_files(path, effective_extensions))
        largest = None
        value = 0
        if probe_type in {"tree_bytes", "tree_extension_bytes"}:
            value = sum(candidate.stat().st_size for candidate in files)
            if files:
                largest = max(files, key=lambda candidate: candidate.stat().st_size)
        elif probe_type == "largest_file_bytes":
            if files:
                largest = max(files, key=lambda candidate: candidate.stat().st_size)
                value = largest.stat().st_size
        elif probe_type == "largest_png_decoded_rgba_bytes":
            for candidate in files:
                width, height = _png_dimensions(candidate)
                decoded = width * height * 4
                if decoded > value:
                    value = decoded
                    largest = candidate

    result: dict[str, Any] = {
        "valueBytes": value,
        "present": present,
        "filesMeasured": len(files),
    }
    if largest is not None:
        result["largestPath"] = largest.relative_to(root).as_posix()
    return result


def classify(value: int, thresholds: dict[str, Any]) -> str:
    if value <= thresholds["targetMax"]:
        return "target"
    if value <= thresholds["warningMax"]:
        return "warning"
    if value <= thresholds["blockingMax"]:
        return "blocking-headroom"
    return "fail"


def _validate_runtime_threshold_groups(config: dict[str, Any]) -> None:
    runtime = config.get("runtimeBudgets")
    if not isinstance(runtime, dict):
        raise BudgetError("runtimeBudgets must be an object")
    for group, entries in runtime.items():
        if group == "enforcement":
            continue
        if not isinstance(entries, list):
            raise BudgetError(f"runtimeBudgets.{group} must be a list")
        for index, entry in enumerate(entries):
            validate_thresholds(entry, f"runtimeBudgets.{group}[{index}]")

    motion = config.get("motionExperienceBudgets")
    if not isinstance(motion, dict):
        raise BudgetError("motionExperienceBudgets must be an object")
    for tier in ("standard", "milestone", "showpiece"):
        value = motion.get(tier)
        if not isinstance(value, dict):
            raise BudgetError(f"motionExperienceBudgets.{tier} must be an object")
        for metric in ("durationMilliseconds", "particles"):
            validate_thresholds(value.get(metric, {}), f"motionExperienceBudgets.{tier}.{metric}")


def validate_config(config: dict[str, Any]) -> None:
    if config.get("schemaVersion") != 1:
        raise BudgetError("schemaVersion must be 1")
    budgets = config.get("staticBudgets")
    if not isinstance(budgets, list) or not budgets:
        raise BudgetError("staticBudgets must be a non-empty list")
    seen: set[str] = set()
    for index, budget in enumerate(budgets):
        if not isinstance(budget, dict):
            raise BudgetError(f"staticBudgets[{index}] must be an object")
        budget_id = budget.get("id")
        if not isinstance(budget_id, str) or not budget_id:
            raise BudgetError(f"staticBudgets[{index}].id must be a string")
        if budget_id in seen:
            raise BudgetError(f"duplicate static budget id: {budget_id}")
        seen.add(budget_id)
        if budget.get("enforcement") != "blocking":
            raise BudgetError(f"{budget_id}.enforcement must be blocking")
        if not isinstance(budget.get("required"), bool):
            raise BudgetError(f"{budget_id}.required must be boolean")
        validate_thresholds(budget.get("thresholdsBytes", {}), budget_id)
        probe = budget.get("probe")
        if not isinstance(probe, dict):
            raise BudgetError(f"{budget_id}.probe must be an object")
        if probe.get("type") not in PROBE_TYPES:
            raise BudgetError(f"{budget_id} has unsupported probe type")
    _validate_runtime_threshold_groups(config)
    journeys = config.get("namedJourneys")
    if not isinstance(journeys, list) or len(journeys) < 4:
        raise BudgetError("namedJourneys must define at least four journeys")


def verify(root: Path, budget_path: Path) -> dict[str, Any]:
    config = json.loads(budget_path.read_text(encoding="utf-8"))
    validate_config(config)
    measurements: list[dict[str, Any]] = []
    failures: list[str] = []
    warnings = 0
    for budget in config["staticBudgets"]:
        measurement = measure_probe(root, budget["probe"])
        tier = classify(measurement["valueBytes"], budget["thresholdsBytes"])
        if budget["required"] and not measurement["present"]:
            tier = "fail"
            failures.append(f"{budget['id']}: required path is missing")
        elif budget["required"] and measurement["filesMeasured"] == 0:
            tier = "fail"
            failures.append(
                f"{budget['id']}: required artifact contains no measurable files"
            )
        elif tier == "fail":
            failures.append(
                f"{budget['id']}: {measurement['valueBytes']} > {budget['thresholdsBytes']['blockingMax']}"
            )
        elif tier != "target":
            warnings += 1
        measurements.append(
            {
                "id": budget["id"],
                **measurement,
                "tier": tier,
                "thresholdsBytes": budget["thresholdsBytes"],
            }
        )
    return {
        "schemaVersion": 1,
        "status": "fail" if failures else "pass",
        "budgetPath": budget_path.relative_to(root).as_posix(),
        "budgetSha256": sha256(budget_path),
        "staticMeasurements": measurements,
        "warningCount": warnings,
        "failures": failures,
        "runtimeGate": config["runtimeBudgets"]["enforcement"],
        "namedJourneyCount": len(config["namedJourneys"]),
        "motionModes": config["policy"]["motionModes"],
        "requiredMotionScenarios": config["policy"]["requiredMotionScenarios"],
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--budgets", type=Path, default=DEFAULT_BUDGETS)
    parser.add_argument("--write-receipt", action="store_true")
    parser.add_argument("--receipt", type=Path, default=DEFAULT_RECEIPT)
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = args.root.resolve()
    budget_path = args.budgets
    if not budget_path.is_absolute():
        budget_path = root / budget_path
    try:
        result = verify(root, budget_path.resolve())
    except (BudgetError, json.JSONDecodeError, OSError) as error:
        result = {
            "schemaVersion": 1,
            "status": "fail",
            "failures": [str(error)],
        }
    if args.write_receipt:
        receipt = args.receipt
        if not receipt.is_absolute():
            receipt = root / receipt
        receipt.parent.mkdir(parents=True, exist_ok=True)
        receipt.write_bytes(canonical_bytes(result))
    if args.json or result["status"] != "pass":
        print(json.dumps(result, indent=2))
    else:
        print(
            "Performance budget gate PASS: "
            f"{len(result['staticMeasurements'])} static probes / "
            f"{result['namedJourneyCount']} journeys / "
            f"{result['warningCount']} warnings"
        )
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
