#!/bin/sh
# Inject the repository-owned response and closeout contract every turn.
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
    source_file=/Users/eddyekofo/.dotfiles/pi/AGENTS.md
    [ -r "$source_file" ] || exit 1
    # The prose contract says "aim under 15"; the Stop hook rejects at exact
    # numbers it never stated. Append them, generated from the check's own
    # constants, so the budget is known before the turn instead of after it.
    {
      awk '/^## Response Style / { emit = 1 } emit' "$source_file"
      python3 "$(dirname -- "$0")/closeout_length.py" --contract
    } |
      jq -Rs '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:.}}'
    ;;
  *)
    exit 0
    ;;
esac
