#!/usr/bin/env python3
"""Enforce one Synapse identity and functional names for absorbed capabilities."""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import date
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class Finding:
    path: str
    line: int
    column: int
    kind: str
    rule: str
    match_sha256: str


def _normalize_path(value: str) -> str:
    return value.replace("\\", "/").removeprefix("./")


def _match_sha256(value: str) -> str:
    return hashlib.sha256(value.casefold().encode("utf-8")).hexdigest().upper()


def compile_rules(policy: dict[str, object]) -> list[tuple[str, re.Pattern[str]]]:
    compiled: list[tuple[str, re.Pattern[str]]] = []
    for raw in policy.get("forbiddenRules", []):
        if not isinstance(raw, dict):
            continue
        rule_id = raw.get("id")
        pattern = raw.get("pattern")
        if isinstance(rule_id, str) and isinstance(pattern, str):
            compiled.append((rule_id, re.compile(pattern)))
    return compiled


def scan_value(
    path: str,
    value: str,
    rules: Iterable[tuple[str, re.Pattern[str]]],
    *,
    kind: str,
) -> list[Finding]:
    findings: list[Finding] = []
    for rule_id, pattern in rules:
        for match in pattern.finditer(value):
            line = value.count("\n", 0, match.start()) + 1 if kind == "content" else 0
            last_break = value.rfind("\n", 0, match.start())
            column = match.start() - last_break if kind == "content" else 0
            findings.append(
                Finding(
                    path=path,
                    line=line,
                    column=column,
                    kind=kind,
                    rule=rule_id,
                    match_sha256=_match_sha256(match.group(0)),
                )
            )
    return findings


def _matches_scope(path: str, globs: Iterable[str]) -> bool:
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in globs)


def committable_paths(root: Path) -> list[str]:
    commands = (
        ["git", "ls-files", "-z"],
        ["git", "ls-files", "--others", "--exclude-standard", "-z"],
    )
    paths: set[str] = set()
    for command in commands:
        result = subprocess.run(command, cwd=root, capture_output=True, check=True)
        paths.update(
            _normalize_path(item.decode("utf-8", errors="surrogateescape"))
            for item in result.stdout.split(b"\0")
            if item
        )
    return sorted(paths)


def _allowlist_errors(policy: dict[str, object], today: date) -> list[str]:
    errors: list[str] = []
    allowlist = policy.get("allowlist", [])
    if not isinstance(allowlist, list):
        return ["allowlist must be an array"]
    required = {
        "path",
        "kind",
        "ruleId",
        "matchSha256",
        "reason",
        "owner",
        "expiresOn",
    }
    for index, item in enumerate(allowlist):
        if not isinstance(item, dict):
            errors.append(f"allowlist[{index}] must be an object")
            continue
        missing = sorted(required - set(item))
        if missing:
            errors.append(f"allowlist[{index}] missing: {', '.join(missing)}")
            continue
        if item["kind"] not in {"content", "path"}:
            errors.append(f"allowlist[{index}].kind must be content or path")
        if not str(item["reason"]).strip() or not str(item["owner"]).strip():
            errors.append(f"allowlist[{index}] needs a concrete reason and owner")
        try:
            expiry = date.fromisoformat(str(item["expiresOn"]))
        except ValueError:
            errors.append(f"allowlist[{index}].expiresOn must be YYYY-MM-DD")
        else:
            if expiry < today:
                errors.append(f"allowlist[{index}] expired on {expiry.isoformat()}")
    return errors


def validate_policy(policy: dict[str, object], *, today: date | None = None) -> list[str]:
    errors: list[str] = []
    if policy.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1")
    if policy.get("productName") != "Synapse":
        errors.append("productName must remain Synapse")
    for key in ("scanGlobs", "textSuffixes", "forbiddenRules", "capabilityMap"):
        if not isinstance(policy.get(key), list) or not policy[key]:
            errors.append(f"{key} must be a non-empty array")
    rules = compile_rules(policy)
    if len(rules) != len(policy.get("forbiddenRules", [])):
        errors.append("every forbidden rule needs a string id and regex pattern")
    if len({rule_id for rule_id, _ in rules}) != len(rules):
        errors.append("forbidden rule ids must be unique")
    errors.extend(_allowlist_errors(policy, today or date.today()))
    return errors


