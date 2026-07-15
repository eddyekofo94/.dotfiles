#!/usr/bin/env python3
import re
import sys


def main() -> int:
    column = int(sys.argv[1] or "1")
    width = int(sys.argv[2] or "120")
    query = sys.argv[3]
    text_ansi = sys.argv[4] if len(sys.argv) > 4 else ""
    ansi_re = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")
    text = ansi_re.sub("", text_ansi)

    if not text:
        return 0

    match_start = None
    match_end = None
    plain_index = 0
    in_ansi = False
    i = 0

    while i < len(text_ansi):
        match = ansi_re.match(text_ansi, i)
        if match:
            if match.group(0) == "\x1b[0m":
                if in_ansi and match_start is not None and match_end is None:
                    match_end = plain_index
                in_ansi = False
            else:
                in_ansi = True
            i = match.end()
            continue

        if in_ansi and not text_ansi[i].isspace():
            if match_start is None:
                match_start = plain_index + 1

        plain_index += 1
        i += 1

    if match_start is None:
        before = text.encode("utf-8")[: max(0, column - 1)]
        match_start = len(before.decode("utf-8", errors="ignore")) + 1

    if query:
        idx = text.lower().find(query.lower(), max(0, match_start - 4))
        if idx >= 0:
            match_start = idx + 1

    start = max(1, match_start - width // 3)
    end = start + width - 1
    snippet = text[start - 1 : end]
    prefix = "..." if start > 1 else ""
    pointer = max(1, match_start - start + 1 + len(prefix))

    if match_end is not None:
        span_start = max(match_start, start)
        span_end = min(match_end, end)
        if span_start <= span_end:
            left = span_start - start
            right = span_end - start + 1
            snippet = (
                snippet[:left]
                + "\033[1;31m"
                + snippet[left:right]
                + "\033[0m"
                + snippet[right:]
            )
    elif query:
        snippet = re.sub(
            re.escape(query),
            lambda m: f"\033[1;31m{m.group(0)}\033[0m",
            snippet,
            flags=re.IGNORECASE,
        )

    print(prefix + snippet)
    print(" " * (pointer - 1) + "\033[1;32m^\033[0m")
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
