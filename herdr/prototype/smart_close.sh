#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_TARGET_PANE_ID:-$("$prototype/focused_pane.sh")}

# Never close a pane that is actively running an agent (claude, codex, ...) when
# invoked via the guarded Alt+q path. Explain why and point at prefix+x, which
# calls this script WITHOUT the guard and so stays a real force-close escape
# hatch (still gated by the normal foreground-process confirmation below).
agent=$($herdr pane current --pane "$pane" | jq -r '.result.pane.agent // ""')
if [ -n "$agent" ] && [ "${SMART_CLOSE_PROTECT_AGENT:-}" = "1" ]; then
  $herdr notification show "Won't close: $agent is running" \
    --body "Alt+q is disabled for agent panes; use prefix+x to force close" \
    --position bottom-right --sound none >/dev/null 2>&1 || true
  printf 'smart-close: refused to close agent pane %s (%s)\n' "$pane" "$agent" >&2
  exit 0
fi

panes=$($herdr pane list)
tab=$($herdr pane current --pane "$pane" | jq -er '.result.pane.tab_id')
count=$(printf '%s\n' "$panes" | jq --arg tab "$tab" \
  '[.result.panes[] | select(.tab_id == $tab)] | length')
processes=$($herdr pane process-info --pane "$pane")
state_root=${HERDR_CLOSE_STATE_DIR:-"$prototype/.runtime/close-confirm"}
pane_key=$(printf '%s' "$pane" | tr -c '[:alnum:]_.-' '_')
state="$state_root/$pane_key"
mkdir -p "$state_root"

confirm_or_close() {
  reason=$1
  fingerprint=$(printf '%s\n' "$processes" | jq -c \
    '[.result.process_info.foreground_processes[]? | {name,pid}]')
  now=$(date +%s)
  if [ -f "$state" ]; then
    saved_time=$(sed -n '1p' "$state")
    saved_fingerprint=$(sed -n '2p' "$state")
    if [ "$saved_fingerprint" = "$fingerprint" ] && [ $((now - saved_time)) -le 5 ]; then
      rm -f "$state"
      exec $herdr pane close "$pane"
    fi
  fi
  printf '%s\n%s\n' "$now" "$fingerprint" >"$state"
  $herdr notification show "Close pane? Press Alt+q again within 5s" \
    --body "$reason" \
    --position bottom-right --sound none >/dev/null 2>&1 || true
  printf 'smart-close: confirmation required for %s in pane %s\n' "$reason" "$pane" >&2
  exit 75
}

if [ "$count" -le 1 ]; then
  confirm_or_close "last pane"
fi

if ! printf '%s\n' "$processes" | jq -e '
  [.result.process_info.foreground_processes[]?
   | .name = (.name | ascii_downcase)
   | select(
       (.name != "sh" and .name != "bash" and .name != "zsh" and
        .name != "fish" and .name != "nu" and .name != "dash") and
       ((.name == "herdr" and ((.argv // []) | join(" ") | contains("pane process-info"))) | not)
     )]
  | length == 0
' >/dev/null; then
  confirm_or_close "running foreground process"
fi

rm -f "$state"
exec $herdr pane close "$pane"
