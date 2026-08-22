#!/usr/bin/env python3
"""Verify the repository-owned GitHub Actions quality boundary."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


QUALITY = Path(".github/workflows/quality.yml")
DEPENDABOT = Path(".github/dependabot.yml")
RECEIPT = Path("contracts/actions/actions-verification.v1.json")
PINNED_ACTIONS = {
    "actions/checkout": "3d3c42e5aac5ba805825da76410c181273ba90b1",
    "subosito/flutter-action": "1a449444c387b1966244ae4d4f8c696479add0b2",
    "actions/upload-artifact": "043fb46d1a93c77aae656e7c1c64a875d1fc6a0a",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def _issue(issues: list[dict[str, str]], code: str, message: str) -> None:
    issues.append({"code": code, "message": message})


def verify_repository(root: Path) -> dict[str, object]:
    issues: list[dict[str, str]] = []
    quality_path = root / QUALITY
    dependabot_path = root / DEPENDABOT
    for path in (quality_path, dependabot_path):
        if not path.is_file():
            _issue(issues, "missing_actions_file", f"Missing {path.relative_to(root)}")
    if issues:
        return _receipt(root, issues, {})

    quality = quality_path.read_text(encoding="utf-8")
    dependabot = dependabot_path.read_text(encoding="utf-8")

    required_fragments = (
        '"on":',
        "  push:",
        "  pull_request:",
        "  workflow_dispatch:",
        "permissions:\n  contents: read",
        "persist-credentials: false",
        'flutter-version: "3.44.0"',
        "flutter pub get --enforce-lockfile",
        "git diff --exit-code -- pubspec.lock",
        "dart run melos run verify",
        "cancel-in-progress: ${{ github.event_name == 'pull_request' }}",
        "apps/app/build/web",
        "contracts/actions/actions-verification.v1.json",
    )
    for fragment in required_fragments:
        if fragment not in quality:
            _issue(
                issues,
                "missing_quality_contract",
                f"Quality workflow is missing required contract: {fragment}",
            )

    forbidden_patterns = {
        "privileged_pull_request_target": r"(?m)^\s*pull_request_target\s*:",
        "chained_workflow_trigger": r"(?m)^\s*workflow_run\s*:",
        "write_permission": r"(?m)^\s*[a-zA-Z_-]+\s*:\s*write\s*$",
        "secret_reference": r"\$\{\{\s*secrets\.",
        "deployment_environment": r"(?m)^\s*environment\s*:",
        "release_or_deploy_action": r"(?mi)^\s*uses\s*:\s*[^\n#]*(deploy|release|pages-action)",
    }
    for code, pattern in forbidden_patterns.items():
        if re.search(pattern, quality):
            _issue(issues, code, f"Quality workflow violates policy: {code}")

    action_refs: dict[str, str] = {}
    for match in re.finditer(r"(?m)^\s*uses:\s*([^\s#]+)", quality):
        reference = match.group(1)
        if reference.startswith("./"):
            continue
        if "@" not in reference:
            _issue(issues, "invalid_action_reference", f"Invalid action: {reference}")
            continue
        action, revision = reference.rsplit("@", 1)
        if not re.fullmatch(r"[0-9a-f]{40}", revision):
            _issue(
                issues,
                "unpinned_action",
                f"Action {action} must use a full lowercase commit SHA.",
            )
        expected = PINNED_ACTIONS.get(action)
        if expected is None:
            _issue(issues, "unreviewed_action", f"Action {action} is not allowlisted.")
        elif revision != expected:
            _issue(
                issues,
                "action_pin_drift",
                f"Action {action} revision {revision} does not match the reviewed pin.",
            )
        action_refs[action] = revision
    for action in PINNED_ACTIONS:
        if action not in action_refs:
            _issue(issues, "missing_pinned_action", f"Required action {action} is missing.")

    if "version: 2" not in dependabot:
        _issue(issues, "dependabot_version", "Dependabot config must use version 2.")
    for ecosystem in ("github-actions", "pub"):
        if f"package-ecosystem: {ecosystem}" not in dependabot:
            _issue(
                issues,
                "dependabot_ecosystem",
                f"Dependabot must cover {ecosystem}.",
            )
    return _receipt(root, issues, action_refs)


def _receipt(
    root: Path,
    issues: list[dict[str, str]],
    action_refs: dict[str, str],
) -> dict[str, object]:
    files = []
    for relative in (QUALITY, DEPENDABOT):
        path = root / relative
        if path.is_file():
            files.append(
                {
                    "path": relative.as_posix(),
                    "bytes": path.stat().st_size,
                    "sha256": sha256(path),
                }
            )
    return {
        "schemaVersion": 1,
        "status": "pass" if not issues else "fail",
        "runner": "ubuntu-24.04",
        "flutter": {"version": "3.44.0", "channel": "stable"},
        "permissions": {"contents": "read"},
        "actions": dict(sorted(action_refs.items())),
        "files": files,
        "issues": issues,
        "policy": {
            "purpose": "quality and public build evidence only",
            "release": "not configured",
            "deployment": "not configured",
            "signing": "not configured",
            "privateDataArtifacts": "forbidden",
        },
    }


def canonical_bytes(value: dict[str, object]) -> bytes:
    return (json.dumps(value, indent=2) + "\n").encode("utf-8")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--write-receipt", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = args.root.resolve()
    receipt = verify_repository(root)
    expected = canonical_bytes(receipt)
    receipt_path = root / RECEIPT
    if args.write_receipt and receipt["status"] == "pass":
        receipt_path.parent.mkdir(parents=True, exist_ok=True)
        receipt_path.write_bytes(expected)
    elif not receipt_path.is_file() or receipt_path.read_bytes() != expected:
        receipt["status"] = "fail"
        receipt["receiptFailure"] = "Actions verification receipt is missing or stale."
    if receipt["status"] == "pass":
        print(
            "Actions gate PASS: "
            f"{len(receipt['actions'])} pinned actions / {len(receipt['files'])} policy files"
        )
        return 0
    print(json.dumps(receipt, indent=2))
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

