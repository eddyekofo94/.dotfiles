#!/bin/bash
# open-next: the master opens the tabs a fill queued for it (master plan B6).
# goal_done.sh (B7: always, master live or not) writes each tab it would open to NEXT_QUEUE
# (from-name, cwd, label, boot, launch) instead of opening it; the master runs this
# on a `landed` wake, in its own session, then subscribes `notify_when_idle` to each
# name printed. A label already open, or queued twice, opens once; a row whose
# checkout is gone is dropped.
#
#   open-next            open every queued tab; prints `opened NAME — BOOT`
#   open-next --dry-run  list them, open nothing, keep the queue
#   open-next --drop LABEL [--dry-run]
#                        drop LABEL's rows and ask its repository to remove the
#                        checkout (`tools/session_worktree.py remove`, which keeps
#                        unlanded or dirty work); prints `dropped LABEL`, and
#                        `kept LABEL — WHY` when the remove refuses
set -euo pipefail
queue="${AGENT_STATE_DIR:-$HOME/.local/state/agents}/next.tsv"
# BS-IOS-TASK-1754: the master says "not this lane now" with one command.
if [ "${1:-}" = "--drop" ]; then
  shift
  drop_dry=0; drop=""; extra=0
  for arg in "$@"; do
    case "$arg" in
      --dry-run) drop_dry=1 ;;
      *) if [ -z "$drop" ]; then drop="$arg"; else extra=1; fi ;;
    esac
  done
  if [ -z "$drop" ] || [ "$extra" = 1 ]; then
    echo "usage: open-next --drop LABEL [--dry-run]" >&2; exit 2
  fi
  drop="${drop#▸ }"
  [ -s "$queue" ] || { echo "nothing queued for ${drop}"; exit 0; }
  # awk with a one-character FS keeps empty fields, unlike bash IFS.
  if ! awk -F'\t' -v l="$drop" \
       '$3 == l || $3 == "▸ " l { found = 1 } END { exit !found }' "$queue"; then
    echo "nothing queued for ${drop}"; exit 0
  fi
  if [ "$drop_dry" = 1 ]; then echo "would drop ${drop}"; exit 0; fi
  work="${queue}.$$"
  mv "$queue" "$work"
  # Kept rows go back by append, never overwrite, so a fill landing meanwhile stays.
  awk -F'\t' -v l="$drop" '!($3 == l || $3 == "▸ " l)' "$work" >> "$queue"
  awk -F'\t' -v l="$drop" '$3 == l || $3 == "▸ " l { print $2 }' "$work" | sort -u |
  while IFS= read -r cwd; do
    [ -n "$cwd" ] && [ -d "$cwd" ] || continue
    # Only a linked worktree is a checkout to remove; a shared tree stays.
    gitdir=$(git -C "$cwd" rev-parse --path-format=absolute --git-dir 2>/dev/null) || continue
    common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue
    [ "$gitdir" != "$common" ] || continue
    root=$(dirname "$common")
    [ -f "$root/tools/session_worktree.py" ] || { echo "kept ${drop} — ${root} has no tools/session_worktree.py"; continue; }
    if ! why=$(cd "$root" && python3 tools/session_worktree.py remove "$(basename "$cwd")" 2>&1); then
      echo "kept ${drop} — $(printf '%s' "$why" | tail -1)"
    fi
  done
  rm -f "$work"
  echo "dropped ${drop}"
  exit 0
fi
dry=0; [ "${1:-}" = "--dry-run" ] && dry=1
[ -s "$queue" ] || { echo "nothing queued"; exit 0; }
if [ "$dry" = 1 ]; then
  tr '\t' '\037' < "$queue" | while IFS=$'\037' read -r _ cwd label boot _; do
    if [ -n "$cwd" ] && [ -d "$cwd" ]; then echo "would open: ${label}"$'\t'"${boot}"
    else echo "would drop: ${label#▸ } — checkout gone"; fi
  done
  exit 0
fi
# Take the queue whole: a fill landing meanwhile appends to a fresh file.
work="${queue}.$$"
mv "$queue" "$work"
# BS-IOS-TASK-1738: the queue is taken, so the next fill's push (keyed on the queue's
# content) wakes the master again even when it queues the same row.
rm -f "$(dirname "$queue")/pushed/fill"
open_labels=$(herdr tab list 2>/dev/null | jq -r '.result.tabs[]?.label' 2>/dev/null |
  sed -E 's/^\[?[0-9]+\]? *//' || true)
seen=""
left=0
# A tab is IFS whitespace, so an empty field would collapse and shift the rest; read
# on the unit separator, which keeps it (BS-IOS-TASK-1738 H12).
while IFS=$'\037' read -r from cwd label boot launch; do
  [ -n "$label" ] || continue
  # BS-IOS-TASK-1738 D6: a checkout swept since the fill queued it never opens, and
  # is not re-queued; an empty cwd is gone too.
  if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
    echo "dropped ${label#▸ } — checkout gone"
    continue
  fi
  if printf '%s\n' "$open_labels" | grep -qxF -- "$label" || printf '%s' "$seen" | grep -qxF -- "$label"; then
    echo "skipped ${label#▸ } — already open"
    continue
  fi
  seen="${seen}${label}"$'\n'
  if pane=$(herdr tab create --cwd "$cwd" --label "$label" --no-focus | jq -r '.result.root_pane.pane_id') &&
     [ -n "$pane" ] && [ "$pane" != null ] && herdr pane run "$pane" "$launch"; then
    name=$(printf '%s' "$launch" | sed -nE 's/.*--name ([^ ]+).*/\1/p')
    echo "opened ${name:-${label#▸ }} — ${boot} (after ${from})"
  else
    printf '%s\t%s\t%s\t%s\t%s\n' "$from" "$cwd" "$label" "$boot" "$launch" >> "$queue"
    echo "could not open ${label#▸ } — left queued" >&2
    left=1
  fi
done < <(tr '\t' '\037' < "$work")
rm -f "$work"
exit "$left"
