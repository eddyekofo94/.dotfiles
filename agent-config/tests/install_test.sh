#!/bin/sh
set -eu

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
repo_dir=$(CDPATH= cd -- "$config_dir/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/agent-config-test.XXXXXX")
cleanup() {
  # The settings probe below writes through a managed link into the repository,
  # so the source is restored even when an assertion aborts the run.
  [ ! -f "$fixture/settings.json.orig" ] ||
    cp "$fixture/settings.json.orig" "$config_dir/claude/settings.json"
  rm -rf "$fixture"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$fixture/home/.codex" "$fixture/home/.claude/hooks" \
  "$fixture/home/.claude/projects/-Users-eddyekofo--dotfiles/memory"

# Every target is preflighted before any migration begins.
partial="$fixture/partial"
mkdir -p "$partial/home/.codex" "$partial/home/.claude/hooks" \
  "$partial/home/.claude/projects/-Users-eddyekofo--dotfiles/memory"
cp "$repo_dir/agent-config/AGENTS.md" "$partial/home/.codex/AGENTS.md"
cp "$config_dir/claude/CLAUDE.md" "$partial/home/.claude/CLAUDE.md"
printf 'unreviewed hook\n' >"$partial/home/.claude/hooks/closeout.sh"
cp "$config_dir/claude/response-concision.md" \
  "$partial/home/.claude/projects/-Users-eddyekofo--dotfiles/memory/response-concision.md"
cp "$config_dir/claude/settings.json" "$partial/home/.claude/settings.json"
if AGENT_CONFIG_HOME="$partial/home" \
   AGENT_CONFIG_BACKUP_DIR="$partial/backups" \
   "$config_dir/install.sh" >/dev/null 2>&1; then
  echo 'agent-config: installer partially accepted an invalid migration plan' >&2
  exit 1
fi
test ! -L "$partial/home/.codex/AGENTS.md"
test ! -L "$partial/home/.codex/config.toml"
test ! -L "$partial/home/.claude/settings.json"
test ! -L "$partial/home/.claude/keybindings.json"
test ! -e "$partial/backups"

AGENT_CONFIG_HOME="$fixture/home" \
  AGENT_CONFIG_BACKUP_DIR="$fixture/backups" \
  "$config_dir/install.sh" >/dev/null
for profile in browser computer-use design docs ios office sites; do
  test -L "$fixture/home/.codex/$profile.config.toml"
  test "$(readlink "$fixture/home/.codex/$profile.config.toml")" = \
    "$config_dir/codex/$profile.config.toml"
done
AGENT_CONFIG_HOME="$fixture/home" "$config_dir/verify.sh" >/dev/null

# Claude Code and `herdr integration install` rewrite settings.json in place
# instead of replacing it, which is what makes the whole file safe to manage as
# a link. Prove an in-place write keeps the link and reaches the repository.
cp "$config_dir/claude/settings.json" "$fixture/settings.json.orig"
printf '{"probe": true}\n' >"$fixture/home/.claude/settings.json"
test -L "$fixture/home/.claude/settings.json"
grep -Fq '"probe": true' "$config_dir/claude/settings.json"
cp "$fixture/settings.json.orig" "$config_dir/claude/settings.json"
rm "$fixture/settings.json.orig"

# Idempotency.
AGENT_CONFIG_HOME="$fixture/home" \
AGENT_CONFIG_BACKUP_DIR="$fixture/backups" \
  "$config_dir/install.sh" >/dev/null

# Reviewed exact source files can migrate to managed links.
rm "$fixture/home/.codex/AGENTS.md"
cp "$repo_dir/agent-config/AGENTS.md" "$fixture/home/.codex/AGENTS.md"
rm "$fixture/home/.codex/config.toml"
cp "$config_dir/codex/config.toml" "$fixture/home/.codex/config.toml"
rm "$fixture/home/.claude/keybindings.json"
cp "$config_dir/claude/keybindings.json" "$fixture/home/.claude/keybindings.json"
AGENT_CONFIG_HOME="$fixture/home" \
AGENT_CONFIG_BACKUP_DIR="$fixture/backups" \
  "$config_dir/install.sh" >/dev/null
test -f "$fixture/backups/codex-agents.pre-repository"
test -f "$fixture/backups/codex-config.pre-repository"
test -f "$fixture/backups/claude-keybindings.pre-repository"

# Retargeted links and unrelated regular files fail closed.
rm "$fixture/home/.codex/AGENTS.md"
ln -s /tmp/unreviewed-agent-rules "$fixture/home/.codex/AGENTS.md"
if AGENT_CONFIG_HOME="$fixture/home" \
   AGENT_CONFIG_BACKUP_DIR="$fixture/backups" \
   "$config_dir/install.sh" >/dev/null 2>&1; then
  echo 'agent-config: installer accepted a retargeted link' >&2
  exit 1
fi
rm "$fixture/home/.codex/AGENTS.md"
ln -s "$repo_dir/agent-config/AGENTS.md" "$fixture/home/.codex/AGENTS.md"
rm "$fixture/home/.claude/CLAUDE.md"
printf 'unreviewed\n' >"$fixture/home/.claude/CLAUDE.md"
if AGENT_CONFIG_HOME="$fixture/home" \
   AGENT_CONFIG_BACKUP_DIR="$fixture/backups" \
   "$config_dir/install.sh" >/dev/null 2>&1; then
  echo 'agent-config: installer accepted an unrelated predecessor' >&2
  exit 1
fi

echo 'agent config installer tests: PASS'
