#!/usr/bin/env python3
"""Discover and atomize the user-provided Harrison-like source corpus.

TypeScript sidecars remain inert and untrusted. A strict static parser accounts
for literal candidates and structural syntax without importing, evaluating,
transpiling, or invoking any source-side code.
"""

from __future__ import annotations

import argparse
import bisect
import hashlib
import json
import os
import re
import sys
import tempfile
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Iterator, Sequence

from tool.curriculum.typescript_static_parser import (
    TypescriptStaticParseError,
    atomize_typescript_sidecar,
)


SCHEMA_URI = "https://synapse.local/contracts/curriculum/source-scan.schema.v1.json"
CONTRACT_ID = "synapse.curriculum.source-scan.v1"
PARSER_NAME = "synapse-static-source-atomizer"
PARSER_VERSION = "1.1.1"
SOURCE_KEY = "harrison-sim"
SOURCE_CLASSIFICATION = "user-provided-simulated-medical-reference"

PART_RE = re.compile(r"^Part_(\d+)(?:_|$)", re.IGNORECASE)
CHAPTER_RE = re.compile(r"^Chapter_(\d+)(?:_|$)", re.IGNORECASE)
LESSON_RE = re.compile(r"^Lesson_(\d+)(?:_|$)", re.IGNORECASE)
ATX_HEADING_RE = re.compile(r"^( {0,3})(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$")
SETEXT_RE = re.compile(r"^ {0,3}(=+|-+)[ \t]*$")
FENCE_RE = re.compile(r"^\s*(`{3,}|~{3,})(.*)$")
LIST_RE = re.compile(r"^(\s*)([-+*]|\d+[.)])\s+(.+?)\s*$")
FOOTNOTE_RE = re.compile(r"^\s*\[\^([^\]]+)\]:\s*(.*)$")
THEMATIC_BREAK_RE = re.compile(
    r"^\s*(?:(?:\*\s*){3,}|(?:-\s*){3,}|(?:_\s*){3,})$"
)
TABLE_SEPARATOR_CELL_RE = re.compile(r"^\s*:?-{3,}:?\s*$")
IMAGE_RE = re.compile(r"!\[([^\]]*)\]\(([^)]*)\)")
FIGURE_LABEL_RE = re.compile(
    r"(?i)(?:^|\b)(?:figure|fig\.?|شکل)\s*[A-Za-z0-9۰-۹-]+"
)
CROSS_REFERENCE_RE = re.compile(
    r"(?i)\b(?:chap(?:ter)?s?\.?|section)\s*[A-Za-z0-9۰-۹]+(?:\s*[–—-]\s*[A-Za-z0-9۰-۹]+)?"
)
FORMULA_PATTERNS = (
    re.compile(r"(?<!\\)\$(?!\$)(.+?)(?<!\\)\$", re.DOTALL),
    re.compile(r"\\\((.+?)\\\)", re.DOTALL),
    re.compile(r"\\\[(.+?)\\\]", re.DOTALL),
)
NUMERIC_THRESHOLD_RE = re.compile(
    r"(?ix)(?:"
    r"(?:at\s+least|at\s+most|more\s+than|less\s+than|greater\s+than|"
    r"fewer\s+than|حداقل|حداکثر|بیش\s+از|کمتر\s+از)\s*"
    r"|[<>≤≥]\s*)?"
    r"\d+(?:[.,]\d+)?"
    r"(?:\s*(?:-|–|—|to|تا)\s*\d+(?:[.,]\d+)?)?"
    r"\s*(?:%|percent|mg|g|kg|mcg|μg|mm\s*hg|cm|mm|ml|l|"
    r"bpm|beats?(?:/|\s+per\s+)min(?:ute)?|years?|months?|weeks?|days?|"
    r"hours?|minutes?|seconds?|سال|ماه|هفته|روز|ساعت|دقیقه|ثانیه)\b"
)
WARNING_RE = re.compile(
    r"(?i)\b(?:warning|caution|danger|red[ -]?flag|contraindicat|emergency|"
    r"هشدار|خطر|اورژانس)\b"
)
PEARL_RE = re.compile(
    r"(?i)\b(?:clinical pearl|pearl|pitfall|key point|takeaway|نکته|دام تشخیصی)\b"
)
LATIN_RE = re.compile(r"[A-Za-z]")
PERSIAN_RE = re.compile(r"[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]")

ARTIFACT_ROLES = {
    "part_index",
    "chapter_markdown",
    "supplemental_markdown",
    "lesson_markdown",
    "derived_find_sidecar",
    "derived_summary_sidecar",
    "derived_quiz_sidecar",
    "derived_enrich_sidecar",
    "contributor_metadata_sidecar",
    "media",
    "other_reviewed_source",
}
ATOM_TYPES = {
    "heading",
    "claim",
    "definition",
    "mechanism_link",
    "paragraph_context",
    "list_item",
    "table_header",
    "table_cell",
    "formula",
    "numeric_threshold",
    "clinical_pearl",
    "warning",
    "cross_reference",
    "footnote",
    "figure_reference",
    "figure_caption",
    "media_label",
    "quiz_stem_candidate",
    "quiz_option_candidate",
    "quiz_explanation_candidate",
    "contributor_metadata",
    "decorative_or_navigation",
}


class ScanError(RuntimeError):
    """Raised when a deterministic and exhaustive scan cannot be guaranteed."""


@dataclass(frozen=True)
class Container:
    part_ordinal: int
    part_name: str
    chapter_ordinal: int | None
    chapter_name: str | None
    lesson_ordinal: int | None
    lesson_name: str | None

    @property
    def course_key(self) -> str:
        return f"{SOURCE_KEY}/course/{self.part_ordinal:02d}"

    @property
    def chapter_key(self) -> str:
        if self.chapter_ordinal is None:
            return f"{self.course_key}/chapter/index"
        return f"{self.course_key}/chapter/{self.chapter_ordinal:03d}"

    @property
    def lesson_key(self) -> str | None:
        if self.lesson_ordinal is None:
            return None
        return f"{self.chapter_key}/source-lesson/{self.lesson_ordinal:03d}"


@dataclass
class AtomDraft:
    atom_type: str
    start_line: int
    end_line: int
    start_character: int
    end_character: int
    heading_path: list[str]
    source_text: str
    source_locale: str
    instructional_disposition: str = "required"
    non_instructional_reason: str | None = None
    risk_tier: str = "clinical_high"
    table_row: int | None = None
    table_column: int | None = None
    media_reference: str | None = None
    duplicate_group_id: str | None = None


@dataclass
class DocumentBuild:
    document: dict[str, object]
    order: dict[str, object]
    atoms: list[dict[str, object]] = field(default_factory=list)
    coverage: dict[str, object] = field(default_factory=dict)
    media: dict[str, object] | None = None


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_text(value: str) -> str:
    return _sha256_bytes(value.encode("utf-8"))


def _normalized_path(value: Path | str) -> str:
    raw = str(value).replace("\\", "/")
    return unicodedata.normalize("NFC", raw.removeprefix("./"))


