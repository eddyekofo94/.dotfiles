export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export DOTFILES_DIR="$HOME/.dotfiles"
export ZSH_DOT_DIR="$DOTFILES_DIR/zsh"
export ZSH_DOT_DIR_ENVS="$ZSH_DOT_DIR/envs"

[[ -f "$ZSH_DOT_DIR_ENVS/envs.zsh" ]] && source "$ZSH_DOT_DIR_ENVS"/envs.zsh

has() {
    type "$1" &>/dev/null
}

# Download Znap, if it's not there yet.
[[ -r ~/.config/zsh/znap/znap.zsh ]] ||
git clone --depth 1 -- \
    https://github.com/marlonrichert/zsh-snap.git ~/.config/zsh/znap

source "$HOME"/.config/zsh/znap/znap.zsh # Start Znap

# Initialize colors.
autoload -Uz colors; colors

# LS colors using Vivid installed using Cargo
if has vivid; then
	export LS_COLORS="$(vivid generate "$DOTFILES_DIR"/vivid/catppuccin-mocha.yml)"
fi

# Zoxide
if has zoxide; then
    eval "$(zoxide init --cmd cd zsh)"
fi

if has bat; then
    alias cat='bat -pp'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

source ~/.dotfiles/zsh/history.zsh

source "$ZSH_DOT_DIR_HELPERS"/aliases.zsh
source "$ZSH_DOT_DIR_HELPERS"/funcs.zsh
source "$ZSH_DOT_DIR_HELPERS"/helpers.zsh
source "$ZSH_DOT_DIR_HELPERS"/fzf_functions.zsh
source "$ZSH_DOT_DIR_HELPERS"/widgets.sh
source "$ZSH_DOT_DIR"/extras/fzf-extras.zsh

# plugins
znap source  zsh-users/zsh-autosuggestions
# znap source  hlissner/zsh-autopair
#  NOTE: 2023-10-03 - use bd to change dir backwards
znap source Tarrasch/zsh-bd
znap source  zap-zsh/vim
# znap source bigH/git-fuzzy
znap clone https://github.com/bigH/git-fuzzy.git

# add the executable to your path
export PATH="$XDG_CONFIG_HOME/zsh/bigH/git-fuzzy/bin:$PATH"
# Add in zsh plugins
#  INFO: 2024-02-26 11:34 AM - aliases expand plugin
export ZPWR_EXPAND_BLACKLIST=(fe chmox tree ls cat cd ll la l g z gss)

# spelling correction in zsh-expand plugin
export ZPWR_CORRECT=false

# plug "zap-zsh/atmachine"
znap source zap-zsh/fzf
znap source zsh-users/zsh-history-substring-search

# znap source marlonrichert/zsh-autocomplete

znap source MichaelAquilina/zsh-you-should-use

znap source ohmyzsh/ohmyzsh lib/{git,completion,clipboard}
znap source ohmyzsh/ohmyzsh plugins/{sudo,kubectl,kubectx,zsh-navigation-tools,command-not-found}

function zvm_config() {
    # Start in insert mode
    ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT
    # Only changing the escape key to `jj` in insert mode, we still
    # keep using the default keybindings `^[` in other modes
    ZVM_VI_INSERT_ESCAPE_BINDKEY=jj
    # The plugin will auto execute this zvm_after_init function
}

function zvm_init ()
{
    autoload add-zle-hook-widget
    add-zle-hook-widget zle-line-pre-redraw zvm_zle-line-pre-redraw
}

function zvm_after_init() {
    # # NOTE:  FZF has to be here for it to be instanstiated
    # Set up fzf key bindings and fuzzy completion
    source <(fzf --zsh)
    source "$(brew --prefix)/opt/fzf/shell/completion.zsh"
    source "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh"
    fpath+=("$(brew --prefix)/share/zsh/site-functions")

    znap source hlissner/zsh-autopair
    autopair-init
    znap source zsh-users/zsh-syntax-highlighting
    znap source zsh-users/zsh-completions
    znap source zsh-users/zsh-autosuggestions

    #  INFO: 2023-09-26 - This expands aliases, use this instead of abbr
    znap source MenkeTechnologies/zsh-expand
    znap source Aloxaf/fzf-tab
}

# Add vim-mode
znap source "jeffreytse/zsh-vi-mode"

# keybinds
source $ZSH_DOT_DIR_HELPERS/bindkeys.zsh

autoload -Uz edit-command-line
zle -N edit-command-line
setopt auto_cd       # cd by typing directory name if it's not a command
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus

setopt correct_all   # autocorrect commands
setopt auto_list     # automatically list choices on ambiguous completion
setopt auto_menu     # automatically use menu completion
setopt always_to_end # move cursor to end if word had one match
setopt globdots # lists hidden files when completing
setopt no_beep                # silence all bells and beeps
setopt prompt_subst           # allow expansion in prompts
setopt NOCLOBBER # Don’t write over existing files with >, use >! instead
setopt BANG_HIST                 # Treat the '!' character specially during expansion.

# Completion styling
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --color=always -T --git --no-user --icons --group --sort=modified $realpath'
#  TODO: 2024-07-16 - Fix the preview
# zstyle ':fzf-tab:complete:nvim:*' fzf-preview "[[ -n $(file -b $1 | grep 'text' ) ]] && bat --color=always {} || eza --color=always -T --icons {} $realpath"
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --color=always -T --git --no-user --icons --group --sort=modified $realpath'
zstyle ':fzf-tab:*' fzf-bindings 'ctrl-y:accept' 'ctrl-a:toggle-all'

# switch group using `<` and `>`
zstyle ':fzf-tab:*' switch-group '<' '>'

# Load completions
autoload -Uz compinit && compinit

export PATH="$HOME/.local/bin/":$PATH

export PATH="/usr/local/opt/curl/bin:$PATH"

# start a prompt called starship
# if has starship; then
#     eval "$(starship init zsh)"
# fi

#  INFO: 2024-06-17 - This one
eval "$(oh-my-posh init zsh --config ~/.dotfiles/oh-my-posh/sim-web.omp.toml)"

bindkey '^ ' autosuggest-accept
if has zellij; then
    eval "$(zellij setup --generate-auto-start zsh)"
fi

export PATH="$(brew --prefix)/opt/libgit2@1.7/bin:$PATH"
