#!/bin/sh
set -eu

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$config_dir/.." && pwd)
agent_home=${AGENT_CONFIG_HOME:-$HOME}

verify_link() {
  target=$1
  source=$2
  [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ] || {
    echo "agent-config: invalid managed link: $target" >&2
    exit 1
  }
}

verify_link "$agent_home/.codex/AGENTS.md" "$repo_dir/agent-config/AGENTS.md"
verify_link "$agent_home/.codex/config.toml" "$config_dir/codex/config.toml"
for profile in browser computer-use design docs ios office sites; do
  verify_link "$agent_home/.codex/$profile.config.toml" \
    "$config_dir/codex/$profile.config.toml"
done
verify_link "$agent_home/.claude/CLAUDE.md" "$config_dir/claude/CLAUDE.md"
verify_link "$agent_home/.claude/hooks/closeout.sh" "$config_dir/claude/closeout.sh"
verify_link \
  "$agent_home/.claude/projects/-Users-eddyekofo--dotfiles/memory/response-concision.md" \
  "$config_dir/claude/response-concision.md"
verify_link "$agent_home/.claude/settings.json" "$config_dir/claude/settings.json"
verify_link "$agent_home/.claude/keybindings.json" "$config_dir/claude/keybindings.json"
verify_link "$agent_home/.claude/statusline-command.sh" \
  "$config_dir/claude/statusline-command.sh"
verify_link "$agent_home/.claude/statusline-tokens.py" \
  "$config_dir/claude/statusline-tokens.py"

[ -x "$config_dir/claude/closeout.sh" ]
[ "$(cat "$config_dir/claude/CLAUDE.md")" = \
  '@/Users/eddyekofo/.dotfiles/agent-config/AGENTS.md' ]
grep -Fq '## Response Style (highest priority)' \
  "$repo_dir/agent-config/AGENTS.md"
grep -Fq '## Closeout' "$repo_dir/agent-config/AGENTS.md"
# The shared loop standard must be owned here, not by an unrelated project.
[ -s "$config_dir/agentic_loop_standard.md" ]
grep -Fxq '/Users/eddyekofo/.dotfiles/agent-config/agentic_loop_standard.md' \
  "$config_dir/AGENTS.md"
jq empty "$agent_home/.claude/keybindings.json"
CODEX_HOME="$agent_home/.codex" \
  "${CODEX_BIN:-codex}" --strict-config --version >/dev/null
for profile in browser computer-use design docs ios office sites; do
  CODEX_HOME="$agent_home/.codex" \
    "${CODEX_BIN:-codex}" --strict-config --profile "$profile" --version >/dev/null
done

node "$config_dir/tests/on_demand_skill_test.mjs"
python3.14 "$repo_dir/tools/verify_agent_catalog.py"

python3 "$config_dir/tests/closeout_length_test.py"
python3 "$config_dir/tests/closeout_capture_test.py"
python3 "$config_dir/tests/context_budget_check_test.py"
python3 "$config_dir/tests/xcode_settings_test.py"
python3 "$config_dir/tests/build_budget_guard_test.py"
python3 "$config_dir/tests/no_shell_step_for_eddy_test.py"
sh "$config_dir/tests/statusline_test.sh"

# settings.json is what actually wires the closeout hooks up, so a restore that
# recovers the scripts but not their registrations is a silent no-op. Each entry
# is asserted through the managed link, which covers the sandbox home too.
jq -e '
  ([.hooks.SessionEnd[]?.hooks[]?.command] |
    any(contains("closeout.sh\" end"))) and
  ([.hooks.Stop[]?.hooks[]?.command] |
    any(contains("closeout.sh\" length")) and
    any(contains("closeout.sh\" capture"))) and
  ([.hooks.UserPromptSubmit[]?.hooks[]?.command] |
    any(contains("closeout.sh\" context")))
' "$agent_home/.claude/settings.json" >/dev/null || {
  echo "agent-config: settings.json does not register the closeout hooks" >&2
  exit 1
}

xcode_home="$agent_home/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig"
if [ -d "$xcode_home" ]; then
  verify_link "$xcode_home/CLAUDE.md" "$config_dir/claude/CLAUDE.md"
  verify_link "$xcode_home/skills" "$agent_home/.claude/skills"
  python3 -I "$config_dir/claude/xcode_settings.py" "$config_dir/claude/settings.json" |
    cmp -s - "$xcode_home/settings.json" || {
    echo "agent-config: Xcode's Claude settings are stale; run agent-config/install.sh" >&2
    exit 1
  }
  ! grep -Eq 'closeout\.sh|agent_status\.py|herdr-agent-state\.sh|retro_due\.py|statusLine' \
    "$xcode_home/settings.json" || {
    echo "agent-config: Xcode's Claude settings carry a terminal-tab hook" >&2
    exit 1
  }
fi

hook_json=$(printf '' | "$config_dir/claude/closeout.sh" context)
jq -e '
  .hookSpecificOutput.hookEventName == "UserPromptSubmit" and
  (.hookSpecificOutput.additionalContext | contains("## Enforced Closeout")) and
  (.hookSpecificOutput.additionalContext | contains("## Response Style") | not) and
  (.hookSpecificOutput.additionalContext | contains("## Closeout") | not) and
  (.hookSpecificOutput.additionalContext | contains("## Agentic Loop Standard") | not)
' <<EOF >/dev/null
$hook_json
EOF

echo 'agent config verification: PASS'
