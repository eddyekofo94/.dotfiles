#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
herdr_dir="$root/herdr"
prototype="$herdr_dir/prototype"
picker="$herdr_dir/project_picker.sh"
herdr="$prototype/.runtime/bin/herdr"
runtime_seed=$(mktemp -d /tmp/hpp.XXXXXX)
runtime=$(CDPATH= cd -P -- "$runtime_seed" && pwd)
config_home="$runtime/config-home"
config="$config_home/herdr/config.toml"
session=project-picker
foreign_session=project-picker-foreign
socket="$config_home/herdr/sessions/$session/herdr.sock"
foreign_socket="$config_home/herdr/sessions/$foreign_session/herdr.sock"
evidence="$prototype/evidence/project-picker-validation.jsonl"
evidence_tmp="$runtime/project-picker-validation.jsonl.tmp"
driver_fifo="$runtime/client.fifo"
driver_log="$runtime/client.log"
screen="$runtime/screen.txt"
server_log="$runtime/server.log"
foreign_server_log="$runtime/foreign-server.log"
projects="$runtime/projects"
external="$runtime/external"
alpha="$projects/alpha"
alpha_feature="$external/alpha-feature"
service_north="$projects/north/service"
service_south="$projects/south/service"
vendored_repo="$projects/app/build/dependency"
stale_project="$projects/stale"
failure_project="$projects/failure"
backslash_project="$projects/back\\slash"
concurrent_project="$projects/concurrent"
unrelated_project="$runtime/unrelated"

[ -x "$herdr" ] || {
  echo "project-picker validation requires the prototype Herdr binary" >&2
  exit 2
}

