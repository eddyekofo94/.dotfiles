#!/usr/bin/env python3
"""Cover the Stop hook's closeout shape, its backstop, and the stale-read loop.

The hook is the only thing enforcing the response contract, so a bug in it is
either an unbounded turn or an unclearable rejection. Both have happened.
"""

import json
import runpy
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HOOK = Path(__file__).resolve().parents[1] / "claude" / "closeout_length.py"
HOOK_CONFIG = runpy.run_path(str(HOOK))
BODY_MAX = HOOK_CONFIG["BODY_MAX"]
WIDTH = HOOK_CONFIG["WIDTH"]
MAX_BLOCKS = HOOK_CONFIG["MAX_BLOCKS"]

COMPLIANT = """Two facts, one line each.

**Status:** DONE
Picked / gave up / why: nothing to pick
Not run: nothing
**Next move:** stop

**Ready-to-paste prompt:**
```
do the thing
until it is done
```
"""

# Text after the fenced prompt: the block `prefix+b` pastes is no longer last.
LONG_CLOSEOUT = "**Status:** DONE\n" + "".join(
    f"Not run: entry {index} " + "x" * 120 + "\n" for index in range(6)
)

NO_CLOSEOUT = "An answer with no closeout at all.\n"

NO_PROMPT = COMPLIANT.split("**Ready-to-paste prompt:**")[0]

# A long closeout is fine now; only its shape is checked.
ROOMY_CLOSEOUT = COMPLIANT.replace(
    "Not run: nothing", "Not run: " + "a" * 900
)

LONG_BODY = "y" * ((BODY_MAX + 1) * WIDTH) + "\n"


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


def tool_turn(directory, name, progress, reply):
    """Write a turn that narrates, calls a tool, and then (maybe) replies.

    Claude Code stores the text and the tool call as separate assistant
    entries, and the result as a user entry -- the layout the hook must see
    through. A `reply` of None is a final message not yet in the transcript.
    """
    entries = [
        {
            "type": "assistant",
            "uuid": f"{name}-progress",
            "message": {"content": [{"type": "text", "text": progress}]},
        },
        {
            "type": "assistant",
            "uuid": f"{name}-call",
            "message": {
                "content": [
                    {"type": "tool_use", "id": "call", "name": "Bash", "input": {}}
                ]
            },
        },
        {
            "type": "user",
            "uuid": f"{name}-result",
            "message": {
                "content": [
                    {"type": "tool_result", "tool_use_id": "call", "content": "ok"}
                ]
            },
        },
    ]
    if reply is not None:
        entries.append(
            {
                "type": "assistant",
                "uuid": f"{name}-reply",
                "message": {"content": [{"type": "text", "text": reply}]},
            }
        )
    path = Path(directory) / f"{name}.jsonl"
    path.write_text(
        "".join(json.dumps(entry) + "\n" for entry in entries), encoding="utf-8"
    )
    return path


WAITING = (
    "Gate running.\n\n"
    "**Status:** WAITING — `verify_app.py`; resumes when it exits, nothing to paste\n"
)


def background_turn(directory, name, launch, ends, reply, tool="Bash"):
    """Write a turn that launches a background job, maybe hears it end, then replies.

    `launch` is Claude Code's tool-result text for the launch; each of `ends`
    is a raw entry announcing an end, in the shapes the transcript uses.
    """
    entries = [
        {
            "type": "assistant",
            "uuid": f"{name}-call",
            "message": {
                "content": [
                    {"type": "tool_use", "id": "call", "name": tool, "input": {}}
                ]
            },
        },
        {
            "type": "user",
            "uuid": f"{name}-result",
            "message": {
                "content": [
                    {"type": "tool_result", "tool_use_id": "call", "content": launch}
                ]
            },
        },
        *ends,
        {
            "type": "assistant",
            "uuid": f"{name}-reply",
            "message": {"content": [{"type": "text", "text": reply}]},
        },
    ]
    path = Path(directory) / f"{name}.jsonl"
    path.write_text(
        "".join(json.dumps(entry) + "\n" for entry in entries), encoding="utf-8"
    )
    return path


BASH_LAUNCH = "Command running in background with ID: bjob1. Output is being written to: /tmp/x"
TIMEOUT_LAUNCH = "Command did not complete within its 120s timeout and was moved to the background (ID: bjob2)."
AGENT_LAUNCH = "Async agent launched successfully.\nagentId: a123 (internal ID)"
BASH_END = {
    "type": "queue-operation",
    "content": "<task-notification>\n<task-id>bjob1</task-id>\n"
    "<tool-use-id>t</tool-use-id>\n<status>completed</status>\n</task-notification>",
}
AGENT_END = {
    "type": "user",
    "message": {"content": 'Another Claude session sent a message:\n<agent-message from="a123">\n[Subagent hand-back] done'},
}


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


