#!/bin/sh
set -eu

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

startup_files="$(find "$package_dir/conf.d" -type f -name '*.fish' -print)
$package_dir/config.fish
$package_dir/functions/fish_user_key_bindings.fish"

if printf '%s\n' "$startup_files" | xargs rg -n \
    '^[[:space:]]*((command[[:space:]]+)?mkdir[[:space:]]+-p|(command[[:space:]]+)?ln[[:space:]]+-s|(command[[:space:]]+)?find .* -delete|fisher (install|update)|git config --global|eval .*brew shellenv|/[^[:space:]]*brew shellenv|fzf --fish|zoxide init|starship init|set .*vivid generate|set .*/usr/libexec/java_home)'; then
    echo 'Fish startup ownership audit: maintenance or generation found in startup' >&2
    exit 1
fi

fish --no-config -c '
    set -e HOMEBREW_PREFIX
    source "$argv[2]"
    not set -q HOMEBREW_PREFIX
' audit-missing-brew-cache "$package_dir/conf.d/brew.fish"

if rg -n 'set[[:space:]]+-[[:alpha:]]*(gx|xg)[[:alpha:]]*[[:space:]]+get_(current|default)_branch' \
    "$package_dir/conf.d/git.fish"; then
    echo 'Fish startup ownership audit: eager Git query found' >&2
    exit 1
fi
rg -q '^function get_current_branch ' "$package_dir/conf.d/git.fish"
rg -q '^function get_default_branch ' "$package_dir/functions/git/get_default_branch.fish"
if rg -n '\$get_(current|default)_branch|\$\(get_(current|default)_branch\)' \
    "$package_dir/conf.d/git.fish"; then
    echo 'Fish startup ownership audit: stale eager Git variable reference found' >&2
    exit 1
fi

theme_file="$package_dir/conf.d/theme.fish"
# Match the assignment with or without scope flags so ownership keeps being
# detected when the flags change.
theme_pattern='^[[:space:]]*set[[:space:]]+(-[[:alnum:]]+[[:space:]]+)*fish_(color|pager_color)_'
theme_owners=$(rg -l "$theme_pattern" \
    "$package_dir/conf.d" "$package_dir/config.fish")
if [ "$theme_owners" != "$theme_file" ]; then
    echo 'Fish startup ownership audit: theme ownership is not singular' >&2
    printf '%s\n' "$theme_owners" >&2
    exit 1
fi

# Separate processes read the theme from the environment rather than from Fish's
# variable table: fish_indent --ansi renders the Ctrl-R history preview and goes
# monochrome when these are merely global.
unexported_theme=$(rg -n "$theme_pattern" "$theme_file" | rg -v '^[0-9]+:set -gx ' || true)
if [ -n "$unexported_theme" ]; then
    echo 'Fish startup ownership audit: theme colors must be exported with set -gx' >&2
    printf '%s\n' "$unexported_theme" >&2
    exit 1
fi

binding_owners=$(rg -l 'fzf_configure_bindings' \
    "$package_dir/conf.d" "$package_dir/config.fish" "$package_dir/functions/fish_user_key_bindings.fish")
if [ "$binding_owners" != "$package_dir/functions/fish_user_key_bindings.fish" ]; then
    echo 'Fish startup ownership audit: FZF binding ownership is not singular' >&2
    printf '%s\n' "$binding_owners" >&2
    exit 1
fi

echo 'Fish startup ownership audit: PASS'
