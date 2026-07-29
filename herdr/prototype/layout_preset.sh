#!/bin/sh
set -eu

preset=${1:?expected a layout preset}
case "$preset" in
  tiled|main-horizontal|main-vertical|even-horizontal|even-vertical) ;;
  *) echo "layout-preset: unknown preset: $preset" >&2; exit 64 ;;
esac

herdr=${HERDR_BIN_PATH:-herdr}
socket=${HERDR_SOCKET_PATH:?layout-preset requires the Herdr socket}
pane=${HERDR_TARGET_PANE_ID:-${HERDR_PANE_ID:-}}
if [ -n "$pane" ]; then
  current=$("$herdr" pane current --pane "$pane")
else
  current=$("$herdr" pane current --current)
fi
tab=$(printf '%s\n' "$current" | jq -er '.result.pane.tab_id')
workspace=$(printf '%s\n' "$current" | jq -er '.result.pane.workspace_id')
focused_before=$("$herdr" pane list --workspace "$workspace" |
  jq -er '.result.panes[] | select(.focused).pane_id')

request() {
  request_id=$1
  payload=$2
  printf '%s\n' "$payload" | nc -U -w 2 "$socket" |
    jq -cer --arg id "$request_id" \
      'select(.id == $id and has("result") and (has("error") | not))'
}
export_root() {
  request_id="layout-preset-export-$$-$1"
  payload=$(jq -cn --arg id "$request_id" --arg tab "$tab" \
    '{id:$id,method:"layout.export",params:{tab_id:$tab}}')
  request "$request_id" "$payload" | jq -cer '.result.layout.root'
}
topology_signature() {
  jq -c '
    def topology:
      if .type == "pane" then {type,pane_id}
      else {type,direction,first:(.first|topology),second:(.second|topology)}
      end;
    topology
  '
}
apply_updates_guarded() {
  updates_path=$1
  expected_path=$2
  sequence=0
  while IFS= read -r update; do
    [ -n "$update" ] || continue
    sequence=$((sequence + 1))
    current=$(export_root "pre-$sequence")
    expected=$(cat "$expected_path")
    [ "$current" = "$expected" ] || return 2
    request_id="layout-preset-ratio-$$-$sequence"
    payload=$(printf '%s\n' "$update" | jq -c \
      --arg id "$request_id" --arg tab "$tab" \
      '{id:$id,method:"layout.set_split_ratio",
        params:{tab_id:$tab,path:.path,ratio:.ratio}}')
    request "$request_id" "$payload" >/dev/null || return 1
    if [ -n "${HERDR_LAYOUT_TEST_AFTER_UPDATE_HOOK:-}" ]; then
      "$HERDR_LAYOUT_TEST_AFTER_UPDATE_HOOK" "$tab" "$sequence"
    fi
    updated=$(export_root "post-$sequence")
    [ "$(printf '%s\n' "$updated" | topology_signature)" = "$topology_before" ] ||
      return 3
    printf '%s\n' "$updated" | jq -e \
      --argjson expected "$expected" --argjson update "$update" '
      def ratios($path):
        if .type == "split" then
          [{path:$path,ratio:.ratio}] +
          (.first | ratios($path + [false])) +
          (.second | ratios($path + [true]))
        else [] end;
      ($expected | ratios([])) as $before_ratios |
      (ratios([])) as $after_ratios |
      ($before_ratios | length) == ($after_ratios | length) and
      all($after_ratios[];
        . as $after |
        ($before_ratios[] | select(.path == $after.path).ratio) as $before |
        if $after.path == $update.path then
          (($after.ratio - $update.ratio) | fabs) < 0.000001
        else
          (($after.ratio - $before) | fabs) < 0.000001
        end)
    ' >/dev/null || return 3
    printf '%s\n' "$updated" >"$expected_path"
  done <"$updates_path"
}

