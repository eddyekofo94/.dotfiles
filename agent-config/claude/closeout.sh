#!/bin/sh
# Inject the Stop hook's line budget every turn and run the closeout hooks.
set -eu

case "${1:-context}" in
  length)
    # Enforce the line budget mechanically. Reminding the model has failed
    # repeatedly, so this rejects the turn and makes it re-send a shorter one.
    exec python3 "$(dirname -- "$0")/closeout_length.py"
    ;;
  capture)
    # Save the closeout for the ctrl+g prompt editor while it is still
    # knowable. Scraping the pane later fails: `herdr pane read` returns about
    # one viewport, and the agent has redrawn by then.
    exec python3 "$(dirname -- "$0")/closeout_capture.py"
    ;;
  end)
    # Drop this session's closeout when it ends, so the next agent in the pane
    # is never handed a finished session's work.
    exec python3 "$(dirname -- "$0")/closeout_capture.py" --session-end
    ;;
  context)
    # This branch reads nothing from the hook payload; drain it so the writer
    # never blocks. Must not happen before `length`, which needs that payload.
    cat >/dev/null 2>&1 || true
    # Response Style and Closeout already load once through CLAUDE.md's import
    # of agent-config/AGENTS.md, so only the Stop hook's exact numbers are
    # injected, generated from the check's own constants.
    python3 "$(dirname -- "$0")/closeout_length.py" --contract |
      jq -Rs '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:.}}'
    ;;
  *)
    exit 0
    ;;
esac
