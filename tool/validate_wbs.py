#!/usr/bin/env python3
"""Validate the durable Synapse atomic work breakdown structure."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROW_RE = re.compile(r"^\| WBS-(?P<id>\d{3}) \| (?P<status>[^|]+) \|(?P<body>.*)\|$")
DEP_RE = re.compile(r"WBS-(?P<start>\d{3})(?:\.\.(?P<end>\d{3}))?")
ALLOWED_STATUSES = {"done", "active", "planned", "blocked"}


@dataclass(frozen=True)
class Step:
    number: int
    status: str
    task: str
    dependencies: str
    owner: str
    evidence: str
    line_number: int


def parse_step(line: str, line_number: int) -> Step | None:
    match = ROW_RE.match(line)
    if match is None:
        return None

    columns = [part.strip() for part in line.strip().strip("|").split("|")]
    if len(columns) != 6:
        raise ValueError(
            f"line {line_number}: expected 6 table columns, found {len(columns)}"
        )
    step_id, status, task, dependencies, owner, evidence = columns
    return Step(
        number=int(step_id.removeprefix("WBS-")),
        status=status,
        task=task,
        dependencies=dependencies,
        owner=owner,
        evidence=evidence,
        line_number=line_number,
    )


def dependency_numbers(raw: str) -> set[int]:
    if raw == "none":
        return set()

    numbers: set[int] = set()
    for match in DEP_RE.finditer(raw):
        start = int(match.group("start"))
        end_text = match.group("end")
        if end_text is None:
            numbers.add(start)
            continue
        end = int(end_text)
        if end < start:
            raise ValueError(f"descending dependency range WBS-{start:03d}..{end:03d}")
        numbers.update(range(start, end + 1))
    if not numbers:
        raise ValueError(f"dependency field has no WBS reference: {raw!r}")
    return numbers


def validate(path: Path, expected: int) -> list[str]:
    errors: list[str] = []
    steps: list[Step] = []

    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        try:
            step = parse_step(line, line_number)
        except ValueError as error:
            errors.append(str(error))
            continue
        if step is not None:
            steps.append(step)

    if len(steps) != expected:
        errors.append(f"expected {expected} steps, found {len(steps)}")

    numbers = [step.number for step in steps]
    expected_numbers = list(range(1, expected + 1))
    if numbers != expected_numbers:
        missing = sorted(set(expected_numbers) - set(numbers))
        duplicates = sorted(number for number in set(numbers) if numbers.count(number) > 1)
        errors.append(
            "step IDs are not a strict 001.."
            f"{expected:03d} sequence; missing={missing}, duplicates={duplicates}"
        )

    known = set(numbers)
    for step in steps:
        if step.status not in ALLOWED_STATUSES:
            errors.append(
                f"line {step.line_number}: WBS-{step.number:03d} has invalid status "
                f"{step.status!r}"
            )
        for field_name, value in (
            ("task", step.task),
            ("owner", step.owner),
            ("exit evidence", step.evidence),
        ):
            if not value:
                errors.append(
                    f"line {step.line_number}: WBS-{step.number:03d} has empty {field_name}"
                )
        try:
            dependencies = dependency_numbers(step.dependencies)
        except ValueError as error:
            errors.append(f"line {step.line_number}: WBS-{step.number:03d}: {error}")
            continue
        unknown = sorted(dependencies - known)
        if unknown:
            errors.append(
                f"line {step.line_number}: WBS-{step.number:03d} references unknown {unknown}"
            )
        non_prior = sorted(number for number in dependencies if number >= step.number)
        if non_prior:
            errors.append(
                f"line {step.line_number}: WBS-{step.number:03d} has non-prior "
                f"dependencies {non_prior}"
            )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument("--expected", type=int, default=440)
    args = parser.parse_args()

    errors = validate(args.path, args.expected)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"WBS OK: {args.expected} ordered, unique, dependency-safe steps")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
