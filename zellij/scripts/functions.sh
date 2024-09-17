#!/usr/bin/env bash

# This function is used to select a project directory
# If the user provides a directory as an argument, it will be used
# Otherwise, it will use fzf to select a directory
# If fzf is not installed, it will exit with an error
function select_project_or_default() {
    local selected=$1

    if [[ $# -eq 1 ]]; then
        echo"$selected"
        return
    fi

    # exit with error if fd is not installed
    # show the installation link for fd
    if ! command -v fd &> /dev/null; then
        echo "fd is not installed. Please install fd first." >&2
        echo "Installation link: https://github.com/sharkdp/fd" >&2
        return 1
    fi

    selected=$(fd . $WORKSPACE/projects \
        $DOTFILES_DIR/ \
        $HOME/.config/nvim* -d 2 --type directory \
        | fzf)

    echo "$selected"
}

