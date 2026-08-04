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

verify_link "$agent_home/.codex/AGENTS.md" "$repo_dir/pi/AGENTS.md"
verify_link "$agent_home/.claude/CLAUDE.md" "$config_dir/claude/CLAUDE.md"
verify_link "$agent_home/.claude/hooks/closeout.sh" "$config_dir/claude/closeout.sh"
verify_link \
  "$agent_home/.claude/projects/-Users-eddyekofo--dotfiles/memory/response-concision.md" \
  "$config_dir/claude/response-concision.md"

[ -x "$config_dir/claude/closeout.sh" ]
[ "$(cat "$config_dir/claude/CLAUDE.md")" = \
  '@/Users/eddyekofo/.dotfiles/pi/AGENTS.md' ]
grep -Fq '## Response Style (highest priority)' \
  "$repo_dir/pi/AGENTS.md"
grep -Fq '## Closeout' "$repo_dir/pi/AGENTS.md"

python3 "$config_dir/tests/closeout_length_test.py"
python3 "$config_dir/tests/closeout_capture_test.py"

# Without the SessionEnd hook, a finished session's closeout stays in the temp
# directory and the next agent to take that pane id inherits it. settings.json
# is Eddy's own file rather than a managed link, so this asserts the live
# install only; the installer's sandbox home has no settings.json to check.
if [ -z "${AGENT_CONFIG_HOME:-}" ]; then
  jq -e '
    [.hooks.SessionEnd[]?.hooks[]?.command] | any(contains("closeout.sh\" end"))
  ' "$agent_home/.claude/settings.json" >/dev/null || {
    echo "agent-config: SessionEnd does not run the closeout cleanup" >&2
    exit 1
  }
fi

hook_json=$(printf '' | "$config_dir/claude/closeout.sh" context)
jq -e '
  .hookSpecificOutput.hookEventName == "UserPromptSubmit" and
  (.hookSpecificOutput.additionalContext | startswith("## Response Style")) and
  (.hookSpecificOutput.additionalContext | contains("## Closeout")) and
  (.hookSpecificOutput.additionalContext | contains("## Agentic Loop Standard") | not)
' <<EOF >/dev/null
$hook_json
EOF

echo 'agent config verification: PASS'