before=$(export_root before)
compatibility=$(printf '%s\n' "$before" | jq -r --arg preset "$preset" '
  def all_dir($direction):
    if .type == "pane" then true
    else
      .type == "split" and .direction == $direction and
      (.first | all_dir($direction)) and
      (.second | all_dir($direction))
    end;
  if .type == "pane" or $preset == "tiled" then true
  elif $preset == "even-horizontal" then all_dir("right")
  elif $preset == "even-vertical" then all_dir("down")
  elif $preset == "main-horizontal" then
    .type == "split" and .direction == "down" and
    .first.type == "pane" and (.second | all_dir("right"))
  elif $preset == "main-vertical" then
    .type == "split" and .direction == "right" and
    .first.type == "pane" and (.second | all_dir("down"))
  else false
  end
')
[ "$compatibility" = true ] || {
  echo "layout-preset: $preset is unavailable for the current process-safe topology" >&2
  exit 4
}

temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/herdr-layout-preset.XXXXXX")
updates_file="$temporary_dir/updates.jsonl"
rollback_file="$temporary_dir/rollback.jsonl"
expected_file="$temporary_dir/expected.json"
trap 'rm -f -- "$updates_file" "$rollback_file" "$expected_file"; rmdir "$temporary_dir" 2>/dev/null || true' EXIT HUP INT TERM

topology_before=$(printf '%s\n' "$before" | topology_signature)
printf '%s\n' "$before" >"$expected_file"

printf '%s\n' "$before" | jq -c '
  def ratios($path):
    if .type == "split" then
      [{path:$path,ratio:.ratio}] +
      (.first | ratios($path + [false])) +
      (.second | ratios($path + [true]))
    else [] end;
  ratios([])[]
' >"$rollback_file"

printf '%s\n' "$before" | jq -c --arg preset "$preset" '
  def leaves:
    if .type == "pane" then 1
    else ((.first | leaves) + (.second | leaves)) end;
  def equal_updates($path):
    if .type == "split" then
      (.first | leaves) as $a |
      (.second | leaves) as $b |
      [{path:$path,ratio:($a / ($a + $b))}] +
      (.first | equal_updates($path + [false])) +
      (.second | equal_updates($path + [true]))
    else [] end;
  if .type == "pane" then []
  elif $preset == "main-horizontal" or $preset == "main-vertical" then
    [{path:[],ratio:0.62}] + (.second | equal_updates([true]))
  else equal_updates([])
  end | .[]
' >"$updates_file"

if ! apply_updates_guarded "$updates_file" "$expected_file"; then
  current=$(export_root failure)
  if [ "$current" = "$(cat "$expected_file")" ]; then
    apply_updates_guarded "$rollback_file" "$expected_file" >/dev/null 2>&1 || true
  fi
  echo "layout-preset: concurrent layout change or ratio update failure; rollback attempted only while ownership was provable" >&2
  exit 5
fi

after=$(export_root after)
topology_after=$(printf '%s\n' "$after" | topology_signature)
focused_after=$("$herdr" pane list --workspace "$workspace" |
  jq -er '.result.panes[] | select(.focused).pane_id')
updates_json=$(jq -sc '.' "$updates_file")
ratios_match=$(printf '%s\n' "$after" | jq -r --argjson updates "$updates_json" '
  def node_at($path):
    reduce $path[] as $side (.;
      if $side then .second else .first end);
  all($updates[];
    ((node_at(.path).ratio - .ratio) | fabs) < 0.000001)
')

if [ "$topology_after" != "$topology_before" ] ||
   [ "$focused_after" != "$focused_before" ] ||
   [ "$ratios_match" != true ]; then
  current=$(export_root postcondition)
  if [ "$current" = "$(cat "$expected_file")" ]; then
    apply_updates_guarded "$rollback_file" "$expected_file" >/dev/null 2>&1 || true
  fi
  echo "layout-preset: topology, focus, or requested ratio changed; rollback attempted only while ownership was provable" >&2
  exit 5
fi

update_count=$(sed '/^$/d' "$updates_file" | wc -l | tr -d ' ')
jq -cn --arg preset "$preset" --arg tab "$tab" \
  --arg focus "$focused_after" --argjson updates "$update_count" \
  '{result:{
    preset:$preset,tab_id:$tab,updated_splits:$updates,
    topology_preserved:true,processes_preserved:true,focus_preserved:true,
    focused_pane_id:$focus
  }}'
