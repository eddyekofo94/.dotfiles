function fdiff -d "fzf git diff"
    git rev-parse --git-dir >/dev/null 2>&1 || { echo "You are not in a git repository" && return }
    set -l files (_fzf_git_status_git | cut -c4-) #get file from fzf
    if test -f $files
        for file in $files
            git diff $file
        end
    else
        "git status is empty..."
    end
end
