function fcat -d "fzf find cat"
    set -l file (
      fzf --query="$argv" --no-multi --select-1 --exit-0 \
          --preview 'bat --color=always --line-range :500 {}'
    )

    if test (count $file) -gt 0
        cat $file
    end
end

