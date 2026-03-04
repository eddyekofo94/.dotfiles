function fed -d "cd into the directory of the selected file"
    set -l file
    set file (fzf +m -q "$argv" \
           --bind=ctrl-v:toggle-preview \
           --bind=ctrl-x:toggle-sort \
           --header='(view:ctrl-v) (sort:ctrl-x)' \
       )

           #--preview-window='right:hidden:wrap' \
    #--preview="${FZF_PREVIEW_CMD}" \
    if test (count $file) -gt 0
        set -l dir (dirname "$file")
        echo "cd $dir"
        cd $dir || return
    end
end