def _capability_map_errors(
    root: Path,
    policy: dict[str, object],
    rules: list[tuple[str, re.Pattern[str]]],
) -> list[str]:
    errors: list[str] = []
    ledger_value = policy.get("capabilityLedger")
    if not isinstance(ledger_value, str):
        return ["capabilityLedger must be a repository-relative path"]
    ledger_path = root / ledger_value
    if not ledger_path.is_file():
        return [f"capability ledger does not exist: {ledger_value}"]
    try:
        ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"capability ledger cannot be read: {error}"]

    prefix = str(policy.get("legacyCapabilityIdPrefix", "studyhub."))
    source_ids = {
        str(entry.get("id"))
        for entry in ledger.get("entries", [])
        if isinstance(entry, dict) and str(entry.get("id", "")).startswith(prefix)
    }
    mappings = policy.get("capabilityMap", [])
    mapped_ids = [str(item.get("sourceId")) for item in mappings if isinstance(item, dict)]
    duplicate_ids = sorted({item for item in mapped_ids if mapped_ids.count(item) > 1})
    if duplicate_ids:
        errors.append(f"duplicate capability mappings: {', '.join(duplicate_ids)}")
    missing = sorted(source_ids - set(mapped_ids))
    extra = sorted(set(mapped_ids) - source_ids)
    if missing:
        errors.append(f"unmapped legacy capabilities: {', '.join(missing)}")
    if extra:
        errors.append(f"unknown legacy capabilities in naming map: {', '.join(extra)}")

    required = {
        "sourceId",
        "canonicalDomain",
        "surface",
        "userFacingLabel",
        "entryContext",
        "analyticsNamespace",
        "exposure",
    }
    valid_exposure = {"visible", "contextual", "background", "migration-only"}
    product_fields = (
        "canonicalDomain",
        "surface",
        "userFacingLabel",
        "entryContext",
        "analyticsNamespace",
    )
    vague_hub = re.compile(r"(?i)\bhub\b")
    for index, item in enumerate(mappings):
        if not isinstance(item, dict):
            errors.append(f"capabilityMap[{index}] must be an object")
            continue
        missing_fields = sorted(required - set(item))
        if missing_fields:
            errors.append(
                f"capabilityMap[{index}] missing: {', '.join(missing_fields)}"
            )
            continue
        if item["exposure"] not in valid_exposure:
            errors.append(f"{item['sourceId']}: invalid exposure {item['exposure']}")
        analytics = str(item["analyticsNamespace"])
        if not analytics.startswith("synapse."):
            errors.append(f"{item['sourceId']}: analytics namespace must start synapse.")
        for field in product_fields:
            value = str(item[field]).strip()
            if not value:
                errors.append(f"{item['sourceId']}: {field} cannot be empty")
                continue
            if vague_hub.search(value):
                errors.append(
                    f"{item['sourceId']}: {field} uses vague standalone Hub naming"
                )
            if scan_value(
                f"capabilityMap[{index}].{field}", value, rules, kind="content"
            ):
                errors.append(
                    f"{item['sourceId']}: {field} leaks a forbidden legacy brand"
                )
    return errors


def _allowlist_match(finding: Finding, item: dict[str, object]) -> bool:
    return (
        finding.path == _normalize_path(str(item.get("path", "")))
        and finding.kind == item.get("kind")
        and finding.rule == item.get("ruleId")
        and finding.match_sha256 == str(item.get("matchSha256", "")).upper()
    )


def scan_repository(
    root: Path,
    policy: dict[str, object],
    *,
    paths: Iterable[str] | None = None,
    today: date | None = None,
) -> dict[str, object]:
    root = root.resolve()
    policy_errors = validate_policy(policy, today=today)
    rules = compile_rules(policy)
    if not policy_errors:
        policy_errors.extend(_capability_map_errors(root, policy, rules))

    globs = [str(item) for item in policy.get("scanGlobs", [])]
    suffixes = {str(item).lower() for item in policy.get("textSuffixes", [])}
    candidates = sorted(
        {_normalize_path(item) for item in (paths if paths is not None else committable_paths(root))}
    )
    raw_findings: list[Finding] = []
    files_scanned = 0
    paths_scanned = 0
    bytes_scanned = 0
    for relative in candidates:
        if not _matches_scope(relative, globs):
            continue
        paths_scanned += 1
        raw_findings.extend(scan_value(relative, relative, rules, kind="path"))
        path = root / relative
        if not path.is_file() or path.suffix.lower() not in suffixes:
            continue
        raw = path.read_bytes()
        files_scanned += 1
        bytes_scanned += len(raw)
        raw_findings.extend(
            scan_value(
                relative,
                raw.decode("utf-8", errors="replace"),
                rules,
                kind="content",
            )
        )

    allowlist = [item for item in policy.get("allowlist", []) if isinstance(item, dict)]
    used_allowlist: set[int] = set()
    findings: list[Finding] = []
    for finding in raw_findings:
        allowed = False
        for index, item in enumerate(allowlist):
            if _allowlist_match(finding, item):
                used_allowlist.add(index)
                allowed = True
                break
        if not allowed:
            findings.append(finding)
    unused_allowlist = [index for index in range(len(allowlist)) if index not in used_allowlist]
    if unused_allowlist:
        policy_errors.append(
            "stale or non-exact allowlist entries: "
            + ", ".join(str(index) for index in unused_allowlist)
        )

    policy_digest = hashlib.sha256(
        (json.dumps(policy, ensure_ascii=False, sort_keys=True) + "\n").encode("utf-8")
    ).hexdigest().upper()
    return {
        "schemaVersion": 1,
        "status": "pass" if not findings and not policy_errors else "fail",
        "productName": policy.get("productName"),
        "policyId": policy.get("policyId"),
        "policySha256": policy_digest,
        "pathsScanned": paths_scanned,
        "filesScanned": files_scanned,
        "bytesScanned": bytes_scanned,
        "capabilityMappings": len(policy.get("capabilityMap", [])),
        "policyErrors": policy_errors,
        "findings": [asdict(finding) for finding in findings],
        "allowlistEntries": len(allowlist),
        "allowlistEntriesUsed": len(used_allowlist),
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--policy",
        type=Path,
        default=Path("contracts/integrity/product-language-policy.v1.json"),
    )
    parser.add_argument("--write-receipt", type=Path)
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = args.root.resolve()
    policy_path = args.policy if args.policy.is_absolute() else root / args.policy
    try:
        policy = json.loads(policy_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"Product language FAIL: cannot load policy: {error}")
        return 1
    result = scan_repository(root, policy)
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
            "Product language PASS: "
            f"{result['filesScanned']} product files / "
            f"{result['capabilityMappings']} absorbed capability names; "
            "one Synapse identity, zero legacy-brand leaks"
        )
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
