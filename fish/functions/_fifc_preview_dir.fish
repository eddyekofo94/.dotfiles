function _fifc_preview_dir -d "List content of the selected directory"
    # --icons takes an optional value, so a bare `--icons` swallows the path that
    # follows it as its value. Spell the value out. `always` rather than `auto`
    # because the output is a pipe into fzf, where auto resolves to off.
    eza --tree --level=3 --color=always --icons=always -- $fifc_candidate
end
