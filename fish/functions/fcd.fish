function fcd -d "cd into the directory of the selected file"
    set -l dir
    set dir (
      fd --type d | \
        fzf +m -q "$argv" \
           --no-multi --select-1 --exit-0 \
           --bind=ctrl-v:toggle-preview \
           --bind=ctrl-x:toggle-sort \
           --header='(view:ctrl-v) (sort:ctrl-x)' \
       )

           #--preview="$FZF_PREVIEW_CMD" \
    #--preview-window='right:hidden:wrap' \
    if test (count $dir) -gt 0
        #set -l dir (dirname "$file")
        echo "cd $dir"
        cd $dir || return
    end
end
