#!/bin/bash
# Sourced by goals.sh and goal_done.sh (BibleStandard BS-IOS-FEAT-597): which
# model and effort a tab opens on, asked of the routing table
# (`tools/model_routes.py`, BS-IOS-FEAT-596) instead of a hard-coded `opus`.
#
#   model_route REPO VERB KIND          KIND is `app` or `other`
#   model_route REPO VERB --record ID   the kind read from the record
#
# Sets ROUTE_MODEL and ROUTE_EFFORT in the caller's shell (no subshell, so the
# fallback line prints once per run). REPO's own table answers first; a repo
# without one (data, web, API) asks the iOS checkout's, which owns the policy.
# A table that cannot be read opens Sonnet medium, never Opus.
ROUTE_MODEL=""
ROUTE_EFFORT=""
ROUTE_WARNED=0
# Eddy, 2026-11-15: a data record that only runs the hunter on one lane (find and
# fetch, no new code; BS-DATA-TASK-147) builds on Sonnet medium. True when REPO's
# record ID carries that Disposition. Read from REPO, not the table's repo.
route_hunt_record() {  # REPO ID
  local f
  [ -n "${2:-}" ] || return 1
  for f in "$1"/project/*/"$2"-*.md; do
    [ -f "$f" ] && grep -q '^- Disposition: finetune — runs the hunter on one lane' "$f" && return 0
  done
  return 1
}
model_route() {
  local repo="$1" pair="" table_repo
  shift
  local verb="${1:-}"
  local ios="${HERDR_ROUTES_REPO:-${HERDR_DEFAULT_REPO:-${CANONFIDEI_ROOT:-$HOME/Programming/Projects/CanonFidei}/biblestandard/ios}}"
  for table_repo in "$repo" "$ios"; do
    [ -f "${table_repo}/tools/model_routes.py" ] || continue
    pair=$(cd "$table_repo" && python3 tools/model_routes.py "$@" 2>/dev/null) || pair=""
    break
  done
  if [[ "$pair" =~ ^[a-z0-9.-]+\ [a-z]+$ ]]; then
    ROUTE_MODEL="${pair% *}"
    ROUTE_EFFORT="${pair#* }"
    # Eddy, 2026-11-14 ("Opus medium for build and as default ... tab3 is sonnet"): the table
    # cannot open a tab above medium, and only a build runs on Opus, so a table row that
    # says otherwise is clamped here. HERDR_ALLOW_HIGH=1 lifts it for one run Eddy asked for.
    if [ "${HERDR_ALLOW_HIGH:-0}" != 1 ]; then
      # Opus only for a build, or a spec the table routes to Opus (an app record).
      case "$verb" in
        build)
          ROUTE_MODEL=opus
          [ "${2:-}" = --record ] && route_hunt_record "$repo" "${3:-}" && ROUTE_MODEL=sonnet ;;
        spec) [ "$ROUTE_MODEL" = opus ] || ROUTE_MODEL=sonnet ;;
        *) ROUTE_MODEL=sonnet ;;
      esac
      ROUTE_EFFORT=medium
    fi
    return 0
  fi
  if [ "$ROUTE_WARNED" = 0 ]; then
    echo "herdr: the routing table did not answer ($*) — opening sonnet medium (BS-IOS-FEAT-597)" >&2
    ROUTE_WARNED=1
  fi
  ROUTE_MODEL=sonnet
  ROUTE_EFFORT=medium
}
