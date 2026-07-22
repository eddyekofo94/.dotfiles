#!/bin/sh
set -eu

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
repo_dir=$(CDPATH= cd -- "$package_dir/.." && pwd)
fish_bin=$(command -v fish)
fish_bin_dir=$(dirname -- "$fish_bin")

owned_files="$package_dir/conf.d/__init__.fish
$package_dir/conf.d/env.fish
$package_dir/conf.d/brew.fish
$package_dir/conf.d/uv.env.fish
$package_dir/config.fish"

universal_findings=$(
    printf '%s\n' "$owned_files" |
        xargs rg -n 'set[[:space:]].*(--universal|-[[:alpha:]]*U[[:alpha:]]*)' || true
)
if [ -n "$universal_findings" ]; then
    echo 'Fish environment audit: universal environment assignment found' >&2
    printf '%s\n' "$universal_findings" >&2
    exit 1
fi

if printf '%s\n' "$owned_files" | xargs rg -n 'fish_add_path' |
    rg -v 'fish_add_path --global'; then
    echo 'Fish environment audit: fish_add_path must use global scope' >&2
    exit 1
fi

if rg -n '^SETUVAR.*(BAT_CONFIG_PATH|BROWSER|BUN_INSTALL|DOT_DIR|EDITOR|FISH_CONFIG|FISH_THEME|GNUPGHOME|HOMEBREW_KEG_ONLY_APPS|JAVA_HOME|LAZYGIT_DIR|LESSHISTFILE|LS_COLORS|NVIM_DIR|NVIM_NF|PAGER|PYLINTHOME|SQLITE_HISTORY|TERM|VISUAL|WORKON_HOME|XDG_(CACHE|CONFIG|DATA|STATE)_HOME|fifc_editor|fish_user_paths):' \
    "$package_dir/fish_variables"; then
    echo 'Fish environment audit: deterministic environment leaked into universal state' >&2
    exit 1
fi

if rg -n 'source .*\.local/share/\.\./bin/env\.fish' "$package_dir/conf.d/uv.env.fish"; then
    echo 'Fish environment audit: noncanonical uv PATH source found' >&2
    exit 1
fi

rg -q '^if test -r "\$HOME/\.cargo/env\.fish"$' "$package_dir/conf.d/env.fish"
test -r "$package_dir/conf.d/_fzf_envs.fish"

base_path=/usr/bin:/bin:/usr/sbin:/sbin
case ":$base_path:" in
    *":$fish_bin_dir:"*) ;;
    *) base_path=$fish_bin_dir:$base_path ;;
esac

optional_home=$(mktemp -d "${TMPDIR:-/tmp}/fish-environment-audit.XXXXXX")
trap 'rm -rf -- "$optional_home"' EXIT HUP INT TERM
mkdir "$optional_home/java-fallback"
mkdir "$optional_home/java-override"
env -i \
    HOME="$optional_home" \
    PATH="$base_path" \
    "$fish_bin" --no-config -c '
        source "$argv[2]"
        set --local resolved (__dotfiles_first_existing_directory "$HOME/missing-java" "$argv[3]")
        test "$resolved" = "$argv[3]"
    ' audit-java-fallback \
    "$package_dir/functions/__dotfiles_first_existing_directory.fish" \
    "$optional_home/java-fallback"

env -i \
    HOME="$optional_home" \
    JAVA_HOME="$optional_home/java-override" \
    PATH="$base_path" \
    "$fish_bin" --no-config -c '
        set -gx XDG_CONFIG_HOME "$HOME/.config"
        set -gx XDG_DATA_HOME "$HOME/.local/share"
        set -gx XDG_CACHE_HOME "$HOME/.cache"
        source "$argv[2]"
        source "$argv[3]"
        test (path resolve "$JAVA_HOME") = (path resolve "$HOME/java-override")
    ' audit-java-override \
    "$package_dir/functions/__dotfiles_first_existing_directory.fish" \
    "$package_dir/conf.d/env.fish"

