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

# for linux
# export LS_COLORS="di=32:ln=35:so=01;35:pi=01;33:ex=01;31:bd=01;33:cd=01;33:su=37;41:sg=37;43:tw=00;42:ow=01;34;42:"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

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

# LS colors using Vivid installed using Cargo
export LS_COLORS="$(vivid generate $HOME/.dotfiles/vivid/catppuccin-mocha.yml)"

# FZF
export FZF_DEFAULT_COMMAND='rg --files --no-ignore-vcs --no-require-git --no-ignore --hidden --follow --glob "!.git/*"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# INFO: uselfull link for the layout etc.....
# https://thevaluable.dev/practical-guide-fzf-example/
export FZF_DEFAULT_OPTS=" \
  --height=70% --border --margin=1 --padding=1 \
  --layout=reverse \
  --border sharp\
  --pointer ▶ \
  --marker ⇒ \
  --prompt '∷ ' \
  --info=hidden \
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
  --color=border:#6c7086 \
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
  --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

export FZF_CTRL_T_OPTS="--height 60% \
--border sharp \
--layout reverse \
--prompt '∷ ' \
--pointer ▶ \
--marker ⇒"

export FZF_COMPLETION_DIR_COMMANDS="cd pushd rmdir tree nvim vim"

source "$ZDOTDIR/plugins/fzf_functions.zsh"

export NVIM_DIR="$XDG_CONFIG_HOME/nvim"

# Amadeus related
export PATH=/workspace/projects/mpt/puz:$PATH
source /workspace/projects/otf/.env
