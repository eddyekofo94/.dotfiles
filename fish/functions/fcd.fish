function fcd -d "cd into the directory of the selected file"
    set -l fd_base "fd --strip-cwd-prefix --hidden --follow --exclude .git"
    set -l fzf_bind "ctrl-x:transform:fish -c 'if test \"\$FZF_PROMPT\" = \"All> \"; echo \"change-prompt(Files> )+reload($fd_base --type f)\"; else if test \"\$FZF_PROMPT\" = \"Files> \"; echo \"change-prompt(Dirs> )+reload($fd_base --type d)\"; else; echo \"change-prompt(All> )+reload($fd_base --type f --type d)\"; end'"

    set -lx FZF_DEFAULT_COMMAND "$fd_base --type f --type d"

    set -l selection (
      fzf +m --query="$argv" --no-multi --select-1 --exit-0 \
          --prompt="All> " \
          --bind="$fzf_bind" \
          --preview '_fzf_preview {}' \
          (_fzf_file_picker_opts .) \
          --bind=ctrl-v:toggle-preview \
          --header='(view:ctrl-v) (toggle:ctrl-x)'
    )

    if test (count $selection) -gt 0
        set -l target_dir $selection
        if test -f "$selection"
            set target_dir (dirname "$selection")
        end
        echo "cd $target_dir"
        cd "$target_dir" || return
    end
end
