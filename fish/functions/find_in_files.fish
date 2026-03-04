function find_in_files
    set -x RG_PREFIX rg --files-with-matches
    set -l file
    set file (
        FZF_DEFAULT_COMMAND="$RG_PREFIX '$argv'" \
            fzf --sort \
                --preview="[ ! -z {} ] && rg --pretty --context 5 {q} {}" \
        #--preview 'bat --color=always {1} --highlight-line {2}' \
                --phony -q "$argv" \
                --bind "change:reload:$RG_PREFIX {q}" \
                --preview-window="70%:wrap"
    ) &&
        $EDITOR "$file"
end
