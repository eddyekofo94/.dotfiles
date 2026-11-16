#!/usr/bin/env python3
"""Model route warning (retro ios-2026-11-16: tab 51c208ba, Opus high, 16.5M tokens).

UserPromptSubmit hook. tab_launch_guard.py only sees launch commands; an in-session `/model`
or `/effort` switch slips past it. This reads the live model and effort from the transcript
tail and, in a tab that is not a /build or /spec, says once per state to go back to Sonnet
medium. Eddy's own word lifts it with `HERDR_ALLOW_HIGH=1`. Any error exits 0.
"""
import json, os, re, sys
from pathlib import Path

STATE = Path(os.environ.get("TMPDIR", "/tmp")) / "claude-model-route-warn"
TAIL, HEAD = 2_000_000, 400_000
EXEMPT = re.compile(rb"<command-name>/(build|spec)</command-name>|\"content\":\"/(build|spec)\b")
COSTLY = {"high", "xhigh", "max"}


def live(transcript: str):
    """(model, effort) of the last assistant line in the tail, else (None, None)."""
    with open(transcript, "rb") as h:
        h.seek(0, os.SEEK_END)
        h.seek(max(0, h.tell() - TAIL))
        lines = h.read().splitlines()
    for raw in reversed(lines):
        if b'"type":"assistant"' not in raw.replace(b'": "', b'":"'):
            continue
        try:
            d = json.loads(raw)
        except ValueError:
            continue
        model = (d.get("message") or {}).get("model")
        if model and not model.startswith("<"):
            return model, d.get("effort") or d.get("perTurnEffort")
    return None, None


def exempt(transcript: str) -> bool:
    with open(transcript, "rb") as h:
        head = h.read(HEAD)
        h.seek(0, os.SEEK_END)
        h.seek(max(HEAD, h.tell() - TAIL))
        tail = h.read()
    return bool(EXEMPT.search(head) or EXEMPT.search(tail))


def warning(model, effort):
    if not model:
        return None
    bits = []
    if "opus" in model:
        bits.append("Opus")
    if effort in COSTLY:
        bits.append(f"effort {effort}")
    if not bits:
        return None
    return (f"Model route: this tab runs {' and '.join(bits)}, but only a /build or app /spec tab does "
            f"(Eddy, 2026-11-14). Switch back to Sonnet medium (/model sonnet, /effort medium) unless Eddy asked for it.")


def main():
    try:
        data = json.load(sys.stdin)
        if data.get("agent_id") or os.environ.get("HERDR_ALLOW_HIGH") == "1":
            return 0
        transcript, session = data.get("transcript_path"), data.get("session_id")
        if not transcript or not session or not os.path.exists(transcript):
            return 0
        model, effort = live(transcript)
        note = warning(model, effort)
        if not note or exempt(transcript):
            return 0
        STATE.mkdir(parents=True, exist_ok=True)
        marker = STATE / session
        key = f"{model} {effort}"
        if marker.exists() and marker.read_text() == key:
            return 0
        marker.write_text(key)
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": note}}))
    except Exception:
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
