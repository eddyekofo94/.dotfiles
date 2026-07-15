function fe -d "fzf find edit"
    set -l fd_base "fd --strip-cwd-prefix --hidden --follow --exclude .git"
    set -l fzf_bind "ctrl-x:transform:fish -c 'if test \"\$FZF_PROMPT\" = \"All> \"; echo \"change-prompt(Files> )+reload($fd_base --type f)\"; else if test \"\$FZF_PROMPT\" = \"Files> \"; echo \"change-prompt(Dirs> )+reload($fd_base --type d)\"; else; echo \"change-prompt(All> )+reload($fd_base --type f --type d)\"; end'"

    set -lx FZF_DEFAULT_COMMAND "$fd_base --type f --type d"

    set -l file (
      fzf --query="$argv" --multi --select-1 --exit-0 \
          --prompt="All> " \
          --bind="$fzf_bind" \
          --preview 'test -d {} && eza -T -L 2 --color=always {} || bat --color=always --line-range :500 {}' \
          (_fzf_file_picker_opts .)
    )

    if test (count $file) -gt 0
        $EDITOR $file
    end
end
