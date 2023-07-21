# Announce 256 bit color support
export TERM=xterm-256color

source "$HOME/.cargo/env"

# Disable activating fzf autocompletion via TAB since in some contexts (e.g.
# completing a file name in the current directory) it is overkill. Explicit
# Ctrl-T is our preferred activation mechanism.
# https://github.com/junegunn/fzf/wiki/Configuring-fuzzy-completion#caveats
setopt vi 

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
source /home/linuxbrew/.linuxbrew/opt/fzf/shell/completion.zsh
source /home/linuxbrew/.linuxbrew/opt/fzf/shell/key-bindings.zsh

 # LS colors using Vivid installed using Cargo
export LS_COLORS="$(vivid generate $HOME/.dotfiles/vivid/catppuccin-mocha.yml)"

# FZF
export FZF_DEFAULT_COMMAND='rg --files --no-ignore-vcs --no-require-git --no-ignore --hidden --follow --glob "!.git/*"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
# Download Znap, if it's not there yet.
[[ -r ~/.dotfiles/znap/znap.zsh ]] ||
    git clone --depth 1 -- \
        https://github.com/marlonrichert/zsh-snap.git ~/.dotfiles/znap
source ~/.dotfiles/znap/znap.zsh  # Start Znap

# Aliases
# alias vim="nvim"

# alias g=git
# alias lg="lazygit"
# Colorize `ls` output using dircolors settings
alias l="exa --group-directories-first --long --header --binary --group"
# List only directories and symbolic
# links that point to directories
alias lsd='ls -ld *(-/DN)'
alias la="l -a"
alias ll="l -al"
alias lh='ls -a | egrep "^\."'
# alias hg="history | grep "

# Installation: brew install olets/tap/zsh-abbr
source /home/linuxbrew/.linuxbrew/share/zsh-abbr/zsh-abbr.zsh

# Abbrevations
# abbr hg="history | grep "
# abbr h=history
# abbr lg=lazygit
# abbr lzd=lazydocker
# abbr vim=nvim
# abbr vi=vim
source ~/.dotfiles/zsh/abbr.zsh

# -------------------------------------------------------------------
# make some commands (potentially) less destructive
# -------------------------------------------------------------------
alias rm='rm -i'

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
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false # Disable old completion system

# brew install pure
fpath+=("$(brew --prefix)/share/zsh/site-functions")

# Pure prompt
autoload -U promptinit; promptinit
prompt pure 

# Highlight like Fishshell
# echo "source ${(q-)PWD}/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ${ZDOTDIR:-$HOME}/.zshrc
source ~/.dotfiles/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Zoxide
eval "$(zoxide init zsh)"

# vivid
export LS_COLORS="$(vivid generate $HOME/.dotfiles/vivid/catppuccin-mocha.yml)"

# Installation: brew install zsp-autopair
source /home/linuxbrew/.linuxbrew/share/zsh-autopair/autopair.zsh

# brew install zsh-vi-mode
# source $(brew --prefix)/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