def _long_path_aware(path: Path, *, strict: bool = True) -> Path:
    """Return an absolute path that can address >260-character files on Windows."""
    resolved = path.resolve(strict=strict)
    if os.name != "nt":
        return resolved
    value = str(resolved)
    if value.startswith("\\\\?\\"):
        return resolved
    if value.startswith("\\\\"):
        return Path("\\\\?\\UNC\\" + value[2:])
    return Path("\\\\?\\" + value)


def _is_within(candidate: Path, boundary: Path) -> bool:
    try:
        candidate.relative_to(boundary)
    except ValueError:
        return False
    return True


def _canonical_text(value: str) -> str:
    return unicodedata.normalize("NFC", value.replace("\r\n", "\n").replace("\r", "\n"))


def _normalized_atom_text(value: str) -> str:
    return " ".join(unicodedata.normalize("NFC", value).split())


def _source_locale(value: str) -> str:
    latin = len(LATIN_RE.findall(value))
    persian = len(PERSIAN_RE.findall(value))
    if latin and persian:
        return "mixed"
    if persian:
        return "fa"
    if latin:
        return "en"
    return "und"


def _numeric_prefix(name: str, pattern: re.Pattern[str], label: str) -> int:
    match = pattern.match(name)
    if not match:
        raise ScanError(f"cannot derive {label} ordinal from {name!r}")
    return int(match.group(1))


def _unique_numbered_directories(
    parent: Path,
    pattern: re.Pattern[str],
    label: str,
) -> list[tuple[int, Path]]:
    entries: list[tuple[int, Path]] = []
    seen: dict[int, Path] = {}
    for path in parent.iterdir():
        if not path.is_dir() or path.is_symlink():
            continue
        match = pattern.match(path.name)
        if not match:
            continue
        ordinal = int(match.group(1))
        if ordinal in seen:
            raise ScanError(
                f"duplicate {label} ordinal {ordinal}: {seen[ordinal].name!r}, {path.name!r}"
            )
        seen[ordinal] = path
        entries.append((ordinal, path))
    return sorted(entries, key=lambda item: (item[0], unicodedata.normalize("NFC", item[1].name).casefold()))


def _course_values(values: Sequence[str]) -> list[int]:
    courses: set[int] = set()
    for value in values:
        if not re.fullmatch(r"\d{1,3}", value.strip()):
            raise ScanError(f"invalid --course value {value!r}; expected a numeric Part ordinal")
        ordinal = int(value)
        if ordinal < 1:
            raise ScanError("course ordinals start at 1")
        courses.add(ordinal)
    return sorted(courses)


def _sniff_mime(raw: bytes, extension: str) -> tuple[str, str]:
    if raw.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png", "png"
    if raw.startswith(b"\xff\xd8\xff"):
        return "image/jpeg", "jpeg"
    if raw.startswith((b"GIF87a", b"GIF89a")):
        return "image/gif", "gif"
    if len(raw) >= 12 and raw[:4] == b"RIFF" and raw[8:12] == b"WEBP":
        return "image/webp", "webp"
    if raw.startswith(b"%PDF-"):
        return "application/pdf", "pdf"

    prefix = raw[:4096]
    try:
        text_prefix = prefix.decode("utf-8-sig")
    except UnicodeDecodeError:
        text_prefix = ""
    stripped = text_prefix.lstrip()
    if stripped.startswith("<svg") or (
        stripped.startswith("<?xml") and "<svg" in stripped[:1000]
    ):
        return "image/svg+xml", "svg"
    if extension == ".md":
        return "text/markdown", "markdown"
    if extension in {".ts", ".tsx"}:
        return "text/typescript", "typescript"
    if text_prefix or not raw:
        return "text/plain", "text"
    return "application/octet-stream", "binary"


def _expected_format(extension: str) -> str | None:
    return {
        ".png": "png",
        ".jpg": "jpeg",
        ".jpeg": "jpeg",
        ".gif": "gif",
        ".webp": "webp",
        ".svg": "svg",
        ".pdf": "pdf",
        ".md": "markdown",
        ".ts": "typescript",
        ".tsx": "typescript",
    }.get(extension)


def _classify_role(path: Path, container: Container, detected_mime: str) -> str:
    extension = path.suffix.casefold()
    stem = path.stem.casefold()
    if extension == ".md":
        if container.chapter_ordinal is None:
            if "chapters" in stem and stem.startswith(f"part_{container.part_ordinal:02d}"):
                return "part_index"
            return "supplemental_markdown"
        if container.lesson_ordinal is not None:
            expected = unicodedata.normalize("NFC", container.lesson_name or "").casefold()
            return "lesson_markdown" if stem == expected else "supplemental_markdown"
        expected = unicodedata.normalize("NFC", container.chapter_name or "").casefold()
        return "chapter_markdown" if stem == expected else "supplemental_markdown"
    if extension in {".ts", ".tsx"}:
        for suffix, role in (
            ("_find", "derived_find_sidecar"),
            ("_summary", "derived_summary_sidecar"),
            ("_quiz", "derived_quiz_sidecar"),
            ("_enrich", "derived_enrich_sidecar"),
            ("_contributors", "contributor_metadata_sidecar"),
            ("_contributor", "contributor_metadata_sidecar"),
        ):
            if stem.endswith(suffix):
                return role
        return "other_reviewed_source"
    if detected_mime.startswith("image/"):
        return "media"
    return "other_reviewed_source"


def _authority_tier(role: str, extension: str) -> str:
    if role == "part_index":
        return "order_metadata_only"
    if role in {"chapter_markdown", "lesson_markdown", "supplemental_markdown"}:
        return "primary_user_corpus"
    if role == "media":
        return "media_evidence"
    if role == "contributor_metadata_sidecar":
        return "non_instructional"
    if extension in {".ts", ".tsx"}:
        return "derived_legacy_candidate"
    return "non_instructional"


def _container_for_file(part_ordinal: int, part_path: Path, path: Path) -> Container:
    relative_parts = path.relative_to(part_path).parts
    chapter_ordinal: int | None = None
    chapter_name: str | None = None
    lesson_ordinal: int | None = None
    lesson_name: str | None = None
    if len(relative_parts) >= 2 and CHAPTER_RE.match(relative_parts[0]):
        chapter_name = relative_parts[0]
        chapter_ordinal = _numeric_prefix(chapter_name, CHAPTER_RE, "chapter")
        if len(relative_parts) >= 3 and LESSON_RE.match(relative_parts[1]):
            lesson_name = relative_parts[1]
            lesson_ordinal = _numeric_prefix(lesson_name, LESSON_RE, "lesson")
    return Container(
        part_ordinal=part_ordinal,
        part_name=part_path.name,
        chapter_ordinal=chapter_ordinal,
        chapter_name=chapter_name,
        lesson_ordinal=lesson_ordinal,
        lesson_name=lesson_name,
    )


def _line_records(text: str) -> tuple[list[str], list[int]]:
    lines = text.splitlines(keepends=True)
    if not lines:
        return [""], [0]
    starts: list[int] = []
    offset = 0
    for line in lines:
        starts.append(offset)
        offset += len(line)
    return lines, starts


