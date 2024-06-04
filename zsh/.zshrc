# INFO: This is a working progress
# You can set that the files are in the .dotfiles dir
# this will remove the need to symlink them
# $ZDOTDIR/.zshenv #  Should only contain user’s environment variables.
# $ZDOTDIR/.zprofile # Can be used to execute commands just after logging in.
# $ZDOTDIR/.zshrc # Should be used for the shell configuration and for executing commands.
# $ZDOTDIR/.zlogin # Same purpose than .zprofile, but read just after .zshrc
# $ZDOTDIR/.zlogout # Can be used to execute commands when a shell exit.

has() {
    type "$1" &>/dev/null
}

if has zellij; then
    eval "$(zellij setup --generate-auto-start zsh)"
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.dotfiles/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Download Znap, if it's not there yet.
[[ -r ~/.config/zsh/znap/znap.zsh ]] ||
git clone --depth 1 -- \
    https://github.com/marlonrichert/zsh-snap.git ~/.config/zsh/znap

source ~/.config/zsh/znap/znap.zsh # Start Znap

#  NOTE: 2023-09-29 - Need this exported early because of the
# helper functions used
export ZDOTDIR_HELPERS="$ZDOTDIR/helpers"
for file in $ZDOTDIR_HELPERS/*.zsh; do
    [[ -r "$file" && -f "$file" ]] && source "$file"
done
# unset file

# NOTE: Alt+. fix: https://unix.stackexchange.com/a/696981/305857
bindkey -M viins '\e.' insert-last-word

# ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
# [ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
# [ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
#
# source "${ZINIT_HOME}/zinit.zsh"

# Add in Powerlevel10k
znap source romkatv/powerlevel10k

#  NOTE: 2023-10-03 - use bd to change dir backwards
znap source Tarrasch/zsh-bd

# To customize prompt, run `p10k configure` or edit ~/.dotfiles/zsh/.p10k.zsh.
[[ ! -f ~/.dotfiles/zsh/.p10k.zsh ]] || source ~/.dotfiles/zsh/.p10k.zsh

# Add in zsh plugins
#  INFO: 2024-02-26 11:34 AM - aliases expand plugin
export ZPWR_EXPAND_BLACKLIST=(tree ls cat cd ll la l g z gss)

# spelling correction in zsh-expand plugin
export ZPWR_CORRECT=false

# znap source bigH/git-fuzzy
znap clone https://github.com/bigH/git-fuzzy.git

# add the executable to your path
export PATH="$XDG_CONFIG_HOME/zsh/bigH/git-fuzzy/bin:$PATH"

#  REF: 2023-09-28 - https://github.com/zsh-users/zsh-history-substring-search
znap source zsh-users/zsh-history-substring-search

znap source mehalter/zsh-nvim-appname

function zvm_config() {
    # Start in insert mode
    ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT
    # Only changing the escape key to `jj` in insert mode, we still
    # keep using the default keybindings `^[` in other modes
    ZVM_VI_INSERT_ESCAPE_BINDKEY=jj
    # The plugin will auto execute this zvm_after_init function
}

function zvm_after_init() {
    # # NOTE:  FZF has to be here for it to be instanstiated
    # [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
    # Set up fzf key bindings and fuzzy completion
    source <(fzf --zsh)
    source $(brew --prefix)/opt/fzf/shell/completion.zsh
    source $(brew --prefix)/opt/fzf/shell/key-bindings.zsh
    fpath+=("$(brew --prefix)/share/zsh/site-functions")
    znap source hlissner/zsh-autopair
    autopair-init
    znap source Aloxaf/fzf-tab
    # znap source zsh-users/zsh-syntax-highlighting
    znap source zsh-users/zsh-completions
    znap source zsh-users/zsh-autosuggestions

    # start a prompt called starship
    # if has starship; then
    #     eval "$(starship init zsh)"
    # fi

    # ZNAP source all the plugins
    znap source zdharma-continuum/fast-syntax-highlighting
    #  INFO: 2023-09-26 - This expands aliases, use this instead of abbr
    znap source MenkeTechnologies/zsh-expand
}

# `znap prompt` also supports Oh-My-Zsh themes. Just make sure you load the
# required libs first:
znap source ohmyzsh/ohmyzsh lib/git

znap source ohmyzsh/ohmyzsh plugins/{git,sudo,kubectl,kubectx,command-not-found,fzf}

# Add vim-mode
znap source "jeffreytse/zsh-vi-mode"

# Load completions
autoload -Uz compinit && compinit

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# History
source ~/.dotfiles/zsh/history.zsh

#  INFO: 2024-06-04 - From old .zshrc
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

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
# switch group using `<` and `>`
zstyle ':fzf-tab:*' switch-group '<' '>'

if has bat; then
    alias cat='bat -pp'
fi

# Zoxide
if has zoxide; then
    eval "$(zoxide init --cmd cd zsh)"
fi

export PATH="$HOME/.local/bin/":$PATH
