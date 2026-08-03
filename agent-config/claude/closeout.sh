#!/bin/sh
# Inject the repository-owned response and closeout contract every turn.
set -eu

case "${1:-context}" in
  length)
    # Enforce the line budget mechanically. Reminding the model has failed
    # repeatedly, so this rejects the turn and makes it re-send a shorter one.
    exec python3 "$(dirname -- "$0")/closeout_length.py"
    ;;
  context)
    # This branch reads nothing from the hook payload; drain it so the writer
    # never blocks. Must not happen before `length`, which needs that payload.
    cat >/dev/null 2>&1 || true
    source_file=/Users/eddyekofo/.dotfiles/pi/AGENTS.md
    [ -r "$source_file" ] || exit 1
    awk '/^## Response Style / { emit = 1 } emit' "$source_file" |
      jq -Rs '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:.}}'
    ;;
  *)
    exit 0
    ;;
esac
