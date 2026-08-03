#!/bin/sh
set -eu

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
repo_dir=$(CDPATH= cd -- "$config_dir/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/agent-config-test.XXXXXX")
cleanup() { rm -rf "$fixture"; }
trap cleanup EXIT HUP INT TERM

mkdir -p "$fixture/home/.codex" "$fixture/home/.claude/hooks" \
  "$fixture/home/.claude/projects/-Users-eddyekofo--dotfiles/memory"

# Every target is preflighted before any migration begins.
partial="$fixture/partial"
mkdir -p "$partial/home/.codex" "$partial/home/.claude/hooks" \
  "$partial/home/.claude/projects/-Users-eddyekofo--dotfiles/memory"
cp "$repo_dir/pi/AGENTS.md" "$partial/home/.codex/AGENTS.md"
cp "$config_dir/claude/CLAUDE.md" "$partial/home/.claude/CLAUDE.md"
printf 'unreviewed hook\n' >"$partial/home/.claude/hooks/closeout.sh"
cp "$config_dir/claude/response-concision.md" \
  "$partial/home/.claude/projects/-Users-eddyekofo--dotfiles/memory/response-concision.md"
if AGENT_CONFIG_HOME="$partial/home" \
   AGENT_CONFIG_BACKUP_DIR="$partial/backups" \
   "$config_dir/install.sh" >/dev/null 2>&1; then
  echo 'agent-config: installer partially accepted an invalid migration plan' >&2
  exit 1
fi
test ! -L "$partial/home/.codex/AGENTS.md"
test ! -e "$partial/backups"

AGENT_CONFIG_HOME="$fixture/home" \
AGENT_CONFIG_BACKUP_DIR="$fixture/backups" \
  "$config_dir/install.sh" >/dev/null
AGENT_CONFIG_HOME="$fixture/home" "$config_dir/verify.sh" >/dev/null

# Idempotency.
AGENT_CONFIG_HOME="$fixture/home" \
AGENT_CONFIG_BACKUP_DIR="$fixture/backups" \
  "$config_dir/install.sh" >/dev/null

# A reviewed exact source file can migrate to a managed link.
rm "$fixture/home/.codex/AGENTS.md"
cp "$repo_dir/pi/AGENTS.md" "$fixture/home/.codex/AGENTS.md"
AGENT_CONFIG_HOME="$fixture/home" \
AGENT_CONFIG_BACKUP_DIR="$fixture/backups" \
  "$config_dir/install.sh" >/dev/null
test -f "$fixture/backups/codex-agents.pre-repository"

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
ln -s "$repo_dir/pi/AGENTS.md" "$fixture/home/.codex/AGENTS.md"
rm "$fixture/home/.claude/CLAUDE.md"
printf 'unreviewed\n' >"$fixture/home/.claude/CLAUDE.md"
if AGENT_CONFIG_HOME="$fixture/home" \
   AGENT_CONFIG_BACKUP_DIR="$fixture/backups" \
   "$config_dir/install.sh" >/dev/null 2>&1; then
  echo 'agent-config: installer accepted an unrelated predecessor' >&2
  exit 1
fi

echo 'agent config installer tests: PASS'
