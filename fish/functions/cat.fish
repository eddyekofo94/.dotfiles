function cat --wraps=bat --description 'alias cat=bat'
    if type -q bat &>/dev/null
        bat -pp $argv
        export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    else
        cat $argv
    end
end
