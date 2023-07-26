. "$HOME/.cargo/env"

# XDG Base Directory Specification
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export XDG_CACHE_HOME=$HOME/.cache

# Editor vars
export TERM="xterm-256color"

# for linux
# export LS_COLORS="di=32:ln=35:so=01;35:pi=01;33:ex=01;31:bd=01;33:cd=01;33:su=37;41:sg=37;43:tw=00;42:ow=01;34;42:"

if type nvim > /dev/null 2>&1; then
  export EDITOR=nvim
else
  export EDITOR=vim
fi

# Amadeus related
export PATH=/workspace/projects/mpt/puz:$PATH
