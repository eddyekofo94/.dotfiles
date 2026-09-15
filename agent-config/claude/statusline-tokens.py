#!/usr/bin/env python3
"""Context tokens in use for a Claude Code transcript, for the statusline.

Usage: statusline-tokens.py TRANSCRIPT [CONTEXT_WINDOW_TOKENS]
The window defaults to 200k; the caller passes 1M for [1m] models.
"""
import json, sys

path = sys.argv[1] if len(sys.argv) > 1 else ""
try:
    window = int(sys.argv[2]) if len(sys.argv) > 2 else 200_000
except ValueError:
    window = 200_000
if window <= 0:
    window = 200_000
last = None
try:
    with open(path) as fh:
        for line in fh:
            try:
                usage = (json.loads(line).get("message") or {}).get("usage")
            except json.JSONDecodeError:
                continue
            if usage:
                last = usage
except OSError:
    pass
if not last:
    sys.exit(0)
total = (
    last.get("input_tokens", 0)
    + last.get("cache_read_input_tokens", 0)
    + last.get("cache_creation_input_tokens", 0)
)
pct = round(total / window * 100)
print(f"{total/1000:.0f}k/{pct}%")
