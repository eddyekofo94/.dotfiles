# Update (one or multiple) selected application(s)
# mnemonic [B]rew [U]pdate [P]ackage
function bup -d "[B]rew [U]pdate [P]ackage"
    set -l upd (brew leaves | fzf -m)

    if test (count $upd) -gt 0
        for app in (echo $upd)
            brew upgrade $app
        end
    end
end
