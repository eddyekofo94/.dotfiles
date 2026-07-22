#!/bin/sh
set -eu

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
repo_dir=$(CDPATH= cd -- "$package_dir/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/fish-startup-consumer.XXXXXX")
trap 'find "$tmp_dir" -depth -delete' EXIT HUP INT TERM

fixture_home="$tmp_dir/home"
fixture_config="$tmp_dir/config"
fixture_data="$tmp_dir/data"
fixture_state="$tmp_dir/state"
fixture_cache="$fixture_home/.cache"
mkdir -p "$fixture_home" "$fixture_config" "$fixture_data" "$fixture_state" \
    "$fixture_cache/fish"

# Maintenance owns only its named generated files. An old cache from another
# consumer must survive a refresh.
unrelated_cache="$fixture_cache/fish/unrelated-consumer.fish"
printf 'UNRELATED_CACHE_SENTINEL\n' >"$unrelated_cache"
touch -t 202001010000 "$unrelated_cache"

refresh_output=$(env \
    HOME="$fixture_home" \
    XDG_CONFIG_HOME="$fixture_config" \
    XDG_DATA_HOME="$fixture_data" \
    XDG_STATE_HOME="$fixture_state" \
    XDG_CACHE_HOME="$fixture_cache" \
    fish --no-config -c '
        set -gx fisher_path "$argv[1]/.fisher"
        set -gx my_plugins_path "$argv[1]/plugins"
        source "$argv[1]/functions/init_fisher.fish"
        source "$argv[1]/scripts/refresh_startup.fish"
    ' "$package_dir")
printf '%s\n' "$refresh_output" | rg -q '^Fish startup maintenance: PASS$'
test -f "$unrelated_cache"
rg -q '^UNRELATED_CACHE_SENTINEL$' "$unrelated_cache"
test -s "$fixture_cache/fish/dotfiles_environment.fish"

# The maintenance command must normalize the same known-bad inherited XDG
# values as interactive Fish, otherwise it prepares caches startup never reads.
legacy_home="$tmp_dir/legacy-home"
mkdir -p "$legacy_home"
legacy_output=$(env \
    HOME="$legacy_home" \
    XDG_CONFIG_HOME="$legacy_home/.config" \
    XDG_DATA_HOME="$legacy_home/.config/.local/share" \
    XDG_STATE_HOME="$legacy_home/.config/.local/state" \
    XDG_CACHE_HOME="$legacy_home/.config/.cache" \
    fish --no-config -c '
        set -gx fisher_path "$argv[1]/.fisher"
        set -gx my_plugins_path "$argv[1]/plugins"
        source "$argv[1]/functions/init_fisher.fish"
        source "$argv[1]/scripts/refresh_startup.fish"
    ' "$package_dir")
printf '%s\n' "$legacy_output" | rg -q '^Fish startup maintenance: PASS$'
test -s "$legacy_home/.cache/fish/dotfiles_environment.fish"
test ! -e "$legacy_home/.config/.cache/fish/dotfiles_environment.fish"

# A failed generator must preserve the last known-good cache, remove its
# temporary output, return nonzero, and never claim PASS.
failure_home="$tmp_dir/failure-home"
failure_bin="$tmp_dir/failure-bin"
mkdir -p "$failure_home/.cache/fish" "$failure_bin"
printf 'LAST_KNOWN_GOOD_FZF_CACHE\n' >"$failure_home/.cache/fish/fzf_completion.fish"
printf '#!/bin/sh\nexit 42\n' >"$failure_bin/fzf"
chmod +x "$failure_bin/fzf"
if failure_output=$(env \
    HOME="$failure_home" \
    PATH="$failure_bin:$PATH" \
    fish --no-config -c '
        set -gx fisher_path "$argv[1]/.fisher"
        set -gx my_plugins_path "$argv[1]/plugins"
        source "$argv[1]/functions/init_fisher.fish"
        source "$argv[1]/scripts/refresh_startup.fish"
    ' "$package_dir" 2>&1); then
    echo 'startup consumer: failed fzf generator returned success' >&2
    exit 1
fi
printf '%s\n' "$failure_output" | rg --fixed-strings --quiet \
    'Fish startup maintenance: FAIL (fzf --fish)'
if printf '%s\n' "$failure_output" | rg -q 'Fish startup maintenance: PASS'; then
    echo 'startup consumer: failed generator claimed PASS' >&2
    exit 1
fi
rg -q '^LAST_KNOWN_GOOD_FZF_CACHE$' "$failure_home/.cache/fish/fzf_completion.fish"
test -z "$(find "$failure_home/.cache/fish" -name 'fzf_completion.fish.*' -print -quit)"

# A failed verified Fisher bootstrap must remain retryable. In particular, it
# must not leave an empty installation directory that makes the next attempt
# look successfully installed.
fisher_failure_home="$tmp_dir/fisher-failure-home"
fisher_failure_path="$tmp_dir/incomplete-fisher"
mkdir -p "$fisher_failure_home/.config/fish" "$fisher_failure_home/.config/tools"
printf '#!/bin/sh\nexit 42\n' \
    >"$fisher_failure_home/.config/tools/fetch_fisher_verified.sh"
chmod +x "$fisher_failure_home/.config/tools/fetch_fisher_verified.sh"
fisher_failure_output=$(env \
    HOME="$fisher_failure_home" \
    XDG_CONFIG_HOME="$fisher_failure_home/.config" \
    fish --no-config -c '
    source "$argv[1]/functions/init_fisher.fish"
    set -gx fisher_path "$argv[2]"
    set -gx my_plugins_path "$argv[1]/plugins"
    init_fisher --install
    set first_status $status
    set first_dir (test -d "$fisher_path"; and echo yes; or echo no)
    echo "first=$first_status dir=$first_dir"
    init_fisher --install
    set second_status $status
    set second_dir (test -d "$fisher_path"; and echo yes; or echo no)
    echo "second=$second_status dir=$second_dir"
' "$package_dir" "$fisher_failure_path")
printf '%s\n' "$fisher_failure_output" | rg -q '^first=1 dir=no$'
printf '%s\n' "$fisher_failure_output" | rg -q '^second=1 dir=no$'
test ! -e "$fisher_failure_path"

# A shell with no prepared cache must still load deterministic environment,
# plugin functions, abbreviations, and on-demand Git helpers without writing
# startup state.
missing_home="$tmp_dir/missing-home"
mkdir -p "$missing_home/.config"
ln -s "$package_dir" "$missing_home/.config/fish"
missing_output=$(env \
    HOME="$missing_home" \
    XDG_CONFIG_HOME="$missing_home/.config" \
    TMUX=FISH_STARTUP_CONSUMER_GUARD \
    fish -i -c '
        function fail
            echo "startup consumer: $argv" >&2
            exit 1
        end

        test "$XDG_CONFIG_HOME" = "$HOME/.config"; or fail "XDG config fallback"
        test "$XDG_CACHE_HOME" = "$HOME/.cache"; or fail "XDG cache fallback"
        test "$DOT_DIR" = "$HOME/.dotfiles"; or fail "dotfiles fallback"
        functions -q _fzf_search_directory; or fail "fzf.fish functions missing"
        functions -q magic-enter; or fail "magic-enter missing"
        functions -q fifc; or fail "fifc missing"
        abbr --show ggp | string match -q "*get_current_branch*"; or fail "Git abbreviation missing"
        set -q JAVA_HOME; and not test -d "$JAVA_HOME"; and fail "invalid Java fallback"
        test -n "$PATH"; or fail "PATH missing"
        true
    ' 2>&1)
if test -n "$missing_output"; then
    echo 'startup consumer: missing-cache shell produced output' >&2
    printf '%s\n' "$missing_output" >&2
    exit 1
fi
test ! -e "$missing_home/.cache/fish/brew_init.fish"
test ! -e "$missing_home/.cache/fish/fzf_completion.fish"
test ! -e "$missing_home/.cache/fish/zoxide_init.fish"
test ! -e "$missing_home/.cache/fish/starship_init.fish"

fish -i -c 'builtin cd "$argv[1]"; test -n (get_current_branch)' "$repo_dir" >/dev/null
fish -i -c 'builtin cd "$argv[1]"; test -z (get_current_branch)' "$tmp_dir" >/dev/null

printf 'Fish startup consumer integration: PASS\n'