def _line_body(line: str) -> str:
    return line.rstrip("\n")


def _span_text(text: str, start: int, end: int) -> str:
    return text[start:end]


def _heading_path_value(headings: list[str | None]) -> list[str]:
    return [item for item in headings if item]


def _table_cells(line: str) -> list[tuple[str, int, int]]:
    """Return trimmed cell text and source offsets within one Markdown row."""
    body = line.rstrip("\n")
    boundaries: list[int] = [-1]
    escaped = False
    for index, character in enumerate(body):
        if character == "\\" and not escaped:
            escaped = True
            continue
        if character == "|" and not escaped:
            boundaries.append(index)
        escaped = False
    boundaries.append(len(body))
    cells: list[tuple[str, int, int]] = []
    for left, right in zip(boundaries, boundaries[1:]):
        raw_start = left + 1
        raw_end = right
        raw_value = body[raw_start:raw_end]
        leading = len(raw_value) - len(raw_value.lstrip())
        trailing = len(raw_value.rstrip())
        start = raw_start + leading
        end = raw_start + trailing
        value = body[start:end]
        if not value and (left == -1 or right == len(body)):
            continue
        cells.append((value, start, end))
    return cells


def _is_table_separator(line: str) -> bool:
    cells = _table_cells(line)
    return bool(cells) and all(TABLE_SEPARATOR_CELL_RE.match(value) for value, _, _ in cells)


def _paragraph_atom_type(value: str, heading_path: Sequence[str]) -> tuple[str, str]:
    signal = " ".join([*heading_path, value])
    if FIGURE_LABEL_RE.search(value[:80]):
        return "figure_caption", "clinical_high"
    if WARNING_RE.search(signal):
        return "warning", "safety_critical"
    if PEARL_RE.search(signal):
        return "clinical_pearl", "clinical_high"
    return "claim", "clinical_high"


def _subatoms_for_span(
    value: str,
    absolute_start: int,
    start_line: int,
    end_line: int,
    heading_path: list[str],
) -> Iterator[AtomDraft]:
    def match_lines(start: int, end: int) -> tuple[int, int]:
        exact_start_line = start_line + value.count("\n", 0, start)
        final_character = max(start, end - 1)
        exact_end_line = start_line + value.count("\n", 0, final_character)
        return exact_start_line, exact_end_line

    for image in IMAGE_RE.finditer(value):
        reference = image.group(2).strip() or None
        exact_start_line, exact_end_line = match_lines(image.start(), image.end())
        yield AtomDraft(
            atom_type="figure_reference",
            start_line=exact_start_line,
            end_line=exact_end_line,
            start_character=absolute_start + image.start(),
            end_character=absolute_start + image.end(),
            heading_path=list(heading_path),
            source_text=image.group(0),
            source_locale=_source_locale(image.group(1)),
            risk_tier="clinical_high",
            media_reference=reference,
        )
    for formula_pattern in FORMULA_PATTERNS:
        for formula in formula_pattern.finditer(value):
            exact_start_line, exact_end_line = match_lines(formula.start(), formula.end())
            yield AtomDraft(
                atom_type="formula",
                start_line=exact_start_line,
                end_line=exact_end_line,
                start_character=absolute_start + formula.start(),
                end_character=absolute_start + formula.end(),
                heading_path=list(heading_path),
                source_text=formula.group(0),
                source_locale=_source_locale(formula.group(0)),
                risk_tier="clinical_high",
            )
    for threshold in NUMERIC_THRESHOLD_RE.finditer(value):
        exact_start_line, exact_end_line = match_lines(
            threshold.start(), threshold.end()
        )
        yield AtomDraft(
            atom_type="numeric_threshold",
            start_line=exact_start_line,
            end_line=exact_end_line,
            start_character=absolute_start + threshold.start(),
            end_character=absolute_start + threshold.end(),
            heading_path=list(heading_path),
            source_text=threshold.group(0),
            source_locale=_source_locale(threshold.group(0)),
            risk_tier="clinical_high",
        )
    for cross_reference in CROSS_REFERENCE_RE.finditer(value):
        exact_start_line, exact_end_line = match_lines(
            cross_reference.start(), cross_reference.end()
        )
        yield AtomDraft(
            atom_type="cross_reference",
            start_line=exact_start_line,
            end_line=exact_end_line,
            start_character=absolute_start + cross_reference.start(),
            end_character=absolute_start + cross_reference.end(),
            heading_path=list(heading_path),
            source_text=cross_reference.group(0),
            source_locale=_source_locale(cross_reference.group(0)),
            risk_tier="clinical_high",
        )


def _make_draft(
    *,
    atom_type: str,
    text: str,
    start_line: int,
    end_line: int,
    start_character: int,
    end_character: int,
    heading_path: list[str],
    navigation_only: bool = False,
    risk_tier: str = "clinical_high",
    table_row: int | None = None,
    table_column: int | None = None,
    media_reference: str | None = None,
) -> AtomDraft:
    if navigation_only:
        atom_type = "decorative_or_navigation"
        disposition = "non_instructional"
        reason = "part_index_navigation"
        risk_tier = "foundational"
    else:
        disposition = "required"
        reason = None
    return AtomDraft(
        atom_type=atom_type,
        start_line=start_line,
        end_line=end_line,
        start_character=start_character,
        end_character=end_character,
        heading_path=heading_path,
        source_text=text,
        source_locale=_source_locale(text),
        instructional_disposition=disposition,
        non_instructional_reason=reason,
        risk_tier=risk_tier,
        table_row=table_row,
        table_column=table_column,
        media_reference=media_reference,
    )


