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

export ZDOTDIR="$DOTFILES_DIR/zsh"

export ZDOTDIR_HELPERS="$ZDOTDIR/helpers"

export TERM_ITALICS="TRUE"

export COLORTERM=${COLORTERM:=truecolor}

ZSH_CACHE_DIR="$XDG_CACHE_HOME/zsh"

if [ ! -d "$ZSH_CACHE_DIR" ]; then
    mkdir -p "$ZSH_CACHE_DIR"
fi

# for linux
# export LS_COLORS="di=32:ln=35:so=01;35:pi=01;33:ex=01;31:bd=01;33:cd=01;33:su=37;41:sg=37;43:tw=00;42:ow=01;34;42:"

case `uname` in
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

. "$HOME/.cargo/env"

if type nvim > /dev/null 2>&1; then
    export EDITOR="nvim"
    export VISUAL="nvim"
else
    export EDITOR=vim
    export VISUAL=vim
fi

#  INFO: 2023-09-26 - This is my history config
source ~/.dotfiles/zsh/history.zsh

# Bat a modern cat with all the goodies
export BAT_CONFIG_PATH=$HOME/.dotfiles/bat/lib/login/bat.conf

export FZF_COMPLETION_DIR_COMMANDS="cd pushd rmdir tree nvim vim"

source "$ZDOTDIR/plugins/fzf_functions.zsh"

export NVIM_DIR="$XDG_CONFIG_HOME/nvim"

# Amadeus related
export PATH=/workspace/projects/mpt/puz:$PATH
source /workspace/projects/otf/.env
