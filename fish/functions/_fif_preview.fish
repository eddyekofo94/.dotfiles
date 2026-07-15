function _fif_preview --argument-names file line column query_file matched_text --description "Preview a fif match with a column-focused snippet"
    set file (printf "%s" "$file" | perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g')
    set line (printf "%s" "$line" | perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g')
    set column (printf "%s" "$column" | perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g')

    string match -qr '^[0-9]+$' -- "$line"; or return 0
    string match -qr '^[0-9]+$' -- "$column"; or set column 1
    test -n "$file"; and test -f "$file"; or return 0

    set -l columns $FZF_PREVIEW_COLUMNS
    string match -qr '^[0-9]+$' -- "$columns"; or set columns 120
    set -l width (math "max(48, $columns - 8)")
    set -l preview_lines $FZF_PREVIEW_LINES
    string match -qr '^[0-9]+$' -- "$preview_lines"; or set preview_lines 40
    set -l context_lines (math "max(8, $preview_lines - 6)")
    set -l before (math "floor(($context_lines - 1) / 2)")
    set -l after (math "$context_lines - $before - 1")
    set -l query (test -n "$query_file"; and test -f "$query_file"; and command cat "$query_file")
    set -l from (math "max(1, $line - $before)")
    set -l to (math "$line + $after")

    printf "\033[1mMatch\033[0m \033[2m%s:%s:%s\033[0m\n" "$file" "$line" "$column"

    python3 (status dirname)/_fif_preview.py "$column" "$width" "$query" "$matched_text"

    printf "\033[1mContext\033[0m\n"
    bat --color=always --style=numbers,changes --highlight-line "$line" --line-range "$from:$to" --wrap=never --terminal-width "$columns" -- "$file"
end
