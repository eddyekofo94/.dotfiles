function gitog
    set -l list_cmd "git status --porcelain"

    eval $list_cmd | fzf -m --ansi \
        --header "ENTER: Toggle | SHIFT-DEL: Untrack (Keep File) | CTRL-A: Stage All" \
        --preview "
            set file (string sub --start 4 {})
            if git diff --cached --quiet -- \$file
                git diff --color=always -- \$file
            else
                git diff --cached --color=always -- \$file
            end
        " \
        --bind "enter:execute(
            for line in {+1..-1}
                set file (string sub --start 4 \$line)
                if git diff --name-only --cached | grep -qx -- \$file
                    git restore --staged -- \$file
                else
                    git add -- \$file
                end
            end
        )+reload($list_cmd)" \
        --bind "shift-delete:execute(
            for line in {+1..-1}
                set file (string sub --start 4 \$line)
                git rm --cached -r -- \$file
            end
        )+reload($list_cmd)" \
        --bind "ctrl-a:execute(git add -A)+reload($list_cmd)"
end
