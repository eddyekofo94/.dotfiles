#!/bin/sh
# herdr-ensure-master: seat the master in tab 1 of the herdr session Eddy starts in
# (master plan M1, M7). Started in the background at login, beside
# ensure_plugins.sh, by prototype/herdr_login_attach.fish.
#
#   ensure_master.sh <session>   seat it in <session> (`main` or `window-N`)
#   ensure_master.sh --dry-run <session>
#   ensure_master.sh --here      `/master` typed in a tab: label this tab the seat
#
# Any session the login attach starts gets the seat (2026-11-12: Eddy's /master ran in
# `1 ios` of `window-114` because only `main` was seated). Tab 1 is the session's first
# tab. It is seated only when it is a fresh session's lone tab, or already labelled
# master (a restart left the seat without its agent), and its pane runs no agent: so
# a restored tab Eddy works in is never typed into.
# It is labelled `✻ master` (tab_status.sh stamps `1 ✻ master`) and runs
# `env AGENT_ROLE=master AGENT_NAME=master claude --name master --model fable "/master"`
# in the BibleStandard root. A tab 1 already running an agent is never taken over.
# One master per machine: a `master` tab in any live session stops it.
# `~/.config/herdr/no-master` (or HERDR_NO_MASTER=1) turns it off.
#
# `--here` (the /master skill's first step) labels $HERDR_TAB_ID `✻ master` unless
# another live tab already is the master (exit 3, naming it). Herdr cannot move a tab,
# so a seat taken by hand keeps its position.
set -eu

DRY=0 HERE=0
[ "${1:-}" = --dry-run ] && { DRY=1; shift; }
[ "${1:-}" = --here ] && { HERE=1; shift; }
if [ "$HERE" = 1 ]; then
  [ -n "${HERDR_TAB_ID:-}" ] && [ -n "${HERDR_SESSION:-}" ] ||
    { echo "ensure-master --here: not inside a herdr tab" >&2; exit 64; }
  session=$HERDR_SESSION
else
  session=${1:-main}
fi
case "$session" in
  *[!A-Za-z0-9._-]*|'') echo "unsafe Herdr session name" >&2; exit 64 ;;
esac
[ "$HERE" = 1 ] || [ -z "${HERDR_NO_MASTER:-}" ] || exit 0
[ "$HERE" = 1 ] || [ ! -e "${HERDR_NO_MASTER_FILE:-$HOME/.config/herdr/no-master}" ] || exit 0

herdr_bin=${HERDR_BIN_PATH:-"$HOME/.local/bin/herdr"}
org=${HERDR_BOARD_ORG:-"${CANONFIDEI_ROOT:-$HOME/Programming/Projects/CanonFidei}/biblestandard"}
model=${HERDR_MASTER_MODEL:-fable}
h() { "$herdr_bin" --session "$session" "$@"; }
is_master='(.label // "") | sub("^\\[?[0-9]+\\]? *"; "") | ltrimstr("✻ ") | ltrimstr("✼ ") | ltrimstr("✽ ") == "master"'

# A first login starts the server concurrently: wait for it, briefly.
attempt=0
until tabs=$(h tab list 2>/dev/null) && [ -n "$(printf '%s' "$tabs" | jq -r '.result.tabs[0].tab_id // empty')" ]; do
  attempt=$((attempt + 1))
  [ "$attempt" -lt 100 ] || { echo "ensure-master: herdr session $session never answered" >&2; exit 75; }
  sleep 0.1
done

# Another live window already seats a master.
for sock in "$HOME/.config/herdr/sessions"/*/herdr.sock; do
  [ -S "$sock" ] || continue
  [ "$(basename "$(dirname "$sock")")" = "$session" ] && continue
  if HERDR_SOCKET_PATH="$sock" perl -e 'alarm 5; exec @ARGV' "$herdr_bin" tab list 2>/dev/null |
      jq -e ".result.tabs[]? | select($is_master)" >/dev/null 2>&1; then
    [ "$HERE" = 1 ] || exit 0
    echo "ensure-master --here: the master already sits in session $(basename "$(dirname "$sock")"); not seating this tab" >&2
    exit 3
  fi
done

if [ "$HERE" = 1 ]; then
  other=$(printf '%s' "$tabs" | jq -r --arg me "$HERDR_TAB_ID" \
    "[.result.tabs[] | select(.tab_id != \$me) | select($is_master) | .tab_id][0] // empty")
  [ -z "$other" ] || { echo "ensure-master --here: the master already sits in $session tab $other; not seating this tab" >&2; exit 3; }
  if printf '%s' "$tabs" | jq -e --arg me "$HERDR_TAB_ID" ".result.tabs[] | select(.tab_id == \$me) | select($is_master)" >/dev/null; then
    echo "ensure-master --here: $session tab $HERDR_TAB_ID is already the seat"; exit 0
  fi
  [ "$DRY" = 1 ] && { echo "would run: herdr tab rename $HERDR_TAB_ID \"✻ master\""; exit 0; }
  h tab rename "$HERDR_TAB_ID" "✻ master" >/dev/null
  echo "ensure-master --here: seated the master in $session tab $HERDR_TAB_ID"
  exit 0
fi

tab=$(printf '%s' "$tabs" | jq -r '.result.tabs[0].tab_id')
printf '%s' "$tabs" | jq -e "(.result.tabs | length) == 1 or (.result.tabs[0] | $is_master)" >/dev/null ||
  { echo "ensure-master: $session tab 1 is someone's tab; not seating the master" >&2; exit 0; }
pane=$(h pane list 2>/dev/null | jq -r --arg tab "$tab" '[.result.panes[]? | select(.tab_id == $tab)][0] // {} | if (.agent // "") == "" then .pane_id // "" else "" end')
[ -n "$pane" ] || exit 0  # tab 1 already runs an agent (the master, or Eddy's own)

launch="cd '$org' && env AGENT_ROLE=master AGENT_NAME=master claude --name master --model $model \"/master\""
if [ "$DRY" = 1 ]; then
  echo "would run: herdr tab rename $tab \"✻ master\""
  echo "would run: herdr pane run $pane $launch"
  exit 0
fi
h tab rename "$tab" "✻ master" >/dev/null
h pane run "$pane" "$launch" >/dev/null
echo "ensure-master: seated the master in $session tab $tab ($model)"
