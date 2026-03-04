function zd -d "z - cd into 'frecency' directory"
    set IFS '\n'

    set -l dir (
    zoxide query -l \
      | fzf \
          --reverse -1 \
          --no-sort \
          --no-multi \
          --tiebreak=index \
          --query "$argv[1]" \
          --bind=ctrl-v:toggle-preview \
          --bind=ctrl-s:toggle-sort \
          --bind 'ctrl-o:become($EDITOR {1} +{2})' \
          --header='(view:ctrl-v) (sort:ctrl-s)' \
          #--preview-window='right:hidden:wrap' \
          #--preview "$FZF_PREVIEW_CMD" \
      )

    if test (count $dir ) -gt 0
        echo "cd $dir"
        cd $dir
    end

end
