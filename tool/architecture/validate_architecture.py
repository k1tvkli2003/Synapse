#!/usr/bin/env python3
"""Enforce Synapse package direction and persistence safety boundaries."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


ALLOWED_WORKSPACE_DEPS = {
    "config": set(),
    "core": set(),
    "foundation": set(),
    "fixtures": {"config", "core", "foundation"},
    "motion": {"foundation"},
    "observability": {"foundation"},
    "engines": {"core"},
    "services": {"core", "engines", "foundation"},
    "ui": {"core", "motion"},
}
PURE_DART_PACKAGES = {
    "config",
    "core",
    "foundation",
    "fixtures",
    "motion",
    "observability",
    "engines",
    "services",
}
PLATFORM_IMPORT_PREFIXES = (
    "dart:ui",
    "package:flutter/",
    "package:flutter_",
    "package:shared_preferences/",
    "package:supabase_flutter/",
)
IMPORT_RE = re.compile(r"^import\s+['\"]([^'\"]+)['\"]", re.MULTILINE)
WORKSPACE_IMPORT_RE = re.compile(r"^package:synapse_([a-z0-9_]+)/")
UNSAFE_ENUM_ENCODER_RE = re.compile(
    r"['\"][A-Za-z0-9_]+['\"]\s*:\s*[^,\n}]*\.index\b"
)
UNSAFE_ENUM_DECODER_RE = re.compile(
    r"\b[A-Z][A-Za-z0-9_]*\.values\s*\[\s*(?:j|json|map|data)\s*\["
)


@dataclass(frozen=True)
class Violation:
    rule: str
    path: str
    line: int
    detail: str


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def declared_workspace_dependencies(pubspec: Path) -> set[str]:
    text = pubspec.read_text(encoding="utf-8")
    match = re.search(
        r"^dependencies:\s*$(.*?)(?=^dev_dependencies:|\Z)",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if not match:
        return set()
    return set(
        re.findall(r"^\s{2}synapse_([a-z0-9_]+):\s*$", match.group(1), re.MULTILINE)
    )


def validate_package(root: Path, package: str) -> list[Violation]:
    package_root = root / "packages" / package
    allowed = ALLOWED_WORKSPACE_DEPS[package]
    violations: list[Violation] = []
    declared = declared_workspace_dependencies(package_root / "pubspec.yaml")
    for dependency in sorted(declared - allowed):
        violations.append(
            Violation(
                rule="dependency-direction",
                path=f"packages/{package}/pubspec.yaml",
                line=1,
                detail=f"synapse_{package} cannot depend on synapse_{dependency}",
            )
        )

    lib = package_root / "lib"
    for path in sorted(lib.rglob("*.dart")):
        relative = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8")
        for match in IMPORT_RE.finditer(text):
            import_uri = match.group(1)
            workspace = WORKSPACE_IMPORT_RE.match(import_uri)
            if workspace and workspace.group(1) not in allowed:
                violations.append(
                    Violation(
                        rule="dependency-direction",
                        path=relative,
                        line=line_number(text, match.start()),
                        detail=f"import of synapse_{workspace.group(1)} is not allowed",
                    )
                )
            if package in PURE_DART_PACKAGES and import_uri.startswith(
                PLATFORM_IMPORT_PREFIXES
            ):
                violations.append(
                    Violation(
                        rule="pure-dart-boundary",
                        path=relative,
                        line=line_number(text, match.start()),
                        detail=f"platform import is forbidden: {import_uri}",
                    )
                )

        for rule, pattern in (
            ("unsafe-enum-index-encode", UNSAFE_ENUM_ENCODER_RE),
            ("unsafe-enum-index-decode", UNSAFE_ENUM_DECODER_RE),
        ):
            for match in pattern.finditer(text):
                violations.append(
                    Violation(
                        rule=rule,
                        path=relative,
                        line=line_number(text, match.start()),
                        detail="persisted enum ordering is not a stable wire contract",
                    )
                )
    return violations


def validate_event_envelope(root: Path) -> list[Violation]:
    relative = "packages/core/lib/src/serialization/synapse_event_codec.dart"
    path = root / relative
    if not path.exists():
        return [
            Violation(
                rule="versioned-domain-events",
                path=relative,
                line=1,
                detail="the authoritative event codec is missing",
            )
        ]
    text = path.read_text(encoding="utf-8")
    required = (
        "currentSchemaVersion = 1",
        "VersionedEnvelope(",
        "supportedVersions: const {currentSchemaVersion}",
    )
    return [
        Violation(
            rule="versioned-domain-events",
            path=relative,
            line=1,
            detail=f"required event envelope marker is missing: {marker}",
        )
        for marker in required
        if marker not in text
    ]


def validate_repository(root: Path) -> dict[str, object]:
    violations: list[Violation] = []
    for package in ALLOWED_WORKSPACE_DEPS:
        violations.extend(validate_package(root, package))
    violations.extend(validate_event_envelope(root))
    inventory = []
    for package in ALLOWED_WORKSPACE_DEPS:
        for path in sorted((root / "packages" / package).rglob("*.dart")):
            raw = path.read_bytes()
            inventory.append(
                f"{path.relative_to(root).as_posix()}|{hashlib.sha256(raw).hexdigest()}"
            )
    return {
        "schemaVersion": 1,
        "status": "pass" if not violations else "fail",
        "packagesChecked": len(ALLOWED_WORKSPACE_DEPS),
        "dartFilesChecked": len(inventory),
        "inventorySha256": hashlib.sha256("\n".join(inventory).encode()).hexdigest().upper(),
        "violations": [asdict(violation) for violation in violations],
        "rules": [
            "dependency-direction",
            "pure-dart-boundary",
            "unsafe-enum-index-encode",
            "unsafe-enum-index-decode",
            "versioned-domain-events",
        ],
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--write-receipt", type=Path)
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = args.root.resolve()
    result = validate_repository(root)
    if args.write_receipt:
        receipt = args.write_receipt
        if not receipt.is_absolute():
            receipt = root / receipt
        receipt.parent.mkdir(parents=True, exist_ok=True)
        receipt.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if args.json or result["status"] != "pass":
        print(json.dumps(result, indent=2))
    else:
        print(
            "Architecture gate PASS: "
            f"{result['packagesChecked']} packages / {result['dartFilesChecked']} Dart files"
        )
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
