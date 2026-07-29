#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
picker=${HERDR_PANE_TRANSFER_PICKER:-fzf}
pane=${HERDR_TARGET_PANE_ID:-${HERDR_PANE_ID:-}}
[ -n "$pane" ] || pane=$("$prototype/focused_pane.sh")

command -v jq >/dev/null 2>&1 || {
  echo "pane-transfer: jq is required" >&2
  exit 69
}
command -v "$picker" >/dev/null 2>&1 || {
  echo "pane-transfer: picker is unavailable: $picker" >&2
  exit 69
}

current=$("$herdr" pane current --pane "$pane")
workspace=$(printf '%s\n' "$current" | jq -er '
  .result.pane |
  select(.pane_id | type == "string" and length > 0) |
  select(.workspace_id | type == "string" and length > 0) |
  .workspace_id
')
panes=$("$herdr" pane list)
printf '%s\n' "$panes" | jq -e --arg pane "$pane" '
  .result.panes | type == "array" and
  all(.[];
    (.pane_id | type == "string" and length > 0) and
    (.tab_id | type == "string" and length > 0) and
    (.workspace_id | type == "string" and length > 0) and
    (.terminal_id | type == "string" and length > 0)
  ) and
  ([.[] | select(.pane_id == $pane)] | length) == 1
' >/dev/null

candidates=$(printf '%s\n' "$panes" | jq -r --arg pane "$pane" '
  .result.panes[] |
  select(.pane_id != $pane) |
  [
    "send", $pane, .pane_id,
    ("send focused pane -> " + .pane_id + "  " +
      (.terminal_title_stripped // .foreground_cwd // .cwd // ""))
  ],
  [
    "receive", .pane_id, $pane,
    ("receive " + .pane_id + " -> focused pane  " +
      (.terminal_title_stripped // .foreground_cwd // .cwd // ""))
  ] |
  @tsv
')

if [ -z "$candidates" ]; then
  echo "pane-transfer: no other panes are available in this session" >&2
  exit 4
fi

set +e
selection=$(printf '%s\n' "$candidates" |
  FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= "$picker" \
  --delimiter="$(printf '\t')" --with-nth=4.. \
  --header='Pane transfer: send focused pane or receive beside it' \
  --prompt='Transfer> ' --layout=reverse --border)
picker_status=$?
set -e
case "$picker_status" in
  0) ;;
  1|130) exit 0 ;;
  *) echo "pane-transfer: picker failed" >&2; exit "$picker_status" ;;
esac
[ -n "$selection" ] || exit 0

tab=$(printf '\t')
old_ifs=$IFS
IFS=$tab
read -r mode source target display <<EOF
$selection
EOF
IFS=$old_ifs

case "$mode" in
  send)
    [ "$source" = "$pane" ] || {
      echo "pane-transfer: stale send source" >&2
      exit 4
    }
    ;;
  receive)
    [ "$target" = "$pane" ] || {
      echo "pane-transfer: stale receive target" >&2
      exit 4
    }
    ;;
  *)
    echo "pane-transfer: malformed picker selection" >&2
    exit 4
    ;;
esac
[ -n "$source" ] && [ -n "$target" ] && [ "$source" != "$target" ] || {
  echo "pane-transfer: self or empty target rejected" >&2
  exit 4
}

fresh=$("$herdr" pane list)
printf '%s\n' "$fresh" | jq -e --arg source "$source" --arg target "$target" '
  .result.panes | type == "array" and
  ([.[] | select(.pane_id == $source)] | length) == 1 and
  ([.[] | select(.pane_id == $target)] | length) == 1
