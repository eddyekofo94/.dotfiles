function _fzf_wrapper --description "Prepares some environment variables before executing fzf."
    # Make sure fzf uses fish to execute preview commands, some of which
    # are autoloaded fish functions so don't exist in other shells.
    # Use --function so that it doesn't clobber SHELL outside this function.
    set -f --export SHELL (command --search fish)

    # If neither FZF_DEFAULT_OPTS nor FZF_DEFAULT_OPTS_FILE are set, then set some sane defaults.
    # See https://github.com/junegunn/fzf#environment-variables
    set --query FZF_DEFAULT_OPTS FZF_DEFAULT_OPTS_FILE
    if test $status -eq 2
        # cycle allows jumping between the first and last results, making scrolling faster
        # layout=reverse lists results top to bottom, mimicking the familiar layouts of git log, history, and env
        # border shows where the fzf window begins and ends
        # height=90% leaves space to see the current command and some scrollback, maintaining context of work
        # preview-window=wrap wraps long lines in the preview window, making reading easier
        # marker=* makes the multi-select marker more distinguishable from the pointer (since both default to >)
        #set --export FZF_DEFAULT_OPTS "--cycle --layout=reverse --border --height=90% --preview-window=wrap --marker="*""

        set --export FZF_DEFAULT_OPTS "--inline-info \
            --height 90% --border --margin=1 --padding=1 \
            --select-1 \
            --preview-window=right,55%,border-sharp,nocycle \
            --ansi \
            --multi \
            --reverse \
            --extended \
            --bind=tab:toggle \
            --bind 'enter:execute-silent(echo {} | fish -c ...)' \
            --bind=ctrl-a:select-all \
            --bind=ctrl-d:deselect-all \
            --bind=ctrl-t:toggle-all \
            '--bind=ctrl-o:execute-silent($EDITOR {})+abort' \
            --bind=ctrl-i:ignore,ctrl-k:ignore \
            --bind=ctrl-j:down,ctrl-k:up \
            --bind=ctrl-u:preview-up,ctrl-d:preview-down \
            --bind=esc:abort \
            --bind=ctrl-c:abort \
            --bind=?:toggle-preview \
            --cycle \
            --margin=0,0 \
            --padding=0,0 \
            --prompt='∷ ' \
            --color=bg+:#313244,spinner:#f5e0dc,hl:#f38ba8 \
            --color=border:#45475a \
            --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
            --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
    end

    fzf $argv
end
