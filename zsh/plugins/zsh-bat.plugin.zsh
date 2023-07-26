
if command -v bat >/dev/null 2>&1; then
  alias rcat=$(which cat)
  # alias cat=$(which bat)
  alias cat='bat --paging=never --style=changes'
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi
