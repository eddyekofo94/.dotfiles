function git_stage_unstage --argument-names 'file' -d "add or unstage a file with one click"
    if test -z "$file"
        echo "Usage: add <filename>"
        return 1
    end

    # 2. Get a list of all currently staged files
    set -l staged_files (git diff --name-only --cached)

    for file in $file
        if contains -- "$file" $staged_files
            # If the file is in the 'cached' list, it is staged -> Unstage it
            git restore --staged "$file"
            set_color red; echo "[-] Unstaged: $file"; set_color normal
        else
            # Otherwise, stage it
            git add "$file"
            set_color green; echo "[+] Staged: $file"; set_color normal
        end
    end

    # 3. Refresh the UI
    # gitog
end
