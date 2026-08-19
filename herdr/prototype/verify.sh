#!/bin/sh
set -eu

# HERDR_VERIFY_AUDIT is owned by herdr/verify.sh, which runs the extra audit
# validators itself and only then delegates here. This script has no audit block,
# so honouring the flag silently was fail-open: an operator who ran
# `HERDR_VERIFY_AUDIT=1 sh herdr/prototype/verify.sh` got a PASS that had skipped
# the whole audit. Refuse instead. The owning gate clears the flag when it
# delegates, so this never fires from a real audit run.
if [ "${HERDR_VERIFY_AUDIT:-0}" = 1 ]; then
  echo "HERDR_VERIFY_AUDIT is owned by herdr/verify.sh; this gate has no audit block." >&2
  echo "Run: HERDR_VERIFY_AUDIT=1 sh herdr/verify.sh" >&2
  exit 2
fi

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
prototype="$root/herdr/prototype"
tab_lifecycle_evidence=${HERDR_TAB_LIFECYCLE_EVIDENCE:-"$prototype/evidence/tab-lifecycle-validation.jsonl"}
picker_evidence=${HERDR_PICKER_EVIDENCE:-"$prototype/evidence/picker-validation.jsonl"}
ready_prompt_evidence=${HERDR_READY_PROMPT_EVIDENCE:-"$prototype/evidence/ready-prompt-validation.jsonl"}
pane_lifecycle_evidence=${HERDR_PANE_LIFECYCLE_EVIDENCE:-"$prototype/evidence/pane-lifecycle-validation.jsonl"}
agent_state_evidence=${HERDR_AGENT_STATE_EVIDENCE:-"$prototype/evidence/agent-state-validation.jsonl"}
multi_agent_evidence=${HERDR_MULTI_AGENT_EVIDENCE:-"$prototype/evidence/multi-agent-compat-validation.jsonl"}
login_attach_evidence=${HERDR_LOGIN_ATTACH_EVIDENCE:-"$prototype/evidence/login-attach-validation.jsonl"}
popup_evidence=${HERDR_POPUP_EVIDENCE:-"$prototype/evidence/popup-validation.jsonl"}
layout_menu_evidence=${HERDR_LAYOUT_MENU_EVIDENCE:-"$prototype/evidence/layout-menu-validation.jsonl"}
copy_mode_evidence=${HERDR_COPY_MODE_EVIDENCE:-"$prototype/evidence/copy-mode-validation.jsonl"}
recovery_evidence=${HERDR_RECOVERY_EVIDENCE:-"$prototype/evidence/recovery-validation.jsonl"}
workspace_navigation_evidence=${HERDR_WORKSPACE_NAVIGATION_EVIDENCE:-"$prototype/evidence/workspace-navigation-validation.jsonl"}
url_evidence=${HERDR_URL_EVIDENCE:-"$prototype/evidence/url-validation.jsonl"}
binding_evidence=${HERDR_BINDING_EVIDENCE:-"$prototype/evidence/binding-validation.jsonl"}
remote_evidence=${HERDR_REMOTE_EVIDENCE:-"$prototype/evidence/remote-validation.jsonl"}
capability_gap_evidence=${HERDR_CAPABILITY_GAP_EVIDENCE:-"$prototype/evidence/capability-gap-validation.jsonl"}
utility_parity_evidence=${HERDR_UTILITY_PARITY_EVIDENCE:-"$prototype/evidence/utility-parity-validation.jsonl"}
picker_reference_evidence=${HERDR_PICKER_REFERENCE_EVIDENCE:-"$prototype/evidence/picker-reference-validation.jsonl"}
agent_overview_evidence=${HERDR_AGENT_OVERVIEW_EVIDENCE:-"$prototype/evidence/agent-overview-validation.jsonl"}

test -x "$prototype/run.sh"
test -x "$prototype/live_ghostty.sh"
test -x "$prototype/launch_live_ghostty.sh"
test -x "$prototype/prepare_live_trial.sh"
test -x "$prototype/smart_nav.sh"
test -x "$prototype/chafa_preview.sh"
test -x "$prototype/native_preview.sh"
test -x "$prototype/numbered_tab.sh"
test -x "$prototype/new_tab.sh"
test -x "$prototype/adaptive_split.sh"
test -x "$prototype/focused_pane.sh"
test -x "$prototype/open_visible_url.sh"
test -x "$prototype/ready_prompt.sh"
test -x "$prototype/ready_prompt_agent_fixture.sh"
test -x "$prototype/prototype_shell.sh"
test -x "$prototype/shell_action.sh"
test -x "$prototype/smart_close.sh"
test -x "$prototype/swap_pane.sh"
test -x "$prototype/validate_bindings.sh"
test -x "$prototype/close_other_tabs.sh"
test -x "$prototype/close_other_panes.sh"
test -x "$prototype/equalize_panes.sh"
test -x "$prototype/layout_preset.sh"
test -x "$prototype/pane_transfer.sh"
test -x "$prototype/export_history.sh"
test -x "$prototype/tab_edge.sh"
test -x "$prototype/manage_objects.sh"
test -x "$prototype/visible_reference_picker.sh"
test -x "$prototype/visible_references.py"
test -x "$prototype/agent_overview.sh"
test -x "$prototype/agent_message_composer.py"
test -x "$prototype/fixtures/pane_transfer_picker_fixture.sh"
test -x "$prototype/fixtures/picker_reference_herdr_fixture.sh"
test -x "$prototype/fixtures/manage_picker_fixture.sh"
test -x "$prototype/fixtures/reference_picker_fixture.sh"
test -x "$prototype/fixtures/reference_clipboard_fixture.sh"
test -x "$prototype/fixtures/reference_opener_fixture.sh"
test -x "$prototype/fixtures/agent_overview_herdr_fixture.sh"
test -x "$prototype/validate_utilities.sh"
test -x "$prototype/validate_picker_reference.sh"
test -x "$prototype/validate_agent_overview.sh"
test -x "$prototype/tab-history/tab_history.sh"
test -f "$prototype/tab-history/herdr-plugin.toml"
test -x "$prototype/tab_client.py"
test -x "$prototype/picker_client.py"
test -x "$prototype/copy_mode_client.py"
test -x "$prototype/tab_move.sh"
test -x "$prototype/validate_tabs.sh"
test -x "$prototype/validate_picker.sh"
test -x "$prototype/validate_ready_prompt.sh"
test -x "$prototype/ready_prompt_parser.sh"
test -x "$prototype/tests/ready_prompt_parser_test.sh"
test -x "$prototype/validate_panes.sh"
test -x "$prototype/semantic_agent_state.py"
test -x "$prototype/validate_agent_states.sh"
test -x "$prototype/validate_multi_agent_compat.sh"
test -f "$prototype/herdr_login_attach.fish"
test -x "$root/herdr/window_session.sh"
test -x "$prototype/login_attach_fixture.sh"
test -x "$prototype/validate_login_attach.sh"
test -x "$prototype/popup_fixture.sh"
test -x "$prototype/validate_popups.sh"
test -x "$prototype/layout_menu.sh"
test -x "$prototype/validate_layout_menu.sh"
test -x "$prototype/validate_copy_mode.sh"
test -x "$prototype/recovery_agent_fixture.sh"
test -x "$prototype/validate_recovery.sh"
test -x "$prototype/validate_workspace_navigation.sh"
test -x "$prototype/validate_urls.sh"
test -x "$prototype/validate_remote.sh"
test -x "$prototype/validate_capability_gaps.sh"
test -f "$tab_lifecycle_evidence"
test -f "$picker_evidence"
test -f "$ready_prompt_evidence"
test -f "$pane_lifecycle_evidence"
test -f "$agent_state_evidence"
test -f "$multi_agent_evidence"
test -f "$login_attach_evidence"
test -f "$popup_evidence"
test -f "$layout_menu_evidence"
test -f "$copy_mode_evidence"
test -f "$recovery_evidence"
test -f "$workspace_navigation_evidence"
test -f "$url_evidence"
test -f "$binding_evidence"
test -f "$remote_evidence"
test -f "$capability_gap_evidence"
test -f "$utility_parity_evidence"
test -f "$picker_reference_evidence"
test -f "$agent_overview_evidence"
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
grep -Fq 'next_tab = ["prefix+n", "alt+ctrl+n", "alt+ctrl+right"]' "$prototype/config.toml"
grep -Fq 'previous_tab = ["prefix+p", "alt+ctrl+p", "alt+ctrl+left"]' "$prototype/config.toml"
grep -q '^workspace_picker = "prefix+w"$' "$prototype/config.toml"
grep -q '^goto = "prefix+f"$' "$prototype/config.toml"
grep -q '^resize_mode = "prefix+r"$' "$prototype/config.toml"
grep -Eq '^copy_mode = (\["prefix\+s".*\]|"prefix\+s")$' "$prototype/config.toml"
grep -q '^toggle_sidebar = "prefix+shift+s"$' "$prototype/config.toml"
grep -q '^split_vertical = "prefix+v"$' "$prototype/config.toml"
grep -q '^split_horizontal = ""$' "$prototype/config.toml"
grep -q '^close_pane = ""$' "$prototype/config.toml"
grep -q '^close_tab = "prefix+shift+x"$' "$prototype/config.toml"
grep -q '^previous_workspace = "prefix+("$' "$prototype/config.toml"
grep -q '^next_workspace = "prefix+)"$' "$prototype/config.toml"
grep -Fq 'last_pane = ["prefix+tab", "ctrl+^"]' "$prototype/config.toml"
grep -q '^key = "prefix+a"$' "$prototype/config.toml"
grep -q '^key = "prefix+x"$' "$prototype/config.toml"
grep -q '^key = "prefix+u"$' "$prototype/config.toml"
for key in h j k l; do
  grep -q "^key = \"prefix+shift+$key\"$" "$prototype/config.toml"
