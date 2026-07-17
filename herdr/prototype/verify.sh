#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
prototype="$root/herdr/prototype"
tab_lifecycle_evidence=${HERDR_TAB_LIFECYCLE_EVIDENCE:-"$prototype/evidence/tab-lifecycle-validation.jsonl"}
picker_evidence=${HERDR_PICKER_EVIDENCE:-"$prototype/evidence/picker-validation.jsonl"}

test -x "$prototype/run.sh"
test -x "$prototype/live_ghostty.sh"
test -x "$prototype/launch_live_ghostty.sh"
test -x "$prototype/prepare_live_trial.sh"
test -x "$prototype/smart_nav.sh"
test -x "$prototype/chafa_preview.sh"
test -x "$prototype/native_preview.sh"
test -x "$prototype/adaptive_split.sh"
test -x "$prototype/focused_pane.sh"
test -x "$prototype/open_visible_url.sh"
test -x "$prototype/prototype_shell.sh"
test -x "$prototype/shell_action.sh"
test -x "$prototype/smart_close.sh"
test -x "$prototype/swap_pane.sh"
test -x "$prototype/validate_bindings.sh"
test -x "$prototype/close_other_tabs.sh"
test -x "$prototype/tab-history/tab_history.sh"
test -f "$prototype/tab-history/herdr-plugin.toml"
test -x "$prototype/tab_client.py"
test -x "$prototype/picker_client.py"
test -x "$prototype/tab_move.sh"
test -x "$prototype/validate_tabs.sh"
test -x "$prototype/validate_picker.sh"
test -f "$tab_lifecycle_evidence"
test -f "$picker_evidence"
test -f "$prototype/fixtures/preview-amber.png"
test -f "$prototype/fixtures/preview-blue.png"
test -f "$prototype/fixtures/preview-green.png"
test -f "$prototype/herdr_nav.fish"
test -x "$prototype/golden-focus/golden_focus.sh"
test -f "$prototype/golden-focus/herdr-plugin.toml"
test -f "$prototype/config.toml"
test -f "$prototype/herdr_nav.lua"
test -f "$prototype/screenshots/expanded.png"
test -f "$prototype/screenshots/collapsed.png"
test -f "$prototype/screenshots/chafa-final.png"
test -f "$prototype/screenshots/native-preview-retry.png"
test -f "$prototype/screenshots/native-preview-acceptance.png"
test -f "$prototype/screenshots/native-preview-clean.png"
test -f "$prototype/screenshots/native-preview-cleared.png"
test -f "$prototype/screenshots/native-preview-cycle-amber.png"
test -f "$prototype/screenshots/native-preview-cycle-blue.png"
test -f "$prototype/screenshots/native-preview-focus-right.png"

grep -q '"method":"pane.graphics.set"' "$prototype/native_preview.sh"
grep -q 'viewport_col.*grid_cols' "$prototype/native_preview.sh"
grep -q 'chafa_preview.sh' "$prototype/native_preview.sh"
grep -q 'lockf -t 3' "$prototype/native_preview.sh"
grep -q 'is_latest' "$prototype/native_preview.sh"
grep -q 'sips -s format png -z' "$prototype/native_preview.sh"
grep -q 'available_cols - grid_cols' "$prototype/native_preview.sh"
grep -q 'resize:refresh-preview' "$prototype/prepare_live_trial.sh"
grep -q 'cd \$prototype/fixtures' "$prototype/prepare_live_trial.sh"

