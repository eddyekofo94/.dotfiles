# Uninstall (one or multiple) selected application(s)
# using "brew search" as source input
# mnemonic [B]rew [X]uninstall [P]ackage
function bxp -d "[B]rew [X]uninstall [P]ackage"
    set -l del (brew leaves | fzf -m --preview 'brew info {}' --preview-window 'right:50%:wrap')

    if test (count $del) -gt 0
        for plugin in (echo $del)
            brew uninstall $plugin
        end
    end
end
