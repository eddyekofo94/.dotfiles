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
alias ls='exa $exa_params'
alias ll='exa --all --header --long $exa_params'
alias llm='exa --all --header --long --sort=modified $exa_params'
alias la='exa -lbhHigUmuSa'
alias lx='exa -lbhHigUmuSa@'
alias lt='exa --tree $exa_params'
alias tree='exa --tree $exa_params'
# List only directories and symbolic
# links that point to directories
alias lsd='ls -ld *(-/DN)'
alias lh='ls -a | egrep "^\."'
# alias hg="history | grep "
alias cat='bat --paging=never --style=changes'

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

# Catpuccin FZF colours
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

# Bat a modern cat with all the goodies
export BAT_CONFIG_PATH=$HOME/.dotfiles/bat/lib/login/bat.conf

# brew install zsh-vi-mode
# source $(brew --prefix)/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh

# Auto sugestions 
# source ~/.dotfiles/zsh/plugins/colorize.plugin.zsh
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