done
test "$(grep -c '^key = ' "$prototype/config.toml")" -eq 44
grep -q '^key = "alt+ctrl+t"$' "$prototype/config.toml"
grep -q 'new_tab.sh' "$prototype/config.toml"
if grep -q '^key = "alt+t"$' "$prototype/config.toml"; then
  echo "Alt-t must remain application-owned and unbound in Herdr" >&2
  exit 1
fi
grep -q '^key = "prefix+b"$' "$prototype/config.toml"
grep -q '^key = "prefix+shift+b"$' "$prototype/config.toml"
grep -q 'ready_prompt.sh' "$prototype/config.toml"
grep -q 'ready_prompt.sh.*--clear' "$prototype/config.toml"
grep -Fq 'bracketed_prompt=$(printf' "$prototype/ready_prompt.sh"
grep -Fq '\033[200~%s\033[201~' "$prototype/ready_prompt.sh"
grep -q '^key = "prefix+o"$' "$prototype/config.toml"
grep -q '^key = "prefix+="$' "$prototype/config.toml"
grep -q '^key = "prefix+space"$' "$prototype/config.toml"
grep -q 'layout_menu.sh' "$prototype/config.toml"
grep -q '^width = 54$' "$prototype/config.toml"
grep -q '^height = 20$' "$prototype/config.toml"
grep -q '^key = "prefix+shift+p"$' "$prototype/config.toml"
grep -q 'pane_transfer.sh' "$prototype/config.toml"
grep -q '^key = "prefix+shift+u"$' "$prototype/config.toml"
grep -q 'export_history.sh' "$prototype/config.toml"
grep -Fq 'key = "prefix+^"' "$prototype/config.toml"
grep -Fq 'key = "prefix+$"' "$prototype/config.toml"
grep -q 'tab_edge.sh.*first' "$prototype/config.toml"
grep -q 'tab_edge.sh.*last' "$prototype/config.toml"
grep -q '^key = "prefix+shift+f"$' "$prototype/config.toml"
grep -q 'manage_objects.sh' "$prototype/config.toml"
grep -q '^key = "prefix+shift+r"$' "$prototype/config.toml"
grep -q 'visible_reference_picker.sh' "$prototype/config.toml"
grep -q '^key = "prefix+shift+a"$' "$prototype/config.toml"
grep -q 'agent_overview.sh' "$prototype/config.toml"
if grep -q 'layout\.apply' "$prototype/layout_preset.sh"; then
  echo "process-preserving layout presets must not call layout.apply" >&2
  exit 1
fi
for digit in 0 1 2 3 4 5 6 7 8 9; do
  grep -q "^key = \"prefix+$digit\"$" "$prototype/config.toml"
done
duplicates=$(awk -F'"' '/^key = "/ { print $2 }' "$prototype/config.toml" | sort | uniq -d)
if [ -n "$duplicates" ]; then
  printf 'duplicate prototype command binding(s):\n%s\n' "$duplicates" >&2
  exit 1
fi
for key in h j k l v n q o = z 'shift+x' 'ctrl+x'; do
  grep -Fq "key = \"alt+$key\"" "$prototype/config.toml"
done
grep -Fq 'command = "exec \"$HERDR_PROTOTYPE_DIR/smart_nav.sh\" h left"' \
  "$prototype/config.toml"
grep -Fq 'command = "exec \"$HERDR_PROTOTYPE_DIR/smart_action.sh\" v split-right"' \
  "$prototype/config.toml"
grep -Fq 'command = "exec \"$HERDR_PROTOTYPE_DIR/smart_action.sh\" ctrl+x close-other-tabs"' \
  "$prototype/config.toml"
if grep -Eiq '(^|["[:space:]])(alt\+ctrl\+f|ctrl\+alt\+f)(["[:space:]]|$)' \
  "$prototype/config.toml"; then
  echo "searchable picker must remain prefix-only at prefix+f" >&2
  exit 1
fi
grep -q '^sidebar_collapsed_mode = "hidden"$' "$prototype/config.toml"
grep -q '^pane_gaps = false$' "$prototype/config.toml"
grep -q '^hide_tab_bar_when_single_tab = true$' "$prototype/config.toml"
grep -Fq 'rows = [["state_icon", "workspace", "tab"], ["agent", "$semantic_state"]]' "$prototype/config.toml"
grep -q '^delivery = "herdr"$' "$prototype/config.toml"
grep -q '^enabled = false$' "$prototype/config.toml"

if [ -x "$prototype/.runtime/bin/herdr" ]; then
  "$prototype/run.sh" cli config check
  "$prototype/run.sh" --border boxed cli config check
  "$prototype/run.sh" --border focused cli config check
  "$prototype/run.sh" --border borderless cli config check

  grep -q '^pane_gaps = true$' "$prototype/.runtime/cb/herdr/config.toml"
  grep -q '^pane_gaps = true$' "$prototype/.runtime/cf/herdr/config.toml"
  grep -q '^overlay0 = "#1e1e2e"$' "$prototype/.runtime/cf/herdr/config.toml"
  test "$(grep -c '^type = "shell"$' "$prototype/.runtime/cf/herdr/config.toml")" -eq 36
  grep -q '^key = "alt+h"$' "$prototype/.runtime/cf/herdr/config.toml"
  grep -q '^key = "alt+ctrl+x"$' "$prototype/.runtime/cf/herdr/config.toml"
  grep -q 'bind --mode.*\\eh.*__herdr_nav h left' "$prototype/herdr_nav.fish"
  grep -q '^type = "plugin_action"$' "$prototype/.runtime/cf/herdr/config.toml"
  grep -q '^command = "prototype.golden-focus.toggle"$' "$prototype/.runtime/cf/herdr/config.toml"
  grep -q '^pane_borders = false$' "$prototype/.runtime/cl/herdr/config.toml"
fi

grep -q 'bind --mode.*\\ev.*split-right' "$prototype/herdr_nav.fish"
grep -q 'bind --mode.*\\en.*split-adaptive' "$prototype/herdr_nav.fish"
grep -q 'bind --mode.*\\eq.*close-pane' "$prototype/herdr_nav.fish"
grep -q 'bind --mode.*\\eo.*close-other-panes' "$prototype/herdr_nav.fish"
grep -q 'bind --mode.*\\e=.*equalize-panes' "$prototype/herdr_nav.fish"
grep -q 'bind --mode.*\\eX.*close-tab' "$prototype/herdr_nav.fish"
grep -q 'bind --mode.*\\e\\cx.*close-other-tabs' "$prototype/herdr_nav.fish"
grep -q 'bind --mode.*\\ez.*zoom' "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[118;3u'" "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[110;3u'" "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[113;3u'" "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[111;3u'" "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[61;3u'" "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[122;3u'" "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[88;3u'" "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[120;4u'" "$prototype/herdr_nav.fish"
grep -q "printf '\\\\e\[120;7u'" "$prototype/herdr_nav.fish"
if grep -Eq "\\\\ex.*close-pane|120;3u.*close-pane" "$prototype/herdr_nav.fish"; then
  echo "Alt-x must remain application-owned and unbound in the Fish adapter" >&2
  exit 1
