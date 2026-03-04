#
# __init__: Anything that needs to be first.
#

# Set XDG basedirs.
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
set -q XDG_CONFIG_HOME; or set -Ux XDG_CONFIG_HOME $HOME/.config
set -q XDG_DATA_HOME; or set -Ux XDG_DATA_HOME $HOME/.local/share
set -q XDG_STATE_HOME; or set -Ux XDG_STATE_HOME $HOME/.local/state
set -q XDG_CACHE_HOME; or set -Ux XDG_CACHE_HOME $HOME/.cache
for xdgdir in (path filter -vd $XDG_CONFIG_HOME $XDG_DATA_HOME $XDG_STATE_HOME $XDG_CACHE_HOME)
    mkdir -p $xdgdir
end

# set fish config variable
set -q FISH_CONFIG; or set -Ux FISH_CONFIG $XDG_CONFIG_HOME/fish

# Ensure manpath is set to something so we can add to it.
set -q MANPATH || set -gx MANPATH ''

# Add more man page paths.
for manpath in (path filter $__fish_data_dir/man /usr/local/share/man /usr/share/man)
    set -a MANPATH $manpath
end

# Allow subdirs for functions and completions.
set fish_function_path (path resolve $__fish_config_dir/functions/*/) $fish_function_path
set fish_complete_path (path resolve $__fish_config_dir/completions/*/) $fish_complete_path

# Setup caching.
if not set -q __fish_cache_dir
    if set -q XDG_CACHE_HOME
        set -U __fish_cache_dir $XDG_CACHE_HOME/fish
    else
        set -U __fish_cache_dir $HOME/.cache/fish
    end
end
test -d $__fish_cache_dir; or mkdir -p $__fish_cache_dir

# Remove expired cache files.
find $__fish_cache_dir -name '*.fish' -type f -mmin +1200 -delete 2>/dev/null

# Setup homebrew.
if not test -s $__fish_cache_dir/brew_init.fish
    if test -e /opt/homebrew/bin/brew
        /opt/homebrew/bin/brew shellenv >$__fish_cache_dir/brew_init.fish
    else if test -e /usr/local/bin/brew
        /usr/local/bin/brew shellenv >$__fish_cache_dir/brew_init.fish
    end
    source $__fish_cache_dir/brew_init.fish
end

set -q LAZYGIT_DIR; or set -Ux LAZYGIT_DIR "$HOME/.config/lazygit"
if test -d "$LAZYGIT_DIR"
    if not test -f ~/.config/lazygit/config.yml
        echo "setting up personal lazygit..."
        ln -s ~/.dotfiles/lazygit/config.yml ~/.config/lazygit/config.yml
    end
end

if not test -f $XDG_CONFIG_HOME/starship.toml
    ln -s ~/.dotfiles/starship/starship.toml ~/.config/starship.toml
end

if not test -d $XDG_CONFIG_HOME/zellij
    ln -s ~/.dotfiles/zellij ~/.config/zellij
end

source $FISH_CONFIG/conf.d/_fzf_envs.fish
# source $FISH_CONFIG/user_variables.fish

# Fisher
init_fisher

# Add bin directories to path.
fish_add_path --prepend (path filter $HOME/bin $HOME/.local/bin)