' >/dev/null || {
  echo "pane-transfer: selected pane is stale" >&2
  exit 4
}
source_before=$(printf '%s\n' "$fresh" | jq -cer --arg source "$source" '
  .result.panes[] | select(.pane_id == $source) |
  {pane_id,terminal_id,cwd,foreground_cwd,workspace_id,tab_id}
')
source_anchor_before=$(printf '%s\n' "$fresh" | jq -c \
  --arg source "$source" \
  --arg source_tab "$(printf '%s\n' "$source_before" | jq -r '.tab_id')" '
  [.result.panes[] |
    select(.tab_id == $source_tab and .pane_id != $source) |
    {pane_id,terminal_id}][0] // null
')
source_anchor=$(printf '%s\n' "$source_anchor_before" | jq -r '.pane_id // empty')
source_guard=
if [ -z "$source_anchor" ]; then
  source_guard=$("$herdr" pane split "$source" --direction down --ratio 0.5 \
    --no-focus | jq -er '.result.pane.pane_id')
  source_anchor_before=$("$herdr" pane get "$source_guard" |
    jq -c '.result.pane | {pane_id,terminal_id}')
  source_anchor=$source_guard
fi
target_tab=$(printf '%s\n' "$fresh" | jq -er --arg target "$target" '
  .result.panes[] | select(.pane_id == $target) | .tab_id
')
target_workspace=$(printf '%s\n' "$fresh" | jq -er --arg target "$target" '
  .result.panes[] | select(.pane_id == $target) | .workspace_id
')

move_status=0
if [ -n "${HERDR_TRANSFER_TEST_MOVE_STATUS:-}" ]; then
  move_status=$HERDR_TRANSFER_TEST_MOVE_STATUS
else
  "$herdr" pane move "$source" --tab "$target_tab" --split down \
    --target-pane "$target" --focus >/dev/null || move_status=$?
fi

after=$("$herdr" pane list)
postcondition_ok=0
if [ "$move_status" -eq 0 ] && printf '%s\n' "$after" | jq -e \
  --arg target_tab "$target_tab" --arg target_workspace "$target_workspace" \
  --argjson before "$source_before" '
  .result.panes | type == "array" and
  ([.[] | select(
    .tab_id == $target_tab and
    .workspace_id == $target_workspace and
    .terminal_id == $before.terminal_id and
    .cwd == $before.cwd and
    .foreground_cwd == $before.foreground_cwd and
    .focused == true
  )] | length) == 1
' >/dev/null; then
  postcondition_ok=1
fi
if [ "${HERDR_TRANSFER_TEST_AFTER_MOVE_FAIL:-0}" = 1 ]; then
  postcondition_ok=0
fi
if [ "$postcondition_ok" -ne 1 ]; then
  current_state=$(printf '%s\n' "$after" | jq -c --argjson before "$source_before" '
    [.result.panes[] | select(.terminal_id == $before.terminal_id)][0] // null
  ')
  if printf '%s\n' "$current_state" | jq -e --argjson before "$source_before" '
    . != null and .tab_id == $before.tab_id and
    .workspace_id == $before.workspace_id
  ' >/dev/null; then
    [ -z "$source_guard" ] || "$herdr" pane close "$source_guard" >/dev/null
    echo "pane-transfer: move failed before source placement changed" >&2
    exit 5
  fi
  fresh_rollback=$("$herdr" pane list)
  moved=$(printf '%s\n' "$fresh_rollback" | jq -r \
    --argjson before "$source_before" '
    [.result.panes[] | select(.terminal_id == $before.terminal_id).pane_id][0] //
    empty
  ')
  rollback_target=$(printf '%s\n' "$fresh_rollback" | jq -r \
    --argjson anchor "$source_anchor_before" \
    --argjson before "$source_before" '
    [.result.panes[] | select(
      .terminal_id == $anchor.terminal_id and .tab_id == $before.tab_id
    ).pane_id][0] // empty
  ')
  [ -n "$moved" ] && [ -n "$rollback_target" ] && [ "$moved" != "$rollback_target" ] && {
    "$herdr" pane move "$moved" --tab \
      "$(printf '%s\n' "$source_before" | jq -r '.tab_id')" --split down \
      --target-pane "$rollback_target" --focus >/dev/null 2>&1 || true
  }
  [ -z "$source_guard" ] || "$herdr" pane close "$source_guard" >/dev/null 2>&1 || true
  restored=$("$herdr" pane list)
  printf '%s\n' "$restored" | jq -e --argjson before "$source_before" '
    any(.result.panes[];
      .terminal_id == $before.terminal_id and
      .workspace_id == $before.workspace_id and
      .tab_id == $before.tab_id and
      .cwd == $before.cwd and .foreground_cwd == $before.foreground_cwd)
  ' >/dev/null || {
    echo "pane-transfer: move postcondition failed and rollback was incomplete" >&2
    exit 6
  }
  echo "pane-transfer: stale move rejected; source terminal restored" >&2
  exit 5
fi
[ -z "$source_guard" ] || "$herdr" pane close "$source_guard" >/dev/null

printf '%s\n' "$after" | jq -c \
  --arg mode "$mode" --arg source "$source" --arg target "$target" \
  --arg target_tab "$target_tab" --arg target_workspace "$target_workspace" \
  --argjson before "$source_before" '
  .result.panes[] | select(
    .terminal_id == $before.terminal_id and .tab_id == $target_tab
  ) |
  {result:{
    mode:$mode,source:$source,target:$target,target_tab:$target_tab,
    source_workspace:$before.workspace_id,target_workspace:$target_workspace,
    cross_workspace:($before.workspace_id != $target_workspace),
    pane_id_before:$before.pane_id,pane_id_after:.pane_id,
    pane_id_preserved:(.pane_id == $before.pane_id),
    terminal_id:.terminal_id,cwd:.cwd,foreground_cwd:.foreground_cwd,
    focused:.focused,process_preserving:(.terminal_id == $before.terminal_id)
  }}
'
