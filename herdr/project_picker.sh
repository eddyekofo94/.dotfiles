#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
herdr=${HERDR_BIN_PATH:-herdr}
session=${HERDR_PROJECT_SESSION:-${HERDR_SESSION:-}}
max_depth=${HERDR_PROJECT_MAX_DEPTH:-10}
scanner=${HERDR_PROJECT_SCANNER:-auto}
list_only=0
lock_file=
lock_acquired=0

case "${1:-}" in
  "")
    ;;
  --list)
    list_only=1
    ;;
  *)
    echo "usage: project_picker.sh [--list]" >&2
    exit 64
    ;;
esac

case "$session" in
  ""|*[!A-Za-z0-9._-]*)
    if [ "$list_only" -eq 0 ]; then
      echo "project picker requires a valid Herdr session identity" >&2
      exit 2
    fi
    ;;
esac
case "$max_depth" in
  ""|*[!0-9]*|0)
    echo "HERDR_PROJECT_MAX_DEPTH must be a positive integer" >&2
    exit 64
    ;;
esac
case "$scanner" in
  auto|fd|find)
    ;;
  *)
    echo "HERDR_PROJECT_SCANNER must be auto, fd, or find" >&2
    exit 64
    ;;
esac

for dependency in find git jq; do
  command -v "$dependency" >/dev/null 2>&1 || {
    echo "project picker requires $dependency" >&2
    exit 127
  }
done

runtime_base=${TMPDIR:-/tmp}
work_dir=$(mktemp -d "$runtime_base/herdr-project-picker.XXXXXX")
cleanup() {
  status=$?
  trap - EXIT HUP INT TERM
  if [ "$lock_acquired" -eq 1 ]; then
    if [ -L "$lock_file" ] &&
        [ "$(readlink "$lock_file" 2>/dev/null || true)" = "$$" ]
    then
      rm -f -- "$lock_file"
    fi
  fi
  rm -rf -- "$work_dir"
  exit "$status"
}
trap cleanup EXIT HUP INT TERM
roots_file="$work_dir/roots"
markers_file="$work_dir/markers"
repos_file="$work_dir/repos"
candidates_file="$work_dir/candidates"
records_file="$work_dir/records"
picked_file="$work_dir/picked"
: >"$roots_file"
: >"$markers_file"
: >"$repos_file"
: >"$candidates_file"
: >"$records_file"

canonical_directory() {
  [ -d "$1" ] || return 1
  (CDPATH= cd -P -- "$1" 2>/dev/null && pwd)
}

append_root() {
  candidate=$1
  case "$candidate" in
    "~")
      candidate=$HOME
      ;;
    "~/"*)
      candidate=$HOME/${candidate#\~/}
      ;;
  esac
  canonical=$(canonical_directory "$candidate") || return 0
  printf '%s\n' "$canonical" >>"$roots_file"
}

if [ -n "${HERDR_PROJECT_ROOTS:-}" ]; then
  old_ifs=$IFS
  IFS=:
  # Intentional word splitting: HERDR_PROJECT_ROOTS is a colon-separated list.
  for configured_root in $HERDR_PROJECT_ROOTS; do
    [ -n "$configured_root" ] && append_root "$configured_root"
  done
  IFS=$old_ifs
else
  append_root "$root"
  for default_root in \
    "$HOME/Documents" "$HOME/Projects" "$HOME/projects" "$HOME/work" "$HOME/code"
  do
    [ -d "$default_root" ] && append_root "$default_root"
  done
fi
LC_ALL=C sort -u "$roots_file" -o "$roots_file"

