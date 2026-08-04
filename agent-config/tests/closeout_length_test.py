#!/usr/bin/env python3
"""Cover the Stop hook's line budget, and the stale-read loop it once had.

The hook is the only thing enforcing the response contract, so a bug in it is
either an unbounded turn or an unclearable rejection. Both have happened.
"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

HOOK = Path(__file__).resolve().parents[1] / "claude" / "closeout_length.py"
MAX_BLOCKS = 4  # mirrors the hook; the test drives a whole spent-budget turn

COMPLIANT = """Two facts, one line each.

**Status:** DONE
Artifacts: none
Verification: nothing to run
Risks: none
**Next move:** stop

**Ready-to-paste prompt:**
```
do the thing
until it is done
```
"""

LONG_CLOSEOUT = "**Status:** DONE\n" + "".join(
    f"Artifacts: entry {index} " + "x" * 120 + "\n" for index in range(6)
)

LONG_BODY = "".join(f"Narration line {index} " + "y" * 120 + "\n" for index in range(9))


def transcript(directory, name, messages):
    """Write a transcript whose assistant entries carry the given texts.

    Scenarios that share a `name` share the file, its sidecar state, and its
    message uuids -- which is exactly what resuming a blocked turn looks like.
    Everything else needs a distinct name, or it inherits the previous
    scenario's state and proves nothing.
    """
    path = Path(directory) / f"{name}.jsonl"
    with path.open("w", encoding="utf-8") as handle:
        for index, text in enumerate(messages):
            handle.write(
                json.dumps(
                    {
                        "type": "assistant",
                        "uuid": f"{name}-{index}",
                        "message": {"content": [{"type": "text", "text": text}]},
                    }
                )
                + "\n"
            )
    return path


def run(path, stop_hook_active=False):
    """Invoke the hook the way Claude Code does, and return its decision."""
    payload = json.dumps(
        {"transcript_path": str(path), "stop_hook_active": stop_hook_active}
    )
    result = subprocess.run(
        [sys.executable, str(HOOK)],
        input=payload,
        capture_output=True,
        text=True,
        check=True,
    )
    if not result.stdout.strip():
        return None
    return json.loads(result.stdout)


def expect(condition, label):
    if not condition:
        raise SystemExit(f"closeout length hook: {label}")


def main():
    with tempfile.TemporaryDirectory() as directory:
        path = transcript(directory, "compliant", [COMPLIANT])
        expect(run(path) is None, "a compliant turn was rejected")

        path = transcript(directory, "long-closeout", [COMPLIANT + LONG_CLOSEOUT])
        decision = run(path)
        expect(decision is not None, "an over-long closeout was allowed")
        expect(
            decision["decision"] == "block" and "closeout is" in decision["reason"],
            "the rejection did not name the closeout",
        )

        path = transcript(directory, "long-body", [LONG_BODY + COMPLIANT])
        decision = run(path)
        expect(decision is not None, "an over-long body was allowed")
        expect("body is" in decision["reason"], "the rejection did not name the body")

        # The regression. The transcript is written asynchronously, so the
        # re-send is often absent when the hook runs again: it re-reads the
        # message it just blocked. Measuring that a second time quoted the old
        # counts at a reply that had already fixed them, and no amount of
        # cutting could clear it -- three real turns were rejected this way.
        path = transcript(directory, "stale", [COMPLIANT + LONG_CLOSEOUT])
        expect(run(path) is not None, "the first over-long turn was allowed")
        expect(
            run(path, stop_hook_active=True) is None,
            "the same message was rejected twice; the stale-read loop is back",
        )

        # Once the re-send lands it is measured on its own merits, over or under.
        path = transcript(directory, "landed-short", [COMPLIANT + LONG_CLOSEOUT])
        expect(run(path) is not None, "the first over-long turn was allowed")
        path = transcript(
            directory, "landed-short", [COMPLIANT + LONG_CLOSEOUT, COMPLIANT]
        )
        expect(
            run(path, stop_hook_active=True) is None,
            "a compliant re-send was rejected",
        )

        path = transcript(directory, "landed-long", [COMPLIANT + LONG_CLOSEOUT])
        expect(run(path) is not None, "the first over-long turn was allowed")
        path = transcript(
            directory,
            "landed-long",
            [COMPLIANT + LONG_CLOSEOUT, COMPLIANT + LONG_CLOSEOUT],
        )
        expect(
            run(path, stop_hook_active=True) is not None,
            "an over-long re-send went through unchecked",
        )

        # A sidecar from the previous format holds a bare count. It must not
        # crash the hook or read as a message identity.
        path = transcript(directory, "legacy-state", [COMPLIANT + LONG_CLOSEOUT])
        Path(str(path) + ".closeout-blocks").write_text("2", encoding="utf-8")
        expect(
            run(path, stop_hook_active=True) is not None,
            "a legacy state file suppressed a real rejection",
        )

        # Repeated failure must still terminate rather than wedge the session.
        path = transcript(directory, "spent", [COMPLIANT + LONG_CLOSEOUT])
        Path(str(path) + ".closeout-blocks").write_text(
            json.dumps({"blocks": 4, "uuid": "spent"}), encoding="utf-8"
        )
        expect(
            run(path, stop_hook_active=True) is None,
            "the hook kept blocking past its own limit",
        )

        # A spent budget belongs to the turn that spent it. Carried forward it
        # is a lifetime total: four bad turns and every later re-send goes
        # through unmeasured, which is the hook silently switching itself off.
        # The re-send is where that shows -- the first Stop of a turn is
        # measured either way -- so drive a whole turn, not just one call.
        path = transcript(directory, "fresh-turn", [COMPLIANT + LONG_CLOSEOUT])
        Path(str(path) + ".closeout-blocks").write_text(
            json.dumps({"blocks": MAX_BLOCKS, "uuid": "older"}), encoding="utf-8"
        )
        expect(run(path) is not None, "a fresh turn was not measured")
        path = transcript(
            directory,
            "fresh-turn",
            [COMPLIANT + LONG_CLOSEOUT, COMPLIANT + LONG_CLOSEOUT],
        )
        expect(
            run(path, stop_hook_active=True) is not None,
            "a spent budget carried into the next turn and freed its re-send",
        )

    print("closeout length hook: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
