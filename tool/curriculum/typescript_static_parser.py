"""Strict, non-executing extraction for legacy TypeScript content sidecars.

The parser is intentionally not a JavaScript runtime. It tokenizes static
source text, follows object/array literal structure only far enough to attach
field paths to literal values, and accounts for every remaining non-whitespace
source span as structural syntax. It never imports, evaluates, transpiles, or
invokes the input.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable


class TypescriptStaticParseError(RuntimeError):
    """Raised when deterministic lexical accounting cannot be guaranteed."""


@dataclass(frozen=True)
class Token:
    kind: str
    value: str
    start: int
    end: int


@dataclass(frozen=True)
class StaticAtom:
    atom_type: str
    start_character: int
    end_character: int
    field_path: tuple[str, ...]
    instructional_disposition: str = "required"
    non_instructional_reason: str | None = None
    risk_tier: str = "clinical_high"


def _identifier_start(character: str) -> bool:
    return character == "_" or character == "$" or character.isalpha()


def _identifier_part(character: str) -> bool:
    return _identifier_start(character) or character.isdigit()


def _quoted_value(raw: str) -> str:
    if len(raw) < 2:
        return raw
    quote = raw[0]
    if quote not in {"'", '"'} or raw[-1] != quote:
        return raw
    body = raw[1:-1]
    result: list[str] = []
    index = 0
    while index < len(body):
        character = body[index]
        if character != "\\" or index + 1 >= len(body):
            result.append(character)
            index += 1
            continue
        escaped = body[index + 1]
        simple = {
            "n": "\n",
            "r": "\r",
            "t": "\t",
            "b": "\b",
            "f": "\f",
            "v": "\v",
            "0": "\0",
            "\\": "\\",
            "'": "'",
            '"': '"',
        }
        if escaped in simple:
            result.append(simple[escaped])
            index += 2
            continue
        if escaped == "u" and index + 5 < len(body):
            value = body[index + 2 : index + 6]
            try:
                result.append(chr(int(value, 16)))
            except ValueError:
                result.append(body[index : index + 6])
            index += 6
            continue
        result.append(escaped)
        index += 2
    return "".join(result)


def tokenize_typescript(source: str) -> list[Token]:
    tokens: list[Token] = []
    index = 0
    length = len(source)
    while index < length:
        character = source[index]
        if character.isspace():
            index += 1
            continue
        if source.startswith("//", index):
            start = index
            newline = source.find("\n", index + 2)
            index = length if newline < 0 else newline
            tokens.append(Token("COMMENT", source[start:index], start, index))
            continue
        if source.startswith("/*", index):
            start = index
            closing = source.find("*/", index + 2)
            if closing < 0:
                raise TypescriptStaticParseError(
                    f"unterminated block comment at character {start}"
                )
            index = closing + 2
            tokens.append(Token("COMMENT", source[start:index], start, index))
            continue
        if character in {"'", '"', "`"}:
            quote = character
            start = index
            index += 1
            escaped = False
            while index < length:
                current = source[index]
                if escaped:
                    escaped = False
                    index += 1
                    continue
                if current == "\\":
                    escaped = True
                    index += 1
                    continue
                if current == quote:
                    index += 1
                    break
                if quote != "`" and current in {"\n", "\r"}:
                    raise TypescriptStaticParseError(
                        f"unterminated quoted string at character {start}"
                    )
                index += 1
            else:
                raise TypescriptStaticParseError(
                    f"unterminated string or template at character {start}"
                )
            raw = source[start:index]
            value = raw[1:-1] if quote == "`" else _quoted_value(raw)
            tokens.append(Token("STRING", value, start, index))
            continue
        if _identifier_start(character):
            start = index
            index += 1
            while index < length and _identifier_part(source[index]):
                index += 1
            tokens.append(Token("IDENT", source[start:index], start, index))
            continue
        if character.isdigit():
            start = index
            index += 1
            while index < length and (
                source[index].isalnum() or source[index] in {".", "_"}
            ):
                index += 1
            tokens.append(Token("NUMBER", source[start:index], start, index))
            continue
        if source.startswith("=>", index):
            tokens.append(Token("PUNCT", "=>", index, index + 2))
            index += 2
            continue
        if source.startswith("...", index):
            tokens.append(Token("PUNCT", "...", index, index + 3))
            index += 3
            continue
        tokens.append(Token("PUNCT", character, index, index + 1))
        index += 1
    return tokens


def _nearest_named_field(path: tuple[str, ...]) -> str:
    for item in reversed(path):
        if not item.isdigit():
            return item.casefold()
    return ""


def _classify_literal(
    *, token: Token, path: tuple[str, ...], artifact_role: str
) -> StaticAtom:
    fields = {item.casefold() for item in path if not item.isdigit()}
    leaf = _nearest_named_field(path)
    raw_lower = token.value.casefold()

    if artifact_role == "contributor_metadata_sidecar" or fields.intersection(
        {"authors", "professors", "contributors"}
    ):
        return StaticAtom(
            atom_type="contributor_metadata",
            start_character=token.start,
            end_character=token.end,
            field_path=path,
            instructional_disposition="non_instructional",
            non_instructional_reason="typescript_contributor_metadata",
            risk_tier="foundational",
        )
    if leaf in {
        "id",
        "difficulty",
        "module_specifier",
        "import",
        "source",
    }:
        return StaticAtom(
            atom_type="decorative_or_navigation",
            start_character=token.start,
            end_character=token.end,
            field_path=path,
            instructional_disposition="non_instructional",
            non_instructional_reason="typescript_identifier_or_module_metadata",
            risk_tier="foundational",
        )
    if leaf in {"title", "subtitle", "lessontitle", "sectiontitle"}:
        return StaticAtom(
            atom_type="heading",
            start_character=token.start,
            end_character=token.end,
            field_path=path,
            risk_tier="foundational",
        )
    if leaf == "question" or "questions" in fields:
        return StaticAtom(
            atom_type="quiz_stem_candidate",
            start_character=token.start,
            end_character=token.end,
            field_path=path,
        )
    if "options" in fields:
        return StaticAtom(
            atom_type="quiz_option_candidate",
            start_character=token.start,
            end_character=token.end,
            field_path=path,
        )
    if leaf in {"answer", "explanation"}:
        return StaticAtom(
            atom_type="quiz_explanation_candidate",
            start_character=token.start,
            end_character=token.end,
            field_path=path,
        )
    if "headers" in fields:
        return StaticAtom(
            atom_type="table_header",
            start_character=token.start,
            end_character=token.end,
            field_path=path,
        )
    if "rows" in fields:
        return StaticAtom(
            atom_type="table_cell",
            start_character=token.start,
            end_character=token.end,
            field_path=path,
        )
    if leaf in {"imagefilename", "image", "media", "src", "url"} or (
        ("/content/" in raw_lower or "images_" in raw_lower)
        and any(extension in raw_lower for extension in (".png", ".jpg", ".jpeg", ".svg", ".webp"))
    ):
        return StaticAtom(
            atom_type="media_label",
            start_character=token.start,
            end_character=token.end,
            field_path=path,
        )
    if leaf == "content" or fields.intersection(
        {"blocks", "flashcards", "sections", "tabledata"}
    ):
        return StaticAtom(
            atom_type="claim",
            start_character=token.start,
            end_character=token.end,
            field_path=path,
        )
    return StaticAtom(
        atom_type="paragraph_context",
        start_character=token.start,
        end_character=token.end,
        field_path=path,
    )


def _classify_number(token: Token, path: tuple[str, ...]) -> StaticAtom:
    leaf = _nearest_named_field(path)
    if leaf in {"correctanswer", "answerindex"}:
        return StaticAtom(
            atom_type="quiz_explanation_candidate",
            start_character=token.start,
            end_character=token.end,
            field_path=path,
        )
    if leaf in {"id", "ordinal", "index", "difficulty"}:
        return StaticAtom(
            atom_type="decorative_or_navigation",
            start_character=token.start,
            end_character=token.end,
            field_path=path,
            instructional_disposition="non_instructional",
            non_instructional_reason="typescript_numeric_metadata",
            risk_tier="foundational",
        )
    return StaticAtom(
        atom_type="numeric_threshold",
        start_character=token.start,
        end_character=token.end,
        field_path=path,
    )


class _LiteralWalker:
    def __init__(self, tokens: list[Token], artifact_role: str) -> None:
        self.tokens = tokens
        self.artifact_role = artifact_role
        self.consumed_literals: set[int] = set()
        self.atoms: list[StaticAtom] = []

    def _record(self, index: int, path: tuple[str, ...]) -> None:
        if index in self.consumed_literals:
            return
        token = self.tokens[index]
        if token.kind == "STRING":
            self.atoms.append(
                _classify_literal(token=token, path=path, artifact_role=self.artifact_role)
            )
        elif token.kind == "NUMBER":
            self.atoms.append(_classify_number(token, path))
        else:
            return
        self.consumed_literals.add(index)

    def _parse_group(
        self, index: int, path: tuple[str, ...], closing: str
    ) -> int:
        index += 1
        while index < len(self.tokens):
            token = self.tokens[index]
            if token.value == closing:
                return index + 1
            if token.value == "{":
                index = self._parse_object(index, path)
            elif token.value == "[":
                index = self._parse_array(index, path)
            elif token.value == "(":
                index = self._parse_group(index, path, ")")
            else:
                self._record(index, path)
                index += 1
        raise TypescriptStaticParseError(f"missing closing token {closing!r}")

    def _parse_expression(
        self, index: int, path: tuple[str, ...], stops: set[str]
    ) -> int:
        while index < len(self.tokens):
            token = self.tokens[index]
            if token.value in stops:
                return index
            if token.value == "{":
                index = self._parse_object(index, path)
            elif token.value == "[":
                index = self._parse_array(index, path)
            elif token.value == "(":
                index = self._parse_group(index, path, ")")
            else:
                self._record(index, path)
                index += 1
        return index

    def _parse_value(
        self, index: int, path: tuple[str, ...], stops: set[str]
    ) -> int:
        if index >= len(self.tokens):
            return index
        token = self.tokens[index]
        if token.value == "{":
            return self._parse_object(index, path)
        if token.value == "[":
            return self._parse_array(index, path)
        return self._parse_expression(index, path, stops)

    def _parse_object(self, index: int, path: tuple[str, ...]) -> int:
        index += 1
        while index < len(self.tokens):
            token = self.tokens[index]
            if token.value == "}":
                return index + 1
            if token.value == ",":
                index += 1
                continue
            if token.kind in {"IDENT", "STRING", "NUMBER"}:
                if index + 1 < len(self.tokens) and self.tokens[index + 1].value == ":":
                    key = token.value
                    index = self._parse_value(
                        index + 2,
                        (*path, key),
                        {",", "}"},
                    )
                    continue
            index = self._parse_expression(index, path, {",", "}"})
        raise TypescriptStaticParseError("missing closing object brace")

    def _parse_array(self, index: int, path: tuple[str, ...]) -> int:
        index += 1
        item_index = 0
        while index < len(self.tokens):
            token = self.tokens[index]
            if token.value == "]":
                return index + 1
            if token.value == ",":
                item_index += 1
                index += 1
                continue
            index = self._parse_value(
                index,
                (*path, str(item_index)),
                {",", "]"},
            )
        raise TypescriptStaticParseError("missing closing array bracket")

    def walk(self) -> list[StaticAtom]:
        index = 0
        while index < len(self.tokens):
            token = self.tokens[index]
            if token.kind == "IDENT" and token.value == "const":
                name_index = index + 1
                if name_index < len(self.tokens) and self.tokens[name_index].kind == "IDENT":
                    name = self.tokens[name_index].value
                    equals = name_index + 1
                    while equals < len(self.tokens) and self.tokens[equals].value not in {
                        "=",
                        ";",
                    }:
                        equals += 1
                    if equals < len(self.tokens) and self.tokens[equals].value == "=":
                        index = self._parse_value(
                            equals + 1,
                            (name,),
                            {";"},
                        )
                        continue
            index += 1

        for token_index, token in enumerate(self.tokens):
            if token.kind not in {"STRING", "NUMBER"}:
                continue
            if token_index in self.consumed_literals:
                continue
            if token.kind == "STRING":
                prior_values = {
                    item.value
                    for item in self.tokens[max(0, token_index - 3) : token_index]
                    if item.kind == "IDENT"
                }
                path = (
                    ("module_specifier",)
                    if prior_values.intersection({"from", "import", "require"})
                    else ("unscoped_static_literal",)
                )
            else:
                path = ("unscoped_numeric_literal",)
            self._record(token_index, path)
        return self.atoms


def _trimmed_non_whitespace_span(source: str, start: int, end: int) -> tuple[int, int] | None:
    while start < end and source[start].isspace():
        start += 1
    while end > start and source[end - 1].isspace():
        end -= 1
    if start == end:
        return None
    return start, end


def _structural_atoms(source: str, covered: Iterable[tuple[int, int]]) -> list[StaticAtom]:
    result: list[StaticAtom] = []
    cursor = 0
    for start, end in sorted(set(covered)):
        if start < cursor:
            raise TypescriptStaticParseError("overlapping static literal spans")
        gap = _trimmed_non_whitespace_span(source, cursor, start)
        if gap is not None:
            result.append(
                StaticAtom(
                    atom_type="decorative_or_navigation",
                    start_character=gap[0],
                    end_character=gap[1],
                    field_path=("typescript_structural_syntax",),
                    instructional_disposition="non_instructional",
                    non_instructional_reason="typescript_structural_syntax",
                    risk_tier="foundational",
                )
            )
        cursor = end
    gap = _trimmed_non_whitespace_span(source, cursor, len(source))
    if gap is not None:
        result.append(
            StaticAtom(
                atom_type="decorative_or_navigation",
                start_character=gap[0],
                end_character=gap[1],
                field_path=("typescript_structural_syntax",),
                instructional_disposition="non_instructional",
                non_instructional_reason="typescript_structural_syntax",
                risk_tier="foundational",
            )
        )
    return result


def atomize_typescript_sidecar(
    source: str, *, artifact_role: str
) -> tuple[list[StaticAtom], list[str]]:
    tokens = tokenize_typescript(source)
    comments = [token for token in tokens if token.kind == "COMMENT"]
    significant = [token for token in tokens if token.kind != "COMMENT"]
    walker = _LiteralWalker(significant, artifact_role)
    atoms = walker.walk()
    for comment in comments:
        atoms.append(
            StaticAtom(
                atom_type="paragraph_context",
                start_character=comment.start,
                end_character=comment.end,
                field_path=("typescript_comment",),
            )
        )

    covered = [(atom.start_character, atom.end_character) for atom in atoms]
    atoms.extend(_structural_atoms(source, covered))
    atoms.sort(
        key=lambda item: (
            item.start_character,
            item.end_character,
            item.atom_type,
            item.field_path,
        )
    )

    findings = [
        "typescript_static_literals_atomized",
        "typescript_structural_syntax_accounted",
    ]
    template_tokens = [
        token
        for token in significant
        if token.kind == "STRING" and source[token.start : token.start + 1] == "`"
    ]
    templates_with_references = [
        token
        for token in template_tokens
        if "${" in source[token.start : token.end]
    ]
    if templates_with_references:
        static_bindings = {
            significant[index + 1].value
            for index in range(len(significant) - 3)
            if significant[index].kind == "IDENT"
            and significant[index].value == "const"
            and significant[index + 1].kind == "IDENT"
            and significant[index + 2].value == "="
            and significant[index + 3].kind == "STRING"
            and source[significant[index + 3].start : significant[index + 3].start + 1]
            in {"'", '"'}
        }
        all_references_are_static = True
        for token in templates_with_references:
            raw_template = source[token.start + 1 : token.end - 1]
            references = re.findall(r"\$\{([^{}]+)\}", raw_template)
            if not references or any(
                re.fullmatch(r"[A-Za-z_$][A-Za-z0-9_$]*", reference.strip())
                is None
                or reference.strip() not in static_bindings
                for reference in references
            ):
                all_references_are_static = False
                break
        findings.append(
            "typescript_static_template_reference_atomized"
            if all_references_are_static
            else "typescript_template_interpolation_requires_semantic_review"
        )
    if any(
        token.value == "=>"
        or (token.kind == "IDENT" and token.value == "function")
        for token in significant
    ):
        findings.append("typescript_dynamic_expression_requires_semantic_review")
    if not any(atom.instructional_disposition == "required" for atom in atoms):
        findings.append("typescript_no_instructional_static_literals")
    return atoms, sorted(findings)
