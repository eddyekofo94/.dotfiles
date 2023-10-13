# INFO: This is a working progress
# You can set that the files are in the .dotfiles dir
# this will remove the need to symlink them
# $ZDOTDIR/.zshenv #  Should only contain user’s environment variables.
# $ZDOTDIR/.zprofile # Can be used to execute commands just after logging in.
# $ZDOTDIR/.zshrc # Should be used for the shell configuration and for executing commands.
# $ZDOTDIR/.zlogin # Same purpose than .zprofile, but read just after .zshrc
# $ZDOTDIR/.zlogout # Can be used to execute commands when a shell exit.

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
    [[ -r "$file" && -f "$file" ]] && source "$file"
done
# unset file

# Zoxide
if has zoxide; then
    eval "$(zoxide init zsh)"
fi

export ZPWR_EXPAND_BLACKLIST=(cat ll la l g z gss)

# spelling correction in zsh-expand plugin
export ZPWR_CORRECT=false

source ~/.config/zsh/znap/znap.zsh # Start Znap

#  NOTE: 2023-10-03 - use bd to change dir backwards
znap source Tarrasch/zsh-bd


# znap source bigH/git-fuzzy
znap clone https://github.com/bigH/git-fuzzy.git

# add the executable to your path
export PATH="$XDG_CONFIG_HOME/zsh/bigH/git-fuzzy/bin:$PATH"

#  REF: 2023-09-28 - https://github.com/zsh-users/zsh-history-substring-search
znap source zsh-users/zsh-history-substring-search

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
    fpath+=("$(brew --prefix)/share/zsh/site-functions")
    znap source hlissner/zsh-autopair
    autopair-init

    # start a prompt called starship
    if has starship; then
        eval "$(starship init zsh)"
    fi

    # ZNAP source all the plugins
    znap source zdharma-continuum/fast-syntax-highlighting
    #  INFO: 2023-09-26 - This expands aliases, use this instead of abbr
    znap source MenkeTechnologies/zsh-expand
}
znap source zsh-users/zsh-autosuggestions

znap source "jeffreytse/zsh-vi-mode"

if has bat; then
    alias cat='bat --paging=never --style=changes'
fi