record() {
  jq -cn --arg check "$1" --argjson evidence "$2" \
    '{check:$check,evidence:$evidence}' >>"$evidence_tmp"
}
wait_for() {
  description=$1
  shift
  attempts=0
  until "$@"; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 120 ]; then
      echo "project-picker validation timed out: $description" >&2
      return 1
    fi
    sleep 0.05
  done
}
cli() {
  "$herdr" --session "$session" "$@"
}
foreign_cli() {
  "$herdr" --session "$foreign_session" "$@"
}
workspace_count() {
  cli workspace list | jq -er '.result.workspaces | length'
}
workspace_count_is() {
  [ "$(workspace_count)" -eq "$1" ]
}
workspace_for_cwd() {
  cli workspace list |
    jq -er --arg cwd "$1" \
      '.result.workspaces[] |
        select(.tokens.project_cwd == $cwd).workspace_id' |
    sed -n '1p'
}
foreign_workspace_for_cwd() {
  foreign_cli workspace list |
    jq -er --arg cwd "$1" \
      '.result.workspaces[] |
        select(.tokens.project_cwd == $cwd).workspace_id' |
    sed -n '1p'
}
focused_workspace() {
  cli workspace list | jq -er '.result.workspaces[] | select(.focused).workspace_id'
}
workspace_exists_for_cwd() {
  workspace_for_cwd "$1" >/dev/null 2>&1
}
production_state() {
  jq -cn \
    --arg binary_hash "$(shasum -a 256 "$HOME/.local/bin/herdr" | awk '{print $1}')" \
    --arg tmux_hash "$(shasum -a 256 "$root/tmux/tmux.conf" | awk '{print $1}')" \
    --arg fish_hash "$(shasum -a 256 "$root/fish/config.fish" | awk '{print $1}')" \
    --arg config_hash "$(shasum -a 256 "$herdr_dir/config.toml" | awk '{print $1}')" \
    --arg pane_history "$(awk -F' = ' '$1 == "pane_history" {print $2}' "$herdr_dir/config.toml")" \
    --arg tmux_version "$(tmux -V)" \
    '{binary_sha256:$binary_hash,tmux_config_sha256:$tmux_hash,
      fish_config_sha256:$fish_hash,herdr_config_sha256:$config_hash,
      pane_history:$pane_history,tmux_version:$tmux_version}'
}
send_action() {
  action=$1
  before=$(wc -l <"$driver_log" | tr -d ' ')
  printf '%s\n' "$action" >&3
  wait_for "client action $action" sh -c \
    '[ "$(wc -l < "$1" | tr -d " ")" -gt "$2" ] && [ "$(tail -n 1 "$1")" = "$3" ]' \
    sh "$driver_log" "$before" "SENT $action"
}
cleanup() {
  status=$?
  trap - EXIT HUP INT TERM
  exec 3>&- 2>/dev/null || true
  if [ -n "${driver_pid:-}" ]; then
    kill "$driver_pid" 2>/dev/null || true
    wait "$driver_pid" 2>/dev/null || true
  fi
  if [ -n "${concurrent_pid:-}" ]; then
    kill "$concurrent_pid" 2>/dev/null || true
    wait "$concurrent_pid" 2>/dev/null || true
  fi
  foreign_cli session stop "$foreign_session" --json >/dev/null 2>&1 || true
  cli session stop "$session" --json >/dev/null 2>&1 || true
  if [ -n "${foreign_server_pid:-}" ]; then
    kill "$foreign_server_pid" 2>/dev/null || true
    wait "$foreign_server_pid" 2>/dev/null || true
  fi
  if [ -n "${server_pid:-}" ]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  foreign_cli session delete "$foreign_session" --json >/dev/null 2>&1 || true
  cli session delete "$session" --json >/dev/null 2>&1 || true
  rm -rf -- "$runtime"
  exit "$status"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$config_home/herdr" "$alpha" "$external" \
  "$service_north" "$service_south" "$vendored_repo" "$stale_project" \
  "$failure_project" "$backslash_project"
mkdir -p "$concurrent_project" "$unrelated_project"
sed 's|^default_shell = .*$|default_shell = "/bin/sh"|' \
  "$herdr_dir/config.toml" >"$config"
: >"$evidence_tmp"

git -C "$alpha" init -q
git -C "$alpha" config user.name "Herdr Project Picker Validation"
git -C "$alpha" config user.email "herdr-project-picker@example.invalid"
printf 'alpha\n' >"$alpha/README"
git -C "$alpha" add README
git -C "$alpha" commit -qm "fixture"
git -C "$alpha" worktree add -qb feature "$alpha_feature"
git -C "$service_north" init -q
git -C "$service_south" init -q
git -C "$vendored_repo" init -q
git -C "$stale_project" init -q
git -C "$failure_project" init -q
git -C "$backslash_project" init -q
git -C "$concurrent_project" init -q

export XDG_CONFIG_HOME="$config_home"
export HERDR_CONFIG_PATH="$config"
export HERDR_BIN_PATH="$herdr"
export HERDR_PROTOTYPE_DIR="$prototype"
export HERDR_PROJECT_ROOTS="$projects"

production_before=$(production_state)
config_result=$(cli config check)
test "$config_result" = "config: ok"
grep -q '^key = "prefix+shift+w"$' "$config"
grep -q 'project_picker\.sh' "$config"
grep -q '^pane_history = false$' "$config"
record decisions "$(jq -cn --arg result "$config_result" \
  '{result:$result,binding:"prefix+Shift+w",native_workspace_picker:"prefix+w",
    model:"workspaces-within-main-session",pane_history:false,
    creates_git_worktrees:false,creates_named_sessions:false}')"

discovered=$(
  HERDR_PROJECT_SESSION="$session" "$picker" --list
)
discovered_find=$(
  HERDR_PROJECT_SCANNER=find HERDR_PROJECT_SESSION="$session" "$picker" --list
)
test "$discovered_find" = "$discovered"
expected=$(printf '%s\n' \
  "$alpha" "$alpha_feature" "$service_north" "$service_south" \
  "$stale_project" "$failure_project" "$backslash_project" | sort)