fi
fish --no-config -n "$prototype/herdr_nav.fish"
fish --no-config -n "$prototype/herdr_login_attach.fish"
sh -n "$prototype/login_attach_fixture.sh"
grep -q 'export XDG_CONFIG_HOME="$user_config_home"' "$prototype/prototype_shell.sh"
grep -q 'export TMUX=HERDR_PROTOTYPE_STARTUP_GUARD' "$prototype/prototype_shell.sh"
grep -q 'set -e TMUX; source' "$prototype/prototype_shell.sh"
for script in "$prototype"/*.sh; do sh -n "$script"; done
sh -n "$prototype/tab-history/tab_history.sh"
python3 -c 'import sys; compile(open(sys.argv[1]).read(), "tab_client.py", "exec")' \
  "$prototype/tab_client.py"
python3 -c 'import sys; compile(open(sys.argv[1]).read(), "picker_client.py", "exec")' \
  "$prototype/picker_client.py"
python3 -c 'import sys; compile(open(sys.argv[1]).read(), "copy_mode_client.py", "exec")' \
  "$prototype/copy_mode_client.py"
python3 -c 'import sys; compile(open(sys.argv[1]).read(), "visible_references.py", "exec")' \
  "$prototype/visible_references.py"
python3 -c 'import sys; compile(open(sys.argv[1]).read(), "semantic_agent_state.py", "exec")' \
  "$prototype/semantic_agent_state.py"

binding_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
binding_nav_hash=$(shasum -a 256 "$prototype/herdr_nav.fish" | awk '{print $1}')
binding_shell_action_hash=$(shasum -a 256 "$prototype/shell_action.sh" | awk '{print $1}')
binding_validator_hash=$(shasum -a 256 "$prototype/validate_bindings.sh" | awk '{print $1}')
binding_production=$(jq -cn \
  --arg tmux "$(shasum -a 256 "$root/tmux/tmux.conf" | awk '{print $1}')" \
  --arg fish "$(shasum -a 256 "$root/fish/config.fish" | awk '{print $1}')" \
  --arg ghostty "$(shasum -a 256 "$root/ghostty/config" | awk '{print $1}')" \
  --arg neovim "$(shasum -a 256 "$HOME/.config/nvim/lua/plugin/tmux.lua" | awk '{print $1}')" \
  '{"tmux/tmux.conf":$tmux,"fish/config.fish":$fish,"ghostty/config":$ghostty,"~/.config/nvim/lua/plugin/tmux.lua":$neovim}')
jq -se --arg config_hash "$binding_config_hash" \
  --arg nav_hash "$binding_nav_hash" \
  --arg shell_action_hash "$binding_shell_action_hash" \
  --arg validator_hash "$binding_validator_hash" \
  --argjson production "$binding_production" '
  map(.check) == ["fixed_split","adaptive_split","swap","resize","move","smart_close","zoom","visible_urls","alt_transport","nested_fish_navigation","close_other_panes","alt_close_tab","alt_close_other_tabs","config","scope_audit","result"] and
  (.[0].evidence.before.panes | length) == 1 and
  .[0].evidence.after.splits[0].direction == "right" and .[0].evidence.after.splits[0].ratio == 0.5 and
  .[1].evidence.layout.splits[1].direction == "down" and
  .[2].evidence.before != .[2].evidence.after and
  .[3].evidence.before.splits[0].ratio == 0.5 and .[3].evidence.after.splits[0].ratio == 0.6 and
  .[4].evidence.before.terminal_id == .[4].evidence.middle.terminal_id and
  .[4].evidence.before.terminal_id == .[4].evidence.after.terminal_id and
  .[5].evidence.protected_exit == 75 and
  .[5].evidence.process_before == .[5].evidence.process_after_first_press and
  .[5].evidence.confirmed_process_pane_exists_after_second_press == 0 and
  .[6].evidence == {before:false,on:true,after:false} and
  .[7].evidence.opened == ["http://a","http://b"] and
  .[8].evidence.after_alt_n == (.[8].evidence.pane_count_before + 1) and
  .[8].evidence.after_nested_alt_v == (.[8].evidence.pane_count_before + 2) and
  .[8].evidence.zoom_before == false and .[8].evidence.zoom_on == true and .[8].evidence.zoom_after == false and
  .[8].evidence.alt_q_pane_exists_after == 0 and
  .[9].evidence.command == "fish" and .[9].evidence.adapter_retained == true and
  .[9].evidence.focused_after_alt_j == .[9].evidence.expected_down_pane and
  .[10].evidence.binding == "Alt-o" and .[10].evidence.confirmation_required == true and
  .[10].evidence.first_press_pane_count == 3 and .[10].evidence.second_press_pane_count == 1 and
  .[11].evidence.binding == "Alt-X" and .[11].evidence.application_owner == "Fish" and
  .[11].evidence.tab_absent == true and .[11].evidence.process_dead == true and
  .[12].evidence.binding == "Alt-Ctrl-x" and .[12].evidence.application_owner == "Fish" and
  .[12].evidence.tabs_after_first_press == .[12].evidence.tabs_before and
  .[12].evidence.tabs_after_confirmation == 1 and .[12].evidence.confirmation_required == true and
  .[13].evidence.result == "config: ok" and
  .[14].evidence.unchanged == true and
  .[14].evidence.production_hashes_before == $production and
  .[14].evidence.production_hashes_after == $production and
  .[14].evidence.artifact_hashes == {
    config:$config_hash,nav:$nav_hash,shell_action:$shell_action_hash,validator:$validator_hash
  } and
  .[15].evidence == {
    status:"PASS",session:"trial-focused",
    production_configuration_modified:false,migration_authorized:false
  }
' "$binding_evidence" >/dev/null

popup_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
popup_fixture_hash=$(shasum -a 256 "$prototype/popup_fixture.sh" | awk '{print $1}')
popup_client_hash=$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')
popup_validator_hash=$(shasum -a 256 "$prototype/validate_popups.sh" | awk '{print $1}')
popup_production=$(jq -cn \
  --arg tmux "$(shasum -a 256 "$root/tmux/tmux.conf" | awk '{print $1}')" \
  --arg fish "$(shasum -a 256 "$root/fish/config.fish" | awk '{print $1}')" \
  --arg fe "$(shasum -a 256 "$root/fish/functions/fe.fish" | awk '{print $1}')" \
  --arg ghostty "$(shasum -a 256 "$root/ghostty/config" | awk '{print $1}')" \
  --arg neovim "$(shasum -a 256 "$HOME/.config/nvim/lua/plugin/tmux.lua" | awk '{print $1}')" \
  '{"tmux/tmux.conf":$tmux,"fish/config.fish":$fish,"fish/functions/fe.fish":$fe,"ghostty/config":$ghostty,"~/.config/nvim/lua/plugin/tmux.lua":$neovim}')
jq -se --arg root "$root" \
  --arg config_hash "$popup_config_hash" \
  --arg fixture_hash "$popup_fixture_hash" \
  --arg client_hash "$popup_client_hash" \
  --arg validator_hash "$popup_validator_hash" \
  --argjson production "$popup_production" '
  def positive_integer: type == "number" and floor == . and . > 0;
  # The popup cwd is recorded as an absolute path by a live session, so it names
  # the checkout that produced the evidence, not the one verifying it. Pin the
  # property that matters — both popups inherited the repo root — without
  # pinning this machine, so a relocated checkout still verifies. The exact
  # cwd == root equality is enforced at record time in validate_popups.sh.
  (.[1].evidence.cwd) as $recorded_root |
  ($recorded_root | type == "string" and startswith("/")) and
  ($recorded_root | split("/") | last) == ($root | split("/") | last) and
  map(.check) == ["config", "scratch", "lazygit", "scope_audit", "result"] and
  .[0].evidence == {
    result:"config: ok",
    scratch:{binding:"prefix+Enter",width:"80%",height:"80%"},
    lazygit:{binding:"prefix+g",width:"85%",height:"85%"}
  } and
  .[1].evidence.kind == "scratch" and
  (.[1].evidence.pid | positive_integer) and
  .[1].evidence.rows == 30 and .[1].evidence.cols == 72 and
  .[1].evidence.cwd == $recorded_root and
  (.[1].evidence.parent_pane_pid | positive_integer) and
  .[1].evidence.tiled_objects_unchanged == true and
  .[1].evidence.dismissed_on_process_exit == true and
  .[2].evidence.kind == "lazygit" and
  (.[2].evidence.pid | positive_integer) and
  .[2].evidence.rows == 32 and .[2].evidence.cols == 76 and
  .[2].evidence.cwd == $recorded_root and
  .[2].evidence.parent_pane_pid == .[1].evidence.parent_pane_pid and
  .[2].evidence.tiled_objects_unchanged == true and
  .[2].evidence.dismissed_on_process_exit == true and
  .[3].evidence == {
    config_sha256:$config_hash,
    fixture_sha256:$fixture_hash,
    client_sha256:$client_hash,
    validator_sha256:$validator_hash,
    production_sha256:$production
  } and
  .[4].evidence == {
    status:"PASS",session:"pu",
    production_configuration_modified:false,migration_authorized:false
  }
' "$popup_evidence" >/dev/null

layout_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
layout_helper_hash=$(shasum -a 256 "$prototype/layout_menu.sh" | awk '{print $1}')
layout_preset_hash=$(shasum -a 256 "$prototype/layout_preset.sh" | awk '{print $1}')
layout_client_hash=$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')
layout_validator_hash=$(shasum -a 256 "$prototype/validate_layout_menu.sh" | awk '{print $1}')
layout_concurrent_fixture_hash=$(shasum -a 256 \
  "$prototype/fixtures/layout_concurrent_fixture.sh" | awk '{print $1}')
jq -se --arg config_hash "$layout_config_hash" \
  --arg helper_hash "$layout_helper_hash" \
  --arg preset_hash "$layout_preset_hash" \
  --arg client_hash "$layout_client_hash" \
  --arg validator_hash "$layout_validator_hash" \
  --arg concurrent_fixture_hash "$layout_concurrent_fixture_hash" \
  --argjson production "$popup_production" '
  def positive_integer: type == "number" and floor == . and . > 0;
  def valid_sentinels:
    type == "array" and length == 3 and
    all(.[]; (.pane_id | type == "string" and length > 0) and (.pid | positive_integer)) and
    (map(.pane_id) | unique | length == 3) and
    (map(.pid) | unique | length == 3);
  map(.check) == [
    "config","equalize","main_vertical_menu","zoom","cancel",
    "adaptive_split","split_right","preset_tiled","preset_main-horizontal",
    "preset_main-vertical","preset_even-horizontal","preset_even-vertical",
    "incompatible_rejection","single_pane_no_ops","concurrent_ownership",
    "scope_audit","result"
  ] and
  .[0].evidence == {
    result:"config: ok",binding:"prefix+Space",
    actions:["tiled","main-horizontal","main-vertical","even-horizontal",
      "even-vertical","equalize","zoom","adaptive-split","split-right","cancel"],
    ratio_only_presets:true,
    layout_apply_used:false
  } and
  .[1].evidence.selection == "e" and
  .[1].evidence.topology_preserved == true and
  .[1].evidence.processes_survived == true and
  (.[1].evidence.sentinels | valid_sentinels) and
  .[1].evidence.topology_signature.type == "split" and
  .[1].evidence.before.ratio == 0.7 and
  .[1].evidence.before.second.ratio == 0.65 and
  .[1].evidence.after.ratio == 0.33333334 and
  .[1].evidence.after.second.ratio == 0.5 and
  .[2].evidence.preset == "main-vertical" and
  .[2].evidence.ratio_only == true and
  .[2].evidence.layout.ratio == 0.62 and
  .[2].evidence.layout.second.ratio == 0.5 and
  .[2].evidence.processes_survived == true and
  .[3].evidence.selection == "z" and
  .[3].evidence.states == [false,true,false] and
  .[3].evidence.processes_survived == true and
  .[4].evidence.selection == "q" and .[4].evidence.layout_unchanged == true and
  .[5].evidence.selection == "a" and
  (.[5].evidence.new_pane | type == "string" and length > 0) and
  .[5].evidence.original_processes_survived == true and
  .[6].evidence.selection == "v" and
  (.[6].evidence.new_pane | type == "string" and length > 0) and
  .[6].evidence.new_pane != .[5].evidence.new_pane and
  .[6].evidence.original_processes_survived == true and
  all(.[7:12][];
    .evidence.real_prefix_transport == true and
    .evidence.ratio_only == true and
    .evidence.topology_preserved == true and
    .evidence.process_identity_preserved == true and
    .evidence.cwd_preserved == true and
    .evidence.focus_preserved == true and
    (.evidence.sentinels | valid_sentinels)
  ) and
  .[7].evidence.preset == "tiled" and .[7].evidence.selection == "+" and
  .[7].evidence.after.direction == "right" and .[7].evidence.after.ratio == 0.33333334 and
  .[8].evidence.preset == "main-horizontal" and .[8].evidence.selection == "_" and
  .[8].evidence.after.direction == "down" and .[8].evidence.after.ratio == 0.62 and
  .[9].evidence.preset == "main-vertical" and .[9].evidence.selection == "|" and
  .[9].evidence.after.direction == "right" and .[9].evidence.after.ratio == 0.62 and
  .[10].evidence.preset == "even-horizontal" and .[10].evidence.selection == "\\" and
  .[10].evidence.after.direction == "right" and .[10].evidence.after.ratio == 0.33333334 and
  .[11].evidence.preset == "even-vertical" and .[11].evidence.selection == "-" and
  .[11].evidence.after.direction == "down" and .[11].evidence.after.ratio == 0.33333334 and
  .[12].evidence.requested == "even-horizontal" and
  .[12].evidence.status == 4 and .[12].evidence.mutation == false and
  .[12].evidence.topology_preserved == true and
  .[12].evidence.processes_preserved == true and
  .[13].evidence.selections == ["+","_","|","\\","-"] and
  .[13].evidence.real_prefix_transport == true and
  .[13].evidence.layout_unchanged == true and
  .[13].evidence.focus_preserved == true and
  .[13].evidence.process_preserved == true and
  .[14].evidence.status == 5 and
  .[14].evidence.injected_after_owned_updates == 2 and
  .[14].evidence.foreign_ratio_preserved == true and
  .[14].evidence.helper_did_not_claim_foreign_update == true and
  .[14].evidence.topology_preserved == true and
  .[14].evidence.processes_preserved == true and
  .[15].evidence == {
    config_sha256:$config_hash,helper_sha256:$helper_hash,
    preset_sha256:$preset_hash,
    client_sha256:$client_hash,validator_sha256:$validator_hash,
    concurrent_fixture_sha256:$concurrent_fixture_hash,
    production_sha256:$production
  } and
  .[16].evidence == {
    status:"PASS",session:"lm",
    production_configuration_modified:false,migration_authorized:false
  }
' "$layout_menu_evidence" >/dev/null

utility_pane_transfer_hash=$(shasum -a 256 "$prototype/pane_transfer.sh" | awk '{print $1}')
utility_history_hash=$(shasum -a 256 "$prototype/export_history.sh" | awk '{print $1}')
utility_tab_edge_hash=$(shasum -a 256 "$prototype/tab_edge.sh" | awk '{print $1}')
utility_fixture_hash=$(shasum -a 256 "$prototype/fixtures/pane_transfer_picker_fixture.sh" | awk '{print $1}')
utility_history_swap_fixture_hash=$(shasum -a 256 \
  "$prototype/fixtures/history_path_swap_fixture.sh" | awk '{print $1}')
utility_validator_hash=$(shasum -a 256 "$prototype/validate_utilities.sh" | awk '{print $1}')
utility_tmux_path=$(command -v tmux)
utility_tmux_version=$("$utility_tmux_path" -V)
jq -se --arg pane_transfer "$utility_pane_transfer_hash" \
  --arg history_export "$utility_history_hash" \
  --arg tab_edge "$utility_tab_edge_hash" \
  --arg fixture "$utility_fixture_hash" \
  --arg history_swap_fixture "$utility_history_swap_fixture_hash" \
  --arg validator "$utility_validator_hash" \
  --arg tmux_path "$utility_tmux_path" \
  --arg tmux_version "$utility_tmux_version" \
  --argjson production "$popup_production" '
  def positive_integer: type == "number" and floor == . and . > 0;
  map(.check) == [
    "config","transfer_send","transfer_receive","transfer_rejections",
    "transfer_cross_workspace","transfer_cross_workspace_receive",
    "transfer_post_move_rollback","transfer_native_failure_no_op",
    "history_export","tab_edges",
    "popup_transport","scope_audit","result"
  ] and
  .[0].evidence.first_tab == "prefix+^" and
  .[0].evidence.last_tab == "prefix+$" and
  .[0].evidence.last_pane_preserved == ["prefix+Tab","Ctrl+^"] and
  all(.[1:3][];
    .evidence.terminal_preserved == true and
    .evidence.process_preserved == true and
    .evidence.cwd_preserved == true and
    .evidence.focused_after == true and
    (.evidence.sentinel_pid | positive_integer)
  ) and
  .[3].evidence.cancel_no_op == true and
  .[3].evidence.self_rejected == true and
  .[3].evidence.stale_rejected == true and
  .[4].evidence.pane_id_namespace_remap == true and
  .[4].evidence.terminal_preserved == true and
  .[4].evidence.process_preserved == true and
  .[4].evidence.cwd_preserved == true and
  .[5].evidence.mode == "receive" and
  .[5].evidence.process_preserved == true and
  .[6].evidence.injected_post_move_failure == true and
  .[6].evidence.status == 5 and
  .[6].evidence.process_preserved == true and
  .[7].evidence.injected_native_move_status == 42 and
  .[7].evidence.sole_source == true and
  .[7].evidence.guard_cleaned == true and
  .[7].evidence.placement_unchanged == true and
  .[7].evidence.process_preserved == true and
  .[8].evidence.explicit_path == true and
  .[8].evidence.mode == "0600" and
  .[8].evidence.terminal_text_preserved == true and
  .[8].evidence.json_like_text_preserved == true and
  .[8].evidence.trailing_newline_preserved == true and
  .[8].evidence.full_scrollback_over_200 == true and
  .[8].evidence.no_clobber_refusal == true and
  .[8].evidence.confirmed_overwrite == true and
  .[8].evidence.path_swap_rejected == true and
  .[8].evidence.unconfirmed_replacement_preserved == true and
  .[8].evidence.before_open_dangling_swap_rejected == true and
  .[8].evidence.dangling_referent_not_created == true and
  .[8].evidence.pane_history_enabled == false and
  .[9].evidence.real_prefix_transport == true and
  .[9].evidence.prefix_tab_last_pane_preserved == true and
  .[9].evidence.sentinel_processes_survived == true and
  .[10].evidence.pane_transfer.real_fzf == true and
  .[10].evidence.pane_transfer.cancelled == true and
  .[10].evidence.history_export.prompted == true and
  .[10].evidence.history_export.cancelled == true and
  .[10].evidence.tiled_objects_unchanged == true and
  .[11].evidence == {
    artifact_sha256:{
      pane_transfer:$pane_transfer,history_export:$history_export,
      tab_edge:$tab_edge,picker_fixture:$fixture,
      history_swap_fixture:$history_swap_fixture,validator:$validator
    },
    production_sha256:$production,unchanged:true
  } and
  .[12].evidence == {
    status:"PASS",version:"herdr 0.7.5",session:"ut",
    pane_history:{prototype:true,production:true},
    tmux:{available:true,path:$tmux_path,version:$tmux_version},
    production_configuration_modified:false
  }
' "$utility_parity_evidence" >/dev/null

copy_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
copy_client_hash=$(shasum -a 256 "$prototype/copy_mode_client.py" | awk '{print $1}')
copy_validator_hash=$(shasum -a 256 "$prototype/validate_copy_mode.sh" | awk '{print $1}')
jq -se --arg config_hash "$copy_config_hash" \
  --arg client_hash "$copy_client_hash" \
  --arg validator_hash "$copy_validator_hash" \
  --argjson production "$popup_production" '
  def positive_integer: type == "number" and floor == . and . > 0;
  map(.check) ==
    ["config","paging","vim_aliases","vim_pending_commands","scope_audit","result"] and
  .[0].evidence == {
    result:"config: ok",binding:"prefix+s",
    native_half_page:["Ctrl-u","Ctrl-d"],
    native_full_page:["PageUp","PageDown"]
  } and
  (.[1].evidence.sentinel_pid | positive_integer) and
  .[1].evidence.initial == {min:82,max:120} and
  .[1].evidence.copy_entry == .[1].evidence.initial and
  .[1].evidence.half_up == {min:62,max:100} and
  .[1].evidence.half_down == .[1].evidence.initial and
  .[1].evidence.page_up == {min:44,max:82} and
  .[1].evidence.page_down == .[1].evidence.initial and
  .[1].evidence.process_survived == true and
  .[2].evidence.exit_without_copy == {
    a:"COPY_MODE_NO_COPY_SENTINEL",i:"COPY_MODE_NO_COPY_SENTINEL"
  } and
  .[2].evidence.whole_line == "COPY_LINE_120 payload-120" and
  (.[2].evidence.sentinel_pid | positive_integer) and
  .[2].evidence.process_survived == true and
  .[2].evidence.input_emulation_installed == false and

  .[3].evidence.alt_slash_entry_counted_yank ==
    "COPY_LINE_119 payload-119\nCOPY_LINE_120 payload-120" and
  .[3].evidence.escape_discards_count == "COPY_LINE_120 payload-120" and
  .[3].evidence.alt_b_backward_search == "COPY_LINE_118 payload-118" and
  .[3].evidence.center.before == {min:44,max:82} and
  .[3].evidence.center.after == {min:64,max:102} and
  (.[3].evidence.sentinel_pid | positive_integer) and
  .[3].evidence.process_survived == true and
  .[3].evidence.input_emulation_installed == false and

  .[4].evidence == {
    config_sha256:$config_hash,client_sha256:$client_hash,
    validator_sha256:$validator_hash,production_sha256:$production
  } and
  .[5].evidence == {
    status:"PASS",version:"herdr 0.7.5",session:"cm",
    production_configuration_modified:false,migration_authorized:false
  }
' "$copy_mode_evidence" >/dev/null

url_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
url_helper_hash=$(shasum -a 256 "$prototype/open_visible_url.sh" | awk '{print $1}')
url_opener_hash=$(shasum -a 256 "$prototype/url_opener_fixture.sh" | awk '{print $1}')
url_client_hash=$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')
url_validator_hash=$(shasum -a 256 "$prototype/validate_urls.sh" | awk '{print $1}')
url_production=$(jq -cn \
  --arg tmux "$(shasum -a 256 "$root/tmux/tmux.conf" | awk '{print $1}')" \
  --arg fish "$(shasum -a 256 "$root/fish/config.fish" | awk '{print $1}')" \
  --arg ghostty "$(shasum -a 256 "$root/ghostty/config" | awk '{print $1}')" \
  --arg neovim "$(shasum -a 256 "$HOME/.config/nvim/lua/plugin/tmux.lua" | awk '{print $1}')" \
  '{"tmux/tmux.conf":$tmux,"fish/config.fish":$fish,"ghostty/config":$ghostty,"~/.config/nvim/lua/plugin/tmux.lua":$neovim}')
jq -se --arg config_hash "$url_config_hash" \
  --arg helper_hash "$url_helper_hash" \
  --arg opener_hash "$url_opener_hash" \
  --arg client_hash "$url_client_hash" \
  --arg validator_hash "$url_validator_hash" \
  --argjson production "$url_production" '
  map(.check) == ["config","transport","scope_audit","result"] and
  .[0].evidence == {result:"config: ok",binding:"prefix+u",transport:"real PTY input"} and
  .[1].evidence.input_submitted_via == "prefix+u" and
  .[1].evidence.cases == {
    zero:{opened:false},
    one:{opened:"https://example.test/one"},
    multiple:{opened_newest:"https://example.test/new?x=1"}
  } and
  .[1].evidence.opened == ["https://example.test/one","https://example.test/new?x=1"] and
  .[2].evidence.unchanged == true and
  .[2].evidence.production_hashes_before == $production and
  .[2].evidence.production_hashes_after == $production and
  .[2].evidence.artifact_hashes == {
    config:$config_hash,helper:$helper_hash,opener:$opener_hash,
    client:$client_hash,validator:$validator_hash
  } and
  .[3].evidence == {
    status:"PASS",version:"herdr 0.7.5",session:"url",
    production_configuration_modified:false,migration_authorized:false
  }
' "$url_evidence" >/dev/null

remote_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
remote_validator_hash=$(shasum -a 256 "$prototype/validate_remote.sh" | awk '{print $1}')
jq -se --arg config_hash "$remote_config_hash" \
  --arg validator_hash "$remote_validator_hash" \
  --argjson production "$url_production" '
  map(.check) == ["capability","ssh","attach","unavailable","scope_audit","result"] and
  .[0].evidence == {
    version:"herdr 0.7.5",remote_attach:true,
    local_or_server_keybindings:true,nesting_default:"disabled"
  } and
  .[1].evidence.transport == "disposable-localhost-openssh" and
  .[1].evidence.authenticated == true and
  .[1].evidence.remote_binary == "herdr 0.7.5" and
  .[1].evidence.production_remote_login_enabled == false and
  .[2].evidence.mode == "thin-client" and .[2].evidence.attached == true and
  .[2].evidence.session == "remote-audit" and
  .[2].evidence.server_status.running == true and
  .[2].evidence.server_status.version == "0.7.5" and
  .[2].evidence.server_status.compatible == true and
  (.[2].evidence.pane_inventory.result.panes | length) >= 1 and
  .[3].evidence.fail_closed == true and .[3].evidence.exit != 0 and
  .[3].evidence.input_sent == false and
  .[3].evidence.remote_install_attempted == false and
  .[4].evidence.unchanged == true and
  .[4].evidence.production_hashes_before == $production and
  .[4].evidence.production_hashes_after == $production and
  .[4].evidence.artifact_hashes == {
    config:$config_hash,validator:$validator_hash
  } and
  .[5].evidence == {
    status:"PASS",production_configuration_modified:false,
    remote_login_enabled:false,integration_installed:false,
    migration_authorized:false
  }
' "$remote_evidence" >/dev/null

# The prototype binary is a gitignored work product. Re-derive the upstream
# default-config hash from it when it exists; a fresh checkout can only carry the
# recorded value forward, so say so rather than failing on an absent build.
if [ -x "$prototype/.runtime/bin/herdr" ]; then
  capability_defaults_hash=$("$prototype/.runtime/bin/herdr" --default-config | shasum -a 256 | awk '{print $1}')
else
  capability_defaults_hash=$(jq -r 'select(.check == "surface").evidence.default_config_sha256' \
    "$capability_gap_evidence")
  echo "Herdr prototype verification: skipped default-config re-derivation (no local build)" >&2
fi
capability_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
capability_nav_hash=$(shasum -a 256 "$prototype/herdr_nav.fish" | awk '{print $1}')
capability_source_patch_hash=$(shasum -a 256 \
  "$root/herdr/source-build/copy-mode-vim-muscle-memory.patch" | awk '{print $1}')
capability_validator_hash=$(shasum -a 256 "$prototype/validate_capability_gaps.sh" | awk '{print $1}')
jq -se --arg defaults_hash "$capability_defaults_hash" \
  --arg config_hash "$capability_config_hash" \
  --arg nav_hash "$capability_nav_hash" \
  --arg source_patch_hash "$capability_source_patch_hash" \
  --arg validator_hash "$capability_validator_hash" \
  --argjson production "$url_production" '
  map(.check) == ["surface","alternatives","policy","scope_audit","result"] and
  .[0].evidence == {
    version:"herdr 0.7.5",default_config_sha256:$defaults_hash,
    upstream_configurable_actions_absent:["rectangle-selection","copy-line-Y","marks","OSC-133-prompt-jumps","copy-mode-cursor-URL"],
    reviewed_source_extensions:["copy-line-Y"],
    absence_deterministic:true
  } and
  .[1].evidence == {
    ordinary_selection:{keys:["v","Space","y","Y","Enter"],evidence:"copy-mode-validation.jsonl"},
    paging:{keys:["Ctrl-u","Ctrl-d","PageUp","PageDown"],evidence:"copy-mode-validation.jsonl"},
    visible_url:{key:"prefix+u",evidence:"url-validation.jsonl"},
    last_location:{keys:["prefix+Tab","Ctrl-^/Ctrl-6"],semantics:"last-pane"}
  } and
  .[2].evidence == {
    alt_tab:"retired",rectangle_selection:"unavailable",copy_line_Y:"reviewed-source-build",
    marks:"unavailable",prompt_jumps:"unavailable",copy_mode_O:"unavailable",
    input_emulation_installed:false,global_alt_binding_installed:true,
    production_config_change_required:false
  } and
  .[3].evidence.unchanged == true and
  .[3].evidence.production_hashes_before == $production and
  .[3].evidence.production_hashes_after == $production and
  .[3].evidence.artifact_hashes == {
    config:$config_hash,nav:$nav_hash,source_patch:$source_patch_hash,
    validator:$validator_hash
  } and
  .[4].evidence == {
    status:"PASS",production_configuration_modified:false,
    unsupported_emulation_installed:false,migration_authorized:false
  }
' "$capability_gap_evidence" >/dev/null

recovery_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
recovery_fixture_hash=$(shasum -a 256 "$prototype/recovery_agent_fixture.sh" | awk '{print $1}')
recovery_validator_hash=$(shasum -a 256 "$prototype/validate_recovery.sh" | awk '{print $1}')
jq -se --arg config_hash "$recovery_config_hash" \
  --arg fixture_hash "$recovery_fixture_hash" \
  --arg validator_hash "$recovery_validator_hash" \
  --argjson production "$popup_production" '
  def positive_integer: type == "number" and floor == . and . > 0;
  map(.check) == ["config","before_restart","after_restart","scope_audit","result"] and
  .[0].evidence.result == "config: ok" and
  .[0].evidence.pane_history == true and
  .[0].evidence.resume_agents_on_restore == true and
  .[0].evidence.isolated_codex_integration.version == 6 and
  .[0].evidence.isolated_codex_integration.installed == true and
  (.[0].evidence.isolated_codex_integration.output | contains("installed codex integration hook")) and
  .[0].evidence.agent_fixture_installed_in_runtime_only == true and
  (.[1].evidence.structure.workspaces | length) == 1 and
  (.[1].evidence.structure.tabs | length) == 2 and
  (.[1].evidence.structure.panes | length) == 3 and
  (.[1].evidence.structure.panes | map(.pane_id)) == ["w1:p1","w1:p2","w1:p3"] and
  (.[1].evidence.structure.tabs | map(.label)) == ["Primary","Secondary"] and
  (.[1].evidence.structure.panes | map(.label)) == ["RECOVERY ONE","RECOVERY TWO","RECOVERY THREE"] and
  .[1].evidence.structure.layouts[0].splits[0].ratio == 0.62 and
  (.[1].evidence.live_process_pids | length) == 3 and
  all(.[1].evidence.live_process_pids[]; positive_integer) and
  (.[1].evidence.live_process_pids | unique | length) == 3 and
  .[1].evidence.history_markers == ["RECOVERY_HISTORY_1_LINE_001","RECOVERY_HISTORY_2_LINE_001"] and
  .[1].evidence.agent_session == {pane_id:"w1:p3",agent:"codex",session_id:"recovery-codex-session"} and
  .[2].evidence.structure == .[1].evidence.structure and
  .[2].evidence.original_processes_gone == true and
  (.[2].evidence.restored_processes | length) == 3 and
  all(.[2].evidence.restored_processes[]; (.shell_pid | positive_integer) and .old_pid_reused == false) and
  .[2].evidence.history_replayed == true and
  .[2].evidence.native_agent_resume == {agent:"codex",args:["resume","recovery-codex-session"]} and
  .[2].evidence.arbitrary_processes_resumed == false and
  .[3].evidence == {
    config_sha256:$config_hash,fixture_sha256:$fixture_hash,
    validator_sha256:$validator_hash,production_sha256:$production
  } and
  .[4].evidence == {
    status:"PASS",version:"herdr 0.7.5",session:"rc",
    snapshot_restored:true,pane_history_replayed:true,
    native_agent_resumed:true,arbitrary_process_resume:false,
    production_configuration_modified:false,migration_authorized:false
  }
' "$recovery_evidence" >/dev/null

workspace_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
workspace_client_hash=$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')
workspace_validator_hash=$(shasum -a 256 "$prototype/validate_workspace_navigation.sh" | awk '{print $1}')
jq -se --arg config_hash "$workspace_config_hash" \
  --arg client_hash "$workspace_client_hash" \
  --arg validator_hash "$workspace_validator_hash" \
  --argjson production "$popup_production" '
  def positive_integer: type == "number" and floor == . and . > 0;
  map(.check) == ["config","cycle","last_pane","scope_audit","result"] and
  .[0].evidence == {
    result:"config: ok",previous_workspace:"prefix+(",next_workspace:"prefix+)",
    last_pane:["prefix+Tab","Ctrl-^/Ctrl-6"]
  } and
  .[1].evidence.start == "w1" and
  .[1].evidence.next_sequence == ["w2","w3","w1"] and
  .[1].evidence.previous_from_first == "w3" and .[1].evidence.wrapped == true and
  .[2].evidence.binding == "Ctrl-^/Ctrl-6" and
  .[2].evidence.setup == ["w1:p1","w2:p1"] and
  .[2].evidence.toggle == ["w1:p1","w2:p1"] and
  .[2].evidence.cross_workspace == true and .[2].evidence.processes_survived == true and
  (.[2].evidence.sentinels | length) == 3 and
  all(.[2].evidence.sentinels[]; (.pane_id | type == "string" and length > 0) and (.pid | positive_integer)) and
  .[3].evidence == {
    config_sha256:$config_hash,client_sha256:$client_hash,
    validator_sha256:$validator_hash,production_sha256:$production
  } and
  .[4].evidence == {
    status:"PASS",version:"herdr 0.7.5",session:"wn",
    model:"workspaces-within-session",
    production_configuration_modified:false,migration_authorized:false
  }
' "$workspace_navigation_evidence" >/dev/null

jq -se '
  def nonempty_string: type == "string" and length > 0;
  def positive_integer: type == "number" and floor == . and . > 0;

  ["config", "reorder_api", "create", "cycle", "indexed", "numbered_noop", "last_tab",
   "reorder", "close", "close_others", "alt_new_tab", "result"] as $expected_checks |
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

  .[1].evidence.version == "herdr 0.7.5" and
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
  .[2].evidence.prefix_binding == "prefix+c" and

  .[3].evidence ==
    {start:$tab_ids[3], next:$tab_ids[0], previous:$tab_ids[3]} and
  .[4].evidence == {binding:"prefix+2", focused_tab:$tab_ids[1]} and
  .[5].evidence.binding == "prefix+7" and
  .[5].evidence.tab_count == 4 and
  .[5].evidence.tab_created == false and
  .[5].evidence.tabs_unchanged == $tab_ids and
  .[5].evidence.focus_unchanged == $tab_ids[1] and
  .[5].evidence.positional == [
    {binding:"prefix+4", position:4, focused_tab:$tab_ids[3]},
    {binding:"prefix+1", position:1, focused_tab:$tab_ids[0]}
  ] and
  .[6].evidence.previous_tab == $tab_ids[1] and
  .[6].evidence.from_tab == $tab_ids[2] and
  .[6].evidence.result == $tab_ids[1] and
  (.[6].evidence.second_pane_in_from_tab | nonempty_string) and

  .[7].evidence.moved_tab == $tab_ids[2] and
  .[7].evidence.sentinel_pid == $sentinel_pids[2] and
  .[7].evidence.before == $tab_ids and
  .[7].evidence.after_right ==
    [$tab_ids[0], $tab_ids[1], $tab_ids[3], $tab_ids[2]] and
  .[7].evidence.restored == $tab_ids and

  (.[8].evidence.closed_tab | nonempty_string) and
  ([.[8].evidence.closed_tab] - $tab_ids | length) == 1 and
  (.[8].evidence.sentinel_pid | positive_integer) and
  ([.[8].evidence.sentinel_pid] - $sentinel_pids | length) == 1 and
  .[8].evidence.tab_absent == true and
  .[8].evidence.sentinel_dead == true and

  .[9].evidence.first_press_preserved_tabs == $tab_ids and
  .[9].evidence.survivor_tab == $tab_ids[1] and
  .[9].evidence.survivor_pid == $sentinel_pids[1] and
  .[9].evidence.closed_target_pids ==
    [$sentinel_pids[0], $sentinel_pids[2], $sentinel_pids[3]] and
  .[9].evidence.confirmation_required == true and

  .[10].evidence.binding == "alt+ctrl+t" and
  .[10].evidence.transport == "kitty-csi-u-116;7u" and
  .[10].evidence.alt_cycle.next.binding == "alt+ctrl+n" and
  .[10].evidence.alt_cycle.next.transport == "kitty-csi-u-110;7u" and
  .[10].evidence.alt_cycle.next.focused_tab == $tab_ids[1] and
  .[10].evidence.alt_cycle.previous.binding == "alt+ctrl+p" and
  .[10].evidence.alt_cycle.previous.transport == "kitty-csi-u-112;7u" and
  .[10].evidence.alt_cycle.previous.focused_tab ==
    .[10].evidence.created_tab and
  .[10].evidence.arrow_cycle.next.binding == "alt+ctrl+right" and
  .[10].evidence.arrow_cycle.next.transport == "csi-1;7C" and
  .[10].evidence.arrow_cycle.next.focused_tab == $tab_ids[1] and
  .[10].evidence.arrow_cycle.previous.binding == "alt+ctrl+left" and
  .[10].evidence.arrow_cycle.previous.transport == "csi-1;7D" and
  .[10].evidence.arrow_cycle.previous.focused_tab ==
    .[10].evidence.created_tab and
  .[10].evidence.workspace == "w1" and
  .[10].evidence.source_cwd == .[10].evidence.created_cwd and
  .[10].evidence.focused == true and
  .[10].evidence.single_new_tab == true and
  (.[10].evidence.created_tab | nonempty_string) and
  .[10].evidence.alt_t == {
    binding:"alt+t",transport:"kitty-csi-u-116;3u",
    tab_count_unchanged:true,focus_unchanged:true
  } and

  .[11].evidence == {
    status:"PASS",
    session:"gate-tabs",
    production_configuration_modified:false,
    migration_authorized:false
  }
' "$tab_lifecycle_evidence" >/dev/null

ready_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
ready_helper_hash=$(shasum -a 256 "$prototype/ready_prompt.sh" | awk '{print $1}')
ready_fixture_hash=$(shasum -a 256 "$prototype/ready_prompt_agent_fixture.sh" | awk '{print $1}')
ready_validator_hash=$(shasum -a 256 "$prototype/validate_ready_prompt.sh" | awk '{print $1}')
jq -se --arg config_hash "$ready_config_hash" \
  --arg helper_hash "$ready_helper_hash" \
  --arg fixture_hash "$ready_fixture_hash" \
  --arg validator_hash "$ready_validator_hash" '
  map(.check) == ["config", "parser", "mock_replay", "live_transport", "scope_audit", "result"] and
  .[0].evidence == {
    result:"config: ok",
    replay_binding:"prefix+b",
    clear_binding:"prefix+shift+b"
  } and
  .[1].evidence.source == "herdr/prototype/ready_prompt_parser.sh --extract" and
  .[1].evidence.checks > 0 and
  .[1].evidence.status == "PASS" and
  .[2].evidence.multiline_insert_exact == true and
  .[2].evidence.submitted == false and
  .[2].evidence.consume_once == true and
  .[2].evidence.duplicate_status != 0 and
  .[2].evidence.concurrent_status == 75 and
  .[2].evidence.clear_then_insert == true and
  .[2].evidence.unsupported_clear_status != 0 and
  .[3].evidence.agent_argv0 == "codex" and
  .[3].evidence.prompt_visible == true and
  .[3].evidence.submitted == false and
  .[3].evidence.marker_absent == true and
  .[4].evidence.unchanged == true and
  .[4].evidence.production_hashes_before == .[4].evidence.production_hashes_after and
  .[4].evidence.artifact_hashes == {
    config:$config_hash,
    helper:$helper_hash,
    fixture:$fixture_hash,
    validator:$validator_hash
  } and
  .[5].evidence == {
    status:"PASS",
    session:"gate-rp",
    production_configuration_modified:false,
    migration_authorized:false
  }
' "$ready_prompt_evidence" >/dev/null

pane_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
pane_helper_hash=$(shasum -a 256 "$prototype/equalize_panes.sh" | awk '{print $1}')
pane_nav_hash=$(shasum -a 256 "$prototype/herdr_nav.fish" | awk '{print $1}')
pane_client_hash=$(shasum -a 256 "$prototype/tab_client.py" | awk '{print $1}')
pane_validator_hash=$(shasum -a 256 "$prototype/validate_panes.sh" | awk '{print $1}')
jq -se --arg config_hash "$pane_config_hash" --arg helper_hash "$pane_helper_hash" \
  --arg nav_hash "$pane_nav_hash" --arg client_hash "$pane_client_hash" \
  --arg validator_hash "$pane_validator_hash" '
  def leaves:
    if .type == "pane" then 1 else ((.first|leaves)+(.second|leaves)) end;
  def balanced:
    if .type == "pane" then true
    else
      (.first|leaves) as $a | (.second|leaves) as $b |
      (($a/($a+$b)) - .ratio) as $delta |
      ($delta < 0.000001 and $delta > -0.000001) and
      (.first|balanced) and (.second|balanced)
    end;
  def signature:
    if .type == "pane" then {type,pane_id}
    else {type,direction,first:(.first|signature),second:(.second|signature)}
    end;
  map(.check) == ["config","equalize","prefix_close_others","shell_close_others","no_siblings","scope_audit","result"] and
  .[0].evidence == {
    result:"config: ok",
    close_others:{prefix:"prefix+o",shell:"Alt-o"},
    equalize:{prefix:"prefix+=",shell:"Alt-="}
  } and
  .[1].evidence.prefix_binding == "prefix+=" and
  .[1].evidence.shell_binding == "Alt-=" and
  .[1].evidence.topology_preserved == true and
  .[1].evidence.processes_survived == true and
  (.[1].evidence.sentinel_pids | length) == 2 and
  (.[1].evidence.sentinel_pids | unique | length) == 2 and
  (.[1].evidence.before | balanced | not) and
  (.[1].evidence.after_prefix | balanced) and
  (.[1].evidence.after_alt | balanced) and
  (.[1].evidence.before | signature) == .[1].evidence.topology_signature and
  (.[1].evidence.after_prefix | signature) == .[1].evidence.topology_signature and
  (.[1].evidence.after_alt | signature) == .[1].evidence.topology_signature and
  .[2].evidence.binding == "prefix+o" and
  .[2].evidence.first_press_preserved == true and
  .[2].evidence.second_press_closed == true and
  (.[2].evidence.closed_process_pids | length) == 2 and
  .[3].evidence.binding == "Alt-o" and
  .[3].evidence.application_owner == "Fish" and
  .[3].evidence.first_press_preserved == true and
  .[3].evidence.second_press_closed == true and
  (.[3].evidence.closed_process_pids | length) == 2 and
  .[4].evidence == {pane:"w1:p1",pane_count:1,no_op:true} and
  .[5].evidence.unchanged == true and
  .[5].evidence.production_hashes_before == .[5].evidence.production_hashes_after and
  .[5].evidence.artifact_hashes == {
    config:$config_hash,
    helper:$helper_hash,
    nav:$nav_hash,
    client:$client_hash,
    validator:$validator_hash
  } and
  .[6].evidence == {
    status:"PASS",
    session:"gp",
    production_configuration_modified:false,
    migration_authorized:false
  }
' "$pane_lifecycle_evidence" >/dev/null

agent_state_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
agent_state_helper_hash=$(shasum -a 256 "$prototype/semantic_agent_state.py" | awk '{print $1}')
agent_state_client_hash=$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')
agent_state_validator_hash=$(shasum -a 256 "$prototype/validate_agent_states.sh" | awk '{print $1}')
jq -se --arg config_hash "$agent_state_config_hash" \
  --arg helper_hash "$agent_state_helper_hash" \
  --arg client_hash "$agent_state_client_hash" \
  --arg validator_hash "$agent_state_validator_hash" '
  map(.check) == ["config","metadata","navigator","scope_audit","result"] and
  .[0].evidence == {
    result:"config: ok",
    sidebar_rows:[["state_icon","workspace","tab"],["agent","$semantic_state"]],
    metadata_api:true
  } and
  .[1].evidence.semantic_states == ["approval","failure","finished","question","running"] and
  .[1].evidence.lifecycle_authority_preserved == true and
  (.[1].evidence.panes | length) == 5 and
  (.[1].evidence.panes | map(.agent) | unique) == ["codex"] and
  (.[1].evidence.panes | map({state:.tokens.semantic_state,status:.agent_status}) | sort_by(.state)) == [
    {state:"approval",status:"blocked"},
    {state:"failure",status:"done"},
    {state:"finished",status:"done"},
    {state:"question",status:"blocked"},
    {state:"running",status:"working"}
  ] and
  all(.[1].evidence.panes[];
    .tokens.semantic_state as $state |
    .tokens.semantic_state == .tokens.summary and
    ([.state_labels[]] | index($state)) != null) and
  .[2].evidence.surface == "prefix+f" and
  .[2].evidence.distinct_labels == true and
  .[2].evidence.lines as $lines |
  all(["running","question","approval","finished","failure"][];
    . as $state | ($lines[$state] | contains($state))) and
  .[3].evidence.unchanged == true and
  .[3].evidence.production_hashes_before == .[3].evidence.production_hashes_after and
  .[3].evidence.artifact_hashes == {
    config:$config_hash,
    helper:$helper_hash,
    client:$client_hash,
    validator:$validator_hash
  } and
  .[4].evidence == {
    status:"PASS",
    version:"herdr 0.7.5",
    session:"gas",
    production_configuration_modified:false,
    integration_installed:false,
    migration_authorized:false
  }
' "$agent_state_evidence" >/dev/null

multi_agent_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
multi_agent_helper_hash=$(shasum -a 256 "$prototype/semantic_agent_state.py" | awk '{print $1}')
multi_agent_model_hash=$(shasum -a 256 "$root/tmux/scripts/agent_status.py" | awk '{print $1}')
multi_agent_client_hash=$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')
multi_agent_validator_hash=$(shasum -a 256 "$prototype/validate_multi_agent_compat.sh" | awk '{print $1}')
jq -se --arg config_hash "$multi_agent_config_hash" \
  --arg helper_hash "$multi_agent_helper_hash" \
  --arg model_hash "$multi_agent_model_hash" \
  --arg client_hash "$multi_agent_client_hash" \
  --arg validator_hash "$multi_agent_validator_hash" '
  map(.check) == ["config","availability","detection","lifecycle","unsupported","visibility","scope_audit","result"] and
  .[0].evidence == {
    result:"config: ok",isolation:"prototype-only",existing_agent_state_evidence_replaced:false
  } and
  (.[1].evidence.agents | map(.agent)) == ["claude","opencode","agy","gemini"] and
  all(.[1].evidence.agents[];
    .model_call_made == false and
    ((.status == "available" and (.executable | length) > 0 and (.version | length) > 0) or
     (.status == "unavailable" and .fail_closed == true))) and
  .[2].evidence.all_passed == true and
  (.[2].evidence.cases | map(.detected)) == ["claude","opencode","agy","gemini"] and
  .[2].evidence.unsupported == {detected:"",fail_closed:true} and
  (.[3].evidence.agents | map(.agent)) == ["claude","opencode","agy","gemini"] and
  (.[3].evidence.agents | map(.events)) == [
    {running:"prompt",question:"stop",approval:"permission",finished:"stop",failure:"failure"},
    {running:"prompt",question:"question",approval:"permission",finished:"complete",failure:"failure"},
    {running:"pre-invocation",question:"question",approval:"permission",finished:"stop",failure:"stop"},
    {running:"before-agent",question:"after-agent",approval:"permission",finished:"after-agent",failure:"after-agent"}
  ] and
  all(.[3].evidence.agents[];
    .deterministic == true and
    (.states | map({semantic_state,agent_status})) == [
      {semantic_state:"running",agent_status:"working"},
      {semantic_state:"question",agent_status:"blocked"},
      {semantic_state:"approval",agent_status:"blocked"},
      {semantic_state:"finished",agent_status:"done"},
      {semantic_state:"failure",agent_status:"done"}
    ]) and
  .[3].evidence.lifecycle_authority == "herdr" and
  .[3].evidence.semantic_metadata == "display-only" and
  .[4].evidence.unchanged == true and
  .[4].evidence.before == .[4].evidence.after and
  .[4].evidence.hook_exit_safe == true and .[4].evidence.input_sent == false and
  .[5].evidence.surface == "prefix+f" and .[5].evidence.all_visible == true and
  (.[] | select(.check == "visibility").evidence.lines) as $lines |
  ($lines.claude | contains("running")) and
  ($lines.opencode | contains("question")) and
  ($lines.agy | contains("approval")) and
  ($lines.gemini | contains("finished")) and
  .[6].evidence.unchanged == true and
  .[6].evidence.production_hashes_before == .[6].evidence.production_hashes_after and
  .[6].evidence.prior_evidence_replaced == false and
  .[6].evidence.artifact_hashes == {
    config:$config_hash,helper:$helper_hash,model:$model_hash,client:$client_hash,validator:$validator_hash
  } and
  .[7].evidence == {
    status:"PASS",version:"herdr 0.7.5",session:"mac",
    named_agents:["claude","opencode","agy","gemini"],
    production_configuration_modified:false,integration_installed:false,migration_authorized:false
  }
' "$multi_agent_evidence" >/dev/null

login_adapter_hash=$(shasum -a 256 "$prototype/herdr_login_attach.fish" | awk '{print $1}')
login_allocator_hash=$(shasum -a 256 "$root/herdr/window_session.sh" | awk '{print $1}')
login_fixture_hash=$(shasum -a 256 "$prototype/login_attach_fixture.sh" | awk '{print $1}')
login_validator_hash=$(shasum -a 256 "$prototype/validate_login_attach.sh" | awk '{print $1}')
jq -se --arg adapter_hash "$login_adapter_hash" \
  --arg allocator_hash "$login_allocator_hash" \
  --arg fixture_hash "$login_fixture_hash" \
  --arg validator_hash "$login_validator_hash" '
  map(.check) == ["decisions","scope_audit","result"] and
  .[0].evidence == {
    top_level_login:{launched:true,args:["--session","main"]},
    custom_session:{launched:true,args:["--session","project-alpha"]},
    cwd_policy:{
      automatic_launch_home:true,
      restored_panes_keep_session_cwd:true
    },
    independent_windows:{
      concurrent_sessions:["main","window-2","window-3"],
      no_client_restores_last:["--session","window-3"],
      active_client_creates_new:["--session","window-4"],
      bare_client_creates_new:["--session","window-5"],
      final_client_exit_updates_last:true,
      double_digit_boundary:["--session","window-10"],
      migration_restores_highest_existing:["--session","window-7"],
      migration_active_creates_next:["--session","window-8"],
      reused_pid_restores_last:["--session","window-8"],
      persistent_servers_not_stopped:true
    },
    guards:{
      non_login:true,
      non_interactive:true,
      herdr_env:true,
      herdr_pane:true,
      tmux:true,
      opt_out:true,
      invalid_session:true,
      allocator_failure:true,
      invalid_session_cwd_unchanged:true,
      broad_runtime_rejected:true,
      unsafe_existing_runtime_rejected:true,
      unsafe_persistent_state_rejected:true,
      symlink_lease_rejected:true,
      concurrent_cold_start:true,
      home_cd_failure_without_lease:true,
      event_driven_supervisor_hup:true,
      supervisor_no_polling:true,
      supervisor_preserves_client_stdin:true,
      interrupted_allocation_no_state:true,
      internal_mode_requires_lock:true,
      tmux_default:true,
      invalid_default:true,
      missing_default:true
    },
    total_launches:16
  } and
  .[1].evidence.unchanged == true and
  .[1].evidence.production_hashes_before == .[1].evidence.production_hashes_after and
  .[1].evidence.artifact_hashes == {
    adapter:$adapter_hash,
    allocator:$allocator_hash,
    fixture:$fixture_hash,
    validator:$validator_hash
  } and
  .[2].evidence == {
    status:"PASS",
    independent_window_sessions:true,
    session_policy:"restore-last-or-create-monotonic",
    production_fish_modified:false,
    installed:false,
    migration_authorized:false
  }
' "$login_attach_evidence" >/dev/null

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
      "equalize=prefix+=/Alt-=",
      "copy_search=prefix+s",
      "smart_close=prefix+x",
      "close_other_panes=prefix+o/Alt-o",
      "close_tab=prefix+X",
      "tabs=prefix+c/n/p+Alt-Ctrl-t/n/p",
      "numbered_tabs=prefix+0..9",
      "zoom=prefix+z",
      "sidebar=prefix+S",
      "ready_prompt=prefix+b/B",
      "open_url=prefix+u",
      "workspace_picker=prefix+w",
      "workspace_cycle=prefix+(/)/Ctrl-^",
      "goto=prefix+f",
      "manage_objects=prefix+Shift+f",
      "visible_references=prefix+Shift+r",
      "agent_overview=prefix+Shift+a",
      "scratch_popup=prefix+Enter",
      "lazygit_popup=prefix+g",
      "layout_menu=prefix+Space"
    ],
    result:"config: ok",
    workspace_picker:"prefix+w",
    goto:"prefix+f",
    direct_alt_ctrl_f:false,
    prefix_enter_preserved:true,
    prefix_g_preserved:true,
    prefix_space_preserved:true
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
    version:"herdr 0.7.5",
    session:"pa",
    production_configuration_modified:false,
    migration_authorized:false,
    validation_plan_steps:7
  }
' "$picker_evidence" >/dev/null

picker_reference_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
picker_reference_manager_hash=$(shasum -a 256 "$prototype/manage_objects.sh" | awk '{print $1}')
picker_reference_picker_hash=$(shasum -a 256 "$prototype/visible_reference_picker.sh" | awk '{print $1}')
picker_reference_parser_hash=$(shasum -a 256 "$prototype/visible_references.py" | awk '{print $1}')
picker_reference_client_hash=$(shasum -a 256 "$prototype/picker_client.py" | awk '{print $1}')
picker_reference_validator_hash=$(shasum -a 256 "$prototype/validate_picker_reference.sh" | awk '{print $1}')
jq -se \
  --arg config "$picker_reference_config_hash" \
  --arg manager "$picker_reference_manager_hash" \
  --arg picker "$picker_reference_picker_hash" \
  --arg parser "$picker_reference_parser_hash" \
  --arg client "$picker_reference_client_hash" \
  --arg validator "$picker_reference_validator_hash" '
  map(.check) == [
    "parser",
    "destructive_picker",
    "reference_actions",
    "config",
    "real_transport",
    "scope_audit",
    "result"
  ] and
  .[0].evidence.newest_first == true and
  .[0].evidence.duplicate_value_count == 1 and
  .[0].evidence.punctuation_trimmed == true and
  .[0].evidence.types == ["uri","path","hash"] and
  .[1].evidence.successful_targets == ["pane","tab","workspace"] and
  .[1].evidence.confirmation_cancel_inert == true and
  .[1].evidence.stale_rejections == ["pane:4","tab:4","workspace:4"] and
  .[1].evidence.picker_cancel_inert == true and
  .[1].evidence.picker_failure_status == 42 and
  .[1].evidence.one_target_per_invocation == true and
  .[2].evidence.copied == ["deadbeef"] and
  .[2].evidence.opened == [
    "https://example.test/new?x=1",
    "/work/project/./docs/guide.md",
    (env.HOME + "/notes/todo.md")
  ] and
  .[2].evidence.relative_path_resolved_from_focused_cwd == true and
  .[2].evidence.hash_open_status == 4 and
  .[2].evidence.picker_cancel_inert == true and
  .[2].evidence.picker_failure_status == 42 and
  .[2].evidence.copy_mode_used == false and
  .[3].evidence == {
    result:"config: ok",
    manage_binding:"prefix+shift+f",
    reference_binding:"prefix+shift+r",
    native_goto:"prefix+f",
    copy_mode_binding_unchanged:true
  } and
  .[4].evidence.manage_popup_via == "prefix+shift+f" and
  .[4].evidence.reference_popup_via == "prefix+shift+r" and
  .[4].evidence.copied_hash == "#a1b2c3d4" and
  .[4].evidence.parent_process_survived == true and
  .[5].evidence.unchanged == true and
  .[5].evidence.herdr_version == "0.7.5" and
  .[5].evidence.pane_history == false and
  .[5].evidence.tmux_available == true and
  .[5].evidence.copy_mode_parity_claimed == false and
  .[5].evidence.artifacts == {
    config:$config,
    manager:$manager,
    picker:$picker,
    parser:$parser,
    client:$client,
    validator:$validator
  } and
  .[6].evidence == {
    status:"PASS",
    session:"pr",
    destructive_confirmation:true,
    stale_target_checks:true,
    visible_reference_types:["uri","path","hash"],
    copy_mode_emulation:false
  }
' "$picker_reference_evidence" >/dev/null

agent_overview_hash=$(shasum -a 256 "$prototype/agent_overview.sh" | awk '{print $1}')
agent_composer_hash=$(shasum -a 256 "$prototype/agent_message_composer.py" | awk '{print $1}')
agent_fixture_hash=$(shasum -a 256 "$prototype/fixtures/agent_overview_herdr_fixture.sh" | awk '{print $1}')
agent_validator_hash=$(shasum -a 256 "$prototype/validate_agent_overview.sh" | awk '{print $1}')
agent_production_config_hash=$(shasum -a 256 "$root/herdr/config.toml" | awk '{print $1}')
agent_prototype_config_hash=$(shasum -a 256 "$prototype/config.toml" | awk '{print $1}')
jq -se \
  --arg overview "$agent_overview_hash" \
  --arg composer "$agent_composer_hash" \
  --arg fixture "$agent_fixture_hash" \
  --arg validator "$agent_validator_hash" \
  --arg production "$agent_production_config_hash" \
  --arg prototype_config "$agent_prototype_config_hash" '
  map(.check) == [
    "inventory","read","focus","message","stale_safety","bindings",
    "read_escape","implementation"
  ] and
  .[0].evidence.sessions == 3 and
  .[0].evidence.fields == ["session","agent","status","cwd"] and
  .[0].evidence.pi_discoverable == true and
  .[0].evidence.duplicate_labels_unambiguous == true and
  .[0].evidence.duplicate_pane_ids_unambiguous == true and
  .[0].evidence.on_demand == true and
  .[1].evidence == {
    bounded_lines:200,read_only:true,focus_unchanged:true
  } and
  .[2].evidence.owning_session == "beta" and
  .[2].evidence.terminal_id == "term-beta" and
  .[2].evidence.current_window_reattached == false and
  .[2].evidence.macos_window_raised == false and
  .[3].evidence.exact_multiline_bracketed_paste == true and
  .[3].evidence.submitted == false and
  .[3].evidence.send_return == false and
  .[3].evidence.focus_unchanged == true and
  .[3].evidence.empty_is_noop == true and
  .[3].evidence.unicode_backspace_valid == true and
  .[4].evidence.changed_identity_failed_closed == true and
  .[4].evidence.missing_session_status != 0 and
  .[4].evidence.untrusted_token_status != 0 and
  .[4].evidence.replacement_dispatch == false and
  .[5].evidence.overview == "prefix+shift+a" and
  .[5].evidence.adaptive_split == "prefix+a" and
  .[5].evidence.workspace_picker == "prefix+w" and
  .[5].evidence.goto == "prefix+f" and
  .[5].evidence.command_keys == "Ghostty-owned" and
  .[5].evidence.pane_history == false and
  .[6].evidence == {
    escape_returns_to_palette:true,
    kitty_csi_u_escape_consumed:true,
    reader:"less"
  } and
  .[7].evidence.hashes == {
    overview:$overview,composer:$composer,fixture:$fixture,validator:$validator,
    production_config:$production,prototype_config:$prototype_config
  } and
  .[7].evidence.remote_aggregation == false and
  .[7].evidence.destructive_actions == false and
  .[7].evidence.polling == false and
  .[7].evidence.commit_or_push == false
' "$agent_overview_evidence" >/dev/null

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
