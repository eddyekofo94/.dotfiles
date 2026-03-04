function gss -d "git status"
    # The command used to populate the list and refresh it
    # set -l list_cmd "git -c color.status=always status --porcelain"
    set -l git_root_dir (git rev-parse --show-toplevel)
    set -l list_cmd "git -c color.status=always status --short $git_root_dir"
    set -l preview_status 'git diff --color=always -- {-1} | sed 1,4d; test ! -d {-1} && bat --color=always {-1} | head -500'
    # Detect clipboard command
    set -l copy_cmd "pbcopy" # Default to macOS; change to xclip or wl-copy if on Linux
    # set -l copy_cmd (command -v pbcopy; or command -v xclip; or echo "wl-copy")

    eval $list_cmd | fzf -m --ansi --header-first \
        --header "ENTER: Toggle | CTRL-A: Stage All | CTRL-R: Unstage All | ESC: Exit" \
        --preview="$preview_status" \
        --bind "enter:execute-silent(
            for file in {2}
                # Your logic: check if file is in the cached/staged list
                if git diff --name-only --cached | grep -qx -- \$file

                    git reset -- \$file
                else
                    git add -- \$file
                end
            end
        )+reload($list_cmd)" \
        --bind "ctrl-a:execute(git add -A)+reload($list_cmd)" \
        --bind "ctrl-r:execute(git restore --staged .)+reload($list_cmd)" \
        --bind='ctrl-o:execute($EDITOR {2})' \
        --bind='ctrl-p:execute(git commit)+abort' \
        --bind='alt-a:execute(git commit --amend)+abort' \
        --bind "ctrl-y:execute(echo {2} | $copy_cmd)+become(echo 'Copied path to clipboard: ' {2})" \
        --bind="tab:toggle"
end
