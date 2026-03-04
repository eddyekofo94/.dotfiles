# Helper function to handle the logic
function __toggle_git_status
    set -l line $argv
    set -l s (string sub -l 1 "$line")
    # Extract filename: handles both ' M file.txt' and '?? file.txt'
    set -l f (string sub -s 4 "$line")

    if test "$s" != " " -a "$s" != "?"
        git restore --staged "$f"
    else
        git add "$f"
    end
end

# Main function
function fstage
    set -l status_cmd (git status --short )

    git status --short | fzf --multi --ansi --no-sort \
        --header "Enter: Toggle Stage | Ctrl-R: Refresh" \
        --preview 'git diff --color=always -- {-1} | head -500' \
        --bind "enter:execute-silent(fish -c '__toggle_git_status {}')+reload(git status --short)" \
        --bind "ctrl-r:reload(git status --short)"
end
