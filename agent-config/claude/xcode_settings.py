#!/usr/bin/env python3
"""Xcode's Claude settings: the shared settings.json without the terminal-tab hooks (BS-IOS-TASK-720).
Xcode 27.1 runs its bundled Claude with CLAUDE_CONFIG_DIR set to
~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig, so it never reads
~/.claude/settings.json. A link would carry hooks that assume a herdr or tmux tab
(the closeout Stop hook would reject every chat answer without its skeleton), so
install.sh writes this script's output there instead.

Left out, each one assuming a terminal tab:
  agent_status.py       the tmux pane's agent status
  herdr-agent-state.sh  the herdr tab's agent state
  closeout.sh           the closeout skeleton, capture and length check
  retro_due.py          the retro reminder that opens a tab
  statusLine            Xcode's chat has no status line
Kept: build_budget_guard.py, context_guard.py, compact_handoff.py and
bash_output_trim.py, which read only the hook payload and the transcript.

Usage: xcode_settings.py <shared settings.json>   (prints the Xcode settings)
"""

import json
import sys

TERMINAL_HOOKS = ("agent_status.py", "herdr-agent-state.sh", "closeout.sh", "retro_due.py")
TERMINAL_KEYS = ("statusLine",)


def xcode_settings(shared: dict) -> dict:
    settings = {key: value for key, value in shared.items() if key not in TERMINAL_KEYS}
    hooks = {}
    for event, matchers in shared.get("hooks", {}).items():
        kept_matchers = []
        for matcher in matchers:
            kept = [hook for hook in matcher.get("hooks", [])
                    if not any(name in hook.get("command", "") for name in TERMINAL_HOOKS)]
            if kept:
                kept_matchers.append({**matcher, "hooks": kept})
        if kept_matchers:
            hooks[event] = kept_matchers
    settings["hooks"] = hooks
    return settings


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    with open(argv[1], encoding="utf-8") as handle:
        shared = json.load(handle)
    json.dump(xcode_settings(shared), sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
