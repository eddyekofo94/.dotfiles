# INFO: This is a working progress
# You can set that the files are in the .dotfiles dir
# this will remove the need to symlink them
# $ZDOTDIR/.zshenv #  Should only contain user’s environment variables.
# $ZDOTDIR/.zprofile # Can be used to execute commands just after logging in.
# $ZDOTDIR/.zshrc # Should be used for the shell configuration and for executing commands.
# $ZDOTDIR/.zlogin # Same purpose than .zprofile, but read just after .zshrc
# $ZDOTDIR/.zlogout # Can be used to execute commands when a shell exit.

source ~/.dotfiles/zsh/history.zsh

setopt auto_cd       # cd by typing directory name if it's not a command
setopt correct_all   # autocorrect commands
setopt auto_list     # automatically list choices on ambiguous completion
setopt auto_menu     # automatically use menu completion
setopt always_to_end # move cursor to end if word had one match
setopt no_beep                # silence all bells and beeps
setopt prompt_subst           # allow expansion in prompts
setopt NOCLOBBER # Don’t write over existing files with >, use >! instead

# start a prompt called starship
eval "$(starship init zsh)"

# Zoxide
eval "$(zoxide init zsh)"

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
source $(brew --prefix)/opt/fzf/shell/completion.zsh
source $(brew --prefix)/opt/fzf/shell/key-bindings.zsh


source ~/.config/zsh/znap/znap.zsh # Start Znap
# `znap prompt` makes your prompt visible in just 15-40ms!
# znap prompt sindresorhus/pure

znap source zsh-users/zsh-syntax-highlighting

znap source hlissner/zsh-autopair
autopair-init

znap source zsh-users/zsh-autosuggestions

# znap source bigH/git-fuzzy
znap clone https://github.com/bigH/git-fuzzy.git


function zvm_config() {
  # Start in insert mode
  ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT
  # Only changing the escape key to `jj` in insert mode, we still
  # keep using the default keybindings `^[` in other modes
  ZVM_VI_INSERT_ESCAPE_BINDKEY=jj
  # The plugin will auto execute this zvm_after_init function
}

function zvm_after_init() {
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
}

znap source "jeffreytse/zsh-vi-mode"

# add the executable to your path
export PATH="~/.config/zsh/bigH/git-fuzzy/bin:$PATH"

alias cat='bat --paging=never --style=changes'

source ~/.dotfiles/zsh/aliases.zsh

# Colorize `man` output.
#
# We define this here so that these environment variables only need to be
# defined for when they are used, and don't colorize everything when we run
# `env` on its own.
man() {
    env \
        LESS_TERMCAP_mb=$'\E[05;31m' \
        LESS_TERMCAP_md=$'\E[01;38;5;64m' \
        LESS_TERMCAP_me=$'\E[0m' \
        LESS_TERMCAP_mr=$'\E[01;38;5;199m' \
        LESS_TERMCAP_so=$'\E[38;5;208m' \
        LESS_TERMCAP_se=$'\E[0m' \
        LESS_TERMCAP_us=$'\E[04;38;5;33m' \
        LESS_TERMCAP_ue=$'\E[0m' \
        command man "$@"
}

# brew install pure
fpath+=("$(brew --prefix)/share/zsh/site-functions")


# brew install zsh-vi-mode
# source $(brew --prefix)/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh

source ~/.dotfiles/zsh/plugins/colorize.plugin.zsh
# source /home/linuxbrew/.linuxbrew/share/zsh-abbr/zsh-abbr.zsh

# ABBRs
#  WARN: 2023-09-24 - Keep this here because it doesn't work elsewhere
#  DO NOT REMOVE from here
znap source olets/zsh-abbr

# My personalised abbreviations
source ~/.dotfiles/zsh/abbr.zsh
# Trying this one out
# autoload -Uz compinit
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

compinit
_comp_options+=(globdots)

# INFO: https://thevaluable.dev/zsh-completion-guide-examples/
zstyle ':completion:*' menu select
zstyle ':completion:*:*:*:*:descriptions' format '%F{green}-- %d --%f'
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' complete-options true
zstyle ':completion:*' file-sort change
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

zmodload zsh/complist
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect 'l' vi-forward-char

# NOTE: Alt+. fix: https://unix.stackexchange.com/a/696981/305857
bindkey -M viins '\e.' insert-last-word

# CTRL+x i to switch to the interactive mode in the completion menu
# bindkey -M menuselect '^xi' vi-insert
