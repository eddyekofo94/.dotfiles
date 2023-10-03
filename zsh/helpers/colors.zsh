# Initialize colors.
autoload -U colors; colors

# LS colors using Vivid installed using Cargo
export LS_COLORS="$(vivid generate $DOTFILES_DIR/vivid/catppuccin-mocha.yml)"

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

# Main change, you can see directories on a dark background
export CLICOLOR=1

source "$ZDOTDIR/plugins/colorize.plugin.zsh"
# Fallback to built in ls colors
# zstyle ':completion:*' list-colors ''
# ref: https://github.com/robbyrussell/oh-my-zsh/issues/1563#issuecomment-53638038
# zstyle ':completion:*:default' list-colors "${(@s.:.)LS_COLORS}"
# zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# https://github.com/xPMo/zsh-ls-colors#customizing-colors-with-styles
zstyle -e '*' list-colors 'reply=(${(s[:])LS_COLORS})'
