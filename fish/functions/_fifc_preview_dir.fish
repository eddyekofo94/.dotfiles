function _fifc_preview_dir -d "List content of the selected directory"
    eza --tree --level=3 --color=always --icons $fifc_candidate
end
