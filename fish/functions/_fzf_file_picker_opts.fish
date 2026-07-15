function _fzf_file_picker_opts --argument-names root --description "Shared fzf bindings for file/path pickers, including grep handoff"
    test -n "$root"; or set root .

    _fzf_file_picker_common_opts

    set -l grep_cmd "fish -ic 'fif --filter \"\$argv[1]\" \"\$argv[2]\"' "(string escape -- "$root")" {q}"
    printf "%s\n" "--bind=ctrl-g:become($grep_cmd)"
end
