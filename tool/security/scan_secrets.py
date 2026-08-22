#!/usr/bin/env python3
"""Scan committable text without ever printing a discovered secret value."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


TEXT_SUFFIXES = {
    ".bat",
    ".cjs",
    ".cmd",
    ".css",
    ".dart",
    ".env",
    ".gradle",
    ".html",
    ".js",
    ".json",
    ".kts",
    ".md",
    ".plist",
    ".properties",
    ".ps1",
    ".py",
    ".scss",
    ".sh",
    ".sql",
    ".toml",
    ".ts",
    ".tsx",
    ".txt",
    ".xml",
    ".yaml",
    ".yml",
}
MAX_FILE_BYTES = 5 * 1024 * 1024
EXCLUDED_PREFIXES = (
    "docs/codex/2026-07-15-synapse-medical-learning-os/assets/",
    "docs/codex/2026-07-15-synapse-medical-learning-os/logs/",
)


@dataclass(frozen=True)
class Rule:
    rule_id: str
    pattern: re.Pattern[str]
    capture_group: int = 0


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    rule: str
    fingerprint: str


RULES = (
    Rule("private-key-header", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    Rule("aws-access-key", re.compile(r"\bAKIA[A-Z0-9]{16}\b")),
    Rule("github-token", re.compile(r"\bgh[oprsu]_[A-Za-z0-9]{30,}\b")),
    Rule("openai-secret", re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b")),
    Rule("supabase-secret", re.compile(r"\bsb_secret_[A-Za-z0-9_-]{16,}\b")),
    Rule(
        "jwt",
        re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b"),
    ),
    Rule(
        "credential-url",
        re.compile(r"\b(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?):\/\/[^\s:/]+:([^\s@]{8,})@"),
        capture_group=1,
    ),
    Rule(
        "assigned-secret",
        re.compile(
            r"(?i)\b(?:password|passwd|secret|service_role_key|private_key|"
            r"api_key|access_token|auth_token)\b\s*[:=]\s*['\"]([^'\"]{8,})['\"]"
        ),
        capture_group=1,
    ),
)


def is_safe_placeholder(value: str) -> bool:
    normalized = value.strip().lower()
    return any(
        marker in normalized
        for marker in (
            "example",
            "fixture",
            "dummy",
            "placeholder",
            "redacted",
            "changeme",
            "public",
            "${",
            "{{",
            "<",
        )
    )


def scan_text(path: str, text: str) -> list[Finding]:
    findings: list[Finding] = []
    for rule in RULES:
        for match in rule.pattern.finditer(text):
            value = match.group(rule.capture_group)
            if is_safe_placeholder(value):
                continue
            findings.append(
                Finding(
                    path=path,
                    line=text.count("\n", 0, match.start()) + 1,
                    rule=rule.rule_id,
                    fingerprint=hashlib.sha256(value.encode("utf-8")).hexdigest()[:16],
                )
            )
    return findings


def committable_paths(root: Path) -> list[str]:
    commands = (
        ["git", "ls-files", "-z"],
        ["git", "ls-files", "--others", "--exclude-standard", "-z"],
    )
    paths: set[str] = set()
    for command in commands:
        result = subprocess.run(command, cwd=root, capture_output=True, check=True)
        paths.update(
            item.decode("utf-8", errors="surrogateescape").replace("\\", "/")
            for item in result.stdout.split(b"\0")
            if item
        )
    return sorted(paths)


def scan_repository(root: Path) -> dict[str, object]:
    findings: list[Finding] = []
    scanned: list[tuple[str, str]] = []
    skipped_oversize: list[str] = []
    total_bytes = 0
    for relative in committable_paths(root):
        if relative.startswith(EXCLUDED_PREFIXES):
            continue
        path = root / relative
        if not path.is_file() or path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        size = path.stat().st_size
        if size > MAX_FILE_BYTES:
            skipped_oversize.append(relative)
            continue
        raw = path.read_bytes()
        total_bytes += len(raw)
        digest = hashlib.sha256(raw).hexdigest()
        scanned.append((relative, digest))
        text = raw.decode("utf-8", errors="replace")
        findings.extend(scan_text(relative, text))

    inventory_digest = hashlib.sha256(
        "\n".join(f"{path}|{digest}" for path, digest in scanned).encode("utf-8")
    ).hexdigest().upper()
    return {
        "schemaVersion": 1,
        "status": "pass" if not findings else "fail",
        "filesScanned": len(scanned),
        "bytesScanned": total_bytes,
        "inventorySha256": inventory_digest,
        "skippedOversize": skipped_oversize,
        "findings": [asdict(finding) for finding in findings],
        "rules": [rule.rule_id for rule in RULES],
        "privacy": "finding output contains only path, line, rule, and a non-reversible short fingerprint",
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
    result = scan_repository(root)
    if args.write_receipt:
        receipt = args.write_receipt
        if not receipt.is_absolute():
            receipt = root / receipt
        receipt.parent.mkdir(parents=True, exist_ok=True)
        receipt.write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    if args.json or result["status"] != "pass":
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(
            "Secret scan PASS: "
            f"{result['filesScanned']} files / {result['bytesScanned']} bytes; "
            "zero findings"
        )
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
