function _fzf_file_picker_common_opts --argument-names open_placeholder --description "Shared fzf bindings for file/path pickers"
    test -n "$open_placeholder"; or set open_placeholder "{+}"

    set -l open_cmd "sh -c 'if command -v open >/dev/null 2>&1; then open \"\$@\"; elif command -v xdg-open >/dev/null 2>&1; then for file do xdg-open \"\$file\" >/dev/null 2>&1 & done; else printf \"%s\n\" \"fzf: no opener found; expected open or xdg-open\" >&2; exit 127; fi' fzf-open $open_placeholder"
    set -l copy_path_cmd "fish -c '_fzf_copy_paths \$argv' $open_placeholder"
    set -l copy_contents_cmd "fish -c '_fzf_copy_file_contents \$argv' $open_placeholder"

    printf "%s\n" \
        "--bind=tab:toggle+down" \
        "--bind=shift-tab:toggle+up" \
        "--bind=alt-a:select-all" \
        "--bind=ctrl-u:preview-half-page-up" \
        "--bind=ctrl-d:preview-half-page-down" \
        "--bind=ctrl-o:execute-silent($open_cmd)" \
        "--bind=ctrl-y:execute-silent($copy_path_cmd)" \
        "--bind=alt-y:execute-silent($copy_contents_cmd)"
end
