source ./pure.zsh

# Announce 256 bit color support
export TERM=xterm-256color

source "$HOME/.cargo/env"

# Disable activating fzf autocompletion via TAB since in some contexts (e.g.
# completing a file name in the current directory) it is overkill. Explicit
# Ctrl-T is our preferred activation mechanism.
# https://github.com/junegunn/fzf/wiki/Configuring-fuzzy-completion#caveats
setopt vi

# FZF
source /home/linuxbrew/.linuxbrew/opt/fzf/shell/completion.zsh
source /home/linuxbrew/.linuxbrew/opt/fzf/shell/key-bindings.zsh

# Aliases
alias vim="nvim"

alias g=git
# Colorize `ls` output using dircolors settings
alias ls="gls --color=auto"
alias l="exa --group-directories-first --long --header --binary --group"
# List only directories and symbolic
# links that point to directories
alias lsd='ls -ld *(-/DN)'
alias la="l -a"
alias lh='ls -a | egrep "^\."'
alias h=history
alias hg="history | grep "

# -------------------------------------------------------------------
# make some commands (potentially) less destructive
# -------------------------------------------------------------------
alias 'rm=rm -i'

# Colorize `man` output.
#
# We define this here so that these environment variables only need to be
# defined for when they are used, and don't colorize everything when we run
# `env` on its own.
man() {
env \
    LESS_TERMCAP_mb=$'\E[05;31m'        \
    LESS_TERMCAP_md=$'\E[01;38;5;64m'   \
    LESS_TERMCAP_me=$'\E[0m'            \
    LESS_TERMCAP_mr=$'\E[01;38;5;199m'  \
    LESS_TERMCAP_so=$'\E[38;5;208m'     \
    LESS_TERMCAP_se=$'\E[0m'            \
    LESS_TERMCAP_us=$'\E[04;38;5;33m'   \
    LESS_TERMCAP_ue=$'\E[0m'            \
    command man "$@"
}


# Customize appearance
zstyle ':completion:*:descriptions' format '%U%B%d%b%u'
zstyle ':completion:*:warnings' format '%BSorry, no matches for: %d%b'
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2 eval "$(gdircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false # Disable old completion system

# Pure prompt
autoload -U promptinit; promptinit
prompt pure

# Highlight like Fishshell
echo "source ${(q-)PWD}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ${ZDOTDIR:-$HOME}/.zshrc

