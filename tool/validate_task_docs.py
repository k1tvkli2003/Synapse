#!/usr/bin/env python3
"""Repository-local structural/content gate for the active work-docs task."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


REQUIRED_FILES = (
    "00-brief.md",
    "01-plan.md",
    "02-state.md",
    "03-previews.md",
    "04-progress.md",
    "05-verification.md",
    "06-handoff.md",
)
REQUIRED_DIRS = ("assets", "logs")
VALID_STATUSES = {
    "planned",
    "active",
    "blocked",
    "paused",
    "ready-for-review",
    "done",
}
PLACEHOLDER = re.compile(r"\b(?:TODO|TBD|FIXME)\b", re.IGNORECASE)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def section(text: str, heading: str) -> str:
    match = re.search(rf"^##\s+{re.escape(heading)}\s*$", text, re.MULTILINE)
    if not match:
        return ""
    tail = text[match.end() :]
    next_heading = re.search(r"^##\s+", tail, re.MULTILINE)
    return tail[: next_heading.start() if next_heading else None].strip()


def validate_structure(task_dir: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    if not task_dir.is_dir():
        return [f"Task directory does not exist: {task_dir}"], warnings

    for name in REQUIRED_DIRS:
        if not (task_dir / name).is_dir():
            errors.append(f"Missing required directory: {name}")
    for name in REQUIRED_FILES:
        path = task_dir / name
        if not path.is_file():
            errors.append(f"Missing required file: {name}")
        elif path.stat().st_size == 0:
            errors.append(f"Required file is empty: {name}")

    index = task_dir.parent / "_index.md"
    if not index.is_file():
        warnings.append(f"Missing sibling index: {index}")
    elif f"`{task_dir.name}`" not in read(index):
        warnings.append(f"Task is not listed in sibling index: {task_dir.name}")
    return errors, warnings


def validate_content(task_dir: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    texts = {name: read(task_dir / name) for name in REQUIRED_FILES}

    for name, text in texts.items():
        if PLACEHOLDER.search(text):
            errors.append(f"Unfinished placeholder found in {name}")

    required_sections = {
        "00-brief.md": ("Request", "Success Criteria"),
        "02-state.md": ("Current State", "Done", "Remaining"),
        "05-verification.md": ("Summary",),
        "06-handoff.md": ("Outcome", "Done", "Remaining", "Verification"),
    }
    for name, headings in required_sections.items():
        for heading in headings:
            if not section(texts[name], heading):
                errors.append(f"Missing meaningful {heading!r} section in {name}")

    status = re.search(r"Current status:\s*`?([a-z-]+)`?", texts["02-state.md"])
    if not status:
        errors.append("Missing current status in 02-state.md")
    elif status.group(1) not in VALID_STATUSES:
        errors.append(f"Invalid current status: {status.group(1)}")

    result = re.search(
        r"Result:\s*([a-z -]+)", texts["05-verification.md"], re.IGNORECASE
    )
    if not result:
        errors.append("Missing verification result in 05-verification.md")
    elif result.group(1).strip().lower() not in {
        "passed",
        "failed",
        "partial",
        "not run",
    }:
        errors.append(f"Unknown verification result: {result.group(1).strip()}")
    return errors, warnings


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("task_dir", type=Path)
    parser.add_argument("--structure-only", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    task_dir = args.task_dir.expanduser().resolve()
    errors, warnings = validate_structure(task_dir)
    if not args.structure_only and not errors:
        content_errors, content_warnings = validate_content(task_dir)
        errors.extend(content_errors)
        warnings.extend(content_warnings)

    result = {
        "taskDir": str(task_dir),
        "structureOnly": args.structure_only,
        "status": "pass" if not errors else "fail",
        "errors": errors,
        "warnings": warnings,
    }
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"Task docs: {task_dir}")
        for warning in warnings:
            print(f"WARNING: {warning}")
        for error in errors:
            print(f"ERROR: {error}")
        print("PASS" if not errors else "FAIL")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