grep -q '^name = "catppuccin"$' "$prototype/config.toml"
grep -q '^prefix = "ctrl+a"$' "$prototype/config.toml"
grep -q '^default_shell = "/Users/eddyekofo/.dotfiles/herdr/prototype/prototype_shell.sh"$' "$prototype/config.toml"
grep -q '^new_tab = "prefix+c"$' "$prototype/config.toml"
grep -q '^next_tab = "prefix+n"$' "$prototype/config.toml"
grep -q '^previous_tab = "prefix+p"$' "$prototype/config.toml"
grep -q '^workspace_picker = "prefix+w"$' "$prototype/config.toml"
grep -q '^goto = "prefix+f"$' "$prototype/config.toml"
grep -q '^resize_mode = "prefix+r"$' "$prototype/config.toml"
grep -q '^copy_mode = "prefix+s"$' "$prototype/config.toml"
grep -q '^toggle_sidebar = "prefix+shift+s"$' "$prototype/config.toml"
grep -q '^split_vertical = "prefix+v"$' "$prototype/config.toml"
grep -q '^split_horizontal = ""$' "$prototype/config.toml"
grep -q '^close_pane = ""$' "$prototype/config.toml"
grep -q '^close_tab = "prefix+shift+x"$' "$prototype/config.toml"
grep -q '^last_pane = "prefix+tab"$' "$prototype/config.toml"
grep -q '^key = "prefix+a"$' "$prototype/config.toml"
grep -q '^key = "prefix+x"$' "$prototype/config.toml"
grep -q '^key = "prefix+u"$' "$prototype/config.toml"
for key in h j k l; do
  grep -q "^key = \"prefix+shift+$key\"$" "$prototype/config.toml"
done
test "$(grep -c '^key = ' "$prototype/config.toml")" -eq 9
if grep -Eq 'prefix\+(b|shift\+b)' "$prototype/config.toml"; then
  echo "prefix+b/B must remain reserved and unassigned" >&2
  exit 1
fi
duplicates=$(awk -F'"' '/^key = "/ { print $2 }' "$prototype/config.toml" | sort | uniq -d)
if [ -n "$duplicates" ]; then
  printf 'duplicate prototype command binding(s):\n%s\n' "$duplicates" >&2
  exit 1
fi
if grep -Eq '^(key = )?"?alt\+(v|n|q|x|z)|^key = "alt\+shift\+x"' "$prototype/config.toml"; then
  echo "application-owned Alt chords must not be global Herdr bindings" >&2
  exit 1
fi
if grep -Eiq '(^|["[:space:]])(alt\+ctrl\+f|ctrl\+alt\+f)(["[:space:]]|$)' \
  "$prototype/config.toml"; then
  echo "searchable picker must remain prefix-only at prefix+f" >&2
  exit 1
fi
grep -q '^sidebar_collapsed_mode = "hidden"$' "$prototype/config.toml"
grep -q '^pane_gaps = false$' "$prototype/config.toml"
grep -q '^hide_tab_bar_when_single_tab = true$' "$prototype/config.toml"
grep -q '^delivery = "off"$' "$prototype/config.toml"
grep -q '^enabled = false$' "$prototype/config.toml"

if [ -x "$prototype/.runtime/bin/herdr" ]; then
  "$prototype/run.sh" cli config check
  "$prototype/run.sh" --border boxed cli config check
  "$prototype/run.sh" --border focused cli config check
  "$prototype/run.sh" --border borderless cli config check

  grep -q '^pane_gaps = true$' "$prototype/.runtime/cb/herdr/config.toml"
  grep -q '^pane_gaps = true$' "$prototype/.runtime/cf/herdr/config.toml"
  grep -q '^overlay0 = "#1e1e2e"$' "$prototype/.runtime/cf/herdr/config.toml"
  test "$(grep -c '^type = "shell"$' "$prototype/.runtime/cf/herdr/config.toml")" -eq 7
  if grep -Eq '^key = "(alt|ctrl\+alt)\+(h|j|k|l)"$' \
    "$prototype/.runtime/cf/herdr/config.toml"; then
    echo "focused prototype must pass physical Alt through to pane applications" >&2
    exit 1
  fi
  grep -q 'bind --mode.*\\eh.*__herdr_nav h left' "$prototype/herdr_nav.fish"
  grep -q '^type = "plugin_action"$' "$prototype/.runtime/cf/herdr/config.toml"
  grep -q '^command = "prototype.golden-focus.toggle"$' "$prototype/.runtime/cf/herdr/config.toml"
  grep -q '^pane_borders = false$' "$prototype/.runtime/cl/herdr/config.toml"
fi

