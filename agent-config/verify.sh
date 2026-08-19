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
verify_link "$agent_home/.claude/CLAUDE.md" "$config_dir/claude/CLAUDE.md"
verify_link "$agent_home/.claude/hooks/closeout.sh" "$config_dir/claude/closeout.sh"
verify_link \
  "$agent_home/.claude/projects/-Users-eddyekofo--dotfiles/memory/response-concision.md" \
  "$config_dir/claude/response-concision.md"
verify_link "$agent_home/.claude/settings.json" "$config_dir/claude/settings.json"

[ -x "$config_dir/claude/closeout.sh" ]
[ "$(cat "$config_dir/claude/CLAUDE.md")" = \
  '@/Users/eddyekofo/.dotfiles/agent-config/AGENTS.md' ]
grep -Fq '## Response Style (highest priority)' \
  "$repo_dir/agent-config/AGENTS.md"
grep -Fq '## Closeout' "$repo_dir/agent-config/AGENTS.md"

python3 "$config_dir/tests/closeout_length_test.py"
python3 "$config_dir/tests/closeout_capture_test.py"

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
