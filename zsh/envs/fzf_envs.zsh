#!/usr/bin/env zsh

#  NOTE: 2023-09-28 - This is needed when loading fzf file
has() {
    type "$1" &>/dev/null
}
# https://github.com/junegunn/fzf/wiki/Color-schemes#color-configuration
# interactive color picker for fzf themes: https://minsw.github.io/fzf-color-picker/
#
# REF:
# https://github.com/junegunn/fzf/wiki/Configuring-shell-key-bindings
# https://gist.github.com/junegunn/8b572b8d4b5eddd8b85e5f4d40f17236
# https://sourcegraph.com/github.com/junegunn/fzf/-/blob/ADVANCED.md#--height
# https://pragmaticpineapple.com/four-useful-fzf-tricks-for-your-terminal/#4-preview-files-before-selecting-them

_fzf_compgen_path() {
    rg --files --glob "!.git" . "$1"
}

_fzf_git_status_git() {
    git -c color.status=always status --short | \
      fzf --ansi \
        --preview '(git diff --color=always -- {-1} | sed 1,4d; [[ ! -d {-1} ]] && bat --color=always {-1}) | head -500' \
        --bind='ctrl-o:execute(${EDITOR:-vim} {+})'
}

_fzf_compgen_dir() {
    fd --type d --hidden --follow --exclude ".git" . "$1"
}

_fzf_complete_git() {
    _fzf_complete -- "$@" < <(
        echo log
        echo diff
    )
}

_fzf_complete_git() {
    _fzf_complete -- "$@" < <(
        git --help -a | grep -E '^\s+' | awk '{print $1}'
    )
}
# TODO:
# https://www.reddit.com/r/vim/comments/10mh48r/fuzzy_search/
# perf gains to be had here: https://github.com/ranelpadon/configs/blob/master/zshrc/rg_fzf_bat.sh

# if has rg; then
#     export FZF_DEFAULT_COMMAND='rg --files --no-ignore-vcs --no-require-git --no-ignore --hidden --follow --glob "!{.git|.npm|node_modules}/*" 2> /dev/null'
# fi


export FZF_COMMON_OPTIONS="--inline-info \
--height 96% --border --margin=1 --padding=1 \
--select-1 \
--ansi \
--multi \
--reverse \
--extended \
--bind=ctrl-space:toggle \
'--bind=ctrl-o:execute-silent($EDITOR {})+abort' \
--bind=ctrl-i:ignore,ctrl-k:ignore \
--bind=ctrl-j:down,ctrl-k:up \
--bind=ctrl-u:preview-up,ctrl-d:preview-down \
--bind=esc:abort \
--bind=ctrl-c:abort \
--bind=?:toggle-preview \
--preview='($FZF_PREVIEW_COMMAND) 2> /dev/null' \
--cycle \
--margin=0,0 \
--padding=0,0 \
--prompt='∷ '"

command -v bat > /dev/null && command -v eza > /dev/null && export FZF_DEFAULT_OPTS="$FZF_COMMON_OPTIONS"

# --preview \". $ZSH_DOT_DIR_HELPERS/functions/fuzzy_preview {}\" \

export FZF_PREVIEW_COMMAND="([[ -d {} ]] && eza -T --icons auto --color=always {}) || \
    ([[ -f {} ]] && bat --style=numbers,changes --color=always {}) || \
    echo {}"

export FZF_CTRL_T_OPTS="--min-height 30 \
--height 85% \
--preview-window noborder --preview '($FZF_PREVIEW_COMMAND)'"

# alts: 󰛄
# --bind=ctrl-f:page-down,ctrl-b:page-up
# --bind=ctrl-u:preview-up,ctrl-d:preview-down
# --preview='bat --color=always --style=header,grid --line-range :300 {}'
# --no-multi
# --reverse
# --height=22%

_fzf_catppuccin() {
    export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
    --color=bg+:#313244,spinner:#f5e0dc,hl:#f38ba8 \
    --color=border:#45475a \
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
    --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
}

# CTRL-/ to toggle small preview window to see the full command
# CTRL-Y to copy the command into clipboard using pbcopy
export FZF_CTRL_R_OPTS="--header='command history (Press CTRL-y to copy command into clipboard)' \
--inline-info \
--height=70% \
--select-1 \
--ansi \
--reverse \
--extended \
--preview 'echo {}' --preview-window down:3:wrap \
--bind 'ctrl-/:toggle-preview' \
--bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort' \
--color header:italic"

_fzf_catppuccin

if has fd; then
    # FZF
    # Setting fd as the default source for fzf
    export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

    export FZF_ALT_C_OPTS="--preview 'eza -T --icons auto --color=always {}' --height=60%"
    export FZF_ALT_C_COMMAND="fd -t d -d 1 --follow --hidden --color=always --no-ignore-vcs --exclude 'Library'"
fi

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
    local command=$1
    shift

    case "$command" in
        git) git --help -a | grep -E '^\s+' | awk '{print $1}' | fzf "$@" ;;
        cd) fzf --preview 'eza -T --icons auto --color=always {} | head -200' "$@" ;;
        export|unset) fzf --preview "eval 'echo\$' {}" "$@" ;;
        ssh) fzf --preview 'dig {}' "$@" ;;
        tree) find . -type d | fzf --preview 'eza -T --icons auto {}' --color=always "$@" ;;
        *) fzf "$@" ;;
    esac
}

export FZF_PREVIEW_LINES=-200