def atomize_markdown(text: str, *, navigation_only: bool = False) -> tuple[list[AtomDraft], list[str]]:
    """Atomize Markdown without executing or rendering embedded content."""
    canonical = _canonical_text(text)
    if canonical == "":
        return [
            AtomDraft(
                atom_type="decorative_or_navigation",
                start_line=1,
                end_line=1,
                start_character=0,
                end_character=0,
                heading_path=[],
                source_text="",
                source_locale="und",
                instructional_disposition="non_instructional",
                non_instructional_reason="empty_markdown",
                risk_tier="foundational",
            )
        ], ["empty_markdown"]

    lines, starts = _line_records(canonical)
    atoms: list[AtomDraft] = []
    findings: list[str] = []
    headings: list[str | None] = [None] * 6
    index = 0

    def line_end(position: int) -> int:
        return starts[position] + len(lines[position].rstrip("\n"))

    def is_block_start(position: int) -> bool:
        if position >= len(lines):
            return True
        body = _line_body(lines[position])
        if not body.strip():
            return True
        if ATX_HEADING_RE.match(body) or FENCE_RE.match(body) or LIST_RE.match(body):
            return True
        if FOOTNOTE_RE.match(body) or THEMATIC_BREAK_RE.match(body):
            return True
        if position + 1 < len(lines) and SETEXT_RE.match(_line_body(lines[position + 1])):
            return True
        if position + 1 < len(lines) and "|" in body and _is_table_separator(_line_body(lines[position + 1])):
            return True
        return False

    while index < len(lines):
        body = _line_body(lines[index])
        if not body.strip():
            index += 1
            continue

        fence = FENCE_RE.match(body)
        if fence:
            marker = fence.group(1)[0]
            minimum = len(fence.group(1))
            end = index + 1
            while end < len(lines):
                closing = _line_body(lines[end]).lstrip()
                if closing.startswith(marker * minimum):
                    end += 1
                    break
                end += 1
            else:
                findings.append("unclosed_code_fence")
            start_character = starts[index]
            end_character = line_end(end - 1)
            atoms.append(
                AtomDraft(
                    atom_type="decorative_or_navigation",
                    start_line=index + 1,
                    end_line=end,
                    start_character=start_character,
                    end_character=end_character,
                    heading_path=_heading_path_value(headings),
                    source_text=_span_text(canonical, start_character, end_character),
                    source_locale="und",
                    instructional_disposition="non_instructional",
                    non_instructional_reason="inert_code_fence",
                    risk_tier="foundational",
                )
            )
            index = end
            continue

        heading = ATX_HEADING_RE.match(body)
        if heading:
            level = len(heading.group(2))
            title = heading.group(3).strip()
            headings[level - 1] = title
            headings[level:] = [None] * (6 - level)
            atoms.append(
                _make_draft(
                    atom_type="heading",
                    text=body,
                    start_line=index + 1,
                    end_line=index + 1,
                    start_character=starts[index],
                    end_character=line_end(index),
                    heading_path=_heading_path_value(headings),
                    navigation_only=navigation_only,
                    risk_tier="foundational",
                )
            )
            index += 1
            continue

        if index + 1 < len(lines) and SETEXT_RE.match(_line_body(lines[index + 1])):
            underline = _line_body(lines[index + 1])
            level = 1 if underline.lstrip().startswith("=") else 2
            title = body.strip()
            headings[level - 1] = title
            headings[level:] = [None] * (6 - level)
            start_character = starts[index]
            end_character = line_end(index + 1)
            atoms.append(
                _make_draft(
                    atom_type="heading",
                    text=_span_text(canonical, start_character, end_character),
                    start_line=index + 1,
                    end_line=index + 2,
                    start_character=start_character,
                    end_character=end_character,
                    heading_path=_heading_path_value(headings),
                    navigation_only=navigation_only,
                    risk_tier="foundational",
                )
            )
            index += 2
            continue

        if index + 1 < len(lines) and "|" in body and _is_table_separator(_line_body(lines[index + 1])):
            table_start = index
            table_path = _heading_path_value(headings)
            header_cells = _table_cells(body)
            for column, (value, cell_start, cell_end) in enumerate(header_cells):
                atoms.append(
                    _make_draft(
                        atom_type="table_header",
                        text=value,
                        start_line=index + 1,
                        end_line=index + 1,
                        start_character=starts[index] + cell_start,
                        end_character=starts[index] + cell_end,
                        heading_path=table_path,
                        navigation_only=navigation_only,
                        table_row=0,
                        table_column=column,
                    )
                )
            separator_start = starts[index + 1]
            separator_end = line_end(index + 1)
            atoms.append(
                AtomDraft(
                    atom_type="decorative_or_navigation",
                    start_line=index + 2,
                    end_line=index + 2,
                    start_character=separator_start,
                    end_character=separator_end,
                    heading_path=table_path,
                    source_text=_span_text(canonical, separator_start, separator_end),
                    source_locale="und",
                    instructional_disposition="non_instructional",
                    non_instructional_reason="markdown_table_separator",
                    risk_tier="foundational",
                    table_row=0,
                )
            )
            index += 2
            row = 1
            while index < len(lines):
                row_body = _line_body(lines[index])
                if not row_body.strip() or "|" not in row_body:
                    break
                for column, (value, cell_start, cell_end) in enumerate(_table_cells(row_body)):
                    absolute_start = starts[index] + cell_start
                    atoms.append(
                        _make_draft(
                            atom_type="table_cell",
                            text=value,
                            start_line=index + 1,
                            end_line=index + 1,
                            start_character=absolute_start,
                            end_character=starts[index] + cell_end,
                            heading_path=table_path,
                            navigation_only=navigation_only,
                            table_row=row,
                            table_column=column,
                        )
                    )
                    if not navigation_only:
                        atoms.extend(
                            _subatoms_for_span(
                                value,
                                absolute_start,
                                index + 1,
                                index + 1,
                                table_path,
                            )
                        )
                index += 1
                row += 1
            if row == 1:
                findings.append("table_without_data_rows")
            if table_start == index:
                raise AssertionError("table parser failed to advance")
            continue

        footnote = FOOTNOTE_RE.match(body)
        if footnote:
            atoms.append(
                _make_draft(
                    atom_type="footnote",
                    text=body,
                    start_line=index + 1,
                    end_line=index + 1,
                    start_character=starts[index],
                    end_character=line_end(index),
                    heading_path=_heading_path_value(headings),
                    navigation_only=navigation_only,
                )
            )
            index += 1
            continue

        list_item = LIST_RE.match(body)
        if list_item:
            heading_path = _heading_path_value(headings)
            draft = _make_draft(
                atom_type="list_item",
                text=body,
                start_line=index + 1,
                end_line=index + 1,
                start_character=starts[index],
                end_character=line_end(index),
                heading_path=heading_path,
                navigation_only=navigation_only,
            )
            atoms.append(draft)
            if not navigation_only:
                atoms.extend(
                    _subatoms_for_span(
                        body,
                        starts[index],
                        index + 1,
                        index + 1,
                        heading_path,
                    )
                )
            index += 1
            continue

        if THEMATIC_BREAK_RE.match(body):
            start_character = starts[index]
            end_character = line_end(index)
            atoms.append(
                AtomDraft(
                    atom_type="decorative_or_navigation",
                    start_line=index + 1,
                    end_line=index + 1,
                    start_character=start_character,
                    end_character=end_character,
                    heading_path=_heading_path_value(headings),
                    source_text=_span_text(canonical, start_character, end_character),
                    source_locale="und",
                    instructional_disposition="non_instructional",
                    non_instructional_reason="thematic_break",
                    risk_tier="foundational",
                )
            )
            index += 1
            continue

        paragraph_start = index
        index += 1
        while index < len(lines) and not is_block_start(index):
            index += 1
        paragraph_end = index - 1
        start_character = starts[paragraph_start]
        end_character = line_end(paragraph_end)
        paragraph = _span_text(canonical, start_character, end_character)
        heading_path = _heading_path_value(headings)
        pure_media = not IMAGE_RE.sub("", paragraph).strip(" \t\n")
        if not pure_media:
            atom_type, risk_tier = _paragraph_atom_type(paragraph, heading_path)
            atoms.append(
                _make_draft(
                    atom_type=atom_type,
                    text=paragraph,
                    start_line=paragraph_start + 1,
                    end_line=paragraph_end + 1,
                    start_character=start_character,
                    end_character=end_character,
                    heading_path=heading_path,
                    navigation_only=navigation_only,
                    risk_tier=risk_tier,
                )
            )
        if not navigation_only:
            atoms.extend(
                _subatoms_for_span(
                    paragraph,
                    start_character,
                    paragraph_start + 1,
                    paragraph_end + 1,
                    heading_path,
                )
            )

    covered = bytearray(len(canonical))
    for atom in atoms:
        if atom.end_character > atom.start_character:
            covered[atom.start_character : atom.end_character] = b"\x01" * (
                atom.end_character - atom.start_character
            )
    structural_index = 0
    while structural_index < len(canonical):
        if covered[structural_index] or canonical[structural_index].isspace():
            structural_index += 1
            continue
        structural_start = structural_index
        while (
            structural_index < len(canonical)
            and not covered[structural_index]
            and not canonical[structural_index].isspace()
        ):
            structural_index += 1
        structural_end = structural_index
        structural_start_line = canonical.count("\n", 0, structural_start) + 1
        structural_end_line = canonical.count(
            "\n", 0, max(structural_start, structural_end - 1)
        ) + 1
        atoms.append(
            AtomDraft(
                atom_type="decorative_or_navigation",
                start_line=structural_start_line,
                end_line=structural_end_line,
                start_character=structural_start,
                end_character=structural_end,
                heading_path=[],
                source_text=canonical[structural_start:structural_end],
                source_locale="und",
                instructional_disposition="non_instructional",
                non_instructional_reason="markdown_structural_syntax",
                risk_tier="foundational",
            )
        )

    atoms.sort(
        key=lambda item: (
            item.start_character,
            item.end_character,
            item.atom_type,
            item.table_row if item.table_row is not None else -1,
            item.table_column if item.table_column is not None else -1,
        )
    )
    return atoms, sorted(set(findings))


