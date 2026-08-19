#!/usr/bin/env python3
"""Cover the capture hook, including its import boundary with closeout_length.

The capture hook reuses `closeout_length`'s transcript reader. Changing that
reader's signature broke ctrl+g and nothing caught it: the length hook had a
test, this one did not, and the failure only surfaced as a traceback in Eddy's
pane. Exercise the hook as Claude Code actually runs it.
"""

import json
import os
import re
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
    Path(path).parent.mkdir(parents=True, exist_ok=True)
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
        # The suite runs inside a Herdr pane; its session must not leak into
        # the pane-only cases, which cover the no-Herdr-session fallback.
        env.pop("HERDR_SESSION", None)
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

        # Two Herdr sessions -- independent Ghostty windows -- at the *same* pane
        # id, sharing one $TMPDIR. This is the live hit-and-miss: each window's
        # Stop hook used to prune the other window's record as "the previous
        # occupant". With the Herdr session in the name, neither reaches the
        # other, and the pane-only files from before scoping are still swept.
        win_a = dict(env, HERDR_SESSION="window-43")
        win_b = dict(env, HERDR_SESSION="window-44")
        rec_a = root / "agent-prompt-turn-closeout.window-43._42.sA.md"
        rec_b = root / "agent-prompt-turn-closeout.window-44._42.sB.md"
        legacy = root / "agent-prompt-turn-closeout._42.sOld.md"
        legacy.write_text("**Status:** DONE — pane-only era\n", encoding="utf-8")

        path = transcript(root / "a.jsonl", ["Window A.\n\n" + CLOSEOUT])
        result = run([], win_a, json.dumps({"transcript_path": str(path), "session_id": "sA"}))
        expect(result.returncode == 0, "window A hook exited non-zero", result)
        expect(rec_a.exists(), "window A wrote no session-scoped record", result)
        expect(not legacy.exists(), "the pane-only record survived a scoped claim")

        path = transcript(root / "b.jsonl", ["Window B.\n\n" + CLOSEOUT])
        result = run([], win_b, json.dumps({"transcript_path": str(path), "session_id": "sB"}))
        expect(result.returncode == 0, "window B hook exited non-zero", result)
        expect(rec_b.exists(), "window B wrote no session-scoped record", result)
        expect(rec_a.exists(), "window B's claim pruned window A's live record")
        expect(
            rec_a.read_text(encoding="utf-8").startswith("Window A."),
            "window A's record was overwritten by window B",
        )

        # Window B's derived scratch is its own; window A's must survive B's end.
        seed_a = root / "agent-prompt-seed.window-43._42.txt"
        seed_b = root / "agent-prompt-seed.window-44._42.txt"
        seed_a.write_text("A\n", encoding="utf-8")
        seed_b.write_text("B\n", encoding="utf-8")
        result = run(["--session-end"], win_b, json.dumps({"session_id": "sB"}))
        expect(result.returncode == 0, "window B session end exited non-zero", result)
        expect(not rec_b.exists(), "window B's end left its own record")
        expect(not seed_b.exists(), "window B's end left its own seed")
        expect(rec_a.exists(), "window B's end removed window A's record")
        expect(seed_a.exists(), "window B's end removed window A's seed")
        rec_a.unlink()
        seed_a.unlink()

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

        # Unnamed: the project's newest transcript is still the answer. The
        # project dir is keyed on the *resolved* cwd, so use a real directory.
        proj = root / "proj"
        proj.mkdir()
        slug = re.sub(r"[^A-Za-z0-9]", "-", str(proj.resolve()))
        transcript(home / ".claude" / "projects" / slug / "s.jsonl", ["Body.\n\n" + CLOSEOUT])
        result = run(["--print", "", str(proj)], dict(env, HOME=str(home)))
        expect(result.returncode == 0, "--print unnamed found nothing", result)
        expect("**Status:** DONE" in result.stdout, "--print unnamed lost the closeout")

        # A named session with no transcript of its own -- a pane whose Claude
        # has not finished a turn yet -- must not be handed that same project
        # transcript, which belongs to some other pane.
        result = run(["--print", "fresh-session", str(proj)], dict(env, HOME=str(home)))
        expect(result.returncode != 0, "--print served another session's transcript")
        expect(not result.stdout.strip(), "--print printed for an unknown session")
        expect("fresh-session" in result.stderr, "--print did not name the missing session")

    print("closeout capture hook: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
