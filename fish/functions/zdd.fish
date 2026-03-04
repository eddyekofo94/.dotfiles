
#  TODO: 2024-12-31 - Turn to fish
function zdd -d "cd to selected directory"
    set -l dir
    set dir (
        fd $argv -type d -print 2> /dev/null \
          | fzf +m \
              --query="$argv" \
              --preview="eza --tree --color=always --icons auto {} | head -n $FZF_PREVIEW_LINES" \
              --preview-window='right:hidden:wrap' \
              --bind=ctrl-v:toggle-preview \
              --bind=ctrl-x:toggle-sort \
              --header='(view:ctrl-v) (sort:ctrl-x)' \
    ) || return

    cd "$dir" || return
end