def _atom_record(document_id: str, ordinal: int, draft: AtomDraft) -> dict[str, object]:
    source_hash = _sha256_text(draft.source_text)
    normalized_hash = _sha256_text(_normalized_atom_text(draft.source_text))
    identity = "|".join(
        (
            document_id,
            draft.atom_type,
            str(draft.start_character),
            str(draft.end_character),
            source_hash,
        )
    )
    atom_id = f"source.atom.{document_id.removeprefix('source.file.')}.{_sha256_text(identity)[:20]}"
    locator: dict[str, object] = {
        "startLine": draft.start_line,
        "endLine": draft.end_line,
        "startCharacter": draft.start_character,
        "endCharacter": draft.end_character,
        "headingPath": draft.heading_path,
    }
    if draft.table_row is not None:
        locator["tableRow"] = draft.table_row
    if draft.table_column is not None:
        locator["tableColumn"] = draft.table_column
    if draft.media_reference is not None:
        locator["mediaReference"] = draft.media_reference
    record: dict[str, object] = {
        "id": atom_id,
        "sourceDocumentId": document_id,
        "ordinal": ordinal,
        "atomType": draft.atom_type,
        "locator": locator,
        "sourceTextSha256": source_hash,
        "normalizedTextSha256": normalized_hash,
        "sourceLocale": draft.source_locale,
        "instructionalDisposition": draft.instructional_disposition,
        "riskTier": draft.risk_tier,
        "claimCandidateIds": [],
    }
    if draft.non_instructional_reason is not None:
        record["nonInstructionalReason"] = draft.non_instructional_reason
    if draft.duplicate_group_id is not None:
        record["duplicateGroupId"] = draft.duplicate_group_id
    return record


def _iter_files(part_path: Path) -> list[Path]:
    files: list[Path] = []
    for path in part_path.rglob("*"):
        if path.is_symlink():
            raise ScanError(f"symbolic links are not accepted inside the source boundary: {path}")
        if path.is_file():
            files.append(path)
    return sorted(files, key=lambda path: _normalized_path(path.relative_to(part_path)).casefold())


def _hierarchy_for_part(part_ordinal: int, part_path: Path, root: Path) -> list[dict[str, object]]:
    part_relative = _normalized_path(part_path.relative_to(root))
    course_key = f"{SOURCE_KEY}/course/{part_ordinal:02d}"
    hierarchy: list[dict[str, object]] = [
        {
            "sourceKey": course_key,
            "parentSourceKey": None,
            "kind": "course",
            "ordinal": part_ordinal,
            "relativePath": part_relative,
            "directoryName": unicodedata.normalize("NFC", part_path.name),
        }
    ]
    for chapter_ordinal, chapter_path in _unique_numbered_directories(
        part_path, CHAPTER_RE, "chapter"
    ):
        chapter_key = f"{course_key}/chapter/{chapter_ordinal:03d}"
        hierarchy.append(
            {
                "sourceKey": chapter_key,
                "parentSourceKey": course_key,
                "kind": "chapter",
                "ordinal": chapter_ordinal,
                "relativePath": _normalized_path(chapter_path.relative_to(root)),
                "directoryName": unicodedata.normalize("NFC", chapter_path.name),
            }
        )
        for lesson_ordinal, lesson_path in _unique_numbered_directories(
            chapter_path, LESSON_RE, "source lesson"
        ):
            hierarchy.append(
                {
                    "sourceKey": f"{chapter_key}/source-lesson/{lesson_ordinal:03d}",
                    "parentSourceKey": chapter_key,
                    "kind": "source_lesson",
                    "ordinal": lesson_ordinal,
                    "relativePath": _normalized_path(lesson_path.relative_to(root)),
                    "directoryName": unicodedata.normalize("NFC", lesson_path.name),
                }
            )
    return hierarchy


