# Initialize XDG base directory environment variables as defined in:
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-0.6.html.
#
# Explicitly define them here so we don't need to add the additional code of
# handling the case where they are not explicitly defined, simplifying the code
# in the rest of our configurations which use XDG.

# Directory where user-specific configuration files should be stored.
export XDG_CONFIG_HOME="$HOME/.config"

# Directory where user-specific data files should be stored.
export XDG_DATA_HOME="$XDG_CONFIG_HOME/.local/share"

# Preference-ordered set of base directories to search for data files in
# addition to the $XDG_DATA_HOME base directory.
export XDG_DATA_DIRS="/usr/local/share/:/usr/share/"

# Preference-ordered set of base directories to search for configuration files
# in addition to the $XDG_CONFIG_HOME base directory.
export XDG_CONFIG_DIRS="/etc/xdg"

# Directory where user-specific non-essential data files should be stored.
export XDG_CACHE_HOME="$XDG_CONFIG_HOME/.cache"

# Editor vars
export TERM="xterm-256color"

export DOTFILES_DIR="$HOME/.dotfiles"

export ZSH_DOT_DIR="$DOTFILES_DIR/zsh"

export ZSH_DOT_DIR_HELPERS="$ZSH_DOT_DIR/helpers"

# export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export ZDOTDIR=~/.config/zsh

export ZSHRC=$DOTFILES_DIR/zsh/.zshrc

export TERM_ITALICS="TRUE"

export COLORTERM=${COLORTERM:=truecolor}

ZSH_CACHE_DIR="$XDG_CACHE_HOME/zsh"

if [ ! -d "$ZSH_CACHE_DIR" ]; then
    mkdir -p "$ZSH_CACHE_DIR"
fi

case $(uname) in
    Darwin)
        # -- intel mac:
        [ -f "/usr/local/bin/brew" ] && eval "$(/usr/local/bin/brew shellenv)"
        # -- M1 mac:
        [ -f "/opt/homebrew/bin/brew" ] && eval "$(/opt/homebrew/bin/brew shellenv)"
        ;;
    Linux)
        [ -d "/home/linuxbrew/.linuxbrew" ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        ;;
esac

if type nvim > /dev/null 2>&1; then
    export EDITOR="nvim"
    export VISUAL="nvim"
    export NVIM_DIR="$XDG_CONFIG_HOME/nvim"
else
    export EDITOR=vim
    export VISUAL=vim
fi

# -- lang
# export LANG="en_US.UTF-8"

TERM=wezterm

# reduce ESC key delay to 0.1
export KEYTIMEOUT=1

# Main change, you can see directories on a dark background
export CLICOLOR=1

export ZSH_DOT_DIR_ENVS="$ZSH_DOT_DIR/envs"

# autosuggest
# export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#465258,bold,underline"
export ZSH_AUTOSUGGEST_USE_ASYNC=1

#  INFO: 2023-09-26 - This is my history config
source ~/.dotfiles/zsh/history.zsh

# Bat a modern cat with all the goodies
export BAT_CONFIG_PATH=$HOME/.dotfiles/bat/bat.conf

# export PATH=$HOME/.dotfiles/doit/build:$PATH

# Amadeus related
export PATH=/workspace/projects/mpt/puz:$PATH
# source /workspace/projects/otf/.env
