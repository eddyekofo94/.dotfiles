#!/bin/bash
# herdr-tab-status: stamp each tab's label with its position.
#
# Herdr numbers a tab only while it carries its default label, so a named goal
# tab loses the key that selects it. Two label shapes, position always first —
# that is what prefix+N selects, and it is the half that survives the sidebar's
# truncation:
#
#   "<position> <repo>"    fresh tab, or an agent with no useful title yet
#   "<position> <name>"    a deliberate goal name (assigned with
#                          `herdr tab create --label` by herdr-goals), or an
#                          agent's live, self-set terminal title
#
# No state glyph: the sidebar renders agent state in its own left-hand column,
# and in the narrow sidebar a trailing glyph is truncated away before it can be
# read. State lives there; this script owns position and name only.
#
# The two shapes are textually identical, so "is this name mine or Eddy's?"
# cannot be read back off the label — it is remembered in $CACHE_DIR instead:
# each pass records what it wrote plus the deliberate name it honored. A label
# that no longer matches what we last wrote was set by a human or by
# herdr-goals, so its name is deliberate and gets frozen; a label still
# matching ours is ours, and a derived title is re-derived every pass so it
# keeps tracking.
#
# numbered_tab.sh (prefix+N) is purely positional, so every tab gets stamped
# every pass — none are left on a stale digit, and the row always reads a
# contiguous 1..N.
#
# Sessions: Herdr runs one server per window, each with its own socket under
# ~/.config/herdr/sessions/<name>/herdr.sock, and there is no global one — the
# bare default socket is usually dead. Inside a Herdr pane $HERDR_SOCKET_PATH
# names this window's server and only it is stamped. Outside one (the launchd
# agent), every live session socket is discovered and stamped each pass, with a
# cache per session, because tab ids repeat across windows.
#
# Run once for a snapshot, or `--watch [interval]` to keep positions and agent
# titles current as tabs are opened, closed, moved, and renamed.
set -uo pipefail

command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }

# Every socket call goes through an alarm: with no controlling terminal a
# `herdr` call against a socket nothing is serving can block forever, and one
# such call wedged the whole watcher after a single pass. perl's alarm is the
# only timeout on a stock macOS — coreutils' timeout(1) is not installed.
hcall() { perl -e 'alarm shift; exec @ARGV' 5 "$@"; }

# Glyphs earlier versions stamped at the end of a label. Kept only so those
# labels can be stripped clean on the first pass after this change.
LEGACY_GLYPHS="⣾⣽⣻⢿⡿⣟⣯⣷○✓▲·"
TITLE_MAX=22
# Generic app titles a CLI shows before it has set a real topic — not a name.
GENERIC_TITLES="claude code|codex|opencode|antigravity|gemini"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/herdr-tab-status"
SESSION_DIR="$HOME/.config/herdr/sessions"
mkdir -p "$CACHE_DIR"