def _document_build(
    *,
    root: Path,
    path: Path,
    container: Container,
    scope_ordinal: int,
    course_file_ordinal: int,
    chapter_file_ordinal: int,
    lesson_file_ordinal: int | None,
) -> DocumentBuild:
    relative = _normalized_path(path.relative_to(root))
    raw = path.read_bytes()
    raw_hash = _sha256_bytes(raw)
    document_id = f"source.file.{_sha256_text(relative)[:24]}"
    extension = path.suffix.casefold()
    detected_mime, detected_format = _sniff_mime(raw, extension)
    role = _classify_role(path, container, detected_mime)
    if role not in ARTIFACT_ROLES:
        raise AssertionError(f"unregistered artifact role {role}")

    findings: set[str] = {"rights_confirmation_required"}
    expected_format = _expected_format(extension)
    if expected_format is not None and expected_format != detected_format:
        findings.add("claimed_extension_mime_mismatch")
    if len(relative) >= 240:
        findings.add("long_relative_path")
    if not raw:
        findings.add("empty_file")
    if extension in {".ts", ".tsx"}:
        findings.add("untrusted_typescript_candidate_not_executed")
        findings.add("legacy_sidecar_requires_semantic_review")
        if role == "derived_enrich_sidecar":
            findings.add("legacy_enrichment_excluded_from_current_authoring_protocol")
        if role == "contributor_metadata_sidecar":
            findings.add("contributor_metadata_non_instructional")
        if role == "other_reviewed_source":
            findings.add("unclassified_typescript_sidecar")

    decoded: str | None = None
    canonical_hash: str | None = None
    source_locale = "und"
    if detected_mime.startswith("text/") or role in {
        "part_index",
        "chapter_markdown",
        "lesson_markdown",
        "supplemental_markdown",
    }:
        try:
            decoded = raw.decode("utf-8-sig")
        except UnicodeDecodeError:
            findings.add("invalid_utf8")
        else:
            canonical = _canonical_text(decoded)
            canonical_hash = _sha256_text(canonical)
            source_locale = _source_locale(canonical)

    document: dict[str, object] = {
        "id": document_id,
        "courseSourceKey": container.course_key,
        "chapterSourceKey": container.chapter_key,
        "sourceLessonKey": container.lesson_key,
        "artifactRole": role,
        "authorityTier": _authority_tier(role, extension),
        "relativePath": relative,
        "byteLength": len(raw),
        "rawSha256": raw_hash,
        "canonicalSha256": canonical_hash,
        "claimedExtension": extension.removeprefix(".") or None,
        "detectedMime": detected_mime,
        "sourceLocale": source_locale,
        "parserVersion": PARSER_VERSION,
        "rightsState": "unknown",
        "ingestState": "discovered",
        "findingCodes": [],
    }
    order = {
        "sourceDocumentId": document_id,
        "scopeOrdinal": scope_ordinal,
        "courseOrdinal": container.part_ordinal,
        "chapterOrdinal": container.chapter_ordinal,
        "sourceLessonOrdinal": container.lesson_ordinal,
        "courseFileOrdinal": course_file_ordinal,
        "chapterFileOrdinal": chapter_file_ordinal,
        "sourceLessonFileOrdinal": lesson_file_ordinal,
    }
    build = DocumentBuild(document=document, order=order)

    if role in {
        "part_index",
        "chapter_markdown",
        "lesson_markdown",
        "supplemental_markdown",
    }:
        if decoded is None:
            document["ingestState"] = "quarantined"
        else:
            drafts, atom_findings = atomize_markdown(
                decoded,
                navigation_only=role == "part_index",
            )
            findings.update(atom_findings)
            for ordinal, draft in enumerate(drafts, start=1):
                build.atoms.append(_atom_record(document_id, ordinal, draft))
            document["ingestState"] = "atomized"
            atom_types = Counter(str(atom["atomType"]) for atom in build.atoms)
            dispositions = Counter(
                str(atom["instructionalDisposition"]) for atom in build.atoms
            )
            build.coverage = {
                "sourceDocumentId": document_id,
                "canonicalCharacterCount": len(_canonical_text(decoded)),
                "canonicalLineCount": len(_canonical_text(decoded).splitlines())
                or 1,
                "atomCount": len(build.atoms),
                "atomCountsByType": dict(sorted(atom_types.items())),
                "atomCountsByDisposition": dict(sorted(dispositions.items())),
                "allNonWhitespaceSourceRepresentedByDocumentAtoms": True,
            }
    elif extension in {".ts", ".tsx"}:
        if decoded is None:
            document["ingestState"] = "quarantined"
        else:
            canonical = _canonical_text(decoded)
            try:
                static_atoms, static_findings = atomize_typescript_sidecar(
                    canonical,
                    artifact_role=role,
                )
            except TypescriptStaticParseError as error:
                findings.add("typescript_static_parse_failed")
                findings.add(
                    "typescript_static_parse_failure."
                    + _sha256_text(str(error))[:16]
                )
                document["ingestState"] = "quarantined"
            else:
                findings.update(static_findings)
                _, line_starts = _line_records(canonical)
                drafts: list[AtomDraft] = []
                for static_atom in static_atoms:
                    start = static_atom.start_character
                    end = static_atom.end_character
                    source_text = canonical[start:end]
                    start_line = bisect.bisect_right(line_starts, start)
                    final_character = max(start, end - 1)
                    end_line = bisect.bisect_right(line_starts, final_character)
                    atom_type = static_atom.atom_type
                    risk_tier = static_atom.risk_tier
                    heading_path = ["typescript", *static_atom.field_path]
                    if atom_type == "claim":
                        atom_type, risk_tier = _paragraph_atom_type(
                            source_text,
                            heading_path,
                        )
                    draft = AtomDraft(
                        atom_type=atom_type,
                        start_line=start_line,
                        end_line=end_line,
                        start_character=start,
                        end_character=end,
                        heading_path=heading_path,
                        source_text=source_text,
                        source_locale=_source_locale(source_text),
                        instructional_disposition=(
                            static_atom.instructional_disposition
                        ),
                        non_instructional_reason=(
                            static_atom.non_instructional_reason
                        ),
                        risk_tier=risk_tier,
                    )
                    drafts.append(draft)
                    if (
                        draft.instructional_disposition == "required"
                        and draft.atom_type
                        in {
                            "claim",
                            "paragraph_context",
                            "warning",
                            "clinical_pearl",
                            "quiz_stem_candidate",
                            "quiz_option_candidate",
                            "quiz_explanation_candidate",
                            "table_cell",
                            "table_header",
                        }
                    ):
                        drafts.extend(
                            _subatoms_for_span(
                                source_text,
                                start,
                                start_line,
                                end_line,
                                heading_path,
                            )
                        )
                drafts.sort(
                    key=lambda item: (
                        item.start_character,
                        item.end_character,
                        item.atom_type,
                        item.table_row if item.table_row is not None else -1,
                        item.table_column if item.table_column is not None else -1,
                    )
                )
                for ordinal, draft in enumerate(drafts, start=1):
                    build.atoms.append(_atom_record(document_id, ordinal, draft))
                document["ingestState"] = "atomized"
                atom_types = Counter(str(atom["atomType"]) for atom in build.atoms)
                dispositions = Counter(
                    str(atom["instructionalDisposition"]) for atom in build.atoms
                )
                build.coverage = {
                    "sourceDocumentId": document_id,
                    "canonicalCharacterCount": len(canonical),
                    "canonicalLineCount": len(canonical.splitlines()) or 1,
                    "atomCount": len(build.atoms),
                    "atomCountsByType": dict(sorted(atom_types.items())),
                    "atomCountsByDisposition": dict(sorted(dispositions.items())),
                    "allNonWhitespaceSourceRepresentedByDocumentAtoms": True,
                }
    elif role == "media":
        build.media = {
            "sourceDocumentId": document_id,
            "declaredExtension": extension.removeprefix(".") or None,
            "detectedFormat": detected_format,
            "magicMatchesExtension": expected_format == detected_format,
        }
    document["findingCodes"] = sorted(findings)
    return build


def _mark_duplicate_documents(builds: list[DocumentBuild]) -> None:
    groups: dict[str, list[DocumentBuild]] = defaultdict(list)
    for build in builds:
        groups[str(build.document["rawSha256"])].append(build)
    for raw_hash, matches in groups.items():
        if len(matches) < 2:
            continue
        group_id = f"duplicate.document.{raw_hash[:24]}"
        for build in matches:
            findings = set(str(item) for item in build.document["findingCodes"])
            findings.add("duplicate_raw_document")
            findings.add(group_id)
            build.document["findingCodes"] = sorted(findings)


