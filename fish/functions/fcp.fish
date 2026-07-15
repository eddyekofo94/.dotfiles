function fcp -d "fzf find and copy file path"
    set -l fd_base "fd --strip-cwd-prefix --hidden --follow --exclude .git"
    set -l fzf_bind "ctrl-x:transform:fish -c 'if test \"\$FZF_PROMPT\" = \"All> \"; echo \"change-prompt(Files> )+reload($fd_base --type f)\"; else if test \"\$FZF_PROMPT\" = \"Files> \"; echo \"change-prompt(Dirs> )+reload($fd_base --type d)\"; else; echo \"change-prompt(All> )+reload($fd_base --type f --type d)\"; end'"

    set -lx FZF_DEFAULT_COMMAND "$fd_base --type f --type d"

    set -l files (
      fzf --query="$argv" --multi --select-1 --exit-0 \
          --prompt="All> " \
          --bind="$fzf_bind" \
          --preview '_fzf_preview {}' \
          (_fzf_file_picker_opts .)
    )

    if test (count $files) -gt 0
        set -l full_paths
        for file in $files
            set -a full_paths (realpath "$file")
        end
        
        # Escape paths to handle spaces and special characters properly
        set -l escaped_paths (string escape -- $full_paths)
        # Join paths with a space so they can be pasted as arguments in a single line
        set -l joined_escaped (string join " " $escaped_paths)
        
        # Copy to clipboard without a trailing newline
        echo -n $joined_escaped | pbcopy
        
        # Append the copy command to history so the user can recopy it with ctrl+r
        set -l double_escaped (string escape -- $joined_escaped)
        set -l copy_cmd "echo -n $double_escaped | pbcopy"
        history append $copy_cmd
        history save
        
        echo "Copied to clipboard:"
        for path in $full_paths
            echo "  $path"
        end
    end
end
