function fe -d "fzf find edit"
    set -l file (
      fzf --query="$argv" --multi --select-1 --exit-0 \
          --preview 'bat --color=always --line-range :500 {}'
    )

    if test (count $file) -gt 0
        $EDITOR "$file"
    end
end

