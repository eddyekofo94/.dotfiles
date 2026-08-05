#!/usr/bin/env python3
"""Cover the capture hook, including its import boundary with closeout_length.

The capture hook reuses `closeout_length`'s transcript reader. Changing that
reader's signature broke ctrl+g and nothing caught it: the length hook had a
test, this one did not, and the failure only surfaced as a traceback in Eddy's
pane. Exercise the hook as Claude Code actually runs it.
"""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HOOK = Path(__file__).resolve().parents[1] / "claude" / "closeout_capture.py"
PANE = "%42"

CLOSEOUT = """**Status:** DONE
Artifacts: none
**Next move:** stop
"""

BODY_ONLY = "Tool-only turn. Nothing settled yet.\n"


def transcript(path, messages):
    with Path(path).open("w", encoding="utf-8") as handle:
        for text in messages:
            handle.write(
                json.dumps(
                    {
                        "type": "assistant",
                        "uuid": "uuid",
                        "message": {"content": [{"type": "text", "text": text}]},
                    }
                )
                + "\n"
            )
    return path


def run(args, env, payload=None):
    return subprocess.run(
        [sys.executable, str(HOOK), *args],
        input=payload or "",
        capture_output=True,
        text=True,
        env=env,
    )


def expect(condition, label, result=None):
    if not condition:
        detail = f": {result.stderr.strip()}" if result is not None else ""
        raise SystemExit(f"closeout capture hook: {label}{detail}")


def main():
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        env = dict(os.environ, HERDR_PANE_ID=PANE, TMPDIR=str(root))
        env.pop("CLAUDE_CODE_SESSION_ID", None)
        target = root / "agent-prompt-turn-closeout._42.s1.md"

        # A pane id is reused by whatever agent starts in it next. The record
        # left by the session before must never be served to its successor.
        stale = root / "agent-prompt-turn-closeout._42.s0.md"
        stale.write_text("**Status:** DONE — a finished session\n", encoding="utf-8")
        legacy = root / "agent-prompt-turn-closeout._42.md"
        legacy.write_text("**Status:** DONE — before session scoping\n", encoding="utf-8")

        path = transcript(root / "one.jsonl", ["Body line.\n\n" + CLOSEOUT])
        payload = json.dumps({"transcript_path": str(path), "session_id": "s1"})
        result = run([], env, payload)
        expect(result.returncode == 0, "the hook exited non-zero", result)
        expect(target.exists(), "no record was written", result)
        # The body is the half the next prompt actually answers -- the checks to
        # run, the files named, the question asked. Cutting at Status drops it.
        captured = target.read_text(encoding="utf-8")
        expect(
            captured.startswith("Body line."),
            "the captured text did not start at the top of the message",
        )
        expect("**Status:** DONE" in captured, "the captured text lost the closeout")

        expect(not stale.exists(), "a finished session's record survived")
        expect(not legacy.exists(), "the pre-session filename survived")

        # A turn with no closeout must leave the last real one in place.
        path = transcript(root / "two.jsonl", [BODY_ONLY])
        payload = json.dumps({"transcript_path": str(path), "session_id": "s1"})
        result = run([], env, payload)
        expect(result.returncode == 0, "a closeout-less turn errored", result)
        expect(
            target.read_text(encoding="utf-8").startswith("Body line."),
            "a closeout-less turn erased the previous record",
        )

        # Two panes, two sessions: neither prune nor cleanup may reach the other.
        other = root / "agent-prompt-turn-closeout._43.s2.md"
        other.write_text("**Status:** DONE — the other pane\n", encoding="utf-8")
        seed = root / "agent-prompt-seed._42.txt"
        seed.write_text("stale seed\n", encoding="utf-8")

        result = run(["--session-end"], env, json.dumps({"session_id": "s1"}))
        expect(result.returncode == 0, "session end exited non-zero", result)
        expect(not target.exists(), "session end left this session's record")
        expect(not seed.exists(), "session end left the derived seed")
        expect(other.exists(), "session end reached another pane's record")

        # --print is what the ctrl+g editor shim calls.
        home = root / "home"
        project = home / ".claude" / "projects" / "-tmp-project"
        project.mkdir(parents=True)
        transcript(project / "session.jsonl", ["Body.\n\n" + CLOSEOUT])
        result = run(
            ["--print", "session", "/tmp/project"], dict(env, HOME=str(home))
        )
        expect(result.returncode == 0, "--print found no closeout", result)
        expect(
            result.stdout.startswith("Body.") and "**Status:** DONE" in result.stdout,
            "--print did not emit the whole message",
        )

    print("closeout capture hook: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
