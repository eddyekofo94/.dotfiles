# [ -f "$HOME/.local/share/zap/zap.zsh" ] && source "$HOME/.local/share/zap/zap.zsh"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export ZSH_DOT_DIR="$DOTFILES_DIR/zsh"
export DOTFILES_DIR="$HOME/.dotfiles"

# Main change, you can see directories on a dark background
export CLICOLOR=1

has() {
    type "$1" &>/dev/null
}

# Download Znap, if it's not there yet.
[[ -r ~/.config/zsh/znap/znap.zsh ]] ||
git clone --depth 1 -- \
    https://github.com/marlonrichert/zsh-snap.git ~/.config/zsh/znap

source ~/.config/zsh/znap/znap.zsh # Start Znap

if has zellij; then
    eval "$(zellij setup --generate-auto-start zsh)"
fi

# Initialize colors.
autoload -U colors; colors

# LS colors using Vivid installed using Cargo
if has vivid; then
	export LS_COLORS="$(vivid generate $DOTFILES_DIR/vivid/catppuccin-mocha.yml)"
fi

# Zoxide
if has zoxide; then
    eval "$(zoxide init --cmd cd zsh)"
fi

if has bat; then
    alias cat='bat -pp'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# history
source ~/.dotfiles/zsh/history.zsh

source $ZSH_DOT_DIR_HELPERS/aliases.zsh
source $ZSH_DOT_DIR_HELPERS/funcs.zsh
source $ZSH_DOT_DIR_HELPERS/helpers.zsh
source $ZSH_DOT_DIR_HELPERS/fzf.zsh
source $ZSH_DOT_DIR_HELPERS/fzf_functions.zsh

# plugins
znap source  esc/conda-zsh-completion
znap source  zsh-users/zsh-autosuggestions
# znap source  hlissner/zsh-autopair
znap source  zap-zsh/supercharge
#  NOTE: 2023-10-03 - use bd to change dir backwards
znap source Tarrasch/zsh-bd
znap source  zap-zsh/vim
# znap source bigH/git-fuzzy
znap clone https://github.com/bigH/git-fuzzy.git
# add the executable to your path
export PATH="$XDG_CONFIG_HOME/zsh/bigH/git-fuzzy/bin:$PATH"
# Add in zsh plugins
#  INFO: 2024-02-26 11:34 AM - aliases expand plugin
export ZPWR_EXPAND_BLACKLIST=(tree ls cat cd ll la l g z gss)

# spelling correction in zsh-expand plugin
export ZPWR_CORRECT=false
# znap source  zap-zsh/zap-prompt
# plug "zap-zsh/atmachine"
znap source  zap-zsh/fzf
znap source  zsh-users/zsh-history-substring-search

znap source MichaelAquilina/zsh-you-should-use

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

    # ZNAP source all the plugins
    znap source zdharma-continuum/fast-syntax-highlighting
    #  INFO: 2023-09-26 - This expands aliases, use this instead of abbr
    znap source MenkeTechnologies/zsh-expand
}

znap source ohmyzsh/ohmyzsh plugins/{git,sudo,kubectl,kubectx,command-not-found,fzf}

# Add vim-mode
znap source "jeffreytse/zsh-vi-mode"

# keybinds
bindkey '^ ' autosuggest-accept

# NOTE: Alt+. fix: https://unix.stackexchange.com/a/696981/305857
bindkey -M viins '\e.' insert-last-word

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

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
# Load completions
autoload -Uz compinit && compinit

export PATH="$HOME/.local/bin/":$PATH

# start a prompt called starship
if has starship; then
    eval "$(starship init zsh)"
fi
