#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
ZSH_DIR="$ROOT/zsh"
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/zsh-startup-verify.XXXXXX")
trap 'rm -rf -- "$FIXTURE"' EXIT HUP INT TERM

zsh -n "$ZSH_DIR/.zshenv" "$ZSH_DIR/.zprofile" "$ZSH_DIR/.zshrc"

mkdir -p "$FIXTURE/.config/zsh"
ln -s "$ROOT" "$FIXTURE/.dotfiles"
ln -s "$ZSH_DIR/.zshenv" "$FIXTURE/.config/zsh/.zshenv"
ln -s "$ZSH_DIR/.zprofile" "$FIXTURE/.config/zsh/.zprofile"
ln -s "$ZSH_DIR/.zshrc" "$FIXTURE/.config/zsh/.zshrc"

run_fixture() {
    env -i \
        HOME="$FIXTURE" \
        PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        TERM=agent-term \
        COLORTERM=agent-color \
        EDITOR=agent-editor \
        VISUAL=agent-visual \
        XDG_CONFIG_HOME="$FIXTURE/.config" \
        XDG_CACHE_HOME="$FIXTURE/.cache" \
        XDG_DATA_HOME="$FIXTURE/.data" \
        ZDOTDIR="$FIXTURE/.config/zsh" \
        /bin/zsh -l -c "$1"
}

missing_output=$(run_fixture \
    'print -r -- "$TERM|$COLORTERM|$EDITOR|$VISUAL|$XDG_CONFIG_HOME|$XDG_DATA_HOME|${LOCAL_ENV_SENTINEL:-missing}"' \
    2>&1)
expected_missing="agent-term|agent-color|agent-editor|agent-visual|$FIXTURE/.config|$FIXTURE/.data|missing"
[[ "$missing_output" == "$expected_missing" ]]
[[ ! -e "$FIXTURE/.config/zsh/znap" ]]
[[ ! -e "$FIXTURE/.terminfo/w/wezterm" ]]

run_interactive_agent_fixture() {
    agent_marker=$1
    interactive_output=$(/usr/bin/script -q /dev/null \
        /usr/bin/env -i \
        "$agent_marker=1" \
        HOME="$FIXTURE" \
        PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        TERM=agent-term \
        XDG_CONFIG_HOME="$FIXTURE/.config" \
        XDG_CACHE_HOME="$FIXTURE/.cache" \
        ZDOTDIR="$FIXTURE/.config/zsh" \
        /bin/zsh -ilc "print -r -- interactive-$agent_marker-ok" 2>&1)
    grep -Fq "interactive-$agent_marker-ok" <<<"$interactive_output"
    ! grep -Eiq 'no such file|source:|command not found|clone|download|install' \
        <<<"$interactive_output"
    [[ ! -e "$FIXTURE/.config/zsh/znap" ]]
    [[ ! -e "$FIXTURE/.terminfo/w/wezterm" ]]
    ! find "$FIXTURE" -name '.zcompdump*' -print -quit | grep -q .
}

for agent_marker in AI_AGENT CLAUDECODE CI; do
    run_interactive_agent_fixture "$agent_marker"
done

touch "$FIXTURE/cache-blocker"
cache_output=$(env -i \
    HOME="$FIXTURE" \
    PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM=agent-term \
    XDG_CONFIG_HOME="$FIXTURE/.config" \
    XDG_CACHE_HOME="$FIXTURE/cache-blocker/child" \
    ZDOTDIR="$FIXTURE/.config/zsh" \
    /bin/zsh -c 'print -r -- cache-failure-is-soft' 2>&1)
[[ "$cache_output" == cache-failure-is-soft ]]

printf '%s\n' 'export LOCAL_ENV_SENTINEL=loaded' >"$FIXTURE/.local.env"
present_output=$(run_fixture 'print -r -- "$LOCAL_ENV_SENTINEL"' 2>&1)
[[ "$present_output" == loaded ]]

git -C "$ROOT" diff --check

printf 'zsh startup verification: PASS\n'
