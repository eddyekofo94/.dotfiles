#!/usr/bin/env python3
"""Extract searchable URI, path, and hash references from pane readback."""

from __future__ import annotations

import re
import sys
import unicodedata


URI = re.compile(
    r"(?:https?://|git@|git://|ssh://|ftp://|file:///)"
    r"""[^\s<>"'`]+""",
    re.IGNORECASE,
)
PATH = re.compile(r"""[^\s<>"'`]*?(?:/|\.)[^\s<>"'`]+""")
HASH = re.compile(r"(?<![0-9A-Fa-f])#?[0-9A-Fa-f]{6,}(?![0-9A-Fa-f])")
LEADING = "([{<"
TRAILING = ")]}>.,;:!?"


def clean(value: str) -> str:
    printable = "".join(
        character
        for character in value
        if not unicodedata.category(character).startswith("C")
    )
    return printable.lstrip(LEADING).rstrip(TRAILING)


def overlaps(span: tuple[int, int], claimed: list[tuple[int, int]]) -> bool:
    return any(span[0] < end and start < span[1] for start, end in claimed)


def main() -> int:
    found: list[tuple[str, str, int, str]] = []
    for line_number, raw_line in enumerate(sys.stdin.read().splitlines(), 1):
        visible_line = "".join(
            character
            for character in raw_line
            if not unicodedata.category(character).startswith("C")
        )
        context = re.sub(r"\s+", " ", visible_line).strip()[:160]
        claimed: list[tuple[int, int]] = []
        line_matches: list[tuple[int, str, str, tuple[int, int]]] = []

        for match in URI.finditer(raw_line):
            value = clean(match.group(0))
            if value:
                span = match.span()
                claimed.append(span)
                line_matches.append((span[0], "uri", value, span))

        for match in PATH.finditer(raw_line):
            span = match.span()
            if overlaps(span, claimed):
                continue
            value = clean(match.group(0))
            if (
                value
                and value not in {".", "..", "/"}
                and not value.startswith("#")
                and not re.fullmatch(r"\d+(?:\.\d+)+", value)
            ):
                claimed.append(span)
                line_matches.append((span[0], "path", value, span))

        for match in HASH.finditer(raw_line):
            span = match.span()
            if overlaps(span, claimed):
                continue
            value = match.group(0)
            line_matches.append((span[0], "hash", value, span))

        for _, kind, value, _ in sorted(line_matches):
            found.append((kind, value, line_number, context))

    seen: set[tuple[str, str]] = set()
    for kind, value, line_number, context in reversed(found):
        identity = (kind, value)
        if identity in seen:
            continue
        seen.add(identity)
        safe_context = context.replace("\t", " ")
        print(f"{kind}\t{value}\t{line_number}\t{safe_context}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
