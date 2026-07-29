#!/bin/sh
set -eu

prototype=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
picker=${HERDR_MANAGE_PICKER:-fzf}
pane=${HERDR_TARGET_PANE_ID:-${HERDR_PANE_ID:-}}
[ -n "$pane" ] || pane=$("$prototype/focused_pane.sh")

command -v jq >/dev/null 2>&1 || {
  echo "manage-objects: jq is required" >&2
  exit 69
}
command -v "$picker" >/dev/null 2>&1 || {
  echo "manage-objects: picker is unavailable: $picker" >&2
  exit 69
}

inventory() {
  workspaces=$("$herdr" workspace list)
  tabs=$("$herdr" tab list)
  panes=$("$herdr" pane list)
  jq -cn --argjson workspaces "$workspaces" --argjson tabs "$tabs" \
    --argjson panes "$panes" '
    {
      workspaces: $workspaces.result.workspaces,
      tabs: $tabs.result.tabs,
      panes: $panes.result.panes
    } | . as $inventory |
    select(
      (.workspaces | type == "array") and
      (.tabs | type == "array") and
      (.panes | type == "array") and
      all(.workspaces[];
        (.workspace_id | type == "string" and length > 0)) and
      all(.tabs[];
        (.tab_id | type == "string" and length > 0) and
        (.workspace_id | type == "string" and length > 0)) and
      all(.panes[];
        (.pane_id | type == "string" and length > 0) and
        (.tab_id | type == "string" and length > 0) and
        (.workspace_id | type == "string" and length > 0) and
        (.terminal_id | type == "string" and length > 0)) and
      ([.workspaces[].workspace_id] | unique | length) ==
        (.workspaces | length) and
      ([.tabs[].tab_id] | unique | length) == (.tabs | length) and
      ([.panes[].pane_id] | unique | length) == (.panes | length) and
      ([.panes[].terminal_id] | unique | length) == (.panes | length) and
      all(.tabs[];
        .workspace_id as $workspace_id |
        any($inventory.workspaces[];
          .workspace_id == $workspace_id)) and
      all(.panes[];
        .tab_id as $tab_id |
        .workspace_id as $workspace_id |
        any($inventory.tabs[];
          .tab_id == $tab_id and
          .workspace_id == $workspace_id))
    )
  '
}

target_snapshot() {
  kind=$1
  id=$2
  printf '%s\n' "$3" | jq -cer --arg kind "$kind" --arg id "$id" '
    if $kind == "pane" then
      {
        kind: $kind,
        object: (
          [.panes[] | select(.pane_id == $id) |
            {pane_id, terminal_id, tab_id, workspace_id}][0]
        )
      } | select(.object != null)
    elif $kind == "tab" then
      {
        kind: $kind,
        object: (
          [.tabs[] | select(.tab_id == $id) |
            {tab_id, workspace_id}][0]
        ),
        panes: (
          [.panes[] | select(.tab_id == $id) |
            {pane_id, terminal_id, tab_id, workspace_id}] |
          sort_by(.pane_id)
        )
      } | select(.object != null)
    elif $kind == "workspace" then
      {
        kind: $kind,
        object: (
          [.workspaces[] | select(.workspace_id == $id) |
            {workspace_id}][0]
        ),
        tabs: (
          [.tabs[] | select(.workspace_id == $id) |
            {tab_id, workspace_id}] |
          sort_by(.tab_id)
        ),
        panes: (
          [.panes[] | select(.workspace_id == $id) |
            {pane_id, terminal_id, tab_id, workspace_id}] |
          sort_by(.pane_id)
        )
      } | select(.object != null)
    else
      empty
    end
  '
}

before=$(inventory) || {
  echo "manage-objects: malformed Herdr inventory" >&2
  exit 4
}
current=$("$herdr" pane current --pane "$pane")
current_pane=$(printf '%s\n' "$current" | jq -er '.result.pane.pane_id')
current_tab=$(printf '%s\n' "$current" | jq -er '.result.pane.tab_id')
current_workspace=$(printf '%s\n' "$current" | jq -er '.result.pane.workspace_id')