expected=$(printf '%s\n' "$expected" "$concurrent_project" | sort)
test "$discovered" = "$expected"
test "$(printf '%s\n' "$discovered" | sort -u | wc -l | tr -d ' ')" -eq 8
record discovery "$(jq -cn \
  --argjson paths "$(printf '%s\n' "$discovered" | jq -Rsc 'split("\n")[:-1]')" \
  '{roots_configurable:true,git_repositories:true,linked_external_worktree:true,
    duplicate_basenames_preserved:true,generated_dependency_pruned:true,
    fd_accelerated_when_available:true,find_fallback_exercised:true,
    canonical_paths:$paths}')"

cli server >"$server_log" 2>&1 &
server_pid=$!
wait_for "main project-picker socket" test -S "$socket"
foreign_cli server >"$foreign_server_log" 2>&1 &
foreign_server_pid=$!
wait_for "foreign project-picker socket" test -S "$foreign_socket"

HERDR_PROJECT_SESSION="$session" HERDR_PROJECT_SELECTION="$alpha" "$picker"
alpha_workspace=$(workspace_for_cwd "$alpha")
test "$(focused_workspace)" = "$alpha_workspace"
count_after_create=$(workspace_count)
HERDR_PROJECT_SESSION="$session" HERDR_PROJECT_SELECTION="$alpha" "$picker"
test "$(workspace_count)" -eq "$count_after_create"
test "$(focused_workspace)" = "$alpha_workspace"
cli session stop "$session" --json >/dev/null
wait "$server_pid" 2>/dev/null || true
server_pid=
cli server >>"$server_log" 2>&1 &
server_pid=$!
wait_for "restarted project-picker socket" test -S "$socket"
if cli workspace list |
    jq -e --arg workspace "$alpha_workspace" '
      any(.result.workspaces[];
        .workspace_id == $workspace and
        ((.tokens.project_cwd // "") | length > 0))
    ' >/dev/null
then
  echo "project identity unexpectedly survived the server restart" >&2
  exit 1
fi
test "$(
  cli pane list |
    jq -er --arg workspace "$alpha_workspace" --arg cwd "$alpha" '
      [.result.panes[] |
        select(.workspace_id == $workspace and
          (.cwd == $cwd or .foreground_cwd == $cwd))] | length
    '
)" -ge 1
HERDR_PROJECT_SESSION="$session" HERDR_PROJECT_SELECTION="$alpha" "$picker"
test "$(workspace_for_cwd "$alpha")" = "$alpha_workspace"
test "$(workspace_count)" -eq "$count_after_create"
test "$(focused_workspace)" = "$alpha_workspace"
record reuse "$(jq -cn --arg workspace "$alpha_workspace" \
  --argjson count "$count_after_create" \
  '{canonical_cwd_reused:true,workspace_id:$workspace,
    workspace_count_after_second_selection:$count,duplicate_created:false,
    metadata_absent_after_server_restart:true,
    restored_pane_cwd_drove_identity_re_adoption:true,
    identity_reestablished_after_server_restart:true,pane_history:false}')"

HERDR_PROJECT_SESSION="$session" HERDR_PROJECT_SELECTION="$service_north" "$picker"
north_workspace=$(workspace_for_cwd "$service_north")
HERDR_PROJECT_SESSION="$session" HERDR_PROJECT_SELECTION="$service_south" "$picker"
south_workspace=$(workspace_for_cwd "$service_south")
test "$north_workspace" != "$south_workspace"
service_labels=$(cli workspace list |
  jq -c --arg north "$service_north" --arg south "$service_south" \
    '[.result.workspaces[] |
      select(.tokens.project_cwd == $north or
        .tokens.project_cwd == $south) | .label]')
test "$service_labels" = '["service","service"]'
HERDR_PROJECT_SESSION="$session" \
HERDR_PROJECT_SELECTION="$backslash_project" "$picker"
backslash_workspace=$(workspace_for_cwd "$backslash_project")
backslash_count=$(workspace_count)
HERDR_PROJECT_SESSION="$session" \
HERDR_PROJECT_SELECTION="$backslash_project" "$picker"
test "$(workspace_count)" -eq "$backslash_count"
test "$(workspace_for_cwd "$backslash_project")" = "$backslash_workspace"
record collision "$(jq -cn --arg north "$north_workspace" \
  --arg south "$south_workspace" --arg backslash "$backslash_workspace" \
  --argjson labels "$service_labels" \
  '{same_basename_distinct_paths:true,workspace_ids:[$north,$south],
    labels:$labels,picker_disambiguates_with_path:true,
    backslash_path_reused_losslessly:true,backslash_workspace_id:$backslash}')"