while IFS= read -r project_root; do
  top_level=$(git -C "$project_root" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$top_level" ]; then
    printf '%s\n' "$top_level" >>"$repos_file"
    continue
  fi
  use_fd=0
  if [ "$scanner" = fd ]; then
    command -v fd >/dev/null 2>&1 || {
      echo "HERDR_PROJECT_SCANNER=fd requires fd" >&2
      exit 127
    }
    use_fd=1
  elif [ "$scanner" = auto ] && command -v fd >/dev/null 2>&1; then
    use_fd=1
  fi
  if [ "$use_fd" -eq 1 ]; then
    fd -HI '^\.git$' "$project_root" --max-depth "$max_depth" --prune \
      --exclude .build --exclude .cache --exclude .runtime --exclude .tox \
      --exclude .venv --exclude build --exclude 'cmake-build-*' \
      --exclude node_modules --exclude target --exclude vendor --exclude venv \
      >>"$markers_file" 2>/dev/null || true
  else
    find "$project_root" -mindepth 1 -maxdepth "$max_depth" \
      \( -type d -name .git -print -prune \) -o \
      \( -type d \( \
        -name .build -o -name .cache -o -name .runtime -o -name .tox -o \
        -name .venv -o -name build -o -name 'cmake-build-*' -o \
        -name node_modules -o -name target -o -name vendor -o -name venv \
      \) -prune \) -o \
      \( -type f -name .git -print \) 2>/dev/null \
      >>"$markers_file" || true
  fi
done <"$roots_file"

while IFS= read -r marker; do
  marker=${marker%/}
  repository=${marker%/.git}
  top_level=$(git -C "$repository" rev-parse --show-toplevel 2>/dev/null || true)
  [ -n "$top_level" ] && printf '%s\n' "$top_level" >>"$repos_file"
done <"$markers_file"
LC_ALL=C sort -u "$repos_file" -o "$repos_file"

while IFS= read -r repository; do
  canonical=$(canonical_directory "$repository") || continue
  printf '%s\n' "$canonical" >>"$candidates_file"
  worktree_registry=
  if [ -d "$canonical/.git/worktrees" ]; then
    worktree_registry=$canonical/.git/worktrees
  elif [ -f "$canonical/.git" ]; then
    common_dir=$(
      git -C "$canonical" rev-parse --path-format=absolute \
        --git-common-dir 2>/dev/null || true
    )
    [ -d "$common_dir/worktrees" ] && worktree_registry=$common_dir/worktrees
  fi
  if [ -n "$worktree_registry" ]; then
    git -C "$canonical" worktree list --porcelain 2>/dev/null |
      sed -n 's/^worktree //p' |
      while IFS= read -r worktree; do
        canonical_worktree=$(canonical_directory "$worktree") || continue
        printf '%s\n' "$canonical_worktree"
      done >>"$candidates_file"
  fi
done <"$repos_file"
LC_ALL=C sort -u "$candidates_file" -o "$candidates_file"

if [ "$list_only" -eq 1 ]; then
  cat "$candidates_file"
  exit 0
fi

[ -s "$candidates_file" ] || {
  echo "project picker found no Git repositories or worktrees" >&2
  exit 1
}

while IFS= read -r candidate; do
  case "$candidate" in
    *"	"*|*"
"*)
      continue
      ;;
  esac
  label=$(basename -- "$candidate")
  display=$candidate
  case "$candidate" in
    "$HOME")
      display="~"
      ;;
    "$HOME"/*)
      display="~/${candidate#"$HOME"/}"
      ;;
  esac
  printf '%s\t%s\t%s\n' "$label" "$display" "$candidate"
done <"$candidates_file" |
  LC_ALL=C sort -f -t "	" -k1,1 -k2,2 >"$records_file"

if [ -n "${HERDR_PROJECT_SELECTION:-}" ]; then
  selected=$(canonical_directory "$HERDR_PROJECT_SELECTION") || {
    echo "selected project is not an accessible directory" >&2
    exit 1
  }
else
  picker=${HERDR_PROJECT_FZF:-fzf}
  command -v "$picker" >/dev/null 2>&1 || {
    echo "project picker requires fzf" >&2
    exit 127
  }
  if "$picker" --prompt="Project: " --layout=reverse \
      --delimiter="	" --with-nth=1,2 <"$records_file" >"$picked_file"
  then
    :
  else
    picker_status=$?
    case "$picker_status" in
      1|130)
        exit 0
        ;;
      *)
        exit "$picker_status"
        ;;
    esac
  fi
  [ -s "$picked_file" ] || exit 0
  selected=$(awk -F "	" 'NR == 1 { print $3 }' "$picked_file")
  selected=$(canonical_directory "$selected") || {
    echo "selected project became unavailable" >&2
    exit 1
  }
fi

if ! grep -Fqx -- "$selected" "$candidates_file"; then
  echo "selected project is outside the discovered project set" >&2
  exit 1
fi

lock_root=${HERDR_PROJECT_LOCK_ROOT:-$runtime_base}
[ -d "$lock_root" ] || {
  echo "project picker lock root is not an accessible directory" >&2
  exit 1
}
lock_file="$lock_root/herdr-project-picker-$session.lock"
while :; do
  if ln -s "$$" "$lock_file" 2>/dev/null; then
    if [ -L "$lock_file" ] &&
        [ "$(readlink "$lock_file" 2>/dev/null || true)" = "$$" ]
    then
      break
    fi
    if [ -L "$lock_file/$$" ] &&
        [ "$(readlink "$lock_file/$$" 2>/dev/null || true)" = "$$" ]
    then
      rm -f -- "$lock_file/$$"
    fi
  fi
  if [ -L "$lock_file" ]; then
    lock_owner=$(readlink "$lock_file" 2>/dev/null || true)
  else
    lock_owner=$(sed -n '1p' "$lock_file/owner" 2>/dev/null || true)
  fi
  case "$lock_owner" in
    ""|*[!0-9]*)
      lock_owner=
      ;;
  esac
  if [ -n "$lock_owner" ] && kill -0 "$lock_owner" 2>/dev/null; then
    echo "another project picker is already changing this Herdr session" >&2
    exit 75
  fi
  stale_lock="$lock_file.stale.$$"
  if mv -- "$lock_file" "$stale_lock" 2>/dev/null; then
    rm -rf -- "$stale_lock"
  else
    echo "another project picker is already changing this Herdr session" >&2
    exit 75
  fi
done
lock_acquired=1

cli() {
  "$herdr" --session "$session" "$@"
}

validate_workspace_list() {
  jq -e '
    type == "object" and
    .id == "cli:workspace:list" and
    (.result | type == "object") and
    .result.type == "workspace_list" and
    (.result.workspaces | type == "array") and
    ([.result.workspaces[].workspace_id] | length == (unique | length)) and
    ([.result.workspaces[] | select(.focused)] | length <= 1) and
    all(.result.workspaces[];
      type == "object" and
      (.workspace_id | type == "string" and length > 0) and
      (.focused | type == "boolean") and
      (.label | type == "string") and
      (.number | type == "number") and
      (.pane_count | type == "number") and
      (.tab_count | type == "number") and
      ((.active_tab_id // "") | type == "string") and
      ((.tokens // {}) | type == "object") and
      all((.tokens // {})[]; type == "string"))
  ' "$1" >/dev/null
}

validate_pane_list() {
  jq -e '
    type == "object" and
    .id == "cli:pane:list" and
    (.result | type == "object") and
    .result.type == "pane_list" and
    (.result.panes | type == "array") and
    ([.result.panes[].pane_id] | length == (unique | length)) and
    all(.result.panes[];
      type == "object" and
      (.pane_id | type == "string" and length > 0) and
      (.tab_id | type == "string" and length > 0) and
      (.workspace_id | type == "string" and length > 0) and
      (.focused | type == "boolean") and
      ((.cwd // "") | type == "string") and
      ((.foreground_cwd // "") | type == "string"))
  ' "$1" >/dev/null
}

validate_focus_result() {
  jq -e --arg workspace "$2" '
    type == "object" and
    .id == "cli:workspace:focus" and
    (.result | type == "object") and
    .result.type == "workspace_info" and
    (.result.workspace | type == "object") and
    .result.workspace.workspace_id == $workspace and
    .result.workspace.focused == true
  ' "$1" >/dev/null
}

focus_workspace() {
  focus_target=$1
  focus_result="$work_dir/focus-$focus_target.json"
  cli workspace focus "$focus_target" >"$focus_result" &&
    validate_focus_result "$focus_result" "$focus_target"
}

verify_focused_workspace() {
  verify_target=$1
  verify_file="$work_dir/verify-focus-$verify_target.json"
  cli workspace list >"$verify_file" &&
    validate_workspace_list "$verify_file" &&
    jq -e --arg workspace "$verify_target" '
      [.result.workspaces[] |
        select(.workspace_id == $workspace and .focused == true)] |
      length == 1
    ' "$verify_file" >/dev/null
}

restore_focus() {
  [ -z "$focused_before" ] && return 0
  focus_workspace "$focused_before" &&
    verify_focused_workspace "$focused_before"
}

verify_project_identity() {
  identity_workspace=$1
  identity_expected=$2
  identity_file="$work_dir/identity-$identity_workspace.json"
  cli workspace list >"$identity_file" &&
    validate_workspace_list "$identity_file" &&
    jq -e --arg workspace "$identity_workspace" \
      --arg expected "$identity_expected" '
        [.result.workspaces[] |
          select(.workspace_id == $workspace and
            (.tokens.project_cwd // "") == $expected)] |
        length == 1
      ' "$identity_file" >/dev/null
}

clear_project_identity() {
  identity_workspace=$1
  cli workspace report-metadata "$identity_workspace" \
    --source project-picker --clear-token project_cwd >/dev/null &&
    verify_project_identity "$identity_workspace" ""
}

validate_close_result() {
  jq -e '
    type == "object" and
    .id == "cli:workspace:close" and
    (.result | type == "object") and
    .result.type == "ok"
  ' "$1" >/dev/null
}

rollback_created_workspace() {
  rollback_known=${1:-}
  rollback_file="$work_dir/rollback-workspaces.json"
  rollback_panes="$work_dir/rollback-panes.json"
  rollback_ids="$work_dir/rollback-ids"
  rollback_targets="$work_dir/rollback-targets"
  : >"$rollback_targets"
  if ! cli workspace list >"$rollback_file" ||
      ! validate_workspace_list "$rollback_file"
  then
    return 1
  fi
  jq -r --argjson before "$before_ids" '
    [.result.workspaces[].workspace_id] - $before | .[]
  ' "$rollback_file" >"$rollback_ids"
  if [ -n "$rollback_known" ]; then
    grep -Fqx -- "$rollback_known" "$rollback_ids" || return 1
    printf '%s\n' "$rollback_known" >"$rollback_targets"
  elif [ -s "$rollback_ids" ]; then
    rollback_delta_count=$(wc -l <"$rollback_ids" | tr -d ' ')
    if [ "$rollback_delta_count" -eq 1 ]; then
      cp "$rollback_ids" "$rollback_targets"
    else
      if ! cli pane list >"$rollback_panes" ||
          ! validate_pane_list "$rollback_panes"
      then
        return 1
      fi
      jq -c '.result.panes[]' "$rollback_panes" |
        while IFS= read -r pane_object; do
          workspace_id=$(printf '%s\n' "$pane_object" |
            jq -er '.workspace_id')
          grep -Fqx -- "$workspace_id" "$rollback_ids" || continue
          pane_cwd=$(printf '%s\n' "$pane_object" |
            jq -r '.cwd // empty')
          foreground_cwd=$(printf '%s\n' "$pane_object" |
            jq -r '.foreground_cwd // empty')
          canonical_pane=
          [ -n "$pane_cwd" ] &&
            canonical_pane=$(canonical_directory "$pane_cwd" || true)
          canonical_foreground=
          [ -n "$foreground_cwd" ] &&
            canonical_foreground=$(
              canonical_directory "$foreground_cwd" || true
            )
          if [ "$canonical_pane" = "$selected" ] ||
              [ "$canonical_foreground" = "$selected" ]
          then
            printf '%s\n' "$workspace_id"
          fi
        done | LC_ALL=C sort -u >"$rollback_targets"
    fi
  fi
  rollback_count=$(wc -l <"$rollback_targets" | tr -d ' ')
  [ "$rollback_count" -le 1 ] || return 1
  if [ "$rollback_count" -eq 1 ]; then
    rollback_target=$(sed -n '1p' "$rollback_targets")
    close_result="$work_dir/rollback-close.json"
    cli workspace close "$rollback_target" >"$close_result" &&
      validate_close_result "$close_result" || return 1
    after_close="$work_dir/rollback-after-close.json"
    cli workspace list >"$after_close" &&
      validate_workspace_list "$after_close" &&
      ! jq -e --arg workspace "$rollback_target" '
        any(.result.workspaces[]; .workspace_id == $workspace)
      ' "$after_close" >/dev/null || return 1
  fi
  restore_focus
}

validate_created_workspace() {
  jq -e --arg selected "$2" --arg label "$3" \
    --argjson expected_focus "$4" '
    type == "object" and
    .id == "cli:workspace:create" and
    (.result | type == "object") and
    .result.type == "workspace_created" and
    (.result.workspace | type == "object") and
    (.result.workspace.workspace_id | type == "string" and length > 0) and
    .result.workspace.focused == $expected_focus and
    .result.workspace.label == $label and
    (.result.workspace.number | type == "number") and
    (.result.workspace.pane_count | type == "number") and
    (.result.workspace.tab_count | type == "number") and
    (.result.workspace.active_tab_id | type == "string" and length > 0) and
    (.result.tab | type == "object") and
    (.result.tab.tab_id | type == "string" and length > 0) and
    (.result.tab.workspace_id == .result.workspace.workspace_id) and
    (.result.root_pane | type == "object") and
    (.result.root_pane.pane_id | type == "string" and length > 0) and
    (.result.root_pane.workspace_id == .result.workspace.workspace_id) and
    (.result.root_pane.tab_id == .result.tab.tab_id) and
    .result.root_pane.cwd == $selected and
    .result.root_pane.foreground_cwd == $selected
  ' "$1" >/dev/null
}

verify_created_workspace_state() {
  created_workspace=$1
  created_selected=$2
  created_label=$3
  created_expected_focus=$4
  created_workspaces="$work_dir/created-state-workspaces.json"
  created_panes="$work_dir/created-state-panes.json"
  cli workspace list >"$created_workspaces" &&
    validate_workspace_list "$created_workspaces" &&
    jq -e --arg workspace "$created_workspace" \
      --arg label "$created_label" \
      --argjson expected_focus "$created_expected_focus" '
        [.result.workspaces[] |
          select(.workspace_id == $workspace and
            .label == $label and .focused == $expected_focus)] |
        length == 1
      ' "$created_workspaces" >/dev/null &&
    cli pane list >"$created_panes" &&
    validate_pane_list "$created_panes" &&
    jq -e --arg workspace "$created_workspace" \
      --arg cwd "$created_selected" '
        [.result.panes[] |
          select(.workspace_id == $workspace and
            .cwd == $cwd and .foreground_cwd == $cwd)] |
        length == 1
      ' "$created_panes" >/dev/null
}

workspaces_file="$work_dir/workspaces.json"
if ! cli workspace list >"$workspaces_file"; then
  echo "could not read Herdr workspaces" >&2
  exit 1
fi
if ! validate_workspace_list "$workspaces_file"
then
    echo "Herdr returned a malformed workspace list" >&2
    exit 1
fi
focused_before=$(
  jq -r '.result.workspaces[] | select(.focused).workspace_id' \
    "$workspaces_file" | sed -n '1p'
)
before_ids=$(jq -c '[.result.workspaces[].workspace_id]' "$workspaces_file")

existing=
adopted_identity=0
jq -c '.result.workspaces[]' "$workspaces_file" >"$work_dir/workspace-objects"
while IFS= read -r workspace_object; do
  workspace_id=$(printf '%s\n' "$workspace_object" |
    jq -er '.workspace_id')
  workspace_cwd=$(printf '%s\n' "$workspace_object" |
    jq -r '.tokens.project_cwd // empty')
  [ -n "$workspace_cwd" ] || continue
  canonical_workspace=$(canonical_directory "$workspace_cwd") || continue
  if [ "$canonical_workspace" = "$selected" ]; then
    printf '%s\n' "$workspace_id"
  fi
done <"$work_dir/workspace-objects" >"$work_dir/existing"
LC_ALL=C sort -u "$work_dir/existing" -o "$work_dir/existing"
existing_count=$(wc -l <"$work_dir/existing" | tr -d ' ')
[ "$existing_count" -le 1 ] || {
  echo "multiple Herdr workspaces claim the selected project identity" >&2
  exit 1
}
existing=$(sed -n '1p' "$work_dir/existing")

if [ -z "$existing" ]; then
  panes_file="$work_dir/panes.json"
  if ! cli pane list >"$panes_file"; then
    echo "could not read Herdr panes" >&2
    exit 1
  fi
  if ! validate_pane_list "$panes_file" ||
      ! jq -e --argjson workspaces "$before_ids" '
        all(.result.panes[];
          .workspace_id as $workspace |
          ($workspaces | index($workspace)) != null)
      ' "$panes_file" >/dev/null
  then
    echo "Herdr returned a malformed pane list" >&2
    exit 1
  fi
  jq -r '
    .result.workspaces[] |
    select((.tokens.project_cwd // "") == "") |
    .workspace_id
  ' "$workspaces_file" >"$work_dir/tokenless-workspaces"
  jq -c '.result.panes[]' "$panes_file" >"$work_dir/pane-objects"
  while IFS= read -r pane_object; do
    workspace_id=$(printf '%s\n' "$pane_object" |
      jq -er '.workspace_id')
    grep -Fqx -- "$workspace_id" "$work_dir/tokenless-workspaces" || continue
    pane_cwd=$(printf '%s\n' "$pane_object" |
      jq -r '.cwd // empty')
    foreground_cwd=$(printf '%s\n' "$pane_object" |
      jq -r '.foreground_cwd // empty')
    canonical_pane=
    [ -n "$pane_cwd" ] &&
      canonical_pane=$(canonical_directory "$pane_cwd" || true)
    canonical_foreground=
    [ -n "$foreground_cwd" ] &&
      canonical_foreground=$(canonical_directory "$foreground_cwd" || true)
    if [ "$canonical_pane" = "$selected" ] ||
        [ "$canonical_foreground" = "$selected" ]
    then
      printf '%s\n' "$workspace_id"
    fi
  done <"$work_dir/pane-objects" >"$work_dir/existing"
  LC_ALL=C sort -u "$work_dir/existing" -o "$work_dir/existing"
  existing_count=$(wc -l <"$work_dir/existing" | tr -d ' ')
  [ "$existing_count" -le 1 ] || {
    echo "multiple tokenless workspaces match the selected project cwd" >&2
    exit 1
  }
  existing=$(sed -n '1p' "$work_dir/existing")
  if [ -n "$existing" ]; then
    adopted_identity=1
  fi
fi

if [ -n "$existing" ]; then
  if ! focus_workspace "$existing"; then
    restore_focus || {
      echo "could not restore the prior Herdr workspace focus" >&2
      exit 1
    }
    echo "could not focus the selected Herdr workspace" >&2
    exit 1
  fi
  if ! verify_focused_workspace "$existing"; then
    restore_focus || {
      echo "could not restore the prior Herdr workspace focus" >&2
      exit 1
    }
    echo "could not verify the selected Herdr workspace" >&2
    exit 1
  fi
  if [ "$adopted_identity" -eq 1 ]; then
    if ! cli workspace report-metadata "$existing" --source project-picker \
        --token "project_cwd=$selected" >/dev/null ||
        ! verify_project_identity "$existing" "$selected"
    then
      clear_project_identity "$existing" || {
        echo "could not roll back the selected workspace identity" >&2
        exit 1
      }
      restore_focus || {
        echo "could not restore the prior Herdr workspace focus" >&2
        exit 1
      }
      echo "could not record the selected workspace identity" >&2
      exit 1
    fi
  fi
  exit 0
fi

label=$(basename -- "$selected")
created_file="$work_dir/created.json"
if ! cli workspace create --cwd "$selected" --label "$label" --no-focus \
    >"$created_file"
then
  rollback_created_workspace || {
    echo "could not roll back the failed Herdr workspace creation" >&2
    exit 1
  }
  echo "could not create the selected Herdr workspace" >&2
  exit 1
fi
if [ "$(printf '%s\n' "$before_ids" | jq 'length')" -eq 0 ]; then
  expected_created_focus=true
else
  expected_created_focus=false
fi
if ! validate_created_workspace "$created_file" "$selected" "$label" \
    "$expected_created_focus"
then
  rollback_created_workspace || {
    echo "could not roll back the malformed Herdr workspace creation" >&2
    exit 1
  }
  echo "Herdr returned a malformed workspace creation result" >&2
  exit 1
fi
created_id=$(jq -er '.result.workspace.workspace_id' "$created_file")
if
    printf '%s\n' "$before_ids" |
      jq -e --arg workspace "$created_id" 'index($workspace) != null' >/dev/null
then
  rollback_created_workspace || {
    echo "could not roll back the duplicate Herdr workspace creation" >&2
    exit 1
  }
  echo "Herdr returned a malformed workspace creation result" >&2
  exit 1
fi
if ! verify_created_workspace_state "$created_id" "$selected" "$label" \
    "$expected_created_focus"
then
  rollback_created_workspace "$created_id" || {
    echo "could not roll back the incorrect live Herdr workspace" >&2
    exit 1
  }
  echo "Herdr created a workspace with incorrect live state" >&2
  exit 1
fi
if ! cli workspace report-metadata "$created_id" --source project-picker \
    --token "project_cwd=$selected" >/dev/null ||
    ! verify_project_identity "$created_id" "$selected"
then
  rollback_created_workspace "$created_id" || {
    echo "could not roll back the unidentified Herdr workspace" >&2
    exit 1
  }
  echo "could not record the new workspace identity" >&2
  exit 1
fi
if ! focus_workspace "$created_id"; then
  rollback_created_workspace "$created_id" || {
    echo "could not roll back the unfocusable Herdr workspace" >&2
    exit 1
  }
  echo "could not focus the new Herdr workspace" >&2
  exit 1
fi
if ! verify_focused_workspace "$created_id"; then
  rollback_created_workspace "$created_id" || {
    echo "could not roll back the unverifiable Herdr workspace" >&2
    exit 1
  }
  echo "could not verify the new Herdr workspace" >&2
  exit 1
fi