def run_while_landing(path, reply, delay):
    """Start the hook, then append the reply after `delay` seconds.

    This is the headless race: Stop fires before the reply is written.
    """
    payload = json.dumps({"transcript_path": str(path), "stop_hook_active": False})
    hook = subprocess.Popen(
        [sys.executable, str(HOOK)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        text=True,
    )
    hook.stdin.write(payload)
    hook.stdin.close()
    time.sleep(delay)
    entry = {
        "type": "assistant",
        "uuid": f"{path.stem}-reply",
        "message": {"content": [{"type": "text", "text": reply}]},
    }
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry) + "\n")
    output = hook.stdout.read()
    hook.wait(timeout=5)
    if not output.strip():
        return None
    return json.loads(output)


def expect(condition, label):
    if not condition:
        raise SystemExit(f"closeout length hook: {label}")


def main():
    with tempfile.TemporaryDirectory() as directory:
        path = transcript(directory, "compliant", [COMPLIANT])
        expect(run(path) is None, "a compliant turn was rejected")

        path = transcript(directory, "roomy-closeout", [ROOMY_CLOSEOUT])
        expect(run(path) is None, "a well-shaped long closeout was rejected")

        path = transcript(directory, "prompt-not-last", [COMPLIANT + "Trailing prose after the prompt.\n"])
        decision = run(path)
        expect(decision is not None, "text after the fenced prompt was allowed")
        expect(
            decision["decision"] == "block" and "not the last" in decision["reason"],
            "the rejection did not name the misplaced prompt",
        )

        path = transcript(directory, "no-closeout", [NO_CLOSEOUT])
        decision = run(path)
        expect(decision is not None, "a turn without a closeout was allowed")
        expect("no closeout" in decision["reason"], "missing closeout not named")

        path = transcript(directory, "no-prompt", [NO_PROMPT])
        decision = run(path)
        expect(decision is not None, "a turn without the prompt block was allowed")
        expect("Ready-to-paste" in decision["reason"], "missing prompt not named")

        path = transcript(directory, "under-backstop", ["z\n" * (BODY_MAX - 1) + COMPLIANT])
        expect(run(path) is None, "a body at the backstop was rejected")

        path = transcript(directory, "long-body", [LONG_BODY + COMPLIANT])
        decision = run(path)
        expect(decision is not None, "an over-long body was allowed")
        expect("body is" in decision["reason"], "the rejection did not name the body")
        expect("backstop is 60" in decision["reason"], "the backstop is not 60")

        # Progress text written before a tool call is not the reply. Measuring
        # it rejected turns whose final message after the tool was compliant.
        path = tool_turn(directory, "progress-then-reply", NO_CLOSEOUT, COMPLIANT)
        expect(run(path) is None, "progress text before a tool call was measured")

        path = tool_turn(directory, "progress-no-reply", LONG_BODY, None)
        expect(
            run(path) is None,
            "progress text was measured while the final reply was still unwritten",
        )

        # Headless sessions run Stop before the reply is written. The hook must
        # wait for it rather than pass a turn it never measured.
        path = tool_turn(directory, "late-reply", COMPLIANT, None)
        decision = run_while_landing(path, NO_CLOSEOUT, 0.3)
        expect(decision is not None, "a reply that landed late went unmeasured")
        expect("no closeout" in decision["reason"], "the late reply was not measured")

        path = tool_turn(directory, "late-compliant", NO_CLOSEOUT, None)
        expect(
            run_while_landing(path, COMPLIANT, 0.3) is None,
            "a compliant reply that landed late was rejected",
        )

        path = tool_turn(directory, "reply-without-closeout", COMPLIANT, NO_CLOSEOUT)
        decision = run(path)
        expect(decision is not None, "a final reply without a closeout was allowed")
        expect("no closeout" in decision["reason"], "the final reply was not measured")

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
            json.dumps({"blocks": MAX_BLOCKS, "uuid": "spent"}), encoding="utf-8"
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

        # BUG-348: a turn waiting on its own background job ends with WAITING
        # and no prompt, so it never reads as a handoff.
        for name, launch in (("wait-bash", BASH_LAUNCH), ("wait-timeout", TIMEOUT_LAUNCH),
                             ("wait-agent", AGENT_LAUNCH)):
            path = background_turn(directory, name, launch, [], WAITING)
            expect(run(path) is None, f"{name}: WAITING on a pending job was rejected")

        for name, launch, end in (("ended-bash", BASH_LAUNCH, BASH_END),
                                  ("ended-agent", AGENT_LAUNCH, AGENT_END)):
            path = background_turn(directory, name, launch, [end], WAITING)
            decision = run(path)
            expect(decision is not None, f"{name}: WAITING on a finished job was allowed")
            expect("no background job pending" in decision["reason"],
                   f"{name}: the rejection did not name the missing job")

        path = transcript(directory, "wait-no-job", [WAITING])
        expect(run(path) is not None, "WAITING with no job at all was allowed")

        path = background_turn(directory, "wait-with-prompt", BASH_LAUNCH, [],
                               WAITING + COMPLIANT.split("**Next move:** stop")[1])
        decision = run(path)
        expect(decision is not None, "WAITING with a paste prompt was allowed")
        expect("ready-to-paste" in decision["reason"], "the prompt under WAITING was not named")

        path = background_turn(directory, "wait-unnamed", BASH_LAUNCH, [],
                               "**Status:** WAITING\n")
        decision = run(path)
        expect(decision is not None and "name the job" in decision["reason"],
               "WAITING that names no job was allowed")

        # A bare fence under WAITING is still a prompt `prefix+b` would paste.
        path = background_turn(directory, "wait-bare-fence", BASH_LAUNCH, [],
                               WAITING + "```\nresume\n```\n")
        expect(run(path) is not None, "a bare fenced block under WAITING was allowed")

        # A tool result that merely quotes the launch wording (a `cat` of this
        # very file) is not a launch: only a result that opens with it is.
        quoted = "WAITING = ...\nBASH_LAUNCH = \"Command running in background with ID: bjob9\""
        path = background_turn(directory, "wait-quoted", quoted, [], WAITING)
        expect(run(path) is not None, "launch wording quoted in tool output counted as a job")

        # A real agent launch: an `Agent` call whose result is a list of text blocks.
        path = background_turn(directory, "wait-real-agent", [{"type": "text", "text": AGENT_LAUNCH}],
                               [], WAITING, tool="Agent")
        expect(run(path) is None, "WAITING on a real Agent launch was rejected")
        path = background_turn(directory, "wait-read-agent", AGENT_LAUNCH, [], WAITING, tool="Read")
        expect(run(path) is not None, "launch wording in a Read result counted as a job")

        # Jobs outlive `/clear`: the new session cannot see them launch, so it
        # cannot refuse (BUG-327's tab at 20:10, gate still running).
        def cleared(age):
            stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - age))
            return json.dumps({"type": "user", "timestamp": stamp, "message": {
                "content": "<command-name>/clear</command-name>"}}, separators=(",", ":"))
        path = transcript(directory, "wait-after-clear", [WAITING])
        path.write_text(cleared(60) + "\n" + path.read_text(), encoding="utf-8")
        expect(run(path) is None, "WAITING just after /clear was refused")
        # Past a job's lifetime nothing launched before the clear can still run.
        path = transcript(directory, "wait-long-after-clear", [WAITING])
        path.write_text(cleared(3 * 3600) + "\n" + path.read_text(), encoding="utf-8")
        expect(run(path) is not None, "WAITING hours after /clear was let through")

        # Claude Code may put a cwd line before the launch (`cd` out of the session).
        prefixed = "Shell cwd was reset to /tmp/x\n" + BASH_LAUNCH
        path = background_turn(directory, "wait-prefixed", prefixed, [], WAITING)
        expect(run(path) is None, "a launch after a cwd-reset line was missed")

        # The closeout is the last Status line: a body quoting a WAITING line
        # (as skill-finish does) is still judged as the DONE closeout it ends in.
        path = transcript(directory, "quotes-waiting", [
            "The new form:\n```text\n**Status:** WAITING — x; resumes\n```\n" + COMPLIANT])
        expect(run(path) is None, "a quoted WAITING line made a DONE closeout fail")
        path = background_turn(directory, "waiting-after-quote", BASH_LAUNCH, [],
                               "Earlier: **Status:** DONE\n**Status:** DONE was last turn.\n" + WAITING)
        expect(run(path) is None, "an older Status line in the body broke a real WAITING")

        # Quoting an agent ID in prose is not a launch.
        path = transcript(directory, "wait-talk", ["agentId: a999 was mentioned\n" + WAITING])
        expect(run(path) is not None, "an agent ID in assistant text counted as a job")

        expect("**Status:** WAITING" in HOOK_CONFIG["contract"](),
               "the injected contract does not teach WAITING")

    print("closeout length hook: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
