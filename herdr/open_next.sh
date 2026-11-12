#!/bin/bash
# herdr-open-next: the master opens the tabs a fill queued for it (master plan B6).
# goal_done.sh (B7: always, master live or not) writes each tab it would open to NEXT_QUEUE
# (from-name, cwd, label, boot, launch) instead of opening it; the master runs this
# on a `landed` wake, in its own session, then subscribes `notify_when_idle` to each
# name printed. A label already open, or queued twice, opens once.
#
#   herdr-open-next            open every queued tab; prints `opened NAME — BOOT`
#   herdr-open-next --dry-run  list them, open nothing, keep the queue
set -euo pipefail
queue="${AGENT_STATE_DIR:-$HOME/.local/state/agents}/next.tsv"
dry=0; [ "${1:-}" = "--dry-run" ] && dry=1
[ -s "$queue" ] || { echo "nothing queued"; exit 0; }
if [ "$dry" = 1 ]; then
  cut -f3,4 "$queue" | sed 's/^/would open: /'
  exit 0
fi
# Take the queue whole: a fill landing meanwhile appends to a fresh file.
work="${queue}.$$"
mv "$queue" "$work"
open_labels=$(herdr tab list 2>/dev/null | jq -r '.result.tabs[]?.label' 2>/dev/null |
  sed -E 's/^\[?[0-9]+\]? *//' || true)
seen=""
left=0
while IFS=$'\t' read -r from cwd label boot launch; do
  [ -n "$label" ] || continue
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
done < "$work"
rm -f "$work"
exit "$left"
