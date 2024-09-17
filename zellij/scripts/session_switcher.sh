#!/usr/bin/env bash

zellij_zoxide() {
  local dir
  dir="$(
    zoxide query -l \
      | fzf \
          --reverse \
          --select-1 \
          --no-sort \
          --no-multi \
          --tiebreak=index \
          --bind=ctrl-x:toggle-sort \
          --query "$*" \
          --preview="eza --tree --color=always --icons auto {} | head -n $FZF_PREVIEW_LINES" \
          --preview-window='right:hidden:wrap' \
          --bind=ctrl-v:toggle-preview \
          --bind=ctrl-x:toggle-sort \
          --header='(view:ctrl-v) (sort:ctrl-x)' \
  )" || return

  if [[ -d "$dir" ]]; then
    cd "$dir" || return
    zellij -s "$(basename "$dir")"
  fi
}
