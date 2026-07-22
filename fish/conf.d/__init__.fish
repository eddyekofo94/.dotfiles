#
# __init__: Anything that needs to be first.
#

# Set deterministic Fish XDG basedirs. Zsh currently exports legacy
# $XDG_CONFIG_HOME/.local and $XDG_CONFIG_HOME/.cache paths; Fish intentionally
# corrects those inherited values here.
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
set -gx XDG_CONFIG_HOME $HOME/.config
set -gx XDG_DATA_HOME $HOME/.local/share
set -gx XDG_STATE_HOME $HOME/.local/state
set -gx XDG_CACHE_HOME $HOME/.cache

# set fish config variable
set -gx FISH_CONFIG $__fish_config_dir
set -g DOTFILES_FISH_CACHE $XDG_CACHE_HOME/fish

# Ensure manpath is set to something so we can add to it.
set -q MANPATH || set -gx MANPATH ''

# Add more man page paths.
for manpath in (path filter $__fish_data_dir/man /usr/local/share/man /usr/share/man)
    set -a MANPATH $manpath
end

# Allow subdirs for functions and completions.
set fish_function_path (path resolve $__fish_config_dir/functions/*/) $fish_function_path
set fish_complete_path (path resolve $__fish_config_dir/completions/*/) $fish_complete_path

# Consume caches prepared by fish/scripts/refresh_startup.fish. A missing cache
# must never turn shell startup into an installer or maintenance pass.
if test -r $DOTFILES_FISH_CACHE/brew_init.fish
    source $DOTFILES_FISH_CACHE/brew_init.fish
end

# source $FISH_CONFIG/user_variables.fish

# Activate already-installed Fisher plugins without installing or updating.
init_fisher

# Add bin directories to path.
fish_add_path --global --prepend (path filter -d $HOME/bin $HOME/.local/bin)
