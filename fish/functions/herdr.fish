# Wrapper around the real herdr binary.
#
# Everything passes straight through except the two commands that would quietly
# dismantle this setup:
#
#   herdr update              → rebuilds the reviewed patched build instead of
#                               downloading the official one over the top of it
#   herdr server reload-config → also checks the config symlink, the installed
#                               binary and the plugins before reloading
#
# Scripts that invoke ~/.local/bin/herdr directly still get the real binary
# untouched, which is what the verification scripts want.

function herdr --wraps herdr --description 'herdr with the dotfiles wrapper'
    set -l real ~/.local/bin/herdr
    set -l dotfiles ~/.dotfiles

    if not test -x $real
        echo "herdr: no binary at $real" >&2
        return 127
    end

    switch "$argv[1]"
        case update
            echo "herdr update would replace the reviewed patched build with the"
            echo "official one, silently disabling the custom copy-mode bindings."
            echo "Running the reviewed update instead: herdr/update.sh --apply"
            echo
            sh $dotfiles/herdr/update.sh --apply $argv[2..]
            return $status
        case server
            if test "$argv[2]" = reload-config
                sh $dotfiles/herdr/reload.sh
                return $status
            end
    end

    command $real $argv
end
