function dotfiles \
    --description 'dotfiles bare git repo'

    git --git-dir=$HOME/.dotfiles --work-tree=$HOME $argv
end
