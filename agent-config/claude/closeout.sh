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
    # Full contract on prompt 1 and every 8th after it (about 450 tokens each);
    # the prompts between carry one line. The Stop hook enforces every turn.
    sid=$(jq -r '.session_id // "none"' 2>/dev/null | tr -cd 'A-Za-z0-9_-') || sid=none
    dir="${CLOSEOUT_STATE:-$HOME/.local/state/agents/closeout_prompts}"
    mkdir -p "$dir" 2>/dev/null || true
    n=$(cat "$dir/${sid:-none}" 2>/dev/null || echo 0)
    n=$((n + 1))
    echo "$n" >"$dir/${sid:-none}" 2>/dev/null || true
    if [ $(( (n - 1) % 8 )) -ne 0 ]; then
      printf '%s' 'Closeout rules unchanged: end with **Status:** line, Picked / gave up / why, Not run, **Next move:**, then a fenced **Ready-to-paste prompt:** last (WAITING only with a live background job, no prompt block). Body 60 lines max.' |
        jq -Rs '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:.}}'
      exit 0
    fi
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
