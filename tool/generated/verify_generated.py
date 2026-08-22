#!/usr/bin/env python3
"""Verify generated contracts and selected identity outputs reproducibly."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path


RECEIPT = Path("contracts/generated/generated-verification.v1.json")
WEB_RUNTIME_MANIFEST = Path("contracts/generated/web-runtime-assets.v1.json")
INVENTORY_PATHS = (
    "tool/generated/verify_generated.py",
    "tool/preservation/generate_preservation_contracts.py",
    "tool/preservation/verify_preservation_contracts.py",
    "tool/identity/build_luma_facefront.py",
    "tool/identity/test_luma_facefront.py",
    "tool/identity/render_wordmark_assets.cjs",
    "contracts/preservation/preservation-manifest.v1.json",
    "contracts/architecture/architecture-verification.v1.json",
    "contracts/generated/web-runtime-assets.v1.json",
    "docs/codex/2026-07-15-synapse-medical-learning-os/assets/identity/production/luma-facefront-restored/identity-source-manifest.json",
    "docs/codex/2026-07-15-synapse-medical-learning-os/assets/identity/production/luma-facefront-restored/platforms/platform-manifest.json",
    "docs/codex/2026-07-15-synapse-medical-learning-os/assets/identity/production/wordmark/renders/render-manifest.json",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run_check(root: Path, label: str, command: list[str]) -> dict[str, object]:
    result = subprocess.run(command, cwd=root, capture_output=True, text=True)
    if result.returncode != 0:
        diagnostic = (result.stdout + "\n" + result.stderr).strip().splitlines()[-12:]
        return {
            "name": label,
            "status": "fail",
            "diagnostic": diagnostic,
        }
    return {"name": label, "status": "pass"}


def locked_package_versions(lockfile: Path) -> dict[str, str]:
    """Read hosted package versions without adding a YAML runtime dependency."""
    versions: dict[str, str] = {}
    package: str | None = None
    for line in lockfile.read_text(encoding="utf-8").splitlines():
        if line.startswith("  ") and not line.startswith("    ") and line.endswith(":"):
            package = line.strip()[:-1]
            continue
        if package and line.startswith('    version: "') and line.endswith('"'):
            versions[package] = line.split('"', 2)[1]
            package = None
    return versions


def verify_web_runtime_assets(root: Path) -> dict[str, object]:
    manifest_path = root / WEB_RUNTIME_MANIFEST
    failures: list[str] = []
    if not manifest_path.is_file():
        return {
            "name": "web-drift-runtime-assets",
            "status": "fail",
            "diagnostic": [f"Missing {WEB_RUNTIME_MANIFEST.as_posix()}"],
        }
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return {
            "name": "web-drift-runtime-assets",
            "status": "fail",
            "diagnostic": [f"Invalid runtime manifest: {error}"],
        }

    if manifest.get("schemaVersion") != 1:
        failures.append("schemaVersion must be 1")
    assets = manifest.get("assets")
    packages = manifest.get("packages")
    if not isinstance(assets, list) or not assets:
        failures.append("assets must be a non-empty list")
        assets = []
    if not isinstance(packages, dict) or not packages:
        failures.append("packages must be a non-empty object")
        packages = {}

    lockfile = root / "pubspec.lock"
    if not lockfile.is_file():
        failures.append("pubspec.lock is missing")
        locked = {}
    else:
        locked = locked_package_versions(lockfile)
    for package, expected_version in packages.items():
        if not isinstance(package, str) or not isinstance(expected_version, str):
            failures.append("package names and versions must be strings")
            continue
        actual_version = locked.get(package)
        if actual_version != expected_version:
            failures.append(
                f"{package} lock version {actual_version!r} != {expected_version!r}"
            )

    seen_paths: set[str] = set()
    for asset in assets:
        if not isinstance(asset, dict):
            failures.append("each asset must be an object")
            continue
        relative = asset.get("path")
        expected_bytes = asset.get("bytes")
        expected_sha = asset.get("sha256")
        if not isinstance(relative, str) or not relative.startswith("apps/app/web/"):
            failures.append(f"invalid web asset path: {relative!r}")
            continue
        if relative in seen_paths:
            failures.append(f"duplicate web asset path: {relative}")
            continue
        seen_paths.add(relative)
        path = root / relative
        if not path.is_file():
            failures.append(f"missing web runtime asset: {relative}")
            continue
        if path.stat().st_size != expected_bytes:
            failures.append(
                f"{relative} bytes {path.stat().st_size} != {expected_bytes!r}"
            )
        actual_sha = sha256(path)
        if actual_sha != expected_sha:
            failures.append(f"{relative} sha256 {actual_sha} != {expected_sha!r}")

    required = {"apps/app/web/sqlite3.wasm", "apps/app/web/drift_worker.js"}
    missing_required = sorted(required - seen_paths)
    if missing_required:
        failures.append(f"required assets not declared: {', '.join(missing_required)}")
    if failures:
        return {
            "name": "web-drift-runtime-assets",
            "status": "fail",
            "diagnostic": failures,
        }
    return {"name": "web-drift-runtime-assets", "status": "pass"}


def find_identity_python() -> str | None:
    configured = os.environ.get("SYNAPSE_IDENTITY_PYTHON")
    candidates = [
        configured,
        str(
            Path.home()
            / ".cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe"
        ),
        sys.executable,
    ]
    for candidate in candidates:
        if not candidate:
            continue
        result = subprocess.run(
            [candidate, "-c", "import numpy, PIL"],
            capture_output=True,
        )
        if result.returncode == 0:
            return candidate
    return None


def build_receipt(root: Path, checks: list[dict[str, object]]) -> dict[str, object]:
    inventory = []
    missing = []
    for relative in INVENTORY_PATHS:
        path = root / relative
        if not path.is_file():
            missing.append(relative)
            continue
        inventory.append(
            {
                "path": relative,
                "bytes": path.stat().st_size,
                "sha256": sha256(path),
            }
        )
    status = (
        "pass"
        if not missing and all(check["status"] == "pass" for check in checks)
        else "fail"
    )
    return {
        "schemaVersion": 1,
        "status": status,
        "checks": checks,
        "inventory": inventory,
        "missing": missing,
        "policy": {
            "contracts": "clean regeneration byte comparison",
            "identity": "source geometry, optical metrics, manifest hashes, and installed-byte parity",
            "webRuntime": "locked package versions and byte-exact Drift worker/WASM assets",
            "generatedDart": "none currently declared",
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
    python = sys.executable
    identity_python = find_identity_python()
    if identity_python is None:
        identity_checks = [
            {
                "name": "identity-python-runtime",
                "status": "fail",
                "diagnostic": [
                    "Python with numpy and Pillow was not found.",
                    "Set SYNAPSE_IDENTITY_PYTHON to a compatible interpreter.",
                ],
            }
        ]
    else:
        identity_checks = [
            run_check(
                root,
                "selected-luma-identity-source-platform-install",
                [
                    identity_python,
                    "tool/identity/test_luma_facefront.py",
                    "--require-install",
                ],
            ),
            run_check(
                root,
                "selected-wordmark",
                [identity_python, "tool/identity/test_wordmark_assets.py"],
            ),
        ]
    checks = [
        verify_web_runtime_assets(root),
        run_check(
            root,
            "preservation-regeneration",
            [python, "tool/preservation/generate_preservation_contracts.py", "--check"],
        ),
        *identity_checks,
    ]
    receipt = build_receipt(root, checks)
    receipt_path = root / RECEIPT
    expected = canonical_bytes(receipt)
    if args.write_receipt and receipt["status"] == "pass":
        receipt_path.parent.mkdir(parents=True, exist_ok=True)
        receipt_path.write_bytes(expected)
    elif not receipt_path.is_file() or receipt_path.read_bytes() != expected:
        receipt["status"] = "fail"
        receipt["receiptFailure"] = "generated verification receipt is missing or stale"

    if receipt["status"] == "pass":
        print(
            "Generated gate PASS: "
            f"{len(checks)} checks / {len(receipt['inventory'])} hashed inputs"
        )
        return 0
    print(json.dumps(receipt, indent=2))
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