def _mark_duplicate_atoms(atoms: list[dict[str, object]]) -> None:
    groups: dict[str, list[dict[str, object]]] = defaultdict(list)
    for atom in atoms:
        groups[str(atom["normalizedTextSha256"])].append(atom)
    for normalized_hash, matches in groups.items():
        if len(matches) < 2:
            continue
        group_id = f"duplicate.atom.{normalized_hash[:24]}"
        for index, atom in enumerate(matches):
            atom["duplicateGroupId"] = group_id
            if index > 0 and atom["instructionalDisposition"] == "required":
                atom["instructionalDisposition"] = "duplicate_required"


def _coverage_bootstrap(atom: dict[str, object]) -> dict[str, object]:
    disposition = str(atom["instructionalDisposition"])
    if disposition == "non_instructional":
        state = "non_instructional_accounted"
        role = "non_instructional_accounting"
        bilingual = False
        verify = False
    elif disposition == "duplicate_required":
        state = "duplicate_pending_reconciliation"
        role = "duplicate_reconciliation"
        bilingual = True
        verify = atom["atomType"] not in {"heading", "paragraph_context"}
    else:
        state = "planned"
        role = {
            "quiz_stem_candidate": "assessment",
            "quiz_option_candidate": "assessment",
            "quiz_explanation_candidate": "assessment",
            "figure_reference": "media_interpretation",
            "figure_caption": "media_interpretation",
            "formula": "mechanism_explanation",
        }.get(str(atom["atomType"]), "primary_instruction")
        bilingual = True
        verify = atom["atomType"] not in {
            "heading",
            "paragraph_context",
            "decorative_or_navigation",
        }
    return {
        "id": f"coverage.bootstrap.{str(atom['id']).removeprefix('source.atom.')}",
        "sourceAtomId": atom["id"],
        "state": state,
        "suggestedCoverageRole": role,
        "requiresBilingualAuthoring": bilingual,
        "claimVerificationRequired": verify,
    }


def _contract_compatibility_errors(
    manifest: dict[str, object], contract: dict[str, object]
) -> list[str]:
    errors: list[str] = []
    definitions = contract.get("$defs", {})
    if not isinstance(definitions, dict):
        return ["content contract has no $defs object"]
    for collection_name, definition_name in (
        ("sourceDocuments", "sourceDocument"),
        ("sourceAtoms", "sourceAtom"),
    ):
        definition = definitions.get(definition_name, {})
        if not isinstance(definition, dict):
            errors.append(f"content contract is missing {definition_name}")
            continue
        required = set(definition.get("required", []))
        allowed = set(definition.get("properties", {}))
        collection = manifest.get(collection_name, [])
        if not isinstance(collection, list):
            errors.append(f"{collection_name} must be an array")
            continue
        for index, item in enumerate(collection):
            if not isinstance(item, dict):
                errors.append(f"{collection_name}[{index}] is not an object")
                continue
            missing = sorted(required - set(item))
            extra = sorted(set(item) - allowed)
            if missing:
                errors.append(
                    f"{collection_name}[{index}] missing contract fields: {', '.join(missing)}"
                )
            if extra:
                errors.append(
                    f"{collection_name}[{index}] has non-contract fields: {', '.join(extra)}"
                )
    document_roles = set(
        definitions.get("sourceDocument", {})
        .get("properties", {})
        .get("artifactRole", {})
        .get("enum", [])
    )
    atom_types = set(
        definitions.get("sourceAtom", {})
        .get("properties", {})
        .get("atomType", {})
        .get("enum", [])
    )
    for document in manifest.get("sourceDocuments", []):
        if document.get("artifactRole") not in document_roles:
            errors.append(f"unsupported artifactRole {document.get('artifactRole')!r}")
    for atom in manifest.get("sourceAtoms", []):
        if atom.get("atomType") not in atom_types:
            errors.append(f"unsupported atomType {atom.get('atomType')!r}")
    return errors


