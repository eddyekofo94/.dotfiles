# Initialize XDG base directory environment variables as defined in:
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-0.6.html.
#
# Explicitly define them here so we don't need to add the additional code of
# handling the case where they are not explicitly defined, simplifying the code
# in the rest of our configurations which use XDG.

# Directory where user-specific configuration files should be stored.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Directory where user-specific data files should be stored.
export XDG_DATA_HOME="${XDG_DATA_HOME:-$XDG_CONFIG_HOME/.local/share}"

# Preference-ordered set of base directories to search for data files in
# addition to the $XDG_DATA_HOME base directory.
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share/:/usr/share/}"

# Preference-ordered set of base directories to search for configuration files
# in addition to the $XDG_CONFIG_HOME base directory.
export XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"

# Directory where user-specific non-essential data files should be stored.
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$XDG_CONFIG_HOME/.cache}"

# Editor vars
export TERM="${TERM:-xterm-256color}"

export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

export ZSH_DOT_DIR="${ZSH_DOT_DIR:-$DOTFILES_DIR/zsh}"

export ZSH_DOT_DIR_HELPERS="${ZSH_DOT_DIR_HELPERS:-$ZSH_DOT_DIR/helpers}"

export ZSH_DOT_DIR_ENVS="${ZSH_DOT_DIR_ENVS:-$ZSH_DOT_DIR/envs}"
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

export ZSHRC="${ZSHRC:-$HOME/.zshrc}"

export TERM_ITALICS="${TERM_ITALICS:-TRUE}"

export COLORTERM="${COLORTERM:-truecolor}"

ZSH_CACHE_DIR="$XDG_CACHE_HOME/zsh"

if [[ ! -d "$ZSH_CACHE_DIR" ]]; then
    mkdir -p "$ZSH_CACHE_DIR" 2>/dev/null || true
fi

if ! command -v brew >/dev/null 2>&1; then
    for brew_path in \
        /opt/homebrew/bin/brew \
        /usr/local/bin/brew \
        /home/linuxbrew/.linuxbrew/bin/brew; do
        if [[ -x "$brew_path" ]]; then
            if brew_environment=$("$brew_path" shellenv 2>/dev/null); then
                eval "$brew_environment"
                break
            fi
        fi
    done
    unset brew_environment brew_path
fi

if [[ -z "${EDITOR:-}" ]]; then
    if command -v nvim >/dev/null 2>&1; then
        export EDITOR=nvim
    else
        export EDITOR=vim
    fi
fi
export VISUAL="${VISUAL:-$EDITOR}"
[[ "$EDITOR" != nvim ]] || export NVIM_DIR="${NVIM_DIR:-$XDG_CONFIG_HOME/nvim}"

# -- lang
# export LANG="en_US.UTF-8"

# reduce ESC key delay to 0.1
export KEYTIMEOUT=1

# Main change, you can see directories on a dark background
export CLICOLOR=1

# autosuggest
# export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#465258,bold,underline"
export ZSH_AUTOSUGGEST_USE_ASYNC=1

# Bat a modern cat with all the goodies
export BAT_CONFIG_PATH="${BAT_CONFIG_PATH:-$DOTFILES_DIR/bat/bat.conf}"

# export PATH=$HOME/.dotfiles/doit/build:$PATH

# Optional machine-local overrides. Never create this file automatically.
[[ -r "$HOME/.local.env" ]] && source "$HOME/.local.env"