before_failure=$(workspace_count)
focused_before_failure=$(focused_workspace)
mkdir -p "$runtime/outside"
if HERDR_PROJECT_SESSION="$session" \
    HERDR_PROJECT_SELECTION="$runtime/outside" "$picker" >/dev/null 2>&1
then
  echo "project picker accepted an undiscovered directory" >&2
  exit 1
fi
test "$(workspace_count)" -eq "$before_failure"
HERDR_PROJECT_SESSION="$session" \
HERDR_PROJECT_FZF="$herdr_dir/fixtures/fzf-cancel.sh" \
HERDR_PROJECT_SELECTION= "$picker"
test "$(workspace_count)" -eq "$before_failure"
if HERDR_PROJECT_SESSION="$session" \
    HERDR_PROJECT_FZF="$herdr_dir/fixtures/fzf-stale-project.sh" \
    HERDR_FZF_STALE_TARGET="$stale_project" \
    HERDR_PROJECT_SELECTION= "$picker" >/dev/null 2>&1
then
  echo "project picker accepted a target removed after discovery" >&2
  exit 1
fi
test "$(workspace_count)" -eq "$before_failure"
if HERDR_PROJECT_SESSION=project-picker-unavailable \
    HERDR_PROJECT_SELECTION="$alpha" "$picker" >/dev/null 2>&1
then
  echo "project picker accepted an unavailable Herdr session" >&2
  exit 1
fi
test "$(workspace_count)" -eq "$before_failure"
for failure_mode in malformed-workspaces malformed-panes \
  malformed-pane-envelope create-failure metadata-failure metadata-noop \
  malformed-create malformed-unexpected-create wrong-create-state \
  wrong-live-create-state rewritten-existing-id focus-failure
do
  if HERDR_PROJECT_SESSION="$session" \
      HERDR_BIN_PATH="$herdr_dir/fixtures/herdr-project-api-fixture.sh" \
      HERDR_FIXTURE_REAL_BIN="$herdr" \
      HERDR_FIXTURE_MODE="$failure_mode" \
      HERDR_FIXTURE_WRONG_CWD="$unrelated_project" \
      HERDR_FIXTURE_EXPECTED_CWD="$failure_project" \
      HERDR_FIXTURE_EXPECTED_LABEL=failure \
      HERDR_FIXTURE_EXISTING_ID="$alpha_workspace" \
      HERDR_PROJECT_SELECTION="$failure_project" \
      "$picker" >/dev/null 2>&1
  then
    echo "project picker accepted injected API failure: $failure_mode" >&2
    exit 1
  fi
  test "$(workspace_count)" -eq "$before_failure"
  test "$(focused_workspace)" = "$focused_before_failure"
done
cli workspace report-metadata "$alpha_workspace" --source project-picker \
  --clear-token project_cwd >/dev/null
test "$(
  cli workspace list |
    jq -r --arg workspace "$alpha_workspace" '
      .result.workspaces[] |
      select(.workspace_id == $workspace) |
      (.tokens.project_cwd // "")
    '
)" = ""
if HERDR_PROJECT_SESSION="$session" \
    HERDR_BIN_PATH="$herdr_dir/fixtures/herdr-project-api-fixture.sh" \
    HERDR_FIXTURE_REAL_BIN="$herdr" \
    HERDR_FIXTURE_MODE=focus-failure \
    HERDR_PROJECT_SELECTION="$alpha" \
    "$picker" >/dev/null 2>&1
then
  echo "project picker accepted an injected focus failure" >&2
  exit 1