candidates=$(printf '%s\n' "$before" | jq -r \
  --arg current_pane "$current_pane" --arg current_tab "$current_tab" \
  --arg current_workspace "$current_workspace" '
  def clean:
    (. // "") | tostring | gsub("[\u0000-\u001F\u007F]"; " ");
  def pane_snapshot($pane):
    {
      kind: "pane",
      object: ($pane | {pane_id, terminal_id, tab_id, workspace_id})
    } | @base64;
  def tab_snapshot($tab):
    {
      kind: "tab",
      object: ($tab | {tab_id, workspace_id}),
      panes: (
        [.panes[] | select(.tab_id == $tab.tab_id) |
          {pane_id, terminal_id, tab_id, workspace_id}] |
        sort_by(.pane_id)
      )
    } | @base64;
  def workspace_snapshot($workspace):
    {
      kind: "workspace",
      object: ($workspace | {workspace_id}),
      tabs: (
        [.tabs[] | select(.workspace_id == $workspace.workspace_id) |
          {tab_id, workspace_id}] |
        sort_by(.tab_id)
      ),
      panes: (
        [.panes[] |
          select(.workspace_id == $workspace.workspace_id) |
          {pane_id, terminal_id, tab_id, workspace_id}] |
        sort_by(.pane_id)
      )
    } | @base64;
  . as $inventory |
  (
    $inventory.panes[] as $pane |
    [
      "pane",
      $pane.pane_id,
      ($inventory | pane_snapshot($pane)),
      (
        ($pane.label // $pane.terminal_title_stripped //
          $pane.foreground_cwd // $pane.cwd // "unnamed pane") | clean
      ),
      (
        "workspace=" + $pane.workspace_id + " tab=" + $pane.tab_id +
        " terminal=" + $pane.terminal_id +
        (if $pane.pane_id == $current_pane then " CURRENT" else "" end)
      )
    ]
  ),
  (
    $inventory.tabs[] as $tab |
    [
      "tab",
      $tab.tab_id,
      ($inventory | tab_snapshot($tab)),
      (($tab.label // "unnamed tab") | clean),
      (
        "workspace=" + $tab.workspace_id +
        " panes=" +
        (([$inventory.panes[] | select(.tab_id == $tab.tab_id)] | length) |
          tostring) +
        (if $tab.tab_id == $current_tab then " CURRENT" else "" end)
      )
    ]
  ),
  (
    $inventory.workspaces[] as $workspace |
    [
      "workspace",
      $workspace.workspace_id,
      ($inventory | workspace_snapshot($workspace)),
      (($workspace.label // "unnamed workspace") | clean),
      (
        "tabs=" +
        (([$inventory.tabs[] |
          select(.workspace_id == $workspace.workspace_id)] | length) |
          tostring) +
        " panes=" +
        (([$inventory.panes[] |
          select(.workspace_id == $workspace.workspace_id)] | length) |
          tostring) +
        (if $workspace.workspace_id == $current_workspace
          then " CURRENT" else "" end)
      )
    ]
  ) |
  @tsv
')

[ -n "$candidates" ] || {
  echo "manage-objects: no Herdr objects are available" >&2
  exit 4
}

tab=$(printf '\t')
set +e
selection=$(printf '%s\n' "$candidates" |
  FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE= "$picker" \
  --delimiter="$tab" --with-nth=1,2,4,5 \
  --header='Delete one Herdr object; Enter selects, Escape cancels' \
  --prompt='Delete> ' --layout=reverse --border \
  --preview-window='down,5,wrap' \
  --preview='printf "type: %s\nid: %s\nlabel: %s\n%s\n" {1} {2} {4} {5}')
picker_status=$?
set -e
case "$picker_status" in
  0) ;;
  1|130) exit 0 ;;
  *) echo "manage-objects: picker failed" >&2; exit "$picker_status" ;;
esac
[ -n "$selection" ] || exit 0

old_ifs=$IFS
IFS=$tab
read -r kind id selected_snapshot label summary <<EOF
$selection
EOF
IFS=$old_ifs
case "$kind" in
  pane|tab|workspace) ;;
  *) echo "manage-objects: malformed picker target" >&2; exit 4 ;;
esac
[ -n "$id" ] && [ -n "$selected_snapshot" ] || {
  echo "manage-objects: incomplete picker target" >&2
  exit 4
}

printf 'Delete %s %s (%s)? [y/N] ' "$kind" "$id" "$label" >&2
IFS= read -r answer || answer=
case "$answer" in
  y|Y|yes|YES|Yes) ;;
  *) echo "manage-objects: cancelled" >&2; exit 0 ;;
esac

fresh=$(inventory) || {
  echo "manage-objects: malformed fresh Herdr inventory" >&2
  exit 4
}
fresh_snapshot=$(target_snapshot "$kind" "$id" "$fresh") || {
  echo "manage-objects: selected $kind is stale" >&2
  exit 4
}
fresh_encoded=$(printf '%s' "$fresh_snapshot" | base64)
[ "$fresh_encoded" = "$selected_snapshot" ] || {
  echo "manage-objects: selected $kind changed after selection" >&2
  exit 4
}

case "$kind" in
  pane) "$herdr" pane close "$id" >/dev/null ;;
  tab) "$herdr" tab close "$id" >/dev/null ;;
  workspace) "$herdr" workspace close "$id" >/dev/null ;;
esac
printf 'manage-objects: deleted %s %s\n' "$kind" "$id"
