source ~/.dotfiles/zsh/history.zsh

# export local variable
source /workspace/projects/otf/.env

# Disable activating fzf autocompletion via TAB since in some contexts (e.g.
# completing a file name in the current directory) it is overkill. Explicit
# Ctrl-T is our preferred activation mechanism.
# https://github.com/junegunn/fzf/wiki/Configuring-fuzzy-completion#caveats
setopt vi

setopt auto_cd # cd by typing directory name if it's not a command
setopt correct_all # autocorrect commands
setopt auto_list # automatically list choices on ambiguous completion
setopt auto_menu # automatically use menu completion
setopt always_to_end # move cursor to end if word had one match
setopt no_beep                # silence all bells and beeps
setopt prompt_subst           # allow expansion in prompts

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
# source /home/linuxbrew/.linuxbrew/opt/fzf/shell/completion.zsh
source /home/linuxbrew/.linuxbrew/opt/fzf/shell/key-bindings.zsh


# Options to fzf command
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
    --prompt='$> ' \
    --pointer='→' \
    --info=hidden \
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
    --color=border:#6c7086 \
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
    --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

# Download Znap, if it's not there yet.
[[ -r ~/.dotfiles/zsh/znap/znap.zsh ]] ||
    git clone --depth 1 -- \
        https://github.com/marlonrichert/zsh-snap.git ~/.dotfiles/zsh/znap
source ~/.dotfiles/zsh/znap/znap.zsh  # Start Znap

# `znap prompt` makes your prompt visible in just 15-40ms!
znap prompt sindresorhus/pure

znap source zsh-users/zsh-syntax-highlighting

znap source zsh-users/zsh-autosuggestions

znap source olets/zsh-abbr

# ABBRs
# My personalised abbreviations
# source ~/.dotfiles/zsh/abbr.zsh

# alias g=git
# alias lg="lazygit"
# Colorize `ls` output using dircolors settings
# alias l="exa --group-directories-first --long --icons --header --binary --group"
# alias ls='exa $exa_params --icons'
# alias ll='exa --all --header --icons --long $exa_params'
# alias llm='exa --all --header --icons --long --sort=modified $exa_params'
# alias la='exa -lbhHigUmuSa --icons'
# alias lx='exa -lbhHigUmuSa@ --icons'
# alias lt='exa --tree $exa_params --icons'
# alias tree='exa --tree $exa_params --icons'
# # List only directories and symbolic
# # links that point to directories
# alias lsd='ls -ld *(-/DN)'
# alias lh='ls -a | egrep "^\."'
# alias hg="history | grep "

# alias cat='bat --paging=never --style=changes'

source ~/.dotfiles/zsh/aliases.zsh
# alias ls='exa $exa_params --icons'
# alias ll='exa --all --header --icons --long $exa_params'
# alias llm='exa --all --header --icons --long --sort=modified $exa_params'
# alias lt='exa --tree $exa_params --icons'

# -------------------------------------------------------------------
# make some commands (potentially) less destructive
# -------------------------------------------------------------------
# Play safe!
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

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

# Don’t write over existing files with >, use >! instead
setopt NOCLOBBER

# Zoxide
eval "$(zoxide init zsh)"

# vivid
export LS_COLORS="$(vivid generate $HOME/.dotfiles/vivid/catppuccin-mocha.yml)"

# Installation: brew install zsp-autopair
source /home/linuxbrew/.linuxbrew/share/zsh-autopair/autopair.zsh

# Bat a modern cat with all the goodies
export BAT_CONFIG_PATH=$HOME/.dotfiles/bat/lib/login/bat.conf

# brew install zsh-vi-mode
# source $(brew --prefix)/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh

# source ~/.dotfiles/zsh/plugins/colorize.plugin.zsh

# Trying this one out
autoload -Uz compinit
compinit
_comp_options+=(globdots)

# if type brew &>/dev/null; then
#     FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
#
#     autoload -Uz compinit
#     compinit
# fi

# Zellij
# INFO: figure out about how to change ctrl+s before changing this back.
# ZELLIJ_CONFIG_DIR=$HOME/.dotfiles/zellij
# eval "$(zellij setup --generate-auto-start zsh)"