fi
test "$(workspace_count)" -eq "$before_failure"
test "$(focused_workspace)" = "$focused_before_failure"
test "$(
  cli workspace list |
    jq -r --arg workspace "$alpha_workspace" '
      .result.workspaces[] |
      select(.workspace_id == $workspace) |
      (.tokens.project_cwd // "")
    '
)" = ""
if HERDR_PROJECT_SESSION="$session" \
    HERDR_BIN_PATH="$herdr_dir/fixtures/herdr-project-api-fixture.sh" \
    HERDR_FIXTURE_REAL_BIN="$herdr" \
    HERDR_FIXTURE_MODE=metadata-failure \
    HERDR_PROJECT_SELECTION="$alpha" \
    "$picker" >/dev/null 2>&1
then
  echo "project picker accepted an adopted metadata mutation failure" >&2
  exit 1
fi
test "$(workspace_count)" -eq "$before_failure"
test "$(focused_workspace)" = "$focused_before_failure"
test "$(
  cli workspace list |
    jq -r --arg workspace "$alpha_workspace" '
      .result.workspaces[] |
      select(.workspace_id == $workspace) |
      (.tokens.project_cwd // "")
    '
)" = ""
fixture_state="$runtime/malformed-post-focus.state"
rm -f "$fixture_state"
if HERDR_PROJECT_SESSION="$session" \
    HERDR_BIN_PATH="$herdr_dir/fixtures/herdr-project-api-fixture.sh" \
    HERDR_FIXTURE_REAL_BIN="$herdr" \
    HERDR_FIXTURE_MODE=malformed-post-focus \
    HERDR_FIXTURE_STATE="$fixture_state" \
    HERDR_PROJECT_SELECTION="$alpha" \
    "$picker" >/dev/null 2>&1
then
  echo "project picker accepted a malformed post-focus response" >&2
  exit 1
fi
test "$(workspace_count)" -eq "$before_failure"
test "$(focused_workspace)" = "$focused_before_failure"
test "$(
  cli workspace list |
    jq -r --arg workspace "$alpha_workspace" '
      .result.workspaces[] |
      select(.workspace_id == $workspace) |
      (.tokens.project_cwd // "")
    '
)" = ""
if HERDR_PROJECT_SESSION="$session" \
    HERDR_BIN_PATH="$herdr_dir/fixtures/herdr-project-api-fixture.sh" \
    HERDR_FIXTURE_REAL_BIN="$herdr" \
    HERDR_FIXTURE_MODE=unrelated-create-failure \
    HERDR_FIXTURE_UNRELATED_CWD="$unrelated_project" \
    HERDR_PROJECT_SELECTION="$failure_project" \
    "$picker" >/dev/null 2>&1
then
  echo "project picker accepted an unrelated concurrent create failure" >&2
  exit 1
fi
test "$(workspace_count)" -eq $((before_failure + 1))
unrelated_workspace=$(
  cli pane list |
    jq -er --arg cwd "$unrelated_project" '
      .result.panes[] |
      select(.cwd == $cwd or .foreground_cwd == $cwd) |
      .workspace_id
    ' |
    sed -n '1p'
)
test -n "$unrelated_workspace"
if cli pane list |
    jq -e --arg cwd "$failure_project" '
      any(.result.panes[];
        .cwd == $cwd or .foreground_cwd == $cwd)
    ' >/dev/null
then
  echo "target workspace survived target-specific rollback" >&2
  exit 1
fi
cli workspace close "$unrelated_workspace" >/dev/null
cli workspace focus "$focused_before_failure" >/dev/null
test "$(workspace_count)" -eq "$before_failure"
test "$(focused_workspace)" = "$focused_before_failure"

conflicting_result=$(
  cli workspace create --cwd "$failure_project" \
    --label conflicting --no-focus
)
conflicting_workspace=$(
  printf '%s\n' "$conflicting_result" |
    jq -er '.result.workspace.workspace_id'
)
cli workspace report-metadata "$conflicting_workspace" \
  --source validation --token "project_cwd=$service_north" >/dev/null
