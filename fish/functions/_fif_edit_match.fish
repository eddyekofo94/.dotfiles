function _fif_edit_match --argument-names file line column --description "Open a fif match in the editor at line and column"
    set file (printf "%s" "$file" | perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g')
    set line (printf "%s" "$line" | perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g')
    set column (printf "%s" "$column" | perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g')

    test -n "$EDITOR"; or set EDITOR vi
    test -f "$file"; or return 1
    string match -qr '^[0-9]+$' -- "$line"; or set line 1
    string match -qr '^[0-9]+$' -- "$column"; or set column 1

    set -l editor_name (basename (string split ' ' -- $EDITOR)[1])

    switch "$editor_name"
        case nvim vim vi
            command $EDITOR +"call cursor($line, $column)" -- "$file"
        case '*'
            command $EDITOR +"$line" -- "$file"
    end
end
