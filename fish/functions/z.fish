function z -d "z - open 'frecency' files in $VISUAL editor"
    set IFS '\n'

    set -l file (
    zoxide query -l \
      | fzf \
          --reverse -1 \
          --no-sort \
          --no-multi \
          --tiebreak=index \
          --query "$argv[1]" \
          --preview-window='right:hidden:wrap' \
          --bind=ctrl-v:toggle-preview \
          --bind=ctrl-s:toggle-sort \
          --header='(view:ctrl-v) (sort:ctrl-s)' \
          #--preview "$FZF_PREVIEW_CMD" \
      )

    if test (count $file) -gt 0
        echo "$EDITOR $file"
        $EDITOR $files
    end

end