# Stamp one server. $1 is its socket; a dead or half-open socket returns 1 so a
# caller sweeping every session can skip it without dying.
stamp_session() {
  local sock="$1" name cache tabs panes tmp
  # Exported *local*, so the sweep does not leak the last socket it tried back
  # into stamp_all: a plain export left HERDR_SOCKET_PATH set after pass one,
  # which pinned every later pass to a single dead session.
  local HERDR_SOCKET_PATH="$sock"
  export HERDR_SOCKET_PATH

  # Liveness first: a dead socket must not leave a cache file behind, or every
  # window ever opened accumulates one.
  tabs=$(hcall herdr tab list 2>/dev/null) || return 1
  panes=$(hcall herdr pane list 2>/dev/null) || return 1
  # `herdr status server` exits 0 even when nothing answers the socket, so
  # well-formed output is the only trustworthy liveness test.
  case "$tabs$panes" in '{'*) ;; *) return 1 ;; esac

  # Test for the session prefix before stripping the suffix: stripping first
  # left the bare ~/.config/herdr socket named for its whole directory path.
  case "$sock" in
    "$SESSION_DIR"/*) name=${sock#"$SESSION_DIR"/}; name=${name%/herdr.sock} ;;
    *) name=default ;;
  esac
  cache="$CACHE_DIR/$name"
  : >>"$cache"

  tmp="$cache.$$"
  : >"$tmp"
  # Position, not `.number`: Herdr's tab bar is contiguous, so the Nth tab is
  # what prefix+N selects even when its internal number is sparse.
  jq -n -r --argjson tabs "$tabs" --argjson panes "$panes" '
    ($panes.result.panes | map({(.tab_id): .}) | add // {}) as $panebytab |
    $tabs.result.tabs | to_entries[] |
    (.value.tab_id) as $tab_id |
    ($panebytab[$tab_id] // {}) as $pane |
    [
      $tab_id,
      (.key + 1 | tostring),
      .value.label,
      ($pane.agent // ""),
      ($pane.terminal_title_stripped // ""),
      (($pane.foreground_cwd // $pane.cwd // "") | split("/") | last)
    ] | join("")
  ' |
    # Unit separator, not a tab: bash's `read` treats IFS=$'\t' as
    # whitespace and silently collapses a run of empty fields (an empty
    # agent next to a real title shifted every later column left by one).
    while IFS=$'\x1f' read -r id position label agent title repo; do
      # What this script wrote for this tab last pass, and the deliberate name
      # it honored then. Empty on a tab we have never seen.
      prev=$(grep -m1 -E "^${id}"$'\x1f' "$cache" 2>/dev/null || true)
      prev_written=''
      prev_name=''
      if [ -n "$prev" ]; then
        prev=${prev#*$'\x1f'}
        prev_written=${prev%%$'\x1f'*}
        prev_name=${prev#*$'\x1f'}
      fi

      if [ -n "$prev" ] && [ "$label" = "$prev_written" ]; then
        # Untouched since our last pass: the name is ours to re-derive.
        name="$prev_name"
      else
        # New to us, or renamed behind our back — whatever is left after the
        # stamp is a deliberate name.
        name=$(printf '%s' "$label" | sed -E "s/^\[?[0-9]+\]?//; s/^\[[^]]*\]//; s/^ +//; s/[[:space:]]*[${LEGACY_GLYPHS}]?[[:space:]]*$//")
        # An all-digit remainder is a stale position, not a deliberate name.
        case "$name" in ''|*[!0-9]*) ;; *) name='' ;; esac
        # A remainder identical to the repo is an auto name, not a deliberate
        # goal label — re-derive it instead of freezing it in.
        [ "$name" = "$repo" ] && name=''
      fi

      derived=''
      if [ -z "$name" ] && [ -n "$agent" ]; then
        clean_title=$(printf '%s' "$title" | sed -E 's/^[^[:alnum:]]+[[:space:]]*//')
        # `[[ =~ ]]`, not `case`: case alternation must be literal in the
        # source, so the `|`s in $GENERIC_TITLES arrived as one long literal
        # and matched nothing — every generic title leaked through as a name.
        shopt -s nocasematch
        if [[ "$clean_title" =~ ^($GENERIC_TITLES)$ ]]; then clean_title=''; fi
        shopt -u nocasematch
        if [ -n "$clean_title" ]; then
          derived="$clean_title"
          [ "${#clean_title}" -gt "$TITLE_MAX" ] && derived="${clean_title:0:$TITLE_MAX}…"
        fi
      fi

      if [ -n "$name" ]; then
        want="${position} ${name}"
      elif [ -n "$derived" ]; then
        want="${position} ${derived}"
      elif [ -n "$repo" ]; then
        # cwd can lag by one pass right after tab creation; don't stamp a
        # dangling trailing space while it's still empty.
        want="${position} ${repo}"
      else
        want="${position}"
      fi

      [ "$label" = "$want" ] || hcall herdr tab rename "$id" "$want" >/dev/null 2>&1
      printf '%s\x1f%s\x1f%s\n' "$id" "$want" "$name" >>"$tmp"
    done
  # Rebuilt from the live tab list, so closed tabs drop out on their own.
  mv "$tmp" "$cache"
}

# One pass over everything this invocation is responsible for. Returns 1 only
# when nothing at all could be stamped, so a one-shot run can report it.
stamp_all() {
  local sock stamped=1
  if [ -n "${HERDR_SOCKET_PATH:-}" ]; then
    stamp_session "$HERDR_SOCKET_PATH" && stamped=0
  else
    # Session sockets only. The bare ~/.config/herdr/herdr.sock is never
    # served by a window, and calling it without a TTY hangs instead of
    # refusing — that single call is what froze the watcher.
    for sock in "$SESSION_DIR"/*/herdr.sock; do
      [ -S "$sock" ] || continue
      stamp_session "$sock" && stamped=0
    done
  fi
  return $stamped
}

if [ "${1:-}" = "--watch" ]; then
  # Watch mode outlives every server: launchd starts it at login, long before
  # the day's first `herdr`, and it must survive each window closing. A pass
  # with nothing live is skipped, never fatal.
  interval="${2:-0.5}"
  while true; do
    stamp_all
    sleep "$interval"
  done
else
  stamp_all || { echo "no live herdr session found" >&2; exit 1; }
fi