grep -q 'bind --mode.*\\ev.*split-right' "$prototype/herdr_nav.fish"
grep -q 'bind --mode.*\\en.*split-adaptive' "$prototype/herdr_nav.fish"
grep -q 'bind --mode.*\\eq.*close-pane' "$prototype/herdr_nav.fish"
grep -q 'bind --mode.*\\eX.*close-tab' "$prototype/herdr_nav.fish"
grep -q 'bind --mode.*\\ez.*zoom' "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[118;3u'" "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[110;3u'" "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[113;3u'" "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[122;3u'" "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[88;3u'" "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[120;4u'" "$prototype/herdr_nav.fish"
if grep -Eq "\\\\ex.*close-pane|120;3u.*close-pane" "$prototype/herdr_nav.fish"; then
  echo "Alt-x must remain application-owned and unbound in the Fish adapter" >&2
  exit 1
fi
fish --no-config -n "$prototype/herdr_nav.fish"
grep -q 'export XDG_CONFIG_HOME="$user_config_home"' "$prototype/prototype_shell.sh"
grep -q 'export TMUX=HERDR_PROTOTYPE_STARTUP_GUARD' "$prototype/prototype_shell.sh"
grep -q 'set -e TMUX; source' "$prototype/prototype_shell.sh"
for script in "$prototype"/*.sh; do sh -n "$script"; done
sh -n "$prototype/tab-history/tab_history.sh"
python3 -c 'import sys; compile(open(sys.argv[1]).read(), "tab_client.py", "exec")' \
  "$prototype/tab_client.py"
python3 -c 'import sys; compile(open(sys.argv[1]).read(), "picker_client.py", "exec")' \
  "$prototype/picker_client.py"
jq -se '
  def nonempty_string: type == "string" and length > 0;
  def positive_integer: type == "number" and floor == . and . > 0;

  ["config", "reorder_api", "create", "cycle", "indexed", "last_tab",
   "reorder", "close", "close_others", "result"] as $expected_checks |
  map(.check) as $checks |
  .[2].evidence.tabs as $tabs |
  .[2].evidence.sentinels as $sentinels |
  ($tabs | map(.tab_id)) as $tab_ids |
  ($sentinels | map(.pid)) as $sentinel_pids |

  length == ($expected_checks | length) and
  $checks == $expected_checks and
  ($checks | unique | length) == ($checks | length) and
  all(.[]; type == "object" and keys == ["check", "evidence"] and
      (.check | nonempty_string) and (.evidence | type == "object")) and

  .[0].evidence == {result:"config: ok"} and

  .[1].evidence.version == "herdr 0.7.4" and
  .[1].evidence.method == "tab.move" and
  .[1].evidence.params.type == "object" and
  .[1].evidence.params.required == ["tab_id", "insert_index"] and
  .[1].evidence.params.properties.tab_id.type == "string" and
  .[1].evidence.params.properties.insert_index ==
    {format:"uint", minimum:0, type:"integer"} and

  ($tabs | type == "array" and length == 4) and
  ($tab_ids | (all(.[]; nonempty_string) and (unique | length == 4))) and
  ($tabs | map(.number)) == [1, 2, 3, 4] and
  ($tabs | map(.label)) == ["1", "2", "3", "4"] and
  ($tabs | map(.focused)) == [false, false, false, true] and
  ($tabs | all(.[];
    .workspace_id == "w1" and .pane_count == 1 and
    (.tab_id | nonempty_string) and (.agent_status | nonempty_string))) and
  ($sentinels | type == "array" and length == 4) and
  ($sentinels | map(.tab_id)) == $tab_ids and
  ($sentinel_pids |
    (all(.[]; positive_integer) and (unique | length == 4))) and

  .[3].evidence ==
    {start:$tab_ids[3], next:$tab_ids[0], previous:$tab_ids[3]} and
  .[4].evidence == {binding:"prefix+2", focused_tab:$tab_ids[1]} and
  .[5].evidence.previous_tab == $tab_ids[1] and
  .[5].evidence.from_tab == $tab_ids[2] and
  .[5].evidence.result == $tab_ids[1] and
  (.[5].evidence.second_pane_in_from_tab | nonempty_string) and

  .[6].evidence.moved_tab == $tab_ids[2] and
  .[6].evidence.sentinel_pid == $sentinel_pids[2] and
  .[6].evidence.before == $tab_ids and
  .[6].evidence.after_right ==
    [$tab_ids[0], $tab_ids[1], $tab_ids[3], $tab_ids[2]] and
  .[6].evidence.restored == $tab_ids and

  (.[7].evidence.closed_tab | nonempty_string) and
  ([.[7].evidence.closed_tab] - $tab_ids | length) == 1 and
  (.[7].evidence.sentinel_pid | positive_integer) and
  ([.[7].evidence.sentinel_pid] - $sentinel_pids | length) == 1 and
  .[7].evidence.tab_absent == true and
  .[7].evidence.sentinel_dead == true and

  .[8].evidence.first_press_preserved_tabs == $tab_ids and
  .[8].evidence.survivor_tab == $tab_ids[1] and
  .[8].evidence.survivor_pid == $sentinel_pids[1] and
  .[8].evidence.closed_target_pids ==
    [$sentinel_pids[0], $sentinel_pids[2], $sentinel_pids[3]] and
  .[8].evidence.confirmation_required == true and

  .[9].evidence == {
    status:"PASS",
    session:"gate-tabs",
    production_configuration_modified:false,
    migration_authorized:false
  }
' "$tab_lifecycle_evidence" >/dev/null

picker_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
picker_client_hash=$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')
picker_validator_hash=$(shasum -a 256 "$prototype/validate_picker.sh" | awk '{print $1}')
jq -se \
  --arg config_hash "$picker_config_hash" \
  --arg client_hash "$picker_client_hash" \
  --arg validator_hash "$picker_validator_hash" '
  def nonempty_string: type == "string" and length > 0;
  def positive_integer: type == "number" and floor == . and . > 0;

  ["config", "topology", "open_bindings", "search", "state_filters",
   "selection", "return_paths", "process_safety", "session_boundary",
   "scope_audit", "result"] as $expected_checks |
  map(.check) as $checks |
  .[1].evidence as $topology |
  ($topology.panes | map(.id)) as $pane_ids |
  ($topology.sentinels | map(.pid)) as $sentinel_pids |

  length == ($expected_checks | length) and
  $checks == $expected_checks and
  ($checks | unique | length) == ($checks | length) and
  all(.[]; type == "object" and keys == ["check", "evidence"] and
      (.check | nonempty_string) and (.evidence | type == "object")) and

  .[0].evidence == {
    approved_bindings:[
      "prefix=ctrl+a",
      "focus=prefix+h/j/k/l",
      "swap=prefix+H/J/K/L",
      "resize=prefix+r",
      "fixed_split=prefix+v",
      "adaptive_split=prefix+a",
      "copy_search=prefix+s",
      "smart_close=prefix+x",
      "close_tab=prefix+X",
      "tabs=prefix+c/n/p",
      "zoom=prefix+z",
      "sidebar=prefix+S",
      "ready_prompt=prefix+b/B reserved",
      "open_url=prefix+u",
      "workspace_picker=prefix+w",
      "goto=prefix+f",
      "scratch_popup=prefix+Enter",
      "lazygit_popup=prefix+g"
    ],
    result:"config: ok",
    workspace_picker:"prefix+w",
    goto:"prefix+f",
    direct_alt_ctrl_f:false,
    prefix_enter_preserved:true,
    prefix_g_preserved:true
  } and

  ($topology.workspaces | map(.label)) == ["Alpha Project", "Beta Project"] and
  ($topology.tabs | map(.label)) == ["Overview", "Weekly Review"] and
  ($topology.panes | map(.label)) ==
    ["BLOCKED SENTINEL", "WORKING SENTINEL", "IDLE SENTINEL", "DONE SENTINEL"] and
  ($topology.panes | map(.status)) == ["blocked", "working", "idle", "done"] and
  ($pane_ids | all(.[]; nonempty_string) and (unique | length == 4)) and
  ($topology.sentinels | length == 4 and all(.[]; (.pane | nonempty_string) and (.pid | positive_integer))) and
  ($topology.sentinels | map(.pane)) == $pane_ids and
  ($sentinel_pids | unique | length) == 4 and

  .[2].evidence.workspace_picker.binding == "prefix+w" and
  .[2].evidence.workspace_picker.search_overlay == false and
  (.[2].evidence.workspace_picker.line | contains("Alpha Project")) and
  .[2].evidence.workspace_picker.focused_workspace_after_down_enter == $topology.workspaces[1].id and
  .[2].evidence.goto.binding == "prefix+f" and
  .[2].evidence.goto.search_overlay == true and
  .[2].evidence.goto.current_selected == true and
  (.[2].evidence.goto.line | contains("BLOCKED SENTINEL")) and

  .[3].evidence.case_insensitive_multi_term.query == "ALPHA PROJECT" and
  (.[3].evidence.case_insensitive_multi_term.match | contains("Alpha Project")) and
  .[3].evidence.case_insensitive_multi_term.nonmatch == "Beta Project" and
  .[3].evidence.tab_query.query == "weekly review" and
  (.[3].evidence.tab_query.match | contains("Weekly Review")) and
  .[3].evidence.tab_query.nonmatch == "Done Queue" and
  .[3].evidence.pane_query.query == "idle sentinel" and
  (.[3].evidence.pane_query.match | contains("IDLE SENTINEL")) and
  .[3].evidence.pane_query.nonmatch == "BLOCKED SENTINEL" and

  (.[4].evidence.blocked | contains("BLOCKED SENTINEL")) and
  (.[4].evidence.working | contains("WORKING SENTINEL")) and
  (.[4].evidence.idle | contains("IDLE SENTINEL")) and
  (.[4].evidence.done | contains("DONE SENTINEL")) and
  .[4].evidence.clear_restored == true and

  .[5].evidence.workspace == {focused:$topology.workspaces[1].id, terminal_mode:true} and
  .[5].evidence.tab == {focused:$topology.tabs[1].id, terminal_mode:true} and
  .[5].evidence.pane == {focused:$topology.panes[2].id, terminal_mode:true} and

  .[6].evidence.search_escape.returned_to_navigator == true and
  .[6].evidence.search_escape.focus_unchanged == $topology.panes[0].id and
  (.[6].evidence.search_escape.line | contains("BLOCKED SENTINEL")) and
  .[6].evidence.outer_escape == {returned_to_terminal:true, focus_unchanged:$topology.panes[0].id} and
  .[6].evidence.no_match_enter == {no_op:true, focus_unchanged:$topology.panes[0].id} and
  .[6].evidence.stale_target_enter == {no_op:true, focus_unchanged:$topology.panes[0].id} and

  .[7].evidence.sentinels == $topology.sentinels and
  .[7].evidence.all_alive_after_picker_paths == true and
  .[7].evidence.objects_before == .[7].evidence.objects_after and
  (.[7].evidence.objects_before.workspaces | length) == 2 and
  (.[7].evidence.objects_before.tabs | length) == 3 and
  (.[7].evidence.objects_before.panes | length) == 4 and
  .[7].evidence.runtime_objects_unchanged == true and

  .[8].evidence.named_sessions == ["pa", "pb"] and
  .[8].evidence.session_a_navigator.contains == "Alpha Project" and
  .[8].evidence.session_a_navigator.excludes == "Foreign Session B" and
  .[8].evidence.explicit_attach_session_b.contains == "Foreign Session B" and
  .[8].evidence.explicit_attach_session_b.excludes == "Alpha Project" and

  .[9].evidence.unchanged == true and
  .[9].evidence.production_hashes_before == .[9].evidence.production_hashes_after and
  (.[9].evidence.production_hashes_before | keys) ==
    ["fish/config.fish", "fish/functions/fe.fish", "ghostty/config", "tmux/tmux.conf", "~/.config/nvim/lua/plugin/tmux.lua"] and

  .[10].evidence == {
    artifact_hashes:{
      "config.toml":$config_hash,
      "picker_client.py":$client_hash,
      "validate_picker.sh":$validator_hash
    },
    status:"PASS",
    version:"herdr 0.7.4",
    session:"pa",
    production_configuration_modified:false,
    migration_authorized:false,
    validation_plan_steps:7
  }
' "$picker_evidence" >/dev/null

nvim_config=${XDG_CONFIG_HOME:-"$HOME/.config"}/nvim/lua/plugin/tmux.lua
if [ ! -f "$nvim_config" ]; then
  echo "production Neovim tmux adapter not found: $nvim_config" >&2
  exit 1
fi

if grep -q 'HERDR_PANE_ID\|herdr pane' "$nvim_config"; then
  echo "production Neovim tmux adapter contains Herdr prototype code" >&2
  exit 1
fi

echo "Herdr prototype verification: PASS"