HERDR_PROJECT_SESSION="$session" \
HERDR_PROJECT_SELECTION="$failure_project" "$picker"
failure_workspace=$(workspace_for_cwd "$failure_project")
test -n "$failure_workspace"
test "$failure_workspace" != "$conflicting_workspace"
test "$(
  cli workspace list |
    jq -r --arg workspace "$conflicting_workspace" '
      .result.workspaces[] |
      select(.workspace_id == $workspace) |
      .tokens.project_cwd
    '
)" = "$service_north"
cli workspace close "$failure_workspace" >/dev/null
cli workspace close "$conflicting_workspace" >/dev/null
cli workspace focus "$focused_before_failure" >/dev/null

ambiguous_one=$(
  cli workspace create --cwd "$failure_project" \
    --label ambiguous-one --no-focus |
    jq -er '.result.workspace.workspace_id'
)
ambiguous_two=$(
  cli workspace create --cwd "$failure_project" \
    --label ambiguous-two --no-focus |
    jq -er '.result.workspace.workspace_id'
)
ambiguous_count=$(workspace_count)
if HERDR_PROJECT_SESSION="$session" \
    HERDR_PROJECT_SELECTION="$failure_project" \
    "$picker" >/dev/null 2>&1
then
  echo "project picker accepted an ambiguous tokenless cwd match" >&2
  exit 1
fi
test "$(workspace_count)" -eq "$ambiguous_count"
cli workspace close "$ambiguous_one" >/dev/null
cli workspace close "$ambiguous_two" >/dev/null
cli workspace focus "$focused_before_failure" >/dev/null
test "$(workspace_count)" -eq "$before_failure"
record failures "$(jq -cn \
  '{undiscovered_target_rejected:true,cancel_no_op:true,
    stale_target_rejected:true,malformed_api_rejected:true,
    malformed_panes_rejected:true,malformed_pane_envelope_rejected:true,
    post_focus_malformed_rejected:true,
    mutate_then_fail_create_rolled_back:true,
    metadata_failure_rolled_back:true,metadata_noop_rejected:true,
    malformed_create_rolled_back:true,
    malformed_unexpected_create_rolled_back:true,
    wrong_create_state_rolled_back:true,
    wrong_live_create_state_rolled_back:true,
    rewritten_existing_id_rolled_back:true,
    mutate_then_fail_focus_rolled_back:true,
    adopted_metadata_rolled_back:true,
    unrelated_concurrent_workspace_preserved:true,
    tokened_workspace_identity_not_overwritten:true,
    ambiguous_tokenless_match_rejected:true,
    unavailable_session_rejected:true,
    workspace_count_unchanged:true,focus_unchanged:true}')"

before_concurrent=$(workspace_count)
HERDR_PROJECT_SESSION="$session" \
HERDR_BIN_PATH="$herdr_dir/fixtures/herdr-project-api-fixture.sh" \
HERDR_FIXTURE_REAL_BIN="$herdr" HERDR_FIXTURE_MODE=slow-create \
HERDR_PROJECT_LOCK_ROOT="$runtime" \
HERDR_PROJECT_SELECTION="$concurrent_project" \
  "$picker" >"$runtime/concurrent-first.log" 2>&1 &
concurrent_pid=$!
active_lock="$runtime/herdr-project-picker-$session.lock"
wait_for "atomically published project-picker lock" test -L "$active_lock"
active_lock_owner=$(readlink "$active_lock")
case "$active_lock_owner" in
  ""|*[!0-9]*)
    echo "project-picker lock did not publish a numeric owner" >&2
    exit 1
    ;;
esac
kill -0 "$active_lock_owner"
if HERDR_PROJECT_SESSION="$session" \
    HERDR_PROJECT_LOCK_ROOT="$runtime" \
    HERDR_PROJECT_SELECTION="$concurrent_project" \
    "$picker" >"$runtime/concurrent-second.log" 2>&1
then
  echo "concurrent project picker did not reject the locked mutation" >&2
  exit 1
