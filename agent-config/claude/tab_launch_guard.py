#!/usr/bin/env python3
"""Tab launch guard (Eddy, 2026-11-14: "Opus medium for build and as default ... tab3 is sonnet").

PreToolUse Bash hook. Denies a command that starts a Claude tab on `--effort high|xhigh|max`,
or on `--model opus` for anything but a `/build`. `HERDR_ALLOW_HIGH=1` in the command lifts it
for one launch Eddy asked for.
"""
import json, re, sys

def verdict(cmd: str):
    if "HERDR_ALLOW_HIGH=1" in cmd or not re.search(r"\bclaude\b[^\n]*--(model|effort)\b", cmd):
        return None
    if re.search(r"--effort[ =](high|xhigh|max)\b", cmd):
        return "Tabs open on medium effort, never high (Eddy, 2026-11-14). Use --effort medium."
    if re.search(r"--model[ =]opus\b", cmd) and not re.search(r"[\"' ]/build\b", cmd):
        return "Only a /build tab runs on Opus; every other tab is Sonnet medium (Eddy, 2026-11-14)."
    return None

def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    if data.get("tool_name") != "Bash" or data.get("agent_id"):
        return 0
    why = verdict((data.get("tool_input") or {}).get("command", ""))
    if why:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
              "permissionDecision": "deny", "permissionDecisionReason": why}}))
    return 0

if __name__ == "__main__":
    sys.exit(main())
