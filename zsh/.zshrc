# INFO: This is a working progress
# You can set that the files are in the .dotfiles dir
# this will remove the need to symlink them
# $ZDOTDIR/.zshenv #  Should only contain user’s environment variables.
# $ZDOTDIR/.zprofile # Can be used to execute commands just after logging in.
# $ZDOTDIR/.zshrc # Should be used for the shell configuration and for executing commands.
# $ZDOTDIR/.zlogin # Same purpose than .zprofile, but read just after .zshrc
# $ZDOTDIR/.zlogout # Can be used to execute commands when a shell exit.

# Trying this one out
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line
setopt auto_cd       # cd by typing directory name if it's not a command
setopt correct_all   # autocorrect commands
setopt auto_list     # automatically list choices on ambiguous completion
setopt auto_menu     # automatically use menu completion
setopt always_to_end # move cursor to end if word had one match
setopt no_beep                # silence all bells and beeps
setopt prompt_subst           # allow expansion in prompts
setopt NOCLOBBER # Don’t write over existing files with >, use >! instead

#  NOTE: 2023-09-29 - Need this exported early because of the
# helper functions used
export ZDOTDIR_HELPERS="$ZDOTDIR/helpers"
for file in $ZDOTDIR_HELPERS/*; do
    # source "$file";
    [[ -r "$file" && -f "$file" ]] && source "$file"
done

# start a prompt called starship
if has starship; then
    eval "$(starship init zsh)"
fi

# Zoxide
if has zoxide; then
    eval "$(zoxide init zsh)"
fi

export ZPWR_EXPAND_BLACKLIST=(g z gss)

source ~/.config/zsh/znap/znap.zsh # Start Znap

znap source wintermi/zsh-brew

znap source zdharma-continuum/fast-syntax-highlighting

znap source Tarrasch/zsh-bd

znap source hlissner/zsh-autopair
autopair-init

znap source zsh-users/zsh-autosuggestions

#  REF: 2023-09-28 - https://github.com/zsh-users/zsh-history-substring-search
znap source zsh-users/zsh-history-substring-search

# znap source bigH/git-fuzzy
znap clone https://github.com/bigH/git-fuzzy.git

#  INFO: 2023-09-26 - This expands aliases, use this instead of abbr
znap source MenkeTechnologies/zsh-expand

function zvm_config() {
    # Start in insert mode
    ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT
    # Only changing the escape key to `jj` in insert mode, we still
    # keep using the default keybindings `^[` in other modes
    ZVM_VI_INSERT_ESCAPE_BINDKEY=jj
    # The plugin will auto execute this zvm_after_init function
}

function zvm_after_init() {
    # NOTE:  FZF has to be here for it to be instanstiated
    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
    source $(brew --prefix)/opt/fzf/shell/completion.zsh
    source $(brew --prefix)/opt/fzf/shell/key-bindings.zsh
}

znap source "jeffreytse/zsh-vi-mode"

# add the executable to your path
export PATH="~/.config/zsh/bigH/git-fuzzy/bin:$PATH"

alias cat='bat --paging=never --style=changes'


# source $ZDOTDIR_HELPERS/aliases.zsh

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

source ~/.dotfiles/zsh/plugins/colorize.plugin.zsh

# How to set the fast-theme
# fast-theme XDG:catppuccin-mocha

compinit
_comp_options+=(globdots)

