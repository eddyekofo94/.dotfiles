#!/bin/sh
set -eu

config_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$config_dir/.." && pwd)
agent_home=${AGENT_CONFIG_HOME:-$HOME}
backup_dir=${AGENT_CONFIG_BACKUP_DIR:-"$repo_dir/.backups/agent-config"}

preflight_link() {
  label=$1
  target=$2
  source=$3
  predecessor_sha=$4
  parent=$(dirname -- "$target")

  [ ! -L "$parent" ] && [ -d "$parent" ] || {
    echo "agent-config: invalid parent for $label: $parent" >&2
    exit 1
  }
  [ ! -L "$source" ] && [ -f "$source" ] || {
    echo "agent-config: invalid repository source for $label" >&2
    exit 1
  }

  if [ -L "$target" ]; then
    [ "$(readlink "$target")" = "$source" ] || {
      echo "agent-config: refusing retargeted $label link" >&2
      exit 1
    }
    return 0
  fi

  if [ -e "$target" ]; then
    [ -f "$target" ] || {
      echo "agent-config: refusing non-file $label target" >&2
      exit 1
    }
    actual_sha=$(shasum -a 256 "$target" | awk '{print $1}')
    if [ "$actual_sha" != "$predecessor_sha" ] && ! cmp -s "$target" "$source"; then
      echo "agent-config: refusing unreviewed $label predecessor" >&2
      exit 1
    fi
    backup="$backup_dir/$label.pre-repository"
    if [ -e "$backup" ]; then
      cmp -s "$target" "$backup" || {
        echo "agent-config: refusing conflicting $label backup" >&2
        exit 1
      }
    fi
  fi
}

install_link() {
  label=$1
  target=$2
  source=$3

  [ ! -L "$target" ] || return 0
  if [ -e "$target" ]; then
    mkdir -p "$backup_dir"
    backup="$backup_dir/$label.pre-repository"
    if [ -e "$backup" ]; then
      rm "$target"
    else
      mv "$target" "$backup"
    fi
  fi

  ln -s "$source" "$target"
}

preflight_link codex-agents \
  "$agent_home/.codex/AGENTS.md" \
  "$repo_dir/agent-config/AGENTS.md" \
  8af457a0fbc10cce7d15d22558ffac1c18528e0539323ce9ac27ea1b06f91fa3
preflight_link claude-instructions \
  "$agent_home/.claude/CLAUDE.md" \
  "$config_dir/claude/CLAUDE.md" \
  17a6644c07ddfe703e69b1a15e5a6a49a7577add024122a5d9e851861a5aa741
preflight_link claude-closeout-hook \
  "$agent_home/.claude/hooks/closeout.sh" \
  "$config_dir/claude/closeout.sh" \
  9f05f1e7734b862de28ba2a32c971bf639b780254e56212afb839cdb86345ea6
preflight_link claude-response-memory \
  "$agent_home/.claude/projects/-Users-eddyekofo--dotfiles/memory/response-concision.md" \
  "$config_dir/claude/response-concision.md" \
  0d9f6751da5da36bef7adda108c51d8f86c6a0ebe836c705487ecb1f59911845
# Claude Code and `herdr integration install` rewrite settings.json in place,
# so the link survives their edits and their changes land as reviewable repo
# diffs. A writer that swapped in a fresh file instead would leave a regular
# file here, and verify.sh would fail on the unmanaged link.
preflight_link claude-settings \
  "$agent_home/.claude/settings.json" \
  "$config_dir/claude/settings.json" \
  6942780acf9eeca5065a5d295e77e3915a1661623e7e8942b365c8b85c456cdd

install_link codex-agents \
  "$agent_home/.codex/AGENTS.md" "$repo_dir/agent-config/AGENTS.md"
install_link claude-instructions \
  "$agent_home/.claude/CLAUDE.md" "$config_dir/claude/CLAUDE.md"
install_link claude-closeout-hook \
  "$agent_home/.claude/hooks/closeout.sh" "$config_dir/claude/closeout.sh"
# closeout.sh resolves its helpers next to itself, so they need their own links
# rather than riding along with the shell entry point.
install_link claude-closeout-length \
  "$agent_home/.claude/hooks/closeout_length.py" "$config_dir/claude/closeout_length.py"
install_link claude-closeout-capture \
  "$agent_home/.claude/hooks/closeout_capture.py" "$config_dir/claude/closeout_capture.py"
install_link claude-response-memory \
  "$agent_home/.claude/projects/-Users-eddyekofo--dotfiles/memory/response-concision.md" \
  "$config_dir/claude/response-concision.md"
install_link claude-settings \
  "$agent_home/.claude/settings.json" "$config_dir/claude/settings.json"

AGENT_CONFIG_HOME="$agent_home" "$config_dir/verify.sh"
echo 'agent config installation: PASS'
