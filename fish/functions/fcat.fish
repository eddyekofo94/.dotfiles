function fcat -d "fzf find cat"
    set -l fd_base "fd --strip-cwd-prefix --hidden --follow --no-ignore-vcs --exclude .git"
    set -l fzf_bind "ctrl-x:transform:fish -c 'if test \"\$FZF_PROMPT\" = \"All> \"; echo \"change-prompt(Files> )+reload($fd_base --type f)\"; else if test \"\$FZF_PROMPT\" = \"Files> \"; echo \"change-prompt(Dirs> )+reload($fd_base --type d)\"; else; echo \"change-prompt(All> )+reload($fd_base --type f --type d)\"; end'"

    set -lx FZF_DEFAULT_COMMAND "$fd_base --type f --type d"

    set -l file (
      fzf --query="$argv" --no-multi --select-1 --exit-0 \
          --prompt="All> " \
          --bind="$fzf_bind" \
          --preview '_fzf_preview {}' \
          (_fzf_file_picker_opts .)
    )

    if test (count $file) -gt 0
        set -l absolute_file (path resolve -- "$file")
        set -l absolute_home (path resolve -- "$HOME")
        set -l display_file "$absolute_file"
        if string match --quiet -- "$absolute_home/*" "$absolute_file"
            set display_file (string replace -- "$absolute_home/" "~/" "$absolute_file")
        end

        set_color brblack
        printf '%s\n' "$display_file"
        set_color normal
        printf '\n'
        cat -- "$file"
    end
end