def scan_source(
    source_root: Path,
    *,
    courses: Sequence[str] = (),
    content_contract: Path | None = None,
) -> dict[str, object]:
    root = _long_path_aware(source_root)
    if not root.is_dir():
        raise ScanError(f"source root is not a directory: {source_root}")

    selected = _course_values(courses)
    parts = _unique_numbered_directories(root, PART_RE, "Part")
    if selected:
        by_ordinal = {ordinal: path for ordinal, path in parts}
        missing = [value for value in selected if value not in by_ordinal]
        if missing:
            raise ScanError(
                "requested course Part directories were not found: "
                + ", ".join(f"{value:02d}" for value in missing)
            )
        parts = [(value, by_ordinal[value]) for value in selected]
    else:
        outside = [
            path
            for path in root.rglob("*")
            if path.is_file()
            and not any(
                path == part_path or part_path in path.parents for _, part_path in parts
            )
        ]
        if outside:
            relative = ", ".join(
                _normalized_path(path.relative_to(root)) for path in outside[:5]
            )
            raise ScanError(
                "full-corpus scan found files outside numbered Part directories; "
                f"refusing to omit them: {relative}"
            )

    hierarchy: list[dict[str, object]] = []
    builds: list[DocumentBuild] = []
    scope_ordinal = 0
    for part_ordinal, part_path in parts:
        hierarchy.extend(_hierarchy_for_part(part_ordinal, part_path, root))
        files = _iter_files(part_path)
        chapter_counts: Counter[int | None] = Counter()
        lesson_counts: Counter[tuple[int | None, int | None]] = Counter()
        for course_file_ordinal, path in enumerate(files, start=1):
            scope_ordinal += 1
            container = _container_for_file(part_ordinal, part_path, path)
            chapter_counts[container.chapter_ordinal] += 1
            lesson_key = (container.chapter_ordinal, container.lesson_ordinal)
            lesson_counts[lesson_key] += 1
            build = _document_build(
                root=root,
                path=path,
                container=container,
                scope_ordinal=scope_ordinal,
                course_file_ordinal=course_file_ordinal,
                chapter_file_ordinal=chapter_counts[container.chapter_ordinal],
                lesson_file_ordinal=(
                    lesson_counts[lesson_key]
                    if container.lesson_ordinal is not None
                    else None
                ),
            )
            if container.chapter_ordinal is None and build.document["artifactRole"] != "part_index":
                findings = set(str(item) for item in build.document["findingCodes"])
                findings.add("outside_chapter_container")
                build.document["findingCodes"] = sorted(findings)
            builds.append(build)

    _mark_duplicate_documents(builds)
    atoms = [atom for build in builds for atom in build.atoms]
    _mark_duplicate_atoms(atoms)

    # Refresh per-document disposition counts after cross-document deduplication.
    atoms_by_document: dict[str, list[dict[str, object]]] = defaultdict(list)
    for atom in atoms:
        atoms_by_document[str(atom["sourceDocumentId"])].append(atom)
    for build in builds:
        if not build.coverage:
            continue
        dispositions = Counter(
            str(atom["instructionalDisposition"])
            for atom in atoms_by_document[str(build.document["id"])]
        )
        build.coverage["atomCountsByDisposition"] = dict(sorted(dispositions.items()))

    source_documents = [build.document for build in builds]
    document_order = [build.order for build in builds]
    document_coverage = [build.coverage for build in builds if build.coverage]
    media_records = [build.media for build in builds if build.media is not None]
    coverage_bootstrap = [_coverage_bootstrap(atom) for atom in atoms]
    tree_material = "".join(
        f"{document['relativePath']}\0{document['rawSha256']}\0{document['byteLength']}\n"
        for document in source_documents
    )
    scope_label = (
        "full"
        if not selected
        else "course-" + "-".join(f"{value:02d}" for value in selected)
    )
    role_counts = Counter(str(item["artifactRole"]) for item in source_documents)
    mime_counts = Counter(str(item["detectedMime"]) for item in source_documents)
    locale_counts = Counter(str(item["sourceLocale"]) for item in source_documents)
    atom_type_counts = Counter(str(item["atomType"]) for item in atoms)
    disposition_counts = Counter(str(item["instructionalDisposition"]) for item in atoms)
    duplicate_document_count = sum(
        "duplicate_raw_document" in item["findingCodes"] for item in source_documents
    )
    duplicate_atom_count = sum(
        item["instructionalDisposition"] == "duplicate_required" for item in atoms
    )

    manifest: dict[str, object] = {
        "$schema": SCHEMA_URI,
        "schemaVersion": 1,
        "contractId": CONTRACT_ID,
        "manifestId": f"scan.{SOURCE_KEY}.{scope_label}.v1",
        "scope": {
            "sourceKey": SOURCE_KEY,
            "classification": SOURCE_CLASSIFICATION,
            "courseFilters": [f"{value:02d}" for value in selected],
            "localRootDistributable": False,
        },
        "parser": {
            "name": PARSER_NAME,
            "version": PARSER_VERSION,
            "typescriptPolicy": (
                "strict-static-literal-and-structure-atomization; "
                "inert-untrusted-bytes-never-executed"
            ),
            "locatorCharacterSemantics": "zero-based Unicode code-point offsets into NFC UTF-8-decoded LF-normalized source text; endCharacter is exclusive",
            "locatorLineSemantics": "one-based inclusive lines",
        },
        "sourceTreeSha256": _sha256_text(tree_material),
        "hierarchyNodes": hierarchy,
        "documentOrder": document_order,
        "sourceDocuments": source_documents,
        "sourceAtoms": atoms,
        "documentCoverage": document_coverage,
        "coverageBootstrap": coverage_bootstrap,
        "mediaRecords": media_records,
        "summary": {
            "courseCount": sum(1 for item in hierarchy if item["kind"] == "course"),
            "chapterCount": sum(1 for item in hierarchy if item["kind"] == "chapter"),
            "explicitSourceLessonCount": sum(
                1 for item in hierarchy if item["kind"] == "source_lesson"
            ),
            "fileCount": len(source_documents),
            "totalBytes": sum(int(item["byteLength"]) for item in source_documents),
            "documentCountsByRole": dict(sorted(role_counts.items())),
            "documentCountsByMime": dict(sorted(mime_counts.items())),
            "documentCountsByLocale": dict(sorted(locale_counts.items())),
            "atomCount": len(atoms),
            "atomCountsByType": dict(sorted(atom_type_counts.items())),
            "atomCountsByDisposition": dict(sorted(disposition_counts.items())),
            "duplicateDocumentCount": duplicate_document_count,
            "duplicateAtomCount": duplicate_atom_count,
            "untrustedTypescriptDocumentCount": sum(
                str(item["claimedExtension"]) in {"ts", "tsx"}
                for item in source_documents
            ),
            "mimeMismatchCount": sum(
                "claimed_extension_mime_mismatch" in item["findingCodes"]
                for item in source_documents
            ),
            "quarantinedDocumentCount": sum(
                item["ingestState"] == "quarantined" for item in source_documents
            ),
        },
    }

    if content_contract is not None:
        try:
            contract = json.loads(content_contract.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise ScanError(f"cannot load content contract {content_contract}: {error}") from error
        compatibility_errors = _contract_compatibility_errors(manifest, contract)
        if compatibility_errors:
            raise ScanError(
                "source scan is not compatible with the content contract: "
                + "; ".join(compatibility_errors[:10])
            )
    return manifest


def manifest_bytes(manifest: dict[str, object]) -> bytes:
    return (
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    ).encode("utf-8")


def write_manifest(path: Path, payload: bytes) -> None:
    path = _long_path_aware(path, strict=False)
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, path)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Deterministically inventory and atomize a Harrison-like source corpus."
    )
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument(
        "--course",
        action="append",
        default=[],
        help="Numeric Part ordinal (for example 06). Repeat for multiple courses; omit for full corpus.",
    )
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument("--output", type=Path)
    destination.add_argument(
        "--check",
        type=Path,
        help="Regenerate in memory and require byte-for-byte equality with this manifest.",
    )
    parser.add_argument(
        "--content-contract",
        type=Path,
        default=Path(__file__).resolve().parents[2]
        / "contracts/curriculum/content-contract.v1.json",
    )
    parser.add_argument("--json-summary", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(list(argv if argv is not None else sys.argv[1:]))
    if args.output is not None:
        try:
            source_boundary = args.source_root.resolve(strict=True)
            output_path = args.output.resolve(strict=False)
        except OSError as error:
            print(f"Source scan FAIL: cannot resolve source/output boundary: {error}", file=sys.stderr)
            return 1
        if _is_within(output_path, source_boundary):
            print(
                "Source scan FAIL: --output must stay outside the read-only source root",
                file=sys.stderr,
            )
            return 1
    try:
        manifest = scan_source(
            args.source_root,
            courses=args.course,
            content_contract=args.content_contract,
        )
        payload = manifest_bytes(manifest)
    except (OSError, ScanError) as error:
        print(f"Source scan FAIL: {error}", file=sys.stderr)
        return 1

    payload_hash = _sha256_bytes(payload)
    if args.check is not None:
        try:
            existing = args.check.read_bytes()
        except OSError as error:
            print(f"Source scan CHECK FAIL: cannot read {args.check}: {error}", file=sys.stderr)
            return 1
        if existing != payload:
            print(
                "Source scan CHECK FAIL: manifest drift "
                f"(expected {_sha256_bytes(existing)}, generated {payload_hash})",
                file=sys.stderr,
            )
            return 1
    else:
        write_manifest(args.output, payload)

    summary = dict(manifest["summary"])
    summary.update(
        {
            "status": "pass",
            "manifestSha256": payload_hash,
            "sourceTreeSha256": manifest["sourceTreeSha256"],
            "scope": manifest["scope"],
        }
    )
    if args.json_summary:
        print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print(
            "Source scan PASS: "
            f"{summary['fileCount']} files, {summary['atomCount']} atoms, "
            f"{summary['chapterCount']} chapters, "
            f"manifest {payload_hash}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