fi
wait "$concurrent_pid"
concurrent_workspace=$(workspace_for_cwd "$concurrent_project")
test -n "$concurrent_workspace"
test "$(workspace_count)" -eq $((before_concurrent + 1))
stale_lock="$runtime/herdr-project-picker-$session.lock"
mkdir "$stale_lock"
printf '%s\n' 999999999 >"$stale_lock/owner"
HERDR_PROJECT_SESSION="$session" \
HERDR_PROJECT_LOCK_ROOT="$runtime" \
HERDR_PROJECT_SELECTION="$concurrent_project" "$picker"
test ! -e "$stale_lock"
test "$(workspace_count)" -eq $((before_concurrent + 1))
record concurrency "$(jq -cn --arg workspace "$concurrent_workspace" \
  '{session_lock_serializes_check_and_create:true,
    lock_owner_published_atomically:true,
    competing_picker_rejected:true,duplicate_created:false,
    stale_dead_owner_lock_recovered:true,
    workspace_id:$workspace}')"

before_foreign=$(workspace_count)
HERDR_PROJECT_SESSION="$foreign_session" \
HERDR_PROJECT_SELECTION="$alpha" "$picker"
foreign_alpha_workspace=$(foreign_workspace_for_cwd "$alpha")
test -n "$foreign_alpha_workspace"
test "$(workspace_count)" -eq "$before_foreign"
record isolation "$(jq -cn --arg foreign "$foreign_alpha_workspace" \
  '{named_session_isolated:true,foreign_workspace_id:$foreign,
    main_workspace_count_unchanged:true}')"

rm -f "$driver_fifo"
mkfifo "$driver_fifo"
"$prototype/picker_client.py" "$herdr" "$config_home" "$config" \
  "$session" "$prototype" "$screen" <"$driver_fifo" >"$driver_log" 2>&1 &
driver_pid=$!
exec 3>"$driver_fifo"
wait_for "project-picker client" grep -q '^READY$' "$driver_log"
project_picker_action=$(printf 'type:\001W')
send_action "$project_picker_action"
send_action type:alpha-feature
send_action enter
wait_for "popup-created linked worktree" \
  workspace_exists_for_cwd "$alpha_feature"
feature_workspace=$(workspace_for_cwd "$alpha_feature")
test "$(focused_workspace)" = "$feature_workspace"
count_after_popup=$(workspace_count)
send_action "$project_picker_action"
send_action type:alpha-feature
send_action enter
wait_for "popup-reused linked worktree" \
  workspace_count_is "$count_after_popup"
test "$(workspace_count)" -eq "$count_after_popup"
test "$(focused_workspace)" = "$feature_workspace"
record popup "$(jq -cn --arg workspace "$feature_workspace" \
  --argjson count "$count_after_popup" \
  '{binding:"prefix+Shift+w",session_modal_popup:true,
    real_fzf_selection:true,linked_worktree_created_as_workspace:true,
    second_selection_reused:true,
    focused_workspace_id:$workspace,workspace_count:$count}')"

production_after=$(production_state)
test "$production_after" = "$production_before"
record scope_audit "$(jq -cn \
  --arg picker_hash "$(shasum -a 256 "$picker" | awk '{print $1}')" \
  --arg validator_hash "$(shasum -a 256 "$herdr_dir/validate_project_picker.sh" | awk '{print $1}')" \
  --arg client_hash "$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')" \
  --arg config_hash "$(shasum -a 256 "$herdr_dir/config.toml" | awk '{print $1}')" \
  --argjson production "$production_after" \
  '{unchanged:true,production_state:$production,
    artifact_sha256:{picker:$picker_hash,validator:$validator_hash,
      client:$client_hash,config:$config_hash}}')"
record result "$(jq -cn \
  '{status:"PASS",version:"herdr 0.7.4",session:"project-picker",
    pane_history:false,tmux_available:true,herdr_upgraded:false,
    git_worktrees_created:false,production_runtime_modified:false}')"

mv "$evidence_tmp" "$evidence"
printf 'Herdr project-picker validation: PASS (%s)\n' "$evidence"
