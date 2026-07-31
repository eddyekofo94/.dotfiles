#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# shellcheck source=/dev/null
. "$root/herdr/source-build/pins.env"

agent_home=${HERDR_AGENT_HOME:-"$HOME"}
herdr_bin=${HERDR_BIN_PATH:-"$agent_home/.local/bin/herdr"}
herdr_config=${HERDR_CONFIG_PATH:-"$agent_home/.config/herdr/config.toml"}
claude_settings="$agent_home/.claude/settings.json"
codex_config="$agent_home/.codex/config.toml"
codex_hooks="$agent_home/.codex/hooks.json"
codex_trusted_hash=sha256:4274f9bbccd603167ff51185dd1b0aff0d7a0baeaf97b494efe78bbcd969aebf
opencode_dir="$agent_home/.config/opencode"

test "$("$herdr_bin" --version)" = "herdr $HERDR_VERSION"
test "$(readlink "$agent_home/.config/herdr/config.toml")" = \
  "$root/herdr/config.toml"
rg -q '^pane_history = false$' "$herdr_config"
rg -q "^set -g @resurrect-capture-pane-contents 'off'$" \
  "$root/tmux/tmux.conf"

integration_status=$("$herdr_bin" integration status)
installed_integrations=$(
  printf '%s\n' "$integration_status" |
    awk -F: '$2 !~ /^ not installed / {print $1}' |
    sort |
    paste -sd, -
)
current_integrations=$(
  printf '%s\n' "$integration_status" |
    awk -F: '$2 ~ /^ current / {print $1}' |
    sort |
    paste -sd, -
)
test "$installed_integrations" = "claude,codex,opencode"
test "$current_integrations" = "claude,codex,opencode"

test -x "$agent_home/.claude/hooks/herdr-agent-state.sh"
rg -q '^# HERDR_INTEGRATION_ID=claude$' \
  "$agent_home/.claude/hooks/herdr-agent-state.sh"
jq -e '
  . as $settings |
  ([
    "Notification", "PermissionRequest", "SessionEnd", "SessionStart",
    "Stop", "StopFailure", "UserPromptSubmit"
  ] - (.hooks | keys) | length == 0) and
  all(
    [
      "Notification", "PermissionRequest", "SessionEnd", "SessionStart",
      "Stop", "StopFailure", "UserPromptSubmit"
    ][];
    any($settings.hooks[.][]?; tostring | contains("agent_status.py"))
  ) and
  any(.hooks.SessionStart[]?; tostring | contains("herdr-agent-state.sh")) and
  any(.hooks.UserPromptSubmit[]?; tostring | contains("closeout.sh")) and
  .enabledPlugins["swift-lsp@claude-plugins-official"] == true
' "$claude_settings" >/dev/null

test -x "$agent_home/.codex/herdr-agent-state.sh"
rg -q '^# HERDR_INTEGRATION_ID=codex$' \
  "$agent_home/.codex/herdr-agent-state.sh"
test -L "$codex_hooks"
test "$(readlink "$codex_hooks")" = "$root/tmux/hooks/codex.json"
jq -e --arg herdr_command \
  "bash '$agent_home/.codex/herdr-agent-state.sh' session" '
  . as $catalog |
  (["PermissionRequest", "SessionStart", "Stop", "UserPromptSubmit"] -
    (.hooks | keys) | length == 0) and
  all(
    ["PermissionRequest", "SessionStart", "Stop", "UserPromptSubmit"][];
    any($catalog.hooks[.][]?; tostring | contains("agent_status.py"))
  ) and
  .hooks.SessionStart[1] == {
    hooks: [{
      command: $herdr_command,
      timeout: 10,
      type: "command"
    }]
  }
' "$codex_hooks" >/dev/null
rg -q '^hooks = true$' "$codex_config"
awk -v section="[hooks.state.\"$codex_hooks:session_start:1:0\"]" \
  -v trusted_hash="$codex_trusted_hash" '
    $0 == section { in_section = 1; next }
    in_section && /^\[/ { exit }
    in_section && $0 == "trusted_hash = \"" trusted_hash "\"" { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$codex_config"

test -f "$opencode_dir/plugins/herdr-agent-state.js"
test -f "$opencode_dir/plugins/tmux-agent-status.js"
rg -q 'HERDR_INTEGRATION_ID=opencode' \
  "$opencode_dir/plugins/herdr-agent-state.js"
node --check "$opencode_dir/plugins/herdr-agent-state.js"
node --check "$opencode_dir/plugins/tmux-agent-status.js"
jq empty "$opencode_dir/opencode.json" "$opencode_dir/package.json"

printf '%s\n' "$integration_status" |
  rg '^(claude|codex|opencode): current '
echo "Herdr integration verification: PASS"