optional_output=$(env -i \
    HOME="$optional_home" \
    PATH="$base_path" \
    TERM=dotfiles-term-test \
    "$fish_bin" --no-config -c '
        function uname
            echo Linux
        end
        set -gx XDG_CONFIG_HOME "$HOME/.config"
        set -gx XDG_DATA_HOME "$HOME/.local/share"
        set -gx XDG_STATE_HOME "$HOME/.local/state"
        set -gx XDG_CACHE_HOME "$HOME/.cache"
        source "$argv[2]"
        source "$argv[3]"
        source "$argv[4]"
        set -q JAVA_HOME; and exit 1
        true
    ' audit-optional-sources \
    "$package_dir/functions/__dotfiles_first_existing_directory.fish" \
    "$package_dir/conf.d/env.fish" \
    "$package_dir/conf.d/uv.env.fish" 2>&1)
if [ -n "$optional_output" ]; then
    echo 'Fish environment audit: optional-source fixture produced output' >&2
    printf '%s\n' "$optional_output" >&2
    exit 1
fi

env -i \
    HOME="$HOME" \
    USER="${USER:-}" \
    LOGNAME="${LOGNAME:-${USER:-}}" \
    PATH="$base_path" \
    TERM=dotfiles-term-test \
    XDG_CONFIG_HOME="$HOME/.config" \
    XDG_DATA_HOME="$HOME/.config/.local/share" \
    XDG_STATE_HOME="$HOME/.config/.local/state" \
    XDG_CACHE_HOME="$HOME/.config/.cache" \
    "$fish_bin" -c '
        function fail
            echo "Fish environment audit: $argv" >&2
            exit 1
        end

        test "$TERM" = dotfiles-term-test; or fail "TERM ownership was overridden"
        test "$XDG_CONFIG_HOME" = "$HOME/.config"; or fail "invalid XDG_CONFIG_HOME"
        test "$XDG_DATA_HOME" = "$HOME/.local/share"; or fail "invalid XDG_DATA_HOME"
        test "$XDG_STATE_HOME" = "$HOME/.local/state"; or fail "invalid XDG_STATE_HOME"
        test "$XDG_CACHE_HOME" = "$HOME/.cache"; or fail "invalid XDG_CACHE_HOME"
        for name in XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME FISH_CONFIG DOT_DIR NVIM_NF PAGER VISUAL EDITOR GNUPGHOME LESSHISTFILE SQLITE_HISTORY WORKON_HOME PYLINTHOME FISH_THEME BAT_CONFIG_PATH fifc_editor LAZYGIT_DIR BUN_INSTALL
            set -qgx $name; or fail "$name is not globally exported"
            set -qU $name; and fail "$name remains universal"
        end
        set -qU JAVA_HOME; and fail "JAVA_HOME remains universal"
        set -qU LS_COLORS; and fail "LS_COLORS remains universal"
        set -qU TERM; and fail "TERM remains universal"
        set -qU fish_user_paths; and fail "fish_user_paths remains universal"

        if set -q JAVA_HOME
            set -qgx JAVA_HOME; or fail "JAVA_HOME is not globally exported"
            test -d "$JAVA_HOME"; or fail "JAVA_HOME does not exist: $JAVA_HOME"
        end

        if command -q vivid; and test -r "$DOT_DIR/vivid/catppuccin-mocha.yml"
            set -qgx LS_COLORS; or fail "LS_COLORS is not globally exported"
            test -n "$LS_COLORS"; or fail "LS_COLORS was not generated"
            string match -q "(vivid generate*" "$LS_COLORS"; and fail "LS_COLORS contains literal command text"
            set --local expected_ls_colors (vivid generate "$DOT_DIR/vivid/catppuccin-mocha.yml")
            test "$LS_COLORS" = "$expected_ls_colors"; or fail "LS_COLORS does not match Vivid output"
        end

        if test (uname) = Darwin
            set -qgx BROWSER; or fail "BROWSER is not globally exported on macOS"
        end

        set --local seen
        for item in $PATH
            contains -- "$item" $seen; and fail "duplicate PATH entry: $item"
            string match -q "*/../*" "$item"; and fail "noncanonical PATH entry: $item"
            test -d "$item"; or fail "nonexistent PATH entry: $item"
            set --append seen "$item"
        end

        contains -- /Applications/Codex.app/Contents/Resources $PATH; and fail "stale Codex PATH entry remains"
        true
    '

git -C "$repo_dir" diff --check -- \
    .working/ACTIVE_GOAL.md \
    .working/UNIFIED_INTAKE.md \
    .working/interviews/fish-environment-correctness/decisions.md \
    fish/conf.d/__init__.fish \
    fish/conf.d/env.fish \
    fish/conf.d/brew.fish \
    fish/conf.d/uv.env.fish \
    fish/functions/__dotfiles_first_existing_directory.fish \
    fish/config.fish \
    fish/fish_variables \
    fish/scripts/audit_environment.sh \
    fish/scripts/verify.sh

echo 'Fish environment audit: PASS'
